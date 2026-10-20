import {MAX_ROUNDS,POINTS_TO_WIN,type SimState} from '../../lib/tactics-v14';
import type {Player} from '../../lib/game';
import './battle-result-v13.css';

type Props={state:SimState;player:Player;names:string[];busy:boolean;waiting:boolean;onRematch:()=>void;onCamp:()=>void;story?:{spell:string;won:boolean;collected:boolean;atLimit:boolean}};
export default function BattleResultV14({state,player,names,busy,waiting,onRematch,onCamp,story}:Props){
 const winner=state.winner;
 if(winner===null)return null;
 const title=winner==='draw'?'Draw':winner===player?'Victory':'Defeat';
 const reason=winner==='draw'?`Level scores after ${MAX_ROUNDS} rounds.`:state.round>=MAX_ROUNDS?`${names[winner]} finished ahead after ${MAX_ROUNDS} rounds.`:`${names[winner]} finished ahead with at least ${POINTS_TO_WIN} points.`;
 return <section className={`tx-match-result ${winner===player?'is-victory':''}`} aria-label="Match result">
  <p className="tx-result-round">Round {state.round} complete</p><h2>{title}</h2>
  <div className="tx-final-scores">{[player,1-player].map(owner=><div key={owner}><span>{names[owner]}</span><strong>{state.scores[owner]}</strong></div>)}</div>
  <p>{reason}</p>
  {story&&<div className="tx-result-reward"><strong>{story.won?`${story.spell} learned`:`Challenge: ${story.spell}`}</strong><p>{story.won?story.collected?'Reward already collected.':story.atLimit?'Your roster has reached its affinity limit.':'+1 affinity for every character. Assign it in camp.':'Win this encounter to learn the signature and earn affinity.'}</p></div>}
  <button className="tx-primary" disabled={busy||waiting} onClick={onRematch}>{waiting?'Waiting for your friend…':'Play again'}</button>
  <button onClick={onCamp}>{story?'Return to story':'Change team'}</button>
 </section>;
}
