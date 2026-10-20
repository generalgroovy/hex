import test from 'node:test';
import assert from 'node:assert/strict';
import {createTowerRun,chooseTowerRoom,towerRoomChoices,createTowerSession,restoreTowerSession,towerRewardChoices,claimTowerReward,finishTowerBattle,transferTowerSupply,validateTowerRun,type TowerRun} from '../lib/tower-v23.ts';
import {castAvailability,battleSpell,legalCasts,legalMoves,resolveRound,restoreSimState,validatePlan,previewPlan,type SimState,type TeamPlan} from '../lib/tactics-v22.ts';
import {TOWER_CHARMS,TOWER_SCROLLS,towerScrollSpell} from '../lib/tower-supplies-v45.ts';
import {towerPreviewRules} from '../lib/tower-preview-v45.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import {targetImpactPreview} from '../lib/target-impact-v41.ts';
import {projectedVolley} from '../lib/planned-volley-v20.ts';
import type {SimState as ReviewState} from '../lib/tactics-v20.ts';
import {createSharedTowerBattle,validateSharedTowerPlan,sharedActorId,finishSharedTowerBattle} from '../lib/tower-shared-battle-v23.ts';
const point=({q,r}:{q:number;r:number})=>({q,r});
const same=(a:{q:number;r:number},b:{q:number;r:number})=>a.q===b.q&&a.r===b.r;
function fixture(scroll='immolate'){
 const run=chooseTowerRoom(createTowerRun('SUPPLY45'),towerRoomChoices(createTowerRun('SUPPLY45'))[0].id);
 run.party[0].charmId='river-stone';run.party[0].scrollSpellId=scroll;
 const battle=createTowerSession(run).battle!;
 return {run,battle,unit:battle.units[0]};
}
function victory(run:TowerRun,battle:SimState):TowerRun{
 const next=structuredClone(battle);for(const enemy of next.units.filter(unit=>unit.owner===1)){enemy.hp=0;enemy.flux=0;enemy.cooldowns={};enemy.statuses={};delete enemy.guard;}
 return finishTowerBattle(run,resolveRound(next,[{orders:[]},{orders:[]}]));
}
test('new runs offer one bounded supply alongside existing rewards; legacy drafts remain unchanged',()=>{
 const {run,battle}=fixture(),rewardRun=victory(run,battle),choices=towerRewardChoices(rewardRun),item=choices.find(choice=>choice.kind==='charm')!;
 assert.equal(choices.length,3);assert.ok(item);assert.notEqual(choices[0].kind,'charm');
 assert.ok(choices.some(choice=>choice.kind==='train'),'Supplies cannot displace affinity progression');
 const wounded=structuredClone(rewardRun);wounded.party[0].hp=2;assert.deepEqual(new Set(towerRewardChoices(wounded).map(choice=>choice.kind)),new Set(['train','heal','charm']));
 assert.throws(()=>claimTowerReward(rewardRun,item.id),/Choose a fighter/);
 const next=claimTowerReward(rewardRun,item.id,undefined,'companion');
 assert.equal(next.party[1].charmId,item.charmId);assert.equal(next.floor,2);
 assert.deepEqual(restoreTowerSession(createTowerSession(next)).run,next);
 const legacy=structuredClone(rewardRun);delete legacy.suppliesModel;for(const actor of legacy.party){delete actor.charmId;delete actor.scrollSpellId;}
 assert.ok(towerRewardChoices(legacy).every(choice=>!['charm','scroll'].includes(choice.kind)));
 assert.deepEqual(validateTowerRun(legacy),legacy);
});
test('supplies swap existing slots within the party and cannot be moved during battle or forged into a new climb',()=>{
 const {run,battle}=fixture(),rewardRun=victory(run,battle),item=towerRewardChoices(rewardRun).find(choice=>choice.kind==='charm')!;
 let next=claimTowerReward(rewardRun,item.id,undefined,'companion');
 const original=next.party.map(actor=>actor.charmId).sort();
 next=transferTowerSupply(next,'hero','companion','charm');
 assert.deepEqual(next.party.map(actor=>actor.charmId).sort(),original);
 assert.throws(()=>transferTowerSupply(next,'hero','seat-1:hero','charm'),/party member/);
 assert.throws(()=>transferTowerSupply(run,'hero','companion','scroll'),/between rooms/);
 const forged=createTowerRun('FORGED');forged.party[0].scrollSpellId='immolate';assert.throws(()=>validateTowerRun(forged),/starting pair/);
});
test('all four charms grant only their documented opening condition, with native status clocks',()=>{
 for(const item of TOWER_CHARMS){
  const {run}=fixture();run.party[0].charmId=item.id;const battle=createTowerSession(run).battle!,unit=battle.units[0];
  assert.deepEqual(unit.statuses,{[item.status]:{turns:2,power:item.power}});
  assert.equal(unit.maxHp,8);assert.equal(unit.maxFlux,6);
  const next=resolveRound(battle,[{orders:[]},{orders:[]}]);assert.equal(next.units[0].statuses[item.status]?.turns,1);
  assert.deepEqual(restoreSimState(next),next);
 }
});
test('every scroll bypasses affinity, loadout, Concussion, Flux and cooldown at printed strength',()=>{
 for(const id of TOWER_SCROLLS){
  const {battle,unit}=fixture(id);unit.flux=0;unit.statuses.concussed={turns:1,power:1};unit.cooldowns[id]=2;
  assert.deepEqual(castAvailability(battle,unit.id,id,true),{available:true,cost:0});
  assert.deepEqual(battleSpell(battle,unit.id,id,true),towerScrollSpell(id,battle.spellModel));
  assert.ok(legalCasts(battle,unit.id,undefined,id,true).length);
 }
});
test('a scroll is consumed exactly on release; planning and undo do not spend it, and it cannot be reused',()=>{
 const {battle,unit}=fixture();unit.flux=0;const aim=point(legalCasts(battle,unit.id,undefined,'immolate',true)[0]);
 const plan:TeamPlan={orders:[{unitId:unit.id,spellId:'immolate',scroll:true,cast:aim}]};
 validatePlan(battle,0,plan);assert.equal(unit.spentScroll,undefined);
 assert.ok(previewPlan(battle,0,plan).some(line=>line.includes('0 Flux')));
 const next=resolveRound(battle,[plan,{orders:[]}]);
 assert.equal(next.units[0].spentScroll,true);assert.equal(next.units[0].cooldowns.immolate,undefined);
 assert.equal(next.lastResolution.filter(event=>event.kind==='cast'&&event.scroll).length,1);
 assert.deepEqual(restoreSimState(next),next);
 assert.equal(castAvailability(next,unit.id,'immolate',true).available,false);
 assert.throws(()=>validatePlan(next,0,plan),/unused scroll/);
 assert.throws(()=>validatePlan(battle,0,{orders:[...plan.orders,...plan.orders]}),/one order/);
 assert.throws(()=>validatePlan(battle,0,{orders:[{...plan.orders[0],spellId:'mend'}]}),/unused scroll/);
 const broken=structuredClone(next);delete broken.units[0].spentScroll;assert.throws(()=>restoreSimState(broken),/unavailable spell/);
 const duplicate=structuredClone(next);duplicate.lastResolution.push(duplicate.lastResolution.find(event=>event.scroll)!);assert.throws(()=>restoreSimState(duplicate),/only be released once/);
});
test('a blocked move that invalidates scroll reach keeps the scroll and spends no Flux',()=>{
 const {battle,unit}=fixture(),ally=battle.units[1],old=legalCasts(battle,unit.id,undefined,'immolate',true);
 const move=legalMoves(battle,unit.id).find(cell=>legalMoves(battle,ally.id).some(other=>same(cell,other))&&legalCasts(battle,unit.id,cell,'immolate',true).some(aim=>!old.some(oldAim=>same(aim,oldAim))))!;
 assert.ok(move);const aim=legalCasts(battle,unit.id,move,'immolate',true).find(aim=>!old.some(oldAim=>same(aim,oldAim)))!;
 const next=resolveRound(battle,[{orders:[{unitId:unit.id,move:point(move),spellId:'immolate',scroll:true,cast:point(aim)},{unitId:ally.id,move:point(move)}]},{orders:[]}]);
 assert.ok(next.lastResolution.some(event=>event.kind==='fizzle'&&event.unitId===unit.id));
 assert.equal(next.units[0].spentScroll,undefined);assert.equal(next.units[0].flux,unit.maxFlux);
 assert.deepEqual(restoreSimState(next),next);
});
test('native Tower forecasts show the actual free scroll, printed damage and elemental field',()=>{
 const {battle,unit}=fixture(),enemy=battle.units.find(actor=>actor.owner===1)!;
 enemy.q=unit.q+2;enemy.r=unit.r;unit.flux=0;
 const aim=point(enemy),plan:TeamPlan={orders:[{unitId:unit.id,spellId:'immolate',scroll:true,cast:aim}]};
 const options={rules:towerPreviewRules(battle),selectedScroll:true as const},review={...battle,rulesVersion:20} as unknown as ReviewState;
 const volley=projectedVolley(review,0,plan,false,options);assert.equal(volley.casts.length,1);assert.equal(volley.casts[0].spell.damage,towerScrollSpell('immolate',battle.spellModel).damage);
 const impact=targetImpactPreview(review,0,plan,unit.id,'immolate',aim,options)!;assert.ok(impact);assert.ok(impact.targets.some(target=>target.id===enemy.id&&target.damage.max>0));
 const forecast=planningForecast(review,0,plan,unit.id,'immolate',aim,options)!;assert.ok(forecast.groups.some(group=>group.elements.includes('fire')));
 const next=resolveRound(battle,[plan,{orders:[]}]);assert.ok(next.lastResolution.some(event=>event.kind==='cast'&&event.scroll));
});
test('shared fights preserve separate supplies and prevent ordering another owner; spend returns only to its owner',()=>{
 const first=fixture(),second=fixture('mend'),battle=createSharedTowerBattle([{seat:0,run:first.run},{seat:3,run:second.run}]),id=sharedActorId(0,'hero'),unit=battle.units.find(unit=>unit.id===id)!;
 const aim=point(legalCasts(battle,id,undefined,'immolate',true)[0]),plan={orders:[{unitId:id,spellId:'immolate',scroll:true as const,cast:aim}]};
 assert.throws(()=>validateSharedTowerPlan(battle,3,plan),/own fighters/);
 const next=resolveRound(battle,[validateSharedTowerPlan(battle,0,plan),{orders:[]}]);assert.equal(next.units.find(unit=>unit.id===id)!.spentScroll,true);assert.equal(next.units.find(unit=>unit.id===sharedActorId(3,'hero'))!.spentScroll,undefined);
 assert.deepEqual(restoreSimState(next),next);
 for(const enemy of next.units.filter(unit=>unit.owner===1)){enemy.hp=0;enemy.flux=0;enemy.statuses={};enemy.cooldowns={};delete enemy.guard;}
 const won=resolveRound(next,[{orders:[]},{orders:[]}]);
 assert.equal(finishSharedTowerBattle(first.run,won,0).party[0].scrollSpellId,undefined);
 assert.equal(finishSharedTowerBattle(second.run,won,3).party[0].scrollSpellId,'mend');
});
test('intercepted scrolls are spent and their native collision field survives save validation',()=>{
 const {run}=fixture();run.party[1].scrollSpellId='frostbite';const battle=createTowerSession(run).battle!,[fire,water]=battle.units;
 const left=battle.cells.find(cell=>cell.q===-1&&cell.r===0)!,right=battle.cells.find(cell=>cell.q===1&&cell.r===0)!;
 assert.notEqual(left.biome,'ruins');assert.notEqual(right.biome,'ruins');Object.assign(fire,point(left));Object.assign(water,point(right));
 const plan:TeamPlan={orders:[{unitId:fire.id,spellId:'immolate',scroll:true,cast:point(right)},{unitId:water.id,spellId:'frostbite',scroll:true,cast:point(left)}]};
 const next=resolveRound(battle,[plan,{orders:[]}]);assert.ok(next.lastResolution.some(event=>event.kind==='clash'&&event.participants?.includes(fire.id)&&event.participants.includes(water.id)));
 assert.equal(next.units[0].spentScroll,true);assert.equal(next.units[1].spentScroll,true);assert.deepEqual(restoreSimState(next),next);
});
test('retiring a charmed squad before the first shared exchange preserves a valid room snapshot',()=>{
 const first=fixture(),second=fixture(),battle=createSharedTowerBattle([{seat:0,run:first.run},{seat:1,run:second.run}]);
 for(const unit of battle.units.filter(unit=>unit.owner===0&&battle.tower.controllers![unit.id]===0)){
  (battle.retirements??=[]).push({unitId:unit.id,round:1});unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;
 }
 assert.deepEqual(restoreSimState(battle),battle);
});
