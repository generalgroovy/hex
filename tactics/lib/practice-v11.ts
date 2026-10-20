import { defaultLoadout,effectiveSpell } from './spells-v11.ts';
import type {AffinityAllocation} from './roster-v11.ts';
import { availableSpellIds, castAvailability, cellElements, chooseAIPlan, distance, getCell, isAlive, legalCasts, legalMoves, MAX_ROUNDS, POINTS_TO_WIN, prepareTeam,spellArea, terrainCover, validatePlan } from './tactics-v11.ts';
import type { Order, Player, Point, SimCell, SimState, SimUnit, Spell, TeamPlan } from './tactics-v11.ts';

/** Practice uses the same fixed pre-match affinities and spell access rules. */
export function practiceLoadouts(ids: string[],affinities:Readonly<Record<string,AffinityAllocation>>={},learnedSignatures:readonly string[]=[]): Record<string, string[]> {
  return Object.fromEntries(ids.map(id => [id, defaultLoadout(id,affinities[id],learnedSignatures)]));
}

const key = (point: Point) => `${point.q || 0},${point.r || 0}`;
const same = (left: Point, right: Point) => key(left) === key(right);
const at = ({ q, r }: Point): Point => ({ q, r });

/** Fixed public income is an estimate, not a prediction of hidden plans. */
function losesFixedIncomeRace(state: SimState, player: Player, ownIncome: number, rivalIncome: number): boolean {
  let ownScore = state.scores[player], rivalScore = state.scores[1 - player];
  for (let round = state.round; round <= MAX_ROUNDS; round++) {
    ownScore += ownIncome; rivalScore += rivalIncome;
    if ((Math.max(ownScore, rivalScore) >= POINTS_TO_WIN && ownScore !== rivalScore) || round === MAX_ROUNDS) return ownScore < rivalScore;
  }
  return false;
}

function guardedDamage(victim: SimUnit, cell: SimCell, spells: Spell[]): number {
  let ordinary = 0, piercing = 0;
  const elements = new Set(cellElements(cell));
  for (const spell of spells) {
    elements.add(spell.element);
    const bonus = spell.bonus && (spell.bonus === 'wounded' ? victim.hp < victim.maxHp : victim.statuses[spell.bonus]) ? spell.bonusDamage ?? 0 : 0;
    if (spell.pierce) piercing += spell.damage + bonus; else ordinary += spell.damage + bonus;
  }
  const total = ordinary + piercing;
  const covered = elements.has('fire') && elements.has('water') ? Math.ceil(total / 2) : total;
  piercing = total ? Math.floor(covered * piercing / total) : 0; ordinary = covered - piercing;
  return Math.max(0, Math.max(0, ordinary - terrainCover(cell) - (victim.statuses.ward?.power ?? 0)) + piercing - 1);
}

/** Keep the established scoring plan, but let one otherwise idle mage pressure a
 * rival scoring well when holding still cannot win the public score race.
 * No opponent order, prediction state or private information enters this policy.
 */
export function choosePracticePlan(state: SimState, player: Player): TeamPlan {
  const originalState=state;
  const baseline = chooseAIPlan(state, player);
  if (state.winner !== null || !baseline.orders.length) return baseline;
  state=prepareTeam(state,player,baseline);
  const own = state.units.filter(unit => unit.owner === player && isAlive(unit));
  const rivals = state.units.filter(unit => unit.owner !== player && isAlive(unit));
  const wells = state.cells.filter(cell => cell.well), opposing = (1 - player) as Player;
  const landing = (unit: SimUnit) => baseline.orders.find(order => order.unitId === unit.id)?.move ?? unit;
  const wellValue = (well: SimCell) => well.reactions?.includes('penumbra') ? 2 : 1;
  const income = (units: SimUnit[], projected = false) => wells.reduce((sum, well) => sum + (units.some(unit => same(projected ? landing(unit) : unit, well)) ? wellValue(well) : 0), 0);
  const ourIncome = income(own, true), theirIncome = income(rivals);
  // Above-target ties continue; the final round can end below target. Preserve
  // a projected win or draw before giving up a quiet holder's scoring income.
  if (!losesFixedIncomeRace(state, player, ourIncome, theirIncome)) return baseline;
  const holders = rivals.filter(unit => getCell(state, unit.q, unit.r)?.well);
  const sign = player === 0 ? 1 : -1;
  const pointOrder = (left: Point, right: Point) => sign * (left.q - right.q || left.r - right.r);
  const allyPositions = own.flatMap(unit => [at(unit), at(landing(unit))]);
  const exposedToPlannedSpell = (unitId: string, origin: Point) => baseline.orders.some(order => {
    if (order.unitId === unitId || !order.cast || !order.spellId) return false;
    const caster=state.units.find(entry=>entry.id===order.unitId)!;
    const spell = effectiveSpell(caster.championId,order.spellId,caster.affinities);
    return spell.harm === 'all' && Boolean(spell.damage || spell.harmful?.length || spell.push)
      && spellArea(state, order.unitId, spell.id, order.cast, order.move).some(cell => same(cell, origin));
  });
  const cleared = wells.filter(well => !state.units.some(unit => isAlive(unit) && same(unit, well)) && state.lastResolution.some(event => event.owner === opposing && (
    event.kind === 'defeat' && event.q === well.q && event.r === well.r || event.kind === 'push' && event.from && same(event.from, well)
  )));
  const plannedHits = new Map(holders.map(victim => [victim.id, baseline.orders.flatMap(order => {
    if (!order.cast || !order.spellId) return [];
    const caster=state.units.find(entry=>entry.id===order.unitId)!;
    const spell = effectiveSpell(caster.championId,order.spellId,caster.affinities);
    return spellArea(state, order.unitId, spell.id, order.cast, order.move).some(cell => same(cell, victim)) ? [spell] : [];
  })]));
  let best: { score: number; order: Order } | undefined;
  for (const unit of own) {
    const original = baseline.orders.find(order => order.unitId === unit.id)!;
    if (!original.guard || unit.hp <= unit.maxHp / 2 || unit.statuses.rooted) continue;
    const moves = legalMoves(state, unit.id);
    // A revealed defeat/displacement is a real opening. Capture the cleared well
    // instead of returning to a comfortable older objective after the attack.
    for (const well of cleared) if (moves.some(cell => same(cell, well)) && !own.some(ally => ally.id !== unit.id && (same(ally, well) || same(landing(ally), well))) && !exposedToPlannedSpell(unit.id, well)) {
      const supported = state.lastResolution.some(event => event.kind === 'cast' && event.unitId === unit.id && event.to && same(event.to, well));
      if (supported && (!best || best.score < 6)) best = { score: 6, order: { unitId: unit.id, move: at(well), guard: true } };
    }
    const continuing = state.lastResolution.some(event => event.kind === 'cast' && event.unitId === unit.id && event.to && holders.some(holder => same(holder, event.to!)));
    // Preserve opening captures; continue a public, already-started attack instead
    // of taking one shot then walking back to the same quiet well.
    if (!continuing && (original.move || !getCell(state, unit.q, unit.r)?.well)) continue;
    if (!holders.length) continue;
    const ownedWell = getCell(state, unit.q, unit.r)?.well === true;
    const candidates = [getCell(state, unit.q, unit.r)!, ...moves]
      .filter(cell => !rivals.some(rival => same(rival, cell)) && !own.some(ally => ally.id !== unit.id && (same(ally, cell) || same(landing(ally), cell))));
    const positionScore = (cell: SimCell) => {
      const nearest = Math.min(...holders.map(holder => distance(cell, holder)));
      return Math.abs(nearest - 3) + distance(unit, cell) * 0.2 - terrainCover(cell) * 0.5
        + rivals.filter(rival => distance(cell, rival) <= 2).length * 2;
    };
    candidates.sort((left, right) => positionScore(left) - positionScore(right) || pointOrder(left, right));
    // Six origins cap the extra work. Include the current hex for a continuing
    // attacker even if other origins have slightly better positional scores.
    const origins = candidates.slice(0, 6);
    if (continuing && !origins.some(cell => same(cell, unit))) origins.push(getCell(state, unit.q, unit.r)!);
    for (const origin of origins) {
      if (ownedWell && same(origin, unit)) continue;
      // Preserve other mages' already-safe damage footprints after our one change.
      if (exposedToPlannedSpell(unit.id, origin)) continue;
      for (const spellId of availableSpellIds(unit.championId, unit.loadout,unit.affinities,state.learnedSignatures[player])) {
        const availability = castAvailability(state, unit.id, spellId); if (!availability.available) continue;
        const spell = effectiveSpell(unit.championId,spellId,unit.affinities);
        if (!(spell.damage || spell.push || spell.steal) || spell.range === 0) continue;
        const possibleTargets = legalCasts(state, unit.id, origin, spellId)
          .filter(cell => holders.some(holder => distance(cell, holder) <= (spell.shape === 'burst' || spell.shape === 'ring' ? spell.radius : 0)))
          .sort(pointOrder);
        for (const target of possibleTargets) {
          const area = spellArea(state, unit.id, spell.id, target, origin);
          if (spell.harm === 'all' && [...allyPositions, origin].some(ally => area.some(cell => same(cell, ally)))) continue;
          const victims = holders.filter(holder => area.some(cell => same(cell, holder)));
          if (!victims.length) continue;
          let score = -availability.cost * 0.35 - (spell.selfDamage ?? 0) * 2 - (ownedWell ? 2 : 0);
          for (const victim of victims) {
            // Evaluate the marginal contribution to our own planned volley.
            // Ward/forest apply once, and adding Water to Fire may reduce it.
            // Existing marks enable bonuses; planned fresh marks do not.
            const field = getCell(state, victim.q, victim.r)!, planned = plannedHits.get(victim.id)!;
            const damage = guardedDamage(victim, field, [...planned, spell]) - guardedDamage(victim, field, planned);
            score += damage * 3 + (damage >= victim.hp ? 5 : 0) + (spell.harmful?.length ?? 0) * 0.75 + (spell.steal ?? 0) * 0.5;
            if (spell.push && !victim.statuses.anchored) score += 2;
          }
          score -= rivals.filter(rival => distance(origin, rival) <= 4).length * 0.5;
          score += terrainCover(origin) * 0.5;
          if (score <= 0 || (best && score <= best.score)) continue;
          best = { score, order: { unitId: unit.id, ...(same(unit, origin) ? {} : { move: at(origin) }), spellId, cast: at(target) } };
        }
      }
    }
  }
  if (!best) return baseline;
  return validatePlan(originalState, player, { ...baseline,orders: baseline.orders.map(order => order.unitId === best.order.unitId ? best.order : order) });
}
