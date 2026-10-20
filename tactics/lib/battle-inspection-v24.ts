import {REFERENCE_STATUSES} from './combat-reference.ts';
import type {Status,StatusId} from './spells-v20.ts';

/** Inspection describes a status that is already active in this planning round. */
const EFFECTS:Record<StatusId,(power:number)=>string>={
 burn:power=>`Take ${power} damage at the coming exchange.`,
 wet:()=> 'Prevents Burn and enables spells that deal bonus damage to Wet targets.',
 chilled:()=> '−1 movement effort. Casting is unaffected.',
 rooted:()=> 'Cannot move. Casting and Guard still work.',
 concussed:()=> 'Spells cost +1 Flux. Movement and Guard are unaffected.',
 blind:()=> '−1 spell reach, minimum 1. Self spells still target only the caster.',
 ward:power=>`Absorb ${power} ordinary spell damage from the next volley.`,
 clarity:()=> 'Blocks new Blind, Rooted, Chilled and Concussed. Existing conditions remain.',
 anchored:()=> 'Cannot be pushed or pulled. Voluntary movement is unaffected.',
 haste:()=> '+1 movement effort. Does not stack with a current; Rooted still prevents movement.',
 wither:power=>`Receive ${power} less total healing this exchange.`,
 resolve:()=> 'Blocks new Blind, Rooted, Chilled and Concussed. Existing conditions remain.',
};
export function statusInsight(id:string,status:Status|undefined){
 const definition=REFERENCE_STATUSES.find(entry=>entry.id===id);
 if(!definition||!status||status.turns<=0)return undefined;
 return {...definition,turns:status.turns,power:status.power,effect:EFFECTS[definition.id](status.power),durationLabel:`${status.turns} round${status.turns===1?'':'s'} left`,powerLabel:['ward','burn','wither'].includes(id)?String(status.power):undefined};
}
const ORDER:StatusId[]=['rooted','concussed','blind','burn','chilled','wither','wet','ward','haste','clarity','anchored','resolve'];
export function activeStatusInsights(statuses:Partial<Record<StatusId,Status>>){return ORDER.flatMap(id=>{const insight=statusInsight(id,statuses[id]);return insight?[insight]:[]})}

/** Pure viewport placement, shared with tests. Never relies on an overflowing card. */
export function insightPosition(anchor:{left:number;right:number;top:number;bottom:number},size:{width:number;height:number},viewport:{width:number;height:number}){
 const gap=8,margin=8,width=Math.min(size.width,Math.max(1,viewport.width-margin*2)),height=Math.min(size.height,Math.max(1,viewport.height-margin*2));
 const left=Math.max(margin,Math.min(anchor.left,viewport.width-width-margin));
 const below=anchor.bottom+gap,above=anchor.top-gap-height;
 const top=below+height<=viewport.height-margin?below:above>=margin?above:Math.max(margin,Math.min(below,viewport.height-height-margin));
 return {left,top,width,maxHeight:Math.max(1,viewport.height-margin*2)};
}
