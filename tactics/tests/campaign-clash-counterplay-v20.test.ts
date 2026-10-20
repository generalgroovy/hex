import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chooseAIPlan,validatePlan,resolveRound,restoreSimState,distance,endgameForecast} from '../lib/tactics-v20.ts';
const fixture=()=>restoreSimState(JSON.parse(readFileSync(new URL('./fixtures/campaign-clash-loop-v20.json',import.meta.url),'utf8')).state);

test('a revealed hostile interception prompts a safe new firing angle and ends the observed opening loop',()=>{
 const state=fixture(),before=structuredClone(state),hero=state.units.find(unit=>unit.id==='0-hero')!,zone=endgameForecast(state);
 assert.equal(hero.hp,8);assert.equal(state.units.find(unit=>unit.id==='1-creature-1')!.hp,1);assert.ok(state.lastResolution.some(event=>event.kind==='clash'));
 const plans=[chooseAIPlan(state,0),chooseAIPlan(state,1)].map((plan,owner)=>validatePlan(state,owner as 0|1,plan));assert.deepEqual(state,before,'Planning must not mutate the public match');
 const action=plans[0].orders.find(order=>order.unitId===hero.id)!;assert.ok(action.move,'A safe side-step avoids another face-to-face interception');assert.ok(action.cast);assert.ok(distance(action.move,zone.centre)<=zone.safeRadius);assert.ok(distance(action.move,zone.centre)<=Math.max(zone.nextSafeRadius,distance(hero,zone.centre)));
 const next=resolveRound(state,plans);assert.equal(next.winner,0);assert.equal(next.units.find(unit=>unit.id===hero.id)!.hp,8);assert.ok(!next.lastResolution.some(event=>event.kind==='clash'));assert.deepEqual(restoreSimState(next),next);
});

test('the same history does not lure the safe centre defender beyond the upcoming boundary',()=>{
 const state=fixture(),defender=state.units.find(unit=>unit.id==='1-creature-1')!,plan=chooseAIPlan(state,1),action=plan.orders.find(order=>order.unitId===defender.id)!;
 assert.deepEqual({q:defender.q,r:defender.r},{q:0,r:0});assert.equal(endgameForecast(state).nextSafeRadius,0);assert.equal(action.move,undefined,'Breaking an interception is not worth abandoning the final safe hex');assert.doesNotThrow(()=>validatePlan(state,1,plan));
});

test('an absent public interception does not invent a need to flank',()=>{
 const state=fixture();state.lastResolution=[];const checked=restoreSimState(state),plan=chooseAIPlan(checked,0),action=plan.orders.find(order=>order.unitId==='0-hero')!;
 assert.equal(action.move,undefined);assert.ok(action.cast);assert.deepEqual(chooseAIPlan(checked,0),plan,'Identical public information produces identical plans');
});
