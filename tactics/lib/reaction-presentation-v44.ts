import type {Element} from './game.ts';
import {combinationFor,type CombinationMechanics} from './combinations-v16.ts';
import type {ElementKind} from './element-presentation.ts';
export type ReactionFamily='mist'|'ice'|'cover'|'current'|'restoration'|'hazard'|'mud'|'denial'|'protection'|'charge';
export function reactionFamily(mechanics:Readonly<CombinationMechanics>):ReactionFamily{
 if(mechanics.damageScale)return 'mist';
 if(mechanics.movement==='ice')return 'ice';
 if(mechanics.cover)return 'cover';
 if(mechanics.hazard)return 'hazard';
 if(mechanics.heal||mechanics.cleanse)return 'restoration';
 if(mechanics.movement==='current'||mechanics.statuses?.some(status=>status.id==='haste'))return 'current';
 if(mechanics.movement==='rough'||mechanics.movement==='flood')return 'mud';
 if(mechanics.flux===-1||mechanics.statuses?.some(status=>['blind','wither','rooted','concussed'].includes(status.id)))return 'denial';
 if(mechanics.flux===1||mechanics.wellBonus)return 'charge';
 return 'protection';
}
const materials:Record<ReactionFamily,ElementKind>={mist:'water',ice:'ice',cover:'earth',current:'air',restoration:'light',hazard:'fire',mud:'water',denial:'dark',protection:'light',charge:'lightning'};
/** The dominant mechanic supplies the silhouette; the complete recipe stays inspectable. */
export function reactionPresentation(elements:readonly Element[]){
 const definition=combinationFor(elements),family=reactionFamily(definition?.mechanics??{});
 return {family,material:materials[family],definition};
}
/** Compact hand-drawn pixel marks reuse the same grammar on contact and ground. */
export const REACTION_MOTIFS:Record<ReactionFamily,string>={
 mist:'M-22 4h8v-5h9v-5H6v5h10v5h7M-15 11h30M-8-12h16',
 ice:'M-2-23H2v17h10v-9h4v13h9V2H16v13H12V6H2v17H-2V6H-12v9H-16V2H-25V-2H-16v-13h4v9H-2Z',
 cover:'M-20 14V-5h7v-9H13v9h7v19M-13-5H13M0-14V14M-20 4H20',
 current:'M-26 7H6V2H17V-3H8M-19-9H8v-5h10M14 11h13V6',
 restoration:'M-3-19H3V-3H19V3H3V19H-3V3H-19V-3H-3ZM-28 11h5v5h-5M23-15h5v5h-5',
 hazard:'M-16 15V2h5v-9h4v9h6v-22h5v9h6v10h7v16ZM-6 12V4h4v-7h4V7h4v5Z',
 mud:'M-24 3h11v4H0V3H15v-5h10M-18 13H9v-4h10M-14-10H2v4h9',
 denial:'M-16-14H13v7h7V8H13v7H-16V8h-7V-7h7ZM-7-5V6H6V-5Z',
 protection:'M-17-16H17V5H10v8H3v5H-3v-5H-10V5H-17ZM-8-3h6V3H8',
 charge:'M2-23H11L3-5H14L-5 23H-11L-3 4H-14Z',
};
