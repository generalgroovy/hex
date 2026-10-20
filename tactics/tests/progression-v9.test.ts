import assert from 'node:assert/strict';
import test from 'node:test';
import {affinityBudget,getChampion} from '../lib/roster-v9.ts';
import {getSpell} from '../lib/spells-v9.ts';
import {createSimGame,prepareTeam,validatePlan,resolveRound,restoreSimState,castAvailability,legalCasts,chooseAIPlan,type SimState,type TeamPlan} from '../lib/tactics-v9.ts';
import {choosePracticePlan,practiceLoadouts} from '../lib/practice-v9.ts';

const empty=():TeamPlan=>({orders:[]});
function atRound(round:number):SimState {let state=createSimGame();while(state.round<round)state=resolveRound(state,[empty(),empty()]);return state;}
const allocated=(unit:SimState['units'][number])=>Object.values(unit.affinities).reduce((sum,points)=>sum+(points??0),0);
const iceKit=['water_jet','deep_freeze','ember','mend'];

test('all characters start with five real points and income is equal, banked and earned after two exchanges',()=>{
  const initial=createSimGame();
  for(const unit of initial.units){assert.equal(allocated(unit),5);assert.deepEqual(unit.affinities,getChampion(unit.championId).affinities);assert.ok(Object.keys(unit.affinities).length<=3);}
  const first=resolveRound(initial,[empty(),empty()]);assert.equal(affinityBudget(first.round),5);
  const second=resolveRound(first,[empty(),empty()]);assert.equal(second.round,3);assert.equal(affinityBudget(second.round),6);
  for(const unit of second.units)assert.equal(affinityBudget(second.round)-allocated(unit),1);
  assert.deepEqual(initial.units.map(unit=>unit.affinities),second.units.map(unit=>unit.affinities),'income never silently chooses an affinity');
  assert.deepEqual(restoreSimState(second),second);
});

test('training, equipping the newly unlocked spell and casting it are one simultaneous order for both teams',()=>{
  const state=atRound(3),before=structuredClone(state);
  const plans=([0,1] as const).map(owner=>{
    const unit=state.units.find(unit=>unit.owner===owner&&unit.championId==='oh_tipi')!;
    const preparation:TeamPlan={orders:[],training:[{unitId:unit.id,element:'water'}],loadouts:[{unitId:unit.id,spells:iceKit}]};
    const projected=prepareTeam(state,owner,preparation);
    assert.equal(projected.units.find(entry=>entry.id===unit.id)!.affinities.water,4);
    assert.equal(projected.units.find(entry=>entry.owner!==owner)!.affinities.water,3);
    const target=legalCasts(projected,unit.id,undefined,'deep_freeze').find(cell=>cell.q!==unit.q||cell.r!==unit.r)!;
    return validatePlan(state,owner,{...preparation,orders:[{unitId:unit.id,spellId:'deep_freeze',cast:{q:target.q,r:target.r}}]});
  }) as [TeamPlan,TeamPlan];
  assert.deepEqual(state,before,'projections and validation preserve authoritative state');
  const next=resolveRound(state,plans);
  assert.equal(next.lastResolution.filter(event=>event.kind==='cast'&&event.spellId==='deep_freeze').length,2);
  for(const unit of next.units.filter(unit=>unit.championId==='oh_tipi')){assert.equal(unit.affinities.water,4);assert.deepEqual(unit.loadout,iceKit);assert.equal(unit.cooldowns.deep_freeze,2);assert.equal(unit.flux,5);}
  assert.deepEqual(restoreSimState(next),next);
});

test('allocation rejects unearned points, fourth elements, level seven, foreign owners and malformed preparation',()=>{
  const opening=createSimGame(),unit=opening.units[0],rival=opening.units[3];
  assert.throws(()=>prepareTeam(opening,0,{orders:[],training:[{unitId:unit.id,element:'water'}]}),/points available/);
  const rich=atRound(9);
  assert.throws(()=>prepareTeam(rich,0,{orders:[],training:[{unitId:unit.id,element:'air'},{unitId:unit.id,element:'earth'}]}),/at most 3/);
  assert.throws(()=>prepareTeam(rich,0,{orders:[],training:Array.from({length:4},()=>({unitId:unit.id,element:'water' as const}))}),/1 to 6/);
  assert.throws(()=>prepareTeam(rich,0,{orders:[],training:[{unitId:rival.id,element:'water'}]}),/your own/);
  assert.throws(()=>prepareTeam(rich,0,{orders:[],loadouts:[{unitId:rival.id,spells:iceKit}]}),/your own/);
  for(const input of [{orders:[],training:null},{orders:[],training:[{unitId:unit.id,element:'ice'}]},{orders:[],training:[{unitId:unit.id,element:'water',points:3}]},{orders:[],loadouts:[{unitId:unit.id,spells:iceKit},{unitId:unit.id,spells:iceKit}]}])assert.throws(()=>validatePlan(rich,0,input));
  assert.throws(()=>prepareTeam(opening,0,{orders:[],loadouts:[{unitId:unit.id,spells:iceKit}]}),/Requires 4 Water/);
  const two=prepareTeam(atRound(5),0,{orders:[],training:[{unitId:unit.id,element:'water'},{unitId:unit.id,element:'water'}]});
  assert.equal(two.units[0].affinities.water,5,'banked points may be spent together');
});

test('unequipping cannot erase cooldowns, saves retain them and re-equipping cannot cast early',()=>{
  const state=atRound(3),unit=state.units[0];
  const prep:TeamPlan={orders:[],training:[{unitId:unit.id,element:'water'}],loadouts:[{unitId:unit.id,spells:iceKit}]};
  const projected=prepareTeam(state,0,prep),target=legalCasts(projected,unit.id,undefined,'deep_freeze')[0];
  const cast=resolveRound(state,[{...prep,orders:[{unitId:unit.id,spellId:'deep_freeze',cast:{q:target.q,r:target.r}}]},empty()]);
  const swapped:TeamPlan={orders:[],loadouts:[{unitId:unit.id,spells:['water_jet','ember','mend','stone']}]};
  const off=prepareTeam(cast,0,swapped);
  assert.equal(off.units[0].cooldowns.deep_freeze,2);
  assert.deepEqual(restoreSimState(off),off,'an unequipped owned cooldown remains a valid save');
  const next=resolveRound(cast,[swapped,empty()]);assert.equal(next.units[0].cooldowns.deep_freeze,1);
  const reequipped:TeamPlan={orders:[],loadouts:[{unitId:unit.id,spells:iceKit}]};
  const on=prepareTeam(next,0,reequipped);assert.equal(castAvailability(on,unit.id,'deep_freeze').available,false);
  assert.throws(()=>validatePlan(next,0,{...reequipped,orders:[{unitId:unit.id,spellId:'deep_freeze',cast:{q:target.q,r:target.r}}]}),/Ready after 1/);
  const ready=resolveRound(next,[reequipped,empty()]);assert.equal(ready.units[0].cooldowns.deep_freeze,undefined);
  assert.equal(castAvailability(ready,unit.id,'deep_freeze').available,true);
});

test('save restoration rejects missing, reassigned, over-budget or otherwise impossible affinities',()=>{
  const state=atRound(3);
  for(const affinity of [undefined,{water:2,fire:3},{water:5,fire:2},{water:3,fire:2,air:1,earth:1},{water:7,fire:2},{water:3,fire:2,ice:1}]){
    const broken=structuredClone(state);(broken.units[0] as any).affinities=affinity;assert.throws(()=>restoreSimState(broken));
  }
  const valid=prepareTeam(state,0,{orders:[],training:[{unitId:state.units[0].id,element:'air'}]});
  assert.deepEqual(restoreSimState(valid),valid,'a third element is permitted within the earned budget');
});

test('AI and practice spend public earned points deterministically and retain preparation through tactical edits',()=>{
  const state=atRound(7),before=structuredClone(state);
  const first=chooseAIPlan(state,1),second=chooseAIPlan(state,1),practice=choosePracticePlan(state,1);
  assert.deepEqual(first,second);assert.deepEqual(state,before);
  assert.ok(first.training?.length);assert.ok(first.loadouts?.length);
  assert.deepEqual(practice.training,first.training);assert.deepEqual(practice.loadouts,first.loadouts);
  assert.deepEqual(validatePlan(state,1,practice),practice);
  const projected=prepareTeam(state,1,practice);
  for(const unit of projected.units.filter(unit=>unit.owner===1)){
    assert.equal(allocated(unit),affinityBudget(state.round));
    assert.ok(unit.loadout.some(id=>getSpell(id).level===1),'the AI retains a basic action beside upgraded spells');
  }
  const kits=practiceLoadouts(['treevor_mason','wa_bidi','s_wayne']);
  assert.doesNotThrow(()=>createSimGame([['treevor_mason','wa_bidi','s_wayne'],['treevor_mason','wa_bidi','s_wayne']],'confluence',[kits,kits]));
});
