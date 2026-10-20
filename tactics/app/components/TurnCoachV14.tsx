"use client";
import {turnGuidance,SHORT_TURN_GUIDANCE} from '../../lib/battle-guidance-v14';
import type {SimState,TeamPlan,Player} from '../../lib/tactics-v14';
import '../experience-v13.css';

export type TurnCoachV14Props={state:SimState;player:Player;plan:TeamPlan;selected:string|null;previous?:SimState;hidden?:boolean;onDismiss?:()=>void};
export default function TurnCoachV14({state,player,plan,selected,previous,hidden=false,onDismiss}:TurnCoachV14Props){
  const guidance=turnGuidance(state,player,plan,selected,previous);
  if(hidden||!guidance)return null;
  return <aside className="tx-turn-coach" aria-label="Turn guidance"><div aria-live="polite"><span className="tx-coach-full"><strong>{guidance.title}</strong> {guidance.text}</span><span className="tx-coach-short">{SHORT_TURN_GUIDANCE[guidance.id]}</span></div>{onDismiss&&<button type="button" aria-label="Hide turn guidance" onClick={onDismiss}>×</button>}</aside>;
}
