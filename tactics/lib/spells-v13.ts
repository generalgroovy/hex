/** Rules 13: allocated elements define spell access; camp kits preserve legal choices. */
export * from './spells-v11.ts';
import * as previous from './spells-v11.ts';
import {getChampion,validateAffinityAllocation,MAX_AFFINITY_ELEMENTS,MAX_AFFINITY_LEVEL,type AffinityAllocation} from './roster-v13.ts';
import type {Spell} from './spells-v11.ts';
import {CHARACTER_DESIGN} from './character-design-v13.ts';
const precise=(text:string)=>text
 .replace('Freeze the footprint; entering Ice slides to its end. Fire melts Ice.','Freezes unmixed Water. Mixed fields use their own ice rule; entering Ice slides to its end.')
 .replace('Guard and Anchored resist.','Guard resists 1 strength of the combined push or pull; Anchored stops it completely. Ice can carry a single push farther.');
const described=(spell:Spell):Spell=>({...spell,description:precise(spell.freeze||spell.push?previous.describeSpell(spell):spell.description)});
export const SPELLS=previous.SPELLS.map(described);
export const SIGNATURES=previous.SIGNATURES.map(described);
export const ALL_SPELLS=[...SPELLS,...SIGNATURES];
const byId=new Map(ALL_SPELLS.map(spell=>[spell.id,spell]));
const effectiveDescriptions=new WeakMap<Spell,Spell>();
export function getSpell(id:string):Spell {const spell=byId.get(id);if(!spell)throw new Error('Unknown spell.');return spell;}
export function getSignature(championId:string):Spell {return getSpell(previous.getSignature(championId).id);}
export function effectiveSpell(championId:string,spellId:string,affinities?:AffinityAllocation):Spell {
 const base=previous.effectiveSpell(championId,spellId,affinities),cached=effectiveDescriptions.get(base);
 if(cached)return cached;
 const spell=Object.freeze(described(base));effectiveDescriptions.set(base,spell);return spell;
}
export function describeSpell(spell:Spell):string {return precise(previous.describeSpell(spell));}
export type SpellAccess=Omit<previous.SpellAccess,'requiredAffinity'>&{requiredAffinity:1|2|3|4|5|6};
/** Earned affinity can add a third element; no unallocated element grants spells. */
export function spellAccess(championId:string,spellId:string,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):SpellAccess {
 const spell=getSpell(spellId),old=previous.spellAccess(championId,spellId,affinities,learnedSignatures);
 if(spell.level!==1||spell.signatureChampionId)return old as SpellAccess;
 const unlocked=((affinities??getChampion(championId).affinities)[spell.element]??0)>=1;
 return {...old,requiredAffinity:1,unlocked,...(!unlocked?{reason:`Requires 1 ${spell.element.charAt(0).toUpperCase()+spell.element.slice(1)} affinity point. Allocate it in camp.`}:{})};
}
export function availableSpellIds(championId:string,loadout:readonly string[],affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):string[] {
 const signature=getSignature(championId).id;
 return [...loadout.filter(id=>id!==signature&&byId.has(id)&&spellAccess(championId,id,affinities,learnedSignatures).unlocked),
  ...(spellAccess(championId,signature,affinities,learnedSignatures).unlocked?[signature]:[])];
}
export function validateLoadout(championId:string,input:unknown,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):string[] {
 getChampion(championId);
 if(affinities!==undefined)validateAffinityAllocation(affinities,MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL);
 previous.validateLearnedSignatures(learnedSignatures);
 if(!Array.isArray(input)||input.length!==4||new Set(input).size!==4||input.some(id=>typeof id!=='string'||!byId.has(id)||id===getSignature(championId).id))throw new Error('Equip exactly 4 different spells. Your own signature has its fixed fifth slot.');
 for(const id of input){const access=spellAccess(championId,id,affinities,learnedSignatures);if(!access.unlocked)throw new Error(`${getSpell(id).name}: ${access.reason}`);}
 return [...input] as string[];
}
/** Slot-preserving migration replaces only missing, duplicate or now-ineligible spells. */
export function repairLoadout(championId:string,input:unknown,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):string[] {
 getChampion(championId);
 if(affinities!==undefined)validateAffinityAllocation(affinities,MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL);
 previous.validateLearnedSignatures(learnedSignatures);
 const supplied=Array.isArray(input)?input:[],used=new Set<string>(),signature=getSignature(championId).id;
 const repaired=Array.from({length:4},(_,index):string|undefined=>{
  const id=supplied[index];
  if(typeof id!=='string'||used.has(id)||id===signature||!byId.has(id)||!spellAccess(championId,id,affinities,learnedSignatures).unlocked)return undefined;
  used.add(id);return id;
 });
 const choices=[...(CHARACTER_DESIGN[championId]?.kit??[]),...SPELLS.map(spell=>spell.id)].filter(id=>spellAccess(championId,id,affinities,learnedSignatures).unlocked);
 for(let slot=0;slot<repaired.length;slot++)if(repaired[slot]===undefined){
  const replacement=choices.find(id=>!used.has(id));
  if(!replacement)throw new Error('This affinity allocation has fewer than four available spells.');
  repaired[slot]=replacement;used.add(replacement);
 }
 return validateLoadout(championId,repaired,affinities,learnedSignatures);
}
export function defaultLoadout(championId:string,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):string[] {
 return repairLoadout(championId,CHARACTER_DESIGN[championId]?.kit,affinities,learnedSignatures);
}
