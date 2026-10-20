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
