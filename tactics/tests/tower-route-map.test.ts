import test from 'node:test';
import assert from 'node:assert/strict';
import {towerRouteGraph,reachableTowerRooms} from '../lib/tower-route-map.ts';
import {createTowerRun,towerRoomChoices,towerFloorRooms,chooseTowerRoom,validateTowerRun,type TowerRun} from '../lib/tower-v23.ts';

test('seeded hex paths have real forks, no dead ends, and a shared middle rendezvous',()=>{
 for(let seed=0;seed<40;seed++){
  const graph=towerRouteGraph(`PATH${seed}`);assert.equal(graph.length,25);assert.deepEqual(graph,towerRouteGraph(`PATH${seed}`));
  for(const node of graph){assert.equal(node.next.length,node.floor===9?0:node.floor===8?1:2);for(const id of node.next){const next=graph.find(entry=>entry.id===id)!;assert.equal(next.floor,node.floor+1);assert.ok(node.floor===8||Math.abs(node.lane-next.lane)<=1);}if(node.floor<8)assert.ok(node.next.includes(`floor-${node.floor+1}-1`));}
  for(const node of graph.filter(node=>node.floor>1))assert.ok(graph.some(previous=>previous.next.includes(node.id)));
 }
 assert.notDeepEqual(towerRouteGraph('PATH0'),towerRouteGraph('PATH1'));
});
test('the displayed reachable doors are the only doors the game accepts',()=>{
 const initial=createTowerRun('ROUTE-CHOICES','steam');const first=towerFloorRooms(initial)[0];
 const run={...initial,floor:2,history:[first]} as TowerRun;assert.doesNotThrow(()=>validateTowerRun(run));
 assert.deepEqual(towerRoomChoices(run).map(room=>room.id),['floor-2-0','floor-2-1']);
 assert.throws(()=>chooseTowerRoom(run,'floor-2-2'),/available rooms/);
 assert.equal(chooseTowerRoom(run,'floor-2-1').currentRoom?.id,'floor-2-1');
 assert.deepEqual(reachableTowerRooms(run.seed,2,run.history),towerRoomChoices(run).map(room=>room.id));
});
test('legacy arbitrary room histories remain readable and take connected paths from their last stop',()=>{
 const initial=createTowerRun('LEGACY-PATH','steam');
 const history=[towerFloorRooms(initial)[0],towerFloorRooms({...initial,floor:2})[2]];
 const oldRun={...initial,floor:3,history} as TowerRun;const restored=validateTowerRun(oldRun);
 assert.deepEqual(restored.history.map(room=>room.id),['floor-1-0','floor-2-2']);
 assert.deepEqual(towerRoomChoices(restored).map(room=>room.id),['floor-3-1','floor-3-2']);
 // An already-entered old encounter must not be invalidated by the new graph.
 const entered={...oldRun,phase:'reward',currentRoom:towerFloorRooms(oldRun)[0]};
 assert.doesNotThrow(()=>validateTowerRun(entered));
});
