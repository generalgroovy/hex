"use client";
import {useEffect, useRef, useState} from 'react';
import IsometricBoard from './components/IsometricBoard';
import type {Player, Point} from '../lib/game';
import {CHAMPIONS, createSimGame, resolveRound, validatePlan, legalMoves, legalCasts, chooseAIPlan, previewPlan, restoreSimState, type SimState, type TeamPlan, type Order} from '../lib/sim';
import './confluence.css';

type Mode = 'practice' | 'online' | 'hotseat';
type Session = {code:string;token:string;seat:Player};
type Room = {code:string;matchId:string;version:number;status:'waiting'|'active'|'finished';yourSeat:Player;players:({name:string;roster:string[]}|null)[];state:SimState|null;rulesVersion:number;locked:[boolean,boolean];yourPlan?:TeamPlan;rematch:[boolean,boolean]};
type ResponseData = {room:Room;code?:string;token?:string;seat?:Player;error?:string};
const DEFAULTS = ['oh_tipi','wa_bidi','treevor_mason'];
const EMPTY:TeamPlan = {orders:[]};
const SYMBOLS:Record<string,string> = {water:'≈',fire:'◆',air:'↝',earth:'⬡',light:'✦',dark:'☾',steam:'≋',magma:'♨',quagmire:'〰',penumbra:'◈'};
const PERSONALITY:Record<string,{spell:string;line:string;role:string}> = {
 oh_tipi:{spell:'Tidecall',line:'“Hold still. This is the gentle wave.”',role:'Water · Shelter & control'},
 wa_bidi:{spell:'Sparkshot',line:'“I measured the explosion. Approximately.”',role:'Fire · Pressure & hazards'},
 grace_reava:{spell:'Crosswind',line:'“You were standing in my breeze.”',role:'Air · Push & reposition'},
 treevor_mason:{spell:'Stonework',line:'“A good foundation. Then the trouble.”',role:'Earth · Shape the ground'},
 haara:{spell:'Daybreak',line:'“Up you get. We’re not finished.”',role:'Light · Heal & sustain'},
 s_wayne:{spell:'Nightfall',line:'“I was here the whole time.”',role:'Dark · Pressure & siphon'},
};
const RECIPES = [
 {a:'fire',b:'water',id:'steam',name:'Steam',text:'Halves combined spell damage, rounded up. Cover made from incoming fire.'},
 {a:'fire',b:'earth',id:'magma',name:'Magma',text:'Burns the occupant for 1 each round. Punish a predictable landing.'},
 {a:'water',b:'earth',id:'quagmire',name:'Quagmire',text:'Entering or leaving costs 2 movement. Make the next escape harder.'},
 {a:'light',b:'dark',id:'penumbra',name:'Penumbra',text:'An occupied well scores 2. A prize for either team.'},
];
const hero = (id:string) => CHAMPIONS.find(c=>c.id===id)!;
const same = (a:Point,b:Point) => a.q===b.q&&a.r===b.r;
const alive = (u:SimState['units'][number]) => u.hp>0&&u.respawn===undefined;
const coord = (p:Point) => `${p.q}, ${p.r}`;
function normalizeCode(value:string){const t=value.trim();return (/^https?:\/\//i.test(t)?new URL(t).searchParams.get('room')||'':t).toUpperCase().replace(/[-\s]/g,'')}
function validSession(value:unknown,code:string):value is Session {const s=value as Session|null;return !!s&&s.code===code&&/^[a-f0-9]{64}$/.test(s.token)&&(s.seat===0||s.seat===1)}
async function responseData(response:Response){const d=await response.json() as ResponseData;if(!response.ok)throw new Error(typeof d.error==='string'?d.error:'The match could not be updated. Try again.');if(!d.room||!Number.isInteger(d.room.version))throw new Error('The server returned an unreadable match.');return d}
function Glyph({id}:{id:string}){return <span className={`cf-glyph cf-${id}`} aria-label={id}>{SYMBOLS[id]||'◇'}</span>}

export default function Confluence(){
 const [screen,setScreen]=useState<'camp'|'battle'>('camp'),[mode,setMode]=useState<Mode>('practice');
 const [roster,setRoster]=useState(DEFAULTS),[firstRoster,setFirstRoster]=useState<string[]|null>(null),[joining,setJoining]=useState(false);
 const [name,setName]=useState(''),[code,setCode]=useState(''),[game,setGame]=useState<SimState>(()=>createSimGame());
 const [plan,setPlan]=useState<TeamPlan>(EMPTY),[selected,setSelected]=useState<string|null>(null),[kind,setKind]=useState<'move'|'cast'>('move');
 const [previous,setPrevious]=useState<SimState|undefined>(),[resolving,setResolving]=useState(false);
 const [room,setRoom]=useState<Room|null>(null),[session,setSession]=useState<Session|null>(null),[connected,setConnected]=useState(true),[busy,setBusy]=useState(false);
 const [hotSeat,setHotSeat]=useState<Player>(0),[handoff,setHandoff]=useState(false),[sealedLocal,setSealedLocal]=useState<TeamPlan|null>(null);
 const [error,setError]=useState(''),[notice,setNotice]=useState(''),[rules,setRules]=useState(false),[sound,setSound]=useState(false),[saved,setSaved]=useState(false),[classicSaved,setClassicSaved]=useState(false);
 const epoch=useRef(0),activeSession=useRef<Session|null>(null),revision=useRef(-1),match=useRef(''),requestBusy=useRef(false),gameRef=useRef(game),audio=useRef<AudioContext|null>(null),timer=useRef<ReturnType<typeof setTimeout>|null>(null),dialog=useRef<HTMLDialogElement|null>(null),handoffDialog=useRef<HTMLDialogElement|null>(null),memorySeats=useRef(new Map<string,Session>());
 const seat:Player=mode==='online'?(session?.seat??0):mode==='hotseat'?hotSeat:0;
 const locked=mode==='online'&&!!room?.locked?.[seat];
 const canPlan=screen==='battle'&&game.winner===null&&!busy&&!resolving&&!handoff&&!locked&&(mode!=='online'||(connected&&room?.status==='active'));
 const unit=game.units.find(u=>u.id===selected),champion=unit?hero(unit.championId):null;
 const order=plan.orders.find(o=>o.unitId===selected),plannedPosition=order?.move||unit;
 const targets=canPlan&&unit&&unit.owner===seat&&alive(unit)?kind==='move'?legalMoves(game,unit.id):legalCasts(game,unit.id,plannedPosition):[];
 const names=mode==='online'?[room?.players[0]?.name||'You',room?.players[1]?.name||'Friend']:mode==='practice'?['Your company','Academy rival']:['Player 1','Player 2'];
 const preview=canPlan?previewPlan(game,seat,plan).filter(line=>!CHAMPIONS.some(c=>line.startsWith(c.name+':'))):[];
 function current(e:number,s?:Session){return epoch.current===e&&(!s||activeSession.current?.code===s.code)}
 function readSeat(c:string){const m=memorySeats.current.get(c);if(m)return m;for(const storage of ['localStorage','sessionStorage'] as const){try{const s=JSON.parse(window[storage].getItem(`confluence-room-${c}`)||'null');if(validSession(s,c)){memorySeats.current.set(c,s);return s}}catch{}}return null}
 function saveSeat(s:Session){memorySeats.current.set(s.code,s);for(const storage of ['localStorage','sessionStorage'] as const){try{window[storage].setItem(`confluence-room-${s.code}`,JSON.stringify(s));if(storage==='sessionStorage')setNotice('Your seat is saved for this tab. Keep it open.');return}catch{}}setNotice('Browser storage is unavailable. Keep this tab open to retain your player key.')}
 function chime(type:'select'|'lock'|'resolve'){
  if(!sound)return;try{audio.current??=new AudioContext();const a=audio.current;void a.resume();const notes=type==='resolve'?[294,392,587]:type==='lock'?[330,440]:[520];notes.forEach((f,i)=>{const o=a.createOscillator(),g=a.createGain(),t=a.currentTime+i*.075;o.type='sine';o.frequency.setValueAtTime(f,t);g.gain.setValueAtTime(.035,t);g.gain.exponentialRampToValueAtTime(.001,t+.24);o.connect(g);g.connect(a.destination);o.start(t);o.stop(t+.25)})}catch{}
 }
 function showResolution(next:SimState,passAfter=false){
  const old=gameRef.current;setPrevious(old);gameRef.current=next;setGame(next);setPlan(EMPTY);setNotice('');setSelected(next.units.find(u=>u.owner===(passAfter?0:seat)&&alive(u))?.id||null);setKind('move');setResolving(true);chime('resolve');if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>{setResolving(false);if(passAfter&&next.winner===null)setHandoff(true)},2200);
 }
 function acceptRoom(r:Room,e:number){
  if(!current(e)||activeSession.current?.code!==r.code)return;
  if(r.rulesVersion>=4){location.replace('/?room='+r.code);return} if(r.rulesVersion<3&&r.state){location.replace(`/classic?room=${r.code}`);return}
  setConnected(true);setError(old=>old.includes('Reconnecting to check')?'':old);setNotice(old=>old.startsWith('Reconnecting…')?'':old);if(r.version<=revision.current)return;
  const first=revision.current<0,changedMatch=match.current!==r.matchId;revision.current=r.version;match.current=r.matchId;setRoom(r);
  if(r.state){if(!first&&!changedMatch&&r.state.version>gameRef.current.version){showResolution(r.state);setNotice('')}else if(first||changedMatch){gameRef.current=r.state;setGame(r.state);setPlan(r.yourPlan||EMPTY);setPrevious(undefined);setSelected(r.state.units.find(u=>u.owner===r.yourSeat&&alive(u))?.id||null)}if(r.locked?.[r.yourSeat]&&r.yourPlan)setPlan(r.yourPlan)}
 }
 async function refresh(s:Session,e:number){const res=await fetch(`/api/rooms/${s.code}`,{headers:{Authorization:`Bearer ${s.token}`,'X-Confluence-Protocol':'16'},cache:'no-store',signal:AbortSignal.timeout(12000)});const d=await responseData(res);if(current(e,s))acceptRoom(d.room,e);return d.room}
 function resetRemote(){epoch.current++;activeSession.current=null;revision.current=-1;match.current='';requestBusy.current=false;setSession(null);setRoom(null);setBusy(false);setConnected(true);if(timer.current)clearTimeout(timer.current);setResolving(false)}
 useEffect(()=>{
  try{setSaved(!!localStorage.getItem('confluence-sim-local'));setClassicSaved(!!localStorage.getItem('confluence-local'));setName(localStorage.getItem('confluence-name')||'');setSound(localStorage.getItem('confluence-sound')==='on')}catch{}
  const raw=new URLSearchParams(location.search).get('room');if(raw){try{const c=normalizeCode(raw);setCode(c);setMode('online');setJoining(true);const s=readSeat(c);if(s){activeSession.current=s;setSession(s);setScreen('battle')}}catch{setError('This invitation does not contain a valid match code.')}}
  return()=>{if(timer.current)clearTimeout(timer.current)};
 },[]);
 useEffect(()=>{if(screen==='battle'&&mode!=='online'){try{localStorage.setItem('confluence-sim-local',JSON.stringify({game,mode,plan,hotSeat,handoff,sealedLocal}));setSaved(true)}catch{}}},[game,mode,plan,hotSeat,handoff,sealedLocal,screen]);
 useEffect(()=>{
  if(!session||mode!=='online'||screen!=='battle')return;
  const e=epoch.current;let gone=false,pending=false;const poll=async()=>{if(gone||pending||!current(e,session))return;pending=true;try{await refresh(session,e)}catch(err){if(!gone&&current(e,session)){setConnected(false);setNotice(`Reconnecting… ${(err as Error).message}`)}}finally{pending=false}};void poll();const id=setInterval(poll,1900);return()=>{gone=true;clearInterval(id)};
 },[session,mode,screen]);
 useEffect(()=>{if(rules)dialog.current?.showModal();else dialog.current?.close()},[rules]);
 useEffect(()=>{if(handoff)handoffDialog.current?.showModal()},[handoff]);
 useEffect(()=>{const key=(e:KeyboardEvent)=>{if(e.target instanceof HTMLInputElement||rules)return;if(e.key==='Escape'){setNotice('');return}if(canPlan&&e.key.toLowerCase()==='m')setKind('move');if(canPlan&&e.key.toLowerCase()==='c')setKind('cast')};window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key)},[canPlan,rules]);
 function chooseMode(m:Mode,join=false){if(requestBusy.current)return;resetRemote();setMode(m);setJoining(join);setFirstRoster(null);setError('')}
 function home(){resetRemote();setScreen('camp');setHandoff(false);setError('');setNotice('');history.replaceState(null,'','/');window.scrollTo({top:0})}
 function installGame(next:SimState){gameRef.current=next;setGame(next);setPrevious(undefined);setPlan(EMPTY);setSelected(next.units.find(u=>u.owner===0)?.id||null);setKind('move');setHotSeat(0);setSealedLocal(null);setHandoff(false);setError('');setNotice('');setScreen('battle');window.scrollTo({top:0})}
 async function launch(){
  if(roster.length!==3||requestBusy.current)return;setError('');
  if(mode==='hotseat'&&!firstRoster){setFirstRoster(roster);setRoster([...DEFAULTS]);setNotice('Player 2: choose your three champions.');return}
  if(mode!=='online'){resetRemote();installGame(createSimGame(mode==='hotseat'?[firstRoster!,roster]:[roster,['grace_reava','haara','s_wayne']]));return}
  requestBusy.current=true;setBusy(true);const e=epoch.current;
  try{const c=joining?normalizeCode(code):'';if(joining&&!/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/.test(c))throw new Error('Enter a 12-character match code or invitation link.');const existing=joining?readSeat(c):null;if(!existing){try{localStorage.setItem('confluence-name',name.trim())}catch{}location.assign(c?`/?room=${c}`:'/');return}
   const res=await fetch(`/api/rooms/${c}`,{headers:{Authorization:`Bearer ${existing.token}`,'X-Confluence-Protocol':'16'},signal:AbortSignal.timeout(12000)});
   const d=await responseData(res),s=existing||{code:d.code,token:d.token,seat:d.seat};if(!validSession(s,d.room.code))throw new Error('Your player key was missing. Please reconnect.');saveSeat(s);if(!current(e))return;activeSession.current=s;revision.current=-1;setSession(s);acceptRoom(d.room,e);setScreen('battle');history.replaceState(null,'',`?room=${s.code}`);try{localStorage.setItem('confluence-name',name)}catch{}
  }catch(err){if(current(e))setError((err as Error).message)}finally{if(current(e)){requestBusy.current=false;setBusy(false)}}
 }
 function editOrder(changes:Partial<Order>){if(!canPlan||!unit||unit.owner!==seat||!alive(unit))return;const existing=plan.orders.find(o=>o.unitId===unit.id)||{unitId:unit.id};const next={...existing,...changes};setPlan({orders:[...plan.orders.filter(o=>o.unitId!==unit.id),next]});setError('');chime('select')}
 function cell(q:number,r:number){
  if(!canPlan)return;const p={q,r};
  if(unit&&targets.some(t=>same(t,p))){if(kind==='move'){const cast=order?.cast&&legalCasts(game,unit.id,p).some(t=>same(t,order.cast!))?order.cast:undefined;editOrder({move:p,cast,guard:cast?undefined:true});setKind('cast');setNotice(`${hero(unit.championId).name} will move to ${coord(p)}. Aim a spell or keep Guard.`)}else{editOrder({cast:p,guard:undefined});setNotice(`${PERSONALITY[unit.championId].spell} aimed at ${coord(p)}. It lands after everyone moves.`)}return}
  const u=game.units.find(u=>u.owner===seat&&alive(u)&&same(u,p));if(u){setSelected(u.id);setKind('move');setNotice('')}else setNotice('Choose a highlighted hex. Change champion using the company portraits.');
 }
 async function lockPlan(){
  if(!canPlan||requestBusy.current)return;setError('');let checked:TeamPlan;try{checked=validatePlan(game,seat,plan)}catch(err){setError((err as Error).message);return}chime('lock');
  if(mode==='practice'){try{const ai=chooseAIPlan(game,1);showResolution(resolveRound(game,[checked,ai]))}catch(err){setError((err as Error).message)}return}
  if(mode==='hotseat'){if(hotSeat===0){setSealedLocal(checked);setPlan(EMPTY);setSelected(null);setHandoff(true);setHotSeat(1)}else{try{const next=resolveRound(game,[sealedLocal||EMPTY,checked]);setHotSeat(0);setSealedLocal(null);setHandoff(false);showResolution(next,true)}catch(err){setError((err as Error).message)}}return}
  const s=activeSession.current,e=epoch.current;if(!s||!room)return;requestBusy.current=true;setBusy(true);
  try{const res=await fetch(`/api/rooms/${s.code}/plan`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${s.token}`},body:JSON.stringify({matchId:room.matchId,round:game.round,plan:checked,protocolVersion:3}),signal:AbortSignal.timeout(12000)});if(!res.ok&&res.status===409){const latest=await refresh(s,e);if(current(e,s))setNotice(latest.locked?.[s.seat]?'Your accepted orders are locked. Waiting for your friend.':'The latest round is loaded. Review the board and lock your orders again.');return}const d=await responseData(res);if(current(e,s))acceptRoom(d.room,e)}catch(err){if(current(e,s)){setConnected(false);setError(`${(err as Error).message} Reconnecting to check whether your orders were accepted.`)}}finally{if(current(e,s)){requestBusy.current=false;setBusy(false)}}
 }
 function resume(){resetRemote();try{const s=JSON.parse(localStorage.getItem('confluence-sim-local')||'null');if(!s||!['practice','hotseat'].includes(s.mode))throw new Error('The saved match could not be read.');const g=restoreSimState(s.game);if(s.hotSeat!==0&&s.hotSeat!==1)throw new Error('Saved player seat is invalid.');if(s.mode==='practice'&&(s.hotSeat!==0||s.sealedLocal||s.handoff))throw new Error('The practice save has inconsistent planning data.');if(s.mode==='hotseat'&&s.hotSeat===0&&s.sealedLocal)throw new Error('The local save has unexpected sealed orders.');const p=s.plan&&g.winner===null?validatePlan(g,s.hotSeat,s.plan):EMPTY;const sealed=s.sealedLocal&&g.winner===null?validatePlan(g,0,s.sealedLocal):null;if(s.mode==='hotseat'&&s.hotSeat===1&&!sealed&&g.winner===null)throw new Error('The first team’s sealed orders are missing.');setMode(s.mode);installGame(g);setPlan(p);setHotSeat(s.hotSeat);setSelected(g.units.find(u=>u.owner===s.hotSeat&&alive(u))?.id||null);setSealedLocal(sealed);setHandoff(!!s.handoff)}catch(err){setError(`${(err as Error).message} Your saved data has been kept.`)}}
 async function invite(){if(!session)return;const text=`${location.origin}/?room=${session.code}`;try{await navigator.clipboard.writeText(text);setNotice('Invitation copied. Send it to your friend.')}catch{setNotice(text)}}
 async function rematch(){if(mode!=='online'){installGame(createSimGame([game.units.filter(u=>u.owner===0).map(u=>u.championId),game.units.filter(u=>u.owner===1).map(u=>u.championId)]));return}const s=activeSession.current,e=epoch.current;if(!s||!room||requestBusy.current)return;requestBusy.current=true;setBusy(true);try{const res=await fetch(`/api/rooms/${s.code}/rematch`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${s.token}`},body:JSON.stringify({version:room.version,protocolVersion:16}),signal:AbortSignal.timeout(12000)});if(res.status===409){const latest=await refresh(s,e);if(current(e,s))setNotice(latest.status==='active'?'Your rematch is ready.':latest.rematch?.[s.seat]?'Your rematch request is saved.':'Your friend requested a rematch. Choose Play again · Frontier to join.');return}const d=await responseData(res);if(current(e,s))acceptRoom(d.room,e)}catch(err){if(current(e,s))setError((err as Error).message)}finally{if(current(e,s)){requestBusy.current=false;setBusy(false)}}}
 function toggleSound(){const value=!sound;setSound(value);try{localStorage.setItem('confluence-sound',value?'on':'off')}catch{}}
 const shownGame=screen==='camp'?createSimGame([roster.length===3?roster:DEFAULTS,['grace_reava','haara','s_wayne']]):game;

 return <main className={`confluence ${screen==='battle'&&(mode!=='online'||room?.state)?'cf-playing':''}`}>
  <header className="cf-header"><button className="cf-brand" onClick={home} aria-label="H.E.X. camp"><span>✧</span><div><strong>H.E.X.</strong></div></button><nav aria-label="Game controls"><button className="cf-quiet" onClick={()=>setRules(true)}>Field guide</button><button className="cf-quiet cf-sound" aria-label={sound?'Mute sound':'Enable sound'} aria-pressed={sound} onClick={toggleSound}>{sound?'♪':'♪ Off'}</button></nav></header>{screen==='battle'&&mode==='online'&&game.winner!==null&&<p className="cf-muted">Play again starts the new Frontier rules after both players agree: a larger seeded map, four affinity points and a unique signature for each champion.</p>}
  {screen==='camp'&&<section className="cf-camp">
   <div className="cf-camp-stage"><div className="cf-location"><span>01</span><div><small>WELLSPRING</small><h1>The Conservatory</h1></div></div><IsometricBoard state={shownGame} plan={EMPTY} player={0} selected={null} kind="move" interactive={false} onCell={()=>{}}/><div className="cf-camp-rule"><Glyph id="fire"/><span>+</span><Glyph id="water"/><span>=</span><Glyph id="steam"/><strong>Steam.</strong><p>Your spells. Their spells. One shared battlefield.</p></div></div>
   <div className="cf-camp-panel"><div className="cf-section-heading"><div><small>ASSEMBLE YOUR COMPANY</small><h2>{firstRoster?'Player 2’s company':'Three mages. One plan.'}</h2></div><span className="cf-count">{roster.length}/3</span></div>
    <p className="cf-instruction">Both teams move and cast together. Read the rival. Combine your elements. Hold the wells.</p>
    <div className="cf-roster-picker">{CHAMPIONS.map(c=><button key={c.id} className={`cf-recruit ${roster.includes(c.id)?'is-picked':''}`} aria-pressed={roster.includes(c.id)} aria-label={`Choose ${c.name}`} disabled={busy} onClick={()=>{if(roster.includes(c.id))setRoster(roster.filter(id=>id!==c.id));else if(roster.length<3)setRoster([...roster,c.id]);else setNotice('Choose three: deselect a champion to make room.')}}><img src={c.portrait} alt=""/><span className="cf-recruit-tick">{roster.includes(c.id)?'✓':'+'}</span><div><strong>{c.name}</strong><small><Glyph id={c.element}/>{c.ancestry} · {c.element}</small></div></button>)}</div>
    <div className="cf-mode-tabs" role="group" aria-label="Play mode"><button aria-pressed={mode==='practice'} onClick={()=>chooseMode('practice')}>Practice</button><button aria-pressed={mode==='online'&&!joining} onClick={()=>chooseMode('online')}>Host friend</button><button aria-pressed={mode==='online'&&joining} onClick={()=>chooseMode('online',true)}>Join code</button><button aria-pressed={mode==='hotseat'} onClick={()=>chooseMode('hotseat')}>Pass & play</button></div>
    {mode==='online'&&<div className="cf-fields"><label>Your name<input value={name} maxLength={24} onChange={e=>setName(e.target.value)} placeholder="Wellspring mage" autoComplete="nickname"/></label>{joining&&<label>Match code or invitation<input value={code} onChange={e=>setCode(e.target.value)} placeholder="12-character code" autoComplete="off"/></label>}</div>}
    <button className="cf-primary cf-launch" disabled={busy||roster.length!==3} onClick={()=>void launch()}>{busy?'Opening match…':mode==='practice'?'Enter practice':mode==='hotseat'?firstRoster?'Begin local match':'Choose Player 2’s company':joining?'Join match':'Open Frontier'}<span>↗</span></button>
    <div className="cf-camp-bottom"><span>{mode==='online'?'Public game. Private match code.':mode==='hotseat'?'Hand over the screen between plans.':'No clock. Learn by playing.'}</span>{saved&&<button className="cf-link" onClick={resume}>Resume match</button>}{classicSaved&&<a className="cf-link" href="/classic">Older saved match</a>}</div>
   </div>
  </section>}
  {screen==='battle'&&mode==='online'&&(!room||room.status==='waiting')&&<section className="cf-lobby"><div className="cf-lobby-art">{roster.map(id=><img key={id} src={hero(id).portrait} alt={hero(id).name}/>)}</div><small>PRIVATE MATCH</small><h1>{room?'Your friend has a seat.':'Reconnecting to your match…'}</h1>{room&&<><p>Send the link. They choose a company, then you both plan.</p><div className="cf-code">{session?.code}</div><button className="cf-primary" onClick={()=>void invite()}>Copy invitation link ↗</button><p className="cf-muted">Your player key stays in this browser. Matches last seven days.</p></>}</section>}
  {screen==='battle'&&(mode!=='online'||room?.state)&&<section className="cf-battle">
   <div className="cf-scoreboard">{[0,1].map(p=><div key={p} className={`cf-team-score cf-team-${p}`}><span className="cf-team-sigil">{p===0?'●':'◆'}</span><div><strong>{names[p]}</strong><small>{mode==='online'?(room?.locked?.[p]?'Orders locked':'Planning'):resolving?'Resolving together':mode==='practice'&&p===1?'Planning in secret':p===seat?'Your orders':'Orders hidden'}</small></div><b>{game.scores[p]}<small>/ 8</small></b></div>)}<div className="cf-round"><small>ROUND</small><strong>{game.round}</strong><span>{mode==='online'?connected?'● Online':'Reconnecting':mode==='practice'?'Practice':'Local duel'}</span></div></div>
   <div className="cf-arena-layout"><div className="cf-arena"><div className="cf-battle-caption"><span>THE CONSERVATORY <i>·</i> Hold wells to reach 8</span><span>SIMULTANEOUS ORDERS</span></div>
    <div className={`cf-phase ${resolving?'is-resolving':''}`} role="status"><span>{game.winner!==null?'MATCH COMPLETE':resolving?'EVERYONE ACTS':locked?'ORDERS SEALED':'PLAN TOGETHER'}</span><p>{game.winner!==null?(game.winner==='draw'?'An even match.':`${names[game.winner]} takes the wells.`):resolving?'Move → spells combine → wells score':locked?'Waiting for your friend. Your targets stay hidden.':'Move and aim with each mage. Lock when ready.'}</p></div>
    <IsometricBoard state={game} plan={plan} player={seat} selected={selected} kind={kind} onCell={cell} interactive={canPlan} previousState={previous} resolving={resolving} onReplayChange={setResolving} legalTargets={targets} showOrders={!handoff}/>
    <div className="cf-board-key"><span><i className="cf-key-move"/>Move</span><span><i className="cf-key-cast"/>Aim</span><span>✧ Well +1</span><span>▰ Height extends range</span></div>
    {game.log.length>0&&<div className="cf-round-report" aria-live="polite"><span>{previous?`ROUND ${previous.round} REPORT`:'CURRENT POSITION'}</span><p>{previous?([...game.lastResolution.filter(e=>['reaction','defeat','damage','fizzle','bounce'].includes(e.kind)).slice(0,2).map(e=>e.text),...game.lastResolution.filter(e=>e.kind==='score'&&e.amount).map(e=>e.text)].join(' ')||'Both companies repositioned. No wells scored.'):'Your rivals are aiming at where you might stand. Keep them guessing.'}</p></div>}
   </div>
   <aside className="cf-orders-panel"><div className="cf-section-heading"><small>{names[seat].toUpperCase()}</small><span>{locked?'SEALED':`${plan.orders.length} / 3 PLANNED`}</span></div>
    <div className="cf-company">{game.units.filter(u=>u.owner===seat).map((u,i)=>{const c=hero(u.championId),o=plan.orders.find(o=>o.unitId===u.id);return <button key={u.id} className={`cf-unit ${selected===u.id?'is-selected':''} ${!alive(u)?'is-down':''}`} disabled={!canPlan||!alive(u)} aria-label={`Plan ${c.name}`} aria-pressed={selected===u.id} onClick={()=>{setSelected(u.id);setKind('move');setNotice('');chime('select')}}><div className="cf-unit-portrait"><img src={c.portrait} alt=""/><b>{i+1}</b></div><div className="cf-unit-copy"><strong>{c.name}</strong><span><Glyph id={c.element}/>{!alive(u)?'Recovering':o?.cast?PERSONALITY[c.id].spell:'Guard'}{o?.move?' · Move':''}</span><div className="cf-hp" aria-label={`${u.hp} of ${u.maxHp} health`}>{Array.from({length:u.maxHp},(_,i)=><i key={i} className={i<u.hp?'is-full':''}/>)}</div></div><span className="cf-order-mark">{o?.cast?'✦':o?.move?'↗':'◇'}</span></button>})}</div>
    {champion&&unit&&<div className="cf-selected"><div className="cf-selected-title"><Glyph id={champion.element}/><div><h2>{champion.name}</h2><small>{PERSONALITY[champion.id].role}</small></div><span>{unit.hp}<small> HP</small></span></div><p className="cf-bark">{PERSONALITY[champion.id].line}</p><p className="cf-ability">{champion.description}</p>
     <div className="cf-order-controls"><button aria-pressed={kind==='move'} disabled={!canPlan} onClick={()=>setKind('move')}><span>↗</span><b>Move</b><small>{order?.move?coord(order.move):'Up to 2 steps'}</small></button><button aria-pressed={kind==='cast'} disabled={!canPlan} onClick={()=>setKind('cast')}><span>{SYMBOLS[champion.element]}</span><b>Aim spell</b><small>{order?.cast?coord(order.cast):PERSONALITY[champion.id].spell}</small></button><button aria-pressed={!order?.cast} disabled={!canPlan} onClick={()=>editOrder({cast:undefined,guard:true})}><span>◇</span><b>Guard</b><small>Reduce damage</small></button></div>
     <p className="cf-aim-help">{kind==='move'?'Tap a blue hex to plan a move. Your spell fires from there.':'Tap a gold hex to aim. Targets are hexes: moving enemies can dodge.'}</p>
     <div className="cf-order-summary"><span>{order?.move?`Move to ${coord(order.move)}`:'Hold position'} → {order?.cast?`${PERSONALITY[champion.id].spell} at ${coord(order.cast)}`:'Guard'}</span><button className="cf-link" disabled={!canPlan||!order} onClick={()=>{setPlan({orders:plan.orders.filter(o=>o.unitId!==unit.id)});setKind('move')}}>Reset</button></div>
    </div>}
    {preview.length>0&&<div className="cf-plan-feedback" aria-live="polite">{preview.map((line,i)=><p key={i}>{line}</p>)}</div>}
    <div className="cf-lock-panel">{game.winner===null?<><button className="cf-primary cf-lock" disabled={!canPlan} onClick={()=>void lockPlan()}>{resolving?'Resolving…':locked?'✓ Orders locked':busy?'Locking…':'Lock team orders'}<span>⟶</span></button><small>{locked?'Your friend sees only that you are ready.':'Unassigned mages hold and Guard. Orders stay editable until locked.'}</small></>:<><h2>{game.winner==='draw'?'Honours even.':game.winner===seat?'Wellspring is yours.':'A lesson from the rival.'}</h2><button className="cf-primary cf-lock" disabled={busy||!!room?.rematch?.[seat]} onClick={()=>void rematch()}>{room?.rematch?.[seat]?'Waiting for rematch…':mode==='online'?'Play again · Frontier ↗':'Play again ↗'}</button></>}</div>
   </aside></div>
   <div className="cf-field-notes"><details><summary>Element combinations <span>Spells meeting on the same hex combine—even across teams.</span></summary><div className="cf-recipes">{RECIPES.map(r=><article key={r.id}><div><Glyph id={r.a}/><small>+</small><Glyph id={r.b}/><strong>{r.name}</strong></div><p>{r.text}</p></article>)}</div></details><details><summary>Battle record</summary><ol>{game.log.slice(-20).map((l,i)=><li key={i}>{l}</li>)}</ol></details>{mode==='online'&&<button className="cf-link" onClick={()=>void invite()}>Invite · {session?.code}</button>}</div>
  </section>}
  {(notice||error)&&<div className={`cf-message ${error?'is-error':''}`} role={error?'alert':'status'}><p>{error||notice}</p><button aria-label="Dismiss message" onClick={()=>{setError('');setNotice('')}}>×</button></div>}
  {handoff&&<dialog ref={handoffDialog} className="cf-handoff" aria-label="Pass the screen" onCancel={e=>e.preventDefault()}><div><span>◇</span><h2>{resolving?'Round resolved':`Pass to Player ${hotSeat+1}`}</h2><p>{hotSeat===1?'Player 1’s orders are sealed. Hand over the screen before continuing.':'Both companies acted together. Player 1 plans the next round.'}</p><button className="cf-primary" disabled={resolving} onClick={()=>{setHandoff(false);setSelected(game.units.find(u=>u.owner===hotSeat&&alive(u))?.id||null)}}>{resolving?'Resolving…':`Player ${hotSeat+1}: ready`}</button></div></dialog>}
  <dialog className="cf-guide" ref={dialog} onCancel={()=>setRules(false)} onClose={()=>setRules(false)}><button className="cf-guide-close" aria-label="Close field guide" onClick={()=>setRules(false)}>×</button><small>WELLSPRING FIELD GUIDE</small><h2>One round. Six intentions.</h2><ol className="cf-guide-steps"><li><b>Plan your three mages.</b><p>Each can move and then cast, or move and Guard. Aim at a hex, not a character. You can revise everything until you lock.</p></li><li><b>Both teams lock in secret.</b><p>No one goes first. Conflicting destinations collide. Both teams’ spells then land together, so even a defeated mage gets their spell off.</p></li><li><b>Make the elements meet.</b><p>Spells landing on the same hex combine before damage. Your rival’s Water can turn your Fire into Steam. Existing surfaces also react.</p></li><li><b>Take the high ground. Hold the wells.</b><p>Higher ground extends cast range; climbing costs movement. Surviving on a well scores at round end. Reach 8 points with a lead to win.</p></li></ol><div className="cf-recipes">{RECIPES.map(r=><article key={r.id}><div><Glyph id={r.a}/><span>+</span><Glyph id={r.b}/><strong>{r.name}</strong></div><p>{r.text}</p></article>)}</div><p className="cf-muted">Downed mages miss a round, then return. Surface effects apply to either team. Guard trades your spell for protection. Ties continue, with a round limit to settle the match.</p><button className="cf-primary" onClick={()=>setRules(false)}>Back to the field</button></dialog>
 </main>;
}












