"use client";

import type {CSSProperties} from 'react';
import {CHAMPIONS} from '../../lib/roster';
import {characterMotion,characterMotionStyle,characterCastAnimation,spriteFacing} from '../../lib/character-motion';
import './pixel-battlefield.css';
import './pixel-champion.css';

export type PixelAction = 'idle' | 'walk' | 'cast' | 'hit' | 'defeat';
export type PixelChampionProps = {id:string;action?:PixelAction;facing?:number;size?:number;className?:string;paused?:boolean;motion?:'quiet'|'full';castLeadMs?:number};

/** A whole original 128px cell; the feet are at (64,104), not the bottom edge. */
export default function PixelChampion({id,action='idle',facing=0,size=128,className='',paused=false,motion='quiet',castLeadMs=120}:PixelChampionProps) {
  const character = CHAMPIONS.find(entry=>entry.id===id);
  if (!character) return <span className={`px-champion px-champion-missing ${className}`} aria-hidden="true" style={{width:size,height:size}}>?</span>;
  const direction = spriteFacing(facing),profile=characterMotion(id);
  const row = action==='cast'?3:action==='walk'?1:0;
  const cast=action==='cast'?characterCastAnimation(id,size,direction,castLeadMs):null;
  const style = {...characterMotionStyle(id,size,direction),'--px-size':`${size}px`,'--px-face-x':`${-direction*size}px`,'--px-frame-y':`${-row*size}px`,...(cast?{'--px-crafted-cast-total':`${cast.durationMs}ms`,'--px-crafted-cast-gesture':cast.name,'--px-crafted-cast-frames':cast.poseName}:{}),backgroundImage:`url("${character.sprite}")`,width:size,height:size} as CSSProperties;
  return <span aria-hidden="true" data-character={id} data-motion-voice={profile.voice} data-motion-mass={profile.mass} data-cast-release={cast?.releaseMs} className={`px-champion px-crafted px-action-${action} px-voice-${profile.voice} px-motion-${motion}${paused?' px-paused':''} ${className}`} style={style}>{cast&&<style>{cast.css}</style>}</span>;
}
