import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS,getChampion,affinityTotal,allocateAffinityBudget,teamAffinityTotal} from '../lib/roster-v11.ts';
import {getSignature,spellAccess,validateLoadout} from '../lib/spells-v11.ts';
import {createSimGame,restoreSimState,resolveRound,MAX_ROUNDS,type SimState} from '../lib/tactics-v11.ts';
import {choosePracticePlan} from '../lib/practice-v11.ts';
import {STORY_ENCOUNTERS,STORY_PROGRESS_KEY,LEGACY_STORY_PROGRESS_KEY,getStoryEncounter,readStoryProgress,learnedStorySignatures,storyAffinityBudget,storyAffinities,setStoryAffinity,storyTeamAffinities,encounterAffinities,encounterLoadouts,createStoryGame,awardStoryVictory,type StoryProgress} from '../lib/story-v11.ts';

const empty=():StoryProgress=>({format:2,defeated:[],affinities:{}});
const company=['grace_reava','spai_si','haara'];
const progressAt=(wins:number)=>readStoryProgress({format:1,defeated:CHAMPIONS.slice(0,wins).map(champion=>champion.id)});
function terminal(state:SimState,winner:0|1|'draw'=0):SimState {
  return {...state,round:MAX_ROUNDS,version:MAX_ROUNDS+1,winner,scores:winner===0?[16,12]:winner===1?[12,16]:[16,16]};
}

test('legacy story wins migrate into both learned spells and earned affinity without altering the original profile',()=>{
  const legacy={format:1,defeated:['s_wayne','unknown',null,'oh_tipi','oh_tipi',12]},before=structuredClone(legacy);
  const migrated=readStoryProgress(JSON.stringify(legacy));
  assert.deepEqual(migrated,{format:2,defeated:['oh_tipi','s_wayne'],affinities:{}});
  assert.equal(storyAffinityBudget(migrated),7);
  assert.deepEqual(learnedStorySignatures(migrated),['signature_oh_tipi','signature_s_wayne']);
  assert.deepEqual(legacy,before);
  for(const champion of CHAMPIONS)assert.deepEqual(storyAffinities(migrated,champion.id),champion.affinities,'migration leaves earned points unspent');
  assert.equal(STORY_PROGRESS_KEY,'hex-confluence-story-v11');
  assert.equal(LEGACY_STORY_PROGRESS_KEY,'hex-confluence-story-v10');
});

test('story profile parsing bounds malformed data and keeps a damaged allocation from erasing valid victories',()=>{
  for(const value of [null,undefined,false,9,[],{},'{broken','x'.repeat(32769),{format:3,defeated:['oh_tipi']},{format:1,defeated:'oh_tipi'},{format:1,defeated:Array(31).fill('oh_tipi')},{format:1,defeated:['oh_tipi'],game:{}},new Date(),Object.create({format:1,defeated:['oh_tipi']})])assert.deepEqual(readStoryProgress(value),empty());
  const valid=allocateAffinityBudget('oh_tipi',7),profile=readStoryProgress({format:2,defeated:['oh_tipi','s_wayne'],affinities:{oh_tipi:valid,s_wayne:{dark:6,light:2},haara:{light:4},unknown:{fire:6}}});
  assert.deepEqual(profile.defeated,['oh_tipi','s_wayne']);
  assert.deepEqual(profile.affinities,{oh_tipi:valid},'overspending and removing canonical affinities discard only affected builds');
  assert.deepEqual(readStoryProgress({...profile,affinities:[]} ),{...profile,affinities:{}});
  assert.deepEqual(readStoryProgress(JSON.stringify(profile)),profile);
});

test('distinct first victories give every character one point, stop at 18, and never count duplicate or unknown encounters',()=>{
  assert.equal(storyAffinityBudget(empty()),5);
  for(let wins=1;wins<=30;wins++)assert.equal(storyAffinityBudget(progressAt(wins)),Math.min(18,5+wins));
  assert.equal(storyAffinityBudget(readStoryProgress({format:1,defeated:['oh_tipi','oh_tipi','unknown']})),6);
  for(const champion of CHAMPIONS){
    const profile=setStoryAffinity(progressAt(13),champion.id,allocateAffinityBudget(champion.id,18));
    assert.equal(affinityTotal(storyAffinities(profile,champion.id)),18);
  }
});

test('camp permits reassignment of earned affinity while preserving native floors and each character budget',()=>{
  const start=progressAt(3),first=setStoryAffinity(start,'s_wayne',{dark:6,light:2});
  const reassigned=setStoryAffinity(first,'s_wayne',{dark:3,light:4,water:1});
  assert.deepEqual(storyAffinities(reassigned,'s_wayne'),{dark:3,light:4,water:1});
  assert.deepEqual(first.affinities.s_wayne,{dark:6,light:2});
  assert.deepEqual(start.affinities,{});
  for(const invalid of [{dark:2,light:3},{dark:6,light:3},{dark:7,light:1},{dark:3,light:2,water:1,fire:1},{dark:3,light:2,water:0},{dark:3.5,light:2},['dark'],null])assert.throws(()=>setStoryAffinity(start,'s_wayne',invalid));
  assert.throws(()=>setStoryAffinity(start,'unknown',{fire:5}),/Unknown champion/);
  const borrowed=storyAffinities(reassigned,'s_wayne');borrowed.dark=6;
  assert.equal(storyAffinities(reassigned,'s_wayne').dark,3,'readers cannot mutate a saved allocation');
});

test('a team uses only its selected characters and counts invested affinity, excluding banked points',()=>{
  const profile=setStoryAffinity(progressAt(4),'grace_reava',allocateAffinityBudget('grace_reava',8));
  const selected=storyTeamAffinities(profile,company);
  assert.deepEqual(Object.keys(selected),company);
  assert.equal(teamAffinityTotal(company,selected),18);
  assert.equal(storyAffinityBudget(profile),9);
  assert.equal(affinityTotal(selected.grace_reava),8);
  assert.equal(affinityTotal(selected.spai_si),5);
});

test('learning a signature does not bypass its affinity requirement, which persistent training can satisfy',()=>{
  const profile=progressAt(4),library=learnedStorySignatures(profile);
  assert.equal(spellAccess('leaf_hidden','signature_oh_tipi',storyAffinities(profile,'leaf_hidden'),library).unlocked,false);
  const trained=setStoryAffinity(profile,'leaf_hidden',{water:5,earth:3,light:1});
  assert.equal(spellAccess('leaf_hidden','signature_oh_tipi',storyAffinities(trained,'leaf_hidden'),library).unlocked,true);
});

test('each story enemy company has deterministic, visible static difficulty and legal upgraded loadouts',()=>{
  assert.equal(STORY_ENCOUNTERS.length,30);
  assert.equal(new Set(STORY_ENCOUNTERS.map(entry=>getSignature(entry.championId).id)).size,30);
  for(const [index,encounter] of STORY_ENCOUNTERS.entries()){
    const allocations=encounterAffinities(encounter.id),loadouts=encounterLoadouts(encounter.id),expected=5+Math.floor(index/3);
    assert.equal(teamAffinityTotal(encounter.opponents,allocations),expected*3);
    for(const id of encounter.opponents){assert.equal(affinityTotal(allocations[id]),expected);assert.deepEqual(validateLoadout(id,loadouts[id],allocations[id]),loadouts[id]);}
    assert.deepEqual(encounterAffinities(encounter.id),allocations);
  }
  assert.throws(()=>encounterAffinities('unknown'),/Choose a story/);
});

test('story creation freezes the trained player build without scaling enemy strength to the player',()=>{
  const profile=setStoryAffinity(progressAt(7),'grace_reava',allocateAffinityBudget('grace_reava',12)),affinities=storyTeamAffinities(profile,company),library=learnedStorySignatures(profile);
  const initial=createStoryGame('haara',company,{},library,affinities),baseline=createStoryGame('haara',company);
  assert.equal(initial.rulesVersion,11);
  assert.deepEqual(initial.learnedSignatures,[[...library].sort(),[]]);
  assert.deepEqual(initial.units.filter(unit=>unit.owner===1),baseline.units.filter(unit=>unit.owner===1));
  assert.deepEqual(initial.units.find(unit=>unit.id==='0-grace_reava')!.affinities,affinities.grace_reava);
  assert.deepEqual(restoreSimState(initial),initial);
  affinities.grace_reava.water=1;library.push('signature_sai_laas');
  assert.notEqual(initial.units.find(unit=>unit.id==='0-grace_reava')!.affinities.water,1);
  assert.ok(!initial.learnedSignatures[0].includes('signature_sai_laas'));
});

test('story victory awards exactly once, preserves trained allocations and rejects losses, wrong encounters or altered enemy strength',()=>{
  const initial=createStoryGame('oh_tipi',company),win=terminal(initial),expected={format:2,defeated:['oh_tipi'],affinities:{}};
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',win),expected);
  for(const result of [initial,terminal(initial,1),terminal(initial,'draw'),{...win,rulesVersion:10},{...initial,winner:0},{...win,cells:[]}])assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',result),empty());
  assert.deepEqual(awardStoryVictory(empty(),'s_wayne',win),empty());
  assert.deepEqual(awardStoryVictory(empty(),'unknown',win),empty());
  const wrong=createSimGame([company,['oh_tipi','wa_bidi','treevor_mason']],initial.mapId);
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',terminal(wrong)),empty());
  const later=getStoryEncounter('haara'),weaker=createSimGame([company,later.opponents],later.mapId);
  assert.deepEqual(awardStoryVictory(empty(),'haara',terminal(weaker)),empty(),'same encounter with weaker enemy affinities is not its story win');
  const trained=setStoryAffinity(readStoryProgress(expected),'s_wayne',{dark:4,light:2}),before=structuredClone(trained);
  const next=awardStoryVictory(trained,'s_wayne',terminal(createStoryGame('s_wayne',company)));
  assert.deepEqual(next.affinities,trained.affinities);
  assert.equal(storyAffinityBudget(next),7);
  assert.deepEqual(awardStoryVictory(next,'s_wayne',terminal(createStoryGame('s_wayne',company))),next);
  assert.deepEqual(trained,before);
});

test('a complete legal story match keeps affinity fixed and only its final victory earns persistent progress',()=>{
  let state=createStoryGame('oh_tipi',company),rounds=0;
  const initialAffinities=state.units.map(unit=>structuredClone(unit.affinities));
  while(state.winner===null&&rounds<MAX_ROUNDS){
    assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',state),empty());
    state=resolveRound(state,[choosePracticePlan(state,0),choosePracticePlan(state,1)]);
    assert.deepEqual(restoreSimState(state),state);
    assert.deepEqual(state.units.map(unit=>unit.affinities),initialAffinities);
    rounds++;
  }
  assert.equal(state.winner,0);
  assert.ok(rounds>1&&rounds<=MAX_ROUNDS);
  const awarded=awardStoryVictory(empty(),'oh_tipi',state);
  assert.equal(storyAffinityBudget(awarded),6);
  assert.deepEqual(learnedStorySignatures(readStoryProgress(JSON.stringify(awarded))),['signature_oh_tipi']);
  assert.deepEqual(awarded.affinities,{},'new earned point is banked for camp allocation');
});
