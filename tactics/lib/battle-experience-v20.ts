import {STATUS_DEFINITIONS,getChampion,castAvailability,type SimState,type SimEvent,type TeamPlan} from './tactics-v20.ts';
import {getSpell} from './spells-v20.ts';
import {eventPhase,type ResolutionPhase} from './feedback-v16.ts';
import {formatTile} from './board-labels-v17.ts';

export const actorName=(unit:SimState['units'][number])=>unit.displayName??getChampion(unit.championId).name;
export function queuedOrderLabel(state:SimState,plan:TeamPlan,id:string):string {
 const unit=state.units.find(actor=>actor.id===id);if(!unit)return '';
 const order=plan.orders.find(entry=>entry.unitId===id);
 const move=order?.move?`→ ${formatTile(order.move,state.boardRadius)} · `:'';
 return move+(order?.cast&&order.spellId?`${getSpell(order.spellId).name} · ${castAvailability(state,unit.id,order.spellId).cost} F`:order?.guard?'Guard':'Auto Guard');
}
export function nextUnplannedId(state:SimState,plan:TeamPlan,current:string|null):string|null {
 const units=state.units.filter(unit=>unit.owner===0&&unit.hp>0&&unit.respawn===undefined);
 const index=units.findIndex(unit=>unit.id===current),ordered=[...units.slice(index+1),...units.slice(0,index+1)];
 return (ordered.find(unit=>{const order=plan.orders.find(entry=>entry.unitId===unit.id);return !order?.guard&&!order?.cast})??ordered[0])?.id??null;
}
export type UnitOutcome={id:string;name:string;owner:number;hpBefore:number;hpAfter:number;hpDelta:number;fluxBefore:number;fluxAfter:number;fluxDelta:number;defeated:boolean;changes:string[]};
export function roundOutcomes(previous:SimState,next:SimState):UnitOutcome[]{
 return next.units.map(unit=>{
  const old=previous.units.find(actor=>actor.id===unit.id)??unit;
  const changes:string[]=[];
  for(const definition of STATUS_DEFINITIONS){
   const before=old.statuses[definition.id],after=unit.statuses[definition.id];
   if(after&&after.turns>0&&(!before||before.turns!==after.turns||before.power!==after.power))changes.push(`${definition.name} ${after.turns}r`);
   else if(before&&before.turns>0&&(!after||after.turns<=0))changes.push(`${definition.name} ended`);
  }
  return {id:unit.id,name:actorName(unit),owner:unit.owner,hpBefore:old.hp,hpAfter:unit.hp,hpDelta:unit.hp-old.hp,fluxBefore:old.flux,fluxAfter:unit.flux,fluxDelta:unit.flux-old.flux,defeated:old.hp>0&&unit.hp<=0,changes};
 });
}
export function phaseLedger(state:SimState,phase:ResolutionPhase):SimEvent[]{return state.lastResolution.filter(event=>eventPhase(event as never,state.lastResolution as never)===phase)}
/** Repeated field tiles collapse into one readable row, without hiding their count. */
export function compactEvents(events:readonly SimEvent[]):string[]{
 const result:string[]=[],seen=new Set<string>();
 for(const event of events){
  if((event.kind==='reaction'||event.kind==='surface')&&!event.unitId&&event.terrain){
   const key=`${event.kind}:${event.terrain}`;if(seen.has(key))continue;seen.add(key);
   const group=events.filter(other=>other.kind===event.kind&&other.terrain===event.terrain&&!other.unitId);
   result.push(group.length>1?`${event.text} (${group.length} hexes)` :event.text);
  }else{result.push(event.text)}
 }
 return result;
}
export const learnedSpellNotice=(names:readonly string[])=>names.length?`Learned ${names.join(', ')}. Available for preparation after this battle.`:'';
