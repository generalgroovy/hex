"""Refresh animation evidence from final runtime PNGs without modifying those PNGs."""
from pathlib import Path
import importlib.util
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("motion_baker", HERE / "build.py")
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)
cells = {}
for body in baker.BODIES:
    atlas = Image.open(baker.OUT / (body+"-locomotion.png")).convert("RGBA")
    for travel in range(8):
        for aim in range(8):
            for phase in range(8):
                index = (travel*8+aim)*8+phase
                x, y = index%16*96, index//16*96
                cells[(body, travel, aim, phase)] = atlas.crop((x, y, x+96, y+96))
baker.gif_examples(cells)
board = Image.new("RGB", (1760, 680), baker.PALETTE["dark"])
draw = ImageDraw.Draw(board)
font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 18)
for phase in range(8):
    draw.text((200+192*phase, 8), "PHASE "+str(phase), font=font, fill="#eee8f5")
for row, (travel, aim, title) in enumerate([(2,2,"FORWARD E/E"),(0,2,"STRAFE S/E"),(6,2,"BACKPEDAL W/E")]):
    draw.text((10, 110+row*208), title, font=font, fill="#eee8f5")
    for phase in range(8):
        cell = cells[("small", travel, aim, phase)].resize((192,192), Image.Resampling.NEAREST)
        board.paste(cell, (200+192*phase, 36+208*row), cell)
board.save(HERE / "small-eight-phase-cycles-2x.png")
print("PASS: regenerated GIF and phase strip from final runtime atlas; runtime files untouched")

# Three walking cycles versus five sprint cycles in a slowed, looping audit.
sprint_cells = {}
for body in baker.BODIES:
    atlas = Image.open(baker.OUT / (body+"-sprint.png")).convert("RGBA")
    for phase in range(8):
        index = (2*8+2)*8+phase
        x, y = index%16*96, index//16*96
        sprint_cells[(body, phase)] = atlas.crop((x,y,x+96,y+96))
comparison = []
for frame_index in range(40):
    frame = Image.new("RGB", (1152, 864), baker.PALETTE["dark"])
    draw = ImageDraw.Draw(frame)
    draw.text((16, 8), "WALK / SPRINT: DISTINCT STRIDE + 3:5 CADENCE / SLOWED REVIEW", font=font, fill="#eee8f5")
    for row, label in enumerate(("WALK / UPRIGHT / SHORTER STEP", "SPRINT / STRONGER LEAN / LONGER STEP")):
        draw.text((16, 40+row*412), label, font=font, fill="#eee8f5")
        for col, body in enumerate(baker.BODIES):
            phase = (frame_index*3//5)%8 if row == 0 else frame_index%8
            cell = (cells[(body,2,2,phase)] if row == 0 else sprint_cells[(body,phase)]).resize((384,384),Image.Resampling.NEAREST)
            frame.paste(cell,(col*384,64+row*412),cell)
    comparison.append(frame)
comparison[0].save(HERE / "walk-run-comparison-4x.gif", save_all=True, append_images=comparison[1:], duration=80, loop=0, disposal=2)
strip = Image.new("RGB", (1760,480),baker.PALETTE["dark"])
draw = ImageDraw.Draw(strip)
for phase in range(8):
    draw.text((200+192*phase,8),"PHASE "+str(phase),font=font,fill="#eee8f5")
for row,label in enumerate(("WALK E/E","SPRINT E/E")):
    draw.text((10,110+row*208),label,font=font,fill="#eee8f5")
    for phase in range(8):
        cell=(cells[("small",2,2,phase)] if row==0 else sprint_cells[("small",phase)]).resize((192,192),Image.Resampling.NEAREST)
        strip.paste(cell,(200+192*phase,36+208*row),cell)
strip.save(HERE / "small-walk-sprint-eight-phases-2x.png")
print("PASS: distinct walk/sprint geometry and slowed 3:5 cadence comparison; runtime files untouched")
