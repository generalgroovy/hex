import type {Element} from './game.ts';
import type {Spell} from './spells-v10.ts';

/** Short rule language shared by loadout building, targeting and the field guide. */
export const ELEMENT_PERSONALITIES: Record<Element,{verb:string;rule:string}> = {
  water:{verb:'Shape the route',rule:'Water fields flood: entering or leaving costs 2 movement. Frost spells freeze the field; entering ice slides to its far edge. Fire thaws it.'},
  fire:{verb:'Make ground dangerous',rule:'Pure Fire hurts its final occupant for 1, sharing the environmental damage cap. Fire thaws ice; Water turns the clash into Steam.'},
  earth:{verb:'Hold the line',rule:'Earth fields cost 2 movement to cross. Stone barriers block routes and sight; forest cover reduces ordinary spell damage.'},
  air:{verb:'Keep momentum',rule:'Starting on an Air field gives +1 movement, without stacking with Haste. Pushes, pulls and ice lanes turn position into a weapon.'},
  light:{verb:'Protect the opening',rule:'Pure Light grants Clarity against incoming control. Protection and healing reward good timing; mixed fields can help either team.'},
  dark:{verb:'Undermine recovery',rule:'Pure Dark applies Wither, weakening future healing. Theft, Blind and bindings pressure the opponent’s next decision.'},
};
export function spellSurfaceHint(spell:Spell):string {
  if(spell.freeze)return '';
  return ({water:'Floods the field · 2 movement in or out.',fire:'Thaws ice. Unmixed Fire deals 1 terrain damage.',earth:'Rough ground · 2 movement in or out.',air:'Current · +1 movement when starting here.',light:'Unmixed Light grants Clarity to either team.',dark:'Unmixed Dark applies Wither to either team.'} as Record<Element,string>)[spell.element];
}
