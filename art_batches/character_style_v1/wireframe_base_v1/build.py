"""Offline pixel mannequin from exported FLUX fixed-bone poses; never a runtime renderer."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
CELL = 96
PALETTE = {
    "fill": "#241d33", "core": "#b9a1de", "rear": "#7c6e9a",
    "left": "#e1a1b5", "right": "#8dbee0", "front": "#f4e6bf",
    "dark": "#15141e", "light": "#e3e0dc",
}


def pixel(point):
    return tuple(int(round(v)) for v in point)


def mix(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))


def hull(points):
    points = sorted(set(map(pixel, points)))
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for point in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return lower[:-1] + upper[:-1]


def segment(draw, start, end, radius, color, foot=False):
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = math.hypot(dx, dy)
    if length < 0.001:
        return
    nx, ny = -dy / length * radius, dx / length * radius
    ring = [pixel((start[0]+nx, start[1]+ny)), pixel((end[0]+nx, end[1]+ny)),
            pixel((end[0]-nx, end[1]-ny)), pixel((start[0]-nx, start[1]-ny))]
    draw.polygon(ring, fill=PALETTE["fill"], outline=color)
    # A single longitudinal mesh seam keeps the 96px figure legible.
    if not foot and length >= 7:
        draw.line([pixel(start), pixel(end)], fill=PALETTE["rear"])
    if not foot:
        cx, cy = pixel(end)
        draw.point((cx, cy), fill=PALETTE["front"])


def render_pose(pose, data):
    canvas = Image.new("RGBA", (CELL, CELL))
    draw = ImageDraw.Draw(canvas)
    points = pose["points"]
    unit = pose["pixels_per_unit"]
    rear = pose["direction"] in ("north_east", "north", "north_west")

    def chain(part):
        color = PALETTE["left" if part["side"] == "l" else "right"]
        keys = part["keys"]
        for i in range(len(keys)-1):
            foot = keys[i].startswith("ankle")
            radius = unit * (0.023 if foot else (0.035 if part["kind"] == "leg" else 0.028))
            segment(draw, points[keys[i]], points[keys[i+1]], radius, color, foot)

    for part in pose["chains"]:
        if part["depth"] <= pose["torso_depth"]:
            chain(part)
    corners = pose["torso_corners"]
    draw.polygon(hull(corners), fill=PALETTE["fill"], outline=PALETTE["core"])
    # Existing corners alternate back/front at each rigid torso corner.
    surface = [corners[i] for i in ([0, 2, 4, 6] if rear else [1, 3, 5, 7])]
    draw.line([pixel(p) for p in surface+[surface[0]]], fill=PALETTE["core"])
    for t in (0.33, 0.66):
        draw.line([pixel(mix(surface[0], surface[3], t)), pixel(mix(surface[1], surface[2], t))], fill=PALETTE["rear"])
    draw.line([pixel(surface[0]), pixel(surface[2])], fill=PALETTE["rear"])
    draw.line([pixel(surface[1]), pixel(surface[3])], fill=PALETTE["rear"])
    # Sternum is warm and solid; back spine is lavender and stippled.
    top, bottom = mix(surface[0], surface[1], 0.5), mix(surface[2], surface[3], 0.5)
    if rear:
        for t in (0.1, 0.3, 0.5, 0.7, 0.9):
            draw.point(pixel(mix(top, bottom, t)), fill=PALETTE["core"])
    else:
        draw.line([pixel(top), pixel(bottom)], fill=PALETTE["front"])
    for part in pose["chains"]:
        if part["depth"] > pose["torso_depth"]:
            chain(part)
    draw.line([pixel(points["neck"]), pixel(points["head"])], fill=PALETTE["core"], width=2)
    hx, hy = points["head"]
    radius = unit * data["head_radius"]
    # Half-open geometric bounds yield exactly 58/68/76 opaque pixels south-grounded.
    bounds = (math.ceil(hx-radius), math.ceil(hy-radius-0.00001)+1,
              math.ceil(hx+radius)-1, math.ceil(hy+radius)-1)
    draw.ellipse(bounds, fill=PALETTE["fill"], outline=PALETTE["core"])
    cx, cy = pixel(points["head"])
    rx = max(1, int(radius * 0.45))
    draw.arc((cx-rx, bounds[1], cx+rx, bounds[3]), 0, 360, fill=PALETTE["rear"])
    draw.arc((bounds[0], cy-2, bounds[2], cy+2), 0, 360, fill=PALETTE["rear"])
    if not rear:
        nose = pixel(points["nose"])
        draw.line([(cx, cy), nose], fill=PALETTE["front"])
        draw.point(nose, fill=PALETTE["front"])
    else:
        # Unmistakable occiput: no face/nose; single rear seam.
        draw.line([(cx, bounds[1]+2), (cx, cy)], fill=PALETTE["core"])
    # The registration contract excludes ground/shadow pixels at and below pivot.
    canvas.paste((0, 0, 0, 0), (0, 84, CELL, CELL))
    return canvas


def board(data, cells, scale, background):
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 14 if scale == 1 else 26)
    w = 160 + 8 * CELL * scale
    h = 92 + 3 * CELL * scale
    result = Image.new("RGB", (w, h), PALETTE[background])
    draw = ImageDraw.Draw(result)
    text = "#eee8f5" if background == "dark" else "#30273d"
    draw.text((16, 12), "FLUX / REUSABLE WIREFRAME BASE / CANDIDATE", font=font, fill=text)
    for i, direction in enumerate(data["directions"]):
        short = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"][i]
        draw.text((160+i*CELL*scale+8, 56), short, font=font, fill=text)
    for row, body in enumerate(("small", "middle", "large")):
        draw.text((16, 92+row*CELL*scale+25), body.upper(), font=font, fill=text)
        draw.text((16, 92+row*CELL*scale+52), str(data["heights"][body])+" px", font=font, fill=text)
        for column, direction in enumerate(data["directions"]):
            cell = cells[(body, "grounded", direction)].resize((CELL*scale, CELL*scale), Image.Resampling.NEAREST)
            result.paste(cell, (160+column*CELL*scale, 92+row*CELL*scale), cell)
    return result


def main():
    data = json.loads((HERE / "rig-data.json").read_text(encoding="utf-8"))
    rig_source = REPO / data["rig_source"].removeprefix("res://")
    assert hashlib.sha256(rig_source.read_bytes()).hexdigest() == data["rig_sha256"], "Stale rig export"
    contract = json.loads((HERE.parent / "template_v2/contract.json").read_text(encoding="utf-8"))
    assert data["rows"] == contract["rows"]
    assert data["heights"] == contract["standing_height_pixels"]
    assert data["cell"] == contract["cell"] and data["pivot"] == contract["feet_pivot"]
    cells, bounds, atlases, seen = {}, {}, {}, set()
    for pose in data["poses"]:
        key = (pose["body"], pose["state"], pose["direction"])
        assert key not in seen
        seen.add(key)
        for side in ("l", "r"):
            for start, end, bone in (("hip", "knee", "thigh"), ("knee", "ankle", "shin"),
                                     ("ankle", "toe", "foot"), ("shoulder", "elbow", "humerus"),
                                     ("elbow", "hand", "forearm")):
                a = pose["landmarks"][start+"_"+side]
                b = pose["landmarks"][end+"_"+side]
                assert abs(math.dist(a, b)-data["bone_lengths"][bone]) < 0.00001, (key, bone)
        if pose["state"] in ("walk", "walk_b", "sprint", "sprint_b"):
            support = "r" if pose["state"].endswith("_b") else "l"
            passing = "l" if support == "r" else "r"
            landmarks = pose["landmarks"]
            assert landmarks["ankle_"+support][2] == 0
            assert landmarks["ankle_"+passing][2] > 0
            assert landmarks["ankle_"+support][1] > landmarks["ankle_"+passing][1]
            assert landmarks["hand_"+support][1] < landmarks["hand_"+passing][1]
        cell = render_pose(pose, data)
        bbox = cell.getbbox()
        assert bbox and bbox[0] > 0 and bbox[2] < 96 and bbox[1] > 0 and bbox[3] == 84, (key, bbox)
        assert set(cell.getchannel("A").getdata()) <= {0, 255}, key
        if pose["state"] == "grounded" and pose["direction"] == "south":
            assert bbox[3]-bbox[1] == data["heights"][pose["body"]], (key, bbox)
        cells[key], bounds["/".join(key)] = cell, list(bbox)
        atlas = atlases.setdefault(pose["body"], Image.new("RGBA", (768, 960)))
        atlas.paste(cell, (data["directions"].index(pose["direction"])*CELL, data["rows"].index(pose["state"])*CELL))
    assert len(cells) == 240
    for body in data["heights"]:
        for direction in data["directions"]:
            for gait in ("walk", "sprint"):
                assert cells[(body, gait, direction)].tobytes() != cells[(body, gait+"_b", direction)].tobytes()
    outputs = {}
    for body, atlas in atlases.items():
        path = HERE / (body+"-wireframe.png")
        atlas.save(path)
        outputs[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for scale in (1, 4):
        for background in ("dark", "light"):
            board(data, cells, scale, background).save(HERE / f"overview-{scale}x-{background}.png")
    # All ten poses in contract order: usable review sheet, not animation interpolation.
    for body, atlas in atlases.items():
        preview = Image.new("RGBA", atlas.size, PALETTE["dark"])
        preview.alpha_composite(atlas)
        preview.resize((1536, 1920), Image.Resampling.NEAREST).save(HERE / (body+"-all-poses-2x.png"))
    evidence = {"status": "candidate_only_not_accepted", "cells_checked": len(cells),
                "binary_alpha": True, "all_cell_bottoms": 83, "cell": [96, 96], "pivot": [48, 84],
                "fixed_bone_length_checks": 2400, "anatomical_contact_checks": 384,
                "standing_heights_verified_south": data["heights"], "rig_sha256": data["rig_sha256"],
                "atlas_sha256": outputs, "bounds": bounds, "runtime_files_modified": False,
                "limitations": ["Ten authored poses, not complete smooth animation clips.",
                                "Identical normalized anatomy at three sizes; no race or character identity.",
                                "Offline source rig does not specify independent gameplay casting aim.",
                                "Geometric candidate has not passed user or in-game acceptance."]}
    (HERE / "evidence.json").write_text(json.dumps(evidence, indent=2)+"\n", encoding="utf-8")
    print("PASS: 240 candidate cells; binary alpha, registration, 58/68/76 south heights, distinct contacts, source hash")


if __name__ == "__main__":
    main()
