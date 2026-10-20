import test from 'node:test';
import assert from 'node:assert/strict';
import { createClientSessionStore, type SessionStorage } from '../lib/client-session.ts';
import { gameShortcut } from '../lib/input.ts';
import { createSimGame, legalMoves, type TeamPlan } from '../lib/tactics.ts';

const code = '23456789ABCD', otherCode = '23456789ABCE', token = 'a'.repeat(64);
const matchId = '12345678-1234-1234-1234-123456789abc';
function store(): SessionStorage & { values: Map<string, string> } {
  const values = new Map<string, string>();
  return { values, getItem: key => values.get(key) ?? null, setItem: (key, value) => { values.set(key, value); }, removeItem: key => { values.delete(key); } };
}
const denied = () => { throw new Error('Storage denied'); };

test('pending join credentials persist before sending, survive reload, and become an established seat', () => {
  const local = store();
  const first = createClientSessionStore([{ kind: 'local', storage: local }], { createToken: () => token });
  assert.deepEqual(first.getPendingJoin(code), { token, persistence: 'local' });
  assert.equal(first.readSeat(code), null, 'an unaccepted join must not be mistaken for an existing seat');
  const reloaded = createClientSessionStore([{ kind: 'local', storage: local }], { createToken: () => { throw new Error('Must reuse saved token'); } });
  assert.deepEqual(reloaded.getPendingJoin(code), { token, persistence: 'local' });
  assert.equal(reloaded.rememberSeat({ code, token, seat: 1 }), 'local');
  assert.deepEqual(reloaded.readSeat(code), { code, token, seat: 1 });
  assert.equal(local.getItem(`confluence-pending-join-${code}`), null);
  assert.equal(reloaded.readSeat(otherCode), null);
});

test('denied browser storage keeps a stable token in memory and reports the real persistence level', () => {
  let generated = 0;
  const session = store();
  const fallback = createClientSessionStore([{ kind: 'local', open: denied }, { kind: 'session', storage: session }], { createToken: () => { generated++; return token; } });
  assert.equal(fallback.getPendingJoin(code).persistence, 'session');
  assert.equal(fallback.rememberSeat({ code, token, seat: 1 }), 'session');
  const memoryOnly = createClientSessionStore([{ kind: 'local', open: denied }, { kind: 'session', open: denied }], { createToken: () => { generated++; return token; } });
  assert.deepEqual(memoryOnly.getPendingJoin(code), { token, persistence: 'memory' });
  assert.deepEqual(memoryOnly.getPendingJoin(code), { token, persistence: 'memory' });
  assert.equal(generated, 2);
  assert.equal(memoryOnly.rememberSeat({ code, token, seat: 1 }), 'memory');
  assert.deepEqual(memoryOnly.readSeat(code), { code, token, seat: 1 });
});

test('released seat keys remain readable and corrupt storage cannot suppress another valid fallback', () => {
  const local = store(), session = store();
  local.setItem(`confluence-room-${code}`, '{bad');
  session.setItem(`confluence-room-${code}`, JSON.stringify({ code, token, seat: 0 }));
  const client = createClientSessionStore([{ kind: 'local', storage: local }, { kind: 'session', storage: session }]);
  assert.deepEqual(client.readSeat(code), { code, token, seat: 0 });
  local.setItem(`confluence-pending-join-${code}`, 'bad');
  session.setItem(`confluence-pending-join-${code}`, token);
  assert.deepEqual(client.getPendingJoin(code), { token, persistence: 'session' });
});

test('credentials already read stay usable when browser storage later becomes unavailable', () => {
  const local = store(); let available = true;
  local.setItem(`confluence-pending-join-${code}`, token);
  local.setItem(`confluence-room-${otherCode}`, JSON.stringify({ code: otherCode, token, seat: 0 }));
  const client = createClientSessionStore([{ kind: 'local', open: () => { if (!available) return denied(); return local; } }], { createToken: () => { throw new Error('Never replace the pending identity'); } });
  assert.equal(client.getPendingJoin(code).token, token);
  assert.equal(client.readSeat(otherCode)?.token, token);
  available = false;
  assert.equal(client.getPendingJoin(code).token, token);
  assert.equal(client.readSeat(otherCode)?.token, token);
});

test('online drafts survive reload only for the same match, round and player with legal orders', () => {
  const local = store(), game = createSimGame();
  const unit = game.units.find(u => u.owner === 0)!;
  const landing = legalMoves(game, unit.id)[0];
  const plan: TeamPlan = { orders: [{ unitId: unit.id, move: { q: landing.q, r: landing.r }, guard: true }] };
  const context = { code, matchId, state: game, seat: 0 as const };
  const client = createClientSessionStore([{ kind: 'local', storage: local }]);
  assert.equal(client.saveDraft({ ...context, plan }), 'local');
  const reloaded = createClientSessionStore([{ kind: 'local', storage: local }]);
  assert.deepEqual(reloaded.readDraft(context), plan);
  assert.equal(reloaded.readDraft({ ...context, code: otherCode }), null);
  assert.equal(reloaded.readDraft({ ...context, matchId: 'abcdefab-1234-1234-1234-123456789abc' }), null);
  assert.equal(reloaded.readDraft({ ...context, state: { ...game, round: game.round + 1 } }), null);
  assert.equal(reloaded.readDraft({ ...context, seat: 1 }), null);
  assert.equal(reloaded.readDraft({ ...context, state: { ...game, winner: 0 } }), null);
  assert.throws(() => client.saveDraft({ ...context, plan: { orders: [{ unitId: unit.id, move: { q: 20, r: 20 } }] } }));
  local.setItem(`confluence-draft-${code}`, JSON.stringify({ format: 1, matchId, round: game.round, seat: 0, plan: { orders: [{ unitId: unit.id, cast: { q: unit.q, r: unit.r }, spellId: 'not-a-spell' }] } }));
  assert.equal(reloaded.readDraft(context), null, 'stored drafts must be revalidated, even with matching metadata');
  reloaded.clearDraft(code);
  assert.equal(local.getItem(`confluence-draft-${code}`), null);
});

test('game shortcuts leave modified browser commands, editing, composition and key repeats alone', () => {
  for (const key of ['m', 'g', 'u', 'Escape', '1', '2', '3', '4']) {
    for (const flags of [{ ctrlKey: true }, { metaKey: true }, { altKey: true }, { repeat: true }, { isComposing: true }, { defaultPrevented: true }]) assert.equal(gameShortcut({ key, ...flags }), null);
    for (const target of [{ tagName: 'INPUT' }, { tagName: 'TEXTAREA' }, { tagName: 'SELECT' }, { tagName: 'SPAN', isContentEditable: true }]) assert.equal(gameShortcut({ key, target }), null);
  }
  assert.equal(gameShortcut({ key: 'M', target: { tagName: 'BUTTON' } }), 'move');
  assert.equal(gameShortcut({ key: 'g' }), 'guard');
  assert.equal(gameShortcut({ key: 'u' }), 'undo');
  assert.equal(gameShortcut({ key: 'Escape' }), 'cancel');
  assert.equal(gameShortcut({ key: '4' }), 'spell4');
  assert.equal(gameShortcut({ key: '5' }), null);
});
