"""Proportion-v4 source/pixel proof and review boards; never runtime acceptance.

Run after export_rig.gd and build.py. W2 receipts remain historical and untouched.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import math
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PRIOR = HERE / "previous-export-counter-swing-v3"
spec = importlib.util.spec_from_file_location("proportion_baker", HERE / "build.py")
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)
FONT = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 13)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pose_key(pose):
    return pose["body"], pose["state"], pose["travel"], pose["aim"], pose["phase"]


def atlas_cell(pose, pages):
    state, aim = pose["state"], pose["aim"]
    if state.endswith("locomotion"):
        bank = "sprint" if state == "sprint_locomotion" else "locomotion"
        index = ((pose["travel"] * 8 + aim) * 8 + pose["phase"])
        x, y = index % 16 * 96, index // 16 * 96
    else:
        bank = "base"
        x, y = aim * 96, baker_rows.index(state) * 96
    return pages[pose["body"], bank].crop((x, y, x+96, y+96))


def write_boards(poses, pages, prior_pages):
    for body in baker.BODIES:
        for theme, color, ink in (("light", "#ddd1b7", "#382b20"), ("dark", "#201e1d", "#ead7aa")):
            board = Image.new("RGB", (884, 432), color)
            draw = ImageDraw.Draw(board)
            draw.text((8, 8), f"PROPORTION V4 {body.upper()} / {baker.DISPLAY_HEIGHTS[body]} PX / SAME GAIT AND BONE LENGTHS", font=FONT, fill=ink)
            for aim, label in enumerate(baker.SHORT):
                draw.text((116+96*aim, 30), label, font=FONT, fill=ink)
            for row, (state, label) in enumerate((("grounded", "STAND"), ("locomotion", "WALK A:E"), ("sprint_locomotion", "RUN A:E"), ("cast", "CAST"))):
                draw.text((8, 78+96*row), label, font=FONT, fill=ink)
                moving = state.endswith("locomotion")
                for aim in range(8):
                    cell = atlas_cell(poses[body, state, 2 if moving else -1, aim, 1 if moving else -1], pages)
                    board.paste(cell, (116+96*aim, 48+96*row), cell)
            board.save(HERE / f"proportion-v4-{body}-native-{theme}.png")
            board.resize((board.width*4, board.height*4), Image.Resampling.NEAREST).save(HERE / f"proportion-v4-{body}-4x-{theme}.png")
    comparison = Image.new("RGB", (116+6*96, 50+3*96), "#ddd1b7")
    draw = ImageDraw.Draw(comparison)
    draw.text((8, 8), "OLD V3 / NEW V4: FRONT, THREE-QUARTER, PROFILE; SAME FEET", font=FONT, fill="#382b20")
    for row, body in enumerate(baker.BODIES):
        draw.text((8, 85+row*96), body.upper(), font=FONT, fill="#382b20")
        for direction, aim in enumerate((0, 1, 2)):
            for revision, source in enumerate((prior_pages, pages)):
                cell = source[body, "base"].crop((aim*96, 0, (aim+1)*96, 96))
                x, y = 116+(direction*2+revision)*96, 50+row*96
                comparison.paste(cell, (x, y), cell)
                if row == 0:
                    draw.text((x+10, 32), f"{baker.SHORT[aim]} {'OLD' if revision == 0 else 'V4'}", font=FONT, fill="#382b20")
    comparison.save(HERE / "proportion-v4-before-after-native.png")
    comparison.resize((comparison.width*4, comparison.height*4), Image.Resampling.NEAREST).save(HERE / "proportion-v4-before-after-4x.png")


def main():
    global baker_rows
    data = json.loads((HERE / "rig-data.json").read_text(encoding="utf-8"))
    old = json.loads((PRIOR / "rig-data.json").read_text(encoding="utf-8"))
    manifest = json.loads((baker.OUT / "manifest.json").read_text(encoding="utf-8"))
    old_manifest = json.loads((PRIOR / "manifest.json").read_text(encoding="utf-8"))
    assert data["motion_revision"] == manifest["motion_revision"] == "proportion_v4"
    baker_rows = data["base_rows"]
    poses = {pose_key(pose): pose for pose in data["poses"]}
    prior_poses = {pose_key(pose): pose for pose in old["poses"]}
    assert poses.keys() == prior_poses.keys() and len(poses) == 3312
    for field in ("bone_lengths", "heights", "directions", "base_rows", "cell", "pivot", "phases"):
        assert data[field] == old[field], field
    assert data["head_radius"] > old["head_radius"]
    assert math.isclose(data["head_offset"], .145) and math.isclose(data["neck_offset"], .04)
    unchanged_joints = ("pelvis", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r",
                        "hip_l", "hip_r", "knee_l", "knee_r", "ankle_l", "ankle_r", "toe_l", "toe_r")
    fixed_checks = head_checks = 0
    for key, pose in poses.items():
        land = pose["landmarks"]
        for joint in unchanged_joints:
            assert land[joint] == prior_poses[key]["landmarks"][joint], (key, joint)
            fixed_checks += 1
        shoulders = [(a+b)*.5 for a, b in zip(land["shoulder_l"], land["shoulder_r"])]
        for joint, expected in (("head", data["head_offset"]), ("neck", data["neck_offset"]), ("pelvis", data["bone_lengths"]["torso"])):
            assert abs(math.dist(shoulders, land[joint])-expected) < .000001, (key, joint)
            head_checks += 1
        if key[1].endswith("locomotion"):
            assert pose["waist_yaw_twist_degrees"] == 0
    for field in ("schema_version", "cell", "pivot", "directions", "base_rows", "locomotion"):
        assert manifest[field] == old_manifest[field], field
    assert manifest["presentation_scale_policy"] == baker.SCALE_POLICY and "presentation_scale" not in manifest
    pages, prior_pages, measurements = {}, {}, {}
    decoded_bytes = 0
    for body in baker.BODIES:
        definition = manifest["sizes"][body]
        assert definition["reference_height"] == old_manifest["sizes"][body]["reference_height"]
        assert definition["display_height"] == baker.DISPLAY_HEIGHTS[body]
        assert definition["presentation_scale"] == baker.DISPLAY_SCALES[body]
        for bank in ("base", "locomotion", "sprint"):
            path = baker.OUT / f"{body}-{bank}.png"
            page = Image.open(path).convert("RGBA")
            assert sha(path) == definition[bank+"_sha256"]
            assert hashlib.sha256(page.tobytes()).hexdigest() == definition[bank+"_rgba_sha256"]
            assert definition[bank+"_dimensions"] == old_manifest["sizes"][body][bank+"_dimensions"] == list(page.size)
            pages[body, bank] = page
            prior_pages[body, bank] = Image.open(PRIOR / f"{body}-{bank}.png").convert("RGBA")
            decoded_bytes += page.width*page.height*4
        pose = poses[body, "grounded", -1, 0, -1]
        bounds = atlas_cell(pose, pages).getbbox()
        head = baker.head_bounds(pose, data)
        head_height = head[3]-head[1]+1
        actual_height = bounds[3]-bounds[1]
        assert actual_height == baker.DISPLAY_HEIGHTS[body] and bounds[3] == 84
        assert 4.0 <= actual_height / head_height <= 4.5, (body, actual_height, head_height)
        measurements[body] = {"visible_height": actual_height, "head_height_pixels": head_height,
                              "visible_heads_tall": actual_height/head_height, "baked_scale": baker.DISPLAY_SCALES[body],
                              "grounded_bounds_eight_facings": [list(atlas_cell(poses[body, "grounded", -1, aim, -1], pages).getbbox()) for aim in range(8)]}
    assert len(pages) == 9 and decoded_bytes == 122093568
    facial_feature_checks = 0
    eye_color = ImageColor.getcolor(baker.CLOTH["eye"], "RGBA")
    for pose in poses.values():
        cell = atlas_cell(pose, pages)
        assert cell.tobytes() == baker.render(pose, data).tobytes(), pose_key(pose)
        bounds = cell.getbbox()
        assert bounds and 0 < bounds[0] < bounds[2] < 96 and 0 < bounds[1] < bounds[3] == 84
        assert set(baker.flattened_pixels(cell.getchannel("A"))) <= {0, 255}
        face = baker.head_feature_layout(pose, data)
        left, top, right, bottom = baker.head_bounds(pose, data)
        head = cell.crop((left, top, right+1, bottom+1))
        if pose["aim"] in (3, 4, 5):
            assert face["eyes"] == [] and face["nose"] is None
            assert eye_color not in set(baker.flattened_pixels(head)), pose_key(pose)
        else:
            assert .39 <= (face["eye_y"]-top)/(bottom-top) <= .47
            assert face["face_top"] < face["eye_y"] < face["nose_y"] < face["mouth_y"] < bottom
            assert len(face["eyes"]) == (1 if pose["aim"] in (2, 6) else 2)
            for eye in face["eyes"]:
                assert cell.getpixel(eye) == eye_color, (pose_key(pose), "missing eye", eye)
        facial_feature_checks += 1
    write_boards(poses, pages, prior_pages)
    receipt = {"status": "offline_proportion_v4_passed_pending_runtime_and_human_review",
               "manifest_sha256": sha(baker.OUT / "manifest.json"), "rig_data_sha256": sha(HERE / "rig-data.json"),
               "rasterizer_sha256": sha(HERE / "build.py"), "exporter_sha256": sha(HERE / "export_rig.gd"),
               "source_rig_sha256": data["rig_sha256"], "prior_manifest_sha256": sha(PRIOR / "manifest.json"),
               "pose_count": len(poses), "unchanged_limb_and_torso_landmark_checks": fixed_checks,
               "constant_head_neck_torso_length_checks": head_checks, "reproducible_final_pixel_cells": len(poses),
               "anatomical_feature_and_rear_face_exclusion_checks": facial_feature_checks,
               "texture_count": len(pages), "decoded_texture_bytes": decoded_bytes,
               "measurements": measurements, "head_radius": data["head_radius"], "head_offset": data["head_offset"],
               "limits": ["Source and final PNG proof only; no live runtime or human aesthetic acceptance implied.",
                          "Old W2 head and projection invariance is historical, not a requirement of this new proportion pass.",
                          "Unchanged source limb landmarks and existing gait matrix do not establish rendered performance."]}
    (HERE / "proportion-v4-verification.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    print("PASS: proportion_v4; 3312 reproducible final cells; visible heights 58/63/68; measured 4-4.5 heads; unchanged gait/limb geometry and nine-page allocation")


if __name__ == "__main__":
    main()
