import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createSimGame,resolveRound,endgameForecast,legalCasts,type TeamPlan} from '../lib/tactics-v18.ts';
import {createSimGame as legacyGame} from '../lib/tactics-v16.ts';
import {presentArena} from '../lib/skirmish-client-v18.ts';
import {endgameCellState,endgameCellDescription,endgameBoundaries} from '../lib/endgame-presentation-v18.ts';
import {resolutionActorIds} from '../lib/battlefield-presentation-v17.ts';
import {formatTile} from '../lib/board-labels-v17.ts';
import {surfacePoint,TILE_HALF_HEIGHT} from '../lib/battlefield-geometry.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown> {
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const requireLocal=(specifier:string):unknown=>{
  if(specifier.endsWith('.css'))return {};
  if(!specifier.startsWith('.'))return nodeRequire(specifier);
  const target=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(suffix=>target+suffix).find(existsSync);
  assert.ok(found,`Missing renderer dependency ${specifier}`);
  return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
 };
 new Function('require','module','exports',js)(requireLocal,module,module.exports);return module.exports;
}
type BoardProps=ComponentProps<typeof import('../app/components/PixelBattlefieldV16.tsx').default>;
const Board=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV16.tsx',import.meta.url))).default as ComponentType<BoardProps>;
const render=(props:Partial<BoardProps>&Pick<BoardProps,'state'>)=>renderToStaticMarkup(createElement(Board,{plan:{orders:[]},player:0,selected:props.state.units[0].id,kind:'move',interactive:true,onCell:()=>{},...props}));
const guards=(count:number):TeamPlan[]=>Array.from({length:count},()=>({orders:[]}));
const tileLabel=(html:string,q:number,r:number,radius:number)=> {
 const tile=formatTile({q,r},radius),tag=[...html.matchAll(/<g[^>]*data-tile="[^"]*"[^>]*>/g)].map(match=>match[0]).find(tag=>tag.includes(`data-tile="${tile}"`));
 assert.ok(tag,`Missing tile ${tile}`);return tag.match(/aria-label="([^"]*)"/)?.[1]??'';
};

test('danger and warning occupy separate rings and report exact consequences',()=>{
 const state=createSimGame({playerCount:6}),calm=endgameForecast(state),warning=endgameForecast({...state,round:12}),closing=endgameForecast({...state,round:14});
 assert.equal(endgameCellState(calm,{q:13,r:0}),'safe');assert.equal(endgameCellDescription(calm,{q:13,r:0}),'');
 assert.equal(endgameCellState(warning,{q:12,r:0}),'closing');assert.equal(endgameCellState(warning,{q:11,r:0}),'safe');
 assert.match(endgameCellDescription(warning,{q:12,r:0}),/round 14; 1 damage/);
 assert.equal(endgameCellState(closing,{q:12,r:0}),'unsafe');assert.equal(endgameCellState(closing,{q:10,r:0}),'closing');assert.equal(endgameCellState(closing,{q:9,r:0}),'safe');
 assert.match(endgameCellDescription(closing,{q:12,r:0}),/1 damage after this exchange/);
 assert.match(endgameCellDescription(closing,{q:10,r:0}),/round 16; 2 damage/);
 const final=endgameForecast({...state,round:26});assert.equal(endgameCellState(final,{q:0,r:0}),'safe');
 assert.equal(state.cells.filter(cell=>endgameCellState(final,cell)==='safe').length,1);
 assert.ok(state.cells.filter(cell=>cell.q||cell.r).every(cell=>endgameCellState(final,cell)==='unsafe'));
});

test('boundary strokes follow the elevated outer edge and never draw an internal hex grid',()=>{
 const state=createSimGame({playerCount:6}),warning=endgameForecast({...state,round:12});
 const early=endgameBoundaries(warning,state.cells);assert.equal(early.current,'');assert.equal((early.next.match(/M/g)||[]).length,6*(2*11+1));
 const closing=endgameBoundaries(endgameForecast({...state,round:14}),state.cells);
 assert.equal((closing.current.match(/M/g)||[]).length,6*(2*11+1));assert.equal((closing.next.match(/M/g)||[]).length,6*(2*9+1));
 const final=endgameBoundaries(endgameForecast({...state,round:26}),state.cells);assert.equal((final.current.match(/M/g)||[]).length,6);assert.equal(final.next,'');
 const centre=state.cells.find(cell=>cell.q===0&&cell.r===0)!,at=surfacePoint(centre,centre.height);assert.ok(final.current.includes(`M${at.x} ${at.y-TILE_HALF_HEIGHT}`));
 assert.deepEqual(endgameBoundaries(undefined,state.cells),{current:'',next:''});
});

test('the actual board keeps next-round collapse out of movement, casting and impact playback',()=>{
 const before=createSimGame({playerCount:2});before.round=9;before.version=9;
 const after=resolveRound(before,guards(2)),zone=endgameForecast(after),previousZone=endgameForecast(before);
 assert.equal(zone.damage,1);assert.equal(previousZone.damage,0);
 for(const phase of ['move','cast','impact','settle'] as const){
  const html=render({state:presentArena(after,0),previousState:presentArena(before,0),resolving:true,playback:{active:true,phase,key:9},boardRadius:9,presentationOnlyRules:true,endgameZone:zone,previousEndgameZone:previousZone});
  const label=tileLabel(html,8,0,9);
  if(phase==='settle'){
   assert.ok(html.includes('data-endgame-cell="unsafe"'));assert.ok(html.includes('data-endgame-boundary="current"'));assert.match(label,/1 damage after this exchange/);
  }else{
   assert.ok(!html.includes('data-endgame-cell="unsafe"'));assert.ok(!html.includes('data-endgame-boundary="current"'));assert.match(label,/becomes unsafe in round 10/);
  }
  assert.ok(html.includes('data-endgame-boundary="next"'));
 }
});

test('legacy story and a calm multiplayer board have no danger geometry, while final closure leaves the centre clear',()=>{
 const story=render({state:legacyGame()});assert.ok(!story.includes('data-endgame-cell'));assert.ok(!story.includes('data-endgame-boundary'));
 const state=createSimGame({playerCount:6}),base={state:presentArena(state,0),boardRadius:13,presentationOnlyRules:true};
 const calm=render({...base,endgameZone:endgameForecast(state)});assert.ok(!calm.includes('data-endgame-cell'));
 const final=render({...base,endgameZone:endgameForecast({...state,round:26})});
 assert.equal((final.match(/data-endgame-cell="unsafe"/g)||[]).length,546);assert.ok(!final.includes('data-endgame-coordinate="0,0"'));
 assert.ok(!final.includes('data-endgame-boundary="next"'));assert.match(tileLabel(final,1,0,13),/8 damage after this exchange/);
 assert.ok(!tileLabel(final,0,0,13).includes('Collapse:'));
});

test('collapse casualties do not widen a local spell camera, but the viewer affected company stays visible',()=>{
 const before=createSimGame({playerCount:6});before.round=24;before.version=24;
 // Preserve canonical terrain. One rival casts near centre, while other companies camp outside.
 const caster=before.units[3];Object.assign(caster,{q:0,r:0});
 const target=legalCasts(before,caster.id,undefined,'water_jet').find(cell=>cell.q===0&&cell.r===1)!;assert.ok(target);
 const plans=guards(6);plans[1]={orders:[{unitId:caster.id,spellId:'water_jet',cast:{q:target.q,r:target.r}}]};
 const after=resolveRound(before,plans),old=presentArena(before,0),shown=presentArena(after,0),own=before.units.filter(unit=>unit.owner===0).map(unit=>unit.id);
 const active=resolutionActorIds(old,shown,shown.lastResolution,own,true);
 assert.ok(active.has(caster.id));for(const id of own)assert.ok(active.has(id));
 const remote=before.units.filter(unit=>unit.owner>=2).map(unit=>unit.id);for(const id of remote)assert.ok(!active.has(id));
 assert.ok(after.lastResolution.filter(event=>event.cause==='collapse').length>=15);
 const all=resolutionActorIds(old,shown,shown.lastResolution,own,false);assert.equal(all.size,18,'Legacy all-company framing is unchanged');
});

