/** V5 spell catalogue: data describes effects; tactics.ts owns simultaneous resolution. */
import { getChampion } from './roster.ts';
import type { Element } from './game.ts';
export type StatusId = 'burn' | 'wet' | 'chilled' | 'rooted' | 'concussed' | 'blind' | 'ward' | 'clarity' | 'anchored' | 'haste' | 'wither' | 'resolve';
export type Status = { turns: number; power: number };
export type StatusApplication = { id: StatusId; turns: number; power?: number };
export type Spell = {
  id: string; name: string; element: Element; description: string;
  cost: number; cooldown: number; range: number; shape: 'hex' | 'burst' | 'ring' | 'line' | 'sweep' | 'wall'; radius: number;
  damage: number; heal: number; harm: 'all' | 'enemy';
  harmful?: StatusApplication[]; friendly?: StatusApplication[]; self?: StatusApplication[];
  push?: number; cleanse?: boolean; dispel?: boolean; wall?: boolean; pierce?: boolean;
  drain?: number; steal?: number; recharge?: number; selfDamage?: number;
  bonus?: 'burn' | 'wet' | 'wither' | 'wounded'; bonusDamage?: number;
};
export const STATUS_DEFINITIONS: { id: StatusId; name: string; symbol: string; color: string; description: string }[] = [
  { id: 'burn', name: 'Burn', symbol: '♨', color: '#ff875c', description: 'Takes 1 damage at the next resolution per power. Wet or cleanse extinguishes it; fresh Burn never ticks immediately.' },
  { id: 'wet', name: 'Wet', symbol: '≈', color: '#68cdea', description: 'Extinguishes Burn and enables spells marked for a Wet target.' },
  { id: 'chilled', name: 'Chilled', symbol: '❄', color: '#a8e5f4', description: 'Next planning movement has 1 effort instead of 2. All equipped spells remain available.' },
  { id: 'rooted', name: 'Rooted', symbol: '⌘', color: '#a3bd79', description: 'Cannot move during the next planning round; can still cast or Guard. Grants Resolve against repeat control.' },
  { id: 'concussed', name: 'Concussed', symbol: '✦', color: '#d9b287', description: 'Spells cost 1 extra Flux during the next planning round. Move and Guard remain available.' },
  { id: 'blind', name: 'Blind', symbol: '◌', color: '#c6a9e9', description: 'Spell range is reduced by 1, to a minimum of 1, during the next planning round.' },
  { id: 'ward', name: 'Ward', symbol: '◇', color: '#ffe6a4', description: 'Absorbs its power from the next aggregate spell volley; piercing spells bypass it. Fresh Ward starts next round.' },
  { id: 'clarity', name: 'Clarity', symbol: '☼', color: '#fff1b8', description: 'Intercepts incoming Blind, Rooted, Chilled and Concussed immediately when applied, then protects during its lifetime. Does not remove an existing restriction.' },
  { id: 'anchored', name: 'Anchored', symbol: '▰', color: '#c1ac8c', description: 'Cannot be pushed or pulled. Voluntary movement remains available.' },
  { id: 'haste', name: 'Haste', symbol: '»', color: '#b6f0dc', description: 'Adds 1 movement effort next planning. Rooted still stops movement; Chilled sets base effort to 1.' },
  { id: 'wither', name: 'Wither', symbol: '†', color: '#c09bdf', description: 'Reduces incoming healing by 1 per power. Cleanse removes it before this exchange is calculated.' },
  { id: 'resolve', name: 'Resolve', symbol: '◆', color: '#e9d59b', description: 'After a control effect, protects against further Blind, Rooted, Chilled and Concussed. Control cannot lock every round.' },
];
const status = (id: StatusId, turns = 1, power = 1): StatusApplication => ({ id, turns, power });
function define(element: Element, id: string, name: string, description: string, options: Partial<Omit<Spell, 'id' | 'name' | 'element' | 'description'>>): Spell {
  return { id, name, element, description, cost: 2, cooldown: 0, range: 2, shape: 'hex', radius: 0, damage: 0, heal: 0, harm: 'all', ...options };
}
export const SPELLS: Spell[] = [
  define('fire', 'ember', 'Ember', 'Hit 2 and apply Burn for the next resolution. Wet extinguishes the mark.', { damage: 2, harmful: [status('burn')] }),
  define('fire', 'fire_lance', 'Fire Lance', 'A long line deals 2 to every occupant along its shortest path; leaves Fire throughout.', { cost: 3, cooldown: 1, range: 3, shape: 'line', damage: 2 }),
  define('fire', 'backdraft', 'Backdraft', 'Hit 2, or 4 against a target already Burning. Incoming Burn does not enable this bonus.', { cost: 3, damage: 2, bonus: 'burn', bonusDamage: 2 }),
  define('fire', 'wildfire', 'Wildfire', 'Burst for 1 and Burn everyone in the seven-hex area. Friendly fire applies.', { cost: 4, cooldown: 2, shape: 'burst', radius: 1, damage: 1, harmful: [status('burn')] }),
  define('fire', 'flare', 'Flare', 'Hit 1 and Blind the occupant for next planning; also reveals Fire for chemistry.', { cost: 2, cooldown: 1, range: 3, damage: 1, harmful: [status('blind')] }),
  define('fire', 'immolate', 'Immolate', 'Commit at close range: hit 4 and Burn the target, but suffer 1 self damage.', { cost: 4, cooldown: 2, range: 1, damage: 4, selfDamage: 1, harmful: [status('burn')] }),
  define('fire', 'cauterize', 'Cauterize', 'Heal a friendly occupant for 3 and cleanse ailments, then give them a fresh Burn mark unless Wet.', { cost: 3, cooldown: 1, heal: 3, cleanse: true, friendly: [status('burn')] }),
  define('fire', 'inferno', 'Inferno', 'Burst for 3 with all-side collateral; caster takes 2 self damage. A costly commitment.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, damage: 3, selfDamage: 2 }),

  define('water', 'water_jet', 'Water Jet', 'Hit 2 and make the occupant Wet. Wet removes old and incoming Burn.', { damage: 2, harmful: [status('wet', 2)] }),
  define('water', 'cleansing_tide', 'Cleansing Tide', 'Heal a friend for 2, cleanse ailments and grant Wet. Can rescue a simultaneous exchange.', { cost: 3, cooldown: 1, heal: 2, cleanse: true, friendly: [status('wet', 2)] }),
  define('water', 'frostbite', 'Frostbite', 'Hit 1 and Chill the occupant, reducing next planning movement effort to 1.', { cost: 2, cooldown: 1, damage: 1, harmful: [status('chilled')] }),
  define('water', 'tidal_surge', 'Tidal Surge', 'Aim along a straight hex axis. A three-hex forward arc hits 1, pushes away from the caster and applies Wet. Allies are affected; Guard or Anchor blocks displacement.', { cost: 3, cooldown: 1, shape: 'sweep', damage: 1, push: 1, harmful: [status('wet', 2)] }),
  define('water', 'undertow', 'Undertow', 'Hit 2 and pull the occupant one hex toward the caster. Also applies Wet.', { cost: 3, cooldown: 1, damage: 2, push: -1, harmful: [status('wet', 2)] }),
  define('water', 'rainfall', 'Rainfall', 'A friendly burst heals 1, cleanses ailments and gives Wet. Water fields still interact with enemy spells.', { cost: 4, cooldown: 2, shape: 'burst', radius: 1, heal: 1, cleanse: true, friendly: [status('wet', 2)] }),
  define('water', 'deep_freeze', 'Deep Freeze', 'Hit 1 and Root the occupant for one planning round. Wet targets also take 2 bonus damage.', { cost: 4, cooldown: 2, damage: 1, harmful: [status('rooted')], bonus: 'wet', bonusDamage: 2 }),
  define('water', 'maelstrom', 'Maelstrom', 'A ring hits for 1 and pulls surrounding occupants toward its centre. The centre is safe.', { cost: 4, cooldown: 2, shape: 'ring', radius: 1, damage: 1, push: -1, harmful: [status('wet', 2)] }),

  define('air', 'gust', 'Gust', 'Hit 1 and push one hex away. Any legal range works; counter with Guard or Anchor.', { damage: 1, push: 1 }),
  define('air', 'gale', 'Gale', 'Hit 1 and push up to two hexes, stopping at the edge or a blocked step.', { cost: 4, cooldown: 2, damage: 1, push: 2 }),
  define('air', 'vacuum', 'Vacuum', 'Pull an occupant up to two hexes toward the caster, without direct damage.', { cost: 3, cooldown: 1, range: 3, push: -2 }),
  define('air', 'wind_shear', 'Wind Shear', 'A narrow line hits every occupant for 2 and leaves an Air field along its shortest rays.', { cost: 3, cooldown: 1, range: 3, shape: 'line', damage: 2 }),
  define('air', 'thunderclap', 'Thunderclap', 'Hit 2 and Concuss the occupant: their next planning spells cost 1 extra Flux.', { cost: 3, cooldown: 1, damage: 2, harmful: [status('concussed')] }),
  define('air', 'tailwind', 'Tailwind', 'Give a friendly occupant Haste and 1 Flux for the next planning round.', { cost: 2, cooldown: 1, friendly: [status('haste')], recharge: 1 }),
  define('air', 'cyclone', 'Cyclone', 'A ring hits for 1 and pushes outward from its centre; the central hex is safe.', { cost: 4, cooldown: 2, shape: 'ring', radius: 1, damage: 1, push: 1 }),
  define('air', 'slipstream', 'Slipstream', 'Self preparation: Haste and Ward 1 start next planning; Clarity also intercepts incoming control now.', { cost: 3, cooldown: 2, range: 0, friendly: [status('haste'), status('ward', 1, 1), status('clarity')] }),

  define('earth', 'stone', 'Stone', 'Hit 2. A reliable Earth mark for Magma or Quagmire combinations.', { damage: 2 }),
  define('earth', 'bulwark', 'Bulwark', 'Give a friendly occupant Ward 3 and Anchor for next planning.', { cost: 3, cooldown: 1, friendly: [status('ward', 1, 3), status('anchored')] }),
  define('earth', 'quake', 'Quake', 'A burst hits for 1 and Concusses all occupants; even allies must respect its footprint.', { cost: 4, cooldown: 2, shape: 'burst', radius: 1, damage: 1, harmful: [status('concussed')] }),
  define('earth', 'grasping_roots', 'Grasping Roots', 'Hit 1 and Root the occupant next planning. Resolve prevents repeated movement denial.', { cost: 3, cooldown: 2, damage: 1, harmful: [status('rooted')] }),
  define('earth', 'shatter', 'Shatter', 'Hit 3 through Ward and break a temporary barrier on the target hex.', { cost: 4, cooldown: 1, damage: 3, pierce: true, dispel: true }),
  define('earth', 'raise_cairn', 'Raise Cairn', 'Aim along a straight hex axis to raise a three-hex barrier strip through the next resolution. Occupied hexes and wells stay open. Preview shows its orientation.', { cost: 4, cooldown: 2, shape: 'wall', wall: true }),
  define('earth', 'fault_line', 'Fault Line', 'A line hits for 2 and pushes occupants one hex away from the caster.', { cost: 4, cooldown: 2, range: 3, shape: 'line', damage: 2, push: 1 }),
  define('earth', 'stoneheart', 'Stoneheart', 'Heal a friend for 2 and give Anchor plus Ward 1 next planning.', { cost: 3, cooldown: 1, heal: 2, friendly: [status('anchored'), status('ward', 1, 1)] }),

  define('light', 'radiant_bolt', 'Radiant Bolt', 'Hit an enemy for 2, or heal a friend for 1. Leaves Light without friendly damage.', { damage: 2, heal: 1, harm: 'enemy' }),
  define('light', 'mend', 'Mend', 'Heal a friendly occupant for 3; Wither reduces the healing unless cleansed.', { cost: 3, cooldown: 1, heal: 3 }),
  define('light', 'clear_sight', 'Clear Sight', 'Cleanse a friend and grant Clarity, protecting their next planning from new control.', { cost: 2, cooldown: 1, cleanse: true, friendly: [status('clarity', 2)] }),
  define('light', 'aegis', 'Aegis', 'Grant a friendly occupant Ward 3 for their next simultaneous exchange.', { cost: 3, cooldown: 1, friendly: [status('ward', 1, 3)] }),
  define('light', 'sunburst', 'Sunburst', 'Burst for 1 against enemies and Blind them. Allies in the footprint are unharmed.', { cost: 4, cooldown: 2, shape: 'burst', radius: 1, damage: 1, harm: 'enemy', harmful: [status('blind')] }),
  define('light', 'prism_lance', 'Prism Lance', 'A line hits enemies for 2 through Ward. Allied occupants are safe.', { cost: 4, cooldown: 1, range: 3, shape: 'line', damage: 2, harm: 'enemy', pierce: true }),
  define('light', 'inspire', 'Inspire', 'Heal a friend for 1 and restore 2 Flux after this resolution.', { cost: 3, cooldown: 1, heal: 1, recharge: 2 }),
  define('light', 'sanctuary', 'Sanctuary', 'A friendly burst heals 2, cleanses ailments and gives Ward 1 for next round.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, heal: 2, cleanse: true, friendly: [status('ward', 1, 1)] }),

  define('dark', 'wither_bolt', 'Wither Bolt', 'Hit 2 and apply Wither, reducing future healing until cleansed or expired.', { damage: 2, harmful: [status('wither', 2)] }),
  define('dark', 'siphon', 'Siphon', 'Hit 2; if an enemy receives damage through protection, heal the caster for 1 in the same exchange.', { cost: 3, cooldown: 1, damage: 2, drain: 1 }),
  define('dark', 'veil', 'Veil', 'Blind the occupant and steal 1 Flux from an enemy after costs; no direct damage.', { cost: 2, cooldown: 1, harmful: [status('blind')], steal: 1 }),
  define('dark', 'blight', 'Blight', 'Burst for 1 and Wither every occupant. Its Dark can combine with a rival Light field.', { cost: 4, cooldown: 2, shape: 'burst', radius: 1, damage: 1, harmful: [status('wither', 2)] }),
  define('dark', 'soul_chain', 'Soul Chain', 'Hit 1 and Root the occupant next round, but apply Wither to the caster.', { cost: 3, cooldown: 2, damage: 1, harmful: [status('rooted')], self: [status('wither', 2)] }),
  define('dark', 'reap', 'Reap', 'Hit 2, or 4 against an already Withered target. Siphon 1 if enemy damage gets through.', { cost: 4, cooldown: 1, damage: 2, bonus: 'wither', bonusDamage: 2, drain: 1 }),
  define('dark', 'essence_theft', 'Essence Theft', 'Hit 1 and steal up to 2 remaining Flux from an enemy. Costs resolve before theft.', { cost: 3, cooldown: 1, damage: 1, steal: 2 }),
  define('dark', 'eclipse', 'Eclipse', 'Burst for 2 and Blind all occupants. Caster suffers Wither as the price of commitment.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, damage: 2, harmful: [status('blind')], self: [status('wither', 2)] }),
];
export function getSpell(id: string): Spell {
  const spell = SPELLS.find((entry) => entry.id === id);
  if (!spell) throw new Error('Unknown spell.');
  return spell;
}
export function spellCost(championId: string, spellId: string): number {
  const spell = getSpell(spellId); const affinity = getChampion(championId).affinities[spell.element] ?? 0;
  return Math.max(1, spell.cost + (affinity === 0 ? 1 : affinity === 2 ? -1 : 0));
}
export function validateLoadout(championId: string, input: unknown): string[] {
  getChampion(championId);
  if (!Array.isArray(input) || input.length !== 4 || new Set(input).size !== 4 || input.some((id) => typeof id !== 'string' || !SPELLS.some((spell) => spell.id === id))) throw new Error('Equip exactly 4 different known spells; every element is allowed.');
  return [...input] as string[];
}
export function defaultLoadout(championId: string): string[] {
  const champion = getChampion(championId);
  const affinities = Object.entries(champion.affinities).sort(([a, left], [b, right]) => (right ?? 0) - (left ?? 0) || a.localeCompare(b)).map(([element]) => element as Element);
  const primary = SPELLS.filter((spell) => spell.element === champion.element);
  const other = affinities.filter((element) => element !== champion.element);
  const signature: Record<Element, string> = { fire: 'fire_lance', water: 'tidal_surge', air: 'cyclone', earth: 'raise_cairn', light: 'sunburst', dark: 'blight' };
  const support: Record<Element, string> = { fire: 'flare', water: 'cleansing_tide', air: 'tailwind', earth: 'bulwark', light: 'mend', dark: 'siphon' };
  return validateLoadout(championId, [primary[0].id, signature[champion.element], SPELLS.find((spell) => spell.element === other[0])?.id ?? primary[2].id, other[1] ? SPELLS.find((spell) => spell.element === other[1])!.id : support[champion.element]]);
}
