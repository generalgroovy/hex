import {ARENA_RADIUS} from './arena-v7.ts';
import type {Point} from './game.ts';

const onBoard=({q,r}:Point)=>Number.isInteger(q)&&Number.isInteger(r)&&Math.max(Math.abs(q),Math.abs(r),Math.abs(q+r))<=ARENA_RADIUS;

/** Staggered screen columns run left to right; rows run top to bottom.
 * The display reference never replaces axial coordinates in game or room state. */
export function formatTile(point:Point):string {
  if(!onBoard(point))return '—';
  const column=point.q+Math.floor(point.r/2)+ARENA_RADIUS;
  return `${String.fromCharCode(65+column)}${point.r+ARENA_RADIUS+1}`;
}

/** Return null for labels in the rectangular corners outside the hexagonal map. */
export function parseTile(label:string):Point|null {
  const match=/^([A-S])([1-9]|1[0-9])$/.exec(label.trim().toUpperCase());
  if(!match)return null;
  const r=Number(match[2])-ARENA_RADIUS-1;
  const q=match[1].charCodeAt(0)-65-ARENA_RADIUS-Math.floor(r/2);
  const point={q,r};
  return onBoard(point)?point:null;
}
