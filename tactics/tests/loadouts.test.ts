import test from 'node:test';
import assert from 'node:assert/strict';
import {readLoadouts} from '../lib/loadouts.ts';
import {CHAMPIONS} from '../lib/roster.ts';
import {defaultLoadout as oldStarter} from '../lib/spells-v4.ts';
import {defaultLoadout,getSpell} from '../lib/spells.ts';

test('returning v4 starters gain a native area spell without modifying stored input',()=>{
 const input=Object.fromEntries(CHAMPIONS.map(c=>[c.id,oldStarter(c.id)])),before=structuredClone(input),result=readLoadouts(input,true);
 for(const c of CHAMPIONS){assert.deepEqual(result[c.id],defaultLoadout(c.id));assert.ok(result[c.id].some(id=>getSpell(id).shape!=='hex'))}
 assert.deepEqual(input,before);
});
test('a custom or reordered old kit is preserved, and a deliberate v5 old-style kit stays exact',()=>{
 const custom=['water_jet','ember','frostbite','mend'];assert.deepEqual(readLoadouts({oh_tipi:custom},true).oh_tipi,custom);
 const reordered=oldStarter('oh_tipi').reverse();assert.deepEqual(readLoadouts({oh_tipi:reordered},true).oh_tipi,reordered);
 const deliberate=oldStarter('oh_tipi');assert.deepEqual(readLoadouts({oh_tipi:deliberate}).oh_tipi,deliberate);
});
test('one damaged kit cannot discard another valid custom kit',()=>{
 const custom=['stone','raise_cairn','gust','mend'],result=readLoadouts({oh_tipi:['forged'],treevor_mason:custom},true);
 assert.deepEqual(result.oh_tipi,defaultLoadout('oh_tipi'));assert.deepEqual(result.treevor_mason,custom);assert.equal(Object.keys(result).length,30);
});
