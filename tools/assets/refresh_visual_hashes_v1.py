#!/usr/bin/env python3
"""Refresh the legacy v1 visual hash manifest after compatible catalog overlays.

The complete-v1 generator intentionally reuses the original Nico Lai public paths.
This helper keeps the legacy integrity manifest synchronized with the final files
without changing the registry contract or granting visual data gameplay authority.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
HASH_PATH = ROOT / "content/visual/visual_asset_hashes_v1.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    data: dict[str, Any] = json.loads(HASH_PATH.read_text(encoding="utf-8"))
    files = data.get("files", [])
    if not isinstance(files, list) or not files:
        raise SystemExit("legacy visual hash manifest has no files")

    seen: set[str] = set()
    refreshed: list[dict[str, Any]] = []
    for entry in files:
        relative = str(entry.get("path", ""))
        if not relative or relative in seen:
            raise SystemExit(f"invalid or duplicate legacy hash path: {relative}")
        seen.add(relative)
        path = ROOT / relative
        if not path.is_file():
            raise SystemExit(f"legacy hash path is missing: {relative}")
        refreshed.append({
            "path": relative,
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    data["files"] = refreshed
    data["refreshed_after"] = "tools/assets/generate_complete_visual_catalog_v1.py"
    HASH_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"refreshed {len(refreshed)} legacy visual SHA-256 entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
