import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {fileURLToPath} from 'node:url';
import {CHAMPIONS} from '../lib/roster.ts';
import {TILE_HALF_HEIGHT,TILE_HALF_WIDTH,TILE_STEP_X,SPRITE_SIZE,SPRITE_FOOT,FOCUS_HEX_PIXELS,groundPoint,surfacePoint,battlefieldBounds,focusViewSize,clampCamera,fitEffect} from '../lib/battlefield-geometry.ts';

test('all 960 original champion frames have room for their feet without shrinking the sprites',async(t)=>{
  assert.equal(CHAMPIONS.length,30);assert.equal(SPRITE_SIZE,192);
  let frameCount=0,widestBody=0,widestFeet=0;
  for(const champion of CHAMPIONS){
    const path=new URL(`../public${champion.sprite}`,import.meta.url);
    const {data,info}=await sharp(fileURLToPath(path)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    assert.equal(info.width,1024);assert.equal(info.height,512);
    for(let row=0;row<4;row++)for(let facing=0;facing<8;facing++){
      let left=128,right=-1,footLeft=128,footRight=-1;
      for(let y=0;y<128;y++)for(let x=0;x<128;x++){
        if(data[((row*128+y)*info.width+facing*128+x)*4+3]===0)continue;
        left=Math.min(left,x);right=Math.max(right,x);
        if(y>=96){
          footLeft=Math.min(footLeft,x);footRight=Math.max(footRight,x);
          const px=(x-SPRITE_FOOT.x)*SPRITE_SIZE/128,py=(y-SPRITE_FOOT.y)*SPRITE_SIZE/128;
          const halfWidth=TILE_HALF_WIDTH*(Math.abs(py)<=TILE_HALF_HEIGHT/2?1:2*(1-Math.abs(py)/TILE_HALF_HEIGHT));
          assert.ok(Math.abs(px)+4<=halfWidth&&Math.abs(py)+4<TILE_HALF_HEIGHT,`${champion.id} row${row} facing${facing}: foot pixel ${x},${y} outside ground`);
        }
      }
      assert.ok(right>=left&&footRight>=footLeft,`${champion.id}: visible body and feet`);
      assert.ok((right-left+1)*SPRITE_SIZE/128<TILE_STEP_X-8,`${champion.id}: horizontal body crowds adjacent cell`);
      widestBody=Math.max(widestBody,right-left+1);widestFeet=Math.max(widestFeet,footRight-footLeft+1);frameCount++;
    }
  }
  assert.equal(frameCount,960);assert.ok(widestBody>60);assert.ok(widestFeet>50);
  t.diagnostic(`30 atlases, ${frameCount} frames: widest individual body ${widestBody*1.5}px, feet ${widestFeet*1.5}px, tile ${TILE_STEP_X}px; sprite scale unchanged.`);
});

test('tactical camera preserves readable hex width at desktop and small phone sizes',()=>{
  for(const viewport of [{width:960,height:500},{width:375,height:232},{width:305,height:232}]){
    const size=focusViewSize(viewport);
    assert.equal(Math.round(TILE_STEP_X*viewport.width/size.width),FOCUS_HEX_PIXELS);
    assert.ok(Math.abs(size.width/size.height-viewport.width/viewport.height)<1e-12);
  }
});

const cells=Array.from({length:13},(_,i)=>i-6).flatMap(q=>Array.from({length:13},(_,i)=>i-6).filter(r=>Math.abs(q+r)<=6).map(r=>({q,r,height:(q===2&&r===-2)?1:0})));
test('overview bounds contain all ground and sprite frames on the 127 hex map',()=>{
  assert.equal(cells.length,127);
  for(const terrain of [cells,cells.map(cell=>({...cell,height:1}))]){
    const bounds=battlefieldBounds(terrain);
    for(const cell of terrain){const at=surfacePoint(cell,cell.height);assert.ok(at.x-TILE_HALF_WIDTH>bounds.left&&at.x+TILE_HALF_WIDTH<bounds.right);assert.ok(at.y-SPRITE_SIZE*.8125>bounds.top);assert.ok(groundPoint(cell).y+TILE_HALF_HEIGHT<bounds.bottom)}
  }
});

test('pan clamps symmetrically and complete edge effects fit on phone and desktop',()=>{
  const bounds=battlefieldBounds(cells);
  for(const viewport of [{width:960,height:500},{width:375,height:232},{width:305,height:232}]){
    const points=[{q:-4,r:0},...cells.filter(cell=>Math.max(Math.abs(cell.q-2),Math.abs(cell.r+4),Math.abs(cell.q+cell.r+2))<=2)].map(point=>surfacePoint(point,cells.find(c=>c.q===point.q&&c.r===point.r)?.height));
    const fitted=fitEffect(points,viewport),size=focusViewSize(viewport,fitted.scale),center=clampCamera(fitted.center,bounds,size);
    for(const point of points){assert.ok(point.x-TILE_HALF_WIDTH>=center.x-size.width/2&&point.x+TILE_HALF_WIDTH<=center.x+size.width/2);assert.ok(point.y-115>=center.y-size.height/2&&point.y+TILE_HALF_HEIGHT<=center.y+size.height/2)}
    const left=clampCamera({x:-1e6,y:-1e6},bounds,size),right=clampCamera({x:1e6,y:1e6},bounds,size);
    assert.ok(left.x<=right.x&&left.y<=right.y);assert.equal((left.x+right.x)/2,(bounds.left+bounds.right)/2);
  }
});
