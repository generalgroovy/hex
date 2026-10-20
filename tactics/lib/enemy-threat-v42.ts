import type {Point} from './game.ts';

export type EnemyThreatPreview = {
  fighterId:string;
  /** Legal landings, including the current hex. */
  move:Point[];
  /** All affected hexes of ready spells from any legal landing. */
  attack:Point[];
  /** Same spell envelope without moving. */
  cast:Point[];
  readySpells:number;
};
type Fighter = Point & {id:string;hp:number;respawn?:number};
type PublicBattle = {units:Fighter[];cells:Point[];winner:unknown};
export type ThreatRules<State extends PublicBattle> = {
  legalMoves:(state:State,id:string)=>Point[];
  legalCasts:(state:State,id:string,from?:Point,spellId?:string)=>Point[];
  spellArea:(state:State,id:string,spellId:string,target:Point,from?:Point)=>Point[];
  availableUnitSpellIds:(state:State,id:string)=>string[];
  castAvailability:(state:State,id:string,spellId:string)=>{available:boolean};
  spellGeometry?:(state:State,id:string,spellId:string)=>{shape:string;range:number;radius:number};
};
const key=({q,r}:Point)=>`${q},${r}`;
const point=({q,r}:Point):Point=>({q,r});

/**
 * Public possibilities, never a predicted enemy order. Includes AoE beyond the
 * aim radius, terrain/height sight, ice destinations, control, Flux and recovery.
 * Own and rival submitted plans are deliberately absent from this API.
 */
export function enemyThreatPreview<State extends PublicBattle>(state:State,id:string,rules:ThreatRules<State>):EnemyThreatPreview|null {
  const unit=state.units.find(unit=>unit.id===id);
  if(!unit||unit.hp<=0||unit.respawn!==undefined||state.winner!==null)return null;
  const origins=new Map([[key(unit),point(unit)],...rules.legalMoves(state,id).map(cell=>[key(cell),point(cell)] as const)]);
  const ids=rules.availableUnitSpellIds(state,id).filter(spell=>rules.castAvailability(state,id,spell).available);
  const attack=new Map<string,Point>(),cast=new Map<string,Point>();
  // A spell's strength/statuses do not alter its legal geometry. Reuse exactly
  // equal aim/footprint rules instead of repeating expensive sight searches.
  const profiles=ids.map(id=>({id,geometry:rules.spellGeometry?.(state,unit.id,id)}));
  const areaCache=new Map<string,Point[]>();
  const includedAreas=new Set<string>();
  for(const origin of origins.values()){
    const standing=key(origin)===key(unit);
    if(!standing&&attack.size===state.cells.length)break;
    const aimCache=new Map<string,Point[]>(),seenGeometry=new Set<string>();
    for(const {id:spell,geometry} of profiles){
      const geometryKey=geometry?`${geometry.shape}:${geometry.range}:${geometry.radius}`:spell;
      if(seenGeometry.has(geometryKey))continue;
      seenGeometry.add(geometryKey);
      const aimKind=geometry?.shape==='line'?'line':geometry?.shape==='wall'||geometry?.shape==='sweep'?'axis':'free';
      const aimKey=geometry?`${geometry.range}:${aimKind}`:spell;
      if(!aimCache.has(aimKey))aimCache.set(aimKey,rules.legalCasts(state,id,origin,spell));
      for(const target of aimCache.get(aimKey)!){
        const independent=geometry&&['hex','burst','ring'].includes(geometry.shape);
        const areaKey=`${geometryKey}:${independent?'any':key(origin)}:${key(target)}`;
        if(!standing&&includedAreas.has(areaKey))continue;
        if(!areaCache.has(areaKey))areaCache.set(areaKey,rules.spellArea(state,id,spell,target,origin));
        for(const cell of areaCache.get(areaKey)!){
          const address=key(cell);
          attack.set(address,point(cell));
          if(standing)cast.set(address,point(cell));
        }
        includedAreas.add(areaKey);
      }
    }
  }
  // Board order keeps SVG output stable across spell and loadout ordering.
  const ordered=(cells:Map<string,Point>)=>state.cells.filter(cell=>cells.has(key(cell))).map(point);
  return {fighterId:id,move:ordered(origins),attack:ordered(attack),cast:ordered(cast),readySpells:ids.length};
}

/** One immutable battle snapshot per factory; repeated hover is free. */
export function enemyThreatReader<State extends PublicBattle>(state:State,rules:ThreatRules<State>):(id:string)=>EnemyThreatPreview|null {
  const cache=new Map<string,EnemyThreatPreview|null>();
  return id=>{
    if(!cache.has(id))cache.set(id,enemyThreatPreview(state,id,rules));
    return cache.get(id)!;
  };
}
