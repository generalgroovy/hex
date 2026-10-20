import {createSkirmish,joinSkirmish} from '@/lib/skirmish-rooms-v18';
import {RoomError,takeRateLimit} from '@/lib/rooms';
import {api,body} from './_shared';
export const dynamic='force-dynamic';
export async function POST(request:Request){
 return api(request,'join',async db=>{const value=await body(request) as Record<string,unknown>|null;if(value?.action==='create'){await takeRateLimit(db,request.headers.get('cf-connecting-ip')??'local-preview','skirmish-create',12,3600000);return createSkirmish(db,value);}if(value?.action==='join'&&typeof value.code==='string')return joinSkirmish(db,value.code,value);throw new RoomError(400,'INVALID_ACTION','Create a match or join with a code.');},201);
}
