import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS,getChampion} from '../lib/roster-v10.ts';
import {ALL_SPELLS,SIGNATURES,availableSpellIds,defaultLoadout,effectiveSpell,getSignature,getSpell,repairLoadout,spellAccess,spellCost,spellScalingSummary,validateLearnedSignatures,validateLoadout} from '../lib/spells-v10.ts';
import {castAvailability,chooseAIPlan,createSimGame,legalCasts,prepareTeam,resolveRound,restoreSimState,spellArea,spellRange,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v10.ts';
import {choosePracticePlan} from '../lib/practice-v10.ts';

const empty=():TeamPlan=>({orders:[]});
const learned=SIGNATURES.map(spell=>spell.id).sort();
const borrowed=SIGNATURES.find(spell=>spell.element==='water'&&spell.signatureChampionId!=='oh_tipi')!;
function atRound(round:number,libraries:[string[],string[]]=[[],[]]):SimState {
  let state=createSimGame(undefined,undefined,undefined,libraries);
  while(state.round<round)state=resolveRound(state,[empty(),empty()]);
  return state;
}
function flat(state=createSimGame()):SimState {
  state.cells.forEach(cell=>{cell.biome='plain';cell.height=0;});
  state.units[0].q=0;state.units[0].r=0;
  state.units[3].q=1;state.units[3].r=0;
  return state;
}

test('all thirty champions have a unique signature of their fixed highest starting affinity',()=>{
  assert.equal(SIGNATURES.length,30);assert.equal(new Set(SIGNATURES.map(s=>s.id)).size,30);
  for(const champion of CHAMPIONS){
    const signature=getSignature(champion.id),rank=champion.affinities[signature.element]!;
    assert.equal(signature.signatureChampionId,champion.id);assert.equal(rank,3);
    assert.ok(Object.values(champion.affinities).every(points=>points!<=rank));
    assert.equal(signature.level,5);assert.equal(signature.cost,5);
    assert.equal(spellAccess(champion.id,signature.id).requiredAffinity,3);
    assert.equal(spellAccess(champion.id,signature.id).unlocked,true);
    assert.equal(availableSpellIds(champion.id,defaultLoadout(champion.id)).at(-1),signature.id);
    assert.throws(()=>validateLoadout(champion.id,[signature.id,...defaultLoadout(champion.id).slice(1)]),/fixed fifth slot/);
  }
});

test('creator discount is exactly two affinity and two Flux at every eligible rank',()=>{
  for(const signature of SIGNATURES){
    const creator=signature.signatureChampionId!,other=CHAMPIONS.find(c=>c.id!==creator)!.id;
    for(let rank=3;rank<=6;rank++){
      const allocation={[signature.element]:rank};
      assert.equal(spellCost(creator,signature.id,allocation),3);
      assert.equal(spellCost(other,signature.id,allocation),5);
      assert.equal(spellAccess(creator,signature.id,allocation).requiredAffinity,3);
      assert.equal(spellAccess(other,signature.id,allocation,[signature.id]).requiredAffinity,5);
      assert.equal(spellAccess(other,signature.id,allocation,[signature.id]).unlocked,rank>=5);
    }
    assert.equal(spellAccess(creator,signature.id,{[signature.element]:2}).unlocked,false);
  }
});

test('learned signatures are known unique canonical libraries and match creation clones them',()=>{
  assert.deepEqual(validateLearnedSignatures([...learned].reverse()),learned);
  for(const bad of [null,{},['ember'],['signature_missing'],[learned[0],learned[0]],['__proto__']])assert.throws(()=>validateLearnedSignatures(bad));
  const supplied:[string[],string[]]=[[learned[1],learned[0]],[]],state=createSimGame(undefined,undefined,undefined,supplied);
  supplied[0].push(learned[2]);assert.deepEqual(state.learnedSignatures,[[learned[0],learned[1]],[]]);
  assert.deepEqual(restoreSimState(state),state);
  assert.throws(()=>createSimGame(undefined,undefined,undefined,[[]] as never),/both squads/);
});

test('borrowers need both Story knowledge and affinity; only borrowers consume an equip slot',()=>{
  const affinity={...getChampion('oh_tipi').affinities,water:5};
  assert.match(spellAccess('oh_tipi',borrowed.id,affinity).reason!,/Beat .* in Story/);
  assert.equal(spellAccess('oh_tipi',borrowed.id,{water:4},[borrowed.id]).unlocked,false);
  assert.equal(spellAccess('oh_tipi',borrowed.id,affinity,[borrowed.id]).unlocked,true);
  const kit=[borrowed.id,'water_jet','ember','mend'];
  assert.deepEqual(validateLoadout('oh_tipi',kit,affinity,[borrowed.id]),kit);
  assert.deepEqual(repairLoadout('oh_tipi',kit,affinity,[borrowed.id]),kit);
  assert.equal(availableSpellIds('oh_tipi',kit,affinity,[borrowed.id]).length,5);
  assert.ok(!availableSpellIds('oh_tipi',kit,affinity).includes(borrowed.id));
  assert.throws(()=>validateLoadout('oh_tipi',kit,affinity),/Story/);
  assert.ok(!repairLoadout('oh_tipi',kit,affinity).includes(borrowed.id));
});

test('every derived spell is immutable and scales only bounded intended dimensions',()=>{
  const before=JSON.stringify(ALL_SPELLS);
  assert.equal(ALL_SPELLS.length,78);
  for(const base of ALL_SPELLS)for(let rank=0;rank<=6;rank++){
    const spell=effectiveSpell('oh_tipi',base.id,{[base.element]:rank});
    assert.ok(Object.isFrozen(spell));assert.notEqual(spell,base);
    assert.equal(spell.range,base.range===0?0:base.range+Number(rank>=2)+Number(rank>=5));
    assert.equal(spell.radius,base.radius);assert.equal(spell.shape,base.shape);
    assert.equal(spell.selfDamage,base.selfDamage);assert.equal(spell.cooldown,base.cooldown);assert.equal(spell.push,base.push);
    assert.equal(spell.damage,base.damage+(base.damage?Number(rank>=3)+Number(rank>=6):0));
    for(const channel of ['harmful','friendly','self'] as const)(spell[channel]??[]).forEach((effect,index)=>{
      assert.ok(Object.isFrozen(effect));assert.ok(Object.isFrozen(spell[channel]));
      const original=base[channel]![index];
      assert.ok(effect.turns<=3);
      if(['rooted','chilled','blind','concussed'].includes(effect.id)||(channel!=='harmful'&&['burn','wither'].includes(effect.id)))assert.equal(effect.turns,original.turns);
    });
    assert.equal(spell.description.includes('undefined'),false);
    if(spell.damage)assert.match(spell.description,new RegExp(`Deal ${spell.damage}`));
    if(spell.heal)assert.match(spell.description,new RegExp(`for ${spell.heal}\\.`));
  }
  assert.equal(JSON.stringify(ALL_SPELLS),before);
});

test('rank milestones improve primary damage, healing, Ward or Flux without amplifying self costs',()=>{
  assert.equal(effectiveSpell('oh_tipi','ember',{fire:6}).damage,4);
  assert.equal(effectiveSpell('oh_tipi','mend',{light:6}).heal,5);
  assert.equal(effectiveSpell('oh_tipi','bulwark',{earth:6}).friendly!.find(s=>s.id==='ward')!.power,5);
  assert.equal(effectiveSpell('oh_tipi','tailwind',{air:6}).recharge,3);
  assert.equal(effectiveSpell('oh_tipi','veil',{dark:6}).steal,3);
  assert.equal(effectiveSpell('oh_tipi','water_jet',{water:4}).harmful![0].turns,3);
  assert.equal(effectiveSpell('oh_tipi','cauterize',{fire:6}).friendly![0].turns,1);
  assert.equal(effectiveSpell('oh_tipi','soul_chain',{dark:6}).self![0].turns,2);
  assert.equal(effectiveSpell('oh_tipi','slipstream',{air:6}).range,0);
  assert.equal(effectiveSpell('oh_tipi','immolate',{fire:6}).selfDamage,1);
  assert.match(spellScalingSummary('oh_tipi','water_jet',{water:6}),/\+2 reach.*\+2 damage.*\+1 status round/);
});

test('reach preview, legal casts and area share effective stats without growing footprint',()=>{
  const state=flat(),unit=state.units[0],base=getSpell('water_jet');
  unit.affinities.water=5;
  assert.ok(legalCasts(state,unit.id,undefined,base.id).some(cell=>cell.q===6&&cell.r===0));
  assert.ok(!legalCasts(state,unit.id,undefined,base.id).some(cell=>cell.q===7&&cell.r===0));
  assert.equal(spellRange(unit,base,state.cells.find(c=>c.q===0&&c.r===0)!,state.cells.find(c=>c.q===6&&c.r===0)!),6);
  assert.equal(spellArea(state,unit.id,'rainfall',{q:0,r:0}).length,19);
  unit.statuses.blind={turns:1,power:1};
  assert.ok(!legalCasts(state,unit.id,undefined,base.id).some(cell=>cell.q===6&&cell.r===0));
});

test('resolution uses strengthened damage while preserving Guard and current-turn Wet counterplay',()=>{
  const state=flat(atRound(7)),unit=state.units[0],victim=state.units[3];unit.affinities.water=6;
  const next=resolveRound(state,[{orders:[{unitId:unit.id,spellId:'water_jet',cast:{q:victim.q,r:victim.r}}]},empty()]);
  assert.equal(next.units[3].hp,5,'4 spell damage minus Guard1');
  assert.equal(next.units[3].statuses.wet!.turns,3);
  const base=flat(atRound(7));base.units[0].affinities.water=6;base.units[1].q=-1;base.units[1].r=0;
  base.units[1].loadout=['ember','stone','mend','gust'];base.units[1].affinities={...base.units[1].affinities};
  const combined=resolveRound(base,[{orders:[{unitId:base.units[0].id,spellId:'water_jet',cast:{q:1,r:0}},{unitId:base.units[1].id,spellId:'ember',cast:{q:1,r:0}}]},empty()]);
  assert.equal(combined.units[3].statuses.burn,undefined);assert.ok(combined.cells.find(c=>c.q===1&&c.r===0)!.reactions?.includes('steam'));
});

test('training to level five, equipping learned signature and casting happen in one sealed turn',()=>{
  const state=atRound(5,[[borrowed.id],[]]),unit=state.units[0],before=structuredClone(state);
  const plan:TeamPlan={orders:[],training:[{unitId:unit.id,element:'water'},{unitId:unit.id,element:'water'}],loadouts:[{unitId:unit.id,spells:[borrowed.id,'water_jet','ember','mend']}]};
  const projected=prepareTeam(state,0,plan),target=legalCasts(projected,unit.id,undefined,borrowed.id)[0];assert.ok(target);
  assert.equal(castAvailability(projected,unit.id,borrowed.id).cost,5);
  assert.equal(castAvailability(projected,unit.id,borrowed.id).available,true);
  plan.orders=[{unitId:unit.id,spellId:borrowed.id,cast:{q:target.q,r:target.r}}];
  const next=resolveRound(state,[plan,empty()]);
  assert.deepEqual(state,before);assert.equal(next.units[0].cooldowns[borrowed.id],3);
  assert.ok(next.lastResolution.some(event=>event.kind==='cast'&&event.spellId===borrowed.id));
  assert.deepEqual(restoreSimState(next),next);
  const off=prepareTeam(next,0,{orders:[],loadouts:[{unitId:unit.id,spells:['water_jet','ember','stone','mend']}]});
  assert.equal(off.units[0].cooldowns[borrowed.id],3);assert.deepEqual(restoreSimState(off),off);
});

test('opponent knowledge never grants borrower access and plans cannot forge a library',()=>{
  const state=atRound(5,[[],[borrowed.id]]),unit=state.units[0];
  const train:TeamPlan={orders:[],training:[{unitId:unit.id,element:'water'},{unitId:unit.id,element:'water'}]};
  assert.throws(()=>prepareTeam(state,0,{...train,loadouts:[{unitId:unit.id,spells:[borrowed.id,'water_jet','ember','mend']}]}),/Story/);
  assert.throws(()=>validatePlan(state,0,{orders:[],learnedSignatures:[borrowed.id]}),/unknown field/);
  const forged=prepareTeam(state,0,train);forged.units[0].loadout[0]=borrowed.id;
  assert.equal(castAvailability(forged,unit.id,borrowed.id).available,false);assert.throws(()=>restoreSimState(forged),/Story/);
  const missing=structuredClone(state);delete (missing as Partial<SimState>).learnedSignatures;assert.throws(()=>restoreSimState(missing),/both learned/);
});

test('restore accepts legitimate scaled statuses and rejects prolonged control or forged power',()=>{
  const state=atRound(7),unit=state.units[0];unit.affinities.water=6;
  const target=legalCasts(state,unit.id,undefined,'water_jet').find(cell=>cell.q!==unit.q||cell.r!==unit.r)!;
  const next=resolveRound(state,[{orders:[{unitId:unit.id,spellId:'water_jet',cast:{q:target.q,r:target.r}}]},empty()]);
  next.units[0].statuses={wet:{turns:3,power:1},ward:{turns:2,power:5}};
  assert.deepEqual(restoreSimState(next),next);
  next.units[0].statuses.rooted={turns:2,power:1};assert.throws(()=>restoreSimState(next),/status duration/);
  delete next.units[0].statuses.rooted;
  for(const id of ['burn','ward'] as const){const saved=structuredClone(next);saved.units[0].statuses[id]={turns:3,power:1};assert.throws(()=>restoreSimState(saved),/status duration/);}
  next.units[0].statuses.ward!.power=6;assert.throws(()=>restoreSimState(next),/status duration/);
});

test('scaled protection resolves and restores at its actual stronger power and safe duration',()=>{
  const state=atRound(7),unit=state.units[2];unit.affinities.earth=6;unit.loadout=['bulwark','stone','mend','ember'];
  const next=resolveRound(state,[{orders:[{unitId:unit.id,spellId:'bulwark',cast:{q:unit.q,r:unit.r}}]},empty()]);
  assert.deepEqual(next.units[2].statuses.ward,{turns:2,power:5});
  assert.deepEqual(next.units[2].statuses.anchored,{turns:2,power:1});
  assert.deepEqual(restoreSimState(next),next);
});

test('AI and practice produce deterministic legal plans and restorable completed matches with learned libraries',()=>{
  for(const policy of [chooseAIPlan,choosePracticePlan]){
    let state=createSimGame(undefined,'frontier:v10-signatures',undefined,[learned,learned]);let exchanges=0;
    while(state.winner===null){
      const plans:[TeamPlan,TeamPlan]=[policy(state,0),policy(state,1)];
      assert.deepEqual(policy(state,0),plans[0]);
      assert.deepEqual(validatePlan(state,0,plans[0]),plans[0]);
      state=resolveRound(state,plans);assert.deepEqual(restoreSimState(state),state);
      assert.ok(++exchanges<=20);
    }
  }
});
