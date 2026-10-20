/** Spell numbers are unchanged; rules 12 field wording reflects exact chemistry. */
export * from './spells-v11.ts';
import * as previous from './spells-v11.ts';
import type {AffinityAllocation} from './roster-v11.ts';
import type {Spell} from './spells-v11.ts';
const precise=(text:string)=>text.replace('Freeze the footprint; entering Ice slides to its end. Fire melts Ice.','Freezes unmixed Water. Mixed fields use their own ice rule; entering Ice slides to its end.');
const described=(spell:Spell):Spell=>({...spell,description:precise(spell.freeze?previous.describeSpell(spell):spell.description)});
export const SPELLS=previous.SPELLS.map(described);
export const SIGNATURES=previous.SIGNATURES.map(described);
export const ALL_SPELLS=[...SPELLS,...SIGNATURES];
export function getSpell(id:string):Spell{return described(previous.getSpell(id));}
export function getSignature(championId:string):Spell{return described(previous.getSignature(championId));}
export function effectiveSpell(championId:string,spellId:string,affinities?:AffinityAllocation):Spell{return described(previous.effectiveSpell(championId,spellId,affinities));}
export function describeSpell(spell:Spell):string{return precise(previous.describeSpell(spell));}
