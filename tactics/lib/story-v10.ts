import {CHAMPIONS} from './roster-v10.ts';
import {getSignature} from './spells-v10.ts';
import {createSimGame,restoreSimState,type SimState} from './tactics-v10.ts';

export type StoryProgress={format:1;defeated:string[]};
export type StoryEncounter={id:string;championId:string;mapId:string;opponents:[string,string,string];title:string;situation:string};
export const STORY_PROGRESS_KEY='hex-confluence-story-v10';

// Fixed companions and seeds keep an encounter replayable as the player's spell library grows.
const ENCOUNTER_DETAILS:Record<string,[string,string,string,string]>={
  oh_tipi:['leaf_hidden','grace_reava','The River Keeper','Oh Tipi braces his company against the current. Pulls will not move an anchored defender; make him choose which well to protect.'],
  s_wayne:['djonah_thaan','haara','A Small Debt','S. Wayne has counted your Flux before you arrive. Leave enough in reserve to recover from his theft.'],
  red_baron:['urzh','jan_wicked','The Last Redoubt','The Baron refuses to yield his well. His strongest protection arrives next exchange: strike before it settles, or take another route.'],
  grace_reava:['oh_tipi','spai_si','Ribbon in the Reeds','Grace Riva catches the whole front line with one pull. Give her an angle and she will use it.'],
  wa_bidi:['nico_lai','fluup','A Borrowed Spark','Wa Bidi tests an overcharged spark on anyone who stands still. It hurts him too; keep a counterattack ready.'],
  steezo:['wa_bidi','haara','One More Step','Steezo has found a clean line through the ruins. Do not let that line pass through two of your company.'],
  treevor_mason:['donnok','leaf_hidden','The Unfinished Wall','Treevor builds around his friends. Occupied hexes and wells cannot become walls; claim the gaps before the masonry closes.'],
  oll_i:['biggy_bob','urzh','No Room to Retreat',"Oll’ I keeps one desperate recovery in reserve. His later healing suffers, so pressure him again after the leap."],
  fluup:['wa_bidi','oh_tipi','The Patient Watch','Fluup saves his strength for the next exchange. A quiet round can leave his company both protected and quick.'],
  nico_lai:['steezo','faab_i_yaina','The Quiet Circuit','Waka Aren Si feeds Flux back into the company. Separate the support from the fighters before their reserves recover.'],
  spai_si:['grace_reava','dr_apex','A Step Too Far','Spai Si only needs one open hex behind you. Guard a well before his feint pushes you off it.'],
  leaf_hidden:['oh_tipi','treevor_mason','Under the Boughs','Leaf waits out hostile marks beneath the canopy. Her cleansing cannot undo a well already lost.'],
  ha_rekt:['fluup','juul_i_yaina','The Empty Centre','Ha Rekt pulls a ring inward, leaving its centre untouched. Read the empty hex as carefully as the threatened ones.'],
  dr_apex:['treevor_mason','h_le_ne','A Matter of Weight','Dr. Apex pulls one rival out of position and leaves their next spell more expensive. Keep a spare route and spare Flux.'],
  haara:['spai_si','nico_lai','Before the Sun Sets','Haara sends a tired ally back into the fight with health, Flux and haste. Make her spend that care away from the wells.'],
  hesus_christo:['oh_tipi','donnok','The Ground Answers','Hesus Christo drives a whole fan of fighters backward. Approach from different sides so one answer cannot reach everyone.'],
  grimm_bow:['s_wayne','urzh','Second Breath','Grimm Bow recovers and digs in for another stand. His haste lasts longer than his anchor; watch which protection remains.'],
  biggy_bob:['treevor_mason','wa_bidi','The Low Bellows','Biggy Bob sends concussion down a straight lane. Spread out, then make him turn before the next strike.'],
  jan_wicked:['s_wayne','grace_reava','A Measured Exit','Jan Wicked leaves a wet target behind a fresh ward. Water can invite lightning, but a simultaneous new mark gives no early bonus.'],
  ba_djoh:['oll_i','biggy_bob','The Open Lane','Ba Djoh needs a lane to scatter your company. Guard, cover the landing hexes, or deny the straight approach.'],
  urzh:['red_baron','donnok','A Promise Kept','Urzh cleans up his own position before the next exchange. His clarity answers control; another well may be the better prize.'],
  donnok:['dr_apex','haara','Beside the Anvil','Donnok puts his strongest ward on an ally. Force a choice between two threatened companions.'],
  djonah_thaan:['s_wayne','jan_wicked','The Retreating Shadow','Djonah Thaan recovers only when the strike gets through. Protection denies both the wound and the stolen breath.'],
  luuh_i_zeh:['leaf_hidden','ha_rekt','A Thread Through Stone','Luuh I Zeh roots a whole line in place. A rooted mage can still cast or guard; do not waste the round.'],
  juul_i_yaina:['ha_rekt','oh_tipi','The Last Crossing','Juul I Yaina washes a defender away from safety. Guard or anchor the well before committing the rest of your company.'],
  faab_i_yaina:['haara','treevor_mason','A Place to Land','Faab I Yaina gathers allies inside a healing burst. A clustered company gains protection but offers a broad target.'],
  joh_haynes:['dr_apex','ba_djoh','Hold the Circle','Joh Haynes clears the six surrounding hexes and stays anchored. Challenge from range or take the space after the pulse.'],
  h_le_ne:['donnok','s_wayne','The Quiet Facet','H. Le Ne cuts through wards and forest cover. Deny a clean target instead of relying on another layer of protection.'],
  fimu_yashiha:['grace_reava','haara','Dew Before Dawn','Fimu Yashiha sends a whole company forward with fresh reserves. Watch the next round’s reach, not only this round’s damage.'],
  sai_laas:['wa_bidi','spai_si','A Bright Rush','Sai Laas pays health for a fast, forceful attack. Leave room to recover, then answer while the cost still matters.'],
};

export const STORY_ENCOUNTERS:StoryEncounter[]=CHAMPIONS.map(champion=>{
  const [left,right,title,situation]=ENCOUNTER_DETAILS[champion.id];
  return {id:champion.id,championId:champion.id,mapId:`frontier:STORY-${champion.id.replaceAll('_','-').toUpperCase()}`,opponents:[champion.id,left,right],title,situation};
});

export function getStoryEncounter(id:string):StoryEncounter {
  const encounter=STORY_ENCOUNTERS.find(entry=>entry.id===id);
  if(!encounter)throw new Error('Choose a story encounter.');
  return encounter;
}

/** Separate, small browser profile. Invalid input never replaces or migrates a match save. */
export function readStoryProgress(input:unknown):StoryProgress {
  const empty:StoryProgress={format:1,defeated:[]};
  if(typeof input==='string'){
    if(input.length>4096)return empty;
    try {input=JSON.parse(input);}catch{return empty;}
  }
  if(!input||typeof input!=='object'||Array.isArray(input)||![Object.prototype,null].includes(Object.getPrototypeOf(input)))return empty;
  const value=input as Record<string,unknown>;
  if(value.format!==1||Object.keys(value).some(key=>!['format','defeated'].includes(key))||!Array.isArray(value.defeated)||value.defeated.length>CHAMPIONS.length)return empty;
  const known=new Set(value.defeated.filter((id):id is string=>typeof id==='string'&&id.length<=40));
  return {format:1,defeated:STORY_ENCOUNTERS.filter(encounter=>known.has(encounter.id)).map(encounter=>encounter.id)};
}

export function learnedStorySignatures(progress:StoryProgress):string[] {
  return readStoryProgress(progress).defeated.map(id=>getSignature(id).id);
}

export function createStoryGame(encounterId:string,roster:string[],loadouts:Record<string,string[]>={},learnedSignatures:string[]=[]):SimState {
  const encounter=getStoryEncounter(encounterId);
  return createSimGame([roster,[...encounter.opponents]],encounter.mapId,[loadouts,{}],[learnedSignatures,[]]);
}

/** Call only for the active story session. Seed, company and validated result guard
 * against accidentally awarding a practice/online result or an interrupted round.
 * This is local progression, not a server-backed proof against profile editing. */
export function awardStoryVictory(progress:StoryProgress,encounterId:string,state:unknown):StoryProgress {
  const current=readStoryProgress(progress);
  const encounter=STORY_ENCOUNTERS.find(entry=>entry.id===encounterId);
  if(!encounter||current.defeated.includes(encounter.id))return current;
  let result:SimState;
  try {result=restoreSimState(state);}catch{return current;}
  if(result.winner!==0||result.mapId!==encounter.mapId)return current;
  const opponents=result.units.filter(unit=>unit.owner===1).map(unit=>unit.championId).sort();
  if(opponents.length!==3||opponents.join('|')!==[...encounter.opponents].sort().join('|'))return current;
  return readStoryProgress({format:1,defeated:[...current.defeated,encounter.id]});
}
