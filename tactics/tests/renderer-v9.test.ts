import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync,existsSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createElement,type ComponentProps,type ComponentType} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import ts from 'typescript';
import {createSimGame,legalCasts,resolveRound,spellArea,movementPath,getCell,isIce,isFlooded,type SimState} from '../lib/tactics-v9.ts';

/** Real TSX and rules, compiled in memory; CSS/browser timing is verified separately. */
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
    if(!found)throw new Error(`Cannot resolve renderer dependency ${specifier}`);
    return /\.tsx?$/.test(found)?loadSource(found):nodeRequire(found);
  };
  new Function('require','module','exports','__filename','__dirname',javascript)(localRequire,module,module.exports,filename,dirname(filename));
  return module.exports;
}
type BoardProps=ComponentProps<typeof import('../app/components/PixelBattlefieldV9.tsx').default>;
const Battlefield=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV9.tsx',import.meta.url))).default as ComponentType<BoardProps>;
const materialComponents=loadSource(fileURLToPath(new URL('../app/components/ElementEffectsV9.tsx',import.meta.url)));
type SurfaceProps=ComponentProps<typeof import('../app/components/ElementEffectsV9.tsx').ElementSurface>;
type ProjectileProps=ComponentProps<typeof import('../app/components/ElementEffectsV9.tsx').ElementProjectile>;
const Surface=materialComponents.ElementSurface as ComponentType<SurfaceProps>;
const Projectile=materialComponents.ElementProjectile as ComponentType<ProjectileProps>;
const render=(state:SimState,overrides:Partial<BoardProps>={})=>renderToStaticMarkup(createElement(Battlefield,{state,plan:{orders:[]},player:0,selected:state.units[0].id,kind:'move',onCell:()=>{},interactive:true,...overrides}));
const impactCells=(html:string,spellId:string)=>[...html.matchAll(new RegExp(`data-cast-spell="${spellId}" data-effect-cell="([^"]+)"`,'g'))].map(match=>match[1]).sort();
const arena=()=>{
  const state=createSimGame();
  state.cells.forEach(cell=>Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false}));
  Object.assign(state.units[0],{q:0,r:0});return state;
};

test('resolved Ice and Flood have distinct surfaces and exact inspection rules, then disappear on expiry',()=>{
  const before=arena(),freezer=before.units[0],water=before.units[1];
  freezer.loadout=['frostbite','water_jet','ember','mend'];
  Object.assign(water,{q:-1,r:1,loadout:['water_jet','ember','mend','gust']});
  const after=resolveRound(before,[{orders:[{unitId:freezer.id,spellId:'frostbite',cast:{q:1,r:0}},{unitId:water.id,spellId:'water_jet',cast:{q:0,r:1}}]},{orders:[]}]);
  assert.ok(isIce(getCell(after,1,0)!));assert.ok(isFlooded(getCell(after,0,1)!));
  const icy=render(after,{aimTarget:{q:1,r:0}}),flooded=render(after,{aimTarget:{q:0,r:1}});
  assert.equal((icy.match(/data-surface="ice"/g)||[]).length,1);
  assert.equal((icy.match(/data-surface="flood"/g)||[]).length,1);
  assert.ok(icy.includes('Slide to the last icy hex'));assert.ok(flooded.includes('Flood: 2 effort in or out'));
  const expired=resolveRound(after,[{orders:[]},{orders:[]}]);
  const settled=render(expired);
  assert.ok(!settled.includes('data-surface="ice"'));assert.ok(!settled.includes('data-surface="flood"'));
});

test('real spell resolutions select distinct art for all six elements and frozen Water',()=>{
  const spells=[['ember','fire'],['water_jet','water'],['gust','air'],['stone','earth'],['radiant_bolt','light'],['wither_bolt','dark'],['frostbite','ice']] as const;
  const silhouettes=new Set<string>();
  for(const [spellId,material] of spells){
    const before=arena(),caster=before.units[0];
    caster.loadout=[spellId,...['ember','water_jet','mend','gust'].filter(id=>id!==spellId)].slice(0,4);
    const after=resolveRound(before,[{orders:[{unitId:caster.id,spellId,cast:{q:1,r:0}}]},{orders:[]}]);
    const html=render(after,{previousState:before,resolving:true,interactive:false,kind:'cast'});
    assert.deepEqual(impactCells(html,spellId),['1,0']);
    assert.ok(html.includes(`data-impact-material="${material}"`),`${spellId} uses ${material} art`);
    const art=html.match(new RegExp(`data-impact-material="${material}"[\\s\\S]*?<path[^>]* d="([^"]+)"`));
    assert.ok(art,`${material} has actual geometry, not only a color class`);silhouettes.add(art![1]);
    assert.equal((html.match(/aria-disabled="true"/g)||[]).length,271);
  }
  assert.equal(silhouettes.size,7,'material silhouettes differ independently of their color');
});

test('advanced Lightning and Metal resolve with their own silhouettes and exact spell footprints',()=>{
  const paths=new Set<string>();
  for(const [spellId,material,championId] of [['fire_lance','lightning','oh_tipi'],['shatter','metal','treevor_mason']] as const){
    const before=createSimGame(),caster=before.units.find(unit=>unit.championId===championId)!;
    Object.assign(before,{round:7,version:7});
    before.cells.forEach(cell=>Object.assign(cell,{terrain:'plain',biome:'plain',height:0,well:false}));
    Object.assign(caster,{q:0,r:0,loadout:[spellId,'ember','water_jet','mend'],affinities:spellId==='fire_lance'?{fire:4,water:3}:{earth:4,air:1,fire:1}});
    const target={q:2,r:0};
    const after=resolveRound(before,[{orders:[{unitId:caster.id,spellId,cast:target}]},{orders:[]}]);
    const html=render(after,{previousState:before,resolving:true,interactive:false});
    assert.deepEqual(impactCells(html,spellId),spellArea(before,caster.id,spellId,target).map(cell=>`${cell.q},${cell.r}`).sort());
    const geometry=html.match(new RegExp(`data-impact-material="${material}"[\\s\\S]*?<path[^>]* d="([^"]+)"`));
    assert.ok(geometry,`${material} renders authored geometry on every impacted hex`);
    paths.add(geometry![1]);
    assert.ok(!html.includes(`data-impact-material="${material==='metal'?'earth':'fire'}"`),'advanced branch keeps a distinct impact silhouette from its parent element');
  }
  assert.equal(paths.size,2);
});

test('Fire and Steam retain bounded, readable surface silhouettes and stop after their fields expire',()=>{
  const state=arena(),cell=getCell(state,1,0)!;
  Object.assign(cell,{terrain:'fire',elements:['fire'],ttl:1});
  const fire=renderToStaticMarkup(createElement(Surface,{cell,animate:true}));
  assert.equal((fire.match(/data-particle="field-flame"/g)||[]).length,3);
  assert.equal((fire.match(/data-particle="field-ember"/g)||[]).length,3);
  assert.ok(fire.includes('is-living'));
  const quietFire=renderToStaticMarkup(createElement(Surface,{cell,animate:false}));
  assert.ok(!quietFire.includes('is-living'));
  assert.equal((quietFire.match(/data-particle="field-flame"/g)||[]).length,3,'Overview keeps the material identifiable without looping motion');
  Object.assign(cell,{terrain:'steam',elements:['fire','water'],reactions:['steam']});
  const steam=renderToStaticMarkup(createElement(Surface,{cell,animate:true}));
  assert.ok(steam.includes('data-surface="steam"'));
  assert.equal((steam.match(/data-particle="steam-puff"/g)||[]).length,3,'a wide Steam field has a fixed per-hex rendering budget');
  assert.ok(!steam.includes('data-surface="flood"'),'Steam cannot be mistaken for a movement-slowing Flood');
  Object.assign(cell,{terrain:'plain'});delete cell.ttl;delete cell.elements;delete cell.reactions;
  assert.equal(renderToStaticMarkup(createElement(Surface,{cell,animate:true})),'' ,'expired spell fields leave no lingering effects');
});

test('a visible projectile follows its actual cast endpoints and arrives on the shared impact clock',()=>{
  const from={x:10,y:-30},to={x:174,y:42};
  const lightning=renderToStaticMarkup(createElement(Projectile,{from,to,element:'fire',shape:'line',branch:'Lightning'}));
  assert.ok(lightning.includes('d="M10 -30L174 42"'));
  assert.ok(lightning.includes('offset-path:path(&quot;M10 -30L174 42&quot;)'));
  assert.ok(lightning.includes('data-projectile-arrival="900"'));
  assert.ok(lightning.includes('--px-flight-delay:570ms'));
  assert.ok(lightning.includes('--px-flight-duration:330ms'));
  assert.equal((lightning.match(/class="px-v9-flight-head"/g)||[]).length,1,'one traveling head per cast keeps the animation bounded');
  const arc=renderToStaticMarkup(createElement(Projectile,{from,to,element:'water'}));
  assert.ok(arc.includes('M10 -30Q92 -74 174 42'),'lobbed spells have one authored arc between their real endpoints');
  assert.equal(renderToStaticMarkup(createElement(Projectile,{from,to:from,element:'light'})),'' ,'self spells never invent a projectile journey');
});

test('resolution renders actual travel keyframes on both actor and healthbar after an icy detour',()=>{
  const before=arena(),unit=before.units[0];
  getCell(before,1,0)!.biome='ruins';
  for(const [q,r] of [[1,-1],[2,-1]])Object.assign(getCell(before,q,r)!,{terrain:'water',elements:['water'],ice:true,ttl:1});
  const target={q:3,r:-1},route=movementPath(before,unit.id,target)!;
  assert.ok(route.length>=3);assert.ok(!route.some(cell=>cell.q===1&&cell.r===0));
  const after=resolveRound(before,[{orders:[{unitId:unit.id,move:target}]},{orders:[]}]);
  const html=render(after,{previousState:before,resolving:true,interactive:false});
  const name=html.match(/@keyframes (px-v9-route-[a-zA-Z0-9_-]+)/)?.[1];
  assert.ok(name,'the exact movement route is injected');
  assert.equal((html.match(new RegExp(`animation-name:${name}`,'g'))||[]).length,2,'sprite and healthbar share the same route');
  assert.ok(html.includes('animation-duration:1400ms'));assert.ok(html.includes('animation-timing-function:linear'));
  assert.ok(!render(after).includes('@keyframes px-v9-route-'),'planning does not keep replay animation live');
});

test('ring resolution preserves its empty centre and disables all 271 planning targets',()=>{
  const before=createSimGame(),caster=before.units[0];
  Object.assign(before,{round:7,version:7});
  Object.assign(caster,{q:0,r:0,loadout:['maelstrom','water_jet','ember','mend'],affinities:{water:6,fire:2}});
  const after=resolveRound(before,[{orders:[{unitId:caster.id,spellId:'maelstrom',cast:{q:0,r:0}}]},{orders:[]}]);
  const html=render(after,{previousState:before,resolving:true,interactive:false,kind:'cast'});
  const actual=impactCells(html,'maelstrom');
  assert.equal(actual.length,12);assert.equal(new Set(actual).size,12);assert.ok(!actual.includes('0,0'));
  assert.deepEqual(actual,spellArea(before,caster.id,'maelstrom',{q:0,r:0}).map(cell=>`${cell.q},${cell.r}`).sort());
  assert.ok(!html.includes('class="px-cast-tracer"'),'a self-centred spell has no projectile journey');
  assert.ok(!html.includes('data-projectile-material='),'a self-centred spell has no traveling projectile head');
  assert.equal((html.match(/aria-disabled="true"/g)||[]).length,271);
});

test('simultaneous new barriers never retroactively shorten the displayed original beam area',()=>{
  const before=createSimGame(undefined,'frontier:BEAM-0'),beam=before.units[0],builder=before.units[2];
  Object.assign(before,{round:7,version:7});
  Object.assign(beam,{q:0,r:0,loadout:['fire_lance','water_jet','ember','mend'],affinities:{fire:4,water:3}});
  Object.assign(builder,{q:2,r:-2,loadout:['raise_cairn','water_jet','ember','mend'],affinities:{earth:4,air:1,fire:1}});
  assert.ok(legalCasts(before,beam.id,undefined,'fire_lance').some(cell=>cell.q===4&&cell.r===0));
  const after=resolveRound(before,[{orders:[{unitId:beam.id,spellId:'fire_lance',cast:{q:4,r:0}},{unitId:builder.id,spellId:'raise_cairn',cast:{q:2,r:0}}]},{orders:[]}]);
  assert.ok(after.cells.find(cell=>cell.q===2&&cell.r===0)?.barrier);
  assert.equal(spellArea(after,beam.id,'fire_lance',{q:4,r:0},{q:0,r:0}).length,0);
  const html=render(after,{previousState:before,resolving:true,interactive:false,kind:'cast'});
  assert.deepEqual(impactCells(html,'fire_lance'),['1,0','2,0','3,0','4,0']);
});
