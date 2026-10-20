import {profileSpell} from './spell-profile-v42.ts';
import {isAlive,legalCasts,spellArea,combinationFor,type SimState,type TeamPlan,type Player,type Point} from './tactics-v20.ts';
import {effectiveSpell,spellElements,type Spell} from './spells-v20.ts';
import {projectAlliedMovement} from './movement-preview-v16.ts';
import {findProjectileClashes,findLegacyProjectileClashes,isTravellingProjectile,interceptionFieldArea} from './projectile-interception-v20.ts';
import {presentCampaign} from './story-v20.ts';
import type {VisibleCast} from './living-world-v20.ts';

export type PreviewOrder=TeamPlan['orders'][number]&{scroll?:true};
export type PreviewRules={
 validatePlan:(plan:TeamPlan)=>TeamPlan;
 legalCasts:(unitId:string,from:Point|undefined,spellId:string,order:PreviewOrder)=>Point[];
 spell:(unitId:string,spellId:string,order:PreviewOrder)=>Spell;
 spellArea:(unitId:string,spellId:string,target:Point,from:Point,order:PreviewOrder)=>SimState['cells'];
};
export type VolleyOptions={legacyProjectiles?:boolean;rules?:PreviewRules;selectedScroll?:true};
const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;
/** Only a validated own-team plan and public board are used. Known blocked moves
 * change the release origin; hidden rival movement and spells stay unknown. */
export function projectedVolley(state:SimState,player:Player,plan:TeamPlan,stationaryRivals=false,options:VolleyOptions={}){
 const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit));
 const movements=projectAlliedMovement(presentCampaign(state),player===0?0:1,plan,stationaryRivals);
 const positions=new Map(own.map(unit=>[unit.id,movements.get(unit.id)!.actualPosition]));
 const casts=plan.orders.flatMap(order=>{
  const unit=own.find(unit=>unit.id===order.unitId);
  if(!unit||!order.cast||!order.spellId)return [];
  const origin=positions.get(unit.id)!;
  if(!(options.rules?options.rules.legalCasts(unit.id,origin,order.spellId,order):legalCasts(state,unit.id,origin,order.spellId)).some(cell=>same(cell,order.cast!)))return [];
  const spell=options.rules?options.rules.spell(unit.id,order.spellId,order):profileSpell(effectiveSpell(unit.championId,order.spellId,unit.affinities),state.spellModel);
  return [{unitId:unit.id,spell,origin,target:order.cast,area:options.rules?options.rules.spellArea(unit.id,spell.id,order.cast,origin,order):spellArea(state,unit.id,spell.id,order.cast,origin)}];
 });
 const clashes=(options.legacyProjectiles?findLegacyProjectileClashes:findProjectileClashes)(casts.filter(cast=>isTravellingProjectile(cast.spell,cast.origin,cast.target,
  own.some(unit=>same(positions.get(unit.id)!,cast.target)))).map(cast=>({unitId:cast.unitId,from:cast.origin,to:cast.target,element:cast.spell.element,elements:spellElements(cast.spell)})),state.cells)
  .map(clash=>{const elements=[...new Set(casts.filter(cast=>clash.participants.includes(cast.unitId)).flatMap(cast=>spellElements(cast.spell)))];return {...clash,elements,terrain:combinationFor(elements)!.id}});
 const intercepted=new Set(clashes.flatMap(clash=>clash.participants));
 const activeCasts=casts.filter(cast=>!intercepted.has(cast.unitId));
 const fields:VisibleCast[]=[...activeCasts.flatMap(cast=>spellElements(cast.spell).map(element=>({element,area:cast.area,freeze:!!cast.spell.freeze}))),
  ...clashes.flatMap(clash=>clash.elements.map(element=>({element,area:interceptionFieldArea(state.cells,clash),freeze:casts.some(cast=>clash.participants.includes(cast.unitId)&&cast.spell.freeze),canCounter:false})))];
 return {casts,activeCasts,clashes,intercepted,positions,movements,fields};
}
