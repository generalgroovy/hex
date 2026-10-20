import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync,existsSync} from 'node:fs';
import {createRequire} from 'node:module';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import ts from 'typescript';
import {formatTile,parseTile} from '../lib/board-labels-v9.ts';
import {generateArena} from '../lib/arena-v7.ts';
import {groundPoint} from '../lib/battlefield-geometry.ts';
import {createSimGame,legalMoves,type Point} from '../lib/tactics-v9.ts';

test('all 271 map references are unique, reversible and stable between replay seeds',()=>{
  const labels=new Set<string>();
  for(const point of generateArena('frontier:WELLSPRING')){
    const label=formatTile(point);assert.match(label,/^[A-S](?:[1-9]|1[0-9])$/);
    assert.ok(!labels.has(label));labels.add(label);
    assert.deepEqual(parseTile(label),{q:point.q,r:point.r});
    assert.deepEqual(parseTile(` ${label.toLowerCase()} `),{q:point.q,r:point.r});
  }
  assert.equal(labels.size,271);
  assert.deepEqual(new Set(generateArena('frontier:OTHER-SEED').map(formatTile)),labels);
  assert.equal(formatTile({q:0,r:0}),'J10');
  assert.equal(formatTile({q:-9,r:0}),'A10');
  assert.equal(formatTile({q:9,r:0}),'S10');
});

test('letters follow screen left-to-right and row numbers follow top-to-bottom',()=>{
  const cells=generateArena();
  for(let r=-9;r<=9;r++){
    const row=cells.filter(cell=>cell.r===r).sort((a,b)=>groundPoint(a).x-groundPoint(b).x);
    const labels=row.map(formatTile);
    assert.ok(labels.every(label=>Number(label.slice(1))===r+10));
    for(let i=1;i<labels.length;i++)assert.equal(labels[i].charCodeAt(0),labels[i-1].charCodeAt(0)+1);
  }
  assert.equal(formatTile({q:0,r:-1}),'I9','odd rows retain their real half-hex stagger');
  assert.equal(formatTile({q:0,r:1}),'J11');
});

test('nonexistent corners, malformed references and non-board positions are rejected',()=>{
  for(const label of ['A1','S1','A19','S19','J0','J20','T10','A01','J1.5','0,0','JJ10',''])assert.equal(parseTile(label),null,label);
  for(const point of [{q:10,r:0},{q:9,r:9},{q:.5,r:0},{q:NaN,r:0}])assert.equal(formatTile(point),'—');
});

// Real renderer and click handlers with inert hooks; layout and camera effects
// are tested separately. This verifies that display references never enter plans.
type Node={type:unknown;props:Record<string,any>};
const require=createRequire(import.meta.url),modules=new Map<string,{exports:any}>();
function loadSource(filename:string):any {
  const cached=modules.get(filename);if(cached)return cached.exports;
  const module={exports:{}};modules.set(filename,module);
  const javascript=ts.transpileModule(readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
  const localRequire=(specifier:string):unknown=>{
    if(specifier==='react')return {useEffect:()=>{},useId:()=>'tile-test',useMemo:(fn:()=>unknown)=>fn(),useRef:(current:unknown)=>({current}),useState:(initial:unknown)=>[typeof initial==='function'?initial():initial,()=>{}]};
    if(specifier.endsWith('.css'))return {};
    if(!specifier.startsWith('.'))return require(specifier);
    const target=resolve(dirname(filename),specifier),found=['','.ts','.tsx','.js','.json'].map(suffix=>target+suffix).find(path=>existsSync(path));
    assert.ok(found,`missing renderer dependency ${specifier}`);
    return /\.tsx?$/.test(found)?loadSource(found):require(found);
  };
  new Function('require','module','exports',javascript)(localRequire,module,module.exports);
  return module.exports;
}
function nodes(value:unknown):Node[] {
  if(Array.isArray(value))return value.flatMap(nodes);
  if(!value||typeof value!=='object'||!('props' in value))return [];
  const node=value as Node;return [node,...nodes(node.props.children)];
}
const text=(value:unknown):string=>Array.isArray(value)?value.map(text).join(''):value&&typeof value==='object'&&'props' in value?text((value as Node).props.children):value===null||value===undefined?'':String(value);
const Battlefield=loadSource(fileURLToPath(new URL('../app/components/PixelBattlefieldV9.tsx',import.meta.url))).default;

test('labelled target taps keep exact axial coordinates, with only inspected and queued tile annotations',()=>{
  const state=createSimGame(),unit=state.units[0],target=legalMoves(state,unit.id).find(point=>point.q!==unit.q||point.r!==unit.r)!;
  const chosen:Point[]=[];
  const tree=Battlefield({state,plan:{orders:[{unitId:unit.id,move:target}]},player:0,selected:unit.id,kind:'move',interactive:true,legalTargets:[target],aimTarget:target,onCell:(q:number,r:number)=>chosen.push({q,r})});
  const all=nodes(tree),tile=all.find(node=>node.props['data-tile']===formatTile(target))!;
  assert.ok(tile);assert.equal(all.filter(node=>node.props['data-tile']).length,271);
  assert.match(tile.props['aria-label'],new RegExp(`^${formatTile(target)}\\.`));
  assert.match(tile.props['aria-label'],/Available move target/);
  tile.props.onClick();assert.deepEqual(chosen,[{q:target.q,r:target.r}]);
  const labels=all.filter(node=>node.props['data-tile-reference']);
  assert.equal(labels.length,1,'the queued and inspected same hex share a single badge');
  assert.equal(labels[0].props['data-tile-reference'],formatTile(target));
  const readout=all.find(node=>node.props.className==='px-board-readout')!;
  assert.ok(text(readout).startsWith(`${formatTile(target)} · `));
  assert.ok(!all.some(node=>node.props.className==='px-board-legend'),'no permanent legend competes with terrain inspection');
});

test('inspected occupant statuses remain visible beside the tile reference',()=>{
  const state=createSimGame(),unit=state.units[0];unit.statuses.burn={turns:2,power:1};
  const tree=Battlefield({state,plan:{orders:[]},player:0,selected:unit.id,kind:'move',interactive:true,aimTarget:unit,onCell:()=>{}});
  const readout=nodes(tree).find(node=>node.props.className==='px-board-readout')!;
  assert.match(text(readout),/Burn 2/);assert.match(text(readout),/HP/);
  assert.ok(text(readout).startsWith(`${formatTile(unit)} · `));
});
