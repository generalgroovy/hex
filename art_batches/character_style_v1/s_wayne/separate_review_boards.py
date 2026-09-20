"""User-authorized technical extraction only. Originals immutable; no pose synthesis.
Removes only edge-connected reviewed neutral backdrop, separates existing components
by translation, retains every other RGBA pixel, records exact masks and provenance.
"""
from pathlib import Path
from collections import deque
from array import array
import argparse
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inside(name):
    path = (ROOT / name).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError("Path escapes isolated S. Wayne source folder")
    return path

def components(alpha):
    h, w = alpha.shape
    pending = bytearray(alpha.tobytes())
    groups = []
    for start in range(w * h):
        if not pending[start]:
            continue
        pending[start] = 0
        queue = deque([start])
        pixels = array("I")
        while queue:
            p = queue.popleft()
            pixels.append(p)
            x, y = p % w, p // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if (dx or dy) and 0 <= nx < w and 0 <= ny < h:
                        n = ny * w + nx
                        if pending[n]:
                            pending[n] = 0
                            queue.append(n)
        ids = np.frombuffer(pixels, dtype=np.uint32)
        xs, ys = ids % w, ids // w
        groups.append({"pixels": pixels, "bounds": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]})
    return sorted(groups, key=lambda g: len(g["pixels"]), reverse=True)

def separation(original, columns, count):
    rgba = np.array(original.convert("RGBA"))
    rgb = rgba[:, :, :3].astype(np.int16)
    alpha_original = {"minimum": int(rgba[:, :, 3].min()), "maximum": int(rgba[:, :, 3].max()),
                      "transparent_pixels": int(np.count_nonzero(rgba[:, :, 3] == 0))}
    removed = np.zeros(rgba.shape[:2], dtype=bool)
    if alpha_original["minimum"] == 255:
        eligible = (rgb.min(axis=2) >= 170) & ((rgb.max(axis=2) - rgb.min(axis=2)) <= 18)
        if not (eligible[0, :].all() and eligible[-1, :].all() and eligible[:, 0].all() and eligible[:, -1].all()):
            raise ValueError("Original complete perimeter does not match reviewed neutral backdrop")
        flood = Image.fromarray(eligible.astype(np.uint8) * 255).copy()
        ImageDraw.floodfill(flood, (0, 0), 128, thresh=0)
        removed = np.array(flood) == 128
        rgba[removed, 3] = 0
    groups = components((rgba[:, :, 3] > 0).astype(np.uint8))
    if len(groups) < count or len(groups[count - 1]["pixels"]) < 1000:
        raise ValueError("Missing substantial body component: " + str([(len(g["pixels"]), g["bounds"]) for g in groups[:count + 2]]))
    if len(groups) > count and len(groups[count]["pixels"]) > len(groups[count - 1]["pixels"]) * .06:
        raise ValueError("Ambiguous extra substantial component; refusing automatic subject separation")
    bodies = groups[:count]
    bodies.sort(key=lambda g: (g["bounds"][1] + g["bounds"][3]) / 2)
    ordered = []
    for i in range(0, count, columns):
        row = bodies[i:i + columns]
        row.sort(key=lambda g: (g["bounds"][0] + g["bounds"][2]) / 2)
        ordered.extend(row)
    # Preserve detached hair/edge islands; assign to nearest substantial silhouette,
    # never delete or recolor them. Excessively remote islands require manual review.
    for group in groups[count:]:
        box = group["bounds"]
        center = ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2)
        def distance(body):
            b = body["bounds"]
            return max(b[0] - center[0], center[0] - b[2], 0) ** 2 + max(b[1] - center[1], center[1] - b[3], 0) ** 2
        owner = min(ordered, key=distance)
        if distance(owner) > (original.width / columns * .3) ** 2:
            raise ValueError("Remote non-background pixel island; manual review required")
        owner["pixels"].extend(group["pixels"])
        b = owner["bounds"]
        owner["bounds"] = [min(b[0], box[0]), min(b[1], box[1]), max(b[2], box[2]), max(b[3], box[3])]
    cell_w = max(g["bounds"][2] - g["bounds"][0] for g in ordered) + 32
    cell_h = max(g["bounds"][3] - g["bounds"][1] for g in ordered) + 32
    output = np.zeros(((count + columns - 1) // columns * cell_h, columns * cell_w, 4), dtype=np.uint8)
    records = []
    for i, group in enumerate(ordered):
        x0, y0, x1, y1 = group["bounds"]
        if x0 <= 0 or y0 <= 0 or x1 >= original.width or y1 >= original.height:
            raise ValueError("Source subject touches original edge")
        ids = np.frombuffer(group["pixels"], dtype=np.uint32).astype(np.int64)
        xs, ys = ids % original.width, ids // original.width
        tx, ty = i % columns * cell_w + 16 - x0, i // columns * cell_h + 16 - y0
        output[ys + ty, xs + tx] = rgba[ys, xs]
        records.append({"original_bounds": [x0, y0, x1 - x0, y1 - y0], "translation": [tx, ty],
                        "retained_pixels": len(ids), "rect": [i % columns * cell_w, i // columns * cell_h, cell_w, cell_h]})
    kept = int(np.count_nonzero(rgba[:, :, 3]))
    assert int(np.count_nonzero(output[:, :, 3])) == kept
    return Image.fromarray(output), Image.fromarray(removed.astype(np.uint8) * 255), records, alpha_original, kept

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    config = json.loads(inside(args.config).read_text(encoding="utf-8-sig"))
    output = inside(args.output)
    if output.exists():
        raise ValueError("Refusing to overwrite prior extraction evidence")
    output.mkdir()
    base_spec = inside(config.get("base_spec", "source-layout-v3.json"))
    spec = json.loads(base_spec.read_text(encoding="utf-8-sig"))
    remove_slots = set(config.get("remove_slots", []))
    for page in spec["pages"]:
        page["cells"] = [c for c in page["cells"] if c["state"] + "/" + c["direction"] not in remove_slots]
    receipt = {"authorization": "User: Yes—use reviewed background removal and assembly.",
               "operation": "edge-connected neutral removal; connected-component translation ONLY; no scaling/recoloring/pose edits",
               "background_rule": {"minimum_channel": 170, "maximum_spread": 18},
               "edge_risk": "Light neutral highlights connected to outer backdrop may be removed; exact masks retained.",
               "base_spec": str(base_spec.relative_to(ROOT)), "base_spec_sha256": sha(base_spec), "replaced_slots": sorted(remove_slots), "boards": []}
    for board in config["boards"]:
        raw = inside(board["file"])
        if sha(raw) != board["sha256"]:
            raise ValueError("Immutable source hash mismatch: " + raw.name)
        image = Image.open(raw)
        packed, mask, records, alpha, kept = separation(image, board["columns"], len(board["cells"]))
        path = output / (board["id"] + ".png")
        mask_path = output / (board["id"] + "-removal-mask.png")
        packed.save(path)
        mask.save(mask_path)
        page = {"id": board["id"], "path": "res://" + path.relative_to(REPO).as_posix(), "sha256": sha(path),
                "dimensions": list(packed.size), "reference_cell_width": image.width / board["columns"], "cells": []}
        for cell, record in zip(board["cells"], records):
            page["cells"].append(dict(cell, rect=record["rect"]))
        spec["pages"].append(page)
        receipt["boards"].append({"source": raw.name, "source_sha256": sha(raw), "source_size": list(image.size),
                                 "source_alpha": alpha, "prepared": path.name, "prepared_sha256": sha(path),
                                 "mask": mask_path.name, "mask_sha256": sha(mask_path),
                                 "removed_pixels": int(np.count_nonzero(np.array(mask))), "retained_pixels": kept,
                                 "components": records, "source_column_width": page["reference_cell_width"]})
        print("EXTRACT PASS", raw.name, len(records), "poses;", kept, "unaltered subject pixels", flush=True)
    count = sum(len(p["cells"]) for p in spec["pages"])
    spec.update(status="complete_source_candidate_pending_visual_review" if count == 80 else "partial_source_review",
                planned_cells=count, live_promotion=False)
    spec["visual_review"] = {"status": "candidate; exact heading, contacts and edge quality still require native visual review",
                            "processing_receipt": "res://" + (output / "extraction-receipt.json").relative_to(REPO).as_posix()}
    (output / "source-layout.json").write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
    (output / "extraction-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("TOTAL", count, "/80; no runtime files changed")

if __name__ == "__main__":
    main()
