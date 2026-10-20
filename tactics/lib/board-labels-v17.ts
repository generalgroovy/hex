import type {Point} from './game.ts';
const onBoard=(p:Point,radius:number)=>Number.isInteger(p.q)&&Number.isInteger(p.r)&&Math.max(Math.abs(p.q),Math.abs(p.r),Math.abs(p.q+p.r))<=radius;
function columnName(index:number):string{let name='';for(let n=index+1;n>0;n=Math.floor((n-1)/26))name=String.fromCharCode(65+(n-1)%26)+name;return name;}
export function formatTile(point:Point,radius:number):string {
  if(!onBoard(point,radius))return '—';
  return `${columnName(point.q+Math.floor(point.r/2)+radius)}${point.r+radius+1}`;
}
export function parseTile(label:string,radius:number):Point|null {
  const match=/^([A-Z]{1,2})([1-9][0-9]?)$/.exec(label.trim().toUpperCase());if(!match)return null;
  const column=[...match[1]].reduce((sum,c)=>sum*26+c.charCodeAt(0)-64,0)-1;
  const r=Number(match[2])-radius-1,p={q:column-radius-Math.floor(r/2),r};return onBoard(p,radius)?p:null;
}
