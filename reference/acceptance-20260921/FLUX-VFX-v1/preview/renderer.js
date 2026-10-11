/* FLUX-VFX-v1 OFFLINE_PREVIEW. This is not the Godot renderer or a sim port.
 * Geometry constants and fallback projectile silhouettes are transcribed from
 * packet source. Lifecycle fixtures do not alter authoritative game values.
 */
(function (scope) {
 'use strict';
 const VERTICES_FIXED=[[0,-36950],[32000,-18475],[32000,18475],[0,36950],[-32000,18475],[-32000,-18475]];
 const FAMILY_SIZE={rapid:18,bolt:24,heavy:32,spray:24};
 const FAMILY_POINTS={rapid:[[6,0],[0,-4],[-5,0],[0,4]],heavy:[[10,0],[5,-8],[-6,-8],[-10,0],[-6,8],[5,8]],
  spray:[[9,0],[-5,-8],[-9,-3],[-4,0],[-9,3],[-5,8]],bolt:[[11,0],[1,-6],[-9,-3],[-5,0],[-9,3],[1,6]]};
 const MODES=['normal','reduced'];
 function clamp(x,lo,hi){return Math.min(hi,Math.max(lo,x));}
 function center(q,r){return [64*q+32*r,55.425*r];}
 function polygon(q,r,x=0,y=0){const c=center(q,r);return VERTICES_FIXED.map(v=>[x+c[0]+v[0]/1000,y+c[1]+v[1]/1000]);}
 function pointInPoly(pt,p){let sign=0;for(let i=0;i<p.length;i++){const a=p[i],b=p[(i+1)%p.length];const cross=(b[0]-a[0])*(pt[1]-a[1])-(b[1]-a[1])*(pt[0]-a[0]);if(Math.abs(cross)<1e-8)continue;const s=Math.sign(cross);if(sign&&sign!==s)return false;sign=s;}return true;}
 function path(ctx,p){ctx.beginPath();p.forEach((v,i)=>i?ctx.lineTo(v[0],v[1]):ctx.moveTo(v[0],v[1]));ctx.closePath();}
 function rgb(h,a=1){const n=parseInt(h.slice(1),16);return `rgba(${n>>16&255},${n>>8&255},${n&255},${clamp(a,0,1)})`;}
 function fixedKey(pt){return `${Math.round(pt[0]*1000)},${Math.round(pt[1]*1000)}`;}
 function edgeKey(r,a,b){const ends=[fixedKey(a),fixedKey(b)].sort().join(':');return [r.material,r.footprint_id,r.phase,Boolean(r.danger),r.intensity,r.expiry_tick,JSON.stringify(r.owner_key!==undefined?r.owner_key:r.owner!==undefined?r.owner:r.owner_id!==undefined?r.owner_id:r.source_ids||[]),ends].join('/');}
 function edgeCounts(regions){const counts=new Map();for(const r of regions){for(let i=0;i<6;i++){const k=edgeKey(r,r.polygon[i],r.polygon[(i+1)%6]);counts.set(k,(counts.get(k)||0)+1);}}return counts;}
 function boundaryEdges(regions){const counts=edgeCounts(regions);let result=[];for(const r of regions){for(let i=0;i<6;i++){if(counts.get(edgeKey(r,r.polygon[i],r.polygon[(i+1)%6]))===1)result.push([r,i]);}}return result;}
 function strengthSize(size,remaining,initial=100){if(!Number.isFinite(size)||size<=0||initial<=0||remaining<=0)return 0;return Math.max(Math.min(5,size),size*Math.sqrt(clamp(remaining/initial,0,1)));}
 function exposureTier(value){return Number.isFinite(value)?value<=0?0:Math.min(3,Math.ceil(clamp(value,0,240)/80)):null;}
 function lifecycle(material,tick){
  const end=material==='water'?720:material==='fire'?480:444;
  const decay=end-60;
  const forming=material==='fire'?'ignition':'forming',expired=material==='fire'?'cooling':'decaying';
  return {phase:tick<24?forming:tick<decay?'active':tick<end?expired:'none',
   danger:material!=='water'&&tick>=24&&tick<decay,
   progress:tick<24?clamp(tick/24,0,1):tick>=decay?clamp((tick-decay)/60,0,1):0,expiry_tick:end};
 }
 function makeRegions(material,cells,opts={}){
  return cells.map(([q,r])=>({material,q,r,polygon:polygon(q,r,opts.x||0,opts.y||0),
   phase:opts.phase||'active',danger:opts.danger===undefined?material!=='water':Boolean(opts.danger),
   intensity:opts.intensity===undefined?1000:opts.intensity,expiry_tick:opts.expiry_tick||900,
   owner:opts.owner===undefined?1:opts.owner,owner_key:opts.owner_key,footprint_id:opts.footprint_id||1,quantity:100,
   progress:opts.progress||0}));
 }
 function style(r,defs){
  const m=defs.materials[r.material];let row=r.phase;
  if(r.material==='steam'&&row==='active')row=r.intensity>1000?'hot':r.intensity<1000?'cool':'active';
  if(!m.palette_phases[row])return null;
  const pal=m.palette_phases[row],decay=r.phase==='decaying'||r.phase==='cooling';
  // A dangerous flag always wins over a stale/unknown cosmetic progress value.
  const fading=decay&&!r.danger?1-clamp(r.progress,0,1):1;
  return {...pal,row,dangerColor:pal.danger,alpha:m.fill_opacity[row]*fading,danger:!!r.danger,decay,
   edgeAlpha:decay?.28*fading:.90,frame:0};
 }
 function inwardStrip(ctx,p,i,width,c){const a=p[i],b=p[(i+1)%6];const dx=b[0]-a[0],dy=b[1]-a[1],len=Math.hypot(dx,dy);if(!len)return;
  const n=[-dy/len*width,dx/len*width];ctx.fillStyle=c;path(ctx,[a,b,[b[0]+n[0],b[1]+n[1]],[a[0]+n[0],a[1]+n[1]]]);ctx.fill();}

 function snapLocalTranslation(ctx,x,y){
  const m=ctx.getTransform(),det=m.a*m.d-m.b*m.c;
  if(!det)return [x,y];
  const sx=Math.round(m.a*x+m.c*y+m.e)-m.e,sy=Math.round(m.b*x+m.d*y+m.f)-m.f;
  return [(m.d*sx-m.c*sy)/det,(-m.b*sx+m.a*sy)/det];
 }
 function materialFrame(r,tick,reduced,defs){const s=style(r,defs);if(!s)return null;
  const m=defs.materials[r.material];let frame;
  if(r.phase==='forming'||r.phase==='ignition'||r.phase==='decaying'||r.phase==='cooling')frame=clamp(Math.floor(r.progress*8),0,7);
  else frame=reduced?3:Math.floor((tick+(r.q*13+r.r*7+10000))/(m.normal_active_loop_ticks/8))%8;
  return {row:m.row_phases.indexOf(s.row),frame,style:s};
 }

 function fillGroups(regions,defs){
  const groups=new Map();
  for(const r of regions){
   if(r.phase==='none')continue;const s=style(r,defs);if(!s)continue;
   const key=r.material+'/'+r.polygon.map(fixedKey).sort().join(';');
   const rank=(r.danger?1000000:0)+(r.phase==='active'?100000:0)+r.intensity;
   const old=groups.get(key);
   if(!old)groups.set(key,{region:r,style:s,rank,alpha:s.alpha,record_count:1});
   else{old.record_count++;old.alpha=Math.max(old.alpha,s.alpha);if(rank>old.rank){old.region=r;old.style=s;old.rank=rank;}}
  }
  return [...groups.values()];
 }
 function drawMaterials(ctx,regions,images,defs,tick,reduced=false,scale=1){
  const counts=edgeCounts(regions);let metrics={regions:0,motifs:0,boundaryEdges:0,freeParticles:0};
  for(const material of ['water','fire','steam']){
   const selected=regions.filter(x=>x.material===material).sort((a,b)=>Number(a.danger)-Number(b.danger));
   // Same-cell base-opacity is a union, not N accumulated cloud veils. Every
   // record still keeps its edge and bounded identity motif below the actors.
   for(const g of fillGroups(selected,defs)){
    ctx.save();path(ctx,g.region.polygon);ctx.clip();ctx.fillStyle=rgb(g.style.base,g.alpha);path(ctx,g.region.polygon);ctx.fill();ctx.restore();
   }
   for(const r of selected){
    if(r.phase==='none')continue;const f=materialFrame(r,tick,reduced,defs);if(!f)continue;const s=f.style,p=r.polygon;
    ctx.save();path(ctx,p);ctx.clip();
    // Material edges are exact inward strips, never UI range circles.
    for(let i=0;i<6;i++){
     if(counts.get(edgeKey(r,p[i],p[(i+1)%6]))>1)continue;
     const wide=Math.max(2,1/scale);
     inwardStrip(ctx,p,i,wide+1,rgb(s.dark,s.edgeAlpha));
     inwardStrip(ctx,p,i,Math.max(1,1/scale),rgb(s.bright,s.edgeAlpha*.76));
     if(s.danger){
      const a=p[i],b=p[(i+1)%6];
      if(material==='fire')inwardStrip(ctx,p,i,Math.max(1,1/scale),rgb(s.dangerColor||s.bright,.95));
      if(material==='steam'){
       // Sparse warm notches; condensation continues between them.
       const dx=b[0]-a[0],dy=b[1]-a[1],len=Math.hypot(dx,dy),nx=-dy/len,ny=dx/len;
       for(const t of [.23,.73]){
        const x=a[0]+dx*t,y=a[1]+dy*t,w=Math.max(2,1/scale);
        ctx.strokeStyle=rgb(s.dangerColor,.98);ctx.lineWidth=w;
        ctx.beginPath();ctx.moveTo(x+nx*w,y+ny*w);ctx.lineTo(x+nx*(w+3),y+ny*(w+3));ctx.stroke();
       }
      }
     }
     metrics.boundaryEdges++;
    }
    const cx=p.reduce((n,v)=>n+v[0],0)/6,cy=p.reduce((n,v)=>n+v[1],0)/6;
    const image=images[`assets/motifs/${material}-${reduced?'reduced':'normal'}.png`];
    if(image){ctx.imageSmoothingEnabled=false;const pos=snapLocalTranslation(ctx,cx-32,cy-40);ctx.drawImage(image,f.frame*64,f.row*80,64,80,pos[0],pos[1],64,80);metrics.motifs++;}
    ctx.restore();metrics.regions++;
   }
  }
  return metrics;
 }
 function label(ctx,text,x,y,size=13,color='#e4d3a5',font='monospace'){
  ctx.font=`${size}px ${font}`;ctx.fillStyle=color;ctx.textAlign='left';ctx.textBaseline='top';ctx.fillText(text,x,y);
 }
 function rule(ctx,x,y,w,color='#634117'){ctx.fillStyle=color;ctx.fillRect(x,y,w,1);}
 function floor(ctx,x,y,w,h,kind='light'){
  const dark=kind==='dark';ctx.fillStyle=dark?'#202428':'#98805a';ctx.fillRect(x,y,w,h);
  ctx.save();ctx.beginPath();ctx.rect(x,y,w,h);ctx.clip();
  // Deliberately quiet cardinals: no isometric floor or raised hex platforms.
  for(let yy=y;yy<y+h;yy+=28){const row=Math.floor((yy-y)/28);for(let xx=x-32;xx<x+w;xx+=64){
   const sx=xx+(row%2)*32;ctx.fillStyle=dark?'#292d30':'#a18b66';ctx.fillRect(sx+2,yy+2,61,1);
   ctx.fillStyle=dark?'#191d20':'#8e7854';ctx.fillRect(sx,yy,1,28);ctx.fillRect(sx,yy+27,64,1);
   if((Math.floor(xx/64)+row)%3===0){ctx.fillStyle=dark?'#2b3033':'#a38c63';ctx.fillRect(sx+16,yy+16,7,2);}
  }}ctx.restore();
 }
 function drawActor(ctx,images,x,y,size='middle',direction=0){
  // Input sheets already bake 58/63/68 px: never rescale them a second time.
  ctx.save();ctx.fillStyle='rgba(12,16,15,.42)';ctx.beginPath();ctx.ellipse(x,y+1,14,4,0,0,Math.PI*2);ctx.fill();
  const im=images[`assets/actors/${size}-base.png`];
  if(im){ctx.imageSmoothingEnabled=false;const pos=snapLocalTranslation(ctx,x-48,y-84);ctx.drawImage(im,direction*96,0,96,96,pos[0],pos[1],96,96);}ctx.restore();
 }
 function drawAim(ctx,x,y,tx,ty){ctx.save();ctx.lineWidth=3;ctx.strokeStyle='#101315';ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(tx,ty);ctx.stroke();
  ctx.lineWidth=1;ctx.strokeStyle='#fff0c6';ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(tx,ty);ctx.stroke();
  const a=5;ctx.strokeStyle='#101315';ctx.lineWidth=3;path(ctx,[[tx,ty-a],[tx+a,ty],[tx,ty+a],[tx-a,ty]]);ctx.stroke();
  ctx.strokeStyle='#fff0c6';ctx.lineWidth=1;ctx.stroke();ctx.restore();
 }
 function drawProjectile(ctx,material,family,x,y,angle,remaining,palette){const size=strengthSize(FAMILY_SIZE[family],remaining,100);if(!size)return 0;
  const c=palette.elements.find(e=>e.id===material).palette;ctx.save();const pos=snapLocalTranslation(ctx,x,y);ctx.translate(pos[0],pos[1]);ctx.rotate(angle);ctx.scale(size/24,size/24);
  ctx.fillStyle=c.base;path(ctx,FAMILY_POINTS[family]);ctx.fill();ctx.strokeStyle=c.dark;ctx.lineWidth=2;ctx.stroke();
  ctx.strokeStyle=c.bright;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(2,0);ctx.lineTo(7,0);ctx.stroke();ctx.restore();return size;
 }
 function drawExposure(ctx,x,y,exposure){const tier=exposureTier(exposure);if(tier===null||tier===0)return;
  for(let n=0;n<3;n++){ctx.fillStyle='#354f63';ctx.fillRect(x+n*5,y-2*n,4,6);ctx.fillStyle=n<tier?'#ff8f4f':'#7897a8';ctx.fillRect(x+n*5+1,y-2*n+1,2,4);}}
 function coverTitle(ctx,title,subtitle,w=1280){ctx.fillStyle='#101615';ctx.fillRect(0,0,w,720);label(ctx,'FLUX  /  MATERIAL WORKSHOP',28,17,12,'#d19a3f');label(ctx,title,28,41,26,'#fff0c6','serif');label(ctx,subtitle,28,80,12,'#c5ad79');rule(ctx,28,105,w-56);}
 function phaseFor(material,state){if(state.phase==='sequence')return lifecycle(material,state.tick);
  const p=state.phase==='forming'?(material==='fire'?'ignition':'forming'):state.phase==='decaying'?(material==='fire'?'cooling':'decaying'):'active';
  return {phase:p,danger:material!=='water'&&p==='active',progress:p==='active'?0:state.progress,expiry_tick:material==='water'?720:material==='fire'?480:444};}
 function renderBoard(canvas,images,defs,palette,state,reduced=false){const ctx=canvas.getContext('2d');canvas.width=1280;canvas.height=720;ctx.imageSmoothingEnabled=false;
  const mode=reduced?'REDUCED':'NORMAL';coverTitle(ctx,`Water / Fire / Steam  —  ${mode}`,
   `OFFLINE_PREVIEW  |  ${Math.round(state.scale*100)}% fixture camera  |  world cell 64 x 73.9 px  |  source body sheets 58 / 63 / 68 px`);
  let metrics=[];const mats=['water','fire','steam'];
  for(let row=0;row<2;row++)for(let col=0;col<3;col++){
   const material=mats[col],x=28+col*417,y=124+row*272,w=390,h=244,life=phaseFor(material,state);
   floor(ctx,x,y,w,h,row?'dark':'light');ctx.fillStyle='#101615ee';ctx.fillRect(x,y,w,44);
   label(ctx,material.toUpperCase(),x+12,y+8,15,'#fff0c6');
   const tag=life.phase==='none'?'EXPIRED / NO MATERIAL':life.danger?'ACTIVE DANGER':life.phase==='active'?'ACTIVE REAGENT / NON-DAMAGING':'HARMLESS '+life.phase.toUpperCase();
   label(ctx,tag,x+12,y+26,10,life.danger?'#ffb080':'#c5ad79');
   ctx.save();ctx.beginPath();ctx.rect(x,y+44,w,h-44);ctx.clip();
   ctx.translate(x+w/2-28*state.scale,y+132);ctx.scale(state.scale,state.scale);
   const regions=makeRegions(material,[[0,0],[1,0],[0,1]],{...life,intensity:material==='steam'?state.heat:1000});
   metrics.push(drawMaterials(ctx,regions,images,defs,state.tick,reduced,state.scale));
   drawActor(ctx,images,32,27,['small','middle','large'][col],state.direction||0);
   drawAim(ctx,43,-7,108,-34);
   const px=-58+((state.tick%180)/180)*165;
   drawProjectile(ctx,material==='steam'?'water':material,'bolt',px,47,-.22,state.remaining,palette);
   if(material==='steam'&&life.danger)drawExposure(ctx,50,-30,state.exposure);
   ctx.restore();label(ctx,row?'DARK WORLDBONE':'LIGHT WARM STONE',x+10,y+h-18,10,row?'#c5ad79':'#403424');
  }
  label(ctx,'Source fallback projectile shapes. Manual exposure input, not a game simulation. No range circles. Zero free particles.',28,684,11,'#c5ad79');
  return metrics;
 }
 function renderPaintover(canvas,images,defs,palette,state,reduced=false){canvas.width=1280;canvas.height=720;const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
  const src=images['assets/reference_inputs/01-before-free-casts-1280x720.png'];ctx.drawImage(src,0,0);
  const placements=[['water',420,404,[[0,0],[1,0],[0,1]],1],['fire',802,405,[[0,0],[1,0],[0,1]],2],['steam',593,380,[[0,0],[1,0],[-1,1],[0,1],[1,1],[-1,2],[0,2]],3]];
  for(const [m,x,y,cells,id] of placements){const life=phaseFor(m,state);ctx.save();ctx.translate(x,y);ctx.scale(.75,.75);
   drawMaterials(ctx,makeRegions(m,cells,{...life,footprint_id:id,intensity:m==='steam'?state.heat:1000}),images,defs,state.tick,reduced,.75);
   ctx.restore();}
  // Restore exact source player/cursor pixels after the paintover. This is an
  // offline manually bounded restoration, not an implementation of actor masking.
  ctx.drawImage(images['assets/actors/source-player-aim-restoration.png'],0,0);
  ctx.fillStyle='#0c100df0';ctx.fillRect(350,91,577,67);
  label(ctx,`OFFLINE PAINTOVER  /  ${reduced?'REDUCED':'NORMAL'}`,365,101,16,'#fff0c6');
  label(ctx,'Historical native capture + proposed material overlays.',365,127,12);
  label(ctx,'0.75x geometric fit inferred from cell width; no new Godot capture.',365,143,10,'#c5ad79');
  for(const [text,x,y] of [['WATER / REAGENT',374,350],['STEAM / SCALD',549,325],['FIRE / PRESSURE',760,350]]){
   ctx.fillStyle='#0c100de8';ctx.fillRect(x-4,y-3,165,21);label(ctx,text,x,y,12,'#fff0c6');}
  return {status:'OFFLINE_PREVIEW',original:'01-before-free-casts-1280x720.png',scale_fit:.75};
 }
 function renderPhaseBoard(canvas,images,defs,palette,reduced=false){canvas.width=1280;canvas.height=1008;const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
  ctx.fillStyle='#101615';ctx.fillRect(0,0,1280,1008);label(ctx,'FLUX / THE THREE MATERIAL SENTENCES',28,25,26,'#fff0c6','serif');
  label(ctx,`OFFLINE_PREVIEW — ${reduced?'REDUCED':'NORMAL'} — all tiles at 100% fixture camera; not a timing simulation`,28,67,12);
  const headings=['FORMATION / HARMLESS','ACTIVE / SOURCE DANGER','EXPIRY / HARMLESS'];for(let c=0;c<3;c++)label(ctx,headings[c],183+c*357,100,13,'#d19a3f');
  const mats=['water','fire','steam'];
  mats.forEach((m,row)=>{const yy=132+row*270;label(ctx,m.toUpperCase(),28,yy+12,18,'#fff0c6');
   const timing=m==='water'?'24 / 636 / 60 ticks':m==='fire'?'24 / 396 / 60 ticks':'24 / 360 / 60 ticks';label(ctx,timing,28,yy+42,10);
   for(let col=0;col<3;col++){const x=180+col*357,w=335;floor(ctx,x,yy,w,225,'light');floor(ctx,x,yy+114,w,111,'dark');
    const p=col===0?(m==='fire'?'ignition':'forming'):col===1?'active':m==='fire'?'cooling':'decaying';
    for(let f=0;f<3;f++)for(let back=0;back<2;back++){
     const progress=col===0?[0,.5,.958][f]:col===2?[0,.5,.999][f]:0;
     const regions=makeRegions(m,[[0,0]],{x:x+56+f*106,y:yy+62+back*110,phase:p,danger:col===1&&m!=='water',progress});
     drawMaterials(ctx,regions,images,defs,24+f*34,reduced,1);
    }
    label(ctx,col===1?(m==='water'?'NO DAMAGE: ingredient, not Flood':'Hot edge stays until source danger=false'):'Same full selected cell; only material changes',x,yy+235,10,'#c5ad79');
   }
  });
  label(ctx,'Steam hot/cool rows are modifier variants, not elapsed-age stages. Active curls are deliberately open; decay has no scald accents.',28,954,12);
  label(ctx,'Read actual phase and expiry from authority. Trail lifetimes and modified Steam may differ from these unmodified terminal references.',28,977,11,'#c5ad79');
 }
 function renderOverlapBoard(canvas,images,defs,palette,state){canvas.width=1280;canvas.height=720;const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
  coverTitle(ctx,'Exact cells. Open actors. No invisible safe gaps.','OFFLINE_PREVIEW — synthetic ownership, overlap and actor-exposure fixtures; not a gameplay capture');
  const panels=[['SAME RECORD / JOINED EDGE',[[0,0],[1,0],[0,1]],'same'],['DIFFERENT OWNERS / SEAM KEPT',[[0,0],[1,0],[0,1]],'owner'],['OVERLAP / ALL THREE READ',[[0,0],[1,0],[0,1]],'overlap']];
  panels.forEach(([title,cells,kind],idx)=>{const x=28+idx*417;floor(ctx,x,132,390,277,idx===1?'light':'dark');label(ctx,title,x+10,142,12,idx===1?'#403424':'#fff0c6');
   ctx.save();ctx.translate(x+155,242);
   let regs=makeRegions(kind==='overlap'?'water':'steam',cells,{phase:'active',danger:kind!=='overlap'});
   if(kind==='owner')regs[1].owner=2;
   if(kind==='overlap')regs=[...regs,...makeRegions('fire',[[1,0],[0,1]],{footprint_id:2}),...makeRegions('steam',[[0,0],[0,1]],{footprint_id:3})];
   drawMaterials(ctx,regs,images,defs,state.tick,state.reduced,1);drawActor(ctx,images,32,25,'middle',2);drawAim(ctx,43,-3,111,-27);
   drawProjectile(ctx,'fire','rapid',-12,52,.15,state.remaining,palette);ctx.restore();
   label(ctx,kind==='same'?'12 exterior edges; shared internal edges suppressed.':kind==='owner'?'No owner / phase / expiry blending.':'Water floor + Fire forks + Steam curls.',x+8,383,10,idx===1?'#403424':'#c5ad79');
  });
  label(ctx,'ACTOR SCALD EXPOSURE — SAME CLOUD, THREE ACTORS; HEAT IS A SEPARATE INPUT',28,437,13,'#d19a3f');
  for(let i=0;i<3;i++){const x=200+i*380;floor(ctx,x-156,471,320,169,'dark');ctx.save();ctx.translate(x,554);
   drawMaterials(ctx,makeRegions('steam',[[0,0]],{intensity:1000}),images,defs,state.tick,state.reduced,1);
   drawActor(ctx,images,0,28,['small','middle','large'][i],0);drawExposure(ctx,21,-13,[1,120,240][i]);ctx.restore();
   label(ctx,`EXPOSURE ${[1,120,240][i]} / 240   |   ${[1,2,3][i]} COPPER TICKS`,x-130,648,11);
  }
  label(ctx,'Synthetic exposure values are supplied explicitly. Missing exposure data => no invented meter. Cool Steam can still scald.',28,685,11);
 }

 function renderStressBoard(canvas,images,defs,palette,state){
  canvas.width=1280;canvas.height=720;const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
  coverTitle(ctx,'Bounded stress fixture / 43 cells, 8 actors, 16 projectiles','OFFLINE_PREVIEW — synthetic visual fixture, not a replay, benchmark, admission test or rendered-FPS claim');
  floor(ctx,28,124,612,502,'light');floor(ctx,640,124,612,502,'dark');
  const cells=[];for(let r=-3;r<=3;r++)for(let q=-3;q<=3;q++){if((r===-3||r===3)&&(q===-3||q===3))continue;cells.push([q,r]);}cells.splice(0,2);
  const mats=['water','fire','steam'];let regions=[];cells.forEach(([q,r],i)=>{const mat=mats[i%3];regions.push(...makeRegions(mat,[[q,r]],{footprint_id:1+i%3,x:625,y:368}));if(i%4===0)regions.push(...makeRegions('steam',[[q,r]],{footprint_id:4,x:625,y:368}));});
  const metrics=drawMaterials(ctx,regions,images,defs,state.tick,state.reduced,1);
  const actors=[[475,279],[632,245],[766,294],[485,415],[649,396],[825,418],[546,516],[742,523]];
  actors.forEach(([x,y],i)=>drawActor(ctx,images,x,y,['small','middle','large'][i%3],i));
  actors.forEach(([x,y],i)=>{drawAim(ctx,x+10,y-26,x+50,y-51);if(i%3===0)drawExposure(ctx,x+20,y-34,80*(i%3+1));});
  for(let i=0;i<16;i++){const x=416+(i%8)*57,y=333+Math.floor(i/8)*131;drawProjectile(ctx,i%2?'fire':'water',['rapid','bolt','heavy','bolt'][i%4],x,y,(i%8)*Math.PI/4,[100,60,25,1][i%4],palette);}
  label(ctx,'Source body sizes and eight grounded facings. All active cell material entries retained. No opaque volume; no free particles.',28,648,12);
  label(ctx,`43 unique cells / ${regions.length} material-region entries / ${metrics.motifs} bounded motifs / ${metrics.freeParticles} particles. No simulation or workload equivalence claimed.`,28,675,11,'#c5ad79');
  return {unique_cells:cells.length,regions:regions.length,actors:8,projectiles:16,...metrics};
 }
 function renderStrengthBoard(canvas,images,defs,palette,state){
  canvas.width=1280;canvas.height=720;const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
  coverTitle(ctx,'Remaining strength / smaller light, unchanged hit geometry','OFFLINE_PREVIEW — source fallback shapes; the runtime projectile atlas is absent. No radius or collision changes.');
  const families=['rapid','bolt','heavy','spray'],values=[100,50,25,1,0];
  values.forEach((v,c)=>label(ctx,v+'% STRENGTH',242+c*199,131,13,'#d19a3f'));
  families.forEach((f,r)=>{const yy=181+r*110;label(ctx,f.toUpperCase(),28,yy+30,16,'#fff0c6');label(ctx,'authored '+FAMILY_SIZE[f]+' px',28,yy+54,10);
   values.forEach((value,col)=>{const x=268+col*199;floor(ctx,x-64,yy,155,90,col%2?'light':'dark');drawProjectile(ctx,'water',f,x-15,yy+30,0,value,palette);drawProjectile(ctx,'fire',f,x+35,yy+30,0,value,palette);
    label(ctx,'bound '+strengthSize(FAMILY_SIZE[f],value,100).toFixed(2)+' px',x-49,yy+66,11,col%2?'#403424':'#c5ad79');});});
  label(ctx,'max(5 px, authored_size × sqrt(remaining / initial)); zero remaining draws nothing. Preserve the existing six-tick shrink cache.',28,650,12);
  label(ctx,'Rapid has no persistent trail. These are visual authored-size bounds, not a measurement of collision circles or final atlas occupancy.',28,679,11,'#c5ad79');
 }
 const API={VERTICES_FIXED,FAMILY_SIZE,FAMILY_POINTS,center,polygon,pointInPoly,edgeKey,edgeCounts,boundaryEdges,strengthSize,exposureTier,lifecycle,makeRegions,style,materialFrame,snapLocalTranslation,fillGroups,
  drawMaterials,drawActor,drawAim,drawProjectile,drawExposure,floor,label,renderBoard,renderPaintover,renderPhaseBoard,renderOverlapBoard,renderStressBoard,renderStrengthBoard,phaseFor};
 if(typeof module!=='undefined'&&module.exports)module.exports=API;scope.FluxVFX=API;
})(typeof globalThis!=='undefined'?globalThis:this);
