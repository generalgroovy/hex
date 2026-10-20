import assert from 'node:assert/strict';
import test from 'node:test';
import { generateArena, normalizeArenaMapId, arenaSeed, ARENA_STARTS } from '../lib/arena.ts';
import { chooseAIPlan, createSimGame, getCell, movementCost, resolveRound, restoreSimState, type SimCell, type SimState } from '../lib/tactics.ts';
const key=(q:number,r:number)=>`${q||0},${r||0}`;
const dirs=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
const empty={orders:[]};
function costs(state:SimState,start:SimCell){const cells=new Map(state.cells.map(c=>[key(c.q,c.r),c]));const found=new Map([[key(start.q,start.r),0]]);const queue=[{cell:start,cost:0}];while(queue.length){queue.sort((a,b)=>a.cost-b.cost);const current=queue.shift()!;for(const dir of dirs){const cell=cells.get(key(current.cell.q+dir.q,current.cell.r+dir.r));if(!cell)continue;const cost=current.cost+movementCost(current.cell,cell);if(cost>6||cost>=(found.get(key(cell.q,cell.r))??Infinity))continue;found.set(key(cell.q,cell.r),cost);queue.push({cell,cost});}}return found;}

test('seed parsing is strict, canonical and replayable without retaining presentation whitespace',()=>{
 assert.equal(normalizeArenaMapId(' confluence '),'reach:WELLSPRING');assert.equal(normalizeArenaMapId(' Reach:river-42 '),'reach:RIVER-42');assert.equal(arenaSeed('reach:river-42'),'RIVER-42');
 for(const invalid of [undefined,null,42,{},'', 'river-42','reach:','reach:A B','reach:ä','reach:<tag>','reach:'+'A'.repeat(25),'reach:../../x'])assert.throws(()=>normalizeArenaMapId(invalid));
 assert.deepEqual(generateArena('confluence'),generateArena('reach:WELLSPRING'));assert.equal(createSimGame().mapId,'reach:WELLSPRING');assert.equal(createSimGame(undefined,' reach:river-42 ').mapId,'reach:RIVER-42');
});

test('200 seeds yield deterministic varied symmetric connected terrain with safe two-move objectives',()=>{
 const layouts=new Set<string>();const wellLayouts=new Set<string>();let firstLayout='';
 for(let index=0;index<200;index++){
  const id=`reach:REPLAY-${index}`;const state=createSimGame(undefined,id);if(index===0)firstLayout=JSON.stringify(state.cells);const cells=new Map(state.cells.map(c=>[key(c.q,c.r),c]));assert.equal(cells.size,127);assert.equal(state.cells.filter(c=>c.height).length,12);assert.equal(state.cells.filter(c=>c.terrain==='earth').length,12);assert.equal(state.cells.filter(c=>c.terrain==='water').length,12);
  const wells=state.cells.filter(c=>c.well);assert.equal(wells.length,3);assert.ok(getCell(state,0,0)!.well);
  for(const cell of state.cells){const mirror=cells.get(key(-cell.q,-cell.r))!;assert.ok(mirror);assert.equal(mirror.height,cell.height);assert.equal(mirror.terrain,cell.terrain);assert.equal(mirror.well,cell.well);if(cell.well)assert.equal(cell.terrain,'plain');}
  for(const start of ARENA_STARTS.flat()){const initial=cells.get(key(start.q,start.r))!;assert.equal(initial.terrain,'plain');assert.equal(initial.height,0);const reachable=costs(state,initial);assert.ok(wells.every(w=>(reachable.get(key(w.q,w.r))??Infinity)>3),`${id}: opening well is too close`);assert.ok(wells.some(w=>(reachable.get(key(w.q,w.r))??Infinity)<=6),`${id}: no well in two movement budgets`);}
  // Natural terrain never blocks access; graph traversal also detects disconnected/missing cells.
  const visited=new Set(['0,0']);const queue=[getCell(state,0,0)!];for(let i=0;i<queue.length;i++)for(const d of dirs){const k=key(queue[i].q+d.q,queue[i].r+d.r);const cell=cells.get(k);if(cell&&!visited.has(k)){visited.add(k);queue.push(cell);}}assert.equal(visited.size,127);
  assert.deepEqual(restoreSimState(state),state);layouts.add(JSON.stringify(state.cells));wellLayouts.add(JSON.stringify(wells.map(c=>[c.q,c.r])));
 }
 assert.ok(layouts.size>=190,`only ${layouts.size} distinct layouts`);assert.equal(wellLayouts.size,4);
 // Cache capacity was exceeded, so replay checks regeneration rather than only a cached object.
 assert.equal(JSON.stringify(generateArena('reach:REPLAY-0')),firstLayout);
});

test('saved seeded geometry cannot silently change seed or omit its base substrate after expiry',()=>{
 const state=createSimGame(undefined,'reach:RIVER-42');const unit=state.units[0];unit.loadout=['ember','water_jet','stone','mend'];const water=state.cells.find(c=>c.terrain==='water')!;
 const origin=state.cells.find(c=>Math.max(Math.abs(c.q-water.q),Math.abs(c.r-water.r),Math.abs(c.q+c.r-water.q-water.r))===1&&!state.units.slice(1).some(u=>u.q===c.q&&u.r===c.r))!;unit.q=origin.q;unit.r=origin.r;
 const heated=resolveRound(state,[{orders:[{unitId:unit.id,spellId:'ember',cast:{q:water.q,r:water.r}}]},empty]);assert.equal(getCell(heated,water.q,water.r)!.terrain,'steam');assert.deepEqual(restoreSimState(heated),heated);
 const faded=resolveRound(heated,[empty,empty]);assert.equal(getCell(faded,water.q,water.r)!.terrain,'water');assert.deepEqual(restoreSimState(faded),faded);
 const tampered=structuredClone(faded);tampered.mapId='reach:ASH-91';assert.throws(()=>restoreSimState(tampered));const alias=structuredClone(faded);alias.mapId='reach:river-42';assert.throws(()=>restoreSimState(alias));
});

test('same canonical seed and sealed plans replay exactly, including regenerated terrain chemistry',()=>{
 for(const seed of ['RIVER-42','ASH-91','REPLAY-199']){let first=createSimGame(undefined,`reach:${seed}`);let second=createSimGame(undefined,`reach:${seed.toLowerCase()}`);for(let i=0;i<4&&first.winner===null;i++){const plans=[chooseAIPlan(first,0),chooseAIPlan(first,1)] as Parameters<typeof resolveRound>[1];first=resolveRound(first,plans);second=resolveRound(second,structuredClone(plans));assert.deepEqual(second,first);assert.deepEqual(restoreSimState(first),first);}}
});
