import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom,TOWER_ROOM_TTL,type TowerRoomSnapshot} from '../lib/tower-rooms-v23.ts';
import {towerRoomChoices} from '../lib/tower-v23.ts';
import {scoutTowerRoom} from '../lib/tower-scouting-actions.ts';
const NOW=1800000000000,DAY=86400000,keys=Array.from({length:7},(_,seat)=>(seat+1).toString().repeat(64));
function database(){const sql=new DatabaseSync(':memory:');for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement;},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null;},async run(){return sql.prepare(text).run(...values);}};return statement;}} as unknown as RoomDatabase;return {db,sql};}
const fault=(code:string)=>(error:unknown)=>error instanceof RoomError&&error.code===code;
const request=(room:TowerRoomSnapshot,action:string,fields:Record<string,unknown>={})=>({action,runId:room.runId,stepId:room.stepId,requestId:crypto.randomUUID(),...fields});
const read=(db:RoomDatabase,code:string,seat=0,now=NOW)=>getTowerRoom(db,code,keys[seat],now).then(reply=>reply.room);
async function started(db:RoomDatabase,count:number){
 const first=await createTowerRoom(db,{name:'Host',starter:'steam',seed:'RECOVER44',capacity:count,clientToken:keys[0]},NOW);
 for(let seat=1;seat<count;seat++)await joinTowerRoom(db,first.code,{name:`Friend ${seat}`,starter:'steam',clientToken:keys[seat]},NOW+1);
 for(let seat=0;seat<count;seat++)await actTowerRoom(db,first.code,keys[seat],request(await read(db,first.code,seat),'ready',{ready:true}),NOW+2);
 await actTowerRoom(db,first.code,keys[0],request(await read(db,first.code),'start'),NOW+3);return first.code;
}
test('successful deliberate action renews seven days; polling, rejected actions and idempotent retry do not',async()=>{
 const {db,sql}=database();try{
  const created=await createTowerRoom(db,{name:'Host',starter:'steam',seed:'RETENTION44',capacity:2,clientToken:keys[0]},NOW);
  assert.equal(created.room.expiresAt,NOW+TOWER_ROOM_TTL);
  const polled=await read(db,created.code,0,NOW+DAY);assert.equal(polled.expiresAt,created.room.expiresAt);
  await assert.rejects(actTowerRoom(db,created.code,keys[0],request(polled,'start'),NOW+DAY),fault('NOT_READY'));
  assert.equal((await read(db,created.code,0,NOW+DAY)).expiresAt,created.room.expiresAt);
  const command=request(polled,'ready',{ready:true}),saved=(await actTowerRoom(db,created.code,keys[0],command,NOW+2*DAY)).room;
  assert.equal(saved.expiresAt,NOW+2*DAY+TOWER_ROOM_TTL);
  assert.equal(Number(sql.prepare('SELECT expires_at FROM tower_rooms_v23 WHERE code = ?').get(created.code)!.expires_at),saved.expiresAt);
  const retried=(await actTowerRoom(db,created.code,keys[0],command,NOW+3*DAY)).room;
  assert.equal(retried.version,saved.version);assert.equal(retried.expiresAt,saved.expiresAt);
  assert.equal((await read(db,created.code,0,NOW+8*DAY)).expiresAt,saved.expiresAt);
  await assert.rejects(getTowerRoom(db,created.code,keys[0],saved.expiresAt),fault('ROOM_NOT_FOUND'));
 }finally{sql.close();}
});
test('original seat reconnects after launch without extending expiry; a new player cannot replace it',async()=>{
 const {db,sql}=database();try{
  const code=await started(db,2),before=await read(db,code,1);
  const reconnect=await joinTowerRoom(db,code,{name:'Different text',starter:'dusk',clientToken:keys[1]},NOW+DAY);
  assert.equal(reconnect.seat,1);assert.equal(reconnect.room.expiresAt,before.expiresAt);assert.equal(reconnect.room.version,before.version);assert.equal(reconnect.room.players[1]!.name,'Friend 1');
  await assert.rejects(joinTowerRoom(db,code,{name:'New friend',starter:'steam',clientToken:keys[2]},NOW+DAY),fault('CLIMB_STARTED'));
  await assert.rejects(getTowerRoom(db,code,keys[2],NOW+DAY),fault('UNAUTHORIZED'));
  assert.equal((await read(db,code,1,NOW+DAY)).expiresAt,before.expiresAt);
 }finally{sql.close();}
});
test('launch fixes all six encounter roles before scouting and keeps original seat credentials',async()=>{
 const {db,sql}=database();try{
  const code=await started(db,6);
  for(let seat=0;seat<6;seat++){
   const room=await read(db,code,seat),run=room.session!.run;
   assert.equal(run.routePlayers,6);assert.equal(run.encounterModel,'motifs44');assert.equal(run.encounterVariant,seat%3);
   const choice=towerRoomChoices(run)[0],expected=scoutTowerRoom(run,'hero',choice.id);
   const result=(await actTowerRoom(db,code,keys[seat],request(room,'scout',{actorId:'hero',choiceId:choice.id}),NOW+10+seat)).room;
   // Another identical variant may have already contributed a clue. Every
   // result must still be a report about this seat's actual generated fight.
   assert.equal(result.session!.run.encounterVariant,seat%3);
   assert.deepEqual(towerRoomChoices(result.session!.run)[0].enemies,choice.enemies);
   assert.ok(result.scoutReports.length>=1);assert.ok(expected.scouting!.reports.length===1);
   const recovered=await joinTowerRoom(db,code,{name:'Recovered',starter:'steam',clientToken:keys[seat]},NOW+20);
   assert.equal(recovered.seat,seat);assert.deepEqual(recovered.room.session,result.session);
  }
 }finally{sql.close();}
});
test('the final retirement does not prolong a finished climb',async()=>{
 const {db,sql}=database();try{
  const code=await started(db,2),first=await read(db,code,0);
  const left=(await actTowerRoom(db,code,keys[0],request(first,'retire',{confirm:true}),NOW+DAY)).room;
  assert.equal(left.status,'active');assert.equal(left.expiresAt,NOW+DAY+TOWER_ROOM_TTL);
  const second=await read(db,code,1,NOW+2*DAY),finished=(await actTowerRoom(db,code,keys[1],request(second,'retire',{confirm:true}),NOW+2*DAY)).room;
  assert.equal(finished.status,'finished');assert.equal(finished.expiresAt,left.expiresAt);
 }finally{sql.close();}
});
