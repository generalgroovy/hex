import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import sharp from 'sharp';
import {terrainMaterial,reactivePropFrame,terrainEdges,terrainTransition} from '../lib/reactive-environment-v17.ts';
import {createSimGame,previewField,resolveRound,type SimCell} from '../lib/tactics-v16.ts';
import {generateArena,arenaRadius,arenaStarts} from '../lib/arena-v17.ts';
import {formatTile} from '../lib/board-labels-v17.ts';
import {battlefieldBounds,fitEffect,surfacePoint} from '../lib/battlefield-geometry.ts';
import {canonicalMotionSnapshot,movementAdviceText,resolutionActorIds} from '../lib/battlefield-presentation-v17.ts';
import {createSimGame as createArena,movementPath as arenaMovementPath,resolveRound as resolveArena,legalCasts as arenaLegalCasts,type TeamPlan as ArenaPlan} from '../lib/tactics-v17.ts';
import {presentArena} from '../lib/skirmish-client-v17.ts';
import {battlefieldMotion} from '../lib/battlefield-motion-v16.ts';
import {groundContacts} from '../lib/combat-life-v16.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
  const cached=modules.get(filename);if(cached)return cached.exports;
  const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
  const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
  const requireLocal=(specifier:string):unknown=>{
    if(specifier.endsWith('.css'))return {};
    if(!specifier.startsWith('.'))return nodeRequire(specifier);
    const target=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(suffix=>target+suffix).find(path=>existsSync(path));
    assert.ok(found,`Missing renderer dependency ${specifier}`);
    return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
  };
  new Function('require','module','exports',js)(requireLocal,module,module.exports);return module.exports;
}
type BoardProps=ComponentProps<typeof import('../app/components/PixelBattlefieldV16.tsx').default>;
const Board=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV16.tsx',import.meta.url))).default as ComponentType<BoardProps>;
const natural:SimCell={q:0,r:0,biome:'plain',terrain:'plain',height:0,well:false};

test('terrain material follows resolved chemistry and its expiration, not ingredient colour',()=>{
  assert.equal(terrainMaterial(previewField(natural,['fire'])),'scorched');
  assert.equal(terrainMaterial(previewField(natural,['fire','water'])),'mist','Steam protects rather than showing dangerous flames');
  assert.equal(terrainMaterial(previewField(natural,['water'],true)),'frozen');
  assert.equal(terrainMaterial(previewField(natural,['water'])),'flooded');
  assert.equal(terrainMaterial(previewField({...natural,terrain:'earth',biome:'forest'},['water'])),'mud','Water on Earth reads as a muddy slow crossing');
  assert.equal(terrainMaterial(previewField(natural,['water','dark'])),'frozen','Black Ice uses its real sliding state');
  assert.equal(terrainMaterial(previewField(natural,['dark'])),'blighted');
  assert.equal(terrainMaterial(previewField(natural,['light'])),'radiant');
  assert.equal(terrainMaterial(previewField(natural,['air'])),'current');
  const state=createSimGame(),point=state.cells.find(cell=>cell.biome==='plain'&&!cell.well)!;
  const burning=previewField(point,['fire']);Object.assign(point,burning,{ttl:1});
  const after=resolveRound(state,[{orders:[]},{orders:[]}]),expired=after.cells.find(cell=>cell.q===point.q&&cell.r===point.r)!;
  assert.equal(terrainMaterial(expired),'natural');
  assert.equal(terrainTransition(burning,expired),'natural');
  assert.equal(terrainTransition(burning,{...burning,ttl:2}),null,'Refreshing the same field does not replay a formation burst');
});

test('reactive scenery preserves its silhouette and never turns open boulders into blockers',()=>{
  const burned=previewField({...natural,biome:'forest',terrain:'earth'},['fire']);
  assert.equal(reactivePropFrame(burned,0),0);
  assert.equal(reactivePropFrame(burned,1),1);
  assert.equal(reactivePropFrame(burned,3),2);
  assert.equal(reactivePropFrame(burned,4),3);
  assert.equal(reactivePropFrame(burned,6),null,'A passable rock never acquires a wall sprite');
  assert.equal(reactivePropFrame({...natural,biome:'forest',terrain:'earth'},0),null);
  assert.equal(reactivePropFrame(previewField(natural,['fire','water']),0),null,'Steam does not char the canopy');
});

test('continuous water and ice show a shoreline only where their material actually ends',()=>{
  const a={...natural,terrain:'water',biome:'water' as const},b={...a,q:1},dry={...natural,r:1};
  const wet=terrainEdges([a,b,dry]);
  assert.ok(!wet.get('0,0')!.some(edge=>edge.edge===1),'No false bank between two water hexes');
  assert.ok(wet.get('0,0')!.some(edge=>edge.edge===2&&edge.kind==='bank'));
  const frozen=[previewField(a,['water'],true),previewField(b,['water'],true),dry],ice=terrainEdges(frozen);
  assert.ok(!ice.get('0,0')!.some(edge=>edge.edge===1),'Connected slide has no internal seam');
  assert.ok(ice.get('0,0')!.some(edge=>edge.edge===2&&edge.kind==='ice'));
  assert.deepEqual(terrainEdges(frozen),ice);
});

test('all sixteen accepted environmental drawings have clean alpha, distinct pixels and grounded feet',async()=>{
  const audit=JSON.parse(readFileSync(new URL('../docs/environment/reactive-props-v17-audit.json',import.meta.url),'utf8'));
  const bytes=readFileSync(new URL('../public/pixel/environment/reactive-props-v17.webp',import.meta.url));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),audit.sha256);
  const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert.deepEqual([info.width,info.height],[512,512]);
  const hashes=new Set<string>();
  for(let row=0;row<4;row++)for(let column=0;column<4;column++){
    const cell=await sharp(bytes).extract({left:column*128,top:row*128,width:128,height:128}).ensureAlpha().raw().toBuffer();
    hashes.add(createHash('sha256').update(cell).digest('hex'));let occupied=0,foot=0;
    for(let y=0;y<128;y++)for(let x=0;x<128;x++){
      const alpha=data[((row*128+y)*512+column*128+x)*4+3];
      assert.ok(alpha===0||alpha===255,'Pixel alpha is binary');
      if(alpha){occupied++;foot=Math.max(foot,y);assert.ok(x>0&&x<127&&y>0&&y<127,'No clipped cell edge');}
    }
    assert.ok(occupied>500);assert.equal(foot,123,'Every prop shares the imported ground baseline');
  }
  assert.equal(hashes.size,16);
});

test('real battlefield reveals changed ground and props at impact, never during movement or flight',()=>{
  const before=createSimGame(),forest=before.cells.find(cell=>cell.biome==='forest')!;
  const after=structuredClone(before);after.version++;
  Object.assign(after.cells.find(cell=>cell.q===forest.q&&cell.r===forest.r)!,previewField(forest,['fire']));
  for(const phase of ['move','cast','impact','settle'] as const){
    const html=renderToStaticMarkup(createElement(Board,{state:after,previousState:before,plan:{orders:[]},player:0,selected:before.units[0].id,kind:'move',interactive:false,onCell:()=>{},resolving:true,playback:{active:true,phase,key:1}}));
    const revealed=phase==='impact'||phase==='settle';
    assert.equal(html.includes('data-prop-material="scorched"'),revealed,phase);
    assert.equal(html.includes('data-terrain-material="scorched"'),revealed,phase);
    assert.equal(html.includes('data-terrain-arrival="scorched"'),revealed,phase);
    assert.equal(html.includes('/pixel/environment/reactive-props-v17.webp'),revealed,phase);
  }
});

test('full-footprint blockers follow authoritative barrier expiry at impact without changing ruins',()=>{
  const before=createSimGame(),barrier=before.cells.find(cell=>cell.biome==='plain'&&!cell.well&&!before.units.some(unit=>unit.q===cell.q&&unit.r===cell.r))!;
  barrier.barrier=1;
  const after=resolveRound(before,[{orders:[]},{orders:[]}]);
  assert.equal(after.cells.find(cell=>cell.q===barrier.q&&cell.r===barrier.r)!.barrier,undefined);
  const ruins=before.cells.filter(cell=>cell.biome==='ruins').length;
  for(const phase of ['move','cast','impact','settle'] as const){
    const html=renderToStaticMarkup(createElement(Board,{state:after,previousState:before,plan:{orders:[]},player:0,selected:before.units[0].id,kind:'move',interactive:false,onCell:()=>{},resolving:true,playback:{active:true,phase,key:2}}));
    const beforeImpact=phase==='move'||phase==='cast';
    assert.equal(html.includes(`data-solid-cell="${barrier.q},${barrier.r}"`),beforeImpact,phase);
    assert.equal((html.match(/data-solid-terrain="ruin"/g)||[]).length,ruins);
    assert.equal((html.match(/data-solid-terrain="barrier"/g)||[]).length,beforeImpact?1:0);
  }
});

test('two and six seat maps render complete dynamic extents, labels and per-player identity',()=>{
  for(const count of [2,6] as const){
    const mapId=`arena:${count}:TERRAIN-RENDER`,state=createSimGame();state.cells=generateArena(mapId).map(cell=>({...cell}));state.mapId=mapId;state.inhabitants=[];
    const radius=arenaRadius(mapId),starts=arenaStarts(mapId),presentation:Record<string,{color:string;label:string;name?:string}>={};
    state.units=state.units.slice(0,count).map((unit,index)=>({...unit,...starts[index][0],owner:(index===0?0:1) as 0|1}));
    const colours=['#16737a','#ac482e','#8055b1','#357f45','#b08021','#4b6ea7'];
    state.units.forEach((unit,index)=>{presentation[unit.id]={color:colours[index],label:`Company ${index+1}`,name:`Adventurer ${index+1}`}});
    const html=renderToStaticMarkup(createElement(Board,{state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',interactive:true,onCell:()=>{},boardRadius:radius,unitPresentation:presentation,presentationOnlyRules:true,controllableUnitIds:[state.units[0].id],deploymentZones:starts.map((tiles,index)=>({tiles,label:`Company ${index+1}`,color:colours[index]}))}));
    assert.equal((html.match(/data-tile="/g)||[]).length,state.cells.length);
    for(const point of [{q:radius,r:0},{q:0,r:radius},{q:-radius,r:0}])assert.ok(html.includes(`data-tile="${formatTile(point,radius)}"`));
    assert.ok(!html.includes('data-tile="—"'));
    const bounds=battlefieldBounds(state.cells);
    assert.ok(html.includes(`viewBox="${bounds.left} ${bounds.top} ${bounds.right-bounds.left} ${bounds.bottom-bounds.top}"`));
    for(let index=0;index<count;index++){
      assert.ok(html.includes(`Adventurer ${index+1} · Company ${index+1}`));
      assert.ok(html.includes(`data-deployment-zone="Company ${index+1}"`));
      assert.ok(html.includes(`fill="${colours[index]}"`));
    }
  }
});

test('a rival on a six-player board animates the canonical resolved route instead of the legacy opposing-side detour',()=>{
  const before=createArena({playerCount:6,seed:'WELLSPRING'}),unit=before.units.find(unit=>unit.owner===1&&unit.championId==='oh_tipi')!,target={q:-4,r:-9};
  assert.deepEqual({q:unit.q,r:unit.r},{q:0,r:-10});
  const expected=arenaMovementPath(before,unit.id,target)!.map(({q,r})=>({q,r}));
  assert.deepEqual(expected,[{q:-1,r:-10},{q:-2,r:-10},{q:-3,r:-10},{q:-4,r:-9}]);
  const plans:ArenaPlan[]=Array.from({length:6},()=>({orders:[]}));plans[1]={orders:[{unitId:unit.id,move:target}]};
  const after=resolveArena(before,plans),shownBefore=presentArena(before,0),shownAfter=presentArena(after,0);
  const oldMotion=battlefieldMotion(shownBefore,shownAfter,unit.id)!;
  assert.notDeepEqual(oldMotion.movePath,expected,'Fixture must expose the opposing-side v16 tie break');
  const fixedBefore=canonicalMotionSnapshot(shownBefore,true),fixedAfter=canonicalMotionSnapshot(shownAfter,true),motion=battlefieldMotion(fixedBefore,fixedAfter,unit.id)!;
  assert.deepEqual(motion.movePath,expected);
  assert.deepEqual(groundContacts(fixedBefore,fixedAfter).find(contact=>contact.unitId===unit.id)!.point,target);
  assert.equal(shownBefore.units.find(entry=>entry.id===unit.id)!.owner,1,'The real presentation allegiance is untouched');
  assert.equal(canonicalMotionSnapshot(shownBefore,false),shownBefore,'Legacy story motion remains unchanged');
  const html=renderToStaticMarkup(createElement(Board,{state:shownAfter,previousState:shownBefore,plan:{orders:[]},player:0,selected:shownAfter.units[0].id,kind:'move',interactive:false,onCell:()=>{},boardRadius:13,presentationOnlyRules:true,resolving:true,playback:{active:true,phase:'move',key:7}}));
  for(const frame of motion.frames.filter(frame=>frame.phase==='move'))assert.ok(html.includes(`transform:translate(${frame.x}px,${frame.y}px)`),'The shipped renderer uses each authoritative waypoint');
  const wrong=oldMotion.frames.find(frame=>frame.point.q===-2&&frame.point.r===-9)!;
  assert.ok(!html.includes(`transform:translate(${wrong.x}px,${wrong.y}px)`),'The old opposing-side detour is absent from the rendered motion');
});

test('movement advice re-labels both in-range and outer-ring occupancy in the current map coordinates',()=>{
  for(const target of [{q:-10,r:0},{q:0,r:0}]){
    const label=formatTile(target,13);
    assert.equal(movementAdviceText('Treevor stays on —; this move will bounce.',target,13),`Treevor stays on ${label}; this move will bounce.`);
    assert.equal(movementAdviceText('Oh Tipi occupies J10. This move bounces if they stay.',target,13),`Oh Tipi occupies ${label}. This move bounces if they stay.`);
  }
  const state=presentArena(createArena({playerCount:6}),0),mover=state.units[0],blocker=state.units[1],point={q:blocker.q,r:blocker.r};
  const html=renderToStaticMarkup(createElement(Board,{state,plan:{orders:[{unitId:mover.id,move:point}]},player:0,selected:mover.id,kind:'move',interactive:true,onCell:()=>{},boardRadius:13,presentationOnlyRules:true,legalTargets:[point]}));
  assert.ok(html.includes(`stays on ${formatTile(point,13)}`));
  assert.ok(!html.includes('stays on —'));
});

test('one actual cast among seventeen guards frames the encounter; an idle exchange falls back to the viewer company',()=>{
  const before=createArena({playerCount:6}),caster=before.units[3],target=arenaLegalCasts(before,caster.id,undefined,'water_jet').find(cell=>cell.q!==caster.q||cell.r!==caster.r)!;
  const plans:ArenaPlan[]=Array.from({length:6},()=>({orders:[]}));plans[1]={orders:[{unitId:caster.id,spellId:'water_jet',cast:{q:target.q,r:target.r}}]};
  const after=resolveArena(before,plans),old=presentArena(before,0),shown=presentArena(after,0),own=before.units.filter(unit=>unit.owner===0).map(unit=>unit.id);
  assert.equal(after.lastResolution.filter(event=>event.kind==='guard').length,17);
  const active=resolutionActorIds(old,shown,shown.lastResolution,own,true);
  assert.ok(active.has(caster.id));assert.ok(active.size<4,'Distant guarding companies never become camera anchors');
  const points=(ids:Set<string>)=>shown.units.filter(unit=>ids.has(unit.id)).map(unit=>surfacePoint(unit,shown.cells.find(cell=>cell.q===unit.q&&cell.r===unit.r)?.height));
  const all=resolutionActorIds(old,shown,shown.lastResolution,own,false),viewport={width:960,height:500};
  const action=[surfacePoint(caster),surfacePoint(target)];
  assert.ok(fitEffect([...action,...points(active)],viewport).scale<fitEffect([...action,...points(all)],viewport).scale*.5,'A local cast stays at least twice as legible as the full-board frame');
  const idle=resolveArena(before,Array.from({length:6},()=>({orders:[]}))),idleShown=presentArena(idle,0);
  assert.deepEqual([...resolutionActorIds(old,idleShown,idleShown.lastResolution,own,true)].sort(),own.sort());
  assert.equal(resolutionActorIds(old,idleShown,idleShown.lastResolution,[],true).size,18,'Spectators without a company retain a safe overview fallback');
});
