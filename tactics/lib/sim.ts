/** H.E.X. Confluence v3: sealed, simultaneous team orders; no player has resolution priority. */
import { CHAMPIONS as BASE_CHAMPIONS, ELEMENTS as BASE_ELEMENTS, distance } from './game.ts';
import type { Champion, Element, Player, Point } from './game.ts';
export { distance };
export type { Element, Player, Point };

export const RULES_VERSION = 3;
export const BOARD_RADIUS = 3;
export const MOVE_RANGE = 2;
export const CAST_RANGE = 2;
export const POINTS_TO_WIN = 8;
export const MAX_ROUNDS = 16;
export const TERRAIN_DURATION = 2;
export const GUARD_ABSORPTION = 1;
export const MAPS = [{ id: 'confluence', name: 'The Confluence', description: 'Three wells, four mirrored ridges, one shared battlefield.' }];
export type ReactionId = 'steam' | 'magma' | 'quagmire' | 'penumbra';
export type SimCell = Point & { well: boolean; terrain: string; ttl?: number; height: 0 | 1; elements?: Element[]; reactions?: ReactionId[] };
export type Cell = SimCell;
export type SimUnit = Point & { id: string; championId: string; owner: Player; hp: number; maxHp: number; guard?: boolean; respawn?: number };
export type Order = { unitId: string; move?: Point; cast?: Point; guard?: boolean };
export type TeamPlan = { orders: Order[] };
export type SimEvent = {
  kind: 'move' | 'bounce' | 'cast' | 'reaction' | 'damage' | 'heal' | 'push' | 'defeat' | 'respawn' | 'score' | 'guard' | 'fizzle' | 'surface';
  text: string; unitId?: string; owner?: Player; from?: Point; to?: Point; q?: number; r?: number; amount?: number; elements?: Element[]; terrain?: string;
};
export type SimState = {
  rulesVersion: 3; version: number; mapId: string; round: number; scores: [number, number]; units: SimUnit[]; cells: SimCell[];
  log: string[]; winner: Player | 'draw' | null; lastResolution: SimEvent[];
};
export const REACTIONS: { id: ReactionId; name: string; elements: [Element, Element]; color: string; symbol: string; description: string }[] = [
  { id: 'steam', name: 'Steam', elements: ['fire', 'water'], color: '#aad7df', symbol: '≋', description: 'Halves combined spell damage on this hex, rounded up. Guard then absorbs 1.' },
  { id: 'magma', name: 'Magma', elements: ['fire', 'earth'], color: '#f69262', symbol: '♨', description: 'Deals 1 environmental damage to its occupant after spells and pushes each round.' },
  { id: 'quagmire', name: 'Quagmire', elements: ['earth', 'water'], color: '#90b68c', symbol: '≋', description: 'Each movement step into or out of this hex costs 2 instead of 1.' },
  { id: 'penumbra', name: 'Penumbra', elements: ['light', 'dark'], color: '#c5a7eb', symbol: '◐', description: 'An occupied well scores 2 points instead of 1 after resolution.' },
];
const DESCRIPTIONS: Record<Element, string> = {
  fire: 'Hit 2, including friends. Fire + Water makes Steam; Fire + Earth makes Magma.',
  water: 'Hit 2, including friends. Water + Fire makes Steam; Water + Earth makes Quagmire.',
  earth: 'Hit 2, including friends. Earth + Fire makes Magma; Earth + Water makes Quagmire.',
  air: 'Hit 1, including friends. Push adjacent occupants one hex unless they Guard; competing winds can cancel.',
  light: 'Heal a friendly occupant by 2, or hit an enemy for 2. Light + Dark makes Penumbra.',
  dark: 'Hit 2, including friends. Siphon 1 from an enemy on pre-existing Dark if spell damage gets through. Dark + Light makes Penumbra.',
};
export const CHAMPIONS: Champion[] = BASE_CHAMPIONS.map((champion) => ({ ...champion, description: DESCRIPTIONS[champion.element] }));
export const ELEMENTS = BASE_ELEMENTS.map((element) => ({ ...element, description: DESCRIPTIONS[element.id] }));
const ELEMENT_ORDER: Element[] = ['fire', 'water', 'earth', 'air', 'light', 'dark'];
const DIRECTIONS: Point[] = [{ q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 }, { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 }];
const DEFAULT_ROSTER = ['oh_tipi', 'wa_bidi', 'treevor_mason'];
const STARTS: [Point[], Point[]] = [[{ q: -3, r: 0 }, { q: -3, r: 1 }, { q: -3, r: 2 }], [{ q: 3, r: 0 }, { q: 3, r: -1 }, { q: 3, r: -2 }]];
const key = (point: Point) => `${point.q},${point.r}`;
const same = (a: Point, b: Point) => a.q === b.q && a.r === b.r;
const other = (player: Player): Player => player === 0 ? 1 : 0;
const point = (value: Point): Point => ({ q: value.q, r: value.r });
const sortedUnits = (units: SimUnit[]) => [...units].sort((a, b) => a.id.localeCompare(b.id));
export const isAlive = (unit: SimUnit) => unit.hp > 0 && unit.respawn === undefined;
export const getCell = (state: SimState, q: number, r: number) => state.cells.find((cell) => cell.q === q && cell.r === r);
export const getChampion = (id: string): Champion => {
  const found = CHAMPIONS.find((champion) => champion.id === id);
  if (!found) throw new Error('Unknown champion.');
  return found;
};
const occupant = (state: SimState, cell: Point) => state.units.find((unit) => isAlive(unit) && same(unit, cell));
const heightAt = (q: number, r: number): 0 | 1 => (q === -1 && (r === 0 || r === 1)) || (q === 1 && (r === 0 || r === -1)) ? 1 : 0;
const event = (state: SimState, entry: SimEvent) => { state.lastResolution.push(entry); state.log.push(entry.text); };

function elementsOn(cell: SimCell): Element[] {
  if (cell.elements) return [...cell.elements];
  const reaction = REACTIONS.find((entry) => entry.id === cell.terrain);
  return reaction ? [...reaction.elements] : ELEMENT_ORDER.includes(cell.terrain as Element) ? [cell.terrain as Element] : [];
}
export function reactionsFor(elements: readonly Element[]): ReactionId[] {
  return REACTIONS.filter((reaction) => reaction.elements.every((element) => elements.includes(element))).map((reaction) => reaction.id);
}
const hasReaction = (cell: SimCell, reaction: ReactionId) => (cell.reactions ?? reactionsFor(elementsOn(cell))).includes(reaction);
function mergeSurface(cell: SimCell, incoming: Element[]): void {
  cell.elements = ELEMENT_ORDER.filter((element) => incoming.includes(element) || elementsOn(cell).includes(element));
  cell.reactions = reactionsFor(cell.elements);
  cell.terrain = cell.reactions[0] ?? cell.elements[0] ?? 'plain';
  cell.ttl = TERRAIN_DURATION;
}

export function createSimGame(rosters: [string[], string[]] = [[...DEFAULT_ROSTER], [...DEFAULT_ROSTER]], mapId = 'confluence'): SimState {
  if (mapId !== 'confluence') throw new Error('Unknown battlefield.');
  if (!Array.isArray(rosters) || rosters.length !== 2 || rosters.some((roster) => !Array.isArray(roster) || roster.length !== 3 || new Set(roster).size !== 3 || roster.some((id) => !CHAMPIONS.some((champion) => champion.id === id)))) throw new Error('Choose exactly 3 different champions per squad.');
  const cells: SimCell[] = [];
  for (let q = -BOARD_RADIUS; q <= BOARD_RADIUS; q++) for (let r = -BOARD_RADIUS; r <= BOARD_RADIUS; r++) {
    if (distance({ q, r }, { q: 0, r: 0 }) <= BOARD_RADIUS) cells.push({ q, r, well: q === 0 && [-2, 0, 2].includes(r), terrain: 'plain', height: heightAt(q, r) });
  }
  const units = rosters.flatMap((roster, owner) => roster.map((championId, index): SimUnit => ({
    id: `${owner}-${championId}`, championId, owner: owner as Player, ...STARTS[owner as Player][index], hp: 5, maxHp: 5,
  })));
  return { rulesVersion: 3, version: 1, mapId, round: 1, scores: [0, 0], units, cells, log: ['Plan every champion: move, aim or Guard, then lock. Both teams resolve together.'], winner: null, lastResolution: [] };
}

export function movementCost(from: SimCell, to: SimCell): number {
  return hasReaction(from, 'quagmire') || hasReaction(to, 'quagmire') || to.height > from.height ? 2 : 1;
}
/** Paths may cross occupied hexes; simultaneous resolution governs destination occupancy. */
export function movementPath(state: SimState, unitId: string, target: Point): SimCell[] | null {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit) || same(unit, target)) return null;
  const start = getCell(state, unit.q, unit.r)!;
  const queue: { cell: SimCell; cost: number; path: SimCell[] }[] = [{ cell: start, cost: 0, path: [] }];
  const costs = new Map([[key(start), 0]]);
  while (queue.length) {
    queue.sort((a, b) => a.cost - b.cost || a.cell.q - b.cell.q || a.cell.r - b.cell.r);
    const current = queue.shift()!;
    if (same(current.cell, target)) return current.path;
    for (const direction of DIRECTIONS) {
      const cell = getCell(state, current.cell.q + direction.q, current.cell.r + direction.r);
      if (!cell) continue;
      const cost = current.cost + movementCost(current.cell, cell);
      if (cost > MOVE_RANGE || cost >= (costs.get(key(cell)) ?? Infinity)) continue;
      costs.set(key(cell), cost); queue.push({ cell, cost, path: [...current.path, cell] });
    }
  }
  return null;
}
export function legalMoves(state: SimState, unitId: string): SimCell[] {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (state.rulesVersion !== 3 || state.winner !== null || !unit || !isAlive(unit)) return [];
  return state.cells.filter((cell) => distance(unit, cell) <= MOVE_RANGE && movementPath(state, unitId, cell));
}
/** Raised ground blocks low-to-low shots; one clear shortest ray is sufficient at hex-edge ties. */
function clearSight(state: SimState, from: SimCell, target: SimCell): boolean {
  const limit = Math.max(from.height, target.height);
  const range = distance(from, target);
  if (range <= 1) return true;
  const queue = [from]; const visited = new Set([key(from)]);
  for (let index = 0; index < queue.length; index++) {
    const current = queue[index];
    for (const direction of DIRECTIONS) {
      const next = getCell(state, current.q + direction.q, current.r + direction.r);
      if (!next || visited.has(key(next)) || distance(from, next) + distance(next, target) !== range || distance(from, next) <= distance(from, current)) continue;
      if (same(next, target)) return true;
      if (next.height > limit) continue;
      visited.add(key(next)); queue.push(next);
    }
  }
  return false;
}
export function legalCasts(state: SimState, unitId: string, from?: Point): SimCell[] {
  const unit = state.units.find((entry) => entry.id === unitId);
  const origin = unit && getCell(state, from?.q ?? unit.q, from?.r ?? unit.r);
  if (state.rulesVersion !== 3 || state.winner !== null || !unit || !isAlive(unit) || !origin) return [];
  return state.cells.filter((cell) => distance(origin, cell) <= CAST_RANGE + (origin.height > cell.height ? 1 : 0) && clearSight(state, origin, cell));
}

function object(input: unknown, allowed: string[], label: string): Record<string, unknown> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error(`${label} must be an object.`);
  const value = input as Record<string, unknown>;
  if (Object.keys(value).some((name) => !allowed.includes(name))) throw new Error(`${label} contains an unknown field.`);
  return value;
}
function readPoint(input: unknown): Point {
  const value = object(input, ['q', 'r'], 'Hex');
  if (!Number.isSafeInteger(value.q) || !Number.isSafeInteger(value.r)) throw new Error('Hex coordinates must be whole numbers.');
  return { q: value.q as number, r: value.r as number };
}
export function validatePlan(state: SimState, player: Player, input: unknown): TeamPlan {
  if (state.rulesVersion !== 3 || state.winner !== null) throw new Error('This simultaneous match is not active.');
  if (player !== 0 && player !== 1) throw new Error('Unknown player.');
  const value = object(input, ['orders'], 'Plan');
  if (!Array.isArray(value.orders) || value.orders.length > 3) throw new Error('A plan must contain at most 3 champion orders.');
  const orders = new Map<string, Order>();
  for (const raw of value.orders) {
    const entry = object(raw, ['unitId', 'move', 'cast', 'guard'], 'Order');
    if (typeof entry.unitId !== 'string' || orders.has(entry.unitId)) throw new Error('Each champion may have only one order.');
    const unit = state.units.find((candidate) => candidate.id === entry.unitId);
    if (!unit || unit.owner !== player || !isAlive(unit)) throw new Error('Order only your living champions.');
    const order: Order = { unitId: unit.id };
    if (entry.move !== undefined) {
      order.move = readPoint(entry.move);
      if (!legalMoves(state, unit.id).some((cell) => same(cell, order.move!))) throw new Error('Movement exceeds 2 effort; climbing or Quagmire costs 2 per step.');
    }
    if (entry.guard !== undefined && entry.guard !== true) throw new Error('Guard must be true when included.');
    if (entry.cast !== undefined && entry.guard === true) throw new Error('Choose either a spell or Guard for each champion.');
    if (entry.cast !== undefined) {
      order.cast = readPoint(entry.cast);
      if (!legalCasts(state, unit.id, order.move).some((cell) => same(cell, order.cast!))) throw new Error('Aim within range and clear sight from the planned landing hex.');
    } else order.guard = true;
    orders.set(unit.id, order);
  }
  return { orders: sortedUnits(state.units.filter((unit) => unit.owner === player && isAlive(unit))).map((unit) => orders.get(unit.id) ?? { unitId: unit.id, guard: true }) };
}

/** Resolve destination occupancy as a graph. All collisions bounce; closed swaps/cycles succeed. */
function resolveDestinations(state: SimState, requested: Map<string, Point>, kind: 'move' | 'push'): void {
  const units = sortedUnits(state.units.filter(isAlive));
  const active = new Set(requested.keys());
  const destinations = new Map<string, string[]>();
  for (const [id, target] of requested) destinations.set(key(target), [...(destinations.get(key(target)) ?? []), id]);
  for (const contenders of destinations.values()) if (contenders.length > 1) contenders.forEach((id) => active.delete(id));
  let changed = true;
  while (changed) {
    changed = false;
    for (const unit of units) {
      if (!active.has(unit.id)) continue;
      const blocker = units.find((candidate) => same(candidate, requested.get(unit.id)!));
      if (blocker && !active.has(blocker.id)) { active.delete(unit.id); changed = true; }
    }
  }
  const previous = new Map(units.map((unit) => [unit.id, point(unit)]));
  for (const unit of units) {
    const target = requested.get(unit.id);
    if (!target) continue;
    if (active.has(unit.id)) {
      unit.q = target.q; unit.r = target.r;
      event(state, { kind, unitId: unit.id, owner: unit.owner, from: previous.get(unit.id), to: point(unit), text: `${getChampion(unit.championId).name} ${kind === 'move' ? 'moves' : 'is pushed'} to ${unit.q}, ${unit.r}.` });
    } else event(state, { kind: 'bounce', unitId: unit.id, owner: unit.owner, from: previous.get(unit.id), to: target, text: `${getChampion(unit.championId).name}'s ${kind} is blocked; they stay put.` });
  }
}
type Spell = { unitId: string; owner: Player; element: Element; from: Point; target: Point };
function defeat(state: SimState, unit: SimUnit): void {
  if (unit.hp > 0 || unit.respawn !== undefined) return;
  unit.hp = 0; unit.respawn = state.round + 2;
  state.scores[other(unit.owner)]++;
  event(state, { kind: 'defeat', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: 1, text: `${getChampion(unit.championId).name} falls. Opponent +1; misses round ${state.round + 1} and returns in round ${state.round + 2}.` });
}
function respawnDue(state: SimState): void {
  // A fair allocation uses mirrored home preference. Only six units can occupy the 37-cell map.
  for (const unit of sortedUnits(state.units.filter((entry) => entry.respawn !== undefined && entry.respawn <= state.round))) {
    const sign = unit.owner === 0 ? 1 : -1;
    const roster = state.units.filter((entry) => entry.owner === unit.owner);
    const start = STARTS[unit.owner][roster.findIndex((entry) => entry.id === unit.id)];
    const free = state.cells.filter((cell) => !occupant(state, cell));
    free.sort((a, b) => Number(a.well) - Number(b.well) || sign * (a.q - b.q) || distance(a, start) - distance(b, start) || sign * (a.r - b.r));
    const cell = free[0]; if (!cell) continue;
    unit.q = cell.q; unit.r = cell.r; unit.hp = unit.maxHp; delete unit.respawn; delete unit.guard;
    event(state, { kind: 'respawn', unitId: unit.id, owner: unit.owner, to: point(unit), text: `${getChampion(unit.championId).name} returns at full health.` });
  }
}

export function resolveRound(state: SimState, plans: [TeamPlan, TeamPlan]): SimState {
  if (!Array.isArray(plans) || plans.length !== 2) throw new Error('Both sealed team plans are required.');
  const normalized = [validatePlan(state, 0, plans[0]), validatePlan(state, 1, plans[1])];
  const next: SimState = structuredClone(state); next.version++; next.lastResolution = [];
  const orders = new Map(normalized.flatMap((plan) => plan.orders).map((order) => [order.unitId, order]));
  const moves = new Map<string, Point>();
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const order = orders.get(unit.id)!;
    unit.guard = order.guard === true;
    if (unit.guard) event(next, { kind: 'guard', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, text: `${getChampion(unit.championId).name} guards: absorb 1 combined spell damage and resist pushes this round.` });
    if (order.move) moves.set(unit.id, order.move);
  }
  resolveDestinations(next, moves, 'move');
  const spells: Spell[] = [];
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const order = orders.get(unit.id)!;
    if (!order.cast) continue;
    if (!legalCasts(next, unit.id).some((cell) => same(cell, order.cast!))) {
      event(next, { kind: 'fizzle', unitId: unit.id, owner: unit.owner, from: point(unit), to: order.cast, text: `${getChampion(unit.championId).name}'s spell fizzles: the actual landing lacks range or sight.` });
      continue;
    }
    const element = getChampion(unit.championId).element;
    spells.push({ unitId: unit.id, owner: unit.owner, element, from: point(unit), target: order.cast });
    event(next, { kind: 'cast', unitId: unit.id, owner: unit.owner, from: point(unit), to: order.cast, q: order.cast.q, r: order.cast.r, elements: [element], text: `${getChampion(unit.championId).name} casts ${element} at ${order.cast.q}, ${order.cast.r}.` });
  }
  const priorDark = new Set(next.cells.filter((cell) => elementsOn(cell).includes('dark')).map(key));
  for (const cell of next.cells) {
    const arrivals = spells.filter((spell) => same(spell.target, cell));
    if (!arrivals.length) continue;
    mergeSurface(cell, arrivals.map((spell) => spell.element));
    if (cell.reactions!.length) event(next, { kind: 'reaction', q: cell.q, r: cell.r, elements: cell.elements, terrain: cell.terrain, text: `${cell.reactions!.map((id) => REACTIONS.find((reaction) => reaction.id === id)!.name).join(' + ')} forms at ${cell.q}, ${cell.r}.` });
  }
  const damage = new Map<string, number>(); const healing = new Map<string, number>();
  for (const unit of next.units.filter(isAlive)) {
    const cell = getCell(next, unit.q, unit.r)!;
    const arrivals = spells.filter((spell) => same(spell.target, unit));
    const harmful = arrivals.filter((spell) => !(spell.element === 'light' && spell.owner === unit.owner));
    let total = harmful.reduce((sum, spell) => sum + (spell.element === 'air' ? 1 : 2), 0);
    if (hasReaction(cell, 'steam')) total = Math.ceil(total / 2);
    total = Math.max(0, total - (unit.guard ? GUARD_ABSORPTION : 0));
    damage.set(unit.id, total);
    healing.set(unit.id, (healing.get(unit.id) ?? 0) + arrivals.filter((spell) => spell.element === 'light' && spell.owner === unit.owner).length * 2);
    if (total > 0 && priorDark.has(key(cell))) {
      for (const spell of arrivals.filter((entry) => entry.element === 'dark' && entry.owner !== unit.owner)) healing.set(spell.unitId, (healing.get(spell.unitId) ?? 0) + 1);
    }
  }
  // Read every attack/heal before changing any HP: dead casters still complete their sealed spells.
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const hurt = damage.get(unit.id) ?? 0; const healed = healing.get(unit.id) ?? 0;
    unit.hp = Math.max(0, Math.min(unit.maxHp, unit.hp + healed - hurt));
    if (healed) event(next, { kind: 'heal', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: healed, text: `${getChampion(unit.championId).name} receives ${healed} healing in the exchange.` });
    if (hurt) event(next, { kind: 'damage', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: hurt, text: `${getChampion(unit.championId).name} takes ${hurt} combined spell damage.` });
  }
  next.units.forEach((unit) => defeat(next, unit));
  const pushes = new Map<string, Point>();
  for (const unit of next.units.filter(isAlive)) {
    if (unit.guard) continue;
    const winds = spells.filter((spell) => spell.element === 'air' && same(spell.target, unit) && distance(spell.from, unit) === 1);
    if (!winds.length) continue;
    const vector = winds.reduce((sum, spell) => ({ q: sum.q + unit.q - spell.from.q, r: sum.r + unit.r - spell.from.r }), { q: 0, r: 0 });
    const ranked = DIRECTIONS.map((direction) => ({ direction, alignment: 2 * direction.q * vector.q + direction.q * vector.r + direction.r * vector.q + 2 * direction.r * vector.r })).sort((a, b) => b.alignment - a.alignment);
    if (ranked[0].alignment <= 0 || ranked[0].alignment === ranked[1].alignment) {
      event(next, { kind: 'bounce', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, text: `Competing winds around ${getChampion(unit.championId).name} cancel.` });
      continue;
    }
    const direction = ranked[0].direction;
    const cell = getCell(next, unit.q + direction.q, unit.r + direction.r);
    if (cell) pushes.set(unit.id, point(cell));
    else event(next, { kind: 'bounce', unitId: unit.id, owner: unit.owner, text: `The battlefield edge stops ${getChampion(unit.championId).name}'s push.` });
  }
  resolveDestinations(next, pushes, 'push');
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    if (hasReaction(getCell(next, unit.q, unit.r)!, 'magma')) {
      unit.hp = Math.max(0, unit.hp - 1);
      event(next, { kind: 'surface', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: 1, terrain: 'magma', text: `Magma burns ${getChampion(unit.championId).name} for 1.` });
    }
  }
  next.units.forEach((unit) => defeat(next, unit));
  const gained: [number, number] = [0, 0];
  for (const cell of next.cells.filter((entry) => entry.well)) {
    const unit = occupant(next, cell);
    if (unit) gained[unit.owner] += hasReaction(cell, 'penumbra') ? 2 : 1;
  }
  for (const player of [0, 1] as const) {
    next.scores[player] += gained[player];
    event(next, { kind: 'score', owner: player, amount: gained[player], text: `Player ${player + 1} scores ${gained[player]} from held wells.` });
  }
  for (const cell of next.cells) if (cell.ttl !== undefined) {
    cell.ttl--;
    if (cell.ttl <= 0) { cell.terrain = 'plain'; delete cell.ttl; delete cell.elements; delete cell.reactions; }
  }
  const [left, right] = next.scores;
  if ((Math.max(left, right) >= POINTS_TO_WIN && left !== right) || next.round >= MAX_ROUNDS) {
    next.winner = left === right ? 'draw' : left > right ? 0 : 1;
    next.log.push(next.winner === 'draw' ? 'The Confluence ends in a draw.' : `Player ${next.winner + 1} claims the Confluence.`);
  } else { next.round++; respawnDue(next); }
  next.log = next.log.slice(-100);
  return next;
}

export function previewPlan(state: SimState, player: Player, input: TeamPlan): string[] {
  const plan = validatePlan(state, player, input);
  const lines = plan.orders.map((order) => {
    const unit = state.units.find((entry) => entry.id === order.unitId)!;
    const name = getChampion(unit.championId).name;
    const movement = order.move ? `move to ${order.move.q}, ${order.move.r}` : 'hold position';
    return `${name}: ${movement}; ${order.cast ? `aim ${getChampion(unit.championId).element} at ${order.cast.q}, ${order.cast.r}` : 'Guard (absorb 1 spell damage; resist pushes)'}.`;
  });
  for (const cell of state.cells) {
    const spells = plan.orders.filter((order) => order.cast && same(order.cast, cell));
    if (!spells.length) continue;
    const elements = [...elementsOn(cell), ...spells.map((order) => getChampion(state.units.find((unit) => unit.id === order.unitId)!.championId).element)];
    const reactions = reactionsFor(elements);
    if (reactions.length) lines.push(`At ${cell.q}, ${cell.r}: ${reactions.map((id) => REACTIONS.find((reaction) => reaction.id === id)!.name).join(' + ')}. Enemy spells may add reactions.`);
    const friend = plan.orders.find((order) => same(order.move ?? state.units.find((unit) => unit.id === order.unitId)!, cell));
    if (friend && spells.some((order) => getChampion(state.units.find((unit) => unit.id === order.unitId)!.championId).element !== 'light')) lines.push(`Friendly fire risk at ${cell.q}, ${cell.r}; friendly occupants can be hurt.`);
  }
  if (plan.orders.some((order) => order.move && order.cast)) lines.push('Aim is fixed to the ground. A blocked move can leave a spell out of range or sight.');
  return lines;
}

/** No opponent plan input or hidden information. At most 3×37 move and 3×37 aim candidates. */
export function chooseAIPlan(state: SimState, player: Player): TeamPlan {
  if (state.winner !== null || state.rulesVersion !== 3) return { orders: [] };
  const units = state.units.filter((unit) => unit.owner === player && isAlive(unit));
  const enemies = state.units.filter((unit) => unit.owner !== player && isAlive(unit));
  const wells = state.cells.filter((cell) => cell.well);
  const perspective = player === 0 ? 1 : -1;
  const reserved = new Set<string>();
  const orders: Order[] = [];
  for (const unit of units) {
    let landing = getCell(state, unit.q, unit.r)!; let best = -Infinity;
    const candidates = [landing, ...legalMoves(state, unit.id)].sort((a, b) => perspective * (a.q - b.q || a.r - b.r));
    for (const cell of candidates) {
      if (reserved.has(key(cell)) || enemies.some((enemy) => same(enemy, cell))) continue;
      const nearest = Math.min(...wells.filter((well) => !reserved.has(key(well))).map((well) => distance(cell, well)), 10);
      let value = (cell.well ? 14 : 0) - nearest * 3 + cell.height * 0.5;
      if (hasReaction(cell, 'magma')) value -= unit.hp <= 1 ? 100 : 4;
      if (cell.well && hasReaction(cell, 'penumbra')) value += 5;
      if (unit.hp <= 2) value -= enemies.filter((enemy) => distance(enemy, cell) <= 2).length * 2;
      if (value > best) { best = value; landing = cell; }
    }
    reserved.add(key(landing));
    orders.push({ unitId: unit.id, ...(same(landing, unit) ? {} : { move: point(landing) }), guard: true });
  }
  // Correct predictable collisions inside our own plan before selecting any aim.
  // Enemy moves remain unknown; this assumes only their currently visible occupancy.
  const ownMovement = structuredClone(state);
  resolveDestinations(ownMovement, new Map(orders.filter((order) => order.move).map((order) => [order.unitId, order.move!])), 'move');
  for (const order of orders) if (order.move) {
    const landed = ownMovement.units.find((unit) => unit.id === order.unitId)!;
    if (!same(landed, order.move)) delete order.move;
  }
  const friendlyLandings = new Map(orders.map((order) => [key(order.move ?? units.find((unit) => unit.id === order.unitId)!), order.unitId]));
  const plannedElements = new Map<string, Element[]>();
  for (const order of orders) {
    const unit = units.find((entry) => entry.id === order.unitId)!;
    const element = getChampion(unit.championId).element;
    const origin = order.move ?? unit;
    let target: SimCell | undefined; let best = 0;
    for (const cell of legalCasts(state, unit.id, origin).sort((a, b) => perspective * (a.q - b.q || a.r - b.r))) {
      const allyId = friendlyLandings.get(key(cell));
      if (allyId && element !== 'light') continue; // Never knowingly blast a friendly planned landing.
      const enemy = enemies.find((entry) => same(entry, cell));
      const existing = [...elementsOn(cell), ...(plannedElements.get(key(cell)) ?? [])];
      const reactions = reactionsFor([...existing, element]);
      let value = 0;
      if (enemy) {
        let hit = element === 'air' ? 1 : 2;
        if (reactions.includes('steam')) hit = Math.ceil(hit / 2);
        value += hit * 3 + (enemy.hp <= hit ? 8 : 0) + (cell.well ? 2 : 0);
        if (element === 'air' && distance(origin, cell) === 1 && cell.well) value += 3;
        if (reactions.includes('magma')) value += 3;
        if (reactions.includes('penumbra') && cell.well) value -= 8;
      }
      if (allyId && element === 'light') {
        const ally = units.find((entry) => entry.id === allyId)!;
        value += Math.min(2, ally.maxHp - ally.hp) * 4;
        if (enemies.some((candidate) => distance(candidate, cell) <= 2)) value += 2;
      }
      if (reactions.includes('penumbra') && cell.well && allyId) value += 8;
      if (!enemy && cell.well && !allyId && reactions.includes('magma')) value += 1;
      if (value > best) { best = value; target = cell; }
    }
    if (target) {
      delete order.guard; order.cast = point(target);
      plannedElements.set(key(target), [...(plannedElements.get(key(target)) ?? []), element]);
    }
  }
  return validatePlan(state, player, { orders });
}

/** Strict save validation; no plan fields, unknown versions, forged board shapes or occupied overlaps. */
export function restoreSimState(input: unknown): SimState {
  const value = object(input, ['rulesVersion', 'version', 'mapId', 'round', 'scores', 'units', 'cells', 'log', 'winner', 'lastResolution'], 'Saved match');
  if (value.rulesVersion !== 3 || value.mapId !== 'confluence' || !Number.isSafeInteger(value.version) || (value.version as number) < 1 || !Number.isSafeInteger(value.round) || (value.round as number) < 1 || (value.round as number) > MAX_ROUNDS) throw new Error('Unsupported or invalid simultaneous save.');
  if (!Array.isArray(value.scores) || value.scores.length !== 2 || value.scores.some((score) => !Number.isSafeInteger(score) || score < 0 || score > 1000)) throw new Error('Invalid saved scores.');
  if (![null, 0, 1, 'draw'].includes(value.winner as never)) throw new Error('Invalid saved winner.');
  const [left, right] = value.scores as [number, number];
  const terminal = value.winner !== null;
  if (value.version !== (value.round as number) + Number(terminal)) throw new Error('Saved round and resolution version disagree.');
  if (!terminal && Math.max(left, right) >= POINTS_TO_WIN && left !== right) throw new Error('A completed victory cannot remain active.');
  if (terminal) {
    const expected = left === right ? 'draw' : left > right ? 0 : 1;
    if (value.winner !== expected || (value.round !== MAX_ROUNDS && (left === right || Math.max(left, right) < POINTS_TO_WIN))) throw new Error('Saved victory disagrees with the score or round cap.');
  }
  if (!Array.isArray(value.cells) || value.cells.length !== 37 || !Array.isArray(value.units) || value.units.length !== 6) throw new Error('Invalid saved battlefield.');
  const cells = value.cells.map((raw): SimCell => {
    const cell = object(raw, ['q', 'r', 'well', 'terrain', 'ttl', 'height', 'elements', 'reactions'], 'Saved hex');
    const position = readPoint({ q: cell.q, r: cell.r });
    if (distance(position, { q: 0, r: 0 }) > BOARD_RADIUS || cell.height !== heightAt(position.q, position.r) || cell.well !== (position.q === 0 && [-2, 0, 2].includes(position.r))) throw new Error('Saved board geometry changed.');
    const allowed = ['plain', ...ELEMENT_ORDER, ...REACTIONS.map((reaction) => reaction.id)];
    if (typeof cell.terrain !== 'string' || !allowed.includes(cell.terrain)) throw new Error('Unknown saved terrain.');
    if (cell.ttl !== undefined && (!Number.isSafeInteger(cell.ttl) || (cell.ttl as number) < 1 || (cell.ttl as number) > TERRAIN_DURATION)) throw new Error('Invalid terrain lifetime.');
    if (cell.elements !== undefined && (!Array.isArray(cell.elements) || cell.elements.length > 6 || new Set(cell.elements).size !== cell.elements.length || cell.elements.some((element) => !ELEMENT_ORDER.includes(element)))) throw new Error('Invalid surface elements.');
    if (cell.reactions !== undefined && (!Array.isArray(cell.reactions) || cell.reactions.length > 4 || new Set(cell.reactions).size !== cell.reactions.length || cell.reactions.some((reaction) => !REACTIONS.some((entry) => entry.id === reaction)))) throw new Error('Invalid surface reactions.');
    const restored = { ...cell } as SimCell;
    if (cell.terrain === 'plain' && (cell.ttl !== undefined || (cell.elements as unknown[] | undefined)?.length || (cell.reactions as unknown[] | undefined)?.length)) throw new Error('Plain terrain cannot contain active elements.');
    if (cell.terrain !== 'plain' && (cell.ttl === undefined || !Array.isArray(cell.elements) || !Array.isArray(cell.reactions))) throw new Error('Active terrain requires its complete elemental state.');
    if (cell.terrain !== 'plain' && (JSON.stringify(reactionsFor(restored.elements!)) !== JSON.stringify(restored.reactions) || restored.terrain !== (restored.reactions![0] ?? restored.elements![0]))) throw new Error('Surface reactions disagree with their elements.');
    return restored;
  });
  if (new Set(cells.map(key)).size !== 37) throw new Error('Duplicate saved hex.');
  const units = value.units.map((raw): SimUnit => {
    const unit = object(raw, ['id', 'championId', 'owner', 'q', 'r', 'hp', 'maxHp', 'guard', 'respawn'], 'Saved champion');
    if (unit.owner !== 0 && unit.owner !== 1) throw new Error('Invalid champion owner.');
    if (typeof unit.championId !== 'string' || !CHAMPIONS.some((champion) => champion.id === unit.championId) || unit.id !== `${unit.owner}-${unit.championId}`) throw new Error('Invalid saved champion.');
    const position = readPoint({ q: unit.q, r: unit.r });
    if (!cells.some((cell) => same(cell, position)) || unit.maxHp !== 5 || !Number.isSafeInteger(unit.hp) || (unit.hp as number) < 0 || (unit.hp as number) > 5 || (unit.guard !== undefined && typeof unit.guard !== 'boolean')) throw new Error('Invalid champion condition.');
    if (unit.respawn !== undefined && (!Number.isSafeInteger(unit.respawn) || (unit.respawn as number) <= (value.round as number) || (unit.respawn as number) > (value.round as number) + 2)) throw new Error('Invalid return round.');
    if ((unit.hp === 0) !== (unit.respawn !== undefined)) throw new Error('Defeat and return state disagree.');
    return { ...unit } as SimUnit;
  });
  if (new Set(units.map((unit) => unit.id)).size !== 6 || [0, 1].some((owner) => units.filter((unit) => unit.owner === owner).length !== 3) || new Set(units.filter(isAlive).map(key)).size !== units.filter(isAlive).length) throw new Error('Invalid squad composition or overlapping champions.');
  if (!Array.isArray(value.log) || value.log.length > 100 || value.log.some((line) => typeof line !== 'string' || line.length > 600)) throw new Error('Invalid saved log.');
  if (!Array.isArray(value.lastResolution) || value.lastResolution.length > 150) throw new Error('Invalid saved resolution.');
  const kinds = ['move', 'bounce', 'cast', 'reaction', 'damage', 'heal', 'push', 'defeat', 'respawn', 'score', 'guard', 'fizzle', 'surface'];
  for (const raw of value.lastResolution) {
    const entry = object(raw, ['kind', 'text', 'unitId', 'owner', 'from', 'to', 'q', 'r', 'amount', 'elements', 'terrain'], 'Saved event');
    if (!kinds.includes(entry.kind as string) || typeof entry.text !== 'string' || entry.text.length > 600) throw new Error('Invalid saved event.');
    if (entry.unitId !== undefined && !units.some((unit) => unit.id === entry.unitId)) throw new Error('Unknown event champion.');
    if (entry.owner !== undefined && entry.owner !== 0 && entry.owner !== 1) throw new Error('Invalid event owner.');
    for (const name of ['from', 'to']) if (entry[name] !== undefined && !cells.some((cell) => same(cell, readPoint(entry[name])))) throw new Error('Invalid event hex.');
    if ((entry.q !== undefined || entry.r !== undefined) && !cells.some((cell) => same(cell, readPoint({ q: entry.q, r: entry.r })))) throw new Error('Invalid event coordinate.');
    if (entry.amount !== undefined && (!Number.isSafeInteger(entry.amount) || (entry.amount as number) < 0 || (entry.amount as number) > 100)) throw new Error('Invalid event amount.');
    if (entry.elements !== undefined && (!Array.isArray(entry.elements) || entry.elements.length > 6 || entry.elements.some((element) => !ELEMENT_ORDER.includes(element)))) throw new Error('Invalid event elements.');
    if (entry.terrain !== undefined && !['plain', ...ELEMENT_ORDER, ...REACTIONS.map((reaction) => reaction.id)].includes(entry.terrain as string)) throw new Error('Invalid event terrain.');
  }
  return structuredClone({ ...value, cells, units }) as SimState;
}
