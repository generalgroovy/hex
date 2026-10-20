/** Recruitable combat creatures. Ambient inhabitants remain frozen in v16. */
import type {Element} from './game.ts';
import type {AffinityAllocation} from './roster-v11.ts';
import {INHABITANT_SPECIES,type CreatureFamily} from './inhabitants-v16.ts';
import {combinationFor} from './combinations-v16.ts';
import {getSpell,spellAccess,SPELLS} from './spells-v16.ts';

export type CreatureClass='lesser'|'standard'|'greater';
export const CREATURE_BOND_RADIUS=2;
export type CreatureRole='striker'|'keeper'|'controller'|'artillery'|'scout'|'support';
export type CreaturePerkMechanics={heal?:1;flux?:1;ward?:1;haste?:1;clarity?:true};
export type CreaturePerk={id:string;name:string;partnerElements:readonly Element[];mechanics:Readonly<CreaturePerkMechanics>;description:string};
export type CreatureDefinition={
 id:string;name:string;elements:Element[];strengthClass:CreatureClass;family:CreatureFamily;role:CreatureRole;description:string;
 visualSpeciesId:string;championId:string;affinities:AffinityAllocation;loadout:string[];maxHp:number;maxFlux:number;perkId:string;
};
export type TeamPerkEffects={heal:0|1;flux:0|1;ward:0|1;haste:0|1;clarity:boolean;perkIds:string[]};
const labels:Record<Element,string>={fire:'Fire',water:'Water',earth:'Earth',air:'Air',light:'Light',dark:'Dark'};
const proxies:Record<Element,string>={fire:'wa_bidi',water:'oh_tipi',earth:'treevor_mason',air:'grace_reava',light:'haara',dark:'s_wayne'};
const classStats:Record<CreatureClass,{maxHp:number;maxFlux:number;rank:number;slots:number}>={
 lesser:{maxHp:4,maxFlux:4,rank:2,slots:2},standard:{maxHp:6,maxFlux:5,rank:4,slots:3},greater:{maxHp:8,maxFlux:6,rank:6,slots:4},
};
const perkDescription=(partnerElements:readonly Element[],mechanics:CreaturePerkMechanics):string=>{
 const benefits=[
  mechanics.heal?'recover 1 health':'',
  mechanics.flux?'recover 1 Flux':'',
  mechanics.ward?'gain Ward 1 for next round':'',
  mechanics.haste?'gain Haste for next round':'',
  mechanics.clarity?'gain Clarity for next round':'',
 ].filter(Boolean).join(' and ');
 return `With a different living ${partnerElements.map(element=>labels[element]).join(' or ')} companion, surviving allies within ${CREATURE_BOND_RADIUS} hexes of both creatures ${benefits} after ordinary effects. Matching benefits do not stack; defeated companions grant nothing.`;
};
const perks:CreaturePerk[]=[];
function perk(id:string,name:string,partnerElements:Element[],mechanics:CreaturePerkMechanics):string {
 perks.push(Object.freeze({id,name,partnerElements:Object.freeze([...partnerElements]),mechanics:Object.freeze({...mechanics}),description:perkDescription(partnerElements,mechanics)}));return id;
}
const purePerks:Record<Element,[string,string]>={
 fire:[perk('kindling','Kindling',['water'],{flux:1}),perk('forge-watch','Forge Watch',['earth'],{ward:1})],
 water:[perk('warm-current','Warm Current',['fire'],{heal:1}),perk('slipwater','Slipwater',['air'],{haste:1})],
 earth:[perk('root-shelter','Root Shelter',['water'],{ward:1}),perk('clear-stone','Clear Stone',['light'],{clarity:true})],
 air:[perk('spark-draft','Spark Draft',['fire'],{haste:1}),perk('night-current','Night Current',['dark'],{flux:1})],
 light:[perk('lantern-watch','Lantern Watch',['dark'],{clarity:true}),perk('morning-dew','Morning Dew',['water'],{heal:1})],
 dark:[perk('dusk-reserve','Dusk Reserve',['light'],{flux:1}),perk('hollow-shelter','Hollow Shelter',['earth'],{ward:1})],
};
type PureEntry=[Element,string,string,CreatureFamily,CreatureRole,CreatureClass,string[],0|1];
const pureEntries:PureEntry[]=[
 ['fire','cinder','Cinder','fox','striker','lesser',['ember','backdraft'],0],
 ['fire','wicktail','Wicktail','salamander','support','lesser',['ember','cauterize'],1],
 ['fire','ashwing','Ashwing','bird','artillery','standard',['ember','flare','fire_lance'],0],
 ['fire','hearthback','Hearthback','tortoise','keeper','standard',['ember','cauterize','immolate'],1],
 ['fire','kilnhorn','Kilnhorn','bison','striker','greater',['inferno','immolate','fire_lance','cauterize'],0],
 ['fire','sunmane','Sunmane','stag','controller','greater',['wildfire','flare','backdraft','cauterize'],1],
 ['water','puddle','Puddle','otter','support','lesser',['water_jet','cleansing_tide'],0],
 ['water','brookling','Brookling','toad','controller','lesser',['water_jet','undertow'],1],
 ['water','reedcoil','Reedcoil','serpent','controller','standard',['undertow','frostbite','water_jet'],1],
 ['water','tideplume','Tideplume','heron','keeper','standard',['tidal_surge','cleansing_tide','frostbite'],0],
 ['water','iceback','Iceback','tortoise','controller','greater',['deep_freeze','frostbite','cleansing_tide','maelstrom'],1],
 ['water','floodhorn','Floodhorn','bison','striker','greater',['maelstrom','tidal_surge','water_jet','rainfall'],0],
 ['earth','pebble','Pebble','tortoise','keeper','lesser',['stone','bulwark'],0],
 ['earth','burrpaw','Burrpaw','cat','controller','lesser',['stone','grasping_roots'],1],
 ['earth','cairnback','Cairnback','bison','striker','standard',['stone','shatter','bulwark'],0],
 ['earth','rootspring','Rootspring','garden','support','standard',['stoneheart','grasping_roots','raise_cairn'],1],
 ['earth','flintstag','Flintstag','stag','artillery','greater',['fault_line','quake','bulwark','shatter'],1],
 ['earth','ironcoil','Ironcoil','serpent','keeper','greater',['fault_line','shatter','stoneheart','raise_cairn'],0],
 ['air','pip','Pip','bird','scout','lesser',['gust','tailwind'],0],
 ['air','whisk','Whisk','cat','controller','lesser',['gust','vacuum'],1],
 ['air','whistle','Whistle','fox','scout','standard',['wind_shear','tailwind','gale'],0],
 ['air','vaneheron','Vaneheron','heron','controller','standard',['thunderclap','vacuum','gust'],1],
 ['air','stormwing','Stormwing','moth','support','greater',['slipstream','tailwind','wind_shear','cyclone'],1],
 ['air','thunderhorn','Thunderhorn','bison','striker','greater',['cyclone','thunderclap','gale','wind_shear'],0],
 ['light','wick','Wick','moth','support','lesser',['radiant_bolt','mend'],0],
 ['light','lanternpaw','Lanternpaw','cat','keeper','lesser',['radiant_bolt','aegis'],1],
 ['light','glimmerfin','Glimmerfin','serpent','artillery','standard',['prism_lance','sunburst','radiant_bolt'],0],
 ['light','dawnkeeper','Dawnkeeper','heron','support','standard',['mend','clear_sight','radiant_bolt'],1],
 ['light','haloheart','Haloheart','stag','keeper','greater',['sanctuary','aegis','prism_lance','clear_sight'],0],
 ['light','sunmeadow','Sunmeadow','garden','support','greater',['sanctuary','inspire','radiant_bolt','sunburst'],1],
 ['dark','morrow','Morrow','cat','striker','lesser',['wither_bolt','siphon'],0],
 ['dark','duskmote','Duskmote','moth','controller','lesser',['wither_bolt','veil'],1],
 ['dark','inkcoil','Inkcoil','serpent','controller','standard',['soul_chain','veil','essence_theft'],1],
 ['dark','shadefox','Shadefox','fox','striker','standard',['reap','siphon','wither_bolt'],0],
 ['dark','nightplume','Nightplume','heron','artillery','greater',['eclipse','blight','reap','veil'],1],
 ['dark','hollowhorn','Hollowhorn','bison','keeper','greater',['soul_chain','reap','siphon','essence_theft'],0],
];
const kindDescription:Record<CreatureRole,string>={striker:'Pressures a single target.',keeper:'Holds ground and protects allies.',controller:'Changes enemy movement or next-round options.',artillery:'Threatens lanes and broad areas.',scout:'Combines displacement with mobile support.',support:'Keeps allies ready for the next exchange.'};
const pure:CreatureDefinition[]=pureEntries.map(([element,slug,name,family,role,strengthClass,loadout,variant])=>{
 const stats=classStats[strengthClass],visual=INHABITANT_SPECIES.find(species=>species.elements.length===1&&species.elements[0]===element)!;
 return {id:`creature-${element}-${slug}`,name,elements:[element],strengthClass,family,role,description:kindDescription[role],visualSpeciesId:visual.id,championId:proxies[element],affinities:{[element]:stats.rank},loadout:[...loadout],maxHp:stats.maxHp,maxFlux:stats.maxFlux,perkId:purePerks[element][variant]};
});
const basic:Record<Element,string>={fire:'ember',water:'water_jet',earth:'stone',air:'gust',light:'radiant_bolt',dark:'wither_bolt'};
const utility:Record<Element,string>={fire:'cauterize',water:'cleansing_tide',earth:'bulwark',air:'tailwind',light:'mend',dark:'siphon'};
const rolePriority:Record<CreatureRole,Element[]>={
 striker:['fire','dark','earth','air','water','light'],keeper:['earth','water','light','dark','fire','air'],
 controller:['water','air','dark','earth','fire','light'],artillery:['fire','air','light','earth','dark','water'],
 scout:['air','water','dark','fire','light','earth'],support:['light','water','earth','air','fire','dark'],
};
const mixed:CreatureDefinition[]=INHABITANT_SPECIES.filter(species=>species.elements.length>1).map(species=>{
 const field=combinationFor(species.elements)!,effects=field.mechanics;
 const role:CreatureRole=effects.heal||effects.cleanse?'support':effects.cover||effects.damageScale?'keeper':effects.movement==='ice'||effects.statuses?.some(status=>['rooted','blind','concussed'].includes(status.id))?'controller':effects.movement==='current'?'scout':species.footprint==='ray'||species.footprint==='fork'?'artillery':'striker';
 const strengthClass:CreatureClass=species.elements.length===2?'standard':'greater',stats=classStats[strengthClass];
 const casting=rolePriority[role].filter(element=>species.elements.includes(element)).slice(0,3),primary=casting[0];
 const affinities:AffinityAllocation=Object.fromEntries(casting.map((element,index)=>[element,Math.max(1,stats.rank-index*2)]));
 // Every full elemental identity remains visible; creatures with four or more
 // ingredients concentrate their four casts into up to three explicit affinities.
 const preferred=SPELLS.filter(spell=>spell.element===primary&&spell.level<=(affinities[primary]??1)&&spell.level>=2&&(
   role==='support'?spell.heal>0||spell.recharge:role==='keeper'?spell.friendly?.length:role==='controller'?spell.push||spell.harmful?.length:role==='artillery'?spell.shape==='line'||spell.shape==='burst':spell.damage>0
 )).sort((a,b)=>b.level-a.level||a.id.localeCompare(b.id));
 const candidateIds=[...preferred.slice(0,1).map(spell=>spell.id),...casting.map(element=>basic[element]),utility[primary],...casting.map(element=>utility[element])];
 const loadout=[...new Set(candidateIds)].filter(id=>spellAccess(proxies[primary],id,affinities).unlocked).slice(0,stats.slots);
 const mechanics:CreaturePerkMechanics=effects.cleanse?{clarity:true}:effects.heal?{heal:1}:effects.cover||effects.damageScale?{ward:1}:effects.flux===1||effects.wellBonus?{flux:1}:effects.movement==='current'||effects.statuses?.some(status=>status.id==='haste')?{haste:1}:effects.statuses?.some(status=>status.id==='ward')?{ward:1}:role==='controller'?{clarity:true}:role==='striker'||role==='artillery'?{flux:1}:{haste:1};
 const perkId=perk(`bond-${field.id}`,`${field.name} Bond`,[species.counterElement],mechanics);
 return {id:`creature-${field.id}`,name:species.name,elements:[...species.elements],strengthClass,family:species.family,role,description:`${kindDescription[role]} ${field.name} lineage.`,visualSpeciesId:species.id,championId:proxies[primary],affinities,loadout,maxHp:stats.maxHp,maxFlux:stats.maxFlux,perkId};
});
export const CREATURES:readonly CreatureDefinition[]=Object.freeze([...pure,...mixed].map(creature=>Object.freeze({...creature,elements:Object.freeze(creature.elements) as unknown as Element[],affinities:Object.freeze(creature.affinities),loadout:Object.freeze(creature.loadout) as unknown as string[]})));
export const CREATURE_PERKS:readonly CreaturePerk[]=Object.freeze(perks);
const byId=new Map(CREATURES.map(creature=>[creature.id,creature]));
const perksById=new Map(CREATURE_PERKS.map(entry=>[entry.id,entry]));
export function getCreature(id:string):CreatureDefinition {const creature=byId.get(id);if(!creature)throw new Error('Unknown combat creature.');return creature;}
export function validateCreatureId(value:unknown):string {if(typeof value!=='string'||!byId.has(value))throw new Error('Choose a known combat creature.');return value;}
export function getCreaturePerk(id:string):CreaturePerk {const value=perksById.get(id);if(!value)throw new Error('Unknown creature bond.');return value;}
/** Call per recipient with only living allied creatures within CREATURE_BOND_RADIUS.
 * Separate companions must supply the partner
 * ingredient: a composite creature cannot activate its own bond. The engine
 * applies this after ordinary effects to survivors, never reviving a defeat. */
export function teamPerkEffects(creatureIds:readonly string[]):TeamPerkEffects {
 const creatures=creatureIds.map(getCreature),active=creatures.flatMap((creature,index)=>{
  const bond=getCreaturePerk(creature.perkId);
  return creatures.some((other,otherIndex)=>otherIndex!==index&&bond.partnerElements.some(element=>other.elements.includes(element)))?[bond]:[];
 });
 const perkIds=[...new Set(active.map(bond=>bond.id))].sort();
 const has=(key:keyof CreaturePerkMechanics)=>active.some(bond=>!!bond.mechanics[key]);
 return {heal:has('heal')?1:0,flux:has('flux')?1:0,ward:has('ward')?1:0,haste:has('haste')?1:0,clarity:has('clarity'),perkIds};
}
export function creatureAbilitySummary(id:string):string {
 const creature=getCreature(id);return creature.loadout.map(spellId=>getSpell(spellId).name).join(' · ');
}

