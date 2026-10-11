"""Assemble approved source pixels, never synthesize poses or bake old meshes.

One uniform scale per source sheet; exact fixed foot registration. The three
tested pilot banks are losslessly repacked. New sources remain immutable.
Run with --available during authoring; only a complete roster writes the runtime
manifest. Review flags in source receipts are never promoted to human acceptance.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT / "assets/sprites/pixel_cast_v1"
PILOT = ROOT / "assets/sprites/pixel_body_pilot_v1"
ROWS = ["idle", "walk_contact_a", "walk_contact_b", "cast"]
HEIGHTS = {"small": 58, "middle": 63, "large": 68}
SEAMS = {"small": 93, "middle": 94, "large": 96}
spec = importlib.util.spec_from_file_location("pilot_assembly", WORK.parent / "pixel_body_pilot_v1/build.py")
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_cells(image, rows, padding, columns=8):
    # Wide empty-hand poses overhang their nominal column. Isolate the connected
    # character inside a larger gutter; never silently crop its fingertips.
    frames = []
    for top, bottom in assembly.bands(image, rows):
        row = []
        for column in range(columns):
            left = round(column * image.width / columns) - padding
            right = round((column + 1) * image.width / columns) + padding
            crop = assembly.isolate_character(image.crop((left, top, right, bottom)))
            box = crop.getbbox()
            if not box or box[0] <= 0 or box[2] >= crop.width:
                raise ValueError(f"Empty/clipped cell {column}, row {len(frames)}: {box}")
            row.append(crop)
        frames.append(row)
    return frames


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--available", action="store_true")
    args = parser.parse_args()
    roster = json.loads((ROOT / "content/champions/foundation_champions_v1.json").read_text(encoding="utf-8"))["champions"]
    pilots = {c["id"]: c for c in json.loads((PILOT / "manifest.json").read_text())["characters"]}
    missing = [c["id"] for c in roster if c["id"] not in pilots and not (WORK / "source" / c["id"] / "source.png").is_file()]
    if missing and not args.available:
        raise SystemExit("Incomplete source roster: " + ", ".join(missing))
    OUT.mkdir(parents=True, exist_ok=True)
    review = WORK / "review"
    review.mkdir(exist_ok=True)
    entries, provenance, errors = [], [], []
    overview = Image.new("RGBA", (960, 800), "#31473e")
    labels = ImageDraw.Draw(overview)
    for number, champion in enumerate(roster):
        identity, body = champion["id"], champion["body_type"]
        if identity in missing:
            continue
        try:
            atlas = Image.new("RGBA", (1024, 512))
            if identity in pilots:
                source_path = PILOT / pilots[identity]["atlas"]
                old = Image.open(source_path).convert("RGBA")
                for target_row, source_row in enumerate([0, 1, 3, 5]):
                    atlas.paste(old.crop((0, source_row * 128, 1024, (source_row + 1) * 128)), (0, target_row * 128))
                seam = pilots[identity]["waist_y"]
                details = {"reuse": "lossless tested pilot pixels", "source_rows": [0, 1, 3, 5]}
            else:
                source_path = WORK / "source" / identity / "source.png"
                source = assembly.clean(source_path)
                recipe_path = WORK / "source" / identity / "assembly.json"
                recipe = json.loads(recipe_path.read_text()) if recipe_path.exists() else {}
                frames = source_cells(source, int(recipe.get("source_row_count", 4)), int(recipe.get("column_padding", 32)))
                source_rows = recipe.get("source_rows", [0, 1, 2, 3])
                source_columns = recipe.get("source_columns", list(range(8)))
                height = max(f.getbbox()[3] - f.getbbox()[1] for f in frames[source_rows[0]])
                factor = HEIGHTS[body] / height
                for target_row, source_row in enumerate(source_rows):
                    for facing in range(8):
                        columns = recipe.get("columns_by_row", {}).get(str(target_row), source_columns)
                        registered = assembly.registered(frames[source_row][columns[facing]], factor)
                        ink = registered.getbbox()
                        if not ink or ink[0] <= 0 or ink[2] >= 128 or ink[3] != 104:
                            raise ValueError(f"Clipped or unregistered {target_row}/{facing}: {ink}")
                        atlas.paste(registered, (facing * 128, target_row * 128))
                seam = int(recipe.get("seam_y", SEAMS[body]))
                details = {"uniform_scale": factor, "source_rows": source_rows, "source_columns": source_columns,
                           "columns_by_row": recipe.get("columns_by_row", {}),
                           "receipt": str((source_path.parent / "receipt.json").relative_to(ROOT)).replace("\\", "/")}
                details["corrections"] = []
                for correction in recipe.get("corrections", []):
                    correction_path = source_path.parent / correction["file"]
                    if correction_path.resolve().parent != source_path.parent.resolve():
                        raise ValueError("Correction must be an adjacent source file")
                    corrected = source_cells(assembly.clean(correction_path), 4, 32, len(correction["target_columns"]))
                    correction_scale = HEIGHTS[body] / max(f.getbbox()[3] - f.getbbox()[1] for f in corrected[0])
                    for row in range(4):
                        for source_column, target_column in enumerate(correction["target_columns"]):
                            column = correction.get("source_columns", list(range(len(corrected[0]))))[source_column]
                            frame = assembly.registered(corrected[row][column], correction_scale)
                            atlas.paste(frame, (target_column * 128, row * 128))
                    details["corrections"].append({"file": correction["file"], "sha256": digest(correction_path),
                        "uniform_scale": correction_scale, "target_columns": correction["target_columns"],
                        "source_columns": correction.get("source_columns", list(range(len(corrected[0]))))})
            for facing in range(8):
                contacts = [atlas.crop((facing * 128, row * 128, (facing + 1) * 128, (row + 1) * 128)).tobytes() for row in [1, 2]]
                if contacts[0] == contacts[1]:
                    raise ValueError(f"Identical contact pixels in facing {facing}")
            atlas.save(OUT / (identity + ".png"))
            atlas.save(review / (identity + ".png"))
            entries.append({"id": identity, "body": body, "display_name": champion["display_name"],
                            "race": champion["ancestry"], "display_height": HEIGHTS[body],
                            "waist_y": seam, "atlas": identity + ".png",
                            "rgba_sha256": hashlib.sha256(atlas.tobytes()).hexdigest()})
            provenance.append({"id": identity, "source": str(source_path.relative_to(ROOT)).replace("\\", "/"),
                               "source_sha256": digest(source_path), **details})
            x, y = number % 6 * 160, number // 6 * 160
            overview.alpha_composite(atlas.crop((0, 0, 128, 128)), (x + 16, y + 8))
            labels.text((x + 8, y + 130), champion["display_name"], fill="#f1d9a2")
            labels.text((x + 8, y + 145), body + " / " + champion["ancestry"], fill="#aabdab")
        except (ValueError, AssertionError, IndexError) as error:
            errors.append({"id": identity, "error": str(error)})
    report = {"characters": entries, "sources": provenance, "missing": missing, "errors": errors,
              "status": "assembled_for_review_not_human_accepted", "physical_rows": ROWS,
              "passing_frames": "Neutral row reused by index; no invented intermediate anatomy",
              "alpha": "Threshold128, hidden RGB zeroed; immutable originals retained"}
    (review / "assembly.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    overview.save(review / "roster.png")
    if not missing and not errors and len(entries) == len(roster):
        manifest = {"id": "hex-pixel-cast-v1", "schema_version": 1, "cell": [128, 128],
                    "pivot": [64, 104], "directions": assembly.DIRS, "rows": ROWS,
                    "characters": entries, "acceptance": "Ground/cast coverage; advanced actions retain previous renderer; human feel acceptance open"}
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"assembled": len(entries), "missing": missing, "errors": errors,
                      "complete_manifest": not missing and not errors}))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
