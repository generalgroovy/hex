import assert from 'node:assert/strict';
import test from 'node:test';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {CHAMPIONS,getChampion} from '../lib/roster-v13.ts';
import {defaultLoadout,getSignature,effectiveSpell,spellCost} from '../lib/spells-v16.ts';
import {createSimGame} from '../lib/tactics-v16.ts';
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
    assert.ok(found,`missing renderer dependency ${specifier}`);
    return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
  };
  new Function('require','module','exports','__filename','__dirname',javascript)(localRequire,module,module.exports,filename,dirname(filename));
  return module.exports;
}

type CompanyProps=ComponentProps<typeof import('../app/components/CompanyOverviewV16.tsx').default>;
type SheetProps=ComponentProps<typeof import('../app/components/CharacterSheetV16.tsx').default>;
const Company=loadSource(fileURLToPath(new URL('../app/components/CompanyOverviewV16.tsx',import.meta.url))).default as ComponentType<CompanyProps>;
const Sheet=loadSource(fileURLToPath(new URL('../app/components/CharacterSheetV16.tsx',import.meta.url))).default as ComponentType<SheetProps>;
const noop=()=>{};

test('every champion has one editable four-spell hand, its signature, and three team selectors',()=>{
 for(const champion of CHAMPIONS){
  const others=CHAMPIONS.filter(entry=>entry.id!==champion.id).slice(0,2).map(entry=>entry.id);
  const roster=[champion.id,...others],kit=defaultLoadout(champion.id);
  const html=renderToStaticMarkup(createElement(Company,{roster,loadouts:{[champion.id]:kit},selectedSlot:0,onSelect:noop,onReplace:noop,onEditSpell:noop,onTrain:noop,onDetails:noop,disabled:false})).replaceAll("&#x27;", "'").replaceAll("&amp;", "&");
  assert.equal((html.match(/<button[^>]*aria-label="Select /g)||[]).length,3,champion.name);
  assert.equal((html.match(/aria-label="Configure spell /g)||[]).length,4,champion.name);
  assert.equal((html.match(/class="cx-member-detail"/g)||[]).length,1);
  assert.ok(html.includes(`Replace ${champion.name}`));
  for(const id of kit)assert.ok(html.includes(effectiveSpell(champion.id,id,champion.affinities).name));
  assert.ok(html.includes(getSignature(champion.id).name));
 }
});

test('character reference shows five reachable spell selectors and one effective effect panel',()=>{
 for(const champion of CHAMPIONS){
  const signature=getSignature(champion.id),kit=defaultLoadout(champion.id),spell=effectiveSpell(champion.id,signature.id,champion.affinities);
  const html=renderToStaticMarkup(createElement(Sheet,{championId:champion.id,allocation:champion.affinities,spellIds:kit,signatureFirst:true})).replaceAll("&#x27;", "'").replaceAll("&amp;", "&");
  assert.equal((html.match(/aria-pressed=/g)||[]).length,5);
  assert.equal((html.match(/class="tx-sheet-effect"/g)||[]).length,1);
  assert.ok(html.includes(`${spellCost(champion.id,signature.id,champion.affinities)} Flux`));
  assert.ok(html.includes(`reach ${spell.range}`));
  for(const id of kit)assert.ok(html.includes(effectiveSpell(champion.id,id,champion.affinities).name));
 }
});

test('battle reference preserves health, flux and status durations at compact size',()=>{
 const state=createSimGame(),unit=state.units[0];unit.hp=6;unit.flux=2;unit.statuses.burn={turns:2,power:1};
 const champion=getChampion(unit.championId);
 const html=renderToStaticMarkup(createElement(Sheet,{championId:champion.id,allocation:unit.affinities,spellIds:unit.loadout,unit,state}));
 assert.ok(html.includes(`6/${unit.maxHp} HP`));assert.ok(html.includes(`2/${unit.maxFlux} Flux`));
 assert.match(html,/Burn(?:ing)? · 2 rounds/i);assert.ok(html.includes('Current statuses'));
});
