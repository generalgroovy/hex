#!/usr/bin/env python3
"""Build export-safe FLUX burst sprites from the reviewed v3 style board."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "reference/art/projectiles/burst_v3/burst_element_style_board_v3.png"
OUTPUT_ROOT = ROOT / "assets/effects/projectiles/burst_v3"
MANIFEST = ROOT / "content/visual/burst_projectile_runtime_v3.json"
ELEMENTS = ("neutral", "fire", "water", "wind", "earth", "charge", "ice", "light", "dark")
DIRECTIONS = ("north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west")
CELL = 32
COLS = 16
ROWS = 8


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_text_sha256(path: Path) -> str:
    source = path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(source.encode("utf-8")).hexdigest()


def alpha_scaled(image: Image.Image, factor: float) -> Image.Image:
    result = image.copy()
    alpha = result.getchannel("A").point(lambda value: round(value * factor))
    result.putalpha(alpha)
    return result


def centered_scaled(image: Image.Image, scale: float, alpha: float = 1.0) -> Image.Image:
    size = max(1, round(CELL * scale))
    scaled = image.resize((size, size), Image.Resampling.NEAREST)
    if alpha < 1.0:
        scaled = alpha_scaled(scaled, alpha)
    result = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    result.alpha_composite(scaled, ((CELL - size) // 2, (CELL - size) // 2))
    return result


def luminosity_anchor(image: Image.Image) -> tuple[float, float]:
    weighted_x = 0.0
    weighted_y = 0.0
    total = 0.0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            weight = (0.2126 * red + 0.7152 * green + 0.0722 * blue) * (alpha / 255.0) ** 2
            weighted_x += x * weight
            weighted_y += y * weight
            total += weight
    return (weighted_x / total, weighted_y / total) if total > 0.0 else (image.width / 2.0, image.height / 2.0)


def runtime_core(source_cell: Image.Image) -> Image.Image:
    bounds = source_cell.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit("style-board cell is empty")
    cropped = source_cell.crop(bounds)
    scale = min(28 / cropped.width, 28 / cropped.height)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    reduced = cropped.resize(size, Image.Resampling.NEAREST)
    reduced = reduced.quantize(colors=16, method=Image.Quantize.FASTOCTREE).convert("RGBA")
    anchor_x, anchor_y = luminosity_anchor(reduced)
    offset = (round(CELL / 2 - anchor_x), round(CELL / 2 - anchor_y))
    result = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    result.alpha_composite(reduced, offset)
    return result


def directional(frame: Image.Image) -> tuple[Image.Image, ...]:
    east = frame
    north_east = east.rotate(45, resample=Image.Resampling.NEAREST, expand=False)
    north = east.rotate(90, resample=Image.Resampling.NEAREST, expand=False)
    south_east = north_east.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    south = north.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    south_west = south_east.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    west = east.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    north_west = north_east.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return (north, north_east, east, south_east, south, south_west, west, north_west)


def phase_frames(core: Image.Image) -> tuple[Image.Image, ...]:
    spawn = (centered_scaled(core, 0.55, 0.72), centered_scaled(core, 0.78, 0.92))
    travel = tuple(
        Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        for _ in range(6)
    )
    shifts = ((0, 0), (0, -1), (0, 0), (0, 1), (0, 0), (1, 0))
    for frame, shift in zip(travel, shifts):
        frame.alpha_composite(core, shift)
    impact = (
        centered_scaled(core, 1.00, 1.00),
        centered_scaled(core, 1.16, 0.80),
        centered_scaled(core, 1.34, 0.56),
        centered_scaled(core, 1.48, 0.30),
    )
    residue = (
        centered_scaled(core, 0.78, 0.48),
        centered_scaled(core, 0.56, 0.30),
        centered_scaled(core, 0.34, 0.16),
    )
    blank = (Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0)),)
    return spawn + travel + impact + residue + blank


def main() -> None:
    board = Image.open(SOURCE).convert("RGBA")
    if board.width != board.height or board.width % 3 != 0:
        raise SystemExit(f"expected square 3x3 style board, got {board.size}")
    source_cell_size = board.width // 3
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    assets: list[dict[str, object]] = []
    for index, element in enumerate(ELEMENTS):
        column = index % 3
        row = index // 3
        source_cell = board.crop((
            column * source_cell_size,
            row * source_cell_size,
            (column + 1) * source_cell_size,
            (row + 1) * source_cell_size,
        ))
        phases = phase_frames(runtime_core(source_cell))
        atlas = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
        for phase_index, phase in enumerate(phases):
            for direction_index, oriented in enumerate(directional(phase)):
                atlas.alpha_composite(oriented, (phase_index * CELL, direction_index * CELL))
        output = OUTPUT_ROOT / f"burst_{element}_runtime_32.png"
        atlas.save(output, optimize=True, compress_level=9)
        assets.append({
            "element": element,
            "path": f"res://assets/effects/projectiles/burst_v3/{output.name}",
            "sha256": sha256(output),
            "png_disk_bytes": output.stat().st_size,
        })
        print(output.relative_to(ROOT))
    manifest = {
        "schema_version": 1,
        "id": "burst-projectile-runtime-v3",
        "status": "runtime-approved",
        "runtime_approved": True,
        "release_approved": False,
        "authority": "presentation-only",
        "provenance": {
            "source_method": "built-in-image-generation-style-board",
            "source_path": "res://reference/art/projectiles/burst_v3/burst_element_style_board_v3.png",
            "source_sha256": sha256(SOURCE),
            "generator_path": "res://tools/assets/prepare_burst_runtime_v3.py",
            "generator_sha256": canonical_text_sha256(Path(__file__)),
            "third_party_pixel_inputs": False,
            "distribution_license": "pending-project-license",
            "review": "C2 runtime readability candidate; replaceable until integrated zoom/accessibility acceptance",
        },
        "contract": {
            "cell_size": [CELL, CELL],
            "columns": COLS,
            "rows": ROWS,
            "pivot": [CELL // 2, CELL // 2],
            "direction_order": DIRECTIONS,
            "phase_columns": {
                "spawn": [0, 1],
                "travel": [2, 3, 4, 5, 6, 7],
                "impact": [8, 9, 10, 11],
                "residue": [12, 13, 14],
                "reserved_blank": [15],
            },
            "texture_filter": "nearest",
            "mipmaps": False,
            "simulation_aim": "continuous-normalized-vector",
            "visual_orientation": "nearest-eight-direction",
            "collision_core": "simulation-owned",
        },
        "budgets": {
            "asset_count": len(assets),
            "png_disk_bytes": sum(int(asset["png_disk_bytes"]) for asset in assets),
            "maximum_png_disk_bytes": 1_000_000,
            "decoded_rgba_bytes": len(assets) * COLS * CELL * ROWS * CELL * 4,
            "maximum_decoded_rgba_bytes": 5_000_000,
        },
        "assets": assets,
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(MANIFEST.relative_to(ROOT))


if __name__ == "__main__":
    main()
