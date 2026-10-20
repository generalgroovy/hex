"use client";
import {useCallback,useEffect,useMemo,useRef,useState,type CSSProperties} from 'react';
import PixelBattlefield from './components/PixelBattlefield';
import PixelChampion from './components/PixelChampion';
import ElementIcon from './components/ElementIcon';
import SeedMapPreview from './components/SeedMapPreview';
import {normalizeArenaMapId,arenaSeed} from '../lib/arena';
import LeafSprig from './components/LeafSprig';
import SpellFootprint,{SHAPE_NAME} from './components/SpellFootprint';
import {CHAMPIONS,getChampion} from '../lib/roster';
import {ELEMENT_STYLE,STATUS_INK} from '../lib/presentation';
import {SPELLS,getSpell,defaultLoadout,spellCost,validateLoadout} from '../lib/spells';
import {practiceLoadouts} from '../lib/practice';
import {readLoadouts} from '../lib/loadouts';
import {analyzePlan} from '../lib/plan-insights';
import {createClientSessionStore} from '../lib/client-session';
import {gameShortcut} from '../lib/input';
import {RESOLUTION_MS,summarizeExchange} from '../lib/feedback';
import {createGameAudio} from '../lib/game-audio';
import {createSimGame,resolveRound,validatePlan,legalMoves,legalCasts,chooseAIPlan,restoreSimState,spellArea,castAvailability,STATUS_DEFINITIONS,REACTIONS,reactionsFor,POINTS_TO_WIN,MOVE_RANGE,movementBudget,cellElements,type SimState,type TeamPlan,type Order} from '../lib/tactics';
import type {Element,Player,Point} from '../lib/game';
import './visual-tokens.css';
import './tactics.css';

type Mode='practice'|'online'|'hotseat';
type Session={code:string;token:string;seat:Player};
type Loadouts=Record<string,string[]>;
type Room={code:string;matchId:string;version:number;status:'waiting'|'active'|'finished';yourSeat:Player;players:({name:string;roster:string[];loadouts:Loadouts}|null)[];state:SimState|null;rulesVersion:number;mapId:string;locked:[boolean,boolean];yourPlan?:TeamPlan;rematch:[boolean,boolean]};
type ResponseData={room:Room;code?:string;token?:string;seat?:Player;error?:string};
const DEFAULTS=['oh_tipi','wa_bidi','treevor_mason'];
const RIVAL=['grace_reava','haara','s_wayne'];
const EMPTY:TeamPlan={orders:[]};
function freshMapSeed(){return Array.from(crypto.getRandomValues(new Uint32Array(2)),n=>n.toString(36)).join('-').toUpperCase()}
const SAVE_KEY='confluence-tactics-v6';
const ELEMENT_IDS=Object.keys(ELEMENT_STYLE) as Element[];
const alive=(u:SimState['units'][number])=>u.hp>0&&u.respawn===undefined;
const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;
const coord=(p:Point)=>`${p.q}, ${p.r}`;
const cap=(s:string)=>s.charAt(0).toUpperCase()+s.slice(1);
function scaleLabel(s:ReturnType<typeof getSpell>){const count=s.shape==='burst'?1+3*s.radius*(s.radius+1):s.shape==='ring'?6*s.radius:s.shape==='sweep'?1+2*(s.radius||1):s.shape==='wall'?3:0;return `${SHAPE_NAME[s.shape]}${count?` · ${count} hexes`:''}`}
function allLoadouts():Loadouts{return Object.fromEntries(CHAMPIONS.map(c=>[c.id,defaultLoadout(c.id)]))}
function normalizeCode(value:string){const t=value.trim();return (/^https?:\/\//i.test(t)?new URL(t).searchParams.get('room')||'':t).toUpperCase().replace(/[-\s]/g,'')}
function validSession(value:unknown,code:string):value is Session{const s=value as Session|null;return !!s&&s.code===code&&/^[a-f0-9]{64}$/.test(s.token)&&(s.seat===0||s.seat===1)}
async function responseData(response:Response){const d=await response.json() as ResponseData;if(!response.ok)throw new Error(typeof d.error==='string'?d.error:'The match could not be updated. Try again.');if(!d.room||!Number.isInteger(d.room.version))throw new Error('The server returned an unreadable match.');return d}
function Glyph({element}:{element:Element}){return <span className="tx-glyph" style={{color:ELEMENT_STYLE[element].color}} role="img" aria-label={cap(element)}><ElementIcon element={element}/></span>}
function Affinities({id}:{id:string}){return <span className="tx-affinities">{Object.entries(getChampion(id).affinities).map(([e,n])=><span key={e} title={`${cap(e)} affinity ${n}: ${n===2?'1 less Flux':'base Flux cost'}`}><Glyph element={e as Element}/><b aria-label={`${n} affinity points`}>{n===2?"••":"•"}</b><small>{n===2?"−1 Flux":"base"}</small></span>)}</span>}
function StatusList({unit}:{unit:SimState['units'][number]}){return <span className="tx-status-list">{Object.entries(unit.statuses).filter(([,v])=>v&&v.turns>0).map(([id,v])=>{const d=STATUS_DEFINITIONS.find(s=>s.id===id);return <span key={id} title={d?.description} style={{'--status-color':STATUS_INK[id]||'#6b5738'} as CSSProperties}>{d?.symbol||'◇'} {d?.name||id}<small>{v!.turns}</small></span>})}</span>}

export default function V6Game(){
 const [screen,setScreen]=useState<'camp'|'battle'>('camp'),[mode,setMode]=useState<Mode>('practice');
 const [roster,setRoster]=useState(DEFAULTS),[loadouts,setLoadouts]=useState<Loadouts>(allLoadouts),[recruitSlot,setRecruitSlot]=useState(0),[spellSlot,setSpellSlot]=useState(0);
 const [rosterOpen,setRosterOpen]=useState(false);
 const [search,setSearch]=useState(''),[rosterFilter,setRosterFilter]=useState<Element|'all'>('all'),[spellFilter,setSpellFilter]=useState<Element|'affinity'|'all'>('affinity'),[library,setLibrary]=useState(false);
 const [mapSeed,setMapSeed]=useState('WELLSPRING');
 const [firstCompany,setFirstCompany]=useState<{roster:string[];loadouts:Loadouts;mapId:string}|null>(null),[joining,setJoining]=useState(false);
 const [name,setName]=useState(''),[code,setCode]=useState(''),[game,setGame]=useState<SimState>(()=>createSimGame());
 const [plan,setPlan]=useState<TeamPlan>(EMPTY),[selected,setSelected]=useState<string|null>(null),[kind,setKind]=useState<'move'|'cast'>('move'),[spellId,setSpellId]=useState('');
 const [draftAim,setDraftAim]=useState<Point|null>(null),[hoverAim,setHoverAim]=useState<Point|null>(null),[planHistory,setPlanHistory]=useState<TeamPlan[]>([]);
 const [storageWarning,setStorageWarning]=useState('');
 const [soundBusy,setSoundBusy]=useState(false);
 const [previous,setPrevious]=useState<SimState|undefined>(),[resolving,setResolving]=useState(false),[inspect,setInspect]=useState<string|null>(null);
 const [room,setRoom]=useState<Room|null>(null),[session,setSession]=useState<Session|null>(null),[connected,setConnected]=useState(true),[busy,setBusy]=useState(false);
 const [hotSeat,setHotSeat]=useState<Player>(0),[handoff,setHandoff]=useState(false),[sealedLocal,setSealedLocal]=useState<TeamPlan|null>(null);
 const [error,setError]=useState(''),[notice,setNotice]=useState(''),[guide,setGuide]=useState(false),[sound,setSound]=useState(false),[saved,setSaved]=useState(false),[oldSaved,setOldSaved]=useState(false),[v4Saved,setV4Saved]=useState(false),[v5Saved,setV5Saved]=useState(false),[loadoutsReady,setLoadoutsReady]=useState(false);
 const epoch=useRef(0),activeSession=useRef<Session|null>(null),revision=useRef(-1),match=useRef(''),requestBusy=useRef(false),gameRef=useRef(game),audio=useRef<ReturnType<typeof createGameAudio>|null>(null),sessionStore=useRef<ReturnType<typeof createClientSessionStore>|null>(null),timer=useRef<ReturnType<typeof setTimeout>|null>(null),guideDialog=useRef<HTMLDialogElement|null>(null),handoffDialog=useRef<HTMLDialogElement|null>(null),libraryDialog=useRef<HTMLDialogElement|null>(null);
 const seat:Player=mode==='online'?(session?.seat??0):mode==='hotseat'?hotSeat:0;
 const locked=mode==='online'&&!!room?.locked?.[seat];
 const canPlan=screen==='battle'&&game.winner===null&&!busy&&!resolving&&!handoff&&!locked&&(mode!=='online'||(connected&&room?.status==='active'));
 const unit=game.units.find(u=>u.id===selected),champion=unit?getChampion(unit.championId):null;
 const order=plan.orders.find(o=>o.unitId===selected),plannedPosition=order?.move||unit;
 const chosenSpell=unit?getSpell(spellId&&unit.loadout.includes(spellId)?spellId:unit.loadout[0]):null;
 const targets=canPlan&&unit&&unit.owner===seat&&alive(unit)?kind==='move'?legalMoves(game,unit.id):legalCasts(game,unit.id,plannedPosition,chosenSpell?.id):[];
 const candidateAim=canPlan&&kind==='cast'?(draftAim??hoverAim):null;
 const area=unit&&candidateAim&&chosenSpell?spellArea(game,unit.id,chosenSpell.id,candidateAim,plannedPosition):unit&&order?.cast&&order.spellId?spellArea(game,unit.id,order.spellId,order.cast,plannedPosition):[];
 const aimTarget=candidateAim??order?.cast;
 const friendlyExposure=unit&&chosenSpell&&candidateAim&&chosenSpell.harm==='all'&&(chosenSpell.damage>0||!!chosenSpell.harmful?.length||!!chosenSpell.push)?game.units.filter(u=>u.owner===seat&&alive(u)&&area.some(p=>same(p,plan.orders.find(o=>o.unitId===u.id)?.move||u))):[];
 const combinationNames=unit&&chosenSpell&&candidateAim?[...new Set(area.flatMap(p=>{
  const cell=game.cells.find(c=>same(c,p));const elements=new Set<Element>([chosenSpell.element,...(cell?cellElements(cell):[])]);
  for(const o of plan.orders)if(o.unitId!==unit.id&&o.cast&&o.spellId&&spellArea(game,o.unitId,o.spellId,o.cast,o.move).some(c=>same(c,p)))elements.add(getSpell(o.spellId).element);
  return reactionsFor([...elements]).map(id=>REACTIONS.find(r=>r.id===id)!.name);
 }))]:[];
 const canConfirm=!!(canPlan&&unit&&draftAim&&chosenSpell&&targets.some(p=>same(p,draftAim)));
 const names=mode==='online'?[room?.players[0]?.name||'Player 1',room?.players[1]?.name||'Friend']:mode==='practice'?['You','Opponent']:['Player 1','Player 2'];
 const insights=useMemo(()=>canPlan?analyzePlan(game,seat,plan):[],[canPlan,game,seat,plan]);
 const exchange=useMemo(()=>previous?summarizeExchange(previous,game,seat):null,[previous,game,seat]);
 const replayFeedback=useCallback((active:boolean)=>{setResolving(active);if(active&&sound)audio.current?.playResolution(game.lastResolution)},[sound,game.lastResolution]);
 const recruit=getChampion(roster[recruitSlot]||DEFAULTS[0]);
 const equipped=loadouts[recruit.id]||defaultLoadout(recruit.id);
 const shownChampions=CHAMPIONS.filter(c=>(rosterFilter==='all'||c.affinities[rosterFilter])&&`${c.name} ${c.race}`.toLowerCase().includes(search.toLowerCase()));
 const shownSpells=SPELLS.filter(s=>spellFilter==='all'||spellFilter==='affinity'&&recruit.affinities[s.element]||s.element===spellFilter);
 const inspected=game.units.find(u=>u.id===inspect);
 let selectedMapId:string|null=null;try{selectedMapId=normalizeArenaMapId(`reach:${mapSeed}`)}catch{}
 const seedLocked=busy||!!firstCompany;

 function current(e:number,s?:Session){return epoch.current===e&&(!s||activeSession.current?.code===s.code)}
 function sessions(){return sessionStore.current??=createClientSessionStore([{kind:'local',open:()=>window.localStorage},{kind:'session',open:()=>window.sessionStorage}])}
 function readSeat(c:string){const s=sessions().readSeat(c);if(s)reportPersistence(sessions().rememberSeat(s));return s}
 function reportPersistence(p:'local'|'session'|'memory'){setStorageWarning(p==='memory'?'Keep this tab open: browser storage is unavailable. Your player key and online draft cannot survive closing or reloading it.':p==='session'?'Your player key is saved for this tab only. Keep this tab to return to the match.':'')}
 function saveSeat(s:Session){reportPersistence(sessions().rememberSeat(s))}
 function sounds(){return audio.current??=createGameAudio()}
 function chime(type:'select'|'lock'){if(sound)audio.current?.playUi(type)}
 function selectUnit(id:string,next=game){setDraftAim(null);setHoverAim(null);const u=next.units.find(u=>u.id===id);setSelected(id);setKind('move');setSpellId(u?.loadout[0]||'');setInspect(null);setNotice('')}
 function showResolution(next:SimState,passAfter=false){const old=gameRef.current;setPrevious(old);gameRef.current=next;setGame(next);setPlan(EMPTY);setPlanHistory([]);if(activeSession.current)sessions().clearDraft(activeSession.current.code);setNotice('');selectUnit(next.units.find(u=>u.owner===(passAfter?0:seat)&&alive(u))?.id||'',next);setResolving(true);if(sound)audio.current?.playResolution(next.lastResolution);if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>{setResolving(false);if(passAfter&&next.winner===null)setHandoff(true)},RESOLUTION_MS)}
 function acceptRoom(r:Room,e:number){
  if(!current(e)||activeSession.current?.code!==r.code)return;
  if(r.rulesVersion>6){location.replace(`/?room=${r.code}`);return}
  if(r.rulesVersion<6&&r.state){location.replace(`${r.rulesVersion===5?'/v5':r.rulesVersion===4?'/v4':r.rulesVersion===3?'/v3':'/classic'}?room=${r.code}`);return}
  setConnected(true);setError(old=>old.includes('Reconnecting to check')?'':old);setNotice(old=>old.startsWith('Reconnecting…')?'':old);if(r.version<=revision.current)return;
  const first=revision.current<0,changedMatch=match.current!==r.matchId;revision.current=r.version;match.current=r.matchId;setRoom(r);setMapSeed(arenaSeed(r.mapId));
  if(r.state){if(!first&&!changedMatch&&r.state.version>gameRef.current.version)showResolution(r.state);else if(first||changedMatch){const restored=!r.locked?.[r.yourSeat]?sessions().readDraft({code:r.code,matchId:r.matchId,state:r.state,seat:r.yourSeat}):null;gameRef.current=r.state;setGame(r.state);setPlan(r.yourPlan||restored||EMPTY);setPlanHistory([]);setPrevious(undefined);selectUnit(r.state.units.find(u=>u.owner===r.yourSeat&&alive(u))?.id||'',r.state);if(restored?.orders.length)setNotice('Your draft orders were restored.')}if(r.locked?.[r.yourSeat]&&r.yourPlan){setPlan(r.yourPlan);setPlanHistory([]);sessions().clearDraft(r.code)}}
 }
 async function refresh(s:Session,e:number){const res=await fetch(`/api/rooms/${s.code}`,{headers:{Authorization:`Bearer ${s.token}`,'X-Confluence-Protocol':'16'},cache:'no-store',signal:AbortSignal.timeout(12000)});const d=await responseData(res);if(current(e,s))acceptRoom(d.room,e);return d.room}
 function resetRemote(){epoch.current++;activeSession.current=null;revision.current=-1;match.current='';requestBusy.current=false;setSession(null);setRoom(null);setBusy(false);setConnected(true);if(timer.current)clearTimeout(timer.current);audio.current?.cancel();setResolving(false)}
 useEffect(()=>{
  const requestedSeed=new URLSearchParams(location.search).get('seed');let rememberedSeed:string|null=null;try{rememberedSeed=localStorage.getItem('confluence-map-seed-r1')}catch{}try{setMapSeed(arenaSeed(normalizeArenaMapId(`reach:${requestedSeed??rememberedSeed??freshMapSeed()}`)))}catch{if(requestedSeed!==null){setMapSeed(requestedSeed);setError('This map link has an invalid seed. Use 1–24 letters, numbers or hyphens.')}else setMapSeed(freshMapSeed())}
  try{setSaved(!!localStorage.getItem(SAVE_KEY));setOldSaved(!!localStorage.getItem('confluence-sim-local'));setV4Saved(!!localStorage.getItem('confluence-tactics-v4'));setV5Saved(!!localStorage.getItem('confluence-tactics-v5'));setName(localStorage.getItem('confluence-name')||'');setSound(localStorage.getItem('confluence-sound')==='on');const latest=localStorage.getItem('confluence-loadouts-v6')||localStorage.getItem('confluence-loadouts-v5'),l=JSON.parse(latest||localStorage.getItem('confluence-loadouts-v4')||'null');if(l)setLoadouts(readLoadouts(l,!latest))}catch{}finally{setLoadoutsReady(true)}
  const raw=new URLSearchParams(location.search).get('room');if(raw){try{const c=normalizeCode(raw);setCode(c);setMode('online');setJoining(true);const s=readSeat(c);if(s){activeSession.current=s;setSession(s);setScreen('battle')}}catch{setError('This invitation does not contain a valid match code.')}}
  return()=>{if(timer.current)clearTimeout(timer.current);audio.current?.dispose();audio.current=null};
 },[]);
 useEffect(()=>{if(!loadoutsReady)return;try{localStorage.setItem('confluence-loadouts-v6',JSON.stringify(loadouts))}catch{}},[loadouts,loadoutsReady]);
 useEffect(()=>{if(!loadoutsReady||!selectedMapId)return;try{localStorage.setItem('confluence-map-seed-r1',arenaSeed(selectedMapId))}catch{}},[selectedMapId,loadoutsReady]);
 useEffect(()=>{if(screen==='battle'&&mode!=='online'){try{localStorage.setItem(SAVE_KEY,JSON.stringify({game,mode,plan,hotSeat,handoff,sealedLocal}));setSaved(true)}catch{}}},[game,mode,plan,hotSeat,handoff,sealedLocal,screen]);
 useEffect(()=>{if(screen==='battle'&&mode==='online'&&session&&room?.matchId&&room.state&&game.winner===null&&!locked&&!resolving&&!busy){try{const persistence=sessions().saveDraft({code:session.code,matchId:room.matchId,state:game,seat,plan});if(persistence==='memory')setStorageWarning(old=>old||'Your current draft is only in this tab. Keep it open until you lock your orders.')}catch{setStorageWarning(old=>old||'This draft could not be saved. Keep this tab open and review your orders.')}}},[screen,mode,session,room?.matchId,game,seat,plan,locked,resolving,busy]);
 useEffect(()=>{const stop=()=>{if(document.hidden)audio.current?.cancel()};const unlock=()=>{if(sound)void sounds().enable()};document.addEventListener('visibilitychange',stop);window.addEventListener('pointerdown',unlock);window.addEventListener('keydown',unlock);return()=>{document.removeEventListener('visibilitychange',stop);window.removeEventListener('pointerdown',unlock);window.removeEventListener('keydown',unlock)}},[sound]);
 useEffect(()=>{if(!session||mode!=='online'||screen!=='battle')return;const e=epoch.current;let gone=false,pending=false;const poll=async()=>{if(gone||pending||!current(e,session))return;pending=true;try{await refresh(session,e)}catch(err){if(!gone&&current(e,session)){setConnected(false);setNotice(`Reconnecting… ${(err as Error).message}`)}}finally{pending=false}};void poll();const id=setInterval(poll,1900);return()=>{gone=true;clearInterval(id)}},[session,mode,screen]);
 useEffect(()=>{if(guide)guideDialog.current?.showModal();else guideDialog.current?.close()},[guide]);
 useEffect(()=>{if(library)libraryDialog.current?.showModal();else libraryDialog.current?.close()},[library]);
 useEffect(()=>{if(handoff)handoffDialog.current?.showModal();else handoffDialog.current?.close()},[handoff]);
 useEffect(()=>{const key=(e:KeyboardEvent)=>{if(!canPlan||guide||library||handoff)return;const action=gameShortcut(e);if(!action)return;e.preventDefault();if(action==='move'){setKind('move');setDraftAim(null);setHoverAim(null)}else if(action==='guard'){setDraftAim(null);setHoverAim(null);editOrder({cast:undefined,spellId:undefined,guard:true});setKind('move')}else if(action==='undo')undoPlan();else if(action==='cancel'){setDraftAim(null);setHoverAim(null)}else if(unit)chooseSpell(unit.loadout[Number(action.slice(-1))-1])};window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key)},[canPlan,unit,guide,library,handoff,plan,planHistory,draftAim]);
 function chooseMode(m:Mode,join=false){if(requestBusy.current)return;resetRemote();setMode(m);setJoining(join);setFirstCompany(null);setError('')}
 function home(){resetRemote();setScreen('camp');setFirstCompany(null);setHandoff(false);setInspect(null);setError('');setNotice('');setStorageWarning('');history.replaceState(null,'','/v6');window.scrollTo({top:0})}
 function installGame(next:SimState){setMapSeed(arenaSeed(next.mapId));gameRef.current=next;setGame(next);setPrevious(undefined);setPlan(EMPTY);setPlanHistory([]);selectUnit(next.units.find(u=>u.owner===0)?.id||'',next);setHotSeat(0);setSealedLocal(null);setHandoff(false);setError('');setNotice('');setScreen('battle');window.scrollTo({top:0})}
 function companyLoadouts(ids=roster):Loadouts{return Object.fromEntries(ids.map(id=>[id,loadouts[id]||defaultLoadout(id)]))}
 async function launch(){
  if(roster.length!==3||requestBusy.current)return;setError('');
  if((mode!=='online'||!joining)&&!selectedMapId){setError('Use a seed of 1–24 letters, numbers or hyphens.');return}
  if(mode==='hotseat'&&!firstCompany){setFirstCompany({roster:[...roster],loadouts:companyLoadouts(),mapId:selectedMapId!});setRoster([...RIVAL]);setRecruitSlot(0);setNotice('');return}
  if(mode!=='online'){resetRemote();installGame(createSimGame(mode==='hotseat'?[firstCompany!.roster,roster]:[roster,RIVAL],firstCompany?.mapId??selectedMapId!,mode==='hotseat'?[firstCompany!.loadouts,companyLoadouts()]:[companyLoadouts(),practiceLoadouts(RIVAL)]));return}
  requestBusy.current=true;setBusy(true);const e=epoch.current;
  try{const c=joining?normalizeCode(code):'';if(joining&&!/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$/.test(c))throw new Error('Enter a 12-character match code or invitation link.');const existing=joining?readSeat(c):null;if(!existing){try{localStorage.setItem('confluence-name',name.trim())}catch{}location.assign(c?`/?room=${c}`:'/');return}
   const res=await fetch(`/api/rooms/${c}`,{headers:{Authorization:`Bearer ${existing.token}`,'X-Confluence-Protocol':'16'},signal:AbortSignal.timeout(12000)});
   const d=await responseData(res),s=existing||{code:d.code,token:d.token,seat:d.seat};if(!validSession(s,d.room.code))throw new Error('Your player key was missing. Please reconnect.');saveSeat(s);if(joining)sessions().clearPendingJoin(c);if(!current(e))return;activeSession.current=s;revision.current=-1;setSession(s);acceptRoom(d.room,e);setScreen('battle');history.replaceState(null,'',`?room=${s.code}`);try{localStorage.setItem('confluence-name',name)}catch{}
  }catch(err){if(current(e))setError((err as Error).message)}finally{if(current(e)){requestBusy.current=false;setBusy(false)}}
 }
 function revisePlan(next:TeamPlan){setPlanHistory(old=>[...old.slice(-19),plan]);setPlan(next);setError('')}
 function editOrder(changes:Partial<Order>){if(!canPlan||!unit||unit.owner!==seat||!alive(unit))return;const existing=plan.orders.find(o=>o.unitId===unit.id)||{unitId:unit.id};const next={...existing,...changes};revisePlan({orders:[...plan.orders.filter(o=>o.unitId!==unit.id),next]});chime('select')}
 function undoPlan(){if(!canPlan)return;if(draftAim){setDraftAim(null);setHoverAim(null);return}const prior=planHistory.at(-1);if(!prior)return;const edited=game.units.find(u=>JSON.stringify(plan.orders.find(o=>o.unitId===u.id))!==JSON.stringify(prior.orders.find(o=>o.unitId===u.id)));setPlan(prior);setPlanHistory(old=>old.slice(0,-1));if(edited)selectUnit(edited.id);setDraftAim(null);setHoverAim(null);setKind('move');setNotice(edited?`${getChampion(edited.championId).name}’s previous orders restored.`:'Last order edit undone.');setError('')}
 function chooseSpell(id:string){setSpellId(id);setKind('cast');setDraftAim(null);setHoverAim(null);setNotice('')}
 function confirmAim(){if(!canConfirm||!draftAim||!chosenSpell)return;editOrder({cast:draftAim,spellId:chosenSpell.id,guard:undefined});setDraftAim(null);setHoverAim(null);setNotice('')}
 function previewCell(p:Point|null){setHoverAim(canPlan&&kind==='cast'&&p&&targets.some(t=>same(t,p))?p:null)}
 function cell(q:number,r:number){
  if(!canPlan)return;const p={q,r};
  if(unit&&targets.some(t=>same(t,p))){if(kind==='move'){const cast=order?.cast&&legalCasts(game,unit.id,p,order.spellId).some(t=>same(t,order.cast!))?order.cast:undefined;editOrder({move:p,cast,spellId:cast?order?.spellId:undefined,guard:cast?undefined:true});setKind('cast');setDraftAim(null);setHoverAim(null);setNotice(order?.cast&&!cast?'That move puts the planned spell out of reach or blocks its aim. Choose a new target, or Undo to restore it.':'')}else if(chosenSpell){const available=castAvailability(game,unit.id,chosenSpell.id);if(!available.available){setNotice(available.reason||'This spell is not ready.');return}setDraftAim(p);setHoverAim(null);setNotice('')}return}
  const u=game.units.find(u=>alive(u)&&same(u,p));if(u){if(u.owner===seat)selectUnit(u.id);else setInspect(u.id)}else setNotice('Choose a highlighted hex, or select another character.');
 }
 async function lockPlan(){
  if(!canPlan||requestBusy.current)return;if(draftAim){setError('Confirm or cancel your preview before sealing the team.');return}setError('');let checked:TeamPlan;try{checked=validatePlan(game,seat,plan)}catch(err){setError((err as Error).message);return}chime('lock');
  if(mode==='practice'){try{showResolution(resolveRound(game,[checked,chooseAIPlan(game,1)]))}catch(err){setError((err as Error).message)}return}
  if(mode==='hotseat'){if(hotSeat===0){setSealedLocal(checked);setPlan(EMPTY);setPlanHistory([]);setSelected(null);setHandoff(true);setHotSeat(1)}else{try{const next=resolveRound(game,[sealedLocal||EMPTY,checked]);setHotSeat(0);setSealedLocal(null);setHandoff(false);showResolution(next,true)}catch(err){setError((err as Error).message)}}return}
  const s=activeSession.current,e=epoch.current;if(!s||!room)return;requestBusy.current=true;setBusy(true);
  try{const res=await fetch(`/api/rooms/${s.code}/plan`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${s.token}`},body:JSON.stringify({matchId:room.matchId,round:game.round,plan:checked,protocolVersion:6}),signal:AbortSignal.timeout(12000)});if(res.status===409){const latest=await refresh(s,e);if(current(e,s))setNotice(latest.locked?.[s.seat]?'Orders locked. Waiting for your friend.':'The latest round is loaded. Review the board and lock again.');return}const d=await responseData(res);if(current(e,s))acceptRoom(d.room,e)}catch(err){if(current(e,s)){setConnected(false);setError(`${(err as Error).message} Reconnecting to check whether your orders were accepted.`)}}finally{if(current(e,s)){requestBusy.current=false;setBusy(false)}}
 }
 function resume(){resetRemote();try{const s=JSON.parse(localStorage.getItem(SAVE_KEY)||'null');if(!s||!['practice','hotseat'].includes(s.mode))throw new Error('This saved match could not be read.');const g=restoreSimState(s.game);if(s.hotSeat!==0&&s.hotSeat!==1)throw new Error('Saved seat is invalid.');if(s.mode==='practice'&&(s.hotSeat!==0||s.sealedLocal||s.handoff))throw new Error('Saved practice data is inconsistent.');if(s.mode==='hotseat'&&s.hotSeat===0&&s.sealedLocal)throw new Error('Unexpected sealed orders.');const p=s.plan&&g.winner===null?validatePlan(g,s.hotSeat,s.plan):EMPTY;const sealed=s.sealedLocal&&g.winner===null?validatePlan(g,0,s.sealedLocal):null;if(s.mode==='hotseat'&&s.hotSeat===1&&!sealed&&g.winner===null)throw new Error('The first team’s orders are missing.');setMode(s.mode);installGame(g);setPlan(p);setHotSeat(s.hotSeat);selectUnit(g.units.find(u=>u.owner===s.hotSeat&&alive(u))?.id||'',g);setSealedLocal(sealed);setHandoff(!!s.handoff)}catch(err){setError(`${(err as Error).message} Saved data has been kept.`)}}
 async function copySeedLink(){const id=screen==='battle'?game.mapId:selectedMapId;if(!id)return;const link=`${location.origin}/v6?seed=${encodeURIComponent(arenaSeed(id))}`;try{await navigator.clipboard.writeText(link);setNotice('Map link copied.')}catch{setNotice(link)}}
 async function invite(){if(!session)return;const text=`${location.origin}/?room=${session.code}`;try{await navigator.clipboard.writeText(text);setNotice('Invite link copied.')}catch{setNotice(text)}}
 async function rematch(){if(mode!=='online'){const ids=([0,1] as const).map(p=>game.units.filter(u=>u.owner===p).map(u=>u.championId)) as [string[],string[]];const kits=([0,1] as const).map(p=>Object.fromEntries(game.units.filter(u=>u.owner===p).map(u=>[u.championId,u.loadout]))) as [Loadouts,Loadouts];installGame(createSimGame(ids,game.mapId,kits));return}const s=activeSession.current,e=epoch.current;if(!s||!room||requestBusy.current)return;requestBusy.current=true;setBusy(true);try{const res=await fetch(`/api/rooms/${s.code}/rematch`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${s.token}`},body:JSON.stringify({version:room.version,protocolVersion:16}),signal:AbortSignal.timeout(12000)});if(res.status===409){const latest=await refresh(s,e);if(current(e,s))setNotice(latest.status==='active'?'Your rematch is ready.':latest.rematch?.[s.seat]?'Your request is saved.':'Your friend requested a rematch. Choose Play again · Frontier to join.');return}const d=await responseData(res);if(current(e,s))acceptRoom(d.room,e)}catch(err){if(current(e,s))setError((err as Error).message)}finally{if(current(e,s)){requestBusy.current=false;setBusy(false)}}}
 function replaceRecruit(id:string){if(busy)return;const existing=roster.indexOf(id);if(existing>=0){setRecruitSlot(existing);setRosterOpen(false);return}setRoster(roster.map((old,i)=>i===recruitSlot?id:old));setRosterOpen(false);setNotice('')}
 function equip(id:string){if(equipped.includes(id)&&equipped[spellSlot]!==id){setNotice('That spell is already equipped. Choose four different spells.');return}const kit=equipped.map((old,i)=>i===spellSlot?id:old);try{validateLoadout(recruit.id,kit);setLoadouts({...loadouts,[recruit.id]:kit});setNotice(`${getSpell(id).name} equipped in slot ${spellSlot+1}.`)}catch(err){setError((err as Error).message)}}
 async function toggleSound(){if(soundBusy)return;setSoundBusy(true);let value=!sound;try{if(!value){audio.current?.mute();setSound(false)}else{value=await sounds().enable();setSound(value);if(value)audio.current?.playUi('select');else setNotice('Audio could not start. Try enabling sound again after interacting with the game.')}try{localStorage.setItem('confluence-sound',value?'on':'off')}catch{}}finally{setSoundBusy(false)}}

 return <main className={`tactics ${screen==='battle'?'tx-playing':''}`}>
  <header className="tx-header"><button className="tx-brand" onClick={home} aria-label="H.E.X. camp"><span><LeafSprig/></span><span><strong>H.E.X.</strong></span></button><nav aria-label="Game controls"><button onClick={()=>setGuide(true)}>Rules</button><button aria-label={sound?'Mute sound':'Enable sound'} aria-pressed={sound} disabled={soundBusy} onClick={()=>void toggleSound()}>{sound?'♪ On':'♪ Off'}</button></nav></header>{screen==='battle'&&mode==='online'&&game.winner!==null&&<p className="tx-muted">Play again starts the new Frontier rules after both players agree: a larger seeded map, four affinity points and a unique signature for each champion.</p>}
  {storageWarning&&<p className="tx-storage-warning" role="status">{storageWarning}</p>}
  {screen==='camp'&&<div className="tx-camp">
   <section className="tx-play-setup" aria-label="Start a game">
    <div className="tx-mode-tabs" role="group" aria-label="Play mode">
     <button aria-pressed={mode==='practice'} disabled={busy} onClick={()=>chooseMode('practice')}>Practice</button>
     <button aria-pressed={mode==='online'&&!joining} disabled={busy} onClick={()=>chooseMode('online')}>Host</button>
     <button aria-pressed={mode==='online'&&joining} disabled={busy} onClick={()=>chooseMode('online',true)}>Join</button>
     <button aria-pressed={mode==='hotseat'} disabled={busy} onClick={()=>chooseMode('hotseat')}>Local duel</button>
    </div>
    {mode==='online'&&<div className="tx-fields"><label>Your name<input value={name} maxLength={24} onChange={e=>setName(e.target.value)} placeholder="Player" autoComplete="nickname"/></label>{joining&&<label>Match code or invitation<input value={code} onChange={e=>setCode(e.target.value)} placeholder="12-character code" autoComplete="off"/></label>}</div>}
    <div className="tx-start-actions"><button className="tx-primary" disabled={busy} onClick={()=>void launch()}>{busy?'Connecting…':mode==='practice'?'Play':mode==='hotseat'?firstCompany?'Start duel':'Choose Player 2':joining?'Join game':'Open Frontier'}<span aria-hidden="true">→</span></button>{saved&&<button className="tx-resume" onClick={resume}>Resume</button>}</div>
    {(mode!=='online'||!joining)&&<details className="tx-map-options"><summary>Map <code>{mapSeed}</code></summary><div className="tx-seed-picker"><div className="tx-seed-label"><label htmlFor="arena-seed">Map seed</label><button disabled={seedLocked} onClick={()=>{setMapSeed(freshMapSeed());setError('')}}>Randomize</button></div><input id="arena-seed" value={mapSeed} maxLength={24} disabled={seedLocked} onChange={e=>setMapSeed(e.target.value.toUpperCase())} autoComplete="off" autoCapitalize="characters" spellCheck={false}/>{selectedMapId?<SeedMapPreview mapId={selectedMapId}/>:<p className="tx-aim-warning">Use 1–24 letters, numbers or hyphens.</p>}<div className="tx-seed-footer"><button disabled={!selectedMapId||busy} onClick={()=>void copySeedLink()}>Copy map link</button></div></div></details>}
    {(v5Saved||v4Saved||oldSaved)&&<details className="tx-older-saves"><summary>Older saves</summary><div className="tx-save-links">{v5Saved&&<a href="/v5">61-hex match</a>}{v4Saved&&<a href="/v4">Earlier arena</a>}{oldSaved&&<a href="/v3">Original match</a>}</div></details>}
   </section>
   <section className="tx-assembly">
    <h1>{firstCompany?'Player 2’s team':'Your team'}</h1>
    <div className="tx-company-slots" role="group" aria-label="Your three characters">{roster.map((id,i)=><button key={i} className={recruitSlot===i?'is-active':''} aria-label={`Select ${getChampion(id).name}`} aria-pressed={recruitSlot===i} onClick={()=>{setRecruitSlot(i);setSpellSlot(0)}}><span className="tx-slot-number">{i+1}</span><PixelChampion id={id} size={144}/><strong>{getChampion(id).name}</strong><Affinities id={id}/></button>)}</div>
    <button className="tx-change-character" aria-expanded={rosterOpen} onClick={()=>setRosterOpen(!rosterOpen)}>{rosterOpen?'Close characters':`Replace ${recruit.name}`} <span aria-hidden="true">{rosterOpen?'−':'+'}</span></button>
    {rosterOpen&&<div className="tx-recruitment"><div className="tx-roster-toolbar"><label className="tx-search"><span>Find a character</span><input placeholder="Name or ancestry" value={search} onChange={e=>setSearch(e.target.value)}/></label></div>
     <div className="tx-filters" aria-label="Filter characters by affinity"><button aria-pressed={rosterFilter==='all'} onClick={()=>setRosterFilter('all')}>All</button>{ELEMENT_IDS.map(e=><button aria-pressed={rosterFilter===e} key={e} onClick={()=>setRosterFilter(e)}><Glyph element={e}/>{cap(e)}</button>)}</div>
     <div className="tx-roster-grid">{shownChampions.map(c=><button key={c.id} className={roster.includes(c.id)?'is-recruited':''} aria-label={`Recruit ${c.name}`} aria-pressed={roster.includes(c.id)} disabled={busy} onClick={()=>replaceRecruit(c.id)}><PixelChampion id={c.id} size={144} paused/><span className="tx-roster-check">{roster.includes(c.id)?roster.indexOf(c.id)+1:'+'}</span><strong>{c.name}</strong><small>{cap(c.race)}</small><Affinities id={c.id}/></button>)}</div>
     {shownChampions.length===0&&<p className="tx-muted">No characters match.</p>}
    </div>}
   </section>
   <aside className="tx-preparation"><div className="tx-kit-card">
    <div className="tx-kit-title"><h2>{recruit.name}</h2><span>Spells</span></div>
    <div className="tx-kit-list">{equipped.map((id,i)=>{const spell=getSpell(id);return <button key={i} onClick={()=>{setSpellSlot(i);setSpellFilter('affinity');setNotice('');setError('');setLibrary(true)}} aria-label={`Configure spell ${i+1} for ${recruit.name}`}><b>{i+1}</b><Glyph element={spell.element}/><span><strong>{spell.name}</strong><small><SpellFootprint shape={spell.shape}/>{scaleLabel(spell)} · range {spell.range}</small></span><em>{spellCost(recruit.id,spell.id)}<small> Flux</small></em></button>})}</div>
    <div className="tx-kit-tools"><button className="tx-text-button" onClick={()=>setLoadouts({...loadouts,[recruit.id]:defaultLoadout(recruit.id)})}>Reset spells</button><details><summary>Spell costs</summary><p>Any character can equip any spell. Affinity •• costs 1 less Flux; • costs the base amount; other elements cost 1 more.</p></details></div>
   </div></aside>
  </div>}
  {screen==='battle'&&mode==='online'&&(!room||room.status==='waiting')&&<section className="tx-lobby"><div className="tx-lobby-company">{roster.map(id=><PixelChampion key={id} id={id} size={160}/>)}</div><span className="tx-eyebrow">PRIVATE MATCH</span><h1>{room?'Waiting for a player':'Reconnecting to your match…'}</h1>{room&&<><p className="tx-muted">Map seed: <strong>{arenaSeed(room.mapId)}</strong></p><div className="tx-code">{session?.code}</div><button className="tx-primary" onClick={()=>void invite()}>Copy invite link</button><p className="tx-muted">Rejoin from this browser. Rooms expire after seven days.</p></>}</section>}
  {screen==='battle'&&(mode!=='online'||room?.state)&&<section className="tx-battle">
   <div className="tx-scoreboard">{[0,1].map(p=><div key={p} className={`tx-team tx-team-${p}`}><span>{p===0?'●':'◆'}</span><div><strong>{names[p]}</strong><small>{mode==='online'?(room?.locked?.[p]?'Orders locked':'Planning'):resolving?'Resolving':p===seat?'Planning':'Planning'}</small></div><b>{game.scores[p]}<small>/{POINTS_TO_WIN}</small></b></div>)}<div className="tx-round"><small>ROUND</small><b>{game.round}</b><span>{mode==='online'?connected?'● Online':'Reconnecting':mode==='practice'?'Practice':'Local duel'}</span></div></div>
   <p className="tx-objective"><strong>{POINTS_TO_WIN} points to win</strong><span>Wells +1–2 each round · Defeats +1</span></p>
   <div className="tx-battle-grid"><div className="tx-field"><div className="tx-phase" role="status"><span>{game.winner!==null?(game.winner==='draw'?'Draw':`${names[game.winner]} wins`):resolving?'Resolving':locked?'Waiting for opponent':'Plan turn'}</span>{locked&&<p>Your orders are locked.</p>}</div>
    <PixelBattlefield state={game} plan={plan} player={seat} selected={selected} kind={kind} onCell={cell} interactive={canPlan} previousState={previous} resolving={resolving} onReplayChange={replayFeedback} legalTargets={targets} showOrders={!handoff} spellId={candidateAim?chosenSpell?.id:order?.spellId} affectedTargets={area} aimTarget={aimTarget} onPreviewCell={previewCell}/>
    {exchange&&!resolving&&!handoff&&<div className="tx-exchange-strip" role="status"><strong>{exchange.headline}</strong><span>{exchange.details.slice(0,2).join(' · ')||''}</span></div>}
   </div>
   <aside className="tx-orders"><div className="tx-company-heading"><span className="tx-eyebrow">YOUR TEAM</span><span>{locked?'Locked':''}</span></div><div className="tx-battle-company">{game.units.filter(u=>u.owner===seat).map((u,i)=>{const c=getChampion(u.championId),o=plan.orders.find(o=>o.unitId===u.id);return <button key={u.id} disabled={!canPlan||!alive(u)} className={`${selected===u.id?'is-selected':''} ${!alive(u)?'is-down':''}`} aria-label={`Plan ${c.name}`} aria-pressed={selected===u.id} onClick={()=>selectUnit(u.id)}><span className="tx-unit-visual"><PixelChampion id={c.id} size={110} paused/><b>{i+1}</b></span><span className="tx-unit-info"><strong>{c.name}</strong><small>{!alive(u)?'Recovering':o?.cast&&o.spellId?getSpell(o.spellId).name:'Guard'}{o?.move?' · Move':''}</small><span className="tx-resource-bars"><i style={{'--fill':`${u.hp/u.maxHp*100}%`} as CSSProperties} aria-label={`${u.hp} health`}/><i style={{'--fill':`${u.flux/u.maxFlux*100}%`} as CSSProperties} aria-label={`${u.flux} Flux`}/></span></span><span className="tx-unit-numbers">{u.hp}<small>HP</small>{u.flux}<small>FLUX</small></span></button>})}</div>
    {champion&&unit&&<div className="tx-action-panel tx-planning-tray">
     <div className="tx-active-mage"><h2>{champion.name}</h2><span>{unit.hp}<small> HP</small> · {unit.flux}<small> Flux</small></span></div>
     {Object.keys(unit.statuses).length>0&&<div className="tx-current-status"><StatusList unit={unit}/></div>}
     <div className="tx-battle-spells" role="group" aria-label="Four equipped spells">{unit.loadout.map((id,i)=>{
      const s=getSpell(id),a=castAvailability(game,unit.id,id);return <button key={id} className={`${kind==='cast'&&chosenSpell?.id===id?'is-active':''} ${!a.available?'is-unready':''}`} aria-label={`${i+1}. ${s.name}. ${a.cost} Flux. ${scaleLabel(s)}. Reach ${s.range===0?0:Math.max(1,s.range-(unit.statuses.blind?1:0))}.${a.available?'':` ${a.reason}`}`} aria-pressed={kind==='cast'&&chosenSpell?.id===id} disabled={!canPlan} onClick={()=>chooseSpell(id)} style={{'--element-color':ELEMENT_STYLE[s.element].color} as CSSProperties}>
       <span className="tx-spell-key">{i+1}</span><Glyph element={s.element}/><strong>{s.name}</strong><small>{a.cost} Flux · {unit.cooldowns[id]?`${unit.cooldowns[id]}r recovery`:`reach ${s.range===0?0:Math.max(1,s.range-(unit.statuses.blind?1:0))}`}</small><SpellFootprint shape={s.shape}/>
      </button>})}</div>
     {kind==='cast'&&chosenSpell&&<div className="tx-spell-effect"><p>{chosenSpell.description}</p>{chosenSpell.cooldown>0&&<small>Recovery: {chosenSpell.cooldown} round{chosenSpell.cooldown===1?'':'s'}</small>}</div>}
     <div className="tx-aim-summary" aria-live="polite">
      <div><strong>{resolving?'Resolving…':locked?'Orders locked':kind==='move'?(unit.statuses.rooted?'Rooted · cannot move':unit.statuses.chilled?`Chilled · ${movementBudget(unit)} movement points`:`Move · ${movementBudget(unit)} movement points`):candidateAim?`${SHAPE_NAME[chosenSpell!.shape]} · ${area.length} hex${area.length===1?'':'es'} · ${coord(candidateAim)}`:order?.cast&&order.spellId?`✓ ${getSpell(order.spellId).name} · ${coord(order.cast)}`:'Choose a target'}</strong>
       {kind==='cast'&&chosenSpell&&!castAvailability(game,unit.id,chosenSpell.id).available?<small className="tx-aim-warning">{castAvailability(game,unit.id,chosenSpell.id).reason}</small>:candidateAim?<small className={friendlyExposure.length?'tx-aim-warning':''}>{friendlyExposure.length?`Allies in area: ${friendlyExposure.map(u=>getChampion(u.championId).name).join(', ')}`:combinationNames.length?`May form: ${combinationNames.join(' + ')}`:'Targets the hex after movement'}</small>:<small>{kind==='move'&&unit.statuses.rooted?`Rooted: ${unit.statuses.rooted.turns} round${unit.statuses.rooted.turns===1?'':'s'}`:<>{order?.move?`Landing ${coord(order.move)}`:'Hold'} · {order?.cast?'Spell queued':'Guard'}</>}</small>}
      </div>
      {draftAim&&<><button className="tx-primary tx-confirm-aim" disabled={!canConfirm} onClick={confirmAim}>Confirm</button><button className="tx-cancel-aim" aria-label="Cancel aim preview" onClick={()=>{setDraftAim(null);setHoverAim(null)}}>×</button></>}
     </div>
     <div className="tx-command-dock">
      <button className={kind==='move'?'is-active':''} aria-pressed={kind==='move'} disabled={!canPlan} onClick={()=>{setKind('move');setDraftAim(null);setHoverAim(null)}}><b>↗ Move</b><small>{order?.move?coord(order.move):`${movementBudget(unit)} points`}</small></button>
      <button aria-pressed={!order?.cast} disabled={!canPlan} onClick={()=>{editOrder({cast:undefined,spellId:undefined,guard:true});setDraftAim(null);setHoverAim(null);setKind('move')}}><b>◇ Guard</b><small>−1 spell damage · +1 Flux</small></button>
      {game.winner===null?<button className="tx-primary tx-lock" disabled={!canPlan||!!draftAim} onClick={()=>void lockPlan()}>{resolving?'Resolving…':locked?'Locked':busy?'Locking…':'End turn'}<span>⟶</span></button>:<button className="tx-primary tx-lock" disabled={busy||!!room?.rematch?.[seat]} onClick={()=>void rematch()}>{room?.rematch?.[seat]?'Waiting…':mode==='online'?'Play again · Frontier':'Play again'} ↗</button>}
     </div>
     <section className="tx-plan-review" aria-label="Team orders">
      {insights.length>0&&<div className="tx-plan-risks" role="status">{insights.slice(0,2).map(item=><p key={item.id}>{item.text}</p>)}{insights.length>2&&<small>{insights.length-2} more in Orders.</small>}</div>}
      <button className="tx-undo" disabled={!canPlan||(!planHistory.length&&!draftAim)} onClick={undoPlan}>{draftAim?'Cancel preview':'Undo'} <kbd>{draftAim?'Esc':'U'}</kbd></button>
      <details><summary>Orders</summary><ol>{game.units.filter(u=>u.owner===seat).map(u=>{const o=plan.orders.find(item=>item.unitId===u.id);return <li key={u.id}><strong>{getChampion(u.championId).name}</strong><span>{!alive(u)?'Recovering':`${o?.move?`Move ${coord(o.move)}`:'Hold'} → ${o?.cast&&o.spellId?`${getSpell(o.spellId).name} ${coord(o.cast)}`:'Guard'}`}</span></li>})}</ol>{insights.slice(2).map(item=><p className="tx-aim-warning" key={item.id}>{item.text}</p>)}</details>
     </section>
     <div className="tx-unit-tools"><button disabled={!canPlan||!order} onClick={()=>{revisePlan({orders:plan.orders.filter(o=>o.unitId!==unit.id)});setKind('move');setDraftAim(null);setHoverAim(null)}}>Reset orders</button><details><summary>Character</summary><Affinities id={champion.id}/><p>{unit.hp}/{unit.maxHp} health · {unit.flux}/{unit.maxFlux} Flux</p><StatusList unit={unit}/></details></div>
    </div>}
    {(!champion||!unit)&&<div className="tx-action-panel tx-recovery"><h2>{game.winner!==null?'Game over':'Recovering'}</h2><p className="tx-muted">{game.winner!==null?'Play again or change your team.':'End the turn to bring your characters back.'}</p><div className="tx-command-dock">{game.winner===null?<button className="tx-primary tx-lock" disabled={!canPlan} onClick={()=>void lockPlan()}>{locked?'Orders locked':resolving?'Resolving…':'End turn'} ⟶</button>:<button className="tx-primary tx-lock" disabled={busy||!!room?.rematch?.[seat]} onClick={()=>void rematch()}>{room?.rematch?.[seat]?'Waiting…':mode==='online'?'Play again · Frontier':'Play again'} ↗</button>}</div></div>}
   </aside></div>
   <details className="tx-battle-detail tx-opponents" open={!!inspected||undefined}><summary>Opponent team</summary>
    <div className="tx-rival-panel"><div>{game.units.filter(u=>u.owner!==seat).map(u=><button key={u.id} onClick={()=>setInspect(inspect===u.id?null:u.id)} aria-pressed={inspect===u.id}><PixelChampion id={u.championId} size={100} paused/><span><strong>{getChampion(u.championId).name}</strong><small>{u.hp}/{u.maxHp} HP · {u.flux}/{u.maxFlux} Flux</small></span></button>)}</div></div>
    {inspected&&<div className="tx-inspect"><button className="tx-close" aria-label="Close rival details" onClick={()=>setInspect(null)}>×</button><h3>{getChampion(inspected.championId).name}</h3><Affinities id={inspected.championId}/><StatusList unit={inspected}/><div>{inspected.loadout.map(id=>{const s=getSpell(id);return <article key={id}><strong><Glyph element={s.element}/>{s.name}</strong><small>{castAvailability(game,inspected.id,id).cost} Flux · {inspected.cooldowns[id]?`${inspected.cooldowns[id]} round recovery`:'Ready'}</small><p>{s.description}</p></article>})}</div></div>}
   </details>
   <div className="tx-battle-notes"><button onClick={()=>void copySeedLink()}>Copy map · {arenaSeed(game.mapId)}</button><details><summary>Reactions</summary><div className="tx-reaction-list">{REACTIONS.map(r=><article key={r.id}><strong>{r.symbol} {r.name}</strong><span>{r.elements.map(e=><Glyph key={e} element={e}/>)}</span><p>{r.description}</p></article>)}</div></details><details><summary>Round log</summary>{exchange&&<div className="tx-round-report"><strong>{exchange.headline}</strong>{exchange.details.map((line,i)=><p key={i}>{line}</p>)}</div>}<ol>{game.log.slice(-40).map((l,i)=><li key={i}>{l}</li>)}</ol></details>{mode==='online'&&<button onClick={()=>void invite()}>Invitation · {session?.code}</button>}</div>
  </section>}
  {(notice||error)&&<div className={`tx-message ${error?'is-error':''}`} role={error?'alert':'status'}><p>{error||notice}</p><button aria-label="Dismiss message" onClick={()=>{setError('');setNotice('')}}>×</button></div>}
  <dialog ref={libraryDialog} className="tx-library tx-dialog" onCancel={()=>setLibrary(false)} onClose={()=>setLibrary(false)}><div className="tx-dialog-top"><div><h2>{recruit.name}</h2><p>Choose spell {spellSlot+1}</p></div><button aria-label="Close spell catalogue" onClick={()=>setLibrary(false)}>×</button></div><div className="tx-library-slots">{equipped.map((id,i)=><button key={i} aria-pressed={spellSlot===i} onClick={()=>setSpellSlot(i)}><small>SLOT {i+1}</small><Glyph element={getSpell(id).element}/><strong>{getSpell(id).name}</strong></button>)}</div><div className="tx-filters"><button aria-pressed={spellFilter==='affinity'} onClick={()=>setSpellFilter('affinity')}>Affinities</button><button aria-pressed={spellFilter==='all'} onClick={()=>setSpellFilter('all')}>All</button>{ELEMENT_IDS.map(e=><button key={e} aria-pressed={spellFilter===e} onClick={()=>setSpellFilter(e)}><Glyph element={e}/>{cap(e)}</button>)}</div>{ELEMENT_IDS.includes(spellFilter as Element)&&<div className="tx-element-personality"><strong>{ELEMENT_STYLE[spellFilter as Element].verb}</strong><p>{ELEMENT_STYLE[spellFilter as Element].description}</p></div>}<p className="tx-library-feedback" role="status">{error||notice||''}</p><div className="tx-spell-catalogue">{shownSpells.map(s=><button key={s.id} className={equipped.includes(s.id)?'is-equipped':''} aria-label={`Equip ${s.name}`} aria-pressed={equipped[spellSlot]===s.id} onClick={()=>equip(s.id)} style={{'--element-color':ELEMENT_STYLE[s.element].color} as CSSProperties}><div><Glyph element={s.element}/><h3>{s.name}</h3><b>{spellCost(recruit.id,s.id)}<small> Flux</small></b></div><span><SpellFootprint shape={s.shape}/>{scaleLabel(s)} · reach {s.range} · recovery {s.cooldown}</span><p>{s.description}</p><small>{equipped.includes(s.id)?`Equipped · slot ${equipped.indexOf(s.id)+1}`:`Equip in slot ${spellSlot+1} →`}</small></button>)}</div><button className="tx-primary tx-library-done" onClick={()=>setLibrary(false)}>Done</button></dialog>
  <dialog ref={handoffDialog} className="tx-handoff" aria-label="Pass the screen" onCancel={e=>e.preventDefault()}><div><span>◇</span><h1>Pass to Player {hotSeat+1}</h1><p>{hotSeat===1?'Hand the screen to Player 2. Your orders are hidden.':'Player 1 plans the next round.'}</p><button className="tx-primary" disabled={resolving} onClick={()=>{setHandoff(false);selectUnit(game.units.find(u=>u.owner===hotSeat&&alive(u))?.id||'')}}>Player {hotSeat+1}: ready</button></div></dialog>
  <dialog ref={guideDialog} className="tx-guide tx-dialog" onCancel={()=>setGuide(false)} onClose={()=>setGuide(false)}><div className="tx-dialog-top"><h2>How to play</h2><button aria-label="Close rules" onClick={()=>setGuide(false)}>×</button></div>
   <ol className="tx-guide-steps">
    <li><strong>Score 8 points with a lead.</strong><p>Each well you occupy at round end earns 1 point, or 2 under Penumbra. Each defeated enemy earns 1 point. Defeated characters miss a round, then return. Ties continue. After round 16, the higher score wins; a tied score is a draw.</p></li>
    <li><strong>Move, then cast or Guard.</strong><p>Select a character and a destination. Choose one of its four spells, select a hex and confirm. Guard absorbs 1 spell damage, blocks pushes and restores 1 extra Flux. Characters with no orders Guard.</p></li>
    <li><strong>Both teams act together.</strong><p>End turn locks your orders. Everyone moves, then spells land. Aim where enemies will be. Two characters trying to land on the same hex both stay put; a blocked move can leave a spell out of range.</p></li>
    <li><strong>Combine elements.</strong><p>Fire + Water makes Steam, halving spell damage. Water channels and Earth terraces also react with spells. Reactions can affect either team. Check the highlighted area before committing.</p></li>
    <li><strong>Manage Flux and ground.</strong><p>Recover 2 Flux each round. Spell recovery is the number of planning rounds before reuse. You have {MOVE_RANGE} movement points; climbing costs 2. High ground adds 1 spell range against lower targets.</p></li>
   </ol>
   <details><summary>Elements</summary><div className="tx-element-notes">{ELEMENT_IDS.map(e=><article key={e}><h3><Glyph element={e}/>{cap(e)}</h3><p>{ELEMENT_STYLE[e].description}</p><p className="tx-muted">{ELEMENT_STYLE[e].counter}</p></article>)}</div></details>
   <details><summary>Statuses</summary><div className="tx-status-guide">{STATUS_DEFINITIONS.map(s=><article key={s.id}><strong style={{color:STATUS_INK[s.id]||'#6b5738'}}>{s.symbol} {s.name}</strong><p>{s.description}</p></article>)}</div></details>
   <details><summary>Controls</summary><p className="tx-muted">M: move · 1–4: spell · G: Guard · U: undo · Esc: cancel aim. Arrow keys and Q/E: move board focus · Enter: select hex. Drag the board to pan; Overview shows the whole map.</p></details>
   <button className="tx-primary" onClick={()=>setGuide(false)}>Done</button>
  </dialog>
 </main>;
}
