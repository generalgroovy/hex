import type {CSSProperties} from 'react';
import {fieldCombination,type SimCell} from '../../lib/tactics-v16';
import {terrainMaterial,type TerrainEdge,type TerrainMaterial} from '../../lib/reactive-environment-v17';
import {ELEMENT_PALETTES} from '../../lib/element-presentation';
import './reactive-terrain-v17.css';

/** Ground markings have the same two-unit pixel cadence as elemental cels.
 * These are material features, never unexplained movement of trees or rocks. */
export function TerrainMaterialArt({cell,edges=[],change=null,animate=false}:{cell:SimCell;edges?:readonly TerrainEdge[];change?:TerrainMaterial|null;animate?:boolean}) {
  const material=terrainMaterial(cell),compound=fieldCombination(cell);
  const stagger=Math.abs(cell.q*31+cell.r*17)%4;
  return <g className={`px17-terrain-art is-${material}${animate?' is-live':''}`} data-terrain-material={material} data-terrain-transition={change??undefined} shapeRendering="crispEdges" pointerEvents="none" style={{'--terrain-step':`${stagger*-180}ms`} as CSSProperties}>
    {edges.map(edge=><g key={edge.edge} data-terrain-edge={edge.kind} className={`px17-bank is-${edge.kind}`}><path d={edge.path}/><path d={edge.path} className="px17-bank-light"/></g>)}
    {material==='scorched'&&<g><path d="M-34-6h14v-6h14v4H10v-5h16v8h12V7H22v7H4v5H-8v-5H-29V7h-9Z" fill="#3e382e" fillOpacity=".76"/><path d="M-28 0h12v6h10v-8H4v-5H20M-10 11H8v-5h17" fill="none" stroke="#7a3d26" strokeWidth="4"/><path className="px17-ember-seam" d="M-23-1h9v6M-2-3h5M7 9h13v-3" fill="none" stroke={ELEMENT_PALETTES.fire.light} strokeWidth="2"/></g>}
    {material==='frozen'&&<g><path d="M-42-14-1-28 42-14V13L1 28-42 13Z" fill="#73b3c3" fillOpacity=".34"/><path d="M-35-10h9v4h12V0H-4v7H12v6H28M-4 0V-8H8v-8h11M12 7v-7h16v-6" fill="none" stroke="#356a86" strokeWidth="2"/><path d="M-34-15h11M-12-21H0M21 9H34M-28 8h10v4h7" fill="none" stroke="#e2f3e8" strokeWidth="2"/></g>}
    {material==='flooded'&&<g><path d="M-42-14-1-28 42-14V13L1 28-42 13Z" fill="#176a95" fillOpacity=".38"/><path className="px17-liquid-line" d="M-34-5h13v-3H-6M7 12h16v-3h10M4-16h12" fill="none" stroke="#a2e0e9" strokeWidth="2"/><path d="M-22 11h12M17-4h14M-6-1H3" stroke="#164e6d" strokeWidth="2"/></g>}
    {material==='mud'&&<g><path d="M-38-5h10v-8h17v6H9v-6h16v8h14V9H25v7H5v5H-12v-8H-32V7h-6Z" fill="#514b32" fillOpacity=".68"/><path d="M-29 6h12v-4H-3M9-6h13v4h9M-8 14H9" fill="none" stroke="#8eb2a2" strokeWidth="2"/><path d="M-20-7h9M13 8h9M-3 7H3" stroke="#312e24" strokeWidth="3"/></g>}
    {material==='mist'&&<g><path d="M-38 4h12V0h14v-4H3V0H17v5h18v8H17v5H-4v-4H-25V9h-13Z" fill="#b4cdc0" fillOpacity=".3"/><path d="M-29 9h16M1 15h16M11-9h15" stroke="#e2e9d7" strokeWidth="2"/></g>}
    {material==='blighted'&&<g><path d="M-36 4h10v-7h13v-9H1v7H16v-4h17V4H23v9H7v7H-8v-7H-28V8h-8Z" fill="#352549" fillOpacity=".42"/><path d="M-28 7h12v-4h7v-9M-16 3v-6h-9M-9 3h11v8h13M16-9v9h13" fill="none" stroke="#9870b9" strokeWidth="2"/><path d="M-25-5h4v3h-4M16 12h5v3h-5M27-1h3v3h-3" fill="#c4a2dc"/></g>}
    {material==='radiant'&&<g><path d="M-33 5h9v-4h8M10 12h12v-4h9M-8-13h13" fill="none" stroke="#dba638" strokeWidth="3"/><path className="px17-light-seam" d="M-26-5h4v-4h2v4h4v2h-4v4h-2v-4h-4M20 2h3v-3h2v3h3v2h-3v3h-2V4h-3" fill="#fff4bf"/></g>}
    {material==='current'&&<g fill="none" stroke="#c4d991" strokeWidth="2"><path className="px17-current-stroke" d="M-36 9h14V5H4V1H20v-5h13M-23-6h16v-4H8"/><path d="M-30 13h6M22-12h5" stroke="#4f6e2c" strokeWidth="3"/></g>}
    {material==='fractured'&&<g><path d="M-31 6h8V0h8v6h5v5h-19ZM9-10h8v-6h8v7h7v5H11ZM1 12h7v-5h5v8H1Z" fill="#805827" stroke="#d9b86a" strokeWidth="1"/><path d="M-14-8h9v7H5M-5-1v9" fill="none" stroke="#513d26" strokeWidth="2"/></g>}
    {compound&&compound.elements.length>1&&<path className="px17-compound-inlay" data-material-combination={compound.id} d="M-8 20h16v2H-8Z" fill={compound.color}/>}
    {change&&<g className="px17-terrain-arrival" data-terrain-arrival={change}><path d="M-40-7h7v-8h14M19-15h14v8h7M-40 7h7v8h14M19 15h14V7h7" fill="none" stroke={change==='scorched'?'#ffb760':change==='frozen'||change==='flooded'?'#a2e0e9':change==='blighted'?'#c4a2dc':'#f4d478'} strokeWidth="3"/></g>}
  </g>;
}
