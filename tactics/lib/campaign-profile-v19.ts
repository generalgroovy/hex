import {CHAMPIONS,getChampion,validateAffinityAllocation,affinityTotal,type AffinityAllocation} from './roster-v13.ts';
import {canonicalBuild,type CharacterBuild} from './character-creation-v17.ts';
import {getSignature,validateLoadout,defaultLoadout} from './spells-v16.ts';
import {readStoryProgress} from './story-v16.ts';
import {CREATURES,getCreature,type CreatureDefinition} from './campaign-creatures-v19.ts';

export type CampaignProfile={format:3;defeated:string[];hero:CharacterBuild;companions:[string,string]};
export const CAMPAIGN_PROFILE_KEY='hex-confluence-campaign-profile-v19';
export const CAMPAIGN_SAVE_KEY='hex-confluence-campaign-match-v19';
export const LEGACY_CAMPAIGN_PROFILE_KEY='hex-confluence-story-v11';
const plain=(value:unknown):value is Record<string,unknown>=>!!value&&typeof value==='object'&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value));
const orderedVictories=(input:unknown)=>{
 if(!Array.isArray(input)||input.length>CHAMPIONS.length||input.some(id=>typeof id!=='string'||!CHAMPIONS.some(hero=>hero.id===id))||new Set(input).size!==input.length)throw new Error('Campaign victories are invalid.');
 return CHAMPIONS.filter(hero=>input.includes(hero.id)).map(hero=>hero.id);
};
export const campaignAffinityBudget=(profile:Pick<CampaignProfile,'defeated'>)=>Math.min(18,5+profile.defeated.length);
/** Every victory can unlock one further spell rank; free reassignment cannot skip the curve. */
export const campaignAffinityRankCap=(profile:Pick<CampaignProfile,'defeated'>)=>Math.min(6,3+profile.defeated.length);
export const learnedCampaignSignatures=(profile:Pick<CampaignProfile,'defeated'>)=>orderedVictories(profile.defeated).map(id=>getSignature(id).id).sort();
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
 if(!plain(input)||input.format!==3||Object.keys(input).some(key=>!['format','defeated','hero','companions'].includes(key)))throw new Error('This campaign profile could not be read.');
 const defeated=orderedVictories(input.defeated),partial={defeated};
 const hero=validateCampaignHero(input.hero,campaignAffinityBudget(partial),learnedCampaignSignatures(partial));
 if(!Array.isArray(input.companions)||input.companions.length!==2||new Set(input.companions).size!==2)throw new Error('Choose two different elemental companions.');
 const available=new Set(availableCampaignCreatures(partial).map(creature=>creature.id));
 const companions=input.companions.map(id=>{if(typeof id!=='string'||!available.has(id))throw new Error('That companion has not joined your journey yet.');return getCreature(id).id;}) as [string,string];
 return {format:3,defeated,hero,companions};
}
function initialProfile(defeated:string[]=[]):CampaignProfile{
 const available=availableCampaignCreatures({defeated}),first=available.find(creature=>creature.strengthClass==='lesser'&&creature.elements[0]==='water')??available[0],second=available.find(creature=>creature.strengthClass==='lesser'&&creature.elements[0]==='fire')??available.find(creature=>creature.id!==first.id)!;
 return {format:3,defeated,hero:canonicalBuild('oh_tipi'),companions:[first.id,second.id]};
}
/** Migration reads old progress without mutating its storage key or match saves. */
export function readCampaignProfile(input:unknown,legacyProgress?:unknown):CampaignProfile{
 let decoded=input;if(typeof decoded==='string'){try{decoded=decoded.length<=100000?JSON.parse(decoded):null;}catch{decoded=null;}}
 try{return validateCampaignProfile(decoded);}catch{}
 if(plain(decoded)&&decoded.format===3){
  const defeated=CHAMPIONS.filter(hero=>Array.isArray(decoded.defeated)&&decoded.defeated.includes(hero.id)).map(hero=>hero.id),repaired=initialProfile(defeated);
  if(plain(decoded.hero)){
   const rawHero=decoded.hero;
   try{repaired.hero=validateCampaignHero(rawHero,campaignAffinityBudget(repaired),learnedCampaignSignatures(repaired));}catch{
    const known=CHAMPIONS.find(hero=>hero.id===rawHero.championId);
    if(known)repaired.hero=canonicalBuild(known.id);
    const name=decoded.hero.name;if(typeof name==='string'&&name.trim().length>=1&&name.trim().length<=24&&!/[\x00-\x1f\x7f<>]/.test(name))repaired.hero.name=name.trim();
   }
  }
  const available=availableCampaignCreatures(repaired).map(creature=>creature.id),chosen=Array.isArray(decoded.companions)?[...new Set(decoded.companions.filter((id):id is string=>typeof id==='string'&&available.includes(id)))].slice(0,2):[];
  for(const id of [...repaired.companions,...available])if(chosen.length<2&&!chosen.includes(id))chosen.push(id);
  repaired.companions=chosen as [string,string];return repaired;
 }
 const legacy=readStoryProgress(legacyProgress??decoded),profile=initialProfile(legacy.defeated);
 const allocation=legacy.affinities[profile.hero.championId];
 if(allocation)try{profile.hero=validateCampaignHero({...profile.hero,affinities:allocation,loadout:defaultLoadout(profile.hero.championId,allocation,learnedCampaignSignatures(profile))},campaignAffinityBudget(profile),learnedCampaignSignatures(profile));}catch{}
 return profile;
}
export function updateCampaignHero(profile:CampaignProfile,build:unknown):CampaignProfile{
 const current=validateCampaignProfile(profile);return {...current,hero:validateCampaignHero(build,campaignAffinityBudget(current),learnedCampaignSignatures(current))};
}
export function updateCampaignCompanions(profile:CampaignProfile,ids:readonly string[]):CampaignProfile{return validateCampaignProfile({...profile,companions:[...ids]});}
