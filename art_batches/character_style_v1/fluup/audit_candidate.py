"""Decoded-pixel technical gate; never certifies anatomy or gait from cell count."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
CANDIDATE = ROOT / "candidate-v1"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def resource(value):
    assert value.startswith("res://")
    path = (REPO / value[6:]).resolve()
    assert path.is_relative_to(ROOT), "Audit expects only isolated Fluup resources"
    return path

manifest = json.loads((CANDIDATE / "manifest.json").read_text())
atlas = Image.open(CANDIDATE / "fluup.png")
assert atlas.mode == "RGBA" and atlas.size == (768, 960)
assert manifest["frame_count"] == 80 and manifest["complete_coverage"] and not manifest["live_promotion"]
assert sha(CANDIDATE / "fluup.png") == manifest["sha256"]
assert hashlib.sha256(atlas.tobytes()).hexdigest() == manifest["rgba_sha256"]
states = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
directions = ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
cells, hashes, idle_heights = [], set(), []
for index, frame in enumerate(manifest["frames"]):
    assert frame["state"] == states[index // 8] and frame["direction"] == directions[index % 8]
    x, y, w, h = frame["output_region"]
    assert [x, y, w, h] == [index % 8 * 96, index // 8 * 96, 96, 96]
    cell = atlas.crop((x, y, x + w, y + h))
    bounds = cell.getbbox()
    assert bounds and bounds[0] >= 1 and bounds[1] >= 1 and bounds[2] <= 95 and bounds[3] == 84, (index, bounds)
    height = bounds[3] - bounds[1]
    assert height <= 78, (index, height)
    if frame["state"] == "grounded":
        assert 74 <= height <= 78, (index, height)
        idle_heights.append(height)
    assert set(np.unique(np.array(cell)[:, :, 3])).issubset({0, 255})
    hashes.add(hashlib.sha256(cell.tobytes()).hexdigest())
    assert frame["output_visible_bounds"] == [bounds[0], bounds[1], bounds[2] - bounds[0], height]
    cells.append({"state": frame["state"], "direction": frame["direction"], "actual_bounds": list(bounds)})
assert len(hashes) == 80
for page in manifest["sources"]:
    assert sha(resource(page["path"])) == page["sha256"]
receipt = json.loads((ROOT / "prepared-v1/extraction-receipt.json").read_text())
assert sha(REPO / receipt["helper"]) == receipt["helper_sha256"]
for board in receipt["boards"]:
    folder = ROOT / "prepared-v1"
    assert sha(ROOT / board["source"]) == board["source_sha256"]
    assert sha(folder / board["prepared"]) == board["prepared_sha256"]
    assert sha(folder / board["mask"]) == board["mask_sha256"]
    raw = np.array(Image.open(ROOT / board["source"]).convert("RGBA"))
    mask = np.array(Image.open(folder / board["mask"])) > 0
    output = np.array(Image.open(folder / board["prepared"]).convert("RGBA"))
    assert np.count_nonzero(mask) == board["removed_pixels"]
    raw[mask, 3] = 0
    assert np.count_nonzero(raw[:, :, 3]) == np.count_nonzero(output[:, :, 3]) == board["retained_pixels"]
    # Every retained original pixel was translated unchanged, including RGB/alpha.
    for record in board["components"]:
        x, y, w, h = record["original_bounds"]
        tx, ty = record["translation"]
        src = raw[y:y+h, x:x+w]
        dst = output[y+ty:y+ty+h, x+tx:x+tx+w]
        opaque = src[:, :, 3] > 0
        assert np.array_equal(src[opaque], dst[opaque])
failed = ["walk/north", "sprint/south", "sprint/north"]
failed += [state + "/" + direction for state in ["walk", "sprint"]
           for direction in ["south_east", "north_east", "north_west", "south_west"]]
report = {"status": "technical_80_cell_pass_visual_animation_REJECTED_pending_contact_correction",
          "png_sha256": manifest["sha256"], "rgba_sha256": manifest["rgba_sha256"],
          "dimensions": list(atlas.size), "mode": atlas.mode, "frame_count": 80, "distinct_rgba_cells": len(hashes),
          "actual_exclusive_bottom_all_cells": 84, "grounded_heights": idle_heights,
          "global_body_scale": manifest["body_scale"], "per_pose_resizing": False,
          "originals_and_masks_hash_verified": True, "retained_pixels_unchanged_verified": True,
          "visually_approved_as_complete_animation": False, "live_promotion": False,
          "repeated_leading_foot_AB_pairs": failed,
          "limitations": ["Distinct pixel hashes do not prove alternating anatomical contacts.",
                         "Gait failures block complete animation acceptance despite 80-cell coverage.",
                         "Exact E/W torso yaw and diagonal shoulder/cloth microdetails vary across pages.",
                         "Enclosed neutral backdrop islands remain under some arms; broad color deletion would risk armor highlights.",
                         "Edge-connected neutral masking can remove exterior armor highlights; masks retained.",
                         "No source painting, mirroring, limb synthesis or runtime registry changes."],
          "cells": cells}
path = CANDIDATE / "technical-qa.json"
assert not path.exists(), "Refusing to overwrite audit receipt"
path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("TECHNICAL PASS:", len(hashes), "cells; actualbottom84; grounded", idle_heights, "source/mask hashes and retained RGBA verified")
print("VISUAL HOLD:", len(failed), "A/B pairs repeat leading foot; no full animation approval")
print("PNG", manifest["sha256"])
print("RGBA", manifest["rgba_sha256"])
