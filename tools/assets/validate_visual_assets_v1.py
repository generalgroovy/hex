#!/usr/bin/env python3
"""Validate FLUX 2 visual asset foundation v1 without requiring Godot."""
from __future__ import annotations

import hashlib
import json
import zipfile
from pathlib import Path

from PIL import Image

EXPECTED_ATLAS_SIZE = (960, 1280)
EXPECTED_CELL = (32, 32)
EXPECTED_PIVOT = (16, 28)
EXPECTED_DIRECTIONS = 8
EXPECTED_ANIMATIONS = 25
EXPECTED_SIZES = 5


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path, errors: list[str]) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(errors, f"{path}: invalid JSON: {exc}")
        return {}


def check_png(path: Path, expected_size: tuple[int, int], errors: list[str], require_content: bool = True) -> None:
    if not path.is_file():
        fail(errors, f"missing PNG: {path}")
        return
    try:
        image = Image.open(path).convert("RGBA")
    except Exception as exc:
        fail(errors, f"unreadable PNG {path}: {exc}")
        return
    if image.size != expected_size:
        fail(errors, f"{path}: expected {expected_size}, got {image.size}")
    if require_content and image.getbbox() is None:
        fail(errors, f"{path}: fully transparent")


def main() -> int:
    repo = Path(__file__).resolve().parents[2]
    errors: list[str] = []
    manifest = load_json(repo / "content/animations/skeleton_animation_manifest_v1.json", errors)
    registry = load_json(repo / "content/visual/visual_asset_registry_v1.json", errors)
    hashes = load_json(repo / "content/visual/visual_asset_hashes_v1.json", errors)

    if manifest:
        if tuple(manifest.get("cell_size", [])) != EXPECTED_CELL:
            fail(errors, "skeleton cell size contract changed")
        if tuple(manifest.get("pivot", [])) != EXPECTED_PIVOT:
            fail(errors, "skeleton pivot contract changed")
        if len(manifest.get("direction_order", [])) != EXPECTED_DIRECTIONS:
            fail(errors, "skeleton direction count is not eight")
        if len(manifest.get("animations", {})) != EXPECTED_ANIMATIONS:
            fail(errors, "skeleton animation count is not 25")
        if len(manifest.get("sizes", {})) != EXPECTED_SIZES:
            fail(errors, "skeleton size count is not five")
        for size in manifest.get("sizes", {}).values():
            for key in ("atlas", "debug_atlas"):
                check_png(repo / str(size.get(key, "")).removeprefix("res://"), EXPECTED_ATLAS_SIZE, errors)

    if registry:
        champion = registry.get("champions", {}).get("nico_lai", {})
        check_png(repo / str(champion.get("atlas", "")).removeprefix("res://"), EXPECTED_ATLAS_SIZE, errors)
        check_png(repo / str(champion.get("debug_atlas", "")).removeprefix("res://"), EXPECTED_ATLAS_SIZE, errors)
        check_png(repo / str(champion.get("direction_preview", "")).removeprefix("res://"), (1024, 128), errors)
        environment = registry.get("environment", {})
        check_png(repo / str(environment.get("sanctum_tiles", {}).get("path", "")).removeprefix("res://"), (256, 256), errors)
        check_png(repo / str(environment.get("nexus_to_conservatory", {}).get("preview", "")).removeprefix("res://"), (1280, 720), errors)
        check_png(repo / str(registry.get("materials", {}).get("path", "")).removeprefix("res://"), (176, 16), errors)
        check_png(repo / str(registry.get("icons", {}).get("elements", {}).get("path", "")).removeprefix("res://"), (128, 16), errors)
        check_png(repo / str(registry.get("icons", {}).get("abilities", {}).get("path", "")).removeprefix("res://"), (192, 32), errors)
        check_png(repo / str(registry.get("icons", {}).get("ui_states", {}).get("path", "")).removeprefix("res://"), (192, 16), errors)

    archive = repo / "assets/sprites/skeletons/skeleton_animation_pngs_v1.zip"
    if not archive.is_file():
        fail(errors, f"missing archive: {archive}")
    else:
        try:
            with zipfile.ZipFile(archive) as package:
                names = [name for name in package.namelist() if name.endswith(".png")]
                expected = EXPECTED_SIZES * EXPECTED_ANIMATIONS
                if len(names) != expected:
                    fail(errors, f"animation archive contains {len(names)} PNGs; expected {expected}")
                bad = package.testzip()
                if bad:
                    fail(errors, f"animation archive CRC failure: {bad}")
        except Exception as exc:
            fail(errors, f"invalid animation archive: {exc}")

    if hashes:
        for entry in hashes.get("files", []):
            path = repo / entry.get("path", "")
            if not path.is_file():
                fail(errors, f"hash manifest missing file: {path}")
                continue
            if path.stat().st_size != int(entry.get("bytes", -1)):
                fail(errors, f"size mismatch: {path}")
            if sha256(path) != entry.get("sha256"):
                fail(errors, f"SHA-256 mismatch: {path}")

    if errors:
        print("visual asset validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("visual asset validation passed")
    print("5 skeleton sizes x 25 animations x 8 directions")
    print("Nico Lai candidate, Sanctum tiles/layout, material/element/ability/UI assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
