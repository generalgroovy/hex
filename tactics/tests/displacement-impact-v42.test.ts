import test from 'node:test';
import assert from 'node:assert/strict';
import {towerChampion} from '../lib/tower-v23.ts';
import {createTowerBattle,resolveRound,validatePlan,previewField,type SimState,type TeamPlan} from '../lib/tactics-v22.ts';
import {resolveRound as resolveStory,type SimState as ViewState} from '../lib/tactics-v20.ts';
import {targetImpactPreview} from '../lib/target-impact-v41.ts';
import {knownDisplacementBranch,knownForceAt} from '../lib/displacement-impact-v42.ts';
import {effectiveSpell,getSpell} from '../lib/spells-v20.ts';
const at=({q,r}:{q:number;r:number})=>({q,r});
const same=(a:{q:number;r:number},b:{q:number;r:number})=>a.q===b.q&&a.r===b.r;
const view=(state:SimState)=>({...state,rulesVersion:20}) as unknown as ViewState;
function fixture(){
 const air={...towerChampion('wa_bidi','air'),loadout:['gale','vacuum','gust','ember']};
 const state=createTowerBattle({id:'force-preview',mapId:'FORCE-PREVIEW',allies:[air,towerChampion('oh_tipi','water')],enemies:[towerChampion('treevor_mason','foe')],learnedSpells:[]});
 delete state.spellModel; // Locked legacy fixture; focused areas have their own parity suite.
 for(const cell of state.cells){Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false});delete cell.ttl;delete cell.elements;delete cell.reactions;delete cell.ice;delete cell.barrier;}
 const [caster,friend,foe]=state.units;
 Object.assign(caster,{q:-1,r:0});Object.assign(friend,{q:-1,r:2});Object.assign(foe,{q:1,r:0});
 return {state,caster,friend,foe};
}
function castPlan(state:SimState,spellId='gale'):TeamPlan{return validatePlan(state,0,{orders:[{unitId:'air',spellId,cast:at(state.units.find(unit=>unit.id==='foe')!)}]});}
function rivalPlan(guard:boolean):TeamPlan{return guard?{orders:[]}:{orders:[{unitId:'foe',spellId:'stone',cast:{q:3,r:-2}}]};}
function compare(state:SimState,plan:TeamPlan){
 const preview=targetImpactPreview(view(state),0,plan,'air')!.targets.find(target=>target.id==='foe')!.displacement!;
 const before=JSON.stringify(state);
 for(const guarded of [false,true]){
  const expected=guarded?preview.withGuard:preview.withoutGuard;
  for(const resolve of [(plans:TeamPlan[])=>resolveRound(state,plans),(plans:TeamPlan[])=>resolveStory(view(state),plans)]){
   const actual=resolve([plan,rivalPlan(guarded)]),unit=actual.units.find(candidate=>candidate.id==='foe')!;
   assert.deepEqual(at(unit),expected.landing,guarded?'Guard landing':'Casting landing');
   const impact=actual.lastResolution.some(event=>event.unitId==='foe'&&event.kind==='surface'&&event.amount===1&&event.text.includes('solid terrain'));
   assert.equal(impact,expected.impact);
   for(const status of expected.statuses)assert.ok(Object.keys(unit.statuses).some(id=>id.toLowerCase()===status.toLowerCase()),`${status} is actually applied`);
  }
 }
 assert.equal(JSON.stringify(state),before,'Projection and resolvers preserve input');
 return preview;
}

test('wall impact and Guard alternatives agree with both active resolvers',()=>{
 const {state}=fixture();Object.assign(state.cells.find(cell=>same(cell,{q:3,r:0}))!,{biome:'ruins'});
 const preview=compare(state,castPlan(state));
 assert.equal(preview.withoutGuard.impact,true);assert.equal(preview.withoutGuard.environmentalDamage,1);
 assert.ok(preview.withoutGuard.statuses.includes('Concussed'));
 assert.equal(preview.withGuard.impact,false);assert.equal(preview.withGuard.environmentalDamage,0);
});

test('a stationary fighter blocks a force landing without invented collision damage',()=>{
 const {state,friend}=fixture();Object.assign(friend,{q:2,r:0});
 const preview=compare(state,castPlan(state));
 for(const branch of [preview.withoutGuard,preview.withGuard]){
  assert.deepEqual(branch.landing,{q:1,r:0});assert.deepEqual(branch.blockedBy,['Oh Tipi']);
  assert.equal(branch.impact,false);assert.equal(branch.environmentalDamage,0);
 }
});

test('Anchored prevents force; Resolve prevents impact control but not physical impact damage',()=>{
 const {state,foe}=fixture();Object.assign(state.cells.find(cell=>same(cell,{q:3,r:0}))!,{biome:'ruins'});
 foe.statuses.anchored={turns:1,power:1};let preview=compare(state,castPlan(state));
 assert.equal(preview.anchored,true);assert.equal(preview.withoutGuard.path.length,0);assert.equal(preview.withoutGuard.impact,false);
 delete foe.statuses.anchored;foe.statuses.resolve={turns:1,power:1};preview=compare(state,castPlan(state));
 assert.equal(preview.withoutGuard.impact,true);assert.equal(preview.withoutGuard.environmentalDamage,1);assert.ok(!preview.withoutGuard.statuses.includes('Concussed'));
});

test('Ice slides end on the final icy hex; crossed fighters do not block the slide',()=>{
 const {state,friend}=fixture();Object.assign(friend,{q:3,r:0});
 for(const q of [2,3,4]){const cell=state.cells.find(cell=>same(cell,{q,r:0}))!;Object.assign(cell,previewField(cell,['water'],true));}
 const preview=compare(state,castPlan(state,'gust'));
 assert.deepEqual(preview.withoutGuard.landing,{q:4,r:0});assert.equal(preview.withoutGuard.path.length,3);
 assert.deepEqual(preview.withoutGuard.blockedBy,[]);assert.deepEqual(preview.withGuard.landing,{q:1,r:0});
});

test('landing on a known hazard reports one environmental damage with contact statuses',()=>{
 const {state}=fixture();const landing=state.cells.find(cell=>same(cell,{q:3,r:0}))!;
 Object.assign(landing,previewField(landing,['fire','light','dark']));
 const preview=compare(state,castPlan(state));
 assert.equal(preview.withoutGuard.environmentalDamage,1);assert.equal(preview.withoutGuard.terrainName,'Ghostfire');
 assert.ok(preview.withoutGuard.statuses.includes('Clarity'));assert.equal(preview.withGuard.environmentalDamage,0);
});

test('combined vectors cancel, reinforce before Guard, and use burst centres',()=>{
 const {state,foe,caster}=fixture(),spell=effectiveSpell(caster.championId,'gust',caster.affinities),area=[at(foe)];
 const push={spell,origin:at(caster),target:at(foe),area};
 const pull={...push,spell:{...spell,push:-1}};
 assert.deepEqual(knownForceAt(foe,[push,pull]),{q:0,r:0});
 const branch=knownDisplacementBranch(view(state),state.cells,[push,push],new Set(['foe']));
 assert.deepEqual(branch.get('foe')!.landing,{q:2,r:0},'Two impulses overcome one Guard resistance');
 assert.deepEqual(knownForceAt({q:2,r:0},[{spell:{...getSpell('maelstrom'),push:-1},origin:{q:-5,r:0},target:{q:1,r:0},area:[{q:2,r:0}]}]),{q:-1,r:0});
});

test('two simultaneous force landings bounce fairly while swaps remain possible',()=>{
 const {state,caster,friend,foe}=fixture();Object.assign(caster,{q:-2,r:0});Object.assign(friend,{q:0,r:0});Object.assign(foe,{q:2,r:0});
 const spell={...getSpell('gust'),push:1};
 const casts=[
  {spell,origin:{q:-1,r:0},target:at(friend),area:[at(friend)]},
  {spell,origin:{q:3,r:0},target:at(foe),area:[at(foe)]},
 ];
 const both=knownDisplacementBranch(view(state),state.cells,casts,new Set());
 assert.deepEqual(both.get('water')!.landing,at(friend));assert.deepEqual(both.get('foe')!.landing,at(foe));
 assert.deepEqual(both.get('foe')!.blockedBy,['Oh Tipi']);assert.equal(both.get('foe')!.impact,false);
 Object.assign(foe,{q:1,r:0});casts[1]={spell,origin:{q:2,r:0},target:at(foe),area:[at(foe)]};
 const swaps=knownDisplacementBranch(view(state),state.cells,casts,new Set());
 assert.deepEqual(swaps.get('water')!.landing,{q:1,r:0});assert.deepEqual(swaps.get('foe')!.landing,{q:0,r:0});
});

test('a cancelled projectile supplies no force consequence',()=>{
 const {state,caster,friend}=fixture();Object.assign(friend,{q:1,r:0});Object.assign(state.units.find(unit=>unit.id==='foe')!,{q:0,r:3});
 const plan=validatePlan(state,0,{orders:[{unitId:caster.id,spellId:'gale',cast:at(friend)},{unitId:friend.id,spellId:'water_jet',cast:at(caster)}]});
 const preview=targetImpactPreview(view(state),0,plan,caster.id)!;
 assert.equal(preview.cancelled,true);assert.ok(preview.targets.every(target=>target.displacement===undefined));
});
