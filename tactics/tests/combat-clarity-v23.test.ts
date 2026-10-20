import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {flightPoint,effectAccentCells,healthBarTicks,conditionChanges} from '../lib/combat-clarity-v23.ts';
import {groundPoint} from '../lib/battlefield-geometry.ts';
import {createSimGame,spellArea,type SimState} from '../lib/tactics-v16.ts';
import {projectileMeetingMs,PHASE_MS,RESOLUTION_MS,DISPLACEMENT_END_MS} from '../lib/feedback-v16.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const Board=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV16.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const render=(state:SimState,extra:Record<string,unknown>={})=>renderToStaticMarkup(createElement(Board,{state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',interactive:true,onCell:()=>{},...extra}));

test('flight coordinates keep one plane and preserve affine crossing geometry',()=>{
 for(const point of [{q:0,r:0},{q:-2,r:3},{q:.25,r:-.5}]){
  const at=flightPoint(point),ground=groundPoint(point);assert.deepEqual(at,{x:ground.x,y:ground.y-44});
 }
 const a={q:-3,r:1},b={q:3,r:-1},mid=flightPoint({q:0,r:0}),start=flightPoint(a),end=flightPoint(b);
 assert.equal((start.x+end.x)/2,mid.x);assert.equal((start.y+end.y)/2,mid.y);
});

test('large effect accents are distributed, bounded, deterministic and never change the footprint',()=>{
 const cells=createSimGame().cells.filter(cell=>Math.abs(cell.q)<=3&&Math.abs(cell.r)<=3),snapshot=JSON.stringify(cells),center={q:0,r:0};
 const accents=effectAccentCells(cells,center);assert.equal(accents.size,5);assert.ok(!accents.has('0,0'));
 assert.deepEqual(accents,effectAccentCells([...cells].reverse(),center));
 for(const id of accents)assert.ok(cells.some(cell=>`${cell.q},${cell.r}`===id));
 assert.equal(JSON.stringify(cells),snapshot);assert.equal(effectAccentCells(cells,center,0).size,0);
 assert.deepEqual([...effectAccentCells([{q:0,r:0},{q:1,r:0}],center)],['1,0']);
});

test('high-health bars retain precise proportions without a barcode of tiny divisions',()=>{
 assert.equal(healthBarTicks(8).length,7);assert.deepEqual(healthBarTicks(25),[.2,.4,.6,.8]);
 for(const hp of [11,25,60,100,1000]){const ticks=healthBarTicks(hp);assert.ok(ticks.length<10);assert.ok(ticks.every(value=>value>0&&value<1));}
 assert.deepEqual(healthBarTicks(1),[]);assert.deepEqual(healthBarTicks(NaN),[]);
});

test('replay flights stop at the shared meeting plane and keep fixed silhouettes across raised terrain',()=>{
 // A presentation fixture isolates the renderer contract. Resolver collision
 // correctness is covered by projectile-interception integration tests.
 const before=createSimGame(),first=before.units[0],second=before.units[3];
 Object.assign(first,{q:-2,r:0});Object.assign(second,{q:2,r:0});
 before.cells.find(cell=>cell.q===first.q&&cell.r===first.r)!.height=1;
 const after=structuredClone(before);after.version++;
 after.lastResolution=[
  {kind:'cast',unitId:first.id,spellId:'water_jet',from:{q:-2,r:0},to:{q:2,r:0},text:'Water'},
  {kind:'cast',unitId:second.id,spellId:'ember',from:{q:2,r:0},to:{q:-2,r:0},text:'Fire'},
  {kind:'clash',participants:[first.id,second.id],q:0,r:0,meeting:{q:0,r:0},flightFraction:.5,elements:['fire','water'],terrain:'steam',radius:1,text:'Steam'},
 ];
 const html=render(after,{previousState:before,interactive:false,playback:{phase:'cast',active:true,key:1}}),center=flightPoint({q:0,r:0}),left=flightPoint(first),right=flightPoint(second);
 for(const from of [left,right])assert.ok(html.includes(`d="M${from.x} ${from.y}L${center.x} ${center.y}"`));
 assert.equal((html.match(/data-projectile-scale="1"/g)??[]).length,2);assert.ok(!html.includes('data-projectile-scale="2"'));
 assert.equal((html.match(new RegExp(`data-projectile-arrival="${projectileMeetingMs(.5)}"`,'g'))??[]).length,2);
 assert.ok(html.includes(`data-clash-meeting="0,0" transform="translate(${center.x} ${center.y}) scale(1.2)"`));
 assert.ok(!html.includes('data-cast-spell="water_jet"'),'intercepted spells do not also explode at their old targets');
 assert.equal((html.match(/data-clash-ingredients="fire\+water"/g)??[]).length,1);
});

test('all effect hexes remain visible while secondary material bursts are bounded',()=>{
 const before=createSimGame(),actor=before.units[0],after=structuredClone(before),to={q:actor.q+2,r:actor.r};after.version++;
 after.lastResolution=[{kind:'cast',unitId:actor.id,spellId:'water_jet',from:{q:actor.q,r:actor.r},to,text:'Water'}];
 const expected=spellArea(before,actor.id,'water_jet',to,actor),html=render(after,{previousState:before,interactive:false,playback:{phase:'impact',active:true,key:1}});
 assert.equal((html.match(/data-cast-spell="water_jet"/g)??[]).length,expected.length);
 assert.ok((html.match(/data-area-wake=/g)??[]).length<=5);
 assert.ok(!html.includes('class="px-field-rune"'),'playback does not repeat informational runes over material art');
});

test('planning keeps shared order destinations while coordinates focus on the selected actor',()=>{
 const state=createSimGame(),party=state.units.filter(unit=>unit.owner===0),orders=party.map((unit,index)=>({unitId:unit.id,move:{q:-3+index,r:0},guard:true}));
 const html=render(state,{plan:{orders},sharedAlliedOrders:true,presentationOnlyRules:true});
 assert.equal((html.match(/data-order-unit=/g)??[]).length,party.length,'teammate plans stay visible');
 assert.ok((html.match(/data-tile-reference=/g)??[]).length<=2,'no coordinate labels for every teammate order');
 assert.ok((html.match(/class="px-field-rune"/g)??[]).length<=1,'natural water and earth are art rather than repeated symbols');
});

test('comic condition tags report actual changes once, after damage and displacement settle',()=>{
 const before=createSimGame(),after=structuredClone(before),id=after.units[0].id;after.version++;
 after.units[0].hp-=2;after.units[0].statuses={burn:{turns:2,power:1},blind:{turns:1,power:1}};
 const snapshot=JSON.stringify(after),changes=conditionChanges(before,after);
 assert.equal(changes.size,1);assert.deepEqual(changes.get(id),{id:'blind',added:true});
 const casting=render(after,{previousState:before,interactive:false,playback:{phase:'cast',active:true,key:1}});
 assert.ok(!casting.includes('data-condition-feedback='));assert.ok(!casting.includes('data-health-feedback='));
 const settled=render(after,{previousState:before,interactive:false,playback:{phase:'settle',active:true,key:1}});
 assert.equal((settled.match(/data-condition-feedback=/g)??[]).length,1);assert.ok(settled.includes('data-combat-callout="Blind"'));
 assert.ok(settled.includes('data-combat-callout="−2 HP"'));assert.equal(JSON.stringify(after),snapshot);
 const cleansed=structuredClone(after);cleansed.version++;cleansed.units[0].statuses={};
 assert.deepEqual(conditionChanges(after,cleansed).get(id),{id:'blind',added:false});
 assert.equal(conditionChanges(before,cleansed).size,0,'an unrelated snapshot cannot invent a condition change');
 assert.ok(DISPLACEMENT_END_MS<PHASE_MS.settle);assert.ok(RESOLUTION_MS-PHASE_MS.settle>=1300,'the final tags get their complete reading interval');
});
