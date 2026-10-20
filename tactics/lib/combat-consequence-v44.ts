/** Contributions are pre-mitigation. Protection is applied to the whole volley,
 * so assigning an invented post-mitigation damage share to each caster is wrong. */
export type ConsequenceSource={
 kind:'spell'|'burn'|'recoil'|'link'|'field'|'drain';
 amount:number;unitId?:string;spellId?:string;
};
export type CombatBreakdown={sources:ConsequenceSource[];prevented:number;total:number};
export function combatBreakdown(sources:readonly ConsequenceSource[],total:number):CombatBreakdown{
 const present=sources.filter(source=>source.amount>0).map(source=>({...source}));
 return {sources:present,prevented:present.reduce((sum,source)=>sum+source.amount,0)-total,total};
}
/** Saved explanation is optional for old replays. Reject invented sources and
 * nonconserving totals without treating this metadata as combat authority. */
export function validateCombatBreakdown(input:unknown,event:{kind:unknown;amount?:unknown},unitIds:ReadonlySet<string>,spellIds:ReadonlySet<string>):void{
 if(input===undefined)return;
 if(!input||typeof input!=='object'||Array.isArray(input)||!['damage','heal'].includes(String(event.kind)))throw new Error('Invalid combat explanation.');
 const value=input as Record<string,unknown>;
 if(Object.keys(value).some(key=>!['sources','prevented','total'].includes(key))||!Array.isArray(value.sources)||value.sources.length>180||!Number.isInteger(value.total)||Number(value.total)<0||value.total!==event.amount||!Number.isInteger(value.prevented)||Number(value.prevented)<0)throw new Error('Invalid combat explanation totals.');
 let sum=0;
 for(const raw of value.sources){
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new Error('Invalid combat contribution.');
  const source=raw as Record<string,unknown>;
  if(Object.keys(source).some(key=>!['kind','amount','unitId','spellId'].includes(key))||!['spell','burn','recoil','link','field','drain'].includes(String(source.kind))||!Number.isInteger(source.amount)||Number(source.amount)<1||Number(source.amount)>100)throw new Error('Invalid combat contribution.');
  if(source.unitId!==undefined&&(typeof source.unitId!=='string'||!unitIds.has(source.unitId)))throw new Error('Unknown combat contributor.');
  if(source.spellId!==undefined&&(typeof source.spellId!=='string'||!spellIds.has(source.spellId)))throw new Error('Unknown contribution spell.');
  if(['spell','recoil','drain'].includes(String(source.kind))&&(source.unitId===undefined||source.spellId===undefined))throw new Error('Missing combat source.');
  if(event.kind==='heal'&&['burn','recoil','link'].includes(String(source.kind))||event.kind==='damage'&&source.kind==='drain')throw new Error('Wrong contribution channel.');
  sum+=Number(source.amount);
 }
 if(sum-Number(value.prevented)!==value.total)throw new Error('Combat contributions do not conserve the total.');
}

/** Timing is a public contract, not another action phase. These entries describe
 * the existing resolver and can be reused by inspection/help without new rules. */
export const COMBAT_CLOCK=Object.freeze([
 {id:'movement',name:'Movement',rule:'Existing movement statuses apply. Conflicting landings can change a casting origin.'},
 {id:'release',name:'Release',rule:'All legal spells release from one shared snapshot. New control never cancels a released spell.'},
 {id:'contact',name:'Contact',rule:'Projectiles meet; surviving ingredients form one field. Same-exchange marks do not enable bonus damage.'},
 {id:'effects',name:'Effects',rule:'Old Ward protects now. New Clarity and Wet work now; new Ward and Anchored protect next exchange.'},
 {id:'aftermath',name:'Aftermath',rule:'Forces combine, then final terrain contact, bonds, closing ground, recovery and elimination resolve.'},
] as const);
export const STATUS_TIMING=Object.freeze({
 burn:'Ticks in a later exchange; Wet and cleansing can prevent that tick.',
 wet:'Extinguishes Burn immediately. Bonus damage needs Wet from before this exchange.',
 rooted:'Stops movement next planning; Resolve prevents repeated control.',
 chilled:'Reduces movement next planning.',
 concussed:'Increases spell cost next planning.',
 blind:'Reduces spell reach next planning.',
 ward:'New Ward protects next exchange; existing Ward absorbs the combined non-piercing volley once.',
 anchored:'New Anchored resists force next exchange; voluntary movement stays available.',
 haste:'Adds movement effort next planning.',
 wither:'Reduces healing from the next exchange; cleansing removes it first.',
 clarity:'Blocks incoming control immediately, without removing existing ailments.',
 resolve:'Blocks new control after a previous control effect; does not remove the current effect.',
});
