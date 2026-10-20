/** Public movement advice. Rival orders never enter this projection. */
import {isAlive,isCellSolid,movementBudget,movementEffort,movementPath,isIce,type Player,type Point,type SimState,type TeamPlan} from './tactics-v15.ts';
import {getChampion} from './roster-v13.ts';
import {formatTile} from './board-labels-v9.ts';

export type MovementRisk={blocked:boolean;reason?:string;contested:boolean;contestedReason?:string};
export type ProjectedMovement=MovementRisk&{unitId:string;from:Point;target:Point;actualPosition:Point;hasMove:boolean};
export type MovementPreview=ProjectedMovement&{landing:Point;route:Point[];effort:number|null;budget:number;slide:boolean};
const key=({q,r}:Point)=>`${q},${r}`;
const same=(a:Point,b:Point)=>key(a)===key(b);
const at=({q,r}:Point):Point=>({q,r});

/** Resolves only known allied destination conflicts. Valid movement routes are
 * supplied by the caller/plan validator; passing through a unit is permitted.
 * Cycles and swaps remain simultaneous. Contested means uncertain, not forbidden.
 */
export function projectAlliedMovement(state:SimState,player:Player,plan:TeamPlan,assumeRivalsStay=false):Map<string,ProjectedMovement>{
  const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit));
  const rivals=state.units.filter(unit=>unit.owner!==player&&isAlive(unit));
  const cells=new Map(state.cells.map(cell=>[key(cell),cell]));
  const result=new Map<string,ProjectedMovement>();
  for(const unit of own){
    const move=plan.orders.find(order=>order.unitId===unit.id)?.move;
    const hasMove=!!move&&!same(move,unit),target=hasMove?at(move!):at(unit);
    result.set(unit.id,{unitId:unit.id,from:at(unit),target,actualPosition:at(unit),hasMove,blocked:false,contested:false});
  }
  const moving=[...result.values()].filter(entry=>entry.hasMove),active=new Set(moving.map(entry=>entry.unitId));
  const names=(ids:string[])=>ids.map(id=>getChampion(own.find(unit=>unit.id===id)!.championId).name).join(' and ');
  for(const entry of moving){
    const cell=cells.get(key(entry.target)),sharing=moving.filter(other=>other.unitId!==entry.unitId&&same(other.target,entry.target));
    if(!cell||isCellSolid(cell)){entry.blocked=true;entry.reason='That landing is blocked by terrain.';active.delete(entry.unitId);}
    else if(sharing.length){entry.blocked=true;entry.reason=`Landing shared with ${names(sharing.map(other=>other.unitId))}; these moves will bounce.`;active.delete(entry.unitId);}
    else if(assumeRivalsStay&&rivals.some(unit=>same(unit,entry.target))){entry.blocked=true;entry.reason='A rival stays on this landing; this move will bounce.';active.delete(entry.unitId);}
  }
  let changed=true;
  while(changed){changed=false;for(const entry of moving)if(active.has(entry.unitId)){
    const blocker=own.find(unit=>same(unit,entry.target));
    if(blocker&&!active.has(blocker.id)){entry.blocked=true;entry.reason=`${getChampion(blocker.championId).name} stays on ${formatTile(entry.target)}; this move will bounce.`;active.delete(entry.unitId);changed=true;}
  }}
  for(const entry of moving)if(active.has(entry.unitId)){
    entry.actualPosition=at(entry.target);
    const rival=rivals.find(unit=>same(unit,entry.target));
    if(rival){entry.contested=true;entry.contestedReason=`${getChampion(rival.championId).name} occupies ${formatTile(entry.target)}. This move bounces if they stay or cannot leave.`;}
  }
  // A follower is uncertain whenever the ally it follows has a contested landing.
  changed=true;
  while(changed){changed=false;for(const entry of moving)if(active.has(entry.unitId)&&!entry.contested){
    const blocker=own.find(unit=>same(unit,entry.target));
    if(blocker&&result.get(blocker.id)!.contested){entry.contested=true;entry.contestedReason=`Depends on ${getChampion(blocker.championId).name} leaving; their landing is contested.`;changed=true;}
  }}
  return result;
}

function withTarget(plan:TeamPlan,unitId:string,target:Point):TeamPlan{
  const existing=plan.orders.find(order=>order.unitId===unitId);
  return {orders:[...plan.orders.filter(order=>order.unitId!==unitId),{...existing,unitId,move:at(target)}]};
}

/** Cheap destination risk map: no pathfinding per hex. Pass already-legal targets. */
export function movementRisks(state:SimState,player:Player,plan:TeamPlan,unitId:string,targets:readonly Point[]):Map<string,MovementRisk>{
  const risks=new Map<string,MovementRisk>();
  if(!state.units.some(unit=>unit.id===unitId&&unit.owner===player&&isAlive(unit))||state.winner!==null)return risks;
  for(const target of targets){const entry=projectAlliedMovement(state,player,withTarget(plan,unitId,target)).get(unitId)!;risks.set(key(target),{blocked:entry.blocked,reason:entry.reason,contested:entry.contested,contestedReason:entry.contestedReason});}
  return risks;
}

/** Omitting target keeps the queued route visible; no queued move means Hold. */
export function movementPreview(state:SimState,player:Player,plan:TeamPlan,unitId:string|null,target?:Point):MovementPreview|null{
  const unit=state.units.find(entry=>entry.id===unitId&&entry.owner===player&&isAlive(entry));
  if(!unit||state.winner!==null)return null;
  const projected=projectAlliedMovement(state,player,target?withTarget(plan,unit.id,target):plan).get(unit.id)!;
  const route=projected.hasMove?movementPath(state,unit.id,projected.target):[];
  const effort=projected.hasMove?movementEffort(state,unit.id,projected.target):0;
  if(projected.hasMove&&!route){projected.blocked=true;projected.reason='That landing is beyond this character’s movement or has no open route.';projected.contested=false;delete projected.contestedReason;projected.actualPosition=at(unit);}
  return {...projected,landing:at(projected.actualPosition),route:(route??[]).map(at),effort,budget:movementBudget(unit,state),slide:!!route?.some(isIce)};
}
