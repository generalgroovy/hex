"use client";
import {useEffect,useState} from 'react';
import type {PlaybackClockV44} from '../../lib/playback-clock-v44';
export default function PlaybackControlsV44({clock}:{clock:PlaybackClockV44}){
 const [snapshot,setSnapshot]=useState(clock.read);
 useEffect(()=>clock.subscribe(()=>setSnapshot(clock.read())),[clock]);
 return <div className="playback-v44" aria-label="Local replay controls">
  <button type="button" onClick={()=>snapshot.paused?clock.resume():clock.pause()} aria-pressed={snapshot.paused}>{snapshot.paused?'Resume':'Pause'}</button>
  <button type="button" onClick={clock.step}>Next phase</button>
  <label><span>Speed</span><select aria-label="Replay speed" value={snapshot.speed} onChange={event=>clock.setSpeed(Number(event.target.value))}><option value=".5">½×</option><option value="1">1×</option><option value="1.5">1½×</option><option value="2">2×</option></select></label>
  <button type="button" onClick={clock.finish}>Show result</button>
 </div>;
}
