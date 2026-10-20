/**
 * Actual HTTP/D1 smoke test. Creates one disposable private climb (expires after seven days).
 * Run from the repository root after starting the built server:
 *   node --experimental-strip-types tests/http-tower-v22-smoke.mjs http://127.0.0.1:8787
 * Run the same command with the published origin after deployment.
 * Access keys stay in process memory and are never printed or written to disk.
 */
import {randomBytes,randomUUID} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {towerRoomChoices} from '../lib/tower-v22.ts';
import {validateCoopPlan} from '../lib/tactics-v22.ts';

const arg=process.argv[2];
if(!arg){console.error('Usage: node --experimental-strip-types tests/http-tower-v22-smoke.mjs <http(s) origin>');process.exit(1);}
const url=new URL(arg);
if(!['http:','https:'].includes(url.protocol)||url.username||url.password||url.search||url.hash){console.error('Supply an HTTP(S) origin without credentials or query parameters.');process.exit(1);}
const origin=url.origin,hostKey=randomBytes(32).toString('hex'),guestKey=randomBytes(32).toString('hex');
const nonce=randomBytes(4).toString('hex').toUpperCase(),timings=[];
let checks=0,publicCode;
function check(condition,label){if(!condition)throw new Error(label);checks++;}
function action(room,verb,fields={}){return {action:verb,runId:room.runId,stepId:room.stepId,requestId:randomUUID(),...fields};}
function privateSnapshot(room){
 check(room?.protocolVersion===22,'Snapshot uses Tower22');
 const wire=JSON.stringify(room);
 check(!wire.includes(hostKey)&&!wire.includes(guestKey),'Room snapshots must not contain player keys');
 check(!wire.includes('tokenHash')&&!wire.includes('enemyPlan')&&!wire.includes('receipts'),'Private server fields must not enter snapshots');
 return room;
}
async function request(label,path,{token,body,status=200,code}={}){
 const started=performance.now();
 const response=await fetch(new URL(path,origin),{method:body?'POST':'GET',headers:{Origin:origin,'X-Confluence-Protocol':'22',...(token?{Authorization:`Bearer ${token}`}:{}) ,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(45000)});
 timings.push({action:label,ms:Math.round(performance.now()-started)});
 check(response.status===status,`${label}: expected HTTP ${status}, received ${response.status}`);
 check(response.headers.get('cache-control')?.includes('no-store'),`${label}: response must disable caching`);
 check(response.headers.get('x-confluence-protocol')==='22',`${label}: response protocol must be 22`);
 let result;try{result=await response.json();}catch{throw new Error(`${label}: response was not JSON`);}
 if(code)check(result.code===code,`${label}: expected ${code}`);
 if(result.room)privateSnapshot(result.room);
 return result;
}
async function main(){
 const created=await request('create','/api/tower',{body:{action:'create',name:`Smoke host ${nonce}`,starterId:'steam',seed:`HTTP-${nonce}`,clientToken:hostKey},status:201});
 publicCode=created.code;check(/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/.test(publicCode),'Created room has a valid invitation code');check(created.seat===0&&created.token===hostKey,'Creator receives its own seat');
 const path=`/api/tower/${publicCode}`;
 const joined=await request('join','/api/tower',{body:{action:'join',code:publicCode,name:`Smoke guest ${nonce}`,starterId:'dusk',clientToken:guestKey},status:201});
 check(joined.seat===1&&joined.token===guestKey,'Joining friend receives a distinct seat');
 check(joined.room.players[0].name!==joined.room.players[1].name,'The two test players have distinct names');
 let room=(await request('host-ready',path,{token:hostKey,body:action(joined.room,'ready',{ready:true})})).room;
 check(room.status==='waiting','One ready player cannot start the climb');
 room=(await request('guest-ready',path,{token:guestKey,body:action(room,'ready',{ready:true})})).room;
 check(room.status==='active'&&room.session.run.mode==='coop','Both ready players start a cooperative climb');
 const choice=towerRoomChoices(room.session.run).find(candidate=>candidate.kind==='combat');check(!!choice,'Floor one offers a normal encounter');
 room=(await request('host-room-vote',path,{token:hostKey,body:action(room,'vote',{choiceId:choice.id})})).room;
 check(room.session.run.phase==='route','One vote cannot choose a room');
 room=(await request('guest-room-vote',path,{token:guestKey,body:action(room,'vote',{choiceId:choice.id})})).room;
 check(room.session.run.phase==='battle'&&room.session.battle.round===1,'Matching room votes start the first encounter');
 const battle=room.session.battle,guard=seat=>validateCoopPlan(battle,seat,{orders:room.session.run.party.filter(actor=>battle.tower.controllers[actor.id]===seat).map(actor=>({unitId:actor.id,guard:true})),link:true});
 const hostPlan=guard(0),guestPlan=guard(1);check(hostPlan.orders.length===2&&guestPlan.orders.length===1,'Opening companion belongs to the host');
 room=(await request('host-draft',path,{token:hostKey,body:action(room,'draft',{plan:hostPlan})})).room;
 const shared=(await request('guest-shared-draft',path,{token:guestKey})).room;
 check(shared.drafts[0]?.link===true&&shared.drafts[0].orders.length===2,'Friendly orders and Link consent are shared');
 await request('forged-partner-order',path,{token:hostKey,body:action(room,'draft',{plan:{orders:[{unitId:'partner',guard:true}]}}),status:400,code:'INVALID_PLAN'});
 await request('wrong-key',path,{token:randomBytes(32).toString('hex'),status:401,code:'UNAUTHORIZED'});
 const hostLock=action(room,'lock',{plan:hostPlan}),guestLock=action(room,'lock',{plan:guestPlan});
 await Promise.all([request('host-lock',path,{token:hostKey,body:hostLock}),request('guest-lock-resolve',path,{token:guestKey,body:guestLock})]);
 const [hostAfter,guestAfter]=await Promise.all([request('host-reconnect',path,{token:hostKey}),request('guest-reconnect',path,{token:guestKey})]);
 const after=hostAfter.room;
 check(after.session.battle.round===2&&after.session.previous.round===1,'Two concurrent locks resolve exactly one round');
 check(after.version===guestAfter.room.version&&after.session.battle.version===guestAfter.room.session.battle.version,'Both seats reconnect to the same authoritative version');
 check(after.stepId===guestAfter.room.stepId&&after.stepId!==room.stepId,'Resolved round advances the shared step exactly once');
 check(after.yourSeat===0&&guestAfter.room.yourSeat===1,'Reconnection preserves seat identity');
 const retry=(await request('lock-response-retry',path,{token:hostKey,body:hostLock})).room;
 check(retry.version===after.version&&retry.session.battle.round===2,'Retrying an acknowledged lock cannot resolve again');
 console.log(JSON.stringify({result:'PASS',code:publicCode,checks,requests:timings.length,round:after.session.battle.round,version:after.version,timings},null,2));
}
main().catch(error=>{console.error(JSON.stringify({result:'FAIL',...(publicCode?{code:publicCode}:{}),checks,error:error instanceof Error?error.message:'Unknown failure',timings},null,2));process.exitCode=1;});
