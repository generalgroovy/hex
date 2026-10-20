import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {readCampaignProfile,type CampaignProfile} from '../lib/campaign-profile-v20.ts';
import {CREATURES,getCreature} from '../lib/campaign-creatures-v20.ts';
import {getCreatureSpell,getSpell,getSignature} from '../lib/spells-v20.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
type Props={profile:CampaignProfile;initialTab?:'hero'|'affinities'|'spells'|'companions';initialSpellId?:string;onHero:()=>void;onCompanions:()=>void;onPendingChange:()=>void;onChallenge:()=>void};
const Workshop=loadSource(fileURLToPath(new URL('../app/components/CampaignWorkshopV20.tsx',import.meta.url))).default as ComponentType<Props>;
const profile=readCampaignProfile(null),noop=()=>{};
const render=(options:Partial<Props>={})=>renderToStaticMarkup(createElement(Workshop,{profile,onHero:noop,onCompanions:noop,onPendingChange:noop,onChallenge:noop,...options})).replaceAll('&#x27;',"'").replaceAll('&amp;','&');

test('a source reward opens its exact detail, keeps four slots, and exposes an eligible creature challenge',()=>{
 const spell=getCreatureSpell('creature-fire-cinder'),html=render({initialSpellId:spell.id});
 assert.match(html,/data-detail-open="true"/);assert.ok(html.includes(spell.name));assert.match(html,/Defeat Cinder to learn this spell/);assert.match(html,/Challenge Cinder/);
 assert.equal((html.match(/aria-label="Replace spell slot /g)??[]).length,4);assert.match(html,/Name, enemy or effect/);assert.match(html,/All spells/);
 assert.match(html,/<button[^>]*disabled=""[^>]*>Requirements not met<\/button>/);
});
test('a learned technique has an explicit equip action while a native signature stays in its fifth slot',()=>{
 const spell=getCreatureSpell('creature-fire-cinder'),known={...profile,learnedSpells:[spell.id]},html=render({profile:known,initialSpellId:spell.id});
 assert.match(html,/Learned from this enemy/);assert.match(html,/Equip in slot 1/);assert.doesNotMatch(html,/Challenge Cinder/);assert.match(html,/Compare Water Jet with/);
 const native=render({initialSpellId:getSignature(profile.hero.championId).id});assert.match(native,/Your signature · fixed fifth spell/);assert.match(native,/<button[^>]*disabled=""[^>]*>Fixed signature<\/button>/);
});
test('a future creature shows both missing requirements and cannot offer an unavailable challenge',()=>{
 const creature=CREATURES.find(entry=>entry.strengthClass==='greater'&&entry.elements.length===1&&entry.elements[0]==='earth')!,html=render({initialSpellId:getCreatureSpell(creature.id).id});
 assert.match(html,/Earth affinity 0\/6/);assert.ok(html.includes(`Defeat ${creature.name} to learn this spell.`));assert.match(html,/This creature appears later/);assert.doesNotMatch(html,/class="c20-challenge"/);
});
test('companion details use their new own spell rather than the frozen v19 kit',()=>{
 const html=render({initialTab:'companions'}),creature=getCreature(profile.companions[0]);
 assert.equal(creature.loadout[0],getCreatureSpell(creature.id).id);
 for(const id of creature.loadout)assert.ok(html.includes(getSpell(id).name));
});
