import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS,MAX_AFFINITY_POINTS,affinityTotal,allocateAffinityBudget,getChampion,teamAffinityTotal,validateChampionAffinities,type AffinityAllocation} from '../lib/roster-v11.ts';
import {ALL_SPELLS,SIGNATURES,defaultLoadout,effectiveSpell,getSignature,getSpell,spellAccess,spellCost,validateLoadout} from '../lib/spells-v11.ts';
import {readLoadouts} from '../lib/loadouts-v11.ts';
import {castAvailability,chooseAIPlan,createSimGame,legalCasts,prepareTeam,resolveRound,restoreSimState,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v11.ts';
import {choosePracticePlan,practiceLoadouts} from '../lib/practice-v11.ts';

const empty=():TeamPlan=>({orders:[]});
const roster=['oh_tipi','wa_bidi','treevor_mason'];
const high=Object.fromEntries(roster.map(id=>[id,allocateAffinityBudget(id,18)]));
const libraries=SIGNATURES.map(spell=>spell.id).sort();
const borrowed=SIGNATURES.find(spell=>spell.element==='water'&&spell.signatureChampionId!=='oh_tipi')!;
const fixed=(state:SimState)=>state.units.map(unit=>({id:unit.id,affinities:unit.affinities}));

test('each character keeps five canonical starting points and budgets deterministically extend its identity',()=>{
  assert.equal(MAX_AFFINITY_POINTS,18);
  for(const champion of CHAMPIONS){
    assert.equal(affinityTotal(champion.affinities),5);
    assert.deepEqual(allocateAffinityBudget(champion.id,5),champion.affinities);
    let previous=champion.affinities;
    for(let budget=5;budget<=18;budget++){
      const allocation=allocateAffinityBudget(champion.id,budget);
      assert.equal(affinityTotal(allocation),budget);
      assert.deepEqual(validateChampionAffinities(champion.id,allocation,budget),allocation);
      assert.ok(Object.keys(allocation).length<=3);
      for(const [element,points] of Object.entries(previous))assert.ok(allocation[element as keyof AffinityAllocation]!>=points!);
      assert.equal(allocation[champion.element],Math.min(6,3+budget-5));
      previous=allocation;
    }
  }
  for(const budget of [0,4,19,5.5,NaN,Infinity])assert.throws(()=>allocateAffinityBudget('oh_tipi',budget),/5 to 18/);
  assert.equal(teamAffinityTotal(roster),15);
  assert.equal(teamAffinityTotal(roster,{oh_tipi:{water:6,fire:2}}),18);
  assert.equal(teamAffinityTotal(roster,high),54);
});

test('new matches freeze independently cloned story allocations, with valid level-six kits available in round one',()=>{
  const supplied=structuredClone(high),kit=['maelstrom','deep_freeze','ember','mend'];
  const state=createSimGame([roster,roster],'frontier:fixed-v11',[{oh_tipi:kit},{}],[libraries,[]],[supplied,{}]);
  assert.equal(state.rulesVersion,11);assert.equal(state.round,1);
  assert.deepEqual(state.units[0].loadout,kit);assert.equal(state.units[0].affinities.water,6);
  assert.equal(castAvailability(state,state.units[0].id,'maelstrom').available,true);
  assert.equal(affinityTotal(state.units[3].affinities),5);
  supplied.oh_tipi.water=3;kit[0]='water_jet';
  assert.equal(state.units[0].affinities.water,6);assert.equal(state.units[0].loadout[0],'maelstrom');
  assert.deepEqual(restoreSimState(state),state);
});

test('all twenty exchanges preserve both team affinity totals with no automatic income',()=>{
  let state=createSimGame([roster,roster],'frontier:fixed-twenty',undefined,undefined,[high,{}]);
  const initial=fixed(state);let exchanges=0;
  while(state.winner===null){
    state=resolveRound(state,[empty(),empty()]);exchanges++;
    assert.deepEqual(fixed(state),initial);
    assert.deepEqual(restoreSimState(state),state);
    assert.ok(exchanges<=20);
  }
  assert.equal(exchanges,20);assert.equal(state.winner,'draw');
});

test('every nonempty or malformed in-match training request is rejected without state mutation',()=>{
  const state=createSimGame(),before=structuredClone(state),unit=state.units[0];
  for(const training of [[{unitId:unit.id,element:'water'}],null,{},'water',[{unitId:'1-oh_tipi',element:'water'}]]){
    const plan={orders:[],training} as unknown as TeamPlan;
    assert.throws(()=>prepareTeam(state,0,plan),/earned in Story/);
    assert.throws(()=>validatePlan(state,0,plan),/earned in Story/);
    assert.throws(()=>resolveRound(state,[plan,empty()]),/earned in Story/);
    assert.deepEqual(state,before);
  }
  assert.deepEqual(prepareTeam(state,0,{orders:[],training:[]}),state);
  assert.equal(validatePlan(state,0,{orders:[],training:[]}).training,undefined);
  assert.throws(()=>validatePlan(state,0,{orders:[],affinities:{water:6}}),/unknown field/);
});

test('creation and restoration reject missing native points, excess elements and malformed allocations',()=>{
  for(const allocation of [undefined,null,{water:2,fire:3},{water:7,fire:2},{water:3,fire:2,air:1,earth:1},{water:3,fire:2,ice:1},{water:3,fire:2.5}]){
    assert.throws(()=>createSimGame(undefined,undefined,undefined,undefined,[{oh_tipi:allocation} as never,{}]));
    const state=createSimGame();state.units[0].affinities=allocation as AffinityAllocation;
    assert.throws(()=>restoreSimState(state));
  }
  for(const input of [[{}],[{}, {},{}],[null,{}],[{s_wayne:{dark:3,light:2}},{}],[new Date(),{}]])assert.throws(()=>createSimGame(undefined,undefined,undefined,undefined,input as never));
  assert.throws(()=>validateChampionAffinities('oh_tipi',{water:4,fire:2},5),/5 affinity/);
  assert.throws(()=>validateChampionAffinities('missing',{water:3,fire:2}),/Unknown champion/);
  const third=createSimGame(undefined,undefined,undefined,undefined,[{oh_tipi:{water:6,fire:6,air:6}},{}]);
  assert.deepEqual(restoreSimState(third),third);
});

test('learned signatures use frozen affinities in round one, retain the creator discount and consume only borrower slots',()=>{
  const kit=[borrowed.id,'water_jet','ember','mend'];
  const state=createSimGame(undefined,undefined,[{oh_tipi:kit},{}],[[borrowed.id],[]],[{oh_tipi:{water:5,fire:2}},{}]);
  assert.equal(castAvailability(state,state.units[0].id,borrowed.id).cost,5);
  assert.equal(spellAccess('oh_tipi',borrowed.id,state.units[0].affinities,[borrowed.id]).requiredAffinity,5);
  for(const champion of CHAMPIONS){
    const signature=getSignature(champion.id);
    assert.equal(signature.element,champion.element);
    assert.equal(spellCost(champion.id,signature.id,allocateAffinityBudget(champion.id,18)),3);
    assert.equal(spellAccess(champion.id,signature.id).requiredAffinity,3);
    assert.throws(()=>validateLoadout(champion.id,[signature.id,...defaultLoadout(champion.id).slice(1)]),/fixed fifth slot/);
  }
  assert.throws(()=>createSimGame(undefined,undefined,[{oh_tipi:kit},{}],[[],[]],[{oh_tipi:{water:5,fire:2}},{}]),/Story/);
  assert.throws(()=>createSimGame(undefined,undefined,[{oh_tipi:kit},{}],[[borrowed.id],[]]),/Requires 5/);
});

test('equipment changes use existing affinity and cannot erase borrowed spell cooldowns',()=>{
  const state=createSimGame(undefined,undefined,undefined,[[borrowed.id],[]],[{oh_tipi:{water:5,fire:2}},{}]);
  const unit=state.units[0],before=structuredClone(state),kit=[borrowed.id,'water_jet','ember','mend'];
  const prep:TeamPlan={orders:[],loadouts:[{unitId:unit.id,spells:kit}]};
  const projected=prepareTeam(state,0,prep),target=legalCasts(projected,unit.id,undefined,borrowed.id)[0];assert.ok(target);
  const cast=resolveRound(state,[{...prep,orders:[{unitId:unit.id,spellId:borrowed.id,cast:{q:target.q,r:target.r}}]},empty()]);
  assert.deepEqual(state,before);assert.deepEqual(fixed(cast),fixed(state));
  assert.equal(cast.units[0].cooldowns[borrowed.id],3);
  const off=prepareTeam(cast,0,{orders:[],loadouts:[{unitId:unit.id,spells:defaultLoadout(unit.championId)}]});
  assert.equal(off.units[0].cooldowns[borrowed.id],3);assert.deepEqual(restoreSimState(off),off);
  assert.equal(castAvailability(prepareTeam(off,0,prep),unit.id,borrowed.id).available,false);
});

test('loadout persistence preserves earned spells only when the stored character affinity permits them',()=>{
  const kit=['maelstrom','deep_freeze','ember','mend'],input={oh_tipi:kit};
  assert.deepEqual(readLoadouts(input,false,[],high).oh_tipi,kit);
  assert.ok(!readLoadouts(input).oh_tipi.includes('maelstrom'));
  const borrowedKit=[borrowed.id,'water_jet','ember','mend'];
  assert.deepEqual(readLoadouts({oh_tipi:borrowedKit},false,[borrowed.id],high).oh_tipi,borrowedKit);
  assert.ok(!readLoadouts({oh_tipi:borrowedKit},false,[],high).oh_tipi.includes(borrowed.id));
  const kits=practiceLoadouts(roster,high,libraries);
  assert.doesNotThrow(()=>createSimGame([roster,roster],undefined,[kits,kits],[libraries,libraries],[high,high]));
});

test('affinity-scaled damage, range, duration and primary support preserve their bounded spell footprints',()=>{
  const catalogue=JSON.stringify(ALL_SPELLS);
  for(const base of ALL_SPELLS)for(let rank=0;rank<=6;rank++){
    const spell=effectiveSpell('oh_tipi',base.id,{[base.element]:rank});
    assert.ok(Object.isFrozen(spell));
    assert.equal(spell.range,base.range===0?0:base.range+Number(rank>=2)+Number(rank>=5));
    assert.equal(spell.damage,base.damage+(base.damage?Number(rank>=3)+Number(rank>=6):0));
    assert.equal(spell.radius,base.radius);assert.equal(spell.shape,base.shape);
    assert.equal(spell.selfDamage,base.selfDamage);assert.equal(spell.cooldown,base.cooldown);
    for(const channel of ['harmful','friendly','self'] as const)(spell[channel]??[]).forEach((effect,index)=>{
      assert.ok(effect.turns<=3);
      if(['rooted','chilled','blind','concussed'].includes(effect.id))assert.equal(effect.turns,base[channel]![index].turns);
    });
  }
  assert.equal(effectiveSpell('oh_tipi','mend',{light:6}).heal,5);
  assert.equal(effectiveSpell('oh_tipi','bulwark',{earth:6}).friendly!.find(effect=>effect.id==='ward')!.power,5);
  assert.equal(JSON.stringify(ALL_SPELLS),catalogue);
});

test('AI and practice equip earned upgrades without training, keep legal plans and complete restorable matches',()=>{
  for(const policy of [chooseAIPlan,choosePracticePlan]){
    let state=createSimGame([roster,roster],'frontier:v11-fixed-ai',undefined,[libraries,libraries],[high,high]);
    const initial=fixed(state);let exchanges=0;
    while(state.winner===null){
      const before=structuredClone(state),plans:[TeamPlan,TeamPlan]=[policy(state,0),policy(state,1)];
      assert.deepEqual(policy(state,0),plans[0]);assert.deepEqual(state,before);
      assert.equal(plans[0].training,undefined);assert.equal(plans[1].training,undefined);
      assert.deepEqual(validatePlan(state,0,plans[0]),plans[0]);
      if(exchanges===0)assert.ok(plans[0].loadouts?.some(entry=>entry.spells.some(id=>getSpell(id).level===6)));
      state=resolveRound(state,plans);
      assert.deepEqual(fixed(state),initial);assert.deepEqual(restoreSimState(state),state);
      assert.ok(++exchanges<=20);
    }
  }
});
