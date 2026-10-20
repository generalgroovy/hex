import type {TowerRouteParty} from '../../lib/tower-route-party-v43';
import type {TowerRoom} from '../../lib/tower-v23';

/** Destinations are grouped by authoritative room ID, never by a repeated name. */
export default function TowerPartyRouteV43({party,rooms,disabled=false,onJoin,onWatch}:{party:TowerRouteParty;rooms:TowerRoom[];disabled?:boolean;onJoin:(id:string)=>void;onWatch:(seat:number)=>void}){
 const groups=new Map<string,typeof party.friends>();
 for(const friend of party.friends)if(friend.roomId&&friend.phase==='route'){
  const group=groups.get(friend.roomId)??[];group.push(friend);groups.set(friend.roomId,group);
 }
 const choosing=party.friends.filter(friend=>party.choosingSeats.includes(friend.seat));
 const elsewhere=party.friends.filter(friend=>friend.phase!=='route');
 if(!groups.size&&!choosing.length&&!elsewhere.length)return null;
 return <section className="t43-friend-routes" aria-label="Friends’ destinations">
  <div className="t43-friend-groups">{[...groups].map(([id,friends])=>{
   const room=rooms.find(item=>item.id===id),lane=id.match(/^floor-\d+-(\d+)$/)?.[1];
   const path=room?.floor===9?'Final room':lane===undefined?'':`Path ${String.fromCharCode(65+Number(lane))}`;
   const withYou=friends.some(friend=>friend.withYou),join=friends.some(friend=>friend.action?.kind==='join');
   const combat=(party.encounterCounts[id]??0)>0||friends[0].roomKind==='combat'||friends[0].roomKind==='elite';
   const names=friends.map(friend=>friend.name).join(', ');
   return <article key={id} data-together={withYou}>
    <div className="t43-friend-room"><strong>{path}{path?' · ':''}{room?.name??friends[0].roomName??'Selected room'}</strong><span className="t43-friend-names">{friends.map(friend=><span key={friend.seat} data-seat={friend.seat}>{friend.name}</span>)}</span></div>
    {withYou?<span className="t43-together">With you</span>:join?<button type="button" disabled={disabled} aria-label={`${combat?'Join':'Go with'} ${names}${path?` on ${path.toLowerCase()}`:''}`} onClick={()=>onJoin(id)}>{combat?'Join fight':'Go together'}<span aria-hidden="true">↗</span></button>:<small>{friends.some(friend=>friend.reason==='low-health')?'Requires 3 HP':friends.some(friend=>friend.reason==='floor-locked')?'Unavailable now':'Different path'}</small>}
   </article>;
  })}</div>
  {choosing.length>0&&<p className="t43-still-choosing"><span>Choosing:</span> {choosing.map(friend=>friend.name).join(', ')}</p>}
  {elsewhere.length>0&&<div className="t43-friend-elsewhere">{elsewhere.map(friend=><span key={friend.seat}><strong>{friend.name}</strong>{friend.action?.kind==='watch'?<button type="button" disabled={disabled} aria-label={`Watch ${friend.name}'s fight`} onClick={()=>onWatch(friend.seat)}>Watch fight</button>:<small>{{lobby:'In lobby',route:'Choosing',battle:'In battle',reward:'Choosing reward',barrier:'At the stairs',won:'Tower cleared',lost:'Defeated',retired:'Retired'}[friend.phase]}</small>}</span>)}</div>}
 </section>;
}
