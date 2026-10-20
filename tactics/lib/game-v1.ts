/** Deterministic, JSON-safe rules shared by the browser and authoritative room server. */
export type Player = 0 | 1;
export type Element = 'water' | 'fire' | 'air' | 'earth' | 'light' | 'dark';
export type Point = { q: number; r: number };
export type Cell = Point & { well: boolean; terrain: string; ttl?: number };
export type Unit = Point & {
  id: string;
  championId: string;
  owner: Player;
  hp: number;
  maxHp: number;
  moved: boolean;
  cast: boolean;
  /** A defeated champion returns at the beginning of its owner's next turn. */
  respawn?: number;
};
export type GameState = {
  version: number;
  mapId: string;
  round: number;
  turn: Player;
  initiative: Player;
  turnsTaken: number;
  ap: number;
  scores: [number, number];
  units: Unit[];
  cells: Cell[];
  log: string[];
  winner: Player | 'draw' | null;
};
export type GameAction = {
  type: 'move' | 'cast' | 'end';
  unitId?: string;
  q?: number;
  r?: number;
};
export type Champion = {
  id: string;
  name: string;
  element: Element;
  ancestry: string;
  role: string;
  description: string;
  hp: number;
  portrait: string;
};

export const BOARD_RADIUS = 3;
export const MOVE_RANGE = 2;
export const CAST_RANGE = 2;
export const POINTS_TO_WIN = 8;
export const MAX_ROUNDS = 16;
export const ACTIONS_PER_TURN = 2;
export const MAPS = [{ id: 'confluence', name: 'The Confluence', description: 'Three wells. One shifting battlefield.' }];

export const ELEMENTS: { id: Element; name: string; color: string; symbol: string; description: string }[] = [
  { id: 'water', name: 'Water', color: '#52bdf4', symbol: '≈', description: 'Combine with Fire for Steam cover, or Earth for healing Bloom.' },
  { id: 'fire', name: 'Fire', color: '#ff865f', symbol: '◆', description: 'Combine with Water for Steam cover, or Earth for dangerous Glass.' },
  { id: 'air', name: 'Air', color: '#b8e9e4', symbol: '↝', description: 'Push a struck enemy one hex away when the destination is free.' },
  { id: 'earth', name: 'Earth', color: '#bbd78a', symbol: '⬡', description: 'Combine with Water for healing Bloom, or Fire for dangerous Glass.' },
  { id: 'light', name: 'Light', color: '#ffe9a5', symbol: '✦', description: 'Combine with Dark to create a Rift that doubles a well’s control point.' },
  { id: 'dark', name: 'Dark', color: '#bc9af4', symbol: '☾', description: 'Combine with Light to create a Rift that doubles a well’s control point.' },
];

export const REACTIONS: { id: string; name: string; elements: [Element, Element]; color: string; symbol: string; description: string }[] = [
  { id: 'steam', name: 'Steam', elements: ['fire', 'water'], color: '#9bcad4', symbol: '≋', description: 'A champion standing here takes 1 less spell damage.' },
  { id: 'bloom', name: 'Bloom', elements: ['water', 'earth'], color: '#ace59d', symbol: '✿', description: 'Heal the occupant by 1 at the start of their turn.' },
  { id: 'glass', name: 'Glass', elements: ['fire', 'earth'], color: '#f5ab86', symbol: '◇', description: 'Deal 1 damage when a champion lands here, including a push.' },
  { id: 'rift', name: 'Rift', elements: ['light', 'dark'], color: '#d9b1ff', symbol: '◈', description: 'An occupied well here scores 2 points instead of 1.' },
];

export const CHAMPIONS: Champion[] = [
  { id: 'oh_tipi', name: 'Oh Tipi', element: 'water', ancestry: 'Seakin', role: 'Tide shaper', description: 'Lay Water to turn Fire into cover or Earth into a healing garden.', hp: 5, portrait: '/portraits/oh_tipi.webp' },
  { id: 'wa_bidi', name: 'Wa Bidi', element: 'fire', ancestry: 'Goblin', role: 'Spark keeper', description: 'Lay Fire to build Steam cover or punish a landing with Glass.', hp: 5, portrait: '/portraits/wa_bidi.webp' },
  { id: 'grace_reava', name: 'Grace Riva', element: 'air', ancestry: 'Sylph', role: 'Wind dancer', description: 'Push opponents off wells and into hazards. Every hex matters.', hp: 5, portrait: '/portraits/grace_reava.webp' },
  { id: 'treevor_mason', name: 'Treevor the Mason', element: 'earth', ancestry: 'Treefolk', role: 'Living mason', description: 'Lay Earth to prepare healing Bloom or a field of Glass.', hp: 5, portrait: '/portraits/treevor_mason.webp' },
  { id: 'haara', name: 'Haara', element: 'light', ancestry: 'Nymph', role: 'Dawn weaver', description: 'Bring Light to a Dark hex to open a well-doubling Rift.', hp: 5, portrait: '/portraits/haara.webp' },
  { id: 's_wayne', name: 'S. Wayne', element: 'dark', ancestry: 'Hobbit', role: 'Dusk wanderer', description: 'Bring Dark to a Light hex to open a well-doubling Rift.', hp: 5, portrait: '/portraits/s_wayne.webp' },
];

const DIRECTIONS: Point[] = [{ q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 }, { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 }];
const DEFAULT_ROSTER = ['oh_tipi', 'wa_bidi', 'treevor_mason'];
const STARTS: [Point[], Point[]] = [
  [{ q: -3, r: 0 }, { q: -3, r: 1 }, { q: -3, r: 2 }],
  [{ q: 3, r: 0 }, { q: 3, r: -1 }, { q: 3, r: -2 }],
];
const key = (p: Point) => `${p.q},${p.r}`;
const same = (a: Point, b: Point) => a.q === b.q && a.r === b.r;
const opponent = (player: Player): Player => player === 0 ? 1 : 0;
export const isAlive = (unit: Unit) => unit.hp > 0 && unit.respawn === undefined;
export const distance = (a: Point, b: Point) => Math.max(Math.abs(a.q - b.q), Math.abs(a.r - b.r), Math.abs(a.q + a.r - b.q - b.r));
export const getCell = (state: GameState, q: number, r: number) => state.cells.find((cell) => cell.q === q && cell.r === r);
export const getChampion = (id: string): Champion => {
  const champion = CHAMPIONS.find((entry) => entry.id === id);
  if (!champion) throw new Error('Unknown champion.');
  return champion;
};
const occupant = (state: GameState, point: Point) => state.units.find((unit) => isAlive(unit) && same(unit, point));
const addLog = (state: GameState, message: string) => { state.log.push(message); state.log = state.log.slice(-80); };

export function createGame(rosters: [string[], string[]] = [[...DEFAULT_ROSTER], [...DEFAULT_ROSTER]], mapId = 'confluence'): GameState {
  if (!MAPS.some((map) => map.id === mapId)) throw new Error('Unknown battlefield.');
  if (!Array.isArray(rosters) || rosters.length !== 2 || rosters.some((roster) => !Array.isArray(roster) || roster.length !== 3 || new Set(roster).size !== 3 || roster.some((id) => !CHAMPIONS.some((champion) => champion.id === id)))) {
    throw new Error('Each player must choose exactly 3 different champions.');
  }
  const cells: Cell[] = [];
  for (let q = -BOARD_RADIUS; q <= BOARD_RADIUS; q++) {
    for (let r = -BOARD_RADIUS; r <= BOARD_RADIUS; r++) {
      if (distance({ q, r }, { q: 0, r: 0 }) <= BOARD_RADIUS) cells.push({ q, r, well: q === 0 && [-2, 0, 2].includes(r), terrain: 'plain' });
    }
  }
  const units = rosters.flatMap((roster, owner) => roster.map((championId, index): Unit => ({
    id: `${owner}-${championId}`, championId, owner: owner as Player, ...STARTS[owner as Player][index],
    hp: getChampion(championId).hp, maxHp: getChampion(championId).hp, moved: false, cast: false,
  })));
  return { version: 1, mapId, round: 1, turn: 0, initiative: 0, turnsTaken: 0, ap: ACTIONS_PER_TURN, scores: [0, 0], units, cells, log: ['The Confluence opens. Each side has 2 actions; wells score after both turns.'], winner: null };
}

/** Traversal is deterministic; units and walls block both intermediate and final hexes. */
export function movementPath(state: GameState, unit: Unit, target: Point): Cell[] | null {
  const queue: { point: Point; path: Cell[] }[] = [{ point: unit, path: [] }];
  const visited = new Set([key(unit)]);
  for (let index = 0; index < queue.length; index++) {
    const { point, path } = queue[index];
    if (path.length >= MOVE_RANGE) continue;
    for (const direction of DIRECTIONS) {
      const cell = getCell(state, point.q + direction.q, point.r + direction.r);
      if (!cell || visited.has(key(cell)) || cell.terrain === 'wall' || occupant(state, cell)) continue;
      const nextPath = [...path, cell];
      if (same(cell, target)) return nextPath;
      visited.add(key(cell));
      queue.push({ point: cell, path: nextPath });
    }
  }
  return null;
}

function clearCastPath(state: GameState, unit: Unit, target: Cell): boolean {
  const range = distance(unit, target);
  if (target.terrain === 'wall' || range > CAST_RANGE) return false;
  if (range <= 1) return true;
  return DIRECTIONS.some((direction) => {
    const middle = getCell(state, unit.q + direction.q, unit.r + direction.r);
    return middle && middle.terrain !== 'wall' && distance(middle, target) === 1;
  });
}

export function legalTargets(state: GameState, unitId: string, kind: 'move' | 'cast'): Cell[] {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit) || state.winner !== null || state.ap <= 0 || unit.owner !== state.turn || (kind === 'move' ? unit.moved : unit.cast)) return [];
  if (kind === 'move') return state.cells.filter((cell) => distance(unit, cell) <= MOVE_RANGE && movementPath(state, unit, cell));
  if (kind === 'cast') return state.cells.filter((cell) => clearCastPath(state, unit, cell));
  return [];
}

export function resultingTerrain(existing: string, element: Element): string {
  if (REACTIONS.some((reaction) => reaction.id === existing && reaction.elements.includes(element))) return existing;
  return REACTIONS.find((reaction) => reaction.elements.includes(element) && reaction.elements.includes(existing as Element) && element !== existing)?.id ?? element;
}

function defeat(state: GameState, unit: Unit): void {
  if (unit.hp > 0 || unit.respawn !== undefined) return;
  unit.hp = 0;
  unit.respawn = state.round;
  state.scores[opponent(unit.owner)]++;
  addLog(state, `${getChampion(unit.championId).name} falls. Opponent +1; returns next friendly turn.`);
}

function landingDamage(state: GameState, unit: Unit): void {
  if (getCell(state, unit.q, unit.r)?.terrain === 'glass') {
    unit.hp--;
    addLog(state, `Glass deals 1 to ${getChampion(unit.championId).name}.`);
    defeat(state, unit);
  }
}

function pushDestination(state: GameState, source: Unit, target: Unit): Cell | undefined {
  const currentDistance = distance(source, target);
  // Choose the direction closest to the source→target vector. Rotate exact-angle
  // tie-breaking with the player's perspective so mirrored hazards stay equivalent.
  const dq = target.q - source.q;
  const dr = target.r - source.r;
  const ranked = DIRECTIONS.map((direction, index) => ({ direction, index: (index + source.owner * 3) % 6, alignment: 2 * direction.q * dq + direction.q * dr + direction.r * dq + 2 * direction.r * dr }))
    .sort((a, b) => b.alignment - a.alignment || a.index - b.index);
  const direction = ranked[0].direction;
  const cell = getCell(state, target.q + direction.q, target.r + direction.r);
  return cell && cell.terrain !== 'wall' && !occupant(state, cell) && distance(source, cell) > currentDistance ? cell : undefined;
}

function beginTurn(state: GameState, player: Player): void {
  state.turn = player;
  state.ap = ACTIONS_PER_TURN;
  for (const unit of state.units.filter((entry) => entry.owner === player)) {
    unit.moved = false;
    unit.cast = false;
    if (unit.respawn !== undefined) {
      const homeQ = player === 0 ? -BOARD_RADIUS : BOARD_RADIUS;
      const start = STARTS[player][state.units.filter((entry) => entry.owner === player).findIndex((entry) => entry.id === unit.id)];
      const enemies = state.units.filter((entry) => entry.owner !== player && isAlive(entry));
      const free = state.cells.filter((cell) => !occupant(state, cell) && cell.terrain !== 'wall');
      free.sort((a, b) => Math.abs(a.q - homeQ) - Math.abs(b.q - homeQ)
        || (Math.min(...enemies.map((enemy) => distance(b, enemy)), 10) - Math.min(...enemies.map((enemy) => distance(a, enemy)), 10))
        || distance(a, start) - distance(b, start) || a.q - b.q || a.r - b.r);
      const spawn = free[0];
      if (!spawn) continue;
      unit.q = spawn.q; unit.r = spawn.r; unit.hp = unit.maxHp;
      delete unit.respawn;
      // Homecoming clears lingering hazards; no damage can repeat during respawn itself.
      spawn.terrain = 'plain'; delete spawn.ttl;
      addLog(state, `${getChampion(unit.championId).name} returns at full health.`);
    }
    if (isAlive(unit) && getCell(state, unit.q, unit.r)?.terrain === 'bloom' && unit.hp < unit.maxHp) {
      unit.hp = Math.min(unit.maxHp, unit.hp + 1);
      addLog(state, `Bloom heals ${getChampion(unit.championId).name} by 1.`);
    }
  }
}

function finishTurn(state: GameState): void {
  state.turnsTaken++;
  if (state.turnsTaken < 2) {
    beginTurn(state, opponent(state.turn));
    return;
  }
  const gained: [number, number] = [0, 0];
  for (const cell of state.cells.filter((entry) => entry.well)) {
    const unit = occupant(state, cell);
    if (unit) gained[unit.owner] += cell.terrain === 'rift' ? 2 : 1;
  }
  state.scores[0] += gained[0]; state.scores[1] += gained[1];
  addLog(state, `Round ${state.round}: wells award ${gained[0]} / ${gained[1]}. Score ${state.scores[0]}–${state.scores[1]}.`);
  // Score first, then expire surfaces, so a newly created reaction can affect this round.
  for (const cell of state.cells) {
    if (cell.ttl !== undefined) {
      cell.ttl--;
      if (cell.ttl <= 0) { cell.terrain = 'plain'; delete cell.ttl; }
    }
  }
  const [left, right] = state.scores;
  if ((Math.max(left, right) >= POINTS_TO_WIN && left !== right) || state.round >= MAX_ROUNDS) {
    state.winner = left === right ? 'draw' : left > right ? 0 : 1;
    state.ap = 0;
    addLog(state, state.winner === 'draw' ? 'The Confluence ends in a draw.' : `Player ${state.winner + 1} claims the Confluence.`);
    return;
  }
  state.round++;
  state.turnsTaken = 0;
  state.initiative = opponent(state.initiative);
  beginTurn(state, state.initiative);
  addLog(state, `Round ${state.round} begins. Initiative alternates: Player ${state.turn + 1} acts again with 2 new actions.`);
}

export function applyAction(state: GameState, player: Player, action: GameAction): GameState {
  if (state.winner !== null) throw new Error('This match has finished.');
  if ((player !== 0 && player !== 1) || player !== state.turn) throw new Error('Wait for your turn.');
  if (!action || !['move', 'cast', 'end'].includes(action.type)) throw new Error('Unknown action.');
  if (state.ap <= 0) throw new Error('No actions remain.');
  // Validate the entire command before cloning or changing anything.
  let unit: Unit | undefined;
  let target: Cell | undefined;
  if (action.type !== 'end') {
    unit = state.units.find((entry) => entry.id === action.unitId);
    if (!unit || unit.owner !== player || !isAlive(unit)) throw new Error('Choose an active champion from your squad.');
    if (!Number.isInteger(action.q) || !Number.isInteger(action.r)) throw new Error('Choose a battlefield hex.');
    target = getCell(state, action.q!, action.r!);
    if (!target) throw new Error('That hex is outside the battlefield.');
    if (action.type === 'move' && unit.moved) throw new Error('This champion has already moved this turn.');
    if (action.type === 'cast' && unit.cast) throw new Error('This champion has already cast this turn.');
    if (!legalTargets(state, unit.id, action.type).some((cell) => same(cell, target!))) {
      throw new Error(action.type === 'move' ? 'Move up to 2 connected, unoccupied hexes; units and walls block the path.' : 'Cast within 2 hexes; stone walls block the spell.');
    }
  }
  const next: GameState = structuredClone(state);
  next.version++;
  if (action.type === 'end') {
    addLog(next, `Player ${player + 1} ends their turn.`);
    finishTurn(next);
    return next;
  }
  const actor = next.units.find((entry) => entry.id === unit!.id)!;
  const destination = getCell(next, target!.q, target!.r)!;
  const champion = getChampion(actor.championId);
  if (action.type === 'move') {
    actor.q = destination.q; actor.r = destination.r; actor.moved = true;
    addLog(next, `${champion.name} moves to ${destination.q}, ${destination.r}.`);
    landingDamage(next, actor);
  } else {
    actor.cast = true;
    const hadCover = destination.terrain === 'steam';
    destination.terrain = resultingTerrain(destination.terrain, champion.element);
    destination.ttl = 2;
    const targetUnit = occupant(next, destination);
    const damage = hadCover || destination.terrain === 'steam' ? 1 : 2;
    addLog(next, `${champion.name} casts ${champion.element}; ${destination.terrain} at ${destination.q}, ${destination.r}.`);
    if (targetUnit && targetUnit.owner !== player) {
      targetUnit.hp -= damage;
      addLog(next, `${getChampion(targetUnit.championId).name} takes ${damage}.`);
      defeat(next, targetUnit);
      if (champion.element === 'air' && isAlive(targetUnit)) {
        const pushed = pushDestination(next, actor, targetUnit);
        if (pushed) {
          targetUnit.q = pushed.q; targetUnit.r = pushed.r;
          addLog(next, `${getChampion(targetUnit.championId).name} is pushed one hex.`);
          landingDamage(next, targetUnit);
        }
      }
    }
  }
  next.ap--;
  if (next.ap === 0) finishTurn(next);
  return next;
}

export function previewAction(state: GameState, action: GameAction): string {
  if (action.type === 'end') return state.turnsTaken === 0
    ? `End your turn. Player ${opponent(state.turn) + 1} acts next; wells score after that turn.`
    : `End round ${state.round}: occupied wells score. If the match continues, Player ${opponent(state.initiative) + 1} opens round ${state.round + 1} with 2 new actions because initiative alternates.`;
  const unit = state.units.find((entry) => entry.id === action.unitId);
  const cell = getCell(state, action.q ?? NaN, action.r ?? NaN);
  if (!unit || !cell) return 'Choose a highlighted hex.';
  const champion = getChampion(unit.championId);
  if (action.type === 'move') {
    const lethal = cell.terrain === 'glass' && unit.hp <= 1;
    return `Move ${champion.name} to ${cell.q}, ${cell.r}.${cell.well && !lethal ? ' Occupy this well to score at round end.' : ''}${cell.terrain === 'glass' ? ' Landing on Glass deals 1 damage.' : ''}${lethal ? ` Defeated: Player ${opponent(unit.owner) + 1} gains 1 point; return next friendly turn.` : ''}`;
  }
  const terrain = resultingTerrain(cell.terrain, champion.element);
  const target = occupant(state, cell);
  const damage = cell.terrain === 'steam' || terrain === 'steam' ? 1 : 2;
  const enemy = target && target.owner !== unit.owner ? target : undefined;
  const hit = enemy ? `${damage} damage to ${getChampion(enemy.championId).name}. ` : 'No friendly damage. ';
  const reaction = REACTIONS.find((entry) => entry.id === terrain);
  const pushed = champion.element === 'air' && enemy && enemy.hp > damage ? pushDestination(state, unit, enemy) : undefined;
  const glassDamage = pushed?.terrain === 'glass' ? 1 : 0;
  const push = pushed ? `Push to ${pushed.q}, ${pushed.r}.${glassDamage ? ' Glass deals 1 more damage.' : ''} ` : champion.element === 'air' && enemy && enemy.hp > damage ? 'Push blocked. ' : '';
  const lethal = enemy && enemy.hp <= damage + glassDamage ? `Defeated: Player ${unit.owner + 1} gains 1 point; return next friendly turn. ` : '';
  return `${hit}${push}${lethal}Create ${reaction?.name ?? ELEMENTS.find((entry) => entry.id === terrain)?.name ?? terrain}.${reaction ? ` ${reaction.description}` : ''} Lasts through 2 round endings.`;
}

/** A bounded, deterministic opponent: enumerate at most 222 actions, with no recursion. */
export function chooseAIAction(state: GameState): GameAction {
  if (state.winner !== null || state.ap <= 0) return { type: 'end' };
  let best: GameAction = { type: 'end' };
  let bestValue = 0;
  const friendly = state.units.filter((unit) => unit.owner === state.turn && isAlive(unit));
  const enemies = state.units.filter((unit) => unit.owner !== state.turn && isAlive(unit));
  const wells = state.cells.filter((cell) => cell.well);
  // Use each side's own coordinate orientation so exact ties do not favor one edge.
  const perspective = state.turn === 0 ? 1 : -1;
  const ordered = (cells: Cell[]) => cells.sort((a, b) => perspective * (a.q - b.q || a.r - b.r));
  for (const unit of friendly) {
    for (const cell of ordered(legalTargets(state, unit.id, 'move'))) {
      const source = getCell(state, unit.q, unit.r)!;
      const availableWells = wells.filter((well) => !friendly.some((ally) => ally.id !== unit.id && same(ally, well)));
      const oldDistance = Math.min(...availableWells.map((well) => distance(unit, well)), 10);
      const newDistance = Math.min(...availableWells.map((well) => distance(cell, well)), 10);
      let value = (oldDistance - newDistance) * 2 + (cell.well ? 8 : 0) - (source.well ? 9 : 0);
      if (cell.terrain === 'glass') value -= unit.hp <= 1 ? 25 : 2;
      if (cell.terrain === 'rift' && cell.well) value += 5;
      if (cell.terrain === 'bloom' && unit.hp < unit.maxHp) value += 1;
      if (unit.hp <= 2) value -= enemies.filter((enemy) => distance(enemy, cell) <= 2).length * 2;
      if (value > bestValue) { bestValue = value; best = { type: 'move', unitId: unit.id, q: cell.q, r: cell.r }; }
    }
    const element = getChampion(unit.championId).element;
    for (const cell of ordered(legalTargets(state, unit.id, 'cast'))) {
      const target = occupant(state, cell);
      const terrain = resultingTerrain(cell.terrain, element);
      const damage = cell.terrain === 'steam' || terrain === 'steam' ? 1 : 2;
      let value = 0;
      if (target && target.owner !== state.turn) {
        value += damage * 3 + (target.hp <= damage ? 18 : 0) + (cell.well ? 2 : 0);
        if (element === 'air' && target.hp > damage) {
          const pushed = pushDestination(state, unit, target);
          if (pushed) value += (cell.well ? 10 : 0) + (pushed.terrain === 'glass' ? 4 : 0) - (pushed.well ? 6 : 0);
        }
      }
      if (terrain === 'rift' && cell.well && target?.owner === state.turn) value += 10;
      if (terrain === 'rift' && cell.well && target?.owner !== state.turn && target) value -= 10;
      if (terrain === 'bloom' && target?.owner === state.turn && target.hp < target.maxHp) value += 4;
      if (terrain === 'steam' && target?.owner === state.turn && enemies.some((enemy) => distance(enemy, cell) <= 2)) value += 3;
      if (cell.terrain === 'rift' && cell.well && target?.owner !== state.turn && target && terrain !== 'rift') value += 4;
      if (cell.terrain === 'rift' && cell.well && target?.owner === state.turn && terrain !== 'rift') value -= 8;
      // Prepare a reaction only when a second allied element can reach this cell.
      if (target?.owner === state.turn && cell.well && terrain === element && cell.terrain !== element) {
        const partner = friendly.find((ally) => !ally.cast && ally.id !== unit.id && distance(ally, cell) <= CAST_RANGE && REACTIONS.some((reaction) => reaction.elements.includes(element) && reaction.elements.includes(getChampion(ally.championId).element)));
        if (partner) value += 1;
      }
      if (value > bestValue) { bestValue = value; best = { type: 'cast', unitId: unit.id, q: cell.q, r: cell.r }; }
    }
  }
  return best;
}
