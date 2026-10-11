"""Offline volume-first anatomy adapter; never writes production/gameplay data.

Coordinates are anatomical right/forward/up before the existing eight-yaw camera.
Limbs are re-proportioned as fixed-length chains, not screen-space stretched art.
Every posed foot keeps its original contact/lift classification. The source rig
and palette are immutable. New rigs deliberately identify their new bone lengths.
"""
from __future__ import annotations

import ast
import copy
import importlib.util
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
RIG = REPO / "art_batches/character_style_v1/wireframe_motion_v2"
VERSION = "volume_first_v1"
DEPTH_SCALE = 0.450533624
PROFILES = {
    "small": {"height": 58, "width": 1.00, "depth": 1.02, "girth": 1.06},
    "middle": {"height": 63, "width": 1.23, "depth": 1.23, "girth": 1.19},
    "large": {"height": 68, "width": 1.46, "depth": 1.44, "girth": 1.33},
}
LEG_SCALE = .80
ARM_SCALE = .82
HEAD_OFFSET_SCALE = .94
HEAD_RADIUS_SCALE = 1.10


def add(a, b): return [x+y for x, y in zip(a, b)]
def sub(a, b): return [x-y for x, y in zip(a, b)]
def mul(a, s): return [x*s for x in a]
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def norm(a):
    length = math.sqrt(dot(a, a))
    if length < 1e-10:
        raise ValueError("Degenerate anatomical axis")
    return mul(a, 1/length)
def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def depth(v, aim):
    yaw = aim*math.pi/4
    return v[0]*math.sin(yaw)+v[1]*math.cos(yaw)


def project(v, aim, unit):
    yaw = aim*math.pi/4
    return [(-v[0]*math.cos(yaw)+v[1]*math.sin(yaw))*unit,
            (depth(v, aim)*DEPTH_SCALE-v[2])*unit]


def adapt_pose(pose, data):
    """Return one new pose; pass the ORIGINAL source data for its calibration."""
    if pose.get("volume_revision"):
        raise ValueError("Refusing to apply anatomy adaptation twice")
    profile = PROFILES[pose["body"]]
    old = pose["landmarks"]
    shoulder_mid = mul(add(old["shoulder_l"], old["shoulder_r"]), .5)
    up = norm(sub(shoulder_mid, old["pelvis"]))
    right = norm(sub(old["shoulder_r"], old["shoulder_l"]))
    forward = norm(cross(up, right))
    pelvis = mul(old["pelvis"], LEG_SCALE)
    chest = add(pelvis, sub(shoulder_mid, old["pelvis"]))
    head = add(chest, mul(sub(old["head"], shoulder_mid), HEAD_OFFSET_SCALE))
    source = {"pelvis": pelvis, "head": head,
              "neck": add(chest, sub(old["neck"], shoulder_mid)),
              "nose": add(head, sub(old["nose"], old["head"]))}
    for side in ("l", "r"):
        # Widen horizontal stance while preserving z=0 foot contacts exactly.
        offset = sub(old["hip_"+side], old["pelvis"])
        shift = [offset[0]*(profile["width"]-LEG_SCALE),
                 offset[1]*(profile["width"]-LEG_SCALE), 0]
        for part in ("hip", "knee", "ankle", "toe"):
            key = part+"_"+side
            source[key] = add(mul(old[key], LEG_SCALE), shift)
        key = "shoulder_"+side
        shoulder = add(chest, mul(sub(old[key], shoulder_mid), profile["width"]))
        source[key] = shoulder
        for part in ("elbow", "hand"):
            source[part+"_"+side] = add(shoulder, mul(sub(old[part+"_"+side], old[key]), ARM_SCALE))
    span = ((data["bone_lengths"]["thigh"]+data["bone_lengths"]["shin"])*LEG_SCALE
            + data["bone_lengths"]["torso"] + data["head_offset"]*HEAD_OFFSET_SCALE
            + data["head_radius"]*HEAD_RADIUS_SCALE
            + data["bone_lengths"]["foot"]*LEG_SCALE*DEPTH_SCALE)
    # Existing renderer still applies its one-per-body source -> display scale.
    unit = data["heights"][pose["body"]]/span
    projected = {k: project(v, pose["aim"], unit) for k, v in source.items()}
    anchor = [48, 83-max(p[1] for p in projected.values())]
    points = {k: add(p, anchor) for k, p in projected.items()}
    chains = copy.deepcopy(pose["chains"])
    for chain in chains:
        chain["depth"] = sum(depth(source[k], pose["aim"]) for k in chain["keys"])/len(chain["keys"])
    chains.sort(key=lambda c: c["depth"])
    mesh, mesh_depths = [], []
    for z, width, thick in ((.30, .200, .150), (.11, .150, .115), (.015, .140, .110)):
        for i in range(8):
            angle = math.tau*i/8
            point = add(add(add(pelvis, mul(up, z)), mul(right, math.cos(angle)*width*profile["width"])),
                        mul(forward, math.sin(angle)*thick*profile["depth"]))
            mesh.append(add(project(point, pose["aim"], unit), anchor))
            mesh_depths.append(depth(point, pose["aim"]))
    faces = copy.deepcopy(pose["mesh_faces"])
    for face in faces:
        face["depth"] = sum(mesh_depths[i] for i in face["indices"])/len(face["indices"])
    faces.sort(key=lambda f: f["depth"])
    sternum = []
    for z in (.27, .06):
        v = add(add(pelvis, mul(up, z)), mul(forward, (.140 if z > .2 else .110)*profile["depth"]))
        sternum.append(add(project(v, pose["aim"], unit), anchor))
    result = copy.deepcopy(pose)
    result.update(points=points, landmarks=source, chains=chains, mesh_points=mesh,
                  mesh_faces=faces, sternum=sternum, pixels_per_unit=unit,
                  torso_depth=depth(mul(add(chest, pelvis), .5), pose["aim"]),
                  volume_revision=VERSION, volume_girth=profile["girth"])
    return result


def adapt_data(data):
    """Clone complete rig, preserving all semantic frame keys and source hashes."""
    if data.get("volume_revision"):
        raise ValueError("Refusing double volume adaptation")
    result = copy.deepcopy(data)
    result["poses"] = [adapt_pose(p, data) for p in data["poses"]]
    result["source_bone_lengths"] = copy.deepcopy(data["bone_lengths"])
    for bone in ("thigh", "shin", "foot"):
        result["bone_lengths"][bone] *= LEG_SCALE
    for bone in ("humerus", "forearm"):
        result["bone_lengths"][bone] *= ARM_SCALE
    result["head_radius"] *= HEAD_RADIUS_SCALE
    result["head_offset"] *= HEAD_OFFSET_SCALE
    result["volume_revision"] = VERSION
    result["volume_profiles"] = copy.deepcopy(PROFILES)
    result["volume_policy"] = "Offline anatomical reproportion; original contact phases/yaws; no gameplay change"
    return result


def girth_function(function, source_path=None, function_name=None):
    """Clone a renderer with limb thickness keyed by pose; no global mutations.

    Supports existing render or factory render_headless. For generated functions
    supply their AST source via girth_ast(fn) before compiling instead.
    """
    import inspect
    tree = ast.parse(Path(source_path).read_text(encoding="utf-8") if source_path else inspect.getsource(function))
    name = function_name or function.__name__
    fn = copy.deepcopy(next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == name))
    fn = girth_ast(fn)
    namespace = dict(function.__globals__)
    exec(compile(ast.fix_missing_locations(ast.Module(body=[fn], type_ignores=[])), "<volume-girth>", "exec"), namespace)
    return namespace[name]


def girth_ast(fn):
    """Clone AST function; call before compiling a custom headless body renderer."""
    fn = copy.deepcopy(fn)
    class Girth(ast.NodeTransformer):
        def visit_Assign(self, node):
            self.generic_visit(node)
            if any(isinstance(t, ast.Name) and t.id == "radius" for t in node.targets):
                node.value = ast.BinOp(node.value, ast.Mult(), ast.parse("pose.get('volume_girth', 1.0)", mode="eval").body)
            return node
    return ast.fix_missing_locations(Girth().visit(fn))


def load_renderer():
    spec = importlib.util.spec_from_file_location("volume_source_renderer", RIG / "build.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, girth_function(module.render)


def build_review(output):
    """Create offline comparison and exact measurable metrics, not production art."""
    from PIL import Image, ImageDraw
    out = Path(output)
    out.mkdir(parents=True, exist_ok=False)
    data = json.loads((RIG / "rig-data.json").read_text())
    adapted = adapt_data(data)
    module, render = load_renderer()
    before = {(p["body"], p["aim"]): p for p in data["poses"] if p["state"] == "grounded"}
    after = {(p["body"], p["aim"]): p for p in adapted["poses"] if p["state"] == "grounded"}
    board = Image.new("RGB", (8*192+160, 6*192+48), "#ddd1b7")
    draw = ImageDraw.Draw(board)
    draw.text((12, 12), "VOLUME-FIRST TEMPLATES / BEFORE + AFTER / SAME CAMERA AND HEIGHT CALIBRATION", fill="#241c19")
    metrics = {}
    for i, body in enumerate(PROFILES):
        metrics[body] = {}
        for j, (label, mapping, rig, renderer) in enumerate((("before", before, data, module.render), ("after", after, adapted, render))):
            row = i*2+j
            draw.text((10, row*192+90), body+" / "+label, fill="#241c19")
            for aim in range(8):
                img = renderer(mapping[(body, aim)], rig)
                board.paste(img.resize((192,192), Image.Resampling.NEAREST), (160+aim*192,48+row*192), img.resize((192,192), Image.Resampling.NEAREST))
                if aim in (0,2):
                    alpha=img.getchannel("A")
                    box=alpha.getbbox()
                    metrics[body][label+"_"+("front" if aim==0 else "profile")]={"bounds":list(box),"width":box[2]-box[0],"height":box[3]-box[1],"opaque_pixels":sum(v>0 for v in alpha.getdata())}
    board.save(out / "volume-before-after.png")
    (out / "metrics.json").write_text(json.dumps(metrics, indent=2)+"\n")
    return metrics


if __name__ == "__main__":
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    args=parser.parse_args()
    print(json.dumps(build_review(args.out), indent=2))
