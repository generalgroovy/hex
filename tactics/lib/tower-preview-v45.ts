import {validatePlan,legalCasts,spellArea,battleSpell,type SimState,type TeamPlan} from './tactics-v22.ts';
import type {PreviewRules} from './planned-volley-v20.ts';
/** Native Tower legality and strength, including consumables. Campaign readers
 * retain their own defaults; this adapter never enters a campaign resolver. */
export function towerPreviewRules(state:SimState):PreviewRules {
 return {
  validatePlan:plan=>validatePlan(state,0,plan as TeamPlan),
  legalCasts:(id,from,spell,order)=>legalCasts(state,id,from,spell,order.scroll),
  spell:(id,spell,order)=>battleSpell(state,id,spell,order.scroll),
  spellArea:(id,spell,target,from,order)=>spellArea(state,id,spell,target,from,order.scroll),
 };
}
