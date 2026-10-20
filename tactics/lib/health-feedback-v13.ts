import type {Point,SimState} from './tactics-v13.ts';

export type ActualHealthFeedback={delta:number;label:string;kind:'heal'|'damage';point:Point};
/** Resolution numbers describe visible HP, not nominal healing or overkill.
 * Returning characters have a separate RETURN cue; their restored HP is not a heal.
 */
export function actualHealthFeedback(previous:SimState|undefined,next:SimState):Map<string,ActualHealthFeedback>{
  const result=new Map<string,ActualHealthFeedback>();
  if(!previous||previous.mapId!==next.mapId||previous.version+1!==next.version)return result;
  for(const unit of next.units){
    const old=previous.units.find(entry=>entry.id===unit.id);
    if(!old||old.hp<=0||old.respawn!==undefined)continue;
    const delta=unit.hp-old.hp;
    if(!delta)continue;
    result.set(unit.id,{delta,label:`${delta>0?'+':'−'}${Math.abs(delta)} HP`,kind:delta>0?'heal':'damage',point:{q:unit.q,r:unit.r}});
  }
  return result;
}
