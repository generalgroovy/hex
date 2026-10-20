"use client";

import {useEffect, useId, useRef, useState, type CSSProperties, type KeyboardEvent} from 'react';
import {CHAMPIONS, type Point} from '../../lib/game';
import {movementPath, type SimEvent, type SimState, type TeamPlan} from '../../lib/sim';
import './battlefield.css';

type Props = {
  state: SimState;
  plan: TeamPlan;
  player: 0 | 1;
  selected: string | null;
  kind: 'move' | 'cast';
  onCell: (q: number, r: number) => void;
  interactive: boolean;
  previousState?: SimState;
  resolving?: boolean;
  onReplayChange?: (active:boolean) => void;
  legalTargets?: Point[];
  showOrders?: boolean;
};

const key = (p: Point) => `${p.q},${p.r}`;
const same = (a: Point, b: Point) => a.q === b.q && a.r === b.r;
const alive = (unit: SimState['units'][number]) => unit.hp > 0 && unit.respawn === undefined;
const champion = (id: string) => CHAMPIONS.find(entry => entry.id === id)!;
const shortName: Record<string, string> = {oh_tipi:'Oh Tipi', wa_bidi:'Wa Bidi', grace_reava:'Grace', treevor_mason:'Treevor', haara:'Haara', s_wayne:'S. Wayne'};
const teamColors = ['#64d5d0', '#ffb17d'];
const palette: Record<string, {top:string; mark:string; name:string}> = {
  plain:{top:'#9ba789',mark:'#667556',name:'Meadow'},
  water:{top:'#75b9c1',mark:'#28687b',name:'Water'},
  fire:{top:'#ce9c72',mark:'#9c482e',name:'Fire'},
  air:{top:'#bed3bd',mark:'#4d897d',name:'Air'},
  earth:{top:'#bbad82',mark:'#736440',name:'Earth'},
  light:{top:'#dbce91',mark:'#a1833d',name:'Light'},
  dark:{top:'#b39bbb',mark:'#67507d',name:'Dark'},
  steam:{top:'#adc5bd',mark:'#4f858b',name:'Steam'},
  magma:{top:'#c08464',mark:'#a13e30',name:'Magma'},
  quagmire:{top:'#8da48b',mark:'#465c4f',name:'Quagmire'},
  penumbra:{top:'#b7a8c9',mark:'#74538b',name:'Penumbra'},
};
const elementColors: Record<string,string> = {water:'#79dfef',fire:'#ffad65',air:'#d4f4da',earth:'#cfe08d',light:'#fff0a8',dark:'#d6b4f8'};
const ground = (p: Point) => ({x:380 + Math.sqrt(3) * 50 * (p.q + p.r / 2),y:312 + 43 * p.r});
const top = (p: Point, state: SimState) => {const at=ground(p);return {...at,y:at.y - (state.cells.find(cell=>same(cell,p))?.height||0)*24};};
const hex = (x:number,y:number,inset=0) => Array.from({length:6},(_,i)=>{
  const angle=(i*60-30)*Math.PI/180;
  return {x:x+(50-inset)*Math.cos(angle), y:y+(29-inset*.58)*Math.sin(angle)};
});
const points = (list: Point[] | {x:number;y:number}[]) => list.map(p=>'x' in p?`${p.x},${p.y}`:`${p.q},${p.r}`).join(' ');
const clamp = (value:number,min:number,max:number) => Math.max(min,Math.min(max,value));

/** Original code-drawn costumes and silhouettes, grounded in the six canonical portraits. */
function ChampionFigure({id}:{id:string}) {
  const ink='#2a3438';
  const common={stroke:ink,strokeWidth:1.65,strokeLinejoin:'round' as const,strokeLinecap:'round' as const};
  if(id==='oh_tipi') return <g {...common}>
    <path fill="#27394d" d="M-12-17 -13-3 -5 0 0-16 5-1 14-3 11-19Z"/><path fill="#172b3a" d="M-14-5 -16 0 -4 0 -5-5M5-5 4 0 17 0 14-5"/>
    <path fill="#23435a" d="M-13-42Q0-49 14-42L20-17 11-11 0-16-12-11-20-18Z"/><path fill="#447291" d="m-13-41-12 15 7 5 12-15M14-41l12 15-7 5-12-15"/>
    <path fill="#2fa7cb" d="M-26-28q-6 5 0 9l6-3-1-6M26-28q6 5 0 9l-6-3 1-6"/>
    <path fill="#e3bd69" d="m-13-40 12 9 14-9-5-3-9 8-8-8ZM-2-31h4v17h-4Z"/><path stroke="#e0b768" d="m-17-17 13-2m9 0 13 2"/>
    <path fill="#2186b5" d="M-17-58-32-68-27-47-15-43M17-58 32-68 27-47 15-43"/><path fill="none" stroke="#72d5da" d="m-26-62 8 13m44-13-8 13"/>
    <path fill="#43b6d5" d="M-18-61Q-16-75 0-73 19-74 20-57L16-41Q0-30-16-42Z"/>
    <path fill="#1989b6" d="m-19-60-5-15 11 4 0-13 11 10 8-14 4 16 14-8-5 20-11-6-9 5-8-5Z"/><path stroke="#74d8e9" d="m-17-71 9 3m6-7 3 7m9-7-1 7"/>
    <path fill="#e4c47b" d="m-13-54 9-1-1 5-7-1m16-4 9 1-1 3-7 1"/><path stroke="#203647" strokeWidth="2.8" d="m-8-53 0 2m16-2 0 2"/><path fill="none" d="m-4-43q5 4 9-1"/><path stroke="#248caf" d="m-14-44 3 1m25-1-3 1"/>
  </g>;
  if(id==='wa_bidi') return <g {...common}>
    <path fill="#514a31" d="m-10-16-3 12 8 2 5-13 4 13 9-2-3-12"/><path fill="#514035" d="M-14-6-18 0-4 0-4-4M5-5 4 0 18 0 13-6"/>
    <path fill="#6f773d" d="M-12-37Q0-43 12-37L18-15 1-10-17-15Z"/><path fill="#ccb98b" d="m-7-38 7 14 7-14"/>
    <path fill="#8c7043" d="m-14-37 5-2 16 25-6 2ZM-16-17l32-2 1 5-33 2Z"/><rect x="-3" y="-19" width="7" height="7" rx="1" fill="#dab76b"/>
    <path fill="#7d7348" d="m-14-36-9 11 6 6 10-13M14-36l9 11-5 6-10-13"/><path fill="#a9b85f" d="M-23-26q-7 3-2 9l7-3M23-26q7 3 2 9l-7-3"/>
    <path fill="#a5b95e" d="m-15-56-23-8 10 18 13 4m30-14 23-8-10 18-13 4"/><path fill="#b8bd73" stroke="none" d="m-29-57 12 7-8 2m54-9-12 7 8 2"/>
    <path fill="#adbe68" d="M-18-57Q-16-72 2-70 21-69 19-52L14-36Q0-29-14-38Z"/>
    <path fill="#32372e" d="m-20-55-2-13 7 0 1-9 8 4 7-9 6 9 13-5-4 9 9 0-7 15-8-8-9 6-7-5-9 7Z"/>
    <path fill="#f2d389" d="m-13-51 9-2-1 5-7 0m16-1 9-3-1 5-7 0"/><path strokeWidth="2.7" d="m-8-51 0 2m16-2 0 2"/>
    <path fill="#eff0ce" d="M-10-42Q0-34 11-43L8-37Q0-32-8-37Z"/><path fill="#fff5d2" d="m-8-41 3 7 2-5m8-1 3 5 2-8"/>
    <path className="iso-hand-spark" stroke="#b55836" fill="#ffcc78" d="M28-26q-7-3-2-11 0 5 4 2 4-6 3-10 10 14 2 19Z"/>
  </g>;
  if(id==='grace_reava') return <g {...common}>
    <g stroke="#8eb7a7" fill="#d0ece0" fillOpacity=".8"><path d="M-9-39Q-49-77-38-48-32-32-9-29Z"/><path d="M9-39Q49-77 38-48 32-32 9-29Z"/><path d="M-8-31Q-36-31-29-17-19-13-4-26Z"/><path d="M8-31Q36-31 29-17 19-13 4-26Z"/><path fill="none" stroke="#f4e8bc" d="m-10-36-26-22m46 22 26-22m-44 29-18 6m34-6 18 6"/></g>
    <path fill="#5f8068" d="m-9-17-1 13 6 1 4-13 6 13 5-2-3-13"/><path fill="#6a513d" d="M-11-5-15-2-5 0-3-4M5-5 5-1 15-3 11-6"/>
    <path fill="#315d4e" d="M-11-40Q0-43 11-39L18-16 4-12 0-17-7-11-18-18Z"/><path fill="#e6e0bc" d="m-11-38-9 12 5 6 10-15M12-38l9 12-6 6-10-15"/>
    <path fill="#e8b894" d="m-21-26-5 4 3 5 7-3m38-6 5 4-3 5-7-3"/><path fill="#a58a49" d="m-9-40 9 12 11-11-2-3-9 8-6-8ZM-13-19l26-3 1 4-26 3Z"/>
    <path fill="#eac3a6" d="m-15-57-12-5 4 12 10 2m28-9 12-5-4 12-10 2"/>
    <path fill="#f0c9ab" d="M-17-57Q-15-72 2-70 19-70 19-53L13-38Q1-33-12-40Z"/>
    <path fill="#307d6e" d="m-18-48-6-10 4-13 9-4 3-7 7 6 11-2 11 12-2 17-7-10-9-8-7 10-8-4-4 15Z"/>
    <path fill="none" stroke="#5cb5a1" d="m-14-67 7-2m9-5 9 6m6 6 0 8"/>
    <path stroke="#344b3e" strokeWidth="3" d="m-9-51 1 1m16-1 1-1"/><circle cx="-8" cy="-51" r=".8" fill="#e7e7a6" stroke="none"/><circle cx="9" cy="-51" r=".8" fill="#e7e7a6" stroke="none"/><path fill="none" d="m-3-43q4 3 7-1"/>
    <path fill="none" stroke="#bfe5ce" strokeWidth="2" d="M-26-8q14 6 35 2 11-2 16-9"/>
  </g>;
  if(id==='treevor_mason') return <g {...common}>
    <path fill="#7b5e42" d="M-15-18-19-5-24 0-9 1-5-15 7-16 10 1 25 0 18-6 16-20Z"/><path stroke="#b2925d" d="m-16-10 2 8m29-8 1 7"/>
    <path fill="#9b7b4e" d="M-18-42Q1-51 19-42L23-13Q0-5-24-14Z"/><path fill="#7c6944" d="M-19-43-29-32-28-16-18-14-11-35M18-43l12 11-2 17-10 1-8-21"/>
    <path fill="#6e8154" d="M-23-42-28-49-19-54-15-48-8-53 9-53 14-49 20-55 28-48 25-40 16-37Z"/><path fill="#4f6847" d="m-22-44-9 3 2 9 13-5m39-6 10 3-2 9-13-5"/>
    <path fill="#a09d83" d="m-30-28 14 3-1 10-14-2Zm47 3 13-3 0 11-14 2Z"/><path stroke="#d0c6a3" d="m-27-25 8 2m11 1 2 9m13-10 10-2"/>
    <path fill="#c09a62" d="m-19-63-12-11 5-13 6 13 10 5 4-9 7 14 10-10 2-14 6 9-1 14 6 6-5 25-15 9-20-8Z"/>
    <path fill="#b08b58" d="M-20-62Q0-69 22-60L18-41 9-32-1-29-14-37Z"/>
    <path fill="#7c6c44" d="m-16-55 12 0-2 7-8-1m18-6 12 0-2 6-8 1"/><path stroke="#b9c989" strokeWidth="3" d="m-11-52 3 0m16 0 3 0"/>
    <path stroke="#735a3d" fill="none" d="m0-58-3 13 6 1m-12 6q9 5 17-1m-21-17-2 10m29-12-2 10m-20 8 2 7m12-7-2 7"/>
    <path fill="#667e4e" d="m-24-64-8-7 11-3 6 5-1 6m31-5 4-8 10 4-5 9-9 2m-13-2-3-10 8 3 1 8"/>
    <path fill="#6c5039" d="m-20-39 5-3 27 29-7 3Zm38 0-5-3-28 29 7 3Z"/><path fill="#d5b674" d="m-5-28 10-1 3 8-9 4-6-6Z"/><path fill="#7a603c" d="M-20-15h41v5h-41Z"/><circle cx="1" cy="-13" r="4" fill="#d7b56a"/>
  </g>;
  if(id==='haara') return <g {...common}>
    <path fill="#315d42" d="M-18-60Q-22-77 0-76 23-74 20-55L27-22 10-15-11-15-28-23Z"/>
    <path fill="#4d6041" d="m-8-17-3 15 6 1 5-13 5 13 6-1-3-15"/><path fill="#806a42" d="m-12-5-3 5 11 0 0-5m9 0 0 5 11 0-4-5"/>
    <path fill="#e8d7ad" d="M-11-39Q0-45 12-39L17-16 0-10-17-16Z"/><path fill="#7b9659" d="m-14-26-7 13 8 0 4 5 9-7 8 7 5-5 8 0-7-13Z"/>
    <path fill="#4b784c" d="m-12-41-13 8 9 8 8-13M12-41l13 8-9 8-8-13"/><path fill="#e5d2ad" d="m-21-32-4 11 6 2 6-13m34 0 4 11-6 2-6-13"/><path fill="#edc4a2" d="m-25-23-3 5 6 3 4-6m43-2 3 5-6 3-4-6"/>
    <path fill="#a88b50" d="m-9-41 9 12 9-12-2-2-7 8-7-8ZM-14-20l28-2 0 4-28 2Z"/>
    <path fill="#efc8a9" d="m-15-57-14-6 6 15 9 0m29-9 14-6-6 15-9 0"/><path fill="#f1ceb2" d="M-16-61Q0-74 17-60L14-42Q0-33-13-43Z"/>
    <path fill="#3f7750" d="M-18-57-19-68-8-75 4-77 18-70 20-55 14-48 9-65 0-69-9-60-15-48Z"/>
    <path fill="#73a66c" d="m-14-65-5-8 10-1 3 6m12-2 5-8 7 7-1 6m-19 0-2-9 9 3-1 7"/>
    <g fill="#f1d5c4" stroke="#b79a8d" strokeWidth=".7"><circle cx="-17" cy="-69" r="3"/><circle cx="-20" cy="-66" r="3"/><circle cx="-16" cy="-64" r="3"/><circle cx="-13" cy="-67" r="3"/><circle cx="17" cy="-67" r="3"/><circle cx="20" cy="-64" r="3"/><circle cx="16" cy="-61" r="3"/><circle cx="14" cy="-64" r="3"/></g><circle fill="#dcb268" stroke="none" cx="-16" cy="-67" r="1.6"/><circle fill="#dcb268" stroke="none" cx="17" cy="-64" r="1.6"/>
    <path strokeWidth="2" d="m-12-55 7 2m10 0 7-2"/><path stroke="#53734d" strokeWidth="3" d="m-8-51 0 1m16-1 0 1"/><path fill="none" d="m-4-43 8 0"/>
    <path className="iso-hand-spark" fill="#fff0ac" stroke="#c6a657" d="m-26-29 2 4 5 2-5 2-2 5-2-5-5-2 5-2Z"/>
  </g>;
  return <g {...common}>
    <path fill="#3e3a3c" d="m-10-17-3 13 8 2 5-14 5 14 8-2-3-13"/><path fill="#594237" d="m-14-5-3 5 13 0-1-5m10 0-1 5 13 0-3-5"/>
    <path fill="#684565" d="M-14-40Q0-46 14-40L19-13 4-10 0-18-4-10-19-13Z"/><path fill="#38383d" d="m-7-38 7 11 7-11-1 23H-6Z"/><path fill="#ede0bd" d="m-6-40 6 12 6-12Z"/>
    <path fill="#805476" d="m-14-39-10 13 6 5 11-13M14-39l10 13-6 5-11-13"/><path fill="#80543e" d="m-24-26-4 5 4 5 7-5m41-5 4 5-4 5-7-5"/>
    <path fill="none" stroke="#caac63" d="m-12-39 9 12-2 13m17-25-9 12 2 13M-15-16l8 1m14 0 8-1"/><path fill="#8c3f44" d="m-7-42 14 0-3 8-5-3-2 10-6-3 5-10Z"/><path fill="#87633e" d="m-15-28 2-4 28 14-2 5Z"/><circle cx="1" cy="-20" r="2" fill="#cdb06a"/>
    <path fill="#80533c" d="m-16-57-12-4 5 12 9 0m28-8 12-4-5 12-9 0"/><path fill="#956348" d="M-18-61Q-17-73 0-73 19-74 19-58L15-41Q1-32-14-41Z"/>
    <path fill="#332e2d" d="M-20-56Q-25-62-18-67-23-74-12-74-13-81-3-78 4-83 9-77 19-79 19-71 27-67 19-57L13-64 6-62-2-66-9-61-17-63Z"/>
    <path stroke="#645044" fill="none" d="m-15-71q4-4 7 1m5-5q5-2 7 3m4 0q5-3 7 2m-21 3 5 1"/>
    <path stroke="#332f30" strokeWidth="2.3" d="m-12-54 7-1m10 0 7 1"/><path fill="#deb980" stroke="none" d="m-12-51 8-1-1 4-6 0m15-4 8 1-1 3-6 0"/><path strokeWidth="2.5" d="m-8-51 0 2m16-2 0 2"/><path stroke="#4b3831" fill="none" d="m-4-42q4 2 8-1"/>
    <path className="iso-hand-spark" fill="#c9abe4" stroke="#795b92" d="M27-32q-8-3-5-10-8 4-3 12 5 5 8-2Z"/>
  </g>;
}

function TerrainMark({terrain}:{terrain:string}) {
  if(terrain==='water') return <path d="M-14-2q6-5 12 0t12 0M-10 4q6-5 12 0t12 0"/>;
  if(terrain==='fire'||terrain==='magma') return <><path d="M-11 7q-4-6 3-10l2 5 5-12 5 9 5-2q7 10-4 13Z"/>{terrain==='magma'&&<path d="m-24 4 5-3 5 7m29-9 8 3 3 6"/>}</>;
  if(terrain==='air') return <path d="M-17-1h24q9 0 7-6-3-5-6-1M-13 5H3q10 0 8 6M-6-7h7"/>;
  if(terrain==='earth') return <><path d="m-14 5 7-10 7 10 6-15 10 15Z"/><path d="m-2 5 8-3 10 3"/></>;
  if(terrain==='light') return <path d="M0-10 3-2 15 0 3 3 0 10-3 3-15 0-3-2Z"/>;
  if(terrain==='dark') return <path d="M6-10Q-9-7-4 4 0 10 11 6-4 17-11 3-17-10 6-10Z"/>;
  if(terrain==='steam') return <path d="M-18 7q-10-7 1-11 0-10 11-6 8-8 13 2 15-2 12 9-2 7-15 6ZM-7 9v5M4 10v4"/>;
  if(terrain==='quagmire') return <><ellipse cx="0" cy="4" rx="19" ry="6"/><path d="M-5 3-7-8m1 5-6-3m6 2 4-5M8 5l4-7"/></>;
  if(terrain==='penumbra') return <><path d="M-13 0 0-9 13 0 0 9Z"/><path d="m-5 0 5-4 5 4-5 4Z"/><path d="M-22 0h5M17 0h5"/></>;
  return null;
}

function Well({owner,occupied}:{owner?:number;occupied:boolean}) {
  return <g className="iso-well">
    <ellipse cy="5" rx="23" ry="12" fill="#3e514c" opacity=".34"/>
    <path d="M-23-2v7q23 15 46 0V-2" fill="#aa9b73" stroke="#736e53" strokeWidth="1.2"/>
    <ellipse cy="-2" rx="23" ry="12" fill="#ddd0a5" stroke="#f3e3b8" strokeWidth="1.5"/>
    <ellipse cy="-2" rx="15" ry="7.5" fill="#426f78" stroke="#817b59" strokeWidth="2"/>
    <ellipse cy="-3" rx="12" ry="5" fill={owner===undefined?'#7bd0c7':teamColors[owner]} opacity=".9"/>
    <path d="m-22-3 5 2m33 0 6-2M0 8V4M0-13v4" stroke="#9d926e" strokeWidth="2"/>
    {!occupied&&<><path className="iso-well-light" d="M-5-7 0-23 5-7 0-3Z" fill="#b9f0d3" stroke="#e7f6cc"/><ellipse cy="-2" rx="6" ry="2" fill="#d3f5cf" opacity=".6"/></>}
  </g>;
}

function eventPoint(event:SimEvent, state:SimState, oldState?:SimState) {
  if(event.kind==='guard') return state.units.find(unit=>unit.id===event.unitId);
  if(event.to) return event.to;
  if(event.q!==undefined&&event.r!==undefined) return {q:event.q,r:event.r};
  return state.units.find(unit=>unit.id===event.unitId)||oldState?.units.find(unit=>unit.id===event.unitId);
}

export default function IsometricBoard({state,plan,player,selected,kind,onCell,interactive,previousState,resolving=false,onReplayChange,legalTargets=[],showOrders=true}:Props) {
  const instance=useId().replace(/:/g,'');
  const [focused,setFocused]=useState('0,0');
  const [hovered,setHovered]=useState<string|null>(null);
  const [zoom,setZoom]=useState(false);
  const [camera,setCamera]=useState({x:380,y:295});
  const [replay,setReplay]=useState(0);
  const [replaying,setReplaying]=useState(false);
  const refs=useRef(new Map<string,SVGGElement>());
  const activeResolution=resolving||replaying;
  const canInteract=interactive&&!replaying;
  const legal=new Set(canInteract?legalTargets.map(key):[]);
  const ownUnits=state.units.filter(unit=>unit.owner===player);
  const events=previousState&&previousState.version!==state.version?state.lastResolution||[]:[];
  const livingUnits=state.units.filter(alive);
  const visibleUnits=state.units.filter(unit=>alive(unit)||events.some(event=>event.kind==='defeat'&&event.unitId===unit.id)).sort((a,b)=>ground(a).y-ground(b).y||ground(a).x-ground(b).x);
  const selectedUnit=livingUnits.find(unit=>unit.id===selected);
  const orders=showOrders&&!activeResolution?plan.orders.filter(order=>state.units.some(unit=>unit.id===order.unitId&&unit.owner===player&&alive(unit))):[];
  const view=zoom?`${camera.x-210} ${camera.y-170} 420 340`:'60 65 640 450';
  const activePoint=hovered?state.cells.find(cell=>key(cell)===hovered):undefined;
  const changed=events.length>0;
  const eventKey=`${state.version}-${replay}`;
  useEffect(()=>{
    if(!replaying)return;
    const timeout=setTimeout(()=>{setReplaying(false);onReplayChange?.(false)},2400);
    return ()=>clearTimeout(timeout);
  },[replaying,replay,state.version,onReplayChange]);

  function focusCell(cell:Point) {
    const id=key(cell);setFocused(id);refs.current.get(id)?.focus();
    if(zoom){const at=top(cell,state);setCamera({x:clamp(at.x,230,530),y:clamp(at.y-20,205,355)});}
  }
  function onKey(event:KeyboardEvent<SVGGElement>,cell:Point) {
    if(event.key==='Enter'||event.key===' '){event.preventDefault();if(canInteract)onCell(cell.q,cell.r);return;}
    if(event.key==='Home'){event.preventDefault();focusCell({q:0,r:0});return;}
    const vectors:Record<string,Point>={ArrowRight:{q:1,r:0},ArrowLeft:{q:-1,r:0},ArrowUp:{q:0,r:-1},ArrowDown:{q:0,r:1},q:{q:-1,r:1},e:{q:1,r:-1}};
    const delta=vectors[event.key];if(!delta)return;
    event.preventDefault();const next=state.cells.find(point=>point.q===cell.q+delta.q&&point.r===cell.r+delta.r);if(next)focusCell(next);
  }
  function focusView() {
    const at=top(selectedUnit||{q:0,r:0},state);
    setCamera({x:clamp(at.x,230,530),y:clamp(at.y-22,205,355)});setZoom(true);
  }

  return <div className={`iso-board${activeResolution?' iso-resolving':''}${zoom?' iso-focused-view':''}`}>
    <div className="iso-tools">
      <span className="iso-height-key"><svg viewBox="0 0 20 20" aria-hidden="true"><path d="m2 10 8-5 8 5-8 5ZM2 10v4l8 5 8-5v-4M10 15v4"/></svg>Raised ground</span>
      <div className="iso-view-buttons">
        {changed&&<button type="button" className="iso-replay" onClick={()=>{setReplay(value=>value+1);setReplaying(true);onReplayChange?.(true);}} aria-label="Replay the last resolution effects" aria-pressed={replaying}><svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4 7a7 7 0 1 1-1 6M3 2v6h6"/></svg><span>Replay</span></button>}
        <button type="button" aria-pressed={zoom} onClick={()=>zoom?setZoom(false):focusView()}><svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="8" cy="8" r="5"/><path d="m12 12 5 5M5 8h6"/>{!zoom&&<path d="M8 5v6"/>}</svg>{zoom?'Overview':'Focus'}</button>
      </div>
    </div>
    <div className="iso-stage">
      <svg className="iso-svg" viewBox={view} role="group" aria-label="The Confluence, an elevated hex battlefield. Arrow keys move focus; Q and E reach the other diagonals; Enter selects a hex.">
        <defs>
          <radialGradient id={`${instance}-pool`}><stop offset="0" stopColor="#6f9d8d" stopOpacity=".2"/><stop offset="1" stopColor="#152834" stopOpacity="0"/></radialGradient>
          <linearGradient id={`${instance}-cliff`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#9b8c6c"/><stop offset="1" stopColor="#5c6355"/></linearGradient>
          <linearGradient id={`${instance}-hill`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#c2b28b"/><stop offset="1" stopColor="#8b8263"/></linearGradient>
          <filter id={`${instance}-shadow`} x="-30%" y="-30%" width="160%" height="180%"><feDropShadow dx="0" dy="2" stdDeviation="1.3" floodColor="#203b3a" floodOpacity=".24"/></filter>
          {Object.entries(elementColors).map(([element,color])=><marker key={element} id={`${instance}-arrow-${element}`} viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto"><path d="M0 1 9 5 0 9" fill="none" stroke={color} strokeWidth="2"/></marker>)}
          <marker id={`${instance}-move-arrow`} viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto"><path d="M0 1 9 5 0 9" fill="none" stroke="#e5f5d4" strokeWidth="2"/></marker>
        </defs>
        <ellipse cx="380" cy="345" rx="360" ry="220" fill={`url(#${instance}-pool)`}/>
        <ellipse cx="380" cy="427" rx="263" ry="83" fill="#081c25" opacity=".42"/>
        <g aria-hidden="true" className="iso-distant-reeds" stroke="#627b69" strokeWidth="2" fill="none"><path d="m98 350-7-25m7 25 1-31m-2 26-9-10m558 25 10-31m-11 30 1-23m5 10 10-10M285 478l-5-18m6 18 3-22"/></g>
        <g className="iso-tiles">
          {[...state.cells].sort((a,b)=>ground(a).y-ground(b).y||ground(a).x-ground(b).x).map(cell=>{
            const at=top(cell,state),base=ground(cell),vertices=hex(at.x,at.y,1),depth=20+cell.height*24;
            const surface=palette[cell.terrain]||palette.plain;
            const occupant=livingUnits.find(unit=>same(unit,cell));
            const isLegal=legal.has(key(cell));
            const isSelected=selectedUnit&&same(selectedUnit,cell);
            const planned=orders.filter(order=>order.move&&same(order.move,cell));
            const fieldNames=cell.reactions?.length?cell.reactions.map(reaction=>palette[reaction]?.name||reaction).join(' and '):surface.name;
            const label=`${cell.q}, ${cell.r}. ${cell.height?'Raised ground. ':''}${cell.well?'Wellspring. ':''}${fieldNames}${cell.ttl?`, ${cell.ttl} rounds remain`:''}.${occupant?` ${champion(occupant.championId).name}, ${occupant.owner===player?'your':'rival'} champion, ${occupant.hp} of ${occupant.maxHp} health.`:''}${planned.length?' Planned destination.':''}${isLegal?` Available ${kind} target.`:''}`;
            return <g key={key(cell)} className={`iso-tile${isLegal?' iso-legal':''}${isSelected?' iso-selected':''}${hovered===key(cell)?' iso-hovered':''}`}>
              <g aria-hidden="true" pointerEvents="none">
                {[0,1,2].map(index=>{const a=vertices[index],b=vertices[index+1];return <polygon key={index} points={`${a.x},${a.y} ${b.x},${b.y} ${b.x},${b.y+depth} ${a.x},${a.y+depth}`} fill={index===0?'#8e8266':index===1?`url(#${instance}-${cell.height?'hill':'cliff'})`:'#716e57'} stroke="#626953" strokeWidth="1"/>;})}
                {cell.height===1&&<><path d={`M${at.x-40},${at.y+20}l40 23 40-23M${at.x-39},${at.y+31}l39 23 39-23`} fill="none" stroke="#776e53" strokeWidth="1.3" opacity=".55"/><path d={`M${at.x-18},${at.y+35}v11m37-15v11M${at.x},${at.y+43}v14`} stroke="#776e53" strokeWidth="1.2" opacity=".6"/></>}
                <polygon points={points(vertices)} fill={surface.top} stroke="#53664f" strokeWidth="1.5"/>
                <polyline points={points([vertices[3],vertices[4],vertices[5],vertices[0]])} fill="none" stroke={cell.height?'#e2d7ad':'#c5c9a3'} strokeWidth="2"/>
                <polygon points={points(hex(at.x,at.y,5))} fill="none" stroke={cell.height?'#dbd1a5':'#c6c8a0'} strokeWidth=".7" opacity=".34"/>
                {cell.terrain==='plain'&&!cell.well&&<g fill="#657d52" opacity=".46"><path d={`m${at.x-25} ${at.y+5} 2-4 2 4 3-3-1 5Z`}/><path d={`m${at.x+17} ${at.y-10} 2-4 1 4 3-2-1 4Z`}/><ellipse cx={at.x+25} cy={at.y+7} rx="3" ry="1.5" fill="#d5c6a1"/></g>}
                {cell.height===1&&<g transform={`translate(${at.x+29},${at.y+8})`}><path d="m-5 0 5-3 5 3-5 3Z" fill="#e6d7ac" stroke="#8f805d" strokeWidth=".8"/><path d="M0 0v-5" stroke="#6e694d" strokeWidth="1.5"/></g>}
                {cell.well&&<g transform={`translate(${at.x},${at.y-1})`}><Well owner={occupant?.owner} occupied={!!occupant}/></g>}
                {cell.terrain!=='plain'&&<g transform={`translate(${at.x},${at.y-4})`} stroke={surface.mark} strokeWidth="1.7" fill="none" opacity={occupant||cell.well ? .5 : .72}><TerrainMark terrain={cell.terrain}/></g>}
                {cell.terrain!=='plain'&&<text className="iso-terrain-label" x={at.x} y={at.y+21} fill={surface.mark}>{surface.name}{(cell.reactions?.length||0)>1?` +${cell.reactions!.length-1}`:''}</text>}
                {cell.terrain!=='plain'&&cell.ttl!==undefined&&Array.from({length:Math.min(4,cell.ttl)},(_,i)=><circle key={i} cx={at.x-4*(Math.min(4,cell.ttl!)-1)+i*8} cy={at.y+26} r="1.5" fill={surface.mark}/>)}
                {isLegal&&<polygon className={`iso-target-edge iso-target-${kind}`} points={points(hex(at.x,at.y,3))}/>}
                {isLegal&&!occupant&&<g transform={`translate(${at.x},${at.y})`} className={`iso-target-mark iso-target-${kind}`}>{kind==='move'?<><ellipse rx="9" ry="5"/><path d="m-3-1 3 3 5-5"/></>:<><ellipse rx="9" ry="5"/><path d="M-15 0h6M9 0h6M0-9v4M0 5v4"/></>}</g>}
              </g>
              <g ref={node=>{if(node)refs.current.set(key(cell),node);else refs.current.delete(key(cell));}} tabIndex={focused===key(cell)?0:-1} role="button" aria-label={label} aria-disabled={!canInteract} className="iso-hit" onKeyDown={event=>onKey(event,cell)} onFocus={()=>{setFocused(key(cell));setHovered(key(cell));}} onBlur={()=>setHovered(null)} onMouseEnter={()=>setHovered(key(cell))} onMouseLeave={()=>setHovered(null)} onClick={()=>{setFocused(key(cell));if(canInteract)onCell(cell.q,cell.r);}}>
                <title>{label}</title><polygon points={points(vertices)} fill="transparent"/><polygon className="iso-focus-ring" points={points(hex(at.x,at.y,3))} fill="none"/>
              </g>
              {/* Tiny cliff-side plants are attached to the island, not interactive cells. */}
              {((cell.q===-3&&cell.r===2)||(cell.q===3&&cell.r===-2)||(cell.q===-1&&cell.r===-2))&&<g pointerEvents="none" aria-hidden="true" transform={`translate(${base.x-28},${base.y+11})`}><path d="M0 4V-9M0 0l-6-5M0-3l5-6" stroke="#566c45" strokeWidth="2"/><ellipse cx="-6" cy="-7" rx="5" ry="3" fill="#779858" transform="rotate(25 -6 -7)"/><ellipse cx="5" cy="-10" rx="5" ry="3" fill="#9dae6b" transform="rotate(-30 5 -10)"/></g>}
            </g>;
          })}
        </g>
        <g className="iso-intent-layer" aria-hidden="true" pointerEvents="none">
          {orders.map((order)=>{
            const unit=state.units.find(unit=>unit.id===order.unitId)!;const land=top(order.move||unit,state);const number=ownUnits.findIndex(entry=>entry.id===unit.id)+1;const color=elementColors[champion(unit.championId).element];
            const route=order.move?movementPath(state,unit.id,order.move):null;
            const routePath=[unit,...route||[]].map((point,index)=>{const at=top(point,state);return `${index?'L':'M'}${at.x} ${at.y}`;}).join(' ');
            return <g key={unit.id} className={unit.id===selected?'iso-order iso-order-selected':'iso-order'}>
              {order.move&&!same(order.move,unit)&&<><path className="iso-move-intent-shadow" d={routePath}/><path className="iso-move-intent" d={routePath} markerEnd={`url(#${instance}-move-arrow)`}/><ellipse cx={land.x} cy={land.y} rx="22" ry="12" className="iso-landing-ring"/><g transform={`translate(${land.x},${land.y})`} className="iso-ghost"><ChampionFigure id={unit.championId}/></g><g transform={`translate(${land.x+24},${land.y-11})`} className="iso-order-number"><circle r="9"/><text y="3">{number}</text></g></>}
              {order.cast&&(()=>{const target=top(order.cast!,state);const loop=same(order.cast!,order.move||unit);return <><path className="iso-cast-intent-shadow" d={loop?`M${land.x-8} ${land.y-20}c-30-44 45-44 20-5`:`M${land.x} ${land.y-25}Q${(land.x+target.x)/2} ${Math.min(land.y,target.y)-65} ${target.x} ${target.y-5}`}/><path className="iso-cast-intent" stroke={color} d={loop?`M${land.x-8} ${land.y-20}c-30-44 45-44 20-5`:`M${land.x} ${land.y-25}Q${(land.x+target.x)/2} ${Math.min(land.y,target.y)-65} ${target.x} ${target.y-5}`} markerEnd={`url(#${instance}-arrow-${champion(unit.championId).element})`}/><g transform={`translate(${target.x},${target.y})`} className="iso-cast-crosshair" stroke={color}><ellipse rx="24" ry="14"/><path d="M-31 0h10M21 0h10M0-20v8M0 12v8"/><circle cx="25" cy="-16" r="8" fill="#203641"/><text x="25" y="-13" stroke="none" fill={color}>{number}</text></g></>;})()}
            </g>;
          })}
          {orders.filter(order=>order.cast).filter((order,index,list)=>list.findIndex(other=>same(other.cast!,order.cast!))===index&&list.filter(other=>same(other.cast!,order.cast!)).length>1).map(order=>{const at=top(order.cast!,state);const count=orders.filter(other=>other.cast&&same(other.cast,order.cast!)).length;return <g key={key(order.cast!)} transform={`translate(${at.x},${at.y+33})`}><rect x="-30" y="-8" width="60" height="14" rx="7" fill="#293c45" stroke="#edcd88"/><text className="iso-combination-label" y="2">{count} SPELLS</text></g>;})}
        </g>
        <g className="iso-unit-layer" aria-hidden="true" pointerEvents="none">
          {visibleUnits.map(unit=>{
            const at=top(unit,state);const old=previousState?.units.find(other=>other.id===unit.id&&alive(other));const before=old&&previousState?top(old,previousState):at;
            const moveEvent=events.find(event=>event.kind==='move'&&event.unitId===unit.id);
            const pushEvent=events.find(event=>event.kind==='push'&&event.unitId===unit.id);
            const mid=moveEvent?.to?top(moveEvent.to,state):pushEvent?.from?top(pushEvent.from,state):at;
            const moving=changed&&!!(moveEvent||pushEvent);
            const selectedNow=selected===unit.id;const order=orders.find(entry=>entry.unitId===unit.id);const number=ownUnits.findIndex(entry=>entry.id===unit.id)+1;
            const damaged=events.some(event=>event.kind==='damage'&&event.unitId===unit.id);const healed=events.some(event=>event.kind==='heal'&&event.unitId===unit.id);const bouncing=events.some(event=>event.kind==='bounce'&&event.unitId===unit.id);
            const motion={'--iso-dx':`${before.x-at.x}px`,'--iso-dy':`${before.y-at.y}px`,'--iso-mid-dx':`${mid.x-at.x}px`,'--iso-mid-dy':`${mid.y-at.y}px`} as CSSProperties;
            const showingGuard=activeResolution?unit.guard:unit.owner===player&&showOrders&&!order?.cast;
            return <g key={unit.id} transform={`translate(${at.x},${at.y-2})`} className={`iso-unit${selectedNow?' iso-unit-selected':''}${unit.owner===player?' iso-own-unit':' iso-rival-unit'}`} pointerEvents={alive(unit)?'visiblePainted':'none'} onClick={()=>{if(canInteract&&alive(unit)){setFocused(key(unit));onCell(unit.q,unit.r);}}} onMouseEnter={()=>{if(alive(unit))setHovered(key(unit));}} onMouseLeave={()=>setHovered(null)}>
              <title>{`${champion(unit.championId).name} · ${unit.owner===player?'Your squad':'Rival'} · ${unit.hp}/${unit.maxHp} health${showingGuard?' · Guard':''}`}</title>
              <g key={eventKey} className={`iso-unit-motion${moving?' iso-unit-moving':bouncing?' iso-unit-bounce':''}`} style={motion}>
              <g className={!alive(unit)?'iso-unit-fallen':''}>
                <ellipse cy="4" rx={unit.championId==='treevor_mason'?27:23} ry="11" fill="#223c37" opacity=".32"/>
                <ellipse className="iso-team-ring" cy="3" rx={unit.championId==='treevor_mason'?26:22} ry="11" fill="none" stroke={teamColors[unit.owner]} strokeWidth={selectedNow?4:2.4}/>
                {selectedNow&&<><ellipse className="iso-selected-halo" cy="3" rx="31" ry="16" fill="none" stroke="#f7e7aa" strokeWidth="1.4"/><path d="m-5-94 5 7 5-7Z" fill="#ffedb3" stroke="#5e6852" strokeWidth="1"/></>}
                <g className={`iso-figure${damaged?' iso-hit-flash':''}${healed?' iso-heal-flash':''}`} filter={`url(#${instance}-shadow)`}><ChampionFigure id={unit.championId}/></g>
                {showingGuard&&<g className="iso-guard-badge" transform="translate(23,-27)"><path d="M-7-8H7L6 2 0 8-6 2Z" fill="#c6d7b3" stroke="#39514a" strokeWidth="1.5"/><path d="m-3-1 3 3 4-6" fill="none" stroke="#466353" strokeWidth="1.6"/></g>}
                <g className="iso-health" transform="translate(0,13)"><rect x="-21" y="-3" width="42" height="6" rx="3" fill="#253b3f" stroke="#f2e2b8" strokeWidth=".7"/>{Array.from({length:unit.maxHp},(_,i)=><rect key={i} x={-19+i*38/unit.maxHp} y="-1.5" width={Math.max(2,38/unit.maxHp-1.3)} height="3" rx=".5" fill={i<unit.hp?teamColors[unit.owner]:'#576361'}/>)}</g>
                <text className="iso-unit-name" y={unit.championId==='treevor_mason'?-97:-86}>{shortName[unit.championId]||champion(unit.championId).name}</text>
                {unit.owner===player&&<g className="iso-roster-number" transform="translate(-24,-17)"><circle r="8" fill={selectedNow?'#eee1b1':'#263d44'} stroke={teamColors[unit.owner]} strokeWidth="1.3"/><text y="3" fill={selectedNow?'#30464b':'#e3eee0'}>{number}</text></g>}
              </g></g>
            </g>;
          })}
        </g>
        <g key={`events-${eventKey}`} className="iso-resolution-layer" aria-hidden="true" pointerEvents="none">
          {events.map((event,index)=>{
            if(event.kind==='score'&&event.owner!==undefined)return event.amount?<g key={index} transform={`translate(${event.owner===0?170:590},140)`}><text className="iso-event-word iso-event-score" style={{'--iso-event-delay':'1.25s'} as CSSProperties}>{event.owner===player?'YOU':'RIVAL'} +{event.amount}</text></g>:null;
            const cell=eventPoint(event,state,previousState);if(!cell)return null;const at=top(cell,state);const unit=state.units.find(unit=>unit.id===event.unitId);const color=event.elements?.[0]?elementColors[event.elements[0]]:unit?elementColors[champion(unit.championId).element]:'#e7d99c';
            const delay=event.kind==='move'||event.kind==='bounce' ? .05 : event.kind==='cast' ? .34 : event.kind==='reaction' ? .54 : event.kind==='surface' ? 1.08 : event.kind==='respawn' ? 1.3 : event.kind==='defeat'&&events.slice(0,index).some(other=>other.kind==='surface'&&other.unitId===event.unitId) ? 1.12 : .72;
            const style={'--iso-event-delay':`${delay}s`,'--iso-effect-color':color} as CSSProperties;
            if(event.kind==='cast') {const origin=event.from||unit;if(!origin)return null;const from=top(origin,state);return <g key={index} className="iso-spell-event" style={style}><path d={`M${from.x} ${from.y-35}Q${(from.x+at.x)/2} ${Math.min(from.y,at.y)-80} ${at.x} ${at.y-5}`} fill="none" stroke={color} strokeWidth="4"/><ellipse cx={at.x} cy={at.y} rx="26" ry="15" fill={color} opacity=".45"/></g>;}
            if(event.kind==='reaction') {const active=state.cells.find(tile=>same(tile,cell))?.reactions;const label=active?.length?active.map(id=>palette[id]?.name||id).join(' + '):event.terrain?palette[event.terrain]?.name||event.terrain:'Reaction!';return <g key={index} transform={`translate(${at.x},${at.y})`} style={style}><g className="iso-reaction-event"><ellipse className="iso-reaction-wave" rx="36" ry="21" fill="none" stroke={palette[event.terrain||'']?.mark||'#f5d9ae'} strokeWidth="5"/><path d="m-13-12 4-13 9 9 9-14 3 17 17 2-14 9 9 13-20-3-5 14-4-17-18 4 10-14-16-7Z" fill={palette[event.terrain||'']?.top||'#e9c596'} stroke="#fff1c0" strokeWidth="2" opacity=".85"/></g><text className={`iso-reaction-word${(active?.length||0)>1?' iso-reaction-many':''}`} y="-57">{label}</text></g>;}
            if(event.kind==='damage'||event.kind==='surface'||event.kind==='heal'||event.kind==='bounce'||event.kind==='fizzle'||event.kind==='guard'||event.kind==='defeat'||event.kind==='respawn') {
              const label=event.kind==='damage'?`−${event.amount??0}`:event.kind==='surface'?`−${event.amount??1} MAGMA`:event.kind==='heal'?`+${event.amount??0}`:event.kind==='bounce'?'BLOCKED':event.kind==='fizzle'?'SPELL FIZZLED':event.kind==='guard'?'GUARD':event.kind==='defeat'?'RETURNING':'BACK!';
              return <g key={index} transform={`translate(${at.x},${at.y-69})`} style={style}><text className={`iso-event-word iso-event-${event.kind}`} y={index%2?-10:0}>{label}</text>{event.kind==='defeat'&&<circle className="iso-defeat-ring" cy="42" r="25" fill="none" stroke={color} strokeWidth="4"/>}</g>;
            }
            if(event.kind==='push'&&event.from&&event.to){const from=top(event.from,state);return <path key={index} className="iso-push-event" style={style} d={`M${from.x} ${from.y}L${at.x} ${at.y}`} fill="none" stroke="#d8f2dc" strokeWidth="7" strokeDasharray="3 7"/>;}
            return null;
          })}
        </g>
      </svg>
      {zoom&&<div className="iso-pan-controls" aria-label="Move the focused battlefield view"><button type="button" aria-label="Pan left" onClick={()=>setCamera(at=>({...at,x:clamp(at.x-75,195,565)}))}>←</button><button type="button" aria-label="Pan up" onClick={()=>setCamera(at=>({...at,y:clamp(at.y-55,180,370)}))}>↑</button><button type="button" aria-label="Center selected champion" onClick={focusView}>◎</button><button type="button" aria-label="Pan down" onClick={()=>setCamera(at=>({...at,y:clamp(at.y+55,180,370)}))}>↓</button><button type="button" aria-label="Pan right" onClick={()=>setCamera(at=>({...at,x:clamp(at.x+75,195,565)}))}>→</button></div>}
    </div>
    <div className="iso-board-caption"><span><i style={{background:teamColors[player]}}/>Your squad <i style={{background:teamColors[player===0?1:0]}}/>Rival</span><span>{activePoint?`${activePoint.q}, ${activePoint.r} · ${activePoint.height?'High ground':'Low ground'}${activePoint.well?' · Well':''}`:zoom?'Pan to inspect · Overview shows all hexes':'Focus enlarges the hexes'}</span></div>
    <p className="iso-sr-only">Dashed routes show planned moves. Destinations can be contested. Both squads move together. Curved arrows show planned spells. A rival can move before a spell lands.</p>
  </div>;
}


