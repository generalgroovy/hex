#!/usr/bin/env python3
"""Verify this package's structure, exact source crops and reference addressing.
Requires Python >=3.10 and Pillow. No network or game execution. Optional --report
writes the offline result to evidence/verification.json. Manifest hashes are
checked when manifest.json exists; --pre-manifest skips that final hash pass.
"""
from pathlib import Path
import hashlib,json,sys,math,argparse
try:from PIL import Image
except ImportError:raise SystemExit('Pillow is required for image verification. No tests were run.')
sys.path.insert(0,str(Path(__file__).resolve().parent))
from presenter_reference import classify,region,frame
R=Path(__file__).resolve().parents[1]
checks=[]
def check(name,condition):
    checks.append({'name':name,'passed':bool(condition)})

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--report',action='store_true');parser.add_argument('--pre-manifest',action='store_true');args=parser.parse_args()
    if args.report and (R/'manifest.json').exists() and not args.pre_manifest:
        parser.error('--report would mutate a checksummed artifact; use no --report to verify a sealed package, or --report --pre-manifest before resealing it.')
    source=json.loads((R/'originals/manifest.json').read_text());spec=json.loads((R/'POSE_TIMING_SPEC.json').read_text());ims={};cells=0
    for size,d in source['sizes'].items():
        for bank in ['base','locomotion','sprint']:
            p=R/'originals'/f'{size}-{bank}.png';im=Image.open(p).convert('RGBA');ims[p.name]=im
            check(f'{p.name}: PNG hash',hashlib.sha256(p.read_bytes()).hexdigest()==d[bank+'_sha256'])
            check(f'{p.name}: RGBA hash',hashlib.sha256(im.tobytes()).hexdigest()==d[bank+'_rgba_sha256'])
            check(f'{p.name}: dimensions',list(im.size)==d[bank+'_dimensions'])
            alpha=im.getchannel('A');check(f'{p.name}: binary alpha',set(alpha.getextrema())<=set([0,255]) and all(v==0 for i,v in enumerate(alpha.histogram()) if i not in (0,255)))
            uniq={}
            for y in range(im.height//96):
                for x in range(im.width//96):
                    index=y*(im.width//96)+x;c=im.crop((x*96,y*96,x*96+96,y*96+96));b=c.getbbox();cells+=1
                    check(f'{p.name}: cell {index} nonempty and no outer-edge ink',b is not None and b[0]>0 and b[1]>0 and b[2]<96 and b[3]<96)
                    if bank!='base':uniq.setdefault(index//8,set()).add(hashlib.sha256(c.tobytes()).hexdigest())
            if bank!='base':check(f'{p.name}: all 64 pairs have 8 distinct phases',len(uniq)==64 and all(len(s)==8 for s in uniq.values()))
        b=ims[f'{size}-base.png'].crop((0,0,96,96)).getbbox()
        check(f'{size}: south standing height/pivot',b[3]-b[1]==spec['frozen']['display_height_px'][size] and b[3]==84)
    check('3312 source cells checked',cells==3312)
    regions=[region(t,a,p) for t in range(8) for a in range(8) for p in range(8)]
    check('D01 unique 512 regions',len(set(regions))==512)
    check('D01 last region',regions[-1]==(1440,2976,96,96))
    for bad in [(-1,0,0),(0,8,0),(0,0,8)]:check('invalid region '+str(bad),region(*bad) is None)
    for phi,want in [(0,0),(.124999,0),(.125,1),(.999999,7),(1,0),(-.125,7)]:check('D02 phase '+str(phi),frame('walk',(0,1000),(0,1000),phi)['phase']==want)
    for v in [float('nan'),float('inf'),-float('inf')]:
        check('D03 moving walk rejects '+str(v),frame('walk',(0,1000),(0,1000),v) is None)
        check('D03 slide ignores phase '+str(v),frame('slide',(0,1000),(707,-707),v)['bank']=='base')
    check('D04 zero travel base / aim fallback',frame('walk',(1000,0),(0,0),.75)=={'bank':'base','region':(192,384,96,96),'aim_index':2,'travel_index':2,'phase':0})
    for x,y,want in [(414214,1000000,0),(414215,1000000,1),(1000000,414214,2),(1000000,414215,1),(-414215,-1000000,5),(414215,-1000000,3),(-1000000,414215,7)]:check('D05/06 boundary '+str((x,y)),classify(x,y)==want)
    check('D07 zero aim defaults S',classify(0,0)==0);check('D07 invalid fallback S',classify(0,0,99)==0)
    slide=[frame('slide',(0,1000),(707,-707),p/8)['region'] for p in range(8)]
    check('D08 same slide S cell regardless phase',len(set(slide))==1 and slide[0]==(0,576,96,96))
    check('D09 cast direct base',frame('cast',(1000,0),(0,-1000),.375)['bank']=='base')
    check('D09 walk direct gait',frame('walk',(1000,0),(0,-1000),.375)['bank']=='locomotion')
    check('sprint own bank',frame('sprint_b',(1000,0),(0,-1000),.375)['bank']=='sprint')
    check('unknown landing state returns none',frame('landing',(0,1000),(0,0),0) is None)
    imf=json.loads((R/'pilots/image-manifest.json').read_text())
    for o in imf['outputs']:
        p=R/o['path'];check(o['path']+': recorded bytes/hash',p.stat().st_size==o['bytes'] and hashlib.sha256(p.read_bytes()).hexdigest()==o['sha256'])
        if 'crops' in o:
            im=Image.open(p).convert('RGBA');check(o['path']+': strip dimensions',im.size==(768,96))
            for i,c in enumerate(o['crops']):
                x,y,w,h=c['source_rect_xywh'];src=Image.open(R/c['source']).convert('RGBA').crop((x,y,x+w,y+h))
                got=im.crop((i*96,0,i*96+96,96));check(o['path']+f': exact crop {i}',src.tobytes()==got.tobytes())
    if (R/'manifest.json').exists() and not args.pre_manifest:
        m=json.loads((R/'manifest.json').read_text());paths=set()
        for o in m['outputs']:
            rel=Path(o['path']);safe=not rel.is_absolute() and '..' not in rel.parts;check(o['path']+': safe relative path',safe)
            if not safe:continue
            p=R/rel;paths.add(str(rel));check(o['path']+': manifest checksum',p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==o['sha256'] and p.stat().st_size==o['bytes'])
        actual={str(p.relative_to(R)) for p in R.rglob('*') if p.is_file() and p.relative_to(R).as_posix()!='manifest.json' and '__pycache__' not in p.parts}
        check('manifest contains every supplied output except itself',actual==paths)
    result={'status':'STATIC_VERIFIED' if all(c['passed'] for c in checks) else 'FAILED','scope':'Offline Python/Pillow checks and a source-math reference; NOT Godot or runtime verification','checks':len(checks),'passed':sum(c['passed'] for c in checks),'failed':[c for c in checks if not c['passed']],'source_cells_checked':cells,'source_pngs':9,'actual_game_tests':'NOT_RUN','human_acceptance':'PENDING','details':checks}
    if args.report:(R/'evidence/verification.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k!='details'},indent=2))
    return 0 if result['status']=='STATIC_VERIFIED' else 1
if __name__=='__main__':raise SystemExit(main())
