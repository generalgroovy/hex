import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,getCell,resolveRound,type SimCell} from '../lib/tactics-v13.ts';
import {contactMaterial,groundContacts} from '../lib/combat-life-v13.ts';
import {PHASE_MS} from '../lib/feedback-v13.ts';
import {UNIT_MOTION_MS} from '../lib/battlefield-motion-v13.ts';

const arena=()=>{
  const state=createSimGame();
  state.cells=state.cells.map(({q,r})=>({q,r,terrain:'plain',biome:'plain',height:0,well:false}));
  Object.assign(state.units[0],{q:0,r:0});
  return state;
};

test('a successful move contacts its actual landing on the movement clock',()=>{
  const before=arena(),unit=before.units[0];
  Object.assign(getCell(before,1,0)!,{biome:'water',terrain:'water'});
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:1,r:0}}]},{orders:[]}]);
  const frozen=structuredClone({before,after}),contacts=groundContacts(before,after);
  assert.deepEqual(contacts,[{id:`${unit.id}-move`,unitId:unit.id,point:{q:1,r:0},atMs:PHASE_MS.cast,material:'water',weight:1,kind:'move'}]);
  assert.deepEqual({before,after},frozen);
});

test('an icy landing remains ice feedback even when that field expires after movement',()=>{
  const before=arena(),unit=before.units[0];
  for(let q=1;q<=4;q++)Object.assign(getCell(before,q,0)!,{terrain:'water',elements:['water'],ice:true,ttl:1});
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:4,r:0}}]},{orders:[]}]);
  assert.equal(getCell(after,4,0)!.ice,undefined);
  const contact=groundContacts(before,after).find(contact=>contact.unitId===unit.id)!;
  assert.equal(contact.material,'ice');assert.deepEqual(contact.point,{q:4,r:0});assert.equal(contact.atMs,PHASE_MS.cast);
});

test('a forced landing uses its final destination and the displacement clock',()=>{
  const before=arena(),victim=before.units[3];
  Object.assign(victim,{q:2,r:0});
  // Presentation consumes resolved endpoints; no spell, intent or enemy plan is consulted.
  const after=structuredClone(before);after.version++;
  Object.assign(after.units[3],{q:4,r:0});Object.assign(getCell(after,4,0)!,{biome:'forest',terrain:'earth'});
  after.lastResolution=[{kind:'push',unitId:victim.id,from:{q:2,r:0},to:{q:3,r:0},text:'Push'},{kind:'push',unitId:victim.id,from:{q:3,r:0},to:{q:4,r:0},text:'Push'}];
  const contacts=groundContacts(before,after);
  assert.equal(contacts.length,1);assert.deepEqual(contacts[0].point,{q:4,r:0});assert.equal(contacts[0].kind,'push');assert.equal(contacts[0].material,'leaf');assert.equal(contacts[0].atMs,UNIT_MOTION_MS);
});

test('blocked movement, stationary turns and unmatched snapshots produce no contact motion',()=>{
  const before=arena(),unit=before.units[0];Object.assign(before.units[1],{q:1,r:0});
  const blocked=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:1,r:0}}]},{orders:[]}]);
  assert.ok(blocked.lastResolution.some(event=>event.kind==='bounce'));
  assert.deepEqual(groundContacts(before,blocked),[]);
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:0,r:1}}]},{orders:[]}]);
  assert.deepEqual(groundContacts(undefined,after),[]);assert.deepEqual(groundContacts(before,before),[]);
  assert.deepEqual(groundContacts({...before,mapId:'frontier:DIFFERENT'},after),[]);
  assert.deepEqual(groundContacts({...before,version:before.version-1},after),[]);
});

test('contact material describes the physical surface, with ice taking priority over water',()=>{
  const cell:SimCell={q:0,r:0,terrain:'plain',biome:'plain',height:0,well:false};
  assert.equal(contactMaterial(cell),'dust');assert.equal(contactMaterial({...cell,biome:'ruins'}),'stone');
  assert.equal(contactMaterial({...cell,biome:'forest'}),'leaf');assert.equal(contactMaterial({...cell,biome:'marsh'}),'water');
  assert.equal(contactMaterial({...cell,terrain:'water',elements:['water'],ttl:2}),'water');
  assert.equal(contactMaterial({...cell,terrain:'water',elements:['water'],ttl:2,ice:true}),'ice');
});
