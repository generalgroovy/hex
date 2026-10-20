import test from 'node:test';
import assert from 'node:assert/strict';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {CREATURES,getCreature} from '../lib/campaign-creatures-v20.ts';
import {getSpell,getSignature,getCreatureSpell,spellElements} from '../lib/spells-v20.ts';
import {createTowerBattle,validateTowerBattleConfig,restoreSimState,resolveRound,validatePlan,availableUnitSpellIds,chooseAIPlan,legalCasts,isCellSolid,plannedProjectileClashes,combinationFor,effectiveSpell,previewField,volleyDamage,spellArea,type TowerActor,type TowerBattleConfig,type SimState,type TeamPlan} from '../lib/tactics-v22.ts';

const empty=():TeamPlan=>({orders:[]});
const champion=(id:string,championId='oh_tipi',hp=8):TowerActor=>{const build=canonicalBuild(championId);return {id,championId,displayName:build.name,affinities:build.affinities,loadout:build.loadout,hp};};
const creature=(id:string,creatureId='creature-fire-cinder'):TowerActor=>{const spec=getCreature(creatureId);return {id,championId:spec.championId,creatureId,affinities:{...spec.affinities},loadout:[...spec.loadout],hp:spec.maxHp};};
const room=(allies:TowerActor[]=[champion('hero')],enemies:TowerActor[]=[creature('enemy')]):TowerBattleConfig=>({id:'floor-1-left',mapId:'arena:2:TOWER-TEST',allies,enemies,learnedSpells:[]});
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.cooldowns={};unit.statuses={};delete unit.guard;};

test('room sizes one through three, mixed recruits, and carried wounds survive exact restoration',()=>{
 for(let allies=1;allies<=3;allies++)for(let enemies=1;enemies<=3;enemies++){
  const config=room([champion('hero','oh_tipi',3),champion('friend','wa_bidi',6),creature('pet')].slice(0,allies),[champion('boss','red_baron'),creature('minion'),creature('second','creature-water-puddle')].slice(0,enemies));
  const state=createTowerBattle(config);assert.equal(state.rulesVersion,22);assert.equal(state.units.length,allies+enemies);assert.equal(state.units[0].hp,3);assert.equal(state.units[0].maxHp,8);assert.deepEqual(restoreSimState(JSON.parse(JSON.stringify(state))),state);
  const next=resolveRound(state,[empty(),empty()]);assert.deepEqual(restoreSimState(next),next);assert.deepEqual(next.tower,state.tower);assert.equal(next.units[0].hp,3,'An idle turn cannot heal carried wounds');
 }
});

test('seed and actor inputs are cloned and deterministic; different seeds change terrain',()=>{
 const config=room(),state=createTowerBattle(config);assert.deepEqual(createTowerBattle(config),state);
 config.allies[0].hp=1;config.allies[0].affinities.water=6;assert.equal(state.tower.allies[0].hp,8);assert.equal(state.units[0].affinities.water,3);
 assert.notDeepEqual(createTowerBattle({...room(),mapId:'ANOTHER-SEED'}).cells,state.cells);
 assert.equal(validateTowerBattleConfig({...room(),mapId:'tower-test'}).mapId,'arena:2:TOWER-TEST');
});

test('room entry refuses stat inflation, forged creature kits, duplicate identities, and unavailable learned spells',()=>{
 for(const update of [
  (r:TowerBattleConfig)=>{r.allies=[];},
  (r:TowerBattleConfig)=>{r.allies[0].hp=0;},
  (r:TowerBattleConfig)=>{r.allies[0].maxHp=99;},
  (r:TowerBattleConfig)=>{r.enemies[0].maxFlux=99;},
  (r:TowerBattleConfig)=>{r.enemies[0].loadout[0]='water_jet';},
  (r:TowerBattleConfig)=>{r.enemies[0].affinities.water=6;},
  (r:TowerBattleConfig)=>{r.enemies[0].id=r.allies[0].id;},
  (r:TowerBattleConfig)=>{r.learnedSpells=['water_jet'];},
  (r:TowerBattleConfig)=>{r.allies[0].loadout[0]=getSignature('red_baron').id;},
  (r:TowerBattleConfig)=>{r.allies[0].affinities={water:6,fire:6,air:6,earth:1};},
  (r:TowerBattleConfig)=>{r.mapId='arena:6:TEST';},
 ]){const config=room();update(config);assert.throws(()=>createTowerBattle(config));}
});

test('all 93 species keep their own technique, including every multi-element mixture',()=>{
 for(const spec of CREATURES){
  const state=createTowerBattle(room([champion('hero')],[creature('enemy',spec.id)])),actor=state.units[1],spellId=getCreatureSpell(spec.id).id;
  assert.ok(availableUnitSpellIds(state,actor.id).includes(spellId),spec.id);assert.ok(!availableUnitSpellIds(state,actor.id).includes(getSignature(actor.championId).id),spec.id);
  const targets=legalCasts(state,actor.id,undefined,spellId),target=targets.find(point=>point.q===actor.q&&point.r===actor.r)??targets[0];assert.ok(target,spec.id);
  const result=resolveRound(state,[empty(),{orders:[{unitId:actor.id,spellId,cast:{q:target.q,r:target.r}}]}]),cast=result.lastResolution.find(event=>event.kind==='cast'&&event.unitId===actor.id);
  assert.ok(cast,spec.id);assert.deepEqual(cast.elements,spellElements(getCreatureSpell(spec.id)));assert.deepEqual(restoreSimState(result),result,spec.id);
 }
});

test('mixed projectiles meet mid-flight and produce one complete combined field',()=>{
 const pair=['Hush','Crackle'].map(name=>CREATURES.find(spec=>spec.name===name)!);
 const state=createTowerBattle(room(pair.map((spec,index)=>creature(`ally-${index}`,spec.id)))),actors=state.units.filter(unit=>unit.owner===0);let plan:TeamPlan|undefined;
 for(const centre of [...state.cells].sort((a,b)=>Math.abs(a.q)+Math.abs(a.r)-Math.abs(b.q)-Math.abs(b.r))){
  const points=[{q:centre.q-1,r:centre.r},{q:centre.q+1,r:centre.r}];
  if(points.some(point=>!state.cells.some(cell=>cell.q===point.q&&cell.r===point.r&&!isCellSolid(cell))||state.units.some(unit=>!actors.includes(unit)&&unit.q===point.q&&unit.r===point.r)))continue;
  actors.forEach((actor,index)=>Object.assign(actor,points[index]));
  if(actors.every((actor,index)=>legalCasts(state,actor.id,undefined,actor.loadout[0]).some(point=>point.q===points[1-index].q&&point.r===points[1-index].r))){plan=validatePlan(state,0,{orders:actors.map((actor,index)=>({unitId:actor.id,spellId:actor.loadout[0],cast:points[1-index]}))});break;}
 }
 assert.ok(plan);const clashes=plannedProjectileClashes(state,plan);assert.equal(clashes.length,1);assert.deepEqual([...clashes[0].elements].sort(),['air','fire','water']);
 const result=resolveRound(state,[plan,empty()]),clash=result.lastResolution.find(event=>event.kind==='clash');assert.ok(clash);assert.equal(clash.flightFraction,.5);assert.equal(clash.terrain,combinationFor(['fire','water','air'])!.id);assert.deepEqual(restoreSimState(result),result);
});

test('one remaining enemy prevents victory and an eliminated team ends the battle',()=>{
 const state=createTowerBattle(room([champion('hero')],[creature('enemy'),creature('second','creature-water-puddle')]));
 const first=state.units.find(unit=>unit.id==='enemy')!;kill(first);
 const partial=resolveRound(state,[empty(),empty()]);assert.equal(partial.winner,null);assert.deepEqual(restoreSimState(partial),partial);
 kill(partial.units.find(unit=>unit.id==='second')!);const won=resolveRound(partial,[empty(),empty()]);assert.equal(won.winner,0);assert.deepEqual(restoreSimState(won),won);assert.throws(()=>validatePlan(won,0,empty()));
});

test('closing ground finishes idle battles by damage, never a live timeout draw',()=>{
 let state=createTowerBattle(room([champion('hero')],[champion('enemy','wa_bidi')]));
 while(state.winner===null&&state.round<=20)state=resolveRound(state,[empty(),empty()]);
 assert.notEqual(state.winner,null);assert.equal(state.winner,'draw');assert.ok(state.units.every(unit=>unit.hp===0));assert.ok(state.lastResolution.some(event=>event.cause==='collapse'));assert.deepEqual(restoreSimState(state),state);
});

test('invalid save identity, first-room health, geometry, libraries and chronology are rejected',()=>{
 for(const alter of [
  (s:SimState)=>{s.units[0].hp=1;},
  (s:SimState)=>{s.units[0].maxHp=99;},
  (s:SimState)=>{s.units[0].kind='creature';},
  (s:SimState)=>{s.units[0].q=0;s.units[0].r=0;},
  (s:SimState)=>{s.units[0].loadout.reverse();},
  (s:SimState)=>{s.learnedSignatures[0]=[getSignature('wa_bidi').id];},
  (s:SimState)=>{s.cells[0].height=s.cells[0].height===0?1:0;},
  (s:SimState)=>{s.winner=0;},
  (s:SimState)=>{s.version=2;},
  (s:SimState)=>{s.units.push({...s.units[0]});},
 ]){const state=createTowerBattle(room());alter(state);assert.throws(()=>restoreSimState(state));}
});

test('public-state AI plans remain legal for unequal squads and injured recruits',()=>{
 let state=createTowerBattle(room([champion('hero','oh_tipi',4),champion('friend','wa_bidi',3)],[creature('enemy')]));
 for(let step=0;step<3&&state.winner===null;step++){
  const plans=[chooseAIPlan(state,0),chooseAIPlan(state,1)];plans.forEach((plan,index)=>assert.deepEqual(validatePlan(state,index as 0|1,plan),plan));
  state=resolveRound(state,plans);assert.deepEqual(restoreSimState(state),state);
 }
});

