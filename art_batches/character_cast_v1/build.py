"""Bounded, offline named-cast assembler. Generated identity art is mandatory.

One named character is assembled at a time. Nothing here changes gameplay,
promotes assets, or turns a technical receipt into visual acceptance.
"""
from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DIRECTIONS = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
CELL, PIVOT = (96, 96), (48, 84)
SIZES = ("small", "middle", "large")


def module_at(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


factory = module_at("cast_race_factory", REPO / "art_batches/race_sprite_factory_v1/factory.py")
volume = module_at("cast_volume_templates", REPO / "art_batches/character_volume_v1/volume.py")
require, sha, write_json = factory.require, factory.sha, factory.write_json


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def finite_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def safe_id(value):
    return isinstance(value, str) and re.fullmatch(r"[a-z][a-z0-9_-]*", value) is not None


def load_catalog(path):
    path = Path(path).resolve()
    catalog = read_json(path)
    require(catalog.get("schema_version") == 1, "Catalog schema_version must be 1")
    characters = catalog.get("characters")
    require(isinstance(characters, list) and characters, "Catalog needs characters")
    seen = set()
    for item in characters:
        require(safe_id(item.get("id")), "Unsafe or absent character id")
        require(item["id"] not in seen, "Duplicate character id")
        seen.add(item["id"])
        require(item.get("size") in SIZES, f"Invalid size: {item['id']}")
        require(isinstance(item.get("race"), str) and item["race"], f"Missing race: {item['id']}")
    return catalog


def load_parts(recipe_path, spec, anchor_names):
    """Crop an authored eight-direction component. No mirroring or color keying."""
    source = (Path(recipe_path).resolve().parent / spec["source_png"]).resolve()
    require(source.is_file(), f"Missing component source: {source}")
    require(isinstance(spec.get("source_sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", spec["source_sha256"]) is not None,
            "Explicit source_sha256 is required")
    require(sha(source) == spec["source_sha256"], "Component source hash mismatch")
    with Image.open(source) as opened:
        require(opened.format == "PNG" and opened.mode == "RGBA", "Authored source must be RGBA PNG")
        image = opened.copy()
    require(image.getchannel("A").getextrema()[0] == 0, "Authored source lacks true transparency")
    threshold = spec.get("alpha_threshold", 127)
    require(type(threshold) is int and 1 <= threshold <= 255, "Invalid alpha threshold")
    entries = spec["parts"]
    require(set(entries) == set(DIRECTIONS), "Exactly eight authored directional parts required")
    parts, measurements, rectangles = {}, {}, []
    for direction in DIRECTIONS:
        entry = entries[direction]
        rect = entry.get("rect")
        require(isinstance(rect, list) and len(rect) == 4 and all(type(v) is int for v in rect), "Invalid source rect")
        x, y, w, h = rect
        require(x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= image.width and y+h <= image.height,
                f"Out-of-source rect: {direction}")
        require(all(x+w <= a or a+c <= x or y+h <= b or b+d <= y for a,b,c,d in rectangles),
                f"Overlapping directional crops: {direction}")
        rectangles.append(rect)
        part = image.crop((x, y, x+w, y+h))
        part.putalpha(part.getchannel("A").point(lambda a: 255 if a >= threshold else 0))
        bounds = part.getchannel("A").getbbox()
        require(bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < w and bounds[3] < h,
                f"Empty or clipped authored part: {direction}")
        for name in anchor_names:
            anchor = entry.get(name)
            require(isinstance(anchor, list) and len(anchor) == 2 and all(finite_number(v) for v in anchor)
                    and 0 <= anchor[0] < w and 0 <= anchor[1] < h, f"Invalid {name}: {direction}")
        clean = Image.new("RGBA", part.size)
        clean.paste(part, (0, 0), part.getchannel("A"))
        parts[direction] = clean
        measurements[direction] = {**entry, "alpha_bounds": list(bounds), "rgba_sha256": factory.rgba_sha(clean)}
    return parts, {"source": str(source.relative_to(REPO)) if source.is_relative_to(REPO) else str(source),
                   "source_sha256": sha(source), "alpha_threshold": threshold, "parts": measurements}


def load_recipe(path, character):
    path = Path(path).resolve()
    config = read_json(path)
    require(config.get("schema_version") == 1, "Component recipe schema_version must be 1")
    require(config.get("character_id") == character["id"], "Recipe character_id mismatch")
    require(config.get("directions") == list(DIRECTIONS), "Directions must be S clockwise to SW")
    require(finite_number(config.get("reference_head_height")) and config["reference_head_height"] > 0,
            "Measured reference_head_height required")
    head_spec = {**config, "parts": config["heads"]}
    parts, provenance = load_parts(path, head_spec, ("chin_anchor",))
    torso_parts, torso_provenance = (None, None)
    if "torso" in config:
        torso_parts, torso_provenance = load_parts(path, config["torso"], ("neck_anchor", "pelvis_anchor"))
    fingerprint = hashlib.sha256("".join(provenance["parts"][d]["rgba_sha256"] for d in DIRECTIONS).encode()).hexdigest()
    return config, parts, torso_parts, {"recipe_sha256": sha(path), "head": provenance,
                                      "torso": torso_provenance, "identity_fingerprint": fingerprint}


def load_body_renderer(palette=None, torso_overlay=None):
    """Compose existing AST adapter with volume girth without editing either."""
    path = REPO / "art_batches/race_sprite_factory_v1/factory.py"
    tree = ast.parse(path.read_text(encoding="utf-8"))
    fn = copy.deepcopy(next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "load_renderer"))
    inserts = [i for i,n in enumerate(fn.body) if isinstance(n, ast.Assign)
               and any(isinstance(t, ast.Name) and t.id == "module" for t in n.targets)]
    require(len(inserts) == 1, "Headless renderer composition contract changed")
    fn.body[inserts[0]:inserts[0]] = ast.parse("fn = _volume.girth_ast(fn)").body
    namespace = dict(vars(factory), _volume=volume)
    exec(compile(ast.fix_missing_locations(ast.Module(body=[fn], type_ignores=[])), "<cast-volume-renderer>", "exec"), namespace)
    return namespace["load_renderer"](palette, torso_overlay)


def prepare_character(recipe, config, parts, torso_parts, character, data):
    body = character["size"]
    renderer, headless = load_body_renderer(config.get("palette"))
    standing = {p["aim"]: p for p in data["poses"] if p["body"] == body and p["state"] == "grounded"}
    bounds = renderer.head_bounds(standing[0], data)
    scale = (bounds[3]-bounds[1]+1)/config["reference_head_height"]
    heads = {}
    for direction, part in parts.items():
        anchor = config["heads"][direction]["chin_anchor"]
        heads[(body, f"neutral/{direction}")] = (
            part.resize((max(1, round(part.width*scale)), max(1, round(part.height*scale))), Image.Resampling.NEAREST),
            (round(anchor[0]*scale), round(anchor[1]*scale)), "chin")
    torso_stats = {"minimum_determinant": None, "fallback_count": 0} if torso_parts else None
    if torso_parts:
        entries = config["torso"]["parts"]
        scales = {}
        for aim, direction in enumerate(DIRECTIONS):
            entry = entries[direction]
            target = math.dist(renderer.display_point(standing[aim]["points"]["neck"], body),
                               renderer.display_point(standing[aim]["points"]["pelvis"], body))
            source = math.dist(entry["neck_anchor"], entry["pelvis_anchor"])
            require(source > 1, "Degenerate torso calibration")
            scales[direction] = target/source
        def overlay(canvas, pose, rig, gender):
            direction = DIRECTIONS[pose["aim"]]
            entry = entries[direction]
            neck = renderer.display_point(pose["points"]["neck"], body)
            pelvis = renderer.display_point(pose["points"]["pelvis"], body)
            inverse, diagnostic = factory.torso_affine(entry["neck_anchor"], entry["pelvis_anchor"],
                (neck[0]+48, neck[1]+48), (pelvis[0]+48, pelvis[1]+48), scales[direction])
            layer = torso_parts[direction].transform((192, 192), Image.Transform.AFFINE, inverse,
                                                   resample=Image.Resampling.NEAREST)
            box = layer.getchannel("A").getbbox()
            require(box and box[0] > 48 and box[1] > 48 and box[2] < 144 and box[3] <= 132,
                    f"Torso clipping: {character['id']}/{factory.pose_key(pose)} {box}")
            current = torso_stats["minimum_determinant"]
            torso_stats["minimum_determinant"] = min(current, diagnostic["determinant"]) if current else diagnostic["determinant"]
            canvas.alpha_composite(layer.crop((48, 48, 144, 144)))
        renderer, headless = load_body_renderer(config.get("palette"), overlay)
    return renderer, headless, heads, {"head_scale": scale, "torso": torso_stats}


def selected_characters(catalog, ids=None):
    selected = catalog["characters"] if not ids else [c for c in catalog["characters"] if c["id"] in ids]
    require(not ids or set(ids) == {c["id"] for c in selected}, "Unknown requested character id")
    return selected


def preflight(catalog_path, ids=None):
    """Validate all selected sources before writing anything. No stand-ins."""
    catalog_path = Path(catalog_path).resolve()
    catalog = load_catalog(catalog_path)
    results, fingerprints, errors = {}, {}, []
    for character in selected_characters(catalog, ids):
        try:
            require(character.get("component_recipe"), f"Missing component_recipe: {character['id']}")
            recipe = (catalog_path.parent / character["component_recipe"]).resolve()
            _, _, _, provenance = load_recipe(recipe, character)
            fingerprint = provenance["identity_fingerprint"]
            require(fingerprint not in fingerprints, f"Duplicate named identity artwork: {fingerprints.get(fingerprint)} and {character['id']}")
            fingerprints[fingerprint] = character["id"]
            results[character["id"]] = {"recipe": str(recipe), "provenance": provenance}
        except (ValueError, KeyError, OSError) as exc:
            errors.append(f"{character['id']}: {exc}")
    require(not errors, "Source preflight blocked; no output written:\n" + "\n".join(errors))
    return catalog, results


def safe_output(path):
    path = Path(path).resolve()
    roots = (HERE / "output", REPO / ".godot/character-cast-candidates")
    require(any(path.is_relative_to(r.resolve()) and path != r.resolve() for r in roots), "Output must be a named staged candidate folder")
    require(not path.exists(), "Output already exists; choose a fresh candidate path")
    return path


def expected_keys(base_rows):
    return {f"{state}/{aim}" for state in base_rows for aim in range(8)} | {
        f"{state}/{travel}/{aim}/{phase}" for state in ("locomotion", "sprint_locomotion")
        for travel in range(8) for aim in range(8) for phase in range(8)}


def build(catalog_path, output, ids=None, sample_only=False):
    catalog_path = Path(catalog_path).resolve()
    catalog, sources = preflight(catalog_path, ids)
    out = safe_output(output)
    original = read_json(factory.RIG_DIR / "rig-data.json")
    factory.validate_rig(original)
    data = volume.adapt_data(original)
    # Original threshold-based stride tests are not valid after fixed-bone
    # reproportioning; preserve exact semantic banks and use adapter tests for
    # new bone lengths/support contacts instead.
    for body in SIZES:
        poses = [p for p in data["poses"] if p["body"] == body]
        require(len(poses) == 1104 and {factory.pose_key(p) for p in poses} == expected_keys(data["base_rows"]),
                f"Volume adapter changed semantic banks: {body}")
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    manifest = {"schema_version": 1, "factory": "character_cast_v1", "status": "staged_pending_visual_review",
                "production_ready": False, "human_approved": False, "runtime_verified": False,
                "sample_only": sample_only, "cell": list(CELL), "pivot": list(PIVOT),
                "directions": list(DIRECTIONS), "base_rows": data["base_rows"],
                "motion_revision": data["motion_revision"], "volume_revision": data["volume_revision"],
                "volume_profiles": data["volume_profiles"], "characters": {},
                "provenance": {"catalog_sha256": sha(catalog_path), "builder_sha256": sha(__file__),
                               "factory_sha256": sha(factory.__file__), "volume_adapter_sha256": sha(volume.__file__),
                               "rig_data_sha256": sha(factory.RIG_DIR / "rig-data.json"),
                               "rig_source_sha256": original["rig_sha256"]},
                "residency_policy": "build_and_validate_one_named_character_at_a_time",
                "limits": ["Authored directional identity heads on shared volume rig; not finished race anatomy.",
                           "No runtime presenter, portraits, afterimages, gameplay, or checkpoint changes.",
                           "Technical coverage does not establish directional, animation, or style acceptance."]}
    selected = selected_characters(catalog, ids)
    board = Image.new("RGB", (8*96+180, len(selected)*112+36), "#282735")
    draw = ImageDraw.Draw(board)
    draw.text((8, 8), "NAMED CAST / VOLUME-FIRST / STAGED TECHNICAL CANDIDATE", fill="#e1c794")
    for row, character in enumerate(selected):
        identifier = character["id"]
        recipe = Path(sources[identifier]["recipe"])
        config, parts, torsos, provenance = load_recipe(recipe, character)
        renderer, headless, heads, metrics = prepare_character(recipe, config, parts, torsos, character, data)
        poses = [p for p in data["poses"] if p["body"] == character["size"]
                 and (not sample_only or p["state"] in ("grounded", "slide", "roll"))]
        atlas = Image.new("RGBA", (96*16, 96*math.ceil(len(poses)/16)))
        records = []
        draw.text((8, row*112+52), character.get("display_name", character.get("name", identifier)), fill="#e1c794")
        draw.text((8, row*112+67), f"{character['race']} / {character['size']}", fill="#b7aba3")
        for index, pose in enumerate(poses):
            cell = factory.assemble(pose, data, "neutral", renderer, headless, heads)
            atlas.paste(cell, ((index % 16)*96, (index // 16)*96))
            record = {"key": factory.pose_key(pose), "state": pose["state"], "aim": pose["aim"],
                      "atlas_index": index, "rgba_sha256": factory.rgba_sha(cell), "bounds": factory.validate_cell(cell)}
            if "travel" in pose:
                record["travel"] = pose["travel"]
            if "phase" in pose:
                record["phase"] = pose["phase"]
            records.append(record)
            if pose["state"] == "grounded":
                board.paste(cell, (180+pose["aim"]*96, row*112+30), cell)
        if not sample_only:
            require({r["key"] for r in records} == expected_keys(data["base_rows"]) and len(records) == 1104,
                    f"Incomplete character frame banks: {identifier}")
        atlas_path, index_path = out / f"{identifier}.png", out / f"{identifier}.frames.json"
        atlas.save(atlas_path)
        write_json(index_path, records)
        manifest["characters"][identifier] = {"id": identifier, "name": character.get("display_name", character.get("name", identifier)),
            "body": character["size"], "race": character["race"], "appearance": character.get("appearance", "unspecified"),
            "atlas": atlas_path.name, "frames": index_path.name, "atlas_columns": 16,
            "atlas_dimensions": list(atlas.size), "atlas_sha256": sha(atlas_path), "frames_sha256": sha(index_path),
            "logical_frames": len(records), "atlas_uncompressed_rgba_bytes": atlas.width*atlas.height*4,
            "provenance": provenance, "metrics": metrics, "partial_anatomy": True,
            "visual_holds": config.get("visual_holds", ["Shared limbs; racial appendages and named costume require review."])}
        atlas.close()
        print(f"Built {identifier}: {len(records)} logical frames", flush=True)
    board.save(out / "cast-review.png")
    write_json(out / "manifest.json", manifest)
    result = check(out)
    write_json(out / "receipt.json", result)
    return result


def contained_file(root, name):
    require(isinstance(name, str), "Invalid manifest path")
    path = (root / name).resolve()
    require(path.is_relative_to(root.resolve()) and path.is_file(), "Manifest path escapes candidate or missing")
    return path


def check(output):
    out = Path(output).resolve()
    manifest = read_json(out / "manifest.json")
    require(manifest.get("factory") == "character_cast_v1", "Not a named-cast candidate")
    require(manifest.get("cell") == list(CELL) and manifest.get("pivot") == list(PIVOT), "Cell/pivot mismatch")
    require(not any(manifest.get(k) for k in ("production_ready", "human_approved", "runtime_verified")),
            "This checker cannot validate promoted approval claims")
    total, peak = 0, 0
    for identifier, item in manifest["characters"].items():
        atlas_path, index_path = contained_file(out, item["atlas"]), contained_file(out, item["frames"])
        require(sha(atlas_path) == item["atlas_sha256"] and sha(index_path) == item["frames_sha256"], "Candidate file hash mismatch")
        records = read_json(index_path)
        require(len(records) == item["logical_frames"] and len({r["key"] for r in records}) == len(records), "Duplicate/missing frame records")
        if not manifest["sample_only"]:
            require(len(records) == 1104 and {r["key"] for r in records} == expected_keys(manifest["base_rows"]), "Incomplete frame bank")
        with Image.open(atlas_path) as atlas:
            require(atlas.mode == "RGBA" and list(atlas.size) == item["atlas_dimensions"], "Atlas format/dimensions mismatch")
            for record in records:
                i = record["atlas_index"]
                require(type(i) is int and 0 <= i < len(records), "Invalid atlas frame index")
                x, y = (i % item["atlas_columns"])*96, (i // item["atlas_columns"])*96
                cell = atlas.crop((x, y, x+96, y+96))
                require(factory.rgba_sha(cell) == record["rgba_sha256"], "Decoded frame hash mismatch")
                require(factory.validate_cell(cell) == record["bounds"], "Frame bounds mismatch")
            peak = max(peak, atlas.width*atlas.height*4)
        total += len(records)
    return {"status": "technical_pass_not_visual_approval", "characters": len(manifest["characters"]),
            "logical_frames": total, "maximum_single_atlas_rgba_bytes": peak,
            "human_approved": False, "runtime_verified": False, "production_ready": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("preflight", "sample", "build", "check"))
    parser.add_argument("--catalog", default=str(HERE / "catalog.json"))
    parser.add_argument("--out")
    parser.add_argument("--characters", nargs="*")
    args = parser.parse_args()
    if args.command == "preflight":
        _, sources = preflight(args.catalog, args.characters)
        result = {"status": "source_pass", "characters": len(sources)}
    else:
        require(args.out, "--out is required")
        result = check(args.out) if args.command == "check" else build(args.catalog, args.out, args.characters, args.command == "sample")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
