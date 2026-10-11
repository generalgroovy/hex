#!/usr/bin/env python3
"""Optional browser smoke test for the offline review artifact, NOT the game.
Requires Playwright and a Chromium executable. Produces a scoped evidence report.
"""
from pathlib import Path
import json,shutil
from playwright.sync_api import sync_playwright
R=Path(__file__).resolve().parents[1]
checks=[];errors=[];requests=[]
def add(name,value):checks.append({'name':name,'passed':bool(value)})
with sync_playwright() as p:
    exe=shutil.which('chromium') or shutil.which('chromium-browser')
    browser=p.chromium.launch(executable_path=exe,headless=True,args=['--no-sandbox']) if exe else p.chromium.launch(headless=True)
    page=browser.new_page(viewport={'width':1280,'height':900},device_scale_factor=1)
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('request',lambda r:requests.append(r.url) if r.url.startswith(('http:','https:')) else None)
    # This environment blocks file:// navigation; do not disable that policy.
    # Inject the same self-contained document for artifact-only UI checks.
    page.set_content((R/'REVIEW.html').read_text(encoding='utf-8'));page.wait_for_function('window.__reviewReady===true')
    add('nine embedded source images decoded',page.evaluate('window.__sourceImageCount===9'))
    for case in range(5):
        page.select_option('#pilot',str(case))
        for size in ['small','middle','large']:
            page.select_option('#size',size)
            for phase in [0,4,7]:
                page.locator('#phase').evaluate('(e,v)=>{e.value=String(v);e.dispatchEvent(new Event("input",{bubbles:true}))}',phase)
                result=page.evaluate('''()=>{let q=window.__lastLookup;let c=window.__review.CASES[Number(document.getElementById('pilot').value)];return q.phase===Number(document.getElementById('phase').value)&&q.x>=0&&q.y>=0&&q.x+96<=(q.bank==='base'?768:1536)&&q.y+96<=(q.bank==='base'?960:3072)&&!document.getElementById('mainCanvas').getContext('2d').imageSmoothingEnabled}''')
                add(f'{case}/{size}/phase{phase}: bounded addressing and nearest',result)
            # Verify opaque pixels at true native scale with annotation guides disabled.
            page.select_option('#zoom','1');page.locator('#guides').uncheck()
            ok=page.evaluate('''()=>{let q=window.__lastLookup;let main=document.getElementById('mainCanvas').getContext('2d');let scratch=document.createElement('canvas');scratch.width=scratch.height=96;let c=scratch.getContext('2d');c.drawImage(images[q.file],q.x,q.y,96,96,0,0,96,96);let src=c.getImageData(0,0,96,96).data,actual=main.getImageData(208,260,96,96).data;for(let i=0;i<src.length;i+=4){if(src[i+3]===255&&(src[i]!==actual[i]||src[i+1]!==actual[i+1]||src[i+2]!==actual[i+2]||actual[i+3]!==255))return false}return true}''')
            add(f'{case}/{size}: native opaque body pixels exact',ok)
    page.select_option('#pilot','1');page.select_option('#size','small');page.select_option('#zoom','3');page.locator('#guides').check()
    page.screenshot(path=str(R/'evidence/viewer-diagonal-slide.png'),full_page=True)
    page.select_option('#pilot','4');page.select_option('#size','large');page.select_option('#zoom','2');page.select_option('#floor','light');page.locator('#reduced').check()
    page.locator('#phase').evaluate('(e)=>{e.value="4";e.dispatchEvent(new Event("input",{bubbles:true}))}')
    add('reduced mode limitation visible','sampler' in page.locator('#modeNote').inner_text())
    page.screenshot(path=str(R/'evidence/viewer-landing-reduced.png'),full_page=True)
    page.select_option('#pilot','0');page.select_option('#bank','sprint');add('sprint selects separate bank',page.evaluate('window.__lastLookup.bank==="sprint"'))
    page.select_option('#travel','7');page.select_option('#aim','3');page.locator('#phase').evaluate('(e)=>{e.value="7";e.dispatchEvent(new Event("input",{bubbles:true}))}')
    add('independent travel/aim/phase override',page.evaluate('window.__lastLookup.index===((7*8+3)*8+7)'))
    page.click('#next');add('next phase wraps 7 to0',page.evaluate('window.__lastLookup.phase===0'))
    page.click('#prev');add('previous phase wraps0 to7',page.evaluate('window.__lastLookup.phase===7'))
    page.click('#play');page.wait_for_timeout(250);page.click('#play');add('play/pause changes review sample',page.evaluate('window.__lastLookup.phase!==7'))
    add('no browser JavaScript errors',not errors);add('no HTTP(S) network requests',not requests)
    browser.close()
result={'status':'STATIC_VERIFIED' if all(c['passed'] for c in checks) else 'FAILED','scope':'Headless Chromium rendered the exact offline HTML via in-memory set_content; direct file navigation was blocked separately. No Godot, game capture, live action timing or performance acceptance','checks':len(checks),'passed':sum(c['passed'] for c in checks),'failed':[c for c in checks if not c['passed']],'javascript_errors':errors,'http_requests':requests,'screenshots':['evidence/viewer-diagonal-slide.png','evidence/viewer-landing-reduced.png'],'details':checks}
(R/'evidence/browser-test.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='details'},indent=2))
raise SystemExit(0 if result['status']=='STATIC_VERIFIED' else 1)
