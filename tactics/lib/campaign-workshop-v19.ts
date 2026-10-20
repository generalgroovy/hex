import {getChampion,affinityTotal,type AffinityAllocation} from './roster-v13.ts';
import type {Element} from './game.ts';
import {canonicalBuild,type CharacterBuild} from './character-creation-v17.ts';
import {repairLoadout} from './spells-v16.ts';

/** Keep earned investment and a chosen name when changing the hero's appearance. */
export function changeCampaignAppearance(current:CharacterBuild,championId:string,learned:readonly string[],rankCap=Math.min(6,Math.max(5,affinityTotal(current.affinities))-2)):CharacterBuild{
 const base=canonicalBuild(championId),spent=Math.max(5,affinityTotal(current.affinities));
 const primary=getChampion(championId).element,affinities:AffinityAllocation={...base.affinities};
 const elements=[primary,...Object.keys(affinities).filter(element=>element!==primary),...(['fire','water','earth','air','light','dark'] as Element[]).filter(element=>!affinities[element])].slice(0,3) as Element[];
 let remaining=spent-affinityTotal(affinities);
 for(const element of elements){const add=Math.min(remaining,rankCap-(affinities[element]??0));if(add>0){affinities[element]=(affinities[element]??0)+add;remaining-=add}}
 if(remaining)throw new Error('This investment does not fit the current element level limit.');
 return {...base,name:current.name===getChampion(current.championId).name?base.name:current.name,affinities,loadout:repairLoadout(championId,current.loadout,affinities,learned)};
}

/** Ordinary in-progress edits are a draft, not a validation failure. */
export function campaignDraftHint(build:CharacterBuild):string|null{
 const missing=5-affinityTotal(build.affinities);
 if(missing>0)return `Assign ${missing} affinity point${missing===1?'':'s'} to use this build.`;
 if(!build.name.trim())return 'Choose a name to use this build.';
 return null;
}
