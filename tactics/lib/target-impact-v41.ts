import {spellAtCell} from './spell-profile-v42.ts';
/** A bounded view of the known volley, never a prediction of hidden orders.
 * Damage is direct spell damage; recovery is spell/field healing before HP caps.
 * Burns, recoil, drain, collapse and unknown rival casts are not folded into
 * these figures. Conditional force/contact is reported separately, assuming
 * targets survive. The UI must label the figures as spell damage/recovery. */
import {areAllies,combinationById,fieldEffects,getCell,isAlive,validatePlan,volleyDamage,type Player,type Point,type SimState,type TeamPlan,type StatusId} from './tactics-v20.ts';
import {STATUS_DEFINITIONS} from './spells-v20.ts';
import {getChampion} from './roster-v13.ts';
import {inhabitantIntents} from './inhabitants-v16.ts';
import {visibleFieldForecast} from './living-world-v20.ts';
import {projectedVolley,type VolleyOptions} from './planned-volley-v20.ts';
import {interceptionFieldArea} from './projectile-interception-v20.ts';
import {knownDisplacementBranch,knownForceAt,type ContactProtection,type DisplacementImpact} from './displacement-impact-v42.ts';
import {fieldChanges,type FieldChange} from './field-change-v44.ts';
export type TargetImpact={id:string;name:string;ally:boolean;damage:{min:number;max:number};healing:number;statuses:string[];displacement?:DisplacementImpact};
export type TargetImpactPreview={targets:TargetImpact[];allyCount:number;enemyCount:number;cancelled:boolean;collisionName?:string;conditional:boolean;blocked:boolean;fieldChanges?:FieldChange[]};
const same=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
const controls:StatusId[]=['rooted','chilled','concussed','blind'];
const ailments:StatusId[]=['burn','wither',...controls];

export function targetImpactPreview(state:SimState,player:Player,input:TeamPlan,selectedUnitId:string|null,spellId?:string,aim?:Point,options:VolleyOptions&{healingTax?:number}={}):TargetImpactPreview|null {
 const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit)),selected=own.find(unit=>unit.id===selectedUnitId);
 if(!selected||state.winner!==null)return null;
 let orders=input.orders.filter(order=>own.some(unit=>unit.id===order.unitId));
 const queued=orders.find(order=>order.unitId===selected.id);
 if(spellId&&aim)orders=[...orders.filter(order=>order.unitId!==selected.id),{unitId:selected.id,...(queued?.move?{move:queued.move}:{}),spellId,cast:{q:aim.q,r:aim.r},...(options.selectedScroll?{scroll:true as const}:{})}];
 let plan:TeamPlan;try{plan=options.rules?options.rules.validatePlan({orders}):validatePlan(state,player,{orders});}catch{return null;}
 const selectedOrder=plan.orders.find(order=>order.unitId===selected.id);
 if(!selectedOrder?.cast||!selectedOrder.spellId)return null;
 const volley=projectedVolley(state,player,plan,false,options),selectedCast=volley.casts.find(cast=>cast.unitId===selected.id);
 const base:TargetImpactPreview={targets:[],allyCount:0,enemyCount:0,cancelled:false,conditional:true,blocked:!selectedCast};
 if(!selectedCast)return base;
 const clash=volley.clashes.find(entry=>entry.participants.includes(selected.id));
 const area=clash?interceptionFieldArea(state.cells,clash):selectedCast.area;
 const intents=inhabitantIntents(state);
 const fields=state.cells.map(cell=>visibleFieldForecast(cell,volley.fields,intents));
 const positioned={...state,units:state.units.map(unit=>({...unit,...(volley.positions.get(unit.id)??{})}))};
 const protections=new Map<string,ContactProtection>();
 for(const unit of positioned.units.filter(isAlive)){
  const ally=areAllies(state,unit.owner,player),effects=fieldEffects(fields.find(cell=>same(cell,unit))!);
  const relevant=volley.activeCasts.filter(cast=>cast.area.some(cell=>same(cell,unit))).map(cast=>({...cast,spell:spellAtCell(cast.spell,cast.target,unit)}));
  const friendly=ally?relevant:[],applications=[...relevant.flatMap(cast=>[...(ally?cast.spell.friendly??[]:[]),...(cast.spell.harm==='all'||!ally?cast.spell.harmful??[]:[])]),...(effects.statuses??[])];
  const cleansed=effects.cleanse===true||friendly.some(cast=>cast.spell.cleanse);
  protections.set(unit.id,{cleansed,wet:Boolean(unit.statuses.wet)||applications.some(status=>status.id==='wet'),control:Boolean(unit.statuses.clarity||unit.statuses.resolve)||applications.some(status=>status.id==='clarity')||!cleansed&&applications.some(status=>controls.includes(status.id))});
 }
 const ownGuards=new Set(plan.orders.filter(order=>order.guard).map(order=>order.unitId));
 const rivalGuards=new Set([...ownGuards,...positioned.units.filter(unit=>isAlive(unit)&&!areAllies(state,unit.owner,player)).map(unit=>unit.id)]);
 const origins=new Map(state.units.map(unit=>[unit.id,unit]));
 const forceWithoutGuard=knownDisplacementBranch(positioned,fields,volley.activeCasts,ownGuards,protections,origins);
 const forceWithGuard=knownDisplacementBranch(positioned,fields,volley.activeCasts,rivalGuards,protections,origins);
 const targets=state.units.filter(isAlive).flatMap(unit=>{
  const position=volley.positions.get(unit.id)??unit;
  if(!area.some(cell=>same(cell,position)))return [];
  const ally=areAllies(state,unit.owner,player),victim={...unit,...position};
  const cell=getCell(state,position.q,position.r)!;
  const after=visibleFieldForecast(cell,volley.fields,intents),effects=fieldEffects(after);
  const relevant=volley.activeCasts.filter(cast=>cast.area.some(point=>same(point,position))).map(cast=>({...cast,spell:spellAtCell(cast.spell,cast.target,position)}));
  const harmful=relevant.filter(cast=>cast.spell.harm==='all'||!ally).map(cast=>cast.spell);
  const friendly=ally?relevant:[];
  const guard=plan.orders.find(order=>order.unitId===unit.id)?.guard===true;
  const min=volleyDamage(after,victim,harmful,ally?guard:true),max=volleyDamage(after,victim,harmful,ally?guard:false);
  const cleanse=effects.cleanse===true||friendly.some(cast=>cast.spell.cleanse);
  const applications=[...relevant.flatMap(cast=>[...(ally?cast.spell.friendly??[]:[]),...(cast.spell.harm==='all'||!ally?cast.spell.harmful??[]:[])]),...(effects.statuses??[])];
  const wet=Boolean(unit.statuses.wet)||applications.some(status=>status.id==='wet');
  const clarity=Boolean(unit.statuses.clarity||unit.statuses.resolve)||applications.some(status=>status.id==='clarity');
  const cauterize=friendly.some(cast=>cast.spell.id==='cauterize');
  const statuses=[...new Set(applications.filter(status=>!(controls.includes(status.id)&&(clarity||cleanse))&&!(ailments.includes(status.id)&&cleanse&&!(status.id==='burn'&&cauterize))&&!(status.id==='burn'&&wet)).map(status=>STATUS_DEFINITIONS.find(definition=>definition.id===status.id)!.name))];
  const healing=Math.max(0,friendly.reduce((sum,cast)=>sum+cast.spell.heal,0)+(effects.heal??0)-(cleanse?0:unit.statuses.wither?.power??0)-Math.max(0,options.healingTax??0));
  const force=knownForceAt(position,volley.activeCasts),hasForce=Math.max(Math.abs(force.q),Math.abs(force.r),Math.abs(force.q+force.r))>1e-9;
  const displacement=hasForce?{anchored:Boolean(unit.statuses.anchored),withoutGuard:forceWithoutGuard.get(unit.id)!,withGuard:forceWithGuard.get(unit.id)!}:undefined;
  return [{id:unit.id,name:unit.displayName??getChampion(unit.championId).name,ally,damage:{min,max},healing,statuses,...(displacement?{displacement}:{})}];
 });
 return {...base,targets,allyCount:targets.filter(target=>target.ally).length,enemyCount:targets.filter(target=>!target.ally).length,cancelled:!!clash,...(clash?{collisionName:combinationById(clash.terrain)!.name}:{}),conditional:true,fieldChanges:fieldChanges(state.cells.filter(cell=>area.some(point=>same(point,cell))),fields.filter(cell=>area.some(point=>same(point,cell))))};
}
