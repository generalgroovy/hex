import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {towerRouteParty} from '../lib/tower-route-party-v43.ts';
import {createTowerRun,createTowerSession,chooseTowerRoom,towerFloorRooms,validateTowerStarter,type TowerRun} from '../lib/tower-v23.ts';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom,type TowerRoomSnapshot,type TowerPlayerSummary} from '../lib/tower-rooms-v23.ts';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';

function fixture(run=createTowerRun('PARTY-43','steam',3)):TowerRoomSnapshot {
 const players:TowerPlayerSummary[]=Array.from({length:3},(_,seat)=>({seat,name:['You','Ash','Bram'][seat],start:run.starts[0],ready:true,alive:true,floor:run.floor,phase:'route',party:run.party,currentRoomName:null,round:null}));
 return {protocolVersion:23,code:'ABCDEFGHJKLM',version:0,runId:'party-run',stepId:'party-step',yourSeat:0,hostSeat:0,capacity:6,seed:run.seed,status:'active',sharedFloor:run.floor,waitingFor:[0,1,2],canEnter:true,players,session:createTowerSession(run),scoutReports:[],gathering:{choiceId:null,choices:[],waitingFor:[0,1,2]},sharedBattle:null,watch:null,expiresAt:1800000000000};
}
const select=(snapshot:TowerRoomSnapshot,seat:number,choiceId:string)=>{snapshot.gathering!.choices.push({seat,name:snapshot.players[seat]!.name,choiceId});snapshot.gathering!.waitingFor=snapshot.gathering!.waitingFor.filter(value=>value!==seat);if(seat===snapshot.yourSeat){snapshot.gathering!.choiceId=choiceId;snapshot.canEnter=false;}};

test('a selected destination can be replaced directly by joining a reachable friend',()=>{
 const snapshot=fixture();select(snapshot,0,'floor-1-0');select(snapshot,1,'floor-1-1');
 const before=JSON.stringify(snapshot),model=towerRouteParty(snapshot),friend=model.friends.find(friend=>friend.seat===1)!;
 assert.equal(snapshot.canEnter,false);assert.deepEqual(friend.action,{kind:'join',roomId:'floor-1-1'});assert.equal(friend.withYou,false);
 assert.deepEqual(model.roomPlayers['floor-1-0'],[{seat:0,name:'You',you:true}]);assert.deepEqual(model.roomPlayers['floor-1-1'],[{seat:1,name:'Ash',you:false}]);
 assert.deepEqual(model.choosingSeats,[2]);assert.equal(JSON.stringify(snapshot),before);
 snapshot.gathering!.choiceId='floor-1-1';snapshot.gathering!.choices[0].choiceId='floor-1-1';
 const together=towerRouteParty(snapshot).friends.find(friend=>friend.seat===1)!;
 assert.equal(together.withYou,true);assert.deepEqual(together.action,{kind:'preview',roomId:'floor-1-1'});assert.equal(together.reason,'already-together');
});

test('unreachable selected destinations are previews, never join commands',()=>{
 const initial=createTowerRun('PARTY-PATHS','steam',3),run={...initial,floor:2,history:[towerFloorRooms(initial)[0]]};
 const snapshot=fixture(run);select(snapshot,1,'floor-2-4');
 const model=towerRouteParty(snapshot),friend=model.friends[0];
 assert.deepEqual(friend.action,{kind:'preview',roomId:'floor-2-4'});assert.equal(friend.reason,'different-path');assert.equal(model.encounterCounts['floor-2-4'],undefined);
 snapshot.players[0]!.phase='barrier';snapshot.session!.run.floor=3;
 const locked=towerRouteParty(snapshot).friends[0];assert.deepEqual(locked.action,{kind:'preview',roomId:'floor-2-4'});assert.equal(locked.reason,'floor-locked');
});

test('active fights can be watched, and repeated room names never invent a map destination',()=>{
 const run=chooseTowerRoom(createTowerRun('PARTY-BATTLES','steam',3),'floor-1-0'),snapshot=fixture();
 snapshot.session=createTowerSession(run);snapshot.players[0]!.phase='battle';snapshot.players[1]!.phase='battle';snapshot.players[1]!.currentRoomName=run.currentRoom!.name;snapshot.gathering=null;snapshot.canEnter=false;
 const model=towerRouteParty(snapshot),friend=model.friends[0];
 assert.equal(friend.roomName,run.currentRoom!.name);assert.equal(friend.roomId,null);assert.equal(friend.withYou,false);assert.deepEqual(friend.action,{kind:'watch',seat:1});
 assert.deepEqual(model.roomPlayers[run.currentRoom!.id].map(person=>person.seat),[0]);
 const watched=chooseTowerRoom(createTowerRun('PARTY-BATTLES','steam',3),'floor-1-2');snapshot.watch={seat:1,session:createTowerSession(watched)};
 assert.equal(towerRouteParty(snapshot).friends[0].roomId,'floor-1-2');
 snapshot.watch=null;snapshot.sharedBattle={id:'group',seats:[0,1],readySeats:[],ownReady:false,controlledActorIds:[],teammatePlan:{orders:[]}};
 const shared=towerRouteParty(snapshot);assert.equal(shared.friends[0].roomId,'floor-1-0');assert.equal(shared.friends[0].withYou,true);
 assert.deepEqual(shared.roomPlayers['floor-1-0'].map(person=>person.seat),[0,1]);
});

test('barrier, retired and choosing friends have clear non-join states',()=>{
 const snapshot=fixture();snapshot.players[1]!.phase='barrier';snapshot.players[1]!.floor=2;snapshot.players[2]!.phase='retired';snapshot.players[2]!.alive=false;
 select(snapshot,2,'floor-1-2');const model=towerRouteParty(snapshot);
 assert.equal(model.friends[0].phase,'barrier');assert.equal(model.friends[0].action,null);assert.equal(model.friends[1].phase,'retired');assert.equal(model.friends[1].action,null);
 assert.equal(model.roomPlayers['floor-1-2'],undefined);assert.deepEqual(model.choosingSeats,[0]);
});

test('projected enemy counts sum exact mixed starting bands rather than multiplying our encounter',()=>{
 const snapshot=fixture();snapshot.players[1]!.start=validateTowerStarter({starterId:'steam',members:[{kind:'creature',creatureId:'creature-fire-cinder'},{kind:'creature',creatureId:'creature-water-puddle'}]});
 select(snapshot,1,'floor-1-0');const model=towerRouteParty(snapshot);
 assert.equal(towerFloorRooms(snapshot.session!.run)[0].enemies.length,2);assert.equal(model.encounterCounts['floor-1-0'],3,'Our two enemies plus one enemy from the creature-only squad');
 assert.equal(model.encounterCounts['floor-1-2'],2,'An unchosen room includes only our own encounter');
 const initial=snapshot.session!.run,history=[towerFloorRooms(initial)[0],towerFloorRooms({...initial,floor:2})[0]];
 const rest=fixture({...initial,floor:3,history});select(rest,1,'floor-3-0');assert.ok(Object.values(towerRouteParty(rest).encounterCounts).every(count=>count===0));
});


test('stale gathering data cannot claim togetherness or a join after our route phase closes',()=>{
 const snapshot=fixture();select(snapshot,0,'floor-1-1');select(snapshot,1,'floor-1-1');
 snapshot.players[0]!.phase='battle';snapshot.session!.run.phase='battle';
 const model=towerRouteParty(snapshot),friend=model.friends[0];
 assert.equal(model.ownChoiceId,null);assert.equal(friend.withYou,false);assert.equal(friend.action?.kind,'preview');assert.equal(friend.reason,'floor-locked');
 snapshot.players[0]!.phase='route';snapshot.session!.run.phase='route';snapshot.gathering!.choiceId='floor-1-99';
 assert.equal(towerRouteParty(snapshot).ownChoiceId,null,'An unknown choice ID is never presented as committed');
});

const NOW=1800000000000,keys=['1','2','3'].map(value=>value.repeat(64));
function database(){
 const sql=new DatabaseSync(':memory:');for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));
 const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null},async run(){return sql.prepare(text).run(...values)}};return statement}} as unknown as RoomDatabase;return {db,sql};
}
const read=(db:RoomDatabase,code:string,seat:number)=>getTowerRoom(db,code,keys[seat],NOW+100).then(reply=>reply.room);
async function action(db:RoomDatabase,code:string,seat:number,action:string,fields:Record<string,unknown>={}){
 const room=await read(db,code,seat);return (await actTowerRoom(db,code,keys[seat],{action,runId:room.runId,stepId:room.stepId,requestId:crypto.randomUUID(),...fields},NOW+100)).room;
}

test('real service replaces an existing choice to join a friend, then refuses joining after launch',async()=>{
 const {db,sql}=database();try{
  const host=await createTowerRoom(db,{name:'You',starter:'steam',seed:'JOIN-PARTY-43',capacity:3,clientToken:keys[0]},NOW);
  for(let seat=1;seat<3;seat++)await joinTowerRoom(db,host.code,{name:['','Ash','Bram'][seat],starter:'steam',clientToken:keys[seat]},NOW+seat);
  for(let seat=0;seat<3;seat++)await action(db,host.code,seat,'ready',{ready:true});await action(db,host.code,0,'start');
  await action(db,host.code,0,'choose',{choiceId:'floor-1-0'});await action(db,host.code,1,'choose',{choiceId:'floor-1-1'});
  const before=await read(db,host.code,0),join=towerRouteParty(before).friends.find(friend=>friend.seat===1)!.action!;assert.equal(join.kind,'join');
  const changed=await action(db,host.code,0,'choose',{choiceId:'roomId' in join?join.roomId:''});assert.equal(changed.gathering!.choiceId,'floor-1-1');assert.equal(changed.session!.run.phase,'route');
  await action(db,host.code,2,'choose',{choiceId:'floor-1-2'});const entered=await read(db,host.code,0);
  await assert.rejects(actTowerRoom(db,host.code,keys[0],{action:'choose',runId:changed.runId,stepId:changed.stepId,requestId:crypto.randomUUID(),choiceId:'floor-1-2'},NOW+100),error=>error instanceof RoomError&&error.code==='STALE_STEP');
  assert.deepEqual(entered.sharedBattle!.seats,[0,1]);assert.equal(entered.session!.run.currentRoom!.id,'floor-1-1');assert.equal(entered.session!.run.phase,'battle');
  assert.equal(towerRouteParty(entered).friends.find(friend=>friend.seat===1)!.action!.kind,'watch');
  await assert.rejects(action(db,host.code,0,'choose',{choiceId:'floor-1-2'}),error=>error instanceof RoomError&&error.code==='INVALID_CHOICE');
  assert.deepEqual((await read(db,host.code,0)).sharedBattle!.seats,[0,1]);
 }finally{sql.close();}
});



test('joining an event requires the actual first fighter to have three HP, including creature-first squads',()=>{
 const standard=validateTowerStarter('steam'),reversed={starterId:standard.starterId,members:[standard.members[1],standard.members[0]]};
 for(const start of [standard,reversed]){
  const initial=createTowerRun('TUITION-PARTY-43',start as typeof standard,3),history=[towerFloorRooms(initial)[0],towerFloorRooms({...initial,floor:2})[0]];
  const run={...initial,floor:3,history};run.party[0].hp=2;
  const snapshot=fixture(run);select(snapshot,1,'floor-3-2');
  const blocked=towerRouteParty(snapshot).friends[0];assert.deepEqual(blocked.action,{kind:'preview',roomId:'floor-3-2'});assert.equal(blocked.reason,'low-health');
  assert.throws(()=>chooseTowerRoom(snapshot.session!.run,'floor-3-2'),/at least 3 health/);
  snapshot.session!.run.party[0].hp=3;
  const allowed=towerRouteParty(snapshot).friends[0];assert.deepEqual(allowed.action,{kind:'join',roomId:'floor-3-2'});assert.equal(allowed.reason,undefined);
  assert.equal(chooseTowerRoom(snapshot.session!.run,'floor-3-2').party[0].hp,1);
 }
});
