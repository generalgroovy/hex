import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {CHAMPIONS,allocateAffinityBudget} from '../lib/roster-v13.ts';
import {CREATURES,getCreaturePerk,CREATURE_BOND_RADIUS} from '../lib/campaign-creatures-v20.ts';
import {effectiveSpell,defaultLoadout,getSignature,getSpell,type Spell} from '../lib/spells-v20.ts';
import {spellEffectLabel} from '../lib/battle-guidance-v16.ts';
import {CURRENT_SPELL_MODEL,profileSpell,type SpellModel} from '../lib/spell-profile-v42.ts';
import {profiledEffectLabel,profiledSpellDescription} from '../lib/spell-profile-label-v42.ts';
import type {TowerMemberInput} from '../lib/tower-v23.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const components=loadSource(fileURLToPath(new URL('../app/components/TowerTeamPickerV23.tsx',import.meta.url))),previews=loadSource(fileURLToPath(new URL('../app/components/TowerKitPreviewV23.tsx',import.meta.url)));
const Member=components.TowerTeamMemberCard as ComponentType<{member:TowerMemberInput;index:number}>,Preview=previews.TowerSpellPreview as ComponentType<{spell:Spell;spellModel?:SpellModel|null}>,Builder=loadSource(fileURLToPath(new URL('../app/components/TowerCharacterBuilderV23.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const html=(element:ReturnType<typeof createElement>)=>renderToStaticMarkup(element).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
const summary=(markup:string)=>markup.match(/<summary>[^]*?<\/summary>/)?.[0]??'';

test('spell decisions expose effective cost, reach and consequence before expansion, including scaled spells',()=>{
 for(const rank of [1,2,3,4,5,6])for(const id of ['water_jet','cleansing_tide',getSignature('oh_tipi').id]){
  const spell=effectiveSpell('oh_tipi',id,{water:rank}),focused=profileSpell(spell,CURRENT_SPELL_MODEL),markup=html(createElement(Preview,{spell})),visible=summary(markup);
  assert.ok(visible.includes(spell.name));assert.ok(visible.includes(`${spell.cost} Flux`));assert.ok(visible.includes(spell.range?`reach ${spell.range}`:'self'));assert.ok(visible.includes(profiledEffectLabel(focused)));
  assert.doesNotMatch(visible,/title=/);assert.ok(markup.includes(profiledSpellDescription(focused)));
  if(focused.focus){assert.ok(visible.includes(`Radius ${focused.radius} · centre crit`));assert.match(markup,/Centre crit/);}
 }
});

test('all twelve starter creatures expose named affinities, actual kits and the creature requirement of their bond',()=>{
 const creatures=CREATURES.filter(creature=>creature.strengthClass==='lesser');assert.equal(creatures.length,12);
 for(const creature of creatures){
  const markup=html(createElement(Member,{member:{kind:'creature',creatureId:creature.id},index:1})),bond=getCreaturePerk(creature.perkId),bondSummary=summary(markup.slice(markup.indexOf('class="tp23-bond"')));
  for(const element of creature.elements)assert.ok(markup.includes(element[0].toUpperCase()+element.slice(1)));
  for(const id of creature.loadout){const spell=profileSpell(effectiveSpell(creature.championId,id,creature.affinities),CURRENT_SPELL_MODEL),facts=summary(markup.slice(markup.indexOf(`data-spell-id="${id}"`)));assert.ok(facts.includes(spell.name));assert.ok(facts.includes(profiledEffectLabel(spell)));assert.ok(facts.includes(`${spell.cost} Flux`));}
  assert.match(bondSummary,/needs another .* creature/);assert.ok(bondSummary.includes(`within ${CREATURE_BOND_RADIUS} hexes of both`));assert.ok(markup.includes(bond.description));
 }
});

test('every champion builder previews its four actual spells while the affinity decision is open',()=>{
 for(const champion of CHAMPIONS){
  const affinities=allocateAffinityBudget(champion.id,5),loadout=defaultLoadout(champion.id,affinities),markup=html(createElement(Builder,{initial:{championId:champion.id,name:champion.name,affinities,loadout},onSave:()=>{},onCancel:()=>{}}));
  assert.match(markup,/aria-label="Affinities"/);assert.match(markup,/aria-label="Current spells"/);
  for(const id of loadout){const spell=profileSpell(effectiveSpell(champion.id,id,affinities),CURRENT_SPELL_MODEL),facts=summary(markup.slice(markup.indexOf(`data-spell-id="${id}"`)));assert.ok(facts.includes(spell.name));assert.ok(facts.includes(profiledEffectLabel(spell)));}
  assert.ok(markup.includes(`data-spell-id="${getSignature(champion.id).id}"`));
 }
});

test('explicit legacy spell previews retain their exact original area, effect and description',()=>{
 for(const rank of [1,3,6])for(const id of ['water_jet','cleansing_tide',getSignature('oh_tipi').id]){
  const spell=effectiveSpell('oh_tipi',id,{water:rank}),markup=html(createElement(Preview,{spell,spellModel:null})),visible=summary(markup);
  assert.ok(visible.includes(spellEffectLabel(spell)));assert.ok(markup.includes(spell.description));
  assert.doesNotMatch(markup,/Centre crit|centre crit|Inner ring|sp42-bands/);
 }
});
test('new-menu Light previews use the current counterplay while explicitly saved focused previews retain Blind',()=>{
 const spell=getSpell('sunburst'),current=html(createElement(Preview,{spell})),saved=html(createElement(Preview,{spell,spellModel:'focused'}));
 assert.ok(current.includes(profiledSpellDescription(profileSpell(spell,CURRENT_SPELL_MODEL))));
 assert.ok(saved.includes(profiledSpellDescription(profileSpell(spell,'focused'))));
 assert.doesNotMatch(current,/\bBlind\b/);assert.match(saved,/\bBlind\b/);
});
