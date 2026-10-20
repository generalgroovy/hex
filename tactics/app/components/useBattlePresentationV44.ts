"use client";
import {useEffect,useRef,useState} from 'react';
import {createGameAudio,type AudioMix} from '../../lib/game-audio-v16';
import {DEFAULT_PRESENTATION,PRESENTATION_KEY,presentationPreferences,type PresentationPreferences} from '../../lib/presentation-preferences-v44';

/** One audio owner per battle host. Playback preference never controls audibility. */
export default function useBattlePresentationV44(){
 const audio=useRef<ReturnType<typeof createGameAudio>|null>(null);
 const unlocking=useRef<{owner:ReturnType<typeof createGameAudio>;promise:Promise<boolean>}|null>(null);
 const soundIntent=useRef(0);
 const prefs=useRef<PresentationPreferences>({...DEFAULT_PRESENTATION,mix:{...DEFAULT_PRESENTATION.mix}});
 const [sound,setSound]=useState(false),[audioReady,setAudioReady]=useState(false),[instant,setInstantState]=useState(false),[mix,setMixState]=useState({...DEFAULT_PRESENTATION.mix});
 const ensureAudio=()=>{audio.current??=createGameAudio();audio.current.configure(prefs.current.mix);return audio.current};
 const unlockAudio=async()=>{
  const intent=soundIntent.current,owner=ensureAudio(),promise=unlocking.current?.owner===owner?unlocking.current.promise:owner.enable();
  unlocking.current={owner,promise};const enabled=await promise;
  if(unlocking.current?.promise===promise)unlocking.current=null;
  if(intent===soundIntent.current&&audio.current===owner&&prefs.current.sound)setAudioReady(enabled);
  return enabled;
 };
 const persist=()=>{try{localStorage.setItem(PRESENTATION_KEY,JSON.stringify(prefs.current))}catch{}};
 useEffect(()=>{
  try{
   prefs.current=presentationPreferences(localStorage.getItem(PRESENTATION_KEY));
   const legacy=localStorage.getItem('hex-confluence-animation');
   if(prefs.current.instant===null&&legacy)prefs.current.instant=legacy==='instant';
   setInstantState(prefs.current.instant??window.matchMedia('(prefers-reduced-motion: reduce)').matches);
   setSound(prefs.current.sound);setMixState(prefs.current.mix);
  }catch{}
  // Restoring "sound on" does not allocate/resume a context without a gesture.
  const activate=()=>{if(prefs.current.sound)void unlockAudio()};
  window.addEventListener('pointerdown',activate,{once:true});
  window.addEventListener('keydown',activate,{once:true});
  return()=>{soundIntent.current++;window.removeEventListener('pointerdown',activate);window.removeEventListener('keydown',activate);audio.current?.dispose();audio.current=null;unlocking.current=null};
 },[]);
 async function toggleSound(){
  const intent=++soundIntent.current,next=!prefs.current.sound;prefs.current.sound=next;setSound(next);persist();
  if(!next){setAudioReady(false);unlocking.current=null;audio.current?.mute();return}
  if(!await unlockAudio()&&intent===soundIntent.current&&audio.current&&prefs.current.sound){prefs.current.sound=false;setSound(false);persist()}
 }
 function setInstant(value:boolean){prefs.current.instant=value;setInstantState(value);persist();try{localStorage.setItem('hex-confluence-animation',value?'instant':'animated')}catch{}}
 function setMix(value:Partial<AudioMix>){prefs.current.mix={...prefs.current.mix,...value};setMixState(prefs.current.mix);audio.current?.configure(prefs.current.mix);persist()}
 return {audio,sound,audioReady,toggleSound,instant,setInstant,mix,setMix};
}
