"use client";
import {useEffect,useRef,useState} from 'react';
import {towerRouteGraph} from '../../lib/tower-route-map';
import {towerFloorRooms,towerRoomChoices,type TowerRun,type TowerRoom} from '../../lib/tower-v23';
import {towerRoomIntel} from '../../lib/tower-scouting';
import type {ScoutReport} from '../../lib/tower-scouting-actions';
import {RoomMark} from './TowerGameV23';
import TowerRoomPreview from './TowerRoomPreviewV43';
import {BattleInsight} from './BattleInsightV24';
import './tower-route-map.css';

/** The entire graph fits its container. Room cards provide equivalent large controls. */
export function routeMapLayout(lanes:number){
 const width=800,height=300,step=(width-56)/lanes,start=28+step/2;
 return {width,height,minWidth:0,position:(floor:number,lane:number)=>({x:floor===9?width/2:start+lane*step,y:18+(9-floor)*33})};
}
const roomPath=(id:string)=>String.fromCharCode(65+Number(id.match(/-(\d+)$/)?.[1]??0));
const ROOM_LEGEND=[
 {kind:'combat',label:'Battle',detail:'Defeat every enemy. Each defeated enemy type teaches its spell; after victory, choose one reward and recover 1 HP per ally.'},
 {kind:'elite',label:'Elite',detail:'A stronger fight. Training rewards, when offered, give up to 2 affinity. Inspect or scout the room before committing.'},
 {kind:'camp',label:'Rest',detail:'No fight or entry cost. Choose one available benefit; recovery restores up to 4 HP to each fighter.'},
 {kind:'recruit',label:'Recruit',detail:'Choose a champion or creature. Keep up to three fighters; at capacity, replace a recruit or creature. Starting champions stay.'},
 {kind:'event',label:'Event',detail:'The first fighter pays 2 HP and must have at least 3 HP. Choose one offered benefit; the exact choices stay hidden until entry.'},
] as const;
export function previewRoomId(rooms:readonly Pick<TowerRoom,'id'>[],preview:string|undefined,committed?:string|null):string|undefined{
 return rooms.some(room=>room.id===preview)?preview:rooms.some(room=>room.id===committed)?committed!:rooms[0]?.id;
}
export function committedPreviewId(rooms:readonly Pick<TowerRoom,'id'>[],preview:string|undefined,previous?:string|null,committed?:string|null):string|undefined{
 return committed&&committed!==previous&&rooms.some(room=>room.id===committed)?committed:preview;
}
export function TowerRouteMap({run,selected,committed,onSelect,roomPlayers={},disabled=false}:{run:TowerRun;selected?:string;committed?:string|null;onSelect?:(id:string)=>void;roomPlayers?:Record<string,string[]>;disabled?:boolean}){
 const graph=towerRouteGraph(run.seed,run.routePlayers),lanes=graph.filter(node=>node.floor===1).length,{width,height,position}=routeMapLayout(lanes);
 const rooms=Array.from({length:9},(_,index)=>towerFloorRooms({...run,floor:index+1,phase:'route'})).flat(),available=new Set(towerRoomChoices({...run,phase:'route'}).map(room=>room.id)),visited=new Set(run.history.map(room=>room.id));
 return <section className="trm-map" aria-label="Tower route map">
  <header><strong>Route</strong><span>Floor {run.floor} / 9</span></header>
  <div className="trm-chart" role="group" aria-label={`${lanes} tower paths`}>
   <div className="trm-active-floor" style={{top:`${position(run.floor,0).y/height*100}%`}} aria-hidden="true"/>
   {Array.from({length:9},(_,index)=>index+1).map(floor=><span className="trm-floor" data-active={floor===run.floor} key={floor} style={{top:`${position(floor,0).y/height*100}%`}} aria-hidden="true">{floor}</span>)}
   <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" aria-hidden="true" className="trm-paths">
    {graph.flatMap(node=>node.next.map(id=>{
     const next=graph.find(entry=>entry.id===id)!,a=position(node.floor,node.lane),b=position(next.floor,next.lane),taken=visited.has(node.id)&&(visited.has(next.id)||run.currentRoom?.id===next.id);
     return <path key={`${node.id}:${id}`} d={`M${a.x} ${a.y} Q${a.x} ${(a.y+b.y)/2} ${b.x} ${b.y}`} className={taken?'is-travelled':selected===node.id?'is-option':node.floor===run.floor-1&&visited.has(node.id)?'is-next':''}/>;
    }))}
   </svg>
   {graph.map(node=>{
    const room=rooms.find(room=>room.id===node.id)!,point=position(node.floor,node.lane),canChoose=node.floor===run.floor&&available.has(node.id),done=visited.has(node.id),people=roomPlayers[node.id]??[],intel=towerRoomIntel(room),near=node.floor<=run.floor+1,path=node.floor===9?'Final room':`Path ${roomPath(node.id)}`,chosen=committed===node.id;
    const hint=near?intel.clues.map(clue=>`${clue.label}: ${clue.detail}`).join(' · '):'';
    return <button type="button" key={node.id} className="trm-node" style={{left:`${point.x/width*100}%`,top:`${point.y/height*100}%`}} data-current={canChoose} data-visited={done} data-chosen={selected===node.id} data-committed={chosen} data-future={node.floor>run.floor} data-company={people.length>0} aria-label={`Floor ${node.floor}, ${path}, ${room.name}${chosen?', chosen destination':''}${canChoose?', preview available':done?', visited':', not reachable now'}${people.length?`, ${people.join(', ')}`:''}`} aria-pressed={canChoose?selected===node.id:undefined} aria-disabled={!canChoose||disabled} tabIndex={canChoose?0:-1} onClick={()=>canChoose&&!disabled&&onSelect?.(node.id)} title={`${path} · ${room.name}${chosen?' · Chosen':''}${hint?` · ${hint}`:''}${people.length?` · ${people.join(', ')}`:''}`}>
     <span aria-hidden="true">{done?'✓':canChoose&&node.floor!==9?<strong className="trm-path-letter">{roomPath(node.id)}</strong>:<RoomMark kind={room.floor===9?'boss':room.kind}/>}</span>
     {people.length>0&&<b aria-hidden="true">{people.length}</b>}
    </button>;
   })}
  </div>
  <footer aria-label="Room types">{ROOM_LEGEND.map(entry=><BattleInsight key={entry.kind} title={`${entry.label} room`} label={<><RoomMark kind={entry.kind}/>{entry.label}</>}><p>{entry.detail}</p></BattleInsight>)}</footer>
 </section>;
}
export default function TowerRouteChoices({run,onChoose,onScout,scoutReports=[],roomPlayers={},lockedChoice,cooperative=false,disabled=false,roomActionLabel,encounterCount}:{run:TowerRun;onChoose:(id:string)=>void;onScout?:(actorId:string,roomId:string)=>void;scoutReports?:readonly ScoutReport[];roomPlayers?:Record<string,string[]>;lockedChoice?:string|null;cooperative?:boolean;disabled?:boolean;roomActionLabel?:(id:string)=>string;encounterCount?:(id:string)=>number|undefined}){
 const rooms=towerRoomChoices(run),[preview,setPreview]=useState<string|undefined>(lockedChoice??rooms[0]?.id),previousCommit=useRef(lockedChoice),selected=previewRoomId(rooms,preview,lockedChoice),room=rooms.find(room=>room.id===selected);
 useEffect(()=>{const previous=previousCommit.current;previousCommit.current=lockedChoice;if(previous!==lockedChoice)setPreview(current=>committedPreviewId(rooms,current,previous,lockedChoice));},[lockedChoice,rooms]);
 return <div className="trm-route">
  <TowerRouteMap run={run} selected={selected} committed={lockedChoice} onSelect={setPreview} roomPlayers={roomPlayers} disabled={disabled}/>
  <div className="trm-decisions" data-room-count={rooms.length}>
   <nav className="trm-doors" aria-label="Available rooms">{rooms.map(choice=>{
    const people=roomPlayers[choice.id]??[],chosen=lockedChoice===choice.id,total=encounterCount?.(choice.id),enemies=total??choice.enemies.length;
    return <button type="button" key={choice.id} aria-pressed={selected===choice.id} data-committed={chosen} disabled={disabled} onClick={()=>setPreview(choice.id)} aria-label={`Preview ${choice.floor===9?'final room':`Path ${roomPath(choice.id)}`}: ${choice.name}${chosen?'. Chosen destination':''}${people.length?`. ${people.join(', ')}`:''}`}>
     <span className="trm-door-path" aria-hidden="true">{choice.floor===9?<RoomMark kind="boss"/>:roomPath(choice.id)}</span>
     <span className="trm-door-copy"><strong>{choice.name}</strong><small><RoomMark kind={choice.floor===9?'boss':choice.kind}/>{choice.enemies.length?`${enemies} ${enemies===1?'enemy':'enemies'}${cooperative&&total===undefined?' + allies’ foes':''}`:choice.kind==='camp'?'Rest':choice.kind==='recruit'?'Recruit':'Event'}</small></span>
     {chosen&&<b className="trm-committed">✓ Chosen</b>}
     {people.length>0&&<span className="trm-door-company" title={people.join(' · ')}>{people.map((name,index)=><span key={`${index}:${name}`}>{name}</span>)}</span>}
    </button>;
   })}</nav>
   <section className="trm-room" aria-label="Selected room">{room&&<TowerRoomPreview run={run} room={room} onChoose={onChoose} onScout={onScout} scoutReports={scoutReports} cooperative={cooperative} disabled={disabled} chosen={lockedChoice===room.id} scoutingLocked={!!lockedChoice} actionLabel={roomActionLabel?.(room.id)} encounterCount={encounterCount?.(room.id)} partyNames={roomPlayers[room.id]}/>}</section>
  </div>
 </div>;
}
