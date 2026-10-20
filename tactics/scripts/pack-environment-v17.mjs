/** Technical atlas import only: crop, alpha sanitation and nearest-neighbour
 * packing of artwork generated with the built-in image tool. */
import sharp from 'sharp';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';

const source=process.argv[2];
if(!source)throw new Error('Usage: node scripts/pack-environment-v17.mjs <generated-atlas.png>');
const root=process.cwd(),output=path.join(root,'public/pixel/environment');
await mkdir(output,{recursive:true});
const {data,info}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
if(info.width!==1254||info.height!==1254)throw new Error('The inspected input must be the 1254×1254 accepted atlas.');
const columns=[0,330,634,955,1254],rows=[0,331,642,957,1254];
const targetHeights=[118,118,84,66],sprites=[],audit=[];
for(let row=0;row<4;row++)for(let column=0;column<4;column++){
  const left=columns[column],top=rows[row],width=columns[column+1]-left,height=rows[row+1]-top;
  let minX=width,minY=height,maxX=-1,maxY=-1;
  for(let y=0;y<height;y++)for(let x=0;x<width;x++)if(data[((top+y)*info.width+left+x)*4+3]>=160){minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y)}
  if(maxX<0)throw new Error(`Empty cell ${row},${column}`);
  const cropWidth=maxX-minX+1,cropHeight=maxY-minY+1;
  const raw=await sharp(source).extract({left:left+minX,top:top+minY,width:cropWidth,height:cropHeight}).ensureAlpha().raw().toBuffer();
  for(let index=3;index<raw.length;index+=4){raw[index]=raw[index]>=160?255:0;if(!raw[index])raw.fill(0,index-3,index)}
  const scale=Math.min(targetHeights[column]/cropHeight,120/cropWidth),w=Math.max(1,Math.round(cropWidth*scale)),h=Math.max(1,Math.round(cropHeight*scale));
  const resized=await sharp(raw,{raw:{width:cropWidth,height:cropHeight,channels:4}}).resize(w,h,{kernel:'nearest'}).raw().toBuffer();
  // Nearest-neighbour sampling can drop a one-source-pixel fringe. Align the
  // actual final opaque feet, not the pre-sampling rectangle.
  let l=w,t=h,r=-1,b=-1;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(resized[(y*w+x)*4+3]){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y)}
  const finalWidth=r-l+1,finalHeight=b-t+1;
  const png=await sharp(resized,{raw:{width:w,height:h,channels:4}}).extract({left:l,top:t,width:finalWidth,height:finalHeight}).png().toBuffer();
  sprites.push({input:png,left:column*128+Math.floor((128-finalWidth)/2),top:row*128+124-finalHeight});
  audit.push({row,column,bounds:[Math.floor((128-finalWidth)/2),124-finalHeight,finalWidth,finalHeight],sourceBounds:[left+minX,top+minY,cropWidth,cropHeight],hash:createHash('sha256').update(png).digest('hex')});
}
const packed=await sharp({create:{width:512,height:512,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(sprites).webp({lossless:true}).toBuffer();
await writeFile(path.join(output,'reactive-props-v17.webp'),packed);
// The accepted original surface art has a 4×4 grid; preserve square pixel scale.
await sharp(path.join(output,'wellspring-surfaces-crafted.webp')).resize(512,512,{kernel:'nearest'}).webp({lossless:true}).toFile(path.join(output,'wellspring-surfaces-pixel-v17.webp'));
await mkdir(path.join(root,'docs/environment'),{recursive:true});
await writeFile(path.join(root,'docs/environment/reactive-props-v17-audit.json'),JSON.stringify({source,sourceSha256:createHash('sha256').update(await readFile(source)).digest('hex'),sha256:createHash('sha256').update(packed).digest('hex'),width:512,height:512,cell:128,foot:124,frames:audit},null,2)+'\n');
console.log(`Packed 16 reactive environment sprites (${packed.length} bytes) and crisp ground atlas.`);
