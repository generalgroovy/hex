"""Reproducible three-source registration; originals and old recipes untouched."""
import argparse
import json
from pathlib import Path
import sys
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
FACTORY=HERE.parents[1]
sys.path.insert(0,str(FACTORY))
import action_keys as keys

MEASUREMENTS={
    "wa_bidi":{"source_head_height":39,"frame":"slide_entry/S","confidence":"low; skull crown obscured by hair, manual visual estimate",
               "notes":"Original first-front source: estimated cranial crown y98 to chin y137 (39px). Excludes hair tips and long ears. Review image source-first-front-measurement-review.png; body-pose bounds not used for scale."},
    "jan_wicked":{"source_head_height":35,"frame":"slide_entry/S","confidence":"low; skull crown obscured by hair, manual visual estimate",
                  "notes":"Original first-front source: estimated cranial crown y76 to chin y111 (35px). Excludes hair silhouette and collar. Review image source-first-front-measurement-review.png; body-pose bounds not used for scale."},
    "fluup":{"source_head_height":38,"frame":"slide_entry/S","confidence":"low; upper skull under cropped hair, manual visual estimate",
             "notes":"Original first-front source: estimated cranial crown y86 to chin y124 (38px). Excludes top hair, ears and shoulder armour. Review image source-first-front-measurement-review.png; body-pose bounds not used for scale."},
}

def main(review_only=False):
    if not review_only:
        for identity,measurement in MEASUREMENTS.items():
            source=FACTORY/"reference"/(identity+"-shared-head-actions-v1.png")
            result=keys.build_key_atlas(identity,source,HERE,measurement)
            print(json.dumps({k:result[k] for k in ("id","keyposes","uniform_scale","complete_cycles")}),flush=True)
    manifest=json.loads((HERE/"manifest.json").read_text())
    assert [c["id"] for c in manifest["characters"]]==list(MEASUREMENTS)
    board=Image.new("RGB",(3072,1136),"#d9cbb0")
    draw=ImageDraw.Draw(board)
    holds=["Authored8 action keys per8 views, not continuous animations.",
           "Cranial heights estimated through obscuring hair; human measurement approval pending.",
           "Front/diagonal source facing remains ambiguous in some poses; exact45degree yaw not certified.",
           "Airborne support translation is provisional; runtime physical jump height remains separate.",
           "No production or gameplay integration in this registration."]
    for col,char in enumerate(manifest["characters"]):
        with Image.open(HERE/char["atlas"]) as atlas: board.paste(atlas,(col*1024,100),atlas)
        draw.text((col*1024+8,10),char["id"]+" / 64 AUTHORED KEY POSES / NOT COMPLETE CYCLES",fill="#2a2330")
        draw.text((col*1024+8,30),"Shared18px cranial target; source estimate "+str(MEASUREMENTS[char["id"]]["source_head_height"])+"px; uniform scale "+str(round(char["uniform_scale"],6)),fill="#2a2330")
        draw.text((col*1024+8,48),"LOW CONFIDENCE CROWN ESTIMATE / FACING REVIEW PENDING",fill="#7b3830")
        for index,direction in enumerate(keys.DIRECTIONS): draw.text((col*1024+index*128+58,77),direction,fill="#2a2330")
        for index,row in enumerate(keys.ROWS): draw.text((col*1024+2,102+index*128),row,fill="#2a2330")
    board.save(HERE/"three-new-characters-action-keys.png")
    # Compact comparison retains full128px cells and native pixel sizes, with
    # front actions only. All eight facings remain in the full review above.
    compact=Image.new("RGB",(1136,520),"#d9cbb0")
    cd=ImageDraw.Draw(compact)
    cd.text((8,8),"THREE NEW CHARACTERS / FRONT ACTION KEYS / NATIVE PIXELS / NOT COMPLETE CYCLES",fill="#2a2330")
    for index,row in enumerate(keys.ROWS): cd.text((112+index*128+3,35),row,fill="#2a2330")
    for row,char in enumerate(manifest["characters"]):
        cd.text((8,110+row*148),char["id"],fill="#2a2330")
        with Image.open(HERE/char["atlas"]) as atlas:
            for action in range(8):
                cell=atlas.crop((0,action*128,128,(action+1)*128))
                compact.paste(cell,(112+action*128,55+row*148),cell)
    compact.save(HERE/"three-new-characters-front-actions-native.png")
    keys.write_json(HERE/"registration-receipt.json",{"status":"PASS_OFFLINE_REGISTRATION", "characters":3,"authored_keyposes":192,
        "source_measurements":MEASUREMENTS,"source_pixel_ownership":"Exact thresholded-alpha conservation and unique64keys per character checked by assemble",
        "complete_cycles":False,"production_ready":False,"human_approved":False,"native_validation":"NOT_RUN_BY_WORKER","holds":holds,
        "manifest_sha256":keys.sha(HERE/"manifest.json")})

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--review-only",action="store_true")
    main(parser.parse_args().review_only)
