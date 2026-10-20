import {endgameForecast,collapseDamageAt,isSafe,type TowerEndgameState,type EndgameForecast} from './tower-endgame-v22.ts';
import type {Point} from './game.ts';
export function landingBoundaryNote(state:TowerEndgameState,point:Point):{severity:'danger'|'future';damage:number;round:number;text:string}|null{
 const zone=endgameForecast(state),damage=collapseDamageAt(state,point);
 if(damage)return {severity:'danger',damage,round:state.round,text:`Exposed landing · ${damage} damage after spells`};
 if(zone.phase!=='calm'&&zone.nextChangeRound!==null&&!isSafe(point,zone.nextSafeRadius))return {severity:'future',damage:zone.nextDamage,round:zone.nextChangeRound,text:`Outside next ring · ${zone.nextDamage} damage from round ${zone.nextChangeRound}`};
 return null;
}
export function frontierReadout(zone:EndgameForecast):{title:string;detail:string}|null{
 if(zone.phase==='calm')return null;
 if(zone.phase==='warning')return {title:`Closing ground · round ${zone.firstClosureRound}`,detail:`Outside the highlighted safe area: ${zone.nextDamage} damage after spells`};
 if(zone.phase==='last-stand')return {title:'Centre only',detail:`${zone.damage} damage outside after spells`};
 return {title:`${zone.damage} damage outside the ring`,detail:`Safe radius ${zone.safeRadius} · next closure round ${zone.nextChangeRound}`};
}
