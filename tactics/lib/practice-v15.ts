import {defaultLoadout} from './spells-v15.ts';
import type {AffinityAllocation} from './roster-v11.ts';
import {chooseAIPlan,type Player,type SimState,type TeamPlan} from './tactics-v15.ts';

/** Practice uses the same fixed pre-match affinities and spell access rules. */
export function practiceLoadouts(ids: string[],affinities:Readonly<Record<string,AffinityAllocation>>={},learnedSignatures:readonly string[]=[]): Record<string, string[]> {
  return Object.fromEntries(ids.map(id => [id, defaultLoadout(id,affinities[id],learnedSignatures)]));
}


/** Practice and story share the elimination AI: close to useful spell range,
 * coordinate a volley, and treat springs only as optional Flux recovery.
 * The policy reads the public state and never either team's sealed orders. */
export function choosePracticePlan(state:SimState,player:Player):TeamPlan {
  return chooseAIPlan(state,player);
}
