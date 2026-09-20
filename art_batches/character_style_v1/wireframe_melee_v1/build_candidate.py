"""Bake the isolated W2 melee candidate; never writes a live asset directory."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
W2 = HERE.parent / "wireframe_motion_v2"
RIG_PATH = HERE / "rig-data.json"
CONTRACT_PATH = HERE / "manifest.json"
BODIES = ("small", "middle", "large")
GAITS = ("idle", "forward", "strafe_right", "backward", "strafe_left")
ATTACKS = ("punch", "kick")
PHASES = ("startup", "active", "recovery")
DIRECTIONS = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
DISPLAY_HEIGHTS = {"small": 58, "middle": 63, "large": 68}
CELL = 96
PAGE_SIZE = (8 * CELL, len(GAITS) * len(ATTACKS) * len(PHASES) * CELL)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba_sha(image: Image.Image) -> str:
    return hashlib.sha256(image.tobytes()).hexdigest()


def load_w2_baker():
    spec = importlib.util.spec_from_file_location("wireframe_motion_v2_baker", W2 / "build.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load the W2 rasterizer")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def frame_key(pose: dict) -> tuple[str, int, int, int, int]:
    return pose["body"], int(pose["gait_index"]), int(pose["attack_index"]), int(pose["physical_phase_index"]), int(pose["aim"])


def page_row(gait_index: int, attack_index: int, phase_index: int) -> int:
    return ((gait_index * len(ATTACKS) + attack_index) * len(PHASES) + phase_index)


def normalize_mesh_face_indices(pose: dict) -> int:
    """Godot JSON emits numeric Variants as floats; W2 expects list indices."""
    mesh_size = len(pose["mesh_points"])
    normalized = 0
    for face in pose["mesh_faces"]:
        indices = []
        for raw_index in face["indices"]:
            assert isinstance(raw_index, (int, float)) and not isinstance(raw_index, bool), (pose["body"], pose["aim"], raw_index, "non-numeric mesh index")
            numeric = float(raw_index)
            assert math.isfinite(numeric), (pose["body"], pose["aim"], raw_index, "non-finite mesh index")
            index = int(numeric)
            assert numeric == index, (pose["body"], pose["aim"], raw_index, "non-integral mesh index")
            assert 0 <= index < mesh_size, (pose["body"], pose["aim"], index, mesh_size, "mesh index outside candidate pose")
            indices.append(index)
            normalized += 1
        assert len(indices) >= 3
        face["indices"] = indices
    return normalized


def font(size: int):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/consola.ttf", size)
    except OSError:
        return ImageFont.load_default()


def review_board(cells: dict, body: str, theme: str) -> Image.Image:
    background, ink = ("#201e1d", "#ead7aa") if theme == "dark" else ("#ddd1b7", "#382b20")
    width, height = 122 + 8 * CELL, 56 + 6 * CELL
    board = Image.new("RGB", (width, height), background)
    draw = ImageDraw.Draw(board)
    draw.text((10, 8), f"MELEE CANDIDATE / {body.upper()} {DISPLAY_HEIGHTS[body]} PX / FORWARD STANCE", font=font(13), fill=ink)
    for aim, label in enumerate(DIRECTIONS):
        draw.text((122 + aim * CELL + 6, 34), label, font=font(12), fill=ink)
    for attack_index, attack in enumerate(ATTACKS):
        for phase_index, phase in enumerate(PHASES):
            row = attack_index * 3 + phase_index
            draw.text((8, 56 + row * CELL + 36), f"{attack[:1].upper()} {phase[:3].upper()}", font=font(12), fill=ink)
            for aim in range(8):
                cell = cells[(body, 1, attack_index, phase_index, aim)]
                board.paste(cell, (122 + aim * CELL, 56 + row * CELL), cell)
    return board


def gait_board(cells: dict, theme: str) -> Image.Image:
    background, ink = ("#201e1d", "#ead7aa") if theme == "dark" else ("#ddd1b7", "#382b20")
    width, height = 122 + 8 * CELL, 56 + 10 * CELL
    board = Image.new("RGB", (width, height), background)
    draw = ImageDraw.Draw(board)
    draw.text((10, 8), "MELEE CANDIDATE / MIDDLE 63 PX / FIVE RELATIVE GAITS / ACTIVE", font=font(13), fill=ink)
    for aim, label in enumerate(DIRECTIONS):
        draw.text((122 + aim * CELL + 6, 34), label, font=font(12), fill=ink)
    for gait_index, gait in enumerate(GAITS):
        for attack_index, attack in enumerate(ATTACKS):
            row = gait_index * 2 + attack_index
            draw.text((8, 56 + row * CELL + 36), f"{gait[:6]} {attack[:1]}", font=font(11), fill=ink)
            for aim in range(8):
                cell = cells[("middle", gait_index, attack_index, 1, aim)]
                board.paste(cell, (122 + aim * CELL, 56 + row * CELL), cell)
    return board


def main() -> int:
    if not RIG_PATH.is_file():
        raise SystemExit("rig-data.json is missing; run export_rig.gd through the serialized engine wrapper first")
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    data = json.loads(RIG_PATH.read_text(encoding="utf-8"))
    baker = load_w2_baker()
    w2_manifest = baker.OUT / "manifest.json"
    assert data["candidate_only"] is True
    assert data["frame_count"] == 720 and len(data["poses"]) == 720
    assert data["rig_source_sha256"] == sha(W2 / "rig-data.json")
    assert data["runtime_manifest_sha256"] == sha(w2_manifest)
    assert data["display_heights"] == DISPLAY_HEIGHTS
    assert contract["status"] == "prepared_not_exported_or_baked"
    assert contract["matrix"]["frame_count"] == 720

    allowed_rgb = {ImageColor.getrgb(value) for value in baker.CLOTH.values()}
    pages = {body: Image.new("RGBA", PAGE_SIZE) for body in BODIES}
    cells: dict[tuple[str, int, int, int, int], Image.Image] = {}
    frames = []
    fixed_bone_checks = 0
    in_cell_landmark_checks = 0
    normalized_mesh_indices = 0
    fixed_body_scale_checks = 0
    palette_pixel_checks = 0
    for pose in data["poses"]:
        key = frame_key(pose)
        assert key not in cells, key
        body, gait_index, attack_index, phase_index, aim = key
        assert body in BODIES
        assert pose["gait"] == GAITS[gait_index]
        assert pose["attack"] == ATTACKS[attack_index]
        assert pose["physical_phase_name"] == PHASES[phase_index]
        assert int(pose["physical_kind"]) == attack_index + 1
        assert int(pose["physical_phase"]) == phase_index + 1
        expected_pixels_per_unit = float(data["reference_heights"][body]) / float(data["standing_span"])
        assert abs(float(pose["pixels_per_unit"]) - expected_pixels_per_unit) < 0.00001, (key, "per-frame anatomical scale drift")
        assert baker.DISPLAY_HEIGHTS[body] == DISPLAY_HEIGHTS[body]
        fixed_body_scale_checks += 1
        for side in ("l", "r"):
            for start, end, length in (
                ("hip", "knee", "thigh"), ("knee", "ankle", "shin"), ("ankle", "toe", "foot"),
                ("shoulder", "elbow", "humerus"), ("elbow", "hand", "forearm"),
            ):
                actual = sum((a - b) ** 2 for a, b in zip(pose["landmarks"][f"{start}_{side}"], pose["landmarks"][f"{end}_{side}"])) ** 0.5
                assert abs(actual - float(data["bone_lengths"][length])) < 0.00001, (key, side, length, actual)
                fixed_bone_checks += 1
        for point in pose["points"].values():
            display_x, display_y = baker.display_point(point, body)
            assert 3.0 <= display_x <= 92.0, (key, (display_x, display_y), "landmark approaches horizontal clip")
            assert 2.0 <= display_y < 84.0, (key, (display_x, display_y), "landmark reaches or crosses fixed y84 pivot")
            in_cell_landmark_checks += 1
        normalized_mesh_indices += normalize_mesh_face_indices(pose)
        cell = baker.render(pose, data)
        assert cell.mode == "RGBA" and cell.size == (CELL, CELL)
        bounds = cell.getbbox()
        assert bounds is not None and bounds[3] <= 84, (key, bounds, "render crosses shared feet pivot")
        assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < CELL, (key, bounds, "render touches a clipping border")
        for red, green, blue, alpha in cell.getdata():
            assert alpha in (0, 255), (key, "non-binary alpha")
            if alpha:
                assert (red, green, blue) in allowed_rgb, (key, (red, green, blue), "non-W2 or magic pixel")
                palette_pixel_checks += 1
        row = page_row(gait_index, attack_index, phase_index)
        pages[body].paste(cell, (aim * CELL, row * CELL), cell)
        cells[key] = cell
        frames.append({
            "body": body, "gait": pose["gait"], "gait_index": gait_index,
            "attack": pose["attack"], "physical_kind": int(pose["physical_kind"]),
            "phase": pose["physical_phase_name"], "physical_phase": int(pose["physical_phase"]),
            "aim": aim, "direction": pose["direction"],
            "region": [aim * CELL, row * CELL, CELL, CELL], "pivot": [48, 84],
            "standing_display_target": DISPLAY_HEIGHTS[body], "visible_bounds": list(bounds),
            "visible_height": bounds[3] - bounds[1], "rgba_sha256": rgba_sha(cell),
        })

    assert len(cells) == 720
    for body in BODIES:
        for gait_index in range(len(GAITS)):
            for aim in range(8):
                for attack_index in range(len(ATTACKS)):
                    phase_images = {cells[(body, gait_index, attack_index, phase, aim)].tobytes() for phase in range(3)}
                    assert len(phase_images) == 3, (body, gait_index, aim, ATTACKS[attack_index], "phase silhouettes collapsed")
                punch = cells[(body, gait_index, 0, 1, aim)].tobytes()
                kick = cells[(body, gait_index, 1, 1, aim)].tobytes()
                assert punch != kick, (body, gait_index, aim, "active attacks collapsed")

    page_records = {}
    for body, page in pages.items():
        path = HERE / f"{body}-melee.png"
        page.save(path)
        page_records[body] = {
            "file": path.name,
            "dimensions": list(page.size),
            "sha256": sha(path),
            "rgba_sha256": rgba_sha(page),
            "reference_height": int(data["reference_heights"][body]),
            "display_height": DISPLAY_HEIGHTS[body],
            "presentation_scale": float(baker.DISPLAY_SCALES[body]),
        }
        for theme in ("dark", "light"):
            board = review_board(cells, body, theme)
            board.save(HERE / f"review-{body}-{theme}-native.png")
            board.resize((board.width * 2, board.height * 2), Image.Resampling.NEAREST).save(HERE / f"review-{body}-{theme}-2x.png")
    for theme in ("dark", "light"):
        board = gait_board(cells, theme)
        board.save(HERE / f"review-gaits-{theme}-native.png")
        board.resize((board.width * 2, board.height * 2), Image.Resampling.NEAREST).save(HERE / f"review-gaits-{theme}-2x.png")

    baked_manifest = dict(contract)
    baked_manifest.update({
        "status": "offline_bake_complete_pending_native_import_capture_and_human_review",
        "rig_data_sha256": sha(RIG_PATH),
        "w2_rig_sha256": data["rig_source_sha256"],
        "w2_runtime_manifest_sha256": data["runtime_manifest_sha256"],
        "pages": page_records,
        "frames": frames,
        "validation": {
            "fixed_bone_checks": fixed_bone_checks,
            "in_cell_landmark_checks": in_cell_landmark_checks,
            "normalized_integral_mesh_indices": normalized_mesh_indices,
            "fixed_per_body_scale_checks": fixed_body_scale_checks,
            "nontransparent_palette_pixel_checks": palette_pixel_checks,
            "binary_alpha_frames": 720,
            "within_fixed_pivot_frames": 720,
            "standing_display_targets": DISPLAY_HEIGHTS,
            "distinct_three_phase_cases": 240,
            "distinct_active_attack_cases": 120,
            "engine_import": "not_run",
            "native_capture": "not_run",
            "human_review": "pending",
        },
    })
    (HERE / "candidate-manifest.json").write_text(json.dumps(baked_manifest, indent=2) + "\n", encoding="utf-8")
    evidence = {
        "status": "offline_bake_complete_pending_native_review",
        "candidate_manifest_sha256": sha(HERE / "candidate-manifest.json"),
        "rig_data_sha256": sha(RIG_PATH),
        "pages": page_records,
        "fixed_bone_checks": fixed_bone_checks,
        "in_cell_landmark_checks": in_cell_landmark_checks,
        "normalized_integral_mesh_indices": normalized_mesh_indices,
        "fixed_per_body_scale_checks": fixed_body_scale_checks,
        "palette_pixel_checks": palette_pixel_checks,
        "live_assets_modified": False,
        "engine_export": "root-owned serialized result required",
        "engine_import": "not_run",
        "native_capture": "not_run",
        "human_review": "pending",
    }
    (HERE / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: baked 720 melee frames to three {PAGE_SIZE[0]}x{PAGE_SIZE[1]} isolated pages; {fixed_bone_checks} fixed-bone checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
