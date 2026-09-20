#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, math, shutil, zipfile
from pathlib import Path
from PIL import Image, ImageDraw

C=32; P=(16,28); DIRS=['south','south_east','east','north_east','north','north_west','west','south_west']
A={
'idle':(0,0,4,6),'walk':(1,0,4,10),'sprint':(2,0,6,14),'hop':(3,0,4,12),'double_jump':(4,0,4,14),
'rise':(0,1,2,10),'fall':(1,1,2,10),'land':(2,1,3,12),'wall_contact':(3,1,2,8),'wall_kick':(4,1,4,14),
'air_dodge':(0,2,4,16),'wavedash':(1,2,4,16),'slide':(2,2,4,14),'slide_jump':(3,2,4,14),'vault':(4,2,5,14),
'superglide':(0,3,5,16),'attack_primary':(1,3,4,12),'cast':(2,3,5,10),'defend':(3,3,3,8),'hit':(4,3,2,12),
'stunned':(0,4,3,6),'rooted':(1,4,2,6),'defeated':(2,4,4,8),'interact':(3,4,3,8),'taunt':(4,4,4,8)}
S={'size_1_tiny':(12,6),'size_2_small':(16,8),'size_3_medium':(20,10),'size_4_large':(24,12),'size_5_huge':(28,14)}
PAL={'water':'#153c4a','water2':'#28677a','shadow':'#17261b','grass':'#304b27','moss':'#66834a','path':'#8b7045','stone':'#b6a477','bone':'#26282a','wood':'#4b3226','brass':'#b88438','cyan':'#55dbe0','violet':'#9b65d9','fire':'#e58a38','paper':'#e2d8b2','ink':'#101314'}
def col(h,a=255): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))+(a,)
def save(im,p): p.parent.mkdir(parents=True,exist_ok=True); im.save(p,'PNG',optimize=True,compress_level=9)
def vec(di): return [(0,1),(1,1),(1,0),(1,-1),(0,-1),(-1,-1),(-1,0),(-1,1)][di]
def pose(an,f,n):
    t=f/max(1,n-1); q=-1 if f%2 else 1
    d={'lift':0,'crouch':0,'lean':0,'stride':0,'arms':0,'squash':0}
    if an=='idle': d['arms']=round(math.sin(t*math.tau))
    elif an=='walk': d.update(stride=q*2,arms=-q*2,lift=1 if f in (1,3) else 0)
    elif an=='sprint': d.update(stride=q*3,arms=-q*3,lean=2,lift=1 if f in (1,4) else 0)
    elif an in ('hop','double_jump','slide_jump','wall_kick'): d.update(lift=[0,3,6,3][f],arms=2,stride=q*2)
    elif an=='rise': d.update(lift=4+f*2,arms=2)
    elif an=='fall': d.update(lift=6-f*2,arms=-1)
    elif an=='land': d.update(lift=[2,0,0][f],crouch=[0,3,1][f],squash=[0,2,0][f])
    elif an=='wall_contact': d.update(lift=2,lean=2,arms=3,stride=q*2)
    elif an in ('air_dodge','wavedash'): d.update(lift=3 if an=='air_dodge' else 0,crouch=2 if an=='wavedash' else 0,lean=[0,3,4,1][f],stride=[0,2,4,1][f])
    elif an=='slide': d.update(crouch=3,lean=3,stride=3,arms=-2)
    elif an in ('vault','superglide'): d.update(lift=([0,3,6,5,2] if an=='vault' else [1,4,7,5,2])[f],lean=3,stride=3,arms=2)
    elif an=='attack_primary': d.update(lean=[0,1,2,0][f],arms=[0,2,4,1][f])
    elif an=='cast': d.update(arms=[1,2,4,4,1][f],lift=1 if f in (2,3) else 0)
    elif an=='defend': d.update(crouch=1,arms=3,lean=-1)
    elif an=='hit': d.update(lean=[-3,-1][f],stride=-2,arms=-2)
    elif an=='stunned': d.update(crouch=1,lean=f-1,arms=-1)
    elif an=='rooted': d.update(crouch=1,arms=1,squash=f)
    elif an=='defeated': d.update(crouch=[1,3,5,6][f],lean=[0,2,4,5][f],stride=[0,1,3,5][f],squash=f)
    elif an=='interact': d['arms']=[1,4,1][f]
    elif an=='taunt': d.update(arms=[1,4,4,1][f],lift=1 if f in (1,2) else 0)
    return d
def pts(h,w,p,di):
    dx,dy=vec(di); fy=P[1]-p['lift']; hh=max(8,h-p['crouch']-p['squash']); th=max(4,hh//3); lh=max(3,hh//3)
    hip=(P[0]+p['lean'],fy-lh); sh=(hip[0]+dx*(1 if p['arms']>2 else 0),hip[1]-th); head=(sh[0]+dx,sh[1]-max(2,w//4)-1); lx=max(2,w//3); st=p['stride']
    lf=(P[0]-lx+st,fy); rf=(P[0]+lx-st,fy); lk=((hip[0]+lf[0])//2-st//2,(hip[1]+lf[1])//2); rk=((hip[0]+rf[0])//2+st//2,(hip[1]+rf[1])//2)
    span=max(3,w//2); ar=p['arms']; lhnd=(sh[0]-span-dx*ar,sh[1]+th//2-ar); rhnd=(sh[0]+span+dx*ar,sh[1]+th//2-ar)
    le=((sh[0]+lhnd[0])//2,(sh[1]+lhnd[1])//2); re=((sh[0]+rhnd[0])//2,(sh[1]+rhnd[1])//2)
    return dict(hip=hip,sh=sh,head=head,lf=lf,rf=rf,lk=lk,rk=rk,lh=lhnd,rh=rhnd,le=le,re=re)
def frame(size,an,di,f,debug=False,nico=False):
    h,w=S[size]; n=A[an][2]; po=pose(an,f,n); z=pts(h,w,po,di); im=Image.new('RGBA',(C,C)); d=ImageDraw.Draw(im); lift=po['lift']; rx=max(2,w//2+2-lift//3); d.ellipse((16-rx,27,16+rx,29),fill=(3,7,8,70))
    if not nico:
        lines=[(z['hip'],z['lk'],z['lf']),(z['hip'],z['rk'],z['rf']),(z['sh'],z['le'],z['lh']),(z['sh'],z['re'],z['rh']),(z['hip'],z['sh'])]; lw=1 if h<=16 else 2
        for q in lines: d.line(q,fill=col(PAL['ink']),width=lw+2,joint='curve')
        for q in lines: d.line(q,fill=col('#d6c9a2'),width=lw,joint='curve')
        r=max(2,w//4); x,y=z['head']; d.ellipse((x-r-1,y-r-1,x+r+1,y+r+1),fill=col(PAL['ink'])); d.ellipse((x-r,y-r,x+r,y+r),fill=col('#d6c9a2'))
    else:
        skin=col('#b98968'); teal=col('#38707a'); dark=col('#24434a'); brass=col(PAL['brass']); cyan=col(PAL['cyan']); ink=col(PAL['ink'])
        for k,foot in (('lk','lf'),('rk','rf')): d.line((z['hip'],z[k],z[foot]),fill=ink,width=3); d.line((z['hip'],z[k],z[foot]),fill=dark,width=1)
        x,y=z['sh']; hx,hy=z['hip']; d.polygon([(x-4,y-1),(x+4,y-1),(hx+3,hy+2),(hx-3,hy+2)],fill=ink); d.polygon([(x-3,y),(x+3,y),(hx+2,hy+1),(hx-2,hy+1)],fill=teal); d.line((x,y,hx,hy+1),fill=brass)
        for e,hand,c in ((z['le'],z['lh'],dark),(z['re'],z['rh'],brass)): d.line((z['sh'],e,hand),fill=ink,width=3); d.line((z['sh'],e,hand),fill=c,width=1)
        d.rectangle((z['rh'][0]-1,z['rh'][1]-1,z['rh'][0]+1,z['rh'][1]+1),fill=cyan)
        x,y=z['head']; d.ellipse((x-4,y-4,x+4,y+4),fill=ink); d.ellipse((x-3,y-3,x+3,y+3),fill=skin); d.rectangle((x-4,y-1,x-3,y+3),fill=col('#d8d4bd')); d.rectangle((x+3,y-1,x+4,y+3),fill=col('#d8d4bd')); dx,dy=vec(di); d.point((x+dx,y+max(-1,min(1,dy))),fill=cyan)
        bx=z['sh'][0]-vec(di)[0]*3; by=z['sh'][1]+2; d.rectangle((bx-2,by-2,bx+2,by+2),fill=ink); d.rectangle((bx-1,by-1,bx+1,by+1),fill=brass)
        if an in ('cast','attack_primary','taunt') and f>=n//2:
            cx,cy=z['rh']
            for ox,oy in ((-3,0),(3,0),(0,-3)): d.point((max(0,min(31,cx+ox)),max(0,min(31,cy+oy))),fill=cyan)
    if debug:
        top=max(0,28-h-po['lift']-2); half=max(4,w//2+3); d.rectangle((16-half,top,16+half,28),outline=(60,225,235,180)); d.line((16,0,16,31),fill=(60,225,235,110)); d.line((0,28,31,28),fill=(255,70,65,190)); d.rectangle((15,27,17,29),fill=(255,40,40,255))
    return im
def atlas(size,nico=False,debug=False):
    im=Image.new('RGBA',(960,1280))
    for an,(bx,by,n,fps) in A.items():
        for di in range(8):
            for f in range(n): im.alpha_composite(frame(size,an,di,f,debug,nico),(bx*192+f*32,by*256+di*32))
    return im
def tiles():
    im=Image.new('RGBA',(256,256)); d=ImageDraw.Draw(im); reg={}
    def add(name,x,y,base,edge,tags):
        X=x*16;Y=y*16;d.rectangle((X,Y,X+15,Y+15),fill=col(base),outline=col(edge))
        for i in range(7): d.point((X+1+(x*7+i*11)%14,Y+1+(y*13+i*5)%14),fill=col(edge))
        reg[name]={'tile':[x,y],'region':[X,Y,16,16],'tags':tags}
    base=[('worldbone',PAL['bone'],'#111416',['immutable']),('pale_stone',PAL['stone'],'#796e55',['walkable']),('warm_path',PAL['path'],'#5e482e',['walkable']),('grass',PAL['grass'],PAL['shadow'],['walkable']),('moss',PAL['moss'],PAL['grass'],['walkable']),('timber_floor',PAL['wood'],'#2b1e19',['walkable']),('undercroft_floor','#343638',PAL['bone'],['walkable']),('brass_plate',PAL['brass'],'#6f4b20',['device'])]
    for i,q in enumerate(base): add(q[0],i,0,q[1],q[2],q[3])
    for i in range(8):
        X=i*16;Y=16;d.rectangle((X,Y,X+15,Y+15),fill=col(PAL['water']));d.line((X,Y+4+i%3,X+15,Y+2+i%3),fill=col(PAL['water2']));reg[f'water_{i}']={'tile':[i,1],'region':[X,Y,16,16],'tags':['water']}
        add(f'cliff_{i}',i,2,PAL['bone'],'#101315',['worldbone']);d.line((X,Y+19,X+15,Y+19),fill=col(PAL['stone']),width=2)
        X=i*16;Y=48;d.polygon([(X,Y+6),(X+8,Y),(X+15,Y+6),(X+15,Y+15),(X,Y+15)],fill=col('#5f4030'));d.line((X,Y+6,X+8,Y,X+15,Y+6),fill=col(PAL['brass']));reg[f'roof_{i}']={'tile':[i,3],'region':[X,Y,16,16],'tags':['foreground','cutaway']}
        X=i*16;Y=64;d.rectangle((X,Y,X+15,Y+15),fill=col(PAL['water']));d.polygon([(X,Y),(X+15,Y),(X+15,Y+8),(X+8,Y+6),(X,Y+9)],fill=col(PAL['path']));reg[f'shore_{i}']={'tile':[i,4],'region':[X,Y,16,16],'tags':['shore']}
        add(f'bridge_{i}',i,5,PAL['wood'],'#281b17',['bridge']); X=i*16;Y=80
        for q in (3,8,13): d.line((X,Y+q,X+15,Y+q),fill=col(PAL['brass']))
        X=i*16;Y=96;d.rectangle((X,Y,X+15,Y+15),fill=col(PAL['bone']));d.ellipse((X+3,Y+3,X+12,Y+12),outline=col(PAL['brass']),width=2);d.arc((X+5,Y+5,X+10,Y+10),i*35,i*35+230,fill=col(PAL['cyan']),width=2);reg[f'shrine_{i}']={'tile':[i,6],'region':[X,Y,16,16],'tags':['attunement']}
        X=i*16;Y=112;d.ellipse((X+2,Y+2,X+11,Y+11),fill=col(PAL['grass']));d.ellipse((X+7,Y+1,X+14,Y+9),fill=col(PAL['moss']));d.rectangle((X+7,Y+8,X+8,Y+15),fill=col(PAL['wood']));reg[f'vegetation_{i}']={'tile':[i,7],'region':[X,Y,16,16],'tags':['foreground','cutaway']}
        X=i*16;Y=128;d.rectangle((X+4,Y+4,X+11,Y+14),fill=col(PAL['wood']),outline=col(PAL['ink']));d.rectangle((X+5,Y+5,X+10,Y+9),fill=col(PAL['brass']));d.point((X+7,Y+7),fill=col(PAL['cyan']));reg[f'device_{i}']={'tile':[i,8],'region':[X,Y,16,16],'tags':['interactive']}
    return im,reg
def material_icons():
    names=['empty','worldbone','stone','brick','wood','water','oil','fire','steam','ice','rubble'];im=Image.new('RGBA',(176,16));d=ImageDraw.Draw(im)
    fills=[None,PAL['bone'],'#77766d','#8d5942',PAL['wood'],PAL['water'],'#261e2b',None,None,'#7bbdca','#514e46']
    for i,n in enumerate(names):
        x=i*16
        if fills[i]: d.rectangle((x,0,x+15,15),fill=col(fills[i]),outline=col(PAL['ink']))
        if n=='brick':
            for y in (4,9,14): d.line((x,y,x+15,y),fill=col('#4e3429'))
        elif n=='wood':
            for q in (3,11): d.line((x+q,0,x+q,15),fill=col('#2f211a'))
        elif n=='water': d.line((x,5,x+7,3,x+15,5),fill=col(PAL['water2']))
        elif n=='fire': d.polygon([(x+8,1),(x+13,11),(x+8,15),(x+3,11),(x+6,6)],fill=col(PAL['fire']))
        elif n=='steam':
            for q in (4,8,12): d.ellipse((x+q-3,4,x+q+3,10),fill=col('#d9e5e2',140))
        elif n=='ice': d.line((x+2,13,x+7,4,x+12,2),fill=col('#e1fbff'))
        elif n=='rubble': d.polygon([(x+1,13),(x+5,6),(x+8,14)],fill=col('#817a6b'))
    return im,names
def icon_sets():
    E=Image.new('RGBA',(128,16));d=ImageDraw.Draw(E); es=[('earth','#8d7d55'),('fire',PAL['fire']),('water','#4aa4c2'),('wind','#b8d9d2'),('ice','#a4e5ee'),('charge',PAL['cyan']),('light','#f3e7a0'),('dark','#60428b')]
    for i,(n,c) in enumerate(es):
        x=i*16; d.ellipse((x+3,3,x+13,13),fill=col(c),outline=col(PAL['ink'])); d.line((x+8,1,x+8,15),fill=col(c))
        if n=='charge': d.polygon([(x+9,1),(x+4,8),(x+8,8),(x+5,15),(x+13,6),(x+9,6)],fill=col(c))
    abs=['arc_primary','vector_lance','prism_ward','stone_channel','phase_step','convergence_engine'];B=Image.new('RGBA',(192,32));d=ImageDraw.Draw(B)
    for i,n in enumerate(abs):
        x=i*32;d.rounded_rectangle((x+1,1,x+30,30),4,fill=col('#161a19'),outline=col(PAL['brass']),width=2);d.ellipse((x+7,7,x+25,25),outline=col(PAL['cyan'] if i<2 else PAL['violet']),width=2);d.line((x+8,24,x+24,8),fill=col(PAL['paper']),width=2)
    ui=['interact','locked','pending','success','failure','offline','friend','host','map','settings','accessibility','reset'];U=Image.new('RGBA',(192,16));d=ImageDraw.Draw(U)
    for i,n in enumerate(ui):
        x=i*16;d.rectangle((x,0,x+15,15),fill=col('#151918'),outline=col('#5c4a2a'));d.ellipse((x+4,4,x+11,11),outline=col(PAL['cyan']));d.point((x+8,8),fill=col(PAL['paper']))
    return E,B,U,abs,ui
def layout(at,reg):
    w,h=80,45; rows=[['water_0']*w for _ in range(h)]; wb=[[0]*w for _ in range(h)]
    for y in range(5,41):
      for x in range(4,48):
       if ((x-25)/22)**2+((y-23)/17)**2<=1: rows[y][x]='grass'
    for y in range(8,39):
      for x in range(47,78):
       if ((x-61)/16)**2+((y-23)/15)**2<=1: rows[y][x]='grass'
    for y in range(1,h-1):
      for x in range(1,w-1):
       if rows[y][x]!='water_0' and any(rows[y+dy][x+dx]=='water_0' for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))): rows[y][x]='shore_0';wb[y][x]=1
    for y in range(14,33):
      for x in range(13,37):
       if ((x-25)/12)**2+((y-23)/9)**2<=1: rows[y][x]='pale_stone'
    for y in range(18,29):
      for x in range(18,33):
       q=math.hypot(x-25,y-23); rows[y][x]='brass_plate' if 4.5<=q<=6.2 else ('water_3' if q<3.2 else rows[y][x])
    rows[23][25]='shrine_3'
    for y in range(21,26):
      for x in range(35,54): rows[y][x]='warm_path'
    for x in range(51,72): rows[12][x]='bridge_0';rows[34][x]='bridge_3'
    for y in range(12,35): rows[y][53]='warm_path';rows[y][70]='warm_path'
    for x in range(53,71): rows[23][x]='pale_stone'
    rows[23][63]='shrine_6'
    for y in range(15,22): rows[y][58]='cliff_1';rows[y][62]='cliff_2';wb[y][58]=wb[y][62]=1
    for x in range(57,68,3): rows[29][x]='device_2'
    for x,y in ((10,12),(12,34),(38,9),(42,35),(55,9),(74,17),(72,32)): rows[y][x]='vegetation_2'
    im=Image.new('RGBA',(1280,720),col(PAL['water']))
    for y,row in enumerate(rows):
      for x,n in enumerate(row):
        q=reg[n]['region'];im.alpha_composite(at.crop((q[0],q[1],q[0]+16,q[1]+16)),(x*16,y*16))
    d=ImageDraw.Draw(im);d.ellipse((342,326,458,410),outline=col(PAL['brass']),width=3);d.ellipse((368,346,432,390),outline=col(PAL['cyan']),width=2);sx,sy=1016,376;d.polygon([(sx,sy-55),(sx+22,sy+25),(sx-22,sy+25)],fill=col(PAL['bone']),outline=col(PAL['brass']));d.line((sx,sy-45,sx,sy+18),fill=col(PAL['cyan']),width=3)
    def rle(r):
      o=[];a=r[0];n=1
      for v in r[1:]:
       if v==a:n+=1
       else:o.append([a,n]);a=v;n=1
      o.append([a,n]);return o
    data={'schema_version':1,'id':'nexus-to-conservatory-visual-v1','authority':'presentation_only','tile_size':[16,16],'size_tiles':[80,45],'tileset':'res://assets/tiles/sanctum/sanctum_tiles_v1.png','rows_rle':[rle(r) for r in rows],'worldbone_mask_rows':[''.join('1' if v else '0' for v in r) for r in wb],'spawn':{'tile':[25,29],'district':'nexus-court'},'landmarks':[{'id':'nexus-fountain','tile':[25,23]},{'id':'conservatory-spire','tile':[63,23]}],'routes':[{'id':'ordinary-causeway','kind':'ordinary','from':[35,23],'to':[54,23]},{'id':'rail-causeway','kind':'advanced','from':[51,12],'to':[71,12]},{'id':'vault-slide-loop','kind':'advanced','from':[55,29],'to':[68,29]},{'id':'wall-kick-well','kind':'advanced','from':[60,21],'to':[60,15]}]}
    return im,data
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    r=Path(__file__).resolve().parents[2]
    for q in ['assets/sprites/skeletons/size_1_tiny','assets/sprites/skeletons/size_2_small','assets/sprites/skeletons/size_3_medium','assets/sprites/skeletons/size_4_large','assets/sprites/skeletons/size_5_huge','assets/sprites/champions/nico_lai','assets/tiles/sanctum','assets/tiles/materials','assets/icons','assets/maps/sanctum','build/visual-assets-v1']:
      p=r/q
      if p.exists(): shutil.rmtree(p) if p.is_dir() else p.unlink()
    ex=r/'build/visual-assets-v1/skeleton_animation_pngs'; zp=r/'assets/sprites/skeletons/skeleton_animation_pngs_v1.zip'
    for size in S:
      cl=atlas(size);db=atlas(size,debug=True);save(cl,r/f'assets/sprites/skeletons/{size}/skeleton_atlas.png');save(db,r/f'assets/sprites/skeletons/{size}/skeleton_overlay_debug_atlas.png')
      for an,(bx,by,n,fps) in A.items(): save(cl.crop((bx*192,by*256,bx*192+n*32,by*256+256)),ex/size/f'{an}.png')
    zp.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
      for p in sorted(ex.rglob('*.png')): z.write(p,p.relative_to(ex).as_posix())
    board=Image.new('RGBA',(960,640),col('#111514'))
    for si,size in enumerate(S):
      for di in range(8): board.alpha_composite(frame(size,'sprint',di,di%6,True).resize((96,96),Image.Resampling.NEAREST),(16+di*116,75+si*108))
    save(board,r/'assets/sprites/skeletons/skeleton_overlay_validation.png')
    ni=atlas('size_1_tiny',nico=True);nd=atlas('size_1_tiny',nico=True,debug=True);save(ni,r/'assets/sprites/champions/nico_lai/nico_lai_atlas.png');save(nd,r/'assets/sprites/champions/nico_lai/nico_lai_overlay_debug_atlas.png')
    pv=Image.new('RGBA',(1024,128),col('#141817'))
    for di in range(8): pv.alpha_composite(ni.crop((0,di*32,32,di*32+32)).resize((128,128),Image.Resampling.NEAREST),(di*128,0))
    save(pv,r/'assets/sprites/champions/nico_lai/nico_lai_direction_preview.png')
    ti,tr=tiles();save(ti,r/'assets/tiles/sanctum/sanctum_tiles_v1.png');mi,mn=material_icons();save(mi,r/'assets/tiles/materials/foundation_material_tiles_v1.png');ei,ai,ui,an,un=icon_sets();save(ei,r/'assets/icons/element_icons_v1.png');save(ai,r/'assets/icons/foundation_ability_icons_v1.png');save(ui,r/'assets/icons/ui_state_icons_v1.png');mp,md=layout(ti,tr);save(mp,r/'assets/maps/sanctum/nexus_to_conservatory_preview_v1.png');p=r/'content/maps/nexus_to_conservatory_visual_v1.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(md,indent=2)+'\n')
    reg={'schema_version':1,'id':'flux2-visual-assets-v1','generated_by':'tools/assets/generate_visual_assets_v1.py','character_contract':{'cell_size':[32,32],'pivot':[16,28],'directions':DIRS,'animation_manifest':'res://content/animations/skeleton_animation_manifest_v1.json'},'skeletons':{s:{'clean_atlas':f'res://assets/sprites/skeletons/{s}/skeleton_atlas.png','debug_atlas':f'res://assets/sprites/skeletons/{s}/skeleton_overlay_debug_atlas.png','body_height':v[0],'body_width':v[1]} for s,v in S.items()},'champions':{'nico_lai':{'status':'integrated_candidate','ancestry':'gnome','size':'size_1_tiny','atlas':'res://assets/sprites/champions/nico_lai/nico_lai_atlas.png','debug_atlas':'res://assets/sprites/champions/nico_lai/nico_lai_overlay_debug_atlas.png','direction_preview':'res://assets/sprites/champions/nico_lai/nico_lai_direction_preview.png','provenance':'original deterministic pixel construction'}},'environment':{'sanctum_tiles':{'path':'res://assets/tiles/sanctum/sanctum_tiles_v1.png','tile_size':[16,16],'tiles':tr},'nexus_to_conservatory':{'layout':'res://content/maps/nexus_to_conservatory_visual_v1.json','preview':'res://assets/maps/sanctum/nexus_to_conservatory_preview_v1.png'}},'materials':{'path':'res://assets/tiles/materials/foundation_material_tiles_v1.png','tile_size':[16,16],'order':mn},'icons':{'elements':{'path':'res://assets/icons/element_icons_v1.png','cell_size':[16,16],'order':['earth','fire','water','wind','ice','charge','light','dark']},'abilities':{'path':'res://assets/icons/foundation_ability_icons_v1.png','cell_size':[32,32],'order':an},'ui_states':{'path':'res://assets/icons/ui_state_icons_v1.png','cell_size':[16,16],'order':un}},'review':{'skeleton_validation':'res://assets/sprites/skeletons/skeleton_overlay_validation.png','singular_animation_archive':'res://assets/sprites/skeletons/skeleton_animation_pngs_v1.zip'},'license':'Project-original; repository license governs distribution.'};rp=r/'content/visual/visual_asset_registry_v1.json';rp.parent.mkdir(parents=True,exist_ok=True);rp.write_text(json.dumps(reg,indent=2)+'\n')
    fs=[]
    for root in [r/'assets',r/'content/visual',p]:
      fs += [root] if root.is_file() else [x for x in root.rglob('*') if x.is_file()]
    hm={'schema_version':1,'generator':'tools/assets/generate_visual_assets_v1.py','files':[{'path':x.relative_to(r).as_posix(),'bytes':x.stat().st_size,'sha256':digest(x)} for x in sorted(set(fs)) if x.suffix.lower() in ('.png','.zip','.json') and x.name!='visual_asset_hashes_v1.json' and 'concept' not in x.parts and 'reference' not in x.parts]};(r/'content/visual/visual_asset_hashes_v1.json').write_text(json.dumps(hm,indent=2)+'\n');print('generated',len(hm['files']),'assets')
if __name__=='__main__': main()
