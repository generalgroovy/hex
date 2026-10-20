import test from 'node:test';
import assert from 'node:assert/strict';
import {materialTexture,type SoundMaterial} from '../lib/audio-material-v41.ts';
import {createGameAudio} from '../lib/game-audio-v16.ts';
import {resolutionCues,PHASE_MS} from '../lib/feedback-v16.ts';
import type {SimEvent} from '../lib/tactics-v16.ts';

class Parameter{value=1;values:number[][]=[];setValueAtTime(value:number,time:number){this.value=value;this.values.push([value,time])}linearRampToValueAtTime(value:number,time:number){this.value=value;this.values.push([value,time])}exponentialRampToValueAtTime(value:number,time:number){this.value=value;this.values.push([value,time])}}
class Gain{gain=new Parameter();disconnected=false;connect(){}disconnect(){this.disconnected=true}}
class Source{frequency=new Parameter();type='';buffer:unknown;startAt=-1;endAt=-1;cancelled=false;disconnected=false;onended:(()=>void)|null=null;connect(){}disconnect(){this.disconnected=true}start(at:number){this.startAt=at}stop(at?:number){if(at===undefined)this.cancelled=true;else this.endAt=at}}
class Context{state='running';currentTime=10;destination={};sources:Source[]=[];gains:Gain[]=[];buffers:Float32Array[]=[];async resume(){}async close(){}createOscillator(){const node=new Source();this.sources.push(node);return node}createBufferSource(){return this.createOscillator()}createGain(){const gain=new Gain();this.gains.push(gain);return gain}createBuffer(_channels:number,length:number,_rate:number){const samples=new Float32Array(length);this.buffers.push(samples);return {copyToChannel(data:Float32Array){samples.set(data)}}}}

test('all material layers are finite, short, bounded and have distinct waveforms',()=>{
 const materials:SoundMaterial[]=['step','fire','water','earth','air','light','dark','steam','ice'];
 const signatures=new Set<string>();
 for(const material of materials){
  const layer=materialTexture(material);assert.ok(layer.samples.length/layer.rate<=.4);assert.ok(layer.volume<=.028);
  assert.ok(layer.samples.every(sample=>Number.isFinite(sample)&&Math.abs(sample)<=1));
  assert.ok(layer.samples.some(sample=>Math.abs(sample)>.01));
  assert.equal(Math.abs(layer.samples[0]),0);assert.equal(Math.abs(layer.samples.at(-1)!),0);
  signatures.add(Array.from(layer.samples.slice(100,120)).join(','));
  assert.deepEqual(materialTexture(material).samples,layer.samples);
 }
 assert.equal(signatures.size,materials.length);
});

test('one coordinated movement has two quiet contacts regardless of party size',()=>{
 const events:SimEvent[]=Array.from({length:18},(_,index)=>({kind:'move',unitId:`u${index}`,text:''}));
 const cues=resolutionCues(events);
 assert.deepEqual(cues,resolutionCues([events[0]]));
 assert.equal(cues.length,2);assert.ok(cues.every(cue=>cue.kind==='step'&&cue.at>0&&cue.at<PHASE_MS.cast));
});

test('a dense exchange retains its late result cue instead of exhausting the schedule during casting',async()=>{
 const context=new Context(),audio=createGameAudio(()=>context as unknown as AudioContext);await audio.enable();
 const events:SimEvent[]=[{kind:'move',text:''},{kind:'cast',elements:['fire'],text:''},{kind:'cast',elements:['water'],text:''},
  {kind:'bounce',text:'A stays: simultaneous move blocked.'},{kind:'fizzle',text:''},
  {kind:'clash',elements:['fire','water'],terrain:'steam',flightFraction:.25,text:''},
  {kind:'clash',elements:['fire','earth'],terrain:'magma',flightFraction:.6,text:''},
  {kind:'reaction',elements:['water','earth','air'],terrain:'storm',text:''},
  {kind:'bounce',text:'B stays: simultaneous push blocked.'},{kind:'defeat',text:''}];
 audio.playResolution(events);
 assert.ok(context.sources.length>16,'future stages may allocate more nodes than the simultaneous voice cap');
 assert.ok(context.sources.some(source=>source.startAt===10+PHASE_MS.settle/1000),'late result is audible');
 for(const at of context.sources.map(source=>source.startAt))assert.ok(context.sources.filter(source=>source.startAt<=at&&source.endAt>at).length<=16);
 assert.ok(context.buffers.length>=5,'movement and spell materials are actually scheduled');
 audio.cancel();assert.ok(context.sources.every(source=>source.cancelled&&source.disconnected));
});

test('sound remains gesture activated and mute cancels textures as well as notes',async()=>{
 const context=new Context(),audio=createGameAudio(()=>context as unknown as AudioContext);
 const events:SimEvent[]=[{kind:'cast',elements:['fire'],text:''}];
 audio.playResolution(events);assert.equal(context.sources.length,0);
 await audio.enable();audio.playResolution(events);assert.equal(context.buffers.length,1);
 audio.mute();assert.ok(context.sources.every(source=>source.cancelled&&source.disconnected));
 const count=context.sources.length;audio.playResolution(events);assert.equal(context.sources.length,count);
});

test('rapid repeated UI taps remain within simultaneous voice budget',async()=>{
 const context=new Context(),audio=createGameAudio(()=>context as unknown as AudioContext);await audio.enable();
 for(let index=0;index<50;index++)audio.playUi('lock');
 assert.equal(context.sources.length,16);audio.dispose();assert.ok(context.sources.every(source=>source.disconnected));
});
