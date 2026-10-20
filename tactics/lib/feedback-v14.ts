import {getChampion} from './roster-v7.ts';
import {REACTIONS, STATUS_DEFINITIONS, type SimEvent, type SimState} from './tactics-v14.ts';

/** One presentation clock for the exchange, its replay, and optional audio.
 * These are readable views of one simultaneous result, never initiative steps.
 * The final review has no deadline; RESOLUTION_MS only ends the animation. */
export const RESOLUTION_MS = 6000;
export const PHASE_MS = {cast:1400, impact:2800, settle:4400} as const;
export const CAST_ANTICIPATION_MS = (PHASE_MS.impact-PHASE_MS.cast)*120/450;
export const EVENT_TEXT_MS = 1500;
export const DISPLACEMENT_END_MS = 4000;
export const HEALTH_FEEDBACK_MS = PHASE_MS.settle;
export type ResolutionPhase = 'move'|'cast'|'impact'|'settle';
export const PHASE_LABELS:Record<ResolutionPhase,string> = {move:'Movement',cast:'Casting',impact:'Effects',settle:'Review'};
export function phaseAt(elapsedMs:number):ResolutionPhase {
  if(elapsedMs>=PHASE_MS.settle)return 'settle';
  if(elapsedMs>=PHASE_MS.impact)return 'impact';
  if(elapsedMs>=PHASE_MS.cast)return 'cast';
  return 'move';
}
/** Bounces also describe blocked forced displacement. The public event stream
 * separates it from voluntary movement without consulting either sealed plan. */
export function eventPhase(event:SimEvent,events:readonly SimEvent[]=[]):ResolutionPhase {
  if(event.kind==='move')return 'move';
  if(event.kind==='bounce'){
    if(event.text.includes('simultaneous move blocked'))return 'move';
    if(event.text.includes('simultaneous push blocked'))return 'impact';
    const index=events.indexOf(event);
    const afterMovement=index>=0&&events.slice(0,index).some(previous=>previous.kind!=='guard'&&previous.kind!=='move'&&previous.kind!=='bounce');
    return afterMovement?'impact':'move';
  }
  if(event.kind==='cast'||event.kind==='fizzle'||event.kind==='guard')return 'cast';
  if(event.kind==='score'||event.kind==='respawn')return 'settle';
  return 'impact';
}
export function eventDelayMs(event:SimEvent,events:readonly SimEvent[]=[]):number {
  const phase=eventPhase(event,events);
  if(event.kind==='move')return 50;
  if(event.kind==='bounce')return phase==='move'?PHASE_MS.cast-300:PHASE_MS.impact+300;
  if(phase==='cast')return PHASE_MS.cast;
  if(phase==='settle')return PHASE_MS.settle;
  if(event.kind==='surface')return PHASE_MS.impact+450;
  if(event.kind==='damage'||event.kind==='heal'||event.kind==='defeat')return HEALTH_FEEDBACK_MS;
  return PHASE_MS.impact;
}

export type ExchangeSummary = {score:[number,number]; headline:string; details:string[]};
/** Aggregate outcomes, not the first few events (large areas can emit dozens of reactions). */
export function summarizeExchange(previous:SimState,next:SimState,player:0|1):ExchangeSummary {
  const score:[number,number]=[next.scores[0]-previous.scores[0],next.scores[1]-previous.scores[1]];
  const rival=player===0?1:0;
  const name=(id:string|undefined)=>{const unit=next.units.find(u=>u.id===id);return unit?getChampion(unit.championId).name:'Mage'};
  const events=next.lastResolution;
  const details:string[]=[];
  const ownerOf=(event:SimEvent)=>event.owner??next.units.find(unit=>unit.id===event.unitId)?.owner;
  // A short visible report must explain setbacks before ambient creature releases.
  for(const owner of [player,rival]){
    const fallen=events.filter(event=>event.kind==='defeat'&&ownerOf(event)===owner).map(event=>name(event.unitId));
    if(fallen.length)details.push(`${fallen.join(', ')} fell. ${owner===player?'Rival':'You'} +${fallen.length}.`);
  }
  const ownFizzles=events.filter(event=>event.kind==='fizzle'&&ownerOf(event)===player);
  if(ownFizzles.length)details.push(ownFizzles.map(event=>event.text).join(' '));
  const ownBlocks=events.filter(event=>event.kind==='bounce'&&ownerOf(event)===player&&!ownFizzles.some(fizzle=>fizzle.unitId===event.unitId));
  if(ownBlocks.length)details.push(ownBlocks.map(event=>event.text).join(' '));
  const captures=([player,rival] as const).map(owner=>next.cells.filter(cell=>cell.well&&next.units.some(u=>u.owner===owner&&u.hp>0&&u.respawn===undefined&&u.q===cell.q&&u.r===cell.r)&&!previous.units.some(u=>u.owner===owner&&u.hp>0&&u.respawn===undefined&&u.q===cell.q&&u.r===cell.r)).length);
  if(captures.some(Boolean))details.push(captures.map((count,i)=>count?`${i===0?'You':'Rival'} took ${count} well${count===1?'':'s'}`:'').filter(Boolean).join(' · '));
  // Describe the health the player can actually see. Raw healing events include
  // overheal; calling those recovered HP made full-health casts look productive.
  const health=[...next.units].sort((a,b)=>Number(b.owner===player)-Number(a.owner===player)||a.id.localeCompare(b.id)).flatMap(unit=>{
    const old=previous.units.find(u=>u.id===unit.id);
    if(!old||old.respawn!==undefined||unit.respawn!==undefined||old.hp===unit.hp)return [];
    const delta=unit.hp-old.hp;
    return [`${name(unit.id)} ${delta>0?'+':'−'}${Math.abs(delta)} HP`];
  });
  if(health.length)details.push(health.join(' · '));
  const statusEvents=events.filter(e=>e.kind==='surface'&&e.status);
  for(const id of new Set(statusEvents.map(e=>e.unitId))){const statuses=[...new Set(statusEvents.filter(e=>e.unitId===id).map(e=>STATUS_DEFINITIONS.find(s=>s.id===e.status)?.name||e.status))];details.push(`${name(id)}: ${statuses.join(', ')}.`)}
  const returns=events.filter(e=>e.kind==='respawn').map(e=>name(e.unitId));if(returns.length)details.push(`${returns.join(', ')} returned.`);
  const rivalBlocks=events.filter(event=>event.kind==='bounce'&&ownerOf(event)===rival).length,rivalFizzles=events.filter(event=>event.kind==='fizzle'&&ownerOf(event)===rival).length;
  if(rivalBlocks||rivalFizzles)details.push([rivalBlocks?`${rivalBlocks} rival movement${rivalBlocks===1?'':'s'} blocked`:'',rivalFizzles?`${rivalFizzles} rival spell${rivalFizzles===1?'':'s'} fizzled`:''].filter(Boolean).join(' · '));
  const reactions=events.filter(event=>event.kind==='reaction');
  if(reactions.length){const kinds=[...new Set(reactions.map(event=>event.terrain||next.cells.find(cell=>cell.q===event.q&&cell.r===event.r)?.reactions?.[0]||''))].map(id=>REACTIONS.find(reaction=>reaction.id===id)?.name||id).filter(Boolean);details.push(`${kinds.join(', ')} formed across ${reactions.length} hex${reactions.length===1?'':'es'}.`)}
  const ice=events.filter(event=>event.kind==='surface'&&!event.unitId&&event.terrain==='ice').length;
  const floods=events.filter(event=>event.kind==='surface'&&!event.unitId&&event.terrain==='water').length;
  if(ice)details.push(`${ice} hex${ice===1?' froze':'es froze'}. Entering ice slides to its far edge.`);
  if(floods)details.push(`${floods} hex${floods===1?' flooded':'es flooded'}. Crossing costs 2 movement.`);
  details.push(...new Set(events.filter(event=>event.kind==='inhabitant').map(event=>event.text)));
  return {score,headline:`You +${score[player]} · Rival +${score[rival]}`,details};
}

const labelKinds=new Set(['damage','heal','surface','bounce','fizzle','guard','defeat','respawn']);
/** Large fields get one creation label; individual status and damage labels remain local. */
export function surfaceLabelGroups(events:SimEvent[]):Map<number,number> {
  const groups=new Map<string,number[]>();
  events.forEach((event,index)=>{if(event.kind==='surface'&&!event.unitId&&event.terrain){groups.set(event.terrain,[...(groups.get(event.terrain)||[]),index])}});
  return new Map([...groups.values()].map(indices=>[indices[0],indices.length]));
}
const labelPriority:Record<string,number>={defeat:0,damage:1,heal:2,fizzle:3,surface:4,bounce:5,respawn:6,guard:7};
export type EventLabelLane={row:number;overflow?:number};
/** Three readable labels per hex, with one explicit overflow count. Full events stay in the record. */
export function eventLabelLanes(events:SimEvent[],state:SimState):Map<number,EventLabelLane> {
  const groups=new Map<string,number[]>();
  events.forEach((event,index)=>{if(!labelKinds.has(event.kind))return;const p=event.to||(event.q!==undefined&&event.r!==undefined?{q:event.q,r:event.r}:state.units.find(u=>u.id===event.unitId));if(!p)return;const key=`${p.q},${p.r}`;groups.set(key,[...(groups.get(key)||[]),index])});
  const result=new Map<number,EventLabelLane>();
  for(const indices of groups.values()){indices.sort((a,b)=>(labelPriority[events[a].kind]??9)-(labelPriority[events[b].kind]??9)||a-b);indices.slice(0,3).forEach((index,row)=>result.set(index,{row}));if(indices.length>3)result.set(indices[3],{row:3,overflow:indices.length-3})}
  return result;
}

/** Repeated area reactions animate on every hex but name each combination once. */
export function reactionLabelGroups(events:SimEvent[],state:SimState):Map<number,number> {
  const groups=new Map<string,number[]>();
  events.forEach((event,index)=>{if(event.kind!=='reaction')return;const ids=state.cells.find(c=>c.q===event.q&&c.r===event.r)?.reactions||[event.terrain||'steam'];const key=[...ids].sort().join('+');groups.set(key,[...(groups.get(key)||[]),index])});
  return new Map([...groups.values()].map(indices=>[indices[0],indices.length]));
}

export type SoundCue={at:number;kind:'cast'|'reaction'|'impact'|'blocked'|'score';element?:string;terrain?:string};
/** Largest compound first, then stable IDs: event-array order never changes the mix.
 * At most two casts, one reaction, one score and one blocked cue per phase. */
export function resolutionCues(events:SimEvent[]):SoundCue[] {
  const cues:SoundCue[]=[];
  const elements=[...new Set(events.filter(event=>event.kind==='cast').flatMap(event=>event.elements?.slice(0,1)||[]))].sort();
  elements.slice(0,2).forEach((element,index)=>cues.push({at:PHASE_MS.cast+index*65,kind:'cast',element}));
  const reactions=events.filter(event=>event.kind==='reaction'||event.kind==='inhabitant'&&!event.interrupted).slice().sort((a,b)=>(b.elements?.length||0)-(a.elements?.length||0)||(a.terrain||'').localeCompare(b.terrain||''));
  if(reactions[0])cues.push({at:PHASE_MS.impact,kind:'reaction',element:reactions[0].elements?.[0],terrain:reactions[0].terrain});
  else if(events.some(event=>event.kind==='damage'||event.kind==='heal'))cues.push({at:PHASE_MS.impact,kind:'impact'});
  const blocked=events.filter(event=>event.kind==='bounce'||event.kind==='fizzle'||event.kind==='inhabitant'&&event.interrupted);
  for(const phase of ['move','cast','impact'] as const){
    const at=blocked.filter(event=>eventPhase(event)===phase).map(event=>eventDelayMs(event));
    if(at.length)cues.push({at:Math.min(...at),kind:'blocked'});
  }
  if(events.some(event=>event.kind==='score'&&(event.amount||0)>0||event.kind==='defeat'))cues.push({at:PHASE_MS.settle,kind:'score'});
  return cues.sort((a,b)=>a.at-b.at);
}
