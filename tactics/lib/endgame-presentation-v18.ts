import type {Point,SimCell} from './tactics-v16.ts';
import type {EndgameForecast} from './endgame-v18.ts';
import {rangeBoundaryPath} from './range-outline-v16.ts';

export type EndgameCellState='safe'|'closing'|'unsafe';
const distance=(point:Point,centre:Point)=>Math.max(Math.abs(point.q-centre.q),Math.abs(point.r-centre.r),Math.abs(point.q+point.r-centre.q-centre.r));
export function endgameCellState(zone:EndgameForecast|undefined,point:Point):EndgameCellState {
  if(!zone||zone.phase==='calm')return 'safe';
  const radius=distance(point,zone.centre);
  if(zone.damage>0&&radius>zone.safeRadius)return 'unsafe';
  return zone.nextChangeRound!==null&&radius>zone.nextSafeRadius?'closing':'safe';
}
export function endgameCellDescription(zone:EndgameForecast|undefined,point:Point):string {
  const state=endgameCellState(zone,point);
  if(!zone||state==='safe')return '';
  if(state==='unsafe')return `Collapse: ${zone.damage} damage after this exchange, at the final landing. Guard, Ward and elemental cover do not reduce it.`;
  return `Closing ground: becomes unsafe in round ${zone.nextChangeRound}; ${zone.nextDamage} damage after that exchange. Move inside the dashed boundary.`;
}
/** The border follows real elevated hex edges. It never masks terrain, legal
 * targets or spell range, and never draws internal grid lines. */
export function endgameBoundaries(zone:EndgameForecast|undefined,cells:readonly SimCell[]):{current:string;next:string} {
  if(!zone||zone.phase==='calm')return {current:'',next:''};
  const height=(point:Point)=>cells.find(cell=>cell.q===point.q&&cell.r===point.r)?.height||0;
  const current=zone.damage>0?rangeBoundaryPath(cells.filter(cell=>distance(cell,zone.centre)<=zone.safeRadius),height):'';
  const next=zone.nextChangeRound!==null&&zone.nextSafeRadius<zone.safeRadius?rangeBoundaryPath(cells.filter(cell=>distance(cell,zone.centre)<=zone.nextSafeRadius),height):'';
  return {current,next};
}
