#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
export_root="${2:-$repo_root/exports}"
release_root="${3:-$export_root/release}"

case "$target" in
  windows|linux|all) ;;
  *) printf 'Usage: %s [windows|linux|all] [export-root] [release-root]\n' "$0" >&2; exit 2 ;;
esac

safe_reset_dir() {
  local destination="$1"
  [[ "$destination" == "$release_root"/* ]] || {
    printf 'Refusing to modify a path outside %s: %s\n' "$release_root" "$destination" >&2
    return 1
  }
  rm -rf -- "$destination"
  mkdir -p -- "$destination"
}

write_manifest() {
  local directory="$1"
  (
    cd -- "$directory"
    find . -maxdepth 1 -type f ! -name SHA256SUMS.txt -print0 \
      | sort -z \
      | xargs -0 -r sha256sum \
      | sed 's#  \./#  #' > SHA256SUMS.txt
  )
}

mkdir -p -- "$release_root"

if [[ "$target" == "windows" || "$target" == "all" ]]; then
  source_dir="$export_root/windows"
  [[ -f "$source_dir/flux2.exe" ]] || { printf 'Windows export is missing flux2.exe at %s\n' "$source_dir" >&2; exit 1; }
  bundle="$release_root/FLUX2-Windows-x86_64"
  safe_reset_dir "$bundle"
  find "$source_dir" -maxdepth 1 -type f -exec cp -- '{}' "$bundle/" \;
  cp -- "$repo_root/packaging/PLAY-FLUX.cmd" "$repo_root/packaging/README-FIRST.txt" "$bundle/"
  write_manifest "$bundle"
  rm -f -- "$release_root/FLUX2-Windows-x86_64.zip"
  (cd -- "$bundle" && zip -q -9 "$release_root/FLUX2-Windows-x86_64.zip" ./*)
fi

if [[ "$target" == "linux" || "$target" == "all" ]]; then
  source_dir="$export_root/linux"
  [[ -f "$source_dir/flux2.x86_64" ]] || { printf 'Linux export is missing flux2.x86_64 at %s\n' "$source_dir" >&2; exit 1; }
  bundle="$release_root/FLUX2-Linux-x86_64"
  safe_reset_dir "$bundle"
  find "$source_dir" -maxdepth 1 -type f -exec cp -- '{}' "$bundle/" \;
  cp -- "$repo_root/packaging/play-flux.sh" "$repo_root/packaging/README-FIRST.txt" "$bundle/"
  chmod 0755 "$bundle/flux2.x86_64" "$bundle/play-flux.sh"
  write_manifest "$bundle"
  rm -f -- "$release_root/FLUX2-Linux-x86_64.tar.gz"
  tar -czf "$release_root/FLUX2-Linux-x86_64.tar.gz" -C "$bundle" .
fi

(
  cd -- "$release_root"
  find . -maxdepth 1 -type f ! -name SHA256SUMS.txt -print0 \
    | sort -z \
    | xargs -0 -r sha256sum \
    | sed 's#  \./#  #' > SHA256SUMS.txt
)
printf 'PASS: portable %s bundle(s) written to %s\n' "$target" "$release_root"
