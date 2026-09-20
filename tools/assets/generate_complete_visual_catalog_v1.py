#!/usr/bin/env python3
"""Generate the complete currently specified FLUX 2 visual catalog.

The output is project-original deterministic pixel construction. It extends the
canonical skeleton contract without granting rendered pixels simulation authority.
"""
from __future__ import annotations

import hashlib
import json
import math
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

import generate_visual_assets_v1 as base

ROOT = Path(__file__).resolve().parents[2]
CELL = 32
ATLAS_SIZE = (960, 1280)

ANCESTRIES = [
    "human", "dwarf", "gnome", "hobbit", "elf", "orc", "troll", "minotaur",
    "seakin", "wyrmborn", "stoneborn", "treefolk", "sylph", "undead", "goblin",
    "nymph", "vampire", "werewolf", "angel", "demon", "weaverkin",
    "scorpionkin", "harvestkin",
]

ANCESTRY_DEFAULTS: dict[str, dict[str, Any]] = {
    "human": {"size": "size_3_medium", "feature": "none"},
    "dwarf": {"size": "size_3_medium", "feature": "beard"},
    "gnome": {"size": "size_1_tiny", "feature": "device"},
    "hobbit": {"size": "size_2_small", "feature": "cloak"},
    "elf": {"size": "size_3_medium", "feature": "long_ears"},
    "orc": {"size": "size_4_large", "feature": "tusks"},
    "troll": {"size": "size_5_huge", "feature": "brow"},
    "minotaur": {"size": "size_5_huge", "feature": "horns"},
    "seakin": {"size": "size_3_medium", "feature": "fins"},
    "wyrmborn": {"size": "size_4_large", "feature": "dragon_wings"},
    "stoneborn": {"size": "size_4_large", "feature": "stone"},
    "treefolk": {"size": "size_4_large", "feature": "roots"},
    "sylph": {"size": "size_2_small", "feature": "streamer_wings"},
    "undead": {"size": "size_3_medium", "feature": "runes"},
    "goblin": {"size": "size_2_small", "feature": "long_ears"},
    "nymph": {"size": "size_2_small", "feature": "bloom"},
    "vampire": {"size": "size_3_medium", "feature": "cloak"},
    "werewolf": {"size": "size_4_large", "feature": "wolf"},
    "angel": {"size": "size_3_medium", "feature": "feather_wings"},
    "demon": {"size": "size_3_medium", "feature": "demon"},
    "weaverkin": {"size": "size_3_medium", "feature": "spider"},
    "scorpionkin": {"size": "size_4_large", "feature": "scorpion"},
    "harvestkin": {"size": "size_4_large", "feature": "harvest"},
}

CHAMPIONS: list[dict[str, Any]] = [
    {"id":"oh_tipi","name":"Oh Tipi","ancestry":"seakin","size":"size_3_medium","skin":"#63aeb4","primary":"#24566b","secondary":"#d7f2e9","accent":"#55dbe0","hair":"none","feature":"large_fins","weapon":"conduit","elements":["water","ice","charge"]},
    {"id":"s_wayne","name":"S. Wayne","ancestry":"hobbit","size":"size_2_small","skin":"#714a39","primary":"#24202f","secondary":"#d0c5a8","accent":"#9b65d9","hair":"hood","feature":"eclipse_cloak","weapon":"disc","elements":["dark","light"]},
    {"id":"red_baron","name":"The Red Baron","ancestry":"undead","size":"size_3_medium","skin":"#b7b1a2","primary":"#7d2730","secondary":"#252832","accent":"#e58a38","hair":"helm","feature":"rune_wings","weapon":"sabre","elements":["dark","fire","ice"]},
    {"id":"steezo","name":"Steezo","ancestry":"goblin","size":"size_2_small","skin":"#a94137","primary":"#55202c","secondary":"#b88438","accent":"#55dbe0","hair":"crest","feature":"device","weapon":"detonator","elements":["fire","charge","light"]},
    {"id":"treevor_mason","name":"Treevor the Mason","ancestry":"treefolk","size":"size_4_large","skin":"#6f5938","primary":"#304b27","secondary":"#8b7045","accent":"#e58a38","hair":"canopy","feature":"roots","weapon":"mason_hammer","elements":["earth","wind","fire"]},
    {"id":"oll_i","name":"Oll' I","ancestry":"werewolf","size":"size_4_large","skin":"#8a7362","primary":"#40352f","secondary":"#b6a477","accent":"#f0d879","hair":"mane","feature":"wolf","weapon":"gauntlets","elements":["earth","fire","light"]},
    {"id":"fluup","name":"Fluup","ancestry":"orc","size":"size_4_large","skin":"#66805b","primary":"#39506b","secondary":"#d6e5de","accent":"#55dbe0","hair":"topknot","feature":"tusks","weapon":"storm_maul","elements":["charge","wind","ice"]},
    {"id":"wa_bidi","name":"Wa Bidi","ancestry":"goblin","size":"size_2_small","skin":"#7e8d57","primary":"#c35f32","secondary":"#413149","accent":"#55dbe0","hair":"braid","feature":"banner","weapon":"horn","elements":["charge","wind","fire"]},
    {"id":"grace_reava","name":"Grace Reava","ancestry":"sylph","size":"size_2_small","skin":"#c68f72","primary":"#e8e0c4","secondary":"#4b8191","accent":"#f3e7a0","hair":"long","feature":"streamer_wings","weapon":"rapier","elements":["wind","water","light"]},
    {"id":"nico_lai","name":"Nico Lai","ancestry":"gnome","size":"size_1_tiny","skin":"#b98968","primary":"#38707a","secondary":"#24434a","accent":"#b88438","hair":"bald_sides","feature":"device","weapon":"charge_gauntlet","elements":["charge","light"]},
    {"id":"spai_si","name":"Spai Si","ancestry":"demon","size":"size_3_medium","skin":"#85515b","primary":"#27303b","secondary":"#856b45","accent":"#d8d4bd","hair":"short_dark","feature":"demon","weapon":"redirect_blade","elements":["wind","light","earth"]},
    {"id":"leaf_hidden","name":"Leaf the Hidden","ancestry":"treefolk","size":"size_3_medium","skin":"#755f3f","primary":"#304b27","secondary":"#66834a","accent":"#d8e8b3","hair":"leaf_hood","feature":"roots","weapon":"rootweaving_hands","elements":["water","earth","light"]},
    {"id":"ha_rekt","name":"Ha Rekt","ancestry":"wyrmborn","size":"size_4_large","skin":"#6a8892","primary":"#38475f","secondary":"#b4dce2","accent":"#e58a38","hair":"spines","feature":"dragon_wings","weapon":"cold_lance","elements":["ice","wind","fire"]},
    {"id":"dr_apex","name":"Dr. Apex","ancestry":"stoneborn","size":"size_4_large","skin":"#7f837d","primary":"#4d5554","secondary":"#e2d8b2","accent":"#55dbe0","hair":"none","feature":"stone","weapon":"medic_prism","elements":["earth","light","water"]},
    {"id":"haara","name":"Haara","ancestry":"nymph","size":"size_2_small","skin":"#a66f58","primary":"#6a3154","secondary":"#66834a","accent":"#f3e7a0","hair":"short_dark","feature":"bloom","weapon":"bloom_orb","elements":["light","wind","spirit"]},
    {"id":"hesus_christo","name":"Hesus Christo","ancestry":"elf","size":"size_3_medium","skin":"#c18d68","primary":"#ddd2b6","secondary":"#426b61","accent":"#8bc6cf","hair":"long_dark","feature":"long_ears","weapon":"renewal_hands","elements":["earth","water"]},
    {"id":"grimm_bow","name":"Grimm Bow","ancestry":"troll","size":"size_5_huge","skin":"#657060","primary":"#3c3836","secondary":"#8b7045","accent":"#4c9eb2","hair":"brow","feature":"brow","weapon":"greatbow","elements":["dark","earth","water"]},
    {"id":"biggy_bob","name":"Biggy Bob","ancestry":"dwarf","size":"size_3_medium","skin":"#a66f50","primary":"#6f3428","secondary":"#b88438","accent":"#e58a38","hair":"beard","feature":"forge_pack","weapon":"breach_hammer","elements":["earth","fire","light"]},
    {"id":"jan_wicked","name":"Jan Wicked","ancestry":"human","size":"size_3_medium","skin":"#b77d61","primary":"#242a35","secondary":"#6d8fa1","accent":"#55dbe0","hair":"swept","feature":"circuit_coat","weapon":"ice_blade","elements":["ice","dark","charge"]},
    {"id":"ba_djoh","name":"Ba Djoh","ancestry":"minotaur","size":"size_5_huge","skin":"#89644b","primary":"#5b3127","secondary":"#8b7045","accent":"#4a9db1","hair":"mane","feature":"horns","weapon":"breaker","elements":["earth","fire","water"]},
    {"id":"urzh","name":"Urzh","ancestry":"stoneborn","size":"size_4_large","skin":"#69675e","primary":"#4a4139","secondary":"#b88438","accent":"#55dbe0","hair":"crystal","feature":"stone","weapon":"kiln_shield","elements":["earth","fire","charge"]},
    {"id":"donnok","name":"Donnok","ancestry":"dwarf","size":"size_3_medium","skin":"#9b694d","primary":"#4b3226","secondary":"#8e744b","accent":"#4a9db1","hair":"braided_beard","feature":"forge_pack","weapon":"terrain_hammer","elements":["earth","fire","water"]},
    {"id":"djonah_thaan","name":"Djonah Thaan","ancestry":"vampire","size":"size_3_medium","skin":"#a17873","primary":"#391f33","secondary":"#242832","accent":"#e58a38","hair":"slick_dark","feature":"cloak","weapon":"grave_coil","elements":["dark","charge","fire"]},
    {"id":"unnamed_angel","name":"Unnamed Angel","ancestry":"angel","size":"size_3_medium","skin":"#c99a78","primary":"#e7dfc9","secondary":"#a9bdc5","accent":"#f3e7a0","hair":"short_light","feature":"feather_wings","weapon":"placeholder_orb","elements":["wind","light","spirit"],"status":"placeholder_unapproved"},
]

DISTRICTS = [
    ("nexus_court", "Nexus Court", "fountain"),
    ("wayfarer_concourse", "Wayfarer Concourse", "gates"),
    ("movement_conservatory", "Movement Conservatory", "movement"),
    ("alchemical_proving_grounds", "Alchemical Proving Grounds", "basins"),
    ("living_archive", "Living Archive", "archive"),
    ("verdant_recovery", "Verdant Recovery", "garden"),
    ("foundry_deep", "Foundry Deep", "foundry"),
    ("crown_observatory", "Crown Observatory", "observatory"),
    ("seasonal_expanse", "Seasonal Expanse", "seasons"),
]


def rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    return base.col(value, alpha)


def draw_feature(draw: ImageDraw.ImageDraw, profile: dict[str, Any], z: dict[str, tuple[int, int]], direction: int, behind: bool) -> None:
    feature = profile.get("feature", "none")
    accent = rgba(profile["accent"])
    secondary = rgba(profile["secondary"])
    ink = rgba(base.PAL["ink"])
    dx, dy = base.vec(direction)
    sh = z["sh"]
    hip = z["hip"]
    head = z["head"]
    if behind:
        if feature in ("dragon_wings", "rune_wings", "feather_wings", "streamer_wings"):
            span = 8 if feature != "streamer_wings" else 6
            draw.polygon([(sh[0]-2,sh[1]+1),(sh[0]-span,sh[1]-5),(hip[0]-4,hip[1]+4)], fill=ink)
            draw.polygon([(sh[0]+2,sh[1]+1),(sh[0]+span,sh[1]-5),(hip[0]+4,hip[1]+4)], fill=ink)
            fill = secondary if feature != "rune_wings" else accent
            draw.line((sh[0]-2,sh[1]+1,sh[0]-span,sh[1]-4,hip[0]-4,hip[1]+3), fill=fill, width=2)
            draw.line((sh[0]+2,sh[1]+1,sh[0]+span,sh[1]-4,hip[0]+4,hip[1]+3), fill=fill, width=2)
        if feature in ("cloak", "eclipse_cloak", "circuit_coat"):
            draw.polygon([(sh[0]-4,sh[1]),(sh[0]+4,sh[1]),(hip[0]+5,hip[1]+5),(hip[0]-5,hip[1]+5)], fill=ink)
            draw.polygon([(sh[0]-3,sh[1]+1),(sh[0]+3,sh[1]+1),(hip[0]+4,hip[1]+4),(hip[0]-4,hip[1]+4)], fill=secondary)
        if feature in ("spider", "scorpion", "harvest"):
            for side in (-1, 1):
                for offset in (-4, -1, 2, 5):
                    y = hip[1] + offset // 2
                    draw.line((hip[0],y,hip[0]+side*(7+abs(offset)//2),y+offset), fill=ink, width=2)
                    draw.line((hip[0]+side*2,y,hip[0]+side*(7+abs(offset)//2),y+offset), fill=secondary)
            if feature == "scorpion":
                draw.line((hip[0],hip[1],hip[0]-dx*4,hip[1]+4,hip[0]-dx*6,hip[1]-4,hip[0]-dx*2,hip[1]-8), fill=accent, width=2)
        if feature in ("roots", "bloom"):
            for side in (-1,1):
                draw.line((hip[0],hip[1],hip[0]+side*5,base.P[1]), fill=secondary, width=2)
        if feature in ("device", "forge_pack"):
            bx = sh[0]-dx*3
            by = sh[1]+2
            draw.rectangle((bx-3,by-3,bx+3,by+3), fill=ink)
            draw.rectangle((bx-2,by-2,bx+2,by+2), fill=secondary)
            draw.point((bx,by), fill=accent)
        if feature == "banner":
            draw.line((sh[0]-dx*2,sh[1],hip[0]-dx*3,hip[1]+8), fill=ink, width=2)
            draw.rectangle((hip[0]-dx*6-2,hip[1]+2,hip[0]-dx*2+2,hip[1]+7), fill=secondary)
    else:
        x, y = head
        if feature in ("horns", "demon"):
            draw.polygon([(x-3,y-2),(x-7,y-7),(x-2,y-5)], fill=accent)
            draw.polygon([(x+3,y-2),(x+7,y-7),(x+2,y-5)], fill=accent)
        if feature in ("fins", "large_fins"):
            span = 7 if feature == "large_fins" else 5
            draw.polygon([(x-2,y),(x-span,y-5),(x-span+1,y+4)], fill=accent)
            draw.polygon([(x+2,y),(x+span,y-5),(x+span-1,y+4)], fill=accent)
        if feature in ("long_ears", "tusks"):
            draw.line((x-3,y,x-7,y+dy), fill=accent, width=2)
            draw.line((x+3,y,x+7,y+dy), fill=accent, width=2)
        if feature == "wolf":
            draw.polygon([(x-3,y-2),(x-5,y-8),(x,y-5)], fill=secondary)
            draw.polygon([(x+3,y-2),(x+5,y-8),(x,y-5)], fill=secondary)
        if feature in ("stone", "crystal"):
            draw.polygon([(x-4,y),(x-2,y-6),(x+1,y-4),(x+4,y-7),(x+4,y+3),(x-4,y+3)], outline=accent)
        if feature in ("bloom", "canopy"):
            for ox, oy in ((-4,-3),(0,-6),(4,-3)):
                draw.ellipse((x+ox-2,y+oy-2,x+ox+2,y+oy+2), fill=accent)
        if feature == "brow":
            draw.line((x-4,y-2,x+4,y-2), fill=accent, width=2)
        if feature == "runes":
            draw.point((x-dx*2,y-dy*2), fill=accent)


def draw_hair(draw: ImageDraw.ImageDraw, profile: dict[str, Any], head: tuple[int, int]) -> None:
    hair = profile.get("hair", "none")
    if hair == "none":
        return
    x, y = head
    color = rgba("#252523" if "dark" in hair or hair in ("hood","slick_dark") else "#d4d0b6")
    if hair == "bald_sides":
        draw.rectangle((x-5,y-1,x-4,y+4), fill=color)
        draw.rectangle((x+4,y-1,x+5,y+4), fill=color)
    elif hair in ("short_dark","short_light","short"):
        draw.arc((x-4,y-5,x+4,y+3), 180, 350, fill=color, width=2)
    elif hair in ("long","long_dark","slick_dark"):
        draw.arc((x-5,y-6,x+5,y+5), 160, 380, fill=color, width=2)
        draw.line((x-4,y,x-4,y+7), fill=color, width=2)
    elif hair in ("mane","canopy","crest","spines","crystal"):
        for ox in (-4,0,4):
            draw.polygon([(x+ox-2,y-1),(x+ox,y-8),(x+ox+2,y-1)], fill=color)
    elif hair in ("beard","braided_beard"):
        draw.arc((x-4,y-5,x+4,y+5), 180, 360, fill=color, width=2)
        draw.polygon([(x-3,y+2),(x+3,y+2),(x,y+8)], fill=color)
    elif hair in ("hood","leaf_hood","helm"):
        draw.arc((x-5,y-6,x+5,y+5), 150, 390, fill=color, width=3)
    else:
        draw.line((x-4,y-3,x+4,y-4), fill=color, width=2)


def actor_frame(profile: dict[str, Any], animation: str, direction: int, frame_index: int, debug: bool = False) -> Image.Image:
    size = profile["size"]
    height, width = base.S[size]
    count = base.A[animation][2]
    pose = base.pose(animation, frame_index, count)
    z = base.pts(height, width, pose, direction)
    image = Image.new("RGBA", (CELL, CELL))
    draw = ImageDraw.Draw(image)
    shadow_radius = max(2, width // 2 + 2 - pose["lift"] // 3)
    draw.ellipse((16-shadow_radius,27,16+shadow_radius,29), fill=(3,7,8,72))
    draw_feature(draw, profile, z, direction, True)
    ink = rgba(base.PAL["ink"])
    skin = rgba(profile["skin"])
    primary = rgba(profile["primary"])
    secondary = rgba(profile["secondary"])
    accent = rgba(profile["accent"])
    for knee, foot in (("lk","lf"),("rk","rf")):
        draw.line((z["hip"],z[knee],z[foot]), fill=ink, width=3)
        draw.line((z["hip"],z[knee],z[foot]), fill=secondary, width=1)
    sh, hip = z["sh"], z["hip"]
    draw.polygon([(sh[0]-4,sh[1]-1),(sh[0]+4,sh[1]-1),(hip[0]+3,hip[1]+2),(hip[0]-3,hip[1]+2)], fill=ink)
    draw.polygon([(sh[0]-3,sh[1]),(sh[0]+3,sh[1]),(hip[0]+2,hip[1]+1),(hip[0]-2,hip[1]+1)], fill=primary)
    draw.line((sh[0],sh[1],hip[0],hip[1]+1), fill=accent)
    for elbow, hand, color in (("le","lh",secondary),("re","rh",accent)):
        draw.line((sh,z[elbow],z[hand]), fill=ink, width=3)
        draw.line((sh,z[elbow],z[hand]), fill=color, width=1)
    x, y = z["head"]
    draw.ellipse((x-4,y-4,x+4,y+4), fill=ink)
    draw.ellipse((x-3,y-3,x+3,y+3), fill=skin)
    draw_hair(draw, profile, z["head"])
    dx, dy = base.vec(direction)
    draw.point((x+dx,y+max(-1,min(1,dy))), fill=accent)
    draw_feature(draw, profile, z, direction, False)
    if animation in ("cast","attack_primary","taunt") and frame_index >= count // 2:
        cx, cy = z["rh"]
        for ox, oy in ((-3,0),(3,0),(0,-3),(0,3)):
            px, py = max(0,min(31,cx+ox)), max(0,min(31,cy+oy))
            draw.point((px,py), fill=accent)
    if debug:
        top = max(0, 28-height-pose["lift"]-2)
        half = max(4, width//2+3)
        draw.rectangle((16-half,top,16+half,28), outline=(60,225,235,180))
        draw.line((16,0,16,31), fill=(60,225,235,110))
        draw.line((0,28,31,28), fill=(255,70,65,190))
        draw.rectangle((15,27,17,29), fill=(255,40,40,255))
    return image


def actor_atlas(profile: dict[str, Any], debug: bool = False) -> Image.Image:
    image = Image.new("RGBA", ATLAS_SIZE)
    for animation, (block_x, block_y, frame_count, _fps) in base.A.items():
        for direction in range(8):
            for frame_index in range(frame_count):
                frame = actor_frame(profile, animation, direction, frame_index, debug)
                image.alpha_composite(frame, (block_x*192+frame_index*CELL, block_y*256+direction*CELL))
    return image


def preview_strip(atlas: Image.Image) -> Image.Image:
    preview = Image.new("RGBA", (1024, 128), rgba("#141817"))
    for direction in range(8):
        frame = atlas.crop((0,direction*32,32,direction*32+32)).resize((128,128), Image.Resampling.NEAREST)
        preview.alpha_composite(frame, (direction*128,0))
    return preview


def portrait(profile: dict[str, Any], atlas: Image.Image, size: int) -> Image.Image:
    image = Image.new("RGBA", (size,size), rgba(profile["primary"]))
    draw = ImageDraw.Draw(image)
    draw.rectangle((1,1,size-2,size-2), outline=rgba(profile["accent"]), width=max(1,size//32))
    frame = atlas.crop((0,0,32,32)).resize((size,size), Image.Resampling.NEAREST)
    image.alpha_composite(frame)
    return image


def neutral_profile(ancestry: str) -> dict[str, Any]:
    default = ANCESTRY_DEFAULTS[ancestry]
    return {
        "id": ancestry,
        "name": ancestry.replace("_", " ").title(),
        "ancestry": ancestry,
        "size": default["size"],
        "skin": "#b0a78d",
        "primary": "#5a5f5a",
        "secondary": "#8b7045",
        "accent": "#55dbe0",
        "hair": "none",
        "feature": default["feature"],
        "weapon": "none",
        "elements": [],
    }


def fill_ellipse(grid: list[list[str]], cx: int, cy: int, rx: int, ry: int, tile: str) -> None:
    for y in range(max(0,cy-ry),min(len(grid),cy+ry+1)):
        for x in range(max(0,cx-rx),min(len(grid[0]),cx+rx+1)):
            if ((x-cx)/max(1,rx))**2 + ((y-cy)/max(1,ry))**2 <= 1:
                grid[y][x] = tile


def fill_rect(grid: list[list[str]], x0: int, y0: int, x1: int, y1: int, tile: str) -> None:
    for y in range(max(0,y0),min(len(grid),y1+1)):
        for x in range(max(0,x0),min(len(grid[0]),x1+1)):
            grid[y][x] = tile


def path_line(grid: list[list[str]], a: tuple[int,int], b: tuple[int,int], width: int, tile: str) -> None:
    x0,y0=a; x1,y1=b
    steps=max(abs(x1-x0),abs(y1-y0),1)
    for step in range(steps+1):
        x=round(x0+(x1-x0)*step/steps); y=round(y0+(y1-y0)*step/steps)
        fill_rect(grid,x-width,y-width,x+width,y+width,tile)


def apply_shore(grid: list[list[str]]) -> list[list[int]]:
    h=len(grid);w=len(grid[0]); mask=[[0]*w for _ in range(h)]
    source=[row[:] for row in grid]
    for y in range(1,h-1):
        for x in range(1,w-1):
            if source[y][x].startswith("water"):
                continue
            if any(source[y+dy][x+dx].startswith("water") for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))):
                grid[y][x]="shore_0";mask[y][x]=1
    return mask


def district_grid(kind: str) -> tuple[list[list[str]], list[list[int]], list[dict[str,Any]], list[dict[str,Any]]]:
    grid=[["water_0"]*80 for _ in range(45)]
    landmarks: list[dict[str,Any]]=[]; routes: list[dict[str,Any]]=[]
    if kind=="fountain":
        fill_ellipse(grid,40,22,29,18,"grass");fill_ellipse(grid,40,22,16,11,"pale_stone");fill_ellipse(grid,40,22,6,5,"brass_plate");fill_ellipse(grid,40,22,3,2,"water_3");grid[22][40]="shrine_3"
        for point in ((40,3),(40,41),(5,22),(75,22)):path_line(grid,(40,22),point,2,"warm_path")
        landmarks=[{"id":"grand_fountain","tile":[40,22]}];routes=[{"id":"fountain_ring","kind":"ordinary"},{"id":"radial_launch_lines","kind":"advanced"}]
    elif kind=="gates":
        fill_ellipse(grid,40,22,28,17,"grass");fill_ellipse(grid,40,22,10,8,"pale_stone");grid[22][40]="shrine_5"
        for point in ((40,3),(40,41),(5,22),(75,22)):path_line(grid,(40,22),point,3,"warm_path")
        for x,y in ((40,7),(40,37),(10,22),(70,22)):fill_rect(grid,x-3,y-2,x+3,y+2,"roof_2")
        landmarks=[{"id":"portal_rotunda","tile":[40,22]}];routes=[{"id":"balcony_chain","kind":"advanced"},{"id":"gatehouse_roofs","kind":"advanced"}]
    elif kind=="movement":
        fill_ellipse(grid,40,22,35,18,"grass");path_line(grid,(8,22),(72,22),2,"warm_path");path_line(grid,(16,10),(64,10),0,"bridge_0");path_line(grid,(16,34),(64,34),0,"bridge_3")
        for y in range(14,31):grid[y][28]="cliff_1";grid[y][34]="cliff_2"
        for x in range(42,69,4):grid[28][x]="device_2"
        grid[22][64]="shrine_6";landmarks=[{"id":"rail_causeway","tile":[40,10]},{"id":"conservatory_spire","tile":[64,22]}];routes=[{"id":"wall_kick_wells","kind":"advanced"},{"id":"vault_slide_loop","kind":"advanced"},{"id":"island_leaps","kind":"advanced"}]
    elif kind=="basins":
        fill_ellipse(grid,40,22,31,18,"undercroft_floor");fill_ellipse(grid,40,22,17,11,"pale_stone")
        for i,(x,y) in enumerate(((40,22),(28,17),(52,17),(28,28),(52,28),(40,12),(40,33))):fill_ellipse(grid,x,y,4,3,f"water_{i%8}")
        path_line(grid,(8,22),(72,22),2,"warm_path");grid[22][40]="shrine_4";landmarks=[{"id":"seven_basin_crater","tile":[40,22]}];routes=[{"id":"basin_rim_run","kind":"advanced"},{"id":"crater_superglide","kind":"advanced"}]
    elif kind=="archive":
        fill_ellipse(grid,40,22,29,18,"grass");path_line(grid,(8,30),(72,30),2,"warm_path");fill_rect(grid,28,10,52,29,"pale_stone");fill_ellipse(grid,40,14,11,7,"roof_4")
        for x in (20,60):fill_rect(grid,x-5,14,x+5,31,"roof_1")
        grid[30][40]="shrine_1";landmarks=[{"id":"oracular_dome","tile":[40,14]}];routes=[{"id":"book_stack_vaults","kind":"advanced"},{"id":"archive_roofline","kind":"advanced"}]
    elif kind=="garden":
        fill_ellipse(grid,40,22,33,19,"grass");path_line(grid,(7,30),(73,30),2,"warm_path");path_line(grid,(40,5),(40,39),1,"warm_path")
        for x,y in ((18,13),(27,19),(54,13),(62,25),(22,33),(55,35)):fill_ellipse(grid,x,y,6,4,"moss");grid[y][x]="vegetation_3"
        grid[22][40]="shrine_0";landmarks=[{"id":"suspended_garden","tile":[40,22]}];routes=[{"id":"root_canopy","kind":"advanced"},{"id":"garden_platforms","kind":"ordinary"}]
    elif kind=="foundry":
        fill_rect(grid,8,6,71,38,"undercroft_floor");fill_rect(grid,11,9,68,35,"timber_floor");path_line(grid,(8,22),(72,22),2,"warm_path")
        for x in (23,40,57):fill_ellipse(grid,x,16,6,5,"brass_plate");grid[16][x]="device_4"
        for y in range(28,33):
            for x in range(12,68):grid[y][x]="water_5"
        grid[22][40]="shrine_7";landmarks=[{"id":"transmutation_engine","tile":[40,16]}];routes=[{"id":"machine_line","kind":"advanced"},{"id":"flooded_shortcut","kind":"advanced"}]
    elif kind=="observatory":
        fill_ellipse(grid,26,22,20,17,"grass");fill_ellipse(grid,54,22,20,17,"grass");path_line(grid,(26,22),(54,22),2,"bridge_2");fill_ellipse(grid,26,22,9,9,"pale_stone");fill_ellipse(grid,54,22,9,9,"pale_stone")
        grid[22][26]="shrine_2";grid[22][54]="device_5";landmarks=[{"id":"twin_astrolabes","tile":[40,22]}];routes=[{"id":"rooftop_redirects","kind":"advanced"},{"id":"astrolabe_ring","kind":"advanced"}]
    else:
        for cx,cy,tile in ((25,14,"grass"),(55,14,"moss"),(25,31,"pale_stone"),(55,31,"undercroft_floor")):fill_ellipse(grid,cx,cy,15,10,tile)
        path_line(grid,(25,14),(55,14),1,"bridge_0");path_line(grid,(25,31),(55,31),1,"bridge_3");path_line(grid,(25,14),(25,31),1,"warm_path");path_line(grid,(55,14),(55,31),1,"warm_path");grid[22][40]="shrine_6"
        landmarks=[{"id":"four_season_orrery","tile":[40,22]}];routes=[{"id":"changing_surface_run","kind":"advanced"},{"id":"island_leaps","kind":"advanced"}]
    mask=apply_shore(grid)
    return grid,mask,landmarks,routes


def rle(row: list[str]) -> list[list[Any]]:
    result=[]; value=row[0]; count=1
    for item in row[1:]:
        if item==value: count+=1
        else: result.append([value,count]);value=item;count=1
    result.append([value,count]);return result


def render_grid(grid: list[list[str]], atlas: Image.Image, regions: dict[str,Any]) -> Image.Image:
    image=Image.new("RGBA",(1280,720),rgba(base.PAL["water"]))
    for y,row in enumerate(grid):
        for x,tile in enumerate(row):
            region=regions[tile]["region"]
            source=atlas.crop((region[0],region[1],region[0]+16,region[1]+16))
            image.alpha_composite(source,(x*16,y*16))
    return image


def props_atlas() -> tuple[Image.Image,list[str],list[str]]:
    props=["door","switch","relay","capacitor","pump","sluice","furnace","prism","mirror","lift","crane","trap","portal","movable_cover","training_dummy","grapple_anchor"]
    states=["idle","focused","disabled","pending","active","success","failure","damaged"]
    image=Image.new("RGBA",(512,256));draw=ImageDraw.Draw(image)
    for row,state in enumerate(states):
        for column,prop in enumerate(props):
            x=column*32;y=row*32
            draw.rectangle((x+3,y+3,x+28,y+28),fill=rgba("#151918"),outline=rgba(base.PAL["brass"]),width=2)
            phase=[base.PAL["paper"],base.PAL["cyan"],"#555a58",base.PAL["violet"],base.PAL["fire"],"#75bf72","#c85149","#817a6b"][row]
            if prop in ("door","lift","movable_cover"):draw.rectangle((x+9,y+7,x+23,y+27),fill=rgba("#4b3226"),outline=rgba(phase))
            elif prop in ("portal","prism","mirror"):draw.ellipse((x+7,y+7,x+25,y+25),outline=rgba(phase),width=3)
            elif prop in ("training_dummy","grapple_anchor"):draw.line((x+16,y+7,x+16,y+27),fill=rgba(phase),width=3);draw.line((x+8,y+14,x+24,y+14),fill=rgba(phase),width=2)
            else:draw.rectangle((x+9,y+10,x+23,y+24),fill=rgba("#4b3226"),outline=rgba(phase));draw.ellipse((x+12,y+5,x+20,y+13),fill=rgba(phase))
    return image,props,states


def vfx_atlas() -> tuple[Image.Image,list[str],list[str]]:
    elements=["earth","fire","water","wind","ice","charge","light","dark"]
    phases=["startup","active","travel","impact","residue","reduced_motion"]
    colors=["#8d7d55",base.PAL["fire"],"#4aa4c2","#b8d9d2","#a4e5ee",base.PAL["cyan"],"#f3e7a0","#60428b"]
    image=Image.new("RGBA",(192,256));draw=ImageDraw.Draw(image)
    for row,(element,color) in enumerate(zip(elements,colors)):
        for column,phase in enumerate(phases):
            x=column*32;y=row*32;cx=x+16;cy=y+16
            draw.ellipse((x+3,y+3,x+29,y+29),outline=rgba(base.PAL["ink"]))
            if element=="earth":draw.polygon([(cx,cy-11),(cx+11,cy+8),(cx-11,cy+8)],fill=rgba(color))
            elif element=="fire":draw.polygon([(cx,cy-13),(cx+9,cy+10),(cx,cy+13),(cx-8,cy+8),(cx-3,cy)],fill=rgba(color))
            elif element=="water":draw.arc((x+5,y+8,x+27,y+27),180,360,fill=rgba(color),width=4)
            elif element=="wind":draw.arc((x+3,y+6,x+29,y+24),210,520,fill=rgba(color),width=2)
            elif element=="ice":
                for angle in range(0,180,45):
                    dx=math.cos(math.radians(angle))*11;dy=math.sin(math.radians(angle))*11
                    draw.line((cx-dx,cy-dy,cx+dx,cy+dy),fill=rgba(color),width=2)
            elif element=="charge":draw.polygon([(cx+2,cy-13),(cx-8,cy),(cx,cy),(cx-5,cy+13),(cx+10,cy-3),(cx+2,cy-3)],fill=rgba(color))
            elif element=="light":draw.ellipse((cx-7,cy-7,cx+7,cy+7),fill=rgba(color));draw.line((cx,cy-13,cx,cy+13),fill=rgba(color))
            else:draw.ellipse((cx-11,cy-11,cx+11,cy+11),fill=rgba(color));draw.ellipse((cx-5,cy-5,cx+5,cy+5),fill=rgba(base.PAL["ink"]))
            if phase=="reduced_motion":draw.rectangle((x+4,y+4,x+28,y+28),outline=rgba(base.PAL["paper"]))
    return image,elements,phases


def ui_skin() -> Image.Image:
    image=Image.new("RGBA",(256,256));draw=ImageDraw.Draw(image)
    draw.rectangle((0,0,255,255),fill=rgba("#101413"))
    panels=[(8,8,120,72),(136,8,248,72),(8,88,248,152),(8,168,248,248)]
    for rect in panels:
        draw.rounded_rectangle(rect,6,fill=rgba("#171c1a"),outline=rgba(base.PAL["brass"]),width=2)
        draw.line((rect[0]+8,rect[1]+13,rect[2]-8,rect[1]+13),fill=rgba(base.PAL["cyan"]))
    for i,color in enumerate((base.PAL["paper"],base.PAL["cyan"],base.PAL["violet"],base.PAL["fire"])):
        y=180+i*15;draw.rounded_rectangle((22,y,120,y+10),3,fill=rgba("#252b28"),outline=rgba(color));draw.rectangle((132,y,224,y+10),fill=rgba(color,90))
    return image


def hash_file(path: Path) -> str:
    digest=hashlib.sha256();digest.update(path.read_bytes());return digest.hexdigest()


def main() -> int:
    base.main()
    for directory in (ROOT/"assets/sprites/ancestries", ROOT/"assets/maps/sanctum/districts", ROOT/"assets/effects", ROOT/"assets/props", ROOT/"assets/ui"):
        if directory.exists(): shutil.rmtree(directory)
    catalog: dict[str,Any]={"schema_version":1,"id":"flux2-complete-visual-catalog-v1","generated_by":"tools/assets/generate_complete_visual_catalog_v1.py","status":"production_foundation","character_contract":{"cell_size":[32,32],"pivot":[16,28],"directions":base.DIRS,"animations":list(base.A)},"ancestries":{},"champions":{},"districts":{}}
    roster_board=Image.new("RGBA",(768,512),rgba("#101413"));board_draw=ImageDraw.Draw(roster_board)
    for index,ancestry in enumerate(ANCESTRIES):
        profile=neutral_profile(ancestry);clean=actor_atlas(profile);debug=actor_atlas(profile,True);directory=ROOT/f"assets/sprites/ancestries/{ancestry}";base.save(clean,directory/"base_atlas.png");base.save(debug,directory/"base_overlay_debug_atlas.png");base.save(preview_strip(clean),directory/"attachment_preview.png")
        catalog["ancestries"][ancestry]={"status":"body_plan_candidate" if ancestry in ("weaverkin","scorpionkin","harvestkin") else "production_foundation","size":profile["size"],"feature":profile["feature"],"atlas":f"res://assets/sprites/ancestries/{ancestry}/base_atlas.png","debug_atlas":f"res://assets/sprites/ancestries/{ancestry}/base_overlay_debug_atlas.png","preview":f"res://assets/sprites/ancestries/{ancestry}/attachment_preview.png"}
    for index,profile in enumerate(CHAMPIONS):
        clean=actor_atlas(profile);debug=actor_atlas(profile,True);directory=ROOT/f"assets/sprites/champions/{profile['id']}";base.save(clean,directory/f"{profile['id']}_atlas.png");base.save(debug,directory/f"{profile['id']}_overlay_debug_atlas.png");base.save(preview_strip(clean),directory/f"{profile['id']}_direction_preview.png");base.save(portrait(profile,clean,64),directory/f"{profile['id']}_portrait.png");base.save(portrait(profile,clean,32),directory/f"{profile['id']}_selection_icon.png")
        status=profile.get("status","integrated_candidate")
        catalog["champions"][profile["id"]]={"display_name":profile["name"],"status":status,"ancestry":profile["ancestry"],"size":profile["size"],"elements":profile["elements"],"weapon":profile["weapon"],"atlas":f"res://assets/sprites/champions/{profile['id']}/{profile['id']}_atlas.png","debug_atlas":f"res://assets/sprites/champions/{profile['id']}/{profile['id']}_overlay_debug_atlas.png","direction_preview":f"res://assets/sprites/champions/{profile['id']}/{profile['id']}_direction_preview.png","portrait":f"res://assets/sprites/champions/{profile['id']}/{profile['id']}_portrait.png","selection_icon":f"res://assets/sprites/champions/{profile['id']}/{profile['id']}_selection_icon.png"}
        px=(index%8)*96;py=(index//8)*160;portrait_image=Image.open(directory/f"{profile['id']}_portrait.png").resize((96,96),Image.Resampling.NEAREST);roster_board.alpha_composite(portrait_image,(px,py));board_draw.text((px+3,py+101),profile["name"][:15],fill=rgba(base.PAL["paper"]));board_draw.text((px+3,py+115),profile["ancestry"],fill=rgba(base.PAL["cyan"]));board_draw.text((px+3,py+129),status.replace("_"," ")[:16],fill=rgba(base.PAL["brass"]))
    base.save(roster_board,ROOT/"assets/sprites/champions/roster_overview_v1.png")
    tile_atlas,tile_regions=base.tiles();district_board=Image.new("RGBA",(960,720),rgba("#101413"));district_draw=ImageDraw.Draw(district_board)
    for index,(district_id,display_name,kind) in enumerate(DISTRICTS):
        grid,mask,landmarks,routes=district_grid(kind);preview=render_grid(grid,tile_atlas,tile_regions);directory=ROOT/"assets/maps/sanctum/districts";base.save(preview,directory/f"{district_id}_preview.png")
        data={"schema_version":1,"id":f"{district_id}-visual-v1","display_name":display_name,"authority":"presentation_only","tile_size":[16,16],"size_tiles":[80,45],"tileset":"res://assets/tiles/sanctum/sanctum_tiles_v1.png","rows_rle":[rle(row) for row in grid],"worldbone_mask_rows":["".join("1" if value else "0" for value in row) for row in mask],"landmarks":landmarks,"routes":routes};path=ROOT/f"content/maps/districts/{district_id}_visual_v1.json";path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        catalog["districts"][district_id]={"display_name":display_name,"status":"presentation_only","preview":f"res://assets/maps/sanctum/districts/{district_id}_preview.png","layout":f"res://content/maps/districts/{district_id}_visual_v1.json","landmarks":landmarks,"routes":routes}
        thumb=preview.resize((320,180),Image.Resampling.NEAREST);x=(index%3)*320;y=(index//3)*240;district_board.alpha_composite(thumb,(x,y));district_draw.rectangle((x,y+180,x+319,y+239),fill=rgba("#111514"));district_draw.text((x+8,y+192),display_name,fill=rgba(base.PAL["paper"]));district_draw.text((x+8,y+210),"presentation only",fill=rgba(base.PAL["cyan"]))
    base.save(district_board,ROOT/"assets/maps/sanctum/sanctum_district_overview_v1.png")
    props,prop_order,prop_states=props_atlas();base.save(props,ROOT/"assets/props/world_interaction_props_v1.png");effects,effect_order,effect_phases=vfx_atlas();base.save(effects,ROOT/"assets/effects/element_vfx_v1.png");base.save(ui_skin(),ROOT/"assets/ui/sanctum_ui_skin_v1.png")
    catalog["props"]={"path":"res://assets/props/world_interaction_props_v1.png","cell_size":[32,32],"order":prop_order,"states":prop_states};catalog["element_vfx"]={"path":"res://assets/effects/element_vfx_v1.png","cell_size":[32,32],"elements":effect_order,"phases":effect_phases};catalog["ui"]={"skin":"res://assets/ui/sanctum_ui_skin_v1.png","status":"production_foundation"};catalog["overviews"]={"roster":"res://assets/sprites/champions/roster_overview_v1.png","districts":"res://assets/maps/sanctum/sanctum_district_overview_v1.png"}
    catalog_path=ROOT/"content/visual/complete_visual_catalog_v1.json";catalog_path.write_text(json.dumps(catalog,indent=2)+"\n",encoding="utf-8")
    files=[]
    for root in (ROOT/"assets/sprites/ancestries",ROOT/"assets/sprites/champions",ROOT/"assets/maps/sanctum",ROOT/"assets/effects",ROOT/"assets/props",ROOT/"assets/ui",ROOT/"content/maps/districts",catalog_path):
        candidates=[root] if root.is_file() else [path for path in root.rglob("*") if path.is_file()]
        for path in candidates:
            if path.suffix.lower() in (".png",".json"):
                files.append({"path":path.relative_to(ROOT).as_posix(),"bytes":path.stat().st_size,"sha256":hash_file(path)})
    hash_path=ROOT/"content/visual/complete_visual_hashes_v1.json";hash_path.write_text(json.dumps({"schema_version":1,"files":sorted(files,key=lambda item:item["path"])},indent=2)+"\n",encoding="utf-8")
    print(f"generated complete visual catalog: {len(ANCESTRIES)} ancestries, {len(CHAMPIONS)} champions, {len(DISTRICTS)} districts, {len(files)} hashed files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
