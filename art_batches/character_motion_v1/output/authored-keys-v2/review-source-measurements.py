"""Review original first-front craniums; copies only, never source mutation."""
from pathlib import Path
from PIL import Image, ImageDraw

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parents[1]/"reference"
board=Image.new("RGB",(1530,510),"#d3c8b1")
draw=ImageDraw.Draw(board)
for col,name in enumerate(("wa_bidi","jan_wicked","fluup")):
    with Image.open(SOURCE/(name+"-shared-head-actions-v1.png")) as source:
        crop=source.crop((0,40,160,190)).convert("RGBA")
    tile=Image.new("RGBA",crop.size,"#34353e")
    tile.alpha_composite(crop)
    board.paste(tile.resize((480,450),Image.Resampling.NEAREST),(col*510+30,40))
    draw.text((col*510+35,12),name+" / original-source y coordinates",fill="#201c22")
    for y in range(40,191,10):
        dy=40+(y-40)*3
        draw.text((col*510+1,dy-4),str(y),fill="#201c22")
        draw.line((col*510+28,dy,col*510+45,dy),fill="#dd9977")
board.save(HERE/"source-first-front-measurement-review.png")
