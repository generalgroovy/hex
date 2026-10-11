"""Review-only assembly of unchanged source-detail frames; no new painted pixels."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/sprites/fullbody_cast_v1"
OUT = ROOT / "docs/art/character-motion-20260927/detail-motion-evidence"

def main():
    entries = json.loads((PACK / "manifest.json").read_text())["characters"]
    OUT.mkdir(parents=True, exist_ok=True)
    front = Image.new("RGB", (1536, 1400), "#263b35")
    ink = ImageDraw.Draw(front)
    for start in range(0, len(entries), 6):
        board = Image.new("RGB", (2048, 1680), "#263b35")
        draw = ImageDraw.Draw(board)
        for row, entry in enumerate(entries[start:start+6]):
            atlas = Image.open(PACK / entry["detail"]["atlas"]).convert("RGBA")
            board.paste(atlas, (0, row*280), atlas)
            draw.text((12, row*280+255), entry["id"]+" / "+entry["body"]+" / S SE E NE N NW W SW", fill="#ead9b6")
            tile = atlas.crop((0, 0, 256, 256))
            index = start+row
            x, y = index%6*256, index//6*280
            front.paste(tile, (x,y), tile)
            ink.text((x+12,y+255), entry["id"]+" / "+entry["body"], fill="#ead9b6")
        board.save(OUT / f"directions-{start//6+1}.png")
    front.save(OUT / "roster-detail.png")
    print("PASS:30 identities /240 source-detail directional views assembled without resizing")

if __name__ == "__main__":
    main()
