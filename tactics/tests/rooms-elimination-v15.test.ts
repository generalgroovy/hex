import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {createRoom,joinRoom,getRoom,planInRoom,requestRematch,hashSecret,RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {planFingerprint} from '../lib/room-plans.ts';
import * as released from '../lib/tactics-v14.ts';
import * as current from '../lib/tactics-v16.ts';

const now=1_800_000_000_000,empty={orders:[]};
const host={protocolVersion:16,name:'Water',roster:['oh_tipi','wa_bidi','treevor_mason']};
const guest={protocolVersion:16,name:'Grove',roster:['haara','s_wayne','grace_reava']};
function database(){
 const sqlite=new DatabaseSync(':memory:'),folder=new URL('../drizzle/',import.meta.url);
 for(const file of readdirSync(folder).filter(f=>f.endsWith('.sql')).sort())sqlite.exec(readFileSync(new URL(file,folder),'utf8'));
 const db={prepare(sql:string){let values:(string|number|null)[]=[];
  const statement={bind(...parameters:(string|number|null)[]){values=parameters;return statement},
   async first<T>(){return (sqlite.prepare(sql).get(...values)??null) as T|null},
   async run(){return sqlite.prepare(sql).run(...values)}};return statement;
 }} as unknown as RoomDatabase;
 return {db,sqlite};
}
const rejection=(code:string)=>(error:unknown)=>error instanceof RoomError&&error.code===code;

test('a pending rules14 exchange preserves exact private bytes and resurrection rules until both players accept elimination',async()=>{
 const {db,sqlite}=database();
 try{
  const created=await createRoom(db,host,now),joined=await joinRoom(db,created.code,guest,now+1);
  const state=released.createSimGame([host.roster,guest.roster],'frontier:V14-ELIMINATION-FREEZE');
  const victim=state.units[0];victim.hp=1;victim.statuses.burn={turns:2,power:1};
  assert.deepEqual(released.restoreSimState(state),state);
  const raw:released.TeamPlan={orders:[{unitId:victim.id,guard:true}]},normalized=released.validatePlan(state,0,raw),fingerprint=await planFingerprint(raw,14);
  assert.equal(fingerprint,await hashSecret(JSON.stringify({rulesVersion:14,plan:raw})));
  assert.notEqual(fingerprint,await planFingerprint(raw,16),'new rules use a different fingerprint domain');
  const squads=([host,guest]).map((team,owner)=>JSON.stringify({roster:team.roster,loadouts:Object.fromEntries(state.units.filter(u=>u.owner===owner).map(u=>[u.championId,u.loadout])),affinities:Object.fromEntries(state.units.filter(u=>u.owner===owner).map(u=>[u.championId,u.affinities])),learnedSignatures:[],matchKind:'casual'}));
  const bytes=JSON.stringify({format:'sealed-v14',matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null]});
  sqlite.prepare('UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?').run(bytes,state.mapId,...squads,created.code);
  const input={matchId:joined.room.matchId,round:1,plan:raw};
  for(const protocolVersion of [14,16]){
   const retry=(await planInRoom(db,created.code,created.token,{...input,protocolVersion},now+2)).room;
   assert.deepEqual(retry.yourPlan,normalized);assert.equal(retry.version,joined.room.version);
   const peer=(await getRoom(db,created.code,joined.token,now+3,protocolVersion)).room;
   assert.equal(peer.rulesVersion,14);assert.equal(peer.protocolVersion,16);assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.locked,[true,false]);assert.deepEqual(peer.state,state);
   for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v14',fingerprint,created.token,joined.token])assert.ok(!JSON.stringify(peer).includes(secret),secret);
   assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,bytes);
  }
  const resolved=(await planInRoom(db,created.code,joined.token,{...input,plan:empty,protocolVersion:14},now+4)).room;
  const expected=released.resolveRound(state,[raw,empty]);assert.deepEqual(resolved.state,expected);assert.equal(resolved.rulesVersion,14);
  assert.ok(expected.units[0].respawn!==undefined,'old match retains resurrection and scoring');assert.deepEqual(released.restoreSimState(expected),expected);
  const modern=current.resolveRound({...state,rulesVersion:16},[raw,empty]);
  assert.equal(modern.units[0].hp,0);assert.equal(modern.units[0].respawn,undefined);assert.deepEqual(modern.scores,[0,0]);
  assert.equal((await planInRoom(db,created.code,created.token,{...input,protocolVersion:16},now+5)).room.version,resolved.version);
  const sealed=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
  sealed.state.winner=0;const finished=JSON.stringify(sealed);
  sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 14 WHERE code = ?").run(finished,created.code);
  const ended=(await getRoom(db,created.code,created.token,now+6,14)).room;assert.deepEqual(ended.rematch,[false,false]);
  await assert.rejects(requestRematch(db,created.code,created.token,{protocolVersion:14,version:ended.version},now+7),rejection('CLIENT_UPGRADE_REQUIRED'));
  const first=(await requestRematch(db,created.code,joined.token,{protocolVersion:16,version:ended.version},now+8)).room;
  assert.equal(first.rulesVersion,14);assert.deepEqual(first.rematch,[false,true]);assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,finished);
  const next=(await requestRematch(db,created.code,created.token,{protocolVersion:16,version:first.version},now+9)).room;
  assert.equal(next.rulesVersion,16);assert.notEqual(next.matchId,joined.room.matchId);assert.equal(next.mapId,state.mapId);
  assert.deepEqual(next.state,current.createSimGame([host.roster,guest.roster],state.mapId));
  assert.deepEqual(next.players.map(p=>p!.loadouts),squads.map(s=>JSON.parse(s).loadouts));assert.deepEqual(next.players.map(p=>p!.affinities),squads.map(s=>JSON.parse(s).affinities));
  await assert.rejects(getRoom(db,created.code,created.token,now+10,14),rejection('CLIENT_UPGRADE_REQUIRED'));
 }finally{sqlite.close()}
});

test('rules15 resolves one elimination exactly once, hides orders until resolution, and keeps defeated characters down',async()=>{
 const {db,sqlite}=database();
 try{
  const created=await createRoom(db,host,now),joined=await joinRoom(db,created.code,guest,now+1);
  const state=joined.room.state as current.SimState;assert.equal(state.rulesVersion,16);
  // Real seeded state, legal wounded statuses: all three rival units succumb in
  // the same exchange, so transport must finish through the elimination engine.
  for(const unit of state.units.filter(u=>u.owner===1)){unit.hp=1;unit.statuses.burn={turns:2,power:1};}
  assert.deepEqual(current.restoreSimState(state),state);
  const sealed=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);sealed.state=state;
  sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(JSON.stringify(sealed),created.code);
  const input={protocolVersion:16,matchId:joined.room.matchId,round:1,plan:empty};
  await assert.rejects(planInRoom(db,created.code,created.token,{...input,protocolVersion:14},now+2),rejection('CLIENT_UPGRADE_REQUIRED'));
  const first=(await planInRoom(db,created.code,created.token,input,now+3)).room;
  assert.deepEqual(first.state,state);assert.deepEqual(first.locked,[true,false]);
  const peer=(await getRoom(db,created.code,joined.token,now+4,16)).room;assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.state,state);
  const results=await Promise.all([planInRoom(db,created.code,joined.token,input,now+5),planInRoom(db,created.code,joined.token,input,now+5)]);
  assert.equal(results[0].room.version,results[1].room.version);
  const result=results[0].room,next=result.state as current.SimState;
  assert.equal(result.status,'finished');assert.equal(next.winner,0);assert.equal(next.version,state.version+1);assert.deepEqual(next.scores,[0,0]);
  assert.deepEqual(next,current.resolveRound(state,[empty,empty]));assert.deepEqual(current.restoreSimState(next),next);
  assert.ok(next.units.filter(u=>u.owner===1).every(u=>u.hp===0&&u.respawn===undefined));assert.ok(next.lastResolution.every(e=>e.kind!=='score'&&e.kind!=='respawn'));
  const retry=(await planInRoom(db,created.code,created.token,input,now+6)).room;assert.equal(retry.version,result.version);assert.deepEqual(retry.state,next);
  await assert.rejects(planInRoom(db,created.code,created.token,{...input,plan:{orders:[{unitId:next.units[0].id,guard:true}]}},now+7),rejection('MATCH_NOT_ACTIVE'));
 }finally{sqlite.close()}
});

test('rules15 simultaneous defeat is a draw and old create clients cannot silently start elimination',async()=>{
 const {db,sqlite}=database();
 try{
  await assert.rejects(createRoom(db,{...host,protocolVersion:14},now),rejection('CLIENT_UPGRADE_REQUIRED'));
  assert.equal(sqlite.prepare('SELECT COUNT(*) AS count FROM rooms').get()!.count,0);
  const created=await createRoom(db,host,now),joined=await joinRoom(db,created.code,guest,now+1),state=joined.room.state as current.SimState;
  for(const unit of state.units){unit.hp=1;unit.statuses.burn={turns:2,power:1};}
  assert.deepEqual(current.restoreSimState(state),state);
  const sealed=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);sealed.state=state;
  sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(JSON.stringify(sealed),created.code);
  const input={protocolVersion:16,matchId:joined.room.matchId,round:1,plan:empty};
  await planInRoom(db,created.code,joined.token,input,now+2);
  const result=(await planInRoom(db,created.code,created.token,input,now+3)).room;
  assert.equal(result.status,'finished');assert.equal(result.state!.winner,'draw');assert.deepEqual(current.restoreSimState(result.state),result.state);
 }finally{sqlite.close()}
});
