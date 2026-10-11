"""Coordinate-based design artifacts. SVG plans + native offline pixel compositions."""
from __future__ import annotations
from pathlib import Path
import json,math,html,sys,textwrap
import cairosvg
from PIL import Image,ImageDraw,ImageFont
from geometry import *
ROOT=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1]) if len(sys.argv)>1 else Path('/mnt/data/source_packet')
BASE=json.loads((ROOT/'evidence/source/repository/content/maps/sanctum_campus_g2_v1.json').read_text())
PILOT=json.loads((ROOT/'pilot/campus_candidate.json').read_text())
LAY=json.loads((ROOT/'HEX_LAYOUT.json').read_text())
BG='#111f27';PANEL='#1b2d35';TEXT='#f4e8ca';MUTED='#b1beb7';GOLD='#edb861';TEAL='#69d2c5';PAPER='#e7ddbd';INK='#253739';WARN='#ed927b'
class SVG:
 def __init__(self,w,h):
  self.w=w;self.h=h;self.s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs><pattern id="hatch" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M-2 10L10 -2M8 12L12 8" stroke="#edb861" stroke-width="2"/></pattern><marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto"><path d="M0 1L9 5L0 9" fill="none" stroke="{TEAL}" stroke-width="1.7"/></marker></defs>'];self.rect(0,0,w,h,BG)
 def rect(self,x,y,w,h,fill,stroke=None,sw=1,rx=0,extra=''):
  self.s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke or "none"}" stroke-width="{sw}" {extra}/>')
 def text(self,x,y,t,size=20,color=TEXT,weight=400,anchor='start',extra=''):
  self.s.append(f'<text x="{x}" y="{y}" font-family="DejaVu Sans, sans-serif" font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="{anchor}" {extra}>{html.escape(str(t))}</text>')
 def lines(self,x,y,t,width=40,size=19,color=MUTED,step=28):
  for i,line in enumerate(textwrap.wrap(t,width)):self.text(x,y+i*step,line,size,color)
 def line(self,pts,col=TEAL,sw=2,dash='',arrow=False,opacity=1):
  self.s.append(f'<polyline points="'+ ' '.join(f'{x},{y}' for x,y in pts)+f'" fill="none" stroke="{col}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round" opacity="{opacity}"'+(f' stroke-dasharray="{dash}"' if dash else '')+(' marker-end="url(#arrow)"' if arrow else '')+'/>')
 def polygon(self,pts,fill,stroke=None,sw=1,opacity=1):
  self.s.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="{fill}" stroke="{stroke or "none"}" stroke-width="{sw}" opacity="{opacity}"/>')
 def circle(self,x,y,r,fill,stroke=None,sw=1):self.s.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke or "none"}" stroke-width="{sw}"/>')
 def badge(self,x,y,n,col=GOLD):self.circle(x,y,17,col);self.text(x,y+6,n,17,BG,700,'middle')
 def save(self,name):
  p=ROOT/'artifacts'/f'{name}.svg';p.write_text(''.join(self.s)+'</svg>');cairosvg.svg2png(url=str(p),write_to=str(p.with_suffix('.png')))
 def header(self,kicker,title,sub):
  self.text(44,43,kicker,15,TEAL,700);self.text(44,94,title,40,TEXT,700);self.text(44,129,sub,18,MUTED)

def current_plan():
 s=SVG(1840,1320);s.header('01 / SOURCE-ANCHORED BASELINE','The campus that actually exists','STATIC SOURCE PLAN • source snapshot, not a fresh gameplay capture • cardinal world axes; no tile-to-tile movement')
 x0,y0,k=44,190,.43
 def xy(p):return (x0+p[0]*k,y0+(p[1]-112)*k)
 def rect(b,fill,stroke=None,sw=1):x,y=xy(b[:2]);s.rect(x,y,b[2]*k,b[3]*k,fill,stroke,sw)
 rect([0,112,3072,2192],'#b9ad89')
 for d in BASE['districts']:
  rect(d['bounds'],{'garden':'#a8ad89','nexus':'#c5b995','proving':'#b7a78b'}[d['style']], '#887e65')
 for a in BASE['activity_areas']:
  rect(a['bounds'],'none','#667259',1.5)
 for r in BASE['routes']+BASE['connections']:
  pts=[xy(p) for p in r['points']];s.line(pts,'#e1d3ae',r['width']*k,opacity=.76)
  s.line(pts,'#738b83' if r['kind']!='advanced' else '#ad8b59',1.7,'6 5' if r['kind']=='advanced' else '')
 for b in BASE['buildings']:
  rect(b['bounds'],'#354449','#223035',1.5);x,y=xy([b['bounds'][0]+b['bounds'][2]/2,b['bounds'][1]+b['bounds'][3]/2]);s.text(x,y+4,str(b['id']),11,TEXT,700,'middle')
 for i,a in enumerate(BASE['activity_areas'],1):
  x,y=xy([a['bounds'][0]+20,a['bounds'][1]+36]);s.badge(x,y,i)
 for i,t in enumerate(BASE['practice_targets']):
  x,y=xy(t['position']);s.circle(x,y,6,'#b65843',TEXT,1)
 for i,st in enumerate(BASE['stations']):
  x,y=xy(st['position']);s.rect(x-4,y-4,8,8,'#654f32',TEXT,1)
 for l in BASE['landmarks']:
  x,y=xy(l['position']);s.polygon([(x,y-8),(x+8,y),(x,y+8),(x-8,y)],'none','#146b73',2)
 p=xy(BASE['spawn']);s.circle(*p,9,TEAL,BG,2);s.text(p[0]+15,p[1]+5,'SHARED SPAWN',13,INK,700)
 # Readable world coordinate ticks, outside the map surface.
 for x in [0,512,1024,1536,2048,2560,3072]:px,py=xy((x,112));s.text(px,y0-16,x,13,MUTED,anchor='middle')
 for y in [112,512,1024,1536,2048,2304]:px,py=xy((0,y));s.text(x0+5,py+16,f'y {y}',11,INK,700)
 sx=1405
 s.text(sx,194,'SOURCE FACTS',20,GOLD,700)
 facts=[('3072 × 2304','Authored canvas; y < 112 excluded'),('3 districts','Not the nine-district future catalog'),('16 solid obstacles','Buildings only in supplied constructor'),('12 station anchors','Repeated props are not new spaces'),('1493 eligible hexes','Reproduced by offline integer port')]
 for i,(a,b) in enumerate(facts):
  y=237+i*78;s.text(sx,y,a,23,TEXT,700);s.lines(sx,y+27,b,34,16,step=23)
 s.text(sx,660,'ACTIVITY INDEX',20,GOLD,700)
 for i,a in enumerate(BASE['activity_areas'],1):
  y=700+(i-1)*38;s.badge(sx+15,y-6,i);s.text(sx+45,y,a['label'].title(),17,TEXT)
 s.text(sx,1001,'Do not infer collision from paving.',17,TEAL,700)
 s.lines(sx,1034,'Diamond markers are authored landmarks; the supplied collision builder does not turn them into walls or teleports.',34,17,step=25)
 s.text(44,1170,'0',14,MUTED);s.line([(62,1165),(62+512*k,1165)],GOLD,4);s.text(62+512*k+12,1170,'512 world px',14,MUTED)
 s.text(44,1210,'Solid charcoal = immutable AABB • pale lanes = ordinary routes • dashed = advanced markings • amber numbers = activity areas',17,TEXT)
 s.text(44,1242,'Source: campus JSON + SanctumCampusLayout.build_collision_world; chemistry eligibility: HexWorldDefinition. See SOURCE_REFERENCES.md.',16,MUTED)
 s.text(44,1280,'World y increases downward. District “elevation” bands do not establish traversable 3D terraces.',16,TEAL)
 s.save('01-current-campus')

def pilot_plan():
 s=SVG(1840,1280);s.header('02 / ONE COURTYARD NOW','Two casts. Two exits. One clear return.','PROPOSED PILOT • world coordinates verified by transform; layout is not implemented • zero additional map acreage')
 k=1.12;ox,oy=1016,1040;x0,y0=44,200
 def xy(p):return (x0+(p[0]-ox)*k,y0+(p[1]-oy)*k)
 def rect(b,fill,stroke=None,sw=1,extra=''):x,y=xy(b[:2]);s.rect(x,y,b[2]*k,b[3]*k,fill,stroke,sw,extra=extra)
 rect([1016,1040,1040,624],PAPER)
 rect([1056,1152,960,448],'#d4c49d','#8d856e',2)
 # Existing south walk is a promised open width, not a force field.
 rect([1040,1328,1000,160],'#ecdfb9')
 rect([1408,1152,160,336],'#7d8b88')
 rect([1568,1152,160,336],'#c5b591')
 # Candidate eligible cells only; lighter enough not to read like step tiles.
 allowed=eligible(PILOT)
 for cell in allowed:
  cx,cy=[v/1000 for v in center(cell)]
  if 1040<cx<2030 and 1110<cy<1600:
   s.polygon([xy((x/1000,y/1000)) for x,y in vertices(cell)],'none','#a8a48d',.65,.65)
 for b in PILOT['buildings']:
  x,y,w,h=b['bounds']
  if x+w<1016 or x>2056 or y+h<1040 or y>1664:continue
  rect(b['bounds'], '#7c6b4d' if b['id']>116 else '#354449',INK,2)
  if b['id']>116:rect(b['bounds'],'url(#hatch)')
  p=xy([x+w/2,y+h/2]);s.text(*[p[0],p[1]+7],b['id'],21,TEXT,700,'middle')
 # 18 px topology exclusions are geometry, not gameplay safety bands.
 for b in PILOT['buildings'][-2:]:
  x,y,w,h=b['bounds'];rect([x-18,y-18,w+36,h+36],'none','#865842',1.5,extra='stroke-dasharray="5 4"')
 selected=selected_disk((1568000,1248000),64000,allowed)
 for cell in selected:
  s.polygon([xy((x/1000,y/1000)) for x,y in vertices(cell)],'#7299a6','#315a6c',2,.68)
 target=xy([1568,1248]);s.circle(*target,9,INK,TEXT,3);s.line([(target[0]-14,target[1]),(target[0]+14,target[1])],TEXT,2);s.line([(target[0],target[1]-14),(target[0],target[1]+14)],TEXT,2)
 fire=[xy([1568,1440]),xy([1568,1248])];s.line(fire,'#8c4e37',4,'8 5');s.circle(*fire[0],11,'none','#8c4e37',3)
 for route in LAY['pilot']['escape_routes']:
  pts=[xy(p) for p in route['points_px']];s.line(pts,'#123c3d',10,opacity=.6);s.line(pts,TEAL,4,arrow=True)
 s.line([xy([1120,1408]),xy([1920,1408])],'#c99d50',4,'14 7')
 # Annotated points and dimensions, clear of the reaction center.
 for num,p in [(1,[1088,1104]),(2,[1192,1184]),(3,[1904,1184]),(4,[1648,1460]),(5,[1744,1536])]:s.badge(*xy(p),num)
 s.text(*[xy([1080,1128])[0],xy([1080,1128])[1]],'From shared spawn / Farflow',16,INK,700)
 s.text(*[xy([1072,1444])[0],xy([1072,1444])[1]],'160 px public return — keep clear',18,INK,700)
 s.text(*[xy([1432,1590])[0],xy([1432,1590])[1]],'106 / EXISTING WORKSHOP',17,TEXT,700,'middle')
 s.text(*[xy([1585,1430])[0],xy([1585,1430])[1]],'(1568, 1440)',14,INK,700)
 s.text(*[xy([1600,1232])[0],xy([1600,1232])[1]],'target / impact',14,INK,700)
 # World x labels outside plan, no screenshot coordinate inference.
 for x in [1056,1216,1408,1568,1768,1920,2016]:px,_=xy((x,1040));s.text(px,182,str(x),13,MUTED,anchor='middle')
 for y in [1152,1216,1288,1408,1504,1600]:_,py=xy((1016,y));s.text(48,py-6,f'y {y}',12,INK,700)
 sx=1260
 descriptions=[('1','A courtyard, not a checklist','Fountain and Farflow remain north. One 320 × 336 px quiet assay floor frames the existing target.'),('2','West shoulder / long exit','New wall 117: [1216,1216,72,72]. Round its north face into the garden return. No vault required.'),('3','East shoulder / cutback','New wall 118: [1768,1216,72,72]. A shorter dogleg changes aim pressure without narrowing public routes.'),('4','Keep the paid experiment honest','Existing 192 px firing line and 64 px width remain. Steam cells shown are an offline 64 px disk selection, not a new area rule.'),('5','Workshop is not a dead end','Use both sides of the existing workshop. The floor is not immune to casts and is not a sanctuary.')]
 for i,(n,a,b) in enumerate(descriptions):
  y=215+i*147;s.badge(sx+18,y-6,n);s.text(sx+49,y,a,19,GOLD,700);s.lines(sx+1,y+34,b,44,18,step=26)
 s.rect(44,954,1752,274,PANEL,rx=10)
 s.text(68,994,'EXACT WHERE VERIFIED',22,TEAL,700)
 s.text(68,1034,'Cell center: x = 64q + 32r; y = 55.425r world px.',20,TEXT)
 s.text(68,1068,'Impact (1568,1248) → owner (13,23), center (1568,1274.775). Do not snap the impact to that center.',18,MUTED)
 s.text(68,1104,'18 px immutable-wall clearance rejects entire overlapping chemistry hexes; unselected walkable ground is not a permanent safe zone.',18,MUTED)
 s.text(68,1140,f'Offline topology: 1493 → {len(allowed)} eligible cells ({1493-len(allowed)} removed, no new cells). Both ordinary route widths preserved.',19,TEXT)
 s.text(68,1177,'HATCHED = new solid wall  •  TEAL = continuous escape line  •  AMBER DASH = public return  •  BLUE HEXES = illustrative active Steam',16,GOLD)
 s.save('02-courtyard-pilot')

def expansion():
 s=SVG(1680,1000);s.header('06 / EXPANSION CONTRACT','The Wellspring grows by useful loops','SCHEMATIC ONLY • no proposed global coordinates • reuse existing districts before enlarging the collision world')
 boxes=[(625,210,420,215,'01 / COURTYARD','Source Court + existing Crucible','Now: two covers, two exits, quiet floor'),(68,300,410,210,'02 / MOVEMENT GARDENS','Existing west campus','Wall tangent → turn pocket → ordinary return'),(1180,300,430,210,'03 / PATTERNS + DUELS','Existing east campus','Separated target range + retained duel anchors'),(625,600,420,200,'04 / LIVING ARCHIVE','Learning + Farflow interfaces','Reference and party controls, not more boards')]
 for x,y,w,h,a,b,c in boxes:
  s.rect(x,y,w,h,PANEL,GOLD if a.startswith('01') else '#46605f',2,14);s.text(x+24,y+42,a,22,GOLD,700);s.text(x+24,y+84,b,19,TEXT,700);s.lines(x+24,y+124,c,31,18,step=27)
 s.line([(625,270),(525,270),(525,350),(478,350)],TEAL,4,arrow=True);s.line([(478,453),(552,453),(552,395),(625,395)],TEAL,3,arrow=True)
 s.line([(1045,270),(1110,270),(1110,350),(1180,350)],TEAL,4,arrow=True);s.line([(1180,453),(1115,453),(1115,395),(1045,395)],TEAL,3,arrow=True)
 s.line([(770,425),(770,600)],TEAL,3,arrow=True);s.line([(900,600),(900,425)],TEAL,3,arrow=True)
 s.text(68,600,'REUSABLE SOCKET',22,TEAL,700)
 s.lines(68,638,'192 px main walk; 160 px secondary return. Cardinal floor; optional chemistry grid overlay. Two non-coincident exits. Dimensions are design constraints, not built doors.',36,18,step=28)
 s.text(1180,600,'BEFORE A NEW POCKET',22,WARN,700)
 s.lines(1180,638,'Accept existing movement choices first. Then measure active-cell, packing, event and rendered work at equal demand. One new pocket at a time. Foundry / seasonal reaches remain unplaced.',35,18,step=28)
 s.rect(68,848,1542,104,'#283b3c',rx=12);s.text(92,885,'DO NOT SCALE ACTIVE SIMULATION WITH MAP ACREAGE',21,GOLD,700)
 s.text(92,919,'No autonomous decorative chemistry, no per-tile effects nodes, no fabricated loading boundary or new sanctuary.',18,TEXT)
 s.save('06-modular-expansion')

FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(size,b=False):return ImageFont.truetype(BOLD if b else FONT,size)
def tile(base,light,dark):
 im=Image.new('RGB',(64,64),base);d=ImageDraw.Draw(im)
 for y in range(0,64,16):
  off=0 if y%32==0 else -16
  for x in range(off,64,32):
   d.line([(x,y),(x+29,y)],fill=light,width=1);d.line([(x+30,y+2),(x+30,y+14)],fill=dark,width=1)
   if (x+y)%48==0:d.rectangle((x+7,y+6,x+10,y+6),fill=light)
 return im

def make_native(reduced=False):
 im=Image.new('RGB',(1280,720),'#77785b');d=ImageDraw.Draw(im)
 stone=tile('#9d8c6a','#a39270','#958562');slate=tile('#566465','#5d6b6b','#505e60')
 for x in range(0,1280,64):
  for y in range(0,720,64):im.paste(stone,(x,y))
 cam=(896,1000)
 def xy(p):return (round(p[0]-cam[0]),round(p[1]-cam[1]))
 def rec(b,fill):x,y=xy(b[:2]);d.rectangle((x,y,x+b[2],y+b[3]),fill=fill)
 # Vegetation is peripheral and unsaturated. These patches are visual only.
 rec([896,1000,150,720],'#566446');rec([2024,1000,152,720],'#566446')
 for x in range(928,1040,18):
  for y in range(1064,1670,28):
   if (x+y)%3:d.line([xy((x,y)),xy((x+3,y-2))],fill='#6a7651',width=2)
 for x in range(1408,1568,64):
  for y in range(1152,1488,64):
   px,py=xy((x,y));w=min(64,1568-x);h=min(64,1488-y);im.paste(slate.crop((0,0,w,h)),(px,py))
 d=ImageDraw.Draw(im)
 # Purposeful, low-contrast path edges rather than tiled grid instruction fields.
 for y in (1328,1488):d.line([xy((1056,y)),xy((2016,y))],fill='#b09b70',width=2)
 for x in (1408,1728):d.line([xy((x,1152)),xy((x,1488))],fill='#b8a272',width=2)
 # New walls and original workshop, actual ground footprint preserved.
 for b in PILOT['buildings']:
  x,y,w,h=b['bounds'];px,py=xy((x,y))
  if px>1280 or px+w<0 or py>720 or py+h<0:continue
  d.rectangle((px,py,px+w-1,py+h-1),fill='#383c36',outline='#252c2d',width=2)
  d.rectangle((px+2,py-24,px+w-3,py+h-25),fill='#88816e',outline='#363a3d',width=2)
  for yy in range(py-22,py+h-24,12):
   d.line([(px+3,yy),(px+w-4,yy)],fill='#aaa18a',width=1)
   for xx in range(px+9+(yy%24),px+w-5,24):d.line([(xx,yy),(xx,yy+10)],fill='#68685e',width=1)
  if b['id'] in [117,118]:
   d.rectangle((px+18,py+h-22,px+w-18,py+h-17),fill='#a56d24');d.line([(px+19,py+h-22),(px+w-19,py+h-22)],fill='#edc779',width=1)
 # A named, target-only silhouette; not a station in the firing line.
 tx,ty=xy((1568,1248));d.ellipse((tx-14,ty-6,tx+14,ty+7),fill='#3c443d');d.rectangle((tx-3,ty-42,tx+3,ty),fill='#4c3024');d.line([(tx-16,ty-32),(tx+16,ty-32)],fill='#c2ac7b',width=5);d.ellipse((tx-8,ty-57,tx+8,ty-41),fill='#ad7a4a',outline='#2c1d18',width=2)
 allowed=eligible(PILOT);steam=selected_disk((1568000,1248000),64000,allowed)
 # An overlap fixture is explicit illustrative material allocation, not a sector solver claim.
 magma=[(12,24),(13,24),(14,24)]
 magma=[c for c in magma if c in allowed]
 lay=Image.new('RGBA',im.size);ld=ImageDraw.Draw(lay)
 for c in magma:
  poly=[xy((x/1000,y/1000)) for x,y in vertices(c)];ld.polygon(poly,fill=(92,47,33,170));ld.line(poly+[poly[0]],fill=(250,126,58,255),width=2)
  cx,cy=xy(tuple(v/1000 for v in center(c)))
  ld.line([(cx-18,cy+5),(cx-6,cy-3),(cx+2,cy+5),(cx+17,cy-6)],fill=(255,149,64,255),width=3)
 im=Image.alpha_composite(im.convert('RGBA'),lay)
 lay=Image.new('RGBA',im.size);ld=ImageDraw.Draw(lay)
 for c in steam:
  poly=[xy((x/1000,y/1000)) for x,y in vertices(c)];ld.polygon(poly,fill=(107,157,177,60));ld.line(poly+[poly[0]],fill=(211,238,235,255),width=2)
  cx,cy=xy(tuple(v/1000 for v in center(c)))
  offsets=[0] if reduced else [-14,8]
  for off in offsets:
   ld.line([(cx+off-3,cy+8),(cx+off+3,cy+3),(cx+off-3,cy-4),(cx+off+3,cy-11)],fill=(223,241,240,255),width=2)
  ld.line([(cx-6,cy+19),(cx+6,cy+19)],fill=(249,159,91,255),width=2)
 im=Image.alpha_composite(im.convert('RGBA'),lay);d=ImageDraw.Draw(im)
 # Preserve distinct magma cracks through the transparent steam fixture.
 for c in magma:
  cx,cy=xy(tuple(v/1000 for v in center(c)))
  d.line([(cx-22,cy+13),(cx-10,cy+7),(cx-1,cy+15),(cx+21,cy+4)],fill='#ff9540',width=3)
 # Unscaled source frames: baked display heights remain 58/63/68, pivot 48,84.
 actors=[('small',(1496,1338),2,'S'),('middle',(1572,1306),6,'M'),('large',(1712,1360),4,'L')]
 for size,pos,aim,label in sorted(actors,key=lambda x:x[1][1]):
  px,py=xy(pos);d.ellipse((px-15,py-4,px+15,py+5),fill=(33,43,38,255))
  src=Image.open(SRC/f'repository/assets/sprites/wireframe_motion_v2/{size}-base.png').convert('RGBA');sprite=src.crop((aim*96,0,(aim+1)*96,96));im.alpha_composite(sprite,(px-48,py-84))
  d=ImageDraw.Draw(im);d.text((px+12,py-69),label,font=font(12,True),fill='#fff0c6',stroke_width=1,stroke_fill='#172529')
  vec={2:(1,0),6:(-1,0),4:(0,-1)}[aim];ax,ay=px+vec[0]*28,py-12+vec[1]*28
  d.line([(px+vec[0]*18,py-12+vec[1]*18),(ax,ay)],fill='#fff0c6',width=2)
 # Schematic projectile motifs separate from bodies.
 for p in [(1610,1354),(1636,1340)]:
  x,y=xy(p);d.polygon([(x-9,y+4),(x+9,y-5),(x+2,y+5)],fill='#57baff',outline='#15366e')
 # Compact sample HUD.
 def panel(box):d.rounded_rectangle(box,radius=5,fill='#101f25',outline='#a56d24',width=1)
 panel((16,14,430,60));d.text((28,22),'THE WELLSPRING / CHEMISTRY COURTYARD',font=font(15,True),fill='#f4e8ca');d.text((28,42),'F4 Compendium    •    Offline design composition',font=font(11),fill='#b7c9bd')
 panel((1032,14,1264,60));d.text((1045,23),'FARFLOW  •  SAMPLE 3 / 8',font=font(14,True),fill='#69d2c5');d.text((1045,43),'Not a connected game',font=font(11),fill='#b7c9bd')
 # Context tag keeps world-state phrasing explicit, never says safe.
 panel((16,81,270,153));d.text((28,91),'NORMAL' if not reduced else 'REDUCED EFFECTS',font=font(14,True),fill='#edb861');d.text((28,115),'Steam: leave to shed exposure',font=font(12),fill='#e6e9dc');d.text((28,134),'Magma: jump or leave ground',font=font(12),fill='#e6e9dc')
 panel((16,628,298,706))
 for y,label,value,col in [(638,'HEALTH','108/108','#e36459'),(660,'FLUX','114/114','#a66bd8'),(682,'STAMINA','660/660','#4fc3c7')]:
  d.text((28,y),label,font=font(11,True),fill='#efe7cc');d.rectangle((100,y+1,220,y+12),fill=col);d.text((227,y),value,font=font(11),fill='#efe7cc')
 panel((616,610,950,633));d.text((626,614),'PLAIN     Ctrl: 4 slots     Alt: 4 slots',font=font(12),fill='#f4e8ca')
 spells=[('1','Rillshot','BOLT','#57baff'),('2','Cinderbolt','BOLT','#ff943e'),('3','Tide Shell','HEAVY','#57baff'),('4','Flintshot','BOLT','#edc179')]
 for i,(key,name,fam,col) in enumerate(spells):
  x=616+i*162;panel((x,639,x+155,706));d.text((x+9,648),key,font=font(19,True),fill=col);d.text((x+32,649),name,font=font(13,True),fill='#f4e8ca');d.text((x+10,675),fam+'  •  sample slot',font=font(10),fill='#b1beb7');d.line([(x+9,698),(x+144,698)],fill=col,width=3)
 # Product annotation does not alter floor, coverage or actors.
 d.text((320,578),'Shared source sprites at 1:1 pixels • free movement, not hex steps',font=font(12),fill='#f4e8ca',stroke_width=1,stroke_fill='#27382e')
 d.text((318,600),'Steam: source-derived disk selection. Magma: illustrative selected cells, not runtime proof.',font=font(10),fill='#f4e8ca',stroke_width=1,stroke_fill='#27382e')
 name='04-native-reduced' if reduced else '04-native-normal';im.convert('RGB').save(ROOT/'artifacts'/f'{name}-1280x720.png')
 return {'path':f'artifacts/{name}-1280x720.png','status':'OFFLINE_PREVIEW','camera_origin_world_px':list(cam),'world_px_to_output_px':1,'source_frames':[{ 'size':size,'source_region_px':[aim*96,0,96,96],'world_foot':list(pos),'screen_foot':list(xy(pos)),'unscaled':True} for size,pos,aim,label in actors],'steam_exact_point_fixed':[1568000,1248000],'steam_radius_fixed':64000,'steam_cells_qr':[list(c) for c in steam],'magma_cells_qr':[list(c) for c in magma],'magma_status':'ILLUSTRATIVE_COVERAGE_SET_NOT_FORMATION_SOLVER','hud_sample_values':'From first source capture; not promised champion stats','rendering':'Pillow offline composition, not Godot; source palette, no shader/occlusion proof'}

def kit_board():
 s=SVG(1680,980);s.header('05 / REUSABLE SPATIAL KIT','Six pieces, many movement choices','PROPOSED ART / COLLISION CONTRACT • schematic elevations • reuse existing practice-wall behavior, do not invent vaults')
 labels=[('QUIET STONE','Floor material; no friction change','64 × 64 repeated patch'),('QUIET SLATE','Experiment contrast, not a hazard','64 × 64 repeated patch'),('BRASS THRESHOLD','One decision point, not a sign row','32 / 64 / 128 px spans'),('SHOULDER COVER','Solid footprint; wallrun-compatible','72 × 72 px • art rise 24 px'),('FARFLOW RAIL','Grouped controls, distinct silhouettes','Retain six Farflow command anchors'),('FLUSH WELLSPRING','Walk-through grate; decorative water','96 × 96 art • zero new collision')]
 for i,(title,purpose,dim) in enumerate(labels):
  col=i%3;row=i//3;x=44+col*544;y=188+row*360;s.rect(x,y,512,330,PANEL,'#405b58',1,10);s.text(x+24,y+39,title,23,GOLD,700)
  if i in (0,1):
   for yy in range(4):
    for xx in range(4):s.rect(x+152+xx*34,y+68+yy*25,32,23,'#b9a882' if i==0 else '#697a79','#819087' if i else '#c3b795')
  elif i==2:
   s.rect(x+80,y+108,350,25,'#5f4524',GOLD,2)
   for q in range(7):s.rect(x+94+q*47,y+113,28,15,'#c3954f')
  elif i==3:
   s.rect(x+178,y+110,120,92,'#574e3d');s.rect(x+178,y+78,120,92,'#9c937d','#384443',3);s.text(x+238,y+133,'72',26,INK,700,'middle')
  elif i==4:
   s.rect(x+76,y+80,360,12,'#986d3f');s.rect(x+84,y+91,12,112,'#63452e');s.rect(x+418,y+91,12,112,'#63452e')
   # Six functions, not six interchangeable instruction lecterns.
   for j in range(2):
    xx=x+112+j*53
    s.line([(xx,y+103),(xx,y+166)],'#b99651',3)
    s.polygon([(xx,y+106),(xx+27,y+118),(xx,y+133)],'#5b837c',GOLD,1)
    s.line([(xx+(2 if j==0 else 22),y+146),(xx+(22 if j==0 else 2),y+146)],TEAL,2)
    tip=xx+(22 if j==0 else 2);s.line([(tip+(-5 if j==0 else 5),y+141),(tip,y+146),(tip+(-5 if j==0 else 5),y+151)],TEAL,2)
   s.circle(x+226,y+132,16,'#b99651',GOLD,2);s.polygon([(x+226,y+119),(x+233,y+132),(x+226,y+143),(x+219,y+132)],PANEL)
   s.rect(x+263,y+113,25,40,'#355d58',GOLD,2,4);s.rect(x+270,y+121,11,24,TEAL);s.line([(x+269,y+109),(x+282,y+109)],GOLD,2)
   s.rect(x+314,y+110,31,46,'#846d43',GOLD,1,3)
   for yy in [120,132,144]:s.circle(x+321,y+yy,2,TEXT);s.line([(x+327,y+yy),(x+339,y+yy)],TEXT,2)
   s.polygon([(x+366,y+148),(x+372,y+123),(x+387,y+123),(x+393,y+148)],'#b99651',GOLD,2);s.circle(x+380,y+153,3,GOLD);s.line([(x+364,y+113),(x+395,y+113)],'#986d3f',5)
   for j,label in enumerate(['HOST','JOIN','RULES','READY','ROSTER','PART']):s.text(x+126+j*51,y+184,label,10,MUTED,700,'middle')
  else:
   s.circle(x+256,y+154,66,'#817658','#d1b87f',4);s.circle(x+256,y+154,46,'#375b66','#6aacae',3)
   for off in [-27,-9,9,27]:s.line([(x+217,y+154+off),(x+295,y+154+off)],'#c8b875',3)
   s.line([(x+256,y+156),(x+256,y+80)],'#70dadb',7);s.line([(x+252,y+129),(x+260,y+100)],'#c8f2e5',3)
  s.text(x+24,y+252,purpose,18,TEXT);s.text(x+24,y+287,dim,17,MUTED)
 s.text(44,946,'Facades do not define height clearance. Decorative water never deposits ingredients. More copies do not create more active simulation agents.',16,TEAL)
 s.save('05-reusable-kit')

if __name__=='__main__':
 current_plan();pilot_plan();expansion();kit_board()
 compositions=[make_native(False),make_native(True)]
 (ROOT/'data/native_composition.json').write_text(json.dumps(compositions,indent=2)+'\n')
 print('Rendered current / pilot / kit / expansion SVG+PNG and two native compositions.')
