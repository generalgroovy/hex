"""Verify the bounded shared slide-pose refinement after export and bake.

This is offline source/pixel evidence. It does not run Godot or establish
human animation acceptance, rendered performance, or gameplay authority.
"""
from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import math
import zipfile
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
MOTION = HERE.parent
REPO = HERE.parents[3]
CURRENT_RIG = MOTION / "rig-data.json"
CURRENT_ASSETS = REPO / "assets" / "sprites" / "wireframe_motion_v2"
BASELINE_RIG = REPO / "docs" / "evidence" / "template-motion-20260915" / "rig-before.json"
BASELINE_ZIP = REPO / "docs" / "evidence" / "template-motion-20260915" / "presentation-before.zip"
REVIEW_BOARD = HERE / "slide-v1-review.png"
RECEIPT = HERE / "verification.json"
CELL = 96
SLIDE_FORWARD_LEAN_DEGREES = math.degrees(-1.10)
SLIDE_SIDE_LEAN_DEGREES = math.degrees(0.50)
MINIMUM_SOUTH_TILT_DEGREES = 30.0
MAXIMUM_SOUTH_TILT_DEGREES = 36.0
BODIES = ("small", "middle", "large")
BANKS = ("base", "locomotion", "sprint")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def pose_key(pose: dict) -> tuple:
    return pose["body"], pose["state"], pose["travel"], pose["aim"], pose["phase"]


def vector(a: list[float], b: list[float]) -> list[float]:
    return [float(y) - float(x) for x, y in zip(a, b)]


def length(value: list[float]) -> float:
    return math.sqrt(sum(component * component for component in value))


def dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def close(actual: float, expected: float, tolerance: float = 0.000001) -> None:
    assert math.isclose(actual, expected, rel_tol=0.0, abs_tol=tolerance), (actual, expected)


def image_from_bytes(value: bytes) -> Image.Image:
    with Image.open(io.BytesIO(value)) as source:
        return source.convert("RGBA")


def cell(page: Image.Image, row: int, column: int) -> Image.Image:
    return page.crop((column * CELL, row * CELL, (column + 1) * CELL, (row + 1) * CELL))


def flattened_pixels(channel: Image.Image) -> set[int]:
    return {int(value) for value in channel.getdata()}


def torso_tilt_from_vertical(pose: dict) -> float:
    pelvis = pose["points"]["pelvis"]
    head = pose["points"]["head"]
    dx = abs(float(head[0]) - float(pelvis[0]))
    dy = abs(float(head[1]) - float(pelvis[1]))
    return math.degrees(math.atan2(dx, dy))


def load_baker():
    spec = importlib.util.spec_from_file_location("slide_v1_baker", MOTION / "build.py")
    assert spec is not None and spec.loader is not None
    baker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(baker)
    return baker


def write_review_board(before_pages: dict, after_pages: dict, slide_row: int) -> None:
    margin = 116
    board = Image.new("RGB", (margin + 8 * CELL, 34 + 6 * CELL), "#201e1d")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 13)
    draw.text((8, 8), "SLIDE V1 / PRESERVED BASELINE THEN CANDIDATE / NATIVE PIXELS", font=font, fill="#ead7aa")
    for aim, label in enumerate(("S", "SE", "E", "NE", "N", "NW", "W", "SW")):
        draw.text((margin + aim * CELL + 40, 20), label, font=font, fill="#ead7aa")
    for body_index, body in enumerate(BODIES):
        for revision_index, (revision, pages) in enumerate((("BEFORE", before_pages), ("AFTER", after_pages))):
            row = body_index * 2 + revision_index
            y = 34 + row * CELL
            draw.text((8, y + 50), f"{body.upper()} {revision}", font=font, fill="#ead7aa")
            for aim in range(8):
                sample = cell(pages[body, "base"], slide_row, aim)
                board.paste(sample, (margin + aim * CELL, y), sample)
    board.save(REVIEW_BOARD)


def main() -> None:
    current = load_json(CURRENT_RIG)
    baseline = load_json(BASELINE_RIG)
    current_poses = {pose_key(pose): pose for pose in current["poses"]}
    baseline_poses = {pose_key(pose): pose for pose in baseline["poses"]}
    assert current_poses.keys() == baseline_poses.keys() and len(current_poses) == 3312

    stable_fields = (
        "schema_version", "heights", "directions", "base_rows", "head_radius",
        "head_offset", "neck_offset", "standing_span", "cell", "pivot", "phases",
        "bone_lengths",
    )
    for field in stable_fields:
        assert current[field] == baseline[field], field
    assert current["motion_revision"] != baseline["motion_revision"]

    changed_slide_poses = 0
    unchanged_poses = 0
    bone_checks = grounded_endpoint_checks = rigid_body_checks = gaze_axis_checks = 0
    south_tilts: dict[str, float] = {}
    for key, pose in current_poses.items():
        before = baseline_poses[key]
        if pose["state"] != "slide":
            assert pose == before, key
            unchanged_poses += 1
            continue
        assert pose != before, key
        changed_slide_poses += 1
        landmarks = pose["landmarks"]
        for side in ("l", "r"):
            for start, end, contract in (
                ("hip_", "knee_", "thigh"),
                ("knee_", "ankle_", "shin"),
                ("ankle_", "toe_", "foot"),
                ("shoulder_", "elbow_", "humerus"),
                ("elbow_", "hand_", "forearm"),
            ):
                close(length(vector(landmarks[start + side], landmarks[end + side])), float(current["bone_lengths"][contract]))
                bone_checks += 1
            close(float(landmarks["ankle_" + side][2]), 0.0)
            close(float(landmarks["toe_" + side][2]), 0.0)
            grounded_endpoint_checks += 2
        shoulders = [(float(a) + float(b)) * 0.5 for a, b in zip(landmarks["shoulder_l"], landmarks["shoulder_r"])]
        close(length(vector(landmarks["shoulder_l"], landmarks["shoulder_r"])), 0.32)
        close(length(vector(landmarks["hip_l"], landmarks["hip_r"])), 0.18)
        close(length(vector(landmarks["pelvis"], shoulders)), float(current["bone_lengths"]["torso"]))
        close(length(vector(shoulders, landmarks["head"])), float(current["head_offset"]))
        close(length(vector(shoulders, landmarks["neck"])), float(current["neck_offset"]))
        rigid_body_checks += 5
        # The deeper recline changes pitch deliberately. It retains one exact
        # anatomical forward axis with no yaw, fixed length, and an orthogonal
        # relationship to both the rolled torso and shoulder axes.
        torso_axis = vector(landmarks["pelvis"], shoulders)
        shoulder_axis = vector(landmarks["shoulder_l"], landmarks["shoulder_r"])
        gaze_axis = vector(landmarks["head"], landmarks["nose"])
        close(length(gaze_axis), 0.11)
        close(float(gaze_axis[0]), 0.0)
        assert float(gaze_axis[1]) > 0.0 and float(gaze_axis[2]) > 0.0
        close(dot(torso_axis, gaze_axis), 0.0)
        close(dot(shoulder_axis, gaze_axis), 0.0)
        pitch = math.degrees(math.atan2(float(gaze_axis[2]), float(gaze_axis[1])))
        close(pitch, -SLIDE_FORWARD_LEAN_DEGREES, 0.00001)
        gaze_axis_checks += 6
        if key[3] == 0:
            tilt = torso_tilt_from_vertical(pose)
            assert MINIMUM_SOUTH_TILT_DEGREES <= tilt <= MAXIMUM_SOUTH_TILT_DEGREES, (key, tilt)
            south_tilts[key[0]] = tilt

    assert changed_slide_poses == 24
    assert unchanged_poses == 3312 - changed_slide_poses
    assert set(south_tilts) == set(BODIES)

    baker = load_baker()
    current_manifest = load_json(CURRENT_ASSETS / "manifest.json")
    with zipfile.ZipFile(BASELINE_ZIP) as archive:
        baseline_manifest = json.loads(archive.read("wireframe_motion_v2/manifest.json"))
        after_pages: dict[tuple[str, str], Image.Image] = {}
        before_pages: dict[tuple[str, str], Image.Image] = {}
        unchanged_page_pixels = rewritten_page_files = unchanged_cells = changed_slide_cells = face_checks = 0
        for field in ("schema_version", "cell", "pivot", "style_id", "presentation_scale_policy", "directions", "base_rows", "locomotion"):
            assert current_manifest[field] == baseline_manifest[field], field
        assert current_manifest["motion_revision"] == current["motion_revision"]
        assert current_manifest["motion_revision"] != baseline_manifest["motion_revision"]
        slide_row = current["base_rows"].index("slide")
        for body in BODIES:
            current_size = current_manifest["sizes"][body]
            baseline_size = baseline_manifest["sizes"][body]
            for field in ("reference_height", "display_height", "presentation_scale"):
                assert current_size[field] == baseline_size[field], (body, field)
            for bank in BANKS:
                current_path = CURRENT_ASSETS / f"{body}-{bank}.png"
                current_bytes = current_path.read_bytes()
                baseline_bytes = archive.read(f"wireframe_motion_v2/{body}-{bank}.png")
                after = image_from_bytes(current_bytes)
                before = image_from_bytes(baseline_bytes)
                assert after.size == before.size == tuple(current_size[bank + "_dimensions"])
                assert sha256_bytes(current_bytes) == current_size[bank + "_sha256"]
                assert sha256_bytes(after.tobytes()) == current_size[bank + "_rgba_sha256"]
                after_pages[body, bank] = after
                before_pages[body, bank] = before
                if bank in ("locomotion", "sprint"):
                    # Re-encoding may change PNG compression bytes. The decoded
                    # RGBA page is the presentation contract being preserved.
                    assert after.tobytes() == before.tobytes(), (body, bank)
                    unchanged_page_pixels += 1
                    if current_bytes != baseline_bytes:
                        rewritten_page_files += 1
            for row, state in enumerate(current["base_rows"]):
                for aim in range(8):
                    after_cell = cell(after_pages[body, "base"], row, aim)
                    before_cell = cell(before_pages[body, "base"], row, aim)
                    if state == "slide":
                        assert after_cell.tobytes() != before_cell.tobytes(), (body, state, aim)
                        changed_slide_cells += 1
                    else:
                        assert after_cell.tobytes() == before_cell.tobytes(), (body, state, aim)
                        unchanged_cells += 1
            standing = cell(after_pages[body, "base"], current["base_rows"].index("grounded"), 0).getbbox()
            assert standing is not None
            assert standing[3] - standing[1] == current_size["display_height"] and standing[3] == 84
            for aim in range(8):
                slide = cell(after_pages[body, "base"], slide_row, aim)
                bounds = slide.getbbox()
                assert bounds is not None and 0 < bounds[0] < bounds[2] < 96 and 0 < bounds[1] < bounds[3] == 84
                assert flattened_pixels(slide.getchannel("A")) <= {0, 255}
                pose = current_poses[body, "slide", -1, aim, -1]
                face = baker.head_feature_layout(pose, current)
                left, top, right, bottom = baker.head_bounds(pose, current)
                head = slide.crop((left, top, right + 1, bottom + 1))
                eye_color = ImageColor.getcolor(baker.CLOTH["eye"], "RGBA")
                if aim in (3, 4, 5):
                    assert face["eyes"] == [] and face["nose"] is None
                    assert eye_color not in set(head.getdata()), (body, aim, "rear false eye")
                else:
                    assert len(face["eyes"]) == (1 if aim in (2, 6) else 2)
                    for eye in face["eyes"]:
                        assert slide.getpixel(eye) == eye_color, (body, aim, "missing eye")
                face_checks += 1

    assert unchanged_page_pixels == 6
    assert unchanged_cells == 3 * 9 * 8
    assert changed_slide_cells == 24
    write_review_board(before_pages, after_pages, slide_row)
    receipt = {
        "status": "offline_slide_v1_passed_pending_godot_runtime_and_human_review",
        "motion_revision": current["motion_revision"],
        "forward_lean_degrees": SLIDE_FORWARD_LEAN_DEGREES,
        "side_lean_degrees": SLIDE_SIDE_LEAN_DEGREES,
        "pose_count": len(current_poses),
        "changed_slide_poses": changed_slide_poses,
        "unchanged_non_slide_poses": unchanged_poses,
        "fixed_bone_checks": bone_checks,
        "grounded_ankle_and_toe_endpoint_checks": grounded_endpoint_checks,
        "rigid_body_checks": rigid_body_checks,
        "gaze_axis_length_yaw_plane_orthogonality_and_pitch_checks": gaze_axis_checks,
        "south_tilt_degrees": south_tilts,
        "changed_slide_cells": changed_slide_cells,
        "unchanged_non_slide_base_cells": unchanged_cells,
        "pixel_identical_locomotion_and_sprint_pages": unchanged_page_pixels,
        "reencoded_locomotion_and_sprint_png_files": rewritten_page_files,
        "slide_face_readability_checks": face_checks,
        "current_rig_sha256": sha256_path(CURRENT_RIG),
        "baseline_rig_sha256": sha256_path(BASELINE_RIG),
        "current_manifest_sha256": sha256_path(CURRENT_ASSETS / "manifest.json"),
        "baseline_archive_sha256": sha256_path(BASELINE_ZIP),
        "review_board": REVIEW_BOARD.name,
        "limits": [
            "Offline rig and final PNG comparison only; no Godot runtime result is claimed.",
            "One shared slide silhouette still follows aim rather than independent travel.",
            "Human motion and size-balance acceptance remains open.",
        ],
    }
    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("PASS: slide_v1; 24 changed slide cells; 3288 unchanged poses; six unchanged locomotion/sprint pages")


if __name__ == "__main__":
    main()
