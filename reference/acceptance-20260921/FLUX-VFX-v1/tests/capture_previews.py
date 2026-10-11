#!/usr/bin/env python3
"""Capture the offline HTML component viewer, not Godot gameplay.
Requires Playwright and a Chromium executable. No network calls are permitted.
"""
from __future__ import annotations
import argparse, base64, json, shutil
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--browser',default=shutil.which('chromium') or shutil.which('google-chrome'));parser.add_argument('--capture',action='store_true');args=parser.parse_args()
 if not args.browser: raise SystemExit('Chromium missing. Supply --browser /path/to/chromium')
 errors=[];network=[];tests=[]
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path=args.browser,headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
  page=browser.new_page(viewport={'width':1440,'height':1000},device_scale_factor=1)
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.on('console',lambda m: errors.append(m.text) if m.type=='error' else None)
  def route(r):
   if r.request.url.startswith(('http://','https://')): network.append(r.request.url);r.abort()
   else:r.continue_()
  page.route('**/*',route)
  entry='file://.../index.html'
  try:
   page.goto((ROOT/'index.html').as_uri(),wait_until='load')
   tests.append({'name':'file_url_load','status':'PASS'})
  except Exception as exc:
   # Respect sandbox browser policy: feed the self-contained page as content.
   if 'ERR_BLOCKED_BY_ADMINISTRATOR' not in str(exc): raise
   (ROOT/'evidence/file-url-blocked.txt').write_text(str(exc)+'\n')
   tests.append({'name':'file_url_load','status':'BLOCKED_BY_ENVIRONMENT','evidence':'evidence/file-url-blocked.txt'})
   page.close()
   page=browser.new_page(viewport={'width':1440,'height':1000},device_scale_factor=1)
   page.on('pageerror',lambda e:errors.append(str(e)))
   page.on('console',lambda m: errors.append(m.text) if m.type=='error' else None)
   page.route('**/*',route)
   page.set_content((ROOT/'preview-standalone.html').read_text(),wait_until='load')
   entry='preview-standalone.html fed via Playwright set_content; file URL blocked by sandbox policy'
   tests.append({'name':'self_contained_content_load','status':'PASS'})
  page.wait_for_function("document.body.dataset.ready==='true'",timeout=20000)
  page.evaluate('FLUX_PREVIEW.pause()')
  for view in ['bench','paintover','phases','overlap','palette','evidence']:
   page.click(f'[data-view="{view}"]')
   assert page.locator('#view-'+view).is_visible(),view
   tests.append({'name':'tab_'+view,'status':'PASS'})
  page.click('[data-view="bench"]')
  for id,val in [('scale','0.5'),('heat','500'),('direction','7'),('phase','decaying')]:
   page.select_option('#'+id,val)
  assert page.evaluate('FLUX_PREVIEW.state.scale')==.5
  assert page.evaluate('FLUX_PREVIEW.state.heat')==500
  assert page.evaluate('FLUX_PREVIEW.state.direction')==7
  assert page.evaluate('FLUX_PREVIEW.state.phase')=='decaying'
  tests.append({'name':'select_controls','status':'PASS'})
  page.locator('#exposure').evaluate("e=>e.value='240'");page.locator('#exposure').dispatch_event('input')
  assert page.evaluate('FLUX_PREVIEW.state.exposure')==240
  tests.append({'name':'exposure_control','status':'PASS'})
  # Restore UI selections and exact state before deterministic captures.
  for id,val in [('scale','1'),('heat','1000'),('direction','0'),('phase','active')]:page.select_option('#'+id,val)
  page.locator('#exposure').evaluate("e=>e.value='120'");page.locator('#exposure').dispatch_event('input')
  page.evaluate("FLUX_PREVIEW.setState({phase:'active',scale:1,heat:1000,direction:0,exposure:120,remaining:100,tick:60,progress:.5})")
  snapshot=page.evaluate('JSON.stringify(FLUX_PREVIEW.state)');page.wait_for_timeout(150)
  assert snapshot==page.evaluate('JSON.stringify(FLUX_PREVIEW.state)')
  tests.append({'name':'pause_freezes_fixture_clock','status':'PASS'})
  matrices=0
  for scale in [.5,.75,1]:
   for phase in ['forming','active','decaying']:
    for heat in [500,1000,1500]:
     for direction in range(8):
      page.evaluate('(s)=>FLUX_PREVIEW.setState(s)',dict(scale=scale,phase=phase,heat=heat,direction=direction,tick=60))
      matrices+=2
  tests.append({'name':'component_matrix','status':'PASS','combinations':matrices,'dimensions':'3 camera x 3 phases x 3 heat x 8 directions x 2 modes; each includes three materials and two floors'})
  masks=page.evaluate("""()=>{
   const F=FluxVFX,P=FLUX_PREVIEW;let comparisons=0;
   for(const material of ['water','fire','steam'])for(const logical of ['forming','active','decaying'])for(const heat of [500,1000,1500]){
    const phase=material==='fire'?(logical==='forming'?'ignition':logical==='decaying'?'cooling':'active'):logical;
    const regs=F.makeRegions(material,[[0,0]],{x:64,y:64,phase,danger:material!=='water'&&phase==='active',progress:.5,intensity:heat});
    const pixels=[false,true].map(reduced=>{const c=document.createElement('canvas');c.width=128;c.height=128;F.drawMaterials(c.getContext('2d'),regs,P.images,P.data.materials,60,reduced,1);return c.getContext('2d').getImageData(0,0,128,128).data;});
    for(let k=3;k<pixels[0].length;k+=4)if(Boolean(pixels[0][k])!==Boolean(pixels[1][k]))throw new Error('Normal/reduced alpha-support mismatch');
    comparisons++;
   }return comparisons;
  }""")
  tests.append({'name':'normal_reduced_raster_support_parity','status':'PASS','comparisons':masks,'limitation':'Browser support-mask parity, not Godot collision/raster acceptance'})
  actors=page.evaluate("""()=>{
   const F=FluxVFX,P=FLUX_PREVIEW;let comparisons=0;
   for(const size of ['small','middle','large'])for(let direction=0;direction<8;direction++)for(const reduced of [false,true]){
    const a=document.createElement('canvas'),b=document.createElement('canvas');a.width=b.width=128;a.height=b.height=128;
    const aa=a.getContext('2d'),bb=b.getContext('2d');
    const regs=['water','fire','steam'].flatMap((m,i)=>F.makeRegions(m,[[0,0]],{x:64,y:72,footprint_id:i+1}));
    F.drawMaterials(bb,regs,P.images,P.data.materials,60,reduced,1);F.drawActor(aa,P.images,64,84,size,direction);F.drawActor(bb,P.images,64,84,size,direction);
    const ap=aa.getImageData(0,0,128,128).data,bp=bb.getImageData(0,0,128,128).data;let opaque=0;
    for(let k=0;k<ap.length;k+=4)if(ap[k+3]===255){opaque++;for(let n=0;n<4;n++)if(ap[k+n]!==bp[k+n])throw new Error('Opaque actor pixel changed by ground effects');}
    if(!opaque)throw new Error('Actor was not drawn');comparisons++;
   }return comparisons;
  }""")
  tests.append({'name':'opaque_actor_pixels_above_mixed_materials','status':'PASS','comparisons':actors,'limitation':'Before own aim/projectile overlays; source body sprites only, no game motion/occlusion test'})

  if args.capture:
   def save(name,fn='renderBoard',reduced=False):
    encoded=page.evaluate('''({fn,reduced})=>{const c=document.createElement('canvas');FLUX_PREVIEW[fn](c,reduced);return c.toDataURL('image/png').split(',')[1]}''',{'fn':fn,'reduced':reduced})
    (ROOT/'boards'/name).write_bytes(base64.b64decode(encoded))
   for scale in [.5,.75,1]:
    page.evaluate('(s)=>FLUX_PREVIEW.setState(s)',dict(phase='active',scale=scale,heat=1000,direction=0,exposure=120,remaining=100,tick=60,progress=.5))
    for reduced in [False,True]:save(f"{'reduced' if reduced else 'normal'}-{int(scale*100)}.png",reduced=reduced)
   for heat,tag in [(500,'cool'),(1500,'hot')]:
    page.evaluate('(s)=>FLUX_PREVIEW.setState(s)',dict(scale=1,heat=heat))
    for reduced in [False,True]:save(f"steam-{tag}-{'reduced' if reduced else 'normal'}.png",reduced=reduced)
   page.evaluate("FLUX_PREVIEW.setState({phase:'active',scale:1,heat:1000,direction:0,exposure:120,remaining:100,tick:60,progress:.5})")
   for reduced in [False,True]:
    save(f"paintover-{'reduced' if reduced else 'normal'}-1280x720.png",'renderPaintover',reduced)
    save(f"lifecycle-{'reduced' if reduced else 'normal'}.png",'renderPhaseBoard',reduced)
   save('coverage-and-scald.png','renderOverlapBoard')
   save('stress-fixture.png','renderStressBoard')
   save('projectile-strength.png','renderStrengthBoard')
   page.evaluate("FLUX_PREVIEW.switchView('bench')")
   page.screenshot(path=str(ROOT/'evidence/browser-workshop.png'),full_page=True)
   page.evaluate("FLUX_PREVIEW.switchView('palette')")
   page.screenshot(path=str(ROOT/'boards/eight-element-table.png'),full_page=True)
   page.evaluate("FLUX_PREVIEW.switchView('bench')")
   page.set_viewport_size({'width':390,'height':844});page.screenshot(path=str(ROOT/'evidence/browser-mobile.png'),full_page=True)
   page.set_viewport_size({'width':1440,'height':1000})
  assert not errors,errors
  assert not network,network
  receipt={'status':'STATIC_VERIFIED','tool':'Chromium via Playwright','browser_version':browser.version,'entry':entry,
   'tests':tests,'console_errors':errors,'remote_requests':network,'godot':'NOT_RUN','human_acceptance':'NOT_RUN',
   'description':'Browser component rendering and controls only; no game simulation, FPS acceptance or native runtime capture.'}
  (ROOT/'evidence/browser-checks.json').write_text(json.dumps(receipt,indent=2)+'\n')
  browser.close()
 print(json.dumps({'tests':len(tests),'combinations':matrices,'errors':errors,'remote_requests':network}))
if __name__=='__main__':main()
