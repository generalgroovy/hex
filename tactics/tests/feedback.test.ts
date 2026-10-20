import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,type SimEvent} from '../lib/tactics.ts';
import {RESOLUTION_MS,PHASE_MS,EVENT_TEXT_MS,eventDelayMs,summarizeExchange,eventLabelLanes,reactionLabelGroups,resolutionCues} from '../lib/feedback.ts';

test('large reaction exchanges retain scoring, defeats and next-round statuses in the summary',()=>{
  const before=createSimGame(),next=structuredClone(before),unit=next.units[0];
  next.scores=[2,1];next.lastResolution=Array.from({length:19},(_,i)=>({kind:'reaction',q:i%5,r:0,terrain:'steam',text:'Steam'}));
  next.lastResolution.push({kind:'defeat',unitId:unit.id,owner:0,text:'Fallen'},{kind:'surface',unitId:unit.id,owner:0,status:'blind',text:'Blind'},{kind:'score',owner:0,amount:2,text:'Wells'});
  const summary=summarizeExchange(before,next,1);
  assert.equal(summary.headline,'You +1 · Rival +2');assert.deepEqual(summary.score,[2,1]);
  assert.match(summary.details[0],/fell/);assert.ok(summary.details.some(s=>s.includes('Blind')));assert.ok(summary.details.some(s=>s.includes('19 hexes')));
  assert.equal(before.scores[0],0);
});

test('score-only exchange never claims that no points scored',()=>{
  const before=createSimGame(),next=structuredClone(before);next.scores=[1,0];next.lastResolution=[{kind:'score',owner:0,amount:1,text:'Well'}];
  assert.equal(summarizeExchange(before,next,0).headline,'You +1 · Rival +0');assert.ok(!summarizeExchange(before,next,0).details.join(' ').includes('No points'));
});

test('the shared replay clock includes every final event label and orders cast before impact',()=>{
  const kinds:SimEvent['kind'][]=['move','bounce','cast','reaction','damage','heal','push','defeat','respawn','score','guard','fizzle','surface'];
  assert.ok(PHASE_MS.cast<PHASE_MS.impact&&PHASE_MS.impact<PHASE_MS.settle);
  for(const kind of kinds)assert.ok(eventDelayMs({kind,text:''})+EVENT_TEXT_MS<=RESOLUTION_MS,kind);
});

test('crowded same-hex labels have distinct lanes and retain an explicit overflow count',()=>{
  const state=createSimGame(),unit=state.units[0];
  const events:SimEvent[]=(['guard','surface','heal','damage','defeat','surface'] as const).map(kind=>({kind,unitId:unit.id,text:''}));
  const lanes=eventLabelLanes(events,state);assert.equal(lanes.size,4);assert.equal(new Set([...lanes.values()].map(l=>l.row)).size,4);
  assert.ok(lanes.has(4),'defeat retained');assert.ok(lanes.has(3),'damage retained');assert.ok(lanes.has(2),'healing retained');
  assert.equal([...lanes.values()].find(l=>l.overflow)?.overflow,3);
});

test('wide reaction areas keep each tile burst but need only one name per combination',()=>{
  const state=createSimGame();const events:SimEvent[]=state.cells.slice(0,19).map(c=>({kind:'reaction',q:c.q,r:c.r,terrain:'steam',text:''}));
  events.push({kind:'reaction',q:6,r:0,terrain:'magma',text:''});
  assert.deepEqual([...reactionLabelGroups(events,state).values()],[19,1]);
  const cues=resolutionCues([...events,{kind:'cast',elements:['water'],text:''},{kind:'score',owner:0,amount:1,text:''}]);
  assert.deepEqual(cues.map(c=>c.kind),['cast','reaction','score']);assert.equal(cues[0].at,PHASE_MS.cast);
});

test('zero-point score events do not play a scoring flourish',()=>{
  assert.deepEqual(resolutionCues([{kind:'guard',text:''},{kind:'score',owner:0,amount:0,text:''},{kind:'score',owner:1,amount:0,text:''}]),[]);
  assert.equal(resolutionCues([{kind:'defeat',text:''}])[0].kind,'score');
});
