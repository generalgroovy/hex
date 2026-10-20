"use client";
import {useEffect,useId,useLayoutEffect,useRef,useState,type CSSProperties,type ReactNode} from 'react';
import {createPortal} from 'react-dom';
import {activeStatusInsights,insightPosition} from '../../lib/battle-inspection-v24';
import type {Status,StatusId} from '../../lib/spells-v20';
import './battle-inspection-v24.css';

/** Hover and keyboard focus inspect; a tap pins the same card until dismissal. */
export function BattleInsight({label,title,children,color,className='',ariaLabel}:{label:ReactNode;title:string;children:ReactNode;color?:string;className?:string;ariaLabel?:string}){
 const [open,setOpen]=useState(false),[pinned,setPinned]=useState(false),[position,setPosition]=useState<CSSProperties>({visibility:'hidden'}),id=useId();
 const trigger=useRef<HTMLButtonElement>(null),card=useRef<HTMLDivElement>(null),timer=useRef<ReturnType<typeof setTimeout>|undefined>(undefined),suppressFocus=useRef(false);
 function clearTimer(){if(timer.current)clearTimeout(timer.current)}
 function show(){clearTimer();if(!suppressFocus.current)setOpen(true)}
 function close(restore=false){clearTimer();setOpen(false);setPinned(false);if(restore){suppressFocus.current=true;trigger.current?.focus();queueMicrotask(()=>{suppressFocus.current=false})}}
 function delayClose(){clearTimer();if(!pinned)timer.current=setTimeout(()=>{if(!card.current?.contains(document.activeElement)&&document.activeElement!==trigger.current)setOpen(false)},160)}
 useEffect(()=>()=>clearTimer(),[]);
 useLayoutEffect(()=>{if(!open||!trigger.current||!card.current)return;const reposition=()=>{const anchor=trigger.current?.getBoundingClientRect(),box=card.current?.getBoundingClientRect();if(anchor&&box)setPosition(insightPosition(anchor,{width:300,height:box.height},{width:window.innerWidth,height:window.innerHeight}))};reposition();window.addEventListener('resize',reposition);window.addEventListener('scroll',reposition,true);return()=>{window.removeEventListener('resize',reposition);window.removeEventListener('scroll',reposition,true)}},[open,children]);
 useEffect(()=>{if(!open)return;const escape=(event:KeyboardEvent)=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();close(pinned)}else if(/^[1-5mgu]$/i.test(event.key)&&(trigger.current===event.target||card.current?.contains(event.target as Node))){event.stopPropagation()}};const outside=(event:PointerEvent)=>{const target=event.target as Node;if(!trigger.current?.contains(target)&&!card.current?.contains(target))close()};const another=(event:Event)=>{if((event as CustomEvent<string>).detail!==id)close()};document.addEventListener('keydown',escape,true);document.addEventListener('pointerdown',outside);document.addEventListener('hex-battle-insight',another);document.dispatchEvent(new CustomEvent('hex-battle-insight',{detail:id}));return()=>{document.removeEventListener('keydown',escape,true);document.removeEventListener('pointerdown',outside);document.removeEventListener('hex-battle-insight',another)}},[open,pinned,id]);
 return <><button ref={trigger} type="button" className={`b24-insight-trigger ${className}`} style={{'--insight-color':color} as CSSProperties} aria-label={ariaLabel??title} aria-haspopup="dialog" aria-expanded={open} aria-controls={open?id:undefined} onPointerEnter={event=>{if(event.pointerType==='mouse')show()}} onPointerLeave={delayClose} onFocus={show} onBlur={delayClose} onClick={()=>{clearTimer();if(pinned)close();else{setPinned(true);setOpen(true)}}}>{label}</button>{open&&typeof document!=='undefined'&&createPortal(<div ref={card} id={id} className="b24-insight" role="dialog" aria-modal="false" aria-label={title} style={position} onPointerEnter={clearTimer} onPointerLeave={delayClose} onFocus={clearTimer} onBlur={delayClose}><header><strong>{title}</strong><button type="button" aria-label={`Close ${title} details`} onClick={()=>close(true)}>×</button></header>{children}</div>,trigger.current?.closest('dialog')??document.body)}</>;
}

export function StatusChips({statuses,label='Active conditions'}:{statuses:Partial<Record<StatusId,Status>>;label?:string}){
 const entries=activeStatusInsights(statuses);if(!entries.length)return null;
 return <div className="b24-statuses" aria-label={label}>{entries.map(entry=><BattleInsight key={entry.id} title={entry.name} color={entry.color} ariaLabel={`${entry.name}${entry.powerLabel?` ${entry.powerLabel}`:''}, ${entry.durationLabel}. Inspect effect.`} label={<><span aria-hidden="true" className="b24-status-symbol">{entry.symbol}</span><span>{entry.name}{entry.id==='ward'?` ${entry.power}`:''}</span><small>{entry.turns}r</small></>}><p className="b24-insight-duration">{entry.durationLabel} · active now</p><p>{entry.effect}</p><p className="b24-insight-counter">{entry.clearRule}</p></BattleInsight>)}</div>;
}

export function CombatVitals({unit}:{unit:{hp:number;maxHp:number;flux:number;maxFlux:number}}){return <small className="b24-vitals"><span className="b24-health" style={{'--fill':`${Math.max(0,Math.min(100,unit.hp/unit.maxHp*100))}%`} as CSSProperties}><b>{unit.hp}</b>/{unit.maxHp} HP</span><span className="b24-flux" style={{'--fill':`${Math.max(0,Math.min(100,unit.flux/unit.maxFlux*100))}%`} as CSSProperties}><b>{unit.flux}</b>/{unit.maxFlux} Flux</span></small>}
