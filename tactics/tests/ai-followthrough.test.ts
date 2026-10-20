import test from 'node:test';
import assert from 'node:assert/strict';
import { CHAMPIONS, chooseAIPlan, createSimGame, defaultLoadout, resolveRound, validateLoadout, validatePlan } from '../lib/tactics.ts';
import { practiceLoadouts } from '../lib/practice.ts';
import type { Point, SimState, StatusId, TeamPlan } from '../lib/tactics.ts';

const empty: TeamPlan = { orders: [] };
const cases = [
  { champion: 'wa_bidi', basic: 'ember', followup: 'backdraft', mark: 'burn', hp: 3, survivingHp: 1 },
  { champion: 's_wayne', basic: 'wither_bolt', followup: 'reap', mark: 'wither', hp: 3, survivingHp: 2 },
  { champion: 'oh_tipi', basic: 'water_jet', followup: 'deep_freeze', mark: 'wet', hp: 2, survivingHp: 1 },
] as const;

function position(fixture: typeof cases[number]): SimState {
  const state = createSimGame([[fixture.champion, 'grace_reava', 'treevor_mason'], ['s_wayne', 'oh_tipi', 'treevor_mason']]);
  const actor = state.units[0], target = state.units[3];
  Object.assign(actor, { q: 0, r: 0, loadout: [fixture.basic, fixture.followup, 'mend', 'clear_sight'], statuses: { rooted: { turns: 1, power: 1 } } });
  Object.assign(target, { q: 1, r: 0, hp: fixture.hp });
  for (const unit of state.units) if (unit !== actor && unit !== target) { unit.hp = 0; unit.respawn = 3; }
  return state;
}

for (const fixture of cases) test(`practice follows existing ${fixture.mark} with ${fixture.followup}, but keeps ${fixture.basic} without the mark`, () => {
  const state = position(fixture), actor = state.units[0], target = state.units[3];
  const unmarked = chooseAIPlan(state, 0);
  assert.equal(unmarked.orders[0].spellId, fixture.basic, 'paying for an inactive bonus is unnecessary');
  target.statuses[fixture.mark] = { turns: 1, power: 1 };
  const before = structuredClone(state), followup = chooseAIPlan(state, 0);
  assert.equal(followup.orders[0].spellId, fixture.followup);
  assert.deepEqual(followup.orders[0].cast, { q: target.q, r: target.r });
  assert.deepEqual(chooseAIPlan(state, 0), followup); assert.deepEqual(state, before, 'policy reads only the public snapshot');
  assert.deepEqual(validatePlan(state, 0, followup), followup);
  const basic = { orders: [{ unitId: actor.id, spellId: fixture.basic, cast: { q: target.q, r: target.r } }] };
  assert.equal(resolveRound(state, [basic, empty]).units[3].hp, fixture.survivingHp, 'the previous policy misses a guarded finish');
  assert.equal(resolveRound(state, [followup, empty]).units[3].hp, 0, 'the selected follow-up actually finishes through Guard');
  delete target.statuses[fixture.mark];
  assert.equal(chooseAIPlan(state, 0).orders[0].spellId, fixture.basic, 'removing the public mark reverses the choice');
});

test('a planned fresh Burn does not enable a second mage\'s Backdraft bonus in the same exchange', () => {
  const state = createSimGame([['wa_bidi', 'treevor_mason', 'grace_reava'], ['s_wayne', 'oh_tipi', 'treevor_mason']]);
  Object.assign(state.units[0], { q: 0, r: 0, loadout: ['ember', 'mend', 'clear_sight', 'aegis'] });
  Object.assign(state.units[1], { q: 0, r: 1, loadout: ['stone', 'backdraft', 'mend', 'clear_sight'] });
  Object.assign(state.units[3], { q: 1, r: 0 });
  for (const unit of state.units.slice(0, 2)) unit.statuses.rooted = { turns: 1, power: 1 };
  for (const index of [2, 4, 5]) { state.units[index].hp = 0; state.units[index].respawn = 3; }
  const unmarked = chooseAIPlan(state, 0);
  assert.equal(unmarked.orders.find(order => order.unitId === state.units[0].id)?.spellId, 'ember');
  assert.equal(unmarked.orders.find(order => order.unitId === state.units[1].id)?.spellId, 'stone', 'future Ember does not make Backdraft stronger now');
  state.units[3].statuses.burn = { turns: 1, power: 1 };
  assert.equal(chooseAIPlan(state, 0).orders.find(order => order.unitId === state.units[1].id)?.spellId, 'backdraft');
});

test('bonus-aware choices are seat symmetric and do not treat prior Guard as a sealed future order', () => {
  const flip = ({ q, r }: Point): Point => ({ q: -q || 0, r: -r || 0 });
  const id = (value: string) => `${1 - Number(value[0])}${value.slice(1)}`;
  for (const fixture of cases) {
    const state = position(fixture); state.units[3].statuses[fixture.mark as StatusId] = { turns: 1, power: 1 };
    const choice = chooseAIPlan(state, 0); state.units[3].guard = true;
    assert.deepEqual(chooseAIPlan(state, 0), choice, 'last round\'s Guard is not knowledge of a future order');
    const inverse: SimState = { ...structuredClone(state), units: state.units.map(unit => ({ ...structuredClone(unit), ...flip(unit), id: id(unit.id), owner: (1 - unit.owner) as 0 | 1 })), cells: state.cells.map(cell => ({ ...structuredClone(cell), ...flip(cell) })) };
    const expected = { orders: choice.orders.map(order => ({ ...order, unitId: id(order.unitId), ...(order.cast ? { cast: flip(order.cast) } : {}), ...(order.move ? { move: flip(order.move) } : {}) })) };
    assert.deepEqual(chooseAIPlan(inverse, 1), expected);
  }
});

test('the real practice kit demonstrates Wither into Reap without changing player starter kits', () => {
  const ids = CHAMPIONS.map(champion => champion.id), before = [...ids];
  const kits = practiceLoadouts(ids);
  assert.deepEqual(ids, before);
  for (const id of ids) {
    assert.deepEqual(validateLoadout(id, kits[id]), kits[id]);
    if (id !== 's_wayne') assert.deepEqual(kits[id], defaultLoadout(id));
  }
  assert.deepEqual(kits.s_wayne, ['wither_bolt', 'blight', 'radiant_bolt', 'reap']);
  assert.equal(defaultLoadout('s_wayne')[3], 'siphon', 'player and hotseat starter kits remain unchanged');
  const state = position(cases[1]); state.units[0].loadout = kits.s_wayne;
  assert.equal(chooseAIPlan(state, 0).orders[0].spellId, 'wither_bolt');
  state.units[3].statuses.wither = { turns: 1, power: 1 };
  const followup = chooseAIPlan(state, 0);
  assert.equal(followup.orders[0].spellId, 'reap');
  assert.equal(resolveRound(state, [followup, empty]).units[3].hp, 0);
});
