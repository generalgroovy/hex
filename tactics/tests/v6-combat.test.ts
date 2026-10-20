/** Live rules-6 combat regression fixtures. Historical version suites remain unchanged. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { CHAMPIONS, MAX_ROUNDS, SPELLS, REACTIONS, castAvailability, chooseAIPlan, createSimGame, defaultLoadout, getCell, getSpell, isAlive, legalCasts, legalMoves, movementPath, previewPlan, reactionsFor, resolveRound, restoreSimState, spellArea, spellCost, validateLoadout, validatePlan } from '../lib/tactics.ts';
import type { Element, Order, Player, Point, SimState, SimUnit, StatusId, TeamPlan } from '../lib/tactics.ts';

const empty = (): TeamPlan => ({ orders: [] });
const plan = (...orders: Order[]): TeamPlan => ({ orders });
const at = (unit: SimUnit, q: number, r: number) => { unit.q = q; unit.r = r; };
const equip = (unit: SimUnit, ...ids: string[]) => { unit.loadout = [...ids, ...SPELLS.map((spell) => spell.id).filter((id) => !ids.includes(id))].slice(0, 4); };
const cast = (unit: SimUnit, spellId: string, q: number, r: number): Order => ({ unitId: unit.id, spellId, cast: { q, r } });
const away = (unit: SimUnit): Order => { equip(unit, 'stone'); return cast(unit, 'stone', unit.q, unit.r + (unit.owner === 0 ? -1 : 1)); };
function duel(): SimState {
  const state = createSimGame([['s_wayne', 'oh_tipi', 'treevor_mason'], ['s_wayne', 'oh_tipi', 'treevor_mason']]);
  at(state.units[0], -1, 0); at(state.units[3], 1, 0); return state;
}
function invert(state: SimState): SimState {
  const next = structuredClone(state); const flip = (id: string) => `${1 - Number(id[0])}${id.slice(1)}`;
  next.units = state.units.map((unit) => ({ ...structuredClone(unit), id: flip(unit.id), owner: (1 - unit.owner) as Player, q: -unit.q || 0, r: -unit.r || 0 }));
  next.cells = state.cells.map((cell) => ({ ...structuredClone(cell), q: -cell.q || 0, r: -cell.r || 0 }));
  next.scores = [state.scores[1], state.scores[0]]; next.winner = typeof state.winner === 'number' ? (1 - state.winner) as Player : state.winner;
  next.log = []; next.lastResolution = []; return next;
}
function invertPlan(input: TeamPlan): TeamPlan {
  const flip = (at: Point) => ({ q: -at.q || 0, r: -at.r || 0 });
  return { orders: input.orders.map((order) => ({ ...order, unitId: `${1 - Number(order.unitId[0])}${order.unitId.slice(1)}`, ...(order.move ? { move: flip(order.move) } : {}), ...(order.cast ? { cast: flip(order.cast) } : {}) })) };
}
function physical(state: SimState) {
  return { round: state.round, version: state.version, scores: state.scores, winner: state.winner,
    units: [...state.units].sort((a, b) => a.id.localeCompare(b.id)), cells: [...state.cells].sort((a, b) => a.q - b.q || a.r - b.r) };
}
function field(state: SimState, q: number, r: number, elements: Element[]): void {
  const cell = getCell(state, q, r)!; cell.elements = (['fire', 'water', 'earth', 'air', 'light', 'dark'] as Element[]).filter((element) => elements.includes(element));
  cell.reactions = reactionsFor(elements); cell.terrain = cell.reactions[0] ?? cell.elements[0]; cell.ttl = 1;
}

test('all 30 canonical champions can equip all six elements; 48 spells provide eight per element', () => {
  assert.equal(CHAMPIONS.length, 30); assert.equal(SPELLS.length, 48); assert.equal(new Set(SPELLS.map((spell) => spell.id)).size, 48);
  for (const element of ['fire', 'water', 'air', 'earth', 'light', 'dark']) assert.equal(SPELLS.filter((spell) => spell.element === element).length, 8);
  for (const champion of CHAMPIONS) {
    const loadout = defaultLoadout(champion.id); assert.equal(new Set(loadout).size, 4);
    for (const spell of SPELLS) {
      const selected = [spell.id, ...SPELLS.filter((entry) => entry.id !== spell.id).slice(0, 3).map((entry) => entry.id)];
      assert.deepEqual(validateLoadout(champion.id, selected), selected);
      const affinity = champion.affinities[spell.element] ?? 0;
      assert.equal(spellCost(champion.id, spell.id), Math.max(1, spell.cost + (affinity === 0 ? 1 : affinity === 2 ? -1 : 0)));
    }
  }
  assert.throws(() => validateLoadout(CHAMPIONS[0].id, ['ember', 'ember', 'stone', 'gust']));
  assert.throws(() => validateLoadout(CHAMPIONS[0].id, ['ember', 'stone', 'gust', 'invented']));
});

test('plans reject foreign, duplicate, unequipped, cooling, unaffordable and malformed orders without mutation', () => {
  const state = duel(); equip(state.units[0], 'ember'); const before = JSON.stringify(state);
  for (const input of [
    { orders: [cast(state.units[3], 'ember', 0, 0)] },
    { orders: [cast(state.units[0], 'ember', 0, 0), cast(state.units[0], 'ember', 0, 0)] },
    { orders: [cast(state.units[0], 'eclipse', 0, 0)] },
    { orders: [{ ...cast(state.units[0], 'ember', 0, 0), guard: true }] },
    { orders: [{ unitId: state.units[0].id, spellId: 'ember' }] },
    { orders: [{ ...cast(state.units[0], 'ember', 0, 0), extra: 1 }] },
    { orders: [{ unitId: state.units[0].id, move: { q: 100, r: 0 } }] },
  ]) assert.throws(() => validatePlan(state, 0, input));
  assert.equal(JSON.stringify(state), before);
  state.units[0].cooldowns.ember = 1; assert.throws(() => validatePlan(state, 0, plan(cast(state.units[0], 'ember', 0, 0))));
  delete state.units[0].cooldowns.ember; state.units[0].flux = 0; assert.throws(() => validatePlan(state, 0, plan(cast(state.units[0], 'ember', 0, 0))));
});

test('Flux is spent once at affinity price, Guard recovers extra, and cooldown consumes complete planning rounds', () => {
  const state = duel(); equip(state.units[0], 'siphon'); state.units[0].flux = 4;
  const first = resolveRound(state, [plan(cast(state.units[0], 'siphon', 1, 0)), empty()]);
  assert.equal(first.units[0].flux, 4, 'cost2 then regen2'); assert.equal(first.units[0].cooldowns.siphon, 1);
  assert.equal(castAvailability(first, state.units[0].id, 'siphon').available, false);
  const second = resolveRound(first, [empty(), empty()]);
  assert.equal(second.units[0].flux, 6); assert.equal(second.units[0].cooldowns.siphon, undefined);
});

test('every catalog spell can legally resolve with its complete public save state', () => {
  for (const spell of SPELLS) {
    const state = duel(); equip(state.units[0], spell.id);
    const target = spell.range === 0 ? state.units[0] : { q: 0, r: 0 };
    assert.ok(legalCasts(state, state.units[0].id, undefined, spell.id).some((cell) => cell.q === target.q && cell.r === target.r), spell.id);
    const result = resolveRound(state, [plan(cast(state.units[0], spell.id, target.q, target.r)), empty()]);
    assert.ok(result.lastResolution.some((event) => event.kind === 'cast' && event.spellId === spell.id), spell.id);
    assert.deepEqual(restoreSimState(result), result, spell.id);
  }
});

test('new Root and Concussion cannot cancel a sealed spell and Resolve prevents the next control lock', () => {
  const state = duel(); equip(state.units[0], 'grasping_roots'); equip(state.units[3], 'thunderclap');
  const first = resolveRound(state, [plan(cast(state.units[0], 'grasping_roots', 1, 0)), plan(cast(state.units[3], 'thunderclap', -1, 0))]);
  assert.ok(first.units[0].statuses.concussed); assert.ok(first.units[3].statuses.rooted);
  assert.equal(first.lastResolution.filter((event) => event.kind === 'cast').length, 2);
  assert.equal(legalMoves(first, first.units[3].id).length, 0);
  assert.ok(legalCasts(first, first.units[3].id, undefined, first.units[3].loadout[1]).length > 0, 'rooted unit retains spell agency');
  first.units[0].cooldowns = {}; first.units[0].flux = 6;
  const second = resolveRound(first, [plan(cast(first.units[0], 'grasping_roots', 1, 0)), empty()]);
  assert.equal(second.units[3].statuses.rooted, undefined); assert.ok(second.units[3].statuses.resolve);
  assert.ok(legalMoves(second, second.units[3].id).length > 0);
});

test('Blind changes next range, Chilled and Haste compose, and Anchor resists forced movement only', () => {
  const state = duel(); const unit = state.units[0]; equip(unit, 'fire_lance');
  const normal = legalCasts(state, unit.id, undefined, 'fire_lance').length; unit.statuses.blind = { turns: 1, power: 1 };
  assert.ok(legalCasts(state, unit.id, undefined, 'fire_lance').length < normal);
  unit.statuses = { chilled: { turns: 1, power: 1 } }; assert.equal(movementPath(state, unit.id, { q: -3, r: 0 }), null);
  unit.statuses.haste = { turns: 1, power: 1 }; assert.ok(movementPath(state, unit.id, { q: -3, r: 0 }));
  unit.statuses = { anchored: { turns: 1, power: 1 } }; assert.ok(legalMoves(state, unit.id).length > 0);
  equip(state.units[3], 'gust'); const result = resolveRound(state, [plan(cast(unit, 'fire_lance', -2, 0)), plan(cast(state.units[3], 'gust', -1, 0))]);
  assert.equal(result.units[0].q, -1);
});

test('opposing Fire and Water combine before damage and Wet extinguishes both old and fresh Burn', () => {
  const state = duel(); at(state.units[1], 0, 0); equip(state.units[0], 'ember'); equip(state.units[3], 'water_jet');
  state.units[1].statuses.burn = { turns: 1, power: 1 };
  const result = resolveRound(state, [plan(cast(state.units[0], 'ember', 0, 0)), plan(cast(state.units[3], 'water_jet', 0, 0))]);
  assert.equal(result.units[1].hp, 7, '4 combined, Steam halves2, Guard absorbs1; Wet prevents old Burn');
  assert.equal(result.units[1].statuses.burn, undefined); assert.ok(result.units[1].statuses.wet);
  assert.deepEqual(getCell(result, 0, 0)!.reactions, ['steam']);
});

test('a Fire Water Earth triple applies each pair once and is independent of order-array permutation', () => {
  const state = duel(); at(state.units[1], -1, 1); at(state.units[4], 0, 0);
  equip(state.units[0], 'ember'); equip(state.units[1], 'stone'); equip(state.units[3], 'water_jet');
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[0], 'ember', 0, 0), cast(state.units[1], 'stone', 0, 0)), plan(cast(state.units[3], 'water_jet', 0, 0))];
  const result = resolveRound(state, plans);
  assert.deepEqual(getCell(result, 0, 0)!.reactions, ['steam', 'magma', 'quagmire']); assert.equal(result.units[4].hp, 5);
  assert.deepEqual(result, resolveRound(state, [{ orders: [...plans[0].orders].reverse() }, plans[1]]));
});

test('all 15 distinct element pairs form from opposing team casts, symmetrically and without recursive products', () => {
  assert.equal(REACTIONS.length, 15); assert.equal(new Set(REACTIONS.map((reaction) => [...reaction.elements].sort().join('+'))).size, 15);
  const basic: Record<Element, string> = { fire: 'ember', water: 'water_jet', earth: 'stone', air: 'gust', light: 'radiant_bolt', dark: 'wither_bolt' };
  for (const reaction of REACTIONS) {
    const state = duel(); at(state.units[1], 0, 0);
    const spells = reaction.elements.map((element) => basic[element]); equip(state.units[0], spells[0]); equip(state.units[3], spells[1]);
    const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[0], spells[0], 0, 0)), plan(cast(state.units[3], spells[1], 0, 0))];
    const result = resolveRound(state, plans);
    assert.deepEqual(getCell(result, 0, 0)!.reactions, [reaction.id], reaction.id);
    assert.equal(getCell(result, 0, 0)!.elements!.length, 2, 'products never become new elements');
    assert.deepEqual(physical(invert(result)), physical(resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])])), reaction.id);
    assert.deepEqual(restoreSimState(result), result);
  }
});

test('persistent chemistry changes next decisions for either team rather than supplying names alone', () => {
  const expected: [string, StatusId][] = [['sandblast', 'concussed'], ['crystal_prism', 'ward'], ['blightsoil', 'wither'], ['solar_flare', 'clarity'], ['backdraft', 'burn'], ['hailcurrent', 'chilled'], ['black_ice', 'rooted'], ['lightbend', 'haste'], ['shadowdraft', 'blind']];
  for (const [id, status] of expected) for (const owner of [0, 1] as const) {
    const state = duel(); const unit = state.units[owner * 3]; at(unit, 0, 0); field(state, 0, 0, REACTIONS.find((reaction) => reaction.id === id)!.elements);
    const result = resolveRound(state, [empty(), empty()]);
    assert.ok(result.units[owner * 3].statuses[status], `${id} grants ${status} to either team`);
    if (status === 'rooted') assert.equal(legalMoves(result, unit.id).length, 0);
    if (status === 'concussed') assert.equal(castAvailability(result, unit.id, unit.loadout[0]).cost, spellCost(unit.championId, unit.loadout[0]) + 1);
  }
  const heal = duel(); at(heal.units[0], 0, 0); heal.units[0].hp = 4; field(heal, 0, 0, ['water', 'light']);
  assert.equal(resolveRound(heal, [empty(), empty()]).units[0].hp, 5);
  heal.units[0].statuses.wither = { turns: 1, power: 1 }; assert.equal(resolveRound(heal, [empty(), empty()]).units[0].hp, 4, 'Wither reduces Mirrorwater in the same aggregate heal');
});

test('triple chemistry caps environmental harm, respects cleanse and control immunity, and never recursively expands', () => {
  const state = duel(); at(state.units[1], -1, 1); at(state.units[4], 0, 0);
  equip(state.units[0], 'ember'); equip(state.units[1], 'stone'); equip(state.units[3], 'gust');
  const formed = resolveRound(state, [plan(cast(state.units[0], 'ember', 0, 0), cast(state.units[1], 'stone', 0, 0)), plan(cast(state.units[3], 'gust', 0, 0))]);
  assert.deepEqual(getCell(formed, 0, 0)!.reactions, ['magma', 'sandblast', 'arcstorm']);
  const environmental = formed.lastResolution.filter((event) => event.unitId === state.units[4].id && event.kind === 'surface' && event.amount);
  assert.equal(environmental.reduce((sum, event) => sum + event.amount!, 0), 1);
  assert.ok(formed.units[4].statuses.concussed);
  const solar = duel(); at(solar.units[0], 0, 0); field(solar, 0, 0, ['fire', 'air', 'light']);
  equip(solar.units[3], 'grasping_roots');
  const protectedState = resolveRound(solar, [empty(), plan(cast(solar.units[3], 'grasping_roots', 0, 0))]);
  assert.ok(protectedState.units[0].statuses.clarity); assert.equal(protectedState.units[0].statuses.rooted, undefined); assert.equal(protectedState.units[0].statuses.concussed, undefined);
  const lingering = duel(); at(lingering.units[0], 0, 0); field(lingering, 0, 0, ['fire', 'air']);
  assert.equal(resolveRound(lingering, [empty(), empty()]).units[0].hp, 8, 'existing Arcstorm has no recurring damage');
});

test('fresh Burn waits until the next resolution; cleanse cancels old Burn and incoming control', () => {
  const state = duel(); equip(state.units[0], 'ember');
  const first = resolveRound(state, [plan(cast(state.units[0], 'ember', 1, 0)), empty()]);
  assert.equal(first.units[3].hp, 7); assert.ok(first.units[3].statuses.burn);
  const next = resolveRound(first, [empty(), empty()]); assert.equal(next.units[3].hp, 6); assert.equal(next.units[3].statuses.burn, undefined);
  const rescue = duel(); at(rescue.units[4], 0, 1); equip(rescue.units[0], 'grasping_roots'); equip(rescue.units[4], 'cleansing_tide');
  rescue.units[3].hp = 5; rescue.units[3].statuses.burn = { turns: 1, power: 1 };
  const clean = resolveRound(rescue, [plan(cast(rescue.units[0], 'grasping_roots', 1, 0)), plan(cast(rescue.units[4], 'cleansing_tide', 1, 0))]);
  assert.equal(clean.units[3].hp, 7); assert.equal(clean.units[3].statuses.rooted, undefined); assert.equal(clean.units[3].statuses.burn, undefined);
});

test('fresh Ward starts next exchange; old Ward absorbs aggregate damage while Shatter bypasses it', () => {
  const state = duel(); at(state.units[4], 0, 1); equip(state.units[0], 'stone'); equip(state.units[4], 'aegis');
  const fresh = resolveRound(state, [plan(cast(state.units[0], 'stone', 1, 0)), plan(cast(state.units[4], 'aegis', 1, 0))]);
  assert.equal(fresh.units[3].hp, 7); assert.equal(fresh.units[3].statuses.ward?.power, 3);
  const protectedState = duel(); equip(protectedState.units[0], 'shatter'); protectedState.units[3].statuses.ward = { turns: 1, power: 3 };
  const shattered = resolveRound(protectedState, [plan(cast(protectedState.units[0], 'shatter', 1, 0)), empty()]);
  assert.equal(shattered.units[3].hp, 6, 'piercing3 minus Guard1 bypasses Ward3');
});

test('Wither affects the existing exchange only, and cleanse restores full healing before simultaneous hits', () => {
  const state = duel(); at(state.units[4], 0, 1); equip(state.units[0], 'wither_bolt'); equip(state.units[4], 'mend'); state.units[3].hp = 4;
  const fresh = resolveRound(state, [plan(cast(state.units[0], 'wither_bolt', 1, 0)), plan(cast(state.units[4], 'mend', 1, 0))]);
  assert.equal(fresh.units[3].hp, 6, 'new Wither does not retroactively reduce3 healing against1 damage');
  state.units[3].statuses.wither = { turns: 2, power: 1 };
  const old = resolveRound(state, [empty(), plan(cast(state.units[4], 'mend', 1, 0))]); assert.equal(old.units[3].hp, 6);
  equip(state.units[4], 'cleansing_tide'); const clean = resolveRound(state, [empty(), plan(cast(state.units[4], 'cleansing_tide', 1, 0))]); assert.equal(clean.units[3].hp, 6);
});

test('mutual Siphons heal in the same exchange without iteration bias; simultaneous lethal hits can trade', () => {
  const state = duel(); equip(state.units[0], 'siphon'); equip(state.units[3], 'siphon'); state.units[0].hp = 2; state.units[3].hp = 2;
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[0], 'siphon', 1, 0)), plan(cast(state.units[3], 'siphon', -1, 0))];
  const result = resolveRound(state, plans); assert.equal(result.units[0].hp, 1); assert.equal(result.units[3].hp, 1);
  assert.deepEqual(physical(invert(result)), physical(resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])])));
  equip(state.units[0], 'stone'); equip(state.units[3], 'stone');
  const traded = resolveRound(state, [plan(cast(state.units[0], 'stone', 1, 0)), plan(cast(state.units[3], 'stone', -1, 0))]);
  assert.equal(traded.units[0].hp, 0); assert.equal(traded.units[3].hp, 0); assert.deepEqual(traded.scores, [1, 1]);
  const returned = resolveRound(traded, [empty(), empty()]); assert.equal(returned.units[0].hp, 8); assert.equal(returned.round, 3); assert.deepEqual(returned.scores, [1, 1]);
});

test('competing Flux theft is allocated from post-cost reserves without first-caster priority', () => {
  const state = createSimGame([['s_wayne', 'treevor_mason', 'oh_tipi'], ['s_wayne', 'treevor_mason', 'oh_tipi']]);
  at(state.units[0], -1, 0); at(state.units[1], -1, 1); at(state.units[3], 0, 0);
  for (const unit of [state.units[0], state.units[1]]) { equip(unit, 'essence_theft'); unit.flux = spellCost(unit.championId, 'essence_theft') + 1; }
  state.units[3].flux = 3;
  const orders = [cast(state.units[0], 'essence_theft', 0, 0), cast(state.units[1], 'essence_theft', 0, 0)];
  const result = resolveRound(state, [plan(...orders), empty()]);
  assert.equal(result.units[0].flux, 4); assert.equal(result.units[1].flux, 4); assert.equal(result.units[3].flux, 4);
  assert.deepEqual(result, resolveRound(state, [plan(...orders.reverse()), empty()]));
});

test('simultaneous movement swaps, contested landings and ground dodges retain symmetric outcomes', () => {
  const state = duel(); const collision = resolveRound(state, [plan({ unitId: state.units[0].id, move: { q: 0, r: 0 } }), plan({ unitId: state.units[3].id, move: { q: 0, r: 0 } })]);
  assert.equal(collision.units[0].q, -1); assert.equal(collision.units[3].q, 1);
  at(state.units[0], 0, -1); at(state.units[3], 0, 0);
  const swapped = resolveRound(state, [plan({ unitId: state.units[0].id, move: { q: 0, r: 0 } }), plan({ unitId: state.units[3].id, move: { q: 0, r: -1 } })]);
  assert.equal(swapped.units[0].r, 0); assert.equal(swapped.units[3].r, -1);
  equip(state.units[0], 'ember'); const dodge = resolveRound(state, [plan(cast(state.units[0], 'ember', 0, 0)), plan({ unitId: state.units[3].id, move: { q: 1, r: 0 } })]);
  assert.equal(dodge.units[3].hp, 8);
});

test('a clear tied line ray cannot make its blocked alternate ray hit through a barrier', () => {
  const state = duel(); at(state.units[0], 0, 0); equip(state.units[0], 'fire_lance');
  getCell(state, 1, 0)!.barrier = 1;
  const area = spellArea(state, state.units[0].id, 'fire_lance', { q: 1, r: 1 });
  assert.ok(area.some((cell) => cell.q === 0 && cell.r === 1));
  assert.ok(!area.some((cell) => cell.q === 1 && cell.r === 0));
  assert.ok(area.some((cell) => cell.q === 1 && cell.r === 1));
});

test('one diagonal displacement still moves and its geometric tie is inversion symmetric', () => {
  const state = duel(); at(state.units[0], -1, -1); at(state.units[3], 0, 0); equip(state.units[0], 'gust'); equip(state.units[3], 'stone');
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[0], 'gust', 0, 0)), plan(cast(state.units[3], 'stone', 0, 1))];
  const result = resolveRound(state, plans); assert.ok(result.units[3].q !== 0 || result.units[3].r !== 0);
  assert.deepEqual(physical(invert(result)), physical(resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])])));
});

test('full two-step displacement stops at occupancy and opposing vectors cancel', () => {
  const state = duel(); at(state.units[0], -1, 0); at(state.units[3], 0, 0); at(state.units[4], 2, 0); equip(state.units[0], 'gale'); equip(state.units[3], 'stone');
  const pushed = resolveRound(state, [plan(cast(state.units[0], 'gale', 0, 0)), plan(cast(state.units[3], 'stone', 0, 1))]);
  assert.equal(pushed.units[3].q, 1, 'second step blocked by stationary occupant at2,0');
  at(state.units[4], 1, 0); equip(state.units[4], 'gust'); equip(state.units[0], 'gust');
  const cancelled = resolveRound(state, [plan(cast(state.units[0], 'gust', 0, 0)), plan(cast(state.units[4], 'gust', 0, 0), cast(state.units[3], 'stone', 0, 1))]);
  assert.equal(cancelled.units[3].q, 0);
});

test('strict save restoration rejects forged resources, spell inventory, statuses, relationships and geometry', () => {
  const valid = createSimGame();
  const mutations: ((state: SimState) => void)[] = [
    (state) => { state.version++; }, (state) => { state.scores = [8, 7]; }, (state) => { state.units[0].flux = 7; },
    (state) => { state.units[0].loadout[0] = 'forged'; }, (state) => { state.units[0].cooldowns.ember = 99; },
    (state) => { state.units[0].statuses.rooted = { turns: 99, power: 1 }; },
    (state) => { state.cells[0].height = 1; }, (state) => { at(state.units[0], state.units[1].q, state.units[1].r); },
  ];
  for (const mutate of mutations) { const changed = structuredClone(valid); mutate(changed); assert.throws(() => restoreSimState(changed)); }
  assert.throws(() => restoreSimState({ ...valid, enemyPlan: {} }));
});

test('previews expose equipped spell, real Flux cost, own chemistry and collateral without enemy orders', () => {
  const state = duel(); at(state.units[1], 0, 0); equip(state.units[0], 'wildfire');
  const text = previewPlan(state, 0, plan(cast(state.units[0], 'wildfire', 0, 0))).join('\n');
  assert.match(text, /Wildfire/); assert.match(text, /Flux/); assert.match(text, /friendly fire/); assert.match(text, /hidden/);
});

test('public-state AI produces reproducible legal complete games and no known friendly damage footprint', () => {
  let state = createSimGame([CHAMPIONS.slice(0, 3).map((champion) => champion.id), CHAMPIONS.slice(15, 18).map((champion) => champion.id)]);
  const before = JSON.stringify(state); assert.deepEqual(chooseAIPlan(state, 0), chooseAIPlan(state, 0)); assert.equal(JSON.stringify(state), before);
  for (let round = 0; state.winner === null && round < MAX_ROUNDS; round++) {
    const plans: [TeamPlan, TeamPlan] = [chooseAIPlan(state, 0), chooseAIPlan(state, 1)];
    for (const input of plans) for (const order of input.orders) if (order.cast && getSpell(order.spellId!).damage && getSpell(order.spellId!).harm === 'all') {
      const area = spellArea(state, order.unitId, order.spellId!, order.cast, order.move);
      assert.ok(!input.orders.some((friend) => area.some((cell) => { const end = friend.move ?? state.units.find((unit) => unit.id === friend.unitId)!; return cell.q === end.q && cell.r === end.r; })));
    }
    state = resolveRound(state, plans); assert.deepEqual(restoreSimState(state), state);
    const living = state.units.filter(isAlive); assert.equal(new Set(living.map((unit) => `${unit.q},${unit.r}`)).size, living.length);
  }
  assert.notEqual(state.winner, null);
});

test('enemy Cauterize cannot let incoming Burn bypass a friendly cleanse', () => {
  const state = createSimGame(); at(state.units[0], 0, 0); at(state.units[1], -1, 0);
  at(state.units[3], 1, 0); at(state.units[4], 1, -1);
  equip(state.units[1], 'clear_sight'); equip(state.units[3], 'ember'); equip(state.units[4], 'cauterize');
  state.units[0].statuses.burn = { turns: 1, power: 1 };
  const plans: [TeamPlan, TeamPlan] = [plan(cast(state.units[1], 'clear_sight', 0, 0)), plan(cast(state.units[3], 'ember', 0, 0), cast(state.units[4], 'cauterize', 0, 0))];
  const resolved = resolveRound(state, plans);
  assert.equal(resolved.units[0].statuses.burn, undefined, 'an enemy support spell must not create the friendly Cauterize exception');
  assert.ok(resolved.units[0].statuses.clarity); assert.equal(resolved.units[0].hp, 7, 'cleanse removes old Burn before the aggregate exchange');
  assert.deepEqual(resolved, resolveRound(state, [plans[0], { orders: [...plans[1].orders].reverse() }]));
  assert.deepEqual(physical(invert(resolved)), physical(resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])])));
  assert.deepEqual(restoreSimState(resolved), resolved);
});

test('friendly Cauterize still grants its promised fresh Burn tradeoff, and Wet still extinguishes it', () => {
  const state = createSimGame(); at(state.units[0], 0, 0); at(state.units[1], -1, 0); at(state.units[2], 0, -1);
  equip(state.units[0], 'water_jet'); equip(state.units[1], 'cauterize'); equip(state.units[2], 'clear_sight'); state.units[0].hp = 3;
  const support = [cast(state.units[1], 'cauterize', 0, 0), cast(state.units[2], 'clear_sight', 0, 0)];
  const restored = resolveRound(state, [plan(...support), empty()]);
  assert.equal(restored.units[0].hp, 6); assert.ok(restored.units[0].statuses.burn, 'friendly Burn cost remains even beside another cleanse');
  const wet = resolveRound(state, [plan(...support, cast(state.units[0], 'water_jet', 0, 0)), empty()]);
  assert.equal(wet.units[0].statuses.burn, undefined); assert.ok(wet.units[0].statuses.wet);
});

test('current arena Penumbra scoring evaluates both teams before declaring a winner', () => {
  const state = duel(); at(state.units[1], 0, 0); at(state.units[4], 0, 4);
  equip(state.units[0], 'radiant_bolt'); equip(state.units[3], 'wither_bolt'); state.scores = [6, 7];
  const resolved = resolveRound(state, [plan(cast(state.units[0], 'radiant_bolt', 0, 0)), plan(cast(state.units[3], 'wither_bolt', 0, 0))]);
  assert.deepEqual(resolved.scores, [8, 8]); assert.equal(resolved.winner, null); assert.equal(getCell(resolved, 0, 0)!.ttl, 1);
  assert.deepEqual(restoreSimState(resolved), resolved);
});
