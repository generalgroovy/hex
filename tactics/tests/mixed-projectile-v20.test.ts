import test from 'node:test';
import assert from 'node:assert/strict';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {CREATURES} from '../lib/campaign-creatures-v20.ts';
import {getCreatureSpell,spellElements} from '../lib/spells-v20.ts';
import {readCampaignProfile,validateCampaignProfile,createCampaignGame,restoreCampaignGame} from '../lib/story-v20.ts';
import {isCellSolid,legalCasts,validatePlan,resolveRound,plannedProjectileClashes,cellElements,combinationFor,type TeamPlan} from '../lib/tactics-v20.ts';
import {projectedVolley} from '../lib/planned-volley-v20.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import {findProjectileClashes} from '../lib/projectile-interception-v20.ts';

const sorted=(values:readonly string[])=>[...values].sort();
function crossing(){
 const pair=['Hush','Crackle'].map(name=>CREATURES.find(creature=>creature.name===name)!);
 const profile=validateCampaignProfile({...readCampaignProfile(null),defeated:CHAMPIONS.slice(0,20).map(hero=>hero.id),companions:pair.map(creature=>creature.id)}),state=createCampaignGame(profile,'oh_tipi');
 const actors=pair.map(creature=>state.units.find(unit=>unit.owner===0&&unit.creatureId===creature.id)!);
 // Keep the actual procedural map. Find an open two-cell crossing rather than
 // replacing terrain with a synthetic plain or bypassing cast validation.
 let plan:TeamPlan|undefined;
 for(const centre of [...state.cells].sort((a,b)=>Math.abs(a.q)+Math.abs(a.r)-Math.abs(b.q)-Math.abs(b.r))){
  const points=[{q:centre.q-1,r:centre.r},{q:centre.q+1,r:centre.r}];
  if(points.some(point=>!state.cells.some(cell=>cell.q===point.q&&cell.r===point.r&&!isCellSolid(cell))||state.units.some(unit=>!actors.includes(unit)&&unit.q===point.q&&unit.r===point.r)))continue;
  actors.forEach((actor,index)=>Object.assign(actor,points[index]));
  if(actors.every((actor,index)=>legalCasts(state,actor.id,undefined,actor.loadout[0]).some(point=>point.q===points[1-index].q&&point.r===points[1-index].r))){plan=validatePlan(state,0,{orders:actors.map((actor,index)=>({unitId:actor.id,spellId:actor.loadout[0],cast:points[1-index]}))});break;}
 }
 assert.ok(plan,'Real board has a legal crossing for both native spells');assert.deepEqual(restoreCampaignGame(state),state);return {state,actors,plan};
}

test('mixed native projectiles preserve all ingredients through planning, flight and actual resolution',()=>{
 const {state,actors,plan}=crossing(),expected=['fire','water','air'];
 const geometry=plannedProjectileClashes(state,plan),preview=projectedVolley(state,0,plan),forecast=planningForecast(state,0,plan,actors[0].id);
 assert.equal(geometry.length,1);assert.equal(preview.clashes.length,1);assert.equal(geometry[0].flightFraction,.5);assert.equal(geometry[0].radius,1);assert.deepEqual(sorted(geometry[0].elements),sorted(expected));assert.deepEqual(sorted(preview.clashes[0].elements),sorted(expected));assert.equal(preview.activeCasts.length,0);assert.ok(forecast);assert.equal(forecast.cells.length,7);
 const result=resolveRound(state,[plan,{orders:[]}]),clash=result.lastResolution.find(event=>event.kind==='clash')!;
 assert.ok(clash);assert.deepEqual(sorted(clash.elements!),sorted(expected));assert.deepEqual(sorted(clash.participants!),sorted(actors.map(actor=>actor.id)));assert.equal(clash.terrain,combinationFor(expected as never)!.id);
 for(const predicted of forecast.cells){
  const reaction=result.lastResolution.find(event=>event.kind==='reaction'&&event.q===predicted.q&&event.r===predicted.r);assert.ok(reaction);assert.deepEqual(sorted(reaction.elements!),sorted(predicted.elements));assert.equal(reaction.terrain,predicted.field);
  if(!combinationFor(predicted.elements)!.mechanics.consume){const actual=result.cells.find(cell=>cell.q===predicted.q&&cell.r===predicted.r)!;assert.deepEqual(sorted(cellElements(actual)),sorted(predicted.elements));}
 }
 assert.ok(!result.lastResolution.some(event=>event.status==='blind'),'Intercepted Kettle Breath must not apply its original direct Blind');assert.deepEqual(restoreCampaignGame(result),result);
});

test('an unopposed mixed technique creates every ingredient across its real forecast footprint',()=>{
 const {state,actors}=crossing(),actor=actors[0],target=actors[1],plan=validatePlan(state,0,{orders:[{unitId:actor.id,spellId:actor.loadout[0],cast:{q:target.q,r:target.r}}]}),forecast=planningForecast(state,0,plan,actor.id);
 assert.ok(forecast);assert.equal(forecast.clashes.length,0);const result=resolveRound(state,[plan,{orders:[]}]);assert.equal(result.lastResolution.filter(event=>event.kind==='clash').length,0);
 for(const predicted of forecast.cells){const reaction=result.lastResolution.find(event=>event.kind==='reaction'&&event.q===predicted.q&&event.r===predicted.r);assert.ok(reaction);assert.deepEqual(sorted(reaction.elements!),sorted(predicted.elements));assert.ok(predicted.elements.includes('fire'));assert.ok(predicted.elements.includes('water'));}
 assert.deepEqual(restoreCampaignGame(result),result);
});

test('same-primary projectiles still combine secondary ingredients independently of input order',()=>{
 const techniques=CREATURES.filter(creature=>creature.elements.length>1).map(creature=>getCreatureSpell(creature.id));
 const left=techniques.find(spell=>spell.element==='fire')!,right=techniques.find(spell=>spell.element===left.element&&spell.id!==left.id&&spellElements(spell).some(element=>!spellElements(left).includes(element)))!;
 assert.ok(left&&right);const projectiles=[{unitId:'a',from:{q:-2,r:0},to:{q:2,r:0},element:left.element,elements:spellElements(left)},{unitId:'b',from:{q:2,r:0},to:{q:-2,r:0},element:right.element,elements:spellElements(right)}];
 const expected=sorted([...new Set([...spellElements(left),...spellElements(right)])]),cells=Array.from({length:7},(_,index)=>({q:index-3,r:0}));
 const forward=findProjectileClashes(projectiles,cells),reverse=findProjectileClashes([...projectiles].reverse(),cells);assert.deepEqual(forward,reverse);assert.equal(forward.length,1);assert.deepEqual(sorted(forward[0].elements),expected);assert.ok(expected.length>=3);
});
