import {getChampion,isAlive,POINTS_TO_WIN,type SimState,type TeamPlan,type Player,type Spell} from './tactics-v14.ts';
import {STATUS_DEFINITIONS} from './spells-v14.ts';

/** Readiness is an explicit decision, not the resolver's safe Hold + Guard fallback. */
export function planReadiness(state:SimState,player:Player,plan:TeamPlan) {
  const own=state.units.filter(unit=>unit.owner===player&&isAlive(unit));
  const readyIds=own.filter(unit=>{
    const order=plan.orders.find(entry=>entry.unitId===unit.id);
    return !!order&&(order.guard===true||!!(order.cast&&order.spellId));
  }).map(unit=>unit.id);
  const remainingIds=own.filter(unit=>!readyIds.includes(unit.id)).map(unit=>unit.id);
  return {active:own.length,ready:readyIds.length,readyIds,remainingIds,allReady:remainingIds.length===0,label:`${readyIds.length}/${own.length} ready`};
}

export type TurnGuidance={id:string;title:string;text:string};
export const SHORT_TURN_GUIDANCE:Record<string,string>={
  recover:'End turn to bring recovering characters back.',
  commit:'Team ready. End turn resolves movement, spells, fields, then well scoring.',
  action:'Landing chosen. Add a spell, or Guard to recover Flux and resist hits.',
  next:'Action chosen. Plan the next character; you can still edit these orders.',
  fizzle:'Blocked movement can put a spell out of range. Fizzles spend no Flux.',
  opening:`Reach ${POINTS_TO_WIN} points. Occupy wells, then cast or Guard. Both teams act together.`,
  'shared-fields':'Spells mix with the ground. Inspect the field; either team can use it.',
  anticipate:'Aim where rivals will be. Inspect their spells and Flux before committing.',
};
/** Teaches the public rules through the player's actual plan; never predicts rival orders. */
export function turnGuidance(state:SimState,player:Player,plan:TeamPlan,selected:string|null,previous?:SimState):TurnGuidance|null {
  if(state.winner!==null||state.round>3)return null;
  const readiness=planReadiness(state,player,plan);
  const unit=state.units.find(entry=>entry.id===selected&&entry.owner===player&&isAlive(entry));
  const order=unit?plan.orders.find(entry=>entry.unitId===unit.id):undefined;
  if(!readiness.active)return {id:'recover',title:'Your team returns next round',text:'End turn to bring recovering characters back. Defeats give the other team 1 point.'};
  if(readiness.allReady)return {id:'commit',title:'Your team is ready',text:'End turn locks your team’s orders. Both teams move, spells land, fields react, then occupied wells score.'};
  if(unit&&order?.move&&!order.cast&&!order.guard)return {id:'action',title:`${getChampion(unit.championId).name}: choose an action`,text:'Add a spell from this landing, or Guard to recover Flux and resist damage and displacement. Movement and action resolve together with the other team.'};
  if(unit&&readiness.readyIds.includes(unit.id))return {id:'next',title:`${readiness.ready} of ${readiness.active} ready`,text:'Choose the next character. Orders stay editable until End turn; everyone without an action will Guard.'};
  if(previous&&state.round>1&&state.lastResolution.some(event=>event.kind==='fizzle'&&state.units.some(entry=>entry.id===event.unitId&&entry.owner===player)))return {id:'fizzle',title:'A spell lost its landing',text:'A spell aimed beyond the original position needs its move to succeed. A blocked move can cancel the spell; no Flux is spent.'};
  if(state.round===1)return {id:'opening',title:`Hold wells. Reach ${POINTS_TO_WIN} points.`,text:'Move toward a glowing well, then cast or Guard. Each occupied well scores after the exchange; defeating a rival earns 1 point.'};
  if(state.round===2)return {id:'shared-fields',title:'The ground is part of your spell',text:'A spell mixes with the elements already on each hex. Inspect the resulting field: either team can use its protection, movement or healing.'};
  return {id:'anticipate',title:'Aim where they will be',text:'Rival orders stay hidden. Watch their equipped spells and Flux, then choose a landing and spell that still help if they move.'};
}

/** Main consequences use effective values. Full conditions remain in the spell description. */
export function spellEffectLabel(spell:Spell):string {
  const effects:string[]=[];
  if(spell.damage)effects.push(`${spell.damage}${spell.pierce?' piercing':''} damage`);
  if(spell.heal)effects.push(`heal ${spell.heal}`);
  if(spell.push)effects.push(`${spell.push>0?'push':'pull'} ${Math.abs(spell.push)}`);
  if(spell.wall)effects.push('raise barrier');
  if(spell.freeze)effects.push('freeze Water');
  if(spell.cleanse)effects.push('cleanse');
  if(spell.recharge)effects.push(`+${spell.recharge} Flux`);
  if(spell.steal)effects.push(`steal ${spell.steal} Flux`);
  if(spell.dispel)effects.push('remove barrier');
  const statuses=[...(spell.harmful??[]),...(spell.friendly??[]),...(spell.self??[])];
  for(const effect of statuses){const name=STATUS_DEFINITIONS.find(entry=>entry.id===effect.id)?.name;if(name&&!effects.includes(name))effects.push(name);}
  if(spell.drain)effects.push(`drain ${spell.drain}`);
  const main=effects.slice(0,3);
  if(spell.selfDamage)main.push(`self −${spell.selfDamage} HP`);
  if(spell.harm==='all'&&(spell.damage||spell.harmful?.length||spell.push))main.push('hits allies');
  return main.length?main.join(' · '):'shapes the field';
}
