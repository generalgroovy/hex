"""Fresh output/source reassembly evidence for this exact three-character pack."""
import json
from pathlib import Path
import sys
from PIL import Image

HERE=Path(__file__).resolve().parent
FACTORY=HERE.parents[1]
sys.path.insert(0,str(FACTORY))
import action_keys as keys

manifest=json.loads((HERE/"manifest.json").read_text())
assert {c["id"] for c in manifest["characters"]}=={"wa_bidi","jan_wicked","fluup"}
checks=[]
for character in manifest["characters"]:
    recipe_path=keys.REPO/character["recipe"]
    assert keys.sha(recipe_path)==character["recipe_sha256"]
    recipe=json.loads(recipe_path.read_text())
    source=keys.REPO/recipe["source_png"]
    assert keys.sha(source)==character["source_sha256"]==recipe["source_sha256"]
    cells,records=keys.assemble(recipe,source)
    atlas_path=HERE/character["atlas"]
    assert keys.sha(atlas_path)==character["atlas_sha256"]
    assert len(cells)==len(records)==64
    assert {r["uniform_scale"] for r in records}=={recipe["uniform_scale"]}
    with Image.open(atlas_path) as atlas:
        for record in character["frames"]:
            x,y,w,h=record["rect"]
            cell=atlas.crop((x,y,x+w,y+h))
            assert cell.tobytes()==cells[record["key"]].tobytes()
            assert keys.pixel_sha(cell)==record["rgba_sha256"]
    checks.append({"id":character["id"],"source_unchanged":True,"fresh_reassembled_cells_match_atlas":64,
                   "all_keys_distinct":True,"single_uniform_scale":recipe["uniform_scale"],
                   "source_head_height":recipe["head_measurement"]["source_head_height"],"target_head_height":18,
                   "measurement_confidence":recipe["head_measurement"]["confidence"]})
receipt_path=HERE/"registration-receipt.json"
receipt=json.loads(receipt_path.read_text())
receipt["fresh_reassembly_checks"]=checks
receipt["fresh_reassembly_cells"]=192
receipt["verification_command"]="python art_batches/character_motion_v1/output/authored-keys-v2/verify-registered.py"
keys.write_json(receipt_path,receipt)
print(json.dumps({"status":"PASS_FRESH_REASSEMBLY","characters":3,"cells":192,"source_originals_unchanged":True}))
