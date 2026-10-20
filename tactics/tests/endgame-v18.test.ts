import test from 'node:test';
import assert from 'node:assert/strict';
import {endgameForecast,collapseDamageAt,isSafe,endgamePositionValue} from '../lib/endgame-v18.ts';
import {createSimGame,resolveRound,restoreSimState,eliminationWinner,chooseAIPlan,validatePlan,type SimState,type TeamPlan,type PlayerCount} from '../lib/tactics-v18.ts';
import {createSimGame as create17,resolveRound as resolve17,restoreSimState as restore17} from '../lib/tactics-v17.ts';
const empty=():TeamPlan=>({orders:[]});
const guards=(n:number)=>Array.from({length:n},empty);
const setRound=(state:SimState,round:number)=>{state.round=round;state.version=round;state.lastResolution=[];return state;};
const flatten=(state:SimState)=>{state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',height:0,biome:'plain'}));return state;};
const kill=(u:SimState['units'][number])=>{u.hp=0;u.flux=0;u.statuses={};u.cooldowns={};delete u.guard;};

test('every closure schedule gives two-round warning and two rings per two rounds, then exactly one safe hex',()=>{
  const finalRounds=[18,19,22,23,26];
  for(const [index,playerCount] of ([2,3,4,5,6] as PlayerCount[]).entries()){
    const state=createSimGame({playerCount}),first=playerCount+8,radius=playerCount+7;
    const zone=(round:number)=>endgameForecast({...state,round});
    assert.equal(zone(first-3).phase,'calm');assert.equal(zone(first-2).phase,'warning');assert.equal(zone(first-1).phase,'warning');assert.equal(zone(first).phase,'closing');
    assert.equal(zone(first-2).nextChangeRound,first);assert.equal(zone(first-2).nextSafeRadius,radius-2);assert.equal(zone(first-2).damage,0);
    for(let round=first;round<finalRounds[index];round++){
      const wave=Math.floor((round-first)/2)+1,current=zone(round);assert.equal(current.safeRadius,Math.max(0,radius-2*wave));assert.equal(current.damage,wave);assert.equal(current.nextChangeRound,first+wave*2);
      assert.equal(collapseDamageAt({...state,round},{q:current.safeRadius,r:0}),0);assert.equal(collapseDamageAt({...state,round},{q:current.safeRadius+1,r:0}),wave);
    }
    const last=zone(finalRounds[index]);assert.equal(last.phase,'last-stand');assert.equal(last.finalRound,finalRounds[index]);assert.equal(last.safeRadius,0);assert.equal(last.damage,8);assert.equal(last.nextChangeRound,null);
    assert.equal(state.cells.filter(cell=>isSafe(cell,last.safeRadius)).length,1);const centre=state.cells.find(c=>c.q===0&&c.r===0)!;assert.equal(centre.well,true);assert.notEqual(centre.biome,'ruins');
    assert.throws(()=>endgameForecast({...state,boardRadius:99}));
  }
});
test('elimination no longer declares a draw while opposing companies remain, and v17 stays frozen',()=>{
  const state=createSimGame({playerCount:6});assert.equal(eliminationWinner(state.units,20,state.teams),null);assert.equal(eliminationWinner(state.units,99,state.teams),null);
  const old=create17({playerCount:6});old.round=20;old.version=20;assert.equal(resolve17(old,guards(6)).winner,'draw');assert.equal(restore17(old).rulesVersion,17);assert.throws(()=>restoreSimState(old));
});
test('collapse applies after healing and ignores Guard, Ward and ordinary terrain mitigation',()=>{
  const state=flatten(createSimGame({playerCount:2,rosters:Array.from({length:2},()=>['haara','oh_tipi','treevor_mason'])}));setRound(state,14);
  const caster=state.units[0],ally=state.units[1];Object.assign(caster,{q:4,r:0});Object.assign(ally,{q:4,r:-1,hp:6,statuses:{ward:{turns:2,power:5}}});
  const next=resolveRound(state,[{orders:[{unitId:caster.id,spellId:'mend',cast:{q:4,r:-1}}]},empty()]);
  // Wave3: Mend restores at least2 up to8, thenunmitigated3collapse leaves5.
  assert.equal(next.units.find(u=>u.id===ally.id)!.hp,5);assert.equal(next.lastResolution.find(e=>e.unitId===ally.id&&e.cause==='collapse')!.amount,3);
  const damageIndex=next.lastResolution.findIndex(e=>e.unitId===ally.id&&e.cause==='collapse'),healIndex=next.lastResolution.findIndex(e=>e.unitId===ally.id&&e.kind==='heal');assert.ok(healIndex>=0&&damageIndex>healIndex);
});
test('collapse reads final displacement: an enemy can push a centre holder into the final lethal band',()=>{
  const state=flatten(createSimGame({playerCount:2}));setRound(state,18);const holder=state.units[0],pusher=state.units[4];state.units.filter(u=>u.id!==holder.id&&u.id!==pusher.id).forEach(kill);
  Object.assign(holder,{q:0,r:0});Object.assign(pusher,{q:-1,r:0});
  const next=resolveRound(state,[{orders:[{unitId:holder.id,spellId:'cleansing_tide',cast:{q:0,r:0}}]},{orders:[{unitId:pusher.id,spellId:'gust',cast:{q:0,r:0}}]}]);
  assert.ok(next.lastResolution.some(e=>e.kind==='push'&&e.unitId===holder.id));assert.ok(next.units.every(u=>u.hp===0));assert.equal(next.winner,'draw');assert.equal(next.lastResolution.filter(e=>e.kind==='defeat').length,2);
});
test('final centre survivor wins only after all actual outer deaths, including three allied seats',()=>{
  const state=createSimGame({playerCount:6,mode:'teams'});setRound(state,26);const centre=state.units[6];Object.assign(centre,{q:0,r:0});
  const next=resolveRound(state,guards(6));assert.equal(next.winner,0);assert.equal(next.units.filter(u=>u.hp>0).length,1);assert.equal(next.lastResolution.filter(e=>e.kind==='defeat').length,17);assert.equal(next.lastResolution.filter(e=>e.cause==='collapse').length,17);assert.deepEqual(restoreSimState(next),next);
});
test('strict restore rejects skipped or invented collapse and altered per-map termination bounds',()=>{
  const state=createSimGame({playerCount:2});setRound(state,10);Object.assign(state.units[0],{q:-8,r:0});const next=resolveRound(state,guards(2));assert.deepEqual(restoreSimState(next),next);
  const wrongDamage=structuredClone(next);wrongDamage.lastResolution.find(e=>e.cause==='collapse')!.amount=8;assert.throws(()=>restoreSimState(wrongDamage));
  const skipped=structuredClone(next);skipped.lastResolution=skipped.lastResolution.filter(e=>e.cause!=='collapse');assert.throws(()=>restoreSimState(skipped));
  const tooHealthy=structuredClone(next);tooHealthy.units[0].hp=8;assert.throws(()=>restoreSimState(tooHealthy));
  const duplicate=structuredClone(next);duplicate.lastResolution.push({...duplicate.lastResolution.find(e=>e.cause==='collapse')!});assert.throws(()=>restoreSimState(duplicate));
  const tooLate=createSimGame({playerCount:2});setRound(tooLate,19);assert.throws(()=>restoreSimState(tooLate));
});
test('bots prefer a reachable safe final landing over a speculative lethal attack',()=>{
  const state=flatten(createSimGame({playerCount:2}));setRound(state,18);const unit=state.units[0];state.units.filter(u=>u.id!==unit.id&&u.owner===0).forEach(kill);Object.assign(unit,{q:2,r:0});
  assert.ok(endgamePositionValue(state,{q:0,r:0},8)>endgamePositionValue(state,{q:1,r:0},8)+200);
  const plan=chooseAIPlan(state,0);assert.deepEqual(validatePlan(state,0,plan),plan);assert.deepEqual(plan.orders[0].move,{q:0,r:0});
  const result=resolveRound(state,[plan,empty()]);assert.equal(result.winner,0);assert.equal(result.units.find(u=>u.id===unit.id)!.hp>0,true);
});
