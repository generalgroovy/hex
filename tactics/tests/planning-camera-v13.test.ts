import assert from 'node:assert/strict';
import test from 'node:test';
import {planningCamera} from '../lib/planning-camera-v13.ts';
import {TILE_STEP_X,TILE_HALF_WIDTH,TILE_HALF_HEIGHT,focusViewSize,surfacePoint} from '../lib/battlefield-geometry.ts';
import {createSimGame,legalMoves} from '../lib/tactics-v13.ts';

const viewports=[{width:960,height:500},{width:390,height:287},{width:305,height:240}];
test('planning frame exposes more movement context while retaining readable targets and the selected champion',()=>{
  for(const mapId of ['frontier:WELLSPRING','frontier:IRONWOOD','frontier:CINDER']){
    const state=createSimGame(undefined,mapId);
    for(const viewport of viewports)for(const unit of state.units){
      const legalTargets=legalMoves(state,unit.id),frame=planningCamera({viewport,origin:unit,legalTargets,cells:state.cells});
      const view=focusViewSize(viewport,frame.scale),at=surfacePoint(unit,state.cells.find(cell=>cell.q===unit.q&&cell.r===unit.r)?.height);
      const hexPixels=TILE_STEP_X*viewport.width/view.width;
      assert.ok(viewport.width>850?frame.scale>=1:frame.scale>1,'phone movement framing reveals more than the old close-up');
      assert.ok(hexPixels>=(viewport.width<=850?44:64)-1e-9,'targets remain readable');
      assert.ok(at.x-TILE_HALF_WIDTH>=frame.center.x-view.width/2,'selected feet stay in frame');
      assert.ok(at.x+TILE_HALF_WIDTH<=frame.center.x+view.width/2);
      assert.ok(at.y-130>=frame.center.y-view.height/2,'selected head stays in frame');
      assert.ok(at.y+TILE_HALF_HEIGHT<=frame.center.y+view.height/2);
    }
  }
});

test('a compact legal area fits completely, including elevated cells',()=>{
  const origin={q:0,r:0},cells=[{...origin,height:1},{q:1,r:0,height:0},{q:0,r:1,height:1}];
  for(const viewport of viewports){
    const frame=planningCamera({viewport,origin,cells,legalTargets:cells}),view=focusViewSize(viewport,frame.scale);
    for(const cell of cells){
      const at=surfacePoint(cell,cell.height);
      assert.ok(at.x-TILE_HALF_WIDTH>=frame.center.x-view.width/2);
      assert.ok(at.x+TILE_HALF_WIDTH<=frame.center.x+view.width/2);
      assert.ok(at.y-130>=frame.center.y-view.height/2);
      assert.ok(at.y+TILE_HALF_HEIGHT<=frame.center.y+view.height/2);
    }
  }
});

test('long one-sided spell ranges keep their caster visible instead of pulling the camera away',()=>{
  const origin={q:-8,r:0},legalTargets=[{q:9,r:0},{q:8,r:1}],viewport={width:305,height:240};
  const frame=planningCamera({viewport,origin,legalTargets,cells:[]}),view=focusViewSize(viewport,frame.scale),at=surfacePoint(origin);
  assert.ok(at.x-TILE_HALF_WIDTH>=frame.center.x-view.width/2);
  assert.ok(at.x+TILE_HALF_WIDTH<=frame.center.x+view.width/2);
  assert.ok(view.width<Math.abs(surfacePoint(legalTargets[0]).x-at.x),'readable view may crop unreachable-on-screen distant aims');
});

test('empty legal targets and repeated calls remain deterministic without mutating inputs',()=>{
  const origin=Object.freeze({q:1,r:-2}),cells=Object.freeze([Object.freeze({...origin,height:1})]);
  const input={viewport:{width:390,height:287},origin,cells,legalTargets:Object.freeze([])};
  const frame=planningCamera(input);
  assert.equal(frame.scale,1);
  assert.deepEqual(planningCamera(input),frame);
  assert.deepEqual(frame.center,{x:surfacePoint(origin,1).x,y:surfacePoint(origin,1).y+(TILE_HALF_HEIGHT+20-130)/2});
});
