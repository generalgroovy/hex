/** Rules 14 preserves spell numbers and access; displacement now has terrain consequences. */
export * from './spells-v13.ts';
import * as previous from './spells-v13.ts';
import type {Spell} from './spells-v13.ts';
import type {AffinityAllocation} from './roster-v11.ts';

const impactRule='A forced step blocked by a ruin or barrier causes 1 environmental damage and Concussed, once per exchange. Guard resists force; Anchored prevents it. Units and map edges cause no impact.';
const described=(spell:Spell):Spell=>spell.push?{...spell,description:`${spell.description} ${impactRule}`}:{...spell};
export const SPELLS=previous.SPELLS.map(described);
export const SIGNATURES=previous.SIGNATURES.map(described);
export const ALL_SPELLS=[...SPELLS,...SIGNATURES];
export const STATUS_DEFINITIONS=previous.STATUS_DEFINITIONS.map(status=>status.id==='wet'?{...status,description:`${status.description} Magical liquid Water grants Wet for one round; Ice does not.`}:status);
export function getSpell(id:string):Spell{return described(previous.getSpell(id));}
export function getSignature(championId:string):Spell{return described(previous.getSignature(championId));}
export function effectiveSpell(championId:string,spellId:string,affinities?:AffinityAllocation):Spell{return described(previous.effectiveSpell(championId,spellId,affinities));}
export function describeSpell(spell:Spell):string{return `${previous.describeSpell(spell)}${spell.push?` ${impactRule}`:''}`;}
