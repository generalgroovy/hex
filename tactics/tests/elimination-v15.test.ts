import test from 'node:test';
import assert from 'node:assert/strict';
import {chooseAIPlan,createSimGame,distance,getCell,isAlive,legalMoves,MAX_ROUNDS,previewField,resolveRound,restoreSimState,validatePlan,type SimState,type SimUnit,type TeamPlan} from '../lib/tactics-v15.ts';
import {choosePracticePlan} from '../lib/practice-v15.ts';
import {createSimGame as createOld,resolveRound as resolveOld,restoreSimState as restoreOld} from '../lib/tactics-v14.ts';

const empty=():TeamPlan=>({orders:[]});
const dead=(unit:SimUnit)=>{unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;delete unit.respawn;};
const canonical=(state:SimState)=>({...state,units:[...state.units].sort((a,b)=>a.id.localeCompare(b.id))});

test('a defeated champion stays out, cannot receive orders, and is not defeated repeatedly',()=>{
  let state=createSimGame();const id=state.units[0].id;
  state.units[0].hp=1;state.units[0].statuses.burn={turns:2,power:1};
  state=resolveRound(state,[empty(),empty()]);
  const fallen=state.units.find(unit=>unit.id===id)!;
  assert.equal(fallen.hp,0);assert.equal(fallen.flux,0);assert.equal(fallen.respawn,undefined);
  assert.equal(state.lastResolution.filter(event=>event.kind==='defeat'&&event.unitId===id).length,1);
  assert.deepEqual(state.scores,[0,0]);assert.equal(state.winner,null);
  assert.deepEqual(legalMoves(state,id),[]);
  assert.throws(()=>validatePlan(state,0,{orders:[{unitId:id,guard:true}]}));
  restoreSimState(state);
  for(let round=0;round<4;round++){
    state=resolveRound(state,[empty(),empty()]);restoreSimState(state);
    assert.equal(state.units.find(unit=>unit.id===id)!.hp,0);
    assert.ok(!state.lastResolution.some(event=>event.kind==='respawn'||event.kind==='defeat'&&event.unitId===id));
  }
});

test('defeating the entire enemy team wins, without any well or score threshold',()=>{
  const state=createSimGame();
  state.units.filter(unit=>unit.owner===1).forEach(unit=>{unit.hp=1;unit.statuses.burn={turns:2,power:1};});
  const result=resolveRound(state,[empty(),empty()]);
  assert.equal(result.winner,0);assert.equal(result.round,1);assert.equal(result.version,2);
  assert.equal(result.units.filter(unit=>unit.owner===1&&isAlive(unit)).length,0);
  assert.deepEqual(result.scores,[0,0]);assert.ok(!result.lastResolution.some(event=>event.kind==='score'));
  assert.deepEqual(restoreSimState(result),result);
  assert.throws(()=>resolveRound(result,[empty(),empty()]),/not active/);
});

test('both last champions still cast simultaneously and a mutual final defeat is a draw',()=>{
  const state=createSimGame();state.cells=state.cells.map(({q,r})=>({q,r,terrain:'plain',biome:'plain',height:0,well:false}));
  state.units.forEach(unit=>{if(unit.championId!=='oh_tipi')dead(unit);else unit.hp=1;});
  const left=state.units[0],right=state.units[3];Object.assign(left,{q:0,r:0});Object.assign(right,{q:1,r:0});
  const plans:[TeamPlan,TeamPlan]=[{orders:[{unitId:left.id,spellId:'ember',cast:{q:1,r:0}}]},{orders:[{unitId:right.id,spellId:'ember',cast:{q:0,r:0}}]}];
  const original=JSON.stringify(state),result=resolveRound(state,plans);
  assert.equal(result.lastResolution.filter(event=>event.kind==='cast').length,2);
  assert.equal(result.lastResolution.filter(event=>event.kind==='defeat').length,2);
  assert.equal(result.winner,'draw');assert.ok(result.units.every(unit=>!isAlive(unit)));
  assert.deepEqual(canonical(resolveRound({...state,units:[...state.units].reverse()},plans)),canonical(result));
  assert.equal(JSON.stringify(state),original);
});

test('simultaneous environmental wipe is a valid restorable draw',()=>{
  const state=createSimGame();state.units.forEach(unit=>{unit.hp=1;unit.statuses.burn={turns:2,power:1};});
  const result=resolveRound(state,[empty(),empty()]);
  assert.equal(result.winner,'draw');assert.equal(result.lastResolution.filter(event=>event.kind==='defeat').length,6);
  assert.deepEqual(restoreSimState(result),result);
});

test('healing ground cannot revive a defeated champion in a later exchange',()=>{
  let state=createSimGame();state.units[0].hp=1;state.units[0].statuses.burn={turns:2,power:1};
  state=resolveRound(state,[empty(),empty()]);const fallen=state.units[0],cell=getCell(state,fallen.q,fallen.r)!;
  Object.assign(cell,previewField(cell,['water','light']));
  const result=resolveRound(state,[empty(),empty()]);
  assert.equal(result.units[0].hp,0);assert.equal(result.units[0].flux,0);
  assert.ok(!result.lastResolution.some(event=>event.unitId===fallen.id&&['heal','respawn','defeat'].includes(event.kind)));
  restoreSimState(result);
});

test('existing simultaneous elemental spell outcomes are retained apart from the victory economy',()=>{
  const state=createSimGame();state.cells=state.cells.map(({q,r})=>({q,r,terrain:'plain',biome:'plain',height:0,well:false}));
  Object.assign(state.units[0],{q:0,r:0});Object.assign(state.units[1],{q:0,r:1});Object.assign(state.units[3],{q:2,r:0});
  const plans:[TeamPlan,TeamPlan]=[{orders:[{unitId:state.units[0].id,spellId:'water_jet',cast:{q:2,r:0}},{unitId:state.units[1].id,spellId:'gust',cast:{q:2,r:0}}]},{orders:[{unitId:state.units[3].id,spellId:'ember',cast:{q:2,r:0}}]}];
  const old=resolveOld({...structuredClone(state),rulesVersion:14},plans),current=resolveRound(state,plans);
  assert.deepEqual(current.units,old.units);assert.deepEqual(current.cells,old.cells);
  assert.deepEqual(current.lastResolution,old.lastResolution.filter(event=>event.kind!=='score'));
  assert.ok(current.lastResolution.some(event=>event.kind==='reaction'));
});

test('springs grant capped Flux, including their compound bonus, but cannot win a battle',()=>{
  const state=createSimGame(),well=state.cells.find(cell=>cell.well)!;
  Object.assign(state.units[0],{q:well.q,r:well.r,flux:0});state.units[1].flux=0;
  const first=resolveRound(state,[empty(),empty()]);
  assert.equal(first.units[0].flux,4,'2 baseline + 1 Guard + 1 spring');
  assert.equal(first.units[1].flux,3,'ordinary ground gets no spring recovery');
  assert.deepEqual(first.scores,[0,0]);assert.equal(first.winner,null);restoreSimState(first);
  const compound=createSimGame(),spring=compound.cells.find(cell=>cell.well)!;
  Object.assign(spring,previewField(spring,['light','dark']));
  assert.equal(spring.terrain,'penumbra');
  Object.assign(compound.units[0],{q:spring.q,r:spring.r,flux:0});
  const boosted=resolveRound(compound,[empty(),empty()]);assert.equal(boosted.units[0].flux,5);restoreSimState(boosted);
  const capped=resolveRound(boosted,[empty(),empty()]);assert.equal(capped.units[0].flux,6);
});

test('the round limit draws surviving teams even if their health and survivor counts differ',()=>{
  const state=createSimGame();state.round=MAX_ROUNDS;state.version=MAX_ROUNDS;
  dead(state.units[3]);dead(state.units[4]);state.units[5].hp=1;
  restoreSimState(state);
  const result=resolveRound(state,[empty(),empty()]);
  assert.equal(result.winner,'draw');assert.equal(result.round,MAX_ROUNDS);assert.equal(result.version,MAX_ROUNDS+1);
  assert.deepEqual(restoreSimState(result),result);
  const finalKill=createSimGame();finalKill.round=MAX_ROUNDS;finalKill.version=MAX_ROUNDS;
  finalKill.units.filter(unit=>unit.owner===1).forEach(unit=>{unit.hp=1;unit.statuses.burn={turns:2,power:1};});
  assert.equal(resolveRound(finalKill,[empty(),empty()]).winner,0,'actual elimination takes precedence over the limit');
});

test('restore rejects score victories, returning champions, false winners and stale dead-unit state',()=>{
  const live=createSimGame();
  for(const mutate of [
    (state:SimState)=>{state.scores=[16,0];},
    (state:SimState)=>{state.winner=0;state.version++;},
    (state:SimState)=>{state.winner='draw';state.version++;},
    (state:SimState)=>{dead(state.units[0]);state.units[0].respawn=3;},
    (state:SimState)=>{dead(state.units[0]);state.units[0].flux=1;},
    (state:SimState)=>{dead(state.units[0]);state.units[0].statuses.ward={turns:1,power:1};},
    (state:SimState)=>{dead(state.units[0]);state.units[0].guard=true;},
    (state:SimState)=>{state.lastResolution=[{kind:'respawn',unitId:state.units[0].id,text:'Returns'}];},
    (state:SimState)=>{state.lastResolution=[{kind:'score',owner:0,amount:1,text:'Scores'}];},
    (state:SimState)=>{state.units.filter(unit=>unit.owner===1).forEach(dead);},
  ]){const forged=structuredClone(live);mutate(forged);assert.throws(()=>restoreSimState(forged));}
  const dying=createSimGame();dying.units.filter(unit=>unit.owner===1).forEach(unit=>{unit.hp=1;unit.statuses.burn={turns:2,power:1};});
  const won=resolveRound(dying,[empty(),empty()]);assert.throws(()=>restoreSimState({...won,winner:1}));assert.throws(()=>restoreSimState({...won,winner:'draw'}));
});

test('rules14 retains returning champions and point scoring byte-for-byte at the public boundary',()=>{
  const state=createOld();state.units[0].hp=1;state.units[0].statuses.burn={turns:2,power:1};
  const result=resolveOld(state,[empty(),empty()]);
  assert.equal(result.rulesVersion,14);assert.equal(result.units[0].respawn,3);assert.equal(result.scores[1],1);
  assert.ok(result.lastResolution.some(event=>event.kind==='score'));
  assert.deepEqual(restoreOld(result),result);assert.throws(()=>restoreSimState(result));
});

test('the combat AI advances toward opponents and is independent of unit array order',()=>{
  const state=createSimGame(undefined,'frontier:ELIMINATION-TACTICS');
  const own=state.units.filter(unit=>unit.owner===0),rivals=state.units.filter(unit=>unit.owner===1);
  const plan=choosePracticePlan(state,0);validatePlan(state,0,plan);
  const nearest=(unit:SimUnit,point=unit)=>Math.min(...rivals.map(rival=>distance(point,rival)));
  assert.ok(plan.orders.some(order=>order.move&&nearest(own.find(unit=>unit.id===order.unitId)!,{...own.find(unit=>unit.id===order.unitId)!,...order.move})<nearest(own.find(unit=>unit.id===order.unitId)!)));
  assert.deepEqual(chooseAIPlan({...state,units:[...state.units].reverse()},0),chooseAIPlan(state,0));
});

test('a complete seeded AI battle deals damage, terminates and restores every authoritative result',()=>{
  let state=createSimGame(undefined,'frontier:ELIMINATION-TACTICS'),damage=0,defeats=0,exchanges=0;
  while(state.winner===null){
    const plans:[TeamPlan,TeamPlan]=[choosePracticePlan(state,0),choosePracticePlan(state,1)];
    state=resolveRound(state,plans);exchanges++;
    damage+=state.lastResolution.filter(event=>event.kind==='damage').reduce((sum,event)=>sum+(event.amount??0),0);
    defeats+=state.lastResolution.filter(event=>event.kind==='defeat').length;
    assert.deepEqual(restoreSimState(state),state);assert.deepEqual(state.scores,[0,0]);
    assert.ok(exchanges<=MAX_ROUNDS);
  }
  assert.ok(damage>0,'opponents must engage rather than camp on springs');
  assert.ok(defeats>0,'the combat policy must create real elimination pressure');
});
