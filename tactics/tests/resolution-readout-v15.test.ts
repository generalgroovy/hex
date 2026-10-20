import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,type SimEvent,type SimState,type TeamPlan} from '../lib/tactics-v15.ts';
import {characterPhaseAction,resolutionReadout} from '../lib/resolution-readout-v15.ts';
import {formatTile} from '../lib/board-labels-v9.ts';

const plan=(...orders:TeamPlan['orders']):TeamPlan=>({orders});
const oh='0-oh_tipi',wa='0-wa_bidi',enemy='1-oh_tipi';
function arena(){
 const state=createSimGame();state.inhabitants=[];
 state.cells=state.cells.map(({q,r})=>({q,r,terrain:'plain',biome:'plain',height:0,well:false}));
 Object.assign(state.units.find(unit=>unit.id===oh)!,{q:-2,r:0});
 Object.assign(state.units.find(unit=>unit.id===wa)!,{q:-2,r:2});
 Object.assign(state.units.find(unit=>unit.id===enemy)!,{q:0,r:0});
 return state;
}
const find=(previous:SimState|undefined,next:SimState,id=oh)=>resolutionReadout(previous,next)!.characters.find(unit=>unit.id===id)!;

test('all six characters show their revealed Guard simultaneously without mutation',()=>{
 const before=arena(),after=resolveRound(before,[plan(),plan()]),saved=structuredClone({before,after});
 const readout=resolutionReadout(before,after)!;
 assert.equal(readout.characters.length,6);
 assert.ok(readout.characters.every(unit=>unit.casting.label==='Guard'));
 assert.ok(readout.characters.every(unit=>unit.movement.label.startsWith('Stayed ')));
 assert.ok(readout.characters.every(unit=>unit.effects.label==='Health unchanged'));
 assert.equal(readout.round,before.round);
 assert.deepEqual({before,after},saved);
});

test('movement and casting use actual revealed endpoints and spells, not the new empty plan',()=>{
 const before=arena(),move={q:-1,r:0},target={q:0,r:0};
 const after=resolveRound(before,[plan({unitId:oh,move,spellId:'water_jet',cast:target}),plan()]);
 const row=find(before,after);
 assert.equal(row.movement.label,`Moved ${formatTile(move)}`);
 assert.match(row.casting.label,/Water Jet/);assert.ok(row.casting.label.endsWith(formatTile(target)));
 assert.equal(characterPhaseAction(row,'move'),row.movement);
 assert.equal(characterPhaseAction(row,'cast'),row.casting);
 assert.equal(characterPhaseAction(row,'impact'),row.impact);
 assert.equal(characterPhaseAction(row,'settle'),row.review);
});

test('a contested landing and consequent fizzle are separate readable setbacks',()=>{
 const before=arena(),target={q:4,r:0};
 const after=resolveRound(before,[plan({unitId:oh,move:{q:0,r:0},spellId:'water_jet',cast:target}),plan()]);
 const row=find(before,after);
 assert.match(row.movement.label,/^Blocked/);assert.match(row.casting.label,/Water Jet fizzled/);
 assert.match(row.casting.detail,/No Flux or cooldown spent/);
 assert.notEqual(row.casting.label,'Guard');assert.equal(row.casting.tone,'bad');
});

test('healing reports observed HP instead of overheal and status removals stay factual',()=>{
 const before=arena(),unit=before.units.find(unit=>unit.id===oh)!;
 unit.statuses.burn={turns:2,power:1};
 const after=resolveRound(before,[plan({unitId:oh,spellId:'cleansing_tide',cast:{q:unit.q,r:unit.r}}),plan()]);
 assert.ok(after.lastResolution.some(event=>event.kind==='heal'&&(event.amount??0)>0));
 const row=find(before,after);
 assert.equal(row.hpDelta,0);assert.doesNotMatch(row.effects.label,/\+\d+ HP/);
 assert.ok(row.statuses.includes('Burn ended'));assert.ok(row.statuses.includes('Wet'));
});

test('blocked forced displacement is an effect, never a failed voluntary move',()=>{
 const before=arena(),after=structuredClone(before);after.version++;after.round++;
 const unit=after.units.find(unit=>unit.id===oh)!;
 const events:SimEvent[]=[
  {kind:'guard',unitId:oh,text:'Guard'},
  {kind:'cast',unitId:enemy,spellId:'undertow',text:'Undertow'},
  {kind:'push',unitId:oh,from:{q:-2,r:0},to:{q:-1,r:0},text:'Forced to I10'},
  {kind:'bounce',unitId:oh,from:{q:-1,r:0},to:{q:0,r:0},text:'Oh Tipi stays: simultaneous push blocked.'},
 ];
 after.lastResolution=events;Object.assign(unit,{q:-1,r:0});
 const row=find(before,after);
 assert.match(row.movement.label,/^Stayed/);assert.match(row.effects.label,/Forced →/);assert.match(row.effects.label,/Push blocked/);
});

test('eliminated characters stay marked defeated instead of suggesting a return',()=>{
 const before=arena(),unit=before.units.find(unit=>unit.id===oh)!;
 const after=structuredClone(before);after.version++;after.round++;
 Object.assign(after.units.find(candidate=>candidate.id===oh)!,{hp:0,flux:0,statuses:{},cooldowns:{}});
 after.lastResolution=[{kind:'guard',unitId:oh,text:'Guard'},{kind:'defeat',unitId:oh,text:'Defeated'}];
 const fallen=find(before,after);assert.match(fallen.effects.label,/Defeated/);assert.equal(fallen.hpDelta,-unit.hp);
 assert.doesNotMatch(characterPhaseAction(fallen,'impact').label,/HP|Defeated/);
 const later=resolveRound(after,[plan(),plan()]);
 const row=find(after,later);assert.equal(row.hpDelta,null);assert.equal(row.casting.label,'Defeated');
 assert.equal(row.movement.label,'Defeated');assert.equal(row.effects.label,'Defeated');
 assert.ok(!later.lastResolution.some(event=>event.kind==='respawn'));
});

test('missing and stale snapshots do not fabricate health changes, staying or Guard',()=>{
 const before=arena(),after=structuredClone(before);after.version++;after.round++;
 after.lastResolution=[{kind:'cast',unitId:oh,spellId:'water_jet',to:{q:0,r:0},text:'Water Jet'}];
 after.units.find(unit=>unit.id===oh)!.hp--;
 for(const previous of [undefined,{...before,version:before.version-1},{...before,mapId:'frontier:OTHER'}]){
  const readout=resolutionReadout(previous,after)!;
  assert.ok(readout.characters.every(unit=>unit.hpDelta===null));
  assert.ok(readout.characters.every(unit=>unit.casting.label!=='Guard'));
  assert.ok(readout.characters.every(unit=>!unit.movement.label.startsWith('Stayed')));
  assert.match(find(previous,after).casting.label,/Water Jet/);
 }
 assert.equal(resolutionReadout(undefined,before),null);
});
