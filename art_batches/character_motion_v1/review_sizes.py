"""Render a compact comparison from already-built fullbody atlas records."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw
from build import digest

def review(folder):
    folder=Path(folder).resolve()
    if not folder.is_relative_to(Path(__file__).resolve().parent/'output'):
        raise ValueError('Review outside artwork output')
    manifest=json.loads((folder/'manifest.json').read_text())
    if not manifest.get('shared_head_policy'): raise ValueError('Requires shared-head build')
    ids=('s_wayne','oh_tipi','red_baron','wa_bidi','jan_wicked','fluup')
    result=Image.new('RGB',(960,750),'#ddd0b0')
    draw=ImageDraw.Draw(result)
    draw.text((18,15),'SHARED HEADS / BODY-LED SIZES / ART CANDIDATE',fill='#302b38')
    for index,id in enumerate(ids):
        character=next(c for c in manifest['characters'] if c['id']==id)
        path=folder/character['atlas']
        if digest(path)!=character['atlas_sha256']: raise ValueError('Atlas hash mismatch')
        layer=character['directions']['S']['layers']['fullbody']
        x,y,w,h=layer['rect']; ox,oy=layer['source_origin']
        with Image.open(path) as atlas: sprite=atlas.crop((x,y,x+w,y+h))
        frame=Image.new('RGBA',(128,128))
        if ox+16<0 or oy+20<0 or ox+16+w>128 or oy+20+h>128: raise ValueError('Review would clip')
        frame.paste(sprite,(round(ox+16),round(oy+20)))
        # Integer magnification for crisp source-pixel inspection.
        frame=frame.resize((256,256),Image.Resampling.NEAREST)
        cx=index%3*320+32;cy=index//3*342+45
        result.paste(frame,(cx,cy),frame)
        draw.text((cx,cy+265),character['display_name']+' / '+character['body'],fill='#302b38')
        draw.text((cx,cy+282),'18px skull target / body '+str({'small':58,'middle':63,'large':68}[character['body']])+'px',fill='#302b38')
    target=folder/'shared-head-size-comparison.png'
    if target.exists(): raise ValueError('Preserve existing review')
    result.save(target)
    print(target)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('folder')
    review(parser.parse_args().folder)
