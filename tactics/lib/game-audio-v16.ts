import {resolutionCues,instantResolutionCues,type SoundCue} from './feedback-v16.ts';
import {combinationById} from './combinations-v16.ts';
import {materialTexture,type SoundMaterial} from './audio-material-v41.ts';
type UiCue='select'|'lock';
type CueKind=UiCue|SoundCue['kind'];
export type AudioVoice={wave:OscillatorType;start:number;end:number;duration:number;delay:number;volume:number};
const voice=(wave:OscillatorType,start:number,end:number,duration:number,delay=0,volume=.018):AudioVoice=>({wave,start,end,duration,delay,volume});
/** Material envelopes share a restrained loudness ceiling, not a transposed jingle. */
export function materialVoices(kind:CueKind,element?:string,terrain?:string):AudioVoice[]{
  if(kind==='step')return [];
  if(kind==='select')return [voice('sine',620,530,.065,0,.011)];
  if(kind==='lock')return [voice('triangle',330,330,.12),voice('sine',495,495,.18,.06)];
  if(kind==='blocked')return [voice('sine',150,74,.17,0,.024)];
  if(kind==='fizzle')return [voice('triangle',392,196,.095,0,.014),voice('sine',196,174.61,.085,.07,.01)];
  if(kind==='critical')return [voice('triangle',987.77,1046.5,.075,0,.015),voice('sine',1567.98,1567.98,.13,.035,.01)];
  if(kind==='heal')return [voice('sine',523.25,523.25,.13,0,.016),voice('triangle',659.25,783.99,.17,.07,.011)];
  if(kind==='burn')return [voice('sawtooth',170,74,.07,0,.009),voice('triangle',740,247,.055,.035,.011)];
  if(kind==='score')return [voice('sine',440,440,.24),voice('sine',660,660,.3,.08)];
  if(kind==='loss')return [voice('triangle',196,130,.26,0,.016),voice('sine',98,65,.34,.055,.02)];
  if(kind==='impact')return [voice('sine',160,60,.14,0,.024)];
  const compound=terrain?combinationById(terrain):undefined;
  if(compound?.mechanics.damageScale)return [voice('triangle',930,290,.36,0,.012),voice('sine',370,245,.3,.07,.014)];
  if(compound?.mechanics.movement==='ice')return [voice('sine',1420,1190,.13,0,.012),voice('sine',1840,1760,.17,.06,.009)];
  if(compound?.mechanics.cover)return [voice('sine',135,61,.22,0,.023),voice('triangle',490,200,.09,.02,.01)];
  if(element==='fire')return [voice('sawtooth',180,73,.16,0,.014),voice('triangle',540,190,.09,.04,.012)];
  if(element==='water')return [voice('sine',380,130,.3,0,.023),voice('sine',560,280,.21,.055,.012)];
  if(element==='earth')return [voice('sine',115,42,.25,0,.028),voice('triangle',245,91,.1,.02,.009)];
  if(element==='air')return [voice('triangle',780,340,.28,0,.013),voice('sine',1160,670,.22,.04,.008)];
  if(element==='dark')return [voice('sine',185,69,.34,0,.022),voice('triangle',277,103,.2,.03,.01)];
  return [voice('sine',880,879,.36,0,.014),voice('sine',1327,1325,.32,.045,.009)];
}
export type AudioMix={ui:number;combat:number;reducedIntensity:boolean};
export type ResolutionAudioOptions={instant?:boolean;player?:0|1;elapsedMs?:number;speed?:number};
export type GameAudio={enable:()=>Promise<boolean>;mute:()=>void;configure:(mix:Partial<AudioMix>)=>void;playUi:(kind:UiCue)=>void;playResolution:(events:Parameters<typeof resolutionCues>[0],options?:ResolutionAudioOptions)=>void;cancel:()=>void;dispose:()=>void};
/** Context allocation/resume only follows an explicit player gesture. */
export function createGameAudio(factory:()=>AudioContext=()=>new AudioContext()):GameAudio {
  let context:AudioContext|null=null,enabled=false,disposed=false,generation=0;
  let mix:AudioMix={ui:.8,combat:.8,reducedIntensity:false};
  let buses:{ui:GainNode;combat:GainNode}|null=null;
  const voices=new Set<{oscillator:OscillatorNode|AudioBufferSourceNode;gain:GainNode;start:number;end:number}>();
  // Scheduled future phases do not consume the current phase's polyphony.
  const hasSpace=(start:number,end:number)=>voices.size<96&&[...voices].filter(entry=>entry.start<end&&entry.end>start).length<16;
  function cancel(){for(const entry of voices){try{entry.oscillator.stop()}catch{}entry.oscillator.disconnect();entry.gain.disconnect()}voices.clear()}
  function mute(){generation++;enabled=false;cancel()}
  function applyMix(smooth=true){
    if(!context||!buses)return;
    for(const kind of ['ui','combat'] as const){const parameter=buses[kind].gain,value=mix[kind]*(mix.reducedIntensity?.65:1),now=context.currentTime;
      parameter.cancelScheduledValues?.(now);
      if(smooth){parameter.setValueAtTime(parameter.value,now);parameter.linearRampToValueAtTime(value,now+.015)}
      else parameter.setValueAtTime(value,now);
    }
  }
  async function enable(){if(disposed)return false;const ticket=++generation;try{context??=factory();if(context.state!=='running')await context.resume();if(disposed||ticket!==generation||context.state!=='running')return false;if(!buses){buses={ui:context.createGain(),combat:context.createGain()};buses.ui.connect(context.destination);buses.combat.connect(context.destination);applyMix(false)}enabled=true;return true}catch{if(ticket===generation)enabled=false;return false}}
  function cue(kind:CueKind,delay=0,element?:string,terrain?:string){
    if(!enabled||disposed||context?.state!=='running')return;
    const active=context;
    // Sound-off schedules nothing. A silent volume bus keeps its bounded cue
    // schedule so raising volume mid-exchange reveals only the remaining sound.
    for(const profile of materialVoices(kind,element,terrain)){
      const at=active.currentTime+delay+profile.delay,end=at+profile.duration+.01;
      if(!hasSpace(at,end))continue;
      const oscillator=active.createOscillator(),gain=active.createGain();
      const entry={oscillator,gain,start:at,end};voices.add(entry);oscillator.type=profile.wave;
      oscillator.frequency.setValueAtTime(profile.start,at);oscillator.frequency.exponentialRampToValueAtTime(profile.end,at+profile.duration);
      gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(profile.volume,at+.008);gain.gain.exponentialRampToValueAtTime(.0001,at+profile.duration);
      oscillator.connect(gain);gain.connect(kind==='select'||kind==='lock'?buses!.ui:buses!.combat);
      oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();voices.delete(entry)};
      oscillator.start(at);oscillator.stop(at+profile.duration+.01);
    }
    if(kind!=='cast'&&kind!=='reaction'&&kind!=='step')return;
    // Minimal/unsupported audio contexts keep the tonal cues above.
    if(typeof active.createBuffer!=='function'||typeof active.createBufferSource!=='function')return;
    const field=terrain?combinationById(terrain):undefined;
    const material:SoundMaterial=kind==='step'?'step':field?.mechanics.damageScale?'steam':field?.mechanics.movement==='ice'?'ice':field?.mechanics.cover?'earth':['fire','water','earth','air','light','dark'].includes(element??'')?element as SoundMaterial:'air';
    const texture=materialTexture(material),at=active.currentTime+delay,length=texture.samples.length/texture.rate,end=at+length;
    if(!hasSpace(at,end))return;
    const oscillator=active.createBufferSource(),gain=active.createGain(),buffer=active.createBuffer(1,texture.samples.length,texture.rate);
    buffer.copyToChannel(new Float32Array(texture.samples),0);oscillator.buffer=buffer;
    const entry={oscillator,gain,start:at,end};voices.add(entry);
    gain.gain.setValueAtTime(texture.volume,at);oscillator.connect(gain);gain.connect(buses!.combat);
    oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();voices.delete(entry)};
    oscillator.start(at);oscillator.stop(end+.01);
  }
  return {enable,mute,cancel,configure:values=>{for(const key of ['ui','combat'] as const)if(typeof values[key]==='number'&&Number.isFinite(values[key]))mix[key]=Math.max(0,Math.min(1,values[key]));if(typeof values.reducedIntensity==='boolean')mix.reducedIntensity=values.reducedIntensity;applyMix()},playUi:kind=>cue(kind),playResolution:(events,options={})=>{cancel();const elapsed=options.instant?0:Math.max(0,options.elapsedMs??0),speed=Math.max(.5,Math.min(2,options.speed??1));for(const event of options.instant?instantResolutionCues(events,options.player):resolutionCues(events,options.player))if(event.at>=elapsed)cue(event.kind,(event.at-elapsed)/1000/speed,event.element,event.terrain)},dispose:()=>{if(disposed)return;disposed=true;mute();buses?.ui.disconnect();buses?.combat.disconnect();buses=null;if(context){void context.close().catch(()=>{});context=null}}};
}
