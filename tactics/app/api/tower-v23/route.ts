import {createTowerRoom,joinTowerRoom} from '@/lib/tower-rooms-v23';
import {RoomError,takeRateLimit} from '@/lib/rooms';
import {api,body} from './_shared';
export const dynamic='force-dynamic';
export async function POST(request:Request){return api(request,'join',async db=>{const value=await body(request) as Record<string,unknown>|null;if(value?.action==='create'){await takeRateLimit(db,request.headers.get('cf-connecting-ip')??'local-preview','tower23-create',12,3600000);return createTowerRoom(db,value);}if(value?.action==='join'&&typeof value.code==='string')return joinTowerRoom(db,value.code,value);throw new RoomError(400,'INVALID_ACTION','Create a climb or join with its code.');},201);}
