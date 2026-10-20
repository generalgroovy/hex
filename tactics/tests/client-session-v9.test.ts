import assert from 'node:assert/strict';
import test from 'node:test';
import {createClientSessionStore} from '../lib/client-session-v9.ts';
import {canonicalPlan} from '../lib/room-plans.ts';
import {createSimGame,prepareTeam,legalCasts,validatePlan,type TeamPlan} from '../lib/tactics-v9.ts';

const code='23456789ABCD',matchId='12345678-1234-1234-1234-123456789abc';
function browserStorage(){
  const values=new Map<string,string>();
  return {getItem:(key:string)=>values.get(key)??null,setItem:(key:string,value:string)=>{values.set(key,value)},removeItem:(key:string)=>{values.delete(key)}};
}

test('a fresh tab restores training, changed equipment and a newly unlocked cast as one private draft',()=>{
  const state=createSimGame();state.round=3;state.version=3;
  const unit=state.units[0],storage=browserStorage(),before=structuredClone(state);
  const prep:TeamPlan={orders:[],training:[{unitId:unit.id,element:'water'}],loadouts:[{unitId:unit.id,spells:['water_jet','deep_freeze','ember','mend']}]};
  const projected=prepareTeam(state,0,prep),target=legalCasts(projected,unit.id,undefined,'deep_freeze')[0];
  const plan:TeamPlan={...prep,orders:[{unitId:unit.id,spellId:'deep_freeze',cast:{q:target.q,r:target.r}}]};
  const context={code,matchId,state,seat:0 as const};
  assert.equal(createClientSessionStore([{kind:'local',storage}]).saveDraft({...context,plan}),'local');
  const reloaded=createClientSessionStore([{kind:'local',storage}]);
  const restored=reloaded.readDraft(context);
  assert.deepEqual(restored,canonicalPlan(plan,9),'reloading must preserve preparation and explicit orders without adding idle Guards');
  assert.deepEqual(validatePlan(state,0,restored),validatePlan(state,0,plan));
  assert.equal(reloaded.readDraft({...context,seat:1}),null,'a draft never crosses the player-seat boundary');
  assert.equal(reloaded.readDraft({...context,state:{...state,round:4,version:4}}),null,'a preparation draft is only valid for its original round');
  assert.deepEqual(state,before,'browser persistence does not apply training to public match state');
});

test('preparation-only drafts survive reload and remain explicit empty orders',()=>{
  const state=createSimGame();state.round=3;state.version=3;
  const unit=state.units[0],storage=browserStorage(),context={code,matchId,state,seat:0 as const};
  for(const plan of [
    {orders:[],training:[{unitId:unit.id,element:'water' as const}]},
    {orders:[],loadouts:[{unitId:unit.id,spells:['water_jet','ember','mend','stone']}]},
  ]){
    createClientSessionStore([{kind:'local',storage}]).saveDraft({...context,plan});
    assert.deepEqual(createClientSessionStore([{kind:'local',storage}]).readDraft(context),canonicalPlan(plan,9));
  }
});
