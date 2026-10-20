"use client";
import {useLayoutEffect,type RefObject} from 'react';
import {playbackAnimationOrigin,type PlaybackClockV44} from '../../lib/playback-clock-v44';
import {synchronizePlaybackAnimations} from '../../lib/playback-animation-v44';
import type {ResolutionPhase} from '../../lib/feedback-v16';

/** One browser animation timeline, driven by the same clock as phase labels/audio.
 * We collect after DOM changes, not on every frame of a large battlefield. */
export default function usePlaybackAnimationsV44(svgRef:RefObject<SVGSVGElement|null>,clock:PlaybackClockV44|undefined,active:boolean,key:string,phase:ResolutionPhase){
 useLayoutEffect(()=>{
  const svg=svgRef.current;if(!svg||!clock||!active)return;
  let animations:{animation:Animation;origin:number;resume:boolean;rate:number}[]=[];
  let hasSmil=false;
  const paintSmil=(elapsed:number)=>{if(hasSmil)try{svg.pauseAnimations();svg.setCurrentTime(elapsed/1000)}catch{}};
  const synchronize=()=>{synchronizePlaybackAnimations(animations,clock.read());paintSmil(clock.read().elapsed)};
  const collect=()=>{
   const previous=new Map(animations.map(entry=>[entry.animation,entry]));
   animations=svg.getAnimations({subtree:true}).map(animation=>{
    const target=(animation.effect as KeyframeEffect|null)?.target;
    const element=target instanceof Element?target:null;
    const character=element?.closest('[data-frame-action],[data-creature-action],.px-crafted');
    const action=character?.getAttribute('data-frame-action')??character?.getAttribute('data-creature-action')??[...character?.classList??[]].find(name=>name.startsWith('px-action-'))?.slice(10)??null;
    return {animation,origin:playbackAnimationOrigin(action,!!element?.closest('[data-combat-callout]'),!!element?.closest('[data-terrain-arrival]')),resume:previous.get(animation)?.resume??animation.playState==='running',rate:previous.get(animation)?.rate??animation.playbackRate};
   });
   hasSmil=!!svg.querySelector('animate,animateMotion,animateTransform,set');
   synchronize();
  };
  const observer=new MutationObserver(collect);
  // Loaded atlas frames and phase-local actors can appear after the first paint.
  observer.observe(svg,{childList:true,subtree:true,attributes:true,attributeFilter:['class','data-animation-ready','data-frame-action','data-creature-action']});
  collect();const unsubscribe=clock.subscribe(synchronize),unsubscribeSmil=clock.subscribeFrame(paintSmil);
  return()=>{observer.disconnect();unsubscribe();unsubscribeSmil();for(const entry of animations)try{entry.animation.playbackRate=entry.rate;if(entry.resume&&entry.animation.playState==='paused')entry.animation.play()}catch{}if(hasSmil)try{svg.unpauseAnimations()}catch{}};
 },[svgRef,clock,active,key,phase]);
}
