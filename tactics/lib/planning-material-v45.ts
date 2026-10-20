import {surfacePoint} from './battlefield-geometry.ts';
import {fieldCombination,isIce,type SimCell} from './tactics-v16.ts';
export const PLANNING_MATERIAL_BUDGET=18;
/** Animate a bounded, deterministic spread of on-screen fields. Off-screen
 * fields retain their static art; scenery is never part of this budget. */
export function planningMaterialCells(cells:readonly SimCell[],view:{x:number;y:number;width:number;height:number},budget=PLANNING_MATERIAL_BUDGET):Set<string>{
 const groups=new Map<string,SimCell[]>();
 for(const cell of cells){
  if(cell.ttl===undefined||cell.ttl<=0)continue;
  const point=surfacePoint(cell,cell.height??0);
  if(Math.abs(point.x-view.x)>view.width/2+88||Math.abs(point.y-view.y)>view.height/2+60)continue;
  const material=isIce(cell)?'ice':fieldCombination(cell)?.id??cell.terrain;
  groups.set(material,[...(groups.get(material)??[]),cell]);
 }
 const distance=(cell:SimCell)=>{const point=surfacePoint(cell,cell.height??0);return Math.hypot(point.x-view.x,point.y-view.y)};
 const queues=[...groups].sort(([a],[b])=>a.localeCompare(b)).map(([,group])=>group.sort((a,b)=>distance(a)-distance(b)||a.q-b.q||a.r-b.r));
 const result=new Set<string>(),limit=Math.max(0,Math.min(PLANNING_MATERIAL_BUDGET,Math.floor(budget)));
 for(let rank=0;result.size<limit;rank++){let added=false;for(const group of queues){const cell=group[rank];if(cell){result.add(`${cell.q},${cell.r}`);added=true;if(result.size===limit)break}}if(!added)break}
 return result;
}
