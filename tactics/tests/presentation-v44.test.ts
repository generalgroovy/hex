import test from 'node:test';
import assert from 'node:assert/strict';
import {resolutionCues,instantResolutionCues,PHASE_MS} from '../lib/feedback-v16.ts';
import {createGameAudio,materialVoices} from '../lib/game-audio-v16.ts';
import {presentationPreferences} from '../lib/presentation-preferences-v44.ts';
import {reactionPresentation,REACTION_MOTIFS} from '../lib/reaction-presentation-v44.ts';
import {COMBINATIONS} from '../lib/combinations-v16.ts';
import {creatureMotion} from '../lib/creature-motion-v44.ts';
import type {SimEvent} from '../lib/tactics-v16.ts';
import {fullyBlockedFighters} from '../lib/protection-feedback-v44.ts';

class Parameter{value=1;values:number[]=[];setValueAtTime(value:number){this.value=value;this.values.push(value)}linearRampToValueAtTime(value:number){this.value=value;this.values.push(value)}exponentialRampToValueAtTime(value:number){this.value=value;this.values.push(value)}}
class Gain{gain=new Parameter();disconnected=false;connect(){}disconnect(){this.disconnected=true}}
class Source{frequency=new Parameter();type='';startAt=-1;cancelled=false;disconnected=false;onended:(()=>void)|null=null;connect(){}disconnect(){this.disconnected=true}start(at:number){this.startAt=at}stop(at?:number){if(at===undefined)this.cancelled=true}}
class Context{state='running';currentTime=1;destination={};closed=0;sources:Source[]=[];gains:Gain[]=[];async resume(){}async close(){this.closed++;this.state='closed'}createOscillator(){const node=new Source();this.sources.push(node);return node}createGain(){const node=new Gain();this.gains.push(node);return node}}
const defeat=(owner:0|1):SimEvent=>({kind:'defeat',owner,unitId:`player-${owner}`,text:''});

test('fully blocked feedback requires recorded prevention and never confuses cancelled net damage with protection',()=>{
 const protectedHit={kind:'damage',unitId:'guarded',amount:0,breakdown:{prevented:4}};
 assert.deepEqual([...fullyBlockedFighters([protectedHit])],['guarded']);
 assert.equal(instantResolutionCues([{...protectedHit,text:''} as SimEvent])[0]?.kind,'blocked');
 assert.deepEqual([...fullyBlockedFighters([protectedHit,{kind:'damage',unitId:'guarded',amount:1}])],[]);
 assert.deepEqual([...fullyBlockedFighters([{kind:'damage',unitId:'old',amount:0},{kind:'damage',unitId:'healed',amount:3},{kind:'heal',unitId:'healed',amount:3}])],[]);
});

test('defeat sounds reflect ownership and simultaneous losses are neutral',()=>{
 assert.equal(resolutionCues([defeat(0)]).at(-1)?.kind,'loss');
 assert.equal(resolutionCues([defeat(1)]).at(-1)?.kind,'score');
 assert.equal(resolutionCues([defeat(0),defeat(1)]).at(-1)?.kind,'impact');
 assert.equal(resolutionCues([defeat(1)],1).at(-1)?.kind,'loss');
 assert.notDeepEqual(materialVoices('loss'),materialVoices('score'));
});

test('contacts win the two-cast foreground without depending on alphabetical name or array order',()=>{
 const events:SimEvent[]=[
  {kind:'cast',unitId:'first',elements:['air'],text:''},
  {kind:'cast',unitId:'second',elements:['earth'],text:''},
  {kind:'cast',unitId:'third',elements:['fire'],text:''},
  {kind:'cast',unitId:'fourth',elements:['water'],text:''},
  {kind:'clash',elements:['water','fire'],terrain:'steam',flightFraction:.5,text:''},
 ];
 const casts=(input:SimEvent[])=>resolutionCues(input).filter(cue=>cue.kind==='cast').map(cue=>cue.element).sort();
 assert.deepEqual(casts(events),['fire','water']);assert.deepEqual(casts(events.toReversed()),casts(events));
 assert.ok(resolutionCues(events).find(cue=>cue.kind==='reaction')!.at<PHASE_MS.impact);
});

test('instant review keeps a brief outcome while suppressing travel sounds',()=>{
 const events:SimEvent[]=[{kind:'move',text:''},{kind:'cast',elements:['fire'],text:''},{kind:'clash',elements:['fire','water'],terrain:'steam',text:''},defeat(0)];
 const cues=instantResolutionCues(events);
 assert.deepEqual(cues.map(cue=>cue.kind),['reaction','loss']);assert.ok(cues.every(cue=>cue.at<=260));
 assert.deepEqual(instantResolutionCues([]),[]);
});

test('audio mix bounds volumes, keeps muted buses silent and disposal closes its owned context once',async()=>{
 const context=new Context();let allocations=0;
 const audio=createGameAudio(()=>{allocations++;return context as unknown as AudioContext});
 audio.configure({combat:0,ui:1});audio.playResolution([defeat(1)]);assert.equal(allocations,0);
 assert.equal(await audio.enable(),true);audio.playResolution([defeat(1)],{instant:true});assert.equal(context.gains[1].gain.value,0,'scheduled voices remain inaudible through their muted combat bus');
 const beforeUi=context.sources.length;audio.playUi('select');assert.equal(context.sources.length,beforeUi+1);
 audio.configure({combat:100,ui:-5,reducedIntensity:true});audio.playUi('select');assert.equal(context.gains[0].gain.value,0);
 audio.playResolution([defeat(0)],{instant:true});assert.ok(context.sources.length>beforeUi+1);
 assert.ok(context.gains.slice(2).every(gain=>gain.gain.values.every(value=>value>=0&&value<=.03)),'voice envelopes keep their independent loudness ceiling');
 assert.ok(context.gains.slice(0,2).every(gain=>gain.gain.values.every(value=>value>=0&&value<=1)),'owned mix buses are bounded');
 audio.dispose();audio.dispose();assert.equal(context.closed,1);assert.ok(context.sources.every(source=>source.disconnected));assert.equal(await audio.enable(),false);
});

test('volume changes reach already scheduled combat voices through independent owned buses',async()=>{
 const context=new Context(),audio=createGameAudio(()=>context as unknown as AudioContext);await audio.enable();
 audio.playResolution([defeat(1)]);
 const [ui,combat]=context.gains,count=context.sources.length;
 audio.configure({combat:.25});assert.equal(combat.gain.values.at(-1),.25);assert.equal(ui.gain.values.at(-1),.8);
 audio.configure({reducedIntensity:true});assert.equal(combat.gain.values.at(-1),.25*.65);
 audio.configure({combat:0});assert.equal(combat.gain.values.at(-1),0);assert.equal(context.sources.length,count,'mix changes do not restart playback or create more voices');
 audio.playResolution([defeat(1)]);const silentCount=context.sources.length;assert.ok(silentCount>count,'silent bus retains future cue nodes');
 audio.configure({combat:.5});assert.equal(combat.gain.value,.5*.65);assert.equal(context.sources.length,silentCount,'raising zero volume restores scheduled voices without restarting the exchange');
 audio.dispose();assert.equal(ui.disconnected,true);assert.equal(combat.disconnected,true);
});

test('audio resumes only future cues at the selected playback speed',async()=>{
 const context=new Context(),audio=createGameAudio(()=>context as unknown as AudioContext);
 await audio.enable();
 audio.playResolution([{kind:'cast',unitId:'first',elements:['fire'],text:''},defeat(1)],{elapsedMs:PHASE_MS.impact,speed:2});
 assert.equal(context.sources.length,2,'Earlier casting is not replayed after the seek');
 assert.ok(Math.abs(context.sources[0].startAt-(context.currentTime+(PHASE_MS.settle-PHASE_MS.impact)/2000))<.001);
 audio.cancel();assert.ok(context.sources.every(source=>source.cancelled));
 audio.dispose();
});

test('corrupt preferences are bounded and sound is independent from motion',()=>{
 assert.equal(presentationPreferences('{bad').sound,false);
 const saved=presentationPreferences(JSON.stringify({sound:true,instant:true,mix:{ui:4,combat:-2,reducedIntensity:true}}));
 assert.equal(saved.sound,true);assert.equal(saved.instant,true);assert.deepEqual(saved.mix,{ui:1,combat:0,reducedIntensity:true});
 assert.equal(presentationPreferences(JSON.stringify({instant:false})).instant,false);
 assert.equal(presentationPreferences(null).instant,null);
});

test('all compounds have a finite mechanical silhouette, independent of ingredient ordering',()=>{
 const families=new Set<string>();
 for(const definition of COMBINATIONS){
  const normal=reactionPresentation(definition.elements),reverse=reactionPresentation(definition.elements.toReversed());
  assert.equal(normal.family,reverse.family);assert.ok(REACTION_MOTIFS[normal.family].length>20);families.add(normal.family);
  if(definition.mechanics.damageScale)assert.equal(normal.family,'mist');
  if(definition.mechanics.movement==='ice'&&!definition.mechanics.damageScale)assert.equal(normal.family,'ice');
 }
 assert.ok(families.size>=8);
 assert.notEqual(reactionPresentation(['fire','earth']).family,reactionPresentation(['water','light']).family);
});

test('creature gaits convey mass and casts release on the common spell clock without idle motion',()=>{
 assert.deepEqual(creatureMotion('garden','idle').frames,[[0,0]]);
 assert.ok(creatureMotion('tortoise','walk').duration>creatureMotion('fox','walk').duration);
 assert.notDeepEqual(creatureMotion('bird','cast').frames,creatureMotion('tortoise','cast').frames);
 for(const family of ['tortoise','fox','bird','garden','serpent'] as const){
  assert.equal(creatureMotion(family,'cast').duration/2,360);
  const last=creatureMotion(family,'defeat').frames.at(-1)!;assert.ok(last[1]>=4);
 }
});
