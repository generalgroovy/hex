import type {CSSProperties} from 'react';
import type {Element} from '../../lib/game';
import {spellPresentation,ELEMENT_PALETTES,type ElementPalette} from '../../lib/element-presentation';
import {isIce,isFlooded,fieldCombination,type SimCell} from '../../lib/tactics-v16';
import {PHASE_MS,CAST_ANTICIPATION_MS,PROJECTILE_FLIGHT_MS} from '../../lib/feedback-v16';
import {ELEMENT_EFFECT_FRAMES,EFFECT_SHADES,PROJECTILE_CEL_MS,STEAM_EFFECT_FRAMES,STEAM_EFFECT_PALETTE,FIELD_FLAME_FRAMES,FIELD_STEAM_FRAMES,type EffectCel} from '../../lib/element-effect-frames';
import {projectileWake,type WakeMark} from '../../lib/element-clarity-v22';
import {reactionPresentation,REACTION_MOTIFS} from '../../lib/reaction-presentation-v44';
import ElementIcon from './ElementIcon';
import './element-motion-v9.css';
import './element-spectacle-v16.css';

export const PROJECTILE_ANTICIPATION_MS=CAST_ANTICIPATION_MS;
export const PROJECTILE_TRAVEL_MS=PROJECTILE_FLIGHT_MS;
type ScreenPoint={x:number;y:number};
const paletteStyle=(palette:ElementPalette):CSSProperties=>Object.fromEntries(Object.entries(palette).map(([name,color])=>[`--fx-${name}`,color])) as CSSProperties;
const materialStyle=(element:Element):CSSProperties=>paletteStyle(ELEMENT_PALETTES[element]);

/** Complete, opaque cels change at frame boundaries. Six compact paths per cel
 * retain pixel edges without DOM particles, scale tweens, or blur filters. */
function EffectFrames({frames,phase='projectile',staticFrame=1,paused=false}:{frames:readonly EffectCel[];phase?:'projectile'|'impact'|'surface';staticFrame?:number;paused?:boolean}) {
  return <g className={`px16-effect-cels px16-cels-${phase}`} shapeRendering="crispEdges" data-effect-cels={frames.length}>
    {frames.map((frame,index)=>paused&&index!==staticFrame?null:<g key={index} className={`px16-effect-cel px16-cel-${index}${index===staticFrame?' is-poster-cel':''}`} data-effect-frame={index} style={{'--px-cel-clock':phase==='impact'?`px16-impact-cel-${index}`:`px16-projectile-cel-${index}`,'--px-cel-cycle':`${PROJECTILE_CEL_MS*4}ms`} as CSSProperties}>
      {frame.paths.map((path,shade)=>path?<path key={shade} d={path} fill={`var(--fx-${EFFECT_SHADES[shade]})`}/>:null)}
    </g>)}
  </g>;
}

/** A travelling cel and a short trail share the resolver's unmodified clock. */
export function ElementProjectile({from,to,element,shape='hex',branch,delayMs=PHASE_MS.cast,flightFraction=1,readabilityScale=1}:{from:ScreenPoint;to:ScreenPoint;element:Element;shape?:string;branch?:string;delayMs?:number;flightFraction?:number;readabilityScale?:1|2}){
  if(from.x===to.x&&from.y===to.y)return null;
  const path=`M${from.x} ${from.y}L${to.x} ${to.y}`;
  const material=spellPresentation({element,branch}).kind;
  const duration=PROJECTILE_TRAVEL_MS*Math.max(0,Math.min(1,flightFraction));
  const timing={'--px-flight-delay':`${delayMs+PROJECTILE_ANTICIPATION_MS}ms`,'--px-flight-duration':`${duration}ms`} as CSSProperties;
  const style={...timing,offsetPath:`path("${path}")`,offsetRotate:'0deg'} as CSSProperties;
  const color=ELEMENT_PALETTES[element].light;
  const wake=projectileWake(from,to,material);
  return <g className={`px-v9-projectile px-v16-projectile px-v9-projectile-${material}`} data-projectile-material={material} data-projectile-shape={shape} data-projectile-launch={delayMs+PROJECTILE_ANTICIPATION_MS} data-projectile-arrival={delayMs+PROJECTILE_ANTICIPATION_MS+duration} data-projectile-fraction={flightFraction} data-element-family={element} data-projectile-scale={readabilityScale} style={materialStyle(element)} pointerEvents="none" aria-hidden="true">
    <path className="px-v16-flight-route" d={path} fill="none" stroke={color} strokeWidth="1.5" strokeDasharray="3 7"/>
    <path className="px-v9-flight-trail px-v16-flight-shadow" d={path} pathLength={100} fill="none" stroke="var(--fx-shadow)" strokeWidth="7" style={timing}/>
    <path className="px-v9-flight-trail" d={path} pathLength={100} fill="none" stroke={color} strokeWidth={material==='lightning'?4:3} style={timing}/>
    <g className="px-v9-flight-head" style={style}><g className={`px-v16-projectile-body is-${material}`} transform={readabilityScale===2?'scale(2)':undefined}><g className="px22-flight-wake" data-flight-profile={wake[0]?.shape??material} shapeRendering="crispEdges">{wake.map((mark,index)=><g key={index} transform={`translate(${mark.x} ${mark.y})`} className={`px22-wake-mark px22-wake-${index}`}><WakePixel mark={mark}/></g>)}</g><EffectFrames frames={ELEMENT_EFFECT_FRAMES[material].projectile}/></g></g>
  </g>;
}

function WakePixel({mark}:{mark:WakeMark}){
 const size=mark.size;
 const path=mark.shape==='spark'?`M-2-${size+2}H2v4H${size}v4H2v4H-2V2H-${size}v-4H-2Z`:mark.shape==='drop'?`M-2-${size}H2v4H${size}v${size}H-${size}v-${size}h${size-2}Z`:mark.shape==='chip'?`M-${size}-2h4v-2h${size}v${size+2}h-4v2h-${size}Z`:mark.shape==='curl'?`M-${size}-4H${size}v4H2v4H-${size}V2h4V0H${size-2}v-2H-${size}Z`:mark.shape==='star'?`M-2-${size+2}H2v${size}H${size+2}v4H2v${size}H-2V2H-${size+2}v-4h${size}Z`:`M-${size}-4H${size}v8H-${size}ZM-2-2v4H2v-4Z`;
 return <path d={path} fill="var(--fx-light)" fillRule="evenodd" stroke="var(--fx-shadow)" strokeWidth="2"/>;
}

/** One pressure front, one material formation, one name. Its burst is timed to
 * the meeting point; it is never duplicated across every affected hex. */
export function ElementClash({elements,name,color,delayMs,revealed}:{elements:Element[];name:string;color:string;delayMs:number;revealed:boolean}) {
  const steam=elements.length===2&&elements.includes('fire')&&elements.includes('water');
  const reaction=reactionPresentation(elements);
  const recipeWidth=elements.length*20-4,labelWidth=recipeWidth+name.length*7+27;
  const style={'--px-clash-delay':`${delayMs}ms`,'--px-impact-delay':`${delayMs}ms`,'--px-clash-color':color,...(steam?paletteStyle(STEAM_EFFECT_PALETTE):materialStyle(elements[0]||'light'))} as CSSProperties;
  return <g className="px-v16-clash" data-clash-name={name} data-reaction-family={reaction.family} data-clash-at={delayMs} data-clash-revealed={revealed} style={style} pointerEvents="none" aria-hidden="true">
    <g className="px16-clash-pressure" shapeRendering="crispEdges">
      <path className="px16-pressure-cel is-first" d="M-18 2h6v-8h24v8h6v8h-6v6h-24v-6h-6Z"/>
      <path className="px16-pressure-cel is-second" d="M-34 0h8v-8h14v-6h24v6h14v8h8v12h-8v8H12v6h-24v-6h-14v-8h-8Z"/>
      <path className="px16-pressure-cel is-third" d="M-50-2h10v-8h18v-6M22-16h18v8h10V4M-50 14h10v8h18v6M22 28h18v-8h10v-8"/>
    </g>
    {steam?<g className="px16-steam-formation"><EffectFrames frames={STEAM_EFFECT_FRAMES} phase="impact" staticFrame={2}/><g className="px16-steam-residue" shapeRendering="crispEdges">{STEAM_EFFECT_FRAMES[4].paths.map((path,shade)=>path?<path key={shade} d={path} fill={`var(--fx-${EFFECT_SHADES[shade]})`}/>:null)}</g></g>:<g className="px44-reaction-formation" shapeRendering="crispEdges">
      <EffectFrames frames={reaction.family==='mist'?STEAM_EFFECT_FRAMES:ELEMENT_EFFECT_FRAMES[reaction.material].impact} phase="impact" staticFrame={2}/>
      <g className="px44-reaction-mark"><path d={REACTION_MOTIFS[reaction.family]} fill="none" stroke="var(--fx-ink)" strokeWidth="7"/><path d={REACTION_MOTIFS[reaction.family]} fill="none" stroke="var(--fx-spark)" strokeWidth="3"/></g>
    </g>}
    <g className="px-v16-clash-name" data-clash-ingredients={elements.join('+')} transform="translate(0 -48)"><title>{`${elements.join(' + ')} → ${name}`}</title><rect x={-labelWidth/2} y="-13" width={labelWidth} height="26" rx="2"/><g className="px22-clash-recipe" transform={`translate(${-labelWidth/2+7} -8)`}>{elements.map((element,index)=><g key={element} transform={`translate(${index*20} 0)`}><ElementIcon element={element} size={16}/>{index<elements.length-1&&<text x="18" y="12" className="px22-recipe-plus">+</text>}</g>)}</g><text x={-labelWidth/2+recipeWidth+18} y="4" style={{textAnchor:'start'}}>{name}</text></g>
  </g>;
}

/** Secondary cells remain quiet: their footprint gives range, while just one
 * central, six-cel impact supplies the spectacle. */
export function ElementWake({element}:{element:Element}) {
  return <g className={`px-v16-area-wake is-${element}`} data-area-wake={element} shapeRendering="crispEdges">
    {element==='water'?<path d="M-29 2h8v-6H21v6h8M-18 9h36M-13 1H1"/>:element==='earth'?<path d="M-26 8h8v-8h8v4H0v-8H9v-5h10v7h8M0 4v10"/>:element==='air'?<path d="M-29 8H8v-4h12V0H9M-19-6H9v-7h9"/>:element==='light'?<path d="M0-16V13M-24-1H24M-13-11v3h3M13 9V6h-3"/>:element==='dark'?<path d="M-24-7h8v-7H8v6h8v8h9v4h-9v10H-7V9h-8V1h-9ZM-6-2H4V5H-6Z"/>:<><path d="M-24 7v-9h5v-9M0 12V-8h5v-9M22 4v-9"/><path d="M-16-16h3M14-20h3"/></>}
  </g>;
}

export function ElementImpact({element,ice=false,branch}:{element:Element;ice?:boolean;branch?:string}) {
  const kind=spellPresentation({element,branch}).kind,material=ice&&kind==='water'?'ice':kind;
  return <g style={materialStyle(element)} data-element-family={element}><g className="px-v8-impact-art px16-framed-impact" data-impact-material={material}><EffectFrames frames={ELEMENT_EFFECT_FRAMES[material].impact} phase="impact" staticFrame={2}/></g></g>;
}

/** A cooperative Link accents one victim. It has no footprint or terrain art. */
export function ElementTeamLink(){return <g className="px22-team-link" data-team-link="true" shapeRendering="crispEdges"><path className="px22-link-flash" d="M-24-10h10v-8H0v8H10V4H0v8H-14V4H-24ZM-4-2H6v-8H20v8H30v14H20v8H6v-8H-4Z" fill="none" stroke="#263b35" strokeWidth="7"/><path className="px22-link-flash" d="M-24-10h10v-8H0v8H10V4H0v8H-14V4H-24Z" fill="none" stroke="#b9e3d3" strokeWidth="3"/><path className="px22-link-flash" d="M-4-2H6v-8H20v8H30v14H20v8H6v-8H-4Z" fill="none" stroke="#f9d77a" strokeWidth="3"/><g className="px22-link-label" transform="translate(2 -31)"><rect x="-22" y="-10" width="44" height="20" rx="2" fill="#263b35" stroke="#f6d37d"/><text y="4" textAnchor="middle" fill="#fff5d8">Link</text></g></g>;}

export function ElementSurface({cell,animate=false,occupied=false}:{cell:SimCell;animate?:boolean;occupied?:boolean}) {
  const seed=Math.abs(cell.q*17+cell.r*31),style={'--px-material-delay':`${-(seed%7)*.43}s`} as CSSProperties;
  const compound=fieldCombination(cell),mechanics=compound?.mechanics;
  if(compound&&compound.elements.length>1&&!isIce(cell)&&compound.id!=='steam'&&compound.id!=='magma')return <g className={`px-v8-material px-material-compound${animate?' is-living':''}`} data-surface={compound.id} data-reaction-family={reactionPresentation(compound.elements).family} data-combination-mask={compound.mask} style={style}>
    <path d="M-37-5-12-18 21-9 38 3 15 18-14 10-35 13Z" fill={compound.color} fillOpacity=".32"/>
    {mechanics?.damageScale&&<g className="px-compound-core" fill={compound.color} fillOpacity=".72"><path d="M-31 3v-8h7v-6h12v5H1v9H-8v5H-25Z"/><path d="M5-7v-9h8v-5h10v5h8v8h-9v5Z"/></g>}
    {mechanics?.cover&&<g fill="#b4c3b4" stroke="#556e62" strokeWidth="1.5"><path d="M-30 8V-4l6-7 5 7V8ZM19 5V-7l6-7 5 7V5Z"/><path d="M-24-7V5M25-10V2" stroke="#f2ecd1"/></g>}
    {mechanics?.movement==='rough'&&<path d="M-33 10l8-6 7 6-7 4ZM7-13l6-5 8 5-8 4ZM-5 16l5-5 8 4-6 4Z" fill="#856f52" stroke="#c8bb91" strokeWidth="1"/>}
    {mechanics?.movement==='flood'&&<path className="px-compound-core" d="M-29 4h14v-3H-6M9-9h11v3h12M-11 13H7" fill="none" stroke="#cce7dd" strokeWidth="2"/>}
    {mechanics?.movement==='current'&&<path className="px-compound-core" d="M-30 5H-8l7-5H17l8-5M-21 13H4l8-5h17" fill="none" stroke="#dae4b7" strokeWidth="2"/>}
    {mechanics?.heal&&<g fill="#dcdf9e" stroke="#61734e" strokeWidth="1"><path d="M-19-9h4v-4h4v4h4v4h-4v4h-4v-4h-4ZM14 10h3V7h4v3h3v4h-3v3h-4v-3h-3Z"/></g>}
    {mechanics?.hazard&&<path className="px-v8-coal-light" d="M-26 10l7-4h10l7-5 9 4h13l7-7M-2-13l6 5 11-2" fill="none" stroke="#e59b63" strokeWidth="2.5"/>}
    {(mechanics?.cleanse||mechanics?.flux)&&<g className="px-compound-core" stroke={mechanics.flux===-1?'#746588':'#f4e0a0'} strokeWidth="2"><path d="M-26-8v7m-3-3h6M24 5v7m-3-3h6"/></g>}
    {!occupied&&<path className="px44-ground-mark" d={REACTION_MOTIFS[reactionPresentation(compound.elements).family]} transform="translate(0 3) scale(.4)" fill="none" stroke="#f2e7c6" strokeWidth="3" opacity=".55" shapeRendering="crispEdges"/>}
  </g>;
  if(isIce(cell))return <g className={`px-v8-material px-v8-frozen px-v9-ice${animate?' is-living':''}`} data-surface="ice" style={style}><path d="M-40-7-12-20 21-10 39 2 16 17-13 9-35 15Z" fill="#c6e4dc" fillOpacity=".76"/><path d="m-32-2 15-6 8 7 13-7 21 6M-9-1l-7 14M4-8l8-10M4-8l7 14 17 4" fill="none" stroke="#4e8d9b" strokeWidth="1.5"/><path className="px22-ice-facets" d="M-30-2h10v-4h8M10 10h12v-4h8M-4-14h10v4h10" fill="none" stroke="#edf9e7" strokeWidth="3"/><path className="px-v9-ice-gleam" d="M-25-8h12M8 10h17M17-9h7" stroke="#f3f8e3" strokeWidth="2"/><path className="px-v9-ice-star" d="M-22 1v6m-3-3h6M25-7v6m-3-3h6" stroke="#f5fff1" strokeWidth="1.5"/></g>;
  if(cell.ttl!==undefined&&(cell.terrain==='steam'||cell.reactions?.includes('steam')))return <g className={`px-v8-material px-v9-steam px16-steam-field${animate?' is-living':''}`} data-surface="steam" style={{...style,...paletteStyle(STEAM_EFFECT_PALETTE)}}>
    <path className="px22-steam-bed" d="M-38 4v-8h10v-6h14v-4H10v4H28v6h10V8H26v6H8v4H-12v-4H-28V8H-38Z" fill="#d9e6dc" fillOpacity=".28"/><path d="M-34 7h16v-3h10M9-8h15v3h10" fill="none" stroke="#edf2df" strokeOpacity=".9" strokeWidth="2"/>
    {(occupied?[[-28,8],[27,-3]]:[[-25,7],[18,2],[-2,-12]]).map(([x,y],index)=><svg key={index} data-particle="steam-puff" className="px16-field-steam" x={x-20} y={y-30} width="40" height="50" viewBox="-20 -30 40 50" overflow="visible" style={{'--px-puff-delay':`${index*-.83}s`} as CSSProperties}><EffectFrames frames={FIELD_STEAM_FRAMES} phase="surface" staticFrame={index%4} paused={!animate}/></svg>)}
  </g>;
  if(isFlooded(cell))return <g className={`px-v8-material px-v8-flood${animate?' is-living':''}`} data-surface="flood" style={style}><path d="M-40-7-12-20 21-10 39 2 16 17-13 9-35 15Z" fill="#4a9dac" fillOpacity=".33"/><g className="px-v8-waterlines"><path d="M-33 4h12v-3h9M9-12h13v3h9M-7 16H9v-3h14" fill="none" stroke="#d3ece1" strokeWidth="2"/><path d="M-24 11h9M11-4h13" stroke="#32768b" strokeWidth="2"/></g></g>;
  if(cell.ttl===undefined)return null;
  const material=cell.terrain;
  if(material==='fire'||material==='magma')return <g className={`px-v8-material px-v8-coals px-v9-burning px16-fire-field${animate?' is-living':''}`} data-surface="fire" style={{...style,...materialStyle('fire')}}>
    <path d="M-33 8h7v-5h8M18-10h8v5h9M-7 17h10" stroke="#963e29" strokeWidth="3" fill="none"/><path className="px-v8-coal-light" d="M-30 7h5M21-8h4M-5 16h6" stroke="#ffd47d" strokeWidth="2"/>
    {[[-28,8],[26,-3],[-5,17]].map(([x,y],index)=><svg key={index} data-particle="field-flame" className="px16-field-fire" x={x-12} y={y-26} width="24" height="34" viewBox="-12 -26 24 34" overflow="visible" style={{'--px-flame-delay':`${index*-.41}s`} as CSSProperties}><EffectFrames frames={FIELD_FLAME_FRAMES} phase="surface" staticFrame={index%4} paused={!animate}/><rect data-particle="field-ember" className="px16-field-ember" x={index%2?-3:2} y="-16" width="2" height="2" fill="var(--fx-light)"/></svg>)}
  </g>;
  if(material==='earth')return <g className="px-v8-material px22-earth-field" data-surface="earth" style={style} shapeRendering="crispEdges"><path d="M-35 7v-6h6v-4h8v6h6v8h-14v-4ZM17-8v-8h10v4h6v8H23v-4ZM-10 18v-6h8v-4h8v10Z" fill="#8e693b" stroke="#4d3d27" strokeWidth="2"/><path d="M-31 1h8M21-12h7M-5 12h7" stroke="#e0be78" strokeWidth="2"/></g>;
  if(material==='air')return <g className={`px-v8-material px-v8-drift${animate?' is-living':''}`} data-surface="air" style={style}><path d="m-28 7 6-3-2 6-4 1M22-12l6-4-1 6-5 1" fill="#618349"/><path d="M-33 12h18v-4h12M8-14h14v4h10M-13-2H5V-6h8" fill="none" stroke="#e2e8b2" strokeWidth="2.5"/></g>;
  if(material==='light')return <g className={`px-v8-material px-v8-sunlit${animate?' is-living':''}`} data-surface="light" style={style}><path d="M-34 6h10v-4h12M12-12h10v4h12M-4 18H8" fill="none" stroke="#b98d32" strokeWidth="4"/><path className="px-v8-glint" d="M-27 0v8m-4-4h8M24-12v8m-4-4h8M2 13v6m-3-3h6" stroke="#fff3c5" strokeWidth="2"/></g>;
  if(material==='dark')return <g className={`px-v8-material px-v8-shade${animate?' is-living':''}`} data-surface="dark" style={style}><path d="M-36 6v-6h8v-4h14v4h6v8h-14v4h-10ZM14-14h14v4h8v8H24v-4H12ZM-8 14H8v6H-8Z" fill="#352549" fillOpacity=".72"/><path d="M-33 6h9v-3h9M16-13h9v3h8M-6 16h12" stroke="#b59bcc" strokeWidth="2" fill="none"/></g>;
  return null;
}
