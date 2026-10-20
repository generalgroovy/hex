import type {Element,Point} from './game.ts';
import {CHAMPIONS} from './roster-v11.ts';
import {ARENA_STARTS} from './arena-v7.ts';

export const INHABITANT_ELEMENTS:readonly Element[]=['fire','water','earth','air','light','dark'];
export type CreatureFamily='fox'|'otter'|'tortoise'|'bird'|'moth'|'cat'|'heron'|'salamander'|'toad'|'stag'|'serpent'|'bison'|'garden';
export type CreatureFootprint='ray'|'fork'|'fan'|'ring'|'halo'|'crescent'|'path';
export type InhabitantSpecies={id:string;mask:number;name:string;kind:string;family:CreatureFamily;elements:Element[];desire:string;footprint:CreatureFootprint;counterElement:Element;phaseOffset:number};
export type Inhabitant=Point&{speciesId:string};
export type InhabitantCell=Point&{biome?:string;well:boolean;height?:number};
export type InhabitantState={mapId:string;round:number;cells:readonly InhabitantCell[];inhabitants?:readonly Inhabitant[]};
export type InhabitantIntent={id:string;name:string;phase:'rest'|'pulse';area:Point[];elements:Element[];counterElement:Element;anchor:Point;tell:string};
type Entry=[string,string,string,CreatureFamily,string,CreatureFootprint,Element];
const letters:Record<string,Element>={f:'fire',w:'water',e:'earth',a:'air',l:'light',d:'dark'};
/** Authored inhabitants, ordered from simple ingredients to complete mixtures.
 * Each has a home, silhouette, desire, footprint and a visible way to interrupt it. */
const entries:Entry[]=[
 ['w','Puddle','reed otter','otter','Keeps one crossing wet enough for its young.','path','earth'],
 ['f','Cinder','ember fox','fox','Warms its nest with a careful ribbon of sparks.','ray','water'],
 ['e','Pebble','burr tortoise','tortoise','Packs loose ground around a sheltered hollow.','crescent','air'],
 ['a','Pip','gust finch','bird','Practises take-off along a straight current.','ray','earth'],
 ['l','Wick','lantern moth','moth','Leaves a little light for anyone coming home.','halo','dark'],
 ['d','Morrow','shade cat','cat','Collects the cool shadows beneath old stones.','fork','light'],
 ['fw','Hush','kettle heron','heron','Hides its fishing pool beneath a warm breath.','fan','air'],
 ['fe','Kiln','clay salamander','salamander','Bakes three sunning stones before settling down.','ray','water'],
 ['fa','Crackle','spark swallow','bird','Races the wind with a crackling tail.','path','earth'],
 ['fl','Saffron','sun fox','fox','Draws a bright circle around its sleeping cubs.','ring','water'],
 ['fd','Soot','chimney cat','cat','Tucks live embers into the darkest corners.','crescent','water'],
 ['we','Mossback','bog newt','salamander','Builds muddy banks with one narrow way through.','fork','fire'],
 ['wa','Skitter','sleet otter','otter','Polishes an icy slide before each dive.','path','fire'],
 ['wl','Ripple','mirror koi','serpent','Makes a still pool for tired travellers.','halo','earth'],
 ['wd','Rime','midnight toad','toad','Waits beside a dark, perfectly frozen pool.','ring','fire'],
 ['ea','Tumble','dune tortoise','tortoise','Sweeps grit away from its favourite ridge.','fan','water'],
 ['el','Facet','crystal stag','stag','Grows a sheltered arch between its antlers.','crescent','dark'],
 ['ed','Loam','mushroom badger','bison','Turns the old roots into a quiet bed.','halo','light'],
 ['al','Tinsel','dawn swallow','bird','Leaves a bright flight path for its flock.','path','dark'],
 ['ad','Whisper','dusk moth','moth','Folds the evening breeze around its wings.','fork','light'],
 ['ld','Vesper','eclipse moth','moth','Visits the place where two shadows meet.','ring','earth'],
 ['fwe','Kettleback','spring tortoise','tortoise','Warms a little spring beneath its cracked shell.','halo','air'],
 ['fwa','Billow','cloud heron','heron','Puffs warm clouds along the river bend.','path','earth'],
 ['fwl','Honeydew','rain fox','fox','Catches warm rain in the hollow of its tail.','crescent','dark'],
 ['fwd','Smudge','soot otter','otter','Washes its smoky paws in a secluded pool.','fork','light'],
 ['fea','Rattle','cinder bison','bison','Shakes hot grit from its enormous mane.','fan','water'],
 ['fel','Aureole','forge stag','stag','Cools glowing antlers in a ring of stone.','ring','water'],
 ['fed','Clinker','coal tortoise','tortoise','Guards a single coal beneath a blackened shell.','crescent','light'],
 ['fal','Flicker','sun kite','bird','Draws a bright zigzag over the hillside.','fork','water'],
 ['fad','Scurry','ash fox','fox','Carries sparks between abandoned burrows.','path','light'],
 ['fld','Solace','twilight moth','moth','Keeps one last warm lamp alight.','halo','water'],
 ['wea','Bracken','rain bison','bison','Tramples a drinking path through the reeds.','path','fire'],
 ['wel','Pearl','spring toad','toad','Tends a small clear pool between the roots.','ring','dark'],
 ['wed','Dapple','peat otter','otter','Digs dark little channels under the bank.','fork','light'],
 ['wal','Nimbus','rain shepherd','heron','Leads a gentle shower across the crossing.','fan','earth'],
 ['wad','Velvet','fog serpent','serpent','Uncoils through the coldest part of the mist.','path','fire'],
 ['wld','Opal','moon koi','serpent','Waits for a reflected moon in every pool.','crescent','earth'],
 ['eal','Chime','reed stag','stag','Makes hollow branches sing in the sun.','fork','dark'],
 ['ead','Burrow','dust badger','bison','Clears a secret entrance with a dusty sneeze.','fan','water'],
 ['eld','Hollowbell','dusk stag','stag','Shelters seedlings beneath its hollow antlers.','crescent','fire'],
 ['ald','Gossamer','horizon moth','moth','Hangs a thin veil between day and night.','ring','earth'],
 ['fwea','Rumblewake','weather bison','bison','Pushes a warm front across the valley.','fan','light'],
 ['fwel','Marigold','geyser stag','stag','Waters a bright garden with a steaming spring.','halo','dark'],
 ['fwed','Crock','bog kiln tortoise','tortoise','Bakes the river mud into little shelters.','crescent','air'],
 ['fwal','Sunshower','rainbow heron','heron','Turns the passing rain toward the morning sun.','path','earth'],
 ['fwad','Fathom','storm otter','otter','Chases the thunder hiding beneath the water.','fork','light'],
 ['fwld','Duskettle','lantern toad','toad','Warms a lantern inside its misty pool.','ring','earth'],
 ['feal','Corona','glasswing kite','bird','Scatters bright grains across a rising current.','fork','water'],
 ['fead','Cairn','ashhorn bison','bison','Builds a windbreak from yesterday\'s embers.','crescent','water'],
 ['feld','Mica','kiln moth','moth','Sleeps where warm stone meets a cool shadow.','halo','air'],
 ['fald','Comet','nightfire fox','fox','Follows its own glowing trail home.','path','water'],
 ['weal','Cress','meadow tortoise','tortoise','Carries a small wet meadow on its back.','halo','fire'],
 ['wead','Murmur','fen serpent','serpent','Breathes a low mist between the sedges.','ring','light'],
 ['weld','Lumenroot','moonroot stag','stag','Tends roots that drink both moonlight and rain.','fork','fire'],
 ['wald','Prism','aurora koi','serpent','Swims through a ribbon of turning light.','path','earth'],
 ['eald','Belfry','hollowwood heron','heron','Shakes the evening dust from an ancient bough.','fan','fire'],
 ['fweal','Verdant','dawn garden','garden','Wakes a little garden with warmth and rain.','halo','dark'],
 ['fwead','Old Cinder','stormroot tortoise','tortoise','Keeps a sheltered seed beneath the weather.','crescent','light'],
 ['fweld','Stillwater','equinox stag','stag','Holds a quiet pool between warm and cold.','ring','air'],
 ['fwald','Wayfarer','horizon serpent','serpent','Carries the changing sky along the river.','path','earth'],
 ['feald','Orrery','starstone moth','moth','Turns its dusty wings toward a missing moon.','fork','water'],
 ['weald','Old Reed','marsh keeper','heron','Makes room for small lives under every season.','fan','fire'],
 ['fweald','Firstbud','wandering garden','garden','Carries one seed from every place it has been.','halo','dark'],
];
export const INHABITANT_SPECIES:readonly InhabitantSpecies[]=entries.map(([code,name,kind,family,desire,footprint,counterElement],index)=>{
 const elements=INHABITANT_ELEMENTS.filter(element=>[...code].some(letter=>letters[letter]===element));
 const mask=elements.reduce((value,element)=>value|(1<<INHABITANT_ELEMENTS.indexOf(element)),0);
 return {id:`inhabitant-${mask}`,mask,name,kind,family,elements:[...elements],desire,footprint,counterElement,phaseOffset:index%2};
});
export function getInhabitantSpecies(id:string):InhabitantSpecies {const species=INHABITANT_SPECIES.find(entry=>entry.id===id);if(!species)throw new Error('Unknown elemental inhabitant.');return species;}
const directions:readonly Point[]=[{q:1,r:0},{q:1,r:-1},{q:0,r:-1},{q:-1,r:0},{q:-1,r:1},{q:0,r:1}];
const key=(point:Point)=>`${point.q},${point.r}`;
const distance=(a:Point,b:Point)=>Math.max(Math.abs(a.q-b.q),Math.abs(a.r-b.r),Math.abs(a.q+a.r-b.q-b.r));
const hash=(text:string)=>{let value=2166136261;for(const letter of text){value^=letter.charCodeAt(0);value=Math.imul(value,16777619)>>>0;}return value;};
function storyIndex(mapId:string):number {return CHAMPIONS.findIndex(champion=>`frontier:STORY-${champion.id.replaceAll('_','-').toUpperCase()}`===mapId);}
const countAt=(index:number)=>index<3?1:index<24?2:3;
export function encounterSpecies(encounterId:string):readonly InhabitantSpecies[] {
 const index=CHAMPIONS.findIndex(champion=>champion.id===encounterId);if(index<0)return [];
 let offset=0;for(let i=0;i<index;i++)offset+=countAt(i);
 return INHABITANT_SPECIES.slice(offset,offset+countAt(index));
}
/** Placements use only immutable geography, never current fields or barriers. */
export function storyInhabitants(mapId:string,cells:readonly InhabitantCell[]):Inhabitant[] {
 const index=storyIndex(mapId);if(index<0)return [];
 const wells=cells.filter(cell=>cell.well),result:Inhabitant[]=[];
 for(const species of encounterSpecies(CHAMPIONS[index].id)){
  const candidates=cells.filter(cell=>!cell.well&&cell.biome!=='ruins'&&ARENA_STARTS.flat().every(start=>distance(cell,start)>=3)&&result.every(other=>distance(cell,other)>=3));
  candidates.sort((a,b)=>{
   const score=(cell:InhabitantCell)=>(cell.biome==='plain'?0:20)+Math.min(...wells.map(well=>Math.abs(distance(cell,well)-2)))*10+Math.max(0,distance(cell,{q:0,r:0})-6)*8;
   return score(a)-score(b)||hash(`${mapId}:${species.id}:${key(a)}`)-hash(`${mapId}:${species.id}:${key(b)}`)||a.q-b.q||a.r-b.r;
  });
  const anchor=candidates[0];if(!anchor)throw new Error('Story map has no safe inhabitant perch.');
  result.push({speciesId:species.id,q:anchor.q,r:anchor.r});
 }
 return result;
}
function footprint(inhabitant:Inhabitant,species:InhabitantSpecies,cells:readonly InhabitantCell[]):Point[] {
 const direction=species.mask%6,dir=(offset:number)=>directions[(direction+offset+6)%6],scaled=(point:Point,amount=1)=>({q:inhabitant.q+point.q*amount,r:inhabitant.r+point.r*amount});
 const center={q:inhabitant.q,r:inhabitant.r};
 const shapes:Record<CreatureFootprint,Point[]>={
  ray:[center,scaled(dir(0)),scaled(dir(0),2)],
  path:[scaled(dir(3)),center,scaled(dir(0)),scaled(dir(0),2)],
  fork:[center,scaled(dir(-1)),scaled(dir(-1),2),scaled(dir(1)),scaled(dir(1),2)],
  fan:[center,scaled(dir(-1)),scaled(dir(0)),scaled(dir(1))],
  ring:directions.map(direction=>scaled(direction)),
  halo:[center,...directions.map(direction=>scaled(direction))],
  crescent:[scaled(dir(-2)),scaled(dir(-1)),center,scaled(dir(1)),scaled(dir(2))],
 };
 const allowed=new Set(cells.filter(cell=>cell.biome!=='ruins').map(key));
 return shapes[species.footprint].filter(point=>allowed.has(key(point)));
}
export function inhabitantIntents(state:InhabitantState):InhabitantIntent[] {
 return [...(state.inhabitants??[])].sort((left,right)=>left.speciesId.localeCompare(right.speciesId)).map(inhabitant=>{
  const species=getInhabitantSpecies(inhabitant.speciesId),phase=(state.round+species.phaseOffset)%2===1?'pulse':'rest';
  const area=footprint(inhabitant,species,state.cells),elementNames=species.elements.map(element=>element[0].toUpperCase()+element.slice(1)).join(' + ');
  return {id:species.id,name:species.name,phase,area,elements:[...species.elements],counterElement:species.counterElement,anchor:{q:inhabitant.q,r:inhabitant.r},tell:phase==='pulse'?`${species.name} releases ${elementNames} across ${area.length} hexes this turn. A spell of ${species.counterElement} on its perch interrupts it.`:`${species.name} rests this turn; ${elementNames} follows next turn.`};
 });
}
export function inhabitantPulses(state:InhabitantState):InhabitantIntent[] {return inhabitantIntents(state).filter(intent=>intent.phase==='pulse');}
/** No client-controlled phase, target or creature strength survives restoration. */
export function validateInhabitants(input:unknown,mapId:string,round:number,cells:readonly InhabitantCell[]):Inhabitant[] {
 if(!Number.isInteger(round)||round<1||round>21)throw new Error('Invalid inhabitant round.');
 if(!Array.isArray(input)||input.length>3)throw new Error('Invalid story inhabitants.');
 const expected=storyInhabitants(mapId,cells);
 if(input.length!==expected.length)throw new Error('Story inhabitants do not match this encounter.');
 for(let index=0;index<expected.length;index++){
  const actual=input[index],wanted=expected[index];
  if(!actual||typeof actual!=='object'||Array.isArray(actual)||![Object.prototype,null].includes(Object.getPrototypeOf(actual))||Object.keys(actual).length!==3||!Object.keys(actual).every(key=>['speciesId','q','r'].includes(key))||actual.speciesId!==wanted.speciesId||actual.q!==wanted.q||actual.r!==wanted.r)throw new Error('Story inhabitant placement has changed.');
 }
 return expected;
}
