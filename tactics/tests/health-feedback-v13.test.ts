import test from 'node:test';
import assert from 'node:assert/strict';
import {createSimGame,resolveRound} from '../lib/tactics-v13.ts';
import {actualHealthFeedback} from '../lib/health-feedback-v13.ts';

test('full overheal has no popup; partial overheal reports only recovered HP',()=>{
  for(const hp of [8,7]){
    const before=createSimGame();before.cells=before.cells.map(({q,r})=>({q,r,height:0,biome:'plain',terrain:'plain',well:false}));
    const unit=before.units.find(u=>u.id==='0-oh_tipi')!;unit.hp=hp;
    const after=resolveRound(before,[{orders:[{unitId:unit.id,spellId:'cleansing_tide',cast:{q:unit.q,r:unit.r}}]},{orders:[]}]);
    assert.ok(after.lastResolution.some(event=>event.kind==='heal'&&event.unitId===unit.id&&event.amount===3));
    const feedback=actualHealthFeedback(before,after).get(unit.id);
    if(hp===8)assert.equal(feedback,undefined);else assert.equal(feedback?.label,'+1 HP');
  }
});

test('simultaneous damage and healing produce one actual net health result',()=>{
  const before=createSimGame(),after=structuredClone(before);after.version++;
  const unit=after.units[0];unit.hp=5;
  after.lastResolution=[{kind:'damage',unitId:unit.id,amount:7,text:'Hit'},{kind:'heal',unitId:unit.id,amount:4,text:'Healed'}];
  const feedback=actualHealthFeedback(before,after);
  assert.equal(feedback.size,1);assert.equal(feedback.get(unit.id)?.label,'−3 HP');
  unit.hp=8;
  assert.equal(actualHealthFeedback(before,after).size,0);
});

test('defeat reports remaining HP lost; returning characters do not count as healing',()=>{
  const before=createSimGame(),after=structuredClone(before);after.version++;
  const fallen=after.units[0],returning=after.units[1];
  before.units[0].hp=3;fallen.hp=0;fallen.respawn=3;
  before.units[1].hp=0;before.units[1].respawn=2;returning.hp=8;
  const feedback=actualHealthFeedback(before,after);
  assert.equal(feedback.get(fallen.id)?.label,'−3 HP');assert.equal(feedback.has(returning.id),false);
});

test('feedback uses the final position without mutating state and ignores unmatched snapshots',()=>{
  const before=createSimGame(),after=structuredClone(before);after.version++;after.units[0].hp=4;after.units[0].q=2;after.units[0].r=-1;
  const snapshot=structuredClone({before,after}),feedback=actualHealthFeedback(before,after);
  assert.deepEqual(feedback.get(after.units[0].id)?.point,{q:2,r:-1});assert.deepEqual({before,after},snapshot);
  assert.equal(actualHealthFeedback(undefined,after).size,0);
  assert.equal(actualHealthFeedback(before,before).size,0);
  after.mapId='frontier:OTHER';assert.equal(actualHealthFeedback(before,after).size,0);
});
