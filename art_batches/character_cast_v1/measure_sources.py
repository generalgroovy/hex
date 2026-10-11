"""Read-only measurement of generated alpha-separated body turnarounds.

Outputs recipe candidates to stdout; it does not draw, color-key, modify source
images, or write recipe files. A lead must visually review and save candidates.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

DIRECTIONS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
ROWS = [
    ["oh_tipi", "s_wayne", "red_baron", "steezo", "treevor_mason"],
    ["oll_i", "fluup", "wa_bidi", "grace_reava", "nico_lai"],
    ["spai_si", "leaf_hidden", "ha_rekt", "dr_apex", "haara"],
    ["hesus_christo", "grimm_bow", "biggy_bob", "jan_wicked", "ba_djoh"],
    ["urzh", "donnok", "djonah_thaan", "sai_laas", "luuh_i_zeh"],
    ["juul_i_yaina", "faab_i_yaina", "joh_haynes", "h_le_ne", "fimu_yashiha"],
]


def valleys(counts, cells, radius):
    """Find a transparent cut near each expected regular-grid boundary."""
    length = len(counts)
    cuts = [0]
    for index in range(1, cells):
        expected = round(length * index / cells)
        low, high = max(cuts[-1] + 1, expected - radius), min(length, expected + radius)
        section = counts[low:high]
        zeros = np.flatnonzero(section == 0) + low
        if not len(zeros):
            raise ValueError(f"No transparent boundary around {expected}; manual source repair required")
        # Center a transparent gutter, rather than selecting its near edge.
        # This retains transparent border pixels on both adjacent crops.
        runs = np.split(zeros, np.flatnonzero(np.diff(zeros) > 1) + 1)
        centers = [int((run[0] + run[-1]) // 2) for run in runs if len(run) >= 3]
        if not centers:
            raise ValueError(f"No >=3px transparent gutter around {expected}")
        cuts.append(min(centers, key=lambda value: abs(value - expected)))
    return cuts + [length]


def measure(path: Path, sheet: int):
    image = Image.open(path).convert("RGBA")
    alpha = np.asarray(image.getchannel("A"))
    mask = alpha >= 127
    # Columns can be independently split when one tall figure intrudes into a
    # neighboring row's vertical extent. This never cuts a silhouette.
    try:
        row_cuts = valleys(mask.sum(axis=1), 5, 80)
    except ValueError:
        return measure_components(path, sheet, image, mask)
    results = []
    for row, character_id in enumerate(ROWS[sheet - 1]):
        y0, y1 = row_cuts[row:row + 2]
        col_cuts = valleys(mask[y0:y1].sum(axis=0), 8, 65)
        parts = {}
        evidence = {}
        for col, direction in enumerate(DIRECTIONS):
            x0, x1 = col_cuts[col:col + 2]
            yy, xx = np.nonzero(mask[y0:y1, x0:x1])
            if not len(xx):
                raise ValueError(f"Empty {character_id}/{direction}")
            left, right = int(xx.min()) + x0, int(xx.max()) + x0 + 1
            top, bottom = int(yy.min()) + y0, int(yy.max()) + y0 + 1
            if left <= x0 or right >= x1 or top <= y0 or bottom >= y1:
                raise ValueError(f"Clipped source {character_id}/{direction}: {(left,top,right,bottom)}")
            border = min(2, left-x0, x1-right, top-y0, y1-bottom)
            rect = [left-border, top-border, right-left+border*2, bottom-top+border*2]
            # Foot registration uses the actual lowest occupied band; anatomy
            # (wings/horns/tails) never changes source scale per facing.
            band = max(3, round((bottom-top) * .035))
            _, feet_x = np.nonzero(mask[bottom-band:bottom, left:right])
            anchor_x = left + (int(feet_x.min()) + int(feet_x.max()) + 1) / 2
            parts[direction] = {"rect": rect, "ground_anchor": [round(anchor_x-rect[0]), bottom-rect[1]]}
            evidence[direction] = {"opaque_bounds": [left,top,right,bottom], "opaque_pixels": int(len(xx)), "foot_band_pixels": band}
        front = evidence["S"]["opaque_bounds"]
        results.append({
            "schema_version": 1, "character_id": character_id,
            "directions": DIRECTIONS, "source_png": "../reference/" + path.name,
            "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "alpha_threshold": 127, "reference_body_height": front[3]-front[1],
            "body_parts": parts,
            "measurement_notes": "Alpha127 only, no color key; transparent row/column valleys then actual silhouette bounds with transparent border. One front crown-to-sole height calibrates all eight directions; no per-frame bbox fitting. Ground anchor uses lowest3.5% foot band midpoint. Anatomical crowns/horns are included in initial calibration pending review.",
            "visual_holds": ["Idle directional candidate only; no walk, run, slide, roll, jump or cast animation authored by this source.", "Exact 45-degree rear quarters require visual review; source may repeat neighboring silhouette.", "Same-size anatomy volume, facing foot registration and crown-inclusive calibration require rendered review before game integration."],
            "source_measurements": {"size": list(image.size), "alpha_extrema": list(image.getchannel("A").getextrema()), "row_cuts": row_cuts, "column_cuts": col_cuts, "directions": evidence},
        })
    return results


def measure_columnwise(path, sheet, image, mask):
    col_cuts = valleys(mask.sum(axis=0), 8, 65)
    columns = []
    for col in range(8):
        x0, x1 = col_cuts[col:col + 2]
        columns.append(valleys(mask[:, x0:x1].sum(axis=1), 5, 80))
    results = []
    for row, character_id in enumerate(ROWS[sheet - 1]):
        parts, evidence = {}, {}
        for col, direction in enumerate(DIRECTIONS):
            x0, x1 = col_cuts[col:col+2]
            y0, y1 = columns[col][row:row+2]
            yy, xx = np.nonzero(mask[y0:y1, x0:x1])
            left, right = int(xx.min())+x0, int(xx.max())+x0+1
            top, bottom = int(yy.min())+y0, int(yy.max())+y0+1
            border = min(2, left-x0, x1-right, top-y0, y1-bottom)
            if border < 1:
                raise ValueError(f"No transparent border {character_id}/{direction}")
            rect = [left-border, top-border, right-left+border*2, bottom-top+border*2]
            band = max(3, round((bottom-top)*.035))
            _, feet_x = np.nonzero(mask[bottom-band:bottom,left:right])
            anchor_x = left+(int(feet_x.min())+int(feet_x.max())+1)/2
            parts[direction] = {"rect":rect,"ground_anchor":[round(anchor_x-rect[0]),bottom-rect[1]]}
            evidence[direction] = {"opaque_bounds":[left,top,right,bottom],"opaque_pixels":int(len(xx)),"foot_band_pixels":band}
        front=evidence["S"]["opaque_bounds"]
        results.append({"schema_version":1,"character_id":character_id,"directions":DIRECTIONS,"source_png":"../reference/"+path.name,"source_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"alpha_threshold":127,"reference_body_height":front[3]-front[1],"body_parts":parts,"measurement_notes":"Alpha127 only, no color key. Transparent column valleys then independent per-column row valleys preserve uneven row heights. Actual opaque bounds plus transparent border; one front crown-to-sole height scales all eight directions; ground anchor midpoint of lowest3.5% band. Crown/horns included pending review.","visual_holds":["Idle directional candidate only; action animations not authored.","Exact45degree rear quarters and per-facing feet registration require visual review."],"source_measurements":{"size":list(image.size),"alpha_extrema":list(image.getchannel('A').getextrema()),"column_cuts":col_cuts,"per_column_row_cuts":columns,"directions":evidence}})
    return results


def connected_boxes(mask):
    """Four-connected horizontal-span union; no source pixel modifications."""
    parent, records, previous = [], [], []
    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index
    for y, line in enumerate(mask):
        switches = np.diff(np.pad(line.astype(np.int8), (1,1)))
        starts, ends = np.flatnonzero(switches == 1), np.flatnonzero(switches == -1)
        current=[]
        pindex=0
        for left,right in zip(starts,ends):
            index=len(parent)
            parent.append(index)
            records.append((int(left),y,int(right),y+1,int(right-left)))
            while pindex<len(previous) and previous[pindex][1]<=left:
                pindex+=1
            check=pindex
            while check<len(previous) and previous[check][0]<right:
                parent[find(index)]=find(previous[check][2])
                check+=1
            current.append((left,right,index))
        previous=current
    groups={}
    for i,(l,t,r,b,area) in enumerate(records):
        root=find(i)
        if root not in groups:
            groups[root]=[l,t,r,b,area]
        else:
            old=groups[root]
            groups[root]=[min(l,old[0]),min(t,old[1]),max(r,old[2]),max(b,old[3]),area+old[4]]
    return list(groups.values())


def measure_components(path,sheet,image,mask):
    boxes=connected_boxes(mask)
    majors=[box for box in boxes if box[4]>1000]
    if len(majors)!=40:
        raise ValueError(f"Expected40 distinct fullbody components, got{len(majors)}")
    majors.sort(key=lambda b:(b[1]+b[3])/2)
    ordered=[]
    for row in range(5):
        ordered.extend(sorted(majors[row*8:row*8+8],key=lambda b:(b[0]+b[2])/2))
    # Detached antialias clusters remain part of their nearest illustrated
    # figure. This is extraction, not an instruction to paint new pixels.
    centers=[((b[0]+b[2])/2,(b[1]+b[3])/2) for b in ordered]
    merged=[list(b) for b in ordered]
    for tiny in (b for b in boxes if b[4]<=1000):
        center=((tiny[0]+tiny[2])/2,(tiny[1]+tiny[3])/2)
        idx=min(range(40),key=lambda i:(centers[i][0]-center[0])**2+(centers[i][1]-center[1])**2)
        old=merged[idx]
        merged[idx]=[min(old[0],tiny[0]),min(old[1],tiny[1]),max(old[2],tiny[2]),max(old[3],tiny[3]),old[4]+tiny[4]]
    results=[]
    for row,character_id in enumerate(ROWS[sheet-1]):
        parts,evidence={},{}
        for col,direction in enumerate(DIRECTIONS):
            left,top,right,bottom,area=merged[row*8+col]
            border=1
            if left<1 or top<1 or right>=image.width or bottom>=image.height:
                raise ValueError(f"Sourceedge {character_id}/{direction}")
            rect=[left-border,top-border,right-left+2*border,bottom-top+2*border]
            local=mask[rect[1]:rect[1]+rect[3],rect[0]:rect[0]+rect[2]]
            if local[0].any() or local[-1].any() or local[:,0].any() or local[:,-1].any():
                raise ValueError(f"Neighborpixels oncropborder {character_id}/{direction}")
            band=max(3,round((bottom-top)*.035))
            _,feet=np.nonzero(mask[bottom-band:bottom,left:right])
            anchor_x=left+(int(feet.min())+int(feet.max())+1)/2
            parts[direction]={"rect":rect,"ground_anchor":[round(anchor_x-rect[0]),bottom-rect[1]]}
            evidence[direction]={"opaque_bounds":[left,top,right,bottom],"opaque_pixels":area,"foot_band_pixels":band}
        front=evidence['S']['opaque_bounds']
        results.append({"schema_version":1,"character_id":character_id,"directions":DIRECTIONS,"source_png":"../reference/"+path.name,"source_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"alpha_threshold":127,"reference_body_height":front[3]-front[1],"body_parts":parts,"measurement_notes":"Alpha127 only, no color key. Forty disconnected fullbody silhouettes measured using run-span component labeling; small detached clusters assigned nearestbody. Crops retain1px transparentborder. One front crown-to-sole calibration across8directions, no per-view fit. Anchorlowest3.5%footband. Source unchanged.","visual_holds":["Idle directional candidate only; actionanimationsnotauthored.","Exact45degree and feetregistration requirevisualreview."],"source_measurements":{"size":list(image.size),"alpha_extrema":list(image.getchannel('A').getextrema()),"component_method":"four_connected_runs_plus_nearest_tiny_clusters","major_component_count":40,"directions":evidence}})
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=int, required=True, choices=range(1,7))
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(measure(args.source, args.sheet), indent=2))
