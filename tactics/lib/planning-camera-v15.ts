import {FOCUS_HEX_PIXELS,TILE_HALF_WIDTH,TILE_HALF_HEIGHT,fitEffect,focusViewSize,surfacePoint,type HexPoint,type ScreenPoint,type ViewSize} from './battlefield-geometry.ts';

export type PlanningCameraInput={
  viewport:ViewSize;
  origin:HexPoint;
  legalTargets:readonly HexPoint[];
  cells:readonly (HexPoint&{height?:number})[];
};

/** Frame the decision around a character, without shrinking phone targets into dots.
 * Large spell areas can still use the separate, unrestricted Fit spell command. */
export function planningCamera({viewport,origin,legalTargets,cells}:PlanningCameraInput):{center:ScreenPoint;scale:number} {
  const heights=new Map(cells.map(cell=>[`${cell.q},${cell.r}`,cell.height??0]));
  const position=(point:HexPoint)=>surfacePoint(point,heights.get(`${point.q},${point.r}`)??0);
  const at=position(origin),points=[at,...legalTargets.map(position)];
  const fitted=fitEffect(points,viewport);
  const minimumHexWidth=viewport.width<=850?44:64;
  const scale=Math.min(fitted.scale,FOCUS_HEX_PIXELS/minimumHexWidth);
  const view=focusViewSize(viewport,scale);
  // When a broad or one-sided range exceeds the readable frame, retain the
  // selected character and its headroom instead of centering on distant aims.
  const retain=(value:number,min:number,max:number)=>min<=max?Math.max(min,Math.min(max,value)):(min+max)/2;
  const center={
    x:retain(fitted.center.x,at.x+TILE_HALF_WIDTH+20-view.width/2,at.x-TILE_HALF_WIDTH-20+view.width/2),
    y:retain(fitted.center.y,at.y+TILE_HALF_HEIGHT+20-view.height/2,at.y-130+view.height/2),
  };
  return {center,scale};
}
