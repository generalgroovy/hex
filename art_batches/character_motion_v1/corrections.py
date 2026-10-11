"""Authored hidden-clothing underlays for the S. Wayne animation pilot.

The generated correction source supplies actual sleeve/trouser artwork. This
module only crops, masks, bone-aligns with nearest sampling, and assembles it.
It never fabricates primitive joint fills or replaces approved heads/skin.
"""
from __future__ import annotations

import copy
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / 's-wayne-corrections.recipe.json'
DIRECTIONS = ('S','SE','E','NE','N','NW','W','SW')
COMPONENTS = ('arm_l','arm_r','leg_l','leg_r')


def require(value, message):
    if not value:
        raise ValueError(message)


def point(value):
    return isinstance(value, (list,tuple)) and len(value) == 2 and all(
        isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) for v in value)


@lru_cache(maxsize=4)
def load_recipe(path_string):
    path = Path(path_string).resolve()
    spec = json.loads(path.read_text(encoding='utf-8'))
    require(spec.get('schema_version') == 1 and spec.get('character_id') == 's_wayne', 'Wrong correction identity/schema')
    source = (path.parent / spec['source_png']).resolve()
    require(source.is_relative_to(path.parent), 'Correction source escapes recipe directory')
    require(hashlib.sha256(source.read_bytes()).hexdigest() == spec['source_sha256'], 'Correction source hash mismatch')
    require(set(spec['parts']) == {f'{part}/{direction}' for part in COMPONENTS for direction in DIRECTIONS}, 'Incomplete correction directions')
    require(isinstance(spec['alpha_threshold'],int) and 1 <= spec['alpha_threshold'] <= 254, 'Invalid alpha threshold')
    require(isinstance(spec['overlap_pixels'],int) and 0 <= spec['overlap_pixels'] <= 20, 'Invalid joint overlap')
    with Image.open(source) as image:
        require(image.mode == 'RGBA' and list(image.size) == spec['source_size'], 'Correction source format mismatch')
        require(image.getchannel('A').getextrema()[0] == 0, 'Correction source has no transparency')
        normalized = image.copy()
    normalized.putalpha(normalized.getchannel('A').point(lambda a: 255 if a >= spec['alpha_threshold'] else 0))
    result = {}
    for key, item in spec['parts'].items():
        rect = item['rect']
        require(len(rect) == 4 and all(isinstance(v,int) and not isinstance(v,bool) for v in rect), 'Invalid component crop')
        x,y,w,h = rect
        require(0 <= x < x+w <= normalized.width and 0 <= y < y+h <= normalized.height, 'Component crop outside source')
        crop = normalized.crop((x,y,x+w,y+h))
        bounds = crop.getchannel('A').getbbox()
        require(bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < w and bounds[3] < h, 'Component crop clips artwork')
        anchors = item['anchors']
        require(set(anchors) == {'root','joint','end'} and all(point(v) for v in anchors.values()), 'Invalid component anchors')
        require(all(0 <= v[0] < w and 0 <= v[1] < h for v in anchors.values()), 'Component anchor outside crop')
        require(anchors['root'][1] < anchors['joint'][1] < anchors['end'][1], 'Component anchors need root/joint/end order')
        require(all(math.dist(anchors[a],anchors[b]) > 1 for a,b in (('root','joint'),('joint','end'))), 'Degenerate corrective bone')
        result[key] = {'image': crop, 'anchors': copy.deepcopy(anchors)}
    return spec, result


def align_bone(source, source_a, source_b, target_a, target_b):
    """Similarity transform only, never stretch a whole component to a cell."""
    require(source.mode == 'RGBA', 'Corrective source must be RGBA')
    require(all(point(p) for p in (source_a,source_b,target_a,target_b)), 'Invalid alignment anchors')
    sx,sy = source_b[0]-source_a[0], source_b[1]-source_a[1]
    tx,ty = target_b[0]-target_a[0], target_b[1]-target_a[1]
    sl,tl = math.hypot(sx,sy), math.hypot(tx,ty)
    require(sl > .1 and tl > .1, 'Degenerate alignment bone')
    scale = tl/sl
    require(.015 <= scale <= 1, 'Unsafe corrective bone scale')
    angle = math.atan2(ty,tx)-math.atan2(sy,sx)
    c,s = math.cos(angle)/scale, math.sin(angle)/scale
    # Inverse mapping into a padded canvas allows a real clipping check.
    ox,oy = target_a[0]+48,target_a[1]+48
    coeff = (c,s,source_a[0]-c*ox-s*oy,-s,c,source_a[1]+s*ox-c*oy)
    padded = source.transform((192,192), Image.Transform.AFFINE, coeff, Image.Resampling.NEAREST)
    bounds = padded.getchannel('A').getbbox()
    require(bounds and bounds[0] >= 48 and bounds[1] >= 48 and bounds[2] <= 144 and bounds[3] <= 144, 'Corrective layer exceeds96cell')
    return padded.crop((48,48,144,144))


def apply_corrections(view, direction, character_id='s_wayne', recipe_path=None):
    """Return a new view; only S.Wayne has reviewed source correction material.

    Default output keeps every original layer byte-identical and returns a
    correction_underlays mapping. Draw those with corresponding bone transforms
    BEFORE all original layers. Underlays are clipped to the complete original
    rest silhouette, so reassembly at rest is exactly unchanged. Motion reveals
    the source-authored hidden clothing; exposed area still needs visual review.
    """
    require(character_id == 's_wayne', 'No authored correction kit for this character')
    require(direction in DIRECTIONS, 'Unknown correction direction')
    require(view['spec']['direction'] == direction, 'Facing mismatch')
    spec, parts = load_recipe(str(Path(recipe_path or DEFAULT_RECIPE).resolve()))
    output = copy.deepcopy(view)
    silhouette = Image.new('L', (96,96))
    for source_layer in view['layers'].values():
        silhouette = ImageChops.lighter(silhouette, source_layer.getchannel('A'))
    underlays = {}
    applied = []
    for kind in ('arm','leg'):
        for side in ('l','r'):
            part = parts[f'{kind}_{side}/{direction}']
            source, controls = part['image'], part['anchors']
            if kind == 'arm':
                targets = (f'shoulder_{side}',f'elbow_{side}',f'hand_{side}')
                names = (f'upper_arm_{side}',f'forearm_{side}')
            else:
                targets = (f'hip_{side}',f'knee_{side}',f'ankle_{side}')
                names = (f'thigh_{side}',f'shin_{side}')
            for index, name in enumerate(names):
                clipped = source.copy()
                alpha = clipped.getchannel('A')
                low = 0 if index == 0 else round(controls['joint'][1]-spec['overlap_pixels'])
                high = round(controls['joint'][1]+spec['overlap_pixels']) if index == 0 else round(controls['end'][1]+2)
                # Keep actual authored overlap at knees/elbows, but do not
                # replace hands/feet with the kit's different skin rendering.
                for y in range(alpha.height):
                    if y < low or y > high:
                        for x in range(alpha.width): alpha.putpixel((x,y),0)
                clipped.putalpha(alpha)
                source_keys = ('root','joint') if index == 0 else ('joint','end')
                aligned = align_bone(clipped, controls[source_keys[0]], controls[source_keys[1]],
                                     view['anchors'][targets[index]], view['anchors'][targets[index+1]])
                aligned.putalpha(ImageChops.multiply(aligned.getchannel('A'), silhouette))
                underlays[name] = aligned
                applied.append(name)
    output['correction_underlays'] = underlays
    output['receipt']['corrective_art'] = {
        'character_id': character_id, 'source_sha256': spec['source_sha256'],
        'recipe_sha256': hashlib.sha256(Path(recipe_path or DEFAULT_RECIPE).read_bytes()).hexdigest(),
        'layers': applied, 'original_identity_layers_preserved': ['head','hand_l','hand_r','foot_l','foot_r'],
        'method': 'authored clothing, nearest bone-aligned uniform sampling, silhouette-clipped rest mask',
        'render_order': 'all correction_underlays first, then all original layers in their depth order',
        'separate_underlay_pass': True,
        'review_required': True, 'hidden_surfaces': 'authored sleeves/trousers; hands/feet and torso remain original',
    }
    output['receipt']['pixel_conservation'] = True
    output['receipt']['pixel_conservation_scope'] = 'Original partition source pixels retained; authored corrective pixels in separate underlays. At rest, underlays-first then originals is exactly source-identical.'
    output['receipt']['hidden_surfaces'] = 'partial_authored_clothing_corrections_pending_visual_acceptance'
    return output
