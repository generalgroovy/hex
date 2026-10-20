"use client";

import type {CSSProperties} from 'react';
import type {Element} from '../../lib/game';
import {getChampion,affinityTotal,type AffinityAllocation} from '../../lib/roster-v13';
import {CHARACTER_DESIGN} from '../../lib/character-design-v13';
import {defaultLoadout,getSignature,effectiveSpell,spellCost,ELEMENT_BRANCHES} from '../../lib/spells-v14';
import {spellFootprintLabel,titleCase} from '../../lib/catalogue-v14';
import {ELEMENT_STYLE} from '../../lib/presentation';
import PixelChampion from './PixelChampion';
import ElementIcon from './ElementIcon';
import './company-overview-v9.css';
import './affinity-progression.css';
import './world-design-v13.css';

export type CompanyOverviewV14Props = {
  roster:string[];
  loadouts:Record<string,string[]>;
  selectedSlot:number;
  onSelect:(slot:number)=>void;
  onReplace:(slot:number)=>void;
  onEditSpell:(slot:number,index:number)=>void;
  affinities?:Record<string,AffinityAllocation>;
  affinityBudget?:number;
  onTrain?:(slot:number)=>void;
  disabled:boolean;
};

export default function CompanyOverviewV14({roster,loadouts,selectedSlot,onSelect,onReplace,onEditSpell,affinities={},affinityBudget,onTrain,disabled}:CompanyOverviewV14Props){
  return <div className="cx-company" role="group" aria-label="Your team and spells">
    {roster.map((id,slot)=>{
      const champion=getChampion(id),allocation=affinities[id]??champion.affinities,total=affinityTotal(allocation),kit=loadouts[id]??defaultLoadout(id,allocation),signature=effectiveSpell(id,getSignature(id).id,allocation);
      return <article key={`${id}-${slot}`} className={`cx-member${selectedSlot===slot?' is-selected':''}`} aria-labelledby={`cx-name-${slot}`}>
        <header className="cx-member-heading">
          <button type="button" className="cx-identity" aria-label={`Select ${champion.name}`} aria-pressed={selectedSlot===slot} disabled={disabled} onClick={()=>onSelect(slot)}>
            <span className="cx-portrait"><PixelChampion id={id} size={82} paused/></span>
            <span className="cx-identity-text"><strong id={`cx-name-${slot}`}>{champion.name}</strong><span className="cx-race">{titleCase(champion.race)}</span><span className="cx-character-role">{CHARACTER_DESIGN[id].role}</span></span>
          </button>
          <button type="button" className="cx-replace" aria-label={`Replace ${champion.name}`} disabled={disabled} onClick={()=>onReplace(slot)}>Replace</button>
        </header>
        <div className="cx-affinities" aria-label={`${champion.name}'s affinity points`}>
          {Object.entries(allocation).map(([element,points])=><span key={element} title={`${points} ${titleCase(element)} affinity points: ${points!>=3?`1 less Flux; ${ELEMENT_BRANCHES[element as Element]} unlocked`:points!>=2?'1 less Flux':'base Flux cost'}`}><ElementIcon element={element as Element} size={18}/><span>{titleCase(element)}</span><b>{points}</b></span>)}
        </div>
        <div className="cx-affinity-total"><span><b>{total}</b> total affinity{affinityBudget!==undefined&&affinityBudget>total?` · ${affinityBudget-total} unspent`:''}</span>{onTrain&&<button type="button" disabled={disabled} onClick={()=>onTrain(slot)} aria-label={`Train ${champion.name}'s affinities`}>Train</button>}</div>
        <div className="cx-unlocks" aria-label={`${champion.name} advanced unlocks`}>{Object.entries(allocation).filter(([,points])=>points!>=3).map(([element,points])=><span key={element}>{ELEMENT_BRANCHES[element as Element]} <b>Lv.{points}</b></span>)}</div>
        <div className="cx-spell-grid" role="group" aria-label={`${champion.name}'s four equipped spells`}>
          {kit.map((spellId,index)=>{
            const spell=effectiveSpell(id,spellId,allocation),cost=spellCost(id,spellId,allocation),footprint=spellFootprintLabel(spell);
            return <button type="button" key={index} className="cx-spell" style={{'--cx-element':ELEMENT_STYLE[spell.element].color} as CSSProperties} disabled={disabled} onClick={()=>onEditSpell(slot,index)} aria-label={`Configure spell ${index+1} for ${champion.name}: ${spell.name}, ${titleCase(spell.element)}, level ${spell.level} ${spell.branch}, ${cost} Flux. ${footprint}. Reach ${spell.range}.`} title={`${spell.description}\n${footprint} · reach ${spell.range} · recovery ${spell.cooldown}`}>
              <span className="cx-slot" aria-hidden="true">{index+1}</span><ElementIcon element={spell.element} size={18}/><strong>{spell.name}</strong>
              <span className="cx-spell-meta">{cost} Flux · {spell.level>=3?`${spell.branch} Lv.${spell.level}`:titleCase(spell.element)}</span>
            </button>;
          })}
        </div>
        <details className="cx-signature">
          <summary aria-label={`${champion.name}'s signature: ${signature.name}. ${spellCost(id,signature.id,allocation)} Flux. Show effects.`}><span className="cx-signature-star" aria-hidden="true">★</span><span><small>Signature</small><strong>{signature.name}</strong></span><b>{spellCost(id,signature.id,allocation)}<small> Flux</small></b></summary>
          <div><p>{signature.description}</p><span>{titleCase(signature.element)} · {spellFootprintLabel(signature)} · reach {signature.range} · recovery {signature.cooldown}</span><p className="cx-signature-rule">Creator: 3 affinity · 3 Flux. Learned by others through Story: 5 affinity · 5 Flux.</p></div>
        </details>
      </article>;
    })}
  </div>;
}
