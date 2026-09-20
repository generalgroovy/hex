#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$repo_root/toolchains/godot.env"

install_root="${GODOT_INSTALL_ROOT:-$HOME/.local/share/godot/$GODOT_VERSION}"
bin_root="${GODOT_BIN_ROOT:-$HOME/.local/bin}"
archive_path="${XDG_CACHE_HOME:-$HOME/.cache}/flux2/$GODOT_ARCHIVE"
binary="$install_root/Godot_v${GODOT_VERSION}-stable_linux.x86_64"

mkdir -p "$install_root" "$bin_root" "$(dirname -- "$archive_path")"
if [[ ! -f "$archive_path" ]] || ! printf '%s  %s\n' "$GODOT_SHA256" "$archive_path" | sha256sum --check --status; then
  curl -fL --retry 3 --output "$archive_path" "$GODOT_URL"
fi
printf '%s  %s\n' "$GODOT_SHA256" "$archive_path" | sha256sum --check
unzip -o "$archive_path" -d "$install_root"
chmod 0755 "$binary"
ln -sfn "$binary" "$bin_root/godot"
ln -sfn "$binary" "$bin_root/godot4"
"$binary" --version
