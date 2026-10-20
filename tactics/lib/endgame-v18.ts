/** One visible spatial endgame, derived entirely from the canonical arena and round. */
import {distance,type Point} from './game.ts';
import type {PlayerCount} from './arena-v17.ts';
export type EndgameState={round:number;playerCount:PlayerCount;boardRadius:number};
export type EndgameForecast={
  phase:'calm'|'warning'|'closing'|'last-stand';round:number;centre:Point;
  /** Radius and damage applied after THIS planning round's final displacement. */
  safeRadius:number;damage:number;
  /** Next scheduled boundary, paired with nextChangeRound; not necessarily next round. */
  nextSafeRadius:number;nextDamage:number;nextChangeRound:number|null;
  firstClosureRound:number;finalRound:number;
};
export const COLLAPSE_FINAL_DAMAGE=8;
export function endgameForecast(state:EndgameState):EndgameForecast {
  const radius=state.playerCount+7;
  if(state.boardRadius!==radius||!Number.isInteger(state.round)||state.round<1||![2,3,4,5,6].includes(state.playerCount))throw new Error('Invalid collapse geometry or round.');
  const firstClosureRound=state.playerCount+8,finalWave=Math.ceil(radius/2),finalRound=firstClosureRound+(finalWave-1)*2;
  const wave=state.round<firstClosureRound?0:Math.min(finalWave,Math.floor((state.round-firstClosureRound)/2)+1);
  const safeRadius=Math.max(0,radius-2*wave),damage=wave===0?0:safeRadius===0?COLLAPSE_FINAL_DAMAGE:wave;
  const nextWave=Math.min(finalWave,wave+1),nextSafeRadius=Math.max(0,radius-2*nextWave),nextDamage=nextSafeRadius===0?COLLAPSE_FINAL_DAMAGE:nextWave;
  const nextChangeRound=wave===finalWave?null:firstClosureRound+wave*2;
  return {phase:wave===finalWave?'last-stand':wave>0?'closing':state.round>=firstClosureRound-2?'warning':'calm',round:state.round,centre:{q:0,r:0},safeRadius,damage,nextSafeRadius,nextDamage,nextChangeRound,firstClosureRound,finalRound};
}
export const isSafe=(point:Point,radius:number):boolean=>distance(point,{q:0,r:0})<=radius;
export function collapseDamageAt(state:EndgameState,point:Point):number {
  const zone=endgameForecast(state);return isSafe(point,zone.safeRadius)?0:zone.damage;
}
/** Public information only. Current lethal exposure outweighs speculative attacks. */
export function endgamePositionValue(state:EndgameState,point:Point,hp:number):number {
  const zone=endgameForecast(state),range=distance(point,zone.centre),damage=range>zone.safeRadius?zone.damage:0;
  const imminent=zone.nextChangeRound!==null&&zone.nextChangeRound-state.round<=2;
  const future=imminent&&range>zone.nextSafeRadius?zone.nextDamage*(zone.nextChangeRound===state.round+1?4:1.5):0;
  // Claim useful interior ground before the last two rounds. Waiting at the
  // safe edge makes every company rush the single final hex at once.
  const interior=zone.phase==='closing'?range*Math.max(0,5-zone.safeRadius)*.8:0;
  return -damage*8-(damage>=hp&&damage>0?250:0)-Math.max(0,range-zone.safeRadius)*2-future-interior;
}
