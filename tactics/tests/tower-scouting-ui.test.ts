import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,towerChampion,towerRoomChoices,type TowerRun,type TowerRoom,type TowerStart,type TowerMemberInput} from '../lib/tower-v23.ts';
import {getSpell,availableSpellIds} from '../lib/spells-v20.ts';
import {towerRoomIntel} from '../lib/tower-scouting.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';
import {scoutTowerRoom,towerScoutReports,towerScoutsAvailable,type ScoutReport} from '../lib/tower-scouting-actions.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(specifier.endsWith('TowerBattleV23'))return {__esModule:true,default:()=>null};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const loaded=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url))),report=loadSource(fileURLToPath(new URL('../app/components/TowerScouting.tsx',import.meta.url)));
const Choices=loaded.TowerRoomChoices as ComponentType<{rooms:TowerRoom[];run:TowerRun;onChoose:(id:string)=>void;onScout:(actorId:string,roomId:string)=>void;scoutReports?:readonly ScoutReport[]}>;
const Report=report.TowerRoomReport as ComponentType<{room:TowerRoom;scoutReports?:readonly ScoutReport[]}>;
const noop=()=>{},render=(element:ReturnType<typeof createElement>)=>renderToStaticMarkup(element).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
const html=(run:TowerRun,scoutReports:readonly ScoutReport[]=[])=>render(createElement(Choices,{run,rooms:towerRoomChoices(run),onChoose:noop,onScout:noop,scoutReports}));
const scoutButtons=(markup:string)=>markup.match(/<button\b[^>]*class="t23-scout-action"[^>]*>[\s\S]*?<\/button>/g)??[];
const unknowns=(markup:string)=>markup.match(/<p class="t23-unknown">[\s\S]*?<\/p>/)?.[0]??'';
const champion=(id:string):TowerMemberInput=>{const actor=towerChampion(id,'temporary');return {kind:'champion',build:{championId:id,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout}};};
const start:TowerStart={starterId:'steam',members:[champion('oh_tipi'),champion('treevor_mason')]};

test('room controls show two champion scouts, then one, then none using persisted model state',()=>{
 let run=createTowerRun('SCOUT-UI',start),markup=html(run);assert.match(markup,/2 scouts left/);assert.equal((markup.match(/data-ready="true"/g)??[]).length,2);assert.equal(scoutButtons(markup).length,3);assert.ok(scoutButtons(markup).every(button=>!button.includes('disabled=""')));
 for(const room of towerRoomChoices(run))assert.ok(markup.includes(`aria-label="Scout ${room.name} with ${run.party[0].displayName}"`));
 run=scoutTowerRoom(run,'hero','floor-1-0');markup=html(run);assert.match(markup,/1 scout left/);assert.equal((markup.match(/data-ready="true"/g)??[]).length,1);assert.equal((markup.match(/data-ready="false"/g)??[]).length,1);assert.ok(scoutButtons(markup).every(button=>button.includes(`with ${run.party[1].displayName}`)&&!button.includes('disabled=""')));
 run=scoutTowerRoom(run,'companion','floor-1-1');markup=html(run);assert.match(markup,/0 scouts left/);assert.equal((markup.match(/data-ready="false"/g)??[]).length,2);assert.ok(scoutButtons(markup).every(button=>button.includes('disabled=""')&&button.includes('No scouts left')));
 assert.equal((markup.match(/>Enter /g)??[]).length,3,'Spending scouts must not prevent choosing a door');
});

test('shared reports are visible without using the receiving squad’s scouting actions',()=>{
 const run=createTowerRun('SHARED-UI',start),other=scoutTowerRoom(run,'hero','floor-1-0'),reports=other.scouting!.reports,before=JSON.stringify(run),markup=html(run,reports);
 assert.match(markup,/2 scouts left/);assert.match(markup,/Scouted · 1/);assert.ok(markup.includes(reports[0].label));assert.ok(markup.includes(reports[0].detail));assert.ok(scoutButtons(markup).every(button=>!button.includes('disabled=""')));assert.equal(towerScoutsAvailable(run).length,2);assert.equal(JSON.stringify(run),before);
 const wrong=scoutTowerRoom(createTowerRun('OTHER-UI',start),'hero','floor-1-0');assert.doesNotMatch(html(run,wrong.scouting!.reports),/Scouted · 1/);
});

test('safe service floors have no scouting action while creature squads retain honest free clues',()=>{
 const services={...createTowerRun('SERVICES-UI',start),floor:3},markup=html(services);assert.equal(scoutButtons(markup).length,0);assert.doesNotMatch(markup,/Champion scouts|scouts left|One random detail/);assert.match(markup,/2 HP/);assert.equal((markup.match(/>Enter /g)??[]).length,3);
 const creatures=createTowerRun('CREATURES-UI',{starterId:'steam',members:[{kind:'creature',creatureId:'creature-fire-cinder'},{kind:'creature',creatureId:'creature-water-puddle'}]}),small=html(creatures);assert.match(small,/0 scouts left/);assert.match(small,/Recruit a champion to scout/);assert.ok(scoutButtons(small).every(button=>button.includes('disabled=""')));assert.match(small,/Unknown/);assert.match(small,/Affinities detected/);
});

test('a ground report removes Terrain from unknowns while unseen spells always remain',()=>{
 const run=createTowerRun('TERRAIN-UI',start),room=towerRoomChoices(run).find(room=>towerRoomIntel(room).environment===undefined)!,facts=scoutFactsForRoom(run,room),terrain=facts.find(fact=>fact.kind==='environment')!;
 const before=render(createElement(Report,{room}));assert.match(unknowns(before),/Terrain/);
 const after=render(createElement(Report,{room,scoutReports:[terrain]}));assert.doesNotMatch(unknowns(after),/Terrain/);assert.match(unknowns(after),/Unseen spells/);assert.ok(after.includes(terrain.detail));
 const full=render(createElement(Report,{room,scoutReports:facts}));assert.match(unknowns(full),/Unseen spells/);assert.doesNotMatch(unknowns(full),/Some enemy identities|Terrain/);
});

test('revealed information consistently identifies numbered enemies and keeps older reports accessible',()=>{
 const run=createTowerRun('NUMBERED-UI',start),room=towerRoomChoices(run)[0],intel=towerRoomIntel(room),facts=scoutFactsForRoom(run,room),markup=render(createElement(Report,{room,scoutReports:facts}));
 if(intel.knownEnemy)assert.ok(markup.includes(`Enemy ${intel.knownEnemy.position}`));
 for(const fact of facts){assert.ok(markup.includes(fact.label));assert.ok(markup.includes(fact.detail));if(fact.enemyId){const index=room.enemies.findIndex(enemy=>enemy.id===fact.enemyId);assert.ok(fact.label.startsWith(`Enemy ${index+1} ·`));}}
 assert.ok(facts.length>3);assert.match(markup,/<details>/);assert.ok(markup.includes(`${facts.length-3} earlier`));
});

test('even every available report omits each enemy’s reserved spell and cannot unlock further scouting',()=>{
 for(const seed of ['RESERVED-A','RESERVED-B'])for(const floor of [1,4,9]){
  const run={...createTowerRun(seed,start),floor};for(const room of towerRoomChoices(run).filter(room=>room.enemies.length)){
   const facts=scoutFactsForRoom(run,room),visible=towerScoutReports(run,room.id,facts),markup=render(createElement(Report,{room,scoutReports:visible}));assert.match(unknowns(markup),/Unseen spells/);
   for(const [index,enemy] of room.enemies.entries()){
    const kit=enemy.creatureId?enemy.loadout:availableSpellIds(enemy.championId,enemy.loadout,enemy.affinities),known=visible.filter(fact=>fact.enemyId===enemy.id&&fact.kind==='spell').map(fact=>fact.spellId),reserved=kit.filter(id=>!known.includes(id));assert.equal(reserved.length,1);
    const spellRows=[...markup.matchAll(/<dt>([\s\S]*?)<\/dt><dd>([\s\S]*?)<\/dd>/g)].filter(([,label])=>label===`Enemy ${index+1} · equipped spell`).map(([, ,detail])=>detail.replace(/<[^>]*>/g,''));
    assert.equal(spellRows.length,new Set(kit).size-1);for(const id of reserved)assert.ok(spellRows.every(row=>!row.startsWith(`${getSpell(id).name} ·`)));
   }
   const choices=render(createElement(Choices,{run,rooms:[room],onChoose:noop,onScout:noop,scoutReports:facts})),buttons=scoutButtons(choices),button=buttons[0];assert.equal(buttons.length,1);assert.ok(button);assert.ok(button.includes('disabled=""'));assert.ok(button.includes('Remaining details concealed'));
  }
 }
});
