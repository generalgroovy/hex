"""Stage genuine authored full-body idle sprites; never invent animation frames.

All eight views share one character scale and one feet pivot. Head/costume/limbs
remain the same authored artwork. No head grafts, anatomical repainting or
per-facing rescale is used in this separate acceptance lane.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
spec = importlib.util.spec_from_file_location("cast_components", HERE / "build.py")
components = importlib.util.module_from_spec(spec)
spec.loader.exec_module(components)
DIRECTIONS, CELL, PIVOT = components.DIRECTIONS, components.CELL, components.PIVOT
HEIGHTS = {"small": 58, "middle": 63, "large": 68}
require, sha, write_json = components.require, components.sha, components.write_json


def load_recipe(path, character):
    path = Path(path).resolve()
    config = components.read_json(path)
    require(config.get("schema_version") == 1, "Full-body recipe schema_version must be 1")
    require(config.get("character_id") == character["id"], "Full-body recipe character mismatch")
    require(config.get("directions") == list(DIRECTIONS), "Eight authored directions required")
    height = config.get("reference_body_height")
    require(components.finite_number(height) and height > 0, "Measured reference_body_height required")
    parts, provenance = components.load_parts(path, {**config, "parts": config["body_parts"]}, ("ground_anchor",))
    for direction in DIRECTIONS:
        source_bounds = provenance["parts"][direction]["alpha_bounds"]
        require(abs(config["body_parts"][direction]["ground_anchor"][1]-source_bounds[3]) <= 1,
                f"Ground anchor must identify source feet baseline: {direction}")
    # The scale calibration must describe the visible front-body source, not a
    # separately chosen arbitrary number to conceal a different character size.
    front = provenance["parts"]["S"]["alpha_bounds"]
    require(abs(height-(front[3]-front[1])) <= 2, "Reference body height must match measured front opaque height")
    identity = hashlib.sha256("".join(provenance["parts"][d]["rgba_sha256"] for d in DIRECTIONS).encode()).hexdigest()
    return config, parts, {"recipe_sha256": sha(path), "source": provenance, "identity_fingerprint": identity}


def validate_cell(cell):
    require(cell.mode == "RGBA" and cell.size == CELL, "Invalid full-body cell")
    alpha = cell.getchannel("A")
    bounds = alpha.getbbox()
    require(bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 96 and 82 <= bounds[3] <= 84,
            f"Full-body clipping or feet registration failure: {bounds}")
    require(sum(alpha.histogram()[1:255]) == 0, "Full-body alpha must be binary")
    return list(bounds)


def assemble_parts(config, parts, character):
    scale = HEIGHTS[character["size"]] / config["reference_body_height"]
    require(0 < scale <= 4, "Unsafe source scale")
    cells, measurements = {}, {}
    for direction in DIRECTIONS:
        part = parts[direction]
        anchor = config["body_parts"][direction]["ground_anchor"]
        target_size = (max(1, round(part.width*scale)), max(1, round(part.height*scale)))
        resized = part.resize(target_size, Image.Resampling.NEAREST)
        offset = (PIVOT[0]-round(anchor[0]*scale), PIVOT[1]-round(anchor[1]*scale))
        opaque = resized.getchannel("A").getbbox()
        require(opaque, f"Scale erased authored view: {character['id']}/{direction}")
        placed = (opaque[0]+offset[0], opaque[1]+offset[1], opaque[2]+offset[0], opaque[3]+offset[1])
        # Nearest-neighbour image extent and separately rounded anchor can
        # disagree by one pixel. Register that raster rounding error only; no
        # direction-dependent resize, distortion or artistic repositioning.
        baseline_correction = PIVOT[1]-placed[3]
        require(abs(baseline_correction) <= 1, f"Inconsistent feet anchor: {character['id']}/{direction}")
        offset = (offset[0], offset[1]+baseline_correction)
        placed = (placed[0], placed[1]+baseline_correction, placed[2], placed[3]+baseline_correction)
        require(placed[0] > 0 and placed[1] > 0 and placed[2] < 96 and 82 <= placed[3] <= 84,
                f"Authored view needs source/calibration correction, not clipping: {character['id']}/{direction} {placed}")
        cell = Image.new("RGBA", CELL)
        cell.alpha_composite(resized, offset)
        bounds = validate_cell(cell)
        cells[direction] = cell
        measurements[direction] = {"bounds": bounds, "source_crop_size": list(part.size),
                                   "resized_crop_size": list(target_size), "offset": list(offset),
                                   "baseline_rounding_correction": baseline_correction,
                                   "opaque_pixels": sum(v > 0 for v in cell.getchannel("A").getdata())}
    return cells, {"uniform_scale": scale, "target_front_height": HEIGHTS[character["size"]],
                   "facings": measurements, "scale_policy": "one_uniform_character_scale_all_eight_authored_views"}


def preflight(catalog_path, ids=None):
    path = Path(catalog_path).resolve()
    catalog = components.load_catalog(path)
    results, fingerprints, errors = {}, {}, []
    for character in components.selected_characters(catalog, ids):
        try:
            recipe_name = character.get("fullbody_recipe")
            require(recipe_name, f"Missing fullbody_recipe: {character['id']}")
            recipe = (path.parent / recipe_name).resolve()
            config, parts, provenance = load_recipe(recipe, character)
            _, geometry = assemble_parts(config, parts, character)
            fingerprint = provenance["identity_fingerprint"]
            require(fingerprint not in fingerprints, f"Duplicate complete named full-body artwork: {fingerprints.get(fingerprint)}")
            fingerprints[fingerprint] = character["id"]
            results[character["id"]] = {"recipe": str(recipe), "provenance": provenance, "geometry": geometry}
        except (KeyError, ValueError, OSError) as exc:
            errors.append(f"{character['id']}: {exc}")
    require(not errors, "Full-body preflight blocked; no output written:\n" + "\n".join(errors))
    return catalog, results


def build(catalog_path, output, ids=None):
    catalog_path = Path(catalog_path).resolve()
    catalog, sources = preflight(catalog_path, ids)
    selected = components.selected_characters(catalog, ids)
    out = components.safe_output(output)
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    manifest = {"schema_version": 1, "factory": "character_fullbody_v1", "cell": list(CELL), "pivot": list(PIVOT),
                "directions": list(DIRECTIONS), "animation_status": "idle_only", "production_ready": False,
                "human_approved": False, "runtime_verified": False, "characters": [],
                "provenance": {"builder_sha256": sha(__file__), "component_helpers_sha256": sha(components.__file__),
                               "catalog_sha256": sha(catalog_path)},
                "limits": ["Eight static authored full-body views per named character; no movement animation coverage.",
                           "Directional style, perspective and anatomy require human review before runtime promotion.",
                           "Shared volume skeleton implementation is separate; these images do not prove rig compatibility."]}
    front = Image.new("RGB", (5*224, math.ceil(len(selected)/5)*232+40), "#ddcaa4")
    front_draw = ImageDraw.Draw(front)
    front_draw.text((12, 12), "H.E.X. / AUTHORED FULL BODY / EIGHT-DIRECTION IDLE CANDIDATES", fill="#2b2530")
    directions = Image.new("RGB", (180+8*96, len(selected)*112+36), "#282735")
    direction_draw = ImageDraw.Draw(directions)
    for col, direction in enumerate(DIRECTIONS):
        direction_draw.text((180+col*96+42, 10), direction, fill="#f0d3a0")
    for index, character in enumerate(selected):
        recipe = Path(sources[character["id"]]["recipe"])
        config, parts, provenance = load_recipe(recipe, character)
        cells, geometry = assemble_parts(config, parts, character)
        atlas = Image.new("RGBA", (768,96))
        frames = []
        for col, direction in enumerate(DIRECTIONS):
            cell = cells[direction]
            atlas.paste(cell, (col*96,0))
            frames.append({"direction": direction, "rect": [col*96,0,96,96],
                           "rgba_sha256": components.factory.rgba_sha(cell), "bounds": validate_cell(cell)})
            directions.paste(cell, (180+col*96,index*112+32), cell)
        name = character.get("display_name", character["id"])
        direction_draw.text((8,index*112+58), name, fill="#f0d3a0")
        direction_draw.text((8,index*112+73), f"{character['race']} / {character['size']}", fill="#c9b9a7")
        x, y = (index % 5)*224, (index // 5)*232+40
        enlarged = cells["S"].resize((192,192), Image.Resampling.NEAREST)
        front.paste(enlarged, (x+16,y), enlarged)
        front_draw.text((x+10,y+192), name, fill="#2b2530")
        front_draw.text((x+10,y+208), f"{character['race']} / {character['size']}", fill="#4e463b")
        atlas_path = out / f"{character['id']}.png"
        atlas.save(atlas_path)
        manifest["characters"].append({"id": character["id"], "display_name": name, "race": character["race"],
            "body": character["size"], "appearance": character.get("appearance", "unspecified"),
            "atlas": atlas_path.name, "atlas_sha256": sha(atlas_path), "frames": frames,
            "geometry": geometry, "provenance": provenance, "visual_holds": config.get("visual_holds", [])})
        print(f"Staged full body {character['id']}: 8 authored static directions", flush=True)
    front.save(out / "fullbody-roster.png")
    directions.save(out / "fullbody-directions.png")
    write_json(out / "manifest.json", manifest)
    receipt = check(out)
    write_json(out / "receipt.json", receipt)
    return receipt


def check(output):
    out = Path(output).resolve()
    manifest = components.read_json(out / "manifest.json")
    require(manifest.get("factory") == "character_fullbody_v1" and manifest.get("schema_version") == 1, "Wrong candidate schema")
    require(manifest.get("cell") == list(CELL) and manifest.get("pivot") == list(PIVOT), "Cell/pivot mismatch")
    require(manifest.get("directions") == list(DIRECTIONS) and manifest.get("animation_status") == "idle_only", "Not static eight-direction candidate")
    require(all(manifest.get(key) is False for key in ("production_ready", "human_approved", "runtime_verified")), "Approval cannot be inferred")
    seen = set()
    for character in manifest["characters"]:
        require(components.safe_id(character["id"]) and character["id"] not in seen, "Invalid/duplicate character identity")
        seen.add(character["id"])
        require(character["body"] in HEIGHTS, "Invalid character size")
        atlas_path = components.contained_file(out, character["atlas"])
        require(sha(atlas_path) == character["atlas_sha256"], "Atlas hash mismatch")
        require([f["direction"] for f in character["frames"]] == list(DIRECTIONS), "Missing/duplicate directional frame")
        with Image.open(atlas_path) as atlas:
            require(atlas.mode == "RGBA" and atlas.size == (768,96), "Invalid full-body atlas format")
            for index, frame in enumerate(character["frames"]):
                require(frame["rect"] == [index*96,0,96,96], "Directional cell rect mismatch")
                cell = atlas.crop((index*96,0,(index+1)*96,96))
                require(components.factory.rgba_sha(cell) == frame["rgba_sha256"], "Decoded cell hash mismatch")
                require(validate_cell(cell) == frame["bounds"], "Cell registration mismatch")
    require(seen, "Empty character candidate")
    return {"status": "technical_pass_not_visual_or_runtime_acceptance", "characters": len(seen),
            "authored_idle_directions": len(seen)*8, "movement_animation_frames": 0,
            "maximum_single_atlas_rgba_bytes": 768*96*4, "production_ready": False,
            "human_approved": False, "runtime_verified": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("preflight", "build", "check"))
    parser.add_argument("--catalog", default=str(HERE / "catalog.json"))
    parser.add_argument("--out")
    parser.add_argument("--characters", nargs="*")
    args = parser.parse_args()
    if args.command == "preflight":
        _, result = preflight(args.catalog, args.characters)
        result = {"status": "fullbody_sources_pass", "characters": len(result)}
    else:
        require(args.out, "--out is required")
        result = check(args.out) if args.command == "check" else build(args.catalog, args.out, args.characters)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
