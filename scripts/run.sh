#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tick_rate="${FLUX2_TICK_RATE:-120}"
[[ "$tick_rate" == "60" || "$tick_rate" == "120" ]] || {
  printf 'FLUX2_TICK_RATE must be 60 or 120.\n' >&2
  exit 2
}
godot_bin="${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}"
[[ -n "$godot_bin" ]] || {
  printf 'Godot is missing. Run scripts/install-godot.sh while connected.\n' >&2
  exit 1
}
exec "$godot_bin" --path "$repo_root" -- --tick-rate="$tick_rate" "$@"
