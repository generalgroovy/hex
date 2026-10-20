import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import sharp from 'sharp';
import {ANIMATED_CHARACTER_IDS} from '../lib/animation-assets.ts';
import {ANIMATION_GRID,animationColumnPosition,characterFrameCss} from '../lib/character-animation.ts';
import {SPRITE_EDGE_REPAIRS,animationAtlasDimensionsMatch,spriteEdgeMaskSvg} from '../lib/sprite-integrity-v42.ts';

test('all 1,440 decoded champion cels remain complete, hard-edged and clear of unreviewed single-pixel islands',async()=>{
 let frames=0,repairs=0;
 for(const id of ANIMATED_CHARACTER_IDS){
  const path=new URL(`../public/pixel/animations/${id}.webp`,import.meta.url);
  const {data,info}=await sharp(readFileSync(path)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert.ok(animationAtlasDimensionsMatch(info.width,info.height),id);
  const declared=JSON.parse(readFileSync(new URL(`../docs/animation-assets/${id}.json`,import.meta.url),'utf8'));
  const patches=SPRITE_EDGE_REPAIRS[id]??[];
  for(let row=0;row<ANIMATION_GRID.rows;row++)for(let column=0;column<ANIMATION_GRID.columns;column++){
   frames++;
   const patch=patches.filter(p=>p.row===row&&p.column===column);
   const alpha=(x:number,y:number)=>data[((row*128+y)*info.width+column*128+x)*4+3];
   for(const pixel of patch){
    repairs++;
    assert.equal(alpha(pixel.x,pixel.y),255,`${id} ${row},${column}: repair still addresses an opaque pixel`);
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)if(dx||dy)assert.equal(alpha(pixel.x+dx,pixel.y+dy),0,`${id}: never mask an attached feature`);
   }
   const [left,top,width,height]=declared.frames.find((f:{row:number;column:number})=>f.row===row&&f.column===column).bounds;
   let opaque=0;
   for(let y=0;y<128;y++)for(let x=0;x<128;x++){
    const a=alpha(x,y);
    assert.ok(a===0||a===255,`${id} ${row},${column}: no soft alpha fringe`);
    if(!a)continue;
    opaque++;
    assert.ok(x>0&&x<127&&y>0&&y<127,`${id} ${row},${column}: transparent frame padding`);
    assert.ok(x>=left&&x<left+width&&y>=top&&y<top+height,`${id} ${row},${column}: pixels match authored bounds`);
    if(patch.some(p=>p.x===x&&p.y===y))continue;
    let neighbours=0;
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)if(dx||dy)neighbours+=Number(alpha(x+dx,y+dy)>0);
    assert.ok(neighbours>0,`${id} ${row},${column}: unreviewed isolated pixel at ${x},${y}`);
   }
   assert.ok(opaque>200,`${id} ${row},${column}: a complete pose, not an empty or fragmentary frame`);
  }
 }
 assert.equal(frames,1440);
 assert.equal(repairs,9);
});

test('the repair masks remove exactly the nine reviewed source pixels and no others',async()=>{
 let removed=0;
 for(const [id,repairs] of Object.entries(SPRITE_EDGE_REPAIRS)){
  const svg=spriteEdgeMaskSvg(id)!;
  const {data,info}=await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const holes=new Set(repairs.map(p=>`${p.column*128+p.x},${p.row*128+p.y}`));
  assert.equal(info.width,768);assert.equal(info.height,1024);
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
   const expected=holes.has(`${x},${y}`)?0:255;
   assert.equal(data[(y*info.width+x)*4+3],expected,`${id}: exact mask at ${x},${y}`);
   if(!expected)removed++;
  }
 }
 assert.equal(removed,9);
 assert.equal(spriteEdgeMaskSvg('dr_apex'),undefined,'no layer for unaffected artwork');
});

test('art and repair masks keep the same source cell at every frame and responsive size',()=>{
 for(const size of [30,44,96,128,192,224]){
  const animation=characterFrameCss('oh_tipi','walk',size);
  for(let frame=0;frame<6;frame++){
   const percent=animationColumnPosition(frame);
   assert.ok(animation.css.includes(`background-position-x:${percent};mask-position-x:${percent}`));
   // CSS background percentage positions use container minus image width.
   assert.equal((size-size*6)*Number.parseFloat(percent)/100,-size*frame);
  }
 }
 assert.equal(animationColumnPosition(2.5),'40%');
 assert.equal(animationColumnPosition(Number.NaN),'0%');
 assert.equal(animationColumnPosition(-1),'0%');
 assert.equal(animationColumnPosition(40),'100%');
 assert.equal(animationAtlasDimensionsMatch(768,1024),true);
 assert.equal(animationAtlasDimensionsMatch(767,1024),false);
 assert.equal(animationAtlasDimensionsMatch(1024,512),false);
});

test('original scenery stays byte-identical and every prop has a transparent frame boundary',async()=>{
 const manifest=JSON.parse(readFileSync(new URL('../public/pixel/environment/manifest.json',import.meta.url),'utf8'));
 for(const entry of [manifest.props,manifest.surfaces]){
  const bytes=readFileSync(new URL(`../public${entry.path}`,import.meta.url));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),entry.sha256);
 }
 for(const file of ['wellspring-props.png','reactive-props-v17.webp']){
  const {data,info}=await sharp(readFileSync(new URL(`../public/pixel/environment/${file}`,import.meta.url))).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert.equal(info.width,512);assert.equal(info.height,512);
  for(let row=0;row<4;row++)for(let column=0;column<4;column++)for(let edge=0;edge<128;edge++){
   for(const [x,y] of [[edge,0],[edge,127],[0,edge],[127,edge]]){
    assert.equal(data[((row*128+y)*info.width+column*128+x)*4+3],0,`${file} ${row},${column}: no adjacent prop leakage`);
   }
  }
 }
});

test('all 960 original portrait and fallback poses remain byte-identical without isolated opaque pixels',async()=>{
 const manifest=JSON.parse(readFileSync(new URL('../public/pixel/manifest.json',import.meta.url),'utf8'));
 let frames=0;
 for(const character of manifest.characters){
  const bytes=readFileSync(new URL(`../public${character.sprite}`,import.meta.url));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),character.sha256,character.id);
  const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert.equal(info.width,1024);assert.equal(info.height,512);
  for(let row=0;row<4;row++)for(let column=0;column<8;column++){
   frames++;
   const alpha=(x:number,y:number)=>data[((row*128+y)*info.width+column*128+x)*4+3];
   for(let y=1;y<127;y++)for(let x=1;x<127;x++){
    if(!alpha(x,y))continue;
    let neighbours=0;
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)if(dx||dy)neighbours+=Number(alpha(x+dx,y+dy)>0);
    assert.ok(neighbours>0,`${character.id} ${row},${column}: stray opaque pixel at ${x},${y}`);
   }
  }
 }
 assert.equal(frames,960);
});
