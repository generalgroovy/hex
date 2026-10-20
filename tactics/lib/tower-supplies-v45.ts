import {getSpell,type Spell,type StatusId} from './spells-v20.ts';
import type {SpellModel} from './spell-profile-v42.ts';
import {profileSpell} from './spell-profile-v42.ts';

/** One slot of each kind. No stockpile, random stat rolls or permanent stat inflation. */
export const TOWER_CHARMS=[
 {id:'river-stone',name:'River stone',description:'Start each fight with Ward 2 for 2 exchanges.',status:'ward',power:2,turns:2},
 {id:'swallow-pin',name:'Swallow pin',description:'Start each fight with Haste for 2 exchanges: +1 movement effort.',status:'haste',power:1,turns:2},
 {id:'clear-lens',name:'Clear lens',description:'Start each fight with Clarity for 2 exchanges: blocks incoming control.',status:'clarity',power:1,turns:2},
 {id:'iron-knot',name:'Iron knot',description:'Start each fight Anchored for 2 exchanges: cannot be pushed or pulled.',status:'anchored',power:1,turns:2},
] as const;
export type TowerCharmId=typeof TOWER_CHARMS[number]['id'];
/** A small toolbox: pressure, ice, barriers, force, recovery and resource denial. */
export const TOWER_SCROLLS=['immolate','frostbite','bulwark','gale','mend','essence_theft'] as const;
export function towerCharm(id:string){const item=TOWER_CHARMS.find(item=>item.id===id);if(!item)throw new Error('Unknown charm.');return item;}
export function validTowerScroll(id:unknown):id is string{return typeof id==='string'&&(TOWER_SCROLLS as readonly string[]).includes(id);}
export function towerScrollSpell(id:string,model?:SpellModel):Spell{
 if(!validTowerScroll(id))throw new Error('Unknown scroll.');
 return profileSpell({...getSpell(id),cost:0,cooldown:0},model);
}
export function openingCharmStatus(id?:string):Partial<Record<StatusId,{turns:number;power:number}>>{
 if(!id)return {};const item=towerCharm(id);return {[item.status]:{turns:item.turns,power:item.power}};
}
export function carryTowerSupplies<T extends {scrollSpellId?:string}>(actor:T,spentScroll?:true):T{
 const next={...actor};if(spentScroll)delete next.scrollSpellId;return next;
}
