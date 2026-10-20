import test from 'node:test';
import assert from 'node:assert/strict';
import {combatOutlook} from '../lib/combat-outlook-v14.ts';
import {createSimGame,resolveRound,type SimState,type TeamPlan} from '../lib/tactics-v14.ts';

const oh='0-oh_tipi',wa='0-wa_bidi',tree='0-treevor_mason',enemy='1-oh_tipi';
const target={q:0,r:0};
const plan=(...orders:TeamPlan['orders']):TeamPlan=>({orders});
function arena():SimState{
 const state=createSimGame();
 state.cells=state.cells.map(({q,r})=>({q,r,biome:'plain',terrain:'plain',height:0,well:false}));
 Object.assign(state.units.find(u=>u.id===oh)!,{q:-2,r:0});
 Object.assign(state.units.find(u=>u.id===wa)!,{q:-2,r:1});
 Object.assign(state.units.find(u=>u.id===tree)!,{q:-2,r:2});
 state.units.find(u=>u.id===tree)!.loadout[0]='ember';
 Object.assign(state.units.find(u=>u.id===enemy)!,target);
 return state;
}
const damage=(state:SimState,id=enemy)=>state.lastResolution.filter(e=>e.kind==='damage'&&e.unitId===id).reduce((sum,e)=>sum+(e.amount??0),0);

test('known allied volley crosses cover, Ward and Guard once, matching the resolver',()=>{
 const state=arena(),victim=state.units.find(u=>u.id===enemy)!;
 victim.statuses.ward={turns:2,power:2};
 Object.assign(state.cells.find(c=>c.q===0&&c.r===0)!,{biome:'forest'});
 const orders=plan({unitId:wa,spellId:'ember',cast:target},{unitId:tree,spellId:'ember',cast:target});
 const outlook=combatOutlook(state,0,orders,tree,'ember',target).find(v=>v.id===enemy)!;
 assert.ok(outlook);
 const guarded=resolveRound(state,[orders,plan()]);
 assert.equal(outlook.guardedDamage,damage(guarded));
 assert.equal(outlook.damage,outlook.guardedDamage+1,'Guard reduces the aggregate, rather than every hit');
 const unguarded=resolveRound(state,[orders,plan({unitId:enemy,spellId:'cleansing_tide',cast:{q:2,r:0}})]);
 assert.equal(outlook.damage,damage(unguarded));
});

test('adding Water can reduce the allied volley through Steam; negative marginal damage is retained',()=>{
 const state=arena();
 for(const id of [wa,tree])state.units.find(u=>u.id===id)!.affinities.fire=6;
 const previous=plan({unitId:wa,spellId:'ember',cast:target},{unitId:tree,spellId:'ember',cast:target});
 const combined=plan(...previous.orders,{unitId:oh,spellId:'water_jet',cast:target});
 const result=combatOutlook(state,0,previous,oh,'water_jet',target).find(v=>v.id===enemy)!;
 assert.equal(result.field,'steam');
 assert.ok(result.addedDamage<0,'Steam can protect the intended victim more than this extra hit hurts them');
 const before=resolveRound(state,[previous,plan()]),after=resolveRound(state,[combined,plan()]);
 assert.equal(result.guardedDamage,damage(after));
 assert.equal(result.guardedAddedDamage,damage(after)-damage(before));
});

test('fresh marks never enable a same-volley bonus; existing marks do',()=>{
 const state=arena(),caster=state.units.find(u=>u.id===tree)!;
 state.units.find(u=>u.id===oh)!.affinities.water=6;
 caster.affinities.fire=4;caster.loadout[0]='fire_lance';
 const orders=plan({unitId:oh,spellId:'water_jet',cast:target},{unitId:tree,spellId:'fire_lance',cast:target});
 const dry=combatOutlook(state,0,orders,tree,'fire_lance',target).find(v=>v.id===enemy)!;
 assert.equal(dry.guardedDamage,damage(resolveRound(state,[orders,plan()])));
 state.units.find(u=>u.id===enemy)!.statuses.wet={turns:1,power:1};
 const wet=combatOutlook(state,0,orders,tree,'fire_lance',target).find(v=>v.id===enemy)!;
 assert.equal(wet.guardedDamage,damage(resolveRound(state,[orders,plan()])));
 assert.ok(wet.guardedDamage>dry.guardedDamage,'only an existing Wet mark improves Lightning Lance');
});

test('outlook uses allied landings, accounts for friendly fire and never reads rival orders',()=>{
 const state=arena();
 const own=plan({unitId:oh,move:target,guard:true},{unitId:wa,spellId:'ember',cast:target});
 Object.assign(state.units.find(u=>u.id===enemy)!,{q:2,r:0});
 const before=structuredClone({state,own});
 const expected=combatOutlook(state,0,own,wa,'ember',target);
 const mixed=plan(...own.orders,{unitId:enemy,spellId:'water_jet',cast:target});
 assert.deepEqual(combatOutlook(state,0,mixed,wa,'ember',target),expected);
 assert.deepEqual({state,own},before);
 assert.equal(expected.length,1);assert.equal(expected[0].id,oh);assert.equal(expected[0].ally,true);
 assert.equal(expected[0].damage,damage(resolveRound(state,[own,plan()]),oh));
 assert.deepEqual(combatOutlook(state,0,own,enemy,'water_jet',target),[]);
 assert.deepEqual(combatOutlook(state,0,own,wa,'inferno',target),[]);
});

test('stationary rival occupancy propagates a bounce through allied followers before predicting casts',()=>{
 const state=arena(),far={q:4,r:0};
 Object.assign(state.units.find(u=>u.id==='1-wa_bidi')!,far);
 const orders=plan({unitId:oh,move:target,spellId:'water_jet',cast:far});
 const resolved=resolveRound(state,[orders,plan()]);
 assert.ok(resolved.lastResolution.some(e=>e.kind==='fizzle'&&e.unitId===oh));
 assert.deepEqual(combatOutlook(state,0,orders,oh,'water_jet',far),[],
   'a stationary rival prevents the landing that this cast needs');
 Object.assign(state.units.find(u=>u.id===wa)!,{q:-4,r:0});
 Object.assign(state.units.find(u=>u.id==='1-wa_bidi')!,{q:2,r:0});
 const following=plan({unitId:oh,move:target,guard:true},{unitId:wa,move:{q:-2,r:0},spellId:'ember',cast:{q:2,r:0}});
 assert.ok(resolveRound(state,[following,plan()]).lastResolution.some(e=>e.kind==='fizzle'&&e.unitId===wa));
 assert.deepEqual(combatOutlook(state,0,following,wa,'ember',{q:2,r:0}),[],
   'a follower cannot enter the ally’s tile after the front move bounces');
});
