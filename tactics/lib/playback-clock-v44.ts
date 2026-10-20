import {PHASE_MS,RESOLUTION_MS,type ResolutionPhase} from './feedback-v16.ts';
export type PlaybackSnapshot={elapsed:number;phase:ResolutionPhase;paused:boolean;speed:number;active:boolean;complete:boolean};
export type PlaybackChange='start'|'phase'|'pause'|'resume'|'seek'|'speed'|'complete'|'stop';
export type PlaybackClockV44={
 read:()=>PlaybackSnapshot;subscribe:(listener:(change:PlaybackChange)=>void)=>()=>void;subscribeFrame:(listener:(elapsed:number)=>void)=>()=>void;
 start:()=>void;pause:()=>void;resume:()=>void;step:()=>void;setSpeed:(speed:number)=>void;finish:()=>void;stop:()=>void;dispose:()=>void;
};
type Scheduler={now:()=>number;request:(callback:(time:number)=>void)=>number;cancel:(id:number)=>void};
export const playbackPhase=(elapsed:number):ResolutionPhase=>elapsed<PHASE_MS.cast?'move':elapsed<PHASE_MS.impact?'cast':elapsed<PHASE_MS.settle?'impact':'settle';
/** Local presentation only. It never calls the resolver or changes network readiness. */
export function createPlaybackClockV44(scheduler:Scheduler={now:()=>performance.now(),request:callback=>requestAnimationFrame(callback),cancel:id=>cancelAnimationFrame(id)}):PlaybackClockV44{
 let value:PlaybackSnapshot={elapsed:0,phase:'move',paused:false,speed:1,active:false,complete:false},last=0,frame:number|null=null,disposed=false;
 const listeners=new Set<(change:PlaybackChange)=>void>(),frames=new Set<(elapsed:number)=>void>();
 const emit=(change:PlaybackChange)=>{for(const listener of [...listeners])listener(change)};
 const paint=()=>{for(const listener of [...frames])listener(value.elapsed)};
 const clear=()=>{if(frame!==null)scheduler.cancel(frame);frame=null};
 function advance(now:number){
  const oldPhase=value.phase;
  value={...value,elapsed:Math.min(RESOLUTION_MS,value.elapsed+Math.max(0,now-last)*value.speed)};last=now;
  value.phase=playbackPhase(value.elapsed);
  if(value.elapsed>=RESOLUTION_MS){value={...value,active:false,complete:true,paused:false};clear();emit('complete')}
  else if(oldPhase!==value.phase)emit('phase');
  paint();
 }
 function schedule(){if(frame===null&&value.active&&!value.paused&&!disposed)frame=scheduler.request(now=>{frame=null;advance(now);schedule()})}
 function synchronize(){if(value.active&&!value.paused)advance(scheduler.now())}
 function stop(){clear();value={...value,active:false,paused:false};emit('stop')}
 return {
  read:()=>({...value}),
  subscribe:listener=>{listeners.add(listener);return()=>{listeners.delete(listener)}},
  subscribeFrame:listener=>{frames.add(listener);return()=>{frames.delete(listener)}},
  start:()=>{if(disposed)return;clear();value={...value,elapsed:0,phase:'move',active:true,paused:false,complete:false};last=scheduler.now();emit('start');paint();schedule()},
  pause:()=>{if(!value.active||value.paused)return;synchronize();if(!value.active)return;clear();value={...value,paused:true};emit('pause');paint()},
  resume:()=>{if(!value.active||!value.paused)return;value={...value,paused:false};last=scheduler.now();emit('resume');schedule()},
  step:()=>{if(!value.active)return;clear();const next=[PHASE_MS.cast,PHASE_MS.impact,PHASE_MS.settle,RESOLUTION_MS].find(time=>time>value.elapsed+.1)??RESOLUTION_MS;value={...value,elapsed:next,phase:playbackPhase(next),paused:next<RESOLUTION_MS,active:next<RESOLUTION_MS,complete:next===RESOLUTION_MS};last=scheduler.now();emit(next===RESOLUTION_MS?'complete':'seek');paint()},
  setSpeed:speed=>{if(![.5,1,1.5,2].includes(speed)||speed===value.speed)return;synchronize();value={...value,speed};last=scheduler.now();emit('speed');schedule()},
  finish:()=>{clear();value={...value,elapsed:RESOLUTION_MS,phase:'settle',active:false,paused:false,complete:true};emit('complete');paint()},
  stop,
  dispose:()=>{clear();disposed=true;listeners.clear();frames.clear()},
 };
}

/** Phase-local sprite/callout clocks start at the same boundary after a seek. */
export function playbackAnimationOrigin(action:string|null,callout=false,terrainArrival=false):number{
 if(callout||action==='defeat')return PHASE_MS.settle;
 if(terrainArrival)return PHASE_MS.impact;
 if(action==='cast')return PHASE_MS.cast;
 if(action==='hit')return PHASE_MS.impact;
 return 0;
}
