import assert from 'node:assert/strict';
import {chooseAIPlan,createSimGame,BOARD_SIZE,MAX_ROUNDS,legalCasts,prepareTeam,restoreSimState} from '../lib/tactics-v11.ts';
import {defaultLoadout, SPELLS, SIGNATURES, getSignature} from '../lib/spells-v11.ts';
import {getChampion,validateAffinityAllocation} from '../lib/roster-v11.ts';
import {readLoadouts} from '../lib/loadouts-v11.ts';
import {createClientSessionStore} from '../lib/client-session-v11.ts';

const origin=process.argv[2]||'http://127.0.0.1:5173';
const diagnostic=result=>JSON.stringify({request:result.request,status:result.status,...(typeof result.data?.code==='string'&&/^[A-Z_]{1,64}$/.test(result.data.code)?{code:result.data.code}:{})});
function expectStatus(result,status){assert.equal(result.status,status,diagnostic(result))}
async function call(path,method='GET',body,token,protocolVersion=11){
 const request=`${method} ${path.replace(/\/api\/rooms\/[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}(?=\/|$)/,'/api/rooms/:code')}`;
 let response;try{response=await fetch(origin+path,{method,headers:{'X-Confluence-Protocol':String(protocolVersion),...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify({...body,protocolVersion})}:{})})}catch{throw new Error(`Network request failed: ${request}`)}
 assert.equal(response.headers.get('X-Confluence-Protocol'),'11',`${request}: HTTP ${response.status} must advertise protocol 11`);
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
const affinities=Object.fromEntries(roster.map(id=>[id,{...getChampion(id).affinities,...(id==='oh_tipi'?{water:5}:{})}]));
const learnedSignature=SIGNATURES.find(spell=>spell.element==='water'&&spell.signatureChampionId!=='oh_tipi'),learnedSignatures=[learnedSignature.id];
const malformedLibrary=await call('/api/rooms','POST',{name:'QA Library',roster,learnedSignatures:['forged']});expectStatus(malformedLibrary,400);assert.equal(malformedLibrary.data.code,'INVALID_SIGNATURE_LIBRARY');
assert.equal((await call('/api/rooms','POST',{name:'QA Invalid',roster,loadouts:{[roster[0]]:['forged']}})).status,400);
const lockedKit=await call('/api/rooms','POST',{name:'QA Locked Spell',roster,loadouts:{...loadouts,treevor_mason:['frostbite',...loadouts.treevor_mason.filter(id=>id!=='frostbite').slice(0,3)]}});
assert.equal(lockedKit.status,400);assert.equal(lockedKit.data.code,'INVALID_LOADOUT','three Water affinity points are required even when a client bypasses the catalogue');
const malformedMap=await call('/api/rooms','POST',{name:'QA Invalid Map',roster,mapId:'frontier:bad/seed'});
assert.equal(malformedMap.status,400);assert.equal(malformedMap.data.code,'INVALID_MAP');
assert.equal((await call('/api/rooms','POST',{name:'QA Old',roster},undefined,8)).status,426);
const first=await call('/api/rooms','POST',{name:'QA Host',roster,loadouts,learnedSignatures,affinities,matchKind:'casual',mapId:'  frontier:qa-river-42  '});
expectStatus(first,201);
assert.equal(first.data.room.rulesVersion,11);
assert.equal(first.data.room.mapId,mapId);
assert.equal(first.data.room.matchId,null);
assert.deepEqual(first.data.room.players[0].loadouts,loadouts);assert.deepEqual(first.data.room.players[0].learnedSignatures,learnedSignatures);
const preview=await call(`${roomPath(first.data.code)}/preview`);expectStatus(preview,200);
assert.deepEqual(preview.data,{preview:{status:'waiting',mapId,matchKind:'casual',affinityTotals:[17,null]}});
for(const secret of ['players','loadouts','learnedSignatures','state','token'])assert.ok(!JSON.stringify(preview.data).includes(secret));
const malformedAffinities=await call('/api/rooms','POST',{name:'QA Invalid Affinity',roster,affinities:{oh_tipi:{water:7}}});expectStatus(malformedAffinities,400);assert.equal(malformedAffinities.data.code,'INVALID_AFFINITIES');
const competitive=await call('/api/rooms','POST',{name:'QA Equal Host',roster,affinities,matchKind:'competitive',affinityTotal:15});expectStatus(competitive,201);assert.deepEqual(competitive.data.room.affinityTotals,[17,null]);
const equalPending=createClientSessionStore([]).getPendingJoin(competitive.data.code);
const unequal=await call(`${roomPath(competitive.data.code)}/join`,'POST',{name:'QA Equal Guest',roster,matchKind:'casual',affinityTotal:17,joinToken:equalPending.token});expectStatus(unequal,409);assert.equal(unequal.data.code,'AFFINITY_MISMATCH');assert.match(unequal.data.error,/host 17, your team 15/);
const stillOpen=await call(`${roomPath(competitive.data.code)}/preview`);expectStatus(stillOpen,200);assert.deepEqual(stillOpen.data.preview.affinityTotals,[17,null]);assert.equal(stillOpen.data.preview.status,'waiting');
const equalJoin=await call(`${roomPath(competitive.data.code)}/join`,'POST',{name:'QA Equal Guest',roster,affinities,matchKind:'casual',joinToken:equalPending.token});expectStatus(equalJoin,200);assert.equal(equalJoin.data.token,equalPending.token);assert.equal(equalJoin.data.room.matchKind,'competitive');assert.deepEqual(equalJoin.data.room.affinityTotals,[17,17]);
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
const lockedJoin=await call(`${roomPath(code)}/join`,'POST',{...guestInput,loadouts:{s_wayne:['frostbite','ember','water_jet','mend']}});
assert.equal(lockedJoin.status,400);assert.equal(lockedJoin.data.code,'INVALID_LOADOUT');
const stillWaiting=await readRoom(code,hostToken);
assert.equal(stillWaiting.data.room.status,'waiting');assert.equal(stillWaiting.data.room.players[1],null,'an invalid affinity kit cannot reserve the second player seat');
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
assert.equal(room.state.rulesVersion,11);assert.deepEqual(room.state.learnedSignatures,[learnedSignatures,[]]);
assert.equal(room.state.cells.length,BOARD_SIZE);
assert.equal(room.mapId,mapId);assert.equal(room.state.mapId,mapId);
const seededMap=createSimGame([room.players[0].roster,room.players[1].roster],mapId,[room.players[0].loadouts,room.players[1].loadouts],[learnedSignatures,[]],[room.players[0].affinities,room.players[1].affinities]);
assert.deepEqual(room.state,seededMap,'the public map must reproduce the host seed exactly');
assert.match(room.matchId,/^[a-f0-9-]{36}$/);
assert.deepEqual(room.locked,[false,false]);
for(const unit of room.state.units)assert.deepEqual(unit.loadout,room.players[unit.owner].loadouts[unit.championId]);
assert.equal((await call(roomPath(code),'GET',undefined,hostToken,8)).status,426,'cached v8 clients must refresh for v11 games');
assert.equal((await call(roomPath(code))).status,401);
assert.equal((await call(`${roomPath(code)}/action`,'POST',{version:room.version,action:{type:'end'}},tokens[0])).status,409);
const baseline=room.state,originalMatchId=room.matchId;
const own=baseline.units.find(unit=>unit.owner===0),foreign=baseline.units.find(unit=>unit.owner===1);
const ownSignature=getSignature(own.championId),foreignSignature=getSignature(foreign.championId);
assert.equal(own.loadout.length,4);assert.ok(!own.loadout.includes(ownSignature.id),'signature is an additional owned action');
const signatureInKit=await call('/api/rooms','POST',{name:'QA Invalid Signature Kit',roster,loadouts:{[own.championId]:[ownSignature.id,...own.loadout.slice(1)]}});
assert.equal(signatureInKit.status,400);assert.equal(signatureInKit.data.code,'INVALID_LOADOUT');
const unequipped=SPELLS.find(spell=>!own.loadout.includes(spell.id)).id;
const lockedCaster=baseline.units.find(unit=>unit.owner===0&&unit.championId==='treevor_mason');
for(const order of [{unitId:foreign.id,guard:true},{unitId:own.id,cast:{q:own.q,r:own.r},spellId:'forged_spell'},{unitId:own.id,cast:{q:own.q,r:own.r},spellId:unequipped},{unitId:own.id,cast:{q:own.q,r:own.r},spellId:foreignSignature.id},{unitId:lockedCaster.id,cast:{q:lockedCaster.q,r:lockedCaster.r},spellId:'frostbite'},{unitId:own.id,cast:{q:own.q,r:own.r}}]){
 const invalid=await call(`${roomPath(code)}/plan`,'POST',planInput(room,{orders:[order]}),tokens[0]);
 expectStatus(invalid,400);
}
const unearned=await call(`${roomPath(code)}/plan`,'POST',planInput(room,{orders:[],training:[{unitId:own.id,element:'fire'}]}),tokens[0]);
expectStatus(unearned,400);
const expandedLibrary=await call(`${roomPath(code)}/plan`,'POST',planInput(room,{orders:[],learnedSignatures:SIGNATURES.map(spell=>spell.id)}),tokens[0]);expectStatus(expandedLibrary,400);assert.equal(expandedLibrary.data.code,'INVALID_PLAN');
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
for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v11',hostToken])assert.ok(!JSON.stringify(peerBefore.data.room).includes(secret));
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
// Affinity is declared in camp and remains fixed even after multiple resolved rounds.
const beforeSecond=room;
for(const result of await Promise.all([0,1].map(seat=>call(`${roomPath(code)}/plan`,'POST',planInput(beforeSecond,{orders:[]}),tokens[seat]))))expectStatus(result,200);
room=(await readRoom(code,tokens[0])).data.room;
assert.equal(room.state.round,3);assert.deepEqual(room.affinityTotals,[17,15]);
const prepBaseline=room.state;
const trainee=prepBaseline.units.find(unit=>unit.owner===0&&unit.championId==='oh_tipi');
assert.equal(trainee.affinities.water,5);
const trainedKit=['deep_freeze',...trainee.loadout.filter(id=>id!=='deep_freeze').slice(0,3)];
const equipmentPlan={loadouts:[{unitId:trainee.id,spells:trainedKit}],orders:[{unitId:trainee.id,spellId:'deep_freeze',cast:{q:trainee.q,r:trainee.r}}]};
for(const invalidPlan of [
 {orders:equipmentPlan.orders},
 {...equipmentPlan,training:[{unitId:trainee.id,element:'water'}]},
 {orders:[],training:[{unitId:foreign.id,element:'water'}]},
])expectStatus(await call(`${roomPath(code)}/plan`,'POST',planInput(room,invalidPlan),tokens[0]),400);
const equipmentInput=planInput(room,equipmentPlan);
const equipmentLock=await call(`${roomPath(code)}/plan`,'POST',equipmentInput,tokens[0]);
expectStatus(equipmentLock,200);assert.deepEqual(equipmentLock.data.room.state,prepBaseline);
assert.deepEqual(equipmentLock.data.room.yourPlan.loadouts,equipmentPlan.loadouts);
const peerBeforeEquip=await readRoom(code,tokens[1]);assert.deepEqual(peerBeforeEquip.data.room.state,prepBaseline);assert.equal(peerBeforeEquip.data.room.yourPlan,undefined);
const equipmentRetry=await call(`${roomPath(code)}/plan`,'POST',equipmentInput,tokens[0]);expectStatus(equipmentRetry,200);assert.equal(equipmentRetry.data.room.version,equipmentLock.data.room.version);
const changedEquipment=await call(`${roomPath(code)}/plan`,'POST',{...equipmentInput,plan:{...equipmentPlan,orders:[]}},tokens[0]);assert.equal(changedEquipment.status,409);assert.equal(changedEquipment.data.code,'PLAN_LOCKED');
const equipmentPeerInput=planInput(room,chooseAIPlan(prepBaseline,1));
for(const result of await Promise.all([0,1].map(()=>call(`${roomPath(code)}/plan`,'POST',equipmentPeerInput,tokens[1]))))expectStatus(result,200);
room=(await readRoom(code,tokens[0])).data.room;
assert.equal(room.state.version,prepBaseline.version+1);
const equippedUnit=room.state.units.find(unit=>unit.id===trainee.id);
assert.equal(equippedUnit.affinities.water,5);assert.deepEqual(equippedUnit.loadout,trainedKit);
validateAffinityAllocation(equippedUnit.affinities,18);
assert.ok(room.state.lastResolution.some(event=>event.kind==='cast'&&event.unitId===trainee.id&&event.spellId==='deep_freeze'));
const resolvedEquipmentRetry=await call(`${roomPath(code)}/plan`,'POST',equipmentInput,tokens[0]);expectStatus(resolvedEquipmentRetry,200);assert.equal(resolvedEquipmentRetry.data.room.version,room.version);
// The learned signature uses its five story-earned affinity points from match entry.
const fourth=room;
for(const result of await Promise.all([0,1].map(seat=>call(`${roomPath(code)}/plan`,'POST',planInput(fourth,{orders:[]}),tokens[seat]))))expectStatus(result,200);
room=(await readRoom(code,tokens[0])).data.room;assert.equal(room.state.round,5);
const borrower=room.state.units.find(unit=>unit.id===trainee.id),borrowedKit=[learnedSignature.id,...borrower.loadout.filter(id=>id!==learnedSignature.id).slice(0,3)];
const borrowPrep={orders:[],loadouts:[{unitId:borrower.id,spells:borrowedKit}]};
const projectedBorrow=prepareTeam(room.state,0,borrowPrep),borrowTarget=legalCasts(projectedBorrow,borrower.id,undefined,learnedSignature.id)[0];assert.ok(borrowTarget);
const borrowPlan={...borrowPrep,orders:[{unitId:borrower.id,spellId:learnedSignature.id,cast:{q:borrowTarget.q,r:borrowTarget.r}}]},borrowInput=planInput(room,borrowPlan);
const borrowLock=await call(`${roomPath(code)}/plan`,'POST',borrowInput,tokens[0]);expectStatus(borrowLock,200);assert.deepEqual(borrowLock.data.room.state,room.state);
const borrowerPeer=await readRoom(code,tokens[1]);assert.equal(borrowerPeer.data.room.yourPlan,undefined);
expectStatus(await call(`${roomPath(code)}/plan`,'POST',planInput(room,{orders:[]}),tokens[1]),200);
room=(await readRoom(code,tokens[0])).data.room;
assert.ok(room.state.lastResolution.some(event=>event.kind==='cast'&&event.spellId===learnedSignature.id&&event.unitId===borrower.id));
assert.deepEqual(room.state.learnedSignatures,[learnedSignatures,[]]);
const borrowRetry=await call(`${roomPath(code)}/plan`,'POST',borrowInput,tokens[0]);expectStatus(borrowRetry,200);assert.equal(borrowRetry.data.room.version,room.version);
let resolutions=5;
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
const rematchLoadouts=[0,1].map(seat=>{
 const latest=Object.fromEntries(room.state.units.filter(unit=>unit.owner===seat).map(unit=>[unit.championId,unit.loadout]));
 const repaired=readLoadouts(latest,false,room.state.learnedSignatures[seat],room.players[seat].affinities);
 return Object.fromEntries(room.players[seat].roster.map(id=>[id,repaired[id]]));
});
const snapshot0=await readRoom(code,tokens[0]);
const snapshot1=await readRoom(code,tokens[1]);
assert.deepEqual(snapshot0.data.room.state,snapshot1.data.room.state);
for(const snapshot of [snapshot0,snapshot1]){
 for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v11',...tokens])assert.ok(!JSON.stringify(snapshot.data.room).includes(secret));
}
const ask=await call(`${roomPath(code)}/rematch`,'POST',{version:room.version},tokens[0]);
expectStatus(ask,200);assert.equal(ask.data.room.status,'finished');
const accept=await call(`${roomPath(code)}/rematch`,'POST',{version:ask.data.room.version},tokens[1]);
expectStatus(accept,200);assert.equal(accept.data.room.status,'active');assert.equal(accept.data.room.state.round,1);
assert.equal(accept.data.room.rulesVersion,11);assert.deepEqual(accept.data.room.state.learnedSignatures,[learnedSignatures,[]]);
for(const seat of [0,1])assert.deepEqual(accept.data.room.players[seat].loadouts,rematchLoadouts[seat],'rematch preserves the final legal kit');
assert.equal(accept.data.room.mapId,mapId);assert.equal(accept.data.room.state.mapId,mapId);assert.deepEqual(accept.data.room.state.cells,baseline.cells);
for(const unit of accept.data.room.state.units){assert.deepEqual(unit.affinities,room.players[unit.owner].affinities[unit.championId],'rematch preserves story-earned affinity levels');assert.deepEqual(unit.loadout,rematchLoadouts[unit.owner][unit.championId],'rematch starts with the repaired final loadout')}
assert.notEqual(accept.data.room.matchId,originalMatchId);
const delayed=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
assert.equal(delayed.status,409);assert.equal(delayed.data.code,'STALE_MATCH');
console.log(JSON.stringify({origin,result:'PASS',mapId,checks:['invalid signature library rejected','declared libraries frozen','library cannot expand through plans','story-earned affinities accepted at entry','invalid affinity allocation rejected','server-derived totals ignore claimed total','casual uneven teams accepted with visible totals','invitation preview reveals only balancing metadata','competitive mismatch rejected before seat consumption','corrected same-key join accepted','joining body cannot loosen competitive mode','loadouts validated against declared affinity','malformed map rejected','canonical seeded map reproduces state','join cannot override seed','pending join identity retained','concurrent same-key joins claim one seat','lost success recovery','foreign key rejected','authentication','protocol upgrade','foreign-unit rejection','forged and unequipped spell rejection','explicit spell required','signature cannot occupy own kit','foreign signature rejected','owned signature fifth action','sealed first lock','own retry','concurrent lock retries','one resolution per round','stale round rejection','affinity cannot grow during battle','loadout preparation stays private','same-round equip and cast','changed sealed equipment rejected','equipment retry idempotent','borrowed learned signature cast','complete simultaneous match','strict restore each authoritative round','Ice snapshot metadata','identical peer snapshots','no plans or tokens leaked','rematch preserves final kits','rematch preserves affinity allocations','rematch preserves libraries','rematch preserves map','cross-rematch stale lock rejected'],final},null,2));
