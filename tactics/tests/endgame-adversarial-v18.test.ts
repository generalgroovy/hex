import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,restoreSimState,validatePlan,legalMoves,type TeamPlan,type PlayerCount,type SimState} from '../lib/tactics-v18.ts';
import {endgameForecast,collapseDamageAt} from '../lib/endgame-v18.ts';
const guards=(count:number):TeamPlan[]=>Array.from({length:count},()=>({orders:[]}));
const alive=(state:SimState)=>state.units.filter(unit=>unit.hp>0);

test('all-Guard play from real initial maps ends by elimination, with every intermediate save restorable',()=>{
 for(const count of [2,3,4,5,6] as PlayerCount[])for(const seed of ['WELLSPRING','RIVERBEND']){
  let state=createSimGame({playerCount:count,seed}),rounds=0;const bound=endgameForecast(state).finalRound;
  while(state.winner===null&&rounds<bound){
   const before=structuredClone(state),plans=guards(count).map((plan,seat)=>validatePlan(state,seat as 0|1|2|3|4|5,plan)),next=resolveRound(state,plans);
   assert.deepEqual(state,before,'Resolving never mutates the authoritative input');assert.deepEqual(restoreSimState(next),next);
   assert.ok(next.lastResolution.filter(event=>event.cause==='collapse').every(event=>event.amount===collapseDamageAt(before,{q:event.q!,r:event.r!})));
   state=next;rounds++;
  }
  assert.notEqual(state.winner,null,`${count} players, ${seed} must end by ${bound}`);
  assert.equal(state.winner,'draw','Identical full-health starting camps wipe together while all Guard');
  assert.equal(alive(state).length,0,'The draw is actual simultaneous elimination, not a living-unit cutoff');
 }
});

test('maximum-healing upper bound cannot keep an outside camper alive through the final exchange',()=>{
 // Deliberately stronger than a real legal strategy: restore every living unit to full HP,
 // refill Flux, and grant Ward before each round. This is an adversarial mathematical
 // upper bound, not a recorded playable build or a balance simulation.
 for(const count of [2,3,4,5,6] as PlayerCount[]){
  let state=createSimGame({playerCount:count}),rounds=0;const bound=endgameForecast(state).finalRound;
  while(state.winner===null&&rounds<bound){
   for(const unit of alive(state)){unit.hp=unit.maxHp;unit.flux=unit.maxFlux;unit.statuses={ward:{turns:2,power:5}};}
   const next=resolveRound(state,guards(count));state=next;rounds++;
  }
  assert.equal(rounds,bound,'Unlimited full healing buys time only until the published final closure');
  assert.equal(state.winner,'draw');assert.equal(alive(state).length,0);
  assert.ok(state.lastResolution.filter(event=>event.cause==='collapse').every(event=>event.amount===8));
 }
});

test('boundary kiting and split allied camps cannot survive the final round outside centre',()=>{
 // A valid late-round fixture isolates movement and final-position hazards from earlier combat.
 // Eighteen full-health units move independently along the outer arena while Guarding.
 const state=createSimGame({playerCount:6,mode:'teams'});state.round=26;state.version=26;
 const plans=guards(6),reserved=new Set<string>();
 for(const unit of state.units){
  const target=legalMoves(state,unit.id).filter(point=>Math.max(Math.abs(point.q),Math.abs(point.r),Math.abs(point.q+point.r))>=7&&!reserved.has(`${point.q},${point.r}`)).at(-1)!;
  assert.ok(target);reserved.add(`${target.q},${target.r}`);
  plans[unit.owner].orders.push({unitId:unit.id,move:{q:target.q,r:target.r},guard:true});
 }
 plans.forEach((plan,seat)=>validatePlan(state,seat as 0|1|2|3|4|5,plan));
 const after=resolveRound(state,plans);
 assert.ok(after.lastResolution.some(event=>event.kind==='move'),'The fixture actually exercises movement');
 assert.equal(after.winner,'draw');assert.equal(alive(after).length,0);assert.equal(after.lastResolution.filter(event=>event.cause==='collapse').length,18);
 assert.deepEqual(restoreSimState(after),after);
});

test('final centre held by any one of six seats produces that surviving team, independent of seat index',()=>{
 for(let seat=0;seat<6;seat++){
  const state=createSimGame({playerCount:6,mode:'teams'});state.round=26;state.version=26;
  const holder=state.units.find(unit=>unit.owner===seat)!;Object.assign(holder,{q:0,r:0});
  const after=resolveRound(state,guards(6));
  assert.equal(after.winner,seat%2);assert.deepEqual(alive(after).map(unit=>unit.id),[holder.id]);
  assert.equal(after.lastResolution.filter(event=>event.kind==='defeat').length,17);
  assert.deepEqual(restoreSimState(after),after);
 }
});

