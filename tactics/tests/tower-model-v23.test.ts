import test from 'node:test';
import assert from 'node:assert/strict';
import {CHAMPIONS,getChampion,affinityTotal} from '../lib/roster-v13.ts';
import {CREATURES,getCreature} from '../lib/campaign-creatures-v20.ts';
import {getSpell,ALL_SPELLS} from '../lib/spells-v20.ts';
import {createTowerRun,validateTowerStarter,createTowerSession,restoreTowerSession,validateTowerRun,towerChampion,towerCreature,towerStartingAffinity,towerReplaceableActors,towerTuitionActor,towerRoomChoices,chooseTowerRoom,towerRewardChoices,claimTowerReward,shareTowerSpells,towerAvailableSpells,updateTowerBuild,towerBattleConfig,finishTowerBattle,type TowerRun,type TowerMemberInput,type TowerStart} from '../lib/tower-v23.ts';
import {createTowerRun as createOldRun,createTowerSession as createOldSession,restoreTowerSession as restoreOldSession} from '../lib/tower-v22.ts';
import {createTowerBattle,chooseAIPlan,resolveRound,restoreSimState} from '../lib/tactics-v22.ts';
const hero=(id:string):TowerMemberInput=>{const actor=towerChampion(id,'temporary');return {kind:'champion',build:{championId:id,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout}};};
const creature=(id:string):TowerMemberInput=>({kind:'creature',creatureId:id});
const start=(...members:[TowerMemberInput,TowerMemberInput]):TowerStart=>({starterId:'steam',members});
const creatureStart=start(creature('creature-fire-cinder'),creature('creature-water-puddle'));
const championStart=start(hero('oh_tipi'),hero('treevor_mason'));
/** Synthetic room completion for transition tests only; actual combat is tested below. */
function toFloor(run:TowerRun,floor:number,preferRight=false):TowerRun {
 while(run.floor<floor){const rooms=towerRoomChoices(run),room=preferRight?rooms.at(-1)!:rooms.find(r=>r.kind==='camp')??rooms[0];run=chooseTowerRoom(run,room.id);if(run.phase==='battle')run={...run,phase:'reward'};const reward=towerRewardChoices(run).find(r=>r.kind==='train')??towerRewardChoices(run)[0];run=claimTowerReward(run,reward.id,towerReplaceableActors(run)[0]?.id);}
 return run;
}

test('every authored champion pair and lesser creature can be freely selected',()=>{
 for(let i=0;i<CHAMPIONS.length;i++)for(let j=i+1;j<CHAMPIONS.length;j++){
  const chosen=validateTowerStarter(start(hero(CHAMPIONS[i].id),hero(CHAMPIONS[j].id)));assert.equal(chosen.members.length,2);
 }
 const lessers=CREATURES.filter(c=>c.strengthClass==='lesser');assert.equal(lessers.length,12);
 for(const pet of lessers){const run=createTowerRun('FREE',start(creature(pet.id),hero('s_wayne')));assert.equal(run.party[0].creatureId,pet.id);assert.equal(towerStartingAffinity(run),7);assert.deepEqual(restoreTowerSession(createTowerSession(run)).run,validateTowerRun(run));}
 const small=createTowerRun('SMALL',creatureStart);assert.equal(towerStartingAffinity(small),4);assert.equal(small.party.length,2);
 const large=createTowerRun('LARGE',championStart);assert.equal(towerStartingAffinity(large),10);assert.equal(large.party.length,2);
});

test('suggestions remain editable and illegal starts are rejected without normalizing away mistakes',()=>{
 const preset=validateTowerStarter('steam');assert.equal(preset.members[0].kind,'champion');assert.equal(preset.members[1].kind,'creature');
 assert.throws(()=>validateTowerStarter(start(hero('oh_tipi'),hero('oh_tipi'))));
 assert.throws(()=>validateTowerStarter(start(creature('creature-fire-cinder'),creature('creature-fire-cinder'))));
 assert.throws(()=>validateTowerStarter(start(hero('oh_tipi'),creature(CREATURES.find(c=>c.strengthClass==='standard')!.id))));
 const bad=hero('oh_tipi');assert.equal(bad.kind,'champion');if(bad.kind==='champion')bad.build.affinities={water:6};assert.throws(()=>validateTowerStarter(start(bad,hero('s_wayne'))));
 assert.throws(()=>validateTowerStarter({starterId:'steam',members:[hero('oh_tipi')]} as unknown as TowerStart));
 assert.throws(()=>validateTowerRun({...createTowerRun('FORGED',creatureStart),party:[towerChampion('oh_tipi','hero'),towerChampion('s_wayne','companion')]}));
});

test('first-floor legal editing preserves the original budget and learned library',()=>{
 const run=createTowerRun('NAME',championStart),member=run.starts[0].members[1];assert.equal(member.kind,'champion');if(member.kind!=='champion')return;
 const updated=updateTowerBuild(run,'companion',{...member.build,name:'Twig Accountant'});assert.equal(updated.party[1].displayName,'Twig Accountant');assert.deepEqual(updated.starts,run.starts);assert.deepEqual(updated.learnedSpells,run.learnedSpells);assert.equal(towerStartingAffinity(updated),10);
});

test('starting champions in either slot stay protected while creatures and recruits can be replaced',()=>{
 const a=createTowerRun('PROTECTED',championStart);assert.deepEqual(towerReplaceableActors(a),[]);
 const b=createTowerRun('SECOND',start(creature('creature-water-puddle'),hero('oh_tipi')));assert.deepEqual(towerReplaceableActors(b).map(a=>a.id),['hero']);
 assert.deepEqual(towerReplaceableActors(createTowerRun('PETS',creatureStart)).map(a=>a.id),['hero','companion']);
 let run=toFloor(a,3);run=chooseTowerRoom(run,towerRoomChoices(run).find(r=>r.kind==='recruit')!.id);run=claimTowerReward(run,towerRewardChoices(run)[0].id);assert.equal(run.party.length,3);assert.equal(towerReplaceableActors(run).length,1);
 run=toFloor(run,6);run=chooseTowerRoom(run,towerRoomChoices(run).find(r=>r.kind==='recruit')!.id);const reward=towerRewardChoices(run)[0];assert.throws(()=>claimTowerReward(run,reward.id,'hero'));assert.throws(()=>claimTowerReward(run,reward.id,'companion'));const replaced=claimTowerReward(run,reward.id,towerReplaceableActors(run)[0].id);assert.equal(replaced.party.length,3);assert.deepEqual(replaced.party.slice(0,2).map(a=>a.id),['hero','companion']);
});

test('creature-only full-health parties always receive real rewards and can pay tuition',()=>{
 const original=createTowerRun('PETS',creatureStart);
 for(const floor of [1,3,6,8])for(const room of towerRoomChoices({...original,floor})){
  const run={...original,floor,phase:'reward' as const,currentRoom:room};const rewards=towerRewardChoices(run);assert.ok(rewards.length>=1);assert.ok(rewards.every(r=>r.kind!=='heal'));assert.ok(rewards.some(r=>r.kind==='recruit'));
 }
 const run=toFloor(original,3,true),event=towerRoomChoices(run).find(r=>r.kind==='event')!;assert.ok(event);const before=towerTuitionActor(run),paid=chooseTowerRoom(run,event.id);assert.equal(paid.party[0].hp,before.hp-2);assert.ok(towerRewardChoices(paid).length>0);
 const exhausted={...run,party:run.party.map((a,i)=>i===0?{...a,hp:2}:a)};assert.throws(()=>chooseTowerRoom(exhausted,event.id));
});

test('enemy strength uses immutable four/seven/ten-point starts and preserves opening attack coverage',()=>{
 for(const starter of [creatureStart,'steam',championStart] as const){
  const run=createTowerRun('POWER',starter),power=towerStartingAffinity(run),normal=towerRoomChoices(run)[0];assert.equal(normal.enemies.length,power===4?1:2);assert.equal(getCreature(normal.enemies[0].creatureId!).strengthClass,power===10?'standard':'lesser');
  const grown={...run,party:run.party.map(a=>a.creatureId?a:{...a,affinities:{...a.affinities,[getChampion(a.championId).element]:6}})};assert.deepEqual(towerRoomChoices(grown),towerRoomChoices(run));
  for(let seed=0;seed<12;seed++)for(const floor of [1,2])for(const room of towerRoomChoices({...run,seed:`COVER${seed}`,floor})){
   assert.equal(room.enemies.length,power===4&&floor===1&&room.kind==='combat'?1:2);if(room.enemies.length>1)assert.notEqual(getChampion(room.enemies[0].championId).element,getChampion(room.enemies[1].championId).element);assert.ok(room.enemies.some(a=>a.loadout.some(id=>getSpell(id).damage>=2)));
  }
  for(const floor of [4,5,7,9])for(const room of towerRoomChoices({...run,floor}).filter(r=>r.enemies.length))createTowerBattle(towerBattleConfig({...run,floor,phase:'battle',currentRoom:room}));
 }
});

test('checkpoint spell sharing is knowledge-only, affinity-gated and strict about phase and IDs',()=>{
 const fresh=createTowerRun('SHARE','steam');assert.throws(()=>shareTowerSpells(fresh,['radiant_bolt']));
 const run=toFloor(fresh,2),spell=ALL_SPELLS.find(s=>s.element==='dark'&&!run.learnedSpells.includes(s.id))!;const shared=shareTowerSpells(run,[spell.id,spell.id]);assert.ok(shared.learnedSpells.includes(spell.id));assert.deepEqual(shared.party,run.party);assert.deepEqual(shared.starts,run.starts);assert.deepEqual(shared.history,run.history);assert.ok(!towerAvailableSpells(shared,'hero').some(s=>s.id===spell.id));assert.throws(()=>shareTowerSpells(run,['invented-spell']));assert.throws(()=>shareTowerSpells(chooseTowerRoom(run,towerRoomChoices(run)[0].id),[spell.id]));
 assert.deepEqual(restoreTowerSession(createTowerSession(shared)).run,shared);
});

test('v23 sessions reuse frozen normal combat and cannot read or overwrite v22 sessions',()=>{
 const old=createOldSession(createOldRun('OLD'));assert.equal(restoreOldSession(old).format,2);assert.throws(()=>restoreTowerSession(old));
 const run=createTowerRun('NEW',championStart),battleRun=chooseTowerRoom(run,towerRoomChoices(run)[0].id),session=createTowerSession(battleRun);assert.equal(session.format,3);assert.equal(session.battle!.rulesVersion,22);assert.equal(session.battle!.tower.mode,'solo');assert.deepEqual(Object.values(session.battle!.tower.controllers!),[0,0]);assert.throws(()=>restoreOldSession(session));
 const first=session.battle!.units.find(unit=>unit.owner===0)!,plan={orders:[{unitId:first.id,guard:true}]};const restored=restoreTowerSession(createTowerSession(battleRun,session.battle,plan));assert.equal(restored.plan.orders.length,1);
});

test('all three starting power bands complete a real bounded opening battle',()=>{
 for(const starter of [creatureStart,'steam',championStart] as const){
  const run=createTowerRun('SQUADS1',starter),roomRun=chooseTowerRoom(run,towerRoomChoices(run)[0].id);let state=createTowerBattle(towerBattleConfig(roomRun)),rounds=0;
  while(state.winner===null&&rounds<16){state=resolveRound(state,[chooseAIPlan(state,0),chooseAIPlan(state,1)]);restoreSimState(state);rounds++;}
  assert.notEqual(state.winner,null,`Power ${towerStartingAffinity(run)} stalled`);assert.ok(rounds<=14);const settled=finishTowerBattle(roomRun,state);assert.ok(['lost','reward'].includes(settled.phase));assert.deepEqual(restoreTowerSession(createTowerSession(settled)).run,settled);
 }
});
