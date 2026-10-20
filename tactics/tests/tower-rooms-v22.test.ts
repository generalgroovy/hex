import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom,TOWER_ROOM_TTL,type TowerRoomSnapshot} from '../lib/tower-rooms-v22.ts';
import {towerRoomChoices,towerRewardChoices,createTowerSession,restoreTowerSession,validateTowerStarter} from '../lib/tower-v22.ts';
import {resolveCoopRound,chooseAIPlan,type SimState} from '../lib/tactics-v22.ts';
import {checkTowerOrigin,towerRequestBody} from '../lib/tower-http-v22.ts';

const NOW=1800000000000,HOST='a'.repeat(64),GUEST='b'.repeat(64);
function database(){const sql=new DatabaseSync(':memory:');for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement;},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null;},async run(){return sql.prepare(text).run(...values);}};return statement;}} as unknown as RoomDatabase;return {db,sql};}
const fault=(code:string)=>(error:unknown)=>error instanceof RoomError&&error.code===code;
const request=(room:TowerRoomSnapshot,action:string,fields:Record<string,unknown>={},id=crypto.randomUUID())=>({action,runId:room.runId,stepId:room.stepId,requestId:id,...fields});
async function lobby(db:RoomDatabase){
 const host=await createTowerRoom(db,{name:'Host',starterId:'steam',seed:'COOP-TEST',clientToken:HOST},NOW),guest=await joinTowerRoom(db,host.code,{name:'Guest',starterId:'dusk',clientToken:GUEST},NOW+1);
 await Promise.all([actTowerRoom(db,host.code,HOST,request(guest.room,'ready',{ready:true}),NOW+2),actTowerRoom(db,host.code,GUEST,request(guest.room,'ready',{ready:true}),NOW+2)]);
 return (await getTowerRoom(db,host.code,HOST,NOW+3)).room;
}
async function battle(db:RoomDatabase){const room=await lobby(db),id=towerRoomChoices(room.session!.run)[0].id;await Promise.all([actTowerRoom(db,room.code,HOST,request(room,'vote',{choiceId:id}),NOW+4),actTowerRoom(db,room.code,GUEST,request(room,'vote',{choiceId:id}),NOW+4)]);return (await getTowerRoom(db,room.code,HOST,NOW+5)).room;}
const privateData=(sql:DatabaseSync,code:string)=>JSON.parse(String(sql.prepare('SELECT data_json FROM tower_rooms WHERE code = ?').get(code)!.data_json));
const store=(sql:DatabaseSync,code:string,data:unknown)=>sql.prepare('UPDATE tower_rooms SET data_json = ?, version = version + 1 WHERE code = ?').run(JSON.stringify(data),code);
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.cooldowns={};unit.statuses={};delete unit.guard;};

test('private codes allocate two distinct seats under races, recover retries, and never expose keys',async()=>{
 const {db,sql}=database();try{
  const first=await createTowerRoom(db,{name:'Host',starterId:'steam',seed:'JOIN-RACE',clientToken:HOST},NOW),again=await createTowerRoom(db,{name:'Host',starterId:'steam',seed:'JOIN-RACE',clientToken:HOST},NOW+1);assert.equal(first.code,again.code);assert.equal(first.code.length,12);
  const result=await Promise.allSettled([joinTowerRoom(db,first.code,{name:'One',starterId:'dusk',clientToken:GUEST},NOW+2),joinTowerRoom(db,first.code,{name:'Two',starterId:'stone',clientToken:'c'.repeat(64)},NOW+2)]);
  assert.equal(result.filter(entry=>entry.status==='fulfilled').length,1);assert.ok(result.some(entry=>entry.status==='rejected'&&fault('ROOM_FULL')(entry.reason)));
  const guest=(result.find(entry=>entry.status==='fulfilled') as PromiseFulfilledResult<Awaited<ReturnType<typeof joinTowerRoom>>>).value;
  const rejoined=await joinTowerRoom(db,first.code,{name:'Reconnect',starterId:'dusk',clientToken:guest.token},NOW+3);assert.equal(rejoined.seat,1);
  const wire=JSON.stringify((await getTowerRoom(db,first.code,HOST,NOW+3)).room),stored=JSON.stringify(privateData(sql,first.code));for(const token of [HOST,guest.token]){assert.ok(!wire.includes(token));assert.ok(!stored.includes(token));}assert.ok(!wire.includes('tokenHash'));assert.ok(!wire.includes('enemyPlan'));assert.ok(!wire.includes('receipts'));
  await assert.rejects(getTowerRoom(db,first.code,'d'.repeat(64),NOW+4),fault('UNAUTHORIZED'));
 }finally{sql.close();}
});

test('invalid or duplicate starting characters do not consume the guest seat',async()=>{
 const {db,sql}=database();try{
  const host=await createTowerRoom(db,{name:'Host',starterId:'steam',seed:'BUILDS',clientToken:HOST},NOW),build=validateTowerStarter('dusk').build;
  await assert.rejects(joinTowerRoom(db,host.code,{name:'Bad',starterId:'dusk',build:{...build,affinities:{dark:6,light:6}},clientToken:GUEST},NOW+1),fault('INVALID_BUILD'));
  await assert.rejects(joinTowerRoom(db,host.code,{name:'Duplicate',starterId:'steam',clientToken:GUEST},NOW+1),fault('INVALID_PARTY'));
  assert.equal((await getTowerRoom(db,host.code,HOST,NOW+2)).room.players[1],null);
  const guest=await joinTowerRoom(db,host.code,{name:'Guest',starterId:'dusk',build:{...build,name:'Penny Lantern'},clientToken:GUEST},NOW+3);assert.equal(guest.room.players[1]!.build.name,'Penny Lantern');
  await assert.rejects(createTowerRoom(db,{name:'Injected',starterId:'steam',seed:'BAD',session:{}},NOW),fault('INVALID_INPUT'));
 }finally{sql.close();}
});

test('both players ready starts exactly once, and room choices require matching changeable votes',async()=>{
 const {db,sql}=database();try{
  const room=await lobby(db);assert.equal(room.status,'active');assert.equal(room.session!.run.mode,'coop');assert.equal(room.session!.run.party.length,3);assert.deepEqual(room.controlledActorIds,['hero','companion']);assert.deepEqual((await getTowerRoom(db,room.code,GUEST,NOW+4)).room.controlledActorIds,['partner']);
  const choices=towerRoomChoices(room.session!.run);
  const hostVote=await actTowerRoom(db,room.code,HOST,request(room,'vote',{choiceId:choices[0].id}),NOW+4);assert.equal(hostVote.room.session!.run.phase,'route');
  const split=await actTowerRoom(db,room.code,GUEST,request(room,'vote',{choiceId:choices[1].id}),NOW+5);assert.equal(split.room.session!.run.phase,'route');assert.notEqual(split.room.votes[0]!.choiceId,split.room.votes[1]!.choiceId);
  const joined=await actTowerRoom(db,room.code,GUEST,request(room,'vote',{choiceId:choices[0].id}),NOW+6);assert.equal(joined.room.session!.run.phase,'battle');assert.equal(joined.room.session!.battle!.round,1);assert.equal(joined.room.votes[0],null);assert.notEqual(joined.room.stepId,room.stepId);
  await assert.rejects(actTowerRoom(db,room.code,HOST,request(room,'vote',{choiceId:choices[0].id}),NOW+7),fault('STALE_STEP'));
  assert.deepEqual(restoreTowerSession(joined.room.session),joined.room.session);
 }finally{sql.close();}
});

test('allied drafts are shared while the enemy plan stays frozen and private; partner orders cannot be forged',async()=>{
 const {db,sql}=database();try{
  const room=await battle(db),enemy=privateData(sql,room.code).enemyPlan;
  const drafted=await actTowerRoom(db,room.code,HOST,request(room,'draft',{plan:{orders:[{unitId:'hero',guard:true}],link:true}}),NOW+6);
  assert.deepEqual(drafted.room.drafts[0],{orders:[{unitId:'hero',guard:true}],link:true});
  const partner=(await getTowerRoom(db,room.code,GUEST,NOW+7)).room;assert.deepEqual(partner.drafts[0],drafted.room.drafts[0]);assert.deepEqual(privateData(sql,room.code).enemyPlan,enemy);assert.ok(!JSON.stringify(partner).includes('enemyPlan'));
  await assert.rejects(actTowerRoom(db,room.code,HOST,request(room,'draft',{plan:{orders:[{unitId:'partner',guard:true}]}}),NOW+7),fault('INVALID_PLAN'));
  await assert.rejects(actTowerRoom(db,room.code,GUEST,request(room,'draft',{plan:{orders:[{unitId:'companion',guard:true}]}}),NOW+7),fault('INVALID_PLAN'));
  assert.equal((await getTowerRoom(db,room.code,HOST,NOW+8)).room.session!.battle!.round,1);
 }finally{sql.close();}
});

test('simultaneous locks resolve once, dropped-response retries are idempotent, and changed payloads are rejected',async()=>{
 const {db,sql}=database();try{
  const room=await battle(db),host=request(room,'lock',{plan:{orders:[],link:true}}),guest=request(room,'lock',{plan:{orders:[],link:true}});
  await Promise.all([actTowerRoom(db,room.code,HOST,host,NOW+6),actTowerRoom(db,room.code,GUEST,guest,NOW+6)]);
  const next=(await getTowerRoom(db,room.code,HOST,NOW+7)).room;assert.equal(next.session!.battle!.round,2);assert.equal(next.session!.previous!.round,1);assert.deepEqual(next.locked,[false,false]);
  const retry=await actTowerRoom(db,room.code,HOST,host,NOW+8);assert.equal(retry.room.version,next.version);assert.equal(retry.room.session!.battle!.round,2);
  await assert.rejects(actTowerRoom(db,room.code,HOST,{...host,plan:{orders:[]}},NOW+8),fault('REQUEST_CHANGED'));
  await assert.rejects(actTowerRoom(db,room.code,GUEST,request(room,'lock',{plan:{orders:[]}}),NOW+8),fault('STALE_STEP'));
  assert.deepEqual(restoreTowerSession(next.session),next.session);
 }finally{sql.close();}
});

test('an unlocked plan can change while the friend is planning, but a locked draft cannot',async()=>{
 const {db,sql}=database();try{
  const room=await battle(db);await actTowerRoom(db,room.code,HOST,request(room,'lock',{plan:{orders:[{unitId:'hero',guard:true}]}}),NOW+6);
  await assert.rejects(actTowerRoom(db,room.code,HOST,request(room,'draft',{plan:{orders:[]}}),NOW+7),fault('PLAN_LOCKED'));
  const unlocked=await actTowerRoom(db,room.code,HOST,request(room,'unlock'),NOW+8);assert.equal(unlocked.room.locked[0],false);
  const edited=await actTowerRoom(db,room.code,HOST,request(room,'draft',{plan:{orders:[],link:true}}),NOW+9);assert.deepEqual(edited.room.drafts[0],{orders:[],link:true});assert.equal(edited.room.session!.battle!.round,1);
 }finally{sql.close();}
});

test('build changes require ownership, preserve budget, and invalidate stale shared choices',async()=>{
 const {db,sql}=database();try{
  const room=await lobby(db),hero=room.session!.run.party[0],partner=room.session!.run.party[1];
  await assert.rejects(actTowerRoom(db,room.code,HOST,request(room,'loadout',{actorId:'partner',loadout:partner.loadout}),NOW+4),fault('NOT_YOUR_CHARACTER'));
  const oldVote=request(room,'vote',{choiceId:towerRoomChoices(room.session!.run)[0].id});
  const changed=await actTowerRoom(db,room.code,HOST,request(room,'build',{actorId:'hero',build:{championId:hero.championId,name:'Tide Clerk',affinities:hero.affinities,loadout:hero.loadout}}),NOW+5);assert.equal(changed.room.session!.run.party[0].displayName,'Tide Clerk');assert.notEqual(changed.room.stepId,room.stepId);
  await assert.rejects(actTowerRoom(db,room.code,GUEST,oldVote,NOW+6),fault('STALE_STEP'));
  await assert.rejects(actTowerRoom(db,room.code,HOST,request(changed.room,'build',{actorId:'hero',build:{championId:hero.championId,name:'Cheat',affinities:{water:6,fire:6},loadout:hero.loadout}}),NOW+6),fault('INVALID_BUILD'));
 }finally{sql.close();}
});

test('terminal battle review needs both confirmations, rewards advance once, and companion control alternates',async()=>{
 const {db,sql}=database();try{
  const room=await battle(db);await assert.rejects(actTowerRoom(db,room.code,HOST,request(room,'vote',{choiceId:'finish'}),NOW+6),fault('INVALID_CHOICE'));
  // Synthetic terminal fixture exercises the network transition, not a balance result.
  const data=privateData(sql,room.code),state=data.session.battle as SimState;state.units.filter(unit=>unit.owner===1).forEach(kill);
  const won=resolveCoopRound(state,[{orders:[]},{orders:[]}],{orders:[]});data.session=createTowerSession(data.session.run,won);data.enemyPlan=null;store(sql,room.code,data);
  const terminal=(await getTowerRoom(db,room.code,HOST,NOW+7)).room;
  const first=await actTowerRoom(db,room.code,HOST,request(terminal,'vote',{choiceId:'finish'}),NOW+8);assert.ok(first.room.session!.battle);
  const both=await actTowerRoom(db,room.code,GUEST,request(terminal,'vote',{choiceId:'finish'}),NOW+8);assert.equal(both.room.session!.run.phase,'reward');assert.equal(both.room.session!.battle,null);
  const choice=towerRewardChoices(both.room.session!.run)[0].id;
  await Promise.all([actTowerRoom(db,room.code,HOST,request(both.room,'vote',{choiceId:choice}),NOW+9),actTowerRoom(db,room.code,GUEST,request(both.room,'vote',{choiceId:choice}),NOW+9)]);
  const next=(await getTowerRoom(db,room.code,GUEST,NOW+10)).room;assert.equal(next.session!.run.floor,2);assert.equal(next.session!.run.history.length,1);assert.deepEqual(next.controlledActorIds,['partner','companion']);assert.deepEqual(restoreTowerSession(next.session),next.session);
 }finally{sql.close();}
});

test('a controller with no living actors locks automatically, so the surviving friend can continue',async()=>{
 const {db,sql}=database();try{
  const room=await battle(db),data=privateData(sql,room.code),state=data.session.battle as SimState;state.units.filter(unit=>['hero','companion'].includes(unit.id)).forEach(kill);
  const next=resolveCoopRound(state,[{orders:[]},{orders:[]}],{orders:[]});assert.equal(next.winner,null);data.session=createTowerSession(data.session.run,next);data.enemyPlan=chooseAIPlan(next,1);store(sql,room.code,data);
  const saved=(await getTowerRoom(db,room.code,HOST,NOW+6)).room;
  await Promise.all([actTowerRoom(db,room.code,HOST,request(saved,'lock',{plan:{orders:[]}}),NOW+7),actTowerRoom(db,room.code,GUEST,request(saved,'lock',{plan:{orders:[]}}),NOW+7)]);
  const progressed=(await getTowerRoom(db,room.code,GUEST,NOW+8)).room;assert.equal(progressed.locked[0],true);assert.deepEqual(progressed.drafts[0],{orders:[]});assert.equal(progressed.locked[1],false);
  const continued=await actTowerRoom(db,room.code,GUEST,request(progressed,'lock',{plan:{orders:[]}}),NOW+9);assert.equal(continued.room.session!.battle!.round,progressed.session!.battle!.round+1);
 }finally{sql.close();}
});

test('expiration is durable and isolated from existing matches, and expired host keys can start again',async()=>{
 const {db,sql}=database();try{
  const first=await createTowerRoom(db,{name:'Host',starterId:'steam',seed:'EXPIRY',clientToken:HOST},NOW);
  assert.equal(sql.prepare('SELECT count(*) AS n FROM skirmishes').get()!.n,0);assert.equal(sql.prepare('SELECT count(*) AS n FROM rooms').get()!.n,0);
  await assert.rejects(getTowerRoom(db,first.code,HOST,NOW+TOWER_ROOM_TTL),fault('ROOM_NOT_FOUND'));
  const renewed=await createTowerRoom(db,{name:'Host',starterId:'steam',seed:'EXPIRY',clientToken:HOST},NOW+TOWER_ROOM_TTL);assert.notEqual(renewed.code,first.code);assert.equal(sql.prepare('SELECT count(*) AS n FROM tower_rooms').get()!.n,1);
 }finally{sql.close();}
});

test('HTTP boundaries reject foreign origins, unsupported protocols and oversized or malformed bodies',async()=>{
 const url='https://example.test/api/tower';assert.doesNotThrow(()=>checkTowerOrigin(new Request(url,{headers:{Origin:'https://example.test','X-Confluence-Protocol':'22'}})));
 assert.throws(()=>checkTowerOrigin(new Request(url,{headers:{Origin:'https://attacker.test'}})),fault('ORIGIN_REJECTED'));
 assert.throws(()=>checkTowerOrigin(new Request(url,{headers:{'X-Confluence-Protocol':'21'}})),fault('CLIENT_UPGRADE_REQUIRED'));
 await assert.rejects(towerRequestBody(new Request(url,{method:'POST',headers:{'Content-Type':'text/plain'},body:'{}'})),fault('JSON_REQUIRED'));
 await assert.rejects(towerRequestBody(new Request(url,{method:'POST',headers:{'Content-Type':'application/json'},body:'{'})),fault('INVALID_JSON'));
 await assert.rejects(towerRequestBody(new Request(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:'x'.repeat(16384)})})),fault('BODY_TOO_LARGE'));
 assert.deepEqual(await towerRequestBody(new Request(url,{method:'POST',headers:{'Content-Type':'application/json'},body:'{"action":"create"}'})),{action:'create'});
});
