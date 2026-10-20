import type {Element,Point} from './game.ts';
/** A surviving mixed cast can counter with any ingredient. Intercepted casts
 * must be removed by the caller; a resulting clash field cannot counter. */
export function countersElementPulse(elements:readonly Element[],area:readonly Point[],pulse:{counterElement:Element;anchor:Point}):boolean {
 return elements.includes(pulse.counterElement)&&area.some(cell=>cell.q===pulse.anchor.q&&cell.r===pulse.anchor.r);
}
