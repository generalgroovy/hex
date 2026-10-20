import {formatTile} from './board-labels-v9.ts';
import {eventPhase,type ResolutionPhase} from './feedback-v15.ts';
import {getChampion,getSpell,isAlive,STATUS_DEFINITIONS,type Player,type SimEvent,type SimState,type SimUnit} from './tactics-v15.ts';

export type ResolutionAction={label:string;detail:string;tone:'neutral'|'good'|'bad'};
export type ResolutionCharacter={
 id:string;championId:string;name:string;owner:Player;
 movement:ResolutionAction;casting:ResolutionAction;impact:ResolutionAction;effects:ResolutionAction;review:ResolutionAction;
 hpDelta:number|null;statuses:string[];details:string[];returned:boolean;
};
export type ResolutionReadout={round:number;characters:ResolutionCharacter[]};
const action=(label:string,detail=label,tone:ResolutionAction['tone']='neutral'):ResolutionAction=>({label,detail,tone});
const statusName=(id:string)=>STATUS_DEFINITIONS.find(status=>status.id===id)?.name||id;
const signed=(value:number)=>`${value>0?'+':'−'}${Math.abs(value)}`;
const unique=(items:string[])=>[...new Set(items)];
const spellName=(event:SimEvent)=>event.spellId?getSpell(event.spellId).name:'Spell';

/** Only public resolution events and matching public snapshots enter this model.
 * Missing or skipped snapshots still expose recorded actions, but never fabricated
 * movement, Guard, HP changes, cleanses or status losses. No TeamPlan is accepted. */
export function resolutionReadout(previous:SimState|undefined,next:SimState):ResolutionReadout|null {
 if(!next.lastResolution.length)return null;
 const before=previous&&previous.version+1===next.version&&previous.mapId===next.mapId?previous:undefined;
 const events=next.lastResolution;
 const characters=next.units.map((unit):ResolutionCharacter=>{
  const old=before?.units.find(candidate=>candidate.id===unit.id);
  const own=events.filter(event=>event.unitId===unit.id);
  const moved=own.find(event=>event.kind==='move'&&event.to);
  const blocked=own.find(event=>event.kind==='bounce'&&eventPhase(event,events)==='move');
  const cast=own.find(event=>event.kind==='cast');
  const fizzled=own.find(event=>event.kind==='fizzle');
  const guard=own.find(event=>event.kind==='guard');
  const defeated=own.some(event=>event.kind==='defeat');
  const returned=own.find(event=>event.kind==='respawn');
  const pushes=own.filter(event=>event.kind==='push'&&event.to);
  const stoppedPush=own.find(event=>event.kind==='bounce'&&eventPhase(event,events)==='impact');
  const wasDefeated=old?!isAlive(old):!!returned||(!isAlive(unit)&&!defeated);
  let movement=action('No move recorded');
  if(wasDefeated)movement=action('Defeated','This character was already defeated before movement.');
  else if(moved)movement=action(`Moved ${formatTile(moved.to!)}`,moved.text);
  else if(blocked)movement=action(`Blocked${blocked.to?` → ${formatTile(blocked.to)}`:''}`,blocked.text,'bad');
  else if(old&&isAlive(old))movement=action(`Stayed ${formatTile(old)}`,'Held position during movement.');
  let casting=action('No action recorded');
  if(wasDefeated)casting=action('Defeated','This character was already defeated before casting.');
  else if(fizzled)casting=action(`${spellName(fizzled)} fizzled`,fizzled.text,'bad');
  else if(cast)casting=action(`${spellName(cast)}${cast.to?` → ${formatTile(cast.to)}`:''}`,cast.text);
  else if(guard)casting=action('Guard',guard.text,'good');

  // Raw healing events include overheal. Show only the visible health difference.
  const hpDelta=old&&isAlive(old)&&!returned?unit.hp-old.hp:null;
  const gained=unique(own.filter(event=>event.kind==='surface'&&event.status&&unit.statuses[event.status]).map(event=>statusName(event.status!)));
  const ended=old&&!defeated&&!returned?Object.keys(old.statuses).filter(id=>!unit.statuses[id as keyof SimUnit['statuses']]).map(id=>`${statusName(id)} ended`):[];
  const statuses=unique([...gained,...ended]);
  const outcomes:string[]=[];
  if(defeated)outcomes.push('Defeated');
  else if(returned)outcomes.push('Returned · full health');
  else if(wasDefeated)outcomes.push('Defeated');
  if(hpDelta)outcomes.push(`${signed(hpDelta)} HP`);
  if(pushes.length)outcomes.push(`Forced → ${formatTile(pushes.at(-1)!.to!)}`);
  if(stoppedPush)outcomes.push('Push blocked');
  outcomes.push(...statuses);
  if(!outcomes.length)outcomes.push(hpDelta===0?'Health unchanged':'No effect recorded');
  const brief=outcomes.length<=3?outcomes.join(' · '):`${outcomes.slice(0,2).join(' · ')} · +${outcomes.length-2} effects`;
  const effects=action(brief,outcomes.join(' · '),defeated||(hpDelta??0)<0?'bad':returned||(hpDelta??0)>0?'good':'neutral');
  // Effects name what is happening; final HP, defeats and returns wait for review.
  const hit=own.some(event=>event.kind==='damage'||event.kind==='surface'&&(event.amount??0)>0);
  const healed=own.some(event=>event.kind==='heal');
  const impacts=wasDefeated?['Defeated']:[
   hit&&healed?'Damage + healing':hit?'Taking damage':healed?'Healing':'',
   pushes.length?`Forced → ${formatTile(pushes.at(-1)!.to!)}`:'',
   stoppedPush?'Push blocked':'',...gained,
  ].filter(Boolean);
  const impact=action(impacts.length?impacts.slice(0,3).join(' · '):casting.label,impacts.join(' · ')||casting.detail,hit?'bad':healed?'good':'neutral');
  const review=action([moved?`Moved ${formatTile(moved.to!)}`:blocked?'Move blocked':wasDefeated?'Defeated':'',casting.label==='Defeated'?'':casting.label].filter(Boolean).join(' · ')||casting.label,
   [movement.detail,casting.detail,effects.detail].join(' '),fizzled||defeated?'bad':effects.tone);
  return {id:unit.id,championId:unit.championId,name:getChampion(unit.championId).name,owner:unit.owner,movement,casting,impact,effects,review,hpDelta,statuses,returned:!!returned,details:unique(own.map(event=>event.text))};
 });
 return {round:before?.round??Math.max(1,next.round-(next.winner===null?1:0)),characters};
}

export function characterPhaseAction(character:ResolutionCharacter,phase:ResolutionPhase):ResolutionAction {
 return phase==='move'?character.movement:phase==='cast'?character.casting:phase==='impact'?character.impact:character.review;
}
