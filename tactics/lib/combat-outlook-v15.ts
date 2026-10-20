import {getChampion,isAlive,legalCasts,spellArea,validatePlan,volleyDamage,type SimState,type TeamPlan,type Player,type Point} from './tactics-v15.ts';
import {effectiveSpell} from './spells-v15.ts';
import {projectAlliedMovement} from './movement-preview-v15.ts';
import {visibleFieldForecast} from './living-world-v15.ts';
import {inhabitantIntents} from './inhabitants-v15.ts';

export type CombatOutlook={id:string;name:string;ally:boolean;damage:number;guardedDamage:number;addedDamage:number;guardedAddedDamage:number;field:string};
const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;

/** A stationary-rival scenario, not a prediction. Only this company's legal
 * spells and public creature tells contribute; fresh marks never earn bonuses. */
export function combatOutlook(state:SimState,player:Player,input:TeamPlan,unitId:string,spellId:string,aim:Point):CombatOutlook[]{
 const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit));
 const selected=own.find(unit=>unit.id===unitId);
 if(!selected||state.winner!==null)return [];
 const prior=input.orders.find(order=>order.unitId===unitId);
 let plan:TeamPlan;
 try{plan=validatePlan(state,player,{orders:[...input.orders.filter(order=>order.unitId!==unitId&&own.some(unit=>unit.id===order.unitId)),{unitId,spellId,cast:aim,...(prior?.move?{move:prior.move}:{})}]});}catch{return [];}
 const movement=projectAlliedMovement(state,player,plan,true);
 const casts=plan.orders.flatMap(order=>{
  if(!order.cast||!order.spellId)return [];
  const caster=own.find(unit=>unit.id===order.unitId)!,origin=movement.get(caster.id)!.actualPosition;
  if(!legalCasts(state,caster.id,origin,order.spellId).some(cell=>same(cell,order.cast!)))return [];
  const spell=effectiveSpell(caster.championId,order.spellId,caster.affinities);
  return [{unitId:caster.id,spell,element:spell.element,freeze:!!spell.freeze,area:spellArea(state,caster.id,spell.id,order.cast,origin)}];
 });
 const candidate=casts.find(cast=>cast.unitId===unitId);
 if(!candidate)return [];
 const others=casts.filter(cast=>cast.unitId!==unitId),intents=inhabitantIntents(state);
 return state.units.filter(isAlive).flatMap(victim=>{
  const position=victim.owner===player?movement.get(victim.id)!.actualPosition:victim;
  if(!candidate.area.some(cell=>same(cell,position)))return [];
  const harmful=casts.filter(cast=>(victim.owner!==player||cast.spell.harm==='all')&&cast.area.some(cell=>same(cell,position)));
  if(!harmful.some(cast=>cast.spell.damage||cast.spell.bonusDamage))return [];
  const cell=state.cells.find(cell=>same(cell,position))!;
  const field=visibleFieldForecast(cell,casts,intents),without=visibleFieldForecast(cell,others,intents);
  const spells=harmful.map(cast=>cast.spell),previous=harmful.filter(cast=>cast.unitId!==unitId).map(cast=>cast.spell);
  const guarding=victim.owner===player&&plan.orders.some(order=>order.unitId===victim.id&&order.guard);
  const damage=volleyDamage(field,victim,spells,guarding),guardedDamage=volleyDamage(field,victim,spells,true);
  return [{id:victim.id,name:getChampion(victim.championId).name,ally:victim.owner===player,damage,guardedDamage,addedDamage:damage-volleyDamage(without,victim,previous,guarding),guardedAddedDamage:guardedDamage-volleyDamage(without,victim,previous,true),field:field.terrain}];
 });
}
