"""Lossless, editable anatomical partition of the approved whole-body sources.

This module does not synthesize substitute body pixels. The default partition is
a REVIEW CANDIDATE: hidden surfaces cannot be recovered from a flattened idle
view. Explicit per-facing anchors and polygon masks override the heuristic.
Source pixels are conserved exactly once; new exposed joints require authored
correction art, never a primitive body fallback.
"""
from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = REPO / 'art_batches/character_cast_v1/output/fullbody-v2/manifest.json'
DEFAULT_OVERRIDES = HERE / 'calibration_overrides.json'
DIRECTIONS = ('S', 'SE', 'E', 'NE', 'N', 'NW', 'W', 'SW')
CELL = (96, 96)
BINDINGS = {
    'torso': ['pelvis', 'neck'], 'head': ['neck', 'head'],
    'appendage_tail': ['pelvis', 'neck'],
    'appendage_wing_l': ['pelvis', 'neck'], 'appendage_wing_r': ['pelvis', 'neck'],
    'appendage_back': ['pelvis', 'neck'],
}
for side in ('l', 'r'):
    BINDINGS.update({
        f'upper_arm_{side}': [f'shoulder_{side}', f'elbow_{side}'],
        f'forearm_{side}': [f'elbow_{side}', f'hand_{side}'],
        f'hand_{side}': [f'elbow_{side}', f'hand_{side}'],
        f'thigh_{side}': [f'hip_{side}', f'knee_{side}'],
        f'shin_{side}': [f'knee_{side}', f'ankle_{side}'],
        f'foot_{side}': [f'ankle_{side}', f'toe_{side}'],
    })
PARTS = tuple(BINDINGS)
ANCHORS = frozenset(a for pair in BINDINGS.values() for a in pair)
WING_RACES = {'sylph', 'angel', 'wyrmborn'}
TAIL_RACES = {'seakin', 'wyrmborn', 'werewolf', 'demon'}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rgba_sha(frame):
    return hashlib.sha256(frame.tobytes()).hexdigest()


def finite_point(value):
    return (isinstance(value, (list, tuple)) and len(value) == 2
            and all(isinstance(v, (int, float)) and not isinstance(v, bool)
                    and math.isfinite(v) and 0 <= v <= 96 for v in value))


def source_frame(character, root, direction):
    path = (Path(root) / character['atlas']).resolve()
    require(path.is_relative_to(Path(root).resolve()), 'Atlas path escapes manifest directory')
    require(sha(path) == character['atlas_sha256'], 'Source atlas hash mismatch')
    frames = character['frames']
    require([f['direction'] for f in frames] == list(DIRECTIONS), 'Eight unique ordered facings required')
    index = DIRECTIONS.index(direction)
    record = frames[index]
    require(record['rect'] == [index * 96, 0, 96, 96], 'Source cell layout mismatch')
    with Image.open(path) as atlas:
        require(atlas.mode == 'RGBA' and atlas.size == (768, 96), 'Source atlas format mismatch')
        frame = atlas.crop((index * 96, 0, (index + 1) * 96, 96))
    require(rgba_sha(frame) == record['rgba_sha256'], 'Source frame hash mismatch')
    require(set(frame.getchannel('A').getdata()) <= {0, 255}, 'Source alpha must be binary')
    return frame


def default_spec(frame, direction, race='human'):
    """Conservative standing landmarks; editable, not anatomical acceptance."""
    bounds = frame.getchannel('A').getbbox()
    require(bounds is not None, 'Empty source frame')
    x0, y0, x1, y1 = bounds
    height = y1 - y0
    center = 48.0
    yaw = DIRECTIONS.index(direction) * math.pi / 4
    lateral, depth = math.cos(yaw), math.sin(yaw)
    # Keep paired visible limbs separable in profile; this is source pixel
    # ownership, not an assertion that an orthographic yaw has been measured.
    side_extent = math.copysign(max(abs(lateral), .38), lateral if abs(lateral) > .01 else 1)
    def point(x, y): return [round(center + height*x, 3), round(y0 + height*y, 3)]
    anchors = {'head': point(.03*depth, .21), 'neck': point(0, .36), 'pelvis': point(0, .67)}
    for side, sign in (('l', 1), ('r', -1)):
        anchors.update({
            f'shoulder_{side}': point(sign*.17*side_extent, .39 + sign*.035*depth),
            f'elbow_{side}': point(sign*.27*side_extent, .52 + sign*.035*depth),
            f'hand_{side}': point(sign*.33*side_extent, .64 + sign*.035*depth),
            f'hip_{side}': point(sign*.12*side_extent, .69 + sign*.02*depth),
            f'knee_{side}': point(sign*.145*side_extent, .82 + sign*.02*depth),
            f'ankle_{side}': point(sign*.17*side_extent, .94 + sign*.01*depth),
            f'toe_{side}': point(sign*.20*side_extent + .025*depth, .985),
        })
    near = 'l' if depth >= 0 else 'r'
    far = 'r' if near == 'l' else 'l'
    limb_order = lambda side: [f'thigh_{side}', f'shin_{side}', f'foot_{side}',
                               f'upper_arm_{side}', f'forearm_{side}', f'hand_{side}']
    return {'schema_version': 1, 'direction': direction, 'race': race,
            'source_rgba_sha256': rgba_sha(frame), 'anchors': anchors,
            'core_bounds': [center-height*.23, y0, center+height*.23, y1],
            'masks': {}, 'bindings': copy.deepcopy(BINDINGS),
            'order': ['appendage_back', 'appendage_tail', 'appendage_wing_l', 'appendage_wing_r']
                     + limb_order(far) + ['torso'] + limb_order(near) + ['head'],
            'review_required': True, 'anchor_status': 'heuristic_source_partition_not_accepted'}


def merge_override(spec, override):
    result = copy.deepcopy(spec)
    require(isinstance(override, dict), 'Facing override must be an object')
    for key, value in override.items():
        if key in ('anchors', 'masks', 'bindings'):
            require(isinstance(value, dict), f'{key} override must be an object')
            result[key].update(copy.deepcopy(value))
        else:
            result[key] = copy.deepcopy(value)
    return result


def validate_spec(spec, frame):
    require(spec.get('schema_version') == 1 and spec.get('direction') in DIRECTIONS, 'Invalid layer spec')
    require(spec.get('source_rgba_sha256') == rgba_sha(frame), 'Layer spec belongs to a different source')
    anchors = spec.get('anchors', {})
    require(ANCHORS <= anchors.keys(), 'Missing anatomical anchor')
    require(all(finite_point(p) for p in anchors.values()), 'Invalid anatomical anchor')
    require(set(spec.get('bindings', {})) == set(PARTS), 'All exact layer bindings required')
    for part, pair in spec['bindings'].items():
        require(isinstance(pair, list) and len(pair) == 2 and all(p in anchors for p in pair), 'Unknown binding anchor')
        require(math.dist(anchors[pair[0]], anchors[pair[1]]) > .1, f'Degenerate binding: {part}')
    bounds = spec.get('core_bounds', [])
    require(len(bounds) == 4 and finite_point(bounds[:2]) and finite_point(bounds[2:])
            and bounds[0] < bounds[2] and bounds[1] < bounds[3], 'Invalid body core bounds')
    require(len(spec.get('order', [])) == len(PARTS) and set(spec['order']) == set(PARTS), 'Invalid depth order')
    require(set(spec.get('masks', {})) <= set(PARTS), 'Unknown layer mask')


def _distance(point, a, b):
    vx, vy = b[0]-a[0], b[1]-a[1]
    ratio = max(0, min(1, ((point[0]-a[0])*vx + (point[1]-a[1])*vy)/(vx*vx+vy*vy)))
    return math.hypot(point[0]-a[0]-ratio*vx, point[1]-a[1]-ratio*vy)


def partition_frame(frame, spec):
    """Return layers/anchors/bindings/order/spec/receipt, conserving RGBA exactly."""
    require(frame.mode == 'RGBA' and frame.size == CELL, 'Expected RGBA96 source')
    require(set(frame.getchannel('A').getdata()) <= {0, 255}, 'Binary source alpha required')
    validate_spec(spec, frame)
    mask_owners = {}
    opaque = frame.getchannel('A')
    for part, polygons in spec['masks'].items():
        require(isinstance(polygons, list), 'Masks must be polygon lists')
        mask = Image.new('1', CELL)
        draw = ImageDraw.Draw(mask)
        for polygon in polygons:
            require(isinstance(polygon, list) and len(polygon) >= 3 and all(finite_point(p) for p in polygon), 'Invalid mask polygon')
            area = abs(sum(polygon[i][0]*polygon[(i+1)%len(polygon)][1] - polygon[(i+1)%len(polygon)][0]*polygon[i][1] for i in range(len(polygon))))
            require(area > .01, 'Degenerate mask polygon')
            draw.polygon([tuple(p) for p in polygon], fill=1)
        for y in range(96):
            for x in range(96):
                if mask.getpixel((x, y)) and opaque.getpixel((x, y)):
                    require((x,y) not in mask_owners, 'Explicit masks overlap on opaque source pixels')
                    mask_owners[(x,y)] = part
    anchors, bindings = spec['anchors'], spec['bindings']
    left, top, right, bottom = spec['core_bounds']
    center, height = (left+right)/2, bottom-top
    head_cut = (anchors['head'][1]+anchors['neck'][1])/2 + height*.045
    pelvis_y = anchors['pelvis'][1]
    layers = {part: Image.new('RGBA', CELL) for part in PARTS}
    counts = {part: 0 for part in PARTS}
    source_count = 0
    for y in range(96):
        for x in range(96):
            pixel = frame.getpixel((x,y))
            if not pixel[3]:
                continue
            source_count += 1
            part = mask_owners.get((x,y))
            if part is None:
                if y < head_cut:
                    part = 'head'
                elif spec['race'] in WING_RACES and abs(x-center) > height*.33 and y < pelvis_y-height*.08:
                    part = 'appendage_wing_l' if x > center else 'appendage_wing_r'
                elif spec['race'] in TAIL_RACES and abs(x-center) > height*.29 and y > pelvis_y-height*.025:
                    part = 'appendage_tail'
                elif spec['race'] == 'spiderkin' and abs(x-center) > height*.30 and y > top+height*.40:
                    part = 'appendage_back'
                elif y >= pelvis_y:
                    candidates = [f'{segment}_{side}' for segment in ('thigh', 'shin', 'foot') for side in ('l','r')]
                    part = min(candidates, key=lambda p: _distance((x,y), *(anchors[a] for a in bindings[p])))
                elif left <= x <= right:
                    part = 'torso'
                else:
                    candidates = [f'{segment}_{side}' for segment in ('upper_arm', 'forearm') for side in ('l','r')]
                    part = min(candidates, key=lambda p: _distance((x,y), *(anchors[a] for a in bindings[p])))
                    side = part[-1]
                    if math.dist((x,y), anchors[f'hand_{side}']) < height*.055:
                        part = f'hand_{side}'
            layers[part].putpixel((x,y), pixel)
            counts[part] += 1
    rebuilt = Image.new('RGBA', CELL)
    for part in spec['order']:
        rebuilt.alpha_composite(layers[part])
    # Hidden RGB in transparent source pixels is intentionally not artwork.
    source_visible = Image.new('RGBA', CELL)
    source_visible.alpha_composite(frame)
    require(rebuilt.tobytes() == source_visible.tobytes(), 'Source pixel conservation failed')
    require(sum(counts.values()) == source_count, 'Source pixel ownership failed')
    return {'layers': layers, 'anchors': copy.deepcopy(anchors), 'bindings': copy.deepcopy(bindings),
            'order': list(spec['order']), 'spec': copy.deepcopy(spec),
            'receipt': {'source_pixels': source_count, 'layer_pixels': counts,
                        'pixel_conservation': True, 'reassembled_rgba_sha256': rgba_sha(rebuilt),
                        'review_required': True, 'hidden_surfaces': 'not_authored'}}


def load_character(character_id, manifest_path=None, overrides_path=None):
    path = Path(manifest_path or DEFAULT_MANIFEST).resolve()
    manifest = json.loads(path.read_text(encoding='utf-8'))
    require(manifest.get('cell') == [96,96] and manifest.get('directions') == list(DIRECTIONS), 'Incompatible source manifest')
    rows = [c for c in manifest['characters'] if c['id'] == character_id]
    require(len(rows) == 1, 'Unknown or duplicate character')
    character = rows[0]
    override_path = Path(overrides_path) if overrides_path else DEFAULT_OVERRIDES
    overrides = {}
    if override_path.exists():
        data = json.loads(override_path.read_text(encoding='utf-8'))
        require(data.get('schema_version') == 1, 'Invalid calibration schema')
        overrides = data.get('characters', {}).get(character_id, {})
        require(set(overrides) <= set(DIRECTIONS), 'Unknown calibrated facing')
        if overrides and 'source_hashes' in data:
            require(data['source_hashes'].get(character_id) == character['atlas_sha256'],
                    'Calibration belongs to a different character source atlas')
    elif overrides_path:
        raise ValueError('Explicit calibration path not found')
    views = {}
    for direction in DIRECTIONS:
        frame = source_frame(character, path.parent, direction)
        spec = merge_override(default_spec(frame, direction, character['race']), overrides.get(direction, {}))
        views[direction] = partition_frame(frame, spec)
    return {'character': copy.deepcopy(character), 'directions': views, 'review_required': True,
            'source_manifest_sha256': sha(path), 'calibration_sha256': sha(override_path) if override_path.exists() else None}
