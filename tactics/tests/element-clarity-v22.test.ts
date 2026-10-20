import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {fieldRegions,projectileReadabilityScale,projectileWake} from '../lib/element-clarity-v22.ts';
import {rangeBoundaryEdges,rangeBoundaryPath} from '../lib/range-outline-v16.ts';
import type {SimCell} from '../lib/tactics-v16.ts';

const cell=(q:number,r:number,terrain:SimCell['terrain']='fire',ttl:number|undefined=2,height:0|1=0):SimCell=>({q,r,terrain,ttl,height,biome:'plain',well:false});

test('connected field contours remove internal seams without enclosing natural terrain or disconnected islands',()=>{
 const cells=[cell(0,0),cell(1,0),cell(5,0),cell(2,0,'water'),{...cell(0,1,'water'),ttl:undefined},cell(1,1,'fire',0)];
 const snapshot=JSON.stringify(cells),regions=fieldRegions(cells);
 assert.equal(regions.length,3);
 assert.deepEqual(regions.map(region=>[region.material,region.cells.length]),[['fire',2],['fire',1],['water',1]]);
 const joined=regions[0];assert.equal(rangeBoundaryEdges(joined.cells).length,10,'two neighbouring hexes share two edges that must disappear');
 assert.equal((joined.path.match(/M/g)||[]).length,10);
 assert.equal(JSON.stringify(cells),snapshot,'presentation cannot change terrain, duration, or ordering');
});

test('height and frozen material are preserved in connected field footprints',()=>{
 const raised=[cell(0,0,'earth',3,1),cell(1,0,'earth',3,1)];
 const region=fieldRegions(raised)[0];
 assert.equal(region.path,rangeBoundaryPath(raised,()=>1));
 assert.notEqual(region.path,rangeBoundaryPath(raised),'surface edges follow the elevated ground');
 const iced:SimCell={...cell(0,0,'water'),ice:true};
 assert.equal(fieldRegions([iced])[0].material,'ice');
});

test('projectile wakes read through six shape families and remain snapped behind their true route',()=>{
 const kinds=['fire','water','earth','air','light','dark'] as const;
 assert.equal(new Set(kinds.map(kind=>projectileWake({x:0,y:0},{x:200,y:80},kind)[0].shape)).size,6);
 for(const kind of kinds)for(const to of [{x:200,y:80},{x:-180,y:30},{x:0,y:-200}]){
  const marks=projectileWake({x:0,y:0},to,kind);
  assert.equal(marks.length,3);
  for(const mark of marks){assert.ok(mark.x*to.x+mark.y*to.y<0,'wake trails the traveller');assert.ok(mark.x%2===0);assert.ok(mark.y%2===0);}
 }
 assert.deepEqual(projectileWake({x:7,y:4},{x:7,y:4},'fire'),[]);
 assert.deepEqual(projectileWake({x:0,y:0},{x:20,y:0},'water'),[],'short casts do not grow a long decorative tail');
 for(const scale of [.5,1,1.99,2,8])assert.ok([1,2].includes(projectileReadabilityScale(scale)),'zoom enhancement never stretches pixel cels by a fractional factor');
});

test('extra feedback is finite and reduced-motion posters cannot reveal future impacts during movement or casting',()=>{
 const css=readFileSync(new URL('../app/components/element-clarity-v22.css',import.meta.url),'utf8');
 assert.doesNotMatch(css,/\binfinite\b|blur\(|rotate\(|scale\(/,'no scenery loop, blur, or deformation added');
 assert.match(css,/px22-impact-contour 1350ms/);
 assert.match(css,/px22-link-window 1250ms/);
 assert.match(css,/@media\(prefers-reduced-motion:reduce\)/);
 for(const phase of ['move','cast'])for(const marker of ['px22-impact-contour','px22-team-link'])assert.ok(css.includes(`[data-playback-phase=${phase}] .${marker}`));
 assert.match(css,/visibility:hidden/);
});
