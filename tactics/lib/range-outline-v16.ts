import {surfacePoint,TILE_HALF_WIDTH,TILE_HALF_HEIGHT,type HexPoint,type ScreenPoint} from './battlefield-geometry.ts';

const adjacent=[{q:1,r:-1},{q:1,r:0},{q:0,r:1},{q:-1,r:1},{q:-1,r:0},{q:0,r:-1}] as const;
const key=(point:HexPoint)=>`${point.q},${point.r}`;
export type RangeEdge={cell:HexPoint;edge:number;from:ScreenPoint;to:ScreenPoint};

/** Draw only the outside of a legal region, including sight/terrain holes.
 * Shared edges disappear, so a large range reads as one shape rather than a
 * second grid. Elevation is taken from the same surface as the actual tiles. */
export function rangeBoundaryEdges(points:readonly HexPoint[],heightAt:(point:HexPoint)=>number=()=>0):RangeEdge[] {
  const unique=new Map(points.map(point=>[key(point),point])),edges:RangeEdge[]=[];
  const w=TILE_HALF_WIDTH,h=TILE_HALF_HEIGHT;
  const vertices=[{x:0,y:-h},{x:w,y:-h/2},{x:w,y:h/2},{x:0,y:h},{x:-w,y:h/2},{x:-w,y:-h/2}];
  for(const cell of unique.values()){
    const center=surfacePoint(cell,heightAt(cell));
    adjacent.forEach((offset,edge)=>{
      if(unique.has(key({q:cell.q+offset.q,r:cell.r+offset.r})))return;
      const a=vertices[edge],b=vertices[(edge+1)%6];
      edges.push({cell,edge,from:{x:center.x+a.x,y:center.y+a.y},to:{x:center.x+b.x,y:center.y+b.y}});
    });
  }
  return edges;
}

export function rangeBoundaryPath(points:readonly HexPoint[],heightAt?:(point:HexPoint)=>number):string {
  return rangeBoundaryEdges(points,heightAt).map(({from,to})=>`M${from.x} ${from.y}L${to.x} ${to.y}`).join('');
}
