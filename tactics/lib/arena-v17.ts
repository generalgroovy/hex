/** Seeded 2–6 company battlefields. Geometry is frozen by map ID. */
import {distance,type Point} from './game.ts';
import {biomeElement,type Biome,type BaseTerrain,type ArenaCell} from './arena-v7.ts';
import {applyTowerMotif} from './tower-terrain-v44.ts';
export type {Biome,BaseTerrain,ArenaCell};
export type PlayerCount=2|3|4|5|6;
const DIRS:Point[]=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
const key=(p:Point)=>`${p.q||0},${p.r||0}`;
const cache=new Map<string,ReadonlyArray<Readonly<ArenaCell>>>();
export function validatePlayerCount(value:unknown):PlayerCount {
  if(!Number.isInteger(value)||Number(value)<2||Number(value)>6)throw new Error('Choose 2 to 6 players.');
  return value as PlayerCount;
}
export function normalizeArenaMapId(input:unknown,playerCount?:PlayerCount):string {
  if(typeof input!=='string')throw new Error('Enter a seed using 1–24 letters, digits or hyphens.');
  const text=input.trim(),match=/^arena:([2-6]):([a-z0-9-]{1,24})(:m44-(?:crossing|courtyard|grove))?$/i.exec(text);
  if(match){if(playerCount!==undefined&&Number(match[1])!==playerCount)throw new Error('Map and player count disagree.');return `arena:${match[1]}:${match[2].toUpperCase()}${match[3]?.toLowerCase()??''}`;}
  const seed=/^(?:frontier:|reach:)?([a-z0-9-]{1,24})$/i.exec(text)?.[1];
  if(!seed)throw new Error('Enter a seed using 1–24 letters, digits or hyphens.');
  return `arena:${validatePlayerCount(playerCount??2)}:${seed.toLowerCase()==='confluence'?'WELLSPRING':seed.toUpperCase()}`;
}
export const arenaPlayerCount=(mapId:string):PlayerCount=>Number(normalizeArenaMapId(mapId).split(':')[1]) as PlayerCount;
export const arenaSeed=(mapId:string)=>normalizeArenaMapId(mapId).split(':')[2];
export const arenaRadius=(mapId:string)=>arenaPlayerCount(mapId)+7;
export const arenaSize=(mapId:string)=>1+3*arenaRadius(mapId)*(arenaRadius(mapId)+1);
const plane=(p:Point)=>({x:p.q+p.r/2,y:Math.sqrt(3)*p.r/2});
const angleDistance=(a:number,b:number)=>Math.abs(Math.atan2(Math.sin(a-b),Math.cos(a-b)));
function ring(radius:number):Point[]{const cells:Point[]=[];for(let q=-radius;q<=radius;q++)for(let r=-radius;r<=radius;r++)if(distance({q,r},{q:0,r:0})===radius)cells.push({q,r});return cells;}
/** Equal radial distance, evenly separated sectors, no shared deployment hexes. */
export function arenaStarts(mapId:string):Point[][] {
  const count=arenaPlayerCount(mapId),radius=arenaRadius(mapId)-3,candidates=ring(radius);
  return Array.from({length:count},(_,seat)=>{
    const angle=Math.PI+seat*Math.PI*2/count;
    const ordered=[...candidates].sort((a,b)=>angleDistance(Math.atan2(plane(a).y,plane(a).x),angle)-angleDistance(Math.atan2(plane(b).y,plane(b).x),angle)||a.q-b.q||a.r-b.r);
    const centre=ordered[0];
    // A triangular camp keeps all three units close, with equal inward reach.
    const neighbours=DIRS.map(d=>({q:centre.q+d.q,r:centre.r+d.r})).filter(p=>distance(p,{q:0,r:0})===radius);
    neighbours.sort((a,b)=>a.q-b.q||a.r-b.r);
    return [{...centre},neighbours[0],neighbours.at(-1)!];
  });
}
export function generateArena(mapId='arena:2:WELLSPRING'):ReadonlyArray<Readonly<ArenaCell>> {
  const canonical=normalizeArenaMapId(mapId),cached=cache.get(canonical);if(cached)return cached;
  const radius=arenaRadius(canonical),starts=arenaStarts(canonical),points:Point[]=[];
  let hash=2166136261;for(const c of canonical){hash^=c.charCodeAt(0);hash=Math.imul(hash,16777619)>>>0;}
  const random=()=>{hash=(Math.imul(hash,1664525)+1013904223)>>>0;return hash/4294967296;};
  for(let q=-radius;q<=radius;q++)for(let r=-radius;r<=radius;r++)if(distance({q,r},{q:0,r:0})<=radius)points.push({q,r});
  const biomes=new Map(points.map(p=>[key(p),'plain' as Biome]));
  const camps=new Set(points.filter(p=>starts.flat().some(start=>distance(start,p)<=1)).map(key));
  // Inner springs and direct approaches provide equal travel cost from each camp.
  const roads=new Set<string>(),wells=new Set<string>(['0,0']);
  for(const company of starts)for(let index=0;index<company.length;index++){
    let at={...company[index]},steps=0;roads.add(key(at));
    while(distance(at,{q:0,r:0})>0){
      const next=DIRS.map(d=>({q:at.q+d.q,r:at.r+d.r})).filter(p=>distance(p,{q:0,r:0})<distance(at,{q:0,r:0}));
      next.sort((a,b)=>Math.abs(plane(a).x*plane(company[index]).y-plane(a).y*plane(company[index]).x)-Math.abs(plane(b).x*plane(company[index]).y-plane(b).y*plane(company[index]).x)||a.q-b.q||a.r-b.r);
      at=next[0];roads.add(key(at));steps++;if(index===0&&steps===3)wells.add(key(at));
    }
  }
  const available=()=>points.filter(p=>!camps.has(key(p))&&!wells.has(key(p))&&biomes.get(key(p))==='plain');
  function grow(biome:Biome,count:number,patchSize:number){let patch:Point[]=[];for(let i=0;i<count;i++){
    const options=available().filter(p=>biome!=='ruins'||!roads.has(key(p)));
    const frontier=i%patchSize?options.filter(p=>patch.some(v=>distance(v,p)===1)):[];
    const pool=frontier.length?frontier:options;if(!pool.length)break;
    if(!frontier.length)patch=[];const p=pool[Math.floor(random()*pool.length)];biomes.set(key(p),biome);patch.push(p);
  }}
  grow('ruins',Math.floor(points.length*.065),3);grow('earth',Math.floor(points.length*.105),7);grow('water',Math.floor(points.length*.095),7);grow('forest',Math.floor(points.length*.14),6);grow('marsh',Math.floor(points.length*.08),4);
  // The shortest approach stays one effort per step; forests/shallow pools retain identity.
  for(const p of points)if(roads.has(key(p))&&['earth','marsh','ruins'].includes(biomes.get(key(p))!))biomes.set(key(p),'plain');
  for(const k of wells)biomes.set(k,'plain');
  applyTowerMotif(canonical,points,biomes,wells);
  // Every walkable hex is reachable; remove only ruin blockers bordering disconnected pockets.
  const reachable=()=>{const seen=new Set(['0,0']),queue:Point[]=[{q:0,r:0}];for(let i=0;i<queue.length;i++)for(const d of DIRS){const p={q:queue[i].q+d.q,r:queue[i].r+d.r},k=key(p);if(biomes.has(k)&&biomes.get(k)!=='ruins'&&!seen.has(k)){seen.add(k);queue.push(p);}}return seen;};
  let seen=reachable();while(points.some(p=>biomes.get(key(p))!=='ruins'&&!seen.has(key(p)))){
    const blocker=points.find(p=>biomes.get(key(p))==='ruins'&&DIRS.some(d=>seen.has(key({q:p.q+d.q,r:p.r+d.r})))&&DIRS.some(d=>{const k=key({q:p.q+d.q,r:p.r+d.r});return biomes.has(k)&&!seen.has(k);}));
    if(!blocker)throw new Error('Unable to connect arena.');biomes.set(key(blocker),'plain');seen=reachable();
  }
  const result=Object.freeze(points.map(p=>{const biome=biomes.get(key(p))!;return Object.freeze({...p,well:wells.has(key(p)),biome,terrain:biomeElement(biome),height:(biome==='earth'?1:0) as 0|1});}));
  if(cache.size>=32)cache.delete(cache.keys().next().value!);cache.set(canonical,result);return result;
}
export const arenaHeightAt=(q:number,r:number,mapId:string):0|1=>generateArena(mapId).find(c=>c.q===q&&c.r===r)?.height??0;
export const arenaWellAt=(q:number,r:number,mapId:string)=>generateArena(mapId).some(c=>c.q===q&&c.r===r&&c.well);
export const arenaBiomeAt=(q:number,r:number,mapId:string):Biome=>generateArena(mapId).find(c=>c.q===q&&c.r===r)?.biome??'plain';
export const baseTerrainAt=(q:number,r:number,mapId:string):BaseTerrain=>biomeElement(arenaBiomeAt(q,r,mapId));
