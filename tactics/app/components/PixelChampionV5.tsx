"use client";

import type {CSSProperties} from 'react';
import {CHAMPIONS} from '../../lib/roster';
import './pixel-battlefield-v5.css';

export type PixelAction = 'idle' | 'walk' | 'cast' | 'hit' | 'defeat';
export type PixelChampionProps = {id:string;action?:PixelAction;facing?:number;size?:number;className?:string;paused?:boolean};

/** A whole original 128px cell; the feet are at (64,104), not the bottom edge. */
export default function PixelChampion({id,action='idle',facing=0,size=128,className='',paused=false}:PixelChampionProps) {
  const character = CHAMPIONS.find(entry=>entry.id===id);
  if (!character) return <span className={`px5-champion px5-champion-missing ${className}`} aria-hidden="true" style={{width:size,height:size}}>?</span>;
  const direction = Math.max(0,Math.min(7,Math.round(facing)));
  const row = action==='cast'?3:action==='walk'?1:0;
  const style = {'--px5-size':`${size}px`,'--px5-face-x':`${-direction*size}px`,'--px5-frame-y':`${-row*size}px`,backgroundImage:`url("${character.sprite}")`,width:size,height:size} as CSSProperties;
  return <span aria-hidden="true" className={`px5-champion px5-action-${action}${paused?' px5-paused':''} ${className}`} style={style}/>;
}
