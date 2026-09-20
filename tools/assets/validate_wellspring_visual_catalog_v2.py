#!/usr/bin/env python3
"""Validate all Wellspring v2 visual-production outputs."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image

import generate_visual_assets_v1 as base
from wellspring_catalog_data_v2 import (
    DIRECTIONS, DISTRICTS, ELEMENTS, MATERIALS, MATERIAL_STATES, PRESENTATIONS,
    PROPS, PROP_STATES, RACES, SIZE_IDS, UI_SURFACES, VFX_PHASES,
)
from wellspring_environment_v2 import MAP_PIXELS
from wellspring_pixel_art_v2 import ATLAS_SIZE

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/visual/wellspring_visual_catalog_v2.json"
HASH_PATH = ROOT / "content/visual/wellspring_visual_hashes_v2.json"


def load_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}: invalid JSON: {exc}")
        return {}


def resource_path(value: str) -> Path:
    if not value.startswith("res://"):
        return ROOT / "__invalid_resource_path__"
    return ROOT / value.removeprefix("res://")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_image(path: Path, expected: tuple[int, int], errors: list[str], nonempty: bool = True) -> None:
    if not path.is_file():
        errors.append(f"missing image: {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")
        return
    try:
        with Image.open(path) as image:
            if image.size != expected:
                errors.append(f"{path.relative_to(ROOT)}: expected {expected}, got {image.size}")
            if image.mode not in {"RGBA", "RGB", "P", "LA"}:
                errors.append(f"{path.relative_to(ROOT)}: unsupported mode {image.mode}")
            if nonempty and image.convert("RGBA").getbbox() is None:
                errors.append(f"{path.relative_to(ROOT)}: image is fully transparent")
    except Exception as exc:
        errors.append(f"{path.relative_to(ROOT)}: invalid image: {exc}")


def check_character_package(entry: dict[str, Any], label: str, errors: list[str], debug_required: bool = True) -> None:
    checks = {
        "atlas": ATLAS_SIZE,
        "direction_preview": (1024, 128),
        "keyframe_board": (640, 640),
        "selection_icon": (48, 48),
        "hud_portrait": (64, 64),
        "roster_portrait": (128, 128),
        "hero_portrait": (256, 256),
    }
    if debug_required:
        checks["debug_atlas"] = ATLAS_SIZE
    for key, expected in checks.items():
        value = str(entry.get(key, ""))
        if not value:
            errors.append(f"{label}: missing {key} path")
            continue
        check_image(resource_path(value), expected, errors)
    if entry.get("all_keyframes_included") is not True:
        errors.append(f"{label}: all_keyframes_included must be true")
    if int(entry.get("animation_count", -1)) != len(base.A):
        errors.append(f"{label}: animation_count mismatch")
    if int(entry.get("direction_count", -1)) != len(DIRECTIONS):
        errors.append(f"{label}: direction_count mismatch")


def decode_rle(row: list[list[Any]], errors: list[str], label: str) -> list[Any]:
    result: list[Any] = []
    for item in row:
        if not isinstance(item, list) or len(item) != 2:
            errors.append(f"{label}: malformed RLE item {item}")
            continue
        value, count = item
        if not isinstance(count, int) or count <= 0:
            errors.append(f"{label}: invalid RLE count {count}")
            continue
        result.extend([value] * count)
    return result


def main() -> int:
    errors: list[str] = []
    catalog = load_json(CATALOG_PATH, errors)
    hashes = load_json(HASH_PATH, errors)
    if not catalog or not hashes:
        for error in errors:
            print(error)
        return 1

    if catalog.get("schema_version") != 2:
        errors.append("catalog schema_version must be 2")
    if catalog.get("id") != "wellspring-visual-catalog-v2":
        errors.append("catalog id must be wellspring-visual-catalog-v2")

    contract = catalog.get("character_contract", {})
    if contract.get("cell_size") != [64, 64]:
        errors.append("character cell_size must be 64 x 64")
    if contract.get("pivot") != [32, 56]:
        errors.append("character pivot must be (32, 56)")
    if tuple(contract.get("atlas_size", [])) != ATLAS_SIZE:
        errors.append(f"character atlas_size must be {ATLAS_SIZE}")
    if contract.get("directions") != list(DIRECTIONS):
        errors.append("direction order mismatch")
    animations = contract.get("animations", [])
    if len(animations) != len(base.A):
        errors.append(f"expected {len(base.A)} animations, found {len(animations)}")
    else:
        for animation in animations:
            animation_id = animation.get("id")
            if animation_id not in base.A:
                errors.append(f"unknown animation {animation_id}")
                continue
            expected = base.A[animation_id]
            if animation.get("block") != [expected[0], expected[1]]:
                errors.append(f"{animation_id}: atlas block mismatch")
            if animation.get("frames") != expected[2] or animation.get("fps") != expected[3]:
                errors.append(f"{animation_id}: frame or fps mismatch")

    races = catalog.get("races", {})
    if set(races) != set(RACES):
        errors.append(f"race catalog mismatch: expected {sorted(RACES)}, found {sorted(races)}")
    for race_id, definition in RACES.items():
        entry = races.get(race_id, {})
        if entry.get("name") != definition["name"]:
            errors.append(f"{race_id}: display name mismatch")
        if entry.get("status") != "production_foundation":
            errors.append(f"{race_id}: status must be production_foundation")
        if entry.get("supported_sizes") != list(SIZE_IDS):
            errors.append(f"{race_id}: must include all five size foundations")
        if entry.get("presentations") != list(PRESENTATIONS):
            errors.append(f"{race_id}: must include masculine and feminine foundations")
        matrix_path = resource_path(str(entry.get("matrix_preview", "")))
        check_image(matrix_path, (800, 384), errors)
        variants = entry.get("base_variants", {})
        if set(variants) != set(SIZE_IDS):
            errors.append(f"{race_id}: size matrix mismatch")
            continue
        for size_id in SIZE_IDS:
            size_entry = variants.get(size_id, {})
            if set(size_entry) != set(PRESENTATIONS):
                errors.append(f"{race_id}/{size_id}: presentation matrix mismatch")
                continue
            for presentation in PRESENTATIONS:
                variant = size_entry[presentation]
                check_image(resource_path(str(variant.get("atlas", ""))), ATLAS_SIZE, errors)
                if variant.get("all_keyframes_included") is not True:
                    errors.append(f"{race_id}/{size_id}/{presentation}: all keyframes missing")
                if int(variant.get("animation_count", -1)) != len(base.A):
                    errors.append(f"{race_id}/{size_id}/{presentation}: animation count mismatch")
                if int(variant.get("direction_count", -1)) != len(DIRECTIONS):
                    errors.append(f"{race_id}/{size_id}/{presentation}: direction count mismatch")
        exemplar = entry.get("exemplar", {})
        if not exemplar.get("name"):
            errors.append(f"{race_id}: missing named exemplar")
        check_character_package(exemplar, f"{race_id} exemplar", errors)

    champions = catalog.get("champions", {})
    if len(champions) != 24:
        errors.append(f"expected 24 champion packages, found {len(champions)}")
    for champion_id, entry in champions.items():
        ancestry = entry.get("ancestry")
        if ancestry not in races:
            errors.append(f"{champion_id}: unknown ancestry {ancestry}")
        if champion_id == "unnamed_angel":
            if entry.get("status") != "placeholder_unapproved":
                errors.append("unnamed_angel must remain placeholder_unapproved")
        elif entry.get("status") != "integrated_candidate":
            errors.append(f"{champion_id}: status must be integrated_candidate")
        check_character_package(entry, f"champion {champion_id}", errors)
    check_image(resource_path(str(catalog.get("overviews", {}).get("champions", ""))), (1056, 736), errors)

    wellspring = catalog.get("wellspring", {})
    if wellspring.get("id") != "wellspring" or wellspring.get("name") != "The Wellspring":
        errors.append("Wellspring identity mismatch")
    if "sanctum" not in wellspring.get("legacy_aliases", []):
        errors.append("Wellspring must preserve deprecated Sanctum alias")
    check_image(resource_path(str(wellspring.get("tileset", ""))), (256, 176), errors)
    check_image(resource_path(str(wellspring.get("cosmic_cascade", ""))), (512, 128), errors)
    check_image(resource_path(str(wellspring.get("overview_1440p", ""))), (2560, 1440), errors)
    tile_registry = load_json(resource_path(str(wellspring.get("tile_registry", ""))), errors)
    if len(tile_registry.get("tiles", {})) < 160:
        errors.append("Wellspring tile registry is incomplete")

    districts = wellspring.get("districts", {})
    expected_districts = {district["id"] for district in DISTRICTS}
    if set(districts) != expected_districts:
        errors.append("Wellspring district catalog mismatch")
    for district_id, entry in districts.items():
        if entry.get("status") != "integrated_candidate":
            errors.append(f"{district_id}: status must be integrated_candidate")
        check_image(resource_path(str(entry.get("preview", ""))), MAP_PIXELS, errors)
        layout = load_json(resource_path(str(entry.get("layout", ""))), errors)
        if not layout:
            continue
        if layout.get("authority") != "integrated_candidate":
            errors.append(f"{district_id}: layout authority mismatch")
        if layout.get("tile_size") != [16, 16] or layout.get("size_tiles") != [80, 45]:
            errors.append(f"{district_id}: invalid tile dimensions")
        for key in ("rows_rle", "collision_rows", "worldbone_rows", "navigation_rows", "elevation_rows"):
            rows = layout.get(key, [])
            if len(rows) != 45:
                errors.append(f"{district_id}: {key} must contain 45 rows")
                continue
            for row_index, row in enumerate(rows):
                decoded = decode_rle(row, errors, f"{district_id}/{key}/{row_index}")
                if len(decoded) != 80:
                    errors.append(f"{district_id}: {key} row {row_index} expands to {len(decoded)}, expected 80")
        if not layout.get("landmarks") or not layout.get("routes"):
            errors.append(f"{district_id}: landmarks and routes are required")
    source_layout = load_json(resource_path(str(districts.get("source_court", {}).get("layout", ""))), errors)
    if not any(item.get("id") == "cosmic_wellspring" for item in source_layout.get("landmarks", [])):
        errors.append("Source Court must contain the Cosmic Wellspring landmark")

    materials = catalog.get("materials", {})
    if materials.get("materials") != list(MATERIALS) or materials.get("states") != list(MATERIAL_STATES):
        errors.append("material catalog mismatch")
    check_image(resource_path(str(materials.get("path", ""))), (352, 384), errors)

    props = catalog.get("props", {})
    if props.get("props") != list(PROPS) or props.get("states") != list(PROP_STATES):
        errors.append("prop catalog mismatch")
    check_image(resource_path(str(props.get("path", ""))), (960, 528), errors)

    vfx = catalog.get("element_vfx", {})
    if vfx.get("elements") != list(ELEMENTS) or vfx.get("phases") != list(VFX_PHASES):
        errors.append("element VFX catalog mismatch")
    if vfx.get("frames_per_phase") != 4:
        errors.append("element VFX requires four frames per phase")
    check_image(resource_path(str(vfx.get("path", ""))), (1024, 256), errors)
    check_image(resource_path(str(catalog.get("icons", {}).get("elements", ""))), (256, 32), errors)

    ui = catalog.get("ui", {})
    if ui.get("surfaces") != list(UI_SURFACES):
        errors.append("UI surface catalog mismatch")
    if ui.get("virtual_viewport") != [640, 360]:
        errors.append("UI virtual viewport must be 640 x 360")
    if ui.get("integer_scales") != {"1920x1080": 3, "2560x1440": 4, "3840x2160": 6}:
        errors.append("UI integer scaling contract mismatch")
    check_image(resource_path(str(ui.get("skin", ""))), (512, 512), errors)
    check_image(resource_path(str(ui.get("surface_overview", ""))), (1280, 800), errors)

    required_docs = (
        ROOT / "docs/WELLSPRING-VISUAL-PRODUCTION.md",
        ROOT / "assets/sprites/races_v2/README.md",
        ROOT / "assets/sprites/champions_v2/README.md",
        ROOT / "assets/maps/wellspring/README.md",
        ROOT / "assets/ui/wellspring_v2/README.md",
        ROOT / "content/maps/wellspring_hub_v2.json",
        ROOT / "content/maps/sanctum_to_wellspring_alias_v2.json",
    )
    for path in required_docs:
        if not path.is_file() or path.stat().st_size == 0:
            errors.append(f"missing required documentation/content file: {path.relative_to(ROOT)}")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    if "The Wellspring" not in readme or "WELLSPRING_VISUAL_V2" not in readme:
        errors.append("root README does not expose the Wellspring visual catalog")

    seen: set[str] = set()
    for item in hashes.get("files", []):
        relative = str(item.get("path", ""))
        if relative in seen:
            errors.append(f"duplicate hash entry: {relative}")
            continue
        seen.add(relative)
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"hash references missing file: {relative}")
            continue
        if path.stat().st_size != int(item.get("bytes", -1)):
            errors.append(f"hash byte count mismatch: {relative}")
        if sha256(path) != item.get("sha256"):
            errors.append(f"hash mismatch: {relative}")
    expected_minimum = (
        len(RACES) * len(SIZE_IDS) * len(PRESENTATIONS)
        + len(RACES) * 9
        + 24 * 8
        + len(DISTRICTS) * 2
        + 20
    )
    if len(seen) < expected_minimum:
        errors.append(f"hash manifest incomplete: {len(seen)} entries, expected at least {expected_minimum}")

    if errors:
        print("Wellspring visual catalog v2 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Wellspring visual catalog v2 validation passed")
    print(f"{len(RACES)} races x {len(SIZE_IDS)} sizes x {len(PRESENTATIONS)} presentations")
    print(f"{len(RACES)} race exemplars, {len(champions)} champion packages")
    print(f"{len(districts)} Wellspring districts, Cosmic Wellspring cascade present")
    print(f"verified {len(seen)} SHA-256 entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
