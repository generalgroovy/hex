import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {getCreature} from '../lib/campaign-creatures-v20.ts';
import {createTowerBattle,resolveRound,legalCasts,type SimState} from '../lib/tactics-v22.ts';
import {createSharedTowerBattle,sharedControlledActorIds} from '../lib/tower-shared-battle-v23.ts';
import {createTowerRun,chooseTowerRoom,towerRoomChoices} from '../lib/tower-v23.ts';
import {planningForecast} from '../lib/planning-forecast-v20.ts';
import {projectedVolley} from '../lib/planned-volley-v20.ts';
import {landingBoundaryNote,frontierReadout} from '../lib/tower-guidance-v22.ts';
import {endgameForecast} from '../lib/tower-endgame-v22.ts';
import type {SimState as CampaignState} from '../lib/tactics-v20.ts';
const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}

const Battle=loadSource(fileURLToPath(new URL('../app/components/TowerBattleV23.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const Outcomes=loadSource(fileURLToPath(new URL('../app/components/CampaignReviewV20.tsx',import.meta.url))).OutcomeCards as ComponentType<Record<string,unknown>>;
function fixture(){const hero=canonicalBuild('oh_tipi'),pet=getCreature('creature-fire-cinder');return createTowerBattle({id:'render-room',mapId:'TOWER-RENDER',learnedSpells:[],allies:[{id:'hero',championId:hero.championId,displayName:hero.name,affinities:hero.affinities,loadout:hero.loadout,hp:5},{id:'friend',championId:pet.championId,creatureId:pet.id,affinities:pet.affinities,loadout:pet.loadout,hp:3}],enemies:[{id:'enemy',championId:pet.championId,creatureId:pet.id,affinities:pet.affinities,loadout:pet.loadout,hp:pet.maxHp}]});}
const render=(battle:SimState,previous?:SimState,finalRoom=false)=>renderToStaticMarkup(createElement(Battle,{battle,previous,finalRoom,plan:{orders:[]},title:'Kitchen inspection',onChange:()=>{},onFinish:()=>{},onExit:()=>{}}));
test('tower battle renders injured variable-sized parties, controls, and actual spell rules',()=>{
 const state=fixture(),html=render(state);
 const party=html.match(/<div class="s18-unit-tabs"[\s\S]*?<\/div>/)?.[0]??'',partyText=party.replace(/<[^>]*>/g,'');
 assert.ok(partyText.includes('5/8 HP'),'The injured champion shows current and maximum health');assert.ok(partyText.includes('3/4 HP'),'The injured creature retains its own health scale');assert.ok(partyText.includes('6/6 Flux'));assert.ok(partyText.includes('4/4 Flux'));assert.ok(html.includes('Kitchen inspection'));
 for(const text of ['End turn','Auto Guard','Move','aria-label="Battle help and animation settings"','Your party','Enemy party','data-creature-action'])assert.ok(html.includes(text),text);
 assert.ok(!html.includes('Retry encounter'));assert.ok(!html.includes('Learned spells are kept;'));
 assert.ok(html.includes('Health carries upstairs.'));assert.ok(html.includes('Full exchange'));
});
test('tower battle can expose a finished result and replay without a campaign profile',()=>{
 const before=fixture(),after=resolveRound(before,[{orders:[]},{orders:[]}]);
 // Explicit rendering fixture: outcome is not used as resolver or save evidence.
 for(const unit of after.units.filter(unit=>unit.owner===1)){unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;}after.winner=0;
 const html=render(after,before);assert.ok(html.includes('Room cleared'));assert.ok(html.includes('Choose reward'));assert.ok(html.includes('Round report'));assert.ok(html.includes('Replay'));
 assert.ok(!html.includes('s18-queued-action'));assert.ok(!html.includes('s18-frontier'));assert.ok(!html.includes('See run →'));const final=render(after,before,true);assert.ok(final.includes('Tower cleared'));assert.ok(final.includes('Finish climb'));assert.ok(!final.includes('Choose reward'));
});

test('tower read-only presentation adapter retains field forecasts and actual spell trajectories',()=>{
 const state=fixture(),hero=state.units[0],target=legalCasts(state,hero.id,undefined,hero.loadout[0]).find(cell=>cell.q!==hero.q||cell.r!==hero.r)!;
 const module=loadSource(fileURLToPath(new URL('../app/components/TowerBattleV23.tsx',import.meta.url))),adapt=module.reviewState as (state:SimState)=>CampaignState,view=adapt(state),plan={orders:[{unitId:hero.id,spellId:hero.loadout[0],cast:{q:target.q,r:target.r}}]};
 assert.equal(view.rulesVersion,20);assert.equal(state.rulesVersion,22);assert.notEqual(view,state);
 const forecast=planningForecast(view,0,plan,hero.id,'water_jet',target);assert.ok(forecast);assert.ok(forecast.cells.length>0);assert.ok(forecast.groups.length>0);
 const volley=projectedVolley(view,0,plan);assert.ok(volley.casts.length>0);
 assert.equal(state.rulesVersion,22,'Presentation must not mutate the saved tower version');
});

test('remote independent battle owns its complete party and submits its own end turn',()=>{
 const battle=fixture(),props={battle,plan:{orders:[]},title:'My room',onChange:()=>{},onFinish:()=>{},onExit:()=>{},onLockPlan:()=>{}};
 const html=renderToStaticMarkup(createElement(Battle,props));
 assert.match(html,/>End turn</);assert.doesNotMatch(html,/Ready together|Partner ·/);
 const party=html.match(/<div class="s18-unit-tabs"[\s\S]*?<\/div>/)?.[0]??'',selected=party.match(/<button\b[^>]*aria-pressed="true"[^>]*>[\s\S]*?<\/button>/)?.[0]??'';
 assert.ok(selected.includes('<strong>Oh Tipi</strong>'),'The owned champion remains selected');assert.equal((party.match(/<button /g)??[]).length,2,'Both owned fighters remain selectable');
 assert.match(party,/<strong>Cinder<\/strong>/,'The owned creature remains selectable');
 assert.match(html,/<button\b[^>]*aria-label="Inspect Oh Tipi"[^>]*>/,'Selected fighter detail access remains available through an accessible button');
});

test('watching is read-only even when action callbacks and owned actor IDs are supplied',()=>{
 const battle=fixture(),props={battle,plan:{orders:[{unitId:'hero',guard:true}]},title:'A friend’s room',spectator:true,spectatorName:'Moss',controlledActorIds:['hero','friend'],onChange:()=>{throw Error('must not edit')},onFinish:()=>{throw Error('must not finish')},onExit:()=>{},onLockPlan:()=>{},onUnlockPlan:()=>{},locked:true,networkStatus:'Watching Moss'};
 const html=renderToStaticMarkup(createElement(Battle,props));
 for(const text of ['Moss’s party','Watching live','Return to my squad','Inspect Cinder','data-spectator="true"'])assert.ok(html.includes(text),text);
 for(const text of ['End turn','Ready together','Edit orders','s18-command-dock','s18-queued-action','Choose reward'])assert.ok(!html.includes(text),text);
 assert.ok(!/Available (move|cast) target/.test(html));
 const finished=resolveRound(battle,[{orders:[]},{orders:[]}]);
 // Rendering-only terminal fixture; not claimed as a resolved victory.
 finished.winner=0;
 const result=renderToStaticMarkup(createElement(Battle,{...props,battle:finished,previous:battle}));
 assert.match(result,/Room cleared/);assert.match(result,/Replay last round/);assert.doesNotMatch(result,/Choose reward|Finish climb|See run →/);
});

test('tower landing warnings use the tower boundary rather than the later multiplayer boundary',()=>{
 const battle=fixture();battle.round=6;
 const zone=endgameForecast(battle),point={q:8,r:0},note=landingBoundaryNote(battle,point);
 assert.equal(zone.phase,'closing');assert.equal(note?.damage,zone.damage);assert.equal(note?.severity,'danger');assert.match(frontierReadout(zone)!.title,/damage outside/);
});

test('Overtime shows the actual symmetric round healing reduction',()=>{const battle=fixture();battle.round=6;assert.match(render(battle),/Each fighter heals 1 less per round/);battle.round=9;assert.match(render(battle),/Each fighter heals 2 less per round/);assert.match(render(battle),/Overtime cannot be cleansed/);});

test('shared battle gives orders only to your own squad and folds allied detail into inspection',()=>{
 const entries=[0,1,2].map(seat=>{const run=createTowerRun('SHARED-UI','steam');return {seat,run:chooseTowerRoom(run,towerRoomChoices(run)[0].id)}}),battle=createSharedTowerBattle(entries),controlledActorIds=sharedControlledActorIds(battle,1);
 const markup=renderToStaticMarkup(createElement(Battle,{battle,controlledActorIds,teammatePlan:{orders:[{unitId:'seat-0:hero',guard:true}]},plan:{orders:[]},title:'Shared room',onChange:()=>{},onFinish:()=>{},onExit:()=>{},onLockPlan:()=>{},networkStatus:'Plan together · 0/3 players ready'}));
 assert.match(markup,/>Ready</);assert.match(markup,/Allies · 4 standing/);assert.match(markup,/Link spells/);assert.doesNotMatch(markup,/Enemy movement is unknown|Enemy orders reveal with yours/);
 const tabs=markup.split('class="s18-unit-tabs"')[1].split('t23-allied-squads')[0];assert.equal((tabs.match(/<button /g)??[]).length,2);
 const locked=renderToStaticMarkup(createElement(Battle,{battle,controlledActorIds,plan:{orders:[]},locked:true,title:'Shared room',onChange:()=>{},onFinish:()=>{},onExit:()=>{},onLockPlan:()=>{},onUnlockPlan:()=>{},networkStatus:'Orders ready · 1/3 players ready'}));assert.match(locked,/Edit orders/);assert.doesNotMatch(locked,/Available move target/);
});

test('shared round review focuses on your squad while the full report retains everyone',()=>{
 const before=fixture(),after=resolveRound(before,[{orders:[]},{orders:[]}]);
 const all=renderToStaticMarkup(createElement(Outcomes,{previous:before,state:after,onInspect:()=>{}}));
 const own=renderToStaticMarkup(createElement(Outcomes,{previous:before,state:after,unitIds:['hero','friend'],onInspect:()=>{}}));
 assert.equal((all.match(/<button /g)??[]).length,3);
 assert.equal((own.match(/<button /g)??[]).length,2);
 assert.doesNotMatch(own,/data-side="enemy"/);
});
