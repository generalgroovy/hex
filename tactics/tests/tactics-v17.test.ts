import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,restoreSimState,validatePlan,eliminationWinner,areAllies,activeSeats,chooseAIPlan,legalMoves,getSpell,type SimState,type TeamPlan,type Player,type PlayerCount} from '../lib/tactics-v17.ts';
import {createSimGame as oldGame,restoreSimState as oldRestore} from '../lib/tactics-v16.ts';
const empty=():TeamPlan=>({orders:[]});
const allEmpty=(n:number)=>Array.from({length:n},empty);
const flat=(count:PlayerCount,mode:'free-for-all'|'teams'='free-for-all')=>{const state=createSimGame({playerCount:count,mode});state.cells=state.cells.map(({q,r})=>({q,r,well:false,terrain:'plain',height:0,biome:'plain'}));return state;};
const kill=(unit:SimState['units'][number])=>{unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;};
const canon=(state:SimState)=>({...state,units:[...state.units].sort((a,b)=>a.id.localeCompare(b.id))});
test('2–6 companies retain fixed budgets, unique corners and exact replayable saves after a common exchange',()=>{
  for(const playerCount of [2,3,4,5,6] as PlayerCount[]){
    const state=createSimGame({playerCount}),before=JSON.stringify(state);assert.equal(state.units.length,playerCount*3);
    for(const unit of state.units){assert.equal(Object.values(unit.affinities).reduce((a,b)=>a+(b??0),0),5);assert.equal(unit.loadout.length,4);}
    assert.deepEqual(restoreSimState(state),state);const next=resolveRound(state,allEmpty(playerCount));
    assert.equal(next.round,2);assert.equal(next.version,2);assert.equal(next.lastResolution.filter(e=>e.kind==='guard').length,playerCount*3);assert.deepEqual(restoreSimState(next),next);assert.equal(JSON.stringify(state),before);
    assert.throws(()=>resolveRound(state,allEmpty(playerCount-1)));
  }
  assert.equal(oldRestore(oldGame()).rulesVersion,16);assert.throws(()=>restoreSimState(oldGame()));assert.throws(()=>oldRestore(createSimGame()));
});
test('orders stay private to their seat, including allied seats, while eliminated seats need no living orders',()=>{
  const state=createSimGame({playerCount:6,mode:'teams'});assert.equal(areAllies(state,0,2),true);assert.equal(areAllies(state,0,1),false);
  assert.throws(()=>validatePlan(state,0,{orders:[{unitId:state.units[6].id,guard:true}]}));assert.throws(()=>validatePlan(state,6 as Player,empty()));
  state.units.filter(u=>u.owner===2).forEach(kill);assert.deepEqual(validatePlan(state,2,empty()),empty());assert.deepEqual(activeSeats(state),[0,1,3,4,5]);
  assert.equal(resolveRound(state,allEmpty(6)).round,2);
});
test('three competing movement requests all bounce in the same exchange with no first-seat advantage',()=>{
  const state=flat(3),positions=[{q:-1,r:0},{q:1,r:0},{q:0,r:-1}],plans=allEmpty(3);
  for(let seat=0;seat<3;seat++){const unit=state.units[seat*3];Object.assign(unit,positions[seat]);plans[seat]={orders:[{unitId:unit.id,move:{q:0,r:0}}]};}
  const next=resolveRound(state,plans);assert.equal(next.lastResolution.filter(e=>e.kind==='bounce').length,3);
  for(let seat=0;seat<3;seat++)assert.deepEqual({q:next.units[seat*3].q,r:next.units[seat*3].r},positions[seat]);
  assert.deepEqual(canon(resolveRound({...state,units:[...state.units].reverse()},plans)),canon(next));
});
test('six actual companies release into one shared six-element midflight clash',()=>{
  const heroes=['red_baron','oh_tipi','treevor_mason','grace_reava','haara','s_wayne'],spells=['ember','water_jet','stone','gust','radiant_bolt','wither_bolt'];
  const rosters=heroes.map(hero=>[hero,...['oll_i','fluup','nico_lai'].filter(id=>id!==hero).slice(0,2)]);
  const state=createSimGame({playerCount:6,rosters});state.cells=state.cells.map(({q,r})=>({q,r,well:false,terrain:'plain',height:0,biome:'plain'}));
  const positions=[{q:-2,r:0},{q:2,r:0},{q:0,r:-2},{q:0,r:2},{q:-2,r:2},{q:2,r:-2}];
  const plans=allEmpty(6);for(let seat=0;seat<6;seat++){const unit=state.units[seat*3];Object.assign(unit,positions[seat]);plans[seat]={orders:[{unitId:unit.id,spellId:spells[seat],cast:{q:-unit.q,r:-unit.r}}]};}
  const next=resolveRound(state,plans),clashes=next.lastResolution.filter(e=>e.kind==='clash');assert.equal(clashes.length,1);assert.equal(clashes[0].participants?.length,6);assert.equal(clashes[0].elements?.length,6);assert.equal(clashes[0].flightFraction,.5);assert.equal(clashes[0].radius,2);assert.equal(next.lastResolution.filter(e=>e.kind==='cast').length,6);
  assert.deepEqual(canon(resolveRound({...state,units:[...state.units].reverse()},plans)),canon(next));
});
test('renumbering all six seats cannot change a simultaneous combat outcome',()=>{
  const state=flat(6),positions=[{q:-2,r:0},{q:2,r:0},{q:0,r:-2},{q:0,r:2},{q:-2,r:2},{q:2,r:-2}],plans=allEmpty(6);
  for(let seat=0;seat<6;seat++){const unit=state.units[seat*3];Object.assign(unit,positions[seat]);plans[seat]={orders:[{unitId:unit.id,spellId:seat%2?'water_jet':'ember',cast:{q:-unit.q,r:-unit.r}}]};}
  const expected=resolveRound(state,plans),permutation=[5,2,0,4,1,3],permuted=structuredClone(state),renamed=new Map<string,string>();
  for(const unit of permuted.units){const old=unit.id;unit.owner=permutation[unit.owner] as Player;unit.id=`${unit.owner}-${unit.championId}`;renamed.set(old,unit.id);}
  const shuffled=allEmpty(6);plans.forEach((plan,oldSeat)=>{shuffled[permutation[oldSeat]]={orders:plan.orders.map(order=>({...order,unitId:renamed.get(order.unitId)!}))};});
  const result=resolveRound(permuted,shuffled);assert.deepEqual(result.cells,expected.cells);assert.equal(result.winner,expected.winner);
  for(const before of expected.units){const after=result.units.find(unit=>unit.id===renamed.get(before.id))!;assert.deepEqual({...after,id:before.id,owner:before.owner},before);}
  const clash=result.lastResolution.find(e=>e.kind==='clash')!,original=expected.lastResolution.find(e=>e.kind==='clash')!;assert.deepEqual(clash.elements,original.elements);assert.deepEqual(clash.meeting,original.meeting);assert.equal(clash.flightFraction,original.flightFraction);
});
test('a six-company clash survives strict replay validation; changed collision data is rejected',()=>{
  const state=createSimGame({playerCount:6}),positions=[{q:-1,r:0},{q:1,r:0},{q:0,r:-1},{q:0,r:1},{q:-1,r:1},{q:1,r:-1}],plans=allEmpty(6);
  for(let seat=0;seat<6;seat++){const unit=state.units[seat*3];Object.assign(unit,positions[seat]);plans[seat]={orders:[{unitId:unit.id,spellId:seat%2?'water_jet':'ember',cast:{q:-unit.q,r:-unit.r}}]};}
  assert.deepEqual(restoreSimState(state),state);const next=resolveRound(state,plans);assert.deepEqual(restoreSimState(next),next);
  for(const field of ['flightFraction','radius','participants'] as const){const changed=structuredClone(next),clash=changed.lastResolution.find(e=>e.kind==='clash')!;if(field==='participants')clash.participants=clash.participants!.slice(1);else if(field==='radius')clash.radius=1;else clash.flightFraction=.4;assert.throws(()=>restoreSimState(changed));}
});
test('team healing and enemy-only harm recognize another player on the same team',()=>{
  const state=createSimGame({playerCount:4,mode:'teams',rosters:Array.from({length:4},()=>['haara','oh_tipi','treevor_mason'])});
  state.cells=state.cells.map(({q,r})=>({q,r,well:false,terrain:'plain',height:0,biome:'plain'}));
  const caster=state.units[0],ally=state.units[6],enemy=state.units[3];Object.assign(caster,{q:0,r:0});Object.assign(ally,{q:1,r:0,hp:3});Object.assign(enemy,{q:-1,r:0});
  const heal=resolveRound(state,[{orders:[{unitId:caster.id,spellId:'mend',cast:{q:1,r:0}}]},empty(),empty(),empty()]);assert.ok(heal.units.find(u=>u.id===ally.id)!.hp>3);
  const friendly=resolveRound(state,[{orders:[{unitId:caster.id,spellId:'radiant_bolt',cast:{q:1,r:0}}]},empty(),empty(),empty()]);assert.ok(friendly.units.find(u=>u.id===ally.id)!.hp>3);assert.ok(!friendly.lastResolution.some(event=>event.kind==='damage'&&event.unitId===ally.id));
  const hostile=resolveRound(state,[{orders:[{unitId:caster.id,spellId:'radiant_bolt',cast:{q:-1,r:0}}]},empty(),empty(),empty()]);assert.ok(hostile.units.find(u=>u.id===enemy.id)!.hp<8);
});
test('last surviving team wins only after the shared result; a complete wipe and round limit draw',()=>{
  const state=createSimGame({playerCount:6,mode:'teams'});state.units.filter(u=>u.owner%2===1).forEach(kill);assert.equal(eliminationWinner(state.units,1,state.teams),0);
  assert.equal(resolveRound(state,allEmpty(6)).winner,0);
  state.units.forEach(kill);assert.equal(eliminationWinner(state.units,1,state.teams),'draw');
  const final=createSimGame({playerCount:5});final.round=20;final.version=20;const draw=resolveRound(final,allEmpty(5));assert.equal(draw.winner,'draw');assert.deepEqual(restoreSimState(draw),draw);
  const ffa=createSimGame({playerCount:6});ffa.units.filter(u=>u.owner!==5).forEach(kill);assert.equal(eliminationWinner(ffa.units,1,ffa.teams),5);
});
test('a simultaneous burn wipe cannot award victory to whichever seat is processed first',()=>{
  const state=flat(3);for(const unit of state.units){unit.hp=1;unit.statuses.burn={turns:1,power:1};}
  const result=resolveRound(state,allEmpty(3));assert.equal(result.winner,'draw');assert.equal(result.units.filter(u=>u.hp===0).length,9);assert.equal(result.lastResolution.filter(e=>e.kind==='defeat').length,9);
});
test('restore rejects forged seats, teams, geometry, budgets, signatures, victories and replay owners',()=>{
  const baseline=resolveRound(createSimGame({playerCount:6}),allEmpty(6));
  const invalid:( (s:SimState)=>void )[]=[s=>{s.playerCount=5;},s=>{s.teams[1]=0;},s=>{s.boardRadius=9;},s=>{s.units[0].owner=5;},s=>{s.units[0].affinities.water=6;},s=>{s.units[0].hp=50;},s=>{s.cells[0].height=s.cells[0].height?0:1;},s=>{s.cells[0]={...s.cells[1]};},s=>{s.learnedSignatures[0]=['signature_oh_tipi'];},s=>{s.winner=5;},s=>{s.lastResolution[0].owner=6 as Player;}];
  for(const mutate of invalid){const state=structuredClone(baseline);mutate(state);assert.throws(()=>restoreSimState(state));}
  const wrongOwner=structuredClone(baseline);wrongOwner.lastResolution[0].owner=5;assert.throws(()=>restoreSimState(wrongOwner));
  assert.throws(()=>createSimGame({playerCount:5,mode:'teams'}));assert.throws(()=>createSimGame({playerCount:7 as PlayerCount}));
});
test('every seat can form a legal public-state bot plan, including allied company support',()=>{
  const state=createSimGame({playerCount:6,mode:'teams'});
  for(const seat of [0,1,2,3,4,5] as Player[]){const plan=chooseAIPlan(state,seat);assert.deepEqual(validatePlan(state,seat,plan),plan);assert.equal(plan.orders.length,3);assert.ok(plan.orders.some(order=>order.move));}
});
