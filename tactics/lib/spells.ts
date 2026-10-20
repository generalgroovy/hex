/** V6 spell catalogue: data describes effects; tactics.ts owns simultaneous resolution. */
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
  { id: 'burn', name: 'Burn', symbol: '♨', color: '#ff875c', description: 'Take 1 damage per power at the next exchange. Wet or cleansing removes Burn before it deals damage.' },
  { id: 'wet', name: 'Wet', symbol: '≈', color: '#68cdea', description: 'Removes existing and incoming Burn. Enables bonus damage from spells that require Wet.' },
  { id: 'chilled', name: 'Chilled', symbol: '❄', color: '#a8e5f4', description: 'Movement drops from 3 to 2 effort next round. Casting is unaffected.' },
  { id: 'rooted', name: 'Rooted', symbol: '⌘', color: '#a3bd79', description: 'No movement next round; casting and Guard still work. Grants Resolve against repeated control.' },
  { id: 'concussed', name: 'Concussed', symbol: '✦', color: '#d9b287', description: 'Spells cost 1 extra Flux next round. Movement and Guard are unaffected.' },
  { id: 'blind', name: 'Blind', symbol: '◌', color: '#c6a9e9', description: 'Spell reach drops by 1 next round, to a minimum of 1. Self-targeted spells remain self-targeted.' },
  { id: 'ward', name: 'Ward', symbol: '◇', color: '#ffe6a4', description: 'Reduce total spell damage by its power at the next hit, except piercing damage. New Ward starts next round.' },
  { id: 'clarity', name: 'Clarity', symbol: '☼', color: '#fff1b8', description: 'Blocks new Blind, Rooted, Chilled and Concussed, including this round. Does not remove existing effects.' },
  { id: 'anchored', name: 'Anchored', symbol: '▰', color: '#c1ac8c', description: 'Blocks pushes and pulls; you can still move voluntarily. New Anchored starts next round.' },
  { id: 'haste', name: 'Haste', symbol: '»', color: '#b6f0dc', description: 'Gain 1 movement effort next round. Rooted still prevents movement; Chilled plus Haste gives 3 effort.' },
  { id: 'wither', name: 'Wither', symbol: '†', color: '#c09bdf', description: 'Reduce total healing received by 1 per power, starting next round. Cleansing removes it before healing is calculated.' },
  { id: 'resolve', name: 'Resolve', symbol: '◆', color: '#e9d59b', description: 'Blocks new Blind, Rooted, Chilled and Concussed after receiving control. Does not remove the current effect.' },
];
const status = (id: StatusId, turns = 1, power = 1): StatusApplication => ({ id, turns, power });
function define(element: Element, id: string, name: string, description: string, options: Partial<Omit<Spell, 'id' | 'name' | 'element' | 'description'>>): Spell {
  return { id, name, element, description, cost: 2, cooldown: 0, range: 3, shape: 'hex', radius: 0, damage: 0, heal: 0, harm: 'all', ...options };
}
export const SPELLS: Spell[] = [
  define('fire', 'ember', 'Ember', 'Deal 2 damage and apply Burn. Wet prevents the Burn.', { damage: 2, harmful: [status('burn')] }),
  define('fire', 'fire_lance', 'Fire Lance', 'Deal 2 damage to everyone along the shortest paths to the target. Leave Fire on those hexes.', { cost: 3, cooldown: 1, range: 5, shape: 'line', damage: 2 }),
  define('fire', 'backdraft', 'Backdraft', 'Deal 2 damage, or 4 if the target was already Burning. Burn applied this round gives no bonus.', { cost: 3, damage: 2, bonus: 'burn', bonusDamage: 2 }),
  define('fire', 'wildfire', 'Wildfire', 'Deal 1 damage and apply Burn to everyone in a 19-hex burst, including allies.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, damage: 1, harmful: [status('burn')] }),
  define('fire', 'flare', 'Flare', 'Deal 1 damage and apply Blind for the next round.', { cost: 2, cooldown: 1, range: 4, damage: 1, harmful: [status('blind')] }),
  define('fire', 'immolate', 'Immolate', 'Deal 4 damage and apply Burn at close range. The caster takes 1 damage.', { cost: 4, cooldown: 2, range: 2, damage: 4, selfDamage: 1, harmful: [status('burn')] }),
  define('fire', 'cauterize', 'Cauterize', 'Heal an ally for 3 and cleanse ailments. Apply Burn afterward unless they are Wet.', { cost: 3, cooldown: 1, heal: 3, cleanse: true, friendly: [status('burn')] }),
  define('fire', 'inferno', 'Inferno', 'Deal 3 damage to everyone in a 7-hex burst, including allies. The caster takes 2 damage.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, damage: 3, selfDamage: 2 }),

  define('water', 'water_jet', 'Water Jet', 'Deal 2 damage and apply Wet for 2 rounds. Wet removes existing and incoming Burn.', { damage: 2, harmful: [status('wet', 2)] }),
  define('water', 'cleansing_tide', 'Cleansing Tide', 'Heal an ally for 2, cleanse ailments and apply Wet for 2 rounds.', { cost: 3, cooldown: 1, heal: 2, cleanse: true, friendly: [status('wet', 2)] }),
  define('water', 'frostbite', 'Frostbite', 'Deal 1 damage and apply Chilled: movement drops to 2 effort next round.', { cost: 2, cooldown: 1, damage: 1, harmful: [status('chilled')] }),
  define('water', 'tidal_surge', 'Tidal Surge', 'Aim along a straight hex line: deal 1 damage, push 1 hex away and apply Wet across 5 hexes. Affects allies; Guard or Anchored stops the push.', { cost: 4, cooldown: 2, shape: 'sweep', radius: 2, damage: 1, push: 1, harmful: [status('wet', 2)] }),
  define('water', 'undertow', 'Undertow', 'Deal 2 damage, pull 1 hex toward the caster and apply Wet. Guard or Anchored stops the pull.', { cost: 3, cooldown: 1, damage: 2, push: -1, harmful: [status('wet', 2)] }),
  define('water', 'rainfall', 'Rainfall', 'Heal allies for 1, cleanse ailments and apply Wet in a 19-hex burst. Its Water can react with either team\'s spells.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, heal: 1, cleanse: true, friendly: [status('wet', 2)] }),
  define('water', 'deep_freeze', 'Deep Freeze', 'Deal 1 damage and prevent movement next round. Deal 2 extra damage if the target was already Wet.', { cost: 4, cooldown: 2, damage: 1, harmful: [status('rooted')], bonus: 'wet', bonusDamage: 2 }),
  define('water', 'maelstrom', 'Maelstrom', 'Deal 1 damage, apply Wet and pull everyone in a 12-hex ring toward its centre. The 7 inner hexes are unaffected.', { cost: 5, cooldown: 3, shape: 'ring', radius: 2, damage: 1, push: -1, harmful: [status('wet', 2)] }),

  define('air', 'gust', 'Gust', 'Deal 1 damage and push 1 hex away from the caster. Guard or Anchored stops the push.', { damage: 1, push: 1 }),
  define('air', 'gale', 'Gale', 'Deal 1 damage and push up to 2 hexes away. Stops at an obstacle or the map edge; Guard or Anchored blocks it.', { cost: 4, cooldown: 2, damage: 1, push: 2 }),
  define('air', 'vacuum', 'Vacuum', 'Pull up to 2 hexes toward the caster without direct damage. Guard or Anchored stops the pull.', { cost: 3, cooldown: 1, range: 4, push: -2 }),
  define('air', 'wind_shear', 'Wind Shear', 'Deal 2 damage to everyone along the shortest paths to the target. Leave Air on those hexes.', { cost: 3, cooldown: 1, range: 5, shape: 'line', damage: 2 }),
  define('air', 'thunderclap', 'Thunderclap', 'Deal 2 damage and apply Concussed: spells cost 1 extra Flux next round.', { cost: 3, cooldown: 1, damage: 2, harmful: [status('concussed')] }),
  define('air', 'tailwind', 'Tailwind', 'Give an ally 1 extra movement effort and 1 Flux for the next round.', { cost: 2, cooldown: 1, friendly: [status('haste')], recharge: 1 }),
  define('air', 'cyclone', 'Cyclone', 'Deal 1 damage and push everyone in a 12-hex ring outward. The 7 inner hexes are unaffected.', { cost: 5, cooldown: 3, shape: 'ring', radius: 2, damage: 1, push: 1 }),
  define('air', 'slipstream', 'Slipstream', 'Give yourself Haste and Ward 1 for next round. Clarity blocks incoming control this round.', { cost: 3, cooldown: 2, range: 0, friendly: [status('haste'), status('ward', 1, 1), status('clarity')] }),

  define('earth', 'stone', 'Stone', 'Deal 2 damage and leave Earth. Combine with Fire for Magma or Water for Quagmire.', { damage: 2 }),
  define('earth', 'bulwark', 'Bulwark', 'Give an ally Ward 3 and Anchored for next round. New protection does not block this round\'s damage or pushes.', { cost: 3, cooldown: 1, friendly: [status('ward', 1, 3), status('anchored')] }),
  define('earth', 'quake', 'Quake', 'Deal 1 damage and apply Concussed to everyone in a 19-hex burst, including allies.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, damage: 1, harmful: [status('concussed')] }),
  define('earth', 'grasping_roots', 'Grasping Roots', 'Deal 1 damage and prevent movement next round. Resolve blocks repeated control.', { cost: 3, cooldown: 2, damage: 1, harmful: [status('rooted')] }),
  define('earth', 'shatter', 'Shatter', 'Deal 3 damage through Ward and remove any temporary barrier on the target hex.', { cost: 4, cooldown: 1, damage: 3, pierce: true, dispel: true }),
  define('earth', 'raise_cairn', 'Raise Cairn', 'Aim along a straight hex line to create a 3-hex barrier lasting through next round. Occupied hexes and wells stay open.', { cost: 4, cooldown: 2, shape: 'wall', wall: true }),
  define('earth', 'fault_line', 'Fault Line', 'Deal 2 damage along a line and push each target 1 hex away from the caster.', { cost: 4, cooldown: 2, range: 4, shape: 'line', damage: 2, push: 1 }),
  define('earth', 'stoneheart', 'Stoneheart', 'Heal an ally for 2. Give them Anchored and Ward 1 for next round.', { cost: 3, cooldown: 1, heal: 2, friendly: [status('anchored'), status('ward', 1, 1)] }),

  define('light', 'radiant_bolt', 'Radiant Bolt', 'Deal 2 damage to an enemy or heal an ally for 1. Allies take no direct damage.', { damage: 2, heal: 1, harm: 'enemy' }),
  define('light', 'mend', 'Mend', 'Heal an ally for 3. Wither reduces healing unless cleansed.', { cost: 3, cooldown: 1, heal: 3 }),
  define('light', 'clear_sight', 'Clear Sight', 'Cleanse an ally and grant Clarity for 2 rounds. Blocks incoming control immediately.', { cost: 2, cooldown: 1, cleanse: true, friendly: [status('clarity', 2)] }),
  define('light', 'aegis', 'Aegis', 'Give an ally Ward 3 for the next exchange. It does not absorb damage this round.', { cost: 3, cooldown: 1, friendly: [status('ward', 1, 3)] }),
  define('light', 'sunburst', 'Sunburst', 'Deal 1 damage and apply Blind to enemies in a 7-hex burst. Allies are unaffected by the direct spell.', { cost: 4, cooldown: 2, shape: 'burst', radius: 1, damage: 1, harm: 'enemy', harmful: [status('blind')] }),
  define('light', 'prism_lance', 'Prism Lance', 'Deal 2 damage through Ward to enemies along a line. Allies take no direct damage.', { cost: 4, cooldown: 1, range: 5, shape: 'line', damage: 2, harm: 'enemy', pierce: true }),
  define('light', 'inspire', 'Inspire', 'Heal an ally for 1 and restore 2 Flux at the end of this round.', { cost: 3, cooldown: 1, heal: 1, recharge: 2 }),
  define('light', 'sanctuary', 'Sanctuary', 'Heal allies for 2 and cleanse ailments in a 7-hex burst. Give Ward 1 for next round.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, heal: 2, cleanse: true, friendly: [status('ward', 1, 1)] }),

  define('dark', 'wither_bolt', 'Wither Bolt', 'Deal 2 damage and apply Wither, reducing healing received over the next 2 rounds.', { damage: 2, harmful: [status('wither', 2)] }),
  define('dark', 'siphon', 'Siphon', 'Deal 2 damage. Heal the caster for 1 if an enemy in the target hex takes spell damage after protection.', { cost: 3, cooldown: 1, damage: 2, drain: 1 }),
  define('dark', 'veil', 'Veil', 'Apply Blind to the target without direct damage. Steal up to 1 Flux if they are an enemy, after spell costs are paid.', { cost: 2, cooldown: 1, harmful: [status('blind')], steal: 1 }),
  define('dark', 'blight', 'Blight', 'Deal 1 damage and apply Wither to everyone in a 19-hex burst, including allies.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, damage: 1, harmful: [status('wither', 2)] }),
  define('dark', 'soul_chain', 'Soul Chain', 'Deal 1 damage and prevent movement next round. The caster gains Wither for 2 rounds.', { cost: 3, cooldown: 2, damage: 1, harmful: [status('rooted')], self: [status('wither', 2)] }),
  define('dark', 'reap', 'Reap', 'Deal 2 damage, or 4 if the target was already Withered. Heal the caster for 1 if an enemy takes spell damage after protection.', { cost: 4, cooldown: 1, damage: 2, bonus: 'wither', bonusDamage: 2, drain: 1 }),
  define('dark', 'essence_theft', 'Essence Theft', 'Deal 1 damage and steal up to 2 Flux from an enemy. Spell costs are paid before theft.', { cost: 3, cooldown: 1, damage: 1, steal: 2 }),
  define('dark', 'eclipse', 'Eclipse', 'Deal 2 damage and apply Blind to everyone in a 7-hex burst, including allies. The caster gains Wither for 2 rounds.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, damage: 2, harmful: [status('blind')], self: [status('wither', 2)] }),
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
