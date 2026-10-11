/* File://-safe browser harness. No imports, fetch, CDN, storage or network. */
'use strict';
(function(){
 const DATA=window.FLUX_DATA,F=window.FluxVFX;
 const assetURL=path=>(window.FLUX_EMBEDDED_ASSETS||{})[path]||path;
 const images={},state={phase:'active',scale:1,heat:1000,direction:0,progress:.5,exposure:120,remaining:100,tick:60,reduced:false};
 let view='bench',paused=window.matchMedia('(prefers-reduced-motion: reduce)').matches,previous=0,lastDraw=0;
 const $=id=>document.getElementById(id);
 const paths=[...DATA.atlas.atlases.map(a=>a.path),...['small','middle','large'].map(s=>`assets/actors/${s}-base.png`),
  'assets/actors/source-player-aim-restoration.png',...['01-before-free-casts','02-water-away-from-dummy','03-steam-normal','04-steam-reduced'].map(n=>`assets/reference_inputs/${n}-1280x720.png`)];
 const ready=Promise.all(paths.map(path=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{images[path]=im;resolve();};im.onerror=()=>reject(new Error('Missing preview dependency: '+path));im.src=assetURL(path);})));
 function render(){
  if(view==='bench'){F.renderBoard($('bench-normal'),images,DATA.materials,DATA.palette,state,false);F.renderBoard($('bench-reduced'),images,DATA.materials,DATA.palette,state,true);}
  else if(view==='paintover'){F.renderPaintover($('paint-normal'),images,DATA.materials,DATA.palette,state,false);F.renderPaintover($('paint-reduced'),images,DATA.materials,DATA.palette,state,true);}
  else if(view==='phases'){F.renderPhaseBoard($('phase-normal'),images,DATA.materials,DATA.palette,false);F.renderPhaseBoard($('phase-reduced'),images,DATA.materials,DATA.palette,true);}
  else if(view==='overlap')F.renderOverlapBoard($('overlap'),images,DATA.materials,DATA.palette,state);
 }
 function setState(patch={}){Object.assign(state,patch);render();return {...state};}
 function switchView(name){view=name;for(const id of ['phase','scale','heat','direction','progress','exposure','remaining'])$(id).disabled=name==='paintover'?['scale','direction','exposure','remaining'].includes(id):name==='overlap'?id!=='remaining':false;document.querySelectorAll('.view').forEach(e=>e.classList.toggle('hidden',e.id!=='view-'+name));document.querySelectorAll('.tabs button').forEach(b=>b.classList.toggle('selected',b.dataset.view===name));$('controls').classList.toggle('hidden',['palette','evidence','phases'].includes(name));$('fixture-note').classList.toggle('hidden',['palette','evidence','phases'].includes(name));render();}
 function step(ts){if(previous&&!paused)state.tick=(state.tick+(ts-previous)*.12)%780;previous=ts;if(!paused&&ts-lastDraw>80){render();lastDraw=ts;}requestAnimationFrame(step);}
 document.querySelectorAll('.tabs button').forEach(b=>b.addEventListener('click',()=>switchView(b.dataset.view)));
 for(const id of ['phase','scale','heat','direction','progress','exposure','remaining'])$(id).addEventListener('input',()=>{
  state[id]=id==='phase'?$(id).value:Number($(id).value)/(id==='progress'?100:1);
  if(id==='progress')$('progress-value').textContent=Math.round(state.progress*100)+'%';
  if(id==='exposure')$('exposure-value').textContent=state.exposure+' / 240';
  if(id==='remaining')$('remaining-value').textContent=state.remaining+'%';render();
 });
 $('play').textContent=paused?'Play motion':'Pause motion';
 $('play').addEventListener('click',()=>{paused=!paused;$('play').textContent=paused?'Play motion':'Pause motion';});
 $('reset').addEventListener('click',()=>{state.tick=0;render();});
 document.querySelectorAll('.export').forEach(b=>b.addEventListener('click',()=>{const a=document.createElement('a');a.href=$(b.dataset.canvas).toDataURL('image/png');a.download='FLUX-OFFLINE-'+b.dataset.canvas+'.png';a.click();}));
 function paletteTable(){
  const esc=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  $('palette-table').innerHTML='<table class="palette"><thead><tr><th>ELEMENT / INTERNAL ID</th><th>CONTRACT PALETTE</th><th>SILHOUETTE &amp; MOTION</th><th>PHASE LANGUAGE</th></tr></thead><tbody>'+DATA.palette.elements.map(e=>
   `<tr><td><div class="element"><img src="${esc(assetURL(e.icon))}" alt=""><div><b>${esc(e.display_name)}</b><small>${esc(e.id)}</small></div></div></td><td><div class="chipline">${Object.values(e.palette).map(c=>`<i class="chip" style="background:${esc(c)}"></i>`).join('')}</div><span class="colorcodes">${Object.values(e.palette).map(esc).join('<br>')}</span></td><td>${esc(e.shape)}<br><span class="phase-description">${esc(e.motion)}</span></td><td class="phase-description"><b>Form:</b> ${esc(e.phases.formation)}<br><b>Active:</b> ${esc(e.phases.active)}<br><b>Expire:</b> ${esc(e.phases.harmless_expiry)}</td></tr>`).join('')+'</tbody></table>';
  $('environment').innerHTML=Object.entries(DATA.palette.environment_ramps).map(([name,colors])=>`<div class="swatch-block">${esc(name.replaceAll('_',' '))}<div class="chipline">${colors.map(c=>`<i class="chip" style="background:${esc(c)}"></i>`).join('')}</div></div>`).join('');
 }
 paletteTable();
 window.FLUX_PREVIEW={ready,state,images,data:DATA,render,setState,switchView,pause(){paused=true;$('play').textContent='Play motion';},
  getState:()=>({...state}),renderBoard:(canvas,reduced=false)=>F.renderBoard(canvas,images,DATA.materials,DATA.palette,state,reduced),
  renderPaintover:(canvas,reduced=false)=>F.renderPaintover(canvas,images,DATA.materials,DATA.palette,state,reduced),
  renderPhaseBoard:(canvas,reduced=false)=>F.renderPhaseBoard(canvas,images,DATA.materials,DATA.palette,reduced),
  renderOverlapBoard:canvas=>F.renderOverlapBoard(canvas,images,DATA.materials,DATA.palette,state),
  renderStressBoard:canvas=>F.renderStressBoard(canvas,images,DATA.materials,DATA.palette,state),
  renderStrengthBoard:canvas=>F.renderStrengthBoard(canvas,images,DATA.materials,DATA.palette,state)};
 ready.then(()=>{render();document.body.dataset.ready='true';requestAnimationFrame(step);}).catch(err=>{const box=$('error');box.textContent=err.message;box.classList.remove('hidden');console.error(err);});
})();
