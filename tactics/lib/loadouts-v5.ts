import {CHAMPIONS} from './roster.ts';
import {defaultLoadout,validateLoadout} from './spells-v5.ts';
import {defaultLoadout as previousStarter} from './spells-v4.ts';

/** Upgrade untouched starters, retaining every valid custom kit and the old storage namespace. */
export function readLoadouts(input:unknown,fromV4=false):Record<string,string[]> {
  const supplied=input&&typeof input==='object'&&!Array.isArray(input)?input as Record<string,unknown>:{};
  return Object.fromEntries(CHAMPIONS.map(champion=>{
    let kit=defaultLoadout(champion.id);
    try {
      const saved=validateLoadout(champion.id,supplied[champion.id]);
      if(!fromV4||JSON.stringify(saved)!==JSON.stringify(previousStarter(champion.id)))kit=saved;
    }catch{/* Missing or damaged entries fall back individually. */}
    return [champion.id,kit];
  }));
}
