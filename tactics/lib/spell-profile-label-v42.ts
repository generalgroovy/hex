import {describeSpell,STATUS_DEFINITIONS,type Spell} from './spells-v20.ts';
import {spellProfileBands,type FocusedSpell} from './spell-profile-v42.ts';
import {spellEffectLabel} from './battle-guidance-v16.ts';

export function profileBandValue(spell:Spell):string{
 const values:string[]=[];
 if(spell.damage)values.push(`${spell.damage} damage`);
 if(spell.heal)values.push(`heal ${spell.heal}`);
 if(!values.length)for(const effect of [...(spell.harmful??[]),...(spell.friendly??[])]){
  const name=STATUS_DEFINITIONS.find(status=>status.id===effect.id)?.name??effect.id;
  const value=`${name}${effect.id==='ward'?` ${effect.power??1}`:''} ${effect.turns}r`;
  if(!values.includes(value))values.push(value);
 }
 return values.join(' · ')||'Terrain';
}
export function profiledEffectLabel(spell:Spell):string{
 const bands=spellProfileBands(spell);
 if(!bands)return spellEffectLabel(spell);
 if(spell.damage||spell.heal){
  const effects=spellEffectLabel({...spell,damage:0,heal:0});
  const extra=effects==='shapes the field'?'':` · ${effects}`;
  const friendly=spell.harm==='all'&&spell.damage>0&&!effects.includes('hits allies')?' · hits allies':'';
  return `Centre ${bands.centre.damage||bands.centre.heal} · inner ${bands.inner.damage||bands.inner.heal} · rim ${bands.rim.damage||bands.rim.heal} ${spell.damage?`${spell.pierce?'piercing ':''}damage`:'healing'}${extra}${friendly}`;
 }
 return `${spellEffectLabel(spell)} · weaker rim`;
}
/** A widened profile must not keep a saved one-hex description. */
export function profiledSpellDescription(spell:Spell):string{
 const bands=spellProfileBands(spell);if(!bands)return spell.description;
 const statuses=[...(spell.harmful??[]),...(spell.friendly??[])],rimStatuses=[...(bands.rim.harmful??[]),...(bands.rim.friendly??[])];
 const noControl=statuses.some(effect=>['rooted','chilled','concussed','blind'].includes(effect.id)),lessPower=rimStatuses.some(effect=>(statuses.find(original=>original.id===effect.id)?.power??1)>(effect.power??1));
 const rim=statuses.length?` Rim: ${rimStatuses.length?`statuses last 1 round${lessPower?' at half power, minimum 1':''}${noControl?'; no direct control':''}`:'no direct statuses'}.`:'';
 const described=(spell as FocusedSpell).forceFromCaster?{...spell,shape:'hex' as const}:spell;
 return `Inner-ring values: ${describeSpell(described)}${rim} Terrain covers the area.`;
}
