import {ANIMATION_GRID} from './character-animation.ts';

export type SpriteEdgeRepair=Readonly<{row:number;column:number;x:number;y:number}>;

/** Reviewed, disconnected dark edge remnants in the packed animation art.
 * These are not spell particles, eyes, highlights or holes inside a silhouette.
 * Masking exact source pixels keeps the original lossless artwork untouched. */
export const SPRITE_EDGE_REPAIRS:Readonly<Record<string,readonly SpriteEdgeRepair[]>>={
 jan_wicked:[{row:6,column:2,x:82,y:59}],
 oh_tipi:[{row:0,column:4,x:51,y:51},{row:2,column:3,x:62,y:41},{row:6,column:2,x:29,y:64}],
 oll_i:[{row:5,column:1,x:56,y:41}],
 red_baron:[{row:1,column:4,x:63,y:40}],
 spai_si:[{row:1,column:3,x:51,y:51}],
 treevor_mason:[{row:5,column:3,x:69,y:37},{row:6,column:1,x:51,y:41}],
};

export function animationAtlasDimensionsMatch(width:number,height:number){
 return width===ANIMATION_GRID.columns*ANIMATION_GRID.cell&&height===ANIMATION_GRID.rows*ANIMATION_GRID.cell;
}

export function spriteEdgeMaskSvg(id:string):string|undefined{
 const repairs=SPRITE_EDGE_REPAIRS[id];
 if(!repairs?.length)return undefined;
 const {columns,rows,cell}=ANIMATION_GRID,width=columns*cell,height=rows*cell;
 const holes=repairs.map(({row,column,x,y})=>`M${column*cell+x} ${row*cell+y}h1v1h-1Z`).join('');
 return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" shape-rendering="crispEdges"><path fill="white" fill-rule="evenodd" d="M0 0H${width}V${height}H0Z${holes}"/></svg>`;
}

const masks=new Map<string,string>();
export function spriteEdgeMask(id:string):string|undefined{
 const previous=masks.get(id);
 if(previous)return previous;
 const svg=spriteEdgeMaskSvg(id);
 if(!svg)return undefined;
 const mask=`url("data:image/svg+xml,${encodeURIComponent(svg)}")`;
 masks.set(id,mask);
 return mask;
}
