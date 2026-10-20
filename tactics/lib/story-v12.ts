import {CHAMPIONS,getChampion,validateChampionAffinities,allocateAffinityBudget,MAX_AFFINITY_POINTS,type AffinityAllocation} from './roster-v11.ts';
import {getSignature,defaultLoadout,SPELLS,spellAccess,validateLoadout} from './spells-v12.ts';
import {createSimGame,restoreSimState,type SimState} from './tactics-v12.ts';
import {storyInhabitants,validateInhabitants} from './inhabitants-v12.ts';

export type StoryProgress={format:2;defeated:string[];affinities:Record<string,AffinityAllocation>};
export type StoryEncounter={id:string;championId:string;mapId:string;opponents:[string,string,string];title:string;situation:string;relationship:string};
// Rules 12 adds inhabitants, not a new progression format. Keep existing victories.
export const STORY_PROGRESS_KEY='hex-confluence-story-v11';
export const LEGACY_STORY_PROGRESS_KEY='hex-confluence-story-v10';
const plainObject=(input:unknown):input is Record<string,unknown>=>!!input&&typeof input==='object'&&!Array.isArray(input)&&[Object.prototype,null].includes(Object.getPrototypeOf(input));
const budgetFor=(victories:number)=>Math.min(MAX_AFFINITY_POINTS,5+victories);

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

// One concrete connection per encounter. These are introductions, not extra objectives.
const INHABITANT_RELATIONSHIPS:Record<string,string>={
  oh_tipi:'has left a gap in the riverbank for Puddle and its young.',
  s_wayne:'owes Cinder a new nest after borrowing the fox’s warmest stone.',
  red_baron:'has made room for Pebble inside his last redoubt.',
  grace_reava:'hangs ribbons for Pip to follow, with Wick lighting the return path.',
  wa_bidi:'borrowed Hush’s kettle while Morrow was asleep inside it.',
  steezo:'has built a little kiln for Kiln; Crackle keeps stealing its sparks.',
  treevor_mason:'is leaving two gaps in the wall for Saffron and Soot.',
  oll_i:'is repairing the bank that Mossback and Skitter keep digging through.',
  fluup:'takes the evening watch beside Ripple and Rime’s pools.',
  nico_lai:'has strung quiet bells between Tumble’s hollow and Facet’s grove.',
  spai_si:'follows Tinsel’s flight over the mushrooms Loam has planted.',
  leaf_hidden:'lets Whisper and Vesper shelter beneath the oldest bough.',
  ha_rekt:'is trying to warm Kettleback’s spring without disturbing Billow’s fishing pool.',
  dr_apex:'has set out two shallow bowls for Honeydew and Smudge.',
  haara:'is cooling Rattle’s scorched mane while Aureole waits for the same care.',
  hesus_christo:'has piled warm stones for Clinker beneath Flicker’s nesting ridge.',
  grimm_bow:'keeps a lamp for Solace and leaves the door open for Scurry.',
  biggy_bob:'has lowered the bellows so Bracken and Pearl can hear the rain.',
  jan_wicked:'follows the channels Dapple digs beneath Nimbus’s passing showers.',
  ba_djoh:'has cleared a narrow passage between Velvet’s mist and Opal’s pool.',
  urzh:'promised Chime a quiet grove; Burrow is still digging beneath it.',
  donnok:'has moved the anvil away from Hollowbell’s seedlings and Gossamer’s resting place.',
  djonah_thaan:'is tending Marigold’s spring after Rumblewake swept through the valley.',
  luuh_i_zeh:'has threaded roots around Crock’s shelters, leaving Sunshower a clear crossing.',
  juul_i_yaina:'shares the last crossing with Fathom, Duskettle and Corona.',
  faab_i_yaina:'has cleared a resting place for Cairn, Mica and the restless Comet.',
  joh_haynes:'keeps a space open between Cress’s meadow and Murmur and Lumenroot’s wet roots.',
  h_le_ne:'studies the light around Prism, Belfry and Verdant without taking anything from their grove.',
  fimu_yashiha:'brings morning water to Old Cinder, Stillwater and Wayfarer.',
  sai_laas:'brought Firstbud to this valley; Orrery and Old Reed followed.',
};

export const STORY_ENCOUNTERS:StoryEncounter[]=CHAMPIONS.map(champion=>{
  const [left,right,title,situation]=ENCOUNTER_DETAILS[champion.id];
  return {id:champion.id,championId:champion.id,mapId:`frontier:STORY-${champion.id.replaceAll('_','-').toUpperCase()}`,opponents:[champion.id,left,right],title,situation,relationship:`${champion.name} ${INHABITANT_RELATIONSHIPS[champion.id]}`};
});

export function getStoryEncounter(id:string):StoryEncounter {
  const encounter=STORY_ENCOUNTERS.find(entry=>entry.id===id);
  if(!encounter)throw new Error('Choose a story encounter.');
  return encounter;
}

/** Separate, small browser profile. Invalid input never replaces or migrates a match save. */
export function readStoryProgress(input:unknown):StoryProgress {
  const empty:StoryProgress={format:2,defeated:[],affinities:{}};
  if(typeof input==='string'){
    if(input.length>32768)return empty;
    try {input=JSON.parse(input);}catch{return empty;}
  }
  if(!plainObject(input))return empty;
  const value=input;
  const keys=value.format===1?['format','defeated']:['format','defeated','affinities'];
  if(![1,2].includes(value.format as number)||Object.keys(value).some(key=>!keys.includes(key))||!Array.isArray(value.defeated)||value.defeated.length>CHAMPIONS.length)return empty;
  const known=new Set(value.defeated.filter((id):id is string=>typeof id==='string'&&id.length<=40));
  const defeated=STORY_ENCOUNTERS.filter(encounter=>known.has(encounter.id)).map(encounter=>encounter.id),affinities:Record<string,AffinityAllocation>={};
  // A damaged allocation should not erase completed encounters or other characters.
  if(value.format===2&&plainObject(value.affinities)&&Object.keys(value.affinities).length<=CHAMPIONS.length){
    for(const champion of CHAMPIONS){
      if(!Object.hasOwn(value.affinities,champion.id))continue;
      try {affinities[champion.id]=validateChampionAffinities(champion.id,value.affinities[champion.id],budgetFor(defeated.length));}catch{/* Keep this character's canonical starting affinities. */}
    }
  }
  return {format:2,defeated,affinities};
}

/** A first victory grants one spendable point to every character, up to 18 each. */
export function storyAffinityBudget(progress:StoryProgress):number {return budgetFor(readStoryProgress(progress).defeated.length);}

export function storyAffinities(progress:StoryProgress,championId:string):AffinityAllocation {
  const champion=getChampion(championId),current=readStoryProgress(progress);
  return {...(current.affinities[championId]??champion.affinities)};
}

/** Reassign earned points freely in camp; original affinities remain that character's floor. */
export function setStoryAffinity(progress:StoryProgress,championId:string,input:unknown):StoryProgress {
  const current=readStoryProgress(progress),allocation=validateChampionAffinities(championId,input,budgetFor(current.defeated.length));
  return {...current,affinities:{...current.affinities,[championId]:allocation}};
}

export function storyTeamAffinities(progress:StoryProgress,roster:readonly string[]):Record<string,AffinityAllocation> {
  return Object.fromEntries(roster.map(id=>[id,storyAffinities(progress,id)]));
}

export function learnedStorySignatures(progress:StoryProgress):string[] {
  return readStoryProgress(progress).defeated.map(id=>getSignature(id).id);
}

/** Encounter strength is fixed, so growing a company never secretly strengthens its opponent. */
export function encounterAffinities(encounterId:string):Record<string,AffinityAllocation> {
  const encounter=getStoryEncounter(encounterId),budget=5+Math.floor(STORY_ENCOUNTERS.indexOf(encounter)/3);
  return Object.fromEntries(encounter.opponents.map(id=>[id,allocateAffinityBudget(id,budget)]));
}

export function encounterLoadouts(encounterId:string):Record<string,string[]> {
  const affinities=encounterAffinities(encounterId);
  return Object.fromEntries(getStoryEncounter(encounterId).opponents.map(id=>{
    const kit=defaultLoadout(id,affinities[id]);
    const advanced=SPELLS.filter(spell=>spell.level>=4&&spellAccess(id,spell.id,affinities[id]).unlocked&&!kit.includes(spell.id)).sort((a,b)=>b.level-a.level||Number(b.element===getChampion(id).element)-Number(a.element===getChampion(id).element));
    if(advanced[0])kit[2]=advanced[0].id;
    return [id,validateLoadout(id,kit,affinities[id])];
  }));
}

export function createStoryGame(encounterId:string,roster:string[],loadouts:Record<string,string[]>={},learnedSignatures:string[]=[],affinities:Record<string,AffinityAllocation>={}):SimState {
  const encounter=getStoryEncounter(encounterId);
  const state=createSimGame([roster,[...encounter.opponents]],encounter.mapId,[loadouts,encounterLoadouts(encounterId)],[learnedSignatures,[]],[affinities,encounterAffinities(encounterId)]);
  return {...state,inhabitants:storyInhabitants(state.mapId,state.cells)};
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
  try {validateInhabitants(result.inhabitants,result.mapId,result.round,result.cells);}catch{return current;}
  const opponents=result.units.filter(unit=>unit.owner===1).map(unit=>unit.championId).sort();
  if(opponents.length!==3||opponents.join('|')!==[...encounter.opponents].sort().join('|'))return current;
  const expected=encounterAffinities(encounter.id);
  for(const opponent of result.units.filter(unit=>unit.owner===1)){
    const canonical=expected[opponent.championId];
    if(Object.keys(opponent.affinities).length!==Object.keys(canonical).length||Object.entries(canonical).some(([element,points])=>opponent.affinities[element as keyof AffinityAllocation]!==points))return current;
  }
  return readStoryProgress({...current,defeated:[...current.defeated,encounter.id]});
}
