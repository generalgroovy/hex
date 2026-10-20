import {readCampaignStorage,writeCampaignStorage,type CampaignStorage} from './campaign-storage-v20.ts';
import type {TowerRoomSnapshot} from './tower-rooms-v23.ts';
export type TowerCredentials={code:string;token:string;seat:number};
export type TowerResponse={room:TowerRoomSnapshot;code?:string;token?:string;seat?:number};
export class TowerResponseError extends Error{readonly code:string;readonly status:number;constructor(message:string,code:string,status:number){super(message);this.code=code;this.status=status;}}
export const TOWER_PENDING_ENTRY_KEY='hex-tower-coop-pending-v23';
export function isCredentials(value:unknown):value is TowerCredentials{const input=value as TowerCredentials|null;return !!input&&typeof input.code==='string'&&/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/.test(input.code)&&typeof input.token==='string'&&/^[a-f0-9]{64}$/.test(input.token)&&Number.isInteger(input.seat)&&input.seat>=0&&input.seat<6;}
export function isSnapshot(value:unknown):value is TowerRoomSnapshot{const input=value as TowerRoomSnapshot|null;return !!input&&input.protocolVersion===23&&typeof input.code==='string'&&Number.isSafeInteger(input.version)&&typeof input.runId==='string'&&typeof input.stepId==='string'&&Array.isArray(input.players)&&input.players.length>=2&&input.players.length<=6&&Number.isInteger(input.yourSeat)&&input.yourSeat>=0&&input.yourSeat<input.players.length;}
async function response(reply:Response):Promise<TowerResponse>{let body:any;try{body=await reply.json()}catch{throw new TowerResponseError('The server response could not be read. Try again.','INVALID_RESPONSE',503);}if(!reply.ok)throw new TowerResponseError(body.error??'The climb could not be updated.',body.code??'SERVICE_UNAVAILABLE',reply.status);if(!isSnapshot(body.room))throw new TowerResponseError('Reload to use the current tower rules.','INVALID_RESPONSE',503);return body;}
export type TowerTransientRetry={attempt:1|2;delayMs:number;status?:number};
export type TowerTransportOptions={
 onRetry?:(retry:TowerTransientRetry)=>void;
 fetcher?:typeof fetch;
 wait?:(delayMs:number,signal?:AbortSignal)=>Promise<void>;
};
const retryDelays=[250,700] as const;
const transientStatuses=new Set([502,503,504]);
const aborted=(error:unknown,signal?:AbortSignal)=>Boolean(signal?.aborted||error&&typeof error==='object'&&'name' in error&&(error.name==='AbortError'||error.name==='TimeoutError'));
function retryIdentity(method:string,body:BodyInit|null|undefined):boolean {
 if(method==='GET')return body==null;
 if(method!=='POST'||typeof body!=='string')return false;
 try{
  const value=JSON.parse(body);
  if(!value||typeof value!=='object'||Array.isArray(value))return false;
  const entry=['create','join'].includes(value.action)&&typeof value.clientToken==='string'&&/^[a-f0-9]{64}$/.test(value.clientToken);
  const action=typeof value.action==='string'&&typeof value.requestId==='string'&&/^[a-zA-Z0-9_-]{8,80}$/.test(value.requestId)&&typeof value.runId==='string'&&value.runId.length>0&&typeof value.stepId==='string'&&value.stepId.length>0;
  return ['create','join'].includes(value.action)?entry:action;
 }catch{return false;}
}
function retryWait(delayMs:number,signal?:AbortSignal):Promise<void>{
 return new Promise((resolve,reject)=>{
  if(signal?.aborted){reject(signal.reason??new DOMException('Aborted','AbortError'));return;}
  const stop=()=>{clearTimeout(timer);signal?.removeEventListener('abort',stop);reject(signal?.reason??new DOMException('Aborted','AbortError'));};
  const timer=setTimeout(()=>{signal?.removeEventListener('abort',stop);resolve();},delayMs);
  signal?.addEventListener('abort',stop,{once:true});
 });
}
/** Retries preserve the exact serialized identity and payload. Only requests
 * the service can replay safely receive at most two extra attempts. */
export async function towerTransport(url:string|URL,init:RequestInit={},options:TowerTransportOptions={}):Promise<Response>{
 const target=String(url),request={...init,headers:new Headers(init.headers)},signal=init.signal??undefined,method=(init.method??'GET').toUpperCase();
 const safe=retryIdentity(method,request.body),fetcher=options.fetcher??fetch,wait=options.wait??retryWait;
 for(let attempt=0;;attempt++){
  if(signal?.aborted)throw signal.reason??new DOMException('Aborted','AbortError');
  let reply:Response;
  try{reply=await fetcher(target,request);}catch(error){
   if(!safe||attempt>=retryDelays.length||aborted(error,signal))throw error;
   options.onRetry?.({attempt:(attempt+1) as 1|2,delayMs:retryDelays[attempt]});
   await wait(retryDelays[attempt],signal);continue;
  }
  if(!safe||attempt>=retryDelays.length||!transientStatuses.has(reply.status))return reply;
  if(signal?.aborted)throw signal.reason??new DOMException('Aborted','AbortError');
  try{await reply.body?.cancel();}catch{/* A failed response body is discarded before the retry. */}
  options.onRetry?.({attempt:(attempt+1) as 1|2,delayMs:retryDelays[attempt],status:reply.status});
  await wait(retryDelays[attempt],signal);
 }
}
const endpoint=(code:string,watch?:number)=>`/api/tower-v23/${encodeURIComponent(code)}${watch===undefined?'':`?watch=${watch}`}`;
const headers=(token?:string)=>({'X-Confluence-Protocol':'23',...(token?{Authorization:`Bearer ${token}`}:{})});
export async function enterTowerRoom(body:Record<string,unknown>):Promise<TowerResponse>{return response(await towerTransport('/api/tower-v23',{method:'POST',headers:{...headers(),'Content-Type':'application/json'},body:JSON.stringify(body)}));}
export async function fetchTowerRoom(code:string,token:string,watch?:number,signal?:AbortSignal):Promise<TowerResponse>{return response(await towerTransport(endpoint(code,watch),{headers:headers(token),cache:'no-store',signal}));}
export async function requestTowerAction(code:string,token:string,body:Record<string,unknown>,watch?:number):Promise<TowerResponse>{return response(await towerTransport(endpoint(code,watch),{method:'POST',headers:{...headers(token),'Content-Type':'application/json'},body:JSON.stringify(body)}));}
export function prepareTowerEntry(fingerprint:string,newToken:()=>string,local:CampaignStorage,session:CampaignStorage):string{let token:string|undefined;try{const saved=JSON.parse(readCampaignStorage(TOWER_PENDING_ENTRY_KEY,local,session)??'null');if(saved?.fingerprint===fingerprint&&typeof saved.token==='string'&&/^[a-f0-9]{64}$/.test(saved.token))token=saved.token;}catch{}token??=newToken();writeCampaignStorage(TOWER_PENDING_ENTRY_KEY,JSON.stringify({fingerprint,token}),local,session);return token;}
export function acknowledgeTowerEntry(local:CampaignStorage,session:CampaignStorage):void{writeCampaignStorage(TOWER_PENDING_ENTRY_KEY,'null',local,session);}
export function preservesTowerEditor(previous:TowerRoomSnapshot|null,next:TowerRoomSnapshot):boolean{return !!previous&&previous.code===next.code&&previous.runId===next.runId&&previous.session?.run.phase==='route'&&next.session?.run.phase==='route'&&previous.session.run.floor===next.session.run.floor;}
