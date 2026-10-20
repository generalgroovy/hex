import {RoomError} from './rooms.ts';
export function checkTowerOrigin(request:Request):void{
 const origin=request.headers.get('origin');if(origin&&origin!==new URL(request.url).origin)throw new RoomError(403,'ORIGIN_REJECTED','Open the game directly to play.');
 const protocol=request.headers.get('X-Confluence-Protocol');if(protocol!==null&&protocol!=='22')throw new RoomError(426,'CLIENT_UPGRADE_REQUIRED','Reload to use the current tower rules. Your room key stays in this browser.');
}
export async function towerRequestBody(request:Request):Promise<unknown>{
 if(!request.headers.get('content-type')?.toLowerCase().includes('application/json'))throw new RoomError(415,'JSON_REQUIRED','Send this request as JSON.');
 if(Number(request.headers.get('content-length'))>16384)throw new RoomError(413,'BODY_TOO_LARGE','The request is too large.');
 const reader=request.body?.getReader();if(!reader)throw new RoomError(400,'INVALID_JSON','Send a JSON request.');
 let bytes=0,text='';const decoder=new TextDecoder();
 try{for(;;){const {done,value}=await reader.read();if(done)break;bytes+=value.byteLength;if(bytes>16384){await reader.cancel();throw new RoomError(413,'BODY_TOO_LARGE','The request is too large.');}text+=decoder.decode(value,{stream:true});}return JSON.parse(text+decoder.decode());}
 catch(error){if(error instanceof RoomError)throw error;throw new RoomError(400,'INVALID_JSON','Send valid JSON.');}finally{reader.releaseLock();}
}
