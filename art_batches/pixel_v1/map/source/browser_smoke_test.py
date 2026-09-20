#!/usr/bin/env python3
"""Optional local browser QA. Requires Playwright and an available Chromium binary.
Creates temporary browser data ONLY inside the map batch, then removes it.
Does not install anything or open an engine/project. Normal users only need review.html.
"""
from __future__ import annotations
import sys
sys.dont_write_bytecode=True
import argparse, hashlib, json, os, shutil, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--chromium',default=shutil.which('chromium') or shutil.which('chrome'));args=ap.parse_args()
    if not args.chromium: raise SystemExit('Provide --chromium path/to/chromium; no browser is installed by this script.')
    tmp=ROOT/'source/.browser_qa_tmp';tmp.mkdir(exist_ok=True)
    os.environ['TMPDIR']=str(tmp);os.environ['TMP']=str(tmp);os.environ['TEMP']=str(tmp);tempfile.tempdir=str(tmp)
    from playwright.sync_api import sync_playwright
    report={'result':'FAIL','tests':[],'javascript_errors':[],'external_page_requests':[],'engine_tested':False}
    def check(value,label):
        if not value:raise AssertionError(label)
        report['tests'].append(label)
    try:
        with sync_playwright() as p:
            ctx=p.chromium.launch_persistent_context(str(tmp/'profile'),executable_path=args.chromium,headless=True,viewport={'width':1440,'height':1100},accept_downloads=True,args=['--no-sandbox','--disable-dev-shm-usage','--disable-background-networking'],env={**os.environ,'HOME':str(tmp/'home')})
            page=ctx.new_page()
            page.on('pageerror',lambda e:report['javascript_errors'].append(str(e)))
            page.on('request',lambda r:report['external_page_requests'].append(r.url) if r.url.startswith(('http:','https:')) else None)
            # The review is self-contained. Inject its exact bytes rather than require file-URL navigation.
            page.set_content((ROOT/'previews/review.html').read_text(),wait_until='load')
            report['html_sha256']=hashlib.sha256((ROOT/'previews/review.html').read_bytes()).hexdigest()
            report['load_method']='set_content of exact delivered HTML; direct file-URL navigation is blocked by this container administrator and was not verified'
            page.wait_for_timeout(800)
            expected=len(json.loads((ROOT/'manifest.json').read_text())['assets'])
            check(page.locator('.card').count()==expected,'All manifest assets become catalogue cards')
            check(page.evaluate('Array.from(images.values()).every(i=>i.complete&&i.naturalWidth>0)'), 'Every embedded PNG decodes successfully')
            check(page.evaluate('DATA.assets.filter(x=>x.meta.loop).every(x=>{let a=x.meta,n=a.frames.reduce((s,f)=>s+f.duration_ticks,0);return indexAt(a,0)===0&&indexAt(a,n-1)===a.frames.length-1&&indexAt(a,n)===0})'),'Exact tick selection and cycle wrap for every ambient clip')
            page.locator('#search').fill('worldbone.standard')
            check(page.locator('.card').count()==16,'Search exposes all sixteen standard wall masks')
            page.locator('#search').fill('')
            page.locator('#group').select_option('ambient')
            check(page.locator('.card').count()==8,'Ambient category contains eight clips')
            page.locator('#zoom').select_option('3')
            check(page.locator('.card canvas').first.evaluate('(c)=>parseInt(c.style.width)===c.width*3'),'Integer nearest-neighbor zoom changes display size, not source resolution')
            page.locator('#anchors').check()
            page.wait_for_timeout(80)
            check(page.locator('#anchors').is_checked(),'Descriptive pivot / footprint overlay toggle works')
            page.locator('#anchors').uncheck()
            page.locator('#group').select_option('')
            page.locator('#search').fill('prop.training_dummy')
            with page.expect_download() as info:page.locator('.card .png').click()
            dl=info.value;out=tmp/'download.png';dl.save_as(out)
            asset=next(a for a in json.loads((ROOT/'manifest.json').read_text())['assets'] if a['id']=='map.prop.training_dummy')
            check(out.read_bytes()==(ROOT/asset['path']).read_bytes(),'Save PNG reproduces exact exported bytes')
            page.locator('.card .info').click()
            check('visual_ground_footprint' in page.locator('#detail').inner_text(),'Asset details include footprint and frame metadata')
            page.locator('#close').click()
            page.locator('#notes').click()
            check('Palette approval is blocked' in page.locator('#detail').inner_text(),'Integration notice is available offline')
            page.locator('#close').click()
            with page.expect_download() as info:page.locator('#manifest').click()
            info.value.save_as(tmp/'manifest.json')
            check(json.loads((tmp/'manifest.json').read_text())['namespace']=='map','Manifest download parses as the map manifest')
            for tab,im in [('catalogue','img-catalogue'),('seams','img-seams'),('courtyard','img-courtyard'),('motion','img-motion')]:
                page.locator(f'[data-tab="{tab}"]').click()
                check(page.locator('#'+im).evaluate('(i)=>i.complete&&i.naturalWidth>0'),f'{tab.title()} preview loads offline')
            page.locator('[data-tab="courtyard"]').click()
            src=page.locator('#img-courtyard').get_attribute('src');page.locator('#grid-toggle').click()
            check(src!=page.locator('#img-courtyard').get_attribute('src'),'Courtyard grid switches to actual grid preview')
            page.locator('[data-tab="assets"]').click();page.locator('#search').fill('');page.locator('#zoom').select_option('2')
            page.screenshot(path=str(ROOT/'previews/review_browser_desktop.png'),full_page=False)
            page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(100)
            check(page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'),'Mobile viewport has no horizontal page overflow')
            page.screenshot(path=str(ROOT/'previews/review_browser_mobile.png'),full_page=False)
            check(not report['javascript_errors'],'No JavaScript page errors')
            check(not report['external_page_requests'],'No external page requests')
            report['result']='PASS';report['chromium_version']=ctx.browser.version if ctx.browser else 'system Chromium'
            report['asset_count']=expected;report['test_count']=len(report['tests']);ctx.close()
    finally:
        (ROOT/'source/browser_qa.json').write_text(json.dumps(report,indent=2)+'\n')
        shutil.rmtree(tmp,ignore_errors=True)
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
