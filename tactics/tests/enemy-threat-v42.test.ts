import test from 'node:test';
import assert from 'node:assert/strict';
import * as tower from '../lib/tactics-v22.ts';
import {towerChampion} from '../lib/tower-v23.ts';
import {enemyThreatPreview,enemyThreatReader} from '../lib/enemy-threat-v42.ts';
const key=({q,r}:{q:number;r:number})=>`${q},${r}`;
function fixture(){
  const state=tower.createTowerBattle({id:'enemy-reach',mapId:'THREAT42',allies:[towerChampion('oh_tipi','ally')],enemies:[towerChampion('red_baron','enemy')],learnedSpells:[]});
  return {state,unit:state.units.find(unit=>unit.owner===1)!};
}
test('enemy envelope includes every ready spell footprint after every legal move',()=>{
  const {state,unit}=fixture(),before=JSON.stringify(state),preview=enemyThreatPreview(state,unit.id,tower)!;
  const expected=new Set<string>(),standing=new Set<string>();
  for(const origin of [unit,...tower.legalMoves(state,unit.id)]){
    for(const spell of tower.availableUnitSpellIds(state,unit.id)){
      for(const aim of tower.legalCasts(state,unit.id,origin,spell)){
        for(const cell of tower.spellArea(state,unit.id,spell,aim,origin)){
          expected.add(key(cell));if(key(origin)===key(unit))standing.add(key(cell));
        }
      }
    }
  }
  assert.deepEqual(new Set(preview.attack.map(key)),expected);
  assert.deepEqual(new Set(preview.cast.map(key)),standing);
  assert.ok(preview.attack.length>=preview.cast.length);
  assert.equal(JSON.stringify(state),before);
});
test('Rooted and empty Flux make the public envelope smaller without guessing orders',()=>{
  const {state,unit}=fixture();unit.statuses.rooted={turns:2,power:1};
  const rooted=enemyThreatPreview(state,unit.id,tower)!;
  assert.deepEqual(rooted.move,[{q:unit.q,r:unit.r}]);
  assert.deepEqual(rooted.attack,rooted.cast);
  unit.flux=0;
  const empty=enemyThreatPreview(state,unit.id,tower)!;
  assert.equal(empty.readySpells,0);assert.deepEqual(empty.attack,[]);
});
test('cooldowns exclude spells and per-snapshot reader memoizes repeated hover',()=>{
  const {state,unit}=fixture();
  for(const id of tower.availableUnitSpellIds(state,unit.id))unit.cooldowns[id]=2;
  const read=enemyThreatReader(state,tower);
  assert.equal(read(unit.id),read(unit.id));
  assert.deepEqual(read(unit.id)!.attack,[]);
  unit.hp=0;
  assert.equal(enemyThreatPreview(state,unit.id,tower),null);
  assert.equal(enemyThreatPreview(state,'missing',tower),null);
});
test('geometry cache has the same envelope as exhaustive casting rules',()=>{
  const {state,unit}=fixture();
  const raw=enemyThreatPreview(state,unit.id,tower);
  const fast=enemyThreatPreview(state,unit.id,{...tower,spellGeometry:tower.battleSpell});
  assert.deepEqual(fast,raw);
});
