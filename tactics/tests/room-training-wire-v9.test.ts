import assert from 'node:assert/strict';
import test from 'node:test';
import {canonicalPlan,planFingerprint} from '../lib/room-plans.ts';

const spells=['ember','mend','stone','water_jet'];
const order={unitId:'0_a',guard:true as const};
const digest=async(value:unknown)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(value)))),byte=>byte.toString(16).padStart(2,'0')).join('');

test('training allocations and loadout rows canonicalize independently while repeated points and spell slots survive',()=>{
  const raw={orders:[{unitId:'0_b',guard:true},order],training:[{unitId:'0_b',element:'water'},{unitId:'0_a',element:'fire'},{unitId:'0_a',element:'earth'},{unitId:'0_a',element:'fire'}],loadouts:[{unitId:'0_b',spells:[...spells].reverse()},{unitId:'0_a',spells}]};
  const before=structuredClone(raw),result=canonicalPlan(raw,9);
  assert.deepEqual(raw,before,'normalizing cannot mutate the browser draft');
  assert.deepEqual(result.orders,[order,{unitId:'0_b',guard:true}]);
  assert.deepEqual(result.training,[{unitId:'0_a',element:'earth'},{unitId:'0_a',element:'fire'},{unitId:'0_a',element:'fire'},{unitId:'0_b',element:'water'}]);
  assert.deepEqual(result.loadouts,[{unitId:'0_a',spells},{unitId:'0_b',spells:[...spells].reverse()}]);
});

test('equivalent allocation order and empty lists retry identically, while point amounts and spell-slot changes do not',async()=>{
  const a=canonicalPlan({orders:[order],training:[{unitId:'0_a',element:'fire'},{unitId:'0_a',element:'earth'}],loadouts:[{unitId:'0_a',spells}]},9);
  const b=canonicalPlan({...a,training:[...a.training!].reverse()},9);
  assert.equal(await planFingerprint(a,9),await planFingerprint(b,9));
  const differentPoints=canonicalPlan({...a,training:[...a.training!,{unitId:'0_a',element:'fire'}]},9);
  const differentSlots=canonicalPlan({...a,loadouts:[{unitId:'0_a',spells:[...spells].reverse()}]},9);
  assert.notEqual(await planFingerprint(a,9),await planFingerprint(differentPoints,9));
  assert.notEqual(await planFingerprint(a,9),await planFingerprint(differentSlots,9));
  assert.deepEqual(canonicalPlan({orders:[],training:[],loadouts:[]},9),{orders:[]});
  assert.equal(await planFingerprint(canonicalPlan({orders:[],training:[],loadouts:[]},9),9),await planFingerprint({orders:[]},9));
});

test('historical wire bytes remain exact and historical plans cannot carry new fields',async()=>{
  const raw={orders:[{unitId:'0_b',guard:true as const},{unitId:'0_a',move:{q:0,r:1}}]};
  const expected={orders:[{unitId:'0_a',move:{q:0,r:1}},{unitId:'0_b',guard:true}]};
  for(const version of [3,4,5,6,7,8] as const){
    assert.deepEqual(canonicalPlan(raw,version),expected);
    assert.equal(await planFingerprint(raw,version),await digest(version===3?expected:{rulesVersion:version,plan:expected}));
    assert.throws(()=>canonicalPlan({...raw,training:[]},version));
    assert.throws(()=>canonicalPlan({...raw,loadouts:[]},version));
  }
});

test('malformed training and kit fields are rejected before any room can seal them',()=>{
  const badTraining=[null,{},[{unitId:'',element:'fire'}],[{unitId:'0_a',element:'ice'}],[{unitId:'0_a',element:'fire',amount:9}],Array.from({length:55},()=>({unitId:'0_a',element:'fire'}))];
  for(const training of badTraining)assert.throws(()=>canonicalPlan({orders:[],training},9));
  const badLoadouts=[null,{},[{unitId:'0_a',spells:spells.slice(1)}],[{unitId:'0_a',spells:['ember','ember','stone','mend']}],[{unitId:'0_a',spells},{unitId:'0_a',spells}],[{unitId:'0_a',spells,extra:true}],[{unitId:'0_a',spells:['ember','mend','stone',null]}]];
  for(const loadouts of badLoadouts)assert.throws(()=>canonicalPlan({orders:[],loadouts},9));
  assert.throws(()=>canonicalPlan({orders:[],affinities:{fire:6}},9));
});
