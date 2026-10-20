import test from 'node:test';
import assert from 'node:assert/strict';
import * as tower from '../lib/tactics-v22.ts';
import * as story from '../lib/tactics-v20.ts';
import * as arena from '../lib/tactics-v18.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {CURRENT_SPELL_MODEL} from '../lib/spell-profile-v42.ts';
import {jointLandings,barrierRouteValue} from '../lib/joint-planning-v44.ts';
import {friendlyStatusValue} from '../lib/support-value-v44.ts';
import {planningGeometry} from '../lib/planning-geometry-v44.ts';
import {ALL_SPELLS,effectiveSpell} from '../lib/spells-v20.ts';
import {profileSpell} from '../lib/spell-profile-v42.ts';

const actor=(id:string,championId:string):tower.TowerActor=>{const build=canonicalBuild(championId);return {id,championId,affinities:build.affinities,loadout:build.loadout,hp:8};};
function rescue(){
 const hero=actor('hero','haara');hero.loadout=['mend','clear_sight','aegis','radiant_bolt'];
 const state=tower.createTowerBattle({id:'rescue44',mapId:'RESCUE44',allies:[hero,actor('patient','oh_tipi')],enemies:[actor('foe','red_baron')],learnedSpells:[]});
 for(const cell of state.cells){Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false});delete cell.ttl;delete cell.elements;delete cell.reactions;delete cell.ice;delete cell.barrier;}
 Object.assign(state.units[0],{q:0,r:0});
 Object.assign(state.units[1],{q:-6,r:0,hp:1,statuses:{rooted:{turns:1,power:1},resolve:{turns:2,power:1}}});
 Object.assign(state.units[2],{q:7,r:0});return state;
}

test('joint movement and casting rescues a separated wounded ally in each active native engine',()=>{
 for(const [name,choose,resolve,version] of [
  ['Tower',tower.chooseAIPlan,tower.resolveRound,22],
  ['Story',story.chooseAIPlan,story.resolveRound,20],
  ['Arena',arena.chooseAIPlan,arena.resolveRound,18],
 ] as const){
  const state={...rescue(),rulesVersion:version},original=JSON.stringify(state);
  const legacy={...state,spellModel:'focused' as const},previous=choose(legacy as never,0),current=choose(state as never,0);
  assert.notEqual(previous.orders.find(order=>order.unitId==='hero')!.spellId,'mend',name);
  assert.equal(current.orders.find(order=>order.unitId==='hero')!.spellId,'mend',name);
  const before=resolve(legacy as never,[previous,{orders:[]}]),after=resolve(state as never,[current,{orders:[]}]);
  assert.ok(after.units.find(unit=>unit.id==='patient')!.hp>before.units.find(unit=>unit.id==='patient')!.hp,name);
  assert.equal(JSON.stringify(state),original,'Search cannot mutate public state');
 }
});

test('current AI is deterministic under unit enumeration and ignores the prior Guard flag',()=>{
 const state=rescue(),expected=tower.chooseAIPlan(state,0),shuffled=structuredClone(state);
 shuffled.units.reverse();shuffled.units.find(unit=>unit.owner===1)!.guard=true;
 assert.deepEqual(tower.chooseAIPlan(shuffled,0),expected);
 assert.equal(state.spellModel,CURRENT_SPELL_MODEL);
});

test('candidate budget retains a useful rescue angle and cannot reserve an occupied allied landing',()=>{
 const candidates=[
  {cell:{q:3,r:0},score:20,support:0},
  {cell:{q:2,r:0},score:19,support:0},
  {cell:{q:0,r:0},score:8,support:3},
  {cell:{q:-1,r:0},score:7,support:15},
  {cell:{q:-2,r:0},score:6,support:15},
 ];
 const result=jointLandings(candidates,{q:3,r:0},{q:0,r:0},new Set(['-2,0']),2);
 assert.ok(result.some(entry=>entry.cell.q===-1));assert.ok(result.every(entry=>entry.cell.q!==-2));
 assert.ok(result.length<=3);
 assert.ok(jointLandings(candidates,{q:3,r:0},{q:0,r:0},new Set(),18).length<=2,'Shared battles have a bounded smaller search');
});

test('short-lived planning geometry agrees with native shape, edge and board-order rules',()=>{
 const state=rescue(),unit=state.units[0],origins=[{q:0,r:0},{q:-2,r:1}],targets=[{q:2,r:0},{q:0,r:0},{q:8,r:0},{q:-3,r:2}];
 let reads=0;
 const geometry=planningGeometry(state.cells,state.units,(actor,id)=>profileSpell(effectiveSpell(actor.championId,id,actor.affinities),state.spellModel),(id,spell,target,from)=>{reads++;return tower.spellArea(state,id,spell,target,from);},(id,spell,from)=>tower.legalCasts(state,id,from,spell));
 const shapes=['hex','burst','ring','line','sweep','wall','self'];
 const examples=shapes.flatMap(shape=>{const spell=ALL_SPELLS.find(spell=>profileSpell(spell,CURRENT_SPELL_MODEL).shape===shape);return spell?[spell]:[];});
 for(const spell of examples)for(const origin of origins)for(const target of targets){
  assert.deepEqual(geometry.area(unit.id,spell.id,target,origin),tower.spellArea(state,unit.id,spell.id,target,origin),`${spell.shape} ${spell.id}`);
 }
 const before=reads;
 for(const spell of examples)for(const origin of origins)for(const target of targets)geometry.area(unit.id,spell.id,target,origin);
 assert.equal(reads,before,'Repeated exact shapes do not repeat native work');
});

test('wall utility rewards a blocked approach rather than empty scenery or occupied ground',()=>{
 const cells=[];for(let q=-4;q<=4;q++)for(let r=-1;r<=1;r++)cells.push({q,r,well:false,biome:r===0?'plain':'ruins'});
 const allies=[{q:-3,r:0,hp:2,maxHp:8}],enemies=[{q:3,r:0}];
 assert.ok(barrierRouteValue(cells,[{q:0,r:0}],allies,enemies)>0);
 assert.equal(barrierRouteValue(cells,[{q:0,r:1}],allies,enemies),0);
 assert.equal(barrierRouteValue(cells,[{q:-3,r:0}],allies,enemies),0);
 const open=cells.map(cell=>({...cell,biome:'plain'}));
 assert.ok(barrierRouteValue(open,[{q:0,r:0}],allies,enemies)<barrierRouteValue(cells,[{q:0,r:0}],allies,enemies));
});

test('support utility counts marginal next-exchange protection and bounded Ward renewal',()=>{
 const ward={...ALL_SPELLS.find(spell=>spell.id==='aegis')!,friendly:[{id:'ward' as const,turns:1,power:3}]};
 const existing={statuses:{ward:{turns:2,power:3}}},empty={statuses:{}};
 assert.equal(friendlyStatusValue(existing,ward,{},[],false),0,'A safe lasting shield is not three free points every turn');
 const threatened=friendlyStatusValue(existing,ward,{},[],true),fresh=friendlyStatusValue(empty,ward,{},[],true);
 assert.ok(threatened>0&&threatened<fresh,'Old Ward can be consumed, so renewal is useful but not full fresh protection');
 assert.ok(friendlyStatusValue({statuses:{ward:{turns:1,power:3}}},ward,{},[],true)>0,'Expiring Ward has future value');
 assert.equal(friendlyStatusValue(empty,ward,{statuses:[{id:'ward',turns:1,power:3}]},[],true),0,'The resulting field already supplies it');
 assert.equal(friendlyStatusValue(empty,ward,{},[ward],true),0,'Another queued buff already supplies it');
 assert.ok(friendlyStatusValue({statuses:{ward:{turns:2,power:5}}},{...ward,friendly:[{id:'ward',turns:1,power:2}]},{},[],true)>0,'Weaker renewal still matters if the old shield is consumed');
});
