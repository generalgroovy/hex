import {movementPath,type Point,type SimState} from './tactics-v12.ts';
import {surfacePoint} from './battlefield-geometry.ts';
import {PHASE_MS} from './feedback-v12.ts';

/** The existing board clock: travel, cast hold, then displacement. */
export const UNIT_MOTION_MS=1400;
export type MovementFrame={atMs:number;point:Point;x:number;y:number;phase:'move'|'hold'|'push'};
export type BattlefieldMotion={
  animationName:string;
  keyframes:string;
  durationMs:number;
  frames:MovementFrame[];
  movePath:Point[];
  pushPath:Point[];
  style:{animationName:string;animationDuration:string;animationTimingFunction:'linear';animationFillMode:'both';animationDelay:string;animationIterationCount:number};
};
const same=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
const point=(at:Point):Point=>({q:at.q,r:at.r});
const key=(at:Point)=>`${at.q},${at.r}`;
const rounded=(value:number)=>Number(value.toFixed(6));
const identifier=(value:string)=>Array.from(value,character=>character.codePointAt(0)!.toString(16)).join('_')||'0';

/** Push events include exact successful endpoints, even if their ice expires afterward. */
function crossedPush(from:Point,to:Point):Point[] {
  const dq=to.q-from.q,dr=to.r-from.r;
  const steps=Math.max(Math.abs(dq),Math.abs(dr),Math.abs(dq+dr));
  if(!steps)return [];
  if(dq!==0&&dr!==0&&dq!==-dr)return [point(to)];
  return Array.from({length:steps},(_,index)=>({q:from.q+dq/steps*(index+1),r:from.r+dr/steps*(index+1)}));
}

/**
 * CSS is generated from the authoritative route, not a straight endpoint tween.
 * A scope from React useId keeps multiple boards/replays isolated. Apply style to
 * the outer .px-unit-moving layer, and keep hit/bounce transforms on a child.
 * Existing reduced-motion CSS disables this animation through !important.
 */
export function battlefieldMotion(previous:SimState|undefined,next:SimState,unitId:string,scope='board'):BattlefieldMotion|null {
  const unit=next.units.find(entry=>entry.id===unitId);
  const events=next.lastResolution.filter(event=>event.unitId===unitId);
  const move=events.find(event=>event.kind==='move'&&event.from&&event.to);
  const pushes=events.filter(event=>event.kind==='push'&&event.from&&event.to);
  if(!unit||(!move&&!pushes.length))return null;
  const old=previous?.units.find(entry=>entry.id===unitId);
  let movePath:Point[]=[];
  if(move){
    // Without the matching planning snapshot, do not invent a path across ruins.
    if(!previous||previous.version+1!==next.version||previous.mapId!==next.mapId||!old||!same(old,move.from!))return null;
    const route=movementPath(previous,unitId,move.to!);
    if(!route)return null;
    movePath=route.map(point);
  }
  const start=move?.from||pushes[0]?.from;
  if(!start)return null;
  const pushPath:Point[]=[];
  let cursor=movePath.at(-1)||start;
  for(const push of pushes){
    // Refuse inconsistent event streams instead of interpolating an unseen jump.
    if(!same(cursor,push.from!))return null;
    pushPath.push(...crossedPush(push.from!,push.to!));cursor=push.to!;
  }
  if(!same(cursor,unit))return null;
  const beforeCells=new Map((previous?.cells||next.cells).map(cell=>[key(cell),cell]));
  const afterCells=new Map(next.cells.map(cell=>[key(cell),cell]));
  const final=surfacePoint(unit,afterCells.get(key(unit))?.height||0);
  const frames:MovementFrame[]=[];
  function frame(atMs:number,at:Point,phase:MovementFrame['phase']) {
    const cells=phase==='push'?afterCells:beforeCells;
    const location=surfacePoint(at,cells.get(key(at))?.height||0);
    frames.push({atMs:rounded(atMs),point:point(at),x:rounded(location.x-final.x),y:rounded(location.y-final.y),phase});
  }
  frame(0,start,'move');
  movePath.forEach((at,index)=>frame(PHASE_MS.cast*(index+1)/movePath.length,at,'move'));
  if(!movePath.length)frame(PHASE_MS.cast,start,'hold');
  const casting=movePath.at(-1)||start;
  frame(PHASE_MS.impact,casting,'hold');
  pushPath.forEach((at,index)=>frame(PHASE_MS.impact+(UNIT_MOTION_MS-PHASE_MS.impact)*(index+1)/pushPath.length,at,'push'));
  if(!pushPath.length)frame(UNIT_MOTION_MS,unit,'hold');
  // Snapshot identity is part of the name so distinct replay data cannot share CSS.
  let hash=2166136261;
  for(const character of JSON.stringify(frames)){hash^=character.charCodeAt(0);hash=Math.imul(hash,16777619)}
  const animationName=`px-v9-route-${identifier(scope)}-${identifier(unitId)}-${(hash>>>0).toString(36)}`;
  // Ease only the complete voluntary route's departure and arrival. Interior
  // tiles, including a continuous ice lane, stay linear with no invented stop.
  // The easing controls stay inside [0,1], so motion never leaves its real path.
  const keyframes=`@keyframes ${animationName}{${frames.map((frame,index)=>{
    const easing=movePath.length===1&&index===0?'cubic-bezier(.4,.08,.6,.92)':movePath.length>1&&index===0?'cubic-bezier(.4,.08,.75,.75)':movePath.length>1&&index===movePath.length-1?'cubic-bezier(.25,.25,.6,.92)':null;
    return `${rounded(frame.atMs/UNIT_MOTION_MS*100)}%{transform:translate(${frame.x}px,${frame.y}px)${easing?`;animation-timing-function:${easing}`:''}}`;
  }).join('')}}`;
  return {animationName,keyframes,durationMs:UNIT_MOTION_MS,frames,movePath,pushPath,style:{animationName,animationDuration:`${UNIT_MOTION_MS}ms`,animationTimingFunction:'linear',animationFillMode:'both',animationDelay:'0ms',animationIterationCount:1}};
}
