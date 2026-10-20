/** Technical sprite import: fixed grid extraction, alpha sanitation, nearest-neighbour
 * reduction and ground-anchor packing. Artwork is supplied by image_gen, not synthesized here. */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import sharp from 'sharp';

const [id,input,mirrorCell]=process.argv.slice(2);
if(!/^[a-z_]+$/.test(id||'')||!input)throw new Error('Usage: node scripts/pack-character-animation.mjs ID INPUT.png');
const original=await sharp(`public/pixel/champions/${id}.png`).extract({left:0,top:0,width:128,height:128}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
const raw=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
const {width,height}=raw.info;
// Segment complete alpha islands before assigning them to the declared grid.
// Poses may extend across a nominal cell boundary; a rectangular crop would
// silently cut boots, hands or wing tips off an otherwise complete drawing.
const seen=new Uint8Array(width*height),islands=Array.from({length:48},()=>[]);
for(let p=0;p<width*height;p++){
 if(seen[p]||raw.data[p*4+3]<128)continue;
 const queue=[p];seen[p]=1;let left=width,right=0,top=height,bottom=0;
 for(let n=0;n<queue.length;n++){const q=queue[n],x=q%width,y=Math.floor(q/width);left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y);
  for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const nx=x+dx,ny=y+dy,next=ny*width+nx;if(nx<0||nx>=width||ny<0||ny>=height||seen[next]||raw.data[next*4+3]<128)continue;seen[next]=1;queue.push(next)}
 }
 const column=Math.min(5,Math.floor((left+right)/2/width*6)),row=Math.min(7,Math.floor((top+bottom)/2/height*8));
 islands[row*6+column].push({pixels:queue,left,right,top,bottom});
}
function bounds(data,w,h){let left=w,top=h,right=-1,bottom=-1;for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(data[(y*w+x)*4+3]>=128){left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y)}return {left,top,right,bottom,width:right-left+1,height:bottom-top+1};}
const frames=[];
for(let row=0;row<8;row++)for(let column=0;column<6;column++){
  const candidates=islands[row*6+column],largest=Math.max(0,...candidates.map(g=>g.pixels.length));
  if(largest<500)throw new Error(`${id}: missing body in ${row},${column}`);
  const groups=candidates.filter(g=>g.pixels.length>=Math.max(6,largest*.003));
  const left=Math.min(...groups.map(g=>g.left)),right=Math.max(...groups.map(g=>g.right)),top=Math.min(...groups.map(g=>g.top)),bottom=Math.max(...groups.map(g=>g.bottom));
  if(right-left>width/6*1.25||bottom-top>height/8*1.3)throw new Error(`${id}: connected poses in ${row},${column}; redraw required`);
  const cw=right-left+3,ch=bottom-top+3,data=Buffer.alloc(cw*ch*4);
  for(const g of groups)for(const p of g.pixels){const x=p%width-left+1,y=Math.floor(p/width)-top+1;raw.data.copy(data,(y*cw+x)*4,p*4,p*4+3);data[(y*cw+x)*4+3]=255;}
  const box=bounds(data,cw,ch);frames.push({row,column,data,box,cw,ch,sourceBounds:[left,top,right-left+1,bottom-top+1],touchesSourceEdge:left===0||top===0||right===width-1||bottom===height-1});
}
const standing=frames.slice(0,18).map(f=>f.box.height).sort((a,b)=>a-b);
const targetHeight=bounds(original.data,128,128).height;
// One scale per character: crouches and fallen poses keep their actual proportions.
const factor=Math.min(targetHeight/standing[Math.floor(standing.length*.65)],108/Math.max(...frames.map(f=>f.box.width)));
const packed=[],audit=[];
for(const frame of frames){
  const {box,data,row,column,cw,ch}=frame;const w=Math.max(1,Math.round(box.width*factor)),h=Math.max(1,Math.round(box.height*factor));
  let footSum=0,footCount=0;const footBand=Math.max(2,Math.round(box.height*.08));
  for(let y=box.bottom-footBand+1;y<=box.bottom;y++)for(let x=box.left;x<=box.right;x++)if(data[(y*cw+x)*4+3]){footSum+=x;footCount++}
  const footX=footCount?footSum/footCount:(box.left+box.right)/2;
  const anchor=row===7&&column>=2?(box.left+box.right)/2:footX;
  const mirrored=mirrorCell===`${row},${column}`;
  const localAnchor=mirrored?box.width-1-(anchor-box.left):anchor-box.left;
  const left=Math.max(2,Math.min(126-w,Math.round(64-localAnchor*factor))),top=104-h;
  if(top<1)throw new Error(`${id}: frame above headroom`);
  let importFrame=sharp(data,{raw:{width:cw,height:ch,channels:4}}).extract({left:box.left,top:box.top,width:box.width,height:box.height});
  if(mirrored)importFrame=importFrame.flop();
  const pixels=await importFrame.resize(w,h,{kernel:'nearest'}).png().toBuffer();
  packed.push({input:pixels,left:column*128+left,top:row*128+top});
  audit.push({row,column,anchor:[64,104],bounds:[left,top,w,h],sourceBounds:frame.sourceBounds,sourceCell:[cw,ch],touchesSourceEdge:frame.touchesSourceEdge,mirrored,sha256:crypto.createHash('sha256').update(pixels).digest('hex')});
}
await fs.mkdir('public/pixel/animations',{recursive:true});
const output=`public/pixel/animations/${id}.webp`;
await sharp({create:{width:768,height:1024,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(packed).webp({lossless:true}).toFile(output);
const record={id,source:path.resolve(input),sourceSha256:crypto.createHash('sha256').update(await fs.readFile(input)).digest('hex'),asset:`/pixel/animations/${id}.webp`,grid:[6,8],cell:128,sourceSize:[width,height],segmentation:'complete-alpha-islands',scale:factor,originalStandingHeight:targetHeight,frames:audit};
await fs.mkdir('docs/animation-assets',{recursive:true});await fs.writeFile(`docs/animation-assets/${id}.json`,JSON.stringify(record,null,2)+'\n');
const ids=(await fs.readdir('docs/animation-assets')).filter(n=>n.endsWith('.json')).map(n=>n.slice(0,-5)).sort();
await fs.writeFile('lib/animation-assets.ts',`/** Verified packed animation atlases. Generated by scripts/pack-character-animation.mjs. */\nexport const ANIMATED_CHARACTER_IDS:readonly string[]=${JSON.stringify(ids)};\n`);
console.log(JSON.stringify({id,output,bytes:(await fs.stat(output)).size,frames:48,unique:new Set(audit.map(f=>f.sha256)).size,scale:factor}));
