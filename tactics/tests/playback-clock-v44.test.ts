import test from 'node:test';
import assert from 'node:assert/strict';
import {createPlaybackClockV44,playbackAnimationOrigin,type PlaybackChange} from '../lib/playback-clock-v44.ts';
import {synchronizePlaybackAnimations} from '../lib/playback-animation-v44.ts';
import {PHASE_MS,RESOLUTION_MS,projectileMeetingMs} from '../lib/feedback-v16.ts';

function fixture(){
 let time=0,serial=0;const pending=new Map<number,(time:number)=>void>(),changes:PlaybackChange[]=[],frames:number[]=[];
 const clock=createPlaybackClockV44({now:()=>time,request:callback=>{pending.set(++serial,callback);return serial},cancel:id=>{pending.delete(id)}});
 clock.subscribe(change=>changes.push(change));clock.subscribeFrame(elapsed=>frames.push(elapsed));
 const advance=(milliseconds:number)=>{time+=milliseconds;const batch=[...pending.values()];pending.clear();batch.forEach(callback=>callback(time))};
 return {clock,changes,frames,advance,pending};
}
test('pause freezes local elapsed and contacts; resume never catches up paused wall time',()=>{
 const {clock,advance,pending}=fixture(),meeting=projectileMeetingMs(.5);
 clock.start();advance(meeting-100);clock.pause();
 const paused=clock.read();assert.equal(paused.phase,'cast');assert.equal(paused.paused,true);assert.equal(pending.size,0);
 advance(60000);assert.deepEqual(clock.read(),paused);
 clock.resume();advance(99);assert.ok(clock.read().elapsed<meeting);
 advance(1);assert.equal(clock.read().elapsed,meeting);
});
test('phase stepping seeks exact boundaries, remains paused and completes once',()=>{
 const {clock,changes,advance,pending}=fixture();
 clock.start();advance(400);
 for(const [elapsed,phase] of [[PHASE_MS.cast,'cast'],[PHASE_MS.impact,'impact'],[PHASE_MS.settle,'settle']] as const){
  clock.step();assert.deepEqual(clock.read(),{elapsed,phase,paused:true,speed:1,active:true,complete:false});
  assert.equal(pending.size,0);advance(9000);assert.equal(clock.read().elapsed,elapsed);
 }
 clock.step();assert.equal(clock.read().elapsed,RESOLUTION_MS);assert.equal(clock.read().complete,true);assert.equal(clock.read().active,false);
 clock.step();assert.equal(changes.filter(change=>change==='complete').length,1);
});
test('speed changes preserve current presentation position and the completed exchange can replay',()=>{
 const {clock,advance,changes,pending}=fixture();
 clock.start();advance(1000);clock.setSpeed(2);assert.equal(clock.read().elapsed,1000);
 advance(300);assert.equal(clock.read().elapsed,1600);assert.equal(clock.read().phase,'cast');
 clock.setSpeed(.5);advance(200);assert.equal(clock.read().elapsed,1700);
 clock.setSpeed(7);assert.equal(clock.read().speed,.5);
 clock.finish();assert.equal(pending.size,0);assert.equal(clock.read().phase,'settle');
 clock.start();assert.equal(clock.read().elapsed,0);assert.equal(clock.read().complete,false);assert.equal(clock.read().speed,.5);
 advance(RESOLUTION_MS*2);assert.equal(clock.read().complete,true);assert.equal(changes.filter(change=>change==='complete').length,2);
});
test('stop and disposal cancel every future callback and unsubscribe cleanly',()=>{
 const {clock,advance,changes,pending}=fixture();
 let local=0;const remove=clock.subscribe(()=>local++);clock.start();remove();clock.stop();assert.equal(local,1);assert.equal(pending.size,0);
 advance(30000);assert.equal(clock.read().elapsed,0);clock.start();clock.dispose();const count=changes.length;
 advance(30000);clock.start();assert.equal(changes.length,count);assert.equal(pending.size,0);
});
class AnimationDouble{
 currentTime:number|null=null;playbackRate=1;state='running';played=0;paused=0;
 effect={getComputedTiming:()=>({endTime:this.end})};
 readonly end:number;
 constructor(end:number=Infinity){this.end=end}
 play(){this.played++;this.state='running'}
 pause(){this.paused++;this.state='paused'}
}
test('movement, cast, impact, defeat and callout animations share phase origins after seeks',()=>{
 const entries=[null,'walk','cast','hit','defeat'].map(action=>({animation:new AnimationDouble(),origin:playbackAnimationOrigin(action)}));
 const callout={animation:new AnimationDouble(1300),origin:playbackAnimationOrigin(null,true)};entries.push(callout);
 const snapshot={elapsed:PHASE_MS.settle+200,phase:'settle' as const,paused:true,speed:1.5,active:true,complete:false};
 synchronizePlaybackAnimations(entries as unknown as Parameters<typeof synchronizePlaybackAnimations>[0],snapshot);
 assert.deepEqual(entries.map(entry=>entry.animation.currentTime),[5800,5800,4200,1600,200,200]);
 assert.ok(entries.every(entry=>entry.animation.state==='paused'&&entry.animation.playbackRate===1.5));
 synchronizePlaybackAnimations(entries as unknown as Parameters<typeof synchronizePlaybackAnimations>[0],{...snapshot,paused:false});
 assert.ok(entries.every(entry=>entry.animation.state==='running'));
});
test('completed finite effects stay completed when playback resumes rather than rewinding',()=>{
 const animation=new AnimationDouble(600);
 synchronizePlaybackAnimations([{animation:animation as unknown as Animation,origin:0}],{elapsed:1000,phase:'move',paused:false,speed:2,active:true,complete:false});
 assert.equal(animation.currentTime,1000);assert.equal(animation.played,0);assert.equal(animation.state,'paused');
});
test('new terrain arrival starts at impact instead of appearing already finished',()=>{
 const animation=new AnimationDouble(850),origin=playbackAnimationOrigin(null,false,true);
 assert.equal(origin,PHASE_MS.impact);
 synchronizePlaybackAnimations([{animation:animation as unknown as Animation,origin}],{elapsed:PHASE_MS.impact+100,phase:'impact',paused:true,speed:1,active:true,complete:false});
 assert.equal(animation.currentTime,100);assert.equal(animation.state,'paused');
});
