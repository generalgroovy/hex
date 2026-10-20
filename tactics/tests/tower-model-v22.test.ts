import test from 'node:test';
import assert from 'node:assert/strict';
import {CREATURES,getCreature} from '../lib/campaign-creatures-v20.ts';
import {CHAMPIONS,getChampion,affinityTotal} from '../lib/roster-v13.ts';
import {defaultLoadout,getSignature,getSpell,spellCost,teachingForEnemy} from '../lib/spells-v20.ts';
import {createTowerRun,createCoopTowerRun,validateTowerStarter,validateTowerBuild,towerBuildSpells,towerRoomChoices,chooseTowerRoom,towerBattleConfig,createTowerSession,restoreTowerSession,validateTowerRun,towerController,towerControlledActorIds,updateTowerBuild,towerRewardChoices,claimTowerReward,finishTowerBattle,towerCreature,TOWER_STARTERS,type TowerBuild,type TowerRun} from '../lib/tower-v22.ts';
import {createTowerBattle,restoreSimState,resolveRound,resolveCoopRound,validateCoopPlan,validatePlan,chooseAIPlan,legalCasts,isCellSolid,getCell,type TeamPlan,type SimState} from '../lib/tactics-v22.ts';
import {endgameForecast} from '../lib/tower-endgame-v22.ts';
const empty=():TeamPlan=>({orders:[]});
const battle=(mode:'solo'|'coop'='solo')=>{let run=mode==='solo'?createTowerRun('TEST','steam'):createCoopTowerRun('TEST','steam','dusk');run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);return createTowerBattle(towerBattleConfig(run));};
const defeatForTest=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;};
/** Synthetic settlement fixture only; full-climb diagnostics use actual AI/resolver battles. */
function completeRoomForTest(run:TowerRun):TowerRun {
 if(run.phase==='battle'){const state=createTowerBattle(towerBattleConfig(run));for(const enemy of state.units.filter(u=>u.owner===1))defeatForTest(enemy);run=finishTowerBattle(run,resolveRound(state,[empty(),empty()]));}
 if(run.phase==='reward'){const choices=towerRewardChoices(run),reward=choices.find(r=>r.kind==='recruit')??choices.find(r=>r.kind==='train')??choices[0];run=claimTowerReward(run,reward.id,run.party.find(a=>!['hero','partner'].includes(a.id))?.id);}return run;
}

test('all champion appearances and lesser companions support strict five-point starts',()=>{
 for(const champion of CHAMPIONS){const affinities={[champion.element]:3,[champion.element==='water'?'fire':'water']:2},build={championId:champion.id,name:champion.name,affinities,loadout:defaultLoadout(champion.id,affinities)};const run=createTowerRun('CUSTOM',{starterId:'steam',build});assert.equal(affinityTotal(run.party[0].affinities),5);assert.deepEqual(restoreTowerSession(createTowerSession(run)).run,validateTowerRun(run));assert.ok(towerBuildSpells(build).every(spell=>spell.id!==getSignature(champion.id).id));}
 for(const creature of CREATURES.filter(creature=>creature.strengthClass==='lesser'))assert.equal(validateTowerStarter({starterId:'stone',companionId:creature.id}).companionId,creature.id);
 assert.throws(()=>validateTowerStarter({starterId:'steam',companionId:CREATURES.find(c=>c.strengthClass==='greater')!.id}));
});
test('builds enforce exact budgets, three elements, creator identity, four distinct affordable spells, and learned ownership',()=>{
 const run=createTowerRun('BUILD','steam'),actor=run.party[0],build:TowerBuild={championId:actor.championId,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout};
 for(const bad of [{...build,affinities:{water:4,fire:1}},{...build,affinities:{water:2,fire:1,earth:1,air:1}},{...build,affinities:{fire:3,water:2}},{...build,loadout:build.loadout.slice(1)},{...build,name:'<script>'},{...build,loadout:[...build.loadout.slice(1),build.loadout[1]]}])assert.throws(()=>validateTowerBuild(bad));
 const renamed=updateTowerBuild(run,'hero',{...build,name:'Captain Damp'});assert.equal(renamed.party[0].displayName,'Captain Damp');assert.equal(renamed.party[0].hp,actor.hp);
 assert.throws(()=>updateTowerBuild(run,'hero',{...build,championId:'s_wayne'}));
 const notOwned=towerBuildSpells(build).find(spell=>!run.learnedSpells.includes(spell.id));assert.ok(notOwned);assert.throws(()=>updateTowerBuild(run,'hero',{...build,loadout:[notOwned.id,...build.loadout.slice(1)]}));
});
test('cooperative founders stay protected and control follows the party member across floor changes',()=>{
 const run=createCoopTowerRun('COOP','steam','dusk');assert.equal(run.party.length,3);assert.deepEqual(towerControlledActorIds(run,0),['hero','companion']);assert.deepEqual(towerControlledActorIds(run,1),['partner']);assert.equal(towerController({...run,floor:2},'companion'),1);
 assert.throws(()=>createCoopTowerRun('SAME','steam','steam'));
 assert.throws(()=>validateTowerRun({...run,party:run.party.filter(a=>a.id!=='partner')}));
 const room=towerRoomChoices(run)[0];assert.equal(room.enemies.length,3);
});
test('preset Dusk has an equipped Light attack and training drafts improve a usable affinity',()=>{
 const dusk=createTowerRun('DRAFT','dusk');assert.ok(dusk.party[0].loadout.includes('radiant_bolt'));assert.ok(dusk.learnedSpells.includes('radiant_bolt'));assert.equal(dusk.party[1].creatureId,'creature-air-whisk');assert.ok(dusk.party[1].loadout.some(id=>getSpell(id).push));assert.ok(dusk.party[0].loadout.includes('mend'));
 for(const starter of TOWER_STARTERS)for(const seed of ['DRAFT1','DRAFT2','DRAFT3']){
  const route=createTowerRun(seed,starter.id),room=towerRoomChoices(route)[0],rewardRun={...route,phase:'reward' as const,currentRoom:room};
  const training=towerRewardChoices(rewardRun).find(reward=>reward.kind==='train')!;assert.equal(training.element,getChampion(route.party.find(a=>a.id===training.actorId)!.championId).element);
 }
});
test('every opening pair has distinct elements and a genuine attacker, never two defensive specialists',()=>{
 for(let seed=0;seed<32;seed++)for(const floor of [1,2])for(const room of towerRoomChoices({...createTowerRun(`PRESSURE${seed}`,'dusk'),floor})){
  const enemies=room.enemies;assert.ok(enemies.some(actor=>actor.loadout.some(id=>getSpell(id).damage>=2)),`${seed}:${floor}:${room.id}`);assert.notEqual(getChampion(enemies[0].championId).element,getChampion(enemies[1].championId).element);
 }
});
test('Dusk breaks the former ward-and-control opening within nine exchanges, with both allies alive and no collapse',()=>{
 let run=createTowerRun('TOWER3','dusk');run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);let state=createTowerBattle(towerBattleConfig(run));
 // Current joint planning originally refreshed redundant Ward until a round-12
 // collapse draw (24 damage). Marginal protection utility restores a real win.
 while(state.winner===null&&state.round<=9){state=resolveRound(state,[chooseAIPlan(state,0),chooseAIPlan(state,1)]);assert.deepEqual(restoreSimState(state),state);assert.ok(!state.lastResolution.some(event=>event.cause==='collapse'));}
 assert.equal(state.winner,0);assert.ok(state.units.filter(unit=>unit.owner===0).every(unit=>unit.hp>0));
});
test('defeating one enemy teaches exactly that enemy technique even in a lost room',()=>{
 let run=createTowerRun('TEACH','steam');run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);const state=createTowerBattle(towerBattleConfig(run)),enemy=state.units.find(u=>u.owner===1)!;
 for(const unit of state.units.filter(u=>u.owner===0||u.id===enemy.id))defeatForTest(unit);
 const defeated=resolveRound(state,[empty(),empty()]),finished=finishTowerBattle(run,defeated),expected=[...new Set([...run.learnedSpells,teachingForEnemy(enemy).id])].sort();
 assert.equal(finished.phase,'lost');assert.deepEqual(finished.learnedSpells,expected);assert.ok(finished.party.every(a=>a.hp===0));assert.deepEqual(restoreTowerSession(createTowerSession(finished)).run,finished);
});
test('sixth-floor camp offers recovery, useful training and a canonical stronger companion',()=>{
 let run=createTowerRun('CAMP','steam');while(run.floor<6){const room=towerRoomChoices(run).find(r=>r.kind===(run.floor===3?'recruit':'combat'))!;run=completeRoomForTest(chooseTowerRoom(run,room.id));}
 run.party[0].hp=3;run=chooseTowerRoom(run,towerRoomChoices(run).find(r=>r.kind==='camp')!.id);
 const choices=towerRewardChoices(run);assert.deepEqual(choices.map(r=>r.kind),['heal','train','recruit']);const upgrade=choices[2];assert.equal(getCreature(upgrade.actor!.creatureId!).strengthClass,'standard');assert.equal(upgrade.actor!.maxHp,6);
 assert.throws(()=>claimTowerReward(run,upgrade.id,'hero'));const upgraded=claimTowerReward(run,upgrade.id,'companion');assert.ok(upgraded.party.some(a=>a.id==='camp-6-companion'));assert.ok(upgrade.actor!.loadout.every(id=>upgraded.learnedSpells.includes(id)));assert.deepEqual(restoreTowerSession(createTowerSession(upgraded)).run,upgraded);
});
test('cooperative recruitment cannot dismiss either founder and tuition has a genuine higher reward',()=>{
 let run=createCoopTowerRun('FOUNDERS','steam','dusk');while(run.floor<3)run=completeRoomForTest(chooseTowerRoom(run,towerRoomChoices(run)[0].id));
 const event=chooseTowerRoom(run,towerRoomChoices(run).find(r=>r.kind==='event')!.id);assert.equal(event.party[0].hp,run.party[0].hp-1);assert.equal(event.party[1].hp,run.party[1].hp-1);assert.ok(towerRewardChoices(event).some(r=>r.kind==='train'&&r.amount===2));
 const recruitment=chooseTowerRoom(run,towerRoomChoices(run).find(r=>r.kind==='recruit')!.id),reward=towerRewardChoices(recruitment)[0];for(const id of ['hero','partner'])assert.throws(()=>claimTowerReward(recruitment,reward.id,id));
});
test('room lanes have different real environmental openings and initial saves cannot change them',()=>{
 const run=createTowerRun('ENV','stone'),rooms=towerRoomChoices(run);assert.equal(new Set(rooms.map(r=>r.environment)).size,3);
 for(const room of rooms){const current=chooseTowerRoom(run,room.id),state=createTowerBattle(towerBattleConfig(current));assert.deepEqual(restoreSimState(state),state);const marked=state.cells.filter(c=>c.ttl!==undefined);assert.equal(marked.length,room.environment==='plain'?0:6);assert.ok(state.units.every(u=>Math.max(Math.abs(u.q),Math.abs(u.r),Math.abs(u.q+u.r))<=4));if(marked.length){marked[0].ttl=1;assert.throws(()=>restoreSimState(state));}}
});
test('public closure warning is earlier, bosses have two extra exchanges, and idle teams lose by damage',()=>{
 assert.equal(endgameForecast({playerCount:2,boardRadius:9,round:4}).phase,'warning');assert.equal(endgameForecast({playerCount:2,boardRadius:9,round:1}).finalRound,12);assert.equal(endgameForecast({playerCount:2,boardRadius:9,round:1,tower:{encounter:'boss'}}).finalRound,14);
 let state=battle();while(state.winner===null){state=resolveRound(state,[empty(),empty()]);assert.deepEqual(restoreSimState(state),state);}assert.ok(state.round<=12);assert.ok(state.units.filter(u=>u.owner===(state.winner===0?1:0)).every(u=>u.hp===0));assert.ok(state.lastResolution.some(e=>e.cause==='collapse'));
});
test('cooperative drafts reject another controller and preserve partial drafts',()=>{
 const state=battle('coop');assert.throws(()=>validateCoopPlan(state,0,{orders:[{unitId:'partner',guard:true}]}));assert.deepEqual(validateCoopPlan(state,0,{orders:[{unitId:'hero',guard:true}],link:true}),{orders:[{unitId:'hero',guard:true}],link:true});assert.throws(()=>validatePlan(battle(),0,{orders:[],link:true}));assert.throws(()=>validatePlan(state,1,{orders:[],link:true}));
 const after=resolveCoopRound(state,[empty(),empty()],empty());assert.deepEqual(restoreSimState(after),after);
});
function linkPosition():SimState {
 const state=battle('coop'),hero=state.units.find(u=>u.id==='hero')!,partner=state.units.find(u=>u.id==='partner')!,enemy=state.units.find(u=>u.owner===1)!;
 for(const centre of state.cells){const points=[{q:centre.q-1,r:centre.r},{q:centre.q,r:centre.r-1},centre];if(points.some(p=>!getCell(state,p.q,p.r)||isCellSolid(getCell(state,p.q,p.r)!))||state.units.some(u=>![hero,partner,enemy].includes(u)&&points.some(p=>p.q===u.q&&p.r===u.r)))continue;
  Object.assign(hero,points[0]);Object.assign(partner,points[1]);Object.assign(enemy,{q:centre.q,r:centre.r,hp:4});
  if(legalCasts(state,hero.id,undefined,'water_jet').some(p=>p.q===enemy.q&&p.r===enemy.r)&&legalCasts(state,partner.id,undefined,'wither_bolt').some(p=>p.q===enemy.q&&p.r===enemy.r))return state;
 }throw Error('No link fixture geometry');
}
test('Link requires both consents, two controllers and two elements; it pays exactly one Flux each',()=>{
 const state=linkPosition(),target=state.units.find(u=>u.owner===1)!,aim={q:target.q,r:target.r};for(const id of ['hero','partner'])state.units.find(u=>u.id===id)!.flux=3;
 const plans:[TeamPlan,TeamPlan]=[{orders:[{unitId:'hero',spellId:'water_jet',cast:aim}],link:true},{orders:[{unitId:'partner',spellId:'wither_bolt',cast:aim}],link:true}];
 const without=resolveCoopRound(state,[plans[0],{...plans[1],link:false}],empty()),linked=resolveCoopRound(state,plans,empty()),events=linked.lastResolution.filter(e=>e.cause==='link');
 assert.equal(events.length,1);assert.equal(without.lastResolution.filter(e=>e.cause==='link').length,0);assert.equal(linked.lastResolution.find(e=>e.kind==='damage'&&e.unitId===target.id)!.amount,without.lastResolution.find(e=>e.kind==='damage'&&e.unitId===target.id)!.amount!+1);
 assert.deepEqual(restoreSimState(linked),linked);for(const id of ['hero','partner'])assert.equal(linked.units.find(u=>u.id===id)!.flux,without.units.find(u=>u.id===id)!.flux-1);
 const depleted=structuredClone(state);for(const plan of plans)for(const order of plan.orders){const unit=depleted.units.find(u=>u.id===order.unitId)!;unit.flux=spellCost(unit.championId,order.spellId!,unit.affinities);}assert.ok(!resolveCoopRound(depleted,plans,empty()).lastResolution.some(e=>e.cause==='link'));
 const forged=structuredClone(linked);forged.lastResolution.find(e=>e.cause==='link')!.elements=['earth','air'];assert.throws(()=>restoreSimState(forged));
});
test('Overtime taxes combined healing once, cannot be cleansed, and never taxes damage',()=>{
 let run=createTowerRun('HEAL',{starterId:'steam',companionId:'creature-water-puddle'});run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);
 const initial=createTowerBattle({...towerBattleConfig(run),environment:'plain'}),hero=initial.units.find(u=>u.id==='hero')!,pet=initial.units.find(u=>u.id==='companion')!;
 const pool=initial.cells.filter(c=>c.terrain==='plain'&&!isCellSolid(c)&&Math.max(Math.abs(c.q),Math.abs(c.r),Math.abs(c.q+c.r))<=3&&!initial.units.some(u=>u.owner===1&&u.q===c.q&&u.r===c.r));
 const cell=pool.find(c=>pool.some(p=>Math.max(Math.abs(p.q-c.q),Math.abs(p.r-c.r),Math.abs(p.q-c.q+p.r-c.r))===1))!,adjacent=pool.find(p=>Math.max(Math.abs(p.q-cell.q),Math.abs(p.r-cell.r),Math.abs(p.q-cell.q+p.r-cell.r))===1)!;
 Object.assign(hero,{q:cell.q,r:cell.r,hp:1,statuses:{wither:{turns:2,power:1}}});Object.assign(pet,{q:adjacent.q,r:adjacent.r});
 const plan={orders:[{unitId:'hero',spellId:'cleansing_tide',cast:{q:cell.q,r:cell.r}},{unitId:'companion',spellId:'cleansing_tide',cast:{q:cell.q,r:cell.r}}]};
 const resolve=(round:number)=>{const state=structuredClone(initial);state.round=round;state.version=round;return resolveRound(state,[plan,empty()]);};
 const amount=(state:SimState)=>state.lastResolution.find(e=>e.kind==='heal'&&e.unitId==='hero')!.amount!;
 assert.equal(amount(resolve(5))-amount(resolve(6)),1);assert.equal(amount(resolve(5))-amount(resolve(9)),2);assert.deepEqual(restoreSimState(resolve(6)),resolve(6));
});
test('AI remains deterministic, legal and independent of previous Guard markers',()=>{
 for(const starter of TOWER_STARTERS){let run=createTowerRun('PUBLIC',starter.id);run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);const state=createTowerBattle(towerBattleConfig(run)),baseline=chooseAIPlan(state,0);assert.deepEqual(validatePlan(state,0,baseline),baseline);const altered=structuredClone(state);for(const u of altered.units)u.guard=true;assert.deepEqual(chooseAIPlan(altered,0),baseline);}
});
