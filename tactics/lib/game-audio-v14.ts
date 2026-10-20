import {resolutionCues,type SoundCue} from './feedback-v14.ts';
import {combinationById} from './combinations-v14.ts';
type UiCue='select'|'lock';
type CueKind=UiCue|SoundCue['kind'];
export type AudioVoice={wave:OscillatorType;start:number;end:number;duration:number;delay:number;volume:number};
const voice=(wave:OscillatorType,start:number,end:number,duration:number,delay=0,volume=.018):AudioVoice=>({wave,start,end,duration,delay,volume});
/** Material envelopes share a restrained loudness ceiling, not a transposed jingle. */
export function materialVoices(kind:CueKind,element?:string,terrain?:string):AudioVoice[]{
  if(kind==='select')return [voice('sine',620,530,.065,0,.011)];
  if(kind==='lock')return [voice('triangle',330,330,.12),voice('sine',495,495,.18,.06)];
  if(kind==='blocked')return [voice('sine',150,74,.17,0,.024)];
  if(kind==='score')return [voice('sine',440,440,.24),voice('sine',660,660,.3,.08)];
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
export type GameAudio={enable:()=>Promise<boolean>;mute:()=>void;playUi:(kind:UiCue)=>void;playResolution:(events:Parameters<typeof resolutionCues>[0])=>void;cancel:()=>void;dispose:()=>void};
/** Context allocation/resume only follows an explicit player gesture. */
export function createGameAudio(factory:()=>AudioContext=()=>new AudioContext()):GameAudio {
  let context:AudioContext|null=null,enabled=false,disposed=false,generation=0;
  const voices=new Set<{oscillator:OscillatorNode;gain:GainNode}>();
  function cancel(){for(const entry of voices){try{entry.oscillator.stop()}catch{}entry.oscillator.disconnect();entry.gain.disconnect()}voices.clear()}
  function mute(){generation++;enabled=false;cancel()}
  async function enable(){if(disposed)return false;const ticket=++generation;try{context??=factory();if(context.state!=='running')await context.resume();if(disposed||ticket!==generation||context.state!=='running')return false;enabled=true;return true}catch{if(ticket===generation)enabled=false;return false}}
  function cue(kind:CueKind,delay=0,element?:string,terrain?:string){
    if(!enabled||disposed||context?.state!=='running')return;
    const active=context;
    for(const profile of materialVoices(kind,element,terrain)){
      if(voices.size>=16)return;
      const oscillator=active.createOscillator(),gain=active.createGain(),at=active.currentTime+delay+profile.delay;
      const entry={oscillator,gain};voices.add(entry);oscillator.type=profile.wave;
      oscillator.frequency.setValueAtTime(profile.start,at);oscillator.frequency.exponentialRampToValueAtTime(profile.end,at+profile.duration);
      gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(profile.volume,at+.008);gain.gain.exponentialRampToValueAtTime(.0001,at+profile.duration);
      oscillator.connect(gain);gain.connect(active.destination);
      oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();voices.delete(entry)};
      oscillator.start(at);oscillator.stop(at+profile.duration+.01);
    }
  }
  return {enable,mute,cancel,playUi:kind=>cue(kind),playResolution:events=>{cancel();for(const event of resolutionCues(events))cue(event.kind,event.at/1000,event.element,event.terrain)},dispose:()=>{if(disposed)return;disposed=true;mute();if(context){void context.close().catch(()=>{});context=null}}};
}
