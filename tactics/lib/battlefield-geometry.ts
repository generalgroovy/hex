/** Shared screen geometry. Atlas artwork remains 192px; only its ground grows. */
export type HexPoint = {q:number;r:number};
export type ScreenPoint = {x:number;y:number};
export type ViewSize = {width:number;height:number};
export type BattlefieldBounds = {left:number;right:number;top:number;bottom:number};
export const TILE_SCALE = 2;
export const TILE_HALF_WIDTH = 44*TILE_SCALE;
export const TILE_HALF_HEIGHT = 30*TILE_SCALE;
export const TILE_STEP_X = TILE_HALF_WIDTH*2;
export const TILE_STEP_Y = TILE_HALF_HEIGHT*1.5;
export const ELEVATION_STEP = 24*TILE_SCALE;
export const SPRITE_SIZE = 192;
export const SPRITE_FOOT = {x:64,y:104};
export const FOCUS_HEX_PIXELS = 120;

export function groundPoint(point:HexPoint):ScreenPoint {
  return {x:450+TILE_STEP_X*(point.q+point.r/2),y:318+TILE_STEP_Y*point.r};
}
export function surfacePoint(point:HexPoint,height=0):ScreenPoint {
  const at=groundPoint(point);
  return {x:at.x,y:at.y-height*ELEVATION_STEP};
}
export function battlefieldBounds(cells:(HexPoint&{height?:number})[]):BattlefieldBounds {
  const terrain=cells.length?cells:[{q:0,r:0}];
  const points=terrain.map(cell=>surfacePoint(cell,cell.height));
  return {left:Math.min(...points.map(at=>at.x))-TILE_HALF_WIDTH-20,right:Math.max(...points.map(at=>at.x))+TILE_HALF_WIDTH+20,top:Math.min(...points.map(at=>at.y))-SPRITE_SIZE*.8125-16,bottom:Math.max(...terrain.map(cell=>groundPoint(cell).y))+TILE_HALF_HEIGHT+32};
}
/** Exact pointy hex target, with the same proportions as the stepped pixel edge. */
export function hexPolygon(x:number,y:number,inset=4):string {
  const width=TILE_HALF_WIDTH-inset,height=TILE_HALF_HEIGHT-inset;
  return `${x} ${y-height},${x+width} ${y-height/2},${x+width} ${y+height/2},${x} ${y+height},${x-width} ${y+height/2},${x-width} ${y-height/2}`;
}
export function focusViewSize(viewport:ViewSize,scale=1):ViewSize {
  const ratio=TILE_STEP_X/FOCUS_HEX_PIXELS*scale;
  return {width:Math.max(1,viewport.width)*ratio,height:Math.max(1,viewport.height)*ratio};
}
export function clampCamera(at:ScreenPoint,bounds:BattlefieldBounds,view:ViewSize):ScreenPoint {
  const clampAxis=(value:number,min:number,max:number,extent:number)=>extent>=max-min?(min+max)/2:Math.max(min+extent/2,Math.min(max-extent/2,value));
  return {x:clampAxis(at.x,bounds.left,bounds.right,view.width),y:clampAxis(at.y,bounds.top,bounds.bottom,view.height)};
}
/** Include complete tile edges and enough headroom for a champion in the effect. */
export function fitEffect(points:ScreenPoint[],viewport:ViewSize):{center:ScreenPoint;scale:number} {
  if(!points.length)return {center:groundPoint({q:0,r:0}),scale:1};
  const left=Math.min(...points.map(at=>at.x))-TILE_HALF_WIDTH-20,right=Math.max(...points.map(at=>at.x))+TILE_HALF_WIDTH+20;
  const top=Math.min(...points.map(at=>at.y))-130,bottom=Math.max(...points.map(at=>at.y))+TILE_HALF_HEIGHT+20;
  const base=focusViewSize(viewport);
  return {center:{x:(left+right)/2,y:(top+bottom)/2},scale:Math.max(1,(right-left)/base.width,(bottom-top)/base.height)};
}
