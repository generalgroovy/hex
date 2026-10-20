import type {Spell} from '../../lib/spells-v20';
import type {Point} from '../../lib/game';
import {focusZone,spellProfileBands} from '../../lib/spell-profile-v42';
import {surfacePoint,hexPolygon} from '../../lib/battlefield-geometry';
import {rangeBoundaryPath} from '../../lib/range-outline-v16';
import './focused-area-v42.css';

/** One inner contour and a small centre marker: no second tile grid. */
export default function FocusedAreaV42({spell,aim,cells}:{spell:Spell;aim:Point;cells:(Point&{height?:number})[]}){
  if(!spellProfileBands(spell))return null;
  const heights=new Map(cells.map(cell=>[`${cell.q},${cell.r}`,cell.height??0]));
  const inner=cells.filter(cell=>['centre','inner'].includes(focusZone(spell,aim,cell)));
  const centre=cells.find(cell=>cell.q===aim.q&&cell.r===aim.r);
  if(!centre)return null;
  const at=surfacePoint(centre,centre.height);
  return <g className="focus42-area" data-focused-area={spell.id} pointerEvents="none" aria-hidden="true">
    <path className="focus42-inner" d={rangeBoundaryPath(inner,cell=>heights.get(`${cell.q},${cell.r}`)??0)}/>
    <polygon className="focus42-centre" points={hexPolygon(at.x,at.y,7)}/>
    <g transform={`translate(${at.x} ${at.y+39})`}>
      <title>Centre crit · strongest effect</title>
      <path className="focus42-star" d="M0-10 3-3 10 0 3 3 0 10-3 3-10 0-3-3Z"/>
    </g>
  </g>;
}
