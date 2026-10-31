'use client';
import {useEffect,useState,type CSSProperties} from 'react';
import ChampionFrames from './ChampionFrames';
import '../visual-tokens.css';
import './hex-home-v41.css';

const modes = [
 {id:'story',href:'/story',name:'Story',players:'Solo',detail:'Defeat each enemy to learn its spell.',symbol:'book',key:'hex-confluence-campaign-session-v20'},
 {id:'tower',href:'/tower',name:'Tower',players:'1–6 players',detail:'Nine seeded floors. Recruit companions and learn spells.',symbol:'tower',key:'hex-confluence-tower-v23'},
 {id:'arena',href:'/skirmish',name:'Arena',players:'2–6 players',detail:'Private team matches or free-for-all.',symbol:'arena',key:'confluence-arena-session-v18'},
] as const;

function ModeMark({kind}:{kind:string}){return <svg viewBox="0 0 40 40" width="36" height="36" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">{kind==='book'?<><path d="M20 10C13 5 8 7 4 9v24c7-3 11-2 16 1 5-3 9-4 16-1V9c-4-2-9-4-16 1v24"/><path d="M9 14h6M9 20h6M25 14h6M25 20h6"/></>:kind==='tower'?<><path d="M10 35h20L27 13H13zM11 6v7h18V6M17 6v7M23 6v7M17 35v-8h6v8M18 19h4"/></>:kind==='party'?<><path d="M14 23h12l4 12H10zM3 28h6M31 28h6"/><circle cx="20" cy="13" r="6"/><circle cx="6" cy="20" r="4"/><circle cx="34" cy="20" r="4"/></>:<><path d="m9 5 22 30M31 5 9 35M7 25l10 7M23 32l10-7M9 5l1 9M31 5l-1 9"/></>}</svg>}

function CampScene(){
 const grass=[[-72,0],[0,0],[72,0],[-108,43],[-36,43],[36,43],[108,43],[-72,86],[0,86],[72,86]];
 return <div className="h41-scene" aria-hidden="true"><svg viewBox="0 0 560 330" className="h41-island" shapeRendering="crispEdges"><ellipse cx="280" cy="278" rx="200" ry="32" fill="#111f1d" opacity=".4"/>{grass.map(([x,y],i)=><g key={i} transform={`translate(${280+x} ${134+y})`}><path d="M-48 0 0-28 48 0 48 35 0 63-48 35Z" fill={i%3===0?'#62513c':'#736044'}/><path d="m0 28 48-28v35L0 63Z" fill="#524b38"/><path d="M-48 0 0-28 48 0 0 28Z" fill={i===1||i===5?'#4d9395':i%3===0?'#879952':'#71864b'}/><path d="M-45-1 0-25 45-1" stroke={i===1||i===5?'#80c2b2':'#b5ba77'} strokeWidth="2" fill="none"/>{i!==1&&i!==5&&<path d="m-17-5 5-2m17 17 7-3m4-17 4-2" stroke="#a4af68" strokeWidth="3"/>}</g>)}<path d="m268 186 18 9 5 66-9 17-8-5z" fill="#68aeb0"/><path d="m279 193 3 77" stroke="#a0d3c3" strokeWidth="3" strokeDasharray="8 14" className="h41-waterfall"/><path d="m326 215 34-17 21 11-35 19z" fill="#b0a27a"/><path d="m326 215 20 13v8l-20-13m20 5 35-19v8l-35 19" fill="#766d54"/></svg><i className="h41-prop h41-oak"/><i className="h41-prop h41-fern"/><i className="h41-prop h41-lantern"/>{[{id:'treevor_mason',x:58,y:36,size:148},{id:'oh_tipi',x:37,y:53,size:152},{id:'s_wayne',x:67,y:62,size:132}].map(actor=><span key={actor.id} className="h41-camp-actor" style={{left:`${actor.x}%`,top:`${actor.y}%`,'--actor-size':`${actor.size}px`} as CSSProperties}><ChampionFrames id={actor.id} size={actor.size}/></span>)}<span className="h41-firefly h41-firefly-a"/><span className="h41-firefly h41-firefly-b"/></div>;
}

export default function HexHome(){
 const [saved,setSaved]=useState<string[]>([]);
 const [towerFriends,setTowerFriends]=useState(false);
 useEffect(()=>{
  const has=(key:string)=>{try{return !!(sessionStorage.getItem(key)||localStorage.getItem(key))}catch{return false}};
  const solo=has('hex-confluence-tower-v23'),friends=has('hex-tower-coop-last-v23');
  setTowerFriends(friends&&!solo);
  setSaved(modes.filter(mode=>has(mode.key)||(mode.id==='tower'&&friends)).map(mode=>mode.id));
 },[]);
 return <main className="h41-home tactics"><section className="h41-welcome" aria-labelledby="hex-title"><div className="h41-title"><h1 id="hex-title">H.E.X.</h1></div><CampScene/></section><nav className="h41-modes" aria-label="Choose a game mode">{modes.map(mode=><a key={mode.id} className={`h41-mode h41-mode-${mode.id}`} href={mode.id==='tower'&&towerFriends?'/tower?play=friends':mode.href}><div className="h41-mode-top"><ModeMark kind={mode.symbol}/><span>{mode.players}</span></div><h2>{mode.name}</h2><p>{mode.detail}</p><strong className="h41-enter">{saved.includes(mode.id)?'Continue':'Play'}<span aria-hidden="true">→</span></strong></a>)}</nav><footer className="h41-foot"><span>Private match codes.</span><a href="/saves">Saves & transfer</a></footer></main>;
}
