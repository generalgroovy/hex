import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame} from '../lib/tactics-v7.ts';
import {wellControl,teamOrders,nextUnplannedUnit} from '../lib/battle-readout-v7.ts';

test('well readout counts public occupants and Penumbra without promising future scoring',()=>{
 const state=createSimGame(),wells=state.cells.filter(c=>c.well);
 Object.assign(state.units[0],{q:wells[0].q,r:wells[0].r});
 Object.assign(state.units[1],{q:wells[1].q,r:wells[1].r,hp:0,respawn:1});
 const rival=state.units.find(u=>u.owner===1)!;
 Object.assign(rival,{q:wells[2].q,r:wells[2].r});wells[2].reactions=['penumbra'];
 assert.deepEqual(wellControl(state),[{count:1,value:1},{count:1,value:2}]);
});

test('order readout distinguishes explicit Guard from untouched default and keeps real cast target',()=>{
 const state=createSimGame(),own=state.units.filter(u=>u.owner===0);
 const plan={orders:[{unitId:own[0].id,guard:true as const},{unitId:own[1].id,move:{q:-3,r:0},cast:{q:-2,r:0},spellId:'ember'}]};
 const rows=teamOrders(state,0,plan);
 assert.deepEqual(rows.map(r=>r.planned),[true,true,false]);
 assert.equal(rows[0].label,'Hold · Guard');
 assert.equal(rows[1].label,'Move -3, 0 · Ember → -2, 0');
 assert.equal(nextUnplannedUnit(state,0,plan,own[0].id),own[2].id);
 own[2].hp=0;own[2].respawn=1;
 assert.equal(nextUnplannedUnit(state,0,plan,own[0].id),own[1].id);
 assert.equal(teamOrders(state,0,plan)[2].label,'Recovering');
});
