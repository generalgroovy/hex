/** Authored creature techniques. The old catalogue remains an immutable save contract. */
import {CREATURES,getCreature} from './campaign-creatures-v19.ts';
import type {Element} from './game.ts';
import type {Spell as PreviousSpell,StatusApplication,StatusId} from './spells-v16.ts';
export type CreatureSpell=PreviousSpell&{creatureId:string;fieldElements?:Element[];counterplay:string};
type Options=Partial<Omit<PreviousSpell,'id'|'name'|'element'|'description'|'signatureChampionId'|'level'|'branch'>>;
type Entry=readonly [creature:string,name:string,options:Options,counterplay:string];
const mark=(id:StatusId,turns=1,power=1):StatusApplication=>({id,turns,power});

// Precision tools keep their reach. Broad tools trade damage, recovery, friendly
// fire or personal safety for coverage; none improves every part of a base cast.
const pure:Entry[]=[
 ['Cinder','Cinder Pounce',{range:2,damage:1,bonus:'burn',bonusDamage:2,self:[mark('haste')],cooldown:1},'Keep out of its short reach; Wet removes its Burn setup.'],
 ['Wicktail','Coal Stitch',{range:2,heal:2,friendly:[mark('ward')],selfDamage:1,cooldown:2},'It sacrifices health and cannot cleanse; pressure the caster.'],
 ['Ashwing','Ash Feathers',{shape:'sweep',radius:1,range:3,damage:1,harmful:[mark('blind')],cooldown:2},'Spread out of the narrow fan; Clarity blocks Blind.'],
 ['Hearthback','Hearth Shell',{range:0,friendly:[mark('ward',2,2),mark('anchored')],heal:1,cooldown:2},'Self-only protection starts next round; use piercing attacks.'],
 ['Kilnhorn','Kiln Charge',{range:2,damage:2,push:2,selfDamage:1,cooldown:3},'Anchored prevents the shove; its close-range recoil leaves an opening.'],
 ['Sunmane','Sunmane Crown',{range:0,shape:'ring',radius:1,damage:1,harmful:[mark('burn')],self:[mark('clarity')],cooldown:3},'Stand beyond the adjacent ring or extinguish Burn with Wet.'],
 ['Puddle','Puddle Splash',{range:2,heal:1,cleanse:true,friendly:[mark('wet',2)],recharge:1,cooldown:2},'Only one nearby ally recovers; separate the patient from Puddle or pressure another target.'],
 ['Brookling','Reed Hook',{range:2,push:-2,harmful:[mark('wet')],cooldown:2},'No direct damage; Guard reduces the pull and Anchored stops it.'],
 ['Reedcoil','Ice Thread',{range:4,shape:'line',damage:1,freeze:true,cooldown:2},'The line hits allies too; Fire thaws its ice.'],
 ['Tideplume','Stillwater Wing',{shape:'sweep',radius:1,heal:1,friendly:[mark('wet'),mark('anchored')],cooldown:2},'A narrow allied formation helps it; protection begins next round.'],
 ['Iceback','Ice Carapace',{range:0,shape:'ring',radius:1,freeze:true,harmful:[mark('chilled')],self:[mark('ward',1,2)],cooldown:3},'Stay outside the shell ring; Fire melts ice and Clarity resists Chilled.'],
 ['Floodhorn','Flood Break',{range:2,shape:'sweep',radius:1,push:2,damage:1,harmful:[mark('wet')],cooldown:3},'Keep room behind you; Anchored stops force and the fan can strike its allies.'],
 ['Pebble','Pebble Shelter',{range:1,friendly:[mark('ward',2,2)],dispel:true,cooldown:2},'Short reach requires clustering; piercing damage ignores its Ward.'],
 ['Burrpaw','Burr Snare',{range:2,damage:1,harmful:[mark('rooted')],self:[mark('anchored')],cooldown:2},'Clarity or Resolve blocks Rooted; the caster must come close.'],
 ['Cairnback','Cairn Tackle',{range:2,damage:1,push:2,dispel:true,cooldown:2},'Anchored prevents impact; it has to enter close casting range.'],
 ['Rootspring','Root Nest',{range:2,heal:1,friendly:[mark('anchored',2),mark('ward',1,2)],cooldown:2},'It protects one position but cannot cleanse or stop current damage.'],
 ['Flintstag','Flint Antler',{range:4,shape:'line',damage:1,pierce:true,bonus:'wounded',bonusDamage:1,cooldown:3},'Move off the ray; its extra damage needs an already wounded target.'],
 ['Ironcoil','Coil Gate',{range:3,shape:'wall',radius:1,wall:true,self:[mark('anchored')],cooldown:3},'Occupied hexes stay open; dispel the gate or move around its three cells.'],
 ['Pip','Pip Updraft',{range:2,push:1,self:[mark('haste')],cooldown:1},'No direct damage; Guard stops its single push.'],
 ['Whisk','Whisk Feint',{range:2,damage:1,harmful:[mark('concussed')],self:[mark('haste')],cooldown:2},'Its pressure requires close range; Clarity blocks the Flux tax.'],
 ['Whistle','Whistle Relay',{range:4,recharge:1,friendly:[mark('haste',2)],cooldown:2},'One ally gains mobility, with no healing or immediate protection.'],
 ['Vaneheron','Crosswind Bill',{range:3,shape:'sweep',radius:1,push:-1,harmful:[mark('concussed')],cooldown:2},'Guard blocks the pull; allies in its fan suffer the same disruption.'],
 ['Stormwing','Stormwing Shelter',{range:0,shape:'ring',radius:1,friendly:[mark('haste'),mark('clarity')],recharge:1,cooldown:3},'The caster gains no ring benefit; break its adjacent formation.'],
 ['Thunderhorn','Thunder Stomp',{range:0,shape:'ring',radius:1,damage:2,harmful:[mark('concussed')],selfDamage:1,cooldown:3},'Only adjacent cells are hit; recoil punishes an empty stomp.'],
 ['Wick','Wick Lantern',{range:2,heal:1,friendly:[mark('clarity',2)],cooldown:1},'It heals only one ally and cannot remove existing ailments.'],
 ['Lanternpaw','Lantern Guard',{range:0,friendly:[mark('ward',2,2),mark('clarity')],cooldown:2},'Self-only Ward starts next round; piercing bypasses it.'],
 ['Glimmerfin','Mirror Needle',{range:4,damage:1,heal:1,harm:'enemy',pierce:true,cooldown:2},'One precise target; ordinary healing is stronger if no attack is needed.'],
 ['Dawnkeeper','Dawn Rinse',{range:2,shape:'sweep',radius:1,cleanse:true,friendly:[mark('clarity')],cooldown:2},'It removes control but grants no health or Ward.'],
 ['Haloheart','Halo Refuge',{range:2,shape:'ring',radius:1,friendly:[mark('ward',1,2)],heal:1,cooldown:3},'The centre is excluded; spread pressure across the ring.'],
 ['Sunmeadow','Meadow Seed',{range:2,shape:'burst',radius:1,heal:1,recharge:1,selfDamage:1,cooldown:3},'It pays health for clustered support and cannot cleanse.'],
 ['Morrow','Morrow Bite',{range:1,damage:2,drain:1,cooldown:1},'Stay beyond biting reach; preventing damage also prevents its drain.'],
 ['Duskmote','Dusk Dust',{range:2,harmful:[mark('blind'),mark('wither',2)],cooldown:2},'No direct damage; cleansing removes both marks.'],
 ['Inkcoil','Ink Knot',{range:3,push:-1,steal:1,harmful:[mark('rooted')],cooldown:2},'Guard blocks its pull; spend Flux before theft and use Clarity against Rooted.'],
 ['Shadefox','Shade Rend',{range:2,damage:2,bonus:'wither',bonusDamage:1,self:[mark('haste')],cooldown:2},'Cleanse Wither to remove its bonus; the fox must approach.'],
 ['Nightplume','Night Quill',{range:4,shape:'line',damage:1,steal:1,cooldown:3},'Step off the line and spend Flux before the exchange.'],
 ['Hollowhorn','Hollow Toll',{range:0,shape:'ring',radius:1,damage:1,drain:1,harmful:[mark('wither')],cooldown:3},'Keep distance; Ward can stop both damage and drain.'],
];

// Every mixed technique lays its complete lineage. Larger mixtures stay precise
// and recover slowly: their chemistry is a tactical commitment, not free power.
const mixed:Entry[]=[
 ['Hush','Kettle Breath',{shape:'sweep',radius:1,range:2,harmful:[mark('blind')],cooldown:2},'Steam obscures both sides; move around the fan or bring Clarity.'],
 ['Kiln','Kiln Press',{range:2,damage:1,harmful:[mark('concussed')],cooldown:2},'Its molten ground is dangerous to its own team; pull it away from the lane.'],
 ['Crackle','Spark Skip',{range:3,shape:'line',damage:1,bonus:'wet',bonusDamage:1,cooldown:2},'Avoid the ray and remove Wet before its lightning setup.'],
 ['Saffron','Sun Circle',{range:0,shape:'ring',radius:1,friendly:[mark('ward')],harm:'enemy',damage:1,cooldown:2},'The centre and distant cells stay clear; its protection starts next round.'],
 ['Soot','Ember Cache',{range:2,damage:1,harmful:[mark('burn'),mark('wither')],cooldown:2},'Wet prevents Burn; cleansing removes its delayed pressure.'],
 ['Mossback','Mud Bank',{range:2,push:1,friendly:[mark('anchored')],cooldown:2},'It prepares one rough crossing; Anchored stops displacement.'],
 ['Skitter','Sleet Run',{range:3,shape:'line',freeze:true,self:[mark('haste')],cooldown:2},'It deals no direct damage; Fire and alternate routes break the slide.'],
 ['Ripple','Mirror Pool',{range:3,heal:1,cleanse:true,cooldown:2},'One pool supports one position; force its beneficiary away.'],
 ['Rime','Midnight Well',{range:2,shape:'ring',radius:1,freeze:true,harmful:[mark('wither')],cooldown:2},'The centre is open; cleanse Wither and avoid stepping onto its ring.'],
 ['Tumble','Grit Sweep',{range:2,shape:'sweep',radius:1,push:1,harmful:[mark('blind')],cooldown:2},'Guard stops its push; Clarity protects against grit.'],
 ['Facet','Crystal Arch',{range:2,shape:'wall',radius:1,wall:true,cooldown:2},'Occupied cells remain open; break or go around the three-cell arch.'],
 ['Loam','Root Bed',{range:2,heal:1,friendly:[mark('anchored')],cooldown:2},'It cannot cleanse; strike before the bed can sustain its ally.'],
 ['Tinsel','Dawn Flight',{range:3,shape:'line',friendly:[mark('haste')],harm:'enemy',damage:1,cooldown:2},'Avoid lining up; the lane helps allied movement but supplies no Ward.'],
 ['Whisper','Evening Fold',{range:3,push:-1,harmful:[mark('blind')],cooldown:2},'Guard counters the pull; its precise mark cannot catch a spread formation.'],
 ['Vesper','Eclipse Wing',{range:0,shape:'ring',radius:1,harmful:[mark('blind')],friendly:[mark('clarity')],harm:'enemy',cooldown:2},'Stand beyond the adjacent ring; existing ailments are not cleansed.'],
 ['Kettleback','Warm Spring',{range:1,heal:1,friendly:[mark('ward')],cooldown:3},'Very short reach; separate the tortoise from its patient.'],
 ['Billow','Cloud Passage',{range:3,shape:'line',harmful:[mark('blind')],cooldown:3},'It deals no direct damage; cross the cloud lane after its long recovery.'],
 ['Honeydew','Honey Rain',{range:2,heal:1,recharge:1,selfDamage:1,cooldown:3},'It pays health to help one ally; punish the exposed healer.'],
 ['Smudge','Soot Wash',{range:2,damage:1,steal:1,cleanse:true,cooldown:3},'One precise target; spend Flux before theft and avoid bunching on its field.'],
 ['Rattle','Cinder Rattle',{range:2,shape:'sweep',radius:1,damage:1,push:1,selfDamage:1,cooldown:3},'The close fan and recoil expose Rattle; Guard resists force.'],
 ['Aureole','Forge Halo',{range:0,shape:'ring',radius:1,friendly:[mark('ward',1,2)],cooldown:3},'The caster is outside its own blessing; attack it or break the ring.'],
 ['Clinker','Coal Vault',{range:0,heal:1,friendly:[mark('ward',1,2),mark('anchored')],cooldown:3},'Self-only shelter cannot rescue companions; piercing ignores Ward.'],
 ['Flicker','Sun Zigzag',{range:4,shape:'line',damage:1,harm:'enemy',selfDamage:1,cooldown:3},'Its long ray costs health; attack after it commits.'],
 ['Scurry','Ash Burrow',{range:2,damage:1,self:[mark('haste',2)],cooldown:3},'Short reach and slow recovery; Clarity does not protect it from direct attacks.'],
 ['Solace','Last Lamp',{range:2,heal:2,cleanse:true,selfDamage:1,cooldown:3},'Pressure the wounded caster; the lamp can only save one ally.'],
 ['Bracken','Reed Passage',{range:3,shape:'line',push:1,friendly:[mark('anchored')],cooldown:3},'No direct damage; Guard keeps units out of an unwanted crossing.'],
 ['Pearl','Clear Pool',{range:2,shape:'ring',radius:1,heal:1,cleanse:true,cooldown:3},'The centre receives nothing; force allies out of its small ring.'],
 ['Dapple','Peat Channel',{range:2,push:-2,harmful:[mark('wither')],cooldown:3},'Anchored prevents the pull; cleanse before relying on recovery.'],
 ['Nimbus','Shepherd Rain',{range:2,shape:'sweep',radius:1,heal:1,friendly:[mark('haste')],cooldown:3},'Only a narrow fan benefits; it cannot cleanse or grant Ward.'],
 ['Velvet','Mist Coil',{range:3,damage:1,push:-1,harmful:[mark('blind')],cooldown:3},'Guard stops the pull; Clarity blocks the range loss.'],
 ['Opal','Moon Reflection',{range:2,heal:1,harm:'enemy',damage:1,pierce:true,cooldown:3},'One target and long recovery; move away from its reflected field.'],
 ['Chime','Reed Chord',{range:3,recharge:1,friendly:[mark('clarity'),mark('haste')],cooldown:3},'It trades its turn for readiness; attack the recipient before new mobility matters.'],
 ['Burrow','Dust Door',{range:2,shape:'sweep',radius:1,push:1,harmful:[mark('concussed')],cooldown:3},'Guard and Clarity answer its disruption; no direct damage is dealt.'],
 ['Hollowbell','Seed Shelter',{range:2,heal:1,friendly:[mark('ward',2,1)],cooldown:3},'It cannot remove Wither; piercing bypasses its long-lived Ward.'],
 ['Gossamer','Horizon Veil',{range:0,shape:'ring',radius:1,friendly:[mark('clarity',2)],harmful:[mark('blind')],harm:'enemy',cooldown:3},'The caster stays exposed and only adjacent allies gain the veil.'],
 ['Rumblewake','Weather Front',{range:2,shape:'sweep',radius:1,push:2,selfDamage:1,cooldown:3},'Anchor against force; its costly close fan can displace friends too.'],
 ['Marigold','Geyser Bloom',{range:2,heal:1,push:1,cooldown:3},'The push also moves allies; choose stable footing or Anchor the patient.'],
 ['Crock','Bog Kiln',{range:2,shape:'wall',radius:1,wall:true,cooldown:3},'Its three-cell shelter leaves occupied tiles open; dispelling reopens the lane.'],
 ['Sunshower','Turning Rain',{range:3,shape:'line',cleanse:true,friendly:[mark('wet')],cooldown:3},'A precise cleansing lane grants no direct healing.'],
 ['Fathom','Thunder Below',{range:2,damage:1,bonus:'wet',bonusDamage:1,harmful:[mark('concussed')],cooldown:3},'Lose Wet before it strikes; Clarity prevents the next-round cost increase.'],
 ['Duskettle','Mist Lantern',{range:2,heal:1,friendly:[mark('clarity')],self:[mark('ward')],cooldown:3},'It guards its caster later, not its patient now; pressure the single healed ally.'],
 ['Corona','Glass Scatter',{range:3,shape:'sweep',radius:1,damage:1,pierce:true,selfDamage:1,cooldown:3},'A narrow fan costs the caster health; spread out before it fires.'],
 ['Cairn','Ash Windbreak',{range:2,friendly:[mark('anchored',2),mark('ward',1,2)],cooldown:3},'One ally gains protection next round; piercing and immediate attacks remain effective.'],
 ['Mica','Kiln Shroud',{range:0,friendly:[mark('clarity',2),mark('ward',1,2)],recharge:1,cooldown:3},'Self-only preparation leaves its companions unsupported.'],
 ['Comet','Homeward Spark',{range:3,shape:'line',damage:1,self:[mark('haste')],cooldown:3},'Move off its return line; Haste helps only the caster next round.'],
 ['Cress','Meadow Fold',{range:1,heal:1,cleanse:true,friendly:[mark('ward')],cooldown:3},'Its protection requires adjacent support; separate or overwhelm the patient.'],
 ['Murmur','Fen Whisper',{range:2,shape:'ring',radius:1,harmful:[mark('blind'),mark('wither')],cooldown:3},'The centre stays clear; cleansing counters both marks.'],
 ['Lumenroot','Moonroot Draw',{range:2,push:-1,heal:1,friendly:[mark('anchored')],cooldown:3},'Anchor first to prevent an unwanted pull; its healing affects allies only.'],
 ['Prism','Aurora Ribbon',{range:3,shape:'line',harm:'enemy',damage:1,friendly:[mark('clarity')],cooldown:3},'The single ribbon cannot cover spread allies and enemies together.'],
 ['Belfry','Bough Toll',{range:2,shape:'sweep',radius:1,dispel:true,harmful:[mark('concussed')],cooldown:3},'No direct damage; Clarity prevents its disruption after barriers fall.'],
 ['Verdant','Garden Waking',{range:1,heal:1,cleanse:true,recharge:1,selfDamage:1,cooldown:4},'An adjacent patient benefits, but the caster pays health and waits four rounds.'],
 ['Old Cinder','Sheltered Seed',{range:1,friendly:[mark('ward',2,2),mark('anchored',2)],cooldown:4},'Protection starts next round; pierce the Ward or change targets.'],
 ['Stillwater','Equinox Pool',{range:2,heal:1,harmful:[mark('wither')],harm:'enemy',cooldown:4},'It has no direct damage and a long recovery; move away from its chosen pool.'],
 ['Wayfarer','Horizon Crossing',{range:3,shape:'line',push:1,selfDamage:1,cooldown:4},'Guard reduces the lane-wide force; the caster pays health for its crossing.'],
 ['Orrery','Missing Moon',{range:2,damage:1,pierce:true,steal:1,cooldown:4},'Spend Flux before impact; one precise hit leaves a long recovery window.'],
 ['Old Reed','Season Shelter',{range:1,heal:1,friendly:[mark('clarity'),mark('anchored')],cooldown:4},'Very short support range; its patient gains no immediate Ward.'],
 ['Firstbud','First Seed',{range:1,heal:1,friendly:[mark('ward')],selfDamage:1,cost:7,cooldown:4},'Six-element ground is a precise, costly commitment; separate the patient and punish the caster.'],
];

function define([creatureName,name,options,counterplay]:Entry):CreatureSpell {
 const creature=CREATURES.find(entry=>entry.name===creatureName);if(!creature)throw new Error(`Unknown technique creator ${creatureName}`);
 const element=Object.entries(creature.affinities).sort(([,a],[,b])=>(b??0)-(a??0))[0][0] as Element;
 const level=({lesser:2,standard:4,greater:6} as const)[creature.strengthClass],ingredients=creature.elements.length;
 return {id:`creature_spell:${creature.id}`,creatureId:creature.id,name,element,description:'',level,branch:ingredients>1?'Confluence':element.charAt(0).toUpperCase()+element.slice(1),cost:ingredients>=4?6:ingredients>=2?5:level===2?3:level===4?4:5,cooldown:1,range:3,shape:'hex',radius:0,damage:0,heal:0,harm:'all',...(ingredients>1?{fieldElements:[...creature.elements]}:{}),...options,counterplay};
}
export const CREATURE_SPELLS:readonly CreatureSpell[]=Object.freeze([...pure,...mixed].map(define));
const byCreator=new Map(CREATURE_SPELLS.map(spell=>[spell.creatureId,spell]));
export function creatureSpellDefinition(creatureId:string):CreatureSpell {getCreature(creatureId);const spell=byCreator.get(creatureId);if(!spell)throw new Error('That creature has no authored technique.');return spell;}
export function creatureLoadout(creatureId:string):string[] {const creature=getCreature(creatureId);return [creatureSpellDefinition(creatureId).id,...creature.loadout.slice(1)];}
