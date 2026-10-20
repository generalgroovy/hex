import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createSimGame,chooseAIPlan,resolveRound,restoreSimState,validatePlan,type SimState,type Player,type TeamPlan} from '../lib/tactics-v18.ts';

test('replayable public collision responses break the preserved two-company final-centre retry loop',()=>{
  const fixture=JSON.parse(readFileSync(new URL('./fixtures/endgame-centre-collision-v18.json',import.meta.url),'utf8')) as {state:SimState;oldPlans25:TeamPlan[];oldPlans26:TeamPlan[]};
  const state=restoreSimState(fixture.state),oldResult=resolveRound(resolveRound(state,fixture.oldPlans25),fixture.oldPlans26);
  assert.equal(oldResult.winner,'draw');assert.equal(oldResult.units.filter(unit=>unit.hp>0).length,0);
  const plan=()=>Array.from({length:6},(_,seat)=>validatePlan(state,seat as Player,chooseAIPlan(state,seat as Player)));
  const plans=plan();assert.deepEqual(plan(),plans);
  const next=resolveRound(state,plans);restoreSimState(next);
  assert.equal(next.lastResolution.filter(event=>event.kind==='bounce').length,0);
  assert.equal(next.units.filter(unit=>unit.hp>0&&unit.q===0&&unit.r===0).length,1);
  const result=resolveRound(next,Array.from({length:6},(_,seat)=>chooseAIPlan(next,seat as Player)));restoreSimState(result);
  assert.notEqual(result.winner,null);assert.notEqual(result.winner,'draw');assert.equal(result.units.filter(unit=>unit.hp>0).length,1);
});

test('allied bot seats nominate one reachable centre contender from public state before the final closure',()=>{
  const state=createSimGame({playerCount:6,mode:'teams'});state.round=25;state.version=25;
  state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',height:0,biome:'plain'}));
  const positions=[{q:-1,r:0},{q:0,r:-1},{q:1,r:-1}];
  for(const [index,seat] of ([0,2,4] as Player[]).entries()){
    const unit=state.units.find(unit=>unit.owner===seat)!;Object.assign(unit,positions[index],{hp:8-index});
    for(const ally of state.units.filter(other=>other.owner===seat&&other.id!==unit.id)){ally.hp=0;ally.flux=0;ally.statuses={};ally.cooldowns={};}
  }
  const plans=([0,2,4] as Player[]).map(seat=>chooseAIPlan(state,seat));
  const claims=plans.flatMap(plan=>plan.orders).filter(order=>order.move?.q===0&&order.move.r===0);
  assert.equal(claims.length,1);assert.equal(claims[0].unitId,state.units.find(unit=>unit.owner===0)!.id);
});
