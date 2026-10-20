/** New battles opt into focused areas. Absence keeps saved encounters on their
 * original footprints and effect values, including reconstructed replays. */
import type {Spell,StatusApplication,StatusId} from './spells-v20.ts';
import type {Point} from './game.ts';
import {distance} from './game.ts';
export type SpellModel='focused'|'focused-v44';
export const CURRENT_SPELL_MODEL:SpellModel='focused-v44';
export const isFocusedSpellModel=(model:unknown):model is SpellModel=>model==='focused'||model===CURRENT_SPELL_MODEL;
export type FocusedSpell=Spell&{focus?:true;forceFromCaster?:true};
export type FocusZone='centre'|'inner'|'rim'|'precision';
/** Deliberate single-target tools: force direction and execution stay precise. */
export const PRECISION_SPELLS:ReadonlySet<string>=new Set(['gust','gale','vacuum','undertow','immolate','shatter','reap']);
const controls:readonly StatusId[]=['rooted','chilled','concussed','blind'];
export function profileSpell<T extends Spell>(spell:T,model?:SpellModel):T&FocusedSpell {
 if(!isFocusedSpellModel(model))return spell;
 // Persisted focused battles keep their original role. New battles give Light
 // a protection-breaking burst without weakening neutral ground's Clarity.
 if(model===CURRENT_SPELL_MODEL&&spell.id==='sunburst')spell={...spell,pierce:true,harmful:undefined,description:'Piercing Light damages enemies through Ward and cover. Allies take no direct damage; the resulting field protects either side from control.'};
 if((spell as FocusedSpell).focus)return spell;
 if(spell.range===0||PRECISION_SPELLS.has(spell.id)||!['hex','burst'].includes(spell.shape))return spell;
 const focused={...spell,shape:'burst' as const,radius:Math.max(2,spell.radius),focus:true as const,...(spell.shape==='hex'&&spell.push?{forceFromCaster:true as const}:{})};
 return {...focused,...(spell.creatureId&&spell.counterplay?{counterplay:focusedCounterplay(focused)}:{})};
}
/** Geometry-sensitive counterplay follows the effective area, including saved
 * focused battles. Immutable catalogue prose continues to serve old hex kits. */
export function focusedCounterplay(spell:Spell):string{
 const options:string[]=[`Spread beyond the radius-${spell.radius} area.`];
 if(spell.push)options.push('Guard reduces force; Anchored blocks it.');
 else if(spell.harmful?.some(status=>controls.includes(status.id)))options.push('Clarity or Resolve blocks direct control.');
 else if(spell.harmful?.some(status=>status.id==='burn'))options.push('Wet prevents Burn.');
 else if(spell.steal)options.push('Spend Flux before theft.');
 else if(spell.pierce)options.push('Ward does not stop its piercing damage.');
 else if(spell.heal||spell.recharge||spell.friendly?.length)options.push(spell.selfDamage?'Pressure the caster: support costs its own health.':'Separate the group to limit shared support.');
 else if(spell.drain)options.push('Prevent spell damage to deny its healing.');
 else if(spell.bonus==='wet')options.push('Avoid being Wet before the exchange.');
 else if(spell.bonus==='wither')options.push('Cleanse Wither before the exchange.');
 else if(spell.cooldown)options.push(`Counterattack during its ${spell.cooldown}-round cooldown.`);
 return options.join(' ');
}
/** Broadening an aimed hex must preserve its original caster-relative force. */
export function forceOrigin(spell:Spell,caster:Point,target:Point):Point {
 return !(spell as FocusedSpell).forceFromCaster&&(spell.shape==='ring'||spell.shape==='burst')?target:caster;
}
export function focusZone(spell:Spell,target:Point,cell:Point):FocusZone {
 if(!(spell as FocusedSpell).focus)return 'precision';
 const radius=distance(target,cell);return radius===0?'centre':radius===1?'inner':'rim';
}
const half=(value:number)=>value>0?Math.max(1,Math.floor(value/2)):0;
/** Actor-local direct effects. Terrain ingredients always cover the full area. */
export function spellAtCell<T extends Spell>(spell:T,target:Point,cell:Point):T {
 const zone=focusZone(spell,target,cell);
 if(zone==='precision'||zone==='inner')return spell;
 if(zone==='centre'){
  const longer=(values:readonly StatusApplication[]|undefined)=>values?.map(status=>({...status,turns:Math.min(controls.includes(status.id)?1:['ward','burn'].includes(status.id)?2:3,status.turns+1)}));
  return {...spell,damage:spell.damage>0?spell.damage+1:0,heal:spell.heal>0?spell.heal+1:0,...(!spell.damage&&!spell.heal?{harmful:longer(spell.harmful),friendly:longer(spell.friendly)}:{})};
 }
 const rimStatuses=(values:readonly StatusApplication[]|undefined)=>values?.filter(status=>!controls.includes(status.id)).map(status=>({...status,turns:1,...(status.power?{power:half(status.power)}:{})}));
 return {...spell,damage:half(spell.damage),heal:half(spell.heal),bonusDamage:half(spell.damage+(spell.bonusDamage??0))-half(spell.damage),harmful:rimStatuses(spell.harmful),friendly:rimStatuses(spell.friendly)};
}
export function hasCentreBonus(spell:Spell):boolean {
 if(!(spell as FocusedSpell).focus)return false;
 const centre=spellAtCell(spell,{q:0,r:0},{q:0,r:0});
 return centre.damage>spell.damage||centre.heal>spell.heal||(['harmful','friendly'] as const).some(kind=>(centre[kind]??[]).some((status,index)=>status.turns>(spell[kind]?.[index]?.turns??0)));
}
export function spellProfileSummary(spell:Spell):string {
 if(!(spell as FocusedSpell).focus)return '';
 const centre=hasCentreBonus(spell)?`Centre crit: ${spell.damage||spell.heal?[spell.damage?'+1 damage':'',spell.heal?'+1 healing':''].filter(Boolean).join(' and '):'statuses last +1 round within normal caps'}. Inner ring: full effect.`:'Centre and inner ring: full effect.';
 return `${centre} Rim: half damage/healing, one-round statuses at half power, no direct control. Terrain covers the area.`;
}
export function spellProfileLabel(spell:Spell):string {
 return (spell as FocusedSpell).focus?`Radius ${spell.radius}${hasCentreBonus(spell)?' · centre crit':''}`:'';
}
export function spellProfileBands(spell:Spell):{centre:Spell;inner:Spell;rim:Spell}|null {
 return (spell as FocusedSpell).focus?{centre:spellAtCell(spell,{q:0,r:0},{q:0,r:0}),inner:spell,rim:spellAtCell(spell,{q:0,r:0},{q:2,r:0})}:null;
}
