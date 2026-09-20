#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
cd "$ROOT"

branch="$(git branch --show-current)"
case "$branch" in
  agent/aider-*) ;;
  *)
    printf 'ERROR: refusing to start Aider on branch %s.\n' "${branch:-detached}" >&2
    printf 'Switch to or create an agent/aider-* branch first.\n' >&2
    exit 2
    ;;
esac

if ! command -v aider >/dev/null 2>&1; then
  printf 'ERROR: aider is not installed or is not on PATH. Run scripts/setup-aider-local.sh first.\n' >&2
  exit 3
fi

if ! command -v ollama >/dev/null 2>&1; then
  printf 'ERROR: ollama is not installed. Run scripts/setup-aider-local.sh first.\n' >&2
  exit 4
fi

model="${FLUX2_AIDER_MODEL:-qwen2.5-coder:3b}"
endpoint=""
for candidate in "${OLLAMA_API_BASE:-}" "http://127.0.0.1:11434" "http://172.17.0.1:11434"; do
  [[ -n "$candidate" ]] || continue
  if curl -fsS --max-time 2 "$candidate/api/tags" >/dev/null 2>&1; then
    endpoint="$candidate"
    break
  fi
done

if [[ -z "$endpoint" ]]; then
  printf 'ERROR: no Ollama API responded on the configured or common local endpoints.\n' >&2
  printf 'Try: sudo systemctl start ollama\n' >&2
  printf 'Then verify: curl http://127.0.0.1:11434/api/tags\n' >&2
  exit 5
fi

export OLLAMA_API_BASE="$endpoint"
export OLLAMA_HOST="${endpoint#http://}"

if ! ollama list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$model"; then
  printf 'Local model %s is missing; pulling it now.\n' "$model"
  ollama pull "$model"
fi

chmod +x .githooks/post-commit scripts/start-aider-local.sh scripts/setup-aider-local.sh 2>/dev/null || true
git config core.hooksPath .githooks

printf '\nFLUX2 local Aider session\n'
printf '  repository: %s\n' "$ROOT"
printf '  branch:     %s\n' "$branch"
printf '  model:      ollama_chat/%s\n' "$model"
printf '  endpoint:   %s\n' "$OLLAMA_API_BASE"
printf '  auto-push:  guarded post-commit push to origin/%s\n\n' "$branch"

git status --short --branch
git log -5 --oneline --decorate

cat <<'GUIDE'

Recommended interaction:
  /ask <goal>       inspect, discuss, and agree on one thin slice
  /code <approved>  implement that slice
  /diff             inspect the latest changes
  /test <command>   run validation and feed failures back to Aider
  /undo             undo Aider's most recent commit
  /git status       inspect exact Git state

Aider can edit repository text files and run commands you explicitly invoke.
It does not receive unrestricted root access, and destructive/system actions require your approval.
GUIDE

set +e
aider --config .aider.conf.yml --model "ollama_chat/$model" "$@"
status=$?
set -e

printf '\nAider exited with status %s. Current repository state:\n' "$status"
git status --short --branch
git log -5 --oneline --decorate

if git diff --quiet && git diff --cached --quiet; then
  if ! git push --set-upstream origin "HEAD:$branch"; then
    printf 'WARNING: final push failed; all local commits remain intact.\n' >&2
  fi
else
  printf 'WARNING: uncommitted files remain; inspect them before committing or pushing.\n' >&2
fi

exit "$status"
