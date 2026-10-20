import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync,existsSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createSimGame,legalCasts,resolveRound,spellArea} from '../lib/tactics-v7.ts';
import {createSimGame as createV6} from '../lib/tactics.ts';

/** Compile the real TSX and local imports in memory; CSS has no server rendering behavior.
 * These assertions cover output semantics, not browser layout, animation timing or touch input.
 */
const nodeRequire=createRequire(import.meta.url);
const modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown> {
  const cached=modules.get(filename);if(cached)return cached.exports;
  const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
  const javascript=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
  const localRequire=(specifier:string):unknown=>{
    if(specifier.endsWith('.css'))return {};
    if(!specifier.startsWith('.'))return nodeRequire(specifier);
    const target=resolve(dirname(filename),specifier);
    const found=['','.ts','.tsx','.js','.json'].map(suffix=>target+suffix).find(path=>existsSync(path));
    if(!found)throw new Error(`Cannot resolve renderer dependency ${specifier}`);
    return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
  };
  new Function('require','module','exports','__filename','__dirname',javascript)(localRequire,module,module.exports,filename,dirname(filename));
  return module.exports;
}
type BoardProps=ComponentProps<typeof import('../app/components/PixelBattlefieldV7.tsx').default>;
const Battlefield=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV7.tsx',import.meta.url))).default as ComponentType<BoardProps>;
const LegacyBattlefield=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefield.tsx',import.meta.url))).default as typeof import('../app/components/PixelBattlefield.tsx').default;
const MapPreview=loadSource(fileURLToPath(new URL('../app/components/SeedMapPreviewV7.tsx',import.meta.url))).default as typeof import('../app/components/SeedMapPreviewV7.tsx').default;
const render=(props:BoardProps)=>renderToStaticMarkup(createElement(Battlefield,props));
const impactCells=(html:string,spellId:string)=>[...html.matchAll(new RegExp(`data-cast-spell="${spellId}" data-effect-cell="([^"]+)"`,'g'))].map(match=>match[1]).sort();

test('resolution draws every ring cell without lighting its unaffected centre or inventing a travel arc',()=>{
  const before=createSimGame(),caster=before.units[0];
  Object.assign(caster,{q:0,r:0,loadout:['maelstrom','water_jet','ember','mend']});
  const after=resolveRound(before,[{orders:[{unitId:caster.id,spellId:'maelstrom',cast:{q:0,r:0}}]},{orders:[]}]);
  const html=render({state:after,previousState:before,resolving:true,plan:{orders:[]},player:0,selected:caster.id,kind:'cast',onCell:()=>{},interactive:false});
  const actual=impactCells(html,'maelstrom');
  assert.equal(actual.length,12);assert.equal(new Set(actual).size,12);assert.ok(!actual.includes('0,0'));
  assert.deepEqual(actual,spellArea(before,caster.id,'maelstrom',{q:0,r:0}).map(cell=>`${cell.q},${cell.r}`).sort());
  assert.ok(!html.includes('class="px-cast-tracer"'),'a self-centred spell has no projectile journey');
  assert.equal((html.match(/aria-disabled="true"/g)||[]).length,271,'replay cannot queue new cell orders');
});

test('simultaneous new barriers cannot retroactively shorten the displayed beam footprint',()=>{
  const before=createSimGame(undefined,'frontier:BEAM-0'),beam=before.units[0],builder=before.units[1];
  Object.assign(beam,{q:0,r:0,loadout:['fire_lance','water_jet','ember','mend']});
  Object.assign(builder,{q:2,r:-2,loadout:['raise_cairn','water_jet','ember','mend']});
  assert.ok(legalCasts(before,beam.id,undefined,'fire_lance').some(cell=>cell.q===4&&cell.r===0));
  assert.ok(legalCasts(before,builder.id,undefined,'raise_cairn').some(cell=>cell.q===2&&cell.r===0));
  const after=resolveRound(before,[{orders:[{unitId:beam.id,spellId:'fire_lance',cast:{q:4,r:0}},{unitId:builder.id,spellId:'raise_cairn',cast:{q:2,r:0}}]},{orders:[]}]);
  assert.ok(after.cells.find(cell=>cell.q===2&&cell.r===0)?.barrier);
  assert.equal(spellArea(after,beam.id,'fire_lance',{q:4,r:0},{q:0,r:0}).length,0,'the resulting terrain really differs from the cast snapshot');
  const html=render({state:after,previousState:before,resolving:true,plan:{orders:[]},player:0,selected:beam.id,kind:'cast',onCell:()=>{},interactive:false});
  assert.deepEqual(impactCells(html,'fire_lance'),['1,0','2,0','3,0','4,0']);
});

test('inspection retains permanent cover beneath a field and wells expose their actual holder',()=>{
  const state=createSimGame(undefined,'frontier:AUDIT-77'),forest=state.cells.find(cell=>cell.biome==='forest')!;
  Object.assign(forest,{terrain:'magma',elements:['fire','earth'],reactions:['magma'],ttl:2});
  Object.assign(state.units[0],{q:0,r:0});
  const html=render({state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',onCell:()=>{},interactive:true,aimTarget:forest});
  assert.ok(html.includes('Forest · Magma'));assert.ok(html.includes('Earth base · −1 nonpiercing spell damage'));assert.ok(html.includes('Field 2 rounds'));
  assert.ok(html.includes('data-biome="forest" data-field="magma"'));
  assert.equal((html.match(/class="px-well-badge"/g)||[]).length,5);
  assert.ok(html.includes('data-well="0,0" data-owner="0"'));
  assert.equal((html.match(/data-owner="neutral"/g)||[]).length,4);
  assert.ok(html.includes('Center selected character'));
});

test('V7 keeps its full map preview and controls without altering the V6 board',()=>{
  const state=createSimGame(),old=createV6();
  const current=render({state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',onCell:()=>{},interactive:true});
  const legacy=renderToStaticMarkup(createElement(LegacyBattlefield,{state:old,plan:{orders:[]},player:0,selected:old.units[0].id,kind:'move',onCell:()=>{},interactive:true}));
  const preview=renderToStaticMarkup(createElement(MapPreview,{mapId:state.mapId}));
  assert.equal((current.match(/class="px-cell-hit"/g)||[]).length,271);
  assert.equal((legacy.match(/class="px-cell-hit"/g)||[]).length,127);assert.ok(!legacy.includes('px-board-v7'));
  assert.equal((preview.match(/class="px-seed-cell"/g)||[]).length,271);assert.equal((preview.match(/class="px-seed-well"/g)||[]).length,5);
});
