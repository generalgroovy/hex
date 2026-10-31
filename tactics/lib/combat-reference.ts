/** Read-only reference data for the current combat resolver (tactics-v22). */
import type {Element} from './game.ts';
import {ALL_SPELLS,STATUS_DEFINITIONS,ELEMENT_BRANCHES,effectiveSpell,spellAccess,spellOrigin,spellFootprintDescription,type Spell,type StatusId} from './spells-v20.ts';
import {COMBINATIONS,ELEMENT_ORDER,type CombinationDefinition} from './combinations-v16.ts';
import {ADVANCED_AFFINITY_THRESHOLD,MAX_AFFINITY_LEVEL,type AffinityAllocation} from './roster-v13.ts';
import {profileSpell,type SpellModel} from './spell-profile-v42.ts';
import {profiledEffectLabel,profiledSpellDescription} from './spell-profile-label-v42.ts';
import {getCreature} from './campaign-creatures-v20.ts';
import {STATUS_TIMING} from './combat-consequence-v44.ts';

export type ReferenceCaster={championId:string;creatureId?:string;affinities:AffinityAllocation;learnedSpells?:readonly string[];name?:string;statuses?:Partial<Record<StatusId,{turns:number;power:number}>>};
export type ReferenceTab='elements'|'interactions'|'spells'|'forms'|'statuses';
export const REFERENCE_TABS:readonly ReferenceTab[]=['elements','interactions','spells','forms','statuses'];
export const elementName=(element:Element)=>element.charAt(0).toUpperCase()+element.slice(1);
const statusName=(id:StatusId)=>STATUS_DEFINITIONS.find(status=>status.id===id)!.name;

/** Compact numbers come from the same mechanics object as the complete field rule. */
export function combinationSummary(field:CombinationDefinition):string {
 const rule=field.mechanics,parts:string[]=[];
 if(rule.movement==='flood'||rule.movement==='rough')parts.push('Enter / leave: 2 effort');
 if(rule.movement==='ice')parts.push('Slide to end of ice');
 if(rule.movement==='current')parts.push('+1 starting movement');
 if(rule.damageScale==='half')parts.push('Half spell damage');
 if(rule.cover)parts.push(`Cover ${rule.cover}`);
 if(rule.hazard)parts.push(rule.hazard==='always'?'Final occupant: 1 damage':rule.hazard==='formed'?'First formation: 1 damage':'Changed hex: 1 damage');
 if(rule.heal)parts.push(`Heal ${rule.heal}`);
 if(rule.flux)parts.push(`${rule.flux>0?'+':''}${rule.flux} Flux recovery`);
 if(rule.cleanse)parts.push('Cleanse');
 for(const status of rule.statuses??[])parts.push(`${statusName(status.id)}${status.id==='ward'?` ${status.power??1}`:''} · ${status.turns}r`);
 if(rule.wellBonus)parts.push('Spring restores 2 Flux');
 if(rule.consume)parts.push('Disperses this exchange');
 return parts.join(' · ');
}

const TOOLKITS:Record<Element,string>={fire:'Burn, burst damage, piercing lightning',water:'Wet, healing, pulls, freezing',earth:'Ward, Anchored, barriers, piercing metal',air:'Pushes, pulls, Haste, Concussed',light:'Healing, cleansing, Clarity, selective damage',dark:'Wither, draining, stolen Flux, Blind'};
const ROLES:Record<Element,string>={fire:'Pressure',water:'Reshape routes',earth:'Hold ground',air:'Redirect',light:'Protect',dark:'Deny recovery'};
const ELEMENT_CHOICES:Record<Element,{use:string;attack:string;risk:string;detail:string;exampleIds:readonly string[]}>={
 fire:{use:'Punish a landing; exploit an existing mark.',attack:'Apply Burn, then keep pressure on the marked target while it ticks.',risk:'Wet stops Burn; many attacks hit friends.',detail:'Burn adds later pressure. Backdraft needs Burn from before the exchange; Lightning Lance needs earlier Wet. Fire + Water becomes Steam, which halves spell damage instead of keeping Fire’s hazard.',exampleIds:['ember','backdraft','fire_lance']},
 water:{use:'Slow passage, cleanse, or make an ice route.',attack:'Wet a target for a Fire Lance bonus; chill or pull it out of position.',risk:'Your flood and ice change movement for both sides.',detail:'Magical liquid Water makes entering or leaving cost 2 effort and grants Wet. Freezing unmixed Water creates dry Ice: it slides but does not grant Wet. Natural water is a mixing ingredient, not an active Flood.',exampleIds:['water_jet','cleansing_tide','frostbite']},
 earth:{use:'Block an approach; prepare Ward and Anchored.',attack:'Crush with direct hits, then close an escape lane with a barrier.',risk:'New protection cannot stop this exchange’s hits or pushes.',detail:'Magical Earth slows passage; Earth alone gives no cover. Iron Rampart blocks movement and sight on eligible empty hexes. Piercing attacks bypass Ward and cover; flanks can bypass a wall.',exampleIds:['bulwark','raise_cairn','shatter']},
 air:{use:'Push into danger, pull out of cover, or gain a step.',attack:'Push or pull a foe into a hazard, wall, or burst footprint.',risk:'Guard reduces force; existing Anchored stops it.',detail:'All pushes and pulls combine before displacement, so opposing forces can cancel. A blocked forced step into a ruin or barrier causes 1 environmental damage and Concussed. Fighters and map edges stop travel without that impact.',exampleIds:['gust','vacuum','tailwind']},
 light:{use:'Recover health, remove ailments, prevent new control.',attack:'Radiant hits finish weakened foes; Clarity protects a close advance.',risk:'Light ground also protects enemies from control.',detail:'Fresh Clarity blocks new Blind, Rooted, Chilled and Concussed immediately; it does not remove existing ailments. Cleansing does. Healing competes with damage for an action; existing Wither reduces aggregate recovery.',exampleIds:['radiant_bolt','clear_sight','aegis']},
 dark:{use:'Tax future healing and punish a depleted enemy.',attack:'Wither first, then land a damage volley before the enemy can recover.',risk:'Cleanse removes Wither; theft only takes unspent Flux.',detail:'New Wither reduces later healing, not healing in the same exchange. Reap needs existing Wither for its bonus. Drain only heals after actual enemy spell damage; a completely prevented hit yields no drain.',exampleIds:['wither_bolt','reap','essence_theft']},
};
export const REFERENCE_ELEMENTS=ELEMENT_ORDER.map(element=>({element,name:elementName(element),role:ROLES[element],advanced:ELEMENT_BRANCHES[element],advancedAt:ADVANCED_AFFINITY_THRESHOLD,maxLevel:MAX_AFFINITY_LEVEL,toolkit:TOOLKITS[element],field:COMBINATIONS.find(field=>field.id===element)!,...ELEMENT_CHOICES[element]}));
export const REFERENCE_INTERACTIONS=COMBINATIONS.filter(field=>field.elements.length>1);

const CLEAR_RULES:Record<StatusId,string>={
 burn:'Wet or cleanse removes it before damage.',wet:'Expires; enables Wet damage bonuses.',
 chilled:'Cleanse removes it. Clarity or Resolve blocks new control.',rooted:'Cleanse removes it. Clarity or Resolve blocks new control.',
 concussed:'Cleanse removes it. Clarity or Resolve blocks new control.',blind:'Cleanse removes it. Clarity or Resolve blocks new control.',
 ward:'A damaging spell volley consumes it even when fully blocked. Piercing bypasses its protection.',clarity:'Expires; does not remove existing control.',
 anchored:'Expires. Does not prevent voluntary movement.',haste:'Expires. Does not override Rooted.',
 wither:'Cleanse removes it before healing.',resolve:'Expires. Granted for 2 rounds on receiving control.',
};
const CONTROL=new Set<StatusId>(['rooted','chilled','concussed','blind']);
/** Resolver validation and affinity scaling bound durations; refreshing takes the longer duration. */
export const REFERENCE_STATUSES=STATUS_DEFINITIONS.map(status=>({...status,clearRule:CLEAR_RULES[status.id],duration:CONTROL.has(status.id)?'1 round':status.id==='resolve'?'2 rounds':status.id==='ward'||status.id==='burn'?'1–2 rounds':'1–3 rounds'}));
const STATUS_CHOICES:Record<StatusId,{effect:string;answer:string}>={
 burn:{effect:'Later: lose HP equal to power.',answer:'Wet or cleanse before the tick.'},
 wet:{effect:'Now: extinguish Burn. Later: enables Wet bonuses.',answer:'Wait for expiry; avoid marked-target attacks.'},
 chilled:{effect:'Next planning: −1 movement effort.',answer:'Cleanse; Clarity / Resolve blocks application.'},
 rooted:{effect:'Next planning: no movement. Casting still works.',answer:'Cleanse; Clarity / Resolve blocks application.'},
 concussed:{effect:'Next planning: spells cost +1 Flux.',answer:'Guard recovers Flux; cleanse removes it.'},
 blind:{effect:'Next planning: −1 reach, minimum 1.',answer:'Move closer or cleanse; self spells keep their aim.'},
 ward:{effect:'Old Ward absorbs ordinary spell damage once.',answer:'Pierce it or consume it with a damaging volley.'},
 clarity:{effect:'Now: prevents new control; keeps existing ailments.',answer:'Use damage or non-control effects.'},
 anchored:{effect:'Next exchange: blocks forced movement.',answer:'Damage still works; voluntary movement remains.'},
 haste:{effect:'Next planning: +1 movement effort.',answer:'Rooted stops movement; Current does not stack.'},
 wither:{effect:'Later: healing reduced by its power, once per exchange.',answer:'Cleanse before healing.'},
 resolve:{effect:'Prevents new control after receiving control.',answer:'Use another tactic until it expires.'},
};
export function referenceStatusDetail(id:StatusId,spellModel?:SpellModel){
 const sources=ALL_SPELLS.filter(base=>{const spell=profileSpell(base,spellModel);return [...(spell.harmful??[]),...(spell.friendly??[]),...(spell.self??[])].some(effect=>effect.id===id);});
 return {...STATUS_CHOICES[id],timing:STATUS_TIMING[id],examples:sources.filter(spell=>!spell.creatureId&&!spell.signatureChampionId).slice(0,3).map(spell=>spell.name)};
}

export type ReferencePurpose='shelter'|'recovery'|'movement'|'pressure'|'control'|'flux';
export const REFERENCE_PURPOSES:readonly {id:ReferencePurpose;name:string}[]=[{id:'shelter',name:'Shelter'},{id:'recovery',name:'Recovery'},{id:'movement',name:'Movement'},{id:'pressure',name:'Pressure'},{id:'control',name:'Control'},{id:'flux',name:'Flux'}];
/** One concrete offensive setup for every field recipe; these describe play, not extra rules. */
const PRESSURE_PLAYS:Readonly<Record<string,string>>=Object.freeze({
 steam:'Advance through enemy spell lanes under half damage, then counter-cast.',
 magma:'Push a foe onto lava or make its slow crossing cost a turn.',
 quagmire:'Wet and slow a target; line up Fire Lance for its earlier-Wet bonus.',
 arcstorm:'Form the field under a likely landing to deal its first damage.',
 hailcurrent:'Lay ice across a route; Chilled reduces the next move.',
 sandblast:'Concuss a caster before its next plan to raise its Flux cost.',
 solar_flare:'Take the field for Flux and a control-safe frontline advance.',
 mirrorwater:'Hold a contested hex; recovery keeps your attacker in firing range.',
 crystal_prism:'Ward a lead caster so it can hold range through the next volley.',
 lightbend:'Use Haste to flank into range before the next burst.',
 backdraft:'Burn the occupant, then keep pressure on it through the next round.',
 black_ice:'Root a foe on the ice lane and aim a burst at its trapped position.',
 blightsoil:'Wither a wounded target before the next healing window.',
 shadowdraft:'Blind a caster, then close inside its reduced reach.',
 penumbra:'Contest a spring for +2 Flux and spend it on a stronger cast.',
 hot_spring:'Hold a slow crossing under cover; recovery keeps your attacker there.',
 geyser:'Make a foe cross the lane; arrivals take the field’s damage.',
 glasswind:'Concuss a caster, then cross under cover before its costly reply.',
 siltstream:'Tax the enemy crossing; use Haste to flank into spell range.',
 dawn_mist:'Cleanse your lead and cross spell lanes under half damage.',
 hearthstone:'Anchor a frontliner on the firing hex and heal it there.',
 lifeclay:'Ward a damaged caster, heal it, then answer from a stable lane.',
 sunstorm:'Blind the opposing caster; bank Flux for your next volley.',
 rainbow:'Take the extra step while healing your lead through the approach.',
 sungrass:'Use its speed and cover to take a firing lane first.',
 scaldshade:'Wither the target while its spells hit for less; set up a finisher.',
 cinderbog:'Bait or pull a foe onto the slow, burning arrival hex.',
 gravewater:'Cross the slow water, cleanse control, and press into spell range.',
 ashwing:'Use Haste to breach range; weigh that push against Burn’s HP cost.',
 rimeveil:'Blind a caster, then use the ice lane to close on its short reach.',
 dustveil:'Hold a slow, sheltered lane; make rivals attack across open ground.',
 ghostfire:'Form it under a foe for damage while your lead gains Clarity.',
 moonwell:'Put it under a spell-heavy foe; the Flux tax can price out a cast.',
 tombglass:'Wither a healer while cover lets your attacker keep the lane.',
 starless_wind:'Take Haste for a flank; use the Flux tax to weaken a reply.',
 weatherfront:'Form it beneath a foe for damage, then use Current to press forward.',
 sunforge:'Cleanse your lead, recover Flux, and keep the attack moving.',
 stormglass:'Cross under spell shelter; use cheap attacks while Flux is taxed.',
 brass_canopy:'Take the firing lane under cover and use Flux to sustain casts.',
 cloudgarden:'Heal the lead, then use Haste to close for a burst.',
 obsidian_mire:'Choke the crossing and shelter your flank from return fire.',
 black_squall:'Wither the target, then displace it across the hazardous route.',
 hollow_furnace:'Concuss a caster; form the field under a foe for first-hit damage.',
 peatstorm:'Slow the crossing and tax the Flux of a caster forced to hold it.',
 eclipse_spring:'Pressure the spring occupant with heat; occupy it for healing and Flux.',
 mourning_sun:'Wither the healer while Ward protects your advancing attacker.',
 stillwater:'Cleanse your lead, then use the ice lane to flank into range.',
 ghoststorm:'Blind a caster while spell shelter lets your front line close.',
 mooncurrent:'Cross the ice lane to flank; the Flux gain funds the next cast.',
 duskwood:'Own a spring: its extra return offsets the field’s Flux tax.',
 summerheart:'Take the extra step under healing and Ward to reach firing range.',
 black_weather:'Shelter your push; force the foe across hazard and Flux tax.',
 amber_vigil:'Anchor your frontliner against pulls; cleanse it before the attack.',
 dreaming_sky:'Trade reach for a healed, faster close-in attack.',
 nightglass:'Push or bait a foe onto the hazard while your lead uses the cover.',
 elder_grove:'Hold a spring with a frontliner; heal and refill before the next cast.',
 worldseed:'Use its one-exchange shelter to cleanse, advance, and fund the next volley.',
});
/** Uses and cautions follow the complete recipe, never add constituent pair effects. */
export function referenceMixtureTactics(field:CombinationDefinition){
 const m=field.mechanics,purposes:ReferencePurpose[]=[],cautions:string[]=[];
 if(m.cover||m.damageScale||m.statuses?.some(s=>['ward','clarity','anchored'].includes(s.id)))purposes.push('shelter');
 if(m.heal||m.cleanse)purposes.push('recovery');
 if(m.movement||m.statuses?.some(s=>s.id==='haste'))purposes.push('movement');
 if(m.hazard||m.statuses?.some(s=>['burn','wither'].includes(s.id)))purposes.push('pressure');
 if(m.statuses?.some(s=>CONTROL.has(s.id)))purposes.push('control');
 if(m.flux||m.wellBonus)purposes.push('flux');
 if(m.damageScale||m.cover)cautions.push('Also shelters enemies.');
 if(m.heal||m.cleanse)cautions.push('Also restores enemies.');
 if(m.hazard==='formed')cautions.push('Refreshing the same field does not retrigger damage.');
 if(m.hazard==='moved')cautions.push('Staying on the same hex avoids its hazard.');
 if(m.hazard==='always')cautions.push('Move or displace out before the exchange ends.');
 if(m.movement==='ice')cautions.push('Check the slide endpoint before entering.');
 if(m.flux===-1)cautions.push('Slower Flux recovery for either side.');
 if(m.statuses?.some(s=>s.id==='wither'))cautions.push('Wither weakens later healing.');
 if(m.statuses?.some(s=>CONTROL.has(s.id)))cautions.push('Clarity / Resolve blocks its control.');
 if(!cautions.length)cautions.push(m.wellBonus?'The spring bonus only helps an occupant.':'Either side can use its benefit.');
 return {purposes,pressure:PRESSURE_PLAYS[field.id]??'Shape the ground, then use its movement or status to set up a focused spell.',caution:cautions[0],details:cautions.slice(1),duration:field.mechanics.consume?'Disperses after this exchange.':'Formed fields last this exchange and the next unless changed or refreshed.'};
}

export type ReferenceForm=Spell['shape']|'self';
const FORM_RULES:Record<ReferenceForm,{name:string;use:string;caution:string;detail:string}>={
 hex:{name:'Precision',use:'One chosen hex.',caution:'A moving target can leave the aim.',detail:'Aim is fixed to ground. Precision tools keep their full direct effect on that hex.'},
 burst:{name:'Burst',use:'A filled area around the aim.',caution:'Check friends and the outer rim.',detail:'The aim is the centre, not a tracked fighter. The actual spell profile determines centre, inner and rim strength; terrain ingredients cover the whole area.'},
 ring:{name:'Ring',use:'Only the outer ring is hit.',caution:'The centre and inner hexes stay clear.',detail:'Targets must be exactly the listed radius from the aim. The empty centre is a usable pocket; the ring is not a filled burst.'},
 line:{name:'Line',use:'All unobstructed shortest rays to the aim.',caution:'Tied rays can hit more than one narrow lane.',detail:'The caster’s hex is excluded. Interior ruins, barriers and high ground can block a ray. Every tied shortest open ray contributes; the spell is not a single projectile-width trail.'},
 sweep:{name:'Fan',use:'A V-shaped footprint behind the aim.',caution:'Aim along one of the six straight hex directions.',detail:'The aim is the tip. Two arms extend back toward the caster’s side; the highlighted footprint shows exactly which hexes are hit.'},
 wall:{name:'Wall',use:'A barrier across an approach.',caution:'Occupied hexes and springs remain open.',detail:'Aim along a straight hex direction. The wall lies across that direction. A temporary barrier blocks movement and sight; it is not ordinary cover.'},
 self:{name:'Self',use:'Centred on the caster’s final landing.',caution:'Self aim does not always mean one hex.',detail:'Range 0 fixes the aim to the caster after movement. The spell can still use a burst or ring; inspect its actual footprint.'},
};
export function referenceFormRows(spellModel?:SpellModel){
 const spells=ALL_SPELLS.map(spell=>profileSpell(spell,spellModel));
 return (['hex','burst','ring','line','sweep','wall','self'] as const).map(id=>{
  const matching=spells.filter(spell=>(spell.range===0?'self':spell.shape)===id),example=matching.find(spell=>!spell.creatureId&&!spell.signatureChampionId)??matching[0];
  return {id,...FORM_RULES[id],count:matching.length,example,footprint:example?spellFootprintDescription(example):''};
 }).filter(row=>row.count>0);
}

/** Natural ground and timed elemental fields are separate layers in movementCost,
 * terrainCover and previewField. A biome ingredient is not an active field. */
export const REFERENCE_GROUND=[
 {id:'plain',name:'Open ground',movement:'1 effort',effect:'No natural ingredient.',detail:'A spell supplies the first ingredients. Ordinary movement costs 1 unless climbing or crossing an active field.'},
 {id:'water',name:'Natural water',movement:'1 effort',effect:'Water ingredient; no Wet or Flood yet.',detail:'A spell mixes with its Water. Magical liquid Water then slows entry and exit; freezing pure Water creates Ice. Natural water alone does not grant Wet.'},
 {id:'earth',name:'Raised earth',movement:'Climb: 2 effort',effect:'Earth ingredient; +1 reach toward lower ground.',detail:'Leaving height costs 1 unless another movement rule applies. Natural Earth is not magical Rough ground. A higher intervening hex can block sight; the board shows legal reach.'},
 {id:'forest',name:'Forest',movement:'1 effort',effect:'Earth ingredient; cover 1.',detail:'Forest absorbs 1 ordinary spell damage from the combined volley. Use the stronger of forest and field cover, not both. Piercing bypasses cover; spells change the surface without removing the natural biome.'},
 {id:'marsh',name:'Marsh',movement:'Enter: 2 effort',effect:'Water ingredient; no automatic Wet.',detail:'Leaving marsh costs 1 unless the destination or a field changes it. Marsh, climbing, Flood and Rough do not stack their costs; Ice entry costs 1.'},
 {id:'ruins',name:'Ruin / barrier',movement:'Blocked',effect:'Blocks sight; forced impact can hurt.',detail:'A forced step into solid terrain causes 1 environmental damage and Concussed, once per exchange. Ruins are permanent Earth terrain; temporary barriers can expire or be dispelled. Fighters and map edges do not cause this impact.'},
 {id:'spring',name:'Spring',movement:'Ground cost',effect:'+1 Flux after the exchange.',detail:'The living final occupant receives the bonus, up to maximum Flux. Some mixtures increase it to 2. Springs do not score victory points and cannot be blocked by a raised barrier.'},
] as const;

export function referenceSpellSummary(spell:Spell):string {
 const parts:string[]=[];
 if(spell.damage)parts.push(`${spell.damage}${spell.pierce?' piercing':''} damage`);
 if(spell.heal)parts.push(`Heal ${spell.heal}`);
 if(spell.push)parts.push(`${spell.push>0?'Push':'Pull'} ${Math.abs(spell.push)}`);
 if(spell.wall)parts.push('Barrier');
 if(spell.freeze)parts.push('Freeze Water');
 if(spell.cleanse)parts.push('Cleanse');
 if(spell.dispel)parts.push('Remove barrier');
 if(spell.recharge)parts.push(`+${spell.recharge} Flux`);
 if(spell.steal)parts.push(`Steal ${spell.steal} Flux`);
 if(spell.drain)parts.push(`Drain ${spell.drain}`);
 for(const status of [...(spell.harmful??[]),...(spell.friendly??[]),...(spell.self??[])]){const label=statusName(status.id);if(!parts.includes(label))parts.push(label);}
 if(spell.selfDamage)parts.push(`Self −${spell.selfDamage} HP`);
 return parts.join(' · ')||'Creates a field';
}

export function referenceSpellRow(base:Spell,caster?:ReferenceCaster,spellModel?:SpellModel){
 const effective=profileSpell(caster?effectiveSpell(caster.championId,base.id,caster.affinities):base,spellModel);
 const spell=caster?.statuses?.concussed||caster?.statuses?.blind?{...effective,cost:effective.cost+Number(!!caster.statuses.concussed),range:effective.range===0?0:Math.max(1,effective.range-Number(!!caster.statuses.blind))}:effective;
 const access=caster?.creatureId?{unlocked:getCreature(caster.creatureId).loadout.includes(base.id),requiredAffinity:base.level,level:base.level,branch:base.branch,...(!getCreature(caster.creatureId).loadout.includes(base.id)?{reason:'Creature spell kits are fixed.'}:{})}:caster?spellAccess(caster.championId,base.id,caster.affinities,caster.learnedSpells??[]):null;
 const origin=spellOrigin(base.id);
 return {spell:{...spell,description:profiledSpellDescription(spell)},origin,access,requiredAffinity:access?.requiredAffinity??base.level,summary:spell.focus?profiledEffectLabel(spell):referenceSpellSummary(spell),area:spellFootprintDescription(spell),friendlyFire:!!spell.push||spell.harm==='all'&&!!(spell.damage||spell.harmful?.length)};
}

export type SpellReferenceFilter={query?:string;element?:Element|'all';level?:number;source?:'all'|'standard'|'champion'|'creature';spellIds?:readonly string[]};
export function filterReferenceSpells(filter:SpellReferenceFilter={},spellModel?:SpellModel):Spell[]{
 const query=(filter.query??'').trim().toLocaleLowerCase(),ids=filter.spellIds?new Set(filter.spellIds):null;
 return ALL_SPELLS.filter(spell=>{
  if(ids&&!ids.has(spell.id)||filter.element&&filter.element!=='all'&&spell.element!==filter.element||filter.level&&spell.level!==filter.level)return false;
  if(filter.source==='standard'&&(spell.signatureChampionId||spell.creatureId)||filter.source==='champion'&&!spell.signatureChampionId||filter.source==='creature'&&!spell.creatureId)return false;
  if(!query)return true;
  const origin=spellOrigin(spell.id);
  const current=profileSpell(spell,spellModel);
  return [current.name,current.element,current.branch,profiledSpellDescription(current),spellFootprintDescription(current),origin?.name??'',referenceSpellSummary(current)].join(' ').toLocaleLowerCase().includes(query);
 }).sort((a,b)=>ELEMENT_ORDER.indexOf(a.element)-ELEMENT_ORDER.indexOf(b.element)||a.level-b.level||a.name.localeCompare(b.name));
}
export function filterReferenceInteractions(filter:{query?:string;element?:Element|'all';size?:number;purpose?:ReferencePurpose|'all'}={}):CombinationDefinition[]{
 const query=(filter.query??'').trim().toLocaleLowerCase();
 return REFERENCE_INTERACTIONS.filter(field=>(!filter.element||filter.element==='all'||field.elements.includes(filter.element))&&(!filter.size||field.elements.length===filter.size)&&(!filter.purpose||filter.purpose==='all'||referenceMixtureTactics(field).purposes.includes(filter.purpose))&&(!query||[field.name,field.elements.map(elementName).join(' '),field.description,field.shortRule].join(' ').toLocaleLowerCase().includes(query))).sort((a,b)=>a.elements.length-b.elements.length||a.name.localeCompare(b.name));
}
