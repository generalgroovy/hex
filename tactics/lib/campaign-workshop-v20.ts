import {getChampion,affinityTotal,type AffinityAllocation} from './roster-v13.ts';
import {canonicalBuild,type CharacterBuild} from './character-creation-v17.ts';
import {ALL_SPELLS,effectiveSpell,getSpell,getSignature,repairLoadout,spellAccess,spellOrigin,validateLoadout,spellFootprintDescription,type Spell,type EnemySpell} from './spells-v20.ts';
import {learnedCampaignSpells,type CampaignProfile} from './campaign-profile-v20.ts';
import {CURRENT_SPELL_MODEL,profileSpell,spellProfileLabel} from './spell-profile-v42.ts';
import {profiledEffectLabel,profiledSpellDescription} from './spell-profile-label-v42.ts';
import type {Element} from './game.ts';

export type LibraryFilter='ready'|'learned'|'all';
export type SpellLibraryEntry={
 spell:Spell;effective:Spell;origin:EnemySpell|null;learned:boolean;ready:boolean;
 affinity:number;requiredAffinity:number;fixed:boolean;equippedSlot:number;requirements:string[];
};
const title=(value:string)=>value.charAt(0).toUpperCase()+value.slice(1);
const searchable=(value:string)=>value.normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase();

/** Availability and teaching are separate: knowing a spell does not waive affinity. */
export function campaignSpellEntry(profile:CampaignProfile,build:CharacterBuild,spellId:string):SpellLibraryEntry{
 const spell=getSpell(spellId),origin=spellOrigin(spellId),knowledge=learnedCampaignSpells(profile);
 const fixed=spell.id===getSignature(build.championId).id,learned=!origin||fixed||knowledge.includes(spell.id);
 const access=spellAccess(build.championId,spell.id,build.affinities,knowledge),affinity=build.affinities[spell.element]??0;
 const requirements:string[]=[];
 if(!learned&&origin)requirements.push(`Defeat ${origin.name} to learn this spell.`);
 if(affinity<access.requiredAffinity)requirements.push(`${title(spell.element)} affinity ${affinity}/${access.requiredAffinity}.`);
 if(!access.unlocked&&!requirements.length&&access.reason)requirements.push(access.reason);
 return {spell,effective:profileSpell(effectiveSpell(build.championId,spell.id,build.affinities),CURRENT_SPELL_MODEL),origin,learned,ready:access.unlocked,affinity,requiredAffinity:access.requiredAffinity,fixed,equippedSlot:build.loadout.indexOf(spell.id),requirements};
}

export function campaignSpellLibrary(profile:CampaignProfile,build:CharacterBuild,options:{query?:string;element?:Element|'all';filter?:LibraryFilter}={}):SpellLibraryEntry[]{
 const words=searchable(options.query??'').trim().split(/\s+/).filter(Boolean);
 return ALL_SPELLS.map(spell=>campaignSpellEntry(profile,build,spell.id)).filter(entry=>{
  if(options.element&&options.element!=='all'&&entry.spell.element!==options.element)return false;
  if(options.filter==='ready'&&!entry.ready)return false;
  if(options.filter==='learned'&&!entry.learned)return false;
  const text=searchable([entry.spell.name,entry.spell.element,entry.spell.branch,entry.origin?.name??'core spell',profiledSpellDescription(entry.effective),profiledEffectLabel(entry.effective)].join(' '));
  return words.every(word=>text.includes(word));
 }).sort((a,b)=>Number(b.ready)-Number(a.ready)||Number(b.learned)-Number(a.learned)||b.spell.level-a.spell.level||a.spell.name.localeCompare(b.spell.name));
}

/** Equipping an already-equipped spell swaps slots; no spell is duplicated or lost. */
export function equipCampaignSpell(profile:CampaignProfile,build:CharacterBuild,slot:number,spellId:string):CharacterBuild{
 if(!Number.isInteger(slot)||slot<0||slot>=4)throw new Error('Choose one of the four spell slots.');
 const entry=campaignSpellEntry(profile,build,spellId);
 if(entry.fixed)throw new Error('Your own signature keeps its fixed fifth slot.');
 if(!entry.ready)throw new Error(entry.requirements.join(' ')||'This spell is not ready to equip.');
 const loadout=[...build.loadout],other=loadout.indexOf(spellId);
 if(other>=0&&other!==slot)loadout[other]=loadout[slot];
 loadout[slot]=spellId;
 return {...build,loadout:validateLoadout(build.championId,loadout,build.affinities,learnedCampaignSpells(profile))};
}

export type SpellComparisonRow={label:string;current:string;candidate:string;change?:string};
export function compareCampaignSpells(current:Spell,candidate:Spell):SpellComparisonRow[]{
 const rows:SpellComparisonRow[]=[];
 for(const [key,label] of [['cost','Flux'],['range','Reach'],['cooldown','Recovery'],['damage','Damage'],['heal','Healing']] as const){
  if((key==='damage'||key==='heal')&&!current[key]&&!candidate[key])continue;
  const delta=candidate[key]-current[key];
  rows.push({label,current:String(current[key]),candidate:String(candidate[key]),...(delta?{change:`${delta>0?'+':''}${delta}`}:{})});
 }
 rows.push({label:'Area',current:spellProfileLabel(current)||spellFootprintDescription(current),candidate:spellProfileLabel(candidate)||spellFootprintDescription(candidate)});
 return rows;
}

export function repairedSpellSlots(before:readonly string[],after:readonly string[]):string[]{
 return after.flatMap((id,index)=>id!==before[index]?[`Slot ${index+1}: ${before[index]?getSpell(before[index]).name:'Empty'} → ${getSpell(id).name}`]:[]);
}

export function changeCampaignAppearance(current:CharacterBuild,championId:string,learned:readonly string[],rankCap:number):CharacterBuild{
 const base=canonicalBuild(championId),spent=Math.max(5,affinityTotal(current.affinities)),primary=getChampion(championId).element,affinities:AffinityAllocation={...base.affinities};
 const elements=[primary,...Object.keys(affinities).filter(element=>element!==primary),...(['fire','water','earth','air','light','dark'] as Element[]).filter(element=>!affinities[element])].slice(0,3) as Element[];
 let remaining=spent-affinityTotal(affinities);
 for(const element of elements){const add=Math.min(remaining,rankCap-(affinities[element]??0));if(add>0){affinities[element]=(affinities[element]??0)+add;remaining-=add}}
 if(remaining)throw new Error('This investment does not fit the current element level limit.');
 return {...base,name:current.name===getChampion(current.championId).name?base.name:current.name,affinities,loadout:repairLoadout(championId,current.loadout,affinities,learned)};
}

export function campaignDraftHint(build:CharacterBuild):string|null{
 const missing=5-affinityTotal(build.affinities);
 if(missing>0)return `Assign ${missing} affinity point${missing===1?'':'s'} to use this build.`;
 if(!build.name.trim())return 'Choose a name to use this build.';
 return null;
}
