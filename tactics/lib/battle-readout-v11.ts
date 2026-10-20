import {formatTile} from './board-labels-v9.ts';
import {getChampion, getSpell, isAlive, type SimState, type TeamPlan, type Player} from './tactics-v11.ts';

/** These are public board facts, not a prediction of hidden enemy orders. */
export function wellControl(state:SimState) {
 const teams:[{count:number;value:number},{count:number;value:number}]=[{count:0,value:0},{count:0,value:0}];
 for(const cell of state.cells.filter(c=>c.well)) {
  const occupant=state.units.find(u=>isAlive(u)&&u.q===cell.q&&u.r===cell.r);
  if(!occupant)continue;
  teams[occupant.owner].count++;
  teams[occupant.owner].value+=cell.reactions?.includes('penumbra')?2:1;
 }
 return teams;
}

export function teamOrders(state:SimState,player:Player,plan:TeamPlan) {
 return state.units.filter(u=>u.owner===player).map(unit=>{
  const order=plan.orders.find(o=>o.unitId===unit.id);
  const active=isAlive(unit),planned=active&&!!order;
  const movement=order?.move?`Move ${formatTile(order.move)}`:'Hold';
  const action=order?.cast&&order.spellId?`${getSpell(order.spellId).name} → ${formatTile(order.cast)}`:'Guard';
  return {id:unit.id,name:getChampion(unit.championId).name,active,planned,movement,action,label:active?`${movement} · ${action}`:'Recovering'};
 });
}

export function nextUnplannedUnit(state:SimState,player:Player,plan:TeamPlan,selected:string|null):string|null {
 const own=teamOrders(state,player,plan).filter(u=>u.active);
 if(!own.length)return null;
 const index=own.findIndex(u=>u.id===selected);
 const ordered=[...own.slice(index+1),...own.slice(0,index+1)];
 return (ordered.find(u=>!u.planned&&u.id!==selected)||ordered.find(u=>u.id!==selected)||own[0]).id;
}
