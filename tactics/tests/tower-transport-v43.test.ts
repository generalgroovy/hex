import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {towerTransport,requestTowerAction,TowerResponseError,type TowerTransientRetry} from '../lib/tower-client-v23.ts';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom} from '../lib/tower-rooms-v23.ts';
import type {RoomDatabase} from '../lib/rooms.ts';

const command={action:'scout',runId:'test-run',stepId:'test-step',requestId:'fixed-request-43',actorId:'hero',choiceId:'floor-1-0'};
const body=JSON.stringify(command),noWait=async()=>{};
const post={method:'POST',headers:{Authorization:'Bearer private-seat-key'},body};

test('transient responses retry twice with identical serialized request and bounded backoff',async()=>{
 const requests:{url:string;body:BodyInit|null|undefined;authorization:string|null}[]=[],delays:number[]=[],retries:TowerTransientRetry[]=[];
 const response=await towerTransport('/api/tower-v23/ROOM',post,{fetcher:async(url,init)=>{
  requests.push({url:String(url),body:init?.body,authorization:new Headers(init?.headers).get('Authorization')});
  return new Response('reply',{status:[502,503,200][requests.length-1]});
 },wait:async ms=>{delays.push(ms);},onRetry:retry=>retries.push(retry)});
 assert.equal(response.status,200);assert.equal(requests.length,3);assert.ok(requests.every(request=>request.body===body&&request.url==='/api/tower-v23/ROOM'&&request.authorization==='Bearer private-seat-key'));
 assert.deepEqual(delays,[250,700]);assert.deepEqual(retries,[{attempt:1,delayMs:250,status:502},{attempt:2,delayMs:700,status:503}]);
});

test('final transient response remains readable and final network failure is preserved',async()=>{
 let calls=0;const final=await towerTransport('/room',post,{fetcher:async()=>{calls++;return new Response('still unavailable',{status:504});},wait:noWait});
 assert.equal(calls,3);assert.equal(final.status,504);assert.equal(await final.text(),'still unavailable');
 calls=0;const failure=new TypeError('Network unavailable');
 await assert.rejects(towerTransport('/room',post,{fetcher:async()=>{calls++;throw failure;},wait:noWait}),error=>error===failure);assert.equal(calls,3);
});

test('validation, authorization, stale actions, throttling and other server errors are never retried',async()=>{
 for(const status of [400,401,403,404,409,429,500]){
  let calls=0;const result=await towerTransport('/room',post,{fetcher:async()=>{calls++;return new Response('rejected',{status});},wait:noWait});
  assert.equal(result.status,status);assert.equal(calls,1,`HTTP ${status} must not retry`);
 }
});

test('only receipted actions, recoverable entry tokens and safe GETs may retry',async()=>{
 const cases:[RequestInit,number][]=[
  [{},3],
  [{method:'POST',body:JSON.stringify({action:'create',clientToken:'a'.repeat(64)})},3],
  [{method:'POST',body:JSON.stringify({action:'join',clientToken:'b'.repeat(64)})},3],
  [{method:'POST',body:JSON.stringify({action:'join'})},1],
  [{method:'POST',body:JSON.stringify({...command,action:'create',clientToken:'invalid'})},1],
  [{method:'POST',body:JSON.stringify({...command,requestId:''})},1],
  [{method:'POST',body:JSON.stringify({...command,runId:''})},1],
  [{method:'POST',body:'invalid JSON'},1],
  [{method:'PUT',body},1],
 ];
 for(const [init,expected] of cases){let calls=0;await towerTransport('/room',init,{fetcher:async()=>{calls++;return new Response(null,{status:503});},wait:noWait});assert.equal(calls,expected,JSON.stringify(init));}
});

test('abort before fetch, explicit cancellation, timeouts and cancellation during backoff stop retries',async()=>{
 let calls=0;const cancelled=new AbortController();cancelled.abort();
 await assert.rejects(towerTransport('/room',{signal:cancelled.signal},{fetcher:async()=>{calls++;return new Response();}}),{name:'AbortError'});assert.equal(calls,0);
 for(const name of ['AbortError','TimeoutError']){
  calls=0;await assert.rejects(towerTransport('/room',post,{fetcher:async()=>{calls++;throw new DOMException('Stopped',name);},wait:noWait}),{name});assert.equal(calls,1);
 }
 calls=0;const during=new AbortController();
 await assert.rejects(towerTransport('/room',{...post,signal:during.signal},{fetcher:async()=>{calls++;return new Response(null,{status:503});},onRetry:()=>{setTimeout(()=>during.abort(),1);}}),{name:'AbortError'});
 assert.equal(calls,1);
});

test('production action wrapper serializes once and keeps final server error usable by existing retry UI',async()=>{
 const original=globalThis.fetch,mutable={...command},seen:(BodyInit|null|undefined)[]=[];
 const snapshot={protocolVersion:23,code:'23456789ABCD',version:0,runId:'run',stepId:'step',players:[{},{}],yourSeat:0};
 try{
  globalThis.fetch=async(_url,init)=>{seen.push(init?.body);if(seen.length===1){mutable.choiceId='changed-after-send';throw new TypeError('Acknowledgement lost');}return Response.json({room:snapshot});};
  const reply=await requestTowerAction('23456789ABCD','a'.repeat(64),mutable);
  assert.equal(reply.room.runId,'run');assert.deepEqual(seen,[body,body]);
  let calls=0;globalThis.fetch=async()=>{calls++;return Response.json({error:'The server is busy. Retry.',code:'SERVICE_UNAVAILABLE'},{status:503});};
  await assert.rejects(requestTowerAction('23456789ABCD','a'.repeat(64),command),error=>error instanceof TowerResponseError&&error.status===503&&error.code==='SERVICE_UNAVAILABLE'&&error.message==='The server is busy. Retry.');
  assert.equal(calls,3);
 }finally{globalThis.fetch=original;}
});

function database(){
 const sql=new DatabaseSync(':memory:');
 for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));
 const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null},async run(){return sql.prepare(text).run(...values)}};return statement}} as unknown as RoomDatabase;
 return {db,sql};
}
test('a real service commit followed by a lost acknowledgement retries without spending a second scout',async()=>{
 const {db,sql}=database(),now=1800000000000,keys=['1'.repeat(64),'2'.repeat(64)];
 try{
  const host=await createTowerRoom(db,{name:'Host',starter:'steam',seed:'RETRY-43',capacity:2,clientToken:keys[0]},now);
  await joinTowerRoom(db,host.code,{name:'Friend',starter:'steam',clientToken:keys[1]},now+1);
  const read=(seat:number)=>getTowerRoom(db,host.code,keys[seat],now+100).then(reply=>reply.room);
  const act=async(seat:number,action:string,fields:Record<string,unknown>={})=>{const room=await read(seat);return actTowerRoom(db,host.code,keys[seat],{action,...fields,runId:room.runId,stepId:room.stepId,requestId:crypto.randomUUID()},now+100);};
  await act(0,'ready',{ready:true});await act(1,'ready',{ready:true});await act(0,'start');
  const before=await read(0),actor=before.session!.run.party.find(actor=>!actor.creatureId&&actor.hp>0)!;
  const payload=JSON.stringify({...command,runId:before.runId,stepId:before.stepId,actorId:actor.id}),seen:(BodyInit|null|undefined)[]=[];
  const reply=await towerTransport('/room',{method:'POST',body:payload},{wait:noWait,fetcher:async(_url,init)=>{
   seen.push(init?.body);const result=await actTowerRoom(db,host.code,keys[0],JSON.parse(init!.body as string),now+100);
   if(seen.length===1)throw new TypeError('Connection lost after commit');
   return Response.json(result);
  }});
  assert.equal(reply.status,200);assert.deepEqual(seen,[payload,payload]);
  const after=await read(0);assert.equal(after.version,before.version+1);assert.deepEqual(after.session!.run.scouting!.usedActorIds,[actor.id]);assert.equal(after.session!.run.scouting!.reports.length,1);
 }finally{sql.close();}
});
