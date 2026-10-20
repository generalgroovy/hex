import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound,restoreSimState,getCell,previewField,fieldEffects,previewDisplacement,validateLoadout,getSpell,ALL_SPELLS,COMBINATIONS,type SimState,type SimUnit,type TeamPlan,type Element} from '../lib/tactics-v14.ts';
import {createSimGame as oldGame,resolveRound as oldResolve,previewField as oldField,getCell as oldCell,restoreSimState as oldRestore} from '../lib/tactics-v13.ts';

const empty=():TeamPlan=>({orders:[]});
const at=(unit:SimUnit,q:number,r:number)=>Object.assign(unit,{q,r});
const point=({q,r}:{q:number;r:number})=>({q,r});
function field(state:SimState,q:number,r:number,elements:Element[],ice=false){const cell=getCell(state,q,r)!;Object.assign(cell,previewField(cell,elements,ice));}
function fixture():SimState {
  const state=createSimGame([['grace_reava','fluup','spai_si'],['oh_tipi','haara','treevor_mason']]);
  for(const cell of state.cells){cell.biome='plain';cell.terrain='plain';cell.height=0;cell.well=false;}
  state.units.slice(0,3).forEach((unit,index)=>{at(unit,-2-index,0);unit.loadout=validateLoadout(unit.championId,['gust','gale','tailwind','wind_shear'],unit.affinities);});
  at(state.units[3],0,0);at(state.units[4],4,-4);at(state.units[5],5,-4);
  return state;
}
const cast=(state:SimState,index=0,spellId='gale',q=0,r=0)=>({unitId:state.units[index].id,spellId,cast:{q,r}});
const run=(state:SimState,orders:TeamPlan["orders"]=[cast(state)],rival:TeamPlan=empty())=>resolveRound(state,[{orders},rival]);
const environmental=(state:SimState,id:string)=>state.lastResolution.filter(event=>event.unitId===id&&event.kind==='surface'&&event.amount).reduce((sum,event)=>sum+event.amount!,0);
const canonical=(state:SimState)=>({...state,units:[...state.units].sort((a,b)=>a.id.localeCompare(b.id)),cells:[...state.cells].sort((a,b)=>a.q-b.q||a.r-b.r)});

test('liquid magical Water quenches old and incoming Burn; frozen Water remains a dry sliding surface',()=>{
  for(const ice of [false,true]){
    const state=fixture(),victim=state.units[3];victim.statuses.burn={turns:2,power:1};field(state,0,0,['water'],ice);
    const result=resolveRound(state,[empty(),empty()]),after=result.units[3];
    assert.equal(after.hp,ice?7:8);assert.equal(Boolean(after.statuses.burn),ice);
    assert.equal(after.statuses.wet?.turns,ice?undefined:1);
    assert.equal(fieldEffects(getCell(state,0,0)!).statuses?.some(status=>status.id==='wet'),!ice);
  }
  const ground=fixture();ground.units[3].statuses.burn={turns:2,power:1};getCell(ground,0,0)!.terrain='water';getCell(ground,0,0)!.biome='water';
  assert.equal(resolveRound(ground,[empty(),empty()]).units[3].hp,7,'ordinary biome geometry is unchanged; magical contact is explicit');
});

test('a newly formed liquid field wets an enemy even when the creating support spell has no hostile Wet',()=>{
  const state=fixture(),water=state.units[3],victim=state.units[0];at(victim,0,0);at(water,2,0);victim.statuses.burn={turns:2,power:1};
  water.affinities={water:5,fire:2};water.loadout=validateLoadout(water.championId,['rainfall','water_jet','cleansing_tide','ember'],water.affinities);
  const result=resolveRound(state,[empty(),{orders:[cast(state,3,'rainfall',0,0)]}]);
  assert.equal(result.units[0].hp,8);assert.equal(result.units[0].statuses.burn,undefined);assert.equal(result.units[0].statuses.wet?.turns,1);
  assert.equal(getCell(result,0,0)!.terrain,'water');
});

test('only liquid Water gains contact Wet; all 63 exact mixture identities remain distinct',()=>{
  assert.equal(COMBINATIONS.length,63);assert.equal(new Set(COMBINATIONS.map(combination=>JSON.stringify(combination.mechanics))).size,63);
  const state=fixture();field(state,0,0,['water','fire']);state.units[3].statuses.burn={turns:2,power:1};
  const result=resolveRound(state,[empty(),empty()]);assert.equal(result.units[3].statuses.wet,undefined);assert.equal(result.units[3].hp,7,'Steam does not inherit a hidden Water trait');
});

test('forced impacts use hard terrain only and add one damage plus next-round Concussed',()=>{
  for(const obstacle of ['barrier','ruins'] as const){
    const state=fixture(),cell=getCell(state,1,0)!;if(obstacle==='barrier')cell.barrier=2;else cell.biome='ruins';
    const result=run(state),victim=result.units[3];
    assert.deepEqual(point(victim),{q:0,r:0});assert.equal(victim.hp,6,'2 spell damage minus Guard, then one impact');
    assert.equal(environmental(result,victim.id),1);assert.equal(victim.statuses.concussed?.turns,1);assert.equal(victim.statuses.resolve?.turns,2);
    assert.equal(result.lastResolution.filter(event=>event.unitId===victim.id&&event.text.includes('strikes solid terrain')).length,1);
  }
});

test('Guard, Anchored, old immunity and fresh Clarity each retain their distinct counterplay',()=>{
  const guarded=fixture();getCell(guarded,1,0)!.barrier=2;
  assert.equal(environmental(run(guarded,[cast(guarded,0,'gust')]),guarded.units[3].id),0,'Guard absorbs the whole weak push');
  for(const status of ['anchored','resolve','clarity'] as const){
    const state=fixture();getCell(state,1,0)!.barrier=2;state.units[3].statuses[status]={turns:1,power:1};
    const result=run(state);assert.equal(environmental(result,state.units[3].id),status==='anchored'?0:1);assert.equal(result.units[3].statuses.concussed,undefined,status);
  }
  const fresh=fixture();getCell(fresh,1,0)!.barrier=2;at(fresh.units[4],1,-2);
  fresh.units[4].loadout=validateLoadout('haara',['clear_sight','mend','radiant_bolt','tailwind']);
  const clear=run(fresh,[cast(fresh)],{orders:[cast(fresh,4,'clear_sight')]});
  assert.equal(environmental(clear,fresh.units[3].id),1);assert.equal(clear.units[3].statuses.concussed,undefined);assert(clear.units[3].statuses.clarity);
});

test('occupancy, map edges and a collision in voluntary movement never inflict an impact',()=>{
  const occupied=fixture();at(occupied.units[4],1,0);const blocked=run(occupied);
  assert.deepEqual(point(blocked.units[3]),{q:0,r:0});assert.equal(environmental(blocked,occupied.units[3].id),0);assert.equal(blocked.units[3].statuses.concussed,undefined);
  const edge=fixture();at(edge.units[0],7,0);at(edge.units[3],9,0);const edged=run(edge,[cast(edge,0,'gale',9,0)]);
  assert.deepEqual(point(edged.units[3]),{q:9,r:0});assert.equal(environmental(edged,edge.units[3].id),0);
  const moving=fixture();at(moving.units[0],-1,0);const bounced=run(moving,[{unitId:moving.units[0].id,move:{q:0,r:0},guard:true}]);
  assert.equal(environmental(bounced,moving.units[0].id),0);assert.equal(bounced.units[0].hp,8);
});

test('coordinated force cannot repeat impact damage, and impact shares the elemental hazard cap',()=>{
  const state=fixture();getCell(state,1,0)!.barrier=2;field(state,0,0,['fire']);
  const result=run(state,[cast(state,0),cast(state,1),cast(state,2)]),victim=result.units[3];
  assert.equal(getCell(result,0,0)!.terrain,'arcstorm');assert.equal(environmental(result,victim.id),1,'formation hazard and wall impact share one environmental point');
  assert.equal(result.lastResolution.filter(event=>event.unitId===victim.id&&event.text.includes('strikes solid terrain')).length,1);
  assert.equal(victim.statuses.concussed?.turns,1);
});

test('a barrier raised in the same exchange can catch force; a simultaneous dispel opens it',()=>{
  const state=fixture(),builder=state.units[2];builder.affinities={air:3,earth:4,light:1};builder.loadout=validateLoadout(builder.championId,['raise_cairn','shatter','gust','tailwind'],builder.affinities);
  const raised=run(state,[cast(state),cast(state,2,'raise_cairn',1,0)]);
  assert.equal(environmental(raised,state.units[3].id),1);assert.deepEqual(point(raised.units[3]),{q:0,r:0});
  const open=structuredClone(state);getCell(open,1,0)!.barrier=2;
  const cleared=run(open,[cast(open),cast(open,2,'shatter',1,0)]);
  assert.equal(environmental(cleared,open.units[3].id),0);assert.deepEqual(point(cleared.units[3]),{q:1,r:0});
});

test('pushing onto existing Quagmire applies Wet on landing without undoing an earlier Burn tick',()=>{
  const state=fixture();field(state,1,0,['water','earth']);state.units[3].statuses.burn={turns:2,power:1};
  const result=run(state),victim=result.units[3];assert.deepEqual(point(victim),{q:1,r:0});
  assert.equal(victim.hp,6,'one guarded spell damage and one old Burn tick occur before landing');assert.equal(victim.statuses.burn,undefined);assert.equal(victim.statuses.wet?.turns,1);
});

test('voluntary liquid contact extinguishes Burn before its tick; forced liquid contact happens after',()=>{
  const state=fixture();field(state,1,0,['water']);state.units[3].statuses.burn={turns:2,power:1};
  const moved=resolveRound(state,[empty(),{orders:[{unitId:state.units[3].id,move:{q:1,r:0},guard:true}]}]);
  assert.equal(moved.units[3].hp,8);assert.equal(moved.units[3].statuses.wet?.turns,1);assert.equal(moved.units[3].statuses.burn,undefined);
  const forced=run(state);assert.equal(forced.units[3].hp,6);assert.equal(forced.units[3].statuses.wet?.turns,1);assert.equal(forced.units[3].statuses.burn,undefined);
});

test('same-exchange Water and Dark create a Black Ice landing trap, independent of unit/order iteration',()=>{
  const state=createSimGame([['grace_reava','oh_tipi','s_wayne'],['oh_tipi','haara','treevor_mason']]);
  for(const cell of state.cells){cell.biome='plain';cell.terrain='plain';cell.height=0;cell.well=false;}
  at(state.units[0],-2,0);at(state.units[1],1,-2);at(state.units[2],2,-2);at(state.units[3],0,0);
  state.units[0].loadout=validateLoadout('grace_reava',['gale','gust','tailwind','wind_shear']);
  const plans:[TeamPlan,TeamPlan]=[{orders:[cast(state),cast(state,1,'water_jet',1,0),cast(state,2,'wither_bolt',1,0)]},empty()];
  const before=structuredClone(state),result=resolveRound(state,plans),victim=result.units[3];
  assert.deepEqual(state,before);assert.equal(getCell(result,1,0)!.terrain,'black_ice');assert.deepEqual(point(victim),{q:1,r:0});assert.equal(victim.statuses.rooted?.turns,1);assert.equal(victim.statuses.resolve?.turns,2);
  const reversed=structuredClone(state);reversed.units.reverse();
  assert.deepEqual(canonical(resolveRound(reversed,[{orders:[...plans[0].orders].reverse()},empty()])),canonical(result));
});

test('landing Clarity, cleansing and fresh Resolve prevent later impact control without cancelling impact damage',()=>{
  const state=fixture();field(state,1,0,['water','dark']);getCell(state,2,0)!.barrier=2;
  const victim=state.units[3];
  const result=run(state,[cast(state)],{orders:[cast(state,3,'ember',0,3)]});
  assert.deepEqual(point(result.units[3]),{q:1,r:0});assert(result.units[3].statuses.rooted);assert.equal(result.units[3].statuses.concussed,undefined,'landing Rooted grants Resolve before impact');assert.equal(environmental(result,victim.id),1);
  const clean=fixture();field(clean,1,0,['fire','water','light']);clean.units[3].statuses.wither={turns:2,power:1};
  const cleaned=run(clean);assert.equal(cleaned.units[3].statuses.wither,undefined);assert.equal(cleaned.units[3].hp,7,'landing cleanse adds no healing and does not rewind the spell hit');
  const clear=fixture();field(clear,1,0,['light']);getCell(clear,2,0)!.barrier=2;
  const clarified=run(clear,[cast(clear)],{orders:[cast(clear,3,'ember',0,3)]});
  assert.equal(clarified.units[3].statuses.clarity?.turns,1);assert.equal(clarified.units[3].statuses.concussed,undefined);assert.equal(environmental(clarified,clear.units[3].id),1);
});

test('fresh cast control grants Resolve before impact and a cleansing landing clears fresh Burn',()=>{
  const state=fixture(),second=state.units[1];getCell(state,1,0)!.barrier=2;
  second.affinities={air:4,fire:1,water:1};second.loadout=validateLoadout(second.championId,['thunderclap','gust','gale','tailwind'],second.affinities);
  const controlled=run(state,[cast(state),cast(state,1,'thunderclap')]);
  assert.equal(controlled.units[3].statuses.concussed?.turns,1);assert.equal(controlled.units[3].statuses.resolve?.turns,2);
  assert.equal(controlled.lastResolution.filter(event=>event.unitId===state.units[3].id&&event.status==='concussed').length,1,'impact cannot reapply already-protected control');
  const clean=fixture();field(clean,1,0,['fire','water','light']);
  clean.units[1].loadout=validateLoadout('fluup',['ember','gust','tailwind','water_jet']);
  const cleared=run(clean,[cast(clean),cast(clean,1,'ember')]);
  assert.equal(cleared.units[3].statuses.burn,undefined);assert.equal(cleared.units[3].hp,5,'the final Steam shelter cannot retroactively halve an earlier volley');
});

test('forced Ice travel applies only its final landing contact, not every crossed field',()=>{
  const state=fixture();field(state,1,0,['water'],true);field(state,2,0,['water','dark']);field(state,3,0,['water'],true);
  const result=run(state),victim=result.units[3];assert.deepEqual(point(victim),{q:3,r:0});
  assert.equal(victim.statuses.rooted,undefined);assert.equal(victim.statuses.wet,undefined);assert.equal(victim.statuses.concussed,undefined);
  assert.equal(result.lastResolution.filter(event=>event.unitId===victim.id&&event.kind==='push').length,1,'one resisted step follows the whole Ice route');
});

test('landing contact neither doubles status duration nor adds a second heal, Flux grant, cast or reaction',()=>{
  const state=fixture();field(state,1,0,['water','earth']);state.units[3].statuses.wet={turns:3,power:1};
  const result=run(state);assert.equal(result.units[3].statuses.wet?.turns,2,'existing longer Wet ticks once and is not extended by short contact');
  const spring=fixture();field(spring,1,0,['fire','water','earth']);spring.units[3].hp=5;spring.units[3].flux=0;
  const landed=run(spring);assert.equal(landed.units[3].hp,4,'Hot Spring healing stays in spell phase, before arrival');assert.equal(landed.units[3].flux,3);
  assert.equal(landed.lastResolution.filter(event=>event.kind==='cast').length,1);assert.equal(landed.lastResolution.filter(event=>event.kind==='reaction').length,0,'walking into a surviving field cannot regenerate it');
});

test('public displacement forecast shares force resistance, Ice route and hard-obstacle contact',()=>{
  const state=fixture(),victim=state.units[3];field(state,1,0,['water'],true);field(state,2,0,['water'],true);getCell(state,3,0)!.barrier=2;
  assert.deepEqual(previewDisplacement(state,victim.id,{q:2,r:0},false),{landing:{q:2,r:0},path:[{q:1,r:0},{q:2,r:0}],impact:true});
  assert.deepEqual(previewDisplacement(state,victim.id,{q:2,r:0},true),{landing:{q:2,r:0},path:[{q:1,r:0},{q:2,r:0}],impact:false});
  victim.statuses.anchored={turns:1,power:1};assert.deepEqual(previewDisplacement(state,victim.id,{q:6,r:0}),{landing:{q:0,r:0},path:[],impact:false});
});

test('new seeded saves restore strictly while frozen rules13 retains old Water and impact behavior',()=>{
  const fresh=createSimGame(),old=oldGame();assert.equal(fresh.rulesVersion,14);assert.equal(old.rulesVersion,13);
  for(const state of [fresh,old]){at(state.units[0] as SimUnit,0,0);state.units[0].statuses.burn={turns:2,power:1};}
  Object.assign(getCell(fresh,0,0)!,previewField(getCell(fresh,0,0)!,['water']));Object.assign(oldCell(old,0,0)!,oldField(oldCell(old,0,0)!,['water']));
  const current=resolveRound(fresh,[empty(),empty()]),historical=oldResolve(old,[empty(),empty()]);
  assert.equal(current.units[0].hp,8);assert.equal(historical.units[0].hp,7);assert.deepEqual(restoreSimState(current),current);assert.deepEqual(oldRestore(historical),historical);
  assert.throws(()=>restoreSimState(historical));assert.throws(()=>oldRestore(current));
  const collision=fixture();getCell(collision,1,0)!.barrier=2;
  const legacy={...structuredClone(collision),rulesVersion:13 as const};
  const oldCollision=oldResolve(legacy,[{orders:[cast(collision)]},empty()]);
  assert.equal(environmental(oldCollision as unknown as SimState,collision.units[3].id),0);assert.equal(oldCollision.units[3].statuses.concussed,undefined);
  for(const spell of ALL_SPELLS.filter(spell=>spell.push))assert.match(spell.description,/ruin or barrier/);
  assert.match(getSpell('gale').description,/Guard resists 1 strength/);
});
