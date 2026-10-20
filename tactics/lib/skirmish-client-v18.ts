/** Browser-only presentation and drafts. Authoritative rules stay in tactics-v18. */
import type {SimState as ArenaState,Seat,TeamPlan} from './tactics-v18.ts';
import type {SimState as PresentedState} from './tactics-v16.ts';
import type {CharacterBuild} from './character-creation-v17.ts';
export const SEAT_COLORS=['#176f76','#a94230','#7754a4','#936110','#416b37','#9a426c'] as const;
export type ArenaSession={code:string;token:string;seat:Seat};
export type ArenaPlayer={seat:Seat;name:string;characters:CharacterBuild[];team:number};
export type ArenaRoom={protocolVersion:18;code:string;version:number;status:'waiting'|'active'|'finished';playerCount:number;mode:'free-for-all'|'teams';seed:string;players:(ArenaPlayer|null)[];ready:boolean[];locked:boolean[];rematch:boolean[];state:ArenaState|null;yourSeat:Seat;matchId:string;roundDeadline:number|null;yourPlan?:TeamPlan;affinityTotals:number[]};
export function normalizeArenaCode(value:string){let text=value.trim();if(/^https?:\/\//i.test(text)){try{text=new URL(text).searchParams.get('room')??''}catch{return ''}}return text.toUpperCase().replace(/[-\s]/g,'');}
export function validArenaSession(value:unknown,code?:string):value is ArenaSession{const s=value as ArenaSession|null;return !!s&&typeof s.code==='string'&&(!code||s.code===code)&&typeof s.token==='string'&&/^[a-f0-9]{64}$/.test(s.token)&&Number.isInteger(s.seat)&&s.seat>=0&&s.seat<6;}
/** Explicit view adapter: seat identity is retained separately in unitPresentation.
 * This never goes back to the room API and never executes a v16 combat round. */
export function presentArena(state:ArenaState,seat:Seat):PresentedState{
 const side=(owner:Seat):0|1=>state.teams[owner]===state.teams[seat]?0:1;
 const learned:[string[],string[]]=[[],[]];
 for(let owner=0;owner<state.playerCount;owner++)learned[side(owner as Seat)].push(...state.learnedSignatures[owner]);
 return {rulesVersion:16,spellModel:state.spellModel,version:state.version,mapId:state.mapId,round:state.round,cells:state.cells,units:state.units.map(unit=>({...unit,owner:side(unit.owner)})),scores:[0,0],learnedSignatures:learned.map(ids=>[...new Set(ids)]) as [string[],string[]],winner:state.winner===null?null:state.winner==='draw'?'draw':state.winner===state.teams[seat]?0:1,log:state.log,lastResolution:state.lastResolution.map(event=>({...event,owner:event.owner===undefined?undefined:side(event.owner)}))};
}
export function arenaUnitLabel(room:ArenaRoom,unit:ArenaState['units'][number]){return room.players[unit.owner]?.characters.find(character=>character.championId===unit.championId)?.name??unit.championId;}
export function arenaDraftKey(room:Pick<ArenaRoom,'code'|'matchId'>,round:number){return `confluence-arena-draft-v18:${room.code}:${room.matchId}:${round}`;}
