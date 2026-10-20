"use client";

import {useEffect,useId,useMemo,useRef,useState,type CSSProperties,type KeyboardEvent,type PointerEvent} from 'react';
import type {PlaybackClockV44} from '../../lib/playback-clock-v44';
import usePlaybackAnimationsV44 from './usePlaybackAnimationsV44';
import {CHAMPIONS} from '../../lib/roster-v11';
import {combinationFor} from '../../lib/combinations-v16';
import {fieldCombination,fieldEffects} from '../../lib/tactics-v16';
import {inhabitantIntents} from '../../lib/inhabitants-v16';
import {exposedCliffs,worldProps,WORLD_PROP_ATLAS,WORLD_SURFACES} from '../../lib/living-world-v16';
import {CRISP_SURFACE_ATLAS,REACTIVE_PROP_ATLAS,reactivePropFrame,terrainEdges,terrainMaterial,terrainTransition} from '../../lib/reactive-environment-v17';
import {TerrainMaterialArt} from './ReactiveTerrainV17';
import {EndgameTile,EndgameBorders} from './EndgameTerrainV18';
import type {EndgameForecast} from '../../lib/endgame-v18';
import {endgameBoundaries,endgameCellDescription} from '../../lib/endgame-presentation-v18';
import ElementalCreature from './ElementalCreatureV16';
import '../living-world-v13.css';
import {isIce,isFlooded,surfaceTraits,movementPath,spellArea as baseSpellArea,terrainCover,isCellSolid,STATUS_DEFINITIONS,REACTIONS,reactionsFor,cellElements,type Point,type SimState,type SimEvent,type TeamPlan} from '../../lib/tactics-v16';
import {getSpell as baseGetSpell,effectiveSpell as baseEffectiveSpell,availableSpellIds} from '../../lib/spells-v16';
import {castAvailability,validatePlan} from '../../lib/tactics-v16';
import {projectedVolley as baseProjectedVolley} from '../../lib/planned-volley-v16';
import {spellEffectLabel} from '../../lib/battle-guidance-v16';
import {planningCamera} from '../../lib/planning-camera-v16';
import type {PlanningForecast} from '../../lib/planning-forecast-v16';
import {visibleStatusStack,screenFacing as facing,resolutionFacing} from '../../lib/battlefield-clarity-v16';
import {movementPreview,movementRisks} from '../../lib/movement-preview-v16';
import {actualHealthFeedback} from '../../lib/health-feedback-v16';
import {groundContacts} from '../../lib/combat-life-v16';
import './combat-life-v13.css';
import '../experience-v13.css';
import './battlefield-clarity-v13.css';
import {BIOME_NAMES,biomeElement,type Biome} from '../../lib/arena-v7';
import {RESOLUTION_MS,PHASE_MS,CAST_POSE_MS,CAST_ANTICIPATION_MS,EVENT_TEXT_MS,eventDelayMs,projectileMeetingMs,type ResolutionPhase} from '../../lib/feedback-v16';
import PixelChampion,{type PixelAction} from './PixelChampion';
import ChampionFrames from './ChampionFrames';
import CombatCreature from './CombatCreatureV19';
import {getCreature} from '../../lib/campaign-creatures-v19';
import {ANIMATED_CHARACTER_IDS} from '../../lib/animation-assets';
import './pixel-battlefield.css';
import './pixel-battlefield-v7.css';
import './pixel-battlefield-v8.css';
import './combat-pacing-v16.css';
import {ElementImpact,ElementSurface,ElementProjectile,ElementClash,ElementWake,ElementTeamLink} from './ElementEffectsV16';
import {fieldRegions,projectileReadabilityScale} from '../../lib/element-clarity-v22';
import './element-clarity-v22.css';
import {flightPoint,effectAccentCells,healthBarTicks,conditionChanges} from '../../lib/combat-clarity-v23';
import CombatCallout from './CombatCalloutV23';
import './combat-clarity-v23.css';
import {rangeBoundaryPath} from '../../lib/range-outline-v16';
import {interceptionFieldArea} from '../../lib/projectile-interception-v16';
import {battlefieldMotion} from '../../lib/battlefield-motion-v16';
import {canonicalMotionSnapshot,movementAdviceText,resolutionActorIds} from '../../lib/battlefield-presentation-v17';
import {formatTile as boardTile} from '../../lib/board-labels-v17';
import {TILE_SCALE,TILE_STEP_X,TILE_STEP_Y,SPRITE_SIZE,groundPoint,surfacePoint,battlefieldBounds,hexPolygon,focusViewSize,clampCamera as clampView,fitEffect,type ScreenPoint} from '../../lib/battlefield-geometry';
import {solidFootprints,terrainEffectDescription,groundEdges,worldFringe,sceneryOpacity} from '../../lib/world-readability-v24';
import {GroundDetailsV24,SolidTerrainV24,CliffArtV24} from './CraftedWorldV24';
import {statusInsight,activeStatusInsights} from '../../lib/battle-inspection-v24';
import {BattleInsight,CombatVitals} from './BattleInsightV24';
import type {EnemyThreatPreview} from '../../lib/enemy-threat-v42';
import EnemyThreatOverlayV42 from './EnemyThreatOverlayV42';
import {enemyRangeSubject} from '../../lib/enemy-range-subject-v42';
import FocusedAreaV42 from './FocusedAreaV42';
import {profileSpell,focusZone,type FocusedSpell} from '../../lib/spell-profile-v42';
import {fullyBlockedFighters} from '../../lib/protection-feedback-v44';
import {exchangeReaction,reactionOnCooldown,type SpeechRect} from '../../lib/character-reactions-v45';
import {planningMaterialCells} from '../../lib/planning-material-v45';
import CharacterSpeechV45 from './CharacterSpeechV45';
import PlanningElementV45 from './PlanningElementV45';

export type BattlefieldSpellRules={getSpell:typeof baseGetSpell;effectiveSpell:typeof baseEffectiveSpell;spellArea:typeof baseSpellArea;projectedVolley:typeof baseProjectedVolley;spellForCast?:(state:SimState,unitId:string,spellId:string,scroll?:boolean)=>FocusedSpell};
type Props = {enemyThreat?:(unitId:string)=>EnemyThreatPreview|null;previewEnemyId?:string|null;spellRules?:BattlefieldSpellRules;state:SimState;plan:TeamPlan;player:0|1;selected:string|null;kind:'move'|'cast';onCell:(q:number,r:number)=>void;onInspectUnit?:(id:string)=>void;interactive:boolean;previousState?:SimState;resolving?:boolean;onReplayChange?:(active:boolean)=>void;playback?:{phase:ResolutionPhase;active:boolean;key:number;clock?:PlaybackClockV44};onReplay?:()=>void;legalTargets?:Point[];showOrders?:boolean;spellId?:string;affectedTargets?:Point[];aimTarget?:Point;forecast?:PlanningForecast|null;onPreviewCell?:(point:Point|null)=>void;focusRequest?:number;unitPresentation?:Readonly<Record<string,{color:string;label:string;name?:string;creatureId?:string}>>;deploymentZones?:readonly {label:string;color:string;tiles:readonly Point[]}[];boardRadius?:number;presentationOnlyRules?:boolean;controllableUnitIds?:readonly string[];sharedAlliedOrders?:boolean;endgameZone?:EndgameForecast;previousEndgameZone?:EndgameForecast};
type Unit = SimState['units'][number];
const key=(point:Point)=>`${point.q},${point.r}`;
const same=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
const alive=(unit:Unit)=>unit.hp>0&&unit.respawn===undefined;
const wellValue=(cell:SimState['cells'][number])=>1+(fieldEffects(cell).wellBonus??0);
const champion=(id:string)=>CHAMPIONS.find(entry=>entry.id===id)!;
const teamColors=['#176f76','#a94230'];
const elementColors:Record<string,string>={fire:'#e66a1f',water:'#238dc2',air:'#739c32',earth:'#967039',light:'#e4ab1f',dark:'#8050bb'};
const terrainColors:Record<string,{top:string;shade:string;mark:string;name:string}>={
  ice:{top:'#b5d8d6',shade:'#66919b',mark:'#376b83',name:'Ice'},
  plain:{top:'#718840',shade:'#465e2d',mark:'#30472b',name:'Meadow'},
  water:{top:'#287d86',shade:'#285664',mark:'#d2ebc8',name:'Water'},
  fire:{top:'#ce9b5b',shade:'#a26c37',mark:'#9d3c15',name:'Fire'},
  earth:{top:'#b9965b',shade:'#81623b',mark:'#503c29',name:'Earth'},
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
const biomeColors:Record<Biome,{top:string;shade:string;mark:string}>={plain:terrainColors.plain,earth:terrainColors.earth,water:terrainColors.water,forest:{top:'#526d33',shade:'#344c2c',mark:'#9bac59'},marsh:{top:'#587f62',shade:'#365b4b',mark:'#c9dab0'},ruins:{top:'#a59464',shade:'#776746',mark:'#4a452f'}};
const hasField=(cell:SimState['cells'][number])=>cell.ttl!==undefined||cell.terrain!==biomeElement(cell.biome);
function biomeRule(cell:SimState['cells'][number]) {
  if(cell.biome==='ruins'&&isCellSolid(cell))return 'Earth base · blocks movement and sight';
  if(cell.biome==='forest')return 'Earth base · forest absorbs 1 nonpiercing spell damage';
  if(cell.biome==='marsh')return 'Water base · entry costs 2 movement';
  if(cell.height)return 'Earth base · climb costs 2 · +1 spell reach downhill';
  return cell.biome==='water'?'Water base · normal movement':'Normal movement';
}
const fieldName=(cell:SimState['cells'][number])=>[isIce(cell)?'Ice':isFlooded(cell)?'Flood':null,cell.reactions?.length?cell.reactions.map(id=>terrainStyle(id).name).join(' + '):isIce(cell)||isFlooded(cell)?null:terrainStyle(cell.terrain).name].filter(Boolean).join(' · ');
const ground=groundPoint;
const top=(point:Point,state:SimState):ScreenPoint=>surfacePoint(point,state.cells.find(cell=>same(cell,point))?.height||0);
const silhouette='0,-30 44,-15 44,15 0,30 -44,15 -44,-15';
const eventCell=(event:SimEvent,state:SimState,before?:SimState):Point|undefined=>event.to||(event.q!==undefined&&event.r!==undefined?{q:event.q,r:event.r}:state.units.find(unit=>unit.id===event.unitId)||before?.units.find(unit=>unit.id===event.unitId));
const statusEntries=(unit:Unit)=>Object.entries(unit.statuses||{}).filter(([,status])=>status&&status.turns>0);
function statusInfo(id:string) {const definitions=STATUS_DEFINITIONS as unknown as Record<string,{name:string;color:string;symbol:string}>|{id:string;name:string;color:string;symbol:string}[];return Array.isArray(definitions)?definitions.find(entry=>entry.id===id):definitions[id]}
function spellColor(id:string|undefined,fallback:string) {const element=id?baseGetSpell(id)?.element:undefined;return elementColors[element||'']||elementColors[fallback]||'#f4e6b9'}

function AtlasProp({frame,size=128,reactive=false}:{frame:number;size?:number;reactive?:boolean}) {const clip=`world-prop-${useId().replaceAll(':','')}`,x=frame%4*128,y=Math.floor(frame/4)*128;return <svg x={-size/2} y={-size*124/128} width={size} height={size} style={{width:size,height:size,overflow:'hidden'}} viewBox={`${x} ${y} 128 128`} overflow="hidden" aria-hidden="true"><defs><clipPath id={clip} clipPathUnits="userSpaceOnUse"><rect x={x} y={y} width="128" height="128"/></clipPath></defs><image href={reactive?REACTIVE_PROP_ATLAS:WORLD_PROP_ATLAS} width="512" height="512" clipPath={`url(#${clip})`}/></svg>}
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
  return reaction?<g>{reaction.elements.map((element,index)=>{const angle=(index/reaction.elements.length)*Math.PI*2-Math.PI/2;return <g key={element} transform={`translate(${Math.cos(angle)*15} ${Math.sin(angle)*11}) scale(.3)`} style={{color:elementColors[element]}}><PixelRune terrain={element}/></g>})}</g>:null;
}
function PixelWell({owner,occupied,color}:{owner?:number;occupied:boolean;color?:string}) {return <g shapeRendering="crispEdges">
  <path d="M-27 2v10l12 7H13l14-7V2" fill="#5c4c2f" stroke="#2c2519" strokeWidth="2"/><path d="M-25-5-12-12H12L25-5V6L13 13H-13L-25 6Z" fill="#c6ad76" stroke="#5d4a2a" strokeWidth="2"/>
  <path d="M-25-5-12-12H12L25-5 12 3H-12Z" fill="#e5d39e"/><path d="M-14-5-7-9H7L14-5 7 0H-7Z" fill="#193e42" stroke="#735c32" strokeWidth="2"/>
  <path d="M-11-4-6-7H6L11-4 6-1H-6Z" fill={color||(owner===undefined?'#39a5bf':teamColors[owner])}/><path d="M-25 1l12 7H13l12-7v4l-12 8H-13l-12-8Z" fill="#aa8b54"/>
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
export default function PixelBattlefieldV16({state,plan,player,selected,kind,onCell,onInspectUnit,interactive,previousState,resolving=false,onReplayChange,playback,onReplay,legalTargets=[],showOrders=true,spellId,affectedTargets=[],aimTarget,forecast,onPreviewCell,focusRequest=0,unitPresentation,deploymentZones=[],boardRadius=9,presentationOnlyRules=false,controllableUnitIds,sharedAlliedOrders=false,endgameZone,previousEndgameZone,spellRules,enemyThreat,previewEnemyId}:Props) {
  const instance=useId().replace(/:/g,'');
  const formatTile=(point:Point)=>boardTile(point,boardRadius);
  const unitColor=(unit:Unit)=>unitPresentation?.[unit.id]?.color||teamColors[unit.owner];
  const unitLabel=(unit:Unit)=>unitPresentation?.[unit.id]?.label||(unit.owner===player?'Your company':'Rival');
  const unitName=(unit:Unit)=>unitPresentation?.[unit.id]?.name||champion(unit.championId).name;
  const unitLineage=(unit:Unit)=>{const creatureId=unitPresentation?.[unit.id]?.creatureId;return creatureId?getCreature(creatureId).family:champion(unit.championId).race};
  const canCommand=(unit:Unit)=>unit.owner===player&&(!controllableUnitIds||controllableUnitIds.includes(unit.id));
  // Private allied orders remain uncertain. Co-op may explicitly share its drafts
  // for truthful routes and conflicts without granting control of those actors.
  const adviceState=useMemo(()=>controllableUnitIds&&!sharedAlliedOrders?{...state,units:state.units.map(unit=>unit.owner===player&&!controllableUnitIds.includes(unit.id)?{...unit,owner:(player===0?1:0) as 0|1}:unit)}:state,[state,player,controllableUnitIds,sharedAlliedOrders]);
  const motionState=useMemo(()=>canonicalMotionSnapshot(state,presentationOnlyRules),[state,presentationOnlyRules]);
  const previousMotionState=useMemo(()=>previousState?canonicalMotionSnapshot(previousState,presentationOnlyRules):undefined,[previousState,presentationOnlyRules]);
  const movementText=(text:string|undefined,point:Point)=>movementAdviceText(text,point,boardRadius);
  const [focused,setFocused]=useState('0,0');
  const [hovered,setHovered]=useState<string|null>(null);
  const [rangeFocus,setRangeFocus]=useState<string|null>(null),[pinnedEnemy,setPinnedEnemy]=useState<string|null>(null);
  const [inspecting,setInspecting]=useState(false),[inspectedNpc,setInspectedNpc]=useState<string|null>(null);
  const [inspectedUnit,setInspectedUnit]=useState<string|null>(null);
  const inspectedCharacter=state.units.find(unit=>unit.id===inspectedUnit);
  const intents=useMemo(()=>inhabitantIntents(state),[state]);
  const npc=intents.find(intent=>intent.id===inspectedNpc);
  const props=useMemo(()=>worldProps(state.cells),[state.cells]);
  const fringe=useMemo(()=>worldFringe(state.cells),[state.cells]);
  const groundRims=useMemo(()=>groundEdges(state.cells),[state.cells]);
  const cellIndex=useMemo(()=>new Map(state.cells.map(cell=>[key(cell),cell])),[state.cells]);
  const previousCellIndex=useMemo(()=>new Map(previousState?.cells.map(cell=>[key(cell),cell])||[]),[previousState?.cells]);
  const finalEdges=useMemo(()=>terrainEdges(state.cells),[state.cells]);
  const previousEdges=useMemo(()=>terrainEdges(previousState?.cells||state.cells),[previousState?.cells,state.cells]);
  const finalSolids=useMemo(()=>solidFootprints(state.cells),[state.cells]);
  const previousSolids=useMemo(()=>solidFootprints(previousState?.cells||state.cells),[previousState?.cells,state.cells]);
  const finalFields=useMemo(()=>fieldRegions(state.cells),[state.cells]);
  const previousFields=useMemo(()=>fieldRegions(previousState?.cells||state.cells),[previousState?.cells,state.cells]);
  const [zoom,setZoom]=useState(false);
  const [viewport,setViewport]=useState({width:960,height:500});
  const [viewportReady,setViewportReady]=useState(false);
  const [detailScale,setDetailScale]=useState(1);
  const [panControls,setPanControls]=useState(false);
  const [camera,setCamera]=useState({x:450,y:290});
  const [replay,setReplay]=useState(0);
  const [replaying,setReplaying]=useState(false);
  const [internalPhase,setPhase]=useState<ResolutionPhase>('settle');
  const [revealedClashes,setRevealedClashes]=useState<number[]>([]);
  const speechHistory=useRef(new Map<string,number>());
  const speechRound=useRef(state.round);
  useEffect(()=>{if(state.round<speechRound.current)speechHistory.current.clear();speechRound.current=state.round},[state.round]);
  const replayCallback=useRef(onReplayChange);
  replayCallback.current=onReplayChange;
  const svgRef=useRef<SVGSVGElement|null>(null);
  const refs=useRef(new Map<string,SVGGElement>());
  const drag=useRef<{x:number;y:number;camera:ScreenPoint;moved:boolean}|null>(null);
  const dragged=useRef(false);
  const initialCamera=useRef(false);
  const initialPlanningView=useRef(false);
  const returnCamera=useRef<{camera:ScreenPoint;scale:number;zoom:boolean}|null>(null);
  const pendingFocus=useRef(false);
  const getSpell=spellRules?.getSpell??baseGetSpell,effectiveSpell=spellRules?.effectiveSpell??baseEffectiveSpell,spellArea=spellRules?.spellArea??baseSpellArea,projectedVolley=spellRules?.projectedVolley??baseProjectedVolley;
  const spellForCast=(snapshot:SimState,unitId:string,id:string,scroll?:boolean):FocusedSpell=>{
    if(spellRules?.spellForCast)return spellRules.spellForCast(snapshot,unitId,id,scroll);
    const actor=snapshot.units.find(unit=>unit.id===unitId);
    return profileSpell(actor?effectiveSpell(actor.championId,id,actor.affinities):getSpell(id),snapshot.spellModel);
  };
  const spellColor=(id:string|undefined,fallback:string)=>{const element=id?getSpell(id).element:undefined;return elementColors[element||'']||elementColors[fallback]||'#f4e6b9'};
  const activeResolution=playback?.active??(resolving||replaying);
  const phase=playback?.phase??internalPhase;
  const viewingExchange=activeResolution||!!playback&&resolving;
  const canInteract=interactive&&!viewingExchange;
  const spellFootprint=forecast?.clashes?.some(clash=>selected&&clash.participants.includes(selected))?forecast.cells:affectedTargets;
  const legal=new Set(canInteract?legalTargets.map(key):[]);
  const affected=new Set(canInteract?spellFootprint.map(key):[]);
  const ownUnits=state.units.filter(canCommand);
  const livingUnits=state.units.filter(alive);
  const selectedUnit=livingUnits.find(unit=>unit.id===selected);
  const inspectedSpell=kind==='cast'&&selectedUnit&&spellId?spellForCast(state,selectedUnit.id,spellId):null;
  const focusedSpell=canInteract&&!inspecting&&aimTarget&&inspectedSpell?.focus&&!forecast?.clashes?.some(clash=>selected&&clash.participants.includes(selected))?inspectedSpell:null;
  const events=previousState&&previousState.version!==state.version?state.lastResolution||[]:[];
  const health=useMemo(()=>actualHealthFeedback(previousState,state),[previousState,state]);
  const blockedFighters=new Set([...fullyBlockedFighters(events)].filter(id=>!health.has(id)));
  const conditions=useMemo(()=>conditionChanges(previousState,state),[previousState,state]);
  const contacts=useMemo(()=>groundContacts(previousMotionState,motionState),[previousMotionState,motionState]);
  const healthEvents:SimEvent[]=[...health].map(([unitId,change])=>({kind:change.kind,unitId,q:change.point.q,r:change.point.r,amount:Math.abs(change.delta),text:change.label}));
  const healthEventSet=new Set(healthEvents);
  const feedbackEvents=[...events.filter(event=>event.kind!=='damage'&&event.kind!=='heal'&&!(event.kind==='surface'&&event.unitId&&event.amount!==undefined)),...healthEvents];
  const clashEvents=events.filter(event=>event.kind==='clash'&&event.meeting);
  const clashAreas=clashEvents.map(event=>({event,cells:interceptionFieldArea(state.cells,{q:event.q!,r:event.r!,radius:event.radius??1})}));
  const clashedUnits=new Set(clashEvents.flatMap(event=>event.participants||[]));
  const castAreas=useMemo(()=>events.filter(event=>event.kind==='cast'&&event.unitId&&event.spellId&&event.to&&!clashedUnits.has(event.unitId)).map(event=>({event,spell:spellForCast(previousState||state,event.unitId!,event.spellId!,(event as SimEvent&{scroll?:boolean}).scroll===true),cells:spellArea(previousState||state,event.unitId!,event.spellId!,event.to!,event.from)})),[state,previousState,spellRules]);
  const castAccents=useMemo(()=>new Map(castAreas.map(({event,cells})=>[event.unitId,effectAccentCells(cells,event.to!,5)])),[castAreas]);
  const visibleUnits=state.units.filter(unit=>!(activeResolution&&phase!=='settle'&&events.some(event=>event.kind==='respawn'&&event.unitId===unit.id))&&(alive(unit)||(viewingExchange&&events.some(event=>event.kind==='defeat'&&event.unitId===unit.id))));
  const orders=showOrders&&!viewingExchange?plan.orders.filter(order=>state.units.some(unit=>unit.id===order.unitId&&unit.owner===player&&(sharedAlliedOrders||canCommand(unit))&&alive(unit))):[];
  const queuedVolley=useMemo(()=>{
    if(!showOrders||viewingExchange)return null;
    try{return projectedVolley(adviceState,player,presentationOnlyRules?{orders}:validatePlan(state,player,{orders}))}catch{return null}
  },[state,adviceState,player,plan,showOrders,viewingExchange,presentationOnlyRules]);
  const bounds=battlefieldBounds(state.cells);
  const focusSize=focusViewSize(viewport,detailScale);
  const clampCamera=(at:ScreenPoint)=>clampView(at,bounds,focusSize);
  const safeCamera=clampCamera(camera);
  const view=zoom?`${safeCamera.x-focusSize.width/2} ${safeCamera.y-focusSize.height/2} ${focusSize.width} ${focusSize.height}`:`${bounds.left} ${bounds.top} ${bounds.right-bounds.left} ${bounds.bottom-bounds.top}`;
  const screenScale=Math.max((zoom?focusSize.width:bounds.right-bounds.left)/viewport.width,(zoom?focusSize.height:bounds.bottom-bounds.top)/viewport.height);
  const viewCenter=zoom?safeCamera:{x:(bounds.left+bounds.right)/2,y:(bounds.top+bounds.bottom)/2};
  const liveMaterials=useMemo(()=>zoom&&!viewingExchange?planningMaterialCells(state.cells,{...viewCenter,width:focusSize.width,height:focusSize.height}):new Set<string>(),[state.cells,zoom,viewingExchange,viewCenter.x,viewCenter.y,focusSize.width,focusSize.height]);
  const reaction=useMemo(()=>exchangeReaction(previousState,state,player,Object.fromEntries(Object.entries(unitPresentation??{}).flatMap(([id,entry])=>entry.creatureId?[[id,getCreature(entry.creatureId).family]]:[]))),[previousState,state,player,unitPresentation]);
  const speechUnit=viewingExchange&&phase==='settle'&&reaction&&!reactionOnCooldown(reaction,state.round,speechHistory.current)?state.units.find(unit=>unit.id===reaction.unitId):undefined;
  useEffect(()=>{if(speechUnit&&reaction){speechHistory.current.set(`${reaction.unitId}:${reaction.reason}`,state.round);for(const [key,round] of speechHistory.current)if(state.round-round>=3)speechHistory.current.delete(key)}},[speechUnit?.id,reaction?.reason,state.round]);
  const speechPoint=(unit:Unit)=>{const at=top(unit,state);return {x:(at.x-viewCenter.x)/screenScale+viewport.width/2,y:(at.y-viewCenter.y)/screenScale+viewport.height/2}};
  const speechObstacles:SpeechRect[]=speechUnit?visibleUnits.flatMap(unit=>{
    const at=speechPoint(unit),calloutScale=Math.max(1/screenScale,.7),rectangles:SpeechRect[]=[{x:at.x-SPRITE_SIZE/2/screenScale,y:at.y-SPRITE_SIZE*.8125/screenScale,width:SPRITE_SIZE/screenScale,height:SPRITE_SIZE/screenScale}];
    if(health.has(unit.id)||conditions.has(unit.id)||blockedFighters.has(unit.id))rectangles.push({x:at.x-110*calloutScale,y:at.y-Math.max(148/screenScale,36)-34*calloutScale,width:220*calloutScale,height:(conditions.has(unit.id)?94:68)*calloutScale});
    return rectangles;
  }):[];
  // Focus keeps the characters and their conditions visible at every readable scale.
  const tacticalOverview=!zoom;
  const compactWorld=viewport.width<=600||viewport.height<250;
  const plannedOrigin=orders.find(order=>order.unitId===selected)?.move||selectedUnit;
  const forecastCells=new Map((canInteract&&showOrders?forecast?.cells:undefined)?.map(cell=>[key(cell),cell])??[]);
  const activeCell=state.cells.find(cell=>key(cell)===(hovered||(aimTarget?key(aimTarget):focused)));
  const activeUnit=activeCell?livingUnits.find(unit=>same(unit,activeCell)):undefined;
  const hoveredEnemy=hovered?livingUnits.find(unit=>unit.owner!==player&&key(unit)===hovered):undefined;
  const threatId=enemyRangeSubject({kind,inspecting,viewingExchange,card:previewEnemyId,hover:hoveredEnemy?.id,focus:rangeFocus,pinned:pinnedEnemy});
  const threatUnit=livingUnits.find(unit=>unit.owner!==player&&unit.id===threatId);
  const enemyRange=useMemo(()=>threatUnit&&enemyThreat?enemyThreat(threatUnit.id):null,[enemyThreat,threatUnit?.id]);
  const selectedMovement=useMemo(()=>showOrders&&!viewingExchange?movementPreview(adviceState,player,plan,selected):null,[adviceState,player,plan,selected,showOrders,viewingExchange]);
  const legalTargetKey=legalTargets.map(key).join('|');
  const rangeEdge=canInteract&&!inspecting&&!(enemyRange&&kind==='move')?rangeBoundaryPath(legalTargets,point=>state.cells.find(cell=>same(cell,point))?.height||0):'';
  const effectEdge=canInteract&&!inspecting?rangeBoundaryPath(spellFootprint,point=>state.cells.find(cell=>same(cell,point))?.height||0):'';
  const movementThreats=useMemo(()=>canInteract&&kind==='move'&&selected?movementRisks(adviceState,player,plan,selected,legalTargets):new Map(),[adviceState,player,plan,selected,canInteract,kind,legalTargetKey]);
  const hoverMovement=canInteract&&kind==='move'&&selectedUnit&&activeCell&&legal.has(key(activeCell))?movementPreview(adviceState,player,plan,selectedUnit.id,activeCell):null;
  const movementReadout=hoverMovement?.hasMove?hoverMovement:selectedMovement?.hasMove?selectedMovement:null;
  const tileReferences=new Map<string,{point:Point;active:boolean}>();
  for(const order of orders.filter(order=>order.unitId===selected))for(const point of [order.move,order.cast])if(point)tileReferences.set(key(point),{point,active:false});
  if(activeCell&&!viewingExchange)tileReferences.set(key(activeCell),{point:activeCell,active:true});
  const hoverRoute=hoverMovement?.hasMove?hoverMovement.route.map(point=>state.cells.find(cell=>same(cell,point))!):null;
  const hoverEffort=movementReadout?.effort??null;
  const eventKey=`${state.version}-${playback?.key??replay}`;
  usePlaybackAnimationsV44(svgRef,playback?.clock,activeResolution,eventKey,phase);
  const beforeImpact=activeResolution&&(phase==='move'||phase==='cast');
  const beforeResults=activeResolution&&phase!=='settle';
  const shownEndgame=beforeResults&&previousEndgameZone?previousEndgameZone:endgameZone;
  const endgameEdges=useMemo(()=>endgameBoundaries(shownEndgame,state.cells),[shownEndgame,state.cells]);
  // Accessible descriptions follow the same discrete snapshots as the visual
  // health bars and reduced-motion figures; they never announce future damage.
  const describedUnits=beforeResults&&previousState?previousState.units.filter(alive).map(unit=>{
    if(phase==='move')return unit;
    const move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id);
    const at=move?.to||push?.from||unit;
    return {...unit,q:at.q,r:at.r};
  }):livingUnits;
  const motions=useMemo(()=>new Map(state.units.map(unit=>[unit.id,battlefieldMotion(previousMotionState,motionState,unit.id,instance)])),[previousMotionState,motionState,instance]);
  // Keep both real fighters and their destinations clear. During playback the
  // complete authoritative route is protected, so a canopy cannot hide a walk.
  const scenerySubjects=[...visibleUnits.map(unit=>top(unit,state)),...orders.flatMap(order=>order.move?[top(order.move,state)]:[]),...intents.map(intent=>top(intent.anchor,state)),...(activeCell&&!viewingExchange?[top(activeCell,state)]:[]),...(activeResolution?[...motions.values()].flatMap(motion=>motion?.frames.map(frame=>top(frame.point,state))??[]):[])];
  useEffect(()=>{const svg=svgRef.current;if(!svg)return;const update=()=>{const box=svg.getBoundingClientRect();if(box.width&&box.height){setViewport({width:box.width,height:box.height});setViewportReady(true)}};update();const observer=new ResizeObserver(update);observer.observe(svg);return()=>observer.disconnect()},[]);
  // Start on the selected character's useful reach on every screen. This is a one-time
  // default: choosing Overview remains respected through later planning edits.
  useEffect(()=>{setPinnedEnemy(null);setRangeFocus(null)},[state.version,selected,viewingExchange,kind]);
  useEffect(()=>{if(!viewportReady||initialPlanningView.current)return;initialPlanningView.current=true;if(!viewingExchange)setZoom(true)},[viewportReady,viewingExchange]);
  useEffect(()=>{if(initialCamera.current)return;initialCamera.current=true;const at=top(selectedUnit||ownUnits[0]||{q:0,r:0},state);setCamera({x:at.x,y:at.y-42})},[state,selectedUnit,ownUnits]);
  // Keep the local encounter stable while choosing a spell, moving a ghost or
  // aiming. Only a new character, deliberate Focus, or resizing reframes it.
  useEffect(()=>{if(!plannedOrigin)return;if(viewingExchange){pendingFocus.current=true;return;}const fitted=planningCamera({viewport,origin:plannedOrigin,legalTargets,cells:state.cells,contextTargets:livingUnits});setDetailScale(fitted.scale);setCamera(fitted.center);setFocused(key(plannedOrigin));setHovered(null)},[selected,focusRequest,viewport.width,viewport.height]);
  useEffect(()=>{
    setRevealedClashes([]);if(!activeResolution)return;
    if(playback?.clock){let shown='';const reveal=(elapsed:number)=>{const next=clashEvents.flatMap((event,index)=>projectileMeetingMs(event.flightFraction??1)<=elapsed?[index]:[]),stamp=next.join(',');if(stamp!==shown){shown=stamp;setRevealedClashes(next)}};reveal(playback.clock.read().elapsed);return playback.clock.subscribeFrame(reveal)}
    const timers=clashEvents.map((event,index)=>setTimeout(()=>setRevealedClashes(visible=>[...visible,index]),projectileMeetingMs(event.flightFraction??1)));
    return()=>timers.forEach(clearTimeout);
  },[activeResolution,eventKey,playback?.clock]);
  useEffect(()=>{if(playback||!replaying)return;const timer=setTimeout(()=>{setReplaying(false);replayCallback.current?.(false)},RESOLUTION_MS);return()=>clearTimeout(timer)},[!!playback,replaying,replay,state.version]);
  useEffect(()=>{if(playback)return;if(!activeResolution){setPhase('settle');return}setPhase('move');const cast=setTimeout(()=>setPhase('cast'),PHASE_MS.cast),impact=setTimeout(()=>setPhase('impact'),PHASE_MS.impact),settle=setTimeout(()=>setPhase('settle'),PHASE_MS.settle);return()=>{clearTimeout(cast);clearTimeout(impact);clearTimeout(settle)}},[!!playback,activeResolution,eventKey]);
  useEffect(()=>{
    if(!viewingExchange){const saved=returnCamera.current;if(saved){const fitted=saved.zoom&&pendingFocus.current&&plannedOrigin?planningCamera({viewport,origin:plannedOrigin,legalTargets,cells:state.cells,contextTargets:livingUnits}):null;setCamera(fitted?.center||saved.camera);setDetailScale(fitted?.scale??saved.scale);setZoom(saved.zoom);if(pendingFocus.current&&plannedOrigin){setFocused(key(plannedOrigin));setHovered(null);}returnCamera.current=null;pendingFocus.current=false;}return;}
    if(!returnCamera.current)returnCamera.current={camera:{...safeCamera},scale:detailScale,zoom};
    const actionPoints=[...castAreas.flatMap(({event,cells})=>[...(event.from?[event.from]:[]),...cells]),...clashAreas.flatMap(({event,cells})=>[...cells,...(event.meeting?[event.meeting]:[])])];
    // Casts must not crop out the movement that got their casters here.
    const points=[...actionPoints,...events.filter(event=>['move','push','damage','heal','defeat','respawn'].includes(event.kind)&&(event as SimEvent&{cause?:string}).cause!=='collapse'&&!(event.kind==='defeat'&&events.some(other=>other.unitId===event.unitId&&(other as SimEvent&{cause?:string}).cause==='collapse'))).flatMap(event=>[...(event.from?[event.from]:[]),...(eventCell(event,state,previousState)?[eventCell(event,state,previousState)!]:[])])];
    const actorIds=resolutionActorIds(previousState,state,events,ownUnits.map(unit=>unit.id),presentationOnlyRules);
    const actorPoints=[...(previousState?.units.filter(unit=>alive(unit)&&actorIds.has(unit.id)).map(unit=>top(unit,previousState))||[]),...visibleUnits.filter(unit=>actorIds.has(unit.id)).map(unit=>top(unit,state))];
    const framed=[...points.map(point=>top(point,state)),...actorPoints.flatMap(at=>[at,{x:at.x,y:at.y-32},{x:at.x,y:at.y+24}])];
    if(framed.length){const fitted=fitEffect(framed,viewport);setDetailScale(fitted.scale);setCamera(fitted.center);setZoom(true);}
  },[viewingExchange,eventKey,viewport.width,viewport.height]);

  function previewCell(point:Point|null) {setHovered(point?key(point):null);onPreviewCell?.(!inspecting&&point&&legal.has(key(point))?{q:point.q,r:point.r}:null)}
  function focusCell(point:Point) {const id=key(point);setFocused(id);refs.current.get(id)?.focus();if(zoom){const at=top(point,state);setCamera(clampCamera({x:at.x,y:at.y-42}))}}
  function onKey(event:KeyboardEvent<SVGGElement>,point:Point) {
    if(event.altKey||event.ctrlKey||event.metaKey||event.nativeEvent.isComposing)return;
    if(event.key==='Escape'){event.preventDefault();setPinnedEnemy(null);setRangeFocus(null);setHovered(null);return}
    if(event.key==='Enter'||event.key===' '){event.preventDefault();choose(point);return}
    if(event.key==='Home'){event.preventDefault();focusCell({q:0,r:0});return}
    const vectors:Record<string,Point>={ArrowRight:{q:1,r:0},ArrowLeft:{q:-1,r:0},ArrowUp:{q:0,r:-1},ArrowDown:{q:0,r:1},q:{q:-1,r:1},e:{q:1,r:-1}};
    const delta=vectors[event.key];if(!delta)return;event.preventDefault();const next=state.cells.find(cell=>cell.q===point.q+delta.q&&cell.r===point.r+delta.r);if(next)focusCell(next);
  }
  function focusView() {const fitted=planningCamera({viewport,origin:plannedOrigin||selectedUnit||{q:0,r:0},legalTargets,cells:state.cells,contextTargets:livingUnits});setDetailScale(fitted.scale);setCamera(fitted.center);setZoom(true)}
  function showEffect() {const points=[...(forecast?.origin?[forecast.origin]:plannedOrigin?[plannedOrigin]:[]),...spellFootprint];const fitted=fitEffect(points.map(point=>top(point,state)),viewport);setDetailScale(fitted.scale);setCamera(fitted.center);setZoom(true)}
  function pointerDown(event:PointerEvent<SVGSVGElement>) {if(!zoom||event.button!==0)return;dragged.current=false;drag.current={x:event.clientX,y:event.clientY,camera:{...safeCamera},moved:false}}
  function pointerMove(event:PointerEvent<SVGSVGElement>) {if(!drag.current||!zoom)return;const dx=event.clientX-drag.current.x,dy=event.clientY-drag.current.y;if(Math.abs(dx)+Math.abs(dy)<8&&!drag.current.moved)return;drag.current.moved=true;dragged.current=true;const box=svgRef.current?.getBoundingClientRect();if(!event.currentTarget.hasPointerCapture(event.pointerId))event.currentTarget.setPointerCapture(event.pointerId);const scale=Math.max(focusSize.width/(box?.width||960),focusSize.height/(box?.height||500));setCamera(clampCamera({x:drag.current.camera.x-dx*scale,y:drag.current.camera.y-dy*scale}))}
  function choose(point:Point) {
    if(dragged.current){dragged.current=false;return}
    setFocused(key(point));setHovered(key(point));setInspectedNpc(null);
    const enemy=livingUnits.find(unit=>unit.owner!==player&&same(unit,point));
    if(enemyThreat&&enemy&&!viewingExchange&&kind==='move'&&!inspecting){setPinnedEnemy(current=>current===enemy.id?null:enemy.id);setRangeFocus(null);setHovered(null);onPreviewCell?.(null);return}
    setPinnedEnemy(null);
    if(inspecting&&!viewingExchange){const occupant=livingUnits.find(unit=>same(unit,point));setInspectedUnit(onInspectUnit?null:occupant?.id||null);if(occupant)onInspectUnit?.(occupant.id);return;}
    if(canInteract)onCell(point.q,point.r);
  }
  function inspectCreature(id:string){const intent=intents.find(entry=>entry.id===id);if(!intent)return;setInspectedNpc(current=>current===id?null:id);setInspecting(false);onPreviewCell?.(null);const at=top(intent.anchor,state);setCamera({x:at.x,y:at.y-42});setZoom(true);setDetailScale(1);}

  function unitFigure(unit:Unit) {
    const at=top(unit,state),old=previousState?.units.find(entry=>entry.id===unit.id&&alive(entry)),before=old&&previousState?top(old,previousState):at;
    const shown=beforeResults&&old?old:unit;
    const move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id),cast=events.find(event=>event.kind==='cast'&&event.unitId===unit.id);
    const mid=move?.to?top(move.to,state):push?.from?top(push.from,state):at;
    const damaged=events.some(event=>event.kind==='damage'&&event.unitId===unit.id&&(event.amount??0)>0),healed=health.get(unit.id)?.kind==='heal',bounced=events.some(event=>event.kind==='bounce'&&event.unitId===unit.id);
    const isSelected=unit.id===selected&&!viewingExchange,order=orders.find(entry=>entry.unitId===unit.id),guarding=activeResolution?unit.guard:unit.owner===player&&showOrders&&!!order?.guard;
    const contextualStatus=visibleUnits.length<=8||isSelected||activeUnit?.id===unit.id;
    const number=state.units.filter(entry=>entry.owner===unit.owner).findIndex(entry=>entry.id===unit.id)+1;
    const hero=champion(unit.championId);
    const direction=activeResolution?resolutionFacing(phase,old||unit,motions.get(unit.id)?.movePath||[],cast,unit.owner===0?2:6):order?.cast?facing(order.move||unit,order.cast,unit.owner===0?2:6):order?.move?facing(unit,order.move,unit.owner===0?2:6):unit.owner===0?1:7;
    const sliding=!!move&&!!previousMotionState&&!!movementPath(previousMotionState,unit.id,move.to!)?.some(isIce);
    const action:PixelAction=!alive(unit)&&!beforeResults?'defeat':activeResolution&&phase==='move'&&!!move&&!sliding?'walk':activeResolution&&phase==='cast'&&!!cast?'cast':activeResolution&&phase==='impact'&&damaged?'hit':'idle';
    const staticAt=phase==='move'?before:phase==='cast'||phase==='impact'?mid:at;
    const motion={'--px-static-x':`${staticAt.x-at.x}px`,'--px-static-y':`${staticAt.y-at.y}px`,'--px-dx':`${before.x-at.x}px`,'--px-dy':`${before.y-at.y}px`,'--px-mid-dx':`${mid.x-at.x}px`,'--px-mid-dy':`${mid.y-at.y}px`} as CSSProperties;
    return <g key={unit.id} transform={`translate(${at.x},${at.y-1})`} className={`px-unit${isSelected?' px-unit-selected':''}`} aria-hidden="true" onClick={()=>choose(unit)} onPointerEnter={event=>{if(event.pointerType==='mouse')previewCell(unit)}}>
      <title>{`${unitName(unit)} · ${unitLabel(unit)} · ${shown.hp}/${shown.maxHp} health · ${shown.flux}/${shown.maxFlux} Flux${activeStatusInsights(shown.statuses).map(status=>` · ${status.name}: ${status.effect} ${status.durationLabel}.`).join('')}`}</title>
      <g key={eventKey} className={`px-unit-motion${activeResolution&&(move||push)?' px-unit-moving':''}`} style={activeResolution?{...motion,...motions.get(unit.id)?.style}:undefined}><g className={activeResolution&&bounced?'px-unit-bounce':undefined} style={activeResolution&&bounced?{animationDelay:`${eventDelayMs(events.find(event=>event.kind==='bounce'&&event.unitId===unit.id)!,events)}ms`}:undefined}>
        <ellipse cy="4" rx="27" ry="10" fill="#2c2519" opacity=".26"/>
        <path d="M-28 0v5l12 7M28 0v5l-12 7" fill="none" stroke="#fff3ce" strokeWidth={isSelected?6:4}/>
        <path d="M-28 0v5l12 7M28 0v5l-12 7" fill="none" stroke={unitColor(unit)} strokeWidth={isSelected?3:2}/>
        {isSelected&&<><path d="M-31-1-16-11h32l15 10v8l-15 9h-32l-15-9Z" fill="none" stroke="#2c2519" strokeWidth="1.5"/><path className="px-selection-arrow" d="M-7-117H7v5H3v5H-3v-5H-7Z" fill="#efc657" stroke="#2c2519" strokeWidth="1.5"/></>}
        {isSelected&&<text className="px-active-name" y="-132">{unitName(unit)}</text>}
        <foreignObject x={-SPRITE_SIZE/2} y={-SPRITE_SIZE*.8125} width={SPRITE_SIZE} height={SPRITE_SIZE} pointerEvents="none" className={activeResolution&&healed?'px-heal-glow':''}>{unitPresentation?.[unit.id]?.creatureId?<CombatCreature creatureId={unitPresentation[unit.id].creatureId!} key={`${unit.id}-${eventKey}-${phase}-${action}`} action={action} facing={direction>=1&&direction<=3?-1:1} size={SPRITE_SIZE}/>:ANIMATED_CHARACTER_IDS.includes(unit.championId)?<ChampionFrames key={unit.id} id={unit.championId} action={action} facing={direction} size={SPRITE_SIZE} releaseMs={CAST_ANTICIPATION_MS}/>:<PixelChampion id={unit.championId} action={action} facing={direction} size={SPRITE_SIZE} motion="quiet" castLeadMs={CAST_ANTICIPATION_MS}/>}</foreignObject>
        <StatusAura unit={shown}/>
        <rect x="-35" y="-108" width="70" height="116" fill="transparent" className="px-unit-hitbox"/>
        {guarding&&<g transform="translate(29 -23)" className="px-guard"><path d="M-8-12H8V2L4 6v3H-4V6L-8 2Z" fill="#e4ca87" stroke="#2c2519" strokeWidth="2"/><path d="M-4-4v5h4V-6H4" fill="none" stroke="#74531e" strokeWidth="2"/></g>}
        <g className="px-unit-badge" transform="translate(-30 -17)"><path d="M-7-9H7v3h3V6H7v3H-7V6h-3V-6h3Z" fill={unitColor(unit)} stroke={isSelected?'#f8e4a0':'#fff3ce'} strokeWidth="2"/><text className="px-unit-number" y="4" fill="#fff3ce">{number}</text></g>
        {zoom&&!activeResolution&&(()=>{const all=visibleStatusStack(shown.statuses),stack=contextualStatus?all:{visible:all.visible.slice(0,1),hidden:all.hidden+Math.max(0,all.visible.length-1)};return <g data-contextual={contextualStatus} className="px-status-stack" transform={`translate(${48+screenScale*9} -88) scale(${Math.max(1,screenScale*.8)})`} data-status-unit={unit.id}>{stack.visible.map(([id,status],index)=>{const meta=statusInfo(id),insight=statusInsight(id,shown.statuses[id as keyof typeof shown.statuses]);return <g key={id} transform={`translate(0 ${index*24})`} className={`px-status px-status-${id}`} data-status={id}><title>{`${meta?.name||id}: ${insight?.effect||''} ${status.turns} round${status.turns===1?'':'s'} left.`}</title><rect x="-14" y="-10" width="28" height="22" rx="2" fill="#2c2519" stroke={meta?.color||'#e5cc9a'} strokeWidth="1.2"/><text x="-5" y="5" fill={meta?.color||'#e5cc9a'}>{(meta?.symbol||id.slice(0,1)).slice(0,2)}</text><text className="px-status-duration" x="10" y="9">{status.turns}</text></g>})}{stack.hidden>0&&<g transform={`translate(0 ${stack.visible.length*24})`} className="px-status-overflow"><rect x="-11" y="-8" width="22" height="16" rx="2" fill="#fff3ce" stroke="#2c2519"/><text y="4">+{stack.hidden}</text></g>}</g>})()}
      </g></g>
    </g>;
  }

  return <div className={`px-board px-board-v7 px-board-v8 px-board-v13 px-board-v17 px-combat-life px-combat-pacing-v16 px-element-clarity-v22 px-combat-clarity-v23 px-crafted-world-v24${playback?.clock?' px-clock-owned':''}${compactWorld?' px-compact-world':''}${activeResolution?' px-resolving':''}${zoom?' px-focused':''}${tacticalOverview?' px-tactical-overview':''}`} data-viewing-exchange={viewingExchange||undefined} data-playback-phase={activeResolution?phase:undefined} style={{'--px-text-duration':`${EVENT_TEXT_MS}ms`,'--px-impact-delay':`${PHASE_MS.impact}ms`,'--px-cast-duration':`${CAST_POSE_MS}ms`,'--px-settle-delay':`${PHASE_MS.settle}ms`} as CSSProperties}>
    {activeResolution&&<style>{[...motions.values()].filter(Boolean).map(motion=>motion!.keyframes+motion!.facingKeyframes).join('\n')}</style>}
    <div className="px-board-toolbar">{enemyRange&&threatUnit&&<div className="px42-threat-key" aria-label={`${unitName(threatUnit)} possible movement and spell reach`} title="Possible reach from public movement, terrain, statuses and ready spells. Spell reach includes areas affected after any legal move; it is not a committed attack or guaranteed damage."><strong>{unitName(threatUnit)}</strong><span><i/>Move</span><span className="px42-threat-spell"><i/>{enemyRange.readySpells?'Spell reach':'No ready spell'}</span>{pinnedEnemy&&<button type="button" aria-label="Clear enemy range" onClick={()=>{setPinnedEnemy(null);setRangeFocus(null);setHovered(null)}}>×</button>}</div>}{canInteract&&!inspecting&&!enemyRange&&<div className={`px16-range-key is-${kind}`} aria-label={kind==='move'?'Tinted area: reachable movement':'Gold edge: cast reach. Stripes: affected area'}><i/>{kind==='move'?'Move reach':'Cast reach'}{kind==='cast'&&spellFootprint.length>0&&<span><i/>Effect</span>}</div>}{!viewingExchange&&inspecting&&intents.length>0&&<div className="px-npc-tools" aria-label="Inspect elemental inhabitants">{intents.length===1?<button type="button" aria-pressed={inspectedNpc===intents[0].id} onClick={()=>inspectCreature(intents[0].id)}>{intents[0].phase==='pulse'?'◆':'◇'} {intents[0].name}</button>:<select aria-label="Inspect an elemental inhabitant" value={inspectedNpc||''} onChange={event=>event.target.value?inspectCreature(event.target.value):setInspectedNpc(null)}><option value="">Creatures · {intents.length}</option>{intents.map(intent=><option key={intent.id} value={intent.id}>{intent.name} · {intent.phase==='pulse'?'acts':'rests'}</option>)}</select>}</div>}<div className="px-camera-tools" role="group" aria-label="Battlefield view">
      {!viewingExchange&&<button type="button" aria-pressed={inspecting} aria-label="Inspect terrain and characters without giving orders" onClick={()=>{setInspecting(value=>!value);setInspectedNpc(null);setInspectedUnit(null);onPreviewCell?.(null)}}>⌕ <span>Inspect</span></button>}
      <button type="button" aria-label={zoom?'Overview':'Focus'} onClick={()=>{initialPlanningView.current=true;zoom?setZoom(false):focusView()}}>{zoom?'−':'+'} <span>{zoom?'Overview':'Focus'}</span></button>
      {!viewingExchange&&spellFootprint.length>1&&<button type="button" className="px-fit-effect" aria-label="Fit complete spell effect" onClick={showEffect}>⌖ <span>Fit spell</span></button>}
      
      {events.length>0&&(!viewingExchange||!onReplay)&&<button type="button" onClick={()=>{if(onReplay){onReplay();return}if(playback)return;setReplay(value=>value+1);setReplaying(true);onReplayChange?.(true)}} aria-pressed={activeResolution} aria-label="Replay the last exchange" disabled={activeResolution}>↻ <span>Replay</span></button>}
      {zoom&&<button type="button" className="px-pan-toggle" aria-label="Show battlefield pan controls" aria-expanded={panControls} onClick={()=>setPanControls(value=>!value)}>✥ <span>Pan</span></button>}
    </div></div>
    <div className="px-stage">
      <svg ref={svgRef} className="px-battlefield" viewBox={view} role="group" aria-label={`Battlefield. References run left to right and top to bottom across ${boardRadius*2+1} rows. Arrow keys and Q/E move focus; Enter selects a hex. Drag to pan. Overview shows the map; Fit spell shows its full area.`} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={event=>{drag.current=null;if(event.currentTarget.hasPointerCapture(event.pointerId))event.currentTarget.releasePointerCapture(event.pointerId)}} onPointerCancel={()=>{drag.current=null;dragged.current=false}} onPointerLeave={event=>{if(!event.currentTarget.hasPointerCapture(event.pointerId)){drag.current=null;if(event.pointerType==='mouse')previewCell(null)}}}>
        <defs>{Object.entries(WORLD_SURFACES).map(([biome,frame])=><pattern key={biome} id={`${instance}-world-${biome}`} width="128" height="128" patternUnits="userSpaceOnUse"><svg width="128" height="128" viewBox={`${frame%4*128} ${Math.floor(frame/4)*128} 128 128`} preserveAspectRatio="none" overflow="hidden"><image className="px-world-surface" href={CRISP_SURFACE_ATLAS} width="512" height="512"/></svg></pattern>)}<pattern id={`${instance}-stone`} width="22" height="12" patternUnits="userSpaceOnUse"><path d="M0 0H22M0 12H22M11 0V6M0 6H22M3 6v6M20 6v6" fill="none" stroke="#5b472a" strokeWidth="1" opacity=".35"/></pattern><pattern id={`${instance}-ground`} width="96" height="48" patternUnits="userSpaceOnUse"><path d="M8 16h3v2H8M59 34h2v2h-2M31 39h5M83 11h3" fill="#8c7546" stroke="#8c7546" strokeWidth="1" opacity=".14"/></pattern><pattern id={`${instance}-area`} width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><path d="M0 0V11" stroke="#2c2519" strokeWidth="2" opacity=".5"/></pattern></defs>
        <rect x={bounds.left-1000} y={bounds.top-1000} width={bounds.right-bounds.left+2000} height={bounds.bottom-bounds.top+2000} fill="#273f34"/>
        <g className="px24-distant-woods" aria-hidden="true" pointerEvents="none">{fringe.map(tree=><g key={tree.id} transform={`translate(${tree.x} ${tree.y})`}><AtlasProp frame={tree.frame} size={tree.size*(compactWorld?.72:1)}/></g>)}</g>
        <path className="px24-land-shadow" aria-hidden="true" pointerEvents="none" transform="translate(12 24)" d={state.cells.map(cell=>{const at=ground(cell);return `M${hexPolygon(at.x,at.y,0).replaceAll(',','L')}Z`;}).join('')}/>
        {state.cells.slice().sort((a,b)=>ground(a).y-ground(b).y||ground(a).x-ground(b).x).map(finalCell=>{
          const cell=beforeImpact?previousCellIndex.get(key(finalCell))||finalCell:finalCell;
          const at=top(cell,state),base=ground(cell),surface=terrainStyle(isIce(cell)?'ice':cell.terrain),substrate=biomeColors[cell.biome],field=hasField(cell),occupant=describedUnits.find(unit=>same(unit,cell)),isLegal=legal.has(key(cell))&&!(enemyRange&&kind==='move'),risk=kind==='move'?movementThreats.get(key(cell)):undefined;

          return <g key={key(cell)} data-biome={cell.biome} data-field={field?cell.terrain:undefined}>
            <g aria-hidden="true" pointerEvents="none" shapeRendering="crispEdges" transform={`translate(${at.x} ${at.y}) scale(${TILE_SCALE})`}>
              {exposedCliffs(cell,state.cells).map(face=><CliffArtV24 key={face.edge} cell={cell} face={face}/>)}
              <g><polygon points={silhouette} fill={substrate.top} stroke={substrate.top} strokeWidth=".6"/><polygon className="px24-ground-texture" points={silhouette} fill={`url(#${instance}-world-${cell.biome})`} opacity={(cell.biome==='water'?.5:cell.biome==='forest'?.42:.3)*(compactWorld?.55:1)}/><GroundDetailsV24 cell={cell} edges={groundRims.get(key(cell))} live={zoom&&!viewingExchange}/><polygon points={silhouette} className="px-world-grid"/>
                {field&&<polygon className="px-field-tint" points={silhouette} fill={surface.top} fillOpacity=".38" stroke={surface.mark} strokeWidth="2" strokeDasharray="4 3"/>}
                <TerrainMaterialArt cell={cell} edges={(beforeImpact?previousEdges:finalEdges).get(key(cell))} change={activeResolution&&!beforeImpact?terrainTransition(previousCellIndex.get(key(cell)),cell):null} animate={zoom&&(activeResolution?phase==='impact'||phase==='settle':liveMaterials.has(key(cell)))}/><ElementSurface cell={cell} occupied={!!occupant} animate={zoom&&(activeResolution?phase==='impact'||phase==='settle':liveMaterials.has(key(cell)))}/>{liveMaterials.has(key(cell))&&<PlanningElementV45 cell={cell}/>}<EndgameTile zone={shownEndgame} point={cell}/>
                {cell.well&&(()=>{const holder=(beforeImpact&&previousState?previousState.units:state.units).find(unit=>alive(unit)&&same(unit,cell));return <PixelWell owner={holder?.owner} color={holder?unitColor(holder):undefined} occupied={!!holder}/>})()}
                {!viewingExchange&&(inspecting||activeCell&&same(activeCell,cell))&&!isIce(cell)&&cell.terrain!=='plain'&&(field||cell.biome==='earth'||cell.biome==='water')&&<g className="px-field-rune" style={{color:surface.mark}} opacity={occupant||cell.well?0.56:0.85}><PixelRune terrain={isIce(cell)?'black_ice':cell.terrain}/></g>}
                {cell.terrain!=='plain'&&cell.ttl!==undefined&&Array.from({length:Math.min(4,cell.ttl)},(_,index)=><rect key={index} x={-3*Math.min(4,cell.ttl!)+index*6} y="27" width="4" height="2" fill={surface.mark}/>)}
                {isLegal&&<><polygon className={`px-target px-target-${kind}`} data-landing-risk={risk?.blocked?'blocked':risk?.contested?'contested':undefined} points={silhouette} fill={risk?.blocked?'#a94230':risk?.contested?'#b07a1e':kind==='move'?'#277c79':'#efc657'} fillOpacity={risk?.blocked||risk?.contested?'.2':'.08'} stroke={risk?.blocked?'#a94230':risk?.contested?'#8a5d14':kind==='move'?'#277c79':'#9c6519'} strokeOpacity=".7" strokeWidth="1"/>{risk?.blocked||risk?.contested?<text className="px-landing-risk" y="12" fill={risk.blocked?'#842d21':'#684509'}>{risk.blocked?'×':'?'}</text>:!occupant&&activeCell&&same(activeCell,cell)&&<circle className="px-range-dot" cy="8" r="3" fill={kind==='move'?'#1c5e5c':'#6b4619'} stroke="#fff3ce" strokeWidth="1.2"/>}</>}
                {affected.has(key(cell))&&(()=>{const predicted=forecastCells.get(key(cell));return <g data-forecast-tile={formatTile(cell)} data-forecast-field={predicted?.field}><polygon className="px-area-preview" points={silhouette} fill={predicted?.color||spellColor(spellId,selectedUnit?champion(selectedUnit.championId).element:'light')} fillOpacity={focusedSpell&&aimTarget?({centre:.4,inner:.23,rim:.11,precision:.29}[focusZone(focusedSpell,aimTarget,cell)]):.29} data-focus-zone={focusedSpell&&aimTarget?focusZone(focusedSpell,aimTarget,cell):undefined} stroke="#fff3ce" strokeWidth="1.5"/><polygon points={silhouette} fill={`url(#${instance}-area)`} stroke="none"/>{predicted&&zoom&&aimTarget&&same(aimTarget,cell)&&<g className="px-field-forecast-marker" transform={`translate(0 19) scale(${Math.max(1,screenScale/TILE_SCALE)})`}><title>{`Planned ${predicted.name}: ${predicted.shortRule}`}</title><rect x="-10" y="-8" width="20" height="16" rx="2" fill="#fff7e0" stroke="#2c2519" strokeWidth="1"/><text y="4" fill="#2c2519">{predicted.symbol}</text></g>}</g>})()}
                {activeResolution&&castAreas.filter(cast=>cast.cells.some(point=>same(point,cell))).map(({event,spell},index)=><g key={`${event.unitId}-${index}`} className="px-spell-impact" data-playback-effect="impact" data-cast-unit={event.unitId} data-cast-spell={event.spellId} data-effect-cell={key(cell)} style={{'--px-cast-color':spellColor(event.spellId,'light'),'--px-impact-delay':`${PHASE_MS.impact}ms`} as CSSProperties}><polygon className="px-impact-fill" points={silhouette} fill="var(--px-cast-color)"/><polygon className="px-impact-edge" points={silhouette} fill="none" stroke="#fff3ce" strokeWidth="3"/>{event.to&&same(event.to,cell)?<g transform="scale(1.2)"><ElementImpact element={spell.element} ice={!!spell.freeze} branch={spell.branch}/></g>:castAccents.get(event.unitId)?.has(key(cell))?<ElementWake element={spell.element}/>:null}</g>)}
                {activeResolution&&clashAreas.filter(clash=>clash.cells.some(point=>same(point,cell))).map(({event},index)=><g key={`clash-${index}`} className="px-spell-impact px-v16-clash-area" data-playback-effect="impact" data-clash-field={event.terrain} data-effect-cell={key(cell)} style={{'--px-cast-color':combinationFor(event.elements||[])?.color||'#d9ead4','--px-impact-delay':`${PHASE_MS.impact}ms`} as CSSProperties}><polygon className="px-impact-fill" points={silhouette} fill="var(--px-cast-color)"/><polygon className="px-impact-edge" points={silhouette} fill="none" stroke="#fff3ce"/></g>)}
              </g>
            </g>

          </g>;
        })}
        {enemyRange&&<EnemyThreatOverlayV42 preview={enemyRange} heightAt={point=>cellIndex.get(key(point))?.height??0}/>}
        <g className="px22-field-regions" aria-hidden="true">{(beforeImpact?previousFields:finalFields).map(region=><g key={region.id} className="px22-field-region" data-field-material={region.material} data-field-cells={region.cells.length} style={{'--field-color':region.color} as CSSProperties}><path className="px22-field-outline" d={region.path}/><path className="px22-field-edge" d={region.path}/></g>)}</g>
        {activeResolution&&<g key={`contours-${eventKey}`} className="px22-impact-contours" aria-hidden="true">{[...castAreas,...clashAreas].map(({event,cells},index)=>{const path=rangeBoundaryPath(cells,point=>cellIndex.get(key(point))?.height??0);return path?<g key={index} className="px22-impact-contour" data-playback-effect="impact" data-impact-outline={event.kind==='clash'?event.terrain:event.spellId} data-impact-area={cells.length}><path className="px22-field-outline" d={path}/><path className="px22-field-edge" d={path}/></g>:null})}</g>}
        <EndgameBorders current={endgameEdges.current} next={endgameEdges.next}/>{!viewingExchange&&(state.round===1||inspecting)&&deploymentZones.map(zone=>{const points=zone.tiles.filter(point=>cellIndex.has(key(point)));if(!points.length)return null;const anchor=top(points[Math.floor(points.length/2)],state);return <g key={zone.label} className="px17-deployment" data-deployment-zone={zone.label} aria-hidden="true" pointerEvents="none">{points.map(point=>{const at=top(point,state);return <polygon key={key(point)} points={hexPolygon(at.x,at.y,8)} fill={zone.color} fillOpacity=".07" stroke={zone.color} strokeWidth="2" strokeDasharray="5 5"/>})}<g transform={`translate(${anchor.x} ${anchor.y+55}) scale(${Math.max(1,screenScale*.85)})`}><text y="4" fill={zone.color}>{zone.label}</text></g></g>})}
        {rangeEdge&&<g className={`px16-range-boundary is-${kind}`} aria-hidden="true" pointerEvents="none" data-range-boundary={kind}><path className="px16-range-shadow" d={rangeEdge}/><path className="px16-range-edge" d={rangeEdge}/></g>}
        {effectEdge&&<g className="px16-effect-boundary" aria-hidden="true" pointerEvents="none" data-effect-boundary={spellFootprint.length}><path className="px16-range-shadow" d={effectEdge}/><path className="px16-effect-edge" d={effectEdge}/></g>}
        {focusedSpell&&aimTarget&&<FocusedAreaV42 spell={focusedSpell} aim={aimTarget} cells={spellFootprint.map(point=>({...point,height:cellIndex.get(key(point))?.height??0}))}/>}
        {activeResolution&&<g key={`contacts-${eventKey}`} aria-hidden="true" pointerEvents="none">{contacts.map(contact=>{const at=top(contact.point,state);return <g key={contact.id} className={`px-ground-contact is-${contact.material}`} data-ground-contact={contact.material} data-contact-unit={contact.unitId} data-contact-at={contact.atMs} transform={`translate(${at.x} ${at.y+2}) scale(${contact.weight})`} style={{'--contact-delay':`${contact.atMs}ms`} as CSSProperties}>{contact.material==='water'&&<ellipse className="px-contact-ring" rx="22" ry="8"/>}{[-1,1].flatMap((side)=>[0,1].map(index=><path key={`${side}-${index}`} className="px-contact-particle" d={contact.material==='leaf'?'M-3 0 1-3 4-2 1 2-2 3Z':contact.material==='ice'?'M0-4 2 0 0 3-2 0Z':'M-2-3H2V1H-2Z'} style={{'--contact-x':`${side*(17+index*11)}px`,'--contact-y':`${-7-index*6}px`,'--contact-spin':`${side*(contact.material==='leaf'?45:12)}deg`} as CSSProperties}/>))}</g>;})}</g>}
        <g className="px-world-actors">{[
          ...props.filter(prop=>prop.cell.biome!=='ruins').map(prop=>{
            const cell=(beforeImpact?previousCellIndex:cellIndex).get(key(prop.cell))||cellIndex.get(key(prop.cell))!,at=top(cell,state),x=at.x+prop.x,y=at.y+prop.y,size=prop.size*(compactWorld?.74:1),reactiveFrame=reactivePropFrame(cell,prop.frame),material=terrainMaterial(cell);
            const opacity=sceneryOpacity({x,y,size,canopy:prop.canopy},scenerySubjects,compactWorld);
            return {key:`prop-${key(prop.cell)}`,depth:y,figure:<g transform={`translate(${x} ${y})`} className={`px-world-prop${opacity<1?' is-canopy-hidden':''}`} style={{opacity}} data-world-prop={prop.frame} data-prop-material={material} data-scenery-opacity={opacity}><ellipse cy="0" rx={size*.23} ry={size*.07} fill="#293e27" opacity=".16"/><AtlasProp frame={reactiveFrame??prop.frame} size={size} reactive={reactiveFrame!==null}/>{reactiveFrame===null&&(material==='frozen'||material==='scorched')&&<g className={`px17-prop-material is-${material}`}><path d={material==='frozen'?'M-18 0v-8h4v-6h3v12h4v4M14 1v-9h4v-5h3v15Z':'M-17 0h7v-5h4v7H5v-6h5V0h8v3H-17Z'}/></g>}</g>};
          }),
          ...[...(beforeImpact?previousSolids:finalSolids)].map(([id,footprint])=>{const cell=(beforeImpact?previousCellIndex:cellIndex).get(id)||cellIndex.get(id)!,at=top(cell,state);return {key:`solid-${id}`,depth:at.y+TILE_SCALE*15,figure:<g transform={`translate(${at.x} ${at.y}) scale(${TILE_SCALE})`}><SolidTerrainV24 cell={cell} footprint={footprint} texture={`${instance}-world-ruins`}/></g>};}),
          ...visibleUnits.map(unit=>({key:unit.id,depth:top(unit,state).y+1,figure:unitFigure(unit)})),
          ...intents.map(intent=>({key:`npc-${intent.id}`,depth:top(intent.anchor,state).y,figure:<ElementalCreature speciesId={intent.id} x={top(intent.anchor,state).x} y={top(intent.anchor,state).y} size={110} active={viewingExchange?events.some(event=>event.kind==='inhabitant'&&event.speciesId===intent.id&&!event.interrupted):intent.phase==='pulse'} paused={tacticalOverview}/>}))
        ].sort((a,b)=>a.depth-b.depth||a.key.localeCompare(b.key)).map(actor=><g key={actor.key}>{actor.figure}</g>)}</g>
        {!viewingExchange&&<g aria-hidden="true" pointerEvents="none">{intents.filter(intent=>inspectedNpc?intent.id===inspectedNpc:intent.phase==='pulse').flatMap(intent=>intent.area.map(point=>{const at=top(point,state);return <polygon key={`${intent.id}-${key(point)}`} className={`px-npc-telegraph${intent.phase==='pulse'?' is-pulse':''}`} data-inhabitant-footprint={intent.id} points={hexPolygon(at.x,at.y,7)}/>;}))}</g>}
        <g className="px-bars" aria-hidden="true" pointerEvents="none">{visibleUnits.map(unit=>{
          const at=top(unit,state),old=previousState?.units.find(entry=>entry.id===unit.id&&alive(entry)),before=old&&previousState?top(old,previousState):at,shown=beforeResults&&old?old:unit;
          const move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id),mid=move?.to?top(move.to,state):push?.from?top(push.from,state):at;
          const staticAt=phase==='move'?before:phase==='cast'||phase==='impact'?mid:at;
          const motion={'--px-static-x':`${staticAt.x-at.x}px`,'--px-static-y':`${staticAt.y-at.y}px`,'--px-dx':`${before.x-at.x}px`,'--px-dy':`${before.y-at.y}px`,'--px-mid-dx':`${mid.x-at.x}px`,'--px-mid-dy':`${mid.y-at.y}px`} as CSSProperties;
          return <g key={unit.id} transform={`translate(${at.x} ${at.y+20})`}><g key={eventKey} className={activeResolution&&(move||push)?'px-unit-moving':''} style={activeResolution?{...motion,...motions.get(unit.id)?.style}:undefined}><rect x="-33" y="-5" width="66" height="10" fill="#f8edcf" stroke="#2c2519" strokeWidth="1.5"/><rect x="-30" y="-2" width={Math.max(0,60*shown.hp/shown.maxHp)} height="4" fill={unitColor(unit)}/>{healthBarTicks(shown.maxHp).map((fraction,i)=><path key={i} d={`M${-30+60*fraction} -2v4`} stroke="#f8edcf" strokeWidth="1"/>)}<rect x="-31" y="7" width="62" height="3" fill="#514530"/><rect x="-31" y="7" width={Math.max(0,62*shown.flux/shown.maxFlux)} height="3" fill="#e2ae38"/></g></g>;
        })}</g>
        <g className="px-well-values" aria-hidden="true" pointerEvents="none">{state.cells.filter(cell=>cell.well&&(inspecting||activeCell&&same(activeCell,cell)||legal.has(key(cell)))).map(cell=>{
          const shown=beforeImpact?previousState?.cells.find(entry=>same(entry,cell))||cell:cell,at=top(cell,state),owner=(beforeImpact&&previousState?previousState.units:state.units).find(unit=>alive(unit)&&same(unit,cell))?.owner;
          return <g key={key(cell)} className="px-well-badge" data-well={key(cell)} data-owner={owner??'neutral'} transform={`translate(${at.x+(tacticalOverview?0:48)} ${at.y+(tacticalOverview?13*screenScale:36)}) scale(${screenScale})`}><path d="M-13-9H13v3h3V6h-3v3H-13V6h-3V-6h3Z" fill={owner===undefined?'#fff0bc':teamColors[owner]} stroke={owner===undefined?'#705321':'#fff3ce'} strokeWidth="1.5"/><text y="4" fill={owner===undefined?'#4c3c22':'#fff3ce'}>+{wellValue(shown)} F</text></g>;
        })}</g>
        {tacticalOverview&&<g className="px-overview-units" aria-hidden="true" pointerEvents="none">{visibleUnits.map(unit=>{
          const old=previousState?.units.find(entry=>entry.id===unit.id&&alive(entry)),move=events.find(event=>event.kind==='move'&&event.unitId===unit.id),push=events.find(event=>event.kind==='push'&&event.unitId===unit.id);
          const point=activeResolution&&phase==='move'&&old?old:activeResolution&&phase==='cast'?(move?.to||push?.from||unit):unit,at=top(point,state),number=state.units.filter(entry=>entry.owner===unit.owner).findIndex(entry=>entry.id===unit.id)+1;
          return <g key={unit.id} data-unit-marker={unit.id} transform={`translate(${at.x+15*screenScale} ${at.y+8*screenScale}) scale(${screenScale})`}><path d={unit.owner===player?'M-6-7H6l2 2V5L6 7H-6l-2-2V-5Z':'M0-9 9 0 0 9-9 0Z'} fill={unitColor(unit)} stroke={unit.id===selected?'#f9d45f':'#fff3ce'} strokeWidth={unit.id===selected?2.5:1.5}/><text y="4" fill="#fff3ce">{number}</text></g>;
        })}</g>}
        {!activeResolution&&kind==='move'&&<g className="px-movement-risks" aria-hidden="true" pointerEvents="none">{legalTargets.flatMap(point=>{const risk=movementThreats.get(key(point));if(!risk?.blocked&&!risk?.contested)return [];const at=top(point,state);return <g key={key(point)} className={`px-risk-marker ${risk.blocked?'is-blocked':'is-contested'}`} data-risk-tile={formatTile(point)} transform={`translate(${at.x+screenScale*14} ${at.y-screenScale*4}) scale(${screenScale})`}><rect x="-8" y="-8" width="16" height="16" rx="2"/><text y="5">{risk.blocked?'×':'?'}</text></g>})}</g>}
        {hoverRoute&&selectedUnit&&<g aria-hidden="true" pointerEvents="none" data-route-effort={hoverEffort} data-route-hexes={hoverRoute.length}><polyline className="px-v8-route-hover" points={[selectedUnit,...hoverRoute].map(point=>{const p=top(point,state);return `${p.x},${p.y}`}).join(' ')}/><polyline className="px-v8-route-ink" points={[selectedUnit,...hoverRoute].map(point=>{const p=top(point,state);return `${p.x},${p.y}`}).join(' ')}/>{hoverRoute.some(isIce)&&(()=>{const p=top(hoverRoute[hoverRoute.length-1],state);return <path className="px-v8-slide-stop" transform={`translate(${p.x} ${p.y})`} d="M-9-6H9V6H-9ZM-4-9V9M4-9V9"/>})()}</g>}
        <g className="px-orders" aria-hidden="true" pointerEvents="none">{orders.map(order=>{const unit=livingUnits.find(entry=>entry.id===order.unitId);if(!unit)return null;const destination=top(order.move||unit,state),number=state.units.filter(entry=>entry.owner===unit.owner).findIndex(entry=>entry.id===unit.id)+1,color=spellColor(order.spellId,champion(unit.championId).element),isSelected=unit.id===selected,related=forecast?.clashes?.some(clash=>!!selected&&clash.participants.includes(selected)&&clash.participants.includes(unit.id));const route=[unit,...(order.move?movementPath(motionState,unit.id,order.move)||[order.move]:[])].map(point=>top(point,state));return <g key={unit.id} className={`px-queued-order${isSelected?' is-selected':related?' is-related':' is-secondary'}${isSelected&&selectedMovement?.blocked?' is-blocked':isSelected&&selectedMovement?.contested?' is-contested':''}`} data-order-unit={unit.id} data-order-control={canCommand(unit)?'local':'ally'}>
          {order.move&&<><polyline className="px-move-path-shadow" points={route.map(point=>`${point.x},${point.y}`).join(' ')}/><polyline className="px-move-path" points={route.map(point=>`${point.x},${point.y}`).join(' ')}/><g transform={`translate(${destination.x} ${destination.y})`}><path d="M-20-4-10-10h20l10 6v8l-10 6h-20l-10-6Z" fill="#fff3ce" fillOpacity=".4" stroke="#1c5e5c" strokeWidth="2" strokeDasharray="4 3"/><text className="px-order-number" y="4">{number}</text></g></>}
          {order.cast&&queuedVolley?.casts.some(cast=>cast.unitId===order.unitId)&&(()=>{const clash=forecast?.clashes?.find(entry=>entry.participants.includes(order.unitId))||queuedVolley.clashes.find(entry=>entry.participants.includes(order.unitId)),target=flightPoint(clash?.meeting??order.cast!),release=queuedVolley.positions.get(order.unitId)||unit,castOrigin=flightPoint(release);return <><path className="px-cast-path" data-queued-cast-unit={order.unitId} data-queued-cast-origin={key(release)} d={`M${castOrigin.x} ${castOrigin.y}L${target.x} ${target.y}`} stroke={color}/><g transform={`translate(${top(order.cast!,state).x} ${top(order.cast!,state).y})`} stroke={color} fill="none" strokeWidth="2"><path d="M-23-5v-7h10M23-5v-7H13M-23 5v7h10M23 5v7H13"/><path d="M-5 0H5M0-4V4"/><text className="px-order-number" x="26" y="-15" stroke="none" fill={color}>{number}</text></g></>})()}
        </g>})}</g>
        {selectedMovement?.hasMove&&(()=>{const at=top(selectedMovement.target,state),blocked=selectedMovement.blocked,contested=selectedMovement.contested;return <g className={`px-selected-landing${blocked?' is-blocked':contested?' is-contested':''}`} data-selected-landing={formatTile(selectedMovement.target)} data-movement-effort={selectedMovement.effort} data-movement-budget={selectedMovement.budget} transform={`translate(${at.x} ${at.y+screenScale*23}) scale(${screenScale})`} aria-hidden="true" pointerEvents="none"><title>{`${formatTile(selectedMovement.target)}: ${selectedMovement.effort}/${selectedMovement.budget} movement${selectedMovement.slide?', includes Ice slide':''}. ${movementText(selectedMovement.reason||selectedMovement.contestedReason,selectedMovement.target)||'Queued landing.'}`}</title><rect x="-46" y="-10" width="92" height="20" rx="3"/><text y="4">{blocked?'× ':contested?'? ':selectedMovement.slide?'↠ ':''}{formatTile(selectedMovement.target)} · {selectedMovement.effort}/{selectedMovement.budget}</text>{selectedMovement.slide&&<path className="px-queued-slide-stop" transform={`translate(0 ${-23+10/screenScale})`} d="M-6-4H6V4H-6ZM-2-7V7M2-7V7"/>}</g>})()}
        {canInteract&&!inspecting&&forecast?.clashes?.map((clash,index)=>{const center=flightPoint(clash.meeting),compound=combinationFor(clash.elements);return <g key={index} data-planned-clash={compound?.name||clash.terrain} transform={`translate(${center.x} ${center.y})`} className="px16-planned-clash" aria-hidden="true" pointerEvents="none"><title>{`${compound?.name||'Elemental'} collision: these allied spells meet here before their aims.`}</title><path d="M0-20 26 0 0 20-26 0Z"/><path d="M-10-6 10 6M10-6-10 6"/><g transform={`translate(0 ${-27*screenScale}) scale(${screenScale})`}><rect x="-41" y="-10" width="82" height="19" rx="3"/><text y="3">{compound?.name||'Collision'}</text></g></g>})}
        {canInteract&&!inspecting&&kind==='cast'&&plannedOrigin&&(()=>{const at=top(forecast?.origin||plannedOrigin,state),moved=selectedUnit&&!same(selectedUnit,forecast?.origin||plannedOrigin);return <g data-cast-origin={formatTile(forecast?.origin||plannedOrigin)} className={`px16-cast-origin${moved?' is-planned':''}`} transform={`translate(${at.x} ${at.y+8})`} aria-hidden="true" pointerEvents="none"><title>{`Cast from ${formatTile(forecast?.origin||plannedOrigin)}${moved?' after moving':''}`}</title><ellipse rx="35" ry="15"/><path d="M-39 0h8M39 0h-8M0-20v8M0 20v-8"/></g>})()}
        {canInteract&&aimTarget&&<g className="px-aim-reticle" aria-hidden="true" pointerEvents="none" transform={`translate(${top(aimTarget,state).x} ${top(aimTarget,state).y})`}><path d="M-31-6v-11h14M31-6v-11H17M-31 6v11h14M31 6v11H17" fill="none" stroke="#fff3ce" strokeWidth="7"/><path d="M-31-6v-11h14M31-6v-11H17M-31 6v11h14M31 6v11H17" fill="none" stroke="#2c2519" strokeWidth="3"/><path d="M-6 0H6M0-5V5" stroke="#2c2519" strokeWidth="2"/></g>}
        {activeResolution&&<g key={`effects-${eventKey}`} className="px-resolution" aria-hidden="true" pointerEvents="none">{feedbackEvents.map((event,index)=>{
          const point=eventCell(event,state,previousState);if(!point)return null;const at=top(point,state),unit=state.units.find(entry=>entry.id===event.unitId),element=event.spellId?getSpell(event.spellId).element:event.elements?.[0]||unit&&champion(unit.championId).element||'light',color=elementColors[element]||'#ead4a0';
          const style={'--px-event-delay':`${healthEventSet.has(event)?0:eventDelayMs(event,events)}ms`,'--px-effect':color} as CSSProperties;
          if(event.kind==='cast'){
            const start=event.from||unit;if(!start)return null;
            const spell=event.spellId&&event.unitId?spellForCast(previousState||state,event.unitId,event.spellId,(event as SimEvent&{scroll?:boolean}).scroll===true):null;
            const origin=flightPoint(start),shape=spell?.shape??'single';
            const clash=clashEvents.find(entry=>event.unitId&&entry.participants?.includes(event.unitId));
            const meeting=clash?.meeting?flightPoint(clash.meeting):null;
            const end=meeting||flightPoint(point);
            return <g key={index} className={`px-cast-event px-element-${element}`} data-playback-effect="cast" style={style}>{!same(start,point)&&<ElementProjectile from={origin} to={end} element={element} shape={shape} branch={spell?.branch} delayMs={eventDelayMs(event,events)} flightFraction={clash?.flightFraction??1} readabilityScale={1}/>}<g transform={`translate(${top(start,state).x} ${top(start,state).y-44})`} className="px-cast-source" style={{color}}><path d="M-5-10H5V-5H10V5H5V10H-5V5H-10V-5H-5Z"/><path d="M-2-4H2V4H-2Z" fill="#fff3cf" stroke="none"/></g></g>;
          }
          if(event.kind==='clash'&&event.meeting){
            const center=flightPoint(event.meeting),combination=combinationFor(event.elements||[]),clashIndex=clashEvents.indexOf(event);
            return <g key={index} data-playback-effect="clash" data-clash-meeting={`${event.meeting.q},${event.meeting.r}`} transform={`translate(${center.x} ${center.y}) scale(1.2)`}><ElementClash elements={event.elements||[]} name={combination?.name||'Spell collision'} color={combination?.color||color} delayMs={projectileMeetingMs(event.flightFraction??1)} revealed={revealedClashes.includes(clashIndex)||phase==='impact'||phase==='settle'}/></g>;
          }
          if(event.kind==='inhabitant')return event.interrupted?null:<g key={index} data-playback-effect="impact" transform={`translate(${at.x} ${at.y-38}) scale(${Math.max(1,screenScale*.75)})`} style={style}><g className="px-reaction-burst"><ellipse rx="36" ry="14" fill="none" stroke={color} strokeWidth="4"/></g></g>;
          if(event.kind==='reaction'&&(event as SimEvent&{cause?:string}).cause==='link')return <g key={index} data-playback-effect="impact" data-link-target={event.unitId} transform={`translate(${at.x} ${at.y-44}) scale(${projectileReadabilityScale(screenScale)})`} style={style}><ElementTeamLink/></g>;
          if(event.kind==='reaction'&&!clashEvents.some(clash=>clash.terrain===event.terrain)&&events.find(entry=>entry.kind==='reaction'&&entry.terrain===event.terrain)===event)return <g key={index} data-playback-effect="impact" transform={`translate(${at.x} ${at.y})`} style={style}><g className="px-reaction-burst"><path d="M-35-4h12v-12h11v-14H0v10h14v-10h10v20h15V4H24v14H8v12H-5V18H-20V7H-35Z" fill={terrainStyle(event.terrain||'steam').top||color} stroke="#2c2519" strokeWidth="3"/><g style={{color:terrainStyle(event.terrain||'steam').mark}}><PixelRune terrain={event.terrain||'steam'}/></g></g></g>;
          if(healthEventSet.has(event)&&phase==='settle')return <g key={index} data-health-feedback={event.unitId} transform={`translate(${at.x} ${at.y-Math.max(148,screenScale*36)}) scale(${Math.max(1,screenScale*.7)})`} style={style}><CombatCallout label={event.text} tone={event.kind==='heal'?'heal':'damage'} critical={events.some(source=>source.unitId===event.unitId&&source.kind===event.kind&&(source.amount??0)>0&&(source as SimEvent&{critical?:boolean}).critical)}/></g>;
          if(event.kind==='push'&&event.from){const origin=top(event.from,state);return <g key={index} className="px-cast-event" data-playback-effect="impact" style={style}><path d={`M${origin.x} ${origin.y}L${at.x} ${at.y}`} fill="none" stroke="#fff3ce" strokeWidth="8" strokeDasharray="4 7"/><path d={`M${origin.x} ${origin.y}L${at.x} ${at.y}`} fill="none" stroke="#53612d" strokeWidth="4" strokeDasharray="4 7"/></g>}
          return null;
        })}</g>}
        {activeResolution&&phase==='settle'&&<g key={`blocked-${eventKey}`} aria-hidden="true" pointerEvents="none">{[...blockedFighters].map(id=>{const unit=state.units.find(unit=>unit.id===id);if(!unit)return null;const at=top(unit,state);return <g key={id} data-protection-feedback={id} transform={`translate(${at.x} ${at.y-Math.max(148,screenScale*36)}) scale(${Math.max(1,screenScale*.7)})`}><CombatCallout label="Blocked"/></g>})}</g>}
        {activeResolution&&phase==='settle'&&<g key={`conditions-${eventKey}`} aria-hidden="true" pointerEvents="none">{[...conditions].map(([id,change])=>{const unit=state.units.find(unit=>unit.id===id)!;const at=top(unit,state),name=statusInfo(change.id)?.name??change.id;return <g key={id} data-condition-feedback={id} transform={`translate(${at.x} ${at.y-Math.max(148,screenScale*36)}) scale(${Math.max(1,screenScale*.7)})`}><CombatCallout label={change.added?name:`${name} ended`} row={health.has(id)||blockedFighters.has(id)?1:0}/></g>})}</g>}
        <g className="px-tile-references" aria-hidden="true" pointerEvents="none">{[...tileReferences.values()].map(({point,active})=>{
          if(selectedMovement?.hasMove&&same(point,selectedMovement.target))return null;const at=top(point,state);return <g key={key(point)} data-tile-reference={formatTile(point)} data-active={active||undefined} transform={`translate(${at.x} ${at.y+43}) scale(${screenScale})`}><rect x="-17" y="-8" width="34" height="16" rx="2" fill={active?'#fff3ce':'#ecedd9'} stroke={active?'#2c2519':'#1c5e5c'} strokeWidth="1"/><text y="4" textAnchor="middle" fill="#2c2519" style={{font:'700 11px/1 Arial,sans-serif'}}>{formatTile(point)}</text></g>;
        })}</g>
        {/* Ground targets sit above tall sprite hitboxes so taps select the visible hex. */}
        <g className="px-cell-interactions">{state.cells.slice().sort((a,b)=>ground(a).y-ground(b).y||ground(a).x-ground(b).x).map(finalCell=>{
          const cell=beforeImpact?previousCellIndex.get(key(finalCell))||finalCell:finalCell;
          const at=top(cell,state),occupant=describedUnits.find(unit=>same(unit,cell)),isLegal=legal.has(key(cell)),predicted=forecastCells.get(key(cell)),movementRisk=movementThreats.get(key(cell));
          const cellStatuses=occupant?statusEntries(occupant).map(([id,status])=>`${statusInfo(id)?.name||id}, ${status?.turns} rounds`).join('; '):'';
          const label=`${formatTile(cell)}. ${BIOME_NAMES[cell.biome]}. ${biomeRule(cell)}.${endgameCellDescription(shownEndgame,cell)?' '+endgameCellDescription(shownEndgame,cell):''}${surfaceTraits(cell).map(trait=>` ${trait.name}: ${trait.description}`).join('')}${hasField(cell)?` Field: ${fieldName(cell)}${cell.ttl?`, ${cell.ttl} round${cell.ttl===1?'':'s'}`:''}.`:''}${cell.well?` Flux spring: +${wellValue(cell)} Flux if occupied after the exchange, up to the character's maximum.`:''}${cell.barrier?` Barrier ${cell.barrier}. Blocks movement and sight.`:''}${occupant?` ${unitName(occupant)}, ${unitLabel(occupant)}, ${occupant.hp} of ${occupant.maxHp} health, ${occupant.flux} Flux.${cellStatuses?' '+cellStatuses+'.':''}`:''}${isLegal?` Available ${kind} target.`:''}${movementRisk?.reason?` ${movementText(movementRisk.reason,cell)}`:movementRisk?.contestedReason?` ${movementText(movementRisk.contestedReason,cell)}`:''}${predicted?` Planned field: ${predicted.name}. ${predicted.shortRule}. Rival orders may change it.`:''}`;
          return <g key={key(cell)} ref={node=>{if(node)refs.current.set(key(cell),node);else refs.current.delete(key(cell))}} role="button" data-tile={formatTile(cell)} tabIndex={focused===key(cell)?0:-1} aria-label={label} aria-disabled={viewingExchange||(!canInteract&&!inspecting)} className="px-cell-hit" onKeyDown={event=>onKey(event,cell)} onFocus={event=>{setFocused(key(cell));setRangeFocus(event.currentTarget.matches(':focus-visible')&&occupant&&occupant.owner!==player?occupant.id:null);previewCell(cell)}} onBlur={()=>{setRangeFocus(null);previewCell(null)}} onPointerEnter={event=>{if(event.pointerType==='mouse'&&!drag.current?.moved)previewCell(cell)}} onClick={()=>choose(cell)}><title>{label}</title><polygon points={hexPolygon(at.x,at.y)} fill="transparent"/><polygon className="px-focus-ring" points={hexPolygon(at.x,at.y,3)} fill="none"/></g>;
        })}</g>
        {!viewingExchange&&inspecting&&intents.map(intent=>{const at=top(intent.anchor,state);return <g key={intent.id} transform={`translate(${at.x+42} ${at.y-58}) scale(${Math.max(1,screenScale)})`} role="button" tabIndex={0} aria-label={`Inspect ${intent.name}. ${intent.tell}`} aria-pressed={inspectedNpc===intent.id} className="px-npc-inspect" onPointerDown={event=>event.stopPropagation()} onClick={event=>{event.stopPropagation();inspectCreature(intent.id)}} onKeyDown={event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();event.stopPropagation();inspectCreature(intent.id)}}}><circle r="12"/><text y="4">i</text></g>})}
        {speechUnit&&reaction&&<CharacterSpeechV45 reaction={reaction} name={unitName(speechUnit)} anchor={{...speechPoint(speechUnit),y:speechPoint(speechUnit).y-128/screenScale}} viewport={viewport} obstacles={speechObstacles} viewCenter={viewCenter} screenScale={screenScale}/>}
      </svg>
    </div>
    {zoom&&panControls&&<div className="px-pan" aria-label="Pan the battlefield"><button type="button" aria-label="Pan left" onClick={()=>setCamera(clampCamera({...safeCamera,x:safeCamera.x-TILE_STEP_X}))}>←</button><button type="button" aria-label="Pan up" onClick={()=>setCamera(clampCamera({...safeCamera,y:safeCamera.y-TILE_STEP_Y}))}>↑</button><button type="button" aria-label="Center selected champion" onClick={focusView}>◎</button><button type="button" aria-label="Pan down" onClick={()=>setCamera(clampCamera({...safeCamera,y:safeCamera.y+TILE_STEP_Y}))}>↓</button><button type="button" aria-label="Pan right" onClick={()=>setCamera(clampCamera({...safeCamera,x:safeCamera.x+TILE_STEP_X}))}>→</button></div>}
    {!viewingExchange&&npc&&<div className="px-world-inspection" role="status"><div><strong>{npc.name} · {npc.phase==='pulse'?'Acts this exchange':'Resting this exchange'}</strong><p>{npc.tell}</p><p>{combinationFor(npc.elements)?.shortRule}. Its field can mix with the natural ground.</p></div><button aria-label="Close creature inspection" onClick={()=>setInspectedNpc(null)}>×</button></div>}
    {!viewingExchange&&inspecting&&inspectedCharacter&&!onInspectUnit&&<section className="px-character-inspection" aria-label={`${unitName(inspectedCharacter)} details`}>
      <header><div><strong>{unitName(inspectedCharacter)}</strong><span>{unitLineage(inspectedCharacter)} · {unitLabel(inspectedCharacter)}</span></div><button type="button" aria-label="Close character inspection" onClick={()=>setInspectedUnit(null)}>×</button></header>
      <p>{inspectedCharacter.hp}/{inspectedCharacter.maxHp} HP · {inspectedCharacter.flux}/{inspectedCharacter.maxFlux} Flux{statusEntries(inspectedCharacter).map(([id,status])=>` · ${statusInfo(id)?.name||id} ${status?.turns}`).join('')}</p>
      <div className="px-inspected-spells">{availableSpellIds(inspectedCharacter.championId,inspectedCharacter.loadout,inspectedCharacter.affinities,state.learnedSignatures[inspectedCharacter.owner]).map(id=>{const spell=effectiveSpell(inspectedCharacter.championId,id,inspectedCharacter.affinities),availability=castAvailability(state,inspectedCharacter.id,id);return <article key={id} style={{'--spell-color':elementColors[spell.element]} as CSSProperties}><strong>{spell.name}</strong><span>{spellEffectLabel(spell)}</span><small>{availability.cost} Flux · reach {spell.range} · {availability.available?'Ready':availability.reason}</small></article>})}</div>
    </section>}
    {!viewingExchange&&activeCell&&<div className="px-board-readout px-terrain-readout px24-readout" aria-label="Terrain and planned effects">
      <BattleInsight className="px24-tile-insight" title={`${formatTile(activeCell)} · ${hasField(activeCell)?fieldName(activeCell):BIOME_NAMES[activeCell.biome]}`} label={<><b>{formatTile(activeCell)}</b><span>{hasField(activeCell)?fieldName(activeCell):BIOME_NAMES[activeCell.biome]}</span>{isCellSolid(activeCell)&&<small>Blocked</small>}{hasField(activeCell)&&activeCell.ttl&&<small>{activeCell.ttl}r</small>}</>}>
        <p>{isCellSolid(activeCell)?'Blocks movement and sight.':biomeRule(activeCell)}</p>
        {terrainEffectDescription(activeCell)&&<p>{terrainEffectDescription(activeCell)}</p>}
        {activeCell.height>0&&<p>Height {activeCell.height} · climb costs 2 · +1 spell reach downhill.</p>}
        {activeCell.barrier&&<p>Barrier · {activeCell.barrier} round{activeCell.barrier===1?'':'s'} left.</p>}
        {hasField(activeCell)&&activeCell.ttl&&<p>{activeCell.ttl} round{activeCell.ttl===1?'':'s'} left.</p>}
        {activeCell.well&&<p>Spring · +{wellValue(activeCell)} Flux to its occupant after the exchange.</p>}
        {endgameCellDescription(shownEndgame,activeCell)&&<p>{endgameCellDescription(shownEndgame,activeCell)}</p>}
      </BattleInsight>
      {hoverEffort!==null&&<span className="px24-move-cost" title={hoverRoute?.some(isIce)?'Movement effort, including an ice slide':'Movement effort'}>↦ {hoverEffort}</span>}
      {activeUnit&&<BattleInsight className="px24-unit-insight" title={unitName(activeUnit)} color={unitColor(activeUnit)} label={<><span>{unitName(activeUnit)}</span><small>{activeUnit.hp}/{activeUnit.maxHp}</small>{statusEntries(activeUnit).length>0&&<i aria-label={`${statusEntries(activeUnit).length} conditions`}>●</i>}</>}>
        <CombatVitals unit={activeUnit}/><p>{unitLineage(activeUnit)} · {unitLabel(activeUnit)}</p><ul className="px24-condition-details">{activeStatusInsights(activeUnit.statuses).map(status=><li key={status.id}><strong>{status.symbol} {status.name} <small>{status.turns}r</small></strong><p>{status.effect}</p></li>)}</ul>
      </BattleInsight>}
      {canInteract&&!inspecting&&forecast&&forecast.groups.length>0&&<BattleInsight className="px24-forecast-insight" title="Planned fields" label={<><span aria-hidden="true">◇</span><span>{forecast.groups.map(group=>group.name).join(' + ')}</span></>}>
        {forecast.groups.map(group=><p key={group.id}><strong>{group.symbol} {group.name}{group.count>1?` ×${group.count}`:''}</strong><br/>{group.shortRule}</p>)}
        <p className="b24-insight-counter">Rival orders can change this result.</p>
      </BattleInsight>}
    </div>}
    <p className="px-sr-only">{unitPresentation?'Each player has a distinct colour and a named deployment area.':`Your team is ${player===0?'teal':'rust'}; rivals are ${player===0?'rust':'teal'}.`} Team bars show health; gold bars show Flux. A teal boundary marks reachable movement; a dashed gold boundary marks casting reach. Striped hexes are the affected area; brackets mark aim; the ring marks the casting origin after planned movement. Dashed paths show planned moves; straight lines show spell flights. Spells that meet at the same moment combine at the meeting point. All teams act together: targets can move and landings can be blocked. Champion details show status durations. In Move or Inspect mode, hover or focus an enemy to see amber movement and dashed rose spell reach after moving; these are possibilities, not revealed orders. In Move mode, tap an enemy to keep its range visible; Escape or Clear enemy range dismisses it.</p>
  </div>;
}
