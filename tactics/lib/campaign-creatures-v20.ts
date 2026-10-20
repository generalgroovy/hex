/** Current campaign kits; prior campaign actors and saves retain their original kits. */
export * from './campaign-creatures-v19.ts';
import {CREATURES as previous,type CreatureDefinition} from './campaign-creatures-v19.ts';
import {creatureLoadout,getSpell} from './spells-v20.ts';
export const CREATURES:readonly CreatureDefinition[]=Object.freeze(previous.map(creature=>Object.freeze({...creature,loadout:Object.freeze(creatureLoadout(creature.id)) as unknown as string[]})));
const byId=new Map(CREATURES.map(creature=>[creature.id,creature]));
export function getCreature(id:string):CreatureDefinition {const creature=byId.get(id);if(!creature)throw new Error('Unknown combat creature.');return creature;}
export function validateCreatureId(value:unknown):string {if(typeof value!=='string'||!byId.has(value))throw new Error('Choose a known combat creature.');return value;}
export function creatureAbilitySummary(id:string):string {return getCreature(id).loadout.map(spellId=>getSpell(spellId).name).join(' · ');}
