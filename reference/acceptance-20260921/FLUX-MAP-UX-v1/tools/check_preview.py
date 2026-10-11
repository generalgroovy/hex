"""Exercise the offline HTML, not the game. Requires Playwright and a Chromium binary."""
import json,shutil,base64
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];results=[];errors=[];requests=[]
def record(name,ok,detail=None):results.append({'name':name,'status':'PASS' if ok else 'FAIL','detail':detail})
html=(ROOT/'preview/index.html').read_text()
assets={f.name:'data:image/png;base64,'+base64.b64encode(f.read_bytes()).decode() for f in (ROOT/'artifacts').glob('*.png')}
html=html.replace('<script>','<script>const ART='+json.dumps(assets)+';')
html=html.replace("'../artifacts/'+r[0]","ART[r[0]]").replace("'../artifacts/04-native-'+b.dataset.effects+'-1280x720.png'","ART['04-native-'+b.dataset.effects+'-1280x720.png']")
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=shutil.which('chromium') or shutil.which('chromium-browser'),headless=True,args=['--no-sandbox'])
 page=browser.new_page(viewport={'width':1280,'height':720},device_scale_factor=1)
 page.on('pageerror',lambda e:errors.append(str(e)));page.on('request',lambda r:requests.append(r.url))
 page.set_content(html);page.wait_for_selector('#matrix button')
 record('64-reaction-cells',page.locator('#matrix button').count()==64)
 record('36-unordered-names',page.evaluate('names.size')==36)
 record('steam-default',page.locator('#detail').inner_text().find('Steam')>=0)
 page.screenshot(path=str(ROOT/'artifacts/07-ui-reference-1280x720.png'),full_page=False)
 page.click('[data-a="Fire"][data-b="Water"]');one=page.locator('#detail').inner_text();page.click('[data-a="Water"][data-b="Fire"]');record('symmetric-first-four-details',one==page.locator('#detail').inner_text())
 page.click('[data-a="Dark"][data-b="Charge"]');record('later-four-not-false-lock', 'not audited' in page.locator('#detail').inner_text())
 page.keyboard.down('Control');record('ctrl-layer',page.evaluate('layer')=='ctrl');page.keyboard.down('Alt');record('alt-wins-both',page.evaluate('layer')=='alt');page.keyboard.up('Alt');record('return-to-ctrl',page.evaluate('layer')=='ctrl');page.keyboard.up('Control');record('return-to-plain',page.evaluate('layer')=='plain')
 page.keyboard.press('Escape');record('escape-closes-panel',page.locator('#closed').is_visible());page.keyboard.press('F4');record('f4-opens-panel',page.locator('#panel').is_visible())
 page.click('[data-tab="movement"]');record('modern-bindings', 'evade/air dodge' in page.locator('#movement').inner_text() and 'Q is free' in page.locator('#movement').inner_text())
 page.click('[data-tab="company"]');page.click('#join');record('join-not-acknowledged', 'pending' in page.locator('#connection').inner_text());page.click('#ack');record('mock-ack-explicit-offline', 'still offline' in page.locator('#connection').inner_text());page.click('#ready');record('ready-pending', 'no acknowledgement yet' in page.locator('#connection').inner_text())
 page.click('#selectPeer');record('select-not-dismiss',page.locator('#confirm').is_disabled());page.click('#arm');record('explicit-confirm-arm',page.locator('#confirm').is_enabled());page.wait_for_timeout(3120);record('three-second-confirm-expiry',page.locator('#confirm').is_disabled());page.click('#arm');page.click('#confirm');record('confirmation-no-real-removal','no player removed' in page.locator('#peerState').inner_text())
 for view in ['current','pilot','native','kit','future']:
  page.click('[data-view="'+view+'"]');page.wait_for_function('document.getElementById("plan").complete && document.getElementById("plan").naturalWidth>0');record('local-image-'+view,page.locator('#plan').evaluate('(im)=>im.naturalWidth>0'))
 page.click('[data-view="native"]');page.click('[data-effects="reduced"]');page.wait_for_function('document.getElementById("plan").complete');record('native-no-rescale',page.locator('#plan').evaluate('(im)=>im.clientWidth')==1280)
 page.click('[data-view="ui"]');page.click('[data-tab="chemistry"]');page.click('[data-a="Water"][data-b="Fire"]');page.set_viewport_size({'width':900,'height':900});record('responsive-page-not-overwide',page.evaluate('document.documentElement.scrollWidth<=900'))
 record('no-browser-errors',not errors,errors);record('no-external-network',all(u.startswith('data:') for u in requests),requests)
 browser.close()
report={'status':'OFFLINE_PREVIEW_CHECKS','scope':'HTML loaded in memory with PNG data URIs for browser checks; no game simulation, game network or runtime UI implementation','file_and_loopback_launch':'BLOCKED by browser administrator; packaged relative-path launch remains NOT_RUN, resources checked separately' ,'count':len(results),'passed':sum(r['status']=='PASS' for r in results),'failed':sum(r['status']=='FAIL' for r in results),'results':results}
(ROOT/'evidence/browser_checks.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ['status','count','passed','failed']},indent=2))
for r in results:
 if r['status']=='FAIL':print(r)
raise SystemExit(bool(report['failed']))
