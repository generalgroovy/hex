"use client";
import type {CSSProperties} from 'react';
import {getInhabitantSpecies,type CreatureFamily} from '../../lib/inhabitants-v14';
import './elemental-creature.css';
import './combat-life-v13.css';

export type ElementalCreatureProps={speciesId:string;x?:number;y?:number;size?:number;active?:boolean;paused?:boolean};
const palettes:Record<string,[string,string,string]>={fire:['#b64f2b','#f2aa4f','#5b332d'],water:['#458b9b','#a0d5d0','#294b61'],earth:['#887245','#b4b174','#414934'],air:['#7d9959','#d2df9b','#435e43'],light:['#c6a44d','#fff0ad','#79613a'],dark:['#756080','#baa2c4','#3c334e']};
function Body({family}:{family:CreatureFamily}) {
 switch(family){
 case 'fox':return <><path className="ec-tail" d="M10-13h11v-5h6v-10h-7v5H9v6H4v9h14v-5Z" fill="var(--ec-light)"/><path d="M-19-24h22v6H12v14H4V3h-7V-4h-11V2h-7v-9h-5v-12h7Z"/><path d="M-23-33v-16h7v8h12v-8h7v23h-5v8h-16v-6h-9v-7Z"/><path d="M-21-32h8v8h-8M-5-32h6v8h-6" fill="var(--ec-light)"/><path d="M-18-30h3v3h-3M-3-30h3v3h-3M-13-24h5v3h-5" fill="var(--ec-ink)"/></>;
 case 'otter':return <><path className="ec-tail" d="M11-7h13v4h8v5H9V-3H4v-7Z" fill="var(--ec-dark)"/><path d="M-11-31H9v7h7v19h-7V2H2v-7h-12v7h-8V-5h-6v-17h8Z"/><path d="M-19-37h6v-6H7v6h7v15H8v6h-21v-5h-8v-10h2Z"/><path d="M-12-25H8v7H2v13h-12Z" fill="var(--ec-light)"/><path d="M-14-31h3v3h-3M5-31h3v3H5M-5-25h5v3h-5" fill="var(--ec-ink)"/><path d="M-22-24h9M7-24h12" stroke="var(--ec-light)" strokeWidth="2"/></>;
 case 'tortoise':return <><path d="M-24-9h9V1h-8M11-9h9V2h-8M19-16h10v6H17" fill="var(--ec-dark)"/><path d="M-23-21v-9h7v-8H9v6h9v9h5v13h-43v-5h-3Z"/><path d="M-16-28h28v-4H-9v-2h-6Z" fill="var(--ec-light)"/><path d="M-10-30v15M4-30v15M-19-22H17" stroke="var(--ec-dark)" strokeWidth="3"/><path d="M-29-19h11v13h-16v-8h5Z" fill="var(--ec-light)"/><path d="M-29-15h3v3h-3" fill="var(--ec-ink)"/></>;
 case 'bird':return <><path className="ec-tail" d="M8-16h18v-6h5v13H14v5H6Z" fill="var(--ec-light)"/><path d="M-13-32H8v9h7v14H8v7H-8v-5h-9v-17h4Z"/><path className="ec-wing" d="M-1-25h14v4h7v8H7v5H-1Z" fill="var(--ec-dark)"/><path d="M-16-34h7v-7H2v8h5v13h-22Z"/><path d="M-23-28h9v6h-9" fill="var(--ec-light)"/><path d="M-10-29h4v4h-4" fill="var(--ec-ink)"/><path d="M-8-2V3h-6M5-2V4h7" stroke="var(--ec-dark)" strokeWidth="3"/></>;
 case 'moth':return <><g className="ec-wing"><path d="M-5-28h-8v-12h-10v-7h-8v22h7v13h12v7h8M5-28h8v-12h10v-7h8v22h-7v13H12v7H4"/><path d="M-12-28h-6v-7h-6v13h8v6h4M12-28h6v-7h6v13h-8v6h-4" fill="var(--ec-light)"/><path d="M-18-29h5v5h-5M13-29h5v5h-5" fill="var(--ec-dark)"/></g><path d="M-4-34h8v30h-8Z" fill="var(--ec-dark)"/><path d="M-6-36h12v9H-6Z" fill="var(--ec-light)"/><path d="M-3-37v-8h-5M3-37v-8h5" stroke="var(--ec-dark)" strokeWidth="2"/><path d="M-4-33h2v3h-2M2-33h2v3H2" fill="var(--ec-ink)"/></>;
 case 'cat':return <><path className="ec-tail" d="M10-10h10v-14h-6v-5h11v24H9Z" fill="var(--ec-dark)"/><path d="M-14-29H6v7h7V0H5v-7H-5v7h-14v-9h5Z"/><path d="M-20-31v-15h6v7H0v-7h6v23H0v6h-14v-6h-6Z"/><path d="M-15-30h4v3h-4M-1-30h4v3h-4" fill="var(--ec-light)"/><path d="M-9-25h4v3h-4" fill="var(--ec-ink)"/><path d="M-25-24h9M2-24h10" stroke="var(--ec-light)" strokeWidth="2"/></>;
 case 'heron':return <><path d="M-8-22h26v7h8v8H-8v-7h-5Z"/><path className="ec-wing" d="M3-20h12v7h8v4H3Z" fill="var(--ec-dark)"/><path d="M-12-37h7v25h-7ZM-12-43H2v11h-14Z"/><path d="M-27-39h15v5h-15" fill="var(--ec-light)"/><path d="M-8-40h3v3h-3" fill="var(--ec-ink)"/><path d="M-2-6V5h-7M12-6V5h7" stroke="var(--ec-dark)" strokeWidth="3"/><path d="M-4-45v-7h3v7" fill="var(--ec-light)"/></>;
 case 'salamander':return <><path className="ec-tail" d="M11-14h14v-8h7v14h-7v6H11" fill="var(--ec-dark)"/><path d="M-20-21H14v17H-20v-5h-7v-8h7Z"/><path d="M-18-6v9h6V-5M5-5v8h7V-6" fill="var(--ec-dark)"/><path d="M-24-20h8v-5h12v7h-8v11h-15v-8h3Z"/><path d="M-22-18h4v4h-4" fill="var(--ec-light)"/><path d="M-10-17h6v4h-6M3-13h5v4H3" fill="var(--ec-light)"/></>;
 case 'toad':return <><path d="M-23-8h11v8h-18v-6h7M13-8h10v2h7V1H12" fill="var(--ec-dark)"/><path d="M-18-23H18v8h6v12h-48v-12h6Z"/><path d="M-17-32h10v10h-10M8-32h10v10H8"/><path d="M-14-29h5v5h-5M10-29h5v5h-5M-12-11h25v6h-25" fill="var(--ec-light)"/><path d="M-13-28h3v3h-3M11-28h3v3h-3M-10-16h21v2h-21" fill="var(--ec-ink)"/></>;
 case 'stag':return <><path d="M-13-25H13v18H-9v8h-6v-17h-3Z"/><path d="M8-10h6V2H8M-13-20h-7v-18h9v13h5Z"/><path d="M-22-42h15v14h-15v-5h-5v-5h5Z"/><path d="M-19-43v-13h-8v-8M-10-43v-13h8v-8M-19-50h-8M-10-50h8" stroke="var(--ec-dark)" strokeWidth="3" fill="none"/><path d="M-21-37h3v3h-3" fill="var(--ec-ink)"/><path d="M-1-22h6v9h-6M13-24h9v5h-9" fill="var(--ec-light)"/></>;
 case 'serpent':return <><path className="ec-tail" d="M-21-13h8v7H8v-7h9v-7h7v16h-8v7h-32v-7h-8v-9Z"/><path d="M-22-15v-20h8v25h-8ZM-25-40h18v12h-18v-5h-6v-4h6Z"/><path d="M-19-34h4v4h-4" fill="var(--ec-light)"/><path d="M-15-5H9v5h-24M-16-19h4v11h-4" fill="var(--ec-light)"/><path d="M-19-37h3v3h-3" fill="var(--ec-ink)"/></>;
 case 'bison':return <><path d="M-17-35H12v6h9v21H14V2H6v-9H-9v9h-8v-9h-7v-19h7Z"/><path d="M-26-30h18v21h-18v-5h-5v-10h5Z" fill="var(--ec-dark)"/><path d="M-28-29v-9h-7v-8M-9-29v-9h7v-8" stroke="var(--ec-light)" strokeWidth="4" fill="none"/><path d="M-25-24h4v4h-4M-28-13h18v5h-18" fill="var(--ec-light)"/><path d="M3-32h9v7H3M13-24h5v7h-5" fill="var(--ec-light)"/></>;
 case 'garden':return <><path d="M-21-15h42v8h-6v9H8v-6H-9v6h-7v-9h-5Z" fill="var(--ec-dark)"/><path d="M-24-19h48v7h-48M-18-27h36v8h-36"/><path d="M-12-27v-15h4v15M8-27v-25h4v25M-2-27v-9h4v9" fill="var(--ec-dark)"/><path d="M-23-43h15v8h-15M-8-45h13v7H-8M5-54h14v10H5M15-44h13v7H15M-6-35h13v9H-6" fill="var(--ec-light)"/><path d="M-12-16h4v4h-4M7-16h4v4H7" fill="var(--ec-ink)"/></>;
 }
}
/** Grounded SVG sprite; the outer transform belongs to the map, inner motion to the creature. */
export default function ElementalCreature({speciesId,x=0,y=0,size=64,active=false,paused=false}:ElementalCreatureProps){
 const species=getInhabitantSpecies(speciesId),primary=palettes[species.elements[0]],secondary=palettes[species.elements.at(-1)!];
 const style={'--ec-body':primary[0],'--ec-light':secondary[1],'--ec-dark':primary[2],'--ec-ink':'#272d2b','--ec-time':`${2.5+(species.mask%7)*.19}s`,'--ec-life-phase':`${-(species.mask%11)*.47}s`} as CSSProperties;
 return <g transform={`translate(${x} ${y}) scale(${size/64})`} className={`elemental-creature ec-combat-life ec-${species.family}${active?' is-gathering':''}${paused?' is-paused':''}`} style={style} shapeRendering="crispEdges" pointerEvents="none" aria-hidden="true">
  <ellipse className="ec-shadow" cx="0" cy="2" rx={species.family==='moth'?15:24} ry="5" fill="#25362c" opacity=".2"/>
  <g className="ec-body" fill="var(--ec-body)" stroke="var(--ec-ink)" strokeWidth="1.5" strokeLinejoin="miter">
   <Body family={species.family}/>
   {species.elements.includes('earth')&&species.family!=='garden'&&<path d="M-2-28v-6h5v6h5v5H-6v-5Z" fill="#a7b16c" strokeWidth="1"/>}
   {species.elements.includes('water')&&<path d="M4-16h3v5H4M10-20h3v5h-3" fill="#a9e5df" stroke="none"/>}
   {species.elements.includes('fire')&&<path className="ec-ember" d="M13-32h3v-7h3v4h3v8h-9Z" fill="#f8be63" stroke="#8f5435" strokeWidth="1"/>}
   {species.elements.includes('air')&&<path d="M-12-42h-5v-5h-6v-3h10v5h5" fill="none" stroke="#d3e3af" strokeWidth="2"/>}
   {species.elements.includes('light')&&<path d="M1-38h3v-4h3v4h4v3H7v4H4v-4H1Z" fill="#fff0ac" stroke="#9c8042" strokeWidth="1"/>}
   {species.elements.includes('dark')&&<path d="M19-18h5v4h-3v5h-6v-3h4Z" fill="#bca9cc" stroke="#605377" strokeWidth="1"/>}
   <path d={species.mask%3===0?'M-6-12h3v3h-3M0-16h3v3H0':species.mask%3===1?'M-6-15h8v2h-8':'M-5-17h3v8h-3'} fill="var(--ec-light)" stroke="none" opacity=".7"/>
  </g>
  {active&&<g className="ec-ready" fill="var(--ec-light)" stroke="var(--ec-dark)" strokeWidth="1"><path d="M-30-36h3v3h-3M26-31h3v3h-3M-25-46h2v2h-2"/></g>}
 </g>;
}
