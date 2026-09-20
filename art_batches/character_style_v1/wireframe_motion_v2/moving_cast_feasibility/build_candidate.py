"""Pack one candidate Large gait page; never writes any W2 runtime asset."""
import hashlib
import copy
import importlib.util
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
W2 = HERE.parent
spec = importlib.util.spec_from_file_location("w2_baker", W2 / "build.py")
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)
WIDTH, HEIGHT = 1536, 3072
STAGES = ("neutral", "preparation", "recovery")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key(pose):
    return (pose["travel"], pose["aim"], pose["phase"], pose["upper_pose"])


def pack(cells):
    # Deterministic best-fit shelves; one transparent pixel on every side.
    unique = {}
    frame_keys = {}
    for frame_key, cell in cells.items():
        crop = cell.getbbox()
        tile = cell.crop(crop)
        digest = hashlib.sha256(tile.tobytes()).hexdigest()+f"/{tile.width}/{tile.height}"
        if digest not in unique:
            unique[digest] = {"image":tile,"w":tile.width+2,"h":tile.height+2}
        frame_keys[frame_key] = (digest,crop)
    shelves = []
    next_y = 0
    atlas = Image.new("RGBA",(WIDTH,HEIGHT))
    for digest,item in sorted(unique.items(),key=lambda pair:(-pair[1]["h"],-pair[1]["w"],pair[0])):
        fits = [row for row in shelves if row["height"] >= item["h"] and WIDTH-row["x"] >= item["w"]]
        if fits:
            row = min(fits,key=lambda candidate:(WIDTH-candidate["x"]-item["w"],candidate["y"]))
        else:
            assert next_y+item["h"] <= HEIGHT, f"Candidate cannot fit fixed page: needs beyond y={next_y+item['h']}"
            row = {"x":0,"y":next_y,"height":item["h"]}
            shelves.append(row)
            next_y += item["h"]
        item["region"] = [row["x"]+1,row["y"]+1,item["image"].width,item["image"].height]
        atlas.paste(item["image"],tuple(item["region"][:2]))
        row["x"] += item["w"]
    frames = []
    for frame_key,cell in cells.items():
        digest,crop = frame_keys[frame_key]
        region = unique[digest]["region"]
        restored = Image.new("RGBA",(96,96))
        restored.paste(atlas.crop((region[0],region[1],region[0]+region[2],region[1]+region[3])),crop[:2])
        assert restored.tobytes() == cell.tobytes()
        frames.append({"travel":frame_key[0],"aim":frame_key[1],"phase":frame_key[2],"upper_pose":frame_key[3],
                       "region":region,"crop_offset":list(crop[:2]),"logical_size":[96,96],
                       "margin":[crop[0],crop[1],96-region[2],96-region[3]],
                       "rgba_sha256":hashlib.sha256(cell.tobytes()).hexdigest()})
    return atlas,frames,{"unique_crops":len(unique),"stored_frames":len(frames),"occupied_shelf_height":next_y,
                         "crop_rectangle_pixels":sum(item["image"].width*item["image"].height for item in unique.values()),
                         "page_pixels":WIDTH*HEIGHT,"one_pixel_gutters":True,"rotation":False}


def main():
    data = json.loads((HERE/"candidate-rig.json").read_text(encoding="utf-8"))
    assert data["w2_rig_sha256"] == sha(W2/"rig-data.json")
    assert data["w2_runtime_manifest_sha256"] == sha(baker.OUT/"manifest.json")
    current = json.loads((W2/"rig-data.json").read_text(encoding="utf-8"))
    original = {(p["travel"],p["aim"],p["phase"]):p for p in current["poses"] if p["body"]=="large" and p["state"]=="locomotion"}
    runtime_page = Image.open(baker.OUT/"large-locomotion.png").convert("RGBA")
    cells = {}
    leg_checks = bone_checks = 0
    for delta in data["poses"]:
        frame_key = (int(delta["travel"]),int(delta["aim"]),int(delta["phase"]),delta["upper_pose"])
        assert frame_key not in cells
        source = original[frame_key[:3]]
        pose = copy.deepcopy(source)
        pose["upper_pose"] = delta["upper_pose"]
        for field in ("landmarks","points"):
            for joint,value in delta[field].items():
                assert joint in ("elbow_l","hand_l","elbow_r","hand_r")
                pose[field][joint] = value
        for chain in pose["chains"]:
            if chain["kind"] == "arm" and chain["side"] in delta["arm_depths"]:
                chain["depth"] = delta["arm_depths"][chain["side"]]
        pose["chains"].sort(key=lambda chain:chain["depth"])
        for joint in source["landmarks"]:
            if joint.startswith(("elbow_","hand_")):
                continue
            assert pose["landmarks"][joint] == source["landmarks"][joint],(frame_key,joint)
            assert pose["points"][joint] == source["points"][joint],(frame_key,joint,"pixel anchor")
            leg_checks += 1
        for side in ("l","r"):
            for a,b,length in (("shoulder","elbow","humerus"),("elbow","hand","forearm"),("hip","knee","thigh"),("knee","ankle","shin"),("ankle","toe","foot")):
                assert abs(math.dist(pose["landmarks"][a+"_"+side],pose["landmarks"][b+"_"+side])-data["bone_lengths"][length]) < 0.00001
                bone_checks += 1
        cell = baker.render(pose,current)
        assert cell.getbbox()[3] == 84
        assert set(cell.getchannel("A").getdata()) <= {0,255}
        if pose["upper_pose"] == "neutral":
            index=(pose["travel"]*8+pose["aim"])*8+pose["phase"]
            x,y=index%16*96,index//16*96
            assert cell.tobytes() == runtime_page.crop((x,y,x+96,y+96)).tobytes(),("neutral changed",frame_key)
        cells[frame_key] = cell
    assert len(cells) == 1536
    for travel in range(8):
        for aim in range(8):
            for phase in range(8):
                assert len({cells[(travel,aim,phase,stage)].tobytes() for stage in STAGES}) == 3,(travel,aim,phase)
    atlas,frames,packing = pack(cells)
    atlas.save(HERE/"large-walk-three-upper-poses.png")
    metadata = {"candidate_only":True,"scope":"Large walk only; 64 travel/aim pairs x8 phases x3 upper poses",
                "page":"large-walk-three-upper-poses.png","dimensions":[WIDTH,HEIGHT],"page_sha256":sha(HERE/"large-walk-three-upper-poses.png"),
                "page_rgba_sha256":hashlib.sha256(atlas.tobytes()).hexdigest(),"logical_size":[96,96],"pivot":[48,84],
                "w2_runtime_manifest_sha256":sha(baker.OUT/"manifest.json"),"w2_rig_sha256":sha(W2/"rig-data.json"),"frames":frames}
    (HERE/"candidate-manifest.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf",13)
    for theme,color,ink in (("light","#ddd1b7","#382b20"),("dark","#201e1d","#ead7aa")):
        board = Image.new("RGB",(900,342),color)
        draw = ImageDraw.Draw(board)
        draw.text((8,8),"CANDIDATE ONLY / LARGE WALK EAST / SAME LEG PHASE1 / THREE UPPER POSES",font=font,fill=ink)
        for row,stage in enumerate(STAGES):
            draw.text((8,78+96*row),stage.upper(),font=font,fill=ink)
            for aim,label in enumerate(baker.SHORT):
                if row == 0:
                    draw.text((128+96*aim,30),label,font=font,fill=ink)
                cell=cells[(2,aim,1,stage)]
                board.paste(cell,(128+96*aim,48+96*row),cell)
        board.save(HERE/f"candidate-native-{theme}.png")
        board.resize((board.width*4,board.height*4),Image.Resampling.NEAREST).save(HERE/f"candidate-4x-{theme}.png")
    evidence = {"status":"offline_packing_and_reference_roundtrip_passed_pending_engine_view_test",
                "packing":packing,"unchanged_non_arm_landmark_and_pixel_anchor_checks":leg_checks,"fixed_bone_checks":bone_checks,
                "neutral_frames_byte_identical_to_w2":512,"all_512_phase_keys_have_three_distinct_upper_poses":True,
                "python_logical_96px_roundtrips":len(frames),"candidate_decoded_mib":WIDTH*HEIGHT*4/1048576,
                "live_runtime_modified":False,"w2_runtime_manifest_sha256":sha(baker.OUT/"manifest.json"),
                "candidate_manifest_sha256":sha(HERE/"candidate-manifest.json"),"atlas_texture_engine_result":"not run"}
    (HERE/"packing-evidence.json").write_text(json.dumps(evidence,indent=2)+"\n",encoding="utf-8")
    print(f"PASS: 1536 frames in unchanged {WIDTH}x{HEIGHT} page; {packing}; {bone_checks} fixed bones; {leg_checks} unchanged non-arm anchors")


if __name__ == "__main__":
    main()
