import type {Element} from './game.ts';
import {fieldCombination,isIce,type SimCell} from './tactics-v16.ts';
import {rangeBoundaryPath} from './range-outline-v16.ts';
import {ELEMENT_PALETTES,type ElementKind} from './element-presentation.ts';

export type FieldRegion={id:string;material:string;name:string;color:string;elements:Element[];cells:SimCell[];path:string};
const key=(cell:{q:number;r:number})=>`${cell.q},${cell.r}`;
const neighbours=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}] as const;
function material(cell:SimCell){return isIce(cell)?'ice':fieldCombination(cell)?.id??cell.terrain;}

/** Connected temporary fields receive one outside contour. Natural biomes keep
 * their own art; expired fields and internal hex seams never create FX borders. */
export function fieldRegions(cells:readonly SimCell[]):FieldRegion[]{
 const active=new Map(cells.filter(cell=>cell.ttl!==undefined&&cell.ttl>0).map(cell=>[key(cell),cell])),seen=new Set<string>(),regions:FieldRegion[]=[];
 for(const first of active.values()){
  if(seen.has(key(first)))continue;
  const kind=material(first),queue=[first],group:SimCell[]=[];seen.add(key(first));
  for(let index=0;index<queue.length;index++){
   const current=queue[index];group.push(current);
   for(const direction of neighbours){const id=key({q:current.q+direction.q,r:current.r+direction.r}),next=active.get(id);if(next&&!seen.has(id)&&material(next)===kind){seen.add(id);queue.push(next);}}
  }
  const combination=fieldCombination(first),element=combination?.elements[0]??(first.terrain in ELEMENT_PALETTES?first.terrain as Element:'light');
  regions.push({id:`${kind}:${key(first)}`,material:kind,name:kind==='ice'?'Ice':combination?.name??kind,color:kind==='ice'?'#a2e0e9':combination?.elements.length&&combination.elements.length>1?combination.color:ELEMENT_PALETTES[element].light,elements:[...(combination?.elements??[element])],cells:group,path:rangeBoundaryPath(group,point=>active.get(key(point))?.height??0)});
 }
 return regions;
}

export type WakeMark={x:number;y:number;size:number;shape:'spark'|'drop'|'chip'|'curl'|'star'|'hollow'};
const shapes:Record<ElementKind,WakeMark['shape']>={fire:'spark',lightning:'spark',water:'drop',ice:'chip',earth:'chip',metal:'chip',air:'curl',storm:'curl',light:'star',radiance:'star',dark:'hollow',void:'hollow'};
const snap=(value:number)=>Math.round(value/2)*2;
/** A bounded, directional wake stays behind the projectile, in the same two-unit
 * pixel grid as its cels. Its length is capped relative to the flight. */
export function projectileWake(from:{x:number;y:number},to:{x:number;y:number},kind:ElementKind):WakeMark[]{
 const dx=to.x-from.x,dy=to.y-from.y,length=Math.hypot(dx,dy);if(!length)return [];
 const ux=dx/length,uy=dy/length;
 return [18,32,46].filter(distance=>distance<length*.55).map((distance,index)=>({x:snap(-ux*distance),y:snap(-uy*distance),size:6-index*2,shape:shapes[kind]}));
}

/** Perceived size may increase when the board is zoomed out, but the route and
 * impact area never change. Integer factors keep the authored pixels crisp. */
export function projectileReadabilityScale(screenScale:number):1|2{return screenScale>=2?2:1;}
