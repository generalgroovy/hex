import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {CHAMPIONS} from '../lib/roster.ts';
import {ANIMATED_CHARACTER_IDS} from '../lib/animation-assets.ts';
import {animationRow,animationView,animationFrames,animationFrameAt,characterFrameCss} from '../lib/character-animation.ts';
test('every champion has all four authored six-frame actions and all three movement/cast views',()=>{
 assert.deepEqual([...ANIMATED_CHARACTER_IDS].sort(),CHAMPIONS.map(c=>c.id).sort());
 for(const hero of CHAMPIONS){const audit=JSON.parse(readFileSync(new URL(`../docs/animation-assets/${hero.id}.json`,import.meta.url),'utf8'));assert.equal(audit.frames.length,48);assert.equal(audit.segmentation,'complete-alpha-islands');assert.equal(audit.frames.some((f:{touchesSourceEdge:boolean})=>f.touchesSourceEdge),false,`${hero.id}: source artwork has full outside margins`);assert.deepEqual(audit.grid,[6,8]);
  for(let row=0;row<8;row++){const frames=audit.frames.filter((f:{row:number})=>f.row===row);assert.equal(frames.length,6);assert.equal(new Set(frames.map((f:{sha256:string})=>f.sha256)).size,6,`${hero.id} row ${row} has six genuinely different images`);for(const f of frames){const [x,y,w,h]=f.bounds;assert.ok(x>=1&&y>=1&&x+w<=127&&y+h===104,`${hero.id}: no clipped artwork and planted ground`);}}
  const bytes=readFileSync(new URL(`../public${audit.asset}`,import.meta.url));assert.ok(bytes.length>10000);assert.equal(bytes.subarray(0,4).toString(),'RIFF');
 }
});
test('every painted cast releases frame four at exactly the shared 400ms point',()=>{
 const rhythms=new Set();for(const c of CHAMPIONS){assert.equal(animationFrameAt(c.id,'cast',399),2);assert.equal(animationFrameAt(c.id,'cast',400),3);assert.equal(animationFrameAt(c.id,'cast',10000),5);const t=animationFrames(c.id,'cast');assert.ok(t.frames.every((f,i)=>i===0||f.at>t.frames[i-1].at));rhythms.add(t.duration);assert.ok(!/rotate|skew|scale/.test(characterFrameCss(c.id,'cast',192).css));}assert.ok(rhythms.size>=8);
});
test('movement loops six frames while impact and defeat finish on a persistent recovery or fallen frame',()=>{
 for(const c of CHAMPIONS){const walk=animationFrames(c.id,'walk');assert.equal(walk.frames.length,6);assert.equal(animationFrameAt(c.id,'walk',walk.duration),0);for(const action of ['hit','defeat'] as const){assert.equal(animationFrameAt(c.id,action,10000),5);assert.equal(animationFrames(c.id,action).loop,false);}}
 for(let direction=0;direction<8;direction++){assert.ok(animationRow('walk',direction)<3);assert.equal(animationRow('cast',direction),animationRow('walk',direction)+3);assert.equal(animationRow('hit',direction),6);assert.equal(animationRow('defeat',direction),7);assert.equal(animationView(direction).flip,direction>=5?-1:1);}
});
