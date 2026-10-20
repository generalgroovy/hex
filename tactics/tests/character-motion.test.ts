import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {CHAMPIONS} from '../lib/roster.ts';
import * as motion from '../lib/character-motion.ts';

const nodeRequire=createRequire(import.meta.url);
const filename=fileURLToPath(new URL('../app/components/PixelChampion.tsx',import.meta.url));
const javascript=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
const module={exports:{}};
new Function('require','module','exports',javascript)((specifier:string)=>specifier.endsWith('.css')?{}:specifier.endsWith('/roster')?{CHAMPIONS}:specifier.endsWith('/character-motion')?motion:nodeRequire(specifier),module,module.exports);
type Props=import('../app/components/PixelChampion.tsx').PixelChampionProps;
const Champion=(module.exports as {default:ComponentType<Props>}).default;
const render=(props:Props)=>renderToStaticMarkup(createElement(Champion,props));

test('all 30 original atlases have an authored motion profile and the expected four-pose layout',()=>{
  assert.equal(CHAMPIONS.length,30);
  assert.deepEqual(Object.keys(motion.CHARACTER_MOTION).sort(),CHAMPIONS.map(character=>character.id).sort());
  for(const character of CHAMPIONS){
    const image=readFileSync(fileURLToPath(new URL(`../public${character.sprite}`,import.meta.url)));
    assert.equal(image.subarray(1,4).toString(),'PNG',character.id);
    assert.equal(image.readUInt32BE(16),8*128,`${character.id}: eight facings`);
    assert.equal(image.readUInt32BE(20),4*128,`${character.id}: rest, two steps, cast`);
    const profile=motion.characterMotion(character.id);
    assert.ok(profile.castMs<=450,`${character.id}: finishes before the existing impact phase`);
    assert.ok(profile.hitMs<=500,`${character.id}: recovers before the aftermath phase`);
    assert.ok(profile.squash<=.025,`${character.id}: preserves pixel silhouette`);
  }
});

test('stone weight and goblin spring remain distinct without changing the actor cell or foot anchor',()=>{
  const stone=motion.characterMotion('dr_apex'),goblin=motion.characterMotion('wa_bidi');
  assert.equal(stone.mass,'heavy');assert.equal(goblin.mass,'light');
  assert.ok(stone.gaitMs>goblin.gaitMs);assert.ok(stone.recoil<goblin.recoil);assert.ok(stone.squash<goblin.squash);
  for(const size of [100,128,170,224]){
    const half=motion.characterMotionStyle('wa_bidi',size,2),opposite=motion.characterMotionStyle('wa_bidi',size,6);
    assert.equal(parseFloat(String(half['--px-release'])),goblin.release*size/128);
    assert.equal(parseFloat(String(half['--px-recoil'])),-parseFloat(String(opposite['--px-recoil'])));
    const html=render({id:'wa_bidi',action:'cast',size,facing:2});
    assert.ok(html.includes(`width:${size}px;height:${size}px`));
    assert.ok(html.includes(`--px-frame-y:-${3*size}px`),'only the actual cast row is selected');
  }
});

test('character renders default to quiet, paused thumbnails stay identifiable, and full motion is explicit',()=>{
  const quiet=render({id:'haara'}),full=render({id:'haara',motion:'full'}),thumbnail=render({id:'haara',paused:true,motion:'full'});
  assert.ok(quiet.includes('px-motion-quiet'));assert.ok(!quiet.includes('px-motion-full'));
  assert.ok(full.includes('px-motion-full'));assert.ok(full.includes('data-motion-voice="flutter"'));
  assert.ok(thumbnail.includes('px-paused'));assert.ok(thumbnail.includes('aria-hidden="true"'));
  assert.ok(!quiet.includes('<img'),'the original complete atlas cell remains a single decorative layer');
  assert.ok(render({id:'missing'}).includes('px-champion-missing'));
});

test('invalid and extreme facings cannot address an absent atlas column',()=>{
  for(const value of [Number.NaN,Infinity,-Infinity,-100,100,2.8]){
    const html=render({id:'oh_tipi',facing:value,size:128});
    const offset=Number(html.match(/--px-face-x:([\d.-]+)px/)?.[1]);
    assert.ok(Number.isFinite(offset));assert.ok(offset<=0&&offset>=-7*128);
    assert.ok(offset%128===0);
  }
});
