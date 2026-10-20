/** Ordered campaign19. Old story16 profiles and matches remain independently readable. */
export * from './campaign-profile-v19.ts';
export * from './campaign-encounters-v19.ts';
import {validateCampaignProfile,type CampaignProfile} from './campaign-profile-v19.ts';
import {campaignEncounters,getCampaignEncounter} from './campaign-encounters-v19.ts';
import {createSimGame,restoreSimState,type SimState} from './tactics-v19.ts';
import type {SimState as PresentedState} from './tactics-v16.ts';
export function createCampaignGame(profile:CampaignProfile,id:string):SimState{
 const current=validateCampaignProfile(profile);if(!campaignEncounters(current).find(encounter=>encounter.id===id)?.available)throw new Error('Finish the next encounter before travelling farther.');
 return createSimGame({profile:current,encounterId:id});
}
export const restoreCampaignGame=restoreSimState;
export function awardCampaignVictory(profile:CampaignProfile,id:string,input:unknown):CampaignProfile{
 const current=validateCampaignProfile(profile);if(current.defeated.includes(id)||!campaignEncounters(current).find(encounter=>encounter.id===id)?.available)return current;
 let state:SimState;try{state=restoreSimState(input);}catch{return current;}
 if(state.winner!==0||state.campaign.encounterId!==id||state.mapId!==getCampaignEncounter(id).mapId)return current;
 if(JSON.stringify(state.campaign.profile.defeated)!==JSON.stringify(current.defeated))return current;
 return validateCampaignProfile({...current,defeated:[...current.defeated,id]});
}
/** Render adapter only. Campaign state never enters a v16 resolver or save slot. */
export function presentCampaign(state:SimState):PresentedState{
 return {...state,rulesVersion:16,scores:[0,0],learnedSignatures:[state.learnedSignatures[0],state.learnedSignatures[1]],winner:state.winner===null||state.winner==='draw'?state.winner:state.winner===0?0:1,units:state.units.map(unit=>({...unit,owner:unit.owner===0?0:1})),lastResolution:state.lastResolution.map(event=>({...event,owner:event.owner===undefined?undefined:event.owner===0?0:1}))};
}
