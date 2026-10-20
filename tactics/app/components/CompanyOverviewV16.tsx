"use client";
import type {CSSProperties} from 'react';
import type {Element} from '../../lib/game';
import {getChampion,affinityTotal,type AffinityAllocation} from '../../lib/roster-v13';
import {CHARACTER_DESIGN} from '../../lib/character-design-v13';
import {defaultLoadout,getSignature,effectiveSpell,spellCost,ELEMENT_BRANCHES} from '../../lib/spells-v16';
import {spellFootprintLabel,titleCase} from '../../lib/catalogue-v16';
import {spellEffectLabel} from '../../lib/battle-guidance-v16';
import {ELEMENT_STYLE} from '../../lib/presentation';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';

export type CompanyOverviewV16Props={roster:string[];loadouts:Record<string,string[]>;selectedSlot:number;onSelect:(slot:number)=>void;onReplace:(slot:number)=>void;onEditSpell:(slot:number,index:number)=>void;affinities?:Record<string,AffinityAllocation>;affinityBudget?:number;onTrain?:(slot:number)=>void;onDetails?:(id:string)=>void;disabled:boolean};

export default function CompanyOverviewV16({roster,loadouts,selectedSlot,onSelect,onReplace,onEditSpell,affinities={},affinityBudget,onTrain,onDetails,disabled}:CompanyOverviewV16Props){
 const slot=Math.min(selectedSlot,roster.length-1),id=roster[slot],champion=getChampion(id),allocation=affinities[id]??champion.affinities,total=affinityTotal(allocation),kit=loadouts[id]??defaultLoadout(id,allocation),signature=effectiveSpell(id,getSignature(id).id,allocation);
 return <div className="cx-company-v16" aria-label="Your team and spells">
  <div className="cx-team-tabs" role="group" aria-label="Select a team member">{roster.map((member,index)=><button className="cx-identity" type="button" key={`${member}-${index}`} aria-label={`Select ${getChampion(member).name}`} aria-pressed={slot===index} disabled={disabled} onClick={()=>onSelect(index)}><PixelChampion id={member} size={66} paused/><span><b>{getChampion(member).name}</b><small>{titleCase(getChampion(member).race)}</small></span></button>)}</div>
  <article className="cx-member-detail" aria-label={`${champion.name}'s loadout`}>
   <header><div><h2>{champion.name}</h2><p>{titleCase(champion.race)} · {CHARACTER_DESIGN[id].role}</p></div><button aria-label={`Replace ${champion.name}`} disabled={disabled} onClick={()=>onReplace(slot)}>Replace</button></header>
   <div className="cx-affinity-row"><div aria-label={`${champion.name}'s affinity points`}>{Object.entries(allocation).map(([element,points])=><span key={element} title={`${points} ${titleCase(element)} affinity${points!>=3?` · ${ELEMENT_BRANCHES[element as Element]} unlocked`:''}`}><ElementIcon element={element as Element} size={18}/><span>{titleCase(element)}</span><b>{points}</b></span>)}</div>{onTrain&&<button disabled={disabled} onClick={()=>onTrain(slot)} aria-label={`Train ${champion.name}'s affinities`}>{affinityBudget!==undefined&&affinityBudget>total?`Train · ${affinityBudget-total} unspent`:'Train'}</button>}</div>
   <div className="cx-kit-v16" role="group" aria-label={`${champion.name}'s four equipped spells`}>{kit.map((spellId,index)=>{const spell=effectiveSpell(id,spellId,allocation),cost=spellCost(id,spellId,allocation);return <button key={index} type="button" style={{'--cx-element':ELEMENT_STYLE[spell.element].color} as CSSProperties} disabled={disabled} onClick={()=>onEditSpell(slot,index)} aria-label={`Configure spell ${index+1} for ${champion.name}: ${spell.name}, ${titleCase(spell.element)}, level ${spell.level} ${spell.branch}, ${cost} Flux. ${spellFootprintLabel(spell)}. Reach ${spell.range}.`}><ElementIcon element={spell.element} spell={spell} size={22}/><span><strong>{spell.name}</strong><small>{spellEffectLabel(spell)}</small><small>{cost} Flux · reach {spell.range} · {spellFootprintLabel(spell)}</small></span><b className="cx-slot-index" aria-hidden="true">{index+1}</b></button>})}</div>
   <button className="cx-signature-v16" aria-label={`${champion.name}'s signature: ${signature.name}. ${spellCost(id,signature.id,allocation)} Flux. Show effects.`} onClick={()=>onDetails?.(id)}><ElementIcon element={signature.element} spell={signature} size={28}/><span><small>Signature · creator</small><strong>{signature.name}</strong><small>{spellEffectLabel(signature)}</small></span><b>{spellCost(id,signature.id,allocation)} Flux</b></button>
  </article>
 </div>;
}
