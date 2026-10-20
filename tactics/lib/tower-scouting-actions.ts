/** One bounded, deterministic scouting action per living champion and floor. */
import {towerRoomChoices,validateTowerRun,type TowerRun,type TowerActor} from './tower-v23.ts';
import {canonicalScoutReport,scoutEncounterKey,scoutFactsForRoom,scoutHash,type ScoutReport,type FloorScouting} from './tower-scouting-state.ts';
export type {ScoutReport,FloorScouting} from './tower-scouting-state.ts';
const roomsFor=(run:TowerRun)=>towerRoomChoices({...run,phase:'route'});
export function towerScoutEncounterKey(run:TowerRun,roomId:string):string {const room=roomsFor(run).find(room=>room.id===roomId);if(!room||!room.enemies.length)throw new Error('Choose a battle room to scout.');return scoutEncounterKey(run,room);}
/** Only verified reports for this exact floor and encounter variant cross player boundaries. */
export function scoutReportsForRun(run:TowerRun,reports:readonly ScoutReport[]):ScoutReport[]{
 const facts=roomsFor(run).flatMap(room=>scoutFactsForRoom(run,room)),seen=new Set<string>(),result:ScoutReport[]=[];
 for(const report of reports){const canonical=canonicalScoutReport(report,facts);if(canonical&&!seen.has(canonical.id)){seen.add(canonical.id);result.push(canonical);}}
 return result;
}
export function towerScoutReports(run:TowerRun,roomId:string,sharedReports:readonly ScoutReport[]=[]):ScoutReport[]{return scoutReportsForRun(run,[...(run.scouting?.floor===run.floor?run.scouting.reports:[]),...sharedReports]).filter(report=>report.roomId===roomId);}
export function towerScoutsAvailable(run:TowerRun):TowerActor[]{if(run.phase!=='route')return [];const used=run.scouting?.floor===run.floor?run.scouting.usedActorIds:[];return run.party.filter(actor=>!actor.creatureId&&actor.hp>0&&!used?.includes(actor.id));}
export function towerScoutOptions(run:TowerRun,roomId:string,sharedReports:readonly ScoutReport[]=[]):{remaining:number;canScout:boolean}{
 const room=roomsFor(run).find(room=>room.id===roomId),known=new Set(towerScoutReports(run,roomId,sharedReports).map(report=>report.id)),remaining=room?scoutFactsForRoom(run,room).filter(report=>!known.has(report.id)).length:0;
 return {remaining,canScout:remaining>0&&towerScoutsAvailable(run).length>0};
}
/** Useful for a view projection; it never spends another champion's allowance. */
export function mergeTowerScouting(run:TowerRun,sharedReports:readonly ScoutReport[]):TowerRun {
 const current=validateTowerRun(run),reports=scoutReportsForRun(current,[...(current.scouting?.reports??[]),...sharedReports]);
 if(!reports.length&&!current.scouting)return current;
 return validateTowerRun({...current,scouting:{floor:current.floor,usedActorIds:current.scouting?.usedActorIds??[],reports}});
}
export function scoutTowerRoom(run:TowerRun,actorId:string,roomId:string,options:{sharedReports?:readonly ScoutReport[]}={}):TowerRun {
 const current=validateTowerRun(run);
 if(current.phase!=='route')throw new Error('Scout before entering a room.');
 const actor=current.party.find(actor=>actor.id===actorId);if(!actor||actor.creatureId||actor.hp<=0)throw new Error('Choose a living champion to scout.');
 if(current.scouting?.usedActorIds.includes(actor.id))throw new Error('This champion has already scouted this floor.');
 const room=roomsFor(current).find(room=>room.id===roomId);if(!room||!room.enemies.length)throw new Error('Choose a battle room to scout.');
 const known=new Set(towerScoutReports(current,roomId,options.sharedReports).map(report=>report.id));
 const choices=scoutFactsForRoom(current,room).filter(report=>!known.has(report.id)).sort((a,b)=>scoutHash(`${current.seed}:${current.floor}:${actor.id}:${a.id}`)-scoutHash(`${current.seed}:${current.floor}:${actor.id}:${b.id}`)||a.id.localeCompare(b.id));
 if(current.encounterModel==='motifs44'){
  // Randomness selects an actionable aspect first. Familiar health totals
  // remain scoutable, but do not crowd out a technique or an unseen field.
  const aspects=[choices.filter(report=>report.kind==='spell'),choices.filter(report=>report.kind==='environment'),choices.filter(report=>report.kind==='identity'||report.kind==='affinity')].filter(group=>group.length);
  if(aspects.length){
   const aspect=aspects[scoutHash(`${current.seed}:${current.floor}:${actor.id}:${room.id}:aspect`)%aspects.length],preferred=new Set(aspect.map(report=>report.id));
   choices.sort((a,b)=>Number(preferred.has(b.id))-Number(preferred.has(a.id)));
  }
 }
 const report=choices[0];if(!report)throw new Error('The remaining details in this room stay hidden until you enter.');
 const scouting:FloorScouting={floor:current.floor,usedActorIds:[...(current.scouting?.usedActorIds??[]),actor.id],reports:[...(current.scouting?.reports??[]),report]};
 return validateTowerRun({...current,scouting});
}
