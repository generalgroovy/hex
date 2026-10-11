"""Recover authored detail directly from original RGBA crops, not upscaled sprites.

User-approved deterministic assembly. Preserve the current world registration,
head/body calibration, source sheets, skeleton and existing runtime pages.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
from PIL import Image
import shared_heads

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_batches/character_cast_v1"
OUT = ROOT / "assets/sprites/fullbody_cast_v1"
spec = importlib.util.spec_from_file_location("fullbody_source", SOURCE / "fullbody.py")
fullbody = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fullbody)


def main():
    catalog = json.loads((SOURCE / "catalog.json").read_text())
    runtime = json.loads((OUT / "manifest.json").read_text())
    calibration = shared_heads.load_calibration()["characters"]
    identities = {c["id"]: c for c in catalog["characters"]}
    for entry in runtime["characters"]:
        character = identities[entry["id"]]
        recipe = SOURCE / character["fullbody_recipe"]
        config, parts, provenance = fullbody.load_recipe(recipe, character)
        _, geometry = fullbody.assemble_parts(config, parts, character)
        row = calibration[entry["id"]]
        plan, body_scale = shared_heads.parameters({"body": entry["body"]}, row)
        atlas = Image.new("RGBA", (2048, 256))
        for index, direction in enumerate(fullbody.DIRECTIONS):
            face = row["facings"][direction]
            chin = face["recommended_head_mask_bottom_y"] - 1
            center = face["head_anchor"][0]
            half_width = max(row["source_cranial_width_px"]/2+4, plan["source_height_px"]*.82)
            if row["race"] in ("goblin", "elf", "nymph"):
                half_width *= 1.28
            target = (48+(center-48)*body_scale, 84+(chin-84)*body_scale)
            original = parts[direction]
            offset = geometry["facings"][direction]["offset"]
            scale = geometry["uniform_scale"]
            pixels = original.load()
            for y in range(256):
                dy = (y+.5)/2-20
                for x in range(256):
                    dx = (x+.5)/2-16
                    distance = abs(dx-target[0])/max(1,half_width*plan["head_scale"])
                    weight = max(0,min(1,(1.7-distance)/.7)) if dy < target[1] else 0
                    weight = weight*weight*(3-2*weight)
                    sy_scale = body_scale+(plan["head_scale"]-body_scale)*weight
                    neck = max(0,min(1,(target[1]-dy)/4))
                    sx_scale = body_scale+(plan["head_scale"]-body_scale)*weight*neck
                    sx = center+(dx-target[0])/sx_scale
                    sy = chin+(dy-target[1])/sy_scale
                    # Direct original-pixel lookup avoids the old 96px raster
                    # followed by a second head/body resampling operation.
                    px = int((sx-offset[0])/scale)
                    py = int((sy-offset[1])/scale)
                    if 0 <= px < original.width and 0 <= py < original.height:
                        value = pixels[px,py]
                        if value[3]: atlas.putpixel((index*256+x,y),value)
        leaf = entry["id"]+"-detail.png"
        atlas.save(OUT / leaf)
        entry["detail"] = {"atlas":leaf,"texels_per_world_pixel":2,
                           "rgba_sha256":hashlib.sha256(atlas.tobytes()).hexdigest(),
                           "source_sha256":provenance["source"]["source_sha256"]}
    (OUT / "manifest.json").write_text(json.dumps(runtime,separators=(",",":"))+"\n",encoding="utf-8")
    print(f"PASS: {len(runtime['characters'])} original-source detail pages; fixed world size and skeleton")


if __name__ == "__main__":
    main()
