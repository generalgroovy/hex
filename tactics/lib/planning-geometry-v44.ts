import {distance,type Point} from './game.ts';
import type {Spell} from './spells-v20.ts';
const key=(point:Point)=>`${point.q},${point.r}`;
/** One immutable public snapshot, one short-lived reader. This caches geometry,
 * never plans or future state. Circular areas use the same board order as the
 * native resolver; directional shapes still delegate to its exact ray rules. */
export function planningGeometry<C extends Point,U extends Point&{id:string}>(
 cells:readonly C[],units:readonly U[],
 readSpell:(unit:U,id:string)=>Spell,
 readArea:(unitId:string,id:string,target:Point,from?:Point)=>C[],
 readAims:(unitId:string,id:string,from?:Point)=>C[],
){
 const byCell=new Map(cells.map((cell,index)=>[key(cell),{cell,index}])),byUnit=new Map(units.map(unit=>[unit.id,unit]));
 const spells=new Map<string,Spell>(),areas=new Map<string,C[]>(),aims=new Map<string,C[]>();
 const spell=(unit:U,id:string)=>{const cacheKey=`${unit.id}:${id}`;let result=spells.get(cacheKey);if(!result){result=readSpell(unit,id);spells.set(cacheKey,result);}return result;};
 return {
  spell,
  area(unitId:string,id:string,target:Point,from?:Point):C[]{
   const unit=byUnit.get(unitId);if(!unit)return [];
   const effect=spell(unit,id),circular=['hex','burst','ring'].includes(effect.shape),origin=from??unit;
   const radius=effect.shape==='hex'?0:effect.radius;
   const cacheKey=circular?`${effect.shape}:${radius}:${key(target)}`:`${unitId}:${id}:${key(origin)}:${key(target)}`;
   let result=areas.get(cacheKey);if(result)return result;
   if(circular){
    const found:{cell:C;index:number}[]=[];
    for(let q=-radius;q<=radius;q++)for(let r=Math.max(-radius,-q-radius);r<=Math.min(radius,-q+radius);r++){
     const at={q:target.q+q,r:target.r+r},entry=byCell.get(key(at));
     if(entry&&(effect.shape!=='ring'||distance(target,at)===radius))found.push(entry);
    }
    result=found.sort((a,b)=>a.index-b.index).map(entry=>entry.cell);
   }else result=readArea(unitId,id,target,from);
   areas.set(cacheKey,result);return result;
  },
  aims(unitId:string,id:string,from?:Point):C[]{
   const unit=byUnit.get(unitId);if(!unit)return [];
   const cacheKey=`${unitId}:${id}:${key(from??unit)}`;let result=aims.get(cacheKey);
   if(!result){result=readAims(unitId,id,from);aims.set(cacheKey,result);}return result;
  },
 };
}
