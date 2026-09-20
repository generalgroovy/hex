"""Standalone canvas player + pixel-scale PNG/GIF review evidence.

Preview backgrounds are flat material swatches, not new map/character assets.
No production renderer is invoked or modified by these illustrative scenes.
"""
from pathlib import Path
import json,base64,math
from PIL import Image,ImageDraw,ImageFont,ImageChops,ImageFilter
from geometry import fixture,sampled_mask,frame_index

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"previews"
MANIFEST=json.loads((ROOT/"manifest.json").read_text())
ASSETS={a["id"]:a for a in MANIFEST["assets"]}
ATLAS={a["path"]:Image.open(ROOT/a["path"]).convert("RGBA") for a in MANIFEST["atlases"]}
RECIPES={r["id"]:r for r in MANIFEST["reactions"]}
BG={"stone":"#98805a","dark":"#202b2b"}
FONT=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",14)
SMALL=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",12)
TITLE=ImageFont.truetype("C:/Windows/Fonts/consolab.ttf",23)

def sprite(key,tick=0,variant="normal"):
    a=ASSETS["magic."+key+"."+variant]
    index=frame_index(a,tick)
    if index is None:return Image.new("RGBA",tuple(a["frame_size_px"])),a["pivot_px"]
    f=a["frames"][index];x,y,w,h=f["rect"]
    return ATLAS[a["path"]].crop((x,y,x+w,y+h)),a["pivot_px"]

def paste(dst,key,xy,tick=0,variant="normal",scale=1,opacity=1):
    im,pivot=sprite(key,tick,variant)
    if opacity!=1:im.putalpha(im.getchannel("A").point(lambda a:round(a*opacity)))
    if scale!=1:im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
    dst.alpha_composite(im,(round(xy[0]-pivot[0]*scale),round(xy[1]-pivot[1]*scale)))

def backdrop(size,ground):
    im=Image.new("RGBA",size,BG[ground]);d=ImageDraw.Draw(im)
    grid="#917952" if ground=="stone" else "#273231"
    for x in range(0,size[0],32):d.line((x,0,x,size[1]),fill=grid)
    for y in range(0,size[1],32):d.line((0,y,size[0],y),fill=grid)
    return im

def reaction_image(rid,tick,variant="normal",size=(320,256)):
    r=RECIPES[rid];s=fixture(r,tick)
    # Follow a moving origin only in gallery cells; motion demo draws separate
    # coordinate ticks so this never claims an unmoving gameplay footprint.
    sx,sy=s["position"]
    origin=(-40+sx/1000,-size[1]/2+sy/1000)
    if r["shape"] not in ["front","corridor","growing_strip","pulse_lane","bands","reveal_line","branch","water_path","frost_path"]:
        origin=(-size[0]/2+sx/1000,-size[1]/2+sy/1000)
    mask=sampled_mask(s,tick,*size,origin)
    phase="formation" if tick<s["active_tick"] else "active" if tick<s["decay_tick"] else "decay"
    elapsed=tick-({"formation":0,"active":s["active_tick"],"decay":s["decay_tick"]}[phase])
    mat=Image.new("RGBA",size)
    gap=48 if variant=="reduced" else 24
    for y in range(12,size[1],gap):
        for x in range(12,size[0],gap):
            paste(mat,"reaction."+rid+"."+phase,(x,y),elapsed+(x//gap%2)*10,variant)
    if r["shape"] in ["cover","plane","lens"]:
        cx=round(sx/1000-origin[0]);cy=round(sy/1000-origin[1])
        for yy in range(round(cy-r["nominal_length_px"]/2),round(cy+r["nominal_length_px"]/2)+1,16):
            paste(mat,"reaction."+rid+"."+phase,(cx,yy+6),elapsed,variant)
    alpha=ImageChops.multiply(mat.getchannel("A"),mask).point(lambda a:round(a*(0.46 if variant=="normal" else .30)))
    mat.putalpha(alpha)
    # Four-neighbour integer edge, exact pixel-centre occupancy mask. No circles
    # are used as decoration and inner ring holes remain completely empty.
    edge=ImageChops.subtract(mask,mask.filter(ImageFilter.MinFilter(3)))
    if phase=="formation":
        dash=Image.new("L",size);dash.putdata([255 if (x+y)//4%2==0 else 0 for y in range(size[1]) for x in range(size[0])]);edge=ImageChops.multiply(edge,dash)
    palette=ASSETS["magic.reaction."+rid+"."+phase+"."+variant]["palette_rgba"]
    edge_color=tuple(bytes.fromhex(palette[4]))
    edge_im=Image.new("RGBA",size,edge_color);edge_im.putalpha(edge)
    mat.alpha_composite(edge_im)
    return mat

def static_sheets():
    for ground in BG:
        im=backdrop((1240,700),ground);d=ImageDraw.Draw(im)
        d.rectangle((0,0,1240,72),fill="#142126")
        d.text((24,16),"FLUX / MAGIC CANDIDATES",font=TITLE,fill="#fff1c7")
        d.text((24,46),"1x world scale  |  separate 4x pose inspection  |  authored pixel frames, not runtime acceptance",font=SMALL,fill="#b9c4bc")
        cols=["hand_prepare","hand_release","flight","impact","deposit_active","beam_body","spray_grain","field_tile"]
        for i,key in enumerate(cols):d.text((172+i*128,89),key.replace("hand_","").replace("deposit_",""),font=SMALL,fill="#fff1c7")
        for j,e in enumerate(["fire","water","earth","wind","ice","charge","light","dark"]):
            y=145+j*66;d.text((24,y-12),e.upper(),font=FONT,fill="#fff1c7")
            for i,key in enumerate(cols):
                paste(im,e+"."+key,(196+i*128,y),12)
                if key=="flight":paste(im,e+"."+key,(252+i*128,y),12,scale=2)
        im.save(OUT/f"element_coverage_{ground}.png")
    rids=list(RECIPES)
    for page in range(6):
        im=backdrop((1100,660),"dark");d=ImageDraw.Draw(im)
        d.rectangle((0,0,1100,64),fill="#142126")
        d.text((20,14),f"CHEMISTRY {page+1}/6 / CURRENT SOURCE SHAPES",font=TITLE,fill="#fff1c7")
        d.text((20,42),"1x pixels / active phase / empty-world coverage masks / material modules are clipped",font=SMALL,fill="#b9c4bc")
        for idx,rid in enumerate(rids[page*6:page*6+6]):
            x=idx%3*365+8;y=idx//3*290+72;r=RECIPES[rid]
            d.text((x+12,y),f"{r['wire_id']} {rid}",font=FONT,fill="#fff1c7")
            d.text((x+12,y+22),r["shape"],font=SMALL,fill="#adc4b8")
            im.alpha_composite(reaction_image(rid,r["formation_ticks"]+min(96,r["active_ticks"]//2)),(x+12,y+29))
        im.save(OUT/f"reaction_coverage_{page+1:02}.png")
    # Large key poses make pixel cluster and registration review independent
    # of swatch contrast, while retaining an actual size row underneath.
    im=backdrop((1000,590),"dark");d=ImageDraw.Draw(im)
    for row,key in enumerate(["fire.flight","water.flight","reaction.steam.active"]):
        y=30+row*190;d.text((20,y),key+" / all 4 key poses at 4x",font=FONT,fill="#fff1c7")
        a=ASSETS["magic."+key+".normal"];age=0
        for f in range(4):
            xy=(130+f*215,y+122);paste(im,key,xy,age,scale=4)
            d.line((xy[0]-5,xy[1],xy[0]+5,xy[1]),fill="#98805a")
            d.text((xy[0]-42,y+156),str(a["frames"][f]["duration_ticks"])+" ticks",font=SMALL,fill="#b9c4bc")
            age+=a["frames"][f]["duration_ticks"]
    im.save(OUT/"representative_keyposes.png")

def representative_gifs():
    for ground in BG:
        for variant in ["normal","reduced"]:
            frames=[]
            for frame in range(72):
                tick=frame*6;im=backdrop((880,400),ground);d=ImageDraw.Draw(im)
                d.rectangle((0,0,880,67),fill="#142126")
                d.text((20,12),f"FIRE / WATER / STEAM - {variant.upper()}",font=TITLE,fill="#fff1c7")
                d.text((20,43),"Candidate motion fixture / 1x native pixels / frames at 120 Hz ticks / no gameplay changes",font=SMALL,fill="#b9c4bc")
                for idx,e in enumerate(["fire","water"]):
                    y=135+idx*135;phase=tick%144
                    d.text((18,y-32),e.upper(),font=FONT,fill="#fff1c7")
                    if phase<32:paste(im,e+".hand_prepare",(110,y),phase,variant)
                    elif phase<62:paste(im,e+".hand_release",(110,y),phase-32,variant)
                    if 35<=phase<88:
                        x=110+(phase-35)*3.1
                        paste(im,e+".flight_tail",(x-20,y),tick,variant,opacity=.38)
                        paste(im,e+".flight",(x,y),tick,variant)
                    if 88<=phase<131:paste(im,e+".impact",(275,y),phase-88,variant)
                    if phase>=98:paste(im,e+".deposit_active",(275,y),phase-98,variant)
                    # Separate, larger source-pose sample clearly labelled.
                    paste(im,e+".flight",(390,y),tick,variant,scale=3)
                    d.text((358,y+42),"3x detail",font=SMALL,fill="#fff1c7")
                r=RECIPES["steam"];rtick=tick%(r["formation_ticks"]+r["active_ticks"]+r["decay_ticks"])
                im.alpha_composite(reaction_image("steam",rtick,variant,size=(300,270)),(550,87))
                d.text((580,354),"Steam: actual 30 -> 90 px radius",font=SMALL,fill="#fff1c7")
                frames.append(im.convert("RGB"))
            frames[0].save(OUT/f"representative_{ground}_{variant}.gif",save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=False,disposal=2)

def main():
    OUT.mkdir(exist_ok=True)
    static_sheets();representative_gifs()
    data=dict(manifest=MANIFEST,atlases={p:"data:image/png;base64,"+base64.b64encode((ROOT/p).read_bytes()).decode() for p in ATLAS})
    template=(ROOT/"source/player.html").read_text(encoding="utf-8")
    (OUT/"index.html").write_text(template.replace("/*PACK_DATA*/", "const PACK="+json.dumps(data,separators=(",",":"))+";"),encoding="utf-8",newline="\n")
    print("PREVIEWS: 9 PNG sheets, 4 animated GIFs, standalone interactive atlas player")

if __name__=="__main__":main()
