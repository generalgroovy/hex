import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {createTowerRoom,joinTowerRoom,getTowerRoom,actTowerRoom,type TowerRoomSnapshot} from '../lib/tower-rooms-v23.ts';
import {RoomError,type RoomDatabase} from '../lib/rooms.ts';
import {chooseAIPlan,legalCasts,restoreSimState} from '../lib/tactics-v22.ts';
import {towerRoomChoices,towerRewardChoices} from '../lib/tower-v23.ts';
import {sharedActorId} from '../lib/tower-shared-battle-v23.ts';
const NOW=1800000000000,keys=['a'.repeat(64),'b'.repeat(64)];
function database(){
 const sql=new DatabaseSync(':memory:');for(const name of readdirSync(new URL('../drizzle/',import.meta.url)).filter(name=>name.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(`../drizzle/${name}`,import.meta.url),'utf8'));
 const db={prepare(text:string){let values:(string|number|null)[]=[];const statement={bind(...args:(string|number|null)[]){values=args;return statement},async first<T>(){return (sql.prepare(text).get(...values)??null) as T|null},async run(){return sql.prepare(text).run(...values)}};return statement}} as unknown as RoomDatabase;
 return {db,sql};
}
test('real cooperative progression equips, swaps, carries and spends a scroll once across idempotent service requests',async(t)=>{
 const {db,sql}=database();try{
  const host=await createTowerRoom(db,{name:'Host',starter:'steezo',seed:'FOCUS42-B',capacity:2,clientToken:keys[0]},NOW),code=host.code;
  await joinTowerRoom(db,code,{name:'Friend',starter:'steam',clientToken:keys[1]},NOW);
  const read=async(seat:number)=>(await getTowerRoom(db,code,keys[seat],NOW+10)).room;
  const command=(room:TowerRoomSnapshot,action:string,fields:Record<string,unknown>={})=>({action,runId:room.runId,stepId:room.stepId,requestId:crypto.randomUUID(),...fields});
  const send=async(seat:number,action:string,fields:Record<string,unknown>={})=>(await actTowerRoom(db,code,keys[seat],command(await read(seat),action,fields),NOW+20)).room;
  for(const seat of [0,1])await send(seat,'ready',{ready:true});await send(0,'start');
  const enter=async(kind?:string)=>{
   const room=await read(0),choices=towerRoomChoices(room.session!.run),choice=choices.find(choice=>kind?choice.kind===kind:choice.kind==='combat')??choices[0];
   for(const seat of [0,1])await send(seat,'choose',{choiceId:choice.id});
  };
  const win=async()=>{
   for(let n=0;n<18;n++){
    const room=await read(0),battle=room.session!.battle!;if(battle.winner!==null){assert.equal(battle.winner,0);t.diagnostic(`Floor ${room.sharedFloor}: ${battle.round} exchanges`);return;}
    const plan=chooseAIPlan(battle,0);
    for(const seat of [0,1])await send(seat,'resolve',{plan:{orders:plan.orders.filter(order=>battle.tower.controllers![order.unitId]===seat)}});
   }
   assert.fail('Opening service fixture did not finish within18 exchanges');
  };
  await enter();await win();for(const seat of [0,1])await send(seat,'finish');
  for(const seat of [0,1]){
   const before=await read(seat),reward=towerRewardChoices(before.session!.run).find(reward=>reward.kind==='charm')!;
   assert.ok(reward);const req=command(before,'reward',{choiceId:reward.id,recipientActorId:'hero'}),after=(await actTowerRoom(db,code,keys[seat],req,NOW+20)).room;
   assert.equal(after.session!.run.party[0].charmId,reward.charmId);
   const again=(await actTowerRoom(db,code,keys[seat],req,NOW+20)).room;assert.equal(again.version,after.version);
  }
  const before=await read(0),request=command(before,'supply',{actorId:'hero',targetActorId:'companion',slot:'charm'});
  const transferred=(await actTowerRoom(db,code,keys[0],request,NOW+20)).room;
  assert.ok(transferred.session!.run.party[1].charmId);assert.equal(transferred.session!.run.party[0].charmId,undefined);
  const replayed=(await actTowerRoom(db,code,keys[0],request,NOW+20)).room;assert.equal(replayed.version,transferred.version);
  await assert.rejects(send(0,'supply',{actorId:'companion',targetActorId:'seat-1:hero',slot:'charm'}),(error:unknown)=>error instanceof RoomError&&error.code==='INVALID_SUPPLY');
  await enter();await win();for(const seat of [0,1])await send(seat,'finish');
  for(const seat of [0,1]){const room=await read(seat),reward=towerRewardChoices(room.session!.run).find(reward=>reward.kind==='scroll')!;assert.ok(reward);await send(seat,'reward',{choiceId:reward.id,recipientActorId:'hero'});}
  await enter('camp');
  for(const seat of [0,1]){const room=await read(seat),reward=towerRewardChoices(room.session!.run).find(reward=>reward.kind==='heal')??towerRewardChoices(room.session!.run)[0];await send(seat,'reward',{choiceId:reward.id});}
  await enter();const active=await read(0),battle=active.session!.battle!,id=sharedActorId(0,'hero'),unit=battle.units.find(unit=>unit.id===id)!;
  assert.ok(unit.scrollSpellId);const aim=legalCasts(battle,id,undefined,unit.scrollSpellId,true)[0];assert.ok(aim);
  const plan={orders:[{unitId:id,spellId:unit.scrollSpellId,scroll:true,cast:{q:aim.q,r:aim.r}}]};
  await assert.rejects(send(1,'draft',{plan}),(error:unknown)=>error instanceof RoomError&&error.code==='INVALID_PLAN');
  const lock=command(await read(0),'resolve',{plan});await actTowerRoom(db,code,keys[0],lock,NOW+20);await send(1,'resolve',{plan:{orders:[]}});
  const resolved=await read(0);assert.equal(resolved.session!.battle!.units.find(unit=>unit.id===id)!.spentScroll,true);
  assert.equal(resolved.session!.battle!.lastResolution.filter(event=>event.scroll&&event.unitId===id).length,1);
  assert.deepEqual(restoreSimState(resolved.session!.battle),resolved.session!.battle);
  const late=(await actTowerRoom(db,code,keys[0],lock,NOW+20)).room;assert.equal(late.session!.battle!.version,resolved.session!.battle!.version);
  await assert.rejects(send(0,'draft',{plan}),(error:unknown)=>error instanceof RoomError&&error.code==='INVALID_PLAN');
 }finally{sql.close();}
});
