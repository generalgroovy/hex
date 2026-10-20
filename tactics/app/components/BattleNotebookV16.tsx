"use client";
import {useEffect,useRef,useState} from 'react';
import {getChampion} from '../../lib/roster-v13';
import {effectiveSpell,getSpell,spellScalingSummary} from '../../lib/spells-v16';
import {STATUS_DEFINITIONS,castAvailability,type SimState,type TeamPlan,type Player} from '../../lib/tactics-v16';
import type {PlanningForecast} from '../../lib/planning-forecast-v16';
import type {CombatOutlook} from '../../lib/combat-outlook-v16';
import type {PlanInsight} from '../../lib/plan-insights-v16';
import {formatTile} from '../../lib/board-labels-v9';
import {spellEffectLabel} from '../../lib/battle-guidance-v16';
import {spellSurfaceHint} from '../../lib/element-personality-v16';
import CombinationGuide from './CombinationGuideV16';
import ElementIcon from './ElementIcon';
import PixelChampion from './PixelChampion';

export type NotebookTab='spell'|'forecast'|'orders'|'rivals'|'log'|'elements';
type Props={open:NotebookTab|null;onClose:()=>void;game:SimState;planningGame:SimState;player:Player;plan:TeamPlan;selected:string|null;spellId?:string;forecast:PlanningForecast|null;combat:CombatOutlook[];insights:PlanInsight[];onInspect:(id:string)=>void;onReset:(id:string)=>void;onHold:(id:string)=>void;canPlan:boolean;onCopyMap:()=>void;onInvite?:()=>void;message?:string};
const TABS:readonly [NotebookTab,string][]=[['spell','Spell'],['forecast','Forecast'],['orders','Orders'],['rivals','Rivals'],['log','Log'],['elements','Mix']];

/** Reference information is deliberately requested. It never crowds the map or
 * changes an order, and uses only public positions and this player's own plan. */
export default function BattleNotebookV16(props:Props){
 const {open,onClose,game,planningGame,player,plan,selected,spellId,forecast,combat,insights,onInspect,onReset,canPlan}=props;
 const dialog=useRef<HTMLDialogElement>(null),[tab,setTab]=useState<NotebookTab>('spell'),[logPage,setLogPage]=useState(0),[forecastFocus,setForecastFocus]=useState('damage');
 useEffect(()=>{if(open){setTab(open);setLogPage(0);if(!dialog.current?.open)dialog.current?.showModal()}else dialog.current?.close()},[open]);
 const unit=planningGame.units.find(entry=>entry.id===selected),spell=unit&&spellId?effectiveSpell(unit.championId,spellId,unit.affinities):null;
 const log=game.log.slice().reverse(),pages=Math.max(1,Math.ceil(log.length/6)),page=Math.min(logPage,pages-1);
 return <dialog ref={dialog} className="tx-dialog tx-notebook" aria-label="Battle reference" onCancel={onClose} onClose={onClose}>
  <header className="tx-dialog-top"><h2>Battle reference</h2><button aria-label="Close battle reference" onClick={onClose}>×</button></header>
  <nav className="tx-notebook-tabs" aria-label="Battle reference sections">{TABS.map(([id,label])=><button key={id} aria-pressed={tab===id} onClick={()=>setTab(id)}>{label}</button>)}</nav>
  <div className="tx-notebook-content">
   {tab==='spell'&&(spell&&unit?<section className="tx-notebook-spell"><h3><ElementIcon element={spell.element} spell={spell} size={24}/>{spell.name}</h3><p className="tx-notebook-stats">{castAvailability(planningGame,unit.id,spell.id).cost} Flux · reach {spell.range} · {spell.shape} · {spell.cooldown} round recovery</p><strong>{spellEffectLabel(spell)}</strong><p>{spell.description}</p><p>{spellSurfaceHint(spell)}</p><small>{spellScalingSummary(unit.championId,spell.id,unit.affinities)}</small></section>:<p>Select a character and a spell to inspect its effects.</p>)}
   {tab==='forecast'&&<section><label className="tx-filter-select">Preview<select value={forecastFocus==='damage'||forecast?.groups.some(group=>group.id===forecastFocus)?forecastFocus:'damage'} onChange={event=>setForecastFocus(event.target.value)}><option value="damage">If enemies stay</option>{forecast?.groups.map(group=><option value={group.id} key={group.id}>{group.name} · {group.count} hexes</option>)}</select></label>{forecastFocus==='damage'||!forecast?.groups.some(group=>group.id===forecastFocus)?<><div className="tx-notebook-forecast"><h4>If they stay</h4>{combat.length?combat.map(target=><p key={target.id}><b>{target.name}{target.ally?' · ally':''}</b> {target.damage} damage{target.damage!==target.guardedDamage?` (${target.guardedDamage} with Guard)`:''}{target.addedDamage<0?` · reduces allied volley by ${Math.abs(target.addedDamage)}`:''}</p>):<p>Aim a spell at a character to compare damage.</p>}</div><small>Enemy movement, crossing spells and healing can change the outcome.</small></>:forecast?.groups.filter(group=>group.id===forecastFocus).map(group=><div className="tx-notebook-forecast" key={group.id}><h4>{group.name} · {group.count} hexes</h4><p>{group.shortRule}</p><small>Rival spells may change this field.</small></div>)}</section>}
   {tab==='orders'&&<section aria-label="Your team orders"><ol className="tx-notebook-orders">{game.units.filter(entry=>entry.owner===player).map(entry=>{const order=plan.orders.find(item=>item.unitId===entry.id);return <li key={entry.id}><PixelChampion id={entry.championId} size={60} paused/><div><button className="tx-order-character" onClick={()=>onInspect(entry.id)} aria-label={`Inspect ${getChampion(entry.championId).name}`}><strong>{getChampion(entry.championId).name}</strong></button><p>{entry.hp<=0?'Defeated':`${order?.move?`Move ${formatTile(order.move)}`:'Stay'} → ${order?.cast&&order.spellId?`${getSpell(order.spellId).name} ${formatTile(order.cast)}`:'Guard'}`}</p><small>{Object.entries(entry.statuses).map(([id,status])=>`${STATUS_DEFINITIONS.find(item=>item.id===id)?.name||id} ${status?.turns}`).join(' · ')||`${entry.hp} HP · ${entry.flux} Flux`}</small></div><div className="tx-order-edits">{order?.move&&<button disabled={!canPlan} onClick={()=>props.onHold(entry.id)} aria-label={`Hold ${getChampion(entry.championId).name} in place; keep its spell`}>Hold</button>}<button disabled={!canPlan||!order} onClick={()=>onReset(entry.id)} aria-label={`Reset ${getChampion(entry.championId).name}'s orders`}>Reset</button></div></li>})}</ol>{insights.length>0&&<div className="tx-notebook-risks"><h4>Watch for</h4>{insights.map(item=><p key={item.id}>{item.text}</p>)}</div>}</section>}
   {tab==='rivals'&&<section className="tx-notebook-rivals" aria-label="Rival team">{game.units.filter(entry=>entry.owner!==player).map(entry=><button key={entry.id} onClick={()=>onInspect(entry.id)}><PixelChampion id={entry.championId} size={76} paused/><span><strong>{getChampion(entry.championId).name}</strong><small>{getChampion(entry.championId).race} · {entry.hp<=0?'Defeated':`${entry.hp}/${entry.maxHp} HP · ${entry.flux} Flux`}</small><small>View affinities and spells →</small></span></button>)}</section>}
   {tab==='log'&&<section><ol className="tx-notebook-log">{log.slice(page*6,page*6+6).map((line,index)=><li key={`${page}-${index}`}>{line}</li>)}</ol>{!log.length&&<p>No exchanges yet.</p>}<nav className="tx-pagination" aria-label="Battle log pages"><button disabled={page===0} onClick={()=>setLogPage(page-1)}>Newer</button><span>{page+1} / {pages}</span><button disabled={page===pages-1} onClick={()=>setLogPage(page+1)}>Older</button></nav></section>}
   {tab==='elements'&&<CombinationGuide/>}
  </div>
  {props.message&&<p className="tx-notebook-message" role="status">{props.message}</p>}
  <footer className="tx-notebook-footer"><button onClick={props.onCopyMap}>Copy map link</button>{props.onInvite&&<button onClick={props.onInvite}>Copy invitation</button>}</footer>
 </dialog>;
}
