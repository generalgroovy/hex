import {roundOutcomes,compactEvents,phaseLedger} from '../../lib/battle-experience-v20';
import type {SimState} from '../../lib/tactics-v20';
import {getSpell} from '../../lib/spells-v20';
import type {ResolutionPhase} from '../../lib/feedback-v16';
import {actorConsequenceEvents,consequenceExplanation,prioritizedPhaseEvents} from '../../lib/round-explanation-v44';
import './round-explanation-v44.css';

const sideName=(owner:number)=>owner===0?'Your party':'Enemy';
function SideBadge({owner}:{owner:number}){return <span className="c20-side-badge" data-side={owner===0?'ally':'enemy'}> {sideName(owner)}</span>}
/** Names can repeat across parties; use the actual actor's ownership without
 * changing the saved event stream or attributing shared field events to a side. */
function attributedEvents(state:SimState,phase:ResolutionPhase,highlights=false){
 const actors=new Map(state.units.map(unit=>[unit.id,unit]));
 const ledger=phaseLedger(state,phase);
 return compactEvents((highlights?prioritizedPhaseEvents(ledger):ledger).map(event=>{
  const source=String(event.cause)==='link'?event.participants?.[0]:event.unitId;
  const actor=source?actors.get(source):undefined;
  return actor?{...event,text:`${sideName(actor.owner)} · ${event.text}`}:event;
 }));
}

export function OutcomeCards({previous,state,onInspect,unitIds}:{previous:SimState;state:SimState;onInspect:(id:string)=>void;unitIds?:readonly string[]}){
 return <div className="c20-outcomes" aria-label="Changes this exchange">{roundOutcomes(previous,state).filter(outcome=>!unitIds||unitIds.includes(outcome.id)).map(outcome=><button key={outcome.id} data-side={outcome.owner===0?'ally':'enemy'} onClick={()=>onInspect(outcome.id)} aria-label={[`${sideName(outcome.owner)} · ${outcome.name}`,outcome.defeated?'Defeated':`${outcome.hpBefore} → ${outcome.hpAfter} HP`,`${outcome.fluxBefore} → ${outcome.fluxAfter} Flux`,...outcome.changes].join('. ')} title={[`${outcome.hpBefore} → ${outcome.hpAfter} HP`,`${outcome.fluxBefore} → ${outcome.fluxAfter} Flux`,...outcome.changes].join(' · ')}><strong>{outcome.name}<SideBadge owner={outcome.owner}/></strong><span>{outcome.defeated?'Defeated':`${outcome.hpBefore} → ${outcome.hpAfter} HP`}</span><small>{outcome.fluxDelta?`${outcome.fluxDelta>0?'+':''}${outcome.fluxDelta} Flux`:outcome.changes[0]??'No resource change'}{outcome.fluxDelta&&outcome.changes.length?` · ${outcome.changes.length} status changes`:''}</small></button>)}</div>
}
export function PhaseHighlights({state,phase}:{state:SimState;phase:ResolutionPhase}){
 const events=attributedEvents(state,phase,true);return <div className="s18-event-list c20-phase-events" aria-live="polite">{events.slice(0,3).map((text,index)=><p key={index}>{text}</p>)}{events.length>3&&<small>{events.length-3} more in the round report</small>}</div>
}
function CauseDetails({state,id}:{state:SimState;id:string}){
 const events=actorConsequenceEvents(state,id);
 return events.length?<details className="c44-causes"><summary>Why?</summary><ul>{events.map((event,index)=><li key={index}>{consequenceExplanation(state,event).map((line,i)=><span key={i}>{line}</span>)}</li>)}</ul></details>:null;
}
export default function CampaignReview({previous,state,learned=[]}:{previous?:SimState;state:SimState;learned?:string[]}){
 return <div className="c20-report">{previous&&<><table><caption>Round {previous.round} · actual changes</caption><thead><tr><th scope="col">Character</th><th scope="col">HP / causes</th><th scope="col">Flux</th><th scope="col">Status changes</th></tr></thead><tbody>{roundOutcomes(previous,state).map(row=><tr key={row.id}><th scope="row">{row.name}<SideBadge owner={row.owner}/></th><td data-label="HP / causes">{row.hpBefore} → {row.hpAfter}{row.defeated?' · defeated':''}<CauseDetails state={state} id={row.id}/></td><td data-label="Flux">{row.fluxBefore} → {row.fluxAfter}</td><td data-label="Status changes">{row.changes.join(' · ')||'—'}</td></tr>)}</tbody></table><p className="c44-net-note">Damage and healing resolve together. HP shows the final result after the health cap.</p></>}{learned.length>0&&<section><h3>Spells learned</h3><p>{learned.map(id=>getSpell(id).name).join(' · ')}</p><p>Knowledge is kept even if the rest of this battle is lost.</p></section>}{(['move','cast','impact','settle'] as const).map(phase=>{const events=attributedEvents(state,phase);return events.length?<section key={phase}><h3>{{move:'Movement',cast:'Casting',impact:'Effects',settle:'Recovery'}[phase]}</h3><ol>{events.map((text,index)=><li key={index}>{text}</li>)}</ol></section>:null})}</div>
}
