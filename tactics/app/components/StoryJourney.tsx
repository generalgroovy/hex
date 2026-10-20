"use client";

import type {CSSProperties} from 'react';
import {getChampion} from '../../lib/roster-v10';
import {effectiveSpell,getSignature} from '../../lib/spells-v10';
import {STORY_ENCOUNTERS,getStoryEncounter,type StoryProgress} from '../../lib/story-v10';
import {ELEMENT_STYLE} from '../../lib/presentation';
import type {Element} from '../../lib/game';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';
import './story-journey.css';

export type StoryJourneyProps={selectedId:string;onSelect:(id:string)=>void;progress:StoryProgress;disabled?:boolean};
const ELEMENTS:Element[]=['water','fire','earth','air','light','dark'];
const title=(word:string)=>word.charAt(0).toUpperCase()+word.slice(1);

export default function StoryJourney({selectedId,onSelect,progress,disabled=false}:StoryJourneyProps){
  const encounter=getStoryEncounter(selectedId),champion=getChampion(encounter.championId),signature=getSignature(champion.id);
  const spell=effectiveSpell(champion.id,signature.id,{[signature.element]:signature.level});
  const learned=progress.defeated.includes(encounter.id);
  return <section className="story-journey" aria-labelledby="story-journey-title" style={{'--story-element':ELEMENT_STYLE[spell.element].color} as CSSProperties}>
    <div className="story-heading"><h2 id="story-journey-title">Story</h2><span>{progress.defeated.length} / {STORY_ENCOUNTERS.length} spells learned</span></div>
    <label className="story-select"><span>Challenge</span><select value={selectedId} disabled={disabled} onChange={event=>onSelect(event.target.value)}>
      {ELEMENTS.map(element=><optgroup key={element} label={title(element)}>{STORY_ENCOUNTERS.filter(entry=>getChampion(entry.championId).element===element).map(entry=><option key={entry.id} value={entry.id}>{getChampion(entry.championId).name}{progress.defeated.includes(entry.id)?' · Learned':''}</option>)}</optgroup>)}
    </select></label>
    <div className="story-character">
      <span className="story-portrait"><PixelChampion id={champion.id} size={100} paused/></span>
      <div><h3>{champion.name}</h3><p className="story-race">{title(champion.race)}</p><div className="story-affinities" aria-label={`${champion.name}'s affinities`}>{Object.entries(champion.affinities).map(([element,points])=><span key={element}><ElementIcon element={element as Element} size={17}/>{title(element)} <b>{points}</b></span>)}</div></div>
    </div>
    <p className="story-situation"><strong>{encounter.title}.</strong> {encounter.situation}</p>
    <p className="story-companions">With {encounter.opponents.slice(1).map(id=>getChampion(id).name).join(' and ')}.</p>
    <div className={`story-reward${learned?' is-learned':''}`}>
      <div className="story-reward-heading"><ElementIcon element={spell.element} size={22}/><strong>{spell.name}</strong><span>{learned?'Learned':'Win to learn'}</span></div>
      <p><strong>At {spell.level} {title(spell.element)} affinity:</strong> {spell.description}</p>
      <p className="story-reward-rule">Available to every character after victory. Requires {spell.level} {title(spell.element)} affinity; {champion.name} requires {Math.max(1,spell.level-2)} and pays 2 less Flux.</p>
    </div>
    <p className="story-progress-note">Story progress stays in this browser. Every encounter can be replayed.</p>
  </section>;
}
