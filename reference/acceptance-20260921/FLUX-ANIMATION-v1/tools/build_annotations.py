#!/usr/bin/env python3
"""Rebuild precise review annotations from the delivered, untouched source PNGs.
No new production sprites are authored. Requires Pillow. Run from any directory.
"""
from pathlib import Path
import json, math, hashlib
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
C=json.loads((ROOT/'pilots/cases.json').read_text())
MAN=json.loads((ROOT/'originals/manifest.json').read_text())
BG='#101c27'; PANEL='#192a38'; INK='#f0e5cf'; MUTED='#abb8bc'; GOLD='#e7b566'; CYAN='#8bdcde'; LINE='#405260'
LIGHT='#dfd3b8'; DARK='#25292a'
FONT_FILES=['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','C:/Windows/Fonts/arial.ttf','/Library/Fonts/Arial.ttf']
font_path=next((p for p in FONT_FILES if Path(p).exists()),None)
def font(n):
    return ImageFont.truetype(font_path,n) if font_path else ImageFont.load_default(size=n)
def text(d,xy,s,n=16,fill=INK): d.text(xy,str(s),font=font(n),fill=fill)
def wrap(d,xy,s,width,n=16,fill=INK,leading=6):
    x,y=xy;cur=''
    for w in s.split():
        cand=(cur+' '+w).strip()
        if d.textlength(cand,font=font(n))>width and cur:
            text(d,(x,y),cur,n,fill);y+=n+leading;cur=w
        else:cur=cand
    if cur:text(d,(x,y),cur,n,fill);y+=n+leading
    return y

def arrow(d,a,b,col,width=2):
    d.line([a,b],fill=col,width=width);dx=b[0]-a[0];dy=b[1]-a[1];l=math.hypot(dx,dy)
    if l:
        ux,uy=dx/l,dy/l
        d.polygon([b,(b[0]-7*ux+3*uy,b[1]-7*uy-3*ux),(b[0]-7*ux-3*uy,b[1]-7*uy+3*ux)],fill=col)

def axes(d,x,y,t,a):
    v=MAN['directions'];fixed=[(0,1),(.707,.707),(1,0),(.707,-.707),(0,-1),(-.707,-.707),(-1,0),(-.707,.707)]
    for idx,base,col in [(a,(x,y),CYAN),(t,(x+82,y),GOLD)]:
        vx,vy=fixed[idx];arrow(d,base,(base[0]+vx*23,base[1]+vy*23),col)
    text(d,(x-17,y+29),'AIM',11,CYAN);text(d,(x+61,y+29),'TRAVEL',11,GOLD)

def select(size,case,phase):
    bank=case['bank'];state=None
    if case['id']=='P05':bank='base';state='jump' if phase<2 else 'grounded'
    elif bank=='base':state=case['source_state']
    if bank=='base':
        cx=case['aim_index'];cy=MAN['base_rows'].index(state);index=cy*8+cx
    else:
        index=((case['travel_index']*8+case['aim_index'])*8+phase);cx=index%16;cy=index//16
    file=f'{size}-{bank}.png';im=Image.open(ROOT/'originals'/file).convert('RGBA')
    box=(cx*96,cy*96,cx*96+96,cy*96+96)
    return im.crop(box),{'source':'originals/'+file,'source_rect_xywh':[box[0],box[1],96,96], 'source_index':index,'phase_sample':phase,'state':state or bank,'travel':case['travel_index'],'aim':case['aim_index'],'lookup_or_storyboard':case['source_mode']}

def base(size,state,aim):
    im=Image.open(ROOT/'originals'/f'{size}-base.png').convert('RGBA');r=MAN['base_rows'].index(state)
    return im.crop((aim*96,r*96,aim*96+96,r*96+96))

def mark(d,x,y,label,support):
    col=GOLD if label=='L' else CYAN
    if label=='L':points=[(x,y-5),(x+5,y),(x,y+5),(x-5,y)];d.polygon(points,fill=col if support else PANEL,outline=col)
    else:d.rectangle((x-4,y-4,x+4,y+4),fill=col if support else PANEL,outline=col,width=1)
    text(d,(x-4,y+10),label,11,col)

def timeline(d,case,y):
    text(d,(42,y),'PROPOSED CONTACT / ACTION SAMPLES — not extracted rig contacts',17,GOLD)
    y+=37
    for p in range(8):
        x=42+p*150;d.rounded_rectangle((x,y,x+138,y+103),radius=6,fill=PANEL)
        text(d,(x+9,y+7),f'{p:02d}  {case["phase_labels"][p]}',12)
        yy=y+54;d.line((x+12,yy,x+126,yy),fill=LINE,width=2)
        if case['id']=='P05':
            planted=p>=2;lift=12 if p<2 else 0
            mark(d,x+49,yy-lift,'L',planted);mark(d,x+91,yy-lift,'R',planted)
        elif case['id']=='P02':
            mark(d,x+47,yy,'L',True);mark(d,x+90,yy,'R',True)
            arrow(d,(x+21,yy-13),(x+54,yy-29),GOLD)
        else:
            left=p<4;mark(d,x+45,yy-(0 if left else 10),'L',left);mark(d,x+92,yy-(10 if left else 0),'R',not left)
    return y+113

def header(im,title,kicker):
    d=ImageDraw.Draw(im);text(d,(42,22),'FLUX  /  SHARED BODY LAB',14,GOLD)
    text(d,(42,49),title,28);text(d,(42,93),kicker,14,MUTED)
    d.line((42,124,1238,124),fill=LINE,width=1)
    return d

def board(case):
    im=Image.new('RGB',(1280,1050),BG);d=header(im,case['title'],'SMALL FIRST   ·   OFFLINE_PREVIEW   ·   original pixels + precise review annotations')
    text(d,(42,138),case['source_label'],16)
    text(d,(42,165),'1× raster pixels · light and dark test swatches · each cell stays 96 × 96',14,MUTED)
    for k,bg in enumerate([LIGHT,DARK]):
        y=199+k*123
        for p in range(8):
            x=42+p*150;d.rectangle((x,y,x+138,y+112),fill=bg)
            crop,_=select('small',case,p);im.paste(crop,(x+21,y+3),crop)
            d.line((x+9,y+87,x+16,y+87),fill='#657075');d.line((x+118,y+87,x+129,y+87),fill='#657075')
            text(d,(x+10,y+93),f'phase {p}',12,'#343d42' if k==0 else INK)
    y=timeline(d,case,465)
    contact='Solid = proposed support; hollow = swing. L diamond / R square are anatomical IDs, never costume colors.'
    if case['id']=='P02':contact='Solid marks here mean GLIDING contact, not a walking plant. Arrow is a review cue for NE travel only.'
    if case['id']=='P04':contact='* Storyboard action samples only; not driven by gait. Feet keep their phase; release follows the actual cast event.'
    if case['id']=='P05':contact='* Precontact is illustrative, never a predicted ground plant. At confirmed contact: two-foot load; lift stays separate.'
    text(d,(42,y+1),contact,13,MUTED)
    y=655
    chosen=[select('small',case,0)[0],select('small',case,4)[0]]
    captions=['Source phase 0','Source phase 4']
    if case['id']=='P02':chosen[1]=base('small','slide',3);captions=['Selected S slide, T3/A0','Existing NE slide, aim 3']
    if case['id']=='P04':chosen[1]=base('small','cast',2);captions=['Gait source, T4/A2','Separate static E cast']
    if case['id']=='P05':captions=['Source jump','Source grounded']
    for k,crop in enumerate(chosen):
        x=42+k*309;d.rectangle((x,y,x+294,y+292),fill=DARK)
        im.paste(crop.resize((288,288),Image.Resampling.NEAREST),(x+3,y),crop.resize((288,288),Image.Resampling.NEAREST))
        # Fixed baseline / pivot shown outside body. No joint positions inferred.
        d.line((x+8,y+252,x+283,y+252),fill=LINE,width=1)
        d.line((x+147,y+249,x+147,y+259),fill=CYAN,width=1)
        text(d,(x+8,y+270),'3× · feet pivot (48,84)',12,MUTED)
        text(d,(x,y+302),captions[k],14)
    yy=y;text(d,(677,yy),'FINDING',13,GOLD);yy=wrap(d,(677,yy+24),case['observed'],557,16)+9
    text(d,(677,yy),'CANDIDATE',13,GOLD);yy=wrap(d,(677,yy+24),case['proposal'],557,16)+8
    text(d,(677,yy),'NEEDS RUNTIME',13,CYAN);yy=wrap(d,(677,yy+24),case['runtime_gate'],557,14,fill=MUTED)
    text(d,(42,1010),f'{case["id"]}  ·  Source crops unchanged. Timeline is proposed. No game run, contact proof or skin acceptance.',13,MUTED)
    return im

def flipbook(size,case):
    frames=[]
    for p in range(8):
        im=Image.new('RGB',(800,360),BG);d=ImageDraw.Draw(im)
        text(d,(20,12),f'{case["id"]} · {size.upper()} · OFFLINE SOURCE / STORYBOARD',18,GOLD)
        text(d,(20,41),case['title'],16)
        text(d,(20,71),f'Sample {p}/7   ·   800 ms review loop, not game timing',13,MUTED)
        d.rectangle((20,106,302,291),fill=LIGHT);d.rectangle((320,106,778,291),fill=DARK)
        crop,_=select(size,case,p);im.paste(crop,(65,121),crop)
        bigger=crop.resize((192,192),Image.Resampling.NEAREST);im.paste(bigger,(350,99),bigger)
        text(d,(38,260),'1× source',13,'#303b41');text(d,(561,125),'2× nearest',14,INK)
        axes(d,596,190,case['travel_index'],case['aim_index'])
        text(d,(20,308),case['source_mode'].replace('_',' '),14)
        text(d,(20,332),'No continuous-gameplay evidence. No new production pose is implied.',12,MUTED)
        frames.append(im)
    return frames

def registration():
    im=Image.new('RGB',(1280,1070),BG);d=header(im,'Stable registration · three distinct templates','STATIC SOURCE AUDIT   ·   measured occupied bounds are not bone-length measurements')
    for sidx,size in enumerate(['small','middle','large']):
        x=42+sidx*410;definition=MAN['sizes'][size]
        text(d,(x,147),size.upper(),23,GOLD)
        text(d,(x,181),f'Display {definition["display_height"]} px · reference {definition["reference_height"]} px',16)
        text(d,(x,208),f'One baked scale: {definition["presentation_scale"]:.8f}',14,MUTED)
        for ri,state in enumerate(['grounded','slide']):
            y=249+ri*337;crop=base(size,state,0);bb=crop.getbbox();big=crop.resize((288,288),Image.Resampling.NEAREST)
            d.rectangle((x,y,x+385,y+298),fill=DARK);im.paste(big,(x+49,y),big)
            bx=x+49;d.line((bx+12,y+252,bx+274,y+252),fill=CYAN,width=1)
            d.rectangle((bx+bb[0]*3,y+bb[1]*3,bx+bb[2]*3-1,y+bb[3]*3-1),outline=GOLD,width=1)
            text(d,(x+11,y+274),f'{state}: {bb[3]-bb[1]} px occupied · 3× view',14)
            text(d,(x,y+309),f'Native bbox {list(bb)} · max edges exclusive',12,MUTED)
    text(d,(42,935),'Do not stretch a seated 43 / 46 / 50 px pose back to the 58 / 63 / 68 px standing target.',20,GOLD)
    text(d,(42,973),'Pivot Y=84 is the baseline edge. South soles end at source row 83; rows 84–95 remain transparent.',16)
    text(d,(42,1005),'Transfer rig rules, not resized Small pixels. Hurtboxes 17/18/19 px; common clearance 18 px; all stats unchanged.',15,MUTED)
    return im

def foundation():
    im=Image.new('RGB',(1280,810),BG);d=header(im,'Small foundation · direction and pose truth','SOURCE_VISIBLE   ·   active slide_v1 atlas   ·   exactly registered source crops')
    for i,name in enumerate(['S 0','SE 1','E 2','NE 3','N 4','NW 5','W 6','SW 7']):
        x=42+i*150;d.rectangle((x,160,x+138,281),fill=LIGHT)
        crop=base('small','grounded',i);im.paste(crop,(x+21,162),crop);text(d,(x+51,262),name,14,'#293844')
    text(d,(42,301),'Screen +X → East; +Y → South. Diagonals are authored columns, not rotated or mirrored substitutes.',16)
    for i,state in enumerate(['grounded','jump','cast','slide','roll']):
        x=42+i*240;crop=base('small',state,0);bb=crop.getbbox();big=crop.resize((192,192),Image.Resampling.NEAREST)
        d.rectangle((x,355,x+218,578),fill=DARK);im.paste(big,(x+13,355),big)
        d.line((x+20,523,x+202,523),fill=LINE,width=1)
        text(d,(x+12,549),state.upper(),17,GOLD)
        text(d,(x+6,591),f'{bb[3]-bb[1]} px occupied · 2×',14)
    wrap(d,(42,643),'The source sheet contains action silhouettes, not entry/hold/release/landing sequences. Jump is compressed in the source cell; physical lift and shadows are separate. Changing occupied height is not itself a proportion change.',1190,19)
    text(d,(42,766),'Cell 96×96 · feet pivot (48,84) · standing height 58 px · no body scaling or pixel cleanup performed',15,MUTED)
    return im

def build():
    outputs=[]
    for case in C:
        for size in ['small','middle','large']:
            strip=Image.new('RGBA',(768,96));crops=[]
            for p in range(8):
                crop,record=select(size,case,p);strip.paste(crop,(p*96,0));crops.append(record)
            rel=f'pilots/{case["id"]}-{size}-source-strip.png';strip.save(ROOT/rel)
            outputs.append({'path':rel,'status':'OFFLINE_PREVIEW','role':'exact_source_crops_not_new_sprite_atlas','size':size,'dimensions':[768,96],'cell':[96,96],'pivot':[48,84],'crops':crops})
        rel=f'images/{case["id"]}-annotated.png';board(case).save(ROOT/rel);outputs.append({'path':rel,'status':'OFFLINE_PREVIEW','role':'exact_source_crops_plus_proposed_review_annotations','derived_from':[f'pilots/{case["id"]}-small-source-strip.png'],'extra_source_cell':{'P02':'small-base slide aim3','P04':'small-base cast aim2'}.get(case['id'])})
        frames=flipbook('small',case);rel=f'pilots/{case["id"]}-small-source-flipbook.gif'
        frames[0].save(ROOT/rel,save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2,optimize=False)
        outputs.append({'path':rel,'status':'OFFLINE_PREVIEW','role':'labeled_lookup_or_storyboard_flipbook','frame_duration_ms':100,'frame_count':8,'runtime_evidence':False})
    for rel,im in [('images/00-small-foundation.png',foundation()),('images/06-size-transfer.png',registration())]:
        im.save(ROOT/rel);outputs.append({'path':rel,'status':'OFFLINE_PREVIEW','role':'precise_source_annotation','source_originals':'originals/*-base.png'})
    for record in outputs:
        f=ROOT/record['path'];record.update({'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size})
    out={'schema_version':1,'status':'OFFLINE_PREVIEW','method':'Exact Pillow crops from original PNGs; nearest-neighbor enlargement and separately drawn annotations. No AI image generation or source repainting.','source_raster_originals':'originals/','new_production_sprites':0,'font_note':'System fonts used for review annotations only; no font files distributed.','outputs':outputs}
    (ROOT/'pilots/image-manifest.json').write_text(json.dumps(out,indent=2))
    return {'annotated_boards':7,'source_strips':15,'source_flipbooks':5,'new_production_sprites':0}
if __name__=='__main__':print(build())
