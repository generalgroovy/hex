import type {Spell} from '../../lib/spells';

const CELLS:Record<Spell['shape'],[number,number][]>= {
  hex:[[0,0]], line:[[-1,0],[0,0],[1,0]], burst:[[0,0],[1,0],[0,1],[-1,1],[-1,0],[0,-1],[1,-1]],
  ring:[[1,0],[0,1],[-1,1],[-1,0],[0,-1],[1,-1]], sweep:[[0,0],[-1,1],[0,-1]], wall:[[0,-1],[0,0],[0,1]],
};
export const SHAPE_NAME:Record<Spell['shape'],string>={hex:'Single',line:'Lane',burst:'Burst',ring:'Ring',sweep:'Sweep',wall:'Wall'};

/** A compact shape key; authoritative target-specific coverage is shown on the battlefield. */
export default function SpellFootprint({shape}:{shape:Spell['shape']}) {
  return <svg className="tx-footprint-icon" width="32" height="26" viewBox="-20 -17 40 34" aria-hidden="true" focusable="false">
    {CELLS[shape].map(([q,r])=><polygon key={`${q},${r}`} points="0,-5 4.3,-2.5 4.3,2.5 0,5 -4.3,2.5 -4.3,-2.5" transform={`translate(${q*9+r*4.5},${r*8})`} fill="currentColor" fillOpacity=".22" stroke="currentColor" strokeWidth="1.3"/>)}
  </svg>;
}
