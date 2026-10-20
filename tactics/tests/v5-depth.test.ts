import test from 'node:test';
import assert from 'node:assert/strict';
import { BOARD_RADIUS, BOARD_SIZE, CHAMPIONS, SPELLS, castAvailability, chooseAIPlan, createSimGame, defaultLoadout, getCell, getSpell, legalCasts, legalMoves, movementPath, previewPlan, resolveRound, restoreSimState, spellArea } from '../lib/tactics-v5.ts';
import { createSimGame as createV4, restoreSimState as restoreV4 } from '../lib/tactics-v4.ts';
import type { Point, SimState, SimUnit, TeamPlan } from '../lib/tactics-v5.ts';

const empty: TeamPlan = { orders: [] };
const key = (point: Point) => `${point.q || 0},${point.r || 0}`;
const keys = (points: Point[]) => points.map(key).sort();
const rotate = ({ q, r }: Point): Point => ({ q: -r || 0, r: q + r || 0 });
const equip = (unit: SimUnit, spell: string) => { unit.loadout = [spell, ...SPELLS.filter((entry) => entry.id !== spell).slice(0, 3).map((entry) => entry.id)]; };
const cast = (unit: SimUnit, spellId: string, q: number, r: number) => ({ unitId: unit.id, spellId, cast: { q, r } });
const at = (unit: SimUnit, q: number, r: number) => Object.assign(unit, { q, r });

test('every fresh starter kit has four unique spells and a native multihex signature', () => {
  for (const champion of CHAMPIONS) {
    const kit = defaultLoadout(champion.id); assert.equal(new Set(kit).size, 4);
    assert.ok(kit.some((id) => getSpell(id).element === champion.element && getSpell(id).shape !== 'hex'), champion.id);
    const custom = ['ember', 'water_jet', 'stone', 'mend'];
    const state = createSimGame([[champion.id, ...CHAMPIONS.filter((entry) => entry.id !== champion.id).slice(0, 2).map((entry) => entry.id)], ['oh_tipi', 'wa_bidi', 'treevor_mason']], 'confluence', [{ [champion.id]: custom }, {}]);
    assert.deepEqual(state.units[0].loadout, custom, 'explicit saved/custom kit stays intact');
  }
});

test('v5 expands to 61 mirrored hexes with separated wells and useful flanks; v4 remains readable unchanged', () => {
  const state = createSimGame();
  assert.equal(state.rulesVersion, 5); assert.equal(BOARD_RADIUS, 4); assert.equal(BOARD_SIZE, 61); assert.equal(state.cells.length, 61);
  assert.equal(new Set(keys(state.cells)).size, 61);
  assert.deepEqual(keys(state.cells.filter((cell) => cell.well)), ['0,-3', '0,0', '0,3']);
  assert.equal(state.cells.filter((cell) => cell.height).length, 4);
  for (const cell of state.cells) {
    const mirror = getCell(state, -cell.q, -cell.r)!;
    assert.equal(mirror.height, cell.height); assert.equal(mirror.well, cell.well);
  }
  for (const unit of state.units) assert.equal(getCell(state, unit.q, unit.r)!.height, 0);
  assert.deepEqual(restoreSimState(state), state);
  for (const changed of [
    { ...state, cells: state.cells.slice(1) },
    { ...state, cells: [...state.cells.slice(1), state.cells[1]] },
    { ...state, cells: state.cells.map((cell) => cell.q === 0 && cell.r === 0 ? { ...cell, well: false } : cell) },
  ]) assert.throws(() => restoreSimState(changed));
  const old = createV4(); assert.equal(old.cells.length, 37); assert.equal(old.rulesVersion, 4);
  assert.deepEqual(restoreV4(old), old); assert.throws(() => restoreSimState(old)); assert.throws(() => restoreV4(state));
});

test('directional sweep and barrier footprints rotate through all six axes without tie bias', () => {
  const state = createSimGame(); const unit = at(state.units[0], 0, 0);
  for (const [spell, initial] of [
    ['tidal_surge', [{ q: 2, r: 0 }, { q: 2, r: -1 }, { q: 1, r: 1 }]],
    ['raise_cairn', [{ q: 2, r: 0 }, { q: 2, r: -1 }, { q: 2, r: 1 }]],
  ] as const) {
    equip(unit, spell); let target: Point = { q: 2, r: 0 }; let expected: Point[] = initial.map((point) => ({ ...point }));
    for (let turn = 0; turn < 6; turn++) {
      assert.deepEqual(keys(spellArea(state, unit.id, spell, target)), keys(expected), `${spell}, rotation ${turn}`);
      target = rotate(target); expected = expected.map(rotate);
    }
  }
});

test('directional targets require a distinct axial aim; height and Blind apply to their centre range', () => {
  const state = createSimGame(); const unit = at(state.units[0], 0, 0); equip(unit, 'tidal_surge');
  assert.ok(legalCasts(state, unit.id, undefined, 'tidal_surge').some((cell) => key(cell) === '2,0'));
  for (const target of [{ q: 0, r: 0 }, { q: 1, r: 1 }, { q: 3, r: 0 }]) {
    assert.ok(!legalCasts(state, unit.id, undefined, 'tidal_surge').some((cell) => key(cell) === key(target)));
  }
  assert.deepEqual(spellArea(state, unit.id, 'tidal_surge', { q: 1, r: 1 }), []);
  at(unit, 2, -1);
  assert.ok(legalCasts(state, unit.id, undefined, 'tidal_surge').some((cell) => key(cell) === '2,2'), 'raised caster reaches a lower centre three hexes away');
  unit.statuses.blind = { turns: 1, power: 1 };
  assert.ok(!legalCasts(state, unit.id, undefined, 'tidal_surge').some((cell) => key(cell) === '2,2'));
});

test('footprints clip at the arena boundary and use the planned landing for orientation', () => {
  const state = createSimGame(); const unit = at(state.units[0], 2, 0);
  assert.deepEqual(keys(spellArea(state, unit.id, 'raise_cairn', { q: 4, r: 0 })), ['4,-1', '4,0']);
  assert.deepEqual(keys(spellArea(state, unit.id, 'tidal_surge', { q: 4, r: 0 })), ['3,1', '4,-1', '4,0']);
  assert.deepEqual(keys(spellArea(state, unit.id, 'tidal_surge', { q: 0, r: 2 }, { q: 0, r: 0 })), ['-1,2', '0,2', '1,1']);
});

function sweepPosition(): SimState {
  const state = createSimGame();
  at(state.units[0], 0, 0); equip(state.units[0], 'tidal_surge');
  at(state.units[1], 0, 1); equip(state.units[1], 'stone');
  at(state.units[3], 1, 0); equip(state.units[3], 'stone');
  at(state.units[4], 1, -1); equip(state.units[4], 'stone');
  return state;
}
test('prepared formation: a sweep hits and displaces three occupants; moving the ally preserves the two-enemy catch', () => {
  const state = sweepPosition();
  const friendly: TeamPlan = { orders: [cast(state.units[0], 'tidal_surge', 1, 0), cast(state.units[1], 'stone', -1, 2)] };
  const rival: TeamPlan = { orders: [cast(state.units[3], 'stone', 2, 0), cast(state.units[4], 'stone', 2, -1)] };
  assert.ok(previewPlan(state, 0, friendly).some((line) => line.includes('friendly fire risk')));
  const exposed = resolveRound(state, [friendly, rival]);
  for (const index of [1, 3, 4]) { assert.equal(exposed.units[index].hp, 7); assert.ok(exposed.units[index].statuses.wet); }
  assert.deepEqual(keys([exposed.units[1], exposed.units[3], exposed.units[4]]), ['0,2', '2,-2', '2,0']);
  const repositioned = structuredClone(friendly); repositioned.orders[1].move = { q: -1, r: 1 };
  const safe = resolveRound(state, [repositioned, rival]);
  assert.equal(safe.units[1].hp, 8); assert.equal(safe.units[1].statuses.wet, undefined);
  for (const index of [3, 4]) assert.equal(safe.units[index].hp, 7);
  const waterCells = exposed.cells.filter((cell) => cell.elements?.includes('water'));
  assert.deepEqual(keys(waterCells), keys(spellArea(state, state.units[0].id, 'tidal_surge', { q: 1, r: 0 })), 'preview and resolved Water have identical footprints');
  assert.deepEqual(restoreSimState(exposed), exposed);
});

test('prepared barrier: a three-cell strip closes movement and sight, then expires after one further resolution', () => {
  const state = createSimGame(); equip(state.units[0], 'raise_cairn'); at(state.units[1], -2, 0); equip(state.units[1], 'stone');
  assert.ok(movementPath(state, state.units[1].id, { q: -1, r: 0 }));
  assert.ok(legalCasts(state, state.units[1].id, undefined, 'stone').some((cell) => key(cell) === '0,0'));
  const raised = resolveRound(state, [{ orders: [cast(state.units[0], 'raise_cairn', -1, 0)] }, empty]);
  assert.deepEqual(keys(raised.cells.filter((cell) => cell.barrier)), ['-1,-1', '-1,0', '-1,1']);
  assert.equal(movementPath(raised, state.units[1].id, { q: -1, r: 0 }), null);
  assert.ok(!legalCasts(raised, state.units[1].id, undefined, 'stone').some((cell) => key(cell) === '0,0'));
  assert.equal(castAvailability(raised, state.units[0].id, 'raise_cairn').available, false);
  const faded = resolveRound(raised, [empty, empty]); assert.equal(faded.cells.some((cell) => cell.barrier), false);
  assert.ok(movementPath(faded, state.units[1].id, { q: -1, r: 0 }));
});

test('a barrier strip leaves wells and occupied cells open; simultaneous Shatter wins over creation', () => {
  const state = createSimGame(); at(state.units[0], -2, 0); equip(state.units[0], 'raise_cairn');
  at(state.units[1], 0, 1); at(state.units[3], 1, -1); equip(state.units[3], 'shatter');
  const raise: TeamPlan = { orders: [cast(state.units[0], 'raise_cairn', 0, 0)] };
  const closed = resolveRound(state, [raise, empty]);
  assert.deepEqual(keys(closed.cells.filter((cell) => cell.barrier)), ['0,-1']);
  const shattered = resolveRound(state, [raise, { orders: [cast(state.units[3], 'shatter', 0, -1)] }]);
  assert.equal(shattered.cells.some((cell) => cell.barrier), false);
});

test('simultaneous sweep exchange and barrier placement preserve mirrored outcomes and order-array independence', () => {
  const flip = ({ q, r }: Point): Point => ({ q: -q || 0, r: -r || 0 });
  const identity = (id: string) => `${1 - Number(id[0])}${id.slice(1)}`;
  const invert = (state: SimState): SimState => ({ ...structuredClone(state), scores: [state.scores[1], state.scores[0]],
    units: state.units.map((unit) => ({ ...structuredClone(unit), ...flip(unit), id: identity(unit.id), owner: (1 - unit.owner) as 0 | 1 })),
    cells: state.cells.map((cell) => ({ ...structuredClone(cell), ...flip(cell) })),
  });
  const invertPlan = (plan: TeamPlan): TeamPlan => ({ orders: plan.orders.map((order) => ({ ...order, unitId: identity(order.unitId), ...(order.move ? { move: flip(order.move) } : {}), ...(order.cast ? { cast: flip(order.cast) } : {}) })) });
  const physical = (state: SimState) => ({ scores: state.scores, units: [...state.units].sort((left, right) => left.id.localeCompare(right.id)), cells: [...state.cells].sort((left, right) => left.q - right.q || left.r - right.r) });
  const state = sweepPosition(); equip(state.units[2], 'raise_cairn');
  const plans: [TeamPlan, TeamPlan] = [
    { orders: [cast(state.units[0], 'tidal_surge', 1, 0), cast(state.units[1], 'stone', -1, 2), cast(state.units[2], 'raise_cairn', -2, 2)] },
    { orders: [cast(state.units[3], 'stone', 2, 0), cast(state.units[4], 'stone', 2, -1)] },
  ];
  const resolved = resolveRound(state, plans);
  assert.deepEqual(physical(invert(resolved)), physical(resolveRound(invert(state), [invertPlan(plans[1]), invertPlan(plans[0])])));
  assert.deepEqual(resolved, resolveRound(state, plans.map((plan) => ({ orders: [...plan.orders].reverse() })) as [TeamPlan, TeamPlan]));
});

test('a collision-dependent cast is disclosed and fizzles without spending Flux or cooldown', () => {
  const state = createSimGame(); const unit = state.units[0]; equip(unit, 'ember'); unit.flux = 3;
  at(state.units[3], 0, -1);
  const plan: TeamPlan = { orders: [{ unitId: unit.id, move: { q: -1, r: 0 }, spellId: 'ember', cast: { q: 1, r: 0 } }] };
  assert.ok(previewPlan(state, 0, plan).some((line) => line.includes('depends on the landing')));
  const bounced = resolveRound(state, [plan, { orders: [{ unitId: state.units[3].id, move: { q: -1, r: 0 } }] }]);
  assert.ok(bounced.lastResolution.some((event) => event.kind === 'fizzle' && event.unitId === unit.id));
  assert.equal(bounced.units[0].flux, 5); assert.deepEqual(bounced.units[0].cooldowns, {});
});

test('every spell still legally resolves and survives strict v5 save validation', () => {
  for (const spell of SPELLS) {
    const state = createSimGame(); const unit = at(state.units[0], -1, 0); equip(unit, spell.id);
    const target = spell.range ? { q: 0, r: 0 } : unit;
    assert.ok(legalCasts(state, unit.id, undefined, spell.id).some((cell) => key(cell) === key(target)), spell.id);
    const resolved = resolveRound(state, [{ orders: [cast(unit, spell.id, target.q, target.r)] }, empty]);
    assert.ok(resolved.lastResolution.some((event) => event.kind === 'cast' && event.spellId === spell.id), spell.id);
    assert.deepEqual(restoreSimState(resolved), resolved, spell.id);
  }
});

test('bot is deterministic, public-state-only and retains an origin-valid cast when its landing is contestable', () => {
  const state = createSimGame(); const before = structuredClone(state);
  assert.deepEqual(chooseAIPlan(state, 0), chooseAIPlan(state, 0)); assert.deepEqual(state, before);
  for (let round = 0; state.winner === null && round < 6; round++) {
    for (const player of [0, 1] as const) {
      const contestable = new Set(state.units.filter((unit) => unit.owner !== player).flatMap((unit) => legalMoves(state, unit.id).map(key)));
      for (const order of chooseAIPlan(state, player).orders) if (order.move && order.cast && contestable.has(key(order.move))) {
        assert.ok(legalCasts(state, order.unitId, undefined, order.spellId).some((cell) => key(cell) === key(order.cast!)));
      }
    }
    Object.assign(state, resolveRound(state, [chooseAIPlan(state, 0), chooseAIPlan(state, 1)]));
  }
});
