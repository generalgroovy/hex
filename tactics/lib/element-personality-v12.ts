import type {Element} from './game.ts';
import type {Spell} from './spells-v11.ts';

/** Short rule language shared by loadout building, targeting and the field guide. */
export const ELEMENT_PERSONALITIES: Record<Element,{verb:string;rule:string}> = {
  water:{verb:'Shape the route',rule:'Unmixed Water floods: entering or leaving costs 2 movement. Frost freezes unmixed Water into sliding ice. Added elements transform it into one new field with its own rules.'},
  fire:{verb:'Make ground dangerous',rule:'Unmixed Fire hurts its final occupant for 1. Fire and Water alone form Steam, which softens spells; adding Earth instead creates Hot Spring. Read the complete mixture.'},
  earth:{verb:'Hold the line',rule:'Unmixed Earth costs 2 movement to cross. Natural stone, forest and ruins contribute Earth to mixtures. Barriers block routes and sight; forests provide cover.'},
  air:{verb:'Keep momentum',rule:'Starting on an Air field gives +1 movement, without stacking with Haste. Pushes, pulls and ice lanes turn position into a weapon.'},
  light:{verb:'Protect the opening',rule:'Pure Light grants Clarity against incoming control. Protection and healing reward good timing; mixed fields can help either team.'},
  dark:{verb:'Undermine recovery',rule:'Pure Dark applies Wither, weakening future healing. Theft, Blind and bindings pressure the opponent’s next decision.'},
};
export function spellSurfaceHint(spell:Spell):string {
  if(spell.freeze)return 'Adds Water. Freezes unmixed Water; other mixtures follow their own field rules.';
  return ({water:'Adds Water. Unmixed Water floods; mixtures transform it.',fire:'Adds Fire. Unmixed Fire deals 1 terrain damage.',earth:'Adds Earth. Unmixed Earth slows passage.',air:'Adds Air. Unmixed Air gives a running start.',light:'Adds Light. Unmixed Light grants Clarity.',dark:'Adds Dark. Unmixed Dark weakens healing.'} as Record<Element,string>)[spell.element];
}
