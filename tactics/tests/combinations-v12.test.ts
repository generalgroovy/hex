import test from 'node:test';
import assert from 'node:assert/strict';
import {COMBINATIONS,REACTIONS,ELEMENT_ORDER,combinationFor,combinationById,combinationMask,describeCombination} from '../lib/combinations-v12.ts';
import {createSimGame,restoreSimState,resolveRound,getCell,previewField,fieldCombination,fieldEffects,reactionsFor,movementCost,movementBudget,isIce,isFlooded,terrainCover,validatePlan,chooseAIPlan,castAvailability,legalCasts,type SimState,type SimCell,type SimUnit,type TeamPlan,type Element} from '../lib/tactics-v12.ts';
import {createSimGame as createV11,restoreSimState as restoreV11} from '../lib/tactics-v11.ts';
import {SPELLS,validateLoadout,getSpell,effectiveSpell as effectiveV11} from '../lib/spells-v11.ts';
import {SPELLS as CURRENT_SPELLS,getSpell as currentSpell,effectiveSpell as currentEffectiveSpell} from '../lib/spells-v12.ts';
import {storyInhabitants,inhabitantPulses} from '../lib/inhabitants-v12.ts';
import {choosePracticePlan} from '../lib/practice-v12.ts';

const empty=():TeamPlan=>({orders:[]});
const at=(unit:SimUnit,q:number,r:number)=>Object.assign(unit,{q,r});
const point=({q,r}:{q:number;r:number})=>({q,r});
const same=(a:{q:number;r:number},b:{q:number;r:number})=>a.q===b.q&&a.r===b.r;
const equip=(unit:SimUnit,...spells:string[])=>unit.loadout=validateLoadout(unit.championId,[...spells,...SPELLS.filter(spell=>spell.level===1&&!spells.includes(spell.id)).map(spell=>spell.id)].slice(0,4),unit.affinities);
function setField(cell:SimCell,elements:readonly Element[],freeze=false):void {const next=previewField({...cell,terrain:'plain',elements:undefined,reactions:undefined,ttl:undefined,ice:undefined},elements,freeze);Object.assign(cell,next);if(!next.ice)delete cell.ice;}
function synthetic():SimState {const state=createSimGame();for(const cell of state.cells){cell.biome='plain';cell.terrain='plain';cell.height=0;cell.well=false;}at(state.units[0],0,0);return state;}
function canonical(state:SimState){return {...state,units:[...state.units].sort((a,b)=>a.id.localeCompare(b.id)),cells:[...state.cells].sort((a,b)=>a.q-b.q||a.r-b.r)};}

test('every nonempty six-element set has exactly one canonical, immutable authored identity',()=>{
  assert.equal(COMBINATIONS.length,63);assert.equal(REACTIONS.length,57);
  assert.deepEqual(COMBINATIONS.map(field=>field.mask),Array.from({length:63},(_,index)=>index+1));
  assert.equal(new Set(COMBINATIONS.map(field=>field.id)).size,63);
  assert.equal(new Set(COMBINATIONS.map(field=>field.name)).size,63);
  assert.equal(new Set(REACTIONS.map(field=>JSON.stringify(field.mechanics))).size,57,'mixed fields cannot differ only in name or palette');
  assert.equal(new Set(COMBINATIONS.map(field=>JSON.stringify(field.mechanics))).size,63,'single elements and their compounds also have different mechanical identities');
  assert.deepEqual([1,2,3,4,5,6].map(size=>COMBINATIONS.filter(field=>field.elements.length===size).length),[6,15,20,15,6,1]);
  for(const field of COMBINATIONS){
    assert.equal(combinationMask(field.elements),field.mask);assert.equal(combinationById(field.id),field);
    assert.equal(combinationFor([...field.elements].reverse()),field);
    assert.equal(combinationFor([...field.elements,...field.elements]),field);
    assert.equal(field.description,describeCombination(field.mechanics));
    assert(Object.isFrozen(field));assert(Object.isFrozen(field.mechanics));assert(Object.isFrozen(field.elements));
    assert.deepEqual(reactionsFor(field.elements),field.elements.length===1?[]:[field.id]);
    assert(field.shortRule.length<80);assert(field.description.includes('Affects either team.'));
  }
  assert.equal(combinationFor([]),undefined);assert.equal(combinationById('missing'),undefined);
});

test('preview includes natural substrate and replaces contained pairs with one exact phenomenon',()=>{
  const state=createSimGame(),earth=state.cells.find(cell=>cell.terrain==='earth')!,water=state.cells.find(cell=>cell.terrain==='water')!,plain=getCell(state,0,0)!;
  const spring=previewField(earth,['water','fire']);assert.equal(spring.terrain,'hot_spring');assert.deepEqual(spring.reactions,['hot_spring']);
  assert.equal(previewField(water,['fire']).terrain,'steam');
  assert.equal(previewField(plain,['fire','water','air']).terrain,'geyser');
  assert.equal(previewField(plain,['fire','water','air']).reactions?.includes('steam'),false);
  assert.equal(earth.ttl,undefined,'forecast never changes ground');
  for(const mixture of COMBINATIONS){
    const expected=previewField(plain,mixture.elements);
    const reversed=previewField(plain,[...mixture.elements].reverse());
    assert.deepEqual(expected,reversed,mixture.name);
    for(const first of mixture.elements){
      const staged=previewField(previewField(plain,[first]),mixture.elements.filter(element=>element!==first));
      assert.equal(staged.terrain,expected.terrain,`${mixture.name}: accumulation is a set, not cast order`);
    }
  }
});

test('mixed fields have only their declared movement and cover, without hidden element inheritance',()=>{
  const state=synthetic(),unit=state.units[0],cell=getCell(state,0,0)!,other=getCell(state,1,0)!;
  setField(cell,['fire','water']);assert.equal(isFlooded(cell),false);assert.equal(movementCost(cell,other),1);
  setField(cell,['earth','air','light']);assert.equal(fieldCombination(cell)?.id,'sungrass');assert.equal(movementCost(cell,other),1);assert.equal(movementBudget(unit,state),5);assert.equal(terrainCover(cell),1);
  setField(cell,['earth','air']);assert.equal(fieldCombination(cell)?.id,'sandblast');assert.equal(movementBudget(unit,state),4);assert.equal(movementCost(cell,other),1);
  setField(cell,['water','earth','dark']);assert.equal(isFlooded(cell),true);assert.equal(movementCost(cell,other),2);
  setField(cell,['earth','light','dark']);assert.equal(terrainCover(cell),2);cell.biome='forest';assert.equal(terrainCover(cell),2,'cover takes the stronger value, not the sum');
});

test('only explicit ice mixtures and frost on unmixed Water slide; higher mixtures thaw old ice',()=>{
  const state=synthetic(),cell=getCell(state,0,0)!;
  setField(cell,['water'],true);assert(isIce(cell));
  const steam=previewField(cell,['fire']);assert.equal(steam.terrain,'steam');assert.equal(isIce(steam),false);
  const spring=previewField(cell,['fire','earth'],true);assert.equal(spring.terrain,'hot_spring');assert.equal(isIce(spring),false);
  for(const id of ['hailcurrent','black_ice','rimeveil','stillwater','mooncurrent']){setField(cell,combinationById(id)!.elements);assert(isIce(cell),id);}
  setField(cell,['water','light'],true);assert.equal(isIce(cell),false,'a frost spell does not hide ice beneath Mirrorwater');
});

test('rules12 static, lookup and scaled frost descriptions say unmixed Water without changing rules11 wording or statistics',()=>{
  const frozen=SPELLS.filter(spell=>spell.freeze);assert.equal(frozen.length,2);
  for(const original of frozen){
    const previousText=original.description,affinities={water:3,fire:2};
    const oldEffective=effectiveV11('oh_tipi',original.id,affinities);
    for(const current of [CURRENT_SPELLS.find(spell=>spell.id===original.id)!,currentSpell(original.id),currentEffectiveSpell('oh_tipi',original.id,affinities)]){
      assert(current.description.includes('Freezes unmixed Water.'),original.id);
      assert(current.description.includes('Mixed fields use their own ice rule;'),original.id);
      assert.equal(current.description.includes('Freeze the footprint;'),false);
    }
    const {description:_newDescription,...currentStats}=currentEffectiveSpell('oh_tipi',original.id,affinities);
    const {description:_oldDescription,...oldStats}=oldEffective;
    assert.deepEqual(currentStats,oldStats,'the presentation wrapper must not alter combat values');
    assert.equal(getSpell(original.id).description,previousText);
    assert.equal(getSpell(original.id).description.includes('unmixed Water'),false);
    assert(oldEffective.description.includes('Freeze the footprint;'),'historical effective wording remains historical');
  }
});

test('all 63 field descriptors execute their bounded health, Flux, status and scoring rules in a real seeded match',()=>{
  for(const mixture of COMBINATIONS){
    const state=createSimGame(),unit=state.units[0],cell=getCell(state,0,0)!;
    at(unit,0,0);unit.hp=5;unit.flux=1;Object.assign(cell,previewField(cell,mixture.elements));
    const before=structuredClone(state),result=resolveRound(state,[empty(),empty()]),after=result.units.find(candidate=>candidate.id===unit.id)!;
    assert.deepEqual(state,before,`${mixture.name}: immutable input`);
    const effects=mixture.mechanics;
    assert.equal(after.hp,5+(effects.heal??0)-(effects.hazard==='always'?1:0),mixture.name);
    assert.equal(after.flux,4+(effects.flux??0),mixture.name);
    assert.equal(result.scores[0],1+(effects.wellBonus??0),`${mixture.name}: well score`);
    for(const status of effects.statuses??[]){assert.equal(after.statuses[status.id]?.turns,status.turns,`${mixture.name}: ${status.id}`);}
    assert.deepEqual(restoreSimState(result),result,`${mixture.name}: restored final state`);
    if(effects.consume){assert.equal(getCell(result,0,0)!.ttl,undefined);assert.equal(getCell(result,0,0)!.terrain,'plain');}
    else assert.equal(getCell(result,0,0)!.terrain,mixture.id);
  }
});

test('higher mixtures do not accidentally apply Steam mitigation, Magma damage or Penumbra scoring',()=>{
  const state=synthetic(),unit=state.units[0],enemy=state.units[3],cell=getCell(state,0,0)!;
  cell.well=true;at(enemy,2,0);equip(enemy,'ember');setField(cell,['fire','water','earth']);
  const result=resolveRound(state,[empty(),{orders:[{unitId:enemy.id,spellId:'ember',cast:{q:0,r:0}}]}]);
  const after=result.units.find(candidate=>candidate.id===unit.id)!;
  assert.equal(fieldCombination(getCell(result,0,0)!)?.id,'hot_spring');
  assert.equal(after.hp,8,'Hot Spring heals 1; cover and Guard mitigate the basic hit; no Magma hazard is inherited');
  assert.equal(result.scores[0],1);
  assert.equal(result.lastResolution.some(event=>event.kind==='surface'&&event.amount&&event.unitId===unit.id),false);
  const second=synthetic();at(second.units[0],0,0);getCell(second,0,0)!.well=true;setField(getCell(second,0,0)!,['fire','light','dark']);
  assert.equal(resolveRound(second,[empty(),empty()]).scores[0],1,'Ghostfire does not inherit doubled Penumbra scoring');
});

test('formation hazards trigger once; movement hazards distinguish holding from a new landing',()=>{
  const state=synthetic(),unit=state.units[0],ally=state.units[1];at(ally,2,0);equip(ally,'gust');
  setField(getCell(state,0,0)!,['fire']);
  const formed=resolveRound(state,[{orders:[{unitId:ally.id,spellId:'gust',cast:{q:0,r:0}}]},empty()]);
  assert.equal(formed.units[0].hp,7);assert.equal(getCell(formed,0,0)!.terrain,'arcstorm');
  const refresh=resolveRound(formed,[{orders:[{unitId:ally.id,spellId:'gust',cast:{q:0,r:0}}]},empty()]);
  assert.equal(refresh.units[0].hp,7,'refreshing identical Arcstorm cannot farm opening damage');
  const lane=synthetic(),moving=lane.units[0];setField(getCell(lane,1,0)!,['fire','water','air']);
  const arrived=resolveRound(lane,[{orders:[{unitId:moving.id,move:{q:1,r:0},guard:true}]},empty()]);assert.equal(arrived.units[0].hp,7);
  const stayed=resolveRound(arrived,[empty(),empty()]);assert.equal(stayed.units[0].hp,7);
});

test('cleansing fields prevent control and Burn, while hostile fields respect Resolve',()=>{
  const state=synthetic(),unit=state.units[0];unit.hp=5;unit.statuses={burn:{turns:2,power:1},wither:{turns:2,power:1},blind:{turns:1,power:1}};
  setField(getCell(state,0,0)!,['fire','water','light']);
  const cleared=resolveRound(state,[empty(),empty()]);assert.equal(cleared.units[0].hp,5);assert.deepEqual(cleared.units[0].statuses,{});
  const locked=synthetic();setField(getCell(locked,0,0)!,['water','dark']);const first=resolveRound(locked,[empty(),empty()]);assert(first.units[0].statuses.rooted);assert(first.units[0].statuses.resolve);
  const second=resolveRound(first,[empty(),empty()]);assert.equal(second.units[0].statuses.rooted,undefined,'Resolve prevents repeated field control');
});

test('all six simultaneous ingredients form Worldseed once, preserve ordinary well scoring and then disperse',()=>{
  const state=synthetic(),spells=['water_jet','gust','stone','ember','radiant_bolt','wither_bolt'];
  const positions=[{q:0,r:0},{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1}];
  state.units.forEach((unit,index)=>{at(unit,positions[index].q,positions[index].r);equip(unit,spells[index]);unit.flux=4;});getCell(state,0,0)!.well=true;
  const plans=([0,1] as const).map(owner=>({orders:state.units.filter(unit=>unit.owner===owner).map(unit=>({unitId:unit.id,spellId:spells[state.units.indexOf(unit)],cast:{q:0,r:0}}))})) as [TeamPlan,TeamPlan];
  const result=resolveRound(state,plans),permuted=resolveRound({...structuredClone(state),units:[...structuredClone(state.units)].reverse()},plans.map(plan=>({orders:[...plan.orders].reverse()})) as [TeamPlan,TeamPlan]);
  assert.deepEqual(canonical(result),canonical(permuted));
  const reactions=result.lastResolution.filter(event=>event.kind==='reaction'&&event.q===0&&event.r===0);assert.equal(reactions.length,1);assert.equal(reactions[0].terrain,'worldseed');
  assert.equal(getCell(result,0,0)!.terrain,'plain');assert.equal(getCell(result,0,0)!.ttl,undefined);
  assert.equal(result.scores[0],1);assert.equal(result.units[0].statuses.burn,undefined);assert.equal(result.units[0].statuses.wither,undefined);
});

test('rules12 fixes spell kits and affinity while rules11 saves retain their original engine',()=>{
  const state=createSimGame(),old=createV11(),unit=state.units[0],before=structuredClone(state);
  assert.throws(()=>validatePlan(state,0,{orders:[],loadouts:[{unitId:unit.id,spells:unit.loadout}]}),/fixed/);
  assert.throws(()=>validatePlan(state,0,{orders:[],loadouts:null}),/fixed/);
  assert.throws(()=>validatePlan(state,0,{orders:[],training:[{unitId:unit.id,element:'fire'}]}),/Story/);
  assert.equal(validatePlan(state,0,{orders:[],loadouts:[],training:[]}).orders.length,3);assert.deepEqual(state,before);
  assert.deepEqual(restoreV11(old),old);assert.throws(()=>restoreSimState(old));assert.throws(()=>restoreV11(state));
  const ai=chooseAIPlan(state,0);assert.equal(ai.loadouts,undefined);assert.equal(ai.training,undefined);
});

test('strict restoration rejects stacked pairs, hidden ice, missing substrate and forged creatures',()=>{
  const state=createSimGame();Object.assign(getCell(state,0,0)!,previewField(getCell(state,0,0)!,['fire','water','earth']));assert.deepEqual(restoreSimState(state),state);
  const stacked=structuredClone(state);getCell(stacked,0,0)!.reactions=['steam','magma','quagmire'];assert.throws(()=>restoreSimState(stacked),/chemistry/);
  const icy=structuredClone(state);getCell(icy,0,0)!.ice=true;assert.throws(()=>restoreSimState(icy),/ice/);
  const missing=structuredClone(state),earth=missing.cells.find(cell=>cell.terrain==='earth')!;Object.assign(earth,previewField({...earth,terrain:'plain'},['water']));assert.throws(()=>restoreSimState(missing),/substrate/);
  const forged={...createSimGame(),inhabitants:[{speciesId:'inhabitant-1',q:0,r:0}]};assert.throws(()=>restoreSimState(forged),/inhabitants/);
});

function storyFixture(mapId='frontier:STORY-OH-TIPI'):SimState {const state=createSimGame(undefined,mapId);state.inhabitants=storyInhabitants(state.mapId,state.cells);return state;}
function placeNear(state:SimState,unit:SimUnit,target:{q:number;r:number}){const cell=state.cells.find(cell=>cell.biome!=='ruins'&&!same(cell,target)&&Math.max(Math.abs(cell.q-target.q),Math.abs(cell.r-target.r),Math.abs(cell.q+cell.r-target.q-target.r))===1&&!state.units.some(other=>other.id!==unit.id&&same(other,cell)))!;at(unit,cell.q,cell.r);}

test('real story pulses join casts in one exact batch, and a public counter spends normal Flux to interrupt',()=>{
  const state=storyFixture(),pulse=inhabitantPulses(state)[0];assert(pulse);assert.deepEqual(pulse.elements,['water']);
  const caster=state.units[0];equip(caster,'ember');placeNear(state,caster,pulse.anchor);
  assert(legalCasts(state,caster.id,undefined,'ember').some(cell=>same(cell,pulse.anchor)));
  const plans:[TeamPlan,TeamPlan]=[{orders:[{unitId:caster.id,spellId:'ember',cast:point(pulse.anchor)}]},empty()];
  const result=resolveRound(state,plans);assert.equal(getCell(result,pulse.anchor.q,pulse.anchor.r)!.terrain,'steam');
  assert(result.lastResolution.some(event=>event.kind==='inhabitant'&&event.speciesId===pulse.id));assert.deepEqual(restoreSimState(result),result);
  const counter=storyFixture(),intent=inhabitantPulses(counter)[0],mage=counter.units[2];equip(mage,'stone');placeNear(counter,mage,intent.anchor);mage.flux=3;
  const cost=castAvailability(counter,mage.id,'stone').cost;
  const interrupted=resolveRound(counter,[{orders:[{unitId:mage.id,spellId:'stone',cast:point(intent.anchor)}]},empty()]);
  assert.equal(interrupted.units.find(unit=>unit.id===mage.id)!.flux,3-cost+2);
  assert.equal(getCell(interrupted,intent.anchor.q,intent.anchor.r)!.terrain,'earth');
  assert(interrupted.lastResolution.some(event=>event.kind==='inhabitant'&&event.text.includes('interrupted')));
  assert.deepEqual(restoreSimState(interrupted),interrupted);
});

test('public NPC pulse forecasts help AI leave lethal ground without sealed enemy information',()=>{
  const state=storyFixture('frontier:STORY-S-WAYNE');state.round=2;state.version=2;
  const pulse=inhabitantPulses(state)[0];assert(pulse);assert.deepEqual(pulse.elements,['fire']);
  const unit=state.units[0];at(unit,pulse.anchor.q,pulse.anchor.r);unit.hp=1;
  const plan=chooseAIPlan(state,0),result=resolveRound(state,[plan,empty()]);
  assert(result.units.find(candidate=>candidate.id===unit.id)!.hp>0,'AI must survive the visible lethal release');
  assert.equal(result.lastResolution.some(event=>event.unitId===unit.id&&event.kind==='surface'&&event.amount===1),false,'no damage from the visible release');
});

test('practice and story AI keep fixed kits through complete deterministic legal matches',()=>{
  for(const initial of [createSimGame(),storyFixture()]){
    let state=initial;const kits=state.units.map(unit=>[unit.id,unit.loadout]);
    for(let turns=0;turns<20&&state.winner===null;turns++){
      const plans:[TeamPlan,TeamPlan]=[choosePracticePlan(state,0),chooseAIPlan(state,1)];
      assert(plans.every(plan=>!plan.loadouts&&!plan.training));state=resolveRound(state,plans);restoreSimState(state);
      assert.deepEqual(state.units.map(unit=>[unit.id,unit.loadout]),kits);
    }
    assert.notEqual(state.winner,null);
  }
});
