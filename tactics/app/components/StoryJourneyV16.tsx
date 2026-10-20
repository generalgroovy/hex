"use client";
import {useState,type CSSProperties} from 'react';
import {getChampion,teamAffinityTotal,type AffinityAllocation} from '../../lib/roster-v13';
import {STORY_ENCOUNTERS,getStoryEncounter,encounterAffinities,encounterSignature,storyAffinityBudget,recommendStoryEncounter,type StoryProgress} from '../../lib/story-v16';
import {encounterSpecies} from '../../lib/inhabitants-v16';
import {combinationFor} from '../../lib/combinations-v16';
import {ELEMENT_STYLE} from '../../lib/presentation';
import type {Element} from '../../lib/game';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';
import ElementalCreature from './ElementalCreatureV16';
export type StoryJourneyProps={selectedId:string;onSelect:(id:string)=>void;progress:StoryProgress;roster?:readonly string[];affinities?:Readonly<Record<string,AffinityAllocation>>;disabled?:boolean};
const ELEMENTS:Element[]=['water','fire','earth','air','light','dark'];
const title=(word:string)=>word.charAt(0).toUpperCase()+word.slice(1);

export default function StoryJourneyV16({selectedId,onSelect,progress,roster,affinities:companyAffinities,disabled=false}:StoryJourneyProps){
 const [tab,setTab]=useState('challenge'),[creature,setCreature]=useState(0);
 const encounter=getStoryEncounter(selectedId),champion=getChampion(encounter.championId),affinities=encounterAffinities(encounter.id),teamTotal=teamAffinityTotal(encounter.opponents,affinities),budget=storyAffinityBudget(progress),inhabitants=encounterSpecies(encounter.id),species=inhabitants[Math.min(creature,inhabitants.length-1)];
 const spell=encounterSignature(encounter.id),learned=progress.defeated.includes(encounter.id),recommended=recommendStoryEncounter(progress,roster,companyAffinities);
 return <section className="story-journey-v16" aria-label="Story challenge" style={{'--story-element':ELEMENT_STYLE[spell.element].color} as CSSProperties}>
  <label className="story-select"><span>Challenge <small>{progress.defeated.length}/{STORY_ENCOUNTERS.length} won</small></span><select value={selectedId} disabled={disabled} onChange={event=>{onSelect(event.target.value);setCreature(0)}}>{ELEMENTS.map(element=><optgroup key={element} label={title(element)}>{STORY_ENCOUNTERS.filter(entry=>getChampion(entry.championId).element===element).map(entry=><option key={entry.id} value={entry.id}>{getChampion(entry.championId).name}{progress.defeated.includes(entry.id)?' · Won':''}</option>)}</optgroup>)}</select></label>
  <div className="story-character"><PixelChampion id={champion.id} size={92} paused/><div><h3>{champion.name}</h3><p>{title(champion.race)}</p><div className="story-affinities" aria-label={`${champion.name}'s affinities`}>{Object.entries(affinities[champion.id]).map(([element,points])=><span key={element}><ElementIcon element={element as Element} size={17}/>{title(element)} <b>{points}</b></span>)}</div></div></div>
  <nav className="tx-notebook-tabs" aria-label="Challenge details">{[['challenge','Challenge'],['tactics','Tactics'],['creatures','Creatures'],['reward','Reward']].map(([id,label])=><button key={id} aria-pressed={tab===id} onClick={()=>setTab(id)}>{label}</button>)}</nav>
  <div className="story-detail-v16" data-story-panel={tab}>
   {tab==='challenge'&&<><strong>{encounter.title}</strong><p>{encounter.relationship}</p><p className="story-companions">With {encounter.opponents.slice(1).map(id=>getChampion(id).name).join(' and ')}. <b>{teamTotal} team affinity.</b></p><p><b>Defeat the enemy team.</b> {encounter.lesson}</p>{recommended&&recommended.encounterId!==selectedId&&<button className="story-recommend-button" disabled={disabled} onClick={()=>onSelect(recommended.encounterId)}>Suggested: {getChampion(recommended.encounterId).name} →</button>}</>}
   {tab==='tactics'&&<><strong>{encounter.focus}</strong><p>{encounter.situation}</p><p>{encounter.lesson}</p>{recommended&&<small>{recommended.reason}</small>}</>}
   {tab==='creatures'&&species&&<><nav className="tx-notebook-tabs" aria-label="Local creatures">{inhabitants.map((entry,index)=><button key={entry.id} aria-pressed={entry.id===species.id} onClick={()=>setCreature(index)}>{entry.name}</button>)}</nav><div className="story-creature-v16"><svg viewBox="-36 -64 72 78" aria-hidden="true"><ElementalCreature speciesId={species.id} paused/></svg><div><strong>{species.name} · {species.kind}</strong><p>{species.desire}</p><small>{combinationFor(species.elements)?.name}</small></div></div><p>{combinationFor(species.elements)?.description}</p><p>Releases its elements every other turn. Cast <b>{title(species.counterElement)}</b> on its perch to interrupt.</p></>}
   {tab==='reward'&&<><strong><ElementIcon element={spell.element} spell={spell} size={18}/>{spell.name} {learned?'· Learned':''}</strong><p>{spell.description}</p><p>Everyone can equip it at {spell.level} {title(spell.element)} affinity. {champion.name} needs {Math.max(1,spell.level-2)} and pays 2 less Flux.</p><p>{learned?'Reward collected. Replays grant no extra affinity.':budget<18?`First victory: +1 affinity for every character (${budget} → ${budget+1}).`:'Affinity complete. Win to learn this signature.'}</p></>}
  </div>
 </section>;
}
