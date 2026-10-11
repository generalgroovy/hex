"""Offline full-body retargeting poses; no images, engines or gameplay writes.

Public API: pose(body, action, aim, travel, phase), rest(body, aim).
points are FINAL 96x96 display-space landmarks; landmarks are fixed-bone 3D.
World jump lift is deliberately absent. Generated poses require visual review.
"""
from __future__ import annotations

import copy
from functools import lru_cache
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("motion_volume", ROOT / "art_batches/character_volume_v1/volume.py")
volume = importlib.util.module_from_spec(spec)
spec.loader.exec_module(volume)
BODIES = ("small", "middle", "large")
DIRECTIONS = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
ALIASES = {"airrise": "jump", "rise": "jump", "doublejump": "double_jump", "airdodge": "air_dodge", "walljump": "walljump", "float": "fly", "grounded": "idle", "wall_skim": "wallrun", "wave_dash": "wavedash"}
ACTIONS = ("idle", "walk", "sprint", "jumpsquat", "jump", "fall", "fast_fall", "double_jump", "land", "crouch", "slide", "slide_jump", "roll", "air_dodge", "wavedash", "wallrun", "walljump", "fly", "cast", "cast_recovery", "hit", "stunned", "rooted", "defeated", "interact", "taunt")
DISPLAY_HEIGHTS = {"small": 58, "middle": 63, "large": 68}


def add(a, b): return [x+y for x, y in zip(a, b)]
def sub(a, b): return [x-y for x, y in zip(a, b)]
def mul(a, n): return [x*n for x in a]
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def length(v): return math.sqrt(dot(v, v))
def unit(v, fallback=(0, 0, -1)):
    n = length(v)
    return mul(v, 1/n) if n > 1e-10 else list(fallback)
def mix(a, b, t): return add(mul(a, 1-t), mul(b, t))
def smooth(t): return t*t*(3-2*t)


@lru_cache(maxsize=1)
def _source():
    data = json.loads((volume.RIG / "rig-data.json").read_text(encoding="utf-8"))
    indexed = {(p["body"], p["state"], p["aim"], p["travel"], p["phase"]): p for p in data["poses"]}
    if len(indexed) != 3312:
        raise ValueError("Expected the immutable 3312-pose source rig")
    return data, indexed


def _base(body, action, aim):
    return copy.deepcopy(_source()[1][(body, action, aim, -1, -1)])


def _ik(start, target, bend_hint, upper, lower):
    """Two fixed-length links aimed at target, clamped only to reachable radius."""
    delta = sub(target, start)
    direction = unit(delta)
    distance = min(upper+lower-1e-9, max(abs(upper-lower)+1e-9, length(delta)))
    along = (upper*upper-lower*lower+distance*distance)/(2*distance)
    normal = sub(sub(bend_hint, start), mul(direction, dot(sub(bend_hint, start), direction)))
    if length(normal) < 1e-8:
        reference = [0, 1, 0] if abs(direction[1]) < .9 else [1, 0, 0]
        normal = sub(reference, mul(direction, dot(reference, direction)))
    knee = add(add(start, mul(direction, along)), mul(unit(normal), math.sqrt(max(0, upper*upper-along*along))))
    return knee, add(start, mul(direction, distance))


def _blend(a, b, t):
    """Blend target endpoints, then solve each limb with unchanged bone lengths."""
    if t <= 0: return copy.deepcopy(a)
    if t >= 1: return copy.deepcopy(b)
    data, _ = _source()
    out = copy.deepcopy(a)
    la, lb = a["landmarks"], b["landmarks"]
    lm = {k: mix(la[k], lb[k], t) for k in la}
    chest_a = mul(add(la["shoulder_l"], la["shoulder_r"]), .5)
    chest_b = mul(add(lb["shoulder_l"], lb["shoulder_r"]), .5)
    chest = add(lm["pelvis"], mul(unit(mix(sub(chest_a, la["pelvis"]), sub(chest_b, lb["pelvis"]), t)), data["bone_lengths"]["torso"]))
    for side in ("l", "r"):
        key = "shoulder_"+side
        offset = mix(sub(la[key], chest_a), sub(lb[key], chest_b), t)
        lm[key] = add(chest, mul(unit(offset), length(sub(la[key], chest_a))))
    for key in ("head", "neck"):
        offset = mix(sub(la[key], chest_a), sub(lb[key], chest_b), t)
        lm[key] = add(chest, mul(unit(offset), length(sub(la[key], chest_a))))
    nose_offset = mix(sub(la["nose"], la["head"]), sub(lb["nose"], lb["head"]), t)
    lm["nose"] = add(lm["head"], mul(unit(nose_offset), length(sub(la["nose"], la["head"]))))
    for side in ("l", "r"):
        for root, joint, tip, first, second in (("hip", "knee", "ankle", "thigh", "shin"), ("shoulder", "elbow", "hand", "humerus", "forearm")):
            r, j, e = (f"{x}_{side}" for x in (root, joint, tip))
            lm[j], lm[e] = _ik(lm[r], lm[e], lm[j], data["bone_lengths"][first], data["bone_lengths"][second])
        ankle, toe = "ankle_"+side, "toe_"+side
        lm[toe] = add(lm[ankle], mul(unit(mix(sub(la[toe], la[ankle]), sub(lb[toe], lb[ankle]), t)), data["bone_lengths"]["foot"]))
    out["landmarks"] = lm
    return out


def _rotate(v, axis, angle):
    x, y, z = v
    c, s = math.cos(angle), math.sin(angle)
    if axis == 0: return [x, y*c-z*s, y*s+z*c]
    if axis == 1: return [x*c+z*s, y, -x*s+z*c]
    return [x*c-y*s, x*s+y*c, z]


def _turn_chain(raw, side, root, axis, angle):
    lm = raw["landmarks"]
    keys = ("elbow", "hand") if root == "shoulder" else ("knee", "ankle", "toe")
    origin = lm[root+"_"+side]
    for part in keys:
        key = part+"_"+side
        lm[key] = add(origin, _rotate(sub(lm[key], origin), axis, angle))


def _turn_upper(raw, angle):
    lm = raw["landmarks"]
    for key in ("head", "nose", "neck", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r"):
        lm[key] = add(lm["pelvis"], _rotate(sub(lm[key], lm["pelvis"]), 0, angle))


def _gait(body, action, aim, travel, phase):
    _, indexed = _source()
    state = "sprint_locomotion" if action in ("sprint", "wallrun") else "locomotion"
    at = (phase % 1.0)*8
    first = int(at) % 8
    return _blend(indexed[(body, state, aim, travel, first)], indexed[(body, state, aim, travel, (first+1)%8)], at-first)


def _raw(body, action, aim, travel, phase):
    p = phase
    wave = math.sin(math.tau*p)
    ground = _base(body, "grounded", aim)
    if action in ("walk", "sprint", "wallrun"):
        out = _gait(body, action, aim, travel, p)
        if action == "wallrun":
            _turn_upper(out, .09)
            out["wall_contact_side_required"] = True
        return out
    if action in ("crouch", "jumpsquat", "land", "slide", "wavedash"):
        depth = {"crouch": .46, "jumpsquat": .24+.35*smooth(p), "land": .43*(1-smooth(p)), "slide": .90+.10*math.sin(math.pi*p), "wavedash": .83-.24*p}[action]
        lane = travel if action in ("slide", "wavedash") else aim
        out = _blend(_base(body, "grounded", lane), _base(body, "slide", lane), depth)
        out["aim"] = lane
        return out
    if action in ("jump", "double_jump", "fall", "fast_fall", "slide_jump", "walljump", "air_dodge", "fly"):
        out = _base(body, "jump", aim)
        _turn_upper(out, (.04*wave if action == "fly" else .12*math.sin(math.pi*p)))
        tuck = {"jump": .10, "double_jump": .34, "fall": -.12, "fast_fall": -.22, "slide_jump": .22, "walljump": .28, "air_dodge": .40, "fly": .06}[action]
        for side, sign in (("l", 1), ("r", -1)):
            _turn_chain(out, side, "hip", 0, tuck*math.sin(math.pi*p)+sign*.045*wave)
            if action == "fly": _turn_chain(out, side, "shoulder", 1, sign*.10*wave)
        return out
    if action == "roll":
        out = _base(body, "roll", travel)
        lm = out["landmarks"]
        pivot = list(lm["pelvis"])
        for key in lm:
            lm[key] = add(pivot, _rotate(sub(lm[key], pivot), 0, -math.tau*p))
        out["aim"] = travel
        return out
    if action in ("cast", "cast_recovery", "interact", "taunt"):
        amount = smooth(min(1.0, p*2)) if action == "cast" else (1-smooth(p))
        if action in ("interact", "taunt"): amount = .55*math.sin(math.pi*p)
        return _blend(ground, _base(body, "cast", aim), amount)
    if action in ("hit", "stunned", "defeated"):
        amount = (1-p) if action == "hit" else (.60+.06*wave)
        if action == "defeated": amount = smooth(p)
        out = _blend(ground, _base(body, "hit", aim), amount)
        if action == "defeated": _turn_upper(out, -.48*smooth(p))
        return out
    out = ground
    # A subtle shoulder-driven idle/held reaction; feet remain untouched.
    for side, sign in (("l", 1), ("r", -1)):
        _turn_chain(out, side, "shoulder", 1, sign*.035*wave)
    return out


@lru_cache(maxsize=24)
def _rest_calibration(body, aim):
    data, _ = _source()
    adapted = volume.adapt_pose(_base(body, "grounded", aim), data)
    anchor = sub(adapted["points"]["pelvis"], volume.project(adapted["landmarks"]["pelvis"], aim, adapted["pixels_per_unit"]))
    return adapted, anchor


def pose(body, action, aim=0, travel=None, phase=0.0):
    """Return an owned mutable pose dict. Inputs use direction indices 0..7.

    Full source limb/mesh metadata is retained. No race capability is granted:
    callers must gate fly with flight_capable. Wall contact side remains a
    required retargeting overlay, explicitly marked on wallrun candidates.
    """
    action = ALIASES.get(action, action)
    if body not in BODIES or action not in ACTIONS:
        raise ValueError("Unknown body/action")
    if type(aim) is not int or not 0 <= aim < 8:
        raise ValueError("Aim must be an integer direction 0..7")
    travel = aim if travel is None else travel
    if type(travel) is not int or not 0 <= travel < 8:
        raise ValueError("Travel must be an integer direction 0..7")
    if not isinstance(phase, (int, float)) or not math.isfinite(phase) or not 0 <= phase <= 1:
        raise ValueError("Phase must be finite in [0,1]")
    data, _ = _source()
    raw = _raw(body, action, aim, travel, float(phase))
    result = volume.adapt_pose(raw, data)
    body_aim = result["aim"]
    _, rest_anchor = _rest_calibration(body, body_aim)
    old_anchor = sub(result["points"]["pelvis"], volume.project(result["landmarks"]["pelvis"], body_aim, result["pixels_per_unit"]))
    shift = sub(rest_anchor, old_anchor)
    scale = DISPLAY_HEIGHTS[body]/data["heights"][body]
    def display(point):
        point = add(point, shift)
        return [48+(point[0]-48)*scale, 84+(point[1]-84)*scale]
    result["points"] = {key: display(point) for key, point in result["points"].items()}
    result["mesh_points"] = [display(point) for point in result["mesh_points"]]
    result["sternum"] = [display(point) for point in result["sternum"]]
    result.update(action=action, phase=float(phase), travel=travel, requested_aim=aim,
                  display_space=True, display_height=DISPLAY_HEIGHTS[body], world_lift=0,
                  source="volume-adapted fixed-bone rig and procedural joint targets",
                  visual_acceptance="pending", ground_anchor=[48, 84],
                  contacts={side: abs(result["landmarks"]["ankle_"+side][2]) < 1e-6 for side in ("l", "r")})
    result["pixels_per_unit"] *= scale
    return result


def rest(body, aim=0):
    """Shared neutral reference, independent mutable result at the same scale."""
    return pose(body, "idle", aim, aim, 0.0)
