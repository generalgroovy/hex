import type {Point,SimState,SimEvent} from './tactics-v16.ts';
import {formatTile} from './board-labels-v17.ts';

/** Rules 17 chooses the same route among equal-cost paths for every seat.
 * Ownership in this isolated geometry snapshot is only the v16 path tie-break
 * adapter; the board's actual ownership, health and allegiance stay unchanged. */
export function canonicalMotionSnapshot(state:SimState,canonical:boolean):SimState {
  return canonical?{...state,units:state.units.map(unit=>({...unit,owner:0}))}:state;
}

/** Legacy advice computes real occupancy but embeds radius-nine coordinates.
 * Re-label only those known coordinate phrases using the displayed board. */
export function movementAdviceText(text:string|undefined,target:Point,radius:number):string|undefined {
  return text?.replace(/\b(stays on|occupies) (?:[A-Z]{1,2}\d{1,2}|—)/g,(_,verb:string)=>`${verb} ${formatTile(target,radius)}`);
}

const meaningful=new Set<SimEvent['kind']>(['move','cast','push','damage','heal','defeat','respawn','clash']);
/** Distant companies that only Guard must not force a 547-hex camera overview.
 * Actual paths and spell footprints are framed separately by the board. */
export function resolutionActorIds(previous:SimState|undefined,state:SimState,events:readonly SimEvent[],ownIds:readonly string[],focusEncounter:boolean):Set<string> {
  const all=new Set([...previous?.units||[],...state.units].filter(unit=>unit.hp>0||events.some(event=>event.unitId===unit.id&&event.kind==='defeat')).map(unit=>unit.id));
  if(!focusEncounter)return all;
  const collapseIds=new Set(events.filter(event=>(event as SimEvent&{cause?:string}).cause==='collapse').flatMap(event=>event.unitId?[event.unitId]:[]));
  const active=new Set(events.filter(event=>meaningful.has(event.kind)&&(event as SimEvent&{cause?:string}).cause!=='collapse'&&!(event.kind==='defeat'&&event.unitId&&collapseIds.has(event.unitId))).flatMap(event=>[...(event.unitId?[event.unitId]:[]),...(event.participants||[])]));
  // The world boundary and company list explain remote collapse casualties;
  // keep the viewer's own losses visible without zooming out to every camper.
  for(const id of ownIds)if(collapseIds.has(id))active.add(id);
  if(active.size)return active;
  const own=ownIds.filter(id=>all.has(id));
  return own.length?new Set(own):all;
}
