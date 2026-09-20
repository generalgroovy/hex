#!/usr/bin/env bash
set -Eeuo pipefail

flux_bundle_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
flux_program="$flux_bundle_root/flux2.x86_64"
if [[ ! -x "$flux_program" ]]; then
  printf 'FLUX 2 could not start because %s is missing or not executable.\n' "$flux_program" >&2
  printf 'Extract the complete archive and try again.\n' >&2
  exit 2
fi
exec "$flux_program" "$@"
