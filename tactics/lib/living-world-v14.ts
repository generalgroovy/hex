/** Deterministic presentation only. Decoration never changes simulation geometry. */
import type {Point,Element} from './game.ts';
import type {Biome} from './arena-v7.ts';
import {previewField,type SimCell} from './tactics-v14.ts';
import type {InhabitantIntent} from './inhabitants-v14.ts';

export type WorldCell=Point&{height:number;biome:Biome;well:boolean};
export const WORLD_PROP_ATLAS='/pixel/environment/wellspring-props.png';
export const WORLD_SURFACE_ATLAS='/pixel/environment/wellspring-surfaces.png';
export const WORLD_SURFACES:Record<Biome,number>={plain:4,earth:6,water:8,forest:5,marsh:9,ruins:2};
const vertices=[[0,-30],[44,-15],[44,15],[0,30],[-44,15],[-44,-15]] as const;
const neighbours=[{q:1,r:-1},{q:1,r:0},{q:0,r:1},{q:-1,r:1},{q:-1,r:0},{q:0,r:-1}];
export type CliffFace={edge:number;path:string;depth:number};
/** Only the three camera-facing edges can expose a vertical face. */
export function exposedCliffs(cell:WorldCell,cells:readonly WorldCell[]):CliffFace[]{
  return [1,2,3].flatMap(edge=>{
    const delta=neighbours[edge],neighbour=cells.find(other=>other.q===cell.q+delta.q&&other.r===cell.r+delta.r);
    const depth=neighbour?Math.max(0,cell.height-neighbour.height)*24:cell.height*24+9;
    if(!depth)return [];
    const [ax,ay]=vertices[edge],[bx,by]=vertices[(edge+1)%6];
    return [{edge,depth,path:`M${ax} ${ay}L${bx} ${by}V${by+depth}L${ax} ${ay+depth}Z`}];
  });
}
export type WorldProp={cell:WorldCell;frame:number;x:number;y:number;size:number;canopy:boolean;motion:'leaf'|'water'|'none'};
/** Trees indicate cover, walls indicate solid ruins; open ground gets only low flowers. */
export function worldProps(cells:readonly WorldCell[]):WorldProp[]{
  return cells.flatMap(cell=>{
    if(cell.well)return [];
    const seed=Math.abs(Math.imul(cell.q+19,73856093)^Math.imul(cell.r+19,19349663));
    const frame=cell.biome==='forest'?seed%2:cell.biome==='ruins'?4+(seed%2):cell.biome==='marsh'?3:cell.biome==='earth'?6:cell.biome==='plain'&&seed%11===0?2:-1;
    if(frame<0)return [];
    return [{cell,frame,x:cell.biome==='forest'?(seed%3-1)*14:cell.biome==='plain'?32:0,y:cell.biome==='forest'?-5:cell.biome==='plain'?12:2,size:cell.biome==='forest'?142:cell.biome==='ruins'?118:cell.biome==='plain'?43:cell.biome==='marsh'?64:57,canopy:cell.biome==='forest',motion:cell.biome==='forest'||cell.biome==='marsh'||cell.biome==='plain'?'leaf' as const:'none' as const}];
  });
}
export type VisibleCast={element:Element;area:readonly Point[];freeze?:boolean};
/** Public creature intentions and known spells share the resolver's exact chemistry.
 * A hidden enemy order can still change the outcome; this is a planning forecast. */
export function visibleFieldForecast(cell:SimCell,casts:readonly VisibleCast[],intents:readonly InhabitantIntent[]):SimCell {
  const at=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
  const arrivals=casts.filter(cast=>cast.area.some(point=>at(point,cell)));
  const pulses=intents.filter(intent=>intent.phase==='pulse'&&intent.area.some(point=>at(point,cell))&&!casts.some(cast=>cast.element===intent.counterElement&&cast.area.some(point=>at(point,intent.anchor))));
  return previewField(cell,[...arrivals.map(cast=>cast.element),...pulses.flatMap(intent=>intent.elements)],arrivals.some(cast=>cast.freeze));
}
