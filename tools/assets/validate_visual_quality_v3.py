#!/usr/bin/env python3
"""Measure structural visual quality for Wellspring runtime art.

This gate checks completeness, palette/value structure, occupied composition and
severe edge truncation. It intentionally allows small edge contacts from wings,
weapons, trails and ground shadows because those are valid in a fixed runtime
render envelope. Human art review remains authoritative for charm and style.
"""
from __future__ import annotations

import json
from pathlib import Path
from statistics import mean
from typing import Any

from PIL import Image, ImageStat

import generate_visual_assets_v1 as base

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/visual/wellspring_visual_catalog_v2.json"
CELL = 64
BLOCK_W = 384
BLOCK_H = 512


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def resource_path(value: str) -> Path:
    if not value.startswith("res://"):
        raise ValueError(f"invalid resource path: {value}")
    return ROOT / value.removeprefix("res://")


def color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    colors = rgba.getcolors(maxcolors=rgba.width * rgba.height)
    if colors is None:
        return rgba.width * rgba.height
    return len([color for count, color in colors if color[3] > 0 and count > 0])


def occupied_ratio(image: Image.Image) -> float:
    bbox = image.convert("RGBA").getbbox()
    if bbox is None:
        return 0.0
    return ((bbox[2] - bbox[0]) * (bbox[3] - bbox[1])) / float(image.width * image.height)


def luminance_spread(image: Image.Image) -> float:
    rgba = image.convert("RGBA")
    background = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
    background.alpha_composite(rgba)
    return float(ImageStat.Stat(background.convert("L")).stddev[0])


def severe_edge_contact(frame: Image.Image) -> tuple[int, int, int]:
    alpha = frame.convert("RGBA").getchannel("A")
    top = sum(1 for x in range(CELL) if alpha.getpixel((x, 0)) > 0)
    left = sum(1 for y in range(CELL) if alpha.getpixel((0, y)) > 0)
    right = sum(1 for y in range(CELL) if alpha.getpixel((CELL - 1, y)) > 0)
    return top, left, right


def frame(atlas: Image.Image, animation: str, direction: int, frame_index: int) -> Image.Image:
    block_x, block_y, _frames, _fps = base.A[animation]
    x = block_x * BLOCK_W + frame_index * CELL
    y = block_y * BLOCK_H + direction * CELL
    return atlas.crop((x, y, x + CELL, y + CELL)).convert("RGBA")


def validate_character_package(entry: dict[str, Any], label: str, errors: list[str]) -> None:
    with Image.open(resource_path(str(entry["atlas"]))) as source:
        atlas = source.convert("RGBA")
    occupancies: list[float] = []
    palette_counts: list[int] = []
    severe_contacts = 0
    frame_total = 0

    for animation, (_bx, _by, frame_count, _fps) in base.A.items():
        for direction in range(8):
            for frame_index in range(frame_count):
                current = frame(atlas, animation, direction, frame_index)
                frame_total += 1
                if current.getbbox() is None:
                    errors.append(f"{label}: blank frame {animation}/{direction}/{frame_index}")
                    continue
                ratio = occupied_ratio(current)
                colors = color_count(current)
                occupancies.append(ratio)
                palette_counts.append(colors)
                if ratio < 0.025:
                    errors.append(f"{label}: underfilled frame {animation}/{direction}/{frame_index} ({ratio:.3f})")
                if colors < 4:
                    errors.append(f"{label}: flat frame {animation}/{direction}/{frame_index} ({colors} colors)")
                top, left, right = severe_edge_contact(current)
                if top > 28 or left > 32 or right > 32:
                    severe_contacts += 1

    if mean(occupancies or [0.0]) < 0.09:
        errors.append(f"{label}: average frame occupancy is too low ({mean(occupancies or [0.0]):.3f})")
    if min(palette_counts or [0]) < 4:
        errors.append(f"{label}: one or more frames lack palette structure")
    if severe_contacts > max(8, frame_total // 8):
        errors.append(f"{label}: {severe_contacts}/{frame_total} frames show severe top/side truncation")

    portrait_rules = (
        ("selection_icon", 10, 18.0),
        ("hud_portrait", 12, 20.0),
        ("roster_portrait", 16, 22.0),
        ("hero_portrait", 18, 24.0),
    )
    for key, minimum_colors, minimum_spread in portrait_rules:
        with Image.open(resource_path(str(entry[key]))) as source:
            portrait = source.convert("RGBA")
        colors = color_count(portrait)
        spread = luminance_spread(portrait)
        ratio = occupied_ratio(portrait)
        if colors < minimum_colors:
            errors.append(f"{label}: {key} has {colors} colors; expected at least {minimum_colors}")
        if spread < minimum_spread:
            errors.append(f"{label}: {key} value spread {spread:.2f} is too flat")
        if ratio < 0.70:
            errors.append(f"{label}: {key} composition occupies only {ratio:.2%}")


def validate_image_family(path: Path, label: str, errors: list[str], minimum_colors: int = 12, minimum_spread: float = 14.0) -> None:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    if image.getbbox() is None:
        errors.append(f"{label}: image is blank")
        return
    colors = color_count(image)
    spread = luminance_spread(image)
    if colors < minimum_colors:
        errors.append(f"{label}: only {colors} visible colors")
    if spread < minimum_spread:
        errors.append(f"{label}: value spread {spread:.2f} is too flat")


def main() -> int:
    catalog = load_json(CATALOG_PATH)
    errors: list[str] = []

    for race_id, race in catalog.get("races", {}).items():
        validate_character_package(race["exemplar"], f"race exemplar {race_id}", errors)
        validate_image_family(resource_path(str(race["matrix_preview"])), f"race matrix {race_id}", errors, 16, 16.0)

    for champion_id, champion in catalog.get("champions", {}).items():
        validate_character_package(champion, f"champion {champion_id}", errors)

    for district_id, district in catalog.get("wellspring", {}).get("districts", {}).items():
        validate_image_family(resource_path(str(district["preview"])), f"Wellspring district {district_id}", errors, 16, 16.0)

    support_images = {
        "Wellspring overview": catalog["wellspring"]["overview_1440p"],
        "Wellspring tiles": catalog["wellspring"]["tileset"],
        "Cosmic Wellspring cascade": catalog["wellspring"]["cosmic_cascade"],
        "material states": catalog["materials"]["path"],
        "prop states": catalog["props"]["path"],
        "element VFX": catalog["element_vfx"]["path"],
        "UI skin": catalog["ui"]["skin"],
        "UI surface overview": catalog["ui"]["surface_overview"],
    }
    for label, resource in support_images.items():
        validate_image_family(resource_path(str(resource)), label, errors)

    if errors:
        print("Wellspring structural visual-quality validation failed:")
        for error in errors[:200]:
            print(f"- {error}")
        if len(errors) > 200:
            print(f"- ... {len(errors) - 200} additional errors")
        return 1

    print("Wellspring structural visual-quality validation passed")
    print(f"checked every keyframe for {len(catalog.get('champions', {}))} champions and {len(catalog.get('races', {}))} race exemplars")
    print("checked portrait composition, value/palette structure, districts and support families")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
