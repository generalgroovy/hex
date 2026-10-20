import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,chooseTowerRoom,towerRoomChoices,createTowerSession} from '../lib/tower-v23.ts';
import {towerScrollSpell} from '../lib/tower-supplies-v45.ts';
import type {SimState} from '../lib/tactics-v22.ts';
const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}

const source=loadSource(fileURLToPath(new URL('../app/components/TowerSuppliesV45.tsx',import.meta.url)));
const Supplies=source.TowerSupplies as ComponentType<Record<string,unknown>>,Recipient=source.TowerSupplyRecipient as ComponentType<Record<string,unknown>>;
const Battle=loadSource(fileURLToPath(new URL('../app/components/TowerBattleV23.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const Rewards=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url))).TowerRewardChoices as ComponentType<Record<string,unknown>>;
test('supply transfer shows the receiving slot before an automatic swap',()=>{
 const run=createTowerRun('SUPPLIES-UI');run.party[0].charmId='river-stone';run.party[1].charmId='swallow-pin';run.party[0].scrollSpellId='mend';
 const html=renderToStaticMarkup(createElement(Supplies,{actor:run.party[0],party:run.party,editable:true,onTransfer:()=>{}}));
 assert.match(html,/swaps Swallow pin/);assert.match(html,/empty/);assert.match(html,/Start each fight/);assert.match(html,/printed strength/);assert.match(html,/Move charm to another fighter/);
});
test('a supply reward states its recipient, replacement and exact printed scroll profile',()=>{
 const run=createTowerRun('SUPPLIES-UI');run.party[0].scrollSpellId='mend';run.party[1].scrollSpellId='gale';
 const reward={id:'scroll:frostbite',kind:'scroll',spellId:'frostbite',name:'Frostbite scroll',description:'One cast; printed strength'};
 const html=renderToStaticMarkup(createElement(Recipient,{party:run.party,reward,onChoose:()=>{}}));assert.match(html,/Recipient for Frostbite scroll/);assert.match(html,/Replaces Mend scroll/);assert.match(html,/Equip scroll/);
 const card=renderToStaticMarkup(createElement(Rewards,{run,rewards:[reward],onChoose:()=>{}}));assert.match(card,/Scroll/);assert.match(card,/0 Flux/);assert.match(card,/radius|Radius/);assert.doesNotMatch(card,/Who can use it/);
});
test('Tower battle offers a separate one-use scroll and hides it once spent',()=>{
 let run=createTowerRun('SUPPLIES-UI');run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);run.party[0].scrollSpellId='immolate';run.party[0].charmId='river-stone';
 const battle=createTowerSession(run).battle!,props={battle,plan:{orders:[]},title:'Supply check',onChange:()=>{},onFinish:()=>{},onExit:()=>{}};
 const html=renderToStaticMarkup(createElement(Battle,props));assert.match(html,/Use Immolate scroll/);assert.match(html,/One use/);assert.match(html,/printed strength/);assert.match(html,/River stone/);
 battle.units[0].spentScroll=true;const spent=renderToStaticMarkup(createElement(Battle,props));assert.doesNotMatch(spent,/Use Immolate scroll/);
});
test('scroll command supplies complete printed menu metadata, sight penalty and actual access',()=>{
 let run=createTowerRun('SUPPLIES-UI');run=chooseTowerRoom(run,towerRoomChoices(run)[0].id);run.party[0].scrollSpellId='frostbite';
 const state=createTowerSession(run).battle!,unit=state.units[0];unit.affinities.water=6;unit.flux=0;unit.statuses.blind={turns:1,power:1};unit.statuses.concussed={turns:1,power:1};
 const details=loadSource(fileURLToPath(new URL('../app/components/TowerBattleV23.tsx',import.meta.url))).towerScrollCommand as (state:SimState,id:string,spell:string)=>{spell:{damage:number;range:number;cost:number;cooldown:number};cost:number;requiredAffinity:number;access:{unlocked:boolean;requiredAffinity:number};area:string;summary:string;origin:unknown;friendlyFire:boolean;recovery:number};
 const row=details(state,unit.id,'frostbite'),printed=towerScrollSpell('frostbite',state.spellModel);
 assert.equal(row.spell.damage,printed.damage);assert.equal(row.spell.range,printed.range-1);assert.equal(row.spell.cost,0);assert.equal(row.cost,0);assert.equal(row.recovery,0);assert.equal(row.spell.cooldown,0);
 assert.equal(row.requiredAffinity,0);assert.equal(row.access.requiredAffinity,0);assert.equal(row.access.unlocked,true);
 assert.equal(row.area,'19-hex burst');assert.ok(row.summary.length);assert.equal(row.origin,null);assert.equal(row.friendlyFire,true);
 unit.spentScroll=true;assert.equal(details(state,unit.id,'frostbite').access.unlocked,false);
});
