import {env} from 'cloudflare:workers';
import {RoomError,takeRateLimit,type RoomDatabase} from '@/lib/rooms';
import {checkTowerOrigin,towerRequestBody} from '@/lib/tower-http-v23';
export {token} from '../rooms/_shared';
export {watchedSeat} from '@/lib/tower-http-v23';
export const body=towerRequestBody;
export type RouteContext={params:Promise<{code:string}>};
const headers={'Cache-Control':'no-store, private','X-Content-Type-Options':'nosniff','X-Confluence-Protocol':'23'};
export async function api(request:Request,scope:'join'|'read'|'action',operation:(db:RoomDatabase)=>Promise<unknown>,status=200){try{checkTowerOrigin(request);const db=(env as Cloudflare.Env).DB;if(!db)throw new RoomError(503,'SERVICE_UNAVAILABLE','Co-op is temporarily unavailable. Your run remains saved.');const quota={join:[60,600000],read:[600,60000],action:[240,60000]}[scope];await takeRateLimit(db,request.headers.get('cf-connecting-ip')??'local-preview',`tower23-${scope}`,quota[0],quota[1]);return Response.json(await operation(db),{status,headers});}catch(error){if(error instanceof RoomError)return Response.json({error:error.message,code:error.code},{status:error.status,headers:{...headers,...(error.status===429?{'Retry-After':'60'}:{})}});console.error('Squad tower request failed',{scope});return Response.json({error:'Co-op is temporarily unavailable. Try again shortly.',code:'SERVICE_UNAVAILABLE'},{status:503,headers});}}
