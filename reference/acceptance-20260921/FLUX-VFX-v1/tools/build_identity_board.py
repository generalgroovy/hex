#!/usr/bin/env python3
"""Render diagnostic identity/grayscale PNGs. Uses local system fonts as pixels,
not redistributed font files. Pillow is a build-only dependency.
"""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont,ImageOps
R=Path(__file__).resolve().parents[1]
font=lambda size:ImageFont.truetype('DejaVuSansMono.ttf',size)
serif=lambda size:ImageFont.truetype('DejaVuSerif.ttf',size)
palette=json.loads((R/'definitions/palette.json').read_text())
im=Image.new('RGB',(1280,490),'#101615');d=ImageDraw.Draw(im)
d.text((28,20),'FLUX / IDENTITY WITHOUT COLOR',font=serif(26),fill='#fff0c6')
d.text((28,64),'OFFLINE_PREVIEW — eight elements; Steam is a separate reaction. No color-vision or human acceptance claimed.',font=font(12),fill='#c5ad79')
d.line((28,98,1252,98),fill='#634117')
shapes=['hooked crest','chipped blocks','unequal forks','open spiral','six-point facet','angular snap','diamond','inward crescent']
for i,e in enumerate(palette['elements']):
 x=28+i*154
 d.rectangle((x,118,x+141,405),fill='#1b2421',outline='#57452b')
 icon=Image.open(R/e['icon']).convert('RGBA');im.paste(icon,(x+47,143),icon)
 d.text((x+10,206),e['display_name'],font=serif(18),fill='#fff0c6')
 for n,c in enumerate(e['palette'].values()):d.rectangle((x+10+n*39,240,x+47+n*39,253),fill=c)
 gray=ImageOps.grayscale(icon).convert('RGBA');gray.putalpha(icon.getchannel('A'));im.paste(gray,(x+47,278),gray)
 d.text((x+7,352),shapes[i],font=font(10),fill='#c5ad79')
 d.text((x+7,376),'id: '+e['id'],font=font(10),fill='#9b987f')
d.text((28,438),'Color reinforces identity. Curvature, mass, open space and motion still do the identifying work.',font=font(12),fill='#c5ad79')
im.save(R/'boards/element-identity-color-grayscale.png',optimize=True)
for mode in ['normal','reduced']:
 src=Image.open(R/f'boards/{mode}-100.png').convert('RGB');out=ImageOps.grayscale(src).convert('RGB');dd=ImageDraw.Draw(out)
 dd.rectangle((27,78,1251,103),fill='#171717')
 dd.text((28,81),'OFFLINE GRAYSCALE DIAGNOSTIC / native 100% fixture / not a color-vision certification',font=font(12),fill='#dedede')
 out.save(R/f'boards/grayscale-{mode}-100.png',optimize=True)
print('Built identity + two grayscale diagnostic boards.')
