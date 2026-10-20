/** Campaign spell library. Older engines retain their frozen registries. */
export * from './spells-v16.ts';
import * as previous from './spells-v16.ts';
import type {Spell as PreviousSpell,StatusId} from './spells-v16.ts';
import {getChampion,validateAffinityAllocation,MAX_AFFINITY_ELEMENTS,MAX_AFFINITY_LEVEL,type AffinityAllocation} from './roster-v13.ts';
import type {Element} from './game.ts';
import {CREATURES,getCreature} from './campaign-creatures-v19.ts';
import {CREATURE_SPELLS as authoredCreatureSpells,creatureSpellDefinition,creatureLoadout} from './creature-spells-v20.ts';
import {combinationFor} from './combinations-v16.ts';

export type Spell=PreviousSpell&{creatureId?:string;fieldElements?:Element[];counterplay?:string};
export type SpellAccess=previous.SpellAccess;
export type EnemySpell={sourceId:string;kind:'champion'|'creature';enemyId:string;name:string;spellId:string;championId?:string;creatureId?:string};
export const SPELLS:Spell[]=previous.SPELLS;
export const SIGNATURES:Spell[]=previous.SIGNATURES;
export function spellElements(spell:Spell):Element[]{return [...(spell.fieldElements??[spell.element])];}
export function describeSpell(spell:Spell):string {
 const rules=previous.describeSpell(spell),field=spell.fieldElements?.length?combinationFor(spell.fieldElements):undefined;
 return `${rules}${field?` Leaves ${field.name} (${spell.fieldElements!.map(element=>element.charAt(0).toUpperCase()+element.slice(1)).join(' + ')}).`:''}`;
}
function freezeSpell(spell:Spell):Spell {
 for(const channel of ['harmful','friendly','self'] as const)if(spell[channel]){spell[channel]=spell[channel]!.map(effect=>Object.freeze({...effect}));Object.freeze(spell[channel]);}
 if(spell.fieldElements)spell.fieldElements=Object.freeze([...spell.fieldElements]) as unknown as Element[];
 return Object.freeze(spell);
}
export const CREATURE_SPELLS:readonly Spell[]=Object.freeze(authoredCreatureSpells.map(spell=>freezeSpell({...spell,description:describeSpell(spell)})));
export const TEACHABLE_SPELLS:readonly Spell[]=Object.freeze([...SIGNATURES,...CREATURE_SPELLS]);
export const ALL_SPELLS:Spell[]=[...SPELLS,...TEACHABLE_SPELLS];
const byId=new Map(ALL_SPELLS.map(spell=>[spell.id,spell]));
const teachableIds=new Set(TEACHABLE_SPELLS.map(spell=>spell.id));
export const ENEMY_SPELLS:readonly EnemySpell[]=Object.freeze([
 ...SIGNATURES.map(spell=>{const champion=getChampion(spell.signatureChampionId!);return Object.freeze({sourceId:`champion:${champion.id}`,kind:'champion' as const,enemyId:champion.id,name:champion.name,spellId:spell.id,championId:champion.id});}),
 ...CREATURES.map(creature=>Object.freeze({sourceId:`creature:${creature.id}`,kind:'creature' as const,enemyId:creature.id,name:creature.name,spellId:creatureSpellDefinition(creature.id).id,creatureId:creature.id})),
]);
const bySource=new Map(ENEMY_SPELLS.map(source=>[source.sourceId,source]));
const originBySpell=new Map(ENEMY_SPELLS.map(source=>[source.spellId,source]));
export function enemySpell(sourceId:string):EnemySpell {const source=bySource.get(sourceId);if(!source)throw new Error('Unknown spell teacher.');return source;}
export function spellOrigin(spellId:string):EnemySpell|null {getSpell(spellId);return originBySpell.get(spellId)??null;}
export function getSpell(id:string):Spell {const spell=byId.get(id);if(!spell)throw new Error('Unknown spell.');return spell;}
export function getSignature(championId:string):Spell {return getSpell(previous.getSignature(championId).id);}
export function getCreatureSpell(creatureId:string):Spell {return getSpell(creatureSpellDefinition(creatureId).id);}
export {creatureLoadout};
export function teachingForEnemy(enemy:{championId:string;creatureId?:string}):Spell {return enemy.creatureId?getCreatureSpell(enemy.creatureId):getSignature(enemy.championId);}
export function validateLearnedSpells(input:unknown):string[] {
 if(!Array.isArray(input)||input.length>TEACHABLE_SPELLS.length||new Set(input).size!==input.length||input.some(id=>typeof id!=='string'||!teachableIds.has(id)))throw new Error('Learned spells must be unique known enemy techniques.');
 return [...input].sort() as string[];
}
/** Engine compatibility alias: the campaign library now includes creature techniques. */
export const validateLearnedSignatures=validateLearnedSpells;
export function spellCost(championId:string,spellId:string,affinities?:AffinityAllocation):number {
 const spell=getSpell(spellId);if(!spell.creatureId)return previous.spellCost(championId,spellId,affinities);
 const rank=(affinities??getChampion(championId).affinities)[spell.element]??0;
 return Math.max(1,spell.cost+(rank===0?1:rank>=2?-1:0));
}
export function spellAccess(championId:string,spellId:string,affinities?:AffinityAllocation,learnedSpells:readonly string[]=[]):SpellAccess {
 const spell=getSpell(spellId);if(!spell.creatureId)return previous.spellAccess(championId,spellId,affinities,learnedSpells);
 const learned=learnedSpells.includes(spell.id),rank=(affinities??getChampion(championId).affinities)[spell.element]??0,enough=rank>=spell.level;
 const reason=!learned?`Defeat ${getCreature(spell.creatureId).name} to learn ${spell.name}.`:`Requires ${spell.level} ${spell.element.charAt(0).toUpperCase()+spell.element.slice(1)} affinity points.`;
 return {unlocked:learned&&enough,requiredAffinity:spell.level,level:spell.level,branch:spell.branch,...(!(learned&&enough)?{reason}:{})};
}
export function availableSpellIds(championId:string,loadout:readonly string[],affinities?:AffinityAllocation,learnedSpells:readonly string[]=[]):string[] {
 const signature=getSignature(championId).id;
 return [...loadout.filter(id=>id!==signature&&byId.has(id)&&spellAccess(championId,id,affinities,learnedSpells).unlocked),...(spellAccess(championId,signature,affinities,learnedSpells).unlocked?[signature]:[])];
}
export function validateLoadout(championId:string,input:unknown,affinities?:AffinityAllocation,learnedSpells:readonly string[]=[]):string[] {
 getChampion(championId);if(affinities!==undefined)validateAffinityAllocation(affinities,MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL);validateLearnedSpells(learnedSpells);
 const signature=getSignature(championId).id;
 if(!Array.isArray(input)||input.length!==4||new Set(input).size!==4||input.some(id=>typeof id!=='string'||!byId.has(id)||id===signature))throw new Error('Equip exactly 4 different spells. Your own signature has its fixed fifth slot.');
 for(const id of input){const access=spellAccess(championId,id,affinities,learnedSpells);if(!access.unlocked)throw new Error(`${getSpell(id).name}: ${access.reason}`);}
 return [...input] as string[];
}
export function repairLoadout(championId:string,input:unknown,affinities?:AffinityAllocation,learnedSpells:readonly string[]=[]):string[] {
 getChampion(championId);if(affinities!==undefined)validateAffinityAllocation(affinities,MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL);validateLearnedSpells(learnedSpells);
 const signature=getSignature(championId).id,supplied=Array.isArray(input)?input:[],used=new Set<string>();
 const repaired=Array.from({length:4},(_,slot):string|undefined=>{const id=supplied[slot];if(typeof id!=='string'||id===signature||used.has(id)||!byId.has(id)||!spellAccess(championId,id,affinities,learnedSpells).unlocked)return undefined;used.add(id);return id;});
 const knownSignatures=learnedSpells.filter(id=>getSpell(id).signatureChampionId);
 const choices=[...previous.defaultLoadout(championId,affinities,knownSignatures),...ALL_SPELLS.map(spell=>spell.id)].filter(id=>id!==signature&&spellAccess(championId,id,affinities,learnedSpells).unlocked);
 for(let slot=0;slot<4;slot++)if(repaired[slot]===undefined){const replacement=choices.find(id=>!used.has(id));if(!replacement)throw new Error('This affinity allocation has fewer than four available spells.');repaired[slot]=replacement;used.add(replacement);}
 return validateLoadout(championId,repaired,affinities,learnedSpells);
}
export function defaultLoadout(championId:string,affinities?:AffinityAllocation,learnedSpells:readonly string[]=[]):string[] {
 return repairLoadout(championId,previous.defaultLoadout(championId,affinities,learnedSpells.filter(id=>getSpell(id).signatureChampionId)),affinities,learnedSpells);
}
const controls:readonly StatusId[]=['rooted','chilled','blind','concussed'];
const positives:readonly StatusId[]=['wet','ward','clarity','anchored','haste','resolve'];
const effectiveCache=new Map<string,Spell>();
export function effectiveSpell(championId:string,spellId:string,affinities?:AffinityAllocation):Spell {
 const base=getSpell(spellId);if(!base.creatureId)return previous.effectiveSpell(championId,spellId,affinities);
 const rank=Math.max(0,Math.min(MAX_AFFINITY_LEVEL,(affinities??getChampion(championId).affinities)[base.element]??0)),key=`${championId}:${spellId}:${rank}`,cached=effectiveCache.get(key);if(cached)return cached;
 const spell:Spell={...base,cost:spellCost(championId,spellId,affinities)};
 for(const channel of ['harmful','friendly','self'] as const)if(base[channel])spell[channel]=base[channel]!.map(effect=>({...effect}));
 if(spell.range>0)spell.range+=Number(rank>=2)+Number(rank>=5);
 const potency=Number(rank>=3)+Number(rank>=6);
 if(spell.damage>0)spell.damage+=potency;else if(spell.heal>0)spell.heal+=potency;else{const ward=[...(spell.friendly??[]),...(spell.self??[])].find(effect=>effect.id==='ward');if(ward)ward.power=(ward.power??1)+potency;else if(spell.recharge)spell.recharge+=potency;else if(spell.steal)spell.steal+=potency;}
 if(rank>=4)for(const channel of ['harmful','friendly','self'] as const)for(const effect of spell[channel]??[])if(!controls.includes(effect.id)&&(channel==='harmful'||positives.includes(effect.id)))effect.turns=Math.min(effect.id==='ward'||effect.id==='burn'?2:3,effect.turns+1);
 spell.description=describeSpell(spell);const frozen=freezeSpell(spell);effectiveCache.set(key,frozen);return frozen;
}
export function spellScalingSummary(championId:string,spellId:string,affinities?:AffinityAllocation):string {
 const base=getSpell(spellId);if(!base.creatureId)return previous.spellScalingSummary(championId,spellId,affinities);
 const spell=effectiveSpell(championId,spellId,affinities),changes:string[]=[];
 if(spell.range>base.range)changes.push(`+${spell.range-base.range} reach`);
 for(const [field,label] of [['damage','damage'],['heal','healing'],['recharge','Flux restored'],['steal','Flux stolen']] as const)if((spell[field]??0)>(base[field]??0))changes.push(`+${(spell[field]??0)-(base[field]??0)} ${label}`);
 let duration=false;for(const channel of ['harmful','friendly','self'] as const)(spell[channel]??[]).forEach((effect,index)=>{const original=base[channel]![index];if(effect.id==='ward'&&(effect.power??1)>(original.power??1))changes.push(`+${(effect.power??1)-(original.power??1)} Ward`);if(effect.turns>original.turns)duration=true;});
 if(duration)changes.push('+1 status round');return changes.length?changes.join(' · '):'Base strength';
}
