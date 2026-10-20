import {characterMotion,spriteFacing} from './character-motion.ts';
export type FrameAction='idle'|'walk'|'cast'|'hit'|'defeat';
export const ANIMATION_GRID={columns:6,rows:8,cell:128,footX:64,footY:104} as const;
/** The painted front, profile and rear views are mirrored only for left-facing play. */
export function animationView(facing:number){const face=spriteFacing(facing);return {view:face===2||face===6?1:face>=3&&face<=5?2:0,flip:face>=5?-1:1};}
export function animationRow(action:FrameAction,facing:number){return action==='hit'?6:action==='defeat'?7:animationView(facing).view+(action==='cast'?3:0);}
export function animationFrames(id:string,action:FrameAction,releaseMs=400){
 const m=characterMotion(id);
 if(action==='walk'){const duration=Math.round(m.gaitMs*1.7);return {duration,loop:true,frames:[0,1,2,3,4,5].map((frame)=>({frame,at:Math.round(duration*frame/6)}))};}
 if(action==='cast'){const lead=Math.max(0,releaseMs),recovery=m.castMs;return {duration:lead+recovery,loop:false,frames:[{frame:0,at:0},{frame:1,at:Math.round(lead*.34)},{frame:2,at:Math.round(lead*.7)},{frame:3,at:lead},{frame:4,at:lead+Math.round(recovery*.38)},{frame:5,at:lead+Math.round(recovery*.8)}]};}
 const duration=action==='hit'?Math.round(m.hitMs*1.65):action==='defeat'?Math.round(760+(m.mass==='heavy'?180:m.mass==='medium'?90:0)):1;
 return {duration,loop:false,frames:action==='idle'?[{frame:0,at:0}]:[0,1,2,3,4,5].map(frame=>({frame,at:Math.round(duration*[0,.12,.28,.47,.7,.88][frame])}))};
}
export function animationFrameAt(id:string,action:FrameAction,elapsedMs:number,releaseMs=400){const timeline=animationFrames(id,action,releaseMs);const at=timeline.loop?Math.max(0,elapsedMs)%timeline.duration:Math.max(0,elapsedMs);return timeline.frames.findLast(f=>f.at<=at)?.frame??0;}
export function animationColumn(frame:number){return Number.isFinite(frame)?Math.min(ANIMATION_GRID.columns-1,Math.max(0,Math.trunc(frame))):0;}
/** Percentage offsets track the actual rendered cell, including responsive CSS
 * resizing. The art and its exact repair mask must always address the same cel. */
export function animationColumnPosition(frame:number){return `${animationColumn(frame)*100/(ANIMATION_GRID.columns-1)}%`;}
export function characterFrameCss(id:string,action:FrameAction,size:number,releaseMs=400){const timeline=animationFrames(id,action,releaseMs),name=`pf-${id}-${action}-${Math.round(size)}-${releaseMs}`,position=(frame:number)=>`background-position-x:${animationColumnPosition(frame)};mask-position-x:${animationColumnPosition(frame)}`;return {name,...timeline,css:`@keyframes ${name}{${timeline.frames.map(f=>`${(f.at/timeline.duration*100).toFixed(5)}%{${position(f.frame)}}`).join('')}100%{${position(timeline.loop?0:timeline.frames.at(-1)!.frame)}}`};}
