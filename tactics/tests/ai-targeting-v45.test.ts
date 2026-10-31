import test from 'node:test';
import assert from 'node:assert/strict';
import {chooseTowerRoom,createTowerRun,towerBattleConfig} from '../lib/tower-v23.ts';
import {chooseAIPlan,createTowerBattle,resolveRound,type SimState,type SimUnit} from '../lib/tactics-v22.ts';
import type {Point} from '../lib/game.ts';

function leadShotFixture():{state:SimState;caster:SimUnit;target:SimUnit}{
  const run=chooseTowerRoom(createTowerRun('AI-LEAD-TEST','steezo'),'floor-1-0');
  const state=createTowerBattle(towerBattleConfig(run));
  const caster=state.units.find(unit=>unit.owner===0&&unit.championId==='steezo')!;
  const target=state.units.find(unit=>unit.owner===1&&unit.id==='enemy-0')!;
  for(const cell of state.cells){cell.biome='plain';cell.terrain='plain';cell.height=0;cell.well=false;delete cell.ttl;delete cell.elements;delete cell.reactions;delete cell.ice;delete cell.barrier;}
  for(const unit of state.units)if(unit.id!==caster.id&&unit.id!==target.id)unit.hp=0;
  Object.assign(caster,{q:0,r:0,hp:caster.maxHp,flux:caster.maxFlux,statuses:{rooted:{turns:1,power:1}}});
  caster.cooldowns=Object.fromEntries(caster.loadout.map(id=>[id,0]));
  Object.assign(target,{q:state.boardRadius,r:0,hp:target.maxHp,flux:0,statuses:{},loadout:[],cooldowns:{}});
  return {state,caster,target};
}

test('current AI leads a simultaneous AoE onto an opponent’s plausible movement lane',()=>{
  const {state,caster,target}=leadShotFixture(),before=structuredClone(state);
  const attack=chooseAIPlan(state,0);
  assert.deepEqual(state,before,'forecasting reads public state without mutating the battle');
  assert.deepEqual(chooseAIPlan(state,0),attack,'the same public snapshot gives the same plan');
  assert.equal(attack.orders[0].unitId,caster.id);
  assert.equal(attack.orders[0].spellId,'ember');
  assert.deepEqual(attack.orders[0].cast,{q:5,r:0},'aim at the enemy’s likely four-hex advance, not its empty current hex');
  const flip=({q,r}:Point):Point=>({q:-q,r:-r});
  const mirrored:SimState={...structuredClone(state),units:state.units.map(unit=>({...structuredClone(unit),...flip(unit),owner:(1-unit.owner) as SimUnit['owner']})),cells:state.cells.map(cell=>({...structuredClone(cell),...flip(cell)}))};
  assert.deepEqual(chooseAIPlan(mirrored,1),{orders:attack.orders.map(order=>({...order,...(order.move?{move:flip(order.move)}:{}),...(order.cast?{cast:flip(order.cast)}:{})}))},'rotating the public fight and swapping seats preserves the lead');

  const enemyReply=chooseAIPlan(state,1);
  assert.deepEqual(enemyReply.orders[0].move,{q:5,r:0});
  const result=resolveRound(state,[attack,enemyReply]);
  assert.equal(result.units.find(unit=>unit.id===target.id)?.hp,0,'the lead hits when the public movement choice resolves');
  assert.ok(result.lastResolution.some(event=>event.kind==='damage'&&event.unitId===target.id));
});
