import assert from 'node:assert/strict';
import test from 'node:test';
import {generateArena,normalizeArenaMapId,arenaSeed,ARENA_STARTS,ARENA_RADIUS,baseTerrainAt,arenaBiomeAt,type ArenaCell} from '../lib/arena-v7.ts';
import {generateArena as legacyArena} from '../lib/arena.ts';
const key=({q,r}:{q:number;r:number})=>`${q||0},${r||0}`;
const dirs=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
function costs(cells:ReadonlyArray<Readonly<ArenaCell>>,start:{q:number;r:number}){
 const byKey=new Map(cells.map(c=>[key(c),c])),found=new Map([[key(start),0]]),queue=[{cell:byKey.get(key(start))!,cost:0}];
 while(queue.length){queue.sort((a,b)=>a.cost-b.cost);const current=queue.shift()!;if(found.get(key(current.cell))!==current.cost)continue;for(const d of dirs){const cell=byKey.get(key({q:current.cell.q+d.q,r:current.cell.r+d.r}));if(!cell||cell.biome==='ruins')continue;const cost=current.cost+(cell.biome==='marsh'||cell.height>current.cell.height?2:1);if(cost>=(found.get(key(cell))??Infinity))continue;found.set(key(cell),cost);queue.push({cell,cost});}}
 return found;
}
test('v7 seed aliases are explicit and do not change frozen v6 geography',()=>{
 assert.equal(ARENA_RADIUS,9);assert.equal(normalizeArenaMapId(' confluence '),'frontier:WELLSPRING');assert.equal(normalizeArenaMapId(' reach:river-42 '),'frontier:RIVER-42');assert.equal(arenaSeed('frontier:river-42'),'RIVER-42');
 for(const value of [undefined,null,{},42,'','river','frontier:','frontier:A B','frontier:ä','frontier:../x','frontier:'+'A'.repeat(25)])assert.throws(()=>normalizeArenaMapId(value));
 assert.equal(legacyArena().length,127);assert.equal(generateArena().length,271);assert.deepEqual(generateArena('reach:RIVER-42'),generateArena('frontier:RIVER-42'));
});
test('256 v7 seeds have mirrored travel costs, five accessible wells and no isolated walkable cells',()=>{
 const layouts=new Set<string>();let first='';
 for(let n=0;n<256;n++){
  const id=`frontier:AUDIT-${n}`,cells=generateArena(id),map=new Map(cells.map(c=>[key(c),c])),wells=cells.filter(c=>c.well);if(n===0)first=JSON.stringify(cells);
  assert.equal(map.size,271);assert.equal(wells.length,5);assert.ok(map.get('0,0')!.well);assert.ok(Object.isFrozen(cells));
  for(const cell of cells){assert.ok(Object.isFrozen(cell));const mirror=map.get(key({q:-cell.q,r:-cell.r}))!;assert.equal(mirror.biome,cell.biome);assert.equal(mirror.height,cell.height);assert.equal(mirror.well,cell.well);assert.equal(baseTerrainAt(cell.q,cell.r,id),cell.terrain);assert.equal(arenaBiomeAt(cell.q,cell.r,id),cell.biome);if(cell.well){assert.equal(cell.biome,'plain');assert.equal(cell.height,0);for(const d of dirs)assert.notEqual(map.get(key({q:cell.q+d.q,r:cell.r+d.r}))?.biome,'ruins');}}
  for(const biome of ['earth','water','forest','marsh','ruins'])assert.ok(cells.some(c=>c.biome===biome),`${id}: missing ${biome}`);
  for(let i=0;i<3;i++){
   const a=ARENA_STARTS[0][i],b=ARENA_STARTS[1][i],left=costs(cells,a),right=costs(cells,b);assert.equal(map.get(key(a))!.biome,'plain');assert.equal(left.size,cells.filter(c=>c.biome!=='ruins').length);
   for(const well of wells){assert.ok(left.has(key(well)),`${id}: unreachable well`);assert.equal(left.get(key(well)),right.get(key({q:-well.q,r:-well.r})),`${id}: unfair mirrored effort`);}
   const nearest=Math.min(...wells.map(w=>left.get(key(w))!));assert.ok(nearest>=4,`${id}: first objective needs at least four movement effort`);assert.ok(nearest<=9,`${id}: first objective exceeds nine movement effort`);
  }
  layouts.add(JSON.stringify(cells));
 }
 assert.equal(layouts.size,256);assert.equal(JSON.stringify(generateArena('frontier:AUDIT-0')),first,'seed regenerates exactly after cache eviction');
});
