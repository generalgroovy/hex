import {validateCampaignProfile,type CampaignProfile} from './campaign-profile-v20.ts';
import {restoreSimState,validatePlan,type SimState,type TeamPlan} from './tactics-v20.ts';
import {applyCampaignProgress} from './story-v20.ts';

export const CAMPAIGN_SESSION_KEY='hex-confluence-campaign-session-v20';
export type CampaignSession={format:1;profile:CampaignProfile;match:{state:SimState;plan:TeamPlan;previous?:SimState}|null};
const plain=(value:unknown):value is Record<string,unknown>=>!!value&&typeof value==='object'&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value));
function restoredDraft(state:SimState,input:unknown):TeamPlan{
 if(state.winner!==null)return {orders:[]};
 try{
  const validated=validatePlan(state,0,input),supplied=plain(input)&&Array.isArray(input.orders)?new Set(input.orders.filter(plain).map(order=>order.unitId)):new Set();
  return {orders:validated.orders.filter(order=>supplied.has(order.unitId))};
 }catch{return {orders:[]}}
}
function restoredPrevious(state:SimState,input:unknown):SimState|undefined{
 if(input===undefined)return undefined;
 try{
  const previous=restoreSimState(input);
  if(previous.winner!==null||previous.version+1!==state.version||previous.mapId!==state.mapId||JSON.stringify(previous.campaign)!==JSON.stringify(state.campaign))return undefined;
  return previous;
 }catch{return undefined}
}
/** One atomic value contains both earned knowledge and the battle which proves it. */
export function createCampaignSession(profile:CampaignProfile,state:SimState|null,plan:TeamPlan={orders:[]},previous?:SimState):CampaignSession{
 const current=validateCampaignProfile(profile);if(state===null)return {format:1,profile:current,match:null};
 const battle=restoreSimState(state),progress=applyCampaignProgress(current,battle),prior=restoredPrevious(battle,previous);
 return {format:1,profile:progress.profile,match:{state:battle,plan:restoredDraft(battle,plan),...(prior?{previous:prior}:{})}};
}
export function restoreCampaignSession(input:unknown):CampaignSession{
 let value=input;if(typeof value==='string'){if(value.length>8000000)throw new Error('Campaign backup is too large.');try{value=JSON.parse(value)}catch{throw new Error('Campaign backup is not valid JSON.')}}
 if(!plain(value)||value.format!==1||Object.keys(value).some(key=>!['format','profile','match'].includes(key)))throw new Error('Unsupported campaign backup.');
 const profile=validateCampaignProfile(value.profile);if(value.match===null)return createCampaignSession(profile,null);
 if(!plain(value.match)||Object.keys(value.match).some(key=>!['state','plan','previous'].includes(key)))throw new Error('Campaign battle record is invalid.');
 const state=restoreSimState(value.match.state),previous=restoredPrevious(state,value.match.previous);
 return createCampaignSession(profile,state,restoredDraft(state,value.match.plan),previous);
}

export type CampaignStorage=Pick<Storage,'getItem'|'setItem'|'removeItem'>;
/** A session copy exists only after a failed local write, so it is the newer value. */
export function readCampaignStorage(key:string,local:CampaignStorage,session:CampaignStorage):string|null{
 try{const fallback=session.getItem(key);if(fallback!==null)return fallback}catch{}
 try{return local.getItem(key)}catch{return null}
}
export function writeCampaignStorage(key:string,value:string,local:CampaignStorage,session:CampaignStorage):boolean{
 try{local.setItem(key,value);try{session.removeItem(key)}catch{}return true}catch{}
 try{session.setItem(key,value);return true}catch{return false}
}
