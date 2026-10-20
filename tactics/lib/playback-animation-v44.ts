import type {PlaybackSnapshot} from './playback-clock-v44.ts';

export type TimedPlaybackAnimation={animation:Animation;origin:number};
/** Native animations run between controls; seeking/pause aligns them exactly.
 * Finished finite effects stay at their final time instead of play() rewinding. */
export function synchronizePlaybackAnimations(animations:readonly TimedPlaybackAnimation[],snapshot:PlaybackSnapshot){
 for(const {animation,origin} of animations)try{
  const localTime=Math.max(0,snapshot.elapsed-origin);
  animation.playbackRate=snapshot.speed;
  animation.currentTime=localTime;
  const end=Number(animation.effect?.getComputedTiming().endTime??Infinity);
  if(snapshot.paused||!snapshot.active||localTime>=end)animation.pause();
  else animation.play();
 }catch{/* A detached effect may disappear between DOM commit and collection. */}
}
