import {combinationById} from './combinations-v16.ts';
import type {SimCell} from './tactics-v20.ts';

export type FieldChange={before:string;after:string;count:number;rule:string;previousRule?:string;duration?:number};
const identity=(cell:SimCell)=>cell.ice?'ice':cell.terrain;
const naturalNames:Record<string,string>={plain:'Ground',forest:'Forest',marsh:'Marsh',ruins:'Wall'};
const fieldName=(cell:SimCell)=>cell.ice?'Ice':combinationById(cell.terrain)?.name??naturalNames[cell.terrain]??'Ground';
const rule=(cell:SimCell)=>cell.ice?'Entering slides to the last connected icy hex in that direction.':combinationById(cell.terrain)?.description??'Natural terrain remains.';

/** Summarize only the supplied known forecast. Never infers an enemy order. */
export function fieldChanges(before:readonly SimCell[],after:readonly SimCell[]):FieldChange[]{
 const old=new Map(before.map(cell=>[`${cell.q},${cell.r}`,cell])),changes=new Map<string,FieldChange>();
 for(const cell of after){
  const previous=old.get(`${cell.q},${cell.r}`);
  if(!previous||identity(previous)===identity(cell))continue;
  const key=`${identity(previous)}>${identity(cell)}:${cell.ttl??0}`;
  const group=changes.get(key);
  if(group){group.count++;continue;}
  changes.set(key,{before:fieldName(previous),after:fieldName(cell),count:1,rule:rule(cell),previousRule:rule(previous),...(cell.ttl?{duration:cell.ttl}:{})});
 }
 return [...changes.values()].sort((a,b)=>b.count-a.count||a.after.localeCompare(b.after)||a.before.localeCompare(b.before));
}
