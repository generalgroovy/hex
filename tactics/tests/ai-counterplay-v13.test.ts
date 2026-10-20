import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,chooseAIPlan,resolveRound,validatePlan,spellArea,castAvailability,getSpell,getCell,distance,type SimState,type TeamPlan,type Point} from '../lib/tactics-v13.ts';
import {storyInhabitants,inhabitantPulses} from '../lib/inhabitants-v13.ts';
import {validateLoadout} from '../lib/spells-v13.ts';

const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;
const empty=():TeamPlan=>({orders:[]});
function fixture(){
 const state=createSimGame(undefined,'frontier:STORY-S-WAYNE');state.round=2;state.version=2;
 state.inhabitants=storyInhabitants(state.mapId,state.cells);
 const pulse=inhabitantPulses(state)[0];assert.equal(pulse.id,'inhabitant-1');
 const [caster,second,threatened]=state.units;
 for(const unit of [caster,second,threatened]){unit.statuses.rooted={turns:1,power:1};unit.flux=0;}
 caster.flux=2;caster.loadout=validateLoadout(caster.championId,['water_jet','ember','frostbite','cleansing_tide'],caster.affinities);
 caster.cooldowns.frostbite=1;caster.cooldowns.cleansing_tide=1;
 Object.assign(threatened,pulse.area.at(-1));threatened.hp=1;
 const free=state.cells.filter(cell=>cell.biome==='plain'&&distance(cell,pulse.anchor)<=2&&!pulse.area.some(point=>same(point,cell))&&!state.units.some(unit=>same(unit,cell)));
 assert(free.length>=2);Object.assign(caster,{q:free[0].q,r:free[0].r});Object.assign(second,{q:free[1].q,r:free[1].r});
 assert.equal(castAvailability(state,caster.id,'water_jet').available,true);
 return {state,caster,second,threatened,pulse};
}
function counters(state:SimState,plan:TeamPlan){
 const pulse=inhabitantPulses(state)[0];
 return plan.orders.filter(order=>order.cast&&order.spellId&&getSpell(order.spellId).element===pulse.counterElement&&spellArea(state,order.unitId,order.spellId,order.cast,order.move).some(cell=>same(cell,pulse.anchor)));
}

test('native water caster pays for an empty-perch counter to save a threatened ally',()=>{
 const {state,caster,threatened,pulse}=fixture(),before=structuredClone(state),plan=chooseAIPlan(state,0),chosen=counters(state,plan);
 assert.equal(chosen.length,1);assert.equal(chosen[0].unitId,caster.id);assert(same(chosen[0].cast!,pulse.anchor));
 assert.equal(spellArea(state,caster.id,chosen[0].spellId!,chosen[0].cast!).some(cell=>same(cell,threatened)),false);
 assert.deepEqual(validatePlan(state,0,plan),plan);assert.deepEqual(state,before);
 const cost=castAvailability(state,caster.id,chosen[0].spellId!).cost,next=resolveRound(state,[plan,empty()]);
 assert.equal(next.units.find(unit=>unit.id===threatened.id)!.hp,1);
 assert.equal(next.units.find(unit=>unit.id===caster.id)!.flux,caster.flux-cost+2);
 assert(next.lastResolution.some(event=>event.kind==='inhabitant'&&event.interrupted));
 assert.equal(getCell(next,pulse.anchor.q,pulse.anchor.r)!.terrain,'water');
});

test('public counterplay neither invents a threat nor bypasses Flux and friendly-fire constraints',()=>{
 const safe=fixture();
 const landing=safe.state.cells.find(cell=>cell.biome==='plain'&&!safe.pulse.area.some(point=>same(point,cell))&&!safe.state.units.some(unit=>same(unit,cell))&&distance(cell,safe.pulse.anchor)<=3)!;
 Object.assign(safe.threatened,{q:landing.q,r:landing.r});safe.threatened.hp=8;
 assert.equal(counters(safe.state,chooseAIPlan(safe.state,0)).length,0);
 const scarce=fixture();scarce.caster.flux=0;assert.equal(counters(scarce.state,chooseAIPlan(scarce.state,0)).length,0);
 const blocked=fixture();Object.assign(blocked.threatened,blocked.pulse.anchor);
 assert.equal(counters(blocked.state,chooseAIPlan(blocked.state,0)).filter(order=>getSpell(order.spellId!).damage>0).length,0,'do not counter by damaging the fragile ally');
});

test('an earned third-element counter is legal, but the same release is not rewarded twice',()=>{
 const {state,second}=fixture();second.affinities={fire:3,air:2,water:1};second.flux=3;
 second.loadout=validateLoadout(second.championId,['water_jet','ember','gust','cauterize'],second.affinities);
 assert.equal(castAvailability(state,second.id,'water_jet').available,true);
 assert.equal(counters(state,chooseAIPlan(state,0)).length,1);
});
