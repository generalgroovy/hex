import test from 'node:test';
import assert from 'node:assert/strict';
import {placeLoadoutSpell,readDraggedSpell,adjacentSpellSlot} from '../lib/loadout-interaction-v45.ts';
test('moving an equipped spell swaps slots without duplicating or losing spells',()=>{
 const original=['a','b','c','d'];
 assert.deepEqual(placeLoadoutSpell(original,'d',0,original),['d','b','c','a']);
 assert.deepEqual(original,['a','b','c','d']);
 assert.deepEqual(placeLoadoutSpell(original,'a',0,original),original);
});
test('a catalogue drop replaces just the chosen slot and rejects invalid inputs',()=>{
 const original=['a','b','c','d'],allowed=[...original,'e'];
 assert.deepEqual(placeLoadoutSpell(original,'e',2,allowed),['a','b','e','d']);
 for(const slot of [-1,4,1.5,NaN])assert.throws(()=>placeLoadoutSpell(original,'e',slot,allowed));
 assert.throws(()=>placeLoadoutSpell(original,'locked',0,allowed));
 assert.equal(readDraggedSpell('locked',allowed),null);
 assert.equal(readDraggedSpell('https://example.com',allowed),null);
 assert.equal(readDraggedSpell('e',allowed),'e');
});
test('keyboard reordering is bounded and ignores unrelated keys',()=>{
 assert.equal(adjacentSpellSlot(0,'ArrowLeft'),null);
 assert.equal(adjacentSpellSlot(3,'ArrowRight'),null);
 assert.equal(adjacentSpellSlot(2,'ArrowLeft'),1);
 assert.equal(adjacentSpellSlot(2,'ArrowRight'),3);
 assert.equal(adjacentSpellSlot(2,'Enter'),null);
});
