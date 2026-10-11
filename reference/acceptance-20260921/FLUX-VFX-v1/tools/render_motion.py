#!/usr/bin/env python3
"""Render a synthetic 120-Hz-reference lifecycle into two lossless APNGs.
15 sampled frames/s, 6.4 s loop. No Godot, live camera, damage or FPS claims.
"""
from pathlib import Path
from io import BytesIO
import base64,json,shutil
from PIL import Image
from playwright.sync_api import sync_playwright
R=Path(__file__).resolve().parents[1]
with sync_playwright() as p:
 executable=shutil.which('chromium') or shutil.which('google-chrome')
 if not executable:raise SystemExit('Chromium is required to rebuild this optional motion preview.')
 browser=p.chromium.launch(executable_path=executable,headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
 page=browser.new_page();errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.route('http://**/*',lambda r:r.abort());page.route('https://**/*',lambda r:r.abort())
 # This sandbox blocks file navigation. Content injection is explicitly recorded.
 page.set_content((R/'preview-standalone.html').read_text(),wait_until='load')
 page.wait_for_function("document.body.dataset.ready==='true'");page.evaluate('FLUX_PREVIEW.pause()')
 for reduced in [False,True]:
  frames=[]
  for i in range(96):
   b64=page.evaluate('''({tick,reduced})=>{
    FLUX_PREVIEW.setState({phase:'sequence',scale:1,heat:1000,direction:0,exposure:120,remaining:100,tick});
    const c=document.createElement('canvas');FLUX_PREVIEW.renderBoard(c,reduced);
    const ctx=c.getContext('2d');ctx.fillStyle='#101615';ctx.fillRect(28,78,1224,24);
    FluxVFX.label(ctx,`OFFLINE LIFECYCLE FIXTURE | t=${(tick/120).toFixed(3)}s | tick=${tick} | 120Hz reference / 15fps sampling | exposure input held at 120`,28,81,11);
    return c.toDataURL('image/png').split(',')[1];
   }''',{'tick':i*8,'reduced':reduced})
   frames.append(Image.open(BytesIO(base64.b64decode(b64))).convert('RGBA'))
  durations=[67,66,67]*32
  out=R/f"boards/pilot-lifecycle-{'reduced' if reduced else 'normal'}.apng"
  frames[0].save(out,format='PNG',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=0,blend=0,optimize=True)
  print(out.name,out.stat().st_size,'bytes')
 assert not errors,errors
 (R/'evidence/motion-preview.json').write_text(json.dumps({'status':'OFFLINE_PREVIEW','format':'APNG / RGBA','dimensions':[1280,720],
  'files':['boards/pilot-lifecycle-normal.apng','boards/pilot-lifecycle-reduced.apng'],'frames_per_file':96,'duration_ms':6400,
  'sampling':'tick = frame_index * 8; 120 Hz references; 15 fps samples; loop resets the fixture',
  'exposure':'manually supplied 120, not calculated from cloud age; glyph only during the containing test field danger',
  'entry':'self-contained HTML via Playwright set_content; sandbox file URL navigation is blocked',
  'javascript_errors':errors,'godot':'NOT_RUN','runtime_performance':'NOT_RUN','human_acceptance':'NOT_RUN'},indent=2)+'\n')
 browser.close()
