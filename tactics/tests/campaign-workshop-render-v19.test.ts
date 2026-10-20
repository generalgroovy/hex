import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {readCampaignProfile,type CampaignProfile} from '../lib/campaign-profile-v19.ts';
import {getCreature} from '../lib/campaign-creatures-v19.ts';
import {getChampion} from '../lib/roster-v13.ts';
import {getSpell,repairLoadout} from '../lib/spells-v16.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
type Tab='hero'|'affinities'|'spells'|'companions';
const Workshop=loadSource(fileURLToPath(new URL('../app/components/CampaignWorkshopV19.tsx',import.meta.url))).default as ComponentType<{profile:CampaignProfile;initialTab:Tab;onHero:()=>void;onCompanions:()=>void;onPendingChange:()=>void}>;
const profile=readCampaignProfile(null),noop=()=>{};
const render=(initialTab:Tab,current=profile)=>renderToStaticMarkup(createElement(Workshop,{profile:current,initialTab,onHero:noop,onCompanions:noop,onPendingChange:noop})).replaceAll('&#x27;',"'").replaceAll('&amp;','&');

test('the fresh five-point hero can release a support point through the actual editor button',()=>{
 const support=Object.keys(profile.hero.affinities).find(element=>element!==getChampion(profile.hero.championId).element)!;
 const html=render('affinities'),button=html.match(new RegExp(`<button[^>]+aria-label="Reduce ${support} affinity"[^>]*>`));
 assert.ok(button);assert.doesNotMatch(button[0],/disabled/);assert.match(html,/5\/5 affinity/);
});
test('selected companions expose their exact equipped kit and positional bond without a tooltip',()=>{
 const html=render('companions'),creature=getCreature(profile.companions[0]);
 for(const id of creature.loadout)assert.ok(html.includes(getSpell(id).name));
 assert.match(html,/within 2 hexes of both creatures/);assert.match(html,/c19-creature-spells/);assert.match(html,/combat-creature-v19/);
});
test('all preparation tabs render and the spell editor exposes four named slots',()=>{
 for(const tab of ['hero','affinities','spells','companions'] as const)assert.match(render(tab),/Prepare your party/);
 const html=render('spells');assert.equal((html.match(/aria-label="Spell slot /g)??[]).length,4);assert.match(html,/c19-spell-detail/);
});
test('first-victory rank four and its highest-level spell are visible without catalogue paging',()=>{
 const affinities={water:4,fire:2},hero={...profile.hero,affinities,loadout:repairLoadout(profile.hero.championId,profile.hero.loadout,affinities,[])};
 const advanced={...profile,defeated:['oh_tipi'],hero};
 assert.match(render('affinities',advanced),/4<small>\/4<\/small>/);
 const html=render('spells',advanced);assert.match(html,/Deep Freeze/);assert.match(html,/level 4/);
});
