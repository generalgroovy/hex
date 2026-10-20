import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ALL_SPELLS, CHAMPIONS, SPELLS, MAX_ROUNDS, chooseAIPlan, createSimGame,
  getCell, isIce, legalCasts, resolveRound, restoreSimState,
  type SimState, type TeamPlan,
} from '../lib/tactics-v8.ts';

const empty = (): TeamPlan => ({ orders: [] });
const wire = <T>(value: T): T => JSON.parse(JSON.stringify(value));

test('every V8 catalogue action produces a strict-restorable immutable snapshot on actual seeded terrain', () => {
  for (const spell of ALL_SPELLS) {
    const champion = spell.signatureChampionId ?? 'oh_tipi';
    const others = CHAMPIONS.filter(entry => entry.id !== champion).slice(0, 2).map(entry => entry.id);
    const state = createSimGame([[champion, ...others], ['oh_tipi', 's_wayne', 'treevor_mason']], 'frontier:SURFACE-RESTORE');
    const unit = state.units[0];
    if (!spell.signatureChampionId) unit.loadout = [spell.id, ...SPELLS.filter(entry => entry.id !== spell.id).slice(0, 3).map(entry => entry.id)];
    const target = legalCasts(state, unit.id, undefined, spell.id).find(cell => cell.terrain !== 'plain') ?? legalCasts(state, unit.id, undefined, spell.id)[0];
    assert.ok(target, `${spell.id} has a legal opening footprint`);
    const before = wire(state);
    const result = resolveRound(state, [{ orders: [{ unitId: unit.id, spellId: spell.id, cast: { q: target.q, r: target.r } }] }, empty()]);
    assert.deepEqual(state, before, `${spell.id} cannot mutate the replay's previous board`);
    assert.ok(result.lastResolution.some(event => event.kind === 'cast' && event.spellId === spell.id), spell.id);
    assert.deepEqual(restoreSimState(wire(result)), result, `${spell.id} survives JSON and strict validation`);
    assert.deepEqual(restoreSimState(wire(resolveRound(result, [empty(), empty()]))), resolveRound(result, [empty(), empty()]), `${spell.id} also restores after field expiry`);
  }
});

test('simultaneous freeze, wind and fire are order-independent and cannot thaw the replay source', () => {
  const state = createSimGame(undefined, 'frontier:WELLSPRING');
  const [ice, wind, fire] = [state.units[0], state.units[1], state.units[3]];
  Object.assign(ice, { q: 0, r: 0 });
  Object.assign(wind, { q: 1, r: 0 });
  Object.assign(fire, { q: -1, r: 0 });
  for (const unit of [ice, wind, fire]) unit.loadout = ['frostbite', 'gust', 'ember', 'mend'];
  const target = { q: 0, r: 1 };
  const iceOrder = { unitId: ice.id, spellId: 'frostbite', cast: target };
  const windOrder = { unitId: wind.id, spellId: 'gust', cast: target };
  const fireOrder = { unitId: fire.id, spellId: 'ember', cast: target };
  const before = wire(state);
  const left = resolveRound(state, [{ orders: [iceOrder, windOrder] }, { orders: [fireOrder] }]);
  const right = resolveRound(state, [{ orders: [windOrder, iceOrder] }, { orders: [fireOrder] }]);
  assert.deepEqual(left, right);
  assert.equal(isIce(getCell(left, target.q, target.r)!), false, 'Fire in the simultaneous union wins over freezing');
  assert.deepEqual(state, before);
  assert.deepEqual(restoreSimState(wire(left)), left);
});

test('strict V8 saves reject forged or contradictory ice without rewriting a source snapshot', () => {
  const state = createSimGame();
  const unit = state.units[0]; unit.loadout = ['frostbite', 'water_jet', 'mend', 'gust'];
  const target = legalCasts(state, unit.id, undefined, 'frostbite').find(cell => cell.terrain === 'plain')!;
  const frozen = resolveRound(state, [{ orders: [{ unitId: unit.id, spellId: 'frostbite', cast: { q: target.q, r: target.r } }] }, empty()]);
  assert.ok(isIce(getCell(frozen, target.q, target.r)!));
  assert.deepEqual(restoreSimState(wire(frozen)), frozen);
  const malformed: SimState[] = [];
  for (const flag of [false, 1, 'true']) {
    const changed = wire(frozen); Object.assign(getCell(changed, target.q, target.r)!, { ice: flag }); malformed.push(changed);
  }
  const onBase = wire(state); Object.assign(onBase.cells[0], { ice: true }); malformed.push(onBase);
  const fireIce = wire(frozen); Object.assign(getCell(fireIce, target.q, target.r)!, { elements: ['fire', 'water'], reactions: ['steam'], terrain: 'steam' }); malformed.push(fireIce);
  for (const changed of malformed) assert.throws(() => restoreSimState(changed), /ice|terrain|chemistry/i);
});

test('three complete seeded V8 matches restore every round and replay from the same sealed input', () => {
  for (const seed of ['WELLSPRING', 'ICE-RETURN', 'RIVER-42']) {
    let state = createSimGame(undefined, `frontier:${seed}`);
    let resolutions = 0;
    while (state.winner === null && resolutions < MAX_ROUNDS) {
      const plans: [TeamPlan, TeamPlan] = [chooseAIPlan(state, 0), chooseAIPlan(state, 1)];
      const before = wire(state);
      const next = resolveRound(state, plans);
      assert.deepEqual(state, before, seed);
      assert.deepEqual(resolveRound(restoreSimState(before), wire(plans)), next, `${seed}, round ${state.round}: replay is deterministic`);
      assert.deepEqual(restoreSimState(wire(next)), next, `${seed}, round ${state.round}: save is valid`);
      state = next; resolutions++;
    }
    assert.notEqual(state.winner, null, `${seed}: match terminates within the cap`);
  }
});
