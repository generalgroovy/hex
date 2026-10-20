import {isAlive,legalCasts,spellArea,combinationFor,type SimState,type TeamPlan,type Player,type Point} from './tactics-v16.ts';
import {effectiveSpell} from './spells-v16.ts';
import {profileSpell} from './spell-profile-v42.ts';
import {projectAlliedMovement} from './movement-preview-v16.ts';
import {findProjectileClashes,isTravellingProjectile,interceptionFieldArea} from './projectile-interception-v16.ts';
import type {VisibleCast} from './living-world-v16.ts';

const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;
/** Only a validated own-team plan and public board are used. Known blocked moves
 * change the release origin; hidden rival movement and spells stay unknown. */
export function projectedVolley(state:SimState,player:Player,plan:TeamPlan,stationaryRivals=false){
 const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit));
 const movements=projectAlliedMovement(state,player,plan,stationaryRivals);
 const positions=new Map(own.map(unit=>[unit.id,movements.get(unit.id)!.actualPosition]));
 const casts=plan.orders.flatMap(order=>{
  const unit=own.find(unit=>unit.id===order.unitId);
  if(!unit||!order.cast||!order.spellId)return [];
  const origin=positions.get(unit.id)!;
  if(!legalCasts(state,unit.id,origin,order.spellId).some(cell=>same(cell,order.cast!)))return [];
  const spell=profileSpell(effectiveSpell(unit.championId,order.spellId,unit.affinities),state.spellModel);
  return [{unitId:unit.id,spell,origin,target:order.cast,area:spellArea(state,unit.id,spell.id,order.cast,origin)}];
 });
 const clashes=findProjectileClashes(casts.filter(cast=>isTravellingProjectile(cast.spell,cast.origin,cast.target,
  own.some(unit=>same(positions.get(unit.id)!,cast.target)))).map(cast=>({unitId:cast.unitId,from:cast.origin,to:cast.target,element:cast.spell.element})),state.cells)
  .map(clash=>({...clash,terrain:combinationFor(clash.elements)!.id}));
 const intercepted=new Set(clashes.flatMap(clash=>clash.participants));
 const activeCasts=casts.filter(cast=>!intercepted.has(cast.unitId));
 const fields:VisibleCast[]=[...activeCasts.map(cast=>({element:cast.spell.element,area:cast.area,freeze:!!cast.spell.freeze})),
  ...clashes.flatMap(clash=>clash.elements.map(element=>({element,area:interceptionFieldArea(state.cells,clash),freeze:casts.some(cast=>clash.participants.includes(cast.unitId)&&cast.spell.freeze),canCounter:false})))];
 return {casts,activeCasts,clashes,intercepted,positions,movements,fields};
}
