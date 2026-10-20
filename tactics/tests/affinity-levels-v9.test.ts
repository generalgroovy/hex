import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS as ORIGINAL_CHAMPIONS} from '../lib/roster-v7.ts';
import {CHAMPIONS,STARTING_AFFINITY_POINTS,MAX_AFFINITY_ELEMENTS,ADVANCED_AFFINITY_THRESHOLD,MAX_AFFINITY_LEVEL,affinityBudget,validateAffinityAllocation,type AffinityAllocation} from '../lib/roster-v9.ts';
import type {Element} from '../lib/game.ts';
import {ALL_SPELLS as OLD_SPELLS,getSpell as oldSpell} from '../lib/spells-v8.ts';
import {defaultLoadout as v4Default} from '../lib/spells-v4.ts';
import {SPELLS,SIGNATURES,ALL_SPELLS,ELEMENT_BRANCHES,ELEMENT_SPELL_LEVELS,ADVANCED_SPELL_IDS,getSpell,getSignature,spellAccess,spellCost,availableSpellIds,validateLoadout,defaultLoadout,repairLoadout} from '../lib/spells-v9.ts';
import {readLoadouts} from '../lib/loadouts-v9.ts';

test('all 30 original characters start with five points across unchanged original element memberships',()=>{
  assert.equal(CHAMPIONS.length,30);
  for(const champion of CHAMPIONS){
    const original=ORIGINAL_CHAMPIONS.find(entry=>entry.id===champion.id)!;
    assert.equal(Object.values(champion.affinities).reduce((sum,points)=>sum+(points??0),0),STARTING_AFFINITY_POINTS);
    assert.ok(Object.keys(champion.affinities).length<=MAX_AFFINITY_ELEMENTS);
    assert.deepEqual(Object.keys(champion.affinities),Object.keys(original.affinities));
    assert.equal(champion.affinities[champion.element],ADVANCED_AFFINITY_THRESHOLD);
    for(const [element,points] of Object.entries(champion.affinities))assert.equal(points,(original.affinities[element as keyof typeof original.affinities]??0)+(element===champion.element?1:0));
    assert.equal(Object.values(original.affinities).reduce((sum,points)=>sum+(points??0),0),4,'historical roster remains unchanged');
    assert.notEqual(champion.affinities,original.affinities,'new roster cannot mutate historical affinity objects');
  }
});

test('all six elements offer six levels and unlock their derived branch at level three',()=>{
  assert.equal(SPELLS.length,48);
  assert.equal(SIGNATURES.length,30);
  assert.equal(SPELLS.filter(spell=>spell.level>=3).length,24);
  assert.deepEqual(ALL_SPELLS.map(spell=>spell.id),OLD_SPELLS.map(spell=>spell.id));
  assert.equal(ELEMENT_BRANCHES.fire,'Lightning');assert.equal(ELEMENT_BRANCHES.water,'Ice');assert.equal(ELEMENT_BRANCHES.earth,'Metal');
  for(const [element,ids] of Object.entries(ADVANCED_SPELL_IDS)){
    assert.equal(ids.length,4);
    assert.deepEqual(ELEMENT_SPELL_LEVELS[element as Element].map(level=>level.length),[2,2,1,1,1,1]);
    assert.equal(new Set(ELEMENT_SPELL_LEVELS[element as Element].flat()).size,8);
    for(const id of ids){const spell=getSpell(id);assert.equal(spell.element,element);assert.ok(spell.level>=3);assert.equal(spell.branch,ELEMENT_BRANCHES[spell.element])}
    for(let level=1;level<=6;level++)for(const id of ELEMENT_SPELL_LEVELS[element as Element][level-1])assert.equal(getSpell(id).level,level);
  }
});

test('all 30 starter kits include the primary branch unlock and obey every spell threshold',()=>{
  for(const champion of CHAMPIONS){
    const starter=defaultLoadout(champion.id);
    assert.deepEqual(validateLoadout(champion.id,starter),starter,champion.id);
    assert.equal(starter.length,4);assert.equal(new Set(starter).size,4);
    assert.ok(starter.some(id=>getSpell(id).element===champion.element&&getSpell(id).level===3));
    for(const spell of SPELLS){
      const expected=spell.level===1||(champion.affinities[spell.element]??0)>=spell.level;
      const access=spellAccess(champion.id,spell.id);
      assert.equal(access.unlocked,expected,`${champion.id}: ${spell.id}`);
      assert.equal(access.requiredAffinity,spell.level===1?0:spell.level);
      assert.equal(access.level,spell.level);assert.equal(access.branch,spell.branch);
      const kit=[spell.id,...SPELLS.filter(candidate=>candidate.id!==spell.id&&spellAccess(champion.id,candidate.id).unlocked).slice(0,3).map(candidate=>candidate.id)];
      if(expected){assert.deepEqual(validateLoadout(champion.id,kit),kit);assert.equal(access.reason,undefined)}
      else {assert.throws(()=>validateLoadout(champion.id,kit),/Requires/);assert.ok(access.reason?.includes(`Requires ${spell.level}`))}
      assert.equal(spellCost(champion.id,spell.id),Math.max(1,spell.cost+((champion.affinities[spell.element]??0)===0?1:(champion.affinities[spell.element]??0)>=2?-1:0)));
    }
  }
});

test('trained affinity overrides unlock all six levels without changing the starting roster or stacking discounts',()=>{
  for(const element of Object.keys(ELEMENT_BRANCHES) as Element[])for(let points=0;points<=MAX_AFFINITY_LEVEL;points++){
    const trained:AffinityAllocation=points?{[element]:points}:{};
    for(const spell of SPELLS.filter(entry=>entry.element===element)){
      assert.equal(spellAccess('oh_tipi',spell.id,trained).unlocked,spell.level===1||points>=spell.level,`${element} ${points}: ${spell.id}`);
      assert.equal(spellCost('oh_tipi',spell.id,trained),Math.max(1,spell.cost+(points===0?1:points>=2?-1:0)));
    }
    assert.deepEqual(validateLoadout('oh_tipi',defaultLoadout('oh_tipi',trained),trained),defaultLoadout('oh_tipi',trained));
  }
  const trained={water:6,fire:2},kit=['frostbite','deep_freeze','rainfall','maelstrom'];
  assert.deepEqual(validateLoadout('oh_tipi',kit,trained),kit);
  assert.deepEqual(repairLoadout('oh_tipi',kit,trained),kit);
  assert.deepEqual(availableSpellIds('oh_tipi',kit,trained),[...kit,'signature_oh_tipi']);
  assert.throws(()=>validateLoadout('oh_tipi',kit),/Requires 4 Water/);
  assert.equal(CHAMPIONS.find(champion=>champion.id==='oh_tipi')!.affinities.water,3);
});

test('every character earns the same budget every two completed rounds and may bank unspent points',()=>{
  assert.deepEqual([1,2,3,4,5,6,7,8].map(affinityBudget),[5,5,6,6,7,7,8,8]);
  for(const round of [0,-1,1.5,NaN,Infinity])assert.throws(()=>affinityBudget(round),/positive whole round/);
  const source={water:3,fire:2},allocation=validateAffinityAllocation(source,affinityBudget(5));
  assert.deepEqual(allocation,source);assert.notEqual(allocation,source);
  assert.equal(affinityBudget(5)-Object.values(allocation).reduce((sum,value)=>sum+(value??0),0),2);
  assert.deepEqual(validateAffinityAllocation({water:6,fire:2},affinityBudget(7)),{water:6,fire:2});
  assert.deepEqual(validateAffinityAllocation({water:3,fire:2,earth:1},affinityBudget(3)),{water:3,fire:2,earth:1});
  assert.deepEqual(validateAffinityAllocation({water:6,fire:6,earth:6},18),{water:6,fire:6,earth:6});
  assert.deepEqual(validateAffinityAllocation({},0),{});
});

test('affinity allocation validation rejects extra elements, excess points and malformed levels',()=>{
  for(const input of [null,[],new Date(),{unknown:1},{water:0},{water:-1},{water:7},{water:1.5},{water:NaN},{water:Infinity},{water:'3'},{water:2,fire:1,air:1,earth:1},{water:6,fire:3}])assert.throws(()=>validateAffinityAllocation(input,8));
  for(const budget of [-1,1.5,NaN,Infinity])assert.throws(()=>validateAffinityAllocation({water:1},budget));
  assert.throws(()=>validateLoadout('oh_tipi',defaultLoadout('oh_tipi'),{water:7}),/whole numbers from 1 to 6/);
});

test('signatures stay fixed and available to their owner independently of advanced spell gates',()=>{
  for(const champion of CHAMPIONS){
    const signature=getSignature(champion.id),access=spellAccess(champion.id,signature.id);
    assert.equal(access.unlocked,true);assert.equal(access.requiredAffinity,0);
    assert.deepEqual(availableSpellIds(champion.id,defaultLoadout(champion.id)),[...defaultLoadout(champion.id),signature.id]);
    assert.throws(()=>validateLoadout(champion.id,[signature.id,...defaultLoadout(champion.id).slice(0,3)]),/fixed slot/);
    const other=CHAMPIONS.find(entry=>entry.id!==champion.id)!;
    assert.equal(spellAccess(other.id,signature.id).unlocked,false);
    assert.equal(spellAccess(champion.id,signature.id,{}).unlocked,true,'signatures do not need an affinity allocation');
  }
  assert.deepEqual(availableSpellIds('treevor_mason',['frostbite','mend','wind_shear','stone']),['mend','stone','signature_treevor_mason']);
});

test('legacy custom loadouts preserve every legal slot and replace only locked spells deterministically',()=>{
  const input={treevor_mason:['frostbite','mend','wind_shear','water_jet'],oh_tipi:['frostbite','mend','fire_lance','deep_freeze']};
  const original=structuredClone(input),migrated=readLoadouts(input);
  assert.deepEqual(input,original,'migration does not mutate the prior save');
  assert.deepEqual(migrated.treevor_mason,['stone','mend','shatter','water_jet']);
  assert.deepEqual(migrated.oh_tipi,['frostbite','mend','water_jet','ember'],'Water3 keeps Frostbite; level4 spells wait for training');
  assert.deepEqual(readLoadouts(input),migrated,'replayable migration');
  assert.deepEqual(readLoadouts(migrated),migrated,'migration is idempotent');
  for(const champion of CHAMPIONS)assert.deepEqual(validateLoadout(champion.id,migrated[champion.id]),migrated[champion.id]);
});

test('damaged individual slots cannot erase unrelated legal choices or introduce signatures',()=>{
  const kit=repairLoadout('treevor_mason',['not_a_spell','mend','mend','signature_treevor_mason']);
  assert.equal(kit[1],'mend');assert.equal(new Set(kit).size,4);assert.ok(kit.every(id=>!id.startsWith('signature_')));
  assert.deepEqual(validateLoadout('treevor_mason',kit),kit);
  assert.deepEqual(repairLoadout('treevor_mason',null),defaultLoadout('treevor_mason'));
  const empty=readLoadouts(null);
  assert.equal(Object.keys(empty).length,30);
  assert.deepEqual(empty.oh_tipi,defaultLoadout('oh_tipi'));
  const legacy=readLoadouts({oh_tipi:v4Default('oh_tipi')},true);
  assert.deepEqual(legacy.oh_tipi,defaultLoadout('oh_tipi'));
});

test('advanced branches retain established effects, with one bounded Lightning Lance tradeoff',()=>{
  const lightning=getSpell('fire_lance');
  assert.equal(lightning.damage,1);assert.equal(lightning.pierce,true);assert.equal(lightning.bonus,'wet');assert.equal(lightning.bonusDamage,1);
  assert.match(lightning.description,/already Wet/);assert.match(lightning.description,/Leaves Fire/);
  for(const spell of ALL_SPELLS){
    const {name,description,level,branch,...current}=spell;
    const {name:oldName,description:oldDescription,...old}=oldSpell(spell.id);
    void name;void description;void level;void branch;void oldName;void oldDescription;
    if(spell.id==='fire_lance')assert.deepEqual(current,{...old,damage:1,pierce:true,bonus:'wet',bonusDamage:1});
    else assert.deepEqual(current,old,`${spell.id} keeps its existing combat properties`);
  }
});
