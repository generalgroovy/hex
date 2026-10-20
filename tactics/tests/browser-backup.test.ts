import { test } from 'node:test';
import assert from 'node:assert/strict';
import { BACKUP_LIMITS, BackupImportError, applyBrowserBackup, captureBrowserBackup, isGameStorageKey, parseBrowserBackup, previewBrowserImport, serializeBrowserBackup, summarizeBrowserBackup, type BackupEntry, type BackupStores } from '../lib/browser-backup.ts';

class MemoryStorage {
  values = new Map<string, string>();
  writes = 0;
  failOnWrite = 0;
  mutateBeforeFailure = false;
  refuseAll = false;
  constructor(initial: Record<string, string> = {}) { this.values = new Map(Object.entries(initial)); }
  get length() { return this.values.size; }
  key(index: number) { return [...this.values.keys()][index] ?? null; }
  getItem(key: string) { return this.values.get(key) ?? null; }
  setItem(key: string, value: string) { this.write(() => this.values.set(key, value)); }
  removeItem(key: string) { this.write(() => this.values.delete(key)); }
  write(change: () => unknown) {
    this.writes++;
    if (this.refuseAll || this.writes === this.failOnWrite) {
      if (this.mutateBeforeFailure) change();
      throw new Error('synthetic storage failure');
    }
    change();
  }
}
const stores = (local: Record<string, string> = {}, session: Record<string, string> = {}) => ({ local: new MemoryStorage(local), session: new MemoryStorage(session) });
const envelope = (entries: BackupEntry[]) => ({ format: 'hex-browser-backup' as const, version: 1 as const, createdAt: '2026-10-20T10:00:00.000Z', entries });
const code = 'ABCDEFGHJKLM';
const story = 'hex-confluence-campaign-session-v20';
const tower = 'hex-confluence-tower-v23';
const entry = (key: string, value: string, store: 'local' | 'session' = 'local'): BackupEntry => ({ store, key, value });

test('allowlist covers active, private, recovery, and legacy keys without broad browser-data prefixes', () => {
  const allowed = [story, `${story}-before-import`, 'hex-confluence-campaign-profile-v19-recovery-1792440000000', tower,
    `${tower}-recovery-1792440000000`, 'hex-confluence-tower-v21-before-import', 'hex-confluence-story-v10',
    'hex-confluence-story-v11', 'hex-confluence-animation', 'hex-presentation-v44', 'confluence-arena-company',
    'confluence-arena-session-v18', 'confluence-arena-session', `confluence-arena-seat-v18:${code}`,
    `confluence-arena-seat:${code}`, 'confluence-arena-pending-v18:host', `confluence-arena-pending:join:${code}`,
    `confluence-arena-draft-v18:${code}:130afd71-0aa1-4970-bcd0-ecab321a9721:3`,
    `hex-tower-coop-seat-v23:${code}`, 'hex-tower-coop-last-v23', 'hex-tower-coop-name-v23', 'hex-tower-coop-pending-v23',
    `hex-tower-coop-seat-v22:${code}`, 'hex-tower-coop-last-v22', 'hex-tower-coop-pending-v22',
    `confluence-room-${code}`, `confluence-pending-join-${code}`, `confluence-draft-${code}`,
    `confluence-draft-v7-${code}`, `confluence-draft-v16-${code}`, 'confluence-tactics-v4', 'confluence-tactics-v16',
    'confluence-loadouts-v4', 'confluence-loadouts-v16', 'confluence-local', 'confluence-sim-local',
    'confluence-name', 'confluence-sound', 'confluence-coach-v13', 'confluence-map-seed-r1'];
  for (const key of allowed) assert.equal(isGameStorageKey(key), true, key);
  for (const key of ['auth-token', '__proto__', 'hex-unrelated', 'confluence-anything', 'confluence-name-suffix',
    'hex-confluence-tower-v24', 'hex-confluence-tower-v23-recovery-invalid', `confluence-arena-seat-v18:${code}:extra`,
    'confluence-room-invalid', `confluence-arena-draft-v18:${code}:../../../secret:3`]) assert.equal(isGameStorageKey(key), false, key);
});

test('export is read-only, omits unrelated data, and round-trips exact local/session contents', () => {
  const source = stores({ [story]: '{old raw}', 'auth-token': 'unrelated-secret', 'confluence-sound': 'on' }, { [story]: '{new raw}', [tower]: '雪🌊' });
  const before = [new Map(source.local.values), new Map(source.session.values)];
  const backup = captureBrowserBackup(source, new Date('2026-10-20T10:00:00Z'));
  assert.equal(backup.entries.length, 4);
  assert(!serializeBrowserBackup(backup).includes('unrelated-secret'));
  assert.equal(source.local.writes + source.session.writes, 0);
  assert.deepEqual([source.local.values, source.session.values], before);
  const destination = stores();
  applyBrowserBackup(parseBrowserBackup(serializeBrowserBackup(backup)), destination);
  assert.equal(destination.local.getItem(story), '{old raw}');
  assert.equal(destination.session.getItem(story), '{new raw}');
  assert.equal(destination.session.getItem(tower), '雪🌊');
});

test('invalid transport is rejected completely before storage is touched', () => {
  const base = envelope([entry(story, 'valid')]);
  const invalid = [null, [], { ...base, format: 'different' }, { ...base, version: 2 }, { ...base, extra: 1 },
    { ...base, createdAt: 'invalid' }, { ...base, entries: [entry('unrelated-data', 'x')] },
    { ...base, entries: [{ store: 'cookies', key: story, value: 'x' }] },
    { ...base, entries: [{ store: 'local', key: story, value: {} }] },
    { ...base, entries: [{ ...entry(story, 'x'), extra: true }] },
    envelope([entry(story, 'x'), entry(story, 'y')]),
    envelope([entry(story, 'x'.repeat(BACKUP_LIMITS.valueBytes + 1))]),
    { ...base, entries: Array.from({ length: BACKUP_LIMITS.entries + 1 }, () => entry(story, 'x')) }];
  const target = stores({ [story]: 'original' });
  for (const data of invalid) {
    assert.throws(() => parseBrowserBackup(JSON.stringify(data)));
    assert.throws(() => applyBrowserBackup(data as typeof base, target));
  }
  assert.throws(() => parseBrowserBackup('{'));
  assert.throws(() => parseBrowserBackup(' '.repeat(BACKUP_LIMITS.bytes + 1)));
  assert.equal(target.local.writes + target.session.writes, 0);
  assert.equal(target.local.getItem(story), 'original');
});

test('default merge treats both stores as one conflict, preventing fallback shadowing', () => {
  const target = stores({ [story]: 'current' }, { [tower]: 'current-tower' });
  const backup = envelope([entry(story, 'incoming-new', 'session'), entry(tower, 'incoming-tower'), entry('confluence-name', 'Ada')]);
  const preview = previewBrowserImport(backup, target);
  assert.deepEqual(preview, { added: 1, replaced: 0, unchanged: 0, conflicts: 2 });
  assert.equal(target.local.writes + target.session.writes, 0);
  assert.deepEqual(applyBrowserBackup(backup, target), preview);
  assert.equal(target.local.getItem(story), 'current');
  assert.equal(target.session.getItem(story), null);
  assert.equal(target.session.getItem(tower), 'current-tower');
  assert.equal(target.local.getItem(tower), null);
  assert.equal(target.local.getItem('confluence-name'), 'Ada');
});

test('identical local/session pairs are unchanged; explicit replace clears stale opposite-store copies', () => {
  const target = stores({ [story]: 'old', [tower]: 'same', unrelated: 'kept' }, { [story]: 'stale', [tower]: 'fallback' });
  const backup = envelope([entry(story, 'new'), entry(tower, 'same'), entry(tower, 'fallback', 'session')]);
  assert.deepEqual(applyBrowserBackup(backup, target, 'replace'), { added: 0, replaced: 1, unchanged: 1, conflicts: 1 });
  assert.equal(target.local.getItem(story), 'new');
  assert.equal(target.session.getItem(story), null);
  assert.equal(target.local.getItem('unrelated'), 'kept');
  assert.equal(target.session.getItem(tower), 'fallback');
  assert.equal(target.local.writes, 1);
  assert.equal(target.session.writes, 1);
});

test('mid-import storage failure rolls back updates and newly added entries across both stores', () => {
  const target = stores({ [story]: 'original' }, { [story]: 'fallback' });
  target.session.failOnWrite = 2;
  const backup = envelope([entry(story, 'new'), entry(story, 'new-fallback', 'session'), entry(tower, 'new'), entry(tower, 'new-session', 'session')]);
  assert.throws(() => applyBrowserBackup(backup, target, 'replace'), (error: unknown) => error instanceof BackupImportError && error.rollbackComplete);
  assert.deepEqual(target.local.values, new Map([[story, 'original']]));
  assert.deepEqual(target.session.values, new Map([[story, 'fallback']]));
});

test('rollback includes mutation-then-throw and failing removal operations', () => {
  const target = stores({ [story]: 'original' }, { [story]: 'fallback' });
  target.session.failOnWrite = 1; target.session.mutateBeforeFailure = true;
  assert.throws(() => applyBrowserBackup(envelope([entry(story, 'replacement')]), target, 'replace'), BackupImportError);
  assert.equal(target.local.getItem(story), 'original');
  assert.equal(target.session.getItem(story), 'fallback');
});

test('an impossible rollback is reported rather than claiming previous data was restored', () => {
  const target = stores({ [story]: 'original' });
  target.local.refuseAll = true; target.local.mutateBeforeFailure = true;
  assert.throws(() => applyBrowserBackup(envelope([entry(story, 'replacement')]), target, 'replace'), (error: unknown) => error instanceof BackupImportError && !error.rollbackComplete && /could not be restored/.test(error.message));
});

test('summaries and preview only expose counts, never private token values', () => {
  const secret = 'private-access-token';
  const backup = envelope([entry(`hex-tower-coop-seat-v23:${code}`, secret), entry('confluence-name', 'Ada')]);
  assert.deepEqual(summarizeBrowserBackup(backup), { records: 2, savedItems: 2, local: 2, session: 0, privateAccess: 1 });
  assert(!JSON.stringify(previewBrowserImport(backup, stores())).includes(secret));
});

test('unavailable storage fails capture instead of silently producing a partial backup', () => {
  const source: BackupStores = stores({ [story]: 'save' });
  source.session = { ...new MemoryStorage(), length: 1, key() { throw new Error('blocked'); }, getItem() { return null; }, setItem() {}, removeItem() {} };
  assert.throws(() => captureBrowserBackup(source), /could not be read/);
});
