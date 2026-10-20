import test from 'node:test';
import assert from 'node:assert/strict';
import {createGameAudio} from '../lib/game-audio.ts';
import type {SimEvent} from '../lib/tactics.ts';

class Parameter {events:number[][]=[];setValueAtTime(v:number,t:number){this.events.push([v,t])}linearRampToValueAtTime(v:number,t:number){this.events.push([v,t])}exponentialRampToValueAtTime(v:number,t:number){this.events.push([v,t])}}
class Gain {gain=new Parameter();disconnected=0;connect(){}disconnect(){this.disconnected++}}
class Oscillator {frequency=new Parameter();type='';started:number[]=[];stopped:(number|undefined)[]=[];disconnected=0;onended:(()=>void)|null=null;connect(){}disconnect(){this.disconnected++}start(at:number){this.started.push(at)}stop(at?:number){this.stopped.push(at)}}
class Context {state='running';currentTime=10;destination={};oscillators:Oscillator[]=[];gains:Gain[]=[];closed=0;resume:()=>Promise<void>=async()=>{this.state='running'};createOscillator(){const o=new Oscillator();this.oscillators.push(o);return o}createGain(){const g=new Gain();this.gains.push(g);return g}async close(){this.closed++;this.state='closed'}}
const wrap=(context:Context)=>()=>context as unknown as AudioContext;
const events:SimEvent[]=[{kind:'cast',elements:['fire'],text:''},...Array.from({length:19},()=>({kind:'reaction' as const,text:''})),{kind:'bounce',text:''},{kind:'score',owner:0,amount:2,text:''}];

test('audio stays silent and does not allocate a context until explicit enable',async()=>{
  const context=new Context();let allocations=0;const audio=createGameAudio(()=>{allocations++;return wrap(context)()});
  audio.playUi('select');audio.playResolution(events);assert.equal(allocations,0);
  assert.equal(await audio.enable(),true);audio.playResolution(events);assert.equal(allocations,1);
  assert.equal(context.oscillators.length,10,'bounded semantic sounds, not one voice per reacted hex');
  assert.equal(context.oscillators[0].started[0],10.45,'cast follows visual clock');
  assert.ok(Math.max(...context.oscillators.flatMap(o=>o.started))<12);
  audio.mute();assert.ok(context.oscillators.every(o=>o.stopped.includes(undefined)&&o.disconnected));
  audio.playUi('select');assert.equal(context.oscillators.length,10);
});

test('mute wins over an in-flight browser resume',async()=>{
  const context=new Context();context.state='suspended';let finish!:()=>void;
  context.resume=()=>new Promise(resolve=>{finish=()=>{context.state='running';resolve()}});
  const audio=createGameAudio(wrap(context)),pending=audio.enable();audio.mute();finish();
  assert.equal(await pending,false);audio.playUi('lock');audio.playResolution(events);assert.equal(context.oscillators.length,0);
});

test('denied audio unlock is handled and the next gesture can retry',async()=>{
  const context=new Context();context.state='suspended';context.resume=async()=>{throw new Error('gesture required')};const audio=createGameAudio(wrap(context));
  assert.equal(await audio.enable(),false);audio.playUi('select');assert.equal(context.oscillators.length,0);
  context.resume=async()=>{context.state='running'};assert.equal(await audio.enable(),true);audio.playUi('select');assert.equal(context.oscillators.length,1);
  audio.dispose();audio.dispose();assert.equal(context.closed,1);assert.equal(await audio.enable(),false);assert.ok(context.gains[0].disconnected>0);
});

test('replays replace scheduled sound, ended voices release connections, and floods stay bounded',async()=>{
  const context=new Context(),audio=createGameAudio(wrap(context));await audio.enable();audio.playResolution(events);const old=[...context.oscillators];audio.playResolution(events);
  assert.ok(old.every(o=>o.stopped.includes(undefined)&&o.disconnected));
  const last=context.oscillators.at(-1)!;last.onended?.();assert.ok(last.disconnected);
  const start=context.oscillators.length;for(let i=0;i<50;i++)audio.playUi('lock');assert.ok(context.oscillators.length-start<=7,'at most16 simultaneously tracked voices');
  audio.cancel();assert.ok(context.oscillators.every(o=>o.disconnected));
});
