import type {Spell} from '../../lib/spells-v20';
import {getCreaturePerk,CREATURE_BOND_RADIUS} from '../../lib/campaign-creatures-v20';
import ElementIcon from './ElementIcon';
import SpellFootprint,{SHAPE_NAME} from './SpellFootprint';
import {CURRENT_SPELL_MODEL,profileSpell,spellProfileLabel,type SpellModel} from '../../lib/spell-profile-v42';
import {profiledEffectLabel,profiledSpellDescription} from '../../lib/spell-profile-label-v42';
import SpellProfile from './SpellProfileV42';

/** The decision summary uses the same effective spell as combat, including affinity scaling. */
export function TowerSpellPreview({spell:base,note,spellModel=CURRENT_SPELL_MODEL}:{spell:Spell;note?:string;spellModel?:SpellModel|null}){
 const spell=profileSpell(base,spellModel??undefined);
 return <details className="tp23-spell" data-spell-id={spell.id}>
  <summary><ElementIcon spell={spell} size={22}/><span className="tp23-spell-name"><strong>{spell.name}</strong><span className="tp23-spell-stats">{spell.cost} Flux · {spell.range?`reach ${spell.range}`:'self'} · {spellProfileLabel(spell)||SHAPE_NAME[spell.shape]}</span></span><span className="tp23-spell-expand" aria-hidden="true">⌄</span><span className="tp23-spell-effect">{profiledEffectLabel(spell)}</span>{note&&<span className="tp23-spell-note">{note}</span>}</summary>
  <div className="tp23-spell-rules"><SpellProfile spell={spell}/><span><SpellFootprint shape={spell.shape}/>{SHAPE_NAME[spell.shape]}</span><p>{profiledSpellDescription(spell)}</p></div>
 </details>;
}

export function TowerBondPreview({perkId}:{perkId:string}){
 const perk=getCreaturePerk(perkId),effects=[perk.mechanics.heal?'+1 HP':'',perk.mechanics.flux?'+1 Flux':'',perk.mechanics.ward?'Ward 1':'',perk.mechanics.haste?'Haste':'',perk.mechanics.clarity?'Clarity':''].filter(Boolean).join(' + '),partners=perk.partnerElements.map(element=>element[0].toUpperCase()+element.slice(1)).join(' / ');
 return <details className="tp23-bond"><summary><strong>{perk.name}<span>Bond</span></strong><span>{effects} · needs another {partners} creature</span><small>Allies within {CREATURE_BOND_RADIUS} hexes of both · after effects</small></summary><p>{perk.description}</p></details>;
}
