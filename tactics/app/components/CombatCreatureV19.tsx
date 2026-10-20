"use client";
import type {CSSProperties} from 'react';
import {getCreature,type CreatureRole} from '../../lib/campaign-creatures-v19';
import {ELEMENT_PALETTES} from '../../lib/element-presentation';
import {creatureMotion,CREATURE_MATERIAL_SHADOWS} from '../../lib/creature-motion-v44';
import CreatureBodyV19,{creatureBodyDetails} from './CreatureBodyV19';
import './combat-creature-v19.css';

export type CreatureAction='idle'|'walk'|'cast'|'hit'|'defeat';
export type CombatCreatureV19Props={creatureId:string;action?:CreatureAction;facing?:1|-1;size?:number;className?:string};
const tierScale={lesser:.78,standard:.92,greater:1.06} as const;
function RoleMark({role}:{role:CreatureRole}) {
 const marks:Record<CreatureRole,string>={
 striker:'M-3-24h3v-5h3v7H0v4H-3Z',keeper:'M-5-27H5v8L0-15-5-19Z',
 controller:'M-5-24h10M0-29v10',artillery:'M-5-28h3v3H2v-3H5v10H2v-3H-2v3H-5Z',
 scout:'M-5-26h6v3H5v3H-1v-3H-5Z',support:'M-2-28H2v4H6v4H2v4H-2v-4H-6v-4H-2Z',
 };
 return <path className="cc19-role-mark" d={marks[role]} fill="var(--cc-accent)" stroke="var(--cc-shadow)" strokeWidth="1"/>;
}
/** Shared pixel silhouettes, distinct ingredients and class crests. The sprite is
 * static at rest. Actual actions select short, discrete poses instead of idle sway. */
export default function CombatCreatureV19({creatureId,action='idle',facing=1,size=96,className=''}:CombatCreatureV19Props){
 const creature=getCreature(creatureId),primary=ELEMENT_PALETTES[creature.elements[0]],secondary=ELEMENT_PALETTES[creature.elements.at(-1)!];
 const motion=creatureMotion(creature.family,action);
 const style={'--ec-body':primary.main,'--ec-light':primary.light,'--ec-dark':primary.shadow,'--ec-ink':primary.ink,'--cc-highlight':primary.bright,'--cc-accent':secondary.light,'--cc-shadow':primary.shadow,'--cc19-duration':`${motion.duration}ms`,width:size,height:size} as CSSProperties;
 const variant=creature.id.split('').reduce((value,letter)=>(value+letter.charCodeAt(0))%7,0);
 const frames=motion.frames,winged=['moth','bird','heron'].includes(creature.family);
 return <span className={`combat-creature-v19 cc19-${action} cc19-${creature.family} cc19-${creature.strengthClass} ${className}`} style={style} role="img" aria-label={`${creature.name}, ${creature.strengthClass} ${creature.elements.join(' and ')} ${creature.role}`} data-creature-id={creature.id} data-creature-action={action}>
  <svg viewBox="-48 -76 96 96" aria-hidden="true" focusable="false" shapeRendering="crispEdges">
   <ellipse cx="0" cy="4" rx={creature.family==='moth'?14:22} ry="4" fill="#302a22" opacity=".18"/>
   <g transform={`scale(${facing} 1)`}>
    {frames.map(([x,y],frame)=><g key={frame} className={`cc19-frame cc19-frame-${frame}`} data-creature-frame={frame} transform={`translate(${x} ${y}) scale(${tierScale[creature.strengthClass]})`}>
     <g className="cc19-pose" fill="var(--ec-body)" stroke="var(--ec-ink)" strokeWidth="2" strokeLinejoin="miter" paintOrder="stroke fill">
      <CreatureBodyV19 family={creature.family} action={action} frame={frame}/>
      {!(['fox','tortoise','bird','heron','garden'].includes(creature.family)&&(action==='cast'&&(frame===1||frame===2)||action==='defeat'&&frame===3))&&<>
       <path className="cc44-material-shadow" d={CREATURE_MATERIAL_SHADOWS[creature.family]} fill="var(--ec-dark)" stroke="none"/>
       <path d={creatureBodyDetails[creature.family]} fill="var(--cc-highlight)" stroke="none"/>
      </>}
      <g className="cc19-ingredient-details">
       {creature.elements.includes('fire')&&<><path d="M9-29v-7h3v-9h3v6h4v-4h3v12h-4v5h-6v-3Z" fill="#ffb760" stroke="#722f24"/><path d="M13-32v-5h4v8h-4Z" fill="#ffe2ad" stroke="none"/></>}
       {creature.elements.includes('water')&&<><path d="M-19-13h7v3h10v3H8v3H-2v-3h-10v-3h-7Z" fill="#a2e0e9" stroke="none"/><path d="M9-23h3v4h-3M15-20h3v5h-3" fill="#e4f8ee" stroke="none"/></>}
       {creature.elements.includes('earth')&&<><path d="M-9-29h15v7h6v9H-4v-5h-5Z" fill="#805827" stroke="#513d26"/><path d="M-6-27H3v3H-6M-1-17H8v3H-1" fill="#d9b86a" stroke="none"/></>}
       {creature.elements.includes('air')&&<path d="M-17-37h-7v-4h-8v-4h13v4h7M9-13h9v-4h10v-3" fill="none" stroke="#b6ce79" strokeWidth="2"/>}
       {creature.elements.includes('light')&&<path d="M-3-43h4v-5H4v5H9v3H4v5H1v-5H-3Z" fill="#fff4bf" stroke="#996718"/>}
       {creature.elements.includes('dark')&&<path d="M17-31h7v4h-3v7h-7v-4h4v-5h-1Z" fill="#c4a2dc" stroke="#63458d"/>}
      </g>
      <path d={variant%3===0?'M-16-18h3v3h-3M-10-15h3v3h-3':variant%3===1?'M-17-20h8v2h-8M-14-15h7v2h-7':'M-16-21h3v10h-3M-11-18h3v7h-3'} fill="var(--ec-light)" stroke="none" opacity=".8"/>
      {creature.strengthClass!=='lesser'&&<g className="cc19-class-crest"><path d="M-17-29v-7h4v-6h4v9h-3v4Z" fill="var(--ec-light)" stroke="var(--ec-dark)"/><RoleMark role={creature.role}/></g>}
      {creature.strengthClass==='greater'&&<path className="cc19-greater-crest" d={creature.family==='moth'?'M-31-39h4v-8h4v10h5v5h-9v7h-5ZM31-39h-4v-8h-4v10h-5v5h9v7h5Z':creature.family==='bird'||creature.family==='heron'?'M-11-42v-10h4v-9h3v13h5v-7h3v13H0v5Z':creature.family==='tortoise'?'M-21-27v-8h5v-8h5v8h5v-10h5v11h5v-8h5v10h5v7Z':creature.family==='serpent'?'M-24-28h-6v-8h4v-9h5v9h4v8M10-6h7v-4h6v9h-13Z':creature.family==='garden'?'M-24-35v-8h-6v-5h5v-6h5v6h6v5h-5v8M14-33v-9h-5v-5h5v-7h5v7h6v5h-6v9':creature.family==='cat'||creature.family==='fox'?'M-23-28h-6v8h5v7h6v-8M6-28h6v8H8v7H2v-8':"M-18-36v-9h-6v-8h-4v12h5v7M8-37v-9h6v-8h4v12h-5v7"} fill="var(--ec-light)" stroke="var(--ec-dark)" strokeWidth="1"/>}
      {action==='walk'&&winged&&frame%2===1&&<path d="M-6-26h-9v-5h-8v-7h6v4h8v4h7M6-26h9v-5h8v-7h-6v4h-8v4H2" fill="var(--ec-light)" stroke="var(--ec-dark)"/>}
     </g>
     {action==='cast'&&frame>0&&frame<3&&<g className="cc19-cast-motes" fill="var(--ec-light)" stroke="var(--ec-dark)" strokeWidth="1"><path d={frame===1?'M-28-30h3v3h-3M26-38h3v3h-3M-8-55h3v3h-3':'M-33-37h4v4h-4M29-44h4v4h-4M-5-62h4v4h-4'}/><path d="M-25 4h12v3H12V4H25M-21-2h-5v4M21-2h5v4" fill="none" strokeWidth="2"/></g>}
     {action==='hit'&&frame<2&&<path d="M-31-22h7v3h-7M27-32h7v3h-7M21-46h3v7h-3" fill="#f5c898" stroke="none"/>}
     {action==='defeat'&&frame===3&&<path d="M-30 0h5v3h-5M20 4h8v3h-8M-6 9h12v2H-6" fill="var(--ec-dark)" stroke="none" opacity=".5"/>}
    </g>)}
   </g>
  </svg>
 </span>;
}

