#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$repo_root/toolchains/godot.env"
godot_bin="${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}"
require_templates=false
if [[ "${1:-}" == "--require-export-templates" ]]; then
  require_templates=true
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--require-export-templates]\n' "$0" >&2
  exit 2
fi

[[ -n "$godot_bin" ]] || {
  printf 'FAIL: Godot is missing. Run scripts/install-godot.sh while connected.\n' >&2
  exit 1
}
actual="$($godot_bin --version)"
[[ "$actual" == "$GODOT_BUILD" ]] || {
  printf 'FAIL: expected Godot %s, found %s\n' "$GODOT_BUILD" "$actual" >&2
  exit 1
}
for required in project.godot scenes/bootstrap/bootstrap.tscn tests/run_all.gd export_presets.cfg; do
  [[ -f "$repo_root/$required" ]] || {
    printf 'FAIL: missing %s\n' "$required" >&2
    exit 1
  }
done
printf 'OK: Godot %s and FLUX2 foundation are present.\n' "$actual"
template_root="${GODOT_EXPORT_TEMPLATE_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable}"
if [[ "$require_templates" == true ]]; then
  missing=()
  for required in linux_release.x86_64 windows_release_x86_64.exe; do
    [[ -f "$template_root/$required" ]] || missing+=("$required")
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'FAIL: Godot %s release templates are missing at %s (%s).\n' "$GODOT_VERSION" "$template_root" "${missing[*]}" >&2
    printf 'Install the matching official templates once in the pinned editor, then rerun. Source run/test remains available.\n' >&2
    exit 1
  fi
  printf 'Export templates: Windows/Linux ready at %s\n' "$template_root"
elif [[ -d "$template_root" ]]; then
  printf 'Export templates: %s\n' "$template_root"
else
  printf 'Export templates: missing (source run/test remains available)\n'
fi
