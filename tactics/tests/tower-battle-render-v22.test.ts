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

const Battle=loadSource(fileURLToPath(new URL('../app/components/TowerBattleV22.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
function fixture(){const hero=canonicalBuild('oh_tipi'),pet=getCreature('creature-fire-cinder');return createTowerBattle({id:'render-room',mapId:'TOWER-RENDER',learnedSpells:[],allies:[{id:'hero',championId:hero.championId,displayName:hero.name,affinities:hero.affinities,loadout:hero.loadout,hp:5},{id:'friend',championId:pet.championId,creatureId:pet.id,affinities:pet.affinities,loadout:pet.loadout,hp:3}],enemies:[{id:'enemy',championId:pet.championId,creatureId:pet.id,affinities:pet.affinities,loadout:pet.loadout,hp:pet.maxHp}]});}
const render=(battle:SimState,previous?:SimState,finalRoom=false)=>renderToStaticMarkup(createElement(Battle,{battle,previous,finalRoom,plan:{orders:[]},title:'Kitchen inspection',onChange:()=>{},onFinish:()=>{},onExit:()=>{}}));
test('tower battle renders injured variable-sized parties, controls, and actual spell rules',()=>{
 const state=fixture(),html=render(state);
 assert.ok(html.includes('5 HP'));assert.ok(html.includes('3 HP'));assert.ok(html.includes('Kitchen inspection'));
 for(const text of ['End turn','Auto Guard','Move','Help','Your party','Enemy party','data-creature-action'])assert.ok(html.includes(text),text);
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
 const module=loadSource(fileURLToPath(new URL('../app/components/TowerBattleV22.tsx',import.meta.url))),adapt=module.reviewState as (state:SimState)=>CampaignState,view=adapt(state),plan={orders:[{unitId:hero.id,spellId:hero.loadout[0],cast:{q:target.q,r:target.r}}]};
 assert.equal(view.rulesVersion,20);assert.equal(state.rulesVersion,22);assert.notEqual(view,state);
 const forecast=planningForecast(view,0,plan,hero.id,'water_jet',target);assert.ok(forecast);assert.ok(forecast.cells.length>0);assert.ok(forecast.groups.length>0);
 const volley=projectedVolley(view,0,plan);assert.ok(volley.casts.length>0);
 assert.equal(state.rulesVersion,22,'Presentation must not mutate the saved tower version');
});

test('co-op battle opens on the controlled actor and exposes ready/unlock rather than solo resolution',()=>{
 const battle=fixture(),props={battle,plan:{orders:[]},controlledActorIds:['friend'],teammatePlan:{orders:[{unitId:'hero',guard:true}]},title:'Together',onChange:()=>{},onFinish:()=>{},onExit:()=>{},onLockPlan:()=>{},onUnlockPlan:()=>{}};
 const html=renderToStaticMarkup(createElement(Battle,props));
 assert.match(html,/Ready together/);assert.doesNotMatch(html,/>End turn</);
 assert.match(html,/s18-command-heading[^>]*><strong>Cinder/);
 assert.match(html,/Partner · Guard/);
 const locked=renderToStaticMarkup(createElement(Battle,{...props,locked:true,networkStatus:'Ready · waiting for your friend'}));
 assert.match(locked,/Edit orders/);assert.match(locked,/waiting for your friend/);
 assert.match(locked,/<button[^>]*disabled=""[^>]*>Ready<small/);
});

test('tower landing warnings use the tower boundary rather than the later multiplayer boundary',()=>{
 const battle=fixture();battle.round=6;
 const zone=endgameForecast(battle),point={q:8,r:0},note=landingBoundaryNote(battle,point);
 assert.equal(zone.phase,'closing');assert.equal(note?.damage,zone.damage);assert.equal(note?.severity,'danger');assert.match(frontierReadout(zone)!.title,/damage outside/);
});

test('Overtime shows the actual symmetric round healing reduction',()=>{const battle=fixture();battle.round=6;assert.match(render(battle),/Each fighter heals 1 less per round/);battle.round=9;assert.match(render(battle),/Each fighter heals 2 less per round/);assert.match(render(battle),/Overtime cannot be cleansed/);});
