import { applyAction, rulesVersionOf } from "./rules.ts";
import type { GameAction, GameState } from "./rules.ts";
import * as v3 from "./sim.ts";
import * as v4 from "./tactics-v4.ts";
import * as v5 from "./tactics-v5.ts";
import * as v6 from "./tactics.ts";
import * as v7 from "./tactics-v7.ts";
import * as v8 from "./tactics-v8.ts";
import * as v9 from "./tactics-v9.ts";
import * as v10 from "./tactics-v10.ts";
import * as v11 from "./tactics-v11.ts";
import * as v12 from "./tactics-v12.ts";
import * as v13 from "./tactics-v13.ts";
import * as v13Spells from "./spells-v13.ts";
import * as v14 from "./tactics-v14.ts";
import * as v15 from "./tactics-v15.ts";
import * as v15Spells from "./spells-v15.ts";
import * as v14Spells from "./spells-v14.ts";
import { createSimGame, resolveRound, validatePlan } from "./tactics-v16.ts";
import type { SimState, TeamPlan } from "./tactics-v16.ts";
import { CHAMPIONS } from "./roster-v7.ts";
import * as v6Spells from "./spells.ts";
import * as v7Spells from "./spells-v7.ts";
import * as v8Spells from "./spells-v8.ts";
import * as v9Spells from "./spells-v9.ts";
import * as v10Spells from "./spells-v10.ts";
import * as v11Spells from "./spells-v11.ts";
import { defaultLoadout, repairLoadout, validateLoadout, validateLearnedSignatures } from "./spells-v16.ts";
import { getChampion, validateChampionAffinities, teamAffinityTotal, type AffinityAllocation } from "./roster-v11.ts";
import { canonicalPlan, planFingerprint } from "./room-plans.ts";
import { normalizeArenaMapId } from "./arena-v7.ts";

export const SIM_PROTOCOL_VERSION = 16;
type RoomRulesVersion = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16;
type MatchState = GameState | v3.SimState | v4.SimState | v5.SimState | v6.SimState | v7.SimState | v8.SimState | v9.SimState | v10.SimState | v11.SimState | v12.SimState | v13.SimState | v14.SimState | v15.SimState | SimState;
type SealedMatch = {
  format: "sealed-v3" | "sealed-v4" | "sealed-v5" | "sealed-v6" | "sealed-v7" | "sealed-v8" | "sealed-v9" | "sealed-v10" | "sealed-v11" | "sealed-v12" | "sealed-v13" | "sealed-v14" | "sealed-v15" | "sealed-v16"; matchId: string; state: v3.SimState | v4.SimState | v5.SimState | v6.SimState | v7.SimState | v8.SimState | v9.SimState | v10.SimState | v11.SimState | v12.SimState | v13.SimState | v14.SimState | v15.SimState | SimState; plans: [TeamPlan | null, TeamPlan | null];
  fingerprints: [string | null, string | null];
  lastResolved?: { round: number; fingerprints: [string[], string[]] };
};

export const ROOM_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const championIds = new Set(CHAMPIONS.map((champion) => champion.id));

export type RoomDatabase = Pick<D1Database, "prepare">;
type Seat = 0 | 1;
type RoomRow = {
  code: string; version: number; status: "waiting" | "active" | "finished";
  map_id: string; player0_name: string; player0_roster: string;
  player0_token_hash: string; player1_name: string | null;
  player1_roster: string | null; player1_token_hash: string | null;
  state_json: string | null; rematch0: number; rematch1: number;
  created_at: number; updated_at: number; expires_at: number;
};
export type MatchKind = 'casual' | 'competitive';
type Squad = { roster: string[]; loadouts: Record<string, string[]>; learnedSignatures: string[]; affinities: Record<string, AffinityAllocation>; matchKind: MatchKind };
type Player = Squad & { seat: Seat; name: string };
export type RoomSnapshot = {
  code: string; version: number; status: RoomRow["status"]; mapId: string;
  players: [Player, Player | null]; yourSeat: Seat; state: MatchState | null;
  rematch: [boolean, boolean]; expiresAt: number;
  rulesVersion: RoomRulesVersion; protocolVersion: typeof SIM_PROTOCOL_VERSION;
  matchId: string | null; locked: [boolean, boolean]; yourPlan?: TeamPlan;
  matchKind: MatchKind; affinityTotals: [number, number | null];
};
type PlayerInput = Squad & { name: string };

export class RoomError extends Error {
  status: number;
  code: string;
  reload?: boolean;
  requiredProtocolVersion?: number;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = "RoomError";
    this.status = status;
    this.code = code;
  }
}

function requireProtocol(version: unknown, required: RoomRulesVersion = 16): void {
  const supplied = version === undefined ? 1 : version;
  if (typeof supplied === "number" && Number.isInteger(supplied) && supplied >= required && supplied <= SIM_PROTOCOL_VERSION) return;
  const error = new RoomError(426, "CLIENT_UPGRADE_REQUIRED", "A newer Confluence update is ready. Reload this page to continue. Your player key will stay in this browser.");
  error.reload = true;
  error.requiredProtocolVersion = SIM_PROTOCOL_VERSION;
  throw error;
}

function storedMatch(row: RoomRow): GameState | SealedMatch | null {
  if (!row.state_json) return null;
  try {
    const stored = JSON.parse(row.state_json);
    if (((stored?.format === "sealed-v3" && stored.state?.rulesVersion === 3) ||
         (stored?.format === "sealed-v4" && stored.state?.rulesVersion === 4) ||
         (stored?.format === "sealed-v5" && stored.state?.rulesVersion === 5) ||
         (stored?.format === "sealed-v6" && stored.state?.rulesVersion === 6) ||
         (stored?.format === "sealed-v7" && stored.state?.rulesVersion === 7) ||
         (stored?.format === "sealed-v8" && stored.state?.rulesVersion === 8) ||
         (stored?.format === "sealed-v9" && stored.state?.rulesVersion === 9) ||
         (stored?.format === "sealed-v10" && stored.state?.rulesVersion === 10) ||
         (stored?.format === "sealed-v11" && stored.state?.rulesVersion === 11) || (stored?.format === "sealed-v12" && stored.state?.rulesVersion === 12) || (stored?.format === "sealed-v13" && stored.state?.rulesVersion === 13) || (stored?.format === "sealed-v14" && stored.state?.rulesVersion === 14) || (stored?.format === "sealed-v15" && stored.state?.rulesVersion === 15) || (stored?.format === "sealed-v16" && stored.state?.rulesVersion === 16)) &&
        Array.isArray(stored.plans) && stored.plans.length === 2) return stored as SealedMatch;
    rulesVersionOf(stored);
    return stored as GameState;
  } catch { throw new RoomError(409, "UNSUPPORTED_RULES", "This match uses rules this server cannot read yet. Your match is preserved; try again after the update."); }
}

function isSealed(stored: GameState | SealedMatch | null): stored is SealedMatch {
  return stored !== null && "format" in stored && (stored.format === "sealed-v3" || stored.format === "sealed-v4" || stored.format === "sealed-v5" || stored.format === "sealed-v6" || stored.format === "sealed-v7" || stored.format === "sealed-v8" || stored.format === "sealed-v9" || stored.format === "sealed-v10" || stored.format === "sealed-v11" || stored.format === "sealed-v12" || stored.format === "sealed-v13" || stored.format === "sealed-v14" || stored.format === "sealed-v15" || stored.format === "sealed-v16");
}

function roomRules(row: RoomRow): RoomRulesVersion {
  // A waiting lobby always starts a new game when a current client joins it.
  const stored = storedMatch(row);
  return stored === null ? 16 : isSealed(stored) ? stored.state.rulesVersion : rulesVersionOf(stored);
}

function newSealedMatch(players: [Squad, Squad], mapId: string): SealedMatch {
  return { format: "sealed-v16", matchId: crypto.randomUUID(),
    state: createSimGame([players[0].roster, players[1].roster], mapId, [players[0].loadouts, players[1].loadouts], [players[0].learnedSignatures, players[1].learnedSignatures], [players[0].affinities, players[1].affinities]),
    plans: [null, null], fingerprints: [null, null] };
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new RoomError(400, "INVALID_INPUT", "Send a JSON object.");
  }
  return value as Record<string, unknown>;
}

export function validatePlayer(input: unknown): PlayerInput {
  const value = object(input);
  const name = typeof value.name === "string" ? value.name.trim().normalize("NFC") : "";
  if (!name || name.length > 24 || /[\u0000-\u001f\u007f-\u009f]/u.test(name)) {
    throw new RoomError(400, "INVALID_NAME", "Choose a name of 1–24 characters.");
  }
  const roster = value.roster;
  if (!Array.isArray(roster) || roster.length !== 3 ||
      !roster.every((id) => typeof id === "string" && championIds.has(id)) ||
      new Set(roster).size !== 3) {
    throw new RoomError(400, "INVALID_ROSTER", "Choose three different champions.");
  }
  const learnedSignatures = normalizeLearnedSignatures(value.learnedSignatures);
  const affinities = normalizeAffinities(roster as string[], value.affinities);
  const matchKind = normalizeMatchKind(value.matchKind);
  return { name, roster: [...roster] as string[], loadouts: normalizeLoadouts(roster as string[], value.loadouts, 16, learnedSignatures, affinities), learnedSignatures, affinities, matchKind };
}

function normalizeMatchKind(input: unknown): MatchKind {
  if (input === undefined || input === 'casual') return 'casual';
  if (input === 'competitive') return 'competitive';
  throw new RoomError(400, 'INVALID_MATCH_KIND', 'Choose Casual or Competitive.');
}

/** Browser-local story progress is declared, then bounded and frozen at entry. */
function normalizeAffinities(roster: string[], input: unknown): Record<string, AffinityAllocation> {
  try {
    if (input !== undefined && (!input || typeof input !== 'object' || Array.isArray(input) || ![Object.prototype, null].includes(Object.getPrototypeOf(input)))) throw new Error('Choose affinity allocations for your three champions.');
    const supplied = (input ?? {}) as Record<string, unknown>;
    if (Object.keys(supplied).some(id => !roster.includes(id))) throw new Error('Configure affinities only for the three champions in your squad.');
    return Object.fromEntries(roster.map(id => {
      const base = getChampion(id).affinities;
      const allocation = validateChampionAffinities(id, Object.hasOwn(supplied, id) ? supplied[id] : base);
      return [id, allocation];
    }));
  } catch (error) { throw new RoomError(400, 'INVALID_AFFINITIES', error instanceof Error ? error.message.slice(0, 180) : 'Choose valid affinity allocations.'); }
}

function squadAffinityTotal(squad: Squad): number {
  return teamAffinityTotal(squad.roster, squad.affinities);
}

/** Casual libraries are declared at entry, validated, then frozen for the match. */
function normalizeLearnedSignatures(input: unknown): string[] {
  try { return validateLearnedSignatures(input === undefined ? [] : input); }
  catch (error) { throw new RoomError(400, "INVALID_SIGNATURE_LIBRARY", error instanceof Error ? error.message.slice(0, 180) : "Choose known story signature spells."); }
}

function normalizeLoadouts(roster: string[], input: unknown, rulesVersion: RoomRulesVersion = 16, learnedSignatures: string[] = [], affinities: Record<string, AffinityAllocation> = {}): Record<string, string[]> {
  if (input !== undefined && (!input || typeof input !== "object" || Array.isArray(input))) {
    throw new RoomError(400, "INVALID_LOADOUT", "Choose four different spells for each champion.");
  }
  const supplied = (input ?? {}) as Record<string, unknown>;
  if (Object.keys(supplied).some((id) => !roster.includes(id))) {
    throw new RoomError(400, "INVALID_LOADOUT", "Configure spells only for the three champions in your squad.");
  }
  try {
    if (rulesVersion === 11 || rulesVersion === 12) return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? v11Spells.validateLoadout(id, supplied[id], affinities[id], learnedSignatures) : v11Spells.defaultLoadout(id, affinities[id], learnedSignatures)]));
    if (rulesVersion === 13) return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? v13Spells.validateLoadout(id, supplied[id], affinities[id], learnedSignatures) : v13Spells.defaultLoadout(id, affinities[id], learnedSignatures)]));
    if (rulesVersion === 14) return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? v14Spells.validateLoadout(id, supplied[id], affinities[id], learnedSignatures) : v14Spells.defaultLoadout(id, affinities[id], learnedSignatures)]));
    if (rulesVersion === 15) return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? v15Spells.validateLoadout(id, supplied[id], affinities[id], learnedSignatures) : v15Spells.defaultLoadout(id, affinities[id], learnedSignatures)]));
    if (rulesVersion === 16) return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? validateLoadout(id, supplied[id], affinities[id], learnedSignatures) : defaultLoadout(id, affinities[id], learnedSignatures)]));
    if (rulesVersion === 10) return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? v10Spells.validateLoadout(id, supplied[id], undefined, learnedSignatures) : v10Spells.defaultLoadout(id)]));
    const spells = rulesVersion === 9 ? v9Spells : rulesVersion === 8 ? v8Spells : rulesVersion === 7 ? v7Spells : v6Spells;
    return Object.fromEntries(roster.map((id) => [id, Object.hasOwn(supplied, id) ? spells.validateLoadout(id, supplied[id]) : spells.defaultLoadout(id)]));
  } catch (error) {
    throw new RoomError(400, "INVALID_LOADOUT", error instanceof Error ? error.message.slice(0, 180) : "Choose four different spells for each champion.");
  }
}

function storedSquad(json: string, rulesVersion: RoomRulesVersion): Squad {
  // Released rooms may store only an array. Read active matches with their
  // released catalogue; newer defaults belong only to a new agreed match.
  const stored = JSON.parse(json);
  const roster: string[] = Array.isArray(stored) ? stored : stored.roster;
  const learnedSignatures = rulesVersion >= 10 ? normalizeLearnedSignatures(stored.learnedSignatures) : [];
  const affinities = normalizeAffinities(roster, rulesVersion >= 11 ? stored.affinities : undefined);
  const matchKind = rulesVersion >= 11 ? normalizeMatchKind(stored.matchKind) : 'casual';
  return { roster, loadouts: normalizeLoadouts(roster, Array.isArray(stored) ? undefined : stored.loadouts, rulesVersion, learnedSignatures, affinities), learnedSignatures, affinities, matchKind };
}

/** Only new matches adopt new unlocks; keep every still-legal choice in its slot. */
function migratedSquad(json: string): Squad {
  const stored = JSON.parse(json);
  const roster: string[] = Array.isArray(stored) ? stored : stored.roster;
  const learnedSignatures = normalizeLearnedSignatures(Array.isArray(stored) ? undefined : stored.learnedSignatures);
  const affinities = normalizeAffinities(roster, Array.isArray(stored) ? undefined : stored.affinities);
  const matchKind = normalizeMatchKind(Array.isArray(stored) ? undefined : stored.matchKind);
  const loadouts = Object.fromEntries(roster.map(id => [id, repairLoadout(id, stored.loadouts?.[id], affinities[id], learnedSignatures)]));
  return { roster, loadouts, learnedSignatures, affinities, matchKind };
}

function squadJson(player: Squad): string {
  return JSON.stringify({ roster: player.roster, loadouts: player.loadouts, learnedSignatures: player.learnedSignatures, affinities: player.affinities, matchKind: player.matchKind });
}

export function normalizeRoomCode(value: string): string {
  const code = value.trim().toUpperCase().replace(/[-\s]/g, "");
  if (!new RegExp(`^[${CODE_ALPHABET}]{12}$`).test(code)) {
    throw new RoomError(400, "INVALID_CODE", "Enter the 12-character match code.");
  }
  return code;
}

export function validateAction(input: unknown): { version: number; action: GameAction } {
  const value = object(input);
  const version = validateVersion(value.version);
  const action = object(value.action);
  if (action.type === "end") return { version, action: { type: "end" } };
  if (action.type === "guard") {
    if (typeof action.unitId !== "string" || action.unitId.length < 1 || action.unitId.length > 48) {
      throw new RoomError(400, "INVALID_ACTION", "Choose a champion to guard.");
    }
    return { version, action: { type: "guard", unitId: action.unitId } };
  }
  if (action.type !== "move" && action.type !== "cast") {
    throw new RoomError(400, "INVALID_ACTION", "Choose move, cast, guard, or end turn.");
  }
  if (typeof action.unitId !== "string" || action.unitId.length < 1 || action.unitId.length > 48 ||
      !Number.isInteger(action.q) || !Number.isInteger(action.r) ||
      Math.abs(action.q as number) > 20 || Math.abs(action.r as number) > 20) {
    throw new RoomError(400, "INVALID_ACTION", "Choose a champion and a board hex.");
  }
  return {
    version,
    action: { type: action.type, unitId: action.unitId, q: action.q as number, r: action.r as number },
  };
}

function validateVersion(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) {
    throw new RoomError(400, "INVALID_VERSION", "Refresh the match before playing.");
  }
  return value as number;
}

export async function hashSecret(secret: string): Promise<string> {
  const buffer = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return Array.from(new Uint8Array(buffer), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function newToken(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function newCode(): string {
  // Rejection sampling avoids modulo bias (the alphabet has 31 characters).
  let code = "";
  while (code.length < 12) {
    for (const byte of crypto.getRandomValues(new Uint8Array(24))) {
      if (byte < Math.floor(256 / CODE_ALPHABET.length) * CODE_ALPHABET.length) {
        code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
        if (code.length === 12) break;
      }
    }
  }
  return code;
}

function secureEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}

function snapshot(row: RoomRow, seat: Seat): RoomSnapshot {
  const stored = storedMatch(row);
  const sealed = isSealed(stored) ? stored : null;
  const rulesVersion = roomRules(row);
  const players: RoomSnapshot['players'] = [
    { seat: 0, name: row.player0_name, ...(stored === null ? migratedSquad(row.player0_roster) : storedSquad(row.player0_roster, rulesVersion)) },
    row.player1_name === null ? null : { seat: 1, name: row.player1_name, ...storedSquad(row.player1_roster!, rulesVersion) },
  ];
  // Historical rounds can still train; report their current totals from state.
  if (sealed && sealed.state.rulesVersion >= 9) for (const unit of sealed.state.units) {
    if ('affinities' in unit) players[unit.owner]!.affinities[unit.championId] = { ...unit.affinities };
  }
  return {
    code: row.code, version: row.version, status: row.status, mapId: row.map_id,
    players, matchKind: players[0].matchKind,
    affinityTotals: [squadAffinityTotal(players[0]), players[1] ? squadAffinityTotal(players[1]) : null],
    yourSeat: seat, state: sealed ? sealed.state : stored as GameState | null,
    // Consent recorded by the old client cannot opt a player into new rules.
    rematch: [row.rematch0 === SIM_PROTOCOL_VERSION, row.rematch1 === SIM_PROTOCOL_VERSION], expiresAt: row.expires_at,
    rulesVersion, protocolVersion: SIM_PROTOCOL_VERSION,
    matchId: sealed?.matchId ?? null,
    locked: sealed ? [sealed.plans[0] !== null, sealed.plans[1] !== null] : [false, false],
    ...(sealed?.plans[seat] ? { yourPlan: sealed.plans[seat]! } : {}),
  };
}

async function findRoom(db: RoomDatabase, rawCode: string, now: number): Promise<RoomRow> {
  const code = normalizeRoomCode(rawCode);
  const row = await db.prepare("SELECT * FROM rooms WHERE code = ? AND expires_at > ?").bind(code, now).first<RoomRow>();
  if (!row) throw new RoomError(404, "ROOM_NOT_FOUND", "This match was not found or has expired. Ask your friend for a new code.");
  return row;
}

async function authenticate(row: RoomRow, token: string): Promise<Seat> {
  if (!/^[a-f0-9]{64}$/.test(token)) {
    throw new RoomError(401, "UNAUTHORIZED", "This browser does not have a player key for this match.");
  }
  const digest = await hashSecret(token);
  if (secureEqual(digest, row.player0_token_hash)) return 0;
  if (row.player1_token_hash && secureEqual(digest, row.player1_token_hash)) return 1;
  throw new RoomError(401, "UNAUTHORIZED", "Your player key is not valid for this match.");
}

function conflict(): never {
  throw new RoomError(409, "STALE_VERSION", "The match changed. Refresh it and choose your action again.");
}

/** Atomic durable fixed-window limit; never relies on per-Worker memory. */
export async function takeRateLimit(
  db: RoomDatabase, subject: string, scope: string, maximum: number, windowMs: number, now = Date.now(),
): Promise<void> {
  const bucket = Math.floor(now / windowMs);
  const key = await hashSecret(`${scope}:${bucket}:${subject}`);
  const allowed = await db.prepare(
    "INSERT INTO room_rate_limits (key, requests, expires_at) VALUES (?, 1, ?) " +
    "ON CONFLICT(key) DO UPDATE SET requests = requests + 1 WHERE requests < ? RETURNING requests",
  ).bind(key, (bucket + 1) * windowMs, maximum).first<{ requests: number }>();
  if (!allowed) throw new RoomError(429, "RATE_LIMITED", "Too many requests. Wait a moment before trying again.");
}

export async function createRoom(db: RoomDatabase, input: unknown, now = Date.now()) {
  requireProtocol(object(input).protocolVersion);
  const player = validatePlayer(input);
  let mapId: string;
  try { mapId = normalizeArenaMapId(object(input).mapId === undefined ? "confluence" : object(input).mapId); }
  catch { throw new RoomError(400, "INVALID_MAP", "Choose a map seed of 1–24 letters, numbers or hyphens."); }
  const token = newToken();
  const digest = await hashSecret(token);
  // Expired rooms are never readable, even before opportunistic physical cleanup.
  await db.prepare("DELETE FROM rooms WHERE expires_at <= ?").bind(now).run();
  await db.prepare("DELETE FROM room_rate_limits WHERE expires_at <= ?").bind(now).run();
  for (let attempt = 0; attempt < 3; attempt++) {
    const code = newCode();
    const row = await db.prepare(
      "INSERT INTO rooms (code, version, status, map_id, player0_name, player0_roster, player0_token_hash, " +
      "created_at, updated_at, expires_at) VALUES (?, 0, 'waiting', ?, ?, ?, ?, ?, ?, ?) " +
      "ON CONFLICT(code) DO NOTHING RETURNING *",
    ).bind(code, mapId, player.name, squadJson(player), digest, now, now, now + ROOM_TTL_MS).first<RoomRow>();
    if (row) return { code, token, seat: 0 as const, room: snapshot(row, 0) };
  }
  throw new RoomError(503, "ROOM_UNAVAILABLE", "Could not create a match. Please try again.");
}

export async function joinRoom(db: RoomDatabase, code: string, input: unknown, now = Date.now()) {
  const value = object(input);
  requireProtocol(value.protocolVersion);
  const player = validatePlayer(input);
  if (value.joinToken !== undefined && (typeof value.joinToken !== "string" || !/^[a-f0-9]{64}$/.test(value.joinToken))) {
    throw new RoomError(400, "INVALID_JOIN_TOKEN", "Your pending player key could not be read. Reopen the invitation and try again.");
  }
  // The browser retains this secret before sending the request, so a lost
  // success response can be retried without abandoning an occupied seat.
  const token = typeof value.joinToken === "string" ? value.joinToken : newToken();
  const digest = await hashSecret(token);
  const row = await findRoom(db, code, now);
  if (value.joinToken && row.player1_token_hash && secureEqual(digest, row.player1_token_hash)) {
    return { code: row.code, token, seat: 1 as const, room: snapshot(row, 1) };
  }
  if (row.player1_token_hash !== null || row.status !== "waiting") {
    throw new RoomError(409, "ROOM_FULL", "Both seats are taken. Reopen the match in the browser you joined with.");
  }
  const host = migratedSquad(row.player0_roster);
  // The host owns the room rules. A joining body cannot loosen them.
  player.matchKind = host.matchKind;
  const hostTotal = squadAffinityTotal(host), guestTotal = squadAffinityTotal(player);
  if (host.matchKind === 'competitive' && hostTotal !== guestTotal) {
    throw new RoomError(409, 'AFFINITY_MISMATCH', `Competitive requires equal team affinity: host ${hostTotal}, your team ${guestTotal}. Adjust your team in camp to ${hostTotal} points and retry, or use a Casual room.`);
  }
  // Old waiting invitations have no game yet. Joining starts the new rules
  // and translates their seed into the new, explicitly named map family.
  const mapId = normalizeArenaMapId(row.map_id);
  const state = newSealedMatch([host, player], mapId);
  const updated = await db.prepare(
    "UPDATE rooms SET player1_name = ?, player1_roster = ?, player1_token_hash = ?, state_json = ?, player0_roster = ?, map_id = ?, " +
    "status = 'active', version = version + 1, updated_at = ? " +
    "WHERE code = ? AND version = ? AND player1_token_hash IS NULL AND status = 'waiting' AND expires_at > ? RETURNING *",
  ).bind(player.name, squadJson(player), digest, JSON.stringify(state), squadJson(host), mapId, now, row.code, row.version, now).first<RoomRow>();
  if (!updated) {
    // Two copies of one pending join may race. Recover only the same secret;
    // another browser still receives ROOM_FULL and no opponent credentials.
    if (value.joinToken) {
      const latest = await findRoom(db, code, now);
      if (latest.player1_token_hash && secureEqual(digest, latest.player1_token_hash)) {
        return { code: latest.code, token, seat: 1 as const, room: snapshot(latest, 1) };
      }
    }
    throw new RoomError(409, "ROOM_FULL", "Another player has already taken this seat.");
  }
  return { code: row.code, token, seat: 1 as const, room: snapshot(updated, 1) };
}

export async function getRoom(db: RoomDatabase, code: string, token: string, now = Date.now(), protocolVersion: unknown = 1) {
  const row = await findRoom(db, code, now);
  const seat = await authenticate(row, token);
  requireProtocol(protocolVersion, roomRules(row));
  return { room: snapshot(row, seat) };
}

/** A private invitation code permits a minimal pre-join comparison, never a seat or board read. */
export async function roomPreview(db: RoomDatabase, code: string, now = Date.now(), protocolVersion: unknown = 1) {
  const row = await findRoom(db, code, now);
  requireProtocol(protocolVersion, roomRules(row));
  const room = snapshot(row, 0);
  return { preview: { status: room.status, mapId: room.mapId, matchKind: room.matchKind, affinityTotals: room.affinityTotals } };
}

export async function actInRoom(db: RoomDatabase, code: string, token: string, input: unknown, now = Date.now()) {
  const { version, action } = validateAction(input);
  const row = await findRoom(db, code, now);
  const seat = await authenticate(row, token);
  requireProtocol(object(input).protocolVersion, roomRules(row));
  if (roomRules(row) >= 3) throw new RoomError(409, "TEAM_PLAN_REQUIRED", "This match uses simultaneous team orders. Lock your team's plan to play.");
  if (version !== row.version) conflict();
  if (row.status !== "active" || !row.state_json) {
    throw new RoomError(409, "MATCH_NOT_ACTIVE", row.status === "waiting" ? "Waiting for your friend to join." : "This match is over.");
  }
  let state: GameState;
  try {
    state = applyAction(JSON.parse(row.state_json), seat, action);
  } catch (error) {
    throw new RoomError(400, "ILLEGAL_ACTION", error instanceof Error ? error.message.slice(0, 180) : "That action is not allowed.");
  }
  const updated = await db.prepare(
    "UPDATE rooms SET state_json = ?, status = ?, version = version + 1, updated_at = ? " +
    "WHERE code = ? AND version = ? AND status = 'active' AND expires_at > ? RETURNING *",
  ).bind(JSON.stringify(state), state.winner === null ? "active" : "finished", now, row.code, version, now).first<RoomRow>();
  if (!updated) conflict();
  return { room: snapshot(updated, seat) };
}

/** Seal one immutable team plan; optimistic retries merge the other seat's lock. */
export async function planInRoom(db: RoomDatabase, code: string, token: string, input: unknown, now = Date.now()) {
  const value = object(input);
  requireProtocol(value.protocolVersion, 3);
  if (!Number.isSafeInteger(value.round) || (value.round as number) < 1) {
    throw new RoomError(400, "INVALID_ROUND", "Refresh the match before locking your plan.");
  }
  const round = value.round as number;
  if (typeof value.matchId !== "string" || !/^[a-f0-9-]{36}$/.test(value.matchId)) {
    throw new RoomError(400, "INVALID_MATCH", "Load the latest match before locking your plan.");
  }
  // At most two player locks can race in a round. A bounded retry also covers
  // duplicate requests without requiring the client to know the room revision.
  for (let attempt = 0; attempt < 6; attempt++) {
    const row = await findRoom(db, code, now);
    const seat = await authenticate(row, token);
    const stored = storedMatch(row);
    if (!isSealed(stored)) throw new RoomError(409, "CLASSIC_ACTION_REQUIRED", "This is a Classic match. Continue it using the Classic game controls.");
    const rulesVersion = stored.state.rulesVersion;
    requireProtocol(value.protocolVersion, rulesVersion);
    let plan: TeamPlan;
    try { plan = canonicalPlan(value.plan, rulesVersion); }
    catch (error) { throw new RoomError(400, "INVALID_PLAN", error instanceof Error ? error.message : "Choose valid team orders."); }
    const fingerprint = await planFingerprint(plan, rulesVersion);
    if (stored.matchId !== value.matchId) throw new RoomError(409, "STALE_MATCH", "A new match has started. Load its board before planning again.");
    if (stored.lastResolved?.round === round && stored.lastResolved.fingerprints[seat].includes(fingerprint)) {
      return { room: snapshot(row, seat) };
    }
    if (stored.state.round !== round) throw new RoomError(409, "STALE_ROUND", "That round has resolved. Load the latest board before planning again.");
    if (row.status !== "active" || stored.state.winner !== null) {
      throw new RoomError(409, "MATCH_NOT_ACTIVE", "This match is over.");
    }
    let normalized: TeamPlan;
    try { normalized = stored.state.rulesVersion === 3 ? v3.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 4 ? v4.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 5 ? v5.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 6 ? v6.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 7 ? v7.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 8 ? v8.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 9 ? v9.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 10 ? v10.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 11 ? v11.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 12 ? v12.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 13 ? v13.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 14 ? v14.validatePlan(stored.state, seat, plan) : stored.state.rulesVersion === 15 ? v15.validatePlan(stored.state, seat, plan) : validatePlan(stored.state, seat, plan); }
    catch (error) { throw new RoomError(400, "ILLEGAL_PLAN", error instanceof Error ? error.message.slice(0, 180) : "Those orders are not allowed."); }
    const locked = stored.plans[seat];
    if (locked) {
      if (stored.fingerprints[seat] === fingerprint || await planFingerprint(locked, rulesVersion) === await planFingerprint(normalized, rulesVersion)) return { room: snapshot(row, seat) };
      throw new RoomError(409, "PLAN_LOCKED", "Your plan is already locked for this round. It cannot be changed.");
    }
    const plans: SealedMatch["plans"] = [...stored.plans];
    plans[seat] = normalized;
    const fingerprints: SealedMatch["fingerprints"] = [...stored.fingerprints];
    fingerprints[seat] = fingerprint;
    let next: SealedMatch = { ...stored, plans, fingerprints };
    if (plans[0] && plans[1]) {
      // Only the successful CAS publishes resolution. Failed contenders reload
      // the winner's receipt and return without applying the round again.
      const state = stored.state.rulesVersion === 3 ? v3.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 4 ? v4.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 5 ? v5.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 6 ? v6.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 7 ? v7.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 8 ? v8.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 9 ? v9.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 10 ? v10.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 11 ? v11.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 12 ? v12.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 13 ? v13.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 14 ? v14.resolveRound(stored.state, [plans[0], plans[1]]) : stored.state.rulesVersion === 15 ? v15.resolveRound(stored.state, [plans[0], plans[1]]) : resolveRound(stored.state, [plans[0], plans[1]]);
      next = { format: stored.format, matchId: stored.matchId, state, plans: [null, null], fingerprints: [null, null], lastResolved: {
        round, fingerprints: [
          [fingerprints[0]!, await planFingerprint(plans[0], rulesVersion)],
          [fingerprints[1]!, await planFingerprint(plans[1], rulesVersion)],
        ],
      } };
    }
    const updated = await db.prepare(
      "UPDATE rooms SET state_json = ?, status = ?, version = version + 1, updated_at = ? " +
      "WHERE code = ? AND version = ? AND status = 'active' AND expires_at > ? RETURNING *",
    ).bind(JSON.stringify(next), next.state.winner === null ? "active" : "finished", now, row.code, row.version, now).first<RoomRow>();
    if (updated) return { room: snapshot(updated, seat) };
  }
  throw new RoomError(409, "MATCH_BUSY", "The other plan is arriving. Refresh the match and retry your same plan.");
}

export async function requestRematch(db: RoomDatabase, code: string, token: string, input: unknown, now = Date.now()) {
  requireProtocol(object(input).protocolVersion);
  const version = validateVersion(object(input).version);
  const row = await findRoom(db, code, now);
  const seat = await authenticate(row, token);
  if (row.version !== version) conflict();
  if (row.status !== "finished") throw new RoomError(409, "MATCH_NOT_FINISHED", "Finish this match before requesting a rematch.");
  if ((seat === 0 ? row.rematch0 : row.rematch1) === SIM_PROTOCOL_VERSION) return { room: snapshot(row, seat) };
  const rematch0 = seat === 0 || row.rematch0 === SIM_PROTOCOL_VERSION ? SIM_PROTOCOL_VERSION : 0;
  const rematch1 = seat === 1 || row.rematch1 === SIM_PROTOCOL_VERSION ? SIM_PROTOCOL_VERSION : 0;
  const restart = rematch0 === SIM_PROTOCOL_VERSION && rematch1 === SIM_PROTOCOL_VERSION;
  const stored=restart?storedMatch(row):null;
  const rematchSquad=(json:string,owner:Seat):Squad=>{
    if(isSealed(stored)&&(stored.state.rulesVersion===9||stored.state.rulesVersion===10||(stored.state.rulesVersion===11||stored.state.rulesVersion===12||(stored.state.rulesVersion===13||stored.state.rulesVersion===14||stored.state.rulesVersion===15||stored.state.rulesVersion===16)))){
      const previous=JSON.parse(json),roster:string[]=Array.isArray(previous)?previous:previous.roster;
      const loadouts=Object.fromEntries(stored.state.units.filter(unit=>unit.owner===owner).map(unit=>[unit.championId,unit.loadout]));
      const learnedSignatures=stored.state.rulesVersion===10||(stored.state.rulesVersion===11||stored.state.rulesVersion===12||(stored.state.rulesVersion===13||stored.state.rulesVersion===14||stored.state.rulesVersion===15||stored.state.rulesVersion===16))?stored.state.learnedSignatures[owner]:[];
      const affinities=(stored.state.rulesVersion===11||stored.state.rulesVersion===12||(stored.state.rulesVersion===13||stored.state.rulesVersion===14||stored.state.rulesVersion===15||stored.state.rulesVersion===16))?Object.fromEntries(stored.state.units.filter(unit=>unit.owner===owner).map(unit=>[unit.championId,unit.affinities])):undefined;
      const matchKind=(stored.state.rulesVersion===11||stored.state.rulesVersion===12||(stored.state.rulesVersion===13||stored.state.rulesVersion===14||stored.state.rulesVersion===15||stored.state.rulesVersion===16))?normalizeMatchKind(previous.matchKind):'casual';
      return migratedSquad(JSON.stringify({roster,loadouts,learnedSignatures,affinities,matchKind}));
    }
    return migratedSquad(json);
  };
  const squads: [Squad, Squad] | null = restart ? [rematchSquad(row.player0_roster,0), rematchSquad(row.player1_roster!,1)] : null;
  const mapId = restart ? normalizeArenaMapId(row.map_id) : row.map_id;
  const stateJson = squads ? JSON.stringify(newSealedMatch(squads, mapId)) : row.state_json;
  const updated = await db.prepare(
    "UPDATE rooms SET state_json = ?, status = ?, rematch0 = ?, rematch1 = ?, player0_roster = ?, player1_roster = ?, map_id = ?, version = version + 1, updated_at = ? " +
    "WHERE code = ? AND version = ? AND status = 'finished' AND expires_at > ? RETURNING *",
  ).bind(stateJson, restart ? "active" : "finished", restart ? 0 : rematch0, restart ? 0 : rematch1, squads ? squadJson(squads[0]) : row.player0_roster, squads ? squadJson(squads[1]) : row.player1_roster, mapId, now, row.code, version, now).first<RoomRow>();
  if (!updated) conflict();
  return { room: snapshot(updated, seat) };
}
