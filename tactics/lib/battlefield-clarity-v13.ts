import {groundPoint,type HexPoint} from './battlefield-geometry.ts';

export function screenFacing(from:HexPoint,to:HexPoint,fallback=0):number {
  const a=groundPoint(from),b=groundPoint(to);
  return a.x===b.x&&a.y===b.y?fallback:((Math.round(Math.atan2(b.x-a.x,b.y-a.y)/(Math.PI/4))%8)+8)%8;
}
/** Travel uses the real departure, then the character turns to release a spell. */
export function resolutionFacing(phase:'move'|'cast'|'impact'|'settle',from:HexPoint,route:readonly HexPoint[],cast:{from?:HexPoint;to?:HexPoint}|undefined,fallback=0):number {
  if(phase==='move'&&route.length)return screenFacing(from,route[0],fallback);
  if(cast?.to)return screenFacing(cast.from||route.at(-1)||from,cast.to,fallback);
  return route.length?screenFacing(route.length>1?route[route.length-2]:from,route[route.length-1],fallback):fallback;
}

/** Surface the conditions that most change a decision before ordinary buffs. */
const STATUS_PRIORITY = ['rooted','concussed','blind','burn','wither','chilled','wet','anchored','ward','clarity','resolve','haste'];
export function visibleStatusStack(statuses:Readonly<Record<string,{turns:number}|undefined>>,limit=2) {
  const active=Object.entries(statuses).filter((entry):entry is [string,{turns:number}]=>!!entry[1]&&entry[1].turns>0)
    .sort(([left],[right])=>{
      const a=STATUS_PRIORITY.indexOf(left),b=STATUS_PRIORITY.indexOf(right);
      return (a<0?STATUS_PRIORITY.length:a)-(b<0?STATUS_PRIORITY.length:b)||left.localeCompare(right);
    });
  const count=Math.max(0,Math.floor(limit));
  return {visible:active.slice(0,count),hidden:Math.max(0,active.length-count)};
}
