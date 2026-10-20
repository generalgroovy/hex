import {spellAtCell} from './spell-profile-v42.ts';
import type {Point,SimCell,SimUnit,Spell} from './tactics-v20.ts';
import type {ProjectileClash} from './projectile-interception-v20.ts';
import {interceptionFieldArea} from './projectile-interception-v20.ts';
import {spellElements} from './spells-v20.ts';
import {harmfulStatusValue} from './combat-ai-v16.ts';
export type TacticalCast={unitId:string;spell:Spell;target?:Point;area:readonly Point[]};
type Rules={
 field:(cell:SimCell,elements:ReturnType<typeof spellElements>,freeze:boolean)=>SimCell;
 damage:(cell:SimCell,victim:SimUnit,spells:readonly Spell[],guard:boolean)=>number;
 fieldValue:(cell:SimCell,unit:SimUnit,origin:Point,previous:SimCell,includeHealing:boolean)=>number;
 healing:(unit:SimUnit,amount:number,cleanse:boolean)=>number;
 effects:(cell:SimCell)=>import('./combinations-v16.ts').CombinationMechanics;
};
const same=(left:Point,right:Point)=>left.q===right.q&&left.r===right.r;
/** Value the actual shared field against the previous draft, including the
 * useful direct hits it consumes. No enemy orders or old Guard flags enter. */
export function alliedClashValue(input:{cells:SimCell[];allies:SimUnit[];enemies:SimUnit[];origins:SimUnit[];before:TacticalCast[];after:TacticalCast[];beforeClashes:ProjectileClash[];afterClashes:ProjectileClash[];guards:Set<string>;cost:number;selfDamage:number},rules:Rules):number {
 const batch=(casts:TacticalCast[],clashes:ProjectileClash[])=>{
  const consumed=new Set(clashes.flatMap(clash=>clash.participants));
  const active=casts.filter(cast=>!consumed.has(cast.unitId));
  const fields=clashes.map(clash=>({...clash,area:interceptionFieldArea(input.cells,clash),freeze:casts.some(cast=>clash.participants.includes(cast.unitId)&&cast.spell.freeze)}));
  return (unit:SimUnit)=>{
   const cell=input.cells.find(point=>same(point,unit))!;
   const arrivals=active.filter(cast=>cast.area.some(point=>same(point,unit))).map(cast=>({...cast,spell:cast.target?spellAtCell(cast.spell,cast.target,unit):cast.spell})),meetings=fields.filter(clash=>clash.area.some(point=>same(point,unit)));
   const field=rules.field(cell,[...arrivals.flatMap(cast=>spellElements(cast.spell)),...meetings.flatMap(clash=>clash.elements)],arrivals.some(cast=>cast.spell.freeze)||meetings.some(clash=>clash.freeze));
   return {field,arrivals,cell,effects:rules.effects(field)};
  };
 };
 const before=batch(input.before,input.beforeClashes),after=batch(input.after,input.afterClashes);
 let score=-input.cost*.35-input.selfDamage*2;
 for(const [units,allied] of [[input.allies,true],[input.enemies,false]] as const)for(const unit of units){
  const old=before(unit),next=after(unit),origin=input.origins.find(actor=>actor.id===unit.id)??unit;
  const harmful=(casts:TacticalCast[])=>casts.filter(cast=>!allied||cast.spell.harm==='all').map(cast=>cast.spell);
  const prior=harmful(old.arrivals),following=harmful(next.arrivals);
  const outcomes=allied?[[input.guards.has(unit.id),1] as const]:[[false,.65] as const,[true,.35] as const];
  for(const [guard,weight] of outcomes){
   const priorDamage=rules.damage(old.field,unit,prior,guard),nextDamage=rules.damage(next.field,unit,following,guard);
   const value=(nextDamage-priorDamage)*3+(Number(nextDamage>=unit.hp)-Number(priorDamage>=unit.hp))*5;
   score+=(allied?-1:1)*value*weight;
  }
  const fieldDelta=rules.fieldValue(next.field,unit,origin,next.cell,false)-rules.fieldValue(old.field,unit,origin,old.cell,false);
  score+=(allied?1:-1)*fieldDelta;
  const statusValue=(spells:Spell[],effects:ReturnType<Rules['effects']>)=>spells.reduce((sum,spell,index)=>sum+harmfulStatusValue(unit,spell,effects,spells.slice(0,index)),0);
  score+=(allied?-1:1)*(statusValue(following,next.effects)-statusValue(prior,old.effects));
  const recovery=(result:ReturnType<typeof before>)=>rules.healing(unit,(allied?result.arrivals.reduce((sum,cast)=>sum+cast.spell.heal,0):0)+(result.effects.heal??0),Boolean(result.effects.cleanse||allied&&result.arrivals.some(cast=>cast.spell.cleanse)));
  score+=(allied?1:-1)*(recovery(next)-recovery(old))*3;
 }
 return score;
}
