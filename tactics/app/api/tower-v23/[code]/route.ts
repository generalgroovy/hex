import {getTowerRoom,actTowerRoom} from '@/lib/tower-rooms-v23';
import {api,body,token,watchedSeat,type RouteContext} from '../_shared';
export const dynamic='force-dynamic';
export async function GET(request:Request,context:RouteContext){return api(request,'read',async db=>getTowerRoom(db,(await context.params).code,token(request),Date.now(),watchedSeat(request)));}
export async function POST(request:Request,context:RouteContext){return api(request,'action',async db=>actTowerRoom(db,(await context.params).code,token(request),await body(request),Date.now(),watchedSeat(request)));}
