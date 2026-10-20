import type {ElementKind, ElementPalette} from './element-presentation.ts';

/** Tiny, authored material cels. Geometry changes on a two-unit pixel grid;
 * playback never stretches a finished drawing to pretend that it is a new cel. */
export type EffectCel = Readonly<{paths:readonly string[]; pixelCount:number; bounds:readonly [number,number,number,number]}>;
export const EFFECT_SHADES = ['ink','shadow','main','bright','light','spark'] as const satisfies readonly (keyof ElementPalette)[];
export const PROJECTILE_CEL_MS = 120;
export const IMPACT_CEL_ENDS = [80,200,400,650,950,1200] as const;
export const EFFECT_MATERIALS = ['fire','water','earth','air','light','dark','lightning','ice','metal','storm','radiance','void'] as const satisfies readonly ElementKind[];
type Point = readonly [number,number];

/** Pixel pen used at module initialization only; each cel is then six batched
 * SVG paths, rather than hundreds of React rectangles or a canvas timer. */
class PixelPen {
  pixels=new Map<string,number>();
  dot(x:number,y:number,color:number){this.pixels.set(`${Math.round(x)},${Math.round(y)}`,color)}
  rect(x:number,y:number,w:number,h:number,color:number){for(let row=0;row<h;row++)for(let col=0;col<w;col++)this.dot(x+col,y+row,color)}
  line(a:Point,b:Point,color:number,width=1){let [x,y]=a;const dx=Math.abs(b[0]-x),sx=x<b[0]?1:-1,dy=-Math.abs(b[1]-y),sy=y<b[1]?1:-1;let error=dx+dy;for(;;){this.rect(x,y,width,width,color);if(x===b[0]&&y===b[1])break;const twice=error*2;if(twice>=dy){error+=dy;x+=sx}if(twice<=dx){error+=dx;y+=sy}}}
  polygon(points:readonly Point[],color:number){const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);for(let y=Math.min(...ys);y<=Math.max(...ys);y++)for(let x=Math.min(...xs);x<=Math.max(...xs);x++){let inside=false;for(let i=0,j=points.length-1;i<points.length;j=i++){const a=points[i],b=points[j];if((a[1]>y)!==(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])inside=!inside}if(inside)this.dot(x,y,color)}}
  path(points:readonly Point[],color:number,width=1){for(let i=1;i<points.length;i++)this.line(points[i-1],points[i],color,width)}
  diamond(x:number,y:number,w:number,h:number,color:number){this.polygon([[x,y-h],[x+w,y],[x,y+h],[x-w,y]],color)}
  ring(x:number,y:number,rx:number,ry:number,color:number){this.path([[x-rx,y],[x-Math.round(rx*.55),y-ry],[x+Math.round(rx*.55),y-ry],[x+rx,y],[x+Math.round(rx*.55),y+ry],[x-Math.round(rx*.55),y+ry],[x-rx,y]],color)}
  finish():EffectCel {
    const drawing=new Map(this.pixels);
    for(const key of drawing.keys()){const [x,y]=key.split(',').map(Number);for(const [dx,dy]of[[0,-1],[1,0],[0,1],[-1,0]])if(!drawing.has(`${x+dx},${y+dy}`))this.pixels.set(`${x+dx},${y+dy}`,1)}
    // A few grounded ink pixels supply value separation without a thick halo.
    for(const key of drawing.keys()){const [x,y]=key.split(',').map(Number);if(!drawing.has(`${x},${y+1}`)&&!drawing.has(`${x},${y+2}`))this.pixels.set(`${x},${y+1}`,0)}
    const entries=[...this.pixels].map(([key,color])=>{const [x,y]=key.split(',').map(Number);return {x,y,color}}),paths=EFFECT_SHADES.map((_,color)=>{
      const rows=new Map<number,number[]>();for(const p of entries)if(p.color===color){const row=rows.get(p.y)||[];row.push(p.x);rows.set(p.y,row)}
      let path='';for(const [y,xs]of [...rows].sort((a,b)=>a[0]-b[0])){xs.sort((a,b)=>a-b);for(let i=0;i<xs.length;i++){const start=xs[i];let end=start;while(xs[i+1]===end+1){i++;end++}const width=(end-start+1)*2;path+=`M${start*2} ${y*2}h${width}v2h-${width}Z`}}return path;
    });
    return Object.freeze({paths:Object.freeze(paths),pixelCount:entries.length,bounds:Object.freeze([Math.min(...entries.map(p=>p.x))*2,Math.min(...entries.map(p=>p.y))*2,(Math.max(...entries.map(p=>p.x))+1)*2,(Math.max(...entries.map(p=>p.y))+1)*2]) as readonly [number,number,number,number]});
  }
}

function projectile(kind:ElementKind,f:number):EffectCel {
  const p=new PixelPen(),tip=[-1,1,0,-2][f],glint=[0,2,1,-1][f];
  switch(kind){
    case 'fire':
      p.polygon([[-6,5],[-7,0],[-4,-4],[-3,-10+tip],[0,-6],[2,-12-tip],[3,-3],[6,-6],[7,2],[4,7],[-3,7]],3);
      p.polygon([[-3,5],[-3,-1],[0,-6-tip],[1,0],[4,2],[2,6]],4);p.polygon([[-1,5],[0,-1],[2,3],[1,6]],5);p.rect(-7+f,-11,1,2,4);break;
    case 'water':
      p.polygon([[tip,-10],[3,-5],[6,-1],[7,4],[4,7],[-2,8],[-6,4],[-7,0],[-3,-4]],3);
      p.polygon([[-4,-1],[-1,-5],[0,-2],[-2,1],[-2,4],[-4,4]],5);p.path([[0,6],[4,4],[5,1]],4);p.rect(7,-5+f,2,2,4);break;
    case 'earth':
      p.polygon([[-7,-3],[-3,-7],[4,-6],[8,-1],[6,5],[0,8],[-6,4]],2);
      p.polygon([[-6,-3],[-2,-6],[3,-5],[1,-1],[-4,0]],4);p.polygon([[2,0],[6,-1],[5,4],[0,6]],3);p.path([[-3,1],[-1,3],[1,2]],1);p.rect(-3+glint,-4,2,1,5);p.rect([-9,9,7,-8][f],[-4,-3,8,7][f],2,2,3);break;
    case 'air':
      p.path([[-8,4],[2+tip,4],[7,1],[7,-4],[3,-6],[-1,-5],[-2,-2],[1,0],[4,-1]],4,2);
      p.path([[-7,-5],[-3,-8],[5,-8]],3);p.path([[-4,8],[5,8],[8,6]],5);p.diamond(-7+f,0,2,1,3);break;
    case 'light':
      p.polygon([[0,-10],[2,-3],[8,0],[2,3],[0,9],[-2,3],[-8,0],[-2,-3]],4);
      p.path([[0,-6],[0,6]],5);p.line([-4,0],[4,0],5);p.rect([-7,6,7,-6][f],[-6,-7,6,7][f],2,2,3);break;
    case 'dark':
      p.polygon([[-6,-6],[0,-8],[6,-5],[8,1],[4,7],[-3,8],[-7,3],[-8,-2]],2);
      p.path([[3+tip,-5],[-2,-5],[-5,-2],[-4,3],[0,5],[4,3],[4,0],[1,-2],[-1,0]],4,2);p.rect(0,0,2,2,1);p.rect(-9+f,5-f,1,2,5);break;
    case 'lightning':
      p.polygon([[1+tip,-11],[-5,-1],[0,-1],[-2,9],[7,-4],[2,-4],[4,-11]],4);
      p.path([[1,-7],[-1,-2],[3,-2],[0,4]],5);p.path([[-7,-6],[-9,-2],[-6,-2]],3);p.path([[8,2],[5,6],[8,6]],4);break;
    case 'ice':
      p.polygon([[0,-12],[5,-3],[5,4],[0,9],[-5,4],[-5,-3]],3);
      p.polygon([[0,-10],[0,6],[-3,3],[-3,-2]],5);p.polygon([[1,-6],[4,-2],[3,3],[1,5]],4);p.rect(-8,-3+glint,2,2,4);p.rect(7,4-glint,1,2,5);break;
    case 'metal':
      p.polygon([[0,-9],[6,-4],[6,4],[0,8],[-6,4],[-6,-4]],3);
      p.polygon([[-5,-3],[0,-7],[4,-4],[0,-1]],4);p.polygon([[0,0],[5,-3],[5,3],[0,6]],2);p.line([0,-7],[0,6],5);p.line([-4,-3+glint],[-1,-5+glint],5);p.rect(-8,6-f,1,2,4);break;
    case 'storm':
      p.path([[-7,-9],[5,-9],[8,-6],[4,-3],[-5,-3],[-7,0],[-3,3],[4,3],[1,7]],3,3);
      p.path([[-6,-8],[5,-8],[6,-6],[2,-4],[-4,-4]],5);p.path([[-5,0],[-2,2],[4,2],[1,7]],4);p.rect([-9,8,-8,7][f],[-3,3,4,-8][f],2,2,4);break;
    case 'radiance':
      p.ring(0,0,8,7,3);p.diamond(0,0,5,7,4);p.line([0,-4],[0,4],5);p.line([-3,0],[3,0],5);
      for(const [x,y]of [[-11,0],[10,0],[0,-11],[0,10]]as Point[])p.rect(x+(y?tip:0),y+(x?tip:0),2,2,4);break;
    case 'void':
      p.polygon([[-4,-8],[4,-8],[8,-4],[8,4],[4,8],[-4,8],[-8,4],[-8,-4]],2);
      p.ring(0,0,7,5,4);p.polygon([[-3,-4],[3,-4],[4,-2],[4,2],[2,4],[-2,4],[-4,2],[-4,-2]],0);p.rect(-1,-2,2,3,1);
      p.rect([-11,9,6,-7][f],[-3,2,-10,9][f],2,2,5);break;
  }
  return p.finish();
}

function impact(kind:ElementKind,f:number):EffectCel {
  const p=new PixelPen(),h=[6,15,22,17,10,4][f],w=[4,10,16,18,17,13][f],lift=[0,0,-1,-3,-6,-8][f];
  // Each material has its own break-up choreography; these are drawing poses,
  // not an animated transform applied to one generic blast.
  switch(kind){
    case 'fire':{
      const tips=[[-3,-8,-5],[-13,-23,-16],[-19,-29,-23],[-13,-25,-19],[-7,-17,-12],[-3,-10,-6]][f];
      if(f<5){p.polygon([[-w,7],[-w,0],[-w+3,tips[0]],[-6,-3],[-3,tips[1]],[2,-9],[7,tips[2]],[10,-2],[w,-8],[w,6]],3);p.polygon([[-7,7],[-7,-2],[-3,-h],[1,-5],[4,-h+6],[7,4],[4,8]],4);p.polygon([[-2,7],[-2,-h+9],[2,-4],[3,7]],5)}
      [[-w-2,-h],[w,-h-5],[-4,-h-9],[7,-h-2]].forEach(([x,y],i)=>p.rect(x,y+lift,(i%2)+1,2,f>3?3:4));p.path([[-w,10],[-w+5,10],[-w+7,8]],2);p.line([w-6,9],[w,9],4);break;
    }
    case 'water':{
      p.ring(0,6,w+3,Math.max(2,Math.round(w/3)),3);p.path([[-w,6],[-w+3,2],[w-4,2],[w,5]],4);
      if(f<4){p.polygon([[-w,5],[-w,-h+5],[-w+2,-h+3],[-w+4,-3],[-5,-5],[-3,-h-4],[0,-h-6],[2,-4],[8,-4],[w-1,-h+2],[w+1,-h+5],[w,6]],3);p.path([[-w+1,-h+5],[-w+2,0],[-6,3],[-2,2],[0,-h+1]],5);p.line([3,5],[w-2,2],4)}
      for(const [x,y]of [[-w-2,-h-3],[w,-h-7],[-3,-h-11],[8,-h-5]])p.rect(x,y+(f>3?f*3:0),2,3,4);break;
    }
    case 'earth':{
      const rise=[0,3,10,7,3,0][f],size=[3,5,7,6,4,3][f];
      for(const [x,top,s]of [[-12,-rise+1,size-1],[0,-rise-8,size],[13,-rise+3,size-2]]){p.polygon([[x-s,top+3],[x-2,top],[x+s-1,top+1],[x+s,top+s],[x+2,top+s*2],[x-s+1,top+s*2-1]],2);p.polygon([[x-s+1,top+3],[x-2,top+1],[x+s-2,top+2],[x,top+5]],4);p.polygon([[x+1,top+5],[x+s-1,top+s],[x+1,top+s*2-1],[x-1,top+s]],3)}
      p.path([[-w-3,9],[-10,7],[-4,11],[3,8],[9,11],[w+2,9]],3);p.path([[-6,8],[-3,4],[1,6],[7,3]],1);p.rect(-w,-h+2,3,2,3);p.rect(w-2,-h-4,2,3,4);break;
    }
    case 'air':{
      const flow=[-5,-2,0,3,6,9][f],curl=[4,7,11,9,5,2][f];
      p.path([[-15+flow,5],[8+flow,5],[14+flow,1],[14+flow,-curl+3],[9+flow,-curl],[1+flow,-curl],[-2+flow,-curl+3],[1+flow,-curl+6],[7+flow,-curl+6]],4,2);
      p.path([[-18+flow,-5],[-8+flow,-curl-7],[6+flow,-curl-7],[12+flow,-curl-4]],3);p.path([[-9+flow,12],[10+flow,12],[17+flow,8]],5);
      p.diamond(-14+flow,-h+2,3,2,3);p.diamond(11+flow,-3+f,3,1,3);break;
    }
    case 'light':{
      p.diamond(0,-4,Math.max(2,w-5),h+3,4);p.diamond(0,-4,Math.max(1,w-9),Math.max(2,h-2),5);
      p.line([-w-3,-4],[-w+1,-4],4);p.line([w-1,-4],[w+3,-4],4);p.rect(-w,-h,2,2,5);p.rect(w,-h,2,2,5);p.rect(-w+3,h-3,1,2,3);p.rect(w-3,h-3,1,2,3);break;
    }
    case 'dark':{
      const r=[18,17,14,11,7,3][f];p.ring(0,-3,r,Math.max(2,r-3),3);p.path([[r-3,-3],[r-3,-10],[3,-15],[-5,-11],[-7,-3],[-3,3],[4,2],[5,-4],[0,-6]],4,2);p.diamond(0,-3,3,5,0);
      p.rect(-r-4,-h,2,3,3);p.rect(r+2,3,3,2,4);p.rect(5,-h-6,2,2,5);break;
    }
    case 'lightning':{
      const fork=[-1,1,-2,2,0,1][f];p.polygon([[3,-h-12],[-10+fork,-4],[-2,-4],[-6,12],[11,-10],[3,-10],[7,-h-12]],4);p.path([[3,-h-7],[-5+fork,-2],[2,-2],[-3,7]],5,2);
      if(f<4){p.path([[-w,-15],[-w-4,-7],[-w+1,-7],[-w-3,0]],3,2);p.path([[w,-18],[w-4,-9],[w+1,-9],[w-2,-3]],4)}p.path([[-w,10],[-w+5,7],[-6,10]],3);p.line([7,10],[w+3,6],4);break;
    }
    case 'ice':{
      const tops=[-h+3,-h-7,-h-1];for(const [i,x]of [-12,0,12].entries()){const top=tops[i],wide=i===1?5:4;p.polygon([[x,top],[x+wide,top+9],[x+wide,8],[x,12],[x-wide,7],[x-wide,top+9]],3);p.polygon([[x,top+2],[x,9],[x-wide+1,6],[x-wide+1,top+9]],5);p.line([x+1,top+10],[x+wide-1,top+13],4)}
      if(f>2){p.rect(-w-2,-h-6,2,3,4);p.rect(w+1,-h,2,2,5)}p.path([[-w,12],[-7,12],[-3,15],[6,13],[w,14]],4);break;
    }
    case 'metal':{
      for(const [x,top,width]of [[-13,-h+7,4],[0,-h-8,5],[13,-h+4,4]]){p.polygon([[x-width,10],[x-width,top+6],[x,top],[x+width,top+6],[x+width,10]],2);p.polygon([[x-width+1,top+6],[x,top+2],[x,9],[x-width+1,8]],4);p.line([x,top+2],[x,8],5);p.line([x+1,top+7],[x+width-1,top+9],3)}
      p.path([[-w-4,11],[-w,8],[-w+4,11]],3);p.line([w-4,11],[w+3,8],4);p.rect(-w-2,-h,2,1,5);p.rect(w+1,-h-6,1,2,5);break;
    }
    case 'storm':{
      const sway=[-1,1,-2,2,0,-1][f];p.path([[-w,-h],[w-3,-h],[w+2,-h+4],[w-4,-h+8],[-w+3,-h+8],[-w,-h+12],[-w+5,-h+16],[w-6,-h+16],[3+sway,8],[-2+sway,11]],3,3);
      p.path([[-w+1,-h],[w-3,-h],[w,-h+3],[w-5,-h+6]],5);p.path([[-w+4,-h+10],[-w+2,-h+12],[-w+5,-h+14],[w-6,-h+14],[3+sway,8]],4);
      p.rect(-w-5,-h+8,2,2,4);p.rect(w+3,-h-3,2,2,3);p.rect(w,-h+12,2,1,5);break;
    }
    case 'radiance':{
      p.ring(0,-4,Math.max(3,w),Math.max(2,h-4),3);p.diamond(0,-4,Math.max(2,w-6),Math.max(3,h-4),4);p.diamond(0,-4,Math.max(1,w-10),Math.max(2,h-8),5);
      const rays:Point[]=[[-w-5,-4],[w+4,-4],[0,-h-8],[0,h+2],[-w,-h],[w,-h],[-w,h-5],[w,h-5]];for(const [i,[x,y]]of rays.entries())p.rect(x,y,i<2?3:2,i<2?2:3,f===2?5:4);break;
    }
    case 'void':{
      const r=[7,13,18,14,9,4][f];p.polygon([[-r+4,-r-3],[r-4,-r-3],[r,-r+1],[r,r-7],[r-4,r-3],[-r+4,r-3],[-r,r-7],[-r,-r+1]],2);p.ring(0,-3,r-1,Math.max(2,r-4),4);p.polygon([[-r+6,-r+1],[r-6,-r+1],[r-4,-r+3],[r-4,r-9],[r-6,r-7],[-r+6,r-7],[-r+4,r-9],[-r+4,-r+3]],0);
      p.rect(-r-5,-8,3,2,4);p.rect(r+3,2,2,3,5);p.rect(-3,-r-9,2,2,3);p.rect(3,r+1,2,2,4);break;
    }
  }
  return p.finish();
}

export const ELEMENT_EFFECT_FRAMES:Readonly<Record<ElementKind,Readonly<{projectile:readonly EffectCel[];impact:readonly EffectCel[]}>>> = Object.freeze(Object.fromEntries(EFFECT_MATERIALS.map(kind=>[kind,Object.freeze({projectile:Object.freeze(Array.from({length:4},(_,f)=>projectile(kind,f))),impact:Object.freeze(Array.from({length:6},(_,f)=>impact(kind,f)))})])) as Record<ElementKind,{projectile:readonly EffectCel[];impact:readonly EffectCel[]}>);

function cloud(p:PixelPen,x:number,y:number,r:number,shade:number){
  p.polygon([[x-r,y+3],[x-r,y-2],[x-r+3,y-2],[x-r+3,y-6],[x-2,y-6],[x-2,y-9],[x+3,y-9],[x+3,y-5],[x+r-2,y-5],[x+r-2,y-1],[x+r+2,y-1],[x+r+2,y+4],[x+4,y+4],[x+4,y+7],[x-5,y+7],[x-5,y+4]],shade);
  p.path([[x-r+4,y-3],[x-r+4,y-5],[x-1,y-5],[x-1,y-7],[x+2,y-7]],5);p.line([x-3,y+4],[x+3,y+4],3);
}
/** Reaction cels use steam's own warm-white / water-shadow ramp. Cloud lobes
 * are redrawn and separate as pressure disperses, rather than scaled blobs. */
export const STEAM_EFFECT_FRAMES:readonly EffectCel[]=Object.freeze(Array.from({length:6},(_,f)=>{
  const p=new PixelPen(),spread=[2,8,14,19,22,25][f],rise=[3,0,-4,-8,-11,-15][f];
  if(f<5)cloud(p,0,rise-5,[5,9,12,11,9,6][f],4);
  cloud(p,-spread,rise+2,[4,8,10,10,8,5][f],4);cloud(p,spread,rise,[4,7,10,10,7,4][f],3);
  if(f>2){p.rect(-5,rise-16,2,2,4);p.rect(12,rise-10,2,2,5)}
  return p.finish();
}));
export const STEAM_EFFECT_PALETTE:ElementPalette=Object.freeze({ink:'#37554f',shadow:'#718e83',main:'#9eb6a8',bright:'#b9cebd',light:'#dfebd4',spark:'#fff5dd'});

export const FIELD_FLAME_FRAMES:readonly EffectCel[]=Object.freeze(Array.from({length:4},(_,f)=>{
  const p=new PixelPen(),tips=[[-5,-9,-4],[-7,-11,-5],[-4,-10,-7],[-6,-8,-6]][f];
  p.polygon([[-3,0],[-4,-3],[-2,tips[0]],[-1,-4],[1,tips[1]],[2,-4],[4,tips[2]],[4,-1],[2,1],[-2,1]],3);
  p.polygon([[-1,0],[-1,-3],[1,-6],[1,-2],[2,0]],5);return p.finish();
}));
export const FIELD_STEAM_FRAMES:readonly EffectCel[]=Object.freeze(Array.from({length:4},(_,f)=>{
  const p=new PixelPen();cloud(p,[0,1,1,0][f],[-1,-2,-3,-2][f],[5,6,5,4][f],4);return p.finish();
}));

/** Same frame schedule is used by CSS and contact sheets. Boundaries have no
 * cross-fade: exactly one complete cel is visible, including reduced motion. */
export function impactCelAt(elapsedMs:number):number|null {
  if(elapsedMs<0||elapsedMs>=IMPACT_CEL_ENDS.at(-1)!)return null;
  return IMPACT_CEL_ENDS.findIndex(end=>elapsedMs<end);
}
export function effectFrameKeyframes():string {
  const loop=Array.from({length:4},(_,i)=>`@keyframes px16-projectile-cel-${i}{0%{opacity:${i===0?1:0}}${i?`${i*25}%{opacity:1}`:''}${(i+1)*25}%{opacity:0}100%{opacity:0}}`).join('');
  const impacts=IMPACT_CEL_ENDS.map((end,i)=>{const start=i?IMPACT_CEL_ENDS[i-1]:0;return `@keyframes px16-impact-cel-${i}{0%{opacity:${i===0?1:0}}${start?`${start/12}%{opacity:1}`:''}${end/12}%{opacity:0}100%{opacity:0}}`}).join('');
  return loop+impacts;
}
