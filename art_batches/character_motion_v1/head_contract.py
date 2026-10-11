"""Pure, identity-locked cranial calibration; never infer anatomy from alpha.

All coordinates are source pixels. Bounds must be manually annotated anatomical
skull bounds, excluding hair, ears, horns, crown and beard. A plan is made ONCE
from neutral frontal anatomy and reused for every facing/pose of that identity.
This module does not partition pixels, load assets or approve visual quality.
"""
from math import isfinite
from numbers import Real

SHARED_SKULL_HEIGHT_PX = 18.0
IDENTITY_HEIGHT_RANGE_PX = (16.0, 20.0)
BODY_HEIGHTS_PX = {"small": 58.0, "middle": 63.0, "large": 68.0}


def _number(value, name):
    if isinstance(value, bool) or not isinstance(value, Real) or not isfinite(value):
        raise ValueError(f"{name} must be a finite number")
    return float(value)


def _point(value, name):
    if not isinstance(value, (list, tuple)) or len(value) != 2:
        raise ValueError(f"{name} must contain two coordinates")
    return tuple(_number(v, name) for v in value)


def _target(value):
    value = _number(value, "target_height_px")
    if not IDENTITY_HEIGHT_RANGE_PX[0] <= value <= IDENTITY_HEIGHT_RANGE_PX[1]:
        raise ValueError("target skull height must stay within 16..20 px")
    return value


def make_head_plan(cranial_bounds, target_height_px=SHARED_SKULL_HEIGHT_PX):
    """Return JSON-safe fixed calibration from explicit [left, top, right, bottom].

    Width is retained isotropically, not forced to a common width. A wide snout
    can keep its identity. The caller must hold unknown/occluded anatomy for
    review rather than pass whole-frame or torso bounds as cranial annotations.
    """
    if not isinstance(cranial_bounds, (list, tuple)) or len(cranial_bounds) != 4:
        raise ValueError("cranial_bounds must contain four coordinates")
    left, top, right, bottom = [_number(v, "cranial_bounds") for v in cranial_bounds]
    if right <= left or bottom <= top:
        raise ValueError("cranial_bounds must have positive width and height")
    target = _target(target_height_px)
    scale = target / (bottom - top)
    return {
        "schema_version": 1,
        "source_bounds": [left, top, right, bottom],
        "source_height_px": bottom - top,
        "target_height_px": target,
        "target_width_px": (right - left) * scale,
        "head_scale": scale,
        "scale_scope": "identity_all_facings_all_poses",
        "review_required": True,
    }


def _scale(plan):
    if not isinstance(plan, dict):
        raise ValueError("plan must be a make_head_plan result")
    expected = make_head_plan(plan.get("source_bounds"), plan.get("target_height_px"))
    actual = _number(plan.get("head_scale"), "head_scale")
    if abs(actual - expected["head_scale"]) > 1e-12:
        raise ValueError("head plan scale was changed after calibration")
    return actual


def relative_head_scale(plan, body_scale):
    """Local correction when an ancestor already applies fixed body_scale."""
    body_scale = _number(body_scale, "body_scale")
    if body_scale <= 0:
        raise ValueError("body_scale must be positive")
    return _scale(plan) / body_scale


def place_head_point(point, source_neck, destination_neck, plan):
    """Place a source head point about neck, at final destination-pixel scale.

    Animate destination_neck and head orientation in the caller's joint system;
    reuse this SAME calibration. Body scaling must not be multiplied again.
    Coordinates may be negative for legitimate poses outside a source canvas.
    """
    point = _point(point, "point")
    source_neck = _point(source_neck, "source_neck")
    destination_neck = _point(destination_neck, "destination_neck")
    scale = _scale(plan)
    return tuple(destination_neck[i] + (point[i] - source_neck[i]) * scale for i in range(2))


def body_budget(size, skull_height_px=SHARED_SKULL_HEIGHT_PX):
    """Neutral construction lengths; NOT per-pose image fitting instructions.

    Keep a 2px neck and divide remaining body 5:7 torso:legs. Thus skull size is
    shared while torso/limbs grow. Changing the reviewed identity skull target
    adjusts the remaining construction budget, not the full actor every frame.
    """
    if not isinstance(size, str) or size not in BODY_HEIGHTS_PX:
        raise ValueError("size must be small, middle or large")
    skull = _target(skull_height_px)
    height = BODY_HEIGHTS_PX[size]
    neck = 2.0
    remaining = height - skull - neck
    return {"height_px": height, "skull_px": skull, "neck_px": neck,
            "torso_px": remaining * 5.0 / 12.0, "legs_px": remaining * 7.0 / 12.0}
