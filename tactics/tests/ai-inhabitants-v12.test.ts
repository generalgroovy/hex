import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,chooseAIPlan,resolveRound,validatePlan,spellArea,castAvailability,getSpell,getCell,distance,type SimState,type SimUnit,type TeamPlan,type Point} from '../lib/tactics-v12.ts';
import {storyInhabitants,inhabitantPulses} from '../lib/inhabitants-v12.ts';
import {validateLoadout} from '../lib/spells-v12.ts';

const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;
const at=(unit:SimUnit,point:Point)=>Object.assign(unit,{q:point.q,r:point.r});
const empty=():TeamPlan=>({orders:[]});
function fixture(){
  const state=createSimGame(undefined,'frontier:STORY-S-WAYNE');state.round=2;state.version=2;
  state.inhabitants=storyInhabitants(state.mapId,state.cells);
  const pulse=inhabitantPulses(state)[0];assert.equal(pulse.id,'inhabitant-1');
  const [caster,second,threatened]=state.units;
  for(const unit of [caster,second,threatened]){unit.statuses.rooted={turns:1,power:1};unit.flux=2;unit.loadout=validateLoadout(unit.championId,['ember','stone','gust','wither_bolt'],unit.affinities);}
  caster.loadout=validateLoadout(caster.championId,['water_jet','ember','stone','wither_bolt'],caster.affinities);
  at(threatened,pulse.area.at(-1)!);threatened.hp=1;
  const free=state.cells.filter(cell=>cell.biome==='plain'&&distance(cell,pulse.anchor)<=2&&!pulse.area.some(point=>same(point,cell))&&!state.units.some(unit=>same(unit,cell)));
  assert(free.length>=2);at(caster,free[0]);at(second,free[1]);
  assert.equal(castAvailability(state,caster.id,'water_jet').available,true);
  return {state,caster,second,threatened,pulse};
}
function counterOrders(state:SimState,plan:TeamPlan){const pulse=inhabitantPulses(state)[0];return plan.orders.filter(order=>order.cast&&order.spellId&&getSpell(order.spellId).element===pulse.counterElement&&spellArea(state,order.unitId,order.spellId,order.cast,order.move).some(cell=>same(cell,pulse.anchor)));}

test('AI pays for a legal counter at an empty perch to protect a rooted ally outside the spell footprint',()=>{
  const {state,caster,threatened,pulse}=fixture(),before=structuredClone(state);
  const plan=chooseAIPlan(state,0),counters=counterOrders(state,plan);
  assert.equal(counters.length,1);assert.equal(counters[0].unitId,caster.id);assert(same(counters[0].cast!,pulse.anchor));
  assert.equal(spellArea(state,caster.id,counters[0].spellId!,counters[0].cast!).some(cell=>same(cell,threatened)),false);
  assert.deepEqual(validatePlan(state,0,plan),plan);assert.deepEqual(state,before);
  const cost=castAvailability(state,caster.id,counters[0].spellId!).cost,result=resolveRound(state,[plan,empty()]);
  assert.equal(result.units.find(unit=>unit.id===threatened.id)!.hp,1);
  assert.equal(result.units.find(unit=>unit.id===caster.id)!.flux,caster.flux-cost+2);
  assert(result.lastResolution.some(event=>event.kind==='inhabitant'&&event.interrupted));
  assert.equal(getCell(result,pulse.anchor.q,pulse.anchor.r)!.terrain,'water','the paid counter contributes its own element after suppressing Fire');
});

test('AI does not spend Flux interrupting an announced pulse that threatens none of its projected units',()=>{
  const {state,threatened,pulse}=fixture();
  const safe=state.cells.find(cell=>cell.biome==='plain'&&!pulse.area.some(point=>same(point,cell))&&!state.units.some(unit=>same(unit,cell))&&distance(cell,pulse.anchor)<=3)!;
  at(threatened,safe);threatened.hp=8;
  const plan=chooseAIPlan(state,0);assert.equal(counterOrders(state,plan).length,0);
});

test('AI counter valuation cannot bypass insufficient Flux or friendly-fire avoidance',()=>{
  const scarce=fixture();scarce.caster.flux=0;
  assert.equal(counterOrders(scarce.state,chooseAIPlan(scarce.state,0)).length,0,'an unaffordable counter is not a legal option');
  const occupied=fixture();at(occupied.threatened,occupied.pulse.anchor);
  assert.equal(counterOrders(occupied.state,chooseAIPlan(occupied.state,0)).length,0,'a damaging counter must not target a vulnerable ally on the perch');
});

test('once an earlier ally counter is planned, another caster does not receive the same interruption reward',()=>{
  const {state,second}=fixture();second.flux=3;
  second.loadout=validateLoadout(second.championId,['water_jet','ember','stone','wither_bolt'],second.affinities);
  assert.equal(castAvailability(state,second.id,'water_jet').available,true);
  const plan=chooseAIPlan(state,0);assert.equal(counterOrders(state,plan).length,1);
});
