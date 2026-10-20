import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {CREATURES} from '../lib/campaign-creatures-v19.ts';
import type {CombatCreatureV19Props} from '../app/components/CombatCreatureV19.tsx';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const Sprite=loadSource(fileURLToPath(new URL('../app/components/CombatCreatureV19.tsx',import.meta.url))).default as ComponentType<CombatCreatureV19Props>;
const render=(creatureId:string,action:CombatCreatureV19Props['action']='idle')=>renderToStaticMarkup(createElement(Sprite,{creatureId,action}));

test('all 93 creatures render actual distinct SVG drawings without champion portrait fallbacks',()=>{
 const drawings=new Set<string>();
 for(const creature of CREATURES){
  const html=render(creature.id),svg=html.slice(html.indexOf('<svg'));
  assert.ok(html.includes('role="img"'));assert.ok(html.includes(creature.name));assert.ok(html.includes(creature.strengthClass));
  assert.ok(html.includes('shape-rendering="crispEdges"'));assert.ok(!html.includes('<image'));assert.ok(!html.includes('<img'));
  assert.ok(html.includes('data-creature-frame="0"'));assert.equal((html.match(/data-creature-frame=/g)||[]).length,1,'Idle shows one grounded drawing');
  drawings.add(svg);
 }
 assert.equal(drawings.size,CREATURES.length,'Each species needs a different visible drawing, not only a renamed accessible label');
});

test('movement, casting, hit and defeat expose four discrete authored poses with persistent final defeat markup',()=>{
 for(const family of [...new Set(CREATURES.map(creature=>creature.family))]){
  const creature=CREATURES.find(creature=>creature.family===family)!;
  for(const action of ['walk','cast','hit','defeat'] as const){
   const html=render(creature.id,action);assert.equal((html.match(/data-creature-frame=/g)||[]).length,4);
   const poses=[...html.matchAll(/data-creature-frame="\d" transform="([^"]*)"/g)].map(match=>match[1]);assert.equal(new Set(poses).size,4);
   assert.ok(html.includes(`data-creature-action="${action}"`));
   if(action==='defeat')assert.ok(html.includes('cc19-frame-3'));
  }
 }
});

