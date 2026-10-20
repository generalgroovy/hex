import type {CSSProperties} from 'react';
import {placeCharacterSpeech,speechLines,type CharacterReaction,type SpeechRect} from '../../lib/character-reactions-v45';
import './character-speech-v45.css';
export default function CharacterSpeechV45({reaction,name,anchor,viewport,obstacles,viewCenter,screenScale}:{reaction:CharacterReaction;name:string;anchor:{x:number;y:number};viewport:{width:number;height:number};obstacles:SpeechRect[];viewCenter:{x:number;y:number};screenScale:number}){
 const lines=speechLines(reaction.line),height=lines.length>1?64:46;
 const placement=placeCharacterSpeech(anchor,viewport,obstacles,{width:184,height});if(!placement)return null;
 const x=viewCenter.x+(placement.x-viewport.width/2)*screenScale,y=viewCenter.y+(placement.y-viewport.height/2)*screenScale;
 const ax=anchor.x-placement.x,ay=anchor.y-placement.y;
 const tailX=Math.max(0,Math.min(placement.width,ax)),tailY=Math.max(0,Math.min(height,ay));
 const distance=Math.hypot(ax-tailX,ay-tailY),fraction=distance?Math.min(8,distance)/distance:0;
 const colors={fire:'#ad4b26',water:'#257c98',earth:'#806037',air:'#5b7935',light:'#92701f',dark:'#754b9b'};
 return <g className="px45-speech" data-character-speech={reaction.unitId} data-speech-reason={reaction.reason} data-speech-element={reaction.element} style={{'--speech-accent':reaction.element?colors[reaction.element]:'#516450'} as CSSProperties} transform={`translate(${x} ${y}) scale(${screenScale})`} pointerEvents="none" role="img" aria-label={`${name}: ${reaction.line}`}>
  <path className="px45-speech-tail" d={`M${tailX} ${tailY}L${tailX+(ax-tailX)*fraction} ${tailY+(ay-tailY)*fraction}`} />
  <g className="px45-speech-card"><path d={`M4 0H${placement.width-4}v4h4V${height-4}h-4v4H4v-4H0V4h4Z`}/>
   <text className="px45-speaker" x="9" y="15">{name.length>24?name.slice(0,23)+'…':name}</text>
   {lines.map((line,index)=><text key={index} className="px45-speech-line" x="9" y={34+index*17}>{line}</text>)}
  </g>
 </g>;
}
