/** Rules 16: larger authored fields, distinct precision tools, unchanged damage and access. */
export * from './spells-v13.ts';
import * as previous from './spells-v13.ts';
import type {Spell} from './spells-v13.ts';
import type {AffinityAllocation} from './roster-v11.ts';

const impactRule='A forced step blocked by a ruin or barrier causes 1 environmental damage and Concussed, once per exchange. Guard resists force; Anchored prevents it. Units and map edges cause no impact.';
const broaden=(spell:Spell):Spell=>{
  if(spell.shape==='burst')return {...spell,radius:spell.radius+1};
  if(spell.shape==='sweep')return {...spell,radius:spell.radius+1};
  if(spell.shape==='wall')return {...spell,radius:2};
  if(spell.shape==='ring'&&spell.range>0)return {...spell,radius:spell.radius+1};
  if(['frostbite','flare','cleansing_tide','thunderclap'].includes(spell.id))return {...spell,shape:'burst',radius:1};
  return {...spell};
};
export const spellFootprintDescription=(spell:Spell):string=>spell.shape==='burst'?`${1+3*spell.radius*(spell.radius+1)}-hex burst`
  :spell.shape==='ring'?`${6*spell.radius}-hex ring; ${1+3*(spell.radius-1)*spell.radius} inner hexes stay clear`
  :spell.shape==='sweep'?`${1+2*spell.radius}-hex fan`
  :spell.shape==='wall'?`${1+2*Math.max(1,spell.radius)}-hex wall`
  :spell.shape==='line'?'Every hex on the shortest rays to the aim':'One precise hex';
const described=(original:Spell):Spell=>{
  const spell=broaden(original);
  return {...spell,description:describeSpell(spell)};
};
export const SPELLS=previous.SPELLS.map(described);
export const SIGNATURES=previous.SIGNATURES.map(described);
export const ALL_SPELLS=[...SPELLS,...SIGNATURES];
export const STATUS_DEFINITIONS=previous.STATUS_DEFINITIONS.map(status=>status.id==='wet'?{...status,description:`${status.description} Magical liquid Water grants Wet for one round; Ice does not.`}:status);
export function getSpell(id:string):Spell{return described(previous.getSpell(id));}
export function getSignature(championId:string):Spell{return described(previous.getSignature(championId));}
export function effectiveSpell(championId:string,spellId:string,affinities?:AffinityAllocation):Spell{return described(previous.effectiveSpell(championId,spellId,affinities));}
export function describeSpell(spell:Spell):string{return `${previous.describeSpell(spell).replace('Raise a 3-hex barrier',`Raise a ${1+2*Math.max(1,spell.radius)}-hex barrier`)} Area: ${spellFootprintDescription(spell)}.${spell.push?` ${impactRule}`:''}`;}
