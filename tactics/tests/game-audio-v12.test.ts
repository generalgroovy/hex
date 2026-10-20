import test from 'node:test';
import assert from 'node:assert/strict';
import {createGameAudio,materialVoices} from '../lib/game-audio-v12.ts';
import {resolutionCues,PHASE_MS} from '../lib/feedback-v12.ts';
import type {SimEvent} from '../lib/tactics-v12.ts';
class Parameter{events:number[][]=[];setValueAtTime(v:number,t:number){this.events.push([v,t])}linearRampToValueAtTime(v:number,t:number){this.events.push([v,t])}exponentialRampToValueAtTime(v:number,t:number){this.events.push([v,t])}}
class Gain{gain=new Parameter();disconnected=0;connect(){}disconnect(){this.disconnected++}}
class Oscillator{frequency=new Parameter();type='';started:number[]=[];stopped:(number|undefined)[]=[];disconnected=0;onended:(()=>void)|null=null;connect(){}disconnect(){this.disconnected++}start(at:number){this.started.push(at)}stop(at?:number){this.stopped.push(at)}}
class Context{state='running';currentTime=10;destination={};oscillators:Oscillator[]=[];gains:Gain[]=[];closed=0;resume:()=>Promise<void>=async()=>{this.state='running'};createOscillator(){const value=new Oscillator();this.oscillators.push(value);return value}createGain(){const value=new Gain();this.gains.push(value);return value}async close(){this.closed++;this.state='closed'}}
const wrap=(context:Context)=>()=>context as unknown as AudioContext;
const events:SimEvent[]=[{kind:'cast',elements:['fire'],text:''},{kind:'cast',elements:['water'],text:''},...Array.from({length:19},()=>({kind:'reaction' as const,elements:['water','fire'] as ('water'|'fire')[],terrain:'steam',text:''})),{kind:'bounce',text:''},{kind:'score',owner:0,amount:2,text:''}];
test('material voices have distinct timbre/envelope and restrained volume',()=>{
  const recipes=['fire','water','earth','air','light','dark'].map(element=>materialVoices('cast',element));
  assert.equal(new Set(recipes.map(recipe=>JSON.stringify(recipe))).size,6);
  assert.notDeepEqual(materialVoices('reaction','fire','steam'),materialVoices('reaction','fire','magma'));
  assert.notDeepEqual(materialVoices('reaction','water','black_ice'),materialVoices('cast','water'));
  for(const recipe of recipes)for(const voice of recipe){assert.ok(voice.volume<=.028);assert.ok(voice.duration<=.36);assert.ok(voice.start>0&&voice.end>0)}
});
test('large repeated fields produce bounded order-independent semantic audio',()=>{
  const cues=resolutionCues(events);assert.equal(cues.length,5);assert.deepEqual(cues,resolutionCues([...events].reverse()));
  assert.equal(cues[0].at,PHASE_MS.cast);assert.equal(cues.find(cue=>cue.kind==='reaction')?.terrain,'steam');
  assert.ok(resolutionCues([...events,...events,...events]).length<=5);
});
test('an interrupted creature gives blocked feedback, never a false release cue',()=>{
  const event:SimEvent={kind:'inhabitant',speciesId:'creature-3',elements:['fire','water'],terrain:'steam',interrupted:true,text:''};
  assert.deepEqual(resolutionCues([event]),[{at:1150,kind:'blocked'}]);
  assert.equal(resolutionCues([{...event,interrupted:false}])[0].kind,'reaction');
});
test('audio is opt-in, follows visual time, and clears all scheduled voices',async()=>{
  const context=new Context();let allocations=0;const audio=createGameAudio(()=>{allocations++;return wrap(context)()});
  audio.playResolution(events);assert.equal(allocations,0);assert.equal(await audio.enable(),true);audio.playResolution(events);
  assert.equal(context.oscillators.length,9);assert.equal(context.oscillators[0].started[0],10.45);
  const previous=[...context.oscillators];audio.playResolution(events);assert.ok(previous.every(value=>value.stopped.includes(undefined)&&value.disconnected));
  audio.mute();assert.ok(context.oscillators.every(value=>value.disconnected));const count=context.oscillators.length;audio.playUi('select');assert.equal(context.oscillators.length,count);
});
test('mute wins an in-flight resume and unlock can recover from denial',async()=>{
  const context=new Context();context.state='suspended';let finish!:()=>void;context.resume=()=>new Promise(resolve=>{finish=()=>{context.state='running';resolve()}});
  const audio=createGameAudio(wrap(context)),pending=audio.enable();audio.mute();finish();assert.equal(await pending,false);audio.playResolution(events);assert.equal(context.oscillators.length,0);
  context.state='suspended';context.resume=async()=>{throw Error('gesture denied')};assert.equal(await audio.enable(),false);
  context.resume=async()=>{context.state='running'};assert.equal(await audio.enable(),true);audio.playUi('select');assert.equal(context.oscillators.length,1);
  audio.dispose();audio.dispose();assert.equal(context.closed,1);assert.equal(await audio.enable(),false);
});
test('repeated UI interactions never exceed the live voice budget',async()=>{
  const context=new Context(),audio=createGameAudio(wrap(context));await audio.enable();for(let i=0;i<50;i++)audio.playUi('lock');assert.equal(context.oscillators.length,16);
  context.oscillators[0].onended?.();audio.playUi('select');assert.equal(context.oscillators.length,17);audio.cancel();assert.ok(context.oscillators.every(value=>value.disconnected));
});
