import {getSpell} from './spells-v20.ts';
import {getChampion} from './roster-v13.ts';
import {combinationById} from './combinations-v16.ts';
import type {SimEvent,SimState} from './tactics-v20.ts';

type ExplainedEvent=SimEvent&{breakdown?:{sources:readonly {unitId?:string;spellId?:string;kind:string;amount:number}[];prevented:number;total:number}};
const sourceKinds:Record<string,string>={burn:'Burn',recoil:'Recoil',link:'Linked volley',field:'Terrain',drain:'Drain'};
const actorName=(state:Pick<SimState,'units'>,id?:string)=>{
 const actor=state.units.find(unit=>unit.id===id);
 return actor?actor.displayName??getChampion(actor.championId).name:undefined;
};
/** Contributions precede shared mitigation. Never invent per-attacker net
 * damage or infer sources from positions in a historical snapshot. */
export function consequenceExplanation(state:Pick<SimState,'units'>,event:ExplainedEvent):string[]{
 const breakdown=event.breakdown;
 if(!breakdown?.sources.length)return [event.text];
 const lines=breakdown.sources.map(source=>{
  const actor=actorName(state,source.unitId);
  let spell:string|undefined;
  if(source.spellId){try{spell=getSpell(source.spellId).name}catch{/* Historical source retains its recorded kind. */}}
  const cause=spell?`${source.kind==='recoil'||source.kind==='drain'?`${sourceKinds[source.kind]} · `:''}${spell}`:(source.kind==='field'&&event.terrain?combinationById(event.terrain)?.name:undefined)??sourceKinds[source.kind]??'Effect';
  return `${source.amount} ${event.kind==='heal'?'healing':'damage'} · ${cause}${actor?` · ${actor}`:''}`;
 });
 if(breakdown.prevented>0)lines.push(`${breakdown.prevented} ${event.kind==='heal'?'healing reduced':'damage prevented'} in total`);
 lines.push(`${breakdown.total} ${event.kind==='heal'?'healing before the health cap':'damage after protection'}`);
 return lines;
}
export function actorConsequenceEvents(state:SimState,id:string):SimEvent[]{
 return state.lastResolution.filter(event=>event.unitId===id&&(['damage','heal','surface','push','bounce','fizzle'].includes(event.kind))||event.kind==='clash'&&!!event.participants?.includes(id));
}
/** Select useful observations without changing the authoritative event order. */
export function prioritizedPhaseEvents(events:readonly SimEvent[]):SimEvent[]{
 const priority=(event:SimEvent)=>({clash:100,fizzle:95,defeat:90,bounce:85,damage:80,heal:75,push:70,surface:event.unitId?65:20,reaction:25,cast:50,move:45,guard:10,respawn:60,score:30,inhabitant:55}[event.kind]);
 return events.map((event,index)=>({event,index})).sort((a,b)=>priority(b.event)-priority(a.event)||a.index-b.index).map(({event})=>event);
}
