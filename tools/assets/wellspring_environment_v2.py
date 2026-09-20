#!/usr/bin/env python3
"""Original Wellspring environment, material, prop, VFX and UI pixel assets."""
from __future__ import annotations

import hashlib
import math
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

from wellspring_catalog_data_v2 import (
    DISTRICTS, ELEMENTS, ELEMENT_COLORS, MATERIALS, MATERIAL_STATES,
    PROPS, PROP_STATES, UI_SURFACES, VFX_PHASES,
)
from wellspring_pixel_art_v2 import blend, rgba, save_png, shade

TILE = 16
MAP_TILES = (80, 45)
MAP_PIXELS = (MAP_TILES[0] * TILE, MAP_TILES[1] * TILE)

BASE_COLORS = {
    "void": "#101519",
    "worldbone": "#252a2d",
    "stone": "#a99b78",
    "path": "#8d7048",
    "grass": "#34572d",
    "moss": "#60804a",
    "wood": "#523725",
    "water": "#174556",
    "flux": "#4f7e9d",
    "cliff": "#363b3e",
    "roof": "#60402d",
    "bridge": "#563a28",
    "shore": "#796444",
    "garden": "#527441",
    "foundry": "#4a3d34",
    "archive": "#786f62",
    "portal": "#4a365d",
    "training": "#6c563d",
    "crystal": "#5ab5bd",
    "waterfall": "#55dbe0",
    "shrine": "#77716b",
}

TILE_GROUPS: dict[str, int] = {
    "void": 1,
    "worldbone": 8,
    "stone": 8,
    "path": 8,
    "grass": 8,
    "moss": 8,
    "wood": 8,
    "water": 8,
    "flux": 8,
    "cliff": 8,
    "roof": 8,
    "bridge": 8,
    "shore": 8,
    "garden": 8,
    "foundry": 8,
    "archive": 8,
    "portal": 8,
    "training": 8,
    "crystal": 8,
    "waterfall": 8,
    "shrine": 8,
}


def deterministic_points(key: str, count: int, margin: int = 1) -> list[tuple[int, int]]:
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    result: list[tuple[int, int]] = []
    for index in range(count):
        x = margin + digest[index * 2 % len(digest)] % max(1, TILE - margin * 2)
        y = margin + digest[(index * 2 + 1) % len(digest)] % max(1, TILE - margin * 2)
        result.append((x, y))
    return result


def draw_tile(kind: str, variant: int) -> Image.Image:
    base_color = BASE_COLORS[kind]
    image = Image.new("RGBA", (TILE, TILE), rgba(base_color))
    draw = ImageDraw.Draw(image)
    edge = shade(base_color, -0.38)
    light = shade(base_color, 0.28)
    mid = shade(base_color, 0.10)
    draw.rectangle((0, 0, 15, 15), outline=rgba(edge))

    if kind == "void":
        draw.rectangle((1, 1, 14, 14), fill=rgba("#11181d"))
        for x, y in deterministic_points("void", 5, 2):
            draw.point((x, y), fill=rgba("#27313a"))
    elif kind == "worldbone":
        draw.polygon([(1, 3), (4, 1), (12, 1), (14, 4), (14, 12), (11, 14), (4, 14), (1, 11)], fill=rgba(mid))
        draw.line((2, 4, 13, 4), fill=rgba(light), width=2)
        draw.line((4, 7, 12, 13), fill=rgba(edge), width=2)
        draw.rectangle((6 + variant % 3, 7, 8 + variant % 3, 9), fill=rgba("#15191b"))
    elif kind == "stone":
        draw.line((0, 7, 15, 7), fill=rgba(edge))
        draw.line((5 + variant % 4, 0, 5 + variant % 4, 7), fill=rgba(edge))
        draw.line((10 - variant % 3, 7, 10 - variant % 3, 15), fill=rgba(edge))
        draw.line((1, 2, 13, 2), fill=rgba(light))
        for x, y in deterministic_points(f"stone-{variant}", 4, 2):
            draw.point((x, y), fill=rgba(shade(base_color, -0.18)))
    elif kind == "path":
        draw.line((0, 2, 15, 2), fill=rgba(light))
        draw.line((0, 13, 15, 13), fill=rgba(edge))
        for x, y in deterministic_points(f"path-{variant}", 8, 1):
            draw.rectangle((x, y, min(15, x + 1), min(15, y + 1)), fill=rgba(mid if (x + y) % 2 else edge))
    elif kind in {"grass", "moss", "garden"}:
        for x, y in deterministic_points(f"{kind}-{variant}", 12, 1):
            blade = light if (x + y + variant) % 3 == 0 else edge
            draw.line((x, y + 1, x + (1 if x % 2 else -1), y - 1), fill=rgba(blade))
        if kind == "garden":
            for x, y in deterministic_points(f"flower-{variant}", 3, 3):
                draw.rectangle((x - 1, y, x + 1, y + 1), fill=rgba("#e7c77b" if variant % 2 else "#d79adf"))
    elif kind == "wood":
        for y in (3, 8, 13):
            draw.line((0, y, 15, y), fill=rgba(edge))
        draw.line((4 + variant % 5, 0, 4 + variant % 5, 15), fill=rgba(light))
        draw.point((11, 5 + variant % 5), fill=rgba(light))
    elif kind in {"water", "flux", "waterfall"}:
        dark = shade(base_color, -0.28)
        bright = shade(base_color, 0.42)
        phase = variant % 8
        if kind == "waterfall":
            draw.rectangle((1, 0, 14, 15), fill=rgba(dark))
            for x in (3, 7, 11):
                offset = (phase + x) % 5
                draw.line((x, -2 + offset, x - 1, 16), fill=rgba(bright), width=2)
            draw.rectangle((1, 13, 14, 15), fill=rgba("#d9f5ee", 160))
        else:
            for band in range(3):
                y = 3 + band * 5 + (phase + band) % 3
                draw.line((0, y, 4, y - 1, 9, y + 1, 15, y), fill=rgba(bright if band == 0 else dark), width=1)
            if kind == "flux":
                colors = list(ELEMENT_COLORS.values())[:8]
                draw.line((0, (phase * 2) % 16, 15, (phase * 2 + 6) % 16), fill=rgba(colors[phase], 190), width=2)
    elif kind == "cliff":
        draw.rectangle((1, 1, 14, 5), fill=rgba(light))
        draw.rectangle((1, 6, 14, 14), fill=rgba(mid))
        for x in (3 + variant % 3, 8, 12 - variant % 2):
            draw.line((x, 6, x - 2, 14), fill=rgba(edge), width=2)
    elif kind == "roof":
        draw.polygon([(0, 6), (8, 0), (15, 6), (15, 15), (0, 15)], fill=rgba(mid))
        draw.line((0, 6, 8, 0, 15, 6), fill=rgba(light), width=2)
        for y in (8, 12):
            draw.line((1, y, 14, y), fill=rgba(edge))
    elif kind == "bridge":
        draw.rectangle((0, 2, 15, 13), fill=rgba(mid))
        for x in range(1, 16, 4):
            draw.line((x, 2, x, 13), fill=rgba(edge))
        draw.line((0, 3, 15, 3), fill=rgba("#b88438"))
        draw.line((0, 12, 15, 12), fill=rgba("#b88438"))
    elif kind == "shore":
        draw.rectangle((0, 0, 15, 7), fill=rgba(BASE_COLORS["water"]))
        draw.polygon([(0, 7), (4, 5), (8, 8), (12, 6), (15, 7), (15, 15), (0, 15)], fill=rgba(mid))
        draw.line((0, 8, 4, 6, 8, 9, 12, 7, 15, 8), fill=rgba(light))
    elif kind == "foundry":
        draw.rectangle((2, 2, 13, 13), fill=rgba(mid), outline=rgba(edge))
        draw.line((2, 6, 13, 6), fill=rgba("#b88438"))
        draw.line((7, 2, 7, 13), fill=rgba("#b88438"))
        draw.rectangle((9, 9, 12, 12), fill=rgba("#e58a38" if variant % 2 else "#55dbe0"))
    elif kind == "archive":
        draw.rectangle((1, 1, 14, 14), fill=rgba(mid), outline=rgba(edge))
        for y in (4, 8, 12):
            draw.line((2, y, 13, y), fill=rgba(light))
        draw.rectangle((3 + variant % 7, 5, 5 + variant % 7, 7), fill=rgba("#9b65d9"))
    elif kind == "portal":
        draw.rectangle((1, 1, 14, 14), fill=rgba("#17151d"))
        draw.ellipse((3, 2, 12, 13), outline=rgba(light), width=2)
        draw.arc((5, 4, 10, 11), variant * 35, variant * 35 + 230, fill=rgba(ELEMENT_COLORS["charge"]), width=2)
    elif kind == "training":
        draw.rectangle((5, 2, 10, 14), fill=rgba(mid), outline=rgba(edge))
        draw.line((1, 6, 14, 6), fill=rgba(light), width=2)
        draw.ellipse((5, 0, 10, 5), fill=rgba("#b88438"), outline=rgba(edge))
    elif kind == "crystal":
        draw.polygon([(8, 1), (13, 6), (11, 14), (5, 14), (3, 6)], fill=rgba(edge))
        draw.polygon([(8, 2), (11, 7), (9, 12), (6, 12), (5, 7)], fill=rgba(light))
        draw.line((8, 2, 8, 12), fill=rgba("#e7f7f3"))
    elif kind == "shrine":
        draw.rectangle((2, 7, 13, 14), fill=rgba(mid), outline=rgba(edge))
        draw.ellipse((3, 1, 12, 10), fill=rgba("#17191c"), outline=rgba(light), width=2)
        color = list(ELEMENT_COLORS.values())[variant % 8]
        draw.arc((5, 3, 10, 8), variant * 30, variant * 30 + 250, fill=rgba(color), width=2)
    return image


def make_tile_atlas() -> tuple[Image.Image, dict[str, dict[str, Any]]]:
    columns = 16
    rows = math.ceil(sum(TILE_GROUPS.values()) / columns)
    image = Image.new("RGBA", (columns * TILE, rows * TILE), (0, 0, 0, 0))
    registry: dict[str, dict[str, Any]] = {}
    index = 0
    for kind, count in TILE_GROUPS.items():
        for variant in range(count):
            tile_id = kind if count == 1 else f"{kind}_{variant}"
            x = (index % columns) * TILE
            y = (index // columns) * TILE
            tile = draw_tile(kind, variant)
            image.alpha_composite(tile, (x, y))
            registry[tile_id] = {
                "region": [x, y, TILE, TILE],
                "kind": kind,
                "variant": variant,
                "walkable": kind not in {"void", "worldbone", "water", "cliff", "roof", "waterfall"},
                "worldbone": kind in {"worldbone", "cliff"},
                "foreground": kind == "roof",
            }
            index += 1
    return image, registry


def fill_rect(grid: list[list[str]], x0: int, y0: int, x1: int, y1: int, tile: str) -> None:
    for y in range(max(0, y0), min(len(grid), y1 + 1)):
        for x in range(max(0, x0), min(len(grid[0]), x1 + 1)):
            grid[y][x] = tile


def fill_ellipse(grid: list[list[str]], cx: int, cy: int, rx: int, ry: int, tile: str) -> None:
    for y in range(max(0, cy - ry), min(len(grid), cy + ry + 1)):
        for x in range(max(0, cx - rx), min(len(grid[0]), cx + rx + 1)):
            if ((x - cx) / max(1, rx)) ** 2 + ((y - cy) / max(1, ry)) ** 2 <= 1:
                grid[y][x] = tile


def path_line(grid: list[list[str]], a: tuple[int, int], b: tuple[int, int], width: int, tile: str) -> None:
    x0, y0 = a
    x1, y1 = b
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for step in range(steps + 1):
        x = round(x0 + (x1 - x0) * step / steps)
        y = round(y0 + (y1 - y0) * step / steps)
        fill_rect(grid, x - width, y - width, x + width, y + width, tile)


def ring(grid: list[list[str]], cx: int, cy: int, radius: int, width: int, tile: str) -> None:
    for y in range(max(0, cy - radius - width), min(len(grid), cy + radius + width + 1)):
        for x in range(max(0, cx - radius - width), min(len(grid[0]), cx + radius + width + 1)):
            distance = math.sqrt((x - cx) ** 2 + ((y - cy) * 1.4) ** 2)
            if radius - width <= distance <= radius + width:
                grid[y][x] = tile


def shoreline(grid: list[list[str]]) -> None:
    source = [row[:] for row in grid]
    for y in range(1, len(grid) - 1):
        for x in range(1, len(grid[0]) - 1):
            kind = source[y][x].split("_")[0]
            if kind in {"water", "void", "waterfall"}:
                continue
            neighbours = [source[y + dy][x + dx].split("_")[0] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if "water" in neighbours:
                grid[y][x] = f"shore_{(x + y) % 8}"


def district_layout(district_id: str) -> dict[str, Any]:
    grid = [[f"water_{(x + y) % 8}" for x in range(MAP_TILES[0])] for y in range(MAP_TILES[1])]
    landmarks: list[dict[str, Any]] = []
    routes: list[dict[str, Any]] = []

    if district_id == "source_court":
        fill_ellipse(grid, 40, 23, 31, 18, "grass_0")
        fill_ellipse(grid, 40, 22, 23, 14, "stone_1")
        ring(grid, 40, 22, 17, 2, "path_2")
        fill_ellipse(grid, 40, 22, 8, 6, "flux_0")
        fill_rect(grid, 38, 2, 42, 18, "waterfall_0")
        grid[22][40] = "shrine_0"
        for point in ((40, 42), (8, 22), (72, 22)):
            path_line(grid, (40, 22), point, 2, "path_3")
        for direction, color_index in enumerate(range(8)):
            angle = math.tau * direction / 8
            end = (round(40 + math.cos(angle) * 25), round(22 + math.sin(angle) * 12))
            path_line(grid, (40, 22), end, 0, f"flux_{color_index}")
        landmarks = [{"id": "cosmic_wellspring", "name": "Cosmic Wellspring", "tile": [40, 15]}, {"id": "source_basin", "name": "Source Basin", "tile": [40, 22]}]
        routes = [{"id": "source_ring", "kind": "ordinary"}, {"id": "eightfold_fluxways", "kind": "advanced"}]
    elif district_id == "farflow_concourse":
        fill_ellipse(grid, 40, 22, 30, 17, "stone_2")
        fill_ellipse(grid, 40, 22, 14, 9, "path_0")
        for point in ((40, 3), (40, 41), (5, 22), (75, 22)):
            path_line(grid, (40, 22), point, 3, "path_4")
        for x, y in ((40, 7), (40, 37), (10, 22), (70, 22)):
            fill_rect(grid, x - 3, y - 2, x + 3, y + 2, "portal_0")
        grid[22][40] = "shrine_1"
        landmarks = [{"id": "farflow_gates", "name": "Farflow Gates", "tile": [40, 22]}]
        routes = [{"id": "gate_ring", "kind": "ordinary"}, {"id": "concourse_roofline", "kind": "advanced"}]
    elif district_id == "movement_gardens":
        fill_ellipse(grid, 40, 22, 36, 19, "grass_2")
        path_line(grid, (7, 22), (73, 22), 2, "path_1")
        path_line(grid, (14, 9), (66, 9), 0, "bridge_0")
        path_line(grid, (14, 35), (66, 35), 0, "bridge_3")
        for y in range(13, 32):
            grid[y][28] = "cliff_1"
            grid[y][34] = "cliff_2"
        for x in range(43, 69, 4):
            grid[28][x] = "training_2"
        grid[22][65] = "shrine_2"
        landmarks = [{"id": "momentum_arbor", "name": "Momentum Arbor", "tile": [65, 22]}]
        routes = [{"id": "ordinary_training_loop", "kind": "ordinary"}, {"id": "wall_vault_superglide_loop", "kind": "advanced"}]
    elif district_id == "elemental_proving_grounds":
        fill_ellipse(grid, 40, 22, 33, 19, "foundry_1")
        fill_ellipse(grid, 40, 22, 21, 13, "stone_3")
        positions = ((40, 22), (27, 16), (53, 16), (27, 29), (53, 29), (40, 10), (40, 35), (16, 22))
        for index, (x, y) in enumerate(positions):
            fill_ellipse(grid, x, y, 4, 3, f"flux_{index}")
        path_line(grid, (7, 22), (73, 22), 2, "path_5")
        grid[22][40] = "shrine_3"
        landmarks = [{"id": "eightfold_basins", "name": "Eightfold Basins", "tile": [40, 22]}]
        routes = [{"id": "basin_ring", "kind": "ordinary"}, {"id": "reaction_rim", "kind": "advanced"}]
    elif district_id == "living_archive":
        fill_ellipse(grid, 40, 22, 31, 19, "grass_4")
        path_line(grid, (7, 32), (73, 32), 2, "path_0")
        fill_rect(grid, 27, 8, 53, 31, "archive_2")
        fill_ellipse(grid, 40, 14, 12, 8, "roof_4")
        for x in (18, 62):
            fill_rect(grid, x - 5, 14, x + 5, 31, "archive_5")
        grid[31][40] = "shrine_4"
        landmarks = [{"id": "oracular_dome", "name": "Oracular Dome", "tile": [40, 14]}]
        routes = [{"id": "archive_walk", "kind": "ordinary"}, {"id": "stack_vaults", "kind": "advanced"}]
    elif district_id == "restoration_grove":
        fill_ellipse(grid, 40, 22, 35, 20, "grass_3")
        path_line(grid, (6, 31), (74, 31), 2, "path_2")
        path_line(grid, (40, 4), (40, 40), 1, "path_6")
        for x, y in ((18, 12), (28, 18), (54, 12), (63, 25), (22, 35), (56, 35)):
            fill_ellipse(grid, x, y, 6, 4, f"garden_{(x + y) % 8}")
        grid[22][40] = "shrine_5"
        landmarks = [{"id": "heartroot_garden", "name": "Heartroot Garden", "tile": [40, 22]}]
        routes = [{"id": "grove_walk", "kind": "ordinary"}, {"id": "canopy_route", "kind": "advanced"}]
    elif district_id == "deep_foundry":
        fill_rect(grid, 7, 5, 72, 39, "worldbone_0")
        fill_rect(grid, 10, 8, 69, 36, "foundry_2")
        path_line(grid, (7, 22), (73, 22), 2, "path_7")
        for x in (22, 40, 58):
            fill_ellipse(grid, x, 15, 6, 5, f"flux_{(x // 8) % 8}")
            grid[15][x] = "crystal_2"
        for y in range(29, 34):
            for x in range(12, 68):
                grid[y][x] = f"water_{(x + y) % 8}"
        grid[22][40] = "shrine_6"
        landmarks = [{"id": "flux_crucible", "name": "Flux Crucible", "tile": [40, 15]}]
        routes = [{"id": "foundry_floor", "kind": "ordinary"}, {"id": "machine_line", "kind": "advanced"}]
    elif district_id == "starward_crown":
        fill_ellipse(grid, 25, 22, 21, 18, "stone_5")
        fill_ellipse(grid, 55, 22, 21, 18, "stone_6")
        path_line(grid, (25, 22), (55, 22), 2, "bridge_5")
        fill_ellipse(grid, 25, 22, 9, 9, "archive_3")
        fill_ellipse(grid, 55, 22, 9, 9, "archive_6")
        grid[22][25] = "shrine_7"
        grid[22][55] = "crystal_5"
        landmarks = [{"id": "twin_astrolabes", "name": "Twin Astrolabes", "tile": [40, 22]}]
        routes = [{"id": "crown_bridge", "kind": "ordinary"}, {"id": "astrolabe_ring", "kind": "advanced"}]
    else:
        for cx, cy, tile in ((24, 13, "grass_5"), (56, 13, "garden_4"), (24, 32, "stone_7"), (56, 32, "foundry_5")):
            fill_ellipse(grid, cx, cy, 16, 10, tile)
        path_line(grid, (24, 13), (56, 13), 1, "bridge_1")
        path_line(grid, (24, 32), (56, 32), 1, "bridge_6")
        path_line(grid, (24, 13), (24, 32), 1, "path_3")
        path_line(grid, (56, 13), (56, 32), 1, "path_4")
        grid[22][40] = "shrine_0"
        landmarks = [{"id": "fourfold_orrery", "name": "Fourfold Orrery", "tile": [40, 22]}]
        routes = [{"id": "seasonal_walk", "kind": "ordinary"}, {"id": "changing_surface_route", "kind": "advanced"}]

    shoreline(grid)
    return {
        "schema_version": 2,
        "id": f"wellspring-{district_id}-v2",
        "district_id": district_id,
        "authority": "integrated_candidate",
        "tile_size": [TILE, TILE],
        "size_tiles": list(MAP_TILES),
        "tileset": "res://assets/tiles/wellspring/wellspring_tiles_v2.png",
        "rows_rle": [rle(row) for row in grid],
        "collision_rows": [rle_int([1 if tile.split("_")[0] in {"void", "worldbone", "water", "cliff", "roof", "waterfall"} else 0 for tile in row]) for row in grid],
        "worldbone_rows": [rle_int([1 if tile.split("_")[0] in {"worldbone", "cliff"} else 0 for tile in row]) for row in grid],
        "navigation_rows": [rle_int([0 if tile.split("_")[0] in {"void", "worldbone", "water", "cliff", "roof", "waterfall"} else 1 for tile in row]) for row in grid],
        "elevation_rows": [rle_int([1 if tile.split("_")[0] in {"roof", "cliff"} else 0 for tile in row]) for row in grid],
        "landmarks": landmarks,
        "routes": routes,
        "reset_groups": [{"id": f"{district_id}_visual_reset", "scope": "mutable_visuals"}],
        "safety": {"critical_topology_immutable": True, "spawn_safe": True, "los_authority": "simulation"},
    }


def rle(row: list[str]) -> list[list[Any]]:
    result: list[list[Any]] = []
    value = row[0]
    count = 1
    for item in row[1:]:
        if item == value:
            count += 1
        else:
            result.append([value, count])
            value, count = item, 1
    result.append([value, count])
    return result


def rle_int(row: list[int]) -> list[list[int]]:
    result: list[list[int]] = []
    value = row[0]
    count = 1
    for item in row[1:]:
        if item == value:
            count += 1
        else:
            result.append([value, count])
            value, count = item, 1
    result.append([value, count])
    return result


def decode_rle(rows: list[list[list[Any]]]) -> list[list[Any]]:
    return [[value for value, count in row for _ in range(count)] for row in rows]


def render_layout(layout: dict[str, Any], atlas: Image.Image, registry: dict[str, dict[str, Any]]) -> Image.Image:
    grid = decode_rle(layout["rows_rle"])
    image = Image.new("RGBA", MAP_PIXELS, rgba(BASE_COLORS["water"]))
    for y, row in enumerate(grid):
        for x, tile_id in enumerate(row):
            region = registry[tile_id]["region"]
            tile = atlas.crop((region[0], region[1], region[0] + TILE, region[1] + TILE))
            image.alpha_composite(tile, (x * TILE, y * TILE))
    return image


def make_flux_cascade_atlas() -> Image.Image:
    frames = 8
    width, height = 64, 128
    atlas = Image.new("RGBA", (frames * width, height), (0, 0, 0, 0))
    colors = [ELEMENT_COLORS[element] for element in ELEMENTS]
    for frame_index in range(frames):
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw.ellipse((6, 103, 58, 125), fill=rgba("#10191e", 220))
        draw.ellipse((9, 106, 55, 122), fill=rgba("#22536a", 220))
        for ribbon, color in enumerate(colors):
            points = []
            for y in range(-4, 112, 4):
                phase = frame_index * math.tau / frames + ribbon * math.tau / len(colors)
                x = 32 + math.sin(y * 0.10 + phase) * (12 - y * 0.035) + (ribbon - 3.5) * 0.7
                points.append((round(x), y))
            draw.line(points, fill=rgba("#0d1113", 220), width=5)
            draw.line(points, fill=rgba(color, 210), width=2)
        draw.line((32, 0, 32, 108), fill=rgba("#effff9", 210), width=2)
        for spark in range(12):
            y = (spark * 13 + frame_index * 9) % 108
            x = 32 + round(math.sin(spark * 2.1 + frame_index) * 20)
            draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=rgba(colors[(spark + frame_index) % 8]))
        draw.arc((5, 101, 59, 126), 190, 350, fill=rgba("#effff9"), width=2)
        atlas.alpha_composite(frame, (frame_index * width, 0))
    return atlas


def make_material_atlas() -> Image.Image:
    cell = 32
    image = Image.new("RGBA", (len(MATERIALS) * cell, len(MATERIAL_STATES) * cell), (0, 0, 0, 0))
    colors = {
        "empty": "#11181d", "worldbone": "#252a2d", "stone": "#a99b78", "brick": "#8b5541",
        "wood": "#523725", "water": "#174556", "oil": "#251d28", "fire": "#e96a32",
        "steam": "#b7c8c6", "ice": "#8bdce7", "rubble": "#5f5a50",
    }
    for row, state in enumerate(MATERIAL_STATES):
        for column, material in enumerate(MATERIALS):
            x, y = column * cell, row * cell
            base_color = colors[material]
            draw = ImageDraw.Draw(image)
            draw.rectangle((x + 1, y + 1, x + 30, y + 30), fill=rgba(base_color), outline=rgba(shade(base_color, -0.45)), width=2)
            for px, py in deterministic_points(f"material-{material}-{state}", 12, 3):
                draw.rectangle((x + px, y + py, x + px + 1, y + py + 1), fill=rgba(shade(base_color, 0.22 if (px + py) % 2 else -0.22)))
            if state in {"cracked", "damaged"}:
                draw.line((x + 6, y + 4, x + 15, y + 14, x + 11, y + 25), fill=rgba("#16191a"), width=2)
                if state == "damaged":
                    draw.line((x + 15, y + 14, x + 26, y + 9), fill=rgba("#16191a"), width=2)
            elif state == "wet":
                draw.arc((x + 4, y + 10, x + 28, y + 28), 180, 350, fill=rgba("#55dbe0"), width=2)
            elif state in {"heated", "burning"}:
                draw.line((x + 5, y + 26, x + 12, y + 10, x + 17, y + 24, x + 25, y + 7), fill=rgba("#f0a33c" if state == "heated" else "#ff5733"), width=3)
            elif state == "cooling":
                draw.arc((x + 5, y + 5, x + 27, y + 27), 20, 320, fill=rgba("#7ca7af"), width=2)
            elif state in {"frozen", "melting"}:
                draw.line((x + 4, y + 5, x + 27, y + 27), fill=rgba("#d9ffff"), width=2)
                draw.line((x + 27, y + 5, x + 4, y + 27), fill=rgba("#d9ffff"), width=2)
                if state == "melting":
                    draw.ellipse((x + 12, y + 23, x + 20, y + 29), fill=rgba("#3e9ac7"))
            elif state == "charged":
                draw.line((x + 17, y + 3, x + 9, y + 16, x + 16, y + 16, x + 12, y + 29, x + 25, y + 12, x + 18, y + 12), fill=rgba("#55dbe0"), width=2)
            elif state == "soot":
                draw.rectangle((x + 3, y + 3, x + 28, y + 28), fill=rgba("#17191a", 150))
            elif state == "residue":
                for px, py in deterministic_points(f"residue-{material}", 8, 4):
                    draw.ellipse((x + px - 2, y + py - 2, x + px + 2, y + py + 2), fill=rgba("#9b65d9", 160))
    return image


def make_prop_atlas() -> Image.Image:
    cell = 48
    image = Image.new("RGBA", (len(PROPS) * cell, len(PROP_STATES) * cell), (0, 0, 0, 0))
    state_colors = {
        "idle": "#e7ddc3", "focused": "#55dbe0", "disabled": "#555a58", "pending": "#9b65d9",
        "active": "#e58a38", "success": "#75bf72", "failure": "#c85149", "damaged": "#817a6b",
        "blocked": "#8d4f45", "team_owned": "#4a9db1", "reset": "#d7ccb0",
    }
    for row, state in enumerate(PROP_STATES):
        for column, prop in enumerate(PROPS):
            x, y = column * cell, row * cell
            draw = ImageDraw.Draw(image)
            phase = state_colors[state]
            draw.ellipse((x + 7, y + 38, x + 41, y + 45), fill=(4, 8, 10, 75))
            draw.rectangle((x + 6, y + 6, x + 41, y + 41), fill=rgba("#151918"), outline=rgba("#101314"), width=3)
            draw.rectangle((x + 9, y + 9, x + 38, y + 38), outline=rgba(phase), width=2)
            if prop in {"door", "lift", "movable_cover"}:
                draw.rectangle((x + 15, y + 11, x + 33, y + 39), fill=rgba("#523725"), outline=rgba(phase), width=2)
                draw.rectangle((x + 18, y + 14, x + 30, y + 36), fill=rgba("#704b30"))
            elif prop in {"portal", "prism", "mirror"}:
                draw.ellipse((x + 12, y + 10, x + 36, y + 38), outline=rgba(phase), width=4)
                draw.arc((x + 16, y + 14, x + 32, y + 34), row * 25, row * 25 + 250, fill=rgba("#55dbe0"), width=2)
            elif prop in {"training_dummy", "target", "grapple_anchor"}:
                draw.line((x + 24, y + 10, x + 24, y + 40), fill=rgba("#b88438"), width=4)
                draw.line((x + 12, y + 20, x + 36, y + 20), fill=rgba(phase), width=3)
                draw.ellipse((x + 17, y + 7, x + 31, y + 21), fill=rgba("#8b7045"), outline=rgba("#101314"))
            elif prop in {"rail", "launch_surface"}:
                draw.line((x + 8, y + 32, x + 40, y + 14), fill=rgba("#101314"), width=7)
                draw.line((x + 9, y + 31, x + 39, y + 15), fill=rgba(phase), width=3)
            else:
                draw.rectangle((x + 15, y + 18, x + 33, y + 37), fill=rgba("#523725"), outline=rgba(phase), width=2)
                draw.ellipse((x + 18, y + 9, x + 30, y + 21), fill=rgba(phase), outline=rgba("#101314"))
                draw.rectangle((x + 22, y + 13, x + 26, y + 17), fill=rgba("#f7e6a3"))
            if state == "damaged":
                draw.line((x + 8, y + 8, x + 39, y + 39), fill=rgba("#101314"), width=3)
            if state == "blocked":
                draw.line((x + 9, y + 39, x + 39, y + 9), fill=rgba("#c85149"), width=4)
    return image


def draw_element_symbol(draw: ImageDraw.ImageDraw, element: str, cx: int, cy: int, radius: int, color: str, frame: int) -> None:
    if element == "earth":
        draw.polygon([(cx, cy - radius), (cx + radius, cy + radius - 2), (cx - radius, cy + radius - 2)], fill=rgba(color))
        draw.line((cx - radius + 2, cy + radius - 4, cx + radius - 2, cy + radius - 4), fill=rgba(shade(color, 0.3)), width=2)
    elif element == "fire":
        draw.polygon([(cx, cy - radius), (cx + radius - 2, cy + radius - 2), (cx, cy + radius), (cx - radius + 2, cy + radius - 3), (cx - 3, cy)], fill=rgba(color))
    elif element == "water":
        draw.arc((cx - radius, cy - radius // 2, cx + radius, cy + radius), 180, 360, fill=rgba(color), width=3)
        draw.arc((cx - radius + 4, cy - radius, cx + radius - 3, cy + radius // 2), 0, 180, fill=rgba(shade(color, 0.25)), width=2)
    elif element == "wind":
        draw.arc((cx - radius, cy - radius, cx + radius, cy + radius), 190 + frame * 20, 500 + frame * 20, fill=rgba(color), width=2)
        draw.line((cx - radius, cy + 4, cx + radius, cy + 4), fill=rgba(color), width=2)
    elif element == "ice":
        for angle in range(0, 180, 45):
            dx = math.cos(math.radians(angle)) * radius
            dy = math.sin(math.radians(angle)) * radius
            draw.line((cx - dx, cy - dy, cx + dx, cy + dy), fill=rgba(color), width=2)
    elif element == "charge":
        draw.polygon([(cx + 2, cy - radius), (cx - radius + 2, cy), (cx, cy), (cx - 4, cy + radius), (cx + radius, cy - 3), (cx + 2, cy - 3)], fill=rgba(color))
    elif element == "light":
        draw.ellipse((cx - radius // 2, cy - radius // 2, cx + radius // 2, cy + radius // 2), fill=rgba(color))
        for angle in range(0, 360, 45):
            dx = math.cos(math.radians(angle)) * radius
            dy = math.sin(math.radians(angle)) * radius
            draw.line((cx + dx * 0.65, cy + dy * 0.65, cx + dx, cy + dy), fill=rgba(color), width=2)
    else:
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=rgba(color))
        draw.ellipse((cx - radius // 2, cy - radius // 2, cx + radius // 2, cy + radius // 2), fill=rgba("#101314"))


def make_vfx_atlas() -> Image.Image:
    cell = 32
    frames_per_phase = 4
    image = Image.new("RGBA", (len(VFX_PHASES) * frames_per_phase * cell, len(ELEMENTS) * cell), (0, 0, 0, 0))
    for row, element in enumerate(ELEMENTS):
        color = ELEMENT_COLORS[element]
        for phase_index, phase in enumerate(VFX_PHASES):
            for frame in range(frames_per_phase):
                x = (phase_index * frames_per_phase + frame) * cell
                y = row * cell
                draw = ImageDraw.Draw(image)
                cx, cy = x + 16, y + 16
                radius = 7 + ((frame + phase_index) % 4) * 2
                draw_element_symbol(draw, element, cx, cy, radius, color, frame)
                if phase in {"impact", "residue", "status"}:
                    draw.arc((x + 3, y + 3, x + 29, y + 29), frame * 45, frame * 45 + 230, fill=rgba(shade(color, 0.35), 170), width=2)
                if phase == "reduced_motion":
                    draw.rectangle((x + 3, y + 3, x + 28, y + 28), outline=rgba("#e7ddc3"), width=1)
    return image


def make_element_icon_atlas() -> Image.Image:
    cell = 32
    image = Image.new("RGBA", (len(ELEMENTS) * cell, cell), (0, 0, 0, 0))
    for index, element in enumerate(ELEMENTS):
        x = index * cell
        draw = ImageDraw.Draw(image)
        draw.rectangle((x + 1, 1, x + 30, 30), fill=rgba("#151918"), outline=rgba("#101314"), width=2)
        draw_element_symbol(draw, element, x + 16, 16, 10, ELEMENT_COLORS[element], 0)
    return image


def make_ui_skin() -> Image.Image:
    image = Image.new("RGBA", (512, 512), rgba("#11181d"))
    draw = ImageDraw.Draw(image)
    panels = [
        (8, 8, 248, 120, "#24313a"), (264, 8, 504, 120, "#2f2a35"),
        (8, 136, 248, 280, "#283624"), (264, 136, 504, 280, "#443528"),
        (8, 296, 504, 504, "#1d262c"),
    ]
    for x0, y0, x1, y1, color in panels:
        draw.rectangle((x0, y0, x1, y1), fill=rgba("#101314"), outline=rgba("#080b0c"), width=4)
        draw.rectangle((x0 + 4, y0 + 4, x1 - 4, y1 - 4), fill=rgba(color), outline=rgba("#b88438"), width=2)
        draw.line((x0 + 9, y0 + 9, x1 - 9, y0 + 9), fill=rgba(shade(color, 0.38)), width=2)
        for px, py in deterministic_points(f"ui-{x0}-{y0}", 12, 12):
            if x0 + px < x1 - 4 and y0 + py < y1 - 4:
                draw.point((x0 + px, y0 + py), fill=rgba(shade(color, 0.18)))
    for index, element in enumerate(ELEMENTS):
        x = 24 + index * 58
        draw.ellipse((x, 322, x + 40, 362), fill=rgba("#101314"), outline=rgba(ELEMENT_COLORS[element]), width=2)
        draw_element_symbol(draw, element, x + 20, 342, 11, ELEMENT_COLORS[element], 0)
    for index in range(10):
        x = 24 + (index % 5) * 92
        y = 392 + (index // 5) * 52
        draw.rectangle((x, y, x + 76, y + 34), fill=rgba("#151918"), outline=rgba("#d7ccb0"), width=2)
        draw.rectangle((x + 4, y + 4, x + 72, y + 30), outline=rgba("#55dbe0" if index % 2 else "#b88438"))
    return image


def make_ui_surface_overview() -> Image.Image:
    width, cell_h = 1280, 160
    rows = math.ceil(len(UI_SURFACES) / 4)
    image = Image.new("RGBA", (width, rows * cell_h), rgba("#11181d"))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    for index, surface in enumerate(UI_SURFACES):
        column = index % 4
        row = index // 4
        x = column * 320
        y = row * cell_h
        color = list(ELEMENT_COLORS.values())[index % 8]
        draw.rectangle((x + 8, y + 8, x + 312, y + 152), fill=rgba("#1d262c"), outline=rgba("#101314"), width=3)
        draw.rectangle((x + 13, y + 13, x + 307, y + 147), outline=rgba(color), width=2)
        draw.text((x + 22, y + 20), surface.replace("_", " ").title(), fill=rgba("#e7ddc3"), font=font)
        draw.rectangle((x + 22, y + 48, x + 118, y + 132), fill=rgba(shade(color, -0.45)), outline=rgba(color), width=2)
        for slot in range(3):
            sx = x + 136 + slot * 52
            draw.rectangle((sx, y + 76, sx + 42, y + 118), fill=rgba("#151918"), outline=rgba(color), width=2)
    return image


def make_wellspring_overview(previews: dict[str, Image.Image]) -> Image.Image:
    image = Image.new("RGBA", (2560, 1440), rgba("#0c1115"))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    cell_w, cell_h = 800, 430
    margin_x, margin_y = 80, 70
    for index, district in enumerate(DISTRICTS):
        column = index % 3
        row = index // 3
        x = margin_x + column * cell_w
        y = margin_y + row * cell_h
        preview = previews[district["id"]].resize((768, 432), Image.Resampling.NEAREST)
        image.alpha_composite(preview, (x, y))
        draw.rectangle((x, y, x + 767, y + 431), outline=rgba("#101314"), width=5)
        draw.rectangle((x + 8, y + 8, x + 330, y + 34), fill=rgba("#101314", 220), outline=rgba("#b88438"), width=1)
        draw.text((x + 16, y + 16), district["name"], fill=rgba("#e7ddc3"), font=font)
    draw.rectangle((920, 620, 1640, 820), fill=rgba("#101314", 215), outline=rgba("#55dbe0"), width=4)
    draw.text((1090, 680), "THE WELLSPRING", fill=rgba("#e7ddc3"), font=font)
    draw.text((1015, 720), "Cosmic Flux source and living central hub", fill=rgba("#55dbe0"), font=font)
    return image
