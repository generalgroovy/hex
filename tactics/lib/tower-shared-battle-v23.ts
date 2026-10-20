import {carryTowerSupplies} from './tower-supplies-v45.ts';
/** One battlefield per chosen door; progression remains owned by each squad. */
import {createTowerBattle,restoreSimState,validatePlan,type SimState,type TeamPlan,type Player} from './tactics-v22.ts';
import {towerBattleConfig,validateTowerRun,TOWER_FLOORS,type TowerRun} from './tower-v23.ts';
import {teachingForEnemy} from './spells-v20.ts';

export type SharedTowerBattle={id:string;seats:number[];battle:SimState;previous?:SimState;enemyPlan:TeamPlan;readySeats:number[]};
export const sharedActorId=(seat:number,id:string)=>`seat-${seat}:${id}`;
export function createSharedTowerBattle(entries:readonly {seat:number;run:TowerRun}[]):SimState {
 if(entries.length<2||entries.length>6||new Set(entries.map(entry=>entry.seat)).size!==entries.length)throw new Error('A shared battle needs two to six different squads.');
 const ordered=[...entries].sort((a,b)=>a.seat-b.seat),configs=ordered.map(entry=>towerBattleConfig(entry.run)),first=configs[0];
 if(ordered.some(entry=>!Number.isInteger(entry.seat)||entry.seat<0||entry.seat>5)||configs.some(config=>config.id!==first.id||config.mapId!==first.mapId||config.environment!==first.environment))throw new Error('Squads must choose the same floor and door.');
 const allies=configs.flatMap((config,index)=>config.allies.map(actor=>({...actor,id:sharedActorId(ordered[index].seat,actor.id)})));
 const enemies=configs.flatMap((config,index)=>config.enemies.map(actor=>({...actor,id:sharedActorId(ordered[index].seat,actor.id)})));
 const controllers=Object.fromEntries(configs.flatMap((config,index)=>config.allies.map(actor=>[sharedActorId(ordered[index].seat,actor.id),ordered[index].seat as Player])));
 const learnedSpells=[...new Set(configs.flatMap(config=>config.learnedSpells))].sort();
 return createTowerBattle({...first,id:`shared:${first.id}`,mapId:first.mapId.replace(/^arena:2:/,`arena:${Math.max(2,entries.length)}:`),allies,enemies,controllers,learnedSpells,mode:'coop'});
}
export function sharedControlledActorIds(state:SimState,seat:number):string[]{return state.units.filter(unit=>unit.owner===0&&state.tower.controllers?.[unit.id]===seat).map(unit=>unit.id);}
export function validateSharedTowerPlan(state:SimState,seat:number,input:unknown):TeamPlan {
 const checked=validatePlan(state,0,input),supplied=new Set((input as TeamPlan).orders.map(order=>order.unitId));
 if([...supplied].some(id=>state.tower.controllers?.[id]!==seat))throw new Error('Order only your own fighters.');
 return {...checked,orders:checked.orders.filter(order=>supplied.has(order.unitId))};
}
/** Trusted server association supplies the seat; client-supplied battle snapshots are never accepted. */
export function finishSharedTowerBattle(run:TowerRun,input:SimState,seat:number):TowerRun {
 const current=validateTowerRun(run),battle=restoreSimState(input),room=current.currentRoom;
 if(current.phase!=='battle'||!room||battle.tower.id!==`shared:tower:${current.seed}:${room.id}`||battle.winner===null)throw new Error('Finish this shared room first.');
 const own=current.party.map(actor=>({actor,unit:battle.units.find(unit=>unit.id===sharedActorId(seat,actor.id)&&battle.tower.controllers?.[unit.id]===seat)}));
 if(own.some(entry=>!entry.unit))throw new Error('Your squad is missing from this battle.');
 const won=battle.winner===0,learnedSpells=[...new Set([...current.learnedSpells,...battle.units.filter(unit=>unit.owner===1&&unit.hp===0).map(unit=>teachingForEnemy(unit).id)])].sort();
 const party=own.map(({actor,unit})=>({...carryTowerSupplies(actor,unit!.spentScroll),hp:won?Math.min(actor.maxHp??8,unit!.hp+1):unit!.hp}));
 return validateTowerRun({...current,party,learnedSpells,phase:won?(current.floor===TOWER_FLOORS?'won':'reward'):'lost',...(won&&current.floor===TOWER_FLOORS?{history:[...current.history,room]}:{})});
}
