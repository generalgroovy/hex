"""Fluup-only reviewed technical extraction. Original RGBA subjects are never painted.
Reuses the tested source separation primitive. Writes a new version, never overwrites.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
MODULE = ROOT.parent / "s_wayne" / "separate_review_boards.py"
loader = importlib.util.spec_from_file_location("reviewed_separation", MODULE)
helper = importlib.util.module_from_spec(loader)
loader.loader.exec_module(helper)
BOARDS = [
    ("core_cardinal", "core-cardinal-v1.png", "9abedf03430d2e2f6788c0f4e45ca2358bb48947150ba1425f862b3887956425",
     ["south", "east", "north", "west"], ["grounded", "jump", "cast", "hit", "roll"]),
    ("core_diagonal", "core-diagonal-v1.png", "69585eb4d27a3bb540e5dd546dc2d9dd9892a6cbe957da719b5ecd4356d5731e",
     ["south_east", "north_east", "north_west", "south_west"], ["grounded", "jump", "cast", "hit", "roll"]),
    ("motion_cardinal", "motion-cardinal-v1.png", "31027f0646b39ff9dcc1e28fe02052b61905d170aa914d4ebfae1dcd3ff57389",
     ["south", "east", "north", "west"], ["walk", "walk_b", "sprint", "sprint_b", "slide"]),
    ("motion_diagonal", "motion-diagonal-v1.png", "05f750591c7b045b188811965cd77643a790f681bd66cf4af8fdfd535fe5c65e",
     ["south_east", "north_east", "north_west", "south_west"], ["walk", "walk_b", "sprint", "sprint_b", "slide"]),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    output = ROOT / "prepared-v1"
    if output.exists():
        raise ValueError("Refusing to overwrite extraction evidence")
    # Validate every immutable input before creating any output.
    for _, filename, expected, _, _ in BOARDS:
        assert sha(ROOT / filename) == expected, filename
    output.mkdir()
    spec = {"schema_version": 2, "champion_id": "fluup", "body": "large",
            "standing_height": 76, "status": "complete_source_coverage_gait_not_approved",
            "planned_cells": 80, "live_promotion": False, "pages": [],
            "visual_review": {"status": "NOT approved: repeated leading foot in multiple walk/sprint pairs",
                              "processing_receipt": "res://" + (output / "extraction-receipt.json").relative_to(REPO).as_posix()}}
    receipt = {"authorization": "User: Yes-use reviewed background removal and assembly.",
               "operation": "Only edge-connected reviewed neutral removal and original-pixel component translation",
               "background_rule": {"minimum_channel": 170, "maximum_spread": 18},
               "edge_risk": "Exterior-connected neutral armor highlights can be removed; exact masks retained for review.",
               "helper": MODULE.relative_to(REPO).as_posix(), "helper_sha256": sha(MODULE), "boards": []}
    for source_id, filename, expected, directions, states in BOARDS:
        raw = ROOT / filename
        original = Image.open(raw)
        packed, mask, records, alpha, kept = helper.separation(original, 4, 20)
        path, mask_path = output / (source_id + ".png"), output / (source_id + "-removal-mask.png")
        packed.save(path)
        mask.save(mask_path)
        page = {"id": source_id, "path": "res://" + path.relative_to(REPO).as_posix(), "sha256": sha(path),
                "dimensions": list(packed.size), "reference_cell_width": original.width / 4, "cells": []}
        for index, record in enumerate(records):
            page["cells"].append({"state": states[index // 4], "direction": directions[index % 4], "rect": record["rect"]})
        spec["pages"].append(page)
        receipt["boards"].append({"source": filename, "source_sha256": expected, "source_size": list(original.size),
                                 "source_alpha": alpha, "prepared": path.name, "prepared_sha256": sha(path),
                                 "mask": mask_path.name, "mask_sha256": sha(mask_path), "retained_pixels": kept,
                                 "removed_pixels": int(np.count_nonzero(np.array(mask))), "components": records,
                                 "source_column_width": original.width / 4})
        print(source_id, "20 original poses preserved", "heights", [r["original_bounds"][3] for r in records], flush=True)
    (output / "source-layout.json").write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
    (output / "extraction-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("EXTRACTION PASS: 80 source cells, not a visual animation approval")

if __name__ == "__main__":
    main()

