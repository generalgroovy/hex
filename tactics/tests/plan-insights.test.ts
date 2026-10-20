import assert from 'node:assert/strict';
import test from 'node:test';
import { analyzePlan } from '../lib/plan-insights.ts';
import { createSimGame, resolveRound, SPELLS } from '../lib/tactics.ts';
import type { SimUnit, TeamPlan } from '../lib/tactics.ts';
const at = (unit: SimUnit, q: number, r: number) => Object.assign(unit, { q, r });
const equip = (unit: SimUnit, id: string) => { unit.loadout = [id, ...SPELLS.filter(spell => spell.id !== id).slice(0, 3).map(spell => spell.id)]; };
const empty: TeamPlan = { orders: [] };

test('two allied orders to one empty landing warn before the proven simultaneous bounce', () => {
  const state = createSimGame(); at(state.units[0], 0, -1); at(state.units[1], -1, 0);
  const plan = { orders: [state.units[0], state.units[1]].map(unit => ({ unitId: unit.id, move: { q: 0, r: 0 } })) };
  const before = structuredClone(state); const insights = analyzePlan(state, 0, plan);
  assert.equal(insights.length, 1); assert.equal(insights[0].kind, 'ally-collision'); assert.equal(insights[0].severity, 'warning');
  assert.deepEqual(insights[0].unitIds, [state.units[0].id, state.units[1].id]);
  assert.equal(resolveRound(state, [plan, empty]).lastResolution.filter(event => event.kind === 'bounce').length, 2);
  assert.deepEqual(state, before); assert.deepEqual(analyzePlan(state, 0, { orders: [...plan.orders].reverse() }), insights);
});

test('stationary allied blockers propagate through a movement chain while legal swaps remain clear', () => {
  const state = createSimGame(); at(state.units[0], 0, -2); at(state.units[1], 0, -1); at(state.units[2], 0, 0);
  const blocked = { orders: [{ unitId: state.units[0].id, move: { q: 0, r: -1 } }, { unitId: state.units[1].id, move: { q: 0, r: 0 } }] };
  assert.equal(analyzePlan(state, 0, blocked).filter(insight => insight.kind === 'ally-collision').length, 2);
  assert.equal(resolveRound(state, [blocked, empty]).lastResolution.filter(event => event.kind === 'bounce').length, 2);
  const swap = { orders: [{ unitId: state.units[0].id, move: { q: 0, r: -1 } }, { unitId: state.units[1].id, move: { q: 0, r: -2 } }] };
  assert.deepEqual(analyzePlan(state, 0, swap), []);
  assert.equal(resolveRound(state, [swap, empty]).lastResolution.filter(event => event.kind === 'bounce').length, 0);
});

test('a rival-occupied landing remains a conditional risk rather than a claimed certain collision', () => {
  const state = createSimGame(); at(state.units[0], 0, -1); at(state.units[3], 0, 0);
  const plan = { orders: [{ unitId: state.units[0].id, move: { q: 0, r: 0 } }] };
  const insights = analyzePlan(state, 0, plan);
  assert.equal(insights.length, 1); assert.equal(insights[0].kind, 'rival-landing'); assert.equal(insights[0].severity, 'risk');
  assert.equal(resolveRound(state, [plan, empty]).units[0].r, -1);
  const vacated = resolveRound(state, [plan, { orders: [{ unitId: state.units[3].id, move: { q: 1, r: 0 } }] }]);
  assert.equal(vacated.units[0].r, 0);
});

test('known allied bounce reports its inevitable fizzle; otherwise the same long aim is conditional', () => {
  const state = createSimGame(); at(state.units[0], 0, -4); at(state.units[1], 0, 0); equip(state.units[0], 'stone');
  const cast = { unitId: state.units[0].id, move: { q: 0, r: -1 }, spellId: 'stone', cast: { q: 0, r: 2 } };
  assert.equal(analyzePlan(state, 0, { orders: [cast] }).find(insight => insight.kind === 'landing-dependent')?.severity, 'risk');
  const conflict = { orders: [cast, { unitId: state.units[1].id, move: { q: 0, r: -1 } }] };
  const insights = analyzePlan(state, 0, conflict);
  assert.equal(insights.find(insight => insight.kind === 'blocked-cast')?.severity, 'warning');
  assert.ok(!insights.some(insight => insight.kind === 'landing-dependent'));
  assert.ok(resolveRound(state, [conflict, empty]).lastResolution.some(event => event.kind === 'fizzle' && event.unitId === state.units[0].id));
});

test('team-wide exposure includes damage, zero-damage control and displacement; moving an ally clear removes it', () => {
  for (const spellId of ['stone', 'veil', 'vacuum']) {
    const state = createSimGame(); at(state.units[0], 0, -1); at(state.units[1], 0, 0); equip(state.units[0], spellId);
    const cast = { unitId: state.units[0].id, spellId, cast: { q: 0, r: 0 } };
    const exposure = analyzePlan(state, 0, { orders: [cast] }).find(insight => insight.kind === 'ally-exposure');
    assert.ok(exposure, spellId); assert.ok(exposure.unitIds.includes(state.units[1].id)); assert.equal(exposure.severity, 'risk');
    assert.ok(!analyzePlan(state, 0, { orders: [cast, { unitId: state.units[1].id, move: { q: 1, r: 0 } }] }).some(insight => insight.kind === 'ally-exposure'));
  }
  const state = createSimGame(); at(state.units[0], 0, -1); at(state.units[1], 0, 0); equip(state.units[0], 'radiant_bolt');
  assert.deepEqual(analyzePlan(state, 0, { orders: [{ unitId: state.units[0].id, spellId: 'radiant_bolt', cast: { q: 0, r: 0 } }] }), []);
});

test('a blocked allied move is used for exposure rather than pretending its destination succeeds', () => {
  const state = createSimGame(); at(state.units[0], 0, -2); at(state.units[1], 0, -1); at(state.units[2], 0, 0); equip(state.units[0], 'stone');
  const plan = { orders: [{ unitId: state.units[0].id, spellId: 'stone', cast: { q: 0, r: -1 } }, { unitId: state.units[1].id, move: { q: 0, r: 0 } }] };
  const insights = analyzePlan(state, 0, plan);
  assert.ok(insights.some(insight => insight.kind === 'ally-collision'));
  assert.ok(insights.some(insight => insight.kind === 'ally-exposure' && insight.unitIds.includes(state.units[1].id)));
});

test('insights accept only this team\'s valid orders and never mutate supplied plans', () => {
  const state = createSimGame(); const plan = { orders: [{ unitId: state.units[0].id, guard: true as const }] }; const before = structuredClone(plan);
  assert.deepEqual(analyzePlan(state, 0, plan), []); assert.deepEqual(plan, before);
  assert.throws(() => analyzePlan(state, 0, { orders: [{ unitId: state.units[3].id, guard: true }] }));
  assert.throws(() => analyzePlan(state, 0, { orders: [{ unitId: state.units[0].id, move: { q: 100, r: 0 } }] }));
});
