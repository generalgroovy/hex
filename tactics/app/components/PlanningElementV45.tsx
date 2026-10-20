import type {CSSProperties} from 'react';
import {fieldCombination,isIce,type SimCell} from '../../lib/tactics-v16';
import {reactionPresentation} from '../../lib/reaction-presentation-v44';
import './planning-element-v45.css';
const art={
 air:['M-30 9h12v-4h10M14-12h10v4h7','M-24 7h15V3H1M18-10h12','M-17 5H0V1H9M25-8h8'],
 light:['M-26 5h6m-3-3v6M22-13h4','M-27 5h8m-4-4v8M23-14v6m-3-3h6','M-25 5h4M24-12v3'],
 dark:['M-30 0h6v3h8M20-14h7v3','M-27 3h7v3h8M22-11h7v3','M-24 6h8v3h8M24-8h7v3'],
 earth:['M-30 7h3M24-9h3M-4 16h3','M-30 5h3M23-11h3M-3 14h3','M-29 3h2M22-13h2M-2 12h2'],
 water:['M-31 9h13M12-12h10','M-28 7h15M16-10h11','M-24 5h14M20-8h12'],
};
/** Material marks stay at the outer ground plane, clear of feet and aim marks.
 * Each cel is separately drawn: no stretching or rocking a finished sprite. */
export default function PlanningElementV45({cell}:{cell:SimCell}){
 if(isIce(cell))return null;
 const compound=fieldCombination(cell),kind=compound&&compound.elements.length>1?reactionPresentation(compound.elements).material:cell.terrain;
 if(!(kind in art))return null;
 const material=kind as keyof typeof art,delay=-Math.abs(cell.q*17+cell.r*31)%13*.23;
 return <g className={`px45-planning-life is-${material}`} data-planning-material={material} style={{'--life-delay':`${delay}s`} as CSSProperties} shapeRendering="crispEdges" pointerEvents="none" aria-hidden="true">
  {art[material].map((path,index)=><path key={index} className={`px45-material-cel is-${index}`} d={path}/>)}
 </g>;
}
