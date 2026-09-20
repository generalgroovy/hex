#!/usr/bin/env bash
set -Eeuo pipefail

MODEL="${FLUX2_AIDER_MODEL:-qwen2.5-coder:3b}"
SESSION="${FLUX2_AIDER_SESSION:-flux2-aider}"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
INSIDE_TMUX=0

if [[ "${1:-}" == "--inside-tmux" ]]; then
  INSIDE_TMUX=1
fi

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v aider >/dev/null 2>&1 || die "aider is not on PATH."
command -v ollama >/dev/null 2>&1 || die "ollama is not on PATH."
command -v git >/dev/null 2>&1 || die "git is not on PATH."

cd "$REPO_ROOT"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$REPO_ROOT is not a Git repository."

if [[ -n "$(git status --porcelain)" && "${FLUX2_AIDER_ALLOW_DIRTY:-0}" != "1" ]]; then
  git status --short --branch
  die "working tree is dirty. Commit/stash it, or explicitly set FLUX2_AIDER_ALLOW_DIRTY=1."
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" == "main" || "$current_branch" == "master" || "$current_branch" == "agent/aider-local-workflow" || -z "$current_branch" ]]; then
  work_branch="${FLUX2_AIDER_BRANCH:-agent/aider-live-$(date +%Y%m%d-%H%M%S)}"
  log "Creating isolated work branch: $work_branch"
  git switch --create "$work_branch"
else
  work_branch="$current_branch"
fi

case "$work_branch" in
  agent/aider-*) ;;
  *) die "refusing unrestricted Aider mode outside an agent/aider-* branch (current: $work_branch)." ;;
esac

if [[ -f .githooks/post-commit ]]; then
  chmod +x .githooks/post-commit
  git config core.hooksPath .githooks
fi

if ! git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
  log "Publishing branch before the session starts"
  git push --set-upstream origin "$work_branch"
fi

endpoint="${OLLAMA_API_BASE:-}"
if [[ -z "$endpoint" ]] && command -v curl >/dev/null 2>&1; then
  for candidate in "http://127.0.0.1:11434" "http://172.17.0.1:11434"; do
    if curl -fsS --max-time 2 "$candidate/api/tags" >/dev/null 2>&1; then
      endpoint="$candidate"
      break
    fi
  done
fi
[[ -n "$endpoint" ]] || endpoint="http://127.0.0.1:11434"
export OLLAMA_API_BASE="$endpoint"
export OLLAMA_HOST="${endpoint#http://}"

if ! ollama list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$MODEL"; then
  die "local model '$MODEL' is not available. Choose one with: FLUX2_AIDER_MODEL=<name> bash scripts/start-aider-full-interactive.sh"
fi

runtime_dir="$REPO_ROOT/.git/aider-runtime"
mkdir -p "$runtime_dir"
empty_ignore="$runtime_dir/empty.aiderignore"
: > "$empty_ignore"

AIDER_ARGS=(
  --model "ollama_chat/$MODEL"
  --edit-format whole
  --yes-always
  --show-diffs
  --git
  --auto-commits
  --dirty-commits
  --git-commit-verify
  --watch-files
  --restore-chat-history
  --suggest-shell-commands
  --notifications
  --map-refresh always
  --aiderignore "$empty_ignore"
  --add-gitignore-files
  --input-history-file "$runtime_dir/input.history"
  --chat-history-file "$runtime_dir/chat.history.md"
  --llm-history-file "$runtime_dir/llm.history"
  --analytics-disable
  --verbose
)

run_session() {
  printf '\nRepository: %s\nBranch:     %s\nModel:      ollama_chat/%s\nEndpoint:   %s\n' \
    "$REPO_ROOT" "$work_branch" "$MODEL" "$OLLAMA_API_BASE"
  printf '\nAider is unrestricted inside this repository and confirmation prompts are auto-approved.\n'
  printf 'Use /ask for analysis, /code for edits, /diff, /test, /undo, /git status, or normal prompts.\n'
  printf 'With --watch-files, comments ending in AI! trigger edits and AI? trigger answers.\n\n'

  if command -v systemd-inhibit >/dev/null 2>&1; then
    systemd-inhibit \
      --what=sleep:idle \
      --who="flux2-aider" \
      --why="Keep the interactive FLUX2 Aider session available" \
      --mode=block \
      aider "${AIDER_ARGS[@]}"
  else
    aider "${AIDER_ARGS[@]}"
  fi
}

if [[ "$INSIDE_TMUX" == "0" && -z "${TMUX:-}" && "${FLUX2_AIDER_NO_TMUX:-0}" != "1" ]]; then
  if command -v tmux >/dev/null 2>&1; then
    printf -v quoted_script '%q' "$SCRIPT_PATH"
    log "Opening persistent tmux session: $SESSION"
    exec tmux new-session -A -s "$SESSION" "bash $quoted_script --inside-tmux"
  else
    printf '\nNOTE: tmux is not installed, so this session will end if the terminal closes.\n'
    printf 'Install it with: sudo pacman -S --needed tmux\n\n'
  fi
fi

while true; do
  set +e
  run_session
  exit_code=$?
  set -e

  printf '\nAider exited with status %s.\n' "$exit_code"
  read -r -p "Press Enter to restart, or type q to stop: " answer
  case "$answer" in
    q|Q|quit|exit) break ;;
    *) ;;
  esac
done
