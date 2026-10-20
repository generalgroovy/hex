/** Canonical scout facts and persistence checks. No runtime import of the run model. */
import type {Element} from './game.ts';
import type {TowerActor,TowerRoom,TowerRun} from './tower-v23.ts';
import {getChampion} from './roster-v13.ts';
import {getCreature} from './campaign-creatures-v20.ts';
import {availableSpellIds,getSpell} from './spells-v20.ts';
import {towerRoomIntel} from './tower-scouting.ts';

export type ScoutReport={id:string;encounterKey:string;roomId:string;kind:'identity'|'affinity'|'health'|'spell'|'environment';label:string;detail:string;enemyId?:string;element?:Element;spellId?:string};
export type FloorScouting={floor:number;usedActorIds:string[];reports:ScoutReport[]};
const elements:readonly Element[]=['fire','water','earth','air','light','dark'];
const cap=(value:string)=>value.charAt(0).toUpperCase()+value.slice(1);
const plain=(value:unknown):value is Record<string,unknown>=>!!value&&typeof value==='object'&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value));
export function scoutHash(value:string,salt=2166136261):number{let result=salt;for(const char of value){result^=char.charCodeAt(0);result=Math.imul(result,16777619)>>>0;}return result;}
const identity=(actor:TowerActor)=>({id:actor.id,championId:actor.championId,creatureId:actor.creatureId??null,affinities:elements.map(element=>actor.affinities[element]??0),loadout:[...actor.loadout],hp:actor.hp,maxHp:actor.maxHp??8,maxFlux:actor.maxFlux??6});
/** Different squad strengths can share a clue only when the actual encounter is identical. */
export function scoutEncounterKey(run:Pick<TowerRun,'seed'>,room:TowerRoom):string {
 const source=JSON.stringify({seed:run.seed,id:room.id,kind:room.kind,mapId:room.mapId,environment:room.environment,enemies:room.enemies.map(identity)});
 return `${room.id}:${scoutHash(source).toString(16).padStart(8,'0')}${scoutHash(source,0x9e3779b9).toString(16).padStart(8,'0')}`;
}

/** Baseline clues are excluded, and one actual equipped spell per foe is never scoutable. */
export function scoutFactsForRoom(run:Pick<TowerRun,'seed'>,room:TowerRoom):ScoutReport[]{
 if(!room.enemies.length)return [];
 const encounterKey=scoutEncounterKey(run,room),intel=towerRoomIntel(room),facts:ScoutReport[]=[];
 const add=(suffix:string,report:Omit<ScoutReport,'id'|'encounterKey'|'roomId'>)=>facts.push({id:`${encounterKey}:${suffix}`,encounterKey,roomId:room.id,...report});
 for(const [index,enemy] of room.enemies.entries()){
  const prefix=`Enemy ${index+1}`,known=intel.knownEnemy&&intel.knownEnemy.championId===enemy.championId&&intel.knownEnemy.creatureId===enemy.creatureId;
  if(!known){const creature=enemy.creatureId?getCreature(enemy.creatureId):undefined,champion=getChampion(enemy.championId);add(`${enemy.id}:identity`,{kind:'identity',enemyId:enemy.id,label:`${prefix} · identity`,detail:`${enemy.displayName??creature?.name??champion.name} · ${creature?`${cap(creature.strengthClass)} creature`:champion.race+' champion'}`});}
  const affinities=elements.filter(element=>(enemy.affinities[element]??0)>0).sort((a,b)=>(enemy.affinities[b]??0)-(enemy.affinities[a]??0)||elements.indexOf(a)-elements.indexOf(b));
  for(const [rank,element] of affinities.entries())add(`${enemy.id}:affinity:${element}`,{kind:'affinity',enemyId:enemy.id,element,label:`${prefix} · ${rank===0?'strongest':'other'} affinity`,detail:`${cap(element)} ${enemy.affinities[element]}`});
  add(`${enemy.id}:health`,{kind:'health',enemyId:enemy.id,label:`${prefix} · health`,detail:`${enemy.hp}/${enemy.maxHp??8} HP`});
  const spells=enemy.creatureId?[...enemy.loadout]:availableSpellIds(enemy.championId,enemy.loadout,enemy.affinities);
  const ordered=[...new Set(spells)].sort((a,b)=>scoutHash(`${encounterKey}:${enemy.id}:reserve:${a}`)-scoutHash(`${encounterKey}:${enemy.id}:reserve:${b}`)||a.localeCompare(b));
  for(const spellId of ordered.slice(1)){const spell=getSpell(spellId);add(`${enemy.id}:spell:${spellId}`,{kind:'spell',enemyId:enemy.id,spellId,element:spell.element,label:`${prefix} · equipped spell`,detail:`${spell.name} · ${cap(spell.element)}`});}
 }
 if(intel.environment===undefined){const description={plain:'No starting elemental field.',flooded:'Six central hexes start flooded for 2 exchanges: slower passage; ready for freezing or steam.',embers:'Six central hexes start burning for 2 exchanges: hazardous footing; ready for an elemental mix.',draft:'Six central hexes carry a current for 2 exchanges: extra movement when starting there.'}[room.environment];add('environment',{kind:'environment',label:'Ground report',detail:description});}
 return facts;
}

const reportKeys=['id','encounterKey','roomId','kind','label','detail','enemyId','element','spellId'];
export function canonicalScoutReport(input:unknown,facts:readonly ScoutReport[]):ScoutReport|undefined {
 if(!plain(input)||Object.keys(input).some(key=>!reportKeys.includes(key))||typeof input.id!=='string')return;
 const expected=facts.find(fact=>fact.id===input.id);if(!expected||reportKeys.some(key=>input[key]!==expected[key as keyof ScoutReport]))return;
 return {...expected};
}

export function validateFloorScouting(run:Pick<TowerRun,'floor'|'seed'|'party'>,rooms:readonly TowerRoom[],input:unknown):FloorScouting|undefined {
 if(input===undefined)return;
 if(!plain(input)||Object.keys(input).some(key=>!['floor','usedActorIds','reports'].includes(key))||input.floor!==run.floor||!Array.isArray(input.usedActorIds)||!Array.isArray(input.reports))throw new Error('Scouting progress is invalid.');
 const used=input.usedActorIds;
 if(used.length>3||new Set(used).size!==used.length||used.some(id=>typeof id!=='string'||!run.party.some(actor=>actor.id===id&&!actor.creatureId)))throw new Error('A champion can scout once per floor.');
 const facts=rooms.flatMap(room=>scoutFactsForRoom(run,room));
 if(input.reports.length>facts.length||input.reports.length<used.length||new Set(input.reports.map(report=>plain(report)?report.id:null)).size!==input.reports.length)throw new Error('Scouting reports are invalid.');
 const reports=input.reports.map(report=>{const canonical=canonicalScoutReport(report,facts);if(!canonical)throw new Error('A scouting report does not match this encounter.');return canonical;});
 return {floor:run.floor,usedActorIds:[...used] as string[],reports};
}
