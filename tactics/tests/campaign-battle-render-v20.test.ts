import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {readCampaignProfile,validateCampaignProfile,updateCampaignCompanions,createCampaignGame,presentCampaign} from '../lib/story-v20.ts';
import {CHAMPIONS} from '../lib/roster-v13.ts';
import {getSpell,effectiveSpell,getCreatureSpell} from '../lib/spells-v20.ts';
import {legalMoves,legalCasts,spellArea,resolveRound,availableUnitSpellIds,castAvailability,battleSpell,type SimState,type TeamPlan,type SimEvent} from '../lib/tactics-v20.ts';
import {enemyThreatReader} from '../lib/enemy-threat-v42.ts';
import {enemyRangeSubject} from '../lib/enemy-range-subject-v42.ts';
import {createSimGame as arenaGame} from '../lib/tactics-v18.ts';
import {presentArena} from '../lib/skirmish-client-v18.ts';
import {CURRENT_SPELL_MODEL} from '../lib/spell-profile-v42.ts';
import {createSimGame as classicGame} from '../lib/tactics-v16.ts';
import {projectedVolley} from '../lib/planned-volley-v20.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import type {BattlefieldSpellRules} from '../app/components/PixelBattlefieldV16.tsx';

// Same isolated TSX loader as the existing sprite/workshop render tests. CSS is
// deliberately skipped: this checks semantic markup and rules injection, not pixels.
const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const reviewSource=loadSource(fileURLToPath(new URL('../app/components/CampaignReviewV20.tsx',import.meta.url)));
const Review=reviewSource.default as ComponentType<{previous?:SimState;state:SimState;learned?:string[]}>;
const Highlights=reviewSource.PhaseHighlights as ComponentType<{state:SimState;phase:'move'|'cast'|'impact'|'settle'}>;
const Outcomes=reviewSource.OutcomeCards as ComponentType<{previous:SimState;state:SimState;onInspect:(id:string)=>void}>;
const Board=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV16.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const markup=(component:ComponentType<any>,props:Record<string,unknown>)=>renderToStaticMarkup(createElement(component,props)).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
const empty=():TeamPlan=>({orders:[]});
function mixedCast(){
 const late=validateCampaignProfile({...readCampaignProfile(null),defeated:CHAMPIONS.slice(0,20).map(hero=>hero.id)});
 const profile=updateCampaignCompanions(late,['creature-steam',late.companions[0]]),before=createCampaignGame(profile,CHAMPIONS[20].id),actor=before.units.find(unit=>unit.owner===0&&unit.creatureId==='creature-steam')!,spell=getCreatureSpell('creature-steam');
 const targets=legalCasts(before,actor.id,undefined,spell.id),aim=targets.find(cell=>cell.q!==actor.q||cell.r!==actor.r)!;assert.ok(aim);
 const plan:TeamPlan={orders:[{unitId:actor.id,spellId:spell.id,cast:{q:aim.q,r:aim.r}}]},after=resolveRound(before,[plan,empty()]);
 assert.ok(after.lastResolution.some(event=>event.kind==='cast'&&event.spellId===spell.id));
 const rules:BattlefieldSpellRules={getSpell,effectiveSpell,spellArea:(_state,id,spellId,target,from)=>spellArea(before,id,spellId,target,from),projectedVolley:(_state,player,draft)=>projectedVolley(before,player,draft)};
 const unitPresentation=Object.fromEntries(before.units.map(unit=>[unit.id,{name:unit.displayName,color:unit.owner===0?'#176f76':'#a94230',label:unit.owner===0?'Your party':'Enemy party',creatureId:unit.creatureId}]));
 return {before,after,actor,spell,aim,plan,rules,unitPresentation,targets};
}

test('the complete round report keeps every character, every action, actual resource changes and newly learned spells',()=>{
 const before=createCampaignGame(readCampaignProfile(null),'oh_tipi'),state=resolveRound(before,[empty(),empty()]);
 before.units[0].hp=5;state.units[0].hp=6;before.units[0].statuses.burn={turns:1,power:1};delete state.units[0].statuses.burn;
 const details=Array.from({length:15},(_,index)=>`Unique consequence ${index+1}.`);
 state.lastResolution.push(...details.map(text=>({kind:'damage',unitId:state.units[0].id,amount:4,text} as SimEvent)));
 const learned=getCreatureSpell('creature-air-pip'),html=markup(Review,{previous:before,state,learned:[learned.id]});
 for(const detail of details)assert.ok(html.includes(detail));
 assert.equal((html.match(/<th scope="row">/g)??[]).length,state.units.length);
 assert.ok(html.includes('5 → 6'));assert.ok(html.includes('Burn ended'));assert.ok(html.includes(learned.name));assert.ok(html.includes('Knowledge is kept even if the rest of this battle is lost.'));
 const guardText=state.lastResolution.find(event=>event.kind==='guard'&&event.unitId==='0-hero')!.text;
 assert.equal(html.split(guardText).length-1,2,'The two Oh Tipis retain separate action rows');
 const highlights=markup(Highlights,{state,phase:'impact'});assert.ok(highlights.includes('more in the round report'));assert.ok(!highlights.includes(details[14]),'The brief summary is bounded while the full report is complete');
});

test('duplicate creatures remain unambiguous in cards, table rows and events without changing the event record',()=>{
 const before=createCampaignGame(readCampaignProfile(null),'field:creature-fire-cinder'),state=resolveRound(before,[empty(),empty()]),savedEvents=structuredClone(state.lastResolution);
 const cinders=state.units.filter(unit=>unit.creatureId==='creature-fire-cinder');assert.ok(cinders.some(unit=>unit.owner===0));assert.ok(cinders.some(unit=>unit.owner===1));
 const guard=state.lastResolution.find(event=>event.kind==='guard'&&event.unitId===cinders[0].id)!.text;
 const report=markup(Review,{previous:before,state}),cards=markup(Outcomes,{previous:before,state,onInspect:()=>{}});
 assert.ok(report.includes(`<li>Your party · ${guard}</li>`));assert.ok(report.includes(`<li>Enemy · ${guard}</li>`));
 assert.ok(report.includes('<th scope="row">Cinder<span class="c20-side-badge" data-side="ally"> Your party</span></th>'));
 assert.ok(report.includes('<th scope="row">Cinder<span class="c20-side-badge" data-side="enemy"> Enemy</span></th>'));
 assert.ok(cards.includes('aria-label="Your party · Cinder.'));assert.ok(cards.includes('aria-label="Enemy · Cinder.'));
 assert.equal((cards.match(/class="c20-side-badge"/g)??[]).length,state.units.length);
 const highlights=markup(Highlights,{state,phase:'cast'});assert.ok(highlights.includes('Your party · '));
 assert.deepEqual(state.lastResolution,savedEvents,'Attribution is presentation-only and never changes persistent replay events');
});

test('current mixed spell planning reaches the shared renderer through injected rules and displays the full forecast',()=>{
 const {before,actor,spell,aim,plan,rules,unitPresentation,targets}=mixedCast(),forecast=planningForecast(before,0,plan,actor.id)!;
 const html=markup(Board,{state:presentCampaign(before),plan,player:0,selected:actor.id,kind:'cast',onCell:()=>{},onInspectUnit:()=>{},interactive:true,spellId:spell.id,spellRules:rules,presentationOnlyRules:true,unitPresentation,boardRadius:before.boardRadius,legalTargets:targets,affectedTargets:forecast.cells,aimTarget:aim,forecast});
 assert.ok(html.includes(`data-order-unit="${actor.id}"`));assert.ok(html.includes(`data-queued-cast-unit="${actor.id}"`),'The mixed creature technique retains its actual projected trajectory');assert.ok(html.includes('aria-label="Planned fields"'));
 for(const cell of forecast.cells)assert.ok(html.includes(`data-forecast-field="${cell.field}"`),'The injected current rules reach every planned field marker');
 for(const group of forecast.groups)assert.ok(html.includes(group.name));
 assert.ok(html.includes('data-creature-action="idle"'),'Owned creatures retain their own sprite renderer');
});

test('mixed spell playback uses its declared primary palette, draws its actual footprint, and keeps classic rendering compatible',()=>{
 const {before,after,actor,spell,rules,unitPresentation}=mixedCast();assert.equal(spell.element,'water');assert.equal(spell.fieldElements?.[0],'fire');
 const html=markup(Board,{state:presentCampaign(after),previousState:presentCampaign(before),plan:empty(),player:0,selected:actor.id,kind:'cast',onCell:()=>{},onInspectUnit:()=>{},interactive:false,spellRules:rules,presentationOnlyRules:true,unitPresentation,boardRadius:before.boardRadius,playback:{phase:'impact',active:true,key:1}});
 assert.ok(html.includes(`data-cast-spell="${spell.id}"`));assert.ok(html.includes('class="px-cast-event px-element-water"'),'Primary Water coloring must not use the first Fire mixture ingredient');
 const event=after.lastResolution.find(event=>event.kind==='cast'&&event.unitId===actor.id)!;
 const area=spellArea(before,actor.id,spell.id,event.to!,event.from);
 assert.equal((html.match(new RegExp(`data-cast-spell="${spell.id}"`,'g'))??[]).length,area.length);
 const classic=classicGame(),oldHtml=markup(Board,{state:classic,plan:empty(),player:0,selected:classic.units[0].id,kind:'move',onCell:()=>{},interactive:true});
 assert.ok(oldHtml.includes('class="px-battlefield"'),'The optional seam must not make old games require current rules');
});

test('enemy hover previews expose the native public movement and spell envelope, never during playback',()=>{
 const state=createCampaignGame(readCampaignProfile(null),'oh_tipi'),enemy=state.units.find(unit=>unit.owner===1)!;
 const reader=enemyThreatReader(state,{legalMoves,legalCasts,spellArea,availableUnitSpellIds,castAvailability,spellGeometry:battleSpell}),preview=reader(enemy.id)!;
 const props={state:presentCampaign(state),plan:empty(),player:0,selected:state.units[0].id,kind:'move',onCell:()=>{},interactive:true,enemyThreat:reader,previewEnemyId:enemy.id,presentationOnlyRules:true};
 const html=markup(Board,props);
 assert.ok(html.includes(`data-enemy-threat-unit="${enemy.id}"`));
 assert.equal((html.match(/data-enemy-move-cell=/g)??[]).length,preview.move.length);
 assert.equal((html.match(/data-enemy-spell-cell=/g)??[]).length,preview.attack.length);
 assert.ok(html.includes('Spell reach'));assert.ok(html.includes('not a committed attack or guaranteed damage'));
 assert.ok(!html.includes('data-range-boundary="move"'),'Inspection gives the enemy boundary visual priority');
 const playing=markup(Board,{...props,resolving:true,playback:{phase:'move',active:true,key:1}});
 assert.ok(!playing.includes('data-enemy-threat-unit='),'Reach is hidden when resolution changes positions');
 const ally=markup(Board,{...props,previewEnemyId:state.units[0].id});
 assert.ok(!ally.includes('data-enemy-threat-unit='),'An allied portrait never becomes an enemy threat');
});

test('focused centre and rim markup follows the native area while old battle snapshots keep their original preview',()=>{
 const state=createCampaignGame(readCampaignProfile(null),'oh_tipi'),actor=state.units[0],spellId='water_jet';
 const target=legalCasts(state,actor.id,undefined,spellId).find(aim=>spellArea(state,actor.id,spellId,aim).length>=19)!;
 assert.ok(target);
 const cells=spellArea(state,actor.id,spellId,target);
 const props={state:presentCampaign(state),plan:empty(),player:0,selected:actor.id,kind:'cast',onCell:()=>{},interactive:true,spellId,aimTarget:target,affectedTargets:cells};
 const html=markup(Board,props);
 assert.ok(html.includes('data-focused-area="water_jet"'));
 assert.equal((html.match(/data-focus-zone="centre"/g)??[]).length,1);
 assert.equal((html.match(/data-focus-zone="inner"/g)??[]).length,6);
 assert.equal((html.match(/data-focus-zone="rim"/g)??[]).length,12);
 delete state.spellModel;
 const legacy=markup(Board,{...props,state:presentCampaign(state),affectedTargets:spellArea(state,actor.id,spellId,target)});
 assert.ok(!legacy.includes('data-focused-area='));assert.ok(!legacy.includes('data-focus-zone='));
});

test('cast aiming suppresses map enemy hover, focus and pins while explicit inspection remains available',()=>{
 const interaction={kind:'cast' as const,inspecting:false,viewingExchange:false,hover:'enemy',focus:'enemy',pinned:'enemy'};
 assert.equal(enemyRangeSubject(interaction),null,'All automatic map range sources yield to the aimed spell');
 assert.equal(enemyRangeSubject({...interaction,kind:'move'}),'enemy');
 assert.equal(enemyRangeSubject({...interaction,inspecting:true}),'enemy');
 assert.equal(enemyRangeSubject({...interaction,card:'portrait-enemy'}),'portrait-enemy');
 assert.equal(enemyRangeSubject({...interaction,card:'portrait-enemy',viewingExchange:true}),null);
 const state=createCampaignGame(readCampaignProfile(null),'oh_tipi'),actor=state.units[0],enemy=state.units.find(unit=>unit.owner===1)!,spellId='water_jet';
 const target=legalCasts(state,actor.id,undefined,spellId).find(aim=>spellArea(state,actor.id,spellId,aim).length>=19)!;
 Object.assign(enemy,{q:target.q,r:target.r});
 const reader=enemyThreatReader(state,{legalMoves,legalCasts,spellArea,availableUnitSpellIds,castAvailability,spellGeometry:battleSpell});
 const props={state:presentCampaign(state),plan:empty(),player:0,selected:actor.id,kind:'cast',onCell:()=>{},interactive:true,spellId,aimTarget:target,affectedTargets:spellArea(state,actor.id,spellId,target),legalTargets:legalCasts(state,actor.id,undefined,spellId),enemyThreat:reader};
 const aiming=markup(Board,props);
 assert.ok(aiming.includes('data-focused-area="water_jet"'));
 assert.ok(aiming.includes('data-range-boundary="cast"'));
 assert.ok(!aiming.includes('data-enemy-threat-unit='),'An enemy beneath the aim does not add its full threat envelope');
 const inspecting=markup(Board,{...props,previewEnemyId:enemy.id});
 assert.ok(inspecting.includes(`data-enemy-threat-unit="${enemy.id}"`),'Deliberate portrait inspection still works while a spell is selected');
});

test('both current explicit presentation paths retain the focused spell model without upgrading old snapshots',()=>{
 const story=createCampaignGame(readCampaignProfile(null),'oh_tipi'),arena=arenaGame({playerCount:2});
 assert.equal(presentCampaign(story).spellModel,CURRENT_SPELL_MODEL);
 assert.equal(presentArena(arena,0).spellModel,CURRENT_SPELL_MODEL);
 story.spellModel='focused';arena.spellModel='focused';
 assert.equal(presentCampaign(story).spellModel,'focused');
 assert.equal(presentArena(arena,0).spellModel,'focused');
 delete story.spellModel;delete arena.spellModel;
 assert.equal(presentCampaign(story).spellModel,undefined);
 assert.equal(presentArena(arena,0).spellModel,undefined);
});
