import type {EndgameForecast} from '../../lib/endgame-v18';
import type {Point} from '../../lib/tactics-v16';
import {endgameCellState} from '../../lib/endgame-presentation-v18';
import './endgame-terrain-v18.css';

const outline='0,-30 44,-15 44,15 0,30 -44,15 -44,-15';
export function EndgameTile({zone,point}:{zone?:EndgameForecast;point:Point}) {
  const state=endgameCellState(zone,point);
  if(state==='safe')return null;
  return <g className={`px18-endgame-tile is-${state}`} data-endgame-cell={state} data-endgame-coordinate={`${point.q},${point.r}`} aria-hidden="true" pointerEvents="none" shapeRendering="crispEdges">
    <polygon points={outline}/>
    {state==='unsafe'?<><path className="px18-fault-shadow" d="M-34-4h10V2h12v6H-2V2H8v-8H23v-6h10M-12 8v8h-9M8-6v-7H0M-2 2v-7H-10"/><path className="px18-fault-edge" d="M-34-6h10V0h12v6H-2V0H8v-8H23v-6h10"/></>:<path className="px18-closing-marks" d="M-34 3h9v-4h6M13-11h8v-4h7M-3 18h9v-4h6"/>}
  </g>;
}
export function EndgameBorders({current,next}:{current:string;next:string}) {
  return <g className="px18-endgame-borders" aria-hidden="true" pointerEvents="none">
    {current&&<g data-endgame-boundary="current"><path className="px18-boundary-shadow" d={current}/><path className="px18-current-boundary" d={current}/></g>}
    {next&&<g data-endgame-boundary="next"><path className="px18-boundary-shadow is-next" d={next}/><path className="px18-next-boundary" d={next}/></g>}
  </g>;
}
