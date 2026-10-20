/** V11: fixed story-earned affinities and deterministic simultaneous fields. */
import { CHAMPIONS, getChampion, validateChampionAffinities } from './roster-v11.ts';
import type {AffinityAllocation} from './roster-v11.ts';
import { ARENA_RADIUS, ARENA_STARTS, arenaHeightAt, arenaWellAt, arenaBiomeAt, baseTerrainAt, generateArena, normalizeArenaMapId } from './arena-v7.ts';
import { ALL_SPELLS, availableSpellIds, getSignature, SPELLS, STATUS_DEFINITIONS, defaultLoadout, getSpell, spellCost, spellAccess, validateLoadout,validateLearnedSignatures,effectiveSpell,describeSpell,spellScalingSummary } from './spells-v11.ts';
import type { Biome } from './arena-v7.ts';
import type { Spell, Status, StatusApplication, StatusId } from './spells-v11.ts';
import { distance } from './game.ts';
import type { Element, Player, Point } from './game.ts';
import { ELEMENTS } from './sim.ts';
import {formatTile} from './board-labels-v9.ts';
export { CHAMPIONS, getChampion, ALL_SPELLS, availableSpellIds, getSignature, SPELLS, STATUS_DEFINITIONS, getSpell, defaultLoadout, spellCost, spellAccess, validateLoadout,validateLearnedSignatures,effectiveSpell,describeSpell,spellScalingSummary, distance, ELEMENTS };
export const MAPS = [{ id: 'confluence', name: 'Frontier', description: 'Five wells across seeded forests, marshes, ruins and high ground.' }];
export type { Element, Player, Point, Spell, Status, StatusId };
export const RULES_VERSION = 11;
export const BOARD_RADIUS = ARENA_RADIUS;
export const BOARD_SIZE = 1 + 3 * BOARD_RADIUS * (BOARD_RADIUS + 1);
export const MOVE_RANGE = 4;
export const POINTS_TO_WIN = 16;
export const MAX_ROUNDS = 20;
export const MAX_FLUX = 6;
export const MAX_HP = 8;
export const TERRAIN_DURATION = 2;
export type ReactionId = 'steam' | 'magma' | 'quagmire' | 'penumbra' | 'sandblast' | 'crystal_prism' | 'blightsoil' | 'arcstorm' | 'solar_flare' | 'backdraft' | 'hailcurrent' | 'mirrorwater' | 'black_ice' | 'lightbend' | 'shadowdraft';
export const REACTIONS: { id: ReactionId; name: string; elements: [Element, Element]; color: string; symbol: string; description: string; status?: StatusApplication; heal?: number }[] = [
  { id: 'steam', name: 'Steam', elements: ['fire', 'water'], color: '#aad7df', symbol: '≋', description: 'Halves combined spell damage once, rounded up; Ward and Guard apply afterward.' },
  { id: 'magma', name: 'Magma', elements: ['fire', 'earth'], color: '#f69262', symbol: '♨', description: 'After spells and displacement, hurts its occupant for 1. All environmental damage shares a cap of 1 per round.' },
  { id: 'quagmire', name: 'Quagmire', elements: ['earth', 'water'], color: '#90b68c', symbol: '≋', description: 'Movement into or out of this hex costs 2 effort, without stacking with climbing.' },
  { id: 'penumbra', name: 'Penumbra', elements: ['light', 'dark'], color: '#c5a7eb', symbol: '◐', description: 'An occupied well scores 2 instead of 1 for either team after resolution.' },
  { id: 'sandblast', name: 'Sandblast', elements: ['earth', 'air'], color: '#c9ad78', symbol: '⋰', status: { id: 'concussed', turns: 1 }, description: 'Its occupant gains Concussed for next planning: spells cost +1 Flux. Resolve or Clarity prevents it.' },
  { id: 'crystal_prism', name: 'Crystal Prism', elements: ['earth', 'light'], color: '#f0dca9', symbol: '◇', status: { id: 'ward', turns: 1, power: 1 }, description: 'Its occupant gains Ward 1 for the next exchange, regardless of team.' },
  { id: 'blightsoil', name: 'Blightsoil', elements: ['earth', 'dark'], color: '#9b82b5', symbol: '†', status: { id: 'wither', turns: 2 }, description: 'Its occupant gains Wither for two planning rounds, reducing future healing by 1.' },
  { id: 'arcstorm', name: 'Arcstorm', elements: ['fire', 'air'], color: '#efae66', symbol: 'ϟ', description: 'When this pair first forms, hurts its post-displacement occupant for 1. Shares the environmental cap with Magma; refreshing does not retrigger it.' },
  { id: 'solar_flare', name: 'Solar Flare', elements: ['fire', 'light'], color: '#ffe08c', symbol: '☼', status: { id: 'clarity', turns: 1 }, description: 'Its occupant gains Clarity, intercepting incoming control immediately and protecting next planning.' },
  { id: 'backdraft', name: 'Backdraft', elements: ['fire', 'dark'], color: '#ba737c', symbol: '♨', status: { id: 'burn', turns: 1 }, description: 'Its occupant gains Burn for the next resolution; Wet or cleanse prevents the mark.' },
  { id: 'hailcurrent', name: 'Hailcurrent', elements: ['water', 'air'], color: '#9ddce8', symbol: '❄', status: { id: 'chilled', turns: 1 }, description: 'Freezes the field unless Fire is present. Entering Ice slides to the last connected icy hex in that direction. Its occupant gains Chilled; Resolve or Clarity prevents the status.' },
  { id: 'mirrorwater', name: 'Mirrorwater', elements: ['water', 'light'], color: '#d6ece6', symbol: '≈', heal: 1, description: 'Heals its occupant by 1 in the current simultaneous exchange, for either team. Existing Wither reduces the aggregate heal once.' },
  { id: 'black_ice', name: 'Black Ice', elements: ['water', 'dark'], color: '#7897be', symbol: '⌘', status: { id: 'rooted', turns: 1 }, description: 'Freezes the field unless Fire is present and Roots its occupant for next planning. Spells and Guard remain available; Resolve prevents repeated locking.' },
  { id: 'lightbend', name: 'Lightbend', elements: ['air', 'light'], color: '#dbefaf', symbol: '»', status: { id: 'haste', turns: 1 }, description: 'Its occupant gains Haste: +1 movement effort next planning, regardless of team.' },
  { id: 'shadowdraft', name: 'Shadowdraft', elements: ['air', 'dark'], color: '#a497cc', symbol: '◌', status: { id: 'blind', turns: 1 }, description: 'Blinds its occupant next planning, reducing spell range by 1, minimum 1. Resolve or Clarity prevents it.' },
];
export type SimCell = Point & { well: boolean; terrain: string; biome: Biome; height: 0 | 1; ttl?: number; elements?: Element[]; reactions?: ReactionId[]; barrier?: number; ice?: true };
export type Cell = SimCell;
export type SimUnit = Point & {
  id: string; championId: string; owner: Player; hp: number; maxHp: number; guard?: boolean; respawn?: number;
  loadout: string[]; affinities:AffinityAllocation; flux: number; maxFlux: number; cooldowns: Record<string, number>; statuses: Partial<Record<StatusId, Status>>;
};
export type Order = { unitId: string; move?: Point; cast?: Point; spellId?: string; guard?: boolean };
export type TeamPlan = { orders: Order[]; training?:{unitId:string;element:Element}[]; loadouts?:{unitId:string;spells:string[]}[] };
export type SimEvent = {
  kind: 'move' | 'bounce' | 'cast' | 'reaction' | 'damage' | 'heal' | 'push' | 'defeat' | 'respawn' | 'score' | 'guard' | 'fizzle' | 'surface';
  text: string; unitId?: string; owner?: Player; from?: Point; to?: Point; q?: number; r?: number; amount?: number;
  elements?: Element[]; terrain?: string; spellId?: string; status?: StatusId;
};
export type SimState = { rulesVersion: 11; version: number; mapId: string; round: number; scores: [number, number]; learnedSignatures:[string[],string[]]; units: SimUnit[]; cells: SimCell[]; log: string[]; winner: Player | 'draw' | null; lastResolution: SimEvent[] };
const ELEMENT_ORDER: Element[] = ['fire', 'water', 'earth', 'air', 'light', 'dark'];
const CONTROL: StatusId[] = ['rooted', 'chilled', 'concussed', 'blind'];
const AILMENTS: StatusId[] = ['burn', 'wither', ...CONTROL];
const DIRS: Point[] = [{ q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 }, { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 }];
const STARTS = ARENA_STARTS;
const DEFAULT = ['oh_tipi', 'wa_bidi', 'treevor_mason'];
const key = (a: Point) => `${a.q},${a.r}`;
const same = (a: Point, b: Point) => a.q === b.q && a.r === b.r;
const point = (a: Point): Point => ({ q: a.q, r: a.r });
const sortedUnits = (units: SimUnit[]) => [...units].sort((a, b) => a.id.localeCompare(b.id));
const opposite = (owner: Player): Player => owner === 0 ? 1 : 0;
const heightAt = arenaHeightAt;
const wellAt = arenaWellAt;
/** Directional spells use six explicit aim axes, so rotation never needs a biased tie break. */
function aimDirection(from: Point, target: Point): number {
  const length = distance(from, target);
  return length ? DIRS.findIndex((direction) => target.q - from.q === direction.q * length && target.r - from.r === direction.r * length) : -1;
}
export const isAlive = (unit: SimUnit) => unit.hp > 0 && unit.respawn === undefined;
export const getCell = (state: SimState, q: number, r: number) => state.cells.find((cell) => cell.q === q && cell.r === r);
const occupant = (state: SimState, at: Point) => state.units.find((unit) => isAlive(unit) && same(unit, at));
const emit = (state: SimState, event: SimEvent) => { state.lastResolution.push(event); state.log.push(event.text); };
const name = (unit: SimUnit) => getChampion(unit.championId).name;
export const reactionsFor = (elements: readonly Element[]): ReactionId[] => REACTIONS.filter((reaction) => reaction.elements.every((element) => elements.includes(element))).map((reaction) => reaction.id);
export const cellElements = (cell: SimCell): Element[] => cell.elements ?? (ELEMENT_ORDER.includes(cell.terrain as Element) ? [cell.terrain as Element] : REACTIONS.find((reaction) => reaction.id === cell.terrain)?.elements ?? []);
const hasReaction = (cell: SimCell, reaction: ReactionId) => (cell.reactions ?? reactionsFor(cellElements(cell))).includes(reaction);
const activeElement = (cell: SimCell, element: Element) => cell.ttl !== undefined && cellElements(cell).includes(element);
const pureElement = (cell: SimCell, element: Element) => activeElement(cell, element) && cellElements(cell).length === 1;
export const isIce = (cell: SimCell): boolean => cell.ice === true;
export const isFlooded = (cell: SimCell): boolean => activeElement(cell, 'water') && !isIce(cell);
export type SurfaceTrait = { id: 'ice' | 'flood' | 'embers' | 'rough' | 'current' | 'radiance' | 'gloom'; name: string; description: string };
/** Exact rules shared by inspection, help and the resolver. Base biomes keep their own rules. */
export function surfaceTraits(cell: SimCell): SurfaceTrait[] {
  const traits: SurfaceTrait[] = [];
  if (isIce(cell)) traits.push({ id: 'ice', name: 'Ice', description: 'Entering Ice slides straight to the last connected icy hex. The whole slide costs 1 effort; barriers, ruins and the edge stop it. Landing collisions bounce as usual.' });
  else if (isFlooded(cell)) traits.push({ id: 'flood', name: 'Flood', description: 'Entering or leaving costs 2 effort. Does not stack with rough ground, marsh or climbing.' });
  if (pureElement(cell, 'fire')) traits.push({ id: 'embers', name: 'Embers', description: 'Hurts the final occupant for 1 after displacement. All environmental hazards together deal at most 1 per round.' });
  if (activeElement(cell, 'earth') && !isIce(cell)) traits.push({ id: 'rough', name: 'Rough ground', description: 'Entering or leaving costs 2 effort. Does not stack with flood, marsh or climbing.' });
  if (activeElement(cell, 'air')) traits.push({ id: 'current', name: 'Current', description: 'Starting here grants 1 extra movement effort, without stacking with Haste. Rooted still prevents movement.' });
  if (pureElement(cell, 'light')) traits.push({ id: 'radiance', name: 'Radiance', description: 'Its occupant gains Clarity, blocking incoming control now and during next planning. Benefits either team.' });
  if (pureElement(cell, 'dark')) traits.push({ id: 'gloom', name: 'Gloom', description: 'Its occupant gains Wither for next planning, reducing future healing by 1. Affects either team.' });
  return traits;
}

export function createSimGame(rosters: [string[], string[]] = [[...DEFAULT], [...DEFAULT]], mapId = 'confluence', loadouts?: [Record<string, string[]>, Record<string, string[]>],learnedSignatures:[string[],string[]]=[[],[]],affinities?:[Record<string,AffinityAllocation>,Record<string,AffinityAllocation>]): SimState {
  mapId = normalizeArenaMapId(mapId);
  if(!Array.isArray(learnedSignatures)||learnedSignatures.length!==2)throw new Error('Learned signatures must describe both squads.');
  learnedSignatures=learnedSignatures.map(validateLearnedSignatures) as [string[],string[]];
  if (!Array.isArray(rosters) || rosters.length !== 2 || rosters.some((roster) => !Array.isArray(roster) || roster.length !== 3 || new Set(roster).size !== 3 || roster.some((id) => !CHAMPIONS.some((champion) => champion.id === id)))) throw new Error('Choose exactly 3 different canonical champions per squad.');
  if(affinities!==undefined&&(!Array.isArray(affinities)||affinities.length!==2))throw new Error('Affinities must describe both squads.');
  const allocated:[Record<string,AffinityAllocation>,Record<string,AffinityAllocation>]=[{},{}];
  for(const owner of [0,1] as const){
    const supplied=affinities===undefined?{}:object(affinities[owner],rosters[owner],'Squad affinities');
    if(![Object.prototype,null].includes(Object.getPrototypeOf(supplied)))throw new Error('Squad affinities must be a plain object.');
    for(const id of rosters[owner])allocated[owner][id]=validateChampionAffinities(id,Object.hasOwn(supplied,id)?supplied[id]:getChampion(id).affinities);
  }
  if (loadouts !== undefined && (!Array.isArray(loadouts) || loadouts.length !== 2)) throw new Error('Loadouts must describe both squads.');
  for (const owner of [0, 1] as const) if (loadouts?.[owner] !== undefined) {
    const selected = object(loadouts[owner], rosters[owner], 'Squad loadouts');
    for (const [id, equipped] of Object.entries(selected)) validateLoadout(id, equipped,allocated[owner][id],learnedSignatures[owner]);
  }
  const cells: SimCell[] = generateArena(mapId).map((cell) => ({ ...cell }));
  const units = rosters.flatMap((roster, owner) => roster.map((championId, index): SimUnit => ({ id: `${owner}-${championId}`, championId, owner: owner as Player, ...STARTS[owner as Player][index], hp: MAX_HP, maxHp: MAX_HP, flux: MAX_FLUX, maxFlux: MAX_FLUX, cooldowns: {}, statuses: {}, affinities:allocated[owner as Player][championId], loadout: validateLoadout(championId, loadouts?.[owner as Player]?.[championId] ?? defaultLoadout(championId,allocated[owner as Player][championId],learnedSignatures[owner as Player]),allocated[owner as Player][championId],learnedSignatures[owner as Player]) })));
  return { rulesVersion: RULES_VERSION, version: 1, mapId, round: 1, scores: [0, 0], learnedSignatures, cells, units, winner: null, log: ['Move, choose one equipped spell, signature or Guard, then seal. Teams resolve simultaneously.'], lastResolution: [] };
}

export const isCellSolid = (cell: SimCell): boolean => Boolean(cell.barrier) || cell.biome === 'ruins';
export const terrainCover = (cell: SimCell): number => cell.biome === 'forest' ? 1 : 0;
export function movementCost(from: SimCell, to: SimCell): number {
  if (isIce(to)) return 1;
  const rough = (cell: SimCell) => !isIce(cell) && (activeElement(cell, 'earth') || hasReaction(cell, 'quagmire'));
  return to.biome === 'marsh' || isFlooded(from) || isFlooded(to) || rough(from) || rough(to) || to.height > from.height ? 2 : 1;
}
export function movementBudget(unit: SimUnit, state?: SimState): number {
  const startingCell = state && getCell(state, unit.q, unit.r);
  return unit.statuses.rooted ? 0 : (unit.statuses.chilled ? MOVE_RANGE - 1 : MOVE_RANGE) + (unit.statuses.haste || (startingCell && activeElement(startingCell, 'air')) ? 1 : 0);
}
type MovementRoute = { path: SimCell[]; cost: number };
/** A straight slide stops on the last Ice cell, before dry ground or an obstacle. */
function slideStep(from: Point, direction: Point, cells: Map<string, SimCell>): SimCell[] {
  let cell = cells.get(`${from.q + direction.q},${from.r + direction.r}`);
  if (!cell || isCellSolid(cell)) return [];
  const crossed = [cell];
  if (isIce(cell)) while (true) {
    const further = cells.get(`${cell.q + direction.q},${cell.r + direction.r}`);
    if (!further || isCellSolid(further) || !isIce(further)) break;
    crossed.push(further); cell = further;
  }
  return crossed;
}
/** Ice edges are whole straight slides. Preview and resolution use the same reachable landings. */
function movementPaths(state: SimState, unit: SimUnit): Map<string, MovementRoute> {
  const paths = new Map<string, MovementRoute>(); const budget = movementBudget(unit, state);
  const cells = new Map(state.cells.map((cell) => [key(cell), cell])); const start = cells.get(key(unit));
  if (!start || !budget) return paths;
  const queue = [{ cell: start, cost: 0, path: [] as SimCell[] }]; const costs = new Map([[key(start), 0]]);
  const sign = unit.owner === 0 ? 1 : -1;
  while (queue.length) {
    queue.sort((a, b) => a.cost - b.cost || sign * (a.cell.q - b.cell.q || a.cell.r - b.cell.r));
    const current = queue.shift()!;
    if (current.cost !== costs.get(key(current.cell))) continue;
    if (current.path.length) paths.set(key(current.cell), { path: current.path, cost: current.cost });
    for (const direction of DIRS) {
      const crossed = slideStep(current.cell, direction, cells), cell = crossed.at(-1);
      if (!cell) continue;
      const cost = current.cost + movementCost(current.cell, crossed[0]);
      if (cost > budget) continue;
      if (cost >= (costs.get(key(cell)) ?? Infinity)) continue;
      costs.set(key(cell), cost); queue.push({ cell, cost, path: [...current.path, ...crossed] });
    }
  }
  return paths;
}
export function movementPath(state: SimState, unitId: string, target: Point): SimCell[] | null {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit) || same(unit, target)) return null;
  return movementPaths(state, unit).get(key(target))?.path ?? null;
}
export function movementEffort(state: SimState, unitId: string, target: Point): number | null {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit)) return null;
  if (same(unit, target)) return 0;
  return movementPaths(state, unit).get(key(target))?.cost ?? null;
}
export function legalMoves(state: SimState, unitId: string): SimCell[] {
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null) return [];
  const unit = state.units.find((entry) => entry.id === unitId); if (!unit || !isAlive(unit)) return [];
  const paths = movementPaths(state, unit);
  return state.cells.filter((cell) => paths.has(key(cell)));
}
function clearSight(state: SimState, from: SimCell, target: SimCell): boolean {
  const range = distance(from, target); if (range <= 1) return true;
  const queue = [from]; const seen = new Set([key(from)]);
  for (let i = 0; i < queue.length; i++) for (const direction of DIRS) {
    const current = queue[i]; const next = getCell(state, current.q + direction.q, current.r + direction.r);
    if (!next || seen.has(key(next)) || distance(from, next) + distance(next, target) !== range || distance(from, next) <= distance(from, current)) continue;
    if (same(next, target)) return true;
    if (isCellSolid(next) || next.height > Math.max(from.height, target.height)) continue;
    seen.add(key(next)); queue.push(next);
  }
  return false;
}
export function castAvailability(state: SimState, unitId: string, spellId: string): { available: boolean; reason?: string; cost: number } {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit)) return { available: false, cost: 0, reason: 'Champion is returning.' };
  const spell = ALL_SPELLS.find((entry) => entry.id === spellId);
  if (!spell || (spell.signatureChampionId!==unit.championId&&!unit.loadout.includes(spellId))) return { available: false, cost: 0, reason: 'Spell is not equipped.' };
  const cost = spellCost(unit.championId, spellId,unit.affinities) + (unit.statuses.concussed ? 1 : 0);
  const access=spellAccess(unit.championId,spellId,unit.affinities,state.learnedSignatures[unit.owner]);
  if(!access.unlocked)return {available:false,cost,reason:access.reason};
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null) return { available: false, cost, reason: 'Match is finished.' };
  if ((unit.cooldowns[spellId] ?? 0) > 0) return { available: false, cost, reason: `Ready after ${unit.cooldowns[spellId]} resolution(s).` };
  if (unit.flux < cost) return { available: false, cost, reason: `Needs ${cost} Flux; ${unit.flux} available.` };
  return { available: true, cost };
}
/** Effective centre reach; the footprint may extend beyond its aimed centre. */
export function spellRange(unit: SimUnit, spell: Spell, origin: SimCell, target: SimCell): number {
  spell=effectiveSpell(unit.championId,spell.id,unit.affinities);
  return spell.range === 0 ? 0 : Math.max(1, spell.range - (unit.statuses.blind ? 1 : 0)) + (origin.height > target.height ? 1 : 0);
}
export function legalCasts(state: SimState, unitId: string, from?: Point, spellId?: string): SimCell[] {
  const unit = state.units.find((entry) => entry.id === unitId); if (!unit || !isAlive(unit)) return [];
  const id = spellId ?? unit.loadout[0]; if (!castAvailability(state, unitId, id).available) return [];
  const spell = effectiveSpell(unit.championId,id,unit.affinities); const origin = getCell(state, from?.q ?? unit.q, from?.r ?? unit.r); if (!origin) return [];
  return state.cells.filter((cell) => {
    if (spell.range === 0) return same(origin, cell);
    if (spell.shape === 'line' && same(origin, cell)) return false;
    if ((spell.shape === 'sweep' || spell.shape === 'wall') && aimDirection(origin, cell) < 0) return false;
    const range = spellRange(unit, spell, origin, cell);
    return distance(origin, cell) <= range && clearSight(state, origin, cell);
  });
}
/** A line includes every tied shortest ray cell, never an arbitrary left/right tie. */
export function spellArea(state: SimState, unitId: string, spellId: string, target: Point, from?: Point): SimCell[] {
  const unit = state.units.find((entry) => entry.id === unitId); if (!unit) return [];
  const origin = from ?? unit; const spell = effectiveSpell(unit.championId,spellId,unit.affinities);
  if (spell.shape === 'sweep' || spell.shape === 'wall') {
    const direction = aimDirection(origin, target); if (direction < 0) return [];
    const forward = DIRS[direction]; const across = DIRS[(direction + 2) % 6];
    const points = spell.shape === 'wall'
      ? [target, { q: target.q + across.q, r: target.r + across.r }, { q: target.q - across.q, r: target.r - across.r }]
      : [target, ...[-1, 1].flatMap((offset) => { const side = DIRS[(direction + offset + 6) % 6]; return Array.from({ length: spell.radius || 1 }, (_, index) => ({ q: target.q + (side.q - forward.q) * (index + 1), r: target.r + (side.r - forward.r) * (index + 1) })); })];
    return state.cells.filter((cell) => points.some((entry) => same(entry, cell)));
  }
  if (spell.shape === 'line') {
    const start = getCell(state, origin.q, origin.r); const end = getCell(state, target.q, target.r);
    if (!start || !end || same(start, end)) return [];
    const length = distance(start, end); const limit = Math.max(start.height, end.height); const included = new Set<string>();
    const visit = (cell: SimCell, path: SimCell[]) => {
      if (same(cell, end)) { path.forEach((entry) => included.add(key(entry))); return; }
      for (const direction of DIRS) {
        const next = getCell(state, cell.q + direction.q, cell.r + direction.r);
        if (!next || distance(start, next) + distance(next, end) !== length || distance(start, next) <= distance(start, cell)) continue;
        if (!same(next, end) && (isCellSolid(next) || next.height > limit)) continue;
        visit(next, [...path, next]);
      }
    };
    visit(start, []); return state.cells.filter((cell) => included.has(key(cell)));
  }
  return state.cells.filter((cell) => spell.shape === 'ring' ? distance(cell, target) === spell.radius
    : distance(cell, target) <= (spell.shape === 'burst' ? spell.radius : 0));
}
function object(input: unknown, allowed: string[], label: string): Record<string, unknown> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error(`${label} must be an object.`);
  const value = input as Record<string, unknown>;
  if (Object.keys(value).some((field) => !allowed.includes(field))) throw new Error(`${label} contains an unknown field.`);
  return value;
}
function readPoint(input: unknown): Point {
  const value = object(input, ['q', 'r'], 'Hex');
  if (!Number.isSafeInteger(value.q) || !Number.isSafeInteger(value.r)) throw new Error('Hex coordinates must be whole numbers.');
  return { q: value.q as number, r: value.r as number };
}
function preparation(state:SimState,player:Player,input:unknown):{projected:SimState;loadouts?:TeamPlan['loadouts']} {
  if(state.rulesVersion!==RULES_VERSION||state.winner!==null||(player!==0&&player!==1))throw new Error('This tactics match is not active.');
  const value=object(input,['orders','training','loadouts'],'Plan');
  if(!Array.isArray(value.orders)||value.orders.length>3)throw new Error('At most 3 champion orders are allowed.');
  const projected=structuredClone(state),loadouts:NonNullable<TeamPlan['loadouts']>=[];
  const own=(id:unknown)=>{const unit=projected.units.find(candidate=>candidate.id===id);if(!unit||unit.owner!==player)throw new Error('Prepare only your own champions.');return unit;};
  for(const unit of projected.units.filter(unit=>unit.owner===player))unit.affinities=validateChampionAffinities(unit.championId,unit.affinities);
  if(value.training!==undefined){
    if(!Array.isArray(value.training)||value.training.length)throw new Error('Affinity is earned in Story and allocated before a match.');
  }
  if(value.loadouts!==undefined){
    if(!Array.isArray(value.loadouts)||value.loadouts.length>3)throw new Error('Send at most one loadout per champion.');
    const changed=new Set<string>();
    for(const raw of value.loadouts){
      const entry=object(raw,['unitId','spells'],'Loadout'),unit=own(entry.unitId);
      if(changed.has(unit.id))throw new Error('Configure each champion only once.');
      changed.add(unit.id);unit.loadout=validateLoadout(unit.championId,entry.spells,unit.affinities,state.learnedSignatures[player]);
      loadouts.push({unitId:unit.id,spells:[...unit.loadout]});
    }
    loadouts.sort((a,b)=>a.unitId.localeCompare(b.unitId));
  }
  return {projected,...(loadouts.length?{loadouts}:{})};
}
/** Preview equipment changes without revealing or changing either sealed plan. */
export function prepareTeam(state:SimState,player:Player,plan:TeamPlan):SimState {
  return preparation(state,player,plan).projected;
}
export function validatePlan(state: SimState, player: Player, input: unknown): TeamPlan {
  const prepared=preparation(state,player,input);state=prepared.projected;
  const value = input as {orders:unknown[]};
  const orders = new Map<string, Order>();
  for (const raw of value.orders) {
    const entry = object(raw, ['unitId', 'move', 'cast', 'spellId', 'guard'], 'Order');
    if (typeof entry.unitId !== 'string' || orders.has(entry.unitId)) throw new Error('Each champion may have one order.');
    const unit = state.units.find((candidate) => candidate.id === entry.unitId);
    if (!unit || unit.owner !== player || !isAlive(unit)) throw new Error('Order only your living champions.');
    const order: Order = { unitId: unit.id };
    if (entry.move !== undefined) { order.move = readPoint(entry.move); if (!movementPath(state, unit.id, order.move)) throw new Error('Movement is blocked or exceeds available effort.'); }
    if (entry.guard !== undefined && entry.guard !== true) throw new Error('Guard must be true when included.');
    if (entry.cast !== undefined) {
      if (entry.guard) throw new Error('Choose a spell or Guard, not both.');
      const id = entry.spellId ?? unit.loadout[0];
      if (typeof id !== 'string') throw new Error('Spell must be an equipped identifier.');
      const availability = castAvailability(state, unit.id, id); if (!availability.available) throw new Error(availability.reason);
      order.spellId = id; order.cast = readPoint(entry.cast);
      if (!legalCasts(state, unit.id, order.move, id).some((cell) => same(cell, order.cast!))) throw new Error('Aim within range and sight from the planned landing.');
    } else { if (entry.spellId !== undefined) throw new Error('A spell needs a ground target.'); order.guard = true; }
    orders.set(unit.id, order);
  }
  return { orders: sortedUnits(state.units.filter((unit) => unit.owner === player && isAlive(unit))).map((unit) => orders.get(unit.id) ?? { unitId: unit.id, guard: true }),...(prepared.loadouts?{loadouts:prepared.loadouts}:{}) };
}
function destinations(state: SimState, requests: Map<string, Point>, kind: 'move' | 'push'): void {
  const units = sortedUnits(state.units.filter(isAlive)); const active = new Set(requests.keys()); const counts = new Map<string, number>();
  for (const target of requests.values()) counts.set(key(target), (counts.get(key(target)) ?? 0) + 1);
  for (const [id, target] of requests) if (counts.get(key(target))! > 1 || !getCell(state, target.q, target.r) || isCellSolid(getCell(state, target.q, target.r)!)) active.delete(id);
  let changed = true;
  while (changed) { changed = false; for (const unit of units) if (active.has(unit.id)) { const blocker = units.find((entry) => same(entry, requests.get(unit.id)!)); if (blocker && !active.has(blocker.id)) { active.delete(unit.id); changed = true; } } }
  const before = new Map(units.map((unit) => [unit.id, point(unit)]));
  for (const unit of units) { const target = requests.get(unit.id); if (!target) continue; if (active.has(unit.id)) { unit.q = target.q; unit.r = target.r; emit(state, { kind, unitId: unit.id, owner: unit.owner, from: before.get(unit.id), to: point(unit), text: `${name(unit)} ${kind === 'move' ? 'moves' : 'is displaced'} to ${formatTile(unit)}.` }); } else emit(state, { kind: 'bounce', unitId: unit.id, owner: unit.owner, from: before.get(unit.id), to: target, text: `${name(unit)} stays: simultaneous ${kind} blocked.` }); }
}
type Cast = { caster: SimUnit; spell: Spell; target: Point; area: SimCell[] };
function mergeStatus(statuses: SimUnit['statuses'], application: StatusApplication): void {
  const previous = statuses[application.id]; statuses[application.id] = { turns: Math.max(previous?.turns ?? 0, application.turns), power: Math.max(previous?.power ?? 0, application.power ?? 1) };
}
function defeat(state: SimState, unit: SimUnit): void {
  if (unit.hp > 0 || unit.respawn !== undefined) return;
  unit.hp = 0; unit.respawn = state.round + 2; unit.statuses = {}; state.scores[opposite(unit.owner)]++;
  emit(state, { kind: 'defeat', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: 1, text: `${name(unit)} falls; opponent +1. Returns in round ${state.round + 2}.` });
}
function returns(state: SimState): void {
  for (const unit of sortedUnits(state.units.filter((entry) => entry.respawn !== undefined && entry.respawn <= state.round))) {
    const sign = unit.owner === 0 ? 1 : -1; const own = state.units.filter((entry) => entry.owner === unit.owner); const start = STARTS[unit.owner][own.findIndex((entry) => entry.id === unit.id)];
    const free = state.cells.filter((cell) => !isCellSolid(cell) && !occupant(state, cell)).sort((a, b) => Number(a.well) - Number(b.well) || sign * (a.q - b.q) || distance(a, start) - distance(b, start) || sign * (a.r - b.r));
    if (!free[0]) continue;
    unit.q = free[0].q; unit.r = free[0].r; unit.hp = unit.maxHp; unit.flux = unit.maxFlux; unit.cooldowns = {}; unit.statuses = {}; delete unit.respawn; delete unit.guard;
    emit(state, { kind: 'respawn', unitId: unit.id, owner: unit.owner, to: point(unit), text: `${name(unit)} returns with full health and Flux.` });
  }
}

export function resolveRound(state: SimState, plans: [TeamPlan, TeamPlan]): SimState {
  if (!Array.isArray(plans) || plans.length !== 2) throw new Error('Two sealed plans are required.');
  const normalized = [validatePlan(state, 0, plans[0]), validatePlan(state, 1, plans[1])];
  const next=prepareTeam(prepareTeam(state,0,normalized[0]),1,normalized[1]); next.version++; next.lastResolution = [];
  const orders = new Map(normalized.flatMap((plan) => plan.orders).map((order) => [order.unitId, order]));
  for (const unit of next.units.filter(isAlive)) { unit.guard = orders.get(unit.id)!.guard === true; if (unit.guard) emit(next, { kind: 'guard', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, text: `${name(unit)} Guards: absorb 1, resist displacement, recover +1 Flux.` }); }
  destinations(next, new Map([...orders.values()].filter((order) => order.move).map((order) => [order.unitId, order.move!])), 'move');
  const casts: Cast[] = [];
  // Every legality check reads the same post-move, pre-effect snapshot. No new effect cancels a sealed spell.
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const order = orders.get(unit.id)!; if (!order.cast) continue;
    const spell = effectiveSpell(unit.championId,order.spellId!,unit.affinities);
    if (!legalCasts(next, unit.id, undefined, spell.id).some((cell) => same(cell, order.cast!))) { emit(next, { kind: 'fizzle', unitId: unit.id, owner: unit.owner, spellId: spell.id, to: order.cast, text: `${name(unit)}'s ${spell.name} fizzles after a blocked landing. No Flux or cooldown spent.` }); continue; }
    casts.push({ caster: structuredClone(unit), spell, target: order.cast, area: spellArea(next, unit.id, spell.id, order.cast) });
  }
  const snapshot = structuredClone(next);
  for (const unit of next.units) {
    for (const [id, turns] of Object.entries(unit.cooldowns)) if (turns > 1) unit.cooldowns[id] = turns - 1; else delete unit.cooldowns[id];
    unit.statuses = Object.fromEntries(Object.entries(unit.statuses).filter(([, value]) => value!.turns > 1).map(([id, value]) => [id, { ...value!, turns: value!.turns - 1 }]));
  }
  for (const cast of casts) {
    const unit = next.units.find((entry) => entry.id === cast.caster.id)!;
    unit.flux -= castAvailability(snapshot, unit.id, cast.spell.id).cost;
    if (cast.spell.cooldown) unit.cooldowns[cast.spell.id] = cast.spell.cooldown;
    emit(next, { kind: 'cast', unitId: unit.id, owner: unit.owner, spellId: cast.spell.id, from: point(cast.caster), to: cast.target, q: cast.target.q, r: cast.target.r, elements: [cast.spell.element], text: `${name(unit)} casts ${cast.spell.name}.` });
  }
  // Chemistry is a set union, never a cast sequence. A triple activates its constituent pairs once each.
  const formedArcstorm = new Set<string>();
  for (const cell of next.cells) {
    const arrivals = casts.filter((cast) => cast.area.some((area) => same(area, cell)));
    if (!arrivals.length) continue;
    const previouslyArcstorm = hasReaction(cell, 'arcstorm');
    const previouslyIce = isIce(cell), previouslyFlooded = isFlooded(cell);
    cell.elements = ELEMENT_ORDER.filter((element) => cellElements(cell).includes(element) || arrivals.some((cast) => cast.spell.element === element));
    cell.reactions = reactionsFor(cell.elements); cell.terrain = cell.reactions[0] ?? cell.elements[0]; cell.ttl = TERRAIN_DURATION;
    // Decide freezing from the complete union, not cast order. Fire wins a simultaneous thaw.
    if (cell.elements.includes('water') && !cell.elements.includes('fire') && (previouslyIce || arrivals.some((cast) => cast.spell.freeze) || cell.reactions.includes('hailcurrent') || cell.reactions.includes('black_ice'))) cell.ice = true;
    else delete cell.ice;
    if (isIce(cell) && !previouslyIce) emit(next, { kind: 'surface', q: cell.q, r: cell.r, terrain: 'ice', text: `Ice forms at ${formatTile(cell)}: entering slides to the end of its straight icy lane.` });
    else if (isFlooded(cell) && (!previouslyFlooded || previouslyIce)) emit(next, { kind: 'surface', q: cell.q, r: cell.r, terrain: 'water', text: `${previouslyIce ? 'Ice melts into floodwater' : 'Water floods the ground'} at ${formatTile(cell)}: entering or leaving costs 2 effort.` });
    if (!previouslyArcstorm && cell.reactions.includes('arcstorm')) formedArcstorm.add(key(cell));
    if (cell.reactions.length) emit(next, { kind: 'reaction', q: cell.q, r: cell.r, terrain: cell.terrain, elements: cell.elements, text: `${cell.reactions.map((id) => REACTIONS.find((entry) => entry.id === id)!.name).join(' + ')} at ${formatTile(cell)}; each reaction applies once.` });
    if (arrivals.some((cast) => cast.spell.dispel)) delete cell.barrier;
    else if (arrivals.some((cast) => cast.spell.wall) && !occupant(snapshot, cell) && !cell.well && cell.biome !== 'ruins') { cell.barrier = 2; emit(next, { kind: 'surface', q: cell.q, r: cell.r, terrain: 'earth', text: `A cairn blocks ${formatTile(cell)} through next resolution.` }); }
  }
  const damages = new Map<string, number>(); const spellDamages = new Map<string, number>(); const heals = new Map<string, number>(); const gains = new Map<string, number>();
  const incoming = new Map<string, StatusApplication[]>(); const cleansed = new Set<string>(); const wet = new Set<string>();
  const stealRequests: { source: string; victim: string; amount: number }[] = [];
  for (const unit of snapshot.units.filter(isAlive)) {
    const relevant = casts.filter((cast) => cast.area.some((cell) => same(cell, unit)));
    const friendly = relevant.filter((cast) => cast.caster.owner === unit.owner);
    const cleanse = friendly.some((cast) => cast.spell.cleanse);
    if (cleanse) cleansed.add(unit.id);
    const applications = relevant.flatMap((cast) => [
      ...(cast.caster.owner === unit.owner ? cast.spell.friendly ?? [] : []),
      ...(cast.spell.harm === 'all' || cast.caster.owner !== unit.owner ? cast.spell.harmful ?? [] : []),
    ]);
    const field = getCell(next, unit.q, unit.r)!;
    const reactions = REACTIONS.filter((reaction) => hasReaction(field, reaction.id));
    applications.push(...reactions.flatMap((reaction) => reaction.status ? [reaction.status] : []));
    if (pureElement(field, 'light')) applications.push({ id: 'clarity', turns: 1 });
    if (pureElement(field, 'dark')) applications.push({ id: 'wither', turns: 1 });
    for (const cast of casts.filter((entry) => entry.caster.id === unit.id)) applications.push(...(cast.spell.self ?? []));
    incoming.set(unit.id, applications);
    if (unit.statuses.wet || applications.some((application) => application.id === 'wet')) wet.add(unit.id);
    const ward = unit.statuses.ward?.power ?? 0;
    const harmful = relevant.filter((cast) => cast.spell.harm === 'all' || cast.caster.owner !== unit.owner);
    const hit = (cast: Cast) => cast.spell.damage + (cast.spell.bonus && (cast.spell.bonus === 'wounded' ? unit.hp < unit.maxHp : unit.statuses[cast.spell.bonus]) ? cast.spell.bonusDamage ?? 0 : 0);
    let ordinary = harmful.filter((cast) => !cast.spell.pierce).reduce((sum, cast) => sum + hit(cast), 0);
    let piercing = harmful.filter((cast) => cast.spell.pierce).reduce((sum, cast) => sum + hit(cast), 0);
    // Steam halves the aggregate once. Allocate it proportionally, then forest
    // absorbs one ordinary damage across the entire exchange, before Ward/Guard.
    const total = ordinary + piercing;
    const covered = hasReaction(getCell(next, unit.q, unit.r)!, 'steam') ? Math.ceil(total / 2) : total;
    piercing = total ? Math.floor(covered * piercing / total) : 0; ordinary = covered - piercing;
    const spellDamage = Math.max(0, Math.max(0, ordinary - terrainCover(field) - ward) + piercing - (unit.guard ? 1 : 0));
    spellDamages.set(unit.id, spellDamage);
    const burn = !cleanse && !wet.has(unit.id) ? unit.statuses.burn?.power ?? 0 : 0;
    const recoil = casts.filter((cast) => cast.caster.id === unit.id).reduce((sum, cast) => sum + (cast.spell.selfDamage ?? 0), 0);
    damages.set(unit.id, spellDamage + burn + recoil);
    if (total > 0) delete next.units.find((entry) => entry.id === unit.id)!.statuses.ward;
    heals.set(unit.id, friendly.reduce((sum, cast) => sum + cast.spell.heal, 0) + reactions.reduce((sum, reaction) => sum + (reaction.heal ?? 0), 0));
    gains.set(unit.id, friendly.reduce((sum, cast) => sum + (cast.spell.recharge ?? 0), 0));
    for (const cast of harmful) if (cast.caster.owner !== unit.owner) {
      if (cast.spell.steal) stealRequests.push({ source: cast.caster.id, victim: unit.id, amount: cast.spell.steal });
    }
  }
  // Accumulate all siphons only after target mitigation is known, then apply Wither once.
  for (const cast of casts.filter((entry) => entry.spell.drain)) {
    const victims = snapshot.units.filter((unit) => isAlive(unit) && unit.owner !== cast.caster.owner && cast.area.some((cell) => same(cell, unit)) && (spellDamages.get(unit.id) ?? 0) > 0);
    heals.set(cast.caster.id, (heals.get(cast.caster.id) ?? 0) + victims.length * cast.spell.drain!);
  }
  for (const unit of snapshot.units.filter(isAlive)) heals.set(unit.id, Math.max(0, (heals.get(unit.id) ?? 0) - (cleansed.has(unit.id) ? 0 : unit.statuses.wither?.power ?? 0)));
  // Equal competing theft requests share only the Flux available after all spell costs; remainder stays.
  for (const victim of next.units.filter(isAlive)) {
    const requests = stealRequests.filter((request) => request.victim === victim.id); if (!requests.length) continue;
    const total = requests.reduce((sum, request) => sum + request.amount, 0); const available = Math.min(victim.flux, total);
    for (const request of requests) { const transfer = Math.floor(available * request.amount / total); victim.flux -= transfer; gains.set(request.source, (gains.get(request.source) ?? 0) + transfer); }
  }
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const before = snapshot.units.find((entry) => entry.id === unit.id)!; const hurt = damages.get(unit.id) ?? 0; const heal = heals.get(unit.id) ?? 0;
    unit.hp = Math.max(0, Math.min(unit.maxHp, unit.hp + heal - hurt));
    if (hurt) emit(next, { kind: 'damage', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: hurt, text: `${name(unit)} takes ${hurt} damage in the exchange.` });
    if (heal) emit(next, { kind: 'heal', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: heal, text: `${name(unit)} receives ${heal} healing in the exchange.` });
    if (cleansed.has(unit.id)) for (const id of AILMENTS) delete unit.statuses[id];
    const applications = incoming.get(unit.id) ?? [];
    const freshClarity = applications.some((application) => application.id === 'clarity');
    for (const application of applications) {
      if (CONTROL.includes(application.id) && (before.statuses.resolve || before.statuses.clarity || freshClarity || cleansed.has(unit.id))) continue;
      if (AILMENTS.includes(application.id) && cleansed.has(unit.id) && !(application.id === 'burn' && casts.some((cast) => cast.caster.owner === unit.owner && cast.spell.id === 'cauterize' && cast.area.some((cell) => same(cell, unit))))) continue;
      if (application.id === 'burn' && wet.has(unit.id)) continue;
      mergeStatus(unit.statuses, application);
      if (CONTROL.includes(application.id)) mergeStatus(unit.statuses, { id: 'resolve', turns: 2, power: 1 });
    }
    if (wet.has(unit.id)) delete unit.statuses.burn;
    for (const id of Object.keys(unit.statuses) as StatusId[]) if ((incoming.get(unit.id) ?? []).some((application) => application.id === id)) emit(next, { kind: 'surface', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, status: id, text: `${name(unit)} gains ${STATUS_DEFINITIONS.find((definition) => definition.id === id)!.name} for ${unit.statuses[id]!.turns} planning round(s).` });
  }
  next.units.forEach((unit) => defeat(next, unit));
  // Vectors are summed from the common spell snapshot, then resolved one step at a time.
  const vectors = new Map<string, Point>();
  for (const unit of next.units.filter(isAlive)) {
    const old = snapshot.units.find((entry) => entry.id === unit.id)!;
    if (old.guard || old.statuses.anchored) continue;
    const vector = casts.filter((cast) => cast.spell.push && cast.area.some((cell) => same(cell, old))).reduce((sum, cast) => {
      const centre = cast.spell.shape === 'ring' || cast.spell.shape === 'burst' ? cast.target : cast.caster;
      const delta = { q: old.q - centre.q, r: old.r - centre.r }; const length = distance(old, centre) || 1;
      return { q: sum.q + delta.q / length * cast.spell.push!, r: sum.r + delta.r / length * cast.spell.push! };
    }, { q: 0, r: 0 });
    if (vector.q || vector.r) vectors.set(unit.id, vector);
  }
  for (let step = 0; step < 2; step++) {
    const requests = new Map<string, Point>();
    const cells = new Map(next.cells.map((cell) => [key(cell), cell]));
    for (const [id, vector] of vectors) {
      if (Math.max(Math.abs(vector.q), Math.abs(vector.r), Math.abs(vector.q + vector.r)) <= step) continue;
      const orientation = Math.sign(vector.q || vector.r);
      const ranked = DIRS.map((direction) => ({ direction, value: 2 * direction.q * vector.q + direction.q * vector.r + direction.r * vector.q + 2 * direction.r * vector.r })).sort((a, b) => b.value - a.value || orientation * (b.direction.q - a.direction.q || b.direction.r - a.direction.r));
      if (ranked[0].value <= 0) continue;
      const unit = next.units.find((entry) => entry.id === id)!; const direction = ranked[0].direction;
      const target = slideStep(unit, direction, cells).at(-1) ?? { q: unit.q + direction.q, r: unit.r + direction.r };
      if (getCell(next, target.q, target.r)) requests.set(id, point(target));
    }
    const before = new Map(next.units.map((unit) => [unit.id, point(unit)])); destinations(next, requests, 'push');
    for (const id of requests.keys()) if (same(next.units.find((unit) => unit.id === id)!, before.get(id)!)) vectors.delete(id);
  }
  for (const unit of next.units.filter(isAlive)) {
    const cell = getCell(next, unit.q, unit.r)!;
    if (pureElement(cell, 'fire') || hasReaction(cell, 'magma') || formedArcstorm.has(key(cell))) {
      const hazards = [pureElement(cell, 'fire') ? 'Embers' : '', hasReaction(cell, 'magma') ? 'Magma' : '', formedArcstorm.has(key(cell)) ? 'Arcstorm' : ''].filter(Boolean).join(' + ');
      unit.hp = Math.max(0, unit.hp - 1); emit(next, { kind: 'surface', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: 1, terrain: hasReaction(cell, 'magma') ? 'magma' : formedArcstorm.has(key(cell)) ? 'arcstorm' : 'fire', text: `${hazards} hurts ${name(unit)} for 1 total (environmental cap).` });
    }
  }
  next.units.forEach((unit) => defeat(next, unit));
  for (const owner of [0, 1] as const) {
    const amount = next.cells.filter((cell) => cell.well && occupant(next, cell)?.owner === owner).reduce((sum, cell) => sum + (hasReaction(cell, 'penumbra') ? 2 : 1), 0);
    next.scores[owner] += amount; emit(next, { kind: 'score', owner, amount, text: `Player ${owner + 1} scores ${amount} from wells.` });
  }
  for (const cell of next.cells) {
    if (cell.ttl !== undefined && --cell.ttl <= 0) { cell.terrain = baseTerrainAt(cell.q, cell.r, next.mapId); delete cell.ttl; delete cell.elements; delete cell.reactions; delete cell.ice; }
    if (cell.barrier !== undefined && --cell.barrier <= 0) delete cell.barrier;
  }
  for (const unit of next.units.filter(isAlive)) unit.flux = Math.min(unit.maxFlux, unit.flux + 2 + (unit.guard ? 1 : 0) + (gains.get(unit.id) ?? 0));
  const [left, right] = next.scores;
  if ((Math.max(left, right) >= POINTS_TO_WIN && left !== right) || next.round >= MAX_ROUNDS) { next.winner = left === right ? 'draw' : left > right ? 0 : 1; next.log.push(next.winner === 'draw' ? 'The match ends in a draw.' : `Player ${next.winner + 1} wins.`); }
  else { next.round++; returns(next); }
  next.log = next.log.slice(-150); return next;
}

export function previewPlan(state: SimState, player: Player, input: TeamPlan): string[] {
  const plan = validatePlan(state, player, input);state=prepareTeam(state,player,plan); const lines: string[] = [];
  for (const order of plan.orders) {
    const unit = state.units.find((entry) => entry.id === order.unitId)!; const landing = order.move ?? unit;
    lines.push(`${name(unit)}: ${order.move ? `move ${formatTile(order.move)} (${movementEffort(state, unit.id, order.move)} effort)` : 'hold'}; ${order.cast ? `${getSpell(order.spellId!).name} at ${formatTile(order.cast)} (${castAvailability(state, unit.id, order.spellId!).cost} Flux)` : 'Guard and recover +1 Flux'}.`);
    if (order.cast) {
      const spell = effectiveSpell(unit.championId,order.spellId!,unit.affinities); const area = spellArea(state, unit.id, spell.id, order.cast, landing);
      if (spell.damage && spell.harm === 'all' && plan.orders.some((ally) => area.some((cell) => same(cell, ally.move ?? state.units.find((entry) => entry.id === ally.unitId)!)))) lines.push(`${spell.name}: friendly fire risk inside its ${area.length}-hex footprint.`);
      if (order.move && !legalCasts(state, unit.id, undefined, spell.id).some((cell) => same(cell, order.cast!))) lines.push(`${spell.name} depends on the landing: a collision can make it fizzle without spending Flux.`);
    }
  }
  for (const cell of state.cells) {
    const incoming = plan.orders.filter((order) => order.cast && spellArea(state, order.unitId, order.spellId!, order.cast, order.move).some((area) => same(area, cell))).map((order) => getSpell(order.spellId!).element);
    if (!incoming.length) continue; const reactions = reactionsFor([...cellElements(cell), ...incoming]);
    if (reactions.length) lines.push(`${formatTile(cell)}: ${reactions.map((id) => REACTIONS.find((reaction) => reaction.id === id)!.name).join(' + ')}. Each pair applies once; enemy spells can add chemistry.`);
  }
  lines.push('Aim is fixed to ground. New statuses affect next planning; incoming enemy plans remain hidden.');
  return lines;
}

/** Equip unlocked spells deterministically using the fixed pre-match affinities. */
function aiPreparation(state:SimState,player:Player):TeamPlan {
  const loadouts:NonNullable<TeamPlan['loadouts']>=[];
  const projected=prepareTeam(state,player,{orders:[]});
  for(const unit of sortedUnits(projected.units.filter(unit=>unit.owner===player))){
    const upgrades=ALL_SPELLS.filter(spell=>spell.level>1&&spell.signatureChampionId!==unit.championId&&!unit.loadout.includes(spell.id)&&!unit.cooldowns[spell.id]&&spellAccess(unit.championId,spell.id,unit.affinities,state.learnedSignatures[player]).unlocked).sort((a,b)=>b.level-a.level||(unit.affinities[b.element]??0)-(unit.affinities[a.element]??0)||a.id.localeCompare(b.id));
    for(const spell of upgrades){
      // Replace an older branch move first; retain basic attacks and other elements.
      const slot=unit.loadout.map((id,index)=>({spell:getSpell(id),index})).filter(entry=>entry.spell.element===spell.element&&entry.spell.level<spell.level).sort((a,b)=>b.spell.level-a.spell.level||a.index-b.index)[0]?.index;
      if(slot===undefined)continue;
      const spells=[...unit.loadout];spells[slot]=spell.id;loadouts.push({unitId:unit.id,spells});break;
    }
  }
  return {orders:[],...(loadouts.length?{loadouts}:{})};
}

/** Bounded public-state bot. It never receives the opponent's sealed plan. */
export function chooseAIPlan(state: SimState, player: Player): TeamPlan {
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null) return { orders: [] };
  const original=state,prepared=aiPreparation(state,player);state=prepareTeam(state,player,prepared);
  const own = state.units.filter((unit) => unit.owner === player && isAlive(unit)); const enemies = state.units.filter((unit) => unit.owner !== player && isAlive(unit));
  // Reachability is public information, not a prediction of the sealed enemy plan.
  const contested = new Set(enemies.flatMap((enemy) => legalMoves(state, enemy.id).map(key)));
  const sign = player === 0 ? 1 : -1; const reserved = new Set<string>(); const orders: Order[] = [];
  // Assign distinct objectives as a squad, rather than sending every mage toward the closest centre well.
  const wells = state.cells.filter((cell) => cell.well).sort((a, b) => sign * (a.q - b.q || a.r - b.r));
  let objectives: SimCell[] = []; let assignmentCost = Infinity;
  const assign = (chosen: SimCell[], remaining: SimCell[]) => {
    if (chosen.length === own.length) {
      const cost = chosen.reduce((sum, well, index) => sum + distance(own[index], well), 0);
      if (cost < assignmentCost) { assignmentCost = cost; objectives = chosen; }
      return;
    }
    for (const well of remaining) assign([...chosen, well], remaining.filter((entry) => entry !== well));
  };
  assign([], wells);
  // A revealed failed move is evidence, not a prediction of sealed orders. Approach from a different hex
  // for one round rather than repeating a collision that leaves both casters outside their useful reach.
  const firstCast = state.lastResolution.findIndex((event) => event.kind === 'cast');
  const movementEvents = state.lastResolution.slice(0, firstCast < 0 ? state.lastResolution.length : firstCast);
  for (const unit of own) {
    const bouncedWell = movementEvents.find((event) => event.kind === 'bounce' && event.unitId === unit.id && event.to && getCell(state, event.to.q, event.to.r)?.well && !occupant(state, event.to))?.to;
    const candidates = [getCell(state, unit.q, unit.r)!, ...legalMoves(state, unit.id)].sort((a, b) => sign * (a.q - b.q || a.r - b.r)); let landing = candidates[0]; let best = -Infinity;
    for (const cell of candidates) {
      if (reserved.has(key(cell)) || enemies.some((enemy) => same(enemy, cell))) continue;
      const objective = objectives[own.indexOf(unit)]; const nearest = objective ? distance(cell, objective) : 0;
      const score = (objective && same(cell, objective) ? 14 : 0) - 3 * nearest + cell.height * 0.5 - (hasReaction(cell, 'magma') || pureElement(cell, 'fire') ? unit.hp <= 1 ? 100 : 4 : 0)
        - (!same(unit, cell) && contested.has(key(cell)) ? 1.5 : 0) - (bouncedWell && same(cell, bouncedWell) ? 20 : 0);
      if (score > best) { best = score; landing = cell; }
    }
    reserved.add(key(landing)); orders.push({ unitId: unit.id, ...(same(unit, landing) ? {} : { move: point(landing) }), guard: true });
  }
  const projected = structuredClone(state); destinations(projected, new Map(orders.filter((order) => order.move).map((order) => [order.unitId, order.move!])), 'move');
  for (const order of orders) if (order.move && !same(projected.units.find((unit) => unit.id === order.unitId)!, order.move)) delete order.move;
  const landings = own.map((unit) => ({ ...unit, ...(orders.find((order) => order.unitId === unit.id)!.move ?? point(unit)) }));
  const possibleAllies = [...landings, ...own.filter((unit) => { const landing = landings.find((entry) => entry.id === unit.id)!; return !same(unit, landing) && contested.has(key(landing)); })];
  for (const order of orders) {
    const unit = own.find((entry) => entry.id === order.unitId)!; let best = 0; let choice: { spell: Spell; target: Point } | undefined;
    for (const spellId of availableSpellIds(unit.championId, unit.loadout,unit.affinities,state.learnedSignatures[player])) {
      const availability = castAvailability(state, unit.id, spellId); if (!availability.available) continue;
      const spell = effectiveSpell(unit.championId,spellId,unit.affinities);
      const fallback = order.move && contested.has(key(order.move)) ? new Set(legalCasts(state, unit.id, undefined, spellId).map(key)) : null;
      for (const target of legalCasts(state, unit.id, order.move, spellId).sort((a, b) => sign * (a.q - b.q || a.r - b.r))) {
        if (fallback && !fallback.has(key(target))) continue;
        const area = spellArea(state, unit.id, spellId, target, order.move); let score = -availability.cost * 0.35 - (spell.selfDamage ?? 0) * 2;
        if (spell.damage && spell.harm === 'all' && possibleAllies.some((ally) => area.some((cell) => same(cell, ally)))) continue;
        if (fallback && spell.damage && spell.harm === 'all' && possibleAllies.some((ally) => spellArea(state, unit.id, spellId, target).some((cell) => same(cell, ally)))) continue;
        for (const enemy of enemies.filter((entry) => area.some((cell) => same(cell, entry)))) {
          // Follow up an already-visible mark. A mark another mage plans this round
          // is not in this snapshot and cannot enable a simultaneous bonus.
          const damage = spell.damage + (spell.bonus && (spell.bonus === 'wounded' ? enemy.hp < enemy.maxHp : enemy.statuses[spell.bonus]) ? spell.bonusDamage ?? 0 : 0);
          score += damage * 3 + (damage >= enemy.hp ? 5 : 0) + (spell.harmful?.length ?? 0) + (spell.push && getCell(state, enemy.q, enemy.r)?.well ? 3 : 0) + (spell.steal ?? 0);
        }
        for (const ally of landings.filter((entry) => area.some((cell) => same(cell, entry)))) {
          score += Math.min(spell.heal, ally.maxHp - ally.hp) * 3;
          if (spell.cleanse) score += AILMENTS.filter((id) => ally.statuses[id]).length * 2;
          if (enemies.some((enemy) => distance(enemy, ally) <= 3)) score += spell.friendly?.reduce((sum, effect) => sum + (effect.id === 'ward' ? effect.power ?? 1 : 0.5), 0) ?? 0;
        }
        if (score > best) { best = score; choice = { spell, target }; }
      }
    }
    if (choice) { delete order.guard; order.spellId = choice.spell.id; order.cast = point(choice.target); }
  }
  return validatePlan(original, player, { ...prepared,orders });
}

export function restoreSimState(input: unknown): SimState {
  const value = object(input, ['rulesVersion', 'version', 'mapId', 'round', 'scores', 'learnedSignatures', 'units', 'cells', 'log', 'winner', 'lastResolution'], 'Saved match');
  if(!Array.isArray(value.learnedSignatures)||value.learnedSignatures.length!==2)throw new Error('Saved match requires both learned signature libraries.');
  const learnedSignatures=value.learnedSignatures.map(validateLearnedSignatures) as [string[],string[]];
  if (value.rulesVersion !== RULES_VERSION || typeof value.mapId !== 'string' || value.mapId !== normalizeArenaMapId(value.mapId) || !Number.isSafeInteger(value.round) || (value.round as number) < 1 || (value.round as number) > MAX_ROUNDS || ![null, 0, 1, 'draw'].includes(value.winner as never)) throw new Error('Unsupported tactics save.');
  if (value.version !== (value.round as number) + Number(value.winner !== null)) throw new Error('Saved version and round disagree.');
  if (!Array.isArray(value.scores) || value.scores.length !== 2 || value.scores.some((score) => !Number.isSafeInteger(score) || score < 0 || score > 1000)) throw new Error('Invalid scores.');
  const [left, right] = value.scores as [number, number];
  if (value.winner === null ? Math.max(left, right) >= POINTS_TO_WIN && left !== right : value.winner !== (left === right ? 'draw' : left > right ? 0 : 1) || (value.round !== MAX_ROUNDS && (left === right || Math.max(left, right) < POINTS_TO_WIN))) throw new Error('Saved victory is inconsistent.');
  if (!Array.isArray(value.cells) || value.cells.length !== BOARD_SIZE || !Array.isArray(value.units) || value.units.length !== 6) throw new Error('Invalid battlefield size.');
  const cells = value.cells.map((raw): SimCell => {
    const cell = object(raw, ['q', 'r', 'well', 'terrain', 'biome', 'height', 'ttl', 'elements', 'reactions', 'barrier', 'ice'], 'Saved hex'); const at = readPoint({ q: cell.q, r: cell.r });
    if (distance(at, { q: 0, r: 0 }) > BOARD_RADIUS || cell.biome !== arenaBiomeAt(at.q, at.r, value.mapId as string) || cell.height !== heightAt(at.q, at.r, value.mapId as string) || cell.well !== wellAt(at.q, at.r, value.mapId as string)) throw new Error('Saved geometry changed.');
    if (cell.barrier !== undefined && (!Number.isInteger(cell.barrier) || (cell.barrier as number) < 1 || (cell.barrier as number) > 2 || cell.well || cell.biome === 'ruins')) throw new Error('Invalid barrier.');
    if (cell.ttl === undefined) { if (cell.terrain !== baseTerrainAt(at.q, at.r, value.mapId as string) || cell.elements !== undefined || cell.reactions !== undefined || cell.ice !== undefined) throw new Error('Base terrain changed.'); }
    else {
      if (!Number.isInteger(cell.ttl) || (cell.ttl as number) < 1 || (cell.ttl as number) > 2 || !Array.isArray(cell.elements) || !cell.elements.length || new Set(cell.elements).size !== cell.elements.length || cell.elements.some((element) => !ELEMENT_ORDER.includes(element)) || !Array.isArray(cell.reactions)) throw new Error('Invalid chemistry.');
      if (JSON.stringify(cell.elements) !== JSON.stringify(ELEMENT_ORDER.filter((element) => (cell.elements as Element[]).includes(element))) || JSON.stringify(cell.reactions) !== JSON.stringify(reactionsFor(cell.elements as Element[])) || cell.terrain !== (cell.reactions[0] ?? cell.elements[0])) throw new Error('Inconsistent chemistry.');
      const base = baseTerrainAt(at.q, at.r, value.mapId as string);
      if (base !== 'plain' && !(cell.elements as Element[]).includes(base)) throw new Error('Field is missing its natural substrate.');
      const elements = cell.elements as Element[], reactions = cell.reactions as ReactionId[];
      if (cell.ice !== undefined && (cell.ice !== true || !elements.includes('water') || elements.includes('fire'))) throw new Error('Invalid ice.');
      if (!elements.includes('fire') && (reactions.includes('hailcurrent') || reactions.includes('black_ice')) && cell.ice !== true) throw new Error('Frozen reaction is missing its ice.');
    }
    return { ...cell } as SimCell;
  });
  if (new Set(cells.map(key)).size !== BOARD_SIZE) throw new Error('Duplicate board hex.');
  const units = value.units.map((raw): SimUnit => {
    const unit = object(raw, ['id', 'championId', 'owner', 'q', 'r', 'hp', 'maxHp', 'guard', 'respawn', 'loadout', 'affinities', 'flux', 'maxFlux', 'cooldowns', 'statuses'], 'Saved champion');
    if ((unit.owner !== 0 && unit.owner !== 1) || typeof unit.championId !== 'string' || !CHAMPIONS.some((entry) => entry.id === unit.championId) || unit.id !== `${unit.owner}-${unit.championId}`) throw new Error('Invalid champion identity.');
    const at = readPoint({ q: unit.q, r: unit.r });
    if (!cells.some((cell) => same(cell, at)) || unit.maxHp !== MAX_HP || !Number.isInteger(unit.hp) || (unit.hp as number) < 0 || (unit.hp as number) > MAX_HP || unit.maxFlux !== MAX_FLUX || !Number.isInteger(unit.flux) || (unit.flux as number) < 0 || (unit.flux as number) > MAX_FLUX || (unit.guard !== undefined && typeof unit.guard !== 'boolean')) throw new Error('Invalid champion condition.');
    if (unit.respawn !== undefined && (!Number.isInteger(unit.respawn) || (unit.respawn as number) <= (value.round as number) || (unit.respawn as number) > (value.round as number) + 2)) throw new Error('Invalid return round.');
    if ((unit.hp === 0) !== (unit.respawn !== undefined)) throw new Error('Defeat state disagrees.');
    const affinities=validateChampionAffinities(unit.championId,unit.affinities);
    const loadout = validateLoadout(unit.championId, unit.loadout,affinities,learnedSignatures[unit.owner]);
    const ownedSpells=ALL_SPELLS.filter(spell=>spellAccess(unit.championId as string,spell.id,affinities,learnedSignatures[unit.owner as Player]).unlocked).map(spell=>spell.id);
    const cooldowns = object(unit.cooldowns, ownedSpells, 'Cooldowns');
    for (const [id, remaining] of Object.entries(cooldowns)) if (!Number.isInteger(remaining) || (remaining as number) < 1 || (remaining as number) > getSpell(id).cooldown) throw new Error('Invalid spell cooldown.');
    const statuses = object(unit.statuses, STATUS_DEFINITIONS.map((status) => status.id), 'Statuses');
    for (const [id,rawStatus] of Object.entries(statuses)) { const status = object(rawStatus, ['turns', 'power'], 'Status'); const maxTurns=CONTROL.includes(id as StatusId)?1:['resolve','burn','ward'].includes(id)?2:3,maxPower=id==='ward'?5:1; if (!Number.isInteger(status.turns) || (status.turns as number) < 1 || (status.turns as number) > maxTurns || !Number.isInteger(status.power) || (status.power as number) < 1 || (status.power as number) > maxPower) throw new Error('Invalid status duration or power.'); }
    return { ...unit, affinities,loadout } as SimUnit;
  });
  const living = units.filter(isAlive);
  if (new Set(units.map((unit) => unit.id)).size !== 6 || [0, 1].some((owner) => units.filter((unit) => unit.owner === owner).length !== 3) || new Set(living.map(key)).size !== living.length || living.some((unit) => isCellSolid(cells.find((cell) => same(cell, unit))!))) throw new Error('Invalid squads or overlapping occupants.');
  if (!Array.isArray(value.log) || value.log.length > 150 || value.log.some((line) => typeof line !== 'string' || line.length > 1000) || !Array.isArray(value.lastResolution) || value.lastResolution.length > 300) throw new Error('Invalid event history.');
  for (const raw of value.lastResolution) {
    const entry = object(raw, ['kind', 'text', 'unitId', 'owner', 'from', 'to', 'q', 'r', 'amount', 'elements', 'terrain', 'spellId', 'status'], 'Event');
    if (!['move', 'bounce', 'cast', 'reaction', 'damage', 'heal', 'push', 'defeat', 'respawn', 'score', 'guard', 'fizzle', 'surface'].includes(entry.kind as string) || typeof entry.text !== 'string' || entry.text.length > 1000) throw new Error('Invalid event.');
    if (entry.owner !== undefined && entry.owner !== 0 && entry.owner !== 1) throw new Error('Invalid event owner.');
    if (entry.unitId !== undefined && !units.some((unit) => unit.id === entry.unitId)) throw new Error('Invalid event champion.');
    for (const field of ['from', 'to']) if (entry[field] !== undefined && !cells.some((cell) => same(cell, readPoint(entry[field])))) throw new Error('Invalid event hex.');
    if ((entry.q !== undefined || entry.r !== undefined) && !cells.some((cell) => same(cell, readPoint({ q: entry.q, r: entry.r })))) throw new Error('Invalid event coordinate.');
    if (entry.amount !== undefined && (!Number.isInteger(entry.amount) || (entry.amount as number) < 0 || (entry.amount as number) > 100)) throw new Error('Invalid event amount.');
    if (entry.spellId !== undefined && (typeof entry.spellId !== 'string' || !ALL_SPELLS.some((spell) => spell.id === entry.spellId))) throw new Error('Invalid event spell.');
    if (entry.status !== undefined && !STATUS_DEFINITIONS.some((status) => status.id === entry.status)) throw new Error('Invalid event status.');
    if (entry.elements !== undefined && (!Array.isArray(entry.elements) || entry.elements.some((element) => !ELEMENT_ORDER.includes(element)))) throw new Error('Invalid event elements.');
    if (entry.terrain !== undefined && !['plain', 'ice', ...ELEMENT_ORDER, ...REACTIONS.map((reaction) => reaction.id)].includes(entry.terrain as string)) throw new Error('Invalid event terrain.');
  }
  return structuredClone({ ...value, learnedSignatures, cells, units }) as SimState;
}
