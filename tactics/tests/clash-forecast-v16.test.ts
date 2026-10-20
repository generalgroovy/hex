import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v16.ts';
import {planningForecast} from '../lib/planning-forecast-v16.ts';
import {combatOutlook} from '../lib/combat-outlook-v16.ts';
import {projectedVolley} from '../lib/planned-volley-v16.ts';
import {resolutionReadout,characterPhaseAction} from '../lib/resolution-readout-v16.ts';
import {visibleFieldForecast} from '../lib/living-world-v16.ts';

function setup(){
 const state=createSimGame();
 state.cells=state.cells.map(({q,r})=>({q,r,biome:'plain',terrain:'plain',height:0,well:false}));
 const left=state.units[0],right=state.units[1];
 Object.assign(left,{q:-2,r:0});Object.assign(right,{q:2,r:0});
 const plan:TeamPlan={orders:[{unitId:left.id,spellId:'water_jet',cast:{q:2,r:0}},{unitId:right.id,spellId:'ember',cast:{q:-2,r:0}}]};
 return {state,left,right,plan};
}
test('the own-plan forecast paints the interception field and removes consumed original target damage',()=>{
 const {state,left,right,plan}=setup();
 const forecast=planningForecast(state,0,plan,left.id)!;
 assert.equal(forecast.clashes.length,1);assert.equal(forecast.cells.length,7);
 assert.deepEqual(forecast.groups.map(group=>group.id),['steam']);
 assert.deepEqual(forecast.clashes[0].meeting,{q:0,r:0});
 assert.ok(forecast.cells.every(cell=>Math.abs(cell.q)<=1));
 assert.deepEqual(combatOutlook(state,0,plan,left.id,'water_jet',plan.orders[0].cast!),[]);
 assert.deepEqual(combatOutlook(state,0,plan,right.id,'ember',plan.orders[1].cast!),[]);
 const after=resolveRound(state,[plan,{orders:[]}]);
 for(const cell of forecast.cells)assert.equal(after.cells.find(c=>c.q===cell.q&&c.r===cell.r)!.terrain,cell.field);
});
test('crossings are recomputed after a candidate changes and never read a rival order',()=>{
 const {state,left,plan}=setup();
 const input={orders:[...plan.orders,{unitId:state.units[3].id,spellId:'water_jet',cast:{q:0,r:0}}]};
 assert.deepEqual(planningForecast(state,0,input,left.id),planningForecast(state,0,plan,left.id));
 const changed=planningForecast(state,0,plan,left.id,'water_jet',{q:0,r:1})!;
 assert.deepEqual(changed.clashes,[]);assert.equal(changed.cells.length,1);
});
test('a known allied movement collision uses actual release positions, not unreachable intended landings',()=>{
 const {state,left,right}=setup();
 const input:TeamPlan={orders:[{unitId:left.id,move:{q:0,r:0},spellId:'water_jet',cast:{q:2,r:0}},{unitId:right.id,move:{q:0,r:0},spellId:'ember',cast:{q:-2,r:0}}]};
 const plan=validatePlan(state,0,input),volley=projectedVolley(state,0,plan);
 assert.deepEqual(volley.positions.get(left.id),{q:-2,r:0});assert.deepEqual(volley.positions.get(right.id),{q:2,r:0});
 assert.equal(volley.clashes.length,1);
 const resolved=resolveRound(state,[plan,{orders:[]}]);
 assert.deepEqual(resolved.lastResolution.find(event=>event.kind==='clash')!.meeting,volley.clashes[0].meeting);
});
test('character review explains an interception without announcing its result during movement or launch',()=>{
 const {state,left,plan}=setup(),after=resolveRound(state,[plan,{orders:[]}]);
 const character=resolutionReadout(state,after)!.characters.find(unit=>unit.id===left.id)!;
 assert.doesNotMatch(characterPhaseAction(character,'move').label,/flight|Steam/i);
 assert.doesNotMatch(characterPhaseAction(character,'cast').label,/flight|Steam/i);
 assert.match(characterPhaseAction(character,'impact').label,/Met in flight.*Steam/);
 assert.match(characterPhaseAction(character,'settle').label,/Water Jet.*met in flight/);
 assert.ok(character.details.some(detail=>/Steam/.test(detail)));
});
test('intercepted Ice retains its freeze while a neutral field cannot interrupt a creature release',()=>{
 const state=createSimGame([['oh_tipi','leaf_hidden','treevor_mason'],['s_wayne','haara','wa_bidi']]);
 state.cells=state.cells.map(({q,r})=>({q,r,biome:'plain',terrain:'plain',height:0,well:false}));
 Object.assign(state.units[0],{q:-2,r:0,loadout:['frostbite','tidal_surge','ember','cleansing_tide']});
 Object.assign(state.units[1],{q:2,r:0});
 state.units[1].loadout[0]='water_jet';
 const plan:TeamPlan={orders:[{unitId:state.units[0].id,spellId:'frostbite',cast:{q:2,r:0}},{unitId:state.units[1].id,spellId:'water_jet',cast:{q:-2,r:0}}]};
 const forecast=planningForecast(state,0,plan,state.units[0].id)!;
 assert.deepEqual(forecast.groups.map(group=>group.id),['water:ice']);
 assert.ok(forecast.cells.every(cell=>cell.ice));
 const after=resolveRound(state,[plan,{orders:[]}]);
 assert.ok(forecast.cells.every(cell=>after.cells.find(c=>c.q===cell.q&&c.r===cell.r)!.ice));
 const cell=state.cells.find(c=>c.q===0&&c.r===0)!;
 const intent={id:'inhabitant-2',name:'Puddle',phase:'pulse' as const,area:[cell],elements:['water' as const],counterElement:'earth' as const,anchor:cell,tell:'Water release'};
 const contribution={element:'earth' as const,area:[cell]};
 assert.equal(visibleFieldForecast(cell,[contribution],[intent]).terrain,'earth');
 assert.equal(visibleFieldForecast(cell,[{...contribution,canCounter:false}],[intent]).terrain,'quagmire');
});
