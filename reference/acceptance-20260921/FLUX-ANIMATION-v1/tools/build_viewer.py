#!/usr/bin/env python3
"""Assemble a self-contained source atlas review; no CDN, server or game dependency."""
from pathlib import Path
import json,base64
R=Path(__file__).resolve().parents[1]
images={p.name:'data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode() for p in (R/'originals').glob('*.png')}
cases=json.loads((R/'pilots/cases.json').read_text());manifest=json.loads((R/'originals/manifest.json').read_text())
html=r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>FLUX · shared body lab / source review</title>
<style>
:root{color-scheme:dark;--bg:#101c27;--panel:#192a38;--text:#f0e5cf;--muted:#abb8bc;--gold:#e7b566;--line:#405260;--cyan:#8bdcde}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 system-ui,sans-serif}main{max-width:1220px;margin:0 auto;padding:24px 28px 60px}
header{border-bottom:1px solid var(--line);padding-bottom:18px}.kicker{font-size:13px;letter-spacing:.13em;color:var(--gold)}h1{font-size:34px;margin:9px 0}h2{font-size:22px;margin:4px 0 12px}h3{font-size:14px;letter-spacing:.08em;color:var(--gold);margin:20px 0 7px}p{margin:7px 0 15px}.muted,small{color:var(--muted)}.badge{display:inline-block;border:1px solid var(--line);border-radius:5px;padding:3px 8px;font-size:12px;margin:4px 7px 0 0}.controls{display:flex;align-items:end;flex-wrap:wrap;gap:12px;margin:23px 0}label{display:grid;gap:5px;font-size:13px;color:var(--muted)}select,button,input{font:inherit}select,button{background:var(--panel);color:var(--text);border:1px solid var(--line);border-radius:6px;padding:9px 11px}button{cursor:pointer}button:hover,button:focus-visible,select:focus-visible{outline:2px solid var(--gold)}button.active{background:#364947;border-color:var(--gold)}input[type=range]{width:180px;accent-color:var(--gold)}input[type=checkbox]{accent-color:var(--cyan)}.row{display:flex;gap:15px;align-items:center;flex-wrap:wrap}.check{display:flex;flex-direction:row;align-items:center;gap:8px;color:var(--text);padding-bottom:8px}.layout{display:grid;grid-template-columns:544px 1fr;gap:24px}.view{border:1px solid var(--line);border-radius:10px;background:var(--panel);overflow:auto}.view-head{padding:14px 16px;border-bottom:1px solid var(--line);font-size:13px}canvas{display:block;image-rendering:pixelated;image-rendering:crisp-edges;margin:0 auto}#mainCanvas{width:512px;height:416px}#companion{width:192px;height:192px;margin:0}.caption{padding:12px 16px;font-size:13px;border-top:1px solid var(--line)}.facts{background:var(--panel);padding:16px;border-radius:8px}.mono{font:13px/1.6 ui-monospace,monospace;white-space:pre-wrap;color:var(--cyan)}.timeline{display:grid;grid-template-columns:repeat(8,1fr);gap:7px;margin:20px 0 7px}.timeline button{padding:10px 4px;min-height:74px;font-size:12px}.timeline b{display:block;font-size:18px}.warning{border-left:3px solid var(--gold);padding:9px 14px;background:#25323a}.mini{display:flex;gap:20px;align-items:center;margin-top:20px}details{border-top:1px solid var(--line);margin-top:26px;padding-top:18px}summary{cursor:pointer;color:var(--gold)}footer{margin-top:35px;border-top:1px solid var(--line);padding-top:18px;color:var(--muted);font-size:13px}a{color:var(--cyan)}@media(max-width:980px){.layout{grid-template-columns:1fr}.view{max-width:100%}.timeline{grid-template-columns:repeat(4,1fr)}}
</style>
<main><header><div class="kicker">FLUX / SHARED BODY LAB</div><h1>Animation foundation, before skins.</h1>
<p class="muted">Exact active-sheet pixels. Five annotated source probes. Clear boundaries between what exists and what still needs a runtime sequence.</p>
<span class="badge">OFFLINE_PREVIEW</span><span class="badge">SOURCE: slide_v1</span><span class="badge">SMALL → MIDDLE → LARGE</span><span class="badge">NO GAME CODE CHANGES</span>
</header>
<div class="controls">
<label>Pilot<select id="pilot"></select></label><label>Body<select id="size"><option>small</option><option>middle</option><option>large</option></select></label>
<label>Gait comparison<select id="bank"><option value="locomotion">walk</option><option value="sprint">sprint</option></select></label>
<label>Travel<select id="travel"></select></label><label>Aim<select id="aim"></select></label>
</div>
<div class="controls"><button id="play">Play source samples</button><button id="prev" title="Previous phase">← Phase</button><button id="next" title="Next phase">Phase →</button>
<label>Sample / phase<input type="range" id="phase" min="0" max="7" step="1" value="0"></label>
<label>Integer zoom<select id="zoom"><option value="1">1× native</option><option value="2">2×</option><option value="3">3×</option><option value="4">4×</option></select></label>
<label>Floor swatch<select id="floor"><option value="dark">Dark</option><option value="light">Light</option></select></label>
<label class="check"><input type="checkbox" id="guides">Aim / travel / pivot guides</label><label class="check"><input type="checkbox" id="reduced">Reduced-effects review</label>
</div>
<div class="layout"><section class="view"><div id="sourceLabel" class="view-head"></div><canvas id="mainCanvas" width="512" height="416" aria-label="Exact source sprite crop, optionally annotated"></canvas><div id="pixelCaption" class="caption"></div></section>
<section><h2 id="caseTitle"></h2><div class="facts"><div class="kicker">SOURCE VISIBLE / DOCUMENTED LIMIT</div><p id="observed"></p><div id="lookup" class="mono"></div></div>
<h3>PROPOSED CHANGE</h3><p id="proposal"></p><h3>ACTUAL RUNTIME STILL REQUIRED</h3><p id="runtime"></p><p id="modeNote" class="warning"></p></section></div>
<h3>PROPOSED ACTION / CONTACT SAMPLES</h3><div id="timeline" class="timeline"></div><p id="timelineNote" class="muted"></p>
<div class="mini"><canvas id="companion" width="192" height="192" aria-label="Additional existing source pose"></canvas><div><h3 id="companionLabel"></h3><p id="companionNote"></p><p class="muted">This additional pose is an exact source crop, not a new body animation. Body, shadow and spell effects remain separate.</p></div></div>
<details><summary>Source contract, provenance and limitations</summary>
<p>Index: <code>((travel*8+aim)*8+phase)</code>, 16×32 cells per gait page. All cells are 96×96; feet pivot (48,84). Direction order S, SE, E, NE, N, NW, W, SW; +Y is South. Moving walk/sprint use independent travel and aim. Slide/cast/jump base lookup uses aim only.</p>
<p>The 800 ms eight-sample loop is a viewing aid, not gameplay timing or the distance-driven clock. No positions, authoritative foot contacts, protection, cost, cast timing or prediction state are simulated. Landing is a deliberately labeled jump→grounded storyboard. Moving-cast mode shows the documented gait-only gap, not a reconstructed missing caller.</p>
<p>At 1×, one source pixel equals one canvas/CSS pixel. Browser zoom, OS scaling and actual camera scale remain external. The original images are embedded losslessly and never rescaled per pose. Debug arrows and the baseline are review-only, not in the body atlas.</p>
<p>No runtime capture or skeleton-length proof is supplied here. Native contact perception, continuous movement, normal/reduced aerial lift, real casting and walls require the original Godot project and lead-scheduled checks.</p>
</details>
<footer>FLUX-ANIMATION-v1 · reported source identity p53-cb264f9358a4, not recomputed here · original nine textures embedded · human acceptance pending · no network requests or profile writes.</footer>
</main>
<script>
'use strict';
const SOURCES=__IMAGES__, CASES=__CASES__, M=__MANIFEST__;
const $=id=>document.getElementById(id), dirs=M.directions;
const vectors=[[0,1],[.707,.707],[1,0],[.707,-.707],[0,-1],[-.707,-.707],[-1,0],[-.707,.707]];
const images={},errors=[];let timer=null,loaded=false;
for(const [name,url] of Object.entries(SOURCES)){const im=new Image();im.src=url;images[name]=im;}
CASES.forEach((c,i)=>{let o=new Option(c.id+' · '+c.slug.replaceAll('-',' '),String(i));$('pilot').add(o)});
for(let i=0;i<8;i++){let n=dirs[i].replaceAll('_',' ');$('travel').add(new Option(i+' · '+n,String(i)));$('aim').add(new Option(i+' · '+n,String(i)))}
function current(){return CASES[Number($('pilot').value)]}
function stop(){if(timer){clearInterval(timer);timer=null}$('play').textContent='Play source samples'}
function setup(){const c=current();$('travel').value=String(c.travel_index);$('aim').value=String(c.aim_index);$('phase').value='0';$('bank').disabled=c.bank==='base';stop();draw()}
function lookup(c,phase,size,t,a){let bank=c.bank==='base'?'base':$('bank').value,state=null,index;
 if(c.id==='P05'){bank='base';state=phase<2?'jump':'grounded'}else if(bank==='base'){state=c.source_state}
 if(bank==='base'){index=M.base_rows.indexOf(state)*8+a;return {file:size+'-base.png',x:a*96,y:M.base_rows.indexOf(state)*96,state,index,bank}}
 index=((t*8+a)*8+phase);return {file:size+'-'+bank+'.png',x:(index%16)*96,y:Math.floor(index/16)*96,state:bank,index,bank};
}
function arrow(ctx,x,y,v,color){ctx.strokeStyle=color;ctx.fillStyle=color;ctx.lineWidth=2;let ex=x+v[0]*32,ey=y+v[1]*32;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(ex,ey);ctx.stroke();const a=Math.atan2(v[1],v[0]);ctx.beginPath();ctx.moveTo(ex,ey);ctx.lineTo(ex-8*Math.cos(a-.5),ey-8*Math.sin(a-.5));ctx.lineTo(ex-8*Math.cos(a+.5),ey-8*Math.sin(a+.5));ctx.closePath();ctx.fill()}
function companion(c,size,a){let ctx=$('companion').getContext('2d');ctx.imageSmoothingEnabled=false;ctx.fillStyle='#25292a';ctx.fillRect(0,0,192,192);let state='grounded',aim=a,label='Existing grounded source',note='A registration reference. Do not fit other pose heights back into this standing rectangle.';
 if(c.id==='P02'){state='slide';aim=3;label='Existing NE slide (aim 3)';note='NE art is present. A South aim still selects the South cell even when actual travel is NE.'}
 if(c.id==='P04'){state='cast';label='Existing static cast (selected aim)';note='Direct cast lookup selects this base cell. The source function does not layer these arms over moving gait legs.'}
 ctx.drawImage(images[size+'-base.png'],aim*96,M.base_rows.indexOf(state)*96,96,96,0,0,192,192);$('companionLabel').textContent=label;$('companionNote').textContent=note;
}
function draw(){if(!loaded)return;const c=current(),phase=Number($('phase').value),size=$('size').value,t=Number($('travel').value),a=Number($('aim').value),z=Number($('zoom').value),r=lookup(c,phase,size,t,a);
 const ctx=$('mainCanvas').getContext('2d');ctx.imageSmoothingEnabled=false;ctx.fillStyle=$('floor').value==='light'?'#dfd3b8':'#25292a';ctx.fillRect(0,0,512,416);const x=Math.floor((512-96*z)/2),y=344-84*z;
 ctx.drawImage(images[r.file],r.x,r.y,96,96,x,y,96*z,96*z);
 if($('guides').checked){ctx.strokeStyle='#718287';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(32,344.5);ctx.lineTo(480,344.5);ctx.stroke();ctx.strokeStyle='#8bdcde';ctx.strokeRect(x+48*z-3,y+84*z-3,6,6);arrow(ctx,64,64,vectors[a],'#65bfc5');arrow(ctx,151,64,vectors[t],'#c28e36');ctx.font='12px system-ui';ctx.fillStyle=$('floor').value==='light'?'#23323b':'#e7dfce';ctx.fillText('AIM '+a,38,115);ctx.fillText('TRAVEL '+t,122,115);ctx.fillText('fixed pivot (48,84)',32,378)}
 $('sourceLabel').textContent=c.source_label+(t!==c.travel_index||a!==c.aim_index?' · headings overridden below':'');
 $('caseTitle').textContent=c.title; $('observed').textContent=c.observed;$('proposal').textContent=c.proposal;$('runtime').textContent=c.runtime_gate;
 $('lookup').textContent=`${r.file}\nsource rect [${r.x}, ${r.y}, 96, 96]\nindex ${r.index} · sample ${phase} · travel ${t} · aim ${a}\n${r.bank==='base'?'BASE: travel does not choose the source cell':'GAIT: independent travel × aim × phase'}`;
 $('pixelCaption').textContent=`${z}× nearest · ${size} standing display ${M.sizes[size].display_height}px · reference ${M.sizes[size].reference_height}px · body source pixels unchanged`;
 $('modeNote').textContent=$('reduced').checked?'Reduced-effects review: contact/action timing must remain. Body source pixels are unchanged here. The documented 28/7px lift sampler and shadows are absent; this viewer does not reproduce them.':'Normal-effects review: no shadows, spell effects or physical aerial lift are simulated. Source pixels alone cannot establish runtime contacts.';
 $('timeline').replaceChildren();c.phase_labels.forEach((s,i)=>{let b=document.createElement('button');b.innerHTML='<b>'+i+'</b>'+s;b.className=i===phase?'active':'';b.onclick=()=>{stop();$('phase').value=String(i);draw()};$('timeline').append(b)});
 $('timelineNote').textContent=c.asterisk||'Proposed support/action labels, not automatic extraction of the source rig. In gait pilots: L supports samples 0–3; R supports 4–7. In slide: contacts glide, not walk-plant.';
 companion(c,size,a);window.__lastLookup={...r,phase,size,t,a,zoom:z};
}
$('pilot').addEventListener('change',setup);
for(const id of ['size','bank','travel','aim','zoom','floor','guides','reduced'])$(id).addEventListener('change',draw);
$('phase').addEventListener('input',()=>{stop();draw()});
$('prev').onclick=()=>{stop();$('phase').value=String((Number($('phase').value)+7)%8);draw()};$('next').onclick=()=>{stop();$('phase').value=String((Number($('phase').value)+1)%8);draw()};
$('play').onclick=()=>{if(timer){stop();return}$('play').textContent='Pause';timer=setInterval(()=>{$('phase').value=String((Number($('phase').value)+1)%8);draw()},100)};
Promise.all(Object.values(images).map(im=>im.decode())).then(()=>{loaded=true;setup();window.__reviewReady=true;window.__sourceImageCount=Object.keys(images).length}).catch(e=>{$('sourceLabel').textContent='Image decoding failed: '+e.message;errors.push(e.message)});
window.__review={lookup,CASES,M,errors};
</script></html>'''
html=html.replace('__IMAGES__',json.dumps(images)).replace('__CASES__',json.dumps(cases,ensure_ascii=False)).replace('__MANIFEST__',json.dumps(manifest))
(R/'REVIEW.html').write_text(html,encoding='utf-8')
print('Wrote standalone REVIEW.html:',len(html),'characters')
