import {isAlive,legalCasts,legalMoves,type Order,type Point,type SimState} from './tactics-v13.ts';

/** Edit only movement. An independent queued action survives whenever its aim
 * remains legal; callers keep the complete previous plan for one-step Undo. */
export function editMovement(state:SimState,unitId:string,existing:Order|undefined,move?:Point):{order:Order;castRemoved:boolean} {
  const unit=state.units.find(unit=>unit.id===unitId);
  if(!unit||!isAlive(unit)||state.winner!==null)throw new Error('This character cannot change orders.');
  if(move&&!legalMoves(state,unitId).some(cell=>cell.q===move.q&&cell.r===move.r))throw new Error('That landing is out of reach.');
  const origin=move??unit;
  const keepCast=!!existing?.cast&&!!existing.spellId&&legalCasts(state,unitId,origin,existing.spellId).some(cell=>cell.q===existing.cast!.q&&cell.r===existing.cast!.r);
  return {order:{...existing,unitId,move:move?{q:move.q,r:move.r}:undefined,cast:keepCast?{...existing!.cast!}:undefined,spellId:keepCast?existing!.spellId:undefined,guard:keepCast?undefined:existing?.guard},castRemoved:!!existing?.cast&&!keepCast};
}
