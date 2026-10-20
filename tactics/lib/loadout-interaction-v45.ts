/** Only spell IDs from the current, legal catalogue can enter a loadout. */
export const SPELL_DRAG_TYPE='application/x-hex-spell';
export function readDraggedSpell(value:string,allowed:readonly string[]):string|null{
 return value.length<=100&&allowed.includes(value)?value:null;
}
export function placeLoadoutSpell(loadout:readonly string[],spellId:string,slot:number,allowed:readonly string[]):string[]{
 if(loadout.length!==4||!Number.isInteger(slot)||slot<0||slot>3)throw new Error('Choose one of the four spell slots.');
 if(!allowed.includes(spellId))throw new Error('This spell is not available for this character.');
 const next=[...loadout],other=next.indexOf(spellId);
 if(other>=0&&other!==slot)next[other]=next[slot];
 next[slot]=spellId;
 return next;
}
export function adjacentSpellSlot(slot:number,key:string):number|null{
 if(!Number.isInteger(slot)||slot<0||slot>3)return null;
 return key==='ArrowLeft'&&slot>0?slot-1:key==='ArrowRight'&&slot<3?slot+1:null;
}
