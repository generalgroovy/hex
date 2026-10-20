import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {createRoom,joinRoom,getRoom,planInRoom,requestRematch,hashSecret,RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {planFingerprint} from '../lib/room-plans.ts';
import * as released from '../lib/tactics-v13.ts';
import * as current from '../lib/tactics-v14.ts';
import * as latest from '../lib/tactics-v16.ts';
import {getChampion} from '../lib/roster-v11.ts';

const now=1_800_000_000_000;
const host={protocolVersion:16,name:'Water',roster:['oh_tipi','wa_bidi','treevor_mason']};
const guest={protocolVersion:16,name:'Grove',roster:['haara','s_wayne','grace_reava']};
/** Actual production SQL with D1's asynchronous boundary. */
function database(){
 const sqlite=new DatabaseSync(':memory:'),folder=new URL('../drizzle/',import.meta.url);
 for(const file of readdirSync(folder).filter(f=>f.endsWith('.sql')).sort())sqlite.exec(readFileSync(new URL(file,folder),'utf8'));
 const db={prepare(sql:string){let values:(string|number|null)[]=[];
  const statement={bind(...parameters:(string|number|null)[]){values=parameters;return statement},
   async first<T>(){return (sqlite.prepare(sql).get(...values)??null) as T|null},
   async run(){return sqlite.prepare(sql).run(...values)}};
  return statement;
 }} as unknown as RoomDatabase;
 return {db,sqlite};
}

test('sealed v13 bytes and hidden orders survive v16 deployment, resolve under v13, then upgrade only by mutual rematch',async()=>{
 const {db,sqlite}=database();
 try{
  const created=await createRoom(db,host,now),joined=await joinRoom(db,created.code,guest,now+1);
  const affinity=[host,guest].map(team=>Object.fromEntries(team.roster.map(id=>{
   const champion=getChampion(id);return [id,{...champion.affinities,[champion.element]:champion.affinities[champion.element]!+1}];
  }))) as Parameters<typeof released.createSimGame>[4];
  const kits=[host,guest].map((team,owner)=>Object.fromEntries(team.roster.map(id=>[id,[...released.defaultLoadout(id,affinity![owner][id])].reverse()]))) as [Record<string,string[]>,Record<string,string[]>];
  const state=released.createSimGame([host.roster,guest.roster],'frontier:V13-COMBAT-FREEZE',kits,[[],[]],affinity);
  const unit=state.units.find(u=>u.id==='0-oh_tipi')!;
  const waterWitness=state.units.find(u=>u.id==='0-wa_bidi')!;
  const waterCell=state.cells.find(c=>c.terrain==='plain'&&!state.units.some(u=>u.q===c.q&&u.r===c.r))!;
  Object.assign(waterWitness,{q:waterCell.q,r:waterCell.r});
  Object.assign(waterCell,released.previewField(waterCell,['water']));
  assert.deepEqual(released.restoreSimState(state),state,'pending fixture is a valid released save with authentic seeded terrain');
  const raw:released.TeamPlan={orders:[{unitId:unit.id,cast:{q:unit.q,r:unit.r},spellId:'cleansing_tide'}]};
  const normalized=released.validatePlan(state,0,raw),fingerprint=await planFingerprint(raw,13);
  assert.equal(fingerprint,await hashSecret(JSON.stringify({rulesVersion:13,plan:raw})),'released fingerprint bytes are unchanged');
  assert.notEqual(fingerprint,await planFingerprint(raw,14));
  const squads=[host,guest].map((team,owner)=>JSON.stringify({roster:team.roster,loadouts:kits[owner],affinities:affinity![owner],learnedSignatures:[],matchKind:'casual'}));
  const bytes=JSON.stringify({format:'sealed-v13',matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null]});
  sqlite.prepare('UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?').run(bytes,state.mapId,...squads,created.code);
  const input={matchId:joined.room.matchId,round:1,plan:raw};
  for(const protocolVersion of [13,14,16]){
   const retry=(await planInRoom(db,created.code,created.token,{...input,protocolVersion},now+2)).room;
   assert.deepEqual(retry.yourPlan,normalized);assert.equal(retry.version,joined.room.version);
   const peer=(await getRoom(db,created.code,joined.token,now+3,protocolVersion)).room;
   assert.equal(peer.rulesVersion,13);assert.equal(peer.protocolVersion,16);
   assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.locked,[true,false]);assert.deepEqual(peer.state,state);
   for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v13',fingerprint,created.token,joined.token])assert.ok(!JSON.stringify(peer).includes(secret),secret);
   assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,bytes);
  }
  const empty={orders:[]};
  const resolved=(await planInRoom(db,created.code,joined.token,{...input,plan:empty,protocolVersion:14},now+4)).room;
  const expected=released.resolveRound(state,[raw,empty]);
  assert.deepEqual(resolved.state,expected);assert.equal(resolved.rulesVersion,13);
  assert.equal(expected.units.find(u=>u.id===waterWitness.id)!.statuses.wet,undefined);
  const modern=current.resolveRound({...state,rulesVersion:14},[raw,empty]);
  assert.ok(modern.units.find(u=>u.id===waterWitness.id)!.statuses.wet,'fixture distinguishes the old and new combat resolvers');
  assert.equal((await planInRoom(db,created.code,created.token,{...input,protocolVersion:14},now+5)).room.version,resolved.version,'lost response retry remains idempotent');
  const sealed=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
  sealed.state.winner=0;const finished=JSON.stringify(sealed);
  sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 13 WHERE code = ?").run(finished,created.code);
  const ended=(await getRoom(db,created.code,created.token,now+6,14)).room;
  assert.deepEqual(ended.rematch,[false,false],'consent to old rules cannot approve new combat');
  await assert.rejects(requestRematch(db,created.code,created.token,{protocolVersion:13,version:ended.version},now+7),e=>e instanceof RoomError&&e.code==='CLIENT_UPGRADE_REQUIRED');
  const first=(await requestRematch(db,created.code,joined.token,{protocolVersion:16,version:ended.version},now+8)).room;
  assert.equal(first.rulesVersion,13);assert.deepEqual(first.rematch,[false,true]);
  assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,finished);
  const next=(await requestRematch(db,created.code,created.token,{protocolVersion:16,version:first.version},now+9)).room;
  assert.equal(next.rulesVersion,16);assert.notEqual(next.matchId,joined.room.matchId);assert.equal(next.mapId,state.mapId);
  assert.deepEqual(next.players.map(p=>p!.loadouts),kits);assert.deepEqual(next.players.map(p=>p!.affinities),affinity);
  const reset=next.state as latest.SimState;
  assert.deepEqual(reset,latest.createSimGame([host.roster,guest.roster],state.mapId,kits,[[],[]],affinity));
  assert.deepEqual(next.locked,[false,false]);assert.deepEqual(next.rematch,[false,false]);
  await assert.rejects(getRoom(db,created.code,created.token,now+10,13),e=>e instanceof RoomError&&e.code==='CLIENT_UPGRADE_REQUIRED');
 }finally{sqlite.close()}
});
