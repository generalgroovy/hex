import test from 'node:test';
import assert from 'node:assert/strict';
import {generateArena,arenaStarts,arenaRadius,arenaSize,normalizeArenaMapId,type PlayerCount} from '../lib/arena-v17.ts';
import {distance,type Point} from '../lib/game.ts';
import {formatTile,parseTile} from '../lib/board-labels-v17.ts';
const dirs=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
const key=(p:Point)=>`${p.q||0},${p.r||0}`;
test('320 seeded arenas keep each company connected, separated and on equal-cost approaches',()=>{
  for(const count of [2,3,4,5,6] as PlayerCount[]){
    const layouts=new Set<string>();
    for(let seed=0;seed<64;seed++){
      const mapId=normalizeArenaMapId(`audit-${seed}`,count),cells=generateArena(mapId),starts=arenaStarts(mapId),byKey=new Map(cells.map(c=>[key(c),c]));
      assert.equal(cells.length,arenaSize(mapId));assert.equal(cells.length,1+3*(count+7)*(count+8));assert.equal(byKey.size,cells.length);
      assert.equal(new Set(starts.flat().map(key)).size,count*3);
      assert.equal(cells.filter(c=>c.well).length,count+1);
      for(const biome of ['plain','earth','water','forest','marsh','ruins'])assert.ok(cells.some(c=>c.biome===biome),`${mapId}: ${biome}`);
      // Dijkstra uses the same base movement costs as combat, but independent traversal.
      const costs=new Map([['0,0',0]]),queue=[{q:0,r:0,cost:0}];
      while(queue.length){queue.sort((a,b)=>a.cost-b.cost);const p=queue.shift()!;if(costs.get(key(p))!==p.cost)continue;
        for(const d of dirs){const next=byKey.get(key({q:p.q+d.q,r:p.r+d.r})),from=byKey.get(key(p))!;if(!next||next.biome==='ruins')continue;
          const cost=p.cost+(next.biome==='marsh'||next.height>from.height?2:1);if(cost>=(costs.get(key(next))??Infinity))continue;costs.set(key(next),cost);queue.push({...next,cost});
        }
      }
      assert.equal(costs.size,cells.filter(c=>c.biome!=='ruins').length,`${mapId}: disconnected`);
      for(const [seat,company] of starts.entries())for(const start of company){
        assert.equal(byKey.get(key(start))!.biome,'plain');assert.equal(distance(start,{q:0,r:0}),arenaRadius(mapId)-3);assert.equal(costs.get(key(start)),arenaRadius(mapId)-3);
        for(const [other,rivals] of starts.entries())if(other!==seat)assert.ok(rivals.every(rival=>distance(start,rival)>=4),`${mapId}: overlapping sectors`);
      }
      layouts.add(JSON.stringify(cells));assert.ok(Object.isFrozen(cells));assert.ok(cells.every(Object.isFrozen));
    }
    assert.equal(layouts.size,64);
    const original=JSON.stringify(generateArena(`arena:${count}:AUDIT-0`));generateArena(`arena:${count}:OTHER`);assert.equal(JSON.stringify(generateArena(`arena:${count}:AUDIT-0`)),original);
  }
});
test('seed normalization preserves player count and rejects malformed or mixed map configurations',()=>{
  assert.equal(normalizeArenaMapId(' frontier:river-42 ',6),'arena:6:RIVER-42');assert.equal(normalizeArenaMapId('arena:5:fen'),'arena:5:FEN');
  for(const input of [null,42,'','../x','arena:7:A','a b','A'.repeat(25)])assert.throws(()=>normalizeArenaMapId(input));
  assert.throws(()=>normalizeArenaMapId('arena:6:FEN',4));
});
test('every 2–6 player battlefield cell has a unique human label, including AA on the largest map',()=>{
  for(const count of [2,3,4,5,6]){
    const id=`arena:${count}:LABELS`,radius=arenaRadius(id),cells=generateArena(id),labels=cells.map(cell=>formatTile(cell,radius));
    assert.equal(new Set(labels).size,cells.length);assert.ok(!labels.includes('—'));
    cells.forEach((cell,index)=>assert.deepEqual(parseTile(labels[index],radius),{q:cell.q,r:cell.r}));
    assert.equal(parseTile('ZZ99',radius),null);
  }
});
