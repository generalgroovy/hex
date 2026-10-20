import {isIce,isFlooded,type Point,type SimCell,type SimState} from './tactics-v13.ts';
import {battlefieldMotion} from './battlefield-motion-v13.ts';
import {characterMotion} from './character-motion.ts';

export type ContactMaterial='water'|'ice'|'leaf'|'stone'|'dust';
export type GroundContact={id:string;unitId:string;point:Point;atMs:number;material:ContactMaterial;weight:number;kind:'move'|'push'};

/** A contact belongs to the actual terrain, never to the spell someone intended. */
export function contactMaterial(cell:SimCell):ContactMaterial {
  if(isIce(cell))return 'ice';
  if(isFlooded(cell)||cell.biome==='water'||cell.biome==='marsh')return 'water';
  if(cell.biome==='forest')return 'leaf';
  if(cell.biome==='ruins')return 'stone';
  return 'dust';
}

/** Brief landing accents use the same route and clock as the moving figure.
 * Missing snapshots, blocked orders and stationary casts never invent a step. */
export function groundContacts(previous:SimState|undefined,next:SimState):GroundContact[] {
  if(!previous||previous.version+1!==next.version||previous.mapId!==next.mapId)return [];
  return next.units.flatMap(unit=>{
    const motion=battlefieldMotion(previous,next,unit.id,'contacts');
    if(!motion)return [];
    const mass=characterMotion(unit.championId).mass,weight=mass==='heavy'?1.15:mass==='light'?.75:1;
    return (['move','push'] as const).flatMap(kind=>{
      const path=kind==='move'?motion.movePath:motion.pushPath;
      if(!path.length)return [];
      const frame=motion.frames.filter(frame=>frame.phase===kind).at(-1);
      if(!frame)return [];
      const cell=(kind==='move'?previous.cells:next.cells).find(cell=>cell.q===frame.point.q&&cell.r===frame.point.r);
      if(!cell)return [];
      return [{id:`${unit.id}-${kind}`,unitId:unit.id,point:{...frame.point},atMs:frame.atMs,material:contactMaterial(cell),weight,kind}];
    });
  });
}
