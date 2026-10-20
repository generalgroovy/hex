import test from 'node:test';
import assert from 'node:assert/strict';
import {chooseAIPlan,createSimGame,resolveRound,validatePlan,restoreSimState,previewField,type SimState,type Point,type TeamPlan} from '../lib/tactics-v14.ts';
import {chooseAIPlan as chooseOld,createSimGame as createOld,resolveRound as resolveOld,type SimState as OldState} from '../lib/tactics-v13.ts';
import {getSpell,validateLoadout} from '../lib/spells-v14.ts';
import {choosePracticePlan} from '../lib/practice-v14.ts';
import {availableTheft,effectiveHealing,harmfulStatusValue,threatensAlly} from '../lib/combat-ai-v14.ts';

const empty=():TeamPlan=>({orders:[]});
const at=(state:SimState|OldState,q:number,r:number)=>state.cells.find(cell=>cell.q===q&&cell.r===r)!;
function clear<S extends SimState|OldState>(state:S):S {
  for(const cell of state.cells){cell.biome='plain';cell.terrain='plain';cell.height=0;cell.well=false;}
  for(const unit of state.units){unit.hp=0;unit.respawn=3;}
  return state;
}
function veilFixture<S extends SimState|OldState>(make:()=>S):S {
  const state=clear(make()),caster=state.units[0],victim=state.units[3];
  Object.assign(caster,{q:0,r:0,hp:8,flux:2,statuses:{rooted:{turns:1,power:1}},loadout:validateLoadout(caster.championId,['veil','wither_bolt','siphon','clear_sight'],caster.affinities),cooldowns:{wither_bolt:2,siphon:2,clear_sight:2,signature_s_wayne:2}});delete caster.respawn;
  Object.assign(victim,{q:2,r:0,hp:8,flux:0,statuses:{resolve:{turns:2,power:1},wither:{turns:2,power:1}}});delete victim.respawn;
  Object.assign(at(state,2,0),previewField(at(state,2,0),['dark']));
  return state;
}
const veilNew=()=>veilFixture(()=>createSimGame([['s_wayne','oh_tipi','treevor_mason'],['wa_bidi','oh_tipi','treevor_mason']]));
const veilOld=()=>veilFixture(()=>createOld([['s_wayne','oh_tipi','treevor_mason'],['wa_bidi','oh_tipi','treevor_mason']]));

test('CPU saves Flux when control is blocked, theft is empty and the field adds nothing',()=>{
  const old=veilOld(),oldPlan=chooseOld(old,0);
  assert.equal(oldPlan.orders[0].spellId,'veil','retains proof of the published baseline mistake');
  const oldResult=resolveOld(old,[oldPlan,empty()]);assert.equal(oldResult.units[3].hp,8);assert.equal(oldResult.units[3].statuses.blind,undefined);
  const state=veilNew(),before=structuredClone(state),plan=chooseAIPlan(state,0);
  assert.equal(plan.orders[0].guard,true);assert.equal(plan.orders[0].cast,undefined);
  assert.deepEqual(choosePracticePlan(state,0),plan);assert.deepEqual(validatePlan(state,0,plan),plan);assert.deepEqual(state,before);
  const result=resolveRound(state,[plan,empty()]);assert.equal(result.units[0].flux,5,'Guard recovers rather than paying for no effect');
});

test('the same cast remains useful when control can land or public Flux can be stolen',()=>{
  const control=veilNew();delete control.units[3].statuses.resolve;
  const plan=chooseAIPlan(control,0);assert.equal(plan.orders[0].spellId,'veil');
  assert.equal(resolveRound(control,[plan,empty()]).units[3].statuses.blind?.turns,1);
  const theft=veilNew();theft.units[3].flux=1;
  const stolen=chooseAIPlan(theft,0);assert.equal(stolen.orders[0].spellId,'veil');
  const result=resolveRound(theft,[stolen,empty()]);
  assert.equal(result.units[3].flux,3,'one available Flux is stolen before three Guard recovery');
  assert.equal(result.units[3].statuses.blind,undefined,'the bot did not invent successful control');
});

function healingFixture<S extends SimState|OldState>(make:()=>S):S {
  const state=clear(make()),caster=state.units[0];
  Object.assign(caster,{q:0,r:0,hp:7,flux:2,statuses:{rooted:{turns:1,power:1},wither:{turns:2,power:1},clarity:{turns:2,power:1}},loadout:validateLoadout(caster.championId,['radiant_bolt','mend','wither_bolt','veil'],caster.affinities),cooldowns:{mend:2,wither_bolt:2,veil:2,signature_s_wayne:2}});delete caster.respawn;
  Object.assign(at(state,0,0),previewField(at(state,0,0),['light']));return state;
}
test('Wither-aware healing avoids a zero-heal cast, while removing Wither restores the rescue',()=>{
  const make=()=>createSimGame([['s_wayne','oh_tipi','treevor_mason'],['wa_bidi','oh_tipi','treevor_mason']]);
  const old=healingFixture(()=>createOld([['s_wayne','oh_tipi','treevor_mason'],['wa_bidi','oh_tipi','treevor_mason']]));
  const oldPlan=chooseOld(old,0);assert.equal(oldPlan.orders[0].spellId,'radiant_bolt');assert.equal(resolveOld(old,[oldPlan,empty()]).units[0].hp,7);
  const state=healingFixture(make);assert.equal(chooseAIPlan(state,0).orders[0].guard,true);
  delete state.units[0].statuses.wither;
  const useful=chooseAIPlan(state,0);assert.equal(useful.orders[0].spellId,'radiant_bolt');assert.equal(resolveRound(state,[useful,empty()]).units[0].hp,8);
});

function vacuumFixture<S extends SimState|OldState>(make:()=>S):S {
  const state=clear(make()),caster=state.units[0],ally=state.units[1],rival=state.units[3];
  Object.assign(caster,{q:0,r:0,hp:8,flux:2,statuses:{rooted:{turns:1,power:1}},loadout:validateLoadout(caster.championId,['vacuum','gust','water_jet','cauterize'],caster.affinities),cooldowns:{gust:2,water_jet:2,cauterize:2,signature_fluup:2}});delete caster.respawn;
  Object.assign(ally,{q:2,r:0,hp:8,flux:0,statuses:{rooted:{turns:1,power:1}}});delete ally.respawn;
  Object.assign(rival,{q:8,r:-8,hp:8});delete rival.respawn;
  Object.assign(at(state,2,0),previewField(at(state,2,0),['fire','earth']),{well:true});return state;
}
test('zero-damage Vacuum does not sacrifice an allied well for an attractive field transformation',()=>{
  const old=vacuumFixture(()=>createOld([['fluup','oh_tipi','treevor_mason'],['s_wayne','oh_tipi','treevor_mason']]));
  const oldPlan=chooseOld(old,0);assert.equal(oldPlan.orders[0].spellId,'vacuum');
  const oldResult=resolveOld(old,[oldPlan,empty()]);assert.equal(oldResult.units[1].q,1);assert.equal(oldResult.scores[0],0);
  const state=vacuumFixture(()=>createSimGame([['fluup','oh_tipi','treevor_mason'],['s_wayne','oh_tipi','treevor_mason']]));
  const plan=chooseAIPlan(state,0);assert.equal(plan.orders[0].guard,true);
  const result=resolveRound(state,[plan,empty()]);assert.equal(result.units[1].q,2);assert.equal(result.scores[0],1);
});

test('utility accounts for Wet, Clarity, cleanse, repeated marks and aggregate healing',()=>{
  const unit={hp:6,maxHp:8,flux:1,statuses:{wither:{turns:2,power:1}}};
  assert.equal(effectiveHealing(unit,1),0);assert.equal(effectiveHealing(unit,2),1);assert.equal(effectiveHealing(unit,1,true),1);
  assert.equal(availableTheft(unit,2),1);assert.equal(availableTheft(unit,2,[getSpell('veil')]),0);
  const victim={...unit,statuses:{}};
  assert.equal(harmfulStatusValue(victim,getSpell('veil'),{}),1);
  assert.equal(harmfulStatusValue(victim,getSpell('veil'),{statuses:[{id:'clarity',turns:1}]}),0);
  assert.equal(harmfulStatusValue(victim,getSpell('veil'),{cleanse:true}),0);
  assert.equal(harmfulStatusValue(victim,getSpell('veil'),{},[getSpell('veil')]),0);
  assert.equal(harmfulStatusValue(victim,getSpell('ember'),{statuses:[{id:'wet',turns:1}]}),0);
  assert.equal(threatensAlly(getSpell('vacuum')),true);assert.equal(threatensAlly(getSpell('veil')),true);assert.equal(threatensAlly(getSpell('cleansing_tide')),false);
});

test('new public-state decisions mirror seats and ignore historical Guard flags',()=>{
  const state=veilNew();state.units[3].flux=1;
  const expected=chooseAIPlan(state,0);state.units[3].guard=true;assert.deepEqual(chooseAIPlan(state,0),expected);
  const flip=({q,r}:Point):Point=>({q:-q||0,r:-r||0}),id=(value:string)=>`${1-Number(value[0])}${value.slice(1)}`;
  const mirrored:SimState={...structuredClone(state),units:state.units.map(unit=>({...structuredClone(unit),...flip(unit),id:id(unit.id),owner:(1-unit.owner) as 0|1})),cells:state.cells.map(cell=>({...structuredClone(cell),...flip(cell)}))};
  assert.deepEqual(chooseAIPlan(mirrored,1),{orders:expected.orders.map(order=>({...order,unitId:id(order.unitId),...(order.move?{move:flip(order.move)}:{}),...(order.cast?{cast:flip(order.cast)}:{})}))});
});

test('current practice and base CPU complete a seeded match with legal plans and restorable rounds',()=>{
  let state=createSimGame([['oh_tipi','wa_bidi','treevor_mason'],['grace_reava','haara','s_wayne']],'frontier:COMBAT-CHOICES');
  while(state.winner===null){const plans:[TeamPlan,TeamPlan]=[choosePracticePlan(state,0),chooseAIPlan(state,1)];for(const owner of [0,1] as const)assert.deepEqual(validatePlan(state,owner,plans[owner]),plans[owner]);state=resolveRound(state,plans);assert.deepEqual(restoreSimState(state),state);}
  assert(state.round<=20);
});
