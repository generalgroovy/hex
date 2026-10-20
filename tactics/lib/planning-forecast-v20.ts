/** Known orders and public creature tells, never a prediction of a rival's plan. */
import {fieldCombination,fieldEffects,isAlive,isIce,legalCasts,spellArea,validatePlan,type Element,type Player,type Point,type SimCell,type SimState,type TeamPlan} from './tactics-v20.ts';
import {effectiveSpell,STATUS_DEFINITIONS} from './spells-v20.ts';
import {getChampion} from './roster-v13.ts';
import {inhabitantIntents} from './inhabitants-v16.ts';
import {visibleFieldForecast,type VisibleCast} from './living-world-v20.ts';
import {projectedVolley,type VolleyOptions} from './planned-volley-v20.ts';
import {interceptionFieldArea} from './projectile-interception-v16.ts';

export type ForecastCell=Point&{field:string;name:string;shortRule:string;elements:Element[];changed:boolean;ice:boolean;symbol:string;color:string};
export type ForecastGroup={id:string;name:string;shortRule:string;count:number;elements:Element[];symbol:string;color:string};
export type PlanningForecast={unitId:string;spellId:string;aim:Point;origin:Point;cells:ForecastCell[];groups:ForecastGroup[];allies:{id:string;name:string}[];blocked:boolean;landingDependent:boolean;clashes:ReturnType<typeof projectedVolley>['clashes']};
const key=(point:Point)=>`${point.q},${point.r}`;
const same=(a:Point,b:Point)=>key(a)===key(b);
const at=({q,r}:Point):Point=>({q,r});

/** Compact consequences come from the computed surface, including deliberate Ice. */
function describeField(cell:SimCell):Omit<ForecastCell,'q'|'r'|'changed'> {
  const field=fieldCombination(cell)!;
  const m=fieldEffects(cell),ice=isIce(cell),parts:string[]=[];
  if(ice)parts.push('Entering slides to the far edge');
  else if(m.movement==='flood'||m.movement==='rough')parts.push('Entering or leaving costs 2 movement');
  else if(m.movement==='current')parts.push('Start here for +1 movement');
  if(m.damageScale==='half')parts.push('Halves spell damage');
  if(m.cover)parts.push(`Absorbs ${m.cover} ordinary damage`);
  if(m.hazard==='always')parts.push('Final occupant takes 1 damage');
  if(m.hazard==='formed')parts.push('Deals 1 damage when this field first forms');
  if(m.hazard==='moved')parts.push('Deals 1 damage if you finish on a different hex');
  if(m.heal)parts.push('Heals 1 HP');
  if(m.flux)parts.push(m.flux>0?'+1 Flux recovery':'−1 Flux recovery');
  if(m.cleanse)parts.push('Cleanses and prevents ailments');
  for(const status of m.statuses??[]){const name=STATUS_DEFINITIONS.find(entry=>entry.id===status.id)?.name||status.id;parts.push(`${name}${status.id==='ward'?` ${status.power??1}`:''} · ${status.turns} round${status.turns===1?'':'s'}`);}
  if(m.wellBonus)parts.push('Occupied spring restores 2 Flux');
  if(m.consume)parts.push('Disperses after this exchange');
  return {field:field.id,name:ice&&field.id==='water'?'Ice':field.name,shortRule:parts.join(' · '),elements:[...field.elements],ice,symbol:ice&&field.id==='water'?'❄':field.symbol,color:ice&&field.id==='water'?'#9ddce8':field.color};
}

/** A candidate replaces just this character's queued cast. With no candidate,
 * the same result stays available after a tap has queued the action.
 * Allied movement conflicts are certain. Rival landings remain deliberately unknown.
 */
export function planningForecast(state:SimState,player:Player,input:TeamPlan,selectedUnitId:string|null,spellId?:string,aim?:Point,options:VolleyOptions={}):PlanningForecast|null {
  const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit));
  const selected=own.find(unit=>unit.id===selectedUnitId);
  if(!selected||state.winner!==null)return null;
  // Even a caller with a mixed plan cannot introduce a private rival order here.
  let orders=input.orders.filter(order=>own.some(unit=>unit.id===order.unitId));
  const queued=orders.find(order=>order.unitId===selected.id);
  if(spellId&&aim)orders=[...orders.filter(order=>order.unitId!==selected.id),{unitId:selected.id,...(queued?.move?{move:queued.move}:{}),spellId,cast:at(aim),...(options.selectedScroll?{scroll:true as const}:{})}];
  let plan:TeamPlan;
  try{plan=options.rules?options.rules.validatePlan({orders}):validatePlan(state,player,{orders});}catch{return null;}
  const selectedOrder=plan.orders.find(order=>order.unitId===selected.id)!;
  if(!selectedOrder.cast||!selectedOrder.spellId)return null;
  const volley=projectedVolley(state,player,plan,false,options),{positions}=volley,castEntries=volley.casts;
  const selectedCast=castEntries.find(cast=>cast.unitId===selected.id);
  const result:PlanningForecast={unitId:selected.id,spellId:selectedOrder.spellId,aim:at(selectedOrder.cast),origin:at(positions.get(selected.id)!),cells:[],groups:[],allies:[],clashes:volley.clashes,blocked:!selectedCast,landingDependent:!!selectedOrder.move&&!(options.rules?options.rules.legalCasts(selected.id,undefined,selectedOrder.spellId,selectedOrder):legalCasts(state,selected.id,undefined,selectedOrder.spellId)).some(cell=>same(cell,selectedOrder.cast!))};
  if(!selectedCast)return result;
  const casts:VisibleCast[]=volley.fields;
  const meeting=volley.clashes.find(clash=>clash.participants.includes(selected.id));
  const affected=meeting?interceptionFieldArea(state.cells,meeting):selectedCast.area;
  const intents=inhabitantIntents(state),groups=new Map<string,ForecastGroup>();
  result.cells=affected.map(cell=>{
    const after=visibleFieldForecast(cell,casts,intents),description=describeField(after),before=fieldCombination(cell);
    const id=description.field+(description.ice?':ice':'');
    const group=groups.get(id);
    if(group)group.count++;else groups.set(id,{id,name:description.name,shortRule:description.shortRule,count:1,elements:[...description.elements],symbol:description.symbol,color:description.color});
    return {...at(cell),...description,changed:before?.id!==description.field||isIce(cell)!==description.ice};
  });
  result.groups=[...groups.values()].sort((a,b)=>b.count-a.count||a.id.localeCompare(b.id));
  const spell=selectedCast.spell;
  if(!meeting&&spell.harm==='all'&&(spell.damage||spell.harmful?.length||spell.push))result.allies=own.filter(unit=>selectedCast.area.some(cell=>same(cell,positions.get(unit.id)!))).map(unit=>({id:unit.id,name:unit.displayName??getChampion(unit.championId).name}));
  return result;
}
