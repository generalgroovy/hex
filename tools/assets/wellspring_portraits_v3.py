#!/usr/bin/env python3
"""High-detail portrait renderer for Wellspring character packages.

Portraits are authored at a dedicated 128-pixel bust resolution instead of
magnifying a gameplay frame. The renderer remains deterministic and original,
while sharing the race, equipment, palette and elemental language of the runtime
sprite package.
"""
from __future__ import annotations

import math
from typing import Any

from PIL import Image, ImageDraw

from wellspring_catalog_data_v2 import ELEMENT_COLORS
from wellspring_pixel_art_v2 import INK, PAPER, blend, rgba, shade

BASE = 128


def _palette(profile: dict[str, Any]) -> dict[str, str]:
    skin = str(profile.get("skin", "#b98968"))
    primary = str(profile.get("primary", "#456070"))
    secondary = str(profile.get("secondary", "#9a7b51"))
    accent = str(profile.get("accent", "#55dbe0"))
    return {
        "skin": skin,
        "skin_shadow": shade(skin, -0.28),
        "skin_deep": shade(skin, -0.48),
        "skin_light": shade(skin, 0.25),
        "primary": primary,
        "primary_shadow": shade(primary, -0.38),
        "primary_deep": shade(primary, -0.56),
        "primary_light": shade(primary, 0.28),
        "secondary": secondary,
        "secondary_shadow": shade(secondary, -0.36),
        "secondary_light": shade(secondary, 0.28),
        "accent": accent,
        "accent_shadow": shade(accent, -0.30),
        "accent_light": shade(accent, 0.42),
    }


def _outline_polygon(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], fill: str, width: int = 3) -> None:
    draw.polygon(points, fill=rgba(INK))
    cx = sum(x for x, _ in points) / len(points)
    cy = sum(y for _, y in points) / len(points)
    inner = []
    for x, y in points:
        dx, dy = cx - x, cy - y
        length = max(1.0, math.hypot(dx, dy))
        inner.append((round(x + dx / length * width), round(y + dy / length * width)))
    draw.polygon(inner, fill=rgba(fill))


def _outline_ellipse(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: str, width: int = 3) -> None:
    draw.ellipse(box, fill=rgba(INK))
    draw.ellipse((box[0] + width, box[1] + width, box[2] - width, box[3] - width), fill=rgba(fill))


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], fill: str, width: int = 3, outline: int = 6) -> None:
    draw.line(points, fill=rgba(INK), width=outline, joint="curve")
    draw.line(points, fill=rgba(fill), width=width, joint="curve")


def _deterministic_bits(key: str) -> list[int]:
    return [((ord(char) * (index + 7)) + index * 19) % 97 for index, char in enumerate(key or "flux")]


def _background(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    draw.rectangle((0, 0, 127, 127), fill=rgba("#101619"))
    draw.rectangle((4, 4, 123, 123), fill=rgba(pal["primary_deep"]), outline=rgba(INK), width=3)
    draw.rectangle((8, 8, 119, 119), fill=rgba(blend(pal["primary_deep"], "#17252b", 0.55)), outline=rgba(pal["secondary"]), width=2)
    draw.line((11, 12, 116, 12), fill=rgba(pal["secondary_light"]), width=2)
    draw.line((11, 115, 116, 115), fill=rgba(pal["secondary_shadow"]), width=3)

    elements = list(profile.get("elements", []))
    if not elements:
        elements = ["light"]
    for index, element in enumerate(elements[:3]):
        color = ELEMENT_COLORS.get(element, pal["accent"])
        radius = 27 + index * 8
        draw.arc((64 - radius, 54 - radius, 64 + radius, 54 + radius), 200 + index * 45, 335 + index * 45, fill=rgba(color, 135), width=2)
        draw.arc((64 - radius, 54 - radius, 64 + radius, 54 + radius), 20 + index * 45, 115 + index * 45, fill=rgba(shade(color, 0.35), 95), width=1)

    bits = _deterministic_bits(str(profile.get("id", profile.get("name", "flux"))))
    for index, value in enumerate(bits[:16]):
        x = 14 + (value * 13 + index * 17) % 100
        y = 18 + (value * 7 + index * 11) % 72
        color = ELEMENT_COLORS.get(elements[index % len(elements)], pal["accent"])
        draw.rectangle((x, y, x + (1 if index % 3 else 2), y + (1 if index % 4 else 2)), fill=rgba(color, 130))


def _element_halo(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    elements = list(profile.get("elements", []))
    for index, element in enumerate(elements[:3]):
        color = ELEMENT_COLORS.get(element, pal["accent"])
        cx = 22 + index * 42
        cy = 93 - (index % 2) * 8
        draw.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=rgba(INK))
        draw.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=rgba(shade(color, -0.18)))
        if element == "charge":
            draw.polygon([(cx + 1, cy - 5), (cx - 4, cy), (cx, cy), (cx - 2, cy + 6), (cx + 5, cy - 1), (cx + 1, cy - 1)], fill=rgba(shade(color, 0.4)))
        elif element == "fire":
            draw.polygon([(cx, cy - 6), (cx + 5, cy + 4), (cx, cy + 6), (cx - 5, cy + 4), (cx - 2, cy - 1)], fill=rgba(shade(color, 0.32)))
        elif element == "water":
            draw.arc((cx - 5, cy - 2, cx + 5, cy + 6), 175, 365, fill=rgba(shade(color, 0.4)), width=2)
        elif element == "wind":
            draw.arc((cx - 6, cy - 5, cx + 6, cy + 6), 190, 510, fill=rgba(shade(color, 0.4)), width=2)
        elif element == "ice":
            draw.line((cx - 5, cy, cx + 5, cy), fill=rgba(shade(color, 0.42)), width=2)
            draw.line((cx, cy - 5, cx, cy + 5), fill=rgba(shade(color, 0.42)), width=2)
            draw.line((cx - 4, cy - 4, cx + 4, cy + 4), fill=rgba(shade(color, 0.42)), width=1)
        elif element == "earth":
            draw.polygon([(cx, cy - 5), (cx + 5, cy + 4), (cx - 5, cy + 4)], fill=rgba(shade(color, 0.35)))
        elif element == "light":
            draw.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=rgba(shade(color, 0.45)))
            for angle in range(0, 360, 90):
                dx = round(math.cos(math.radians(angle)) * 6)
                dy = round(math.sin(math.radians(angle)) * 6)
                draw.line((cx + dx // 2, cy + dy // 2, cx + dx, cy + dy), fill=rgba(shade(color, 0.45)), width=1)
        else:
            draw.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=rgba(color))
            draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=rgba("#101619"))


def _back_features(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    race = str(profile.get("ancestry", "human"))
    feature = str(profile.get("feature", ""))
    if race in {"angel", "sylph", "wyrmborn"} or "wing" in feature:
        if race == "angel":
            for side in (-1, 1):
                wing = [(63 + side * 5, 49), (63 + side * 42, 27), (63 + side * 48, 54), (63 + side * 32, 78), (63 + side * 11, 70)]
                _outline_polygon(draw, wing, pal["secondary_light"], 3)
                for offset in (0, 8, 16):
                    draw.line((63 + side * (11 + offset), 56 + offset // 2, 63 + side * (36 + offset // 3), 38 + offset), fill=rgba(pal["secondary_shadow"]), width=2)
        elif race == "sylph":
            for side in (-1, 1):
                draw.polygon([(62 + side * 5, 46), (62 + side * 40, 25), (62 + side * 30, 68)], fill=rgba(INK))
                draw.polygon([(62 + side * 7, 47), (62 + side * 36, 29), (62 + side * 27, 64)], fill=rgba(pal["accent"], 185))
                draw.line((62 + side * 10, 47, 62 + side * 30, 36), fill=rgba(pal["accent_light"]), width=2)
        else:
            for side in (-1, 1):
                _outline_polygon(draw, [(63 + side * 5, 50), (63 + side * 38, 28), (63 + side * 43, 65), (63 + side * 15, 74)], pal["primary_shadow"], 3)
                draw.line((63 + side * 9, 52, 63 + side * 34, 35), fill=rgba(pal["accent"]), width=2)

    if race == "arachnoid":
        for side in (-1, 1):
            for index, y in enumerate((43, 53, 64, 75)):
                root = (63 + side * 10, y)
                joint = (63 + side * (31 + index * 3), y - 8 + index * 4)
                tip = (63 + side * (48 + index), y + 2 + index * 3)
                _line(draw, [root, joint, tip], pal["secondary_shadow"], 3, 6)
                draw.rectangle((tip[0] - 1, tip[1] - 1, tip[0] + 1, tip[1] + 1), fill=rgba(pal["accent_light"]))

    if race == "treefolk":
        for side in (-1, 1):
            _line(draw, [(63 + side * 6, 51), (63 + side * 22, 25), (63 + side * 32, 16)], pal["skin_shadow"], 4, 8)
            _outline_ellipse(draw, (63 + side * 33 - 15, 7, 63 + side * 33 + 15, 34), pal["secondary"], 3)
            draw.ellipse((63 + side * 33 - 9, 11, 63 + side * 33 + 8, 25), fill=rgba(pal["secondary_light"]))

    if race in {"vampire"} or "cloak" in feature:
        _outline_polygon(draw, [(42, 47), (86, 47), (109, 114), (64, 100), (19, 114)], pal["primary_shadow"], 4)
        draw.line((32, 58, 64, 100, 96, 58), fill=rgba(pal["primary_light"]), width=2)


def _torso(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    presentation = str(profile.get("presentation", "neutral"))
    shoulder = 32 if profile.get("size") in {"size_4_large", "size_5_huge"} else 27
    waist = 18 if presentation == "feminine" else 22
    _outline_polygon(draw, [(64 - shoulder, 68), (64 + shoulder, 68), (64 + waist, 116), (64 - waist, 116)], pal["primary"], 4)
    draw.polygon([(64, 72), (64 + shoulder - 5, 72), (64 + waist - 4, 112), (64, 112)], fill=rgba(pal["primary_light"]))
    draw.polygon([(64 - shoulder + 5, 72), (64, 72), (64, 112), (64 - waist + 4, 112)], fill=rgba(pal["primary_shadow"]))
    draw.line((64, 72, 64, 113), fill=rgba(pal["secondary"]), width=3)
    draw.rectangle((43, 102, 85, 111), fill=rgba(INK))
    draw.rectangle((47, 104, 81, 108), fill=rgba(pal["secondary"]))
    draw.rectangle((60, 102, 68, 111), fill=rgba(pal["accent_shadow"]))
    draw.rectangle((62, 104, 66, 108), fill=rgba(pal["accent_light"]))

    race = str(profile.get("ancestry", "human"))
    if race == "stoneborn":
        draw.line((46, 76, 61, 90, 55, 111), fill=rgba(pal["accent"]), width=3)
        draw.line((82, 73, 71, 91, 77, 108), fill=rgba(pal["accent_shadow"]), width=2)
    elif race == "treefolk":
        for x in (48, 57, 70, 79):
            draw.line((x, 73, x - 3, 110), fill=rgba(pal["skin_shadow"]), width=2)
    elif race == "arachnoid":
        draw.ellipse((50, 86, 78, 118), fill=rgba(INK))
        draw.ellipse((54, 89, 74, 114), fill=rgba(pal["primary_shadow"]))
        draw.polygon([(64, 93), (70, 102), (64, 110), (58, 102)], fill=rgba(pal["accent_shadow"]))
    elif race == "angel":
        draw.line((41, 80, 64, 98, 87, 80), fill=rgba(pal["accent_light"]), width=3)
        draw.ellipse((58, 86, 70, 98), outline=rgba(pal["secondary"]), width=2)
    elif race == "demon":
        draw.polygon([(45, 73), (57, 83), (48, 94)], fill=rgba(pal["accent_shadow"]))
        draw.polygon([(83, 73), (71, 83), (80, 94)], fill=rgba(pal["accent_shadow"]))


def _head_geometry(profile: dict[str, Any]) -> tuple[int, int, int, int]:
    race = str(profile.get("ancestry", "human"))
    if race in {"gnome", "goblin", "hobbit"}:
        return 40, 24, 88, 75
    if race in {"troll", "minotaur", "werewolf", "wyrmborn"}:
        return 36, 21, 92, 79
    return 40, 22, 88, 75


def _head(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    race = str(profile.get("ancestry", "human"))
    x0, y0, x1, y1 = _head_geometry(profile)

    if race == "stoneborn":
        _outline_polygon(draw, [(42, 27), (57, 19), (83, 24), (91, 42), (83, 70), (55, 78), (39, 61)], pal["skin"], 4)
        draw.line((48, 33, 61, 44, 56, 68), fill=rgba(pal["accent"]), width=3)
        draw.line((81, 28, 73, 46, 82, 61), fill=rgba(pal["skin_shadow"]), width=2)
    elif race == "treefolk":
        _outline_ellipse(draw, (x0, y0, x1, y1 + 4), pal["skin"], 4)
        for x in (49, 58, 70, 80):
            draw.line((x, 29, x - 4, 68), fill=rgba(pal["skin_shadow"]), width=2)
    elif race == "undead":
        _outline_ellipse(draw, (x0, y0, x1, y1), "#c8c0a9", 4)
        draw.rectangle((47, 42, 58, 52), fill=rgba("#101314"))
        draw.rectangle((70, 42, 81, 52), fill=rgba("#101314"))
        draw.rectangle((50, 45, 55, 49), fill=rgba(pal["accent"]))
        draw.rectangle((73, 45, 78, 49), fill=rgba(pal["accent_light"]))
        draw.polygon([(64, 52), (59, 61), (69, 61)], fill=rgba(pal["skin_shadow"]))
        draw.line((52, 67, 76, 67), fill=rgba(INK), width=3)
        for x in range(55, 75, 5):
            draw.line((x, 65, x, 71), fill=rgba(INK), width=1)
        return
    elif race == "minotaur":
        _outline_ellipse(draw, (x0, y0, x1, y1 + 5), pal["skin"], 4)
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 17, 31), (64 + side * 43, 13), (64 + side * 34, 39)], pal["secondary_light"], 3)
        draw.ellipse((49, 55, 79, 76), fill=rgba(INK))
        draw.ellipse((53, 58, 75, 72), fill=rgba(pal["skin_shadow"]))
        draw.ellipse((56, 63, 61, 68), fill=rgba(INK))
        draw.ellipse((67, 63, 72, 68), fill=rgba(INK))
    elif race == "werewolf":
        _outline_ellipse(draw, (x0, y0, x1, y1 + 3), pal["skin"], 4)
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 10, 29), (64 + side * 26, 7), (64 + side * 31, 35)], pal["skin_shadow"], 3)
        _outline_polygon(draw, [(49, 52), (79, 52), (73, 72), (64, 81), (55, 72)], pal["skin_shadow"], 3)
        draw.polygon([(59, 62), (69, 62), (64, 68)], fill=rgba(INK))
    elif race == "wyrmborn":
        _outline_ellipse(draw, (x0, y0, x1, y1 + 3), pal["skin"], 4)
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 8, 27), (64 + side * 30, 7), (64 + side * 27, 39)], pal["accent_shadow"], 3)
        for y in (35, 45, 55):
            draw.line((47, y, 81, y + 2), fill=rgba(pal["skin_shadow"]), width=1)
        draw.polygon([(64, 52), (58, 61), (70, 61)], fill=rgba(pal["skin_shadow"]))
    elif race == "arachnoid":
        _outline_ellipse(draw, (x0 - 2, y0 - 2, x1 + 2, y1 + 2), pal["skin"], 4)
        for index, (x, y) in enumerate(((49, 41), (58, 36), (70, 36), (79, 41), (54, 49), (74, 49))):
            radius = 4 if index < 4 else 3
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=rgba(INK))
            draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=rgba(pal["accent_light"]))
        draw.line((51, 64, 58, 72), fill=rgba(INK), width=3)
        draw.line((77, 64, 70, 72), fill=rgba(INK), width=3)
        return
    else:
        _outline_ellipse(draw, (x0, y0, x1, y1), pal["skin"], 4)

    if race == "elf":
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 21, 38), (64 + side * 43, 29), (64 + side * 23, 51)], pal["skin_light"], 2)
    elif race == "goblin":
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 21, 39), (64 + side * 49, 25), (64 + side * 24, 55)], pal["skin_light"], 3)
    elif race == "seakin":
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 13, 28), (64 + side * 37, 14), (64 + side * 27, 49)], pal["accent"], 3)
            draw.line((64 + side * 16, 30, 64 + side * 31, 20), fill=rgba(pal["accent_light"]), width=2)
        _outline_polygon(draw, [(58, 27), (64, 9), (70, 27)], pal["accent_light"], 2)
    elif race == "demon":
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 10, 29), (64 + side * 31, 7), (64 + side * 27, 39)], pal["accent_shadow"], 3)
    elif race == "angel":
        draw.ellipse((43, 12, 85, 21), fill=rgba(INK))
        draw.ellipse((47, 14, 81, 19), outline=rgba(pal["accent_light"]), width=2)

    _hair(draw, profile, pal)
    _face(draw, profile, pal)


def _hair(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    race = str(profile.get("ancestry", "human"))
    hair = str(profile.get("hair", ""))
    if race in {"undead", "stoneborn", "treefolk", "arachnoid", "seakin", "wyrmborn", "minotaur", "werewolf", "demon", "angel"} and hair in {"", "none"}:
        return
    hair_color = str(profile.get("hair_color", shade(pal["primary_shadow"], -0.2)))
    if hair == "bald_sides":
        draw.arc((42, 23, 86, 64), 185, 355, fill=rgba(pal["skin_light"]), width=2)
        for side in (-1, 1):
            _outline_polygon(draw, [(64 + side * 18, 35), (64 + side * 28, 30), (64 + side * 25, 65), (64 + side * 17, 71)], "#d8d4bd", 2)
        return
    if "hood" in hair:
        draw.arc((35, 16, 93, 82), 190, 350, fill=rgba(INK), width=10)
        draw.arc((39, 20, 89, 78), 190, 350, fill=rgba(hair_color), width=6)
        return
    draw.pieslice((38, 16, 90, 70), 180, 360, fill=rgba(INK))
    draw.pieslice((42, 20, 86, 66), 180, 360, fill=rgba(hair_color))
    for x in (44, 52, 62, 71, 81):
        length = 6 + (x * 3) % 9
        draw.polygon([(x - 4, 30), (x + 4, 28), (x, 28 + length)], fill=rgba(hair_color))
    if hair in {"long", "long_dark", "braid", "mane"} or profile.get("presentation") == "feminine":
        for side in (-1, 1):
            _line(draw, [(64 + side * 20, 42), (64 + side * 29, 66), (64 + side * 24, 95)], hair_color, 5, 9)
    if hair in {"topknot", "crest"}:
        _outline_ellipse(draw, (56, 6, 72, 25), hair_color, 3)


def _face(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    race = str(profile.get("ancestry", "human"))
    eye = pal["accent_light"] if race in {"vampire", "demon", "angel", "seakin", "wyrmborn", "stoneborn"} else "#f4ead1"
    draw.polygon([(45, 42), (58, 39), (58, 45), (47, 47)], fill=rgba(pal["skin_shadow"]))
    draw.polygon([(83, 42), (70, 39), (70, 45), (81, 47)], fill=rgba(pal["skin_shadow"]))
    draw.rectangle((47, 44, 58, 50), fill=rgba(INK))
    draw.rectangle((70, 44, 81, 50), fill=rgba(INK))
    draw.rectangle((51, 45, 55, 48), fill=rgba(eye))
    draw.rectangle((73, 45, 77, 48), fill=rgba(eye))
    draw.point((53, 45), fill=rgba("#ffffff"))
    draw.point((75, 45), fill=rgba("#ffffff"))
    draw.line((64, 48, 60, 58, 65, 59), fill=rgba(pal["skin_shadow"]), width=2)
    draw.line((53, 65, 64, 69, 75, 65), fill=rgba(INK), width=2)
    draw.line((57, 66, 64, 68, 71, 66), fill=rgba(pal["skin_light"]), width=1)

    if race in {"orc", "troll", "goblin"}:
        _outline_polygon(draw, [(52, 64), (58, 64), (55, 76)], PAPER, 1)
        _outline_polygon(draw, [(70, 64), (76, 64), (73, 76)], PAPER, 1)
    if race == "vampire":
        draw.polygon([(58, 66), (62, 66), (60, 72)], fill=rgba(PAPER))
        draw.polygon([(66, 66), (70, 66), (68, 72)], fill=rgba(PAPER))
    if race == "dwarf":
        beard = pal["secondary"]
        _outline_polygon(draw, [(45, 61), (83, 61), (76, 94), (64, 104), (52, 94)], beard, 3)
        draw.line((54, 66, 59, 93), fill=rgba(pal["secondary_light"]), width=2)
        draw.line((74, 66, 69, 93), fill=rgba(pal["secondary_shadow"]), width=2)
        draw.line((64, 70, 64, 99), fill=rgba(pal["secondary_light"]), width=2)
    if race == "gnome":
        draw.rectangle((43, 41, 61, 54), outline=rgba(INK), width=3)
        draw.rectangle((67, 41, 85, 54), outline=rgba(INK), width=3)
        draw.line((61, 47, 67, 47), fill=rgba(pal["secondary"]), width=3)
        draw.rectangle((47, 44, 57, 50), outline=rgba(pal["accent_light"]), width=2)
        draw.rectangle((71, 44, 81, 50), outline=rgba(pal["accent_light"]), width=2)


def _weapon_and_gear(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    weapon = str(profile.get("weapon", "none")).lower()
    if weapon in {"", "none"}:
        return
    if any(token in weapon for token in ("staff", "lance", "conduit", "rapier", "blade", "sabre", "bow", "greatbow", "hammer", "maul", "breaker")):
        _line(draw, [(96, 108), (111, 71), (116, 30)], pal["secondary"], 4, 8)
    if any(token in weapon for token in ("staff", "lance", "conduit")):
        _outline_ellipse(draw, (106, 18, 124, 36), pal["accent"], 3)
        draw.ellipse((111, 23, 119, 31), fill=rgba(pal["accent_light"]))
        draw.line((115, 14, 115, 7), fill=rgba(pal["accent_light"]), width=2)
        draw.line((105, 20, 99, 15), fill=rgba(pal["accent"]), width=2)
    elif any(token in weapon for token in ("hammer", "maul", "breaker")):
        _outline_polygon(draw, [(103, 19), (123, 25), (119, 42), (98, 36)], pal["secondary"], 3)
        draw.rectangle((104, 24, 118, 29), fill=rgba(pal["accent_shadow"]))
    elif any(token in weapon for token in ("bow", "greatbow")):
        draw.arc((92, 24, 126, 100), 90, 270, fill=rgba(INK), width=7)
        draw.arc((95, 27, 123, 97), 90, 270, fill=rgba(pal["secondary"]), width=3)
        draw.line((110, 27, 110, 97), fill=rgba(PAPER), width=1)
    elif any(token in weapon for token in ("orb", "disc", "detonator", "gauntlet", "coil", "pack", "horn")):
        _outline_ellipse(draw, (96, 78, 123, 105), pal["secondary"], 3)
        draw.ellipse((103, 85, 116, 98), fill=rgba(pal["accent_shadow"]))
        draw.rectangle((108, 90, 112, 94), fill=rgba(pal["accent_light"]))
        for angle in range(0, 360, 90):
            dx = round(math.cos(math.radians(angle)) * 16)
            dy = round(math.sin(math.radians(angle)) * 16)
            draw.line((110 + dx * 2 // 3, 92 + dy * 2 // 3, 110 + dx, 92 + dy), fill=rgba(pal["accent"]), width=2)

    if "shield" in weapon or "prism" in weapon:
        _outline_polygon(draw, [(19, 73), (37, 64), (43, 83), (36, 108), (20, 116), (10, 103), (10, 83)], pal["accent_shadow"], 4)
        draw.polygon([(23, 76), (35, 70), (38, 83), (32, 102), (22, 108), (15, 99), (15, 84)], fill=rgba(pal["accent"]))
        draw.line((22, 79, 34, 95), fill=rgba(pal["accent_light"]), width=2)


def _race_details(draw: ImageDraw.ImageDraw, profile: dict[str, Any], pal: dict[str, str]) -> None:
    race = str(profile.get("ancestry", "human"))
    if race == "seakin":
        for side in (-1, 1):
            draw.arc((64 + side * 9 - 17, 52, 64 + side * 9 + 17, 83), 20 if side < 0 else 160, 170 if side < 0 else 310, fill=rgba(pal["accent_light"]), width=2)
    elif race == "nymph":
        for x, y in ((30, 75), (92, 70), (38, 103), (87, 101)):
            draw.line((x, y + 7, x, y - 5), fill=rgba(pal["secondary_shadow"]), width=2)
            draw.ellipse((x - 4, y - 8, x + 4, y), fill=rgba(pal["secondary_light"]))
    elif race == "werewolf":
        for x in (42, 48, 80, 86):
            draw.line((x, 74, x - 3 if x < 64 else x + 3, 91), fill=rgba(pal["skin_light"]), width=2)
    elif race == "vampire":
        draw.polygon([(36, 75), (45, 68), (52, 83)], fill=rgba(pal["primary_light"]))
        draw.polygon([(92, 75), (83, 68), (76, 83)], fill=rgba(pal["primary_light"]))
    elif race == "demon":
        for side in (-1, 1):
            draw.polygon([(64 + side * 26, 73), (64 + side * 38, 62), (64 + side * 32, 88)], fill=rgba(INK))
            draw.polygon([(64 + side * 27, 74), (64 + side * 35, 66), (64 + side * 30, 84)], fill=rgba(pal["accent_shadow"]))


def _portrait_base(profile: dict[str, Any]) -> Image.Image:
    pal = _palette(profile)
    image = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _background(draw, profile, pal)
    _element_halo(draw, profile, pal)
    _back_features(draw, profile, pal)
    _torso(draw, profile, pal)
    _head(draw, profile, pal)
    _race_details(draw, profile, pal)
    _weapon_and_gear(draw, profile, pal)
    draw.rectangle((9, 116, 118, 120), fill=rgba(INK))
    draw.rectangle((12, 117, 115, 118), fill=rgba(pal["accent_light"]))
    return image


def make_portrait(profile: dict[str, Any], size: int) -> Image.Image:
    base = _portrait_base(profile)
    if size == BASE:
        return base
    return base.resize((size, size), Image.Resampling.NEAREST)


def make_selection_icon(profile: dict[str, Any]) -> Image.Image:
    return make_portrait(profile, 48)
