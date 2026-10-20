import assert from 'node:assert/strict';
import test from 'node:test';
import {battlefieldMotion,UNIT_MOTION_MS} from '../lib/battlefield-motion-v9.ts';
import {createSimGame,movementPath,resolveRound,getCell,type Point} from '../lib/tactics-v9.ts';
import {surfacePoint} from '../lib/battlefield-geometry.ts';
const xy=({q,r}:Point)=>({q,r});
const arena=()=>{
  const state=createSimGame();
  state.cells.forEach(cell=>Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false}));
  Object.assign(state.units[0],{q:0,r:0});return state;
};

test('movement keyframes follow the resolver path around an obstacle and retain elevation',()=>{
  const before=arena(),unit=before.units[0];
  getCell(before,1,0)!.biome='ruins';getCell(before,2,-1)!.height=1;
  const target={q:2,r:0},route=movementPath(before,unit.id,target)!;
  assert.ok(route.length>2);assert.ok(!route.some(cell=>cell.q===1&&cell.r===0));
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:target}]},{orders:[]}]);
  const motion=battlefieldMotion(before,after,unit.id,'test')!;
  assert.deepEqual(motion.movePath,route.map(xy));
  assert.deepEqual(motion.frames.filter(frame=>frame.phase==='move').map(frame=>frame.point),[xy(unit),...route.map(xy)]);
  const final=surfacePoint(target,getCell(after,target.q,target.r)!.height);
  for(const frame of motion.frames.filter(frame=>frame.phase==='move')){
    const actual=surfacePoint(frame.point,getCell(before,frame.point.q,frame.point.r)!.height);
    assert.equal(frame.x,actual.x-final.x);assert.equal(frame.y,actual.y-final.y);
  }
  assert.equal(motion.frames.find(frame=>frame.atMs===450)?.point.q,target.q);
  assert.deepEqual(motion.frames.find(frame=>frame.atMs===900)?.point,target);
  assert.deepEqual(motion.frames.at(-1),{atMs:UNIT_MOTION_MS,point:target,x:0,y:0,phase:'hold'});
});

test('an ice slide visits every crossed hex using the old field even after it melts',()=>{
  const before=arena(),unit=before.units[0];
  for(let q=1;q<=5;q++)Object.assign(getCell(before,q,0)!,{terrain:'water',elements:['water'],ice:true,ttl:1});
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:5,r:0}}]},{orders:[]}]);
  assert.ok(!getCell(after,3,0)!.ice,'the old ice really expired');
  const motion=battlefieldMotion(before,after,unit.id)!;
  assert.deepEqual(motion.movePath,[1,2,3,4,5].map(q=>({q,r:0})));
  assert.deepEqual(motion.frames.filter(frame=>frame.phase==='move').map(frame=>frame.atMs),[0,90,180,270,360,450]);
  assert.equal(motion.style.animationTimingFunction,'linear','each crossed hex remains an actual waypoint');
  assert.equal((motion.keyframes.match(/animation-timing-function:cubic-bezier/g)||[]).length,2,'ease only at departure and final arrival, never at each icy hex');
  assert.match(motion.keyframes,/0%\{transform:[^}]+cubic-bezier\(\.4,\.08,\.75,\.75\)/);
  assert.match(motion.keyframes,/cubic-bezier\(\.25,\.25,\.6,\.92\)/);
});

test('multiple actual Gale displacements preserve their intermediate hexes after the spell hold',()=>{
  const before=arena(),caster=before.units[0],victim=before.units[3];
  before.round=5; before.version=5; caster.affinities={water:3,fire:2,air:2};
  Object.assign(victim,{q:2,r:0,loadout:['mend','ember','water_jet','gust']});caster.loadout=['gale','ember','water_jet','mend'];
  const after=resolveRound(before,[{orders:[{unitId:caster.id,spellId:'gale',cast:xy(victim)}]},{orders:[{unitId:victim.id,spellId:'mend',cast:xy(victim)}]}]);
  assert.equal(after.lastResolution.filter(event=>event.kind==='push'&&event.unitId===victim.id).length,2);
  const motion=battlefieldMotion(before,after,victim.id)!;
  assert.deepEqual(motion.pushPath,[{q:3,r:0},{q:4,r:0}]);
  assert.deepEqual(motion.frames.filter(frame=>frame.phase==='push').map(frame=>frame.atMs),[1150,1400]);
  assert.deepEqual(motion.frames.find(frame=>frame.atMs===900)?.point,{q:2,r:0});
  assert.equal(motion.frames.at(-1)!.x,0);assert.equal(motion.frames.at(-1)!.y,0);
});

test('a forced slide expands its successful endpoint event into all crossed ice hexes',()=>{
  const before=arena(),caster=before.units[0],victim=before.units[3];
  Object.assign(victim,{q:2,r:0,loadout:['mend','ember','water_jet','gust']});caster.loadout=['gust','ember','water_jet','mend'];
  for(let q=3;q<=6;q++)Object.assign(getCell(before,q,0)!,{terrain:'water',elements:['water'],ice:true,ttl:1});
  const after=resolveRound(before,[{orders:[{unitId:caster.id,spellId:'gust',cast:xy(victim)}]},{orders:[{unitId:victim.id,spellId:'mend',cast:xy(victim)}]}]);
  const motion=battlefieldMotion(before,after,victim.id)!;
  assert.deepEqual(motion.pushPath,[3,4,5,6].map(q=>({q,r:0})));
  assert.equal(motion.frames.filter(frame=>frame.phase==='push').length,4);
});

test('no invented route for blocked moves or missing snapshots; generated CSS is deterministic and isolated',()=>{
  const before=arena(),unit=before.units[0];
  Object.assign(before.units[1],{q:1,r:0});
  const blocked=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:1,r:0}}]},{orders:[]}]);
  assert.ok(blocked.lastResolution.some(event=>event.kind==='bounce'));
  assert.equal(battlefieldMotion(before,blocked,unit.id),null);
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:0,r:1}}]},{orders:[]}]);
  const frozen=JSON.stringify([before,after]);
  assert.equal(battlefieldMotion(undefined,after,unit.id),null);
  assert.equal(battlefieldMotion({...before,version:before.version-1},after,unit.id),null,'an older planning snapshot cannot reconstruct a later icy route');
  const first=battlefieldMotion(before,after,unit.id,':board-a:')!,second=battlefieldMotion(before,after,unit.id,':board-a:')!,other=battlefieldMotion(before,after,unit.id,':board-b:')!;
  assert.equal(first.keyframes,second.keyframes);assert.notEqual(first.animationName,other.animationName);
  assert.match(first.animationName,/^[a-zA-Z][a-zA-Z0-9_-]*$/);
  assert.ok(first.keyframes.endsWith('100%{transform:translate(0px,0px)}}'));
  assert.equal(JSON.stringify([before,after]),frozen,'presentation cannot mutate match state');
});
