import {redirect} from 'next/navigation';
import HexHome from './components/HexHomeV41';

/** Existing invitation and seeded-map links keep their original rules. */
export default async function Home({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}) {
 const query=await searchParams;
 if(query.room!==undefined||query.seed!==undefined){
  const legacy=new URLSearchParams();
  for(const key of ['room','seed']){const value=query[key];if(typeof value==='string')legacy.set(key,value);}
  redirect(`/v16?${legacy.toString()}`);
 }
 return <HexHome/>;
}
