import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom,type TowerRoomSnapshot} from '../lib/tower-rooms-v23.ts';
import {towerRoomChoices,towerRewardChoices,towerChampion,createTowerSession,type TowerStarterInput,type TowerMemberInput} from '../lib/tower-v23.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';
import {resolveRound,type SimState} from '../lib/tactics-v22.ts';

const NOW=1800000000000,keys=Array.from({length:6},(_,index)=>(index+1).toString().repeat(64));
function database(){
 const sql=new DatabaseSync(':memory:');for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));
 const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null},async run(){return sql.prepare(text).run(...values)}};return statement}} as unknown as RoomDatabase;
 return {db,sql};
}
const read=(db:RoomDatabase,code:string,seat:number)=>getTowerRoom(db,code,keys[seat],NOW+100).then(reply=>reply.room);
const request=(room:TowerRoomSnapshot,action:string,fields:Record<string,unknown>={},requestId=crypto.randomUUID())=>({action,runId:room.runId,stepId:room.stepId,requestId,...fields});
const fault=(code:string)=>(error:unknown)=>error instanceof RoomError&&error.code===code;
async function act(db:RoomDatabase,code:string,seat:number,action:string,fields:Record<string,unknown>={}){const room=await read(db,code,seat);return (await actTowerRoom(db,code,keys[seat],request(room,action,fields),NOW+100)).room;}
async function start(db:RoomDatabase,starters:TowerStarterInput[],legacy=false){
 const host=await createTowerRoom(db,{name:'Scout host',starter:starters[0],seed:'SHARED-SCOUTS',capacity:starters.length,clientToken:keys[0]},NOW);
 if(legacy){const saved=await db.prepare('SELECT data_json FROM tower_rooms_v23 WHERE code = ?').bind(host.code).first<{data_json:string}>();const data=JSON.parse(saved!.data_json);delete data.sharedRules;await db.prepare('UPDATE tower_rooms_v23 SET data_json = ? WHERE code = ?').bind(JSON.stringify(data),host.code).run();}
 for(let seat=1;seat<starters.length;seat++)await joinTowerRoom(db,host.code,{name:`Scout ${seat}`,starter:starters[seat],clientToken:keys[seat]},NOW+seat);
 for(let seat=0;seat<starters.length;seat++)await act(db,host.code,seat,'ready',{ready:true});
 await act(db,host.code,0,'start');
 if(legacy){const row=await db.prepare('SELECT data_json FROM tower_rooms_v23 WHERE code = ?').bind(host.code).first<{data_json:string}>();const data=JSON.parse(row!.data_json);for(const player of data.players.filter(Boolean)){delete player.session.run.encounterModel;delete player.session.run.encounterVariant;player.session=createTowerSession(player.session.run);}await db.prepare('UPDATE tower_rooms_v23 SET data_json = ? WHERE code = ?').bind(JSON.stringify(data),host.code).run();}
 return host.code;
}
function champion(championId:string):TowerMemberInput{const actor=towerChampion(championId,'preview');return {kind:'champion',build:{championId,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout}};}
const twoChampions:TowerStarterInput={starterId:'steam',members:[champion('oh_tipi'),champion('treevor_mason')]};
const twoCreatures:TowerStarterInput={starterId:'steam',members:[{kind:'creature',creatureId:'creature-fire-cinder'},{kind:'creature',creatureId:'creature-water-puddle'}]};
const privateData=(sql:DatabaseSync,code:string)=>JSON.parse(String(sql.prepare('SELECT data_json FROM tower_rooms_v23 WHERE code = ?').get(code)!.data_json));

test('each owned champion scouts once, retries are exact, and allied steps remain valid',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,[twoChampions,'steam']),before=await read(db,code,0),ally=await read(db,code,1),roomId=towerRoomChoices(before.session!.run)[0].id;
  const command=request(before,'scout',{actorId:'hero',choiceId:roomId}),first=(await actTowerRoom(db,code,keys[0],command,NOW+100)).room;
  assert.deepEqual(first.session!.run.scouting?.usedActorIds,['hero']);assert.equal(first.session!.run.scouting?.reports.length,1);assert.equal(first.scoutReports.length,1);
  assert.equal((await read(db,code,1)).stepId,ally.stepId,'Receiving information must not invalidate another player action');
  const retry=(await actTowerRoom(db,code,keys[0],command,NOW+100)).room;assert.equal(retry.version,first.version);assert.deepEqual(retry.scoutReports,first.scoutReports);
  await assert.rejects(act(db,code,0,'scout',{actorId:'hero',choiceId:roomId}),fault('INVALID_SCOUT'));
  const second=await act(db,code,0,'scout',{actorId:'companion',choiceId:roomId});assert.equal(second.session!.run.scouting?.usedActorIds.length,2);assert.equal(second.scoutReports.length,2);
  assert.notEqual(second.scoutReports[0].id,second.scoutReports[1].id);
  await assert.rejects(act(db,code,0,'scout',{actorId:'someone-elses-character',choiceId:roomId}),fault('NOT_YOUR_CHARACTER'));
  await assert.rejects(act(db,code,1,'scout',{actorId:'companion',choiceId:roomId}),fault('INVALID_SCOUT'));
  const wire=JSON.stringify(second);for(const key of ['enemyPlan','tokenHash','receipts'])assert.ok(!wire.includes(key));
 }finally{sql.close();}
});

test('shared discoveries apply only to matching encounter strength and do not spend allied scouts',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,['steam','dusk',twoCreatures,'stone']),before=await read(db,code,0),roomId=towerRoomChoices(before.session!.run)[0].id;
  const own=await act(db,code,0,'scout',{actorId:'hero',choiceId:roomId}),same=await read(db,code,3),lighter=await read(db,code,2);
  assert.equal(own.scoutReports.length,1);assert.deepEqual(same.scoutReports,own.scoutReports);
  assert.equal(lighter.scoutReports.length,0,'A one-creature encounter cannot inherit facts about the stronger two-enemy room');
  assert.equal(same.session!.run.scouting?.usedActorIds.length??0,0);assert.equal(same.session!.run.scouting?.reports.length??0,0,'Only the shared snapshot receives allied reports');
  const ally=await act(db,code,3,'scout',{actorId:'hero',choiceId:roomId});assert.equal(ally.scoutReports.length,2);assert.notEqual(ally.scoutReports[0].id,ally.scoutReports[1].id);
  assert.equal((await read(db,code,0)).scoutReports.length,2);assert.equal((await read(db,code,2)).scoutReports.length,0);
 }finally{sql.close();}
});

test('concurrent six-player scouting keeps every spend and avoids repeated facts after CAS retries',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,Array.from({length:6},()=>'steam')),before=await Promise.all(keys.map((_,seat)=>read(db,code,seat)));
  const commands=before.map((room,seat)=>request(room,'scout',{actorId:'hero',choiceId:towerRoomChoices(room.session!.run)[seat%3].id}));
  await Promise.all(commands.map((command,seat)=>actTowerRoom(db,code,keys[seat],command,NOW+100)));
  const after=await Promise.all(keys.map((_,seat)=>read(db,code,seat)));
  for(const room of after){const run=room.session!.run,legalFacts=new Set(towerRoomChoices(run).flatMap(door=>scoutFactsForRoom(run,door)).map(fact=>fact.id)),expected=privateData(sql,code).scoutReports.filter((report:{id:string})=>legalFacts.has(report.id));assert.deepEqual(run.scouting?.usedActorIds,['hero']);assert.deepEqual([...room.scoutReports].sort((a,b)=>a.id.localeCompare(b.id)),expected.sort((a:{id:string},b:{id:string})=>a.id.localeCompare(b.id)));assert.ok(room.scoutReports.length>=2,'The same-role partner contributes a distinct clue');assert.equal(new Set(room.scoutReports.map(report=>`${report.encounterKey}:${report.id}`)).size,room.scoutReports.length);}
  for(let seat=0;seat<6;seat++)assert.equal((await actTowerRoom(db,code,keys[seat],commands[seat],NOW+100)).room.version,after[0].version);
  assert.equal(privateData(sql,code).scoutReports.length,6);
 }finally{sql.close();}
});

test('legacy friend scouting cannot change the enemy plan or invalidate an already planned battle turn',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,['steam','stone'],true),route=await read(db,code,0),roomId=towerRoomChoices(route.session!.run)[0].id;
  const battle=await act(db,code,1,'choose',{choiceId:roomId}),enemyPlan=privateData(sql,code).players[1].enemyPlan;
  const submitted=request(battle,'resolve',{plan:{orders:[]}});
  await act(db,code,0,'scout',{actorId:'hero',choiceId:roomId});
  assert.equal((await read(db,code,1)).stepId,battle.stepId);assert.deepEqual(privateData(sql,code).players[1].enemyPlan,enemyPlan);
  const resolved=(await actTowerRoom(db,code,keys[1],submitted,NOW+100)).room;assert.equal(resolved.session!.battle!.round,2);
  const watching=(await getTowerRoom(db,code,keys[0],NOW+100,1)).room;
  assert.equal(watching.watch!.session.battle!.round,2);assert.equal(watching.session!.run.phase,'route');assert.equal(watching.session!.run.scouting!.usedActorIds.length,1);
  assert.ok(!JSON.stringify(watching).includes('enemyPlan'));
 }finally{sql.close();}
});

// Synthetic terminal state is used only to exercise checkpoint protocol; this
// is not a claim about battle balance or the likelihood of winning a room.
function finishFixture(sql:DatabaseSync,code:string,seat:number){
 const data=privateData(sql,code),player=data.players[seat],state=player.session.battle as SimState;
 for(const unit of state.units.filter(unit=>unit.owner===1)){unit.hp=0;unit.flux=0;unit.cooldowns={};unit.statuses={};delete unit.guard;}
 const won=resolveRound(state,[{orders:[]},{orders:[]}]);player.session=createTowerSession(player.session.run,won);player.enemyPlan=null;player.step++;
 sql.prepare('UPDATE tower_rooms_v23 SET data_json = ?, version = version + 1 WHERE code = ?').run(JSON.stringify(data),code);
}
test('legacy scouting survives an early finisher, rejects battle and barrier actions, and resets at the shared stairs',async()=>{
 const {db,sql}=database();try{
  const code=await start(db,['steam','stone'],true),host=await read(db,code,0),roomId=towerRoomChoices(host.session!.run)[0].id;
  await act(db,code,0,'scout',{actorId:'hero',choiceId:roomId});await act(db,code,0,'choose',{choiceId:roomId});
  await assert.rejects(act(db,code,0,'scout',{actorId:'hero',choiceId:roomId}),fault('NOT_SCOUTING'));
  finishFixture(sql,code,0);const completed=await act(db,code,0,'finish');await act(db,code,0,'reward',{choiceId:towerRewardChoices(completed.session!.run)[0].id});
  const waiting=await read(db,code,0);assert.equal(waiting.canEnter,false);assert.equal(waiting.session!.run.floor,2);assert.equal(waiting.scoutReports.length,0);
  await assert.rejects(act(db,code,0,'scout',{actorId:'hero',choiceId:'floor-2-0'}),fault('FLOOR_BARRIER'));
  assert.equal((await read(db,code,1)).scoutReports.length,1,'A completed squad must not erase intelligence still useful to its friends');
  await act(db,code,1,'choose',{choiceId:roomId});finishFixture(sql,code,1);const second=await act(db,code,1,'finish');await act(db,code,1,'reward',{choiceId:towerRewardChoices(second.session!.run)[0].id});
  for(const seat of [0,1]){const fresh=await read(db,code,seat);assert.equal(fresh.sharedFloor,2);assert.equal(fresh.canEnter,true);assert.equal(fresh.scoutReports.length,0);assert.equal(fresh.session!.run.scouting?.usedActorIds.length??0,0);}
  assert.equal(privateData(sql,code).scoutReports.length,0);
  const fresh=await act(db,code,0,'scout',{actorId:'hero',choiceId:'floor-2-0'});assert.equal(fresh.scoutReports.length,1);
 }finally{sql.close();}
});
