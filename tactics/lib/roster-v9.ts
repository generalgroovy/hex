/** Rules 9 starts each original character with five points in at most three elements. */
import {CHAMPIONS as ORIGINAL_CHAMPIONS,type Champion} from './roster-v7.ts';
import type {Element} from './game.ts';
export type {Champion} from './roster-v7.ts';

export const STARTING_AFFINITY_POINTS=5;
export const MAX_AFFINITY_ELEMENTS=3;
export const ADVANCED_AFFINITY_THRESHOLD=3;
export const MAX_AFFINITY_LEVEL=6;
export type AffinityAllocation=Partial<Record<Element,number>>;
const ELEMENT_IDS:readonly Element[]=['fire','water','earth','air','light','dark'];

/** Both teams gain one point per character after every two completed rounds. */
export function affinityBudget(round:number):number {
  if(!Number.isSafeInteger(round)||round<1)throw new Error('Affinity budget requires a positive whole round.');
  return STARTING_AFFINITY_POINTS+Math.floor((round-1)/2);
}

/** Unspent points are implicit; this validator never fills or reallocates them. */
export function validateAffinityAllocation(input:unknown,totalMax:number):AffinityAllocation {
  if(!Number.isSafeInteger(totalMax)||totalMax<0)throw new Error('Affinity budget must be a nonnegative whole number.');
  if(!input||typeof input!=='object'||Array.isArray(input)||![Object.prototype,null].includes(Object.getPrototypeOf(input)))throw new Error('Choose an affinity allocation.');
  const entries=Object.entries(input);
  if(entries.length>MAX_AFFINITY_ELEMENTS)throw new Error('A character can have at most 3 different elements.');
  let spent=0;
  for(const [element,points] of entries){
    if(!ELEMENT_IDS.includes(element as Element)||!Number.isInteger(points)||points<1||points>MAX_AFFINITY_LEVEL)throw new Error('Affinity levels must be whole numbers from 1 to 6 for known elements; omit unused elements.');
    spent+=points;
  }
  if(spent>totalMax)throw new Error(`This character has ${totalMax} affinity points available.`);
  return Object.fromEntries(entries) as AffinityAllocation;
}

/** Preserve original element membership; the additional point strengthens the primary element. */
export const CHAMPIONS:Champion[]=ORIGINAL_CHAMPIONS.map(champion=>({
  ...champion,
  affinities:{...champion.affinities,[champion.element]:(champion.affinities[champion.element]??0)+1},
}));

export function getChampion(id:string):Champion {
  const champion=CHAMPIONS.find(entry=>entry.id===id);
  if(!champion)throw new Error('Unknown champion.');
  return champion;
}
