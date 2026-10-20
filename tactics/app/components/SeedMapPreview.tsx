import {arenaSeed,generateArena} from '../../lib/arena';
import {TILE_HALF_HEIGHT,TILE_HALF_WIDTH,groundPoint,surfacePoint,hexPolygon} from '../../lib/battlefield-geometry';
import './seed-map-preview.css';

/** Uses exactly the same seeded cells and projection as the playable battlefield. */
export default function SeedMapPreview({mapId}:{mapId:string}) {
  const cells=generateArena(mapId).slice().sort((a,b)=>groundPoint(a).y-groundPoint(b).y||groundPoint(a).x-groundPoint(b).x);
  const points=cells.map(cell=>surfacePoint(cell,cell.height));
  const left=Math.min(...points.map(at=>at.x))-TILE_HALF_WIDTH,right=Math.max(...points.map(at=>at.x))+TILE_HALF_WIDTH;
  const top=Math.min(...points.map(at=>at.y))-TILE_HALF_HEIGHT,bottom=Math.max(...cells.map(cell=>groundPoint(cell).y))+TILE_HALF_HEIGHT+20;
  const seed=arenaSeed(mapId);
  return <svg className="px-seed-map" viewBox={`${left} ${top} ${right-left} ${bottom-top}`} role="img" aria-label={`Seed ${seed}: 127 hexes with raised Earth terraces, Water channels and three wells.`}>
    <title>{`${seed} · Wellspring Reach`}</title>
    {cells.map(cell=>{
      const at=surfacePoint(cell,cell.height),base=groundPoint(cell),depth=base.y+TILE_HALF_HEIGHT+20;
      const half=TILE_HALF_HEIGHT/2;
      return <g key={`${cell.q},${cell.r}`} className="px-seed-cell">
        <path d={`M${at.x-TILE_HALF_WIDTH} ${at.y+half}L${at.x} ${at.y+TILE_HALF_HEIGHT} ${at.x+TILE_HALF_WIDTH} ${at.y+half}V${depth-half}L${at.x} ${depth} ${at.x-TILE_HALF_WIDTH} ${depth-half}Z`} fill={cell.height?'#967341':'#9b8050'} stroke="#65512f" strokeWidth="2"/>
        <polygon points={hexPolygon(at.x,at.y,2)} fill={cell.terrain==='water'?'#79b6bd':cell.terrain==='earth'?'#c5ad78':'#8d9a52'} stroke="#4b502b" strokeWidth="3"/>
        {cell.terrain==='water'&&<path d={`M${at.x-30} ${at.y}h18v-6h22v6h20`} fill="none" stroke="#3e8297" strokeWidth="6"/>}
        {cell.height===1&&<path d={`M${at.x-22} ${at.y+7}v-13h17v-12h17v25Z`} fill="#ac915a" stroke="#776440" strokeWidth="3"/>}
        {cell.well&&<g className="px-seed-well"><circle cx={at.x} cy={at.y} r="24" fill="#f8e8b6" stroke="#554426" strokeWidth="5"/><circle cx={at.x} cy={at.y} r="12" fill="#267c89"/><path d={`M${at.x} ${at.y-37}v-8M${at.x} ${at.y+37}v8M${at.x-37} ${at.y}h-8M${at.x+37} ${at.y}h8`} stroke="#554426" strokeWidth="5"/></g>}
      </g>;
    })}
  </svg>;
}
