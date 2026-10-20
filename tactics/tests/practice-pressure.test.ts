import test from 'node:test';
import assert from 'node:assert/strict';
import { choosePracticePlan } from '../lib/practice-v7.ts';
import { analyzePlan } from '../lib/plan-insights-v7.ts';
import { chooseAIPlan, createSimGame, getCell, getSignature, isAlive, MAX_ROUNDS, POINTS_TO_WIN, resolveRound, restoreSimState, spellArea, validatePlan } from '../lib/tactics-v7.ts';
import type { Player, Point, SimState, TeamPlan } from '../lib/tactics-v7.ts';

/** Prepared public position isolates a quiet scorer and two rival scoring wells. */
function position(): SimState {
  const state = createSimGame([['oh_tipi', 's_wayne', 'treevor_mason'], ['oh_tipi', 's_wayne', 'treevor_mason']]);
  for (const cell of state.cells) { cell.well = false; cell.biome = 'plain'; cell.terrain = 'plain'; cell.height = 0; }
  Object.assign(state.units[0], { q: 0, r: 0, loadout: ['water_jet', 'ember', 'gust', 'stone'] });
  Object.assign(state.units[3], { q: 6, r: 0 }); Object.assign(state.units[4], { q: 6, r: -3 });
  for (const index of [1, 2, 5]) { state.units[index].hp = 0; state.units[index].respawn = 3; }
  for (const unit of state.units.filter(isAlive)) getCell(state, unit.q, unit.r)!.well = true;
  state.scores = [0, 4]; return state;
}
function threeAgainstTwo(): SimState {
  const state = position();
  for (const [index, q, r] of [[1, 0, 4], [2, -4, 0]]) {
    Object.assign(state.units[index], { hp: 8, q, r, loadout: ['water_jet', 'ember', 'gust', 'stone'] }); delete state.units[index].respawn;
    getCell(state, q, r)!.well = true;
  }
  state.scores = [POINTS_TO_WIN - 5, POINTS_TO_WIN - 3]; return state;
}
const empty: TeamPlan = { orders: [] };
const clean = (state: SimState, player: Player, plan: TeamPlan) => {
  assert.deepEqual(validatePlan(state, player, plan), plan);
  assert.deepEqual(analyzePlan(state, player, plan).filter(issue => issue.kind === 'ally-collision' || issue.kind === 'ally-exposure' || issue.kind === 'blocked-cast'), []);
};

test('an idle scorer in a losing race creates a legal threat against rival scoring instead of waiting to lose', () => {
  const state = position(), baseline = chooseAIPlan(state, 0), before = structuredClone(state);
  assert.equal(baseline.orders[0].guard, true); assert.equal(baseline.orders[0].move, undefined);
  const candidate = choosePracticePlan(state, 0); clean(state, 0, candidate);
  assert.ok(candidate.orders[0].move); assert.ok(candidate.orders[0].cast);
  assert.deepEqual(state, before); assert.deepEqual(choosePracticePlan(state, 0), candidate);
  const held = resolveRound(state, [baseline, empty]), pressured = resolveRound(state, [candidate, empty]);
  assert.equal(held.lastResolution.some(event => event.kind === 'damage' && event.owner === 1), false);
  assert.equal(pressured.lastResolution.some(event => event.kind === 'damage' && event.owner === 1 && event.amount! > 0), true, 'pressure damages a defended well through Guard');
});

test('a near winner, a favorable or tied score race and a wounded holder preserve the established scoring plan', () => {
  for (const setup of [
    (state: SimState) => { state.scores = [15, 4]; },
    (state: SimState) => { state.scores = [12, 0]; },
    (state: SimState) => { state.scores = [4, 4]; getCell(state, 6, -3)!.well = false; },
    (state: SimState) => { state.units[0].hp = 4; },
  ]) {
    const state = position(); setup(state);
    assert.deepEqual(choosePracticePlan(state, 0), chooseAIPlan(state, 0));
  }
});

test('the race gate respects simultaneous whole-round ties above the victory target', () => {
  const state = threeAgainstTwo(), baseline = chooseAIPlan(state, 0);
  assert.ok((POINTS_TO_WIN - state.scores[0]) / 3 > (POINTS_TO_WIN - state.scores[1]) / 2, 'fractional arrival times incorrectly call this a loss');
  assert.deepEqual(choosePracticePlan(state, 0), baseline, 'holding3 wells wins after the simultaneous threshold tie');
  let next = structuredClone(state);
  for (let index = 0; index < 3; index++) next = resolveRound(next, [empty, empty]);
  assert.equal(next.winner, 0); assert.deepEqual(next.scores, [POINTS_TO_WIN + 4, POINTS_TO_WIN + 3]);
});

test('the race gate preserves a projected draw at the cap but recognizes a sub-threshold final-round loss', () => {
  const draw = threeAgainstTwo(); draw.round = MAX_ROUNDS - 1;
  assert.deepEqual(choosePracticePlan(draw, 0), chooseAIPlan(draw, 0), 'two remaining rounds end level and should not donate a scoring well');
  const last = threeAgainstTwo(); last.round = MAX_ROUNDS; last.scores = [POINTS_TO_WIN - 9, POINTS_TO_WIN - 7];
  assert.ok((POINTS_TO_WIN - last.scores[0]) / 3 < (POINTS_TO_WIN - last.scores[1]) / 2, 'fractional threshold times miss the final-round loss');
  assert.notDeepEqual(choosePracticePlan(last, 0), chooseAIPlan(last, 0), 'the losing final-round holder should attempt pressure');
  assert.equal(resolveRound(last, [empty, empty]).winner, 1);
});

test('the pressure policy evaluates a public allied volley against shared Ward instead of treating each hit alone', () => {
  const state = position();
  getCell(state, 6, -3)!.well = false; Object.assign(state.units[4], { q: 8, r: -8 }); getCell(state, 8, -8)!.well = true;
  for (const [index, r] of [[1, 1], [2, -1]]) {
    Object.assign(state.units[index], { hp: 8, q: 3, r, loadout: ['stone', 'mend', 'clear_sight', 'aegis'], statuses: { rooted: { turns: 1, power: 1 } } });
    delete state.units[index].respawn;
  }
  state.units[3].statuses.ward = { turns: 1, power: 3 };
  const baseline = chooseAIPlan(state, 0), candidate = choosePracticePlan(state, 0);
  assert.equal(baseline.orders.find(order => order.unitId === state.units[0].id)!.guard, true);
  assert.ok(candidate.orders.find(order => order.unitId === state.units[0].id)!.cast); clean(state, 0, candidate);
  const without = resolveRound(state, [baseline, empty]), withPressure = resolveRound(state, [candidate, empty]);
  assert.ok(withPressure.units[3].hp < without.units[3].hp, 'additional planned spell penetrates the aggregate protection');
});

test('after clearing a rival well, the attacking mage captures it instead of returning to its former well', () => {
  const state = position(), actor = state.units[0], victim = state.units[3];
  actor.q = 3; victim.hp = 0; victim.respawn = 3;
  state.lastResolution = [
    { kind: 'cast', unitId: actor.id, owner: 0, spellId: 'water_jet', from: { q: 3, r: 0 }, to: { q: 6, r: 0 }, text: 'Revealed attack.' },
    { kind: 'defeat', unitId: victim.id, owner: 1, q: 6, r: 0, amount: 1, text: 'Revealed defeat.' },
  ];
  // The other rival is too far away to make the baseline choose an attack.
  Object.assign(state.units[4], { q: 8, r: -7 }); getCell(state, 6, -3)!.well = false; getCell(state, 8, -7)!.well = true;
  const baseline = chooseAIPlan(state, 0); assert.deepEqual(baseline.orders[0].move, { q: 0, r: 0 });
  const candidate = choosePracticePlan(state, 0); assert.deepEqual(candidate.orders[0].move, { q: 6, r: 0 }); clean(state, 0, candidate);
  const result = resolveRound(state, [candidate, empty]); assert.equal(result.units[0].q, 6); assert.equal(result.scores[0], 1);
});

test('burst pressure excludes the caster at its new origin, along with allies at old and planned positions', () => {
  const state = position(), actor = state.units[0];
  actor.championId = 's_wayne'; actor.id = '0-s_wayne'; state.units[1].championId = 'oh_tipi'; state.units[1].id = '0-oh_tipi';
  actor.loadout = ['blight', 'quake', 'wildfire', 'rainfall']; actor.cooldowns[getSignature(actor.championId).id] = 3;
  actor.statuses.blind = { turns: 1, power: 1 };
  for (const cell of state.cells) { cell.biome = 'ruins'; cell.terrain = 'earth'; }
  for (const [q, r] of [[0, 0], [1, 0], [2, 0], [3, 0], [5, -3], [5, -2], [5, -1], [6, -1], [5, 3], [5, 2], [5, 1], [6, 0]]) {
    const cell = getCell(state, q, r)!; cell.biome = 'plain'; cell.terrain = 'plain';
  }
  Object.assign(state.units[3], { q: 6, r: -1 }); Object.assign(state.units[4], { q: 6, r: 0 });
  getCell(state, 6, -3)!.well = false; getCell(state, 6, -1)!.well = true;
  for (const [index, r] of [[1, -3], [2, 3]]) {
    Object.assign(state.units[index], { hp: 8, q: 5, r, loadout: ['stone', 'mend', 'clear_sight', 'aegis'], statuses: { rooted: { turns: 1, power: 1 }, blind: { turns: 1, power: 1 } } });
    delete state.units[index].respawn;
  }
  const candidate = choosePracticePlan(state, 0); clean(state, 0, candidate);
  const order = candidate.orders.find(entry => entry.unitId === actor.id)!;
  assert.ok(order.cast, 'fixture exercises an actual burst, rather than passing by Guarding');
  const origin = order.move ?? actor;
  assert.ok(!spellArea(state, actor.id, order.spellId!, order.cast!, order.move).some(cell => cell.q === origin.q && cell.r === origin.r));
});

test('pressure decisions mirror with the seat and do not infer the next sealed action from old Guard flags', () => {
  const state = position(), expected = choosePracticePlan(state, 0);
  for (const rival of state.units.filter(unit => unit.owner === 1)) rival.guard = true;
  assert.deepEqual(choosePracticePlan(state, 0), expected);
  const flip = ({ q, r }: Point): Point => ({ q: -q || 0, r: -r || 0 }), id = (value: string) => `${1 - Number(value[0])}${value.slice(1)}`;
  const mirrored: SimState = { ...structuredClone(state), scores: [state.scores[1], state.scores[0]], units: state.units.map(unit => ({ ...structuredClone(unit), ...flip(unit), id: id(unit.id), owner: (1 - unit.owner) as Player })), cells: state.cells.map(cell => ({ ...structuredClone(cell), ...flip(cell) })) };
  const mirrorPlan = { orders: expected.orders.map(order => ({ ...order, unitId: id(order.unitId), ...(order.move ? { move: flip(order.move) } : {}), ...(order.cast ? { cast: flip(order.cast) } : {}) })) };
  assert.deepEqual(choosePracticePlan(mirrored, 1), mirrorPlan);
});

test('practice policy completes seeded games with no known own collisions or harmful footprints and strict save restoration', () => {
  for (const seed of ['WELLSPRING', 'RIVER-FRIENDS', 'FRIENDS']) {
    let state = createSimGame([['oh_tipi', 'wa_bidi', 'treevor_mason'], ['grace_reava', 'haara', 's_wayne']], `frontier:${seed}`);
    while (state.winner === null) {
      const plans: [TeamPlan, TeamPlan] = [choosePracticePlan(state, 0), choosePracticePlan(state, 1)];
      clean(state, 0, plans[0]); clean(state, 1, plans[1]);
      state = resolveRound(state, plans); assert.deepEqual(restoreSimState(state), state);
    }
  }
});
