import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import {createSimGame,resolveRound,validatePlan,castAvailability,type SimState,type TeamPlan} from '../lib/tactics-v14.ts';
import {availableSpellIds} from '../lib/spells-v14.ts';
import {arenaSeed} from '../lib/arena-v7.ts';
import {PHASE_MS,RESOLUTION_MS} from '../lib/feedback-v14.ts';

// Run the actual component handlers, derived gates and playback effect. Only
// React scheduling, time, storage and audio are isolated; resolution is real.
const source=ts.createSourceFile('TacticsGame.tsx',readFileSync(new URL('../app/TacticsGameV14.tsx',import.meta.url),'utf8'),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
const handlers=new Map<string,string>(),derived=new Map<string,string>();
let playbackEffect='',playbackDependencies='',resultGate='';
const transpile=(value:string)=>ts.transpileModule(value,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.None}}).outputText;
function visit(node:ts.Node){
  if(ts.isFunctionDeclaration(node)&&node.name)handlers.set(node.name.text,transpile(node.getText(source)));
  if(ts.isVariableDeclaration(node)&&ts.isIdentifier(node.name)&&node.initializer&&['seat','locked','canPlan','displayedGame'].includes(node.name.text))derived.set(node.name.text,transpile(`return ${node.initializer.getText(source)};`));
  if(ts.isCallExpression(node)&&ts.isIdentifier(node.expression)&&node.expression.text==='useEffect'&&node.arguments[0]?.getText(source).includes("setResolutionPhase('cast')")){
    playbackEffect=transpile(`return ${node.arguments[0].getText(source)};`);
    playbackDependencies=transpile(`return ${node.arguments[1].getText(source)};`);
  }
  if(ts.isConditionalExpression(node)&&ts.isJsxSelfClosingElement(node.whenTrue)&&node.whenTrue.tagName.getText(source)==='BattleResult')resultGate=transpile(`return ${node.condition.getText(source)};`);
  ts.forEachChild(node,visit);
}
visit(source);
const EMPTY:TeamPlan={orders:[]},CODE='23456789ABCD';
const initial=()=>createSimGame(undefined,'frontier:PHASE-CONTROLLER');

function harness(game=initial(),mode='practice'){
  const timers=new Map<number,{at:number;callback:()=>void}>(),audioEvents:string[]=[],clearedDrafts:string[]=[];
  let now=0,nextTimer=1,resolutions=0,cleanup:(()=>void)|undefined,dependencies='';
  const env:Record<string,any>={
    game,gameRef:{current:game},mode,screen:'battle',plan:EMPTY,planHistory:[],selected:game.units[0].id,kind:'move',spellId:'',
    resolving:false,reviewing:false,resolutionRun:0,resolutionPhase:'move',previous:undefined,passAfterResolution:{current:false},
    hotSeat:0,handoff:false,sealedLocal:null,busy:false,connected:true,room:null,session:null,requestBusy:{current:false},
    epoch:{current:0},activeSession:{current:null},revision:{current:-1},match:{current:''},timer:{current:null},
    error:'',notice:'',hoverAim:null,inspect:null,focusRequest:0,sound:true,
    audio:{current:{playResolution:()=>audioEvents.push('play'),cancel:()=>audioEvents.push('cancel')}},
    EMPTY,PHASE_MS,RESOLUTION_MS,arenaSeed,availableSpellIds,castAvailability,validatePlan,
    alive:(unit:SimState['units'][number])=>unit.hp>0&&unit.respawn===undefined,
    choosePracticePlan:()=>EMPTY,chime:()=>{},
    resolveRound:(state:SimState,plans:[TeamPlan,TeamPlan])=>{resolutions++;return resolveRound(state,plans);},
    sessions:()=>({clearDraft:(code:string)=>clearedDrafts.push(code),readDraft:()=>null}),
    location:{replace:()=>assert.fail('current rules must not redirect')},
    setTimeout:(callback:()=>void,delay:number)=>{const id=nextTimer++;timers.set(id,{at:now+delay,callback});return id;},
    clearTimeout:(id:number)=>{timers.delete(id);},
  };
  for(const name of ['ResolutionPhase','Reviewing','ResolutionRun','Resolving','HoverAim','Inspect','Previous','Game','Plan','PlanHistory','Notice','Selected','FocusRequest','Kind','SpellId','HotSeat','SealedLocal','Handoff','Error','Connected','Room','MapSeed','Session','Busy']){
    const field=name[0].toLowerCase()+name.slice(1);
    env[`set${name}`]=(value:unknown)=>{env[field]=typeof value==='function'?value(env[field]):value;};
  }
  function evaluate(js:string){return new Function(...Object.keys(env),js)(...Object.values(env));}
  function derive(){for(const [name,js] of derived)env[name]=evaluate(js);}
  function invoke(name:string,...args:unknown[]){derive();const js=handlers.get(name);assert.ok(js,`actual ${name} handler exists`);return evaluate(`${js};return ${name};`)(...args);}
  for(const name of ['current','selectUnit','startPlayback','showResolution','showResult','finishReview','replayResolution'])env[name]=(...args:unknown[])=>invoke(name,...args);
  function flush(){
    derive();assert.ok(playbackEffect);assert.ok(playbackDependencies);
    const next=JSON.stringify(evaluate(playbackDependencies));
    if(next!==dependencies){cleanup?.();dependencies=next;cleanup=evaluate(playbackEffect)();}
    derive();
  }
  function call(name:string,...args:unknown[]){const result=invoke(name,...args);flush();return result;}
  function advance(ms:number){
    const end=now+ms;
    for(;;){const next=[...timers].filter(([,timer])=>timer.at<=end).sort((a,b)=>a[1].at-b[1].at||a[0]-b[0])[0];if(!next)break;now=next[1].at;timers.delete(next[0]);next[1].callback();flush();}
    now=end;flush();
  }
  function connect(state=env.game){
    env.mode='online';env.session={code:CODE,seat:0,token:'a'.repeat(64)};env.activeSession.current=env.session;env.revision.current=4;env.match.current='match-one';
    env.room=room(state);flush();
  }
  function room(state:SimState,overrides:Record<string,unknown>={}){return {code:CODE,matchId:'match-one',version:4,status:state.winner===null?'active':'finished',rulesVersion:14,yourSeat:0,state,mapId:state.mapId,locked:[false,false],rematch:[false,false],...overrides};}
  flush();
  return {env,call,advance,flush,connect,room,audioEvents,clearedDrafts,timers,resolutions:()=>resolutions,resultVisible:()=>{derive();assert.ok(resultGate);return evaluate(resultGate);}};
}

test('ending a practice turn resolves once and waits through ordered phases and an unlimited review',async()=>{
  const h=harness(),before=h.env.game;
  await h.call('lockPlan');assert.equal(h.env.error,'');assert.equal(h.resolutions(),1);
  assert.equal(h.env.previous,before);assert.equal(h.env.game.version,before.version+1);assert.equal(h.env.resolutionPhase,'move');assert.equal(h.env.canPlan,false);
  assert.equal(h.env.displayedGame,before);h.advance(PHASE_MS.cast-1);assert.equal(h.env.resolutionPhase,'move');
  h.advance(1);assert.equal(h.env.resolutionPhase,'cast');assert.equal(h.env.displayedGame,before);
  h.advance(PHASE_MS.impact-PHASE_MS.cast);assert.equal(h.env.resolutionPhase,'impact');
  h.advance(PHASE_MS.settle-PHASE_MS.impact);assert.equal(h.env.resolutionPhase,'settle');assert.equal(h.env.displayedGame,h.env.game);assert.equal(h.env.reviewing,false);
  h.advance(RESOLUTION_MS-PHASE_MS.settle);assert.equal(h.env.reviewing,true);assert.equal(h.env.canPlan,false);
  h.advance(120000);assert.equal(h.env.resolving,true);assert.equal(h.env.reviewing,true);assert.equal(h.env.canPlan,false);assert.equal(h.timers.size,0);
  await h.call('lockPlan');assert.equal(h.resolutions(),1,'End turn cannot resolve again while reviewing');
  h.call('finishReview');assert.equal(h.env.canPlan,true);assert.equal(h.env.resolving,false);
});

test('Show result cancels playback and audio without unlocking orders or allowing stale phase callbacks',async()=>{
  const h=harness();await h.call('lockPlan');h.advance(100);
  h.call('showResult');assert.equal(h.env.resolutionPhase,'settle');assert.equal(h.env.reviewing,true);assert.equal(h.env.canPlan,false);assert.equal(h.timers.size,0);
  assert.equal(h.audioEvents.at(-1),'cancel');h.advance(RESOLUTION_MS*2);
  assert.equal(h.env.resolutionPhase,'settle');assert.equal(h.env.canPlan,false);assert.equal(h.resolutions(),1);
});

test('replay preserves a new draft and its undo history, never resolves again, and remains read-only',async()=>{
  const h=harness();await h.call('lockPlan');h.call('showResult');h.call('finishReview');
  const draft={orders:[{unitId:h.env.game.units[0].id,guard:true}]};h.env.plan=draft;h.env.planHistory=[EMPTY];h.flush();
  const game=h.env.game,previous=h.env.previous,run=h.env.resolutionRun;
  h.call('replayResolution');assert.equal(h.env.resolutionRun,run+1);assert.equal(h.env.game,game);assert.equal(h.env.previous,previous);assert.equal(h.env.plan,draft);assert.deepEqual(h.env.planHistory,[EMPTY]);
  assert.equal(h.env.canPlan,false);await h.call('lockPlan');assert.equal(h.resolutions(),1);
  h.advance(RESOLUTION_MS);h.call('finishReview');assert.equal(h.env.plan,draft);assert.equal(h.env.canPlan,true);assert.equal(h.clearedDrafts.length,0);
});

test('replay refuses mismatched snapshots and a new playback cancels the older phase schedule',async()=>{
  const h=harness();h.call('replayResolution');assert.equal(h.env.resolving,false);
  await h.call('lockPlan');h.advance(1000);const run=h.env.resolutionRun;
  h.call('replayResolution');assert.equal(h.env.resolutionRun,run+1);h.advance(PHASE_MS.cast-1);assert.equal(h.env.resolutionPhase,'move','old casting callback was cancelled');h.advance(1);assert.equal(h.env.resolutionPhase,'cast');
  h.call('showResult');h.call('finishReview');h.env.previous={...h.env.previous,version:h.env.previous.version-1};h.call('replayResolution');assert.equal(h.env.resolving,false);
});

test('online polls cannot dismiss playback or review when opponent locks the next round',()=>{
  const h=harness();h.connect();const next=resolveRound(h.env.game,[EMPTY,EMPTY]);
  h.call('acceptRoom',h.room(next,{version:5}),0);assert.equal(h.env.resolving,true);assert.equal(h.clearedDrafts.length,1);
  h.advance(RESOLUTION_MS);const run=h.env.resolutionRun;
  h.call('acceptRoom',h.room(next,{version:6,locked:[false,true]}),0);
  assert.equal(h.env.resolving,true);assert.equal(h.env.reviewing,true);assert.equal(h.env.canPlan,false);assert.equal(h.env.resolutionRun,run);
  h.advance(60000);assert.equal(h.env.canPlan,false);h.call('finishReview');assert.equal(h.env.canPlan,true);assert.deepEqual(h.env.plan,EMPTY);
});

test('online rematch arriving during replay cancels the old playback and opens the fresh match',()=>{
  const h=harness();h.connect();const next={...resolveRound(h.env.game,[EMPTY,EMPTY]),winner:0 as const};
  h.call('acceptRoom',h.room(next,{version:5}),0);h.call('showResult');h.call('finishReview');h.call('replayResolution');h.advance(1000);
  const fresh=createSimGame(undefined,next.mapId);
  h.call('acceptRoom',h.room(fresh,{version:6,matchId:'match-two'}),0);
  assert.equal(h.env.game,fresh);assert.equal(h.env.previous,undefined);assert.equal(h.env.resolving,false);assert.equal(h.env.reviewing,false);assert.equal(h.env.canPlan,true);assert.equal(h.env.passAfterResolution.current,false);assert.equal(h.timers.size,0);
  h.advance(60000);assert.equal(h.env.canPlan,true);assert.equal(h.env.reviewing,false);assert.equal(h.audioEvents.at(-1),'cancel');
});

test('a mutually upgraded online room routes from the retained rules14 page before it can install elimination state',()=>{
  const h=harness();h.connect();const original=h.env.game,room=h.env.room,redirects:string[]=[];
  h.env.location.replace=(url:string)=>redirects.push(url);
  const upgraded=h.room(original,{version:7,rulesVersion:15,matchId:'elimination-rematch',state:{...original,rulesVersion:15}});
  h.call('acceptRoom',upgraded,0);
  assert.deepEqual(redirects,['/?room=23456789ABCD']);assert.equal(h.env.game,original);assert.equal(h.env.gameRef.current,original);
  assert.equal(h.env.room,room);assert.equal(h.env.revision.current,4);assert.equal(h.env.previous,undefined);assert.equal(h.env.resolving,false);assert.equal(h.timers.size,0);
});

test('reconnecting across missed rounds or an incompatible map installs the current state without inventing a replay',()=>{
  for(const difference of ['missed-rounds','different-map']){
    const h=harness();h.connect();const first=resolveRound(h.env.game,[EMPTY,EMPTY]);
    h.call('acceptRoom',h.room(first,{version:5}),0);h.advance(2000);
    assert.equal(h.env.resolving,true);assert.ok(h.timers.size>0);
    const next=difference==='missed-rounds'
      ?resolveRound(resolveRound(first,[EMPTY,EMPTY]),[EMPTY,EMPTY])
      :resolveRound(resolveRound(createSimGame(undefined,'frontier:ANOTHER-PHASE-MAP'),[EMPTY,EMPTY]),[EMPTY,EMPTY]);
    if(difference==='missed-rounds')assert.equal(next.version,first.version+2);
    else{assert.equal(next.version,first.version+1);assert.notEqual(next.mapId,first.mapId);}
    const plays=h.audioEvents.filter(event=>event==='play').length;
    h.call('acceptRoom',h.room(next,{version:8}),0);
    assert.equal(h.env.game,next);assert.equal(h.env.gameRef.current,next);assert.equal(h.env.previous,undefined);
    assert.equal(h.env.resolving,false);assert.equal(h.env.reviewing,false);assert.equal(h.env.passAfterResolution.current,false);assert.equal(h.env.canPlan,true);
    assert.deepEqual(h.env.plan,EMPTY);assert.equal(h.timers.size,0);assert.match(h.env.notice,/Caught up to the current round/);
    assert.equal(h.audioEvents.filter(event=>event==='play').length,plays,'catch-up must not play the final exchange against an unrelated before-state');
    assert.equal(h.audioEvents.at(-1),'cancel');assert.equal(h.clearedDrafts.length,2);assert.equal(h.resolutions(),0,'installing authoritative state does not resolve client combat');
    h.call('replayResolution');assert.equal(h.env.resolving,false);h.advance(60000);
    assert.equal(h.env.reviewing,false);assert.equal(h.env.canPlan,true);assert.equal(h.env.game,next);
  }
});

test('hotseat shows neither sealed orders nor an early handoff during playback, then passes after review',async()=>{
  const h=harness(initial(),'hotseat'),old=h.env.game;
  h.env.plan={orders:[{unitId:old.units[0].id,guard:true}]};await h.call('lockPlan');
  assert.equal(h.env.hotSeat,1);assert.equal(h.env.handoff,true);assert.equal(h.env.canPlan,false);assert.ok(h.env.sealedLocal);assert.deepEqual(h.env.plan,EMPTY);assert.equal(h.resolutions(),0);
  h.env.handoff=false;h.flush();await h.call('lockPlan');
  assert.equal(h.resolutions(),1);assert.equal(h.env.hotSeat,0);assert.equal(h.env.sealedLocal,null);assert.equal(h.env.handoff,false);assert.equal(h.env.passAfterResolution.current,true);assert.equal(h.env.canPlan,false);assert.deepEqual(h.env.plan,EMPTY);
  h.advance(RESOLUTION_MS);assert.equal(h.env.handoff,false,'players have as much review time as needed');
  h.call('replayResolution');h.call('showResult');h.call('finishReview');
  assert.equal(h.env.handoff,true);assert.equal(h.env.passAfterResolution.current,false);assert.equal(h.env.canPlan,false);
});

test('a winning exchange remains behind review and never opens planning or an unnecessary hotseat pass',()=>{
  const h=harness(initial(),'hotseat'),won={...resolveRound(h.env.game,[EMPTY,EMPTY]),winner:0 as const};
  h.call('showResolution',won,true);assert.equal(h.resultVisible(),false);assert.equal(h.env.canPlan,false);
  h.advance(RESOLUTION_MS);assert.equal(h.resultVisible(),false);h.call('finishReview');
  assert.equal(h.resultVisible(),true);assert.equal(h.env.canPlan,false);assert.equal(h.env.handoff,false);
});

test('disconnecting the active match cleans up all phase timers and prevents a delayed review state',async()=>{
  const h=harness();await h.call('lockPlan');h.advance(200);h.env.passAfterResolution.current=true;
  h.call('resetRemote');assert.equal(h.env.resolving,false);assert.equal(h.env.reviewing,false);assert.equal(h.env.passAfterResolution.current,false);assert.equal(h.timers.size,0);
  h.advance(60000);assert.equal(h.env.reviewing,false);assert.equal(h.env.resolving,false);assert.equal(h.audioEvents.at(-1),'cancel');
});

test('sealed online polling installs only this seat\'s acknowledged plan and never exposes a rival plan',()=>{
  const h=harness();h.connect();const own=validatePlan(h.env.game,0,{orders:[{unitId:h.env.game.units[0].id,guard:true}]}),secret={orders:[{unitId:h.env.game.units[3].id,spellId:'ember',cast:{q:0,r:0}}]};
  h.call('acceptRoom',h.room(h.env.game,{version:5,locked:[true,true],yourPlan:own,opponentPlan:secret}),0);
  assert.deepEqual(h.env.plan,own);assert.ok(h.env.plan.orders.every((order:TeamPlan['orders'][number])=>h.env.game.units.find((unit:SimState['units'][number])=>unit.id===order.unitId)?.owner===0));
  assert.equal(h.env.resolving,false);assert.equal(h.env.previous,undefined);assert.equal(h.env.canPlan,false);
});
