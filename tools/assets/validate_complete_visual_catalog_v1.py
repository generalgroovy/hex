#!/usr/bin/env python3
"""Validate the complete FLUX 2 visual catalog and reproducibility manifest."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/visual/complete_visual_catalog_v1.json"
HASH_PATH = ROOT / "content/visual/complete_visual_hashes_v1.json"
ATLAS_SIZE = (960, 1280)


def load_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{path}: invalid JSON: {exc}")
        return {}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resource_path(value: str) -> Path:
    return ROOT / value.removeprefix("res://")


def check_image(path: Path, expected: tuple[int, int], errors: list[str]) -> None:
    if not path.is_file():
        errors.append(f"missing image: {path}")
        return
    try:
        image = Image.open(path).convert("RGBA")
    except Exception as exc:
        errors.append(f"invalid image {path}: {exc}")
        return
    if image.size != expected:
        errors.append(f"{path}: expected {expected}, got {image.size}")
    if image.getbbox() is None:
        errors.append(f"{path}: image is fully transparent")


def main() -> int:
    errors: list[str] = []
    catalog = load_json(CATALOG_PATH, errors)
    hashes = load_json(HASH_PATH, errors)
    if not catalog or not hashes:
        for error in errors:
            print(error)
        return 1

    contract = catalog.get("character_contract", {})
    if contract.get("cell_size") != [32, 32]:
        errors.append("character cell contract must remain 32 x 32")
    if contract.get("pivot") != [16, 28]:
        errors.append("character pivot contract must remain (16, 28)")
    if len(contract.get("directions", [])) != 8:
        errors.append("character direction contract must contain eight directions")
    if len(contract.get("animations", [])) != 25:
        errors.append("character animation contract must contain 25 states")

    ancestries = catalog.get("ancestries", {})
    champions = catalog.get("champions", {})
    districts = catalog.get("districts", {})
    if len(ancestries) != 23:
        errors.append(f"expected 23 ancestry/body plans, found {len(ancestries)}")
    if len(champions) != 24:
        errors.append(f"expected 24 champion slots, found {len(champions)}")
    if len(districts) != 9:
        errors.append(f"expected nine Sanctum districts, found {len(districts)}")

    provisional = {"weaverkin", "scorpionkin", "harvestkin"}
    for ancestry_id, entry in ancestries.items():
        expected_status = "body_plan_candidate" if ancestry_id in provisional else "production_foundation"
        if entry.get("status") != expected_status:
            errors.append(f"{ancestry_id}: invalid status {entry.get('status')}")
        check_image(resource_path(str(entry.get("atlas", ""))), ATLAS_SIZE, errors)
        check_image(resource_path(str(entry.get("debug_atlas", ""))), ATLAS_SIZE, errors)
        check_image(resource_path(str(entry.get("preview", ""))), (1024, 128), errors)

    for champion_id, entry in champions.items():
        if champion_id == "unnamed_angel":
            if entry.get("status") != "placeholder_unapproved":
                errors.append("Unnamed Angel must remain placeholder_unapproved")
        elif entry.get("status") != "integrated_candidate":
            errors.append(f"{champion_id}: must remain integrated_candidate")
        if entry.get("ancestry") not in ancestries:
            errors.append(f"{champion_id}: unknown ancestry {entry.get('ancestry')}")
        check_image(resource_path(str(entry.get("atlas", ""))), ATLAS_SIZE, errors)
        check_image(resource_path(str(entry.get("debug_atlas", ""))), ATLAS_SIZE, errors)
        check_image(resource_path(str(entry.get("direction_preview", ""))), (1024, 128), errors)
        check_image(resource_path(str(entry.get("portrait", ""))), (64, 64), errors)
        check_image(resource_path(str(entry.get("selection_icon", ""))), (32, 32), errors)

    for district_id, entry in districts.items():
        if entry.get("status") != "presentation_only":
            errors.append(f"{district_id}: district must remain presentation_only")
        check_image(resource_path(str(entry.get("preview", ""))), (1280, 720), errors)
        layout_path = resource_path(str(entry.get("layout", "")))
        layout = load_json(layout_path, errors)
        if layout:
            if layout.get("authority") != "presentation_only":
                errors.append(f"{district_id}: layout authority must remain presentation_only")
            if layout.get("tile_size") != [16, 16] or layout.get("size_tiles") != [80, 45]:
                errors.append(f"{district_id}: invalid tile dimensions")
            if len(layout.get("rows_rle", [])) != 45:
                errors.append(f"{district_id}: visual layout must contain 45 rows")
            if len(layout.get("worldbone_mask_rows", [])) != 45:
                errors.append(f"{district_id}: worldbone presentation mask must contain 45 rows")
            if not layout.get("landmarks") or not layout.get("routes"):
                errors.append(f"{district_id}: missing landmarks or routes")

    props = catalog.get("props", {})
    if len(props.get("order", [])) != 16 or len(props.get("states", [])) != 8:
        errors.append("world interaction prop atlas must contain 16 props x 8 states")
    check_image(resource_path(str(props.get("path", ""))), (512, 256), errors)

    vfx = catalog.get("element_vfx", {})
    if len(vfx.get("elements", [])) != 8 or len(vfx.get("phases", [])) != 6:
        errors.append("element VFX atlas must contain eight elements x six phases")
    check_image(resource_path(str(vfx.get("path", ""))), (192, 256), errors)
    check_image(resource_path(str(catalog.get("ui", {}).get("skin", ""))), (256, 256), errors)
    check_image(resource_path(str(catalog.get("overviews", {}).get("roster", ""))), (768, 512), errors)
    check_image(resource_path(str(catalog.get("overviews", {}).get("districts", ""))), (960, 720), errors)

    seen: set[str] = set()
    for entry in hashes.get("files", []):
        relative = str(entry.get("path", ""))
        if relative in seen:
            errors.append(f"duplicate hash entry: {relative}")
            continue
        seen.add(relative)
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"hash manifest references missing file: {relative}")
            continue
        if path.stat().st_size != int(entry.get("bytes", -1)):
            errors.append(f"hash byte-size mismatch: {relative}")
        if sha256(path) != entry.get("sha256"):
            errors.append(f"hash mismatch: {relative}")

    expected_minimum = 23 * 3 + 24 * 5 + 9 * 2 + 6
    if len(seen) < expected_minimum:
        errors.append(f"hash manifest is incomplete: {len(seen)} entries; expected at least {expected_minimum}")

    if errors:
        print("complete visual catalog validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("complete visual catalog validation passed")
    print("23 body plans, 24 champion slots, nine Sanctum districts")
    print("16 interaction props x eight states, eight element VFX families x six phases")
    print(f"verified {len(seen)} SHA-256 entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
