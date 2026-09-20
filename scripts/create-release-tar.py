#!/usr/bin/env python3
"""Create a deterministic Linux friend bundle with executable launch files."""

from __future__ import annotations

import gzip
import pathlib
import sys
import tarfile


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} BUNDLE_DIRECTORY OUTPUT.tar.gz", file=sys.stderr)
        return 2
    source = pathlib.Path(sys.argv[1]).resolve(strict=True)
    output = pathlib.Path(sys.argv[2]).resolve(strict=False)
    if not source.is_dir():
        print(f"Bundle directory does not exist: {source}", file=sys.stderr)
        return 1
    output.parent.mkdir(parents=True, exist_ok=True)
    executable_names = {"flux2.x86_64", "play-flux.sh"}
    with output.open("wb") as raw_file:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw_file, compresslevel=9, mtime=0) as gzip_file:
            with tarfile.open(fileobj=gzip_file, mode="w", format=tarfile.PAX_FORMAT) as archive:
                root_info = tarfile.TarInfo(".")
                root_info.type = tarfile.DIRTYPE
                root_info.mode = 0o755
                root_info.uid = root_info.gid = 0
                root_info.uname = root_info.gname = "root"
                root_info.mtime = 0
                archive.addfile(root_info)
                for path in sorted(source.rglob("*"), key=lambda item: item.as_posix().lower()):
                    if path.is_symlink() or not path.is_file():
                        raise ValueError(f"Release bundles only accept regular files: {path}")
                    info = archive.gettarinfo(str(path), arcname=path.relative_to(source).as_posix())
                    info.mode = 0o755 if path.name in executable_names else 0o644
                    info.uid = info.gid = 0
                    info.uname = info.gname = "root"
                    info.mtime = 0
                    with path.open("rb") as payload:
                        archive.addfile(info, payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
