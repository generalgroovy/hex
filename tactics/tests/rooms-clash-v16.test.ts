import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {createRoom,joinRoom,getRoom,planInRoom,requestRematch,hashSecret,RoomError,type RoomDatabase,type RoomSnapshot} from '../lib/rooms.ts';
import {canonicalPlan,planFingerprint} from '../lib/room-plans.ts';
import * as released from '../lib/tactics-v15.ts';
import * as current from '../lib/tactics-v16.ts';

const now=1_800_000_000_000;
const roster=['oh_tipi','wa_bidi','treevor_mason'];
const host={protocolVersion:16,name:'Water',roster};
const guest={protocolVersion:16,name:'Fire',roster};
function database(){
 const sqlite=new DatabaseSync(':memory:'),folder=new URL('../drizzle/',import.meta.url);
 for(const file of readdirSync(folder).filter(file=>file.endsWith('.sql')).sort())sqlite.exec(readFileSync(new URL(file,folder),'utf8'));
 const db={prepare(sql:string){let values:(string|number|null)[]=[];
  const statement={bind(...parameters:(string|number|null)[]){values=parameters;return statement},
   async first<T>(){return (sqlite.prepare(sql).get(...values)??null) as T|null},
   async run(){return sqlite.prepare(sql).run(...values)}};return statement;
 }} as unknown as RoomDatabase;
 return {db,sqlite};
}
const rejection=(code:string)=>(error:unknown)=>error instanceof RoomError&&error.code===code;
function crossingPlans(state:current.SimState|released.SimState):[current.TeamPlan,current.TeamPlan]{
 Object.assign(state.units[0],{q:-1,r:0});Object.assign(state.units[3],{q:1,r:0});
 return [{orders:[{unitId:state.units[0].id,spellId:'ember',cast:{q:1,r:0}}]},
  {orders:[{unitId:state.units[3].id,spellId:'water_jet',cast:{q:-1,r:0}}]}];
}
function assertNoPrivateEnvelope(room:RoomSnapshot,secrets:string[]=[]){
 const wire=JSON.stringify(room);
 for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v15','sealed-v16',...secrets])assert.ok(!wire.includes(secret),`Private envelope leaked: ${secret}`);
}

test('pending sealed-v15 bytes and fingerprint survive reads and retries; only both protocol16 rematch consents adopt clashes',async()=>{
 const {db,sqlite}=database();
 try{
  const created=await createRoom(db,host,now),joined=await joinRoom(db,created.code,guest,now+1);
  const state=released.createSimGame([roster,roster]),plans=crossingPlans(state);
  assert.deepEqual(released.restoreSimState(state),state);
  const normalized=released.validatePlan(state,0,plans[0]);
  const fingerprint=await planFingerprint(plans[0],15);
  assert.equal(fingerprint,await hashSecret(JSON.stringify({rulesVersion:15,plan:canonicalPlan(plans[0],15)})));
  assert.notEqual(fingerprint,await planFingerprint(plans[0],16));
  const bytes=JSON.stringify({format:'sealed-v15',matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null]});
  sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(bytes,created.code);
  const input={matchId:joined.room.matchId,round:1,plan:plans[0]};
  for(const protocolVersion of [15,16]){
   const retry=(await planInRoom(db,created.code,created.token,{...input,protocolVersion},now+2)).room;
   assert.equal(retry.version,joined.room.version);assert.deepEqual(retry.yourPlan,normalized);
   const peer=(await getRoom(db,created.code,joined.token,now+3,protocolVersion)).room;
   assert.equal(peer.rulesVersion,15);assert.equal(peer.protocolVersion,16);
   assert.deepEqual(peer.state,state);assert.deepEqual(peer.locked,[true,false]);assert.equal(peer.yourPlan,undefined);
   assertNoPrivateEnvelope(peer,[fingerprint,created.token,joined.token]);
   assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,bytes);
  }
  const resolved=(await planInRoom(db,created.code,joined.token,{...input,plan:plans[1],protocolVersion:15},now+4)).room;
  const expected=released.resolveRound(state,plans);
  assert.deepEqual(resolved.state,expected);assert.deepEqual(released.restoreSimState(expected),expected);
  assert.equal(resolved.rulesVersion,15);assert.ok(!expected.lastResolution.some(event=>String(event.kind)==='clash'));
  assert.ok(expected.lastResolution.some(event=>event.kind==='damage'),'Released15 must retain original target impacts');
  const modern=current.resolveRound({...state,rulesVersion:16},plans);
  assert.equal(modern.lastResolution.filter(event=>event.kind==='clash').length,1);
  assert.notDeepEqual(expected.units.map(unit=>unit.hp),modern.units.map(unit=>unit.hp));
  const resolvedBytes=sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string;
  for(const protocolVersion of [15,16]){
   const retry=(await planInRoom(db,created.code,created.token,{...input,protocolVersion},now+5)).room;
   assert.equal(retry.version,resolved.version);assert.deepEqual(retry.state,expected);
   assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,resolvedBytes);
  }
  const sealed=JSON.parse(resolvedBytes),finishedState=sealed.state as released.SimState;
  for(const unit of finishedState.units.filter(unit=>unit.owner===1)){
   unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;
  }
  finishedState.winner=0;finishedState.version=finishedState.round+1;
  assert.deepEqual(released.restoreSimState(finishedState),finishedState);
  const finished=JSON.stringify(sealed);
  sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 15 WHERE code = ?").run(finished,created.code);
  const ended=(await getRoom(db,created.code,created.token,now+6,15)).room;
  assert.deepEqual(ended.rematch,[false,false],'Previous-version consent cannot carry into new rules');
  await assert.rejects(requestRematch(db,created.code,created.token,{protocolVersion:15,version:ended.version},now+7),rejection('CLIENT_UPGRADE_REQUIRED'));
  const first=(await requestRematch(db,created.code,joined.token,{protocolVersion:16,version:ended.version},now+8)).room;
  assert.equal(first.rulesVersion,15);assert.deepEqual(first.rematch,[false,true]);
  assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,finished);
  const next=(await requestRematch(db,created.code,created.token,{protocolVersion:16,version:first.version},now+9)).room;
  assert.equal(next.rulesVersion,16);assert.notEqual(next.matchId,joined.room.matchId);
  assert.deepEqual(next.state,current.createSimGame([roster,roster],state.mapId));
  assert.deepEqual(next.players.map(player=>player!.loadouts),joined.room.players.map(player=>player!.loadouts));
  assert.deepEqual(next.players.map(player=>player!.affinities),joined.room.players.map(player=>player!.affinities));
  assert.deepEqual(next.rematch,[false,false]);assert.deepEqual(next.locked,[false,false]);
  await assert.rejects(getRoom(db,created.code,created.token,now+10,15),rejection('CLIENT_UPGRADE_REQUIRED'));
 }finally{sqlite.close()}
});

test('server rules16 hide pending projectile orders and publish a crossing volley exactly once under duplicate concurrent locks',async()=>{
 const {db,sqlite}=database();
 try{
  const created=await createRoom(db,host,now),joined=await joinRoom(db,created.code,guest,now+1);
  const state=joined.room.state as current.SimState,plans=crossingPlans(state);
  assert.deepEqual(current.restoreSimState(state),state);
  const stored=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
  assert.equal(stored.format,'sealed-v16');stored.state=state;
  sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(JSON.stringify(stored),created.code);
  const input={protocolVersion:16,matchId:joined.room.matchId,round:1};
  await assert.rejects(planInRoom(db,created.code,created.token,{...input,protocolVersion:15,plan:plans[0]},now+2),rejection('CLIENT_UPGRADE_REQUIRED'));
  const first=(await planInRoom(db,created.code,created.token,{...input,plan:plans[0]},now+3)).room;
  assert.deepEqual(first.locked,[true,false]);assert.deepEqual(first.state,state);
  const peer=(await getRoom(db,created.code,joined.token,now+4,16)).room;
  assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.state,state);assert.deepEqual(peer.state!.lastResolution,[]);
  assertNoPrivateEnvelope(peer,[created.token,joined.token,await planFingerprint(plans[0],16)]);
  const results=await Promise.all(Array.from({length:4},()=>planInRoom(db,created.code,joined.token,{...input,plan:plans[1]},now+5)));
  const expected=current.resolveRound(state,plans),result=results[0].room;
  assert.ok(results.every(response=>response.room.version===result.version));
  assert.equal(result.version,joined.room.version+2);assert.equal(expected.version,state.version+1);
  assert.deepEqual(result.state,expected);assert.deepEqual(current.restoreSimState(result.state),expected);
  const clash=expected.lastResolution.filter(event=>event.kind==='clash');
  assert.equal(clash.length,1);assert.equal(clash[0].terrain,'steam');assert.equal(clash[0].flightFraction,.5);
  assert.deepEqual(clash[0].meeting,{q:0,r:0});assert.deepEqual(clash[0].participants,['0-oh_tipi','1-oh_tipi']);
  assert.deepEqual(result.locked,[false,false]);assert.equal(result.yourPlan,undefined);assertNoPrivateEnvelope(result);
  const finalBytes=sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json;
  for(const [token,plan] of [[created.token,plans[0]],[joined.token,plans[1]]] as const){
   const retry=(await planInRoom(db,created.code,token,{...input,plan},now+6)).room;
   assert.equal(retry.version,result.version);assert.deepEqual(retry.state,expected);
   assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,finalBytes);
  }
  await assert.rejects(planInRoom(db,created.code,created.token,{...input,plan:{orders:[]}},now+7),rejection('STALE_ROUND'));
 }finally{sqlite.close()}
});
