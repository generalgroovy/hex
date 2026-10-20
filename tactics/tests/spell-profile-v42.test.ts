import test from 'node:test';
import assert from 'node:assert/strict';
import {towerChampion} from '../lib/tower-v23.ts';
import * as tower from '../lib/tactics-v22.ts';
import * as story from '../lib/tactics-v20.ts';
import * as arena from '../lib/tactics-v18.ts';
import {spellArea as presentedArea} from '../lib/tactics-v16.ts';
import {ALL_SPELLS,effectiveSpell,getSpell} from '../lib/spells-v20.ts';
import {CURRENT_SPELL_MODEL,profileSpell,spellAtCell,spellProfileBands,PRECISION_SPELLS,forceOrigin,hasCentreBonus} from '../lib/spell-profile-v42.ts';
import {knownForceAt} from '../lib/displacement-impact-v42.ts';
import {targetImpactPreview} from '../lib/target-impact-v41.ts';
const at=({q,r}:{q:number;r:number})=>({q,r});
function fixture(championId='red_baron',loadout?:string[]){
 const caster=towerChampion(championId,'caster');if(loadout)caster.loadout=loadout;
 const state=tower.createTowerBattle({id:'focused',mapId:'FOCUSED-42',allies:[caster,towerChampion('oh_tipi','friend')],enemies:[towerChampion('treevor_mason','centre'),towerChampion('oll_i','inner'),towerChampion('jan_wicked','rim')],learnedSpells:[]});
 for(const cell of state.cells){Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false});delete cell.ttl;delete cell.elements;delete cell.reactions;delete cell.ice;delete cell.barrier;}
 for(const [id,point] of Object.entries({caster:{q:-3,r:0},friend:{q:-3,r:2},centre:{q:0,r:0},inner:{q:1,r:0},rim:{q:2,r:0}}))Object.assign(state.units.find(unit=>unit.id===id)!,point);
 return state;
}
const view=(state:tower.SimState)=>({...state,rulesVersion:20}) as unknown as story.SimState;
const damage=(state:{lastResolution:tower.SimEvent[]},id:string)=>state.lastResolution.filter(event=>event.unitId===id&&event.kind==='damage').reduce((sum,event)=>sum+(event.amount??0),0);

test('most catalog spells have radius two or more while deliberate shapes keep identity',()=>{
 const large=ALL_SPELLS.filter(spell=>profileSpell(spell,'focused').radius>=2);
 assert.ok(large.length>ALL_SPELLS.length/2);assert.equal(large.length,102);
 for(const spell of ALL_SPELLS){
  const source=JSON.stringify(spell),focused=profileSpell(spell,'focused');
  assert.equal(JSON.stringify(spell),source);
  assert.equal(profileSpell(spell,undefined),spell,'No gate means no silent rules migration');
  assert.equal(profileSpell(focused,'focused'),focused,'Profiling cannot grow a footprint twice');
  if(spell.range===0||PRECISION_SPELLS.has(spell.id)||!['hex','burst'].includes(spell.shape))assert.equal(focused,spell);
 }
});

test('centre, inner and rim direct damage agree across Tower, Story, Arena, presentation and preview',()=>{
 const state=fixture(),plan=tower.validatePlan(state,0,{orders:[{unitId:'caster',spellId:'ember',cast:{q:0,r:0}}]});
 const before=JSON.stringify(state),native=tower.spellArea(state,'caster','ember',{q:0,r:0});
 assert.equal(native.length,19);assert.deepEqual(story.spellArea(view(state),'caster','ember',{q:0,r:0}),native);
 assert.deepEqual(arena.spellArea({...state,rulesVersion:18} as unknown as arena.SimState,'caster','ember',{q:0,r:0}),native);
 assert.deepEqual(presentedArea({...state,rulesVersion:16} as never,'caster','ember',{q:0,r:0}),native);
 const prediction=targetImpactPreview(view(state),0,plan,'caster')!;
 for(const resolved of [tower.resolveRound(state,[plan,{orders:[]}]),story.resolveRound(view(state),[plan,{orders:[]}]),arena.resolveRound({...state,rulesVersion:18} as unknown as arena.SimState,[plan,{orders:[]}])]){
  assert.deepEqual(['centre','inner','rim'].map(id=>damage(resolved,id)),[3,2,0],'4/3/1 raw damage minus known Guard');
  for(const id of ['centre','inner','rim'])assert.equal(prediction.targets.find(target=>target.id===id)!.damage.min,damage(resolved,id));
  assert.equal(resolved.lastResolution.find(event=>event.kind==='damage'&&event.unitId==='centre')!.critical,true);
  assert.ok(resolved.lastResolution.filter(event=>event.kind==='damage'&&event.unitId!=='centre').every(event=>event.critical===undefined));
 }
 assert.equal(JSON.stringify(state),before);
});

test('outer direct control is removed, but centre and inner control retain the one-round cap',()=>{
 const state=fixture('treevor_mason'),plan=tower.validatePlan(state,0,{orders:[{unitId:'caster',spellId:'grasping_roots',cast:{q:0,r:0}}]});
 const next=tower.resolveRound(state,[plan,{orders:[]}]);
 assert.equal(next.units.find(unit=>unit.id==='centre')!.statuses.rooted?.turns,1);
 assert.equal(next.units.find(unit=>unit.id==='inner')!.statuses.rooted?.turns,1);
 assert.equal(next.units.find(unit=>unit.id==='rim')!.statuses.rooted,undefined);
 const preview=targetImpactPreview(view(state),0,plan,'caster')!;
 assert.ok(preview.targets.find(target=>target.id==='centre')!.statuses.includes('Rooted'));
 assert.ok(!preview.targets.find(target=>target.id==='rim')!.statuses.includes('Rooted'));
});

test('healing and status bands use the same deterministic profile without multiplying capped control',()=>{
 const mend=profileSpell(effectiveSpell('s_wayne','mend',{dark:3,light:2}),'focused');
 const bands=spellProfileBands(mend)!;assert.deepEqual([bands.centre.heal,bands.inner.heal,bands.rim.heal],[4,3,1]);
 const clarity=profileSpell({...getSpell('clear_sight'),friendly:[{id:'clarity' as const,turns:1,power:1}]},'focused');
 assert.equal(spellAtCell(clarity,{q:0,r:0},{q:0,r:0}).friendly![0].turns,2);
 assert.equal(spellAtCell(clarity,{q:0,r:0},{q:2,r:0}).friendly![0].turns,1);
 const root=profileSpell({...getSpell('grasping_roots'),damage:0},'focused');
 assert.equal(spellAtCell(root,{q:0,r:0},{q:0,r:0}).harmful!.find(status=>status.id==='rooted')!.turns,1);
});

test('actual healing uses centre, inner and rim values and marks only the centre critical',()=>{
 const state=fixture('s_wayne',['mend','radiant_bolt','siphon','veil']);
 Object.assign(state.units.find(unit=>unit.id==='caster')!,{q:2,r:0,hp:2});
 Object.assign(state.units.find(unit=>unit.id==='friend')!,{q:1,r:0,hp:2});
 Object.assign(state.units.find(unit=>unit.id==='centre')!,{owner:0,hp:2});
 Object.assign(state.units.find(unit=>unit.id==='inner')!,{q:5,r:-3});
 Object.assign(state.units.find(unit=>unit.id==='rim')!,{q:5,r:-2});
 const plan=tower.validatePlan(state,0,{orders:[{unitId:'caster',spellId:'mend',cast:{q:0,r:0}}]});
 const next=tower.resolveRound(state,[plan,{orders:[]}]);
 const heals=['centre','friend','caster'].map(id=>next.lastResolution.find(event=>event.kind==='heal'&&event.unitId===id)!);
 assert.deepEqual(heals.map(event=>event.amount),[4,3,1]);assert.equal(heals[0].critical,true);
 assert.ok(heals.slice(1).every(event=>event.critical===undefined));
});

test('mitigation that absorbs the entire centre bonus does not produce a false critical popup',()=>{
 const state=fixture();
 for(const cell of state.cells.filter(cell=>Math.abs(cell.q)+Math.abs(cell.r)<4))Object.assign(cell,tower.previewField(cell,['water']));
 const next=tower.resolveRound(state,[{orders:[{unitId:'caster',spellId:'ember',cast:{q:0,r:0}}]},{orders:[]}]);
 const hit=next.lastResolution.find(event=>event.kind==='damage'&&event.unitId==='centre')!;
 assert.equal(hit.amount,1,'Steam halves 4 to 2, then Guard absorbs 1');
 assert.equal(hit.critical,undefined,'Without the centre bonus, 3 also rounds to 2 in Steam');
});

test('new native states opt in, while legacy saved battles and replay contacts retain old rules',()=>{
 const config={id:'save-test',mapId:'SAVE-42',allies:[towerChampion('red_baron','fire'),towerChampion('oh_tipi','water')],enemies:[towerChampion('treevor_mason','foe')],learnedSpells:[]};
 for(const focused of [false,true]){
  const state=tower.createTowerBattle(config);if(focused)state.spellModel='focused';else delete state.spellModel;
  const restored=tower.restoreSimState(JSON.parse(JSON.stringify(state)));
  assert.equal(restored.spellModel,focused?'focused':undefined);
  const unit=state.units[0],target=tower.legalCasts(state,unit.id,undefined,'ember').find(cell=>cell.q!==unit.q||cell.r!==unit.r)!;
  const plan={orders:[{unitId:unit.id,spellId:'ember',cast:at(target)}]},next=tower.resolveRound(state,[plan,{orders:[]}]);
  assert.deepEqual(tower.restoreSimState(JSON.parse(JSON.stringify(next))),next);
  assert.equal(tower.spellArea(state,unit.id,'ember',target).length>=2,focused);
 }
 assert.equal(arena.createSimGame().spellModel,CURRENT_SPELL_MODEL);
 assert.throws(()=>tower.restoreSimState({...tower.createTowerBattle(config),spellModel:'surprise'}),/Unknown spell area rules/);
});


test('widened hex forces preserve caster-relative push and pull, including the centre',()=>{
 const origin={q:-3,r:0},target={q:0,r:0};
 for(const spell of ALL_SPELLS.filter(spell=>spell.shape==='hex'&&spell.push)){
  const focused=profileSpell(spell,'focused');
  assert.deepEqual(forceOrigin(focused,origin,target),origin,spell.name);
  assert.deepEqual(knownForceAt(target,[{spell:focused,origin,target,area:[target]}]),{q:spell.push,r:0},spell.name);
 }
 const burst=profileSpell({...getSpell('gust'),id:'existing-burst',shape:'burst',radius:2},'focused');
 assert.deepEqual(forceOrigin(burst,origin,target),target,'Existing radial force remains aim-relative');
 assert.deepEqual(knownForceAt(target,[{spell:burst,origin,target,area:[target]}]),{q:0,r:0});
 for(const guard of [false,true]){
  const state=fixture('dr_apex');state.units=state.units.filter(unit=>['caster','centre'].includes(unit.id));
  const plan={orders:[{unitId:'caster',spellId:'signature_dr_apex',cast:target}]};
  const enemy={orders:guard?[]:[{unitId:'centre',spellId:'cauterize',cast:target}]};
  const preview=targetImpactPreview(view(state),0,plan,'caster')!.targets.find(unit=>unit.id==='centre')!.displacement!;
  const expected=guard?target:{q:-1,r:0};
  assert.deepEqual((guard?preview.withGuard:preview.withoutGuard).landing,expected);
  for(const next of [tower.resolveRound(state,[plan,enemy]),story.resolveRound(view(state),[plan,enemy]),arena.resolveRound({...state,rulesVersion:18} as unknown as arena.SimState,[plan,enemy])]){
   assert.deepEqual(at(next.units.find(unit=>unit.id==='centre')!),expected,'Native resolvers and exact force preview agree');
  }
 }
 const capped=profileSpell({...getSpell('grasping_roots'),damage:0},'focused');assert.equal(hasCentreBonus(capped),false);
});

test('focused AI takes a clean central firing position without guessing hidden movement',()=>{
 const state=fixture();state.units=state.units.filter(unit=>['caster','centre'].includes(unit.id));
 const caster=state.units[0],enemy=state.units[1];Object.assign(caster,{q:-2,r:0,cooldowns:Object.fromEntries(caster.loadout.filter(id=>id!=='ember').map(id=>[id,3]))});
 enemy.statuses.rooted={turns:1,power:1};
 for(const [rules,rulesVersion] of [[tower,22],[story,20],[arena,18]] as const){
  const current={...state,rulesVersion} as never,before=JSON.stringify(current),plan=rules.chooseAIPlan(current,0),action=plan.orders[0];
  assert.ok(action.move,'A public rooted target allows a clean firing angle');assert.deepEqual(action.cast,at(enemy));
  assert.equal(rules.distance(action.move!,enemy),3);assert.equal(JSON.stringify(current),before);
  assert.ok(!rules.spellArea(current,caster.id,'ember',action.cast!,action.move).some(cell=>cell.q===action.move!.q&&cell.r===action.move!.r));
 }
 const legacy={...state};delete legacy.spellModel;assert.equal(tower.chooseAIPlan(legacy,0).orders[0].move,undefined,'Legacy position preference remains unchanged');
});


test('rim falloff halves each active base-plus-conditional total once across all damage readers',()=>{
 const state=fixture(),victim=state.units.find(unit=>unit.id==='centre')!,cell=state.cells.find(cell=>cell.q===0&&cell.r===0)!;
 for(const id of ['creature_spell:creature-black_squall','creature_spell:creature-fire-cinder','backdraft']){
  const spell=profileSpell(getSpell(id),'focused'),rim=spellAtCell(spell,{q:0,r:0},{q:2,r:0});
  for(const active of [false,true])for(const guard of [false,true]){
   const marked={...victim,statuses:active?{[spell.bonus!]:{turns:1,power:1}}:{}};
   const raw=spell.damage+(active?(spell.bonusDamage??0):0),expected=Math.max(0,Math.max(1,Math.floor(raw/2))-(guard?1:0));
   for(const rules of [tower,story,arena])assert.equal(rules.volleyDamage(cell,marked,[rim],guard),expected,`${id}: active=${active}, guard=${guard}`);
  }
 }
 const squall=spellAtCell(profileSpell(getSpell('creature_spell:creature-black_squall'),'focused'),{q:0,r:0},{q:2,r:0});
 assert.equal(squall.damage,1);assert.equal(squall.bonusDamage,0,'The conditional 1+1 total stays 1 at the rim, not 1+1 again');
});
