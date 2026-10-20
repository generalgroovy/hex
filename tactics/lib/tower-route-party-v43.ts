/** Public cooperative destinations. Selection is replaceable until the doors
 * launch; a running battle can only be watched, never joined late. */
import type {TowerRoomSnapshot,TowerPlayerSummary} from './tower-rooms-v23.ts';
import {towerFloorRooms,towerRoomChoices,towerTuitionActor,type TowerRoom} from './tower-v23.ts';

export type TowerRoutePerson={seat:number;name:string;you:boolean};
export type TowerFriendAction={kind:'join';roomId:string}|{kind:'preview';roomId:string}|{kind:'watch';seat:number};
export type TowerFriendDestination={
 seat:number;name:string;phase:TowerPlayerSummary['phase'];floor:number;
 roomId:string|null;roomName:string|null;roomKind:TowerRoom['kind']|null;withYou:boolean;
 action:TowerFriendAction|null;reason?:'different-path'|'already-together'|'floor-locked'|'low-health';
};
export type TowerRouteParty={
 ownChoiceId:string|null;
 roomPlayers:Record<string,TowerRoutePerson[]>;
 choosingSeats:number[];
 encounterCounts:Record<string,number>;
 friends:TowerFriendDestination[];
};

export function towerRouteParty(snapshot:TowerRoomSnapshot):TowerRouteParty {
 const run=snapshot.session?.run,own=snapshot.players.find(player=>player?.seat===snapshot.yourSeat),gathering=snapshot.gathering;
 const rooms=run?towerFloorRooms({...run,floor:snapshot.sharedFloor,phase:'route'}):[],byId=new Map(rooms.map(room=>[room.id,room]));
 const reachable=new Set(run?towerRoomChoices({...run,phase:'route'}).map(room=>room.id):[]);
 const canJoin=Boolean(snapshot.status==='active'&&own?.alive&&own.phase==='route'&&run?.phase==='route'&&run.floor===snapshot.sharedFloor&&gathering);
 // canEnter becomes false after choosing, but choose may replace that choice.
 // Requiring canEnter here would reintroduce an unnecessary withdrawal step.
 const ownChoiceId=canJoin&&gathering?.choiceId&&reachable.has(gathering.choiceId)?gathering.choiceId:null,choices=new Map((gathering?.choices??[]).filter(choice=>byId.has(choice.choiceId)).map(choice=>[choice.seat,choice.choiceId]));
 const players=snapshot.players.filter((player):player is TowerPlayerSummary=>!!player).sort((a,b)=>a.seat-b.seat);
 const roomPlayers:TowerRouteParty['roomPlayers']={},friends:TowerFriendDestination[]=[],encounterCounts:Record<string,number>={};
 for(const id of reachable){const room=byId.get(id);if(room)encounterCounts[id]=room.enemies.length;}
 for(const player of players){
  const selected=player.alive&&player.phase==='route'&&player.floor===snapshot.sharedFloor?choices.get(player.seat):undefined;
  const shared=Boolean(snapshot.sharedBattle?.seats.includes(player.seat));
  const watched=snapshot.watch?.seat===player.seat?snapshot.watch.session.run:undefined;
  // Room names repeat. Only authoritative choice IDs, our explicit shared
  // group, or the watched seat's actual session can locate another squad.
  const knownRoom=player.seat===snapshot.yourSeat?run?.currentRoom:shared?run?.currentRoom:watched?.currentRoom;
  const roomId=selected??knownRoom?.id??null,room=selected?byId.get(selected):knownRoom;
  if(roomId)(roomPlayers[roomId]??=[]).push({seat:player.seat,name:player.name,you:player.seat===snapshot.yourSeat});
  if(player.seat===snapshot.yourSeat)continue;
  if(run&&selected&&encounterCounts[selected]!==undefined){
   // Each squad brings its own immutable starting-band encounter. Multiplying
   // our count would be wrong for mixed champion/creature starting pairs.
   const friendRoom=towerFloorRooms({...run,floor:snapshot.sharedFloor,phase:'route',starterId:player.start.starterId,starts:[player.start]}).find(room=>room.id===selected);
   encounterCounts[selected]+=friendRoom?.enemies.length??0;
  }
  const withYou=Boolean(selected&&ownChoiceId===selected||shared);
  const entry:TowerFriendDestination={seat:player.seat,name:player.name,phase:player.phase,floor:player.floor,roomId,roomName:room?.name??player.currentRoomName,roomKind:room?.kind??null,withYou,action:null};
  if(selected){
   if(withYou){entry.action={kind:'preview',roomId:selected};entry.reason='already-together';}
   else if(canJoin&&reachable.has(selected)){
    if(room?.kind==='event'&&towerTuitionActor(run!).hp<3){entry.action={kind:'preview',roomId:selected};entry.reason='low-health';}
    else entry.action={kind:'join',roomId:selected};
   }
   else {entry.action={kind:'preview',roomId:selected};entry.reason=canJoin?'different-path':'floor-locked';}
  }else if(player.phase==='battle')entry.action={kind:'watch',seat:player.seat};
  friends.push(entry);
 }
 const choosingSeats=(gathering?.waitingFor??[]).filter(seat=>players.some(player=>player.seat===seat&&player.alive&&player.phase==='route'&&player.floor===snapshot.sharedFloor));
 return {ownChoiceId,roomPlayers,choosingSeats,encounterCounts,friends};
}
