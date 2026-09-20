#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}"
[[ -n "$godot_bin" ]] || {
  printf 'Godot is missing. Run scripts/install-godot.sh while connected.\n' >&2
  exit 1
}
"$repo_root/scripts/doctor.sh"

test_log="$(mktemp)"
trap 'rm -f -- "$test_log"' EXIT

run_godot_checked() {
  : >"$test_log"
  "$godot_bin" "$@" 2>&1 | tee "$test_log"
  if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call' "$test_log"; then
    printf 'Godot emitted a script/import/runtime error despite its process status.\n' >&2
    return 1
  fi
}

run_godot_checked --headless --path "$repo_root" --import
run_godot_checked --headless --path "$repo_root" --script tests/run_all.gd
for tick_rate in 60 120; do
  run_godot_checked --headless --path "$repo_root" --quit-after 5 -- --tick-rate="$tick_rate"
done
