import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {effectiveSpell,ALL_SPELLS,type Spell} from '../lib/spells-v20.ts';
import {spellEffectLabel} from '../lib/battle-guidance-v16.ts';

const nodeRequire=createRequire(import.meta.url),modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown>{
 const cached=modules.get(filename);if(cached)return cached.exports;
 const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
 const js=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 const local=(specifier:string):unknown=>{if(specifier.endsWith('.css'))return {};if(!specifier.startsWith('.'))return nodeRequire(specifier);const path=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(ext=>path+ext).find(existsSync);assert.ok(found);return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found)};
 new Function('require','module','exports',js)(local,module,module.exports);return module.exports;
}

const components=loadSource(fileURLToPath(new URL('../app/components/BattleCommandV41.tsx',import.meta.url)));
const Command=components.default as (props:any)=>any,Impact=components.TargetReadout as ComponentType<any>,Header=components.BattlePhaseHeader as ComponentType<any>;
const helpers=loadSource(fileURLToPath(new URL('../lib/battle-command-v41.ts',import.meta.url))) as {castAfterMove:(preferred:string|undefined,choices:{id:string;available:boolean}[],guard?:boolean)=>string|null;orderReadout:(order:any,name:(id:string)=>string,tile:(point:any)=>string)=>{movement:string;action:string;queued:boolean}};
const html=(element:ReturnType<typeof createElement>)=>renderToStaticMarkup(element).replaceAll('&#x27;',"'").replaceAll('&amp;','&');
const noop=()=>{},water=effectiveSpell('oh_tipi','water_jet',{water:3}),fire=effectiveSpell('oh_tipi',ALL_SPELLS.find(spell=>spell.element==='fire'&&!spell.signatureChampionId)!.id,{fire:3});
const defaults={name:'Oh Tipi',identity:'Seakin',portrait:createElement('span',null,'portrait'),unit:{hp:14,maxHp:18,flux:4,maxFlux:7,statuses:{},affinities:{water:3,fire:2}},spells:[{spell:water,cost:2,available:true},{spell:fire,cost:8,available:false,reason:'Need 8 Flux · have 4'}],selectedSpellId:water.id,kind:'cast',movement:4,disabled:false,formatPoint:(point:{q:number;r:number})=>point.q+','+point.r,spellName:(id:string)=>id===water.id?water.name:fire.name,onInspect:noop,onMove:noop,onGuard:noop,onSpell:noop,onCancelMove:noop,onClear:noop,onNext:noop,onUndo:noop,onRedo:noop,canUndo:false,canRedo:false,canNext:true,onCommit:noop,commitLabel:'End turn',commitNote:'1 auto Guard'};
function nodes(node:any,predicate:(node:any)=>boolean):any[]{if(node===null||node===undefined||typeof node!=='object')return [];if(Array.isArray(node))return node.flatMap(child=>nodes(child,predicate));return [...(predicate(node)?[node]:[]),...nodes(node.props?.children,predicate)];}

test('landing follows an available spell without discarding a queued Guard',()=>{
 const choices=[{id:'water',available:false},{id:'fire',available:true},{id:'air',available:true}];
 assert.equal(helpers.castAfterMove('water',choices),'fire');
 assert.equal(helpers.castAfterMove('air',choices),'air');
 assert.equal(helpers.castAfterMove(undefined,choices),'fire');
 assert.equal(helpers.castAfterMove('air',choices,true),null);
 assert.equal(helpers.castAfterMove('water',[{id:'water',available:false}]),null);
});

test('order readout names the actual queued cast, movement and default Guard',()=>{
 const order={move:{q:2,r:3},cast:{q:4,r:5},spellId:water.id};
 assert.deepEqual(helpers.orderReadout(order,defaults.spellName,defaults.formatPoint),{movement:'Move to 2,3',action:water.name+' → 4,5',queued:true});
 assert.equal(helpers.orderReadout(undefined,defaults.spellName,defaults.formatPoint).action,'Guard unless a spell is chosen');
 assert.equal(helpers.orderReadout({guard:true},defaults.spellName,defaults.formatPoint).action,'Guard');
});

test('spell decisions include consequences and local unavailable reasons before the map is tapped',()=>{
 const markup=html(createElement(Command,{...defaults,selectedSpellId:fire.id}));
 assert.ok(markup.includes('Need 8 Flux · have 4'));assert.ok(markup.includes(spellEffectLabel(water)));assert.ok(markup.includes(water.name));
 assert.ok(markup.includes('2 Flux'));assert.ok(markup.includes(water.range+' reach'));
 assert.ok(markup.includes('Inspect Oh Tipi'));assert.ok(markup.includes('Element affinities'));
});

test('only meaningful cancellation controls exist, and they invoke the intended handler',()=>{
 let clear=0,cancel=0,cast='';
 const empty=Command({...defaults,onClear:()=>clear++}),planned=Command({...defaults,order:{move:{q:2,r:3},cast:{q:4,r:5},spellId:water.id},onClear:()=>clear++,onCancelMove:()=>cancel++,onSpell:(id:string)=>cast=id});
 assert.equal(nodes(empty,node=>node.type==='button'&&node.props.children==='Clear order').length,0);
 for(const [label,key] of [['Clear order','clear'],['Cancel move','cancel']] as const){const button=nodes(planned,node=>node.type==='button'&&node.props.children===label)[0];assert.ok(button);button.props.onClick();}
 assert.equal(clear,1);assert.equal(cancel,1);
 const unavailable=nodes(planned,node=>node.type==='button'&&node.props['aria-label']?.includes('Need 8 Flux'))[0];
 assert.equal(unavailable.props.disabled,false);unavailable.props.onClick();assert.equal(cast,fire.id);
});

test('locked online orders cannot be changed through the shared action tray',()=>{
 const tree=Command({...defaults,disabled:true,locked:true,order:{guard:true}}),buttons=nodes(tree,node=>node.type==='button');
 assert.ok(buttons.length>6);for(const button of buttons.filter(node=>node.props['aria-label']!=='Inspect Oh Tipi'))assert.equal(button.props.disabled,true);
 assert.ok(html(tree).includes('Orders locked · waiting for players'));
});

test('target preview labels conditional damage rather than promising final health',()=>{
 const markup=html(createElement(Impact,{preview:{targets:[{id:'enemy',name:'Baron',ally:false,damage:{min:2,max:4},healing:0,statuses:['Wet']},{id:'ally',name:'Tipi',ally:true,damage:{min:0,max:0},healing:2,statuses:[]}],allyCount:1,enemyCount:1,cancelled:true,collisionName:'Steam',conditional:true,blocked:false}}));
 assert.ok(markup.includes('Known volley · if targets stay'));assert.ok(markup.includes('2–4'));assert.ok(markup.includes('spell dmg'));assert.ok(markup.includes('Steam'));assert.ok(markup.includes('Tipi · ally'));assert.ok(markup.includes('+2'));assert.ok(markup.includes('recovery'));assert.ok(markup.includes('Wet'));assert.doesNotMatch(markup,/remaining HP|guaranteed/);
 assert.match(markup,/<details class="bc44-preview-assumptions"><summary[^>]*>Known volley · if targets stay<\/summary>/);
 assert.match(markup,/Uses your current orders and shared allied drafts\. Enemy movement and spells can change the result\./);
 assert.match(markup,/Recovery is before the health cap/);
});

test('the active resolution phase is explicit with one round heading and ready count only during planning',()=>{
 const props={round:3,context:'Steam Gardens',planned:1,total:2,enemiesOpen:false,onToggleEnemies:noop};
 const planning=html(createElement(Header,{...props,phase:'planning'})),casting=html(createElement(Header,{...props,phase:'cast'}));
 assert.equal((casting.match(/Round 3/g)??[]).length,1);assert.equal((casting.match(/aria-current="step"/g)??[]).length,1);
 assert.match(casting,/<li aria-current="step"><span aria-hidden="true">3<\/span>Cast/);
 assert.ok(planning.includes('1/2 ready'));assert.ok(!casting.includes('1/2 ready'));
});

test('Rooted fighters receive a usable action choice instead of an impossible movement instruction',()=>{
 const markup=html(createElement(Command,{...defaults,kind:'move',movement:0,unit:{...defaults.unit,statuses:{rooted:{turns:1,power:1}}}}));
 assert.ok(markup.includes('Cannot move this round'));assert.ok(markup.includes('Choose a spell or Guard.'));
 assert.ok(!markup.includes('Choose a teal landing'));assert.ok(!markup.includes('Choose a landing'));
 assert.ok(markup.includes('aria-label="Spells"'));
});

test('force previews show readable landing and alternative enemy Guard cases without promising survival',()=>{
 const outcome={landing:{q:3,r:2},path:[{q:3,r:2}],impact:true,blockedBy:[],environmentalDamage:1,statuses:['Concussed'],cleansed:false,terrainName:'Ground'};
 const markup=html(createElement(Impact,{formatPoint:(point:{q:number;r:number})=>point.q===3?'F4':'E4',preview:{targets:[{id:'enemy',name:'Baron',ally:false,damage:{min:1,max:2},healing:0,statuses:[],displacement:{anchored:false,withoutGuard:outcome,withGuard:{...outcome,landing:{q:2,r:2},path:[],impact:false,environmentalDamage:0,statuses:[]}}}],allyCount:0,enemyCount:1,cancelled:false,conditional:true,blocked:false}}));
 assert.match(markup,/If still standing/);assert.match(markup,/Enemies act/);assert.match(markup,/Enemies Guard/);
 assert.match(markup,/To F4/);assert.match(markup,/wall impact/);assert.match(markup,/1 environment dmg/);assert.match(markup,/Concussed/);assert.match(markup,/Holds position/);
 assert.doesNotMatch(markup,/remaining HP|guaranteed/);
});

test('phone action preview shows actual target consequence and a cancelled projectile does not claim its old friendly fire',()=>{
 const preview={targets:[{id:'enemy',name:'Baron',ally:false,damage:{min:1,max:3},healing:0,statuses:['Wet']}],allyCount:0,enemyCount:1,cancelled:false,conditional:true,blocked:false};
 const tree=Command({...defaults,impact:preview,aim:{q:1,r:1}}),compact=nodes(tree,node=>node.props?.className==='bc41-mobile-preview')[0];
 assert.ok(html(compact).includes('Baron · 1–3 spell dmg · Wet'));
 const clash=html(createElement(Command,{...defaults,impact:{...preview,targets:[],cancelled:true,collisionName:'Steam'},friendlyNames:['Tipi']}));
 assert.match(clash,/Steam · projectiles meet/);assert.doesNotMatch(clash,/Friendly fire · Tipi/);
});

test('new combat profiles expose exact centre, inner and rim strength while saved legacy profiles stay precise',()=>{
 const focused=html(createElement(Command,{...defaults,spellModel:'focused'})),legacy=html(createElement(Command,defaults));
 assert.match(focused,/Radius 2 · centre crit/);assert.match(focused,/Centre crit/);assert.match(focused,/Inner ring/);assert.match(focused,/Rim/);
 assert.match(focused,/Centre 4 · inner 3 · rim 1 damage/);
 assert.match(focused,/Radius 2/);assert.doesNotMatch(focused,/One precise hex/);
 assert.doesNotMatch(legacy,/centre crit|19-hex burst/);
});

test('a capped pure control effect labels the centre without promising a stronger critical hit',()=>{
 const rootSpell:Spell={...water,damage:0,heal:0,harmful:[{id:'rooted',turns:1}],friendly:undefined};
 const markup=html(createElement(Command,{...defaults,spells:[{spell:rootSpell,cost:rootSpell.cost,available:true}],spellModel:'focused'}));
 assert.match(markup,/>Centre<\/strong>/);assert.match(markup,/Rooted 1r/);
 assert.doesNotMatch(markup,/Centre crit|centre crit/);
});
