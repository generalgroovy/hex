import test from 'node:test';
import assert from 'node:assert/strict';
import {towerChampion} from '../lib/tower-v23.ts';
import {createTowerBattle,resolveRound,legalCasts,isCellSolid,validatePlan,previewField,type SimState,type TeamPlan} from '../lib/tactics-v22.ts';
import {targetImpactPreview} from '../lib/target-impact-v41.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import {planningForecast as legacyForecast} from '../lib/planning-forecast-v16.ts';
import {countersElementPulse} from '../lib/element-counter-v41.ts';
import type {SimState as ViewState} from '../lib/tactics-v20.ts';
const at=({q,r}:{q:number;r:number})=>({q,r});
const same=(a:{q:number;r:number},b:{q:number;r:number})=>a.q===b.q&&a.r===b.r;
const view=(state:SimState)=>({...state,rulesVersion:20}) as unknown as ViewState;
function fixture(forest=false){
 const state=createTowerBattle({id:'impact-preview',mapId:'IMPACT-PREVIEW',allies:[towerChampion('red_baron','fire'),towerChampion('oh_tipi','water')],enemies:[towerChampion('treevor_mason','foe')],learnedSpells:[]});
 delete state.spellModel; // Preserve the original v41 numerical contract alongside v42 tests.
 const [fire,water,foe]=state.units;
 for(const target of state.cells.filter(cell=>forest?cell.biome==='forest':cell.terrain==='plain'&&!isCellSolid(cell))){
  const origins=[{q:target.q-1,r:target.r},{q:target.q,r:target.r-1}];
  if(origins.some(origin=>!state.cells.some(cell=>same(cell,origin)&&!isCellSolid(cell))))continue;
  Object.assign(fire,origins[0]);Object.assign(water,origins[1]);Object.assign(foe,at(target));
  if(legalCasts(state,fire.id,undefined,'ember').some(cell=>same(cell,target))&&legalCasts(state,water.id,undefined,'water_jet').some(cell=>same(cell,target)))return {state,fire,water,foe,target};
 }
 throw new Error('No legal fixture placement on actual seeded map');
}
function damageTo(state:SimState,id:string){return state.lastResolution.filter(event=>event.kind==='damage'&&event.unitId===id).reduce((sum,event)=>sum+(event.amount??0),0);}

test('known combined volley respects Steam, forest and Ward, matching both real Guard branches',()=>{
 for(const forest of [false,true])for(const ward of [0,1]){
  const {state,fire,water,foe,target}=fixture(forest);
  if(ward)foe.statuses.ward={turns:2,power:ward};
  const plan=validatePlan(state,0,{orders:[{unitId:fire.id,spellId:'ember',cast:at(target)},{unitId:water.id,spellId:'water_jet',cast:at(target)}]});
  const before=JSON.stringify(state),preview=targetImpactPreview(view(state),0,plan,fire.id)!;
  assert.ok(preview);assert.equal(preview.conditional,true);
  const impact=preview.targets.find(unit=>unit.id===foe.id)!;
  assert.ok(impact);if(!forest)assert.ok(impact.damage.max<=3,'Steam halves the scaled combined damage before other protection');
  const guarding=resolveRound(state,[plan,{orders:[]}]);assert.equal(damageTo(guarding,foe.id),impact.damage.min);
  // Self Cauterize neither intercepts the volley nor adds a new Steam ingredient.
  const casting=resolveRound(state,[plan,{orders:[{unitId:foe.id,spellId:'cauterize',cast:at(foe)}]}]);assert.equal(damageTo(casting,foe.id),impact.damage.max);
  assert.equal(JSON.stringify(state),before,'Forecast and resolution preserve the input');
 }
});

test('known friendly Guard is exact and a harmless candidate never exposes rival draft orders',()=>{
 const {state,fire,water,foe}=fixture();
 const plan:TeamPlan={orders:[{unitId:fire.id,spellId:'water_jet',cast:at(water)},{unitId:foe.id,spellId:'stone',cast:at(fire)}]};
 const preview=targetImpactPreview(view(state),0,plan,fire.id)!;
 const ally=preview.targets.find(unit=>unit.id===water.id)!;
 assert.equal(ally.damage.min,ally.damage.max);
 const resolved=resolveRound(state,[{orders:plan.orders.filter(order=>order.unitId!==foe.id)},{orders:[]}]);
 assert.equal(ally.damage.min,damageTo(resolved,water.id));
 assert.equal(preview.enemyCount,0);
});

test('liquid Water and dry Ice advertise only statuses the actual resolver grants',()=>{
 const {state,water,foe,target}=fixture();water.loadout=['frostbite','water_jet','ember','cleansing_tide'];
 const frozen=validatePlan(state,0,{orders:[{unitId:water.id,spellId:'frostbite',cast:at(target)}]});
 const predicted=planningForecast(view(state),0,frozen,water.id)!;
 assert.equal(predicted.groups[0].name,'Ice');assert.doesNotMatch(predicted.groups[0].shortRule,/Wet/);
 const old=legacyForecast({...state,rulesVersion:16} as never,0,frozen as never,water.id)!;
 assert.equal(old.groups[0].name,'Ice');assert.doesNotMatch(old.groups[0].shortRule,/Wet/);
 const next=resolveRound(state,[frozen,{orders:[]}]);assert.equal(next.units.find(unit=>unit.id===foe.id)!.statuses.wet,undefined);
 const liquid=validatePlan(state,0,{orders:[{unitId:water.id,spellId:'water_jet',cast:at(target)}]});
 assert.match(planningForecast(view(state),0,liquid,water.id)!.groups[0].shortRule,/Wet/);
 assert.ok(resolveRound(state,[liquid,{orders:[]}]).units.find(unit=>unit.id===foe.id)!.statuses.wet);
});

test('healing preview applies Wither and Tower overtime once, just like the actual exchange',()=>{
 const {state,water,fire}=fixture();state.round=6;fire.hp=2;fire.statuses.wither={turns:2,power:1};
 const targetCell=state.cells.find(cell=>same(cell,fire))!;Object.assign(targetCell,previewField(targetCell,['water','light']));
 const plan=validatePlan(state,0,{orders:[{unitId:water.id,spellId:'cleansing_tide',cast:at(fire)}]});
 const preview=targetImpactPreview(view(state),0,plan,water.id,undefined,undefined,{healingTax:1})!;
 const target=preview.targets.find(unit=>unit.id===fire.id)!;
 const next=resolveRound(state,[plan,{orders:[]}]);
 const healing=next.lastResolution.filter(event=>event.kind==='heal'&&event.unitId===fire.id).reduce((sum,event)=>sum+(event.amount??0),0);
 assert.equal(target.healing,healing);assert.ok(target.healing>0);
});

test('mixed secondary elements can counter a pulse only at its actual perch',()=>{
 const pulse={counterElement:'water' as const,anchor:{q:1,r:0}};
 assert.equal(countersElementPulse(['fire','water'],[{q:1,r:0}],pulse),true);
 assert.equal(countersElementPulse(['fire'],[{q:1,r:0}],pulse),false);
 assert.equal(countersElementPulse(['fire','water'],[{q:0,r:0}],pulse),false);
});

test('a planned projectile collision removes its direct hits from the outcome preview',()=>{
 const {state,fire,water}=fixture();
 const plan=validatePlan(state,0,{orders:[{unitId:fire.id,spellId:'ember',cast:at(water)},{unitId:water.id,spellId:'water_jet',cast:at(fire)}]});
 const preview=targetImpactPreview(view(state),0,plan,fire.id)!;
 assert.equal(preview.cancelled,true);assert.equal(preview.collisionName,'Steam');
 assert.ok(preview.targets.length);assert.ok(preview.targets.every(target=>target.damage.min===0&&target.damage.max===0));
 const next=resolveRound(state,[plan,{orders:[]}]);assert.ok(next.lastResolution.some(event=>event.kind==='clash'));
 for(const target of preview.targets)assert.equal(damageTo(next,target.id),0);
});
