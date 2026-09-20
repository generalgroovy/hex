"""Bake shared wireframe locomotion pages and auditable move/aim contact sheets."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
OUT = REPO / "assets/sprites/wireframe_motion_v2"
spec = importlib.util.spec_from_file_location("wireframe_base", HERE.parent / "wireframe_base_v1/build.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
PALETTE, pixel, mix, segment = base.PALETTE, base.pixel, base.mix, base.segment
BODIES = ("small", "middle", "large")
SHORT = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")


def render(pose, data):
    canvas = Image.new("RGBA", (96, 96))
    draw = ImageDraw.Draw(canvas)
    points, unit = pose["points"], pose["pixels_per_unit"]
    rear = pose["aim"] in (3, 4, 5)

    def chain(part):
        color = PALETTE["left" if part["side"] == "l" else "right"]
        keys = part["keys"]
        for i in range(len(keys)-1):
            foot = keys[i].startswith("ankle")
            radius = unit * (0.026 if foot else (0.04 if part["kind"] == "leg" else 0.032))
            segment(draw, points[keys[i]], points[keys[i+1]], radius, color, foot)

    for part in pose["chains"]:
        if part["depth"] <= pose["torso_depth"]:
            chain(part)
    vertices = pose["mesh_points"]
    for face in pose["mesh_faces"]:
        polygon = [pixel(vertices[i]) for i in face["indices"]]
        draw.polygon(polygon, fill=PALETTE["fill"], outline=PALETTE["rear"])
        draw.line([polygon[0], polygon[2]], fill="#514361")
    draw.line(base.hull(vertices)+[base.hull(vertices)[0]], fill=PALETTE["core"])
    if rear:
        top, bottom = mix(points["shoulder_l"], points["shoulder_r"], 0.5), points["pelvis"]
        for t in (0.1, 0.3, 0.5, 0.7, 0.9):
            draw.point(pixel(mix(top, bottom, t)), fill=PALETTE["core"])
    else:
        draw.line([pixel(p) for p in pose["sternum"]], fill=PALETTE["front"])
    for part in pose["chains"]:
        if part["depth"] > pose["torso_depth"]:
            chain(part)
    draw.line([pixel(points["neck"]), pixel(points["head"])], fill=PALETTE["core"], width=2)
    hx, hy = points["head"]
    radius = unit * data["head_radius"]
    bounds = (math.ceil(hx-radius), math.ceil(hy-radius-0.00001)+1,
              math.ceil(hx+radius)-1, math.ceil(hy+radius)-1)
    draw.ellipse(bounds, fill=PALETTE["fill"], outline=PALETTE["core"])
    cx, cy = pixel(points["head"])
    rx = max(1, int(radius * 0.45))
    draw.arc((cx-rx, bounds[1], cx+rx, bounds[3]), 0, 360, fill=PALETTE["rear"])
    draw.arc((bounds[0], cy-2, bounds[2], cy+2), 0, 360, fill=PALETTE["rear"])
    if rear:
        draw.line([(cx, bounds[1]+2), (cx, cy)], fill=PALETTE["core"])
    else:
        draw.line([(cx, cy), pixel(points["nose"])], fill=PALETTE["front"])
    canvas.paste((0, 0, 0, 0), (0, 84, 96, 96))
    return canvas


def combo_board(body, cells, scale=1, phase=1):
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 14 if scale == 1 else 24)
    board = Image.new("RGB", (104+768*scale, 80+768*scale), PALETTE["dark"])
    draw = ImageDraw.Draw(board)
    draw.text((12, 10), body.upper()+" / 64 MOVE-A / AIM-B PAIRS", font=font, fill="#e9e1f2")
    for aim in range(8):
        draw.text((104+aim*96*scale+8, 45), "B:"+SHORT[aim], font=font, fill="#e9e1f2")
    for travel in range(8):
        draw.text((12, 80+travel*96*scale+32), "A:"+SHORT[travel], font=font, fill="#e9e1f2")
        for aim in range(8):
            cell = cells[(body, travel, aim, phase)].resize((96*scale, 96*scale), Image.Resampling.NEAREST)
            board.paste(cell, (104+aim*96*scale, 80+travel*96*scale), cell)
    return board


def gif_examples(cells):
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 20)
    cases = [(2, 2, "FORWARD / MOVE E AIM E"), (0, 2, "STRAFE / MOVE S AIM E"), (6, 2, "BACKPEDAL / MOVE W AIM E")]
    frames = []
    for phase in range(8):
        frame = Image.new("RGB", (1152, 3*408+48), PALETTE["dark"])
        draw = ImageDraw.Draw(frame)
        draw.text((16, 8), "EIGHT-POSE CYCLE / SMALL 58 / MIDDLE 68 / LARGE 76", font=font, fill="#e9e1f2")
        for row, (travel, aim, title) in enumerate(cases):
            draw.text((16, 48+row*408), title, font=font, fill="#e9e1f2")
            for col, body in enumerate(BODIES):
                cell = cells[(body, travel, aim, phase)].resize((384, 384), Image.Resampling.NEAREST)
                frame.paste(cell, (col*384, 72+row*408), cell)
        frames.append(frame)
    frames[0].save(HERE / "motion-examples-4x.gif", save_all=True, append_images=frames[1:], duration=100, loop=0, disposal=2)


def main():
    data = json.loads((HERE / "rig-data.json").read_text(encoding="utf-8"))
    assert hashlib.sha256((REPO / data["rig_source"].removeprefix("res://")).read_bytes()).hexdigest() == data["rig_sha256"]
    contract = json.loads((HERE.parent / "template_v2/contract.json").read_text(encoding="utf-8"))
    assert data["base_rows"] == contract["rows"] and data["heights"] == contract["standing_height_pixels"]
    OUT.mkdir(parents=True, exist_ok=True)
    base_pages = {body: Image.new("RGBA", (768, 960)) for body in BODIES}
    motion_pages = {body: Image.new("RGBA", (1536, 3072)) for body in BODIES}
    sprint_pages = {body: Image.new("RGBA", (1536, 3072)) for body in BODIES}
    cells, seen, bounds, poses = {}, set(), {}, {}
    sprint_cells, sprint_poses = {}, {}
    bone_checks = plant_checks = 0
    ankle_angles, knee_angles = [], []
    def angle_at(a, joint, b):
        u, v = [x-y for x, y in zip(a, joint)], [x-y for x, y in zip(b, joint)]
        cosine = sum(x*y for x, y in zip(u, v)) / (math.hypot(*u)*math.hypot(*v))
        return math.degrees(math.acos(max(-1, min(1, cosine))))
    for pose in data["poses"]:
        body, state = pose["body"], pose["state"]
        motion = state in ("locomotion", "sprint_locomotion")
        sprinting = state == "sprint_locomotion"
        key = (body, pose["travel"], pose["aim"], pose["phase"]) if motion else (body, state, pose["aim"])
        unique_key = (state,) + key
        assert unique_key not in seen, unique_key
        seen.add(unique_key)
        for side in ("l", "r"):
            for start, end, bone in (("hip", "knee", "thigh"), ("knee", "ankle", "shin"),
                                     ("ankle", "toe", "foot"), ("shoulder", "elbow", "humerus"),
                                     ("elbow", "hand", "forearm")):
                assert abs(math.dist(pose["landmarks"][start+"_"+side], pose["landmarks"][end+"_"+side])-data["bone_lengths"][bone]) < 0.00001, (key, bone)
                bone_checks += 1
        if motion:
            assert pose["waist_yaw_twist_degrees"] == 0
            land = pose["landmarks"]
            assert min(land["ankle_l"][2], land["ankle_r"][2]) < 0.00001
            assert land["ankle_l"][0] < land["ankle_r"][0], (key, "crossed feet")
            for side in ("l", "r"):
                ankle = angle_at(land["knee_"+side], land["ankle_"+side], land["toe_"+side])
                knee = angle_at(land["hip_"+side], land["knee_"+side], land["ankle_"+side])
                assert 54.999 <= ankle <= 125, (key, side, "ankle", ankle)
                assert 80 <= knee <= 175, (key, side, "knee", knee)
                assert land["toe_"+side][2] >= -0.000001, (key, "toe penetrates ground")
                ankle_angles.append(ankle)
                knee_angles.append(knee)
            plant_checks += 2
        cell = render(pose, data)
        box = cell.getbbox()
        assert box and 0 < box[0] and box[2] < 96 and 0 < box[1] and box[3] == 84, (key, box)
        assert set(cell.getchannel("A").getdata()) <= {0, 255}
        if state == "grounded" and pose["aim"] == 0:
            assert box[3]-box[1] == data["heights"][body], (body, box)
        bounds["/".join(map(str, unique_key))] = list(box)
        if motion:
            bank_cells, bank_poses = (sprint_cells, sprint_poses) if sprinting else (cells, poses)
            bank_cells[key], bank_poses[key] = cell, pose
            index = ((pose["travel"]*8+pose["aim"])*8+pose["phase"])
            (sprint_pages if sprinting else motion_pages)[body].paste(cell, (index % 16*96, index // 16*96))
        else:
            base_pages[body].paste(cell, (pose["aim"]*96, data["base_rows"].index(state)*96))
    assert len(cells) == 1536 and len(sprint_cells) == 1536 and len(seen) == 3312
    for bank_cells, bank_poses in ((cells, poses), (sprint_cells, sprint_poses)):
        for body in BODIES:
            for travel in range(8):
                for aim in range(8):
                    assert len({bank_cells[(body, travel, aim, p)].tobytes() for p in range(8)}) == 8, (body, travel, aim)
                    a, b = bank_poses[(body, travel, aim, 2)]["landmarks"], bank_poses[(body, travel, aim, 6)]["landmarks"]
                    assert a["ankle_l"][2] < 0.00001 and a["ankle_r"][2] > 0.08
                    assert b["ankle_r"][2] < 0.00001 and b["ankle_l"][2] > 0.08
    assert all(cells[key].tobytes() != sprint_cells[key].tobytes() for key in cells), "Sprint must have distinct authored geometry at every combination/phase"
    manifest = {"schema_version": 2, "cell": [96, 96], "pivot": [48, 84],
                "directions": data["directions"], "base_rows": data["base_rows"],
                "locomotion": {"columns": 16, "rows": 32, "phases": 8,
                               "index_formula": "((travel*8+aim)*8+phase)", "gait_policy": "distinct_walk_sprint_fixed_bone_banks"}, "sizes": {}}
    for body in BODIES:
        entry = {"reference_height": data["heights"][body]}
        for kind, page in (("base", base_pages[body]), ("locomotion", motion_pages[body]), ("sprint", sprint_pages[body])):
            path = OUT / (body+"-"+kind+".png")
            page.save(path)
            entry[kind] = "res://assets/sprites/wireframe_motion_v2/"+path.name
            entry[kind+"_dimensions"] = list(page.size)
            entry[kind+"_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            entry[kind+"_rgba_sha256"] = hashlib.sha256(page.tobytes()).hexdigest()
        manifest["sizes"][body] = entry
        for scale in (1, 4):
            combo_board(body, cells, scale).save(HERE / (body+f"-64-pairs-{scale}x.png"))
            combo_board(body, sprint_cells, scale).save(HERE / (body+f"-sprint-64-pairs-{scale}x.png"))
    gif_examples(cells)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    evidence = {"status": "baked_local_pending_runtime_verification", "base_cells": 240,
                "locomotion_cells": len(cells), "sprint_cells": len(sprint_cells), "move_aim_pairs_per_body_per_gait": 64, "phases_per_pair": 8,
                "fixed_bone_checks": bone_checks, "plant_and_non_crossing_checks": plant_checks,
                "all_phase_cells_distinct": True, "binary_alpha": True, "last_opaque_y": 83,
                "waist_yaw_twist_degrees": 0, "standing_heights": data["heights"],
                "ankle_included_angle_degrees": [min(ankle_angles), max(ankle_angles)],
                "knee_included_angle_degrees": [min(knee_angles), max(knee_angles)],
                "exporter_sha256": hashlib.sha256((HERE / "export_rig.gd").read_bytes()).hexdigest(),
                "rig_data_sha256": hashlib.sha256((HERE / "rig-data.json").read_bytes()).hexdigest(),
                "rasterizer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "source_rig_sha256": data["rig_sha256"], "bounds": bounds,
                "limits": ["Eight baked phases, no subpixel interpolation.",
                           "Walk and sprint use separate fixed-bone eight-phase banks; neither is motion capture.",
                           "Fixed-bone geometric motion is not motion capture or biomechanical certification.",
                           "This source build does not establish in-game or user acceptance."]}
    (HERE / "evidence.json").write_text(json.dumps(evidence, indent=2)+"\n", encoding="utf-8")
    print(f"PASS: 240 base + {len(cells)} walk + {len(sprint_cells)} sprint cells; {bone_checks} fixed bones; 384 complete eight-phase move/aim pairs; zero waist twist")


if __name__ == "__main__":
    main()
