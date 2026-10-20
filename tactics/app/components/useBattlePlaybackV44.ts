"use client";
import {useEffect,useRef,type RefObject} from 'react';
import {createPlaybackClockV44,type PlaybackChange,type PlaybackClockV44} from '../../lib/playback-clock-v44';
import type {GameAudio} from '../../lib/game-audio-v16';
import type {ResolutionPhase} from '../../lib/feedback-v16';
import type {SimEvent} from '../../lib/tactics-v16';
export default function useBattlePlaybackV44(options:{audio:RefObject<GameAudio|null>;sound:boolean;onPhase:(phase:ResolutionPhase)=>void;onComplete:()=>void}){
 const latest=useRef(options);latest.current=options;
 const owner=useRef<PlaybackClockV44|null>(null);owner.current??=createPlaybackClockV44();
 const clock=owner.current,events=useRef<SimEvent[]>([]);
 useEffect(()=>{
  const changed=(change:PlaybackChange)=>{
   const snapshot=clock.read(),current=latest.current;
   if(change==='stop'){current.audio.current?.cancel();return}
   current.onPhase(snapshot.phase);
   if(change==='complete'){current.audio.current?.cancel();current.onComplete();return}
   if(change==='pause'||change==='seek'){current.audio.current?.cancel();return}
   if(change==='start'||change==='resume'||change==='speed'){
    current.audio.current?.cancel();
    if(current.sound&&!snapshot.paused&&snapshot.active)current.audio.current?.playResolution(events.current,{elapsedMs:snapshot.elapsed,speed:snapshot.speed});
   }
  };
  const unsubscribe=clock.subscribe(changed);
  return()=>{unsubscribe();clock.stop()};
 },[clock]);
 useEffect(()=>{
  const snapshot=clock.read(),current=latest.current;
  if(!snapshot.active)return;
  current.audio.current?.cancel();
  if(current.sound&&!snapshot.paused)current.audio.current?.playResolution(events.current,{elapsedMs:snapshot.elapsed,speed:snapshot.speed});
 },[clock,options.sound]);
 return {clock,startReplay:(next:SimEvent[])=>{events.current=next;clock.start()}};
}
