import assert from 'node:assert/strict';
import test from 'node:test';
import {INHABITANT_SPECIES,INHABITANT_ELEMENTS,getInhabitantSpecies,encounterSpecies,storyInhabitants,inhabitantIntents,inhabitantPulses,validateInhabitants} from '../lib/inhabitants-v12.ts';
import {COMBINATIONS,combinationFor,combinationMask} from '../lib/combinations-v12.ts';
import {CHAMPIONS} from '../lib/roster-v11.ts';
import {ARENA_STARTS,generateArena} from '../lib/arena-v7.ts';
import {createStoryGame,STORY_ENCOUNTERS,STORY_PROGRESS_KEY,LEGACY_STORY_PROGRESS_KEY,readStoryProgress,awardStoryVictory,storyAffinityBudget,storyAffinities,setStoryAffinity,learnedStorySignatures} from '../lib/story-v12.ts';
import {createSimGame,restoreSimState,resolveRound,MAX_ROUNDS,type SimState} from '../lib/tactics-v12.ts';
import {choosePracticePlan} from '../lib/practice-v12.ts';
const roster=['oh_tipi','wa_bidi','treevor_mason'];
const distance=(a:{q:number;r:number},b:{q:number;r:number})=>Math.max(Math.abs(a.q-b.q),Math.abs(a.r-b.r),Math.abs(a.q+a.r-b.q-b.r));
const pointKey=(point:{q:number;r:number})=>`${point.q},${point.r}`;
const empty=()=>readStoryProgress(null);
const win=(state:SimState):SimState=>({...state,round:MAX_ROUNDS,version:MAX_ROUNDS+1,winner:0,scores:[16,12]});

test('all 63 elemental subsets have a named inhabitant with authored identity and an exact field',()=>{
 assert.equal(INHABITANT_SPECIES.length,63);
 assert.deepEqual([...INHABITANT_SPECIES.map(species=>species.mask)].sort((a,b)=>a-b),Array.from({length:63},(_,i)=>i+1));
 assert.equal(new Set(INHABITANT_SPECIES.map(species=>species.name)).size,63);
 assert.equal(new Set(INHABITANT_SPECIES.map(species=>species.kind)).size,63);
 assert.equal(new Set(INHABITANT_SPECIES.map(species=>species.desire)).size,63);
 assert.equal(new Set(INHABITANT_SPECIES.map(species=>species.family)).size,13);
 assert.deepEqual([1,2,3,4,5,6].map(size=>INHABITANT_SPECIES.filter(species=>species.elements.length===size).length),[6,15,20,15,6,1]);
 for(const species of INHABITANT_SPECIES){assert.equal(combinationMask(species.elements),species.mask);assert.equal(combinationFor(species.elements)?.mask,species.mask);assert.ok(INHABITANT_ELEMENTS.includes(species.counterElement));assert.equal(getInhabitantSpecies(species.id),species);}
 assert.equal(COMBINATIONS.length,63);assert.throws(()=>getInhabitantSpecies('unknown'),/Unknown/);
});

test('existing 30 champion encounters cover every inhabitant exactly once with increasing group size',()=>{
 assert.equal(STORY_ENCOUNTERS.length,30);assert.equal(CHAMPIONS.length,30);
 const seen:string[]=[];
 for(const [index,encounter] of STORY_ENCOUNTERS.entries()){
  const species=encounterSpecies(encounter.id);assert.equal(species.length,index<3?1:index<24?2:3);seen.push(...species.map(entry=>entry.id));
  assert.ok(encounter.relationship.startsWith(CHAMPIONS[index].name));
  assert.ok(species.every(entry=>encounter.relationship.includes(entry.name)),'each intro connects its champion to every local inhabitant');
  assert.ok(encounter.relationship.length<200,'encounter introduction stays concise');
 }
 assert.equal(seen.length,63);assert.equal(new Set(seen).size,63);assert.deepEqual(seen,INHABITANT_SPECIES.map(species=>species.id));
 assert.deepEqual(encounterSpecies('missing'),[]);
});

test('all authored placements are legal, spawn-safe, separated and deterministic independent of cell order',()=>{
 for(const encounter of STORY_ENCOUNTERS){
  const cells=generateArena(encounter.mapId),before=JSON.stringify(cells),inhabitants=storyInhabitants(encounter.mapId,cells);
  assert.deepEqual(storyInhabitants(encounter.mapId,[...cells].reverse()),inhabitants);
  for(const [index,inhabitant] of inhabitants.entries()){
   const cell=cells.find(cell=>pointKey(cell)===pointKey(inhabitant));assert.ok(cell&&!cell.well&&cell.biome!=='ruins');
   assert.ok(ARENA_STARTS.flat().every(start=>distance(start,inhabitant)>=3));
   assert.ok(inhabitants.slice(index+1).every(other=>distance(other,inhabitant)>=3));
  }
  assert.equal(JSON.stringify(cells),before);
 }
 assert.deepEqual(storyInhabitants('frontier:WELLSPRING',generateArena()),[]);
});

test('every public intention is bounded, follows its tell, alternates with rest and never changes the input',()=>{
 for(const encounter of STORY_ENCOUNTERS){
  const cells=generateArena(encounter.mapId),inhabitants=storyInhabitants(encounter.mapId,cells),initial=JSON.stringify({cells,inhabitants});
  for(let round=1;round<=MAX_ROUNDS;round++){
   const state={mapId:encounter.mapId,cells,inhabitants,round},intents=inhabitantIntents(state),next=inhabitantIntents({...state,round:round+1});
   assert.deepEqual(inhabitantIntents({...state,inhabitants:[...inhabitants].reverse()}),intents,'public intentions use canonical creature order');
   assert.deepEqual(inhabitantPulses(state),intents.filter(intent=>intent.phase==='pulse'));
   for(const [index,intent] of intents.entries()){
    assert.ok(intent.area.length>=1&&intent.area.length<=7);assert.equal(new Set(intent.area.map(pointKey)).size,intent.area.length);
    assert.ok(intent.area.every(point=>cells.some(cell=>pointKey(cell)===pointKey(point)&&cell.biome!=='ruins')));
    assert.ok(intent.area.every(point=>ARENA_STARTS.flat().every(start=>pointKey(point)!==pointKey(start))),'no forced first-turn spawn exposure');
    assert.notEqual(next[index].phase,intent.phase);assert.deepEqual(next[index].area,intent.area);
    if(intent.phase==='pulse'){assert.ok(intent.tell.includes(intent.counterElement));assert.ok(intent.tell.includes(`${intent.area.length} hexes`));}else assert.ok(intent.tell.includes('next turn'));
   }
  }
  assert.equal(JSON.stringify({cells,inhabitants}),initial);
 }
});

test('restoration accepts only canonical story identities and perches; field changes cannot move a perch',()=>{
 const encounter=STORY_ENCOUNTERS[29],cells=generateArena(encounter.mapId),inhabitants=storyInhabitants(encounter.mapId,cells);
 assert.deepEqual(validateInhabitants(JSON.parse(JSON.stringify(inhabitants)),encounter.mapId,1,cells),inhabitants);
 assert.deepEqual(validateInhabitants(inhabitants,encounter.mapId,12,cells.map(cell=>({...cell,terrain:'fire',barrier:1}))),inhabitants);
 for(const invalid of [null,{},[],[...inhabitants,inhabitants[0]],inhabitants.slice(1),[...inhabitants].reverse(),inhabitants.map((entry,i)=>i?entry:{...entry,q:entry.q+1}),inhabitants.map((entry,i)=>i?entry:{...entry,speciesId:'inhabitant-1'}),inhabitants.map((entry,i)=>i?entry:{...entry,phase:'pulse'})])assert.throws(()=>validateInhabitants(invalid,encounter.mapId,1,cells));
 assert.throws(()=>validateInhabitants(inhabitants,'frontier:WELLSPRING',1,cells));assert.throws(()=>validateInhabitants(inhabitants,encounter.mapId,0,cells));
 assert.deepEqual(validateInhabitants([],'frontier:WELLSPRING',1,generateArena()),[]);
});

test('all story games carry their inhabitants through strict state restoration without adding player units',()=>{
 for(const encounter of STORY_ENCOUNTERS){const state=createStoryGame(encounter.id,roster);assert.equal(state.rulesVersion,12);assert.equal(state.units.length,6);assert.deepEqual(state.inhabitants,storyInhabitants(state.mapId,state.cells));assert.deepEqual(restoreSimState(state),state);}
 assert.equal(createSimGame().inhabitants,undefined);
});

test('a public pulse enters the same field batch, emits feedback, then rests next turn',()=>{
 const initial=createStoryGame('oh_tipi',roster),intent=inhabitantPulses(initial)[0];assert.ok(intent);
 const next=resolveRound(initial,[{orders:[]},{orders:[]}]);
 assert.ok(next.lastResolution.some(event=>event.kind==='inhabitant'&&event.speciesId===intent.id&&event.text.includes('releases')));
 for(const point of intent.area){const cell=next.cells.find(cell=>pointKey(cell)===pointKey(point))!;assert.ok(cell.elements?.includes('water'));}
 assert.equal(inhabitantPulses(next).length,0);assert.deepEqual(restoreSimState(next),next);
 const resting=resolveRound(next,[{orders:[]},{orders:[]}]);assert.ok(!resting.lastResolution.some(event=>event.kind==='inhabitant'));assert.deepEqual(restoreSimState(resting),resting);
});

test('either team can interrupt the announced release with its visible counter element',()=>{
 for(const owner of [0,1] as const){
  const initial=createStoryGame('oh_tipi',roster),intent=inhabitantPulses(initial)[0];
  const caster=initial.units.find(unit=>unit.owner===owner&&unit.affinities.earth)!;assert.ok(caster);
  caster.q=intent.anchor.q;caster.r=intent.anchor.r;caster.loadout=['stone',...caster.loadout.filter(id=>id!=='stone').slice(0,3)];
  const plans:[{orders:any[]},{orders:any[]}]=[{orders:[]},{orders:[]}];plans[owner].orders=[{unitId:caster.id,spellId:'stone',cast:{...intent.anchor}}];
  const result=resolveRound(initial,plans);
  assert.ok(result.lastResolution.some(event=>event.kind==='inhabitant'&&event.speciesId===intent.id&&event.text.includes('interrupted')));
  for(const point of intent.area.filter(point=>pointKey(point)!==pointKey(intent.anchor))){const cell=result.cells.find(cell=>pointKey(cell)===pointKey(point))!;assert.equal(cell.ttl,undefined,'interrupted creature adds no fields elsewhere');}
  assert.deepEqual(restoreSimState(result),result);
 }
});

test('story profiles retain the v11 storage key, victories, trained builds and signature rewards',()=>{
 assert.equal(STORY_PROGRESS_KEY,'hex-confluence-story-v11');assert.equal(LEGACY_STORY_PROGRESS_KEY,'hex-confluence-story-v10');
 const existing=setStoryAffinity(readStoryProgress({format:1,defeated:['oh_tipi']}),'s_wayne',{dark:4,light:2});
 assert.deepEqual(readStoryProgress(JSON.stringify(existing)),existing);assert.deepEqual(storyAffinities(existing,'s_wayne'),{dark:4,light:2});
 const awarded=awardStoryVictory(existing,'s_wayne',win(createStoryGame('s_wayne',roster)));
 assert.deepEqual(awarded.affinities,existing.affinities);assert.equal(storyAffinityBudget(awarded),7);assert.ok(learnedStorySignatures(awarded).includes('signature_s_wayne'));
 assert.deepEqual(awardStoryVictory(awarded,'s_wayne',win(createStoryGame('s_wayne',roster))),awarded);
});

test('a victory cannot omit or relocate the encounter inhabitants to earn a story reward',()=>{
 const initial=createStoryGame('oh_tipi',roster),terminal=win(initial);
 assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',terminal).defeated,['oh_tipi']);
 for(const changed of [{...terminal,inhabitants:undefined},{...terminal,inhabitants:[]},{...terminal,inhabitants:terminal.inhabitants!.map(entry=>({...entry,q:entry.q+1}))}])assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',changed),empty());
});

test('a complete legal inhabited encounter keeps fixed affinities and restores after every resolution',()=>{
 let state=createStoryGame('oh_tipi',['grace_reava','spai_si','haara']),rounds=0;const affinities=state.units.map(unit=>structuredClone(unit.affinities));
 while(state.winner===null&&rounds<MAX_ROUNDS){state=resolveRound(state,[choosePracticePlan(state,0),choosePracticePlan(state,1)]);assert.deepEqual(restoreSimState(state),state);assert.deepEqual(state.units.map(unit=>unit.affinities),affinities);rounds++;}
 assert.notEqual(state.winner,null);assert.ok(rounds>=2&&rounds<=MAX_ROUNDS);assert.ok(state.inhabitants?.length);
 const profile=awardStoryVictory(empty(),'oh_tipi',state);assert.equal(profile.defeated.length,state.winner===0?1:0);
});
