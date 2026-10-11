#!/usr/bin/env python3
"""Rebuild authored pixel motifs. Offline design assets, not simulation code.
Requires Pillow. No networking, random sampling, source-checkout writes or fonts.
"""
from __future__ import annotations
import json, math
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
TILE = (64, 80)
PIVOT = (32, 40)
COLS = 8
PALETTES = {
 'water': {
  'forming':['#102a59','#1959c6','#4a9ce8','#57baff'],
  'active':['#15366e','#1f70f2','#57baff','#57baff'],
  'decaying':['#294b75','#4c79ad','#8cb8dc',None]},
 'fire': {
  'ignition':['#701d20','#ff6a2e','#ffc05a',None],
  'active':['#701d20','#fa4b26','#ff943e','#ff6a2e'],
  'cooling':['#4b2822','#8f3b27','#d5683a',None]},
 'steam': {
  'forming':['#3e586c','#7897a8','#cce2e8',None],
  'active':['#354f63','#83a6b8','#d7edf2','#ff8f4f'],
  'hot':['#584b4a','#a77d69','#f2c2a6','#ff7740'],
  'cool':['#456575','#8eb8c7','#d5edf2','#e8a065'],
  'decaying':['#566a73','#a4bdc5','#e2f0f2',None]}}

def color(h: str, alpha: int = 255) -> tuple[int,int,int,int]:
 return (*tuple(bytes.fromhex(h.lstrip('#'))),alpha)

def poly(d, points, c): d.polygon(points, fill=c)
def line(d, pts, c, width=1): d.line(pts, fill=c, width=width)

def water_frame(phase, f, reduced=False):
 im=Image.new('RGBA',(32,40)); d=ImageDraw.Draw(im)
 dark,base,bright,_=[color(c) if c else None for c in PALETTES['water'][phase]]
 k=3 if reduced else f
 if phase=='decaying':
  a=max(0,150-19*f); dark=(*dark[:3],a); base=(*base[:3],a)
  line(d,[(6,23),(10,24),(16,24),(20,23),(24,23)],dark,2)
  line(d,[(9,23),(15,23),(18,22)],base)
  if not reduced: line(d,[(19,27),(24,27),(26,26)],base)
 else:
  rise = [0,0,1,1,1,0,-1,-1][k]
  forming=phase=='forming'
  yshift=2 if forming else 0
  # An open, hooked crest with a filled underside: not a Flood chevron.
  pts=[(5,23),(7,22),(8,19),(10,16+rise),(13,14+rise),(17,14+rise),
       (19,16+rise),(19,19+rise),(17,21+rise),(14,21+rise),(13,19+rise),
       (15,18+rise),(16,19+rise),(17,18+rise),(16,17+rise),(13,17+rise),
       (11,20),(12,23),(17,24),(23,23),(26,21),(27,23),(24,26),(19,28),(12,27),(8,26)]
  pts=[(x,y+yshift) for x,y in pts]
  poly(d,pts,dark)
  body=[(7,23),(10,20),(11,17+rise),(14,15+rise),(17,15+rise),(18,17+rise),
        (17,19+rise),(16,17+rise),(13,17+rise),(11,19),(11,22),(14,25),(20,25),(25,23),(23,25),(18,27),(12,26)]
  poly(d,[(x,y+yshift) for x,y in body],base)
  line(d,[(9,20+yshift),(11,17+rise+yshift),(14,15+rise+yshift),(17,15+rise+yshift),(18,17+rise+yshift)],bright)
  line(d,[(12,24+yshift),(16,25+yshift),(22,24+yshift),(25,22+yshift)],bright)
  if not reduced and not forming:
   # Two sparse back ripples; no free particles or outward emission.
   off=[0,1,1,2,2,1,0,0][f]
   line(d,[(5+off,11),(8+off,10),(11+off,10)],base)
   line(d,[(19-off,31),(22-off,31),(25-off,30)],bright)
  if forming:
   # Build internal motif only. Ground coverage is full from the first sample.
   a=115+int(f*140/7)
   im.putalpha(im.getchannel('A').point(lambda v: v*a//255))
 return im.resize(TILE,Image.Resampling.NEAREST)

def fire_frame(phase,f,reduced=False):
 im=Image.new('RGBA',(32,40));d=ImageDraw.Draw(im)
 dark,base,bright,_=[color(c) if c else None for c in PALETTES['fire'][phase]]
 k=3 if reduced else f
 if phase=='cooling':
  a=max(0,170-23*f)
  dark=(*dark[:3],a);base=(*base[:3],int(a*.6))
  poly(d,[(7,27),(10,25),(14,26),(17,25),(22,26),(25,28),(20,30),(11,30)],dark)
  line(d,[(10,27),(13,27),(14,28)],base)
  line(d,[(17,28),(19,27),(22,28)],base)
  # No orange/yellow tips, no upward motion, no delayed danger accents.
 elif phase=='ignition':
  poly(d,[(7,28),(11,25),(21,25),(25,28),(21,30),(10,30)],dark)
  # A low split bud, never the active upright crown.
  h=3+(0 if reduced else f//2)
  poly(d,[(11,27),(12,25-h),(15,25),(17,22-h),(20,27),(18,29),(13,29)],base)
  line(d,[(13,27),(15,26),(17,27)],bright)
 else:
  sway=[-1,-1,0,1,1,0,-1,0][k]
  stretch=[0,1,2,1,0,-1,0,1][k]
  pts=[(6,28),(5,24),(7,19),(10,22),(9,15),(12,17),(14+sway,8-stretch),
       (18+sway,14),(18,11),(21,15),(20,20),(24,17),(26,22),(25,27),(21,31),(12,31)]
  poly(d,pts,dark)
  poly(d,[(7,26),(8,23),(11,25),(11,19),(13,21),(15+sway,12-stretch),
          (18+sway,17),(17,22),(20,23),(23,21),(24,25),(21,29),(12,29)],base)
  poly(d,[(11,27),(12,24),(15,26),(16+sway,19),(18,23),(20,25),(20,28),(16,30)],bright)
  if not reduced:
   # Anchored splits, contained in the cell. Not a persistent particle trail.
   line(d,[(8,29),(10,30),(14,30)],bright)
   line(d,[(22,15),(23,12+(k%2))],base)
 return im.resize(TILE,Image.Resampling.NEAREST)

def steam_frame(phase,f,reduced=False):
 im=Image.new('RGBA',(32,40));d=ImageDraw.Draw(im)
 dark,base,bright,danger=[color(c) if c else None for c in PALETTES['steam'][phase]]
 k=3 if reduced else f
 if phase=='decaying':
  a=max(0,145-20*f)
  # Broken sideways condensate, never a faint active coil.
  for pts in [[(7,25),(9,24),(12,24)],[(19,28),(22,28),(25,27)]]:
   line(d,pts,(*dark[:3],a),2);line(d,pts,(*base[:3],a))
 else:
  drift=[0,0,-1,-1,0,1,1,0][k]
  lift=[0,-1,-1,-2,-2,-1,0,0][k]
  if reduced: drift=0;lift=0
  if phase=='forming': lift=3
  # Two open ribbon curls with a quiet center; no cloud mass or smoke shader.
  paths=[[(8,29),(10,27),(11,24),(9+drift,21),(8+drift,18),
          (10,15+lift),(13,14+lift),(15,15+lift),(15,17+lift),(13,18+lift)],
         [(19,30),(22,28),(23,25),(21-drift,22),(19-drift,19),
          (20,15+lift),(22,12+lift),(25,12+lift),(26,14+lift),(25,16+lift)]]
  for path in paths:
   line(d,path,dark,3)
   line(d,path,base,2)
   line(d,[(x-1,y) for x,y in path[1:-1]],bright,1)
  if danger:
   line(d,[(8,28),(10,26)],danger,1)
   line(d,[(21,28),(23,26)],danger,1)
   if phase=='hot': line(d,[(19,25),(20,24)],danger,1)
  elif phase=='forming':
   a=110+int(f*100/7)
   im.putalpha(im.getchannel('A').point(lambda v: v*a//255))
 return im.resize(TILE,Image.Resampling.NEAREST)

# Logical icons describe identity, never affinity/roster changes.
def icon(element):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 p=json.loads((ROOT/'definitions/palette.json').read_text())
 row=next(x for x in p['elements'] if x['id']==element)
 dark,base,hi=[color(row['palette'][k]) for k in ['dark','base','bright']]
 if element=='water': return water_frame('active',3).crop((4,16,60,72)).resize((24,24),Image.Resampling.NEAREST)
 if element=='fire': return fire_frame('active',3).crop((4,4,60,64)).resize((24,24),Image.Resampling.NEAREST)
 if element=='earth':
  for x,y,w,h in [(3,12,8,7),(12,7,8,9),(13,18,7,4)]:
   poly(d,[(x,y+2),(x+2,y),(x+w,y),(x+w,y+h-1),(x+w-2,y+h),(x,y+h)],dark)
   d.rectangle((x+1,y+2,x+w-2,y+h-2),fill=base);line(d,[(x+2,y+1),(x+w-1,y+1)],hi)
 elif element=='wind':
  for path in [[(3,9),(6,5),(12,4),(16,7),(16,10),(13,12),(10,11)],[(20,14),(18,18),(12,20),(7,18),(7,15),(10,14)]]:
   line(d,path,dark,3);line(d,path,base,2);line(d,path[:3],hi)
 elif element=='ice':
  for i in range(6):
   a=math.pi*i/3;end=(12+int(9*math.sin(a)),12+int(9*math.cos(a)))
   line(d,[(12,12),end],dark,3);line(d,[(12,12),end],base)
  poly(d,[(12,7),(16,12),(12,17),(8,12)],hi)
 elif element=='charge':
  pts=[(12,2),(5,13),(11,13),(8,21),(20,9),(13,9),(17,2)]
  poly(d,pts,dark);poly(d,[(12,4),(8,11),(14,11),(11,17),(17,11),(12,11),(15,4)],base)
  line(d,[(12,5),(9,10)],hi)
 elif element=='light':
  poly(d,[(12,2),(21,12),(12,22),(3,12)],dark);poly(d,[(12,4),(19,12),(12,20),(5,12)],base)
  poly(d,[(12,7),(16,12),(12,17),(8,12)],hi)
 else:
  path=[(18,3),(11,3),(6,7),(4,13),(7,19),(14,22),(19,19),(12,18),(9,14),(10,9),(14,6)]
  poly(d,path,dark);line(d,[(16,4),(11,5),(7,9),(7,15),(10,19),(15,20)],base,3)
  line(d,[(13,6),(10,9),(9,12)],hi)
 return im

def main():
 meta={'status':'PROPOSAL','format':'RGBA8 PNG straight alpha, sRGB','filter':'nearest; no mipmaps',
       'tile':list(TILE),'pivot':list(PIVOT),'logical_pixel_world_px':2,'columns':8,
       'packing':'row-major, 8 columns, no gutter; region sampling must not bleed',
       'geometry':'Motifs only. Fill, boundary and selected polygons remain separate.', 'atlases':[]}
 for material,fn in [('water',water_frame),('fire',fire_frame),('steam',steam_frame)]:
  phases=list(PALETTES[material])
  for reduced in [False,True]:
   mode='reduced' if reduced else 'normal'
   atlas=Image.new('RGBA',(64*8,80*len(phases)))
   for r,phase in enumerate(phases):
    for f in range(8):
     frame=Image.new('RGBA',TILE) if phase in ['decaying','cooling'] and f==7 else fn(phase,f,reduced)
     frame.putdata([(0,0,0,0) if pixel[3]==0 else pixel for pixel in (frame.get_flattened_data() if hasattr(frame,'get_flattened_data') else frame.getdata())])
     atlas.paste(frame,(f*64,r*80))
   path=f'assets/motifs/{material}-{mode}.png';atlas.save(ROOT/path,optimize=True)
   meta['atlases'].append({'path':path,'material':material,'mode':mode,'dimensions':list(atlas.size),
    'rows':phases,'frames_per_row':8,'pivot':list(PIVOT),'alpha':'straight','status':'PROPOSAL'})
 for mat in ['water','earth','fire','wind','ice','charge','light','dark']:
  icon(mat).resize((48,48),Image.Resampling.NEAREST).save(ROOT/f'assets/ui/{mat}.png')
 (ROOT/'definitions/atlas-layout.json').write_text(json.dumps(meta,indent=2)+'\n')
 print('Built 6 atlases (176 frames) and 8 element icons.')
if __name__=='__main__': main()
