/** Established Wellspring pixel silhouettes; combat poses live in CombatCreatureV19. */
import type {CreatureFamily} from '../../lib/inhabitants-v16';
import type {CreatureMotionAction} from '../../lib/creature-motion-v44';
export default function CreatureBodyV19({family,action='idle',frame=0}:{family:CreatureFamily;action?:CreatureMotionAction;frame?:number}) {
 const gathered=action==='cast'&&frame===1,release=action==='cast'&&frame===2,fallen=action==='defeat'&&frame===3;
 const step=action==='walk'?(frame===1?-3:frame===3?3:0):0;
 // Anatomy poses are drawn separately from travel. A planted shell, forepaws,
 // spread wings and a flower bud each communicate a different preparation.
 if(family==='tortoise')return <>
  <path d={fallen?'M-24-4h12v4h-12M12-4h12v4H12':`M${-24+step}-9h9V1h-8M${11-step}-9h9V2h-8`} fill="var(--ec-dark)"/>
  <path d="M19-16h10v6H17" fill="var(--ec-dark)"/>
  <path d={gathered?'M-23-18v-10h7v-8H9v6h9v9h5v11h-43v-4h-3Z':'M-23-21v-9h7v-8H9v6h9v9h5v13h-43v-5h-3Z'}/>
  <path d="M-16-28h28v-4H-9v-2h-6Z" fill="var(--ec-light)"/><path d="M-10-30v15M4-30v15M-19-22H17" stroke="var(--ec-dark)" strokeWidth="3"/>
  <g transform={gathered?'translate(5 2)':release?'translate(-4 -2)':fallen?'translate(3 4)':undefined}><path d="M-29-19h11v13h-16v-8h5Z" fill="var(--ec-light)"/><path d={fallen?'M-29-13h5v2h-5':'M-29-15h3v3h-3'} fill="var(--ec-ink)"/></g>
 </>;
 if(family==='fox')return <>
  <path className="ec-tail" d={gathered?'M9-12h8v-8h4v-13h6v20h-5v8H9Z':release?'M8-10h18v-7h8v8h-5v6H7Z':'M10-13h11v-5h6v-10h-7v5H9v6H4v9h14v-5Z'} fill="var(--ec-light)"/>
  <path d={gathered?'M-19-20H4v5h9v11H-21v-5h-5v-7h7Z':'M-19-24h22v6H12v14H-21v-3h-5v-12h7Z'}/>
  <path d={fallen?'M-25-3h18v5h-18M3-3h16v5H3':`M${-21+step}-8h7V2h-7ZM${4-step}-8h7V3h-7Z`} fill="var(--ec-dark)"/>
  <g transform={gathered?'translate(2 3)':release?'translate(-3 -2)':fallen?'translate(0 7)':undefined}>
   <path d="M-23-33v-16h7v8h12v-8h7v23h-5v8h-16v-6h-9v-7Z"/><path d="M-21-32h8v8h-8M-5-32h6v8h-6" fill="var(--ec-light)"/>
   <path d="M-20-41h2v8h-2M-1-41h2v8h-2M-15-35h9v2h-9M-20-23h6v2h-6" fill="var(--cc-highlight)" stroke="none"/>
   <path d={fallen?'M-18-28h5v2h-5M-4-28h5v2h-5M-13-24h5v3h-5':'M-18-30h3v3h-3M-3-30h3v3h-3M-13-24h5v3h-5'} fill="var(--ec-ink)"/>
   {!fallen&&<path d="M-18-30h1v1h-1M-3-30h1v1h-1" fill="#fff4d7" stroke="none"/>}
   {release&&<path d="M-15-21h8v4h-8Z" fill="var(--ec-ink)"/>}
  </g>
 </>;
 if(family==='bird'||family==='heron')return <>
  <path className="ec-tail" d={release?'M8-16h14v-13h6v18H14v7H6Z':'M8-16h18v-6h5v13H14v5H6Z'} fill="var(--ec-light)"/>
  <path d="M-13-32H8v9h7v14H8v7H-8v-5h-9v-17h4Z"/>
  <path className="ec-wing" d={release||action==='walk'&&frame===1?'M-1-24h9v-9h7v-10h5v17h-5v12H7v6H-1Z':gathered?'M-1-24h10v6h5v10H1v-5H-3Z':'M-1-25h14v4h7v8H7v5H-1Z'} fill="var(--ec-dark)"/>
  <g transform={gathered?'translate(3 3)':release?'translate(-3 -2)':fallen?'translate(2 8)':undefined}><path d={family==='heron'?'M-13-43H2v13H-5v12h-8Z':'M-16-34h7v-7H2v8h5v13h-22Z'}/><path d={family==='heron'?'M-28-36h16v5h-16':'M-23-28h9v6h-9'} fill="var(--ec-light)"/><path d={fallen?'M-10-27h5v2h-5':family==='heron'?'M-9-37h3v3h-3':'M-10-29h4v4h-4'} fill="var(--ec-ink)"/></g>
  <path d={`M${-8+step}-2V${family==='heron'?8:3}h-6M${5-step}-2V${family==='heron'?8:4}h7`} stroke="var(--ec-dark)" strokeWidth="3"/>
 </>;
 if(family==='garden')return <>
  <path d={fallen?'M-26-9h51v7H-26Z':'M-21-15h42v8h-6v9H8v-6H-9v6h-7v-9h-5Z'} fill="var(--ec-dark)"/>
  <path d="M-24-19h48v7h-48M-18-27h36v8h-36"/>
  <path d={gathered?'M-12-27v-9h4v9M8-27v-15h4v15M-2-27v-6h4v6':fallen?'M-12-27v-6h4v6M8-27v-8h4v8':'M-12-27v-15h4v15M8-27v-25h4v25M-2-27v-9h4v9'} fill="var(--ec-dark)"/>
  <path d={gathered?'M-16-37h9v8h-9M5-45h13v13H5M-5-34h10v8H-5':release?'M-27-45h18v8h-18M-8-48H8v7H-8M1-58h22v8H1M17-45h15v8H17M-9-37H9v9H-9':fallen?'M-22-34h13v7h-13M1-36h22v8H1':'M-23-43h15v8h-15M-8-45h13v7H-8M5-54h14v10H5M15-44h13v7H15M-6-35h13v9H-6'} fill="var(--ec-light)"/>
  <path d={fallen?'M-12-14h5v2h-5M7-14h5v2H7':'M-12-16h4v4h-4M7-16h4v4H7'} fill="var(--ec-ink)"/>
 </>;
 switch(family){
 case 'otter':return <><path className="ec-tail" d="M11-7h13v4h8v5H9V-3H4v-7Z" fill="var(--ec-dark)"/><path d="M-11-31H9v7h7v19h-7V2H2v-7h-12v7h-8V-5h-6v-17h8Z"/><path d="M-19-37h6v-6H7v6h7v15H8v6h-21v-5h-8v-10h2Z"/><path d="M-12-25H8v7H2v13h-12Z" fill="var(--ec-light)"/><path d="M-14-31h3v3h-3M5-31h3v3H5M-5-25h5v3h-5" fill="var(--ec-ink)"/><path d="M-22-24h9M7-24h12" stroke="var(--ec-light)" strokeWidth="2"/></>;
 case 'moth':return <><g className="ec-wing"><path d="M-5-28h-8v-12h-10v-7h-8v22h7v13h12v7h8M5-28h8v-12h10v-7h8v22h-7v13H12v7H4"/><path d="M-12-28h-6v-7h-6v13h8v6h4M12-28h6v-7h6v13h-8v6h-4" fill="var(--ec-light)"/><path d="M-18-29h5v5h-5M13-29h5v5h-5" fill="var(--ec-dark)"/></g><path d="M-4-34h8v30h-8Z" fill="var(--ec-dark)"/><path d="M-6-36h12v9H-6Z" fill="var(--ec-light)"/><path d="M-3-37v-8h-5M3-37v-8h5" stroke="var(--ec-dark)" strokeWidth="2"/><path d="M-4-33h2v3h-2M2-33h2v3H2" fill="var(--ec-ink)"/></>;
 case 'cat':return <><path className="ec-tail" d="M10-10h10v-14h-6v-5h11v24H9Z" fill="var(--ec-dark)"/><path d="M-14-29H6v7h7V0H5v-7H-5v7h-14v-9h5Z"/><path d="M-20-31v-15h6v7H0v-7h6v23H0v6h-14v-6h-6Z"/><path d="M-15-30h4v3h-4M-1-30h4v3h-4" fill="var(--ec-light)"/><path d="M-9-25h4v3h-4" fill="var(--ec-ink)"/><path d="M-25-24h9M2-24h10" stroke="var(--ec-light)" strokeWidth="2"/></>;
 case 'salamander':return <><path className="ec-tail" d="M11-14h14v-8h7v14h-7v6H11" fill="var(--ec-dark)"/><path d="M-20-21H14v17H-20v-5h-7v-8h7Z"/><path d="M-18-6v9h6V-5M5-5v8h7V-6" fill="var(--ec-dark)"/><path d="M-24-20h8v-5h12v7h-8v11h-15v-8h3Z"/><path d="M-22-18h4v4h-4" fill="var(--ec-light)"/><path d="M-10-17h6v4h-6M3-13h5v4H3" fill="var(--ec-light)"/></>;
 case 'toad':return <><path d="M-23-8h11v8h-18v-6h7M13-8h10v2h7V1H12" fill="var(--ec-dark)"/><path d="M-18-23H18v8h6v12h-48v-12h6Z"/><path d="M-17-32h10v10h-10M8-32h10v10H8"/><path d="M-14-29h5v5h-5M10-29h5v5h-5M-12-11h25v6h-25" fill="var(--ec-light)"/><path d="M-13-28h3v3h-3M11-28h3v3h-3M-10-16h21v2h-21" fill="var(--ec-ink)"/></>;
 case 'stag':return <><path d="M-13-25H13v18H-9v8h-6v-17h-3Z"/><path d="M8-10h6V2H8M-13-20h-7v-18h9v13h5Z"/><path d="M-22-42h15v14h-15v-5h-5v-5h5Z"/><path d="M-19-43v-13h-8v-8M-10-43v-13h8v-8M-19-50h-8M-10-50h8" stroke="var(--ec-dark)" strokeWidth="3" fill="none"/><path d="M-21-37h3v3h-3" fill="var(--ec-ink)"/><path d="M-1-22h6v9h-6M13-24h9v5h-9" fill="var(--ec-light)"/></>;
 case 'serpent':return <><path className="ec-tail" d="M-21-13h8v7H8v-7h9v-7h7v16h-8v7h-32v-7h-8v-9Z"/><path d="M-22-15v-20h8v25h-8ZM-25-40h18v12h-18v-5h-6v-4h6Z"/><path d="M-19-34h4v4h-4" fill="var(--ec-light)"/><path d="M-15-5H9v5h-24M-16-19h4v11h-4" fill="var(--ec-light)"/><path d="M-19-37h3v3h-3" fill="var(--ec-ink)"/></>;
 case 'bison':return <><path d="M-17-35H12v6h9v21H14V2H6v-9H-9v9h-8v-9h-7v-19h7Z"/><path d="M-26-30h18v21h-18v-5h-5v-10h5Z" fill="var(--ec-dark)"/><path d="M-28-29v-9h-7v-8M-9-29v-9h7v-8" stroke="var(--ec-light)" strokeWidth="4" fill="none"/><path d="M-25-24h4v4h-4M-28-13h18v5h-18" fill="var(--ec-light)"/><path d="M3-32h9v7H3M13-24h5v7h-5" fill="var(--ec-light)"/></>;
 }
}

export const creatureBodyDetails:Record<CreatureFamily,string>={
 fox:'M-20-41h3v8h-3M-1-41h3v8h-3M-17-18h8v3h-8M-18-7h4v5h-4M11-15h7v2h-7',
 otter:'M-16-36h4v3h-4M5-36h4v3H5M-16-20h5v3h-5M-8-14h9v2h-9M-16-5h4v4h-4M18-4h7v2h-7',
 tortoise:'M-15-27h4v8h-4M-7-28H1v5h-8M7-27h5v7H7M-15-15h11v2h-11M4-15h12v2H4',
 bird:'M-12-35h3v8h-3M-11-19h5v10h-5M3-23h8v2H3M8-17h8v2H8M15-12h7v2h-7',
 moth:'M-29-40h3v9h-3M-24-19h6v3h-6M26-40h3v9h-3M18-19h6v3h-6M-2-24h4v9h-4',
 cat:'M-18-39h3v6h-3M0-39h3v6H0M-15-18h5v2h-5M-11-12h4v5h-4M-16-3h4v3h-4M7-3h4v3H7',
 heron:'M-10-36h2v20h-2M-10-41h9v2h-9M-5-19h6v8h-6M6-18h6v2H6M11-13h7v2h-7',
 salamander:'M-19-22h5v2h-5M-13-20h3v3h-3M-6-20h3v3h-3M1-20h3v3H1M8-20h3v3H8M16-12h6v2h-6',
 toad:'M-14-27h3v2h-3M11-27h3v2h-3M-18-19h4v3h-4M16-19h4v3h-4M-7-9h15v2H-7M-25-4h7v2h-7',
 stag:'M-20-54h2v10h-2M-11-54h2v10h-2M-18-31h3v8h-3M-9-23h6v3h-6M7-22h3v8H7M-13-5h3v5h-3',
 serpent:'M-23-38h5v2h-5M-20-26h3v3h-3M-20-18h3v3h-3M-16-11h3v3h-3M-8-6h3v3h-3M3-6h3v3H3M14-12h3v3h-3',
 bison:'M-15-32h5v3h-5M-6-32h4v3h-4M2-32h4v3H2M-25-18h3v4h-3M-14-5h4v5h-4M8-5h4v5H8',
 garden:'M-20-41h8v2h-8M8-52h8v2H8M17-42h8v2h-8M-15-24h11v2h-11M4-24h8v2H4M-19-17h4v3h-4M-12-4h4v4h-4',
};
