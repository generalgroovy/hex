import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import {CHAMPIONS,getChampion} from '../lib/roster-v10.ts';
import {defaultLoadout,validateLoadout} from '../lib/spells-v10.ts';
import {createSimGame,restoreSimState,resolveRound,prepareTeam,validatePlan,type SimState} from '../lib/tactics-v10.ts';
import {readLoadouts} from '../lib/loadouts-v10.ts';
import {arenaSeed,normalizeArenaMapId} from '../lib/arena-v7.ts';
import {practiceLoadouts} from '../lib/practice-v10.ts';
import {STORY_PROGRESS_KEY,getStoryEncounter,readStoryProgress,learnedStorySignatures,createStoryGame,awardStoryVictory} from '../lib/story-v10.ts';

// Execute the shipped handlers/effects with real game rules and an isolated
// browser-storage boundary. Layout and real browser rendering are checked separately.
const source=ts.createSourceFile('TacticsGame.tsx',readFileSync(new URL('../app/TacticsGameV10.tsx',import.meta.url),'utf8'),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
const handlers=new Map<string,string>(),effects=new Map<string,string>();
const transpile=(code:string)=>ts.transpileModule(code,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.None}}).outputText;
function visit(node:ts.Node){
  if(ts.isFunctionDeclaration(node)&&node.name)handlers.set(node.name.text,transpile(node.getText(source)));
  if(ts.isCallExpression(node)&&ts.isIdentifier(node.expression)&&node.expression.text==='useEffect'){
    const body=node.arguments[0]?.getText(source)??'';
    if(body.includes('const requestedSeed='))effects.set('initialize',transpile(`const effect=${body};`));
    if(body.includes('awardStoryVictory('))effects.set('award',transpile(`const effect=${body};`));
  }
  ts.forEachChild(node,visit);
}
visit(source);
const playedCompany=['grace_reava','spai_si','haara'];
const SAVE_KEY='confluence-tactics-v10';
function won(game:SimState):SimState{return {...game,round:20,version:21,winner:0,scores:[16,12]};}

function harness(initial=createStoryGame('oh_tipi',playedCompany)){
  const stored=new Map<string,string>(),writes:{key:string;value:string}[]=[];
  let rejectWrites=false;
  const empty={orders:[]};
  const env:Record<string,any>={
    game:initial,gameRef:{current:initial},plan:empty,planHistory:[],screen:'camp',mode:'story',
    roster:['oh_tipi','wa_bidi','treevor_mason'],loadouts:readLoadouts(null),loadoutsReady:true,
    storyId:'oh_tipi',activeStory:null,storyProgress:readStoryProgress(null),learnedSignatures:[],
    busy:false,requestBusy:{current:false},firstCompany:null,joining:false,selectedMapId:null,
    error:'',notice:'',storageWarning:'',hotSeat:0,sealedLocal:null,handoff:false,seat:0,
    timer:{current:null},audio:{current:null},activeSession:{current:null},
    EMPTY:empty,SAVE_KEY,STORY_PROGRESS_KEY,CHAMPIONS,RIVAL:['s_wayne','leaf_hidden','red_baron'],
    defaultLoadout,getChampion,readLoadouts,createSimGame,restoreSimState,resolveRound,validatePlan,
    createStoryGame,getStoryEncounter,readStoryProgress,learnedStorySignatures,awardStoryVictory,
    arenaSeed,normalizeArenaMapId,practiceLoadouts,freshMapSeed:()=> 'STORY-TEST',
    alive:(unit:SimState['units'][number])=>unit.hp>0&&unit.respawn===undefined,
    location:{search:''},window:{scrollTo:()=>{}},resetRemote:()=>{},
    localStorage:{
      getItem:(key:string)=>stored.get(key)??null,
      setItem:(key:string,value:string)=>{if(rejectWrites)throw new Error('Storage unavailable');stored.set(key,value);writes.push({key,value});},
    },
  };
  for(const name of ['StoryProgress','LoadoutsReady','Saved','V9Saved','V8Saved','V7Saved','OldSaved','V4Saved','V5Saved','V6Saved','Name','Sound','Loadouts','Notice','Error','StorageWarning','StoryId','ActiveStory','Mode','Game','Plan','HotSeat','SealedLocal','Handoff','BattleLibrary','MapSeed','Previous','PlanHistory','Selected','FocusRequest','Kind','SpellId','Inspect','HoverAim','Screen','FirstCompany','Roster','RecruitSlot','Code','Joining','Session']){
    const field=name.charAt(0).toLowerCase()+name.slice(1);
    env[`set${name}`]=(value:unknown)=>{env[field]=typeof value==='function'?value(env[field]):value;};
  }
  function call(name:string,...args:unknown[]):any{
    const js=handlers.get(name);assert.ok(js,`actual ${name} handler is present`);
    return new Function(...Object.keys(env),`${js};return ${name};`)(...Object.values(env))(...args);
  }
  function effect(name:string){
    const js=effects.get(name);assert.ok(js,`actual ${name} effect is present`);
    const result=new Function(...Object.keys(env),`${js};return effect;`)(...Object.values(env))();
    env.learnedSignatures=learnedStorySignatures(env.storyProgress);
    return result;
  }
  for(const name of ['companyLoadouts','installGame','selectUnit'])env[name]=(...args:unknown[])=>call(name,...args);
  function save(game=initial,activeStory='oh_tipi',mode='story'){
    const value=JSON.stringify({game,mode,plan:empty,hotSeat:0,handoff:false,sealedLocal:null,activeStory});
    stored.set(SAVE_KEY,value);return value;
  }
  return {env,stored,writes,call,effect,save,rejectStorageWrites:()=>{rejectWrites=true;}};
}

test('Story launch uses the selected encounter and player library even when the ordinary map seed is invalid',async()=>{
  const h=harness();h.env.storyId='s_wayne';h.env.learnedSignatures=['signature_oh_tipi'];
  h.env.roster=[...playedCompany];h.env.selectedMapId=null;
  await h.call('launch');
  assert.equal(h.env.activeStory,'s_wayne');assert.equal(h.env.screen,'battle');
  assert.equal(h.env.game.mapId,getStoryEncounter('s_wayne').mapId);
  assert.deepEqual(h.env.game.units.filter((unit:SimState['units'][number])=>unit.owner===0).map((unit:SimState['units'][number])=>unit.championId),playedCompany);
  assert.deepEqual(h.env.game.learnedSignatures,[['signature_oh_tipi'],[]]);
  assert.deepEqual(restoreSimState(h.env.game),h.env.game);assert.equal(h.env.error,'');
});

test('Resume preserves the played story company, encounter and library despite stale camp selection',()=>{
  const state=createStoryGame('s_wayne',playedCompany,{},['signature_oh_tipi']),h=harness();
  h.save(state,'s_wayne');h.env.mode='practice';h.call('resume');
  assert.equal(h.env.mode,'story');assert.equal(h.env.storyId,'s_wayne');assert.equal(h.env.activeStory,'s_wayne');
  assert.deepEqual(h.env.game,state);assert.equal(h.env.screen,'battle');assert.equal(h.env.error,'');
  assert.notDeepEqual(h.env.roster,playedCompany,'camp selection is deliberately stale in this regression');
});

test('Resume rejects mismatched story identity and leaves the saved payload intact',()=>{
  const h=harness(),initial=structuredClone(h.env.game),payload=h.save(createStoryGame('s_wayne',playedCompany),'oh_tipi');
  h.call('resume');
  assert.match(h.env.error,/Saved story encounter is inconsistent.*Saved data has been kept/);
  assert.equal(h.env.screen,'camp');assert.deepEqual(h.env.game,initial);assert.equal(h.stored.get(SAVE_KEY),payload);
});

test('story retry uses the actual played team and repairs borrowed spells at starting affinity',async()=>{
  let state=createStoryGame('oh_tipi',playedCompany,{},['signature_spai_si']);
  while(state.round<5)state=resolveRound(state,[{orders:[]},{orders:[]}]);
  const caster=state.units.find(unit=>unit.owner===0&&unit.championId==='grace_reava')!;
  const borrowedKit=['signature_spai_si','gust','water_jet','mend'];
  state=prepareTeam(state,0,{orders:[],training:[{unitId:caster.id,element:'air'},{unitId:caster.id,element:'air'}],loadouts:[{unitId:caster.id,spells:borrowedKit}]});
  const h=harness(won(state));h.env.activeStory='oh_tipi';h.env.learnedSignatures=['signature_oh_tipi','signature_spai_si'];
  await h.call('rematch');
  const replay=h.env.game as SimState;
  assert.equal(replay.round,1);assert.equal(replay.winner,null);assert.equal(replay.mapId,state.mapId);
  assert.deepEqual(replay.units.filter(unit=>unit.owner===0).map(unit=>unit.championId),playedCompany);
  const restoredCaster=replay.units.find(unit=>unit.id===caster.id)!;
  assert.equal(restoredCaster.affinities.air,3);assert.ok(!restoredCaster.loadout.includes('signature_spai_si'));
  assert.deepEqual(restoredCaster.loadout.slice(1),borrowedKit.slice(1),'still legal slots survive repair');
  assert.deepEqual(replay.learnedSignatures,[['signature_oh_tipi','signature_spai_si'],[]]);
  assert.deepEqual(validateLoadout(caster.championId,restoredCaster.loadout,restoredCaster.affinities,replay.learnedSignatures[0]),restoredCaster.loadout);
  assert.deepEqual(restoreSimState(replay),replay);
});

test('practice, online and hotseat results cannot award story progress even with a matching story map',()=>{
  for(const mode of ['practice','online','hotseat']){
    const h=harness(won(createStoryGame('oh_tipi',playedCompany)));h.env.activeStory='oh_tipi';h.env.mode=mode;
    h.effect('award');assert.deepEqual(h.env.storyProgress,{format:1,defeated:[]});assert.equal(h.writes.length,0);
  }
  const h=harness(won(createStoryGame('oh_tipi',playedCompany)));h.env.activeStory=null;
  h.effect('award');assert.equal(h.writes.length,0);
});

test('story victory is persisted once and remains usable in the tab when storage rejects writes',()=>{
  const h=harness(won(createStoryGame('oh_tipi',playedCompany)));h.env.activeStory='oh_tipi';
  h.effect('award');assert.deepEqual(h.env.learnedSignatures,['signature_oh_tipi']);
  assert.deepEqual(readStoryProgress(h.stored.get(STORY_PROGRESS_KEY)),{format:1,defeated:['oh_tipi']});
  h.effect('award');assert.equal(h.writes.length,1);
  const unavailable=harness(won(createStoryGame('oh_tipi',playedCompany)));unavailable.env.activeStory='oh_tipi';unavailable.rejectStorageWrites();
  unavailable.effect('award');assert.deepEqual(unavailable.env.learnedSignatures,['signature_oh_tipi']);
  assert.match(unavailable.env.storageWarning,/browser storage is unavailable/);
});

test('corrupt story JSON cannot interrupt initialization of independent saves, name or loadouts',()=>{
  const h=harness();h.env.loadoutsReady=false;
  h.stored.set(STORY_PROGRESS_KEY,'{broken');h.stored.set(SAVE_KEY,'existing match');h.stored.set('confluence-tactics-v9','old match');
  h.stored.set('confluence-name','Mira');h.stored.set('confluence-sound','on');
  const kit=['mend','ember','water_jet','cleansing_tide'];h.stored.set('confluence-loadouts-v10',JSON.stringify({oh_tipi:kit}));
  h.effect('initialize');
  assert.deepEqual(h.env.storyProgress,{format:1,defeated:[]});assert.equal(h.env.loadoutsReady,true);
  assert.equal(h.env.saved,true);assert.equal(h.env.v9Saved,true);assert.equal(h.env.name,'Mira');assert.equal(h.env.sound,true);
  assert.deepEqual(h.env.loadouts.oh_tipi,kit);assert.equal(h.stored.get(STORY_PROGRESS_KEY),'{broken');
});
