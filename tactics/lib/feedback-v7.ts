import {getChampion} from './roster-v7.ts';
import {REACTIONS, STATUS_DEFINITIONS, type SimEvent, type SimState} from './tactics-v7.ts';

/** One presentation clock for the first exchange, its replay, and optional audio. */
export const RESOLUTION_MS = 2800;
export const PHASE_MS = {cast:450, impact:900, settle:1700} as const;
export const EVENT_TEXT_MS = 1100;
export function eventDelayMs(event:SimEvent):number {
  if(event.kind==='move'||event.kind==='bounce')return 50;
  if(event.kind==='cast')return PHASE_MS.cast;
  if(event.kind==='reaction')return PHASE_MS.impact;
  if(event.kind==='surface')return 1350;
  if(event.kind==='respawn')return 1550;
  if(event.kind==='score')return PHASE_MS.settle;
  return 1000;
}

export type ExchangeSummary = {score:[number,number]; headline:string; details:string[]};
/** Aggregate outcomes, not the first few events (large areas can emit dozens of reactions). */
export function summarizeExchange(previous:SimState,next:SimState,player:0|1):ExchangeSummary {
  const score:[number,number]=[next.scores[0]-previous.scores[0],next.scores[1]-previous.scores[1]];
  const rival=player===0?1:0;
  const name=(id:string|undefined)=>{const unit=next.units.find(u=>u.id===id);return unit?getChampion(unit.championId).name:'Mage'};
  const events=next.lastResolution;
  const details:string[]=[];
  const fallen=events.filter(e=>e.kind==='defeat').map(e=>name(e.unitId));
  if(fallen.length)details.push(`${fallen.join(', ')} fell. Each fall awards the opponent 1 point.`);
  const blocks=events.filter(e=>e.kind==='bounce').length,fizzles=events.filter(e=>e.kind==='fizzle').length;
  if(blocks||fizzles)details.push([blocks?`${blocks} blocked movement${blocks===1?'':'s'}`:'',fizzles?`${fizzles} spell${fizzles===1?'':'s'} fizzled`:'' ].filter(Boolean).join('; ')+'.');
  const reactions=events.filter(e=>e.kind==='reaction');
  if(reactions.length){const kinds=[...new Set(reactions.flatMap(e=>next.cells.find(c=>c.q===e.q&&c.r===e.r)?.reactions||[e.terrain||'']))].map(id=>REACTIONS.find(r=>r.id===id)?.name||id).filter(Boolean);details.push(`${kinds.join(', ')} formed across ${reactions.length} hex${reactions.length===1?'':'es'}.`)}
  // Describe the health the player can actually see. Raw healing events include
  // overheal; calling those recovered HP made full-health casts look productive.
  const health=next.units.flatMap(unit=>{
    const old=previous.units.find(u=>u.id===unit.id);
    if(!old||old.respawn!==undefined||unit.respawn!==undefined||old.hp===unit.hp)return [];
    const delta=unit.hp-old.hp;
    return [`${name(unit.id)} ${delta>0?'+':'−'}${Math.abs(delta)} HP`];
  });
  if(health.length)details.push(health.join(' · '));
  const captures=([player,rival] as const).map(owner=>next.cells.filter(cell=>cell.well&&next.units.some(u=>u.owner===owner&&u.hp>0&&u.respawn===undefined&&u.q===cell.q&&u.r===cell.r)&&!previous.units.some(u=>u.owner===owner&&u.hp>0&&u.respawn===undefined&&u.q===cell.q&&u.r===cell.r)).length);
  if(captures.some(Boolean))details.push(captures.map((count,i)=>count?`${i===0?'You':'Rival'} took ${count} well${count===1?'':'s'}`:'').filter(Boolean).join(' · '));
  const statusEvents=events.filter(e=>e.kind==='surface'&&e.status);
  for(const id of new Set(statusEvents.map(e=>e.unitId))){const statuses=[...new Set(statusEvents.filter(e=>e.unitId===id).map(e=>STATUS_DEFINITIONS.find(s=>s.id===e.status)?.name||e.status))];details.push(`${name(id)}: ${statuses.join(', ')}.`)}
  const returns=events.filter(e=>e.kind==='respawn').map(e=>name(e.unitId));if(returns.length)details.push(`${returns.join(', ')} returned.`);
  return {score,headline:`You +${score[player]} · Rival +${score[rival]}`,details};
}

const labelKinds=new Set(['damage','heal','surface','bounce','fizzle','guard','defeat','respawn']);
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

export type SoundCue={at:number;kind:'cast'|'reaction'|'impact'|'blocked'|'score';element?:string};
/** One cue per semantic stage prevents a 19-cell spell becoming 19 simultaneous sounds. */
export function resolutionCues(events:SimEvent[]):SoundCue[] {
  const cues:SoundCue[]=[];
  const cast=events.find(e=>e.kind==='cast');if(cast)cues.push({at:PHASE_MS.cast,kind:'cast',element:cast.elements?.[0]});
  if(events.some(e=>e.kind==='reaction'))cues.push({at:PHASE_MS.impact,kind:'reaction'});
  else if(events.some(e=>e.kind==='damage'||e.kind==='heal'))cues.push({at:PHASE_MS.impact,kind:'impact'});
  if(events.some(e=>e.kind==='bounce'||e.kind==='fizzle'))cues.push({at:1150,kind:'blocked'});
  if(events.some(e=>e.kind==='score'&&(e.amount||0)>0||e.kind==='defeat'))cues.push({at:PHASE_MS.settle,kind:'score'});
  return cues;
}
