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
  /** One-hit brace: absorbs 1 spell damage and blocks that hit's push. */
  guard?: boolean;
  /** A defeated champion returns at the beginning of its owner's next turn. */
  respawn?: number;
};
export type GameState = {
  /** Missing means an archived v1 match; dispatch that state through game-v1.ts. */
  rulesVersion?: 2;
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
  type: 'move' | 'cast' | 'guard' | 'end';
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
export const RULES_VERSION = 2;
export const MOVE_RANGE = 2;
export const CAST_RANGE = 2;
export const POINTS_TO_WIN = 8;
export const MAX_ROUNDS = 16;
export const ACTIONS_PER_TURN = 2;
export const OPENING_ACTIONS = 1;
export const MAPS = [{ id: 'confluence', name: 'The Confluence', description: 'Three wells. One shifting battlefield.' }];

export const ELEMENTS: { id: Element; name: string; color: string; symbol: string; description: string }[] = [
  { id: 'water', name: 'Water', color: '#52bdf4', symbol: '≈', description: 'Combine with Fire for Steam cover, or Earth for healing Bloom.' },
  { id: 'fire', name: 'Fire', color: '#ff865f', symbol: '◆', description: 'Combine with Water for Steam cover, or Earth for dangerous Glass.' },
  { id: 'air', name: 'Air', color: '#b8e9e4', symbol: '↝', description: 'Deal 1 damage. Adjacent enemies are pushed one hex; Guard blocks the push.' },
  { id: 'earth', name: 'Earth', color: '#bbd78a', symbol: '⬡', description: 'Combine with Water for healing Bloom, or Fire for dangerous Glass.' },
  { id: 'light', name: 'Light', color: '#ffe9a5', symbol: '✦', description: 'Heal an ally or yourself by 2, or hit an enemy for 1. Combine with Dark for Rift.' },
  { id: 'dark', name: 'Dark', color: '#bc9af4', symbol: '☾', description: 'Hit for 2. Heal yourself by 1 if damage lands on an enemy already standing on Dark. Combine with Light for Rift.' },
];

export const REACTIONS: { id: string; name: string; elements: [Element, Element]; color: string; symbol: string; description: string }[] = [
  { id: 'steam', name: 'Steam', elements: ['fire', 'water'], color: '#9bcad4', symbol: '≋', description: 'A champion standing here takes 1 less spell damage.' },
  { id: 'bloom', name: 'Bloom', elements: ['water', 'earth'], color: '#ace59d', symbol: '✿', description: 'Heal the occupant by 1 at the start of their turn.' },
  { id: 'glass', name: 'Glass', elements: ['fire', 'earth'], color: '#f5ab86', symbol: '◇', description: 'Deal 1 damage when a champion lands here, including a push.' },
  { id: 'rift', name: 'Rift', elements: ['light', 'dark'], color: '#d9b1ff', symbol: '◈', description: 'An occupied well here scores 2 instead of 1 at its owner’s turn start.' },
];

export const CHAMPIONS: Champion[] = [
  { id: 'oh_tipi', name: 'Oh Tipi', element: 'water', ancestry: 'Seakin', role: 'Tide shaper', description: 'Hit 2. Water + Fire makes Steam cover; Water + Earth makes healing Bloom.', hp: 5, portrait: '/portraits/oh_tipi.webp' },
  { id: 'wa_bidi', name: 'Wa Bidi', element: 'fire', ancestry: 'Goblin', role: 'Spark keeper', description: 'Hit 2. Fire + Water makes Steam cover; Fire + Earth makes Glass hazards.', hp: 5, portrait: '/portraits/wa_bidi.webp' },
  { id: 'grace_reava', name: 'Grace Riva', element: 'air', ancestry: 'Sylph', role: 'Wind dancer', description: 'Hit 1. Push only adjacent enemies one hex; Guard stops the push and Glass punishes the landing.', hp: 5, portrait: '/portraits/grace_reava.webp' },
  { id: 'treevor_mason', name: 'Treevor the Mason', element: 'earth', ancestry: 'Treefolk', role: 'Living mason', description: 'Hit 2. Earth + Water makes healing Bloom; Earth + Fire makes Glass hazards.', hp: 5, portrait: '/portraits/treevor_mason.webp' },
  { id: 'haara', name: 'Haara', element: 'light', ancestry: 'Nymph', role: 'Dawn weaver', description: 'Heal an ally or yourself by 2, or hit an enemy for 1. Light + Dark makes Rift.', hp: 5, portrait: '/portraits/haara.webp' },
  { id: 's_wayne', name: 'S. Wayne', element: 'dark', ancestry: 'Hobbit', role: 'Dusk wanderer', description: 'Hit 2. Siphon 1 health if the enemy was already on Dark and takes damage. Dark + Light makes Rift.', hp: 5, portrait: '/portraits/s_wayne.webp' },
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
  return { rulesVersion: RULES_VERSION, version: 1, mapId, round: 1, turn: 0, initiative: 0, turnsTaken: 0, ap: OPENING_ACTIONS, scores: [0, 0], units, cells, log: ['Player 1 opens with 1 action to offset moving first. Every later turn has 2 actions. Hold wells through the opponent’s response to score at your next turn start.'], winner: null };
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

export function legalTargets(state: GameState, unitId: string, kind: 'move' | 'cast' | 'guard'): Cell[] {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (state.rulesVersion !== RULES_VERSION || !unit || !isAlive(unit) || state.winner !== null || state.ap <= 0 || unit.owner !== state.turn || (kind === 'move' ? unit.moved : unit.cast)) return [];
  if (kind === 'guard') return state.cells.filter((cell) => same(cell, unit));
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
  if (currentDistance > 1) return undefined;
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

export function baseCastDamage(element: Element): number {
  return element === 'air' || element === 'light' ? 1 : 2;
}

/** Exact incoming spell damage, including newly formed Steam and a one-hit Guard. */
export function getCastDamage(state: GameState, caster: Unit, target: Unit): number {
  const cell = getCell(state, target.q, target.r)!;
  const element = getChampion(caster.championId).element;
  const cover = cell.terrain === 'steam' || resultingTerrain(cell.terrain, element) === 'steam';
  return Math.max(0, baseCastDamage(element) - (cover ? 1 : 0) - (target.guard ? 1 : 0));
}

/** UI arrows use the same geometry, Guard and lethal-hit checks as resolution. */
export function previewPush(state: GameState, unitId: string, q: number, r: number): Cell | undefined {
  const caster = state.units.find((unit) => unit.id === unitId);
  const target = occupant(state, { q, r });
  if (!caster || !target || target.owner === caster.owner || target.guard || getChampion(caster.championId).element !== 'air'
    || target.hp <= getCastDamage(state, caster, target) || !legalTargets(state, unitId, 'cast').some((cell) => cell.q === q && cell.r === r)) return undefined;
  return pushDestination(state, caster, target);
}

function beginTurn(state: GameState, player: Player): void {
  state.turn = player;
  state.ap = ACTIONS_PER_TURN;
  const respawned = new Set<string>();
  for (const unit of state.units.filter((entry) => entry.owner === player)) {
    unit.moved = false;
    unit.cast = false;
    delete unit.guard;
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
      respawned.add(unit.id);
      // Homecoming clears lingering hazards; no damage can repeat during respawn itself.
      spawn.terrain = 'plain'; delete spawn.ttl;
      addLog(state, `${getChampion(unit.championId).name} returns at full health.`);
    }
    if (isAlive(unit) && getCell(state, unit.q, unit.r)?.terrain === 'bloom' && unit.hp < unit.maxHp) {
      unit.hp = Math.min(unit.maxHp, unit.hp + 1);
      addLog(state, `Bloom heals ${getChampion(unit.championId).name} by 1.`);
    }
  }
  let gained = 0;
  for (const cell of state.cells.filter((entry) => entry.well)) {
    const unit = occupant(state, cell);
    if (unit?.owner === player && !respawned.has(unit.id)) gained += cell.terrain === 'rift' ? 2 : 1;
  }
  state.scores[player] += gained;
  if (gained) addLog(state, `Player ${player + 1} holds through the response: +${gained} well point${gained === 1 ? '' : 's'}. Score ${state.scores[0]}–${state.scores[1]}.`);
}

function finishTurn(state: GameState): void {
  // Four player-turn endings give both seats the same surface lifetime.
  for (const cell of state.cells) {
    if (cell.ttl !== undefined) {
      cell.ttl--;
      if (cell.ttl <= 0) { cell.terrain = 'plain'; delete cell.ttl; }
    }
  }
  state.turnsTaken++;
  if (state.turnsTaken < 2) {
    beginTurn(state, opponent(state.turn));
    return;
  }
  addLog(state, `Round ${state.round} complete. Both players have acted; score ${state.scores[0]}–${state.scores[1]}.`);
  const [left, right] = state.scores;
  if ((Math.max(left, right) >= POINTS_TO_WIN && left !== right) || state.round >= MAX_ROUNDS) {
    state.winner = left === right ? 'draw' : left > right ? 0 : 1;
    state.ap = 0;
    addLog(state, state.winner === 'draw' ? 'The Confluence ends in a draw.' : `Player ${state.winner + 1} claims the Confluence.`);
    return;
  }
  state.round++;
  state.turnsTaken = 0;
  state.initiative = 0;
  beginTurn(state, 0);
}

export function applyAction(state: GameState, player: Player, action: GameAction): GameState {
  if (state.rulesVersion !== RULES_VERSION) throw new Error('This match uses different rules. Open it with its original rules engine.');
  if (state.winner !== null) throw new Error('This match has finished.');
  if ((player !== 0 && player !== 1) || player !== state.turn) throw new Error('Wait for your turn.');
  if (!action || !['move', 'cast', 'guard', 'end'].includes(action.type)) throw new Error('Unknown action.');
  if (state.ap <= 0) throw new Error('No actions remain.');
  // Validate the entire command before cloning or changing anything.
  let unit: Unit | undefined;
  let target: Cell | undefined;
  if (action.type !== 'end') {
    unit = state.units.find((entry) => entry.id === action.unitId);
    if (!unit || unit.owner !== player || !isAlive(unit)) throw new Error('Choose an active champion from your squad.');
    if (action.type !== 'guard' && (!Number.isInteger(action.q) || !Number.isInteger(action.r))) throw new Error('Choose a battlefield hex.');
    target = action.type === 'guard' ? getCell(state, unit.q, unit.r) : getCell(state, action.q!, action.r!);
    if (!target) throw new Error('That hex is outside the battlefield.');
    if (action.type === 'move' && unit.moved) throw new Error('This champion has already moved this turn.');
    if (action.type !== 'move' && unit.cast) throw new Error('This champion has already cast or guarded this turn.');
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
  if (action.type === 'guard') {
    actor.guard = true; actor.cast = true;
    addLog(next, `${champion.name} guards: the next enemy spell deals 1 less damage and cannot push.`);
  } else if (action.type === 'move') {
    actor.q = destination.q; actor.r = destination.r; actor.moved = true;
    addLog(next, `${champion.name} moves to ${destination.q}, ${destination.r}.`);
    landingDamage(next, actor);
  } else {
    actor.cast = true;
    const targetUnit = occupant(next, destination);
    const damage = targetUnit && targetUnit.owner !== player ? getCastDamage(next, actor, targetUnit) : 0;
    const guarded = Boolean(targetUnit?.guard);
    const targetHadDark = destination.terrain === 'dark';
    destination.terrain = resultingTerrain(destination.terrain, champion.element);
    destination.ttl = 4;
    addLog(next, `${champion.name} casts ${champion.element}; ${destination.terrain} at ${destination.q}, ${destination.r}.`);
    if (targetUnit && targetUnit.owner !== player) {
      if (guarded) {
        delete targetUnit.guard;
        addLog(next, `${getChampion(targetUnit.championId).name}'s Guard is spent: 1 less damage; this hit cannot push.`);
      }
      targetUnit.hp -= damage;
      addLog(next, `${getChampion(targetUnit.championId).name} takes ${damage}.`);
      defeat(next, targetUnit);
      if (champion.element === 'dark' && targetHadDark && damage > 0 && actor.hp < actor.maxHp) {
        actor.hp = Math.min(actor.maxHp, actor.hp + 1);
        addLog(next, `${champion.name} siphons 1 health.`);
      }
      if (champion.element === 'air' && !guarded && isAlive(targetUnit)) {
        const pushed = pushDestination(next, actor, targetUnit);
        if (pushed) {
          targetUnit.q = pushed.q; targetUnit.r = pushed.r;
          addLog(next, `${getChampion(targetUnit.championId).name} is pushed one hex.`);
          landingDamage(next, targetUnit);
        }
      }
    } else if (targetUnit && champion.element === 'light') {
      const healed = Math.min(2, targetUnit.maxHp - targetUnit.hp);
      targetUnit.hp += healed;
      addLog(next, `${champion.name} heals ${getChampion(targetUnit.championId).name} by ${healed}.`);
    }
  }
  next.ap--;
  if (next.ap === 0) finishTurn(next);
  return next;
}

export function previewAction(state: GameState, action: GameAction): string {
  if (action.type === 'end') return state.turnsTaken === 0
    ? `End your turn. Player ${opponent(state.turn) + 1} scores their held wells, then takes 2 actions. Victory waits until both players finish this round.`
    : `End round ${state.round}: both players have acted, so victory is checked. If play continues, Player 1 scores held wells and opens round ${state.round + 1}.`;
  const unit = state.units.find((entry) => entry.id === action.unitId);
  if (action.type === 'guard') return unit
    ? `Guard ${getChampion(unit.championId).name}: spend 1 action and this champion’s cast. Their next enemy spell hit deals 1 less damage and cannot push. Consumed by that hit; otherwise expires at your next turn.`
    : 'Choose a champion to guard.';
  const cell = getCell(state, action.q ?? NaN, action.r ?? NaN);
  if (!unit || !cell) return 'Choose a highlighted hex.';
  const champion = getChampion(unit.championId);
  if (action.type === 'move') {
    const lethal = cell.terrain === 'glass' && unit.hp <= 1;
    return `Move ${champion.name} to ${cell.q}, ${cell.r}.${cell.well && !lethal ? ' Hold this well through the opponent’s response to score at your next turn start.' : ''}${cell.terrain === 'glass' ? ' Landing on Glass deals 1 damage.' : ''}${lethal ? ` Defeated: Player ${opponent(unit.owner) + 1} gains 1 point; return next friendly turn.` : ''}`;
  }
  const terrain = resultingTerrain(cell.terrain, champion.element);
  const target = occupant(state, cell);
  const enemy = target && target.owner !== unit.owner ? target : undefined;
  const damage = enemy ? getCastDamage(state, unit, enemy) : 0;
  const healing = target && !enemy && champion.element === 'light' ? Math.min(2, target.maxHp - target.hp) : 0;
  const hit = enemy ? `${damage} damage to ${getChampion(enemy.championId).name}. ` : target && champion.element === 'light' ? `Heal ${getChampion(target.championId).name} by ${healing}. ` : 'No friendly damage. ';
  const guard = enemy?.guard ? 'Guard reduces damage by 1, blocks this hit’s push, and is consumed. ' : '';
  const siphon = enemy && champion.element === 'dark' && cell.terrain === 'dark' && damage > 0 && unit.hp < unit.maxHp ? 'Siphon heals the caster by 1. ' : '';
  const reaction = REACTIONS.find((entry) => entry.id === terrain);
  const pushed = previewPush(state, unit.id, cell.q, cell.r);
  const glassDamage = pushed?.terrain === 'glass' ? 1 : 0;
  const push = pushed ? `Push to ${pushed.q}, ${pushed.r}.${glassDamage ? ' Glass deals 1 more damage.' : ''} ` : champion.element === 'air' && enemy && !enemy.guard && enemy.hp > damage ? distance(unit, enemy) > 1 ? 'Range 2: damage only; push requires adjacency. ' : 'Push blocked. ' : '';
  const lethal = enemy && enemy.hp <= damage + glassDamage ? `Defeated: Player ${unit.owner + 1} gains 1 point; return next friendly turn. ` : '';
  return `${hit}${guard}${push}${siphon}${lethal}Create ${reaction?.name ?? ELEMENTS.find((entry) => entry.id === terrain)?.name ?? terrain}.${reaction ? ` ${reaction.description}` : ''} Fades after 4 turn endings.`;
}

/** A bounded, deterministic opponent: enumerate at most 225 actions, with no recursion. */
export function chooseAIAction(state: GameState): GameAction {
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null || state.ap <= 0) return { type: 'end' };
  let best: GameAction = { type: 'end' };
  let bestValue = 0;
  const friendly = state.units.filter((unit) => unit.owner === state.turn && isAlive(unit));
  const enemies = state.units.filter((unit) => unit.owner !== state.turn && isAlive(unit));
  const wells = state.cells.filter((cell) => cell.well);
  // Use each side's own coordinate orientation so exact ties do not favor one edge.
  const perspective = state.turn === 0 ? 1 : -1;
  const ordered = (cells: Cell[]) => cells.sort((a, b) => perspective * (a.q - b.q || a.r - b.r));
  for (const unit of friendly) {
    if (legalTargets(state, unit.id, 'guard').length) {
      const threats = enemies.filter((enemy) => distance(enemy, unit) <= CAST_RANGE);
      const onWell = getCell(state, unit.q, unit.r)!.well;
      let value = threats.length ? (onWell ? 4 : 0) + (unit.hp <= 2 ? 3 : 0) : 0;
      if (onWell && threats.some((enemy) => getChampion(enemy.championId).element === 'air')) value += 5;
      if (value > bestValue) { bestValue = value; best = { type: 'guard', unitId: unit.id }; }
    }
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
      const damage = target && target.owner !== state.turn ? getCastDamage(state, unit, target) : 0;
      let value = 0;
      if (target && target.owner !== state.turn) {
        value += damage * 3 + (target.hp <= damage ? 18 : 0) + (cell.well ? 2 : 0);
        if (target.guard) value += 1;
        if (element === 'dark' && cell.terrain === 'dark' && damage > 0 && unit.hp < unit.maxHp) value += 3;
        if (element === 'air' && !target.guard && target.hp > damage) {
          const pushed = pushDestination(state, unit, target);
          if (pushed) value += (cell.well ? 10 : 0) + (pushed.terrain === 'glass' ? 4 : 0) - (pushed.well ? 6 : 0);
        }
      }
      if (element === 'light' && target?.owner === state.turn) value += Math.min(2, target.maxHp - target.hp) * 4;
      if (terrain === 'rift' && cell.well && target?.owner === state.turn && (cell.terrain !== 'rift' || (cell.ttl ?? 0) <= 2)) value += 10;
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
