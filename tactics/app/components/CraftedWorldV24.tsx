import type {CSSProperties} from 'react';
import type {SimCell} from '../../lib/tactics-v16';
import {groundDetailSeed,WORLD_HEX_VERTICES,type SolidFootprint,type GroundEdge} from '../../lib/world-readability-v24';
import {terrainMaterial} from '../../lib/reactive-environment-v17';
import type {CliffFace} from '../../lib/living-world-v16';
import './crafted-world-v24.css';

/** A few larger material clusters read at playing distance. The atlas supplies
 * grain; authored accents give a place character without stippling every hex. */
export function GroundDetailsV24({cell,live,edges=[]}:{cell:SimCell;live:boolean;edges?:readonly GroundEdge[]}){
 const seed=groundDetailSeed(cell),water=cell.biome==='water'||cell.biome==='marsh',woodland=cell.biome==='forest';
 return <g className={`px24-ground-detail${live?' is-live':''}`} data-ground-detail={cell.biome} style={{'--world-delay':`${-(seed%9)*310}ms`} as CSSProperties} shapeRendering="crispEdges" pointerEvents="none">
  {water?<g className="px24-water-glints" fill="none"><path d={seed%2?'M-31-5h11v-2h15M5 12h13v-2h10':'M-24 9h16v-2h11M8-13h16'} stroke="#9bcfc1" strokeWidth="1.2"/><path d={seed%2?'M-24-1h18M13 16h9':'M-21 13h12M11-9h11'} stroke="#1d535e" strokeWidth="2"/></g>:cell.biome==='ruins'?null:cell.biome==='earth'?seed%3===0&&<g><path d="M-32 2h6v-4h9v3h8v5h-8v3h-15Z" fill="#8d6b3d"/><path d="M-30 1h8v-3h6v3h5M-25 6h11" fill="none" stroke="#d3b174" strokeWidth="1.5"/><path d="M17-13h7v3h6v3H16Z" fill="#c6a269"/><path d="M17-13h7" stroke="#e4c48b" strokeWidth="1.5"/></g>:seed%3===0&&<g transform={`translate(${seed%2?-24:23} ${seed%2?7:-9})`}><path d="M-11 4h22v3H-11Z" fill="#334b26" opacity=".45"/><path d="M-10 3V-1h2v-5h2v7h3V-9h2v-3h2V1h3v-5h2v-3h2v8h3v4Z" fill={woodland?'#324c27':'#45652c'}/><path d="M-6-3h2v5h-2M0-9h2v9H0M7-4h2v6H7" fill={woodland?'#879448':'#a5b45e'}/>{seed%9===0&&<g><path d="M-9-3h4v-3h3v4h-3v3h-4ZM7-6h3v-3h3v4h-3v3H7Z" fill={seed%2?'#e0bd72':'#bc96b7'}/><path d="M-6-3h2M10-6h2" stroke="#f0dda0" strokeWidth="1.5"/></g>}</g>}
  {edges.map(edge=><g key={edge.edge} className={`px24-ground-rim is-${edge.kind}`} data-ground-edge={edge.kind}><path d={edge.path} stroke={water?'#244c4b':edge.kind==='woodland'?'#334e2c':'#4a5030'} strokeWidth={edge.kind==='woodland'?4:2.5}/><path d={edge.path} stroke={water?'#8bbdaf':cell.biome==='earth'?'#d6b577':'#a4ae62'} strokeWidth={edge.kind==='woodland'?1:1.3} opacity={edge.edge>=4||edge.edge===0?'.85':'.45'}/></g>)}
 </g>;
}

/** A ledge is soil and stone with a turf cap, not the old repeating brick wall.
 * The exact resolver projection supplies its height and exposed edges. */
export function CliffArtV24({cell,face}:{cell:SimCell;face:CliffFace}){
 const [ax,ay]=WORLD_HEX_VERTICES[face.edge],[bx,by]=WORLD_HEX_VERTICES[(face.edge+1)%6],wet=cell.biome==='water'||cell.biome==='marsh';
 const rim=`M${ax} ${ay}L${bx} ${by}`,layers=[.25,.62].map(fraction=>`M${ax} ${ay+face.depth*fraction}L${bx} ${by+face.depth*fraction}`).join('');
 return <g className="px-world-cliff" data-cliff-edge={face.edge} data-cliff-material={wet?'wet-earth':'earth'}><path d={face.path} fill={face.edge===1?'#574b35':face.edge===2?'#776044':'#917246'} stroke="#38432e" strokeWidth=".7"/><path d={layers} fill="none" stroke={wet?'#486450':'#b58e55'} strokeWidth="1.6" opacity=".65"/><path d={`M${ax*.65+bx*.35} ${ay*.65+by*.35+2}v${Math.min(6,face.depth*.55)}m${(bx-ax)*.35} ${Math.min(2,face.depth*.15)}v${Math.min(5,face.depth*.35)}`} fill="none" stroke="#4c432f" strokeWidth="1.2"/><path d={rim} fill="none" stroke={wet?'#42685c':cell.biome==='earth'?'#bd985f':'#627c38'} strokeWidth="3"/><path d={rim} fill="none" stroke={wet?'#78a89a':cell.biome==='earth'?'#dfbc7b':'#a5b562'} strokeWidth=".8"/></g>;
}

/** Fixed masonry uses the same ink, warm highlights and stepped detail as the
 * champion art. Only the surface material changes when a spell lands. */
export function SolidTerrainV24({cell,footprint,texture}:{cell:SimCell;footprint:SolidFootprint;texture?:string}){
 const material=terrainMaterial(cell),temporary=!!cell.barrier,seed=groundDetailSeed(cell);
 const palette=material==='frozen'?{top:'#93c5c8',left:'#507b8a',right:'#315968',light:'#e3f1dd',ink:'#294752'}:material==='scorched'?{top:'#786044',left:'#55432e',right:'#39352a',light:'#b18b51',ink:'#282f28'}:material==='blighted'?{top:'#897389',left:'#615064',right:'#413649',light:'#c6a7c3',ink:'#302b36'}:temporary?{top:'#c5a165',left:'#8d6b3d',right:'#624e31',light:'#efd298',ink:'#45402b'}:{top:'#c5b17a',left:'#8e7b4f',right:'#5b6240',light:'#ecdb9e',ink:'#34432d'};
 return <g className={`px24-solid-terrain is-${material}`} data-solid-terrain={temporary?'barrier':'ruin'} data-solid-cell={`${cell.q},${cell.r}`} pointerEvents="none" shapeRendering="crispEdges">
  {footprint.faces.map(face=><g key={face.edge}><path d={face.path} fill={face.edge===1?palette.right:palette.left} stroke={palette.ink} strokeWidth=".8"/><path d={face.seam} stroke={palette.ink} strokeWidth="1" fill="none" opacity=".6"/></g>)}
  <polygon points={footprint.top} fill={palette.top} stroke={palette.top} strokeWidth=".65"/>
  {texture&&<polygon points={footprint.top} fill={`url(#${texture})`} opacity={material==='natural'?'.54':'.23'}/>}
  <g transform={`translate(0 ${-footprint.lift})`}>
   <path d={seed%2?'M-28-8h19v6H6v8h23M-9-2v15M6-2v-13':'M-27 7h15v-9H7v-9h22M-12-2v-12M7-2v16'} fill="none" stroke={palette.ink} strokeWidth="1.2" opacity=".7"/>
   <path d="M-26-10h11M8-16h10M12 7h12M-17 13h9" fill="none" stroke={palette.light} strokeWidth="2"/>
   <path d="M-5-17h5v2h-5M25-3h5v2h-5M-29 3h4v2h-4" fill={palette.ink} opacity=".25"/>
   {!temporary&&material==='natural'&&<g><path d="M-36-9h10v3h-4v6h-7v-3h-5M24 11h10v4h-7v6h-7v-5h4Z" fill="#526a31"/><path d="M-35-8h5v2h-5M25 12h5v2h-5M22 17h3" fill="#a5b159"/><path d={seed%2?'M-24-17l9-3 7 3v5l-9 3-7-3Z':'M7-19l10-3 9 4v5l-10 3-9-4Z'} fill={palette.left} stroke={palette.ink} strokeWidth=".7"/><path d={seed%2?'M-24-17l9-3 7 3-9 3Z':'M7-19l10-3 9 4-10 3Z'} fill={palette.light}/></g>}
   {material==='frozen'&&<path d="M-30-12h9v3h12M9 14h14v-3h7" fill="none" stroke="#eff6dc" strokeWidth="2"/>}
   {material==='scorched'&&<path className="px24-stone-embers" d="M-16-3h6v3M10 5h7" fill="none" stroke="#eaa465" strokeWidth="1.5"/>}
  </g>
  <path d={footprint.rim} fill="none" stroke={palette.ink} strokeWidth="1.2"/><path d={footprint.rim} fill="none" stroke={palette.light} strokeWidth=".5"/>
 </g>;
}
