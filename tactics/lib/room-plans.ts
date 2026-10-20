import type { TeamPlan } from "./tactics-v10.ts";
import type { Element } from "./game.ts";

type CanonicalTeamPlan = TeamPlan & {
  training?: {unitId:string;element:Element}[];
  loadouts?: {unitId:string;spells:string[]}[];
};

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Send a team plan with an orders list.");
  return value as Record<string, unknown>;
}

/** Stable, bounded wire representation, also usable after a round has resolved. */
export function canonicalPlan(input: unknown, rulesVersion: 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 = 3): CanonicalTeamPlan {
  const plan = record(input);
  const planKeys = rulesVersion >= 9 ? ["orders", "training", "loadouts"] : ["orders"];
  if (Object.keys(plan).some((key) => !planKeys.includes(key)) || !Array.isArray(plan.orders) || plan.orders.length > 3) {
    throw new Error("Send up to three champion orders.");
  }
  const seen = new Set<string>();
  const orders = plan.orders.map((inputOrder) => {
    const order = record(inputOrder);
    const keys = rulesVersion >= 4 ? ["unitId", "move", "cast", "guard", "spellId"] : ["unitId", "move", "cast", "guard"];
    if (Object.keys(order).some((key) => !keys.includes(key)) ||
        typeof order.unitId !== "string" || !order.unitId.length || order.unitId.length > 48 || seen.has(order.unitId)) {
      throw new Error("Give each champion at most one order.");
    }
    seen.add(order.unitId);
    const point = (value: unknown): { q: number; r: number } => {
      const target = record(value);
      if (Object.keys(target).some((key) => key !== "q" && key !== "r") ||
          !Number.isInteger(target.q) || !Number.isInteger(target.r) || Math.abs(target.q as number) > 20 || Math.abs(target.r as number) > 20) {
        throw new Error("Choose valid board coordinates for each order.");
      }
      return { q: target.q as number, r: target.r as number };
    };
    if (order.guard !== undefined && order.guard !== true) throw new Error("Guard must be true when included.");
    if (rulesVersion >= 4 && ((order.cast !== undefined && (typeof order.spellId !== "string" || !order.spellId.length || order.spellId.length > 64)) ||
        (order.cast === undefined && order.spellId !== undefined))) throw new Error("Choose an equipped spell for every cast order.");
    return {
      unitId: order.unitId,
      ...(order.move !== undefined ? { move: point(order.move) } : {}),
      ...(order.cast !== undefined ? { cast: point(order.cast) } : {}),
      ...(rulesVersion >= 4 && order.cast !== undefined ? { spellId: order.spellId as string } : {}),
      ...(order.guard === true ? { guard: true } : {}),
    };
  });
  orders.sort((a, b) => a.unitId.localeCompare(b.unitId));
  if(rulesVersion<9)return {orders};
  const validUnitId=(id:unknown):id is string=>typeof id==='string'&&id.length>0&&id.length<=48;
  const training:NonNullable<CanonicalTeamPlan['training']>=[];
  if(plan.training!==undefined){
    // Three champions can each hold at most three affinities of six levels.
    // The engine applies the stricter ownership, point-bank and level checks.
    if(!Array.isArray(plan.training)||plan.training.length>54)throw new Error('Send a bounded list of affinity allocations.');
    if(rulesVersion>=11&&plan.training.length)throw new Error('Affinity is earned in Story and trained in camp before a match.');
    for(const raw of plan.training){
      const entry=record(raw);
      if(Object.keys(entry).some(key=>!['unitId','element'].includes(key))||!validUnitId(entry.unitId)||!['fire','water','air','earth','light','dark'].includes(entry.element as string))throw new Error('Choose a champion and element for each affinity point.');
      training.push({unitId:entry.unitId,element:entry.element as Element});
    }
    training.sort((a,b)=>a.unitId.localeCompare(b.unitId)||a.element.localeCompare(b.element));
  }
  const loadouts:NonNullable<CanonicalTeamPlan['loadouts']>=[];
  if(plan.loadouts!==undefined){
    if(!Array.isArray(plan.loadouts)||plan.loadouts.length>3)throw new Error('Send at most one four-spell loadout per champion.');
    if(rulesVersion>=12&&plan.loadouts.length)throw new Error('Four-spell kits are fixed for this match. Change equipment in camp.');
    const equipped=new Set<string>();
    for(const raw of plan.loadouts){
      const entry=record(raw);
      if(Object.keys(entry).some(key=>!['unitId','spells'].includes(key))||!validUnitId(entry.unitId)||equipped.has(entry.unitId)||!Array.isArray(entry.spells)||entry.spells.length!==4||entry.spells.some(id=>typeof id!=='string'||!id.length||id.length>64)||new Set(entry.spells).size!==4)throw new Error('Choose four different spells once per champion.');
      equipped.add(entry.unitId);loadouts.push({unitId:entry.unitId,spells:[...entry.spells] as string[]});
    }
    loadouts.sort((a,b)=>a.unitId.localeCompare(b.unitId));
  }
  return { orders,...(training.length?{training}:{}),...(loadouts.length?{loadouts}:{}) };
}

export async function planFingerprint(plan: TeamPlan, rulesVersion: 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 = 3): Promise<string> {
  // Preserve released v3 bytes so pending locks and receipts remain retryable.
  const canonical = canonicalPlan(plan, rulesVersion);
  const wire = rulesVersion === 3 ? canonical : { rulesVersion, plan: canonical };
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(wire)));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}
