"use client";
import type {CSSProperties} from 'react';
import {getChampion,teamAffinityTotal,type AffinityAllocation} from '../../lib/roster-v13';
import {STORY_ENCOUNTERS,getStoryEncounter,encounterAffinities,encounterSignature,storyAffinityBudget,recommendStoryEncounter,type StoryProgress} from '../../lib/story-v15';
import {CHARACTER_DESIGN} from '../../lib/character-design-v13';
import {encounterSpecies} from '../../lib/inhabitants-v15';
import {combinationFor} from '../../lib/combinations-v15';
import {ELEMENT_STYLE} from '../../lib/presentation';
import type {Element} from '../../lib/game';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';
import ElementalCreature from './ElementalCreatureV15';
import './story-journey.css';
import './affinity-progression.css';
import './world-design-v13.css';

export type StoryJourneyProps={selectedId:string;onSelect:(id:string)=>void;progress:StoryProgress;roster?:readonly string[];affinities?:Readonly<Record<string,AffinityAllocation>>;disabled?:boolean};
const ELEMENTS:Element[]=['water','fire','earth','air','light','dark'];
const title=(word:string)=>word.charAt(0).toUpperCase()+word.slice(1);
export default function StoryJourneyV15({selectedId,onSelect,progress,roster,affinities:companyAffinities,disabled=false}:StoryJourneyProps){
 const encounter=getStoryEncounter(selectedId),champion=getChampion(encounter.championId);
 const affinities=encounterAffinities(encounter.id),teamTotal=teamAffinityTotal(encounter.opponents,affinities),budget=storyAffinityBudget(progress),inhabitants=encounterSpecies(encounter.id);
 const spell=encounterSignature(encounter.id),learned=progress.defeated.includes(encounter.id),recommended=recommendStoryEncounter(progress,roster,companyAffinities);
 return <section className="story-journey" aria-labelledby="story-journey-title" style={{'--story-element':ELEMENT_STYLE[spell.element].color} as CSSProperties}>
  <div className="story-heading"><h2 id="story-journey-title">Story</h2><span>{progress.defeated.length} / {STORY_ENCOUNTERS.length} won</span></div>
  {recommended&&<div className="story-recommendation"><span><strong>{recommended.encounterId===selectedId?'Suggested challenge':`Suggested: ${getChampion(recommended.encounterId).name}`}</strong><small>{recommended.reason} Choose any challenge.</small></span>{recommended.encounterId!==selectedId&&<button type="button" disabled={disabled} onClick={()=>onSelect(recommended.encounterId)}>Choose</button>}</div>}
  <label className="story-select"><span>Challenge</span><select value={selectedId} disabled={disabled} onChange={event=>onSelect(event.target.value)}>
   {ELEMENTS.map(element=><optgroup key={element} label={title(element)}>{STORY_ENCOUNTERS.filter(entry=>getChampion(entry.championId).element===element).map(entry=><option key={entry.id} value={entry.id}>{getChampion(entry.championId).name}{progress.defeated.includes(entry.id)?' · Won':''}</option>)}</optgroup>)}
  </select></label>
  <div className="story-character"><span className="story-portrait"><PixelChampion id={champion.id} size={88} paused/></span><div><h3>{champion.name}</h3><p className="story-race">{title(champion.race)}</p><div className="story-affinities" aria-label={`${champion.name}'s affinities`}>{Object.entries(affinities[champion.id]).map(([element,points])=><span key={element}><ElementIcon element={element as Element} size={17}/>{title(element)} <b>{points}</b></span>)}</div></div></div>
  <p className="story-situation"><strong>{encounter.title}.</strong> {encounter.relationship}</p>
  <p className="story-role">{CHARACTER_DESIGN[champion.id].role} · {champion.description}</p>
  <p className="story-companions">With {encounter.opponents.slice(1).map(id=>getChampion(id).name).join(' and ')}. <strong>{teamTotal} team affinity.</strong></p>
  {encounter.focus!=='Defeat the enemy team'&&<p className="story-objective"><strong>Defeat all three opponents.</strong> Fallen characters stay out.</p>}
  <div className="story-lesson"><strong>{encounter.focus}</strong><p>{encounter.lesson}</p></div>
  <details className="story-tactics"><summary>Opponent tactics</summary><p>{encounter.situation}</p></details>
  <details className="story-inhabitants"><summary>Local inhabitants · {inhabitants.map(species=>species.name).join(', ')}</summary>
   <ul className="story-inhabitant-list">{inhabitants.map(species=>{const mixture=combinationFor(species.elements);return <li key={species.id}>
    <svg className="story-inhabitant-portrait" viewBox="-36 -64 72 78" aria-hidden="true"><ElementalCreature speciesId={species.id} paused/></svg>
    <div className="story-inhabitant-copy"><strong>{species.name} · {species.kind}</strong><p>{species.desire}</p><div className="story-inhabitant-elements">{species.elements.map(element=><span key={element}><ElementIcon element={element} size={14}/>{title(element)}</span>)}</div><small>{mixture?.name}: {mixture?.description}</small><small className="story-inhabitant-rule">Releases its elements every other turn. A spell of {title(species.counterElement)} on its perch interrupts the release.</small></div>
   </li>})}</ul>
   <p className="story-inhabitant-rule">Their next action is shown on the battlefield. Both teams can use or interrupt it; existing ground can change the mixture.</p>
  </details>
  <details className={`story-reward${learned?' is-learned':''}`}><summary className="story-reward-heading"><ElementIcon element={spell.element} size={20}/><strong>{spell.name}</strong><span>{learned?'Learned':'Victory reward'}</span></summary>
   <p>{spell.description}</p><p className="story-reward-rule">Shown at the opponent’s {affinities[champion.id][spell.element]} {title(spell.element)} affinity. Your allocation determines its strength.</p><p className="story-reward-rule">Everyone can equip it at {spell.level} {title(spell.element)} affinity. {champion.name} needs {Math.max(1,spell.level-2)} and pays 2 less Flux.</p>
  </details>
  <p className="story-affinity-reward">{learned?'Reward collected. Replays grant no extra affinity.':budget<18?`First victory: +1 affinity for every character (${budget} → ${budget+1}).`:'Affinity complete. Win to learn this signature.'}</p>
  <p className="story-progress-note">Progress saved in this browser.</p>
 </section>;
}
