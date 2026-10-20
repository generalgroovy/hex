import {groundPoint,type HexPoint,type ScreenPoint} from './battlefield-geometry.ts';
import type {SimState,StatusId} from './tactics-v16.ts';

/** The resolver uses one flat hex plane. Terrain still raises the ground and
 * characters, but cannot bend a projectile route or separate a real collision. */
export function flightPoint(point:HexPoint):ScreenPoint {
 const at=groundPoint(point);return {x:at.x,y:at.y-44};
}

/** Large areas keep their complete footprint, but only a few distributed
 * material accents. Sampling never decides which cells receive an effect. */
export function effectAccentCells(cells:readonly HexPoint[],center:HexPoint,limit=5):Set<string>{
 const key=(point:HexPoint)=>`${point.q},${point.r}`;
 const distance=(a:HexPoint,b:HexPoint)=>Math.max(Math.abs(a.q-b.q),Math.abs(a.r-b.r),Math.abs(a.q+a.r-b.q-b.r));
 const candidates=[...cells].filter(cell=>key(cell)!==key(center)).sort((a,b)=>a.q-b.q||a.r-b.r);
 const selected:HexPoint[]=[center],result=new Set<string>();
 while(candidates.length&&result.size<Math.max(0,limit)){
  let best=0,furthest=-1;
  candidates.forEach((cell,index)=>{const separation=Math.min(...selected.map(point=>distance(point,cell)));if(separation>furthest){furthest=separation;best=index;}});
  const [cell]=candidates.splice(best,1);selected.push(cell);result.add(key(cell));
 }
 return result;
}

/** Individual HP divisions become noise on a 60px bar at high affinity.
 * Preserve exact fill and expose only a few consistent five-HP landmarks. */
export function healthBarTicks(maxHp:number):number[]{
 if(!Number.isFinite(maxHp)||maxHp<=1)return [];
 const step=maxHp<=10?1:Math.max(5,Math.ceil(maxHp/50)*5),ticks:number[]=[];
 for(let hp=step;hp<maxHp;hp+=step)ticks.push(hp/maxHp);
 return ticks;
}

export type ConditionChange={id:StatusId;added:boolean};
/** One consequential changed condition per fighter keeps the board readable.
 * Full status durations remain in inspection and the unabridged round report. */
export function conditionChanges(previous:SimState|undefined,next:SimState):Map<string,ConditionChange>{
 const result=new Map<string,ConditionChange>();
 if(!previous||previous.mapId!==next.mapId||previous.version+1!==next.version)return result;
 const priority:StatusId[]=['rooted','concussed','blind','burn','chilled','wither','wet','ward','haste','clarity','anchored','resolve'];
 for(const unit of next.units){
  const old=previous.units.find(entry=>entry.id===unit.id);if(!old||old.hp<=0||unit.hp<=0||unit.respawn!==undefined)continue;
  const added=priority.find(id=>unit.statuses[id]?.turns&&!old.statuses[id]?.turns);
  const removed=priority.find(id=>old.statuses[id]?.turns&&!unit.statuses[id]?.turns);
  if(added||removed)result.set(unit.id,{id:(added??removed)!,added:!!added});
 }
 return result;
}
