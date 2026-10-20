import type {Point} from './game.ts';
import type {DisplacementImpact,DisplacementOutcome} from './displacement-impact-v42.ts';
import type {TargetImpactPreview} from './target-impact-v41.ts';

export type CastChoice={id:string;available:boolean};
/** Preserve intent after moving, but never aim a spell the fighter cannot cast. */
export function castAfterMove(preferred:string|undefined,choices:CastChoice[],guard=false):string|null{
 if(guard)return null;
 return choices.find(choice=>choice.id===preferred&&choice.available)?.id??choices.find(choice=>choice.available)?.id??null;
}
export function orderReadout(order:{move?:Point;cast?:Point;spellId?:string;guard?:boolean}|undefined,spellName:(id:string)=>string,tile:(point:Point)=>string):{movement:string;action:string;queued:boolean}{
 return {movement:order?.move?`Move to ${tile(order.move)}`:'Hold position',action:order?.guard?'Guard':order?.cast&&order.spellId?`${spellName(order.spellId)} → ${tile(order.cast)}`:'Guard unless a spell is chosen',queued:!!(order?.guard||order?.cast)};
}
export function displacementReadout(outcome:DisplacementOutcome,tile:(point:Point)=>string):string{
 const pieces=[outcome.path.length?`To ${tile(outcome.landing)} · ${outcome.terrainName}`:'Holds position'];
 if(outcome.impact)pieces.push('wall impact');
 if(outcome.blockedBy.length)pieces.push(`blocked by ${outcome.blockedBy.join(', ')}`);
 if(outcome.environmentalDamage)pieces.push(`${outcome.environmentalDamage} environment dmg`);
 if(outcome.statuses.length)pieces.push(outcome.statuses.join(' · '));
 if(outcome.cleansed)pieces.push('cleansed');
 return pieces.join(' · ');
}
export function displacementReadouts(displacement:DisplacementImpact,tile:(point:Point)=>string):{label:string;text:string}[]{
 const without=displacementReadout(displacement.withoutGuard,tile),guarded=displacementReadout(displacement.withGuard,tile);
 if(displacement.anchored)return [{label:'Anchored',text:without}];
 return without===guarded?[{label:'Force',text:without}]:[{label:'Enemies act',text:without},{label:'Enemies Guard',text:guarded}];
}
/** Keep the decision consequence on phones; the full conditional view stays one tap away. */
export function compactImpactReadout(preview:TargetImpactPreview|undefined|null):string|null{
 if(!preview)return null;
 if(preview.blocked)return 'Blocked landing · spell may fail';
 if(preview.cancelled)return `${preview.collisionName??'Elemental collision'} · projectiles meet`;
 const affected=preview.targets.filter(target=>target.damage.max>0||target.healing>0||target.statuses.length||target.displacement);
 if(!affected.length)return `${preview.targets.length?'No spell damage here':'No fighters in this area'} · terrain can still react`;
 const target=affected.find(actor=>!actor.ally)??affected[0],parts:string[]=[];
 if(target.damage.max>0)parts.push(`${target.damage.min===target.damage.max?target.damage.max:`${target.damage.min}–${target.damage.max}`} spell dmg`);
 if(target.displacement)parts.push(target.displacement.anchored?'Anchored':target.displacement.withoutGuard.impact?'wall impact possible':'forced movement');
 else if(target.healing>0)parts.push(`+${target.healing} recovery`);
 if(target.statuses.length&&!target.displacement)parts.push(target.statuses[0]);
 return `${target.name} · ${parts.join(' · ')}${affected.length>1?` · +${affected.length-1} more`:''}`;
}
