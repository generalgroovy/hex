"""Versioned, two-part anatomical calibration of existing source layers.

User-authorized layered assembly, not new anatomy painted by an algorithm.
Head and body each have ONE isotropic identity scale for all source headings.
Flattened hidden anatomy and mask ownership remain visual-review candidates.
"""
import copy
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw
import head_contract
import layers

HERE = Path(__file__).resolve().parent


def load_calibration():
    return json.loads((HERE/'head_calibration.json').read_text())


def parameters(character, row):
    plan = head_contract.make_head_plan(row['cranial_bounds'])
    chin = row['cranial_bounds'][3]
    height = head_contract.BODY_HEIGHTS_PX[character['body']]
    body_scale = (height-plan['target_height_px'])/(84-chin)
    if not .5 < body_scale < 2: raise ValueError('Unreasonable below-chin scale')
    return plan, body_scale


def transform_layer(image, scale, source_pivot, target_pivot):
    box = image.getbbox()
    result = Image.new('RGBA', (128,128))
    if not box: return result
    crop = image.crop(box)
    size = tuple(max(1,round(n*scale)) for n in crop.size)
    crop = crop.resize(size,Image.Resampling.NEAREST)
    origin = tuple(round(target_pivot[i]+(box[i]-source_pivot[i])*scale)+[16,20][i] for i in range(2))
    bounds = crop.getbbox()
    if any(origin[i]+bounds[i]<0 or origin[i]+bounds[i+2]>128 for i in range(2)):
        raise ValueError('Reproportioning would clip source art; needs authored correction')
    result.paste(crop,origin)
    return result


def connected_registration(parts, head_scale, body_scale, center, chin, target_chin, half_width):
    """One inverse sampling map shared by every layer: no rounded-cut seams.

The central skull uses the fixed head scale. A narrow neck transition joins
it to the separately scaled body. Outer shoulder/wing pixels use body scale.
Only existing source pixels are sampled; no gap-fill colours are invented.
"""
    source=Image.new('RGBA',(96,96))
    owner={}
    for name,im in parts.items():
        source.alpha_composite(im)
        for y in range(96):
            for x in range(96):
                if im.getpixel((x,y))[3]: owner[x,y]=name
    output={name:Image.new('RGBA',(128,128)) for name in parts}
    for y in range(128):
        dy=y-20
        for x in range(128):
            dx=x-16
            distance=abs(dx-target_chin[0])/max(1,half_width*head_scale)
            weight=max(0,min(1,(1.7-distance)/.7)) if dy<target_chin[1] else 0
            weight=weight*weight*(3-2*weight)
            sy_scale=body_scale+(head_scale-body_scale)*weight
            neck_blend=max(0,min(1,(target_chin[1]-dy)/4))
            sx_scale=body_scale+(head_scale-body_scale)*weight*neck_blend
            sx=round(center+(dx-target_chin[0])/sx_scale)
            sy=round(chin+(dy-target_chin[1])/sy_scale)
            name=owner.get((sx,sy))
            if name: output[name].putpixel((x,y),source.getpixel((sx,sy)))
    return output


def apply(source, calibration=None):
    result=copy.deepcopy(source)
    row=(calibration or load_calibration())['characters'][source['character']['id']]
    if row['source_atlas_sha256']!=source['character']['atlas_sha256']:
        raise ValueError('Head calibration does not match source atlas')
    plan, body_scale=parameters(source['character'],row)
    front_chin=row['cranial_bounds'][3]
    receipt={'target_head_height':18,'source_head_height':plan['source_height_px'],
             'head_scale':plan['head_scale'],'body_scale':body_scale,
             'source_confidence':row['confidence'],'review_required':True,
             'policy':'two fixed isotropic scales per identity; never per-frame fitting'}
    for facing,view in result['directions'].items():
        geometry=row['facings'][facing]
        chin=geometry['recommended_head_mask_bottom_y']-1
        center=geometry['head_anchor'][0]
        # Measured chin closes the old jaw cut. Head attachments inside this
        # conservative envelope move with the head; outer wings/armor do not.
        half_width=max(row['source_cranial_width_px']/2+4,plan['source_height_px']*.82)
        if row['race'] in ('goblin','elf','nymph'): half_width*=1.28
        head=Image.new('RGBA',(96,96))
        visible=Image.new('RGBA',(96,96))
        for name in view['order']: visible.alpha_composite(view['layers'][name])
        count=0
        for y in range(96):
            for x in range(96):
                px=visible.getpixel((x,y))
                if not px[3]: continue
                is_head=y<=chin and abs(x-center)<=half_width
                current=next(name for name,im in view['layers'].items() if im.getpixel((x,y))[3])
                if is_head:
                    head.putpixel((x,y),px)
                    view['layers'][current].putpixel((x,y),(0,0,0,0))
                    count+=1
                elif current=='head':
                    view['layers']['head'].putpixel((x,y),(0,0,0,0))
                    destination='appendage_back' if row['race'] in layers.WING_RACES else 'torso'
                    view['layers'][destination].putpixel((x,y),px)
        view['layers']['head']=head
        reconstructed=Image.new('RGBA',(96,96))
        for name in view['order']: reconstructed.alpha_composite(view['layers'][name])
        if reconstructed.tobytes()!=visible.tobytes(): raise ValueError('Head repartition lost source pixels')
        target_chin=[48+(center-48)*body_scale,84+(chin-84)*body_scale]
        for name,im in view['layers'].items():
            # Conservative clipping preflight; all parts then share one pixel
            # registration map so independent trim rounding cannot open seams.
            transform_layer(im,plan['head_scale'],[center,chin],target_chin) if name=='head' else transform_layer(im,body_scale,[48,84],[48,84])
        view['layers']=connected_registration(view['layers'],plan['head_scale'],body_scale,center,chin,target_chin,half_width)
        if 'correction_underlays' in view:
            view['correction_underlays']={k:transform_layer(im,body_scale,[48,84],[48,84]) for k,im in view['correction_underlays'].items()}
        view['anchors']={k:[48+(p[0]-48)*body_scale,84+(p[1]-84)*body_scale] for k,p in view['anchors'].items()}
        view['anchors']['neck']=[target_chin[0],target_chin[1]+1]
        view['anchors']['head']=[target_chin[0],target_chin[1]-9]
        view['spec']['core_bounds']=[24,84-head_contract.BODY_HEIGHTS_PX[source['character']['body']],72,84]
        view['spec']['anchor_status']='common-head staged; directional mask review required'
        view['image_coordinate_offset']=[-16,-20]
        view['receipt']['shared_head']={**receipt,'source_pixels_repartitioned':count,'pre_scale_conservation':True}
    result['shared_head']=receipt
    return result


def review_board(sources, out):
    """Render final static layered composites, not invented motion frames."""
    ordered=sorted(sources,key=lambda s:(('small','middle','large').index(s['character']['body']),s['character']['display_name']))
    board=Image.new('RGB',(6*320,math.ceil(len(ordered)/6)*420),'#ddd0b0')
    draw=ImageDraw.Draw(board)
    for index,source in enumerate(ordered):
        view=source['directions']['S']; cell=Image.new('RGBA',(128,128))
        for name in view['order']: cell.alpha_composite(view['layers'][name])
        x,y=index%6*320,index//6*420
        enlarged=cell.resize((320,320),Image.Resampling.NEAREST)
        board.paste(enlarged,(x,y),enlarged)
        draw.text((x+10,y+338),source['character']['display_name'],fill='#302b38')
        draw.text((x+10,y+355),source['character']['body']+' / common 18px skull target',fill='#302b38')
    board.save(out)
