#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$repo_root/toolchains/godot.env"
godot_bin="${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}"
target="${1:-all}"

case "$target" in
  windows|linux|all) ;;
  *) printf 'Usage: %s [windows|linux|all]\n' "$0" >&2; exit 2 ;;
esac
[[ -n "$godot_bin" ]] || {
  printf 'Godot is missing. Run scripts/install-godot.sh while connected.\n' >&2
  exit 1
}
"$repo_root/scripts/doctor.sh"
template_root="${GODOT_EXPORT_TEMPLATE_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable}"

export_one() {
  local preset="$1"
  local relative_path="$2"
  local output="$repo_root/exports/$relative_path"
  mkdir -p -- "$(dirname -- "$output")"
  "$godot_bin" --headless --path "$repo_root" --export-release "$preset" "$output"
  [[ -f "$output" ]] || {
    printf 'FAIL: export did not create %s\n' "$output" >&2
    return 1
  }
}

required_templates=()
if [[ "$target" == "windows" || "$target" == "all" ]]; then required_templates+=(windows_release_x86_64.exe); fi
if [[ "$target" == "linux" || "$target" == "all" ]]; then required_templates+=(linux_release.x86_64); fi
missing_templates=()
for template in "${required_templates[@]}"; do
  [[ -f "$template_root/$template" ]] || missing_templates+=("$template")
done
if (( ${#missing_templates[@]} > 0 )); then
  printf 'FAIL: Godot %s %s release templates are missing at %s (%s).\n' "$GODOT_VERSION" "$target" "$template_root" "${missing_templates[*]}" >&2
  printf 'Install the matching official templates once in the pinned editor, then rerun.\n' >&2
  exit 1
fi

if [[ "$target" == "windows" || "$target" == "all" ]]; then
  export_one 'Windows x86_64' 'windows/flux2.exe'
fi
if [[ "$target" == "linux" || "$target" == "all" ]]; then
  export_one 'Linux x86_64' 'linux/flux2.x86_64'
  chmod 0755 "$repo_root/exports/linux/flux2.x86_64"
fi

(
  cd -- "$repo_root/exports"
  find . -type f ! -name SHA256SUMS.txt -print0 \
    | sort -z \
    | xargs -0 sha256sum \
    | sed 's#  \./#  #' > SHA256SUMS.txt
)
"$repo_root/scripts/bundle-release.sh" "$target" "$repo_root/exports" "$repo_root/exports/release"
printf 'PASS: release exports, portable archives and checksums written to %s/exports\n' "$repo_root"
