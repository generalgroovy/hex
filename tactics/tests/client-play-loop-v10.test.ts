import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import { createSimGame, legalCasts, legalMoves, castAvailability, validatePlan, prepareTeam, type SimState, type TeamPlan } from '../lib/tactics-v10.ts';
import { CHAMPIONS, getChampion } from '../lib/roster-v10.ts';
import { availableSpellIds, defaultLoadout, getSignature, getSpell, validateLoadout } from '../lib/spells-v10.ts';
import { canonicalPlan } from '../lib/room-plans.ts';
import { arenaSeed } from '../lib/arena-v7.ts';
import { nextUnplannedUnit } from '../lib/battle-readout-v10.ts';

// Run the actual component handlers with real rules and controllable React-like
// state setters. Browser geometry, focus and rendering are separate UI checks.
const source = ts.createSourceFile('TacticsGame.tsx', readFileSync(new URL('../app/TacticsGameV10.tsx', import.meta.url), 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
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
    libraryLearned: [], learnedSignatures: [], activeStory: null, battleLibrary: null, rosterOpen: true, recruitSlot: 0, spellSlot: 0,
    spellFilter: 'affinity', spellSearch: '', spellRole: 'all',
    roster: ['oh_tipi', 'wa_bidi', 'treevor_mason'],
    loadouts: Object.fromEntries(CHAMPIONS.map(champion => [champion.id, defaultLoadout(champion.id)])),
    hotSeat: 0, sealedLocal: null,
    recruitFocus: { current: null },
    gameRef: { current: initial }, epoch: { current: 0 }, activeSession: { current: session },
    revision: { current: 1 }, match: { current: '12345678-1234-1234-1234-123456789abc' }, requestBusy: { current: false },
    room: { code: session.code, matchId: '12345678-1234-1234-1234-123456789abc', version: 1, state: initial, locked: [false, false] },
    EMPTY: empty, getSpell, getSignature, getChampion, availableSpellIds, defaultLoadout, validateLoadout, nextUnplannedUnit, legalMoves, legalCasts, castAvailability, validatePlan, prepareTeam, canonicalPlan, arenaSeed,
    cap: (s:string)=>s.charAt(0).toUpperCase()+s.slice(1),
    same: (a: { q: number; r: number }, b: { q: number; r: number }) => a.q === b.q && a.r === b.r,
    alive: (unit: SimState['units'][number]) => unit.hp > 0 && unit.respawn === undefined,
    coord: (point: { q: number; r: number }) => `${point.q}, ${point.r}`,
    chime: noop, sessions: () => ({ readDraft: () => null, clearDraft: (code: string) => cleared.push(code) }),
    location: { replace: () => assert.fail('current rules must not redirect') },
    fetch: async (path: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      requests.push({ path, body });
      return { status: 200, ok: true, room: { ...env.room, rulesVersion: 10, yourSeat: 0, mapId: env.game.mapId, version: env.room.version + 1, locked: [true, false], yourPlan: body.plan } };
    },
    responseData: async (response: { room: unknown }) => ({ room: response.room }),
    showResolution: () => assert.fail('these interactions must not resolve a round'),
  };
  for (const name of ['Plan', 'PlanHistory', 'Selected', 'Kind', 'SpellId', 'HoverAim', 'Notice', 'Error', 'FocusRequest', 'Inspect', 'Busy', 'Connected', 'Room', 'MapSeed', 'Game', 'Previous', 'BattleLibrary', 'ActiveStory', 'RosterOpen', 'RecruitSlot', 'Roster', 'Loadouts', 'SpellSlot', 'SpellFilter', 'SpellSearch', 'SpellRole', 'Library', 'HotSeat', 'SealedLocal', 'Handoff']) {
    const field = name[0].toLowerCase() + name.slice(1);
    env[`set${name}`] = (value: unknown) => { env[field] = typeof value === 'function' ? value(env[field]) : value; };
  }
  function updateDerived() {
    env.planningGame=prepareTeam(env.game,env.seat,env.plan);
    env.libraryUnit=env.screen==='battle'&&env.battleLibrary?env.planningGame.units.find((u:SimState['units'][number])=>u.id===env.battleLibrary):undefined;
    env.recruit = getChampion(env.libraryUnit?.championId||env.roster[env.recruitSlot]);
    env.libraryAffinities=env.libraryUnit?.affinities??env.recruit.affinities;
    env.equipped = env.libraryUnit?.loadout||env.loadouts[env.recruit.id] || defaultLoadout(env.recruit.id);
    env.unit = env.planningGame.units.find((unit: SimState['units'][number]) => unit.id === env.selected);
    env.order = env.plan.orders.find((order: TeamPlan['orders'][number]) => order.unitId === env.selected);
    env.plannedPosition = env.order?.move || env.unit;
    env.chosenSpell = env.unit ? getSpell(availableSpellIds(env.unit.championId, env.unit.loadout,env.unit.affinities).includes(env.spellId) ? env.spellId : env.unit.loadout[0]) : null;
    env.targets = env.canPlan && env.unit ? env.kind === 'move' ? legalMoves(env.planningGame, env.unit.id) : legalCasts(env.planningGame, env.unit.id, env.plannedPosition, env.chosenSpell?.id) : [];
  }
  function call(name: string, ...args: unknown[]) {
    updateDerived();
    const javascript = functions.get(name);
    assert.ok(javascript, `missing ${name} interaction`);
    return new Function(...Object.keys(env), `${javascript}; return ${name};`)(...Object.values(env))(...args);
  }
  for (const name of ['current', 'selectUnit', 'editOrder', 'revisePlan', 'acceptRoom','updateKit']) env[name] = (...args: unknown[]) => call(name, ...args);
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
  h.call('chooseSpell', other);
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
  h.env.game.units.find((unit:SimState['units'][number])=>unit.id===h.env.unit.id)!.flux = castAvailability(h.env.game, h.env.unit.id, original.orders[0].spellId!).cost;
  const unavailable=availableSpellIds(h.env.unit.championId,h.env.unit.loadout,h.env.unit.affinities).find(id=>!castAvailability(h.env.game,h.env.unit.id,id).available)!;
  assert.ok(unavailable,'the current kit has an unaffordable action');
  h.call('chooseSpell', unavailable);
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
  const snapshot = { ...h.env.room, version: 8, rulesVersion: 10, yourSeat: 0, mapId: current.mapId, state: structuredClone(current), yourPlan: { orders: [] } };
  h.call('acceptRoom', snapshot, 0);
  h.call('acceptRoom', { ...snapshot, version: 10, code: 'BCDEFGHJKLMN' }, 0);
  h.call('acceptRoom', { ...snapshot, version: 10 }, -1);
  assert.equal(h.env.game, current);
  assert.deepEqual(h.env.plan, original);
  assert.equal(h.env.revision.current, 9);
  assert.equal(h.cleared.length, 0);
  assert.equal(h.requests.length, 0);
});

test('direct recruitment replaces only the selected seat and preserves customized kits', () => {
  const h = harness();
  const replacement = 's_wayne';
  h.env.loadouts[replacement] = ['ember', 'water_jet', 'stone', 'mend'];
  const kits = structuredClone(h.env.loadouts);
  h.env.recruitSlot = 1;
  h.call('replaceRecruit', replacement);
  assert.deepEqual(h.env.roster, ['oh_tipi', replacement, 'treevor_mason']);
  assert.deepEqual(h.env.loadouts, kits, 'recruiting must not reset a character’s saved kit');
  assert.equal(h.env.rosterOpen, false);
  assert.equal(h.env.recruitSlot, 1);
  assert.equal(h.env.recruitFocus.current, 1, 'after dialogs close, focus returns to the replaced team slot');
});

test('selecting an existing recruit changes focus without duplicating or rearranging the team', () => {
  const h = harness();
  const original = structuredClone(h.env.roster);
  h.call('replaceRecruit', original[2]);
  assert.deepEqual(h.env.roster, original);
  assert.equal(h.env.recruitSlot, 2);
  assert.equal(h.env.recruitFocus.current, 2, 'selecting an existing recruit targets its existing team control');
  assert.equal(new Set(h.env.roster).size, 3);
  h.env.busy = true;
  h.env.recruitFocus.current = null;
  h.call('replaceRecruit', 's_wayne');
  assert.deepEqual(h.env.roster, original, 'a pending game launch freezes the selected roster');
  assert.equal(h.env.recruitFocus.current, null, 'an ignored recruit cannot steal keyboard focus');
});

test('catalogue equips the chosen slot without changing other slots or other character kits', () => {
  const h = harness();
  const championId = h.env.roster[0];
  const before = structuredClone(h.env.loadouts);
  const replacement = ['mend', 'stone', 'gust', 'ember'].find(id => !before[championId].includes(id))!;
  h.env.spellSlot = 2;
  h.call('equip', replacement);
  const expected = [...before[championId]];
  expected[2] = replacement;
  assert.deepEqual(h.env.loadouts[championId], expected);
  assert.equal(validateLoadout(championId, h.env.loadouts[championId]).length, 4);
  for (const id of Object.keys(before)) if (id !== championId) assert.deepEqual(h.env.loadouts[id], before[id]);
});

test('one direct slot action opens the correct character and spell without a separate selection step', () => {
  const h = harness();
  const before = structuredClone(h.env.loadouts);
  h.call('openLoadout', 2, 3);
  assert.equal(h.env.library, true);
  assert.equal(h.env.recruitSlot, 2);
  assert.equal(h.env.spellSlot, 3);
  assert.deepEqual(h.env.loadouts, before, 'opening a catalogue never edits the kit');
  const replacement = ['mend', 'stone', 'gust', 'ember'].find(id => !before.treevor_mason.includes(id))!;
  h.call('equip', replacement);
  assert.equal(h.env.loadouts.treevor_mason[3], replacement);
  assert.deepEqual(h.env.loadouts.oh_tipi, before.oh_tipi, 'the formerly selected character is not edited');
});

test('catalogue rejects duplicates and exclusive signatures without corrupting the current kit', () => {
  const h = harness();
  const before = structuredClone(h.env.loadouts);
  h.env.spellSlot = 0;
  h.call('equip', before[h.env.roster[0]][1]);
  assert.deepEqual(h.env.loadouts, before);
  assert.match(h.env.notice, /already equipped|different spells/i);
  h.call('equip', getSignature(h.env.roster[0]).id);
  assert.deepEqual(h.env.loadouts, before);
  assert.ok(h.env.error, 'a signature is not an editable fifth loadout slot');
  h.env.busy = true;
  const replacement = ['mend', 'stone', 'gust', 'ember'].find(id => !before[h.env.roster[0]].includes(id))!;
  h.call('equip', replacement);
  assert.deepEqual(h.env.loadouts, before, 'a pending launch freezes loadouts along with the roster');
});

test('a direct attempt to equip an affinity-locked spell preserves the selected kit',()=>{
  const h=harness();
  h.call('openLoadout',2,0);
  const before=structuredClone(h.env.loadouts);
  h.call('equip','frostbite');
  assert.deepEqual(h.env.loadouts,before);
  assert.match(h.env.error,/3 water affinity/i);
  assert.equal(h.env.library,true,'the catalogue stays available so the player can choose a legal spell');
});

test('next character skips a completed order without changing it or adding a default order', () => {
  const h = harness();
  const before = queuedCast(h);
  const originalSelection = h.env.selected;
  h.call('nextCharacter');
  assert.notEqual(h.env.selected, originalSelection);
  assert.equal(h.env.game.units.find((unit: SimState['units'][number]) => unit.id === h.env.selected)?.owner, 0);
  assert.deepEqual(h.env.plan, before);
  assert.equal(h.env.planHistory.length, 0);
});

test('a hotseat handoff seals the first team and clears every visible draft before the second team plans', async () => {
  const h = harness();
  const before = queuedCast(h);
  h.env.mode = 'hotseat';
  h.env.planHistory = [{ orders: [] }];
  await h.call('lockPlan');
  assert.deepEqual(h.env.sealedLocal, validatePlan(h.env.game, 0, before));
  assert.deepEqual(h.env.plan, { orders: [] });
  assert.deepEqual(h.env.planHistory, []);
  assert.equal(h.env.selected, null);
  assert.equal(h.env.handoff, true);
  assert.equal(h.env.hotSeat, 1);
  assert.equal(h.requests.length, 0);
  h.env.canPlan = false;
  h.call('chooseSpell', h.env.game.units[0].loadout[1]);
  h.call('cell', h.env.game.units[0].q, h.env.game.units[0].r);
  h.call('undoPlan');
  assert.deepEqual(h.env.plan, { orders: [] });
  assert.deepEqual(h.env.sealedLocal, validatePlan(h.env.game, 0, before));
});

test('earned training unlocks a new spell for the same sealed round without changing the public state',async()=>{
  const state=createSimGame();state.round=3;state.version=3;
  const original=structuredClone(state),h=harness(state);
  h.call('train','water');
  assert.equal(h.env.plan.training.length,1);
  h.call('openBattleLoadout',1);
  h.call('equip','deep_freeze');
  assert.equal(h.env.error,'');
  assert.equal(h.env.plan.loadouts[0].spells[1],'deep_freeze');
  h.call('chooseSpell','deep_freeze');
  const target=h.env.targets[0];assert.ok(target);
  h.call('cell',target.q,target.r);
  await h.call('lockPlan');
  const sent=h.requests[0].body.plan;
  assert.equal(sent.training?.[0].element,'water');
  assert.equal(sent.loadouts?.[0].spells[1],'deep_freeze');
  assert.equal(sent.orders.find(o=>o.unitId===state.units[0].id)?.spellId,'deep_freeze');
  assert.deepEqual(state,original);
});

test('replacing a queued spell preserves its movement, explicitly Guards, and Undo restores kit and cast',()=>{
  const h=harness();queuedCast(h);const original=structuredClone(h.env.plan);
  h.call('openBattleLoadout',0);
  h.call('equip','mend');
  assert.equal(h.env.plan.orders[0].guard,true);
  assert.equal(h.env.plan.orders[0].cast,undefined);
  assert.match(h.env.notice,/replaced by Guard/);
  h.call('undoPlan');
  assert.deepEqual(h.env.plan,original);
});

test('training can be undone and cannot be overspent by repeating the control',()=>{
  const state=createSimGame();state.round=3;state.version=3;
  const h=harness(state);h.call('train','water');const trained=structuredClone(h.env.plan);
  h.call('train','water');assert.deepEqual(h.env.plan,trained);assert.ok(h.env.error);
  h.call('editOrder',{guard:true});assert.deepEqual(h.env.plan.training,trained.training,'normal order edits retain training');
  h.call('undoPlan');h.call('undoPlan');assert.deepEqual(h.env.plan,{orders:[]});
});

test('a stale catalogue reset cannot change a locked or disconnected battle plan',()=>{
  const h=harness();h.call('openBattleLoadout',0);
  const before=structuredClone(h.env.plan),history=structuredClone(h.env.planHistory);
  h.env.canPlan=false;
  h.call('updateKit',['ember','water_jet','stone','mend']);
  assert.deepEqual(h.env.plan,before);
  assert.deepEqual(h.env.planHistory,history);
  h.env.canPlan=true;h.env.busy=true;
  h.call('updateKit',['ember','water_jet','stone','mend']);
  assert.deepEqual(h.env.plan,before,'an in-flight submit also freezes direct resets');
});
