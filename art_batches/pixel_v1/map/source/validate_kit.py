#!/usr/bin/env python3
"""Read-only independent checker for the delivered PNGs, manifest and seam scheme.
Python 3.10+ and Pillow. No imports from the generator, no network, no writes.
"""
from __future__ import annotations
import sys
sys.dont_write_bytecode = True
import hashlib, json, math, zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
BITS={'N':1,'E':2,'S':4,'W':8}
D={'N':(0,-1),'E':(1,0),'S':(0,1),'W':(-1,0)}
C={'NW':('N','W',-1,-1),'NE':('N','E',1,-1),'SE':('S','E',1,1),'SW':('S','W',-1,1)}


def require(condition,message):
    if not condition: raise AssertionError(message)


def main():
    m=json.loads((ROOT/'manifest.json').read_text())
    require(m['schema_version']==1 and m['contract_id']=='flux-pixel-assets-v1' and m['namespace']=='map','Wrong contract')
    require(m['tick_rate_hz']==120 and m['ground_cell_px']==[32,32],'Wrong grid or clock')
    require(m['usage_authority']['collision_authority'] is False,'Collision authority must stay false')
    palette=json.loads((ROOT/'source/palette.json').read_text())['colors']
    allowed={tuple(bytes.fromhex(c[1:]))+(255,) for c in palette.values()}
    require(hashlib.sha256((ROOT/'source/palette.json').read_bytes()).hexdigest()==m['palette']['sha256'],'Palette hash stale')
    counts=Counter(); ids=set(); decoded={}; atlas_images={}; transparent=0
    for at in m['atlases']:
        p=ROOT/at['path']; im=Image.open(p).convert('RGBA'); atlas_images[at['path']]=im
        require(list(im.size)==at['size_px'],'Atlas size mismatch')
        require(hashlib.sha256(im.tobytes()).hexdigest()==at['rgba_sha256'],'Atlas decoded hash mismatch')
    for a in m['assets']:
        require(a['id'].startswith('map.') and a['id'] not in ids,'Duplicate or non-namespaced asset')
        ids.add(a['id'])
        for k in ('path','frames','loop','pivot_px','layer_role','completion_status','tile_dimensions_px','connectors','autotile','visual_ground_footprint','occlusion_suggestions'):
            require(k in a,'Missing metadata field: '+k)
        p=(ROOT/a['path']).resolve(); require(p.is_relative_to(ROOT) and p.exists(),'Path not contained or missing')
        require(hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256'],'PNG checksum mismatch: '+a['id'])
        im=Image.open(p); require(im.mode=='RGBA','Not RGBA')
        colors=im.getcolors(im.width*im.height) or []
        require(all(v[3] in (0,255) for _,v in colors),'Soft alpha found')
        require(all(v in allowed for _,v in colors if v[3]),'Off-palette color found')
        if a['layer_role']=='terrain_base': require(im.getchannel('A').getextrema()==(255,255),'Terrain must be opaque')
        else: transparent+=int(im.getchannel('A').getextrema()[0]==0)
        fw,fh=a['frame_size_px']; require(fw%32==0 and fh%32==0,'Canvas not cell multiple')
        px,py=a['pivot_px']; require(0<=px<=fw and 0<=py<=fh,'Pivot outside frame')
        fx,fy,w,h=a['visual_ground_footprint']['rect_px']
        require(0<=fx and 0<=fy and fx+w<=fw and fy+h<=fh,'Footprint outside frame')
        require(a['visual_ground_footprint']['descriptive_only'] is True,'Footprint must be descriptive')
        require(len(a['frames'])==len(a['atlas_frames']),'Frame counts differ')
        for i,f in enumerate(a['frames']):
            x,y,w,h=f['rect']; require(x>=0 and y>=0 and w>0 and h>0 and x+w<=im.width and y+h<=im.height,'Invalid rect')
            require(isinstance(f['duration_ticks'],int) and f['duration_ticks']>0,'Invalid ticks')
            frame=im.crop((x,y,x+w,y+h)); af=a['atlas_frames'][i]; ax,ay,aw,ah=af['rect']; at=atlas_images[af['path']]
            require(frame.tobytes()==at.crop((ax,ay,ax+aw,ay+ah)).tobytes(),'Atlas content differs')
            # Verify the entire 2px edge extrusion and all four corners.
            for pad in (1,2):
                require(at.crop((ax-pad,ay,ax-pad+1,ay+h)).tobytes()==frame.crop((0,0,1,h)).tobytes(),'Left extrusion mismatch')
                require(at.crop((ax+w-1+pad,ay,ax+w+pad,ay+h)).tobytes()==frame.crop((w-1,0,w,h)).tobytes(),'Right extrusion mismatch')
                require(at.crop((ax,ay-pad,ax+w,ay-pad+1)).tobytes()==frame.crop((0,0,w,1)).tobytes(),'Top extrusion mismatch')
                require(at.crop((ax,ay+h-1+pad,ax+w,ay+h+pad)).tobytes()==frame.crop((0,h-1,w,h)).tobytes(),'Bottom extrusion mismatch')
            if i==0: decoded[a['id']]=frame
            counts['frame_checks']+=1
        counts['asset_checks']+=1
    families=m['autotile_scheme']['terrain_families']
    for fam in families:
        masks=[a['autotile']['mask'] for a in m['assets'] if a['autotile'] and a['autotile'].get('family')==fam and 'mask' in a['autotile']]
        require(sorted(masks)==list(range(16)),'Incomplete base coverage')
        for kind in ('convex','concave'):
            for corner in C: require(f'map.terrain.{fam}.corner_{kind}_{corner.lower()}' in ids,'Missing corner')
        # Enumerate ALL eight-neighbor signatures independently. The redundant
        # diagonals collapse to the familiar 47 effective binary topologies.
        topologies=set(); hashes=set()
        for signature in range(256):
            mask=signature&15; missing=signature>>4
            frame=decoded[f'map.terrain.{fam}.mask_{mask:02d}'].copy(); corner_bits=[]
            for j,(corner,(aa,bb,dx,dy)) in enumerate(C.items()):
                if mask&BITS[aa] and mask&BITS[bb] and missing&(1<<j):
                    corner_bits.append(corner); frame.alpha_composite(decoded[f'map.terrain.{fam}.corner_concave_{corner.lower()}'])
                elif not mask&BITS[aa] and not mask&BITS[bb]: frame.alpha_composite(decoded[f'map.terrain.{fam}.corner_convex_{corner.lower()}'])
            topologies.add((mask,tuple(corner_bits))); hashes.add(hashlib.sha256(frame.tobytes()).digest())
        require(len(topologies)==47 and len(hashes)==47,'Eight-neighbor topology coverage differs from expected 47')
        counts['eight_neighbor_signatures']+=256
        counts['unique_effective_topologies']+=47
    def tile(grid,x,y):
        fam=grid[y][x]; mask=0
        for d,(dx,dy) in D.items():
            xx,yy=x+dx,y+dy
            if 0<=xx<3 and 0<=yy<3 and grid[yy][xx]==fam:mask|=BITS[d]
        frame=decoded[f'map.terrain.{fam}.mask_{mask:02d}'].copy()
        for c,(aa,bb,dx,dy) in C.items():
            xx,yy=x+dx,y+dy
            diagonal=0<=xx<3 and 0<=yy<3 and grid[yy][xx]==fam
            if mask&BITS[aa] and mask&BITS[bb] and not diagonal: frame.alpha_composite(decoded[f'map.terrain.{fam}.corner_concave_{c.lower()}'])
            elif not mask&BITS[aa] and not mask&BITS[bb]:frame.alpha_composite(decoded[f'map.terrain.{fam}.corner_convex_{c.lower()}'])
        return frame
    for fam in families:
        other='earth' if fam!='earth' else 'paving'
        for signature in range(512):
            grid=[[fam if signature&(1<<(y*3+x)) else other for x in range(3)] for y in range(3)]
            tiles={(x,y):tile(grid,x,y) for y in range(3) for x in range(3)}
            for y in range(3):
                for x in range(3):
                    for dx,dy in ((1,0),(0,1)):
                        xx,yy=x+dx,y+dy
                        if xx>=3 or yy>=3 or grid[y][x]!=grid[yy][xx]:continue
                        a=tiles[x,y]; b=tiles[xx,yy]
                        if dx: edgea=a.crop((31,0,32,32)); edgeb=b.crop((0,0,1,32))
                        else: edgea=a.crop((0,31,32,32)); edgeb=b.crop((0,0,32,1))
                        require(edgea.tobytes()==edgeb.tobytes(),f'Export seam failed: {fam} / {signature}')
                        counts['full_export_edge_comparisons']+=1
    examples=json.loads((ROOT/'source/seam_examples.json').read_text()); require(len(examples)==20,'Missing mixed examples')
    for ex in examples:
        im=Image.open(ROOT/ex['path']); n=ex['size']; require(im.size==(n*32,n*32),'Wrong seam example dimensions')
    for f in ROOT.glob('source/*.ora'):
        with zipfile.ZipFile(f) as z:
            require(z.read('mimetype')==b'image/openraster','Wrong ORA mimetype')
            require(z.getinfo('mimetype').compress_type==zipfile.ZIP_STORED,'ORA mimetype must be stored')
            tree=ElementTree.fromstring(z.read('stack.xml'))
            for layer in tree.findall('.//layer'):require(layer.attrib['src'] in z.namelist(),'Missing ORA layer')
            counts['openraster_documents']+=1
    gif=Image.open(ROOT/'previews/ambient_loops.gif'); duration=0
    for i in range(gif.n_frames):gif.seek(i);duration+=gif.info.get('duration',0)
    common=math.lcm(*[sum(f['duration_ticks'] for f in a['frames']) for a in m['assets'] if a['loop']])
    require(duration==common*1000//120,'GIF does not end on common cycle boundary')
    counts['gif_period_ms']=duration
    require((ROOT/'previews/review.html').exists(),'Viewer missing')
    require(m['qa']['asset_count']==counts['asset_checks'] and m['qa']['frame_count']==counts['frame_checks'],'Manifest summary stale')
    print(json.dumps({'result':'PASS','checks':dict(counts),'shared_palette_verified':False,'production_integration_verified':False},indent=2))

if __name__=='__main__':
    try:main()
    except (AssertionError,KeyError,ValueError,OSError) as e:
        print('FAIL:',e,file=sys.stderr);raise SystemExit(1)
