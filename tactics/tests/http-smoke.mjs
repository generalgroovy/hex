import assert from 'node:assert/strict';
import {chooseAIPlan} from '../lib/sim.ts';

const origin=process.argv[2]||'http://127.0.0.1:5173';
async function call(path,method='GET',body,token){
 const response=await fetch(origin+path,{method,headers:{'X-Confluence-Protocol':'3',...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify({...body,protocolVersion:3})}:{})});
 const data=await response.json();return {status:response.status,data};
}
const roomPath=code=>`/api/rooms/${code}`;
const planInput=(room,plan)=>({matchId:room.matchId,round:room.state.round,plan});
const roster=['oh_tipi','wa_bidi','treevor_mason'];
const first=await call('/api/rooms','POST',{name:'QA Host',roster});
assert.equal(first.status,201,JSON.stringify(first.data));
assert.equal(first.data.room.rulesVersion,3);
assert.equal(first.data.room.matchId,null);
const {code,token:hostToken}=first.data;
const second=await call(`${roomPath(code)}/join`,'POST',{name:'QA Guest',roster:['grace_reava','haara','s_wayne']});
assert.equal(second.status,200,JSON.stringify(second.data));
const tokens=[hostToken,second.data.token];let room=second.data.room;
assert.equal(room.state.rulesVersion,3);
assert.match(room.matchId,/^[a-f0-9-]{36}$/);
assert.deepEqual(room.locked,[false,false]);
assert.equal((await fetch(origin+roomPath(code),{headers:{Authorization:`Bearer ${hostToken}`,'X-Confluence-Protocol':'2'}})).status,426,'cached alternating clients must refresh for new games');
assert.equal((await call(roomPath(code))).status,401);
assert.equal((await call(`${roomPath(code)}/action`,'POST',{version:room.version,action:{type:'end'}},tokens[0])).status,409);
const baseline=room.state,originalMatchId=room.matchId;
const foreign=baseline.units.find(unit=>unit.owner===1);
const invalid=await call(`${roomPath(code)}/plan`,'POST',planInput(room,{orders:[{unitId:foreign.id,guard:true}]}),tokens[0]);
assert.equal(invalid.status,400,JSON.stringify(invalid.data));
const firstPlans=[chooseAIPlan(baseline,0),chooseAIPlan(baseline,1)];
const originalInputs=firstPlans.map(plan=>planInput(room,plan));
const firstLock=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
assert.equal(firstLock.status,200,JSON.stringify(firstLock.data));
assert.deepEqual(firstLock.data.room.state,baseline);
assert.deepEqual(firstLock.data.room.locked,[true,false]);
assert.ok(firstLock.data.room.yourPlan);
const peerBefore=await call(roomPath(code),'GET',undefined,tokens[1]);
assert.deepEqual(peerBefore.data.room.state,baseline);
assert.equal(peerBefore.data.room.yourPlan,undefined);
for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v3',hostToken])assert.ok(!JSON.stringify(peerBefore.data.room).includes(secret));
const retry=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
assert.equal(retry.status,200);assert.equal(retry.data.room.version,firstLock.data.room.version);
const race=await Promise.all([0,1].map(()=>call(`${roomPath(code)}/plan`,'POST',originalInputs[1],tokens[1])));
for(const result of race)assert.equal(result.status,200,JSON.stringify(result.data));
room=(await call(roomPath(code),'GET',undefined,tokens[0])).data.room;
assert.equal(room.version,second.data.room.version+2);
assert.equal(room.state.version,baseline.version+1);
assert.deepEqual(room.locked,[false,false]);
const resolvedRetry=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
assert.equal(resolvedRetry.status,200);assert.equal(resolvedRetry.data.room.version,room.version);
let resolutions=1;
while(room.state.winner===null&&resolutions<20){
 const before=room;
 const plans=[chooseAIPlan(before.state,0),chooseAIPlan(before.state,1)];
 const responses=await Promise.all(plans.map((plan,seat)=>call(`${roomPath(code)}/plan`,'POST',planInput(before,plan),tokens[seat])));
 for(const result of responses)assert.equal(result.status,200,JSON.stringify(result.data));
 room=(await call(roomPath(code),'GET',undefined,tokens[0])).data.room;
 assert.equal(room.version,before.version+2,'each pair of concurrent locks writes twice');
 assert.equal(room.state.version,before.state.version+1,'each round resolves exactly once');
 resolutions++;
}
assert.notEqual(room.state.winner,null,'match must complete within the round cap');
assert.equal(room.status,'finished');
const final={round:room.state.round,scores:room.state.scores,winner:room.state.winner,resolutions};
const snapshot0=await call(roomPath(code),'GET',undefined,tokens[0]);
const snapshot1=await call(roomPath(code),'GET',undefined,tokens[1]);
assert.deepEqual(snapshot0.data.room.state,snapshot1.data.room.state);
for(const snapshot of [snapshot0,snapshot1]){
 for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v3',...tokens])assert.ok(!JSON.stringify(snapshot.data.room).includes(secret));
}
const ask=await call(`${roomPath(code)}/rematch`,'POST',{version:room.version},tokens[0]);
assert.equal(ask.status,200);assert.equal(ask.data.room.status,'finished');
const accept=await call(`${roomPath(code)}/rematch`,'POST',{version:ask.data.room.version},tokens[1]);
assert.equal(accept.status,200);assert.equal(accept.data.room.status,'active');assert.equal(accept.data.room.state.round,1);
assert.notEqual(accept.data.room.matchId,originalMatchId);
const delayed=await call(`${roomPath(code)}/plan`,'POST',originalInputs[0],tokens[0]);
assert.equal(delayed.status,409);assert.equal(delayed.data.code,'STALE_MATCH');
console.log(JSON.stringify({origin,result:'PASS',checks:['create','join','authentication','protocol upgrade','foreign-unit rejection','sealed first lock','own retry','concurrent second-lock retries','one resolution per round','complete simultaneous match','identical peer snapshots','no plan or token leak','mutual rematch','cross-rematch stale lock rejection'],final},null,2));
