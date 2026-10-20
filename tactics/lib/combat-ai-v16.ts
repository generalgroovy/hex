/** Bounded public-state utility. None of these estimates reads sealed rival orders. */
import type {Spell, StatusApplication, StatusId} from './spells-v11.ts';
import type {CombinationMechanics} from './combinations-v16.ts';

type Combatant={hp:number;maxHp:number;flux:number;statuses:Partial<Record<StatusId,{turns:number;power:number}>>};
const controls:readonly StatusId[]=['rooted','chilled','concussed','blind'];
const ailments:readonly StatusId[]=['burn','wither',...controls];

/** Direct harm includes a zero-damage pull or impairment. Friendly support stays legal. */
export function threatensAlly(spell:Spell):boolean {
  return spell.harm==='all'&&Boolean(spell.damage||spell.push||spell.harmful?.length);
}

/** Wither reduces aggregate healing before the health cap; cleansing removes that tax. */
export function effectiveHealing(unit:Combatant,amount:number,cleansed=false):number {
  return Math.min(Math.max(0,unit.maxHp-unit.hp),Math.max(0,amount-(cleansed?0:unit.statuses.wither?.power??0)));
}

/** A public upper bound. A rival may spend this Flux before simultaneous theft resolves. */
export function availableTheft(unit:Combatant,amount:number,priorSpells:readonly Spell[]=[]):number {
  const prior=priorSpells.reduce((sum,spell)=>sum+(spell.steal??0),0);
  return Math.max(0,Math.min(amount,unit.flux-prior));
}

/** Value only a direct mark which survives known immunity and adds duration or power.
 * Field marks participate in cancellation but their own utility is scored by fieldValue.
 * New Wet can remove a prior planned Burn; new control never cancels a sealed cast.
 */
export function harmfulStatusValue(unit:Combatant,spell:Spell,effects:Readonly<CombinationMechanics>,priorSpells:readonly Spell[]=[]):number {
  const field=effects.statuses??[];
  const value=(spells:readonly Spell[]):number=>{
    const direct=spells.flatMap(candidate=>candidate.harmful??[]),all=[...field,...direct];
    const wet=Boolean(unit.statuses.wet)||all.some(status=>status.id==='wet');
    const clear=Boolean(unit.statuses.clarity)||all.some(status=>status.id==='clarity');
    const accepted=(application:StatusApplication)=>!(effects.cleanse&&ailments.includes(application.id))
      &&!(controls.includes(application.id)&&(unit.statuses.resolve||clear))
      &&!(application.id==='burn'&&wet);
    let total=0;
    for(const id of new Set(direct.map(status=>status.id))){
      const incoming=direct.filter(status=>status.id===id&&accepted(status));
      if(!incoming.length)continue;
      const natural=field.filter(status=>status.id===id&&accepted(status));
      const baselineTurns=Math.max(Math.max(0,(unit.statuses[id]?.turns??0)-1),...natural.map(status=>status.turns));
      const baselinePower=Math.max(unit.statuses[id]?.turns&&unit.statuses[id]!.turns>1?unit.statuses[id]!.power:0,...natural.map(status=>status.power??1));
      const turns=Math.max(...incoming.map(status=>status.turns)),power=Math.max(...incoming.map(status=>status.power??1));
      if(turns>baselineTurns||power>baselinePower)total++;
    }
    return total;
  };
  return value([...priorSpells,spell])-value(priorSpells);
}
