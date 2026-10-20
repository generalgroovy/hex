import {readCampaignStorage,writeCampaignStorage,type CampaignStorage} from './campaign-storage-v20.ts';
import type {TowerRoomSnapshot} from './tower-rooms-v22.ts';

export const TOWER_PENDING_ENTRY_KEY='hex-tower-coop-pending-v22';

/** Only an unacknowledged request keeps its key: explicit later creates get a new seat. */
export function prepareTowerEntry(fingerprint:string,newToken:()=>string,local:CampaignStorage,session:CampaignStorage):string{
 let token:string|undefined;
 try{const saved=JSON.parse(readCampaignStorage(TOWER_PENDING_ENTRY_KEY,local,session)??'null');if(saved?.fingerprint===fingerprint&&typeof saved.token==='string'&&/^[a-f0-9]{64}$/.test(saved.token))token=saved.token;}catch{}
 token??=newToken();writeCampaignStorage(TOWER_PENDING_ENTRY_KEY,JSON.stringify({fingerprint,token}),local,session);return token;
}
export function acknowledgeTowerEntry(local:CampaignStorage,session:CampaignStorage):void{writeCampaignStorage(TOWER_PENDING_ENTRY_KEY,'null',local,session);}

/** A partner's own build save advances the server step without ending your editing context. */
export function preservesTowerEditor(previous:TowerRoomSnapshot|null,next:TowerRoomSnapshot):boolean{
 return !!previous&&previous.code===next.code&&previous.runId===next.runId&&previous.session?.run.phase==='route'&&next.session?.run.phase==='route'&&previous.session.run.floor===next.session.run.floor;
}
