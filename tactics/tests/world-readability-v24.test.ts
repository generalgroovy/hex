import test from 'node:test';
import assert from 'node:assert/strict';
import {solidFootprints,WORLD_HEX_VERTICES,groundDetailSeed,terrainEffectDescription,groundEdges,worldFringe,sceneryOpacity} from '../lib/world-readability-v24.ts';
import {worldProps} from '../lib/living-world-v16.ts';
import {planningCamera} from '../lib/planning-camera-v16.ts';
import {TILE_SCALE,TILE_STEP_X,TILE_HALF_WIDTH,TILE_HALF_HEIGHT,ELEVATION_STEP,focusViewSize,surfacePoint} from '../lib/battlefield-geometry.ts';
import {generateArena} from '../lib/arena-v17.ts';
import {isCellSolid,previewField,type SimCell} from '../lib/tactics-v16.ts';

const cell:SimCell={q:0,r:0,biome:'plain',terrain:'plain',height:0,well:false};
test('every visually solid footprint agrees with real movement blocking across two and six player maps',()=>{
 for(const count of [2,6])for(const seed of ['CLOVER','IRONWOOD','WELLSPRING']){
  const cells:SimCell[]=generateArena(`arena:${count}:${seed}`).map(entry=>({...entry}));
  const open=cells.find(entry=>!isCellSolid(entry)&&!entry.well)!;open.barrier=2;
  const before=JSON.stringify(cells),footprints=solidFootprints(cells);
  assert.equal(footprints.size,cells.filter(isCellSolid).length);
  for(const entry of cells)assert.equal(footprints.has(`${entry.q},${entry.r}`),isCellSolid(entry));
  assert.deepEqual(solidFootprints(cells),footprints);assert.equal(JSON.stringify(cells),before);
 }
});

test('solid tops occupy the full hex and connected walls have no false internal alley',()=>{
 const a={...cell,biome:'ruins' as const,terrain:'earth'},b={...a,q:1};
 const footprints=solidFootprints([a,b]),left=footprints.get('0,0')!,right=footprints.get('1,0')!;
 assert.equal(left.top,WORLD_HEX_VERTICES.map(([x,y])=>`${x},${y-left.lift}`).join(' '));
 assert.ok(!left.faces.some(face=>face.edge===1),'No front face between joined ruins');
 assert.ok(!left.rim.includes('M44 -39L44 -9'),'No apparent gap along the common edge');
 const exposed=solidFootprints([a]).get('0,0')!;
 assert.ok(exposed.faces.some(face=>face.edge===1));
 assert.equal(right.lift,left.lift);
 const raised=solidFootprints([a,{...b,height:1}]);
 assert.ok(raised.get('0,0')!.faces.some(face=>face.edge===1),'Different heights retain their boundary');
 assert.equal(ELEVATION_STEP,24*TILE_SCALE,'Cliff depth and surface elevation use one projection');
});

test('current planning camera keeps larger on-screen hexes and the selected actor inside small and large arenas',()=>{
 for(const count of [2,6]){
  const cells=generateArena(`arena:${count}:READABILITY`),origin=cells.find(entry=>entry.q===0&&entry.r===0)!;
  for(const viewport of [{width:820,height:510},{width:360,height:232},{width:305,height:198}]){
   const frame=planningCamera({viewport,origin,legalTargets:cells,cells}),view=focusViewSize(viewport,frame.scale),at=surfacePoint(origin,origin.height);
   const pixels=TILE_STEP_X*viewport.width/view.width;
   assert.ok(pixels>=(viewport.width<=600?64:96)-1e-9);
   assert.ok(at.x-TILE_HALF_WIDTH>=frame.center.x-view.width/2);assert.ok(at.x+TILE_HALF_WIDTH<=frame.center.x+view.width/2);
   assert.ok(at.y-130>=frame.center.y-view.height/2);assert.ok(at.y+TILE_HALF_HEIGHT<=frame.center.y+view.height/2);
  }
 }
});

test('continuous ground omits ordinary interior rims and keeps actual exposed cliffs readable',()=>{
 const adjacent={...cell,q:1};
 const edges=groundEdges([cell,adjacent]);
 assert.ok(!edges.get('0,0')!.some(edge=>edge.edge===1));
 assert.ok(!edges.get('1,0')!.some(edge=>edge.edge===4));
 assert.equal(edges.get('0,0')!.filter(edge=>edge.kind==='rim').length,5);
 const raised=groundEdges([{...cell,height:1},adjacent]);
 assert.equal(raised.get('0,0')!.find(edge=>edge.edge===1)?.kind,'rise');
 const wooded=groundEdges([{...cell,biome:'forest'},adjacent]);
 assert.equal(wooded.get('0,0')!.find(edge=>edge.edge===1)?.kind,'woodland');
});

test('distant woods remain entirely outside real two and six player maps and decoration cannot mutate rules',()=>{
 for(const players of [2,6]){
  const cells:SimCell[]=generateArena(`arena:${players}:WOODLAND`).map(entry=>({...entry})),before=JSON.stringify(cells),ids=new Set(cells.map(entry=>`${entry.q},${entry.r}`));
  const fringe=worldFringe(cells);
  assert.ok(fringe.length>5);assert.ok(fringe.every(tree=>!ids.has(tree.id)));
  assert.deepEqual(fringe,worldFringe(cells));assert.equal(new Set(fringe.map(tree=>tree.id)).size,fringe.length);
  assert.ok(worldProps(cells).every(prop=>!prop.cell.well&&prop.motion==='none'));
  assert.equal(JSON.stringify(cells),before);
 }
});

test('planning includes the nearby living encounter but not a distant idle team',()=>{
 const viewport={width:1000,height:640},cells=Array.from({length:17},(_,i)=>({...cell,q:i-8}));
 const ordinary=planningCamera({viewport,origin:cell,legalTargets:[],cells});
 const nearby=planningCamera({viewport,origin:cell,legalTargets:[],cells,contextTargets:[{q:3,r:0}]});
 assert.ok(nearby.center.x>ordinary.center.x);
 assert.deepEqual(planningCamera({viewport,origin:cell,legalTargets:[],cells,contextTargets:[{q:8,r:0}]}),ordinary);
});

test('scenery clears the body and feet of neighbouring fighters and planned ghosts, not only tree cells',()=>{
 const actor={x:0,y:0},ghost={x:176,y:90};
 const foregroundTree={x:60,y:80,size:178,canopy:true};
 assert.ok(sceneryOpacity(foregroundTree,[actor],true)<=.12);
 assert.ok(sceneryOpacity({...foregroundTree,canopy:false},[actor],true)<=.12,'Flowers and rocks also clear fighters');
 assert.ok(sceneryOpacity({x:200,y:110,size:60,canopy:false},[actor,ghost],true)<=.12,'Planned landing clears low decorations');
 assert.equal(sceneryOpacity({x:700,y:500,size:178,canopy:true},[actor,ghost],true),1,'Distant scenery retains its art');
 assert.equal(sceneryOpacity({x:0,y:-40,size:178,canopy:true},[actor],true),.45,'Background canopy is subdued without disappearing');
 assert.ok(sceneryOpacity(foregroundTree,[actor],false)>sceneryOpacity(foregroundTree,[actor],true),'Compact scenery yields more strongly');
});

test('ground accent placement is stable through field changes and distinct across nearby hexes',()=>{
 assert.equal(groundDetailSeed(cell),groundDetailSeed({...cell}));
 assert.notEqual(groundDetailSeed(cell),groundDetailSeed({...cell,q:1}));
 assert.notEqual(groundDetailSeed(cell),groundDetailSeed({...cell,r:1}));
});

test('hovered field explanations expose real damage and movement, including dry ice rather than liquid-water rules',()=>{
 const water=previewField(cell,['water']),ice=previewField(cell,['water'],true),steam=previewField(cell,['fire','water']);
 assert.match(terrainEffectDescription(water),/costs 2 movement/);assert.match(terrainEffectDescription(water),/Wet/);
 assert.match(terrainEffectDescription(ice),/slides to the last connected icy hex/);assert.doesNotMatch(terrainEffectDescription(ice),/Wet|Flooded|costs 2 movement/);
 assert.match(terrainEffectDescription(steam),/Halves total incoming spell damage once, rounded up/);
 assert.equal(terrainEffectDescription(cell),'');
});
