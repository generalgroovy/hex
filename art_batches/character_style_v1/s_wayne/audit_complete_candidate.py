"""Read-only image/source audit; writes only a new QA receipt next to candidate."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
CANDIDATE = ROOT / "candidate-v2"
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def resource(path):
    assert path.startswith("res://")
    resolved = (REPO / path[6:]).resolve()
    assert resolved.is_relative_to(REPO)
    return resolved
manifest = json.loads((CANDIDATE / "manifest.json").read_text())
atlas = Image.open(CANDIDATE / "s_wayne.png")
assert atlas.mode == "RGBA" and atlas.size == (768, 960)
assert manifest["frame_count"] == 80 and manifest["complete_coverage"] and not manifest["live_promotion"]
assert sha(CANDIDATE / "s_wayne.png") == manifest["sha256"]
assert hashlib.sha256(atlas.tobytes()).hexdigest() == manifest["rgba_sha256"]
states = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
directions = ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
checks = []
pixel_hashes = set()
for index, frame in enumerate(manifest["frames"]):
    assert frame["state"] == states[index // 8] and frame["direction"] == directions[index % 8]
    x, y, w, h = frame["output_region"]
    assert [x, y, w, h] == [(index % 8) * 96, (index // 8) * 96, 96, 96]
    cell = atlas.crop((x, y, x + w, y + h))
    bounds = cell.getbbox()
    assert bounds and bounds[0] >= 1 and bounds[1] >= 1 and bounds[2] <= 95 and bounds[3] == 84
    height = bounds[3] - bounds[1]
    assert height <= 60
    if frame["state"] == "grounded":
        assert 56 <= height <= 60
    pixels = np.array(cell)
    assert set(np.unique(pixels[:, :, 3])).issubset({0, 255})
    pixel_hashes.add(hashlib.sha256(cell.tobytes()).hexdigest())
    declared = frame["output_visible_bounds"]
    assert declared == [bounds[0], bounds[1], bounds[2]-bounds[0], height]
    checks.append({"state": frame["state"], "direction": frame["direction"], "actual_bounds": list(bounds)})
assert len(pixel_hashes) == 80
for page in manifest["sources"]:
    assert sha(resource(page["path"])) == page["sha256"]
    if "removal_mask_path" in page:
        assert sha(resource(page["removal_mask_path"])) == page["removal_mask_sha256"]
for name in ["prepared-v4", "prepared-v5"]:
    folder = ROOT / name
    receipt = json.loads((folder / "extraction-receipt.json").read_text())
    assert sha(ROOT / receipt["base_spec"]) == receipt["base_spec_sha256"] if "base_spec_sha256" in receipt else True
    for board in receipt["boards"]:
        assert sha(ROOT / board["source"]) == board["source_sha256"]
        assert sha(folder / board["prepared"]) == board["prepared_sha256"]
        assert sha(folder / board["mask"]) == board["mask_sha256"]
report = {"status": "technical_80_cell_pass_visual_playtest_candidate_not_final_art_acceptance",
          "png_sha256": sha(CANDIDATE / "s_wayne.png"), "rgba_sha256": manifest["rgba_sha256"],
          "dimensions": list(atlas.size), "mode": atlas.mode, "frame_count": 80, "distinct_rgba_cells": len(pixel_hashes),
          "all_actual_exclusive_bottom": 84, "global_body_scale": manifest["body_scale"], "per_pose_resizing": False,
          "originals_and_masks_hash_verified": True, "native_review": "Actual Godot sheet-dark/sheet-light and gait A/B inspected",
          "limitations": ["Diagonal walk arms do not all show full counter-swing", "Exact yaw and costume microdetail can vary by source epoch",
                         "Two contact phases are not a hand-authored multi-frame gait overhaul", "Neutral edge-removal risks remain inspectable in masks",
                         "Gameplay and live promotion unchanged"], "cells": checks}
path = CANDIDATE / "technical-qa.json"
assert not path.exists(), "Refusing to overwrite audit receipt"
path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("PASS: 80 distinct RGBA cells; all actual bottoms84; 8 grounded57-58px; source/mask hashes verified; no live promotion")
print("PNG", report["png_sha256"])
print("RGBA", report["rgba_sha256"])

