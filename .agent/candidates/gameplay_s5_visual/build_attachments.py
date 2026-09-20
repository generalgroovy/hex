"""Derive the compact runtime melee attachment table from accepted bake data."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
DEFAULT_BATCH = REPO / "art_batches/character_style_v1/wireframe_melee_v1"
MANIFEST_NAME = "candidate-manifest.json"
RIG_NAME = "rig-data.json"
OUTPUT_NAME = "attachments.json"
RUNTIME_PATH = "res://assets/sprites/wireframe_melee_v1/attachments.json"
CELL = (96, 96)
PIVOT = (48.0, 84.0)
BODIES = ("small", "middle", "large")
GAITS = ("idle", "forward", "strafe_right", "backward", "strafe_left")
ATTACKS = ("punch", "kick")
PHASES = ("startup", "active", "recovery")
DIRECTIONS = ("south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west")
DISPLAY_HEIGHTS = {"small": 58, "middle": 63, "large": 68}
PRESENTATION_SCALES = {"small": 1.0, "middle": 63 / 68, "large": 68 / 76}
FRAME_COUNT = 720
RECORD_FIELDS = (
    "body_index", "gait_index", "physical_kind", "physical_phase", "aim_index",
    "point_x", "point_y", "pixel_x", "pixel_y",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    value = json.loads(raw.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value, raw


def frame_key(value: dict) -> tuple[str, int, int, int, int]:
    return (
        str(value.get("body", "")),
        int(value.get("gait_index", -1)),
        int(value.get("physical_kind", -1)),
        int(value.get("physical_phase", -1)),
        int(value.get("aim", -1)),
    )


def expected_keys() -> set[tuple[str, int, int, int, int]]:
    return {
        (body, gait, kind, phase, aim)
        for body in BODIES
        for gait in range(len(GAITS))
        for kind in (1, 2)
        for phase in (1, 2, 3)
        for aim in range(len(DIRECTIONS))
    }


def validate_manifest(manifest: dict) -> dict[tuple[str, int, int, int, int], dict]:
    matrix = manifest.get("matrix")
    if (
        manifest.get("schema_version") != 1
        or manifest.get("cell") != list(CELL)
        or manifest.get("pivot") != [48, 84]
        or manifest.get("page_dimensions") != [768, 2880]
        or not isinstance(matrix, dict)
        or matrix.get("bodies") != list(BODIES)
        or matrix.get("display_heights") != DISPLAY_HEIGHTS
        or matrix.get("directions") != list(DIRECTIONS)
        or matrix.get("gaits") != list(GAITS)
        or matrix.get("attacks") != list(ATTACKS)
        or matrix.get("phases") != list(PHASES)
        or matrix.get("frame_count") != FRAME_COUNT
    ):
        raise ValueError("candidate manifest melee matrix contract changed")
    frames = manifest.get("frames")
    if not isinstance(frames, list) or len(frames) != FRAME_COUNT:
        raise ValueError("candidate manifest must contain exactly 720 frames")
    indexed: dict[tuple[str, int, int, int, int], dict] = {}
    for frame in frames:
        if not isinstance(frame, dict):
            raise ValueError("candidate manifest frame must be an object")
        key = frame_key(frame)
        body, gait, kind, phase, aim = key
        if key in indexed or key not in expected_keys():
            raise ValueError(f"candidate manifest frame key is invalid or duplicated: {key}")
        row = ((gait * len(ATTACKS) + (kind - 1)) * len(PHASES) + (phase - 1))
        if frame.get("region") != [aim * CELL[0], row * CELL[1], CELL[0], CELL[1]]:
            raise ValueError(f"candidate manifest frame region changed: {key}")
        if (
            frame.get("gait") != GAITS[gait]
            or frame.get("attack") != ATTACKS[kind - 1]
            or frame.get("phase") != PHASES[phase - 1]
            or frame.get("direction") != DIRECTIONS[aim]
            or int(frame.get("standing_display_target", -1)) != DISPLAY_HEIGHTS[body]
        ):
            raise ValueError(f"candidate manifest frame labels changed: {key}")
        indexed[key] = frame
    if set(indexed) != expected_keys():
        raise ValueError("candidate manifest frame matrix is incomplete")
    return indexed


def manifest_core_sha256(manifest: dict) -> str:
    core = copy.deepcopy(manifest)
    core.pop("attachment_table", None)
    encoded = (json.dumps(core, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    return sha256_bytes(encoded)


def derive_table(manifest: dict, rig: dict, rig_sha256: str) -> dict:
    manifest_frames = validate_manifest(manifest)
    if manifest.get("rig_data_sha256") != rig_sha256:
        raise ValueError("candidate manifest rig_data_sha256 does not match raw rig-data.json")
    poses = rig.get("poses")
    if (
        rig.get("schema_version") != 1
        or rig.get("cell") != list(CELL)
        or rig.get("pivot") != [48, 84]
        or rig.get("frame_count") != FRAME_COUNT
        or rig.get("display_heights") != DISPLAY_HEIGHTS
        or not isinstance(poses, list)
        or len(poses) != FRAME_COUNT
    ):
        raise ValueError("rig-data attachment source contract changed")
    indexed_poses: dict[tuple[str, int, int, int, int], dict] = {}
    for pose in poses:
        if not isinstance(pose, dict):
            raise ValueError("rig pose must be an object")
        key = frame_key(pose)
        if key not in manifest_frames or key in indexed_poses:
            raise ValueError(f"rig pose key does not match one rendered frame: {key}")
        indexed_poses[key] = pose
    if set(indexed_poses) != set(manifest_frames):
        raise ValueError("rig pose matrix does not match the rendered frame matrix")

    records: list[list[int | float]] = []
    for key in sorted(indexed_poses, key=lambda item: (BODIES.index(item[0]), *item[1:])):
        body, gait, kind, phase, aim = key
        points = indexed_poses[key].get("points")
        point_name = "hand_r" if kind == 1 else "toe_r"
        point = points.get(point_name) if isinstance(points, dict) else None
        if (
            not isinstance(point, list)
            or len(point) != 2
            or isinstance(point[0], bool)
            or isinstance(point[1], bool)
            or not isinstance(point[0], (int, float))
            or not isinstance(point[1], (int, float))
        ):
            raise ValueError(f"rig striking point is malformed: {key}/{point_name}")
        scale = PRESENTATION_SCALES[body]
        x = PIVOT[0] + (float(point[0]) - PIVOT[0]) * scale
        y = PIVOT[1] + (float(point[1]) - PIVOT[1]) * scale
        if not math.isfinite(x) or not math.isfinite(y) or not (0.0 <= x < CELL[0] and 0.0 <= y < CELL[1]):
            raise ValueError(f"baked striking point leaves the fixed cell: {key}/{(x, y)}")
        pixel_x, pixel_y = int(round(x)), int(round(y))
        if not (0 <= pixel_x < CELL[0] and 0 <= pixel_y < CELL[1]):
            raise ValueError(f"rounded striking pixel leaves the fixed cell: {key}/{(pixel_x, pixel_y)}")
        records.append([BODIES.index(body), gait, kind, phase, aim, x, y, pixel_x, pixel_y])
    if len(records) != FRAME_COUNT:
        raise ValueError("compact attachment table must contain exactly 720 records")
    return {
        "schema_version": 1,
        "authority": "presentation-only points derived from validated melee rig; no simulation or collision values",
        "coordinate_space": "baked_cell_pixels_subpixel",
        "cell": list(CELL),
        "pivot": [48, 84],
        "frame_count": FRAME_COUNT,
        "bodies": list(BODIES),
        "gaits": list(GAITS),
        "attacks": list(ATTACKS),
        "phases": list(PHASES),
        "directions": list(DIRECTIONS),
        "display_heights": DISPLAY_HEIGHTS,
        "presentation_scales": PRESENTATION_SCALES,
        "record_fields": list(RECORD_FIELDS),
        "attachment_by_physical_kind": {"1": "hand_r", "2": "toe_r"},
        "source_rig_sha256": rig_sha256,
        "source_manifest_core_sha256": manifest_core_sha256(manifest),
        "records": records,
    }


def atomic_write(path: Path, data: bytes) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(data)
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch-root", type=Path, default=DEFAULT_BATCH)
    parser.add_argument("--check", action="store_true", help="validate and report without writing files")
    args = parser.parse_args()
    batch = args.batch_root.resolve()
    manifest_path = batch / MANIFEST_NAME
    rig_path = batch / RIG_NAME
    output_path = batch / OUTPUT_NAME
    manifest, _ = read_json(manifest_path)
    rig, rig_raw = read_json(rig_path)
    rig_sha256 = sha256_bytes(rig_raw)
    table = derive_table(manifest, rig, rig_sha256)
    table_bytes = (json.dumps(table, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    table_sha256 = sha256_bytes(table_bytes)
    attachment_record = {
        "schema_version": 1,
        "file": OUTPUT_NAME,
        "path": RUNTIME_PATH,
        "sha256": table_sha256,
        "source_rig_sha256": rig_sha256,
        "source_manifest_core_sha256": table["source_manifest_core_sha256"],
        "coordinate_space": table["coordinate_space"],
        "frame_count": FRAME_COUNT,
    }
    if args.check:
        print(f"STATIC PASS: {FRAME_COUNT} compact attachments; {len(table_bytes)} bytes; table sha256 {table_sha256}; raw rig sha256 {rig_sha256}")
        return
    updated_manifest = copy.deepcopy(manifest)
    updated_manifest["attachment_table"] = attachment_record
    manifest_bytes = (json.dumps(updated_manifest, indent=2) + "\n").encode("utf-8")
    atomic_write(output_path, table_bytes)
    atomic_write(manifest_path, manifest_bytes)
    print(f"PASS: wrote {output_path} with {FRAME_COUNT} attachments and updated {manifest_path.name}; table sha256 {table_sha256}; raw rig sha256 {rig_sha256}")


if __name__ == "__main__":
    main()
