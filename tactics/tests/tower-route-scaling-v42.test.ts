import test from 'node:test';
import assert from 'node:assert/strict';
import {towerBranchCount,towerRouteGraph,reachableTowerRooms} from '../lib/tower-route-map.ts';
import {createTowerRun,towerFloorRooms,towerRoomChoices,chooseTowerRoom,validateTowerRun,createTowerSession,restoreTowerSession,type TowerRun} from '../lib/tower-v23.ts';
import {scoutTowerRoom,towerScoutReports,towerScoutsAvailable} from '../lib/tower-scouting-actions.ts';

test('one to six launch players receive three to eight seeded branches and one final boss',()=>{
 for(let players=1;players<=6;players++)for(const seed of ['PARALLEL-A','PARALLEL-B','PARALLEL-C']){
  const run=createTowerRun(seed,'steam',players),graph=towerRouteGraph(run.seed,run.routePlayers),width=players+2;
  assert.equal(towerBranchCount(players),width);assert.equal(graph.length,8*width+1);assert.deepEqual(graph,towerRouteGraph(run.seed,players));
  assert.equal(run.routePlayers,players);assert.deepEqual(validateTowerRun(run),run);
  for(let floor=1;floor<=9;floor++){
   const rooms=towerFloorRooms({...run,floor}),legacy=towerFloorRooms({...run,floor,routePlayers:undefined});
   assert.equal(rooms.length,floor===9?1:width);assert.equal(new Set(rooms.map(room=>room.id)).size,rooms.length);assert.equal(new Set(rooms.map(room=>room.mapId)).size,rooms.length);
   assert.deepEqual(rooms.slice(0,legacy.length),legacy,'The original three room identities and contents stay intact');
   assert.deepEqual(graph.filter(node=>node.floor===floor).map(node=>node.id),rooms.map(room=>room.id));
  }
 }
});

test('wide paths retain real forks, every branch remains reachable, and split squads can rejoin each depth',()=>{
 for(let players=2;players<=6;players++)for(let seed=0;seed<20;seed++){
  const graph=towerRouteGraph(`MERGE-${seed}`,players);
  for(const node of graph){
   assert.equal(node.next.length,node.floor===9?0:node.floor===8?1:3);
   assert.equal(new Set(node.next).size,node.next.length);
   for(const id of node.next)assert.equal(graph.find(next=>next.id===id)?.floor,node.floor+1);
   if(node.floor>1)assert.ok(graph.some(previous=>previous.next.includes(node.id)),`${node.id} cannot be an unreachable decorative room`);
  }
  for(let floor=1;floor<9;floor++){
   const previous=graph.filter(node=>node.floor===floor),shared=previous[0].next.filter(id=>previous.every(node=>node.next.includes(id)));
   assert.ok(shared.length>0,'Every split route has a legal shared destination on the following floor');
  }
 }
});

test('reachable choices, selected high lanes, scouting and restoration use the persisted launch width',()=>{
 for(let players=1;players<=6;players++){
  let run=createTowerRun('SAVE-PARALLEL','steam',players);
  const highest=towerRoomChoices(run).at(-1)!;
  const scouted=scoutTowerRoom(run,'hero',highest.id);assert.equal(towerScoutReports(scouted,highest.id).length,1);assert.equal(towerScoutsAvailable(scouted).length,0);
  const session=createTowerSession(chooseTowerRoom(scouted,highest.id));assert.deepEqual(restoreTowerSession(JSON.parse(JSON.stringify(session))),session);
  assert.equal(session.run.currentRoom!.id,highest.id);assert.equal(session.run.routePlayers,players);
  const history:TowerRun['history']=[];
  for(let floor=1;floor<=9;floor++){
   run=validateTowerRun({...run,floor,history:[...history],scouting:undefined});
   const choices=towerRoomChoices(run);assert.deepEqual(choices.map(room=>room.id),reachableTowerRooms(run.seed,floor,history,players));
   assert.equal(choices.length,floor===1?players+2:floor===9?1:players===1?2:3);
   const unreachable=towerFloorRooms(run).find(room=>!choices.some(choice=>choice.id===room.id));if(unreachable)assert.throws(()=>chooseTowerRoom(run,unreachable.id),/available rooms/);
   const room=choices.at(-1)!;assert.equal(chooseTowerRoom(run,room.id).currentRoom!.id,room.id);history.push(room);
  }
 }
});

test('old three-branch runs and pending battles remain unchanged; invalid launch widths are rejected',()=>{
 const legacy=createTowerRun('LEGACY-PARALLEL','steam');delete legacy.routePlayers;
 assert.equal(towerRoomChoices(legacy).length,3);assert.equal(validateTowerRun(legacy).routePlayers,undefined);
 const entered=createTowerSession(chooseTowerRoom(legacy,'floor-1-2'));
 assert.deepEqual(restoreTowerSession(JSON.parse(JSON.stringify(entered))),entered);
 assert.equal(entered.run.routePlayers,undefined);
 for(const width of [0,7,1.5,NaN,Infinity,null,'6']){
  assert.throws(()=>validateTowerRun({...legacy,routePlayers:width}));assert.throws(()=>towerBranchCount(width as number));
 }
 assert.deepEqual(towerRouteGraph('LEGACY-PARALLEL'),towerRouteGraph('LEGACY-PARALLEL',1));
});
