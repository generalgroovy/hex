import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame} from '../lib/tactics-v7.ts';
import {summarizeExchange} from '../lib/feedback-v7.ts';

test('exchange readout does not present overheal or a respawn as recovered HP',()=>{
 const before=createSimGame(),next=structuredClone(before),unit=next.units[0];
 next.lastResolution=[{kind:'heal',unitId:unit.id,owner:unit.owner,amount:2,text:'healing'}];
 assert.deepEqual(summarizeExchange(before,next,0).details,[]);
 before.units[0].hp=0;before.units[0].respawn=1;
 next.lastResolution=[{kind:'respawn',unitId:unit.id,text:'returned'}];
 assert.match(summarizeExchange(before,next,0).details.join(' '),/returned/);
 assert.doesNotMatch(summarizeExchange(before,next,0).details.join(' '),/HP/);
});

test('readout names visible HP changes and captures without claiming hidden outcomes',()=>{
 const before=createSimGame(),next=structuredClone(before),unit=next.units[0],well=next.cells.find(c=>c.well)!;
 unit.hp-=3;unit.q=well.q;unit.r=well.r;next.scores[0]=1;
 const summary=summarizeExchange(before,next,0);
 assert.equal(summary.headline,'You +1 · Rival +0');
 assert.ok(summary.details.some(s=>s.includes('−3 HP')));
 assert.ok(summary.details.some(s=>s==='You took 1 well'));
 assert.deepEqual(summarizeExchange(next,next,0).details,[]);
});
