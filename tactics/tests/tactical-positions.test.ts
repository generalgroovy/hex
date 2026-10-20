import assert from 'node:assert/strict';
import test from 'node:test';
import { castAvailability, createSimGame, getCell, resolveRound, spellCost, validateLoadout } from '../lib/tactics-v4.ts';
import type { SimState, TeamPlan } from '../lib/tactics-v4.ts';

const EMPTY: TeamPlan = { orders: [] };
const KIT = ['stone', 'shatter', 'water_jet', 'mend'];

/** Prepared positions compare explicit candidate plans, not a search for global optimal play. */
function wellDuel(champion = 'treevor_mason'): SimState {
  const state = createSimGame([[champion, 'oh_tipi', 's_wayne'], ['haara', 'wa_bidi', 'grace_reava']]);
  Object.assign(state.units[0], { q: -1, r: 0, loadout: validateLoadout(champion, KIT) });
  Object.assign(state.units[3], { q: 0, r: 0, hp: 1 });
  return state;
}

function castAt(state: SimState, spellId: string, targetIndex = 3): SimState {
  const caster = state.units[0], target = state.units[targetIndex];
  return resolveRound(state, [{ orders: [{ unitId: caster.id, spellId, cast: { q: target.q, r: target.r } }] }, EMPTY]);
}

test('prepared well position: Ward changes the useful answer from economical Stone to piercing Shatter', () => {
  const state = wellDuel();
  const stone = castAt(state, 'stone'), shatter = castAt(state, 'shatter');
  assert.equal(stone.units[3].hp, 0); assert.equal(shatter.units[3].hp, 0);
  assert.deepEqual(stone.scores, [1, 0]); assert.deepEqual(shatter.scores, [1, 0]);
  assert.equal(spellCost(state.units[0].championId, 'stone'), 2);
  assert.equal(spellCost(state.units[0].championId, 'shatter'), 4);
  state.units[3].statuses.ward = { turns: 1, power: 3 };
  const absorbed = castAt(state, 'stone'), pierced = castAt(state, 'shatter');
  assert.equal(absorbed.units[3].hp, 1); assert.deepEqual(absorbed.scores, [0, 1]);
  assert.equal(pierced.units[3].hp, 0); assert.deepEqual(pierced.scores, [1, 0]);
});

test('prepared low-Flux position: canonical affinity changes which equipped spell can clear the well', () => {
  for (const [champion, affordable, unavailable] of [
    ['treevor_mason', 'stone', 'water_jet'], ['grace_reava', 'water_jet', 'stone'],
  ] as const) {
    const state = wellDuel(champion); state.units[0].flux = 2;
    assert.deepEqual(castAvailability(state, state.units[0].id, affordable), { available: true, cost: 2 });
    assert.equal(castAvailability(state, state.units[0].id, unavailable).available, false);
    assert.equal(castAvailability(state, state.units[0].id, unavailable).cost, 3);
    const result = castAt(state, affordable);
    assert.equal(result.units[3].hp, 0); assert.deepEqual(result.scores, [1, 0]);
  }
});

test('prepared rescue position: old Burn and Wither reverse the immediate healing preference', () => {
  const state = createSimGame([['oh_tipi', 'treevor_mason', 's_wayne'], ['haara', 'wa_bidi', 'grace_reava']]);
  state.units[0].hp = 2;
  state.units[0].loadout = validateLoadout('oh_tipi', ['mend', 'cleansing_tide', 'stone', 'gust']);
  assert.equal(castAt(state, 'mend', 0).units[0].hp, 5);
  assert.equal(castAt(state, 'cleansing_tide', 0).units[0].hp, 4);
  state.units[0].statuses = { burn: { turns: 1, power: 1 }, wither: { turns: 2, power: 1 } };
  const mended = castAt(state, 'mend', 0), cleansed = castAt(state, 'cleansing_tide', 0);
  assert.equal(mended.units[0].hp, 3); assert.ok(mended.units[0].statuses.wither);
  assert.equal(cleansed.units[0].hp, 4);
  assert.equal(cleansed.units[0].statuses.wither, undefined); assert.equal(cleansed.units[0].statuses.burn, undefined);
  assert.ok(cleansed.units[0].statuses.wet);
});

test('prepared reaction position: Steam changes a lethal hold into an immediate scoring opportunity', () => {
  const state = wellDuel();
  Object.assign(state.units[0], { q: 0, r: 0, hp: 1 });
  Object.assign(state.units[3], { q: 1, r: 0, hp: 8, loadout: validateLoadout('haara', ['ember', 'stone', 'mend', 'gust']) });
  const attack: TeamPlan = { orders: [{ unitId: state.units[3].id, spellId: 'ember', cast: { q: 0, r: 0 } }] };
  const retreat: TeamPlan = { orders: [{ unitId: state.units[0].id, move: { q: 0, r: 1 } }] };
  const plainHold = resolveRound(state, [EMPTY, attack]), plainRetreat = resolveRound(state, [retreat, attack]);
  assert.equal(plainHold.units[0].hp, 0); assert.deepEqual(plainHold.scores, [0, 1]);
  assert.equal(plainRetreat.units[0].hp, 1); assert.deepEqual(plainRetreat.scores, [0, 0]);
  Object.assign(getCell(state, 0, 0)!, { terrain: 'steam', ttl: 1, elements: ['fire', 'water'], reactions: ['steam'] });
  const steamHold = resolveRound(state, [EMPTY, attack]), steamRetreat = resolveRound(state, [retreat, attack]);
  assert.equal(steamHold.units[0].hp, 1); assert.deepEqual(steamHold.scores, [1, 0]);
  assert.equal(steamRetreat.units[0].hp, 1); assert.deepEqual(steamRetreat.scores, [0, 0]);
  assert.ok(steamHold.units[0].statuses.burn, 'holding takes the immediate point but still needs an answer to fresh Burn next round');
});
