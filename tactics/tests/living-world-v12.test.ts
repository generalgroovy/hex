import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {exposedCliffs,worldProps,visibleFieldForecast,type WorldCell} from '../lib/living-world-v12.ts';
import {generateArena} from '../lib/arena-v7.ts';
import {fieldCombination,isIce,type SimCell} from '../lib/tactics-v12.ts';
import type {InhabitantIntent} from '../lib/inhabitants-v12.ts';

test('adjacent equal-height land is continuous, with no internal cliff faces',()=>{
  const cell:WorldCell={q:0,r:0,height:0,biome:'plain',well:false};
  const ground=[cell,...[{q:1,r:0},{q:0,r:1},{q:-1,r:1}].map(point=>({...cell,...point}))];
  assert.deepEqual(exposedCliffs(cell,ground),[]);
  assert.deepEqual(exposedCliffs({...cell,height:1},ground.map(item=>({...item,height:1}))),[]);
});
test('cliffs expose the exact lower neighbour edge, not every raised hex side',()=>{
  const cell:WorldCell={q:0,r:0,height:1,biome:'earth',well:false};
  const land=[cell,{...cell,q:1},{...cell,r:1,height:0},{...cell,q:-1,r:1}];
  assert.deepEqual(exposedCliffs(cell,land).map(face=>[face.edge,face.depth]),[[2,24]]);
  assert.deepEqual(exposedCliffs({...cell,height:0},[{...cell,height:0}]).map(face=>face.depth),[9,9,9]);
});
test('world decoration is repeatable and never places false walls or cover on open ground',()=>{
  for(const seed of ['WELLSPRING','STORY-OH-TIPI','CLEAR-MEADOW','MOON-CROSSING']){
    const cells=generateArena(`frontier:${seed}`),snapshot=JSON.stringify(cells),props=worldProps(cells);
    assert.deepEqual(props,worldProps(cells));assert.equal(JSON.stringify(cells),snapshot);
    assert.ok(props.length<100);assert.ok(props.every(prop=>!prop.cell.well));
    assert.ok(props.filter(prop=>prop.frame===0||prop.frame===1).every(prop=>prop.cell.biome==='forest'));
    assert.ok(props.filter(prop=>prop.frame===4||prop.frame===5).every(prop=>prop.cell.biome==='ruins'));
    assert.ok(props.filter(prop=>prop.cell.biome==='plain').every(prop=>prop.frame===2&&prop.size<50));
  }
});
test('copied environment PNGs match their provenance manifest and declared grid',()=>{
  const manifest=JSON.parse(readFileSync(new URL('../public/pixel/environment/manifest.json',import.meta.url),'utf8').replace(/^\uFEFF/,''));
  for(const kind of ['props','surfaces']){
    const entry=manifest[kind],bytes=readFileSync(new URL(`../public${entry.path}`,import.meta.url));
    assert.equal(createHash('sha256').update(bytes).digest('hex'),entry.sha256);
    assert.equal(bytes.readUInt32BE(16),512);assert.equal(bytes.readUInt32BE(20),512);
    assert.equal(entry.order.length,16);assert.equal(manifest.cell,128);
  }
});
test('field preview includes natural ground, public inhabitants, and counterspell interruption',()=>{
  const cell:SimCell={q:0,r:0,height:1,biome:'earth',terrain:'earth',well:false};
  const pulse:InhabitantIntent={id:'test',name:'Test',phase:'pulse',area:[cell],elements:['water'],counterElement:'air',anchor:{q:1,r:0},tell:''};
  const fire={element:'fire' as const,area:[cell]};
  assert.equal(fieldCombination(visibleFieldForecast(cell,[fire],[pulse]))?.id,'hot_spring');
  assert.equal(fieldCombination(visibleFieldForecast(cell,[fire,{element:'air',area:[pulse.anchor]}],[pulse]))?.id,'magma');
  assert.equal(fieldCombination(visibleFieldForecast(cell,[fire],[{...pulse,phase:'rest'}]))?.id,'magma');
});
test('field preview retains deliberate freezing only when the resulting material permits it',()=>{
  const cell:SimCell={q:0,r:0,height:0,biome:'plain',terrain:'plain',well:false};
  assert.ok(isIce(visibleFieldForecast(cell,[{element:'water',area:[cell],freeze:true}],[])));
  assert.equal(isIce(visibleFieldForecast(cell,[{element:'water',area:[cell],freeze:true},{element:'fire',area:[cell]}],[])),false);
});
