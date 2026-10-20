import {RoomError,hashSecret,normalizeRoomCode,type RoomDatabase} from './rooms.ts';
import {createTowerRun,validateTowerStarter,chooseTowerRoom,claimTowerReward,finishTowerBattle,updateTowerLoadout,updateTowerBuild,transferTowerSupply,createTowerSession,shareTowerSpells,type TowerSession,type TowerStart,type TowerStarterInput,type TowerBuild,type TowerActor} from './tower-v23.ts';
import {validatePlan,chooseAIPlan,resolveRound,eliminationWinner,type TeamPlan} from './tactics-v22.ts';
import {scoutTowerRoom,scoutReportsForRun,type ScoutReport} from './tower-scouting-actions.ts';
import {createSharedTowerBattle,sharedActorId,sharedControlledActorIds,validateSharedTowerPlan,finishSharedTowerBattle,type SharedTowerBattle} from './tower-shared-battle-v23.ts';

export const TOWER_PROTOCOL=23;
export const TOWER_ROOM_TTL=7*24*60*60*1000;
export type TowerPlayerSummary={seat:number;name:string;start:TowerStart;ready:boolean;alive:boolean;floor:number;phase:'lobby'|'route'|'battle'|'reward'|'barrier'|'won'|'lost'|'retired';party:TowerActor[];currentRoomName:string|null;round:number|null};
export type TowerGathering={choiceId:string|null;choices:{seat:number;name:string;choiceId:string}[];waitingFor:number[]};
export type TowerSharedBattleSnapshot={id:string;seats:number[];readySeats:number[];ownReady:boolean;controlledActorIds:string[];teammatePlan:TeamPlan};
export type TowerRoomSnapshot={protocolVersion:23;code:string;version:number;runId:string;stepId:string;yourSeat:number;hostSeat:0;capacity:number;seed:string;status:'waiting'|'active'|'finished';sharedFloor:number;waitingFor:number[];canEnter:boolean;players:(TowerPlayerSummary|null)[];session:TowerSession|null;scoutReports:ScoutReport[];gathering:TowerGathering|null;sharedBattle:TowerSharedBattleSnapshot|null;watch:{seat:number;session:TowerSession}|null;expiresAt:number};
type Receipt={id:string;digest:string};
type Player={seat:number;name:string;start:TowerStart;tokenHash:string;ready:boolean;retired:boolean;step:number;session:TowerSession|null;enemyPlan:TeamPlan|null;receipts:Receipt[];choiceId?:string};
type Envelope={protocolVersion:23;runId:string;seed:string;capacity:number;status:TowerRoomSnapshot['status'];sharedFloor:number;players:(Player|null)[];scoutReports?:ScoutReport[];sharedRules?:boolean;battles?:SharedTowerBattle[]};
type Row={code:string;version:number;host_hash:string;data_json:string;created_at:number;updated_at:number;expires_at:number};
const ALPHABET='23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const fail=(code:string,message:string,status=400):never=>{throw new RoomError(status,code,message);};
function object(input:unknown,keys?:readonly string[]):Record<string,unknown>{if(!input||typeof input!=='object'||Array.isArray(input)||![Object.prototype,null].includes(Object.getPrototypeOf(input)))return fail('INVALID_INPUT','Send a valid tower request.');const result=input as Record<string,unknown>;if(keys&&Object.keys(result).some(key=>!keys.includes(key)))return fail('INVALID_INPUT','This request contains unsupported fields.');return result;}
function tokenValue(value:unknown):string{if(value===undefined)return Array.from(crypto.getRandomValues(new Uint8Array(32)),byte=>byte.toString(16).padStart(2,'0')).join('');if(typeof value!=='string'||!/^[a-f0-9]{64}$/.test(value))return fail('INVALID_KEY','Use a valid player key.');return value;}
function randomCode():string{let code='';while(code.length<12)for(const byte of crypto.getRandomValues(new Uint8Array(24))){if(byte<Math.floor(256/ALPHABET.length)*ALPHABET.length)code+=ALPHABET[byte%ALPHABET.length];if(code.length===12)break;}return code;}
function playerInput(value:Record<string,unknown>):Pick<Player,'name'|'start'>{
 if(typeof value.name!=='string'||value.name.trim().length<1||value.name.trim().length>24||/[\u0000-\u001f\u007f-\u009f<>]/.test(value.name))return fail('INVALID_NAME','Use a player name from 1 to 24 plain characters.');
 try{return {name:value.name.trim(),start:validateTowerStarter(value.starter as TowerStarterInput)}}catch(error){return fail('INVALID_BUILD',error instanceof Error?error.message:'Choose a legal two-character squad.');}
}
function envelope(row:Row):Envelope{let data:Envelope;try{data=JSON.parse(row.data_json)}catch{return fail('CORRUPT_ROOM','This saved climb could not be read. It has been preserved.',409);}if(data.protocolVersion!==23)return fail('RULES_CHANGED','Open this climb in its original rules version.',409);return data;}
const players=(data:Envelope)=>data.players.filter((player):player is Player=>!!player);
const living=(player:Player)=>!player.retired&&player.session?.run.phase!=='lost';
const stepId=(data:Envelope,player:Player)=>`${data.runId}:${player.seat}:${player.step}`;
function waitingFor(data:Envelope):number[]{return data.status==='active'?players(data).filter(player=>living(player)&&player.session!.run.phase!=='won'&&player.session!.run.floor<=data.sharedFloor).map(player=>player.seat):[];}
function battleFor(data:Envelope,player:Player):SharedTowerBattle|undefined{return player.session?.run.phase==='battle'?data.battles?.find(group=>group.seats.includes(player.seat)&&group.battle.tower.id===`shared:tower:${data.seed}:${player.session!.run.currentRoom?.id}`):undefined;}
function playerSession(data:Envelope,player:Player):TowerSession|null {const group=battleFor(data,player);return group&&player.session?{...player.session,battle:group.battle,...(group.previous?{previous:group.previous}:{})}:player.session;}
function summary(data:Envelope,player:Player):TowerPlayerSummary{
 const run=player.session?.run,battle=playerSession(data,player)?.battle,shared=battleFor(data,player);
 return {seat:player.seat,name:player.name,start:player.start,ready:player.ready,alive:living(player),floor:run?.floor??1,phase:player.retired?'retired':!run?'lobby':run.phase==='route'&&run.floor>data.sharedFloor?'barrier':run.phase,party:run?run.party.map(actor=>{const unit=battle?.units.find(unit=>unit.id===(shared?sharedActorId(player.seat,actor.id):actor.id));return unit?{...actor,hp:unit.hp}:actor;}):[],currentRoomName:run?.currentRoom?.name??null,round:battle?.round??null};
}
function snapshot(row:Row,seat:number,watch?:number):TowerRoomSnapshot{
 const data=envelope(row),own=data.players[seat]!,watched=watch===undefined?null:data.players[watch];
 const run=own.session?.run,reports=[...(run?.scouting?.reports??[]),...(data.scoutReports??[])];
 const scoutReports=run&&run.floor===data.sharedFloor&&reports.length?scoutReportsForRun(run,reports):[];
 const canEnter=data.status==='active'&&living(own)&&run?.phase==='route'&&run.floor===data.sharedFloor,group=battleFor(data,own);
 const gathering=canEnter&&data.sharedRules?{choiceId:own.choiceId??null,choices:players(data).filter(player=>living(player)&&player.choiceId).map(player=>({seat:player.seat,name:player.name,choiceId:player.choiceId!})),waitingFor:players(data).filter(player=>living(player)&&player.session?.run.floor===data.sharedFloor&&!player.choiceId).map(player=>player.seat)}:null;
 const sharedBattle=group?{id:group.id,seats:group.seats,readySeats:group.readySeats,ownReady:group.readySeats.includes(seat),controlledActorIds:sharedControlledActorIds(group.battle,seat),teammatePlan:{orders:group.seats.filter(other=>other!==seat&&!data.players[other]!.retired).flatMap(other=>data.players[other]!.session?.plan.orders??[])}}:null;
 return {protocolVersion:23,code:row.code,version:row.version,runId:data.runId,stepId:stepId(data,own),yourSeat:seat,hostSeat:0,capacity:data.capacity,seed:data.seed,status:data.status,sharedFloor:data.sharedFloor,waitingFor:waitingFor(data),canEnter:!!canEnter&&!own.choiceId,players:data.players.map(player=>player?summary(data,player):null),session:playerSession(data,own),scoutReports,gathering,sharedBattle,watch:watched?.session?{seat:watched.seat,session:playerSession(data,watched)!}:null,expiresAt:row.expires_at};
}
function watchSeat(watch:unknown):number|undefined{if(watch===undefined)return undefined;if(!Number.isInteger(watch)||Number(watch)<0||Number(watch)>5)return fail('INVALID_SPECTATOR','Choose a player to watch.');return Number(watch);}
async function find(db:RoomDatabase,code:string,now:number):Promise<Row>{const row=await db.prepare('SELECT * FROM tower_rooms_v23 WHERE code = ? AND expires_at > ?').bind(normalizeRoomCode(code),now).first<Row>();if(!row)return fail('ROOM_NOT_FOUND','This climb has expired or the code is incorrect.',404);envelope(row);return row;}
async function seatFor(row:Row,token:string):Promise<number>{if(!/^[a-f0-9]{64}$/.test(token))return fail('UNAUTHORIZED','Reopen this climb in the browser you joined with.',401);const digest=await hashSecret(token),player=players(envelope(row)).find(player=>player.tokenHash===digest);if(!player)return fail('UNAUTHORIZED','This player key does not belong to the climb.',401);return player.seat;}
async function save(db:RoomDatabase,row:Row,data:Envelope,now:number):Promise<Row|null>{
 // Polling and receipt replays never extend retention. A successful deliberate
 // action keeps an unfinished climb available for another seven days.
 const expiresAt=data.status==='finished'?row.expires_at:Math.max(row.expires_at,now+TOWER_ROOM_TTL);
 return db.prepare('UPDATE tower_rooms_v23 SET data_json = ?, version = version + 1, updated_at = ?, expires_at = ? WHERE code = ? AND version = ? AND expires_at > ? RETURNING *').bind(JSON.stringify(data),now,expiresAt,row.code,row.version,now).first<Row>();
}
function stable(value:unknown,depth=0):string{if(depth>12)return fail('INVALID_INPUT','This request is nested too deeply.');if(value===null||typeof value!=='object')return JSON.stringify(value);if(Array.isArray(value)){if(value.length>64)return fail('INVALID_INPUT','This request contains too many entries.');return `[${value.map(entry=>stable(entry,depth+1)).join(',')}]`;}return `{${Object.keys(value).sort().map(key=>`${JSON.stringify(key)}:${stable((value as Record<string,unknown>)[key],depth+1)}`).join(',')}}`;}
function openStep(player:Player):void{player.step++;player.enemyPlan=null;const battle=player.session?.battle;if(battle&&battle.winner===null)player.enemyPlan=chooseAIPlan(battle,1);}
function refreshBarrier(data:Envelope):void{
 if(data.status!=='active')return;
 const remaining=players(data).filter(living);
 if(!remaining.length){data.status='finished';return;}
 if(waitingFor(data).length)return;
 const discoveries=[...new Set(players(data).flatMap(player=>player.session?.run.learnedSpells??[]))];
 for(const player of remaining){const session=player.session!;player.session=createTowerSession(shareTowerSpells(session.run,discoveries));player.step++;}
 data.scoutReports=[];
 data.battles=[];data.sharedRules=true;
 if(data.sharedFloor===9){data.status='finished';return;}
 data.sharedFloor++;
}
function resetReady(data:Envelope):void{for(const player of players(data)){player.ready=false;player.step++;}}
function newPlayer(seat:number,input:Pick<Player,'name'|'start'>,tokenHash:string):Player{return {...input,seat,tokenHash,ready:false,retired:false,step:0,session:null,enemyPlan:null,receipts:[]};}

function launchChosenRooms(data:Envelope):void {
 if(!data.sharedRules||data.status!=='active')return;
 const entrants=players(data).filter(player=>living(player)&&player.session?.run.phase!=='won'&&player.session!.run.floor===data.sharedFloor);
 if(!entrants.length||entrants.some(player=>player.session?.run.phase!=='route'||!player.choiceId))return;
 const groups=new Map<string,Player[]>();
 for(const player of entrants){
  const run=chooseTowerRoom(player.session!.run,player.choiceId!);delete player.choiceId;
  player.session={format:3,run,battle:null,plan:{orders:[]}};player.step++;player.enemyPlan=null;
  if(run.phase!=='battle'){player.session=createTowerSession(run);continue;}
  const members=groups.get(run.currentRoom!.id)??[];members.push(player);groups.set(run.currentRoom!.id,members);
 }
 for(const [door,members] of groups){
  if(members.length===1){const player=members[0];player.session=createTowerSession(player.session!.run);player.enemyPlan=chooseAIPlan(player.session.battle!,1);continue;}
  const battle=createSharedTowerBattle(members.map(player=>({seat:player.seat,run:player.session!.run})));
  (data.battles??=[]).push({id:`${door}:${members.map(player=>player.seat).join('-')}`,seats:members.map(player=>player.seat),battle,enemyPlan:chooseAIPlan(battle,1),readySeats:[]});
 }
}
function requiredBattleSeats(data:Envelope,group:SharedTowerBattle):number[]{return group.seats.filter(seat=>!data.players[seat]!.retired&&group.battle.units.some(unit=>unit.hp>0&&unit.owner===0&&group.battle.tower.controllers?.[unit.id]===seat));}
function resolveSharedWhenReady(data:Envelope,group:SharedTowerBattle):void {
 if(group.battle.winner!==null)return;
 const required=requiredBattleSeats(data,group);if(!required.length||required.some(seat=>!group.readySeats.includes(seat)))return;
 const plans=required.map(seat=>data.players[seat]!.session!.plan),plan:TeamPlan={orders:plans.flatMap(plan=>plan.orders),link:plans.every(plan=>plan.link===true)};
 const previous=group.battle;group.battle=resolveRound(previous,[plan,group.enemyPlan]);group.previous=previous;group.readySeats=[];
 group.enemyPlan=group.battle.winner===null?chooseAIPlan(group.battle,1):{orders:[]};
 for(const seat of group.seats){const player=data.players[seat]!;if(player.retired||player.session?.run.phase!=='battle')continue;player.session.plan={orders:[]};player.step++;}
}
function retireFromBattle(data:Envelope,player:Player):void {
 const group=battleFor(data,player);if(!group||group.battle.winner!==null)return;
 for(const unit of group.battle.units.filter(unit=>unit.owner===0&&group.battle.tower.controllers?.[unit.id]===player.seat)){
  if(unit.hp>0)(group.battle.retirements??=[]).push({unitId:unit.id,round:group.battle.round});
  unit.hp=0;unit.flux=0;unit.cooldowns={};unit.statuses={};delete unit.guard;
 }
 group.readySeats=group.readySeats.filter(seat=>seat!==player.seat);group.previous=undefined;
 // Preserve the last exchange's chemistry and collapse evidence. If the final
 // squad leaves, finish through the resolver so the terminal replay is valid.
 if(eliminationWinner(group.battle.units,group.battle.round,group.battle.teams)!==null)group.battle=resolveRound(group.battle,[{orders:[]},{orders:[]}]);
 group.enemyPlan=group.battle.winner===null?chooseAIPlan(group.battle,1):{orders:[]};
 for(const seat of group.seats)if(seat!==player.seat){const ally=data.players[seat]!;ally.step++;}
 resolveSharedWhenReady(data,group);
}

export async function createTowerRoom(db:RoomDatabase,input:unknown,now=Date.now()){
 const value=object(input,['action','name','starter','seed','capacity','clientToken']),player=playerInput(value),token=tokenValue(value.clientToken),hostHash=await hashSecret(token),capacity=value.capacity===undefined?6:value.capacity;
 if(!Number.isInteger(capacity)||Number(capacity)<2||Number(capacity)>6)return fail('INVALID_CAPACITY','Choose between two and six places.');
 let seed:string;try{seed=createTowerRun(value.seed as string,player.start).seed}catch(error){return fail('INVALID_SEED',error instanceof Error?error.message:'Choose a valid seed.');}
 await db.prepare('DELETE FROM tower_rooms_v23 WHERE expires_at <= ?').bind(now).run();await db.prepare('DELETE FROM room_rate_limits WHERE expires_at <= ?').bind(now).run();
 const existing=await db.prepare('SELECT * FROM tower_rooms_v23 WHERE host_hash = ? AND expires_at > ?').bind(hostHash,now).first<Row>();if(existing)return {code:existing.code,token,seat:0,room:snapshot(existing,0)};
 const data:Envelope={protocolVersion:23,runId:crypto.randomUUID(),seed,capacity:Number(capacity),status:'waiting',sharedFloor:1,sharedRules:true,players:Array.from({length:Number(capacity)},(_,seat)=>seat===0?newPlayer(0,player,hostHash):null)};
 for(let attempt=0;attempt<4;attempt++){const code=randomCode(),row=await db.prepare('INSERT INTO tower_rooms_v23 (code,version,host_hash,data_json,created_at,updated_at,expires_at) VALUES (?,0,?,?,?,?,?) ON CONFLICT DO NOTHING RETURNING *').bind(code,hostHash,JSON.stringify(data),now,now,now+TOWER_ROOM_TTL).first<Row>();if(row)return {code,token,seat:0,room:snapshot(row,0)};const recovered=await db.prepare('SELECT * FROM tower_rooms_v23 WHERE host_hash = ? AND expires_at > ?').bind(hostHash,now).first<Row>();if(recovered)return {code:recovered.code,token,seat:0,room:snapshot(recovered,0)};}
 return fail('TRY_AGAIN','Could not reserve a climb. Try again.',503);
}
export async function joinTowerRoom(db:RoomDatabase,code:string,input:unknown,now=Date.now()){
 const value=object(input,['action','code','name','starter','clientToken']),player=playerInput(value),token=tokenValue(value.clientToken),tokenHash=await hashSecret(token);
 for(let attempt=0;attempt<16;attempt++){const row=await find(db,code,now),data=envelope(row),existing=players(data).find(player=>player.tokenHash===tokenHash);if(existing)return {code:row.code,token,seat:existing.seat,room:snapshot(row,existing.seat)};
  if(data.status!=='waiting')return fail('CLIMB_STARTED','This climb has already started.',409);const seat=data.players.findIndex(player=>!player);if(seat<0)return fail('ROOM_FULL','Every place is taken.',409);
  data.players[seat]=newPlayer(seat,player,tokenHash);resetReady(data);const updated=await save(db,row,data,now);if(updated)return {code:row.code,token,seat,room:snapshot(updated,seat)};
 }return fail('ROOM_CHANGED','Several friends joined together. Try again.',409);
}
export async function getTowerRoom(db:RoomDatabase,code:string,token:string,now=Date.now(),watch?:number){const selected=watchSeat(watch),row=await find(db,code,now),seat=await seatFor(row,token);return {room:snapshot(row,seat,selected)};}
const actionKeys:Record<string,readonly string[]>={ready:['ready'],start:[],lobby:['name','starter'],choose:['choiceId'],unchoose:[],scout:['actorId','choiceId'],reward:['choiceId','replaceActorId','recipientActorId'],draft:['plan'],resolve:['plan'],unlock:[],finish:[],loadout:['actorId','loadout'],build:['actorId','build'],supply:['actorId','targetActorId','slot'],retire:['confirm']};
export async function actTowerRoom(db:RoomDatabase,code:string,token:string,input:unknown,now=Date.now(),watch?:number){
 const selected=watchSeat(watch),raw=object(input),action=raw.action;if(typeof action!=='string'||!Object.prototype.hasOwnProperty.call(actionKeys,action))return fail('INVALID_ACTION','Choose a valid tower action.');
 const value=object(raw,['action','runId','stepId','requestId',...actionKeys[action]]);if(typeof value.requestId!=='string'||!/^[a-zA-Z0-9_-]{8,80}$/.test(value.requestId))return fail('INVALID_REQUEST_ID','Give this action a valid request ID.');
 if(typeof value.runId!=='string'||typeof value.stepId!=='string'||value.runId.length>100||value.stepId.length>120)return fail('STALE_STEP','Refresh the climb before acting.',409);
 const digest=await hashSecret(stable(value));
 // A CAS loss caused only by another squad must not recompute this squad's AI.
 // Reuse an exact-source transition within this request; checkpoint logic still
 // runs against the newly read room and can invalidate all next-floor steps.
 // Scouting instead rechecks the shared report pool after every CAS retry.
 let computed:{source:string;player:string}|undefined;
 for(let attempt=0;attempt<16;attempt++){
  const row=await find(db,code,now),seat=await seatFor(row,token),data=envelope(row);let player=data.players[seat]!;const receipt=player.receipts.find(entry=>entry.id===value.requestId);
  if(receipt){if(receipt.digest!==digest)return fail('REQUEST_CHANGED','This request ID was already used for another action.',409);return {room:snapshot(row,seat,selected)};}
  if(value.runId!==data.runId||value.stepId!==stepId(data,player))return fail('STALE_STEP','Your squad has moved on. Review its current choices.',409);
  if(['ready','start','lobby'].includes(action)){
   if(data.status!=='waiting')return fail('CLIMB_STARTED','The climb has already started.',409);
   if(action==='start'){
    if(seat!==0)return fail('HOST_ONLY','The host starts the climb.',403);const joined=players(data);if(joined.length<2||joined.some(player=>!player.ready))return fail('NOT_READY','At least two players must join, and everyone must be ready.',409);
     for(const entrant of joined){entrant.session=createTowerSession(createTowerRun(data.seed,entrant.start,joined.length,(entrant.seat%3) as 0|1|2));openStep(entrant);}data.status='active';
   }else if(action==='ready'){if(typeof value.ready!=='boolean')return fail('INVALID_READY','Choose ready or not ready.');player.ready=value.ready;}
   else {Object.assign(player,playerInput(value));resetReady(data);}
  }else if(!data.sharedRules&&action!=='scout'&&computed&&computed.source===JSON.stringify(player)){
   player=JSON.parse(computed.player);data.players[seat]=player;refreshBarrier(data);
  }else{
   if(data.status!=='active'||!player.session)return fail('NOT_ACTIVE','This climb is not accepting new actions.',409);
   if(player.retired||player.session.run.phase==='lost'||player.session.run.phase==='won')return fail('SPECTATOR_ONLY','Your squad has finished. You can watch the remaining climbers.',403);
   const current=player.session,source=JSON.stringify(player),group=battleFor(data,player);
   if(player.choiceId&&['scout','build','loadout','supply'].includes(action))return fail('DOOR_CHOSEN','Change your room choice before scouting or editing your squad.',409);
   if(action==='retire'){if(value.confirm!==true)return fail('CONFIRM_RETIRE','Confirm that your squad is retiring.');player.retired=true;player.step++;player.enemyPlan=null;delete player.choiceId;retireFromBattle(data,player);launchChosenRooms(data);}
   else if(action==='unchoose'){
    if(!data.sharedRules||current.run.phase!=='route'||!player.choiceId)return fail('NOT_GATHERING','Your room has already started.',409);
    delete player.choiceId;player.step++;
   }
   else if(action==='scout'){
    if(current.run.floor!==data.sharedFloor)return fail('FLOOR_BARRIER','Wait for the other squads to finish this floor.',409);
    if(current.run.phase!=='route')return fail('NOT_SCOUTING','Scout a room before entering it.',409);
    if(typeof value.actorId!=='string'||!current.run.party.some(actor=>actor.id===value.actorId))return fail('NOT_YOUR_CHARACTER','Choose a champion of your own squad.',403);
    if(typeof value.choiceId!=='string'||value.choiceId.length>100)return fail('INVALID_CHOICE','Choose an available room.');
    try{
     const next=scoutTowerRoom(current.run,value.actorId,value.choiceId,{sharedReports:data.scoutReports??[]});
     player.session=createTowerSession(next);openStep(player);
     // Retain this floor's discoveries until every squad reaches the stairs.
     // A fast finisher may already have reset their own next-floor scouting.
     const reports=[...(data.scoutReports??[]),...(next.scouting?.reports??[])];
     data.scoutReports=reports.filter((report,index)=>reports.findIndex(other=>other.encounterKey===report.encounterKey&&other.id===report.id)===index);
    }catch(error){if(error instanceof RoomError)throw error;return fail('INVALID_SCOUT',error instanceof Error?error.message:'Choose an available champion and room.');}
   }else if(action==='choose'){
    if(current.run.floor!==data.sharedFloor)return fail('FLOOR_BARRIER','Wait for the other squads to finish this floor.',409);
    if(typeof value.choiceId!=='string'||value.choiceId.length>100)return fail('INVALID_CHOICE','Choose an available room.');
    try{const next=chooseTowerRoom(current.run,value.choiceId);if(data.sharedRules){player.choiceId=value.choiceId;player.step++;launchChosenRooms(data);}else{player.session=createTowerSession(next);openStep(player);}}catch(error){if(error instanceof RoomError)throw error;return fail('INVALID_CHOICE',error instanceof Error?error.message:'Choose an available room.');}
   }else if(action==='reward'){
    if(typeof value.choiceId!=='string'||value.choiceId.length>100||value.replaceActorId!==undefined&&typeof value.replaceActorId!=='string'||value.recipientActorId!==undefined&&typeof value.recipientActorId!=='string')return fail('INVALID_CHOICE','Choose an available reward.');
    try{player.session=createTowerSession(claimTowerReward(current.run,value.choiceId,value.replaceActorId as string|undefined,value.recipientActorId as string|undefined));openStep(player);}catch(error){if(error instanceof RoomError)throw error;return fail('INVALID_CHOICE',error instanceof Error?error.message:'Choose an available reward.');}
   }else if(action==='finish'){
    try{player.session=createTowerSession(group?finishSharedTowerBattle(current.run,group.battle,seat):finishTowerBattle(current.run,current.battle));openStep(player);}catch(error){return fail('NOT_FINISHED',error instanceof Error?error.message:'Finish the battle first.',409);}
   }else if(action==='supply'){
    if(typeof value.actorId!=='string'||typeof value.targetActorId!=='string'||!['charm','scroll'].includes(value.slot as string))return fail('INVALID_SUPPLY','Choose a supply and recipient.');
    try{player.session=createTowerSession(transferTowerSupply(current.run,value.actorId,value.targetActorId,value.slot as 'charm'|'scroll'));openStep(player);}catch(error){return fail('INVALID_SUPPLY',error instanceof Error?error.message:'Move supplies between rooms.');}
   }else if(action==='build'||action==='loadout'){
    if(current.run.phase!=='route')return fail('NOT_IN_CAMP','Change your squad between rooms.',409);
    if(typeof value.actorId!=='string'||!current.run.party.some(actor=>actor.id===value.actorId))return fail('NOT_YOUR_CHARACTER','Choose a member of your own squad.',403);
    try{player.session=createTowerSession(action==='build'?updateTowerBuild(current.run,value.actorId,value.build as TowerBuild):updateTowerLoadout(current.run,value.actorId,value.loadout as string[]));openStep(player);}catch(error){return fail('INVALID_BUILD',error instanceof Error?error.message:'Choose a legal build.');}
   }else if(group){
    if(group.battle.winner!==null)return fail('NOT_PLANNING','Your battle is not accepting orders.',409);
    if(action==='unlock'){group.readySeats=group.readySeats.filter(other=>other!==seat);player.step++;}
    else{
     if(group.readySeats.includes(seat))return fail('PLAN_LOCKED','Unlock your orders to change them.',409);
     let plan:TeamPlan;try{plan=validateSharedTowerPlan(group.battle,seat,object(value.plan,['orders','link']));}catch(error){return fail('INVALID_PLAN',error instanceof Error?error.message:'Send legal orders for your own squad.');}
     current.plan=plan;
     if(action==='resolve'){group.readySeats.push(seat);player.step++;resolveSharedWhenReady(data,group);}
    }
   }else{
    if(action==='unlock')return fail('NOT_SHARED','Only a shared battle waits for allied orders.',409);
    if(!current.battle||current.battle.winner!==null)return fail('NOT_PLANNING','Your battle is not accepting orders.',409);
    let plan:TeamPlan;try{const inputPlan=object(value.plan,['orders']);plan=validatePlan(current.battle,0,inputPlan);const supplied=Array.isArray(inputPlan.orders)?new Set(inputPlan.orders.map(order=>object(order).unitId)):new Set();if(action==='draft')plan={orders:plan.orders.filter(order=>supplied.has(order.unitId))};}catch(error){return fail('INVALID_PLAN',error instanceof Error?error.message:'Send legal orders for your squad.');}
    if(action==='draft')player.session=createTowerSession(current.run,current.battle,plan,current.previous);
    else{if(!player.enemyPlan)return fail('MISSING_ENEMY_PLAN','This turn could not be restored. The climb has been preserved.',409);const next=resolveRound(current.battle,[plan,player.enemyPlan]);player.session=createTowerSession(current.run,next,{orders:[]},current.battle);openStep(player);}
   }
   computed={source,player:JSON.stringify(player)};refreshBarrier(data);
  }
  player.receipts=[...player.receipts,{id:value.requestId,digest}].slice(-32);const updated=await save(db,row,data,now);if(updated)return {room:snapshot(updated,seat,selected)};
 }return fail('ROOM_CHANGED','Your friends updated the climb at the same time. Try again.',409);
}
