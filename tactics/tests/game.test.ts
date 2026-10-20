import test from 'node:test';
import assert from 'node:assert/strict';
import { CHAMPIONS, MAX_ROUNDS, RULES_VERSION, applyAction, chooseAIAction, createGame as createOpeningGame, distance, getCell, isAlive, legalTargets, movementPath, previewAction, previewPush, resultingTerrain } from '../lib/game.ts';
import type { GameAction, GameState, Unit } from '../lib/game.ts';

// Focused interaction fixtures model a standard two-action turn. The compensated
// opening and complete AI games below use the unmodified createOpeningGame.
function createGame(rosters?: [string[], string[]], mapId?: string): GameState {
  const state = createOpeningGame(rosters, mapId);
  state.ap = 2;
  return state;
}

const end = (state: GameState) => applyAction(state, state.turn, { type: 'end' });
const relocate = (unit: Unit, q: number, r: number) => { unit.q = q; unit.r = r; };
const action = (type: 'move' | 'cast', unit: Unit, q: number, r: number): GameAction => ({ type, unitId: unit.id, q, r });
function assertUnchangedAfterError(state: GameState, command: GameAction, player = state.turn) {
  const before = JSON.stringify(state);
  assert.throws(() => applyAction(state, player, command));
  assert.equal(JSON.stringify(state), before);
}

test('canonical roster, 37-hex map, three wells, mirrored full-health deployment', () => {
  const state = createOpeningGame();
  assert.equal(CHAMPIONS.length, 6);
  assert.equal(state.cells.length, 37);
  assert.equal(state.cells.filter((cell) => cell.well).length, 3);
  assert.equal(new Set(state.cells.map((cell) => `${cell.q},${cell.r}`)).size, 37);
  for (const unit of state.units.filter((unit) => unit.owner === 0)) {
    const mirror = state.units.find((candidate) => candidate.owner === 1 && candidate.championId === unit.championId)!;
    assert.equal(unit.q, -mirror.q);
    assert.ok(unit.r === -mirror.r);
    assert.equal(unit.hp, 5);
  }
  assert.deepEqual(state.scores, [0, 0]);
  assert.equal(state.ap, 1);
  assert.equal(state.rulesVersion, RULES_VERSION);
});

test('only the starting player’s first turn has one action; subsequent turns always have two', () => {
  for (const firstAction of ['move', 'cast', 'guard'] as const) {
    let state = createOpeningGame();
    assert.match(state.log[0], /opens with 1 action to offset moving first/);
    state = applyAction(state, 0, firstAction === 'guard' ? { type: 'guard', unitId: state.units[0].id } : action(firstAction, state.units[0], -2, 0));
    assert.equal(state.turn, 1); assert.equal(state.round, 1); assert.equal(state.ap, 2);
    state = end(state);
    assert.equal(state.turn, 0); assert.equal(state.round, 2); assert.equal(state.ap, 2);
    state = end(state);
    assert.equal(state.turn, 1); assert.equal(state.ap, 2);
  }
});

test('v2 never silently reinterprets a legacy saved match', () => {
  const state = createGame(); delete state.rulesVersion;
  assertUnchangedAfterError(state, { type: 'end' });
  assert.deepEqual(legalTargets(state, state.units[0].id, 'move'), []);
});

test('drafts reject duplicate, unknown, malformed or wrong-sized squads and maps', () => {
  const good = ['oh_tipi', 'wa_bidi', 'haara'];
  assert.throws(() => createGame([good, ['oh_tipi', 'oh_tipi', 'haara']]));
  assert.throws(() => createGame([good, ['oh_tipi', 'wa_bidi', 'unknown']]));
  assert.throws(() => createGame([good, []]));
  assert.throws(() => createGame(null as never));
  assert.throws(() => createGame(undefined, 'missing'));
  assert.equal(createGame([good, good]).units.length, 6);
});

test('range uses axial hex distance and valid movement can turn around an obstruction', () => {
  assert.equal(distance({ q: -1, r: 1 }, { q: 1, r: -1 }), 2);
  assert.equal(distance({ q: 0, r: 0 }, { q: 1, r: 1 }), 2);
  const state = createGame();
  const unit = state.units[0];
  relocate(unit, 0, 0);
  getCell(state, 1, 0)!.terrain = 'wall';
  assert.equal(movementPath(state, unit, { q: 2, r: 0 }), null);
  const around = movementPath(state, unit, { q: 1, r: 1 });
  assert.ok(around);
  assert.equal(around.length, 2);
  assert.ok(around.every((cell) => cell.terrain !== 'wall'));
});

test('illegal player, ownership, coordinates, distance, occupancy, wall and action cannot mutate state', () => {
  const state = createGame();
  const unit = state.units[0];
  assertUnchangedAfterError(state, action('move', unit, -2, 0), 1);
  assertUnchangedAfterError(state, action('move', state.units[3], 2, 0));
  assertUnchangedAfterError(state, action('move', unit, 0, 0));
  assertUnchangedAfterError(state, action('move', unit, -3, 1));
  assertUnchangedAfterError(state, action('move', unit, -3, 0));
  assertUnchangedAfterError(state, action('cast', unit, 3, 0));
  assertUnchangedAfterError(state, action('cast', unit, 0.5, 0));
  assertUnchangedAfterError(state, action('cast', unit, NaN, 0));
  assertUnchangedAfterError(state, { type: 'teleport' } as never);
  getCell(state, -2, 0)!.terrain = 'wall';
  assertUnchangedAfterError(state, action('move', unit, -2, 0));
  assertUnchangedAfterError(state, action('cast', unit, -2, 0));
  state.ap = 0;
  assertUnchangedAfterError(state, { type: 'end' });
});

test('walls also obstruct a two-hex spell line', () => {
  const state = createGame();
  relocate(state.units[0], 0, 0);
  getCell(state, 1, 0)!.terrain = 'wall';
  assertUnchangedAfterError(state, action('cast', state.units[0], 2, 0));
  assert.ok(legalTargets(state, state.units[0].id, 'cast').some((cell) => cell.q === 1 && cell.r === 1));
});

test('actions clone state, spend one AP, limit each champion to one move and one cast', () => {
  const original = createGame();
  const before = JSON.stringify(original);
  const unit = original.units[0];
  const moved = applyAction(original, 0, action('move', unit, -1, 0));
  assert.equal(JSON.stringify(original), before);
  assert.equal(moved.ap, 1);
  assert.equal(moved.version, original.version + 1);
  assert.notEqual(moved.units[0], original.units[0]);
  assertUnchangedAfterError(moved, action('move', moved.units[0], 0, 0));
  const cast = applyAction(moved, 0, action('cast', moved.units[0], 0, 0));
  assert.equal(cast.turn, 1);
  assert.equal(cast.round, 1);
  assert.equal(cast.ap, 2);
  assert.ok(cast.units[0].cast);
  assert.ok(cast.units[0].moved);
  const once = applyAction(original, 0, action('cast', unit, -2, 0));
  assertUnchangedAfterError(once, action('cast', unit, -1, 0));
});

test('all element combinations are deterministic and symmetric, existing paired reactions refresh', () => {
  assert.equal(resultingTerrain('water', 'fire'), 'steam');
  assert.equal(resultingTerrain('fire', 'water'), 'steam');
  assert.equal(resultingTerrain('earth', 'water'), 'bloom');
  assert.equal(resultingTerrain('water', 'earth'), 'bloom');
  assert.equal(resultingTerrain('fire', 'earth'), 'glass');
  assert.equal(resultingTerrain('earth', 'fire'), 'glass');
  assert.equal(resultingTerrain('light', 'dark'), 'rift');
  assert.equal(resultingTerrain('dark', 'light'), 'rift');
  assert.equal(resultingTerrain('steam', 'fire'), 'steam');
  assert.equal(resultingTerrain('bloom', 'air'), 'air');
});

test('Steam reduces damage immediately on creation and on a later incoming spell', () => {
  const state = createGame();
  const caster = state.units[1];
  const enemy = state.units[3];
  relocate(caster, -1, 0); relocate(enemy, 0, 0);
  getCell(state, 0, 0)!.terrain = 'water';
  const first = applyAction(state, 0, action('cast', caster, 0, 0));
  assert.equal(first.units[3].hp, 4);
  assert.equal(getCell(first, 0, 0)!.terrain, 'steam');
  const earth = first.units[2];
  relocate(earth, -1, 1);
  const second = applyAction(first, 0, action('cast', earth, 0, 0));
  assert.equal(second.units[3].hp, 3);
  assert.equal(getCell(second, 0, 0)!.terrain, 'earth');
  assert.match(previewAction(state, action('cast', caster, 0, 0)), /1 damage/);
});

test('casts on allies do no friendly damage; Bloom heals only at their turn start and caps HP', () => {
  const state = createGame();
  const water = state.units[0];
  relocate(water, -1, 0);
  const friend = state.units[1];
  relocate(friend, 0, 0); friend.hp = 4;
  getCell(state, 0, 0)!.terrain = 'earth';
  let next = applyAction(state, 0, action('cast', water, 0, 0));
  assert.equal(next.units[1].hp, 4);
  assert.equal(getCell(next, 0, 0)!.terrain, 'bloom');
  next = end(next); next = end(next);
  assert.equal(next.turn, 0);
  assert.equal(next.units[1].hp, 5);
});

test('an opponent can complete your elemental reaction and their Bloom still heals your occupant', () => {
  let state = createGame();
  relocate(state.units[2], -1, 0); // Friendly Earth sets up the well.
  relocate(state.units[1], 0, 0); state.units[1].hp = 3;
  relocate(state.units[3], 1, 0); // Opposing Water can use that Earth.
  state = applyAction(state, 0, action('cast', state.units[2], 0, 0));
  assert.equal(getCell(state, 0, 0)!.terrain, 'earth');
  state = end(state);
  state = applyAction(state, 1, action('cast', state.units[3], 0, 0));
  assert.equal(getCell(state, 0, 0)!.terrain, 'bloom');
  assert.equal(state.units[1].hp, 1);
  state = end(state); // Round two begins with Player 1; the response window is over.
  assert.equal(state.turn, 0);
  assert.equal(state.units[1].hp, 2, 'Terrain benefits its occupant, regardless of who created it');
});

test('an enemy-created Rift rewards the well occupant rather than the caster', () => {
  let state = createGame([['haara', 'oh_tipi', 'wa_bidi'], ['s_wayne', 'oh_tipi', 'wa_bidi']]);
  relocate(state.units[0], -1, 0);
  relocate(state.units[1], 0, 0);
  relocate(state.units[3], 1, 0);
  state = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  state = end(state);
  state = applyAction(state, 1, action('cast', state.units[3], 0, 0));
  assert.equal(getCell(state, 0, 0)!.terrain, 'rift');
  assert.equal(state.units[1].hp, 3);
  state = end(state);
  assert.deepEqual(state.scores, [2, 0]);
});

test('Air displaces enemies, Glass landing can defeat, and awards exactly one point', () => {
  const state = createGame([['grace_reava', 'wa_bidi', 'haara'], ['oh_tipi', 'treevor_mason', 's_wayne']]);
  const air = state.units[0]; const enemy = state.units[3];
  relocate(air, -1, 0); relocate(enemy, 0, 0); enemy.hp = 2;
  getCell(state, 1, 0)!.terrain = 'glass';
  getCell(state, 1, 0)!.ttl = 2;
  const preview = previewAction(state, action('cast', air, 0, 0));
  assert.match(preview, /Push to 1, 0/);
  assert.match(preview, /Glass deals 1 more damage/);
  assert.match(preview, /Defeated: Player 1 gains 1 point/);
  const next = applyAction(state, 0, action('cast', air, 0, 0));
  assert.equal(next.units[3].q, 1);
  assert.equal(next.units[3].hp, 0);
  assert.equal(next.units[3].respawn, 1);
  assert.deepEqual(next.scores, [1, 0]);
  assert.equal(legalTargets(next, enemy.id, 'move').length, 0);
});

test('Air cannot push through another champion, wall or board edge', () => {
  for (const obstruction of ['unit', 'wall', 'edge']) {
    const state = createGame([['grace_reava', 'wa_bidi', 'haara'], ['oh_tipi', 'treevor_mason', 's_wayne']]);
    const air = state.units[0]; const enemy = state.units[3];
    relocate(air, obstruction === 'edge' ? 1 : -1, 0);
    relocate(enemy, obstruction === 'edge' ? 3 : 0, 0);
    if (obstruction === 'unit') relocate(state.units[4], 1, 0);
    if (obstruction === 'wall') getCell(state, 1, 0)!.terrain = 'wall';
    const next = applyAction(state, 0, action('cast', air, enemy.q, enemy.r));
    assert.equal(next.units[3].q, enemy.q);
    assert.equal(next.units[3].hp, 4);
  }
});

test('a mirrored adjacent Air push has the same Glass damage and defeat outcome for both seats', () => {
  const roster = ['grace_reava', 'wa_bidi', 'haara'];
  for (const owner of [0, 1] as const) {
    const state = createGame([roster, roster]);
    state.turn = owner; state.initiative = owner;
    const sign = owner === 0 ? 1 : -1;
    const caster = state.units[owner * 3];
    const target = state.units[(1 - owner) * 3];
    relocate(caster, -sign, 0); relocate(target, 0, 0); target.hp = 2;
    getCell(state, sign, 0)!.terrain = 'glass';
    const next = applyAction(state, owner, action('cast', caster, 0, 0));
    const victim = next.units.find((unit) => unit.id === target.id)!;
    assert.equal(victim.q, sign); assert.equal(victim.r, 0);
    assert.equal(victim.hp, 0);
    assert.equal(next.scores[owner], 1);
    assert.equal(next.scores[(1 - owner) as 0 | 1], 0);
  }
});

test('Air at range two damages but cannot push; both mirrored seats get the same preview and outcome', () => {
  const roster = ['grace_reava', 'wa_bidi', 'haara'];
  for (const owner of [0, 1] as const) {
    const state = createGame([roster, roster]); state.turn = owner;
    const sign = owner === 0 ? 1 : -1;
    const caster = state.units[owner * 3]; const target = state.units[(1 - owner) * 3];
    relocate(caster, -sign, -sign); relocate(target, 0, 0); target.hp = 2;
    getCell(state, sign, 0)!.terrain = 'glass';
    assert.equal(previewPush(state, caster.id, 0, 0), undefined);
    assert.match(previewAction(state, action('cast', caster, 0, 0)), /Range 2: damage only; push requires adjacency/);
    const next = applyAction(state, owner, action('cast', caster, 0, 0));
    const victim = next.units.find((unit) => unit.id === target.id)!;
    assert.equal(victim.q, 0); assert.equal(victim.r, 0); assert.equal(victim.hp, 1);
    assert.equal(next.scores[owner], 0);
  }
});

test('Glass damages on landing, not on crossing, with no repeated defeat scoring', () => {
  const state = createGame();
  const unit = state.units[0];
  getCell(state, -2, 0)!.terrain = 'glass';
  let next = applyAction(state, 0, action('move', unit, -1, 0));
  assert.equal(next.units[0].hp, 5);
  unit.hp = 1;
  assert.match(previewAction(state, action('move', unit, -2, 0)), /Defeated: Player 2 gains 1 point/);
  next = applyAction(state, 0, action('move', unit, -2, 0));
  assert.equal(next.units[0].hp, 0);
  assert.deepEqual(next.scores, [0, 1]);
  assertUnchangedAfterError(next, action('cast', next.units[0], -1, 0));
});

test('respawn waits for owner turn, chooses unoccupied space and clears the landing hazard', () => {
  const state = createGame();
  const enemy = state.units[3];
  enemy.hp = 0; enemy.respawn = 1;
  getCell(state, 3, 0)!.terrain = 'glass';
  getCell(state, 3, 0)!.ttl = 2;
  assert.equal(isAlive(enemy), false);
  const next = end(state);
  assert.equal(next.turn, 1);
  assert.equal(next.units[3].hp, 5);
  assert.equal(next.units[3].respawn, undefined);
  const positions = next.units.filter(isAlive).map((unit) => `${unit.q},${unit.r}`);
  assert.equal(new Set(positions).size, positions.length);
  assert.equal(getCell(next, next.units[3].q, next.units[3].r)!.terrain, 'plain');
});

test('completely occupied home edge cannot stack or prevent a safe fallback respawn', () => {
  const state = createGame();
  state.turn = 1; state.initiative = 1;
  state.units[0].hp = 0; state.units[0].respawn = 1;
  for (let index = 1; index <= 4; index++) relocate(state.units[index], -3, index - 1);
  const next = end(state);
  assert.equal(next.turn, 0);
  assert.ok(isAlive(next.units[0]));
  assert.notEqual(next.units[0].q, -3);
  const positions = next.units.filter(isAlive).map((unit) => `${unit.q},${unit.r}`);
  assert.equal(new Set(positions).size, positions.length);
});

test('a forced fallback respawn onto a well cannot score without surviving a response', () => {
  const state = createGame();
  state.turn = 1; state.turnsTaken = 1;
  state.units[0].hp = 0; state.units[0].respawn = 1;
  for (const cell of state.cells) cell.terrain = 'wall';
  getCell(state, 0, 0)!.terrain = 'plain';
  let next = end(state);
  assert.equal(next.turn, 0); assert.equal(next.units[0].q, 0); assert.equal(next.units[0].r, 0);
  assert.equal(next.scores[0], 0, 'respawn itself must not grant a held-well point');
  next = end(end(next));
  assert.equal(next.scores[0], 1, 'surviving the next opponent response makes the well eligible');
});

test('wells score at owner-turn start, Rift doubles them, and surfaces expire symmetrically per turn', () => {
  const state = createGame();
  relocate(state.units[0], 0, 0);
  relocate(state.units[3], 0, -2);
  getCell(state, 0, 0)!.terrain = 'rift'; getCell(state, 0, 0)!.ttl = 4;
  const first = end(state);
  assert.deepEqual(first.scores, [0, 1]);
  assert.equal(first.round, 1); assert.equal(first.turn, 1);
  const second = end(first);
  assert.deepEqual(second.scores, [2, 1]);
  assert.equal(second.round, 2); assert.equal(second.turn, 0);
  assert.equal(getCell(second, 0, 0)!.ttl, 2);
  const third = end(second);
  assert.deepEqual(third.scores, [2, 2]); assert.equal(third.turn, 1);
  const fourth = end(third);
  assert.deepEqual(fourth.scores, [3, 2]);
  assert.equal(fourth.round, 3); assert.equal(fourth.turn, 0);
  assert.equal(getCell(fourth, 0, 0)!.terrain, 'plain');
  assert.equal(getCell(fourth, 0, 0)!.ttl, undefined);
});

test('turns always alternate, including round boundaries, and reset only the incoming player’s limits', () => {
  let state = createGame();
  state = applyAction(state, 0, action('move', state.units[0], -1, 0));
  state = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(state.turn, 1);
  assert.match(previewAction(state, { type: 'end' }), /both players have acted, so victory is checked/);
  state = applyAction(state, 1, action('move', state.units[3], 1, 0));
  state = applyAction(state, 1, action('cast', state.units[3], 0, 0));
  assert.equal(state.turn, 0); assert.equal(state.round, 2); assert.equal(state.ap, 2);
  assert.equal(state.units[0].moved, false); assert.equal(state.units[0].cast, false);
  assert.equal(state.units[3].moved, true); assert.equal(state.units[3].cast, true);
  assert.match(state.log.at(-1)!, /Both players have acted/);
  assert.match(previewAction(state, { type: 'end' }), /Player 2 scores their held wells/);
  state = applyAction(state, 0, action('move', state.units[0], 0, 0));
  assert.equal(state.ap, 1);
  assertUnchangedAfterError(state, action('move', state.units[0], 0, -1));
});

test('hitting eight during first turn does not end match before equal opportunity', () => {
  const state = createGame();
  state.scores = [7, 7];
  relocate(state.units[0], -1, 0); relocate(state.units[3], 0, 0);
  state.units[3].hp = 2;
  let next = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(next.scores[0], 8); assert.equal(next.winner, null);
  next = end(next);
  assert.equal(next.turn, 1); assert.equal(next.winner, null);
  next = end(next);
  assert.equal(next.winner, 0);
  assertUnchangedAfterError(next, { type: 'end' });
});

test('a tied eight-point score continues, round sixteen resolves a tie as a draw', () => {
  const state = createGame(); state.scores = [8, 8];
  const next = end(end(state));
  assert.equal(next.round, 2); assert.equal(next.winner, null);
  next.round = MAX_ROUNDS;
  const draw = end(end(next));
  assert.equal(draw.winner, 'draw'); assert.equal(draw.ap, 0);
  const other = createGame(); other.round = MAX_ROUNDS; other.scores = [2, 3];
  assert.equal(end(end(other)).winner, 1);
});

test('both seats must survive an opponent response before a newly occupied well scores', () => {
  const roster = ['grace_reava', 'oh_tipi', 'treevor_mason'];
  for (const owner of [0, 1] as const) {
    let state = createGame([roster, roster]);
    if (owner === 1) state = end(state);
    const capturer = state.units[owner * 3 + 1];
    const defender = state.units[(1 - owner) * 3];
    relocate(capturer, -1, 0); relocate(defender, 1, 0);
    state = applyAction(state, owner, action('move', capturer, 0, 0));
    assert.equal(state.scores[owner], 0, 'capture itself grants no points');
    state = end(state);
    assert.equal(state.scores[owner], 0, 'opponent gets a response before scoring');
    state = applyAction(state, state.turn, action('cast', defender, 0, 0));
    state = end(state);
    assert.equal(state.turn, owner);
    assert.equal(state.scores[owner], 0, 'displacing a champion denies the held-well point');
  }
});

test('start-turn threshold crossings wait for equal completed turns and can become a tie', () => {
  let state = createGame();
  state.round = 2; state.scores = [8, 7]; // Player 1 has just scored at turn start.
  relocate(state.units[3], 0, 2);
  state = end(state);
  assert.deepEqual(state.scores, [8, 8]);
  assert.equal(state.winner, null);
  state = end(state);
  assert.equal(state.round, 3); assert.equal(state.winner, null);
});

test('Guard spends the cast allowance, allows movement, and expires before the next friendly turn', () => {
  let state = createGame(); const id = state.units[0].id;
  assert.deepEqual(legalTargets(state, id, 'guard').map(({ q, r }) => ({ q, r })), [{ q: -3, r: 0 }]);
  state = applyAction(state, 0, { type: 'guard', unitId: id });
  assert.equal(state.ap, 1); assert.equal(state.units[0].guard, true);
  assertUnchangedAfterError(state, { type: 'guard', unitId: id });
  assertUnchangedAfterError(state, { type: 'cast', unitId: id, q: -2, r: 0 });
  state = applyAction(state, 0, { type: 'move', unitId: id, q: -1, r: 0 });
  assert.equal(state.turn, 1); assert.equal(state.units[0].guard, true);
  state = end(state);
  assert.equal(state.turn, 0); assert.equal(state.units[0].guard, undefined);
  assert.equal(state.units[0].cast, false);
});

test('Guard consumes even a zero-damage Air hit and blocks that displacement', () => {
  let state = createGame([['oh_tipi', 'wa_bidi', 'treevor_mason'], ['grace_reava', 'oh_tipi', 's_wayne']]);
  relocate(state.units[0], 0, 0); relocate(state.units[3], 1, 0);
  state = applyAction(state, 0, { type: 'guard', unitId: state.units[0].id });
  state = end(state);
  assert.equal(previewPush(state, state.units[3].id, 0, 0), undefined);
  assert.match(previewAction(state, action('cast', state.units[3], 0, 0)), /0 damage.*Guard reduces damage by 1/);
  state = applyAction(state, 1, action('cast', state.units[3], 0, 0));
  assert.equal(state.units[0].hp, 5); assert.equal(state.units[0].guard, undefined);
  assert.equal(state.units[0].q, 0); assert.equal(state.units[0].r, 0);
});

test('a first attacker can strip Guard so a second attacker can push', () => {
  let state = createGame([['oh_tipi', 'wa_bidi', 'treevor_mason'], ['grace_reava', 'oh_tipi', 's_wayne']]);
  relocate(state.units[0], 0, 0); relocate(state.units[3], 1, 0); relocate(state.units[4], 1, -1);
  state = applyAction(state, 0, { type: 'guard', unitId: state.units[0].id }); state = end(state);
  state = applyAction(state, 1, action('cast', state.units[4], 0, 0));
  assert.equal(state.units[0].hp, 4); assert.equal(state.units[0].guard, undefined);
  assert.equal(previewPush(state, state.units[3].id, 0, 0)?.q, -1);
  state = applyAction(state, 1, action('cast', state.units[3], 0, 0));
  assert.equal(state.units[0].hp, 3); assert.equal(state.units[0].q, -1);
  assert.equal(state.scores[0], 0);
});

test('Steam and Guard stack to zero without healing the target or preserving Guard', () => {
  let state = createGame(); relocate(state.units[0], 0, 0); relocate(state.units[4], 1, 0);
  getCell(state, 0, 0)!.terrain = 'steam'; getCell(state, 0, 0)!.ttl = 4;
  state = applyAction(state, 0, { type: 'guard', unitId: state.units[0].id }); state = end(state);
  assert.match(previewAction(state, action('cast', state.units[4], 0, 0)), /0 damage/);
  state = applyAction(state, 1, action('cast', state.units[4], 0, 0));
  assert.equal(state.units[0].hp, 5); assert.equal(state.units[0].guard, undefined);
});

test('Light heals allies or self by up to two, does not consume allied Guard, and hits enemies for one', () => {
  const roster = ['haara', 'oh_tipi', 'wa_bidi'];
  let state = createGame([roster, roster]);
  relocate(state.units[0], -1, 0); relocate(state.units[1], 0, 0); state.units[1].hp = 2;
  state = applyAction(state, 0, { type: 'guard', unitId: state.units[1].id });
  assert.match(previewAction(state, action('cast', state.units[0], 0, 0)), /Heal Oh Tipi by 2/);
  state = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(state.units[1].hp, 4); assert.equal(state.units[1].guard, true);
  const self = createGame([roster, roster]); self.units[0].hp = 4;
  assert.equal(applyAction(self, 0, action('cast', self.units[0], -3, 0)).units[0].hp, 5);
  relocate(self.units[3], -1, 0);
  assert.equal(applyAction(self, 0, action('cast', self.units[0], -1, 0)).units[3].hp, 4);
});

test('Dark deals two and siphons only from an enemy already on Dark when damage lands', () => {
  const roster = ['s_wayne', 'oh_tipi', 'wa_bidi'];
  const state = createGame([roster, roster]);
  relocate(state.units[0], -1, 0); relocate(state.units[3], 0, 0); state.units[0].hp = 2;
  let next = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(next.units[3].hp, 3); assert.equal(next.units[0].hp, 2, 'laying fresh Dark does not siphon');
  assert.doesNotMatch(previewAction(state, action('cast', state.units[0], 0, 0)), /Siphon heals/);
  getCell(state, 0, 0)!.terrain = 'dark';
  assert.match(previewAction(state, action('cast', state.units[0], 0, 0)), /Siphon heals the caster by 1/);
  next = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(next.units[3].hp, 3); assert.equal(next.units[0].hp, 3);
  state.units[3].guard = true;
  next = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(next.units[3].hp, 4); assert.equal(next.units[0].hp, 3, 'one actual damage through Guard still siphons');
  getCell(state, 0, 0)!.terrain = 'steam';
  assert.doesNotMatch(previewAction(state, action('cast', state.units[0], 0, 0)), /Siphon heals/);
  next = applyAction(state, 0, action('cast', state.units[0], 0, 0));
  assert.equal(next.units[3].hp, 5); assert.equal(next.units[0].hp, 2);
});

test('bounded AI always returns legal actions and deterministic matches terminate', () => {
  const rosterA = ['oh_tipi', 'wa_bidi', 'treevor_mason'];
  const rosterB = ['grace_reava', 'haara', 's_wayne'];
  const simulate = () => {
    let state = createOpeningGame([rosterA, rosterB]);
    let actions = 0;
    while (state.winner === null && actions < MAX_ROUNDS * 4 + 1) {
      const before = JSON.stringify(state);
      const command = chooseAIAction(state);
      assert.equal(JSON.stringify(state), before);
      state = applyAction(state, state.turn, command);
      for (const unit of state.units) {
        assert.ok(unit.hp >= 0 && unit.hp <= unit.maxHp);
        assert.ok(getCell(state, unit.q, unit.r));
      }
      const alive = state.units.filter(isAlive);
      assert.equal(new Set(alive.map((unit) => `${unit.q},${unit.r}`)).size, alive.length);
      assert.ok(state.scores.every((score) => score >= 0));
      actions++;
    }
    assert.notEqual(state.winner, null);
    return state;
  };
  assert.deepEqual(simulate(), simulate());
});
