import test from 'node:test';
import assert from 'node:assert/strict';
import {fieldChanges} from '../lib/field-change-v44.ts';
import {consequenceExplanation,prioritizedPhaseEvents,actorConsequenceEvents} from '../lib/round-explanation-v44.ts';
import {previewField,type SimCell,type SimState,type SimEvent} from '../lib/tactics-v20.ts';
import {createTowerRun,chooseTowerRoom,towerBattleConfig} from '../lib/tower-v23.ts';
import {createTowerBattle} from '../lib/tactics-v22.ts';
import {targetImpactPreview} from '../lib/target-impact-v41.ts';

const cell=(q=0,terrain='plain'):SimCell=>({q,r:0,height:0,well:false,biome:'plain',terrain});
test('terrain explanation names exact replacement, counts cells and does not stack the old recipe',()=>{
 const before=[cell(0,'steam'),cell(1,'steam'),cell(2,'plain')];
 const after=before.map((tile,index)=>index===2?tile:previewField(tile,['earth']));
 const changes=fieldChanges(before,after);
 assert.equal(changes.length,1);
 assert.equal(changes[0].before,'Steam');assert.equal(changes[0].after,'Hot Spring');assert.equal(changes[0].count,2);
 assert.match(changes[0].previousRule!,/Halves/);assert.doesNotMatch(changes[0].rule,/Halves/);
 assert.match(changes[0].rule,/Heals/);assert.match(changes[0].rule,/either team/);
 assert.deepEqual(fieldChanges(before,before),[]);
});
test('freeze is a visible change even when the ingredient set stays water',()=>{
 const before=cell(0,'water'),after=previewField(before,['water'],true);
 assert.equal(fieldChanges([before],[after])[0].after,'Ice');
 assert.match(fieldChanges([before],[after])[0].rule,/last connected/);
});
test('damage explanation retains aggregate protection and never assigns net damage to individual casters',()=>{
 const state={units:[]} as Pick<SimState,'units'>;
 const lines=consequenceExplanation(state,{kind:'damage',text:'Target takes 3.',amount:3,breakdown:{sources:[{kind:'spell',spellId:'ember',amount:3},{kind:'spell',spellId:'water_jet',amount:2}],prevented:2,total:3}});
 assert.deepEqual(lines,['3 damage · Ember','2 damage · Water Jet','2 damage prevented in total','3 damage after protection']);
 const legacy={kind:'damage',text:'Recorded old damage.',amount:3} as SimEvent;
 assert.deepEqual(consequenceExplanation(state,legacy),[legacy.text]);
});
test('healing is explicitly before the HP cap, and full protection is still explained',()=>{
 const state={units:[]} as Pick<SimState,'units'>;
 assert.match(consequenceExplanation(state,{kind:'heal',text:'Healing.',amount:5,breakdown:{sources:[{kind:'field',amount:1},{kind:'spell',spellId:'mend',amount:5}],prevented:1,total:5}}).at(-1)!,/before the health cap/);
 assert.match(consequenceExplanation(state,{kind:'damage',text:'Blocked.',amount:0,breakdown:{sources:[{kind:'spell',spellId:'ember',amount:2}],prevented:2,total:0}}).at(-1)!,/^0 damage after protection/);
});
test('drain and recoil remain distinct from a spell hit in the causal report',()=>{
 const state={units:[]} as Pick<SimState,'units'>;
 const drain=consequenceExplanation(state,{kind:'heal',text:'Drain.',amount:1,breakdown:{sources:[{kind:'drain',spellId:'reap',amount:1}],prevented:0,total:1}});
 const recoil=consequenceExplanation(state,{kind:'damage',text:'Recoil.',amount:1,breakdown:{sources:[{kind:'recoil',spellId:'ember',amount:1}],prevented:0,total:1}});
 assert.equal(drain[0],'1 healing · Drain · Reap');
 assert.equal(recoil[0],'1 damage · Recoil · Ember');
});
test('phase highlights surface a collision and failed order ahead of repeated guards without mutating the ledger',()=>{
 const events:SimEvent[]=[{kind:'guard',text:'Guard'},{kind:'cast',text:'Cast'},{kind:'fizzle',text:'Landing invalidated cast'},{kind:'clash',text:'Steam',participants:['hero']}];
 const copy=JSON.stringify(events);
 assert.deepEqual(prioritizedPhaseEvents(events).slice(0,2).map(event=>event.kind),['clash','fizzle']);
 assert.equal(JSON.stringify(events),copy);
 assert.deepEqual(actorConsequenceEvents({lastResolution:events} as SimState,'hero').map(event=>event.kind),['clash']);
});
test('actual legal aiming exposes terrain conversion from the known volley without enemy orders',()=>{
 const tower=createTowerBattle(towerBattleConfig(chooseTowerRoom(createTowerRun('EXPLAIN44','steam'),'floor-1-0')));
 const state={...tower,rulesVersion:20} as unknown as SimState,hero=state.units.find(unit=>unit.id==='hero')!;
 Object.assign(hero,{q:-2,r:0});
 for(const tile of state.cells)Object.assign(tile,{terrain:tile.q===0&&tile.r===0?'fire':'plain',height:0,biome:'plain',well:false});
 const preview=targetImpactPreview(state,0,{orders:[]},hero.id,'water_jet',{q:0,r:0});
 assert.ok(preview&&!preview.blocked);
 assert.equal(preview.conditional,true);
 assert.ok(preview.fieldChanges?.some(change=>change.before==='Fire'&&change.after==='Steam'));
});
