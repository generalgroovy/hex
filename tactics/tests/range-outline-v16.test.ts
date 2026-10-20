import test from 'node:test';
import assert from 'node:assert/strict';
import {rangeBoundaryEdges,rangeBoundaryPath} from '../lib/range-outline-v16.ts';
import {surfacePoint,TILE_HALF_HEIGHT} from '../lib/battlefield-geometry.ts';
import {projectileMeetingMs,PHASE_MS,CAST_ANTICIPATION_MS,PROJECTILE_FLIGHT_MS} from '../lib/feedback-v16.ts';

test('reachable outlines suppress shared interior edges and preserve holes',()=>{
  assert.equal(rangeBoundaryEdges([{q:0,r:0}]).length,6);
  assert.equal(rangeBoundaryEdges([{q:0,r:0},{q:1,r:0}]).length,10);
  const ring=[{q:1,r:0},{q:0,r:1},{q:-1,r:1},{q:-1,r:0},{q:0,r:-1},{q:1,r:-1}];
  assert.equal(rangeBoundaryEdges(ring).length,24,'18 exterior and 6 inside a real terrain/sight hole');
  assert.equal(rangeBoundaryEdges([...ring,{q:0,r:0}]).length,18);
  assert.equal(rangeBoundaryEdges([...ring,...ring]).length,24,'duplicate target input cannot double the outline');
});

test('range outlines follow exactly the elevated board surface',()=>{
  const point={q:2,r:-1},at=surfacePoint(point,2),[first]=rangeBoundaryEdges([point],()=>2);
  assert.deepEqual(first.from,{x:at.x,y:at.y-TILE_HALF_HEIGHT});
  assert.ok(rangeBoundaryPath([point],()=>2).startsWith(`M${first.from.x} ${first.from.y}`));
  assert.equal(rangeBoundaryPath([]),'');
});

test('interception timing consumes the same fraction of flight, without shifting simultaneous release',()=>{
  const release=PHASE_MS.cast+CAST_ANTICIPATION_MS;
  assert.equal(projectileMeetingMs(.5),release+PROJECTILE_FLIGHT_MS/2);
  assert.equal(projectileMeetingMs(.25),release+PROJECTILE_FLIGHT_MS/4);
  assert.equal(projectileMeetingMs(1),PHASE_MS.impact);
  assert.equal(projectileMeetingMs(-1),release);
});
