import test from 'node:test';
import assert from 'node:assert/strict';
import {CAST_ANTICIPATION_MS,CAST_POSE_MS,PROJECTILE_FLIGHT_MS,DISPLACEMENT_END_MS,EVENT_TEXT_MS,HEALTH_FEEDBACK_MS,PHASE_MS,RESOLUTION_MS,eventDelayMs,eventPhase,phaseAt,resolutionCues} from '../lib/feedback-v15.ts';
import {battlefieldMotion,UNIT_MOTION_MS} from '../lib/battlefield-motion-v15.ts';
import {groundContacts} from '../lib/combat-life-v15.ts';
import {createGameAudio} from '../lib/game-audio-v15.ts';
import {createSimGame,getCell,resolveRound,type SimEvent} from '../lib/tactics-v15.ts';

const arena=()=>{
  const state=createSimGame();
  state.cells=state.cells.map(({q,r})=>({q,r,terrain:'plain',biome:'plain',height:0,well:false}));
  Object.assign(state.units[0],{q:0,r:0});
  return state;
};

test('one presentation clock gives each simultaneous stage time and leaves a readable result',()=>{
  assert.equal(phaseAt(0),'move');assert.equal(phaseAt(PHASE_MS.cast-1),'move');
  assert.equal(phaseAt(PHASE_MS.cast),'cast');assert.equal(phaseAt(PHASE_MS.impact-1),'cast');
  assert.equal(phaseAt(PHASE_MS.impact),'impact');assert.equal(phaseAt(PHASE_MS.settle-1),'impact');
  assert.equal(phaseAt(PHASE_MS.settle),'settle');assert.equal(phaseAt(RESOLUTION_MS*100),'settle');
  assert.ok(PHASE_MS.cast>=1200);assert.ok(PHASE_MS.impact-PHASE_MS.cast>=1200);
  assert.ok(PHASE_MS.settle-PHASE_MS.impact>=1500);
  assert.ok(PHASE_MS.impact<DISPLACEMENT_END_MS&&DISPLACEMENT_END_MS<PHASE_MS.settle);
  assert.ok(HEALTH_FEEDBACK_MS>DISPLACEMENT_END_MS);
  assert.equal(HEALTH_FEEDBACK_MS,PHASE_MS.settle,'health numbers arrive with the reviewed health and statuses');
  assert.ok(PHASE_MS.settle+EVENT_TEXT_MS<=RESOLUTION_MS);
  assert.ok(CAST_ANTICIPATION_MS>0&&CAST_ANTICIPATION_MS<PHASE_MS.impact-PHASE_MS.cast);
  assert.equal(CAST_ANTICIPATION_MS/CAST_POSE_MS,120/450);
  assert.deepEqual(PHASE_MS,{cast:1800,impact:4800,settle:6400});
  assert.equal(RESOLUTION_MS,7800);
});

test('movement and forced collisions belong to different public phases without reading orders',()=>{
  const movement:SimEvent={kind:'bounce',text:'Oh Tipi stays: simultaneous move blocked.'};
  const forced:SimEvent={kind:'bounce',text:'Oh Tipi stays: simultaneous push blocked.'};
  const events:SimEvent[]=[{kind:'guard',text:'Guard'},movement,{kind:'cast',text:'Gust'},forced];
  assert.equal(eventPhase(movement,events),'move');assert.equal(eventPhase(forced,events),'impact');
  assert.equal(eventPhase({kind:'bounce',text:'Legacy displacement'},[events[2],{kind:'push',text:''}]),'move','unrelated event is not treated as a known stream member');
  const contextual:SimEvent={kind:'bounce',text:'Displacement blocked'};
  assert.equal(eventPhase(contextual,[events[2],contextual]),'impact');
  assert.ok(eventDelayMs(movement,events)<PHASE_MS.cast);
  assert.ok(eventDelayMs(forced,events)>=PHASE_MS.impact);
  assert.equal(eventPhase({kind:'fizzle',text:''}),'cast');
  assert.equal(eventPhase({kind:'guard',text:''}),'cast');
  assert.equal(eventPhase({kind:'respawn',text:''}),'settle');
  for(const kind of ['reaction','damage','heal','push','defeat','surface','inhabitant'] as const)assert.equal(eventPhase({kind,text:''}),'impact');
});

test('all timed event labels finish before the animated exchange ends',()=>{
  const kinds:SimEvent['kind'][]=['move','bounce','cast','reaction','damage','heal','push','defeat','respawn','score','guard','fizzle','surface','inhabitant'];
  for(const kind of kinds)assert.ok(eventDelayMs({kind,text:''})+EVENT_TEXT_MS<=RESOLUTION_MS,kind);
});

test('voluntary routes and physical contacts finish together before casting',()=>{
  const before=arena(),unit=before.units[0];
  for(let q=1;q<=4;q++)Object.assign(getCell(before,q,0)!,{terrain:'water',elements:['water'],ice:true,ttl:1});
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:{q:4,r:0}}]},{orders:[]}]);
  const frozen=JSON.stringify([before,after]);
  const motion=battlefieldMotion(before,after,unit.id)!,contact=groundContacts(before,after).find(entry=>entry.unitId===unit.id)!;
  assert.deepEqual(motion.frames.filter(frame=>frame.phase==='move').map(frame=>frame.atMs),[0,450,900,1350,1800]);
  assert.deepEqual(motion.frames.find(frame=>frame.atMs===PHASE_MS.impact)?.point,{q:4,r:0});
  assert.equal(contact.atMs,PHASE_MS.cast);assert.equal(contact.material,'ice');
  assert.equal(motion.durationMs,UNIT_MOTION_MS);assert.equal(motion.style.animationDuration,`${UNIT_MOTION_MS}ms`);
  assert.equal(JSON.stringify([before,after]),frozen,'presentation never mutates combat');
});

test('forced displacement and landing accents stay after impacts and before review',()=>{
  const before=arena(),victim=before.units[3];Object.assign(victim,{q:2,r:0});
  const after=structuredClone(before);after.version++;Object.assign(after.units[3],{q:4,r:0});
  Object.assign(getCell(after,4,0)!,{biome:'forest'});
  after.lastResolution=[{kind:'push',unitId:victim.id,from:{q:2,r:0},to:{q:3,r:0},text:'Push'},{kind:'push',unitId:victim.id,from:{q:3,r:0},to:{q:4,r:0},text:'Push'}];
  const motion=battlefieldMotion(before,after,victim.id)!;
  assert.deepEqual(motion.frames.filter(frame=>frame.phase==='push').map(frame=>frame.atMs),[5450,6100]);
  assert.deepEqual(motion.frames.find(frame=>frame.atMs===PHASE_MS.impact)?.point,{q:2,r:0});
  const contact=groundContacts(before,after)[0];
  assert.equal(contact.atMs,DISPLACEMENT_END_MS);assert.equal(contact.material,'leaf');
  assert.deepEqual(groundContacts(undefined,after),[]);
  assert.deepEqual(groundContacts({...before,version:before.version-1},after),[]);
});

test('audio is bounded, deterministic and uses the same readable stages',()=>{
  const events:SimEvent[]=[{kind:'cast',elements:['fire'],text:''},{kind:'cast',elements:['water'],text:''},{kind:'reaction',terrain:'steam',elements:['fire','water'],text:''},{kind:'bounce',text:'Mage stays: simultaneous move blocked.'},{kind:'bounce',text:'Mage stays: simultaneous push blocked.'},{kind:'fizzle',text:''},{kind:'inhabitant',interrupted:true,text:''},{kind:'score',amount:2,owner:0,text:''}];
  const cues=resolutionCues(events);
  assert.deepEqual(cues,resolutionCues([...events].reverse()));
  assert.deepEqual(cues.filter(cue=>cue.kind==='cast').map(cue=>cue.at),[PHASE_MS.cast+CAST_ANTICIPATION_MS,PHASE_MS.cast+CAST_ANTICIPATION_MS]);
  assert.equal(cues.find(cue=>cue.kind==='reaction')?.at,PHASE_MS.impact);
  assert.equal(cues.find(cue=>cue.kind==='score')?.at,PHASE_MS.settle);
  assert.deepEqual(cues.filter(cue=>cue.kind==='blocked').map(cue=>cue.at),[PHASE_MS.cast-300,PHASE_MS.cast,PHASE_MS.impact]);
  assert.ok(cues.length<=7);assert.deepEqual(resolutionCues([...events,...events]),cues);
});

class Parameter{setValueAtTime(){}linearRampToValueAtTime(){}exponentialRampToValueAtTime(){}}
class Gain{gain=new Parameter();disconnected=false;connect(){}disconnect(){this.disconnected=true}}
class Oscillator{frequency=new Parameter();type='';started:number[]=[];cancelled=false;disconnected=false;onended:(()=>void)|null=null;connect(){}disconnect(){this.disconnected=true}start(at:number){this.started.push(at)}stop(at?:number){if(at===undefined)this.cancelled=true}}
class Context{state='running';currentTime=10;destination={};oscillators:Oscillator[]=[];gains:Gain[]=[];async resume(){}async close(){}createOscillator(){const value=new Oscillator();this.oscillators.push(value);return value}createGain(){const value=new Gain();this.gains.push(value);return value}}
test('replay audio reschedules from the shared clock and cancels every old voice',async()=>{
  const context=new Context(),audio=createGameAudio(()=>context as unknown as AudioContext);
  const events:SimEvent[]=[{kind:'cast',elements:['water'],text:''}];
  audio.playResolution(events);assert.equal(context.oscillators.length,0);
  assert.equal(await audio.enable(),true);audio.playResolution(events);
  assert.equal(context.oscillators[0].started[0],10+(PHASE_MS.cast+CAST_ANTICIPATION_MS)/1000);
  const first=[...context.oscillators];audio.playResolution(events);
  assert.ok(first.every(voice=>voice.cancelled&&voice.disconnected));
  audio.cancel();assert.ok(context.oscillators.every(voice=>voice.cancelled&&voice.disconnected));
  audio.dispose();
});


test('every element releases together after movement and arrives before any interaction',()=>{
  const elements=['fire','water','earth','air','light','dark'] as const;
  const casts:SimEvent[]=elements.map((element,index)=>({kind:'cast',unitId:`mage-${index}`,elements:[element],text:''}));
  for(const event of [...casts].reverse()){
    const release=eventDelayMs(event,casts)+CAST_ANTICIPATION_MS;
    const arrival=release+PROJECTILE_FLIGHT_MS;
    assert.equal(release,2200,'no caster or element receives an initiative delay');
    assert.equal(arrival,PHASE_MS.impact);
    assert.ok(release>PHASE_MS.cast,'movement completes before any spell is released');
    assert.ok(PROJECTILE_FLIGHT_MS>=2500,'material and converging flights remain readable');
  }
  for(const kind of ['reaction','push','surface','inhabitant'] as const)assert.ok(eventDelayMs({kind,text:''})>=PHASE_MS.impact);
});
