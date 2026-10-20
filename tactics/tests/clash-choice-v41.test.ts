import test from 'node:test';
import assert from 'node:assert/strict';
import {towerChampion} from '../lib/tower-v23.ts';
import {alliedClashValue} from '../lib/clash-choice-v41.ts';
import {effectiveHealing} from '../lib/combat-ai-v16.ts';
import {createTowerBattle,isCellSolid,legalCasts,validatePlan,plannedProjectileClashes,spellArea,effectiveSpell,previewField,fieldEffects,fieldValue,volleyDamage,resolveRound,type TeamPlan} from '../lib/tactics-v22.ts';
const same=(a:{q:number;r:number},b:{q:number;r:number})=>a.q===b.q&&a.r===b.r;
const at=({q,r}:{q:number;r:number})=>({q,r});
function setup(hp=1){
 const wounded={...towerChampion('treevor_mason','centre'),hp};
 const state=createTowerBattle({id:'clash-choice',mapId:'CLASH-CHOICE',allies:[towerChampion('red_baron','fire'),towerChampion('wa_bidi','air')],enemies:[towerChampion('treevor_mason','far'),wounded],learnedSpells:[]});
 delete state.spellModel; // This authored v41 collision trade uses precision Ember.
 const [fire,air,far,centre]=state.units;
 for(const middle of state.cells.filter(cell=>cell.terrain==='plain'&&!isCellSolid(cell))){
  const points=[-1,1,2,0,-2].map(q=>({q:middle.q+q,r:middle.r}));
  if(points.some(point=>!state.cells.some(cell=>same(cell,point)&&!isCellSolid(cell))))continue;
  [fire,air,far,centre].forEach((unit,index)=>Object.assign(unit,points[index]));
  if(!legalCasts(state,fire.id,undefined,'ember').some(cell=>same(cell,far))||!legalCasts(state,air.id,undefined,'gust').some(cell=>same(cell,points[4])))continue;
  const before=validatePlan(state,0,{orders:[{unitId:fire.id,spellId:'ember',cast:at(far)}]});
  const after=validatePlan(state,0,{orders:[...before.orders.filter(order=>order.spellId),{unitId:air.id,spellId:'gust',cast:points[4]}]});
  const releases=(plan:TeamPlan)=>plan.orders.flatMap(order=>{if(!order.spellId||!order.cast)return [];const actor=state.units.find(unit=>unit.id===order.unitId)!;return [{unitId:actor.id,spell:effectiveSpell(actor.championId,order.spellId,actor.affinities),area:spellArea(state,actor.id,order.spellId,order.cast)}]});
  const input={cells:state.cells,allies:[fire,air],enemies:[far,centre],origins:state.units,before:releases(before),after:releases(after),beforeClashes:plannedProjectileClashes(state,before),afterClashes:plannedProjectileClashes(state,after),guards:new Set<string>(),cost:2,selfDamage:0};
  if(!input.afterClashes.length)continue;
  return {state,before,after,input};
 }
 throw new Error('No legal clash on seeded map');
}
const rules={field:previewField,effects:fieldEffects,damage:volleyDamage,fieldValue,healing:effectiveHealing};

test('an opening Arcstorm can be worth its sacrificed direct hit, and the real field defeats the target',()=>{
 const {state,before,after,input}=setup();
 assert.equal(input.afterClashes.length,1);assert.deepEqual(input.afterClashes[0].elements,['fire','air']);
 assert.ok(alliedClashValue(input,rules)>0);
 const ordinary=resolveRound(state,[before,{orders:[]}]),combined=resolveRound(state,[after,{orders:[]}]);
 assert.equal(ordinary.units.find(unit=>unit.id==='centre')!.hp,1);
 assert.equal(combined.units.find(unit=>unit.id==='centre')!.hp,0);
 assert.ok(combined.lastResolution.some(event=>event.kind==='surface'&&event.unitId==='centre'&&event.amount===1&&event.terrain==='arcstorm'));
 assert.ok(combined.units.filter(unit=>unit.owner===0).every(unit=>unit.hp>0),'The nonlethal cost to allies is part of the trade');
});

test('the same collision is rejected when it wastes the hit without a tactical payoff',()=>{
 const {input}=setup(8);
 assert.ok(alliedClashValue(input,rules)<0);
});

test('collision utility is deterministic and independent of actor/cast enumeration and seat labels',()=>{
 const {input}=setup();
 const baseline=alliedClashValue(input,rules);
 const swapped={...input,allies:input.allies.map(unit=>({...unit,owner:1 as const})).reverse(),enemies:input.enemies.map(unit=>({...unit,owner:0 as const})).reverse(),before:[...input.before].reverse(),after:[...input.after].reverse(),cells:[...input.cells].reverse()};
 assert.equal(alliedClashValue(swapped,rules),baseline);
 assert.equal(alliedClashValue(input,rules),baseline);
});
