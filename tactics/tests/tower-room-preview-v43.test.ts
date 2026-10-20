import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType,type ReactElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,towerChampion,towerRoomChoices,type TowerRun,type TowerStart,type TowerMemberInput} from '../lib/tower-v23.ts';
import {scoutFactsForRoom} from '../lib/tower-scouting-state.ts';
import {scoutTowerRoom} from '../lib/tower-scouting-actions.ts';
import {towerRoomIntel} from '../lib/tower-scouting.ts';
import {availableSpellIds,getSpell} from '../lib/spells-v20.ts';
import type {TowerRoomPreviewProps} from '../app/components/TowerRoomPreviewV43.tsx';

const require=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function load(filename:string):Record<string,unknown>{
 const existing=modules.get(filename);if(existing)return existing.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{
  if(specifier.endsWith('.css'))return {};
  if(!specifier.startsWith('.'))return require(specifier);
  const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);
  assert.ok(found,`${filename}: ${specifier}`);return /\.tsx?$/.test(found)?load(found):require(found);
 };
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const Preview=load(fileURLToPath(new URL('../app/components/TowerRoomPreviewV43.tsx',import.meta.url))).default as ComponentType<TowerRoomPreviewProps>;
const noop=()=>{};
const champion=(id:string):TowerMemberInput=>{const actor=towerChampion(id,'temporary');return {kind:'champion',build:{championId:id,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout}};};
const start:TowerStart={starterId:'steam',members:[champion('oh_tipi'),champion('treevor_mason')]};
const html=(props:TowerRoomPreviewProps)=>renderToStaticMarkup(createElement(Preview,props)).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
const props=(run:TowerRun):TowerRoomPreviewProps=>({run,room:towerRoomChoices(run)[0],onChoose:noop,onScout:noop});
const button=(markup:string,label:string)=>[...markup.matchAll(/<button\b[^>]*>[\s\S]*?<\/button>/g)].map(match=>match[0]).find(tag=>tag.includes(`aria-label="${label}`))??'';
const text=(markup:string)=>markup.replace(/<[^>]*>/g,'');

test('the compact preview keeps all earned enemy facts visible, without rendering reserved spells or unknown identities',()=>{
 const run=createTowerRun('PREVIEW43-FACTS',start),room=towerRoomChoices(run)[0],facts=scoutFactsForRoom(run,room),before=JSON.stringify(run);
 const markup=html({...props(run),scoutReports:facts});
 for(const fact of facts)for(const detail of fact.kind==='identity'?fact.detail.split(' · '):[fact.detail])assert.ok(text(markup).includes(detail),`Missing earned fact: ${detail}`);
 assert.doesNotMatch(markup,/<details|earlier reports/);
 assert.match(markup,/Unseen spells/);
 assert.doesNotMatch(markup,/Some details unscouted/);
 for(const enemy of room.enemies){
  const known=facts.filter(fact=>fact.enemyId===enemy.id&&fact.kind==='spell').map(fact=>fact.spellId);
  const kit=enemy.creatureId?enemy.loadout:availableSpellIds(enemy.championId,enemy.loadout,enemy.affinities);
  const reserved=kit.filter(id=>!known.includes(id));assert.equal(reserved.length,1);
  const spellSection=[...markup.matchAll(/<div class="trp43-facts trp43-spells"[\s\S]*?<\/div>/g)].map(match=>match[0]).join('');
  for(const id of reserved)if(!facts.some(fact=>fact.spellId===id))assert.ok(!text(spellSection).includes(getSpell(id).name));
 }
 const health=facts.find(fact=>fact.kind==='health'&&fact.enemyId!==towerRoomIntel(room).knownEnemy?.enemyId)!;
 assert.ok(health);
 const onlyHealth=html({...props(run),scoutReports:[health]});
 assert.ok(text(onlyHealth).includes(health.detail));
 const enemy=room.enemies.find(enemy=>enemy.id===health.enemyId)!;
 assert.ok(!text(onlyHealth).includes(enemy.displayName!));
 assert.equal(JSON.stringify(run),before,'Reading a preview cannot spend a scout or mutate the encounter.');
});

test('foreign and other-door reports never enter the preview',()=>{
 const run=createTowerRun('PREVIEW43-REPORTS',start),foreign=createTowerRun('PREVIEW43-OTHER',start);
 const wrong=scoutFactsForRoom(foreign,towerRoomChoices(foreign)[0]),otherDoor=scoutFactsForRoom(run,towerRoomChoices(run)[1]);
 const baseline=html(props(run));
 assert.equal(html({...props(run),scoutReports:[...wrong,...otherDoor]}),baseline);
});

test('each available champion has a direct scouting action and spending one preserves the other',()=>{
 let run=createTowerRun('PREVIEW43-SCOUTS',start),markup=html(props(run));
 for(const actor of run.party)assert.doesNotMatch(button(markup,`Scout ${towerRoomChoices(run)[0].name} with ${actor.displayName}`),/disabled/);
 const tree=(Preview as (props:TowerRoomPreviewProps)=>ReactElement)(props(run));
 const callbacks:string[]=[];
 const interactive=(Preview as (props:TowerRoomPreviewProps)=>ReactElement)({...props(run),onScout:(actorId,roomId)=>callbacks.push(`${actorId}:${roomId}`)});
 const visit=(node:unknown):void=>{
  if(!node||typeof node!=='object')return;
  if(Array.isArray(node)){node.forEach(visit);return;}
  const element=node as ReactElement<Record<string,unknown>>;
  if(element.type==='button'&&String(element.props['aria-label']).startsWith('Scout '))(element.props.onClick as ()=>void)();
  visit(element.props?.children);
 };
 assert.ok(tree);visit(interactive);assert.deepEqual(callbacks,['hero:floor-1-0','companion:floor-1-0']);
 run=scoutTowerRoom(run,'hero','floor-1-0');markup=html(props(run));
 assert.match(button(markup,`Scout ${towerRoomChoices(run)[0].name} with ${run.party[0].displayName}`),/disabled/);
 assert.doesNotMatch(button(markup,`Scout ${towerRoomChoices(run)[0].name} with ${run.party[1].displayName}`),/disabled/);
 assert.match(markup,/Scout <span>1 left/);
 assert.doesNotMatch(button(markup,'Enter room'),/disabled/);
});

test('committed, replacement and network states cannot be mistaken for one another',()=>{
 const run=createTowerRun('PREVIEW43-DESTINATION',start);
 const chosen=html({...props(run),cooperative:true,chosen:true,scoutingLocked:true,partyNames:['Moss','Fern'],encounterCount:7});
 assert.match(chosen,/Your destination/);assert.match(chosen,/7 enemies/);assert.match(chosen,/Combined encounter/);assert.match(chosen,/Moss · Fern/);
 assert.match(button(chosen,'Destination chosen'),/disabled/);
 for(const actor of run.party)assert.match(button(chosen,`Scout ${towerRoomChoices(run)[0].name} with ${actor.displayName}`),/disabled/);
 const replacement=html({...props(run),cooperative:true,scoutingLocked:true,actionLabel:'Join Moss'});
 assert.match(replacement,/data-preview="true">Preview/);assert.doesNotMatch(replacement,/Your destination/);
 assert.doesNotMatch(button(replacement,'Join Moss'),/disabled/);
 const offline=html({...props(run),disabled:true});
 assert.match(button(offline,'Enter room'),/disabled/);
 for(const actor of run.party)assert.match(button(offline,`Scout ${towerRoomChoices(run)[0].name} with ${actor.displayName}`),/disabled/);
});

test('service rooms show the actual tuition payer and health consequence without offering scouting',()=>{
 const run={...createTowerRun('PREVIEW43-COST',start),floor:3},room=towerRoomChoices(run).find(room=>room.kind==='event')!;
 const eligible=html({...props(run),room}),name=run.party[0].displayName!;
 assert.match(eligible,new RegExp(`2 HP · ${name}`));assert.ok(text(eligible).includes(`${run.party[0].hp} → ${run.party[0].hp-2} HP`));
 assert.doesNotMatch(eligible,/Champion scouts|First fighter|Exact reward choices|Unseen spells/);
 assert.ok(text(eligible).includes(towerRoomIntel(room).reward));assert.doesNotMatch(button(eligible,'Enter room'),/disabled/);
 const injured={...run,party:run.party.map((actor,index)=>index?actor:{...actor,hp:2})};
 const blocked=html({...props(injured),room});assert.match(blocked,/2 HP · needs 3/);assert.match(button(blocked,'Requires 3 HP'),/disabled/);
 const three={...run,party:run.party.map((actor,index)=>index?actor:{...actor,hp:3})};
 const safe=html({...props(three),room});assert.ok(text(safe).includes('3 → 1 HP'));assert.doesNotMatch(button(safe,'Enter room'),/disabled/);
});
