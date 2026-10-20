import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import test from 'node:test';
import {RESOLUTION_MS} from '../lib/feedback-v16.ts';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {createSkirmish,joinSkirmish,getSkirmish,actSkirmish,PLANNING_MS,validateStoredSkirmishState} from '../lib/skirmish-rooms-v17.ts';
const NOW=1800000000000;
const characters=['oh_tipi','wa_bidi','treevor_mason'].map(canonicalBuild);
function database(){const sql=new DatabaseSync(':memory:');for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(n=>n.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null},async run(){return sql.prepare(text).run(...values)}};return statement}} as unknown as RoomDatabase;return {db,sql};}
const fault=(code:string)=>(e:unknown)=>e instanceof RoomError&&e.code===code;
async function lobby(db:RoomDatabase,count=6,mode='free-for-all'){
 const host=await createSkirmish(db,{name:'Host',characters,playerCount:count,mode,seed:'SIX-RIVERS'},NOW);
 const guests=await Promise.all(Array.from({length:count-1},(_,i)=>joinSkirmish(db,host.code,{name:`Guest${i}`,characters,clientToken:(i+1).toString(16).repeat(64)},NOW+1)));
 const seats=[host,...guests].sort((a,b)=>a.seat-b.seat);
 await Promise.all(seats.map(s=>actSkirmish(db,host.code,s.token,{action:'ready',ready:true},NOW+2)));
 return seats;
}
test('six concurrent joins reserve distinct seats, all keys stay private, and only ready full lobbies start',async()=>{
 const {db,sql}=database();try{
  const host=await createSkirmish(db,{name:'Host',characters,playerCount:6,mode:'free-for-all',seed:'SEATS',clientToken:'a'.repeat(64)},NOW);
  const retry=await createSkirmish(db,{name:'Host',characters,playerCount:6,mode:'free-for-all',seed:'SEATS',clientToken:host.token},NOW+1);assert.equal(retry.code,host.code);
  await assert.rejects(actSkirmish(db,host.code,host.token,{action:'start'},NOW+1),fault('NOT_READY'));
  const joined=await Promise.all(Array.from({length:5},(_,i)=>joinSkirmish(db,host.code,{name:`Player${i}`,characters,clientToken:(i+1).toString(16).repeat(64)},NOW+2)));
  assert.equal(new Set(joined.map(j=>j.seat)).size,5);
  await assert.rejects(joinSkirmish(db,host.code,{name:'Extra',characters},NOW+3),fault('ROOM_FULL'));
  const again=await joinSkirmish(db,host.code,{name:'Player0',characters,clientToken:joined[0].token},NOW+3);assert.equal(again.seat,joined[0].seat);
  await assert.rejects(actSkirmish(db,host.code,joined[0].token,{action:'start'},NOW+3),fault('HOST_ONLY'));
  const read=await getSkirmish(db,host.code,host.token,NOW+4);const wire=JSON.stringify(read);assert.ok(!wire.includes('tokenHash'));assert.ok(!wire.includes(host.token));assert.equal(read.room.players.filter(Boolean).length,6);assert.deepEqual(read.room.affinityTotals,[15,15,15,15,15,15]);
  await assert.rejects(getSkirmish(db,host.code,'f'.repeat(64),NOW+5),fault('UNAUTHORIZED'));
 }finally{sql.close()}
});
test('six sealed plans resolve exactly once under races and retries never expose opponents orders',async()=>{
 const {db,sql}=database();try{
  const seats=await lobby(db),host=seats[0],started=await actSkirmish(db,host.code,host.token,{action:'start'},NOW+3),matchId=started.room.matchId;
  assert.equal(started.room.state!.units.length,18);assert.deepEqual(validateStoredSkirmishState(started.room.state),started.room.state);
  const plan={orders:[]};await actSkirmish(db,host.code,host.token,{action:'plan',matchId,round:1,plan},NOW+4);
  const other=await getSkirmish(db,host.code,seats[1].token,NOW+5);assert.equal(other.room.yourPlan,undefined);assert.equal(other.room.locked[0],true);assert.equal(other.room.state!.round,1);
  const before=JSON.stringify(other.room.state);await assert.rejects(actSkirmish(db,host.code,seats[1].token,{action:'plan',matchId,round:1,plan:{orders:[{unitId:started.room.state!.units.find(u=>u.owner===0)!.id,guard:true}]}},NOW+5),fault('INVALID_PLAN'));
  assert.equal(JSON.stringify((await getSkirmish(db,host.code,host.token,NOW+5)).room.state),before);
  await Promise.all(seats.slice(1).map(s=>actSkirmish(db,host.code,s.token,{action:'plan',matchId,round:1,plan},NOW+6)));
  const resolved=(await getSkirmish(db,host.code,host.token,NOW+7)).room;assert.equal(resolved.state!.round,2);assert.ok(resolved.locked.every(v=>!v));
  const retry=await actSkirmish(db,host.code,host.token,{action:'plan',matchId,round:1,plan},NOW+8);assert.equal(retry.room.version,resolved.version);assert.equal(retry.room.state!.round,2);
  assert.deepEqual(validateStoredSkirmishState(resolved.state),resolved.state);
 }finally{sql.close()}
});
test('invalid builds do not reserve seats or inject stats, and names survive the complete server boundary',async()=>{
 const {db,sql}=database();try{
  const custom=characters.map(c=>({...c,name:`New ${c.name}`}));const host=await createSkirmish(db,{name:'Maker',characters:custom,playerCount:2,mode:'free-for-all',seed:'NAMES'},NOW);
  await assert.rejects(joinSkirmish(db,host.code,{name:'Cheat',characters:characters.map((c,i)=>i?c:{...c,affinities:{water:6}})},NOW+1),fault('INVALID_COMPANY'));
  assert.equal((await getSkirmish(db,host.code,host.token,NOW+2)).room.players[1],null);
  const guest=await joinSkirmish(db,host.code,{name:'Guest',characters},NOW+3);for(const p of [host,guest])await actSkirmish(db,host.code,p.token,{action:'ready',ready:true},NOW+4);
  const result=await actSkirmish(db,host.code,host.token,{action:'start'},NOW+5);assert.equal(result.room.state!.units.find(u=>u.owner===0&&u.championId==='oh_tipi')!.displayName,'New Oh Tipi');
  for(const unit of result.room.state!.units){assert.equal(unit.hp,8);assert.equal(unit.maxFlux,6)}
 }finally{sql.close()}
});
test('missing players can be guarded only after the advertised deadline; stale timers cannot advance twice',async()=>{
 const {db,sql}=database();try{
  const seats=await lobby(db,3),host=seats[0],started=await actSkirmish(db,host.code,host.token,{action:'start'},NOW+3),matchId=started.room.matchId;
  await assert.rejects(actSkirmish(db,host.code,seats[1].token,{action:'timeout',matchId,round:1},NOW+PLANNING_MS),fault('STILL_PLANNING'));
  await assert.rejects(actSkirmish(db,host.code,host.token,{action:'plan',matchId,round:1,plan:{orders:[]}},NOW+PLANNING_MS+3),fault('PLANNING_ENDED'));
  await assert.rejects(actSkirmish(db,host.code,seats[2].token,{action:'plan',matchId,round:1,plan:{orders:[]}},NOW+PLANNING_MS+4),fault('PLANNING_ENDED'));
  const result=await actSkirmish(db,host.code,seats[1].token,{action:'timeout',matchId,round:1},NOW+PLANNING_MS+3);assert.equal(result.room.state!.round,2);assert.equal(result.room.roundDeadline,NOW+PLANNING_MS*2+RESOLUTION_MS+3);
  await assert.rejects(actSkirmish(db,host.code,seats[2].token,{action:'timeout',matchId,round:1},NOW+PLANNING_MS+4),fault('ROUND_CHANGED'));
 }finally{sql.close()}
});
test('expired host keys can reserve a fresh room while current rooms are retained',async()=>{
 const {db,sql}=database();try{
  const input={name:'Host',characters,playerCount:2,mode:'free-for-all',seed:'RENEW',clientToken:'e'.repeat(64)};
  const first=await createSkirmish(db,input,NOW),later=NOW+7*24*60*60*1000;
  const current=await createSkirmish(db,{...input,clientToken:'d'.repeat(64)},later-10);
  const renewed=await createSkirmish(db,input,later);assert.notEqual(renewed.code,first.code);
  assert.equal((await getSkirmish(db,current.code,current.token,later)).room.code,current.code);
  assert.equal(sql.prepare('SELECT count(*) AS count FROM skirmishes').get()!.count,2);
 }finally{sql.close()}
});
test('team matches keep equal companies and require unanimous rematch with a fresh match identity',async()=>{
 const {db,sql}=database();try{
  const seats=await lobby(db,4,'teams'),host=seats[0],started=await actSkirmish(db,host.code,host.token,{action:'start'},NOW+3);assert.deepEqual(started.room.state!.teams,[0,1,0,1]);
  let room=started.room,at=NOW+3;for(let i=0;i<20&&room.status==='active';i++){at=room.roundDeadline!;room=(await actSkirmish(db,host.code,host.token,{action:'timeout',matchId:room.matchId,round:room.state!.round},at)).room;}
  assert.equal(room.status,'finished');const oldId=room.matchId;
  for(const p of seats.slice(0,-1)){room=(await actSkirmish(db,host.code,p.token,{action:'rematch',matchId:oldId},at+1)).room;assert.equal(room.status,'finished')}
  room=(await actSkirmish(db,host.code,seats.at(-1)!.token,{action:'rematch',matchId:oldId},at+2)).room;assert.equal(room.status,'active');assert.notEqual(room.matchId,oldId);assert.equal(room.state!.round,1);assert.ok(room.rematch.every(v=>!v));
  await assert.rejects(actSkirmish(db,host.code,host.token,{action:'plan',matchId:oldId,round:1,plan:{orders:[]}},at+3),fault('MATCH_CHANGED'));
 }finally{sql.close()}
});

