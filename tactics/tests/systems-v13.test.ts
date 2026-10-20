import test from 'node:test';
import assert from 'node:assert/strict';
import {CHAMPIONS,getChampion,allocateAffinityBudget} from '../lib/roster-v13.ts';
import {SPELLS,ALL_SPELLS,defaultLoadout,repairLoadout,validateLoadout,spellAccess,availableSpellIds,getSpell,getSignature,effectiveSpell} from '../lib/spells-v13.ts';
import {spellAccess as oldAccess,validateLoadout as oldLoadout} from '../lib/spells-v12.ts';
import {createSimGame,resolveRound,restoreSimState,validatePlan,castAvailability,chooseAIPlan,getCell,previewField,displacementSteps,mitigatedSpellDamage,volleyDamage,distance,type SimState,type SimUnit,type TeamPlan} from '../lib/tactics-v13.ts';
import {createSimGame as createOld,resolveRound as resolveOld} from '../lib/tactics-v12.ts';
import {choosePracticePlan} from '../lib/practice-v13.ts';

const empty=():TeamPlan=>({orders:[]});
const point=({q,r}:{q:number;r:number})=>({q,r});
const at=(unit:SimUnit,q:number,r:number)=>Object.assign(unit,{q,r});
function forces(){
 const state=createSimGame([['grace_reava','fluup','spai_si'],['oh_tipi','wa_bidi','treevor_mason']]);
 for(const cell of state.cells){cell.biome='plain';cell.terrain='plain';cell.height=0;cell.well=false;}
 state.units.slice(0,3).forEach((unit,index)=>{at(unit,-3+index,0);unit.loadout=validateLoadout(unit.championId,['gust','gale','tailwind','wind_shear'],unit.affinities);});
 const victim=state.units[3];at(victim,0,0);return {state,victim};
}
const forcePlan=(state:SimState,count:number,spellId='gust'):TeamPlan=>({orders:state.units.slice(0,count).map(unit=>({unitId:unit.id,spellId,cast:{q:0,r:0}}))});

test('all ordinary spell levels require allocated affinity, with exact thresholds for every champion',()=>{
 for(const champion of CHAMPIONS)for(const spell of SPELLS){
  const access=spellAccess(champion.id,spell.id),points=champion.affinities[spell.element]??0;
  assert.equal(access.requiredAffinity,spell.level);assert.equal(access.unlocked,points>=spell.level,`${champion.id}/${spell.id}`);
 }
 assert.equal(oldAccess('oh_tipi','gust').unlocked,true,'frozen rules12 still allows off-element basics');
 assert.equal(spellAccess('oh_tipi','gust').unlocked,false);
 assert.equal(spellAccess('oh_tipi','gust',{water:3,fire:2,air:1}).unlocked,true,'earned third element is valid');
 assert.equal(spellAccess('oh_tipi','gale',{water:3,fire:2,air:1}).unlocked,false);
});

test('all thirty starter kits validate, preserve native ingredients and retain signature discounts',()=>{
 for(const champion of CHAMPIONS){
  const kit=defaultLoadout(champion.id);assert.deepEqual(validateLoadout(champion.id,kit),kit);
  assert.equal(kit.length,4);assert(kit.every(id=>(champion.affinities[getSpell(id).element]??0)>0));
  const signature=getSignature(champion.id),effective=effectiveSpell(champion.id,signature.id);
  assert.equal(spellAccess(champion.id,signature.id).requiredAffinity,3);assert.equal(effective.cost,signature.cost-2);
  assert(availableSpellIds(champion.id,kit).includes(signature.id));
 }
 const signature=getSignature('juul_i_yaina');
 assert.equal(spellAccess('oh_tipi',signature.id,{water:5,fire:2},[signature.id]).unlocked,true);
 assert.equal(spellAccess('oh_tipi',signature.id,{water:4,fire:2},[signature.id]).unlocked,false);
 assert.equal(spellAccess('oh_tipi',signature.id,{water:5,fire:2},[]).unlocked,false);
});

test('migration reserves every legal custom slot and replaces only now-ineligible spells',()=>{
 const old=['ember','gust','frostbite','mend'];assert.deepEqual(oldLoadout('oh_tipi',old),old);
 const repaired=repairLoadout('oh_tipi',old);assert.equal(repaired[0],'ember');assert.equal(repaired[2],'frostbite');
 assert.notEqual(repaired[1],'gust');assert.notEqual(repaired[3],'mend');
 assert.deepEqual(repairLoadout('oh_tipi',repaired),repaired);assert.deepEqual(old,['ember','gust','frostbite','mend']);
 const allocated={water:3,fire:2,air:1},custom=['gust','ember','frostbite','water_jet'];
 assert.deepEqual(repairLoadout('oh_tipi',custom,allocated),custom);
 assert.throws(()=>validateLoadout('oh_tipi',old),/Requires 1 Air/);
});

test('current engine rejects off-element equips and injected casts without changing historical rules',()=>{
 const state=createSimGame(),unit=state.units[0];assert.equal(state.rulesVersion,13);
 assert.throws(()=>createSimGame(undefined,undefined,[{oh_tipi:['gust','ember','frostbite','water_jet']},{}]),/Requires 1 Air/);
 unit.loadout=['gust','ember','frostbite','water_jet'];assert.equal(castAvailability(state,unit.id,'gust').available,false);
 assert.throws(()=>validatePlan(state,0,{orders:[{unitId:unit.id,spellId:'gust',cast:point(unit)}]}),/Requires 1 Air/);
 assert.throws(()=>restoreSimState(state),/Requires 1 Air/);
 const old=createOld(undefined,undefined,[{oh_tipi:['gust','ember','frostbite','water_jet']},{}]);
 assert.equal(old.rulesVersion,12);assert.equal(resolveOld(old,[empty(),empty()]).round,2);
});

test('Guard subtracts one combined strength before the two-step limit; vectors and diagonals cancel',()=>{
 for(const strength of [0,1,2,3,7]){assert.equal(displacementSteps({q:strength,r:0},true),Math.min(2,Math.max(0,strength-1)));assert.equal(displacementSteps({q:strength,r:0},false,true),0);}
 assert.equal(displacementSteps({q:.5,r:.5},true),0);assert.equal(displacementSteps({q:1,r:1},true),1);
 assert.equal(displacementSteps({q:1,r:-1},true),0);assert.equal(displacementSteps({q:1.5,r:-.5},true),1);
 assert.equal(displacementSteps({q:0,r:0},true),0);assert.equal(displacementSteps({q:1+1e-15,r:0},true),0);
});

test('one Gust cannot unseat Guard, two aligned Gusts push one, three push two',()=>{
 for(const [count,expected] of [[1,0],[2,1],[3,2]]){
  const {state,victim}=forces(),before=structuredClone(state),next=resolveRound(state,[forcePlan(state,count),empty()]);
  assert.deepEqual(point(next.units.find(unit=>unit.id===victim.id)!),{q:expected,r:0});assert.deepEqual(state,before);
  const actual=next.lastResolution.filter(event=>event.kind==='push'&&event.unitId===victim.id).length;assert.equal(actual,expected);
 }
});

test('opposed pushes cancel and existing Anchored blocks a coordinated volley',()=>{
 const opposing=forces();at(opposing.state.units[0],-1,0);at(opposing.state.units[1],1,0);at(opposing.state.units[2],-3,0);
 const cancelled=resolveRound(opposing.state,[forcePlan(opposing.state,2),empty()]);assert.deepEqual(point(cancelled.units[3]),{q:0,r:0});
 const anchored=forces();anchored.victim.statuses.anchored={turns:1,power:1};
 const stopped=resolveRound(anchored.state,[forcePlan(anchored.state,3),empty()]);assert.deepEqual(point(stopped.units[3]),{q:0,r:0});
});

test('fractional diagonal vectors combine before resistance and resolve independently of unit array order',()=>{
 const {state}=forces();at(state.units[0],-1,-1);at(state.units[1],-2,-2);at(state.units[2],-3,0);
 const single=resolveRound(state,[forcePlan(state,1),empty()]);assert.equal(distance(single.units[3],{q:0,r:0}),0);
 const plan=forcePlan(state,2),combined=resolveRound(state,[plan,empty()]);assert.equal(distance(combined.units[3],{q:0,r:0}),1);
 const reordered=structuredClone(state);reordered.units.reverse();
 const result=resolveRound(reordered,[plan,empty()]);
 assert.deepEqual(point(result.units.find(unit=>unit.id===state.units[3].id)!),point(combined.units[3]));
});

test('fresh Anchored protects next exchange, while a resisted push can still slide along Ice',()=>{
 const fresh=forces(),signature=getSignature(fresh.victim.championId);
 const next=resolveRound(fresh.state,[forcePlan(fresh.state,1,'gale'),{orders:[{unitId:fresh.victim.id,spellId:signature.id,cast:{q:0,r:0}}]}]);
 assert.equal(distance(next.units[3],{q:0,r:0}),2);assert(next.units[3].statuses.anchored);
 const icy=forces();for(let q=1;q<=3;q++)Object.assign(getCell(icy.state,q,0)!,previewField(getCell(icy.state,q,0)!,['water'],true));
 const slid=resolveRound(icy.state,[forcePlan(icy.state,2),empty()]);assert.deepEqual(point(slid.units[3]),{q:3,r:0});
 assert.equal(slid.lastResolution.filter(event=>event.kind==='push'&&event.unitId===icy.victim.id).length,1,'one resisted step becomes a connected ice slide');
});

test('aggregated volleys cross protection once; changing chemistry can reduce marginal damage',()=>{
 const {state,victim}=forces(),cell=getCell(state,0,0)!;cell.biome='forest';
 assert.equal(mitigatedSpellDamage(cell,6,0,2,true),2);
 assert.equal(mitigatedSpellDamage(cell,3,0,2,true),0);
 assert.equal(mitigatedSpellDamage(cell,0,3,2,true),2,'piercing bypasses cover and Ward, not Guard');
 const steam=previewField(cell,['fire','water']);steam.biome='plain';
 assert.equal(mitigatedSpellDamage(steam,3,2,0,false),3,'round once over the complete spell volley');
 const fire={...getSpell('ember'),damage:4},water={...getSpell('water_jet'),damage:1};
 const open={...cell,biome:'plain' as const,terrain:'plain'};
 assert.equal(volleyDamage(open,victim,[fire],true),3);assert.equal(volleyDamage(steam,victim,[fire,water],true),2);
 const wetBonus={...getSpell('fire_lance'),damage:1};assert.equal(volleyDamage(open,victim,[water,wetBonus]),2,'new Wet is not an existing mark');
 victim.statuses.wet={turns:1,power:1};assert.equal(volleyDamage(open,victim,[water,wetBonus]),3);
});

test('all current displacement descriptions explain resistance and retain the old description',()=>{
 for(const spell of ALL_SPELLS.filter(spell=>spell.push))assert.match(spell.description,/Guard resists 1 strength/);
 assert.match(getSpell('frostbite').description,/Freezes unmixed Water/);
});

test('AI coordinates affordable force against a scoring defender, but does not reward an Anchored target',()=>{
 const {state,victim}=forces();getCell(state,0,0)!.well=true;victim.statuses.ward={turns:1,power:5};
 for(const unit of state.units.slice(0,3)){
  unit.statuses.rooted={turns:1,power:1};
  for(const id of [...unit.loadout,getSignature(unit.championId).id])if(id!=='gust')unit.cooldowns[id]=1;
 }
 const plan=chooseAIPlan(state,0);assert.equal(plan.orders.filter(order=>order.spellId==='gust'&&order.cast?.q===0&&order.cast?.r===0).length,3);
 const result=resolveRound(state,[plan,empty()]);assert.equal(result.units[3].q,2);assert.equal(result.scores[1],0);
 victim.guard=true;assert.deepEqual(chooseAIPlan(state,0),plan,'last exchange Guard flag is not knowledge of the new order');
 victim.statuses.anchored={turns:1,power:1};
 assert.equal(chooseAIPlan(state,0).orders.filter(order=>order.spellId==='gust').length,0);
});

test('a complete current match keeps legal native kits, immutable allocations and restorable state',()=>{
 let state=createSimGame([['oh_tipi','wa_bidi','treevor_mason'],['grace_reava','s_wayne','haara']],'frontier:SYSTEMS-13');
 const original=state.units.map(unit=>({id:unit.id,kit:unit.loadout,affinities:unit.affinities}));let rounds=0,casts=0;
 while(state.winner===null){
  const plans=[choosePracticePlan(state,0),choosePracticePlan(state,1)] as [TeamPlan,TeamPlan];
  plans.forEach((plan,owner)=>assert.deepEqual(validatePlan(state,owner as 0|1,plan),plan));
  state=restoreSimState(resolveRound(state,plans));rounds++;casts+=state.lastResolution.filter(event=>event.kind==='cast').length;
 }
 assert(rounds<=20);assert(casts>0);assert.deepEqual(state.units.map(unit=>({id:unit.id,kit:unit.loadout,affinities:unit.affinities})),original);
});
