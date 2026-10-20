import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {generateArena,normalizeArenaMapId,arenaStarts} from '../lib/arena-v17.ts';
import {distance} from '../lib/game.ts';
import {createTowerRun,towerFloorRooms,towerRoomChoices,chooseTowerRoom,createTowerSession,restoreTowerSession,validateTowerRun,towerRewardChoices,claimTowerReward,towerReplaceableActors,towerCreature,towerBattleConfig,finishTowerBattle,towerAvailableSpells,updateTowerLoadout,type TowerRun} from '../lib/tower-v23.ts';
import {CREATURES,getCreature,getCreaturePerk,teamPerkEffects} from '../lib/campaign-creatures-v20.ts';
import {getChampion} from '../lib/roster-v13.ts';
import {getSpell,teachingForEnemy} from '../lib/spells-v20.ts';
import {scoutTowerRoom,scoutReportsForRun} from '../lib/tower-scouting-actions.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';
import {createSharedTowerBattle,sharedActorId,finishSharedTowerBattle} from '../lib/tower-shared-battle-v23.ts';
import {resolveRound,restoreSimState,createTowerBattle,legalMoves,legalCasts,movementEffort,chooseAIPlan} from '../lib/tactics-v22.ts';
import {TOWER_MOTIFS,towerMotifFromMapId} from '../lib/tower-terrain-v44.ts';
import {towerRecruitComparison,towerLearningNotice} from '../lib/tower-choice-v44.ts';
import {towerReferenceSession,sharedTowerReference} from '../lib/tower-reference-v44.ts';
const key=(p:{q:number;r:number})=>`${p.q},${p.r}`;
const directions=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
/** Synthetic room settlement exercises run persistence and rewards, not fight balance. */
function advance(run:TowerRun,floor:number):TowerRun{
 while(run.floor<floor){
  run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);
  if(run.phase==='battle')run={...run,phase:'reward'};
  const reward=towerRewardChoices(run).find(r=>r.kind==='train')??towerRewardChoices(run)[0];
  run=claimTowerReward(run,reward.id,towerReplaceableActors(run)[0]?.id);
 }
 return run;
}
test('old legal map IDs retain exact terrain and version suffixes are explicit',()=>{
 for(const [id,hash] of [
  ['arena:2:LEGACY','83c6c2a8a831298923a6136d70cc0b99f8400471b5003cf2ad54dc80620be54d'],
  ['arena:6:OLD-SEED','ac6cf91ca6793f35d10a84d6173723512112d0215fe5bfc6f60de401f0a3e456'],
 ])assert.equal(createHash('sha256').update(JSON.stringify(generateArena(id))).digest('hex'),hash);
 assert.equal(normalizeArenaMapId('arena:3:hello:m44-CROSSING'),'arena:3:HELLO:m44-crossing');
 assert.throws(()=>normalizeArenaMapId('arena:3:hello:m44-unknown'));
 assert.equal(towerMotifFromMapId('arena:3:M44-CROSSING'),undefined,'an older seed name is never reinterpreted');
});
test('all motifs retain connected walkable terrain, clear centre and unique deployment for 2–6 companies',()=>{
 for(let count=2;count<=6;count++)for(const motif of TOWER_MOTIFS)for(const seed of ['A','B','C']){
  const id=`arena:${count}:${seed}:m44-${motif}`,cells=generateArena(id),walkable=new Map(cells.filter(c=>c.biome!=='ruins').map(c=>[key(c),c])),seen=new Set(['0,0']),queue=[{q:0,r:0}];
  for(let i=0;i<queue.length;i++)for(const d of directions){const p={q:queue[i].q+d.q,r:queue[i].r+d.r};if(walkable.has(key(p))&&!seen.has(key(p))){seen.add(key(p));queue.push(p);}}
  assert.equal(seen.size,walkable.size,id);assert.equal(walkable.get('0,0')!.biome,'plain');
  const starts=arenaStarts(id).flat();assert.equal(new Set(starts.map(key)).size,count*3);assert.ok(starts.every(p=>walkable.has(key(p))));
  const central=cells.filter(c=>distance(c,{q:0,r:0})<=4);
  if(motif==='crossing'){assert.ok(central.filter(c=>c.biome==='water').length>=3);assert.ok(cells.some(c=>c.q===0&&c.r===2&&c.biome==='plain'));assert.ok(cells.some(c=>c.q===0&&c.r===-2&&c.biome==='plain'));}
  if(motif==='courtyard')assert.ok(central.filter(c=>c.biome==='ruins').length>=2);
  if(motif==='grove'){assert.ok(central.some(c=>c.height===1));assert.ok(central.some(c=>c.biome==='forest'));}
 }
});
test('motif routes obey real movement and sight: both gates work, pools cost effort, and courtyard walls block shots',()=>{
 const reference=towerReferenceSession();
 for(const count of [2,6])for(const motif of TOWER_MOTIFS){
  const source=count===2?reference.battle!:sharedTowerReference(6),state=createTowerBattle({...source.tower,mapId:`arena:${count}:ROUTE44:m44-${motif}`,environment:'plain'}),hero=state.units.find(u=>u.owner===0)!;
  for(const r of [-2,2]){
   Object.assign(hero,{q:-1,r});
   assert.ok(legalMoves(state,hero.id).some(c=>c.q===1&&c.r===r),`${count}:${motif} has a traversable gate at ${r}`);
   assert.ok(legalCasts(state,hero.id,undefined,'water_jet').some(c=>c.q===1&&c.r===r),`${count}:${motif} allows a shot through its gate`);
  }
  if(motif==='crossing'){
   Object.assign(hero,{q:-1,r:2});const dry=movementEffort(state,hero.id,{q:1,r:2})!;
   Object.assign(hero,{q:-1,r:3});const wet=movementEffort(state,hero.id,{q:1,r:3})!;
   assert.ok(wet>dry,`water route ${wet} versus dry gate ${dry}`);
  }
  if(motif==='courtyard'){Object.assign(hero,{q:-1,r:1});assert.ok(!legalCasts(state,hero.id,undefined,'water_jet').some(c=>c.q===1&&c.r===1));}
 }
});
test('new encounter versions replay deterministically, while legacy pending battles and history stay legacy',()=>{
 const fresh=createTowerRun('PERSIST44');assert.equal(fresh.encounterModel,'motifs44');
 assert.deepEqual(towerRoomChoices(fresh),towerRoomChoices(createTowerRun('PERSIST44')));
 const pending=createTowerSession(chooseTowerRoom(fresh,towerRoomChoices(fresh)[0].id));
 assert.deepEqual(restoreTowerSession(JSON.stringify(pending)),pending);
 const old=createTowerRun('OLD-RUN');delete old.encounterModel;delete old.encounterVariant;
 const route=advance(old,4);assert.ok(route.history.every(room=>!room.mapId.includes(':m44-')));
 const session=createTowerSession(chooseTowerRoom(route,towerRoomChoices(route)[0].id));delete session.battle!.spellModel;
 assert.deepEqual(restoreTowerSession(session),session);assert.equal(session.run.encounterModel,undefined);
 assert.throws(()=>validateTowerRun({...fresh,encounterModel:'invented'}));
 assert.throws(()=>validateTowerRun({...fresh,encounterVariant:3}));
 assert.throws(()=>validateTowerRun({...old,encounterVariant:1}));
});
test('support variants retain opening pressure, strength class, teacher anchor and exact scouted enemies',()=>{
 let changed=0;
 for(let seed=0;seed<12;seed++)for(const variant of [0,1,2] as const){
  const run=createTowerRun(`ROLES-${seed}`,'steam',6,variant),base=towerRoomChoices(createTowerRun(run.seed,'steam',6,0));
  for(const [index,room] of towerRoomChoices(run).entries()){
   assert.deepEqual(room.enemies[0],base[index].enemies[0]);assert.equal(room.mapId,base[index].mapId);assert.equal(room.enemies.length,base[index].enemies.length);
   assert.ok(room.enemies.some(a=>a.loadout.some(id=>getSpell(id).damage>=2)));
   assert.notEqual(getChampion(room.enemies[0].championId).element,getChampion(room.enemies[1].championId).element);
   assert.equal(getCreature(room.enemies[1].creatureId!).strengthClass,getCreature(base[index].enemies[1].creatureId!).strengthClass);
   if(room.enemies[1].creatureId!==base[index].enemies[1].creatureId)changed++;
   const scouted=scoutTowerRoom(run,'hero',room.id),report=scouted.scouting!.reports[0];
   assert.notEqual(report.kind,'health','an actionable unknown aspect is preferred');
   assert.ok(scoutFactsForRoom(run,room).some(fact=>fact.id===report.id));
   assert.deepEqual(chooseTowerRoom(scouted,room.id).currentRoom!.enemies,room.enemies);
   assert.deepEqual(scoutReportsForRun(run,scouted.scouting!.reports),scouted.scouting!.reports);
  }
 }
 assert.ok(changed>30,`support variety must actually appear (${changed})`);
});
test('a shared door uses each pre-scouted contribution, changes no enemy budget and preserves split discovery benefit',()=>{
 const runs=Array.from({length:6},(_,seat)=>chooseTowerRoom(createTowerRun('AUDIT43','steam',6,seat%3 as 0|1|2),'floor-1-0')),battle=createSharedTowerBattle(runs.map((run,seat)=>({seat,run})));
 for(const [seat,run] of runs.entries())for(const enemy of run.currentRoom!.enemies){
  const actual=battle.units.find(unit=>unit.id===sharedActorId(seat,enemy.id))!;
  assert.equal(actual.creatureId,enemy.creatureId);assert.deepEqual(actual.affinities,enemy.affinities);assert.deepEqual(actual.loadout,enemy.loadout);assert.equal(actual.maxHp,enemy.maxHp);
 }
 const joined=new Set(battle.units.filter(u=>u.owner===1).map(u=>teachingForEnemy(u).id));
 const split=new Set(Array.from({length:6},(_,seat)=>towerRoomChoices(createTowerRun('AUDIT43','steam',6,seat%3 as 0|1|2))[seat].enemies.flatMap(e=>teachingForEnemy(e).id)).flat());
 assert.equal(battle.units.filter(u=>u.owner===1).length,12);assert.ok(joined.size>2);assert.ok(split.size>joined.size,`${split.size} split versus ${joined.size} joined`);
});
test('shared victory teaches precisely defeated enemy techniques, not hypothetical variant enemies',()=>{
 const runs=[0,1].map(seat=>chooseTowerRoom(createTowerRun('TEACH44','steam',2,seat as 0|1),'floor-1-0')),battle=createSharedTowerBattle(runs.map((run,seat)=>({seat,run})));
 const expected=new Set([...runs[0].learnedSpells,...battle.units.filter(u=>u.owner===1).map(u=>teachingForEnemy(u).id)]);
 // Synthetic terminal state: this test verifies teaching provenance, not combat performance.
 for(const unit of battle.units.filter(u=>u.owner===1)){unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;}
 const terminal=resolveRound(battle,[{orders:[]},{orders:[]}]);
 assert.deepEqual(new Set(finishSharedTowerBattle(runs[0],terminal,0).learnedSpells),expected);
});
test('greater creatures occupy one late elite or summit support slot, never the opening',()=>{
 for(const variant of [0,1,2] as const)for(const floor of [1,2,5,7,8,9]){
  const run={...createTowerRun('GREATER44','steam',6,variant),floor};
  for(const room of towerFloorRooms(run).filter(r=>r.enemies.length)){
   const greater=room.enemies.filter(a=>a.creatureId&&getCreature(a.creatureId).strengthClass==='greater');
   assert.equal(greater.length,floor>=7&&(room.kind==='elite'||floor===9)?1:0,`${variant}:${floor}:${room.id}`);
  }
 }
});
test('recruit comparisons report the actual legal replacement and real gained or lost creature bonds',()=>{
 const run=createTowerRun('BONDS44');run.party.push(towerCreature('creature-water-puddle','recruit-old'));
 const candidate=towerCreature('creature-steam','new');
 for(const option of towerRecruitComparison(run,candidate)){
  assert.ok(towerReplaceableActors(run).some(a=>a.id===option.replaceId));
  const before=teamPerkEffects(run.party.flatMap(a=>a.creatureId?[a.creatureId]:[])).perkIds;
  const after=teamPerkEffects([...run.party.filter(a=>a.id!==option.replaceId).flatMap(a=>a.creatureId?[a.creatureId]:[]),candidate.creatureId!]).perkIds;
  assert.deepEqual(option.gainedBonds,after.filter(id=>!before.includes(id)).map(id=>getCreaturePerk(id).name));
  assert.deepEqual(option.lostBonds,before.filter(id=>!after.includes(id)).map(id=>getCreaturePerk(id).name));
 }
 const solo=createTowerRun('ADD44');assert.equal(towerRecruitComparison(solo,candidate)[0].replaceId,null);
});
test('automatic learning distinguishes immediately equipable knowledge from affinity-locked knowledge',()=>{
 const run=createTowerRun('KNOW44'),before=[...run.learnedSpells];
 run.learnedSpells.push('frostbite');assert.match(towerLearningNotice(run,before),/ready to equip between rooms/);
 run.learnedSpells=[...before,'reap'];assert.match(towerLearningNotice(run,before),/Stored for a matching champion or affinity/);
 assert.equal(towerLearningNotice(run,run.learnedSpells),'');
});
test('reference fixtures use ordinary legal solo and 2/4/6-squad rules with distinct deployment',()=>{
 const solo=towerReferenceSession();assert.equal(towerMotifFromMapId(solo.battle!.mapId),'crossing');
 assert.ok(solo.battle!.units.filter(u=>u.owner===0).some(u=>u.loadout.includes('water_jet')));
 assert.ok(solo.battle!.units.filter(u=>u.owner===0).some(u=>u.loadout.includes('undertow')));
 assert.ok(solo.battle!.units.filter(u=>u.owner===0).some(u=>u.loadout.some(id=>getSpell(id).element==='fire')));
 assert.deepEqual(restoreTowerSession(solo),solo);
 for(const count of [2,4,6] as const){const battle=sharedTowerReference(count);assert.equal(new Set(battle.units.map(key)).size,battle.units.length);assert.deepEqual(restoreSimState(battle),battle);}
});
test('the reference completes a real battle, learns its defeated foes, equips a teaching and carries it into the next room',t=>{
 const session=towerReferenceSession();let battle=session.battle!,exchanges=0;
 while(battle.winner===null&&exchanges<16){battle=resolveRound(battle,[chooseAIPlan(battle,0),chooseAIPlan(battle,1)]);exchanges++;}
 assert.equal(battle.winner,0,'reference baseline AI party should reach the post-battle decision');
 let run=finishTowerBattle(session.run,battle);
 const defeated=battle.units.filter(u=>u.owner===1&&u.hp===0).map(u=>teachingForEnemy(u).id),learned=defeated.filter(id=>!session.run.learnedSpells.includes(id));
 assert.ok(learned.length>0);assert.ok(learned.every(id=>run.learnedSpells.includes(id)));
 const rewards=towerRewardChoices(run);assert.ok(new Set(rewards.map(r=>r.kind)).size>=2);
 const training=rewards.find(r=>r.kind==='train')!;assert.ok(training);
 run=claimTowerReward(run,training.id);
 const teaching=towerAvailableSpells(run,'hero').find(spell=>learned.includes(spell.id));assert.ok(teaching,'at least one defeated foe teaches an immediately usable tool');
 run=updateTowerLoadout(run,'hero',[teaching.id,...run.party[0].loadout.slice(1)]);
 assert.deepEqual(restoreTowerSession(createTowerSession(run)).run,run);
 const next=createTowerSession(chooseTowerRoom(run,towerRoomChoices(run)[0].id));
 assert.equal(next.run.floor,2);assert.ok(next.battle!.units.find(u=>u.id==='hero')!.loadout.includes(teaching.id));
 assert.deepEqual(restoreTowerSession(next),next);
 t.diagnostic(`Reference baseline: ${exchanges} exchanges, learned ${learned.length}, equipped ${teaching.id}; this is deterministic AI flow evidence, not human playtest evidence.`);
});
