import {getChampion} from './roster-v13.ts';
import {getCreature} from './campaign-creatures-v20.ts';
import {effectiveSpell,getSignature,getSpell,spellAccess,STATUS_DEFINITIONS,type Spell} from './spells-v20.ts';
import type {Element} from './game.ts';
import type {TowerActor,TowerReward,TowerRun} from './tower-v23.ts';
import {CURRENT_SPELL_MODEL,profileSpell,spellProfileBands} from './spell-profile-v42.ts';

export type SpellStatChange={label:string;before:number;after:number};
export type TrainingSpellChange={id:string;name:string;changes:SpellStatChange[]};
export type TrainingPreview={
 kind:'train';name:string;element:Element;before:number;after:number;
 spells:TrainingSpellChange[];unlocks:{id:string;name:string;signature:boolean;cost:number}[];
};
export type RecoveryPreview={
 kind:'heal';total:number;unused:number;
 fighters:{id:string;name:string;before:number;after:number;maxHp:number;gain:number}[];
};
export type SpellRewardPreview={
 kind:'spell';
 recipients:{id:string;name:string;eligible:boolean;cost:number;reason?:string;signature:boolean}[];
};
export type TowerRewardPreview=TrainingPreview|RecoveryPreview|SpellRewardPreview;
const actorName=(actor:TowerActor)=>actor.displayName??(actor.creatureId?getCreature(actor.creatureId).name:getChampion(actor.championId).name);
const title=(value:string)=>value.charAt(0).toUpperCase()+value.slice(1);
const statusName=(id:string)=>STATUS_DEFINITIONS.find(status=>status.id===id)?.name??title(id);

/** Compare the actual effective definitions; do not duplicate affinity thresholds. */
export function spellStatChanges(before:Spell,after:Spell):SpellStatChange[]{
 const changes:SpellStatChange[]=[];
 for(const [key,label] of [['cost','Flux'],['range','Reach'],['damage','Damage'],['heal','Healing'],['recharge','Flux restored'],['steal','Flux stolen'],['push','Force'],['cooldown','Cooldown']] as const){
  const from=before[key]??0,to=after[key]??0;
  if(from!==to)changes.push({label,before:from,after:to});
 }
 for(const channel of ['harmful','friendly','self'] as const){
  for(const effect of after[channel]??[]){
   const original=before[channel]?.find(entry=>entry.id===effect.id);
   if(!original)continue;
   const prefix=channel==='self'?'Self ':channel==='friendly'?'Ally ':'';
   if((original.power??1)!==(effect.power??1))changes.push({label:`${prefix}${statusName(effect.id)}`,before:original.power??1,after:effect.power??1});
   if(original.turns!==effect.turns)changes.push({label:`${prefix}${statusName(effect.id)} rounds`,before:original.turns,after:effect.turns});
  }
 }
 return changes;
}
export function trainingSpellStatChanges(before:Spell,after:Spell):SpellStatChange[]{
 const previous=spellProfileBands(profileSpell(before,CURRENT_SPELL_MODEL)),next=spellProfileBands(profileSpell(after,CURRENT_SPELL_MODEL));
 if(!previous||!next)return spellStatChanges(before,after);
 const global=new Set(['Flux','Reach','Flux restored','Flux stolen','Force','Cooldown']);
 const changes=spellStatChanges(before,after).filter(change=>global.has(change.label));
 for(const [zone,label] of [['centre','Centre'],['inner','Inner'],['rim','Rim']] as const){
  changes.push(...spellStatChanges(previous[zone],next[zone]).filter(change=>!global.has(change.label)&&!change.label.startsWith('Self ')).map(change=>({...change,label:`${label} ${change.label.toLowerCase()}`})));
 }
 changes.push(...spellStatChanges(before,after).filter(change=>change.label.startsWith('Self ')));
 return changes;
}

function usable(actor:TowerActor,id:string,learnedSpells:readonly string[]):boolean{
 return spellAccess(actor.championId,id,actor.affinities,learnedSpells).unlocked&&effectiveSpell(actor.championId,id,actor.affinities).cost<=(actor.maxFlux??6);
}

/** A read-only consequence view shared by solo and friends reward screens. */
export function towerRewardPreview(run:Pick<TowerRun,'party'|'learnedSpells'>,reward:TowerReward):TowerRewardPreview|null{
 if(reward.kind==='heal'){
  const amount=Math.max(0,reward.amount??0);
  const fighters=run.party.map(actor=>{
   const maxHp=actor.maxHp??8,after=Math.min(maxHp,actor.hp+amount);
   return {id:actor.id,name:actorName(actor),before:actor.hp,after,maxHp,gain:after-actor.hp};
  });
  const total=fighters.reduce((sum,actor)=>sum+actor.gain,0);
  return {kind:'heal',total,unused:amount*fighters.length-total,fighters};
 }
 if(reward.kind==='train'&&reward.element){
  const actor=run.party.find(member=>member.id===reward.actorId);
  if(!actor||actor.creatureId)return null;
  const element=reward.element,before=actor.affinities[element]??0,after=before+(reward.amount??1),next={...actor,affinities:{...actor.affinities,[element]:after}};
  const signature=getSignature(actor.championId).id;
  const spells=[...new Set([...actor.loadout,signature])].filter(id=>usable(actor,id,run.learnedSpells)).flatMap(id=>{
   const changes=trainingSpellStatChanges(effectiveSpell(actor.championId,id,actor.affinities),effectiveSpell(actor.championId,id,next.affinities));
   return changes.length?[{id,name:getSpell(id).name,changes}]:[];
  });
  const unlocks=[...new Set([...run.learnedSpells,signature])].filter(id=>!usable(actor,id,run.learnedSpells)&&usable(next,id,run.learnedSpells)).map(id=>({id,name:getSpell(id).name,signature:id===signature,cost:effectiveSpell(actor.championId,id,next.affinities).cost}));
  return {kind:'train',name:actorName(actor),element,before,after,spells,unlocks};
 }
 if(reward.kind==='spell'&&reward.spellId){
  const id=reward.spellId,library=[...new Set([...run.learnedSpells,id])];
  const recipients=run.party.filter(actor=>!actor.creatureId).map(actor=>{
   const access=spellAccess(actor.championId,id,actor.affinities,library),spell=effectiveSpell(actor.championId,id,actor.affinities),affordable=spell.cost<=(actor.maxFlux??6);
   return {id:actor.id,name:actorName(actor),eligible:access.unlocked&&affordable,cost:spell.cost,signature:getSignature(actor.championId).id===id,...(!access.unlocked?{reason:`Needs ${access.requiredAffinity} ${title(spell.element)}`} : !affordable?{reason:`Needs ${spell.cost} Flux · maximum ${actor.maxFlux??6}`}:{})};
  });
  return {kind:'spell',recipients};
 }
 return null;
}
