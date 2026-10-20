import assert from 'node:assert/strict';
import test from 'node:test';
import {existsSync,readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createSimGame,getCell,resolveRound,validatePlan,type SimState,type TeamPlan} from '../lib/tactics-v15.ts';
import {formatTile} from '../lib/board-labels-v9.ts';
import type {ResolutionPhase} from '../lib/feedback-v15.ts';

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
type BoardProps=ComponentProps<typeof import('../app/components/PixelBattlefieldV15.tsx').default>;
type PanelProps=ComponentProps<typeof import('../app/components/ResolutionPanelV15.tsx').default>;
const Board=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV15.tsx',import.meta.url))).default as ComponentType<BoardProps>;
const Panel=loadSource(fileURLToPath(new URL('../app/components/ResolutionPanelV15.tsx',import.meta.url))).default as ComponentType<PanelProps>;
const phases:ResolutionPhase[]=['move','cast','impact','settle'];
const target={q:1,r:0};

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

test('real opposing Water and Fire casts launch together at 2200 ms and arrive together at 4800 ms',()=>{
  const {before,after}=exchange(),html=render(before,after,'cast');
  const projectiles=tags(html,'data-projectile-material');
  assert.equal(projectiles.length,2,'exactly one projectile per resolved cast');
  assert.deepEqual(projectiles.map(tag=>attr(tag,'data-projectile-material')).sort(),['fire','water']);
  for(const projectile of projectiles){
    assert.equal(attr(projectile,'data-projectile-launch'),'2200');
    assert.equal(attr(projectile,'data-projectile-arrival'),'4800');
  }
  assert.equal((html.match(/class="px-v9-flight-head"/g)||[]).length,2);
  assert.equal((html.match(/--px-flight-delay:2200ms;--px-flight-duration:2600ms;offset-path:/g)||[]).length,2);
  for(const spell of ['water_jet','ember'])assert.ok(html.includes(`data-cast-spell="${spell}" data-effect-cell="1,0"`),'both actual spell areas reach their shared target');
});

test('new Steam reveals at impact while health and accessible health descriptions wait for results',()=>{
  const {before,after}=exchange(),old=before.units[1],hurt=after.units[1];
  for(const phase of phases){
    const html=render(before,after,phase),label=tileLabel(html,target);
    assert.ok(html.includes(`data-playback-phase="${phase}"`));
    assert.equal(html.includes('data-surface="steam"'),phase==='impact'||phase==='settle',`${phase}: field art follows impact`);
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
    assert.equal(tags(html,'data-well').length,springs.length);
    assert.ok(springs.every(cell=>tileLabel(html,cell).includes('Flux spring: +1 Flux')));
    const playerText=html.replace(/<style>[\s\S]*?<\/style>/g,'').replace(/<[^>]*>/g,' ')+cells.map(tag=>attr(tag,'aria-label')).join(' ');
    assert.doesNotMatch(playerText,/(?:\bpoints?\b|\bscore\b|well victory)/i,'elimination presentation never describes springs as a score objective');
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
