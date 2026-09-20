"""Dress the fixed-bone rig as a shared warm pixel adventurer, then bake every gait."""
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
DISPLAY_SCALE = 0.92
DISPLAY_HEIGHTS = {"small": 53, "middle": 63, "large": 70}
STYLE_ID = "warm_adventurer_foundation_v1"
CLOTH = {"outline": "#211b19", "shade": "#282729", "dark": "#383332",
         "mid": "#514940", "light": "#71624e", "leather": "#67462f",
         "leather_light": "#976c3e", "gold_dark": "#8d642b", "gold": "#c79d4b",
         "gold_light": "#efd18c", "skin_dark": "#9d633d", "skin": "#d69c62",
         "skin_light": "#edc18b", "hair": "#312b25", "hair_light": "#6f5940",
         "eye": "#171a1c"}


def display_point(point):
    return (48 + (point[0]-48)*DISPLAY_SCALE, 84 + (point[1]-84)*DISPLAY_SCALE)


def cloth_segment(draw, start, end, radius, fill, highlight=None, end_radius=None):
    dx, dy = end[0]-start[0], end[1]-start[1]
    length = math.hypot(dx,dy)
    if length < .001:
        return
    nx, ny = -dy/length, dx/length
    end_radius = radius if end_radius is None else end_radius
    ring = [pixel((start[0]+nx*radius,start[1]+ny*radius)),pixel((end[0]+nx*end_radius,end[1]+ny*end_radius)),
            pixel((end[0]-nx*end_radius,end[1]-ny*end_radius)),pixel((start[0]-nx*radius,start[1]-ny*radius))]
    draw.polygon(ring,fill=fill,outline=CLOTH["outline"])
    if highlight:
        # Filled, tapered light-facing cloth panel, not a colored bone stroke.
        a,b=mix(start,end,.13),mix(start,end,.86)
        light_panel=[pixel((a[0]+nx*radius*.6,a[1]+ny*radius*.6)),
                     pixel((b[0]+nx*end_radius*.6,b[1]+ny*end_radius*.6)),
                     pixel((b[0]+nx*end_radius*.08,b[1]+ny*end_radius*.08)),
                     pixel((a[0]+nx*radius*.08,a[1]+ny*radius*.08))]
        draw.polygon(light_panel,fill=highlight)
    return ring


def render(pose, data):
    canvas = Image.new("RGBA", (96, 96))
    draw = ImageDraw.Draw(canvas)
    points = {key: display_point(point) for key,point in pose["points"].items()}
    unit = pose["pixels_per_unit"]*DISPLAY_SCALE
    rear = pose["aim"] in (3, 4, 5)

    def chain(part):
        near = part["depth"] > pose["torso_depth"]
        keys = part["keys"]
        for i in range(len(keys)-1):
            foot = keys[i].startswith("ankle")
            start,end = points[keys[i]],points[keys[i+1]]
            # Garment volume surrounds the unchanged bone endpoints. The thigh
            # and sleeve are deliberately broader than the articulated joints.
            radius = unit * (0.070 if foot else ((0.078 if i == 0 else 0.065) if part["kind"] == "leg" else (0.069 if i == 0 else 0.060)))
            fill = CLOTH["dark"] if part["kind"] == "leg" else CLOTH["mid"]
            taper = .82 if i == 0 else .9
            cloth_segment(draw,start,end,radius,fill if near else CLOTH["shade"],CLOTH["light"] if near else CLOTH["dark"],radius*taper)
            if foot:
                cloth_segment(draw,start,end,radius,CLOTH["leather"],CLOTH["leather_light"] if near else CLOTH["dark"],radius*1.05)
            elif part["kind"] == "leg" and i == 1:
                boot_top = mix(start,end,.34)
                ring = cloth_segment(draw,boot_top,end,radius*1.18,CLOTH["leather"],CLOTH["leather_light"] if near else CLOTH["dark"],radius)
                if ring:
                    draw.line([ring[0],ring[3]],fill=CLOTH["gold"] if part["side"] == "r" else CLOTH["leather_light"])
            elif part["kind"] == "arm" and i == 1:
                glove_top = mix(start,end,.55)
                ring = cloth_segment(draw,glove_top,end,radius*1.18,CLOTH["leather"],CLOTH["leather_light"] if near else CLOTH["dark"],radius*1.08)
                if ring:
                    draw.line([ring[0],ring[3]],fill=CLOTH["gold"])
                hand_x,hand_y=pixel(end)
                glove_radius=max(1,int(round(unit*.055)))
                draw.ellipse((hand_x-glove_radius,hand_y-glove_radius,hand_x+glove_radius,hand_y+glove_radius),fill=CLOTH["leather"],outline=CLOTH["outline"])
                draw.line([(hand_x-1,hand_y-1),(hand_x,hand_y-1)],fill=CLOTH["leather_light"])
                draw.point((hand_x,hand_y+1),fill=CLOTH["skin_light"] if near else CLOTH["skin_dark"])
        if part["kind"] == "leg" and part["side"] == "r":
            # One small brass kneepad keeps anatomical leg exchange readable.
            knee_x,knee_y=pixel(points["knee_r"])
            draw.rectangle((knee_x-1,knee_y-1,knee_x,knee_y),fill=CLOTH["gold_dark"])
            draw.point((knee_x-1,knee_y-1),fill=CLOTH["gold"])

    for part in pose["chains"]:
        if part["depth"] <= pose["torso_depth"]:
            chain(part)
    # Short split leather coat follows the real thigh chains; it is not a
    # detached cape or a static costume painted over unrelated motion.
    hip_l,hip_r = points["hip_l"],points["hip_r"]
    hem_l,hem_r = mix(hip_l,points["knee_l"],.62),mix(hip_r,points["knee_r"],.62)
    lateral = ((hip_r[0]-hip_l[0])*.28,(hip_r[1]-hip_l[1])*.28)
    coat = [(hip_l[0]-lateral[0],hip_l[1]-lateral[1]),(hip_r[0]+lateral[0],hip_r[1]+lateral[1]),
            (hem_r[0]+lateral[0],hem_r[1]+lateral[1]),mix(hip_l,hip_r,.5),
            (hem_l[0]-lateral[0],hem_l[1]-lateral[1])]
    draw.polygon([pixel(p) for p in coat],fill=CLOTH["leather"],outline=CLOTH["outline"])
    draw.line([pixel(coat[2]),pixel(coat[3]),pixel(coat[4])],fill=CLOTH["gold_dark"])
    vertices = [display_point(point) for point in pose["mesh_points"]]
    for face in pose["mesh_faces"]:
        polygon = [pixel(vertices[i]) for i in face["indices"]]
        center_x = sum(p[0] for p in polygon)/len(polygon)
        fill = CLOTH["mid"] if center_x <= points["pelvis"][0] else CLOTH["dark"]
        draw.polygon(polygon, fill=fill)
    silhouette = base.hull(vertices)
    draw.line(silhouette+[silhouette[0]],fill=CLOTH["outline"])
    # Gold collar, dark belt and lapel are clothing on the rigid torso mesh.
    collar = [pixel(p) for p in vertices[:8]]
    draw.line(collar+[collar[0]],fill=CLOTH["gold_dark"])
    belt = [pixel(p) for p in vertices[16:24]]
    draw.line(belt+[belt[0]],fill=CLOTH["leather"],width=1)
    if rear:
        top, bottom = mix(points["shoulder_l"], points["shoulder_r"], 0.5), points["pelvis"]
        draw.line([pixel(mix(top,bottom,.15)),pixel(mix(top,bottom,.8))],fill=CLOTH["shade"])
        draw.point(pixel(mix(top,bottom,.15)),fill=CLOTH["gold_dark"])
    else:
        sternum = [display_point(p) for p in pose["sternum"]]
        draw.line([pixel(p) for p in sternum],fill=CLOTH["gold"])
        cx,cy = pixel(sternum[-1])
        draw.rectangle((cx-1,cy-1,cx+1,cy),fill=CLOTH["gold_dark"])
        draw.point((cx,cy-1),fill=CLOTH["gold_light"])
        for shoulder in ("shoulder_l","shoulder_r"):
            draw.line([pixel(mix(points[shoulder],sternum[0],.2)),pixel(sternum[0])],fill=CLOTH["gold"])
    for part in pose["chains"]:
        if part["depth"] > pose["torso_depth"]:
            chain(part)
    for shoulder in ("shoulder_l","shoulder_r"):
        x,y=pixel(points[shoulder])
        pad=max(1,int(round(unit*.057)))
        draw.ellipse((x-pad,y-1,x+pad,y+1),fill=CLOTH["leather"],outline=CLOTH["gold_dark"])
        draw.point((x-1,y-1),fill=CLOTH["gold"])
    draw.line([pixel(points["neck"]),pixel(points["head"])],fill=CLOTH["skin_dark"],width=2)
    hx,hy = pose["points"]["head"]
    radius = pose["pixels_per_unit"]*data["head_radius"]
    native_bounds = (math.ceil(hx-radius),math.ceil(hy-radius-.00001)+1,math.ceil(hx+radius)-1,math.ceil(hy+radius)-1)
    left,top = pixel(display_point(native_bounds[:2]))
    right,bottom = pixel(display_point(native_bounds[2:]))
    # Fuller lateral hair/cheeks; the crown and chin stay on their exact rows.
    hair_volume=max(1,int(round(unit*.025)))
    left-=hair_volume
    right+=hair_volume
    bounds = (left,top,right,bottom)
    cx,cy = pixel(points["head"])
    draw.ellipse(bounds,fill=CLOTH["hair"],outline=CLOTH["outline"])
    draw.line([(left+2,top+2),(cx,top+1),(right-2,top+2)],fill=CLOTH["hair_light"])
    if rear:
        if pose["aim"] != 4:
            draw.point((right-1 if pose["aim"] == 3 else left+1,cy+1),fill=CLOTH["skin_dark"])
    else:
        face_top = top + max(2,(bottom-top)//3)
        if pose["aim"] in (2,6):
            sign = 1 if pose["aim"] == 2 else -1
            face = [(cx-sign,face_top),(cx+sign*((right-left)//2-1),face_top+1),
                    (cx+sign*((right-left)//2-1),bottom-2),(cx,bottom-1),(cx-sign,cy+1)]
            draw.polygon(face,fill=CLOTH["skin"])
            draw.point((cx+sign,face_top+1),fill=CLOTH["eye"])
            draw.point(pixel(points["nose"]),fill=CLOTH["skin_light"])
            draw.point((cx+sign,bottom-2),fill=CLOTH["skin_dark"])
        else:
            shift = 1 if pose["aim"] == 1 else (-1 if pose["aim"] == 7 else 0)
            face = [(left+1+max(shift,0),face_top),(right-1+min(shift,0),face_top),
                    (right-1,bottom-2),(cx+shift,bottom-1),(left+1,bottom-2)]
            draw.polygon(face,fill=CLOTH["skin_dark"])
            draw.polygon([(left+2,face_top),(right-2,face_top),(right-2,bottom-2),(cx,bottom-1),(left+2,bottom-2)],fill=CLOTH["skin"])
            eye_y = face_top+1
            draw.point((cx-2+shift,eye_y),fill=CLOTH["eye"])
            draw.point((cx+2+shift,eye_y),fill=CLOTH["eye"])
            draw.point((cx+shift,eye_y+2),fill=CLOTH["skin_light"])
            draw.line([(cx-1+shift,bottom-2),(cx+shift,bottom-1),(cx+1+shift,bottom-2)],fill=CLOTH["skin_dark"])
        # Discrete fringe interrupts the hairline instead of a smooth vector edge.
        draw.point((cx-1,face_top),fill=CLOTH["hair"])
        draw.point((cx+1,face_top),fill=CLOTH["hair"])
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


def foundation_board(cells, data, scale=1, background="dark"):
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf",14 if scale==1 else 24)
    board = Image.new("RGB",(128+768*scale,80+288*scale),"#201e1d" if background=="dark" else "#ddd1b7")
    draw = ImageDraw.Draw(board)
    text = "#ead7aa" if background=="dark" else "#382b20"
    draw.text((12,10),"WARM ADVENTURER / SHARED THREE-SIZE FOUNDATION / 92%",font=font,fill=text)
    for i,label in enumerate(SHORT):
        draw.text((128+i*96*scale+8,45),label,font=font,fill=text)
    for row,body in enumerate(BODIES):
        draw.text((12,80+row*96*scale+30),body.upper(),font=font,fill=text)
        draw.text((12,80+row*96*scale+55),str(DISPLAY_HEIGHTS[body])+" px",font=font,fill=text)
        for aim in range(8):
            cell=cells[(body,aim)].resize((96*scale,96*scale),Image.Resampling.NEAREST)
            board.paste(cell,(128+aim*96*scale,80+row*96*scale),cell)
    return board


def gif_examples(cells):
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 20)
    cases = [(2, 2, "FORWARD / MOVE E AIM E"), (0, 2, "STRAFE / MOVE S AIM E"), (6, 2, "BACKPEDAL / MOVE W AIM E")]
    frames = []
    for phase in range(8):
        frame = Image.new("RGB", (1152, 3*408+48), PALETTE["dark"])
        draw = ImageDraw.Draw(frame)
        draw.text((16, 8), "ADVENTURER CYCLE / SMALL 53 / MIDDLE 63 / LARGE 70", font=font, fill="#e9e1f2")
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
    grounded_cells = {}
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
            assert box[3]-box[1] == DISPLAY_HEIGHTS[body], (body, box)
        if state == "grounded":
            grounded_cells[(body,pose["aim"])] = cell
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
                "style_id": STYLE_ID, "presentation_scale": DISPLAY_SCALE,
                "style_reference_sha256": hashlib.sha256((HERE / "reference-warm-fantasy.png").read_bytes()).hexdigest(),
                "directions": data["directions"], "base_rows": data["base_rows"],
                "locomotion": {"columns": 16, "rows": 32, "phases": 8,
                               "index_formula": "((travel*8+aim)*8+phase)", "gait_policy": "distinct_walk_sprint_fixed_bone_banks"}, "sizes": {}}
    for body in BODIES:
        entry = {"reference_height": data["heights"][body], "display_height": DISPLAY_HEIGHTS[body]}
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
    for scale in (1,4):
        for background in ("dark","light"):
            foundation_board(grounded_cells,data,scale,background).save(HERE/f"adventurer-overview-{scale}x-{background}.png")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    evidence = {"status": "baked_local_pending_runtime_verification", "base_cells": 240,
                "locomotion_cells": len(cells), "sprint_cells": len(sprint_cells), "move_aim_pairs_per_body_per_gait": 64, "phases_per_pair": 8,
                "fixed_bone_checks": bone_checks, "plant_and_non_crossing_checks": plant_checks,
                "all_phase_cells_distinct": True, "binary_alpha": True, "last_opaque_y": 83,
                "waist_yaw_twist_degrees": 0, "source_standing_heights": data["heights"],
                "standing_heights": DISPLAY_HEIGHTS, "presentation_scale": DISPLAY_SCALE, "style_id": STYLE_ID,
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
