"use client";
import {useEffect,useLayoutEffect,useRef,useState,type CSSProperties} from 'react';
import {animationView,animationColumnPosition,characterFrameCss,type FrameAction} from '../../lib/character-animation';
import {animationAtlasDimensionsMatch,spriteEdgeMask} from '../../lib/sprite-integrity-v42';
import PixelChampion from './PixelChampion';
import './champion-frames.css';

export default function ChampionFrames({id,action='idle',facing=0,size=128,paused=false,releaseMs=400,frame}:{id:string;action?:FrameAction;facing?:number;size?:number;paused?:boolean;releaseMs?:number;frame?:number}){
 const view=animationView(facing),timing=characterFrameCss(id,action,size,releaseMs);
 const [loaded,setLoaded]=useState({id:'',token:-1,delay:0}),[phaseToken,setPhaseToken]=useState(0);
 const clock=useRef({id,action,started:0,token:0});
 useLayoutEffect(()=>{const token=clock.current.token+1;clock.current={id,action,started:performance.now(),token};setPhaseToken(token)},[id,action]);
 const image=useRef<HTMLImageElement>(null);
 const ready=()=>{const source=image.current;if(!source||!animationAtlasDimensionsMatch(source.naturalWidth,source.naturalHeight))return;const phase=clock.current;setLoaded({id,token:phase.token,delay:phase.started?Math.max(0,performance.now()-phase.started):0})};
 useEffect(()=>{if(image.current?.complete&&image.current.naturalWidth>0)ready()},[id]);
 const base=action==='hit'?6:action==='defeat'?7:action==='cast'?3:0;
 const style={'--pf-size':`${size}px`,'--pf-view':view.view,'--pf-flip':view.flip,'--pf-base-row':base,'--pf-use-view':action==='hit'||action==='defeat'?0:1,'--pf-duration':`${timing.duration}ms`,'--pf-animation':timing.name,'--pf-delay':`${loaded.id===id&&loaded.token===phaseToken?-loaded.delay:0}ms`,'--pf-iterations':timing.loop?'infinite':'1',width:size,height:size} as CSSProperties;
 return <span className={`pf-champion pf-${action}${paused?' pf-paused':''}${frame!==undefined?' pf-manual':''}`} data-character={id} data-frame-action={action} data-frame-count={6} data-animation-ready={loaded.id===id} data-cast-release={action==='cast'?releaseMs:undefined} style={style} aria-hidden="true"><style>{timing.css}</style><img ref={image} className="pf-preload" src={`/pixel/animations/${id}.webp`} alt="" onLoad={ready}/>{loaded.id!==id?<PixelChampion id={id} action={action} facing={facing} size={size} paused={paused} castLeadMs={releaseMs}/>:<span className="pf-direction"><span className="pf-paint" style={{backgroundImage:`url("/pixel/animations/${id}.webp")`,maskImage:spriteEdgeMask(id),...(frame!==undefined?{backgroundPositionX:animationColumnPosition(frame),maskPositionX:animationColumnPosition(frame)}: {})}}/></span>}</span>;
}
