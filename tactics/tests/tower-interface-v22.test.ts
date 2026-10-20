import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {TOWER_STARTERS,createTowerRun,towerRoomChoices,towerRewardChoices,type TowerRun,type TowerRoom,type TowerReward,type TowerActor} from '../lib/tower-v22.ts';
import {getSpell,getSignature,effectiveSpell,defaultLoadout,spellAccess} from '../lib/spells-v20.ts';
import {getCreature,CREATURE_PERKS} from '../lib/campaign-creatures-v20.ts';
import {createTowerBattle,availableUnitSpellIds} from '../lib/tactics-v22.ts';
import {spellEffectLabel} from '../lib/battle-guidance-v16.ts';
import {CHAMPIONS} from '../lib/roster-v13.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(specifier.endsWith('TowerBattleV22'))return {__esModule:true,default:()=>null};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const components=loadSource(fileURLToPath(new URL('../app/components/TowerGameV22.tsx',import.meta.url))),noop=()=>{};
const Starter=components.TowerStarterPicker as ComponentType<{starterId:string;onSelect:(id:string)=>void}>;
const Choices=components.TowerRoomChoices as ComponentType<{rooms:TowerRoom[];onChoose:(id:string)=>void;onInspect:(actor:TowerActor)=>void;leadHp?:number;eventAllowed?:boolean;eventCostLabel?:string}>;
const Rewards=components.TowerRewardChoices as ComponentType<{run:TowerRun;rewards:TowerReward[];onChoose:(reward:TowerReward)=>void}>;
const Loadout=components.TowerLoadout as ComponentType<{run:TowerRun;actor:TowerActor;onChange:(loadout:string[])=>void}>;
const Progress=components.TowerRouteProgress as ComponentType<{run:TowerRun}>;
const Inspection=components.TowerEnemyInspection as ComponentType<{actor:TowerActor}>;
const Builder=loadSource(fileURLToPath(new URL('../app/components/TowerCharacterBuilderV22.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const html=(element:ReturnType<typeof createElement>)=>renderToStaticMarkup(element).replaceAll('&#x27;',"'").replaceAll('&amp;','&');

test('character configuration exposes every champion, the budget, native signature, and legal save state',()=>{
 const actor=createTowerRun('builder','steam').party[0],initial={championId:actor.championId,name:actor.displayName,affinities:actor.affinities,loadout:actor.loadout};
 const markup=html(createElement(Builder,{initial,onSave:noop,onCancel:noop}));
 for(const champion of CHAMPIONS)assert.ok(markup.includes(`value="${champion.id}"`));
 assert.match(markup,/5\/5/);assert.match(markup,/3 elements max/);assert.ok(markup.includes(getSignature(actor.championId).name));
 assert.match(markup,/<button[^>]*class="t22-primary"[^>]*>Use character/);
 const invalid=html(createElement(Builder,{initial:{...initial,affinities:{water:3,fire:3}},onSave:noop,onCancel:noop}));
 assert.match(invalid,/<button[^>]*disabled=""[^>]*>Use character/);
});

test('starter choices show each pair once and expose one selected build',()=>{
 const markup=html(createElement(Starter,{starterId:'stone',onSelect:noop}));
 for(const starter of TOWER_STARTERS)assert.equal(markup.split(starter.name).length-1,1);
 assert.equal((markup.match(/aria-pressed="true"/g)??[]).length,1);
 assert.equal((markup.match(/class="t22-starter"/g)??[]).length,3);
 assert.match(markup,/Starting party/);
});

test('signature availability shows the real affinity lock and creator Flux cost in both configuration views',()=>{
 const affinities={water:2,fire:2,earth:1},build={championId:'oh_tipi',name:'Oh Tipi',affinities,loadout:defaultLoadout('oh_tipi',affinities)};
 const lockedRun=createTowerRun('signature-lock',{starterId:'steam',build}),readyRun=createTowerRun('signature-ready','steam');
 for(const run of [lockedRun,readyRun]){
  const actor=run.party[0],signature=effectiveSpell(actor.championId,getSignature(actor.championId).id,actor.affinities),access=spellAccess(actor.championId,signature.id,actor.affinities,run.learnedSpells);
  const builder=html(createElement(Builder,{initial:{championId:actor.championId,name:actor.displayName,affinities:actor.affinities,loadout:actor.loadout},onSave:noop,onCancel:noop}));
  const loadout=html(createElement(Loadout,{run,actor,onChange:noop}));
  assert.match(builder,/<button[^>]*class="t22-primary"[^>]*>Use character/,'The valid 2/2/1 build remains selectable.');
  assert.equal(access.unlocked,run===readyRun);
  for(const markup of [builder,loadout]){
   const row=markup.match(/<div class="t22-(?:builder|native)-signature"[^>]*>[\s\S]*?<\/div>/)?.[0];assert.ok(row);
   assert.ok(row.includes(signature.name));assert.ok(row.includes(`data-signature-ready="${access.unlocked}"`));
   if(access.unlocked){assert.ok(row.includes(`${signature.cost} Flux`));assert.doesNotMatch(row,/locked/);}
   else {assert.equal(access.requiredAffinity,3);assert.ok(row.includes(`Requires ${access.requiredAffinity} Water · locked`));}
  }
 }
});

test('room previews show real enemies and prevent unaffordable tuition',()=>{
 const run=createTowerRun('interface-test','steam'),rooms=towerRoomChoices(run);
 const markup=html(createElement(Choices,{rooms,onChoose:noop,onInspect:noop}));
 for(const room of rooms){assert.ok(markup.includes(room.name));for(const enemy of room.enemies)assert.ok(markup.includes(enemy.displayName!));}
 assert.equal((markup.match(/aria-label="Inspect [^"]+, enemy spells"/g)??[]).length,rooms.reduce((count,room)=>count+room.enemies.length,0));
 const checkpoint=towerRoomChoices({...run,floor:3}),locked=html(createElement(Choices,{rooms:checkpoint,onChoose:noop,onInspect:noop,leadHp:2}));
 assert.match(locked,/<button[^>]*disabled=""[^>]*>Requires 3 health/);
 assert.match(locked,/Starting champion spends 2 health/);
 const allowed=html(createElement(Choices,{rooms:checkpoint,onChoose:noop,onInspect:noop,leadHp:3}));
 assert.doesNotMatch(allowed,/Requires 3 health/);
});

test('champion loadout has four explicit slots, a native signature and selected effect values',()=>{
 const run=createTowerRun('interface-test','steam'),actor=run.party[0],markup=html(createElement(Loadout,{run,actor,onChange:noop}));
 assert.equal((markup.match(/aria-label="Replace spell /g)??[]).length,4);
 assert.ok(markup.includes(getSignature(actor.championId).name));
 for(const id of actor.loadout)assert.ok(markup.includes(getSpell(id).name));
 assert.match(markup,/Reach /);assert.match(markup,/Selected spell/);assert.match(markup,/Equipped/);
});

test('fixed creature kits explain their actual party bond and cannot offer equip actions',()=>{
 const run=createTowerRun('interface-test','steam'),actor=run.party[1],markup=html(createElement(Loadout,{run,actor,onChange:noop})),creature=getCreature(actor.creatureId!),perk=CREATURE_PERKS.find(entry=>entry.id===creature.perkId)!;
 assert.match(markup,/Creature spells are fixed/);assert.ok(markup.includes(perk.name));assert.ok(markup.includes(perk.description));assert.doesNotMatch(markup,/Equip in slot/);assert.doesNotMatch(markup,/Swap with slot/);
});

test('reward choices disclose recruit replacement, health, native spells and bond',()=>{
 const run=createTowerRun('interface-test','steam'),room=towerRoomChoices({...run,floor:3}).find(entry=>entry.kind==='recruit')!,rewardRun={...run,floor:3,phase:'reward',currentRoom:room} as TowerRun,rewards=towerRewardChoices(rewardRun),markup=html(createElement(Rewards,{run:rewardRun,rewards,onChoose:noop}));
 assert.equal(rewards.length,3);for(const reward of rewards){assert.ok(markup.includes(reward.name));for(const id of reward.actor!.loadout)assert.ok(markup.includes(getSpell(id).name));}
 const creature=rewards.find(reward=>reward.actor?.creatureId)!;assert.ok(markup.includes(CREATURE_PERKS.find(entry=>entry.id===getCreature(creature.actor!.creatureId!).perkId)!.name));
 const full={...rewardRun,party:[...rewardRun.party,rewards[0].actor!]};assert.match(html(createElement(Rewards,{run:full,rewards,onChoose:noop})),/Choose who leaves/);
});

test('nine-floor navigation identifies the current floor accessibly',()=>{
 const run=createTowerRun('interface-test','steam'),markup=html(createElement(Progress,{run}));assert.equal((markup.match(/<li /g)??[]).length,9);assert.equal((markup.match(/aria-current="step"/g)??[]).length,1);assert.match(markup,/Floor 9, boss/);
});

test('enemy inspection shows exactly the authoritative combat kit with affinity-scaled values',()=>{
 const run=createTowerRun('inspect-enemies','steam'),room=towerRoomChoices({...run,floor:9})[0],battle=createTowerBattle({id:'inspection',mapId:room.mapId,allies:run.party,enemies:room.enemies,learnedSpells:[]});
 for(const enemy of room.enemies){
  const markup=html(createElement(Inspection,{actor:enemy})),ids=[...markup.matchAll(/data-spell-id="([^"]+)"/g)].map(match=>match[1]),expected=availableUnitSpellIds(battle,enemy.id);
  assert.deepEqual(ids,expected);
  for(const id of expected){const spell=effectiveSpell(enemy.championId,id,enemy.affinities);assert.ok(markup.includes(spell.name));assert.ok(markup.includes(`Reach ${spell.range}`));assert.ok(markup.includes(spellEffectLabel(spell)));assert.ok(markup.includes(`<b>${spell.cost} <small>Flux</small></b>`));}
  assert.doesNotMatch(markup,/Equip in slot|Swap with slot|Find spell or effect/);
  if(enemy.creatureId){const perk=CREATURE_PERKS.find(entry=>entry.id===getCreature(enemy.creatureId!).perkId)!;assert.ok(markup.includes(perk.description));assert.doesNotMatch(markup,/Creator signature/);}else{assert.equal(ids.length,5);assert.match(markup,/Creator signature/);}
 }
});

test('co-op room eligibility uses both founders and recruit replaces only the companion',()=>{
 const solo=createTowerRun('interface-test','steam'),rooms=towerRoomChoices({...solo,floor:3});
 const allowed=html(createElement(Choices,{rooms,onChoose:noop,onInspect:noop,leadHp:2,eventAllowed:true,eventCostLabel:'Both champions pay 1 HP'}));
 assert.doesNotMatch(allowed,/Requires 3 health|Each champion needs 2 HP/);
 const blocked=html(createElement(Choices,{rooms,onChoose:noop,onInspect:noop,leadHp:8,eventAllowed:false,eventCostLabel:'Both champions pay 1 HP'}));
 assert.match(blocked,/disabled=""[^>]*>Each champion needs 2 HP/);
 const room=rooms.find(entry=>entry.kind==='recruit')!,run={...solo,floor:3,phase:'reward',currentRoom:room} as TowerRun,rewards=towerRewardChoices(run);
 const full={...run,mode:'coop',party:[...run.party,rewards[0].actor!]} as TowerRun;
 assert.match(html(createElement(Rewards,{run:full,rewards,onChoose:noop})),/Replace companion/);
});
