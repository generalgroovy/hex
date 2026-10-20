import {CHAMPIONS,getChampion,validateChampionAffinities,allocateAffinityBudget,MAX_AFFINITY_POINTS,teamAffinityTotal,type AffinityAllocation} from './roster-v13.ts';
import {getSignature,defaultLoadout,getSpell,spellAccess,validateLoadout,effectiveSpell} from './spells-v14.ts';
import {createSimGame,restoreSimState,type SimState} from './tactics-v14.ts';
import {storyInhabitants,validateInhabitants} from './inhabitants-v14.ts';
import {CHARACTER_DESIGN} from './character-design-v13.ts';

export type StoryProgress={format:2;defeated:string[];affinities:Record<string,AffinityAllocation>};
export type StoryEncounter={id:string;championId:string;mapId:string;opponents:[string,string,string];title:string;situation:string;relationship:string;focus:string;lesson:string};
// A new combat version does not reset earned victories or affinity allocations.
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
  oll_i:['biggy_bob','urzh','No Room to Retreat',"Ollâ€™ I keeps one desperate recovery in reserve. His later healing suffers, so pressure him again after the leap."],
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
  ba_djoh:['oll_i','biggy_bob','The Open Lane','Ba Djoh needs a lane to scatter your company. Guard reduces his push by one; Anchored stops it. Deny the straight approach.'],
  urzh:['red_baron','donnok','A Promise Kept','Urzh cleans up his own position before the next exchange. His clarity answers control; another well may be the better prize.'],
  donnok:['dr_apex','haara','Beside the Anvil','Donnok puts his strongest ward on an ally. Force a choice between two threatened companions.'],
  djonah_thaan:['s_wayne','jan_wicked','The Retreating Shadow','Djonah Thaan recovers only when the strike gets through. Protection denies both the wound and the stolen breath.'],
  luuh_i_zeh:['leaf_hidden','ha_rekt','A Thread Through Stone','Luuh I Zeh roots a whole line in place. A rooted mage can still cast or guard; do not waste the round.'],
  juul_i_yaina:['ha_rekt','oh_tipi','The Last Crossing','Juul I Yaina washes a defender away from safety. Guard only reduces her two-hex push; prepare Anchored before committing to the well.'],
  faab_i_yaina:['haara','treevor_mason','A Place to Land','Faab I Yaina gathers allies inside a healing burst. A clustered company gains protection but offers a broad target.'],
  joh_haynes:['dr_apex','ba_djoh','Hold the Circle','Joh Haynes clears the six surrounding hexes and stays anchored. Challenge from range or take the space after the pulse.'],
  h_le_ne:['donnok','s_wayne','The Quiet Facet','H. Le Ne cuts through wards and forest cover. Deny a clean target instead of relying on another layer of protection.'],
  fimu_yashiha:['grace_reava','haara','Dew Before Dawn','Fimu Yashiha sends a whole company forward with fresh reserves. Watch the next roundâ€™s reach, not only this roundâ€™s damage.'],
  sai_laas:['wa_bidi','spai_si','A Bright Rush','Sai Laas pays health for a fast, forceful attack. Leave room to recover, then answer while the cost still matters.'],
};

/** One useful decision per encounter. These teach the existing objective, not side quests. */
const ENCOUNTER_LESSONS:Record<string,[string,string]>={
 oh_tipi:['Claim a well','Move toward separate wells. Each occupied well scores at the end of the turn; you may move and cast with the same character.'],
 s_wayne:['Change a shared field','On clear ground, put Water where Cinder releases Fire to make Steam. Shared fields can protect either company; natural ground can change the mixture.'],
 red_baron:['Prepare the next exchange','New Ward and Anchored protect from next turn. Take another well while the Baron prepares, or attack before his protection settles.'],
 grace_reava:['Spread the approach','Aim at ground where a rival may finish moving. Keep your company apart so one broad pull cannot catch everyone.'],
 wa_bidi:['Answer a costly attack','Wa Bidi hurts himself with Scrap Spark. Keep a healthy companion near enough to answer after his burst.'],
 steezo:['Break the firing lane','A lane spell can hit several characters. Approach from different angles rather than queueing your company on one line.'],
 treevor_mason:['Leave a route open','Wells and occupied hexes cannot become barriers. Claim a useful gap before Treevor closes the empty approaches.'],
 oll_i:['Sustain pressure','Ollâ€™ Iâ€™s recovery leaves Wither behind. Pressure him again while further healing is weaker, instead of giving him a quiet exchange.'],
 fluup:['Read a quiet turn','Guard restores extra Flux; some signatures prepare protection and movement. A turn without damage can still change the next contest.'],
 nico_lai:['Separate the support','Flux restoration keeps a company casting. Contest a second well so the support must choose which companion to help.'],
 spai_si:['Protect the landing','Guard resists one strength of combined displacement. An existing Anchor stops it; leave a safe hex behind a defender when you lack one.'],
 leaf_hidden:['Win space before damage','Cleansing removes marks, but cannot return a lost well. Use a push or a different route when repeated ailments achieve little.'],
 ha_rekt:['Read the empty centre','A ring leaves its centre untouched. Inspect the footprint before choosing a landing or clustering around the aim point.'],
 dr_apex:['Keep a reserve','Concussion makes next turnâ€™s spells cost one more Flux. Keep enough for a useful reply, or Guard while a companion takes over.'],
 haara:['Make care a choice','Threaten two different wells. A strong rescue spell matters less when saving one companion leaves another objective open.'],
 hesus_christo:['Approach from two sides','A fan pushes several nearby fighters. Split the approach so one cast cannot clear the whole company.'],
 grimm_bow:['Watch what expires','Haste and Anchored can have different durations. Check the remaining marks before spending a spell on a defender you could move next turn.'],
 biggy_bob:['Keep spells affordable','Concussion taxes the next cast rather than cancelling movement. Reposition or Guard to recover while the affected character still contributes.'],
 jan_wicked:['Prepare a mark','Bonus damage checks marks from before the exchange. Fresh Wet and a matching attack together do not earn the existing-Wet bonus.'],
 ba_djoh:['Respect combined force','Several pushes can overcome Guard. Use an existing Anchor, break the casting lane, or make the landing less valuable.'],
 urzh:['Change the threat','Clarity prevents fresh control but does not block damage. Pressure Urzh with another kind of action or take an unprotected well.'],
 donnok:['Time your protection','A new Ward does not absorb this turnâ€™s attack. Put protection on a companion before the expected clash.'],
 djonah_thaan:['Deny the recovery','Drain requires damage to get through. Guard and existing cover can deny both the wound and the attackerâ€™s healing.'],
 luuh_i_zeh:['Act while rooted','Rooted prevents movement, not spells or Guard. Choose a useful action from the current hex and use a companion to open the next route.'],
 juul_i_yaina:['Hold a crossing','A two-hex push still moves a guarding defender one hex. Prepare Anchored or plan a second character to take the well after displacement.'],
 faab_i_yaina:['Weigh the gathering','A healing burst rewards a close company but offers a broad target. Gather only the characters who need its care.'],
 joh_haynes:['Use the outer edge','Joh Haynes clears the six hexes beside him. Cast from farther away or take space after the ring has passed.'],
 h_le_ne:['Move out of certainty','Piercing damage ignores Ward and forest cover. A different landing can do more than another layer of protection.'],
 fimu_yashiha:['Plan for new reach','Haste changes next turnâ€™s movement, not the current move. Use the quiet exchange to arrange where that extra effort will matter.'],
 sai_laas:['Read the whole landscape','Three creatures announce different fields. Use one useful release, interrupt a dangerous one, or leave their ground; you need not combine everything.'],
};

// One concrete connection per encounter. These are introductions, not extra objectives.
const INHABITANT_RELATIONSHIPS:Record<string,string>={
  oh_tipi:'has left a gap in the riverbank for Puddle and its young.',
  s_wayne:'owes Cinder a new nest after borrowing the foxâ€™s warmest stone.',
  red_baron:'has made room for Pebble inside his last redoubt.',
  grace_reava:'hangs ribbons for Pip to follow, with Wick lighting the return path.',
  wa_bidi:'borrowed Hushâ€™s kettle while Morrow was asleep inside it.',
  steezo:'has built a little kiln for Kiln; Crackle keeps stealing its sparks.',
  treevor_mason:'is leaving two gaps in the wall for Saffron and Soot.',
  oll_i:'is repairing the bank that Mossback and Skitter keep digging through.',
  fluup:'takes the evening watch beside Ripple and Rimeâ€™s pools.',
  nico_lai:'has strung quiet bells between Tumbleâ€™s hollow and Facetâ€™s grove.',
  spai_si:'follows Tinselâ€™s flight over the mushrooms Loam has planted.',
  leaf_hidden:'lets Whisper and Vesper shelter beneath the oldest bough.',
  ha_rekt:'is trying to warm Kettlebackâ€™s spring without disturbing Billowâ€™s fishing pool.',
  dr_apex:'has set out two shallow bowls for Honeydew and Smudge.',
  haara:'is cooling Rattleâ€™s scorched mane while Aureole waits for the same care.',
  hesus_christo:'has piled warm stones for Clinker beneath Flickerâ€™s nesting ridge.',
  grimm_bow:'keeps a lamp for Solace and leaves the door open for Scurry.',
  biggy_bob:'has lowered the bellows so Bracken and Pearl can hear the rain.',
  jan_wicked:'follows the channels Dapple digs beneath Nimbusâ€™s passing showers.',
  ba_djoh:'has cleared a narrow passage between Velvetâ€™s mist and Opalâ€™s pool.',
  urzh:'promised Chime a quiet grove; Burrow is still digging beneath it.',
  donnok:'has moved the anvil away from Hollowbellâ€™s seedlings and Gossamerâ€™s resting place.',
  djonah_thaan:'is tending Marigoldâ€™s spring after Rumblewake swept through the valley.',
  luuh_i_zeh:'has threaded roots around Crockâ€™s shelters, leaving Sunshower a clear crossing.',
  juul_i_yaina:'shares the last crossing with Fathom, Duskettle and Corona.',
  faab_i_yaina:'has cleared a resting place for Cairn, Mica and the restless Comet.',
  joh_haynes:'keeps a space open between Cressâ€™s meadow and Murmur and Lumenrootâ€™s wet roots.',
  h_le_ne:'studies the light around Prism, Belfry and Verdant without taking anything from their grove.',
  fimu_yashiha:'brings morning water to Old Cinder, Stillwater and Wayfarer.',
  sai_laas:'brought Firstbud to this valley; Orrery and Old Reed followed.',
};

export const STORY_ENCOUNTERS:StoryEncounter[]=CHAMPIONS.map(champion=>{
  const [left,right,title,situation]=ENCOUNTER_DETAILS[champion.id];
  const [focus,lesson]=ENCOUNTER_LESSONS[champion.id];
  return {id:champion.id,championId:champion.id,mapId:`frontier:STORY-${champion.id.replaceAll('_','-').toUpperCase()}`,opponents:[champion.id,left,right],title,situation,relationship:`${champion.name} ${INHABITANT_RELATIONSHIPS[champion.id]}`,focus,lesson};
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

/** Preview the actual opponent, including its fixed encounter investment. */
export function encounterSignature(encounterId:string){
  const encounter=getStoryEncounter(encounterId);
  return effectiveSpell(encounter.championId,getSignature(encounter.championId).id,encounterAffinities(encounterId)[encounter.championId]);
}

export function encounterLoadouts(encounterId:string):Record<string,string[]> {
  const affinities=encounterAffinities(encounterId);
  return Object.fromEntries(getStoryEncounter(encounterId).opponents.map(id=>{
    const kit=defaultLoadout(id,affinities[id]);
    // Each authored replacement keeps its slot's ingredient and tactical purpose.
    // An upgrade is optional: higher level alone is not a reason to discard a tool.
    for(const upgrade of CHARACTER_DESIGN[id].upgrades){
      if(!kit.includes(upgrade.spellId)&&spellAccess(id,upgrade.spellId,affinities[id]).unlocked&&getSpell(kit[upgrade.slot]).element===getSpell(upgrade.spellId).element)kit[upgrade.slot]=upgrade.spellId;
    }
    return [id,validateLoadout(id,kit,affinities[id])];
  }));
}

export type StoryRecommendation={encounterId:string;companyAffinity:number;opponentAffinity:number;reason:string};
/** Compare fixed encounters to the actual selected company, not its unspent budget. */
export function recommendStoryEncounter(progress:StoryProgress,roster:readonly string[]=['oh_tipi','wa_bidi','treevor_mason'],allocations?:Readonly<Record<string,AffinityAllocation>>):StoryRecommendation|null {
  const current=readStoryProgress(progress),companyAffinity=teamAffinityTotal(roster,allocations??storyTeamAffinities(current,roster));
  const remaining=STORY_ENCOUNTERS.filter(encounter=>!current.defeated.includes(encounter.id)).map((encounter,index)=>({encounter,index,total:teamAffinityTotal(encounter.opponents,encounterAffinities(encounter.id))}));
  remaining.sort((left,right)=>Math.abs(left.total-companyAffinity)-Math.abs(right.total-companyAffinity)||left.index-right.index);
  const next=remaining[0];if(!next)return null;
  return {encounterId:next.encounter.id,companyAffinity,opponentAffinity:next.total,reason:next.total===companyAffinity?'Same total affinity as your company.':`${Math.abs(next.total-companyAffinity)} ${next.total>companyAffinity?'more':'less'} team affinity than your company.`};
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
