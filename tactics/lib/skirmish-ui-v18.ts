/** Small public-state readouts. None of these helpers accepts another seat's plan. */
import {getSpell,type SimState,type Seat,type TeamPlan} from './tactics-v18.ts';
import {formatTile} from './board-labels-v17.ts';
import {collapseDamageAt,endgameForecast,isSafe,type EndgameForecast,type EndgameState} from './endgame-v18.ts';
import type {ArenaPlayer,ArenaRoom} from './skirmish-client-v18.ts';
import type {Point} from './game.ts';
const alive=(unit:SimState['units'][number])=>unit.hp>0&&unit.respawn===undefined;
export function companyOrderSummary(state:SimState,seat:Seat,plan:TeamPlan){
 return state.units.filter(unit=>unit.owner===seat).map(unit=>{
  const order=plan.orders.find(entry=>entry.unitId===unit.id),active=alive(unit),ready=active&&!!(order?.guard||order?.cast&&order.spellId);
  const movement=order?.move?`Move ${formatTile(order.move,state.boardRadius)}`:'Hold';
  const action=order?.cast&&order.spellId?getSpell(order.spellId).name:order?.guard?'Guard':'Choose action';
  return {id:unit.id,active,ready,movement,action,label:active?`${movement} · ${action}`:'Defeated'};
 });
}
export function nextCompanyAction(state:SimState,seat:Seat,plan:TeamPlan,selected:string|null):string|null{
 const own=companyOrderSummary(state,seat,plan).filter(entry=>entry.active);if(!own.length)return null;
 const index=own.findIndex(entry=>entry.id===selected),after=[...own.slice(index+1),...own.slice(0,index+1)];
 return (after.find(entry=>!entry.ready&&entry.id!==selected)??after.find(entry=>entry.id!==selected)??own[0]).id;
}
export function opponentGroups(room:Pick<ArenaRoom,'players'|'mode'>,state:SimState,seat:Seat):{id:string;label:string;players:ArenaPlayer[]}[]{
 const players=room.players.filter((player):player is ArenaPlayer=>!!player&&player.seat!==seat);
 const standing=(player:ArenaPlayer)=>state.units.some(unit=>unit.owner===player.seat&&alive(unit));
 const ordered=(list:ArenaPlayer[])=>[...list].sort((a,b)=>Number(standing(b))-Number(standing(a))||a.seat-b.seat);
 if(room.mode==='free-for-all')return [{id:'rivals',label:'Rivals',players:ordered(players)}];
 const ownTeam=state.teams[seat];
 return [{id:'allies',label:`Allies · Team ${ownTeam+1}`,players:ordered(players.filter(player=>state.teams[player.seat]===ownTeam))},
  {id:'enemies',label:`Enemies · Team ${ownTeam===0?2:1}`,players:ordered(players.filter(player=>state.teams[player.seat]!==ownTeam))}].filter(group=>group.players.length);
}
export function landingBoundaryNote(state:EndgameState,point:Point):{severity:'danger'|'future';damage:number;round:number;text:string}|null{
 const zone=endgameForecast(state),damage=collapseDamageAt(state,point);
 if(damage)return {severity:'danger',damage,round:state.round,text:`Exposed landing · ${damage} damage after spells`};
 if(zone.phase!=='calm'&&zone.nextChangeRound!==null&&!isSafe(point,zone.nextSafeRadius))return {severity:'future',damage:zone.nextDamage,round:zone.nextChangeRound,text:`Outside next ring · ${zone.nextDamage} damage from round ${zone.nextChangeRound}`};
 return null;
}
export function frontierReadout(zone:EndgameForecast):{title:string;detail:string}|null{
 if(zone.phase==='calm')return null;
 if(zone.phase==='warning')return {title:`Closing ground · starts round ${zone.firstClosureRound}`,detail:`Outer two rings take ${zone.nextDamage} damage after spells`};
 if(zone.phase==='last-stand')return {title:'Centre only',detail:`${zone.damage} damage outside after spells`};
 return {title:`${zone.damage} damage outside the ring`,detail:`Safe radius ${zone.safeRadius} · next closure round ${zone.nextChangeRound}`};
}
export const legacyArenaUrl=(code:string)=>`/skirmish/legacy?room=${encodeURIComponent(code)}`;
