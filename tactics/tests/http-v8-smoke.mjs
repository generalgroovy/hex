import assert from 'node:assert/strict';
import {chooseAIPlan,createSimGame,BOARD_SIZE,MAX_ROUNDS,legalCasts,restoreSimState} from '../lib/tactics-v8.ts';
import {defaultLoadout, SPELLS, getSignature} from '../lib/spells-v8.ts';
import {createClientSessionStore} from '../lib/client-session-v8.ts';

const origin=process.argv[2]||'http://127.0.0.1:5173';
const diagnostic=result=>JSON.stringify({request:result.request,status:result.status,...(typeof result.data?.code==='string'&&/^[A-Z_]{1,64}$/.test(result.data.code)?{code:result.data.code}:{})});
function expectStatus(result,status){assert.equal(result.status,status,diagnostic(result))}
async function call(path,method='GET',body,token,protocolVersion=8){
 const request=`${method} ${path.replace(/\/api\/rooms\/[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}(?=\/|$)/,'/api/rooms/:code')}`;
 let response;try{response=await fetch(origin+path,{method,headers:{'X-Confluence-Protocol':String(protocolVersion),...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify({...body,protocolVersion})}:{})})}catch{throw new Error(`Network request failed: ${request}`)}
 assert.equal(response.headers.get('X-Confluence-Protocol'),'8',`${request}: HTTP ${response.status} must advertise protocol 8`);
 let data;try{data=await response.json()}catch{throw new Error(`${request}: HTTP ${response.status} returned unreadable JSON`)}
 return {request,status:response.status,data};
}
const roomPath=code=>`/api/rooms/${code}`;
async function readRoom(code,token){const result=await call(roomPath(code),'GET',undefined,token);expectStatus(result,200);assert.ok(result.data?.room&&Number.isInteger(result.data.room.version),`Unreadable room: ${diagnostic(result)}`);if(result.data.room.state)assert.deepEqual(restoreSimState(JSON.parse(JSON.stringify(result.data.room.state))),result.data.room.state,'every authoritative round must survive strict client save restore');return result}
const planInput=(room,plan)=>({matchId:room.matchId,round:room.state.round,plan});
const roster=['red_baron','oh_tipi','treevor_mason'];
const loadouts=Object.fromEntries(roster.map(id=>[id,defaultLoadout(id)]));
loadouts.oh_tipi=['frostbite',...loadouts.oh_tipi.filter(id=>id!=='frostbite').slice(0,3)];
const mapId='frontier:QA-RIVER-42';
assert.equal((await call('/api/rooms','POST',{name:'QA Invalid',roster,loadouts:{[roster[0]]:['forged']}})).status,400);
const malformedMap=await call('/api/rooms','POST',{name:'QA Invalid Map',roster,mapId:'frontier:bad/seed'});
assert.equal(malformedMap.status,400);assert.equal(malformedMap.data.code,'INVALID_MAP');
assert.equal((await call('/api/rooms','POST',{name:'QA Old',roster},undefined,7)).status,426);
const first=await call('/api/rooms','POST',{name:'QA Host',roster,loadouts,mapId:'  frontier:qa-river-42  '});
expectStatus(first,201);
assert.equal(first.data.room.rulesVersion,8);
assert.equal(first.data.room.mapId,mapId);
assert.equal(first.data.room.matchId,null);
assert.deepEqual(first.data.room.players[0].loadouts,loadouts);
const {code,token:hostToken}=first.data;
// Use the production client helper and browser-compatible Web Crypto generation.
// A memory-backed Storage interface models the retained browser key; no token
// appears in the result report or on disk.
const browserValues=new Map();
const browserStorage={getItem:key=>browserValues.get(key)??null,setItem:(key,value)=>browserValues.set(key,value),removeItem:key=>browserValues.delete(key)};
const guestClient=createClientSessionStore([{kind:'local',storage:browserStorage}]);
const pending=guestClient.getPendingJoin(code);
assert.equal(pending.persistence,'local');assert.ok(/^[a-f0-9]{64}$/.test(pending.token),'generated player key must have the expected format');
assert.equal(guestClient.readSeat(code),null,'a pending join is not an accepted seat');
const guestInput={name:'QA Guest',roster:['grace_reava','haara','s_wayne'],mapId:'frontier:IGNORED-JOIN-SEED',joinToken:pending.token};
const malformedJoin=await call(`${roomPath(code)}/join`,'POST',{...guestInput,joinToken:'invalid'});
assert.equal(malformedJoin.status,400);assert.equal(malformedJoin.data.code,'INVALID_JOIN_TOKEN');
const concurrentJoins=await Promise.all([0,1].map(()=>call(`${roomPath(code)}/join`,'POST',guestInput)));
for(const result of concurrentJoins){expectStatus(result,200);assert.ok(result.data.token===pending.token,'a repeated join must return its retained player key');assert.equal(result.data.seat,1)}
assert.deepEqual(concurrentJoins[0].data.room,concurrentJoins[1].data.room,'duplicate join requests must recover one authoritative seat');
assert.equal(concurrentJoins[0].data.room.version,1,'duplicate joins must not start or modify the match twice');
// Simulate both successful responses being lost before the client installs a
// seat. A reloaded client must reuse its previously retained pending identity.
assert.equal(guestClient.readSeat(code),null);
const reloadedGuest=createClientSessionStore([{kind:'local',storage:browserStorage}]);
const retained=reloadedGuest.getPendingJoin(code);
assert.ok(retained.token===pending.token,'reload must retain the pending player key');
const second=await call(`${roomPath(code)}/join`,'POST',{...guestInput,joinToken:retained.token});
expectStatus(second,200);
assert.ok(second.data.token===retained.token,'join recovery must return the retained player key');assert.deepEqual(second.data.room,concurrentJoins[0].data.room);
reloadedGuest.rememberSeat({code,token:second.data.token,seat:second.data.seat});
assert.ok(reloadedGuest.readSeat(code).token===retained.token,'the recovered seat must retain its player key');
const outsider=createClientSessionStore([]).getPendingJoin(code);
assert.ok(outsider.token!==retained.token,'different clients must have different player keys');
const wrongJoinKey=await call(`${roomPath(code)}/join`,'POST',{...guestInput,joinToken:outsider.token});
assert.equal(wrongJoinKey.status,409);assert.equal(wrongJoinKey.data.code,'ROOM_FULL');
const tokens=[hostToken,second.data.token];let room=second.data.room;
assert.equal(room.state.rulesVersion,8);
assert.equal(room.state.cells.length,BOARD_SIZE);
assert.equal(room.mapId,mapId);assert.equal(room.state.mapId,mapId);
const seededMap=createSimGame([room.players[0].roster,room.players[1].roster],mapId,[room.players[0].loadouts,room.players[1].loadouts]);
assert.deepEqual(room.state,seededMap,'the public map must reproduce the host seed exactly');
assert.match(room.matchId,/^[a-f0-9-]{36}$/);
assert.deepEqual(room.locked,[false,false]);
for(const unit of room.state.units)assert.deepEqual(unit.loadout,room.players[unit.owner].loadouts[unit.championId]);
assert.equal((await call(roomPath(code),'GET',undefined,hostToken,7)).status,426,'cached v7 clients must refresh for v8 games');
assert.equal((await call(roomPath(code))).status,401);
assert.equal((await call(`${roomPath(code)}/action`,'POST',{version:room.version,action:{type:'end'}},tokens[0])).status,409);
const baseline=room.state,originalMatchId=room.matchId;
const own=baseline.units.find(unit=>unit.owner===0),foreign=baseline.units.find(unit=>unit.owner===1);
const ownSignature=getSignature(own.championId),foreignSignature=getSignature(foreign.championId);
assert.equal(own.loadout.length,4);assert.ok(!own.loadout.includes(ownSignature.id),'signature is an additional owned action');
const signatureInKit=await call('/api/rooms','POST',{name:'QA Invalid Signature Kit',roster,loadouts:{[own.championId]:[ownSignature.id,...own.loadout.slice(1)]}});
assert.equal(signatureInKit.status,400);assert.equal(signatureInKit.data.code,'INVALID_LOADOUT');
const unequipped=SPELLS.find(spell=>!own.loadout.includes(spell.id)).id;
for(const order of [{unitId:foreign.id,guard:true},{unitId:own.id,cast:{q:own.q,r:own.r},spellId:'forged_spell'},{unitId:own.id,cast:{q:own.q,r:own.r},spellId:unequipped},{unitId:own.id,cast:{q:own.q,r:own.r},spellId:foreignSignature.id},{unitId:own.id,cast:{q:own.q,r:own.r}}]){
 const invalid=await call(`${roomPath(code)}/plan`,'POST',planInput(room,{orders:[order]}),tokens[0]);
 expectStatus(invalid,400);
}
const signatureTarget=legalCasts(baseline,own.id,undefined,ownSignature.id)[0];
assert.ok(signatureTarget,'own signature must be available at the start of the match');
const freezingUnit=baseline.units.find(unit=>unit.owner===0&&unit.championId==='oh_tipi');
const iceTarget={q:freezingUnit.q,r:freezingUnit.r};
const firstPlans=[{orders:[{unitId:own.id,cast:{q:signatureTarget.q,r:signatureTarget.r},spellId:ownSignature.id},{unitId:freezingUnit.id,cast:iceTarget,spellId:'frostbite'}]},chooseAIPlan(baseline,1)];
for(const plan of firstPlans)for(const order of plan.orders)if(order.cast)assert.equal(typeof order.spellId,'string');
const originalInputs=firstPlans.map(plan=>planInput(room,plan));
const firstLock=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
expectStatus(firstLock,200);
assert.deepEqual(firstLock.data.room.state,baseline);
assert.deepEqual(firstLock.data.room.locked,[true,false]);
assert.ok(firstLock.data.room.yourPlan);
assert.equal(firstLock.data.room.yourPlan.orders.find(order=>order.unitId===own.id).spellId,ownSignature.id);
const peerBefore=await readRoom(code,tokens[1]);
assert.deepEqual(peerBefore.data.room.state,baseline);
assert.deepEqual(peerBefore.data.room.players[0].loadouts,loadouts);
assert.equal(peerBefore.data.room.yourPlan,undefined);
for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v8',hostToken])assert.ok(!JSON.stringify(peerBefore.data.room).includes(secret));
const retry=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
expectStatus(retry,200);assert.equal(retry.data.room.version,firstLock.data.room.version);
const race=await Promise.all([0,1].map(()=>call(`${roomPath(code)}/plan`,'POST',originalInputs[1],tokens[1])));
for(const result of race)expectStatus(result,200);
room=(await readRoom(code,tokens[0])).data.room;
assert.equal(room.version,second.data.room.version+2);
assert.equal(room.state.version,baseline.version+1);
assert.deepEqual(room.locked,[false,false]);
assert.equal(room.state.cells.find(cell=>cell.q===iceTarget.q&&cell.r===iceTarget.r).ice,true,'server Ice metadata must reach both clients and pass strict restore');
const resolvedRetry=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
expectStatus(resolvedRetry,200);assert.equal(resolvedRetry.data.room.version,room.version);
const stale=await call(`${roomPath(code)}/plan`,'POST',{...originalInputs[0],plan:{orders:[{unitId:'old-round-probe'}]}},tokens[0]);
assert.equal(stale.status,409);assert.equal(stale.data.code,'STALE_ROUND');
let resolutions=1;
while(room.state.winner===null&&resolutions<MAX_ROUNDS){
 const before=room;
 const plans=[chooseAIPlan(before.state,0),chooseAIPlan(before.state,1)];
 const responses=await Promise.all(plans.map((plan,seat)=>call(`${roomPath(code)}/plan`,'POST',planInput(before,plan),tokens[seat])));
 for(const result of responses)expectStatus(result,200);
 room=(await readRoom(code,tokens[0])).data.room;
 assert.equal(room.version,before.version+2,'each pair of concurrent locks writes twice');
 assert.equal(room.state.version,before.state.version+1,'each round resolves exactly once');
 resolutions++;
}
assert.notEqual(room.state.winner,null,'match must complete within the round cap');
assert.equal(room.status,'finished');
const final={round:room.state.round,scores:room.state.scores,winner:room.state.winner,resolutions};
const snapshot0=await readRoom(code,tokens[0]);
const snapshot1=await readRoom(code,tokens[1]);
assert.deepEqual(snapshot0.data.room.state,snapshot1.data.room.state);
for(const snapshot of [snapshot0,snapshot1]){
 for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v8',...tokens])assert.ok(!JSON.stringify(snapshot.data.room).includes(secret));
}
const ask=await call(`${roomPath(code)}/rematch`,'POST',{version:room.version},tokens[0]);
expectStatus(ask,200);assert.equal(ask.data.room.status,'finished');
const accept=await call(`${roomPath(code)}/rematch`,'POST',{version:ask.data.room.version},tokens[1]);
expectStatus(accept,200);assert.equal(accept.data.room.status,'active');assert.equal(accept.data.room.state.round,1);
assert.equal(accept.data.room.rulesVersion,8);assert.deepEqual(accept.data.room.players[0].loadouts,loadouts);
assert.equal(accept.data.room.mapId,mapId);assert.equal(accept.data.room.state.mapId,mapId);assert.deepEqual(accept.data.room.state.cells,baseline.cells);
assert.notEqual(accept.data.room.matchId,originalMatchId);
const delayed=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
assert.equal(delayed.status,409);assert.equal(delayed.data.code,'STALE_MATCH');
console.log(JSON.stringify({origin,result:'PASS',mapId,checks:['create expanded roster','reject forged loadout','reject malformed map seed','canonical host seed reproduces exact map','join cannot override host seed','public configured loadouts','join defaults','pending join key persisted before HTTP','malformed pending join key rejected','concurrent same-key joins claim one seat','lost join success recovered with retained key','foreign join key rejected','authentication','protocol upgrade','foreign-unit rejection','forged and unequipped spell rejection','explicit spell required','signature cannot occupy a kit slot','foreign signature rejected','owned signature seals as fifth action','sealed first lock','own retry','concurrent second-lock retries','one resolution per round','stale round rejection','complete simultaneous match','strict restore of every authoritative round','server-produced Ice survives snapshot and restore','identical peer snapshots','no plan or token leak','mutual rematch preserves loadouts','mutual rematch preserves seed and geography','cross-rematch stale lock rejection'],final},null,2));
