/** Rules 11 carries story-earned affinities into a match as a fixed allocation. */
import {CHAMPIONS as ORIGINAL_CHAMPIONS,type Champion} from './roster-v7.ts';
import type {Element} from './game.ts';
export type {Champion} from './roster-v7.ts';

export const STARTING_AFFINITY_POINTS=5;
export const MAX_AFFINITY_ELEMENTS=3;
export const ADVANCED_AFFINITY_THRESHOLD=3;
export const MAX_AFFINITY_LEVEL=6;
export const MAX_AFFINITY_POINTS=MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL;
export type AffinityAllocation=Partial<Record<Element,number>>;
const ELEMENT_IDS:readonly Element[]=['fire','water','earth','air','light','dark'];

export function affinityTotal(allocation:AffinityAllocation):number {
  return Object.values(allocation).reduce((sum,points)=>sum+(points??0),0);
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

/** Story investment can add to a champion's identity, never remove its starting affinities. */
export function validateChampionAffinities(id:string,input:unknown,totalMax=MAX_AFFINITY_POINTS):AffinityAllocation {
  const champion=getChampion(id),affinities=validateAffinityAllocation(input,totalMax);
  for(const [element,starting] of Object.entries(champion.affinities))if((affinities[element as Element]??0)<(starting??0))throw new Error('Starting affinity points cannot be removed or reassigned.');
  return affinities;
}

export function teamAffinityTotal(roster:readonly string[],allocations:Readonly<Record<string,AffinityAllocation>>={}):number {
  return roster.reduce((sum,id)=>sum+affinityTotal(validateChampionAffinities(id,allocations[id]??getChampion(id).affinities)),0);
}

/** A predictable opponent build: develop its primary, then its native support elements. */
export function allocateAffinityBudget(championId:string,budget:number):AffinityAllocation {
  if(!Number.isSafeInteger(budget)||budget<STARTING_AFFINITY_POINTS||budget>MAX_AFFINITY_POINTS)throw new Error('Affinity budget must be a whole number from 5 to 18.');
  const champion=getChampion(championId),allocation:AffinityAllocation={...champion.affinities};
  const native=ELEMENT_IDS.filter(element=>element!==champion.element&&(allocation[element]??0)>0).sort((a,b)=>(allocation[b]??0)-(allocation[a]??0)||ELEMENT_IDS.indexOf(a)-ELEMENT_IDS.indexOf(b));
  const elements=[champion.element,...native,...ELEMENT_IDS.filter(element=>!allocation[element])].slice(0,MAX_AFFINITY_ELEMENTS);
  let remaining=budget-affinityTotal(allocation);
  for(const element of elements){
    const added=Math.min(remaining,MAX_AFFINITY_LEVEL-(allocation[element]??0));
    if(added>0)allocation[element]=(allocation[element]??0)+added;
    remaining-=added;
  }
  return validateChampionAffinities(championId,allocation,budget);
}
