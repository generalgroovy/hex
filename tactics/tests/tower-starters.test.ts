import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {TOWER_STARTERS,TOWER_SOLO_STARTERS,validateTowerStarter,createTowerRun,createTowerSession,restoreTowerSession,towerStartingAffinity,towerRoomChoices,chooseTowerRoom,towerBattleConfig,type TowerStart} from '../lib/tower-v23.ts';
import {TOWER_STARTERS as previousStarters} from '../lib/tower-v22.ts';
import {affinityTotal,getChampion} from '../lib/roster-v13.ts';
import {getCreature} from '../lib/campaign-creatures-v20.ts';
import {getSpell,validateLoadout,spellCost} from '../lib/spells-v20.ts';
import {createTowerBattle,chooseAIPlan,validatePlan,resolveRound} from '../lib/tactics-v22.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const Picker=loadSource(fileURLToPath(new URL('../app/components/TowerTeamPickerV23.tsx',import.meta.url))).default as ComponentType<{value:TowerStart;onChange:(next:TowerStart)=>void;soloSuggestions?:boolean}>;
const html=(soloSuggestions=false,value=validateTowerStarter('steam'))=>renderToStaticMarkup(createElement(Picker,{value,onChange:()=>{},soloSuggestions})).replaceAll('&#x27;',"'").replaceAll('&amp;','&');

test('solo suggestions follow the requested seven champions while original shared suggestions stay unchanged',()=>{
 assert.deepEqual(TOWER_SOLO_STARTERS.map(starter=>starter.heroId),['oh_tipi','s_wayne','red_baron','steezo','treevor_mason','oll_i','wa_bidi']);
 assert.deepEqual(TOWER_STARTERS.map(starter=>starter.id),['steam','stone','dusk']);
 for(const previous of previousStarters){const current=TOWER_STARTERS.find(starter=>starter.id===previous.id)!;assert.ok(current);for(const key of ['name','description','heroId','companionId','party'] as const)assert.deepEqual(current[key],previous[key]);}
 assert.equal(createTowerRun('DEFAULT').starterId,'steam');
});

test('all seven starts have equal legal budgets, affordable kits and round-trip saved sessions',()=>{
 for(const starter of TOWER_SOLO_STARTERS){
  const chosen=validateTowerStarter(starter.id),run=createTowerRun('SEVEN',chosen);assert.equal(chosen.members.length,2);assert.equal(towerStartingAffinity(run),7);
  const hero=chosen.members[0],pet=chosen.members[1];assert.equal(hero.kind,'champion');assert.equal(pet.kind,'creature');if(hero.kind!=='champion'||pet.kind!=='creature')continue;
  assert.equal(affinityTotal(hero.build.affinities),5);assert.ok(Object.keys(hero.build.affinities).length<=3);assert.equal(hero.build.championId,starter.heroId);
  assert.deepEqual(validateLoadout(hero.build.championId,hero.build.loadout,hero.build.affinities),hero.build.loadout);assert.ok(hero.build.loadout.every(id=>spellCost(hero.build.championId,id,hero.build.affinities)<=6));
  const creature=getCreature(pet.creatureId);assert.equal(creature.strengthClass,'lesser');assert.equal(affinityTotal(creature.affinities),2);
  assert.deepEqual(restoreTowerSession(createTowerSession(run)).run,run);
 }
});

test('new suggestions describe effects their actual selected spells provide',()=>{
 const party=(id:string)=>createTowerRun('KITS',id).party;
 const spells=(id:string,index:number)=>party(id)[index].loadout.map(getSpell);
 assert.ok(spells('baron',0).some(spell=>spell.bonus==='burn'));assert.ok(spells('baron',1).some(spell=>spell.harmful?.some(effect=>effect.id==='rooted')));
 assert.ok(spells('steezo',1).some(spell=>spell.recharge&&spell.friendly?.some(effect=>effect.id==='haste')));
 assert.ok(spells('oll_i',0).some(spell=>spell.pierce));assert.ok(spells('oll_i',0).some(spell=>spell.heal));assert.ok(spells('oll_i',1).some(spell=>spell.drain));
 assert.ok(spells('wa_bidi',0).some(spell=>spell.selfDamage));assert.ok(spells('wa_bidi',1).some(spell=>spell.heal&&spell.friendly?.some(effect=>effect.id==='clarity')));
});

test('every suggested pair starts a real encounter with legal independent orders',()=>{
 for(const starter of TOWER_SOLO_STARTERS){
  const run=createTowerRun('SEVEN',starter.id),room=towerRoomChoices(run)[0],entered=chooseTowerRoom(run,room.id),battle=createTowerBattle(towerBattleConfig(entered)),friendly=chooseAIPlan(battle,0),enemy=chooseAIPlan(battle,1);
  assert.deepEqual(validatePlan(battle,0,friendly),friendly);assert.deepEqual(validatePlan(battle,1,enemy),enemy);
  const next=resolveRound(battle,[friendly,enemy]);assert.equal(next.round,battle.round+1);assert.equal(next.units.filter(unit=>unit.owner===0).length,2);
 }
});

test('solo picker offers seven compact suggestions and default co-op keeps three with editable pair cards',()=>{
 for(const solo of [false,true]){
  const markup=html(solo),presets=markup.match(/<div class="tp23-presets[^]*?<\/div>/)?.[0];assert.ok(presets);
  assert.equal((presets.match(/<button /g)??[]).length,solo?7:3);assert.equal((presets.match(/aria-pressed="true"/g)??[]).length,1);
  assert.equal((markup.match(/aria-label="Change character [12]:/g)??[]).length,2);
  if(solo){let last=-1;for(const starter of TOWER_SOLO_STARTERS){const next=presets.indexOf(`>${getChampion(starter.heroId).name}</button>`);assert.ok(next>last);last=next;}assert.match(presets,/tp23-solo-presets/);assert.doesNotMatch(presets,/<img|<svg/);}
 }
 const edited=validateTowerStarter('baron');if(edited.members[0].kind==='champion')edited.members[0].build.name='Custom Baron';
 const markup=html(true,edited);assert.match(markup,/Custom Baron/);assert.equal((markup.match(/aria-pressed="true"/g)??[]).length,0);
});
