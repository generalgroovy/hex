"use client";
import {useState} from 'react';
import {getSpell} from '../../lib/spells-v20';
import {towerCharm} from '../../lib/tower-supplies-v45';
import type {TowerActor,TowerReward} from '../../lib/tower-v23';
import './tower-supplies-v45.css';
const name=(actor:TowerActor)=>actor.displayName??actor.championId;
export function TowerSupplyRecipient({party,reward,onChoose}:{party:TowerActor[];reward:TowerReward;onChoose:(id:string)=>void}){
 const key=reward.kind==='charm'?'charmId':'scrollSpellId',value=reward.charmId??reward.spellId;
 const [selected,setSelected]=useState(()=>party.find(actor=>!actor[key])?.id??party.find(actor=>actor[key]!==value)?.id??party[0].id);
 const actor=party.find(actor=>actor.id===selected)??party[0],old=actor[key],same=old===value;
 return <div className="t45-recipient"><label>Give to<select aria-label={`Recipient for ${reward.name}`} value={actor.id} onChange={event=>setSelected(event.target.value)}>{party.map(actor=><option key={actor.id} value={actor.id}>{name(actor)}</option>)}</select></label>
 {old&&<small>{same?'Already equipped':`Replaces ${key==='charmId'?towerCharm(old).name:`${getSpell(old).name} scroll`}`}</small>}
 <button type="button" className="t22-primary" disabled={same} onClick={()=>onChoose(actor.id)}>Equip {reward.kind==='charm'?'charm':'scroll'}</button></div>;
}
export function TowerSupplies({actor,party,editable,onTransfer}:{actor:TowerActor;party:TowerActor[];editable:boolean;onTransfer:(target:string,slot:'charm'|'scroll')=>void}){
 if(!actor.charmId&&!actor.scrollSpellId)return null;
 return <section className="t45-supplies" aria-label={`${name(actor)} supplies`}>{(['charm','scroll'] as const).map(slot=>{
  const id=slot==='charm'?actor.charmId:actor.scrollSpellId;if(!id)return null;
  return <article key={slot}><div><strong>{slot==='charm'?towerCharm(id).name:`${getSpell(id).name} scroll`}</strong><small>{slot==='charm'?towerCharm(id).description:'One cast · 0 Flux · any affinity · printed strength'}</small></div>
   {editable&&<label><span className="t45-visually-hidden">Move {slot} to another fighter</span><select aria-label={`Move ${slot} to another fighter`} value="" onChange={event=>{if(event.target.value)onTransfer(event.target.value,slot)}}><option value="">Give / swap…</option>{party.filter(other=>other.id!==actor.id).map(other=><option key={other.id} value={other.id}>{name(other)} · {slot==='charm'?(other.charmId?`swaps ${towerCharm(other.charmId).name}`:'empty'):(other.scrollSpellId?`swaps ${getSpell(other.scrollSpellId).name} scroll`:'empty')}</option>)}</select></label>}
  </article>;
 })}</section>;
}
