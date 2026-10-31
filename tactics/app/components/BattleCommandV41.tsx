"use client";
import type {CSSProperties,ReactNode} from 'react';
import type {Element,Point} from '../../lib/game';
import type {Spell,StatusId,Status} from '../../lib/spells-v20';
import type {TargetImpactPreview} from '../../lib/target-impact-v41';
import {orderReadout,displacementReadouts,compactImpactReadout} from '../../lib/battle-command-v41';
import {spellEffectLabel} from '../../lib/battle-guidance-v16';
import {ELEMENT_STYLE} from '../../lib/presentation';
import {BattleInsight,CombatVitals,StatusChips} from './BattleInsightV24';
import ElementIcon from './ElementIcon';
import SpellFootprint,{SHAPE_NAME} from './SpellFootprint';
import {profileSpell,spellProfileLabel,type SpellModel} from '../../lib/spell-profile-v42';
import {profiledEffectLabel,profiledSpellDescription} from '../../lib/spell-profile-label-v42';
import SpellProfile from './SpellProfileV42';
import './round-explanation-v44.css';

export type BattleCommandSpell={spell:Spell;cost:number;available:boolean;reason?:string;recovery?:number};
export type BattleCommandProps={
 name:string;identity:string;portrait:ReactNode;unit:{hp:number;maxHp:number;flux:number;maxFlux:number;statuses:Partial<Record<StatusId,Status>>;affinities:Partial<Record<Element,number>>};
 spells:BattleCommandSpell[];selectedSpellId?:string;kind:'move'|'cast';movement:number;disabled:boolean;locked?:boolean;
 order?:{move?:Point;cast?:Point;spellId?:string;guard?:boolean};formatPoint:(point:Point)=>string;spellName:(id:string)=>string;
 onInspect:()=>void;onMove:()=>void;onGuard:()=>void;onSpell:(id:string)=>void;onCancelMove:()=>void;onClear:()=>void;onNext:()=>void;
 onUndo:()=>void;onRedo?:()=>void;canUndo:boolean;canRedo?:boolean;canNext:boolean;onCommit:()=>void;commitLabel:string;commitNote:string;
 aim?:Point;areaCount?:number;friendlyNames?:string[];impact?:TargetImpactPreview|null;forecast?:ReactNode;extra?:ReactNode;spellModel?:SpellModel;
};

export function TargetReadout({preview,formatPoint=(point:Point)=>`${point.q}, ${point.r}`}:{preview:TargetImpactPreview;formatPoint?:(point:Point)=>string}){
 return <div className="bc41-impact" aria-label="Known volley effects">
  <details className="bc44-preview-assumptions"><summary className="bc41-conditional">Known volley · if targets stay</summary><p>Uses your current orders and shared allied drafts. Enemy movement and spells can change the result.</p><p>Damage ranges include possible enemy Guard. Recovery is before the health cap. Burn, recoil, drain and closing ground are shown after resolution.</p><p>Displacement assumes the target survives. A blocked landing can change a cast&apos;s reach.</p></details>
  {preview.blocked?<strong className="bc41-warning">Blocked landing · spell may fail</strong>:<>
   {preview.cancelled&&<strong className="bc41-collision">{preview.collisionName??'Elemental collision'} · projectiles meet</strong>}
   {preview.targets.length?<ul>{preview.targets.map(target=><li key={target.id} data-ally={target.ally}>
    <strong>{target.name}{target.ally?' · ally':''}</strong><span>
     {target.damage.max>0&&<b className="bc41-damage">{target.damage.min===target.damage.max?target.damage.max:`${target.damage.min}–${target.damage.max}`} spell dmg</b>}
     {target.healing>0&&<b className="bc41-heal">+{target.healing} recovery</b>}
     {target.statuses.length>0&&<span>{target.statuses.join(' · ')}</span>}
     {!target.damage.max&&!target.healing&&!target.statuses.length&&!target.displacement&&<span>No spell damage</span>}
     {target.displacement&&<span className="bc42-force" aria-label={`${target.name} displacement if still standing`}><small>If still standing</small>{displacementReadouts(target.displacement,formatPoint).map(branch=><span key={branch.label}><b>{branch.label}</b> {branch.text}</span>)}</span>}
    </span>
   </li>)}</ul>:<span>No fighters in this area</span>}
   {!!preview.fieldChanges?.length&&<details className="bc44-field-changes"><summary>Terrain · {preview.fieldChanges[0].before} → {preview.fieldChanges[0].after}{preview.fieldChanges.length>1?` · +${preview.fieldChanges.length-1} changes`:''}</summary><ul>{preview.fieldChanges.map((field,index)=><li key={index}><strong>{field.before} → {field.after} · {field.count} hex{field.count===1?'':'es'}</strong><span>{field.rule}</span>{field.before!=='Ground'&&<small>Replaces: {field.previousRule}</small>}{field.duration&&<small>{field.duration} exchanges · either team</small>}</li>)}</ul></details>}
  </>}
 </div>;
}

export default function BattleCommandV41(props:BattleCommandProps){
 const choices=props.spells.map(choice=>({...choice,spell:profileSpell(choice.spell,props.spellModel)}));
 const selected=choices.find(choice=>choice.spell.id===props.selectedSpellId),spell=selected?.spell;
 const readout=orderReadout(props.order,props.spellName,props.formatPoint),hasOrder=!!(props.order?.move||props.order?.cast||props.order?.guard);
 const cannotMove=props.movement===0;
 const compactTitle=props.locked?'Orders locked':props.kind==='move'?cannotMove?'Cannot move this round':`Move · ${props.movement} effort`:spell?.name??'Choose a spell';
 const compactDetail=props.locked?readout.action:props.kind==='move'?cannotMove?'Choose a spell or Guard.':hasOrder?`${readout.movement} · ${readout.action}`:'Choose a teal landing, then aim a spell':!selected?.available?selected?.reason??'Unavailable this turn':props.friendlyNames?.length&&!props.impact?.cancelled?`Friendly fire · ${props.friendlyNames.join(', ')}`:compactImpactReadout(props.impact)??(spell?profiledEffectLabel(spell):'Choose a spell');
 return <section className="bc41-command" aria-label={`${props.name} orders`}>
  <div className="bc41-fighter">
   <button className="bc41-identity" onClick={props.onInspect} aria-label={`Inspect ${props.name}`}>
    <span className="bc41-portrait">{props.portrait}</span><span><strong>{props.name}</strong><small>{props.identity} <span aria-hidden="true">↗</span></small><CombatVitals unit={props.unit}/></span>
   </button>
   <div className="bc41-affinities" aria-label="Element affinities">{Object.entries(props.unit.affinities).filter(([,rank])=>rank&&rank>0).map(([element,rank])=><span key={element}><ElementIcon element={element as Element} size={17} label={`${element} affinity ${rank}`}/><b>{rank}</b></span>)}</div>
  </div>
  <StatusChips statuses={props.unit.statuses} label={`${props.name} conditions`}/>
  <div className="bc41-actions">
   <button disabled={props.disabled} aria-pressed={props.kind==='move'} onClick={props.onMove}><b>Move</b><small>{props.movement} effort</small></button>
   <button disabled={props.disabled} aria-pressed={!!props.order?.guard} onClick={props.onGuard}><b>Guard</b><small>Recover · resist</small></button>
  </div>
  <div className="s18-spells bc41-spells" data-count={choices.length} aria-label="Spells">{choices.map(({spell,cost,available,reason,recovery},index)=><button type="button" key={spell.id} disabled={props.disabled} aria-pressed={props.kind==='cast'&&props.selectedSpellId===spell.id} className={available?'':'is-unready'} style={{'--element':ELEMENT_STYLE[spell.element].color} as CSSProperties} aria-label={`${index+1}. ${spell.name}. ${cost} Flux. ${spell.range?`${spell.range} reach`:'Self'}. ${SHAPE_NAME[spell.shape]} area. ${profiledEffectLabel(spell)}. ${reason??''}`} title={`${spell.name} · ${SHAPE_NAME[spell.shape]} area · ${cost} Flux · ${spell.range?`${spell.range} reach`:'Self'}`} onClick={()=>props.onSpell(spell.id)}>
   <ElementIcon element={spell.element} spell={spell} size={22}/><strong>{spell.name}</strong><SpellFootprint shape={spell.shape}/><small>{recovery?`${recovery}r recovery`:`${cost} Flux`} · {spell.range?`${spell.range} reach`:'Self'}</small><span className="bc41-spell-effect">{spellProfileLabel(spell)||spellEffectLabel(spell)}</span>
  </button>)}</div>
  <div className="bc41-mobile-preview">
   <BattleInsight className={props.kind==='cast'&&(!selected?.available||props.friendlyNames?.length&&!props.impact?.cancelled)?'bc41-compact-warning':''} ariaLabel={`${compactTitle}. ${compactDetail}. Inspect action and queued order.`} title={compactTitle} label={<span><strong>{compactTitle}{props.kind==='cast'&&props.aim?` · ${props.formatPoint(props.aim)}`:''}<b aria-hidden="true">ⓘ</b></strong><small>{compactDetail}</small></span>}>
    {props.kind==='cast'&&spell?<><p>{selected?.cost} Flux · {spell.range?`${spell.range} reach`:'Self'} · {spellProfileLabel(spell)||SHAPE_NAME[spell.shape]}</p><SpellProfile spell={spell}/><p>{profiledSpellDescription(spell)}</p>{!selected?.available&&<p className="bc41-warning">{selected?.reason}</p>}{props.friendlyNames?.length&&!props.impact?.cancelled?<p className="bc41-warning">Friendly fire · {props.friendlyNames.join(', ')}</p>:null}{props.impact&&<TargetReadout preview={props.impact} formatPoint={props.formatPoint}/>}</>:<p>{cannotMove?`${props.unit.statuses.rooted?'Rooted prevents movement this round.':'No movement available this round.'} Choose a spell or Guard.`:'Choose a teal landing. Movement happens before every fighter casts.'}</p>}
    {props.forecast}
    {hasOrder&&<><p><strong>{readout.movement}</strong><br/>{readout.action}</p><div className="bc41-insight-order-tools">{props.order?.move&&<button disabled={props.disabled} onClick={props.onCancelMove}>Cancel move</button>}<button disabled={props.disabled} onClick={props.onClear}>Clear order</button></div></>}
   </BattleInsight>
  </div>
  <div className="bc41-preview s18-aim-summary" data-kind={props.kind} aria-live="polite">
   {props.locked?<strong>Orders locked · waiting for players</strong>:props.kind==='move'?<><strong>{cannotMove?'Cannot move this round':'Choose a landing'}</strong><small>{cannotMove?'Choose a spell or Guard.':'Teal hexes · then aim your spell'}</small></>:spell&&<>
    <div className="bc41-spell-heading"><SpellFootprint shape={spell.shape}/><strong>{spell.name}</strong><small>{SHAPE_NAME[spell.shape]}</small></div>
    <SpellProfile spell={spell}/>
    <small className="bc41-selected-effect">{profiledEffectLabel(spell)}</small>
    {!selected?.available?<strong className="bc41-warning">{selected?.reason??'Unavailable this turn'}</strong>:<small>{props.aim?`${props.areaCount??0} hexes · ${props.formatPoint(props.aim)}`:'Choose a target · gold reach, striped area'}</small>}
    {props.friendlyNames?.length&&!props.impact?.cancelled?<strong className="bc41-warning">Friendly fire · {props.friendlyNames.join(', ')}</strong>:null}
    {props.impact&&<TargetReadout preview={props.impact} formatPoint={props.formatPoint}/>}
   </>}
   {props.forecast}
  </div>
  {hasOrder&&<div className="bc41-queued" data-ready={readout.queued} aria-label="Queued order"><span>{readout.movement}</span><strong>{readout.action}</strong></div>}
  {props.extra}
  {hasOrder&&<div className="bc41-order-tools">{props.order?.move&&<button disabled={props.disabled} onClick={props.onCancelMove}>Cancel move</button>}<button disabled={props.disabled} onClick={props.onClear}>Clear order</button></div>}
  <div className="bc41-footer s18-command-dock">
   <div className="bc41-history"><button disabled={props.disabled||!props.canUndo} onClick={props.onUndo} aria-label="Undo order" title="Undo · U">↶</button>{props.onRedo&&<button disabled={props.disabled||!props.canRedo} onClick={props.onRedo} aria-label="Redo order" title="Redo">↷</button>}</div>
   {props.canNext&&<button disabled={props.disabled} className="bc41-next" onClick={props.onNext}>Next fighter →</button>}
   <button className="s18-primary bc41-commit" disabled={props.disabled} onClick={props.onCommit}>{props.commitLabel}<small>{props.commitNote}</small></button>
  </div>
 </section>;
}

export function BattlePhaseHeader({round,context,phase,planned,total,enemiesOpen,onToggleEnemies,opponentsLabel='Enemies',extra}:{round:number;context:string;phase:'planning'|'move'|'cast'|'impact'|'settle';planned:number;total:number;enemiesOpen:boolean;onToggleEnemies:()=>void;opponentsLabel?:string;extra?:ReactNode}){
 const phases=[['planning','Plan'],['move','Move'],['cast','Cast'],['impact','Effects'],['settle','Review']] as const;
 return <header className="bc41-phase-header">
  <div className="bc41-round"><strong>Round {round}</strong><span>{context}</span></div>
  <ol className="bc41-phases" aria-label="Turn phases">{phases.map(([id,label],index)=><li key={id} aria-current={phase===id?'step':undefined}><span aria-hidden="true">{index+1}</span>{label}</li>)}</ol>
  <div className="bc41-phase-tools">{phase==='planning'&&<span className="bc41-ready">{planned}/{total} ready</span>}{extra}<button className="s18-enemy-toggle" aria-expanded={enemiesOpen} onClick={onToggleEnemies}>{opponentsLabel}</button></div>
 </header>;
}
