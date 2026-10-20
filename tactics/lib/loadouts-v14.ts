import {CHAMPIONS,type AffinityAllocation} from './roster-v11.ts';
import {defaultLoadout,repairLoadout} from './spells-v14.ts';
import {defaultLoadout as previousStarter} from './spells-v4.ts';

/** New games adopt affinity unlocks without replacing legal choices from saved custom kits. */
export function readLoadouts(input:unknown,fromV4=false,learnedSignatures:readonly string[]=[],allocations:Readonly<Record<string,AffinityAllocation>>={}):Record<string,string[]> {
  const supplied=input&&typeof input==='object'&&!Array.isArray(input)?input as Record<string,unknown>:{};
  return Object.fromEntries(CHAMPIONS.map(champion=>{
    let kit=defaultLoadout(champion.id,allocations[champion.id],learnedSignatures);
    try {
      const saved=supplied[champion.id];
      if(!fromV4||JSON.stringify(saved)!==JSON.stringify(previousStarter(champion.id)))kit=repairLoadout(champion.id,saved,allocations[champion.id],learnedSignatures);
    }catch{/* Unknown legacy identities fall back individually. */}
    return [champion.id,kit];
  }));
}
