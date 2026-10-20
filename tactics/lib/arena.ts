/** Rules 6's fixed geography. Spell fields temporarily cover, then reveal, this substrate. */
import { distance, type Point } from './game.ts';

export const ARENA_RADIUS = 6;
export const ARENA_STARTS: [Point[], Point[]] = [
  [{ q: -4, r: 0 }, { q: -4, r: 2 }, { q: -4, r: 4 }],
  [{ q: 4, r: 0 }, { q: 4, r: -2 }, { q: 4, r: -4 }],
];
const mirrored = (points: Point[]) => [...points, ...points.map(({ q, r }) => ({ q: -q, r: -r }))];
const key = (q: number, r: number) => `${q || 0},${r || 0}`;
export const ARENA_TERRACES = mirrored([
  { q: -2, r: 0 }, { q: -2, r: 1 }, { q: -2, r: 2 },
  { q: -3, r: 1 }, { q: -3, r: 2 }, { q: -3, r: 3 },
]);
export const ARENA_STREAMS = mirrored([
  { q: -2, r: 4 }, { q: -1, r: 3 }, { q: 0, r: 2 },
  { q: 1, r: 2 }, { q: 2, r: 1 }, { q: 3, r: 0 },
]);
const terraces = new Set(ARENA_TERRACES.map(({ q, r }) => key(q, r)));
const streams = new Set(ARENA_STREAMS.map(({ q, r }) => key(q, r)));
export type ArenaCell = Point & { well: boolean; terrain: 'plain' | 'earth' | 'water'; height: 0 | 1 };
export function normalizeArenaMapId(input: unknown): string {
  if (typeof input !== 'string') throw new Error('Enter a battlefield seed using 1–24 letters, digits or hyphens.');
  const value = input.trim();
  if (value.toLowerCase() === 'confluence') return 'reach:WELLSPRING';
  const matched = /^reach:([a-z0-9-]{1,24})$/i.exec(value);
  if (!matched) throw new Error('Enter a battlefield seed using 1–24 letters, digits or hyphens.');
  return `reach:${matched[1].toUpperCase()}`;
}
export const arenaSeed = (mapId: string) => normalizeArenaMapId(mapId).slice(6);
const directions: Point[] = [{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
const rotate = (point: Point, times: number): Point => { let p = point; for (let i=0;i<times;i++) p={q:-p.r,r:p.q+p.r}; return p; };
const opposite = ({q,r}:Point):Point => ({q:-q,r:-r});
const cache = new Map<string, ReadonlyArray<Readonly<ArenaCell>>>();
/** Generator v1, frozen as part of rules 6. Selection is bounded; no retries or external randomness. */
export function generateArena(mapId = 'confluence'): ReadonlyArray<Readonly<ArenaCell>> {
  const canonical = normalizeArenaMapId(mapId); const existing = cache.get(canonical); if (existing) return existing;
  const seed = arenaSeed(canonical); let hash = 2166136261;
  for (const char of seed) { hash ^= char.charCodeAt(0); hash = Math.imul(hash, 16777619) >>> 0; }
  const random = () => { hash = (Math.imul(hash, 1664525) + 1013904223) >>> 0; return hash / 4294967296; };
  let ground = new Set(terraces); let water = new Set(streams); let wellPositions: Point[] = [{q:0,r:0},{q:0,r:4},{q:0,r:-4}];
  if (seed !== 'WELLSPRING') {
    const outer = [{q:0,r:4},{q:0,r:5},{q:-1,r:5},{q:1,r:4}][Math.floor(random()*4)];
    wellPositions = [{q:0,r:0},outer,opposite(outer)]; const wellKeys = new Set(wellPositions.map(p=>key(p.q,p.r)));
    const startKeys = new Set(ARENA_STARTS.flat().map(p=>key(p.q,p.r)));
    const turn = Math.floor(random()*3); const left: Point[] = [{q:-2,r:1}];
    // Grow a connected six-cell terrace in one half of the inner arena, then mirror it.
    for (let i=1;i<6;i++) {
      const frontier = new Map<string,Point>();
      for (const point of left) for (const d of directions) { const p={q:point.q+d.q,r:point.r+d.r};if(p.q<0&&distance(p,{q:0,r:0})<=3&&!left.some(v=>key(v.q,v.r)===key(p.q,p.r))) frontier.set(key(p.q,p.r),p); }
      const candidates=[...frontier.values()].sort((a,b)=>a.q-b.q||a.r-b.r);left.push(candidates[Math.floor(random()*candidates.length)]);
    }
    const raised = mirrored(left.map(p=>rotate(p,turn))); ground = new Set(raised.map(p=>key(p.q,p.r)));
    // Grow a shallow branching channel separately. Restrict to one half-plane, so its mirror stays disjoint.
    const channelTurn = Math.floor(random()*6);
    const candidates:Point[]=[];
    for(let q=-5;q<=5;q++)for(let r=1;r<=5;r++)if(distance({q,r},{q:0,r:0})<=5){const p=rotate({q,r},channelTurn);const k=key(p.q,p.r);const mirroredKey=key(-p.q,-p.r);if(!ground.has(k)&&!ground.has(mirroredKey)&&!wellKeys.has(k)&&!wellKeys.has(mirroredKey)&&!startKeys.has(k)&&!startKeys.has(mirroredKey))candidates.push(p);}
    const available = new Map(candidates.map(p=>[key(p.q,p.r),p]));
    // Choose a sufficiently large connected component before growth; finite enumeration guarantees six cells.
    const components:Point[][]=[];const visited=new Set<string>();
    for(const p of candidates){if(visited.has(key(p.q,p.r)))continue;const component=[p];visited.add(key(p.q,p.r));for(let i=0;i<component.length;i++)for(const d of directions){const k=key(component[i].q+d.q,component[i].r+d.r);const next=available.get(k);if(next&&!visited.has(k)){visited.add(k);component.push(next);}}if(component.length>=6)components.push(component);}
    if(!components.length)throw new Error('Arena channel generation has no connected region.');
    const component=components[Math.floor(random()*components.length)];const componentKeys=new Set(component.map(p=>key(p.q,p.r)));const channel=[component[Math.floor(random()*component.length)]];
    for(let i=1;i<6;i++){const frontier=new Map<string,Point>();for(const p of channel)for(const d of directions){const k=key(p.q+d.q,p.r+d.r);if(componentKeys.has(k)&&!channel.some(v=>key(v.q,v.r)===k))frontier.set(k,available.get(k)!);}const options=[...frontier.values()].sort((a,b)=>a.q-b.q||a.r-b.r);channel.push(options[Math.floor(random()*options.length)]);}
    water=new Set(mirrored(channel).map(p=>key(p.q,p.r)));
  }
  const wells=new Set(wellPositions.map(p=>key(p.q,p.r))); const cells:ArenaCell[]=[];
  for(let q=-ARENA_RADIUS;q<=ARENA_RADIUS;q++)for(let r=-ARENA_RADIUS;r<=ARENA_RADIUS;r++)if(distance({q,r},{q:0,r:0})<=ARENA_RADIUS){const k=key(q,r);const well=wells.has(k);cells.push(Object.freeze({q,r,well,terrain:well?'plain':ground.has(k)?'earth':water.has(k)?'water':'plain',height:ground.has(k)?1:0}));}
  const result=Object.freeze(cells);if(cache.size>=64)cache.delete(cache.keys().next().value!);cache.set(canonical,result);return result;
}
export const arenaHeightAt = (q: number, r: number, mapId = 'confluence'): 0 | 1 => generateArena(mapId).find(c=>c.q===q&&c.r===r)?.height ?? 0;
export const arenaWellAt = (q: number, r: number, mapId = 'confluence') => generateArena(mapId).some(c=>c.q===q&&c.r===r&&c.well);
export const baseTerrainAt = (q: number, r: number, mapId = 'confluence'): 'plain' | 'earth' | 'water' => generateArena(mapId).find(c=>c.q===q&&c.r===r)?.terrain ?? 'plain';
