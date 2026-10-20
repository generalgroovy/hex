import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import {CHAMPIONS,affinityTotal,allocateAffinityBudget,getChampion,type AffinityAllocation} from '../lib/roster-v13.ts';
import {availableSpellIds,defaultLoadout,repairLoadout,validateLoadout} from '../lib/spells-v16.ts';
import {castAvailability,createSimGame,restoreSimState,resolveRound,validatePlan,type SimState} from '../lib/tactics-v16.ts';
import {readLoadouts} from '../lib/loadouts-v16.ts';
import {arenaSeed,normalizeArenaMapId} from '../lib/arena-v7.ts';
import {practiceLoadouts} from '../lib/practice-v16.ts';
import {STORY_ENCOUNTERS,STORY_PROGRESS_KEY,LEGACY_STORY_PROGRESS_KEY,getStoryEncounter,readStoryProgress,learnedStorySignatures,createStoryGame,awardStoryVictory,setStoryAffinity,storyAffinityBudget,storyAffinities,storyTeamAffinities,type StoryProgress} from '../lib/story-v16.ts';

// Execute the component's actual handlers against real progression and combat
// rules. Storage/network boundaries are isolated; browser layout is tested separately.
const source=ts.createSourceFile('TacticsGame.tsx',readFileSync(new URL('../app/TacticsGame.tsx',import.meta.url),'utf8'),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
const handlers=new Map<string,string>(),effects=new Map<string,string>();
const transpile=(code:string)=>ts.transpileModule(code,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.None}}).outputText;
function visit(node:ts.Node){
  if(ts.isFunctionDeclaration(node)&&node.name)handlers.set(node.name.text,transpile(node.getText(source)));
  if(ts.isCallExpression(node)&&ts.isIdentifier(node.expression)&&node.expression.text==='useEffect'){
    const body=node.arguments[0]?.getText(source)??'';
    if(body.includes('const requestedSeed='))effects.set('initialize',transpile(`const effect=${body};`));
    if(body.includes('awardStoryVictory('))effects.set('award',transpile(`const effect=${body};`));
    if(body.includes("localStorage.setItem('confluence-loadouts-v16'"))effects.set('saveKits',transpile(`const effect=${body};`));
  }
  ts.forEachChild(node,visit);
}
visit(source);
const ownRoster=['oh_tipi','wa_bidi','treevor_mason'];
const rivalRoster=['s_wayne','leaf_hidden','red_baron'];
const SAVE_KEY='confluence-tactics-v16';
const earned=(victories=3):StoryProgress=>readStoryProgress({format:1,defeated:STORY_ENCOUNTERS.slice(0,victories).map(encounter=>encounter.id)});
const won=(state:SimState):SimState=>{const result:SimState={...structuredClone(state),round:20,version:21,winner:0,scores:[0,0]};for(const unit of result.units.filter(unit=>unit.owner===1)){unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;delete unit.respawn;}return result;};

function harness(initial=createStoryGame('oh_tipi',ownRoster)){
  const stored=new Map<string,string>(),writes:{key:string;value:string}[]=[],requests:{path:string;init:RequestInit;body:Record<string,any>}[]=[];
  let rejectWrites=false;
  const empty={orders:[]},noop=()=>{};
  const env:Record<string,any>={setNotebook:()=>{},
    game:initial,gameRef:{current:initial},plan:empty,planHistory:[],screen:'camp',mode:'story',
    roster:[...ownRoster],loadouts:readLoadouts(null),loadoutsReady:true,
    storyId:'oh_tipi',activeStory:null,storyProgress:readStoryProgress(null),learnedSignatures:[],
    busy:false,requestBusy:{current:false},firstCompany:null,joining:false,selectedMapId:'frontier:CLIENT-V11',
    error:'',notice:'',storageWarning:'',hotSeat:0,sealedLocal:null,handoff:false,seat:0,
    resolving:false,reviewing:false,resolutionPhase:'move',resolutionRun:0,passAfterResolution:{current:false},
    timer:{current:null},audio:{current:null},activeSession:{current:null},epoch:{current:0},revision:{current:-1},match:{current:''},
    name:'Mira',matchKind:'casual',code:'23456789ABCD',room:null,
    EMPTY:empty,SAVE_KEY,STORY_PROGRESS_KEY,CHAMPIONS,RIVAL:rivalRoster,
    availableSpellIds,castAvailability,defaultLoadout,repairLoadout,getChampion,readLoadouts,createSimGame,restoreSimState,resolveRound,validatePlan,
    createStoryGame,getStoryEncounter,readStoryProgress,learnedStorySignatures,awardStoryVictory,
    setStoryAffinity,storyAffinityBudget,storyAffinities,storyTeamAffinities,affinityTotal,allocateAffinityBudget,
    arenaSeed,normalizeArenaMapId,practiceLoadouts,freshMapSeed:()=> 'CLIENT-V11',
    alive:(unit:SimState['units'][number])=>unit.hp>0&&unit.respawn===undefined,
    location:{search:''},history:{replaceState:noop},window:{scrollTo:noop},
    readSeat:()=>null,saveSeat:noop,reportPersistence:noop,
    sessions:()=>({getPendingJoin:()=>null,clearPendingJoin:noop}),
    acceptRoom:(room:unknown)=>{env.room=room;},
    fetch:async(path:string,init:RequestInit)=>{
      const body=JSON.parse(init.body as string);requests.push({path,init,body});
      return {ok:true,status:200,json:async()=>({code:'23456789ABCD',token:'a'.repeat(64),seat:0,room:{code:'23456789ABCD',version:1,status:'waiting'}})};
    },
    localStorage:{
      getItem:(key:string)=>stored.get(key)??null,
      setItem:(key:string,value:string)=>{if(rejectWrites)throw new Error('Storage unavailable');stored.set(key,value);writes.push({key,value});},
    },
  };
  for(const name of ['StoryProgress','LoadoutsReady','Saved','V15Saved','V14Saved','V13Saved','V12Saved','V11Saved','V10Saved','V9Saved','V8Saved','V7Saved','OldSaved','V4Saved','V5Saved','V6Saved','Name','Sound','Loadouts','Notice','Error','StorageWarning','StoryId','ActiveStory','Mode','Game','Plan','HotSeat','SealedLocal','Handoff','Notebook','BattleLibrary','MapSeed','Previous','PlanHistory','Selected','FocusRequest','Kind','SpellId','Inspect','HoverAim','Screen','FirstCompany','Roster','RecruitSlot','Code','Joining','Session','Room','Busy','Connected','Resolving','Reviewing','ResolutionPhase','ResolutionRun']){
    const field=name.charAt(0).toLowerCase()+name.slice(1);
    env[`set${name}`]=(value:unknown)=>{env[field]=typeof value==='function'?value(env[field]):value;};
  }
  function derived(){
    env.learnedSignatures=learnedStorySignatures(env.storyProgress);
    env.campAffinities=storyTeamAffinities(env.storyProgress,CHAMPIONS.map(champion=>champion.id));
  }
  function call(name:string,...args:unknown[]):any{
    derived();const js=handlers.get(name);assert.ok(js,`actual ${name} handler is present`);
    return new Function(...Object.keys(env),`${js};return ${name};`)(...Object.values(env))(...args);
  }
  function effect(name:string){
    derived();const js=effects.get(name);assert.ok(js,`actual ${name} effect is present`);
    const result=new Function(...Object.keys(env),`${js};return effect;`)(...Object.values(env))();derived();return result;
  }
  for(const name of ['companyLoadouts','installGame','selectUnit','resetRemote','current','validSession','responseData','normalizeCode'])env[name]=(...args:unknown[])=>call(name,...args);
  return {env,stored,writes,requests,call,effect,rejectStorageWrites:()=>{rejectWrites=true;}};
}

test('character selection chooses a ready spell while preserving an existing queued choice',()=>{
  const state=createSimGame([ownRoster,rivalRoster]),unit=state.units[0];
  const choices=availableSpellIds(unit.championId,unit.loadout,unit.affinities,state.learnedSignatures[unit.owner]);
  unit.cooldowns[choices[0]]=2;
  const ready=choices.find(id=>castAvailability(state,unit.id,id).available);
  assert.ok(ready);assert.notEqual(ready,choices[0],'fixture has a recovering first spell and a ready alternative');
  const h=harness(state);h.env.hoverAim={q:1,r:0};h.call('selectUnit',unit.id);
  assert.equal(h.env.spellId,ready);assert.equal(h.env.kind,'move');assert.equal(h.env.hoverAim,null);
  const queued=choices.at(-1)!;
  h.call('selectUnit',unit.id,state,{orders:[{unitId:unit.id,spellId:queued,cast:{q:unit.q,r:unit.r}}]});
  assert.equal(h.env.spellId,queued);assert.equal(h.env.kind,'cast','reviewing an order retains its selected spell');
  for(const id of choices)unit.cooldowns[id]=2;
  h.call('selectUnit',unit.id,state,{orders:[]});
  assert.equal(h.env.spellId,unit.loadout[0],'with no ready cast the equipped spell remains inspectable');
});

test('camp affinity edits persist and immediately repair an equipped spell when its affinity is lowered',()=>{
  const h=harness();h.env.storyProgress=earned();
  h.call('updateAffinity','oh_tipi',{water:6,fire:2});
  assert.deepEqual(storyAffinities(h.env.storyProgress,'oh_tipi'),{water:6,fire:2});
  assert.deepEqual(readStoryProgress(h.stored.get(STORY_PROGRESS_KEY)),h.env.storyProgress);
  h.env.loadouts.oh_tipi=['maelstrom','deep_freeze','ember','cleansing_tide'];
  h.call('updateAffinity','oh_tipi',{water:3,fire:2});h.effect('saveKits');
  assert.ok(!h.env.loadouts.oh_tipi.includes('maelstrom'));assert.ok(!h.env.loadouts.oh_tipi.includes('deep_freeze'));
  assert.deepEqual(h.env.loadouts.oh_tipi.slice(2),['ember','cleansing_tide']);
  assert.deepEqual(validateLoadout('oh_tipi',h.env.loadouts.oh_tipi,{water:3,fire:2},h.env.learnedSignatures),h.env.loadouts.oh_tipi);
  assert.deepEqual(JSON.parse(h.stored.get('confluence-loadouts-v16')!).oh_tipi,h.env.loadouts.oh_tipi);
  assert.match(h.env.notice,/above your affinity was replaced/);assert.equal(h.env.error,'');
});

test('unearned camp changes are atomic and storage failure retains valid progress and repaired kits in the tab',()=>{
  const h=harness(),before=structuredClone({profile:h.env.storyProgress,kits:h.env.loadouts});
  h.call('updateAffinity','oh_tipi',{water:4,fire:2});
  assert.deepEqual(h.env.storyProgress,before.profile);assert.deepEqual(h.env.loadouts,before.kits);assert.equal(h.writes.length,0);
  assert.match(h.env.error,/5 affinity/);
  h.env.storyProgress=earned();h.rejectStorageWrites();h.call('updateAffinity','oh_tipi',{water:6,fire:2});
  assert.equal(storyAffinities(h.env.storyProgress,'oh_tipi').water,6);assert.match(h.env.storageWarning,/available in this tab/);
});

test('story launch carries saved earned affinities and an advanced kit into round one',async()=>{
  const h=harness();h.env.storyProgress=setStoryAffinity(earned(),'oh_tipi',{water:6,fire:2});
  h.env.storyId='haara';h.env.selectedMapId=null;h.env.loadouts.oh_tipi=['maelstrom','deep_freeze','ember','cleansing_tide'];
  h.env.resolving=true;h.env.reviewing=true;h.env.passAfterResolution.current=true;
  await h.call('launch');
  const state=h.env.game as SimState;
  assert.equal(state.round,1);assert.equal(h.env.activeStory,'haara');assert.equal(state.mapId,getStoryEncounter('haara').mapId);
  assert.deepEqual(state.units[0].affinities,{water:6,fire:2});assert.equal(state.units[0].loadout[0],'maelstrom');
  assert.deepEqual(state.learnedSignatures[0],learnedStorySignatures(h.env.storyProgress).sort());
  assert.deepEqual(restoreSimState(state),state);assert.equal(h.env.error,'');
  assert.equal(h.env.resolving,false);assert.equal(h.env.reviewing,false);assert.equal(h.env.passAfterResolution.current,false);
});

test('practice mirrors actually allocated team strength, excluding unspent story points',async()=>{
  const h=harness();h.env.mode='practice';h.env.storyProgress=earned(5);
  h.env.storyProgress=setStoryAffinity(h.env.storyProgress,'oh_tipi',{water:6,fire:2});
  h.env.storyProgress=setStoryAffinity(h.env.storyProgress,'wa_bidi',allocateAffinityBudget('wa_bidi',6));
  await h.call('launch');
  const state=h.env.game as SimState,own=state.units.filter(unit=>unit.owner===0),rival=state.units.filter(unit=>unit.owner===1);
  assert.deepEqual(own.map(unit=>affinityTotal(unit.affinities)),[8,6,5]);
  assert.deepEqual(rival.map(unit=>affinityTotal(unit.affinities)),[8,6,5]);
  assert.equal(h.env.activeStory,null);assert.deepEqual(restoreSimState(state),state);
});

test('online hosting sends selected match kind and only the selected team’s earned allocations',async()=>{
  for(const matchKind of ['casual','competitive']){
    const h=harness();h.env.mode='online';h.env.matchKind=matchKind;
    h.env.storyProgress=setStoryAffinity(earned(),'oh_tipi',{water:6,fire:2});
    await h.call('launch');
    assert.equal(h.env.error,'');assert.equal(h.requests.length,1);
    const request=h.requests[0];assert.equal(request.path,'/api/rooms');assert.equal(request.init.method,'POST');
    assert.equal(request.body.matchKind,matchKind);assert.equal(request.body.protocolVersion,16);
    assert.deepEqual(Object.keys(request.body.affinities),ownRoster);
    assert.deepEqual(request.body.affinities.oh_tipi,{water:6,fire:2});
    assert.deepEqual(request.body.learnedSignatures,learnedStorySignatures(h.env.storyProgress));
    assert.equal(h.env.busy,false);assert.equal(h.env.requestBusy.current,false);
  }
});

test('joining sends earned allocations while retaining the host’s match kind',async()=>{
  const h=harness();h.env.mode='online';h.env.joining=true;h.env.matchKind='competitive';
  h.env.storyProgress=setStoryAffinity(earned(),'oh_tipi',{water:6,fire:2});
  await h.call('launch');assert.equal(h.env.error,'');
  const request=h.requests[0];assert.equal(request.path,'/api/rooms/23456789ABCD/join');
  assert.equal(Object.hasOwn(request.body,'matchKind'),false);assert.equal(Object.hasOwn(request.body,'mapId'),false);
  assert.deepEqual(request.body.affinities.oh_tipi,{water:6,fire:2});
});

test('practice and hotseat rematches retain the completed match’s allocation and earned spell kits',async()=>{
  for(const mode of ['practice','hotseat']){
    const allocations=Object.fromEntries(ownRoster.map(id=>[id,allocateAffinityBudget(id,8)]));
    const state=won(createSimGame([ownRoster,ownRoster],'frontier:REMATCH-V11',[{oh_tipi:['maelstrom','deep_freeze','ember','cleansing_tide']},{}],undefined,[allocations,allocations]));
    const h=harness(state);h.env.mode=mode;h.env.storyProgress=readStoryProgress(null);
    await h.call('rematch');
    const replay=h.env.game as SimState;
    assert.equal(replay.round,1);assert.equal(replay.winner,null);assert.equal(replay.mapId,state.mapId);
    assert.deepEqual(replay.units.map(unit=>unit.affinities),state.units.map(unit=>unit.affinities));
    assert.deepEqual(replay.units.map(unit=>unit.loadout),state.units.map(unit=>unit.loadout));
    assert.deepEqual(restoreSimState(replay),replay);
  }
});

test('only a first active story victory adds spendable affinity; other modes and replays never award it',()=>{
  for(const mode of ['practice','online','hotseat']){
    const h=harness(won(createStoryGame('oh_tipi',ownRoster)));h.env.activeStory='oh_tipi';h.env.mode=mode;
    h.effect('award');assert.equal(storyAffinityBudget(h.env.storyProgress),5);assert.equal(h.writes.length,0);
  }
  const h=harness(won(createStoryGame('oh_tipi',ownRoster)));h.env.activeStory='oh_tipi';
  h.effect('award');assert.equal(storyAffinityBudget(h.env.storyProgress),6);
  assert.deepEqual(h.env.learnedSignatures,['signature_oh_tipi']);
  assert.deepEqual(storyAffinities(h.env.storyProgress,'oh_tipi'),getChampion('oh_tipi').affinities,'a reward is banked until camp allocation');
  h.effect('award');assert.equal(storyAffinityBudget(h.env.storyProgress),6);assert.equal(h.writes.length,1);
});

test('initialization migrates v10 story victories into earned budget without changing the legacy profile or match',()=>{
  const h=harness(),legacy=JSON.stringify({format:1,defeated:['oh_tipi','s_wayne','red_baron']});h.env.loadoutsReady=false;
  h.stored.set(LEGACY_STORY_PROGRESS_KEY,legacy);h.stored.set('confluence-tactics-v10','legacy match');
  h.stored.set('confluence-name','Mira');h.stored.set('confluence-loadouts-v10',JSON.stringify({oh_tipi:['water_jet','ember','cleansing_tide','cleansing_tide']}));
  h.effect('initialize');
  assert.equal(h.env.loadoutsReady,true);assert.equal(h.env.v10Saved,true);assert.equal(h.env.storyProgress.format,2);
  assert.equal(storyAffinityBudget(h.env.storyProgress),8);assert.equal(h.env.learnedSignatures.length,3);
  assert.deepEqual(storyAffinities(h.env.storyProgress,'oh_tipi'),getChampion('oh_tipi').affinities);
  assert.equal(h.stored.get(LEGACY_STORY_PROGRESS_KEY),legacy);assert.equal(h.stored.get('confluence-tactics-v10'),'legacy match');
  h.call('updateAffinity','oh_tipi',{water:6,fire:2});
  const next=harness();for(const [key,value] of h.stored)next.stored.set(key,value);next.effect('initialize');
  assert.deepEqual(storyAffinities(next.env.storyProgress,'oh_tipi'),{water:6,fire:2});assert.equal(storyAffinityBudget(next.env.storyProgress),8);
});

test('initialization restores v11 high-level kits from earned affinity and tolerates a corrupt story profile',()=>{
  const h=harness();const progress=setStoryAffinity(earned(),'oh_tipi',{water:6,fire:2}),kit=['maelstrom','deep_freeze','ember','cleansing_tide'];
  h.stored.set(STORY_PROGRESS_KEY,JSON.stringify(progress));h.stored.set('confluence-loadouts-v16',JSON.stringify({oh_tipi:kit}));
  h.effect('initialize');assert.deepEqual(h.env.loadouts.oh_tipi,kit);
  const broken=harness();broken.stored.set(STORY_PROGRESS_KEY,'{invalid');broken.stored.set(SAVE_KEY,'active saved match');broken.stored.set('confluence-name','Mira');
  broken.effect('initialize');assert.equal(broken.env.saved,true);assert.equal(broken.env.name,'Mira');assert.equal(broken.env.loadoutsReady,true);
  assert.equal(storyAffinityBudget(broken.env.storyProgress),5);assert.equal(broken.stored.get(STORY_PROGRESS_KEY),'{invalid');
});

test('rules15 initialization retains earned rules14 kits and leaves the historical match and kit bytes untouched',async()=>{
  const h=harness(),progress=setStoryAffinity(earned(),'oh_tipi',{water:6,fire:2});
  const kit=['maelstrom','deep_freeze','ember','cleansing_tide'];
  const oldKits=JSON.stringify({oh_tipi:kit}),oldMatch='preserved rules14 match',savedProgress=JSON.stringify(progress);
  h.stored.set(STORY_PROGRESS_KEY,savedProgress);
  h.stored.set('confluence-loadouts-v14',oldKits);
  h.stored.set('confluence-tactics-v14',oldMatch);
  h.effect('initialize');
  assert.equal(h.env.v14Saved,true);assert.equal(h.env.saved,false);
  assert.deepEqual(h.env.loadouts.oh_tipi,kit);
  assert.deepEqual(storyAffinities(h.env.storyProgress,'oh_tipi'),{water:6,fire:2});
  h.effect('saveKits');
  assert.deepEqual(JSON.parse(h.stored.get('confluence-loadouts-v16')!).oh_tipi,kit);
  assert.equal(h.stored.get('confluence-loadouts-v14'),oldKits);
  assert.equal(h.stored.get('confluence-tactics-v14'),oldMatch);
  assert.equal(h.stored.get(STORY_PROGRESS_KEY),savedProgress);
  await h.call('launch');
  assert.equal(h.env.game.rulesVersion,16);
  assert.deepEqual(h.env.game.units[0].loadout,kit);
  assert.deepEqual(h.env.game.units[0].affinities,{water:6,fire:2});
  assert.deepEqual(restoreSimState(h.env.game),h.env.game);
  // Once the current kit exists it takes precedence, without rewriting old slots.
  const current=['water_jet','deep_freeze','ember','cleansing_tide'];
  h.stored.set('confluence-loadouts-v16',JSON.stringify({oh_tipi:current}));
  h.effect('initialize');assert.deepEqual(h.env.loadouts.oh_tipi,current);
  assert.equal(h.stored.get('confluence-loadouts-v14'),oldKits);
});
