import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";
import {
  ROOM_TTL_MS, RoomError, actInRoom, createRoom, getRoom, hashSecret, joinRoom,
  normalizeRoomCode, planInRoom, roomPreview, requestRematch, takeRateLimit, validateAction, validatePlayer,
} from "../lib/rooms.ts";
import type { RoomDatabase } from "../lib/rooms.ts";
import * as legacy from "../lib/game-v1.ts";
import { applyAction, chooseAIAction, createGame, legalTargets, movementPath, previewAction, previewPush, restoreGameState, rulesVersionOf } from "../lib/rules.ts";
import type { GameState } from "../lib/rules.ts";
import { createSimGame as createV3, resolveRound, validatePlan } from "../lib/sim.ts";
import type { SimState, TeamPlan } from "../lib/sim.ts";
import * as tactics from "../lib/tactics-v16.ts";
import * as releasedV12 from "../lib/tactics-v12.ts";
import * as releasedV11 from "../lib/tactics-v11.ts";
import * as releasedV10 from "../lib/tactics-v10.ts";
import {getChampion, teamAffinityTotal} from "../lib/roster-v11.ts";
import * as releasedV9 from "../lib/tactics-v9.ts";
import * as spellsV9 from "../lib/spells-v9.ts";
import * as releasedV8 from "../lib/tactics-v8.ts";
import { defaultLoadout as v8DefaultLoadout } from "../lib/spells-v8.ts";
import { readLoadouts } from "../lib/loadouts-v16.ts";
import * as releasedV7 from "../lib/tactics-v7.ts";
import { defaultLoadout as v7DefaultLoadout } from "../lib/spells-v7.ts";
import * as releasedV6 from "../lib/tactics.ts";
import { defaultLoadout as v6DefaultLoadout } from "../lib/spells.ts";
import * as releasedV4 from "../lib/tactics-v4.ts";
import * as releasedV5 from "../lib/tactics-v5.ts";
import { CHAMPIONS } from "../lib/roster-v7.ts";
import { defaultLoadout, getSignature, repairLoadout, spellAccess, SIGNATURES } from "../lib/spells-v16.ts";
import { canonicalPlan, planFingerprint } from "../lib/room-plans.ts";

const NOW = 1_800_000_000_000;
const host = { protocolVersion: 16, name: "Grace", roster: ["grace_reava", "oh_tipi", "haara"] };
const guest = { protocolVersion: 16, name: "Treevor", roster: ["treevor_mason", "wa_bidi", "s_wayne"] };

test('v16 online matches reject kit edits and creature orders without reserving a lock, including story-shaped seeds',async()=>{
  const {db,sqlite}=database();
  try{
    const creatures=[{speciesId:'inhabitant-2',q:0,r:0}];
    const created=await createRoom(db,{...host,mapId:'frontier:STORY-OH-TIPI',inhabitants:creatures},NOW);
    const joined=await joinRoom(db,created.code,{...guest,inhabitants:creatures},NOW+1);
    const initial=joined.room.state as tactics.SimState,unit=initial.units.find(entry=>entry.owner===0)!;
    assert.equal(initial.rulesVersion,16);
    assert.equal(initial.inhabitants,undefined,'a story-shaped seed and client declaration do not enable Story actors online');
    const baseline=sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json;
    const input={protocolVersion:16,matchId:joined.room.matchId,round:1};
    for(const plan of [
      {orders:[],loadouts:[{unitId:unit.id,spells:unit.loadout}]},
      {orders:[],loadouts:null},
      {orders:[],inhabitants:creatures},
      {orders:[],pulses:creatures},
      {orders:[],state:{...initial,inhabitants:creatures}},
    ])await assert.rejects(planInRoom(db,created.code,created.token,{...input,plan},NOW+2),roomError(400,'INVALID_PLAN'));
    await assert.rejects(planInRoom(db,created.code,created.token,{...input,plan:{orders:[{unitId:'inhabitant-2',guard:true}]}},NOW+2),roomError(400,'ILLEGAL_PLAN'));
    assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,baseline);
    const untouched=(await currentRoom(db,created.code,created.token,NOW+3)).room;
    assert.equal(untouched.version,joined.room.version);assert.deepEqual(untouched.locked,[false,false]);
    const valid={...input,plan:{orders:[],loadouts:[],training:[]}};
    await planInRoom(db,created.code,created.token,valid,NOW+4);
    const resolved=(await planInRoom(db,created.code,joined.token,valid,NOW+5)).room;
    const next=resolved.state as tactics.SimState;
    assert.equal(next.inhabitants,undefined);assert.ok(next.lastResolution.every(event=>event.kind!=='inhabitant'));
    assert.deepEqual(next.units.map(entry=>entry.loadout),initial.units.map(entry=>entry.loadout));
    assert.deepEqual(tactics.restoreSimState(next),next);
    await assert.rejects(planInRoom(db,created.code,created.token,{...input,round:2,plan:{orders:[],loadouts:[{unitId:unit.id,spells:unit.loadout}]}},NOW+6),roomError(400,'INVALID_PLAN'));
  }finally{sqlite.close()}
});

test('a pending released v11 equipment lock keeps its exact fingerprint and resolver through protocol13 deployment',async()=>{
  const {db,sqlite}=database();
  try{
    const created=await createRoom(db,host,NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    const state=releasedV11.createSimGame([host.roster,guest.roster],'frontier:V11-PENDING');
    const unit=state.units.find(entry=>entry.owner===0&&entry.championId==='oh_tipi')!;
    const kit=[...unit.loadout].reverse();
    const raw:releasedV11.TeamPlan={orders:[],loadouts:[{unitId:unit.id,spells:kit}]};
    const normalized=releasedV11.validatePlan(state,0,raw),fingerprint=await planFingerprint(raw,11);
    const serialized=JSON.stringify({format:'sealed-v11',matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null]});
    sqlite.prepare('UPDATE rooms SET state_json = ?, map_id = ? WHERE code = ?').run(serialized,state.mapId,created.code);
    const input={protocolVersion:11,matchId:joined.room.matchId,round:1,plan:raw};
    const retry=await planInRoom(db,created.code,created.token,input,NOW+2);
    assert.equal(retry.room.version,joined.room.version);assert.deepEqual(retry.room.yourPlan,normalized);
    assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,serialized,'retry does not rewrite released bytes');
    const peer=(await getRoom(db,created.code,joined.token,NOW+3,11)).room;
    assert.equal(peer.rulesVersion,11);assert.equal(peer.protocolVersion,16);assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.state,state);
    const resolved=await planInRoom(db,created.code,joined.token,{...input,plan:{orders:[]}},NOW+4);
    assert.deepEqual(resolved.room.state,releasedV11.resolveRound(state,[raw,{orders:[]}]));
    assert.deepEqual(releasedV11.restoreSimState(resolved.room.state),resolved.room.state);
    assert.deepEqual((resolved.room.state as releasedV11.SimState).units.find(entry=>entry.id===unit.id)!.loadout,kit);
    assert.equal((await planInRoom(db,created.code,created.token,input,NOW+5)).room.version,resolved.room.version);
    assert.equal((await planInRoom(db,created.code,created.token,{...input,protocolVersion:16},NOW+6)).room.version,resolved.room.version,'current client may recover the same released receipt');
    assert.throws(()=>canonicalPlan(raw,12),/fixed/,'only the new rules reject equipment mutation');
  }finally{sqlite.close()}
});

test('rules 16 rejects zero-affinity kits before writing a room or consuming a guest seat',async()=>{
  const {db,sqlite}=database();
  try{
    const invalidHost={...host,loadouts:{grace_reava:['radiant_bolt','mend','stone','water_jet']}};
    assert.equal(getChampion('grace_reava').affinities.earth,undefined);
    await assert.rejects(createRoom(db,invalidHost,NOW),roomError(400,'INVALID_LOADOUT'));
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS count FROM rooms').get()!.count,0);
    const created=await createRoom(db,host,NOW+1),joinToken='e'.repeat(64);
    const invalidGuest={...guest,joinToken,loadouts:{treevor_mason:['stone','gust','ember','mend']}};
    assert.equal(getChampion('treevor_mason').affinities.light,undefined);
    await assert.rejects(joinRoom(db,created.code,invalidGuest,NOW+2),roomError(400,'INVALID_LOADOUT'));
    assert.equal((await currentRoom(db,created.code,created.token,NOW+3)).room.players[1],null);
    const joined=await joinRoom(db,created.code,{...guest,joinToken},NOW+4);
    assert.equal(joined.room.rulesVersion,16);assert.equal(joined.token,joinToken);
  }finally{sqlite.close()}
});

test('released v12 off-affinity pending locks preserve exact bytes and secrecy until a mutually accepted v16 rematch repairs only illegal slots',async()=>{
  const {db,sqlite}=database();
  try{
    const created=await createRoom(db,host,NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    const kits=[host,guest].map(player=>Object.fromEntries(player.roster.map(id=>[id,releasedV12.defaultLoadout(id)]))) as [Record<string,string[]>,Record<string,string[]>];
    kits[0].grace_reava=['radiant_bolt','mend','stone','water_jet'];
    const state=releasedV12.createSimGame([host.roster,guest.roster],'frontier:V12-FROZEN-KIT',kits);
    const caster=state.units.find(unit=>unit.owner===0&&unit.championId==='grace_reava')!;
    assert.equal(caster.affinities.earth,undefined);
    assert.equal(releasedV12.spellAccess(caster.championId,'stone',caster.affinities).unlocked,true);
    assert.equal(spellAccess(caster.championId,'stone',caster.affinities).unlocked,false);
    const raw:releasedV12.TeamPlan={orders:[{unitId:caster.id,cast:{q:caster.q,r:caster.r},spellId:'stone'}]};
    const normalized=releasedV12.validatePlan(state,0,raw);
    const fingerprint=await hashSecret(JSON.stringify({rulesVersion:12,plan:raw}));
    assert.equal(await planFingerprint(raw,12),fingerprint,'published v12 fingerprint bytes remain exact');
    assert.notEqual(await planFingerprint(raw,16),fingerprint);
    const storedSquads=[host,guest].map((player,owner)=>JSON.stringify({roster:player.roster,loadouts:kits[owner],learnedSignatures:[],affinities:Object.fromEntries(state.units.filter(unit=>unit.owner===owner).map(unit=>[unit.championId,unit.affinities])),matchKind:'casual'}));
    const serialized=JSON.stringify({format:'sealed-v12',matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null]});
    sqlite.prepare('UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?').run(serialized,state.mapId,...storedSquads,created.code);
    const input={protocolVersion:12,matchId:joined.room.matchId,round:1,plan:raw};
    for(const protocolVersion of [12,16]){
      const retry=await planInRoom(db,created.code,created.token,{...input,protocolVersion},NOW+2);
      assert.equal(retry.room.version,joined.room.version);assert.deepEqual(retry.room.yourPlan,normalized);
      assert.deepEqual(retry.room.players[0].loadouts.grace_reava,kits[0].grace_reava);
      assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,serialized);
      const peer=(await getRoom(db,created.code,joined.token,NOW+3,protocolVersion)).room;
      assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.locked,[true,false]);assert.deepEqual(peer.state,state);
      for(const secret of ['"plans"','fingerprints','lastResolved','sealed-v12',fingerprint,created.token,joined.token])assert.ok(!JSON.stringify(peer).includes(secret));
    }
    const empty={orders:[]};
    const resolved=(await planInRoom(db,created.code,joined.token,{...input,plan:empty},NOW+4)).room;
    assert.equal(resolved.rulesVersion,12);
    assert.deepEqual(resolved.state,releasedV12.resolveRound(state,[raw,empty]));
    assert.deepEqual(releasedV12.restoreSimState(resolved.state),resolved.state);
    assert.ok((resolved.state as releasedV12.SimState).lastResolution.some(event=>event.kind==='cast'&&event.spellId==='stone'));
    for(const protocolVersion of [12,16])assert.equal((await planInRoom(db,created.code,created.token,{...input,protocolVersion},NOW+5)).room.version,resolved.version);
    const sealed=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
    assert.ok(sealed.lastResolved.fingerprints[0].includes(fingerprint));
    sealed.state.winner=0;
    const finished=JSON.stringify(sealed);
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 12 WHERE code = ?").run(finished,created.code);
    const ended=(await currentRoom(db,created.code,created.token,NOW+6)).room;
    assert.deepEqual(ended.rematch,[false,false],'old consent cannot accept changed access and Guard rules');
    await assert.rejects(requestRematch(db,created.code,created.token,{protocolVersion:12,version:ended.version},NOW+7),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
    const first=(await currentRematch(db,created.code,joined.token,{version:ended.version},NOW+8)).room;
    assert.equal(first.rulesVersion,12);assert.deepEqual(first.rematch,[false,true]);
    const preserved=sqlite.prepare('SELECT state_json, player0_roster, player1_roster FROM rooms WHERE code = ?').get(created.code)!;
    assert.deepEqual({...preserved},{state_json:finished,player0_roster:storedSquads[0],player1_roster:storedSquads[1]});
    const restarted=(await currentRematch(db,created.code,created.token,{version:first.version},NOW+9)).room;
    assert.equal(restarted.rulesVersion,16);assert.notEqual(restarted.matchId,joined.room.matchId);assert.equal(restarted.mapId,state.mapId);
    const repaired=restarted.players[0].loadouts.grace_reava;
    assert.equal(repaired[0],'radiant_bolt');assert.equal(repaired[1],'mend');assert.equal(repaired[3],'water_jet');
    assert.notEqual(repaired[2],'stone');assert.ok(repaired.every(id=>spellAccess(caster.championId,id,caster.affinities).unlocked));
    assert.deepEqual(restarted.players.map(player=>player!.affinities),storedSquads.map(json=>JSON.parse(json).affinities));
    assert.deepEqual(tactics.restoreSimState(restarted.state),restarted.state);
    await assert.rejects(getRoom(db,created.code,created.token,NOW+10,12),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
    await assert.rejects(planInRoom(db,created.code,created.token,{...input,protocolVersion:16},NOW+10),roomError(409,'STALE_MATCH'));
  }finally{sqlite.close()}
});

test("a retained pending join key recovers a lost success response without reopening the seat", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joinToken = "a".repeat(64);
    const accepted = await joinRoom(db, created.code, { ...guest, joinToken }, NOW + 1);
    // The first response may never reach the browser. Its pre-saved secret is
    // sufficient to recover the existing seat, without trusting name or roster.
    const recovered = await joinRoom(db, created.code, { ...guest, name: "Edited before retry", joinToken }, NOW + 2);
    assert.equal(recovered.token, joinToken);
    assert.equal(recovered.seat, 1);
    assert.equal(recovered.room.version, accepted.room.version);
    assert.deepEqual(recovered.room, accepted.room);
    assert.equal(sqlite.prepare("SELECT player1_token_hash FROM rooms WHERE code = ?").get(created.code)!.player1_token_hash, await hashSecret(joinToken));
    assert.ok(!String(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json).includes(joinToken));
    await assert.rejects(() => joinRoom(db, created.code, { ...guest, joinToken: "b".repeat(64) }, NOW + 3), roomError(409, "ROOM_FULL"));
    await assert.rejects(() => joinRoom(db, created.code, { ...guest, joinToken: created.token }, NOW + 3), roomError(409, "ROOM_FULL"));
    await assert.rejects(() => joinRoom(db, created.code, guest, NOW + 3), roomError(409, "ROOM_FULL"));
  } finally { sqlite.close(); }
});

test("concurrent copies of one pending join recover the same seat and resolve no round", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const input = { ...guest, joinToken: "c".repeat(64) };
    const results = await Promise.all([joinRoom(db, created.code, input, NOW + 1), joinRoom(db, created.code, input, NOW + 1)]);
    assert.deepEqual(results[0], results[1]);
    assert.equal(results[0].room.version, 1);
    assert.equal((results[0].room.state as tactics.SimState).round, 1);
    assert.deepEqual(results[0].room.locked, [false, false]);
  } finally { sqlite.close(); }
});

test("malformed pending join secrets fail before taking a seat", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    for (const joinToken of [null, 5, {}, [], "", "a".repeat(63), "A".repeat(64), "g".repeat(64)]) {
      await assert.rejects(() => joinRoom(db, created.code, { ...guest, joinToken }, NOW + 1), roomError(400, "INVALID_JOIN_TOKEN"));
    }
    assert.equal(sqlite.prepare("SELECT status FROM rooms WHERE code = ?").get(created.code)!.status, "waiting");
    assert.equal((await joinRoom(db, created.code, guest, NOW + 2)).room.status, "active", "released clients without a pending token continue to work");
  } finally { sqlite.close(); }
});

// Current reads/rematches use 16; released matches retain their own protocols.
const currentRoom = (db: RoomDatabase, code: string, token: string, now: number) => getRoom(db, code, token, now, 16);
const currentAction = (db: RoomDatabase, code: string, token: string, input: Record<string, unknown>, now: number) => actInRoom(db, code, token, { ...input, protocolVersion: 2 }, now);
const currentRematch = (db: RoomDatabase, code: string, token: string, input: Record<string, unknown>, now: number) => requestRematch(db, code, token, { ...input, protocolVersion: 16 }, now);

function storeClassic(sqlite: DatabaseSync, code: string, state: GameState = createGame([host.roster, guest.roster])) {
  sqlite.prepare("UPDATE rooms SET state_json = ? WHERE code = ?").run(JSON.stringify(state), code);
  return state;
}

function storeV3(sqlite: DatabaseSync, code: string, matchId: string) {
  const state = createV3([host.roster, guest.roster]);
  sqlite.prepare("UPDATE rooms SET state_json = ?, player0_roster = ?, player1_roster = ? WHERE code = ?").run(
    JSON.stringify({ format: "sealed-v3", matchId, state, plans: [null, null], fingerprints: [null, null] }),
    JSON.stringify(host.roster), JSON.stringify(guest.roster), code,
  );
  return state;
}

/** Execute production SQL against actual SQLite, preserving D1's async boundary. */
function database() {
  const sqlite = new DatabaseSync(":memory:");
  const migrationFolder = new URL("../drizzle/", import.meta.url);
  const migrations = readdirSync(migrationFolder).filter((file) => file.endsWith(".sql")).sort();
  assert.ok(migrations.length, "Generate the D1 schema with npm run db:generate before running room tests.");
  for (const file of migrations) sqlite.exec(readFileSync(new URL(file, migrationFolder), "utf8"));
  const db = {
    prepare(sql: string) {
      let values: (string | number | null)[] = [];
      const statement = {
        bind(...parameters: (string | number | null)[]) { values = parameters; return statement; },
        async first<T>() { return (sqlite.prepare(sql).get(...values) ?? null) as T | null; },
        async run() { return sqlite.prepare(sql).run(...values); },
      };
      return statement;
    },
  } as unknown as RoomDatabase;
  return { db, sqlite };
}

function roomError(status: number, code: string) {
  return (error: unknown) => error instanceof RoomError && error.status === status && error.code === code;
}

test("private room creates, starts, authenticates both seats, and never returns credential hashes", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    assert.match(created.code, /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/);
    assert.match(created.token, /^[a-f0-9]{64}$/);
    assert.equal(created.seat, 0);
    assert.equal(created.room.status, "waiting");
    assert.equal(created.room.state, null);
    assert.equal(created.room.players[1], null);
    assert.equal(created.room.expiresAt, NOW + ROOM_TTL_MS);
    const stored = sqlite.prepare("SELECT * FROM rooms WHERE code = ?").get(created.code)!;
    assert.equal(stored.player0_token_hash, await hashSecret(created.token));
    assert.ok(!JSON.stringify(stored).includes(created.token), "raw token must never be stored");

    const joined = await joinRoom(db, created.code.toLowerCase(), guest, NOW + 1);
    assert.equal(joined.seat, 1);
    assert.notEqual(joined.token, created.token);
    assert.equal(joined.room.status, "active");
    assert.equal(joined.room.version, 1);
    assert.equal(joined.room.players[1]?.name, "Treevor");
    assert.ok(joined.room.state);
    const read = await currentRoom(db, created.code, created.token, NOW + 2);
    assert.equal(read.room.yourSeat, 0);
    assert.equal(read.room.version, joined.room.version);
    assert.ok(!JSON.stringify(read).includes("token"), "snapshots must contain no token fields");
    assert.ok(!JSON.stringify(joined.room).includes(stored.player0_token_hash as string));
    await assert.rejects(currentRoom(db, created.code, "f".repeat(64), NOW), roomError(401, "UNAUTHORIZED"));
    await assert.rejects(currentRoom(db, created.code, "", NOW), roomError(401, "UNAUTHORIZED"));
  } finally { sqlite.close(); }
});

test("simultaneous join requests cannot claim the same seat", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const outcomes = await Promise.allSettled([
      joinRoom(db, created.code, { ...guest, name: "First" }, NOW + 1),
      joinRoom(db, created.code, { ...guest, name: "Second" }, NOW + 1),
    ]);
    const fulfilled = outcomes.filter((outcome) => outcome.status === "fulfilled");
    const rejected = outcomes.filter((outcome) => outcome.status === "rejected");
    assert.equal(fulfilled.length, 1);
    assert.equal(rejected.length, 1);
    assert.ok(roomError(409, "ROOM_FULL")(rejected[0].reason));
    const winner = fulfilled[0].value;
    const read = await currentRoom(db, created.code, winner.token, NOW + 2);
    assert.equal(read.room.yourSeat, 1);
    assert.equal(read.room.version, 1);
  } finally { sqlite.close(); }
});

test("the server rejects the wrong player, invalid actions, and duplicate concurrent turns", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    storeClassic(sqlite, created.code);
    const version = joined.room.version;
    await assert.rejects(
      currentAction(db, created.code, joined.token, { version, action: { type: "end" } }, NOW + 2),
      roomError(400, "ILLEGAL_ACTION"),
    );
    await assert.rejects(
      currentAction(db, created.code, created.token, { version, action: { type: "move", unitId: "foreign", q: 20, r: 20 } }, NOW + 2),
      roomError(400, "ILLEGAL_ACTION"),
    );
    assert.equal((await currentRoom(db, created.code, created.token, NOW + 2)).room.version, version);
    const outcomes = await Promise.allSettled([
      currentAction(db, created.code, created.token, { version, action: { type: "end" } }, NOW + 3),
      currentAction(db, created.code, created.token, { version, action: { type: "end" } }, NOW + 3),
    ]);
    assert.equal(outcomes.filter((outcome) => outcome.status === "fulfilled").length, 1);
    const rejected = outcomes.find((outcome) => outcome.status === "rejected");
    assert.ok(rejected?.status === "rejected" && roomError(409, "STALE_VERSION")(rejected.reason));
    const updated = (await currentRoom(db, created.code, joined.token, NOW + 4)).room;
    assert.equal(updated.version, version + 1);
    assert.equal((updated.state as GameState).turn, 1);
    await assert.rejects(
      currentAction(db, created.code, joined.token, { version, action: { type: "end" } }, NOW + 5),
      roomError(409, "STALE_VERSION"),
    );
    const next = await currentAction(db, created.code, joined.token, { version: updated.version, action: { type: "end" } }, NOW + 5);
    assert.equal(next.room.version, version + 2);
  } finally { sqlite.close(); }
});

test("a rematch requires consent from both authenticated seats", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    await assert.rejects(currentRematch(db, created.code, created.token, { version: joined.room.version }, NOW + 2), roomError(409, "MATCH_NOT_FINISHED"));
    const finished = { ...createGame([host.roster, guest.roster]), winner: 0 };
    sqlite.prepare("UPDATE rooms SET status = 'finished', state_json = ? WHERE code = ?").run(JSON.stringify(finished), created.code);
    const first = await currentRematch(db, created.code, created.token, { version: joined.room.version }, NOW + 3);
    assert.equal(first.room.status, "finished");
    assert.deepEqual(first.room.rematch, [true, false]);
    const repeat = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 3);
    assert.equal(repeat.room.version, first.room.version);
    assert.deepEqual(repeat.room.rematch, [true, false]);
    const second = await currentRematch(db, created.code, joined.token, { version: first.room.version }, NOW + 4);
    assert.equal(second.room.status, "active");
    assert.deepEqual(second.room.rematch, [false, false]);
    assert.equal(second.room.state?.winner, null);
    assert.equal(second.room.version, joined.room.version + 2);
  } finally { sqlite.close(); }
});

test("expired matches cannot be read, joined, or played", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const expired = NOW + ROOM_TTL_MS;
    await assert.rejects(currentRoom(db, created.code, created.token, expired), roomError(404, "ROOM_NOT_FOUND"));
    await assert.rejects(joinRoom(db, created.code, guest, expired), roomError(404, "ROOM_NOT_FOUND"));
    await assert.rejects(currentAction(db, created.code, created.token, { version: 0, action: { type: "end" } }, expired), roomError(404, "ROOM_NOT_FOUND"));
    await createRoom(db, host, expired);
    assert.equal(sqlite.prepare("SELECT code FROM rooms WHERE code = ?").get(created.code), undefined);
  } finally { sqlite.close(); }
});

test("durable rate limits are atomic and reset only at the next window", async () => {
  const { db, sqlite } = database();
  try {
    const results = await Promise.allSettled(Array.from({ length: 8 }, () => takeRateLimit(db, "203.0.113.1", "create", 3, 60_000, NOW)));
    assert.equal(results.filter((result) => result.status === "fulfilled").length, 3);
    assert.ok(results.filter((result) => result.status === "rejected").every((result) => roomError(429, "RATE_LIMITED")(result.reason)));
    assert.equal(sqlite.prepare("SELECT requests FROM room_rate_limits").get()?.requests, 3);
    assert.ok(!JSON.stringify(sqlite.prepare("SELECT * FROM room_rate_limits").all()).includes("203.0.113.1"));
    await takeRateLimit(db, "203.0.113.1", "create", 3, 60_000, NOW + 60_000);
    await takeRateLimit(db, "203.0.113.2", "create", 3, 60_000, NOW);
  } finally { sqlite.close(); }
});

test("input validation rejects malformed rosters, coordinates, versions, and codes", () => {
  assert.equal(validatePlayer({ ...host, name: " Grace " }).name, "Grace");
  for (const input of [null, {}, { ...host, name: "" }, { ...host, name: "a\nname" }, { ...host, roster: ["haara", "haara", "haara"] }, { ...host, roster: ["fake", "haara", "s_wayne"] }]) {
    assert.throws(() => validatePlayer(input), RoomError);
  }
  assert.equal(normalizeRoomCode("2345-6789-abcd"), "23456789ABCD");
  assert.throws(() => normalizeRoomCode("tiny"), RoomError);
  for (const input of [null, { version: -1, action: { type: "end" } }, { version: 0, action: { type: "hack" } }, { version: 0, action: { type: "move", unitId: "unit", q: 0.5, r: 2 } }]) {
    assert.throws(() => validateAction(input), RoomError);
  }
  assert.deepEqual(validateAction({ version: 1, action: { type: "end", ignored: true } }), { version: 1, action: { type: "end" } });
});

test("cached clients must reload before creating, joining, reading, or acting in new-rules matches", async () => {
  const { db, sqlite } = database();
  try {
    const oldHost = { name: host.name, roster: host.roster };
    await assert.rejects(createRoom(db, oldHost, NOW), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    assert.equal(sqlite.prepare("SELECT COUNT(*) AS count FROM rooms").get()?.count, 0);
    const created = await createRoom(db, host, NOW);
    assert.equal(created.room.rulesVersion, 16);
    assert.equal(created.room.protocolVersion, 16);
    await assert.rejects(createRoom(db, { ...host, protocolVersion: 6 }, NOW), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(joinRoom(db, created.code, { ...guest, protocolVersion: 6 }, NOW + 1), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 1, 6), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(createRoom(db, { ...host, protocolVersion: 2 }, NOW), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(joinRoom(db, created.code, { name: guest.name, roster: guest.roster }, NOW + 1), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 1), (error: unknown) => {
      assert.ok(error instanceof RoomError);
      assert.equal(error.status, 426);
      assert.equal(error.code, "CLIENT_UPGRADE_REQUIRED");
      assert.equal(error.reload, true);
      assert.equal(error.requiredProtocolVersion, 16);
      assert.match(error.message, /Reload this page/);
      return true;
    });
    const joined = await joinRoom(db, created.code, guest, NOW + 2);
    assert.equal(joined.room.state?.rulesVersion, 16);
    const input = { version: joined.room.version, action: { type: "end" } };
    await assert.rejects(actInRoom(db, created.code, created.token, input, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(actInRoom(db, created.code, created.token, { ...input, protocolVersion: 2 }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(actInRoom(db, created.code, created.token, { ...input, protocolVersion: 3 }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(actInRoom(db, created.code, created.token, { ...input, protocolVersion: 16 }, NOW + 3), roomError(409, "TEAM_PLAN_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 3, 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 3, "2"), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const unchanged = await currentRoom(db, created.code, created.token, NOW + 4);
    assert.equal(unchanged.room.version, joined.room.version);
    const classic = storeClassic(sqlite, created.code);
    assert.equal((await getRoom(db, created.code, created.token, NOW + 5, 2)).room.rulesVersion, 2);
    const guarded = await currentAction(db, created.code, created.token, { version: joined.room.version, action: { type: "guard", unitId: classic.units[0].id } }, NOW + 5);
    assert.equal(guarded.room.state?.units[0].guard, true);
    assert.equal(guarded.room.version, joined.room.version + 1);
  } finally { sqlite.close(); }
});

test("existing untagged matches retain the exact public v1 rules for cached and new clients", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = legacy.createGame([host.roster, guest.roster]);
    state.units[1].q = -1; state.units[1].r = 0;
    state.units[3].q = 0; state.units[3].r = 0;
    sqlite.prepare("UPDATE rooms SET state_json = ? WHERE code = ?").run(JSON.stringify(state), created.code);
    const oldRead = await getRoom(db, created.code, created.token, NOW + 2);
    const newRead = await currentRoom(db, created.code, created.token, NOW + 2);
    assert.equal(oldRead.room.rulesVersion, 1);
    assert.deepEqual(newRead.room.state, oldRead.room.state);
    const action: legacy.GameAction = { type: "cast", unitId: state.units[1].id, q: 0, r: 0 };
    const expected = legacy.applyAction(state, 0, action);
    const result = await actInRoom(db, created.code, created.token, { version: joined.room.version, action }, NOW + 3);
    assert.deepEqual(result.room.state, expected);
    assert.equal(result.room.rulesVersion, 1);
    assert.equal(result.room.state?.rulesVersion, undefined);
    await assert.rejects(currentAction(db, created.code, created.token, { version: result.room.version, action: { type: "guard", unitId: state.units[0].id } }, NOW + 4), roomError(400, "ILLEGAL_ACTION"));
    assert.equal((await currentRoom(db, created.code, created.token, NOW + 5)).room.version, result.room.version);
  } finally { sqlite.close(); }
});

test("legacy rematches upgrade only after both players consent with the new protocol", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = legacy.createGame([host.roster, guest.roster]); state.winner = 0;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 2 WHERE code = ?").run(JSON.stringify(state), created.code);
    const before = await currentRoom(db, created.code, created.token, NOW + 2);
    assert.deepEqual(before.room.rematch, [false, false], "old queued consent must not opt into changed rules");
    await assert.rejects(requestRematch(db, created.code, created.token, { version: before.room.version }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(requestRematch(db, created.code, created.token, { version: before.room.version, protocolVersion: 2 }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const first = await currentRematch(db, created.code, joined.token, { version: before.room.version }, NOW + 4);
    assert.equal(first.room.rulesVersion, 1);
    assert.equal(first.room.status, "finished");
    assert.deepEqual(first.room.rematch, [false, true]);
    const next = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 5);
    assert.equal(next.room.status, "active");
    assert.equal(next.room.rulesVersion, 16);
    assert.equal(next.room.state?.rulesVersion, 16);
    assert.deepEqual(next.room.rematch, [false, false]);
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 6), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
  } finally { sqlite.close(); }
});

test("local save restoration preserves legacy rules and rejects damaged or future saves without mutation", () => {
  const old = legacy.createGame([host.roster, guest.roster]);
  const serialized = JSON.stringify(old);
  const restored = restoreGameState(old);
  assert.deepEqual(restored, old);
  assert.notEqual(restored, old);
  assert.equal(rulesVersionOf(restored), 1);
  assert.deepEqual(legalTargets(restored, old.units[0].id, "cast"), legacy.legalTargets(old, old.units[0].id, "cast"));
  assert.deepEqual(chooseAIAction(restored), legacy.chooseAIAction(old));
  assert.equal(previewAction(restored, { type: "end" }), legacy.previewAction(old, { type: "end" }));
  assert.deepEqual(applyAction(restored, 0, { type: "end" }), legacy.applyAction(old, 0, { type: "end" }));
  assert.deepEqual(legalTargets(restored, old.units[0].id, "guard"), []);
  assert.throws(() => applyAction(restored, 0, { type: "guard", unitId: old.units[0].id }), /legacy match/);
  assert.equal(JSON.stringify(old), serialized);
  assert.equal(rulesVersionOf(restoreGameState(createGame())), 2);
  for (const broken of [null, {}, { ...old, rulesVersion: 3 }, { ...old, units: [] }, { ...old, scores: [NaN, 0] }, { ...old, cells: old.cells.slice(1) }, { ...old, units: [{ ...old.units[0], hp: "5" }, ...old.units.slice(1)] }]) {
    const before = JSON.stringify(broken);
    assert.throws(() => restoreGameState(broken));
    assert.equal(JSON.stringify(broken), before);
  }
});

test("legacy movement and push previews preserve original geometry before automatic respawn", () => {
  const state = legacy.createGame([host.roster, guest.roster]);
  const caster = state.units[0], target = state.units[3];
  caster.q = -1; caster.r = 0; target.q = 0; target.r = 0; target.hp = 3;
  const glass = legacy.getCell(state, 1, 0)!; glass.terrain = "glass"; glass.ttl = 2;
  state.ap = 1;
  const before = JSON.stringify(state);
  assert.deepEqual(movementPath(state, caster, { q: -1, r: -1 }), legacy.movementPath(state, caster, { q: -1, r: -1 }));
  assert.deepEqual(previewPush(state, caster.id, target.q, target.r), glass);
  assert.equal(JSON.stringify(state), before);
  target.hp = 2;
  assert.equal(previewPush(state, caster.id, target.q, target.r), undefined, "lethal spell hits do not push in the original rules");
});

test("sealed plans persist privately, remain immutable, and identical lock retries are idempotent", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = storeV3(sqlite, created.code, joined.room.matchId!);
    const plan: TeamPlan = { orders: [] };
    const input = { protocolVersion: 3, matchId: joined.room.matchId, round: state.round, plan };
    const locked = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.deepEqual(locked.room.locked, [true, false]);
    assert.deepEqual(locked.room.yourPlan, validatePlan(state, 0, plan));
    assert.deepEqual(locked.room.state, state, "locking must not expose a partially resolved board");
    assert.equal(locked.room.version, joined.room.version + 1);
    const repeat = await planInRoom(db, created.code, created.token, input, NOW + 3);
    assert.equal(repeat.room.version, locked.room.version);
    const normalizedRetry = await planInRoom(db, created.code, created.token, { ...input, plan: locked.room.yourPlan }, NOW + 3);
    assert.equal(normalizedRetry.room.version, locked.room.version, "recovered own normalized orders can be retried too");
    const peer = await currentRoom(db, created.code, joined.token, NOW + 4);
    assert.deepEqual(peer.room.locked, [true, false]);
    assert.equal(peer.room.yourPlan, undefined);
    assert.deepEqual(peer.room.state, state);
    for (const secret of ["plans", "fingerprints", "lastResolved", "sealed-v3", created.token, joined.token]) {
      assert.ok(!JSON.stringify(peer.room).includes(secret), `peer snapshot must not contain ${secret}`);
    }
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    assert.deepEqual(stored.plans[0], locked.room.yourPlan);
    assert.equal(stored.plans[1], null);
    const caster = state.units.find((unit) => unit.owner === 0)!;
    await assert.rejects(planInRoom(db, created.code, created.token, {
      ...input, plan: { orders: [{ unitId: caster.id, cast: { q: caster.q, r: caster.r } }] },
    }, NOW + 5), roomError(409, "PLAN_LOCKED"));
  } finally { sqlite.close(); }
});

test("both seats can lock the same round concurrently and resolve exactly once, including duplicate retries", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const initial = storeV3(sqlite, created.code, joined.room.matchId!);
    const plan: TeamPlan = { orders: [] };
    const input = { protocolVersion: 3, matchId: joined.room.matchId, round: initial.round, plan };
    const outcomes = await Promise.all([
      planInRoom(db, created.code, created.token, input, NOW + 2),
      planInRoom(db, created.code, joined.token, input, NOW + 2),
      planInRoom(db, created.code, created.token, input, NOW + 2),
      planInRoom(db, created.code, joined.token, input, NOW + 2),
    ]);
    assert.equal(outcomes.length, 4, "all identical retried submissions should be accepted");
    const latest = (await currentRoom(db, created.code, created.token, NOW + 3)).room;
    assert.equal(latest.version, joined.room.version + 2, "only two successful lock writes");
    assert.equal(latest.state!.version, initial.version + 1, "one engine resolution");
    assert.deepEqual(latest.state, resolveRound(initial, [plan, plan]));
    assert.deepEqual(latest.locked, [false, false]);
    assert.equal(latest.yourPlan, undefined);
    const again = await planInRoom(db, created.code, joined.token, input, NOW + 4);
    assert.equal(again.room.version, latest.version);
    assert.deepEqual(again.room.state, latest.state);
    await assert.rejects(planInRoom(db, created.code, joined.token, {
      ...input, plan: { orders: [{ unitId: initial.units.find((unit) => unit.owner === 1)!.id }] },
    }, NOW + 5), roomError(409, "STALE_ROUND"));
    const peer = (await currentRoom(db, created.code, joined.token, NOW + 5)).room;
    assert.deepEqual(latest.state, peer.state);
    assert.ok(!JSON.stringify(peer).includes("fingerprints"));
  } finally { sqlite.close(); }
});

test("concurrent conflicting plans from one seat lock only once and cannot impersonate the other team", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = storeV3(sqlite, created.code, joined.room.matchId!);
    const unit = state.units.find((entry) => entry.owner === 0)!;
    const input = { protocolVersion: 3, matchId: joined.room.matchId, round: state.round };
    await assert.rejects(planInRoom(db, created.code, created.token, {
      ...input, plan: { orders: [{ unitId: state.units.find((entry) => entry.owner === 1)!.id, guard: true }] },
    }, NOW + 2), roomError(400, "ILLEGAL_PLAN"));
    await assert.rejects(planInRoom(db, created.code, "f".repeat(64), { ...input, plan: { orders: [] } }, NOW + 2), roomError(401, "UNAUTHORIZED"));
    const outcomes = await Promise.allSettled([
      planInRoom(db, created.code, created.token, { ...input, plan: { orders: [] } }, NOW + 3),
      planInRoom(db, created.code, created.token, { ...input, plan: { orders: [{ unitId: unit.id, cast: { q: unit.q, r: unit.r } }] } }, NOW + 3),
    ]);
    assert.equal(outcomes.filter((outcome) => outcome.status === "fulfilled").length, 1);
    const rejected = outcomes.find((outcome) => outcome.status === "rejected");
    assert.ok(rejected?.status === "rejected" && roomError(409, "PLAN_LOCKED")(rejected.reason));
    assert.equal((await currentRoom(db, created.code, created.token, NOW + 4)).room.version, joined.room.version + 1);
  } finally { sqlite.close(); }
});

test("plan validation rejects malformed and incompatible submissions without changing the room", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = storeV3(sqlite, created.code, joined.room.matchId!);
    const unit = state.units.find((entry) => entry.owner === 0)!;
    for (const plan of [null, {}, { orders: [], plans: [] }, { orders: [{ unitId: unit.id, move: { q: Infinity, r: 0 } }] }, { orders: [{ unitId: unit.id }, { unitId: unit.id }] }]) {
      await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 3, matchId: joined.room.matchId, round: 1, plan }, NOW + 2), roomError(400, "INVALID_PLAN"));
    }
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 3, round: -1, plan: { orders: [] } }, NOW + 2), roomError(400, "INVALID_ROUND"));
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 2, round: 1, plan: { orders: [] } }, NOW + 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    assert.equal((await currentRoom(db, created.code, created.token, NOW + 3)).room.version, joined.room.version);
    storeClassic(sqlite, created.code);
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 3, matchId: joined.room.matchId, round: 1, plan: { orders: [] } }, NOW + 4), roomError(409, "CLASSIC_ACTION_REQUIRED"));
    const classic = await actInRoom(db, created.code, created.token, { protocolVersion: 3, version: joined.room.version, action: { type: "end" } }, NOW + 5);
    assert.equal(classic.room.rulesVersion, 2, "protocol3 clients can continue alternating matches");
  } finally { sqlite.close(); }
});

test("a delayed lock cannot cross a rematch even when both matches are on round one", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const previousMatchId = joined.room.matchId;
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    stored.state.winner = 0;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished' WHERE code = ?").run(JSON.stringify(stored), created.code);
    const first = await currentRematch(db, created.code, created.token, { version: joined.room.version }, NOW + 2);
    const next = await currentRematch(db, created.code, joined.token, { version: first.room.version }, NOW + 3);
    assert.notEqual(next.room.matchId, previousMatchId);
    assert.equal(next.room.state!.round, 1);
    await assert.rejects(planInRoom(db, created.code, created.token, {
      protocolVersion: 16, matchId: previousMatchId, round: 1, plan: { orders: [] },
    }, NOW + 4), roomError(409, "STALE_MATCH"));
    assert.deepEqual((await currentRoom(db, created.code, created.token, NOW + 5)).room.locked, [false, false]);
  } finally { sqlite.close(); }
});

test("all 30 canonical champions receive valid defaults and forged loadouts are rejected", async () => {
  assert.equal(CHAMPIONS.length, 30);
  for (const champion of CHAMPIONS) {
    const roster = [champion.id, ...CHAMPIONS.filter((entry) => entry.id !== champion.id).slice(0, 2).map((entry) => entry.id)];
    const player = validatePlayer({ name: "Squad", roster });
    assert.deepEqual(player.loadouts[champion.id], defaultLoadout(champion.id));
    assert.equal(new Set(player.loadouts[champion.id]).size, 4);
  }
  const defaults = defaultLoadout(host.roster[0]);
  for (const loadouts of [null, [], { foreign: defaults }, { [host.roster[0]]: [] },
    { [host.roster[0]]: [defaults[0], defaults[0], defaults[1], defaults[2]] },
    { [host.roster[0]]: ["forged_spell", ...defaults.slice(1)] },
    JSON.parse('{"__proto__":["ember","gust","stone","mend"]}')]) {
    assert.throws(() => validatePlayer({ ...host, loadouts }), roomError(400, "INVALID_LOADOUT"));
  }
  const { db, sqlite } = database();
  try {
    await assert.rejects(createRoom(db, { ...host, loadouts: { [host.roster[0]]: ["forged"] } }, NOW), roomError(400, "INVALID_LOADOUT"));
    assert.equal(sqlite.prepare("SELECT COUNT(*) AS count FROM rooms").get()?.count, 0);
    const created = await createRoom(db, host, NOW);
    await assert.rejects(joinRoom(db, created.code, { ...guest, loadouts: { [guest.roster[0]]: ["forged"] } }, NOW + 1), roomError(400, "INVALID_LOADOUT"));
    assert.equal((await currentRoom(db, created.code, created.token, NOW + 2)).room.players[1], null);
  } finally { sqlite.close(); }
});

// Current custom kits obey allocated elements. Historical fixtures deliberately
// retain the old cross-element kit to exercise immutable released access rules.
const frozenCustomSpells = ["radiant_bolt", "mend", "stone", "water_jet"];
const frozenCustomKits = Object.fromEntries(host.roster.map(id => [id, [...frozenCustomSpells]]));
const customHost = { ...host, loadouts: Object.fromEntries(host.roster.map(id => [id,
  id === "grace_reava" ? ["radiant_bolt", "mend", "gust", "water_jet"] : [...defaultLoadout(id)].reverse(),
])) };

test("v16 configured loadouts are public and persisted while plans stay private and spell-specific", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, customHost, NOW);
    assert.deepEqual(created.room.players[0].loadouts, customHost.loadouts);
    const storedRoster = JSON.parse(sqlite.prepare("SELECT player0_roster FROM rooms WHERE code = ?").get(created.code)!.player0_roster as string);
    assert.deepEqual(storedRoster, { roster: host.roster, loadouts: customHost.loadouts, learnedSignatures: [], affinities: Object.fromEntries(host.roster.map(id=>[id,getChampion(id).affinities])), matchKind: "casual" });
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = joined.room.state as tactics.SimState;
    const unit = state.units.find((entry) => entry.owner === 0)!;
    for (const entry of state.units) assert.deepEqual(entry.loadout, joined.room.players[entry.owner]!.loadouts[entry.championId]);
    const plan = { orders: [{ unitId: unit.id, cast: { q: unit.q, r: unit.r }, spellId: "radiant_bolt" }] };
    const input = { protocolVersion: 16, matchId: joined.room.matchId, round: state.round, plan };
    const locked = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.deepEqual(locked.room.yourPlan, tactics.validatePlan(state, 0, plan));
    assert.equal(locked.room.yourPlan!.orders.find((order) => order.unitId === unit.id)!.spellId, "radiant_bolt");
    const normalizedRetry = await planInRoom(db, created.code, created.token, { ...input, plan: locked.room.yourPlan }, NOW + 3);
    assert.equal(normalizedRetry.room.version, locked.room.version);
    const peer = (await currentRoom(db, created.code, joined.token, NOW + 3)).room;
    assert.deepEqual(peer.players[0].loadouts, customHost.loadouts);
    assert.deepEqual(peer.state, state);
    assert.equal(peer.yourPlan, undefined);
    for (const secret of ['"plans"', "fingerprints", "lastResolved", "sealed-v10", created.token, joined.token]) assert.ok(!JSON.stringify(peer).includes(secret));
    await assert.rejects(planInRoom(db, created.code, created.token, { ...input, plan: { orders: [{ ...plan.orders[0], spellId: "mend" }] } }, NOW + 4), roomError(409, "PLAN_LOCKED"));
    assert.notEqual(await planFingerprint(plan, 4), await planFingerprint({ orders: [{ ...plan.orders[0], spellId: "mend" }] }, 4));
    assert.throws(() => canonicalPlan(plan, 3), /at most one order/);
  } finally { sqlite.close(); }
});

test("v16 rejects old clients, missing spells, unequipped spells, and forged unit ownership before locking", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, customHost, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = joined.room.state as tactics.SimState;
    const own = state.units.find((unit) => unit.owner === 0)!, foreign = state.units.find((unit) => unit.owner === 1)!;
    const input = { protocolVersion: 16, matchId: joined.room.matchId, round: state.round };
    const cast = { unitId: own.id, cast: { q: own.q, r: own.r } };
    for (const order of [cast, { unitId: own.id, spellId: "mend" }, { ...cast, spellId: 1 }]) {
      await assert.rejects(planInRoom(db, created.code, created.token, { ...input, plan: { orders: [order] } }, NOW + 2), roomError(400, "INVALID_PLAN"));
    }
    for (const order of [{ ...cast, spellId: "forged_spell" }, { ...cast, spellId: "ember" }, { unitId: foreign.id, guard: true }]) {
      await assert.rejects(planInRoom(db, created.code, created.token, { ...input, plan: { orders: [order] } }, NOW + 2), roomError(400, "ILLEGAL_PLAN"));
    }
    await assert.rejects(planInRoom(db, created.code, created.token, { ...input, protocolVersion: 3, plan: { orders: [] } }, NOW + 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 2, 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(createRoom(db, { ...host, protocolVersion: 3 }, NOW + 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    assert.deepEqual((await currentRoom(db, created.code, created.token, NOW + 3)).room.locked, [false, false]);
    assert.equal((await currentRoom(db, created.code, created.token, NOW + 3)).room.version, joined.room.version);
  } finally { sqlite.close(); }
});

test("v16 concurrent duplicate locks resolve exactly once and cannot be reused in another round", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, customHost, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const initial = joined.room.state as tactics.SimState;
    const own = initial.units.find((unit) => unit.owner === 0)!;
    const plans: [tactics.TeamPlan, tactics.TeamPlan] = [{ orders: [{ unitId: own.id, cast: { q: own.q, r: own.r }, spellId: "radiant_bolt" }] }, { orders: [] }];
    const inputs = plans.map((plan) => ({ protocolVersion: 16, matchId: joined.room.matchId, round: initial.round, plan }));
    const tokens = [created.token, joined.token];
    const outcomes = await Promise.all([0, 1, 0, 1].map((seat) => planInRoom(db, created.code, tokens[seat], inputs[seat], NOW + 2)));
    assert.equal(outcomes.length, 4);
    const latest = (await currentRoom(db, created.code, created.token, NOW + 3)).room;
    assert.equal(latest.version, joined.room.version + 2);
    assert.equal(latest.state!.version, initial.version + 1);
    assert.deepEqual(latest.state, tactics.resolveRound(initial, plans));
    assert.deepEqual(latest.locked, [false, false]);
    const repeat = await planInRoom(db, created.code, created.token, inputs[0], NOW + 4);
    assert.equal(repeat.room.version, latest.version);
    await assert.rejects(planInRoom(db, created.code, created.token, { ...inputs[0], plan: { orders: [] } }, NOW + 5), roomError(409, "STALE_ROUND"));
  } finally { sqlite.close(); }
});

test("released v3 pending hashes and receipts remain valid without changing the old engine", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = storeV3(sqlite, created.code, joined.room.matchId!);
    const raw: TeamPlan = { orders: [] }, normalized = validatePlan(state, 0, raw);
    const releasedHash = await hashSecret(JSON.stringify({ orders: [] }));
    assert.equal(await planFingerprint(raw, 3), releasedHash);
    assert.notEqual(await planFingerprint(raw, 4), releasedHash);
    sqlite.prepare("UPDATE rooms SET state_json = ? WHERE code = ?").run(JSON.stringify({
      format: "sealed-v3", matchId: joined.room.matchId, state, plans: [normalized, null], fingerprints: [releasedHash, null],
    }), created.code);
    const input = { protocolVersion: 3, matchId: joined.room.matchId, round: state.round, plan: raw };
    const repeat = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.equal(repeat.room.version, joined.room.version);
    assert.equal(repeat.room.rulesVersion, 3);
    const peer = (await getRoom(db, created.code, joined.token, NOW + 3, 3)).room;
    assert.equal(peer.yourPlan, undefined);
    assert.deepEqual(peer.state, state);
    const resolved = await planInRoom(db, created.code, joined.token, input, NOW + 4);
    assert.deepEqual(resolved.room.state, resolveRound(state, [raw, raw]));
    const receipt = await planInRoom(db, created.code, created.token, input, NOW + 5);
    assert.equal(receipt.room.version, resolved.room.version);
    assert.equal(receipt.room.rulesVersion, 3);
  } finally { sqlite.close(); }
});

test("v3 rematches need both v11 consents and convert old roster arrays into default loadouts", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    storeV3(sqlite, created.code, joined.room.matchId!);
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    stored.state.winner = 0;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 3 WHERE code = ?").run(JSON.stringify(stored), created.code);
    const before = (await getRoom(db, created.code, created.token, NOW + 2, 3)).room;
    assert.deepEqual(before.rematch, [false, false]);
    await assert.rejects(requestRematch(db, created.code, created.token, { protocolVersion: 3, version: before.version }, NOW + 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const first = await currentRematch(db, created.code, joined.token, { version: before.version }, NOW + 3);
    assert.equal(first.room.rulesVersion, 3);
    assert.equal(sqlite.prepare("SELECT player0_roster FROM rooms WHERE code = ?").get(created.code)!.player0_roster, JSON.stringify(host.roster), "one consent must preserve the released roster bytes");
    const next = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 4);
    assert.equal(next.room.rulesVersion, 16);
    assert.notEqual(next.room.matchId, joined.room.matchId);
    for (const unit of (next.room.state as tactics.SimState).units) assert.deepEqual(unit.loadout, defaultLoadout(unit.championId));
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 16, matchId: joined.room.matchId, round: 1, plan: { orders: [] } }, NOW + 5), roomError(409, "STALE_MATCH"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 5, 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
  } finally { sqlite.close(); }
});


test("released v4 pending plans, map and spell footprints survive the v11 server update", async () => {
  const {db,sqlite}=database();
  try {
    const created=await createRoom(db,host,NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    const state=releasedV4.createSimGame([host.roster,guest.roster]);
    const raw:releasedV4.TeamPlan={orders:[]},normalized=releasedV4.validatePlan(state,0,raw);
    const fingerprint=await planFingerprint(raw,4);
    assert.notEqual(fingerprint,await planFingerprint(raw,5));
    sqlite.prepare("UPDATE rooms SET state_json = ? WHERE code = ?").run(JSON.stringify({
      format:"sealed-v4",matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null],
    }),created.code);
    const input={protocolVersion:4,matchId:joined.room.matchId,round:1,plan:raw};
    const repeated=await planInRoom(db,created.code,created.token,input,NOW+2);
    assert.equal(repeated.room.version,joined.room.version);
    const peer=(await getRoom(db,created.code,joined.token,NOW+3,4)).room;
    assert.equal(peer.rulesVersion,4);assert.equal((peer.state as releasedV4.SimState).cells.length,37);
    assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.state,state);
    assert.equal(releasedV4.getSpell('tidal_surge').shape,'hex');assert.equal(releasedV4.getSpell('raise_cairn').cost,3);
    const resolved=await planInRoom(db,created.code,joined.token,input,NOW+4);
    assert.deepEqual(resolved.room.state,releasedV4.resolveRound(state,[raw,raw]));
    const receipt=await planInRoom(db,created.code,created.token,input,NOW+5);
    assert.equal(receipt.room.version,resolved.room.version);
    assert.equal(receipt.room.rulesVersion,4);
  }finally{sqlite.close()}
});

test("v11 rooms reject v4 cached clients while v4 cannot consent to new-rule rematches",async()=>{
 const {db,sqlite}=database();try{
  await assert.rejects(createRoom(db,{...host,protocolVersion:4},NOW),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
  const created=await createRoom(db,host,NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
  await assert.rejects(getRoom(db,created.code,created.token,NOW+2,4),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
  await assert.rejects(planInRoom(db,created.code,created.token,{protocolVersion:4,matchId:joined.room.matchId,round:1,plan:{orders:[]}},NOW+2),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
  await assert.rejects(requestRematch(db,created.code,created.token,{protocolVersion:4,version:joined.room.version},NOW+2),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
 }finally{sqlite.close()}
});

test("released v5 pending spell orders retain exact fingerprints, secrecy, map, and resolution", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = releasedV5.createSimGame([host.roster, guest.roster]);
    const unit = state.units.find(entry => entry.owner === 0 && entry.championId === "oh_tipi")!;
    const raw: releasedV5.TeamPlan = { orders: [{ unitId: unit.id, cast: { q: -2, r: 1 }, spellId: "tidal_surge" }] };
    const normalized = releasedV5.validatePlan(state, 0, raw);
    // This is the published wire representation, independent of the new server dispatcher.
    const fingerprint = await hashSecret(JSON.stringify({ rulesVersion: 5, plan: raw }));
    assert.equal(await planFingerprint(raw, 5), fingerprint);
    assert.notEqual(await planFingerprint(raw, 6), fingerprint);
    const stored = { format: "sealed-v5", matchId: joined.room.matchId, state, plans: [normalized, null], fingerprints: [fingerprint, null] };
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = 'confluence' WHERE code = ?").run(JSON.stringify(stored), created.code);
    const input = { protocolVersion: 5, matchId: joined.room.matchId, round: 1, plan: raw };
    const repeat = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.equal(repeat.room.version, joined.room.version);
    assert.deepEqual(repeat.room.yourPlan, normalized);
    assert.deepEqual(JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string), stored, "a retry must not migrate or rewrite sealed v5 data");
    const peer = (await getRoom(db, created.code, joined.token, NOW + 3, 5)).room;
    assert.equal(peer.rulesVersion, 5);
    assert.equal(peer.mapId, "confluence");
    assert.equal(peer.state!.mapId, "confluence");
    assert.equal(peer.protocolVersion, 16);
    assert.equal((peer.state as releasedV5.SimState).cells.length, 61);
    assert.deepEqual(peer.state, state);
    assert.equal(peer.yourPlan, undefined);
    for (const secret of ["fingerprints", "lastResolved", '"plans"', "sealed-v5", created.token]) assert.ok(!JSON.stringify(peer).includes(secret));
    assert.equal(releasedV5.MOVE_RANGE, 2);
    assert.equal(releasedV5.getSpell("tidal_surge").range, 2);
    assert.equal(releasedV5.spellArea(state, unit.id, "tidal_surge", raw.orders[0].cast!).length, 3);
    const empty = { orders: [] };
    const resolved = await planInRoom(db, created.code, joined.token, { ...input, plan: empty }, NOW + 4);
    assert.deepEqual(resolved.room.state, releasedV5.resolveRound(state, [raw, empty]));
    const receipt = await planInRoom(db, created.code, created.token, input, NOW + 5);
    assert.equal(receipt.room.version, resolved.room.version);
    assert.equal(receipt.room.rulesVersion, 5);
  } finally { sqlite.close(); }
});

test("v5 finished rooms need two new v11 consents before dispatching a larger-map rematch", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = releasedV5.createSimGame([host.roster, guest.roster]);
    state.winner = 0;
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = 'confluence', status = 'finished', rematch0 = 5 WHERE code = ?").run(JSON.stringify({
      format: "sealed-v5", matchId: joined.room.matchId, state, plans: [null, null], fingerprints: [null, null],
    }), created.code);
    const before = (await getRoom(db, created.code, created.token, NOW + 2, 5)).room;
    assert.deepEqual(before.rematch, [false, false]);
    await assert.rejects(requestRematch(db, created.code, created.token, { protocolVersion: 5, version: before.version }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const first = await currentRematch(db, created.code, joined.token, { version: before.version }, NOW + 4);
    assert.equal(first.room.rulesVersion, 5);
    assert.deepEqual(first.room.rematch, [false, true]);
    assert.deepEqual(first.room.state, state);
    const next = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 5);
    assert.equal(next.room.rulesVersion, 16);
    assert.equal(next.room.state!.mapId, "frontier:WELLSPRING");
    assert.equal((next.room.state as tactics.SimState).cells.length, tactics.BOARD_SIZE);
    assert.ok(tactics.BOARD_SIZE > 61);
    assert.notEqual(next.room.matchId, joined.room.matchId);
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 6, 5), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 16, matchId: joined.room.matchId, round: 1, plan: { orders: [] } }, NOW + 6), roomError(409, "STALE_MATCH"));
  } finally { sqlite.close(); }
});

test("v5 clients cannot create or join a v11 waiting lobby", async () => {
  const { db, sqlite } = database();
  try {
    await assert.rejects(createRoom(db, { ...host, protocolVersion: 5 }, NOW), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const created = await createRoom(db, host, NOW);
    await assert.rejects(joinRoom(db, created.code, { ...guest, protocolVersion: 5 }, NOW + 1), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 1, 5), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const waiting = (await currentRoom(db, created.code, created.token, NOW + 2)).room;
    assert.equal(waiting.rulesVersion, 16);
    assert.equal(waiting.state, null);
    assert.equal(waiting.players[1], null);
    assert.equal(waiting.version, 0);
  } finally { sqlite.close(); }
});

test("host seeds are canonical, deterministic, distinct and authoritative when a friend joins", async () => {
  const { db, sqlite } = database();
  try {
    const seeded = await createRoom(db, { ...host, mapId: "  reach:river-42  " }, NOW);
    assert.equal(seeded.room.mapId, "frontier:RIVER-42");
    assert.equal(sqlite.prepare("SELECT map_id FROM rooms WHERE code = ?").get(seeded.code)!.map_id, "frontier:RIVER-42");
    // A joining client supplies a different (even malformed) map; only the host's stored map applies.
    const joined = await joinRoom(db, seeded.code, { ...guest, mapId: "not-a-map" }, NOW + 1);
    assert.equal(joined.room.mapId, "frontier:RIVER-42");
    assert.equal(joined.room.state!.mapId, "frontier:RIVER-42");
    const replay = await createRoom(db, { ...host, mapId: "frontier:RIVER-42" }, NOW + 2);
    const replayed = await joinRoom(db, replay.code, guest, NOW + 3);
    assert.deepEqual(replayed.room.state, joined.room.state, "the same seed and companies reproduce the exact initial battlefield");
    const different = await createRoom(db, { ...host, mapId: "reach:ASH-91" }, NOW + 4);
    const changed = await joinRoom(db, different.code, guest, NOW + 5);
    assert.notDeepEqual((changed.room.state as tactics.SimState).cells, (joined.room.state as tactics.SimState).cells);
  } finally { sqlite.close(); }
});

test("invalid host map seeds fail before room writes and omitted seeds retain a canonical default", async () => {
  const { db, sqlite } = database();
  try {
    for (const mapId of [null, 5, {}, [], "", "reach:", "reach:bad seed", "reach:a/b", "reach:Ã©", `reach:${"A".repeat(25)}`, "unknown:SEED"]) {
      await assert.rejects(createRoom(db, { ...host, mapId }, NOW), roomError(400, "INVALID_MAP"));
    }
    assert.equal(sqlite.prepare("SELECT COUNT(*) AS count FROM rooms").get()!.count, 0);
    const created = await createRoom(db, host, NOW);
    assert.equal(created.room.mapId, "frontier:WELLSPRING");
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    assert.equal(joined.room.state!.mapId, "frontier:WELLSPRING");
  } finally { sqlite.close(); }
});

test("a seeded mutual rematch preserves the host seed and exact initial geography", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, { ...host, mapId: "frontier:EMBER-FALL" }, NOW);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    const initial = joined.room.state as tactics.SimState;
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    stored.state.winner = 0;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished' WHERE code = ?").run(JSON.stringify(stored), created.code);
    const first = await currentRematch(db, created.code, created.token, { version: joined.room.version, mapId: "reach:OVERRIDE" }, NOW + 2);
    const next = await currentRematch(db, created.code, joined.token, { version: first.room.version, mapId: "reach:OVERRIDE" }, NOW + 3);
    assert.equal(next.room.mapId, "frontier:EMBER-FALL");
    assert.equal(next.room.state!.mapId, "frontier:EMBER-FALL");
    assert.deepEqual((next.room.state as tactics.SimState).cells, initial.cells);
    assert.deepEqual(next.room.state, initial);
    assert.notEqual(next.room.matchId, joined.room.matchId);
  } finally { sqlite.close(); }
});

test("released v6 sealed orders retain exact bytes, custom kits, geometry, and retry receipts", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const guestKits = Object.fromEntries(guest.roster.map(id => [id, v6DefaultLoadout(id)]));
    const state = releasedV6.createSimGame([host.roster, guest.roster], "reach:RETAINED-42", [frozenCustomKits, guestKits]);
    const unit = state.units.find(entry => entry.owner === 0)!;
    const raw: releasedV6.TeamPlan = { orders: [{ unitId: unit.id, cast: { q: unit.q, r: unit.r }, spellId: "radiant_bolt" }] };
    const normalized = releasedV6.validatePlan(state, 0, raw);
    const fingerprint = await hashSecret(JSON.stringify({ rulesVersion: 6, plan: raw }));
    assert.equal(await planFingerprint(raw, 6), fingerprint, "published v6 fingerprint bytes must remain exact");
    assert.notEqual(await planFingerprint(raw, 10), fingerprint);
    const sealed = { format: "sealed-v6", matchId: joined.room.matchId, state, plans: [normalized, null], fingerprints: [fingerprint, null] };
    const serialized = JSON.stringify(sealed);
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?").run(serialized, state.mapId, JSON.stringify({ roster: host.roster, loadouts: frozenCustomKits }), JSON.stringify({ roster: guest.roster, loadouts: guestKits }), created.code);
    const input = { protocolVersion: 6, matchId: joined.room.matchId, round: state.round, plan: raw };
    const repeated = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.equal(repeated.room.version, joined.room.version);
    assert.deepEqual(repeated.room.yourPlan, normalized);
    assert.equal(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json, serialized, "an idempotent retry cannot rewrite or migrate the old match");
    const oldRead = (await getRoom(db, created.code, joined.token, NOW + 3, 6)).room;
    const newRead = (await getRoom(db, created.code, joined.token, NOW + 3, 12)).room;
    assert.deepEqual(newRead, oldRead);
    assert.equal(oldRead.rulesVersion, 6);
    assert.equal(oldRead.protocolVersion, 16);
    assert.equal(oldRead.mapId, "reach:RETAINED-42");
    assert.equal((oldRead.state as releasedV6.SimState).cells.length, 127);
    assert.deepEqual(oldRead.state, state);
    assert.deepEqual(oldRead.players[0].loadouts, frozenCustomKits);
    assert.equal(oldRead.yourPlan, undefined);
    for (const secret of ['"plans"', "fingerprints", "lastResolved", "sealed-v6", created.token]) assert.ok(!JSON.stringify(oldRead).includes(secret));
    const empty = { orders: [] };
    const resolved = await planInRoom(db, created.code, joined.token, { ...input, plan: empty }, NOW + 4);
    assert.deepEqual(resolved.room.state, releasedV6.resolveRound(state, [raw, empty]));
    assert.equal(resolved.room.rulesVersion, 6);
    const receipt = await planInRoom(db, created.code, created.token, input, NOW + 5);
    assert.equal(receipt.room.version, resolved.room.version);
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    assert.equal(stored.format, "sealed-v6");
    assert.ok(stored.lastResolved.fingerprints[0].includes(fingerprint));
  } finally { sqlite.close(); }
});

test("v6 rematches preserve original bytes until both v13 consents and carry the seed into Frontier", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const guestKits = Object.fromEntries(guest.roster.map(id => [id, v6DefaultLoadout(id)]));
    const state = releasedV6.createSimGame([host.roster, guest.roster], "reach:OLD-RIVER", [frozenCustomKits, guestKits]);
    state.winner = 0;
    const serialized = JSON.stringify({ format: "sealed-v6", matchId: joined.room.matchId, state, plans: [null, null], fingerprints: [null, null] });
    const storedHost = JSON.stringify({ roster: host.roster, loadouts: frozenCustomKits, learnedSignatures: [], affinities: Object.fromEntries(host.roster.map(id=>[id,getChampion(id).affinities])), matchKind: "casual" });
    const storedGuest = JSON.stringify({ roster: guest.roster, loadouts: guestKits });
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ?, status = 'finished', rematch0 = 6 WHERE code = ?").run(serialized, state.mapId, storedHost, storedGuest, created.code);
    const before = (await getRoom(db, created.code, created.token, NOW + 2, 6)).room;
    assert.deepEqual(before.rematch, [false, false], "v6 consent cannot start changed rules");
    await assert.rejects(requestRematch(db, created.code, created.token, { protocolVersion: 6, version: before.version }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const first = await currentRematch(db, created.code, joined.token, { version: before.version }, NOW + 4);
    assert.equal(first.room.rulesVersion, 6);
    assert.deepEqual(first.room.rematch, [false, true]);
    const preserved = sqlite.prepare("SELECT state_json, map_id, player0_roster, player1_roster FROM rooms WHERE code = ?").get(created.code)!;
    assert.deepEqual({ ...preserved }, { state_json: serialized, map_id: state.mapId, player0_roster: storedHost, player1_roster: storedGuest });
    const next = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 5);
    assert.equal(next.room.rulesVersion, 16);
    assert.equal(next.room.mapId, "frontier:OLD-RIVER");
    assert.equal(next.room.state!.mapId, "frontier:OLD-RIVER");
    const migratedHostKits = Object.fromEntries(host.roster.map(id => [id, repairLoadout(id, frozenCustomKits[id])]));
    assert.deepEqual(next.room.players[0].loadouts, migratedHostKits);
    for (const id of host.roster) for (const [slot, spell] of frozenCustomKits[id].entries()) {
      if (spellAccess(id, spell).unlocked) assert.equal(migratedHostKits[id][slot], spell, 'legal historical slots stay in place');
      else assert.notEqual(migratedHostKits[id][slot], spell, 'zero-affinity historical spells change only on the new match');
    }
    const migratedGuestKits = Object.fromEntries(guest.roster.map(id => [id, readLoadouts(guestKits)[id]]));
    assert.deepEqual(next.room.players[1]!.loadouts, migratedGuestKits);
    const expected = tactics.createSimGame([host.roster, guest.roster], "frontier:OLD-RIVER", [migratedHostKits, migratedGuestKits]);
    assert.deepEqual(next.room.state, expected);
    assert.ok(expected.cells.length > state.cells.length);
    assert.notEqual(next.room.matchId, joined.room.matchId);
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 6, 6), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 16, matchId: joined.room.matchId, round: 1, plan: { orders: [] } }, NOW + 6), roomError(409, "STALE_MATCH"));
  } finally { sqlite.close(); }
});

test("old waiting invitations start v11 with one canonical map and persisted four-spell kits", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    sqlite.prepare("UPDATE rooms SET map_id = 'reach:WAITING-SEED', player0_roster = ? WHERE code = ?").run(JSON.stringify(host.roster), created.code);
    const joined = await joinRoom(db, created.code, guest, NOW + 1);
    assert.equal(joined.room.rulesVersion, 16);
    assert.equal(joined.room.mapId, "frontier:WAITING-SEED");
    assert.equal(joined.room.state!.mapId, joined.room.mapId);
    const row = sqlite.prepare("SELECT map_id, player0_roster FROM rooms WHERE code = ?").get(created.code)!;
    assert.equal(row.map_id, joined.room.mapId);
    assert.deepEqual(JSON.parse(row.player0_roster as string), { roster: host.roster, loadouts: Object.fromEntries(host.roster.map(id => [id, defaultLoadout(id)])), learnedSignatures: [], affinities: Object.fromEntries(host.roster.map(id=>[id,getChampion(id).affinities])), matchKind: "casual" });
  } finally { sqlite.close(); }
});

test("v11 signatures are derived owned actions and cannot replace a configured spell or be forged", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const state = joined.room.state as tactics.SimState;
    const own = state.units.find(unit => unit.owner === 0)!;
    const signature = getSignature(own.championId);
    const foreignSignature = getSignature(state.units.find(unit => unit.owner === 1)!.championId);
    assert.equal(own.loadout.length, 4);
    assert.ok(!own.loadout.includes(signature.id));
    await assert.rejects(createRoom(db, { ...host, loadouts: { [own.championId]: [signature.id, ...own.loadout.slice(1)] } }, NOW + 2), roomError(400, "INVALID_LOADOUT"));
    const cast = { unitId: own.id, cast: { q: own.q, r: own.r } };
    const input = { protocolVersion: 16, matchId: joined.room.matchId, round: 1 };
    await assert.rejects(planInRoom(db, created.code, created.token, { ...input, plan: { orders: [{ ...cast, spellId: foreignSignature.id }] } }, NOW + 2), roomError(400, "ILLEGAL_PLAN"));
    const target = tactics.legalCasts(state, own.id, undefined, signature.id)[0];
    assert.ok(target, "every signature must have a legal opening target");
    const plan = { orders: [{ unitId: own.id, cast: { q: target.q, r: target.r }, spellId: signature.id }] };
    const locked = await planInRoom(db, created.code, created.token, { ...input, plan }, NOW + 3);
    assert.deepEqual(locked.room.yourPlan, tactics.validatePlan(state, 0, plan));
    assert.equal(locked.room.yourPlan!.orders.find(order => order.unitId === own.id)!.spellId, signature.id);
    const peer = (await currentRoom(db, created.code, joined.token, NOW + 4)).room;
    assert.equal(peer.yourPlan, undefined);
    const resolved = await planInRoom(db, created.code, joined.token, { ...input, plan: { orders: [] } }, NOW + 5);
    assert.deepEqual(resolved.room.state, tactics.resolveRound(state, [plan, { orders: [] }]));
  } finally { sqlite.close(); }
});

test("released v7 locks preserve their exact state, fingerprints and elemental rules through the v11 server", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const kits = [host, guest].map(player => Object.fromEntries(player.roster.map(id => [id, v7DefaultLoadout(id)]))) as [Record<string, string[]>, Record<string, string[]>];
    const state = releasedV7.createSimGame([host.roster, guest.roster], "frontier:OLD-WATER", kits);
    const unit = state.units.find(entry => entry.championId === "oh_tipi")!;
    const raw: releasedV7.TeamPlan = { orders: [{ unitId: unit.id, cast: { q: unit.q, r: unit.r }, spellId: "water_jet" }] };
    const normalized = releasedV7.validatePlan(state, 0, raw);
    const fingerprint = await hashSecret(JSON.stringify({ rulesVersion: 7, plan: raw }));
    assert.equal(await planFingerprint(raw, 7), fingerprint, "released retry fingerprints remain byte-identical");
    assert.notEqual(await planFingerprint(raw, 10), fingerprint, "new rules have a separate fingerprint domain");
    const sealed = { format: "sealed-v7", matchId: joined.room.matchId, state, plans: [normalized, null], fingerprints: [fingerprint, null] };
    const serialized = JSON.stringify(sealed);
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?").run(serialized, state.mapId, JSON.stringify({ roster: host.roster, loadouts: kits[0] }), JSON.stringify({ roster: guest.roster, loadouts: kits[1] }), created.code);
    const input = { protocolVersion: 7, matchId: joined.room.matchId, round: 1, plan: raw };
    const repeated = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.equal(repeated.room.version, joined.room.version);
    assert.deepEqual(repeated.room.yourPlan, normalized);
    assert.equal(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json, serialized);
    const oldRead = (await getRoom(db, created.code, joined.token, NOW + 3, 7)).room;
    const newRead = (await currentRoom(db, created.code, joined.token, NOW + 3)).room;
    assert.deepEqual(oldRead, newRead);
    assert.equal(oldRead.rulesVersion, 7);
    assert.equal(oldRead.protocolVersion, 16);
    assert.deepEqual(oldRead.state, state);
    assert.equal(oldRead.yourPlan, undefined);
    for (const secret of ['"plans"', "fingerprints", "lastResolved", "sealed-v7", created.token, joined.token]) assert.ok(!JSON.stringify(oldRead).includes(secret));
    const empty = { orders: [] };
    const resolved = await planInRoom(db, created.code, joined.token, { ...input, plan: empty }, NOW + 4);
    assert.deepEqual(resolved.room.state, releasedV7.resolveRound(state, [raw, empty]), "the old Water Jet must use the released resolver");
    assert.deepEqual(releasedV7.restoreSimState(resolved.room.state), resolved.room.state);
    const receipt = await planInRoom(db, created.code, created.token, input, NOW + 5);
    assert.equal(receipt.room.version, resolved.room.version);
    assert.equal(receipt.room.rulesVersion, 7);
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    assert.equal(stored.format, "sealed-v7");
    assert.ok(stored.lastResolved.fingerprints[0].includes(fingerprint));
  } finally { sqlite.close(); }
});

test("v7 matches need two fresh v13 rematch consents and keep old state bytes until then", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const guestKits = Object.fromEntries(guest.roster.map(id => [id, v7DefaultLoadout(id)]));
    const state = releasedV7.createSimGame([host.roster, guest.roster], "frontier:OLD-FROST", [frozenCustomKits, guestKits]);
    state.winner = 0;
    const serialized = JSON.stringify({ format: "sealed-v7", matchId: joined.room.matchId, state, plans: [null, null], fingerprints: [null, null] });
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ?, status = 'finished', rematch0 = 7 WHERE code = ?").run(serialized, state.mapId, JSON.stringify({roster:host.roster,loadouts:frozenCustomKits}),JSON.stringify({roster:guest.roster,loadouts:guestKits}),created.code);
    const before = (await getRoom(db, created.code, created.token, NOW + 2, 7)).room;
    assert.deepEqual(before.rematch, [false, false]);
    await assert.rejects(requestRematch(db, created.code, created.token, { protocolVersion: 7, version: before.version }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const first = await currentRematch(db, created.code, joined.token, { version: before.version }, NOW + 4);
    assert.equal(first.room.rulesVersion, 7);
    assert.deepEqual(first.room.rematch, [false, true]);
    assert.equal(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json, serialized);
    const next = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 5);
    assert.equal(next.room.rulesVersion, 16);
    assert.equal(next.room.mapId, state.mapId);
    assert.notEqual(next.room.matchId, joined.room.matchId);
    const migratedHostKits = Object.fromEntries(host.roster.map(id => [id, repairLoadout(id, frozenCustomKits[id])]));
    assert.deepEqual(next.room.players[0].loadouts, migratedHostKits);
    for (const id of host.roster) for (const [slot, spell] of frozenCustomKits[id].entries()) {
      if (spellAccess(id, spell).unlocked) assert.equal(migratedHostKits[id][slot], spell, 'legal historical slots stay in place');
      else assert.notEqual(migratedHostKits[id][slot], spell, 'zero-affinity historical spells change only on the new match');
    }
    const migratedGuestKits = Object.fromEntries(guest.roster.map(id => [id, readLoadouts(guestKits)[id]]));
    assert.deepEqual(next.room.players[1]!.loadouts, migratedGuestKits);
    assert.deepEqual(next.room.state, tactics.createSimGame([host.roster, guest.roster], state.mapId, [migratedHostKits, migratedGuestKits]));
    assert.deepEqual(tactics.restoreSimState(next.room.state), next.room.state);
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 6, 7), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
  } finally { sqlite.close(); }
});

test("cached v7 clients cannot create, join, read or seal a changed-rules match", async () => {
  const { db, sqlite } = database();
  try {
    await assert.rejects(createRoom(db, { ...host, protocolVersion: 7 }, NOW), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const created = await createRoom(db, host, NOW);
    await assert.rejects(joinRoom(db, created.code, { ...guest, protocolVersion: 7 }, NOW + 1), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 1, 7), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const joined = await joinRoom(db, created.code, guest, NOW + 2);
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 7, matchId: joined.room.matchId, round: 1, plan: { orders: [] } }, NOW + 3), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    assert.equal(joined.room.rulesVersion, 16);
    assert.equal(joined.room.version, 1);
    assert.deepEqual(joined.room.locked, [false, false]);
  } finally { sqlite.close(); }
});

test("v8 branch spells stay playable until both players explicitly start a v11 rematch", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const kits = [host, guest].map(player => Object.fromEntries(player.roster.map(id => [id, v8DefaultLoadout(id)]))) as [Record<string, string[]>, Record<string, string[]>];
    kits[0].grace_reava = ["frostbite", "mend", "stone", "water_jet"];
    assert.equal(spellAccess("grace_reava", "frostbite").unlocked, false);
    const state = releasedV8.createSimGame([host.roster, guest.roster], "frontier:RETAINED-ICE", kits);
    const original = JSON.stringify({ format: "sealed-v8", matchId: joined.room.matchId, state, plans: [null, null], fingerprints: [null, null] });
    const storedKits = [host, guest].map((player, seat) => JSON.stringify({ roster: player.roster, loadouts: kits[seat] }));
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?").run(original, state.mapId, ...storedKits, created.code);
    const before = (await getRoom(db, created.code, created.token, NOW + 2, 8)).room;
    assert.deepEqual(before.players[0].loadouts.grace_reava, kits[0].grace_reava);
    const caster = state.units.find(unit => unit.championId === "grace_reava")!;
    const target = releasedV8.legalCasts(state, caster.id, undefined, "frostbite")[0];
    const plan = { orders: [{ unitId: caster.id, spellId: "frostbite", cast: { q: target.q, r: target.r } }] };
    const input = { protocolVersion: 8, matchId: joined.room.matchId, round: 1, plan };
    await planInRoom(db, created.code, created.token, input, NOW + 3);
    const resolved = await planInRoom(db, created.code, joined.token, { ...input, plan: { orders: [] } }, NOW + 4);
    assert.deepEqual(resolved.room.state, releasedV8.resolveRound(state, [plan, { orders: [] }]), "V8 ignores the new affinity gate and retains its released resolver");
    const sealed = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    sealed.state.winner = 0;
    const finished = JSON.stringify(sealed);
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished', rematch0 = 8 WHERE code = ?").run(finished, created.code);
    const ended = (await currentRoom(db, created.code, created.token, NOW + 5)).room;
    assert.deepEqual(ended.rematch, [false, false], "an earlier V8 consent cannot accept new rules");
    await assert.rejects(requestRematch(db, created.code, created.token, { protocolVersion: 8, version: ended.version }, NOW + 6), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const first = await currentRematch(db, created.code, joined.token, { version: ended.version }, NOW + 7);
    assert.equal(first.room.rulesVersion, 8);
    assert.equal(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json, finished);
    assert.equal(sqlite.prepare("SELECT player0_roster FROM rooms WHERE code = ?").get(created.code)!.player0_roster, storedKits[0]);
    const next = await currentRematch(db, created.code, created.token, { version: first.room.version }, NOW + 8);
    const migrated = readLoadouts(kits[0]).grace_reava;
    assert.equal(next.room.rulesVersion, 16);assert.equal(next.room.mapId, state.mapId);
    assert.notEqual(next.room.matchId, joined.room.matchId);
    assert.deepEqual(next.room.players[0].loadouts.grace_reava, migrated);
    assert.notEqual(migrated[0], "frostbite");
    assert.equal(migrated[1], "mend", "legal choices retain their exact original slots");
    assert.equal(migrated[3], "water_jet", "legal choices retain their exact original slots");
    assert.notEqual(migrated[2], "stone", "zero-affinity spells also become unavailable only in the new match");
    assert.deepEqual(tactics.restoreSimState(next.room.state), next.room.state);
    await assert.rejects(getRoom(db, created.code, created.token, NOW + 9, 8), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
  } finally { sqlite.close(); }
});

test("old waiting invitations repair locked slots only when starting the new match", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW);
    const kits = { grace_reava: ["frostbite", "mend", "stone", "water_jet"] };
    const stored = JSON.stringify({ roster: host.roster, loadouts: kits });
    sqlite.prepare("UPDATE rooms SET player0_roster = ? WHERE code = ?").run(stored, created.code);
    const read = (await currentRoom(db, created.code, created.token, NOW + 1)).room;
    assert.equal(read.rulesVersion, 16);
    assert.deepEqual(read.players[0].loadouts.grace_reava, readLoadouts(kits).grace_reava);
    assert.equal(sqlite.prepare("SELECT player0_roster FROM rooms WHERE code = ?").get(created.code)!.player0_roster, stored, "a read does not alter the saved invitation");
    await assert.rejects(joinRoom(db, created.code, { ...guest, protocolVersion: 8 }, NOW + 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    const joined = await joinRoom(db, created.code, guest, NOW + 3);
    assert.deepEqual(joined.room.players[0].loadouts, read.players[0].loadouts);
    assert.deepEqual((joined.room.state as tactics.SimState).units.find(unit => unit.championId === "grace_reava")!.loadout, read.players[0].loadouts.grace_reava);
    assert.deepEqual(JSON.parse(sqlite.prepare("SELECT player0_roster FROM rooms WHERE code = ?").get(created.code)!.player0_roster as string).loadouts, read.players[0].loadouts);
  } finally { sqlite.close(); }
});

test("v11 validates affinity unlocks at the remote room boundary and rejects cached v8 planners", async () => {
  const { db, sqlite } = database();
  try {
    await assert.rejects(createRoom(db, { ...host, protocolVersion: 8 }, NOW), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    await assert.rejects(createRoom(db, { ...host, loadouts: { grace_reava: ["frostbite", "mend", "stone", "water_jet"] } }, NOW), roomError(400, "INVALID_LOADOUT"));
    assert.equal(sqlite.prepare("SELECT COUNT(*) AS count FROM rooms").get()!.count, 0);
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    await assert.rejects(planInRoom(db, created.code, created.token, { protocolVersion: 8, matchId: joined.room.matchId, round: 1, plan: { orders: [] } }, NOW + 2), roomError(426, "CLIENT_UPGRADE_REQUIRED"));
    assert.deepEqual((await currentRoom(db, created.code, created.token, NOW + 3)).room.locked, [false, false]);
  } finally { sqlite.close(); }
});

test("released v8 locks preserve their exact state, fingerprints and elemental rules through the v11 server", async () => {
  const { db, sqlite } = database();
  try {
    const created = await createRoom(db, host, NOW), joined = await joinRoom(db, created.code, guest, NOW + 1);
    const kits = [host, guest].map(player => Object.fromEntries(player.roster.map(id => [id, v8DefaultLoadout(id)]))) as [Record<string, string[]>, Record<string, string[]>];
    const state = releasedV8.createSimGame([host.roster, guest.roster], "frontier:OLD-WATER", kits);
    const unit = state.units.find(entry => entry.championId === "oh_tipi")!;
    const raw: releasedV8.TeamPlan = { orders: [{ unitId: unit.id, cast: { q: unit.q, r: unit.r }, spellId: "water_jet" }] };
    const normalized = releasedV8.validatePlan(state, 0, raw);
    const fingerprint = await hashSecret(JSON.stringify({ rulesVersion: 8, plan: raw }));
    assert.equal(await planFingerprint(raw, 8), fingerprint, "released retry fingerprints remain byte-identical");
    assert.notEqual(await planFingerprint(raw, 10), fingerprint, "new rules have a separate fingerprint domain");
    const sealed = { format: "sealed-v8", matchId: joined.room.matchId, state, plans: [normalized, null], fingerprints: [fingerprint, null] };
    const serialized = JSON.stringify(sealed);
    sqlite.prepare("UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?").run(serialized, state.mapId, JSON.stringify({ roster: host.roster, loadouts: kits[0] }), JSON.stringify({ roster: guest.roster, loadouts: kits[1] }), created.code);
    const input = { protocolVersion: 8, matchId: joined.room.matchId, round: 1, plan: raw };
    const repeated = await planInRoom(db, created.code, created.token, input, NOW + 2);
    assert.equal(repeated.room.version, joined.room.version);
    assert.deepEqual(repeated.room.yourPlan, normalized);
    assert.equal(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json, serialized);
    const oldRead = (await getRoom(db, created.code, joined.token, NOW + 3, 8)).room;
    const newRead = (await currentRoom(db, created.code, joined.token, NOW + 3)).room;
    assert.deepEqual(oldRead, newRead);
    assert.equal(oldRead.rulesVersion, 8);
    assert.equal(oldRead.protocolVersion, 16);
    assert.deepEqual(oldRead.state, state);
    assert.equal(oldRead.yourPlan, undefined);
    for (const secret of ['"plans"', "fingerprints", "lastResolved", "sealed-v8", created.token, joined.token]) assert.ok(!JSON.stringify(oldRead).includes(secret));
    const empty = { orders: [] };
    const resolved = await planInRoom(db, created.code, joined.token, { ...input, plan: empty }, NOW + 4);
    assert.deepEqual(resolved.room.state, releasedV8.resolveRound(state, [raw, empty]), "the old Water Jet must use the released resolver");
    assert.deepEqual(releasedV8.restoreSimState(resolved.room.state), resolved.room.state);
    const receipt = await planInRoom(db, created.code, created.token, input, NOW + 5);
    assert.equal(receipt.room.version, resolved.room.version);
    assert.equal(receipt.room.rulesVersion, 8);
    const stored = JSON.parse(sqlite.prepare("SELECT state_json FROM rooms WHERE code = ?").get(created.code)!.state_json as string);
    assert.equal(stored.format, "sealed-v8");
    assert.ok(stored.lastResolved.fingerprints[0].includes(fingerprint));
  } finally { sqlite.close(); }
});

test("released v10 earned preparation remains private, canonical retries spend once, and rematches repair the latest kit",async()=>{
  const {db,sqlite}=database();
  try{
    const created=await createRoom(db,host,NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    const released=releasedV10.createSimGame([host.roster,guest.roster],joined.room.mapId,undefined,[joined.room.players[0].learnedSignatures,joined.room.players[1]!.learnedSignatures]);
    sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(JSON.stringify({format:'sealed-v10',matchId:joined.room.matchId,state:released,plans:[null,null],fingerprints:[null,null]}),created.code);
    let room=(await currentRoom(db,created.code,created.token,NOW+1)).room;
    for(let round=1;round<=2;round++){
      const input={protocolVersion:10,matchId:room.matchId,round,plan:{orders:[]}};
      await planInRoom(db,created.code,created.token,input,NOW+round*2);
      room=(await planInRoom(db,created.code,joined.token,input,NOW+round*2+1)).room;
    }
    const state=room.state as releasedV10.SimState,tipi=state.units.find(unit=>unit.owner===0&&unit.championId==='oh_tipi')!,grace=state.units.find(unit=>unit.owner===0&&unit.championId==='grace_reava')!;
    assert.equal(state.round,3);
    const draft:releasedV10.TeamPlan={orders:[],training:[{unitId:tipi.id,element:'water'},{unitId:grace.id,element:'air'}],loadouts:[{unitId:tipi.id,spells:['mend','deep_freeze','ember','water_jet']},{unitId:grace.id,spells:['thunderclap','gust','mend','ember']}]};
    const projected=releasedV10.prepareTeam(state,0,draft),target=releasedV10.legalCasts(projected,tipi.id,undefined,'deep_freeze')[0];
    draft.orders=[{unitId:tipi.id,spellId:'deep_freeze',cast:{q:target.q,r:target.r}}];
    const input={protocolVersion:10,matchId:room.matchId,round:3,plan:draft};
    const locked=await planInRoom(db,created.code,created.token,input,NOW+10);
    assert.deepEqual(locked.room.state,state,'locking cannot publish training or new equipment early');
    assert.deepEqual(locked.room.yourPlan,releasedV10.validatePlan(state,0,draft));
    const peer=(await currentRoom(db,created.code,joined.token,NOW+11)).room;
    assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.state,state);
    assert.ok(!JSON.stringify(peer).includes('"training"'));
    const reordered={...draft,training:[...draft.training!].reverse(),loadouts:[...draft.loadouts!].reverse()};
    const repeated=await planInRoom(db,created.code,created.token,{...input,plan:reordered},NOW+12);
    assert.equal(repeated.room.version,locked.room.version);
    const changed={...draft,loadouts:draft.loadouts!.map(entry=>({...entry,spells:[...entry.spells].reverse()}))};
    await assert.rejects(planInRoom(db,created.code,created.token,{...input,plan:changed},NOW+14),roomError(409,'PLAN_LOCKED'));
    const outcomes=await Promise.all([
      planInRoom(db,created.code,joined.token,{...input,plan:{orders:[]}},NOW+14),
      planInRoom(db,created.code,created.token,{...input,plan:reordered},NOW+14),
    ]);
    const after=(await currentRoom(db,created.code,created.token,NOW+16)).room;
    assert.equal((after.state as releasedV10.SimState).round,4);
    assert.equal((after.state as releasedV10.SimState).units.find(unit=>unit.id===tipi.id)!.affinities.water,4);
    assert.equal((after.state as releasedV10.SimState).units.find(unit=>unit.id===grace.id)!.affinities.air,4);
    assert.equal((after.state as releasedV10.SimState).lastResolution.filter(event=>event.kind==='cast'&&event.spellId==='deep_freeze').length,1);
    assert.ok(outcomes.every(result=>result.room.version<=after.version));
    const receipt=await planInRoom(db,created.code,created.token,input,NOW+16);
    assert.equal(receipt.room.version,after.version,'a late retry cannot spend the points twice');
    const stored=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
    stored.state.winner=0;stored.state.scores[0]=16;stored.state.version++;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished' WHERE code = ?").run(JSON.stringify(stored),created.code);
    const first=await currentRematch(db,created.code,created.token,{version:after.version},NOW+17);
    const rematched=await currentRematch(db,created.code,joined.token,{version:first.room.version},NOW+18);
    const restarted=(rematched.room.state as tactics.SimState).units.find(unit=>unit.id===tipi.id)!;
    assert.equal(restarted.affinities.water,3);assert.equal(Object.values(restarted.affinities).reduce((sum,value)=>sum+value!,0),5);
    assert.notEqual(restarted.loadout[0],'mend','zero-affinity Light is repaired only for the new rules');assert.equal(restarted.loadout[2],'ember');assert.equal(restarted.loadout[3],'water_jet');
    assert.ok(!restarted.loadout.includes('deep_freeze'),'the earned spell is replaced for a new match');
    assert.deepEqual(restarted.cooldowns,{});assert.equal((rematched.room.state as tactics.SimState).round,1);
  }finally{sqlite.close();}
});

test('story libraries are canonical, entry-scoped and reject invalid identifiers before taking seats',async()=>{
  const {db,sqlite}=database();
  try{
    const ids=[getSignature('oh_tipi').id,getSignature('wa_bidi').id];
    for(const learnedSignatures of [null,{},'signature_oh_tipi',['forged'],['ember'],[ids[0],ids[0]],Array(31).fill(ids[0])]){
      await assert.rejects(createRoom(db,{...host,learnedSignatures},NOW),roomError(400,'INVALID_SIGNATURE_LIBRARY'));
    }
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS count FROM rooms').get()!.count,0);
    const created=await createRoom(db,{...host,learnedSignatures:[...ids].reverse()},NOW);
    assert.deepEqual(created.room.players[0].learnedSignatures,[...ids].sort());
    assert.deepEqual(JSON.parse(sqlite.prepare('SELECT player0_roster FROM rooms WHERE code = ?').get(created.code)!.player0_roster as string).learnedSignatures,[...ids].sort());
    await assert.rejects(joinRoom(db,created.code,{...guest,learnedSignatures:['forged']},NOW+1),roomError(400,'INVALID_SIGNATURE_LIBRARY'));
    assert.equal((await currentRoom(db,created.code,created.token,NOW+1)).room.players[1],null);
    const joinToken='d'.repeat(64),joined=await joinRoom(db,created.code,{...guest,joinToken,learnedSignatures:[ids[1]]},NOW+2);
    const retry=await joinRoom(db,created.code,{...guest,joinToken,learnedSignatures:ids},NOW+3);
    assert.deepEqual(retry.room,joined.room,'a join retry cannot expand the match library');
    assert.deepEqual((joined.room.state as tactics.SimState).learnedSignatures,[[...ids].sort(),[ids[1]]]);
    assert.deepEqual(tactics.restoreSimState(joined.room.state),joined.room.state);
    await assert.rejects(planInRoom(db,created.code,created.token,{protocolVersion:16,matchId:joined.room.matchId,round:1,plan:{orders:[],learnedSignatures:ids}},NOW+4),roomError(400,'INVALID_PLAN'));
  }finally{sqlite.close()}
});

test('released v10 learned signatures train, equip and cast privately; retry and rematch preserve the frozen library',async()=>{
  const {db,sqlite}=database();
  try{
    const signature=SIGNATURES.find(spell=>spell.element==='water'&&spell.signatureChampionId!=='oh_tipi')!;
    assert.ok(signature);
    const created=await createRoom(db,{...host,learnedSignatures:[signature.id]},NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    const released=releasedV10.createSimGame([host.roster,guest.roster],joined.room.mapId,undefined,[joined.room.players[0].learnedSignatures,joined.room.players[1]!.learnedSignatures]);
    sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(JSON.stringify({format:'sealed-v10',matchId:joined.room.matchId,state:released,plans:[null,null],fingerprints:[null,null]}),created.code);
    let room=(await currentRoom(db,created.code,created.token,NOW+1)).room;
    for(let round=1;round<=4;round++){
      const input={protocolVersion:10,matchId:room.matchId,round,plan:{orders:[]}};
      await planInRoom(db,created.code,created.token,input,NOW+round*2);
      room=(await planInRoom(db,created.code,joined.token,input,NOW+round*2+1)).room;
    }
    const state=room.state as releasedV10.SimState,tipi=state.units.find(unit=>unit.owner===0&&unit.championId==='oh_tipi')!;
    assert.equal(state.round,5);assert.equal(tipi.affinities.water,3);
    const spells=[signature.id,...tipi.loadout.slice(1)],prep:releasedV10.TeamPlan={orders:[],training:[{unitId:tipi.id,element:'water'},{unitId:tipi.id,element:'water'}],loadouts:[{unitId:tipi.id,spells}]};
    const projected=releasedV10.prepareTeam(state,0,prep),target=releasedV10.legalCasts(projected,tipi.id,undefined,signature.id)[0];
    assert.ok(target,'the borrowed signature is usable after training to its full affinity requirement');
    const plan:releasedV10.TeamPlan={...prep,orders:[{unitId:tipi.id,spellId:signature.id,cast:{q:target.q,r:target.r}}]},input={protocolVersion:10,matchId:room.matchId,round:5,plan};
    const locked=await planInRoom(db,created.code,created.token,input,NOW+20);
    assert.deepEqual(locked.room.state,state);
    const peer=(await currentRoom(db,created.code,joined.token,NOW+21)).room;
    assert.equal(peer.yourPlan,undefined);assert.deepEqual(peer.state,state);
    const retry=await planInRoom(db,created.code,created.token,input,NOW+22);assert.equal(retry.room.version,locked.room.version);
    const resolved=await planInRoom(db,created.code,joined.token,{...input,plan:{orders:[]}},NOW+23);
    const next=resolved.room.state as releasedV10.SimState;
    assert.deepEqual(next.learnedSignatures,state.learnedSignatures);
    assert.equal(next.units.find(unit=>unit.id===tipi.id)!.affinities.water,5);
    assert.ok(next.lastResolution.some(event=>event.kind==='cast'&&event.spellId===signature.id&&event.unitId===tipi.id));
    assert.deepEqual(releasedV10.restoreSimState(next),next);
    const receipt=await planInRoom(db,created.code,created.token,input,NOW+24);assert.equal(receipt.room.version,resolved.room.version);
    const stored=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
    stored.state.winner=0;stored.state.scores[0]=16;stored.state.version++;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished' WHERE code = ?").run(JSON.stringify(stored),created.code);
    const first=await currentRematch(db,created.code,created.token,{version:resolved.room.version,learnedSignatures:SIGNATURES.map(spell=>spell.id)},NOW+25);
    const second=await currentRematch(db,created.code,joined.token,{version:first.room.version},NOW+26);
    const restarted=second.room.state as tactics.SimState;
    assert.deepEqual(restarted.learnedSignatures,state.learnedSignatures,'rematch preserves agreed libraries and cannot accept extra body declarations');
    assert.deepEqual(second.room.players[0].learnedSignatures,[signature.id]);
    assert.equal(restarted.units.find(unit=>unit.id===tipi.id)!.affinities.water,3);
    assert.ok(!restarted.units.find(unit=>unit.id===tipi.id)!.loadout.includes(signature.id),'the now-locked learned slot is repaired for the new match');
  }finally{sqlite.close()}
});

test('released v9 training locks and retries use the exact frozen resolver through the v11 server',async()=>{
  const {db,sqlite}=database();
  try{
    const created=await createRoom(db,host,NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    const kits=[host,guest].map(player=>Object.fromEntries(player.roster.map(id=>[id,spellsV9.defaultLoadout(id)]))) as [Record<string,string[]>,Record<string,string[]>];
    const state=releasedV9.createSimGame([host.roster,guest.roster],'frontier:V9-FROZEN',kits);state.round=3;state.version=3;
    const unit=state.units.find(entry=>entry.owner===0&&entry.championId==='oh_tipi')!;
    const raw:releasedV9.TeamPlan={orders:[{unitId:unit.id,cast:{q:unit.q,r:unit.r},spellId:'water_jet'}],training:[{unitId:unit.id,element:'water'}]};
    const normalized=releasedV9.validatePlan(state,0,raw),fingerprint=await planFingerprint(raw,9);
    assert.notEqual(fingerprint,await planFingerprint(raw,10));
    const serialized=JSON.stringify({format:'sealed-v9',matchId:joined.room.matchId,state,plans:[normalized,null],fingerprints:[fingerprint,null]});
    sqlite.prepare('UPDATE rooms SET state_json = ?, map_id = ?, player0_roster = ?, player1_roster = ? WHERE code = ?').run(serialized,state.mapId,JSON.stringify({roster:host.roster,loadouts:kits[0]}),JSON.stringify({roster:guest.roster,loadouts:kits[1]}),created.code);
    const input={protocolVersion:9,matchId:joined.room.matchId,round:3,plan:raw};
    const repeated=await planInRoom(db,created.code,created.token,input,NOW+2);
    assert.equal(repeated.room.version,joined.room.version);assert.deepEqual(repeated.room.yourPlan,normalized);
    assert.equal(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json,serialized);
    const read=(await getRoom(db,created.code,joined.token,NOW+3,9)).room;
    assert.equal(read.rulesVersion,9);assert.equal(read.protocolVersion,16);assert.deepEqual(read.state,state);assert.equal(read.yourPlan,undefined);
    const next=await planInRoom(db,created.code,joined.token,{...input,plan:{orders:[]}},NOW+4);
    assert.deepEqual(next.room.state,releasedV9.resolveRound(state,[raw,{orders:[]}]))
    assert.deepEqual(releasedV9.restoreSimState(next.room.state),next.room.state);
    assert.equal((await planInRoom(db,created.code,created.token,input,NOW+5)).room.version,next.room.version);
  }finally{sqlite.close()}
});

test('v11 validates declared affinity bounds and starting floors before writing a room or reserving a seat',async()=>{
  const {db,sqlite}=database();
  try{
    const malformed=[null,[],5,{forged:{fire:3}},{oh_tipi:null},{oh_tipi:{water:2,fire:3}},{oh_tipi:{water:7,fire:1}},{oh_tipi:{water:3,fire:1,air:1,earth:1}},{oh_tipi:{water:3.5,fire:1}},{oh_tipi:{water:3,fire:0}},{oh_tipi:{...getChampion('oh_tipi').affinities,forged:1}}];
    for(const affinities of malformed)await assert.rejects(createRoom(db,{...host,affinities},NOW),roomError(400,'INVALID_AFFINITIES'));
    for(const matchKind of ['ranked',true,null,1])await assert.rejects(createRoom(db,{...host,matchKind},NOW),roomError(400,'INVALID_MATCH_KIND'));
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS count FROM rooms').get()!.count,0);
    const created=await createRoom(db,host,NOW);
    await assert.rejects(joinRoom(db,created.code,{...guest,affinities:{s_wayne:{dark:1}}},NOW+1),roomError(400,'INVALID_AFFINITIES'));
    assert.equal((await currentRoom(db,created.code,created.token,NOW+2)).room.players[1],null);
    await assert.rejects(createRoom(db,{...host,loadouts:{oh_tipi:['deep_freeze',...defaultLoadout('oh_tipi').slice(1)]}},NOW),roomError(400,'INVALID_LOADOUT'));
    const allocations={oh_tipi:{...getChampion('oh_tipi').affinities,water:4}};
    const advanced=await createRoom(db,{...host,affinities:allocations,loadouts:{oh_tipi:['deep_freeze',...defaultLoadout('oh_tipi').slice(1)]}},NOW);
    assert.equal(advanced.room.affinityTotals[0],16);assert.equal(advanced.room.players[0].affinities.oh_tipi.water,4);
  }finally{sqlite.close()}
});

test('competitive totals are server-derived, reject imbalance before a seat is consumed, and allow corrected same-key retries',async()=>{
  const {db,sqlite}=database();
  try{
    const hostAffinities={oh_tipi:{...getChampion('oh_tipi').affinities,water:4}};
    const created=await createRoom(db,{...host,affinities:hostAffinities,matchKind:'competitive',affinityTotal:999},NOW);
    assert.equal(created.room.matchKind,'competitive');assert.deepEqual(created.room.affinityTotals,[16,null]);
    const joinToken='e'.repeat(64);
    await assert.rejects(joinRoom(db,created.code,{...guest,joinToken,matchKind:'casual',affinityTotal:16},NOW+1),(error:unknown)=>{
      assert.ok(error instanceof RoomError);assert.equal(error.status,409);assert.equal(error.code,'AFFINITY_MISMATCH');
      assert.match(error.message,/host 16, your team 15/);return true;
    });
    const waiting=(await currentRoom(db,created.code,created.token,NOW+2)).room;
    assert.equal(waiting.version,0);assert.equal(waiting.players[1],null);
    const affinities={treevor_mason:{...getChampion('treevor_mason').affinities,earth:4}};
    const joined=await joinRoom(db,created.code,{...guest,joinToken,affinities,matchKind:'casual'},NOW+3);
    assert.equal(joined.token,joinToken);assert.equal(joined.room.matchKind,'competitive');assert.deepEqual(joined.room.affinityTotals,[16,16]);
    assert.equal(joined.room.players[1]!.matchKind,'competitive');
    const retried=await joinRoom(db,created.code,{...guest,joinToken},NOW+4);
    assert.deepEqual(retried.room,joined.room,'a lost success response recovers the frozen team even if camp has since changed');
    assert.equal(teamAffinityTotal(host.roster,joined.room.players[0].affinities),16);
    assert.deepEqual(tactics.restoreSimState(joined.room.state),joined.room.state);
  }finally{sqlite.close()}
});

test('invitation previews expose only balancing metadata and respect protocol and expiry',async()=>{
  const {db,sqlite}=database();
  try{
    const created=await createRoom(db,{...host,matchKind:'competitive'},NOW);
    const preview=await roomPreview(db,created.code,NOW+1,16);
    assert.deepEqual(preview,{preview:{status:'waiting',mapId:created.room.mapId,matchKind:'competitive',affinityTotals:[15,null]}});
    await assert.rejects(roomPreview(db,created.code,NOW+1,10),roomError(426,'CLIENT_UPGRADE_REQUIRED'));
    const joined=await joinRoom(db,created.code,guest,NOW+2);
    const active=await roomPreview(db,created.code,NOW+3,16);
    assert.deepEqual(active,{preview:{status:'active',mapId:joined.room.mapId,matchKind:'competitive',affinityTotals:[15,15]}});
    for(const secret of [created.token,joined.token,host.name,guest.name,'roster','loadouts','learnedSignatures','state','yourPlan'])assert.ok(!JSON.stringify(active).includes(secret));
    await assert.rejects(roomPreview(db,created.code,NOW+ROOM_TTL_MS,16),roomError(404,'ROOM_NOT_FOUND'));
  }finally{sqlite.close()}
});

test('casual rooms reveal unequal totals and never award or spend affinity during their rounds',async()=>{
  const {db,sqlite}=database();
  try{
    const affinities={oh_tipi:{...getChampion('oh_tipi').affinities,water:5}};
    const created=await createRoom(db,{...host,affinities,matchKind:'casual'},NOW),joined=await joinRoom(db,created.code,guest,NOW+1);
    let room=joined.room;const initial=structuredClone((room.state as tactics.SimState).units.map(unit=>unit.affinities));
    assert.deepEqual(room.affinityTotals,[17,15]);assert.equal(room.matchKind,'casual');
    for(let round=1;round<=4;round++){
      const input={protocolVersion:16,matchId:room.matchId,round,plan:{orders:[]}};
      await planInRoom(db,created.code,created.token,input,NOW+round*2);
      room=(await planInRoom(db,created.code,joined.token,input,NOW+round*2+1)).room;
      assert.deepEqual((room.state as tactics.SimState).units.map(unit=>unit.affinities),initial);
      assert.deepEqual(room.affinityTotals,[17,15]);
    }
    const unit=(room.state as tactics.SimState).units.find(unit=>unit.owner===0)!;
    await assert.rejects(planInRoom(db,created.code,created.token,{protocolVersion:16,matchId:room.matchId,round:5,plan:{orders:[],training:[{unitId:unit.id,element:'air'}]}},NOW+20),roomError(400,'INVALID_PLAN'));
    assert.deepEqual((await currentRoom(db,created.code,created.token,NOW+21)).room.locked,[false,false]);
  }finally{sqlite.close()}
});

test('v11 rematches retain agreed affinity, mode, borrowed spells and latest legal kits without accepting body overrides',async()=>{
  const {db,sqlite}=database();
  try{
    const signature=SIGNATURES.find(spell=>spell.element==='water'&&spell.signatureChampionId!=='oh_tipi')!;
    const hostAffinities={oh_tipi:{...getChampion('oh_tipi').affinities,water:5}};
    const guestAffinities={treevor_mason:{...getChampion('treevor_mason').affinities,earth:5}};
    const created=await createRoom(db,{...host,affinities:hostAffinities,learnedSignatures:[signature.id],matchKind:'competitive'},NOW);
    const joined=await joinRoom(db,created.code,{...guest,affinities:guestAffinities},NOW+1);
    const legacyState=releasedV11.createSimGame([host.roster,guest.roster],joined.room.mapId,undefined,[[signature.id],[]],[hostAffinities,guestAffinities]);
    const legacyStored={format:'sealed-v11',matchId:joined.room.matchId,state:legacyState,plans:[null,null],fingerprints:[null,null]};
    sqlite.prepare('UPDATE rooms SET state_json = ? WHERE code = ?').run(JSON.stringify(legacyStored),created.code);
    const state=legacyState,tipi=state.units.find(unit=>unit.owner===0&&unit.championId==='oh_tipi')!;
    const kit=[signature.id,...tipi.loadout.slice(1)];
    const input={protocolVersion:16,matchId:joined.room.matchId,round:1,plan:{orders:[],loadouts:[{unitId:tipi.id,spells:kit}]}};
    const locked=await planInRoom(db,created.code,created.token,input,NOW+2);
    assert.deepEqual(locked.room.state,state);
    const resolved=await planInRoom(db,created.code,joined.token,{...input,plan:{orders:[],loadouts:[]}},NOW+3);
    assert.deepEqual((resolved.room.state as tactics.SimState).units.find(unit=>unit.id===tipi.id)!.loadout,kit);
    const stored=JSON.parse(sqlite.prepare('SELECT state_json FROM rooms WHERE code = ?').get(created.code)!.state_json as string);
    stored.state.winner=0;stored.state.scores[0]=16;stored.state.version++;
    sqlite.prepare("UPDATE rooms SET state_json = ?, status = 'finished' WHERE code = ?").run(JSON.stringify(stored),created.code);
    const first=await currentRematch(db,created.code,created.token,{version:resolved.room.version,affinities:{},matchKind:'casual'},NOW+4);
    const second=await currentRematch(db,created.code,joined.token,{version:first.room.version},NOW+5);
    assert.equal(second.room.matchKind,'competitive');assert.deepEqual(second.room.affinityTotals,[17,17]);
    const restart=second.room.state as tactics.SimState;
    assert.equal(restart.round,1);assert.deepEqual(restart.units.map(unit=>unit.affinities),state.units.map(unit=>unit.affinities));
    assert.deepEqual(restart.units.find(unit=>unit.id===tipi.id)!.loadout,kit);
    assert.deepEqual(restart.learnedSignatures,[[signature.id],[]]);assert.deepEqual(tactics.restoreSimState(restart),restart);
  }finally{sqlite.close()}
});
