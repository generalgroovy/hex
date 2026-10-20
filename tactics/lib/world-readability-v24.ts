import {isCellSolid,isIce,fieldEffects,fieldCombination,type SimCell,type Point} from './tactics-v16.ts';
import {describeCombination} from './combinations-v16.ts';
import {groundPoint,type ScreenPoint} from './battlefield-geometry.ts';

export const WORLD_HEX_VERTICES:readonly (readonly [number,number])[]=[[0,-30],[44,-15],[44,15],[0,30],[-44,15],[-44,-15]];
const directions:readonly Point[]=[{q:1,r:-1},{q:1,r:0},{q:0,r:1},{q:-1,r:1},{q:-1,r:0},{q:0,r:-1}];
const key=({q,r}:Point)=>`${q},${r}`;
export type SolidFootprint={top:string;faces:{edge:number;path:string;seam:string}[];rim:string;lift:number};

/** A blocked hex occupies the entire ground polygon. Connected stones share
 * one top plane: there is no drawn alley where movement is actually forbidden. */
export function solidFootprints(cells:readonly SimCell[]):Map<string,SolidFootprint>{
 const indexed=new Map(cells.map(cell=>[key(cell),cell]));
 return new Map(cells.filter(isCellSolid).map(cell=>{
  const lift=24;
  const exposed=directions.flatMap((direction,edge)=>{
   const neighbour=indexed.get(key({q:cell.q+direction.q,r:cell.r+direction.r}));
   return neighbour&&isCellSolid(neighbour)&&neighbour.height===cell.height?[]:[edge];
  });
  const edgePath=(edge:number,offset:number)=>{const [ax,ay]=WORLD_HEX_VERTICES[edge],[bx,by]=WORLD_HEX_VERTICES[(edge+1)%6];return `M${ax} ${ay-offset}L${bx} ${by-offset}`;};
  return [key(cell),{
   lift,top:WORLD_HEX_VERTICES.map(([x,y])=>`${x},${y-lift}`).join(' '),
   rim:exposed.map(edge=>edgePath(edge,lift)).join(''),
   faces:exposed.filter(edge=>edge>=1&&edge<=3).map(edge=>{
    const [ax,ay]=WORLD_HEX_VERTICES[edge],[bx,by]=WORLD_HEX_VERTICES[(edge+1)%6];
    return {edge,path:`M${ax} ${ay-lift}L${bx} ${by-lift}V${by}L${ax} ${ay}Z`,seam:edgePath(edge,lift/2)};
   }),
  }];
 }));
}

/** Stable placement is authored in small pixel clusters, not random per frame. */
export function groundDetailSeed(point:Point):number{
 return Math.abs(Math.imul(point.q+29,73856093)^Math.imul(point.r+17,19349663));
}

export type GroundEdge={edge:number;path:string;kind:'rim'|'rise'|'woodland'};
/** Only material changes and exposed ledges get a rim. Ordinary neighbours
 * share a continuous floor; the tactical grid is drawn separately on demand. */
export function groundEdges(cells:readonly SimCell[]):Map<string,GroundEdge[]>{
 const indexed=new Map(cells.map(cell=>[key(cell),cell]));
 return new Map(cells.map(cell=>[key(cell),directions.flatMap((direction,edge)=>{
  const neighbour=indexed.get(key({q:cell.q+direction.q,r:cell.r+direction.r}));
  const kind=!neighbour?'rim':cell.height>neighbour.height?'rise':cell.biome==='forest'&&neighbour.biome!=='forest'?'woodland':null;
  if(!kind)return [];
  const [ax,ay]=WORLD_HEX_VERTICES[edge],[bx,by]=WORLD_HEX_VERTICES[(edge+1)%6];
  return [{edge,kind,path:`M${ax} ${ay}L${bx} ${by}`}];
 })]));
}

export type FringeTree=ScreenPoint&{id:string;frame:number;size:number};

/** Screen rectangles, not hex identity: a foreground flower or neighbouring
 * canopy can cover a fighter just as easily as scenery on the same tile. */
export function sceneryOpacity(prop:ScreenPoint&{size:number;canopy:boolean},subjects:readonly ScreenPoint[],compact:boolean):number{
 let opacity=1;
 for(const foot of subjects){
  const overlap=Math.abs(prop.x-foot.x)<prop.size*.46+54&&prop.y-prop.size*.92<foot.y+28&&prop.y+12>foot.y-128;
  if(!overlap)continue;
  const foreground=prop.y>=foot.y-24;
  opacity=Math.min(opacity,foreground?(prop.canopy?(compact?.12:.2):(compact?.06:.12)):(compact?.45:.65));
 }
 return opacity;
}

/** The distant treeline is outside the playable polygon and never participates
 * in collision, hit testing or spell forecasts. No decoration is added to cells. */
export function worldFringe(cells:readonly SimCell[]):FringeTree[]{
 if(!cells.length)return [];
 const indexed=new Set(cells.map(key)),outer=new Map<string,Point>();
 for(const cell of cells)for(const direction of directions){const point={q:cell.q+direction.q,r:cell.r+direction.r};if(!indexed.has(key(point)))outer.set(key(point),point);}
 const centre=cells.reduce((sum,cell)=>{const at=groundPoint(cell);return {x:sum.x+at.x/cells.length,y:sum.y+at.y/cells.length};},{x:0,y:0});
 return [...outer].filter(([,point])=>groundDetailSeed(point)%3!==0).map(([id,point])=>{
  const seed=groundDetailSeed(point),at=groundPoint(point),dx=at.x-centre.x,dy=at.y-centre.y,length=Math.hypot(dx,dy)||1;
  return {id,frame:seed%2,size:212+seed%4*18,x:at.x+dx/length*46,y:at.y+dy/length*46};
 }).sort((a,b)=>a.y-b.y||a.x-b.x);
}

/** Frozen pure water keeps its slide, but does not inherit liquid Flood/Wet
 * wording. Inspection uses resolved mechanics rather than ingredient slogans. */
export function terrainEffectDescription(cell:SimCell):string{
 if(!fieldCombination(cell))return '';
 const effects=fieldEffects(cell);
 return describeCombination(isIce(cell)?{...effects,movement:'ice'}:effects);
}
