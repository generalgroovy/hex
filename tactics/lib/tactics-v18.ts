import {friendlyStatusValue} from './support-value-v44.ts';
import {planningGeometry} from './planning-geometry-v44.ts';
import {jointLandings,barrierRouteValue,type ScoredLanding} from './joint-planning-v44.ts';
import {combatBreakdown,validateCombatBreakdown,type CombatBreakdown,type ConsequenceSource} from './combat-consequence-v44.ts';
import {CURRENT_SPELL_MODEL,isFocusedSpellModel,forceOrigin,profileSpell,spellAtCell,focusZone,type SpellModel} from './spell-profile-v42.ts';
/** Rules 18: simultaneous elimination with a visible, bounded contracting battlefield. */
import { CHAMPIONS, getChampion } from './roster-v13.ts';
import {validateCharacterBuild,canonicalBuild} from './character-creation-v17.ts';
import type {AffinityAllocation} from './roster-v11.ts';
import {arenaRadius,arenaSize,arenaStarts,arenaPlayerCount,validatePlayerCount,arenaHeightAt,arenaWellAt,arenaBiomeAt,baseTerrainAt,generateArena,normalizeArenaMapId,type PlayerCount} from './arena-v17.ts';
import { ALL_SPELLS, availableSpellIds, getSignature, SPELLS, STATUS_DEFINITIONS, defaultLoadout, getSpell, spellCost, spellAccess, validateLoadout,validateLearnedSignatures,effectiveSpell,describeSpell,spellScalingSummary } from './spells-v16.ts';
import type { Biome } from './arena-v17.ts';
import type { Spell, Status, StatusApplication, StatusId } from './spells-v16.ts';
import { distance } from './game.ts';
import type { Element, Point } from './game.ts';
export type Player=0|1|2|3|4|5;
export type Seat=Player;
export type MatchMode='free-for-all'|'teams';
export type {PlayerCount};
import { ELEMENTS } from './sim.ts';
import {formatTile} from './board-labels-v17.ts';
import {endgameForecast,collapseDamageAt,endgamePositionValue} from './endgame-v18.ts';
export {endgameForecast,collapseDamageAt,isSafe} from './endgame-v18.ts';
import {COMBINATIONS,REACTIONS,ELEMENT_ORDER,combinationFor,combinationById,type CombinationDefinition,type CombinationMechanics,type ReactionId} from './combinations-v16.ts';
import {inhabitantPulses,validateInhabitants,getInhabitantSpecies,type Inhabitant} from './inhabitants-v16.ts';
import {harmfulStatusValue,effectiveHealing,threatensAlly,availableTheft} from './combat-ai-v16.ts';
import {findProjectileClashes,findLegacyProjectileClashes,interceptionFieldArea,isTravellingProjectile,type Projectile,type ProjectileClash} from './projectile-interception-v20.ts';
export {COMBINATIONS,REACTIONS,combinationFor,combinationById};
export type {ReactionId,CombinationDefinition,CombinationMechanics};
export { CHAMPIONS, getChampion, ALL_SPELLS, availableSpellIds, getSignature, SPELLS, STATUS_DEFINITIONS, getSpell, defaultLoadout, spellCost, spellAccess, validateLoadout,validateLearnedSignatures,effectiveSpell,describeSpell,spellScalingSummary, distance, ELEMENTS };
export const MAPS = [{ id: 'confluence', name: 'Wellspring Reach', description: 'Seeded forests, marshes, ruins and high ground with a separate camp and inner spring for each company.' }];
export type { Element, Point, Spell, Status, StatusId };
export const RULES_VERSION = 18;
export const BOARD_RADIUS = 9;
export const BOARD_SIZE = 1 + 3 * BOARD_RADIUS * (BOARD_RADIUS + 1);
export const MOVE_RANGE = 4;
export const VICTORY_RULES = {mode:'elimination',simultaneousWipe:'draw',roundLimit:'collapse',collapseIgnoresProtection:true,springFlux:1} as const;
/** Validation ceiling only: winner is always determined by actual surviving teams. */
export const MAX_ROUNDS = 26;
export const MAX_FLUX = 6;
export const MAX_HP = 8;
export const TERRAIN_DURATION = 2;
export type SimCell = Point & { well: boolean; terrain: string; biome: Biome; height: 0 | 1; ttl?: number; elements?: Element[]; reactions?: ReactionId[]; barrier?: number; ice?: true };
export type Cell = SimCell;
export type SimUnit = Point & {
  id: string; championId: string; displayName?:string; owner: Player; hp: number; maxHp: number; guard?: boolean; respawn?: number;
  loadout: string[]; affinities:AffinityAllocation; flux: number; maxFlux: number; cooldowns: Record<string, number>; statuses: Partial<Record<StatusId, Status>>;
};
export type Order = { unitId: string; move?: Point; cast?: Point; spellId?: string; guard?: boolean };
export type TeamPlan = { orders: Order[]; training?:{unitId:string;element:Element}[]; loadouts?:{unitId:string;spells:string[]}[] };
export type SimEvent = {
  kind: 'move' | 'bounce' | 'cast' | 'clash' | 'reaction' | 'damage' | 'heal' | 'push' | 'defeat' | 'respawn' | 'score' | 'guard' | 'fizzle' | 'surface' | 'inhabitant';
  text: string; unitId?: string; owner?: Player; from?: Point; to?: Point; q?: number; r?: number; amount?: number;
  elements?: Element[]; terrain?: string; spellId?: string; status?: StatusId; speciesId?:string; interrupted?:boolean;
  breakdown?:CombatBreakdown;critical?:true;participants?:string[];meeting?:Point;flightFraction?:number;radius?:1|2;cause?:'collapse';
};
export type SimState = { rulesVersion: 18;spellModel?:SpellModel;projectileModel?:'volume'; version: number; mapId: string; playerCount:PlayerCount;mode:MatchMode;teams:number[];boardRadius:number; round: number; scores: number[]; learnedSignatures:string[][]; units: SimUnit[]; cells: SimCell[]; inhabitants?:Inhabitant[]; log: string[]; winner: Player | 'draw' | null; lastResolution: SimEvent[] };
const CONTROL: StatusId[] = ['rooted', 'chilled', 'concussed', 'blind'];
const AILMENTS: StatusId[] = ['burn', 'wither', ...CONTROL];
const DIRS: Point[] = [{ q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 }, { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 }];

const DEFAULT = ['oh_tipi', 'wa_bidi', 'treevor_mason'];
const key = (a: Point) => `${a.q},${a.r}`;
const same = (a: Point, b: Point) => a.q === b.q && a.r === b.r;
const point = (a: Point): Point => ({ q: a.q, r: a.r });
const sortedUnits = (units: SimUnit[]) => [...units].sort((a, b) => a.id.localeCompare(b.id));
export const teamForSeat=(state:Pick<SimState,'teams'>,seat:number):number=>state.teams[seat];
export const areAllies=(state:Pick<SimState,'teams'>,a:number,b:number):boolean=>state.teams[a]!==undefined&&state.teams[a]===state.teams[b];
export const activeSeats=(state:SimState):Player[]=>Array.from({length:state.playerCount},(_,seat)=>seat as Player).filter(seat=>state.units.some(unit=>unit.owner===seat&&isAlive(unit)));
export function seatTeams(playerCount:PlayerCount,mode:MatchMode):number[]{if(mode!=='free-for-all'&&mode!=='teams')throw new Error('Choose Free-for-all or Teams.');if(mode==='teams'&&playerCount%2)throw new Error('Teams need an even number of players.');return Array.from({length:playerCount},(_,seat)=>mode==='teams'?seat%2:seat);}
const heightAt = arenaHeightAt;
const wellAt = arenaWellAt;
/** Directional spells use six explicit aim axes, so rotation never needs a biased tie break. */
function aimDirection(from: Point, target: Point): number {
  const length = distance(from, target);
  return length ? DIRS.findIndex((direction) => target.q - from.q === direction.q * length && target.r - from.r === direction.r * length) : -1;
}
export const isAlive = (unit: SimUnit) => unit.hp > 0 && unit.respawn === undefined;
export const getCell = (state: SimState, q: number, r: number) => state.cells.find((cell) => cell.q === q && cell.r === r);
const occupant = (state: SimState, at: Point) => state.units.find((unit) => isAlive(unit) && same(unit, at));
const emit = (state: SimState, event: SimEvent) => { state.lastResolution.push(event); state.log.push(event.text); };
const name = (unit: SimUnit) => unit.displayName??getChampion(unit.championId).name;
export const reactionsFor = (elements: readonly Element[]): ReactionId[] => {
  const combination=combinationFor(elements);
  return combination&&combination.elements.length>1?[combination.id]:[];
};
/** Natural Earth and Water are ingredients before the first spell, too. */
export const cellElements = (cell: SimCell): Element[] => [...(cell.elements ?? (ELEMENT_ORDER.includes(cell.terrain as Element) ? [cell.terrain as Element] : combinationById(cell.terrain)?.elements ?? []))];
export const fieldCombination=(cell:SimCell):CombinationDefinition|undefined=>cell.ttl===undefined?undefined:combinationFor(cellElements(cell));
export const fieldEffects=(cell:SimCell):Readonly<CombinationMechanics>=>{
  const field=fieldCombination(cell),effects=field?.mechanics??{};
  // Frozen Water keeps its sliding route, but a dry ice surface does not soak an occupant.
  return cell.ice&&field?.id==='water'?{...effects,statuses:effects.statuses?.filter(status=>status.id!=='wet')}:effects;
};
const pureElement = (cell: SimCell, element: Element) => fieldCombination(cell)?.id===element;
export const isIce = (cell: SimCell): boolean => cell.ice === true;
export const isFlooded = (cell: SimCell): boolean => fieldEffects(cell).movement==='flood' && !isIce(cell);
/** One shared forecast for the resolver, planning UI and public-state AI. */
export function previewField(cell:SimCell,incomingElements:readonly Element[],freeze=false):SimCell {
  if(!incomingElements.length)return {...cell};
  const elements=ELEMENT_ORDER.filter(element=>cellElements(cell).includes(element)||incomingElements.includes(element));
  const combination=combinationFor(elements)!;
  const result:SimCell={...cell,elements:[...elements],reactions:reactionsFor(elements),terrain:combination.id,ttl:combination.mechanics.consume?1:TERRAIN_DURATION};
  if(combination.mechanics.movement==='ice'||combination.id==='water'&&(freeze||isIce(cell)))result.ice=true;
  else delete result.ice;
  return result;
}
export type SurfaceTrait = { id: 'ice' | 'flood' | 'embers' | 'rough' | 'current' | 'radiance' | 'gloom'; name: string; description: string };
/** Exact rules shared by inspection, help and the resolver. Base biomes keep their own rules. */
export function surfaceTraits(cell: SimCell): SurfaceTrait[] {
  const traits: SurfaceTrait[] = [];
  if (isIce(cell)) traits.push({ id: 'ice', name: 'Ice', description: 'Entering Ice slides straight to the last connected icy hex. The whole slide costs 1 effort; barriers, ruins and the edge stop it. Landing collisions bounce as usual.' });
  else if (isFlooded(cell)) traits.push({ id: 'flood', name: 'Flood', description: `Entering or leaving costs 2 effort. Does not stack with rough ground, marsh or climbing.${pureElement(cell,'water')?' Liquid Water grants Wet for 1 round and extinguishes Burn.':''}` });
  if (pureElement(cell, 'fire')) traits.push({ id: 'embers', name: 'Embers', description: 'Hurts the final occupant for 1 after displacement. All environmental hazards together deal at most 1 per round.' });
  if (fieldEffects(cell).movement==='rough' && !isIce(cell)) traits.push({ id: 'rough', name: 'Rough ground', description: 'Entering or leaving costs 2 effort. Does not stack with flood, marsh or climbing.' });
  if (fieldEffects(cell).movement==='current') traits.push({ id: 'current', name: 'Current', description: 'Starting here grants 1 extra movement effort, without stacking with Haste. Rooted still prevents movement.' });
  if (pureElement(cell, 'light')) traits.push({ id: 'radiance', name: 'Radiance', description: 'Its occupant gains Clarity, blocking incoming control now and during next planning. Benefits either team.' });
  if (pureElement(cell, 'dark')) traits.push({ id: 'gloom', name: 'Gloom', description: 'Its occupant gains Wither for next planning, reducing future healing by 1. Affects either team.' });
  return traits;
}

export type GameConfig={playerCount?:PlayerCount;mode?:MatchMode;seed?:string;rosters?:string[][];loadouts?:Record<string,string[]>[];learnedSignatures?:string[][];affinities?:Record<string,AffinityAllocation>[];names?:Record<string,string>[]};
export function createSimGame(config:GameConfig={}):SimState {
  object(config,['playerCount','mode','seed','rosters','loadouts','learnedSignatures','affinities','names'],'Match configuration');
  const playerCount=validatePlayerCount(config.playerCount??2),mode=config.mode??'free-for-all',teams=seatTeams(playerCount,mode),mapId=normalizeArenaMapId(config.seed??'WELLSPRING',playerCount);
  const rosters=config.rosters??Array.from({length:playerCount},()=>[...DEFAULT]);
  if(!Array.isArray(rosters)||rosters.length!==playerCount||rosters.some(roster=>!Array.isArray(roster)||roster.length!==3||new Set(roster).size!==3||roster.some(id=>!CHAMPIONS.some(champion=>champion.id===id))))throw new Error('Choose 3 different canonical characters for every player.');
  for(const [label,entries] of Object.entries({loadouts:config.loadouts,affinities:config.affinities,names:config.names}))if(entries!==undefined&&(!Array.isArray(entries)||entries.length!==playerCount))throw new Error(`${label} must describe every player.`);
  if(config.learnedSignatures!==undefined&&(!Array.isArray(config.learnedSignatures)||config.learnedSignatures.length!==playerCount||config.learnedSignatures.some(library=>!Array.isArray(library)||library.length)))throw new Error('Arena characters use their own signature; story unlocks do not change the shared budget.');
  const starts=arenaStarts(mapId),learnedSignatures=Array.from({length:playerCount},()=>[] as string[]);
  const units=rosters.flatMap((roster,owner)=>{
    const suppliedAffinities=config.affinities===undefined?{}:object(config.affinities[owner],roster,'Company affinities');
    const suppliedLoadouts=config.loadouts===undefined?{}:object(config.loadouts[owner],roster,'Company spells');
    const suppliedNames=config.names===undefined?{}:object(config.names[owner],roster,'Company names');
    return roster.map((championId,index):SimUnit=>{
      const canonical=canonicalBuild(championId),affinities=suppliedAffinities[championId]??canonical.affinities;
      const build=validateCharacterBuild({championId,name:suppliedNames[championId]??canonical.name,affinities,loadout:suppliedLoadouts[championId]??defaultLoadout(championId,affinities as AffinityAllocation,[])});
      return {id:`${owner}-${championId}`,championId,displayName:build.name,owner:owner as Player,...starts[owner][index],hp:MAX_HP,maxHp:MAX_HP,flux:MAX_FLUX,maxFlux:MAX_FLUX,cooldowns:{},statuses:{},affinities:build.affinities,loadout:build.loadout};
    });
  });
  return {rulesVersion:RULES_VERSION,spellModel:CURRENT_SPELL_MODEL,projectileModel:'volume',version:1,mapId,playerCount,mode,teams,boardRadius:arenaRadius(mapId),round:1,scores:Array(playerCount).fill(0),learnedSignatures,cells:generateArena(mapId).map(cell=>({...cell})),units,winner:null,log:['Each company moves, then every spell resolves together. Defeat all opposing companies.'],lastResolution:[]};
}

export function battleSpell(state:Pick<SimState,'spellModel'|'units'>,unitId:string,spellId:string):Spell {const unit=state.units.find(unit=>unit.id===unitId);if(!unit)throw new Error('Unknown champion.');return profileSpell(effectiveSpell(unit.championId,spellId,unit.affinities),state.spellModel);}

export const isCellSolid = (cell: SimCell): boolean => Boolean(cell.barrier) || cell.biome === 'ruins';
export const terrainCover = (cell: SimCell): number => Math.max(cell.biome === 'forest' ? 1 : 0,fieldEffects(cell).cover??0);
/** Aggregate once: a coordinated volley crosses protection together. */
export function mitigatedSpellDamage(cell:SimCell,ordinary:number,piercing:number,ward=0,guard=false):number {
  const total=ordinary+piercing,covered=fieldEffects(cell).damageScale==='half'?Math.ceil(total/2):total;
  const afterPiercing=total?Math.floor(covered*piercing/total):0;
  return Math.max(0,Math.max(0,covered-afterPiercing-terrainCover(cell)-ward)+afterPiercing-(guard?1:0));
}
/** Net vector first, then Guard resistance, then the ordinary two-step limit.
 * A step can become a longer slide on Ice. Anchored blocks the vector entirely. */
export function displacementSteps(vector:Point,guard=false,anchored=false):number {
  if(anchored)return 0;
  const strength=Math.max(Math.abs(vector.q),Math.abs(vector.r),Math.abs(vector.q+vector.r));
  return Math.min(2,Math.max(0,Math.ceil(strength-(guard?1:0)-1e-9)));
}
function displacementDirection(vector:Point):Point|undefined {
  const orientation=Math.sign(vector.q||vector.r);
  const ranked=DIRS.map(direction=>({direction,value:2*direction.q*vector.q+direction.q*vector.r+direction.r*vector.q+2*direction.r*vector.r})).sort((a,b)=>b.value-a.value||orientation*(b.direction.q-a.direction.q||b.direction.r-a.direction.r));
  return ranked[0].value>0?ranked[0].direction:undefined;
}
export type DisplacementPreview={landing:Point;path:Point[];impact:boolean};
/** Public geometry only: other units may move or block this route when sealed orders resolve. */
export function previewDisplacement(state:SimState,unitId:string,vector:Point,guard=false):DisplacementPreview {
  const unit=state.units.find(candidate=>candidate.id===unitId);
  if(!unit)throw new Error('Unknown champion.');
  const result:DisplacementPreview={landing:point(unit),path:[],impact:false};
  if(!isAlive(unit))return result;
  const direction=displacementDirection(vector),steps=displacementSteps(vector,guard,Boolean(unit.statuses.anchored));
  if(!direction||!steps)return result;
  const cells=new Map(state.cells.map(cell=>[key(cell),cell]));
  for(let step=0;step<steps;step++){
    const adjacent=cells.get(key({q:result.landing.q+direction.q,r:result.landing.r+direction.r}));
    if(!adjacent)break;
    if(isCellSolid(adjacent)){result.impact=true;break;}
    const crossed=slideStep(result.landing,direction,cells);
    result.path.push(...crossed.map(point));result.landing=point(crossed.at(-1)!);
  }
  return result;
}
/** Damage estimates read existing marks only, never a mark promised by this volley. */
export function volleyDamage(cell:SimCell,victim:SimUnit,spells:readonly Spell[],guard=false):number {
  let ordinary=0,piercing=0;
  for(const spell of spells){
    const bonus=spell.bonus&&(spell.bonus==='wounded'?victim.hp<victim.maxHp:Boolean(victim.statuses[spell.bonus]))?spell.bonusDamage??0:0;
    if(spell.pierce)piercing+=spell.damage+bonus;else ordinary+=spell.damage+bonus;
  }
  return mitigatedSpellDamage(cell,ordinary,piercing,victim.statuses.ward?.power??0,guard);
}
function spellForce(victim:Point,caster:Point,spell:Spell,target:Point):Point {
  if(!spell.push)return {q:0,r:0};
  const centre=forceOrigin(spell,caster,target);
  const length=distance(victim,centre)||1;
  return {q:(victim.q-centre.q)/length*spell.push,r:(victim.r-centre.r)/length*spell.push};
}
const addForce=(left:Point,right:Point):Point=>({q:left.q+right.q,r:left.r+right.r});
export function movementCost(from: SimCell, to: SimCell): number {
  if (isIce(to)) return 1;
  const rough = (cell: SimCell) => !isIce(cell) && fieldEffects(cell).movement==='rough';
  return to.biome === 'marsh' || isFlooded(from) || isFlooded(to) || rough(from) || rough(to) || to.height > from.height ? 2 : 1;
}
export function movementBudget(unit: SimUnit, state?: SimState): number {
  const startingCell = state && getCell(state, unit.q, unit.r);
  return unit.statuses.rooted ? 0 : (unit.statuses.chilled ? MOVE_RANGE - 1 : MOVE_RANGE) + (unit.statuses.haste || (startingCell && fieldEffects(startingCell).movement==='current') ? 1 : 0);
}
type MovementRoute = { path: SimCell[]; cost: number };
/** A straight slide stops on the last Ice cell, before dry ground or an obstacle. */
function slideStep(from: Point, direction: Point, cells: Map<string, SimCell>): SimCell[] {
  let cell = cells.get(`${from.q + direction.q},${from.r + direction.r}`);
  if (!cell || isCellSolid(cell)) return [];
  const crossed = [cell];
  if (isIce(cell)) while (true) {
    const further = cells.get(`${cell.q + direction.q},${cell.r + direction.r}`);
    if (!further || isCellSolid(further) || !isIce(further)) break;
    crossed.push(further); cell = further;
  }
  return crossed;
}
/** Ice edges are whole straight slides. Preview and resolution use the same reachable landings. */
function movementPaths(state: SimState, unit: SimUnit): Map<string, MovementRoute> {
  const paths = new Map<string, MovementRoute>(); const budget = movementBudget(unit, state);
  const cells = new Map(state.cells.map((cell) => [key(cell), cell])); const start = cells.get(key(unit));
  if (!start || !budget) return paths;
  const queue = [{ cell: start, cost: 0, path: [] as SimCell[] }]; const costs = new Map([[key(start), 0]]);
  const sign = 1;
  while (queue.length) {
    queue.sort((a, b) => a.cost - b.cost || sign * (a.cell.q - b.cell.q || a.cell.r - b.cell.r));
    const current = queue.shift()!;
    if (current.cost !== costs.get(key(current.cell))) continue;
    if (current.path.length) paths.set(key(current.cell), { path: current.path, cost: current.cost });
    for (const direction of DIRS) {
      const crossed = slideStep(current.cell, direction, cells), cell = crossed.at(-1);
      if (!cell) continue;
      const cost = current.cost + movementCost(current.cell, crossed[0]);
      if (cost > budget) continue;
      if (cost >= (costs.get(key(cell)) ?? Infinity)) continue;
      costs.set(key(cell), cost); queue.push({ cell, cost, path: [...current.path, ...crossed] });
    }
  }
  return paths;
}
export function movementPath(state: SimState, unitId: string, target: Point): SimCell[] | null {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit) || same(unit, target)) return null;
  return movementPaths(state, unit).get(key(target))?.path ?? null;
}
export function movementEffort(state: SimState, unitId: string, target: Point): number | null {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit)) return null;
  if (same(unit, target)) return 0;
  return movementPaths(state, unit).get(key(target))?.cost ?? null;
}
export function legalMoves(state: SimState, unitId: string): SimCell[] {
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null) return [];
  const unit = state.units.find((entry) => entry.id === unitId); if (!unit || !isAlive(unit)) return [];
  const paths = movementPaths(state, unit);
  return state.cells.filter((cell) => paths.has(key(cell)));
}
function clearSight(state: SimState, from: SimCell, target: SimCell, cells?:ReadonlyMap<string,SimCell>): boolean {
  const range = distance(from, target); if (range <= 1) return true;
  const queue = [from]; const seen = new Set([key(from)]);
  for (let i = 0; i < queue.length; i++) for (const direction of DIRS) {
    const current = queue[i]; const next = cells?cells.get(`${current.q+direction.q},${current.r+direction.r}`):getCell(state, current.q + direction.q, current.r + direction.r);
    if (!next || seen.has(key(next)) || distance(from, next) + distance(next, target) !== range || distance(from, next) <= distance(from, current)) continue;
    if (same(next, target)) return true;
    if (isCellSolid(next) || next.height > Math.max(from.height, target.height)) continue;
    seen.add(key(next)); queue.push(next);
  }
  return false;
}
export function castAvailability(state: SimState, unitId: string, spellId: string): { available: boolean; reason?: string; cost: number } {
  const unit = state.units.find((entry) => entry.id === unitId);
  if (!unit || !isAlive(unit)) return { available: false, cost: 0, reason: 'Champion is returning.' };
  const spell = ALL_SPELLS.find((entry) => entry.id === spellId);
  if (!spell || (spell.signatureChampionId!==unit.championId&&!unit.loadout.includes(spellId))) return { available: false, cost: 0, reason: 'Spell is not equipped.' };
  const cost = spellCost(unit.championId, spellId,unit.affinities) + (unit.statuses.concussed ? 1 : 0);
  const access=spellAccess(unit.championId,spellId,unit.affinities,state.learnedSignatures[unit.owner]);
  if(!access.unlocked)return {available:false,cost,reason:access.reason};
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null) return { available: false, cost, reason: 'Match is finished.' };
  if ((unit.cooldowns[spellId] ?? 0) > 0) return { available: false, cost, reason: `Ready after ${unit.cooldowns[spellId]} resolution(s).` };
  if (unit.flux < cost) return { available: false, cost, reason: `Needs ${cost} Flux; ${unit.flux} available.` };
  return { available: true, cost };
}
/** Effective centre reach; the footprint may extend beyond its aimed centre. */
const resolvedSpellRange=(unit:SimUnit,spell:Spell,origin:SimCell,target:SimCell):number=>spell.range===0?0:Math.max(1,spell.range-(unit.statuses.blind?1:0))+(origin.height>target.height?1:0);
export function spellRange(unit: SimUnit, spell: Spell, origin: SimCell, target: SimCell): number {
  spell=effectiveSpell(unit.championId,spell.id,unit.affinities);
  return resolvedSpellRange(unit,spell,origin,target);
}
export function legalCasts(state: SimState, unitId: string, from?: Point, spellId?: string): SimCell[] {
  const unit = state.units.find((entry) => entry.id === unitId); if (!unit || !isAlive(unit)) return [];
  const id = spellId ?? unit.loadout[0]; if (!castAvailability(state, unitId, id).available) return [];
  const spell = profileSpell(effectiveSpell(unit.championId,id,unit.affinities),state.spellModel); const origin = getCell(state, from?.q ?? unit.q, from?.r ?? unit.r); if (!origin) return [];
  const cells=new Map(state.cells.map(cell=>[key(cell),cell]));
  return state.cells.filter((cell) => {
    if (spell.range === 0) return same(origin, cell);
    if (spell.shape === 'line' && same(origin, cell)) return false;
    if ((spell.shape === 'sweep' || spell.shape === 'wall') && aimDirection(origin, cell) < 0) return false;
    const range = resolvedSpellRange(unit,spell,origin,cell);
    return distance(origin, cell) <= range && clearSight(state, origin, cell,cells);
  });
}
/** A line includes every tied shortest ray cell, never an arbitrary left/right tie. */
export function spellArea(state: SimState, unitId: string, spellId: string, target: Point, from?: Point): SimCell[] {
  const unit = state.units.find((entry) => entry.id === unitId); if (!unit) return [];
  const origin = from ?? unit; const spell = profileSpell(effectiveSpell(unit.championId,spellId,unit.affinities),state.spellModel);
  if (spell.shape === 'sweep' || spell.shape === 'wall') {
    const direction = aimDirection(origin, target); if (direction < 0) return [];
    const forward = DIRS[direction]; const across = DIRS[(direction + 2) % 6];
    const points = spell.shape === 'wall'
      ? Array.from({length:1+2*Math.max(1,spell.radius)},(_,index)=>({q:target.q+across.q*(index-Math.max(1,spell.radius)),r:target.r+across.r*(index-Math.max(1,spell.radius))}))
      : [target, ...[-1, 1].flatMap((offset) => { const side = DIRS[(direction + offset + 6) % 6]; return Array.from({ length: spell.radius || 1 }, (_, index) => ({ q: target.q + (side.q - forward.q) * (index + 1), r: target.r + (side.r - forward.r) * (index + 1) })); })];
    return state.cells.filter((cell) => points.some((entry) => same(entry, cell)));
  }
  if (spell.shape === 'line') {
    const cells=new Map(state.cells.map(cell=>[key(cell),cell]));
    const start = getCell(state, origin.q, origin.r); const end = getCell(state, target.q, target.r);
    if (!start || !end || same(start, end)) return [];
    const length = distance(start, end); const limit = Math.max(start.height, end.height); const included = new Set<string>();
    const visit = (cell: SimCell, path: SimCell[]) => {
      if (same(cell, end)) { path.forEach((entry) => included.add(key(entry))); return; }
      for (const direction of DIRS) {
        const next = cells.get(`${cell.q+direction.q},${cell.r+direction.r}`);
        if (!next || distance(start, next) + distance(next, end) !== length || distance(start, next) <= distance(start, cell)) continue;
        if (!same(next, end) && (isCellSolid(next) || next.height > limit)) continue;
        visit(next, [...path, next]);
      }
    };
    visit(start, []); return state.cells.filter((cell) => included.has(key(cell)));
  }
  return state.cells.filter((cell) => spell.shape === 'ring' ? distance(cell, target) === spell.radius
    : distance(cell, target) <= (spell.shape === 'burst' ? spell.radius : 0));
}
function object(input: unknown, allowed: string[], label: string): Record<string, unknown> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error(`${label} must be an object.`);
  const value = input as Record<string, unknown>;
  if (Object.keys(value).some((field) => !allowed.includes(field))) throw new Error(`${label} contains an unknown field.`);
  return value;
}
function readPoint(input: unknown): Point {
  const value = object(input, ['q', 'r'], 'Hex');
  if (!Number.isSafeInteger(value.q) || !Number.isSafeInteger(value.r)) throw new Error('Hex coordinates must be whole numbers.');
  return { q: value.q as number, r: value.r as number };
}
function preparation(state:SimState,player:Player,input:unknown):{projected:SimState} {
  if(state.rulesVersion!==RULES_VERSION||state.winner!==null||(!Number.isInteger(player)||player<0||player>=state.playerCount))throw new Error('This tactics match is not active.');
  const value=object(input,['orders','training','loadouts'],'Plan');
  if(!Array.isArray(value.orders)||value.orders.length>3)throw new Error('At most 3 champion orders are allowed.');
  if(value.training!==undefined&&(!Array.isArray(value.training)||value.training.length))throw new Error('Affinity is earned in Story and allocated before a match.');
  if(value.loadouts!==undefined&&(!Array.isArray(value.loadouts)||value.loadouts.length))throw new Error('Your four spells are fixed for this match. Change your kit in camp.');
  return {projected:structuredClone(state)};
}
/** Planning never changes the fixed affinity allocation or the four-spell kit. */
export function prepareTeam(state:SimState,player:Player,plan:TeamPlan):SimState {
  return preparation(state,player,plan).projected;
}
export function validatePlan(state: SimState, player: Player, input: unknown): TeamPlan {
  const prepared=preparation(state,player,input);state=prepared.projected;
  const value = input as {orders:unknown[]};
  const orders = new Map<string, Order>();
  for (const raw of value.orders) {
    const entry = object(raw, ['unitId', 'move', 'cast', 'spellId', 'guard'], 'Order');
    if (typeof entry.unitId !== 'string' || orders.has(entry.unitId)) throw new Error('Each champion may have one order.');
    const unit = state.units.find((candidate) => candidate.id === entry.unitId);
    if (!unit || unit.owner !== player || !isAlive(unit)) throw new Error('Order only your living champions.');
    const order: Order = { unitId: unit.id };
    if (entry.move !== undefined) { order.move = readPoint(entry.move); if (!movementPath(state, unit.id, order.move)) throw new Error('Movement is blocked or exceeds available effort.'); }
    if (entry.guard !== undefined && entry.guard !== true) throw new Error('Guard must be true when included.');
    if (entry.cast !== undefined) {
      if (entry.guard) throw new Error('Choose a spell or Guard, not both.');
      const id = entry.spellId ?? unit.loadout[0];
      if (typeof id !== 'string') throw new Error('Spell must be an equipped identifier.');
      const availability = castAvailability(state, unit.id, id); if (!availability.available) throw new Error(availability.reason);
      order.spellId = id; order.cast = readPoint(entry.cast);
      if (!legalCasts(state, unit.id, order.move, id).some((cell) => same(cell, order.cast!))) throw new Error('Aim within range and sight from the planned landing.');
    } else { if (entry.spellId !== undefined) throw new Error('A spell needs a ground target.'); order.guard = true; }
    orders.set(unit.id, order);
  }
  return { orders: sortedUnits(state.units.filter((unit) => unit.owner === player && isAlive(unit))).map((unit) => orders.get(unit.id) ?? { unitId: unit.id, guard: true }) };
}
function destinations(state: SimState, requests: Map<string, Point>, kind: 'move' | 'push'): void {
  const units = sortedUnits(state.units.filter(isAlive)); const active = new Set(requests.keys()); const counts = new Map<string, number>();
  for (const target of requests.values()) counts.set(key(target), (counts.get(key(target)) ?? 0) + 1);
  for (const [id, target] of requests) if (counts.get(key(target))! > 1 || !getCell(state, target.q, target.r) || isCellSolid(getCell(state, target.q, target.r)!)) active.delete(id);
  let changed = true;
  while (changed) { changed = false; for (const unit of units) if (active.has(unit.id)) { const blocker = units.find((entry) => same(entry, requests.get(unit.id)!)); if (blocker && !active.has(blocker.id)) { active.delete(unit.id); changed = true; } } }
  const before = new Map(units.map((unit) => [unit.id, point(unit)]));
  for (const unit of units) { const target = requests.get(unit.id); if (!target) continue; if (active.has(unit.id)) { unit.q = target.q; unit.r = target.r; emit(state, { kind, unitId: unit.id, owner: unit.owner, from: before.get(unit.id), to: point(unit), text: `${name(unit)} ${kind === 'move' ? 'moves' : 'is displaced'} to ${formatTile(unit,state.boardRadius)}.` }); } else emit(state, { kind: 'bounce', unitId: unit.id, owner: unit.owner, from: before.get(unit.id), to: target, text: `${name(unit)} stays: simultaneous ${kind} blocked.` }); }
}
type Cast = { caster: SimUnit; spell: Spell; target: Point; area: SimCell[] };
function mergeStatus(statuses: SimUnit['statuses'], application: StatusApplication): void {
  const previous = statuses[application.id]; statuses[application.id] = { turns: Math.max(previous?.turns ?? 0, application.turns), power: Math.max(previous?.power ?? 0, application.power ?? 1) };
}
function defeat(state: SimState, unit: SimUnit, previous:SimState): void {
  if(unit.hp>0||!previous.units.some(old=>old.id===unit.id&&isAlive(old))||state.lastResolution.some(event=>event.kind==='defeat'&&event.unitId===unit.id))return;
  unit.hp=0;unit.flux=0;unit.statuses={};unit.cooldowns={};delete unit.guard;delete unit.respawn;
  emit(state,{kind:'defeat',unitId:unit.id,owner:unit.owner,q:unit.q,r:unit.r,text:`${name(unit)} is defeated for this battle.`});
}

/** Victory reads the final shared result, after both teams and all terrain effects. */
export function eliminationWinner(units:readonly SimUnit[],round:number,teams:readonly number[]=Array.from({length:6},(_,seat)=>seat)):Player|'draw'|null {
  const survivors=new Set(units.filter(isAlive).map(unit=>teams[unit.owner]));
  if(!survivors.size)return 'draw';
  if(survivors.size===1)return [...survivors][0] as Player;
  return null;
}

export function resolveRound(state:SimState,plans:TeamPlan[]):SimState {
  if(!Array.isArray(plans)||plans.length!==state.playerCount)throw new Error('One sealed plan per player is required.');
  const normalized=plans.map((plan,seat)=>validatePlan(state,seat as Player,plan));
  const next=structuredClone(state);next.version++;next.lastResolution=[];next.projectileModel='volume';
  const orders = new Map(normalized.flatMap((plan) => plan.orders).map((order) => [order.unitId, order]));
  for (const unit of sortedUnits(next.units.filter(isAlive))) { unit.guard = orders.get(unit.id)!.guard === true; if (unit.guard) emit(next, { kind: 'guard', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, text: `${name(unit)} Guards: absorb 1 damage, resist 1 push/pull strength, recover +1 Flux.` }); }
  destinations(next, new Map([...orders.values()].filter((order) => order.move).map((order) => [order.unitId, order.move!])), 'move');
  const releasedCasts: Cast[] = [];
  // Every legality check reads the same post-move, pre-effect snapshot. No new effect cancels a sealed spell.
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const order = orders.get(unit.id)!; if (!order.cast) continue;
    const spell = profileSpell(effectiveSpell(unit.championId,order.spellId!,unit.affinities),state.spellModel);
    if (!legalCasts(next, unit.id, undefined, spell.id).some((cell) => same(cell, order.cast!))) { emit(next, { kind: 'fizzle', unitId: unit.id, owner: unit.owner, spellId: spell.id, to: order.cast, text: `${name(unit)}'s ${spell.name} fizzles after a blocked landing. No Flux or cooldown spent.` }); continue; }
    releasedCasts.push({ caster: structuredClone(unit), spell, target: order.cast, area: spellArea(next, unit.id, spell.id, order.cast) });
  }
  const snapshot = structuredClone(next);
  for (const unit of next.units) {
    for (const [id, turns] of Object.entries(unit.cooldowns)) if (turns > 1) unit.cooldowns[id] = turns - 1; else delete unit.cooldowns[id];
    unit.statuses = Object.fromEntries(Object.entries(unit.statuses).filter(([, value]) => value!.turns > 1).map(([id, value]) => [id, { ...value!, turns: value!.turns - 1 }]));
  }
  for (const cast of releasedCasts) {
    const unit = next.units.find((entry) => entry.id === cast.caster.id)!;
    unit.flux -= castAvailability(snapshot, unit.id, cast.spell.id).cost;
    if (cast.spell.cooldown) unit.cooldowns[cast.spell.id] = cast.spell.cooldown;
    emit(next, { kind: 'cast', unitId: unit.id, owner: unit.owner, spellId: cast.spell.id, from: point(cast.caster), to: cast.target, q: cast.target.q, r: cast.target.r, elements: [cast.spell.element], text: `${name(unit)} casts ${cast.spell.name}.` });
  }
  const clashes=findProjectileClashes(releasedCasts.filter(cast=>isTravellingProjectile(cast.spell,cast.caster,cast.target,snapshot.units.some(unit=>isAlive(unit)&&areAllies(snapshot,unit.owner,cast.caster.owner)&&same(unit,cast.target)))).map(cast=>({unitId:cast.caster.id,from:point(cast.caster),to:cast.target,element:cast.spell.element})),next.cells);
  const intercepted=new Set(clashes.flatMap(clash=>clash.participants)),casts=releasedCasts.filter(cast=>!intercepted.has(cast.caster.id));
  const clashFields=clashes.map(clash=>({...clash,area:interceptionFieldArea(next.cells,clash),freeze:releasedCasts.some(cast=>clash.participants.includes(cast.caster.id)&&cast.spell.freeze)}));
  for(const clash of clashes){const mixture=combinationFor(clash.elements)!;emit(next,{kind:'clash',...clash,terrain:mixture.id,text:`${clash.participants.length} spells meet in flight: ${mixture.name} spreads across ${interceptionFieldArea(next.cells,clash).length} hexes at ${formatTile(clash,state.boardRadius)}. Their original target hits are canceled.`});}
  // Public inhabitants contribute to the same batch. An announced counter at
  // their perch suppresses the pulse before any field is formed, for either team.
  const pulses=inhabitantPulses(snapshot).filter(pulse=>{
    const interrupted=casts.some(cast=>cast.spell.element===pulse.counterElement&&cast.area.some(cell=>same(cell,pulse.anchor)));
    emit(next,{kind:'inhabitant',speciesId:pulse.id,interrupted,q:pulse.anchor.q,r:pulse.anchor.r,elements:[...pulse.elements],terrain:combinationFor(pulse.elements)!.id,text:interrupted?`${pulse.name}'s release is interrupted by ${pulse.counterElement}.`:`${pulse.name} releases ${combinationFor(pulse.elements)!.name} across ${pulse.area.length} hexes.`});
    return !interrupted;
  });
  // Natural substrate, surviving field, player casts and creatures form one set.
  // Exactly one named phenomenon resolves; no contained pair runs underneath it.
  const formedFields = new Set<string>();
  for (const cell of next.cells) {
    const arrivals = casts.filter(cast=>cast.area.some(area=>same(area,cell)));
    const clashArrivals=clashFields.filter(clash=>clash.area.some(area=>same(area,cell)));
    const creatureArrivals=pulses.filter(pulse=>pulse.area.some(area=>same(area,cell)));
    if(!arrivals.length&&!creatureArrivals.length&&!clashArrivals.length)continue;
    const previous=fieldCombination(cell),previouslyIce=isIce(cell),previouslyFlooded=isFlooded(cell);
    Object.assign(cell,previewField(cell,[...arrivals.map(cast=>cast.spell.element),...creatureArrivals.flatMap(pulse=>pulse.elements),...clashArrivals.flatMap(clash=>clash.elements)],arrivals.some(cast=>cast.spell.freeze)||clashArrivals.some(clash=>clash.freeze)));
    // Object.assign cannot remove an old icy property when a transformation thaws it.
    const combination=fieldCombination(cell)!;
    if(combination.mechanics.movement!=='ice'&&combination.id!=='water')delete cell.ice;
    if(previous?.id!==combination.id)formedFields.add(key(cell));
    if(isIce(cell)&&!previouslyIce)emit(next,{kind:'surface',q:cell.q,r:cell.r,terrain:'ice',text:`Ice forms at ${formatTile(cell,state.boardRadius)}: entering slides to the end of its straight icy lane.`});
    else if(isFlooded(cell)&&(!previouslyFlooded||previouslyIce))emit(next,{kind:'surface',q:cell.q,r:cell.r,terrain:'water',text:`Water floods ${formatTile(cell,state.boardRadius)}: entering or leaving costs 2 effort.`});
    if(cell.reactions!.length)emit(next,{kind:'reaction',q:cell.q,r:cell.r,terrain:combination.id,elements:[...cell.elements!],text:`${combination.name} forms at ${formatTile(cell,state.boardRadius)}. ${combination.shortRule}.`});
    if(arrivals.some(cast=>cast.spell.dispel))delete cell.barrier;
    else if(arrivals.some(cast=>cast.spell.wall)&&!occupant(snapshot,cell)&&!cell.well&&cell.biome!=='ruins'){cell.barrier=2;emit(next,{kind:'surface',q:cell.q,r:cell.r,terrain:'earth',text:`A cairn blocks ${formatTile(cell,state.boardRadius)} through next resolution.`});}
  }
  const criticalDamage=new Set<string>(),criticalHealing=new Set<string>();
  const damageSources=new Map<string,ConsequenceSource[]>(),healingSources=new Map<string,ConsequenceSource[]>();
  const damages = new Map<string, number>(); const spellDamages = new Map<string, number>(); const heals = new Map<string, number>(); const gains = new Map<string, number>();
  const incoming = new Map<string, StatusApplication[]>(); const cleansed = new Set<string>(); const wet = new Set<string>();
  const stealRequests: { source: string; victim: string; amount: number }[] = [];
  for (const unit of snapshot.units.filter(isAlive)) {
    const relevant = casts.filter((cast) => cast.area.some((cell) => same(cell, unit))).map(cast=>({...cast,spell:spellAtCell(cast.spell,cast.target,unit)}));
    const friendly = relevant.filter((cast) => areAllies(snapshot,cast.caster.owner,unit.owner));
    const field = getCell(next, unit.q, unit.r)!;
    const effects=fieldEffects(field);
    const cleanse = effects.cleanse===true || friendly.some((cast) => cast.spell.cleanse);
    if (cleanse) cleansed.add(unit.id);
    const applications = relevant.flatMap((cast) => [
      ...(areAllies(snapshot,cast.caster.owner,unit.owner) ? cast.spell.friendly ?? [] : []),
      ...(cast.spell.harm === 'all' || !areAllies(snapshot,cast.caster.owner,unit.owner) ? cast.spell.harmful ?? [] : []),
    ]);
    applications.push(...(effects.statuses??[]));
    for (const cast of releasedCasts.filter((entry) => entry.caster.id === unit.id)) applications.push(...(cast.spell.self ?? []));
    incoming.set(unit.id, applications);
    if (unit.statuses.wet || applications.some((application) => application.id === 'wet')) wet.add(unit.id);
    const ward = unit.statuses.ward?.power ?? 0;
    const harmful = relevant.filter((cast) => cast.spell.harm === 'all' || !areAllies(snapshot,cast.caster.owner,unit.owner));
    const hit = (cast: Cast) => cast.spell.damage + (cast.spell.bonus && (cast.spell.bonus === 'wounded' ? unit.hp < unit.maxHp : unit.statuses[cast.spell.bonus]) ? cast.spell.bonusDamage ?? 0 : 0);
    const ordinary = harmful.filter((cast) => !cast.spell.pierce).reduce((sum, cast) => sum + hit(cast), 0);
    const piercing = harmful.filter((cast) => cast.spell.pierce).reduce((sum, cast) => sum + hit(cast), 0);
    const total = ordinary + piercing;
    const spellDamage = mitigatedSpellDamage(field,ordinary,piercing,ward,unit.guard);
    spellDamages.set(unit.id, spellDamage);
    const withoutCritical=harmful.map(cast=>({...cast.spell,damage:cast.spell.damage-Number(cast.spell.damage>0&&focusZone(cast.spell,cast.target,unit)==='centre')}));
    if(spellDamage>volleyDamage(field,unit,withoutCritical,unit.guard))criticalDamage.add(unit.id);
    if(friendly.some(cast=>cast.spell.heal>0&&focusZone(cast.spell,cast.target,unit)==='centre'))criticalHealing.add(unit.id);
    const burn = !cleanse && !wet.has(unit.id) ? unit.statuses.burn?.power ?? 0 : 0;
    const recoil = releasedCasts.filter((cast) => cast.caster.id === unit.id).reduce((sum, cast) => sum + (cast.spell.selfDamage ?? 0), 0);
    damages.set(unit.id, spellDamage + burn + recoil);
    if (total > 0) delete next.units.find((entry) => entry.id === unit.id)!.statuses.ward;
    heals.set(unit.id, friendly.reduce((sum, cast) => sum + cast.spell.heal, 0) + (effects.heal??0));
    gains.set(unit.id, friendly.reduce((sum, cast) => sum + (cast.spell.recharge ?? 0), 0)+(effects.flux??0));
    if(state.spellModel===CURRENT_SPELL_MODEL){
      damageSources.set(unit.id,[...harmful.map(cast=>({kind:'spell' as const,unitId:cast.caster.id,spellId:cast.spell.id,amount:hit(cast)})),{kind:'burn',amount:burn},...releasedCasts.filter(cast=>cast.caster.id===unit.id&&cast.spell.selfDamage).map(cast=>({kind:'recoil' as const,unitId:unit.id,spellId:cast.spell.id,amount:cast.spell.selfDamage!}))]);
      healingSources.set(unit.id,[...friendly.filter(cast=>cast.spell.heal>0).map(cast=>({kind:'spell' as const,unitId:cast.caster.id,spellId:cast.spell.id,amount:cast.spell.heal})),{kind:'field',amount:effects.heal??0}]);
    }
    for (const cast of harmful) if (!areAllies(snapshot,cast.caster.owner,unit.owner)) {
      if (cast.spell.steal) stealRequests.push({ source: cast.caster.id, victim: unit.id, amount: cast.spell.steal });
    }
  }
  // Accumulate all siphons only after target mitigation is known, then apply Wither once.
  for (const cast of casts.filter((entry) => entry.spell.drain)) {
    const victims = snapshot.units.filter((unit) => isAlive(unit) && !areAllies(snapshot,unit.owner,cast.caster.owner) && cast.area.some((cell) => same(cell, unit)) && (spellDamages.get(unit.id) ?? 0) > 0);
    heals.set(cast.caster.id, (heals.get(cast.caster.id) ?? 0) + victims.length * cast.spell.drain!);
    if(state.spellModel===CURRENT_SPELL_MODEL)healingSources.get(cast.caster.id)?.push({kind:'drain',unitId:cast.caster.id,spellId:cast.spell.id,amount:victims.length*cast.spell.drain!});
  }
  for (const unit of snapshot.units.filter(isAlive)) heals.set(unit.id, Math.max(0, (heals.get(unit.id) ?? 0) - (cleansed.has(unit.id) ? 0 : unit.statuses.wither?.power ?? 0)));
  // Equal competing theft requests share only the Flux available after all spell costs; remainder stays.
  for (const victim of next.units.filter(isAlive)) {
    const requests = stealRequests.filter((request) => request.victim === victim.id); if (!requests.length) continue;
    const total = requests.reduce((sum, request) => sum + request.amount, 0); const available = Math.min(victim.flux, total);
    for (const request of requests) { const transfer = Math.floor(available * request.amount / total); victim.flux -= transfer; gains.set(request.source, (gains.get(request.source) ?? 0) + transfer); }
  }
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const before = snapshot.units.find((entry) => entry.id === unit.id)!; const hurt = damages.get(unit.id) ?? 0; const heal = heals.get(unit.id) ?? 0;
    const damageDetail=state.spellModel===CURRENT_SPELL_MODEL?combatBreakdown(damageSources.get(unit.id)??[],hurt):undefined;
    const healingDetail=state.spellModel===CURRENT_SPELL_MODEL?combatBreakdown(healingSources.get(unit.id)??[],heal):undefined;
    unit.hp = Math.max(0, Math.min(unit.maxHp, unit.hp + heal - hurt));
    if (hurt||damageDetail?.sources.length) emit(next, { kind: 'damage',...(damageDetail?{breakdown:damageDetail}:{}), unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: hurt, ...(criticalDamage.has(unit.id)?{critical:true as const}:{}), text: `${name(unit)} takes ${hurt} damage in the exchange.` });
    if (heal||healingDetail?.sources.length) emit(next, { kind: 'heal',...(healingDetail?{breakdown:healingDetail}:{}), unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, amount: heal, ...(heal>0&&criticalHealing.has(unit.id)?{critical:true as const}:{}), text: `${name(unit)} receives ${heal} healing in the exchange.` });
    if (cleansed.has(unit.id)) for (const id of AILMENTS) delete unit.statuses[id];
    const applications = incoming.get(unit.id) ?? [];
    const freshClarity = applications.some((application) => application.id === 'clarity');
    for (const application of applications) {
      if (CONTROL.includes(application.id) && (before.statuses.resolve || before.statuses.clarity || freshClarity || cleansed.has(unit.id))) continue;
      if (AILMENTS.includes(application.id) && cleansed.has(unit.id) && !(application.id === 'burn' && casts.some((cast) => areAllies(snapshot,cast.caster.owner,unit.owner) && cast.spell.id === 'cauterize' && cast.area.some((cell) => same(cell, unit))))) continue;
      if (application.id === 'burn' && wet.has(unit.id)) continue;
      mergeStatus(unit.statuses, application);
      if (CONTROL.includes(application.id)) mergeStatus(unit.statuses, { id: 'resolve', turns: 2, power: 1 });
    }
    if (wet.has(unit.id)) delete unit.statuses.burn;
    for (const id of Object.keys(unit.statuses) as StatusId[]) if ((incoming.get(unit.id) ?? []).some((application) => application.id === id)) emit(next, { kind: 'surface', unitId: unit.id, owner: unit.owner, q: unit.q, r: unit.r, status: id, text: `${name(unit)} gains ${STATUS_DEFINITIONS.find((definition) => definition.id === id)!.name} for ${unit.statuses[id]!.turns} planning round(s).` });
  }
  sortedUnits(next.units).forEach((unit) => defeat(next, unit, state));
  // Vectors are summed from the common spell snapshot, then resolved one step at a time.
  const vectors = new Map<string, Point>();
  const displaced=new Set<string>(),impacts=new Set<string>();
  for (const unit of next.units.filter(isAlive)) {
    const old = snapshot.units.find((entry) => entry.id === unit.id)!;
    if (old.statuses.anchored) continue;
    const vector = casts.filter((cast) => cast.spell.push && cast.area.some((cell) => same(cell, old))).reduce((sum, cast) => addForce(sum,spellForce(old,cast.caster,cast.spell,cast.target)), { q: 0, r: 0 });
    if (displacementSteps(vector,old.guard)) vectors.set(unit.id, vector);
  }
  for (let step = 0; step < 2; step++) {
    const requests = new Map<string, Point>();
    const cells = new Map(next.cells.map((cell) => [key(cell), cell]));
    for (const [id, vector] of vectors) {
      const old=snapshot.units.find(unit=>unit.id===id)!;
      if(displacementSteps(vector,old.guard,Boolean(old.statuses.anchored))<=step)continue;
      const direction=displacementDirection(vector);
      if(!direction)continue;
      const unit = next.units.find((entry) => entry.id === id)!;
      const target = slideStep(unit, direction, cells).at(-1) ?? { q: unit.q + direction.q, r: unit.r + direction.r };
      const targetCell=getCell(next,target.q,target.r);
      if(targetCell){
        requests.set(id,point(target));
        if(isCellSolid(targetCell))impacts.add(id);
      }
    }
    const before = new Map(next.units.map((unit) => [unit.id, point(unit)])); destinations(next, requests, 'push');
    for (const id of requests.keys()) {
      if(same(next.units.find(unit=>unit.id===id)!,before.get(id)!))vectors.delete(id);
      else displaced.add(id);
    }
  }
  // Contact after forced movement is a second, bounded status opportunity.
  // Spell-phase healing, Flux and mitigation remain at the exchange position.
  // No contact creates another spell, force or field, so reactions cannot recurse.
  for(const unit of sortedUnits(next.units.filter(isAlive))){
    const before=snapshot.units.find(candidate=>candidate.id===unit.id)!;
    const applyContact=(application:StatusApplication)=>{
      if(CONTROL.includes(application.id)&&(before.statuses.resolve||before.statuses.clarity||unit.statuses.resolve||unit.statuses.clarity||cleansed.has(unit.id)))return;
      if(AILMENTS.includes(application.id)&&cleansed.has(unit.id))return;
      if(application.id==='burn'&&(wet.has(unit.id)||unit.statuses.wet))return;
      const previous=unit.statuses[application.id];
      mergeStatus(unit.statuses,application);
      if(CONTROL.includes(application.id))mergeStatus(unit.statuses,{id:'resolve',turns:2,power:1});
      if(application.id==='wet'){wet.add(unit.id);delete unit.statuses.burn;}
      const current=unit.statuses[application.id]!;
      if(!previous||current.turns!==previous.turns||current.power!==previous.power)emit(next,{kind:'surface',unitId:unit.id,owner:unit.owner,q:unit.q,r:unit.r,status:application.id,text:`${name(unit)} gains ${STATUS_DEFINITIONS.find(definition=>definition.id===application.id)!.name} for ${current.turns} planning round(s).`});
    };
    if(displaced.has(unit.id)){
      const effects=fieldEffects(getCell(next,unit.q,unit.r)!);
      if(effects.cleanse){
        const removed=AILMENTS.some(id=>unit.statuses[id]);
        cleansed.add(unit.id);for(const id of AILMENTS)delete unit.statuses[id];
        if(removed)emit(next,{kind:'surface',unitId:unit.id,owner:unit.owner,q:unit.q,r:unit.r,text:`${name(unit)} sheds ailments on landing.`});
      }
      // Immediate Clarity protects against all contact control, irrespective of descriptor order.
      for(const application of effects.statuses??[])if(application.id==='clarity')applyContact(application);
      for(const application of effects.statuses??[])if(application.id!=='clarity')applyContact(application);
    }
    if(impacts.has(unit.id)){
      unit.hp=Math.max(0,unit.hp-1);
      emit(next,{kind:'surface',unitId:unit.id,owner:unit.owner,q:unit.q,r:unit.r,amount:1,terrain:'earth',text:`${name(unit)} strikes solid terrain for 1 damage (environmental cap).`});
      applyContact({id:'concussed',turns:1,power:1});
    }
  }
  sortedUnits(next.units).forEach(unit=>defeat(next,unit,state));
  for (const unit of sortedUnits(next.units.filter(isAlive))) {
    const cell = getCell(next, unit.q, unit.r)!;
    const effects=fieldEffects(cell),old=state.units.find(previous=>previous.id===unit.id)!;
    const hurt=effects.hazard==='always'||effects.hazard==='formed'&&formedFields.has(key(cell))||effects.hazard==='moved'&&!same(old,unit);
    if(hurt&&!impacts.has(unit.id)){
      const combination=fieldCombination(cell)!;
      unit.hp=Math.max(0,unit.hp-1);emit(next,{kind:'surface',unitId:unit.id,owner:unit.owner,q:unit.q,r:unit.r,amount:1,terrain:combination.id,text:`${combination.name} hurts ${name(unit)} for 1 (environmental cap).`});
    }
  }
  sortedUnits(next.units).forEach((unit) => defeat(next, unit, state));
  // All spells, healing, force and ordinary hazards finish before the border is checked.
  // Collapse is one simultaneous unmitigated batch at final positions, not another field.
  // The last safe area is the unwallable centre hex. Unique occupancy and 8 maximum HP
  // prove that its final 8-damage outer band leaves at most one champion alive.
  for(const unit of sortedUnits(next.units.filter(isAlive))){
    const harm=collapseDamageAt(state,unit);if(!harm)continue;
    unit.hp=Math.max(0,unit.hp-harm);
    emit(next,{kind:'damage',cause:'collapse',unitId:unit.id,owner:unit.owner,q:unit.q,r:unit.r,amount:harm,text:`Collapse strikes ${name(unit)} for ${harm} damage outside the safe boundary. Guard and Ward cannot block it.`});
  }
  sortedUnits(next.units).forEach(unit=>defeat(next,unit,state));
  // Springs are optional tactical resources, never an alternate victory track.
  const springGains=new Map(next.units.filter(isAlive).map(unit=>{
    const cell=getCell(next,unit.q,unit.r)!;
    return [unit.id,cell.well?1+(fieldEffects(cell).wellBonus??0):0] as const;
  }));
  for (const cell of next.cells) {
    if (cell.ttl !== undefined && --cell.ttl <= 0) { cell.terrain = baseTerrainAt(cell.q, cell.r, next.mapId); delete cell.ttl; delete cell.elements; delete cell.reactions; delete cell.ice; }
    if (cell.barrier !== undefined && --cell.barrier <= 0) delete cell.barrier;
  }
  for (const unit of next.units.filter(isAlive)) unit.flux = Math.min(unit.maxFlux, unit.flux + 2 + (unit.guard ? 1 : 0) + (gains.get(unit.id) ?? 0) + (springGains.get(unit.id) ?? 0));
  next.winner=eliminationWinner(next.units,next.round,next.teams);
  if(next.winner!==null)next.log.push(next.winner==='draw'?'Every remaining company falls in the same exchange. The battle is a draw.':`${next.mode==='teams'?'Team':'Player'} ${next.winner+1} wins.`);
  else next.round++;
  next.log = next.log.slice(-150); return next;
}

export function previewPlan(state: SimState, player: Player, input: TeamPlan): string[] {
  const plan = validatePlan(state, player, input);state=prepareTeam(state,player,plan); const lines: string[] = [];
  const clashes=plannedProjectileClashes(state,plan),intercepted=new Set(clashes.flatMap(clash=>clash.participants));
  for(const clash of clashes)lines.push(`In-flight meeting at ${formatTile(clash,state.boardRadius)}: ${clash.participants.map(id=>name(state.units.find(unit=>unit.id===id)!)).join(' + ')} form ${combinationFor(clash.elements)!.name} across ${interceptionFieldArea(state.cells,clash).length} hexes. Their original target effects are replaced; hidden enemy spells can change this.`);
  for (const order of plan.orders) {
    const unit = state.units.find((entry) => entry.id === order.unitId)!; const landing = order.move ?? unit;
    lines.push(`${name(unit)}: ${order.move ? `move ${formatTile(order.move,state.boardRadius)} (${movementEffort(state, unit.id, order.move)} effort)` : 'hold'}; ${order.cast ? `${getSpell(order.spellId!).name} at ${formatTile(order.cast,state.boardRadius)} (${castAvailability(state, unit.id, order.spellId!).cost} Flux)` : 'Guard and recover +1 Flux'}.`);
    if (order.cast) {
      const spell = profileSpell(effectiveSpell(unit.championId,order.spellId!,unit.affinities),state.spellModel); const area = spellArea(state, unit.id, spell.id, order.cast, landing);
      if (!intercepted.has(unit.id)&&spell.damage && spell.harm === 'all' && plan.orders.some((ally) => area.some((cell) => same(cell, ally.move ?? state.units.find((entry) => entry.id === ally.unitId)!)))) lines.push(`${spell.name}: friendly fire risk inside its ${area.length}-hex footprint.`);
      if (order.move && !legalCasts(state, unit.id, undefined, spell.id).some((cell) => same(cell, order.cast!))) lines.push(`${spell.name} depends on the landing: a collision can make it fizzle without spending Flux.`);
    }
  }
  for (const cell of state.cells) {
    const incoming = [...plan.orders.filter((order) => !intercepted.has(order.unitId)&&order.cast && spellArea(state, order.unitId, order.spellId!, order.cast, order.move).some((area) => same(area, cell))).map((order) => getSpell(order.spellId!).element),...clashes.filter(clash=>interceptionFieldArea([cell],clash).length).flatMap(clash=>clash.elements)];
    if (!incoming.length) continue; const reactions = reactionsFor([...cellElements(cell), ...incoming]);
    if (reactions.length) lines.push(`${formatTile(cell,state.boardRadius)}: ${reactions.map((id) => combinationById(id)!.name).join('')}. The complete mixture is one field; hidden enemy spells can change it.`);
  }
  const zone=endgameForecast(state);
  if(zone.phase!=='calm')lines.push(zone.damage?`Outside radius ${zone.safeRadius}: ${zone.damage} Collapse damage after all movement, spells and displacement. Guard and Ward do not block it.`:`The outer boundary closes in ${zone.firstClosureRound-state.round} rounds. Move inside radius ${zone.nextSafeRadius} before then.`);
  lines.push('Aim is fixed to ground. New statuses affect next planning; incoming enemy plans remain hidden.');
  return lines;
}

/** Own sealed trajectories only; this never reads another team's hidden orders. */
export function plannedProjectileClashes(state:SimState,plan:TeamPlan):ProjectileClash[] {
  const projectiles:Projectile[]=plan.orders.flatMap(order=>{
    if(!order.cast||!order.spellId)return [];
    const unit=state.units.find(unit=>unit.id===order.unitId);if(!unit||!isAlive(unit))return [];
    const spell=profileSpell(effectiveSpell(unit.championId,order.spellId,unit.affinities),state.spellModel),from=order.move??unit;
    const friendlyTarget=state.units.some(ally=>isAlive(ally)&&areAllies(state,ally.owner,unit.owner)&&same(plan.orders.find(planned=>planned.unitId===ally.id)?.move??ally,order.cast!));
    return isTravellingProjectile(spell,from,order.cast,friendlyTarget)?[{unitId:unit.id,from:point(from),to:order.cast,element:spell.element}]:[];
  });
  return findProjectileClashes(projectiles,state.cells);
}

/** A bounded positional estimate, using the same exact field descriptor as combat. */
function fieldValue(cell:SimCell,unit:SimUnit,origin:Point=unit,previous?:SimCell,includeHealing=true):number {
  const effects=fieldEffects(cell);
  let score=(includeHealing?effectiveHealing(unit,effects.heal??0,Boolean(effects.cleanse))*2:0)+(effects.flux??0)*.7+(effects.cover??0)*.6;
  if(effects.damageScale)score+=.6;
  if(effects.cleanse)score+=AILMENTS.filter(id=>unit.statuses[id]).length*1.5;
  if(effects.movement==='current')score+=.3;
  if(effects.movement==='rough'||effects.movement==='flood')score-=.3;
  if(cell.well)score+=Math.min(unit.maxFlux-unit.flux,effects.wellBonus??0)*.6;
  for(const status of effects.statuses??[]){
    if(CONTROL.includes(status.id)&&!unit.statuses.resolve&&!unit.statuses.clarity&&!effects.cleanse)score-=1.4;
    if(status.id==='burn'&&!unit.statuses.wet&&!effects.cleanse)score-=1.5;
    if(status.id==='wither'&&!effects.cleanse)score-=.4;
    if(status.id==='ward')score+=(status.power??1)*.5;
    if(status.id==='wet'&&unit.statuses.burn&&!unit.statuses.wet)score+=1.5;
    if(status.id==='haste'||status.id==='clarity'||status.id==='anchored')score+=.4;
  }
  const hazard=effects.hazard==='always'||effects.hazard==='moved'&&!same(origin,cell)||effects.hazard==='formed'&&fieldCombination(previous??cell)?.id!==fieldCombination(cell)?.id;
  if(hazard)score-=unit.hp<=1?100:3;
  return score;
}
/** Bounded public-state bot. It never receives the opponent's sealed plan. */
export function chooseAIPlan(state: SimState, player: Player): TeamPlan {
  if (state.rulesVersion !== RULES_VERSION || state.winner !== null) return { orders: [] };
  const original=state;
  const joint=state.spellModel===CURRENT_SPELL_MODEL,landingScores=new Map<string,ScoredLanding<SimCell>[]>();
  const geometry=planningGeometry(state.cells,state.units,(unit,id)=>profileSpell(effectiveSpell(unit.championId,id,unit.affinities),state.spellModel),(id,spell,target,from)=>spellArea(state,id,spell,target,from),(id,spell,from)=>legalCasts(state,id,from,spell));
  const aiSpell=geometry.spell;
  const aiClashes=(plan:TeamPlan):ProjectileClash[]=>{
    if(!joint)return plannedProjectileClashes(state,plan);
    const projectiles:Projectile[]=plan.orders.flatMap(order=>{
      if(!order.cast||!order.spellId)return [];const actor=state.units.find(unit=>unit.id===order.unitId);if(!actor||!isAlive(actor))return [];
      const spell=aiSpell(actor,order.spellId),from=order.move??actor;
      const friendlyTarget=state.units.some(ally=>isAlive(ally)&&areAllies(state,ally.owner,actor.owner)&&same(plan.orders.find(planned=>planned.unitId===ally.id)?.move??ally,order.cast!));
      return isTravellingProjectile(spell,from,order.cast,friendlyTarget)?[{unitId:actor.id,from:point(from),to:order.cast,element:spell.element,elements:[spell.element]}]:[];
    });return findProjectileClashes(projectiles,state.cells);
  };
  const aiArea=(id:string,spell:string,target:Point,from?:Point)=>joint?geometry.area(id,spell,target,from):spellArea(state,id,spell,target,from);
  const aiAims=(id:string,from?:Point,spell?:string)=>joint?geometry.aims(id,spell??state.units.find(unit=>unit.id===id)!.loadout[0],from):legalCasts(state,id,from,spell);
  const sightCells=new Map(state.cells.map(cell=>[key(cell),cell])),sightCache=new Map<string,boolean>();
  const aiSight=(from:SimCell,target:SimCell)=>{const id=key(from)+':'+key(target);let result=sightCache.get(id);if(result===undefined){result=clearSight(state,from,target,sightCells);sightCache.set(id,result);}return result;};
  const own = sortedUnits(state.units.filter((unit) => unit.owner === player && isAlive(unit))); const enemies = sortedUnits(state.units.filter((unit) => !areAllies(state,unit.owner,player) && isAlive(unit)));
  if(!own.length||!enemies.length)return {orders:[]};
  const publicDamageThreats=joint?enemies.flatMap(enemy=>availableSpellIds(enemy.championId,enemy.loadout,enemy.affinities,state.learnedSignatures[enemy.owner]).filter(id=>castAvailability(state,enemy.id,id).available).map(id=>({enemy,spell:aiSpell(enemy,id)})).filter(entry=>entry.spell.damage>0)):[];
  const publicPulses=inhabitantPulses(state);
  const forecast=new Map(state.cells.map(cell=>[key(cell),previewField(cell,publicPulses.filter(pulse=>pulse.area.some(point=>same(point,cell))).flatMap(pulse=>pulse.elements))]));
  // Reachability is public information, not a prediction of the sealed enemy plan.
  const contested = new Set(enemies.flatMap((enemy) => legalMoves(state, enemy.id).map(key)));
  const sign = 1; const reserved = new Set<string>(); const orders: Order[] = [];
  const alliedOtherSeats=state.units.filter(unit=>unit.owner!==player&&areAllies(state,unit.owner,player)&&isAlive(unit));
  // Engage living opponents. Springs can improve a useful combat position, but
  // occupying one is never a reason to stop pursuing the elimination objective.
  // A revealed failed move is evidence, not a prediction of sealed orders. Approach from a different hex
  // for one round rather than repeating a collision that leaves both casters outside their useful reach.
  const firstCast = state.lastResolution.findIndex((event) => event.kind === 'cast');
  const movementEvents = state.lastResolution.slice(0, firstCast < 0 ? state.lastResolution.length : firstCast);
  const zone=endgameForecast(state);
  const recentContests=new Set(movementEvents.filter(event=>event.kind==='bounce'&&event.to&&movementEvents.filter(other=>other.kind==='bounce'&&other.to&&same(other.to,event.to!)).length>1).map(event=>key(event.to!)));
  const retryPriority=(unit:SimUnit)=>{let hash=2166136261;for(const character of `${state.mapId}:${state.round}:${unit.id}`){hash^=character.charCodeAt(0);hash=Math.imul(hash,16777619)>>>0;}return hash;};
  const retryContenders=new Map<string,string>();
  if(zone.phase==='closing')for(const contestedKey of recentContests){
    const cell=state.cells.find(cell=>key(cell)===contestedKey)!;
    const contenders=state.units.filter(unit=>isAlive(unit)&&legalMoves(state,unit.id).some(landing=>same(landing,cell))).sort((a,b)=>retryPriority(a)-retryPriority(b)||a.id.localeCompare(b.id));
    if(contenders[0])retryContenders.set(contestedKey,contenders[0].id);
  }
  // Allied seats can agree on one centre contender using only public positions.
  // Their sealed plans remain private; the same choice is computed independently.
  const centreContender=state.mode==='teams'&&zone.nextSafeRadius===0&&zone.phase!=='calm'?state.units.filter(unit=>isAlive(unit)&&areAllies(state,unit.owner,player)&&(same(unit,zone.centre)||legalMoves(state,unit.id).some(cell=>same(cell,zone.centre)))).sort((a,b)=>Number(same(b,zone.centre))-Number(same(a,zone.centre))||b.hp-a.hp||distance(a,zone.centre)-distance(b,zone.centre)||a.id.localeCompare(b.id))[0]?.id:undefined;
  for (const unit of own) {
    const bouncedLanding = movementEvents.find((event) => event.kind === 'bounce' && event.unitId === unit.id && event.to && !occupant(state, event.to))?.to;
    const attacks=availableSpellIds(unit.championId,unit.loadout,unit.affinities,state.learnedSignatures[player]).filter(id=>castAvailability(state,unit.id,id).available).map(id=>aiSpell(unit,id)).filter(spell=>spell.damage>0||spell.push||spell.harmful?.length);
    const desiredRange=attacks.length?Math.max(1,Math.min(3,Math.max(...attacks.map(spell=>spell.range)))):2;
    const candidates = [getCell(state, unit.q, unit.r)!, ...legalMoves(state, unit.id)].sort((a, b) => sign * (a.q - b.q || a.r - b.r)); let landing = candidates[0]; let best = -Infinity;
    const supportSpells=joint?availableSpellIds(unit.championId,unit.loadout,unit.affinities,state.learnedSignatures[player]).filter(id=>castAvailability(state,unit.id,id).available).map(id=>aiSpell(unit,id)).filter(spell=>spell.heal>0):[];
    const scored:ScoredLanding<SimCell>[]=[];landingScores.set(unit.id,scored);
    for (const cell of candidates) {
      if (reserved.has(key(cell)) || enemies.some((enemy) => same(enemy, cell)) || alliedOtherSeats.some(ally=>same(ally,cell))) continue;
      if(centreContender&&unit.id!==centreContender&&same(cell,zone.centre))continue;
      const nearest=Math.min(...enemies.map(enemy=>distance(cell,enemy)));
      const targets=enemies.filter(enemy=>attacks.some(spell=>{
        const target=getCell(state,enemy.q,enemy.r)!;
        return spell.range>0&&distance(cell,target)<=resolvedSpellRange(unit,spell,cell,target)&&((spell.shape!=='sweep'&&spell.shape!=='wall')||aimDirection(cell,target)>=0)&&aiSight(cell,target);
      }));
      const pressure=targets.length?8+Math.max(...targets.map(enemy=>(enemy.maxHp-enemy.hp)*.35)):0;
      // Focused areas need a clean firing position: range alone may leave the
      // caster inside its own burst. Reward a legal centre aim without guessing
      // rival movement, and keep this bounded below urgent endgame safety.
      const cleanCentre=isFocusedSpellModel(state.spellModel)&&targets.some(enemy=>attacks.some(spell=>{
        if(focusZone(spell,enemy,enemy)!=='centre'||!threatensAlly(spell))return false;
        const target=getCell(state,enemy.q,enemy.r)!;
        if(distance(cell,target)>resolvedSpellRange(unit,spell,cell,target)||!aiSight(cell,target))return false;
        const area=aiArea(unit.id,spell.id,target,cell);
        return !state.units.filter(ally=>isAlive(ally)&&areAllies(state,ally.owner,player)).some(ally=>{
          const landing=ally.id===unit.id?cell:orders.find(order=>order.unitId===ally.id)?.move??ally;
          return area.some(point=>same(point,landing));
        });
      }))?2:0;
      const proximity=nearest>desiredRange?-(nearest-desiredRange)*2.2:-(desiredRange-nearest)*.4;
      const spring=cell.well?Math.min(unit.maxFlux-unit.flux,1+(fieldEffects(forecast.get(key(cell))!).wellBonus??0))*.6:0;
      let retryPenalty=bouncedLanding&&same(cell,bouncedLanding)?20:0;
      if(zone.phase==='closing'&&collapseDamageAt(state,unit)===0&&recentContests.has(key(cell))){
        // A revealed collision should not synchronize identical retries forever.
        // One public, seed/round-varying contender retries; the others can flank
        // or attack. This is bot preference, never a movement-rule privilege.
        retryPenalty=retryContenders.get(key(cell))===unit.id?0:72;
      }
      const score=endgamePositionValue(state,cell,unit.hp)+pressure+cleanCentre+proximity+spring+cell.height*.5+fieldValue(forecast.get(key(cell))!,unit,unit,cell)+(same(unit,cell) ? .25 : 0)
        - (!same(unit, cell) && contested.has(key(cell)) ? 1.5 : 0) - retryPenalty;
      if(joint){
        const support=Math.max(0,...state.units.filter(ally=>isAlive(ally)&&areAllies(state,ally.owner,player)&&ally.hp<ally.maxHp).flatMap(ally=>supportSpells.map(spell=>distance(cell,ally)<=spell.range+spell.radius?Math.min(ally.maxHp-ally.hp,spellAtCell(spell,{q:0,r:0},{q:Math.max(0,distance(cell,ally)-spell.range),r:0}).heal)*3:0)));
        scored.push({cell,score,support});
      }
      if (score > best) { best = score; landing = cell; }
    }
    reserved.add(key(landing)); orders.push({ unitId: unit.id, ...(same(unit, landing) ? {} : { move: point(landing) }), guard: true });
  }
  const projected = structuredClone(state); destinations(projected, new Map(orders.filter((order) => order.move).map((order) => [order.unitId, order.move!])), 'move');
  for (const order of orders) if (order.move && !same(projected.units.find((unit) => unit.id === order.unitId)!, order.move)) delete order.move;
  let landings = sortedUnits(state.units.filter(unit=>isAlive(unit)&&areAllies(state,unit.owner,player))).map((unit) => ({ ...unit, ...(orders.find((order) => order.unitId === unit.id)?.move ?? point(unit)) }));
  let possibleAllies = [...landings, ...own.filter((unit) => { const landing = landings.find((entry) => entry.id === unit.id)!; return !same(unit, landing) && contested.has(key(landing)); })];
  for (const order of orders) {
    const unit = own.find((entry) => entry.id === order.unitId)!; let best = 0; let choice: { spell: Spell; target: Point; move?:Point } | undefined;
    const initialMove=order.move,baseline=initialMove??point(unit),scored=landingScores.get(unit.id)??[];
    const blocked=new Set([...orders.filter(other=>other.unitId!==unit.id).map(other=>key(other.move??own.find(ally=>ally.id===other.unitId)!)),...alliedOtherSeats.map(key)]);
    const positions=joint?jointLandings(scored,baseline,unit,blocked,own.length):[];
    const baselineScore=scored.find(candidate=>same(candidate.cell,baseline))?.score??0;
    for(const candidate of positions.length?positions:[{cell:getCell(state,baseline.q,baseline.r)!,score:baselineScore,support:0}]){
      if(joint&&collapseDamageAt(state,candidate.cell)>=unit.hp&&collapseDamageAt(state,baseline)<unit.hp)continue;
      if(joint&&orders.some(other=>other.unitId!==unit.id&&other.spellId&&other.cast&&threatensAlly(aiSpell(own.find(ally=>ally.id===other.unitId)!,other.spellId))&&aiArea(other.unitId,other.spellId,other.cast,other.move).some(cell=>same(cell,candidate.cell))))continue;
      if(same(candidate.cell,unit))delete order.move;else order.move=point(candidate.cell);
      landings = sortedUnits(state.units.filter(actor=>isAlive(actor)&&areAllies(state,actor.owner,player))).map(actor=>({...actor,...(orders.find(other=>other.unitId===actor.id)?.move??point(actor))}));
      possibleAllies=[...landings,...own.filter(actor=>{const landing=landings.find(other=>other.id===actor.id)!;return !same(actor,landing)&&contested.has(key(landing));})];
      const movementAdjustment=joint?Math.min(0,(candidate.score-baselineScore)*.2):0;
    const priorCasts=orders.filter(other=>other.unitId!==unit.id&&other.cast&&other.spellId).map(other=>{
      const caster=own.find(ally=>ally.id===other.unitId)!,spell=aiSpell(caster,other.spellId!);
      return {spell,origin:other.move??caster,target:other.cast!,element:spell.element,freeze:spell.freeze,area:aiArea(other.unitId,other.spellId!,other.cast!,other.move)};
    });
    const pendingPulses=publicPulses.filter(pulse=>!priorCasts.some(cast=>cast.element===pulse.counterElement&&cast.area.some(cell=>same(cell,pulse.anchor))));
    const priorFields=new Map<typeof pendingPulses,Map<string,SimCell>>();
    const priorField=(point:Point,pulses= pendingPulses)=>{
      let fields=priorFields.get(pulses);if(!fields){fields=new Map();priorFields.set(pulses,fields);}const cached=fields.get(key(point));if(cached)return cached;
      const arrivals=priorCasts.filter(cast=>cast.area.some(cell=>same(cell,point)));
      const result=previewField(getCell(state,point.q,point.r)!,[...pulses.filter(pulse=>pulse.area.some(cell=>same(cell,point))).flatMap(pulse=>pulse.elements),...arrivals.map(cast=>cast.element)],arrivals.some(cast=>cast.freeze));fields.set(key(point),result);return result;
    };
    for (const spellId of availableSpellIds(unit.championId, unit.loadout,unit.affinities,state.learnedSignatures[player])) {
      const availability = castAvailability(state, unit.id, spellId); if (!availability.available) continue;
      const spell = aiSpell(unit,spellId);
      const fallback = order.move && contested.has(key(order.move)) ? new Set(aiAims( unit.id, undefined, spellId).map(key)) : null;
      for (const target of aiAims( unit.id, order.move, spellId).sort((a, b) => sign * (a.q - b.q || a.r - b.r))) {
        if (fallback && !fallback.has(key(target))) continue;
        // Do not value a coordinated direct hit that our own projectile would consume.
        // Enemy interception remains uncertain; only our public draft participates here.
        if(aiClashes({orders:[...orders.filter(other=>other.unitId!==unit.id),{...order,spellId,cast:target}]}).some(clash=>clash.participants.includes(unit.id)))continue;
        const area = aiArea( unit.id, spellId, target, order.move); let score = movementAdjustment-availability.cost * 0.35 - (spell.selfDamage ?? 0) * 2;
        let drainPotential=0;
        if(joint&&spell.wall)score+=barrierRouteValue(state.cells,area,landings,enemies);
        if (threatensAlly(spell) && possibleAllies.some((ally) => area.some((cell) => same(cell, ally)))) continue;
        if (fallback && threatensAlly(spell) && possibleAllies.some((ally) => aiArea( unit.id, spellId, target).some((cell) => same(cell, ally)))) continue;
        const countered=pendingPulses.filter(pulse=>pulse.counterElement===spell.element&&area.some(cell=>same(cell,pulse.anchor)));
        const survivingPulses=countered.length?pendingPulses.filter(pulse=>!countered.includes(pulse)):pendingPulses;
        const resultAt=(point:Point)=>{
          const base=priorField(point,survivingPulses);
          return previewField(base,[...priorCasts.filter(cast=>cast.area.some(cell=>same(cell,point))).map(cast=>cast.element),spell.element],spell.freeze);
        };
        if(countered.length){
          // Score a release once, only where interrupting it protects a planned
          // ally. Inside the spell area the ordinary field score below already
          // includes the full transformation, so do not reward it twice here.
          const outside=landings.filter(ally=>!area.some(cell=>same(cell,ally)));
          const delta=(occupant:SimUnit,origin:Point)=>{
            const previous=getCell(state,occupant.q,occupant.r)!;
            return fieldValue(priorField(occupant,survivingPulses),occupant,origin,previous)-fieldValue(priorField(occupant),occupant,origin,previous);
          };
          const ownChanges=outside.map(ally=>delta(ally,state.units.find(original=>original.id===ally.id)!));
          if(ownChanges.some(change=>change>0)){
            const enemyBenefit=enemies.filter(enemy=>!area.some(cell=>same(cell,enemy))).reduce((sum,enemy)=>sum+delta(enemy,enemy),0);
            score+=Math.max(-12,Math.min(12,ownChanges.reduce((sum,change)=>sum+change,0)-enemyBenefit*.75));
          }
        }
        for (const enemy of enemies.filter((entry) => area.some((cell) => same(cell, entry)))) {
          const targetSpell=spellAtCell(spell,target,enemy);
          // Follow up an already-visible mark. A mark another mage plans this round
          // is not in this snapshot and cannot enable a simultaneous bonus.
          const field=resultAt(enemy),prior=priorCasts.filter(cast=>cast.area.some(cell=>same(cell,enemy))),earlier=prior.map(cast=>spellAtCell(cast.spell,cast.target,enemy));
          // Evaluate marginal coordinated damage with the resolver's aggregate
          // mitigation. Guard is a conservative scenario, not a revealed order.
          const beforeDamage=volleyDamage(priorField(enemy),enemy,earlier,true),afterDamage=volleyDamage(field,enemy,[...earlier,targetSpell],true);
          const damage=afterDamage-beforeDamage;
          if(joint&&afterDamage>0)drainPotential+=spell.drain??0;
          score += damage * 3 + (beforeDamage<enemy.hp&&afterDamage>=enemy.hp ? 5 : 0) + harmfulStatusValue(enemy,targetSpell,fieldEffects(field),earlier) + availableTheft(enemy,spell.steal??0,earlier);
          if(spell.push&&!enemy.statuses.anchored){
            const beforeForce=prior.reduce((sum,cast)=>addForce(sum,spellForce(enemy,cast.origin,cast.spell,cast.target)),{q:0,r:0});
            const afterForce=addForce(beforeForce,spellForce(enemy,order.move??unit,spell,target));
            // A caster may choose to cast instead of Guard. Give both public
            // possibilities bounded weight; no old Guard flag predicts this turn.
            if(getCell(state,enemy.q,enemy.r)?.well)score+=displacementSteps(afterForce)-displacementSteps(beforeForce)
              +2*(displacementSteps(afterForce,true)-displacementSteps(beforeForce,true));
            const impactValue=(force:Point,guard:boolean)=>{
              const route=previewDisplacement(state,enemy.id,force,guard);
              if(!route.impact||route.path.some(cell=>state.units.some(other=>other.id!==enemy.id&&isAlive(other)&&same(other,cell))))return 0;
              return 3+harmfulStatusValue(enemy,{...spell,harmful:[{id:'concussed',turns:1,power:1}]},fieldEffects(field),earlier);
            };
            score+=(impactValue(afterForce,true)-impactValue(beforeForce,true))*.7+(impactValue(afterForce,false)-impactValue(beforeForce,false))*.3;
            const collapseDelta=(force:Point,guard:boolean)=>collapseDamageAt(state,previewDisplacement(state,enemy.id,force,guard).landing);
            score+=3*((collapseDelta(afterForce,true)-collapseDelta(beforeForce,true))*.7+(collapseDelta(afterForce,false)-collapseDelta(beforeForce,false))*.3);
          }
          score-=fieldValue(field,enemy,enemy,getCell(state,enemy.q,enemy.r)!)-fieldValue(priorField(enemy),enemy);
        }
        if(joint&&drainPotential)score+=effectiveHealing(unit,drainPotential)*3;
        for (const ally of landings.filter((entry) => area.some((cell) => same(cell, entry)))) {
          const targetSpell=spellAtCell(spell,target,ally);
          const earlier=priorCasts.filter(cast=>cast.area.some(cell=>same(cell,ally))).map(cast=>spellAtCell(cast.spell,cast.target,ally));
          const prior=priorField(ally),field=resultAt(ally),beforeEffects=fieldEffects(prior),afterEffects=fieldEffects(field);
          const existingHeal=earlier.reduce((sum,cast)=>sum+cast.heal,0),alreadyCleansed=earlier.some(cast=>cast.cleanse);
          score += (effectiveHealing(ally,existingHeal+targetSpell.heal+(afterEffects.heal??0),Boolean(alreadyCleansed||targetSpell.cleanse||afterEffects.cleanse))
            -effectiveHealing(ally,existingHeal+(beforeEffects.heal??0),Boolean(alreadyCleansed||beforeEffects.cleanse)))*3;
          if (targetSpell.cleanse) score += AILMENTS.filter((id) => ally.statuses[id]).length * 2;
          if(joint&&targetSpell.recharge){
            const queued=orders.find(other=>other.unitId===ally.id),cost=queued?.spellId?castAvailability(state,ally.id,queued.spellId).cost:ally.id===unit.id?availability.cost:0;
            const priorFlux=earlier.reduce((sum,cast)=>sum+(cast.recharge??0),0),capacity=Math.max(0,ally.maxFlux-ally.flux+cost-2-priorFlux);
            score+=Math.min(capacity,targetSpell.recharge)*1.1;
          }
          if (enemies.some((enemy) => distance(enemy, ally) <= 3)) score += joint?friendlyStatusValue(ally,targetSpell,afterEffects,earlier,publicDamageThreats.some(({enemy,spell})=>distance(enemy,ally)<=spell.range+spell.radius+1)):targetSpell.friendly?.reduce((sum, effect) => sum + (effect.id === 'ward' ? effect.power ?? 1 : 0.5), 0) ?? 0;
          score+=fieldValue(field,ally,state.units.find(original=>original.id===ally.id)!,getCell(state,ally.q,ally.r)!,false)-fieldValue(prior,ally,ally,undefined,false);
        }
        if (score > best) { best = score; choice = { spell, target, move:order.move }; }
      }
    }
    }
    if(initialMove)order.move=initialMove;else delete order.move;
    if (choice) { if(choice.move)order.move=choice.move;else delete order.move;delete order.guard; order.spellId = choice.spell.id; order.cast = point(choice.target); }
  }
  return validatePlan(original, player, { orders });
}

export function restoreSimState(input: unknown): SimState {
  const value = object(input, ['rulesVersion','spellModel','projectileModel', 'version', 'mapId', 'playerCount','mode','teams','boardRadius','round', 'scores', 'learnedSignatures', 'units', 'cells', 'inhabitants', 'log', 'winner', 'lastResolution'], 'Saved match');
  if(value.spellModel!==undefined&&!isFocusedSpellModel(value.spellModel))throw new Error('Unknown spell area rules.');
  if(value.projectileModel!==undefined&&value.projectileModel!=='volume')throw new Error('Unknown projectile rules.');
  const playerCount=validatePlayerCount(value.playerCount),teams=seatTeams(playerCount,value.mode as MatchMode);
  if(JSON.stringify(value.teams)!==JSON.stringify(teams)||typeof value.mapId!=='string'||arenaPlayerCount(value.mapId)!==playerCount||value.boardRadius!==arenaRadius(value.mapId))throw new Error('Saved arena configuration changed.');
  if(!Array.isArray(value.learnedSignatures)||value.learnedSignatures.length!==playerCount||value.learnedSignatures.some(library=>!Array.isArray(library)||library.length))throw new Error('Arena libraries must be empty.');
  const learnedSignatures=Array.from({length:playerCount},()=>[] as string[]),boardSize=arenaSize(value.mapId),boardRadius=arenaRadius(value.mapId);
  if (value.rulesVersion !== RULES_VERSION || typeof value.mapId !== 'string' || value.mapId !== normalizeArenaMapId(value.mapId) || !Number.isSafeInteger(value.round) || (value.round as number) < 1 || (value.round as number) > MAX_ROUNDS || ![null,...teams,'draw'].includes(value.winner as never)) throw new Error('Unsupported tactics save.');
  const finalRound=endgameForecast({playerCount,boardRadius,round:1}).finalRound;
  if((value.round as number)>finalRound)throw new Error('Saved match exceeds its collapse schedule.');
  if (value.version !== (value.round as number) + Number(value.winner !== null)) throw new Error('Saved version and round disagree.');
  if (!Array.isArray(value.scores) || value.scores.length !== playerCount || value.scores.some(score=>score!==0)) throw new Error('Elimination battles do not have scores.');
  if (!Array.isArray(value.cells) || value.cells.length !== boardSize || !Array.isArray(value.units) || value.units.length !== playerCount*3) throw new Error('Invalid battlefield size.');
  const cells = value.cells.map((raw): SimCell => {
    const cell = object(raw, ['q', 'r', 'well', 'terrain', 'biome', 'height', 'ttl', 'elements', 'reactions', 'barrier', 'ice'], 'Saved hex'); const at = readPoint({ q: cell.q, r: cell.r });
    if (distance(at, { q: 0, r: 0 }) > boardRadius || cell.biome !== arenaBiomeAt(at.q, at.r, value.mapId as string) || cell.height !== heightAt(at.q, at.r, value.mapId as string) || cell.well !== wellAt(at.q, at.r, value.mapId as string)) throw new Error('Saved geometry changed.');
    if (cell.barrier !== undefined && (!Number.isInteger(cell.barrier) || (cell.barrier as number) < 1 || (cell.barrier as number) > 2 || cell.well || cell.biome === 'ruins')) throw new Error('Invalid barrier.');
    if (cell.ttl === undefined) { if (cell.terrain !== baseTerrainAt(at.q, at.r, value.mapId as string) || cell.elements !== undefined || cell.reactions !== undefined || cell.ice !== undefined) throw new Error('Base terrain changed.'); }
    else {
      if (!Number.isInteger(cell.ttl) || (cell.ttl as number) < 1 || (cell.ttl as number) > 2 || !Array.isArray(cell.elements) || !cell.elements.length || new Set(cell.elements).size !== cell.elements.length || cell.elements.some((element) => !ELEMENT_ORDER.includes(element)) || !Array.isArray(cell.reactions)) throw new Error('Invalid chemistry.');
      if (JSON.stringify(cell.elements) !== JSON.stringify(ELEMENT_ORDER.filter((element) => (cell.elements as Element[]).includes(element))) || JSON.stringify(cell.reactions) !== JSON.stringify(reactionsFor(cell.elements as Element[])) || cell.terrain !== (cell.reactions[0] ?? cell.elements[0])) throw new Error('Inconsistent chemistry.');
      const base = baseTerrainAt(at.q, at.r, value.mapId as string);
      if (base !== 'plain' && !(cell.elements as Element[]).includes(base)) throw new Error('Field is missing its natural substrate.');
      const combination=combinationFor(cell.elements as Element[])!;
      if(cell.ice!==undefined&&(cell.ice!==true||combination.id!=='water'&&combination.mechanics.movement!=='ice'))throw new Error('Invalid ice.');
      if(combination.mechanics.movement==='ice'&&cell.ice!==true)throw new Error('Frozen field is missing its ice.');
      if(combination.mechanics.consume)throw new Error('An ephemeral field cannot survive an exchange.');
    }
    return { ...cell } as SimCell;
  });
  if (new Set(cells.map(key)).size !== boardSize) throw new Error('Duplicate board hex.');
  const inhabitants=value.inhabitants===undefined?undefined:validateInhabitants(value.inhabitants,value.mapId as string,value.round as number,cells);
  const units = value.units.map((raw): SimUnit => {
    const unit = object(raw, ['id', 'championId', 'displayName','owner', 'q', 'r', 'hp', 'maxHp', 'guard', 'respawn', 'loadout', 'affinities', 'flux', 'maxFlux', 'cooldowns', 'statuses'], 'Saved champion');
    if ((!Number.isInteger(unit.owner)||Number(unit.owner)<0||Number(unit.owner)>=playerCount) || typeof unit.championId !== 'string' || !CHAMPIONS.some((entry) => entry.id === unit.championId) || unit.id !== `${unit.owner}-${unit.championId}`) throw new Error('Invalid champion identity.');
    const at = readPoint({ q: unit.q, r: unit.r });
    if (!cells.some((cell) => same(cell, at)) || unit.maxHp !== MAX_HP || !Number.isInteger(unit.hp) || (unit.hp as number) < 0 || (unit.hp as number) > MAX_HP || unit.maxFlux !== MAX_FLUX || !Number.isInteger(unit.flux) || (unit.flux as number) < 0 || (unit.flux as number) > MAX_FLUX || (unit.guard !== undefined && typeof unit.guard !== 'boolean')) throw new Error('Invalid champion condition.');
    if (unit.respawn !== undefined) throw new Error('Defeated characters do not return in elimination battles.');
    const build=validateCharacterBuild({championId:unit.championId,name:unit.displayName??getChampion(unit.championId).name,affinities:unit.affinities,loadout:unit.loadout});
    const {affinities,loadout}=build;
    if(unit.displayName!==undefined&&unit.displayName!==build.name)throw new Error('Saved character name is not normalized.');
    const ownedSpells=ALL_SPELLS.filter(spell=>spellAccess(unit.championId as string,spell.id,affinities,learnedSignatures[unit.owner as Player]).unlocked).map(spell=>spell.id);
    const cooldowns = object(unit.cooldowns, ownedSpells, 'Cooldowns');
    for (const [id, remaining] of Object.entries(cooldowns)) if (!Number.isInteger(remaining) || (remaining as number) < 1 || (remaining as number) > getSpell(id).cooldown) throw new Error('Invalid spell cooldown.');
    const statuses = object(unit.statuses, STATUS_DEFINITIONS.map((status) => status.id), 'Statuses');
    for (const [id,rawStatus] of Object.entries(statuses)) { const status = object(rawStatus, ['turns', 'power'], 'Status'); const maxTurns=CONTROL.includes(id as StatusId)?1:['resolve','burn','ward'].includes(id)?2:3,maxPower=id==='ward'?5:1; if (!Number.isInteger(status.turns) || (status.turns as number) < 1 || (status.turns as number) > maxTurns || !Number.isInteger(status.power) || (status.power as number) < 1 || (status.power as number) > maxPower) throw new Error('Invalid status duration or power.'); }
    if(unit.hp===0&&(unit.flux!==0||unit.guard!==undefined||Object.keys(statuses).length||Object.keys(cooldowns).length))throw new Error('Defeated champion condition is inconsistent.');
    return { ...unit, affinities,loadout } as SimUnit;
  });
  const expectedWinner=eliminationWinner(units,value.winner===null?(value.round as number)-1:value.round as number,teams);
  if(value.winner!==expectedWinner)throw new Error('Saved elimination victory is inconsistent.');
  const living = units.filter(isAlive);
  if (new Set(units.map((unit) => unit.id)).size !== playerCount*3 || Array.from({length:playerCount},(_,seat)=>seat).some((owner) => units.filter((unit) => unit.owner === owner).length !== 3) || new Set(living.map(key)).size !== living.length || living.some((unit) => isCellSolid(cells.find((cell) => same(cell, unit))!))) throw new Error('Invalid squads or overlapping occupants.');
  if (!Array.isArray(value.log) || value.log.length > 150 || value.log.some((line) => typeof line !== 'string' || line.length > 1000) || !Array.isArray(value.lastResolution) || value.lastResolution.length > 1800) throw new Error('Invalid event history.');
  for (const raw of value.lastResolution) {
    const entry = object(raw, ['kind', 'breakdown', 'critical', 'text', 'unitId', 'owner', 'from', 'to', 'q', 'r', 'amount', 'elements', 'terrain', 'spellId', 'status', 'speciesId', 'interrupted','participants','meeting','flightFraction','radius','cause'], 'Event');
    if (!['move', 'bounce', 'cast', 'clash', 'reaction', 'damage', 'heal', 'push', 'defeat', 'respawn', 'score', 'guard', 'fizzle', 'surface', 'inhabitant'].includes(entry.kind as string) || typeof entry.text !== 'string' || entry.text.length > 1000) throw new Error('Invalid event.');
    if(entry.kind==='score'||entry.kind==='respawn')throw new Error('Unsupported elimination event.');
    if(entry.breakdown!==undefined&&value.spellModel!==CURRENT_SPELL_MODEL)throw new Error('Combat explanation requires current rules.');
    validateCombatBreakdown(entry.breakdown,entry as {kind:unknown;amount?:unknown},new Set(units.map(unit=>unit.id)),new Set(ALL_SPELLS.map(spell=>spell.id)));
    if (entry.owner !== undefined && (!Number.isInteger(entry.owner)||Number(entry.owner)<0||Number(entry.owner)>=playerCount)) throw new Error('Invalid event owner.');
    if (entry.unitId !== undefined && !units.some((unit) => unit.id === entry.unitId)) throw new Error('Invalid event champion.');
    if (entry.unitId !== undefined && entry.owner !== undefined && !units.some(unit=>unit.id===entry.unitId&&unit.owner===entry.owner)) throw new Error('Event champion and owner disagree.');
    for (const field of ['from', 'to']) if (entry[field] !== undefined && !cells.some((cell) => same(cell, readPoint(entry[field])))) throw new Error('Invalid event hex.');
    if ((entry.q !== undefined || entry.r !== undefined) && !cells.some((cell) => same(cell, readPoint({ q: entry.q, r: entry.r })))) throw new Error('Invalid event coordinate.');
    if(entry.critical!==undefined&&(entry.critical!==true||!isFocusedSpellModel(value.spellModel)||!['damage','heal'].includes(entry.kind as string)||!Number.isInteger(entry.amount)||Number(entry.amount)<=0))throw new Error('Invalid centre critical event.');
    if (entry.amount !== undefined && (!Number.isInteger(entry.amount) || (entry.amount as number) < 0 || (entry.amount as number) > 100)) throw new Error('Invalid event amount.');
    if(entry.cause!==undefined){
      const resolvedRound=value.winner===null?(value.round as number)-1:value.round as number;
      if(entry.cause!=='collapse'||entry.kind!=='damage'||resolvedRound<1||typeof entry.unitId!=='string'||entry.owner===undefined||entry.q===undefined||entry.r===undefined||['from','to','spellId','status','elements','terrain'].some(field=>entry[field]!==undefined))throw new Error('Invalid collapse event.');
      const unit=units.find(unit=>unit.id===entry.unitId)!;
      const expected=collapseDamageAt({playerCount,boardRadius,round:resolvedRound},unit);
      if(!expected||entry.amount!==expected||entry.q!==unit.q||entry.r!==unit.r)throw new Error('Collapse event disagrees with the resolved boundary.');
    }

    if (entry.spellId !== undefined && (typeof entry.spellId !== 'string' || !ALL_SPELLS.some((spell) => spell.id === entry.spellId))) throw new Error('Invalid event spell.');
    if(entry.speciesId!==undefined&&(!inhabitants?.some(inhabitant=>inhabitant.speciesId===entry.speciesId)||entry.kind!=='inhabitant'))throw new Error('Invalid event inhabitant.');
    if(entry.kind==='inhabitant'&&(typeof entry.speciesId!=='string'||!inhabitants?.some(inhabitant=>inhabitant.speciesId===entry.speciesId)))throw new Error('Missing event inhabitant.');
    if(entry.interrupted!==undefined&&(entry.kind!=='inhabitant'||typeof entry.interrupted!=='boolean'))throw new Error('Invalid inhabitant interruption.');
    if(entry.kind==='inhabitant'&&typeof entry.interrupted!=='boolean')throw new Error('Missing inhabitant interruption.');
    if(entry.kind==='inhabitant'){
      const inhabitant=inhabitants!.find(inhabitant=>inhabitant.speciesId===entry.speciesId)!,species=getInhabitantSpecies(inhabitant.speciesId);
      if(entry.q!==inhabitant.q||entry.r!==inhabitant.r||entry.terrain!==combinationFor(species.elements)!.id||JSON.stringify(entry.elements)!==JSON.stringify(species.elements)||entry.unitId!==undefined||entry.owner!==undefined||entry.spellId!==undefined)throw new Error('Inconsistent inhabitant event.');
    }
    if (entry.status !== undefined && !STATUS_DEFINITIONS.some((status) => status.id === entry.status)) throw new Error('Invalid event status.');
    if (entry.elements !== undefined && (!Array.isArray(entry.elements) || entry.elements.some((element) => !ELEMENT_ORDER.includes(element)))) throw new Error('Invalid event elements.');
    if (entry.terrain !== undefined && !['plain', 'ice', ...ELEMENT_ORDER, ...REACTIONS.map((reaction) => reaction.id)].includes(entry.terrain as string)) throw new Error('Invalid event terrain.');
    if(entry.kind!=='clash'&&['participants','meeting','flightFraction','radius'].some(field=>entry[field]!==undefined))throw new Error('Clash details belong to a clash event.');
    if(entry.kind==='clash'){
      const meeting=object(entry.meeting,['q','r'],'Clash meeting');
      if(!Number.isFinite(meeting.q)||!Number.isFinite(meeting.r)||typeof entry.flightFraction!=='number'||!Number.isFinite(entry.flightFraction)||entry.flightFraction<=0||entry.flightFraction>=1)throw new Error('Invalid in-flight meeting.');
      if(!Array.isArray(entry.participants)||entry.participants.length<2||entry.participants.length>playerCount*3||new Set(entry.participants).size!==entry.participants.length||entry.participants.some(id=>typeof id!=='string'||!units.some(unit=>unit.id===id)))throw new Error('Invalid clash participants.');
      if(entry.radius!==(entry.participants.length>=3?2:1)||entry.unitId!==undefined||entry.owner!==undefined||entry.spellId!==undefined||entry.from!==undefined||entry.to!==undefined||entry.status!==undefined||entry.amount!==undefined||entry.q===undefined||entry.r===undefined)throw new Error('Inconsistent clash event.');
    }
  }
  // Recompute every meeting from the public cast trajectories. A saved replay cannot
  // invent a collision, reuse a consumed projectile, or change its time/field size.
  const events=value.lastResolution as SimEvent[],projectiles:Projectile[]=[];
  const collapseIds=events.filter(event=>event.cause==='collapse').map(event=>event.unitId);
  if(new Set(collapseIds).size!==collapseIds.length)throw new Error('A champion cannot take the same collapse twice.');
  const resolvedRound=value.winner===null?(value.round as number)-1:value.round as number;
  if(resolvedRound>=1)for(const unit of living){
    const exposure=collapseDamageAt({playerCount,boardRadius,round:resolvedRound},unit);
    if(exposure&&(unit.hp>MAX_HP-exposure||!collapseIds.includes(unit.id)))throw new Error('A surviving champion skipped the resolved collapse.');
  }
  const landingById=new Map(units.map(unit=>[unit.id,point(unit)]));
  for(const event of events.filter(event=>event.kind==='push'&&event.unitId&&event.from).reverse())landingById.set(event.unitId!,event.from!);
  for(const event of events.filter(event=>event.kind==='cast')){
    if(!event.unitId||!event.spellId||!event.from||!event.to)throw new Error('Incomplete cast event.');
    const unit=units.find(unit=>unit.id===event.unitId)!,spell=profileSpell(effectiveSpell(unit.championId,event.spellId,unit.affinities),value.spellModel as SpellModel|undefined);
    const friendlyTarget=units.some(ally=>(isAlive(ally)||events.some(event=>event.kind==='defeat'&&event.unitId===ally.id))&&teams[ally.owner]===teams[unit.owner]&&same(landingById.get(ally.id)!,event.to!));
    if(isTravellingProjectile(spell,event.from,event.to,friendlyTarget))projectiles.push({unitId:unit.id,from:event.from,to:event.to,element:spell.element});
  }
  const expectedClashes=(value.projectileModel==='volume'?findProjectileClashes:findLegacyProjectileClashes)(projectiles,cells),savedClashes=events.filter(event=>event.kind==='clash');
  if(expectedClashes.length!==savedClashes.length||expectedClashes.some((clash,index)=>{
    const saved=savedClashes[index];return JSON.stringify(saved.participants)!==JSON.stringify(clash.participants)||saved.flightFraction!==clash.flightFraction||saved.meeting?.q!==clash.meeting.q||saved.meeting?.r!==clash.meeting.r||saved.q!==clash.q||saved.r!==clash.r||saved.radius!==clash.radius||JSON.stringify(saved.elements)!==JSON.stringify(clash.elements)||saved.terrain!==combinationFor(clash.elements)!.id;
  }))throw new Error('Saved projectile meetings are inconsistent.');
  return structuredClone({ ...value, learnedSignatures, cells, units,...(inhabitants?{inhabitants}:{}) }) as SimState;
}
