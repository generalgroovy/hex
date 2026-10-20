/** Knowledge comes from individual enemy defeats; affinity comes only from story victories. */
export * from './campaign-profile-v20.ts';
export * from './campaign-encounters-v20.ts';
import {validateCampaignProfile,campaignAffinityBudget,type CampaignProfile} from './campaign-profile-v20.ts';
import {campaignEncounterStatus,getCampaignEncounter} from './campaign-encounters-v20.ts';
import {createSimGame,restoreSimState,type SimState} from './tactics-v20.ts';
import {teachingForEnemy} from './spells-v20.ts';
import type {SimState as PresentedState} from './tactics-v16.ts';
export function createCampaignGame(profile:CampaignProfile,id:string):SimState{
 const current=validateCampaignProfile(profile);if(!campaignEncounterStatus(current,id).available)throw new Error('Finish more story encounters before travelling here.');
 return createSimGame({profile:current,encounterId:id});
}
export const restoreCampaignGame=restoreSimState;
export type LearningReward={spellId:string;enemyId:string;enemyKind:'champion'|'creature';enemyName:string;unitId:string};
export type CampaignProgressResult={profile:CampaignProfile;learned:LearningReward[];victory:boolean;affinityGained:number};
/** Dead enemies remain in the validated state, so reloads can recover knowledge without an unbounded receipt log. */
export function defeatedEnemyTeachings(state:SimState):LearningReward[]{
 const rewards=new Map<string,LearningReward>();
 for(const unit of state.units.filter(unit=>unit.owner===1&&unit.hp===0)){
  const spell=teachingForEnemy(unit);rewards.set(spell.id,{spellId:spell.id,enemyId:unit.creatureId??unit.championId,enemyKind:unit.kind==='creature'?'creature':'champion',enemyName:unit.displayName??unit.championId,unitId:unit.id});
 }
 return [...rewards.values()].sort((a,b)=>a.spellId.localeCompare(b.spellId));
}
export function applyCampaignProgress(profile:CampaignProfile,input:unknown):CampaignProgressResult{
 const current=validateCampaignProfile(profile),state=restoreSimState(input),start=state.campaign.profile,encounter=getCampaignEncounter(state.campaign.encounterId);
 if(start.defeated.some(id=>!current.defeated.includes(id)))throw new Error('This battle belongs to a journey with later story progress. Restore its campaign profile first.');
 const known=new Set([...current.learnedSpells,...start.learnedSpells]);
 const learned=defeatedEnemyTeachings(state).filter(reward=>!known.has(reward.spellId));for(const reward of learned)known.add(reward.spellId);
 const victory=encounter.kind==='story'&&state.winner===0&&!current.defeated.includes(encounter.id)&&campaignEncounterStatus(current,encounter.id).available;
 const next=validateCampaignProfile({...current,learnedSpells:[...known].sort(),defeated:victory?[...current.defeated,encounter.id]:current.defeated});
 return {profile:next,learned,victory,affinityGained:campaignAffinityBudget(next)-campaignAffinityBudget(current)};
}
export function awardCampaignVictory(profile:CampaignProfile,id:string,input:unknown):CampaignProfile{
 const current=validateCampaignProfile(profile);
 try{const state=restoreSimState(input);if(state.campaign.encounterId!==id)return current;return applyCampaignProgress(current,state).profile}catch{return current}
}
/** Render adapter only. Campaign state never enters a v16 resolver or save slot. */
export function presentCampaign(state:SimState):PresentedState{
 return {...state,rulesVersion:16,scores:[0,0],learnedSignatures:[state.learnedSignatures[0],state.learnedSignatures[1]],winner:state.winner===null||state.winner==='draw'?state.winner:state.winner===0?0:1,units:state.units.map(unit=>({...unit,owner:unit.owner===0?0:1})),lastResolution:state.lastResolution.map(event=>({...event,owner:event.owner===undefined?undefined:event.owner===0?0:1}))};
}
