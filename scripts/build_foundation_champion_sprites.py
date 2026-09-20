"""Build the reviewed 96px FLUX body-only champion atlas from its source sheet.

This script is deterministic and intentionally narrow: it removes only
edge-connected magenta matte, scales each isolated body/clothing cell to the
reviewed gameplay height, adds a mirrored west run, and packs two seven-cell
rows. Spell, aura, shadow and environment layers are never generated here.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


SOURCE_COLUMNS = 6
SOURCE_ROWS = 2
SOURCE_CELL = (256, 512)
OUTPUT_CELL = 96
OUTPUT_PIVOT_Y = 84
CELL_ORDER = ("south", "east", "west", "north", "jump", "cast", "hit")
SOURCE_FOR_OUTPUT = (0, 1, 1, 2, 3, 4, 5)
TARGET_HEIGHTS = (68, 60)


def is_matte(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    # The generated matte varies slightly around antialiased edges. Flooding
    # only from the cell border lets us accept that wider family without
    # deleting isolated clothing detail.
    return (
        red > 95
        and blue > 95
        and green < min(red, blue) * 0.62
        and abs(red - blue) < 115
    )


def remove_edge_matte(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if not visited[index] and is_matte(pixels[x, y]):
            visited[index] = 1
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)
    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    rgba = rgb.convert("RGBA")
    output = rgba.load()
    for y in range(height):
        for x in range(width):
            if visited[y * width + x]:
                output[x, y] = (0, 0, 0, 0)
    return rgba


def isolated_sprite(source: Image.Image, row: int, column: int) -> Image.Image:
    cell_width, cell_height = SOURCE_CELL
    cell = source.crop(
        (
            column * cell_width,
            row * cell_height,
            (column + 1) * cell_width,
            (row + 1) * cell_height,
        )
    )
    transparent = remove_edge_matte(cell)
    bounds = transparent.getbbox()
    if bounds is None:
        raise ValueError(f"source cell {row},{column} contains no isolated sprite")
    return transparent.crop(bounds)


def fit_sprite(sprite: Image.Image, target_height: int) -> Image.Image:
    scale = min(target_height / sprite.height, 92 / sprite.width)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    # LANCZOS produces a clean master at gameplay resolution. Godot then keeps
    # this exact pixel grid through nearest-neighbor sampling.
    return sprite.resize(size, Image.Resampling.LANCZOS)


def build(source_path: Path, output_path: Path) -> None:
    source = Image.open(source_path).convert("RGB")
    expected = (SOURCE_COLUMNS * SOURCE_CELL[0], SOURCE_ROWS * SOURCE_CELL[1])
    if source.size != expected:
        raise ValueError(f"expected {expected} source sheet, got {source.size}")
    atlas = Image.new("RGBA", (len(CELL_ORDER) * OUTPUT_CELL, SOURCE_ROWS * OUTPUT_CELL))
    for row in range(SOURCE_ROWS):
        for output_column, source_column in enumerate(SOURCE_FOR_OUTPUT):
            sprite = fit_sprite(isolated_sprite(source, row, source_column), TARGET_HEIGHTS[row])
            if output_column == 2:
                sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            x = output_column * OUTPUT_CELL + (OUTPUT_CELL - sprite.width) // 2
            y = row * OUTPUT_CELL + OUTPUT_PIVOT_Y - sprite.height
            atlas.alpha_composite(sprite, (x, y))
    alpha = atlas.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    atlas = atlas.convert("RGB").quantize(
        colors=32,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    atlas.putalpha(alpha)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path, optimize=True)
    print(f"built {output_path} {atlas.size[0]}x{atlas.size[1]}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    build(arguments.source, arguments.output)


if __name__ == "__main__":
    main()
