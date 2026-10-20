/**
 * Actual HTTP/D1 integration; no battle fixtures or forged outcomes.
 * node --experimental-strip-types tests/http-tower-v23-smoke.mjs http://127.0.0.1:8787
 * node --experimental-strip-types tests/http-tower-v23-smoke.mjs <origin> --join-five <UI-room-code>
 * Default checks eight available doors for six players, then runs one shared
 * battle or three deliberate pairs. Pair grouping is independent of route width.
 * --join-five joins a human host; guests lock their own orders and wait for the
 * host whenever they share that battlefield.
 * Access keys stay in memory. An unfinished disposable climb expires after seven days without a successful action.
 */
import {randomBytes,randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {performance} from 'node:perf_hooks';
import {towerRoomChoices,towerRewardChoices} from '../lib/tower-v23.ts';
import {chooseAIPlan} from '../lib/tactics-v22.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';
import {towerTransport} from '../lib/tower-client-v23.ts';

const [arg,mode,suppliedCode]=process.argv.slice(2);
if(!arg||mode&&!['--join-five','--same-room','--split-rooms'].includes(mode)||mode==='--join-five'&&!suppliedCode){console.error('Usage: node --experimental-strip-types tests/http-tower-v23-smoke.mjs <origin> [--same-room | --split-rooms | --join-five CODE]');process.exit(1);}
const url=new URL(arg);if(!['http:','https:'].includes(url.protocol)||url.username||url.password||url.search||url.hash){console.error('Supply a plain HTTP(S) origin.');process.exit(1);}
const origin=url.origin,nonce=randomBytes(4).toString('hex').toUpperCase(),players=[],timings=[],transientRetries=[];
let code=suppliedCode,checks=0;
const secret=()=>randomBytes(32).toString('hex');
function check(condition,message){if(!condition)throw new Error(message);checks++;}
const command=(room,action,fields={})=>({action,...fields,runId:room.runId,stepId:room.stepId,requestId:randomUUID()});
function privacy(room){check(room?.protocolVersion===23,'The server uses protocol23');const wire=JSON.stringify(room);for(const player of players)check(!wire.includes(player.token),'A snapshot must not expose seat keys');for(const field of ['tokenHash','enemyPlan','receipts'])check(!wire.includes(field),'A snapshot must not expose private server fields');}
function safeExcerpt(text){return String(text).replace(/"(?:token|tokenHash|clientToken|authorization)"\s*:\s*"[^"]*"/gi,'"private":"[redacted]"').replace(/Bearer\s+[^\s"<>]+/gi,'Bearer [redacted]').replace(/[a-f0-9]{64}/gi,'[redacted]').replace(/\s+/g,' ').slice(0,240);}
async function http(label,path,{token,body,status=200,errorCode}={}){
 const started=performance.now();let response;
 try{response=await towerTransport(new URL(path,origin),{method:body?'POST':'GET',headers:{Origin:origin,'X-Confluence-Protocol':'23',...(token?{Authorization:`Bearer ${token}`}:{}) ,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(45000)},{onRetry:retry=>transientRetries.push({action:label,...retry})});}
 finally{timings.push({action:label,ms:Math.round(performance.now()-started)});}
 const text=await response.text();let result;try{result=JSON.parse(text);}catch{}
 check(response.status===status,`${label}: HTTP ${response.status}; expected ${status}; code ${safeExcerpt(result?.code??'unavailable')}; response ${safeExcerpt(text)}`);
 check(response.headers.get('cache-control')?.includes('no-store'),`${label}: responses must not be cached`);check(result!==undefined,`${label}: unreadable JSON; response ${safeExcerpt(text)}`);if(errorCode)check(result.code===errorCode,`${label}: expected ${errorCode}`);if(result.room)privacy(result.room);return result;
}
const path=()=>`/api/tower-v23/${code}`;
async function read(player,watch){const result=await http('read',`${path()}${watch===undefined?'':`?watch=${watch}`}`,{token:player.token});player.room=result.room;return result.room;}
async function act(player,action,fields={},body){const result=await http(action,path(),{token:player.token,body:body??command(player.room,action,fields)});player.room=result.room;return result.room;}
async function join(index){const token=secret(),player={token,seat:-1,room:null};players.push(player);const result=await http('join','/api/tower-v23',{body:{action:'join',code,name:`QA squad ${index} ${nonce}`,starter:['steam','stone','dusk'][index%3],clientToken:token},status:201});player.seat=result.seat;player.room=result.room;return player;}
async function readyAll(){await Promise.all(players.map(player=>read(player)));await Promise.all(players.map(player=>act(player,'ready',{ready:true})));}
const plans=new Map();
function ownPlan(player){
 const {battle}=player.room.session,key=`${battle.tower.id}:${battle.version}`;
 if(!plans.has(key))plans.set(key,chooseAIPlan(battle,0));
 const ids=player.room.sharedBattle?.controlledActorIds??battle.units.filter(unit=>unit.owner===0).map(unit=>unit.id);
 return {orders:plans.get(key).orders.filter(order=>ids.includes(order.unitId)),...(player.room.sharedBattle?{link:true}:{})};
}
function canLock(player){const {battle,run}=player.room.session;return run.phase==='battle'&&battle.winner===null&&!player.room.sharedBattle?.ownReady&&(!player.room.sharedBattle||battle.units.some(unit=>unit.hp>0&&player.room.sharedBattle.controlledActorIds.includes(unit.id)));}
async function actualTurn(player){if(canLock(player))return act(player,'resolve',{plan:ownPlan(player)});return player.room;}
async function enterRooms(sameRoom=false){
 await Promise.all(players.map(player=>read(player)));
 // Six players deliberately reuse three doors so this continues to test shared
 // encounters even as the number of available parallel doors grows.
 const choose=player=>{const choices=towerRoomChoices(player.room.session.run),choice=choices[sameRoom?0:player.seat%3];return act(player,'choose',{choiceId:choice.id});};
 await choose(players[0]);
 check(players[0].room.session.run.phase==='route'&&players[0].room.gathering?.choiceId,'A chosen door waits for all floor choices before loading a battlefield');
 await Promise.all(players.slice(1).map(choose));await Promise.all(players.map(player=>read(player)));
 if(mode==='--join-five')return;
 check(players.every(player=>player.room.session.run.phase==='battle'),'Every squad enters after all players choose');
 const groupIds=new Set(players.map(player=>player.room.sharedBattle?.id));check(!groupIds.has(undefined),'Every same-door pair shares an authoritative battle');
 check(groupIds.size===(sameRoom?1:3),'Same doors group six players together or three pairs separately');
 for(const player of players){const shared=player.room.sharedBattle;check(shared.seats.length===(sameRoom?6:2),'The shared group has the expected number of squad owners');check(shared.controlledActorIds.length===2,'Each player controls only their own two starting characters');check(player.room.session.battle.units.filter(unit=>unit.owner===0).length===(sameRoom?12:4),'All grouped characters stand on the same map');}
 sharedBoards();
}
function sharedBoards(){
 const groups=new Map();for(const player of players){const shared=player.room.sharedBattle;if(!shared)continue;const serialized=JSON.stringify(player.room.session.battle);if(groups.has(shared.id))check(groups.get(shared.id)===serialized,'All viewers of one room receive exactly the same battle');else groups.set(shared.id,serialized);}
}
async function scoutRooms(){
 await Promise.all(players.map(player=>read(player)));
 check(players.every(player=>player.room.session.run.routePlayers===6&&towerRoomChoices(player.room.session.run).length===8),'Six occupied launch seats provide eight available doors for every squad');
 // Exercise concurrent reports on three deliberately selected doors, leaving
 // five doors unscouted. This is not an assertion that the route has three doors.
 const before=players.map(player=>{const run=player.room.session.run,rooms=towerRoomChoices(run),room=rooms[player.seat%3];return {seat:player.seat,stepId:player.room.stepId,champion:run.party.find(actor=>!actor.creatureId&&actor.hp>0),roomId:room.id,encounterModel:run.encounterModel??'legacy',encounterVariant:run.encounterVariant??0,enemies:room.enemies.map(actor=>actor.creatureId??actor.championId),facts:new Map(rooms.flatMap(room=>scoutFactsForRoom(run,room)).map(fact=>[fact.id,fact]))};});
 const reportText=report=>JSON.stringify(Object.fromEntries(Object.entries(report).sort(([a],[b])=>a.localeCompare(b))));
 const eligible=(index,reports)=>reports.filter(report=>before[index].facts.has(report.id));
 const verifyReports=(index,reports,expected)=>{check(reports.length===expected.length,'A recipient gets exactly the earned facts compatible with its real encounter');check(new Set(reports.map(report=>report.id)).size===reports.length,'Projected reports have no duplicates');for(const report of reports){check(expected.some(fact=>reportText(fact)===reportText(report)),'No unearned or modified scout report enters a snapshot');check(reportText(before[index].facts.get(report.id))===reportText(report),'Every received identity, affinity, health or spell matches the actual generated enemy');}};
 check(before.every(entry=>entry.champion),'Every test squad has a living champion to scout');
 const commands=players.map((player,index)=>command(player.room,'scout',{actorId:before[index].champion.id,choiceId:before[index].roomId}));
 const host=players[0];await act(host,'scout',{},commands[0]);
 check(host.room.session.run.scouting?.usedActorIds.length===1,'One scouting action spends one champion allowance');
 const retry=await http('scout-retry',path(),{token:host.token,body:commands[0]});check(retry.room.version===host.room.version,'Retrying a scout cannot write or spend again');
 await Promise.all(players.slice(1).map(player=>read(player)));
 for(let index=1;index<players.length;index++){
  check(players[index].room.stepId===before[index].stepId,'A friend scouting cannot invalidate an unrelated player step');
  check((players[index].room.session.run.scouting?.usedActorIds.length??0)===0,'Receiving shared intelligence cannot spend an allied champion');
  verifyReports(index,players[index].room.scoutReports,eligible(index,host.room.session.run.scouting.reports));
 }
 // These requests retain the steps captured before the host scouted. Concurrent
 // CAS retries must select facts against the latest shared intelligence.
 await Promise.all(players.slice(1).map((player,index)=>act(player,'scout',{},commands[index+1])));
 await Promise.all(players.map(player=>read(player)));
 const earned=players.flatMap(player=>player.room.session.run.scouting.reports);
 check(earned.length===6&&new Set(earned.map(report=>report.id)).size===6,'Six successful scouts earn six distinct facts across their actual encounter variants');
 for(let index=0;index<players.length;index++){
  const room=players[index].room,scouting=room.session.run.scouting;
  check(scouting.usedActorIds.length===1&&scouting.usedActorIds[0]===before[index].champion.id,'Each squad spends only its own champion once');
  check(scouting.reports.length===1,'The private run stores only its own earned report');
  check(scouting.reports[0].roomId===before[index].roomId,'Each source report belongs to the door its champion actually scouted');
  verifyReports(index,room.scoutReports,eligible(index,earned));
  check(room.scoutReports.length>=2,'The matching role partner contributes an additional fact without spending this squad twice');
  check(room.scoutReports.every(report=>before.some(entry=>entry.roomId===report.roomId)),'Unscouted parallel doors do not receive discovered reports');
 }
 const settledVersion=host.room.version,lastRetry=await http('shared-scout-retry',path(),{token:host.token,body:commands[0]});
 check(lastRetry.room.version===settledVersion,'A lost-acknowledgement retry does not write a second charge');verifyReports(0,lastRetry.room.scoutReports,eligible(0,earned));
 await http('spent-scout',path(),{token:host.token,body:command(host.room,'scout',{actorId:before[0].champion.id,choiceId:before[0].roomId}),status:400,errorCode:'INVALID_SCOUT'});
 return {champions:6,availableDoors:8,scoutedDoors:new Set(before.map(entry=>entry.roomId)).size,sharedUniqueReports:earned.length,sources:before.map((entry,index)=>({seat:entry.seat,encounterModel:entry.encounterModel,encounterVariant:entry.encounterVariant,roomId:entry.roomId,enemies:entry.enemies,earnedReportId:players[index].room.session.run.scouting.reports[0].id,receivedReports:players[index].room.scoutReports.length}))};
}
async function joinFive(){
 check(/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/.test(code),'Use a valid UI room code');
 for(let index=1;index<=5;index++)await join(index);await readyAll();
 console.log(JSON.stringify({status:'READY_FOR_HOST_START',code,guestSeats:players.map(player=>player.seat)}));
 for(let attempt=0;attempt<360;attempt++){const room=await read(players[0]);if(room.status==='active')break;if(attempt===359)throw new Error('Timed out waiting for the host to start');await delay(2000);}
 await enterRooms(true);
 console.log(JSON.stringify({status:'GUEST_CHOICES_READY',code,choice:'first room',guestSeats:players.map(player=>player.seat)}));
 let firstLocksReported=false;
 for(let iteration=0;iteration<360;iteration++){
  await Promise.all(players.map(player=>read(player)));
  if(players.every(player=>player.room.session.run.floor===2||player.room.session.run.phase==='lost'))break;
  await Promise.all(players.map(async player=>{const {run,battle}=player.room.session;if(run.floor===2||run.phase==='lost')return;if(run.phase==='battle'&&battle.winner===null)await actualTurn(player);else if(run.phase==='battle')await act(player,'finish');else if(run.phase==='reward'){const offers=towerRewardChoices(run),choice=offers.find(offer=>offer.kind==='heal')??offers.find(offer=>offer.kind==='train')??offers.find(offer=>offer.kind==='spell');check(!!choice,'A guest can claim its earned reward');await act(player,'reward',{choiceId:choice.id});}}));
  if(!firstLocksReported&&players.every(player=>player.room.sharedBattle?.ownReady)){firstLocksReported=true;console.log(JSON.stringify({status:'GUEST_ORDERS_LOCKED',code,guestSeats:players.map(player=>player.seat)}));}
  if(iteration===359)throw new Error('Timed out waiting for all human and guest squads to finish');await delay(2000);
 }
 await Promise.all(players.map(player=>read(player)));
 console.log(JSON.stringify({result:'PASS',code,checks,mode:'join-five',transientRetries,squads:players.map(player=>({seat:player.seat,phase:player.room.players[player.seat].phase,floor:player.room.session.run.floor,canEnter:player.room.canEnter,waitingFor:player.room.waitingFor})),maxRequestMs:Math.max(...timings.map(timing=>timing.ms))},null,2));
}
async function fullSmoke(sameRoom){
 players.length=0;plans.clear();const firstCheck=checks,firstRequest=timings.length;
 const host={token:secret(),seat:0,room:null};players.push(host);const created=await http('create','/api/tower-v23',{body:{action:'create',name:`QA host ${nonce}`,starter:'steam',seed:'HTTP-TOWER23',capacity:6,clientToken:host.token},status:201});code=created.code;host.room=created.room;
 for(let index=1;index<=5;index++)await join(index);
 await http('seventh-player','/api/tower-v23',{body:{action:'join',code,name:'Extra player',starter:'steam',clientToken:secret()},status:409,errorCode:'ROOM_FULL'});
 await readyAll();await read(host);check(host.room.status==='waiting','All ready does not start without the host');await act(host,'start');const scouting=await scoutRooms();await enterRooms(sameRoom);
 const watched=await read(host,players[1].seat);check(watched.watch?.seat===players[1].seat,'An authenticated friend can spectate another squad');
 await http('forged-spectator-action',path(),{token:host.token,body:command(host.room,'resolve',{plan:{orders:[]},seat:players[1].seat}),status:400,errorCode:'INVALID_INPUT'});
 await http('wrong-key',path(),{token:secret(),status:401,errorCode:'UNAUTHORIZED'});
 const foreign=host.room.session.battle.units.find(unit=>unit.owner===0&&!host.room.sharedBattle.controlledActorIds.includes(unit.id));
 await http('foreign-fighter-order',path(),{token:host.token,body:command(host.room,'resolve',{plan:{orders:[{unitId:foreign.id,guard:true}]}}),status:400,errorCode:'INVALID_PLAN'});
 const firstBody=command(host.room,'resolve',{plan:ownPlan(host)});
 await act(host,'resolve',{},firstBody);check(host.room.sharedBattle.ownReady&&host.room.session.battle.round===1,'The first player locks without moving or casting before their allies');
 const lockedVersion=host.room.version,lockedRetry=await http('locked-retry',path(),{token:host.token,body:firstBody});check(lockedRetry.room.version===lockedVersion,'Retrying a locked plan spends no second action');
 await Promise.all(players.slice(1).map(actualTurn));await Promise.all(players.map(player=>read(player)));sharedBoards();
 check(players.every(player=>player.room.session.battle.round===2),'Each battlefield resolves once when all its required players lock');
 check(players.every(player=>!player.room.sharedBattle.ownReady&&player.room.sharedBattle.readySeats.length===0),'A resolved exchange opens fresh orders for every teammate');
 await read(host);const retry=await http('resolve-retry',path(),{token:host.token,body:firstBody});check(retry.room.version===host.room.version&&retry.room.session.battle.round===2,'A duplicate action cannot resolve again');
 let observedBarrier=false;const rounds=new Map(players.map(player=>[player.seat,1]));
 for(let iteration=0;iteration<50;iteration++){
  await Promise.all(players.map(player=>read(player)));
  sharedBoards();
  if(players.every(player=>player.room.session.run.floor===2||player.room.session.run.phase==='lost'))break;
  await Promise.all(players.map(async player=>{
   const {run,battle}=player.room.session;
   if(run.floor===2||run.phase==='lost')return;
   if(run.phase==='battle'&&battle.winner===null){rounds.set(player.seat,battle.round);await actualTurn(player);}
   else if(run.phase==='battle')await act(player,'finish');
   else if(run.phase==='reward'){const offers=towerRewardChoices(run),choice=offers.find(offer=>offer.kind==='heal')??offers.find(offer=>offer.kind==='train')??offers.find(offer=>offer.kind==='spell');check(!!choice,'An earned floor-one reward is available');await act(player,'reward',{choiceId:choice.id});}
   if(player.room.session.run.floor===2&&!player.room.canEnter){observedBarrier=true;check(player.room.sharedFloor===1,'A finished squad waits on the previous shared floor');check(player.room.scoutReports.length===0,'A waiting next-floor squad cannot receive old-floor scouting');}
  }));
  if(iteration===49)throw new Error('The first-floor battles did not finish within50 actions per squad');
 }
 await Promise.all(players.map(player=>read(player)));
 const survivors=players.filter(player=>player.room.session.run.phase!=='lost');check(survivors.length>0,'At least one actual squad survives to test checkpoint release');check(observedBarrier,'At least one early finisher visibly waited for another squad');
 for(const player of survivors){check(player.room.sharedFloor===2&&player.room.canEnter,'Survivors can enter floor two after every squad finishes');check(player.room.scoutReports.length===0,'The shared report pool resets at the new floor');check((player.room.session.run.scouting?.usedActorIds.length??0)===0,'Champion scouting allowances refresh after the actual floor checkpoint');for(const other of players)for(const id of other.room.session.run.learnedSpells)check(player.room.session.run.learnedSpells.includes(id),'Checkpoint shares discoveries from completed and defeated squads');}
 const last=survivors[0],nextChoice=towerRoomChoices(last.room.session.run)[0];await act(last,'choose',{choiceId:nextChoice.id});check(last.room.session.run.floor===2,'A released survivor can choose on the next floor');
 return {scenario:sameRoom?'six-in-one-room':'three-shared-pairs',code,checks:checks-firstCheck,requests:timings.length-firstRequest,scouting:{...scouting,checkpointReset:true},sharedFloor:2,survivors:survivors.map(player=>player.seat),rounds:Object.fromEntries(rounds)};
}
async function run(){if(mode==='--join-five')return joinFive();const scenarios=[];for(const sameRoom of mode==='--same-room'?[true]:mode==='--split-rooms'?[false]:[true,false])scenarios.push(await fullSmoke(sameRoom));console.log(JSON.stringify({result:'PASS',checks,requests:timings.length,transientRetries,scenarios,maxRequestMs:Math.max(...timings.map(timing=>timing.ms))},null,2));}
run().catch(error=>{console.error(JSON.stringify({result:'FAIL',...(code?{code}:{}),checks,requests:timings.length,transientRetries,error:safeExcerpt(error instanceof Error?error.message:'Unknown failure')},null,2));process.exitCode=1;});
