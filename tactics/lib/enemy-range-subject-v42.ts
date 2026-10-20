type RangeInteraction={
 kind:'move'|'cast';inspecting:boolean;viewingExchange:boolean;
 card?:string|null;hover?:string|null;focus?:string|null;pinned?:string|null;
};
/** Aiming owns the map. Explicit portrait inspection remains available, but a
 * fighter under the cast cursor must never replace the player's spell preview. */
export function enemyRangeSubject(input:RangeInteraction):string|null {
 if(input.viewingExchange)return null;
 if(input.card)return input.card;
 if(input.kind==='cast'&&!input.inspecting)return null;
 return input.hover||input.focus||input.pinned||null;
}
