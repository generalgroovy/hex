import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ALL_SPELLS, CHAMPIONS, SPELLS, MAX_ROUNDS, chooseAIPlan, createSimGame,
  castAvailability, legalCasts, resolveRound, restoreSimState, validatePlan,
  type TeamPlan,
} from '../lib/tactics-v9.ts';
import {spellAccess,validateLoadout} from '../lib/spells-v9.ts';
import {affinityBudget,validateAffinityAllocation} from '../lib/roster-v9.ts';
import {createSimGame as createV8,restoreSimState as restoreV8,resolveRound as resolveV8} from '../lib/tactics-v8.ts';

const empty=():TeamPlan=>({orders:[]});
const wire=<T>(value:T):T=>JSON.parse(JSON.stringify(value));

test('every level-two through level-six spell rejects every lower affinity boundary in forged plans and saves',()=>{
  const gated=SPELLS.filter(spell=>spell.level>1);
  assert.equal(gated.length,36);
  for(const spell of gated)for(let points=0;points<spell.level;points++){
    const champion=CHAMPIONS.find(entry=>(entry.affinities[spell.element]??0)===Math.min(3,points));
    assert.ok(champion,`${spell.element} has a ${points}-point boundary case`);
    const others=CHAMPIONS.filter(entry=>entry.id!==champion.id).slice(0,2).map(entry=>entry.id);
    const state=createSimGame([[champion.id,...others],['oh_tipi','s_wayne','treevor_mason']]);
    const unit=state.units[0];
    const earned=Math.max(0,points-(champion.affinities[spell.element]??0));
    state.round=1+2*earned;state.version=state.round;
    if(points)unit.affinities={...unit.affinities,[spell.element]:points};
    assert.deepEqual(validateAffinityAllocation(unit.affinities,affinityBudget(state.round)),unit.affinities);
    unit.loadout=[spell.id,...['ember','water_jet','stone','mend'].filter(id=>id!==spell.id).slice(0,3)];
    const input=wire(state);
    assert.equal(castAvailability(state,unit.id,spell.id).available,false,`${champion.name} cannot cast ${spell.name}`);
    assert.deepEqual(legalCasts(state,unit.id,undefined,spell.id),[]);
    assert.throws(()=>validatePlan(state,0,{orders:[{unitId:unit.id,spellId:spell.id,cast:{q:unit.q,r:unit.r}}]}));
    assert.throws(()=>restoreSimState(input),/affinity|requires|unlock/i);
    assert.deepEqual(state,input,'validation never repairs a forged live match in place');
  }
});

test('every unlocked V9 catalogue action resolves and survives strict restore on actual seeded terrain',()=>{
  for(const spell of ALL_SPELLS){
    const champion=spell.signatureChampionId??CHAMPIONS.find(entry=>entry.element===spell.element)!.id;
    const others=CHAMPIONS.filter(entry=>entry.id!==champion).slice(0,2).map(entry=>entry.id);
    const state=createSimGame([[champion,...others],['oh_tipi','s_wayne','treevor_mason']],'frontier:AFFINITY-RESTORE');
    const unit=state.units[0];
    if(!spell.signatureChampionId){
      const earned=Math.max(0,spell.level-(unit.affinities[spell.element]??0));
      state.round=1+2*earned;state.version=state.round;
      unit.affinities={...unit.affinities,[spell.element]:Math.max(spell.level,unit.affinities[spell.element]??0)};
      validateAffinityAllocation(unit.affinities,affinityBudget(state.round));
      unit.loadout=validateLoadout(champion,[spell.id,...SPELLS.filter(entry=>entry.id!==spell.id&&spellAccess(champion,entry.id,unit.affinities).unlocked).slice(0,3).map(entry=>entry.id)],unit.affinities);
    }
    assert.deepEqual(restoreSimState(wire(state)),state,`${spell.id}: setup itself is a legal earned allocation`);
    const targets=legalCasts(state,unit.id,undefined,spell.id);
    const target=targets.find(cell=>cell.terrain!=='plain')??targets[0];
    assert.ok(target,`${spell.id} has a legal opening footprint`);
    const before=wire(state);
    const plan={orders:[{unitId:unit.id,spellId:spell.id,cast:{q:target.q,r:target.r}}]};
    const next=resolveRound(state,[plan,empty()]);
    assert.deepEqual(state,before,`${spell.id} preserves replay source`);
    assert.ok(next.lastResolution.some(event=>event.kind==='cast'&&event.spellId===spell.id),spell.id);
    assert.deepEqual(restoreSimState(wire(next)),next,`${spell.id} survives JSON and strict restore`);
    const expired=resolveRound(next,[empty(),empty()]);
    assert.deepEqual(restoreSimState(wire(expired)),expired,`${spell.id} also restores after field expiry`);
  }
});

test('V8 saves keep their original legal loadouts and cannot be silently relabelled as V9',()=>{
  const original=createV8();
  const treevor=original.units.find(unit=>unit.championId==='treevor_mason')!;
  treevor.loadout=['frostbite','ember','mend','gust'];
  const serialized=wire(original);
  assert.deepEqual(restoreV8(serialized),original,'the previous rules still allow a cross-affinity Frostbite kit');
  const plan={orders:[{unitId:treevor.id,spellId:'frostbite',cast:{q:treevor.q,r:treevor.r}}]};
  const continued=resolveV8(original,[plan,empty()]);
  assert.ok(continued.lastResolution.some(event=>event.kind==='cast'&&event.spellId==='frostbite'));
  assert.deepEqual(restoreV8(wire(continued)),continued);
  assert.throws(()=>restoreSimState(serialized),/unsupported/i,'new rules must not reinterpret an unfinished V8 match');
  assert.throws(()=>restoreSimState({...serialized,rulesVersion:9}),/affinity|requires|unlock/i,'changing only the version cannot bypass new affinity validation');
  assert.deepEqual(original,serialized);
});

test('Lightning pierces existing Ward, rewards earlier Wet, and cannot claim Wet applied simultaneously',()=>{
  function exchange(wet:boolean,incomingWater=false,guard=false){
    const state=createSimGame();
    state.cells.forEach(cell=>Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false}));
    const caster=state.units[1],water=state.units[0],defender=state.units[3];
    state.round=3;state.version=3;caster.affinities={...caster.affinities,fire:4};
    validateAffinityAllocation(caster.affinities,affinityBudget(state.round));
    Object.assign(caster,{q:0,r:0,loadout:['fire_lance','ember','water_jet','mend']});
    Object.assign(water,{q:-1,r:1,loadout:['water_jet','ember','mend','gust']});
    Object.assign(defender,{q:1,r:0,loadout:['ember','water_jet','mend','gust'],statuses:{ward:{turns:1,power:3},...(wet?{wet:{turns:2,power:1}}:{})}});
    const orders:TeamPlan['orders']=[{unitId:caster.id,spellId:'fire_lance',cast:{q:1,r:0}}];
    if(incomingWater)orders.push({unitId:water.id,spellId:'water_jet',cast:{q:1,r:0}});
    // Casting into an empty hex keeps the defender from auto-Guarding, without
    // adding a second element or a heal to its own hex.
    const enemy:TeamPlan=guard?empty():{orders:[{unitId:defender.id,spellId:'mend',cast:{q:1,r:-1}}]};
    const next=resolveRound(state,[{orders},enemy]);
    return {next,defender:next.units.find(unit=>unit.id===defender.id)!,spellDamage:next.lastResolution.filter(event=>event.kind==='damage'&&event.unitId===defender.id).reduce((sum,event)=>sum+(event.amount??0),0)};
  }
  const dry=exchange(false),alreadyWet=exchange(true),newWet=exchange(false,true),guarded=exchange(true,false,true);
  assert.equal(dry.spellDamage,1,'piercing damage bypasses Ward 3');
  assert.equal(alreadyWet.spellDamage,2,'existing Wet earns the explicit one-damage bonus');
  assert.equal(guarded.spellDamage,1,'Guard still absorbs one piercing spell damage');
  assert.equal(newWet.spellDamage,0,'new Wet gives no bonus: Steam leaves ordinary damage that existing Ward absorbs');
  assert.ok(newWet.defender.statuses.wet,'the simultaneous Water spell still applies Wet for future rounds');
  assert.equal(dry.next.cells.find(cell=>cell.q===1&&cell.r===0)!.terrain,'fire','Lightning retains Fire chemistry');
  assert.equal(newWet.next.cells.find(cell=>cell.q===1&&cell.r===0)!.terrain,'steam','Lightning and Water still form Steam');
});

test('three complete seeded V9 matches replay deterministically with valid loadouts and restorable rounds',()=>{
  for(const seed of ['WELLSPRING','SIX-LEVELS','RIVER-42']){
    let state=createSimGame(undefined,`frontier:${seed}`),resolutions=0;
    while(state.winner===null&&resolutions<MAX_ROUNDS){
      for(const unit of state.units){assert.deepEqual(validateLoadout(unit.championId,unit.loadout,unit.affinities),unit.loadout);validateAffinityAllocation(unit.affinities,affinityBudget(state.round))}
      const plans:[TeamPlan,TeamPlan]=[chooseAIPlan(state,0),chooseAIPlan(state,1)];
      const before=wire(state),next=resolveRound(state,plans);
      assert.deepEqual(state,before,seed);
      assert.deepEqual(resolveRound(restoreSimState(before),wire(plans)),next,`${seed}, round ${state.round}`);
      assert.deepEqual(restoreSimState(wire(next)),next,`${seed}: strict round restore`);
      state=next;resolutions++;
    }
    assert.notEqual(state.winner,null,`${seed}: match ends within the round cap`);
  }
});
