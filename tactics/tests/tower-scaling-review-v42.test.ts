import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom,type TowerRoomSnapshot} from '../lib/tower-rooms-v23.ts';
import {createTowerRun,towerRoomChoices,restoreTowerSession} from '../lib/tower-v23.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';

const NOW=1800000000000,keys=Array.from({length:6},(_,index)=>(index+1).toString().repeat(64));
function database(){
 const sql=new DatabaseSync(':memory:');
 for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));
 const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null},async run(){return sql.prepare(text).run(...values)}};return statement}} as unknown as RoomDatabase;
 return {db,sql};
}
const read=(db:RoomDatabase,code:string,seat:number,now=NOW+100)=>getTowerRoom(db,code,keys[seat],now).then(reply=>reply.room);
const request=(room:TowerRoomSnapshot,action:string,fields:Record<string,unknown>={})=>({action,runId:room.runId,stepId:room.stepId,requestId:crypto.randomUUID(),...fields});
const fault=(code:string)=>(error:unknown)=>error instanceof RoomError&&error.code===code;
async function act(db:RoomDatabase,code:string,seat:number,action:string,fields:Record<string,unknown>={}){
 return (await actTowerRoom(db,code,keys[seat],request(await read(db,code,seat),action,fields),NOW+100)).room;
}
async function start(db:RoomDatabase,count:number){
 const host=await createTowerRoom(db,{name:'Review host',starter:'steam',seed:'SCALING-REVIEW',capacity:6,clientToken:keys[0]},NOW);
 for(let seat=1;seat<count;seat++)await joinTowerRoom(db,host.code,{name:`Reviewer ${seat}`,starter:'steam',clientToken:keys[seat]},NOW+seat);
 for(let seat=0;seat<count;seat++)await act(db,host.code,seat,'ready',{ready:true});
 await act(db,host.code,0,'start');return host.code;
}

test('one through six players retain launch-scaled choices through serialized service sessions, independent of empty lobby seats',async()=>{
 assert.equal(towerRoomChoices(createTowerRun('SCALING-REVIEW')).length,3);
 for(let count=2;count<=6;count++){
  const {db,sql}=database();try{
   const code=await start(db,count);
   for(let seat=0;seat<count;seat++){
    const room=await read(db,code,seat),run=room.session!.run;
    assert.equal(room.capacity,6);
    assert.equal(run.routePlayers,count,'Occupied launch seats, not the six-place capacity, choose route width');
    assert.equal(towerRoomChoices(run).length,count+2);
    const restored=restoreTowerSession(JSON.parse(JSON.stringify(room.session)));
    assert.equal(restored.run.routePlayers,count);
    assert.deepEqual(towerRoomChoices(restored.run),towerRoomChoices(run));
   }
  }finally{sql.close();}
 }
});

test('reconnect, a long polling gap and retirement keep the seeded eight-door route while high doors can launch separate battles',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,6),initial=await read(db,code,0),doors=towerRoomChoices(initial.session!.run),before=JSON.stringify(doors);
  assert.equal(doors.length,8);
  const afterGap=await read(db,code,0,NOW+60*60*1000);
  assert.equal(afterGap.version,initial.version,'A missing poll cannot retire a seat or silently alter the route');
  assert.deepEqual(afterGap.waitingFor,[0,1,2,3,4,5]);
  const returningBefore=JSON.stringify(towerRoomChoices((await read(db,code,5)).session!.run));
  const recovered=await joinTowerRoom(db,code,{name:'Returning player',starter:'stone',clientToken:keys[5]},NOW+100);
  assert.equal(recovered.seat,5);
  assert.equal(JSON.stringify(towerRoomChoices(recovered.room.session!.run)),returningBefore);
  await assert.rejects(joinTowerRoom(db,code,{name:'Late arrival',starter:'steam',clientToken:'a'.repeat(64)},NOW+100),fault('CLIMB_STARTED'));
  for(const seat of [2,3,4,5])await act(db,code,seat,'retire',{confirm:true});
  const remaining=await read(db,code,0);
  assert.deepEqual(remaining.waitingFor,[0,1]);
  assert.equal(remaining.session!.run.routePlayers,6);
  assert.equal(JSON.stringify(towerRoomChoices(remaining.session!.run)),before,'Retirement never deletes high lanes or rerolls their enemies');
  await act(db,code,0,'choose',{choiceId:doors[7].id});
  await act(db,code,1,'choose',{choiceId:doors[6].id});
  const [left,right]=await Promise.all([read(db,code,0),read(db,code,1)]);
  for(const room of [left,right]){
   assert.equal(room.session!.run.phase,'battle');
   assert.equal(room.session!.run.routePlayers,6);
   assert.equal(room.sharedBattle,null,'Different high doors remain separate encounters');
   assert.equal(restoreTowerSession(JSON.parse(JSON.stringify(room.session))).run.routePlayers,6);
  }
  assert.notEqual(left.session!.battle!.tower.id,right.session!.battle!.tower.id);
 }finally{sql.close();}
});

test('six scouts can investigate a new high lane without exposing other doors or spending allies allowances',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,6),before=await Promise.all(keys.map((_,seat)=>read(db,code,seat))),door=towerRoomChoices(before[0].session!.run)[7];
  assert.ok(door.enemies.length);
  assert.ok(before.every(room=>room.scoutReports.length===0));
  const commands=before.map(room=>request(room,'scout',{actorId:'hero',choiceId:door.id}));
  await Promise.all(commands.map((command,seat)=>actTowerRoom(db,code,keys[seat],command,NOW+100)));
  const stored=JSON.parse(String(sql.prepare('SELECT data_json FROM tower_rooms_v23 WHERE code = ?').get(code)!.data_json));
  assert.equal(stored.scoutReports.length,6);
  for(let seat=0;seat<6;seat++){
   const room=await read(db,code,seat),ownDoor=towerRoomChoices(room.session!.run).find(candidate=>candidate.id===door.id)!,facts=new Set(scoutFactsForRoom(room.session!.run,ownDoor).map(fact=>fact.id)),expected=stored.scoutReports.filter((report:{id:string})=>facts.has(report.id));
   assert.deepEqual(room.session!.run.scouting!.usedActorIds,['hero']);
   assert.equal(room.session!.run.scouting!.reports.length,1);
   assert.deepEqual([...room.scoutReports].sort((a,b)=>a.id.localeCompare(b.id)),expected.sort((a:{id:string},b:{id:string})=>a.id.localeCompare(b.id)));assert.ok(room.scoutReports.length>=2);
   assert.equal(new Set(room.scoutReports.map(report=>report.id)).size,expected.length);
   assert.ok(room.scoutReports.every(report=>report.roomId===door.id&&facts.has(report.id)));
   assert.equal(restoreTowerSession(JSON.parse(JSON.stringify(room.session))).run.routePlayers,6);
   // Wire checks cover credentials, private plans and earned report projection.
   // The public deterministic seed is not a cryptographic secret-content boundary.
   const wire=JSON.stringify(room);
   for(const value of [...keys,'"tokenHash"','"enemyPlan"','"receipts"'])assert.ok(!wire.includes(value));
  }
  const snapshot=await read(db,code,0),version=snapshot.version;
  const retry=(await actTowerRoom(db,code,keys[0],commands[0],NOW+100)).room;
  assert.equal(retry.version,version);assert.deepEqual(retry.scoutReports,snapshot.scoutReports);
  await assert.rejects(act(db,code,0,'choose',{choiceId:'floor-1-8'}),fault('INVALID_CHOICE'));
 }finally{sql.close();}
});

test('pre-expansion active service saves remain three-door climbs when resumed and scouted',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,6);
  const saved=JSON.parse(String(sql.prepare('SELECT data_json FROM tower_rooms_v23 WHERE code = ?').get(code)!.data_json));
  for(const player of saved.players)if(player?.session)delete player.session.run.routePlayers;
  sql.prepare('UPDATE tower_rooms_v23 SET data_json = ? WHERE code = ?').run(JSON.stringify(saved),code);
  const before=await read(db,code,0);
  assert.equal(before.session!.run.routePlayers,undefined);
  assert.equal(towerRoomChoices(before.session!.run).length,3);
  const scouted=await act(db,code,0,'scout',{actorId:'hero',choiceId:'floor-1-2'});
  assert.equal(scouted.session!.run.routePlayers,undefined);
  assert.equal(towerRoomChoices(scouted.session!.run).length,3);
  assert.equal(restoreTowerSession(JSON.parse(JSON.stringify(scouted.session))).run.routePlayers,undefined);
  await assert.rejects(act(db,code,1,'choose',{choiceId:'floor-1-7'}),fault('INVALID_CHOICE'));
 }finally{sql.close();}
});
