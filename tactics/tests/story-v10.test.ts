import assert from 'node:assert/strict';
import test from 'node:test';
import {CHAMPIONS,getChampion} from '../lib/roster-v10.ts';
import {getSignature,spellAccess} from '../lib/spells-v10.ts';
import {normalizeArenaMapId} from '../lib/arena-v7.ts';
import {createSimGame,restoreSimState,resolveRound,MAX_ROUNDS,type SimState} from '../lib/tactics-v10.ts';
import {choosePracticePlan} from '../lib/practice-v10.ts';
import {STORY_ENCOUNTERS,STORY_PROGRESS_KEY,getStoryEncounter,readStoryProgress,learnedStorySignatures,createStoryGame,awardStoryVictory,type StoryProgress} from '../lib/story-v10.ts';

const empty=():StoryProgress=>({format:1,defeated:[]});
const company=['grace_reava','spai_si','haara'];
function terminal(state:SimState,winner:0|1|'draw'=0):SimState {
  return {...state,round:MAX_ROUNDS,version:MAX_ROUNDS+1,winner,scores:winner===0?[16,12]:winner===1?[12,16]:[16,16]};
}

test('every canonical champion has one freely selectable, seeded encounter and a distinct reward',()=>{
  assert.equal(STORY_ENCOUNTERS.length,30);
  assert.equal(new Set(STORY_ENCOUNTERS.map(entry=>entry.mapId)).size,30);
  assert.deepEqual(STORY_ENCOUNTERS.map(entry=>entry.id),CHAMPIONS.map(champion=>champion.id));
  assert.equal(new Set(STORY_ENCOUNTERS.map(entry=>getSignature(entry.championId).id)).size,30);
  for(const encounter of STORY_ENCOUNTERS){
    assert.equal(encounter.id,encounter.championId);
    assert.equal(encounter.opponents[0],encounter.championId);
    assert.equal(new Set(encounter.opponents).size,3);
    for(const id of encounter.opponents)assert.ok(getChampion(id));
    assert.equal(normalizeArenaMapId(encounter.mapId),encounter.mapId);
    assert.ok(encounter.title.length&&encounter.situation.length);
  }
  assert.throws(()=>getStoryEncounter('missing'),/Choose a story/);
});

test('story profile parsing is bounded, canonical and independent of old save formats',()=>{
  for(const value of [null,undefined,false,9,[],{},'{broken','x'.repeat(4097),{format:2,defeated:['oh_tipi']},{format:1,defeated:'oh_tipi'},{format:1,defeated:Array(31).fill('oh_tipi')},{format:1,defeated:['oh_tipi'],game:{}},new Date(),Object.create({format:1,defeated:['oh_tipi']})])assert.deepEqual(readStoryProgress(value),empty());
  const raw={format:1,defeated:['s_wayne','unknown',null,'oh_tipi','oh_tipi',12]};
  assert.deepEqual(readStoryProgress(raw),{format:1,defeated:['oh_tipi','s_wayne']});
  assert.deepEqual(readStoryProgress(JSON.stringify(raw)),readStoryProgress(raw));
  assert.equal(raw.defeated.length,6,'reader does not mutate supplied progress');
  assert.equal(STORY_PROGRESS_KEY,'hex-confluence-story-v10');
});

test('story libraries contain only learned signature ids and never unlock affinity requirements',()=>{
  const progress=readStoryProgress({format:1,defeated:['oh_tipi','wa_bidi']});
  const library=learnedStorySignatures(progress);
  assert.deepEqual(library,['signature_oh_tipi','signature_wa_bidi']);
  assert.equal(spellAccess('leaf_hidden','signature_oh_tipi',undefined,library).unlocked,false);
  assert.equal(spellAccess('leaf_hidden','signature_oh_tipi',{water:5,earth:1,light:1},library).unlocked,true);
  library.push('signature_s_wayne');
  assert.deepEqual(progress.defeated,['oh_tipi','wa_bidi']);
});

test('story creation fixes the enemy company and map without leaking the player library to opponents',()=>{
  const library=['signature_oh_tipi'];
  const initial=createStoryGame('s_wayne',company,{},library);
  assert.equal(initial.rulesVersion,10);
  assert.equal(initial.mapId,getStoryEncounter('s_wayne').mapId);
  assert.deepEqual(initial.units.filter(unit=>unit.owner===1).map(unit=>unit.championId),getStoryEncounter('s_wayne').opponents);
  assert.deepEqual(initial.learnedSignatures,[library,[]]);
  assert.deepEqual(restoreSimState(initial),initial);
  assert.deepEqual(createStoryGame('s_wayne',company,{},library),initial,'replaying uses the same starting terrain and company');
  library.push('signature_s_wayne');
  assert.deepEqual(initial.learnedSignatures[0],['signature_oh_tipi']);
  assert.throws(()=>createStoryGame('unknown',company),/Choose a story/);
});

test('only a valid win against the selected story company and seed awards a signature',()=>{
  const initial=createStoryGame('oh_tipi',company);
  const win=terminal(initial);
  const expected={format:1,defeated:['oh_tipi']};
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',win),expected);
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',initial),empty());
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',terminal(initial,1)),empty());
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',terminal(initial,'draw')),empty());
  assert.deepEqual(awardStoryVictory(empty(),'s_wayne',win),empty());
  assert.deepEqual(awardStoryVictory(empty(),'unknown',win),empty());
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',{...win,rulesVersion:9}),empty());
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',{...initial,winner:0}),empty(),'unfinished score cannot become a victory');
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',{...win,cells:[]}),empty(),'invalid restored result earns nothing');
  const otherCompany=createSimGame([company,['oh_tipi','wa_bidi','treevor_mason']],initial.mapId);
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',terminal(otherCompany)),empty(),'same seed with practice opponents earns nothing');
  const otherSeed=createSimGame([company,getStoryEncounter('oh_tipi').opponents],'frontier:PRACTICE');
  assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',terminal(otherSeed)),empty(),'same opponents on another seed earn nothing');
});

test('a replay reward is idempotent and never mutates prior progress or the completed match',()=>{
  const result=terminal(createStoryGame('oh_tipi',company)),before=structuredClone(result),progress=empty();
  const awarded=awardStoryVictory(progress,'oh_tipi',result);
  assert.deepEqual(awardStoryVictory(awarded,'oh_tipi',result),awarded);
  assert.deepEqual(progress,empty());
  assert.deepEqual(result,before);
  const second=awardStoryVictory(awarded,'s_wayne',terminal(createStoryGame('s_wayne',company)));
  assert.deepEqual(second,{format:1,defeated:['oh_tipi','s_wayne']});
});

test('a complete legal story match restores every round and awards only its final victory',()=>{
  let state=createStoryGame('oh_tipi',company),rounds=0;
  while(state.winner===null&&rounds<MAX_ROUNDS){
    assert.deepEqual(awardStoryVictory(empty(),'oh_tipi',state),empty());
    state=resolveRound(state,[choosePracticePlan(state,0),choosePracticePlan(state,1)]);
    assert.deepEqual(restoreSimState(state),state,`round ${state.round} can resume`);
    rounds++;
  }
  assert.equal(state.winner,0);
  assert.ok(rounds>1&&rounds<=MAX_ROUNDS);
  const awarded=awardStoryVictory(empty(),'oh_tipi',state);
  assert.deepEqual(awarded,{format:1,defeated:['oh_tipi']});
  assert.deepEqual(learnedStorySignatures(readStoryProgress(JSON.stringify(awarded))),['signature_oh_tipi']);
  const replay=createStoryGame('oh_tipi',company,{},learnedStorySignatures(awarded));
  assert.equal(replay.round,1);
  assert.deepEqual(replay.learnedSignatures,[['signature_oh_tipi'],[]]);
});
