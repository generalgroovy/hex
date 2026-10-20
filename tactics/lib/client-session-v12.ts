import { canonicalPlan } from './room-plans.ts';
import { validatePlan, type SimState, type TeamPlan } from './tactics-v12.ts';

export type ClientSeat = { code: string; token: string; seat: 0 | 1 };
export type Persistence = 'local' | 'session' | 'memory';
export type SessionStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>;
export type StorageSource = { kind: 'local' | 'session' } &
  ({ storage: SessionStorage; open?: never } | { open: () => SessionStorage; storage?: never });
type DraftContext = { code: string; matchId: string; state: SimState; seat: 0 | 1 };
const TOKEN = /^[a-f0-9]{64}$/;
const CODE = /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/;
const MATCH = /^[a-f0-9-]{36}$/;

function createToken(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), n => n.toString(16).padStart(2, '0')).join('');
}

/** Browser persistence is optional. Every accepted write also survives in this tab. */
export function createClientSessionStore(sources: StorageSource[], options: { createToken?: () => string } = {}) {
  const memory = new Map<string, { value: string; persistence: Persistence }>();
  const storage = (source: StorageSource) => source.open ? source.open() : source.storage;
  function checkCode(code: string) { if (!CODE.test(code)) throw new Error('Choose a valid match code.'); }
  function write(key: string, value: string): Persistence {
    let persistence: Persistence = 'memory';
    for (const source of sources) {
      try { storage(source).setItem(key, value); persistence = source.kind; break; } catch { /* Try the next browser store. */ }
    }
    memory.set(key, { value, persistence });
    return persistence;
  }
  function* reads(key: string) {
    const remembered = memory.get(key);
    if (remembered) yield remembered;
    for (const source of sources) {
      try { const value = storage(source).getItem(key); if (value !== null && value.length <= 65536) yield { value, persistence: source.kind }; } catch { /* Storage can be disabled or full. */ }
    }
  }
  function remove(key: string) {
    memory.delete(key);
    for (const source of sources) { try { storage(source).removeItem(key); } catch { /* A stale entry is validated before reuse. */ } }
  }
  function readSeat(code: string): ClientSeat | null {
    checkCode(code);
    for (const entry of reads(`confluence-room-${code}`)) {
      try {
        const seat = JSON.parse(entry.value);
        if (seat?.code === code && TOKEN.test(seat.token) && (seat.seat === 0 || seat.seat === 1)) {
          memory.set(`confluence-room-${code}`, entry);
          return { code, token: seat.token, seat: seat.seat };
        }
      } catch { /* Preserve unreadable data and try another store. */ }
    }
    return null;
  }
  function rememberSeat(seat: ClientSeat): Persistence {
    checkCode(seat.code);
    if (!TOKEN.test(seat.token) || (seat.seat !== 0 && seat.seat !== 1)) throw new Error('Your player key could not be read.');
    const persistence = write(`confluence-room-${seat.code}`, JSON.stringify(seat));
    remove(`confluence-pending-join-${seat.code}`);
    return persistence;
  }
  function getPendingJoin(code: string): { token: string; persistence: Persistence } {
    checkCode(code);
    const key = `confluence-pending-join-${code}`;
    for (const entry of reads(key)) if (TOKEN.test(entry.value)) {
      memory.set(key, entry);
      return { token: entry.value, persistence: entry.persistence };
    }
    const token = (options.createToken ?? createToken)();
    if (!TOKEN.test(token)) throw new Error('A player key could not be created.');
    return { token, persistence: write(key, token) };
  }
  function saveDraft({ code, matchId, state, seat, plan }: DraftContext & { plan: TeamPlan }): Persistence {
    checkCode(code);
    if (!MATCH.test(matchId) || (seat !== 0 && seat !== 1) || state.rulesVersion !== 12 || state.winner !== null) throw new Error('Only an active match can retain draft orders.');
    validatePlan(state, seat, plan);
    return write(`confluence-draft-v12-${code}`, JSON.stringify({ format: 1, matchId, round: state.round, seat, plan: canonicalPlan(plan, 12) }));
  }
  function readDraft({ code, matchId, state, seat }: DraftContext): TeamPlan | null {
    checkCode(code);
    if (state.rulesVersion !== 12 || state.winner !== null) return null;
    for (const entry of reads(`confluence-draft-v12-${code}`)) {
      try {
        const draft = JSON.parse(entry.value);
        if (draft?.format !== 1 || draft.matchId !== matchId || draft.round !== state.round || draft.seat !== seat) continue;
        validatePlan(state, seat, draft.plan);
        // Keep the player's explicit orders instead of expanding omitted mages
        // into Guards and misleading the planning counter after reloading.
        return canonicalPlan(draft.plan, 12);
      } catch { /* Never replace authoritative or legal orders with a stale draft. */ }
    }
    return null;
  }
  return { readSeat, rememberSeat, getPendingJoin, saveDraft, readDraft,
    clearPendingJoin(code: string) { checkCode(code); remove(`confluence-pending-join-${code}`); },
    clearDraft(code: string) { checkCode(code); remove(`confluence-draft-v12-${code}`); },
  };
}
