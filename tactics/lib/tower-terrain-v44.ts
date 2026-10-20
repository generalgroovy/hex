/** Tower-only geometry. The explicit map suffix keeps all previous seeds frozen. */
import {distance,type Point} from './game.ts';
import type {Biome} from './arena-v7.ts';

export type TowerMotif='crossing'|'courtyard'|'grove';
export const TOWER_MOTIFS:readonly TowerMotif[]=['crossing','courtyard','grove'];
export const TOWER_MOTIF_INFO:Record<TowerMotif,{name:string;detail:string}>={
 crossing:{name:'Split crossing',detail:'Marshy banks slow the water crossing. Dry passages offer quicker routes; the water is ready for ice or steam.'},
 courtyard:{name:'Broken courtyard',detail:'A broken wall interrupts direct shots. Open gates and covered flanks give two ways around it.'},
 grove:{name:'Terraced grove',detail:'Raised ground overlooks a sheltered approach. Forest cover protects a flank but can change when spells land.'},
};
export function towerMotifFromMapId(mapId:string):TowerMotif|undefined{
 const motif=mapId.match(/:m44-(crossing|courtyard|grove)$/)?.[1];
 return motif as TowerMotif|undefined;
}
const key=(p:Point)=>`${p.q||0},${p.r||0}`;
/** Stamp the encounter's usable geometry before the arena's connectivity check. */
export function applyTowerMotif(mapId:string,points:readonly Point[],biomes:Map<string,Biome>,wells:ReadonlySet<string>):void{
 const motif=towerMotifFromMapId(mapId);if(!motif)return;
 const radius=Math.max(...points.map(p=>distance(p,{q:0,r:0}))),span=Math.min(6,radius-5);
 let hash=2166136261;for(const char of mapId){hash^=char.charCodeAt(0);hash=Math.imul(hash,16777619)>>>0;}
 const side=hash%2?1:-1;
 const set=(q:number,r:number,biome:Biome)=>{const cell={q:q*side,r:r*side},id=key(cell);if(biomes.has(id)&&!wells.has(id))biomes.set(id,biome);};
 // A readable central engagement replaces unrelated random blockers, while
 // the outer seeded landscape stays intact and supplies further flank space.
 for(const p of points)if(distance(p,{q:0,r:0})<=span+1&&!wells.has(key(p)))biomes.set(key(p),'plain');
 if(motif==='crossing'){
  for(let r=-span;r<=span;r++){set(0,r,'water');if(r!==0){set(-1,r,'marsh');set(1,r,'marsh');}}
  for(const r of [-2,2]){set(0,r,'plain');set(-1,r,'forest');set(1,r,'forest');}
  for(const r of [-span,span]){set(-1,r,'marsh');set(1,r,'marsh');}
 }else if(motif==='courtyard'){
  for(let r=-span;r<=span;r++)if(![-2,0,2].includes(r))set(0,r,'ruins');
  for(const r of [-2,2]){set(-1,r,'forest');set(1,r,'forest');}
  set(-2,2,'earth');set(2,-2,'earth');set(-1,3,'water');set(1,-3,'water');
 }else{
  for(let r=-span;r<=span;r++){
   if(r!==0){set(-1,r,'earth');set(1,r,'forest');}
   if(Math.abs(r)>1)set(2,r,'forest');
  }
  set(0,-2,'water');set(0,2,'water');
 }
 // Normal deployment and the final safe centre remain free from blockers.
 for(const sign of [-1,1])for(const p of [{q:3*sign,r:0},{q:3*sign,r:-sign},{q:2*sign,r:sign}])biomes.set(key(p),'plain');
 biomes.set('0,0','plain');
}
