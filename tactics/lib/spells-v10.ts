/** V10: learned signatures and bounded affinity scaling over the frozen V9 catalogue. */
import { getChampion,ADVANCED_AFFINITY_THRESHOLD,validateAffinityAllocation,MAX_AFFINITY_ELEMENTS,MAX_AFFINITY_LEVEL,type AffinityAllocation } from './roster-v10.ts';
import type { Element } from './game.ts';
export type StatusId = 'burn' | 'wet' | 'chilled' | 'rooted' | 'concussed' | 'blind' | 'ward' | 'clarity' | 'anchored' | 'haste' | 'wither' | 'resolve';
export type Status = { turns: number; power: number };
export type StatusApplication = { id: StatusId; turns: number; power?: number };
export type SpellLevel=1|2|3|4|5|6;
export type Spell = {
  id: string; name: string; element: Element; description: string; signatureChampionId?: string;
  level: SpellLevel; branch: string;
  cost: number; cooldown: number; range: number; shape: 'hex' | 'burst' | 'ring' | 'line' | 'sweep' | 'wall'; radius: number;
  damage: number; heal: number; harm: 'all' | 'enemy';
  harmful?: StatusApplication[]; friendly?: StatusApplication[]; self?: StatusApplication[];
  push?: number; cleanse?: boolean; dispel?: boolean; wall?: boolean; pierce?: boolean; freeze?: boolean;
  drain?: number; steal?: number; recharge?: number; selfDamage?: number;
  bonus?: 'burn' | 'wet' | 'wither' | 'wounded'; bonusDamage?: number;
};
export const ELEMENT_BRANCHES:Record<Element,string> = {fire:'Lightning',water:'Ice',earth:'Metal',air:'Storm',light:'Radiance',dark:'Void'};
/** Six successive affinity thresholds; the first two each offer two complementary tools. */
export const ELEMENT_SPELL_LEVELS:Record<Element,readonly (readonly string[])[]> = {
  fire:[['ember','cauterize'],['backdraft','immolate'],['flare'],['fire_lance'],['wildfire'],['inferno']],
  water:[['water_jet','cleansing_tide'],['undertow','tidal_surge'],['frostbite'],['deep_freeze'],['rainfall'],['maelstrom']],
  earth:[['stone','bulwark'],['grasping_roots','stoneheart'],['shatter'],['raise_cairn'],['fault_line'],['quake']],
  air:[['gust','tailwind'],['gale','vacuum'],['wind_shear'],['thunderclap'],['slipstream'],['cyclone']],
  light:[['radiant_bolt','mend'],['clear_sight','aegis'],['sunburst'],['prism_lance'],['inspire'],['sanctuary']],
  dark:[['wither_bolt','siphon'],['veil','soul_chain'],['essence_theft'],['reap'],['blight'],['eclipse']],
};
const SPELL_LEVEL_BY_ID=Object.fromEntries(Object.values(ELEMENT_SPELL_LEVELS).flatMap(levels=>levels.flatMap((ids,index)=>ids.map(id=>[id,(index+1) as SpellLevel])))) as Record<string,SpellLevel>;
const advancedIds=(element:Element)=>ELEMENT_SPELL_LEVELS[element].slice(ADVANCED_AFFINITY_THRESHOLD-1).flat();
export const ADVANCED_SPELL_IDS:Record<Element,readonly string[]>={fire:advancedIds('fire'),water:advancedIds('water'),earth:advancedIds('earth'),air:advancedIds('air'),light:advancedIds('light'),dark:advancedIds('dark')};
export const STATUS_DEFINITIONS: { id: StatusId; name: string; symbol: string; color: string; description: string }[] = [
  { id: 'burn', name: 'Burn', symbol: '♨', color: '#ff875c', description: 'Take 1 damage per power at the next exchange. Wet or cleansing removes Burn before it deals damage.' },
  { id: 'wet', name: 'Wet', symbol: '≈', color: '#68cdea', description: 'Removes existing and incoming Burn. Enables bonus damage from spells that require Wet.' },
  { id: 'chilled', name: 'Chilled', symbol: '❄', color: '#a8e5f4', description: 'Movement drops from 4 to 3 effort next round. Casting is unaffected.' },
  { id: 'rooted', name: 'Rooted', symbol: '⌘', color: '#a3bd79', description: 'No movement next round; casting and Guard still work. Grants Resolve against repeated control.' },
  { id: 'concussed', name: 'Concussed', symbol: '✦', color: '#d9b287', description: 'Spells cost 1 extra Flux next round. Movement and Guard are unaffected.' },
  { id: 'blind', name: 'Blind', symbol: '◌', color: '#c6a9e9', description: 'Spell reach drops by 1 next round, to a minimum of 1. Self-targeted spells remain self-targeted.' },
  { id: 'ward', name: 'Ward', symbol: '◇', color: '#ffe6a4', description: 'Reduce total spell damage by its power at the next hit, except piercing damage. New Ward starts next round.' },
  { id: 'clarity', name: 'Clarity', symbol: '☼', color: '#fff1b8', description: 'Blocks new Blind, Rooted, Chilled and Concussed, including this round. Does not remove existing effects.' },
  { id: 'anchored', name: 'Anchored', symbol: '▰', color: '#c1ac8c', description: 'Blocks pushes and pulls; you can still move voluntarily. New Anchored starts next round.' },
  { id: 'haste', name: 'Haste', symbol: '»', color: '#b6f0dc', description: 'Gain 1 movement effort next round. Rooted still prevents movement; Chilled plus Haste gives 4 effort.' },
  { id: 'wither', name: 'Wither', symbol: '†', color: '#c09bdf', description: 'Reduce total healing received by 1 per power, starting next round. Cleansing removes it before healing is calculated.' },
  { id: 'resolve', name: 'Resolve', symbol: '◆', color: '#e9d59b', description: 'Blocks new Blind, Rooted, Chilled and Concussed after receiving control. Does not remove the current effect.' },
];
const status = (id: StatusId, turns = 1, power = 1): StatusApplication => ({ id, turns, power });
function define(element: Element, id: string, name: string, description: string, options: Partial<Omit<Spell, 'id' | 'name' | 'element' | 'description'>>): Spell {
  const level=SPELL_LEVEL_BY_ID[id]??1;
  const branch=level>=ADVANCED_AFFINITY_THRESHOLD?ELEMENT_BRANCHES[element]:element.charAt(0).toUpperCase()+element.slice(1);
  return { id, name, element, description, level, branch, cost: 2, cooldown: 0, range: 3, shape: 'hex', radius: 0, damage: 0, heal: 0, harm: 'all', ...options };
}
export const SPELLS: Spell[] = [
  define('fire', 'ember', 'Ember', 'Deal 2 damage and apply Burn. Wet prevents the Burn.', { damage: 2, harmful: [status('burn')] }),
  define('fire', 'fire_lance', 'Lightning Lance', 'Deal 1 piercing damage to everyone along the shortest paths to the target, or 2 if they were already Wet. Wet applied this round gives no bonus. Leaves Fire.', { cost: 3, cooldown: 1, range: 5, shape: 'line', damage: 1, pierce: true, bonus: 'wet', bonusDamage: 1 }),
  define('fire', 'backdraft', 'Backdraft', 'Deal 2 damage, or 4 if the target was already Burning. Burn applied this round gives no bonus.', { cost: 3, damage: 2, bonus: 'burn', bonusDamage: 2 }),
  define('fire', 'wildfire', 'Flashburn', 'Deal 1 damage and apply Burn to everyone in a 19-hex burst, including allies. Leaves Fire.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, damage: 1, harmful: [status('burn')] }),
  define('fire', 'flare', 'Lightning Flash', 'Deal 1 damage and apply Blind for the next round. Leaves Fire.', { cost: 2, cooldown: 1, range: 4, damage: 1, harmful: [status('blind')] }),
  define('fire', 'immolate', 'Immolate', 'Deal 4 damage and apply Burn at close range. The caster takes 1 damage.', { cost: 4, cooldown: 2, range: 2, damage: 4, selfDamage: 1, harmful: [status('burn')] }),
  define('fire', 'cauterize', 'Cauterize', 'Heal an ally for 3 and cleanse ailments. Apply Burn afterward unless they are Wet.', { cost: 3, cooldown: 1, heal: 3, cleanse: true, friendly: [status('burn')] }),
  define('fire', 'inferno', 'Overload', 'Deal 3 damage to everyone in a 7-hex burst, including allies. The caster takes 2 damage. Leaves Fire.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, damage: 3, selfDamage: 2 }),

  define('water', 'water_jet', 'Water Jet', 'Deal 2 damage and apply Wet for 2 rounds. Wet removes existing and incoming Burn.', { damage: 2, harmful: [status('wet', 2)] }),
  define('water', 'cleansing_tide', 'Cleansing Tide', 'Heal an ally for 2, cleanse ailments and apply Wet for 2 rounds.', { cost: 3, cooldown: 1, heal: 2, cleanse: true, friendly: [status('wet', 2)] }),
  define('water', 'frostbite', 'Frostbite', 'Deal 1 damage, apply Chilled and freeze the hex. Entering Ice slides straight to its last icy hex; Fire melts it.', { cost: 2, cooldown: 1, damage: 1, freeze: true, harmful: [status('chilled')] }),
  define('water', 'tidal_surge', 'Tidal Surge', 'Aim along a straight hex line: deal 1 damage, push 1 hex away and apply Wet across 5 hexes. Affects allies; Guard or Anchored stops the push.', { cost: 4, cooldown: 2, shape: 'sweep', radius: 2, damage: 1, push: 1, harmful: [status('wet', 2)] }),
  define('water', 'undertow', 'Undertow', 'Deal 2 damage, pull 1 hex toward the caster and apply Wet. Guard or Anchored stops the pull.', { cost: 3, cooldown: 1, damage: 2, push: -1, harmful: [status('wet', 2)] }),
  define('water', 'rainfall', 'Snowmelt', 'Heal allies for 1, cleanse ailments and apply Wet in a 19-hex burst. Leaves Water; this spell does not freeze its footprint.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, heal: 1, cleanse: true, friendly: [status('wet', 2)] }),
  define('water', 'deep_freeze', 'Deep Freeze', 'Deal 1 damage, freeze the hex and prevent movement next round. Deal 2 extra damage if the target was already Wet. Fire melts the Ice.', { cost: 4, cooldown: 2, damage: 1, freeze: true, harmful: [status('rooted')], bonus: 'wet', bonusDamage: 2 }),
  define('water', 'maelstrom', 'Meltwater Vortex', 'Deal 1 damage, apply Wet and pull everyone in a 12-hex ring toward its centre. The 7 inner hexes are unaffected. Leaves Water.', { cost: 5, cooldown: 3, shape: 'ring', radius: 2, damage: 1, push: -1, harmful: [status('wet', 2)] }),

  define('air', 'gust', 'Gust', 'Deal 1 damage and push 1 hex away from the caster. Guard or Anchored stops the push.', { damage: 1, push: 1 }),
  define('air', 'gale', 'Gale', 'Deal 1 damage and push up to 2 hexes away. Stops at an obstacle or the map edge; Guard or Anchored blocks it.', { cost: 4, cooldown: 2, damage: 1, push: 2 }),
  define('air', 'vacuum', 'Vacuum', 'Pull up to 2 hexes toward the caster without direct damage. Guard or Anchored stops the pull.', { cost: 3, cooldown: 1, range: 4, push: -2 }),
  define('air', 'wind_shear', 'Wind Shear', 'Deal 2 damage to everyone along the shortest paths to the target. Leave Air on those hexes.', { cost: 3, cooldown: 1, range: 5, shape: 'line', damage: 2 }),
  define('air', 'thunderclap', 'Thunderclap', 'Deal 2 damage and apply Concussed: spells cost 1 extra Flux next round.', { cost: 3, cooldown: 1, damage: 2, harmful: [status('concussed')] }),
  define('air', 'tailwind', 'Tailwind', 'Give an ally 1 extra movement effort and 1 Flux for the next round.', { cost: 2, cooldown: 1, friendly: [status('haste')], recharge: 1 }),
  define('air', 'cyclone', 'Cyclone', 'Deal 1 damage and push everyone in a 12-hex ring outward. The 7 inner hexes are unaffected.', { cost: 5, cooldown: 3, shape: 'ring', radius: 2, damage: 1, push: 1 }),
  define('air', 'slipstream', 'Stormguard', 'Give yourself Haste and Ward 1 for next round. Clarity blocks incoming control this round.', { cost: 3, cooldown: 2, range: 0, friendly: [status('haste'), status('ward', 1, 1), status('clarity')] }),

  define('earth', 'stone', 'Stone', 'Deal 2 damage and leave Earth. Combine with Fire for Magma or Water for Quagmire.', { damage: 2 }),
  define('earth', 'bulwark', 'Bulwark', 'Give an ally Ward 3 and Anchored for next round. New protection does not block this round\'s damage or pushes.', { cost: 3, cooldown: 1, friendly: [status('ward', 1, 3), status('anchored')] }),
  define('earth', 'quake', 'Iron Quake', 'Deal 1 damage and apply Concussed to everyone in a 19-hex burst, including allies.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, damage: 1, harmful: [status('concussed')] }),
  define('earth', 'grasping_roots', 'Grasping Roots', 'Deal 1 damage and prevent movement next round. Resolve blocks repeated control.', { cost: 3, cooldown: 2, damage: 1, harmful: [status('rooted')] }),
  define('earth', 'shatter', 'Steel Shard', 'Deal 3 piercing damage through Ward and forest cover, and remove any temporary barrier on the target hex.', { cost: 4, cooldown: 1, damage: 3, pierce: true, dispel: true }),
  define('earth', 'raise_cairn', 'Iron Rampart', 'Aim along a straight hex line to raise a 3-hex metal barrier lasting through next round. Occupied hexes and wells stay open.', { cost: 4, cooldown: 2, shape: 'wall', wall: true }),
  define('earth', 'fault_line', 'Iron Fault', 'Deal 2 damage along a line and push each target 1 hex away from the caster.', { cost: 4, cooldown: 2, range: 4, shape: 'line', damage: 2, push: 1 }),
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
  define('dark', 'blight', 'Null Field', 'Deal 1 damage and apply Wither to everyone in a 19-hex burst, including allies.', { cost: 5, cooldown: 3, shape: 'burst', radius: 2, damage: 1, harmful: [status('wither', 2)] }),
  define('dark', 'soul_chain', 'Soul Chain', 'Deal 1 damage and prevent movement next round. The caster gains Wither for 2 rounds.', { cost: 3, cooldown: 2, damage: 1, harmful: [status('rooted')], self: [status('wither', 2)] }),
  define('dark', 'reap', 'Reap', 'Deal 2 damage, or 4 if the target was already Withered. Heal the caster for 1 if an enemy takes spell damage after protection.', { cost: 4, cooldown: 1, damage: 2, bonus: 'wither', bonusDamage: 2, drain: 1 }),
  define('dark', 'essence_theft', 'Essence Theft', 'Deal 1 damage and steal up to 2 Flux from an enemy. Spell costs are paid before theft.', { cost: 3, cooldown: 1, damage: 1, steal: 2 }),
  define('dark', 'eclipse', 'Eclipse', 'Deal 2 damage and apply Blind to everyone in a 7-hex burst, including allies. The caster gains Wither for 2 rounds.', { cost: 5, cooldown: 3, shape: 'burst', radius: 1, damage: 2, harmful: [status('blind')], self: [status('wither', 2)] }),
].map((spell) => ({ ...spell, range: spell.range > 0 ? spell.range + 1 : 0 }));
/** Names follow H.E.X.'s character perks; their turn-based effects are specific to Confluence.
 * Its creator keeps a fixed fifth choice. A learned signature occupies an ordinary slot for others.
 * The creator pays exactly two fewer affinity points and Flux, without another affinity discount.
 */
function signature(championId: string, name: string, description: string, options: Partial<Spell>): Spell {
  return define(getChampion(championId).element, `signature_${championId}`, name, description,
    { cooldown: 3, range: 4, ...options, cost: 5, level: 5, branch: ELEMENT_BRANCHES[getChampion(championId).element], signatureChampionId: championId });
}
export const SIGNATURES: Spell[] = [
  signature('oh_tipi', 'Current Anchor', 'Heal an ally for 2 and apply Wet for 2 rounds. Give Anchored for next round, resisting pushes and pulls.', { heal: 2, friendly: [status('wet', 2), status('anchored')] }),
  signature('s_wayne', 'Shadow Budget', 'Deal 1 damage and steal up to 2 Flux from an enemy after spell costs. Give yourself Haste next round.', { damage: 1, steal: 2, self: [status('haste')] }),
  signature('red_baron', 'Last Redoubt', 'Heal yourself for 1. Gain Ward 3 and Anchored for next round; neither blocks this exchange.', { range: 0, heal: 1, friendly: [status('ward', 1, 3), status('anchored')] }),
  signature('grace_reava', 'Falling Ribbon', 'Deal 1 damage and pull everyone in a 3-hex fan toward you. Give yourself Haste next round; allies can be pulled.', { shape: 'sweep', radius: 1, damage: 1, push: -1, self: [status('haste')] }),
  signature('wa_bidi', 'Scrap Spark', 'Deal 3 damage to the target and take 1 damage yourself. Give yourself Haste next round.', { damage: 3, selfDamage: 1, self: [status('haste')] }),
  signature('steezo', 'Slide Encore', 'Deal 2 damage to everyone along the shortest paths to the target. Give yourself Haste next round; the line can hit allies.', { range: 5, shape: 'line', damage: 2, self: [status('haste')] }),
  signature('treevor_mason', "Mason's Stance", 'Raise a 3-hex wall. Occupied hexes and wells stay open; allies in the strip gain Ward 2 and Anchored for next round.', { shape: 'wall', wall: true, friendly: [status('ward', 1, 2), status('anchored')] }),
  signature('oll_i', 'Cornered Bound', 'Heal yourself for 3 and gain Haste next round. Gain Wither for 2 rounds, reducing later healing by 1.', { range: 0, heal: 3, self: [status('haste'), status('wither', 2)] }),
  signature('fluup', 'Patient Reserve', 'Heal yourself for 1. Gain Ward 2 next round and Haste for 2 rounds.', { range: 0, heal: 1, friendly: [status('ward', 1, 2), status('haste', 2)] }),
  signature('nico_lai', 'Quiet Circuit', 'Heal an ally for 1 and restore 3 Flux at the end of this round. Give Ward 1 for next round.', { heal: 1, recharge: 3, friendly: [status('ward', 1, 1)] }),
  signature('spai_si', 'Rising Feint', 'Deal 2 damage and push the target 1 hex away. Give yourself Clarity, blocking incoming control immediately.', { range: 5, damage: 2, push: 1, self: [status('clarity')] }),
  signature('leaf_hidden', 'Sheltered Sap', 'Cleanse yourself and heal for 3. Gain Ward 1 for next round.', { range: 0, heal: 3, cleanse: true, friendly: [status('ward', 1, 1)] }),
  signature('ha_rekt', 'Spent-Wing Rudder', 'Deal 1 damage and pull everyone in a 6-hex ring toward its centre. The centre is unaffected; give yourself Haste next round.', { shape: 'ring', radius: 1, damage: 1, push: -1, self: [status('haste')] }),
  signature('dr_apex', 'Counterweight', 'Deal 1 damage, pull the target 1 hex toward you and apply Concussed. Give yourself Anchored for next round.', { damage: 1, push: -1, harmful: [status('concussed')], self: [status('anchored')] }),
  signature('haara', 'Sunlit Pace', 'Heal an ally for 2, restore 2 Flux at the end of this round and give Haste for next round.', { heal: 2, recharge: 2, friendly: [status('haste')] }),
  signature('hesus_christo', 'Grounded Reprise', 'Deal 2 damage and push everyone in a 3-hex fan 1 hex away from you. Allies can be hit and pushed.', { shape: 'sweep', radius: 1, damage: 2, push: 1 }),
  signature('grimm_bow', 'Second Breath', 'Heal yourself for 2. Gain Haste for 2 rounds and Anchored for next round.', { range: 0, heal: 2, friendly: [status('haste', 2), status('anchored')] }),
  signature('biggy_bob', 'Low Bellows', 'Deal 1 damage and apply Concussed to everyone along a line, including allies. Give yourself Ward 1 for next round.', { range: 5, shape: 'line', damage: 1, harmful: [status('concussed')], self: [status('ward', 1, 1)] }),
  signature('jan_wicked', 'Measured Exit', 'Deal 2 damage and apply Wet for 2 rounds. Give yourself Ward 2 for next round.', { damage: 2, harmful: [status('wet', 2)], self: [status('ward', 1, 2)] }),
  signature('ba_djoh', 'Open-Lane Charge', 'Deal 1 damage along a line and push each target up to 2 hexes away. Allies can be hit; obstacles, Guard and Anchored stop displacement.', { range: 5, shape: 'line', damage: 1, push: 2 }),
  signature('urzh', 'Weighted Resolve', 'Heal yourself for 2 and gain Clarity immediately. Gain Ward 2 for next round.', { range: 0, heal: 2, friendly: [status('clarity'), status('ward', 1, 2)] }),
  signature('donnok', 'Set the Anvil', 'Cleanse an ally and heal for 1. Give Ward 3 for next round.', { heal: 1, cleanse: true, friendly: [status('ward', 1, 3)] }),
  signature('djonah_thaan', 'Retreating Hunger', 'Deal 2 damage; heal yourself for 1 if an enemy takes spell damage after protection. Give yourself Haste next round.', { damage: 2, drain: 1, self: [status('haste')] }),
  signature('luuh_i_zeh', 'Wall Thread', 'Deal 1 damage and Root everyone along a line, including allies. Root prevents movement next round; Resolve blocks repeated control.', { range: 5, shape: 'line', damage: 1, harmful: [status('rooted')] }),
  signature('juul_i_yaina', 'Last Ember Step', 'Deal 1 damage, apply Wet for 2 rounds and push the target up to 2 hexes away. Obstacles, Guard and Anchored stop the push.', { damage: 1, push: 2, harmful: [status('wet', 2)] }),
  signature('faab_i_yaina', 'Steady Descent', 'Heal allies for 2 in a 7-hex burst and give Clarity immediately. Give Ward 1 for next round.', { shape: 'burst', radius: 1, heal: 2, friendly: [status('clarity'), status('ward', 1, 1)] }),
  signature('joh_haynes', 'Unbroken Bearing', 'Deal 1 damage and push everyone in the 6 hexes around you outward. Give yourself Anchored for 2 rounds; your hex is unaffected by the burst.', { range: 0, shape: 'ring', radius: 1, damage: 1, push: 1, self: [status('anchored', 2)] }),
  signature('h_le_ne', 'Quiet Facet', 'Deal 2 piercing damage, bypassing Ward and forest cover. Give yourself Ward 1 for next round.', { damage: 2, pierce: true, self: [status('ward', 1, 1)] }),
  signature('fimu_yashiha', 'Landing Dew', 'Heal allies for 1 in a 7-hex burst and restore 1 Flux. Give Haste for next round.', { shape: 'burst', radius: 1, heal: 1, recharge: 1, friendly: [status('haste')] }),
  signature('sai_laas', 'Bright Rush', 'Deal 2 damage and push the target 1 hex away. Take 1 damage yourself and gain Haste for 2 rounds.', { damage: 2, push: 1, selfDamage: 1, self: [status('haste', 2)] }),
];
export const ALL_SPELLS: Spell[] = [...SPELLS, ...SIGNATURES];
export function getSignature(championId: string): Spell {
  getChampion(championId);
  return SIGNATURES.find((spell) => spell.signatureChampionId === championId)!;
}
export function validateLearnedSignatures(input:unknown):string[] {
  if(!Array.isArray(input)||input.length>SIGNATURES.length||new Set(input).size!==input.length||input.some(id=>typeof id!=='string'||!SIGNATURES.some(spell=>spell.id===id)))throw new Error('Learned signatures must be unique known signature spell IDs.');
  return [...input].sort() as string[];
}
export function availableSpellIds(championId: string, loadout: readonly string[],affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]): string[] {
  const signature=getSignature(championId).id;
  return [...loadout.filter(id=>id!==signature&&ALL_SPELLS.some(spell=>spell.id===id)&&spellAccess(championId,id,affinities,learnedSignatures).unlocked), signature];
}
export function getSpell(id: string): Spell {
  const spell = ALL_SPELLS.find((entry) => entry.id === id);
  if (!spell) throw new Error('Unknown spell.');
  return spell;
}
export function spellCost(championId: string, spellId: string,affinities?:AffinityAllocation): number {
  const champion=getChampion(championId),spell = getSpell(spellId); const affinity = (affinities??champion.affinities)[spell.element] ?? 0;
  if(spell.signatureChampionId)return spell.cost-(spell.signatureChampionId===championId?2:0);
  return Math.max(1, spell.cost + (affinity === 0 ? 1 : affinity >= 2 ? -1 : 0));
}
export type SpellAccess = {unlocked:boolean;requiredAffinity:0|2|3|4|5|6;level:SpellLevel;branch:string;reason?:string};
export function spellAccess(championId:string,spellId:string,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):SpellAccess {
  const champion=getChampion(championId),spell=getSpell(spellId);
  if(spell.signatureChampionId){
    const creator=spell.signatureChampionId===championId,requiredAffinity=creator?3:5;
    const learned=creator||learnedSignatures.includes(spell.id),enough=((affinities??champion.affinities)[spell.element]??0)>=requiredAffinity;
    const reason=!learned?`Beat ${getChampion(spell.signatureChampionId).name} in Story to learn ${spell.name}.`:`Requires ${requiredAffinity} ${spell.element.charAt(0).toUpperCase()+spell.element.slice(1)} affinity points.`;
    return {unlocked:learned&&enough,requiredAffinity,level:spell.level,branch:spell.branch,...(!(learned&&enough)?{reason}:{})};
  }
  const requiredAffinity=spell.level===1?0:spell.level;
  const unlocked=((affinities??champion.affinities)[spell.element]??0)>=requiredAffinity;
  const elementName=spell.element.charAt(0).toUpperCase()+spell.element.slice(1);
  return {unlocked,requiredAffinity,level:spell.level,branch:spell.branch,...(!unlocked?{reason:`Requires ${requiredAffinity} ${elementName} affinity points${spell.level>=ADVANCED_AFFINITY_THRESHOLD?` for level ${spell.level} ${spell.branch}`:''}.`}:{})};
}
export function validateLoadout(championId: string, input: unknown,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]): string[] {
  getChampion(championId);
  if(affinities!==undefined)validateAffinityAllocation(affinities,MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL);
  validateLearnedSignatures(learnedSignatures);
  if (!Array.isArray(input) || input.length !== 4 || new Set(input).size !== 4 || input.some((id) => typeof id !== 'string' || !ALL_SPELLS.some((spell) => spell.id === id)||id===getSignature(championId).id)) throw new Error('Equip exactly 4 different spells. Your own signature has its fixed fifth slot.');
  for(const id of input){const access=spellAccess(championId,id,affinities,learnedSignatures);if(!access.unlocked)throw new Error(`${getSpell(id).name}: ${access.reason}`)}
  return [...input] as string[];
}
function starterSpellIds(championId: string): string[] {
  const champion = getChampion(championId);
  const affinities = Object.entries(champion.affinities).sort(([a, left], [b, right]) => (right ?? 0) - (left ?? 0) || a.localeCompare(b)).map(([element]) => element as Element);
  const primary = SPELLS.filter((spell) => spell.element === champion.element);
  const other = affinities.filter((element) => element !== champion.element);
  const branch=ELEMENT_SPELL_LEVELS[champion.element][ADVANCED_AFFINITY_THRESHOLD-1][0];
  const support: Record<Element, string> = { fire: 'cauterize', water: 'cleansing_tide', air: 'tailwind', earth: 'bulwark', light: 'mend', dark: 'siphon' };
  return [primary[0].id, branch, SPELLS.find((spell) => spell.element === other[0]&&spell.level===1)?.id ?? support[champion.element], other[1] ? SPELLS.find((spell) => spell.element === other[1]&&spell.level===1)!.id : support[champion.element]];
}
/** Preserve legal custom choices in their original slots; replace only unusable slots. */
export function repairLoadout(championId:string,input:unknown,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]):string[] {
  getChampion(championId);
  if(affinities!==undefined)validateAffinityAllocation(affinities,MAX_AFFINITY_ELEMENTS*MAX_AFFINITY_LEVEL);
  const supplied=Array.isArray(input)?input:[];
  const used=new Set<string>();
  const repaired=Array.from({length:4},(_,index):string|undefined=>{
    const id=supplied[index];
    if(typeof id!=='string'||used.has(id)||id===getSignature(championId).id||!ALL_SPELLS.some(spell=>spell.id===id)||!spellAccess(championId,id,affinities,learnedSignatures).unlocked)return undefined;
    used.add(id);return id;
  });
  const choices=[...starterSpellIds(championId),...SPELLS.map(spell=>spell.id)].filter(id=>spellAccess(championId,id,affinities).unlocked);
  for(let slot=0;slot<repaired.length;slot++)if(repaired[slot]===undefined){
    const replacement=choices.find(id=>!used.has(id))!;
    repaired[slot]=replacement;used.add(replacement);
  }
  return validateLoadout(championId,repaired,affinities,learnedSignatures);
}
export function defaultLoadout(championId: string,affinities?:AffinityAllocation,learnedSignatures:readonly string[]=[]): string[] {
  return repairLoadout(championId,starterSpellIds(championId),affinities,learnedSignatures);
}

const CONTROL_STATUSES:readonly StatusId[]=['rooted','chilled','blind','concussed'];
const POSITIVE_STATUSES:readonly StatusId[]=['wet','ward','clarity','anchored','haste','resolve'];
const EFFECTIVE_CACHE=new Map<string,Spell>();
/** Rank 2/5 add one aimed hex of reach; rank 3/6 improve exactly one primary effect.
 * Rank 4 adds one round to non-control target marks or beneficial statuses, capped at three.
 * Self-targeting, footprint, control duration and negative self/ally costs never grow.
 * Pure displacement and barriers gain reach only: forced movement keeps its existing cap.
 */
export function effectiveSpell(championId:string,spellId:string,affinities?:AffinityAllocation):Spell {
  const base=getSpell(spellId),champion=getChampion(championId);
  const rank=Math.max(0,Math.min(MAX_AFFINITY_LEVEL,(affinities??champion.affinities)[base.element]??0));
  const key=`${championId}:${spellId}:${rank}`,cached=EFFECTIVE_CACHE.get(key);if(cached)return cached;
  const spell:Spell={...base,cost:spellCost(championId,spellId,affinities)};
  for(const channel of ['harmful','friendly','self'] as const)if(base[channel])spell[channel]=base[channel]!.map(effect=>({...effect}));
  if(spell.range>0)spell.range+=Number(rank>=2)+Number(rank>=5);
  const potency=Number(rank>=3)+Number(rank>=6);
  if(spell.damage>0)spell.damage+=potency;
  else if(spell.heal>0)spell.heal+=potency;
  else {
    const ward=[...(spell.friendly??[]),...(spell.self??[])].find(effect=>effect.id==='ward');
    if(ward)ward.power=(ward.power??1)+potency;
    else if(spell.recharge)spell.recharge+=potency;
    else if(spell.steal)spell.steal+=potency;
  }
  if(rank>=4)for(const channel of ['harmful','friendly','self'] as const)for(const effect of spell[channel]??[]){
    if(!CONTROL_STATUSES.includes(effect.id)&&(channel==='harmful'||POSITIVE_STATUSES.includes(effect.id)))effect.turns=Math.min(3,effect.turns+1);
  }
  spell.description=describeSpell(spell);
  for(const channel of ['harmful','friendly','self'] as const)if(spell[channel]){spell[channel]!.forEach(Object.freeze);Object.freeze(spell[channel]);}
  Object.freeze(spell);EFFECTIVE_CACHE.set(key,spell);return spell;
}

/** Numeric rules text comes from the same derived object used by preview and resolution. */
export function describeSpell(spell:Spell):string {
  const parts:string[]=[];
  if(spell.damage)parts.push(`Deal ${spell.damage}${spell.pierce?' piercing':''} damage${spell.harm==='enemy'?' to enemies':' to everyone hit, including allies'}.`);
  if(spell.bonus&&spell.bonusDamage)parts.push(`Add ${spell.bonusDamage} damage if already ${spell.bonus==='wounded'?'wounded':spell.bonus==='burn'?'Burning':spell.bonus==='wither'?'Withered':'Wet'} before this exchange.`);
  if(spell.heal)parts.push(`Heal ${spell.range===0?'yourself':'allies'} for ${spell.heal}.`);
  if(spell.cleanse)parts.push('Cleanse allies before healing.');
  const effects=(list:StatusApplication[])=>list.map(effect=>`${STATUS_DEFINITIONS.find(status=>status.id===effect.id)!.name}${effect.id==='ward'||(effect.power??1)>1?` ${effect.power??1}`:''} for ${effect.turns} round${effect.turns===1?'':'s'}`).join(', ');
  if(spell.harmful?.length)parts.push(`Apply ${effects(spell.harmful)}${spell.harm==='enemy'?' to enemies':' to everyone hit'}.`);
  if(spell.friendly?.length)parts.push(`Give ${spell.range===0?'yourself':'allies'} ${effects(spell.friendly)}.`);
  if(spell.self?.length)parts.push(`Give yourself ${effects(spell.self)}.`);
  if(spell.push)parts.push(`${spell.push>0?'Push':'Pull'} up to ${Math.abs(spell.push)} hex${Math.abs(spell.push)===1?'':'es'} ${spell.push<0?'toward':'away from'} ${spell.shape==='ring'||spell.shape==='burst'?'the aim centre':'the caster'}; Guard and Anchored resist.`);
  if(spell.drain)parts.push(`Heal yourself for ${spell.drain} if an enemy takes spell damage after protection.`);
  if(spell.steal)parts.push(`Steal up to ${spell.steal} Flux from enemies after spell costs.`);
  if(spell.recharge)parts.push(`Restore ${spell.recharge} Flux to allies at the end of this round.`);
  if(spell.selfDamage)parts.push(`Take ${spell.selfDamage} damage yourself.`);
  if(spell.wall)parts.push('Raise a 3-hex barrier through next round; occupied hexes and wells stay open.');
  if(spell.dispel)parts.push('Remove temporary barriers.');
  if(spell.freeze)parts.push('Freeze the footprint; entering Ice slides to its end. Fire melts Ice.');
  if(spell.harmful?.some(effect=>effect.id==='burn')||spell.friendly?.some(effect=>effect.id==='burn'))parts.push('Wet prevents Burn.');
  if([...(spell.friendly??[]),...(spell.self??[])].some(effect=>effect.id==='ward'||effect.id==='anchored'))parts.push('New Ward and Anchored protect from next round.');
  if([...(spell.friendly??[]),...(spell.self??[])].some(effect=>effect.id==='clarity'))parts.push('Clarity blocks incoming control immediately.');
  return parts.join(' ');
}

/** A compact exact delta for loadout and training previews. */
export function spellScalingSummary(championId:string,spellId:string,affinities?:AffinityAllocation):string {
  const base=getSpell(spellId),spell=effectiveSpell(championId,spellId,affinities),changes:string[]=[];
  if(spell.range>base.range)changes.push(`+${spell.range-base.range} reach`);
  for(const [field,label] of [['damage','damage'],['heal','healing'],['recharge','Flux restored'],['steal','Flux stolen']] as const)if((spell[field]??0)>(base[field]??0))changes.push(`+${(spell[field]??0)-(base[field]??0)} ${label}`);
  if(Math.abs(spell.push??0)>Math.abs(base.push??0))changes.push(`+${Math.abs(spell.push!)-Math.abs(base.push!)} displacement`);
  let duration=false;
  for(const channel of ['harmful','friendly','self'] as const)(spell[channel]??[]).forEach((effect,index)=>{
    const original=base[channel]![index];
    if(effect.id==='ward'&&(effect.power??1)>(original.power??1))changes.push(`+${(effect.power??1)-(original.power??1)} Ward`);
    if(effect.turns>original.turns)duration=true;
  });
  if(duration)changes.push('+1 status round');
  return changes.length?changes.join(' · '):'Base strength';
}
