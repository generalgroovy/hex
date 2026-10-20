/** Origin-independent transport only. Game loaders still validate their own saves. */
export const BACKUP_LIMITS = { bytes: 32 * 1024 * 1024, valueBytes: 8 * 1024 * 1024, keyLength: 160, entries: 2048 } as const;
export type BackupStoreName = 'local' | 'session';
export type BackupStorage = Pick<Storage, 'length' | 'key' | 'getItem' | 'setItem' | 'removeItem'>;
export type BackupStores = Record<BackupStoreName, BackupStorage>;
export type BackupEntry = { store: BackupStoreName; key: string; value: string };
export type BrowserBackup = { format: 'hex-browser-backup'; version: 1; createdAt: string; entries: BackupEntry[] };
export type ImportMode = 'missing' | 'replace';
const STORES = ['local', 'session'] as const;
const CODE = '[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}';
const EXACT_KEYS = new Set([
  'confluence-local', 'confluence-sim-local', 'confluence-name', 'confluence-sound',
  'confluence-map-seed-r1', 'confluence-coach-v13', 'hex-confluence-animation', 'hex-presentation-v44', 'confluence-arena-company',
  'confluence-arena-session', 'confluence-arena-session-v18',
  'hex-confluence-story-v10', 'hex-confluence-story-v11',
]);
const KEY_PATTERNS = [
  /^confluence-(?:tactics|loadouts)-v(?:[4-9]|1[0-6])$/,
  /^hex-confluence-campaign-(?:profile-v(?:19|20)|match-v(?:19|20)|session-v20)(?:-before-import|-recovery-\d{1,16})?$/,
  /^hex-confluence-tower-v2[1-3](?:-before-import|-recovery-\d{1,16})?$/,
  /^hex-tower-coop-(?:last|name|pending)-v2[23]$/,
  new RegExp(`^hex-tower-coop-seat-v2[23]:${CODE}$`),
  new RegExp(`^confluence-arena-seat(?:-v18)?:${CODE}$`),
  new RegExp(`^confluence-arena-pending(?:-v18)?:(?:host|join:${CODE})$`),
  new RegExp(`^confluence-arena-draft(?:-v18)?:${CODE}:[A-Za-z0-9-]{1,64}:\\d{1,10}$`),
  new RegExp(`^confluence-(?:room|pending-join)-${CODE}$`),
  new RegExp(`^confluence-draft(?:-v(?:[7-9]|1[0-6]))?-${CODE}$`),
];
export function isGameStorageKey(key: string): boolean {
  return key.length <= BACKUP_LIMITS.keyLength && (EXACT_KEYS.has(key) || KEY_PATTERNS.some(pattern => pattern.test(key)));
}
const byteLength = (text: string) => new TextEncoder().encode(text).byteLength;
const record = (value: unknown): value is Record<string, unknown> => !!value && typeof value === 'object' && !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
const exactFields = (value: Record<string, unknown>, fields: string[]) => Object.keys(value).length === fields.length && fields.every(field => Object.hasOwn(value, field));
function invalid(): never { throw new Error('This is not a valid H.E.X. browser backup. No saves were changed.'); }

export function validateBrowserBackup(value: unknown): BrowserBackup {
  if (!record(value) || !exactFields(value, ['format', 'version', 'createdAt', 'entries']) || value.format !== 'hex-browser-backup' || value.version !== 1 || typeof value.createdAt !== 'string' || value.createdAt.length > 30 || !Number.isFinite(Date.parse(value.createdAt)) || !Array.isArray(value.entries) || value.entries.length > BACKUP_LIMITS.entries) invalid();
  const seen = new Set<string>();
  const entries: BackupEntry[] = [];
  for (const entry of value.entries) {
    if (!record(entry) || !exactFields(entry, ['store', 'key', 'value']) || (entry.store !== 'local' && entry.store !== 'session') || typeof entry.key !== 'string' || !isGameStorageKey(entry.key) || typeof entry.value !== 'string' || byteLength(entry.value) > BACKUP_LIMITS.valueBytes) invalid();
    const id = `${entry.store}:${entry.key}`;
    if (seen.has(id)) invalid();
    seen.add(id);
    entries.push({ store: entry.store, key: entry.key, value: entry.value });
  }
  const backup: BrowserBackup = { format: 'hex-browser-backup', version: 1, createdAt: value.createdAt, entries };
  if (byteLength(JSON.stringify(backup)) > BACKUP_LIMITS.bytes) invalid();
  return backup;
}
export function parseBrowserBackup(text: string): BrowserBackup {
  if (byteLength(text) > BACKUP_LIMITS.bytes) invalid();
  let value: unknown;
  try { value = JSON.parse(text); } catch { invalid(); }
  return validateBrowserBackup(value);
}
export function serializeBrowserBackup(backup: BrowserBackup): string {
  return JSON.stringify(validateBrowserBackup(backup));
}
export function captureBrowserBackup(stores: BackupStores, now = new Date()): BrowserBackup {
  const entries: BackupEntry[] = [];
  try {
    for (const store of STORES) {
      const keys = new Set<string>();
      for (let index = 0; index < stores[store].length; index++) {
        const key = stores[store].key(index);
        if (key !== null && isGameStorageKey(key)) keys.add(key);
      }
      for (const key of [...keys].sort()) {
        const value = stores[store].getItem(key);
        if (value !== null) entries.push({ store, key, value });
      }
    }
  } catch { throw new Error('Browser storage could not be read. No backup was created.'); }
  return validateBrowserBackup({ format: 'hex-browser-backup', version: 1, createdAt: now.toISOString(), entries });
}
export function summarizeBrowserBackup(backup: BrowserBackup) {
  const keys = new Set(backup.entries.map(entry => entry.key));
  return {
    records: backup.entries.length,
    savedItems: keys.size,
    local: backup.entries.filter(entry => entry.store === 'local').length,
    session: backup.entries.filter(entry => entry.store === 'session').length,
    privateAccess: [...keys].filter(key => /(?:-seat(?:-v\d+)?:|-room-|-pending(?:-v\d+)?:|-pending-join-|-coop-pending-|-arena-session)/.test(key)).length,
  };
}
type Change = { store: BackupStoreName; key: string; before: string | null; after: string | null };
type ImportPlan = { added: number; replaced: number; unchanged: number; conflicts: number; changes: Change[] };
function planImport(input: BrowserBackup, stores: BackupStores, mode: ImportMode): ImportPlan {
  const backup = validateBrowserBackup(input);
  if (mode !== 'missing' && mode !== 'replace') invalid();
  const groups = new Map<string, { local: string | null; session: string | null }>();
  for (const entry of backup.entries) {
    const pair = groups.get(entry.key) ?? { local: null, session: null };
    pair[entry.store] = entry.value;
    groups.set(entry.key, pair);
  }
  const plan: ImportPlan = { added: 0, replaced: 0, unchanged: 0, conflicts: 0, changes: [] };
  try {
    for (const [key, after] of groups) {
      const before = { local: stores.local.getItem(key), session: stores.session.getItem(key) };
      if (STORES.every(store => before[store] === after[store])) { plan.unchanged++; continue; }
      // A session fallback can shadow a local save. Keep/replace each pair together.
      const conflict = STORES.some(store => before[store] !== null);
      if (conflict) { plan.conflicts++; if (mode === 'missing') continue; plan.replaced++; }
      else plan.added++;
      for (const store of STORES) if (before[store] !== after[store]) plan.changes.push({ store, key, before: before[store], after: after[store] });
    }
  } catch { throw new Error('Browser storage could not be read. No saves were changed.'); }
  return plan;
}
export function previewBrowserImport(backup: BrowserBackup, stores: BackupStores, mode: ImportMode = 'missing') {
  const { changes: _changes, ...summary } = planImport(backup, stores, mode);
  return summary;
}
export class BackupImportError extends Error {
  readonly rollbackComplete: boolean;
  constructor(rollbackComplete: boolean) {
    super(rollbackComplete ? 'Import failed. Previous saves were restored. Keep your backup and try again after freeing browser storage.' : 'Import failed and some previous values could not be restored. Keep your backup; browser storage is refusing writes.');
    this.name = 'BackupImportError';
    this.rollbackComplete = rollbackComplete;
  }
}
export function applyBrowserBackup(backup: BrowserBackup, stores: BackupStores, mode: ImportMode = 'missing') {
  const { changes, ...summary } = planImport(backup, stores, mode);
  const attempted: Change[] = [];
  const write = (change: Change, value: string | null) => {
    if (value === null) stores[change.store].removeItem(change.key);
    else stores[change.store].setItem(change.key, value);
    if (stores[change.store].getItem(change.key) !== value) throw new Error('Storage verification failed');
  };
  try {
    for (const change of changes) {
      if (stores[change.store].getItem(change.key) !== change.before) throw new Error('Storage changed during import');
      attempted.push(change);
      write(change, change.after);
    }
  } catch {
    let restored = true;
    for (const change of attempted.reverse()) {
      try { write(change, change.before); } catch { restored = false; }
    }
    throw new BackupImportError(restored);
  }
  return summary;
}
