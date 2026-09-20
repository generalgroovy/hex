#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/generalgroovy/flux2.git"
SSH_REPO_URL="git@github.com:generalgroovy/flux2.git"
BOOTSTRAP_BRANCH="agent/aider-local-workflow"
REPO_DIR="${1:-$HOME/Projects/flux2}"
MODEL="${FLUX2_AIDER_MODEL:-qwen2.5-coder:3b}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Linux" ]]; then
  die "this setup script targets Linux/Garuda."
fi

log "Checking required commands"
missing_packages=()
command -v git >/dev/null 2>&1 || missing_packages+=(git)
command -v curl >/dev/null 2>&1 || missing_packages+=(curl)
command -v python >/dev/null 2>&1 || missing_packages+=(python)
command -v ollama >/dev/null 2>&1 || missing_packages+=(ollama)
command -v notify-send >/dev/null 2>&1 || missing_packages+=(libnotify)

if ((${#missing_packages[@]})); then
  command -v pacman >/dev/null 2>&1 || die "missing commands and pacman is unavailable: ${missing_packages[*]}"
  log "Installing missing Garuda/Arch packages: ${missing_packages[*]}"
  sudo pacman -S --needed "${missing_packages[@]}"
fi

log "Installing or updating Aider in its isolated environment"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v aider >/dev/null 2>&1; then
  curl -LsSf https://aider.chat/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v aider >/dev/null 2>&1 || die "Aider installation completed but aider is not on PATH. Add $HOME/.local/bin to PATH."
aider --version

log "Starting Ollama"
if systemctl list-unit-files --no-legend ollama.service 2>/dev/null | grep -q '^ollama\.service'; then
  sudo systemctl enable --now ollama
else
  mkdir -p "$HOME/.local/state/ollama"
  if ! pgrep -x ollama >/dev/null 2>&1; then
    nohup ollama serve >"$HOME/.local/state/ollama/serve.log" 2>&1 &
  fi
fi

endpoint=""
for attempt in {1..30}; do
  for candidate in "${OLLAMA_API_BASE:-}" "http://127.0.0.1:11434" "http://172.17.0.1:11434"; do
    [[ -n "$candidate" ]] || continue
    if curl -fsS --max-time 2 "$candidate/api/tags" >/dev/null 2>&1; then
      endpoint="$candidate"
      break 2
    fi
  done
  sleep 1
done
[[ -n "$endpoint" ]] || die "Ollama did not respond. Inspect: systemctl status ollama; journalctl -u ollama -n 100"

export OLLAMA_API_BASE="$endpoint"
export OLLAMA_HOST="${endpoint#http://}"
printf 'Ollama endpoint: %s\n' "$OLLAMA_API_BASE"

log "Ensuring local coding model is present: $MODEL"
if ! ollama list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$MODEL"; then
  ollama pull "$MODEL"
fi

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"
if [[ -n "$script_root" ]] && git -C "$script_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_DIR="$(git -C "$script_root" rev-parse --show-toplevel)"
elif [[ ! -d "$REPO_DIR/.git" ]]; then
  log "Cloning $REPO_URL into $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
git remote get-url origin >/dev/null 2>&1 || die "$REPO_DIR has no origin remote."

if [[ -n "$(git status --porcelain)" ]]; then
  git status --short --branch
  die "the repository has uncommitted changes. Preserve or commit them before setup; nothing was altered."
fi

log "Fetching the repository-contained Aider workflow"
git fetch origin "$BOOTSTRAP_BRANCH"
current_branch="$(git branch --show-current)"
if [[ "$current_branch" == "$BOOTSTRAP_BRANCH" ]]; then
  git merge --ff-only "origin/$BOOTSTRAP_BRANCH"
elif [[ "$current_branch" != agent/aider-* ]] || [[ ! -f .aider.conf.yml ]] || [[ ! -f CONVENTIONS.md ]]; then
  if git show-ref --verify --quiet "refs/heads/$BOOTSTRAP_BRANCH"; then
    git switch "$BOOTSTRAP_BRANCH"
    git merge --ff-only "origin/$BOOTSTRAP_BRANCH"
  else
    git switch --create "$BOOTSTRAP_BRANCH" --track "origin/$BOOTSTRAP_BRANCH"
  fi
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" == "$BOOTSTRAP_BRANCH" ]]; then
  work_branch="${FLUX2_AIDER_BRANCH:-agent/aider-$(date +%Y%m%d-%H%M%S)}"
  git switch --create "$work_branch"
else
  work_branch="$current_branch"
fi

case "$work_branch" in
  agent/aider-*) ;;
  *) die "refusing to configure automatic pushes outside an agent/aider-* branch." ;;
esac

log "Enabling repository-owned Git hooks"
chmod +x .githooks/post-commit scripts/start-aider-local.sh scripts/setup-aider-local.sh
git config core.hooksPath .githooks

if [[ -z "$(git config user.name || true)" ]]; then
  read -r -p "Git author name: " git_name
  [[ -n "$git_name" ]] || die "Git author name is required."
  git config user.name "$git_name"
fi
if [[ -z "$(git config user.email || true)" ]]; then
  read -r -p "Git author email: " git_email
  [[ -n "$git_email" ]] || die "Git author email is required."
  git config user.email "$git_email"
fi

log "Publishing isolated branch origin/$work_branch"
if ! git push --set-upstream origin "HEAD:$work_branch"; then
  printf '\nInitial HTTPS push failed. Trying existing SSH authentication.\n' >&2
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -qi 'successfully authenticated'; then
    git remote set-url origin "$SSH_REPO_URL"
    git push --set-upstream origin "HEAD:$work_branch"
  elif command -v gh >/dev/null 2>&1; then
    printf 'GitHub CLI is available. Starting interactive authentication.\n'
    gh auth login
    gh auth setup-git
    git push --set-upstream origin "HEAD:$work_branch"
  else
    die "GitHub push authentication is not configured. Install github-cli and run 'gh auth login', then rerun this script."
  fi
fi

log "Setup complete"
printf 'Repository: %s\n' "$REPO_DIR"
printf 'Branch:     %s\n' "$work_branch"
printf 'Model:      ollama_chat/%s\n' "$MODEL"
printf 'Endpoint:   %s\n' "$OLLAMA_API_BASE"
printf 'Launch:     bash %s/scripts/start-aider-local.sh\n' "$REPO_DIR"

if [[ "${FLUX2_AIDER_NO_LAUNCH:-0}" != "1" ]]; then
  bash scripts/start-aider-local.sh
fi
