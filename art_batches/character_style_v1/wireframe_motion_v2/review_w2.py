"""W2 native readability review and exact-cadence offline motion evidence."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("w2_baker", HERE / "build.py")
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)
PRIOR = HERE / "previous-export-adventurer-volume-v2"
FONT = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 13)


def key(pose):
    return (pose["body"], pose["state"], pose["travel"], pose["aim"], pose["phase"])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preview(body, data):
    poses = {key(p): p for p in data["poses"]}
    for theme,color,ink in (("light","#ddd1b7","#382b20"),("dark","#201e1d","#ead7aa")):
        board = Image.new("RGB", (884,432),color)
        draw = ImageDraw.Draw(board)
        draw.text((8,8),f"W2 {body.upper()} / NATIVE / {baker.DISPLAY_HEIGHTS[body]} PX / SAME BONES AND FOOT PIVOT",font=FONT,fill=ink)
        for aim,label in enumerate(baker.SHORT):
            draw.text((116+96*aim,30),label,font=FONT,fill=ink)
        for row,(state,label) in enumerate((("grounded","STAND"),("locomotion","WALK A:E"),("sprint_locomotion","RUN A:E"),("cast","CAST"))):
            draw.text((8,78+96*row),label,font=FONT,fill=ink)
            motion = state.endswith("locomotion")
            for aim in range(8):
                pose = poses[(body,state,2 if motion else -1,aim,1 if motion else -1)]
                cell = baker.render(pose,data)
                board.paste(cell,(116+96*aim,48+96*row),cell)
        board.save(HERE / f"w2-{body}-native-{theme}.png")
        board.resize((board.width*4,board.height*4),Image.Resampling.NEAREST).save(HERE / f"w2-{body}-4x-{theme}.png")


def proof(data):
    old_data = json.loads((PRIOR / "rig-data.json").read_text(encoding="utf-8"))
    old_poses = {key(p):p for p in old_data["poses"]}
    poses = {key(p):p for p in data["poses"]}
    assert poses.keys() == old_poses.keys() and len(poses) == 3312
    for field in ("bone_lengths","heights","directions","base_rows","head_radius","cell","pivot","phases","rig_sha256"):
        assert data[field] == old_data[field], field
    fixed_landmarks = ("pelvis","head","neck","nose","shoulder_l","shoulder_r","hip_l","hip_r","knee_l","knee_r","ankle_l","ankle_r","toe_l","toe_r")
    for pose_key,pose in poses.items():
        for joint in fixed_landmarks:
            assert pose["landmarks"][joint] == old_poses[pose_key]["landmarks"][joint],(pose_key,joint)
            assert pose["points"][joint] == old_poses[pose_key]["points"][joint],(pose_key,joint,"registration")
    counter_checks = 0
    for body in baker.BODIES:
        for state in ("locomotion","sprint_locomotion"):
            for travel in range(8):
                for aim in range(8):
                    a,b=(poses[(body,state,travel,aim,p)]["landmarks"] for p in (0,4))
                    for side in ("l","r"):
                        hand_delta=[(a["hand_"+side][axis]-a["shoulder_"+side][axis])-(b["hand_"+side][axis]-b["shoulder_"+side][axis]) for axis in range(3)]
                        foot_delta=[a["ankle_"+side][axis]-b["ankle_"+side][axis] for axis in range(3)]
                        assert sum(x*y for x,y in zip(hand_delta,foot_delta)) < 0,(body,state,travel,aim,side)
                        counter_checks += 1
    manifest=json.loads((baker.OUT / "manifest.json").read_text(encoding="utf-8"))
    old_manifest=json.loads((PRIOR / "manifest.json").read_text(encoding="utf-8"))
    for field in ("schema_version","cell","pivot","presentation_scale","directions","base_rows","locomotion"):
        assert manifest[field] == old_manifest[field], field
    pages={}
    for body in baker.BODIES:
        for bank in ("base","locomotion","sprint"):
            path=baker.OUT/f"{body}-{bank}.png"
            page=Image.open(path).convert("RGBA")
            assert sha(path) == manifest["sizes"][body][bank+"_sha256"]
            assert hashlib.sha256(page.tobytes()).hexdigest() == manifest["sizes"][body][bank+"_rgba_sha256"]
            assert list(page.size) == manifest["sizes"][body][bank+"_dimensions"]
            pages[(body,bank)]=page
        prior_page=Image.open(PRIOR/f"{body}-base.png").convert("RGBA")
        for aim in range(8):
            box=(aim*96,0,(aim+1)*96,96)
            before,after=prior_page.crop(box).getbbox(),pages[(body,"base")].crop(box).getbbox()
            assert before[1] == after[1] and before[3] == after[3] == 84,(body,aim,"crown/feet")
    # Exact 1-second loop at the existing 3/s walk and 5/s sprint caps. GIF's
    # 10ms clock is explicit; this is offline cadence evidence, not a live run.
    frames=[]
    cases=((2,2,"FORWARD E/E"),(0,2,"STRAFE S/E"),(6,2,"BACKPEDAL W/E"))
    for tick in range(100):
        board=Image.new("RGB",(440,632),"#201e1d")
        draw=ImageDraw.Draw(board)
        draw.text((8,8),"W2 NORMAL CAPS / WALK3 RUN5 CYCLES/SECOND",font=FONT,fill="#ead7aa")
        for row in range(6):
            travel,aim,label=cases[row//2]
            sprinting=row%2==1
            phase=(tick*(40 if sprinting else 24)//100)%8
            bank="sprint" if sprinting else "locomotion"
            draw.text((8,58+row*96),("RUN " if sprinting else "WALK ")+label,font=FONT,fill="#ead7aa")
            for col,body in enumerate(baker.BODIES):
                index=(travel*8+aim)*8+phase
                x,y=index%16*96,index//16*96
                cell=pages[(body,bank)].crop((x,y,x+96,y+96))
                board.paste(cell,(152+col*96,32+row*96),cell)
        frames.append(board)
    gif_path=HERE/"w2-normal-speed-native.gif"
    frames[0].save(gif_path,save_all=True,append_images=frames[1:],duration=10,loop=0,disposal=2)
    with Image.open(gif_path) as gif:
        duration=0
        for index in range(gif.n_frames):
            gif.seek(index)
            duration+=gif.info["duration"]
    assert duration == 1000
    evidence={"status":"offline_w2_passed_pending_runtime_checks","manifest_sha256":sha(baker.OUT/"manifest.json"),
              "rig_data_sha256":sha(HERE/"rig-data.json"),"exporter_sha256":sha(HERE/"export_rig.gd"),"rasterizer_sha256":sha(HERE/"build.py"),
              "all_3312_pose_keys_unchanged":True,"all_leg_head_neck_shoulder_landmarks_and_registration_unchanged":True,
              "exact_bone_lengths_unchanged":True,"all_24_grounded_crown_and_foot_rows_unchanged":True,
              "opposed_same_side_arm_foot_phase_checks":counter_checks,"display_heights":baker.DISPLAY_HEIGHTS,
              "normal_speed_preview":{"path":gif_path.name,"duration_ms":duration,"walk_cycles":3,"sprint_cycles":5,"source":"current final runtime PNGs; offline cap cadence, not captured gameplay"},
              "moving_cast_limit":"Movement frame has no casting-state input. Free-hand counter-swing is locomotion, not cast anticipation. Caller hook plus bounded upper-body pose support remains separate.",
              "prior_checkpoint":PRIOR.name}
    (HERE/"w2-verification.json").write_text(json.dumps(evidence,indent=2)+"\n",encoding="utf-8")
    print(f"PASS: unchanged 3312 pose keys and all leg/head/neck/shoulder anchors; {counter_checks} opposed arm checks; nine PNG/RGBA hashes; exact 1000ms 3:5-cadence GIF")


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--body",choices=baker.BODIES)
    parser.add_argument("--proof",action="store_true")
    args=parser.parse_args()
    data=json.loads((HERE/"rig-data.json").read_text(encoding="utf-8"))
    if args.body:
        preview(args.body,data)
    if args.proof:
        proof(data)
