import test from 'node:test';
import assert from 'node:assert/strict';
import {TOWER_STARTERS,createTowerRun,validateTowerRun,towerRoomChoices,chooseTowerRoom,towerRewardChoices,claimTowerReward,towerBattleConfig,finishTowerBattle,towerAvailableSpells,updateTowerLoadout,createTowerSession,restoreTowerSession,type TowerRun} from '../lib/tower-v21.ts';
import {createTowerBattle,resolveRound,restoreSimState,type SimState} from '../lib/tactics-v21.ts';
import {getSpell,getSignature,teachingForEnemy,spellAccess,spellCost,ALL_SPELLS} from '../lib/spells-v20.ts';
import {getChampion} from '../lib/roster-v13.ts';

const copy=<T>(value:T):T=>JSON.parse(JSON.stringify(value));
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.cooldowns={};unit.statuses={};delete unit.guard;};
/** Synthetic terminal state tests settlement only; real AI climbs are a separate balance diagnostic. */
function terminal(run:TowerRun,won=true):SimState{
 const state=createTowerBattle(towerBattleConfig(run));
 for(const unit of state.units.filter(unit=>unit.owner===(won?1:0)))kill(unit);
 return restoreSimState(resolveRound(state,[{orders:[]},{orders:[]}]))!;
}
function clear(run:TowerRun,lane=0):TowerRun{
 let next=chooseTowerRoom(run,towerRoomChoices(run)[lane].id);
 if(next.phase==='battle')next=finishTowerBattle(next,terminal(next));
 if(next.phase==='reward')next=claimTowerReward(next,towerRewardChoices(next)[0].id);
 return next;
}
function atFloor(floor:number,starter='steam',seed='TEST'):TowerRun{let run=createTowerRun(seed,starter);while(run.floor<floor)run=clear(run);return run;}

test('starting pairs use all six elements, independent libraries, and deterministic fork previews',()=>{
 const seen=new Set<string>();
 for(const starter of TOWER_STARTERS){
  const run=createTowerRun(' old kettle ',starter.id);assert.equal(run.seed,'OLD KETTLE');assert.equal(run.party.length,2);assert.equal(run.party[0].loadout.length,4);
  for(const actor of run.party)Object.keys(actor.affinities).forEach(element=>seen.add(element));
  assert.deepEqual(validateTowerRun(run),run);assert.deepEqual(towerRoomChoices(run),towerRoomChoices(createTowerRun('OLD KETTLE',starter.id)));
  assert.notDeepEqual(towerRoomChoices(run),towerRoomChoices(createTowerRun('NEW KETTLE',starter.id)));
  run.party[0].hp=1;assert.equal(createTowerRun('OLD KETTLE',starter.id).party[0].hp,8);
 }
 assert.equal(seen.size,6);assert.throws(()=>createTowerRun('','steam'));assert.throws(()=>createTowerRun('OK','missing'));assert.throws(()=>createTowerRun('<html>','steam'));
});

test('every route requires five fights and preserves the same visible summit across choices',()=>{
 let run=createTowerRun('UPSTAIRS','steam'),fights=0;const boss=towerRoomChoices({...run,floor:9})[0];
 while(run.phase!=='won'){
  const choices=towerRoomChoices(run),room=choices.find(room=>!room.enemies.length&&room.kind!=='event')??choices[0];
  run=chooseTowerRoom(run,room.id);
  if(run.phase==='battle'){fights++;run=finishTowerBattle(run,terminal(run));}
  if(run.phase==='reward'){const reward=towerRewardChoices(run)[0];run=claimTowerReward(run,reward.id,run.party.length===3?run.party[1].id:undefined);}
 }
 assert.equal(fights,5);assert.equal(run.floor,9);assert.equal(run.history.length,9);assert.deepEqual(run.currentRoom,boss);assert.equal(run.phase,'won');assert.deepEqual(restoreTowerSession(JSON.stringify(createTowerSession(run))).run,run);assert.throws(()=>claimTowerReward(run,'anything'));
});

test('opening waves vary across seeds, mix primary elements and always include direct pressure',()=>{
 const primaryCounts=new Map<string,number>(),species=new Set<string>();
 for(let seed=0;seed<32;seed++)for(const floor of [1,2]){
  const run={...createTowerRun(`AUDIT${seed}`,'steam'),floor};
  for(const room of towerRoomChoices(run)){
   assert.equal(room.enemies.length,2);const primary=room.enemies.map(actor=>getChampion(actor.championId).element);assert.notEqual(primary[0],primary[1]);
   assert.ok(room.enemies.some(actor=>actor.loadout.some(id=>getSpell(id).damage>0)));
   for(const actor of room.enemies)species.add(actor.creatureId!);
   primaryCounts.set(primary[0],(primaryCounts.get(primary[0])??0)+1);
  }
 }
 assert.equal(primaryCounts.size,6);assert.ok([...primaryCounts.values()].every(count=>count>=8));assert.ok(species.size>=20);
});

test('room selection, reward settlement, and floor advancement cannot be repeated',()=>{
 const route=createTowerRun('ONCE','steam'),battle=chooseTowerRoom(route,towerRoomChoices(route)[0].id);
 assert.throws(()=>chooseTowerRoom(battle,towerRoomChoices(route)[1].id));assert.throws(()=>claimTowerReward(battle,'heal:party'));
 assert.throws(()=>finishTowerBattle(battle,createTowerBattle(towerBattleConfig(battle))));
 const reward=finishTowerBattle(battle,terminal(battle));assert.equal(reward.floor,1);assert.equal(reward.history.length,0);assert.throws(()=>finishTowerBattle(reward,terminal(battle)));
 const next=claimTowerReward(reward,towerRewardChoices(reward)[0].id);assert.equal(next.floor,2);assert.equal(next.history.length,1);assert.throws(()=>claimTowerReward(next,towerRewardChoices(reward)[0].id));assert.deepEqual(route,createTowerRun('ONCE','steam'));
});

test('a victory carries wounds, revives a fallen companion at one health, and learns each enemy technique',()=>{
 const battle=chooseTowerRoom(createTowerRun('WOUNDS','steam'),'floor-1-0'),state=createTowerBattle(towerBattleConfig(battle));
 state.units.find(unit=>unit.id==='hero')!.hp=3;kill(state.units.find(unit=>unit.id==='companion')!);state.units.filter(unit=>unit.owner===1).forEach(kill);
 const won=restoreSimState(resolveRound(state,[{orders:[]},{orders:[]}])),next=finishTowerBattle(battle,won);
 assert.equal(next.party[0].hp,4);assert.equal(next.party[1].hp,1);
 for(const enemy of won.units.filter(unit=>unit.owner===1))assert.ok(next.learnedSpells.includes(teachingForEnemy(enemy).id));
 const heal=towerRewardChoices(next).find(reward=>reward.kind==='heal')!;assert.ok(heal);const healed=claimTowerReward(next,heal.id);assert.equal(healed.party[0].hp,7);assert.equal(healed.party[1].hp,4);
});

test('loss ends the run at actual zero health but retains techniques from enemies defeated first',()=>{
 const battle=chooseTowerRoom(createTowerRun('LAST-LESSON','steam'),'floor-1-0'),state=createTowerBattle(towerBattleConfig(battle)),enemy=state.units.find(unit=>unit.owner===1)!;
 kill(enemy);state.units.filter(unit=>unit.owner===0).forEach(kill);
 const lost=finishTowerBattle(battle,resolveRound(state,[{orders:[]},{orders:[]}]));assert.equal(lost.phase,'lost');assert.ok(lost.party.every(actor=>actor.hp===0));assert.ok(lost.learnedSpells.includes(teachingForEnemy(enemy).id));assert.deepEqual(createTowerSession(lost).run,lost);assert.equal(towerRoomChoices(lost).length,0);assert.equal(towerRewardChoices(lost).length,0);
});

test('tuition has a visible exact cost, cannot kill, and cannot be paid twice by reloading',()=>{
 const route=atFloor(3),room=towerRoomChoices(route).find(room=>room.kind==='event')!;assert.match(room.description,/2 health/);
 const paid=chooseTowerRoom(route,room.id);assert.equal(paid.party[0].hp,route.party[0].hp-2);assert.deepEqual(restoreTowerSession(JSON.stringify(createTowerSession(paid))).run,paid);assert.throws(()=>chooseTowerRoom(paid,room.id));
 const wounded=copy(route);wounded.party[0].hp=2;assert.throws(()=>chooseTowerRoom(wounded,room.id));
});

test('recruit drafts include champions and creatures; a full party swaps only a companion',()=>{
 let run=atFloor(3);run=chooseTowerRoom(run,towerRoomChoices(run).find(room=>room.kind==='recruit')!.id);
 const offers=towerRewardChoices(run);assert.equal(offers.length,3);assert.ok(offers.some(reward=>reward.actor?.creatureId));assert.ok(offers.some(reward=>!reward.actor?.creatureId));
 const chosen=offers.find(reward=>reward.actor&&!reward.actor.creatureId)!;run=claimTowerReward(run,chosen.id);assert.equal(run.party.length,3);assert.equal(run.party[2].championId,chosen.actor!.championId);assert.ok(chosen.actor!.loadout.every(id=>run.learnedSpells.includes(id)));
 run=clear(run);const recruitment=chooseTowerRoom(run,towerRoomChoices(run).find(room=>room.kind==='recruit')!.id),replacement=towerRewardChoices(recruitment)[0];
 assert.throws(()=>claimTowerReward(recruitment,replacement.id));assert.throws(()=>claimTowerReward(recruitment,replacement.id,'hero'));
 const replaced=claimTowerReward(recruitment,replacement.id,recruitment.party[1].id);assert.equal(replaced.party.length,3);assert.equal(replaced.party[0].id,'hero');assert.ok(replaced.party.some(actor=>actor.id===replacement.actor!.id));
});

test('spell drafts are unowned, affinity-legal and affordable, and learning does not silently replace a slot',()=>{
 for(const starter of TOWER_STARTERS){
  const run=chooseTowerRoom(atFloor(3,starter.id),'floor-3-2'),offer=towerRewardChoices(run).find(reward=>reward.kind==='spell')!;assert.ok(offer);
  const actor=run.party.find(actor=>actor.id===offer.actorId)!;assert.ok(!run.learnedSpells.includes(offer.spellId!));assert.ok(spellAccess(actor.championId,offer.spellId!,actor.affinities,[...run.learnedSpells,offer.spellId!]).unlocked);assert.ok(spellCost(actor.championId,offer.spellId!,actor.affinities)<=6);
  const next=claimTowerReward(run,offer.id);assert.deepEqual(next.party[0].loadout,run.party[0].loadout);assert.ok(towerAvailableSpells(next,actor.id).some(spell=>spell.id===offer.spellId));
  const loadout=[offer.spellId!,...actor.loadout.slice(1)];assert.deepEqual(updateTowerLoadout(next,actor.id,loadout).party.find(actor=>actor.id===offer.actorId)!.loadout,loadout);
 }
});

test('affinity alone cannot equip an undrafted base spell; creatures keep fixed native kits',()=>{
 const run=createTowerRun('LIMITED','steam'),hero=run.party[0],unknown=ALL_SPELLS.find(spell=>!run.learnedSpells.includes(spell.id)&&spellAccess(hero.championId,spell.id,hero.affinities,[]).unlocked)!;assert.ok(unknown);
 assert.throws(()=>updateTowerLoadout(run,'hero',[unknown.id,...hero.loadout.slice(1)]));assert.throws(()=>updateTowerLoadout(run,'companion',hero.loadout));
 const battle=chooseTowerRoom(run,'floor-1-0');assert.throws(()=>updateTowerLoadout(battle,'hero',hero.loadout));assert.ok(!towerAvailableSpells(run,'hero').some(spell=>spell.id===getSignature(hero.championId).id));
});

test('training keeps the primary strongest and capped at six, and healthy camps do not waste a reward on healing',()=>{
 const route=atFloor(3),camp=chooseTowerRoom(route,'floor-3-1'),offers=towerRewardChoices(camp);assert.equal(offers.length,3);assert.ok(!offers.some(reward=>reward.kind==='heal'));
 const train=offers.find(reward=>reward.kind==='train')!,next=claimTowerReward(camp,train.id),before=camp.party.find(actor=>actor.id===train.actorId)!;assert.equal(next.party.find(actor=>actor.id===train.actorId)!.affinities[train.element!],before.affinities[train.element!]!+train.amount!);
 const capped=copy(camp);capped.party[0].affinities={water:6,fire:6};assert.ok(towerRewardChoices(capped).every(reward=>reward.kind!=='train'));
});

test('camps offer distinct recovery, training and study choices instead of filling every card with affinity',()=>{
 for(const starter of TOWER_STARTERS){
  const healthy=chooseTowerRoom(atFloor(3,starter.id),'floor-3-1');
  assert.ok(towerRewardChoices(healthy).some(reward=>reward.kind==='spell'));assert.ok(towerRewardChoices(healthy).some(reward=>reward.kind==='train'));
  const wounded=copy(healthy);wounded.party[0].hp=3;
  assert.deepEqual(towerRewardChoices(wounded).map(reward=>reward.kind),['heal','train','spell']);
 }
});

test('atomic sessions restore partial drafts and previous rounds without filling unplanned guards',()=>{
 const run=chooseTowerRoom(createTowerRun('SAVE','steam'),'floor-1-0'),first=createTowerSession(run),state=resolveRound(first.battle!,[{orders:[]},{orders:[]}]),session=createTowerSession(run,state,{orders:[{unitId:'hero',guard:true}]},first.battle!);
 const restored=restoreTowerSession(JSON.stringify(session));assert.equal(restored.plan.orders.length,1);assert.equal(restored.plan.orders[0].unitId,'hero');assert.equal(restored.previous!.version+1,restored.battle!.version);
 const damaged=copy(session);damaged.plan={orders:[{unitId:'not-ours',guard:true}]};assert.deepEqual(restoreTowerSession(damaged).plan,{orders:[]});
 const unrelated=copy(session);unrelated.previous=copy(state);assert.equal(restoreTowerSession(unrelated).previous,undefined);
});

test('save provenance rejects missing battle, mixed room state, tampered map, and impossible history',()=>{
 const run=chooseTowerRoom(createTowerRun('SAFE','steam'),'floor-1-0'),session=createTowerSession(run);
 for(const alter of [
  (value:any)=>{value.battle=null;},
  (value:any)=>{value.run.seed='OTHER';},
  (value:any)=>{value.run.currentRoom.mapId='arena:2:OTHER';},
  (value:any)=>{value.run.history.push(value.run.currentRoom);},
  (value:any)=>{value.run.learnedSpells.push('made-up-spell');},
  (value:any)=>{value.run.party[0].maxHp=999;},
  (value:any)=>{value.extra='unknown';},
 ]){const bad=copy(session);alter(bad);assert.throws(()=>restoreTowerSession(bad));}
 assert.throws(()=>restoreTowerSession('{'));assert.throws(()=>restoreTowerSession({...createTowerSession(createTowerRun('SAFE','steam')),battle:session.battle}));
});

test('room prose can be improved without invalidating an existing run or replay',()=>{
 const run=chooseTowerRoom(atFloor(2),'floor-2-0'),session=createTowerSession(run),old=copy(session);
 old.run.history[0].name='Old room title';old.run.history[0].description='Old wording';old.run.currentRoom!.flavor='Old joke';old.run.currentRoom!.description='Old explanation';
 assert.deepEqual(restoreTowerSession(old),session);
});
