import assert from 'node:assert/strict';
import test from 'node:test';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {dirname,resolve} from 'node:path';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {CHAMPIONS} from '../lib/roster.ts';
import {characterCastAnimation,characterMotion} from '../lib/character-motion.ts';
import {battlefieldMotion} from '../lib/battlefield-motion-v16.ts';
import * as tactics from '../lib/tactics-v16.ts';
import * as feedback from '../lib/feedback-v16.ts';
import * as presentation from '../lib/element-presentation.ts';
import * as effectFrames from '../lib/element-effect-frames.ts';
import {screenFacing} from '../lib/battlefield-clarity-v16.ts';

const nodeRequire=createRequire(import.meta.url);
const modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
type ProjectileProps=Parameters<typeof import('../app/components/ElementEffectsV16.tsx').ElementProjectile>[0];
type ImpactProps=Parameters<typeof import('../app/components/ElementEffectsV16.tsx').ElementImpact>[0];
const {ElementProjectile,ElementImpact}=loadSource(fileURLToPath(new URL('../app/components/ElementEffectsV16.tsx',import.meta.url))) as {ElementProjectile:ComponentType<ProjectileProps>;ElementImpact:ComponentType<ImpactProps>};

test('all thirty authored gestures release the real cast pose on the shared launch instant',()=>{
  const recoveries=new Set<string>();
  for(const hero of CHAMPIONS){
    const cast=characterCastAnimation(hero.id,192,2,feedback.CAST_ANTICIPATION_MS);
    assert.equal(cast.releaseMs,feedback.CAST_ANTICIPATION_MS,hero.id);
    assert.equal(cast.durationMs,feedback.CAST_ANTICIPATION_MS+characterMotion(hero.id).castMs);
    assert.ok(cast.restMs>cast.releaseMs&&cast.restMs<cast.durationMs);
    const releasePercent=Number((feedback.CAST_ANTICIPATION_MS/cast.durationMs*100).toFixed(6));
    assert.ok(cast.css.includes(`${releasePercent}%{background-position-y:-576px}`),`${hero.id}: raised-hand row begins exactly at release`);
    assert.ok(!/scale\(|scale[XY]\(|rotate\(|skew/.test(cast.css),`${hero.id}: painted anatomy is never deformed`);
    for(const [,pixels] of cast.css.matchAll(/translateX\((-?[\d.]+)px\)/g))assert.ok(Number.isInteger(Number(pixels)));
    recoveries.add(`${cast.durationMs}/${cast.restMs}`);
  }
  assert.ok(recoveries.size>=20,'individual preparation and recovery remain authored');
});

test('each advanced element has a distinct silhouette in its exact parent palette and collision time',()=>{
  const silhouettes=new Set<string>();
  for(const family of ['fire','water','earth','air','light','dark'] as const){
    const branch=presentation.ADVANCED_ELEMENT_NAMES[family],kind=presentation.ADVANCED_ELEMENT_KINDS[family];
    const projectile=renderToStaticMarkup(createElement(ElementProjectile,{from:{x:0,y:0},to:{x:50,y:0},element:family,branch,flightFraction:.5}));
    const impact=renderToStaticMarkup(createElement(ElementImpact,{element:family,branch}));
    assert.ok(projectile.includes(`data-projectile-material="${kind}"`));
    assert.ok(impact.includes(`data-impact-material="${kind}"`),`${branch}: distinct impact, without implying a gameplay freeze`);
    for(const [shade,color] of Object.entries(presentation.ELEMENT_PALETTES[family]))assert.ok(projectile.includes(`--fx-${shade}:${color}`));
    assert.ok(projectile.includes(`data-projectile-launch="${feedback.projectileMeetingMs(0)}"`));
    assert.ok(projectile.includes(`data-projectile-arrival="${feedback.projectileMeetingMs(.5)}"`));
    assert.equal((projectile.match(/data-effect-frame="\d"/g)||[]).length,4,`${branch}: four actual travel cels`);
    assert.equal((impact.match(/data-effect-frame="\d"/g)||[]).length,6,`${branch}: six actual impact cels`);
    const poster=effectFrames.ELEMENT_EFFECT_FRAMES[kind].impact[2];
    for(const path of poster.paths.filter(Boolean))assert.ok(impact.includes(`d="${path}"`),`${branch}: authored poster cel reaches the renderer`);
    silhouettes.add(poster.paths.join('|'));
  }
  assert.equal(silhouettes.size,6);
});

test('curved movement switches atlas facing at each real waypoint without altering the route',()=>{
  const before=tactics.createSimGame();
  before.cells.forEach(cell=>Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false}));
  const unit=before.units[0];Object.assign(unit,{q:0,r:0});
  tactics.getCell(before,1,0)!.biome='ruins';
  const route=tactics.movementPath(before,unit.id,{q:2,r:0})!;
  assert.ok(route.length>2);
  const after=tactics.resolveRound(before,[{orders:[{unitId:unit.id,move:{q:2,r:0}}]},{orders:[]}]);
  const motion=battlefieldMotion(before,after,unit.id,'craft-test')!;
  assert.deepEqual(motion.movePath,route.map(({q,r})=>({q,r})));
  assert.equal(motion.facingFrames.length,route.length);
  motion.facingFrames.forEach((frame,index)=>{
    assert.equal(frame.facing,screenFacing(index?route[index-1]:unit,route[index]));
    assert.ok(Math.abs(frame.atMs-feedback.PHASE_MS.cast*index/route.length)<.000001);
  });
  assert.ok(new Set(motion.facingFrames.map(frame=>frame.facing)).size>1);
  assert.equal(motion.frames.find(frame=>frame.atMs===feedback.PHASE_MS.cast)?.point.q,2);
});
