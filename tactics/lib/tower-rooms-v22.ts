import {RoomError,hashSecret,normalizeRoomCode,type RoomDatabase} from './rooms.ts';
import {createTowerRun,createCoopTowerRun,validateTowerStarter,towerControlledActorIds,chooseTowerRoom,claimTowerReward,finishTowerBattle,updateTowerLoadout,updateTowerBuild,createTowerSession,restoreTowerSession,type TowerSession,type TowerBuild} from './tower-v22.ts';
import {validateCoopPlan,resolveCoopRound,chooseAIPlan,type TeamPlan} from './tactics-v22.ts';

export const TOWER_PROTOCOL=22;
export const TOWER_ROOM_TTL=7*24*60*60*1000;
type Seat=0|1;
export type TowerPlayer={seat:Seat;name:string;starterId:string;build:TowerBuild;companionId:string};
type PrivatePlayer=TowerPlayer&{tokenHash:string};
export type TowerVote={choiceId:string;replaceActorId?:string};
type Receipt={id:string;seat:Seat;digest:string};
type Envelope={protocolVersion:22;seed:string;status:'waiting'|'active'|'finished';runId:string;step:number;players:[PrivatePlayer,PrivatePlayer|null];ready:[boolean,boolean];session:TowerSession|null;drafts:[TeamPlan|null,TeamPlan|null];locked:[boolean,boolean];votes:[TowerVote|null,TowerVote|null];enemyPlan:TeamPlan|null;receipts:Receipt[]};
type Row={code:string;version:number;host_hash:string;data_json:string;created_at:number;updated_at:number;expires_at:number};
export type TowerRoomSnapshot={protocolVersion:22;code:string;version:number;seed:string;status:Envelope['status'];runId:string;stepId:string;players:[TowerPlayer,TowerPlayer|null];ready:[boolean,boolean];session:TowerSession|null;drafts:[TeamPlan|null,TeamPlan|null];locked:[boolean,boolean];votes:[TowerVote|null,TowerVote|null];yourSeat:Seat;controlledActorIds:string[];expiresAt:number};
const ALPHABET='23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const fail=(code:string,message:string,status=400):never=>{throw new RoomError(status,code,message);};
function object(input:unknown,keys?:readonly string[]):Record<string,unknown>{if(!input||typeof input!=='object'||Array.isArray(input)||![Object.prototype,null].includes(Object.getPrototypeOf(input)))return fail('INVALID_INPUT','Send a valid tower request.');const result=input as Record<string,unknown>;if(keys&&Object.keys(result).some(key=>!keys.includes(key)))return fail('INVALID_INPUT','This request contains unsupported fields.');return result;}
function tokenValue(value:unknown):string{if(value===undefined)return Array.from(crypto.getRandomValues(new Uint8Array(32)),byte=>byte.toString(16).padStart(2,'0')).join('');if(typeof value!=='string'||!/^[a-f0-9]{64}$/.test(value))return fail('INVALID_KEY','Use a valid player key.');return value;}
function randomCode():string{let code='';while(code.length<12)for(const byte of crypto.getRandomValues(new Uint8Array(24))){if(byte<Math.floor(256/ALPHABET.length)*ALPHABET.length)code+=ALPHABET[byte%ALPHABET.length];if(code.length===12)break;}return code;}
function playerInput(input:Record<string,unknown>):Omit<TowerPlayer,'seat'>{
 if(typeof input.name!=='string'||input.name.trim().length<1||input.name.trim().length>24||/[\u0000-\u001f\u007f-\u009f<>]/.test(input.name))return fail('INVALID_NAME','Use a player name from 1 to 24 plain characters.');
 if(typeof input.starterId!=='string'||input.companionId!==undefined&&typeof input.companionId!=='string')return fail('INVALID_BUILD','Choose a starting character and companion.');
 try{const start=validateTowerStarter({starterId:input.starterId,...(input.build!==undefined?{build:input.build as TowerBuild}:{}),...(input.companionId!==undefined?{companionId:input.companionId as string}:{})});return {name:input.name.trim(),...start};}catch(error){return fail('INVALID_BUILD',error instanceof Error?error.message:'Choose a valid starting character.');}
}
function envelope(row:Row):Envelope{let value:Envelope;try{value=JSON.parse(row.data_json)}catch{return fail('CORRUPT_ROOM','This saved climb could not be read. It has been preserved.',409);}if(value.protocolVersion!==TOWER_PROTOCOL)return fail('RULES_CHANGED','Open this climb in its original rules version.',409);return value;}
const stepId=(data:Envelope)=>`${data.runId}:${data.step}`;
const startInput=(player:Omit<TowerPlayer,'seat'>)=>({starterId:player.starterId,build:player.build,companionId:player.companionId});
function snapshot(row:Row,seat:Seat):TowerRoomSnapshot{
 const data=envelope(row),players=data.players.map(player=>{if(!player)return null;const {tokenHash:_,...publicPlayer}=player;return publicPlayer;}) as [TowerPlayer,TowerPlayer|null];
 return {protocolVersion:22,code:row.code,version:row.version,seed:data.seed,status:data.status,runId:data.runId,stepId:stepId(data),players,ready:data.ready,session:data.session,drafts:data.drafts,locked:data.locked,votes:data.votes,yourSeat:seat,controlledActorIds:data.session?towerControlledActorIds(data.session.run,seat):[],expiresAt:row.expires_at};
}
async function find(db:RoomDatabase,code:string,now:number):Promise<Row>{const row=await db.prepare('SELECT * FROM tower_rooms WHERE code = ? AND expires_at > ?').bind(normalizeRoomCode(code),now).first<Row>();if(!row)return fail('ROOM_NOT_FOUND','This climb has expired or the code is incorrect.',404);envelope(row);return row;}
async function seatFor(row:Row,token:string):Promise<Seat>{if(!/^[a-f0-9]{64}$/.test(token))return fail('UNAUTHORIZED','Reopen this climb in the browser you joined with.',401);const digest=await hashSecret(token),seat=envelope(row).players.findIndex(player=>player?.tokenHash===digest);if(seat<0)return fail('UNAUTHORIZED','This player key does not belong to the climb.',401);return seat as Seat;}
async function save(db:RoomDatabase,row:Row,data:Envelope,now:number):Promise<Row|null>{return db.prepare('UPDATE tower_rooms SET data_json = ?, version = version + 1, updated_at = ? WHERE code = ? AND version = ? AND expires_at > ? RETURNING *').bind(JSON.stringify(data),now,row.code,row.version,now).first<Row>();}
/** Stable request digests make dropped-response retries safe without accepting changed payloads. */
function stable(value:unknown,depth=0):string{if(depth>12)return fail('INVALID_INPUT','This request is nested too deeply.');if(value===null||typeof value!=='object')return JSON.stringify(value);if(Array.isArray(value)){if(value.length>64)return fail('INVALID_INPUT','This request contains too many entries.');return `[${value.map(entry=>stable(entry,depth+1)).join(',')}]`;}return `{${Object.keys(value).sort().map(key=>`${JSON.stringify(key)}:${stable((value as Record<string,unknown>)[key],depth+1)}`).join(',')}}`;}
function openStep(data:Envelope):void{
 data.step++;data.votes=[null,null];data.drafts=[null,null];data.locked=[false,false];data.enemyPlan=null;
 const battle=data.session?.battle;
 if(battle&&battle.winner===null){
  // This plan is chosen from public state before either player submits a draft.
  data.enemyPlan=chooseAIPlan(battle,1);
  for(const seat of [0,1] as const){const ids=towerControlledActorIds(data.session!.run,seat);if(!battle.units.some(unit=>ids.includes(unit.id)&&unit.hp>0)){data.drafts[seat]={orders:[]};data.locked[seat]=true;}}
 }
}
function start(data:Envelope):void{
 if(!data.players[1])return fail('NOT_READY','Wait for your friend to join.',409);
 try{data.session=createTowerSession(createCoopTowerRun(data.seed,startInput(data.players[0]),startInput(data.players[1])));}catch(error){return fail('INVALID_PARTY',error instanceof Error?error.message:'Choose two different champions.');}
 data.status='active';openStep(data);
}
function validVote(data:Envelope,value:Record<string,unknown>):TowerVote{
 if(typeof value.choiceId!=='string'||value.choiceId.length>100||!value.choiceId.length||value.replaceActorId!==undefined&&(typeof value.replaceActorId!=='string'||value.replaceActorId.length>100))return fail('INVALID_CHOICE','Choose an available room or reward.');
 const vote:TowerVote={choiceId:value.choiceId,...(value.replaceActorId!==undefined?{replaceActorId:value.replaceActorId as string}:{})};
 const current=data.session;if(!current)return fail('NOT_STARTED','Both players must be ready first.',409);
 try{
  if(current.run.phase==='route')chooseTowerRoom(current.run,vote.choiceId);
  else if(current.run.phase==='reward')claimTowerReward(current.run,vote.choiceId,vote.replaceActorId);
  else if(current.run.phase==='battle'){if(current.battle?.winner===null||vote.choiceId!=='finish'||vote.replaceActorId!==undefined)throw new Error('Finish the battle before moving on.');}
  else if(vote.choiceId!=='retry'||vote.replaceActorId!==undefined)throw new Error('Choose retry to climb this seed together again.');
 }catch(error){return fail('INVALID_CHOICE',error instanceof Error?error.message:'Choose an available option.');}
 return vote;
}
function applyVote(data:Envelope,vote:TowerVote):void{
 const current=data.session!;
 if(current.run.phase==='route')data.session=createTowerSession(chooseTowerRoom(current.run,vote.choiceId));
 else if(current.run.phase==='reward')data.session=createTowerSession(claimTowerReward(current.run,vote.choiceId,vote.replaceActorId));
 else if(current.run.phase==='battle')data.session=createTowerSession(finishTowerBattle(current.run,current.battle));
 else{data.runId=crypto.randomUUID();data.ready=[true,true];start(data);return;}
 data.status=['won','lost'].includes(data.session.run.phase)?'finished':'active';openStep(data);
}
function scopedPlan(data:Envelope,seat:Seat,input:unknown,partial:boolean):TeamPlan{
 if(data.status!=='active'||!data.session?.battle||data.session.battle.winner!==null)return fail('NOT_PLANNING','This battle is not accepting orders.',409);
 try{
  const checked=validateCoopPlan(data.session.battle,seat,input);
  if(!partial)return checked;
  const raw=object(input),supplied=Array.isArray(raw.orders)?new Set(raw.orders.map(order=>object(order).unitId)):new Set();
  return {...checked,orders:checked.orders.filter(order=>supplied.has(order.unitId))};
 }catch(error){if(error instanceof RoomError)throw error;return fail('INVALID_PLAN',error instanceof Error?error.message:'Send legal orders for your characters.');}
}

export async function createTowerRoom(db:RoomDatabase,input:unknown,now=Date.now()){
 const value=object(input,['action','name','starterId','build','companionId','seed','clientToken']),player=playerInput(value),token=tokenValue(value.clientToken),hostHash=await hashSecret(token);
 let seed:string;try{seed=createTowerRun(value.seed as string,startInput(player)).seed;}catch(error){return fail('INVALID_SEED',error instanceof Error?error.message:'Choose a valid seed.');}
 await db.prepare('DELETE FROM tower_rooms WHERE expires_at <= ?').bind(now).run();await db.prepare('DELETE FROM room_rate_limits WHERE expires_at <= ?').bind(now).run();
 const existing=await db.prepare('SELECT * FROM tower_rooms WHERE host_hash = ? AND expires_at > ?').bind(hostHash,now).first<Row>();if(existing)return {code:existing.code,token,seat:0 as Seat,room:snapshot(existing,0)};
 const data:Envelope={protocolVersion:22,seed,status:'waiting',runId:crypto.randomUUID(),step:0,players:[{...player,seat:0,tokenHash:hostHash},null],ready:[false,false],session:null,drafts:[null,null],locked:[false,false],votes:[null,null],enemyPlan:null,receipts:[]};
 for(let attempt=0;attempt<4;attempt++){
  const code=randomCode(),row=await db.prepare('INSERT INTO tower_rooms (code,version,host_hash,data_json,created_at,updated_at,expires_at) VALUES (?,0,?,?,?,?,?) ON CONFLICT DO NOTHING RETURNING *').bind(code,hostHash,JSON.stringify(data),now,now,now+TOWER_ROOM_TTL).first<Row>();
  if(row)return {code,token,seat:0 as Seat,room:snapshot(row,0)};
  const recovered=await db.prepare('SELECT * FROM tower_rooms WHERE host_hash = ? AND expires_at > ?').bind(hostHash,now).first<Row>();if(recovered)return {code:recovered.code,token,seat:0 as Seat,room:snapshot(recovered,0)};
 }
 return fail('TRY_AGAIN','Could not reserve a climb. Try again.',503);
}
export async function joinTowerRoom(db:RoomDatabase,code:string,input:unknown,now=Date.now()){
 const value=object(input,['action','code','name','starterId','build','companionId','clientToken']),player=playerInput(value),token=tokenValue(value.clientToken),tokenHash=await hashSecret(token);
 for(let attempt=0;attempt<8;attempt++){
  const row=await find(db,code,now),data=envelope(row),existing=data.players.find(candidate=>candidate?.tokenHash===tokenHash);
  if(existing)return {code:row.code,token,seat:existing.seat,room:snapshot(row,existing.seat)};
  if(data.status!=='waiting')return fail('CLIMB_STARTED','This climb has already started.',409);if(data.players[1])return fail('ROOM_FULL','Both places are taken.',409);
  try{createCoopTowerRun(data.seed,startInput(data.players[0]),startInput(player));}catch(error){return fail('INVALID_PARTY',error instanceof Error?error.message:'Choose a different champion from your friend.');}
  data.players[1]={...player,seat:1,tokenHash};data.ready=[false,false];
  const updated=await save(db,row,data,now);if(updated)return {code:row.code,token,seat:1 as Seat,room:snapshot(updated,1)};
 }
 return fail('ROOM_CHANGED','Someone joined at the same time. Try again.',409);
}
export async function getTowerRoom(db:RoomDatabase,code:string,token:string,now=Date.now()){
 const row=await find(db,code,now),seat=await seatFor(row,token);return {room:snapshot(row,seat)};
}
const actionKeys:Record<string,readonly string[]>={ready:['ready'],lobby:['name','starterId','build','companionId'],vote:['choiceId','replaceActorId'],draft:['plan'],lock:['plan'],unlock:[],loadout:['actorId','loadout'],build:['actorId','build']};
export async function actTowerRoom(db:RoomDatabase,code:string,token:string,input:unknown,now=Date.now()){
 const raw=object(input),action=raw.action;if(typeof action!=='string'||!Object.prototype.hasOwnProperty.call(actionKeys,action))return fail('INVALID_ACTION','Choose a valid tower action.');
 const value=object(raw,['action','runId','stepId','requestId',...actionKeys[action]]);
 if(typeof value.requestId!=='string'||!/^[a-zA-Z0-9_-]{8,80}$/.test(value.requestId))return fail('INVALID_REQUEST_ID','Give this action a valid request ID.');
 if(typeof value.runId!=='string'||typeof value.stepId!=='string'||value.runId.length>100||value.stepId.length>120)return fail('STALE_STEP','Refresh the climb before acting.',409);
 const digest=await hashSecret(stable(value));
 for(let attempt=0;attempt<8;attempt++){
  const row=await find(db,code,now),seat=await seatFor(row,token),data=envelope(row),receipt=data.receipts.find(entry=>entry.seat===seat&&entry.id===value.requestId);
  if(receipt){if(receipt.digest!==digest)return fail('REQUEST_CHANGED','This request ID was already used for another action.',409);return {room:snapshot(row,seat)};}
  if(value.runId!==data.runId||value.stepId!==stepId(data))return fail('STALE_STEP','The climb has moved on. Review the current choices.',409);
  if(action==='ready'||action==='lobby'){
   if(data.status!=='waiting')return fail('CLIMB_STARTED','The climb has already started.',409);
   if(action==='lobby'){
    const player=playerInput(value),other=data.players[1-seat];if(other)try{createCoopTowerRun(data.seed,startInput(seat===0?player:other),startInput(seat===0?other:player));}catch(error){return fail('INVALID_PARTY',error instanceof Error?error.message:'Choose two different champions.');}
    data.players[seat]={...player,seat,tokenHash:data.players[seat]!.tokenHash};data.ready=[false,false];data.step++;
   }else {if(typeof value.ready!=='boolean')return fail('INVALID_READY','Choose ready or not ready.');data.ready[seat]=value.ready;if(data.players[1]&&data.ready.every(Boolean))start(data);}
  }else if(action==='vote'){
   const vote=validVote(data,value);data.votes[seat]=vote;if(data.votes.every(Boolean)&&stable(data.votes[0])===stable(data.votes[1]))applyVote(data,vote);
  }else if(action==='loadout'||action==='build'){
   const run=data.session?.run;if(!run||run.phase!=='route')return fail('NOT_IN_CAMP','Change your character between rooms.',409);
   if(typeof value.actorId!=='string'||!towerControlledActorIds(run,seat).includes(value.actorId))return fail('NOT_YOUR_CHARACTER','Your friend controls that character.',403);
   try{const next=action==='loadout'?updateTowerLoadout(run,value.actorId,value.loadout as string[]):updateTowerBuild(run,value.actorId,value.build as TowerBuild);data.session=createTowerSession(next);openStep(data);}catch(error){return fail('INVALID_BUILD',error instanceof Error?error.message:'Choose a legal build.');}
  }else {
   if(!data.session?.battle||data.session.battle.winner!==null)return fail('NOT_PLANNING','This battle is not accepting orders.',409);
   if(action==='unlock'){
    if(!data.session.battle.units.some(unit=>unit.hp>0&&towerControlledActorIds(data.session!.run,seat).includes(unit.id)))return fail('NO_ACTIVE_CHARACTER','Your characters are defeated this round.',409);
    data.locked[seat]=false;
   }else {
    if(data.locked[seat])return fail('PLAN_LOCKED','Unlock your orders before changing them.',409);
    data.drafts[seat]=scopedPlan(data,seat,value.plan,action==='draft');if(action==='lock')data.locked[seat]=true;
    if(data.locked.every(Boolean)){
     if(!data.enemyPlan)return fail('MISSING_ENEMY_PLAN','This round could not be restored. The climb has been preserved.',409);
     const previous=data.session.battle,next=resolveCoopRound(previous,data.drafts as [TeamPlan,TeamPlan],data.enemyPlan);
     data.session=createTowerSession(data.session.run,next,{orders:[]},previous);openStep(data);
    }
   }
  }
  data.receipts=[...data.receipts,{id:value.requestId,seat,digest}].slice(-32);
  const updated=await save(db,row,data,now);if(updated)return {room:snapshot(updated,seat)};
 }
 return fail('ROOM_CHANGED','The climb changed while saving. Refresh and try again.',409);
}
export function validateStoredTowerSession(input:unknown){return restoreTowerSession(input);}
