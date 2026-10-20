import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,getSpell,effectiveSpell,POINTS_TO_WIN,type TeamPlan} from '../lib/tactics-v13.ts';
import {planReadiness,turnGuidance,spellEffectLabel,SHORT_TURN_GUIDANCE} from '../lib/battle-guidance-v13.ts';
import {summarizeExchange} from '../lib/feedback-v13.ts';

test('readiness distinguishes explicit actions from movement and the implicit Guard fallback',()=>{
  const state=createSimGame(),own=state.units.filter(unit=>unit.owner===0);
  const plan:TeamPlan={orders:[{unitId:own[0].id,move:{q:-5,r:0}},{unitId:own[1].id,guard:true},{unitId:own[2].id,spellId:'stone',cast:{q:-5,r:6}}]};
  assert.equal(planReadiness(state,0,plan).ready,2);
  assert.deepEqual(planReadiness(state,0,plan).remainingIds,[own[0].id]);
  assert.equal(planReadiness(state,1,plan).ready,0);
  plan.orders[0].guard=true;
  assert.equal(planReadiness(state,0,plan).allReady,true);
  own[0].hp=0;own[0].respawn=2;
  assert.equal(planReadiness(state,0,plan).active,2);
  assert.equal(planReadiness(state,0,plan).ready,2);
});

test('guidance follows the actual action flow and retires after the opening',()=>{
  const state=createSimGame(),own=state.units.filter(unit=>unit.owner===0),unit=own[0];
  const plan:TeamPlan={orders:[]};
  assert.equal(turnGuidance(state,0,plan,unit.id)?.id,'opening');
  assert.match(turnGuidance(state,0,plan,unit.id)!.title,new RegExp(String(POINTS_TO_WIN)));
  plan.orders.push({unitId:unit.id,move:{q:-5,r:0}});
  assert.equal(turnGuidance(state,0,plan,unit.id)?.id,'action');
  plan.orders[0].guard=true;
  assert.equal(turnGuidance(state,0,plan,unit.id)?.id,'next');
  plan.orders=own.map(entry=>({unitId:entry.id,guard:true}));
  assert.equal(turnGuidance(state,0,plan,unit.id)?.id,'commit');
  state.round=4;
  assert.equal(turnGuidance(state,0,plan,unit.id),null);
  state.round=1;state.winner=0;
  assert.equal(turnGuidance(state,0,plan,unit.id),null);
  assert.ok(Object.values(SHORT_TURN_GUIDANCE).every(text=>text.length<=100));
});

test('feedback teaches only a real own fizzle, never an unseen rival intent',()=>{
  const state=createSimGame(),previous=structuredClone(state),own=state.units[0],rival=state.units.find(unit=>unit.owner===1)!;
  state.round=2;
  state.lastResolution=[{kind:'fizzle',unitId:rival.id,owner:1,text:'Rival fizzle'}];
  assert.equal(turnGuidance(state,0,{orders:[]},own.id,previous)?.id,'shared-fields');
  state.lastResolution.push({kind:'fizzle',unitId:own.id,owner:0,text:'Own fizzle'});
  assert.equal(turnGuidance(state,0,{orders:[]},own.id,previous)?.id,'fizzle');
});

test('spell labels use effective values and disclose harmful allied exposure',()=>{
  const ember=effectiveSpell('wa_bidi','ember',{fire:6,air:1});
  assert.match(spellEffectLabel(ember),new RegExp(`${ember.damage} damage`));
  assert.match(spellEffectLabel(ember),/Burn/);
  assert.match(spellEffectLabel(ember),/hits allies/);
  assert.match(spellEffectLabel(getSpell('cleansing_tide')),/heal 2/);
  assert.doesNotMatch(spellEffectLabel(getSpell('cleansing_tide')),/hits allies/);
  assert.match(spellEffectLabel(getSpell('gust')),/push/);
  assert.match(spellEffectLabel(getSpell('frostbite')),/freeze Water/);
  assert.match(spellEffectLabel(getSpell('immolate')),/self −1 HP/);
});

test('visible outcome prioritizes own loss and fizzle before creature narration',()=>{
  const before=createSimGame(),next=structuredClone(before),own=next.units.filter(unit=>unit.owner===0);
  next.scores[1]++;
  next.lastResolution=[
    {kind:'inhabitant',text:'Puddle releases Water across 3 hexes.'},
    {kind:'fizzle',unitId:own[1].id,owner:0,text:'Wa Bidi’s Ember fizzles after a blocked landing. No Flux spent.'},
    {kind:'defeat',unitId:own[0].id,owner:0,text:'Oh Tipi falls.'},
    {kind:'bounce',unitId:own[1].id,owner:0,text:'Wa Bidi stays: movement blocked.'},
  ];
  own[0].hp=0;own[0].respawn=2;
  const result=summarizeExchange(before,next,0);
  assert.match(result.details[0],/Oh Tipi fell/);
  assert.match(result.details[1],/Ember fizzles/);
  assert.match(result.details.at(-1)!,/Puddle/);
  assert.equal(result.details.filter(line=>/Wa Bidi/.test(line)).length,1);
  assert.equal(result.headline,'You +0 · Rival +1');
});

test('captures and real health changes outrank ambient reactions; overheal is not recovery',()=>{
  const before=createSimGame(),next=structuredClone(before),well=next.cells.find(cell=>cell.well)!;
  next.units[0].q=well.q;next.units[0].r=well.r;next.units[1].hp-=2;
  next.lastResolution=[{kind:'inhabitant',text:'Puddle releases.'},{kind:'heal',unitId:next.units[2].id,amount:3,text:'Treevor heals 3.'}];
  const result=summarizeExchange(before,next,0);
  assert.match(result.details[0],/You took 1 well/);
  assert.match(result.details[1],/−2 HP/);
  assert.doesNotMatch(result.details.join(' '),/\+3 HP/);
  assert.match(result.details.at(-1)!,/Puddle/);
});
