#!/usr/bin/env python3
"""Deterministic high-detail pixel renderer for FLUX2 Wellspring visual assets.

The renderer intentionally separates the 64x64 presentation envelope from the
simulation footprint. It produces original, nearest-neighbour-safe pixel art and
never assigns gameplay authority to rendered pixels.
"""
from __future__ import annotations

import math
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, ImageDraw

import generate_visual_assets_v1 as base
from wellspring_catalog_data_v2 import CELL_SIZE, ELEMENT_COLORS, PIVOT, RACES

CELL = CELL_SIZE
BLOCK_W = 6 * CELL
BLOCK_H = 8 * CELL
ATLAS_SIZE = (5 * BLOCK_W, 5 * BLOCK_H)
INK = "#101314"
DEEP_INK = "#080b0c"
PAPER = "#e7ddc3"


def rgba(value: str | tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    if isinstance(value, tuple):
        return value + (alpha,)
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def shade(value: str, amount: float) -> str:
    r, g, b, _ = rgba(value)
    if amount >= 0:
        r = round(r + (255 - r) * amount)
        g = round(g + (255 - g) * amount)
        b = round(b + (255 - b) * amount)
    else:
        scale = 1.0 + amount
        r = round(r * scale)
        g = round(g * scale)
        b = round(b * scale)
    return f"#{max(0,min(255,r)):02x}{max(0,min(255,g)):02x}{max(0,min(255,b)):02x}"


def blend(a: str, b: str, t: float) -> str:
    ar, ag, ab, _ = rgba(a)
    br, bg, bb, _ = rgba(b)
    return f"#{round(ar+(br-ar)*t):02x}{round(ag+(bg-ag)*t):02x}{round(ab+(bb-ab)*t):02x}"


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=False, compress_level=4)


def scaled_geometry(size_id: str, animation: str, direction: int, frame_index: int) -> tuple[dict[str, tuple[int, int]], dict[str, int]]:
    height, width = base.S[size_id]
    frame_count = base.A[animation][2]
    pose = base.pose(animation, frame_index, frame_count)
    points = base.pts(height, width, pose, direction)
    scaled = {key: (value[0] * 2, value[1] * 2) for key, value in points.items()}
    return scaled, pose


def line_layer(draw: ImageDraw.ImageDraw, points: Iterable[tuple[int, int]], outer: str, inner: str, outer_width: int, inner_width: int) -> None:
    points = list(points)
    draw.line(points, fill=rgba(outer), width=outer_width, joint="curve")
    draw.line(points, fill=rgba(inner), width=inner_width, joint="curve")


def ellipse_layer(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], outer: str, inner: str, inset: int = 2) -> None:
    draw.ellipse(box, fill=rgba(outer))
    draw.ellipse((box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset), fill=rgba(inner))


def polygon_layer(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], outer: str, inner: str, inset_points: list[tuple[int, int]] | None = None) -> None:
    draw.polygon(points, fill=rgba(outer))
    if inset_points:
        draw.polygon(inset_points, fill=rgba(inner))


def direction_vector(direction: int) -> tuple[int, int]:
    return base.vec(direction)


def profile_palette(profile: dict[str, Any]) -> dict[str, str]:
    primary = profile.get("primary", "#456070")
    secondary = profile.get("secondary", "#9a7b51")
    accent = profile.get("accent", "#55dbe0")
    skin = profile.get("skin", "#b98968")
    return {
        "ink": INK,
        "deep_ink": DEEP_INK,
        "skin": skin,
        "skin_shadow": shade(skin, -0.24),
        "skin_light": shade(skin, 0.22),
        "primary": primary,
        "primary_shadow": shade(primary, -0.34),
        "primary_light": shade(primary, 0.24),
        "secondary": secondary,
        "secondary_shadow": shade(secondary, -0.32),
        "secondary_light": shade(secondary, 0.24),
        "accent": accent,
        "accent_light": shade(accent, 0.34),
    }


def draw_shadow(draw: ImageDraw.ImageDraw, pose: dict[str, int], size_id: str) -> None:
    _, width = base.S[size_id]
    lift = pose.get("lift", 0) * 2
    radius = max(6, width + 5 - lift // 3)
    draw.ellipse((PIVOT[0] - radius - 2, PIVOT[1] + 1, PIVOT[0] + radius + 2, PIVOT[1] + 6), fill=(4, 8, 10, 38))
    draw.ellipse((PIVOT[0] - radius, PIVOT[1] + 2, PIVOT[0] + radius, PIVOT[1] + 5), fill=(4, 8, 10, 82))


def draw_back_features(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], direction: int, animation: str, frame_index: int, pal: dict[str, str]) -> None:
    race = profile["ancestry"]
    feature = str(profile.get("feature", ""))
    dx, dy = direction_vector(direction)
    sh = z["sh"]
    hip = z["hip"]
    accent = pal["accent"]
    secondary = pal["secondary"]
    secondary_shadow = pal["secondary_shadow"]

    winged = race in {"angel", "sylph", "wyrmborn"} or any(token in feature for token in ("wing", "rune_wings"))
    if winged:
        if race == "angel" or "feather" in feature:
            span, rise = 18, 13
            for side in (-1, 1):
                root = (sh[0] + side * 2, sh[1] + 2)
                tip = (sh[0] + side * span, sh[1] - rise + (frame_index % 2) * 2)
                low = (hip[0] + side * 11, hip[1] + 9)
                polygon_layer(draw, [root, tip, (tip[0] - side * 2, tip[1] + 10), low], INK, secondary,
                              [(root[0] + side, root[1] + 1), (tip[0] - side * 2, tip[1] + 3), (low[0] - side * 2, low[1] - 2)])
                draw.line((root, tip), fill=rgba(pal["accent_light"]), width=2)
                draw.line((tip[0], tip[1] + 4, low[0], low[1]), fill=rgba(secondary_shadow), width=2)
        elif race == "sylph" or "streamer" in feature:
            for side in (-1, 1):
                draw.polygon([(sh[0], sh[1]), (sh[0] + side * 15, sh[1] - 9), (hip[0] + side * 10, hip[1] + 6)], fill=rgba(INK))
                draw.polygon([(sh[0] + side, sh[1]), (sh[0] + side * 13, sh[1] - 7), (hip[0] + side * 9, hip[1] + 4)], fill=rgba(accent, 190))
                draw.line((sh[0] + side * 2, sh[1] + 2, hip[0] + side * 15, hip[1] + 10), fill=rgba(pal["accent_light"], 180), width=2)
        else:
            for side in (-1, 1):
                draw.polygon([(sh[0] + side * 2, sh[1]), (sh[0] + side * 17, sh[1] - 10), (hip[0] + side * 13, hip[1] + 8)], fill=rgba(INK))
                draw.polygon([(sh[0] + side * 3, sh[1] + 1), (sh[0] + side * 14, sh[1] - 7), (hip[0] + side * 11, hip[1] + 5)], fill=rgba(secondary_shadow))
                draw.line((sh[0] + side * 4, sh[1], hip[0] + side * 10, hip[1] + 5), fill=rgba(accent), width=2)

    if race == "arachnoid" or any(token in feature for token in ("spider", "scorpion", "harvest")):
        for side in (-1, 1):
            for index, offset in enumerate((-8, -3, 3, 8)):
                root = (hip[0] + side * 2, hip[1] + offset // 3)
                joint = (hip[0] + side * (10 + index), hip[1] + offset)
                end = (hip[0] + side * (17 + index), hip[1] + offset + 6)
                line_layer(draw, (root, joint, end), INK, secondary_shadow, 5, 2)
                draw.point(end, fill=rgba(accent))

    if race in {"seakin", "wyrmborn", "demon", "werewolf", "minotaur"} or any(token in feature for token in ("tail", "wolf")):
        tail_color = pal["skin_shadow"] if race in {"seakin", "wyrmborn", "werewolf", "minotaur"} else secondary_shadow
        side = -1 if direction in {1, 2, 3, 4} else 1
        root = (hip[0] - dx * 2, hip[1] + 1)
        mid = (hip[0] + side * 10 - dx * 4, hip[1] + 8)
        tip = (hip[0] + side * 17 - dx * 2, hip[1] + 3 + (frame_index % 2) * 2)
        line_layer(draw, (root, mid, tip), INK, tail_color, 6, 3)
        if race == "demon":
            draw.polygon([(tip[0], tip[1] - 4), (tip[0] + side * 5, tip[1]), (tip[0], tip[1] + 4)], fill=rgba(accent))
        if race == "seakin":
            draw.polygon([(tip[0], tip[1]), (tip[0] + side * 6, tip[1] - 6), (tip[0] + side * 6, tip[1] + 6)], fill=rgba(accent))

    if race == "treefolk":
        for side in (-1, 1):
            draw.line((sh[0], sh[1], sh[0] + side * 9, sh[1] - 11), fill=rgba(INK), width=6)
            draw.line((sh[0], sh[1], sh[0] + side * 8, sh[1] - 10), fill=rgba(pal["skin_shadow"]), width=3)
            draw.ellipse((sh[0] + side * 12 - 7, sh[1] - 19, sh[0] + side * 12 + 7, sh[1] - 5), fill=rgba(INK))
            draw.ellipse((sh[0] + side * 12 - 5, sh[1] - 17, sh[0] + side * 12 + 5, sh[1] - 7), fill=rgba(pal["secondary"]))

    if race == "vampire" or "cloak" in feature:
        flap = (frame_index % 2) * 2
        draw.polygon([(sh[0] - 7, sh[1]), (sh[0] + 7, sh[1]), (hip[0] + 12 + flap, hip[1] + 12), (hip[0] - 12 - flap, hip[1] + 12)], fill=rgba(INK))
        draw.polygon([(sh[0] - 5, sh[1] + 2), (sh[0] + 5, sh[1] + 2), (hip[0] + 9 + flap, hip[1] + 9), (hip[0] - 9 - flap, hip[1] + 9)], fill=rgba(pal["primary_shadow"]))


def draw_limbs(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], pal: dict[str, str]) -> None:
    size_id = profile["size"]
    _, width = base.S[size_id]
    thickness = 6 if width <= 8 else 7 if width <= 12 else 8
    inner = max(2, thickness - 4)
    leg_color = pal["primary_shadow"]
    arm_color = pal["secondary_shadow"]
    for knee, foot in (("lk", "lf"), ("rk", "rf")):
        line_layer(draw, (z["hip"], z[knee], z[foot]), INK, leg_color, thickness, inner)
        fx, fy = z[foot]
        draw.rectangle((fx - 4, fy - 2, fx + 4, fy + 2), fill=rgba(INK))
        draw.rectangle((fx - 2, fy - 1, fx + 3, fy + 1), fill=rgba(pal["secondary"]))
    for elbow, hand in (("le", "lh"), ("re", "rh")):
        line_layer(draw, (z["sh"], z[elbow], z[hand]), INK, arm_color, thickness, inner)
        hx, hy = z[hand]
        draw.ellipse((hx - 3, hy - 3, hx + 3, hy + 3), fill=rgba(INK))
        draw.ellipse((hx - 1, hy - 1, hx + 1, hy + 1), fill=rgba(pal["skin_light"]))


def draw_torso(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], pal: dict[str, str]) -> None:
    shx, shy = z["sh"]
    hx, hy = z["hip"]
    _, width = base.S[profile["size"]]
    presentation = profile.get("presentation", "neutral")
    shoulder = max(6, width // 2 + 3)
    waist = max(4, shoulder - (3 if presentation == "feminine" else 1))
    lower = 5 if presentation == "feminine" else 3
    outer = [(shx - shoulder - 2, shy - 2), (shx + shoulder + 2, shy - 2), (hx + waist + 2, hy + lower + 2), (hx - waist - 2, hy + lower + 2)]
    inner_points = [(shx - shoulder, shy), (shx + shoulder, shy), (hx + waist, hy + lower), (hx - waist, hy + lower)]
    polygon_layer(draw, outer, INK, pal["primary"], inner_points)
    draw.polygon([(shx, shy + 1), (shx + shoulder - 1, shy + 1), (hx + waist - 1, hy + lower - 1), (hx, hy + lower - 1)], fill=rgba(pal["primary_light"]))
    draw.line((shx - shoulder + 1, shy + 3, hx - waist + 1, hy + lower - 2), fill=rgba(pal["primary_shadow"]), width=2)
    draw.line((shx, shy + 2, hx, hy + lower), fill=rgba(pal["secondary"]), width=2)
    draw.rectangle((hx - waist, hy + lower - 2, hx + waist, hy + lower + 1), fill=rgba(INK))
    draw.rectangle((hx - waist + 2, hy + lower - 1, hx + waist - 2, hy + lower), fill=rgba(pal["secondary"]))


def draw_hair(draw: ImageDraw.ImageDraw, profile: dict[str, Any], head: tuple[int, int], radius: int, pal: dict[str, str], direction: int) -> None:
    hair = str(profile.get("hair", ""))
    if hair in {"none", "bald"} and profile["ancestry"] not in {"human", "elf", "gnome", "hobbit", "vampire"}:
        return
    hx, hy = head
    hair_color = profile.get("hair_color", shade(pal["primary_shadow"], -0.18))
    dx, dy = direction_vector(direction)
    if hair == "bald_sides":
        draw.rectangle((hx - radius - 2, hy - 1, hx - radius + 1, hy + radius + 3), fill=rgba(INK))
        draw.rectangle((hx + radius - 1, hy - 1, hx + radius + 2, hy + radius + 3), fill=rgba(INK))
        draw.rectangle((hx - radius - 1, hy, hx - radius, hy + radius + 2), fill=rgba("#d8d4bd"))
        draw.rectangle((hx + radius, hy, hx + radius + 1, hy + radius + 2), fill=rgba("#d8d4bd"))
        return
    if "hood" in hair:
        draw.arc((hx - radius - 4, hy - radius - 4, hx + radius + 4, hy + radius + 5), 180, 360, fill=rgba(INK), width=5)
        draw.arc((hx - radius - 2, hy - radius - 2, hx + radius + 2, hy + radius + 3), 180, 360, fill=rgba(hair_color), width=3)
        return
    if hair in {"short_dark", "slick_dark", "swept", "crest", "topknot", "short_light", "long", "long_dark", "braid", "leaf_hood", "mane", "canopy", "spines", "crystal", "brow", "helm", "braided_beard", "beard"} or profile["ancestry"] in {"human", "elf", "gnome", "hobbit", "vampire"}:
        draw.pieslice((hx - radius - 2, hy - radius - 3, hx + radius + 2, hy + radius + 2), 180, 360, fill=rgba(INK))
        draw.pieslice((hx - radius, hy - radius - 1, hx + radius, hy + radius), 180, 360, fill=rgba(hair_color))
        if hair in {"long", "long_dark", "braid", "mane"} or profile.get("presentation") == "feminine":
            side = -1 if dx >= 0 else 1
            draw.line((hx + side * radius, hy, hx + side * (radius + 3), hy + radius + 9), fill=rgba(INK), width=5)
            draw.line((hx + side * radius, hy + 1, hx + side * (radius + 2), hy + radius + 8), fill=rgba(hair_color), width=2)
        if hair in {"topknot", "crest"}:
            draw.ellipse((hx - 3, hy - radius - 9, hx + 3, hy - radius - 2), fill=rgba(INK))
            draw.ellipse((hx - 1, hy - radius - 7, hx + 1, hy - radius - 3), fill=rgba(hair_color))
        if hair in {"spines", "crystal"}:
            for offset in (-5, 0, 5):
                draw.polygon([(hx + offset - 2, hy - radius), (hx + offset, hy - radius - 8 - abs(offset) // 2), (hx + offset + 2, hy - radius)], fill=rgba(pal["accent"]))


def draw_head(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], direction: int, pal: dict[str, str]) -> None:
    race = profile["ancestry"]
    hx, hy = z["head"]
    _, width = base.S[profile["size"]]
    radius = max(5, width // 2 + 2)
    dx, dy = direction_vector(direction)

    if race == "undead":
        ellipse_layer(draw, (hx - radius - 2, hy - radius - 2, hx + radius + 2, hy + radius + 2), INK, "#c7c1ad", 2)
        if dy >= 0:
            draw.rectangle((hx - 5 + dx, hy - 2, hx - 1 + dx, hy + 2), fill=rgba(DEEP_INK))
            draw.rectangle((hx + 1 + dx, hy - 2, hx + 5 + dx, hy + 2), fill=rgba(DEEP_INK))
            draw.line((hx - 3, hy + 5, hx + 3, hy + 5), fill=rgba(DEEP_INK), width=2)
        return

    if race == "stoneborn":
        draw.polygon([(hx - radius - 2, hy - radius), (hx + radius, hy - radius - 3), (hx + radius + 3, hy + radius - 1), (hx - radius, hy + radius + 3)], fill=rgba(INK))
        draw.polygon([(hx - radius, hy - radius + 1), (hx + radius - 1, hy - radius - 1), (hx + radius + 1, hy + radius - 2), (hx - radius + 1, hy + radius + 1)], fill=rgba(pal["skin"]))
        draw.line((hx - 3, hy - 5, hx, hy, hx - 2, hy + 7), fill=rgba(pal["accent"]), width=2)
    elif race == "treefolk":
        ellipse_layer(draw, (hx - radius - 2, hy - radius - 3, hx + radius + 2, hy + radius + 3), INK, pal["skin"], 2)
        draw.line((hx - 4, hy - radius, hx - 7, hy - radius - 8), fill=rgba(INK), width=4)
        draw.line((hx + 4, hy - radius, hx + 8, hy - radius - 8), fill=rgba(INK), width=4)
        draw.ellipse((hx - 11, hy - radius - 12, hx - 3, hy - radius - 4), fill=rgba(pal["secondary"]))
        draw.ellipse((hx + 3, hy - radius - 12, hx + 12, hy - radius - 4), fill=rgba(pal["secondary_light"]))
    elif race == "minotaur":
        ellipse_layer(draw, (hx - radius - 3, hy - radius - 2, hx + radius + 3, hy + radius + 4), INK, pal["skin"], 2)
        for side in (-1, 1):
            draw.polygon([(hx + side * (radius - 1), hy - 2), (hx + side * (radius + 10), hy - radius - 6), (hx + side * (radius + 5), hy + 1)], fill=rgba(INK))
            draw.polygon([(hx + side * radius, hy - 2), (hx + side * (radius + 8), hy - radius - 4), (hx + side * (radius + 4), hy)], fill=rgba(pal["secondary_light"]))
        draw.ellipse((hx - 5 + dx * 2, hy + 2, hx + 5 + dx * 2, hy + 9), fill=rgba(pal["skin_shadow"]))
    elif race == "werewolf":
        ellipse_layer(draw, (hx - radius - 3, hy - radius - 2, hx + radius + 3, hy + radius + 4), INK, pal["skin"], 2)
        for side in (-1, 1):
            draw.polygon([(hx + side * 3, hy - radius + 1), (hx + side * (radius + 5), hy - radius - 9), (hx + side * radius, hy)], fill=rgba(INK))
            draw.polygon([(hx + side * 4, hy - radius), (hx + side * (radius + 3), hy - radius - 6), (hx + side * (radius - 1), hy - 1)], fill=rgba(pal["skin_shadow"]))
        draw.polygon([(hx - 4 + dx * 3, hy + 2), (hx + 4 + dx * 3, hy + 2), (hx + dx * 7, hy + 8)], fill=rgba(pal["skin_shadow"]))
    elif race == "wyrmborn":
        ellipse_layer(draw, (hx - radius - 3, hy - radius - 2, hx + radius + 3, hy + radius + 3), INK, pal["skin"], 2)
        for side in (-1, 1):
            draw.polygon([(hx + side * 2, hy - radius), (hx + side * (radius + 5), hy - radius - 10), (hx + side * radius, hy + 1)], fill=rgba(INK))
            draw.polygon([(hx + side * 3, hy - radius + 1), (hx + side * (radius + 3), hy - radius - 7), (hx + side * (radius - 1), hy)], fill=rgba(pal["accent"]))
        draw.line((hx - radius + 2, hy + 2, hx + radius - 2, hy + 2), fill=rgba(pal["skin_shadow"]), width=2)
    elif race == "arachnoid":
        ellipse_layer(draw, (hx - radius - 3, hy - radius - 3, hx + radius + 3, hy + radius + 3), INK, pal["skin"], 2)
        if dy >= 0:
            for ox, oy in ((-5, -3), (0, -4), (5, -3), (-3, 2), (3, 2), (0, 5)):
                draw.rectangle((hx + ox - 1, hy + oy - 1, hx + ox + 1, hy + oy + 1), fill=rgba(pal["accent_light"]))
        draw.line((hx - radius, hy + radius - 1, hx - radius - 4, hy + radius + 5), fill=rgba(INK), width=3)
        draw.line((hx + radius, hy + radius - 1, hx + radius + 4, hy + radius + 5), fill=rgba(INK), width=3)
    else:
        ellipse_layer(draw, (hx - radius - 2, hy - radius - 2, hx + radius + 2, hy + radius + 2), INK, pal["skin"], 2)

    if race == "elf":
        for side in (-1, 1):
            draw.polygon([(hx + side * radius, hy - 2), (hx + side * (radius + 10), hy - 5), (hx + side * radius, hy + 3)], fill=rgba(INK))
            draw.polygon([(hx + side * (radius - 1), hy - 1), (hx + side * (radius + 7), hy - 4), (hx + side * (radius - 1), hy + 2)], fill=rgba(pal["skin_light"]))
    elif race == "goblin":
        for side in (-1, 1):
            draw.polygon([(hx + side * (radius - 1), hy - 3), (hx + side * (radius + 12), hy - 7), (hx + side * radius, hy + 4)], fill=rgba(INK))
            draw.polygon([(hx + side * radius, hy - 2), (hx + side * (radius + 9), hy - 6), (hx + side * (radius - 1), hy + 2)], fill=rgba(pal["skin_light"]))
    elif race == "seakin":
        for side in (-1, 1):
            draw.polygon([(hx + side * 2, hy - radius), (hx + side * (radius + 7), hy - radius - 5), (hx + side * radius, hy + 2)], fill=rgba(INK))
            draw.polygon([(hx + side * 3, hy - radius + 1), (hx + side * (radius + 5), hy - radius - 3), (hx + side * (radius - 1), hy + 1)], fill=rgba(pal["accent"]))
        draw.polygon([(hx - 4, hy - radius), (hx, hy - radius - 9), (hx + 4, hy - radius)], fill=rgba(pal["accent_light"]))
    elif race == "demon":
        for side in (-1, 1):
            draw.polygon([(hx + side * 2, hy - radius), (hx + side * (radius + 5), hy - radius - 10), (hx + side * radius, hy + 1)], fill=rgba(INK))
            draw.polygon([(hx + side * 3, hy - radius + 1), (hx + side * (radius + 3), hy - radius - 7), (hx + side * (radius - 1), hy)], fill=rgba(pal["accent"]))
    elif race == "angel":
        draw.ellipse((hx - radius - 3, hy - radius - 10, hx + radius + 3, hy - radius - 5), outline=rgba(INK), width=3)
        draw.ellipse((hx - radius - 1, hy - radius - 9, hx + radius + 1, hy - radius - 6), outline=rgba(pal["accent_light"]), width=2)
    elif race == "gnome":
        draw.rectangle((hx - radius - 3, hy - 2, hx + radius + 3, hy + 2), fill=rgba(INK))
        draw.ellipse((hx - radius, hy - 3, hx - 1, hy + 3), fill=rgba(pal["accent_light"]))
        draw.ellipse((hx + 1, hy - 3, hx + radius, hy + 3), fill=rgba(pal["accent_light"]))
    elif race == "dwarf":
        draw.polygon([(hx - radius + 1, hy + 2), (hx + radius - 1, hy + 2), (hx + 5, hy + radius + 10), (hx, hy + radius + 14), (hx - 5, hy + radius + 10)], fill=rgba(INK))
        draw.polygon([(hx - radius + 3, hy + 3), (hx + radius - 3, hy + 3), (hx + 4, hy + radius + 8), (hx, hy + radius + 11), (hx - 4, hy + radius + 8)], fill=rgba(pal["secondary"]))
    elif race == "vampire":
        draw.polygon([(hx - radius - 2, hy - radius + 1), (hx, hy - radius - 6), (hx + radius + 2, hy - radius + 1)], fill=rgba(INK))

    draw_hair(draw, profile, (hx, hy), radius, pal, direction)

    if dy >= 0 and race not in {"undead", "arachnoid"}:
        eye_y = hy + max(-1, dy)
        eye_color = pal["accent_light"] if race in {"vampire", "demon", "angel", "seakin", "wyrmborn"} else "#f4ead1"
        draw.rectangle((hx - 4 + dx, eye_y - 1, hx - 2 + dx, eye_y + 1), fill=rgba(INK))
        draw.rectangle((hx + 2 + dx, eye_y - 1, hx + 4 + dx, eye_y + 1), fill=rgba(INK))
        draw.point((hx - 3 + dx, eye_y), fill=rgba(eye_color))
        draw.point((hx + 3 + dx, eye_y), fill=rgba(eye_color))
        if race in {"orc", "troll", "goblin"}:
            draw.polygon([(hx - 4, hy + 5), (hx - 1, hy + 5), (hx - 2, hy + 9)], fill=rgba(PAPER))
            draw.polygon([(hx + 1, hy + 5), (hx + 4, hy + 5), (hx + 2, hy + 9)], fill=rgba(PAPER))
        if race == "vampire":
            draw.point((hx - 2, hy + 7), fill=rgba(PAPER))
            draw.point((hx + 2, hy + 7), fill=rgba(PAPER))


def draw_race_front_features(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], pal: dict[str, str]) -> None:
    race = profile["ancestry"]
    hip = z["hip"]
    sh = z["sh"]
    if race == "stoneborn":
        draw.line((sh[0] - 4, sh[1] + 3, hip[0], hip[1], hip[0] + 3, hip[1] + 6), fill=rgba(pal["accent"]), width=2)
    elif race == "treefolk":
        for side in (-1, 1):
            draw.line((hip[0] + side * 2, hip[1], PIVOT[0] + side * 9, PIVOT[1] + 4), fill=rgba(INK), width=5)
            draw.line((hip[0] + side * 2, hip[1] + 1, PIVOT[0] + side * 8, PIVOT[1] + 3), fill=rgba(pal["skin_shadow"]), width=2)
    elif race == "nymph":
        for ox, oy in ((-7, -3), (7, 0), (0, 7)):
            draw.ellipse((sh[0] + ox - 2, sh[1] + oy - 2, sh[0] + ox + 2, sh[1] + oy + 2), fill=rgba(pal["accent_light"]))
    elif race == "arachnoid":
        draw.ellipse((hip[0] - 7, hip[1] - 1, hip[0] + 7, hip[1] + 9), fill=rgba(INK))
        draw.ellipse((hip[0] - 5, hip[1], hip[0] + 5, hip[1] + 7), fill=rgba(pal["primary_shadow"]))
    elif race == "sylph":
        draw.arc((sh[0] - 9, sh[1] - 4, sh[0] + 9, sh[1] + 12), 200, 520, fill=rgba(pal["accent_light"]), width=2)


def hand_vector(z: dict[str, tuple[int, int]], direction: int) -> tuple[tuple[int, int], tuple[int, int]]:
    hand = z["rh"]
    dx, dy = direction_vector(direction)
    if dx == 0 and dy == 0:
        dy = 1
    end = (hand[0] + dx * 13, hand[1] + dy * 13 - 4)
    if dx == 0:
        end = (hand[0] + 7, hand[1] + dy * 12 - 4)
    return hand, end


def draw_weapon(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], direction: int, animation: str, frame_index: int, pal: dict[str, str]) -> None:
    weapon = str(profile.get("weapon", "none"))
    if weapon in {"", "none"}:
        return
    hand, end = hand_vector(z, direction)
    active = animation in {"attack_primary", "cast", "taunt", "defend"}
    if active:
        scale = 1 + frame_index / max(1, base.A[animation][2] - 1)
        end = (round(hand[0] + (end[0] - hand[0]) * scale), round(hand[1] + (end[1] - hand[1]) * scale))
    lower = weapon.lower()
    if any(token in lower for token in ("staff", "lance", "conduit", "sabre", "blade", "rapier", "greatbow", "bow", "hammer", "maul", "breaker")):
        line_layer(draw, (hand, end), INK, pal["secondary"], 5, 2)
    if any(token in lower for token in ("hammer", "maul", "breaker")):
        ex, ey = end
        draw.rectangle((ex - 8, ey - 5, ex + 8, ey + 5), fill=rgba(INK))
        draw.rectangle((ex - 6, ey - 3, ex + 6, ey + 3), fill=rgba(pal["accent"]))
    elif any(token in lower for token in ("staff", "conduit", "lance")):
        ex, ey = end
        draw.ellipse((ex - 5, ey - 5, ex + 5, ey + 5), fill=rgba(INK))
        draw.ellipse((ex - 3, ey - 3, ex + 3, ey + 3), fill=rgba(pal["accent_light"]))
    elif any(token in lower for token in ("bow", "greatbow")):
        ex, ey = end
        draw.arc((ex - 9, ey - 12, ex + 9, ey + 12), 270, 90, fill=rgba(pal["accent"]), width=3)
        draw.line((ex, ey - 10, ex, ey + 10), fill=rgba(PAPER), width=1)
    elif any(token in lower for token in ("shield", "prism")):
        hx, hy = z["lh"]
        draw.polygon([(hx, hy - 9), (hx + 8, hy - 4), (hx + 6, hy + 8), (hx, hy + 12), (hx - 6, hy + 8), (hx - 8, hy - 4)], fill=rgba(INK))
        draw.polygon([(hx, hy - 6), (hx + 5, hy - 3), (hx + 4, hy + 6), (hx, hy + 9), (hx - 4, hy + 6), (hx - 5, hy - 3)], fill=rgba(pal["accent"]))
    elif any(token in lower for token in ("orb", "disc", "detonator", "gauntlet", "coil", "pack", "horn")):
        ex, ey = end
        draw.ellipse((ex - 6, ey - 6, ex + 6, ey + 6), fill=rgba(INK))
        draw.ellipse((ex - 4, ey - 4, ex + 4, ey + 4), fill=rgba(pal["secondary"]))
        draw.rectangle((ex - 1, ey - 1, ex + 1, ey + 1), fill=rgba(pal["accent_light"]))


def element_color(profile: dict[str, Any], index: int = 0) -> str:
    elements = profile.get("elements", [])
    if not elements:
        return profile.get("accent", "#55dbe0")
    return ELEMENT_COLORS.get(elements[index % len(elements)], profile.get("accent", "#55dbe0"))


def draw_animation_fx(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], animation: str, frame_index: int, direction: int, pal: dict[str, str]) -> None:
    count = base.A[animation][2]
    phase = frame_index / max(1, count - 1)
    primary = element_color(profile, 0)
    secondary = element_color(profile, 1)
    if animation == "cast":
        cx, cy = z["rh"]
        radius = 5 + frame_index * 2
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=rgba(primary, 210), width=2)
        for index, angle in enumerate((0, 90, 180, 270)):
            radians = math.radians(angle + frame_index * 25)
            px = round(cx + math.cos(radians) * (radius + 3))
            py = round(cy + math.sin(radians) * (radius + 3))
            draw.rectangle((px - 1, py - 1, px + 1, py + 1), fill=rgba(secondary if index % 2 else primary))
    elif animation == "attack_primary":
        hand, end = hand_vector(z, direction)
        r = 11 + frame_index * 4
        draw.arc((hand[0] - r, hand[1] - r, hand[0] + r, hand[1] + r), 210, 330, fill=rgba(primary, 190), width=3)
        draw.point(end, fill=rgba(pal["accent_light"]))
    elif animation in {"sprint", "slide", "wavedash", "superglide"}:
        dx, dy = direction_vector(direction)
        for offset in (0, 5, 10):
            x = PIVOT[0] - dx * (8 + offset) + (frame_index % 2)
            y = PIVOT[1] - dy * (4 + offset // 2)
            draw.line((x, y, x - dx * 5, y - dy * 3), fill=rgba(pal["secondary_light"], 120), width=2)
    elif animation == "land":
        for side in (-1, 1):
            draw.arc((PIVOT[0] - 14, PIVOT[1] - 2, PIVOT[0] + 14, PIVOT[1] + 9), 180 if side < 0 else 270, 270 if side < 0 else 360, fill=rgba(pal["secondary"], 150), width=2)
    elif animation == "hit":
        cx, cy = z["sh"]
        for angle in range(0, 360, 60):
            radians = math.radians(angle)
            x = round(cx + math.cos(radians) * (8 + frame_index * 3))
            y = round(cy + math.sin(radians) * (8 + frame_index * 3))
            draw.line((cx, cy, x, y), fill=rgba("#f2d37c"), width=2)
    elif animation == "stunned":
        hx, hy = z["head"]
        for index in range(3):
            angle = frame_index * 1.7 + index * math.tau / 3
            x = round(hx + math.cos(angle) * 11)
            y = round(hy - 12 + math.sin(angle) * 4)
            draw.regular_polygon((x, y, 3), 4, rotation=45, fill=rgba("#f2d37c"))
    elif animation == "rooted":
        for side in (-1, 1):
            draw.line((PIVOT[0] + side * 2, PIVOT[1], PIVOT[0] + side * 12, PIVOT[1] + 5, PIVOT[0] + side * 16, PIVOT[1] - 2), fill=rgba("#6f5938"), width=4)
            draw.line((PIVOT[0] + side * 3, PIVOT[1], PIVOT[0] + side * 12, PIVOT[1] + 4), fill=rgba("#a47b4d"), width=2)
    elif animation == "interact":
        cx, cy = z["rh"]
        draw.rectangle((cx - 7, cy - 7, cx + 7, cy + 7), outline=rgba(primary), width=2)
        draw.line((cx - 5, cy, cx + 5, cy), fill=rgba(primary), width=2)
        draw.line((cx, cy - 5, cx, cy + 5), fill=rgba(primary), width=2)
    elif animation == "taunt":
        cx, cy = z["sh"]
        draw.arc((cx - 17, cy - 17, cx + 17, cy + 17), round(phase * 180), round(phase * 180 + 240), fill=rgba(primary, 170), width=2)


def render_character_frame(profile: dict[str, Any], animation: str, direction: int, frame_index: int, debug: bool = False) -> Image.Image:
    image = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    z, pose = scaled_geometry(profile["size"], animation, direction, frame_index)
    pal = profile_palette(profile)
    draw_shadow(draw, pose, profile["size"])
    draw_back_features(draw, profile, z, direction, animation, frame_index, pal)
    draw_limbs(draw, profile, z, pal)
    draw_torso(draw, profile, z, pal)
    draw_head(draw, profile, z, direction, pal)
    draw_race_front_features(draw, profile, z, pal)
    draw_weapon(draw, profile, z, direction, animation, frame_index, pal)
    draw_animation_fx(draw, profile, z, animation, frame_index, direction, pal)

    if debug:
        height, width = base.S[profile["size"]]
        top = max(0, (28 - height - pose.get("lift", 0) - 2) * 2)
        half = max(8, width + 6)
        draw.rectangle((PIVOT[0] - half, top, PIVOT[0] + half, PIVOT[1]), outline=(70, 230, 240, 190), width=1)
        draw.line((PIVOT[0], 0, PIVOT[0], CELL - 1), fill=(70, 230, 240, 110))
        draw.line((0, PIVOT[1], CELL - 1, PIVOT[1]), fill=(255, 70, 65, 200))
        draw.rectangle((PIVOT[0] - 2, PIVOT[1] - 2, PIVOT[0] + 2, PIVOT[1] + 2), fill=(255, 40, 40, 255))
        for key, point in z.items():
            color = (255, 220, 70, 220) if key in {"lh", "rh", "head"} else (90, 255, 150, 180)
            draw.rectangle((point[0] - 1, point[1] - 1, point[0] + 1, point[1] + 1), fill=color)
    return image


def make_character_atlas(profile: dict[str, Any], debug: bool = False) -> Image.Image:
    atlas = Image.new("RGBA", ATLAS_SIZE, (0, 0, 0, 0))
    for animation, (block_x, block_y, frame_count, _fps) in base.A.items():
        for direction in range(8):
            for frame_index in range(frame_count):
                frame = render_character_frame(profile, animation, direction, frame_index, debug=debug)
                x = block_x * BLOCK_W + frame_index * CELL
                y = block_y * BLOCK_H + direction * CELL
                atlas.alpha_composite(frame, (x, y))
    return atlas


def make_direction_preview(profile: dict[str, Any]) -> Image.Image:
    image = Image.new("RGBA", (1024, 128), rgba("#151918"))
    draw = ImageDraw.Draw(image)
    for direction in range(8):
        frame = render_character_frame(profile, "idle", direction, direction % base.A["idle"][2])
        scaled = frame.resize((128, 128), Image.Resampling.NEAREST)
        image.alpha_composite(scaled, (direction * 128, 0))
        draw.rectangle((direction * 128, 0, direction * 128 + 127, 127), outline=rgba(shade(profile.get("accent", "#55dbe0"), -0.25)), width=2)
    return image


def make_portrait(profile: dict[str, Any], size: int) -> Image.Image:
    primary = profile.get("primary", "#456070")
    accent = profile.get("accent", "#55dbe0")
    image = Image.new("RGBA", (size, size), rgba(shade(primary, -0.45)))
    draw = ImageDraw.Draw(image)
    border = max(1, size // 32)
    draw.rectangle((border, border, size - border - 1, size - border - 1), outline=rgba(INK), width=max(2, border * 2))
    draw.rectangle((border * 3, border * 3, size - border * 3 - 1, size - border * 3 - 1), outline=rgba(accent), width=border)
    frame = render_character_frame(profile, "idle", 0, 1)
    crop = frame.crop((6, 0, 58, 62)).resize((size - border * 6, size - border * 6), Image.Resampling.NEAREST)
    image.alpha_composite(crop, (border * 3, border * 3))
    draw.line((border * 3, size - border * 5, size - border * 3, size - border * 5), fill=rgba(shade(accent, 0.3)), width=border)
    return image


def make_selection_icon(profile: dict[str, Any]) -> Image.Image:
    return make_portrait(profile, 48)


def make_size_gender_preview(profiles: list[dict[str, Any]]) -> Image.Image:
    image = Image.new("RGBA", (1280, 256), rgba("#151918"))
    draw = ImageDraw.Draw(image)
    for index, profile in enumerate(profiles):
        frame = render_character_frame(profile, "idle", 0, index % 4)
        scale = 4
        x = index * 128 + 32
        y = 4
        image.alpha_composite(frame.resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST).crop((64, 0, 192, 256)), (x - 32, y))
        draw.rectangle((index * 128, 0, index * 128 + 127, 255), outline=rgba(profile.get("accent", "#55dbe0")), width=2)
    return image


def make_animation_keyframe_board(profile: dict[str, Any]) -> Image.Image:
    animations = list(base.A.keys())
    columns = 5
    cell = 128
    rows = math.ceil(len(animations) / columns)
    image = Image.new("RGBA", (columns * cell, rows * cell), rgba("#151918"))
    draw = ImageDraw.Draw(image)
    for index, animation in enumerate(animations):
        frame_count = base.A[animation][2]
        frame = render_character_frame(profile, animation, 0, frame_count // 2)
        x = (index % columns) * cell
        y = (index // columns) * cell
        image.alpha_composite(frame.resize((cell, cell), Image.Resampling.NEAREST), (x, y))
        draw.rectangle((x, y, x + cell - 1, y + cell - 1), outline=rgba(profile.get("accent", "#55dbe0")), width=1)
    return image
