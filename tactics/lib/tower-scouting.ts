/** Route-only information. Entering a room still reveals the unchanged encounter. */
import type {Element} from './game.ts';
import {getChampion} from './roster-v13.ts';
import {getCreature} from './campaign-creatures-v20.ts';
import type {TowerRoom} from './tower-v23.ts';
import {towerMotifFromMapId,TOWER_MOTIF_INFO} from './tower-terrain-v44.ts';

export type TowerScoutClue={label:string;detail:string;elements?:Element[]};
export type TowerRoomIntel={
 profile:'elements'|'sighting'|'terrain'|'service';
 heading:string;
 risk:string;
 reward:string;
 enemyCount:number;
 clues:TowerScoutClue[];
 unknowns:string[];
 knownEnemy?:{name:string;championId:string;creatureId?:string;kind:'champion'|'creature';enemyId:string;position:number};
 environment?:TowerRoom['environment'];
};

const elements:readonly Element[]=['fire','water','earth','air','light','dark'];
const labels:Record<Element,string>={fire:'Fire',water:'Water',earth:'Earth',air:'Air',light:'Light',dark:'Dark'};
const profiles=['elements','sighting','terrain'] as const;
const terrain:Record<TowerRoom['environment'],{name:string;effect:string}>={
 plain:{name:'Clear ground',effect:'No starting elemental field.'},
 flooded:{name:'Flooded centre',effect:'Six central hexes start flooded for 2 exchanges: slower passage; ready for freezing or steam.'},
 embers:{name:'Burning centre',effect:'Six central hexes start burning for 2 exchanges: hazardous footing; ready for an elemental mix.'},
 draft:{name:'Central current',effect:'Six central hexes carry a current for 2 exchanges: extra movement when starting there.'},
};
function hash(value:string):number{let result=2166136261;for(const character of value){result^=character.charCodeAt(0);result=Math.imul(result,16777619)>>>0;}return result;}
const affinityClue=(values:Element[]):TowerScoutClue=>({label:'Affinities detected',detail:values.map(element=>labels[element]).join(' · '),elements:[...values]});

/**
 * Projection only: no run state, random stream, reward draft or battle is changed.
 * Neighbouring doors expose different kinds of evidence. Which actual affinity
 * or fighter is detected is fixed by the room's seeded map identity.
 */
export function towerRoomIntel(room:TowerRoom):TowerRoomIntel {
 if(!room.enemies.length){
  const reward=room.kind==='recruit'?'Choose a champion or creature. Party limit: 3.':room.kind==='event'?'Choose an eligible spell, training (up to 2 affinity) or recruit.':'Eligible choices: recovery (up to 4 HP each), training, a spell or a recruit.';
  const clues:TowerScoutClue[]=room.kind==='event'?[{label:'Cost',detail:'First fighter pays 2 HP; requires at least 3 HP.'}]:room.kind==='recruit'?[{label:'Recruitment',detail:'Starting champions stay. At 3 members, replace a recruit or creature.'}]:[{label:'Rest',detail:'No health cost to enter.'}];
  return {profile:'service',heading:'Safe room',risk:'No battle',reward,enemyCount:0,clues,unknowns:['Exact reward choices']};
 }
 const lane=Number(room.id.match(/-(\d+)$/)?.[1]??0);
 const profile=profiles[(room.floor+lane)%profiles.length];
 const salt=`${room.mapId}:${room.id}:scouting`;
 const present=elements.filter(element=>room.enemies.some(enemy=>(enemy.affinities[element]??0)>0));
 const ranked=[...present].sort((a,b)=>hash(`${salt}:${a}`)-hash(`${salt}:${b}`)||elements.indexOf(a)-elements.indexOf(b));
 const boss=room.floor===9;
 const result:TowerRoomIntel={
  profile,heading:{elements:'Element traces',sighting:'Sighting',terrain:'Ground report'}[profile],
  risk:boss?'Final battle':room.kind==='elite'?'Elite battle':'Battle',
  reward:boss?'Defeat the entire enemy team to clear the tower. Learn defeated foes’ spells.':`Learn defeated foes’ spells; choose one eligible reward. ${room.kind==='elite'?'Training, when offered, grants up to 2 affinity. ':''}Each ally recovers 1 HP after victory.`,
  enemyCount:room.enemies.length,clues:[],unknowns:[],
 };
 const motif=towerMotifFromMapId(room.mapId);
 if(motif)result.clues.push({label:TOWER_MOTIF_INFO[motif].name,detail:TOWER_MOTIF_INFO[motif].detail});
 if(profile==='elements'){
  result.clues.push(affinityClue(ranked.slice(0,2)));
  result.unknowns=['Enemy identities and spells','Terrain',...(present.length>2?['Other affinities']:[])];
 }else if(profile==='sighting'){
  const champions=room.enemies.filter(enemy=>!enemy.creatureId);
  const candidates=champions.length?champions:room.enemies;
  const enemy=candidates[hash(`${salt}:sighting`)%candidates.length];
  const champion=getChampion(enemy.championId),creature=enemy.creatureId?getCreature(enemy.creatureId):undefined;
  const name=enemy.displayName??creature?.name??champion.name;
  result.knownEnemy={name,championId:enemy.championId,...(enemy.creatureId?{creatureId:enemy.creatureId}:{}),kind:enemy.creatureId?'creature':'champion',enemyId:enemy.id,position:room.enemies.indexOf(enemy)+1};
  result.clues.push({label:'Spotted',detail:`${name} · ${creature?`${creature.strengthClass} creature`:'champion'}`},affinityClue([champion.element]));
  result.unknowns=[...(room.enemies.length>1?[`${room.enemies.length-1} other ${room.enemies.length===2?'enemy':'enemies'}`]:[]),'Spell kits','Terrain'];
 }else{
  result.environment=room.environment;
  const ground=terrain[room.environment];
  result.clues.push({label:ground.name,detail:ground.effect},affinityClue(ranked.slice(0,1)));
  result.unknowns=['Enemy identities and spells',...(present.length>1?['Other affinities']:[])];
 }
 return result;
}
