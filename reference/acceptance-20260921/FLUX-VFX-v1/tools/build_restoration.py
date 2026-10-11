#!/usr/bin/env python3
"""Rebuild the exact source-player/aim pixel restoration used in the paintover.
The hand-bounded alpha mask is an offline compositing aid, NOT a game mask.
"""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
source=Image.open(ROOT/'assets/reference_inputs/01-before-free-casts-1280x720.png').convert('RGBA')
mask=Image.new('L',source.size);d=ImageDraw.Draw(mask)
d.polygon([(635,376),(644,376),(648,383),(647,399),(644,405),(646,421),(641,426),(634,424),(634,409),(632,400),(631,386)],fill=255)
d.polygon([(620,399),(624,399),(622,412),(618,412)],fill=255)
d.polygon([(656,408),(664,407),(664,416),(658,423),(652,424),(653,420),(658,415)],fill=255)
d.line([(573,381),(592,362),(611,381),(592,399),(573,381)],fill=255,width=2)
result=Image.composite(source,Image.new('RGBA',source.size),mask)
result.save(ROOT/'assets/actors/source-player-aim-restoration.png',optimize=True)
print('Rebuilt source-pixel restoration; transparent RGB cleared.')
