import {affinityTotal,getChampion} from './roster-v13.ts';
import {getCreature,getCreaturePerk,teamPerkEffects} from './campaign-creatures-v20.ts';
import {getSpell,spellAccess,spellCost} from './spells-v20.ts';
import {towerReplaceableActors,type TowerActor,type TowerRun} from './tower-v23.ts';
const name=(actor:TowerActor)=>actor.displayName??(actor.creatureId?getCreature(actor.creatureId).name:getChampion(actor.championId).name);
const bonds=(party:readonly TowerActor[])=>teamPerkEffects(party.flatMap(actor=>actor.creatureId?[actor.creatureId]:[])).perkIds;
export type RecruitComparison={replaceId:string|null;label:string;healthCapacity:number;affinity:number;gainedBonds:string[];lostBonds:string[]};
/** Bond changes use the exact party after each legal replacement, not all candidates together. */
export function towerRecruitComparison(run:TowerRun,recruit:TowerActor):RecruitComparison[]{
 const before=bonds(run.party),options=run.party.length<3?[null]:towerReplaceableActors(run);
 return options.map(replaced=>{
  const after=bonds([...run.party.filter(actor=>actor.id!==replaced?.id),recruit]);
  return {replaceId:replaced?.id??null,label:replaced?`Replace ${name(replaced)}`:'Add to party',healthCapacity:(recruit.maxHp??8)-(replaced?.maxHp??0),affinity:affinityTotal(recruit.affinities)-(replaced?affinityTotal(replaced.affinities):0),gainedBonds:after.filter(id=>!before.includes(id)).map(id=>getCreaturePerk(id).name),lostBonds:before.filter(id=>!after.includes(id)).map(id=>getCreaturePerk(id).name)};
 });
}
/** Learning is automatic; this readout distinguishes knowledge from immediate access. */
export function towerLearningNotice(run:TowerRun,previous:readonly string[]):string{
 const learned=run.learnedSpells.filter(id=>!previous.includes(id));if(!learned.length)return '';
 const usable=learned.filter(id=>run.party.some(actor=>!actor.creatureId&&spellAccess(actor.championId,id,actor.affinities,run.learnedSpells).unlocked&&spellCost(actor.championId,id,actor.affinities)<=(actor.maxFlux??6))).length;
 return `${learned.length===1?getSpell(learned[0]).name:`${learned.length} enemy techniques`} learned. ${usable?`${usable} ready to equip between rooms.`:'Stored for a matching champion or affinity.'}`;
}
