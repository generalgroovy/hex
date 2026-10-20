import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,previewField,resolveRound,spellArea,type SimState,type TeamPlan} from '../lib/tactics-v13.ts';
import {planningForecast} from '../lib/planning-forecast-v13.ts';

const oh='0-oh_tipi',wa='0-wa_bidi',tree='0-treevor_mason';
const point={q:0,r:0};
function arena():SimState{
  const state=createSimGame();
  state.cells=state.cells.map(({q,r})=>({q,r,biome:'plain',terrain:'plain',height:0,well:false}));
  Object.assign(state.units.find(u=>u.id===oh)!,{q:-2,r:0});
  Object.assign(state.units.find(u=>u.id===wa)!,{q:-2,r:1});
  Object.assign(state.units.find(u=>u.id===tree)!,{q:-2,r:2});
  return state;
}
const cell=(state:SimState,q=0,r=0)=>state.cells.find(c=>c.q===q&&c.r===r)!;
const plan=(...orders:TeamPlan['orders']):TeamPlan=>({orders});

test('one footprint distinguishes exact resulting materials on natural ground',()=>{
  const state=arena(),unit=state.units.find(u=>u.id===oh)!;
  unit.loadout[1]='tidal_surge';
  const area=spellArea(state,oh,'tidal_surge',point);
  assert.ok(area.length>=3);
  Object.assign(area[0],{biome:'water',terrain:'water'});
  Object.assign(area[1],{biome:'forest',terrain:'earth'});
  Object.assign(area[2],{biome:'earth',terrain:'earth',height:1});
  const forecast=planningForecast(state,0,plan(),oh,'tidal_surge',point)!;
  assert.ok(forecast);
  assert.equal(forecast.cells.length,area.length);
  assert.ok(forecast.groups.some(g=>g.id==='water'&&g.shortRule.includes('costs 2 movement')));
  assert.ok(forecast.groups.some(g=>g.id==='quagmire'&&g.shortRule.includes('Wet')));
  assert.equal(forecast.groups.reduce((n,g)=>n+g.count,0),area.length);
});

test('queued cast persists, candidate replaces it, and allies combine into exactly one field',()=>{
  const state=arena(),orders=plan({unitId:oh,spellId:'water_jet',cast:point},{unitId:wa,spellId:'ember',cast:point});
  const queued=planningForecast(state,0,orders,wa)!;
  assert.deepEqual(queued.groups.map(g=>g.id),['steam']);
  assert.match(queued.groups[0].shortRule,/Halves spell damage/);
  const replacement=planningForecast(state,0,orders,wa,'gust',point)!;
  assert.deepEqual(replacement.groups.map(g=>g.id),['hailcurrent:ice']);
  assert.deepEqual(replacement.groups[0].elements,['water','air']);
  assert.equal(planningForecast(state,0,plan(),wa),null);
  assert.equal(planningForecast(state,0,orders,wa,'gust')!.spellId,'ember');
});

test('three and six ingredient fields replace all contained pairs',()=>{
  const state=arena();
  Object.assign(cell(state),{biome:'earth',terrain:'earth'});
  const orders=plan({unitId:oh,spellId:'water_jet',cast:point},{unitId:wa,spellId:'ember',cast:point});
  assert.deepEqual(planningForecast(state,0,orders,wa)!.groups.map(g=>g.id),['hot_spring']);
  Object.assign(cell(state),previewField(cell(state),['air','light','dark']));
  const complete=planningForecast(state,0,orders,wa)!;
  assert.equal(complete.groups.length,1);
  assert.equal(complete.groups[0].elements.length,6);
  assert.equal(complete.groups[0].id,'worldseed');
});

test('deliberately frozen Water is Ice; a later ingredient thaws it into its own mixture',()=>{
  const state=arena(),unit=state.units.find(u=>u.id===oh)!;
  unit.loadout[1]='frostbite';
  const orders=plan({unitId:oh,spellId:'frostbite',cast:point});
  const frozen=planningForecast(state,0,orders,oh)!;
  assert.equal(frozen.groups[0].id,'water:ice');
  assert.equal(frozen.groups[0].name,'Ice');
  assert.match(frozen.groups[0].shortRule,/slides/);
  assert.doesNotMatch(frozen.groups[0].shortRule,/costs 2/);
  orders.orders.push({unitId:wa,spellId:'ember',cast:point});
  assert.equal(planningForecast(state,0,orders,oh)!.groups[0].id,'steam');
});

test('public creature pulse participates until an allied counter hits its perch',()=>{
  const state=arena();state.inhabitants=[{speciesId:'inhabitant-2',...point}];
  const orders=plan({unitId:wa,spellId:'ember',cast:point});
  assert.equal(planningForecast(state,0,orders,wa)!.groups[0].id,'steam');
  orders.orders.push({unitId:tree,spellId:'stone',cast:point});
  assert.equal(planningForecast(state,0,orders,wa)!.groups[0].id,'magma');
  state.round=2;
  assert.equal(planningForecast(state,0,plan({unitId:wa,spellId:'ember',cast:point}),wa)!.groups[0].id,'fire');
});

test('allied exposure uses planned landings and excludes helpful spells',()=>{
  const state=arena(),orders=plan({unitId:oh,move:point,guard:true},{unitId:wa,spellId:'ember',cast:point});
  assert.deepEqual(planningForecast(state,0,orders,wa)!.allies.map(u=>u.id),[oh]);
  assert.deepEqual(planningForecast(state,0,orders,oh,'cleansing_tide',point)!.allies,[]);
  assert.deepEqual(planningForecast(state,0,plan({unitId:wa,spellId:'ember',cast:point}),wa)!.allies,[]);
});

test('known allied collisions exclude guaranteed fizzles but retain valid casts after a bounce',()=>{
  const state=arena();Object.assign(state.units.find(u=>u.id===wa)!,{q:-4,r:1});
  const target={q:2,r:0},orders=plan({unitId:oh,move:point,spellId:'water_jet',cast:target},{unitId:wa,move:point,spellId:'ember',cast:target});
  assert.equal(planningForecast(state,0,orders,wa)!.blocked,true);
  assert.deepEqual(planningForecast(state,0,orders,wa)!.cells,[]);
  const water=planningForecast(state,0,orders,oh)!;
  assert.equal(water.blocked,false);
  assert.deepEqual(water.groups.map(g=>g.id),['water']);
  const resolved=resolveRound(state,[orders,plan()]);
  assert.ok(resolved.lastResolution.some(event=>event.kind==='fizzle'&&event.unitId===wa));
  assert.equal(cell(resolved,2,0).terrain,'water');
});

test('a surviving directional spell uses its actual origin after a known allied bounce',()=>{
  const state=arena(),unit=state.units.find(u=>u.id===oh)!;unit.loadout[1]='tidal_surge';
  const landing={q:0,r:-1},orders=plan({unitId:oh,move:landing,spellId:'tidal_surge',cast:point},{unitId:wa,move:landing,guard:true});
  const coordinates=(cells:{q:number;r:number}[])=>cells.map(c=>`${c.q},${c.r}`).sort();
  const actual=coordinates(spellArea(state,oh,'tidal_surge',point,unit));
  const intended=coordinates(spellArea(state,oh,'tidal_surge',point,landing));
  assert.notDeepEqual(actual,intended);
  const forecast=planningForecast(state,0,orders,oh)!;
  assert.equal(forecast.blocked,false);
  assert.deepEqual(coordinates(forecast.cells),actual);
  const resolved=resolveRound(state,[orders,plan()]);
  assert.deepEqual(coordinates(resolved.cells.filter(c=>c.ttl!==undefined)),actual);
});

test('forecast ignores rival orders, never mutates inputs, and rejects unavailable casts',()=>{
  const state=arena(),orders=plan({unitId:wa,spellId:'ember',cast:point});
  const before=structuredClone({state,orders}),expected=planningForecast(state,0,orders,wa);
  const mixed=plan(...orders.orders,{unitId:'1-oh_tipi',spellId:'water_jet',cast:point});
  assert.deepEqual(planningForecast(state,0,mixed,wa),expected);
  assert.deepEqual({state,orders},before);
  assert.equal(planningForecast(state,0,orders,wa,'rainfall',point),null);
  assert.equal(planningForecast(state,0,orders,'1-oh_tipi','water_jet',point),null);
});

test('refreshing the same field is distinguished from creating a new material',()=>{
  const state=arena();Object.assign(cell(state),previewField(cell(state),['fire','water']));
  const orders=plan({unitId:wa,spellId:'ember',cast:point});
  assert.equal(planningForecast(state,0,orders,wa)!.cells[0].changed,false);
  const changed=planningForecast(state,0,orders,wa,'gust',point)!;
  assert.equal(changed.cells[0].changed,true);
  assert.equal(changed.cells[0].field,'geyser');
});
