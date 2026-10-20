import {env} from 'cloudflare:workers';
import {RoomError,takeRateLimit,type RoomDatabase} from '@/lib/rooms';
export {token} from '../rooms/_shared';
export type RouteContext={params:Promise<{code:string}>};
const headers={'Cache-Control':'no-store, private','X-Content-Type-Options':'nosniff','X-Confluence-Protocol':'18'};
export async function body(request:Request):Promise<unknown>{
 if(!request.headers.get('content-type')?.toLowerCase().includes('application/json'))throw new RoomError(415,'JSON_REQUIRED','Send this request as JSON.');
 const reader=request.body?.getReader();if(!reader)throw new RoomError(400,'INVALID_JSON','Send a JSON request.');
 const decoder=new TextDecoder();let text='',size=0;
 try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>16_384){await reader.cancel();throw new RoomError(413,'BODY_TOO_LARGE','The request is too large.');}text+=decoder.decode(value,{stream:true});}return JSON.parse(text+decoder.decode());}
 catch(e){if(e instanceof RoomError)throw e;throw new RoomError(400,'INVALID_JSON','Send valid JSON.');}finally{reader.releaseLock()}
}
export async function api(request:Request,scope:'create'|'join'|'read'|'action',operation:(db:RoomDatabase)=>Promise<unknown>,status=200){
 try{
  const origin=request.headers.get('origin');if(origin&&origin!==new URL(request.url).origin)throw new RoomError(403,'ORIGIN_REJECTED','Open the game directly to play.');
  const db=(env as Cloudflare.Env).DB;if(!db)throw new RoomError(503,'SERVICE_UNAVAILABLE','Online matches are temporarily unavailable.');
  const quota={create:[12,3600000],join:[60,600000],read:[400,60000],action:[180,60000]}[scope];
  await takeRateLimit(db,request.headers.get('cf-connecting-ip')??'local-preview',`skirmish-${scope}`,quota[0],quota[1]);
  return Response.json(await operation(db),{status,headers});
 }catch(e){if(e instanceof RoomError)return Response.json({error:e.message,code:e.code},{status:e.status,headers:{...headers,...(e.status===429?{'Retry-After':'60'}:{})}});console.error('Skirmish request failed',{scope});return Response.json({error:'Online matches are temporarily unavailable. Try again shortly.',code:'SERVICE_UNAVAILABLE'},{status:503,headers});}
}
