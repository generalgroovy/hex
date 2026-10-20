import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,type TeamPlan} from '../lib/tactics-v16.ts';
import {analyzePlan} from '../lib/plan-insights-v16.ts';
import {planningForecast} from '../lib/planning-forecast-v16.ts';

function crossing(distance=2){
 const state=createSimGame();state.cells=state.cells.map(({q,r})=>({q,r,biome:'plain',terrain:'plain',height:0,well:false}));
 const water=state.units[0],fire=state.units[1];
 Object.assign(water,{q:-distance,r:0});Object.assign(fire,{q:distance,r:0});
 const plan:TeamPlan={orders:[{unitId:water.id,spellId:'water_jet',cast:{q:distance,r:0}},{unitId:fire.id,spellId:'ember',cast:{q:-distance,r:0}}]};
 return {state,water,fire,plan};
}

test('orders warnings and the selected forecast both remove consumed original friendly-fire footprints',()=>{
 const {state,water,plan}=crossing();
 assert.equal(planningForecast(state,0,plan,water.id)!.clashes.length,1);
 assert.deepEqual(analyzePlan(state,0,plan),[]);
 const after=resolveRound(state,[plan,{orders:[]}]);
 assert.ok(after.units.every((unit,index)=>unit.hp===state.units[index].hp));
});

test('an unintercepted hostile spell still warns about its actual allied target',()=>{
 const {state,fire,plan}=crossing(),single={orders:[plan.orders[0]]};
 const warnings=analyzePlan(state,0,single);
 assert.equal(warnings.length,1);assert.equal(warnings[0].kind,'ally-exposure');
 assert.ok(warnings[0].unitIds.includes(fire.id));assert.match(warnings[0].text,/Water Jet may hit Wa Bidi/);
 const after=resolveRound(state,[single,{orders:[]}]);assert.ok(after.units[1].hp<fire.hp);
});

test('a hazardous neutral collision field warns once about allies inside its real footprint',()=>{
 const {state,water,fire,plan}=crossing(1);plan.orders[0].spellId='ember';
 const warnings=analyzePlan(state,0,plan);
 assert.equal(warnings.length,1);assert.equal(warnings[0].kind,'field-exposure');
 assert.match(warnings[0].text,/neutral field/);assert.match(warnings[0].text,/Oh Tipi would stand in Fire/);assert.match(warnings[0].text,/Wa Bidi would stand in Fire/);
 assert.ok(warnings[0].unitIds.includes(water.id)&&warnings[0].unitIds.includes(fire.id));
 const after=resolveRound(state,[plan,{orders:[]}]);assert.equal(after.units[0].hp,water.hp-1);assert.equal(after.units[1].hp,fire.hp-1);
});

test('rival order objects cannot alter own-team advice or expose a hidden plan',()=>{
 const {state,plan}=crossing();
 const mixed={orders:[...plan.orders,{unitId:state.units[3].id,spellId:'water_jet',cast:{q:0,r:0}}]};
 assert.deepEqual(analyzePlan(state,0,mixed),analyzePlan(state,0,plan));
});

test('known blocked allied moves use their actual release positions for interception advice',()=>{
 const {state,plan}=crossing();for(const order of plan.orders)order.move={q:0,r:0};
 const warnings=analyzePlan(state,0,plan);
 assert.ok(warnings.some(warning=>warning.kind==='ally-collision'));
 assert.ok(!warnings.some(warning=>warning.kind==='ally-exposure'));
 const after=resolveRound(state,[plan,{orders:[]}]);assert.deepEqual(after.lastResolution.find(event=>event.kind==='clash')!.meeting,{q:0,r:0});
});
