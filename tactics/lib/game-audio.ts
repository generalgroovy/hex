import {resolutionCues, type SoundCue} from './feedback.ts';
import type {SimEvent} from './tactics.ts';

type UiCue='select'|'lock';
type CueKind=UiCue|SoundCue['kind'];
const notes:Record<CueKind,readonly number[]>={select:[520],lock:[330,440],cast:[220,294],reaction:[294,440,587],impact:[196],blocked:[185,147],score:[392,494,659]};
const elementPitch:Record<string,number>={fire:1,water:.8,air:1.25,earth:.65,light:1.5,dark:.75};
export type GameAudio = {
  enable:()=>Promise<boolean>; mute:()=>void; playUi:(kind:UiCue)=>void;
  playResolution:(events:SimEvent[])=>void; cancel:()=>void; dispose:()=>void;
};
/** Owned, opt-in audio. Construct/resume only from enable(), called in a player gesture. */
export function createGameAudio(factory:()=>AudioContext=()=>new AudioContext()):GameAudio {
  let context:AudioContext|null=null,enabled=false,disposed=false,generation=0;
  const voices=new Set<{oscillator:OscillatorNode;gain:GainNode}>();
  function cancel(){for(const voice of voices){try{voice.oscillator.stop()}catch{}voice.oscillator.disconnect();voice.gain.disconnect()}voices.clear()}
  function mute(){generation++;enabled=false;cancel()}
  async function enable(){
    if(disposed)return false;
    const ticket=++generation;
    try{context??=factory();if(context.state!=='running')await context.resume();if(disposed||ticket!==generation||context.state!=='running')return false;enabled=true;return true}catch{if(ticket===generation)enabled=false;return false}
  }
  function cue(kind:CueKind,delay=0,element?:string){
    if(!enabled||disposed||context?.state!=='running')return;
    const a=context;
    notes[kind].forEach((frequency,index)=>{
      if(voices.size>=16)return;
      const oscillator=a.createOscillator(),gain=a.createGain(),at=a.currentTime+delay+index*.055;
      const voice={oscillator,gain};voices.add(voice);
      oscillator.type=kind==='blocked'?'sine':'triangle';
      oscillator.frequency.setValueAtTime(frequency*(element?elementPitch[element]||1:1),at);
      gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(.025,at+.008);gain.gain.exponentialRampToValueAtTime(.0001,at+.18);
      oscillator.connect(gain);gain.connect(a.destination);
      oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();voices.delete(voice)};
      oscillator.start(at);oscillator.stop(at+.2);
    });
  }
  return {enable,mute,cancel,playUi:kind=>cue(kind),playResolution:events=>{cancel();for(const event of resolutionCues(events))cue(event.kind,event.at/1000,event.element)},dispose:()=>{if(disposed)return;disposed=true;mute();if(context){void context.close().catch(()=>{});context=null}}};
}
