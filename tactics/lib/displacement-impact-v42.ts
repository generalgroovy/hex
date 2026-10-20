import {forceOrigin} from './spell-profile-v42.ts';
/** Conditional force geometry for the known volley. Rivals stay at their public
 * positions and affected fighters survive the spell phase. This is not a hidden
 * order prediction or a whole-exchange damage forecast. */
import {displacementSteps,distance,fieldCombination,fieldEffects,getCell,isAlive,previewDisplacement,type Point,type SimCell,type SimState,type StatusId} from './tactics-v20.ts';
import {STATUS_DEFINITIONS,type Spell} from './spells-v20.ts';
import {getChampion} from './roster-v13.ts';

export type DisplacementOutcome={
 landing:Point;path:Point[];impact:boolean;blockedBy:string[];
 environmentalDamage:0|1;statuses:string[];cleansed:boolean;terrainName:string;
};
export type DisplacementImpact={anchored:boolean;withoutGuard:DisplacementOutcome;withGuard:DisplacementOutcome};
export type KnownForceCast={spell:Spell;origin:Point;target:Point;area:readonly Point[]};
export type ContactProtection={control:boolean;cleansed:boolean;wet:boolean};
const key=(point:Point)=>`${point.q},${point.r}`;
const at=({q,r}:Point):Point=>({q,r});
const same=(left:Point,right:Point)=>key(left)===key(right);
const controls:readonly StatusId[]=['rooted','chilled','concussed','blind'];
const ailments:readonly StatusId[]=['burn','wither',...controls];
const label=(id:StatusId)=>STATUS_DEFINITIONS.find(status=>status.id===id)!.name;

/** Uses the same centre and hex metric as spell force in both active resolvers. */
export function knownForceAt(victim:Point,casts:readonly KnownForceCast[]):Point {
 return casts.filter(cast=>cast.spell.push&&cast.area.some(cell=>same(cell,victim))).reduce((force,cast)=>{
  const centre=forceOrigin(cast.spell,cast.origin,cast.target);
  const length=distance(victim,centre)||1;
  return {q:force.q+(victim.q-centre.q)/length*cast.spell.push!,r:force.r+(victim.r-centre.r)/length*cast.spell.push!};
 },{q:0,r:0});
}

/** One stationary-rival branch, with all known forces resolved together.
 * Landing conflicts block; crossing a fighter during an Ice slide does not.
 * Swaps, cycles and a train of departing fighters remain simultaneous. */
export function knownDisplacementBranch(
 state:SimState,cells:readonly SimCell[],casts:readonly KnownForceCast[],guards:ReadonlySet<string>,
 protection:ReadonlyMap<string,ContactProtection>=new Map(),exchangeOrigins:ReadonlyMap<string,Point>=new Map(),
):Map<string,DisplacementOutcome> {
 const working={...state,cells:[...cells],units:state.units.map(unit=>({...unit}))};
 const live=working.units.filter(isAlive),forces=new Map(live.map(unit=>[unit.id,knownForceAt(unit,casts)]));
 const steps=new Map(live.map(unit=>[unit.id,displacementSteps(forces.get(unit.id)!,guards.has(unit.id),Boolean(unit.statuses.anchored))]));
 const results=new Map(live.map(unit=>[unit.id,{landing:at(unit),path:[],impact:false,blockedBy:[],environmentalDamage:0 as 0|1,statuses:[],cleansed:false,terrainName:''} as DisplacementOutcome]));
 const stopped=new Set<string>();
 for(let step=0;step<2;step++){
  const requests=new Map<string,{target:Point;path:Point[]}>();
  for(const unit of live){
   if(stopped.has(unit.id)||step>=steps.get(unit.id)!)continue;
   const force=forces.get(unit.id)!,strength=Math.max(Math.abs(force.q),Math.abs(force.r),Math.abs(force.q+force.r));
   // Normalize to a single force step; the authoritative helper supplies the
   // direction, solid geometry and any complete Ice slide in that step.
   const route=previewDisplacement(working,unit.id,{q:force.q/strength,r:force.r/strength});
   if(route.impact){results.get(unit.id)!.impact=true;stopped.add(unit.id);continue;}
   if(!route.path.length){stopped.add(unit.id);continue;}
   requests.set(unit.id,{target:route.landing,path:route.path});
  }
  const active=new Set(requests.keys());
  for(const [id,request] of requests){
   const sharing=[...requests].filter(([otherId,other])=>otherId!==id&&same(other.target,request.target)).map(([otherId])=>otherId);
   if(sharing.length){active.delete(id);results.get(id)!.blockedBy.push(...sharing);}
  }
  let changed=true;
  while(changed){
   changed=false;
   for(const id of active){
    const request=requests.get(id)!,occupant=live.find(unit=>same(unit,request.target));
    if(occupant&&occupant.id!==id&&!active.has(occupant.id)){
     active.delete(id);results.get(id)!.blockedBy.push(occupant.id);changed=true;
    }
   }
  }
  for(const [id,request] of requests){
   if(!active.has(id)){stopped.add(id);continue;}
   Object.assign(live.find(unit=>unit.id===id)!,request.target);
   const result=results.get(id)!;result.path.push(...request.path);result.landing=at(request.target);
  }
 }
 for(const unit of live){
  const result=results.get(unit.id)!,cell=getCell(working,unit.q,unit.r)!,effects=fieldEffects(cell);
  const before=state.units.find(candidate=>candidate.id===unit.id)!,known=protection.get(unit.id);
  const contact=result.path.length>0,cleansed=Boolean(known?.cleansed||contact&&effects.cleanse);
  const clarity=Boolean(known?.control||before.statuses.clarity||before.statuses.resolve||contact&&effects.statuses?.some(status=>status.id==='clarity'));
  const wet=Boolean(known?.wet||before.statuses.wet||contact&&effects.statuses?.some(status=>status.id==='wet'));
  const applications=[...(contact?effects.statuses??[]:[]),...(result.impact?[{id:'concussed' as const,turns:1,power:1}]:[])];
  result.statuses=[...new Set(applications.filter(status=>!(controls.includes(status.id)&&(clarity||cleansed))&&!(ailments.includes(status.id)&&cleansed)&&!(status.id==='burn'&&wet)).map(status=>label(status.id)))];
  result.cleansed=Boolean(contact&&effects.cleanse);
  const original=getCell(state,unit.q,unit.r)!,formed=fieldCombination(original)?.id!==fieldCombination(cell)?.id;
  const origin=exchangeOrigins.get(unit.id)??before;
  const hazard=effects.hazard==='always'||effects.hazard==='formed'&&formed||effects.hazard==='moved'&&!same(origin,unit);
  result.environmentalDamage=result.impact||hazard?1:0;
  result.terrainName=cell.ice?'Ice':fieldCombination(cell)?.name??(cell.biome==='ruins'?'Ruins':cell.biome==='forest'?'Forest':'Ground');
  result.blockedBy=[...new Set(result.blockedBy)].map(id=>{const blocker=state.units.find(candidate=>candidate.id===id)!;return blocker.displayName??getChampion(blocker.championId).name;});
 }
 return results;
}
