import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import { createSimGame, legalCasts, legalMoves, castAvailability, validatePlan, type SimState, type TeamPlan } from '../lib/tactics-v7.ts';
import { getChampion } from '../lib/roster-v7.ts';
import { availableSpellIds, getSpell } from '../lib/spells-v7.ts';
import { canonicalPlan } from '../lib/room-plans.ts';
import { arenaSeed } from '../lib/arena-v7.ts';

// Run the actual component handlers with real rules and controllable React-like
// state setters. Browser geometry, focus and rendering are separate UI checks.
const source = ts.createSourceFile('TacticsGame.tsx', readFileSync(new URL('../app/V7Game.tsx', import.meta.url), 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
const functions = new Map<string, string>();
const visit = (node: ts.Node) => {
  if (ts.isFunctionDeclaration(node) && node.name) functions.set(node.name.text, ts.transpileModule(node.getText(source), { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.None } }).outputText);
  ts.forEachChild(node, visit);
};
visit(source);

function harness(initial = createSimGame()) {
  const session = { code: '23456789ABCD', token: 'a'.repeat(64), seat: 0 };
  const requests: { path: string; body: { plan: TeamPlan } }[] = [];
  const cleared: string[] = [];
  const empty = { orders: [] };
  const noop = () => {};
  // This environment changes when setters run; each handler is re-created from
  // the latest values, matching the state snapshot of a subsequent React event.
  const env: Record<string, any> = {
    game: initial, plan: empty, planHistory: [], selected: initial.units.find(u => u.owner === 0)!.id,
    kind: 'move', spellId: '', hoverAim: null, notice: '', error: '', focusRequest: 0, inspect: null,
    mode: 'online', screen: 'battle', seat: 0, canPlan: true, locked: false, busy: false,
    resolving: false, handoff: false, guide: false, library: false, candidate: null,
    spellPickerOpen: false,
    gameRef: { current: initial }, epoch: { current: 0 }, activeSession: { current: session },
    revision: { current: 1 }, match: { current: '12345678-1234-1234-1234-123456789abc' }, requestBusy: { current: false },
    room: { code: session.code, matchId: '12345678-1234-1234-1234-123456789abc', version: 1, state: initial, locked: [false, false] },
    EMPTY: empty, getSpell, getChampion, availableSpellIds, legalMoves, legalCasts, castAvailability, validatePlan, canonicalPlan, arenaSeed,
    same: (a: { q: number; r: number }, b: { q: number; r: number }) => a.q === b.q && a.r === b.r,
    alive: (unit: SimState['units'][number]) => unit.hp > 0 && unit.respawn === undefined,
    coord: (point: { q: number; r: number }) => `${point.q}, ${point.r}`,
    chime: noop, sessions: () => ({ readDraft: () => null, clearDraft: (code: string) => cleared.push(code) }),
    location: { replace: () => assert.fail('current rules must not redirect') },
    fetch: async (path: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      requests.push({ path, body });
      return { status: 200, ok: true, room: { ...env.room, rulesVersion: 7, yourSeat: 0, mapId: env.game.mapId, version: env.room.version + 1, locked: [true, false], yourPlan: body.plan } };
    },
    responseData: async (response: { room: unknown }) => ({ room: response.room }),
    showResolution: () => assert.fail('these interactions must not resolve a round'),
  };
  for (const name of ['Plan', 'PlanHistory', 'Selected', 'Kind', 'SpellId', 'HoverAim', 'Notice', 'Error', 'FocusRequest', 'Inspect', 'Busy', 'Connected', 'Room', 'MapSeed', 'Game', 'Previous', 'SpellPickerOpen']) {
    const field = name[0].toLowerCase() + name.slice(1);
    env[`set${name}`] = (value: unknown) => { env[field] = typeof value === 'function' ? value(env[field]) : value; };
  }
  function updateDerived() {
    env.unit = env.game.units.find((unit: SimState['units'][number]) => unit.id === env.selected);
    env.order = env.plan.orders.find((order: TeamPlan['orders'][number]) => order.unitId === env.selected);
    env.plannedPosition = env.order?.move || env.unit;
    env.chosenSpell = env.unit ? getSpell(availableSpellIds(env.unit.championId, env.unit.loadout).includes(env.spellId) ? env.spellId : env.unit.loadout[0]) : null;
    env.targets = env.canPlan && env.unit ? env.kind === 'move' ? legalMoves(env.game, env.unit.id) : legalCasts(env.game, env.unit.id, env.plannedPosition, env.chosenSpell?.id) : [];
  }
  function call(name: string, ...args: unknown[]) {
    updateDerived();
    const javascript = functions.get(name);
    assert.ok(javascript, `missing ${name} interaction`);
    return new Function(...Object.keys(env), `${javascript}; return ${name};`)(...Object.values(env))(...args);
  }
  for (const name of ['current', 'selectUnit', 'editOrder', 'revisePlan', 'acceptRoom']) env[name] = (...args: unknown[]) => call(name, ...args);
  updateDerived();
  return { env, requests, cleared, call };
}

function queuedCast(h: ReturnType<typeof harness>) {
  const unit = h.env.unit as SimState['units'][number];
  const spellId = unit.loadout[0];
  const target = legalCasts(h.env.game, unit.id, undefined, spellId).find(p => p.q === unit.q && p.r === unit.r)!;
  assert.ok(target);
  h.env.plan = { orders: [{ unitId: unit.id, cast: { q: target.q, r: target.r }, spellId }] };
  h.call('selectUnit', unit.id);
  return structuredClone(h.env.plan) as TeamPlan;
}

test('browsing another spell and hovering a hex cannot silently replace the submitted cast', async () => {
  const h = harness();
  const queued = queuedCast(h);
  const other = h.env.unit.loadout[1];
  h.env.spellPickerOpen = true;
  h.call('chooseSpell', other);
  assert.equal(h.env.spellPickerOpen, false, 'choosing a spell returns the player to the targetable board');
  const target = legalCasts(h.env.game, h.env.unit.id, undefined, other)[0];
  h.call('previewCell', { q: target.q, r: target.r });
  assert.deepEqual(h.env.plan, queued);
  assert.equal(h.env.planHistory.length, 0);
  await h.call('lockPlan');
  assert.equal(h.requests.length, 1);
  assert.deepEqual(h.requests[0].body.plan, validatePlan(h.env.game, 0, queued));
});

test('tapping a new spell target queues that exact spell and hex in the sealed payload', async () => {
  const h = harness();
  queuedCast(h);
  const other = h.env.unit.loadout[1];
  h.call('chooseSpell', other);
  const target = legalCasts(h.env.game, h.env.unit.id, undefined, other)[0];
  h.call('cell', target.q, target.r);
  const order = h.env.plan.orders.find((entry: TeamPlan['orders'][number]) => entry.unitId === h.env.unit.id);
  assert.equal(order.spellId, other);
  assert.deepEqual(order.cast, { q: target.q, r: target.r });
  assert.equal(h.env.hoverAim, null);
  const queued = structuredClone(h.env.plan);
  await h.call('lockPlan');
  assert.deepEqual(h.requests[0].body.plan, validatePlan(h.env.game, 0, queued));
});

test('undo restores a cast and its planned landing one edit at a time', () => {
  const h = harness();
  const original = queuedCast(h);
  h.env.kind = 'move';
  const move = legalMoves(h.env.game, h.env.unit.id).find(point => legalCasts(h.env.game, h.env.unit.id, point, original.orders[0].spellId).some(p => p.q === original.orders[0].cast!.q && p.r === original.orders[0].cast!.r))!;
  assert.ok(move);
  h.call('cell', move.q, move.r);
  const moved = structuredClone(h.env.plan);
  h.call('chooseSpell', h.env.unit.loadout[1]);
  const target = legalCasts(h.env.game, h.env.unit.id, move, h.env.unit.loadout[1])[0];
  h.call('cell', target.q, target.r);
  h.call('undoPlan');
  assert.deepEqual(h.env.plan, moved);
  h.call('undoPlan');
  assert.deepEqual(h.env.plan, original);
  assert.equal(h.env.planHistory.length, 0);
});

test('unavailable spell inspection cannot replace orders or queue a cast without Flux', () => {
  const h = harness();
  const original = queuedCast(h);
  h.env.unit.flux = castAvailability(h.env.game, h.env.unit.id, original.orders[0].spellId!).cost;
  assert.equal(castAvailability(h.env.game, h.env.unit.id, h.env.unit.loadout[1]).available, false);
  h.call('chooseSpell', h.env.unit.loadout[1]);
  h.call('previewCell', { q: h.env.unit.q, r: h.env.unit.r });
  h.call('cell', h.env.unit.q, h.env.unit.r);
  assert.deepEqual(h.env.plan, original);
  assert.equal(h.env.planHistory.length, 0);
  assert.equal(h.requests.length, 0);
});

test('locked read-only character and spell inspection never edits, undoes, or resubmits orders', async () => {
  const h = harness();
  const original = queuedCast(h);
  h.env.canPlan = false; h.env.locked = true;
  h.env.planHistory = [{ orders: [] }];
  const other = h.env.game.units.find((unit: SimState['units'][number]) => unit.owner === 0 && unit.id !== h.env.selected)!;
  h.call('selectUnit', other.id);
  assert.equal(h.env.selected, other.id);
  h.call('chooseSpell', other.loadout[1]);
  h.call('cell', other.q, other.r);
  h.call('editOrder', { guard: true });
  h.call('undoPlan');
  await h.call('lockPlan');
  assert.deepEqual(h.env.plan, original);
  assert.equal(h.env.planHistory.length, 1);
  assert.equal(h.requests.length, 0);
});

test('stale revisions, abandoned sessions and old lifecycle responses cannot replace current drafts', () => {
  const h = harness();
  const original = queuedCast(h);
  h.env.revision.current = 9;
  const current = h.env.game;
  const snapshot = { ...h.env.room, version: 8, rulesVersion: 7, yourSeat: 0, mapId: current.mapId, state: structuredClone(current), yourPlan: { orders: [] } };
  h.call('acceptRoom', snapshot, 0);
  h.call('acceptRoom', { ...snapshot, version: 10, code: 'BCDEFGHJKLMN' }, 0);
  h.call('acceptRoom', { ...snapshot, version: 10 }, -1);
  assert.equal(h.env.game, current);
  assert.deepEqual(h.env.plan, original);
  assert.equal(h.env.revision.current, 9);
  assert.equal(h.cleared.length, 0);
  assert.equal(h.requests.length, 0);
});
