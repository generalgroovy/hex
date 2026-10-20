"use client";
import {useEffect,useState} from 'react';
import {getChampion,type AffinityAllocation} from '../../lib/roster-v13';
import {effectiveSpell,getSignature,spellCost,spellScalingSummary} from '../../lib/spells-v16';
import {STATUS_DEFINITIONS,castAvailability,type SimState,type SimUnit} from '../../lib/tactics-v16';
import {spellEffectLabel} from '../../lib/battle-guidance-v16';
import {spellFootprintLabel} from '../../lib/catalogue-v16';
import {spellSurfaceHint} from '../../lib/element-personality-v16';
import type {Element} from '../../lib/game';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';

type Props={championId:string;allocation:AffinityAllocation;spellIds:string[];unit?:SimUnit;state?:SimState;signatureFirst?:boolean};
export default function CharacterSheetV16({championId,allocation,spellIds,unit,state,signatureFirst=false}:Props){
 const signature=getSignature(championId),ids=[...new Set([...spellIds,signature.id])],champion=getChampion(championId);
 const [selected,setSelected]=useState(signatureFirst?signature.id:ids[0]);
 useEffect(()=>setSelected(signatureFirst?getSignature(championId).id:spellIds[0]),[championId,signatureFirst]);
 const spell=effectiveSpell(championId,ids.includes(selected)?selected:ids[0],allocation),availability=unit&&state?castAvailability(state,unit.id,spell.id):null;
 return <section className="tx-character-sheet" aria-label={`${champion.name}'s moveset`}>
  <div className="tx-sheet-identity"><PixelChampion id={championId} size={86} paused/><div><strong>{champion.name}</strong><small>{champion.race}{unit?` · ${unit.hp}/${unit.maxHp} HP · ${unit.flux}/${unit.maxFlux} Flux`:''}</small><div className="tx-sheet-affinities">{Object.entries(allocation).map(([element,points])=><span key={element}><ElementIcon element={element as Element} size={18}/>{element} <b>{points}</b></span>)}</div></div></div>
  {unit&&Object.keys(unit.statuses).length>0&&<div className="tx-sheet-statuses" aria-label="Current statuses">{Object.entries(unit.statuses).map(([id,status])=>{const rule=STATUS_DEFINITIONS.find(entry=>entry.id===id);return <span key={id} title={rule?.description}>{rule?.name||id} · {status?.turns} rounds</span>})}</div>}
  <div className="tx-sheet-spells" role="group" aria-label={`${champion.name}'s spells`}>{ids.map((id,index)=>{const entry=effectiveSpell(championId,id,allocation);return <button key={id} aria-pressed={spell.id===id} onClick={()=>setSelected(id)}><ElementIcon element={entry.element} spell={entry} size={18}/><span>{entry.id===signature.id?'★ ':`${index+1}. `}{entry.name}</span></button>})}</div>
  <article className="tx-sheet-effect" aria-label={`${spell.name} effects`}><h3><ElementIcon element={spell.element} spell={spell} size={22}/>{spell.name}</h3><p className="tx-sheet-stats"><b>{availability?.cost??spellCost(championId,spell.id,allocation)} Flux</b> · reach {spell.range} · {spellFootprintLabel(spell)} · {spell.cooldown} round recovery</p><strong>{spellEffectLabel(spell)}</strong><p>{spell.description}</p><p>{spellSurfaceHint(spell)}</p><small>{spellScalingSummary(championId,spell.id,allocation)}{availability&&!availability.available?` · ${availability.reason}`:''}</small>{spell.id===signature.id&&<small>Creator needs 2 fewer affinity and pays 2 less Flux. Victory in this character’s story unlocks the spell for everyone.</small>}</article>
 </section>;
}
