import {CHAMPIONS,getChampion,validateAffinityAllocation,affinityTotal} from './roster-v13.ts';
import {canonicalBuild,type CharacterBuild} from './character-creation-v17.ts';
import {getSignature,getCreatureSpell,TEACHABLE_SPELLS,validateLearnedSpells,validateLoadout} from './spells-v20.ts';
import {readCampaignProfile as readPreviousProfile} from './campaign-profile-v19.ts';
import {CAMPAIGN_ENCOUNTERS as previousEncounters} from './campaign-encounters-v19.ts';
import {STORY_ENCOUNTERS as legacyEncounters} from './story-v16.ts';
import {CREATURES,getCreature,type CreatureDefinition} from './campaign-creatures-v20.ts';

/** defeated contains completed STORY encounters; learnedSpells includes individual enemy defeats. */
export type CampaignProfile={format:4;defeated:string[];learnedSpells:string[];hero:CharacterBuild;companions:[string,string]};
export const CAMPAIGN_PROFILE_KEY='hex-confluence-campaign-profile-v20';
export const CAMPAIGN_SAVE_KEY='hex-confluence-campaign-match-v20';
export const PREVIOUS_CAMPAIGN_PROFILE_KEY='hex-confluence-campaign-profile-v19';
export const LEGACY_CAMPAIGN_PROFILE_KEY='hex-confluence-story-v11';
const plain=(value:unknown):value is Record<string,unknown>=>!!value&&typeof value==='object'&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value));
const decode=(value:unknown):unknown=>{if(typeof value!=='string')return value;try{return value.length<=200000?JSON.parse(value):null}catch{return null}};
const knownVictories=(value:unknown)=>CHAMPIONS.filter(hero=>Array.isArray(value)&&value.includes(hero.id)).map(hero=>hero.id);
function orderedVictories(input:unknown):string[]{
 if(!Array.isArray(input)||input.length>CHAMPIONS.length||input.some(id=>typeof id!=='string'||!CHAMPIONS.some(hero=>hero.id===id))||new Set(input).size!==input.length)throw new Error('Campaign victories are invalid.');
 return knownVictories(input);
}
export const campaignAffinityBudget=(profile:Pick<CampaignProfile,'defeated'>)=>Math.min(18,5+profile.defeated.length);
export const campaignAffinityRankCap=(profile:Pick<CampaignProfile,'defeated'>)=>Math.min(6,3+profile.defeated.length);
/** An old completed battle proves that every opposing actor in its authored lineup fell. */
export function spellsFromCompletedEncounters(defeated:readonly string[]):string[]{
 return [...new Set(previousEncounters.filter(encounter=>defeated.includes(encounter.id)).flatMap(encounter=>[
  ...encounter.enemyChampions.map(id=>getSignature(id).id),...encounter.enemyCreatures.map(id=>getCreatureSpell(id).id),
 ]))].sort();
}
export const learnedCampaignSpells=(profile:Pick<CampaignProfile,'learnedSpells'>)=>validateLearnedSpells(profile.learnedSpells);
/** Compatibility name for callers; this library also contains creature-origin spells. */
export const learnedCampaignSignatures=learnedCampaignSpells;
export function availableCampaignCreatures(profile:Pick<CampaignProfile,'defeated'>):CreatureDefinition[]{
 const won=profile.defeated.length,maxElements=Math.min(6,1+Math.floor(won/4));
 return CREATURES.filter(creature=>creature.elements.length<=maxElements&&won>=({lesser:0,standard:3,greater:10}[creature.strengthClass]));
}
export function validateCampaignHero(input:unknown,budget:number,learned:readonly string[]):CharacterBuild{
 if(!plain(input)||Object.keys(input).some(key=>!['championId','name','affinities','loadout'].includes(key))||typeof input.championId!=='string')throw new Error('Choose a hero appearance, name, affinities and four spells.');
 const hero=getChampion(input.championId),affinities=validateAffinityAllocation(input.affinities,budget),primary=affinities[hero.element]??0;
 if(affinityTotal(affinities)<5||primary<2||Object.values(affinities).some(value=>(value??0)>primary))throw new Error(`Spend at least five affinity; keep ${hero.element} at two or more and at least as high as every other element.`);
 const rankCap=Math.min(6,budget-2);
 if(Object.values(affinities).some(value=>(value??0)>rankCap))throw new Error(`An affinity can reach rank ${rankCap} at this point in the journey. Each victory unlocks the next rank, up to six.`);
 if(typeof input.name!=='string'||input.name.trim().length<1||input.name.trim().length>24||/[\x00-\x1f\x7f<>]/.test(input.name))throw new Error('Use a hero name from 1 to 24 plain characters.');
 return {championId:hero.id,name:input.name.trim(),affinities,loadout:validateLoadout(hero.id,input.loadout,affinities,learned)};
}
export function validateCampaignProfile(input:unknown):CampaignProfile{
 if(!plain(input)||input.format!==4||Object.keys(input).some(key=>!['format','defeated','learnedSpells','hero','companions'].includes(key)))throw new Error('This campaign profile could not be read.');
 const defeated=orderedVictories(input.defeated),partial={defeated};
 const learnedSpells=validateLearnedSpells([...new Set([...validateLearnedSpells(input.learnedSpells),...defeated.map(id=>getSignature(id).id)])]);
 const hero=validateCampaignHero(input.hero,campaignAffinityBudget(partial),learnedSpells);
 if(!Array.isArray(input.companions)||input.companions.length!==2||new Set(input.companions).size!==2)throw new Error('Choose two different elemental companions.');
 const available=new Set(availableCampaignCreatures(partial).map(creature=>creature.id));
 const companions=input.companions.map(id=>{if(typeof id!=='string'||!available.has(id))throw new Error('That companion has not joined your journey yet.');return getCreature(id).id;}) as [string,string];
 return {format:4,defeated,learnedSpells,hero,companions};
}
function initialProfile(defeated:string[]=[]):CampaignProfile{
 return {format:4,defeated,learnedSpells:defeated.map(id=>getSignature(id).id).sort(),hero:canonicalBuild('oh_tipi'),companions:['creature-water-puddle','creature-fire-cinder']};
}
function repairCurrent(decoded:Record<string,unknown>):CampaignProfile{
 const repaired=initialProfile(knownVictories(decoded.defeated)),known=new Set(TEACHABLE_SPELLS.map(spell=>spell.id));
 if(Array.isArray(decoded.learnedSpells))repaired.learnedSpells=[...new Set([...repaired.learnedSpells,...decoded.learnedSpells.filter((id):id is string=>typeof id==='string'&&known.has(id))])].sort();
 if(plain(decoded.hero)){
  const rawHero=decoded.hero;
  try{repaired.hero=validateCampaignHero(rawHero,campaignAffinityBudget(repaired),repaired.learnedSpells)}catch{
   const champion=CHAMPIONS.find(hero=>hero.id===rawHero.championId);if(champion)repaired.hero=canonicalBuild(champion.id);
   const name=rawHero.name;if(typeof name==='string'&&name.trim().length>=1&&name.trim().length<=24&&!/[\x00-\x1f\x7f<>]/.test(name))repaired.hero.name=name.trim();
  }
 }
 const available=availableCampaignCreatures(repaired).map(creature=>creature.id),chosen=Array.isArray(decoded.companions)?[...new Set(decoded.companions.filter((id):id is string=>typeof id==='string'&&available.includes(id)))].slice(0,2):[];
 for(const id of [...repaired.companions,...available])if(chosen.length<2&&!chosen.includes(id))chosen.push(id);
 repaired.companions=chosen as [string,string];return validateCampaignProfile(repaired);
}
/** New storage never overwrites old profile/match keys. No in-flight battle is converted. */
export function readCampaignProfile(input:unknown,previousProfile?:unknown,legacyProgress?:unknown):CampaignProfile{
 const decoded=decode(input);try{return validateCampaignProfile(decoded)}catch{}
 if(plain(decoded)&&decoded.format===4)return repairCurrent(decoded);
 const candidate=plain(decoded)&&decoded.format===3?decoded:decode(previousProfile),hasPrevious=plain(candidate)&&candidate.format===3;
 const legacy=legacyProgress??(!hasPrevious?previousProfile??decoded:undefined);
 const old=readPreviousProfile(hasPrevious?candidate:null,legacy);
 const learnedSpells=hasPrevious?spellsFromCompletedEncounters(old.defeated):old.defeated.map(id=>getSignature(id).id);
 if(!hasPrevious)for(const encounter of legacyEncounters.filter(encounter=>old.defeated.includes(encounter.id)))for(const id of encounter.opponents)learnedSpells.push(getSignature(id).id);
 return validateCampaignProfile({...old,format:4,learnedSpells:[...new Set(learnedSpells)].sort()});
}
export function updateCampaignHero(profile:CampaignProfile,build:unknown):CampaignProfile{
 const current=validateCampaignProfile(profile);return {...current,hero:validateCampaignHero(build,campaignAffinityBudget(current),current.learnedSpells)};
}
export function updateCampaignCompanions(profile:CampaignProfile,ids:readonly string[]):CampaignProfile{return validateCampaignProfile({...profile,companions:[...ids]});}
