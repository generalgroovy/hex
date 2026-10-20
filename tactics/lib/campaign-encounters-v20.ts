import {CHAMPIONS,getChampion} from './roster-v13.ts';
import {STORY_ENCOUNTERS as legacyEncounters} from './story-v16.ts';
import {CREATURES,type CreatureClass} from './campaign-creatures-v20.ts';
import {availableCampaignCreatures,type CampaignProfile} from './campaign-profile-v20.ts';
import {getCreatureSpell} from './spells-v20.ts';
export type CampaignEncounter={id:string;kind:'story'|'field';targetCreatureId?:string;index:number;chapter:1|2|3;title:string;championId:string;description:string;lesson:string;mapId:string;championCount:0|1|2|3;enemyChampions:string[];enemyCreatures:string[];enemyAffinity:number;rewardCreatureIds:string[]};
export type CampaignEncounterStatus=CampaignEncounter&{available:boolean;completed:boolean};
export const CAMPAIGN_ENCOUNTERS:CampaignEncounter[]=CHAMPIONS.map((hero,index)=>{
 const old=legacyEncounters.find(encounter=>encounter.id===hero.id)!,chapter=(Math.floor(index/10)+1) as 1|2|3,championCount=chapter;
 const enemyAffinity=chapter===1?5+Math.floor(index/2):chapter===2?8+Math.floor((index-10)/3):10+Math.floor((index-20)/2);
 const strengthClass:CreatureClass=chapter===1?(index<4?'lesser':'standard'):index<13?'lesser':index<16?'standard':'greater';
 const pool=CREATURES.filter(creature=>creature.strengthClass===strengthClass&&creature.elements.length<=Math.min(6,1+Math.floor(index/4))&&creature.elements.includes(hero.element));
 const fallback=CREATURES.filter(creature=>creature.strengthClass===strengthClass);
 const choices=pool.length>=3-championCount?pool:fallback;
 // The first fight teaches displacement without stacking two enemy healers.
 const enemyCreatures=index===0?['creature-air-pip','creature-water-brookling']:Array.from({length:3-championCount},(_,slot)=>choices[(index+slot)%choices.length].id);
 const before=new Set(availableCampaignCreatures({defeated:CHAMPIONS.slice(0,index).map(hero=>hero.id)}).map(creature=>creature.id));
 const rewardCreatureIds=availableCampaignCreatures({defeated:CHAMPIONS.slice(0,index+1).map(hero=>hero.id)}).filter(creature=>!before.has(creature.id)).map(creature=>creature.id);
 const lesson=hero.id==='oh_tipi'?'Pip pushes and Brookling pulls. Leave space behind your party, then separate them from Oh Tipi before he can heal them.':hero.id==='s_wayne'?'Wither weakens healing. Cleansing removes it before recovery; nearby Earth and Water companions grant Ward against his repeated attacks.':hero.id==='sai_laas'?'Sai Laas spends health to strike. Spread out from his allies, protect the wounded, and answer while his cost still matters.':old.lesson;
 return {id:hero.id,kind:'story',index,chapter,title:old.title,championId:hero.id,description:old.situation,lesson,mapId:`arena:2:CH-${String(index+1).padStart(2,'0')}-${hero.id.replaceAll('_','-').toUpperCase()}`.slice(0,32),championCount,enemyChampions:old.opponents.slice(0,championCount),enemyCreatures,enemyAffinity,rewardCreatureIds};
});
/** Optional, seeded learning battles fill the creature acquisition gaps in the fixed story. */
export const CAMPAIGN_FIELD_ENCOUNTERS:CampaignEncounter[]=CREATURES.map((creature,index)=>{
 const lesser=CREATURES.filter(candidate=>candidate.strengthClass==='lesser'&&candidate.id!==creature.id);
 const escorts=[...lesser.filter(candidate=>candidate.elements.some(element=>creature.elements.includes(element))),...lesser.filter(candidate=>!candidate.elements.some(element=>creature.elements.includes(element)))].slice(0,2);
 return {id:`field:${creature.id}`,kind:'field',targetCreatureId:creature.id,index:30+index,chapter:({lesser:1,standard:2,greater:3} as const)[creature.strengthClass],title:creature.name,championId:creature.championId,description:`Defeat ${creature.name} to learn ${getCreatureSpell(creature.id).name}. Learned spells are kept even if your party falls.`,lesson:getCreatureSpell(creature.id).description,mapId:`arena:2:FIELD-${String(index+1).padStart(3,'0')}-${creature.id.slice(-10).toUpperCase().replace(/[^A-Z0-9-]/g,'-')}`,championCount:0,enemyChampions:[],enemyCreatures:[creature.id,...escorts.map(escort=>escort.id)],enemyAffinity:0,rewardCreatureIds:[]};
});
export function getCampaignEncounter(id:string):CampaignEncounter{const encounter=[...CAMPAIGN_ENCOUNTERS,...CAMPAIGN_FIELD_ENCOUNTERS].find(encounter=>encounter.id===id);if(!encounter)throw new Error('Choose a campaign encounter.');return encounter;}
export function campaignEncounters(profile:Pick<CampaignProfile,'defeated'>):CampaignEncounterStatus[]{
 const next=CAMPAIGN_ENCOUNTERS.findIndex(encounter=>!profile.defeated.includes(encounter.id));
 return CAMPAIGN_ENCOUNTERS.map(encounter=>({...encounter,completed:profile.defeated.includes(encounter.id),available:profile.defeated.includes(encounter.id)||encounter.index===next}));
}
export function campaignFieldEncounters(profile:Pick<CampaignProfile,'defeated'|'learnedSpells'>):CampaignEncounterStatus[]{
 const available=new Set(availableCampaignCreatures(profile).map(creature=>creature.id));
 return CAMPAIGN_FIELD_ENCOUNTERS.filter(encounter=>available.has(encounter.targetCreatureId!)).map(encounter=>({...encounter,available:true,completed:profile.learnedSpells.includes(getCreatureSpell(encounter.targetCreatureId!).id)}));
}
export function campaignEncounterStatus(profile:Pick<CampaignProfile,'defeated'|'learnedSpells'>,id:string):CampaignEncounterStatus{
 const encounter=getCampaignEncounter(id);
 if(encounter.kind==='story')return campaignEncounters(profile).find(entry=>entry.id===id)!;
 const available=availableCampaignCreatures(profile).some(creature=>creature.id===encounter.targetCreatureId);
 return {...encounter,available,completed:profile.learnedSpells.includes(getCreatureSpell(encounter.targetCreatureId!).id)};
}
