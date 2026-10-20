import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,previewField,resolveRound,legalMoves,type SimState,type TeamPlan} from '../lib/tactics-v13.ts';
import {projectAlliedMovement,movementPreview,movementRisks} from '../lib/movement-preview-v13.ts';

const a='0-oh_tipi',b='0-wa_bidi',c='0-treevor_mason';
const p=(q:number,r=0)=>({q,r});
const plan=(...orders:TeamPlan['orders']):TeamPlan=>({orders});
function arena():SimState{
  const state=createSimGame();state.cells=state.cells.map(({q,r})=>({q,r,height:0,well:false,biome:'plain',terrain:'plain'}));
  [a,b,c].forEach((id,q)=>Object.assign(state.units.find(u=>u.id===id)!,p(q)));
  return state;
}
function compareResolution(state:SimState,orders:TeamPlan){
  const projected=projectAlliedMovement(state,0,orders),resolved=resolveRound(state,[orders,plan()]);
  for(const [id,entry]of projected){const actual=resolved.units.find(u=>u.id===id)!;assert.deepEqual(entry.actualPosition,p(actual.q,actual.r));}
}

test('stationary ally blocks a landing, but passing through them is allowed',()=>{
  const state=arena();Object.assign(state.units.find(u=>u.id===c)!,p(2,-2));
  const blocked=movementPreview(state,0,plan(),a,p(1))!;
  assert.equal(blocked.blocked,true);assert.match(blocked.reason!,/Wa Bidi stays/);assert.deepEqual(blocked.actualPosition,p(0));
  const through=movementPreview(state,0,plan(),a,p(2))!;
  assert.equal(through.blocked,false);assert.deepEqual(through.actualPosition,p(2));
  compareResolution(state,plan({unitId:a,move:p(1),guard:true}));
  compareResolution(state,plan({unitId:a,move:p(2),guard:true}));
});

test('duplicate destinations propagate blockage to followers',()=>{
  const state=arena(),orders=plan({unitId:a,move:p(3),guard:true},{unitId:b,move:p(3),guard:true},{unitId:c,move:p(0),guard:true});
  const result=projectAlliedMovement(state,0,orders);
  assert.ok([...result.values()].every(entry=>entry.blocked));
  assert.match(result.get(a)!.reason!,/Landing shared/);
  assert.match(result.get(c)!.reason!,/Oh Tipi stays/);
  compareResolution(state,orders);
});

test('simultaneous swaps and three-character cycles stay valid',()=>{
  const state=arena();
  for(const orders of [plan({unitId:a,move:p(1),guard:true},{unitId:b,move:p(0),guard:true}),plan({unitId:a,move:p(1),guard:true},{unitId:b,move:p(2),guard:true},{unitId:c,move:p(0),guard:true})]){
    assert.ok([...projectAlliedMovement(state,0,orders).values()].every(entry=>!entry.blocked));
    compareResolution(state,orders);
  }
});

test('rival landings and dependent followers are uncertain, never claimed as guaranteed failures',()=>{
  const state=arena(),rival=state.units.find(u=>u.owner===1)!;Object.assign(rival,p(3));
  const orders=plan({unitId:a,move:p(3),guard:true},{unitId:b,move:p(0),guard:true});
  const result=projectAlliedMovement(state,0,orders);
  assert.equal(result.get(a)!.blocked,false);assert.equal(result.get(a)!.contested,true);
  assert.equal(result.get(b)!.blocked,false);assert.equal(result.get(b)!.contested,true);
  assert.match(result.get(b)!.contestedReason!,/Depends on Oh Tipi/);
  const hidden=plan(...orders.orders,{unitId:rival.id,move:p(4),guard:true});
  assert.deepEqual(projectAlliedMovement(state,0,hidden),result);
});

test('queued routes persist; candidate replacement is immutable and risk map agrees',()=>{
  const state=arena(),orders=plan({unitId:a,move:p(0,-2),guard:true}),snapshot=structuredClone({state,orders});
  const queued=movementPreview(state,0,orders,a)!;
  assert.deepEqual(queued.target,p(0,-2));assert.equal(queued.effort,2);assert.equal(queued.budget,4);
  const candidate=movementPreview(state,0,orders,a,p(1))!;
  assert.equal(candidate.blocked,true);
  const risks=movementRisks(state,0,orders,a,legalMoves(state,a));
  assert.equal(risks.get('1,0')!.blocked,true);assert.equal(risks.get('0,-2')!.blocked,false);
  assert.deepEqual({state,orders},snapshot);
});

test('ice route reports the full slide and one effort, including a blocked endpoint',()=>{
  const state=arena();Object.assign(state.units.find(u=>u.id===b)!,p(3));Object.assign(state.units.find(u=>u.id===c)!,p(2,-2));
  for(let q=1;q<=3;q++){const cell=state.cells.find(cell=>cell.q===q&&cell.r===0)!;Object.assign(cell,previewField(cell,['water'],true));}
  const route=movementPreview(state,0,plan(),a,p(3))!;
  assert.equal(route.slide,true);assert.equal(route.effort,1);assert.deepEqual(route.route,[p(1),p(2),p(3)]);
  assert.equal(route.blocked,true);assert.deepEqual(route.landing,p(0));
  compareResolution(state,plan({unitId:a,move:p(3),guard:true}));
});

test('unreachable, rooted and non-owned targets fail safely while Hold stays clear',()=>{
  const state=arena();
  assert.equal(movementPreview(state,0,plan(),a,p(9))!.blocked,true);
  state.units.find(u=>u.id===a)!.statuses.rooted={turns:1,power:1};
  const rooted=movementPreview(state,0,plan(),a,p(0,-1))!;
  assert.equal(rooted.blocked,true);assert.equal(rooted.budget,0);assert.equal(rooted.effort,null);
  const hold=movementPreview(state,0,plan(),a)!;
  assert.equal(hold.hasMove,false);assert.equal(hold.blocked,false);assert.equal(hold.effort,0);
  assert.equal(movementPreview(state,0,plan(),'1-oh_tipi'),null);
});
