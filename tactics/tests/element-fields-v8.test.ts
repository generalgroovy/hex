import test from 'node:test';
import assert from 'node:assert/strict';
import { ALL_SPELLS as V7_SPELLS, createSimGame as createV7, restoreSimState as restoreV7 } from '../lib/tactics-v7.ts';
import { ALL_SPELLS, SPELLS, CHAMPIONS, createSimGame, restoreSimState, getCell, getSpell, isIce, isFlooded, surfaceTraits, reactionsFor, movementCost, movementBudget, movementEffort, movementPath, legalMoves, legalCasts, resolveRound, validatePlan, chooseAIPlan } from '../lib/tactics-v8.ts';
import type { Element, Point, SimCell, SimState, SimUnit, Order, TeamPlan } from '../lib/tactics-v8.ts';

const key = ({ q, r }: Point) => `${q || 0},${r || 0}`;
const xy = ({ q, r }: Point) => ({ q: q || 0, r: r || 0 });
const empty = (): TeamPlan => ({ orders: [] });
const plan = (...orders: Order[]): TeamPlan => ({ orders });
const cast = (unit: SimUnit, spellId: string, target: Point = unit): Order => ({ unitId: unit.id, spellId, cast: xy(target) });
const move = (unit: SimUnit, target: Point): Order => ({ unitId: unit.id, move: xy(target), guard: true });
const equip = (unit: SimUnit, ...ids: string[]) => { unit.loadout = [...ids, ...SPELLS.map(s => s.id).filter(id => !ids.includes(id))].slice(0, 4); };
const at = (unit: SimUnit, q: number, r: number) => Object.assign(unit, { q, r });
const rotate = ({ q, r }: Point): Point => ({ q: -r || 0, r: q + r || 0 });
function field(cell: SimCell, elements: Element[], ice = false) {
  cell.elements = ['fire', 'water', 'earth', 'air', 'light', 'dark'].filter(e => elements.includes(e as Element)) as Element[];
  cell.reactions = reactionsFor(cell.elements); cell.terrain = cell.reactions[0] ?? cell.elements[0]; cell.ttl = 2;
  if (ice) cell.ice = true; else delete cell.ice;
  return cell;
}
/** Synthetic geometry isolates route/combat semantics; strict restores use real seeded fixtures below. */
function arena(): SimState {
  const state = createSimGame();
  for (const cell of state.cells) { cell.biome = 'plain'; cell.terrain = 'plain'; cell.height = 0; cell.well = false; }
  at(state.units[0], 0, 0); at(state.units[1], -4, 3); at(state.units[2], -6, 6);
  at(state.units[3], 2, 0); at(state.units[4], 6, -3); at(state.units[5], 6, -6);
  return state;
}

test('V8 preserves the full roster, loadouts and spell statistics while V7 saves remain V7', () => {
  const old = createV7(), current = createSimGame();
  assert.equal(current.rulesVersion, 8); assert.equal(CHAMPIONS.length, 30); assert.equal(ALL_SPELLS.length, 78);
  assert.deepEqual(current.units, old.units); assert.deepEqual(current.cells, old.cells);
  assert.deepEqual(restoreSimState(current), current); assert.deepEqual(restoreV7(old), old);
  assert.throws(() => restoreSimState(old)); assert.throws(() => restoreV7(current));
  assert.equal(getSpell('frostbite').freeze, true); assert.equal(getSpell('deep_freeze').freeze, true);
  assert.deepEqual(ALL_SPELLS.filter(spell => spell.freeze).map(spell => spell.id), ['frostbite', 'deep_freeze']);
  for (const spell of ALL_SPELLS) {
    const { description: _description, freeze: _freeze, ...stats } = spell;
    const { description: _oldDescription, ...oldStats } = V7_SPELLS.find(s => s.id === spell.id)!;
    assert.deepEqual(stats, oldStats, `${spell.id}: cost, reach, footprint, direct effects and signature identity preserved`);
  }
});

test('only active Water floods: entry and exit cost two without terrain stacking', () => {
  const state = arena(), plain = getCell(state, 0, 0)!, water = getCell(state, 1, 0)!;
  water.biome = 'water'; water.terrain = 'water';
  assert.equal(movementCost(plain, water), 1); assert.equal(isFlooded(water), false); assert.deepEqual(surfaceTraits(water), []);
  field(water, ['water']); assert.equal(isFlooded(water), true);
  assert.equal(movementCost(plain, water), 2); assert.equal(movementCost(water, plain), 2);
  water.height = 1; water.biome = 'marsh'; field(water, ['water', 'earth']);
  assert.equal(movementCost(plain, water), 2); assert.equal(movementCost(water, plain), 2);
  assert.deepEqual(surfaceTraits(water).map(t => t.id), ['flood', 'rough']);
  for (const cell of state.cells) if (cell.r !== 0 || cell.q < 0 || cell.q > 4) cell.biome = 'ruins';
  assert.equal(movementEffort(state, state.units[0].id, { q: 2, r: 0 }), 4);
  assert.equal(movementPath(state, state.units[0].id, { q: 3, r: 0 }), null);
});

test('Earth resists passage and Air gives one starting effort without stacking Haste', () => {
  const state = arena(), unit = state.units[0], start = getCell(state, 0, 0)!, next = getCell(state, 1, 0)!;
  field(next, ['earth']); assert.equal(movementCost(start, next), 2); assert.equal(movementCost(next, start), 2);
  field(start, ['air']); assert.equal(movementBudget(unit, state), 5); assert.equal(movementBudget(unit), 4);
  unit.statuses.haste = { turns: 1, power: 1 }; assert.equal(movementBudget(unit, state), 5);
  unit.statuses.chilled = { turns: 1, power: 1 }; assert.equal(movementBudget(unit, state), 4);
  unit.statuses.rooted = { turns: 1, power: 1 }; assert.equal(movementBudget(unit, state), 0);
  assert.equal(legalMoves(state, unit.id).length, 0);
});

test('Ice slides preview and resolve at the same last icy hex with one effort across all six rotations', () => {
  let start = { q: -5, r: 0 }, ice = Array.from({ length: 9 }, (_, index) => ({ q: index - 4, r: 0 }));
  let lane = Array.from({ length: 15 }, (_, index) => ({ q: index - 7, r: 0 }));
  for (let rotation = 0; rotation < 6; rotation++) {
    const state = arena(), unit = state.units[0]; Object.assign(unit, start);
    for (const cell of state.cells) cell.biome = lane.some(p => key(p) === key(cell)) ? 'plain' : 'ruins';
    for (const p of ice) field(getCell(state, p.q, p.r)!, ['water'], true);
    const landing = ice.at(-1)!;
    assert.equal(movementEffort(state, unit.id, landing), 1, `rotation ${rotation}`);
    assert.deepEqual(movementPath(state, unit.id, landing)!.map(xy), ice, `full visible route ${rotation}`);
    assert.equal(movementPath(state, unit.id, ice[3]), null, 'cannot stop halfway along the straight icy lane');
    const result = resolveRound(state, [plan(move(unit, landing)), empty()]);
    assert.deepEqual(xy(result.units[0]), landing); assert.equal(result.lastResolution.find(e => e.kind === 'move' && e.unitId === unit.id)?.to?.q, landing.q);
    const reversed = structuredClone(state); reversed.cells.reverse(); reversed.units.reverse();
    assert.deepEqual(movementPath(reversed, unit.id, landing)!.map(xy), ice, 'array enumeration is irrelevant');
    start = rotate(start); ice = ice.map(rotate); lane = lane.map(rotate);
  }
});

test('Ice stops before ruins, barriers and edges; dry ground ends the slide without entering it', () => {
  for (const obstacle of ['ruins', 'barrier', 'dry', 'edge'] as const) {
    const state = arena(), unit = at(state.units[0], 5, 0);
    for (let q = 6; q <= 9; q++) field(getCell(state, q, 0)!, ['water'], true);
    if (obstacle === 'ruins') getCell(state, 9, 0)!.biome = 'ruins';
    if (obstacle === 'barrier') getCell(state, 9, 0)!.barrier = 1;
    if (obstacle === 'dry') { const dry = getCell(state, 9, 0)!; delete dry.ice; field(dry, ['water']); }
    const end = { q: obstacle === 'edge' ? 9 : 8, r: 0 };
    assert.equal(movementEffort(state, unit.id, end), 1, obstacle);
    assert.deepEqual(movementPath(state, unit.id, end)!.at(-1) && xy(movementPath(state, unit.id, end)!.at(-1)!), end);
  }
});

test('Ice preserves simultaneous endpoint collisions, vacated landings and crossing-path semantics', () => {
  const state = arena(), a = at(state.units[0], -1, 0), b = at(state.units[3], 0, 0);
  for (let q = 1; q <= 4; q++) field(getCell(state, q, 0)!, ['water'], true);
  const target = { q: 4, r: 0 };
  const blocked = resolveRound(state, [plan(move(a, target)), plan(move(b, target))]);
  assert.deepEqual(xy(blocked.units[0]), xy(a)); assert.deepEqual(xy(blocked.units[3]), xy(b));
  assert.equal(blocked.lastResolution.filter(e => e.kind === 'bounce').length, 2);
  const crossing = resolveRound(state, [plan(move(a, target)), empty()]);
  assert.deepEqual(xy(crossing.units[0]), target, 'stationary intermediate occupants do not create hidden path collisions');
  at(b, 4, 0);
  const occupied = resolveRound(state, [plan(move(a, target)), empty()]); assert.deepEqual(xy(occupied.units[0]), xy(a));
  const vacated = resolveRound(state, [plan(move(a, target)), plan(move(b, { q: 5, r: 0 }))]);
  assert.deepEqual(xy(vacated.units[0]), target); assert.deepEqual(xy(vacated.units[3]), { q: 5, r: 0 });
});

test('Frostbite and Deep Freeze persist and expire Ice in strict seeded saves', () => {
  for (const spellId of ['frostbite', 'deep_freeze']) {
    const state = createSimGame(), unit = state.units[0]; equip(unit, spellId);
    const frozen = resolveRound(state, [plan(cast(unit, spellId)), empty()]);
    assert.equal(isIce(getCell(frozen, unit.q, unit.r)!), true); assert.equal(isFlooded(getCell(frozen, unit.q, unit.r)!), false);
    assert.ok(frozen.lastResolution.some(e => e.kind === 'surface' && e.terrain === 'ice'));
    assert.deepEqual(restoreSimState(frozen), frozen);
    const expired = resolveRound(frozen, [empty(), empty()]);
    assert.equal(getCell(expired, unit.q, unit.r)!.ice, undefined); assert.deepEqual(restoreSimState(expired), expired);
  }
});

test('Water plus Air or Dark freezes; Fire melts simultaneously regardless of cast/unit order', () => {
  for (const other of ['gust', 'veil']) {
    const state = arena(), a = state.units[0], b = at(state.units[1], 0, 1), c = at(state.units[2], -1, 1);
    equip(a, 'water_jet'); equip(b, other); equip(c, 'ember');
    const target = { q: 1, r: 0 }, orders = [cast(a, 'water_jet', target), cast(b, other, target)];
    const frozen = resolveRound(state, [plan(...orders), empty()]); assert.equal(isIce(getCell(frozen, 1, 0)!), true);
    const mixed = resolveRound(state, [plan(...orders, cast(c, 'ember', target)), empty()]);
    assert.equal(isIce(getCell(mixed, 1, 0)!), false); assert.equal(isFlooded(getCell(mixed, 1, 0)!), true);
    const reversed = structuredClone(state); reversed.units.reverse();
    const again = resolveRound(reversed, [plan(cast(c, 'ember', target), ...orders.reverse()), empty()]);
    assert.deepEqual(getCell(again, 1, 0), getCell(mixed, 1, 0));
  }
  const state = arena(), unit = state.units[0]; equip(unit, 'frostbite'); const cell = field(getCell(state, 1, 0)!, ['fire']);
  const result = resolveRound(state, [plan(cast(unit, 'frostbite', cell)), empty()]);
  assert.equal(isIce(getCell(result, 1, 0)!), false, 'old Fire also wins over new freezing');
});

test('a new Ice field never changes a sealed voluntary landing or cancels its simultaneous spell', () => {
  const state = arena(), a = at(state.units[0], -2, 0), b = at(state.units[3], 2, 0); equip(a, 'water_jet'); equip(b, 'frostbite');
  field(getCell(state, 0, 0)!, ['water'], true);
  const order = { unitId: a.id, move: { q: -1, r: 0 }, spellId: 'water_jet', cast: { q: 1, r: 0 } };
  const result = resolveRound(state, [plan(order), plan(cast(b, 'frostbite', { q: -1, r: 0 }))]);
  assert.deepEqual(xy(result.units[0]), { q: -1, r: 0 }, 'movement reads pre-spell terrain');
  assert.equal(isIce(getCell(result, -1, 0)!), true);
  assert.ok(result.lastResolution.some(e => e.kind === 'cast' && e.unitId === a.id));
});

test('pushes slide along fresh Ice while Guard and pre-existing Anchored resist displacement', () => {
  for (const protection of ['none', 'guard', 'anchored'] as const) {
    const state = arena(), a = state.units[0], b = at(state.units[3], 1, 0); equip(a, 'gust'); equip(b, 'mend');
    for (let q = 2; q <= 5; q++) field(getCell(state, q, 0)!, ['water'], true);
    if (protection === 'anchored') b.statuses.anchored = { turns: 1, power: 1 };
    const result = resolveRound(state, [plan(cast(a, 'gust', b)), protection === 'guard' ? empty() : plan(cast(b, 'mend'))]);
    assert.deepEqual(xy(result.units[3]), { q: protection === 'none' ? 5 : 1, r: 0 }, protection);
    if (protection === 'none') assert.deepEqual(result.lastResolution.find(e => e.kind === 'push' && e.unitId === b.id)?.to, { q: 5, r: 0 });
  }
  const state = arena(), a = state.units[0], freeze = at(state.units[1], 0, 1), b = at(state.units[3], 1, 0);
  equip(a, 'gust'); equip(freeze, 'frostbite'); equip(b, 'mend'); field(getCell(state, 3, 0)!, ['water'], true); field(getCell(state, 4, 0)!, ['water'], true);
  const result = resolveRound(state, [plan(cast(a, 'gust', b), cast(freeze, 'frostbite', { q: 2, r: 0 })), plan(cast(b, 'mend'))]);
  assert.deepEqual(xy(result.units[3]), { q: 4, r: 0 }, 'a simultaneously created icy entry joins the existing lane before displacement');
});

test('equal opposing pushes cancel before any Ice slide', () => {
  const state = arena(), a = at(state.units[0], 0, 0), c = at(state.units[1], 2, 0), b = at(state.units[3], 1, 0);
  equip(a, 'gust'); equip(c, 'gust'); equip(b, 'mend');
  for (let q = -3; q <= 5; q++) field(getCell(state, q, 0)!, ['water'], true);
  const result = resolveRound(state, [plan(cast(a, 'gust', b), cast(c, 'gust', b)), plan(cast(b, 'mend'))]);
  assert.deepEqual(xy(result.units[3]), { q: 1, r: 0 }); assert.equal(result.lastResolution.some(e => e.kind === 'push'), false);
});

test('two forced Ice slides claiming one endpoint both bounce, independent of unit order', () => {
  const state = arena(), a = at(state.units[0], -1, 0), c = at(state.units[1], 3, -4);
  const b = at(state.units[3], 0, 0), d = at(state.units[4], 3, -3);
  equip(a, 'gust'); equip(c, 'gust'); equip(b, 'mend'); equip(d, 'mend');
  for (const p of [{ q: 1, r: 0 }, { q: 2, r: 0 }, { q: 3, r: 0 }, { q: 3, r: -1 }, { q: 3, r: -2 }]) field(getCell(state, p.q, p.r)!, ['water'], true);
  const orders: [TeamPlan, TeamPlan] = [plan(cast(a, 'gust', b), cast(c, 'gust', d)), plan(cast(b, 'mend'), cast(d, 'mend'))];
  const result = resolveRound(state, orders);
  for (const victim of [b, d]) {
    assert.deepEqual(xy(result.units.find(u => u.id === victim.id)!), xy(victim));
    assert.deepEqual(result.lastResolution.find(e => e.kind === 'bounce' && e.unitId === victim.id)?.to, { q: 3, r: 0 });
  }
  const reversed = structuredClone(state); reversed.units.reverse();
  const again = resolveRound(reversed, orders);
  assert.deepEqual(again.units.map(u => ({ id: u.id, ...xy(u) })).sort((a, b) => a.id.localeCompare(b.id)), result.units.map(u => ({ id: u.id, ...xy(u) })).sort((a, b) => a.id.localeCompare(b.id)));
});

test('Fire, Light and Dark have distinct pure-field effects; reactions do not pile on pure-field effects', () => {
  for (const element of ['fire', 'light', 'dark'] as const) {
    const state = arena(), unit = state.units[0]; field(getCell(state, unit.q, unit.r)!, [element]);
    const result = resolveRound(state, [empty(), empty()]), after = result.units[0];
    assert.equal(after.hp, element === 'fire' ? 7 : 8);
    assert.equal(Boolean(after.statuses.clarity), element === 'light'); assert.equal(Boolean(after.statuses.wither), element === 'dark');
  }
  const state = arena(), unit = state.units[0]; field(getCell(state, unit.q, unit.r)!, ['fire', 'water']);
  const result = resolveRound(state, [empty(), empty()]); assert.equal(result.units[0].hp, 8, 'Steam replaces pure embers');
  field(getCell(state, unit.q, unit.r)!, ['fire', 'earth', 'air']);
  const hazards = resolveRound(state, [empty(), empty()]); assert.equal(hazards.units[0].hp, 7, 'hazards share a single environmental point');
  assert.equal(hazards.lastResolution.filter(e => e.kind === 'surface' && e.amount === 1 && e.unitId === unit.id).length, 1);
});

test('strict restore rejects impossible Ice metadata and requires frozen reactions to carry Ice', () => {
  const state = createSimGame(), unit = state.units[0]; equip(unit, 'frostbite');
  const frozen = resolveRound(state, [plan(cast(unit, 'frostbite')), empty()]);
  for (const mutate of [
    (s: SimState) => { (getCell(s, unit.q, unit.r)! as unknown as { ice: unknown }).ice = false; },
    (s: SimState) => { field(getCell(s, unit.q, unit.r)!, ['fire', 'water'], true); },
    (s: SimState) => { field(getCell(s, unit.q, unit.r)!, ['earth'], true); },
    (s: SimState) => { delete getCell(s, unit.q, unit.r)!.ttl; },
    (s: SimState) => { field(getCell(s, unit.q, unit.r)!, ['water', 'air']); },
  ]) { const changed = structuredClone(frozen); mutate(changed); assert.throws(() => restoreSimState(changed)); }
});

test('returning champions can stand on Ice without inventing an entry direction, and the state restores', () => {
  const state = createSimGame(), unit = state.units[0]; unit.hp = 0; unit.respawn = 2;
  for (const cell of state.cells) field(cell, cell.terrain === 'earth' ? ['water', 'earth'] : ['water'], true);
  assert.deepEqual(restoreSimState(state), state);
  const result = resolveRound(state, [empty(), empty()]), returned = result.units[0];
  assert.equal(returned.hp, returned.maxHp); assert.equal(returned.respawn, undefined);
  assert.equal(isIce(getCell(result, returned.q, returned.r)!), true);
  assert.equal(result.lastResolution.filter(e => e.unitId === returned.id && e.kind === 'respawn').length, 1);
  assert.equal(result.lastResolution.some(e => e.unitId === returned.id && (e.kind === 'move' || e.kind === 'push')), false);
  assert.deepEqual(restoreSimState(result), result);
});

test('all 78 spells resolve from legal seeded positions, retain strict restores and never mutate their input', () => {
  for (const spell of ALL_SPELLS) {
    const champion = spell.signatureChampionId ?? 'oh_tipi';
    const other = CHAMPIONS.filter(c => c.id !== champion).slice(0, 2).map(c => c.id);
    const state = createSimGame([[champion, ...other], ['oh_tipi', 's_wayne', 'treevor_mason']]), unit = state.units[0];
    if (!spell.signatureChampionId) equip(unit, spell.id);
    const target = legalCasts(state, unit.id, undefined, spell.id)[0]; assert.ok(target, spell.id);
    const before = structuredClone(state), result = resolveRound(state, [plan(cast(unit, spell.id, target)), empty()]);
    assert.deepEqual(state, before, spell.id); assert.deepEqual(restoreSimState(result), result, spell.id);
  }
});

test('public-state AI can play seeded V8 matches through new surfaces with legal plans and restorable rounds', () => {
  for (const seed of ['WELLSPRING', 'ICE-RIVER']) {
    let state = createSimGame(undefined, `frontier:${seed}`);
    for (let round = 0; round < 8 && state.winner === null; round++) {
      const plans = [chooseAIPlan(state, 0), chooseAIPlan(state, 1)] as [TeamPlan, TeamPlan];
      plans.forEach((p, player) => assert.deepEqual(validatePlan(state, player as 0 | 1, p), p));
      state = resolveRound(state, plans); assert.deepEqual(restoreSimState(state), state);
    }
  }
});
