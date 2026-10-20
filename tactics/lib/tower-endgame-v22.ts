/** Tower rooms close after a visible warning; only actual elimination decides a winner. */
import {distance,type Point} from './game.ts';
import type {EndgameForecast,EndgameState} from './endgame-v18.ts';
export type TowerEndgameState=EndgameState&{tower?:{encounter?:'combat'|'elite'|'boss'}};
export type {EndgameForecast};
export const COLLAPSE_FINAL_DAMAGE=8;
export function endgameForecast(state:TowerEndgameState):EndgameForecast {
 if(!Number.isInteger(state.boardRadius)||state.boardRadius<9||state.boardRadius>13||state.playerCount!==2||!Number.isInteger(state.round)||state.round<1)throw new Error('Invalid tower boundary.');
 const firstClosureRound=state.tower?.encounter==='boss'?8:6,finalRound=firstClosureRound+6;
 const wave=state.round<firstClosureRound?0:Math.min(4,Math.floor((state.round-firstClosureRound)/2)+1);
 const radiusAt=(at:number)=>Math.max(0,Math.floor((state.boardRadius-1)*(4-at)/4));
 const safeRadius=wave===0?state.boardRadius:radiusAt(wave),damage=wave===0?0:wave===4?8:wave;
 const nextWave=Math.min(4,wave+1),nextSafeRadius=radiusAt(nextWave),nextDamage=nextWave===4?8:nextWave,nextChangeRound=wave===4?null:firstClosureRound+wave*2;
 return {phase:wave===4?'last-stand':wave>0?'closing':state.round>=firstClosureRound-2?'warning':'calm',round:state.round,centre:{q:0,r:0},safeRadius,damage,nextSafeRadius,nextDamage,nextChangeRound,firstClosureRound,finalRound};
}
export const isSafe=(point:Point,radius:number)=>distance(point,{q:0,r:0})<=radius;
export function collapseDamageAt(state:TowerEndgameState,point:Point):number {const zone=endgameForecast(state);return isSafe(point,zone.safeRadius)?0:zone.damage;}
export function endgamePositionValue(state:TowerEndgameState,point:Point,hp:number):number {
 const zone=endgameForecast(state),range=distance(point,zone.centre),damage=range>zone.safeRadius?zone.damage:0;
 const imminent=zone.nextChangeRound!==null&&zone.nextChangeRound-state.round<=2,future=imminent&&range>zone.nextSafeRadius?zone.nextDamage*(zone.nextChangeRound===state.round+1?4:1.5):0;
 return -damage*8-(damage>=hp&&damage>0?250:0)-Math.max(0,range-zone.safeRadius)*2-future-(zone.phase==='closing'?range*Math.max(0,5-zone.safeRadius)*.8:0);
}
