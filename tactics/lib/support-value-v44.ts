import type {Spell,StatusId,StatusApplication} from './spells-v20.ts';
import type {CombinationMechanics} from './combinations-v16.ts';
type Fighter={statuses:Partial<Record<StatusId,{turns:number;power:number}>>};
/** New Ward is valued after the exchange, never as protection from its incoming
 * damage. Known fields and queued allied buffs are not counted
 * twice. A live Ward may be consumed, so renewal keeps bounded future value. */
export function friendlyStatusValue(unit:Fighter,spell:Spell,effects:Readonly<CombinationMechanics>,prior:readonly Spell[]=[],underPressure=false):number{
 const incoming=spell.friendly??[],known=[...(effects.statuses??[]),...prior.flatMap(effect=>effect.friendly??[])];
 let value=0;
 for(const id of new Set(incoming.map(effect=>effect.id))){
  const next=incoming.filter(effect=>effect.id===id),previous=known.filter(effect=>effect.id===id);
  const strength=(values:readonly StatusApplication[])=>Math.max(0,...values.map(effect=>effect.power??1));
  const duration=(values:readonly StatusApplication[])=>Math.max(0,...values.map(effect=>effect.turns));
  const old=unit.statuses[id],remaining=Math.max(0,(old?.turns??0)-1);
  if(id==='ward'){
   // Immediate incoming damage consumes old Ward. Without sealed orders this
   // is a risk-weighted reserve, not a guaranteed unused shield.
   const carried=remaining?old?.power??0:0,knownPower=strength(previous),power=strength(next);
   const retained=Math.max(0,power-Math.max(carried,knownPower)),consumed=Math.max(0,power-knownPower);
   // Average complete scenarios: averaging the old power before max() would
   // wrongly erase useful weaker renewals when a stronger old Ward is hit.
   value+=(underPressure?(retained+consumed)/2:retained)*.5;
   if(duration(next)>Math.max(remaining,duration(previous)))value+=.2;
  }else{
   const beforeTurns=Math.max(remaining,duration(previous)),beforePower=Math.max(remaining?old?.power??0:0,strength(previous));
   if(strength(next)>beforePower||duration(next)>beforeTurns)value+=.5;
  }
 }
 return value;
}
