"use client";

import {useId, useRef, useState, type KeyboardEvent} from 'react';
import {CHAMPIONS, type GameState, type Point, type Unit} from '../../lib/game';
import {legalTargets, movementPath, previewPush} from '../../lib/rules';

type BoardProps = {
  state: GameState;
  selected: string | null;
  kind: 'move' | 'cast';
  onCell: (q: number, r: number) => void;
  onHover?: (q: number, r: number) => void;
  interactive?: boolean;
  pending?: Point | null;
  previousState?: GameState;
};

const colors: Record<string, string> = {
  water:'#a0ccd8', fire:'#dca17c', air:'#d2dfbe', earth:'#c1ad8d',
  light:'#e8d590', dark:'#b7a3c7', steam:'#c1dbd6', bloom:'#a4c493',
  glass:'#e6af98', rift:'#c7a5d9', plain:'#b9c8a5', none:'#b9c8a5', wall:'#8c9585',
};
const symbols: Record<string, string> = {
  water:'≈', fire:'◆', air:'↝', earth:'⬡', light:'✦', dark:'☾',
  steam:'≋', bloom:'✿', glass:'◇', rift:'◈',
};
const champion = (id: string) => CHAMPIONS.find(entry => entry.id === id)!;
const cellKey = (point: Point) => `${point.q},${point.r}`;
const same = (a: Point, b: Point) => a.q === b.q && a.r === b.r;
const position = (point: Point) => ({x:360 + Math.sqrt(3) * 43 * (point.q + point.r / 2), y:315 + 64.5 * point.r});
const alive = (unit: Unit) => unit.hp > 0 && unit.respawn === undefined;
const guarded = (unit: Unit) => Boolean(unit.guard);
const hexPoints = (x: number, y: number, size: number) => Array.from({length:6}, (_, index) => {
  const angle = (index * 60 - 30) * Math.PI / 180;
  return `${x + size * Math.cos(angle)},${y + size * Math.sin(angle)}`;
}).join(' ');

/** Stable champion nodes live outside the tile layer, so accepted moves can animate. */
export default function Board({state, selected, kind, onCell, onHover, interactive=false, pending=null, previousState}: BoardProps) {
  const instance = useId().replace(/:/g, '');
  const [hovered, setHovered] = useState<Point | null>(null);
  const [focused, setFocused] = useState('0,0');
  const tileRefs = useRef(new Map<string, SVGGElement>());
  const unit = state.units.find(entry => entry.id === selected && alive(entry));
  const targets = new Set((selected && interactive ? legalTargets(state, selected, kind) : []).map(cellKey));
  const aim = pending || hovered;
  const validAim = aim && targets.has(cellKey(aim)) ? aim : null;
  const route = kind === 'move' && unit && validAim ? movementPath(state, unit, validAim) : null;
  const routePoints = unit && route ? [unit, ...route].map(point => {const p=position(point); return `${p.x},${p.y}`;}).join(' ') : '';
  const aimPosition = validAim ? position(validAim) : null;
  const pushed = kind === 'cast' && unit && validAim ? previewPush(state,unit.id,validAim.q,validAim.r) : undefined;
  const units = state.units.filter(alive);

  function inspect(point: Point) {
    setHovered({q:point.q, r:point.r});
    onHover?.(point.q, point.r);
  }
  function navigate(event: KeyboardEvent<SVGGElement>, point: Point) {
    if (!interactive) return;
    if (event.key === 'Enter' || event.key === ' ') {event.preventDefault();onCell(point.q,point.r);return;}
    const steps: Record<string, Point> = {ArrowLeft:{q:-1,r:0}, ArrowRight:{q:1,r:0}, ArrowUp:{q:0,r:-1}, ArrowDown:{q:0,r:1}};
    const step=steps[event.key]; if(!step)return;
    event.preventDefault();
    const next=state.cells.find(cell=>cell.q===point.q+step.q&&cell.r===point.r+step.r);
    if(next){setFocused(cellKey(next));tileRefs.current.get(cellKey(next))?.focus();}
  }

  return <svg className={`board tactical-board ${pending?'has-pending':''}`} viewBox="88 68 544 500" role="group" aria-label="Wellspring hex battlefield" aria-describedby={`${instance}-help`} onMouseLeave={()=>setHovered(null)}>
    <title>Wellspring battlefield</title>
    <desc id={`${instance}-help`}>Three wells on a shared hex battlefield. Team one has round green markers; team two has coral diamond markers. Health is shown beneath each portrait. Arrow keys explore hexes; Enter selects. {pending?`Previewing ${kind} to hex ${pending.q}, ${pending.r}. Confirm with the action controls.`:''}</desc>
    <defs>
      <filter id={`${instance}-shadow`} x="-35%" y="-35%" width="170%" height="190%"><feDropShadow dx="0" dy="3" stdDeviation="2.5" floodColor="#233b2d" floodOpacity=".24"/></filter>
      <linearGradient id={`${instance}-tile-light`} x1="0" y1="0" x2=".7" y2="1"><stop stopColor="#ffffff" stopOpacity=".18"/><stop offset="1" stopColor="#263b29" stopOpacity=".07"/></linearGradient>
      <radialGradient id={`${instance}-well`}><stop stopColor="#fff3bd"/><stop offset=".5" stopColor="#c1dcb6"/><stop offset="1" stopColor="#397e6e"/></radialGradient>
      <pattern id={`${instance}-grain`} width="17" height="17" patternUnits="userSpaceOnUse"><circle cx="3" cy="4" r=".65" fill="#3b563c" opacity=".12"/><path d="M12 11h2" stroke="#fff" opacity=".2"/></pattern>
      <clipPath id={`${instance}-portrait`}><circle r="24"/></clipPath>
      <marker id={`${instance}-arrow`} viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M1 1l7 4-7 4" fill="none" stroke="#f8f4d3" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></marker>
    </defs>
    <ellipse cx="360" cy="331" rx="263" ry="225" fill="#364e31" opacity=".07"/>
    <g className="board-tiles">{state.cells.map(cell=>{
      const {x,y}=position(cell), occupant=units.find(entry=>same(entry,cell));
      const active=occupant?.id===selected, valid=targets.has(cellKey(cell)), chosen=Boolean(pending&&same(pending,cell));
      const surface=cell.terrain!=='plain'&&cell.terrain!=='none';
      const oldCell=previousState?.cells.find(entry=>same(entry,cell));
      const changed=oldCell&&oldCell.terrain!==cell.terrain;
      const label=`Hex ${cell.q}, ${cell.r}${cell.well?', scoring well':''}, ${cell.terrain}${cell.ttl!==undefined?`, ${cell.ttl} ${state.rulesVersion===2?'turn':'round'} endings remaining`:''}${occupant?`, ${champion(occupant.championId).name}, team ${occupant.owner+1}, ${occupant.hp} of ${occupant.maxHp} health${guarded(occupant)?', guarded':''}`:''}${valid?`, legal ${kind} target`:''}${chosen?', awaiting confirmation':''}`;
      return <g key={cellKey(cell)} ref={node=>{if(node)tileRefs.current.set(cellKey(cell),node);else tileRefs.current.delete(cellKey(cell));}} className={`hex ${valid?'valid':''} ${active?'selected':''} ${chosen?'pending':''} ${cell.well?'well-hex':''} ${surface?'has-surface':''}`} role={interactive?'button':undefined} tabIndex={interactive?(focused===cellKey(cell)?0:-1):undefined} aria-label={label} aria-pressed={interactive?chosen||active:undefined} onClick={()=>{inspect(cell);if(interactive)onCell(cell.q,cell.r);}} onKeyDown={event=>navigate(event,cell)} onMouseEnter={()=>inspect(cell)} onFocus={()=>{setFocused(cellKey(cell));inspect(cell);}}>
        <title>{label}</title>
        <polygon points={hexPoints(x,y+7,41)} fill="#6e8564" stroke="#61765b" strokeWidth="1.5"/>
        <polygon className="tile" points={hexPoints(x,y,41)} fill={colors[cell.terrain]||colors.plain} stroke={chosen?'#fff3b6':active?'#fff9dd':valid?(kind==='move'?'#f5ffe6':'#f8d7b4'):'#dde4ca'} strokeWidth={chosen?4:active?3:valid?2.5:1.1}/>
        <polygon className="tile-light" points={hexPoints(x,y,40)} fill={`url(#${instance}-tile-light)`}/>
        <polygon points={hexPoints(x,y,39)} fill={`url(#${instance}-grain)`}/>
        <path d={`M${x-30} ${y-18}L${x} ${y-35}L${x+30} ${y-18}`} stroke="#fff" fill="none" opacity=".3" strokeWidth="1.5"/>
        {cell.well&&<g className="well-art"><polygon points={hexPoints(x,y,34)} fill="none" stroke="#456d58" strokeWidth="3"/><polygon points={hexPoints(x,y,30)} fill="none" stroke="#f7e5a4" strokeWidth="2"/><circle cx={x} cy={y} r="23" fill="#3f705c" stroke="#436f5d" strokeWidth="2"/><circle cx={x} cy={y} r="18" fill={`url(#${instance}-well)`}/>{!occupant&&<><path d={`M${x} ${y-13}l8 13-8 13-8-13Z`} fill="none" stroke="#fff5cb" strokeWidth="2.2"/><text className="well-value" x={x} y={y+34} textAnchor="middle">{cell.terrain==='rift'?'+2':'+1'}</text></>}{occupant&&<path d={`M${x-29} ${y-17}L${x} ${y-34}L${x+29} ${y-17}`} fill="none" stroke={occupant.owner===0?'#286a57':'#ad523d'} strokeWidth="5" strokeLinecap="round"/>}</g>}
        {!occupant&&surface&&!cell.well&&<text x={x} y={y+8} textAnchor="middle" className="surface-icon">{symbols[cell.terrain]||'▧'}</text>}
        {surface&&cell.ttl!==undefined&&<g className="surface-lifetime" transform={`translate(${x+25} ${y+19})`}>{Array.from({length:Math.min(4,cell.ttl)},(_,index)=><circle key={index} cx="0" cy={index*4.5} r="1.6" fill="#334d3d" opacity=".75"/>)}</g>}
        {valid&&!occupant&&<g className="target-cue" transform={`translate(${x} ${y})`}>{kind==='move'?<circle r="7" fill="#f9ffe8" stroke="#466e55" strokeWidth="2"/>:<><path d="M-8 0h16M0-8v16" stroke="#754e31" strokeWidth="4"/><path d="M-7 0h14M0-7v14" stroke="#fff0cb" strokeWidth="2"/></>}</g>}
        {chosen&&<polygon className="pending-outline" points={hexPoints(x,y,35)} fill="none" stroke="#fff8d5" strokeWidth="2" strokeDasharray="5 4"/>}
        {changed&&<polygon key={`${state.version}-${cellKey(cell)}`} className="terrain-flash" points={hexPoints(x,y,38)} fill="none" stroke="#fff6cb" strokeWidth="4"/>}
      </g>;
    })}</g>
    {unit&&validAim&&<g className="board-aim" aria-hidden="true" pointerEvents="none">
      {routePoints&&<><polyline points={routePoints} fill="none" stroke="#365847" strokeWidth="7" strokeLinecap="round" strokeLinejoin="round" opacity=".55"/><polyline points={routePoints} fill="none" stroke="#f8f4d3" strokeWidth="3" strokeDasharray="5 5" strokeLinecap="round" strokeLinejoin="round" markerEnd={`url(#${instance}-arrow)`}/></>}
      {kind==='cast'&&aimPosition&&<><line x1={position(unit).x} y1={position(unit).y} x2={aimPosition.x} y2={aimPosition.y} stroke="#553c32" strokeWidth="5" opacity=".42"/><line x1={position(unit).x} y1={position(unit).y} x2={aimPosition.x} y2={aimPosition.y} stroke="#ffedbd" strokeWidth="2" strokeDasharray="4 5"/><circle cx={aimPosition.x} cy={aimPosition.y} r="33" fill="none" stroke="#fff0c2" strokeWidth="3" strokeDasharray="8 5"/>{pushed&&<><polygon points={hexPoints(position(pushed).x,position(pushed).y,34)} fill="#f7e7ae" fillOpacity=".16" stroke="#654d35" strokeDasharray="4 4" strokeWidth="2"/><line x1={aimPosition.x} y1={aimPosition.y} x2={position(pushed).x} y2={position(pushed).y} stroke="#574635" strokeWidth="7" opacity=".7"/><line x1={aimPosition.x} y1={aimPosition.y} x2={position(pushed).x} y2={position(pushed).y} stroke="#f8f4d3" strokeWidth="3" markerEnd={`url(#${instance}-arrow)`}/></>}</>}
    </g>}
    <g className="board-units" pointerEvents="none" aria-hidden="true">{units.map(entry=>{
      const {x,y}=position(entry),active=entry.id===selected,cell=state.cells.find(cell=>same(cell,entry))!;
      const old=previousState&&state.version>previousState.version?previousState.units.find(unit=>unit.id===entry.id):undefined;
      // A final-action defeat may already include the following turn's respawn.
      // Do not describe that position-and-Health reset as an ordinary healing hit.
      const hpDifference=old&&alive(old)&&(same(old,entry)||entry.hp<old.hp)?entry.hp-old.hp:0,returned=old&&!alive(old),shielded=guarded(entry);
      const badgeColor=entry.owner===0?'#285e4d':'#a64f39';
      return <g key={entry.id} className={`board-unit ${active?'is-selected':''} ${shielded?'is-guarded':''}`} style={{transform:`translate(${x}px, ${y-4}px)`}}>
        <g filter={`url(#${instance}-shadow)`}><circle className="unit-selection-halo" r="31" fill="none" stroke={active?'#fff6c4':'transparent'} strokeWidth="2.5"/><circle r="28" fill={badgeColor} stroke={active?'#fff7d0':'#e3e8d2'} strokeWidth="2"/><image href={champion(entry.championId).portrait} x="-24" y="-24" width="48" height="48" clipPath={`url(#${instance}-portrait)`} preserveAspectRatio="xMidYMid slice"/>{shielded&&<circle r="29" fill="none" stroke="#f6d681" strokeWidth="2.5" strokeDasharray="9 3"/>}{entry.owner===0?<circle cx="22" cy="-20" r="11" fill={badgeColor} stroke="#f2e9cf" strokeWidth="1.5"/>:<rect x="13" y="-29" width="18" height="18" rx="2" transform="rotate(45 22 -20)" fill={badgeColor} stroke="#f2e9cf" strokeWidth="1.5"/>}<text x="22" y="-15.5" textAnchor="middle" className="unit-team-number">{entry.owner+1}</text><rect x="-24" y="26" width="48" height="18" rx="7" fill="#f4f0dc" stroke="#57725b" strokeWidth="1.2"/><text x="-15" y="39" textAnchor="middle" className="unit-health-number">{entry.hp}</text>{Array.from({length:entry.maxHp},(_,index)=><rect key={index} x={-7+index*5.3} y="32" width="4" height="7" rx="1" fill={index<entry.hp?(entry.hp<=2?'#ad523c':'#42765b'):'#b9c2ae'}/>)}</g>
        {symbols[cell.terrain]&&<g className="occupied-terrain-badge" transform="translate(-25 19)"><circle r="10" fill={colors[cell.terrain]} stroke="#f8f0d1" strokeWidth="1.3"/><text y="4.5" textAnchor="middle">{symbols[cell.terrain]}</text></g>}
        {shielded&&<g className="guard-badge" transform="translate(-23 -21)"><path d="M0-10L10-6v7c0 5-5 9-10 12C-5 10-10 6-10 1v-7Z" fill="#f3dc98" stroke="#77643b" strokeWidth="1.5"/><path d="M-4 0l3 3 6-6" fill="none" stroke="#485b3c" strokeWidth="2"/></g>}
        {cell.well&&<text className="occupied-well-value" x="0" y="-33" textAnchor="middle">{cell.terrain==='rift'?'+2':'+1'}</text>}
        {(hpDifference!==0||returned)&&<text key={`${state.version}-${entry.id}-hp`} className={`unit-feedback ${hpDifference<0?'damage-feedback':'heal-feedback'}`} x="0" y="-41" textAnchor="middle">{returned?'RETURN':hpDifference>0?`+${hpDifference}`:hpDifference}</text>}
        {shielded&&old&&!guarded(old)&&<text key={`${state.version}-${entry.id}-guard`} className="unit-feedback guard-feedback" x="0" y="-42" textAnchor="middle">GUARD</text>}
      </g>;
    })}</g>
    <g className="defeat-effects" pointerEvents="none" aria-hidden="true">{previousState?.units.filter(old=>alive(old)&&!state.units.some(unit=>unit.id===old.id&&alive(unit))).map(old=>{const p=position(old);return <g key={`${state.version}-${old.id}`} transform={`translate(${p.x} ${p.y})`}><circle className="defeat-ring" r="24" fill="none" stroke="#f5e9c1" strokeWidth="3"/><text className="unit-feedback damage-feedback" y="-20" textAnchor="middle">DEFEATED</text></g>;})}</g>
  </svg>;
}
