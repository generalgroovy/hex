"""Deterministic four-key action assembly, never pose generation or deformation.

Default: validate the complete catalog before publishing a runtime bank.
--available: publish only a separate, explicitly partial review bank.
One nearest-neighbour scale per source (fall row or explicit neutral row), grid-center registration,
row-wide baseline104, binary alpha128, immutable sources and ground/cast art.
"""
import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from PIL import Image, ImageDraw

WORK = Path(__file__).resolve().parent
ROOT = WORK.parents[1]
OUT = ROOT / "assets/sprites/pixel_actions_v1"
GROUND = ROOT / "assets/sprites/pixel_cast_v1"
CATALOG = ROOT / "content/champions/foundation_champions_v1.json"
spec = importlib.util.spec_from_file_location("pixel_assembly", WORK.parent / "pixel_body_pilot_v1/build.py")
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)
ROWS = ["jumpsquat", "rise", "fall", "land"]
HEIGHTS = {"small": 58, "middle": 63, "large": 68}
ATLAS_SIZE = (1024, 512)
MAX_SOURCE_BYTES = 32 * 1024 * 1024
MAX_SOURCE_PIXELS = 8 * 1024 * 1024
LEGACY_RGBA = "85e15b260ff69beafad8f7feb0ecc5e26621ca13a38dfab7be0f554975116265"
LEGACY_PNG = "49f2789e522558e95f6f1f437d082edcc385a681a3d15fe19a8ffbbab4de0b78"
RECIPE_KEYS = {"source_row_count", "source_rows", "source_columns", "columns_by_row", "column_padding",
               "calibration_source_row"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2) + "\n").encode("utf-8")


def png_bytes(image):
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def snapshot(path, watched, limit=MAX_SOURCE_BYTES):
    path = Path(path)
    if not path.is_file() or path.stat().st_size > limit:
        raise ValueError(f"Missing or oversized input: {path}")
    data = path.read_bytes()
    if not data or len(data) > limit:
        raise ValueError(f"Empty or oversized input: {path}")
    watched[path] = sha(data)
    return data


def stable_inputs(watched):
    for path, expected in watched.items():
        if not path.is_file() or sha(path.read_bytes()) != expected:
            raise ValueError(f"Input changed during assembly; retry after authoring finishes: {path}")


def load_lead_review(path, watched, identity, source_sha256, assembly_sha256=None):
    """Acceptance is separate from provenance and binds to the selected PNG."""
    value = json.loads(snapshot(path, watched, 1024 * 1024))
    if not isinstance(value, dict):
        raise ValueError("lead-review.json must be an acceptance object")
    if not isinstance(value.get("id"), str) or value["id"] != identity:
        raise ValueError("lead-review.json id must match the exact catalog identity")
    if not isinstance(value.get("source_sha256"), str) or value["source_sha256"] != source_sha256:
        raise ValueError("lead-review.json source_sha256 must match the exact selected source PNG")
    if assembly_sha256 is not None and value.get("assembly_sha256") != assembly_sha256:
        raise ValueError("lead-review.json assembly_sha256 must match the exact neutral calibration assembly.json bytes")
    if value.get("accepted") is not True:
        raise ValueError("lead-review.json requires accepted: true; HOLD or unaccepted sources cannot publish")
    if value.get("reviewer") != "integration-lead":
        raise ValueError("lead-review.json reviewer must be integration-lead")
    if value.get("review_scope") != "assembled-native-pixel-board":
        raise ValueError("lead-review.json review_scope must be assembled-native-pixel-board")
    if not isinstance(value.get("reason"), str) or not value["reason"].strip():
        raise ValueError("lead-review.json reason must be a nonblank string")
    return value


def load_roster(path, watched):
    value = json.loads(snapshot(path, watched, 1024 * 1024))
    roster = value.get("champions") if isinstance(value, dict) else None
    if not isinstance(roster, list) or len(roster) != 30:
        raise ValueError("Expected all 30 catalog identities")
    seen = set()
    for entry in roster:
        identity = entry.get("id") if isinstance(entry, dict) else None
        if not isinstance(identity, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", identity) or identity in seen:
            raise ValueError("Invalid or duplicate catalog identity")
        if entry.get("body_type") not in HEIGHTS:
            raise ValueError(f"Invalid catalog body: {identity}")
        seen.add(identity)
    return roster


def integer(value, low, high, name):
    if type(value) is not int or not low <= value <= high:
        raise ValueError(f"{name} must be an integer from {low} to {high}")
    return value


def indices(value, length, maximum, name):
    if not isinstance(value, list) or len(value) != length:
        raise ValueError(f"{name} must contain exactly {length} indices")
    result = [integer(i, 0, maximum, name) for i in value]
    if len(set(result)) != length:
        raise ValueError(f"{name} must not repeat indices")
    return result


def recipe(value, identity):
    if not isinstance(value, dict) or set(value) - RECIPE_KEYS:
        raise ValueError("assembly.json must be an object with only supported mapping/padding/calibration keys")
    count = integer(value.get("source_row_count", 4), 4, 16, "source_row_count")
    rows = indices(value.get("source_rows", [0, 1, 2, 3]), 4, count - 1, "source_rows")
    columns = indices(value.get("source_columns", list(range(8))), 8, 7, "source_columns")
    padding = integer(value.get("column_padding", 12 if identity == "s_wayne" else 32), 0, 64, "column_padding")
    by_row = value.get("columns_by_row", {})
    if not isinstance(by_row, dict) or set(by_row) - {"0", "1", "2", "3"}:
        raise ValueError("columns_by_row keys must be target rows 0..3 as strings")
    by_row = {key: indices(mapped, 8, 7, "columns_by_row") for key, mapped in by_row.items()}
    result = {"source_row_count": count, "source_rows": rows, "source_columns": columns,
              "columns_by_row": by_row, "column_padding": padding}
    if "calibration_source_row" in value:
        if identity == "s_wayne":
            raise ValueError("S. Wayne legacy assembly recipe is locked; calibration_source_row is forbidden")
        calibration_row = integer(value["calibration_source_row"], 0, count - 1, "calibration_source_row")
        if calibration_row in rows:
            raise ValueError("calibration_source_row must be a separate neutral row, not one of source_rows")
        result["calibration_source_row"] = calibration_row
    if identity == "s_wayne" and (count != 4 or rows != [0, 1, 2, 3] or columns != list(range(8)) or by_row or padding != 12):
        raise ValueError("S. Wayne legacy assembly recipe is locked to preserve exact pixels")
    return result


def source_image(data):
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "PNG" or getattr(image, "n_frames", 1) != 1:
            raise ValueError("Source must be a single-frame PNG")
        if not (32 <= image.width <= 8192 and 16 <= image.height <= 8192) or image.width * image.height > MAX_SOURCE_PIXELS:
            raise ValueError("Source dimensions exceed the bounded assembly budget")
    image = assembly.clean(io.BytesIO(data))
    box = image.getbbox()
    if not box or box[0] <= 0 or box[1] <= 0 or box[2] >= image.width or box[3] >= image.height:
        raise ValueError("Blank source or artwork touching the source canvas edge")
    return image


def source_cells(image, config, reference_cells=None):
    frames = []
    padding = config["column_padding"]
    for top, bottom in assembly.bands(image, config["source_row_count"]):
        row = []
        for column in range(8):
            left = round(column * image.width / 8) - padding
            right = round((column + 1) * image.width / 8) + padding
            cell = assembly.isolate_character(image.crop((left, top, right, bottom)))
            box = cell.getbbox()
            if not box or box[0] <= 0 or box[2] >= cell.width:
                raise ValueError(f"Empty/clipped source cell {len(frames)}/{column}: {box}")
            row.append(cell)
        frames.append(row)
    if reference_cells is not None:
        reference_cells.extend(frames[config["calibration_source_row"]][column] for column in config["source_columns"])
    return [[frames[source_row][column] for column in config["columns_by_row"].get(str(row), config["source_columns"])]
            for row, source_row in enumerate(config["source_rows"])]


def assemble(source, body, config, calibration=None):
    reference_cells = []
    if "calibration_source_row" in config:
        frames = source_cells(source, config, reference_cells)
    else:
        frames = source_cells(source, config)
    reference = reference_cells if reference_cells else frames[2]
    reference_height = max(frame.getbbox()[3] - frame.getbbox()[1] for frame in reference)
    factor = HEIGHTS[body] / reference_height
    if reference_cells and calibration is not None:
        calibration.update({"method": "neutral_source_row", "source_row": config["calibration_source_row"],
                            "coordinate_space": "extracted source cells before resizing",
                            "maximum_source_height": reference_height, "scale": factor,
                            "cells": [{"direction": assembly.DIRS[column], "ink": list(frame.getbbox()),
                                       "height": frame.getbbox()[3] - frame.getbbox()[1]}
                                      for column, frame in enumerate(reference_cells)]})
    atlas = Image.new("RGBA", ATLAS_SIZE)
    boxes, signatures = [], [[] for _ in range(8)]
    for row, cells in enumerate(frames):
        resized = []
        for cell in cells:
            size = (round(cell.width * factor), round(cell.height * factor))
            if min(size) < 1 or max(size) > 1024:
                raise ValueError("Resized source cell exceeds the bounded assembly budget")
            resized.append(cell.resize(size, Image.Resampling.NEAREST))
        if any(cell.getbbox() is None for cell in resized):
            raise ValueError(f"Blank action after uniform scaling: row {row}")
        baseline = max(cell.getbbox()[3] for cell in resized)
        for column, cell in enumerate(resized):
            offset = (64 - cell.width // 2, 104 - baseline)
            ink = cell.getbbox()
            placed = (ink[0] + offset[0], ink[1] + offset[1], ink[2] + offset[0], ink[3] + offset[1])
            if min(placed[:2]) <= 0 or max(placed[2:]) >= 128:
                raise ValueError(f"Empty/clipped action cell {row}/{column}: {placed}")
            tight = cell.crop(ink)
            signature = (tight.size, sha(tight.tobytes()))
            if signature in signatures[column]:
                raise ValueError(f"Duplicate action poses in facing {assembly.DIRS[column]}, row {row}")
            signatures[column].append(signature)
            tile = Image.new("RGBA", (128, 128))
            tile.paste(cell, offset)
            atlas.paste(tile, (column * 128, row * 128))
            boxes.append({"row": row, "direction": assembly.DIRS[column], "ink": list(tile.getbbox())})
    return atlas, factor, boxes


def ground_image(data):
    with Image.open(io.BytesIO(data)) as source:
        if source.size != ATLAS_SIZE or source.format != "PNG":
            raise ValueError("Ground comparison must be the existing 1024x512 PNG bank")
        return source.convert("RGBA")


def manifest(entries):
    return {"id": "hex-pixel-actions-v1", "schema_version": 1, "cell": [128, 128],
            "pivot": [64, 104], "directions": assembly.DIRS, "rows": ROWS, "characters": entries}


def prepare(roster, source_root, ground_root, available=False, watched=None):
    """Validate all inputs and render in memory. This function has no writes."""
    watched = {} if watched is None else watched
    entries, sources, errors, missing = [], [], [], []
    runtime_files, review_files = {}, {}
    # Show native pixels: quarter-sized thumbnails concealed the very head and
    # leg differences this overview is meant to review. Three readable columns.
    overview = Image.new("RGBA", (1440, ((len(roster) + 2) // 3) * 176), "#31473e")
    labels = ImageDraw.Draw(overview)
    for number, champion in enumerate(roster):
        identity, body = champion["id"], champion["body_type"]
        directory = source_root / identity
        path = directory / ("proportion-repair-v3.png" if identity == "s_wayne" else "source.png")
        receipt_path = directory / "receipt.json"
        x, y = number % 3 * 480, number // 3 * 176
        labels.text((x + 5, y + 146), champion.get("display_name", identity), fill="#f1d9a2")
        labels.text((x + 5, y + 160), body, fill="#aabdab")
        if not path.is_file() or not receipt_path.is_file():
            missing.append(identity)
            labels.text((x + 12, y + 65), "SOURCE PENDING", fill="#d99880")
            continue
        try:
            receipt = json.loads(snapshot(receipt_path, watched, 1024 * 1024))
            if not isinstance(receipt, dict) or not receipt:
                raise ValueError("receipt.json must be a nonempty provenance object")
            config_path = directory / "assembly.json"
            config = recipe(json.loads(snapshot(config_path, watched, 65536)) if config_path.is_file() else {}, identity)
            data = snapshot(path, watched)
            source_sha256 = sha(data)
            lead_review_path = directory / "lead-review.json"
            if not available:
                load_lead_review(lead_review_path, watched, identity, source_sha256,
                                 watched[config_path] if "calibration_source_row" in config else None)
            calibration = {}
            if "calibration_source_row" in config:
                atlas, factor, boxes = assemble(source_image(data), body, config, calibration)
            else:
                atlas, factor, boxes = assemble(source_image(data), body, config)
            encoded = png_bytes(atlas)
            rgba = sha(atlas.tobytes())
            if identity == "s_wayne" and (rgba != LEGACY_RGBA or sha(encoded) != LEGACY_PNG):
                raise ValueError("S. Wayne no longer matches the exact original runtime PNG; publication refused")
            ground_path = ground_root / f"{identity}.png"
            ground = ground_image(snapshot(ground_path, watched))
            board = Image.new("RGBA", (1024, 640), "#31473e")
            board.alpha_composite(ground.crop((0, 0, 1024, 128)), (0, 0))
            board.alpha_composite(atlas, (0, 128))
            text = ImageDraw.Draw(board)
            for row, name in enumerate(["existing idle"] + ROWS):
                text.text((5, row * 128 + 112), name, fill="#f1d9a2")
            leaf = identity + ".png"
            runtime_files[leaf] = encoded
            review_files["boards/" + leaf] = png_bytes(board)
            entries.append({"id": identity, "body": body, "atlas": leaf, "rgba_sha256": rgba})
            sources.append({"id": identity, "source": str(path), "source_sha256": source_sha256,
                            "receipt_sha256": watched[receipt_path], "recipe": config, "scale": factor,
                            "png_sha256": sha(encoded), "ground_sha256": watched[ground_path], "cells": boxes})
            if calibration:
                sources[-1]["calibration"] = calibration
                sources[-1]["assembly_sha256"] = watched[config_path]
            if not available:
                sources[-1]["lead_review_sha256"] = watched[lead_review_path]
            # Compare existing idle and all four source keys without changing runtime pixels.
            for column, image in enumerate([ground] + [atlas.crop((0, row * 128, 128, (row + 1) * 128)) for row in range(4)]):
                thumb = image.crop((0, 0, 128, 128))
                overview.alpha_composite(thumb, (x + column * 92, y + 5))
                labels.text((x + column * 92 + 44, y + 115), (["idle"] + ROWS)[column], fill="#aabdab")
        except (ValueError, OSError, AssertionError, IndexError, KeyError) as error:
            errors.append({"id": identity, "error": str(error)})
            labels.text((x + 12, y + 65), "VALIDATION FAILED", fill="#d99880")
    if not available and (missing or errors or len(entries) != len(roster)):
        raise ValueError("No output changed: incomplete/invalid action roster: " + json.dumps({"missing": missing, "errors": errors}))
    if not entries:
        raise ValueError("No valid action sources; no output changed: " + json.dumps({"missing": missing, "errors": errors}))
    stable_inputs(watched)
    runtime_files["manifest.json"] = json_bytes(manifest(entries))
    report = {"status": "assembled_for_review_not_human_accepted", "partial_review": available,
              "runtime_publication": not available, "characters": entries, "sources": sources,
              "lead_review_gate": "not_required_partial_review" if available else "passed",
              "missing": missing, "errors": errors, "physical_rows": ROWS,
              "registration": "source grid center; one source-wide fall-height scale; row-wide baseline104; world lift external",
              "alpha": "threshold128; hidden RGB zeroed; immutable originals retained",
              "scope": "four whole-body keys, not full cycles, new action families or independent cast limbs"}
    if any("calibration" in source for source in sources):
        report["registration"] = "source grid center; one source-wide scale from explicit neutral row or legacy fall height; row-wide baseline104; world lift external"
    review_files.update(runtime_files)
    review_files["assembly.json"] = json_bytes(report)
    review_files["roster.png"] = png_bytes(overview)
    return runtime_files, review_files, report


def publish(groups, before_commit=None):
    """Stage every byte first; directory-rename commits with rollback on IO error.

    Existing runtime import sidecars are retained. No partial manifest is ever
    published. Windows has no atomic exchange of two populated directories:
    readers may observe a brief missing path, never a half-written new bank.
    Stop live imports before publishing; every individual rename is atomic.
    """
    stages, committed, success = [], [], False
    try:
        for target, files, preserve in groups:
            if Path(target).is_symlink():
                raise ValueError(f"Output must not be a symbolic link: {target}")
            target = Path(target).resolve()
            if target.exists() and (not target.is_dir() or target.is_symlink()):
                raise ValueError(f"Output must be a real directory: {target}")
            target.parent.mkdir(parents=True, exist_ok=True)
            owner = Path(tempfile.mkdtemp(prefix=f".{target.name}-stage-", dir=target.parent))
            stage, backup = owner / "next", owner / "previous"
            stages.append((owner, target, stage, backup))
            if preserve and target.exists():
                shutil.copytree(target, stage, symlinks=True)
            else:
                stage.mkdir()
            for leaf, data in files.items():
                path = stage / leaf
                if not path.resolve().is_relative_to(stage.resolve()):
                    raise ValueError("Unsafe staged output filename")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        if before_commit:
            before_commit()
        for owner, target, stage, backup in stages:
            existed = target.exists()
            if existed:
                os.replace(target, backup)
            try:
                os.replace(stage, target)
            except OSError:
                if existed:
                    os.replace(backup, target)
                raise
            committed.append((target, stage, backup, existed))
        success = True
    except BaseException:
        for target, stage, backup, existed in reversed(committed):
            os.replace(target, stage)
            if existed:
                os.replace(backup, target)
        raise
    finally:
        for owner, target, stage, backup in stages:
            # A failed rollback must retain the old directory for recovery.
            if backup.exists() and not success:
                continue
            shutil.rmtree(owner, ignore_errors=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--available", action="store_true", help="Review available completed sources only; NEVER writes runtime output")
    parser.add_argument("--only", nargs="+", help="Limit --available review to these catalog IDs")
    parser.add_argument("--source-root", type=Path, default=WORK / "source")
    parser.add_argument("--ground-root", type=Path, default=GROUND)
    parser.add_argument("--catalog", type=Path, default=CATALOG)
    parser.add_argument("--output", type=Path, default=OUT, help="Complete runtime bank destination (ignored with --available)")
    parser.add_argument("--review-output", type=Path, help="Default: review/available or review/complete")
    args = parser.parse_args(argv)
    watched = {}
    roster = load_roster(args.catalog, watched)
    if args.only:
        if not args.available or set(args.only) - {entry["id"] for entry in roster}:
            parser.error("--only requires --available and known catalog IDs")
        roster = [entry for entry in roster if entry["id"] in args.only]
    review = args.review_output or WORK / "review" / ("available" if args.available else "complete")
    destinations = [review.resolve()] + ([] if args.available else [args.output.resolve()])
    inputs = [args.source_root.resolve(), args.ground_root.resolve(), args.catalog.resolve()]
    if any(out == src or out.is_relative_to(src) or src.is_relative_to(out) for out in destinations for src in inputs):
        parser.error("Output directories must not overlap source, ground or catalog inputs")
    if len(destinations) == 2 and (destinations[0].is_relative_to(destinations[1]) or destinations[1].is_relative_to(destinations[0])):
        parser.error("Review and runtime outputs must be separate directories")
    if args.available and any(review.resolve().is_relative_to(bank.resolve()) or bank.resolve().is_relative_to(review.resolve())
                              for bank in (OUT, args.output)):
        parser.error("Partial review output must not overlap the runtime bank")
    runtime_files, review_files, report = prepare(roster, args.source_root, args.ground_root, args.available, watched)
    groups = [(review, review_files, False)]
    if not args.available:
        groups.append((args.output, runtime_files, True))
    stable_inputs(watched)
    publish(groups, before_commit=lambda: stable_inputs(watched))
    print(json.dumps({"assembled": len(report["characters"]), "missing": report["missing"], "errors": report["errors"],
                      "complete_manifest": not args.available, "review_output": str(review),
                      "runtime_output": None if args.available else str(args.output)}))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from error
