import test from 'node:test';
import assert from 'node:assert/strict';
import {createTowerRun,createTowerSession,restoreTowerSession,validateTowerRun,towerRoomChoices,chooseTowerRoom,towerBattleConfig,towerRewardChoices,claimTowerReward,towerReplaceableActors,towerChampion,updateTowerBuild,type TowerRun,type TowerMemberInput,type TowerStart} from '../lib/tower-v23.ts';
import {availableSpellIds,getSpell} from '../lib/spells-v20.ts';
import {towerRoomIntel} from '../lib/tower-scouting.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';
import {scoutTowerRoom,towerScoutReports,towerScoutOptions,towerScoutsAvailable,scoutReportsForRun,towerScoutEncounterKey,mergeTowerScouting,type ScoutReport} from '../lib/tower-scouting-actions.ts';

const champion=(id:string):TowerMemberInput=>{const actor=towerChampion(id,'temporary');return {kind:'champion',build:{championId:id,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout}};};
const double:TowerStart={starterId:'steam',members:[champion('oh_tipi'),champion('treevor_mason')]};
const pets:TowerStart={starterId:'steam',members:[{kind:'creature',creatureId:'creature-fire-cinder'},{kind:'creature',creatureId:'creature-water-puddle'}]};
/** Synthetic room transitions exercise save and allowance state, not combat balance. */
function advance(run:TowerRun):TowerRun{const room=towerRoomChoices(run).find(room=>room.kind==='camp')??towerRoomChoices(run)[0];const entered=chooseTowerRoom(run,room.id),rewardRun={...entered,phase:'reward' as const},reward=towerRewardChoices(rewardRun).find(reward=>reward.kind==='train')??towerRewardChoices(rewardRun)[0];return claimTowerReward(rewardRun,reward.id,towerReplaceableActors(rewardRun)[0]?.id);}
function floor(run:TowerRun,target:number){while(run.floor<target)run=advance(run);return run;}

test('scouting reveals one seeded fact without changing HP, Flux, loadouts, rooms or combat',()=>{
 const run=createTowerRun('SCOUT',double),before=JSON.stringify(run),room=towerRoomChoices(run)[0],next=scoutTowerRoom(run,'hero',room.id);
 assert.deepEqual(next.scouting,scoutTowerRoom(JSON.parse(before),'hero',room.id).scouting);assert.equal(next.scouting!.reports.length,1);assert.deepEqual(next.scouting!.usedActorIds,['hero']);
 assert.deepEqual(next.party,run.party);assert.deepEqual(next.starts,run.starts);assert.deepEqual(towerRoomChoices(next),towerRoomChoices(run));assert.equal(JSON.stringify(run),before);
 assert.deepEqual(towerBattleConfig(chooseTowerRoom(next,room.id)),towerBattleConfig(chooseTowerRoom(run,room.id)));
 assert.deepEqual(towerScoutReports(next,room.id),next.scouting!.reports);
});

test('only a living champion can scout, once per floor, before entering a battle room',()=>{
 const run=createTowerRun('ALLOWANCE'),room=towerRoomChoices(run)[0];assert.deepEqual(towerScoutsAvailable(run).map(actor=>actor.id),['hero']);assert.throws(()=>scoutTowerRoom(run,'companion',room.id),/living champion/);assert.throws(()=>scoutTowerRoom(run,'invented',room.id),/living champion/);
 const next=scoutTowerRoom(run,'hero',room.id);assert.throws(()=>scoutTowerRoom(next,'hero',towerRoomChoices(next)[1].id),/already scouted/);assert.equal(towerScoutsAvailable(next).length,0);
 assert.throws(()=>scoutTowerRoom(chooseTowerRoom(run,room.id),'hero',room.id),/before entering/);
 const dead=floor(run,2);dead.party[0].hp=0;assert.equal(towerScoutsAvailable(dead).length,0);assert.throws(()=>scoutTowerRoom(dead,'hero',towerRoomChoices(dead)[0].id),/living champion|maximum health/);
 assert.equal(towerScoutsAvailable(createTowerRun('PETS',pets)).length,0);
 const service=floor(run,3);assert.ok(towerRoomChoices(service).every(room=>!towerScoutOptions(service,room.id).canScout));assert.throws(()=>scoutTowerRoom(service,'hero',towerRoomChoices(service)[0].id),/battle room/);
});

test('save, reload and same-floor build edits preserve the spent action and exact report',()=>{
 const run=scoutTowerRoom(createTowerRun('PERSIST',double),'hero','floor-1-0'),saved=createTowerSession(run),restored=restoreTowerSession(JSON.stringify(saved)).run;
 assert.deepEqual(restored,run);assert.throws(()=>scoutTowerRoom(restored,'hero','floor-1-1'),/already scouted/);
 const actor=restored.party[0],edited=updateTowerBuild(restored,actor.id,{championId:actor.championId,name:'New coat',affinities:actor.affinities,loadout:[...actor.loadout].reverse()});
 assert.deepEqual(edited.scouting,run.scouting);assert.throws(()=>scoutTowerRoom(edited,'hero','floor-1-1'),/already scouted/);
 const second=scoutTowerRoom(edited,'companion','floor-1-0');assert.equal(second.scouting!.reports.length,2);assert.notEqual(second.scouting!.reports[0].id,second.scouting!.reports[1].id);
});

test('a completed floor resets scouting while old v23 saves remain unchanged',()=>{
 const old=createTowerRun('OLD23');assert.equal(old.scouting,undefined);assert.deepEqual(restoreTowerSession(createTowerSession(old)).run,old);
 const spent=scoutTowerRoom(createTowerRun('RESET',double),'hero','floor-1-0'),next=advance(spent);assert.equal(next.floor,2);assert.equal(next.scouting,undefined);assert.equal(towerScoutsAvailable(next).length,2);
 const second=scoutTowerRoom(next,'hero','floor-2-0');assert.equal(second.scouting!.floor,2);assert.equal(second.scouting!.reports.length,1);assert.equal(scoutReportsForRun(second,spent.scouting!.reports).length,0);
});

test('every generated enemy retains at least one unknown equipped spell and baseline clues are never repeated',()=>{
 for(const starter of [pets,'steam',double] as const)for(const seed of ['SCOUT1','SCOUT2','SCOUT3'])for(const value of [1,2,4,5,7,8,9]){
  const run={...createTowerRun(seed,starter),floor:value};for(const room of towerRoomChoices(run)){
   const facts=scoutFactsForRoom(run,room),intel=towerRoomIntel(room);assert.equal(new Set(facts.map(fact=>fact.id)).size,facts.length);
   if(!room.enemies.length){assert.equal(facts.length,0);continue;}
   assert.equal(facts.some(fact=>fact.kind==='environment'),intel.environment===undefined);
   for(const enemy of room.enemies){
    const actual=enemy.creatureId?enemy.loadout:availableSpellIds(enemy.championId,enemy.loadout,enemy.affinities),revealed=facts.filter(fact=>fact.enemyId===enemy.id&&fact.kind==='spell').map(fact=>fact.spellId!);assert.ok(actual.length>=1);assert.equal(revealed.length,new Set(actual).size-1);assert.ok(revealed.every(id=>actual.includes(id)));
    const sighted=intel.knownEnemy?.championId===enemy.championId&&intel.knownEnemy?.creatureId===enemy.creatureId;assert.equal(facts.some(fact=>fact.enemyId===enemy.id&&fact.kind==='identity'),!sighted);
    for(const fact of facts.filter(fact=>fact.enemyId===enemy.id)){if(fact.kind==='affinity')assert.equal(fact.detail,`${fact.element![0].toUpperCase()}${fact.element!.slice(1)} ${enemy.affinities[fact.element!]}`);if(fact.kind==='health')assert.equal(fact.detail,`${enemy.hp}/${enemy.maxHp??8} HP`);if(fact.kind==='spell')assert.ok(fact.detail.startsWith(getSpell(fact.spellId!).name));}
   }
  }
 }
});

test('shared clues apply only to identical real encounters, including equal encounters across different start budgets',()=>{
 const small=createTowerRun('VARIANTS',pets),mixed=createTowerRun('VARIANTS'),large=createTowerRun('VARIANTS',double),allSmall=towerRoomChoices(small).flatMap(room=>scoutFactsForRoom(small,room));
 assert.notEqual(towerScoutEncounterKey(small,'floor-1-0'),towerScoutEncounterKey(mixed,'floor-1-0'));assert.notEqual(towerScoutEncounterKey(mixed,'floor-1-0'),towerScoutEncounterKey(large,'floor-1-0'));
 assert.equal(scoutReportsForRun(mixed,allSmall).filter(report=>report.roomId==='floor-1-0').length,0);
 const small2={...small,floor:2},mixed2={...mixed,floor:2},equalRoom=towerRoomChoices(small2)[0];assert.equal(towerScoutEncounterKey(small2,equalRoom.id),towerScoutEncounterKey(mixed2,equalRoom.id));const equalFacts=scoutFactsForRoom(small2,equalRoom);assert.deepEqual(scoutReportsForRun(mixed2,equalFacts),equalFacts);
 assert.equal(scoutReportsForRun(createTowerRun('OTHER'),allSmall).length,0);
 const own=scoutTowerRoom(mixed,'hero','floor-1-0'),merged=mergeTowerScouting(mixed,own.scouting!.reports);assert.equal(merged.scouting!.usedActorIds.length,0);assert.equal(towerScoutsAvailable(merged).length,1);assert.deepEqual(merged.party,mixed.party);
});

test('six squads can spend twelve champion actions on distinct finite facts without rerolling their own reports',()=>{
 const runs=Array.from({length:6},()=>createTowerRun('SIXSCOUTS',double)),pool:ScoutReport[]=[];
 for(let seat=0;seat<runs.length;seat++)for(const actorId of ['hero','companion']){
  const run=runs[seat],room=towerRoomChoices(run).find(room=>towerScoutOptions(run,room.id,pool).remaining>0)!;assert.ok(room);
  const next=scoutTowerRoom(run,actorId,room.id,{sharedReports:pool}),report=next.scouting!.reports.at(-1)!;assert.ok(!pool.some(known=>known.id===report.id));pool.push(report);runs[seat]=next;
 }
 assert.equal(pool.length,12);assert.equal(new Set(pool.map(report=>report.id)).size,12);
 for(const run of runs){assert.equal(run.scouting!.reports.length,2);assert.equal(run.scouting!.usedActorIds.length,2);assert.equal(scoutReportsForRun(run,pool).length,12);assert.deepEqual(restoreTowerSession(createTowerSession(run)).run,run);}
});

test('exhausted facts do not spend an action, and a complete scout pool still cannot reveal full kits',()=>{
 const run=createTowerRun('EXHAUST',double),room=towerRoomChoices(run)[0],pool=scoutFactsForRoom(run,room),before=JSON.stringify(run);
 assert.deepEqual(towerScoutOptions(run,room.id,pool),{remaining:0,canScout:false});assert.throws(()=>scoutTowerRoom(run,'hero',room.id,{sharedReports:pool}),/stay hidden/);assert.equal(JSON.stringify(run),before);assert.equal(towerScoutsAvailable(run).length,2);
 const elsewhere=towerRoomChoices(run)[1];assert.ok(towerScoutOptions(run,elsewhere.id,pool).canScout);assert.ok(scoutTowerRoom(run,'hero',elsewhere.id,{sharedReports:pool}).scouting);
});

test('save validation rejects forged facts, duplicate reports, stale floors and invalid champion allowances',()=>{
 const run=scoutTowerRoom(createTowerRun('FORGERY'),'hero','floor-1-0'),scouting=run.scouting!,report=scouting.reports[0];
 for(const changed of [
  {...scouting,floor:2},
  {...scouting,usedActorIds:['hero','hero']},
  {...scouting,usedActorIds:['companion']},
  {...scouting,usedActorIds:['invented']},
  {...scouting,reports:[]},
  {...scouting,reports:[report,report]},
  {...scouting,reports:[{...report,detail:'All enemies have 1 HP.'}]},
  {...scouting,reports:[{...report,id:'made up'}]},
  {...scouting,reports:[{...report,privateEnemyPlan:{orders:[]}}]},
 ])assert.throws(()=>validateTowerRun({...run,scouting:changed}));
 assert.equal(scoutReportsForRun(run,[{...report,detail:'false'}]).length,0);assert.deepEqual(scoutReportsForRun(run,[report,report]),[report]);
});
