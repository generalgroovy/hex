import test from 'node:test';
import assert from 'node:assert/strict';
import { CHAMPIONS, MAX_ROUNDS, chooseAIPlan, createSimGame, getCell, isAlive, legalCasts, legalMoves, movementCost, previewPlan, reactionsFor, resolveRound, restoreSimState, validatePlan } from '../lib/sim.ts';
import type { Element, Order, Player, Point, SimState, SimUnit, TeamPlan } from '../lib/sim.ts';

const empty = (): TeamPlan => ({ orders: [] });
const plan = (...orders: Order[]): TeamPlan => ({ orders });
const at = (unit: SimUnit, q: number, r: number) => { unit.q = q; unit.r = r; };
const cast = (unit: SimUnit, q: number, r: number): Order => ({ unitId: unit.id, cast: { q, r } });
const move = (unit: SimUnit, q: number, r: number): Order => ({ unitId: unit.id, move: { q, r } });
function surface(state: SimState, q: number, r: number, elements: Element[], ttl = 2) {
  const cell = getCell(state, q, r)!;
  const canonical: Element[] = ['fire', 'water', 'earth', 'air', 'light', 'dark'];
  cell.elements = canonical.filter((element) => elements.includes(element)); cell.reactions = reactionsFor(cell.elements);
  cell.terrain = cell.reactions[0] ?? cell.elements[0]; cell.ttl = ttl;
}
function physics(state: SimState) {
  return { version: state.version, round: state.round, scores: state.scores, winner: state.winner,
    units: [...state.units].sort((a, b) => a.id.localeCompare(b.id)), cells: [...state.cells].sort((a, b) => a.q - b.q || a.r - b.r) };
}
const invertPoint = (position: Point): Point => ({ q: -position.q || 0, r: -position.r || 0 });
const invertId = (id: string) => `${id.startsWith('0-') ? '1' : '0'}${id.slice(1)}`;
function invert(state: SimState): SimState {
  const inverted = structuredClone(state);
  inverted.units = inverted.units.map((unit) => ({ ...unit, ...invertPoint(unit), id: invertId(unit.id), owner: (1 - unit.owner) as Player }));
  inverted.cells = inverted.cells.map((cell) => ({ ...cell, ...invertPoint(cell) }));
  inverted.scores = [state.scores[1], state.scores[0]];
  inverted.winner = typeof state.winner === 'number' ? (1 - state.winner) as Player : state.winner;
  return inverted;
}
const invertPlan = (input: TeamPlan): TeamPlan => ({ orders: input.orders.map((order) => ({ ...order, unitId: invertId(order.unitId), ...(order.move ? { move: invertPoint(order.move) } : {}), ...(order.cast ? { cast: invertPoint(order.cast) } : {}) })) });

test('v3 starts with canonical champions, mirrored heights, three wells and no turn/AP priority', () => {
  const state = createSimGame();
  assert.equal(state.rulesVersion, 3); assert.equal(state.version, 1); assert.equal(state.round, 1);
  assert.equal(CHAMPIONS.length, 6); assert.equal(state.cells.length, 37);
  assert.equal(state.cells.filter((cell) => cell.height === 1).length, 4);
  assert.equal(state.cells.filter((cell) => cell.well).length, 3);
  for (const cell of state.cells) assert.equal(cell.height, getCell(state, -cell.q, -cell.r)!.height);
  assert.equal('turn' in state, false); assert.equal('ap' in state, false);
  assert.deepEqual(restoreSimState(state), state);
});

test('plan validation strictly rejects unknown fields, duplicates, foreign/dead units and invalid geometry without mutation', () => {
  const state = createSimGame(); const unit = state.units[0]; const before = JSON.stringify(state);
  const bad: unknown[] = [null, [], { orders: [], state }, { orders: [{}] }, { orders: [{ unitId: unit.id, arbitrary: 1 }] },
    plan({ unitId: unit.id }, { unitId: unit.id }), plan({ unitId: state.units[3].id }),
    plan({ unitId: unit.id, guard: false }), plan({ unitId: unit.id, guard: true, cast: { q: -2, r: 0 } }),
    plan({ unitId: unit.id, move: { q: 0, r: 0 } }), plan({ unitId: unit.id, move: { q: -3, r: 0 } }),
    plan({ unitId: unit.id, cast: { q: 3, r: 0 } }), plan({ unitId: unit.id, cast: { q: NaN, r: 0 } }),
    { orders: [{ unitId: unit.id, move: { q: -2, r: 0, z: 0 } }] }];
  for (const input of bad) assert.throws(() => validatePlan(state, 0, input));
  assert.equal(JSON.stringify(state), before);
  unit.hp = 0; unit.respawn = 3;
  assert.throws(() => validatePlan(state, 0, plan({ unitId: unit.id })));
});

test('omitted orders become Guard, inputs are canonicalized and no mutable references escape', () => {
  const state = createSimGame();
  const first = validatePlan(state, 0, empty());
  assert.equal(first.orders.length, 3); assert.ok(first.orders.every((order) => order.guard));
  assert.deepEqual(validatePlan(state, 0, { orders: [...first.orders].reverse() }), first);
  const input = plan(move(state.units[0], -2, 0));
  const normalized = validatePlan(state, 0, input);
  input.orders[0].move!.q = 3;
  assert.equal(normalized.orders.find((order) => order.unitId === state.units[0].id)!.move!.q, -2);
});

test('uphill and Quagmire each cost two effort without stacking; high ground gains range and blocks low rays', () => {
  const state = createSimGame(); const unit = state.units[0]; at(unit, -2, 0);
  assert.ok(legalMoves(state, unit.id).some((cell) => cell.q === -1 && cell.r === 0));
  assert.ok(!legalMoves(state, unit.id).some((cell) => cell.q === 0 && cell.r === 0));
  assert.ok(!legalCasts(state, unit.id).some((cell) => cell.q === 0 && cell.r === 0));
  assert.ok(legalCasts(state, unit.id, { q: -1, r: 0 }).some((cell) => cell.q === 2 && cell.r === 0));
  surface(state, -1, 0, ['earth', 'water']);
  assert.equal(movementCost(getCell(state, -2, 0)!, getCell(state, -1, 0)!), 2);
  assert.equal(movementCost(getCell(state, -1, 0)!, getCell(state, 0, 0)!), 2);
});

test('contested destinations bounce both players symmetrically', () => {
  const state = createSimGame(); at(state.units[0], -1, 0); at(state.units[3], 1, 0);
  const before = JSON.stringify(state);
  const result = resolveRound(state, [plan(move(state.units[0], 0, 0)), plan(move(state.units[3], 0, 0))]);
  assert.equal(result.units[0].q, -1); assert.equal(result.units[3].q, 1);
  assert.equal(result.lastResolution.filter((entry) => entry.kind === 'bounce').length, 2);
  assert.deepEqual(result.scores, [0, 0]); assert.equal(JSON.stringify(state), before);
});

test('simultaneous swaps succeed and blocked destination chains bounce every dependent mover', () => {
  const state = createSimGame(); at(state.units[0], -1, 0); at(state.units[3], 0, 0);
  const swapped = resolveRound(state, [plan(move(state.units[0], 0, 0)), plan(move(state.units[3], -1, 0))]);
  assert.equal(swapped.units[0].q, 0); assert.equal(swapped.units[3].q, -1);
  at(state.units[4], 1, 0);
  const blocked = resolveRound(state, [plan(move(state.units[0], 0, 0)), plan(move(state.units[3], 1, 0), move(state.units[4], 0, 0))]);
  assert.equal(blocked.units[0].q, -1); assert.equal(blocked.units[3].q, 0); assert.equal(blocked.units[4].q, 1);
});

test('ground-aimed spells miss dodging units; bounced movement can fizzle a formerly legal aim', () => {
  const state = createSimGame(); at(state.units[1], -1, 0); at(state.units[3], 0, 0);
  const dodge = resolveRound(state, [plan(cast(state.units[1], 0, 0)), plan(move(state.units[3], 0, 1))]);
  assert.equal(dodge.units[3].hp, 5); assert.equal(dodge.units[3].r, 1);
  at(state.units[1], -2, 0); at(state.units[3], 0, -1);
  const blocked = resolveRound(state, [plan({ unitId: state.units[1].id, move: { q: -1, r: 0 }, cast: { q: 2, r: 0 } }), plan(move(state.units[3], -1, 0))]);
  assert.ok(blocked.lastResolution.some((entry) => entry.kind === 'fizzle' && entry.unitId === state.units[1].id));
  assert.equal(getCell(blocked, 2, 0)!.terrain, 'plain');
});

test('simultaneous opposing Fire and Water create Steam before combined damage; friendly fire is real', () => {
  const state = createSimGame();
  at(state.units[1], -1, 0); at(state.units[2], 0, 0); at(state.units[3], 1, 0);
  const result = resolveRound(state, [plan(cast(state.units[1], 0, 0)), plan(cast(state.units[3], 0, 0))]);
  assert.equal(getCell(result, 0, 0)!.terrain, 'steam');
  assert.equal(result.units[2].hp, 4, '4 combined damage becomes 2 in Steam, then Guard absorbs 1');
  assert.ok(result.lastResolution.some((entry) => entry.kind === 'reaction' && entry.terrain === 'steam'));
});

test('three-way reactions stack and order of team order arrays never changes the result', () => {
  const state = createSimGame();
  at(state.units[1], -1, 0); at(state.units[2], -1, 1); at(state.units[3], 1, 0); at(state.units[4], 0, 0);
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[1], 0, 0), cast(state.units[2], 0, 0)), plan(cast(state.units[3], 0, 0))];
  const first = resolveRound(state, plans);
  const reversed = resolveRound(state, [{ orders: [...plans[0].orders].reverse() }, { orders: [...plans[1].orders].reverse() }]);
  assert.deepEqual(first, reversed);
  assert.deepEqual(getCell(first, 0, 0)!.reactions, ['steam', 'magma', 'quagmire']);
  assert.equal(first.units[4].hp, 2, '6 damage halves to3, Guard absorbs1, then Magma deals1');
});

test('two spells can mutually defeat their casters; each defeated champion misses one full round', () => {
  const state = createSimGame(); at(state.units[1], -1, 0); at(state.units[4], 1, 0);
  state.units[1].hp = 2; state.units[4].hp = 2;
  const round2 = resolveRound(state, [plan(cast(state.units[1], 1, 0)), plan(cast(state.units[4], -1, 0))]);
  assert.equal(round2.units[1].hp, 0); assert.equal(round2.units[4].hp, 0);
  assert.deepEqual(round2.scores, [1, 1]); assert.equal(round2.round, 2);
  assert.equal(round2.units[1].respawn, 3); assert.equal(round2.units[4].respawn, 3);
  assert.ok(!validatePlan(round2, 0, empty()).orders.some((order) => order.unitId === state.units[1].id));
  const round3 = resolveRound(round2, [empty(), empty()]);
  assert.equal(round3.units[1].hp, 5); assert.equal(round3.units[4].hp, 5);
  assert.equal(round3.units[1].respawn, undefined); assert.equal(round3.units[4].respawn, undefined);
  assert.deepEqual(round3.scores, [1, 1]);
  assert.deepEqual(restoreSimState(round3), round3);
});

test('Light healing and incoming damage are one exchange, including support at full health', () => {
  const roster = ['haara', 'wa_bidi', 'oh_tipi'];
  const state = createSimGame([roster, roster]);
  at(state.units[0], -1, 0); at(state.units[1], 0, 0); at(state.units[4], 1, 0);
  const result = resolveRound(state, [plan(cast(state.units[0], 0, 0), cast(state.units[1], 0, 1)), plan(cast(state.units[4], 0, 0))]);
  assert.equal(result.units[1].hp, 5, 'simultaneous healing offsets the incoming hit instead of being discarded as prior overheal');
});

test('Light contests enemy occupants for 2 while its friendly cast still heals 2', () => {
  const roster = ['haara', 'wa_bidi', 'oh_tipi']; const state = createSimGame([roster, roster]);
  at(state.units[0], -1, 0); at(state.units[4], 0, 0);
  const attack = resolveRound(state, [plan(cast(state.units[0], 0, 0)), plan(cast(state.units[4], 0, 2))]);
  assert.equal(attack.units[4].hp, 3);
  const guarded = resolveRound(state, [plan(cast(state.units[0], 0, 0)), empty()]);
  assert.equal(guarded.units[4].hp, 4, 'Guard still absorbs 1 from Light');
  at(state.units[1], 0, 0); at(state.units[4], 2, 0); state.units[1].hp = 2;
  const support = resolveRound(state, [plan(cast(state.units[0], 0, 0)), empty()]);
  assert.equal(support.units[1].hp, 4);
});

test('Guard blocks displacement for the complete simultaneous volley, without cast-order dependence', () => {
  const roster = ['grace_reava', 'wa_bidi', 'haara']; const state = createSimGame([roster, roster]);
  at(state.units[0], -1, 0); at(state.units[1], -1, 1); at(state.units[3], 0, 0);
  const result = resolveRound(state, [plan(cast(state.units[0], 0, 0), cast(state.units[1], 0, 0)), empty()]);
  assert.equal(result.units[3].q, 0); assert.equal(result.units[3].r, 0);
  assert.equal(result.units[3].hp, 3, 'Guard absorbs1 from total3 rather than depending on which spell arrives first');
});

test('opposing winds cancel and pushes into Magma can defeat after the exchange', () => {
  const roster = ['grace_reava', 'wa_bidi', 'haara']; const state = createSimGame([roster, roster]);
  at(state.units[0], -1, 0); at(state.units[3], 1, 0); at(state.units[1], 0, 0);
  const cancelled = resolveRound(state, [plan(cast(state.units[0], 0, 0), cast(state.units[1], 0, 2)), plan(cast(state.units[3], 0, 0))]);
  assert.equal(cancelled.units[1].q, 0); assert.equal(cancelled.units[1].hp, 3);
  assert.ok(cancelled.lastResolution.some((entry) => entry.text.includes('winds') && entry.text.includes('cancel')));
  at(state.units[3], 2, -1); at(state.units[4], 0, 0); at(state.units[1], -2, 1);
  state.units[4].hp = 2; surface(state, 1, 0, ['fire', 'earth']);
  const burned = resolveRound(state, [plan(cast(state.units[0], 0, 0)), plan(cast(state.units[4], 0, 2))]);
  assert.equal(burned.units[4].q, 1); assert.equal(burned.units[4].hp, 0);
  assert.equal(burned.scores[0], 1);
});

test('simultaneous pushes toward the same landing bounce both victims', () => {
  const roster = ['grace_reava', 'wa_bidi', 'haara']; const state = createSimGame([roster, roster]);
  at(state.units[0], -2, 0); at(state.units[1], -1, 0); at(state.units[3], 2, 0); at(state.units[4], 1, 0);
  const result = resolveRound(state, [plan(cast(state.units[0], -1, 0), cast(state.units[1], 0, 2)), plan(cast(state.units[3], 1, 0), cast(state.units[4], 0, 2))]);
  assert.equal(result.units[1].q, -1); assert.equal(result.units[4].q, 1);
  assert.equal(result.units[1].hp, 4); assert.equal(result.units[4].hp, 4);
  assert.equal(result.lastResolution.filter((entry) => entry.kind === 'bounce' && entry.text.includes('push')).length, 2);
});

test('Dark siphons only from prior Dark, and both sides receive simultaneous siphons without order bias', () => {
  const roster = ['s_wayne', 'wa_bidi', 'haara']; const state = createSimGame([roster, roster]);
  at(state.units[0], -1, 0); at(state.units[3], 1, 0); state.units[0].hp = 2; state.units[3].hp = 2;
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[0], 1, 0)), plan(cast(state.units[3], -1, 0))];
  const fresh = resolveRound(state, plans);
  assert.equal(fresh.units[0].hp, 0); assert.equal(fresh.units[3].hp, 0);
  surface(state, -1, 0, ['dark']); surface(state, 1, 0, ['dark']);
  const marked = resolveRound(state, plans);
  assert.equal(marked.units[0].hp, 1); assert.equal(marked.units[3].hp, 1);
  assert.deepEqual(marked.scores, [0, 0]);
  assert.deepEqual(physics(invert(marked)), physics(resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])])));
});

test('Penumbra doubles shared-well scoring, surfaces expire, and both teams score before victory', () => {
  const state = createSimGame(); at(state.units[0], 0, 0); at(state.units[3], 0, 2);
  surface(state, 0, 0, ['light', 'dark']);
  const first = resolveRound(state, [empty(), empty()]);
  assert.deepEqual(first.scores, [2, 1]); assert.equal(getCell(first, 0, 0)!.ttl, 1);
  const second = resolveRound(first, [empty(), empty()]);
  assert.deepEqual(second.scores, [4, 2]); assert.equal(getCell(second, 0, 0)!.terrain, 'plain');
  state.scores = [6, 7];
  const tied = resolveRound(state, [empty(), empty()]);
  assert.deepEqual(tied.scores, [8, 8]); assert.equal(tied.winner, null);
  tied.round = MAX_ROUNDS; at(tied.units[0], -1, 0); at(tied.units[3], 1, 0);
  assert.equal(resolveRound(tied, [empty(), empty()]).winner, 'draw');
});

test('rotating the battlefield and swapping team identities preserves physical outcomes', () => {
  const left = ['wa_bidi', 'treevor_mason', 'haara']; const right = ['oh_tipi', 'grace_reava', 's_wayne'];
  const state = createSimGame([left, right]);
  at(state.units[0], -1, 0); at(state.units[1], -1, 1); at(state.units[3], 1, 0); at(state.units[4], 0, 0);
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[0], 0, 0), cast(state.units[1], 0, 0)), plan(cast(state.units[3], 0, 0), cast(state.units[4], -1, 0))];
  const expected = invert(resolveRound(state, plans));
  const rotated = resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])]);
  assert.deepEqual(physics(rotated), physics(expected));
});

test('strict save restoration rejects corrupted versions, geometry, occupants, effects and event data', () => {
  const valid = createSimGame();
  const mutations: ((state: SimState) => void)[] = [
    (state) => { (state as unknown as { rulesVersion: number }).rulesVersion = 2; },
    (state) => { state.cells[0].height = 1; },
    (state) => { state.units[0].hp = 99; },
    (state) => { state.units[0].hp = 0; },
    (state) => { at(state.units[0], state.units[1].q, state.units[1].r); },
    (state) => { state.cells[0].terrain = 'steam'; state.cells[0].ttl = 1; },
    (state) => { state.lastResolution = [{ kind: 'damage', text: 'bad', amount: -1 }]; },
  ];
  for (const mutate of mutations) { const changed = structuredClone(valid); mutate(changed); assert.throws(() => restoreSimState(changed)); }
  assert.throws(() => restoreSimState({ ...valid, opponentPlan: {} }));
});

test('saved resolution versions and victories must agree with round and simultaneous scores', () => {
  const start = createSimGame();
  assert.throws(() => restoreSimState({ ...start, version: 2 }), /version/i);
  assert.throws(() => restoreSimState({ ...start, scores: [8, 7] }), /victory/i);
  assert.throws(() => restoreSimState({ ...start, version: 2, winner: 0 }), /victory/i);
  assert.throws(() => restoreSimState({ ...start, version: 2, winner: 'draw' }), /victory/i);
  assert.throws(() => restoreSimState({ ...start, version: 2, winner: 1, scores: [8, 7] }), /victory/i);
  const near = createSimGame(); near.scores = [7, 6]; at(near.units[0], 0, 0);
  const won = resolveRound(near, [empty(), empty()]);
  assert.equal(won.winner, 0); assert.equal(won.version, won.round + 1);
  assert.deepEqual(restoreSimState(won), won);
  assert.throws(() => restoreSimState({ ...won, version: won.round }), /version/i);
  let capped = createSimGame();
  for (let round = 0; round < MAX_ROUNDS; round++) capped = resolveRound(capped, [empty(), empty()]);
  assert.equal(capped.winner, 'draw'); assert.equal(capped.version, MAX_ROUNDS + 1);
  assert.deepEqual(restoreSimState(capped), capped);
  assert.throws(() => restoreSimState({ ...capped, scores: [1, 0] }), /victory/i);
});

test('own-plan previews reveal combos and friendly-fire risk without predicting a hidden opponent order', () => {
  const state = createSimGame(); at(state.units[0], -1, 0); at(state.units[1], -1, 1); at(state.units[2], 0, 0);
  const preview = previewPlan(state, 0, plan(cast(state.units[0], 0, 0), cast(state.units[1], 0, 0)));
  assert.ok(preview.some((line) => line.includes('Steam')));
  assert.ok(preview.some((line) => line.includes('Friendly fire risk')));
  assert.ok(preview.some((line) => line.includes('Enemy spells may add reactions')));
});

test('AI plans are bounded, legal, deterministic, avoid known friendly fire and form team combos', () => {
  const state = createSimGame();
  at(state.units[0], 0, -1); at(state.units[1], -1, 0); at(state.units[2], -1, 1); at(state.units[3], 0, 0);
  const before = JSON.stringify(state); const chosen = chooseAIPlan(state, 0);
  assert.deepEqual(chooseAIPlan(state, 0), chosen); assert.equal(JSON.stringify(state), before);
  const landings = chosen.orders.map((order) => order.move ?? state.units.find((unit) => unit.id === order.unitId)!);
  for (const order of chosen.orders) if (order.cast) assert.ok(!landings.some((landing) => landing.q === order.cast!.q && landing.r === order.cast!.r));
  assert.ok(chosen.orders.filter((order) => order.cast?.q === 0 && order.cast.r === 0).length >= 2, 'team focuses at least two elements on the exposed enemy');
  let game = createSimGame([['oh_tipi', 'wa_bidi', 'treevor_mason'], ['grace_reava', 'haara', 's_wayne']]);
  for (let round = 0; game.winner === null && round < MAX_ROUNDS; round++) {
    const plans: [TeamPlan, TeamPlan] = [chooseAIPlan(game, 0), chooseAIPlan(game, 1)];
    game = resolveRound(game, plans);
    assert.deepEqual(restoreSimState(game), game);
    const alive = game.units.filter(isAlive); assert.equal(new Set(alive.map((unit) => `${unit.q},${unit.r}`)).size, alive.length);
  }
  assert.notEqual(game.winner, null);
});
