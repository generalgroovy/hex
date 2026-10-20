import type {Element} from './game.ts';
import type {StatusApplication} from './spells-v11.ts';

/** The complete field is one phenomenon. Subset reactions never run underneath it. */
export const ELEMENT_ORDER:readonly Element[]=['fire','water','earth','air','light','dark'];
export type CombinationMechanics={
  movement?:'flood'|'rough'|'ice'|'current';
  damageScale?:'half';
  cover?:1|2;
  hazard?:'always'|'formed'|'moved';
  heal?:1;
  flux?:1|-1;
  statuses?:readonly StatusApplication[];
  cleanse?:true;
  wellBonus?:1;
  consume?:true;
};
export type CombinationDefinition={
  id:string;mask:number;name:string;elements:readonly Element[];color:string;symbol:string;
  description:string;shortRule:string;mechanics:Readonly<CombinationMechanics>;
};
export type ReactionId=string;
export function combinationMask(elements:readonly Element[]):number {
  return ELEMENT_ORDER.reduce((mask,element,index)=>mask|(elements.includes(element)?1<<index:0),0);
}
const mark=(id:StatusApplication['id'],turns=1,power?:number):StatusApplication=>({id,turns,...(power===undefined?{}:{power})});
const palette=['#ef9764','#80c7d7','#b9a06c','#b4d786','#f3d985','#aa8dca'];
function blendedColor(elements:readonly Element[]):string {
  const colors=elements.map(element=>palette[ELEMENT_ORDER.indexOf(element)]);
  return '#'+[1,3,5].map(offset=>Math.round(colors.reduce((sum,color)=>sum+parseInt(color.slice(offset,offset+2),16),0)/colors.length).toString(16).padStart(2,'0')).join('');
}
const statusLabels:Record<StatusApplication['id'],string>={wet:'Wet',burn:'Burn',blind:'Blind',concussed:'Concussed',rooted:'Rooted',chilled:'Chilled',ward:'Ward',haste:'Haste',wither:'Wither',clarity:'Clarity',resolve:'Resolve',anchored:'Anchored'};
/** Wording comes from the same bounded values the resolver reads. */
export function describeCombination(mechanics:Readonly<CombinationMechanics>):string {
  const lines:string[]=[];
  if(mechanics.movement==='flood')lines.push('Flooded: entering or leaving costs 2 movement.');
  if(mechanics.movement==='rough')lines.push('Rough: entering or leaving costs 2 movement.');
  if(mechanics.movement==='ice')lines.push('Ice: entering slides to the last connected icy hex in that direction.');
  if(mechanics.movement==='current')lines.push('Starting here gives +1 movement, without stacking with Haste.');
  if(mechanics.damageScale==='half')lines.push('Halves total incoming spell damage once, rounded up, before protection.');
  if(mechanics.cover)lines.push(`Absorbs ${mechanics.cover} ordinary spell damage; uses the stronger of this cover and forest cover.`);
  if(mechanics.hazard==='always')lines.push('Hurts its final occupant for 1 after displacement.');
  if(mechanics.hazard==='formed')lines.push('Hurts its final occupant for 1 only when this exact field first forms; refreshing it does not retrigger.');
  if(mechanics.hazard==='moved')lines.push('Hurts its final occupant for 1 if they finish on a different hex from the start of this exchange. Staying put is safe.');
  if(mechanics.hazard)lines.push('All environmental damage shares a cap of 1 per round.');
  if(mechanics.heal)lines.push('Heals its occupant for 1 in the exchange; existing Wither reduces aggregate healing once.');
  if(mechanics.flux)lines.push(mechanics.flux>0?'Its occupant recovers +1 Flux at the end of the exchange.':'Its occupant recovers 1 less Flux at the end of the exchange.');
  if(mechanics.cleanse)lines.push('Cleanses ailments and prevents incoming ailments this exchange, except Cauterize’s deliberate Burn.');
  for(const status of mechanics.statuses??[])lines.push(`${mechanics.movement==='flood'&&status.id==='wet'?'While liquid, grants':'Grants'} ${statusLabels[status.id]}${status.id==='ward'?` ${status.power??1}`:''} for ${status.turns} planning round${status.turns===1?'':'s'}.`);
  if(mechanics.wellBonus)lines.push('An occupied spring restores 2 Flux instead of 1.');
  if(mechanics.consume)lines.push('Disperses after this exchange, returning to the natural ground.');
  lines.push('Affects either team.');
  return lines.join(' ');
}
function field(mask:number,id:string,name:string,shortRule:string,mechanics:CombinationMechanics,symbol='✧',color?:string):CombinationDefinition {
  const elements=ELEMENT_ORDER.filter((_,index)=>mask&(1<<index));
  const immutable=Object.freeze({...mechanics,...(mechanics.statuses?{statuses:Object.freeze(mechanics.statuses.map(status=>Object.freeze({...status})))}:{})});
  return Object.freeze({mask,id,name,elements:Object.freeze(elements),color:color??blendedColor(elements),symbol,shortRule,mechanics:immutable,description:describeCombination(immutable)});
}
/** Each entry is authored as a tactical trade or opportunity, rather than generated pair stacking. */
export const COMBINATIONS:readonly CombinationDefinition[]=Object.freeze([
  field(1,'fire','Fire','Dangerous ground',{hazard:'always'},'♨'),
  field(2,'water','Water','Liquid flood wets its occupant',{movement:'flood',statuses:[mark('wet')]},'≈'),
  field(4,'earth','Earth','Rough ground',{movement:'rough'},'◆'),
  field(8,'air','Air','A running start',{movement:'current'},'»'),
  field(16,'light','Light','Protection from control',{statuses:[mark('clarity')]},'☼'),
  field(32,'dark','Dark','Weakens recovery',{statuses:[mark('wither')]},'◐'),
  field(3,'steam','Steam','Shelter from spells',{damageScale:'half'},'≋','#aad7df'),
  field(5,'magma','Magma','Slow, dangerous lava',{movement:'rough',hazard:'always'},'♨','#f69262'),
  field(6,'quagmire','Quagmire','Clinging mud leaves its occupant Wet',{movement:'rough',statuses:[mark('wet')]},'≋','#90b68c'),
  field(9,'arcstorm','Arcstorm','A spark on formation',{hazard:'formed'},'ϟ','#efae66'),
  field(10,'hailcurrent','Hailcurrent','Sliding ice leaves you chilled',{movement:'ice',statuses:[mark('chilled')]},'❄','#9ddce8'),
  field(12,'sandblast','Sandblast','Makes the next spell expensive',{statuses:[mark('concussed')]},'⋰','#c9ad78'),
  field(17,'solar_flare','Solar Flare','Clarity and a spark of Flux',{statuses:[mark('clarity')],flux:1},'☼','#ffe08c'),
  field(18,'mirrorwater','Mirrorwater','A healing pool',{heal:1},'≈','#d6ece6'),
  field(20,'crystal_prism','Crystal Prism','Protection for next exchange',{statuses:[mark('ward',1,1)]},'◇','#f0dca9'),
  field(24,'lightbend','Lightbend','Haste for the next move',{statuses:[mark('haste')]},'»','#dbefaf'),
  field(33,'backdraft','Backdraft','Leaves a lingering burn',{statuses:[mark('burn')]},'♨','#ba737c'),
  field(34,'black_ice','Black Ice','Ice that binds its occupant',{movement:'ice',statuses:[mark('rooted')]},'⌘','#7897be'),
  field(36,'blightsoil','Blightsoil','Two rounds of weakened healing',{statuses:[mark('wither',2)]},'†','#9b82b5'),
  field(40,'shadowdraft','Shadowdraft','Shortens the next spell’s reach',{statuses:[mark('blind')]},'◌','#a497cc'),
  field(48,'penumbra','Penumbra','Doubles spring Flux recovery',{wellBonus:1},'◐','#c5a7eb'),
  // Twenty triples. Their exact identities replace all three constituent pairs.
  field(7,'hot_spring','Hot Spring','Heal behind slow, protective ground',{movement:'rough',cover:1,heal:1},'♨'),
  field(11,'geyser','Geyser','A fast start; arriving hurts',{movement:'current',hazard:'moved'},'↑'),
  field(13,'glasswind','Glasswind','Shelter that taxes your next spell',{cover:1,statuses:[mark('concussed')]},'◇'),
  field(14,'siltstream','Siltstream','Slow passage, then a quick departure',{movement:'rough',statuses:[mark('haste')]},'≈'),
  field(19,'dawn_mist','Dawn Mist','Soften spells and shed ailments',{damageScale:'half',cleanse:true},'☀'),
  field(21,'hearthstone','Hearthstone','Heal and stand firm',{heal:1,statuses:[mark('anchored')]},'▰'),
  field(22,'lifeclay','Lifeclay','Recover now; protect next exchange',{heal:1,statuses:[mark('ward',1,1)]},'❧'),
  field(25,'sunstorm','Sunstorm','More Flux, shorter reach',{flux:1,statuses:[mark('blind')]},'ϟ'),
  field(26,'rainbow','Rainbow','Heal along a running current',{movement:'current',heal:1},'⌒'),
  field(28,'sungrass','Sungrass','A protected running start',{movement:'current',cover:1},'❧'),
  field(35,'scaldshade','Scaldshade','Soften spells but weaken healing',{damageScale:'half',statuses:[mark('wither')]},'≋'),
  field(37,'cinderbog','Cinderbog','A slow crossing that burns arrivals',{movement:'rough',hazard:'moved'},'♨'),
  field(38,'gravewater','Gravewater','Slow water washes ailments away',{movement:'flood',cleanse:true},'≈'),
  field(41,'ashwing','Ashwing','Speed with a lingering burn',{statuses:[mark('haste'),mark('burn')]},'»'),
  field(42,'rimeveil','Rimeveil','A sliding route that obscures aim',{movement:'ice',statuses:[mark('blind')]},'❄'),
  field(44,'dustveil','Dustveil','Slow passage beneath spell shelter',{movement:'rough',damageScale:'half'},'≋'),
  field(49,'ghostfire','Ghostfire','Control protection on dangerous ground',{hazard:'always',statuses:[mark('clarity')]},'☼'),
  field(50,'moonwell','Moonwell','Trade Flux recovery for health',{heal:1,flux:-1},'◐'),
  field(52,'tombglass','Tombglass','Strong cover weakens later healing',{cover:2,statuses:[mark('wither')]},'◇'),
  field(56,'starless_wind','Starless Wind','Trade Flux recovery for haste',{flux:-1,statuses:[mark('haste')]},'»'),
  // Fifteen groups of four: larger recipes change the decision, not merely its magnitude.
  field(15,'weatherfront','Weatherfront','A fast route with one opening shock',{movement:'current',hazard:'formed'},'ϟ'),
  field(23,'sunforge','Sunforge','Clear ailments and replenish Flux',{cleanse:true,flux:1},'☼'),
  field(27,'stormglass','Stormglass','Spell shelter taxes Flux recovery',{damageScale:'half',flux:-1},'◇'),
  field(29,'brass_canopy','Brass Canopy','Cover and steady Flux',{cover:1,flux:1},'⌒'),
  field(30,'cloudgarden','Cloudgarden','Heal now and carry haste away',{heal:1,statuses:[mark('haste')]},'❧'),
  field(39,'obsidian_mire','Obsidian Mire','Deep cover behind a slow crossing',{movement:'rough',cover:2},'◆'),
  field(43,'black_squall','Black Squall','A fast, hazardous route weakens healing',{movement:'current',hazard:'moved',statuses:[mark('wither')]},'ϟ'),
  field(45,'hollow_furnace','Hollow Furnace','Opening shock and an expensive reply',{hazard:'formed',statuses:[mark('concussed')]},'♨'),
  field(46,'peatstorm','Peatstorm','A slow crossing with poor Flux recovery',{movement:'rough',flux:-1},'⋰'),
  field(51,'eclipse_spring','Eclipse Spring','Healing and Flux amid persistent heat',{heal:1,flux:1,hazard:'always'},'◐'),
  field(53,'mourning_sun','Mourning Sun','A strong next ward at the cost of healing',{statuses:[mark('ward',1,2),mark('wither')]},'☼'),
  field(54,'stillwater','Stillwater','A cleansing ice lane',{movement:'ice',cleanse:true},'❄'),
  field(57,'ghoststorm','Ghoststorm','Spell shelter that obscures aim',{damageScale:'half',statuses:[mark('blind')]},'◌'),
  field(58,'mooncurrent','Mooncurrent','An ice lane replenishes Flux',{movement:'ice',flux:1},'≈'),
  field(60,'duskwood','Duskwood','More spring recovery, less field Flux',{wellBonus:1,flux:-1},'†'),
  // Six groups of five each give a distinct public opportunity or trade.
  field(31,'summerheart','Summerheart','A healing current leaves a ward',{movement:'current',heal:1,statuses:[mark('ward',1,1)]},'❧'),
  field(47,'black_weather','Black Weather','Spell shelter with a dangerous, costly arrival',{damageScale:'half',hazard:'moved',flux:-1},'ϟ'),
  field(55,'amber_vigil','Amber Vigil','Cleanse and anchor, with reduced Flux recovery',{cleanse:true,flux:-1,statuses:[mark('anchored')]},'◇'),
  field(59,'dreaming_sky','Dreaming Sky','Health and haste, but shorter spell reach',{heal:1,statuses:[mark('haste'),mark('blind')]},'⌒'),
  field(61,'nightglass','Nightglass','Strong cover on dangerous ground',{cover:2,hazard:'always'},'◆'),
  field(62,'elder_grove','Elder Grove','A healing spring is slow to leave',{movement:'rough',heal:1,wellBonus:1},'❧'),
  field(63,'worldseed','Worldseed','One exchange of shelter, cleansing and renewal',{damageScale:'half',cleanse:true,flux:1,consume:true},'✺'),
].sort((a,b)=>a.mask-b.mask));
export const REACTIONS=Object.freeze(COMBINATIONS.filter(combination=>combination.elements.length>1));
const byMask=new Map(COMBINATIONS.map(combination=>[combination.mask,combination]));
const byId=new Map(COMBINATIONS.map(combination=>[combination.id,combination]));
export function combinationFor(elements:readonly Element[]):CombinationDefinition|undefined {return byMask.get(combinationMask(elements));}
export function combinationById(id:string):CombinationDefinition|undefined {return byId.get(id);}
