import assert from 'node:assert/strict';
import test from 'node:test';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType,type ReactNode} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createSimGame,getCell,resolveRound,validatePlan,spellArea,type SimState,type TeamPlan} from '../lib/tactics-v16.ts';
import {getSpell,effectiveSpell} from '../lib/spells-v16.ts';
import {projectedVolley} from '../lib/planned-volley-v16.ts';
import {formatTile} from '../lib/board-labels-v9.ts';
import {PHASE_MS,CAST_ANTICIPATION_MS,PROJECTILE_FLIGHT_MS,projectileMeetingMs,type ResolutionPhase} from '../lib/feedback-v16.ts';
import {planningForecast} from '../lib/planning-forecast-v16.ts';
import {canonicalBuild} from '../lib/character-creation-v17.ts';
import {createTowerBattle,resolveCoopRound} from '../lib/tactics-v22.ts';
import {getCreature} from '../lib/campaign-creatures-v19.ts';

// Execute the shipped TSX and its real dependencies. This checks rendered phase
// snapshots and timing contracts; browser playback verifies actual animation.
const nodeRequire=createRequire(import.meta.url);
const modules=new Map<string,{exports:Record<string,unknown>}>();
function loadSource(filename:string):Record<string,unknown> {
  const cached=modules.get(filename);if(cached)return cached.exports;
  const module={exports:{} as Record<string,unknown>};modules.set(filename,module);
  const javascript=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
  const localRequire=(specifier:string):unknown=>{
    if(specifier.endsWith('.css'))return {};
    if(!specifier.startsWith('.'))return nodeRequire(specifier);
    const target=resolve(dirname(filename),specifier);
    const found=['','.ts','.tsx','.js','.json'].map(suffix=>target+suffix).find(path=>existsSync(path));
    assert.ok(found,`missing renderer dependency ${specifier}`);
    return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
  };
  new Function('require','module','exports','__filename','__dirname',javascript)(localRequire,module,module.exports,filename,dirname(filename));
  return module.exports;
}
type BoardProps=ComponentProps<typeof import('../app/components/PixelBattlefieldV16.tsx').default>;
type PanelProps=ComponentProps<typeof import('../app/components/ResolutionPanelV16.tsx').default>;
const Board=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV16.tsx',import.meta.url))).default as ComponentType<BoardProps>;
const Panel=loadSource(fileURLToPath(new URL('../app/components/ResolutionPanelV16.tsx',import.meta.url))).default as ComponentType<PanelProps>;
const phases:ResolutionPhase[]=['move','cast','impact','settle'];
const target={q:1,r:0};

test('an opened creature readout identifies its actual family instead of its mechanics proxy champion race',()=>{
 const source=loadSource(fileURLToPath(new URL('../app/components/BattleInsightV24.tsx',import.meta.url))),original=source.BattleInsight;
 // Expose only the popover container; the battlefield supplies its actual
 // title, vitals, identity and status content through the production component.
 source.BattleInsight=({title,children}:{title:string;children:ReactNode})=>createElement('aside',{'data-open-insight':title},children);
 try{
  const state=createSimGame(),creature=getCreature('creature-fire-cinder'),unit=state.units[0];
  unit.championId=creature.championId;
  const html=renderToStaticMarkup(createElement(Board,{state,plan:{orders:[]},player:0,selected:null,kind:'move',onCell:()=>{},interactive:false,aimTarget:unit,unitPresentation:{[unit.id]:{name:creature.name,creatureId:creature.id,label:'Your party',color:'#176f76'}}}));
  const readout=html.match(/<aside data-open-insight="Cinder">([\s\S]*?)<\/aside>/)?.[1];
  assert.ok(readout);assert.ok(readout.includes('<p>fox · Your party</p>'));assert.ok(!readout.includes('goblin'));
 }finally{source.BattleInsight=original;}
});

function exchange(){
  const before=createSimGame();
  // A level arena isolates presentation from generated cover; keep real spring
  // positions, character kits, affinity, plan validation and resolver behavior.
  before.cells=before.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
  Object.assign(before.units[0],{q:0,r:0});
  Object.assign(before.units[1],target);
  Object.assign(before.units[3],{q:2,r:0});
  const plans:[TeamPlan,TeamPlan]=[
    {orders:[{unitId:before.units[0].id,move:{q:0,r:1},spellId:'water_jet',cast:target}]},
    {orders:[{unitId:before.units[3].id,spellId:'ember',cast:target}]},
  ];
  validatePlan(before,0,plans[0]);validatePlan(before,1,plans[1]);
  const after=resolveRound(before,plans);
  assert.equal(after.lastResolution.filter(event=>event.kind==='cast').length,2);
  assert.equal(getCell(after,target.q,target.r)!.terrain,'steam');
  assert.ok(after.units[1].hp>0&&after.units[1].hp<before.units[1].hp);
  return {before,after,plans};
}
const render=(before:SimState,after:SimState,phase:ResolutionPhase,plan:TeamPlan={orders:[]})=>renderToStaticMarkup(createElement(Board,{
  state:after,previousState:before,plan,player:0,selected:after.units[0].id,kind:'cast',spellId:'water_jet',
  onCell:()=>{},interactive:true,resolving:true,playback:{active:true,phase,key:1},
  showOrders:true,legalTargets:[target],affectedTargets:[target],aimTarget:target,
}));
const tags=(html:string,attribute:string)=>[...html.matchAll(new RegExp(`<[^>]+\\b${attribute}="[^"]*"[^>]*>`,'g'))].map(match=>match[0]);
const attr=(tag:string,name:string)=>tag.match(new RegExp(`\\b${name}="([^"]*)"`))?.[1];
const tileLabel=(html:string,point:{q:number;r:number})=>{
  const tag=tags(html,'data-tile').find(tag=>attr(tag,'data-tile')===formatTile(point));
  assert.ok(tag,`missing tile ${formatTile(point)}`);return attr(tag,'aria-label')!;
};

test('character speech waits for the results phase and never competes with planning targets',()=>{
 const before=createSimGame(),after=structuredClone(before);
 after.version++;after.round++;after.lastResolution=[{kind:'fizzle',unitId:after.units[0].id,text:'Spell fizzled.'}];
 for(const phase of ['move','cast','impact'] as ResolutionPhase[])assert.equal(tags(render(before,after,phase),'data-character-speech').length,0);
 const result=render(before,after,'settle');
 assert.equal(tags(result,'data-character-speech').length,1,'one safely placed reaction after the exchange');
 assert.ok(result.includes('data-speech-reason="fizzle"'));
 const planning=renderToStaticMarkup(createElement(Board,{state:after,previousState:before,plan:{orders:[]},player:0,selected:after.units[0].id,kind:'cast',onCell:()=>{},interactive:true,aimTarget:target,affectedTargets:[target]}));
 assert.equal(tags(planning,'data-character-speech').length,0,'aiming has priority over speech');
});

test('native cast metadata receives the recorded scroll flag for projectile rendering',()=>{
 const {before,after}=exchange(),cast=after.lastResolution.find(event=>event.kind==='cast')!;
 Object.assign(cast,{scroll:true});
 const seen:{id:string;scroll:boolean|undefined}[]=[];
 const html=renderToStaticMarkup(createElement(Board,{state:after,previousState:before,plan:{orders:[]},player:0,selected:after.units[0].id,kind:'cast',spellId:cast.spellId,onCell:()=>{},interactive:false,resolving:true,playback:{active:true,phase:'cast',key:1},spellRules:{
  getSpell,effectiveSpell,spellArea,projectedVolley,spellForCast:(_state,id,spellId,scroll)=>{seen.push({id,scroll});return {...getSpell(spellId),shape:scroll?'sweep':'hex'}},
 }}));
 assert.ok(seen.some(entry=>entry.id===cast.unitId&&entry.scroll===true));
 assert.ok(html.includes('data-projectile-shape="sweep"'),'recorded scroll uses native printed shape rather than the ordinary affinity-derived default');
});

test('native cast metadata retains optional focus for the selected planning overlay',()=>{
 const state=createSimGame(),seen:(boolean|undefined)[]=[];
 const props:BoardProps={state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'cast',spellId:'water_jet',onCell:()=>{},interactive:true,aimTarget:target,affectedTargets:[target],spellRules:{
  getSpell,effectiveSpell,spellArea,projectedVolley,spellForCast:(_state,_id,spellId,scroll)=>{seen.push(scroll);return {...getSpell(spellId),shape:'burst',radius:2,focus:true}},
 }};
 const focused=renderToStaticMarkup(createElement(Board,props));
 assert.ok(focused.includes('data-focused-area="water_jet"'));
 assert.ok(seen.includes(undefined),'selection uses the native current-selection mode, not a fabricated replay flag');
 const ordinary=renderToStaticMarkup(createElement(Board,{...props,spellRules:{...props.spellRules!,spellForCast:(_state,_id,spellId)=>getSpell(spellId)}}));
 assert.ok(!ordinary.includes('data-focused-area='),'ordinary native spells do not acquire a focus marker');
});

test('real opposing Water and Fire casts share the launch and arrival clock',()=>{
  const {before,after}=exchange(),html=render(before,after,'cast');
  const projectiles=tags(html,'data-projectile-material');
  assert.equal(projectiles.length,2,'exactly one projectile per resolved cast');
  assert.deepEqual(projectiles.map(tag=>attr(tag,'data-projectile-material')).sort(),['fire','water']);
  for(const projectile of projectiles){
    assert.equal(attr(projectile,'data-projectile-launch'),String(PHASE_MS.cast+CAST_ANTICIPATION_MS));
    assert.equal(attr(projectile,'data-projectile-arrival'),String(PHASE_MS.impact));
  }
  assert.equal((html.match(/class="px-v9-flight-head"/g)||[]).length,2);
  assert.equal((html.match(new RegExp(`--px-flight-delay:${PHASE_MS.cast+CAST_ANTICIPATION_MS}ms;--px-flight-duration:${PROJECTILE_FLIGHT_MS}ms;offset-path:`,'g'))||[]).length,2);
  for(const spell of ['water_jet','ember'])assert.ok(html.includes(`data-cast-spell="${spell}" data-effect-cell="1,0"`),'both actual spell areas reach their shared target');
});

test('new Steam reveals at impact while health and accessible health descriptions wait for results',()=>{
  const {before,after}=exchange(),old=before.units[1],hurt=after.units[1];
  for(const phase of phases){
    const html=render(before,after,phase),label=tileLabel(html,target);
    assert.ok(html.includes(`data-playback-phase="${phase}"`));
    assert.equal(html.includes('data-surface="steam"'),phase==='impact'||phase==='settle',`${phase}: field art follows impact`);
    assert.equal(html.includes('data-field-material="steam"'),phase==='impact'||phase==='settle',`${phase}: connected field boundary never leaks the future field`);
    assert.equal(label.includes('Field: Steam'),phase==='impact'||phase==='settle',`${phase}: accessible terrain follows impact`);
    const shown=phase==='settle'?hurt:old;
    assert.ok(label.includes(`${shown.hp} of ${shown.maxHp} health`),`${phase}: tile announces only the health visible in this phase`);
    assert.ok(html.includes(`Wa Bidi · Your company · ${shown.hp}/${shown.maxHp} health`),`${phase}: sprite tooltip agrees with accessible tile`);
    assert.equal(html.includes(`data-health-feedback="${hurt.id}"`),phase==='settle',`${phase}: health result mounts only once results begin`);
    if(phase==='settle'){
      assert.ok(html.includes(`−${old.hp-hurt.hp} HP`));
      assert.match(tags(html,'data-health-feedback')[0],/--px-event-delay:0ms/,'already-timed health feedback must not wait a second time');
    }
  }
});

test('every playback phase suppresses planning clutter and disables all hex orders while springs remain Flux only',()=>{
  const {before,after,plans}=exchange();
  for(const phase of phases){
    const html=render(before,after,phase,plans[0]);
    const cells=tags(html,'data-tile');
    assert.equal(cells.length,after.cells.length);
    assert.ok(cells.every(tag=>attr(tag,'aria-disabled')==='true'),`${phase}: even an interactive parent cannot enable planning targets`);
    for(const clutter of ['px-queued-order','px-aim-reticle','data-selected-landing=','px-planned-fields','Available cast target.','Terrain and planned effects'])assert.ok(!html.includes(clutter),`${phase}: hides ${clutter}`);
    const springs=after.cells.filter(cell=>cell.well);
    assert.ok(springs.length>0);
    assert.equal(tags(html,'data-well').length,0,'decorative Flux labels stay out of playback while the spring art and accessible descriptions remain');
    assert.ok(springs.every(cell=>tileLabel(html,cell).includes('Flux spring: +1 Flux')));
    const playerText=html.replace(/<style>[\s\S]*?<\/style>/g,'').replace(/<[^>]*>/g,' ')+cells.map(tag=>attr(tag,'aria-label')).join(' ');
    assert.doesNotMatch(playerText,/(?:victory points?|\bscore\b|well victory|\b[0-9]+ points?\b)/i,'elimination presentation never describes springs as a score objective');
  }
});

test('the actual six-character resolution panel keeps defeated characters defeated in every later phase',()=>{
  const initial=createSimGame(),fallenId=initial.units[2].id;
  initial.units[2].hp=1;initial.units[2].statuses.burn={turns:2,power:1};
  const before=resolveRound(initial,[{orders:[]},{orders:[]}]);
  assert.equal(before.units[2].hp,0);
  const after=resolveRound(before,[{orders:[]},{orders:[]}]);
  for(const phase of phases){
    const html=renderToStaticMarkup(createElement(Panel,{state:after,previous:before,player:0,phase,names:['Your team','Rival']}));
    assert.equal(tags(html,'data-resolution-unit').length,6);
    const card=html.match(new RegExp(`<li[^>]+data-resolution-unit="${fallenId}"[\\s\\S]*?</li>`))?.[0];
    assert.ok(card);assert.ok(card.includes('>Defeated</span>'),`${phase}: an already defeated character has no invented action`);
    assert.doesNotMatch(html,/Recovering|Returned|Not planned|\bpoints?\b|\bscore\b/i);
    assert.ok(html.includes('aria-label="This exchange"'));
  }
});

test('real intercepted casts stop at their shared midpoint and show no phantom aimed impacts',()=>{
  const before=createSimGame();before.cells=before.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
  Object.assign(before.units[0],{q:-1,r:0});Object.assign(before.units[3],{q:1,r:0});
  const after=resolveRound(before,[{orders:[{unitId:before.units[0].id,spellId:'ember',cast:{q:1,r:0}}]},{orders:[{unitId:before.units[3].id,spellId:'water_jet',cast:{q:-1,r:0}}]}]);
  const html=render(before,after,'cast'),projectiles=tags(html,'data-projectile-material');
  assert.equal(projectiles.length,2);
  for(const projectile of projectiles){assert.equal(attr(projectile,'data-projectile-launch'),String(projectileMeetingMs(0)));assert.equal(attr(projectile,'data-projectile-arrival'),String(projectileMeetingMs(.5)));assert.equal(attr(projectile,'data-projectile-fraction'),'0.5');}
  assert.equal((html.match(new RegExp(`--px-flight-duration:${PROJECTILE_FLIGHT_MS*.5}ms`,'g'))||[]).length,6,'head and two trails use the consumed half flight');
  assert.ok(html.includes('data-clash-meeting="0,0"'));
  const clash=after.lastResolution.find(event=>event.kind==='clash')!;
  assert.ok(html.includes(`data-clash-ingredients="${clash.elements!.join('+')}"`),'the meeting card names the actual interacting ingredients');
  assert.ok(html.includes('data-impact-outline="steam" data-impact-area="7"'),'one outside contour describes the real seven-cell collision field');
  const clashTag=tags(html,'data-clash-name')[0];
  assert.equal(attr(clashTag,'data-clash-name'),'Steam');
  assert.equal(attr(clashTag,'data-clash-at'),String(projectileMeetingMs(.5)));
  assert.equal(attr(clashTag,'data-clash-revealed'),'false');
  assert.equal(tags(html,'data-clash-field').length,7);
  assert.equal(tags(html,'data-cast-spell').length,0,'intercepted original spell effects do not appear at their intended aims');
  assert.ok(render(before,after,'impact').includes('data-clash-revealed="true"'),'reduced motion sees the meeting only after its flight time');
});

test('large areas use one prominent material impact and quieter surrounding waves',()=>{
  const before=createSimGame();before.cells=before.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
  Object.assign(before.units[0],{q:0,r:0});
  const after=resolveRound(before,[{orders:[{unitId:before.units[0].id,spellId:'cleansing_tide',cast:{q:1,r:0}}]},{orders:[]}]);
  const html=render(before,after,'impact');
  assert.equal(tags(html,'data-cast-spell').length,7);
  assert.equal(tags(html,'data-impact-material').length,1);
  assert.equal(tags(html,'data-area-wake').length,5,'secondary accents stay bounded without removing any effect hex');
});

test('planning distinguishes reachable region, affected footprint, and the actual post-move casting origin',()=>{
  const state=createSimGame(),unit=state.units[0],landing={q:unit.q+1,r:unit.r};
  const html=renderToStaticMarkup(createElement(Board,{state,plan:{orders:[{unitId:unit.id,move:landing}]},player:0,selected:unit.id,kind:'cast',spellId:'water_jet',onCell:()=>{},interactive:true,legalTargets:[landing,{q:landing.q+1,r:landing.r}],affectedTargets:[landing],aimTarget:landing}));
  assert.equal(tags(html,'data-range-boundary').length,1);
  assert.equal(attr(tags(html,'data-range-boundary')[0],'data-range-boundary'),'cast');
  assert.equal(attr(tags(html,'data-effect-boundary')[0],'data-effect-boundary'),'1');
  assert.equal(attr(tags(html,'data-cast-origin')[0],'data-cast-origin'),formatTile(landing));
  assert.ok(html.includes('after moving'));
});

test('known allied collisions preview their meeting footprint instead of the lost target',()=>{
  const state=createSimGame();state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
  const water=state.units[0],fire=state.units[1];Object.assign(water,{q:-2,r:0});Object.assign(fire,{q:2,r:0});
  const plan:TeamPlan={orders:[{unitId:water.id,spellId:'water_jet',cast:{q:2,r:0}},{unitId:fire.id,spellId:'ember',cast:{q:-2,r:0}}]};
  const forecast=planningForecast(state,0,plan,water.id,'water_jet',{q:2,r:0});assert.ok(forecast);assert.equal(forecast.clashes.length,1);
  const html=renderToStaticMarkup(createElement(Board,{state,plan,player:0,selected:water.id,kind:'cast',spellId:'water_jet',onCell:()=>{},interactive:true,legalTargets:[{q:2,r:0}],affectedTargets:[{q:2,r:0}],aimTarget:{q:2,r:0},forecast}));
  assert.equal(attr(tags(html,'data-planned-clash')[0],'data-planned-clash'),'Steam');
  assert.equal(attr(tags(html,'data-effect-boundary')[0],'data-effect-boundary'),'7');
  assert.equal(tags(html,'data-forecast-tile').length,7);
  assert.ok(!tags(html,'data-forecast-tile').some(tag=>attr(tag,'data-forecast-tile')===formatTile({q:2,r:0})),'the old aim is no longer striped as affected');
});

test('both queued flight paths start at actual origins when two allied landings are blocked',()=>{
  const state=createSimGame();state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
  const water=state.units[0],fire=state.units[1];Object.assign(water,{q:-2,r:0});Object.assign(fire,{q:2,r:0});
  const plan:TeamPlan={orders:[{unitId:water.id,move:{q:0,r:0},spellId:'water_jet',cast:{q:2,r:0}},{unitId:fire.id,move:{q:0,r:0},spellId:'ember',cast:{q:-2,r:0}}]};
  const forecast=planningForecast(state,0,plan,water.id)!;
  assert.equal(forecast.clashes.length,1);
  const html=renderToStaticMarkup(createElement(Board,{state,plan,player:0,selected:water.id,kind:'cast',spellId:'water_jet',onCell:()=>{},interactive:true,forecast}));
  const flights=tags(html,'data-queued-cast-unit');assert.equal(flights.length,2);
  assert.equal(attr(flights.find(tag=>attr(tag,'data-queued-cast-unit')===water.id)!,'data-queued-cast-origin'),'-2,0');
  assert.equal(attr(flights.find(tag=>attr(tag,'data-queued-cast-unit')===fire.id)!,'data-queued-cast-origin'),'2,0');
  assert.ok(flights.every(tag=>attr(tag,'data-queued-cast-origin')!=='0,0'),'neither cast can start at the blocked shared landing');
  assert.equal(attr(tags(html,'data-planned-clash')[0],'data-planned-clash'),'Steam');
});

test('shared allied orders show partner routes and definite collisions without changing local control',()=>{
 const state=createSimGame();state.cells=state.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
 const own=state.units[0],partner=state.units[1];Object.assign(own,{q:-2,r:0});Object.assign(partner,{q:2,r:0});
 const plan:TeamPlan={orders:[{unitId:own.id,move:{q:0,r:0},spellId:'water_jet',cast:{q:2,r:0}},{unitId:partner.id,move:{q:0,r:0},spellId:'ember',cast:{q:-2,r:0}}]};
 const props:BoardProps={state,plan,player:0,selected:own.id,kind:'move',onCell:()=>{},interactive:true,controllableUnitIds:[own.id],legalTargets:[{q:0,r:0}]};
 const privateView=renderToStaticMarkup(createElement(Board,props));
 assert.ok(!tags(privateView,'data-order-unit').some(tag=>attr(tag,'data-order-unit')===partner.id),'private modes do not publish partner drafts');
 const shared=renderToStaticMarkup(createElement(Board,{...props,sharedAlliedOrders:true})),orders=tags(shared,'data-order-unit');
 assert.equal(orders.length,2);
 assert.equal(attr(orders.find(tag=>attr(tag,'data-order-unit')===own.id)!,'data-order-control'),'local');
 assert.equal(attr(orders.find(tag=>attr(tag,'data-order-unit')===partner.id)!,'data-order-control'),'ally','shared orders confer visibility, not local control');
 assert.match(tags(shared,'data-selected-landing')[0],/is-blocked/,'known shared destination is a definite bounce');
 const flights=tags(shared,'data-queued-cast-unit');assert.equal(flights.length,2);
 assert.equal(attr(flights.find(tag=>attr(tag,'data-queued-cast-unit')===own.id)!,'data-queued-cast-origin'),'-2,0');
 assert.equal(attr(flights.find(tag=>attr(tag,'data-queued-cast-unit')===partner.id)!,'data-queued-cast-origin'),'2,0');
 assert.doesNotMatch(shared,/class="px-order-number"[^>]*>0</,'partner numbering matches the party instead of becoming zero');
});

test('an actual consensual Link is attributed to its casters while the target-only glyph stays on its victim',()=>{
 const actor=(championId:string,id:string)=>{const build=canonicalBuild(championId);return {id,championId,displayName:build.name,affinities:build.affinities,loadout:build.loadout,hp:8}};
 const before=createTowerBattle({id:'link-feedback',mapId:'LINK-FEEDBACK',mode:'coop',controllers:{water:0,fire:1},learnedSpells:[],allies:[actor('oh_tipi','water'),actor('steezo','fire')],enemies:[actor('treevor_mason','victim')]});
 before.cells=before.cells.map(({q,r,well})=>({q,r,well,terrain:'plain',biome:'plain',height:0}));
 Object.assign(before.units[0],{q:-2,r:0});Object.assign(before.units[1],{q:0,r:-2});Object.assign(before.units[2],{q:0,r:0});
 const after=resolveCoopRound(before,[{orders:[{unitId:'water',spellId:'water_jet',cast:{q:0,r:0}}],link:true},{orders:[{unitId:'fire',spellId:'ember',cast:{q:0,r:0}}],link:true}],{orders:[]});
 const link=after.lastResolution.find(event=>event.cause==='link');assert.ok(link,'fixture uses the actual co-op resolver');assert.equal(link.unitId,'victim');
 const Report=loadSource(fileURLToPath(new URL('../app/components/CampaignReviewV20.tsx',import.meta.url))).default as ComponentType<Record<string,unknown>>;
 const report=renderToStaticMarkup(createElement(Report,{previous:{...before,rulesVersion:20},state:{...after,rulesVersion:20}}));
 assert.ok(report.includes(`Your party · ${link.text}`));assert.ok(!report.includes(`Enemy · ${link.text}`));
 const view=render({...before,rulesVersion:16} as unknown as SimState,{...after,rulesVersion:16} as unknown as SimState,'impact');
 assert.equal(tags(view,'data-team-link').length,1);assert.equal(attr(tags(view,'data-link-target')[0],'data-link-target'),'victim');
 assert.ok(!view.includes('data-impact-outline="link"'),'Link does not invent an area or terrain field');
 assert.equal(after.lastResolution.find(event=>event.cause==='link')?.unitId,'victim','attribution must not mutate the authoritative event');
});
