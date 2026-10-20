import test from 'node:test';
import assert from 'node:assert/strict';
import * as tower from '../lib/tactics-v22.ts';
import * as story from '../lib/tactics-v20.ts';
import * as arena from '../lib/tactics-v18.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {CURRENT_SPELL_MODEL,profileSpell,spellAtCell} from '../lib/spell-profile-v42.ts';
import {ALL_SPELLS,getSpell} from '../lib/spells-v20.ts';
import {combatBreakdown,validateCombatBreakdown} from '../lib/combat-consequence-v44.ts';
import {targetImpactPreview} from '../lib/target-impact-v41.ts';
import {createCampaignGame,readCampaignProfile} from '../lib/story-v20.ts';
import type {Point} from '../lib/game.ts';
import {presentArena} from '../lib/skirmish-client-v18.ts';
import {ARENA_SPELL_RULES,arenaPlanningForecast,arenaTargetImpactPreview,arenaHasPrivateAlliedOrders} from '../lib/arena-presentation-v44.ts';

const actor=(id:string,championId:string):tower.TowerActor=>{const build=canonicalBuild(championId);return {id,championId,affinities:build.affinities,loadout:build.loadout,hp:8};};
const at=({q,r}:Point)=>({q,r});
const same=(a:Point,b:Point)=>a.q===b.q&&a.r===b.r;
function fixture(){
 const light=actor('light','haara');light.loadout=['sunburst','radiant_bolt','mend','clear_sight'];
 const state=tower.createTowerBattle({id:'contract44',mapId:'CONTRACT44',allies:[light],enemies:[actor('foe','treevor_mason')],learnedSpells:[]});
 for(const cell of state.cells){Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false});delete cell.ttl;delete cell.elements;delete cell.reactions;delete cell.ice;delete cell.barrier;}
 Object.assign(state.units[0],{q:-4,r:0});Object.assign(state.units[1],{q:0,r:0});return state;
}
const asStory=(state:tower.SimState)=>({...state,rulesVersion:20}) as unknown as story.SimState;
const asArena=(state:tower.SimState)=>({...state,rulesVersion:18}) as unknown as arena.SimState;
const plan=(spellId:string):tower.TeamPlan=>({orders:[{unitId:'light',spellId,cast:{q:0,r:0}}]});
const damage=(state:{lastResolution:tower.SimEvent[]})=>state.lastResolution.filter(event=>event.kind==='damage'&&event.unitId==='foe').reduce((sum,event)=>sum+(event.amount??0),0);

test('current Sunburst is a protection-breaking Light burst in all three native engines and forecast',()=>{
 const state=fixture();state.units[1].statuses.ward={turns:2,power:3};
 assert.equal(state.spellModel,CURRENT_SPELL_MODEL);
 for(const [name,run] of [
  ['Tower',(spell:string)=>tower.resolveRound(state,[plan(spell),{orders:[]}])],
  ['Story',(spell:string)=>story.resolveRound(asStory(state),[plan(spell),{orders:[]}])],
  ['Arena',(spell:string)=>arena.resolveRound(asArena(state),[plan(spell),{orders:[]}])],
 ] as const){
  const sun=run('sunburst'),bolt=run('radiant_bolt');
  assert.equal(damage(sun),2,name);assert.equal(damage(bolt),0,name);
  const victim=sun.units.find(unit=>unit.id==='foe')!;
  assert.equal(victim.statuses.blind,undefined);assert.ok(victim.statuses.clarity);
  const detail=sun.lastResolution.find(event=>event.kind==='damage'&&event.unitId==='foe')!.breakdown!;
  assert.deepEqual(detail,{sources:[{kind:'spell',unitId:'light',spellId:'sunburst',amount:3}],prevented:1,total:2});
 }
 const preview=targetImpactPreview(asStory(state),0,plan('sunburst'),'light')!;
 assert.equal(preview.targets.find(target=>target.id==='foe')!.damage.min,2);
});

test('undefined and original focused profiles retain Sunburst Blind and original mitigation',()=>{
 const base=getSpell('sunburst');
 for(const model of [undefined,'focused'] as const){
  const spell=profileSpell(base,model);assert.notEqual(spell.pierce,true);assert.ok(spell.harmful?.some(status=>status.id==='blind'));
  const state=fixture();state.spellModel=model;state.units[1].statuses.ward={turns:2,power:3};
  const next=tower.resolveRound(state,[plan('sunburst'),{orders:[]}]);
  assert.equal(damage(next),0);assert.ok(next.lastResolution.every(event=>event.breakdown===undefined));
 }
 assert.equal(profileSpell(base,CURRENT_SPELL_MODEL).harmful,undefined);
 assert.ok(base.harmful?.some(status=>status.id==='blind'),'Immutable original catalogue');
});

test('focused creature counterplay describes its actual radius while old precise kits keep original text',()=>{
 for(const name of ['Puddle Splash','Mirror Needle','Soot Wash','First Seed','Root Nest','Whistle Relay','Last Lamp']){
  const base=ALL_SPELLS.find(spell=>spell.name===name)!;assert.ok(base);
  for(const model of ['focused',CURRENT_SPELL_MODEL] as const){
   const spell=profileSpell(base,model);
   assert.equal(spell.radius,2);assert.match(spell.counterplay!,/radius-2/);
   assert.doesNotMatch(spell.counterplay!,/only one|one precise|single healed|precise, costly/i);
  }
  assert.equal(profileSpell(base,undefined).counterplay,base.counterplay);
 }
 const sun=profileSpell(getSpell('sunburst'),CURRENT_SPELL_MODEL);
 assert.equal(spellAtCell(sun,{q:0,r:0},{q:2,r:0}).pierce,true);
});

test('new Arena forecasts and resolves narrow volume contact without changing original target hits twice',()=>{
 const state=arena.createSimGame({seed:'CONTACT44',rosters:[['red_baron','oh_tipi','treevor_mason'],['wa_bidi','haara','steezo']]});
 const [fire,water]=state.units;let selected:arena.TeamPlan|undefined;
 for(const cell of state.cells){
  const shift=(point:Point)=>({q:point.q+cell.q,r:point.r+cell.r}),origins=[shift({q:-2,r:0}),shift({q:0,r:-2})],targets=[shift({q:2,r:0}),shift({q:1,r:2})];
  if([...origins,...targets].some(point=>!state.cells.some(candidate=>same(point,candidate)&&!arena.isCellSolid(candidate)))||origins.some(point=>state.units.slice(2).some(unit=>same(point,unit))))continue;
  Object.assign(fire,origins[0]);Object.assign(water,origins[1]);
  if(![fire,water].every((unit,index)=>arena.legalCasts(state,unit.id,undefined,index?'water_jet':'ember').some(point=>same(point,targets[index]))))continue;
  selected={orders:[{unitId:fire.id,spellId:'ember',cast:targets[0]},{unitId:water.id,spellId:'water_jet',cast:targets[1]}]};break;
 }
 assert.ok(selected);
 const predicted=arena.plannedProjectileClashes(state,selected);assert.equal(predicted.length,1);assert.equal(predicted[0].flightFraction,7/13);
 const presented=presentArena(state,0);
 const described=predicted.map(clash=>({...clash,terrain:'steam'}));
 assert.deepEqual(ARENA_SPELL_RULES.projectedVolley(presented,0,selected).clashes,described,'Renderer queued paths use native current contact');
 assert.deepEqual(arenaPlanningForecast(presented,selected,fire.id)!.clashes.map(clash=>({...clash,elements:[...clash.elements].sort()})),described.map(clash=>({...clash,elements:[...clash.elements].sort()})),'Selected forecast uses the same contact and ingredient set');
 const next=arena.resolveRound(state,[selected,{orders:[]}]);assert.equal(next.projectileModel,'volume');
 assert.equal(next.lastResolution.filter(event=>event.kind==='clash').length,1);
 assert.deepEqual(arena.restoreSimState(JSON.parse(JSON.stringify(next))),next);
 const forged=structuredClone(next);forged.lastResolution=forged.lastResolution.filter(event=>event.kind!=='clash');assert.throws(()=>arena.restoreSimState(forged),/meetings/);
});

test('native current and older battle profiles restore without silently changing spell models',()=>{
 const towerState=tower.createTowerBattle({id:'restore44',mapId:'RESTORE44',allies:[actor('a','haara')],enemies:[actor('b','treevor_mason')],learnedSpells:[]});
 const storyState=createCampaignGame(readCampaignProfile(null),'oh_tipi');
 for(const model of [undefined,'focused',CURRENT_SPELL_MODEL] as const){
  for(const [state,restore,resolve] of [
   [towerState,tower.restoreSimState,tower.resolveRound],
   [storyState,story.restoreSimState,story.resolveRound],
   [arena.createSimGame(),arena.restoreSimState,arena.resolveRound],
  ] as const){
   const saved=structuredClone(state);if(model)saved.spellModel=model;else delete saved.spellModel;delete saved.projectileModel;
   const restored=restore(saved as never);assert.equal(restored.spellModel,model);
   const next=resolve(restored as never,[{orders:[]},{orders:[]}]);
   assert.equal(next.projectileModel,'volume');assert.equal(next.spellModel,model);
   assert.deepEqual(restore(JSON.parse(JSON.stringify(next))),next);
  }
 }
});

test('four- and six-seat Arena teams never invent Guard orders for uncontrolled allies',()=>{
 for(const playerCount of [4,6] as const)for(const seat of [0,playerCount-1] as arena.Player[]){
  const native=arena.createSimGame({playerCount,mode:'teams',seed:'PRIVATE44'}),presented=presentArena(native,seat),own=native.units.filter(unit=>unit.owner===seat),ids=own.map(unit=>unit.id);
  const selected=own[0],spell=selected.loadout[0],aim=arena.legalCasts(native,selected.id,undefined,spell)[0],plan={orders:[{unitId:selected.id,spellId:spell,cast:at(aim)}]};
  assert.equal(arenaHasPrivateAlliedOrders(presented,ids),true);
  assert.equal(arenaPlanningForecast(presented,plan,selected.id,spell,aim,ids),null);
  assert.equal(arenaTargetImpactPreview(presented,plan,selected.id,spell,aim,ids),null);
  assert.deepEqual(ARENA_SPELL_RULES.spellArea(presented,selected.id,spell,aim),arena.spellArea(native,selected.id,spell,aim),'Honest geometry remains available');
  for(const ally of presented.units.filter(unit=>unit.owner===0&&!ids.includes(unit.id)))ally.hp=0;
  assert.equal(arenaHasPrivateAlliedOrders(presented,ids),false,'Defeated teammates have no hidden action');
 }
 const native=arena.createSimGame({playerCount:6,mode:'free-for-all',seed:'PUBLIC44'}),seat=5,presented=presentArena(native,seat),own=native.units.filter(unit=>unit.owner===seat),unit=own[0],ids=own.map(unit=>unit.id),spell=unit.loadout[0],aim=arena.legalCasts(native,unit.id,undefined,spell)[0],plan={orders:[{unitId:unit.id,spellId:spell,cast:at(aim)}]};
 assert.equal(arenaHasPrivateAlliedOrders(presented,ids),false);
 assert.ok(arenaPlanningForecast(presented,plan,unit.id,spell,aim,ids));
 assert.ok(arenaTargetImpactPreview(presented,plan,unit.id,spell,aim,ids));
});

test('consequence totals conserve raw contribution minus aggregate prevention and reject forged channels',()=>{
 const detail=combatBreakdown([{kind:'spell',unitId:'a',spellId:'ember',amount:4},{kind:'burn',amount:1}],3);
 assert.equal(detail.prevented,2);
 const check=(input:unknown)=>validateCombatBreakdown(input,{kind:'damage',amount:3},new Set(['a']),new Set(['ember']));
 check(detail);assert.throws(()=>check({...detail,prevented:0}),/conserve/);
 assert.throws(()=>check({...detail,sources:[{kind:'spell',unitId:'missing',spellId:'ember',amount:5}]}),/contributor/);
 assert.throws(()=>check({...detail,sources:[{kind:'drain',unitId:'a',spellId:'ember',amount:5}]}),/channel/);
});

test('a fully prevented centre heal keeps its explanation without a false critical marker',()=>{
 const caster=actor('caster','s_wayne');caster.loadout=['radiant_bolt','mend','siphon','wither_bolt'];
 const state=tower.createTowerBattle({id:'blocked-centre44',mapId:'HEAL-CENTRE44',allies:[caster],enemies:[actor('foe','treevor_mason')],learnedSpells:[]});
 state.round=6;state.version=6;
 Object.assign(state.units[0],{q:0,r:0,hp:4,statuses:{wither:{turns:2,power:1}}});
 const orders={orders:[{unitId:'caster',spellId:'radiant_bolt',cast:{q:0,r:0}}]};
 const next=tower.resolveRound(state,[orders,{orders:[]}]),heal=next.lastResolution.find(event=>event.kind==='heal'&&event.unitId==='caster')!;
 assert.equal(heal.amount,0);assert.equal(heal.critical,undefined);
 assert.deepEqual(heal.breakdown,{sources:[{kind:'spell',unitId:'caster',spellId:'radiant_bolt',amount:2}],prevented:2,total:0});
 assert.deepEqual(tower.restoreSimState(JSON.parse(JSON.stringify(next))),next);
 const forged=structuredClone(next);forged.lastResolution.find(event=>event.kind==='heal'&&event.unitId==='caster')!.critical=true;
 assert.throws(()=>tower.restoreSimState(forged),/centre critical/,'The validator must still reject a false blocked critical');
 const clear=structuredClone(state);clear.units[0].statuses={};
 const positive=tower.resolveRound(clear,[orders,{orders:[]}]).lastResolution.find(event=>event.kind==='heal'&&event.unitId==='caster')!;
 assert.equal(positive.amount,1);assert.equal(positive.critical,true,'A surviving centre bonus is still marked');
});
