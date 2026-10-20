import {actSkirmish,getSkirmish} from '@/lib/skirmish-rooms-v17';
import {api,body,token,type RouteContext} from '../_shared';
export const dynamic='force-dynamic';
export async function GET(request:Request,context:RouteContext){return api(request,'read',async db=>getSkirmish(db,(await context.params).code,token(request)));}
export async function POST(request:Request,context:RouteContext){return api(request,'action',async db=>actSkirmish(db,(await context.params).code,token(request),await body(request)));}
