"""Register genuine authored extreme-action key poses; never invent cycles.

Threshold alpha, discover actual clear gutters, crop, uniformly nearest-scale,
and place on a shared canvas. Every source PNG stays untouched. The source pose
height never participates in scaling. Production/runtime files are not written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
ROWS = ("slide_entry", "slide_hold", "roll_anticipation", "roll_tuck",
        "jumpsquat", "jump_rise", "fall", "land")
DIRECTIONS = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
CELL, PIVOT = (128, 128), (64, 104)
CATALOG = REPO / "art_batches/character_cast_v1/catalog.json"
TARGET_HEAD_HEIGHT = 18.0
HEAD_WIDTHS = {
    # Explicit comparable crown-free cranial-width estimates reviewed against
    # current 96px reference cells, then its anatomical core calibration.
    "s_wayne": {"source": 66, "reference": 22, "frame": "slide_entry/S", "source_span": [64, 130], "confidence": "medium; hair-side envelope used consistently with reference cap"},
    "oh_tipi": {"source": 54, "reference": 18, "frame": "slide_entry/S", "source_span": [50, 104], "confidence": "medium; cranial face span beneath lateral fins, excludes tall central crest"},
    "red_baron": {"source": 34, "reference": 14, "frame": "slide_entry/S", "source_span": [76, 110], "confidence": "medium; visible cheekbone width below crown compared with reference skull, crown excluded"},
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def pixel_sha(image): return hashlib.sha256(image.tobytes()).hexdigest()
def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True)+"\n", encoding="utf-8")


def occupied_bands(values):
    """Exact connected projection bands, not evenly divided nominal cells."""
    result = []
    start = previous = None
    for value in values:
        if start is None:
            start = previous = value
        elif value == previous+1:
            previous = value
        else:
            result.append((start, previous+1))
            start = previous = value
    if start is not None:
        result.append((start, previous+1))
    return result


def disconnected_parts(alpha, top, bottom):
    active={(x,y) for y in range(top,bottom) for x in range(alpha.width) if alpha.getpixel((x,y))}
    parts=[]
    while active:
        queue=[active.pop()]
        points=set()
        while queue:
            x,y=queue.pop()
            points.add((x,y))
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                point=(x+dx,y+dy)
                if point in active:
                    active.remove(point)
                    queue.append(point)
        parts.append(points)
    require(len(parts)==8 and all(len(p)>100 for p in parts), "Fallback requires exactly eight disconnected complete body components")
    parts.sort(key=lambda p:sum(x for x,y in p)/len(p))
    return parts


def component_runs(points):
    result=[]
    for y in sorted({p[1] for p in points}):
        for left,right in occupied_bands(sorted(x for x,py in points if py==y)):
            result.append([y,left,right])
    return result


def discover_rects(image, threshold=127):
    require(image.mode == "RGBA", "Source must be explicit RGBA")
    alpha = image.getchannel("A").point(lambda a: 255 if a >= threshold else 0)
    require(alpha.getextrema() == (0, 255), "Source needs actual transparency and body pixels")
    rows = occupied_bands(y for y in range(image.height) if alpha.crop((0,y,image.width,y+1)).getbbox())
    require(len(rows) == 8, f"Expected eight clear horizontal source bands, got {len(rows)}; manual registration required")
    rects, gutters, ownership = {}, [], {}
    for row_index, (top, bottom) in enumerate(rows):
        columns = occupied_bands(x for x in range(image.width) if alpha.crop((x,top,x+1,bottom)).getbbox())
        if len(columns) != 8:
            # Explicit exception: boxes may overlap where disconnected bodies
            # interleave. Preserve exact pixels with disjoint component masks.
            parts=disconnected_parts(alpha,top,bottom)
            gutters.append({"row":ROWS[row_index],"occupied_y":[top,bottom],"registration_exception":"disconnected_opaque_components_with_overlapping_transparent_bounding_rectangles","opaque_pixels":sum(len(p) for p in parts)})
            for direction,points in zip(DIRECTIONS,parts):
                xs=[p[0] for p in points];ys=[p[1] for p in points]
                left,right,upper,lower=min(xs),max(xs)+1,min(ys),max(ys)+1
                require(left>=2 and upper>=2 and right+2<=image.width and lower+2<=image.height,"Component touches source edge")
                key=ROWS[row_index]+"/"+direction
                rects[key]=[left-2,upper-2,right-left+4,lower-upper+4]
                ownership[key]=component_runs(points)
            continue
        row_top = 0 if row_index == 0 else (rows[row_index-1][1]+top)//2
        row_bottom = image.height if row_index == 7 else (bottom+rows[row_index+1][0])//2
        gutters.append({"row": ROWS[row_index], "occupied_y": [top,bottom], "occupied_x": columns})
        for direction, (left,right) in zip(DIRECTIONS, columns):
            col = DIRECTIONS.index(direction)
            cell_left = 0 if col == 0 else (columns[col-1][1]+left)//2
            cell_right = image.width if col == 7 else (right+columns[col+1][0])//2
            # Tight two-pixel margin, bounded by actual zero-alpha gutters.
            x, y = max(cell_left,left-2), max(row_top,top-2)
            end_x, end_y = min(cell_right,right+2), min(row_bottom,bottom+2)
            require(x < left and y < top and end_x > right and end_y > bottom, "No transparent margin between authored poses")
            rects[ROWS[row_index]+"/"+direction] = [x,y,end_x-x,end_y-y]
    return rects, gutters, ownership


def owned_alpha(image, rect, threshold, runs=None):
    x,y,w,h=rect
    alpha=image.getchannel("A").crop((x,y,x+w,y+h)).point(lambda a:255 if a>=threshold else 0)
    if runs is None:
        return alpha
    mask=Image.new("L",(w,h))
    for py,left,right in runs:
        require(y<=py<y+h and x<=left<right<=x+w,"Ownership run outside crop")
        for px in range(left,right):
            require(alpha.getpixel((px-x,py-y))==255,"Ownership run includes transparent source pixel")
            mask.putpixel((px-x,py-y),255)
    return mask


def known_characters():
    """Current named identities only; historical labels do not grant new IDs."""
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    characters = catalog.get("characters", [])
    require(isinstance(characters, list), "Invalid current character catalog")
    ids = [c.get("id") for c in characters if isinstance(c, dict)]
    require(len(ids) == len(characters) and all(isinstance(i, str) and i and i == Path(i).name and "/" not in i and "\\" not in i and i not in (".", "..") for i in ids), "Invalid catalog character ID")
    require(len(set(ids)) == len(ids), "Duplicate catalog character ID")
    return set(ids)


def validate_measurement(measurement, source_dimensions=None):
    """Explicit cranial dimensions, never inferred from whole-body alpha bounds.

    Height means skull crown to chin, excluding hair, horns, crown, fins and
    other ornament. Source width is optional audit metadata, NOT a second fit.
    """
    require(isinstance(measurement, dict), "Head measurement must be an object")
    allowed = {"source_head_height", "source_head_width", "target_head_height", "frame", "notes", "confidence", "measured_by"}
    require(not set(measurement)-allowed, "Unknown head measurement field")
    height = measurement.get("source_head_height")
    require(isinstance(height, (int, float)) and not isinstance(height, bool) and math.isfinite(height) and height > 0, "Invalid source cranial head height")
    target = measurement.get("target_head_height", TARGET_HEAD_HEIGHT)
    require(isinstance(target, (int, float)) and not isinstance(target, bool) and math.isfinite(target) and 16 <= target <= 20, "Target cranial height must be approximately18px (16..20)")
    scale = target/height
    require(0 < scale < 2, "Measured head gives unsupported uniform scale")
    frame = measurement.get("frame", "slide_entry/S")
    require(frame in {row+"/"+direction for row in ROWS for direction in DIRECTIONS}, "Head measurement frame is not an authored key")
    normalized = dict(measurement)
    normalized.update(source_head_height=float(height), target_head_height=float(target), frame=frame,
                      policy="explicit_cranial_measurement_excludes_ornament_not_alpha_bbox")
    for field in ("notes", "confidence", "measured_by"):
        if field in measurement:
            require(isinstance(measurement[field], str) and bool(measurement[field].strip()), "Invalid measurement annotation: "+field)
    if "source_head_width" in measurement:
        width = measurement["source_head_width"]
        require(isinstance(width, (int, float)) and not isinstance(width, bool) and math.isfinite(width) and width > 0, "Invalid source cranial head width")
        normalized["source_head_width"] = float(width)
        normalized["predicted_target_head_width"] = float(width)*scale
    if source_dimensions is not None:
        require(height <= source_dimensions[1], "Head measurement exceeds source height")
        require(measurement.get("source_head_width", 0) <= source_dimensions[0], "Head measurement exceeds source width")
    return normalized, scale


def register_source(character_id, source, measurement=None):
    require(character_id in known_characters(), "Unknown current character ID")
    require(measurement is not None or character_id in HEAD_WIDTHS, "New character sources require explicit cranial head measurement")
    source = Path(source).resolve()
    require(source.is_relative_to(REPO.resolve()), "Preserve authored source inside repository before registration")
    if measurement is not None:
        validate_measurement(measurement)
    with Image.open(source) as opened:
        image = opened.copy()
    rects, gutters, ownership = discover_rects(image)
    calibration_path = HERE / "calibration_overrides.json"
    if measurement is None:
        # Historical three-pilot rebuilds intentionally retain their exact
        # recorded width/core calibration and recipe fields.
        measure = HEAD_WIDTHS[character_id]
        require(not measure["confidence"].startswith("pending"), "Head calibration still awaits source review")
        calibration = json.loads(calibration_path.read_text())["calibration"][character_id]
        scale = measure["reference"]*calibration["recommended_uniform_scale"]/measure["source"]
        scale_fields = {"calibration_sha256":sha(calibration_path),
                        "scale_policy":"one_character_scale_from_reference_cranial_width_and_anatomical_core_calibration_not_pose_height",
                        "head_measurement":measure, "reference_anatomical_height":calibration["anatomical_height"],
                        "target_anatomical_height":calibration["target_height"]}
    else:
        measure, scale = validate_measurement(measurement, image.size)
        measured_rect = rects[measure["frame"]]
        require(measure["source_head_height"] <= measured_rect[3], "Cranial head height exceeds declared measurement frame")
        require(measure.get("source_head_width", 0) <= measured_rect[2], "Cranial head width exceeds declared measurement frame")
        scale_fields = {"scale_policy":"one_character_scale_from_explicit_cranial_height_preserve_authored_head_body_ratio_not_pose_height",
                        "head_measurement":measure, "catalog_sha256":sha(CATALOG),
                        "measurement_status":"explicit_source_measurement_requires_native_visual_review",
                        "source_proportions_preserved":True}
    recipe = {"schema_version":1, "character_id":character_id, "source_png":str(source.relative_to(REPO)),
              "source_sha256":sha(source), "source_dimensions":list(image.size), "alpha_threshold":127,
              "rows":list(ROWS), "directions":list(DIRECTIONS), "cell":list(CELL), "pivot":list(PIVOT),
              "uniform_scale":scale, **scale_fields, "gutter_measurements":gutters,
              "frames":{}, "holds":["Authored key poses, not continuous animation cycles", "Exact directional yaw and skull-scale consistency require native visual review", "Sole-band anchor registration is provisional for airborne poses; runtime jump height is separate", "No per-pose scaling or inferred motion coverage"]}
    for key, rect in rects.items():
        part = image.crop((rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3]))
        alpha = owned_alpha(image,rect,127,ownership.get(key))
        bounds = alpha.getbbox()
        band = max(2, round((bounds[3]-bounds[1])*.035))
        xs = [x for y in range(bounds[3]-band,bounds[3]) for x in range(part.width) if alpha.getpixel((x,y))]
        require(xs, "No lower support-band pixels")
        # Translation only: no fitted pose height or width.
        anchor = [(min(xs)+max(xs)+1)/2,bounds[3]]
        recipe["frames"][key] = {"rect":rect,"support_anchor":anchor,"source_alpha_bounds":list(bounds)}
        if key in ownership:
            recipe["frames"][key]["source_owned_runs"]=ownership[key]
    return recipe


def assemble(recipe, source):
    source = Path(source).resolve()
    require(sha(source) == recipe["source_sha256"], "Authored key source hash mismatch")
    require(recipe["rows"] == list(ROWS) and recipe["directions"] == list(DIRECTIONS), "Action row/direction contract mismatch")
    scale = recipe.get("uniform_scale")
    require(isinstance(scale,(int,float)) and not isinstance(scale,bool) and math.isfinite(scale) and 0<scale<2, "Invalid uniform character scale")
    expected = {row+"/"+direction for row in ROWS for direction in DIRECTIONS}
    require(set(recipe["frames"]) == expected, "Expected all64 unique authored keys")
    with Image.open(source) as opened:
        image = opened.copy()
    require(image.mode == "RGBA", "Source must have explicit alpha")
    require(list(image.size) == recipe["source_dimensions"], "Source dimensions differ")
    cells, records, rects, owned_pixels = {}, [], [], set()
    for row_index,row in enumerate(ROWS):
        for direction_index,direction in enumerate(DIRECTIONS):
            key=row+"/"+direction
            entry=recipe["frames"][key]
            rect=entry["rect"]
            require(isinstance(rect,list) and len(rect)==4 and all(type(v) is int for v in rect), "Invalid crop rectangle")
            x,y,w,h=rect
            require(0<=x and 0<=y and w>0 and h>0 and x+w<=image.width and y+h<=image.height, "Out-of-source crop")
            has_mask="source_owned_runs" in entry
            require(all(x+w<=a or a+c<=x or y+h<=b or b+d<=y or (has_mask and masked) for a,b,c,d,masked in rects), "Overlapping authored key crops without explicit disjoint ownership")
            rects.append([x,y,w,h,has_mask])
            part=image.crop((x,y,x+w,y+h))
            alpha=owned_alpha(image,rect,recipe["alpha_threshold"],entry.get("source_owned_runs"))
            for py in range(h):
                for px in range(w):
                    if alpha.getpixel((px,py)):
                        point=(x+px,y+py)
                        require(point not in owned_pixels,"Source pixel claimed by two authored poses")
                        owned_pixels.add(point)
            bounds=alpha.getbbox()
            require(bounds and 0<bounds[0] and 0<bounds[1] and bounds[2]<w and bounds[3]<h,"Clipped authored source pose")
            part.putalpha(alpha)
            clean=Image.new("RGBA",part.size)
            clean.paste(part,(0,0),alpha)
            size=(max(1,round(w*scale)),max(1,round(h*scale)))
            resized=clean.resize(size,Image.Resampling.NEAREST)
            anchor=entry["support_anchor"]
            require(isinstance(anchor,list) and len(anchor)==2 and all(isinstance(v,(int,float)) and math.isfinite(v) for v in anchor), "Invalid support anchor")
            require(0<=anchor[0]<w and 0<anchor[1]<=h,"Support anchor outside crop")
            offset=(PIVOT[0]-round(anchor[0]*scale),PIVOT[1]-round(anchor[1]*scale))
            scaled_bounds=resized.getbbox()
            require(scaled_bounds,"Uniform scale erased authored key")
            correction=PIVOT[1]-(offset[1]+scaled_bounds[3])
            require(abs(correction)<=1,"Unexpected source-foot registration discrepancy")
            offset=(offset[0],offset[1]+correction)
            placed=(offset[0]+scaled_bounds[0],offset[1]+scaled_bounds[1],offset[0]+scaled_bounds[2],offset[1]+scaled_bounds[3])
            require(0<placed[0] and 0<placed[1] and placed[2]<128 and placed[3]==104,"Keypose outside canvas; revise source, never shrink this pose")
            cell=Image.new("RGBA",CELL)
            cell.alpha_composite(resized,offset)
            cells[key]=cell
            records.append({"key":key,"row":row,"direction":direction,"rect":[direction_index*128,row_index*128,128,128],"rgba_sha256":pixel_sha(cell),"bounds":list(cell.getbbox()),"uniform_scale":scale,"source_rect":rect,"support_rounding_correction":correction})
    require(len({pixel_sha(cell) for cell in cells.values()})==64,"Duplicate authored keys detected; no cloned coverage")
    source_alpha=image.getchannel("A")
    expected_opaque=sum(source_alpha.histogram()[recipe["alpha_threshold"]:])
    require(len(owned_pixels)==expected_opaque,"Opaque source-pixel conservation failed")
    return cells,records


def build_key_atlas(character_id,source,out,measurement=None):
    """Build one measured character; never replace existing recipes/identities."""
    require(character_id in known_characters(), "Unknown current character ID")
    out=Path(out).resolve()
    allowed=HERE/"output"
    require(out.is_relative_to(allowed.resolve()),"Output must stay in character_motion_v1/output")
    atlas_path=out/(character_id+"-action-keys.png")
    require(not atlas_path.exists(),"Refusing to overwrite existing key atlas")
    recipe_dir=HERE/"action-recipes"
    recipe_path=recipe_dir/(character_id+".json")
    require(not recipe_path.exists(),"Refusing to overwrite prior measured recipe")
    recipe=register_source(character_id,source,measurement)
    cells,records=assemble(recipe,source)
    out.mkdir(parents=True,exist_ok=True)
    atlas=Image.new("RGBA",(1024,1024))
    for record in records:
        atlas.paste(cells[record["key"]],tuple(record["rect"][:2]))
    atlas.save(atlas_path)
    recipe_dir.mkdir(exist_ok=True)
    write_json(recipe_path,recipe)
    manifest_path=out/"manifest.json"
    manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "schema_version":1,"factory":"character_authored_action_keys_v1","cell":list(CELL),"pivot":list(PIVOT),
        "rows":list(ROWS),"directions":list(DIRECTIONS),"production_ready":False,"human_approved":False,
        "animation_status":"eight_authored_action_keyposes_not_complete_cycles","characters":[]}
    require(not any(c["id"]==character_id for c in manifest["characters"]),"Duplicate character in combined manifest")
    character={"id":character_id,"atlas":atlas_path.name,"atlas_sha256":sha(atlas_path),"atlas_dimensions":[1024,1024],
               "recipe":str(recipe_path.relative_to(REPO)),"recipe_sha256":sha(recipe_path),"source_sha256":recipe["source_sha256"],
               "uniform_scale":recipe["uniform_scale"],"rows":list(ROWS),"frames":records,"keyposes":64,"complete_cycles":False,"holds":recipe["holds"]}
    manifest["characters"].append(character)
    write_json(manifest_path,manifest)
    (out/".gdignore").touch()
    board=Image.new("RGB",(1024,1088),"#ddd0b0")
    draw=ImageDraw.Draw(board)
    draw.text((8,8),character_id+" / AUTHORED EXTREME KEYS / NOT COMPLETE CYCLES",fill="#2a2231")
    for i,direction in enumerate(DIRECTIONS): draw.text((i*128+60,28),direction,fill="#2a2231")
    board.paste(atlas,(0,64),atlas)
    board.save(out/(character_id+"-action-board.png"))
    return character


def write_combined_review(out):
    out=Path(out).resolve()
    require(out.is_relative_to((HERE/"output").resolve()),"Review must stay in staged output")
    manifest=json.loads((out/"manifest.json").read_text())
    characters=sorted(manifest["characters"],key=lambda c:("s_wayne","oh_tipi","red_baron").index(c["id"]))
    require(len(characters)==3,"Combined review needs all three pilots")
    target=out/"all-three-action-keys.png"
    require(not target.exists(),"Refusing to overwrite combined review")
    board=Image.new("RGB",(3*1024,1110),"#ddd0b0")
    draw=ImageDraw.Draw(board)
    for col,character in enumerate(characters):
        atlas_path=out/character["atlas"]
        require(sha(atlas_path)==character["atlas_sha256"],"Review atlas hash mismatch")
        with Image.open(atlas_path) as atlas:
            board.paste(atlas,(col*1024,86),atlas)
        draw.text((col*1024+8,8),character["id"]+" / 64 AUTHORED KEYS / NOT COMPLETE CYCLES",fill="#2a2231")
        draw.text((col*1024+8,28),"Fixed character scale: "+str(round(character["uniform_scale"],6)),fill="#2a2231")
        for i,direction in enumerate(DIRECTIONS):draw.text((col*1024+i*128+58,58),direction,fill="#2a2231")
        for i,row in enumerate(ROWS):draw.text((col*1024+3,88+i*128),row,fill="#2a2231")
    board.save(target)
    write_json(out/"registration-receipt.json",{"status":"PASS_OFFLINE_REGISTRATION","characters":3,"authored_keys":192,
               "rows":list(ROWS),"directions":list(DIRECTIONS),"uniform_scales":{c["id"]:c["uniform_scale"] for c in characters},
               "source_pixel_ownership":"thresholded alpha exact disjoint conservation checked during all three reassemblies",
               "oh_tipi_exception":"Eight disconnected component masks replace impossible nonoverlapping rectangular gutters in slide_hold",
               "tests":11,"tests_command":"python -m unittest discover -s tests/art -p test_character_action_keys.py -v",
               "native_validation":"NOT_RUN_BY_WORKER","visual_approval":False,"production_ready":False,"complete_cycles":False})
    return target


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("character_pos",nargs="?")
    parser.add_argument("source_pos",nargs="?")
    parser.add_argument("--character")
    parser.add_argument("--source")
    parser.add_argument("--head-height",type=float,help="Explicit source skull-crown-to-chin pixels, excluding hair/horns/ornament")
    parser.add_argument("--head-width",type=float,help="Optional cranial width audit measurement; does not independently rescale")
    parser.add_argument("--target-head-height",type=float)
    parser.add_argument("--measurement-frame")
    parser.add_argument("--measurement-json",help="Explicit per-character source measurement object")
    parser.add_argument("--out",required=True)
    args=parser.parse_args()
    if args.character and args.character_pos and args.character != args.character_pos:
        parser.error("Conflicting positional/optional character IDs")
    if args.source and args.source_pos and args.source != args.source_pos:
        parser.error("Conflicting positional/optional source paths")
    character, source = args.character or args.character_pos, args.source or args.source_pos
    if not character or not source:
        parser.error("Provide character and source, positionally or using --character and --source")
    measurement = None
    if args.measurement_json:
        if any(value is not None for value in (args.head_height,args.head_width,args.target_head_height,args.measurement_frame)):
            parser.error("Use either --measurement-json or individual head measurements")
        measurement = json.loads(Path(args.measurement_json).read_text(encoding="utf-8"))
    elif args.head_height is not None:
        measurement = {"source_head_height":args.head_height,"target_head_height":TARGET_HEAD_HEIGHT if args.target_head_height is None else args.target_head_height,"frame":args.measurement_frame or "slide_entry/S"}
        if args.head_width is not None: measurement["source_head_width"] = args.head_width
    elif any(value is not None for value in (args.head_width,args.target_head_height,args.measurement_frame)):
        parser.error("Individual measurement options require --head-height; width alone does not define new-character scale")
    result=build_key_atlas(character,source,args.out,measurement)
    print(json.dumps({k:result[k] for k in ("id","atlas","keyposes","uniform_scale","complete_cycles")},indent=2))
