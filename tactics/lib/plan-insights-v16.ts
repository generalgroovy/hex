/** Advisory checks use only the public position and this team's editable orders. */
import { getChampion, getSpell, isAlive, legalCasts, spellArea, validatePlan, prepareTeam,fieldCombination,fieldEffects } from './tactics-v16.ts';
import {formatTile} from './board-labels-v9.ts';
import type { Player, Point, SimState, TeamPlan } from './tactics-v16.ts';
import {projectedVolley} from './planned-volley-v16.ts';
import {interceptionFieldArea} from './projectile-interception-v16.ts';
import {visibleFieldForecast} from './living-world-v16.ts';
import {inhabitantIntents} from './inhabitants-v16.ts';

export type PlanInsight = {
  id: string;
  kind: 'ally-collision' | 'rival-landing' | 'blocked-cast' | 'landing-dependent' | 'ally-exposure' | 'field-exposure';
  severity: 'warning' | 'risk';
  unitIds: string[];
  text: string;
  hex?: Point;
};
const key = (point: Point) => `${point.q || 0},${point.r || 0}`;
const same = (left: Point, right: Point) => key(left) === key(right);
const at = (point: Point): Point => ({ q: point.q, r: point.r });

/** Known allied conflicts are certain; rival intentions and eventual spell exposure are not. */
export function analyzePlan(state: SimState, player: Player, input: TeamPlan): PlanInsight[] {
  const ownIds=new Set(state.units.filter(unit=>unit.owner===player&&isAlive(unit)).map(unit=>unit.id));
  const plan = validatePlan(state, player, {...input,orders:input.orders.filter(order=>ownIds.has(order.unitId))});
  state=prepareTeam(state,player,plan);
  const own = state.units.filter(unit => unit.owner === player && isAlive(unit));
  const rivals = state.units.filter(unit => unit.owner !== player && isAlive(unit));
  const orders = new Map(plan.orders.map(order => [order.unitId, order]));
  const names = (ids: string[]) => ids.map(id => getChampion(own.find(unit => unit.id === id)!.championId).name).join(' and ');
  const insights: PlanInsight[] = [];
  const active = new Set(plan.orders.filter(order => order.move).map(order => order.unitId));
  const destinations = new Map<string, string[]>();
  for (const order of plan.orders) if (order.move) destinations.set(key(order.move), [...(destinations.get(key(order.move)) ?? []), order.unitId]);

  for (const [destination, ids] of destinations) if (ids.length > 1) {
    for (const id of ids) active.delete(id);
    insights.push({ id: `ally-collision:${destination}`, kind: 'ally-collision', severity: 'warning', unitIds: ids,
      hex: at(orders.get(ids[0])!.move!), text: `${names(ids)} target ${formatTile(orders.get(ids[0])!.move!)}. All those moves will bounce.` });
  }
  // A failed landing also blocks any ally trying to take that champion's current hex.
  let changed = true;
  while (changed) {
    changed = false;
    for (const order of plan.orders) if (order.move && active.has(order.unitId)) {
      const blocker = own.find(unit => same(unit, order.move!));
      if (blocker && !active.has(blocker.id)) {
        active.delete(order.unitId); changed = true;
        insights.push({ id: `ally-collision:${order.unitId}`, kind: 'ally-collision', severity: 'warning', unitIds: [order.unitId, blocker.id],
          hex: at(order.move), text: `${names([order.unitId])}'s move to ${formatTile(order.move)} will bounce: ${names([blocker.id])} stays there.` });
      }
    }
  }

  const volley=projectedVolley(state,player,plan),projected=volley.positions;
  for (const order of plan.orders) {
    const unit = own.find(entry => entry.id === order.unitId)!;
    if (order.move && active.has(unit.id)) {
      const rival = rivals.find(entry => same(entry, order.move!));
      if (rival) insights.push({ id: `rival-landing:${unit.id}`, kind: 'rival-landing', severity: 'risk', unitIds: [unit.id], hex: at(order.move),
        text: `${names([unit.id])}'s move will bounce if ${getChampion(rival.championId).name} stays or cannot leave.` });
    }
    if (!order.cast || !order.spellId) continue;
    const spell = getSpell(order.spellId);
    const origin = projected.get(unit.id)!;
    const legalFromOrigin = legalCasts(state, unit.id, origin, spell.id).some(cell => same(cell, order.cast!));
    if (!legalFromOrigin) {
      insights.push({ id: `blocked-cast:${unit.id}`, kind: 'blocked-cast', severity: 'warning', unitIds: [unit.id], hex: at(order.cast),
        text: `${names([unit.id])}'s ${spell.name} will fizzle because an ally blocks the move. Change the move or aim; no Flux is spent.` });
      continue;
    }
    if (order.move && active.has(unit.id) && !legalCasts(state, unit.id, undefined, spell.id).some(cell => same(cell, order.cast!))) {
      insights.push({ id: `landing-dependent:${unit.id}`, kind: 'landing-dependent', severity: 'risk', unitIds: [unit.id], hex: at(order.cast),
        text: `${names([unit.id])}'s ${spell.name} needs this move to succeed. If it bounces, the spell fizzles without spending Flux.` });
    }
    // Meeting spells lose their original footprints. Advice must agree with the
    // map forecast instead of retaining phantom damage at either former aim.
    if (volley.intercepted.has(unit.id)||spell.harm !== 'all' || !(spell.damage || spell.harmful?.length || spell.push)) continue;
    const area = spellArea(state, unit.id, spell.id, order.cast, origin);
    const exposed = own.filter(ally => area.some(cell => same(cell, projected.get(ally.id)!))).map(ally => ally.id).sort();
    if (exposed.length) insights.push({ id: `ally-exposure:${unit.id}`, kind: 'ally-exposure', severity: 'risk', unitIds: [...new Set([unit.id, ...exposed])], hex: at(order.cast),
      text: `${spell.name} may hit ${names(exposed)} in their planned positions. Rival moves can change the outcome.` });
  }
  const intents=inhabitantIntents(state);
  for(const clash of volley.clashes){
    const area=interceptionFieldArea(state.cells,clash),exposed=own.flatMap(unit=>{
      const position=projected.get(unit.id)!,cell=area.find(cell=>same(cell,position));
      if(!cell)return [];
      const after=visibleFieldForecast(cell,volley.fields,intents),field=fieldCombination(after)!,effects=fieldEffects(after);
      const hazard=effects.hazard==='always'||effects.hazard==='formed'&&fieldCombination(cell)?.id!==field.id||effects.hazard==='moved'&&!same(unit,position);
      const ailment=effects.statuses?.some(status=>['burn','wither','rooted','chilled','concussed','blind'].includes(status.id));
      return hazard||ailment||effects.flux===-1?[{unit,field}]:[];
    });
    if(exposed.length)insights.push({id:`field-exposure:${clash.participants.join(':')}`,kind:'field-exposure',severity:'risk',unitIds:[...new Set([...clash.participants,...exposed.map(entry=>entry.unit.id)])],hex:at(clash),
      text:`The in-flight meeting replaces the original hits with a neutral field. ${exposed.map(({unit,field})=>`${getChampion(unit.championId).name} would stand in ${field.name}: ${field.shortRule.toLowerCase()}`).join('; ')}. Rival spells and displacement can change this.`});
  }
  return insights.sort((left, right) => Number(left.severity === 'risk') - Number(right.severity === 'risk') || left.id.localeCompare(right.id));
}
