"use client";
import {CURRENT_SPELL_MODEL,profileSpell} from '../../lib/spell-profile-v42';
import {useId,useMemo,useRef,useState,type CSSProperties,type KeyboardEvent} from 'react';
import {CHAMPIONS,getChampion,affinityTotal,allocateAffinityBudget,type AffinityAllocation} from '../../lib/roster-v13';
import {ALL_SPELLS,defaultLoadout,repairLoadout,spellAccess,effectiveSpell,getSignature,getSpell,TEACHABLE_SPELLS} from '../../lib/spells-v20';
import {validateTowerBuild,type TowerBuild} from '../../lib/tower-v23';
import {profiledEffectLabel} from '../../lib/spell-profile-label-v42';
import {placeLoadoutSpell} from '../../lib/loadout-interaction-v45';
import {useSpellDragV45} from './useSpellDragV45';
import './loadout-interaction-v45.css';
import {ELEMENT_STYLE} from '../../lib/presentation';
import type {Element} from '../../lib/game';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';
import {CombatReferenceButton} from './CombatReference';
import {TowerSpellPreview} from './TowerKitPreviewV23';
import './tower-v22.css';
import './tower-team-v23.css';

const ELEMENTS:Element[]=['fire','water','earth','air','light','dark'];
const cap=(s:string)=>s[0].toUpperCase()+s.slice(1);
export type TowerCharacterBuilderProps={initial:TowerBuild;budget?:number;learnedSpells?:string[];allowIdentity?:boolean;excludedChampionIds?:string[];onSave:(build:TowerBuild)=>void;onCancel:()=>void};
/** All controls preview a draft; the canonical validator is the only save path. */
export default function TowerCharacterBuilder({initial,budget=5,learnedSpells=[],allowIdentity=true,excludedChampionIds=[],onSave,onCancel}:TowerCharacterBuilderProps){
 const [build,setBuild]=useState<TowerBuild>(()=>structuredClone(initial)),[tab,setTab]=useState<'affinity'|'spells'>('affinity'),[slot,setSlot]=useState(0),[page,setPage]=useState(0),[query,setQuery]=useState(''),[problem,setProblem]=useState(''),[feedback,setFeedback]=useState('');
 const panelId=useId();
 const tabs=useRef<(HTMLButtonElement|null)[]>([]);
 const champion=getChampion(build.championId),spent=affinityTotal(build.affinities),primary=champion.element,limit=Math.min(6,budget-2);
 const learned=useMemo(()=>learnedSpells.filter(id=>TEACHABLE_SPELLS.some(spell=>spell.id===id)),[learnedSpells]);
 const signature=effectiveSpell(champion.id,getSignature(champion.id).id,build.affinities),signatureAccess=spellAccess(champion.id,signature.id,build.affinities,learned);
 const library=useMemo(()=>ALL_SPELLS.filter(spell=>spell.id!==getSignature(build.championId).id&&spellAccess(build.championId,spell.id,build.affinities,learned).unlocked&&effectiveSpell(build.championId,spell.id,build.affinities).cost<=6&&(!learnedSpells.length||learnedSpells.includes(spell.id))&&`${spell.name} ${spell.element}`.toLowerCase().includes(query.toLowerCase())),[build,learned,learnedSpells,query]);
 const pages=Math.max(1,Math.ceil(library.length/6)),shownPage=Math.min(page,pages-1),selected=build.loadout[slot]?effectiveSpell(build.championId,build.loadout[slot],build.affinities):null;
 let valid=false,reason='';try{if(excludedChampionIds.includes(build.championId))throw new Error('Choose a different character from your teammate.');validateTowerBuild(build,budget,learned);if(learnedSpells.length&&build.loadout.some(id=>!learnedSpells.includes(id)))throw new Error('Equip four spells already learned in this run.');valid=true}catch(error){reason=(error as Error).message}
 function changeAffinity(element:Element,delta:number){const value=(build.affinities[element]??0)+delta;if(value<0||value>limit||delta>0&&spent>=budget)return;const affinities:AffinityAllocation={...build.affinities};if(value)affinities[element]=value;else delete affinities[element];if(Object.keys(affinities).length>3)return;let loadout=build.loadout;try{loadout=repairLoadout(build.championId,build.loadout,affinities,learned);if(learnedSpells.length){const choices=learnedSpells.filter(id=>id!==getSignature(build.championId).id&&spellAccess(build.championId,id,affinities,learned).unlocked&&effectiveSpell(build.championId,id,affinities).cost<=6);if(choices.length>=4){const used=new Set<string>();loadout=loadout.map(id=>{const next=choices.includes(id)&&!used.has(id)?id:choices.find(choice=>!used.has(choice))!;used.add(next);return next})}else loadout=build.loadout}}catch{}setBuild({...build,affinities,loadout});setPage(0);setProblem('')}
 function changeIdentity(id:string){const hero=getChampion(id),affinities=allocateAffinityBudget(id,budget);setBuild({championId:id,name:hero.name,affinities,loadout:defaultLoadout(id,affinities,learned)});setPage(0);setProblem('')}
 function chooseSpell(id:string,target=slot){try{const allowed=ALL_SPELLS.filter(spell=>spell.id!==getSignature(build.championId).id&&spellAccess(build.championId,spell.id,build.affinities,learned).unlocked&&effectiveSpell(build.championId,spell.id,build.affinities).cost<=6&&(!learnedSpells.length||learnedSpells.includes(spell.id))).map(spell=>spell.id);const old=build.loadout.indexOf(id),loadout=placeLoadoutSpell(build.loadout,id,target,allowed);setBuild({...build,loadout});setSlot(target);setProblem('');setFeedback(old>=0&&old!==target?`Swapped slots ${old+1} and ${target+1}.`:`Slot ${target+1}: ${getSpell(id).name}.`)}catch(error){setProblem((error as Error).message)}}
 const drag=useSpellDragV45([...new Set([...library.map(spell=>spell.id),...build.loadout])],chooseSpell);
 function save(){if(!valid)return;try{onSave(validateTowerBuild(build,budget,learned))}catch(error){setProblem((error as Error).message)}}
 function keyTab(event:KeyboardEvent<HTMLButtonElement>,index:number){const next=event.key==='Home'?0:event.key==='End'?1:event.key==='ArrowLeft'||event.key==='ArrowRight'?1-index:null;if(next!==null){event.preventDefault();setTab(next===0?'affinity':'spells');tabs.current[next]?.focus()}}
 return <div className="t22-builder tp23-builder">
  <div className="t22-builder-identity"><PixelChampion id={champion.id} size={64} paused/><div><label>Character<select aria-label="Character appearance" value={champion.id} disabled={!allowIdentity} onChange={event=>changeIdentity(event.target.value)}>{CHAMPIONS.map(hero=><option value={hero.id} key={hero.id} disabled={excludedChampionIds.includes(hero.id)}>{hero.name} · {hero.race}</option>)}</select></label><label>Name<input aria-label="Character name" maxLength={24} value={build.name} onChange={event=>setBuild({...build,name:event.target.value})}/></label></div></div>
  <div className="t22-builder-tabs" role="tablist" aria-label="Character configuration"><button ref={node=>{tabs.current[0]=node}} type="button" role="tab" tabIndex={tab==='affinity'?0:-1} aria-selected={tab==='affinity'} aria-controls={`${panelId}-affinity`} onKeyDown={event=>keyTab(event,0)} onClick={()=>setTab('affinity')}>Affinities <b>{spent}/{budget}</b></button><button ref={node=>{tabs.current[1]=node}} type="button" role="tab" tabIndex={tab==='spells'?0:-1} aria-selected={tab==='spells'} aria-controls={`${panelId}-spells`} onKeyDown={event=>keyTab(event,1)} onClick={()=>setTab('spells')}>Four spells</button></div>
  <div className="tp23-builder-body">
   {tab==='affinity'?<section id={`${panelId}-affinity`} role="tabpanel" aria-label="Affinities">
    <p className="t22-builder-rule">3 elements max · {limit} points each · {cap(primary)} highest</p>
    <div className="t22-affinity-editor">{ELEMENTS.map(element=>{const rank=build.affinities[element]??0;return <div key={element} style={{'--element':ELEMENT_STYLE[element].color} as CSSProperties}><ElementIcon element={element} size={24}/><strong>{cap(element)}{element===primary&&<small>signature</small>}</strong><button type="button" aria-label={`Decrease ${element} affinity`} disabled={!rank} onClick={()=>changeAffinity(element,-1)}>−</button><output aria-label={`${element} affinity`}>{rank}</output><button type="button" aria-label={`Increase ${element} affinity`} disabled={spent>=budget||rank>=limit||!rank&&Object.keys(build.affinities).length>=3} onClick={()=>changeAffinity(element,1)}>+</button></div>})}</div>
    <div className="tp23-builder-signature" data-signature-ready={signatureAccess.unlocked}><TowerSpellPreview spell={signature} note={signatureAccess.unlocked?'Signature':`Signature · requires ${signatureAccess.requiredAffinity} ${cap(signature.element)}`}/></div>
   </section>:<section id={`${panelId}-spells`} role="tabpanel" aria-label="Four spells">
    <div className="t22-equipped" role="group" aria-label="Choose spell slot">{build.loadout.map((id,index)=><button type="button" key={index} data-spell-slot={index} {...drag.source(id)} {...drag.target(index)} onKeyDown={event=>drag.reorder(event,id,index)} title="Drag to swap. Alt + left or right also moves a spell." aria-pressed={slot===index} onClick={()=>setSlot(index)} aria-label={`Configure spell ${index+1}: ${getSpell(id).name}`}><small>{index+1}</small><ElementIcon spell={getSpell(id)} size={22}/><strong>{getSpell(id).name}</strong></button>)}</div>
    <p className="spell-drag-help-v45">Choose a slot, then a spell.<span className="pointer-shortcut"> Or drag a spell onto a slot.</span></p>
    <label className="t22-label">Replace spell {slot+1}<input type="search" aria-label="Find available spell" placeholder="Name or element" value={query} onChange={event=>{setQuery(event.target.value);setPage(0)}}/></label>
    <div className="t22-library-grid">{library.slice(shownPage*6,shownPage*6+6).map(base=>{const spell=profileSpell(effectiveSpell(champion.id,base.id,build.affinities),CURRENT_SPELL_MODEL);return <button type="button" key={spell.id} {...drag.source(spell.id)} title={`${spell.name}: ${profiledEffectLabel(spell)}. ${spell.cost} Flux; reach ${spell.range}.`} aria-pressed={selected?.id===spell.id} aria-label={`Equip ${spell.name} in slot ${slot+1}`} onClick={()=>chooseSpell(spell.id)}><ElementIcon spell={spell} size={22}/><span><strong>{spell.name}</strong><small>{spell.cost} Flux · {spell.range?`reach ${spell.range}`:'self'}{build.loadout.includes(spell.id)?` · slot ${build.loadout.indexOf(spell.id)+1}`:''}</small><span className="tp23-library-effect">{profiledEffectLabel(spell)}</span></span></button>})}</div>
    {!library.length&&<p className="tp23-no-results" role="status">No matching spells.</p>}
    {pages>1&&<nav className="t22-pages" aria-label="Configuration spell pages"><button type="button" aria-label="Previous available spells" disabled={shownPage===0} onClick={()=>setPage(shownPage-1)}>←</button><span>{shownPage+1}/{pages}</span><button type="button" aria-label="Next available spells" disabled={shownPage+1>=pages} onClick={()=>setPage(shownPage+1)}>→</button></nav>}
   </section>}
   <aside className="tp23-builder-kit" aria-label={tab==='affinity'?'Current spells':'Selected spell'}>
    <header><strong>{tab==='affinity'?'Spells':`Slot ${slot+1}`}</strong>{allowIdentity&&<span>8 HP · 6 Flux</span>}</header>
    {tab==='affinity'?<ul className="tp23-kit">{build.loadout.map(id=><li key={id}><TowerSpellPreview spell={effectiveSpell(champion.id,id,build.affinities)}/></li>)}</ul>:<>{selected&&<TowerSpellPreview spell={selected}/>}<div className="tp23-builder-signature"><TowerSpellPreview spell={signature} note={signatureAccess.unlocked?'Signature':`Signature · requires ${signatureAccess.requiredAffinity} ${cap(signature.element)}`}/></div></>}
   </aside>
  </div>
  {feedback&&<p className="spell-drag-feedback-v45" role="status">{feedback}</p>}
  <footer className="t22-builder-footer">{(problem||!valid)&&<p role={problem?'alert':'status'}>{problem||reason}</p>}<div><CombatReferenceButton spellModel={CURRENT_SPELL_MODEL} tower caster={{championId:build.championId,affinities:build.affinities,learnedSpells:learned}} spellIds={build.loadout} initialTab="spells"/><button type="button" onClick={onCancel}>Cancel</button><button type="button" className="t22-primary" disabled={!valid} onClick={save}>Use character</button></div></footer>
 </div>;
}
