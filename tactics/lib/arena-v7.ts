/** Rules 7 geography. Biomes persist beneath the temporary elemental field. */
import { distance, type Point } from './game.ts';

export const ARENA_RADIUS = 9;
export const ARENA_STARTS: [Point[], Point[]] = [
  [{q:-6,r:0},{q:-6,r:3},{q:-6,r:6}],
  [{q:6,r:0},{q:6,r:-3},{q:6,r:-6}],
];
export type Biome = 'plain'|'earth'|'water'|'forest'|'marsh'|'ruins';
export type BaseTerrain = 'plain'|'earth'|'water';
export type ArenaCell = Point & {well:boolean;biome:Biome;terrain:BaseTerrain;height:0|1};
export const BIOME_NAMES:Record<Biome,string> = {plain:'Meadow',earth:'High ground',water:'Shallows',forest:'Forest',marsh:'Marsh',ruins:'Ruins'};
export const biomeElement = (biome:Biome):BaseTerrain => biome==='forest'||biome==='ruins'?'earth':biome==='marsh'?'water':biome;
const key=({q,r}:Point)=>`${q||0},${r||0}`;
const opposite=({q,r}:Point):Point=>({q:-q||0,r:-r||0});
const dirs:Point[]=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
const half=(p:Point)=>p.q<0||(p.q===0&&p.r<0);
const cache=new Map<string,ReadonlyArray<Readonly<ArenaCell>>>();

export function normalizeArenaMapId(input:unknown):string {
  if(typeof input!=='string')throw new Error('Enter a battlefield seed using 1–24 letters, digits or hyphens.');
  const value=input.trim();if(value.toLowerCase()==='confluence')return 'frontier:WELLSPRING';
  const match=/^(?:frontier|reach):([a-z0-9-]{1,24})$/i.exec(value);
  if(!match)throw new Error('Enter a battlefield seed using 1–24 letters, digits or hyphens.');
  return `frontier:${match[1].toUpperCase()}`;
}
export const arenaSeed=(mapId:string)=>normalizeArenaMapId(mapId).slice(9);

/** Frozen generator v2: bounded seeded choices, mirrored costs and no disconnected pockets. */
export function generateArena(mapId='confluence'):ReadonlyArray<Readonly<ArenaCell>> {
  const canonical=normalizeArenaMapId(mapId),cached=cache.get(canonical);if(cached)return cached;
  let hash=2166136261;for(const char of arenaSeed(canonical)){hash^=char.charCodeAt(0);hash=Math.imul(hash,16777619)>>>0;}
  const random=()=>{hash=(Math.imul(hash,1664525)+1013904223)>>>0;return hash/4294967296;};
  const points:Point[]=[];for(let q=-ARENA_RADIUS;q<=ARENA_RADIUS;q++)for(let r=-ARENA_RADIUS;r<=ARENA_RADIUS;r++)if(distance({q,r},{q:0,r:0})<=ARENA_RADIUS)points.push({q,r});
  // Flanks stay four or more hexes from every spawn; either seat has mirrored approaches.
  const north=[{q:0,r:5},{q:0,r:6},{q:-1,r:6},{q:1,r:5}];
  const west=[{q:-2,r:-1},{q:-2,r:-2},{q:-1,r:-2}];
  const flank=[north[Math.floor(random()*north.length)],west[Math.floor(random()*west.length)]];
  const wells:Point[]=[{q:0,r:0},...flank,...flank.map(opposite)];
  const wellKeys=new Set(wells.map(key)),startKeys=new Set(ARENA_STARTS.flat().map(key));
  const biomes=new Map(points.map(p=>[key(p),'plain' as Biome]));
  const candidates=points.filter(p=>half(p)&&!wellKeys.has(key(p))&&!startKeys.has(key(p)));
  const setPair=(p:Point,biome:Biome)=>{biomes.set(key(p),biome);biomes.set(key(opposite(p)),biome);};
  const safe=(p:Point)=>!ARENA_STARTS.flat().some(s=>distance(s,p)<=1)&&!wells.some(w=>distance(w,p)<=1);
  const connected=()=>{const seen=new Set(['0,0']),queue:Point[]=[{q:0,r:0}];for(let i=0;i<queue.length;i++)for(const d of dirs){const p={q:queue[i].q+d.q,r:queue[i].r+d.r},k=key(p);if(biomes.has(k)&&biomes.get(k)!=='ruins'&&!seen.has(k)){seen.add(k);queue.push(p);}}return seen.size===points.length-[...biomes.values()].filter(v=>v==='ruins').length;};
  // Small ruin groups create routes without cutting off any playable cell.
  const ruins:Point[]=[];
  for(let i=0;i<8;i++){
    const options=candidates.filter(p=>biomes.get(key(p))==='plain'&&safe(p));
    const adjacent=options.filter(p=>ruins.some(v=>distance(v,p)===1));
    const pool=i%3!==0&&adjacent.length?adjacent:options;
    const start=Math.floor(random()*pool.length);let placed=false;
    for(let j=0;j<pool.length;j++){const p=pool[(start+j)%pool.length];setPair(p,'ruins');if(connected()){ruins.push(p);placed=true;break;}setPair(p,'plain');}
    if(!placed)throw new Error('Seed has no connected ruin placement.');
  }
  // Patches retain visible shape; disconnected frontier fallback starts a new patch.
  function grow(biome:Biome,count:number,patchSize:number) {
    let patch:Point[]=[];
    for(let i=0;i<count;i++){
      const available=candidates.filter(p=>biomes.get(key(p))==='plain');
      const frontier=i%patchSize?available.filter(p=>patch.some(v=>distance(v,p)===1)):[];
      const pool=frontier.length?frontier:available;
      if(!frontier.length)patch=[];
      const p=pool[Math.floor(random()*pool.length)];if(!p)throw new Error('Seed has no terrain placement.');setPair(p,biome);patch.push(p);
    }
  }
  grow('earth',10,5);grow('water',10,5);grow('forest',12,4);grow('marsh',8,4);
  const result=Object.freeze(points.map(p=>{const biome=biomes.get(key(p))!;return Object.freeze({...p,well:wellKeys.has(key(p)),biome,terrain:biomeElement(biome),height:(biome==='earth'?1:0) as 0|1});}));
  if(cache.size>=64)cache.delete(cache.keys().next().value!);cache.set(canonical,result);return result;
}
export const arenaHeightAt=(q:number,r:number,mapId='confluence'):0|1=>generateArena(mapId).find(c=>c.q===q&&c.r===r)?.height??0;
export const arenaWellAt=(q:number,r:number,mapId='confluence')=>generateArena(mapId).some(c=>c.q===q&&c.r===r&&c.well);
export const arenaBiomeAt=(q:number,r:number,mapId='confluence'):Biome=>generateArena(mapId).find(c=>c.q===q&&c.r===r)?.biome??'plain';
export const baseTerrainAt=(q:number,r:number,mapId='confluence'):BaseTerrain=>biomeElement(arenaBiomeAt(q,r,mapId));
// These default-seed exports retain the familiar map metadata interface.
export const ARENA_TERRACES=generateArena().filter(cell=>cell.biome==='earth').map(({q,r})=>({q,r}));
export const ARENA_STREAMS=generateArena().filter(cell=>cell.biome==='water').map(({q,r})=>({q,r}));
