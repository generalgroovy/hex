"use client";
import {useEffect,useRef,useState} from 'react';
import {TOWER_STARTERS,TOWER_SOLO_STARTERS,validateTowerStarter,type TowerStart,type TowerMemberInput,type TowerBuild} from '../../lib/tower-v23';
import {CHAMPIONS,getChampion,affinityTotal,allocateAffinityBudget} from '../../lib/roster-v13';
import {CREATURES,getCreature} from '../../lib/campaign-creatures-v20';
import {getSignature,effectiveSpell,spellAccess,defaultLoadout} from '../../lib/spells-v20';
import type {Element} from '../../lib/game';
import TowerCharacterBuilder from './TowerCharacterBuilderV23';
import PixelChampion from './PixelChampion';
import CombatCreature from './CombatCreatureV19';
import ElementIcon from './ElementIcon';
import {TowerSpellPreview,TowerBondPreview} from './TowerKitPreviewV23';
import './tower-v22.css';
import './tower-team-v23.css';

export const TOWER_STARTING_CREATURES=CREATURES.filter(creature=>creature.strengthClass==='lesser'&&affinityTotal(creature.affinities)===2);
const memberIdentity=(member:TowerMemberInput)=>member.kind==='champion'?`champion:${member.build.championId}`:`creature:${member.creatureId}`;
const memberName=(member:TowerMemberInput)=>member.kind==='champion'?member.build.name:getCreature(member.creatureId).name;
const cap=(value:string)=>value[0].toUpperCase()+value.slice(1);

export function TowerTeamMemberCard({member,index,onEdit,disabled=false}:{member:TowerMemberInput;index:number;onEdit?:()=>void;disabled?:boolean}){
 const creature=member.kind==='creature'?getCreature(member.creatureId):null,championId=member.kind==='champion'?member.build.championId:creature!.championId,affinities=member.kind==='champion'?member.build.affinities:creature!.affinities,loadout=member.kind==='champion'?member.build.loadout:creature!.loadout;
 const signature=member.kind==='champion'?effectiveSpell(championId,getSignature(championId).id,affinities):null,access=signature?spellAccess(championId,signature.id,affinities):null;
 return <article className="tp23-member" aria-label={`Character ${index+1}: ${memberName(member)}`}>
  <header><span className="tp23-number" aria-hidden="true">{index+1}</span>{member.kind==='champion'?<PixelChampion id={championId} size={76} paused/>:<CombatCreature creatureId={member.creatureId} size={76}/>}<div><strong>{memberName(member)}</strong><small>{creature?`Lesser ${creature.role}`:getChampion(championId).race}</small><span className="tp23-stat">{creature?.maxHp??8} HP · {creature?.maxFlux??6} Flux</span></div></header>
  <div className="tp23-affinities" aria-label="Element affinities">{Object.entries(affinities).map(([element,points])=><span key={element}><ElementIcon element={element as Element} size={18}/>{cap(element)} <b>{points}</b></span>)}</div>
  <ul className="tp23-kit" aria-label={`Character ${index+1} starting spells`}>{loadout.map(id=><li key={id}><TowerSpellPreview spell={effectiveSpell(championId,id,affinities)}/></li>)}</ul>
  {signature&&access&&<div className="tp23-signature"><TowerSpellPreview spell={signature} note={access.unlocked?'Signature':`Signature · requires ${access.requiredAffinity} ${cap(signature.element)}`}/></div>}
  {creature&&<TowerBondPreview perkId={creature.perkId}/>}
  {onEdit&&<button type="button" disabled={disabled} onClick={onEdit} aria-label={`Change character ${index+1}: ${memberName(member)}`}>Change character</button>}
 </article>;
}

export default function TowerTeamPicker({value,onChange,disabled=false,soloSuggestions=false}:{value:TowerStart;onChange:(next:TowerStart)=>void;disabled?:boolean;soloSuggestions?:boolean}){
 const [editing,setEditing]=useState<0|1|null>(null),[kind,setKind]=useState<'champion'|'creature'>('champion'),[creatureId,setCreatureId]=useState(TOWER_STARTING_CREATURES[0].id),[draft,setDraft]=useState<TowerBuild|null>(null),[error,setError]=useState('');
 const dialog=useRef<HTMLDialogElement|null>(null),trigger=useRef<HTMLElement|null>(null);
 useEffect(()=>{if(editing!==null&&!dialog.current?.open){trigger.current=document.activeElement as HTMLElement;dialog.current?.showModal()}else if(editing===null&&dialog.current?.open){dialog.current.close();trigger.current?.focus()}},[editing]);
 const other=editing===null?null:value.members[1-editing],excluded=other?.kind==='champion'?[other.build.championId]:[];
 function edit(index:0|1){const member=value.members[index],otherMember=value.members[1-index],fallback=CHAMPIONS.find(champion=>otherMember.kind!=='champion'||champion.id!==otherMember.build.championId)!,affinities=allocateAffinityBudget(fallback.id,5);setDraft(member.kind==='champion'?structuredClone(member.build):{championId:fallback.id,name:fallback.name,affinities,loadout:defaultLoadout(fallback.id,affinities)});setCreatureId(member.kind==='creature'?member.creatureId:TOWER_STARTING_CREATURES.find(creature=>otherMember.kind!=='creature'||creature.id!==otherMember.creatureId)!.id);setKind(member.kind);setError('');setEditing(index);}
 function apply(member:TowerMemberInput){if(editing===null)return;try{const members=[...value.members] as [TowerMemberInput,TowerMemberInput];members[editing]=member;onChange(validateTowerStarter({starterId:value.starterId,members}));setEditing(null);setError('')}catch(problem){setError(problem instanceof Error?problem.message:'Choose two different characters.')}}
 function choosePreset(id:string){try{onChange(validateTowerStarter(id));setError('')}catch(problem){setError((problem as Error).message)}}
 return <section className="tp23-picker" aria-label="Choose your two characters">
  <div className={`tp23-presets${soloSuggestions?' tp23-solo-presets':''}`} role="group" aria-label="Suggested teams">{(soloSuggestions?TOWER_SOLO_STARTERS:TOWER_STARTERS).map(starter=>{const selected=JSON.stringify(value.members)===JSON.stringify(validateTowerStarter(starter.id).members);return <button type="button" key={starter.id} aria-pressed={selected} disabled={disabled} onClick={()=>choosePreset(starter.id)} title={`${starter.name}. ${starter.description}`} aria-label={soloSuggestions?starter.name:undefined}>{soloSuggestions?getChampion(starter.heroId).name:starter.name}</button>})}</div>
  <div className="tp23-members">{value.members.map((member,index)=><TowerTeamMemberCard key={`${index}:${memberIdentity(member)}`} member={member} index={index} disabled={disabled} onEdit={()=>edit(index as 0|1)}/>)}</div>
  <p className="tp23-rule">Choose any two different characters.</p>
  <dialog className="t22-dialog tp23-dialog" ref={dialog} aria-label={`Choose character ${(editing??0)+1}`} onCancel={event=>{event.preventDefault();setEditing(null)}}>
   <header><h2>Character {(editing??0)+1}</h2><button type="button" className="t22-close" aria-label="Close character selection" onClick={()=>setEditing(null)}>×</button></header>
   {editing!==null&&<><div className="tp23-type" role="group" aria-label="Character type"><button type="button" aria-pressed={kind==='champion'} onClick={()=>setKind('champion')}>Champion</button><button type="button" aria-pressed={kind==='creature'} onClick={()=>setKind('creature')}>Creature</button></div>{error&&<p className="tp23-error" role="alert">{error}</p>}
    {kind==='champion'&&draft?<TowerCharacterBuilder key={`champion-${editing}`} initial={draft} excludedChampionIds={excluded} onSave={build=>apply({kind:'champion',build})} onCancel={()=>setEditing(null)}/>:<div className="tp23-creature-choice"><div className="tp23-creature-layout"><div className="tp23-creature-catalog" role="group" aria-label="Starting creature">{TOWER_STARTING_CREATURES.map(creature=><button type="button" key={creature.id} aria-pressed={creatureId===creature.id} aria-label={`${creature.name}, ${creature.elements.map(cap).join(' and ')}, ${creature.role}`} disabled={other?.kind==='creature'&&other.creatureId===creature.id} onClick={()=>setCreatureId(creature.id)}><CombatCreature creatureId={creature.id} size={42}/><span><strong>{creature.name}</strong><small>{creature.elements.map(cap).join(' + ')} · {creature.role}</small></span></button>)}</div><TowerTeamMemberCard member={{kind:'creature',creatureId}} index={editing}/></div><div className="t22-dialog-actions"><button type="button" onClick={()=>setEditing(null)}>Cancel</button><button type="button" className="t22-primary" onClick={()=>apply({kind:'creature',creatureId})}>Use creature</button></div></div>}
   </>}
  </dialog>
 </section>;
}
