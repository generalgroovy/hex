import TowerGame from '../components/TowerGameV23';
import CoopTower from '../components/CoopTowerV23';
export const metadata={title:'Tower · H.E.X.',description:'Choose two characters and climb nine seeded floors, solo or in a group of up to six.'};
export default async function TowerPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const query=await searchParams;
 return query.play==='friends'||typeof query.code==='string'?<CoopTower/>:<TowerGame/>;
}
