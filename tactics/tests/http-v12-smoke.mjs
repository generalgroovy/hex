import assert from 'node:assert/strict';
import {choosePracticePlan} from '../lib/practice-v12.ts';
import {restoreSimState} from '../lib/tactics-v12.ts';
import {getChampion} from '../lib/roster-v11.ts';
const origin=process.argv[2]||'http://127.0.0.1:8787';
let requests=0,checks=0;
const equal=(a,b,label)=>{assert.deepEqual(a,b,label);checks++};
const ok=(a,label)=>{assert.ok(a,label);checks++};
async function api(path,method='GET',body,token,protocol=12){
 requests++;const response=await fetch(origin+path,{method,headers:{'X-Confluence-Protocol':String(protocol),...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify({...body,protocolVersion:protocol})}:{})});
 equal(response.headers.get('X-Confluence-Protocol'),'12','published protocol');
 const data=await response.json();return {status:response.status,data};
}
const roster=['oh_tipi','haara','treevor_mason'];
const host=await api('/api/rooms','POST',{name:'Field QA',roster,mapId:'frontier:LIVING-QA-42'});equal(host.status,201);
const {code,token}=host.data,path=`/api/rooms/${code}`;
const preview=await api(path+'/preview');equal(preview.status,200);equal(Object.keys(preview.data.preview).sort(),['affinityTotals','mapId','matchKind','status']);
const pending=crypto.randomUUID().replaceAll('-','')+crypto.randomUUID().replaceAll('-','');
const guest=await api(path+'/join','POST',{name:'River QA',roster,joinToken:pending});equal(guest.status,200);equal(guest.data.token,pending);
const recovered=await api(path+'/join','POST',{name:'Retry',roster,joinToken:pending});equal(recovered.status,200);equal(recovered.data.token,pending);equal(recovered.data.room.version,guest.data.room.version);
const tokens=[token,pending];let room=guest.data.room;
equal(room.rulesVersion,12);equal(room.state.inhabitants??[],[]);equal(room.affinityTotals,[15,15]);
const kits=room.state.units.map(unit=>unit.loadout),affinities=room.state.units.map(unit=>unit.affinities);
const input=(snapshot,plan)=>({matchId:snapshot.matchId,round:snapshot.state.round,plan});
for(const bad of [{orders:[],loadouts:[{unitId:room.state.units[0].id,spells:room.state.units[0].loadout}]},{orders:[],training:[{unitId:room.state.units[0].id,element:'fire'}]},{orders:[],inhabitants:[{speciesId:'worldseed',q:0,r:0}]}]){const r=await api(path+'/plan','POST',input(room,bad),token);equal(r.status,400);equal(r.data.code,'INVALID_PLAN')}
equal((await api(path,'GET',undefined,token,11)).status,426);
let rounds=0;const originalMatch=room.matchId;
while(room.state.winner===null&&rounds<20){
 const before=room,plans=[choosePracticePlan(before.state,0),choosePracticePlan(before.state,1)];
 const first=await api(path+'/plan','POST',input(before,plans[0]),tokens[0]);equal(first.status,200);equal(first.data.room.state,before.state);
 if(rounds===0){
  const peer=await api(path,'GET',undefined,tokens[1]);equal(peer.data.room.yourPlan,undefined);equal(peer.data.room.state,before.state);
  const retry=await api(path+'/plan','POST',input(before,plans[0]),tokens[0]);equal(retry.status,200);equal(retry.data.room.version,first.data.room.version);
  for(const secret of ['fingerprints','lastResolved','sealed-v12',token])ok(!JSON.stringify(peer.data.room).includes(secret),'sealed orders and credentials remain private');
 }
 const second=await api(path+'/plan','POST',input(before,plans[1]),tokens[1]);equal(second.status,200);room=second.data.room;rounds++;
 equal(room.state.version,before.state.version+1);equal(restoreSimState(room.state),room.state);
 equal(room.state.units.map(unit=>unit.loadout),kits);equal(room.state.units.map(unit=>unit.affinities),affinities);
 if(rounds===1){const retry=await api(path+'/plan','POST',input(before,plans[1]),tokens[1]);equal(retry.status,200);equal(retry.data.room.version,room.version)}
}
ok(room.state.winner!==null,'full online match reaches victory');
const peers=await Promise.all(tokens.map(t=>api(path,'GET',undefined,t)));equal(peers[0].data.room.state,peers[1].data.room.state);
const rematch0=await api(path+'/rematch','POST',{version:room.version},tokens[0]);equal(rematch0.status,200);
const rematch1=await api(path+'/rematch','POST',{version:rematch0.data.room.version},tokens[1]);equal(rematch1.status,200);equal(rematch1.data.room.state.round,1);equal(rematch1.data.room.state.units.map(u=>u.loadout),kits);ok(rematch1.data.room.matchId!==originalMatch);
const stale=await api(path+'/plan','POST',{matchId:originalMatch,round:1,plan:{orders:[]}},token);equal(stale.status,409);equal(stale.data.code,'STALE_MATCH');
const strong={oh_tipi:{...getChampion('oh_tipi').affinities,water:5}};
const competitive=await api('/api/rooms','POST',{name:'Equal QA',roster,affinities:strong,matchKind:'competitive'});equal(competitive.status,201);
const equalPath=`/api/rooms/${competitive.data.code}`;
const unequal=await api(equalPath+'/join','POST',{name:'Mismatch',roster});equal(unequal.status,409);equal(unequal.data.code,'AFFINITY_MISMATCH');
const open=await api(equalPath+'/preview');equal(open.data.preview.status,'waiting');equal(open.data.preview.affinityTotals,[17,null]);
const matched=await api(equalPath+'/join','POST',{name:'Matched',roster,affinities:strong});equal(matched.status,200);equal(matched.data.room.affinityTotals,[17,17]);
console.log(JSON.stringify({origin,protocol:12,checks,requests,rounds,winner:room.state.winner,scores:room.state.scores,fullMatch:true,rematch:true,sealedOrders:true,fixedKits:true,competitiveGauge:true}));
