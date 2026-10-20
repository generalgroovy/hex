"use client";

import {useEffect,useId,useMemo,useRef,useState,type CSSProperties,type KeyboardEvent,type PointerEvent} from 'react';
import {CHAMPIONS} from '../../lib/roster-v7';
import {isIce,isFlooded,surfaceTraits,movementEffort,movementPath,spellArea,terrainCover,isCellSolid,STATUS_DEFINITIONS,REACTIONS,reactionsFor,cellElements,type Point,type SimState,type SimEvent,type TeamPlan} from '../../lib/tactics-v10';
import {getSpell} from '../../lib/spells-v10';
import {BIOME_NAMES,biomeElement,type Biome} from '../../lib/arena-v7';
import {RESOLUTION_MS,PHASE_MS,EVENT_TEXT_MS,eventDelayMs,eventLabelLanes,reactionLabelGroups,surfaceLabelGroups} from '../../lib/feedback-v10';
import PixelChampion,{type PixelAction} from './PixelChampion';
import './pixel-battlefield.css';
import './pixel-battlefield-v7.css';
import './pixel-battlefield-v8.css';
import {ElementImpact,ElementSurface,ElementProjectile} from './ElementEffectsV10';
import {battlefieldMotion} from '../../lib/battlefield-motion-v10';
import {formatTile} from '../../lib/board-labels-v9';
import {TILE_SCALE,TILE_STEP_X,TILE_STEP_Y,SPRITE_SIZE,groundPoint,surfacePoint,battlefieldBounds,hexPolygon,focusViewSize,clampCamera as clampView,fitEffect,type ScreenPoint} from '../../lib/battlefield-geometry';

type Props = {state:SimState;plan:TeamPlan;player:0|1;selected:string|null;kind:'move'|'cast';onCell:(q:number,r:number)=>void;interactive:boolean;previousState?:SimState;resolving?:boolean;onReplayChange?:(active:boolean)=>void;legalTargets?:Point[];showOrders?:boolean;spellId?:string;affectedTargets?:Point[];aimTarget?:Point;onPreviewCell?:(point:Point|null)=>void;focusRequest?:number};
type Unit = SimState['units'][number];
const key=(point:Point)=>`${point.q},${point.r}`;
const same=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
const alive=(unit:Unit)=>unit.hp>0&&unit.respawn===undefined;
const wellValue=(cell:SimState['cells'][number])=>(cell.reactions??reactionsFor(cellElements(cell))).includes('penumbra')?2:1;
const champion=(id:string)=>CHAMPIONS.find(entry=>entry.id===id)!;
const teamColors=['#176f76','#a94230'];
const elementColors:Record<string,string>={fire:'#e66a1f',water:'#238dc2',air:'#739c32',earth:'#967039',light:'#e4ab1f',dark:'#8050bb'};
const terrainColors:Record<string,{top:string;shade:string;mark:string;name:string}>={
  ice:{top:'#b5d8d6',shade:'#66919b',mark:'#376b83',name:'Ice'},
  plain:{top:'#8d9a52',shade:'#637138',mark:'#3e4927',name:'Meadow'},
  water:{top:'#79b6bd',shade:'#3e8297',mark:'#164f77',name:'Water'},
  fire:{top:'#ce9b5b',shade:'#a26c37',mark:'#9d3c15',name:'Fire'},
  earth:{top:'#c5ad78',shade:'#9b8050',mark:'#594321',name:'Earth'},
  air:{top:'#b9c780',shade:'#8b9e50',mark:'#465e24',name:'Air'},
  light:{top:'#e5ca77',shade:'#bd9b39',mark:'#805510',name:'Light'},
  dark:{top:'#ae99bf',shade:'#7d6894',mark:'#4d286e',name:'Dark'},
  steam:{top:'#b5c9bd',shade:'#819f97',mark:'#315e63',name:'Steam'},
  magma:{top:'#b7834f',shade:'#81513b',mark:'#ffdf7e',name:'Magma'},
  quagmire:{top:'#99a36d',shade:'#6d794c',mark:'#414e28',name:'Quagmire'},
  penumbra:{top:'#baabc5',shade:'#8f789b',mark:'#553c78',name:'Penumbra'},
  sandblast:{top:'#c8b278',shade:'#9f874c',mark:'#6a4d21',name:'Sandblast'},
  crystal_prism:{top:'#c8cab3',shade:'#8eab98',mark:'#496d63',name:'Crystal Prism'},
  blightsoil:{top:'#a69b9d',shade:'#7c697e',mark:'#582f69',name:'Blightsoil'},
  arcstorm:{top:'#c5ab64',shade:'#998246',mark:'#814512',name:'Arcstorm'},
  solar_flare:{top:'#e2bd62',shade:'#b89134',mark:'#8a4f10',name:'Solar Flare'},
  backdraft:{top:'#c28c75',shade:'#975d56',mark:'#6c2f4c',name:'Backdraft'},
  hailcurrent:{top:'#9bc9c6',shade:'#6398a0',mark:'#305e81',name:'Hailcurrent'},
  mirrorwater:{top:'#c0d3bf',shade:'#87aaa0',mark:'#387b83',name:'Mirrorwater'},
  black_ice:{top:'#93adc0',shade:'#657995',mark:'#3c426d',name:'Black Ice'},
  lightbend:{top:'#cad58a',shade:'#98ad51',mark:'#527026',name:'Lightbend'},
  shadowdraft:{top:'#aaa3c5',shade:'#80769e',mark:'#54467a',name:'Shadowdraft'},
};
function terrainStyle(id:string) {if(terrainColors[id])return terrainColors[id];const reaction=REACTIONS.find(entry=>entry.id===id);return reaction?{top:reaction.color,shade:'#9b8050',mark:'#2c2519',name:reaction.name}:terrainColors.plain}
const biomeColors:Record<Biome,{top:string;shade:string;mark:string}>={plain:terrainColors.plain,earth:terrainColors.earth,water:terrainColors.water,forest:{top:'#7d9252',shade:'#4c6739',mark:'#2f512c'},marsh:{top:'#9baa86',shade:'#647e69',mark:'#365e50'},ruins:{top:'#b1aa8e',shade:'#7e7a64',mark:'#514b3b'}};
const hasField=(cell:SimState['cells'][number])=>cell.ttl!==undefined||cell.terrain!==biomeElement(cell.biome);
function biomeRule(cell:SimState['cells'][number]) {
  if(cell.biome==='ruins'&&isCellSolid(cell))return 'Earth base · blocks movement and sight';
  if(terrainCover(cell))return `Earth base · −${terrainCover(cell)} nonpiercing spell damage`;
  if(cell.biome==='marsh')return 'Water base · entry costs 2 movement';
  if(cell.height)return 'Earth base · climb costs 2 · +1 spell reach downhill';
  return cell.biome==='water'?'Water base · normal movement':'Normal movement';
}
function terrainBrief(cell:SimState['cells'][number]) {
  if(cell.biome==='ruins'&&isCellSolid(cell))return 'Blocks movement and sight';
  if(terrainCover(cell))return `Cover: −${terrainCover(cell)} nonpiercing spell damage`;
  if(cell.biome==='marsh')return 'Entry costs 2 movement';
  return cell.height?'Climb costs 2 · +1 reach downhill':'';
}
const fieldName=(cell:SimState['cells'][number])=>[isIce(cell)?'Ice':isFlooded(cell)?'Flood':null,cell.reactions?.length?cell.reactions.map(id=>terrainStyle(id).name).join(' + '):isIce(cell)||isFlooded(cell)?null:terrainStyle(cell.terrain).name].filter(Boolean).join(' · ');
const surfaceBrief=(cell:SimState['cells'][number])=>surfaceTraits(cell).map(trait=>({ice:'Slide to the last icy hex',flood:'Flood: 2 effort in or out',rough:'Rough: 2 effort in or out',embers:'Fire: 1 terrain damage',current:'Air: +1 starting movement',radiance:'Light: Clarity',gloom:'Dark: Wither'}[trait.id])).join(' · ');
function surfaceEventLabel(event:SimEvent,count=1):string {return event.status?(statusInfo(event.status)?.name||event.status).toUpperCase():event.amount!==undefined?`−${event.amount} TERRAIN`:event.terrain==='ice'?`ICE${count>1?` ×${count}`:''}`:event.terrain==='water'?`FLOOD${count>1?` ×${count}`:''}`:'BARRIER'}
const ground=groundPoint;
const top=(point:Point,state:SimState):ScreenPoint=>surfacePoint(point,state.cells.find(cell=>same(cell,point))?.height||0);
const silhouette='0,-30 8,-28 8,-26 20,-22 20,-20 32,-16 32,-14 44,-10 44,14 36,18 28,20 28,22 16,26 8,28 0,30 -8,28 -16,26 -28,22 -28,20 -36,18 -44,14 -44,-10 -32,-14 -32,-16 -20,-20 -20,-22 -8,-26 -8,-28';
const eventCell=(event:SimEvent,state:SimState,before?:SimState):Point|undefined=>event.to||(event.q!==undefined&&event.r!==undefined?{q:event.q,r:event.r}:state.units.find(unit=>unit.id===event.unitId)||before?.units.find(unit=>unit.id===event.unitId));
const statusEntries=(unit:Unit)=>Object.entries(unit.statuses||{}).filter(([,status])=>status&&status.turns>0);
function statusInfo(id:string) {const definitions=STATUS_DEFINITIONS as unknown as Record<string,{name:string;color:string;symbol:string}>|{id:string;name:string;color:string;symbol:string}[];return Array.isArray(definitions)?definitions.find(entry=>entry.id===id):definitions[id]}
function facing(from:Point,to:Point,fallback=0) {const a=ground(from),b=ground(to);if(a.x===b.x&&a.y===b.y)return fallback;return((Math.round(Math.atan2(b.x-a.x,b.y-a.y)/(Math.PI/4))%8)+8)%8;}
function spellColor(id:string|undefined,fallback:string) {const element=id?getSpell(id)?.element:undefined;return elementColors[element||'']||elementColors[fallback]||'#f4e6b9'}

function PixelGrass({seed=0}:{seed?:number}) {return <g shapeRendering="crispEdges">
  {seed%3===0&&<><path d="M-30 5h2v-7h2v5h3v5h-7Z" fill="#6d7e44"/><path d="M-28 3h2v4h-2" fill="#abb877"/></>}
  <path d={seed%2?'M18-13h5v2h-5M-8 15h4v2h-4':'M-17-16h6v2h-6M28 6h5v2h-5'} fill="#a7b36b" opacity=".6"/>
  {seed%17===0&&<><path d="M-32-5h3v-8h2v11h-5" fill="#53612d"/><path d="M-34-13h7v4h-7M-31-16h3v10h-3" fill="#e5dfb0"/><rect x="-31" y="-13" width="3" height="3" fill="#d5a036"/></>}
</g>}
/** Low edge details keep a champion's feet and the spell footprint unobstructed. */
function PixelBiome({biome,seed}:{biome:Biome;seed:number}) {
  if(biome==='plain')return <PixelGrass seed={seed}/>;
  if(biome==='forest')return <g className="px-biome-detail" shapeRendering="crispEdges">{[[-25,-9],[25,3],[-19,14]].map(([x,y],i)=><g key={i} transform={`translate(${x} ${y})`}><path d="M-2 2h4v9h-4Z" fill="#6b5738"/><path d="M-3-17h6v5h5v5h4v8H6v4H-6V1h-6v-8h4v-5h5Z" fill="#3c6131" stroke="#2f4927" strokeWidth="1"/><path d="M-2-15h4v6h5v3H0v4h-7v-4h3v-6h2Z" fill="#9aaa60"/><path d="M3-3h6v3H3M-7 3h11" stroke="#6e8b44" strokeWidth="2"/></g>)}</g>;
  if(biome==='marsh')return <g className="px-biome-detail" shapeRendering="crispEdges"><path d="M-29 5h12v-3H-6v3H8M12-10h16v3h7M-5 16h16v-3h13" fill="none" stroke="#477c79" strokeWidth="2"/><path d="M-22-2v-15m-5 7v9m9-12v10M22 15V1m-5 7v7m10-12v12" stroke="#587344" strokeWidth="2"/><path d="M-24-17h4v6h-4M20 1h4v6h-4M25 2h4v5h-4" fill="#776544"/><path d="M-12 10h4v3h-4M10-14h5v3h-5" fill="#b8bd75"/></g>;
  if(biome==='ruins')return <g className="px-biome-detail" shapeRendering="crispEdges"><path d="M-31 8v-24h12v-8h13v12H4v-18h13v12h13V8L16 15H-17Z" fill="#8c8a76" stroke="#514b3b" strokeWidth="2"/><path d="M-29-14h10v-7h11v11H4v-17h11v12h13" fill="none" stroke="#d6ceb0" strokeWidth="3"/><path d="M-17-10V8M-6-5H27M11-12V9M-30 0H-17M-6 4H10M17 3H29" fill="none" stroke="#626252" strokeWidth="2"/><path d="M-12 9v-8h8v12H-12M17 10h13v4H16M-29 8h7v6h-7" fill="#596b43"/><path d="M-5-19h4v7h-4M20-6h3v8h-3" fill="#b3aa89"/></g>;
  return null;
}
function PixelRune({terrain}:{terrain:string}) {
  const common={fill:'none',stroke:'currentColor',strokeWidth:3,strokeLinejoin:'miter' as const};
  if(terrain==='fire'||terrain==='magma')return <g {...common}><path d="M-8 8h-5V0h5v-7h5v-8h4v9h5v-5h4V1h4v7H8v4H-8Z"/>{terrain==='magma'&&<path d="M-26 7h8v5h7M18-8v5h10v5"/>}</g>;
  if(terrain==='water')return <g {...common}><path d="M-24-4h10v-3H-3v3H9v-3h12M-18 6h10V3H4v3h14"/></g>;
  if(terrain==='earth')return <g {...common}><path d="M-20 9V4h5v-8h5V0h4v9ZM0 9V0h5v-9h5v-6h4v8h5V4h5v5Z"/></g>;
  if(terrain==='air')return <g {...common}><path d="M-22-4H9v-6h8v6h-4M-15 4h32v6H9M-7-12h5"/></g>;
  if(terrain==='light')return <g {...common}><path d="M-3-17h6v10h7v5h9v5H9v5H3v10H-3V8h-7V3h-9v-5h9v-5h7Z"/></g>;
  if(terrain==='dark')return <g {...common}><path d="M8-15H-4v4h-8v8h-4v9h4v6h8v4H8v-5h7V7H3V3H-2V-5H3v-5h5Z"/></g>;
  if(terrain==='steam')return <g {...common}><path d="M-22 8V-1h6v-7h11v-5H5v5h11v7h6v9ZM-8 12v6M6 12v6"/></g>;
  if(terrain==='quagmire')return <g {...common}><path d="M-22 3h7V0H15v3h7v6H15v3H-15V9h-7ZM-6 3V-13m0 6h-6m6-3h7"/></g>;
  if(terrain==='penumbra')return <g {...common}><path d="M-20-2h8v-6h9v-7h6v7h9v6h8v5h-8v6H3v7H-3V9h-9V3h-8ZM-4-4H4v8H-4Z"/></g>;
  if(terrain==='sandblast')return <g {...common}><path d="M-24-8H6v-5h9M-17 2H13v5h9M-24 12h8M-8 11H4"/><path d="M19-8h4M12-2h4M-9-15h4" strokeWidth="4"/></g>;
  if(terrain==='crystal_prism')return <g {...common}><path d="M-12-7 0-16 12-7 12 7 0 16-12 7ZM0-16V16M-12-7 0 2 12-7M-21 7h-5M20-5h6"/></g>;
  if(terrain==='blightsoil')return <g {...common}><path d="M-21 10h42M0 10V-14M0-3h-9v-7h-5M0 3h11v-9h5M-12 14v-4M12 14v-4"/><path d="M-4-18H4v6H-4Z" fill="currentColor" stroke="none"/></g>;
  if(terrain==='arcstorm')return <g {...common}><path d="M-14-11H0v-5H13L4-3H14L-4 15 0 4H-10L-2-7M-25 1h10M15 11h10"/></g>;
  if(terrain==='solar_flare')return <g {...common}><path d="M-7-9H7V-3H13V4H7v6H-7V4h-6V-3h6ZM0-18v5M0 14v5M-23 0h6M17 0h6M-16-14l4 4M12 11l4 4M15-14l-4 4M-12 11l-4 4"/></g>;
  if(terrain==='backdraft')return <g {...common}><path d="M-22-5h12v-7H6v-5h9V-7H8v6h10v10H6v6H-8V9h-9V1h7M-2-1h7v5H-2Z"/></g>;
  if(terrain==='hailcurrent')return <g {...common}><path d="M-24-7h18v-5H9M-15 4h29v-5h9M-21 13h9M5 13h10"/><path d="M-12-18h4M16-12h4M-3 8h4" strokeWidth="5"/></g>;
  if(terrain==='mirrorwater')return <g {...common}><path d="M-22 2H22M-9-3V-8h6v-7H3v7h6v5M-9 7v4h6v5H3v-5h6V7M-25-6h6M19 9h6"/></g>;
  if(terrain==='black_ice')return <g {...common}><path d="M-22 11h44M-17 8V0h4v-7h5V5h5M0 8V-8h5v-10h4V-2h5V8M17 8V1h5"/></g>;
  if(terrain==='lightbend')return <g {...common}><path d="M-25 10h10V4h7V-4H0v-8H9v-5h9M-18 16h10V9H0V1H8v-7h10M19-16v8h7"/></g>;
  if(terrain==='shadowdraft')return <g {...common}><path d="M-25-4h14v-6H10v6h10V6H9v7H-8V7h-7V1H-2V-3H8M18-12h7M-23 13h8"/></g>;
  const reaction=REACTIONS.find(entry=>entry.id===terrain);
  return reaction?<g><g transform="translate(-11 0) scale(.5)" style={{color:elementColors[reaction.elements[0]]}}><PixelRune terrain={reaction.elements[0]}/></g><path d="M-3-2H3v4H-3Z" fill="currentColor"/><g transform="translate(11 0) scale(.5)" style={{color:elementColors[reaction.elements[1]]}}><PixelRune terrain={reaction.elements[1]}/></g></g>:null;
}
function PixelWell({owner,occupied}:{owner?:number;occupied:boolean}) {return <g shapeRendering="crispEdges">
  <path d="M-27 2v10l12 7H13l14-7V2" fill="#5c4c2f" stroke="#2c2519" strokeWidth="2"/><path d="M-25-5-12-12H12L25-5V6L13 13H-13L-25 6Z" fill="#c6ad76" stroke="#5d4a2a" strokeWidth="2"/>
  <path d="M-25-5-12-12H12L25-5 12 3H-12Z" fill="#e5d39e"/><path d="M-14-5-7-9H7L14-5 7 0H-7Z" fill="#193e42" stroke="#735c32" strokeWidth="2"/>
  <path d="M-11-4-6-7H6L11-4 6-1H-6Z" fill={owner===undefined?'#39a5bf':teamColors[owner]}/><path d="M-25 1l12 7H13l12-7v4l-12 8H-13l-12-8Z" fill="#aa8b54"/>
  <path d="M-14 4v9M1 5v8M14 3v9" stroke="#6b5738" strokeWidth="2"/><path d="M-23-5l10-5H11l10 5" fill="none" stroke="#fff3ce" strokeWidth="2"/>
  {!occupied&&<g className="px-well-flame"><path d="M-3-31H3v8H7v9H3v6H-3v-6H-7v-9H-3Z" fill="#30b5d0" stroke="#214954" strokeWidth="2"/><path d="M-2-28H2v18H-2Z" fill="#bdf5ef"/><rect x="-2" y="-1" width="4" height="2" fill="#fff3ce"/></g>}
</g>}
function StatusAura({unit}:{unit:Unit}) {return <g pointerEvents="none" shapeRendering="crispEdges">
  {unit.statuses.burn&&<g className="px-aura-burn" fill="#ff9e62"><path d="M-20-17h4v-8h3v15h-8v-5M20-11h4v-8h3v14h-8v-4M-4-4h3v-8h3v14h-8v-3Z"/><path d="M-18-13h3v5h-3M22-8h3v5h-3" fill="#ffe2a0"/></g>}
  {unit.statuses.wet&&<g className="px-aura-wet" fill="#81deed"><path d="M-24-36h3v5h-3M23-24h3v5h-3M-14-9h3v4h-3"/><path d="M-19 6h13v2h-13M4 9h15V7H4" opacity=".7"/></g>}
  {unit.statuses.blind&&<g className="px-aura-blind"><path d="M-20-68h8v-3h23v3h9v6h-8v3h-24v-3h-8Z" fill="#685776" fillOpacity=".8"/><path d="M-12-66h7v3h-7M6-66h7v3H6" fill="#d8b6e7"/></g>}
  {unit.statuses.concussed&&<g className="px-aura-concussed" fill="#ffe2a4"><path d="M-21-87h3v-3h3v3h3v3h-3v3h-3v-3h-3M13-91h3v-3h3v3h3v3h-3v3h-3v-3h-3"/></g>}
  {unit.statuses.rooted&&<path d="M-25 9v-5h7v-11h4v9h9v8H7V1h10v-10h4V4h6v5H15v5H-13V9Z" fill="#806c43" stroke="#c1b27a" strokeWidth="1"/>}
  {unit.statuses.chilled&&<g className="px-aura-chilled" fill="#b5ebec"><path d="M-24 4V-6h4v-6h3V3h4v5M13 6V-3h4v-7h4V1h5v7"/><rect x="-2" y="-36" width="3" height="3"/></g>}
  {unit.statuses.ward&&<path className="px-aura-ward" d="M-30-54v-14l30-14 30 14v14M-30-17v16L0 15 30-1v-16" fill="none" stroke="#f0dda2" strokeWidth="2" strokeDasharray="8 4"/>}
  {unit.statuses.haste&&<path className="px-aura-haste" d="M-30-2h-9v3h-8M27 5h10V2h9" fill="none" stroke="#bdeace" strokeWidth="3"/>}
</g>}
function IslandTrim({state}:{state:SimState}) {
  const north=Math.min(...state.cells.map(cell=>top(cell,state).y));
  const south=Math.max(...state.cells.map(cell=>ground(cell).y));
  const west=Math.min(...state.cells.map(cell=>ground(cell).x));
  const east=Math.max(...state.cells.map(cell=>ground(cell).x));
  return <g aria-hidden="true" pointerEvents="none" shapeRendering="crispEdges">
    <g transform={`translate(450 ${north-30})`} opacity=".86"><path d="M-16 4v-51h6v-14h39v10h10v48H25v-40H1V4Z" fill="#56462d" stroke="#2c2519" strokeWidth="2"/><path d="M-12-47H1V0h-13M-6-59h35v10H-6M27-49h10v43H27" fill="#b69d68"/><path d="M-12-47H1v5h-13M27-49h10v4H27M-6-59h35v4H-6" fill="#e4ce93"/><path d="M-12-29H1M-12-14H1M27-30h10M27-15h10M8-59v10M21-59v10" stroke="#75603a" strokeWidth="2"/><path d="M-18-1H3v5h-21M23-7h20v5H23" fill="#7a8146" stroke="#53612d"/><path d="M24-62h5v16h-5v12h-4v8h-4v-6h5v-10h3Z" fill="#53612d"/><path d="M18-48h9v4h-9M25-57h8v4h-8M15-37h9v4h-9" fill="#8e9e51"/></g>
    {[west-83,east+83].map(x=><g key={x} transform={`translate(${x} 318)`}><path d="M-2 10v-30h7v30M-10-23H15v6H-10M-6-31H11v8H-6" fill="#6b5738" stroke="#2c2519" strokeWidth="2"/><path d="M-6-17H11V1H-6Z" fill="#ad7a25" stroke="#2c2519" strokeWidth="2"/><path d="M-3-14H8V-2H-3Z" fill="#efc657"/><path d="M0-12H5v8H0Z" fill="#fff3ce"/><path d="M-9 1h23v4H-9" fill="#53612d"/></g>)}
    <g transform={`translate(450 ${south+69})`}><path d="M-20 1h40v4h-40" fill="#ad915b" opacity=".4"/><path d="M0 0v-23h4v23M2-15h8v-5h5v9H3M1-7h-9v-5h-5v10H1" fill="#53612d"/><path d="M-8-10h7v6h-7M7-18h9v5H7" fill="#91a04f"/><path d="M0-30h7v8H0M-4-27H11v4H-4" fill="#b55337" stroke="#6b5738"/><rect x="1" y="-27" width="5" height="4" fill="#f4d38a"/></g>
  </g>
}

export default function PixelBattlefieldV7({state,plan,player,selected,kind,onCell,interactive,previousState,resolving=false,onReplayChange,legalTargets=[],showOrders=true,spellId,affectedTargets=[],aimTarget,onPreviewCell,focusRequest=0}:Props) {
  const instance=useId().replace(/:/g,'');
  const [focused,setFocused]=useState('0,0');
  const [hovered,setHovered]=useState<string|null>(null);
  const [zoom,setZoom]=useState(true);
  const [viewport,setViewport]=useState({width:960,height:500});
  const [detailScale,setDetailScale]=useState(1);
  const [panControls,setPanControls]=useState(false);
  const [camera,setCamera]=useState({x:450,y:290});
  const [replay,setReplay]=useState(0);
  const [replaying,setReplaying]=useState(false);
  const [phase,setPhase]=useState<'move'|'cast'|'impact'|'settle'>('settle');
  const replayCallback=useRef(onReplayChange);
  replayCallback.current=onReplayChange;
  const svgRef=useRef<SVGSVGElement|null>(null);
  const refs=useRef(new Map<string,SVGGElement>());
  const drag=useRef<{x:number;y:number;camera:ScreenPoint;moved:boolean}|null>(null);
  const dragged=useRef(false);
  const initialCamera=useRef(false);
  const returnCamera=useRef<{camera:ScreenPoint;scale:number;zoom:boolean}|null>(null);
  const activeResolution=resolving||replaying;
  const canInteract=interactive&&!activeResolution;
  const legal=new Set(canInteract?legalTargets.map(key):[]);
  const affected=new Set(canInteract?affectedTargets.map(key):[]);
  const ownUnits=state.units.filter(unit=>unit.owner===player);
  const livingUnits=state.units.filter(alive);
  const selectedUnit=livingUnits.find(unit=>unit.id===selected);
  const events=previousState&&previousState.version!==state.version?state.lastResolution||[]:[];
  const surfaceLabels=surfaceLabelGroups(events);
  const castAreas=useMemo(()=>events.filter(event=>event.kind==='cast'&&event.unitId&&event.spellId&&event.to).map(event=>({event,cells:spellArea(previousState||state,event.unitId!,event.spellId!,event.to!,event.from)})),[state,previousState]);
  const visibleUnits=state.units.filter(unit=>alive(unit)||(activeResolution&&events.some(event=>event.kind==='defeat'&&event.unitId===unit.id)));
  const orders=showOrders&&!activeResolution?plan.orders.filter(order=>state.units.some(unit=>unit.id===order.unitId&&unit.owner===player&&alive(unit))):[];
  const bounds=battlefieldBounds(state.cells);
  const focusSize=focusViewSize(viewport,detailScale);
  const clampCamera=(at:ScreenPoint)=>clampView(at,bounds,focusSize);
  const safeCamera=clampCamera(camera);
  const view=zoom?`${safeCamera.x-focusSize.width/2} ${safeCamera.y-focusSize.height/2} ${focusSize.width} ${focusSize.height}`:`${bounds.left} ${bounds.top} ${bounds.right-bounds.left} ${bounds.bottom-bounds.top}`;
  const screenScale=Math.max((zoom?focusSize.width:bounds.right-bounds.left)/viewport.width,(zoom?focusSize.height:bounds.bottom-bounds.top)/viewport.height);
  const tacticalOverview=!zoom||detailScale>1.65;
  const plannedOrigin=orders.find(order=>order.unitId===selected)?.move||selectedUnit;
  const activeCell=state.cells.find(cell=>key(cell)===(hovered||(aimTarget?key(aimTarget):focused)));
  const activeUnit=activeCell?livingUnits.find(unit=>same(unit,activeCell)):undefined;
  const tileReferences=new Map<string,{point:Point;active:boolean}>();
  for(const order of orders)for(const point of [order.move,order.cast])if(point)tileReferences.set(key(point),{point,active:false});
  if(activeCell&&!activeResolution)tileReferences.set(key(activeCell),{point:activeCell,active:true});
  const hoverRoute=canInteract&&kind==='move'&&selectedUnit&&activeCell&&legal.has(key(activeCell))?movementPath(state,selectedUnit.id,activeCell):null;
  const hoverEffort=hoverRoute&&selectedUnit&&activeCell?movementEffort(state,selectedUnit.id,activeCell):null;
  const eventKey=`${state.version}-${replay}`;
  const labelLanes=eventLabelLanes(events,state);
  const reactionLabels=reactionLabelGroups(events,state);
  const scoreEvents=events.filter(event=>event.kind==='score'&&(event.amount||0)>0);
  const beforeImpact=activeResolution&&(phase==='move'||phase==='cast');
  const motions=useMemo(()=>new Map(state.units.map(unit=>[unit.id,battlefieldMotion(previousState,state,unit.id,instance)])),[previousState,state,instance]);
  useEffect(()=>{const svg=svgRef.current;if(!svg)return;const update=()=>{const box=svg.getBoundingClientRect();if(box.width&&box.height)setViewport({width:box.width,height:box.height})};update();const observer=new ResizeObserver(update);observer.observe(svg);return()=>observer.disconnect()},[]);
  useEffect(()=>{if(initialCamera.current)return;initialCamera.current=true;const at=top(selectedUnit||ownUnits[0]||{q:0,r:0},state);setCamera({x:at.x,y:at.y-42})},[state,selectedUnit,ownUnits]);
  // A new order follows the selected champion without overriding an explicit Overview.
  useEffect(()=>{if(!activeResolution&&plannedOrigin){const at=top(plannedOrigin,state);setDetailScale(1);setCamera({x:at.x,y:at.y-42});setFocused(key(plannedOrigin))}},[selected,plannedOrigin?.q,plannedOrigin?.r,focusRequest,activeResolution]);
  useEffect(()=>{if(!replaying)return;const timer=setTimeout(()=>{setReplaying(false);replayCallback.current?.(false)},RESOLUTION_MS);return()=>clearTimeout(timer)},[replaying,replay,state.version]);
  useEffect(()=>{if(!activeResolution){setPhase('settle');return}setPhase('move');const cast=setTimeout(()=>setPhase('cast'),PHASE_MS.cast),impact=setTimeout(()=>setPhase('impact'),PHASE_MS.impact),settle=setTimeout(()=>setPhase('settle'),PHASE_MS.settle);return()=>{clearTimeout(cast);clearTimeout(impact);clearTimeout(settle)}},[activeResolution,eventKey]);
  useEffect(()=>{
    if(!activeResolution){const saved=returnCamera.current;if(saved){setCamera(saved.camera);setDetailScale(saved.scale);setZoom(saved.zoom);returnCamera.current=null;}return;}
    const selectedAt=top(selectedUnit||ownUnits[0]||{q:0,r:0},state);
    returnCamera.current=replaying?{camera:{...safeCamera},scale:detailScale,zoom}:{camera:{x:selectedAt.x,y:selectedAt.y-42},scale:1,zoom};
    const actionPoints=castAreas.flatMap(({event,cells})=>[...(event.from?[event.from]:[]),...cells]);
    if(actionPoints.length)actionPoints.push(...events.filter(event=>['push','damage','heal','defeat'].includes(event.kind)).flatMap(event=>eventCell(event,state,previousState)?[eventCell(event,state,previousState)!]:[]));
    const points=actionPoints.length?actionPoints:events.filter(event=>['move','push','damage','heal','defeat','respawn'].includes(event.kind)).flatMap(event=>[...(event.from?[event.from]:[]),...(eventCell(event,state,previousState)?[eventCell(event,state,previousState)!]:[])]);
    if(points.length){const fitted=fitEffect(points.map(point=>top(point,state)),viewport);setDetailScale(fitted.scale);setCamera(fitted.center);setZoom(true);}
  },[activeResolution,eventKey]);

  function previewCell(point:Point|null) {setHovered(point?key(point):null);onPreviewCell?.(point&&legal.has(key(point))?{q:point.q,r:point.r}:null)}
  function focusCell(point:Point) {const id=key(point);setFocused(id);refs.current.get(id)?.focus();if(zoom){const at=top(point,state);setCamera(clampCamera({x:at.x,y:at.y-42}))}}
  function onKey(event:KeyboardEvent<SVGGElement>,point:Point) {
    if(event.altKey||event.ctrlKey||event.metaKey||event.nativeEvent.isComposing)return;
    if(event.key==='Enter'||event.key===' '){event.preventDefault();if(canInteract)onCell(point.q,point.r);return}
    if(event.key==='Home'){event.preventDefault();focusCell({q:0,r:0});return}
    const vectors:Record<string,Point>={ArrowRight:{q:1,r:0},ArrowLeft:{q:-1,r:0},ArrowUp:{q:0,r:-1},ArrowDown:{q:0,r:1},q:{q:-1,r:1},e:{q:1,r:-1}};
    const delta=vectors[event.key];if(!delta)return;event.preventDefault();const next=state.cells.find(cell=>cell.q===point.q+delta.q&&cell.r===point.r+delta.r);if(next)focusCell(next);
  }
  function focusView() {const at=top(plannedOrigin||selectedUnit||{q:0,r:0},state);setDetailScale(1);setCamera({x:at.x,y:at.y-42});setZoom(true)}
  function showEffect() {const points=[...(plannedOrigin?[plannedOrigin]:[]),...affectedTargets];const fitted=fitEffect(points.map(point=>top(point,state)),viewport);setDetailScale(fitted.scale);setCamera(fitted.center);setZoom(true)}
  function pointerDown(event:PointerEvent<SVGSVGElement>) {if(!zoom||event.button!==0)return;dragged.current=false;drag.current={x:event.clientX,y:event.clientY,camera:{...safeCamera},moved:false}}
  function pointerMove(event:PointerEvent<SVGSVGElement>) {if(!drag.current||!zoom)return;const dx=event.clientX-drag.current.x,dy=event.clientY-drag.current.y;if(Math.abs(dx)+Math.abs(dy)<8&&!drag.current.moved)return;drag.current.moved=true;dragged.current=true;const box=svgRef.current?.getBoundingClientRect();if(!event.currentTarget.hasPointerCapture(event.pointerId))event.currentTarget.setPointerCapture(event.pointerId);const scale=Math.max(focusSize.width/(box?.width||960),focusSize.height/(box?.height||500));setCamera(clampCamera({x:drag.current.camera.x-dx*scale,y:drag.current.camera.y-dy*scale}))}
  function choose(point:Point) {if(dragged.current){dragged.current=false;return}setFocused(key(point));if(canInteract)onCell(point.q,point.r)}

  function unitFigure(unit:Unit) {
    const at=top(unit,state),old=previousState?.units.find(entry=>entry.id===unit.id&&alive(entry)),before=old&&previousState?top(old,previousState):at;
    const shown=beforeImpact&&old?old:unit;
    const move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id),cast=events.find(event=>event.kind==='cast'&&event.unitId===unit.id);
    const mid=move?.to?top(move.to,state):push?.from?top(push.from,state):at;
    const damaged=events.some(event=>event.kind==='damage'&&event.unitId===unit.id),healed=events.some(event=>event.kind==='heal'&&event.unitId===unit.id),bounced=events.some(event=>event.kind==='bounce'&&event.unitId===unit.id);
    const isSelected=unit.id===selected,order=orders.find(entry=>entry.unitId===unit.id),guarding=activeResolution?unit.guard:unit.owner===player&&showOrders&&!!order?.guard;
    const number=state.units.filter(entry=>entry.owner===unit.owner).findIndex(entry=>entry.id===unit.id)+1;
    const hero=champion(unit.championId);
    const direction=activeResolution&&cast?.to?facing(cast.from||unit,cast.to,unit.owner===0?2:6):order?.cast?facing(order.move||unit,order.cast,unit.owner===0?2:6):order?.move?facing(unit,order.move,unit.owner===0?2:6):unit.owner===0?1:7;
    const sliding=!!move&&!!previousState&&!!movementPath(previousState,unit.id,move.to!)?.some(isIce);
    const action:PixelAction=!alive(unit)&&!beforeImpact?'defeat':activeResolution&&phase==='move'&&!!move&&!sliding?'walk':activeResolution&&phase==='cast'&&!!cast?'cast':activeResolution&&phase==='impact'&&damaged?'hit':'idle';
    const motion={'--px-dx':`${before.x-at.x}px`,'--px-dy':`${before.y-at.y}px`,'--px-mid-dx':`${mid.x-at.x}px`,'--px-mid-dy':`${mid.y-at.y}px`} as CSSProperties;
    return <g key={unit.id} transform={`translate(${at.x},${at.y-1})`} className={`px-unit${isSelected?' px-unit-selected':''}`} aria-hidden="true" onClick={()=>choose(unit)} onPointerEnter={event=>{if(event.pointerType==='mouse')previewCell(unit)}}>
      <title>{`${hero.name} · ${unit.owner===player?'Your company':'Rival'} · ${unit.hp}/${unit.maxHp} health · ${unit.flux}/${unit.maxFlux} Flux${statusEntries(unit).map(([id,status])=>` · ${statusInfo(id)?.name||id} ${status?.turns}`).join('')}`}</title>
      <g key={eventKey} className={`px-unit-motion${activeResolution&&(move||push)?' px-unit-moving':''}`} style={activeResolution?motions.get(unit.id)?.style||motion:undefined}><g className={activeResolution&&bounced?'px-unit-bounce':undefined} style={activeResolution&&bounced?{animationDelay:events.findIndex(event=>event.kind==='cast')>=0&&events.findIndex(event=>event.kind==='bounce'&&event.unitId===unit.id)>events.findIndex(event=>event.kind==='cast')?'1100ms':'100ms'}:undefined}>
        <path d="M-27 0-13-7h26l14 7v7l-14 7h-26l-14-7Z" fill="#2c2519" opacity=".28"/>
        <path d="M-26-1-13-8h26l13 7v6l-13 7h-26l-13-7Z" fill="none" stroke="#fff3ce" strokeWidth={isSelected?7:5}/>
        <path d="M-26-1-13-8h26l13 7v6l-13 7h-26l-13-7Z" fill="none" stroke={teamColors[unit.owner]} strokeWidth={isSelected?4:2.5}/>
        {isSelected&&<><path d="M-31-1-16-11h32l15 10v8l-15 9h-32l-15-9Z" fill="none" stroke="#2c2519" strokeWidth="1.5"/><path className="px-selection-arrow" d="M-7-117H7v5H3v5H-3v-5H-7Z" fill="#efc657" stroke="#2c2519" strokeWidth="1.5"/></>}
        {isSelected&&<text className="px-active-name" y="-132">{hero.name}</text>}
        <foreignObject x={-SPRITE_SIZE/2} y={-SPRITE_SIZE*.8125} width={SPRITE_SIZE} height={SPRITE_SIZE} pointerEvents="none" className={activeResolution&&healed?'px-heal-glow':''}><PixelChampion id={unit.championId} action={action} facing={direction} size={SPRITE_SIZE} motion={isSelected&&!tacticalOverview&&!activeResolution?'full':'quiet'}/></foreignObject>
        <StatusAura unit={shown}/>
        <rect x="-35" y="-108" width="70" height="116" fill="transparent" className="px-unit-hitbox"/>
        {guarding&&<g transform="translate(29 -23)" className="px-guard"><path d="M-8-12H8V2L4 6v3H-4V6L-8 2Z" fill="#e4ca87" stroke="#2c2519" strokeWidth="2"/><path d="M-4-4v5h4V-6H4" fill="none" stroke="#74531e" strokeWidth="2"/></g>}
        <g className="px-unit-badge" transform="translate(-30 -17)"><path d="M-7-9H7v3h3V6H7v3H-7V6h-3V-6h3Z" fill={teamColors[unit.owner]} stroke={isSelected?'#f8e4a0':'#fff3ce'} strokeWidth="2"/><text className="px-unit-number" y="4" fill="#fff3ce">{number}</text></g>
        {isSelected&&statusEntries(shown).slice(0,2).map(([id],index)=>{const meta=statusInfo(id);return <g key={id} transform={`translate(33 ${-57+index*20})`} className={`px-status px-status-${id}`}><rect x="-9" y="-8" width="18" height="16" fill="#2c2519" stroke={meta?.color||'#e5cc9a'} strokeWidth="1"/><text y="3" fill={meta?.color||'#e5cc9a'}>{(meta?.symbol||id.slice(0,1)).slice(0,2)}</text></g>})}
      </g></g>
    </g>;
  }

  return <div className={`px-board px-board-v7 px-board-v8${activeResolution?' px-resolving':''}${zoom?' px-focused':''}${tacticalOverview?' px-tactical-overview':''}`} style={{'--px-text-duration':`${EVENT_TEXT_MS}ms`,'--px-impact-delay':`${PHASE_MS.impact}ms`} as CSSProperties}>
    {activeResolution&&<style>{[...motions.values()].filter(Boolean).map(motion=>motion!.keyframes).join('\n')}</style>}
    <div className="px-board-toolbar"><div className="px-camera-tools" role="group" aria-label="Battlefield view">
      {events.length>0&&<button type="button" onClick={()=>{setReplay(value=>value+1);setReplaying(true);onReplayChange?.(true)}} aria-pressed={replaying} aria-label="Replay the last resolution effects" disabled={resolving}>↻ <span>Replay</span></button>}
      <button type="button" aria-pressed={zoom} onClick={()=>zoom&&detailScale===1?setZoom(false):focusView()}>{zoom&&detailScale===1?'−':'+'} <span>{zoom&&detailScale===1?'Overview':'Focus'}</span></button>
      <button type="button" className="px-center" aria-label="Center selected character" disabled={!selectedUnit} onClick={focusView}>◎ <span>Center</span></button>
      {affectedTargets.length>1&&<button type="button" className="px-fit-effect" aria-label="Fit complete spell effect" onClick={showEffect}>⌖ <span>Fit spell</span></button>}
      {zoom&&<button type="button" className="px-pan-toggle" aria-label="Show battlefield pan controls" aria-expanded={panControls} onClick={()=>setPanControls(value=>!value)}>✥ <span>Pan</span></button>}
    </div></div>
    <div className="px-stage">
      <svg ref={svgRef} className="px-battlefield" viewBox={view} role="group" aria-label="Battlefield. Columns A to S run left to right; rows 1 to 19 run top to bottom. Arrow keys and Q/E move focus; Enter selects a hex. Drag to pan. Overview shows the map; Fit spell shows its full area." onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={event=>{drag.current=null;if(event.currentTarget.hasPointerCapture(event.pointerId))event.currentTarget.releasePointerCapture(event.pointerId)}} onPointerCancel={()=>{drag.current=null;dragged.current=false}} onPointerLeave={event=>{if(!event.currentTarget.hasPointerCapture(event.pointerId)){drag.current=null;if(event.pointerType==='mouse')previewCell(null)}}}>
        <defs><pattern id={`${instance}-stone`} width="22" height="12" patternUnits="userSpaceOnUse"><path d="M0 0H22M0 12H22M11 0V6M0 6H22M3 6v6M20 6v6" fill="none" stroke="#5b472a" strokeWidth="1" opacity=".35"/></pattern><pattern id={`${instance}-ground`} width="96" height="48" patternUnits="userSpaceOnUse"><path d="M8 16h3v2H8M59 34h2v2h-2M31 39h5M83 11h3" fill="#8c7546" stroke="#8c7546" strokeWidth="1" opacity=".14"/></pattern><pattern id={`${instance}-area`} width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><path d="M0 0V10" stroke="#2c2519" strokeWidth="2" opacity=".5"/></pattern></defs>
        <rect x={bounds.left} y={bounds.top} width={bounds.right-bounds.left} height={bounds.bottom-bounds.top} fill={`url(#${instance}-ground)`}/><IslandTrim state={state}/>
        {state.cells.slice().sort((a,b)=>ground(a).y-ground(b).y||ground(a).x-ground(b).x).map(finalCell=>{
          const cell=beforeImpact?previousState?.cells.find(entry=>same(entry,finalCell))||finalCell:finalCell;
          const at=top(cell,state),base=ground(cell),surface=terrainStyle(isIce(cell)?'ice':cell.terrain),substrate=biomeColors[cell.biome],field=hasField(cell),occupant=livingUnits.find(unit=>same(unit,cell)),isLegal=legal.has(key(cell));
          const cliffBottom=(base.y-at.y)/TILE_SCALE+29;
          return <g key={key(cell)} data-biome={cell.biome} data-field={field?cell.terrain:undefined}>
            <g aria-hidden="true" pointerEvents="none" shapeRendering="crispEdges" transform={`translate(${at.x} ${at.y}) scale(${TILE_SCALE})`}>
              <path d={`M-44 14L0 30 44 14V${cliffBottom-10}L0 ${cliffBottom+6} -44 ${cliffBottom-10}Z`} fill={cell.height?'#b49a63':'#7c8150'} stroke={cell.height?'#665537':'#697345'} strokeWidth="1"/>
              <path d={`M0 30L44 14V${cliffBottom-10}L0 ${cliffBottom+6}Z`} fill={cell.height?'#8b7146':'#687348'} stroke={cell.height?'#75613f':'#657044'} strokeWidth="1"/>
              {cell.height>0&&<path d={`M-44 14L0 30 44 14V${cliffBottom-10}L0 ${cliffBottom+6} -44 ${cliffBottom-10}Z`} fill={`url(#${instance}-stone)`}/>}
              <g><polygon points={silhouette} fill={cell.biome==='plain'?['#8e9c59','#929f5c','#899854'][Math.abs(cell.q*13+cell.r*7)%3]:substrate.top} stroke={cell.biome==='plain'?'#6b7949':'#5b6342'} strokeWidth="1"/><path d="M-36-14-20-20-8-24 0-26 8-24 20-20 36-14" fill="none" stroke={cell.biome==='plain'?'#bbc887':substrate.mark} strokeWidth="1" opacity=".5"/><path d="M-39 13-27 17-16 21-3 25H4l13-4 12-4 10-4" fill="none" stroke={substrate.shade} strokeWidth="1" opacity=".65"/>
                {field&&<polygon className="px-field-tint" points={silhouette} fill={surface.top} fillOpacity=".38" stroke={surface.mark} strokeWidth="2" strokeDasharray="4 3"/>}
                <ElementSurface cell={cell} animate={zoom&&!activeResolution}/>{!cell.well&&<PixelBiome biome={cell.biome} seed={(cell.q+9)*13+cell.r+9}/>}
                {cell.height===1&&<><path d="M-24-3h12v-3H5v4H19v4H7v3H-11V1h-13Z" fill="#c5b580" stroke="#807045" strokeWidth="1"/><path d="M-15-3v6M1-5v8M9-1v5" stroke="#897449" strokeWidth="1"/><path d="M29 5h6V2h5v7h-5v3h-6Z" fill="#e4cd90" stroke="#776440" strokeWidth="1"/></>}
                {cell.well&&(()=>{const holder=(beforeImpact&&previousState?previousState.units:state.units).find(unit=>alive(unit)&&same(unit,cell));return <PixelWell owner={holder?.owner} occupied={!!holder}/>})()}
                {!isIce(cell)&&cell.terrain!=='plain'&&(field||cell.biome==='earth'||cell.biome==='water')&&<g className="px-field-rune" style={{color:surface.mark}} opacity={occupant||cell.well?0.56:0.85}><PixelRune terrain={isIce(cell)?'black_ice':cell.terrain}/></g>}
                {(cell.barrier||0)>0&&<g className="px-terrain-barrier"><path d="M-29 7v-18h10v-8h13v12H6v-15h12v10h10V7Z" fill="#bda371" stroke="#4e3e27" strokeWidth="2"/><path d="M-26-9h6M-15-17h8M8-20h8M19-10h7" stroke="#f2dda2" strokeWidth="3"/><path d="M-25 0h14M11-7V5M18-2h8" stroke="#876c41" strokeWidth="2"/></g>}
                {cell.terrain!=='plain'&&cell.ttl!==undefined&&Array.from({length:Math.min(4,cell.ttl)},(_,index)=><rect key={index} x={-3*Math.min(4,cell.ttl!)+index*6} y="27" width="4" height="2" fill={surface.mark}/>)}
                {isLegal&&<><polygon className={`px-target px-target-${kind}`} points={silhouette} fill={kind==='move'?'#277c79':'#efc657'} fillOpacity=".08" stroke={kind==='move'?'#277c79':'#9c6519'} strokeOpacity=".5" strokeWidth="1"/>{!occupant&&<circle className="px-range-dot" cy="8" r="3" fill={kind==='move'?'#1c5e5c':'#6b4619'} stroke="#fff3ce" strokeWidth="1.2"/>}</>}
                {affected.has(key(cell))&&<><polygon className="px-area-preview" points={silhouette} fill={spellColor(spellId,selectedUnit?champion(selectedUnit.championId).element:'light')} fillOpacity=".25" stroke="#fff3ce" strokeWidth="4"/><polygon points={silhouette} fill={`url(#${instance}-area)`} stroke="#2c2519" strokeWidth="2"/></>}
                {activeResolution&&castAreas.filter(cast=>cast.cells.some(point=>same(point,cell))).map(({event},index)=><g key={`${event.unitId}-${index}`} className="px-spell-impact" data-cast-unit={event.unitId} data-cast-spell={event.spellId} data-effect-cell={key(cell)} style={{'--px-cast-color':spellColor(event.spellId,'light'),'--px-impact-delay':`${PHASE_MS.impact}ms`} as CSSProperties}><polygon className="px-impact-fill" points={silhouette} fill="var(--px-cast-color)"/><polygon className="px-impact-edge" points={silhouette} fill="none" stroke="#fff3ce" strokeWidth="3"/><ElementImpact element={getSpell(event.spellId!).element} ice={!!getSpell(event.spellId!).freeze} branch={getSpell(event.spellId!).level>=3?getSpell(event.spellId!).branch:undefined}/></g>)}
              </g>
            </g>
            {visibleUnits.filter(unit=>same(unit,cell)).map(unitFigure)}
          </g>;
        })}
        <g className="px-bars" aria-hidden="true" pointerEvents="none">{visibleUnits.map(unit=>{
          const at=top(unit,state),old=previousState?.units.find(entry=>entry.id===unit.id&&alive(entry)),before=old&&previousState?top(old,previousState):at,shown=beforeImpact&&old?old:unit;
          const move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id),mid=move?.to?top(move.to,state):push?.from?top(push.from,state):at;
          const motion={'--px-dx':`${before.x-at.x}px`,'--px-dy':`${before.y-at.y}px`,'--px-mid-dx':`${mid.x-at.x}px`,'--px-mid-dy':`${mid.y-at.y}px`} as CSSProperties;
          return <g key={unit.id} transform={`translate(${at.x} ${at.y+20})`}><g key={eventKey} className={activeResolution&&(move||push)?'px-unit-moving':''} style={activeResolution?motions.get(unit.id)?.style||motion:undefined}><rect x="-33" y="-5" width="66" height="10" fill="#f8edcf" stroke="#2c2519" strokeWidth="1.5"/><rect x="-30" y="-2" width={Math.max(0,60*shown.hp/shown.maxHp)} height="4" fill={teamColors[unit.owner]}/>{Array.from({length:shown.maxHp-1},(_,i)=><path key={i} d={`M${-30+60*(i+1)/shown.maxHp} -2v4`} stroke="#f8edcf" strokeWidth="1"/>)}<rect x="-31" y="7" width="62" height="3" fill="#514530"/><rect x="-31" y="7" width={Math.max(0,62*shown.flux/shown.maxFlux)} height="3" fill="#e2ae38"/></g></g>;
        })}</g>
        <g className="px-well-values" aria-hidden="true" pointerEvents="none">{state.cells.filter(cell=>cell.well).map(cell=>{
          const shown=beforeImpact?previousState?.cells.find(entry=>same(entry,cell))||cell:cell,at=top(cell,state),owner=(beforeImpact&&previousState?previousState.units:state.units).find(unit=>alive(unit)&&same(unit,cell))?.owner;
          return <g key={key(cell)} className="px-well-badge" data-well={key(cell)} data-owner={owner??'neutral'} transform={`translate(${at.x+(tacticalOverview?0:48)} ${at.y+(tacticalOverview?13*screenScale:36)}) scale(${screenScale})`}><path d="M-13-9H13v3h3V6h-3v3H-13V6h-3V-6h3Z" fill={owner===undefined?'#fff0bc':teamColors[owner]} stroke={owner===undefined?'#705321':'#fff3ce'} strokeWidth="1.5"/><text y="4" fill={owner===undefined?'#4c3c22':'#fff3ce'}>+{wellValue(shown)}</text></g>;
        })}</g>
        {tacticalOverview&&<g className="px-overview-units" aria-hidden="true" pointerEvents="none">{visibleUnits.map(unit=>{
          const old=previousState?.units.find(entry=>entry.id===unit.id&&alive(entry)),move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id);
          const point=activeResolution&&phase==='move'&&old?old:activeResolution&&phase==='cast'?(move?.to||push?.from||unit):unit,at=top(point,state),number=state.units.filter(entry=>entry.owner===unit.owner).findIndex(entry=>entry.id===unit.id)+1;
          return <g key={unit.id} data-unit-marker={unit.id} transform={`translate(${at.x} ${at.y-11*screenScale}) scale(${screenScale})`}><path d={unit.owner===player?'M-8-9H8l3 3V6L8 9H-8l-3-3V-6Z':'M0-12 12 0 0 12-12 0Z'} fill={teamColors[unit.owner]} stroke={unit.id===selected?'#f9d45f':'#fff3ce'} strokeWidth={unit.id===selected?2.5:1.5}/><text y="4" fill="#fff3ce">{number}</text></g>;
        })}</g>}
        {hoverRoute&&selectedUnit&&<g aria-hidden="true" pointerEvents="none" data-route-effort={hoverEffort} data-route-hexes={hoverRoute.length}><polyline className="px-v8-route-hover" points={[selectedUnit,...hoverRoute].map(point=>{const p=top(point,state);return `${p.x},${p.y}`}).join(' ')}/><polyline className="px-v8-route-ink" points={[selectedUnit,...hoverRoute].map(point=>{const p=top(point,state);return `${p.x},${p.y}`}).join(' ')}/>{hoverRoute.some(isIce)&&(()=>{const p=top(hoverRoute[hoverRoute.length-1],state);return <path className="px-v8-slide-stop" transform={`translate(${p.x} ${p.y})`} d="M-9-6H9V6H-9ZM-4-9V9M4-9V9"/>})()}</g>}
        <g className="px-orders" aria-hidden="true" pointerEvents="none">{orders.map(order=>{const unit=livingUnits.find(entry=>entry.id===order.unitId);if(!unit)return null;const destination=top(order.move||unit,state),number=ownUnits.findIndex(entry=>entry.id===unit.id)+1,color=spellColor(order.spellId,champion(unit.championId).element);const route=[unit,...(order.move?movementPath(state,unit.id,order.move)||[order.move]:[])].map(point=>top(point,state));return <g key={unit.id}>
          {order.move&&<><polyline className="px-move-path-shadow" points={route.map(point=>`${point.x},${point.y}`).join(' ')}/><polyline className="px-move-path" points={route.map(point=>`${point.x},${point.y}`).join(' ')}/><g transform={`translate(${destination.x} ${destination.y})`}><path d="M-20-4-10-10h20l10 6v8l-10 6h-20l-10-6Z" fill="#fff3ce" fillOpacity=".4" stroke="#1c5e5c" strokeWidth="2" strokeDasharray="4 3"/><text className="px-order-number" y="4">{number}</text></g></>}
          {order.cast&&(()=>{const target=top(order.cast!,state);return <><path className="px-cast-path" d={`M${destination.x} ${destination.y-18}Q${(destination.x+target.x)/2} ${Math.min(destination.y,target.y)-65} ${target.x} ${target.y-4}`} stroke={color}/><g transform={`translate(${target.x} ${target.y})`} stroke={color} fill="none" strokeWidth="2"><path d="M-23-5v-7h10M23-5v-7H13M-23 5v7h10M23 5v7H13"/><path d="M-5 0H5M0-4V4"/><text className="px-order-number" x="26" y="-15" stroke="none" fill={color}>{number}</text></g></>})()}
        </g>})}</g>
        {canInteract&&aimTarget&&<g className="px-aim-reticle" aria-hidden="true" pointerEvents="none" transform={`translate(${top(aimTarget,state).x} ${top(aimTarget,state).y})`}><path d="M-31-6v-11h14M31-6v-11H17M-31 6v11h14M31 6v11H17" fill="none" stroke="#fff3ce" strokeWidth="7"/><path d="M-31-6v-11h14M31-6v-11H17M-31 6v11h14M31 6v11H17" fill="none" stroke="#2c2519" strokeWidth="3"/><path d="M-6 0H6M0-5V5" stroke="#2c2519" strokeWidth="2"/></g>}
        {activeResolution&&<g key={`effects-${eventKey}`} className="px-resolution" aria-hidden="true" pointerEvents="none">{events.map((event,index)=>{
          const point=eventCell(event,state,previousState);if(!point)return null;const at=top(point,state),unit=state.units.find(entry=>entry.id===event.unitId),element=event.elements?.[0]||unit&&champion(unit.championId).element||'light',color=elementColors[element]||'#ead4a0';
          const style={'--px-event-delay':`${eventDelayMs(event)}ms`,'--px-effect':color} as CSSProperties;
          if(event.kind==='cast'){const start=event.from||unit;if(!start)return null;const origin=top(start,state),shape=event.spellId?getSpell(event.spellId).shape:'single';return <g key={index} className={`px-cast-event px-element-${element}`} style={style}>{!same(start,point)&&<ElementProjectile from={{x:origin.x,y:origin.y-42}} to={{x:at.x,y:at.y-10}} element={element} shape={shape} branch={event.spellId&&getSpell(event.spellId).level>=3?getSpell(event.spellId).branch:undefined} delayMs={eventDelayMs(event)}/>}<g transform={`translate(${origin.x} ${origin.y-44})`} className="px-cast-source" style={{color}}><PixelRune terrain={element}/></g><g className="px-v8-arrival" transform={`translate(${at.x} ${at.y-6})`} style={{color}}><PixelRune terrain={element}/></g><g transform={`translate(${at.x} ${at.y})`} className="px-impact-pixels px-v8-arrival" fill={color}>{Array.from({length:8},(_,i)=><rect key={i} x={Math.round(Math.cos(i*Math.PI/4)*30)-3} y={Math.round(Math.sin(i*Math.PI/4)*20)-3} width="6" height="6"/>)}</g></g>}
          if(event.kind==='reaction'){const reactions=state.cells.find(cell=>same(cell,point))?.reactions,labels=reactions?.length?reactions.map(id=>terrainStyle(id).name):[terrainStyle(event.terrain||'steam').name];return <g key={index} transform={`translate(${at.x} ${at.y})`} style={style}><g className="px-reaction-burst"><path d="M-35-4h12v-12h11v-14H0v10h14v-10h10v20h15V4H24v14H8v12H-5V18H-20V7H-35Z" fill={terrainStyle(event.terrain||'steam').top||color} stroke="#2c2519" strokeWidth="3"/><g style={{color:terrainStyle(event.terrain||'steam').mark}}><PixelRune terrain={event.terrain||'steam'}/></g></g>{reactionLabels.has(index)&&<text className="px-event-text px-reaction-text" y="39"><tspan x="0">{labels[0].toUpperCase()}{reactionLabels.get(index)!>1?` ×${reactionLabels.get(index)}`:''}</tspan>{labels.length>1&&<tspan x="0" dy="16">+ {labels[1].toUpperCase()}{labels.length>2?` +${labels.length-2}`:''}</tspan>}</text>}</g>}
          if(['damage','heal','surface','bounce','fizzle','guard','defeat','respawn'].includes(event.kind)){if(event.kind==='surface'&&!event.unitId&&!surfaceLabels.has(index))return null;const lane=labelLanes.get(index);if(!lane)return null;const surfaceLabel=surfaceEventLabel(event,surfaceLabels.get(index));const label=lane.overflow?`+${lane.overflow} updates`:event.kind==='damage'?`−${event.amount||0}`:event.kind==='heal'?`+${event.amount||0}`:event.kind==='surface'?surfaceLabel:event.kind==='bounce'?'BLOCKED':event.kind==='fizzle'?'FIZZLE':event.kind==='guard'?'GUARD':event.kind==='defeat'?'FALLEN':'RETURN';return <g key={index} transform={`translate(${at.x} ${at.y-Math.max(70,screenScale*28)}) scale(${Math.max(1,screenScale*.8)})`} style={style}><text className={`px-event-text px-event-${event.kind}${event.kind==='surface'&&event.amount===undefined?' px-event-status':''}`} y={-lane.row*20}>{label}</text></g>}
          if(event.kind==='push'&&event.from){const origin=top(event.from,state);return <g key={index} className="px-cast-event" style={style}><path d={`M${origin.x} ${origin.y}L${at.x} ${at.y}`} fill="none" stroke="#fff3ce" strokeWidth="8" strokeDasharray="4 7"/><path d={`M${origin.x} ${origin.y}L${at.x} ${at.y}`} fill="none" stroke="#53612d" strokeWidth="4" strokeDasharray="4 7"/></g>}
          return null;
        })}</g>}
        <g className="px-tile-references" aria-hidden="true" pointerEvents="none">{[...tileReferences.values()].map(({point,active})=>{
          const at=top(point,state);return <g key={key(point)} data-tile-reference={formatTile(point)} data-active={active||undefined} transform={`translate(${at.x} ${at.y+43}) scale(${screenScale})`}><rect x="-17" y="-8" width="34" height="16" rx="2" fill={active?'#fff3ce':'#ecedd9'} stroke={active?'#2c2519':'#1c5e5c'} strokeWidth="1"/><text y="4" textAnchor="middle" fill="#2c2519" style={{font:'700 11px/1 Arial,sans-serif'}}>{formatTile(point)}</text></g>;
        })}</g>
        {/* Ground targets sit above tall sprite hitboxes so taps select the visible hex. */}
        <g className="px-cell-interactions">{state.cells.slice().sort((a,b)=>ground(a).y-ground(b).y||ground(a).x-ground(b).x).map(finalCell=>{
          const cell=beforeImpact?previousState?.cells.find(entry=>same(entry,finalCell))||finalCell:finalCell;
          const at=top(cell,state),occupant=livingUnits.find(unit=>same(unit,cell)),isLegal=legal.has(key(cell));
          const cellStatuses=occupant?statusEntries(occupant).map(([id,status])=>`${statusInfo(id)?.name||id}, ${status?.turns} rounds`).join('; '):'';
          const label=`${formatTile(cell)}. ${BIOME_NAMES[cell.biome]}. ${biomeRule(cell)}.${surfaceTraits(cell).map(trait=>` ${trait.name}: ${trait.description}`).join('')}${hasField(cell)?` Field: ${fieldName(cell)}${cell.ttl?`, ${cell.ttl} round${cell.ttl===1?'':'s'}`:''}.`:''}${cell.well?` Well: +${wellValue(cell)} point${wellValue(cell)===1?'':'s'} if occupied after the exchange.`:''}${cell.barrier?` Barrier ${cell.barrier}. Blocks movement and sight.`:''}${occupant?` ${champion(occupant.championId).name}, ${occupant.owner===player?'your company':'rival'}, ${occupant.hp} of ${occupant.maxHp} health, ${occupant.flux} Flux.${cellStatuses?' '+cellStatuses+'.':''}`:''}${isLegal?` Available ${kind} target.`:''}`;
          return <g key={key(cell)} ref={node=>{if(node)refs.current.set(key(cell),node);else refs.current.delete(key(cell))}} role="button" data-tile={formatTile(cell)} tabIndex={focused===key(cell)?0:-1} aria-label={label} aria-disabled={!canInteract} className="px-cell-hit" onKeyDown={event=>onKey(event,cell)} onFocus={()=>{setFocused(key(cell));previewCell(cell)}} onBlur={()=>previewCell(null)} onPointerEnter={event=>{if(event.pointerType==='mouse'&&!drag.current?.moved)previewCell(cell)}} onClick={()=>choose(cell)}><title>{label}</title><polygon points={hexPolygon(at.x,at.y)} fill="transparent"/><polygon className="px-focus-ring" points={hexPolygon(at.x,at.y,3)} fill="none"/></g>;
        })}</g>
      </svg>
      {activeResolution&&<div className="px-phase" aria-live="polite">{phase==='move'?'MOVEMENT':phase==='cast'?'SPELLS':phase==='impact'?'REACTIONS':'AFTERMATH'}{phase==='settle'&&scoreEvents.length>0&&<span className="px-score-feedback">{scoreEvents.map(event=>`${event.owner===player?'You':'Rival'} +${event.amount||0} from wells`).join(' · ')}</span>}</div>}
    </div>
    {zoom&&panControls&&<div className="px-pan" aria-label="Pan the battlefield"><button type="button" aria-label="Pan left" onClick={()=>setCamera(at=>clampCamera({...at,x:at.x-TILE_STEP_X}))}>←</button><button type="button" aria-label="Pan up" onClick={()=>setCamera(at=>clampCamera({...at,y:at.y-TILE_STEP_Y}))}>↑</button><button type="button" aria-label="Center selected champion" onClick={focusView}>◎</button><button type="button" aria-label="Pan down" onClick={()=>setCamera(at=>clampCamera({...at,y:at.y+TILE_STEP_Y}))}>↓</button><button type="button" aria-label="Pan right" onClick={()=>setCamera(at=>clampCamera({...at,x:at.x+TILE_STEP_X}))}>→</button></div>}
    {activeCell&&<div className="px-board-readout"><span className="px-cell-description"><b>{formatTile(activeCell)} · {BIOME_NAMES[activeCell.biome]}{activeCell.well?` · Well +${wellValue(activeCell)}`:''}{hasField(activeCell)?` · ${fieldName(activeCell)}`:''}</b><span>{[surfaceBrief(activeCell),terrainBrief(activeCell),hoverEffort!==null?`${hoverEffort} movement${hoverRoute?.some(isIce)?' · includes slide':''}`:'',activeCell.barrier?`Barrier ${activeCell.barrier}`:'',hasField(activeCell)&&activeCell.ttl?`${activeCell.ttl} round${activeCell.ttl===1?'':'s'} left`:'',activeUnit?`${champion(activeUnit.championId).name} · ${activeUnit.hp}/${activeUnit.maxHp} HP`:'',activeUnit?statusEntries(activeUnit).map(([id,status])=>`${statusInfo(id)?.name||id} ${status?.turns}`).join(' · '):''].filter(Boolean).join(' · ')}</span></span></div>}
    <p className="px-sr-only">Your team is {player===0?'teal':'rust'}; rivals are {player===0?'rust':'teal'}. Team bars show health; gold bars show Flux. Dots mark available targets; hatching marks the spell area; brackets mark aim. Dashed paths show planned moves; curves show spells. Both teams act together: targets can move and landings can be blocked. Champion details show status durations.</p>
  </div>;
}
