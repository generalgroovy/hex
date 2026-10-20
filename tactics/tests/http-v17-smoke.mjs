import assert from 'node:assert/strict';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {chooseAIPlan,restoreSimState} from '../lib/tactics-v17.ts';
const origin=process.argv[2]||'http://127.0.0.1:8787';
const roundsLimit=Number(process.argv[3]||20);
let requests=0,checks=0;
const eq=(a,b,label)=>{assert.deepEqual(a,b,label);checks++},ok=(v,label)=>{assert.ok(v,label);checks++};
async function api(path,method='GET',body,token){requests++;const r=await fetch(origin+path,{method,headers:{'X-Confluence-Protocol':'17',...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify(body)}:{})});eq(r.headers.get('X-Confluence-Protocol'),'17');return {status:r.status,data:await r.json()};}
async function create(mode,count){
 const companies=Array.from({length:count},(_,seat)=>CHAMPIONS.slice(seat*3,seat*3+3).map(c=>canonicalBuild(c.id)));
 companies[0][0].name='River Keeper QA';
 const pending=()=>crypto.randomUUID().replaceAll('-','')+crypto.randomUUID().replaceAll('-','');
 const secret=pending(),body={action:'create',name:'Host QA',characters:companies[0],playerCount:count,mode,seed:'SIX-RIVERS-QA',clientToken:secret};
 const host=await api('/api/skirmishes','POST',body);eq(host.status,201);eq(host.data.token,secret);
 const again=await api('/api/skirmishes','POST',body);eq(again.status,201);eq(again.data.code,host.data.code);
 const code=host.data.code,path=`/api/skirmishes/${code}`,players=[host.data];
 const denied=await api(path);eq(denied.status,401);
 const joins=await Promise.all(companies.slice(1).map((characters,i)=>api('/api/skirmishes','POST',{action:'join',code,name:`Guest ${i+1}`,characters,clientToken:pending()})));
 for(const join of joins){eq(join.status,201);players.push(join.data)}players.sort((a,b)=>a.seat-b.seat);eq(players.map(p=>p.seat),Array.from({length:count},(_,i)=>i));
 eq((await api(path,'POST',{action:'start'},players[1].token)).status,403);
 eq((await api(path,'POST',{action:'start'},players[0].token)).status,409);
 await Promise.all(players.map(p=>api(path,'POST',{action:'ready',ready:true},p.token).then(r=>eq(r.status,200))));
 const start=await api(path,'POST',{action:'start'},players[0].token);eq(start.status,200);const room=start.data.room;eq(room.state.rulesVersion,17);eq(room.state.units.length,count*3);eq(room.affinityTotals,Array(count).fill(15));
 ok(!JSON.stringify(room).includes('tokenHash'));eq(restoreSimState(room.state),room.state);
 return {players,room,path};
}
const match=await create('free-for-all',6),{players,path}=match;let room=match.room,rounds=0;
const initial=room.state,originalId=room.matchId;
while(room.state.winner===null&&rounds<roundsLimit){
 const before=room,active=players.filter(p=>before.state.units.some(u=>u.owner===p.seat&&u.hp>0));
 const plans=active.map(p=>({p,plan:chooseAIPlan(before.state,p.seat)}));
 const first=plans[0],wire={action:'plan',matchId:before.matchId,round:before.state.round,plan:first.plan};
 const locked=await api(path,'POST',wire,first.p.token);eq(locked.status,200);
 if(plans.length>1){eq(locked.data.room.state,before.state);const peer=await api(path,'GET',undefined,plans[1].p.token);eq(peer.data.room.yourPlan,undefined);eq(peer.data.room.state,before.state);for(const secret of ['fingerprints','tokenHash',first.p.token])ok(!JSON.stringify(peer.data.room).includes(secret));}
 const rest=await Promise.all(plans.slice(1).map(({p,plan})=>api(path,'POST',{...wire,plan},p.token)));for(const r of rest)eq(r.status,200);
 room=(await api(path,'GET',undefined,players[0].token)).data.room;rounds++;
 eq(room.state.version,before.state.version+1);eq(restoreSimState(room.state),room.state);eq(room.state.units.map(u=>u.affinities),initial.units.map(u=>u.affinities));eq(room.state.units.map(u=>u.loadout),initial.units.map(u=>u.loadout));
 if(rounds===1){const retry=await api(path,'POST',wire,first.p.token);eq(retry.status,200);eq(retry.data.room.version,room.version);}
}
if(roundsLimit===20)ok(room.state.winner!==null,'the full six-company match terminates');
let rematch=false;
if(room.status==='finished'){
 for(const p of players){const r=await api(path,'POST',{action:'rematch',matchId:room.matchId},p.token);eq(r.status,200);if(p===players.at(-1)){eq(r.data.room.state.round,1);ok(r.data.room.matchId!==originalId);rematch=true;}}
 eq((await api(path,'POST',{action:'plan',matchId:originalId,round:1,plan:{orders:[]}},players[0].token)).status,409);
}
const team=await create('teams',6);eq(team.room.state.teams,[0,1,0,1,0,1]);
const results=await Promise.all(team.players.map(p=>api(team.path,'POST',{action:'plan',matchId:team.room.matchId,round:1,plan:{orders:[]}},p.token)));for(const r of results)eq(r.status,200);
eq((await api(team.path,'GET',undefined,team.players[0].token)).data.room.state.round,2);
console.log(JSON.stringify({origin,protocol:17,checks,requests,players:6,units:18,hexes:initial.cells.length,rounds,winner:room.state.winner,fullMatch:room.state.winner!==null,rematch,sealedOrders:true,concurrentJoins:true,concurrentPlans:true,balancedCompanies:true,teams:'3v3',teamsExchange:true}));
