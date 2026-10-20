import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {ALL_SPELLS,STATUS_DEFINITIONS,getSpell,getSignature,effectiveSpell,spellCost,spellAccess,spellFootprintDescription} from '../lib/spells-v20.ts';
import {COMBINATIONS,combinationFor,ELEMENT_ORDER} from '../lib/combinations-v16.ts';
import {REFERENCE_ELEMENTS,REFERENCE_INTERACTIONS,REFERENCE_STATUSES,REFERENCE_TABS,REFERENCE_GROUND,filterReferenceSpells,filterReferenceInteractions,referenceSpellRow,referenceStatusDetail,referenceMixtureTactics,referenceFormRows,type ReferenceCaster} from '../lib/combat-reference.ts';
import type {CombatReferenceProps} from '../app/components/CombatReference.tsx';
import {profileSpell,CURRENT_SPELL_MODEL} from '../lib/spell-profile-v42.ts';
import {profiledSpellDescription} from '../lib/spell-profile-label-v42.ts';
import {getCreature} from '../lib/campaign-creatures-v20.ts';
import {movementCost,previewField,fieldEffects,terrainCover,type SimCell} from '../lib/tactics-v22.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const loaded=loadSource(fileURLToPath(new URL('../app/components/CombatReference.tsx',import.meta.url))),Reference=loaded.CombatReference as ComponentType<CombatReferenceProps>,Button=loaded.CombatReferenceButton as ComponentType<CombatReferenceProps>;
const html=(props:CombatReferenceProps)=>renderToStaticMarkup(createElement(Reference,props)).replaceAll('&#x27;',"'").replaceAll('&amp;','&');

test('reference covers all live fields, six branches, spells and statuses without a parallel catalogue',()=>{
 assert.deepEqual(REFERENCE_ELEMENTS.map(entry=>entry.element),ELEMENT_ORDER);assert.equal(REFERENCE_INTERACTIONS.length,57);
 assert.deepEqual(new Set(REFERENCE_INTERACTIONS.map(field=>field.id)),new Set(COMBINATIONS.filter(field=>field.elements.length>1).map(field=>field.id)));
 assert.deepEqual(new Set(filterReferenceSpells().map(spell=>spell.id)),new Set(ALL_SPELLS.map(spell=>spell.id)));
 for(const status of STATUS_DEFINITIONS){const row=REFERENCE_STATUSES.find(entry=>entry.id===status.id);assert.ok(row);assert.equal(row.description,status.description);assert.ok(row.clearRule);}
 for(const element of REFERENCE_ELEMENTS){assert.equal(element.field,combinationFor([element.element]));assert.equal(element.advancedAt,3);assert.equal(element.maxLevel,6);}
});

test('mixture filters preserve complete recipes through six elements and explain exact mechanics',()=>{
 assert.equal(filterReferenceInteractions({size:2}).length,15);assert.equal(filterReferenceInteractions({size:3}).length,20);assert.equal(filterReferenceInteractions({size:4}).length,15);assert.equal(filterReferenceInteractions({size:5}).length,6);assert.equal(filterReferenceInteractions({size:6}).length,1);
 assert.equal(filterReferenceInteractions({element:'fire',size:3}).length,10);
 const steam=filterReferenceInteractions({query:'steam',size:2});assert.equal(steam.length,1);assert.equal(steam[0],combinationFor(['fire','water']));assert.match(steam[0].description,/rounded up/);
 assert.equal(filterReferenceInteractions({query:'not a recipe'}).length,0);
});

test('spell search works for teachers, advanced branches, shapes and effects and respects source filters',()=>{
 assert.equal(filterReferenceSpells({source:'standard'}).length,48);assert.equal(filterReferenceSpells({source:'champion'}).length,30);assert.equal(filterReferenceSpells({source:'creature'}).length,93);
 assert.ok(filterReferenceSpells({query:'Lightning',element:'fire'}).some(spell=>spell.id==='fire_lance'));
 assert.ok(filterReferenceSpells({query:'Oh Tipi',source:'champion'}).some(spell=>spell.signatureChampionId==='oh_tipi'));
 assert.ok(filterReferenceSpells({query:'piercing'}).every(spell=>`${spell.description} ${spell.name}`.toLowerCase().includes('piercing')));
 assert.ok(filterReferenceSpells({level:6}).every(spell=>spell.level===6));
 const ids=['ember','water_jet'];assert.deepEqual(new Set(filterReferenceSpells({spellIds:ids}).map(spell=>spell.id)),new Set(ids));
});

test('contextual rows match live affinity and current status modifiers without mutating registered spells',()=>{
 const caster:ReferenceCaster={championId:'oh_tipi',affinities:{water:3,fire:2},learnedSpells:[],statuses:{concussed:{turns:1,power:1},blind:{turns:1,power:1}}};
 for(const base of ALL_SPELLS){const before=JSON.stringify(base),row=referenceSpellRow(base,caster),effective=effectiveSpell(caster.championId,base.id,caster.affinities);assert.equal(row.spell.cost,spellCost(caster.championId,base.id,caster.affinities)+1);assert.equal(row.spell.range,effective.range===0?0:Math.max(1,effective.range-1));assert.equal(row.spell.damage,effective.damage);assert.equal(row.area,spellFootprintDescription(effective));assert.deepEqual(row.access,spellAccess(caster.championId,base.id,caster.affinities,[]));assert.equal(JSON.stringify(base),before);}
 const signature=getSignature('oh_tipi'),creator=referenceSpellRow(signature,caster);assert.equal(creator.requiredAffinity,3);assert.equal(referenceSpellRow(signature).requiredAffinity,5);
});

test('tables expose accessible sections and canonical branch emblems while closed menu mounts no catalogue',()=>{
 const markup=html({initialTab:'elements'});assert.equal((markup.match(/role="tab"/g)??[]).length,REFERENCE_TABS.length);assert.equal((markup.match(/aria-selected="true"/g)??[]).length,1);assert.match(markup,/<table/);assert.match(markup,/scope="col"/);assert.match(markup,/Lightning/);assert.match(markup,/Radiance/);assert.match(markup,/Void/);
 for(const element of REFERENCE_ELEMENTS)assert.ok(markup.includes(`aria-label="Inspect ${element.name} tactics"`));
 const closed=renderToStaticMarkup(createElement(Button,{}));assert.match(closed,/aria-label="Combat reference"/);assert.match(closed,/>Guide<\/button>/);assert.doesNotMatch(closed,/<table|<dialog|Lightning/);
});

test('spell reference starts from selected moves but retains an explicit full catalogue option',()=>{
 const ids=['ember','water_jet'],markup=html({initialTab:'spells',spellIds:ids,caster:{championId:'oh_tipi',name:'Oh Tipi',affinities:{water:3,fire:2}}});
 assert.match(markup,/Selected spells/);assert.match(markup,/Full catalogue/);assert.match(markup,/current affinity and status values/);assert.match(markup,/Ember/);assert.match(markup,/Water Jet/);assert.match(markup,/2 spells/);assert.doesNotMatch(markup,/Lightning Lance/);
 const base=html({initialTab:'spells'});assert.match(base,/Base values/);assert.match(base,/High ground can add 1 reach/);assert.match(base,/171 spells/);assert.equal((base.match(/<th scope="row"/g)??[]).length,8);
});

test('visible comparisons retain timing and counters while detailed rules have accessible inspection controls',()=>{
 const statuses=html({initialTab:'statuses'});assert.match(statuses,/Old Ward absorbs ordinary spell damage once/);assert.match(statuses,/Now: prevents new control/);assert.match(statuses,/Wet or cleanse before the tick/);assert.equal((statuses.match(/<th scope="row"/g)??[]).length,12);
 assert.match(referenceStatusDetail('ward').timing,/next exchange/);assert.match(referenceStatusDetail('clarity').timing,/immediately/);
 assert.match(REFERENCE_STATUSES.find(s=>s.id==='ward')!.clearRule,/even when fully blocked/);
 for(const status of REFERENCE_STATUSES)assert.ok(statuses.includes(`aria-label="Inspect ${status.name} status"`));
 const interactions=html({initialTab:'interactions'});assert.match(interactions,/Fields affect both teams/);assert.match(interactions,/57 mixtures/);assert.match(interactions,/2–6 elements/);assert.match(interactions,/How mixing works/);assert.match(interactions,/Purpose/);
 assert.match(interactions,/aria-label="Mixing rules" aria-haspopup="dialog" aria-expanded="false"/);
 assert.doesNotMatch(interactions,/Tower overtime/);const tower=html({initialTab:'spells',tower:true});assert.match(tower,/aria-label="Tower scrolls" aria-haspopup="dialog"/);
});

test('reference uses the active footprint model and distinguishes deterministic centre strength from the rim',()=>{
 const caster:ReferenceCaster={championId:'oh_tipi',affinities:{water:3,fire:2}};
 const focused=referenceSpellRow(getSpell('water_jet'),caster,'focused'),legacy=referenceSpellRow(getSpell('water_jet'),caster);
 assert.equal(focused.spell.shape,'burst');assert.equal(focused.spell.radius,2);assert.equal(focused.area,'19-hex burst');
 assert.equal(legacy.spell.shape,'hex');assert.equal(legacy.area,'One precise hex');
 assert.match(focused.summary,/Centre 4 · inner 3 · rim 1 damage/);assert.match(focused.spell.description,/^Inner-ring values: Deal 3 damage/);
 const markup=html({initialTab:'spells',spellIds:['water_jet'],caster,spellModel:'focused'});
 assert.match(markup,/19-hex burst/);assert.match(markup,/Centre 4 · inner 3 · rim 1 damage/);assert.match(markup,/aria-label="Inspect Water Jet" aria-haspopup="dialog"/);
 assert.doesNotMatch(markup,/One precise hex/);
});

test('ground comparisons distinguish natural ingredients from timed fields using native movement and protection rules',()=>{
 const plain:SimCell={q:0,r:0,well:false,biome:'plain',terrain:'plain',height:0};
 const water:SimCell={...plain,q:1,biome:'water',terrain:'water'},earth:SimCell={...plain,q:1,biome:'earth',terrain:'earth',height:1},forest:SimCell={...plain,q:1,biome:'forest',terrain:'earth'},marsh:SimCell={...plain,q:1,biome:'marsh',terrain:'water'};
 assert.deepEqual(fieldEffects(water),{});assert.equal(movementCost(plain,water),1);
 const flood=previewField(water,['water']);assert.equal(movementCost(plain,flood),2);assert.equal(movementCost(flood,plain),2);assert.ok(fieldEffects(flood).statuses?.some(s=>s.id==='wet'));
 const ice=previewField(water,['water'],true);assert.equal(movementCost(plain,ice),1);assert.equal(fieldEffects(ice).statuses?.some(s=>s.id==='wet'),false);
 assert.deepEqual(fieldEffects(earth),{});assert.equal(movementCost(plain,earth),2);assert.equal(movementCost(earth,plain),1);
 assert.equal(terrainCover(forest),1);assert.equal(previewField(forest,['fire']).terrain,'magma');
 assert.equal(movementCost(plain,marsh),2);assert.equal(movementCost(marsh,plain),1);assert.deepEqual(fieldEffects(marsh),{});
 const ground=Object.fromEntries(REFERENCE_GROUND.map(g=>[g.id,g]));assert.match(ground.water.effect,/no Wet or Flood/);assert.match(ground.forest.effect,/Earth ingredient; cover 1/);assert.match(ground.marsh.effect,/Water ingredient; no automatic Wet/);
 const markup=html({initialTab:'forms',spellModel:CURRENT_SPELL_MODEL});assert.match(markup,/Natural ground/);assert.match(markup,/Spell shapes/);assert.match(markup,/Natural water/);assert.match(markup,/Map & aim/);
});

test('shape comparison examples come from the selected profile and self aiming does not promise a one-hex effect',()=>{
 for(const model of [undefined,'focused',CURRENT_SPELL_MODEL] as const){
  const rows=referenceFormRows(model);
  assert.deepEqual(new Set(rows.map(row=>row.id)),new Set(['hex','burst','ring','line','sweep','wall','self']));
  for(const row of rows){assert.ok(row.example);assert.equal((row.example.range===0?'self':row.example.shape),row.id);assert.equal(row.footprint,spellFootprintDescription(profileSpell(getSpell(row.example.id),model)));}
  assert.match(rows.find(row=>row.id==='self')!.detail,/can still use a burst or ring/);
  assert.match(rows.find(row=>row.id==='ring')!.caution,/centre and inner hexes stay clear/);
  assert.match(rows.find(row=>row.id==='line')!.detail,/Every tied shortest open ray/);
 }
 assert.ok(referenceFormRows(CURRENT_SPELL_MODEL).find(row=>row.id==='burst')!.count>referenceFormRows().find(row=>row.id==='burst')!.count);
});

test('purpose filters cover every actual recipe without adding constituent effects or promising free advantages',()=>{
 for(const field of REFERENCE_INTERACTIONS){const row=referenceMixtureTactics(field);assert.ok(row.purposes.length,field.id);assert.ok(row.caution);for(const purpose of row.purposes)assert.ok(filterReferenceInteractions({purpose}).some(entry=>entry.id===field.id));}
 const steam=combinationFor(['fire','water'])!,magma=combinationFor(['fire','earth'])!,worldseed=combinationFor(ELEMENT_ORDER)!;
 assert.deepEqual(referenceMixtureTactics(steam).purposes,['shelter']);assert.match(referenceMixtureTactics(steam).caution,/shelters enemies/);
 assert.ok(!filterReferenceInteractions({purpose:'pressure'}).includes(steam));assert.ok(filterReferenceInteractions({purpose:'pressure'}).includes(magma));
 assert.match(referenceMixtureTactics(worldseed).duration,/after this exchange/);assert.match(referenceMixtureTactics(steam).duration,/this exchange and the next/);
 assert.match(referenceMixtureTactics(combinationFor(['fire','air'])!).caution,/does not retrigger/);
});

test('fixed creature kit access never pretends its own techniques require learning and legacy status examples retain their old role',()=>{
 const creature=getCreature('creature-water-puddle'),caster:ReferenceCaster={championId:creature.championId,creatureId:creature.id,affinities:creature.affinities,learnedSpells:[]};
 for(const id of creature.loadout)assert.equal(referenceSpellRow(getSpell(id),caster,CURRENT_SPELL_MODEL).access?.unlocked,true);
 const other=ALL_SPELLS.find(spell=>!creature.loadout.includes(spell.id))!;assert.equal(referenceSpellRow(other,caster).access?.unlocked,false);assert.equal(referenceSpellRow(other,caster).access?.reason,'Creature spell kits are fixed.');
 assert.ok(referenceStatusDetail('blind','focused').examples.includes('Sunburst'));assert.ok(!referenceStatusDetail('blind',CURRENT_SPELL_MODEL).examples.includes('Sunburst'));
});

test('area descriptions label inner values and preserve cleanse, conditional damage and original force direction',()=>{
 const cleanse=profiledSpellDescription(profileSpell(effectiveSpell('oh_tipi','cleansing_tide',{water:3}),'focused'));
 assert.match(cleanse,/^Inner-ring values:/);assert.match(cleanse,/Cleanse allies before healing/);assert.doesNotMatch(cleanse,/Centre crit:|half damage\/healing/);
 const freeze=profiledSpellDescription(profileSpell(getSpell('deep_freeze'),'focused'));
 assert.match(freeze,/Add 2 damage if already Wet before this exchange/);assert.match(freeze,/Freezes unmixed Water/);assert.match(freeze,/Rim: no direct statuses/);
 const force=profiledSpellDescription(profileSpell({...getSpell('water_jet'),push:1},'focused'));
 assert.match(force,/Push up to 1 hex away from the caster/);assert.match(force,/Guard resists 1 strength/);assert.match(force,/Terrain covers the area/);assert.doesNotMatch(force,/away from the aim centre/);
});
