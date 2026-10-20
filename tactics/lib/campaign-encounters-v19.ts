import {CHAMPIONS,getChampion} from './roster-v13.ts';
import {STORY_ENCOUNTERS as legacyEncounters} from './story-v16.ts';
import {CREATURES,type CreatureClass} from './campaign-creatures-v19.ts';
import {availableCampaignCreatures,type CampaignProfile} from './campaign-profile-v19.ts';
export type CampaignEncounter={id:string;index:number;chapter:1|2|3;title:string;championId:string;description:string;lesson:string;mapId:string;championCount:1|2|3;enemyChampions:string[];enemyCreatures:string[];enemyAffinity:number;rewardCreatureIds:string[]};
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
 return {id:hero.id,index,chapter,title:old.title,championId:hero.id,description:old.situation,lesson,mapId:`arena:2:CH-${String(index+1).padStart(2,'0')}-${hero.id.replaceAll('_','-').toUpperCase()}`.slice(0,32),championCount,enemyChampions:old.opponents.slice(0,championCount),enemyCreatures,enemyAffinity,rewardCreatureIds};
});
export function getCampaignEncounter(id:string):CampaignEncounter{const encounter=CAMPAIGN_ENCOUNTERS.find(encounter=>encounter.id===id);if(!encounter)throw new Error('Choose a campaign encounter.');return encounter;}
export function campaignEncounters(profile:Pick<CampaignProfile,'defeated'>):CampaignEncounterStatus[]{
 const next=CAMPAIGN_ENCOUNTERS.findIndex(encounter=>!profile.defeated.includes(encounter.id));
 return CAMPAIGN_ENCOUNTERS.map(encounter=>({...encounter,completed:profile.defeated.includes(encounter.id),available:profile.defeated.includes(encounter.id)||encounter.index===next}));
}
