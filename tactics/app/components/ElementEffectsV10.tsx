import type {CSSProperties} from 'react';
import type {Element} from '../../lib/game';
import {isIce,isFlooded,type SimCell} from '../../lib/tactics-v10';
import {PHASE_MS} from '../../lib/feedback-v10';
import './element-motion-v9.css';

export const PROJECTILE_ANTICIPATION_MS=120;
export const PROJECTILE_TRAVEL_MS=PHASE_MS.impact-PHASE_MS.cast-PROJECTILE_ANTICIPATION_MS;
type ScreenPoint={x:number;y:number};
/** A single head and short trail follow the same cast geometry, arriving on the impact clock. */
export function ElementProjectile({from,to,element,shape='hex',branch,delayMs=PHASE_MS.cast}:{from:ScreenPoint;to:ScreenPoint;element:Element;shape?:string;branch?:string;delayMs?:number}){
  if(from.x===to.x&&from.y===to.y)return null;
  const path=shape==='line'?`M${from.x} ${from.y}L${to.x} ${to.y}`:`M${from.x} ${from.y}Q${(from.x+to.x)/2} ${Math.min(from.y,to.y)-44} ${to.x} ${to.y}`;
  const material=branch==='Lightning'?'lightning':branch==='Metal'?'metal':branch==='Ice'?'ice':element;
  const timing={'--px-flight-delay':`${delayMs+PROJECTILE_ANTICIPATION_MS}ms`,'--px-flight-duration':`${PROJECTILE_TRAVEL_MS}ms`} as CSSProperties;
  const style={...timing,offsetPath:`path("${path}")`,offsetRotate:'0deg'} as CSSProperties;
  const color={fire:'#f5a349',water:'#7ed9df',air:'#d5e9ac',earth:'#c9ad78',light:'#fff1ad',dark:'#bc9edb'}[element];
  return <g className={`px-v9-projectile px-v9-projectile-${material}`} data-projectile-material={material} data-projectile-arrival={delayMs+PROJECTILE_ANTICIPATION_MS+PROJECTILE_TRAVEL_MS} pointerEvents="none" aria-hidden="true">
    <path className="px-v9-flight-trail" d={path} pathLength={100} fill="none" stroke={color} strokeWidth={material==='lightning'?4:3} style={timing}/>
    <g className="px-v9-flight-head" style={style}>
      {material==='lightning'?<path d="M2-12-7 1H0L-3 11 8-3H2Z" fill="#fff7bc" stroke="#8266a1" strokeWidth="2"/>:material==='metal'?<path d="M0-11 7-3 7 5 0 10-7 5-7-3Z" fill="#b8c8c2" stroke="#415854" strokeWidth="2"/>:material==='ice'?<path d="M0-12 7 0 0 11-7 0Z" fill="#e0fcf1" stroke="#5aa0bb" strokeWidth="2"/>:<><path d="M-7-3h4v-4h6v4h4v6H3v4H-3V3H-7Z" fill={color} stroke="#5e513f" strokeWidth="1.5"/><path d="M-2-4H2V3H-2Z" fill="#fff6ce"/></>}
    </g>
  </g>;
}

/** Authored silhouettes keep each material legible even with animation disabled. */
export function ElementImpact({element,ice=false,branch}:{element:Element;ice?:boolean;branch?:string}) {
  if(branch==='Lightning')return <g className="px-v8-impact-art px-v9-lightning" data-impact-material="lightning"><path className="px-v9-bolt" d="M6-38-17-9H-4L-12 18 17-15H3Z" fill="#fff5ac" stroke="#7564a3" strokeWidth="3"/><path className="px-v9-bolt-echo" d="M-23-24l-6 7h8l-6 11M22-9l8-6h-8l5-10" fill="none" stroke="#f8e9b2" strokeWidth="3"/><path className="px-v9-impact-ring" d="M-24 8-12 2H12L24 8 12 14H-12Z" fill="none" stroke="#d5bfed" strokeWidth="2"/></g>;
  if(branch==='Metal')return <g className="px-v8-impact-art px-v9-metal" data-impact-material="metal"><path className="px-v9-metal-spire" d="M-26 12V-8l8-13 8 13V12Z" fill="#a2b3ad" stroke="#465a59" strokeWidth="2"/><path className="px-v9-metal-spire" style={{'--px-spire-delay':'35ms'} as CSSProperties} d="M-6 13V-20l8-16 8 16V13Z" fill="#c3cec5" stroke="#465a59" strokeWidth="2"/><path className="px-v9-metal-spire" style={{'--px-spire-delay':'60ms'} as CSSProperties} d="M15 12V-4l8-14 8 14V12Z" fill="#95aaa6" stroke="#465a59" strokeWidth="2"/><path className="px-v9-metal-glint" d="M-18-17V9M2-31V10M23-14V9" stroke="#f1f0ce" strokeWidth="3"/><path className="px-v9-impact-ring" d="M-32 12h14v3h8M14 15h19v-3h6" fill="none" stroke="#c6b88f" strokeWidth="3"/></g>;
  if(ice)return <g className="px-v8-impact-art px-v8-ice" data-impact-material="ice"><path d="M-26 12V-3l6-10 6 10V8M-7 15V-12l7-16 7 16V15M14 9V-4l6-11 6 11V9" fill="#c8f3ed" stroke="#33779b" strokeWidth="2"/><path d="M0-21V10M-20-7V6M20-9V6" stroke="#fff9df" strokeWidth="3"/></g>;
  if(element==='water')return <g className="px-v8-impact-art px-v8-water" data-impact-material="water"><path className="px-v8-ripple" d="M-34 1-20-7H20L34 1 20 9H-20Z" fill="none" stroke="#d9f5e8" strokeWidth="4"/><path className="px-v8-splash" d="M-24 2v-13h5v8h7v-19h5v20H7v-15h5v14h9v-12h5V5H-24Z" fill="#62bfd0" stroke="#e4f5df" strokeWidth="2"/><path d="M-29-18h4v5h-4M17-26h4v5h-4M-3-32h4v5h-4" fill="#b4e9e4"/></g>;
  if(element==='fire')return <g className="px-v8-impact-art px-v8-fire" data-impact-material="fire"><path className="px-v8-flare" d="M-25 9V-6h5v-10h5v15h7v-21h5v-14h5v18h6v14h6v-13h5v8h6v18H-25Z" fill="#e77832" stroke="#913d20" strokeWidth="2"/><path d="M-10 9V-6h6v-11h4v15H7V9Z" fill="#ffe09a"/><path className="px-v8-embers" d="M-27-20h4v4h-4M18-28h4v4h-4M1-42h3v3H1" fill="#f9b34f"/></g>;
  if(element==='earth')return <g className="px-v8-impact-art px-v8-earth" data-impact-material="earth"><path className="px-v8-stones" d="M-29 10V-4l10-7 12 7V10ZM-4 12V-15l12-9 13 9V12ZM22 10V0l7-5 7 5V10Z" fill="#ad8b56" stroke="#624b32" strokeWidth="2"/><path d="m-28-4 9-5 10 5M-2-14l10-8 11 8" fill="none" stroke="#ecce91" strokeWidth="3"/><path className="px-v8-dust" d="M-36 12h13M23 16h16M-8 20h15" stroke="#d8c29a" strokeWidth="4"/></g>;
  if(element==='air')return <g className="px-v8-impact-art px-v8-air" data-impact-material="air"><path className="px-v8-curl" d="M-32 4H18l10-7V-14H10M-22-12H6l7-5V-25H4M-14 15H22l8-5" fill="none" stroke="#d9e7b3" strokeWidth="4"/><path className="px-v8-leaves" d="m-26-18 9-5-2 7-7 2M16 2l10-6-3 8-7 2M-3-32l7-4-1 7-6 2" fill="#71974b"/></g>;
  if(element==='light')return <g className="px-v8-impact-art px-v8-light" data-impact-material="light"><path className="px-v8-rays" d="M0-38v10M-32-13l10 4M32-13l-10 4M-22 15l7-6M22 15l-7-6" stroke="#f4d779" strokeWidth="3"/><path className="px-v8-prism" d="M0-29 8-9 20-4 8 2 0 18-8 2-20-4-8-9Z" fill="#fff3bf" stroke="#be913b" strokeWidth="2"/><path d="M0-18V6M-8-4H8" stroke="#fffdf0" strokeWidth="3"/></g>;
  return <g className="px-v8-impact-art px-v8-dark" data-impact-material="dark"><path className="px-v8-collapse" d="M-28-13H-17V-22H12v9H26V8H14v9H-13V8H-28Z" fill="none" stroke="#a58ab8" strokeWidth="4"/><path className="px-v8-core" d="M-7-15H7v6h6V4H7v7H-7V4h-6V-9h6Z" fill="#544164" stroke="#d4bddb" strokeWidth="2"/><path d="M-2-8H3V3H-2Z" fill="#211e30"/></g>;
}

export function ElementSurface({cell,animate=false}:{cell:SimCell;animate?:boolean}) {
  const seed=Math.abs(cell.q*17+cell.r*31),style={'--px-material-delay':`${-(seed%7)*.43}s`} as CSSProperties;
  if(isIce(cell))return <g className={`px-v8-material px-v8-frozen px-v9-ice${animate?' is-living':''}`} data-surface="ice" style={style}><path d="M-40-7-12-20 21-10 39 2 16 17-13 9-35 15Z" fill="#c6e4dc" fillOpacity=".6"/><path d="m-32-2 15-6 8 7 13-7 21 6M-9-1l-7 14M4-8l8-10M4-8l7 14 17 4" fill="none" stroke="#4e8d9b" strokeWidth="1.5"/><path className="px-v9-ice-gleam" d="M-25-8h12M8 10h17M17-9h7" stroke="#f3f8e3" strokeWidth="2"/><path className="px-v9-ice-star" d="M-22 1v6m-3-3h6M25-7v6m-3-3h6" stroke="#f5fff1" strokeWidth="1.5"/></g>;
  if(cell.ttl!==undefined&&(cell.terrain==='steam'||cell.reactions?.includes('steam')))return <g className={`px-v8-material px-v9-steam${animate?' is-living':''}`} data-surface="steam" style={style}>
    <path d="M-34 7h16v-3h10M9-8h15v3h10" fill="none" stroke="#dce8d8" strokeOpacity=".7" strokeWidth="2"/>
    {[[-25,7],[18,2],[-2,-12]].map(([x,y],index)=><g key={index} transform={`translate(${x} ${y})`}><path data-particle="steam-puff" className="px-v9-steam-puff" style={{'--px-puff-delay':`${index*-.83}s`,'--px-puff-drift':`${index%2?-5:6}px`} as CSSProperties} d="M-13 3V-3h4v-5h7v-4h7v5h7v5h5v7H9v4H-7V5h-6Z" fill={index===1?'#c6d9cf':'#edf1dd'} stroke="#b7d0c7" strokeWidth="1"/></g>)}
  </g>;
  if(isFlooded(cell))return <g className={`px-v8-material px-v8-flood${animate?' is-living':''}`} data-surface="flood" style={style}><path d="M-40-7-12-20 21-10 39 2 16 17-13 9-35 15Z" fill="#4a9dac" fillOpacity=".33"/><g className="px-v8-waterlines"><path d="M-33 4h12v-3h9M9-12h13v3h9M-7 16H9v-3h14" fill="none" stroke="#d3ece1" strokeWidth="2"/><path d="M-24 11h9M11-4h13" stroke="#32768b" strokeWidth="2"/></g></g>;
  if(cell.ttl===undefined)return null;
  const material=cell.terrain;
  if(material==='fire'||material==='magma')return <g className={`px-v8-material px-v8-coals px-v9-burning${animate?' is-living':''}`} data-surface="fire" style={style}>
    <path d="M-33 8h7v-5h8M18-10h8v5h9M-7 17h10" stroke="#963e29" strokeWidth="3" fill="none"/><path className="px-v8-coal-light" d="M-30 7h5M21-8h4M-5 16h6" stroke="#ffd47d" strokeWidth="2"/>
    {[[-28,8],[26,-3],[-5,17]].map(([x,y],index)=><g key={index} transform={`translate(${x} ${y})`}><g className="px-v9-field-flame" data-particle="field-flame" style={{'--px-flame-delay':`${index*-.41}s`} as CSSProperties}><path d="M-6 0v-6h3v-8h3v-6h2v11h3v-4h2v8H5v5Z" fill="#dd7234" stroke="#a34a28" strokeWidth="1"/><path d="M-2 0v-6h2v-5h2v6h2v5Z" fill="#ffe5a1"/></g><rect data-particle="field-ember" className="px-v9-field-ember" x={index%2?-2:2} y="-8" width="3" height="3" fill="#ffd99b" style={{'--px-flame-delay':`${index*-.61}s`,'--px-ember-drift':`${index%2?-5:4}px`} as CSSProperties}/></g>)}
  </g>;
  if(material==='air')return <g className={`px-v8-material px-v8-drift${animate?' is-living':''}`} data-surface="air" style={style}><path d="m-28 7 6-3-2 6-4 1M22-12l6-4-1 6-5 1" fill="#618349"/><path d="M-22 12h12M10-15h14" stroke="#e2e8b2" strokeWidth="2"/></g>;
  if(material==='light')return <g className={`px-v8-material px-v8-sunlit${animate?' is-living':''}`} data-surface="light" style={style}><path className="px-v8-glint" d="M-27 0v8m-4-4h8M24-12v8m-4-4h8" stroke="#fff3c5" strokeWidth="2"/></g>;
  if(material==='dark')return <g className={`px-v8-material px-v8-shade${animate?' is-living':''}`} data-surface="dark" style={style}><path d="M-33 6h9v-3h9M16-13h9v3h8M-6 16h12" stroke="#6c527f" strokeWidth="3" fill="none"/></g>;
  return null;
}
