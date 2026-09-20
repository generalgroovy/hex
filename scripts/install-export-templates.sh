#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$repo_root/toolchains/godot.env"
python_bin="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"
[[ -n "$python_bin" ]] || { printf 'Python 3 is required to install export templates.\n' >&2; exit 1; }
destination="${GODOT_EXPORT_TEMPLATE_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable}"
url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
"$python_bin" "$repo_root/scripts/fetch-export-templates.py" \
  --url "$url" \
  --size 1280486955 \
  --destination "$destination"
for template in linux_release.x86_64 windows_release_x86_64.exe; do
  [[ -f "$destination/$template" ]] || { printf 'Missing installed template: %s\n' "$template" >&2; exit 1; }
done
printf 'PASS: Godot %s Windows/Linux release templates are ready at %s\n' "$GODOT_VERSION" "$destination"
