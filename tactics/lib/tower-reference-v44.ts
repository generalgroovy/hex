/** Internal quality fixture built entirely through normal Tower entry APIs. */
import {createTowerRun,towerRoomChoices,chooseTowerRoom,createTowerSession,type TowerSession} from './tower-v23.ts';
import {towerMotifFromMapId} from './tower-terrain-v44.ts';
import {createSharedTowerBattle} from './tower-shared-battle-v23.ts';

export const TOWER_REFERENCE_SEED='FIRST-STEPS-4';
export const TOWER_REFERENCE_DECISIONS=[
 'Choose a landing with a safe space behind it before aiming.',
 'Compare a direct hit with Fire and Water meeting to create shared cover.',
 'Use displacement to change who can benefit from that cover.',
] as const;
/** The authored steam suggestion has the required tools; arbitrary custom kits need not. */
export function towerReferenceSession():TowerSession{
 const run=createTowerRun(TOWER_REFERENCE_SEED,'steam'),room=towerRoomChoices(run).find(room=>room.kind==='combat'&&towerMotifFromMapId(room.mapId)==='crossing')??towerRoomChoices(run).find(room=>room.kind==='combat')!;
 return createTowerSession(chooseTowerRoom(run,room.id));
}
export function sharedTowerReference(count:2|4|6){
 const first=towerReferenceSession(),id=first.run.currentRoom!.id;
 return createSharedTowerBattle(Array.from({length:count},(_,seat)=>({seat,run:chooseTowerRoom(createTowerRun(TOWER_REFERENCE_SEED,seat%2?'stone':'steam',count,(seat%3) as 0|1|2),id)})));
}
