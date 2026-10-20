import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,towerRoomChoices,chooseTowerRoom,createTowerSession,restoreTowerSession,type TowerRoom,type TowerActor} from '../lib/tower-v23.ts';
import {towerRoomIntel} from '../lib/tower-scouting.ts';
import {getSpell} from '../lib/spells-v20.ts';

// Render real source, including accessible names and title attributes. Merely
// hiding a full enemy card with CSS would fail these disclosure checks.
const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{
  if(specifier.endsWith('.css'))return {};
  if(specifier.endsWith('TowerBattleV23'))return {__esModule:true,default:()=>null};
  if(!specifier.startsWith('.'))return nodeRequire(specifier);
  const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);
  return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
 };
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const reportModule=loadSource(fileURLToPath(new URL('../app/components/TowerScouting.tsx',import.meta.url))),towerModule=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url)));
const Report=reportModule.TowerRoomReport as ComponentType<{room:TowerRoom;compact?:boolean}>,Choices=towerModule.TowerRoomChoices as ComponentType<{rooms:TowerRoom[];onChoose:(id:string)=>void;onInspect:(actor:TowerActor)=>void;leadHp?:number}>,Inspection=towerModule.TowerEnemyInspection as ComponentType<{actor:TowerActor}>;
const html=(element:ReturnType<typeof createElement>)=>renderToStaticMarkup(element).replaceAll('&#x27;',"'").replaceAll('&amp;','&'),noop=()=>{};
function forbiddenInspection(markup:string){assert.doesNotMatch(markup,/Inspect spells|enemy spells|Enemy spell kit|data-spell-id=|maximum Flux|\d+ HP|affinity [1-6]/);}

test('route reports disclose only selected evidence, including in titles and accessible labels',()=>{
 let checked=0;
 for(const seed of ['SCOUT-A','SCOUT-B'])for(const starter of ['steam','stone','dusk'])for(const floor of [1,2,4,5,7,8,9]){
  const run={...createTowerRun(seed,starter),floor};
  for(const room of towerRoomChoices(run).filter(room=>room.enemies.length)){
   const before=JSON.stringify(room),intel=towerRoomIntel(room),markup=html(createElement(Report,{room}));
   assert.match(markup,/Unknown/);assert.ok(markup.includes(intel.risk));assert.ok(markup.includes(`${room.enemies.length} ${room.enemies.length===1?'enemy':'enemies'}`));
   assert.ok(intel.clues.some(clue=>clue.elements?.length),'Every report needs an actionable elemental clue');
   for(const enemy of room.enemies){if(enemy.displayName!==intel.knownEnemy?.name)assert.ok(!markup.includes(enemy.displayName!),`${room.id} leaked ${enemy.displayName}`);}
   forbiddenInspection(markup);
   assert.equal(JSON.stringify(room),before,'Scouting cannot change the actual encounter');checked++;
  }
 }
 assert.ok(checked>=90);
});

test('sibling combat doors offer different evidence and retain public stakes without full inspection buttons',()=>{
 const rooms=towerRoomChoices(createTowerRun('DOOR-CHOICE','steam')),markup=html(createElement(Choices,{rooms,onChoose:noop,onInspect:()=>assert.fail('An unseen enemy cannot be inspected')}));
 assert.equal(new Set(rooms.map(room=>towerRoomIntel(room).profile)).size,3);
 assert.equal((markup.match(/<button\b/g)??[]).length,rooms.length,'Only room entry is actionable before commitment');
 assert.equal((markup.match(/Unknown/g)??[]).length,rooms.length);
 for(const room of rooms){const intel=towerRoomIntel(room);assert.ok(markup.includes(intel.reward));assert.ok(markup.includes(`Enter ${room.name}`));}
 assert.doesNotMatch(markup,/title="Inspect|aria-label="Inspect|t22-enemy-preview|data-spell-id=/);
});

test('safe-room costs remain explicit and low-health tuition cannot be selected',()=>{
 const rooms=towerRoomChoices({...createTowerRun('SAFE-DOORS'),floor:3}),markup=html(createElement(Choices,{rooms,onChoose:noop,onInspect:noop,leadHp:2}));
 assert.match(markup,/2 HP/);assert.match(markup,/3 HP|3 health/);assert.match(markup,/<button[^>]*disabled=""[^>]*>/);
 assert.match(markup,/Starting champions stay/);assert.match(markup,/Party limit: 3/);
 for(const room of rooms)assert.ok(markup.includes(towerRoomIntel(room).reward));
 assert.doesNotMatch(markup,/enemy spells|Inspect spells/);
});

test('summit scouting uses the same partial report and never reveals the full boss roster early',()=>{
 const room=towerRoomChoices({...createTowerRun('SUMMIT-SCOUT'),floor:9})[0],intel=towerRoomIntel(room),markup=html(createElement(Report,{room,compact:true}));
 assert.match(markup,/data-compact="true"/);assert.match(markup,/Final battle/);assert.match(markup,/Unknown/);
 for(const enemy of room.enemies)if(enemy.displayName!==intel.knownEnemy?.name)assert.ok(!markup.includes(enemy.displayName!));
 forbiddenInspection(markup);
 const routeSource=readFileSync(new URL('../app/components/TowerGameV23.tsx',import.meta.url),'utf8');
 assert.doesNotMatch(routeSource,/summit\.enemies\.map/,'The sidebar must not bypass the report projection');
});

test('entering a scouted room keeps its real enemy kit and save identity intact for full inspection',()=>{
 const run=createTowerRun('COMMIT-THEN-INSPECT'),room=towerRoomChoices(run)[0],intel=towerRoomIntel(room),before=JSON.stringify(run);
 html(createElement(Choices,{rooms:[room],onChoose:noop,onInspect:noop}));assert.equal(JSON.stringify(run),before);
 const session=createTowerSession(chooseTowerRoom(run,room.id)),restored=restoreTowerSession(JSON.stringify(session));
 assert.deepEqual(restored.run.currentRoom,room);assert.deepEqual(restored.battle?.tower?.enemies,session.battle?.tower?.enemies);
 for(const enemy of room.enemies){const markup=html(createElement(Inspection,{actor:enemy}));assert.ok(markup.includes(enemy.displayName!));for(const id of enemy.loadout)assert.ok(markup.includes(getSpell(id).name));assert.match(markup,/Enemy spell kit/);}
 assert.ok(intel.unknowns.length>0,'The route report remains partial even though entry has revealed the encounter');
});
