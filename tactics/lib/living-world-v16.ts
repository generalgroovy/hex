/** Deterministic presentation only. Decoration never changes simulation geometry. */
import type {Point,Element} from './game.ts';
import type {Biome} from './arena-v7.ts';
import {previewField,type SimCell} from './tactics-v16.ts';
import type {InhabitantIntent} from './inhabitants-v16.ts';

export type WorldCell=Point&{height:number;biome:Biome;well:boolean};
export const WORLD_PROP_ATLAS='/pixel/environment/wellspring-props.png';
export const WORLD_SURFACE_ATLAS='/pixel/environment/wellspring-surfaces-crafted.webp';
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
    const frame=cell.biome==='forest'&&seed%3!==0?seed%2:cell.biome==='ruins'?4+(seed%2):cell.biome==='marsh'&&seed%3===0?3:cell.biome==='earth'&&seed%5===0?6:cell.biome==='plain'&&seed%19===0?2:-1;
    if(frame<0)return [];
    // Full trees sit behind the walking centre; low plants and loose stones sit
    // near the rim. Their artwork never masquerades as a blocking ruin.
    const side=seed%2?1:-1;
    return [{cell,frame,x:cell.biome==='forest'?side*34:cell.biome==='plain'?side*49:cell.biome==='marsh'?side*40:side*47,y:cell.biome==='forest'?-15:cell.biome==='plain'?17:-9,size:cell.biome==='forest'?178:cell.biome==='ruins'?118:cell.biome==='plain'?48:cell.biome==='marsh'?68:58,canopy:cell.biome==='forest',motion:'none' as const}];
  });
}
export type VisibleCast={element:Element;area:readonly Point[];freeze?:boolean;canCounter?:boolean};
/** Public creature intentions and known spells share the resolver's exact chemistry.
 * A hidden enemy order can still change the outcome; this is a planning forecast. */
export function visibleFieldForecast(cell:SimCell,casts:readonly VisibleCast[],intents:readonly InhabitantIntent[]):SimCell {
  const at=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
  const arrivals=casts.filter(cast=>cast.area.some(point=>at(point,cell)));
  const pulses=intents.filter(intent=>intent.phase==='pulse'&&intent.area.some(point=>at(point,cell))&&!casts.some(cast=>cast.canCounter!==false&&cast.element===intent.counterElement&&cast.area.some(point=>at(point,intent.anchor))));
  return previewField(cell,[...arrivals.map(cast=>cast.element),...pulses.flatMap(intent=>intent.elements)],arrivals.some(cast=>cast.freeze));
}
