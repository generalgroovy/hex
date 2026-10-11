#!/usr/bin/env python3
"""Build a self-contained preview; embeds CSS, JS and required PNG dependencies.
No font files, source modification, networking or third-party modules.
"""
from pathlib import Path
import base64,json,re
ROOT=Path(__file__).resolve().parents[1]
assets={str(p.relative_to(ROOT)).replace('\\','/'):'data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode() for p in (ROOT/'assets').rglob('*.png')}
s=(ROOT/'index.html').read_text()
s=s.replace('<link rel="stylesheet" href="preview/workshop.css">','<style>'+ (ROOT/'preview/workshop.css').read_text()+'</style>')
for name in ['data.js','renderer.js','app.js']:
 contents=(ROOT/'preview'/name).read_text()
 if name=='app.js': contents='window.FLUX_EMBEDDED_ASSETS='+json.dumps(assets,separators=(',',':'))+';\n'+contents
 s=s.replace(f'<script src="preview/{name}"></script>','<script>'+contents.replace('</script','<\\/script')+'</script>')
for path,uri in assets.items():s=s.replace('src="'+path+'"','src="'+uri+'"')
(ROOT/'preview-standalone.html').write_text(s)
print('Built preview-standalone.html,',len(assets),'embedded PNG dependencies')
