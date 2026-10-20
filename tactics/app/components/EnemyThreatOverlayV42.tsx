import type {EnemyThreatPreview} from '../../lib/enemy-threat-v42';
import {hexPolygon,surfacePoint} from '../../lib/battlefield-geometry';
import {rangeBoundaryPath} from '../../lib/range-outline-v16';
import type {Point} from '../../lib/game';
import './enemy-threat-v42.css';

/** Public reach is a possibility envelope, never an enemy order or hit promise. */
export default function EnemyThreatOverlayV42({preview,heightAt}:{preview:EnemyThreatPreview;heightAt:(point:Point)=>number}){
 const moveEdge=rangeBoundaryPath(preview.move,heightAt),spellEdge=rangeBoundaryPath(preview.attack,heightAt);
 return <g className="px42-enemy-threat" data-enemy-threat-unit={preview.fighterId} data-ready-spells={preview.readySpells} aria-hidden="true" pointerEvents="none">
  {preview.attack.map(point=>{const at=surfacePoint(point,heightAt(point));return <polygon key={`${point.q},${point.r}`} data-enemy-spell-cell={`${point.q},${point.r}`} className="px42-spell-fill" points={hexPolygon(at.x,at.y)}/>})}
  {preview.move.map(point=>{const at=surfacePoint(point,heightAt(point));return <polygon key={`${point.q},${point.r}`} data-enemy-move-cell={`${point.q},${point.r}`} className="px42-move-fill" points={hexPolygon(at.x,at.y)}/>})}
  {spellEdge&&<g data-enemy-range-boundary="spell"><path className="px42-range-under" d={spellEdge}/><path className="px42-spell-edge" d={spellEdge}/></g>}
  {moveEdge&&<g data-enemy-range-boundary="move"><path className="px42-range-under" d={moveEdge}/><path className="px42-move-edge" d={moveEdge}/></g>}
 </g>;
}
