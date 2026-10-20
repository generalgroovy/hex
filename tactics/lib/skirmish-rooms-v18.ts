import {RoomError,hashSecret,normalizeRoomCode,type RoomDatabase} from './rooms.ts';
import {validateCompany,type CharacterBuild} from './character-creation-v17.ts';
import {createSimGame,validatePlan,resolveRound,restoreSimState,type SimState,type TeamPlan,type Seat} from './tactics-v18.ts';
import {canonicalPlan,planFingerprint} from './room-plans.ts';
import {RESOLUTION_MS} from './feedback-v16.ts';

export const SKIRMISH_PROTOCOL=18;
export const PLANNING_MS=90_000;
const TTL=7*24*60*60*1000;
const ALPHABET='23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
type Mode='free-for-all'|'teams';
type PublicPlayer={seat:Seat;name:string;characters:CharacterBuild[];team:number};
type PrivatePlayer=PublicPlayer&{tokenHash:string};
type Envelope={rulesVersion:18;playerCount:2|3|4|5|6;mode:Mode;seed:string;status:'waiting'|'active'|'finished';players:(PrivatePlayer|null)[];ready:boolean[];rematch:boolean[];state:SimState|null;plans:(TeamPlan|null)[];fingerprints:(string|null)[];matchId:string;roundDeadline:number|null;lastResolved?:{matchId:string;round:number;fingerprints:(string|null)[]}};
type Row={code:string;version:number;host_hash:string;data_json:string;created_at:number;updated_at:number;expires_at:number};
export type SkirmishSnapshot={code:string;version:number;status:Envelope['status'];playerCount:Envelope['playerCount'];mode:Mode;seed:string;players:(PublicPlayer|null)[];ready:boolean[];locked:boolean[];rematch:boolean[];state:SimState|null;yourSeat:Seat;matchId:string;roundDeadline:number|null;yourPlan?:TeamPlan;affinityTotals:number[];protocolVersion:18;expiresAt:number};
const object=(input:unknown):Record<string,unknown>=>{if(!input||typeof input!=='object'||Array.isArray(input))throw new RoomError(400,'INVALID_INPUT','Send a valid match request.');return input as Record<string,unknown>};
const error=(code:string,message:string,status=400):never=>{throw new RoomError(status,code,message)};
const tokenValue=(input:unknown):string=>{if(input===undefined)return randomToken();if(typeof input!=='string'||! /^[a-f0-9]{64}$/.test(input))return error('INVALID_KEY','Use a valid player key.');return input;};
function randomToken(){return Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('')}
function randomCode(){let code='';while(code.length<12)for(const byte of crypto.getRandomValues(new Uint8Array(24))){if(byte<Math.floor(256/ALPHABET.length)*ALPHABET.length)code+=ALPHABET[byte%ALPHABET.length];if(code.length===12)break;}return code;}
function playerInput(value:Record<string,unknown>){
 if(typeof value.name!=='string'||value.name.trim().length<1||value.name.trim().length>24||/[\x00-\x1f\x7f<>]/.test(value.name))return error('INVALID_NAME','Use a player name from 1 to 24 plain characters.');
 try{return {name:value.name.trim(),characters:validateCompany(value.characters)}}catch(e){return error('INVALID_COMPANY',e instanceof Error?e.message:'Choose three legal characters.');}
}
function envelope(row:Row):Envelope{const data=JSON.parse(row.data_json);if(data.rulesVersion!==18)throw new RoomError(409,'LEGACY_MATCH','This match uses the previous rules. Open its original match screen to continue.');return data as Envelope}
function snapshot(row:Row,seat:Seat):SkirmishSnapshot{
 const data=envelope(row);
 return {code:row.code,version:row.version,status:data.status,playerCount:data.playerCount,mode:data.mode,seed:data.seed,players:data.players.map(player=>player?{seat:player.seat,name:player.name,characters:player.characters,team:player.team}:null),ready:data.ready,locked:data.plans.map(Boolean),rematch:data.rematch,state:data.state,yourSeat:seat,matchId:data.matchId,roundDeadline:data.roundDeadline,...(data.plans[seat]?{yourPlan:data.plans[seat]!}:{}),affinityTotals:data.players.map(p=>p?15:0),protocolVersion:18,expiresAt:row.expires_at};
}
async function find(db:RoomDatabase,code:string,now:number){const row=await db.prepare('SELECT * FROM skirmishes WHERE code = ? AND expires_at > ?').bind(normalizeRoomCode(code),now).first<Row>();if(!row)return error('ROOM_NOT_FOUND','This match code has expired or does not exist.',404);envelope(row);return row;}
async function seatFor(row:Row,token:string):Promise<Seat>{
 if(!/^[a-f0-9]{64}$/.test(token))return error('UNAUTHORIZED','Reopen this match in the browser you joined with.',401);
 const hash=await hashSecret(token),seat=envelope(row).players.findIndex(p=>p?.tokenHash===hash);if(seat<0)return error('UNAUTHORIZED','This player key does not belong to the match.',401);return seat as Seat;
}
async function save(db:RoomDatabase,row:Row,data:Envelope,now:number){return db.prepare('UPDATE skirmishes SET data_json = ?, version = version + 1, updated_at = ? WHERE code = ? AND version = ? AND expires_at > ? RETURNING *').bind(JSON.stringify(data),now,row.code,row.version,now).first<Row>();}
function openPlans(data:Envelope){data.plans=Array.from({length:data.playerCount},(_,seat)=>data.state?.units.some(u=>u.owner===seat&&u.hp>0)?null:{orders:[]});data.fingerprints=Array(data.playerCount).fill(null);}
function start(data:Envelope,now:number){
 const players=data.players.map(p=>p!);
 data.state=createSimGame({playerCount:data.playerCount,mode:data.mode,seed:data.seed,rosters:players.map(p=>p.characters.map(c=>c.championId)),affinities:players.map(p=>Object.fromEntries(p.characters.map(c=>[c.championId,c.affinities]))),loadouts:players.map(p=>Object.fromEntries(p.characters.map(c=>[c.championId,c.loadout]))),names:players.map(p=>Object.fromEntries(p.characters.map(c=>[c.championId,c.name])))});
 data.matchId=crypto.randomUUID();data.status='active';data.roundDeadline=now+PLANNING_MS;data.rematch.fill(false);delete data.lastResolved;openPlans(data);
}
function resolveIfReady(data:Envelope,now:number){
 if(!data.state||data.plans.some(p=>p===null))return;
 const receipt={matchId:data.matchId,round:data.state.round,fingerprints:[...data.fingerprints]};
 data.state=resolveRound(data.state,data.plans as TeamPlan[]);data.lastResolved=receipt;
 data.status=data.state.winner===null?'active':'finished';data.roundDeadline=data.status==='active'?now+RESOLUTION_MS+PLANNING_MS:null;
 if(data.status==='active')openPlans(data);else{data.plans.fill(null);data.fingerprints.fill(null)}
}

export async function createSkirmish(db:RoomDatabase,input:unknown,now=Date.now()){
 const value=object(input),player=playerInput(value),count=value.playerCount;
 if(!Number.isInteger(count)||Number(count)<2||Number(count)>6)return error('INVALID_SIZE','Choose two to six players.');
 const playerCount=count as Envelope['playerCount'];
 if(value.mode!=='free-for-all'&&value.mode!=='teams')return error('INVALID_MODE','Choose Free-for-all or Teams.');
 const mode=value.mode;if(mode==='teams'&&playerCount!==4&&playerCount!==6)return error('INVALID_SIZE','Teams needs four or six players.');
 if(typeof value.seed!=='string'||!/^[a-zA-Z0-9-]{1,24}$/.test(value.seed.trim()))return error('INVALID_SEED','Use a seed of 1 to 24 letters, numbers or hyphens.');
 const seed=value.seed.trim().toUpperCase(),token=tokenValue(value.clientToken),hostHash=await hashSecret(token);
 await db.prepare('DELETE FROM skirmishes WHERE expires_at <= ?').bind(now).run();
 await db.prepare('DELETE FROM room_rate_limits WHERE expires_at <= ?').bind(now).run();
 const existing=await db.prepare('SELECT * FROM skirmishes WHERE host_hash = ? AND expires_at > ?').bind(hostHash,now).first<Row>();
 if(existing)return {code:existing.code,token,seat:0,room:snapshot(existing,0)};
 const data:Envelope={rulesVersion:18,playerCount,mode,seed,status:'waiting',players:Array(playerCount).fill(null),ready:Array(playerCount).fill(false),rematch:Array(playerCount).fill(false),state:null,plans:Array(playerCount).fill(null),fingerprints:Array(playerCount).fill(null),matchId:crypto.randomUUID(),roundDeadline:null};
 data.players[0]={...player,seat:0,team:0,tokenHash:hostHash};
 for(let attempt=0;attempt<4;attempt++){
  const code=randomCode();
  const row=await db.prepare('INSERT INTO skirmishes (code,version,host_hash,data_json,created_at,updated_at,expires_at) VALUES (?,0,?,?,?,?,?) ON CONFLICT DO NOTHING RETURNING *').bind(code,hostHash,JSON.stringify(data),now,now,now+TTL).first<Row>();
  if(row)return {code,token,seat:0,room:snapshot(row,0)};
  const recovered=await db.prepare('SELECT * FROM skirmishes WHERE host_hash = ? AND expires_at > ?').bind(hostHash,now).first<Row>();
  if(recovered)return {code:recovered.code,token,seat:0,room:snapshot(recovered,0)};
 }
 return error('TRY_AGAIN','Could not reserve a match code. Try again.',503);
}
export async function joinSkirmish(db:RoomDatabase,code:string,input:unknown,now=Date.now()){
 const value=object(input),player=playerInput(value),token=tokenValue(value.clientToken),tokenHash=await hashSecret(token);
 for(let attempt=0;attempt<8;attempt++){
  const row=await find(db,code,now),data=envelope(row),existing=data.players.find(p=>p?.tokenHash===tokenHash);
  if(existing)return {code:row.code,token,seat:existing.seat,room:snapshot(row,existing.seat)};
  if(data.status!=='waiting')return error('MATCH_STARTED','This match has already started.',409);
  const seat=data.players.findIndex(p=>!p) as Seat;if(seat<0)return error('ROOM_FULL','Every seat is taken.',409);
  data.players[seat]={...player,seat,team:data.mode==='teams'?seat%2:seat,tokenHash};data.ready[seat]=false;
  const updated=await save(db,row,data,now);if(updated)return {code:row.code,token,seat,room:snapshot(updated,seat)};
 }
 return error('MATCH_CHANGED','Several players joined at once. Try joining again.',409);
}
export async function getSkirmish(db:RoomDatabase,code:string,token:string,now=Date.now()){
 const row=await find(db,code,now),seat=await seatFor(row,token);return {room:snapshot(row,seat)};
}
export async function actSkirmish(db:RoomDatabase,code:string,token:string,input:unknown,now=Date.now()){
 const value=object(input),action=value.action;
 if(!['ready','start','plan','timeout','rematch'].includes(String(action)))return error('INVALID_ACTION','Choose a valid match action.');
 let canonical:TeamPlan|undefined,fingerprint:string|undefined;
 if(action==='plan'){
  try{canonical=canonicalPlan(value.plan,16);fingerprint=await planFingerprint(canonical,16)}catch(e){return error('INVALID_PLAN',e instanceof Error?e.message:'Send a legal plan.');}
  if(!Number.isInteger(value.round)||Number(value.round)<1)return error('INVALID_ROUND','Refresh the round before locking orders.');
 }
 for(let attempt=0;attempt<8;attempt++){
  const row=await find(db,code,now),seat=await seatFor(row,token),data=envelope(row);
  if(action==='ready'||action==='start'){
   if(data.status!=='waiting')return error('MATCH_STARTED','The match has already started.',409);
   if(action==='ready'){
    if(typeof value.ready!=='boolean')return error('INVALID_READY','Choose Ready or Not ready.');
    if(data.ready[seat]===value.ready)return {room:snapshot(row,seat)};
    data.ready[seat]=value.ready;
   }else{
    if(seat!==0)return error('HOST_ONLY','Only the host can start the match.',403);
    if(data.players.some(p=>!p)||data.ready.some(r=>!r))return error('NOT_READY','Fill every seat and wait for everyone to be ready.',409);
    start(data,now);
   }
  }else{
   if(value.matchId!==data.matchId)return error('MATCH_CHANGED','A new match has started. Refresh before acting.',409);
   if(action==='rematch'){
    if(data.status!=='finished')return error('MATCH_ACTIVE','Finish the match before requesting a rematch.',409);
    if(data.rematch[seat])return {room:snapshot(row,seat)};
    data.rematch[seat]=true;if(data.rematch.every(Boolean))start(data,now);
   }else if(action==='plan'){
    if(data.lastResolved?.matchId===value.matchId&&data.lastResolved.round===value.round&&data.lastResolved.fingerprints[seat]===fingerprint)return {room:snapshot(row,seat)};
    if(data.status!=='active'||!data.state)return error('MATCH_NOT_ACTIVE','The match is not accepting orders.',409);
    if(data.state.round!==value.round)return error('ROUND_CHANGED','The round has changed. Review the latest result.',409);
    if(data.plans[seat]){
     if(data.fingerprints[seat]===fingerprint)return {room:snapshot(row,seat)};
     return error('PLAN_LOCKED','Your orders are already locked for this round.',409);
    }
    if(data.roundDeadline===null||now>=data.roundDeadline)return error('PLANNING_ENDED','Planning time has ended. Waiting for the round to resolve.',409);
    try{data.plans[seat]=validatePlan(data.state,seat,canonical!)}catch(e){return error('INVALID_PLAN',e instanceof Error?e.message:'This plan is not legal.');}
    data.fingerprints[seat]=fingerprint!;resolveIfReady(data,now);
   }else{
    if(data.status!=='active'||!data.state)return error('MATCH_NOT_ACTIVE','The match is not accepting orders.',409);
    if(value.round!==data.state.round)return error('ROUND_CHANGED','The round has changed. Refresh before continuing.',409);
    if(data.roundDeadline===null||now<data.roundDeadline)return error('STILL_PLANNING','Give everyone the full planning time.',409);
    data.plans=data.plans.map(p=>p??{orders:[]});resolveIfReady(data,now);
   }
  }
  const updated=await save(db,row,data,now);if(updated)return {room:snapshot(updated,seat)};
 }
 return error('MATCH_CHANGED','The match changed while saving. Refresh and try again.',409);
}

/** Used by tests and recovery diagnostics; never returns the private room envelope. */
export function validateStoredSkirmishState(input:unknown){return restoreSimState(input)}
