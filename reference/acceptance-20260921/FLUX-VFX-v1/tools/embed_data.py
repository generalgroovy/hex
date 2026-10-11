#!/usr/bin/env python3
"""Embed authored JSON for a file://-safe preview. Python standard library only."""
import json
from pathlib import Path
r=Path(__file__).resolve().parents[1]
data={n:json.loads((r/p).read_text()) for n,p in [('palette','definitions/palette.json'),('materials','definitions/materials.proposed.json'),('atlas','definitions/atlas-layout.json')]}
(r/'preview/data.js').write_text('/* Embedded data: no fetch or web dependency. Rebuild with tools/embed_data.py. */\nwindow.FLUX_DATA='+json.dumps(data,separators=(',',':'))+';\n')
