import test from 'node:test';
import assert from 'node:assert/strict';
import {findProjectileClashes,findLegacyProjectileClashes,PROJECTILE_RADIUS,type Projectile} from '../lib/projectile-interception-v20.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {createTowerBattle,resolveRound,restoreSimState,legalCasts,plannedProjectileClashes,validatePlan,isCellSolid,type TowerActor,type TeamPlan} from '../lib/tactics-v22.ts';
import {createCampaignGame,readCampaignProfile,restoreCampaignGame} from '../lib/story-v20.ts';
import {resolveRound as resolveStory} from '../lib/tactics-v20.ts';
import {createSharedTowerBattle} from '../lib/tower-shared-battle-v23.ts';
import {createTowerRun,chooseTowerRoom,towerRoomChoices} from '../lib/tower-v23.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import {projectedVolley} from '../lib/planned-volley-v20.ts';
import type {Element,Point} from '../lib/game.ts';

const board:Point[]=[];for(let q=-5;q<=5;q++)for(let r=-5;r<=5;r++)if(Math.max(Math.abs(q),Math.abs(r),Math.abs(q+r))<=5)board.push({q,r});
const shot=(unitId:string,from:Point,to:Point,element:Element='fire'):Projectile=>({unitId,from,to,element});
const fire=shot('fire',{q:-2,r:0},{q:2,r:0});
const water=shot('water',{q:0,r:-2},{q:1,r:2},'water');
const empty=():TeamPlan=>({orders:[]});
const actor=(id:string,championId:string):TowerActor=>{const build=canonicalBuild(championId);return {id,championId,displayName:build.name,affinities:build.affinities,loadout:build.loadout,hp:8};};

test('overlapping water and fire cores meet even when their centres never coincide',()=>{
 assert.equal(PROJECTILE_RADIUS,.25);
 assert.deepEqual(findLegacyProjectileClashes([fire,water],board),[],'Reproduces the old zero-width miss');
 const result=findProjectileClashes([fire,water],board);assert.equal(result.length,1);
 assert.deepEqual(result[0].participants,['fire','water']);assert.deepEqual(result[0].elements,['fire','water']);
 assert.equal(result[0].flightFraction,7/13);assert.equal(result[0].radius,1);
 assert.deepEqual(findProjectileClashes([water,fire],[...board].reverse()),result);
 assert.equal(result[0].q,0);assert.equal(result[0].r,0);
});

test('visible tails, neighbouring parallel lanes and crossings at different times do not collide',()=>{
 assert.deepEqual(findProjectileClashes([fire,shot('late',{q:0,r:-1},{q:0,r:3},'water')],board),[]);
 assert.deepEqual(findProjectileClashes([fire,shot('parallel',{q:-2,r:1},{q:2,r:1},'water')],board),[]);
 assert.deepEqual(findProjectileClashes([fire,shot('far',{q:3,r:-2},{q:3,r:2},'water')],board),[]);
});

test('shared aims remain normal impacts, and exact multi-element meetings keep their timing',()=>{
 assert.deepEqual(findProjectileClashes([shot('a',{q:-2,r:0},{q:0,r:0}),shot('b',{q:0,r:-2},{q:0,r:0},'water')],board),[]);
 const directions:Point[]=[{q:2,r:0},{q:0,r:2},{q:-2,r:2},{q:-2,r:0},{q:0,r:-2},{q:2,r:-2}];
 const elements:Element[]=['fire','water','earth','air','light','dark'];
 const six=directions.map((from,index)=>shot(String(index),from,{q:-from.q,r:-from.r},elements[index]));
 const [clash]=findProjectileClashes(six,board);assert.equal(clash.flightFraction,.5);assert.deepEqual(clash.meeting,{q:0,r:0});assert.equal(clash.radius,2);assert.deepEqual(clash.elements,elements);
 assert.deepEqual(findProjectileClashes([...six].reverse(),board),[clash]);
});

test('the first contact consumes a cast once, while unrelated later shots survive',()=>{
 const casts=[shot('a',{q:0,r:0},{q:4,r:0}),shot('b',{q:2,r:0},{q:-2,r:0},'water'),shot('c',{q:3,r:-3},{q:3,r:1},'earth')];
 const clashes=findProjectileClashes(casts,board);assert.equal(clashes.length,1);assert.deepEqual(clashes[0].participants,['a','b']);
 assert.equal(clashes[0].flightFraction,.25);assert.ok(!clashes[0].participants.includes('c'));
});

/** Real Tower map, real legal spells and native kits. Only fighter placement is
 * arranged to reproduce the narrow water/fire crossing. */
function crossing(){
 const state=createTowerBattle({id:'contact-proof',mapId:'CONTACT-PROOF',allies:[actor('fire','red_baron'),actor('water','oh_tipi')],enemies:[actor('foe','treevor_mason')],learnedSpells:[]});
 const [fireActor,waterActor]=state.units;
 let plan:TeamPlan|undefined;
 for(const centre of state.cells){
  const shift=(p:Point)=>({q:p.q+centre.q,r:p.r+centre.r});
  const origins=[shift(fire.from),shift(water.from)],targets=[shift(fire.to),shift(water.to)];
  if([...origins,...targets].some(point=>!state.cells.some(cell=>cell.q===point.q&&cell.r===point.r&&!isCellSolid(cell)))||origins.some(point=>state.units.some(unit=>unit.owner===1&&unit.q===point.q&&unit.r===point.r)))continue;
  Object.assign(fireActor,origins[0]);Object.assign(waterActor,origins[1]);
  if(![fireActor,waterActor].every((unit,index)=>legalCasts(state,unit.id,undefined,index?'water_jet':'ember').some(point=>point.q===targets[index].q&&point.r===targets[index].r)))continue;
  plan=validatePlan(state,0,{orders:[{unitId:fireActor.id,spellId:'ember',cast:targets[0]},{unitId:waterActor.id,spellId:'water_jet',cast:targets[1]}]});break;
 }
 assert.ok(plan,'A legal crossing exists on the generated board');return {state,plan};
}

test('real Tower casts agree with the plan, cancel original hits and save their contact exactly',()=>{
 const {state,plan}=crossing(),before=JSON.stringify(state),forecast=plannedProjectileClashes(state,plan);
 assert.equal(forecast.length,1);assert.equal(forecast[0].flightFraction,7/13);
 const next=resolveRound(state,[plan,empty()]),clash=next.lastResolution.find(event=>event.kind==='clash')!;
 assert.ok(clash);assert.equal(clash.terrain,'steam');assert.deepEqual(clash.meeting,forecast[0].meeting);assert.equal(clash.flightFraction,forecast[0].flightFraction);
 assert.equal(next.projectileModel,'volume');assert.deepEqual(restoreSimState(next),next);assert.equal(JSON.stringify(state),before);
 assert.equal(next.lastResolution.filter(event=>event.kind==='cast').length,2,'Both casters spend their normal action and Flux');
 assert.ok(!next.lastResolution.some(event=>event.kind==='push'),'Intercepted Water Jet cannot push its original target');
 assert.ok(!next.lastResolution.some(event=>event.kind==='surface'&&event.status==='burn'),'Intercepted Ember cannot apply its direct Burn');
 const forged=structuredClone(next);forged.lastResolution=forged.lastResolution.filter(event=>event.kind!=='clash');assert.throws(()=>restoreSimState(forged),/meetings/);
 const changed=structuredClone(next);changed.lastResolution.find(event=>event.kind==='clash')!.meeting!.q+=.1;assert.throws(()=>restoreSimState(changed),/meetings/);
});

test('older Tower and Story saves load, then the next exchange adopts volume collision rules',()=>{
 const tower=createTowerBattle({id:'legacy-proof',mapId:'LEGACY-PROOF',allies:[actor('hero','oh_tipi')],enemies:[actor('foe','red_baron')],learnedSpells:[]});
 delete tower.projectileModel; // A saved pre-volume encounter, not a new constructor.
 assert.equal(tower.projectileModel,undefined);assert.deepEqual(restoreSimState(tower),tower);
 const oldTowerReplay=resolveRound(tower,[empty(),empty()]);delete oldTowerReplay.projectileModel;assert.deepEqual(restoreSimState(oldTowerReplay),oldTowerReplay);
 const nextTower=resolveRound(oldTowerReplay,[empty(),empty()]);assert.equal(nextTower.projectileModel,'volume');assert.deepEqual(restoreSimState(nextTower),nextTower);
 const story=createCampaignGame(readCampaignProfile(null),'oh_tipi');delete story.projectileModel;assert.equal(story.projectileModel,undefined);assert.deepEqual(restoreCampaignGame(story),story);
 const nextStory=resolveStory(story,[empty(),empty()]);assert.equal(nextStory.projectileModel,'volume');assert.deepEqual(restoreCampaignGame(nextStory),nextStory);
 assert.throws(()=>restoreSimState({...nextTower,projectileModel:'invented'}),/projectile rules/);
});

test('a six-squad shared volley retains forecasts after more than three fighters queue orders',()=>{
 const entries=Array.from({length:6},(_,seat)=>{const run=createTowerRun('SHARED-FORECAST','steam');return {seat,run:chooseTowerRoom(run,towerRoomChoices(run)[0].id)};});
 const state=createSharedTowerBattle(entries),own=state.units.filter(unit=>unit.owner===0),unit=own[0];
 assert.equal(own.length,12);
 const target=legalCasts(state,unit.id,undefined,'water_jet')[0];assert.ok(target);
 const plan:TeamPlan={orders:own.map(actor=>actor.id===unit.id?{unitId:actor.id,spellId:'water_jet',cast:{q:target.q,r:target.r}}:{unitId:actor.id,guard:true})};
 const view={...state,rulesVersion:20} as unknown as Parameters<typeof planningForecast>[0];
 const forecast=planningForecast(view,0,plan,unit.id);assert.ok(forecast,'Allied plan size must not erase the selected spell preview');assert.ok(forecast.cells.length);assert.equal(forecast.unitId,unit.id);
});

test('the legacy Tower forecast retains point contacts while current rooms forecast volume contacts',()=>{
 const {state,plan}=crossing(),view={...state,rulesVersion:20} as unknown as Parameters<typeof planningForecast>[0];
 assert.equal(projectedVolley(view,0,plan).clashes.length,1);
 assert.equal(projectedVolley(view,0,plan,false,{legacyProjectiles:true}).clashes.length,0);
 const current=planningForecast(view,0,plan,'fire'),legacy=planningForecast(view,0,plan,'fire',undefined,undefined,{legacyProjectiles:true});
 assert.ok(current&&legacy);assert.equal(current.clashes.length,1);assert.equal(legacy.clashes.length,0);assert.notDeepEqual(current.cells,legacy.cells);
});
