import type {Element} from './game.ts';
import {ELEMENT_SPELL_LEVELS,getSpell} from './spells-v13.ts';
export type AffinityStep={rank:number;spellIds:readonly string[];spells:string;effect:string};
/** Describes the very next point, including the first point in a new element. */
export function nextAffinityStep(element:Element,currentRank:number):AffinityStep|null {
 if(!Number.isInteger(currentRank)||currentRank<0||currentRank>6)throw new Error('Affinity rank must be between 0 and 6.');
 if(currentRank===6)return null;
 const rank=currentRank+1,spellIds=ELEMENT_SPELL_LEVELS[element][rank-1];
 const effect=[
  '',
  'Unlocks this element’s first spells.',
  'Spells cost 1 less Flux and aimed spells gain 1 reach.',
  'Improves the main damage, healing, Ward or Flux effect by 1.',
  'Marks and beneficial statuses last 1 longer, up to 3 turns. Control duration stays fixed.',
  'Aimed spells gain 1 more reach.',
  'Improves the main damage, healing, Ward or Flux effect by 1 again.',
 ][rank];
 return {rank,spellIds,spells:spellIds.map(id=>getSpell(id).name).join(' / '),effect};
}
