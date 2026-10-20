import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,towerFloorRooms,type TowerRun} from '../lib/tower-v23.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(specifier.endsWith('TowerBattleV23'))return {__esModule:true,default:()=>null};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const source=loadSource(fileURLToPath(new URL('../app/components/TowerRouteMap.tsx',import.meta.url)));
const Route=source.default as ComponentType<Record<string,unknown>>,RouteMapView=source.TowerRouteMap as ComponentType<Record<string,unknown>>,layout=source.routeMapLayout as (lanes:number)=>{width:number;height:number;minWidth:number;position:(floor:number,lane:number)=>{x:number;y:number}},previewRoomId=source.previewRoomId as (rooms:readonly {id:string}[],preview:string|undefined,committed?:string|null)=>string|undefined;
const committedPreviewId=source.committedPreviewId as (rooms:readonly {id:string}[],preview:string|undefined,previous?:string|null,committed?:string|null)=>string|undefined;
const render=(props:Record<string,unknown>)=>renderToStaticMarkup(createElement(Route,{onChoose:()=>{},onScout:()=>{},...props})).replaceAll('&#x27;',"'").replaceAll('&amp;','&');

test('one to six player routes fit every lane in a phone-width overview without horizontal scrolling',()=>{
 for(let players=1;players<=6;players++){
  const lanes=players+2,run={...createTowerRun(`LAYOUT-${players}`),routePlayers:players},plan=layout(lanes),markup=render({run});
  assert.equal((markup.match(/class="trm-node"/g)??[]).length,lanes*8+1);
  assert.equal((markup.match(/data-current="true"/g)??[]).length,lanes);
  assert.match(markup,new RegExp(`aria-label="${lanes} tower paths"`));
  assert.ok(markup.includes(`viewBox="0 0 ${plan.width} ${plan.height}"`));
  for(let lane=0;lane<lanes;lane++){
   const point=plan.position(1,lane),phoneX=point.x/plan.width*274;assert.ok(phoneX>=13&&phoneX<=274-13);
   if(lane)assert.ok((point.x-plan.position(1,lane-1).x)/plan.width*274>26,'phone overview nodes must not overlap');
   assert.ok(markup.includes(`Path ${String.fromCharCode(65+lane)}`));
  }
  assert.equal(plan.position(9,0).x,plan.width/2);
  assert.equal(plan.minWidth,0);assert.doesNotMatch(markup,/trm-scroll|trm-min-width/);
  const controls=markup.match(/<nav class="trm-doors"[^>]*>([\s\S]*?)<\/nav>/)![1];
  assert.equal((controls.match(/<button /g)??[]).length,lanes,'every path has a large equivalent room control');
 }
});

test('the wider menu keeps one selected room, exposes eight named doors and preserves shared-party identity',()=>{
 const run={...createTowerRun('EIGHT-DOORS'),routePlayers:6},markup=render({run,roomPlayers:{'floor-1-7':['You','Moss']},lockedChoice:'floor-1-7'});
 assert.equal((markup.match(/class="trp43"/g)??[]).length,1);
 assert.equal((markup.match(/class="trm-node"[^>]*data-chosen="true"/g)??[]).length,1);
 assert.match(markup,/Path H/);assert.match(markup,/You/);assert.match(markup,/Moss/);
 assert.match(markup,/aria-pressed="true"/);
});

test('duplicated service names remain distinguishable by path and legacy routes stay three lanes',()=>{
 const start={...createTowerRun('SERVICE-PATHS'),routePlayers:6},run={...start,floor:3,history:[]} as TowerRun;
 const rooms=towerFloorRooms(run);assert.equal(rooms.length,8);assert.ok(new Set(rooms.map(room=>room.name)).size<rooms.length);
 const markup=render({run});for(const letter of 'ABCDEFGH')assert.ok(markup.includes(`Path ${letter}`));
 const legacy={...createTowerRun('LEGACY-PATHS')};delete legacy.routePlayers;
 const old=render({run:legacy});assert.equal((old.match(/class="trm-node"/g)??[]).length,25);assert.match(old,/viewBox="0 0 800 300"/);
 assert.doesNotMatch(old,/Path D/);
});

test('committing a room does not lock other previews and the chosen destination remains distinct',()=>{
 const run={...createTowerRun('CHOSEN-PREVIEW'),routePlayers:6},rooms=towerFloorRooms(run);
 assert.equal(previewRoomId(rooms,'floor-1-0','floor-1-7'),'floor-1-0');
 assert.equal(previewRoomId(rooms,'floor-2-0','floor-1-7'),'floor-1-7');
 assert.equal(previewRoomId(rooms,undefined,null),'floor-1-0');
 const markup=render({run,lockedChoice:'floor-1-7'}),controls=markup.match(/<nav class="trm-doors"[^>]*>([\s\S]*?)<\/nav>/)![1];
 assert.doesNotMatch(controls,/disabled=/);assert.equal((controls.match(/data-committed="true"/g)??[]).length,1);assert.match(controls,/✓ Chosen/);
 const map=renderToStaticMarkup(createElement(RouteMapView,{run,selected:'floor-1-0',committed:'floor-1-7'}));
 assert.match(map,/data-chosen="true" data-committed="false"/);assert.match(map,/data-chosen="false" data-committed="true"/);
});

test('friends are visible on unpreviewed destination cards and combined counts are used when supplied',()=>{
 const run={...createTowerRun('FRIENDS-ALL-CARDS'),routePlayers:6},markup=render({run,cooperative:true,roomPlayers:{'floor-1-2':['Ada'],'floor-1-7':['Moss','Fern']},encounterCount:(id:string)=>id==='floor-1-7'?7:undefined});
 const controls=markup.match(/<nav class="trm-doors"[^>]*>([\s\S]*?)<\/nav>/)![1];
 assert.equal((controls.match(/class="trm-door-company"/g)??[]).length,2);assert.match(controls,/Ada/);assert.match(controls,/Moss/);assert.match(controls,/Fern/);assert.match(controls,/7 enemies/);
 assert.match(controls,/class="trm-door-company" title="Moss · Fern"/);
 const busy=render({run,disabled:true}),busyControls=busy.match(/<nav class="trm-doors"[^>]*>([\s\S]*?)<\/nav>/)![1];
 assert.equal((busyControls.match(/disabled=""/g)??[]).length,8);
});

test('joining a new destination updates its preview once while later inspection and withdrawal keep the chosen preview',()=>{
 const rooms=towerFloorRooms({...createTowerRun('JOIN-PREVIEW'),routePlayers:6});
 assert.equal(committedPreviewId(rooms,'floor-1-0',null,'floor-1-7'),'floor-1-7');
 assert.equal(committedPreviewId(rooms,'floor-1-1','floor-1-7','floor-1-7'),'floor-1-1','polling the same commitment must not undo manual inspection');
 assert.equal(committedPreviewId(rooms,'floor-1-1','floor-1-7',null),'floor-1-1','withdrawing keeps the inspected room');
 assert.equal(committedPreviewId(rooms,'floor-1-1','floor-1-7','floor-1-2'),'floor-1-2','a direct replacement previews the new destination');
 assert.equal(committedPreviewId(rooms,'floor-1-1',null,'floor-2-0'),'floor-1-1','an unavailable destination cannot steal the preview');
});
