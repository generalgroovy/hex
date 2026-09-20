#!/usr/bin/env python3
"""FLUX Wellspring standalone pixel kit. Original integer-grid raster source.

Run from any directory: python source/build_kit.py
Optional palette: python source/build_kit.py --palette source/palette.json
Every write is constrained to this script's parent kit folder. No repository edits.
Python 3.10+ and Pillow required; no network, game engine, or source sprites needed.
"""
from __future__ import annotations
import argparse, base64, hashlib, io, json, math, random, sys, zipfile
from functools import lru_cache
from collections import Counter
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CELL = 32
BITS = {'N':1,'E':2,'S':4,'W':8}
DIRS = {'N':(0,-1),'E':(1,0),'S':(0,1),'W':(-1,0)}
CORNERS = {'NW':('N','W',-1,-1), 'NE':('N','E',1,-1), 'SE':('S','E',1,1),'SW':('S','W',-1,1)}
DEFAULT_PALETTE = {
 'ink':'#202330','deep':'#292d38','shadow':'#353640',
 'bone_dark':'#333a46','bone':'#454d5a','bone_top':'#616b77','bone_light':'#88909a',
 'stone_dark':'#625c53','stone_shade':'#887d69','stone':'#aa9c80','stone_light':'#c8b898','stone_high':'#e0cfac',
 'pave_dark':'#928b7b','pave':'#a09a88','pave_light':'#aaa391',
 'plaster_shade':'#a09479','plaster':'#c1b390','plaster_light':'#d5c7a5',
 'wood_dark':'#403534','wood_shade':'#635040','wood':'#92704f','wood_light':'#b69565',
 'brass_dark':'#6d624b','brass':'#a18d5b','brass_light':'#d0b97d',
 'roof_dark':'#2e344e','roof':'#485371','roof_light':'#677592','roof_high':'#919bb1',
 'soil_dark':'#6b5e4c','soil':'#837255','soil_light':'#8d7b5f',
 'grass_dark':'#485741','grass':'#61704e','grass_light':'#6d7b53',
 'leaf_dark':'#2f473b','leaf':'#4b6647','leaf_light':'#798855','leaf_high':'#9aa16a',
 'water_dark':'#254a4d','water':'#346767','water_light':'#4a827c','water_high':'#7aa49b',
 'cloth_dark':'#574555','cloth':'#856275','cloth_light':'#ab8590',
 'flower':'#b78577','ember':'#a45b40','flame':'#df9d59','flame_high':'#eed39b'
}
P: dict[str,tuple[int,int,int,int]]={}
PALETTE_META={}
ASSETS: list[dict]=[]
FRAMES: dict[str,list[Image.Image]]={}
SHEETS: dict[str,Image.Image]={}
FAMILIES=['paving','earth','grass','worldbone','water']
MATERIAL={
 'paving':('pave','pave_dark','pave_light'),
 'earth':('soil','soil_dark','soil_light'),
 'grass':('grass','grass_dark','grass_light'),
 'worldbone':('bone','bone_dark','bone_top'),
 'water':('water','water_dark','water_light')
}

def relwrite(path:str, data:bytes|str):
    p=(ROOT/path).resolve()
    if not p.is_relative_to(ROOT): raise ValueError('Output escapes kit folder')
    p.parent.mkdir(parents=True,exist_ok=True)
    if isinstance(data,str): p.write_text(data,encoding='utf-8')
    else: p.write_bytes(data)

def jsave(path:str,obj): relwrite(path,json.dumps(obj,indent=2,ensure_ascii=False)+'\n')
def image(w:int,h:int)->Image.Image: return Image.new('RGBA',(w,h),(0,0,0,0))
def col(c): return P[c] if isinstance(c,str) else c

def rect(im,xy,c):
    if xy[2]>=xy[0] and xy[3]>=xy[1]: ImageDraw.Draw(im).rectangle(tuple(map(int,xy)),fill=col(c))
def line(im,xy,c,width=1): ImageDraw.Draw(im).line(xy,fill=col(c),width=width)
def poly(im,points,c): ImageDraw.Draw(im).polygon(points,fill=col(c))
def ell(im,xy,c): ImageDraw.Draw(im).ellipse(xy,fill=col(c))
def cut(im,xy): rect(im,xy,(0,0,0,0))
def pix(im,x,y,c):
    if 0<=x<im.width and 0<=y<im.height: im.putpixel((x,y),col(c))
def paste(im,part,xy): im.alpha_composite(part,(int(xy[0]),int(xy[1])))
def rng(seed): return random.Random(seed)

def add(name,frames,group,*,foot=None,cells=None,pivot=None,role=None,ticks=1,loop=False,connectors=None,autotile=None,notes='',motion=None,occlusion=None):
    if isinstance(frames,Image.Image): frames=[frames]
    w,h=frames[0].size
    assert all(f.size==(w,h) and f.mode=='RGBA' for f in frames)
    if foot is None: foot=[0,h-32,w,32]
    fx,fy,fw,fd=foot
    if cells is None: cells=[math.ceil(fw/32),math.ceil(fd/32)]
    if pivot is None: pivot=[fx+fw//2,fy+fd//2]
    if role is None: role={'terrain':'terrain_base','architecture':'architecture_body','props':'prop_body','ambient':'ambient_overlay'}[group]
    id='map.'+name
    assert id not in FRAMES, id
    path=f'export/{group}/{name.replace(".","_")}.png'
    sheet=image(w*len(frames),h)
    for i,f in enumerate(frames): paste(sheet,f,(i*w,0))
    sheet.save(ROOT/path,optimize=True)
    durations=[ticks]*len(frames) if isinstance(ticks,int) else list(ticks)
    assert len(durations)==len(frames)
    a={
      'id':id,'path':path,'group':group,
      'frames':[{'rect':[i*w,0,w,h],'duration_ticks':durations[i]} for i in range(len(frames))],
      'loop':bool(loop),'pivot_px':pivot,'frame_size_px':[w,h],
      'tile_dimensions_px':[32,32],'nominal_ground_cells':cells,
      'layer_role':role,'completion_status':'complete_standalone_palette_unverified',
      'visual_ground_footprint':{'rect_px':foot,'polygon_px':[[fx,fy],[fx+fw,fy],[fx+fw,fy+fd],[fx,fy+fd]],'descriptive_only':True,'collision_authority':False},
      'connectors':connectors or {},'autotile':autotile,
      'occlusion_suggestions':occlusion or {'authority':'suggestion_only','ground_y_sort':role not in ('terrain_base','terrain_corner_overlay'),'policy':'Keep ground anchor fixed. Review upper parts against character readability; no runtime behavior supplied.'},
      'notes':notes,
      'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
    }
    if motion is not None: a['motion']=motion
    ASSETS.append(a); FRAMES[id]=frames; SHEETS[id]=sheet
    return id

def inner_texture(family,variant=0):
    im=image(32,32); base,edge,light=MATERIAL[family]; rect(im,(0,0,31,31),base)
    r=rng(2100+FAMILIES.index(family)*40+variant)
    if family=='paving':
        # Few quiet stone-joint fragments. Some interiors are intentionally blank.
        paths=[[(6,18),(17,18),(17,7)],[(8,8),(24,8),(24,17)],[(6,25),(13,25)],[]]
        if paths[variant]: line(im,paths[variant],edge)
        if variant==0: line(im,[(7,19),(13,19)],light)
        elif variant==1: line(im,[(9,9),(15,9)],light)
        elif variant==2: line(im,[(19,9),(24,9)],light)
        else: line(im,[(11,20),(14,20)],light)
    elif family in ('earth','grass'):
        for _ in range(3 if family=='earth' else 2):
            x,y=r.randrange(5,26),r.randrange(5,26)
            rect(im,(x,y,x+r.randrange(2,5),y+1),light)
            if family=='grass': pix(im,x+1,y-1,light)
        for _ in range(1):
            x,y=r.randrange(5,26),r.randrange(5,26); line(im,[(x,y),(x+2,y)],edge)
    elif family=='worldbone':
        line(im,[(6,22),(14,22),(17,19),(25,19)],edge)
        line(im,[(7,23),(12,23)],light)
        line(im,[(20,6),(20,11),(22,13)],edge)
        if variant%2: rect(im,(6,8,9,9),light)
    elif family=='water':
        # No bright caustics. Static negative-space bands; motion is opt-in overlay.
        for x,y,l in [(6,10,6),(18,22,6)]:
            line(im,[(x,y),(x+l,y)],light)
            line(im,[(x+2,y+1),(x+l-1,y+1)],base)
        if variant%2: line(im,[(13,17),(17,17)],edge)
    return im

def terrain_tile(family,mask,variant=0):
    im=inner_texture(family,variant); edge=MATERIAL[family][1]
    if not mask&1: rect(im,(0,0,31,1),edge)
    if not mask&2: rect(im,(30,0,31,31),edge)
    if not mask&4: rect(im,(0,30,31,31),edge)
    if not mask&8: rect(im,(0,0,1,31),edge)
    return im

def corner_image(family,corner,kind):
    im=image(32,32); _,edge,light=MATERIAL[family]
    def transform(x,y): return (31-x if 'E' in corner else x,31-y if 'S' in corner else y)
    if kind=='concave':
        # A 2x2 diagonal notch makes full seam profiles agree at concave junctions.
        for y in range(2):
            for x in range(2): pix(im,*transform(x,y),edge)
    else:
        # Optional corner wear is inward from both boundary collars.
        for x,y in [(2,2),(3,2),(2,3)]: pix(im,*transform(x,y),light)
    return im

def generate_terrain():
    for fam in FAMILIES:
        for mask in range(16):
            add(f'terrain.{fam}.mask_{mask:02d}',terrain_tile(fam,mask),'terrain',foot=[0,0,32,32],role='terrain_base',autotile={'family':fam,'scheme':'four_neighbor_with_explicit_corner_overlays','mask':mask,'bits':BITS,'variant':0},notes='Opaque base. Exposed material boundary is an intentional two-pixel material-colored seam, not a gap.')
        for v in range(1,4):
            add(f'terrain.{fam}.fill_v{v}',inner_texture(fam,v),'terrain',foot=[0,0,32,32],autotile={'family':fam,'scheme':'interior_fill_variation','requires_mask':15,'variant':v},notes='Use in fully connected interiors only. Shares the same two-pixel boundary collar.')
        for corner in CORNERS:
            for kind in ['concave','convex']:
                add(f'terrain.{fam}.corner_{kind}_{corner.lower()}',corner_image(fam,corner,kind),'terrain',foot=[0,0,32,32],role='terrain_corner_overlay',autotile={'family':fam,'scheme':'explicit_corner_overlay','corner':corner,'kind':kind},notes='Concave: both adjacent cardinals match and the diagonal differs. Convex: neither adjacent cardinal matches; optional interior wear only.')


def ground_plan(mask):
    p=Image.new('L',(32,32),0); d=ImageDraw.Draw(p)
    d.rectangle((4,4,27,27),fill=255)
    if mask&1: d.rectangle((4,0,27,15),fill=255)
    if mask&2: d.rectangle((16,4,31,27),fill=255)
    if mask&4: d.rectangle((4,16,27,31),fill=255)
    if mask&8: d.rectangle((0,4,15,27),fill=255)
    return p

def wall_sprite(mask,height=48,ledge=False):
    # Cardinal extrusion: x stays x; elevation projects only upward on the image.
    h=96 if height>=20 else 64; oy=h-32
    plan=ground_plan(mask); im=image(32,h)
    for x in range(32):
        ys=[y for y in range(32) if plan.getpixel((x,y))]
        if not ys: continue
        end=max(ys)
        rect(im,(x,oy+min(ys)-height,x,oy+end),'bone_dark' if x>25 else 'bone')
        pix(im,x,oy+end,'ink')
        for y in range(oy+end-height+4,oy+end-1):
            if y%16==0: pix(im,x,y,'bone_dark')
        if height>25 and 7<=x<=9: rect(im,(x,oy+end-height+7,x,oy+end-7),'bone_dark')
        if x in (11,24) and height>25: rect(im,(x,oy+end-height+12,x,oy+end-10),'bone_top')
    # Cap comes last, retaining matching pixels at connected cardinal ends.
    for y in range(32):
        for x in range(32):
            if not plan.getpixel((x,y)): continue
            c='bone_top'
            if y==0 or not plan.getpixel((x,y-1)): c='bone_light'
            if x==0 or not plan.getpixel((x-1,y)): c='bone_light'
            if y==31 or not plan.getpixel((x,y+1)): c='bone_dark'
            pix(im,x,oy+y-height,c)
    # Deliberate inboard fossil/rib detail, never random noise on connector edges.
    if height>20:
        line(im,[(10,oy+11-height),(18,oy+11-height),(21,oy+14-height)],'bone')
        line(im,[(11,oy+12-height),(17,oy+12-height)],'bone_light')
    return im

def pillar(low=False):
    im=image(32,96); y=59 if low else 15
    ell(im,(2,77,29,94),'ink')
    rect(im,(5,y+13,26,86),'bone_dark'); rect(im,(7,y+14,21,86),'bone')
    rect(im,(8,y+14,10,84),'bone_top'); rect(im,(23,y+17,25,84),'deep')
    poly(im,[(3,y+5),(8,y),(23,y),(28,y+5),(28,y+17),(23,y+22),(8,y+22),(3,y+17)],'ink')
    poly(im,[(4,y+5),(8,y+1),(22,y+1),(27,y+5),(27,y+15),(22,y+20),(8,y+20),(4,y+15)],'bone_top')
    line(im,[(5,y+5),(9,y+2),(21,y+2)],'bone_light',2)
    line(im,[(8,y+20),(23,y+20)],'bone_dark',2)
    rect(im,(3,83,28,89),'bone_dark'); rect(im,(4,82,26,84),'bone_top')
    for x in (8,22): rect(im,(x,y+7,x+1,y+8),'brass')
    return im

def generate_walls():
    for profile,height in [('standard',48),('low',20),('ledge',8)]:
        for mask in range(16):
            im=wall_sprite(mask,height,profile=='ledge')
            names=[k for k in BITS if mask&BITS[k]]
            add(f'worldbone.{profile}.mask_{mask:02d}',im,'architecture',foot=[0,im.height-32,32,32],connectors={k:('worldbone_'+profile if k in names else 'closed_end') for k in BITS},autotile={'family':'worldbone_'+profile,'scheme':'four_neighbor','mask':mask,'bits':BITS,'closed_ends_baked':True},notes=f'Cardinal plan extrusion, {height}px visual rise. Ends, L/T/cross corners and isolated post are included. Descriptive art, not a wallrun collider.')
    add('worldbone.pillar.tall',pillar(),'architecture')
    add('worldbone.pillar.low',pillar(True),'architecture',notes='Low-profile counterpart shares the tall pillar anchor and 32x96 canvas.')


def bank(direction):
    im=image(32,64); oy=32
    # All versions drawn separately in world light, never rotated shaded artwork.
    if direction in ('N','S'):
        y=oy+4 if direction=='N' else oy+20
        rect(im,(0,y,31,y+8),'stone_dark'); rect(im,(0,y-5,31,y),'stone')
        line(im,[(0,y-5),(31,y-5)],'stone_light'); line(im,[(0,y+7),(31,y+7)],'ink')
        line(im,[(15,y-4),(15,y-1)],'stone_shade')
        line(im,[(16,y+1),(16,y+6)],'stone_shade')
    else:
        x=3 if direction=='W' else 21
        rect(im,(x,oy-4,x+7,61),'stone_dark'); rect(im,(x,oy-8,x+7,55),'stone')
        line(im,[(x,oy-8),(x,55)],'stone_light'); line(im,[(x+7,oy-7),(x+7,57)],'stone_dark')
        for y in (oy+6,oy+22): line(im,[(x+1,y),(x+6,y)],'stone_shade')
    return im

def bank_corner(corner):
    im=image(32,64)
    for d in corner: paste(im,bank(d),(0,0))
    return im

def bridge(orientation,layer):
    w,h=(96,96) if orientation=='EW' else (64,128)
    im=image(w,h)
    if layer=='deck':
        if orientation=='EW':
            rect(im,(0,35,95,89),'wood_dark'); rect(im,(0,31,95,82),'wood')
            rect(im,(0,31,95,34),'wood_light'); rect(im,(0,79,95,82),'wood_shade')
            for x in range(11,96,12):
                rect(im,(x,35,x,78),'wood_dark'); rect(im,(x+1,35,x+1,76),'wood_light')
            for x,y in [(5,45),(27,64),(57,54),(79,69)]: line(im,[(x,y),(x+3,y+1)],'wood_shade')
            for x in (2,91):
                rect(im,(x,32,x+2,82),'brass_dark'); rect(im,(x,32,x,80),'brass')
        else:
            rect(im,(3,34,60,122),'wood_dark'); rect(im,(3,30,60,116),'wood')
            rect(im,(3,30,6,116),'wood_light'); rect(im,(57,30,60,116),'wood_shade')
            for y in range(40,118,11):
                line(im,[(7,y),(56,y)],'wood_dark'); line(im,[(7,y+1),(56,y+1)],'wood_light')
            for y in (32,111):
                rect(im,(4,y,59,y+3),'brass_dark'); line(im,[(4,y),(58,y)],'brass')
    else:
        if orientation=='EW':
            y=27 if layer=='rear_rail' else 77
            for x in (2,45,90):
                rect(im,(x,y-24,x+4,y+4),'wood_dark'); rect(im,(x,y-24,x+1,y+2),'wood_light')
                rect(im,(x-1,y-25,x+5,y-22),'brass')
            rect(im,(0,y-19,95,y-14),'wood_dark'); rect(im,(0,y-20,95,y-18),'wood')
            line(im,[(0,y-20),(95,y-20)],'wood_light')
        else:
            x=4 if layer=='rear_rail' else 56
            for y in (30,71,115):
                rect(im,(x-2,y-24,x+3,y+1),'wood_dark'); rect(im,(x-2,y-24,x,y),'wood_light')
                rect(im,(x-3,y-25,x+4,y-22),'brass')
            rect(im,(x-1,9,x+3,98),'wood_dark'); rect(im,(x-2,9,x,98),'wood')
            line(im,[(x-2,9),(x-2,98)],'wood_light')
    return im

def stairs(direction,ramp=False):
    im=image(64,96)
    def rise(x,y):
        t={'N':63-y,'S':y,'W':63-x,'E':x}[direction]
        return (t*16)//63 if ramp else ((t//16)*4+4)
    for y in range(2,62):
        for x in range(2,62):
            z=rise(x,y); top=32+y-z
            # Southward raster depth order. Height goes up, ground stays cardinal.
            rect(im,(x,top,x,32+y),'stone_shade')
            if x==61: rect(im,(x,top,x,32+y),'stone_dark')
            if x==2: rect(im,(x,top,x,32+y),'stone_light')
            c='stone'
            if x in (2,3) or y==2: c='stone_light'
            if x==61: c='stone_dark'
            if not ramp:
                if direction in ('N','S') and y%16 in (0,1): c='stone_light' if y%16==0 else 'stone_shade'
                if direction in ('E','W') and x%16 in (0,1): c='stone_light' if x%16==0 else 'stone_shade'
            elif x in (7,56): c='stone_light' if x==7 else 'stone_shade'
            pix(im,x,top,c)
    # The south apron makes the actual height change legible without UI arrows.
    for x in range(2,62):
        top=32+61-rise(x,61)
        pix(im,x,top,'stone_light')
        pix(im,x,94,'stone_dark')
    if ramp:
        for x,y in ((22,25),(37,44)):
            yy=32+y-rise(x,y)
            line(im,[(x,yy),(x+5,yy)],'stone_shade')
    return im


def generate_channels():
    for d in BITS:
        add(f'channel.bank.water_{d.lower()}',bank(d),'architecture',connectors={'tangent_axis':'EW' if d in 'NS' else 'NS','water_side':d,'rise_px':8},notes='Water side is a placement hint. No walkability or collider is assigned.')
    for c in CORNERS:
        add(f'channel.bank.corner_{c.lower()}',bank_corner(c),'architecture',connectors={'water_sides':list(c),'kind':'outside_corner'},notes='Orthogonal outside corner. Dedicated reverse inside banks are not supplied; see QA limits.')
    for ori in ('EW','NS'):
        w,h=(96,96) if ori=='EW' else (64,128)
        foot=[0,32,w,h-32]
        for layer in ('deck','rear_rail','front_rail'):
            add(f'bridge.{ori.lower()}.{layer}',bridge(ori,layer),'architecture',foot=foot,role='traversable_surface' if layer=='deck' else ('rear_detail' if layer=='rear_rail' else 'foreground_detail'),connectors={'traversal_axis':ori,'span_cells':3,'width_cells':2,'registration_group':f'bridge_{ori}'},notes='Separate deck and two rail layers share canvas and ground anchor. These are visuals, not traversal rules.')
    for d in BITS:
        for kind in ('steps','ramp'):
            add(f'access.{kind}.rise_{d.lower()}',stairs(d,kind=='ramp'),'architecture',foot=[0,32,64,64],role='traversable_surface',connectors={'suggested_rise_direction':d,'visual_rise_px':16},notes='Rise annotation is descriptive only; author must reconcile existing production elevations.')


def masonry(im,box,material='stone',seed=1):
    x0,y0,x1,y1=box; rect(im,box,material)
    for j,y in enumerate(range(y0+14,y1,16)):
        line(im,[(x0,y),(x1,y)],'stone_shade')
        for x in range(x0+(14 if j%2 else 28),x1,28):
            line(im,[(x,y-13),(x,y-1)],'stone_shade')
    for x,y in [(x0+5,y0+6),(x1-12,y1-7)]:
        if y<y1 and x<x1: line(im,[(x,y),(x+5,y)],'stone_light')

def arch_polygon(x0,x1,top,bottom):
    mid=(x0+x1)//2
    return [(x0,bottom),(x0,top+14),(x0+3,top+8),(x0+8,top+3),(mid-4,top),(mid+4,top),(x1-8,top+3),(x1-3,top+8),(x1,top+14),(x1,bottom)]

def facade(kind):
    im=image(64,160)
    rect(im,(0,40,63,153),'stone_dark')
    masonry(im,(0,43,63,148),'plaster')
    # Large quiet plaster fields with local wear at the base, not uniform bricks.
    rect(im,(7,55,56,129),'plaster'); rect(im,(8,57,54,124),'plaster_light')
    rect(im,(55,54,61,136),'plaster_shade')
    rect(im,(0,39,63,46),'stone_shade'); rect(im,(0,38,63,40),'stone_light')
    rect(im,(0,145,63,154),'stone_shade'); rect(im,(0,145,63,148),'stone_light')
    rect(im,(0,154,63,157),'stone_dark')
    for x,y in [(7,130),(50,137)]: rect(im,(x,y,x+5,y+2),'stone_shade')
    if kind in ('window','arched_window'):
        outer=arch_polygon(12,51,65,122)
        poly(im,outer,'stone_dark'); poly(im,arch_polygon(14,49,65,118),'stone_light')
        poly(im,arch_polygon(18,45,69,115),'wood_dark'); poly(im,arch_polygon(20,43,72,113),'roof_dark')
        rect(im,(22,86,30,108),'roof'); rect(im,(34,80,41,108),'roof')
        rect(im,(30,73,33,116),'brass_dark'); rect(im,(30,73,31,114),'brass')
        rect(im,(20,93,43,95),'brass'); line(im,[(21,78),(24,75)],'roof_light')
        rect(im,(10,121,53,126),'stone_dark'); rect(im,(9,120,52,123),'stone_light')
        if kind=='arched_window':
            for x in (10,49): rect(im,(x,75,x+3,115),'wood'); line(im,[(x,76),(x,114)],'wood_light')
    elif kind=='door_frame':
        poly(im,arch_polygon(8,55,55,146),'stone_shade')
        poly(im,arch_polygon(10,53,56,145),'stone_light')
        poly(im,arch_polygon(15,48,63,149),(0,0,0,0))
        for x,y in [(9,86),(9,111),(51,86),(51,111)]: rect(im,(x,y,x+3,y+2),'stone_dark')
        rect(im,(13,148,50,152),'stone_light'); line(im,[(13,153),(50,153)],'stone_dark')
        rect(im,(29,54,35,64),'brass_dark'); rect(im,(30,54,34,60),'brass')
    elif kind=='buttress':
        masonry(im,(23,46,41,148),'stone')
        rect(im,(22,46,25,148),'stone_light'); rect(im,(39,47,42,149),'stone_dark')
        rect(im,(18,134,47,151),'stone_shade'); rect(im,(17,132,46,137),'stone_light')
        for y in (78,109): rect(im,(21,y,43,y+3),'stone_shade')
    return im

def door_panel():
    im=image(64,160); poly(im,arch_polygon(15,48,63,148),'wood_dark'); poly(im,arch_polygon(17,46,66,147),'wood')
    for x in (22,29,36,43): line(im,[(x,76),(x,146)],'wood_dark'); line(im,[(x+1,77),(x+1,145)],'wood_light')
    for y in (91,130):
        rect(im,(18,y,45,y+4),'brass_dark'); line(im,[(18,y),(45,y)],'brass')
        for x in (21,42): pix(im,x,y+1,'brass_light')
    ell(im,(38,111,43,118),'ink'); ell(im,(39,111,43,117),'brass'); ell(im,(40,112,42,115),'wood_dark')
    return im

def low_facade():
    im=image(64,64); masonry(im,(0,21,63,55),'stone')
    rect(im,(0,19,63,26),'stone_light'); rect(im,(0,58,63,62),'stone_dark'); rect(im,(0,54,63,57),'stone_shade')
    return im

def roof(kind):
    im=image(64,160)
    shape=[(0,9),(63,9),(63,70),(0,70)]
    if kind=='end_w': shape=[(16,9),(63,9),(63,70),(0,70),(0,35)]
    if kind=='end_e': shape=[(0,9),(47,9),(63,35),(63,70),(0,70)]
    poly(im,shape,'roof_dark')
    mask=Image.new('1',im.size,0); ImageDraw.Draw(mask).polygon(shape,fill=1)
    for y in range(11,68):
        for x in range(64):
            if not mask.getpixel((x,y)): continue
            c='roof' if y<57 else 'roof_dark'
            if (y-11)%9 in (0,1): c='roof_light' if y<48 else 'roof'
            if x%16==(8 if ((y-11)//9)%2 else 0) and (y-11)%9>=2: c='roof_dark'
            pix(im,x,y,c)
    line(im,[(17 if kind=='end_w' else 0,9),(46 if kind=='end_e' else 63,9)],'brass',2)
    if kind=='end_w': line(im,[(16,10),(0,36),(0,67)],'roof_high',2)
    if kind=='end_e': line(im,[(47,10),(63,36),(63,67)],'roof_dark',2)
    rect(im,(0,68,63,73),'wood_dark'); rect(im,(0,67,63,69),'brass_dark'); line(im,[(0,67),(63,67)],'brass')
    for x in (9,42): rect(im,(x,72,x+4,76),'wood_shade')
    shifted=image(64,160); paste(shifted,im.crop((0,9,64,160)),(0,0))
    return shifted

def arch_layer(layer):
    im=image(96,160)
    if layer=='supports':
        for x in (3,74):
            masonry(im,(x,69,x+18,147),'stone')
            rect(im,(x,69,x+2,146),'stone_light'); rect(im,(x+16,70,x+19,148),'stone_dark')
            rect(im,(x-3,139,x+21,153),'stone_shade'); rect(im,(x-3,138,x+20,142),'stone_light')
            rect(im,(x-3,74,x+21,79),'stone_light')
    else:
        poly(im,arch_polygon(0,95,27,83),'stone_dark')
        poly(im,arch_polygon(2,93,26,80),'stone')
        poly(im,arch_polygon(6,89,29,80),'stone_light')
        poly(im,arch_polygon(22,73,47,84),(0,0,0,0))
        for x,y in [(14,43),(28,34),(45,29),(64,34),(80,43)]:
            line(im,[(x,y),(x+2,y+8)],'stone_shade',2)
        rect(im,(43,28,52,44),'brass_dark'); rect(im,(44,28,50,40),'brass')
        rect(im,(37,26,58,28),'stone_high')
    return im

def side_return(side):
    im=image(32,192); oy=128
    rect(im,(4,oy-96,27,188),'plaster_shade')
    rect(im,(5,oy-98,25,oy-34),'stone')
    line(im,[(5,oy-98),(25,oy-98)],'stone_light',2)
    for y in range(oy-31,188,16): line(im,[(5,y),(26,y)],'stone_shade')
    rect(im,(4 if side=='W' else 24,oy-95,6 if side=='W' else 27,185),'stone_light' if side=='W' else 'stone_dark')
    rect(im,(4,184,27,189),'stone_dark')
    return im

def courtyard_trim(sides):
    im=image(32,32)
    for side in sides:
        if side in 'NS':
            y=0 if side=='N' else 26
            rect(im,(0,y,31,y+5),'stone_shade')
            line(im,[(0,y+1),(31,y+1)],'stone_light')
            line(im,[(0,y+4),(31,y+4)],'stone')
            pix(im,15,y+2,'stone_dark')
        else:
            x=0 if side=='W' else 26
            rect(im,(x,0,x+5,31),'stone_shade')
            line(im,[(x+1,0),(x+1,31)],'stone_light')
            line(im,[(x+4,0),(x+4,31)],'stone')
            pix(im,x+2,15,'stone_dark')
    return im

def generate_academy():
    for sides in ('N','E','S','W','NW','NE','SE','SW'):
        add(f'academy.courtyard.trim_{sides.lower()}',courtyard_trim(sides),'architecture',foot=[0,0,32,32],role='terrain_decoration',connectors={'edge_sides':list(sides),'ground_decal':True},notes='Optional inset courtyard stone border. No raised collider or gameplay edge is implied.')
    for kind in ('blank','window','arched_window','door_frame','buttress'):
        add(f'academy.facade.{kind}',facade(kind),'architecture',connectors={'W':'academy_facade_2c','E':'academy_facade_2c','facing':'S','registration_group':'academy_bay'},notes='South-facing facade. 2-cell module, 32px visual footprint depth. Door aperture is alpha, never a new gameplay opening.')
    add('academy.door.closed_panel',door_panel(),'architecture',role='door_panel',connectors={'registration_group':'academy_bay'},notes='Separate panel; open state is omission of this layer. No interaction or open/close animation supplied.')
    add('academy.facade.low_profile',low_facade(),'architecture',connectors={'W':'academy_low','E':'academy_low'},notes='Low plinth alternative. Use only under an existing, explicitly selected visibility policy.')
    for kind in ('end_w','middle','end_e'):
        add(f'academy.roof.{kind}',roof(kind),'architecture',role='roof_foreground',foot=[0,128,64,32],connectors={'W':'roof_bay' if kind!='end_w' else 'closed_hip','E':'roof_bay' if kind!='end_e' else 'closed_hip','registration_group':'academy_bay'},notes='Separate elevated roof with same canvas and anchor as facade. No roof fading is installed.')
    for part in ('supports','lintel'):
        add(f'academy.arch.{part}',arch_layer(part),'architecture',role='architecture_body' if part=='supports' else 'foreground_detail',foot=[0,128,96,32],connectors={'registration_group':'academy_arch','opening_width_px':50},notes='The lintel is independently hideable art. Opening dimensions are visual observations, not collision authority.')
    for side in ('W','E'):
        add(f'academy.return.{side.lower()}',side_return(side),'architecture',foot=[0,128,32,64],connectors={'N':'academy_side','S':'academy_side','side':side},notes='Side-return visual strip; not a full directional interior architecture set.')


def footshadow(im,box): ell(im,box,'shadow')
def pot(im,x,y,w=48,h=26):
    ell(im,(x,y+h-10,x+w,y+h+8),'shadow')
    poly(im,[(x+2,y),(x+w-2,y),(x+w-7,y+h),(x+8,y+h)],'stone_dark')
    poly(im,[(x+4,y),(x+w-4,y),(x+w-9,y+h-3),(x+10,y+h-3)],'stone')
    rect(im,(x+10,y+4,x+13,y+h-5),'stone_light')
    ell(im,(x,y-8,x+w,y+9),'stone_light'); ell(im,(x+4,y-4,x+w-4,y+6),'soil_dark')

def leaf_cluster(im,x,y,scale=1,flower=False):
    s=scale
    # Foliage is sculpted as a few readable pixel masses, not scattered particles.
    shapes=[(-12,-2,0,9),(-5,-12,10,3),(5,-4,17,10),(-5,1,9,16)]
    for i,(x0,y0,x1,y1) in enumerate(shapes):
        poly(im,[(x+x0*s,y+(y0+3)*s),(x+(x0+3)*s,y+y0*s),(x+(x1-3)*s,y+y0*s),(x+x1*s,y+(y0+4)*s),(x+(x1-1)*s,y+(y1-3)*s),(x+(x1-4)*s,y+y1*s),(x+(x0+2)*s,y+y1*s),(x+x0*s,y+(y1-4)*s)],'leaf_dark')
        rect(im,(x+(x0+3)*s,y+(y0+2)*s,x+(x1-4)*s,y+(y1-4)*s),'leaf')
        line(im,[(x+(x0+4)*s,y+(y0+2)*s),(x+(x1-5)*s,y+(y0+2)*s)],'leaf_light',2*s)
    for dx,dy in [(-4,-8),(8,0),(-7,3)]: rect(im,(x+dx*s,y+dy*s,x+(dx+3)*s,y+(dy+1)*s),'leaf_light')
    if flower:
        for dx,dy in [(-7,-7),(5,-3),(1,8)]:
            rect(im,(x+dx,y+dy,x+dx+3,y+dy+3),'flower'); pix(im,x+dx+1,y+dy+1,'stone_high')

def training_dummy():
    im=image(64,128); footshadow(im,(8,108,57,125))
    poly(im,[(15,116),(31,94),(49,117),(45,121),(31,107),(19,121)],'wood_dark')
    line(im,[(31,93),(17,117)],'wood_light',3); line(im,[(31,99),(47,118)],'wood',4)
    rect(im,(29,31,34,117),'wood_dark'); rect(im,(29,30,31,115),'wood_light')
    rect(im,(9,65,54,71),'wood_dark'); rect(im,(9,63,53,67),'wood')
    ell(im,(12,28,51,76),'wood_dark'); ell(im,(14,29,49,72),'wood')
    ell(im,(17,33,46,69),'stone'); ell(im,(22,38,41,63),'cloth_dark'); ell(im,(26,43,37,58),'cloth')
    ell(im,(29,47,34,53),'stone_high')
    for x,y in [(16,38),(20,62),(42,44),(36,32)]: line(im,[(x,y),(x+3,y+4)],'wood_light')
    rect(im,(26,78,38,82),'brass_dark'); rect(im,(26,78,36,79),'brass')
    return im

def lectern():
    im=image(64,96); footshadow(im,(11,73,55,93))
    poly(im,[(12,83),(31,71),(53,83),(48,90),(17,90)],'wood_dark')
    rect(im,(27,48,37,83),'wood_dark'); rect(im,(27,48,31,80),'wood_light')
    poly(im,[(9,35),(48,27),(57,54),(16,65)],'wood_dark')
    poly(im,[(10,33),(47,25),(55,51),(17,61)],'wood')
    line(im,[(11,33),(47,25)],'wood_light',2)
    poly(im,[(16,34),(29,31),(34,49),(23,55)],'stone_light')
    poly(im,[(30,31),(43,31),(49,49),(35,49)],'stone_high')
    line(im,[(29,32),(34,48)],'stone_shade')
    line(im,[(20,38),(26,36)],'stone_shade'); line(im,[(37,37),(43,38)],'stone')
    # Marks are page creases, not legible text.
    rect(im,(35,49,38,58),'cloth')
    return im

def signboard():
    im=image(64,96); footshadow(im,(8,75,58,94))
    for x in (13,46):
        rect(im,(x,29,x+5,86),'wood_dark'); rect(im,(x,29,x+1,85),'wood_light')
        rect(im,(x-4,84,x+8,89),'stone_dark')
    rect(im,(5,24,59,62),'wood_dark'); rect(im,(7,25,56,58),'wood')
    rect(im,(9,29,54,54),'wood_shade'); line(im,[(8,26),(55,26)],'wood_light',2)
    for x in (10,53):
        for y in (28,56): pix(im,x,y,'brass_light')
    return im

def bench():
    im=image(96,96); footshadow(im,(5,73,91,94))
    for x in (12,74):
        poly(im,[(x,58),(x+7,58),(x+12,89),(x+7,91)],'wood_dark')
        line(im,[(x+1,61),(x+7,87)],'wood_light',2)
        rect(im,(x,26,x+5,62),'wood_dark'); rect(im,(x,26,x+1,60),'wood_light')
    for y in (30,43):
        rect(im,(7,y,88,y+8),'wood_dark'); rect(im,(7,y,87,y+5),'wood'); line(im,[(7,y),(87,y)],'wood_light')
    rect(im,(4,59,90,73),'wood_dark'); rect(im,(4,56,89,66),'wood')
    line(im,[(4,56),(89,56)],'wood_light'); line(im,[(5,62),(88,62)],'wood_shade')
    for x in (15,78): rect(im,(x,60,x+2,61),'brass')
    return im

def planter(with_leaves=True):
    im=image(64,96); pot(im,7,61,49,25)
    if with_leaves:
        rect(im,(29,48,33,64),'wood_shade')
        leaf_cluster(im,23,42,1,True); leaf_cluster(im,39,41,1,True)
    return im

def lantern_housing():
    im=image(32,128); footshadow(im,(4,109,29,126))
    rect(im,(14,41,18,115),'wood_dark'); rect(im,(14,43,15,113),'wood_light')
    rect(im,(9,111,24,121),'stone_dark'); rect(im,(9,110,23,114),'stone')
    rect(im,(7,21,26,50),'brass_dark'); cut(im,(11,25,21,43))
    rect(im,(9,22,11,46),'brass'); rect(im,(22,23,24,46),'wood_dark')
    poly(im,[(4,22),(10,14),(22,14),(28,22)],'ink'); poly(im,[(6,20),(11,15),(21,15),(25,20)],'roof')
    line(im,[(7,20),(11,15),(20,15)],'roof_light')
    rect(im,(6,47,27,51),'ink'); rect(im,(7,46,25,48),'brass')
    rect(im,(13,10,19,14),'brass_dark'); rect(im,(14,10,17,11),'brass_light')
    return im

def banner_pole():
    im=image(64,128); footshadow(im,(4,110,31,125))
    rect(im,(13,11,17,115),'wood_dark'); rect(im,(13,11,14,115),'wood_light')
    poly(im,[(10,12),(15,2),(21,12),(15,17)],'brass_dark'); poly(im,[(12,11),(15,5),(18,11),(15,13)],'brass_light')
    rect(im,(16,22,54,25),'wood_dark'); rect(im,(16,21,53,22),'brass')
    rect(im,(8,112,25,121),'stone_dark'); rect(im,(8,111,24,115),'stone')
    return im

def fountain_basin():
    im=image(96,128); footshadow(im,(0,91,95,127))
    ell(im,(3,63,92,123),'stone_dark'); ell(im,(4,57,91,115),'stone')
    ell(im,(6,56,89,109),'stone_light'); ell(im,(12,62,83,103),'stone_shade')
    ell(im,(15,65,80,100),(0,0,0,0))
    for x,y in [(10,88),(28,109),(59,109),(84,84)]: line(im,[(x,y),(x+1,y+9)],'stone_shade',2)
    line(im,[(26,61),(41,59)],'stone_high',2)
    line(im,[(23,114),(71,114)],'stone_shade',2)
    return im

def fountain_spout():
    im=image(96,128)
    ell(im,(35,83,62,103),'stone_dark'); rect(im,(43,41,53,93),'stone_shade'); rect(im,(43,43,46,91),'stone_light')
    ell(im,(26,35,68,55),'stone_dark'); ell(im,(26,31,68,50),'stone'); ell(im,(30,33,64,44),'water_dark')
    line(im,[(29,35),(36,32),(52,32)],'stone_high')
    rect(im,(45,21,51,34),'stone_shade'); ell(im,(43,16,54,28),'stone_light'); pix(im,46,18,'stone_high')
    return im

def workbench(material):
    im=image(96,96); footshadow(im,(5,71,90,95))
    for x in (11,75):
        rect(im,(x,53,x+9,88),'wood_dark'); rect(im,(x,54,x+3,85),'wood')
        rect(im,(x-2,85,x+11,91),'brass_dark')
    rect(im,(13,73,85,78),'wood_dark'); line(im,[(13,73),(84,73)],'wood')
    base,top,high=('stone_dark','stone','stone_light') if material=='stone' else (('bone_dark','bone_top','bone_light') if material=='worldbone' else ('brass_dark','brass','brass_light'))
    poly(im,[(4,41),(11,31),(83,31),(92,41),(92,63),(84,70),(11,70),(4,63)],base)
    poly(im,[(4,38),(11,29),(83,29),(91,38),(91,53),(84,61),(11,61),(4,53)],top)
    line(im,[(5,38),(12,30),(81,30)],high,2)
    for x in (26,66):
        ell(im,(x-10,37,x+10,52),base); ell(im,(x-7,39,x+7,49),'deep')
        line(im,[(x-6,39),(x+4,39)],high)
    rect(im,(41,36,49,55),base); rect(im,(43,36,44,53),high)
    return im

def generate_props():
    for name,im,foot,notes in [
      ('training_dummy',training_dummy(),[8,96,48,32],'Inert straw target on a timber practice stand, not a character or gameplay actor.'),
      ('lectern',lectern(),[8,64,48,32],'Open blank book with page folds, no baked readable text.'),
      ('signboard',signboard(),[0,64,64,32],'Blank face for separate game UI or localization. No baked lettering.'),
      ('bench',bench(),[0,64,96,32],'Perimeter seating. Rear support and seat are original timber clusters.'),
      ('planter.empty',planter(False),[0,64,64,32],'Empty basin to combine with independent foliage.'),
      ('planter.planted',planter(True),[0,64,64,32],'Static plant alternative for low-motion rooms.'),
      ('lantern.housing',lantern_housing(),[4,96,24,32],'Stationary housing. Add optional physical flame below housing layer.'),
      ('banner.pole',banner_pole(),[4,96,24,32],'Stationary pole. Cloth animations share this 64x128 registration.'),
      ('fountain.basin',fountain_basin(),[0,64,96,64],'Basin with alpha water aperture. Physical water is a separate ambient layer.'),
      ('fountain.spout',fountain_spout(),[0,64,96,64],'Optional static stone spout sharing basin registration.')]:
        add(f'prop.{name}',im,'props',foot=foot,notes=notes)
    for material in ('stone','brass','worldbone'):
        add(f'prop.workbench.{material}',workbench(material),'props',foot=[0,32,96,64],notes='Unassigned elemental-workbench shell with two empty sockets. No element roster, spell effect or interaction is invented.')


def water_motion(variant=0):
    frames=[]
    seq=[0,1,1,0]
    for i,off in enumerate(seq):
        im=image(32,32)
        for x,y,l in [(7,10,5),(19,22,5)]:
            y+=variant*2; x+=off
            line(im,[(x,y),(x+l,y)],'water_light')
            if i in (1,2): pix(im,x+l+1,y-1,'water_light')
        frames.append(im)
    return frames

def banner_motion(indigo=True):
    frames=[]
    for off in (0,1,2,1):
        im=image(64,128); dark,mid,light=('roof_dark','roof','roof_light') if indigo else ('cloth_dark','cloth','cloth_light')
        poly(im,[(19,25),(51,25),(51+off,65),(44+off,73),(36+off,67),(29+off,73),(20+off,66)],dark)
        poly(im,[(21,26),(49,26),(49+off,63),(44+off,69),(36+off,63),(29+off,69),(22+off,64)],mid)
        line(im,[(23,28),(24+off,61)],light,2)
        line(im,[(43,28),(44+off,64)],dark,2)
        line(im,[(21,28),(48,28)],'brass')
        poly(im,[(30,40),(35,35),(40,40),(35,48)],'brass_dark')
        line(im,[(31,40),(35,36),(38,40)],'brass')
        frames.append(im)
    return frames

def flame_motion():
    frames=[]
    for off in (0,-1,0,1):
        im=image(32,128)
        poly(im,[(13,43),(12,39),(15,33),(16+off,29),(20,38),(19,43)],'ember')
        poly(im,[(14,42),(14,38),(16+off,33),(18,38),(18,42)],'flame')
        rect(im,(15,39,16,42),'flame_high')
        frames.append(im)
    return frames

def foliage_motion():
    frames=[]
    for off in (0,1,1,0):
        im=image(64,96); rect(im,(29,48,33,64),'wood_shade')
        leaf_cluster(im,23,42,1,True); leaf_cluster(im,39,41,1,True)
        # Only one tip moves; the root and main silhouette stay registered.
        rect(im,(47,24,54,29),(0,0,0,0))
        poly(im,[(46,30),(50+off,24),(53+off,24),(52,29)],'leaf_light')
        frames.append(im)
    return frames

def fountain_motion():
    frames=[]
    for i in range(4):
        im=image(96,128); ell(im,(15,65,80,100),'water')
        # Restricted to basin aperture, no airborne magical cloud or combat burst.
        for x,y in [(26,78),(60,86),(31,91)]:
            line(im,[(x+(i%2),y),(x+7+(i%2),y)],'water_light')
        line(im,[(41,81+i%2),(54,81+i%2)],'water_high')
        frames.append(im)
    return frames

def fountain_overflow():
    frames=[]
    for i in range(4):
        im=image(96,128)
        for x,phase in ((29,0),(66,2)):
            line(im,[(x,43),(x,58)],'water_light')
            line(im,[(x+1,45),(x+1,55)],'water')
            for base_y in (59,73):
                yy=base_y+((i+phase)%4)*3
                rect(im,(x,yy,x+1,yy+3),'water_light')
                pix(im,x,yy,'water_high')
        frames.append(im)
    return frames

def generate_ambient():
    defs=[
      ('water.ripple_a',water_motion(0),[0,0,32,32],[36,36,48,60],{'max_tip_shift_px':1,'recommended_density':'At most one moving tile in four; keep bank collars static.','static_base':'map.terrain.water.mask_15'}),
      ('water.ripple_b',water_motion(1),[0,0,32,32],[48,36,36,60],{'max_tip_shift_px':1,'recommended_density':'Alternate with ripple_a only where desired. No whole-map shimmer.'}),
      ('banner.indigo',banner_motion(True),[4,96,24,32],[30,24,30,60],{'max_tip_shift_px':2,'static_base':'map.prop.banner.pole'}),
      ('banner.heather',banner_motion(False),[4,96,24,32],[30,24,30,60],{'max_tip_shift_px':2,'static_base':'map.prop.banner.pole'}),
      ('lantern.flame',flame_motion(),[4,96,24,32],[12,18,12,30],{'max_tip_shift_px':1,'static_base':'map.prop.lantern.housing','layer_order':'flame below housing','not_combat_magic':True}),
      ('foliage.planter',foliage_motion(),[0,64,64,32],[72,24,24,96],{'max_tip_shift_px':1,'static_base':'map.prop.planter.empty','recommended_density':'Only occasional planters; static planted alternative provided.'}),
      ('fountain.overflow',fountain_overflow(),[0,64,96,64],[24,24,24,24],{'max_tip_shift_px':0,'flow_step_px':3,'static_base':'map.prop.fountain.spout','not_combat_magic':True}),
      ('fountain.water',fountain_motion(),[0,64,96,64],[30,42,30,42],{'max_tip_shift_px':1,'static_base':'map.prop.fountain.basin','layer_order':'water, basin, optional spout','not_combat_magic':True})]
    for name,frames,foot,ticks,motion in defs:
        add(f'ambient.{name}',frames,'ambient',foot=foot,ticks=ticks,loop=True,motion=motion,notes='120 Hz timebase. Fixed frame canvas and fixed pivot, nearest-neighbor integer pixel motion; per-frame ticks, not a uniform environment frame rate.')


def mask_for(grid,x,y):
    fam=grid[y][x]; H=len(grid); W=len(grid[0]); mask=0
    for d,(dx,dy) in DIRS.items():
        xx,yy=x+dx,y+dy
        if 0<=xx<W and 0<=yy<H and grid[yy][xx]==fam: mask|=BITS[d]
    return mask

def resolved_tile(grid,x,y,variation=False):
    fam=grid[y][x]; H=len(grid); W=len(grid[0]); m=mask_for(grid,x,y)
    hashv=((x*374761393+y*668265263)^((x+13)*(y+29)*1274126177)) & 0xffffffff
    v=min(3,(hashv^(hashv>>13))%5) if variation and m==15 else 0
    im=terrain_tile(fam,m,v)
    for corner,(a,b,dx,dy) in CORNERS.items():
        match=0<=x+dx<W and 0<=y+dy<H and grid[y+dy][x+dx]==fam
        if m&BITS[a] and m&BITS[b] and not match: paste(im,corner_image(fam,corner,'concave'),(0,0))
        elif not m&BITS[a] and not m&BITS[b]: paste(im,corner_image(fam,corner,'convex'),(0,0))
    return im

def render_ground(grid):
    im=image(len(grid[0])*32,len(grid)*32)
    for y,row in enumerate(grid):
        for x,fam in enumerate(row): paste(im,resolved_tile(grid,x,y,True),(x*32,y*32))
    return im

@lru_cache(maxsize=24)
def previewfont(size=16,bold=False):
    for name in (('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'),'/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf'):
        if Path(name).exists(): return ImageFont.truetype(name,size)
    return ImageFont.load_default()

def text(im,xy,s,size=16,c='#d8d5cc',bold=False):
    ImageDraw.Draw(im).text(xy,s,font=previewfont(size,bold),fill=c)

def preview_canvas(w,h,title,subtitle=''):
    im=Image.new('RGB',(w,h),'#191f29')
    text(im,(30,22),'F L U X   /   W E L L S P R I N G',14,'#c8b898',True)
    text(im,(28,48),title,28,'#f0e6d0',True)
    if subtitle: text(im,(30,88),subtitle,13,'#9aa8b4')
    return im

def label_card(im,box,label,sub=''):
    d=ImageDraw.Draw(im); d.rectangle(box,fill='#252e38')
    text(im,(box[0]+9,box[3]-34),label,12,'#e1d8c6',True)
    if sub: text(im,(box[0]+9,box[3]-17),sub,10,'#9ca9b1')

def preview_save(im,name):
    im.convert('RGBA').save(ROOT/'previews'/name,optimize=True)

def build_catalogues():
    groups=[('terrain','Terrain / complete 4-neighbor families'),('architecture','Architecture / registered modular pieces'),('props','Props / empty sockets, no gameplay authority'),('ambient','Ambient / restrained, opt-in motion')]
    for group,title in groups:
        assets=[a for a in ASSETS if a['group']==group]
        if group=='terrain':
            im=preview_canvas(1232,610,title,'32 x 32 cells | N=1 E=2 S=4 W=8 | 16 masks + four concave and four convex overlays per family')
            for i,fam in enumerate(FAMILIES):
                y=139+i*86; text(im,(30,y+19),fam.title(),15,'#d2c5a7',True)
                for m in range(16):
                    tile=FRAMES[f'map.terrain.{fam}.mask_{m:02d}'][0].resize((56,56),Image.Resampling.NEAREST)
                    im.paste(tile,(174+m*64,y),tile); text(im,(189+m*64,y+60),f'{m:02d}',11)
            text(im,(30,580),'Exact exports shown. Shared palette remains unverified; these are standalone review candidates.',12,'#bba780')
        else:
            # Condense wall masks to representative modules in summary; HTML lists all.
            if group=='architecture':
                assets=[a for a in assets if not a['id'].startswith('map.worldbone.') or a.get('autotile',{} ) is None or a.get('autotile',{}).get('mask') in (0,3,5,10,15)]
            cw,ch=192,235; cols=6; rows=math.ceil(len(assets)/cols)
            im=preview_canvas(1208,128+rows*ch,title,'Native exported pixels; transparent padding may be cropped in catalogue views. The HTML review contains every asset and every frame.')
            for idx,a in enumerate(assets):
                x=24+(idx%cols)*196; y=124+(idx//cols)*ch
                label='.'.join(a['id'].split('.')[1:])
                box=(x,y,x+187,y+ch-8); label_card(im,box,label[-25:],f'{a["frame_size_px"][0]} x {a["frame_size_px"][1]} px | {len(a["frames"])} frame(s)')
                f=FRAMES[a['id']][0]; scale=1 if f.height>112 else 2
                if f.width*scale>178: scale=1
                f=f.resize((f.width*scale,f.height*scale),Image.Resampling.NEAREST)
                im.paste(f,(x+(187-f.width)//2,y+(ch-45-f.height)//2),f)
        preview_save(im,f'catalogue_{group}.png')
    # Selective overview, designed as a useful quick audit rather than a massive atlas.
    im=preview_canvas(1280,1050,'A reusable academy kit, not a flattened map','Actual exports; empty margins cropped for this catalogue. Magnification is marked per card. The courtyard shows native scale.')
    examples=[('FLOORS',['map.terrain.'+f+'.mask_15' for f in FAMILIES]),
      ('WORLDBONE',['map.worldbone.standard.mask_10','map.worldbone.standard.mask_03','map.worldbone.standard.mask_15','map.worldbone.low.mask_10','map.worldbone.pillar.tall']),
      ('ACADEMY',['map.academy.facade.window','map.academy.facade.door_frame','map.academy.roof.middle','map.academy.arch.supports','map.academy.arch.lintel']),
      ('CROSSINGS',['map.bridge.ew.deck','map.bridge.ns.deck','map.access.steps.rise_n','map.access.ramp.rise_e','map.channel.bank.corner_nw']),
      ('PROPS',['map.prop.training_dummy','map.prop.lectern','map.prop.bench','map.prop.planter.planted','map.prop.workbench.brass'])]
    for row,(label,ids) in enumerate(examples):
        y=130+row*168
        text(im,(28,y+8),label,13,'#c8b898',True)
        for j,id in enumerate(ids):
            x=174+j*214; ImageDraw.Draw(im).rectangle((x,y,x+204,y+155),fill='#252e38')
            f=FRAMES[id][0]; f=f.crop(f.getbbox()) if f.getbbox() else f
            sc=2 if f.height<=56 and f.width<=80 else 1
            f=f.resize((f.width*sc,f.height*sc),Image.Resampling.NEAREST)
            im.paste(f,(x+(204-f.width)//2,y+5+(131-f.height)//2),f)
            text(im,(x+174,y+7),f'{sc}x',10,'#9aabb5')
            text(im,(x+9,y+136),'.'.join(id.split('.')[-2:]),11,'#d7d4c5')
    text(im,(30,992),'32 px cells  /  58, 68, 76 px scale references  /  static floors + eight optional ambient clips',15,'#c9d5ce')
    text(im,(30,1019),'Integration gate: authoritative palette, checkout checkpoint, character references and engine import are not verified.',12,'#c8a789')
    preview_save(im,'asset_catalogue.png')


def seam_tests():
    checks=0; failures=[]; kinds=Counter()
    # Exhaust all binary 3x3 material neighborhoods. Same-family connected edges
    # must have exactly equal RGBA profiles, including endpoints/corner patches.
    for fam in FAMILIES:
        for code in range(512):
            grid=[[fam if code&(1<<(y*3+x)) else 'earth' if fam!='earth' else 'paving' for x in range(3)] for y in range(3)]
            tiles={(x,y):resolved_tile(grid,x,y) for y in range(3) for x in range(3)}
            for y in range(3):
                for x in range(3):
                    for dx,dy in ((1,0),(0,1)):
                        xx,yy=x+dx,y+dy
                        if xx>=3 or yy>=3 or grid[y][x]!=grid[yy][xx]: continue
                        a=tiles[(x,y)]; b=tiles[(xx,yy)]
                        p=[a.getpixel((31,k)) if dx else a.getpixel((k,31)) for k in range(32)]
                        q=[b.getpixel((0,k)) if dx else b.getpixel((k,0)) for k in range(32)]
                        checks+=1
                        if p!=q: failures.append({'family':fam,'pattern':code,'edge':[x,y,xx,yy]})
    # All unordered family pairs, each with an L/island/corner-rich 3x3 and 5x5.
    patterns3=['AAB','ABB','AAA']
    patterns5=['AABBA','ABABA','BBABB','ABAAA','AABBA']
    examples=[]
    for i,a in enumerate(FAMILIES):
        for b in FAMILIES[i+1:]:
            for n,pattern in [(3,patterns3),(5,patterns5)]:
                grid=[[a if c=='A' else b for c in row] for row in pattern]
                art=render_ground(grid); name=f'seam_{a}_{b}_{n}x{n}.png'
                art.save(ROOT/'previews'/name,optimize=True)
                examples.append({'a':a,'b':b,'size':n,'grid':grid,'path':'previews/'+name})
    jsave('source/seam_examples.json',examples)
    im=preview_canvas(1240,1430,'Mixed material seams / 3 x 3 and 5 x 5','Every unordered pair is shown. Different materials retain a deliberate boundary; matching material edges have no alpha gaps.')
    pairs=[(a,b) for i,a in enumerate(FAMILIES) for b in FAMILIES[i+1:]]
    for idx,(a,b) in enumerate(pairs):
        x=28+(idx%2)*612; y=128+(idx//2)*250
        text(im,(x,y),f'{a.upper()}  /  {b.upper()}',13,'#d8c79f',True)
        for n,px in [(3,x),(5,x+248)]:
            f=Image.open(ROOT/'previews'/f'seam_{a}_{b}_{n}x{n}.png').convert('RGBA')
            s=2 if n==3 else 1
            f=f.resize((f.width*s,f.height*s),Image.Resampling.NEAREST)
            im.paste(f,(px,y+26+(32 if n==5 else 0)),f)
            text(im,(px,y+225),f'{n} x {n} cells / {s}x preview',11,'#a6b4bd')
    text(im,(28,1390),f'Exhaustive binary-neighborhood test: {checks:,} full 32-pixel edge-profile comparisons; {len(failures)} mismatches.',14,'#c9d5ce')
    preview_save(im,'seam_tests.png')
    return {'binary_neighborhoods':512*len(FAMILIES),'full_edge_profile_comparisons':checks,'mismatches':len(failures),'first_failures':failures[:10],'mixed_examples':len(examples),'coverage':'5 terrain families; all 10 unordered pairs at 3x3 and 5x5; full RGBA edge profiles checked for equal-material adjacency.'}


def compose_sample():
    W,H=36,26
    grid=[['grass']*W for _ in range(H)]
    for y in range(3,24):
        for x in range(2,34): grid[y][x]='earth'
    for y in range(7,23):
        for x in range(3,28): grid[y][x]='paving'
    for y in range(10,17):
        for x in range(3,9): grid[y][x]='worldbone'
    for y in range(3,24): grid[y][29]='water'
    for y in range(4,23):
        for x in (30,31,32): grid[y][x]='grass'
    for y in (10,11,18,19):
        for x in range(28,34):
            if x!=29: grid[y][x]='paving'
    ground=render_ground(grid); arch=image(W*32,H*32); props=image(W*32,H*32); roofs=image(W*32,H*32); ambient=image(W*32,H*32)
    placements=[]
    def place(id,cx,cy,layer='architecture',frame=0):
        a=next(a for a in ASSETS if a['id']==id); f=FRAMES[id][frame]
        dest={'architecture':arch,'props':props,'roof':roofs,'ambient':ambient}[layer]
        # cx/cy denote the upper-left of the nominal ground footprint in cells.
        fx,fy,fw,fd=a['visual_ground_footprint']['rect_px']
        x=int(cx*32-fx); y=int(cy*32-fy)
        paste(dest,f,(x,y)); placements.append({'asset_id':id,'ground_origin_cells':[cx,cy],'layer':layer,'frame':frame})
    # Canal banks; two open bridge interruptions.
    for y in range(3,24):
        if y in (10,11,18,19): continue
        place('map.channel.bank.water_e',28,y)
        place('map.channel.bank.water_w',30,y)
    for y in (10,18):
        for part in ('deck','rear_rail','front_rail'): place(f'map.bridge.ew.{part}',28,y)
    # Ground-level perimeter trims, never a replacement collision boundary.
    for x in range(3,28):
        place('map.academy.courtyard.trim_n',x,7)
        place('map.academy.courtyard.trim_s',x,22)
    for y in range(8,22):
        place('map.academy.courtyard.trim_w',3,y)
    # Academy perimeter, repeated compatible modules but varied facade texture.
    for j,kind in enumerate(('buttress','window','window','door_frame','window','buttress')):
        x=5+2*j
        place('map.academy.facade.'+kind,x,6)
        if kind=='door_frame': pass # empty visual aperture, not an engine door
        r='end_w' if j==0 else 'end_e' if j==5 else 'middle'
        place('map.academy.roof.'+r,x,6,'roof')
    for part in ('supports','lintel'): place('map.academy.arch.'+part,22,6,'roof' if part=='lintel' else 'architecture')
    # Short wallrun practice lanes; negative space kept between lanes.
    for x in range(4,8):
        m=2 if x==4 else 8 if x==7 else 10
        place(f'map.worldbone.standard.mask_{m:02d}',x,12)
    for y in range(14,17):
        m=4 if y==14 else 1 if y==16 else 5
        place(f'map.worldbone.low.mask_{m:02d}',4,y)
    place('map.worldbone.pillar.tall',8,16)
    # Props sit along edges, not in every available floor tile.
    for x,y in [(4,8),(18,7),(25,7),(32,12),(32,20)]: place('map.prop.planter.planted',x,y,'props')
    for x,y in [(5,9),(24,8)]:
        place('map.prop.banner.pole',x,y,'props'); place('map.ambient.banner.indigo',x,y,'ambient')
    for x,y in [(9,8),(19,8),(27,17),(32,8)]:
        place('map.ambient.lantern.flame',x,y,'ambient'); place('map.prop.lantern.housing',x,y,'props')
    place('map.prop.training_dummy',5,15,'props')
    place('map.prop.lectern',18,8,'props')
    place('map.prop.signboard',25,21,'props')
    place('map.prop.bench',10,22,'props'); place('map.prop.bench',20,22,'props')
    place('map.prop.workbench.brass',4,21,'props')
    place('map.prop.workbench.worldbone',4,18,'props')
    place('map.ambient.fountain.water',11,14,'ambient')
    place('map.ambient.fountain.overflow',11,14,'ambient')
    place('map.prop.fountain.basin',11,14,'props'); place('map.prop.fountain.spout',11,14,'props')
    for y in (4,8,13,16,21): place('map.ambient.water.ripple_a',29,y,'ambient')
    scene=ground.copy()
    # Ordered components for demonstration. World-space engine sorting is unverified.
    for layer in (arch,ambient,props,roofs): paste(scene,layer,(0,0))
    preview_save(scene,'courtyard_clean.png')
    for name,layer in [('ground',ground),('architecture',arch),('props',props),('ambient',ambient),('roofs_foreground',roofs)]: preview_save(layer,'courtyard_layer_'+name+'.png')
    markers=image(scene.width,scene.height); d=ImageDraw.Draw(markers)
    for x,height in [(17*32,58),(20*32,68),(23*32,76)]:
        y=20*32
        # Neutral rulers, not characters, anatomy or imported sprites.
        d.rectangle((x,y-height,x+19,y-1),fill='#a5a9a8',outline='#353b43',width=2)
        d.rectangle((x+4,y-height+4,x+7,y-5),fill='#c4c6ba')
        d.line((x-5,y,x+25,y),fill='#d8d9ca',width=2)
        text(markers,(x-6,y+6),f'{height}px',11,'#eee9d4',True)
    paste(scene,markers,(0,0))
    preview_save(markers,'courtyard_scale_markers.png')
    review=preview_canvas(scene.width+48,scene.height+172,'Sample courtyard / visual layout demonstration','58 / 68 / 76 px neutral height rulers. No production layout, collision, navigation or visibility behavior is changed.')
    review.paste(scene,(24,120),scene)
    text(review,(28,review.height-37),'Open movement floor intentionally left quiet. Layer-separated scene and cell-placement JSON are included for review only.',13,'#c4cdbf')
    preview_save(review,'courtyard_review.png')
    gridview=scene.copy(); d=ImageDraw.Draw(gridview)
    for x in range(0,scene.width,32): d.line((x,0,x,scene.height),fill='#5b6260')
    for y in range(0,scene.height,32): d.line((0,y,scene.width,y),fill='#5b6260')
    preview_save(gridview,'courtyard_grid.png')
    jsave('source/sample_courtyard.json',{'purpose':'visual_layout_demonstration_not_production_map','cell_px':32,'dimensions_cells':[W,H],'terrain':grid,'placements':placements,'neutral_scale_marker_heights_px':[58,68,76],'collision_data':None,'navigation_data':None})
    return placements


def make_ora(name,ids):
    # OpenRaster carries actual editable raster layers at identical registration.
    sizes=[FRAMES[id][0].size for id in ids]; w=max(s[0] for s in sizes); h=max(s[1] for s in sizes)
    merged=image(w,h)
    for id in ids: paste(merged,FRAMES[id][0],(0,0))
    root=Element('image',{'w':str(w),'h':str(h),'name':name,'version':'0.0.3'}); stack=SubElement(root,'stack')
    buf=io.BytesIO()
    with zipfile.ZipFile(buf,'w') as z:
        z.writestr('mimetype','image/openraster',compress_type=zipfile.ZIP_STORED)
        for i,id in reversed(list(enumerate(ids))):
            path=f'data/layer{i:02d}.png'
            b=io.BytesIO(); FRAMES[id][0].save(b,format='PNG')
            z.writestr(path,b.getvalue())
            SubElement(stack,'layer',{'name':id,'src':path,'x':'0','y':'0','opacity':'1.0','visibility':'visible','composite-op':'svg:src-over'})
        z.writestr('stack.xml',tostring(root,encoding='UTF-8',xml_declaration=True))
        b=io.BytesIO(); merged.save(b,format='PNG'); z.writestr('mergedimage.png',b.getvalue())
        thumb=merged.copy(); thumb.thumbnail((256,256),Image.Resampling.NEAREST); b=io.BytesIO(); thumb.save(b,format='PNG'); z.writestr('Thumbnails/thumbnail.png',b.getvalue())
    relwrite('source/'+name+'.ora',buf.getvalue())


def build_animation_preview():
    ids=['map.ambient.water.ripple_a','map.ambient.banner.indigo','map.ambient.lantern.flame','map.ambient.foliage.planter','map.ambient.fountain.water']
    def frame_at(a,t):
        lengths=[f['duration_ticks'] for f in a['frames']]; t%=sum(lengths)
        for i,n in enumerate(lengths):
            if t<n:return i
            t-=n
        return 0
    gif=[]
    gif_palette=None
    period=math.lcm(*[sum(f['duration_ticks'] for f in a['frames']) for a in ASSETS if a['loop']])
    for tick in range(0,period,12):
        im=preview_canvas(1080,410,'Ambient / fixed registration, independent cadence','Preview sampled at 10 fps. The manifest retains the exact per-frame 120 Hz timing; no global shimmer pass.')
        for i,id in enumerate(ids):
            a=next(a for a in ASSETS if a['id']==id); fi=frame_at(a,tick); w,h=a['frame_size_px']; f=image(w,h)
            if 'water.ripple' in id: paste(f,FRAMES['map.terrain.water.mask_15'][0],(0,0)); paste(f,FRAMES[id][fi],(0,0))
            elif 'banner.' in id: paste(f,FRAMES['map.prop.banner.pole'][0],(0,0)); paste(f,FRAMES[id][fi],(0,0))
            elif 'lantern' in id: paste(f,FRAMES[id][fi],(0,0)); paste(f,FRAMES['map.prop.lantern.housing'][0],(0,0))
            elif 'foliage' in id: paste(f,FRAMES['map.prop.planter.empty'][0],(0,0)); paste(f,FRAMES[id][fi],(0,0))
            else: paste(f,FRAMES[id][fi],(0,0)); paste(f,FRAMES['map.prop.fountain.basin'][0],(0,0)); paste(f,FRAMES['map.prop.fountain.spout'][0],(0,0))
            if 'fountain' in id:
                aa=next(a for a in ASSETS if a['id']=='map.ambient.fountain.overflow')
                paste(f,FRAMES[aa['id']][frame_at(aa,tick)],(0,0))
            s=2 if w<96 and h<100 else 1; f=f.resize((w*s,h*s),Image.Resampling.NEAREST)
            x=25+i*210; ImageDraw.Draw(im).rectangle((x,130,x+195,343),fill='#252e38')
            im.paste(f,(x+(195-f.width)//2,142+(170-f.height)//2),f)
            text(im,(x+10,350),'.'.join(id.split('.')[-2:]),12,'#e6d5b0',True)
            text(im,(x+10,372),'/'.join(str(f['duration_ticks']) for f in a['frames'])+' ticks',10)
        if gif_palette is None:
            gif_palette=im.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
            gif.append(gif_palette.copy())
        else:
            gif.append(im.quantize(palette=gif_palette,dither=Image.Dither.NONE))
    gif[0].save(ROOT/'previews/ambient_loops.gif',save_all=True,append_images=gif[1:],duration=100,loop=0,optimize=False,disposal=1)
    # Exact, unscaled four-frame contact strips remain the authoritative PNGs.


def make_atlases():
    info=[]
    for group in ('terrain','architecture','props','ambient'):
        assets=[a for a in ASSETS if a['group']==group]
        width=1024; pad=2; x=y=pad; rowh=0; slots=[]
        for a in assets:
            for i,f in enumerate(FRAMES[a['id']]):
                if x+f.width+pad>width: x=pad; y+=rowh+2*pad; rowh=0
                slots.append((a,i,x,y)); x+=f.width+2*pad; rowh=max(rowh,f.height)
        height=y+rowh+pad; atlas=image(width,height)
        for a,i,x,y in slots:
            f=FRAMES[a['id']][i]; paste(atlas,f,(x,y))
            # Two-pixel nearest edge extrusion protects even simple atlas renderers.
            for q in range(1,pad+1):
                atlas.paste(f.crop((0,0,1,f.height)),(x-q,y)); atlas.paste(f.crop((f.width-1,0,f.width,f.height)),(x+f.width-1+q,y))
                atlas.paste(f.crop((0,0,f.width,1)),(x,y-q)); atlas.paste(f.crop((0,f.height-1,f.width,f.height)),(x,y+f.height-1+q))
            for dx,dy,sx,sy in [(-pad,-pad,0,0),(f.width,-pad,f.width-1,0),(-pad,f.height,0,f.height-1),(f.width,f.height,f.width-1,f.height-1)]:
                rect(atlas,(x+dx,y+dy,x+dx+pad-1,y+dy+pad-1),f.getpixel((sx,sy)))
            a.setdefault('atlas_frames',[]).append({'path':f'export/{group}/atlas.png','rect':[x,y,f.width,f.height],'duration_ticks':a['frames'][i]['duration_ticks']})
        atlas.save(ROOT/f'export/{group}/atlas.png',optimize=True)
        info.append({'group':group,'path':f'export/{group}/atlas.png','size_px':list(atlas.size),'padding_px':2,'extrusion_px':2,'sampling':'nearest','frame_regions':len(slots),'rgba_sha256':hashlib.sha256(atlas.tobytes()).hexdigest()})
    return info


def validate(seams,atlases):
    errors=[]; checks=Counter(); opaque=0; pixels=set(); clips=[]
    for a in ASSETS:
        p=(ROOT/a['path']).resolve(); checks['asset_paths']+=1
        if not p.is_relative_to(ROOT) or not p.is_file(): errors.append('Invalid path '+a['id'])
        im=Image.open(p)
        checks['rgba_images']+=1
        if im.mode!='RGBA': errors.append('Not RGBA '+a['id'])
        colors=im.getcolors(im.width*im.height) or []
        for _,rgba in colors:
            if rgba[3] not in (0,255): errors.append('Fractional alpha '+a['id'])
            if rgba[3]:pixels.add(rgba)
        if a['layer_role']=='terrain_base':
            opaque+=1
            if im.getchannel('A').getextrema()!=(255,255): errors.append('Nonopaque terrain '+a['id'])
        fw,fh=a['frame_size_px']; px,py=a['pivot_px']; fx,fy,bw,bh=a['visual_ground_footprint']['rect_px']
        if not (0<=px<=fw and 0<=py<=fh): errors.append('Out of bounds pivot '+a['id'])
        if not (0<=fx and 0<=fy and fx+bw<=fw and fy+bh<=fh): errors.append('Out of bounds footprint '+a['id'])
        if fw%32 or fh%32: errors.append('Non-cell-multiple canvas '+a['id'])
        for i,f in enumerate(a['frames']):
            x,y,w,h=f['rect']; checks['frame_rectangles']+=1
            if min(x,y,w,h)<0 or x+w>im.width or y+h>im.height: errors.append('Bad frame rect '+a['id'])
            if not isinstance(f['duration_ticks'],int) or f['duration_ticks']<1: errors.append('Bad frame duration '+a['id'])
            af=a['atlas_frames'][i]; ar=af['rect']; atlas=Image.open(ROOT/af['path']).convert('RGBA')
            if atlas.crop((ar[0],ar[1],ar[0]+ar[2],ar[1]+ar[3])).tobytes()!=FRAMES[a['id']][i].tobytes():errors.append('Atlas mismatch '+a['id'])
            checks['atlas_region_pixel_identity']+=1
        if a['loop']:
            frames=FRAMES[a['id']]; changes=[]; alphas=[]
            for i,f in enumerate(frames):
                b=frames[(i+1)%len(frames)]
                fb,bb=f.tobytes(),b.tobytes()
                changed=sum(fb[k:k+4]!=bb[k:k+4] for k in range(0,len(fb),4)); changes.append(changed)
                alphas.append(f.getbbox())
            clips.append({'id':a['id'],'fixed_canvas':True,'fixed_pivot':True,'cycle_ticks':sum(f['duration_ticks'] for f in a['frames']),'changed_pixels_between_frames_including_wrap':changes,'alpha_bounds_by_frame':alphas})
            if max(changes)==0:errors.append('Accidentally static clip '+a['id'])
            # Don't claim a one-pixel movement just from color changes; movement is sourced in code.
    allowed=set(P.values())
    if not pixels<=allowed: errors.append('Export uses undefined palette colors')
    if seams['mismatches']: errors.append('Terrain seams failed')
    for fam in FAMILIES:
        masks=[a['autotile']['mask'] for a in ASSETS if a.get('autotile') and a['autotile'].get('family')==fam and 'mask' in a['autotile']]
        if sorted(masks)!=list(range(16)):errors.append('Incomplete masks '+fam)
        corners=[(a['autotile'].get('kind'),a['autotile'].get('corner')) for a in ASSETS if a.get('autotile') and a['autotile'].get('family')==fam and a['autotile'].get('scheme')=='explicit_corner_overlay']
        if len(set(corners))!=8:errors.append('Incomplete corners '+fam)
    # Verify atlas regions have no overlaps (padding is separate from frame rectangles).
    for at in atlases:
        occupied=Image.new('1',tuple(at['size_px']),0); od=ImageDraw.Draw(occupied)
        for a in ASSETS:
            for f in a['atlas_frames']:
                if f['path']!=at['path']:continue
                x,y,w,h=f['rect']
                if occupied.crop((x,y,x+w,y+h)).getbbox(): errors.append('Overlapping atlas regions')
                od.rectangle((x,y,x+w-1,y+h-1),fill=1); checks['nonoverlapping_atlas_regions']+=1
    return {'result':'PASS' if not errors else 'FAIL','asset_count':len(ASSETS),'frame_count':sum(len(a['frames']) for a in ASSETS),'export_palette_color_count':len(pixels),'opaque_terrain_assets':opaque,'checks':dict(checks),'terrain_seams':seams,'ambient':clips,'errors':errors,'not_verified':['authoritative Windows checkout','commit 286bd8f','shared visual_language_v1.json palette identity','character reference sprite scale alignment beyond provided heights','in-engine import and rendering','runtime performance','production collision/navigation/occlusion policies','external pixel editor opening of OpenRaster files']}


def write_manifest(atlases,qa):
    manifest={
      'schema_version':1,'contract_id':'flux-pixel-assets-v1','namespace':'map',
      'title':'Wellspring / Courtyard Practice Kit','version':'1.0.0-standalone-review',
      'status':'standalone_complete_with_explicit_integration_gates','tick_rate_hz':120,
      'ground_cell_px':[32,32],'art_elevation_degrees_approx':55,'projection':'orthogonal cardinal ground axes; height projects upward, not diamond isometric',
      'character_scale_reference_heights_px':[58,68,76],
      'palette':{'path':'source/palette.json','status':'provisional_not_matched_to_authoritative_visual_language_v1.json','sha256':hashlib.sha256((ROOT/'source/palette.json').read_bytes()).hexdigest(),'colors':len(P),'reason':'Authoritative checkout and named shared palette were unavailable. No other worker palette or scale was changed.'},
      'repository_verification':{'authoritative_checkout_accessible':False,'requested_checkpoint':'286bd8f','checkpoint_verified':False,'remote_main_observed':'6d9b81875ca53c759e8001c450f262e2980e396a6c8d','remote_is_authoritative':False,'production_files_changed':False},
      'usage_authority':{'presentation_only':True,'runtime_approved':False,'collision_authority':False,'navigation_authority':False,'sample_is_production_layout':False},
      'import_defaults':{'filter':'nearest','mipmaps':False,'lossless_rgba':True,'pixel_snap':'integer texel positions in the art presentation layer only','allow_hardware_texture_rotation':False,'atlas_padding_px':2,'atlas_extrusion_px':2},
      'autotile_scheme':{'neighbor_bits':BITS,'match_rule':'same terrain family','mask_range':[0,15],'base_tiles':'opaque','required_corner_overlays':'If both adjacent cardinals match but diagonal differs, add matching concave corner overlay.','optional_corner_overlays':'If neither adjacent cardinal matches, add the matching convex wear overlay.','all_256_neighbor_signatures_representable':True,'terrain_families':FAMILIES,'blend_note':'Intentional two-pixel material-colored rims at material changes. No noisy alpha feathering.'},
      'atlases':atlases,'assets':ASSETS,
      'source':{'generator':'source/build_kit.py','license':'source/LICENSE.txt','provenance':'source/provenance.json','editable_raster_documents':['source/academy_bay.ora','source/bridge_ew.ora','source/fountain.ora','source/banner.ora']},
      'previews':{'catalogue':'previews/asset_catalogue.png','seams':'previews/seam_tests.png','courtyard':'previews/courtyard_review.png','interactive':'previews/review.html','ambient':'previews/ambient_loops.gif'},
      'qa':{'report':'QA.md','machine_report':'source/qa_results.json','result':qa['result'],'asset_count':qa['asset_count'],'frame_count':qa['frame_count']}
    }
    jsave('manifest.json',manifest)
    return manifest


def write_docs(manifest,qa):
    n=qa['asset_count']; nf=qa['frame_count']; sc=qa['terrain_seams']['full_edge_profile_comparisons']
    integration='''# Wellspring map kit — integration notes

## Boundary and status
This is a standalone presentation-only asset batch. Everything belongs below
`art_batches/pixel_v1/map/`. It does not contain a production scene, a project-setting
change, an import plugin, a collision shape, navigation data, a gameplay script or
a shared manifest change. The courtyard is only a visual arrangement demonstration.

The authoritative Windows checkout `C:\\Users\\sende\\Projects\\flux` was not mounted.
The GitHub connector could read a remote main tree, but the requested checkpoint
`286bd8f` could not be verified (commit request returned an error). Remote main was
observed at `6d9b81875ca53c759e8001c450f262e2980e396a6c8d`; that remote tree is not
accepted as the local checkout. It did not expose the named shared palette.

**Palette approval is blocked.** `source/palette.json` is a source-local provisional
material palette, not an assertion that `visual_language_v1.json` has been matched.
No other worker's scale, palette or production assets were modified. Do not promote
these candidates until the real palette is supplied and mapped/reviewed.

## Use the standalone files
Unpack the archive into a staging folder. Its paths begin with
`art_batches/pixel_v1/map/`. Open `previews/review.html` directly in a browser; it is
self-contained and makes no network requests. It can filter all assets, play exact
frame timings, change integer zoom, inspect pivots/footprints and save individual
PNGs. Generated previews and UI labels are not importable game art.

Each `export/{terrain,architecture,props,ambient}` folder has individual PNG strips
and an optional separate category atlas. Select ONE representation in the game,
not both. `frames[].rect` addresses the individual asset PNG; `atlas_frames[].rect`
addresses the atlas. The corresponding rects have identical decoded RGBA pixels.
Rectangles are `[x,y,w,h]`, zero-based, half-open extents. Atlas padding is excluded.
PNG strips have no inter-frame padding; atlases have 2px padding/edge extrusion.

Import losslessly as RGBA, nearest sampling, no mipmaps, no smooth scaling. These
are import recommendations, not installed engine settings. Preview at integer
scales first. The archive has no engine-specific resource files. An integrator
must resolve Sprite2D/TileMap versus Sprite3D/3D texture placement from the real
checkout instead of inferring it here. If the art is textured onto a 3D surface,
check the camera and avoid applying a second perspective skew to the authored
55-degree-style imagery. World units per pixel remain unverified.

## Coordinates, layers, visibility
All ground cells are 32x32 pixels with cardinal horizontal/vertical axes. Sprites
have cell-multiple canvases. `pivot_px` is relative to a frame, not its sheet. It is
the center of the descriptive ground footprint. For placement with the top-left
of a ground footprint at `(gx,gy)`, use `(gx-fx,gy-fy)` as the sprite image origin,
where `[fx,fy,fw,fd]` is `visual_ground_footprint.rect_px`.

Footprints describe the art. **They are not collider, navigation, wallrun, jump,
step, ramp, bridge or door authority.** Cells may include transparent margins.
Follow the existing game's visibility and sorting policy, once inspected.

Facade and roof pieces share a 64x160 canvas and the same ground anchor. Combine
facade, optional closed panel and roof. A door's alpha aperture is not permission
to create a gameplay passage. Roof middle pieces connect between west/east end
pieces. Arch supports and lintel share a 96x160 canvas; retain the opening and keep
the lintel separable. Bridge decks and rails have identical registration within
each cardinal orientation. Render bridge deck first, rear/detail rails as the
existing policy requires, and keep front rails independently selectable.

Normal worldbone walls (48px visual rise), low versions (20px) and ledges (8px)
have complete 16-mask plan coverage. They use closed ends and 24px-wide connecting
arms inside the 32px cell. Sort the ground anchor consistently. Low variants are
alternatives for a reviewed visibility policy, not automatic fading or collision
substitutions. Roof, lintel and foreground rails may be grouped for a future
visibility policy; this batch does not implement one.

## Terrain — complete coverage rules
For each cell compute `mask = N*1 + E*2 + S*4 + W*8`, where each bit is 1 when that
neighbor belongs to the SAME family. Use the corresponding opaque `mask_00` to
`mask_15` tile. Outside the test grid counts as different terrain.

After placing the base, for each corner NW/NE/SE/SW:
* Add `corner_concave_*` when both adjacent cardinal neighbors match and the
  diagonal does not. The 2x2 patch closes the otherwise ambiguous inner junction.
* Optionally add `corner_convex_*` when neither adjacent cardinal matches. This
  adds inward corner wear; it does not cut alpha holes or round away walkable art.
* Add nothing in the other cases. Diagonals are immaterial unless both adjacent
  cardinals match. This represents every one of the 256 eight-neighbor signatures.

`fill_v1` to `fill_v3` substitute the base of mask 15 only. Their 2px outer collar is
identical; add needed concave corner overlays afterward. The basic mask 15 is v0.
No frame is randomly rotated or mirrored: lighting is upper-left in every export.

This is a crisp, inset material-rim transition system, not an organic 47-tile blob
with transparent bite-outs. All material pairs are supported with the same rule.
The ten unordered pairs have both 3x3 and 5x5 mixed examples. These are in
`source/seam_examples.json` and `previews/seam_*.png`; exhaustive binary local
neighborhood tests are recorded in QA. Different-family seams intentionally show
each material's border. The test asserts continuity at same-material joins.

## Ambient clips — exact 120 Hz durations
Use cumulative frame durations, not an assumed animation FPS. At tick `t`, reduce
`t` modulo the sum of durations, then select the first cumulative boundary greater
than that value. The source viewer uses this rule without changing a simulation
clock. Static assets have one frame with duration 1 and `loop=false`.

Water: add sparse ripple overlays on top of static water; recommended density at
most one animated tile in four. Do not animate all terrain. Banner: pole is static,
cloth moves by up to 2px. Lantern: flame is an ordinary physical flame below the
static housing. Planter: use either static planted version, or empty planter plus
foliage overlay; never both foliage sources. Fountain: water, basin, optional spout and ordinary overflow. Keep overflow locally bounded.
All variants retain fixed canvases, pivots and descriptive footprints. Water stays
inside the basin or tile. No magical clouds, combat effects or hazards are supplied.

## Editing and regeneration
`source/build_kit.py` is deterministic, integer-pixel raster source for every asset,
atlas, preview and manifest. `source/palette.json` holds named material ramps.
Layered `source/*.ora` documents preserve actual PNG layers for an OpenRaster-capable
editor. The individual PNGs are also directly editable. OpenRaster package structure
was checked, but opening in external editors was not tested in this environment.

Python 3.10+ and Pillow are required. No other dependency is needed:

```powershell
# Run inside this batch folder, not a production asset folder.
py -3 -m pip install Pillow
py -3 source/build_kit.py
py -3 source/validate_kit.py
```

On Linux, replace `py -3` with `python3`. To apply approved shared colors, copy only
the desired color values into a separate semantic mapping JSON below `source/`;
retain the names in `source/palette.json`. Do not point the generator blindly at an
unknown production JSON schema. Run `--palette source/approved_palette_map.json`.
The generator deliberately keeps approval marked unverified until an actual human
integration review updates the batch-local approval record. Rebuilding overwrites
this batch's generated files, including PNG edits, but never files above the batch.
Back up edits in this same batch before rebuilding. There are no network requests.

## Promotion gates and known missing coverage
1. Read the authoritative commit and shared palette; reconcile the palette exactly.
2. Compare against real 58/68/76px character sprites at the actual camera/zoom.
3. Test existing movement, visibility and sorting with a separate approved task.
4. Review environment/character contrast, roof occlusion and atlas sampling in-engine.

Not supplied: full academy interiors or four-direction building facades; roof valleys,
roof cross/T junctions and multi-story stacks; inside/re-entrant water-bank corner
pieces; a water lock or waterfall kit; arbitrary bridge spans beyond supplied 3x2
and 2x3 cell modules; functional door animations; per-element named workbench internals;
production terrain painting; integration scripts; collision/navigation/gameplay data.
The source-local palette, camera mapping and actor comparison are unverified.
'''
    integration += '\n### Browser-test scope\nThe delivered self-contained review was functionally exercised in Chromium via\nan in-memory document load (`set_content`). This container blocks file-URL\nnavigation; direct double-click opening on the target computer was not tested.\nThe file has no fetch calls, external images, external fonts or CDN dependencies.\nThe optional `source/browser_smoke_test.py` requires Playwright and an existing\nChromium binary; it installs nothing and cleans its batch-local temporary profile.\n`source/manifest.schema.json` provides an optional formal schema; the included\nread-only validator does not require a JSON Schema package.\n'
    relwrite('integration.md',integration)
    counts=Counter(a['group'] for a in ASSETS)
    qa_md=f'''# QA — Wellspring standalone map kit

## Result
**{qa['result']} for the executed standalone raster/metadata checks.**
**NOT production-approved; shared palette and authoritative checkout remain unverified.**

{n} independently addressed asset IDs; {nf} frame rectangles; {len(manifest['atlases'])} category atlases.
Terrain {counts['terrain']}; architecture {counts['architecture']}; props {counts['props']}; ambient clips {counts['ambient']}.
{qa['opaque_terrain_assets']} opaque terrain bases/interior variations. All export images use PNG RGBA.
{qa['export_palette_color_count']} opaque palette colors were actually used. Alpha is exclusively 0 or 255.

## Executed checks
- Every asset path stays inside the batch and exists. All namespaced IDs are unique.
- Every frame rectangle, pivot and descriptive footprint is within its frame/canvas.
- Every canvas is a 32px cell multiple. Durations are positive integers at 120Hz.
- All export colors belong to the source-local provisional palette. This is NOT a comparison to the unavailable shared palette.
- Individual-strip frame pixels equal the corresponding atlas regions exactly.
- All atlas frame rectangles are non-overlapping; category atlases use 2px edge extrusion.
- Five terrain families each have all masks 0–15, three extra interior variations and eight explicit corner overlays.
- {qa['terrain_seams']['binary_neighborhoods']:,} binary 3x3 neighborhoods were resolved across five family tests.
- {sc:,} complete 32-pixel RGBA seam-profile comparisons at equal-material joins; {qa['terrain_seams']['mismatches']} mismatches.
- All ten unordered material pairs have actual mixed 3x3 and 5x5 PNG examples ({qa['terrain_seams']['mixed_examples']} examples).
- Ambient frames share stable registration. The preview GIF uses a common cycle period to avoid a mismatched global wrap. Frame-to-frame and wrap changed-pixel counts are in `source/qa_results.json`.
- OpenRaster files have an uncompressed mimetype, stack XML, independent PNG layers and merged previews.

## Visual review scope
The contact sheets and sample courtyard are rendered from the delivered PNGs, not
concept paintings. The generated browser viewer also displays the same PNG bytes.
Review focuses on hard pixel edges, readable ground bases, upper-left light, low
floor contrast, separated occluders and restrained motion. Automated seam equality
is a technical continuity test, not proof of artistic beauty or in-game readability.
A pixel-grid courtyard and component-only/layer-separated views are supplied.

## Ambient cycles
'''
    for c in qa['ambient']:
        qa_md+=f"- `{c['id']}`: {c['cycle_ticks']} ticks / {c['cycle_ticks']/120:.2f}s; changed pixels including wrap {c['changed_pixels_between_frames_including_wrap']}.\n"
    qa_md+='''
The GIF preview is sampled at 10fps and is not the authoritative timing artifact.
Manifest and browser timing use the actual 120Hz tick durations. No performance or
simulation determinism claim is made from the browser review.

## Explicitly unverified / not supplied
Authoritative `C:\\Users\\sende\\Projects\\flux`; reference commit `286bd8f`;
shared `visual_language_v1.json`; real character sprite references; world-unit scale;
actual Godot/runtime importer; camera pipeline; in-engine visibility and sorting;
frame rate, texture memory on target devices; gameplay, collision, navigation and
wallrun/walljump behavior. No repository content was modified or pushed.

Missing modular coverage is listed in integration.md: interiors and full directional
facades, complex roof junctions, inside water-bank corners, variable bridge spans,
functional door sequences, named per-element workbench internals and special water
structures. The completed terrain-mask coverage must not be mistaken for complete
coverage of every architectural arrangement.

## Reproduce
Run `python source/build_kit.py`, then `python source/validate_kit.py` from this
batch. The generator exits nonzero for failed raster tests. Machine-readable evidence:
`source/qa_results.json`. Neither script writes outside this batch folder.
'''
    qa_md += "\n## Independent export and browser checks\nThe separately executed read-only checker `source/validate_kit.py` passed on the\ndelivered PNGs: all 1,280 eight-neighbor signatures across five terrain families,\n47 effective binary topologies per family (235 total), all 15,360 full edge-profile\ncomparisons, all 274 frame/atlas identities and edge extrusions, four OpenRaster\npackages, and the 36-second common-period GIF. The manifest also passed the included\n`source/manifest.schema.json` schema. Evidence: `source/independent_qa.json`.\n\nBrowser functional QA passed 19 checks, including every embedded PNG, searching,\ncategory filtering, native-resolution/integer zoom, pivot overlays, exact PNG\ndownload bytes, manifest saving, preview tabs, tick selection/wrap, no JavaScript\nerrors, no external page requests, and a 390px-wide mobile viewport.\nEvidence: `source/browser_qa.json` and the desktop/mobile browser screenshots.\n\nThis container blocks direct file-URL navigation by administrator policy. Browser\nQA therefore loaded the exact self-contained HTML via Playwright `set_content`,\nnot by relaxing browser policy. Direct double-click/file-URL behavior on the user's\nmachine is an unverified integration assumption. No engine or game was launched.\nReports carry hashes of the tested manifest/HTML. After editing or rebuilding,\nrerun the independent and optional browser checks rather than reuse their results.\n"
    relwrite('QA.md',qa_md)
    license_text='''FLUX Wellspring standalone map kit — licensing and provenance

Original artwork, integer-grid raster generator, metadata, documentation and previews
were created for this request. No third-party sprite, room, texture, character, logo,
font file or reference-game artwork is included. Broad genre principles only.

To the extent copyright or related rights attach to this generated work and can be
waived by its contributor, the contributor dedicates these newly created files to
the public domain under CC0 1.0 Universal. Commercial use, modification and redistribution
are permitted without an attribution requirement. This statement is not a legal
opinion, warranty of copyrightability, exclusivity or third-party-rights clearance.
Existing FLUX names, code and third-party rights are not licensed or altered here.

The standalone browser preview uses system fonts. PNG preview labels may rasterize
an installed font, but no font software is distributed. Pillow is a build dependency,
not bundled code. Asset export PNGs contain no UI text or preview labels.

No generative-image output is included: the image-generation call did not produce
an image. The actual deliverables are original scripted pixel-raster assets with
editable geometry and material ramps. Their source is source/build_kit.py.

Provided AS IS, without warranties or liability to the maximum extent permitted.
'''
    relwrite('source/LICENSE.txt',license_text)
    jsave('source/provenance.json',{'origin':'original_integer_grid_raster_art_created_for_this_request','third_party_asset_inputs':[],'copied_reference_sprites':False,'image_generation_output_used':False,'generator':'source/build_kit.py','editable_sources':'Python integer pixel drawing, semantic palette, OpenRaster layer files, PNGs','license':'CC0-1.0 to extent waivable; see LICENSE.txt','palette_status':'provisional; named shared palette unavailable','reference_character_art_used':False,'source_of_scale':'user-provided 32px cell and 58/68/76px heights','network_needed_to_rebuild':False})
    jsave('source/design_config.json',{'contract_id':'flux-pixel-assets-v1','grid_px':32,'tick_rate_hz':120,'height_references_px':[58,68,76],'lighting':'upper-left','axes':'cardinal','art_elevation_degrees_approx':55,'palette_gate':'unverified','terrain_families':FAMILIES,'footprints_authoritative':False,'sample_authority':'visual_demo_only'})


def build_viewer(manifest):
    # Self-contained review: no fetch(), CORS requirement, CDN, engine or service.
    data={'manifest':manifest,'assets':[],'previews':{}}
    for a in ASSETS:
        data['assets'].append({'meta':a,'png':base64.b64encode((ROOT/a['path']).read_bytes()).decode()})
    for name in ('asset_catalogue.png','seam_tests.png','courtyard_review.png','courtyard_clean.png','courtyard_grid.png','ambient_loops.gif'):
        p=ROOT/'previews'/name; data['previews'][name]='data:'+('image/gif' if name.endswith('gif') else 'image/png')+';base64,'+base64.b64encode(p.read_bytes()).decode()
    # Documentation is available offline alongside the manifest; no hidden game code.
    data['docs']={n:(ROOT/n).read_text() for n in ('integration.md','QA.md','source/LICENSE.txt')}
    html=r'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FLUX / Wellspring modular kit</title>
<style>
:root{color-scheme:dark;--bg:#171e27;--panel:#232d38;--line:#394553;--ink:#e1dfd5;--muted:#9aaab5;--accent:#ccb786}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 system-ui,sans-serif}header,main{max-width:1440px;margin:auto;padding:28px}header{padding-bottom:12px}small,.muted{color:var(--muted)}h1{font-size:clamp(27px,4vw,46px);line-height:1.15;margin:10px 0 12px}h2{font-size:22px;margin:20px 0 12px}.eyebrow{letter-spacing:.22em;color:var(--accent);font-size:12px;font-weight:700}.notice{padding:13px 17px;border-left:3px solid var(--accent);background:#342f2a;color:#e1cdaa;border-radius:3px;margin:18px 0}.controls{display:flex;flex-wrap:wrap;gap:10px;align-items:center;position:sticky;top:0;background:#171e27f5;padding:14px 0;z-index:3}button,input,select{font:inherit;padding:8px 12px;background:var(--panel);color:var(--ink);border:1px solid var(--line);border-radius:5px}button{cursor:pointer}button:hover{border-color:var(--accent)}button.active{border-color:var(--accent);color:var(--accent)}input[type=search]{min-width:220px;flex:1}a{color:var(--accent)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(205px,1fr));gap:14px}.card{min-width:0;background:var(--panel);border:1px solid var(--line);padding:12px;border-radius:7px}.stage{height:230px;display:flex;align-items:center;justify-content:center;overflow:auto;background-color:#202731;background-image:linear-gradient(45deg,#28323c 25%,transparent 25%),linear-gradient(-45deg,#28323c 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#28323c 75%),linear-gradient(-45deg,transparent 75%,#28323c 75%);background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0}canvas{image-rendering:pixelated;image-rendering:crisp-edges;flex:none}code{font-size:11px;overflow-wrap:anywhere;color:#deccb0}.name{margin:9px 0 4px;font-size:12px;font-weight:700;overflow-wrap:anywhere}.meta{font-size:11px;color:var(--muted)}.actions{display:flex;gap:6px;margin-top:9px}.actions button{font-size:11px;padding:5px 8px}.preview{display:block;width:100%;height:auto;image-rendering:pixelated;border:1px solid var(--line)}.hidden{display:none!important}.stats{display:flex;flex-wrap:wrap;gap:24px;margin:18px 0}.stats b{font-size:23px;color:var(--accent);display:block}.stats span{font-size:12px;color:var(--muted)}dialog{background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:8px;max-width:900px;width:90%;max-height:85vh}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.55 ui-monospace,monospace}footer{padding:28px 0;color:var(--muted);font-size:12px}.section-tabs{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0}.scale{font-size:12px}.caption{font-size:12px;color:var(--muted);margin:8px 0 16px}.details{display:grid;grid-template-columns:repeat(2,1fr);gap:20px}@media(max-width:700px){header,main{padding:18px}.details{display:block}.stage{height:190px}}
</style><header><div class="eyebrow">FLUX / PIXEL ASSETS V1 / MAP</div><h1>The Wellspring<br>Modular courtyard practice kit</h1><p class="muted">Original editable raster modules. Terrain, architecture, props and ambient clips are independent. This viewer is not a game build.</p><div class="notice"><strong>Standalone review candidate — not production approved.</strong> Shared <code>visual_language_v1.json</code>, authoritative checkout and checkpoint 286bd8f were unavailable. The palette is provisional. Nothing here creates collision, navigation, gameplay or automatic fading.</div><div class="stats" id="stats"></div><div class="section-tabs"><button data-tab="assets" class="active">All modules</button><button data-tab="catalogue">Catalogue</button><button data-tab="seams">Seam tests</button><button data-tab="courtyard">Courtyard</button><button data-tab="motion">Ambient loops</button><button id="manifest">Save manifest</button><button id="notes">Integration notes</button><button id="qa">QA report</button></div></header>
<main><section id="assets"><div class="controls"><input id="search" type="search" placeholder="Search names, e.g. roof, mask_03, workbench"><select id="group"><option value="">All batches</option><option>terrain</option><option>architecture</option><option>props</option><option>ambient</option></select><select id="zoom"><option value="1">1x native</option><option value="2" selected>2x</option><option value="3">3x</option></select><button id="play">Pause motion</button><label class="scale"><input id="anchors" type="checkbox"> Show pivot / footprint</label></div><p id="count" class="caption"></p><div class="grid" id="cards"></div></section><section id="catalogue" class="hidden"><img class="preview" id="img-catalogue"><p class="caption">Every pictured part comes from its actual export. The full module grid includes all masks and overlays.</p></section><section id="seams" class="hidden"><img class="preview" id="img-seams"><p class="caption">Equal-material edge profiles are tested at full resolution, including corners. Between different materials, dark rims are intentional.</p></section><section id="courtyard" class="hidden"><button id="grid-toggle">Toggle 32px grid</button><img class="preview" id="img-courtyard"><p class="caption">Only a visual layout example. The neutral 58/68/76px bars are scale rulers, not characters. Layer PNGs and the demonstration-only placement JSON are in the folder.</p></section><section id="motion" class="hidden"><img class="preview" id="img-motion"><p class="caption">GIF is sampled at 10fps. Individual module playback uses exact manifest ticks. Animation is local and optional, never a uniform moving texture pass.</p></section><footer>Original source / CC0 to the extent waivable. No external images, requests, fonts or libraries are loaded by this file. Export PNGs contain no labels. Footprints are descriptive only.</footer></main><dialog id="dialog"><button id="close">Close</button><pre id="detail"></pre></dialog>
<script>
const DATA=__DATA__;
const $=x=>document.getElementById(x), M=DATA.manifest;
$('stats').innerHTML=`<div><b>${M.assets.length}</b><span>addressable assets</span></div><div><b>${M.qa.frame_count}</b><span>frame rectangles</span></div><div><b>32 x 32</b><span>ground cells</span></div><div><b>5 x 16</b><span>terrain masks + corner overlays</span></div><div><b>8</b><span>optional ambient clips</span></div>`;
$('img-catalogue').src=DATA.previews['asset_catalogue.png'];$('img-seams').src=DATA.previews['seam_tests.png'];$('img-courtyard').src=DATA.previews['courtyard_review.png'];$('img-motion').src=DATA.previews['ambient_loops.gif'];
let running=true, tick=0, last=performance.now(), zoom=2, show=false, cards=[];
const images=new Map();for(const a of DATA.assets){const im=new Image();im.src='data:image/png;base64,'+a.png;images.set(a.meta.id,im)}
function save(data,name,type='text/plain'){const b=new Blob([data],{type}),u=URL.createObjectURL(b),a=document.createElement('a');a.href=u;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(u),1500)}
function detail(s){$('detail').textContent=s;$('dialog').showModal()}
$('close').onclick=()=>$('dialog').close();$('manifest').onclick=()=>save(JSON.stringify(M,null,2),'manifest.json','application/json');$('notes').onclick=()=>detail(DATA.docs['integration.md']);$('qa').onclick=()=>detail(DATA.docs['QA.md']);
function indexAt(a,t){if(!a.loop)return 0;let q=Math.floor(t)%a.frames.reduce((s,f)=>s+f.duration_ticks,0);for(let i=0;i<a.frames.length;i++){if(q<a.frames[i].duration_ticks)return i;q-=a.frames[i].duration_ticks}return 0}
function render(){const q=$('search').value.toLowerCase(),g=$('group').value;cards=[];$('cards').replaceChildren();const list=DATA.assets.filter(a=>(!g||a.meta.group===g)&&a.meta.id.toLowerCase().includes(q));$('count').textContent=`${list.length} of ${DATA.assets.length} assets | Integer zoom only. Frames, pivots, descriptive footprints and connectors available under Details.`;
for(const a of list){const m=a.meta,c=document.createElement('article');c.className='card';c.innerHTML=`<div class="stage"><canvas></canvas></div><div class="name">${m.id}</div><div class="meta">${m.frame_size_px.join(' x ')} px | ${m.frames.length} frame(s)<br>${m.layer_role}</div><div class="actions"><button class="png">Save PNG</button><button class="info">Details</button></div>`;const cv=c.querySelector('canvas');cv.width=m.frame_size_px[0];cv.height=m.frame_size_px[1];cv.style.width=cv.width*zoom+'px';cv.style.height=cv.height*zoom+'px';c.querySelector('.info').onclick=()=>detail(JSON.stringify(m,null,2));c.querySelector('.png').onclick=()=>{const b=Uint8Array.from(atob(a.png),c=>c.charCodeAt(0));save(b,m.path.split('/').pop(),'image/png')};$('cards').append(c);cards.push({cv,a:m,im:images.get(m.id),previous:-1})}}
function paint(){for(const c of cards){const i=indexAt(c.a,tick);if(c.previous===i)continue;c.previous=i;const ctx=c.cv.getContext('2d');ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,c.cv.width,c.cv.height);if(!c.im.complete){c.previous=-1;continue}const [x,y,w,h]=c.a.frames[i].rect;ctx.drawImage(c.im,x,y,w,h,0,0,w,h);if(show){const [fx,fy,fw,fh]=c.a.visual_ground_footprint.rect_px;ctx.strokeStyle='#efc772';ctx.lineWidth=1;ctx.strokeRect(fx+.5,fy+.5,fw-1,fh-1);const [px,py]=c.a.pivot_px;ctx.fillStyle='#ffdf94';ctx.fillRect(px-3,py,7,1);ctx.fillRect(px,py-3,1,7)}}}
function loop(now){const dt=Math.min(100,now-last);last=now;if(running)tick+=dt*.12;paint();requestAnimationFrame(loop)}
$('search').oninput=render;$('group').onchange=render;$('zoom').onchange=()=>{zoom=+$('zoom').value;render()};$('anchors').onchange=()=>{show=$('anchors').checked;for(const c of cards)c.previous=-1;paint()};$('play').onclick=()=>{running=!running;$('play').textContent=running?'Pause motion':'Play motion'};
for(const b of document.querySelectorAll('[data-tab]'))b.onclick=()=>{document.querySelectorAll('main>section').forEach(s=>s.classList.toggle('hidden',s.id!==b.dataset.tab));document.querySelectorAll('[data-tab]').forEach(x=>x.classList.toggle('active',x===b))};let grid=false;$('grid-toggle').onclick=()=>{grid=!grid;$('img-courtyard').src=DATA.previews[grid?'courtyard_grid.png':'courtyard_review.png']};render();requestAnimationFrame(loop);
</script></html>'''
    relwrite('previews/review.html',html.replace('__DATA__',json.dumps(data,separators=(',',':')).replace('</','<\\/')))


def archive():
    p=ROOT/'FLUX_Wellspring_Map_Kit.zip'
    paths=sorted(q for q in ROOT.rglob('*') if q.is_file() and q!=p and '__pycache__' not in q.parts)
    with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for q in paths:
            arc='art_batches/pixel_v1/map/'+q.relative_to(ROOT).as_posix()
            # Stable ZIP metadata: no generated timestamps are needed for source art.
            info=zipfile.ZipInfo(arc,(2026,9,6,0,0,0)); info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,q.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    return p


def main():
    global P,PALETTE_META
    ap=argparse.ArgumentParser(description=__doc__); ap.add_argument('--palette',type=Path); args=ap.parse_args()
    for group in ('terrain','architecture','props','ambient'): (ROOT/'export'/group).mkdir(parents=True,exist_ok=True)
    (ROOT/'previews').mkdir(exist_ok=True)
    pp=args.palette or ROOT/'source/palette.json'
    if not pp.exists():
        jsave('source/palette.json',{'status':'provisional_shared_palette_unavailable','colors':DEFAULT_PALETTE,'reference_palette_path':'visual_language_v1.json','reference_palette_verified':False})
    obj=json.loads(pp.read_text(encoding='utf-8')); colors=obj.get('colors',obj)
    if set(colors)!=set(DEFAULT_PALETTE):raise ValueError('Palette must map exactly the semantic names in source/palette.json')
    for k,v in colors.items():
        if not isinstance(v,str) or len(v)!=7 or not v.startswith('#'): raise ValueError('Expected #RRGGBB for '+k)
        P[k]=tuple(bytes.fromhex(v[1:]))+(255,)
    if pp.resolve()!=(ROOT/'source/palette.json').resolve():
        jsave('source/palette.json',{'status':'provisional_pending_shared_palette_review','colors':colors,'reference_palette_verified':False})
    generate_terrain(); generate_walls(); generate_channels(); generate_academy(); generate_props(); generate_ambient()
    atlas_info=make_atlases()
    print(f'Generated {len(ASSETS)} assets; checking full seam profiles...',flush=True)
    seams=seam_tests(); qa=validate(seams,atlas_info); jsave('source/qa_results.json',qa)
    if qa['errors']:
        print(json.dumps(qa['errors'],indent=2)); raise SystemExit(1)
    build_catalogues(); compose_sample(); build_animation_preview()
    make_ora('academy_bay',['map.academy.facade.door_frame','map.academy.door.closed_panel','map.academy.roof.middle'])
    make_ora('bridge_ew',['map.bridge.ew.deck','map.bridge.ew.rear_rail','map.bridge.ew.front_rail'])
    make_ora('fountain',['map.ambient.fountain.water','map.prop.fountain.basin','map.prop.fountain.spout','map.ambient.fountain.overflow'])
    make_ora('banner',['map.prop.banner.pole','map.ambient.banner.indigo'])
    manifest=write_manifest(atlas_info,qa); write_docs(manifest,qa); build_viewer(manifest)
    p=archive();print(f"{qa['result']}: {qa['asset_count']} assets / {qa['frame_count']} frames; {seams['full_edge_profile_comparisons']} seam checks; archive {p.stat().st_size:,} bytes",flush=True)

if __name__=='__main__': main()
