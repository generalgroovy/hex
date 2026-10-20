import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {EFFECT_MATERIALS,ELEMENT_EFFECT_FRAMES,EFFECT_SHADES,IMPACT_CEL_ENDS,impactCelAt,effectFrameKeyframes,STEAM_EFFECT_FRAMES,FIELD_FLAME_FRAMES,FIELD_STEAM_FRAMES} from '../lib/element-effect-frames.ts';
import {CAST_ANTICIPATION_MS,PROJECTILE_FLIGHT_MS,PHASE_MS,projectileMeetingMs} from '../lib/feedback-v16.ts';

test('all twelve materials have distinct, bounded drawings for every travel and impact cel',()=>{
  const materialPosters=new Set<string>();
  for(const kind of EFFECT_MATERIALS){
    const {projectile,impact}=ELEMENT_EFFECT_FRAMES[kind];
    assert.equal(projectile.length,4,kind);assert.equal(impact.length,6,kind);
    assert.equal(new Set(projectile.map(c=>c.paths.join('|'))).size,4,`${kind}: each travel cel changes actual geometry`);
    assert.equal(new Set(impact.map(c=>c.paths.join('|'))).size,6,`${kind}: impact grows and breaks up through distinct drawings`);
    materialPosters.add(impact[2].paths.join('|'));
    for(const cel of [...projectile,...impact]){
      assert.equal(cel.paths.length,EFFECT_SHADES.length);
      assert.ok(cel.paths[0]&&cel.paths[1],`${kind}: ink footing and dark outline survive any background`);
      assert.ok(cel.paths[3]||cel.paths[4]||cel.paths[5],`${kind}: readable material colour or bright core`);
      assert.ok(cel.pixelCount>20&&cel.pixelCount<1800,`${kind}: bounded pixel and SVG workload`);
      const [left,top,right,bottom]=cel.bounds;
      assert.ok(left>=-80&&right<=80&&top>=-100&&bottom<=60,`${kind}: stays inside the central impact area`);
      for(const path of cel.paths){
        assert.ok(/^(?:M-?\d+ -?\d+h\d+v2h-\d+Z)*$/.test(path),`${kind}: integer, axis-aligned pixels only`);
        for(const [,number]of path.matchAll(/(-?\d+)/g))assert.ok(Number(number)%2===0,`${kind}: every edge is on the two-unit grid`);
      }
    }
  }
  assert.equal(materialPosters.size,12,'element families and advanced branches have independent silhouettes');
});

test('impact frame boundaries have no cross-fade, premature cel, gap, or post-impact ghost',()=>{
  assert.equal(impactCelAt(-1),null);assert.equal(impactCelAt(0),0);
  for(let i=0;i<IMPACT_CEL_ENDS.length;i++){
    const end=IMPACT_CEL_ENDS[i];assert.equal(impactCelAt(end-1),i);
    assert.equal(impactCelAt(end),i===5?null:i+1);
  }
  assert.equal(impactCelAt(5000),null);
  const css=readFileSync(new URL('../app/components/element-spectacle-v16.css',import.meta.url),'utf8');
  assert.ok(css.includes(effectFrameKeyframes()),'deployed CSS and authored frame timings agree');
  assert.match(css,/\.px16-cels-impact>\.px16-effect-cel\{animation:[^}]*steps\(1,end\) forwards\}/,'default hidden cel remains hidden before its impact delay');
  assert.match(css,/\.px16-effect-cel\{opacity:0;/);
  assert.match(css,/\.px16-effect-cel\.is-poster-cel\{opacity:1!important\}/,'reduced motion retains exactly the selected complete cel');
  assert.doesNotMatch(css,/scale\(|scale[XY]\(|rotate\(|skew|blur\(/,'current effects never deform a completed pixel drawing');
});

test('Steam disperses and field materials change cels without competing with character-sized impacts',()=>{
  assert.equal(STEAM_EFFECT_FRAMES.length,6);
  assert.equal(new Set(STEAM_EFFECT_FRAMES.map(c=>c.paths.join('|'))).size,6);
  assert.ok(STEAM_EFFECT_FRAMES[2].pixelCount>STEAM_EFFECT_FRAMES[0].pixelCount*2,'pressure visibly blooms');
  assert.ok(STEAM_EFFECT_FRAMES[5].pixelCount<STEAM_EFFECT_FRAMES[2].pixelCount*.65,'cloud separates into a sparse residue');
  for(const frames of [FIELD_FLAME_FRAMES,FIELD_STEAM_FRAMES]){
    assert.equal(frames.length,4);assert.equal(new Set(frames.map(c=>c.paths.join('|'))).size,4);
    for(const cel of frames)assert.ok(cel.bounds[2]-cel.bounds[0]<=36&&cel.bounds[3]-cel.bounds[1]<=36,'persistent material remains small around the feet');
  }
});

test('new cel cadence does not alter the authoritative launch or interception clock',()=>{
  assert.equal(CAST_ANTICIPATION_MS,360);
  const launch=PHASE_MS.cast+CAST_ANTICIPATION_MS;
  assert.equal(launch,1960);assert.equal(launch+PROJECTILE_FLIGHT_MS,PHASE_MS.impact);
  for(const fraction of [0,.125,.5,.875,1])assert.equal(projectileMeetingMs(fraction),launch+PROJECTILE_FLIGHT_MS*fraction);
});
