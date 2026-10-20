/** Equal-budget companies for multiplayer. Appearance never grants extra stats. */
import {getChampion,validateAffinityAllocation,affinityTotal,type AffinityAllocation} from './roster-v13.ts';
import {defaultLoadout,validateLoadout} from './spells-v16.ts';
export type CharacterBuild={championId:string;name:string;affinities:AffinityAllocation;loadout:string[]};
export const CREATION_BUDGET=5;
export const COMPANY_SIZE=3;
export function creationAffinities(championId:string,input:unknown):AffinityAllocation{
 const hero=getChampion(championId),points=validateAffinityAllocation(input,CREATION_BUDGET);
 if(affinityTotal(points)!==CREATION_BUDGET)throw new Error('Spend exactly five affinity points on each character.');
 const primary=points[hero.element]??0;
 if(primary<2||Object.values(points).some(n=>(n??0)>3||(n??0)>primary))throw new Error(`Keep ${hero.element} at two or three points and at least as high as the other elements. No affinity can exceed three.`);
 return points;
}
export function canonicalBuild(championId:string):CharacterBuild{
 const hero=getChampion(championId),affinities=creationAffinities(championId,hero.affinities);
 return {championId,name:hero.name,affinities,loadout:defaultLoadout(championId,affinities,[])};
}
export function validateCharacterBuild(input:unknown):CharacterBuild{
 if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('Choose a character and four spells.');
 const value=input as Record<string,unknown>;
 if(Object.keys(value).some(key=>!['championId','name','affinities','loadout'].includes(key)))throw new Error('Only appearance, name, affinities and spells can be customized.');
 if(typeof value.championId!=='string')throw new Error('Choose a known character appearance.');
 const hero=getChampion(value.championId);
 if(typeof value.name!=='string'||value.name.trim().length<1||value.name.trim().length>24||/[\x00-\x1f\x7f<>]/.test(value.name))throw new Error('Use a character name from 1 to 24 plain characters.');
 const affinities=creationAffinities(hero.id,value.affinities);
 const loadout=validateLoadout(hero.id,value.loadout,affinities,[]);
 return {championId:hero.id,name:value.name.trim(),affinities,loadout};
}
export function validateCompany(input:unknown):CharacterBuild[]{
 if(!Array.isArray(input)||input.length!==COMPANY_SIZE)throw new Error('Choose exactly three characters.');
 const company=input.map(validateCharacterBuild);
 if(new Set(company.map(c=>c.championId)).size!==COMPANY_SIZE)throw new Error('Use three different character appearances in your company.');
 return company;
}
