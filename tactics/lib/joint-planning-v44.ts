import {distance,type Point} from './game.ts';
const key=(point:Point)=>`${point.q},${point.r}`;
export type ScoredLanding<T extends Point>={cell:T;score:number;support:number};
/** Fixed candidate budget; no sealed enemy orders or random search. Include a
 * support angle and holding ground rather than four nearly identical steps. */
export function jointLandings<T extends Point>(candidates:readonly ScoredLanding<T>[],baseline:Point,current:Point,blocked:ReadonlySet<string>,unitCount:number):ScoredLanding<T>[]{
 const legal=candidates.filter(candidate=>!blocked.has(key(candidate.cell)));
 const best=legal.find(candidate=>key(candidate.cell)===key(baseline));
 if(!best)return [];
 const limit=unitCount<=6?3:2,result=[best],seen=new Set([key(best.cell)]);
 const add=(candidate:ScoredLanding<T>|undefined)=>{if(candidate&&!seen.has(key(candidate.cell))&&result.length<limit){result.push(candidate);seen.add(key(candidate.cell));}};
 const ranked=[...legal].sort((a,b)=>b.score-a.score||a.cell.q-b.cell.q||a.cell.r-b.cell.r);
 const support=[...legal].sort((a,b)=>(b.score*.25+b.support)-(a.score*.25+a.support)||a.cell.q-b.cell.q||a.cell.r-b.cell.r);
 // Small parties can afford a hold comparison as well as a rescue angle.
 if(limit>2)add(legal.find(candidate=>key(candidate.cell)===key(current)));
 add(support.find(candidate=>candidate.support>0&&!seen.has(key(candidate.cell))));
 for(const candidate of ranked)add(candidate);
 return result;
}
type RouteCell=Point&{barrier?:number;biome:string;well:boolean};
const directions:Point[]=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
/** Value an actual change to shortest walkable approach, not decorative walls.
 * Uses public positions and static terrain; occupied/well cells cannot close. */
export function barrierRouteValue(cells:readonly RouteCell[],area:readonly Point[],allies:readonly (Point&{hp:number;maxHp:number})[],enemies:readonly Point[]):number{
 const occupied=new Set([...allies,...enemies].map(key)),byKey=new Map(cells.map(cell=>[key(cell),cell]));
 const added=new Set(area.filter(point=>{const cell=byKey.get(key(point));return cell&&!cell.well&&!cell.barrier&&cell.biome!=='ruins'&&!occupied.has(key(point));}).map(key));
 if(!added.size)return 0;
 const routes=(extra:ReadonlySet<string>)=>{
  const result=new Map<string,number>(),queue:Point[]=[];
  for(const ally of allies){result.set(key(ally),0);queue.push(ally);}
  for(let index=0;index<queue.length;index++){
   const point=queue[index],cost=result.get(key(point))!;
   for(const direction of directions){
    const next={q:point.q+direction.q,r:point.r+direction.r},id=key(next),cell=byKey.get(id);
    if(!cell||cell.biome==='ruins'||cell.barrier||extra.has(id)||result.has(id))continue;
    result.set(id,cost+1);queue.push(next);
   }
  }
  return result;
 };
 const before=routes(new Set()),after=routes(added);
 let value=0;
 for(const enemy of enemies){
  const initial=before.get(key(enemy));if(initial===undefined||initial>7)continue;
  const change=Math.min(3,(after.get(key(enemy))??initial+3)-initial);
  const threatened=allies.filter(ally=>distance(ally,enemy)<=7),urgency=threatened.some(ally=>ally.hp<ally.maxHp/2)?1.5:1;
  value+=Math.max(0,change)*urgency;
 }
 return Math.min(6,value)*1.5;
}
