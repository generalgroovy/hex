"""Bake the deterministic FLUX hex-court projectile candidate atlas."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


CELL = 24
ELEMENTS = [
    ("earth", "#4a2d1a", "#b47c36", "#edc179"),
    ("fire", "#701d20", "#fa4b26", "#ff943e"),
    ("water", "#15366e", "#1f70f2", "#57baff"),
    ("wind", "#16513d", "#28d882", "#88f3ad"),
    ("ice", "#246078", "#41d8ed", "#b0f7ff"),
    ("charge", "#786011", "#eed42e", "#ffef78"),
    ("light", "#8e8262", "#f9ebc0", "#fff9e8"),
    ("dark", "#301345", "#a246df", "#d98aff"),
]
FAMILIES = ("rapid", "bolt", "heavy", "spray")


def pixel_rect(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], color: str) -> None:
    draw.rectangle(xy, fill=color)


def rapid(draw: ImageDraw.ImageDraw, dark: str, base: str, bright: str) -> None:
    draw.polygon([(19, 12), (13, 7), (6, 10), (4, 12), (6, 14), (13, 17)], fill=dark)
    draw.polygon([(18, 12), (12, 8), (7, 11), (5, 12), (7, 13), (12, 16)], fill=base)
    pixel_rect(draw, (12, 10, 16, 12), bright)


def bolt(draw: ImageDraw.ImageDraw, dark: str, base: str, bright: str) -> None:
    draw.polygon([(22, 12), (14, 6), (10, 8), (3, 5), (7, 11), (2, 14), (10, 15), (14, 18)], fill=dark)
    draw.polygon([(20, 12), (14, 8), (11, 10), (6, 8), (9, 12), (6, 14), (12, 14), (14, 16)], fill=base)
    draw.polygon([(20, 12), (14, 10), (11, 12), (14, 14)], fill=bright)


def heavy(draw: ImageDraw.ImageDraw, dark: str, base: str, bright: str) -> None:
    draw.polygon([(21, 12), (17, 4), (8, 3), (2, 9), (2, 15), (8, 21), (17, 20)], fill=dark)
    draw.polygon([(19, 12), (15, 6), (9, 5), (4, 10), (4, 14), (9, 19), (15, 18)], fill=base)
    pixel_rect(draw, (8, 7, 13, 9), bright)
    pixel_rect(draw, (15, 10, 18, 13), bright)
    pixel_rect(draw, (6, 15, 10, 17), dark)


def spray(draw: ImageDraw.ImageDraw, dark: str, base: str, bright: str) -> None:
    draw.polygon([(22, 12), (8, 3), (3, 5), (8, 11), (3, 12), (8, 13), (3, 19), (8, 21)], fill=dark)
    draw.polygon([(20, 12), (9, 5), (6, 6), (11, 11), (6, 12), (11, 13), (6, 18), (9, 19)], fill=base)
    pixel_rect(draw, (12, 10, 18, 13), bright)


DRAWERS = {"rapid": rapid, "bolt": bolt, "heavy": heavy, "spray": spray}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output = root / "export" / "projectile_atlas.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (CELL * len(ELEMENTS), CELL * len(FAMILIES)), (0, 0, 0, 0))
    for row, family in enumerate(FAMILIES):
        for column, (_, dark, base, bright) in enumerate(ELEMENTS):
            frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            DRAWERS[family](ImageDraw.Draw(frame), dark, base, bright)
            atlas.alpha_composite(frame, (column * CELL, row * CELL))
    atlas.save(output, "PNG", optimize=False, compress_level=9)
    manifest = {
        "schema_version": 1,
        "id": "flux-hex-court-projectiles-v1",
        "authority": "presentation only; simulation collision timing quantities and outcomes remain authoritative elsewhere",
        "atlas": {
            "path": "export/projectile_atlas.png",
            "size_px": list(atlas.size),
            "frame_size_px": [CELL, CELL],
            "rgba_sha256": hashlib.sha256(atlas.tobytes()).hexdigest(),
        },
        "columns": [item[0] for item in ELEMENTS],
        "element_wire_ids": list(range(1, 9)),
        "rows": list(FAMILIES),
        "rapid_has_flight_trail": False,
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
