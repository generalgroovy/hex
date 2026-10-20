import type {ReactNode} from 'react';
import {characterPhaseAction,resolutionReadout} from '../../lib/resolution-readout-v14';
import type {ResolutionPhase} from '../../lib/feedback-v14';
import type {Player,SimState} from '../../lib/tactics-v14';
import PixelChampion from './PixelChampion';
import './resolution-panel-v14.css';

type Props={state:SimState;previous?:SimState;player:Player;phase:ResolutionPhase;names:readonly string[];controls?:ReactNode};

export default function ResolutionPanelV14({state,previous,player,phase,names,controls}:Props){
 const readout=resolutionReadout(previous,state);
 return <section className={`tx-resolution-panel is-${phase}`} aria-label="This exchange">
  {readout?<div className="tx-resolution-teams">{([player,1-player] as Player[]).map(owner=><div className={`tx-resolution-team tx-resolution-team-${owner}`} key={owner}>
   <h2><span aria-hidden="true">{owner===0?'●':'◆'}</span>{names[owner]|| (owner===player?'Your team':'Rival')}</h2>
   <ol>{readout.characters.filter(character=>character.owner===owner).map((character,index)=>{const current=characterPhaseAction(character,phase);return <li key={character.id} className={`tx-resolution-character is-${current.tone}`} data-resolution-unit={character.id}>
    <span className="tx-resolution-portrait"><PixelChampion id={character.championId} size={54} paused/><b>{index+1}</b></span>
    <div className="tx-resolution-action"><strong title={character.name}>{character.name}</strong><span title={current.detail}>{current.label}</span>{phase==='settle'&&<small title={character.effects.detail}>{character.effects.label}</small>}</div>
   </li>})}</ol>
  </div>)}</div>:<p className="tx-resolution-unavailable">No recorded actions for this exchange.</p>}
  {phase==='settle'&&readout?.score&&readout.score.some(Boolean)&&<p className="tx-resolution-score">{([player,1-player] as Player[]).map(owner=><span key={owner}>{names[owner]||(owner===player?'You':'Rival')} <b>+{readout.score![owner]}</b></span>)}</p>}
  {controls&&<div className="tx-resolution-controls">{controls}</div>}
 </section>;
}
