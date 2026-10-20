import {redirect} from 'next/navigation';
/** Keep previously shared invitations usable after merging the Tower entry. */
export default async function CoopTowerPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const query=await searchParams,params=new URLSearchParams({play:'friends'});
 if(typeof query.code==='string')params.set('code',query.code);
 redirect(`/tower?${params.toString()}`);
}
