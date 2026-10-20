import {fieldCombination,fieldEffects,isFlooded,isIce,type SimCell,type Point} from './tactics-v16.ts';

/** Presentation reads the final material, never guesses the effect from the
 * incoming ingredients. Fire + Water is sheltering steam, not burning water. */
export type TerrainMaterial='natural'|'scorched'|'frozen'|'flooded'|'mud'|'mist'|'blighted'|'radiant'|'current'|'fractured';
export const REACTIVE_PROP_ATLAS='/pixel/environment/reactive-props-v17.webp';
export const CRISP_SURFACE_ATLAS='/pixel/environment/wellspring-surfaces-pixel-v17.webp';
export const REACTIVE_PROP_STATES=['scorched','frozen','flooded','blighted'] as const;
export function terrainMaterial(cell:SimCell):TerrainMaterial {
  if(isIce(cell))return 'frozen';
  const field=fieldCombination(cell),effects=fieldEffects(cell);
  if(!field)return 'natural';
  if(isFlooded(cell))return 'flooded';
  if(effects.damageScale==='half')return 'mist';
  if((effects.hazard==='always'||effects.statuses?.some(status=>status.id==='burn'))&&field.elements.includes('fire'))return 'scorched';
  if(effects.statuses?.some(status=>status.id==='wither')||effects.flux===-1)return 'blighted';
  if(effects.heal||effects.cleanse||effects.statuses?.some(status=>status.id==='clarity'))return 'radiant';
  if(effects.movement==='current')return 'current';
  if(effects.movement==='rough'&&field.elements.includes('water'))return 'mud';
  if(effects.movement==='rough')return 'fractured';
  return 'natural';
}

/** Only matching silhouettes swap: a boulder must never become a solid wall. */
export function reactivePropFrame(cell:SimCell,originalFrame:number):number|null {
  const material=terrainMaterial(cell);
  const row=REACTIVE_PROP_STATES.indexOf((material==='mud'?'flooded':material) as typeof REACTIVE_PROP_STATES[number]);
  const column=originalFrame===0?0:originalFrame===1?1:originalFrame===3?2:originalFrame===4||originalFrame===5?3:-1;
  return row<0||column<0?null:row*4+column;
}

const directions:readonly Point[]=[{q:1,r:-1},{q:1,r:0},{q:0,r:1},{q:-1,r:1},{q:-1,r:0},{q:0,r:-1}];
const vertices:readonly (readonly [number,number])[]=[[0,-30],[44,-15],[44,15],[0,30],[-44,15],[-44,-15]];
const key=({q,r}:Point)=>`${q},${r}`;
export type TerrainEdge={edge:number;kind:'bank'|'ice';path:string};
const wet=(cell:SimCell)=>!isIce(cell)&&(cell.biome==='water'||cell.biome==='marsh'||isFlooded(cell));
/** Internal edges disappear inside connected water and ice. This makes actual
 * crossings legible at any map radius, without inventing collision boundaries. */
export function terrainEdges(cells:readonly SimCell[]):Map<string,TerrainEdge[]> {
  const byPosition=new Map(cells.map(cell=>[key(cell),cell]));
  return new Map(cells.map(cell=>[key(cell),directions.flatMap((direction,edge)=>{
    const neighbour=byPosition.get(key({q:cell.q+direction.q,r:cell.r+direction.r}));
    const kind=isIce(cell)&&(!neighbour||!isIce(neighbour))?'ice':wet(cell)&&neighbour&&!wet(neighbour)&&!isIce(neighbour)?'bank':null;
    if(!kind)return [];
    const [ax,ay]=vertices[edge],[bx,by]=vertices[(edge+1)%6];
    return [{edge,kind,path:`M${ax} ${ay}L${bx} ${by}`}];
  })]));
}

/** A transition only exists when authoritative field state changes. */
export function terrainTransition(before:SimCell|undefined,after:SimCell):TerrainMaterial|null {
  if(!before)return null;
  const from=terrainMaterial(before),to=terrainMaterial(after);
  return from===to?null:to;
}
