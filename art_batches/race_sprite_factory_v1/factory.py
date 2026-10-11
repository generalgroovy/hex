"""Staged raster-head / existing-rig candidate factory. Never promotes assets.

All raster identity comes from supplied PNG art. Pillow only crops, nearest-
neighbour scales, and composites it. Body skinning is the existing renderer's
headless prefix with an isolated material palette, not a new anatomy generator.
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
RIG_DIR = REPO / "art_batches/character_style_v1/wireframe_motion_v2"
BODIES = ("small", "middle", "large")
GENDERS = ("neutral", "masculine", "feminine")
DIRECTIONS = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
CELL = (96, 96)
PIVOT = (48, 84)
DISPLAY_HEIGHTS = {"small": 58, "middle": 63, "large": 68}
MOTION_REVISION = "slide_v1"
SEAKIN_PALETTE = {
    "outline": "#142332", "shade": "#183044", "dark": "#20465a",
    "mid": "#28617b", "light": "#438a9c", "leather": "#1b354c",
    "leather_light": "#366376", "gold_dark": "#947344", "gold": "#ceb877",
    "gold_light": "#f1dc9a", "skin_dark": "#357f8d", "skin": "#69b8bc",
    "skin_light": "#a7e2da", "hair": "#173b4e", "hair_light": "#448899",
    "eye": "#102530",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rgba_sha(image):
    return hashlib.sha256(image.tobytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_renderer(palette=None, torso_overlay=None):
    """Compile only the pre-head statements; source files and globals stay intact."""
    path = RIG_DIR / "build.py"
    spec = importlib.util.spec_from_file_location("race_source_motion", path)
    renderer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(renderer)
    tree = ast.parse(path.read_text(encoding="utf-8"))
    fn = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "render")
    cuts = [i for i, node in enumerate(fn.body)
            if isinstance(node, ast.Assign) and isinstance(node.value, ast.Call)
            and isinstance(node.value.func, ast.Name) and node.value.func.id == "head_bounds"]
    require(len(cuts) == 1, "Body adapter contract changed: expected one head_bounds call")
    fn = copy.deepcopy(fn)
    fn.name = "render_headless"
    fn.body = fn.body[:cuts[0]] + ast.parse(
        "canvas.paste((0, 0, 0, 0), (0, 84, 96, 96))\nreturn canvas").body
    if torso_overlay is not None:
        # Replace only the existing coat/torso block between rear and near limbs.
        loops = [i for i, node in enumerate(fn.body) if isinstance(node, ast.For)
                 and isinstance(node.target, ast.Name) and node.target.id == "part"]
        require(len(loops) == 2, "Torso adapter contract changed: expected rear/near limb loops")
        require(any(isinstance(node, ast.Gt) for node in ast.walk(fn.body[loops[1]])),
                "Torso adapter requires verified near-depth comparator")
        near_loop = fn.body[loops[1]]
        near_if = near_loop.body[0]
        require(isinstance(near_if, ast.If), "Near limb loop contract changed")
        near_if.test = ast.BoolOp(op=ast.And(), values=[near_if.test,
            ast.parse("part['kind'] == 'arm'", mode="eval").body])
        fn.body[loops[0]+1:loops[1]] = ast.parse(
            "for part in pose['chains']:\n"
            "    if part['depth'] > pose['torso_depth'] and part['kind'] == 'leg':\n"
            "        chain(part)\n"
            "_torso_overlay(canvas, pose, data, gender)").body
        fn.body = [node for node in fn.body if not (isinstance(node, ast.For)
                   and isinstance(node.target, ast.Name) and node.target.id == "shoulder")]
    fn.args.args.append(ast.arg(arg="gender"))
    fn.args.defaults.append(ast.Constant(value="neutral"))
    namespace = dict(vars(renderer))
    namespace["CLOTH"] = dict(renderer.CLOTH)
    namespace["CLOTH"].update(palette or SEAKIN_PALETTE)
    namespace["_torso_overlay"] = torso_overlay
    # cloth_segment reads module globals too: clone it into this isolated palette.
    helper = copy.deepcopy(next(node for node in tree.body
        if isinstance(node, ast.FunctionDef) and node.name == "cloth_segment"))
    module = ast.fix_missing_locations(ast.Module(body=[helper, fn], type_ignores=[]))
    exec(compile(module, str(path) + ":headless-adapter", "exec"), namespace)
    return renderer, namespace["render_headless"]


def pose_key(pose):
    if pose["state"] in ("locomotion", "sprint_locomotion"):
        return f'{pose["state"]}/{pose["travel"]}/{pose["aim"]}/{pose["phase"]}'
    return f'{pose["state"]}/{pose["aim"]}'


def validate_rig(data, verify_source=True):
    require(data.get("motion_revision") == MOTION_REVISION, "Unexpected motion revision")
    require(data["cell"] == list(CELL) and data["pivot"] == list(PIVOT), "Rig cell/pivot mismatch")
    require(len(data["base_rows"]) == 10 and data["phases"] == 8, "Rig action/phase mismatch")
    if verify_source:
        require(sha(REPO / data["rig_source"].removeprefix("res://")) == data["rig_sha256"], "Rig source hash mismatch")
    counts = {}
    for body in BODIES:
        poses = [p for p in data["poses"] if p["body"] == body]
        indexed = {pose_key(p): p for p in poses}
        expected = {f"{state}/{aim}" for state in data["base_rows"] for aim in range(8)}
        expected |= {f"{state}/{travel}/{aim}/{phase}" for state in ("locomotion", "sprint_locomotion")
                     for travel in range(8) for aim in range(8) for phase in range(8)}
        require(len(indexed) == len(poses) == 1104 and set(indexed) == expected, f"Incomplete/duplicate frame bank: {body}")
        for pose in poses:
            for side in ("l", "r"):
                for start, end, bone in (("hip", "knee", "thigh"), ("knee", "ankle", "shin"),
                                         ("ankle", "toe", "foot"), ("shoulder", "elbow", "humerus"),
                                         ("elbow", "hand", "forearm")):
                    require(abs(math.dist(pose["landmarks"][start+"_"+side], pose["landmarks"][end+"_"+side])
                                - data["bone_lengths"][bone]) < .00001, "Changed bone lengths")
            if pose["state"] in ("locomotion", "sprint_locomotion"):
                require(pose["waist_yaw_twist_degrees"] == 0, "Unexpected waist twist")
                land = pose["landmarks"]
                require(min(land["ankle_l"][2], land["ankle_r"][2]) < .00001, "Missing support foot")
                require(land["ankle_l"][0] < land["ankle_r"][0], "Crossed feet")
                if pose["phase"] in (2, 6):
                    planted, raised = ("l", "r") if pose["phase"] == 2 else ("r", "l")
                    require(land["ankle_"+planted][2] < .00001 and land["ankle_"+raised][2] > .08,
                            "Alternating support-leg contract broken")
        counts[body] = {"base": 80, "walk": 512, "sprint": 512, "total": len(poses)}
    return counts


def read_config(path, seen=None):
    path = Path(path).resolve()
    seen = set() if seen is None else seen
    require(path not in seen, "Cyclic recipe inheritance")
    seen.add(path)
    config = json.loads(path.read_text(encoding="utf-8"))
    if "extends" in config:
        parent = (path.parent / config["extends"]).resolve()
        require(parent.parent == path.parent, "Inherited recipe must be in the same directory")
        base_config = read_config(parent, seen)
        config = {**base_config, **config}
    return config


def load_recipe(path):
    path = Path(path).resolve()
    config = read_config(path)
    require(config.get("schema_version") == 1, "Recipe schema_version must be 1")
    require(re.fullmatch(r"[a-z][a-z0-9_-]*", config["race_id"]), "Unsafe race_id")
    require(config.get("directions") == list(DIRECTIONS), "Eight authored facings required, S clockwise to SW")
    require(config.get("genders") == list(GENDERS), "Three authored gender rows required")
    source = (path.parent / config["source_png"]).resolve()
    require(source.suffix.lower() == ".png", "Source must be PNG")
    if config.get("source_sha256"):
        require(sha(source) == config["source_sha256"], "Source PNG hash mismatch")
    with Image.open(source) as opened:
        require(opened.format == "PNG" and opened.mode == "RGBA", "Source must have explicit RGBA, not an opaque/checkerboard image")
        image = opened.copy()
    alpha = image.getchannel("A")
    require(alpha.getextrema()[0] == 0 and alpha.getextrema()[1] >= 250,
            "Source needs genuine transparent and near-opaque pixels")
    require(config["reference_head_height"] > 0, "Missing measured reference_head_height")
    threshold = config.get("alpha_threshold", 128)
    require(isinstance(threshold, int) and 1 <= threshold <= 255, "Invalid alpha threshold")
    parts, measurements, rects = {}, {}, []
    for gender in GENDERS:
        for direction in DIRECTIONS:
            key = f"{gender}/{direction}"
            entry = config["heads"][key]
            rect = entry["rect"]
            require(len(rect) == 4 and all(isinstance(n, int) for n in rect), f"Invalid rect: {key}")
            x, y, w, h = rect
            require(w > 0 and h > 0 and x >= 0 and y >= 0 and x+w <= image.width and y+h <= image.height,
                    f"Out-of-image rect: {key}")
            for previous in rects:
                require(x+w <= previous[0] or previous[0]+previous[2] <= x or
                        y+h <= previous[1] or previous[1]+previous[3] <= y, f"Overlapping source rect: {key}")
            rects.append(rect)
            part = image.crop((x, y, x+w, y+h))
            source_channel = part.getchannel("A")
            channel = source_channel.point(lambda a: 255 if a >= threshold else 0)
            box = channel.getbbox()
            require(box and box[0] > 0 and box[1] > 0 and box[2] < w and box[3] < h,
                    f"Empty or clipped cell; measured crop must have transparent border: {key}")
            anchor_kind = "chin_anchor" if "chin_anchor" in entry else "crown_anchor"
            anchor = entry[anchor_kind]
            require(len(anchor) == 2 and 0 <= anchor[0] <= w and 0 <= anchor[1] <= h, f"Bad {anchor_kind}: {key}")
            # Explicit threshold is deterministic; never infer/remove a background color.
            part.putalpha(channel)
            require(part.getchannel("A").getbbox(), f"Threshold emptied head: {key}")
            clean = Image.new("RGBA", part.size)
            clean.paste(part, (0, 0), part.getchannel("A"))
            parts[key] = clean
            measurements[key] = {"rect": rect, anchor_kind: anchor, "source_alpha_bounds": list(box),
                                 "source_alpha_extrema": list(source_channel.getextrema()),
                                 "thresholded_rgba_sha256": rgba_sha(clean)}
    return config, source, parts, measurements


def prepare_heads(config, parts, renderer, data):
    """One uniform scale per body, shared by every direction, gender and action."""
    prepared, scales = {}, {}
    for body in BODIES:
        pose = next(p for p in data["poses"] if p["body"] == body and p["state"] == "grounded" and p["aim"] == 0)
        bounds = renderer.head_bounds(pose, data)
        scale = (bounds[3]-bounds[1]+1) / config["reference_head_height"]
        scales[body] = scale
        for key, part in parts.items():
            size = (max(1, round(part.width*scale)), max(1, round(part.height*scale)))
            entry = config["heads"][key]
            anchor = entry.get("chin_anchor", entry.get("crown_anchor"))
            prepared[(body, key)] = (part.resize(size, Image.Resampling.NEAREST),
                                      (round(anchor[0]*scale), round(anchor[1]*scale)),
                                      "chin" if "chin_anchor" in entry else "crown")
    return prepared, scales


def torso_affine(source_neck, source_pelvis, target_neck, target_pelvis, transverse_scale):
    """Source→screen matrix with exact rig anchors and positive handedness.

    Longitudinal deformation is projected bone foreshortening, never an alpha-
    bounds fit. Transverse calibration is fixed at the same-facing standing pose.
    """
    sx, sy = source_pelvis[0]-source_neck[0], source_pelvis[1]-source_neck[1]
    tx, ty = target_pelvis[0]-target_neck[0], target_pelvis[1]-target_neck[1]
    sl, tl = math.hypot(sx, sy), math.hypot(tx, ty)
    require(sl > 1 and sy > 0 and tl > .01 and transverse_scale > 0, "Degenerate or inverted torso anchors")
    sc, sn, tc, tn = (sy/sl, -sx/sl), (sx/sl, sy/sl), (ty/tl, -tx/tl), (tx/tl, ty/tl)
    longitudinal_scale = tl/sl
    a = transverse_scale*tc[0]*sc[0]+longitudinal_scale*tn[0]*sn[0]
    b = transverse_scale*tc[0]*sc[1]+longitudinal_scale*tn[0]*sn[1]
    d = transverse_scale*tc[1]*sc[0]+longitudinal_scale*tn[1]*sn[0]
    e = transverse_scale*tc[1]*sc[1]+longitudinal_scale*tn[1]*sn[1]
    c = target_neck[0]-a*source_neck[0]-b*source_neck[1]
    f = target_neck[1]-d*source_neck[0]-e*source_neck[1]
    determinant = a*e-b*d
    require(determinant > 0, "Reflected torso transform")
    for source, target in ((source_neck, target_neck), (source_pelvis, target_pelvis)):
        require(math.dist((a*source[0]+b*source[1]+c, d*source[0]+e*source[1]+f), target) < .00001,
                "Torso anchor mismatch")
    inverse = (e/determinant, -b/determinant, (b*f-e*c)/determinant,
               -d/determinant, a/determinant, (d*c-a*f)/determinant)
    return inverse, {"determinant": determinant, "longitudinal_scale": longitudinal_scale,
                     "transverse_scale": transverse_scale, "projected_anchor_span": tl,
                     "in_plane_lean_degrees": math.degrees(math.atan2(tx, ty))}


def prepare_torsos(recipe, config, renderer, data):
    if "torso" not in config:
        return None, None
    spec = config["torso"]
    source = (Path(recipe).resolve().parent / spec["source_png"]).resolve()
    if spec.get("source_sha256"):
        require(sha(source) == spec["source_sha256"], "Torso source hash mismatch")
    with Image.open(source) as opened:
        require(opened.format == "PNG" and opened.mode == "RGBA", "Torso source must be RGBA PNG")
        source_image = opened.copy()
    require(source_image.getchannel("A").getextrema()[0] == 0, "Torso source has no transparency")
    threshold = spec.get("alpha_threshold", 127)
    require(isinstance(threshold, int) and 1 <= threshold <= 255, "Invalid torso alpha threshold")
    parts, scales, measurements, rects = {}, {}, {}, []
    for gender in GENDERS:
        for aim, direction in enumerate(DIRECTIONS):
            key = f"{gender}/{direction}"
            entry = spec["parts"][key]
            x, y, w, h = entry["rect"]
            require(all(isinstance(v, int) for v in (x, y, w, h)) and x >= 0 and y >= 0 and w > 0 and h > 0
                    and x+w <= source_image.width and y+h <= source_image.height, f"Invalid torso rect: {key}")
            for rx, ry, rw, rh in rects:
                require(x+w <= rx or rx+rw <= x or y+h <= ry or ry+rh <= y, f"Overlapping torso rect: {key}")
            rects.append((x, y, w, h))
            part = source_image.crop((x, y, x+w, y+h))
            part.putalpha(part.getchannel("A").point(lambda value: 255 if value >= threshold else 0))
            box = part.getchannel("A").getbbox()
            require(box and box[0] > 0 and box[1] > 0 and box[2] < w and box[3] < h, f"Clipped torso crop: {key}")
            for anchor in ("neck_anchor", "pelvis_anchor"):
                p = entry[anchor]
                require(len(p) == 2 and 0 <= p[0] <= w and 0 <= p[1] <= h, f"Invalid torso {anchor}: {key}")
            parts[key] = part
            measurements[key] = entry
            for body in BODIES:
                standing = next(p for p in data["poses"] if p["body"] == body and p["state"] == "grounded" and p["aim"] == aim)
                target_span = math.dist(renderer.display_point(standing["points"]["neck"], body),
                                        renderer.display_point(standing["points"]["pelvis"], body))
                source_span = math.dist(entry["neck_anchor"], entry["pelvis_anchor"])
                require(source_span > 1, "Invalid torso calibration span")
                scales[(body, key)] = target_span/source_span
    _, fallback_body = load_renderer(config.get("palette", SEAKIN_PALETTE))
    stats = {"source_png_sha256": sha(source), "alpha_threshold": threshold, "measurements": measurements,
             "skin_policy": "projected_neck_pelvis_affine_fixed_standing_transverse_scale",
             "original_coat_mesh_suppressed": True, "near_limbs_above_torso": True,
             "minimum_determinant": float("inf"), "maximum_anchor_span": 0.0,
             "held_states": spec.get("held_states", []), "held_pose_fallbacks": {}, "visual_approval": False}

    def overlay(canvas, pose, rig, gender):
        key = f"{gender}/{DIRECTIONS[pose['aim']]}"
        entry = spec["parts"][key]
        body = pose["body"]
        neck = renderer.display_point(pose["points"]["neck"], body)
        pelvis = renderer.display_point(pose["points"]["pelvis"], body)
        # Overscan verifies actual opaque pixels before cropping back to the cell.
        inverse, diagnostics = torso_affine(entry["neck_anchor"], entry["pelvis_anchor"],
            (neck[0]+48, neck[1]+48), (pelvis[0]+48, pelvis[1]+48), scales[(body, key)])
        layer = parts[key].transform((192, 192), Image.Transform.AFFINE, inverse,
                                    resample=Image.Resampling.NEAREST)
        box = layer.getchannel("A").getbbox()
        inside = box and box[0] > 48 and box[1] > 48 and box[2] < 144 and box[3] <= 132
        if not inside and pose["state"] in stats["held_states"]:
            stats["held_pose_fallbacks"][f"{body}/{gender}/{pose_key(pose)}"] = {
                "reason": "projected_raster_hem_crosses_ground_or_cell_boundary",
                "attempted_overscan_bounds": list(box) if box else None,
                "fallback": "original_headless_geometric_body"}
            canvas.paste(fallback_body(pose, rig, gender), (0, 0))
            return
        require(inside, f"Torso skin clips cell/ground: {body}/{gender}/{pose_key(pose)} {box}")
        stats["minimum_determinant"] = min(stats["minimum_determinant"], diagnostics["determinant"])
        stats["maximum_anchor_span"] = max(stats["maximum_anchor_span"], diagnostics["projected_anchor_span"])
        canvas.alpha_composite(layer.crop((48, 48, 144, 144)))
    return overlay, stats


def assemble(pose, data, gender, renderer, headless, heads, body_cell=None):
    cell = body_cell.copy() if body_cell is not None else headless(pose, data, gender)
    key = f"{gender}/{DIRECTIONS[pose['aim']]}"
    head, anchor, anchor_kind = heads[(pose["body"], key)]
    bounds = renderer.head_bounds(pose, data)
    center_x = renderer.pixel(renderer.display_point(pose["points"]["head"], pose["body"]))[0]
    offset = (center_x-anchor[0], (bounds[3]+1 if anchor_kind == "chin" else bounds[1])-anchor[1])
    opaque = head.getchannel("A").getbbox()
    placed = (opaque[0]+offset[0], opaque[1]+offset[1], opaque[2]+offset[0], opaque[3]+offset[1])
    require(placed[0] > 0 and placed[1] > 0 and placed[2] < 96 and placed[3] < 84,
            f"Head clips cell or ground: {pose['body']}/{gender}/{pose_key(pose)} {placed}")
    cell.alpha_composite(head, offset)
    validate_cell(cell)
    return cell


def validate_cell(cell):
    require(cell.mode == "RGBA" and cell.size == CELL, "Wrong frame mode/cell")
    alpha = cell.getchannel("A")
    box = alpha.getbbox()
    require(box and box[0] > 0 and box[1] > 0 and box[2] < 96 and box[3] == 84,
            f"Frame boundary/pivot failure: {box}")
    histogram = alpha.histogram()
    require(sum(histogram[1:255]) == 0, "Nonbinary candidate alpha")
    return list(box)


def safe_output(path):
    path = Path(path).resolve()
    allowed = ((REPO / ".godot/race-sprite-candidates").resolve(), (HERE / "output").resolve())
    require(any(path.is_relative_to(root) for root in allowed), "Output must remain in staged candidate roots")
    require(not (path / "manifest.json").exists(), "Candidate exists; use a new output directory")
    return path


def make_board(cells, title, background):
    board = Image.new("RGB", (820, 330), background)
    draw = ImageDraw.Draw(board)
    draw.text((10, 8), title, fill="#dbcb9d")
    for aim, direction in enumerate(DIRECTIONS):
        draw.text((54+aim*96, 25), direction, fill="#dbcb9d")
    for row, body in enumerate(BODIES):
        draw.text((2, 77+row*96), body, fill="#dbcb9d")
        for aim in range(8):
            cell = cells[(body, aim)]
            board.paste(cell, (52+aim*96, 38+row*96), cell)
    return board


def inspect(recipe, output=None):
    config, source, parts, measurements = load_recipe(recipe)
    result = {"status": "source_validation_passed_not_visual_approval", "source_sha256": sha(source),
              "source": str(source), "race_id": config["race_id"], "heads": measurements,
              "alpha_policy": f"explicit_threshold_{config.get('alpha_threshold', 128)}", "human_approved": False}
    if output:
        out = safe_output(output)
        out.mkdir(parents=True, exist_ok=True)
        write_json(out / "source-inspection.json", result)
        width = max(part.width for part in parts.values())
        height = max(part.height for part in parts.values())
        board = Image.new("RGB", (width*8, height*3), "#39314c")
        for row, gender in enumerate(GENDERS):
            for col, direction in enumerate(DIRECTIONS):
                part = parts[f"{gender}/{direction}"]
                board.paste(part, (col*width, row*height), part)
        board.save(out / "source-crops.png")
    return result


def sample(recipe, output):
    """Only 72 standing cells; review this before the complete nine-family bake."""
    out = safe_output(output)
    config, source, parts, measurements = load_recipe(recipe)
    data = json.loads((RIG_DIR / "rig-data.json").read_text(encoding="utf-8"))
    validate_rig(data)
    renderer, headless = load_renderer(config.get("palette", SEAKIN_PALETTE))
    torso_overlay, torso_stats = prepare_torsos(recipe, config, renderer, data)
    if torso_overlay:
        renderer, headless = load_renderer(config.get("palette", SEAKIN_PALETTE), torso_overlay)
    heads, scales = prepare_heads(config, parts, renderer, data)
    out.mkdir(parents=True, exist_ok=True)
    for gender in GENDERS:
        cells = {}
        for pose in data["poses"]:
            if pose["state"] == "grounded":
                cells[(pose["body"], pose["aim"])] = assemble(pose, data, gender, renderer, headless, heads)
        for background, color in (("dark", "#242737"), ("light", "#c6c5b8")):
            board = make_board(cells, f"{config['race_id']} / {gender} / SAMPLE - PARTIAL ANATOMY", color)
            board.save(out / f"{gender}-{background}-1x.png")
            board.resize((board.width*4, board.height*4), Image.Resampling.NEAREST).save(out / f"{gender}-{background}-4x.png")
        if torso_overlay:
            for state in ("slide", "roll"):
                cells = {(pose["body"], pose["aim"]): assemble(pose, data, gender, renderer, headless, heads)
                         for pose in data["poses"] if pose["state"] == state}
                board = make_board(cells, f"{config['race_id']} / {gender} / {state} / HELD FOR REVIEW", "#242737")
                board.resize((board.width*4, board.height*4), Image.Resampling.NEAREST).save(out / f"{gender}-{state}-4x.png")
    result = {"status": "standing_sample_only", "frames": 72, "head_scales": scales,
              "source_png_sha256": sha(source), "recipe_sha256": sha(recipe), "human_approved": False,
              "anatomy_complete": False, "source_measurements": measurements}
    if torso_stats:
        result["torso"] = torso_stats
        result["frames"] = 216
        result["status"] = "standing_slide_roll_sample_only"
    write_json(out / "sample-receipt.json", result)
    summary = {k: v for k, v in result.items() if k not in ("source_measurements", "torso")}
    if torso_stats:
        summary["held_pose_fallbacks"] = len(torso_stats["held_pose_fallbacks"])
        summary["minimum_torso_determinant"] = torso_stats["minimum_determinant"]
    return summary


def build(recipe, output):
    out = safe_output(output)
    config, source, parts, measurements = load_recipe(recipe)
    data = json.loads((RIG_DIR / "rig-data.json").read_text(encoding="utf-8"))
    counts = validate_rig(data)
    renderer, headless = load_renderer(config.get("palette", SEAKIN_PALETTE))
    torso_overlay, torso_stats = prepare_torsos(recipe, config, renderer, data)
    if torso_overlay:
        renderer, headless = load_renderer(config.get("palette", SEAKIN_PALETTE), torso_overlay)
    heads, scales = prepare_heads(config, parts, renderer, data)
    out.mkdir(parents=True, exist_ok=True)
    manifest = {"schema_version": 1, "factory": "race_sprite_factory_v1", "race_id": config["race_id"],
                "status": "staged_candidate_pending_human_review", "production_ready": False,
                "human_approved": False, "runtime_verified": False, "cell": list(CELL), "pivot": list(PIVOT),
                "motion_revision": MOTION_REVISION, "directions": list(DIRECTIONS), "base_rows": data["base_rows"],
                "genders": list(GENDERS), "frame_counts_per_variant": counts["small"],
                "scale_policy": "one_uniform_source_scale_per_body_all_facings_actions_genders",
                "head_scales": scales, "source_measurements": measurements,
                "anatomy": {"status": "partial", "tail": "not_authored", "body": "shared_rig_clothing_palette",
                            "race_specific_body_geometry": False, "head": "authored_directional_raster"},
                "limits": ["Head-only gender differentiation; shared body rig and clothing.",
                           "Tail and other race-specific body anatomy are not authored.",
                           "Eight authored facing crops, not rotations of a front view.",
                           "Visual style and directional correctness need human review.",
                           "Candidate is not promoted to production assets or presenters."],
                "provenance": {"source_png_sha256": sha(source), "recipe_sha256": sha(recipe),
                               "factory_sha256": sha(__file__), "rig_data_sha256": sha(RIG_DIR / "rig-data.json"),
                               "body_renderer_sha256": sha(RIG_DIR / "build.py"),
                               "base_renderer_sha256": sha(RIG_DIR.parent / "wireframe_base_v1/build.py"),
                               "rig_source_sha256": data["rig_sha256"]}, "variants": {}}
    manifest["visual_holds"] = config.get("visual_holds", [])
    manifest["preview_residency_policy"] = "load_one_family_atlas_and_frame_index_at_a_time"
    if torso_stats:
        manifest["anatomy"]["body"] = "authored_directional_torso_shared_rig_limbs"
        manifest["anatomy"]["gender_differentiation"] = "authored_head_and_torso_shared_limbs"
        manifest["limits"][0] = "Head and torso gender differentiation; shared limb rig and geometric boots/gloves."
        manifest["provenance"]["torso_source_png_sha256"] = torso_stats["source_png_sha256"]
        manifest["torso"] = torso_stats
        if "extends" in config:
            manifest["provenance"]["base_recipe_sha256"] = sha(Path(recipe).resolve().parent / config["extends"])
    grounding = {gender: {} for gender in GENDERS}
    examples = {}
    for body in BODIES:
        poses = [p for p in data["poses"] if p["body"] == body]
        # At most one body bank retained; frame records never contain image data.
        body_cells = None if torso_overlay else [headless(pose, data) for pose in poses]
        for gender in GENDERS:
            name = f"{config['race_id']}-{body}-{gender}"
            records, seen, unique = [], {}, []
            phase_hashes = {}
            for pose, body_cell in zip(poses, body_cells if body_cells is not None else [None]*len(poses)):
                cell = assemble(pose, data, gender, renderer, headless, heads, body_cell)
                digest = rgba_sha(cell)
                if digest not in seen:
                    seen[digest] = len(unique)
                    unique.append(cell)
                record = {"key": pose_key(pose), "state": pose["state"], "aim": pose["aim"],
                          "atlas_index": seen[digest], "rgba_sha256": digest, "bounds": validate_cell(cell)}
                if torso_stats:
                    full_key = f"{body}/{gender}/{pose_key(pose)}"
                    record["torso_layer"] = "held_geometric_fallback" if full_key in torso_stats["held_pose_fallbacks"] else "authored_affine"
                    record["torso_visual_review_held"] = pose["state"] in torso_stats["held_states"]
                if pose["state"] in ("locomotion", "sprint_locomotion"):
                    record.update(travel=pose["travel"], phase=pose["phase"])
                    record["support_legs"] = [side for side in ("l", "r") if pose["landmarks"]["ankle_"+side][2] < .00001]
                    phase_hashes.setdefault((pose["state"], pose["travel"], pose["aim"]), []).append(digest)
                    if pose["aim"] == 2 and pose["travel"] in (0, 2, 6) and body == "middle":
                        examples[(gender, pose["state"], pose["travel"], pose["phase"])] = cell
                if pose["state"] == "grounded":
                    grounding[gender][(body, pose["aim"])] = cell
                records.append(record)
            require(all(len(set(hashes)) == 8 for hashes in phase_hashes.values()), f"Lost gait phases: {name}")
            index = {r["key"]: r for r in records}
            require(all(index[f"locomotion/{t}/{a}/{p}"]["rgba_sha256"] != index[f"sprint_locomotion/{t}/{a}/{p}"]["rgba_sha256"]
                        for t in range(8) for a in range(8) for p in range(8)), "Sprint bank duplicates walk")
            columns = 16
            atlas = Image.new("RGBA", (96*columns, 96*math.ceil(len(unique)/columns)))
            for i, cell in enumerate(unique):
                atlas.paste(cell, ((i % columns)*96, (i // columns)*96))
            atlas_path = out / f"{name}.png"
            atlas.save(atlas_path, optimize=False)
            frame_path = out / f"{name}.frames.json"
            write_json(frame_path, records)
            manifest["variants"][f"{body}/{gender}"] = {"body": body, "gender": gender,
                "display_height": DISPLAY_HEIGHTS[body], "atlas": atlas_path.name, "frames": frame_path.name,
                "atlas_columns": columns, "atlas_dimensions": list(atlas.size), "unique_frames": len(unique),
                "logical_frames": len(records), "atlas_sha256": sha(atlas_path), "frames_sha256": sha(frame_path),
                "atlas_file_bytes": atlas_path.stat().st_size, "frame_index_file_bytes": frame_path.stat().st_size,
                "atlas_uncompressed_rgba_bytes": atlas.width*atlas.height*4}
            print(f"Built {name}: {len(records)} logical / {len(unique)} unique", flush=True)
    for gender in GENDERS:
        for background, color in (("dark", "#242737"), ("light", "#c6c5b8")):
            board = make_board(grounding[gender], f"{config['race_id']} / {gender} / STAGED - TAIL NOT AUTHORED", color)
            board.save(out / f"{gender}-{background}-1x.png")
            board.resize((board.width*4, board.height*4), Image.Resampling.NEAREST).save(out / f"{gender}-{background}-4x.png")
    for gender in GENDERS:
        frames = []
        for phase in range(8):
            frame = Image.new("RGB", (3*192, 2*220), "#242737")
            draw = ImageDraw.Draw(frame)
            for row, state in enumerate(("locomotion", "sprint_locomotion")):
                for col, travel in enumerate((2, 0, 6)):
                    cell = examples[(gender, state, travel, phase)].resize((192, 192), Image.Resampling.NEAREST)
                    frame.paste(cell, (col*192, row*220+25), cell)
                    draw.text((col*192+5, row*220+5), f"{state} {DIRECTIONS[travel]} / aim E", fill="#dbcb9d")
            frames.append(frame)
        frames[0].save(out / f"{gender}-motion.gif", save_all=True, append_images=frames[1:], duration=100, loop=0, disposal=2)
    write_json(out / "manifest.json", manifest)
    receipt = check(out)
    write_json(out / "receipt.json", receipt)
    return receipt


def preflight(recipe, output):
    """Exhaust every assembled pose in memory; no atlas or production export."""
    out = safe_output(output)
    config, source, parts, _ = load_recipe(recipe)
    data = json.loads((RIG_DIR / "rig-data.json").read_text(encoding="utf-8"))
    validate_rig(data)
    renderer, headless = load_renderer(config.get("palette", SEAKIN_PALETTE))
    torso_overlay, torso_stats = prepare_torsos(recipe, config, renderer, data)
    if torso_overlay:
        renderer, headless = load_renderer(config.get("palette", SEAKIN_PALETTE), torso_overlay)
    heads, scales = prepare_heads(config, parts, renderer, data)
    families = {}
    for body in BODIES:
        poses = [p for p in data["poses"] if p["body"] == body]
        for gender in GENDERS:
            hashes, phase_hashes, bounds = {}, {}, []
            for pose in poses:
                cell = assemble(pose, data, gender, renderer, headless, heads)
                digest = rgba_sha(cell)
                hashes[pose_key(pose)] = digest
                bounds.append(validate_cell(cell))
                if pose["state"] in ("locomotion", "sprint_locomotion"):
                    phase_hashes.setdefault((pose["state"], pose["travel"], pose["aim"]), []).append(digest)
            require(len(hashes) == 1104, "Incomplete in-memory family")
            require(all(len(set(values)) == 8 for values in phase_hashes.values()), "Occluded gait phase in preflight")
            require(all(hashes[f"locomotion/{t}/{a}/{p}"] != hashes[f"sprint_locomotion/{t}/{a}/{p}"]
                        for t in range(8) for a in range(8) for p in range(8)), "Walk/sprint collision in preflight")
            families[f"{body}/{gender}"] = {"frames": len(hashes), "unique_frames": len(set(hashes.values())),
                "minimum_alpha_top": min(b[1] for b in bounds), "maximum_alpha_bottom": max(b[3] for b in bounds),
                "eight_distinct_phases_per_pair": True, "walk_sprint_distinct": True}
            print(f"Preflight {body}/{gender}: {len(hashes)} frames", flush=True)
    result = {"status": "PASS_in_memory_frame_geometry_only", "families": families,
        "logical_frames": sum(v["frames"] for v in families.values()), "cell": list(CELL), "pivot": list(PIVOT),
        "binary_alpha": True, "motion_revision": MOTION_REVISION, "head_scales": scales,
        "source_png_sha256": sha(source), "recipe_sha256": sha(recipe), "factory_sha256": sha(__file__),
        "rig_data_sha256": sha(RIG_DIR / "rig-data.json"), "human_approved": False,
        "runtime_verified": False, "production_ready": False, "anatomy_complete": False}
    if torso_stats:
        result["torso"] = torso_stats
    out.mkdir(parents=True, exist_ok=True)
    write_json(out / "preflight-receipt.json", result)
    return {"status": result["status"], "logical_frames": result["logical_frames"],
            "held_pose_fallbacks": len(torso_stats["held_pose_fallbacks"]) if torso_stats else 0,
            "human_approved": False, "runtime_verified": False, "production_ready": False}


def check(output):
    out = Path(output).resolve()
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    require(manifest["production_ready"] is False and manifest["human_approved"] is False, "Unapproved promotion flag")
    require(manifest["motion_revision"] == MOTION_REVISION and manifest["pivot"] == list(PIVOT), "Manifest contract mismatch")
    require(set(manifest["variants"]) == {f"{body}/{gender}" for body in BODIES for gender in GENDERS}, "Missing variants")
    total, unique_total = 0, 0
    for name, variant in manifest["variants"].items():
        atlas_path, frames_path = out / variant["atlas"], out / variant["frames"]
        require(sha(atlas_path) == variant["atlas_sha256"] and sha(frames_path) == variant["frames_sha256"], f"Output hash mismatch: {name}")
        with Image.open(atlas_path) as opened:
            require(opened.mode == "RGBA", "Atlas must be RGBA")
            atlas = opened.copy()
        records = json.loads(frames_path.read_text(encoding="utf-8"))
        require(len(records) == 1104 and len({r["key"] for r in records}) == 1104, "Logical frame count mismatch")
        expected = {f"{state}/{aim}" for state in manifest["base_rows"] for aim in range(8)}
        expected |= {f"{state}/{travel}/{aim}/{phase}" for state in ("locomotion", "sprint_locomotion")
                     for travel in range(8) for aim in range(8) for phase in range(8)}
        require({r["key"] for r in records} == expected, "Logical action/direction/phase coverage mismatch")
        require(list(atlas.size) == variant["atlas_dimensions"], "Atlas dimensions changed")
        for record in records:
            i, columns = record["atlas_index"], variant["atlas_columns"]
            require(0 <= i < variant["unique_frames"], "Bad atlas index")
            x, y = i % columns * 96, i // columns * 96
            cell = atlas.crop((x, y, x+96, y+96))
            require(rgba_sha(cell) == record["rgba_sha256"], "Frame pixel hash mismatch")
            require(validate_cell(cell) == record["bounds"], "Frame bounds changed")
        total += len(records)
        unique_total += variant["unique_frames"]
    receipt = {"status": "PASS_candidate_integrity_only", "variants": 9, "logical_frames": total,
            "unique_frames": unique_total, "binary_alpha": True, "pivot": list(PIVOT),
            "motion_revision": MOTION_REVISION, "human_approved": False, "production_ready": False,
            "runtime_verified": False, "anatomy_complete": False}
    if "torso" in manifest:
        receipt["authored_torso_present"] = True
        receipt["held_pose_fallbacks"] = len(manifest["torso"]["held_pose_fallbacks"])
        receipt["held_states"] = manifest["torso"]["held_states"]
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("inspect", "sample", "preflight", "build"):
        child = sub.add_parser(command)
        child.add_argument("--recipe", type=Path, required=True)
        child.add_argument("--out", type=Path, required=command != "inspect")
    sub.add_parser("check").add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "inspect":
        result = inspect(args.recipe, args.out)
        print(json.dumps({k: v for k, v in result.items() if k != "heads"}, indent=2))
    elif args.command == "preflight":
        print(json.dumps(preflight(args.recipe, args.out), indent=2))
    else:
        result = sample(args.recipe, args.out) if args.command == "sample" else (
            build(args.recipe, args.out) if args.command == "build" else check(args.out))
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
