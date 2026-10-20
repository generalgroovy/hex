"use client";

import {getChampion,affinityTotal,type AffinityAllocation} from '../../lib/roster-v13';
import {ELEMENT_BRANCHES} from '../../lib/spells-v14';
import {nextAffinityStep} from '../../lib/affinity-preview-v14';
import type {Element} from '../../lib/game';
import ElementIcon from './ElementIcon';
import './affinity-progression.css';

export type AffinityTrainingProps={championId:string;allocation:AffinityAllocation;budget:number;onChange:(allocation:AffinityAllocation)=>void;disabled?:boolean};
const ELEMENTS:Element[]=['fire','water','earth','air','light','dark'];
const title=(word:string)=>word.charAt(0).toUpperCase()+word.slice(1);

export default function AffinityTraining({championId,allocation,budget,onChange,disabled=false}:AffinityTrainingProps){
  const champion=getChampion(championId),spent=affinityTotal(allocation),unspent=Math.max(0,budget-spent),elements=Object.keys(allocation).length;
  const change=(element:Element,delta:number)=>{
    const next={...allocation},level=(allocation[element]??0)+delta;
    if(level>0)next[element]=level;else delete next[element];
    onChange(next);
  };
  return <section className="affinity-training" aria-label={`Train ${champion.name}'s affinities`}>
    <div className="affinity-training-heading"><h3>{champion.name} · Affinity</h3><span role="status" aria-live="polite"><strong>{unspent}</strong> unspent · {spent} / {budget}</span></div>
    <p className="affinity-training-rule">Reassign earned points before battle. Starting affinities stay fixed; at most 3 elements.</p>
    <div className="affinity-training-grid">
      {ELEMENTS.map(element=>{
        const rank=allocation[element]??0,floor=champion.affinities[element]??0,full=rank===6,blockedElement=rank===0&&elements>=3;
        const next=nextAffinityStep(element,rank),effect=next?.effect??'Maximum level';
        return <div className={`affinity-training-element${rank?' is-affinity':''}`} key={element}>
          <div className="affinity-training-label"><ElementIcon element={element} size={22}/><strong>{title(element)}</strong>{rank>=3&&<small>{ELEMENT_BRANCHES[element]}</small>}</div>
          <div className="affinity-training-controls"><button type="button" disabled={disabled||rank<=floor} aria-label={`Reduce ${title(element)} affinity for ${champion.name}`} title={rank<=floor?'Starting affinity stays fixed':'Return one earned point'} onClick={()=>change(element,-1)}>−</button><output aria-label={`${title(element)} affinity`}>{rank}<small> / 6</small></output><button type="button" disabled={disabled||!unspent||full||blockedElement} aria-label={`Increase ${title(element)} affinity for ${champion.name}`} title={full?'Maximum level':blockedElement?'At most 3 elements':!unspent?'Win a new story encounter to earn affinity':effect} onClick={()=>change(element,1)}>+</button></div>
          <p>{full?'Maximum level':blockedElement?'Three elements already chosen':<>At {next!.rank}: {next!.spells}</>}</p>
          {!full&&!blockedElement&&<small className="affinity-next-effect">{effect}</small>}
        </div>;
      })}
    </div>
  </section>;
}
