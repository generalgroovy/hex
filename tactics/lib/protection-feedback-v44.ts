type DamageEvent={kind:string;unitId?:string;amount?:number;breakdown?:{prevented:number}};
/** A blocked cue needs recorded prevention, not merely unchanged net HP:
 * healing can offset damage, and missing historical explanations prove nothing. */
export function fullyBlockedFighters(events:readonly DamageEvent[]):Set<string>{
 const hurt=new Set(events.filter(event=>event.kind==='damage'&&(event.amount??0)>0).map(event=>event.unitId));
 return new Set(events.filter(event=>event.kind==='damage'&&event.unitId&&event.amount===0&&(event.breakdown?.prevented??0)>0&&!hurt.has(event.unitId)).map(event=>event.unitId!));
}
