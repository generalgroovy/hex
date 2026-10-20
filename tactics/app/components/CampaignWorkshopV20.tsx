"use client";
import {useMemo,useRef,useState} from 'react';
import {CHAMPIONS,getChampion,affinityTotal} from '../../lib/roster-v13';
import {type CharacterBuild} from '../../lib/character-creation-v17';
import {ALL_SPELLS,effectiveSpell,getSignature,repairLoadout,spellAccess,spellCost} from '../../lib/spells-v20';
import {campaignAffinityBudget,campaignAffinityRankCap,learnedCampaignSpells,availableCampaignCreatures,type CampaignProfile} from '../../lib/story-v20';
import {getCreature,CREATURE_PERKS} from '../../lib/campaign-creatures-v20';
import {changeCampaignAppearance,campaignDraftHint,campaignSpellEntry,campaignSpellLibrary,equipCampaignSpell,compareCampaignSpells,repairedSpellSlots,type LibraryFilter} from '../../lib/campaign-workshop-v20';
import {CURRENT_SPELL_MODEL,profileSpell,spellProfileLabel} from '../../lib/spell-profile-v42';
import {profiledEffectLabel,profiledSpellDescription} from '../../lib/spell-profile-label-v42';
import SpellProfile from './SpellProfileV42';
import type {Element} from '../../lib/game';
import PixelChampion from './PixelChampion';
import CombatCreature from './CombatCreatureV19';
import ElementIcon from './ElementIcon';
import SpellFootprint,{SHAPE_NAME} from './SpellFootprint';
import './campaign-workshop-v20.css';
import {useSpellDragV45} from './useSpellDragV45';
import './loadout-interaction-v45.css';

export type WorkshopTab='hero'|'affinities'|'spells'|'companions';
type Props={profile:CampaignProfile;initialTab?:WorkshopTab;initialSpellId?:string;onChallenge?:(creatureId:string)=>void;onHero:(hero:CharacterBuild)=>void;onCompanions:(ids:[string,string])=>void;onPendingChange:(pending:boolean)=>void};
const ELEMENTS:Element[]=['fire','water','earth','air','light','dark'];
const cap=(word:string)=>word.charAt(0).toUpperCase()+word.slice(1);

export default function CampaignWorkshop({profile,initialTab='hero',initialSpellId,onChallenge,onHero,onCompanions,onPendingChange}:Props){
 const [tab,setTab]=useState<WorkshopTab>(initialSpellId?'spells':initialTab),[draft,setDraft]=useState(profile.hero),[error,setError]=useState(''),[hint,setHint]=useState(''),[feedback,setFeedback]=useState('');
 const [slot,setSlot]=useState(0),[filter,setFilter]=useState<Element|'all'>('all'),[page,setPage]=useState(0),[companionSlot,setCompanionSlot]=useState(0),[creatureFocus,setCreatureFocus]=useState(profile.companions[0]);

 const previewHeading=useRef<HTMLHeadingElement|null>(null),libraryList=useRef<HTMLDivElement|null>(null);
 const [query,setQuery]=useState(''),[libraryFilter,setLibraryFilter]=useState<LibraryFilter>(initialSpellId?'all':'ready'),[selectedSpell,setSelectedSpell]=useState(initialSpellId??profile.hero.loadout[0]),[detailOpen,setDetailOpen]=useState(!!initialSpellId);
 const hero=getChampion(draft.championId),budget=campaignAffinityBudget(profile),rankCap=campaignAffinityRankCap(profile),spent=affinityTotal(draft.affinities),learned=learnedCampaignSpells(profile),signature=getSignature(hero.id);
 const spells=useMemo(()=>campaignSpellLibrary(profile,draft,{query,element:filter,filter:libraryFilter}),[profile,draft,query,filter,libraryFilter]);
 const selectedId=ALL_SPELLS.some(entry=>entry.id===selectedSpell)?selectedSpell:draft.loadout[slot];
 const candidate=campaignSpellEntry(profile,draft,selectedId),current=profileSpell(effectiveSpell(hero.id,draft.loadout[slot],draft.affinities),CURRENT_SPELL_MODEL),comparison=compareCampaignSpells(current,candidate.effective);
 const pages=Math.max(1,Math.ceil(spells.length/6)),currentPage=Math.min(page,pages-1);
 const recruits=availableCampaignCreatures(profile).filter(creature=>filter==='all'||creature.elements.includes(filter)),recruitPages=Math.max(1,Math.ceil(recruits.length/6)),recruitPage=Math.min(page,recruitPages-1),focused=getCreature(creatureFocus);
 const perk=CREATURE_PERKS.find(entry=>entry.id===focused.perkId);
 function edit(next:CharacterBuild){setDraft(next);const pending=campaignDraftHint(next);setHint(pending??'');if(pending){setError('');onPendingChange(true);return}try{onHero(next);setError('');onPendingChange(false)}catch(problem){setError((problem as Error).message);onPendingChange(true)}}
 function train(element:Element,delta:number){const affinities={...draft.affinities,[element]:(draft.affinities[element]??0)+delta};if(!affinities[element])delete affinities[element];let loadout=draft.loadout;try{if(affinityTotal(affinities)>=5)loadout=repairLoadout(hero.id,loadout,affinities,learned)}catch{}const repaired=repairedSpellSlots(draft.loadout,loadout);setFeedback(repaired.length?`Spells adjusted: ${repaired.join("; ")}`:"");edit({...draft,affinities,loadout})}
 function appearance(id:string){try{const next=changeCampaignAppearance(draft,id,learned,rankCap),repaired=repairedSpellSlots(draft.loadout,next.loadout);setFeedback(repaired.length?`Spells adjusted: ${repaired.join("; ")}`:"");edit(next)}catch(problem){setError((problem as Error).message)}}
 function changeTab(next:WorkshopTab){setTab(next);setPage(0);setFilter('all')}
 function inspectSpell(id:string){setSelectedSpell(id);setDetailOpen(true);requestAnimationFrame(()=>previewHeading.current?.focus())}
 function browse(){setDetailOpen(false);requestAnimationFrame(()=>{const list=libraryList.current;(list?.querySelector<HTMLButtonElement>('button[aria-pressed=true]')??list?.querySelector<HTMLButtonElement>('button'))?.focus()})}
 function placeSpell(id:string,target:number){try{const entry=campaignSpellEntry(profile,draft,id),next=equipCampaignSpell(profile,draft,target,id);edit(next);setSlot(target);setSelectedSpell(id);setFeedback(entry.equippedSlot>=0&&entry.equippedSlot!==target?`Swapped slots ${target+1} and ${entry.equippedSlot+1}.`:`Slot ${target+1}: ${entry.spell.name}.`)}catch(problem){setError((problem as Error).message)}}
 function equip(){placeSpell(candidate.spell.id,slot)}
 const drag=useSpellDragV45([...new Set([...spells.filter(entry=>entry.ready&&!entry.fixed).map(entry=>entry.spell.id),...draft.loadout])],placeSpell);
 function recruit(id:string){try{const next=[...profile.companions] as [string,string];next[companionSlot]=id;onCompanions(next);setError('')}catch(problem){setError((problem as Error).message)}}
 const filters=<div className="c19-element-filter" role="group" aria-label="Filter by element"><button aria-pressed={filter==='all'} onClick={()=>{setFilter('all');setPage(0)}}>All</button>{ELEMENTS.map(element=><button key={element} title={cap(element)} aria-label={cap(element)} aria-pressed={filter===element} onClick={()=>{setFilter(element);setPage(0)}}><ElementIcon element={element} size={23}/></button>)}</div>;
 return <section className="c19-workshop c20-workshop" aria-label="Prepare your party">
  <nav className="c19-tabs" aria-label="Party preparation">{([['hero','Hero'],['affinities','Affinity'],['spells','Spells'],['companions','Companions']] as const).map(([id,label])=><button key={id} aria-pressed={tab===id} onClick={()=>changeTab(id)}>{label}{id==='affinities'&&budget>spent&&<b>{budget-spent}</b>}</button>)}</nav>
  {hint&&<p className="c19-help" role="status">{hint}</p>}{feedback&&<p className="c20-feedback" role="status">{feedback}</p>}{error&&<p className="c19-error" role="alert">{error}</p>}
  {tab==='hero'&&<div className="c19-hero-editor"><PixelChampion id={hero.id} size={136} paused/><div><label>Name<input maxLength={24} value={draft.name} onChange={event=>edit({...draft,name:event.target.value})}/></label><label>Appearance · race<select value={hero.id} onChange={event=>appearance(event.target.value)}>{CHAMPIONS.map(champion=><option key={champion.id} value={champion.id}>{champion.name} · {champion.race}</option>)}</select></label><div className="c19-affinity-marks">{ELEMENTS.filter(element=>draft.affinities[element]).map(element=><span key={element} title={cap(element)}><ElementIcon element={element} label={cap(element)} size={24}/><b>{draft.affinities[element]}</b></span>)}</div><p>{hero.description}</p><button onClick={()=>changeTab('affinities')}>{budget>spent?`Spend ${budget-spent} affinity`:'Change affinities'} →</button></div><article className="c19-signature"><ElementIcon element={signature.element} spell={signature} size={28}/><div><small>Creator signature</small><strong>{signature.name}</strong><p>{profiledEffectLabel(profileSpell(effectiveSpell(hero.id,signature.id,draft.affinities),CURRENT_SPELL_MODEL))}</p><small>{spellAccess(hero.id,signature.id,draft.affinities,learned).reason??`${spellCost(hero.id,signature.id,draft.affinities)} Flux · creator discount`}</small></div></article></div>}
  {tab==='affinities'&&<><div className="c19-editor-heading"><strong>{spent}/{budget} affinity</strong><span>{budget-spent?`${budget-spent} unspent`:'All spent'}</span></div><p className="c19-help">Up to three elements. {cap(hero.element)} stays highest.</p><div className="c19-affinity-grid">{ELEMENTS.map(element=>{const rank=draft.affinities[element]??0,primary=draft.affinities[hero.element]??0,highestOther=Math.max(0,...ELEMENTS.filter(entry=>entry!==hero.element).map(entry=>draft.affinities[entry]??0));return <article key={element}><header><ElementIcon element={element} size={26}/><strong>{cap(element)}</strong></header><div><button aria-label={`Reduce ${element} affinity`} disabled={rank<=(element===hero.element?Math.max(2,highestOther):0)} onClick={()=>train(element,-1)}>−</button><output>{rank}<small>/{rankCap}</small></output><button aria-label={`Increase ${element} affinity`} disabled={spent>=budget||rank>=(rankCap)||(element!==hero.element&&rank>=primary)||(!rank&&Object.keys(draft.affinities).length>=3)} onClick={()=>train(element,1)}>+</button></div><small>{rank===rankCap?rankCap<6?`Next victory: level ${rankCap+1}`:'Maximum':rank===2?'Next: advanced spells':rank===1||rank===4?'Next: longer reach':rank===3?'Next: longer effects':'Next: stronger spells'}</small></article>})}</div><button className="c19-primary" onClick={()=>changeTab('spells')}>Choose spells →</button></>}
  {tab==='spells'&&<>
   <div className="c19-loadout c20-loadout" role="group" aria-label="Four equipped spells">
    {draft.loadout.map((id,index)=>{const entry=effectiveSpell(hero.id,id,draft.affinities);return <button key={index} data-spell-slot={index} {...drag.source(id)} {...drag.target(index)} onKeyDown={event=>drag.reorder(event,id,index)} title="Drag to swap. Alt + left or right also moves a spell." aria-pressed={slot===index} onClick={()=>setSlot(index)} aria-label={`Replace spell slot ${index+1}: ${entry.name}`}><ElementIcon element={entry.element} spell={entry} size={23}/><span>{entry.name}</span><small>{index+1}</small></button>})}
   </div>
   <p className="spell-drag-help-v45">Choose a slot, then a spell.<span className="pointer-shortcut"> Or drag a spell onto a slot.</span></p>
   <div className="c20-library" data-detail-open={detailOpen}>
    <section className="c20-library-browse" aria-label="Spell library">
     <label className="c20-search"><span>Find a spell or enemy</span><input type="search" value={query} placeholder="Name, enemy or effect" onChange={event=>{setQuery(event.target.value);setPage(0)}}/></label>
     <div className="c20-library-filters">
      <label><span>Element</span><select value={filter} onChange={event=>{setFilter(event.target.value as Element|'all');setPage(0)}}><option value="all">All elements</option>{ELEMENTS.map(element=><option key={element} value={element}>{cap(element)}</option>)}</select></label>
      <label><span>Show</span><select value={libraryFilter} onChange={event=>{setLibraryFilter(event.target.value as LibraryFilter);setPage(0)}}><option value="ready">Ready to use</option><option value="learned">Learned spells</option><option value="all">All spells</option></select></label>
     </div>
     <div className="c20-library-list" ref={libraryList}>
      {spells.slice(currentPage*6,currentPage*6+6).map(entry=><button key={entry.spell.id} {...drag.source(entry.spell.id,entry.ready&&!entry.fixed)} title={entry.ready?`${profiledEffectLabel(entry.effective)}. ${entry.effective.cost} Flux; reach ${entry.effective.range}.`:entry.requirements.join(" ")} aria-pressed={candidate.spell.id===entry.spell.id} onClick={()=>inspectSpell(entry.spell.id)} aria-label={`${entry.spell.name}. ${entry.origin?`From ${entry.origin.name}. `:''}${entry.fixed?'Native signature. ':entry.equippedSlot>=0?`Equipped in slot ${entry.equippedSlot+1}. `:''}${entry.ready?`${entry.effective.cost} Flux.`:entry.requirements.join(' ')}`}><ElementIcon element={entry.spell.element} spell={entry.spell} size={23}/><span><strong>{entry.spell.name}</strong><small>{entry.origin?.name??'Core spell'}</small><small className={entry.ready?'is-ready':'is-locked'}>{entry.fixed?'Signature':entry.equippedSlot>=0?`Slot ${entry.equippedSlot+1}`:entry.ready?`${entry.effective.cost} Flux · affinity ${entry.requiredAffinity}`:entry.learned?`${cap(entry.spell.element)} ${entry.affinity}/${entry.requiredAffinity}`:'Not learned'}</small></span></button>)}
     </div>
     {!spells.length&&<div className="c20-library-empty"><p>No spells match these filters.</p>{libraryFilter!=='all'&&<button onClick={()=>{setLibraryFilter('all');setPage(0)}}>Include locked spells</button>}</div>}
     <nav className="c19-pagination c20-pagination" aria-label="Spell pages"><button disabled={currentPage===0} onClick={()=>setPage(currentPage-1)} aria-label="Previous spells">←</button><span role="status" aria-live="polite">{spells.length?`${currentPage*6+1}–${Math.min(spells.length,currentPage*6+6)}`:'0'} / {spells.length}</span><button disabled={currentPage+1>=pages} onClick={()=>setPage(currentPage+1)} aria-label="More spells">→</button></nav>
    </section>
    <section className="c20-spell-preview" aria-label="Selected spell">
     <button className="c20-back-to-library" onClick={browse}>← Spell library</button>
     <header><ElementIcon element={candidate.spell.element} spell={candidate.spell} size={30}/><div><h3 ref={previewHeading} tabIndex={-1}>{candidate.spell.name}</h3><small>{candidate.requiredAffinity?`${cap(candidate.spell.element)} ${candidate.affinity} · needs ${candidate.requiredAffinity}`:"No affinity required"}</small></div><b>{candidate.effective.cost} Flux</b></header>
     <p className="c20-effect"><SpellFootprint shape={candidate.effective.shape}/><span>{profiledEffectLabel(candidate.effective)}</span></p>{candidate.effective.fieldElements&&<div className="c20-field-elements"><small>Adds to the ground</small>{candidate.effective.fieldElements.map(element=><ElementIcon key={element} element={element} label={cap(element)} size={18}/>)}</div>}
     {candidate.origin?<div className="c20-spell-origin">{candidate.origin.creatureId?<CombatCreature creatureId={candidate.origin.creatureId} size={40}/>:candidate.origin.championId?<PixelChampion id={candidate.origin.championId} size={40} paused/>:null}<div><strong>{candidate.origin.name}</strong><small>{candidate.fixed?'Your signature · fixed fifth spell':candidate.learned?'Learned from this enemy':'Defeat this enemy to learn it'}</small></div></div>:<p className="c20-core-note">Core spell · already known</p>}
     {!!candidate.requirements.length&&<ul className="c20-requirements" id="c20-spell-requirements">{candidate.requirements.map(requirement=><li key={requirement}>{requirement}</li>)}</ul>}
     {candidate.origin?.creatureId&&!candidate.learned&&onChallenge&&(availableCampaignCreatures(profile).some(creature=>creature.id===candidate.origin!.creatureId)?<button className="c20-challenge" disabled={!!campaignDraftHint(draft)||!!error} onClick={()=>onChallenge(candidate.origin!.creatureId!)}>Challenge {candidate.origin.name} →</button>:<small>This creature appears later in the journey.</small>)}
     {candidate.effective.counterplay&&<p className="c20-counterplay"><b>Counterplay.</b> {candidate.effective.counterplay}</p>}<details className="c20-full-effects"><summary>Full effects and conditions</summary><SpellProfile spell={candidate.effective}/><p>{profiledSpellDescription(candidate.effective)}</p></details>
     <div className="c20-comparison">
      <header><span>Slot {slot+1} · {current.name}</span><span>{candidate.spell.id===current.id?'Equipped':`→ ${candidate.spell.name}`}</span></header>
      <table aria-label={`Compare ${current.name} with ${candidate.spell.name}`}><thead><tr><th scope="col">Stat</th>{candidate.spell.id!==current.id&&<th scope="col">Current</th>}<th scope="col">{candidate.spell.id===current.id?'Value':'Selected'}</th></tr></thead><tbody>{comparison.map(row=><tr key={row.label}><th scope="row">{row.label}</th>{candidate.spell.id!==current.id&&<td>{row.current}</td>}<td>{row.candidate}{row.change&&<small> ({row.change})</small>}</td></tr>)}</tbody></table>
     </div>
     <button className="c19-primary c20-equip" aria-describedby={candidate.requirements.length?"c20-spell-requirements":undefined} disabled={!candidate.ready||candidate.fixed||candidate.equippedSlot===slot} onClick={equip}>{candidate.fixed?'Fixed signature':candidate.equippedSlot===slot?'Equipped in this slot':!candidate.ready?'Requirements not met':candidate.equippedSlot>=0?`Swap with slot ${candidate.equippedSlot+1}`:`Equip in slot ${slot+1}`}</button>
    </section>
   </div>
  </>}
  {tab==='companions'&&<><div className="c19-companion-slots" role="group" aria-label="Companion slots">{profile.companions.map((id,index)=><button key={index} aria-pressed={companionSlot===index} onClick={()=>{setCompanionSlot(index);setCreatureFocus(id)}}><CombatCreature creatureId={id} size={64}/><span><small>Companion {index+1}</small><strong>{getCreature(id).name}</strong></span></button>)}</div><article className="c19-creature-detail"><CombatCreature creatureId={focused.id} size={90}/><div><strong>{focused.name}</strong><small>{cap(focused.strengthClass)} · {focused.maxHp} HP · {focused.maxFlux} Flux</small><div className="c19-affinity-marks">{focused.elements.map(element=><ElementIcon key={element} element={element} label={cap(element)} size={23}/>)}</div><p>{focused.description}</p>{perk&&<p><b>{perk.name}.</b> {perk.description}</p>}</div><div className="c19-creature-spells">{focused.loadout.map(id=>{const move=profileSpell(effectiveSpell(focused.championId,id,focused.affinities),CURRENT_SPELL_MODEL);return <article key={id}><ElementIcon element={move.element} spell={move} size={22}/><div><strong>{move.name}</strong><small>{move.cost} Flux · reach {move.range} · {spellProfileLabel(move)||SHAPE_NAME[move.shape]}</small><p>{profiledEffectLabel(move)}</p></div></article>})}</div><button className="c19-primary" disabled={profile.companions.includes(focused.id)} onClick={()=>recruit(focused.id)}>{profile.companions.includes(focused.id)?'In your party':`Recruit in slot ${companionSlot+1}`}</button></article>{filters}<div className="c19-recruits">{recruits.slice(recruitPage*6,recruitPage*6+6).map(creature=><button key={creature.id} aria-pressed={creatureFocus===creature.id} onClick={()=>setCreatureFocus(creature.id)}><CombatCreature creatureId={creature.id} size={56}/><strong>{creature.name}</strong><small>{cap(creature.strengthClass)}{profile.companions.includes(creature.id)?' · ✓':''}</small></button>)}</div><nav className="c19-pagination" aria-label="Recruit pages"><button disabled={recruitPage===0} onClick={()=>setPage(recruitPage-1)} aria-label="Previous recruits">←</button><span>{recruitPage+1}/{recruitPages}</span><button disabled={recruitPage+1>=recruitPages} onClick={()=>setPage(recruitPage+1)} aria-label="More recruits">→</button></nav></>}
 </section>;
}











