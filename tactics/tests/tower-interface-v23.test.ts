import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createTowerRun,validateTowerStarter,towerChampion,towerCreature,type TowerStart,type TowerMemberInput} from '../lib/tower-v23.ts';
import {getCreature,CREATURE_PERKS} from '../lib/campaign-creatures-v20.ts';
import {getSpell,getSignature} from '../lib/spells-v20.ts';
import type {TowerPlayerSummary} from '../lib/tower-rooms-v23.ts';
import {towerRewardPreview} from '../lib/tower-reward-preview-v42.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(specifier.endsWith('TowerBattleV23'))return {__esModule:true,default:()=>null};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}
const picker=loadSource(fileURLToPath(new URL('../app/components/TowerTeamPickerV23.tsx',import.meta.url))),coop=loadSource(fileURLToPath(new URL('../app/components/CoopTowerV23.tsx',import.meta.url))),noop=()=>{};
const Picker=picker.default as ComponentType<{value:TowerStart;onChange:(next:TowerStart)=>void}>,Member=picker.TowerTeamMemberCard as ComponentType<{member:TowerMemberInput;index:number}>,Builder=loadSource(fileURLToPath(new URL('../app/components/TowerCharacterBuilderV23.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
const Strip=coop.TowerPlayerStrip as ComponentType<{players:(TowerPlayerSummary|null)[];yourSeat:number;watchSeat:number|null;onWatch:(seat:number|null)=>void}>,Wait=coop.TowerFloorWait as ComponentType<{players:(TowerPlayerSummary|null)[];waitingFor:number[];sharedFloor:number;onWatch:(seat:number)=>void}>;
const html=(element:ReturnType<typeof createElement>)=>renderToStaticMarkup(element).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
function champion(id:string):TowerMemberInput{const actor=towerChampion(id,'preview');return {kind:'champion',build:{championId:id,name:actor.displayName!,affinities:actor.affinities,loadout:actor.loadout}}}
function player(seat:number,phase:TowerPlayerSummary['phase']='battle'):TowerPlayerSummary{const run=createTowerRun('SQUADS',seat%2?'dusk':'steam');return {seat,name:`Player ${seat+1}`,start:run.starts[0],ready:true,alive:phase!=='lost',floor:3,phase,party:run.party,currentRoomName:'Boiler room',round:2}}

test('a suggested team is visibly selected and both actual movesets are shown before starting',()=>{
 const start=validateTowerStarter('steam'),markup=html(createElement(Picker,{value:start,onChange:noop}));
 assert.equal((markup.match(/aria-pressed="true"/g)??[]).length,1);
 assert.equal((markup.match(/aria-label="Change character [12]:/g)??[]).length,2);
 for(const member of start.members){const ids=member.kind==='champion'?member.build.loadout:getCreature(member.creatureId).loadout;for(const id of ids)assert.ok(markup.includes(getSpell(id).name));}
 assert.match(markup,/Choose any two different characters/);
});

test('two freely configured champions retain their own builds, signatures and four-spell previews',()=>{
 const members:[TowerMemberInput,TowerMemberInput]=[champion('s_wayne'),champion('oh_tipi')],start=validateTowerStarter({starterId:'steam',members}),run=createTowerRun('TWO-HEROES',start),markup=html(createElement(Picker,{value:start,onChange:noop}));
 assert.equal(run.party.length,2);assert.ok(run.party.every(actor=>!actor.creatureId));
 assert.equal((markup.match(/aria-pressed="true"/g)??[]).length,0);
 for(const member of members){if(member.kind!=='champion')continue;assert.ok(markup.includes(member.build.name));assert.ok(markup.includes(getSignature(member.build.championId).name));for(const id of member.build.loadout)assert.ok(markup.includes(getSpell(id).name));}
});

test('two starting creatures display real fixed spells, health and party bonds without a forced champion',()=>{
 const members:[TowerMemberInput,TowerMemberInput]=[{kind:'creature',creatureId:'creature-fire-cinder'},{kind:'creature',creatureId:'creature-water-puddle'}],start=validateTowerStarter({starterId:'steam',members});assert.ok(createTowerRun('TWO-CREATURES',start).party.every(actor=>!!actor.creatureId));
 for(const [index,member] of members.entries()){if(member.kind!=='creature')continue;const creature=getCreature(member.creatureId),markup=html(createElement(Member,{member,index}));assert.ok(markup.includes(`${creature.maxHp} HP`));for(const id of creature.loadout)assert.ok(markup.includes(getSpell(id).name));const perk=CREATURE_PERKS.find(perk=>perk.id===creature.perkId)!;assert.ok(markup.includes(perk.name));assert.ok(markup.includes(perk.description));assert.doesNotMatch(markup,/tp23-signature/);}
});

test('character builder prevents selecting the other squad member without constraining the roster',()=>{
 const member=champion('oh_tipi');assert.equal(member.kind,'champion');if(member.kind!=='champion')return;
 const markup=html(createElement(Builder,{initial:member.build,excludedChampionIds:['oh_tipi'],onSave:noop,onCancel:noop}));
 assert.match(markup,/<option value="oh_tipi" disabled=""[^>]*>/);assert.match(markup,/Choose a different character from your teammate/);assert.match(markup,/<button[^>]*disabled=""[^>]*>Use character/);assert.match(markup,/<option value="s_wayne"[^>]*>/);
});

test('six-player switcher identifies watched and own squads and distinguishes defeat from progress',()=>{
 const players=Array.from({length:6},(_,index)=>player(index,index===5?'lost':index===2?'barrier':'battle')),markup=html(createElement(Strip,{players,yourSeat:0,watchSeat:3,onWatch:noop}));
 assert.equal((markup.match(/<button /g)??[]).length,6);assert.equal((markup.match(/aria-pressed="true"/g)??[]).length,1);
 assert.match(markup,/aria-pressed="true" aria-label="Watch Player 4, Round 2"/);assert.match(markup,/Your squad, Round 2/);assert.match(markup,/Watch Player 6, Defeated/);assert.match(markup,/F2 complete/);
});

test('checkpoint waiting names only unfinished squads and explains the shared spell reward',()=>{
 const players=[player(0,'barrier'),player(1,'battle'),player(2,'reward'),player(3,'lost')],markup=html(createElement(Wait,{players,waitingFor:[1,2],sharedFloor:3,onWatch:noop}));
 assert.match(markup,/Floor 3 is still in progress/);assert.match(markup,/Watch Player 2/);assert.match(markup,/Watch Player 3/);assert.doesNotMatch(markup,/Watch Player 4/);assert.match(markup,/Spells discovered on this floor are shared at the stairs/);
});

test('a chosen room identifies the remaining players and can be withdrawn before the group enters',()=>{
 const Gathering=coop.TowerGathering as ComponentType<Record<string,unknown>>,players=[player(0,'route'),player(1,'route'),player(2,'route')];
 const markup=html(createElement(Gathering,{gathering:{choiceId:'floor-3-1',choices:[{seat:0,name:'Player 1',choiceId:'floor-3-1'}],waitingFor:[1,2]},players,busy:false,onWithdraw:noop}));
 assert.match(markup,/Room selected/);assert.match(markup,/Waiting for Player 2, Player 3/);assert.match(markup,/Change room/);assert.doesNotMatch(markup,/Watch Player/);
});

test('the hex route shows actual connected forks and only one detailed room at a time',()=>{
 const Route=loadSource(fileURLToPath(new URL('../app/components/TowerRouteMap.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
 const run=createTowerRun('ROUTE-UI','steam'),markup=html(createElement(Route,{run,onChoose:noop,onScout:noop,roomPlayers:{'floor-1-0':['You','Moss']}}));
 assert.match(markup,/Tower route map/);assert.equal((markup.match(/class="trm-node"/g)??[]).length,25);
 assert.equal((markup.match(/data-current="true"/g)??[]).length,3);
 assert.equal((markup.match(/class="trp43"/g)??[]).length,1);
 assert.match(markup,/You · Moss/);assert.match(markup,/Together/);assert.match(markup,/preserveAspectRatio="none"/);
});

test('reward cards expose exact training and recovery consequences before the irreversible choice',()=>{
 const Rewards=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url))).TowerRewardChoices as ComponentType<Record<string,unknown>>;
 const run=createTowerRun('REWARD-DECISION','steam');run.party[0].affinities={water:2,air:2,fire:1};run.party[0].hp=2;run.party[1].hp=3;
 const rewards=[{id:'train',kind:'train',name:'Water practice',description:'Generic scaling prose',actorId:run.party[0].id,element:'water',amount:1},{id:'heal',kind:'heal',name:'Rest',description:'Generic recovery prose',amount:3}];
 const markup=html(createElement(Rewards,{run,rewards,onChoose:noop}));
 assert.match(markup,/aria-label="Affinity result"/);assert.match(markup,/Water 2 → 3/);assert.match(markup,/Inner damage <b>2 → 3/);assert.match(markup,/Inner healing <b>2 → 3/);
 assert.match(markup,/Ready now/);assert.ok(markup.includes(getSignature(run.party[0].championId).name));
 assert.match(markup,/\+4 HP for the party/);assert.match(markup,/2 recovery unused at full health/);
 assert.doesNotMatch(markup,/Generic scaling prose|Generic recovery prose/);
});

test('spell reward overview lists every eligible champion and does not imply creatures can re-equip',()=>{
 const Consequences=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url))).TowerRewardConsequences as ComponentType<Record<string,unknown>>;
 const run=createTowerRun('RECIPIENTS','steam'),preview=towerRewardPreview(run,{id:'spell',kind:'spell',name:'Water Jet',description:'',spellId:'water_jet'});
 const markup=html(createElement(Consequences,{preview}));
 assert.match(markup,/Who can use it/);assert.ok(markup.includes(run.party[0].displayName!));assert.match(markup,/Ready to equip/);
 assert.ok(!markup.includes(run.party[1].displayName!));
});

test('paused Tower spell dialogs preserve a saved battle profile and new rooms show focused areas',()=>{
 const source=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url))),Loadout=source.TowerLoadout as ComponentType<Record<string,unknown>>,Inspection=source.TowerEnemyInspection as ComponentType<Record<string,unknown>>;
 const run=createTowerRun('SAVED-PROFILE','steam'),actor=run.party[0];run.phase='battle';
 const legacy=html(createElement(Loadout,{run,actor,onChange:noop,initialSpellId:'water_jet',spellModel:null}));
 const focused=html(createElement(Loadout,{run,actor,onChange:noop,initialSpellId:'water_jet',spellModel:'focused'}));
 assert.doesNotMatch(legacy,/Centre crit|Radius 2/);assert.match(focused,/Centre crit/);assert.match(focused,/Radius 2/);
 const oldEnemy=html(createElement(Inspection,{actor,spellModel:null})),newEnemy=html(createElement(Inspection,{actor}));
 assert.doesNotMatch(oldEnemy,/Centre crit/);assert.match(newEnemy,/Centre crit/);
});
test('first-climb help is optional and contains the actual simultaneous and carry-over decisions',()=>{
 const Intro=loadSource(fileURLToPath(new URL('../app/components/TowerFirstClimbV44.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>,markup=html(createElement(Intro,{}));
 assert.match(markup,/<details class="t44-first-climb"><summary>/);assert.doesNotMatch(markup,/<details[^>]* open/);
 assert.equal((markup.match(/<li>/g)??[]).length,3);assert.match(markup,/landing, then a spell/);assert.match(markup,/original hits are canceled/);assert.match(markup,/Health carries upstairs/);
});
test('recovery displays the exact server expiry and distinguishes action renewal, seat recovery and permanent retirement',()=>{
 const Recovery=loadSource(fileURLToPath(new URL('../app/components/TowerRecoveryV44.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>,expiresAt=1800000000000,markup=html(createElement(Recovery,{expiresAt}));
 assert.ok(markup.includes(`dateTime="${new Date(expiresAt).toISOString()}"`));assert.match(markup,/successful action renews/);assert.match(markup,/Watching and reconnecting do not renew/);
 assert.match(markup,/same browser or your exported seat key/);assert.match(markup,/Retiring leaves this run permanently/);assert.match(markup,/href="\/saves"/);
 const finished=html(createElement(Recovery,{expiresAt,finished:true}));assert.match(finished,/completed climb remains available/);assert.doesNotMatch(finished,/action renews/);
});
test('recruit decisions expose legal replacement differences and potential nearby bonds before selection',()=>{
 const Rewards=loadSource(fileURLToPath(new URL('../app/components/TowerGameV23.tsx',import.meta.url))).TowerRewardChoices as ComponentType<Record<string,unknown>>,run=createTowerRun('RECRUIT44');run.party.push(towerCreature('creature-water-puddle','extra'));
 const actor=towerCreature('creature-steam','candidate'),markup=html(createElement(Rewards,{run,rewards:[{id:'recruit:steam',kind:'recruit',name:actor.displayName,description:'',actor}],onChoose:noop}));
 assert.match(markup,/aria-label="Recruit comparison"/);assert.match(markup,/Replace /);assert.match(markup,/maximum HP/);assert.doesNotMatch(markup,/Replace Oh Tipi/);
});
