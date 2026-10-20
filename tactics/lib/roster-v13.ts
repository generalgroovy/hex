/** Current descriptions describe Confluence's rules; canonical H.E.X. identities stay fixed. */
export * from './roster-v11.ts';
import {CHAMPIONS as canonical,type Champion} from './roster-v11.ts';
import {CHARACTER_DESIGN} from './character-design-v13.ts';
export const CHAMPIONS:Champion[]=canonical.map(champion=>({...champion,description:CHARACTER_DESIGN[champion.id].description}));
export function getChampion(id:string):Champion {const champion=CHAMPIONS.find(entry=>entry.id===id);if(!champion)throw new Error('Unknown champion.');return champion;}
