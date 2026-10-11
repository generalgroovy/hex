"""Build review-only articulated cast atlases; no production replacement.

The user explicitly authorized body-part separation and skeletal assembly.
Original raster artwork remains untouched. Source pixel ownership is checked
before scaling. Motion coverage is not equivalent to accepted character art.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw
import layers
import poses
import corrections
import shared_heads

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def digest(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, data): Path(path).write_text(json.dumps(data, separators=(',',':'))+'\n', encoding='utf-8')

def core_scale(character, source):
    """One anatomical scale for every facing/pose, excluding decorated silhouette."""
    spec = source['directions']['S']['spec']
    bounds = spec['core_bounds']
    span = float(bounds[3])-float(bounds[1])
    if not 25 <= span <= 84: raise ValueError('Invalid anatomical calibration')
    target = {'small':58,'middle':63,'large':68}[character['body']]
    return target/span, spec.get('anchor_status','heuristic_source_partition_not_accepted')

def pack_character(source, out):
    char = source['character']
    scale, calibration = core_scale(char, source)
    atlas = Image.new('RGBA',(512,2048))
    x=y=2
    row=0
    records={}
    for facing, view in source['directions'].items():
        image_offset=view.get('image_coordinate_offset',[0,0])
        image_size=next(iter(view['layers'].values())).size
        # The same single character scale applies to all original pixel layers.
        anchors={k:[48+(p[0]-48)*scale,84+(p[1]-84)*scale] for k,p in view['anchors'].items()}
        entry={'anchors':anchors,'layers':{},'order':view['order'], 'review_required':True,
               'conservation':view['receipt']}
        visible=Image.new('RGBA',image_size)
        for layer_name in view['order']: visible.alpha_composite(view['layers'][layer_name])
        images={**{'correction__'+k:v for k,v in view.get('correction_underlays',{}).items()},**view['layers'],'fullbody':visible}
        for name, image in images.items():
            box=image.getchannel('A').getbbox()
            if box is None: continue
            crop=image.crop(box)
            size=(max(1,round(crop.width*scale)),max(1,round(crop.height*scale)))
            crop=crop.resize(size,Image.Resampling.NEAREST)
            if x+crop.width+2>512: x=2; y+=row+4; row=0
            if y+crop.height+2>2048: raise ValueError('Layer atlas overflow')
            atlas.paste(crop,(x,y))
            origin=[round(48+(box[0]+image_offset[0]-48)*scale),round(84+(box[1]+image_offset[1]-84)*scale)]
            entry['layers'][name]={'rect':[x,y,crop.width,crop.height], 'source_origin':origin,
                                   'binding':view['bindings'].get(name.removeprefix('correction__'),['pelvis','neck'])}
            if name=='fullbody':
                entry['layers'][name]['unscaled_bounds']=list(box)
            row=max(row,crop.height); x+=crop.width+4
        records[facing]=entry
        # A connected textured cage preserves garment continuity; rigid layers
        # remain available for explicit overlap/correction review. No repainting.
        owner={}
        for name,image in view['layers'].items():
            for py in range(image_size[1]):
                for px in range(image_size[0]):
                    if image.getpixel((px,py))[3]: owner[(px+image_offset[0],py+image_offset[1])]=name
        vertices=[]
        for gy in range(17):
            for gx in range(17):
                sx,sy=gx*image_size[0]/16+image_offset[0],gy*image_size[1]/16+image_offset[1]
                counts={}
                for dy in range(-5,6):
                    for dx in range(-5,6):
                        name=owner.get((sx+dx,sy+dy))
                        if name: counts[name]=counts.get(name,0)+1/(1+dx*dx+dy*dy)
                if not counts:
                    counts={'torso':1.0}
                chosen=sorted(counts,key=counts.get,reverse=True)[:2]
                if len(chosen)==1: chosen.append(chosen[0])
                weight=1.0 if chosen[0]==chosen[1] else counts[chosen[0]]/(counts[chosen[0]]+counts[chosen[1]])
                vertices.append({'point':[48+(sx-48)*scale,84+(sy-84)*scale],
                                 'parts':chosen,'weight':weight})
        entry['mesh_vertices']=vertices
    height=2**math.ceil(math.log2(max(32,y+row+2)))
    atlas=atlas.crop((0,0,512,height))
    path=out/(char['id']+'.png'); atlas.save(path)
    return {'id':char['id'],'display_name':char['display_name'],'body':char['body'], 'race':char['race'],
            'atlas':path.name,'atlas_sha256':digest(path),'atlas_dimensions':list(atlas.size),
            'anatomical_scale':scale,'calibration_status':calibration,'directions':records,
            'review_required':True,'hidden_surface_status':'correction_art_required_where_revealed'}

def make_bank():
    contract=json.loads((HERE/'motion_contract.json').read_text())
    actions={}
    for clip in contract['clips']:
        if clip['priority']!=1: continue
        action=clip['id']
        actions[action]={'loop':clip['loop'],'fps':clip['preview_fps'],
                         'travel_facing':action in ('slide','roll','air_dodge','wavedash','wallrun'),
                         'travel_matrix':action in ('walk','sprint','wallrun'),
                         'frames':max(8,clip['frames_proposed'])}
    result={'schema_version':1,'actions':actions,'bodies':{},'production_ready':False,
            'phase_policy':'preview clocks only; gameplay integration must use authoritative accepted-action and distance clocks'}
    for body in ('small','middle','large'):
        rests={}
        for aim in range(8):
            sample=poses.rest(body,aim)
            rests[str(aim)]={k:[round(v,4) for v in p] for k,p in sample['points'].items()}
        bank={}
        for action, clip in actions.items():
            for aim in range(8):
                for travel in (range(8) if clip['travel_matrix'] else [aim]):
                    frames=[]
                    for index in range(clip['frames']):
                        phase=index/(clip['frames'] if clip['loop'] else clip['frames']-1)
                        sample=poses.pose(body,action,aim,travel,phase)
                        points={k:[round(v,4) for v in p] for k,p in sample['points'].items()}
                        order=[]
                        torso_depth=sample.get('torso_depth',0)
                        ordered_chains=sample.get('chains',[])
                        for front in (False,True):
                            if front: order.append('torso')
                            for chain in ordered_chains:
                                if (chain.get('depth',0)>torso_depth)!=front: continue
                                side=chain['side']
                                parts=('thigh','shin','foot') if chain['kind']=='leg' else ('upper_arm','forearm','hand')
                                order.extend(p+'_'+side for p in parts)
                        frames.append({'points':points, 'order':order, 'contacts':sample.get('contacts',{})})
                    bank[f'{action}/{aim}/{travel}']=frames
        result['bodies'][body]={'rest':rests,'clips':bank}
    return result

def build(out, ids=None, common_heads=False):
    out=Path(out).resolve()
    if not out.is_relative_to((HERE/'output').resolve()) or out.exists():
        raise ValueError('Use a fresh contained output directory')
    manifest=json.loads(layers.DEFAULT_MANIFEST.read_text())
    selected=[c for c in manifest['characters'] if ids is None or c['id'] in ids]
    if not selected or (ids is not None and len(selected)!=len(set(ids))): raise ValueError('Unknown IDs')
    # Finish all expensive validation before creating the output folder.
    bank=make_bank()
    out.mkdir(parents=True)
    (out/'.gdignore').touch()
    save(out/'motion-bank.json',bank)
    result={'schema_version':1,'factory':'articulated_fullbody_candidate_v1','cell':[128,128], 'pivot':[64,104],
            'directions':list(layers.DIRECTIONS), 'production_ready':False,'human_approved':False,
            'motion_bank':'motion-bank.json','motion_bank_sha256':digest(out/'motion-bank.json'),
            'source_manifest_sha256':digest(layers.DEFAULT_MANIFEST),
            'generator_inputs':{str(p.relative_to(ROOT)):digest(p) for p in
                (HERE/'build.py',HERE/'poses.py',HERE/'layers.py',HERE/'corrections.py',
                 HERE/'s-wayne-corrections.recipe.json',HERE/'reference/s-wayne-components-v1.png',
                 HERE/'motion_contract.json',HERE/'proportions.json',
                 HERE/'calibration_overrides.json',HERE/'shared_heads.py',HERE/'head_contract.py',HERE/'head_calibration.json',ROOT/'art_batches/character_volume_v1/volume.py',
                 ROOT/'art_batches/character_style_v1/wireframe_motion_v2/rig-data.json') if p.exists()},
            'characters':[], 'shared_head_policy':bool(common_heads),
            'limitations':['Procedural articulated animation, not individually hand-drawn frames.',
                           'Automatic partitions require per-character visual review and hidden-joint corrections.',
                           'No runtime production integration or gameplay timing changes.']}
    normalized_sources=[]
    for char in selected:
        source=layers.load_character(char['id'])
        if char['id']=='s_wayne':
            source['directions']={direction:corrections.apply_corrections(view,direction) for direction,view in source['directions'].items()}
        if common_heads:
            source=shared_heads.apply(source)
            normalized_sources.append(source)
        result['characters'].append(pack_character(source,out))
        if common_heads: result['characters'][-1]['shared_head']=source['shared_head']
        print('Built articulated candidate '+char['id'],flush=True)
    save(out/'manifest.json',result)
    if normalized_sources: shared_heads.review_board(normalized_sources,out/'shared-head-roster.png')
    receipt={'characters':len(selected),'authored_source_views':len(selected)*8,'actions':len(bank['actions']),
             'shared_motion_samples':sum(len(frames) for b in bank['bodies'].values() for frames in b['clips'].values()),
             'max_atlas_rgba_bytes':max(math.prod(c['atlas_dimensions'])*4 for c in result['characters']),
             'production_ready':False,'visual_acceptance':False,'status':'candidate_built'}
    save(out/'receipt.json',receipt)
    return receipt

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',required=True); parser.add_argument('--characters',nargs='*')
    parser.add_argument('--common-heads',action='store_true')
    args=parser.parse_args()
    print(json.dumps(build(args.out,args.characters,args.common_heads),indent=2))
