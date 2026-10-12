extends RefCounted

# Situational identity passives use the existing action and resource state.
# Ratios are per mille, not added percentage points. Runtime owns all gates,
# positive payment floors, duration rounding, and combined-effect clamps.
const APEX_GUIDE := "https://help.ea.com/en/articles/apex-legends/abilities/"
const HORIZON := APEX_GUIDE
const REVENANT := APEX_GUIDE
const TITANFALL := "https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right"
const APEX_BALANCE := "https://www.ea.com/games/apex-legends/apex-legends/news/28-1-designers-notes"

const ORDER: Array[String] = [
	"human", "dwarf", "gnome", "hobbit", "elf", "orc", "troll", "minotaur",
	"seakin", "wyrmborn", "stoneborn", "treefolk", "sylph", "undead", "goblin",
	"nymph", "spiderkin", "vampire", "demon", "angel", "werewolf",
]

const ANCESTRY_BY_WIRE: Array[String] = [
	"", "seakin", "hobbit", "undead", "sylph", "goblin", "goblin",
	"treefolk", "werewolf", "orc", "gnome", "demon", "treefolk", "wyrmborn",
	"stoneborn", "nymph", "elf", "troll", "dwarf", "human", "minotaur",
	"stoneborn", "dwarf", "vampire", "spiderkin", "demon", "angel", "orc",
	"stoneborn", "treefolk", "nymph",
]

const DEFINITIONS: Dictionary = {
	"human": {
		"id": "race_measured_pace", "ancestry": "human", "name": "Measured Pace",
		"summary": "Walking recovers Flux and Stamina 10% faster after their normal delays.",
		"condition": "grounded_walking", "effects": {"flux_recovery_ratio": 1100, "stamina_recovery_ratio": 1100},
		"window": "Ordinary grounded walking; no sprint, crouch or authored movement.",
		"counter": "Chase or force evasions to end the walking recovery window.", "reference": APEX_BALANCE,
	},
	"dwarf": {
		"id": "race_low_bastion", "ancestry": "dwarf", "name": "Low Bastion",
		"summary": "Crouch takes 7% less damage and 15% less knockback, but moves 10% slower.",
		"condition": "grounded_crouching", "effects": {"incoming_damage_ratio": 930, "knockback_ratio": 850, "ground_speed_ratio": 900},
		"window": "Grounded crouch only; sliding does not count.",
		"counter": "Ground hazards still hit crouch; pressure its slower exit.", "reference": REVENANT,
	},
	"gnome": {
		"id": "race_charged_focus", "ancestry": "gnome", "name": "Charged Focus",
		"summary": "High Flux starts casts 10% faster; that spell's cooldown is 10% longer if Flux stays high at release.",
		"condition": "high_flux", "effects": {"spell_startup_ratio": 900, "spell_cooldown_ratio": 1100},
		"window": "Startup checks two-thirds Flux before payment; that spell's cooldown checks the threshold at release. Both timing changes require a real whole-tick difference; otherwise neither applies to that spell.",
		"counter": "Bait the quicker opening, then contest the longer wait before that spell can repeat.", "reference": APEX_GUIDE,
	},
	"hobbit": {
		"id": "race_last_step", "ancestry": "hobbit", "name": "Last Step",
		"summary": "At one-third Stamina or less, movement actions cost 10% less; take 5% more damage.",
		"condition": "low_stamina", "effects": {"movement_cost_ratio": 900, "incoming_damage_ratio": 1050},
		"window": "Stamina at or below one-third full; each action still needs positive payment.",
		"counter": "Punish a failed escape while its reserve is low.", "reference": APEX_GUIDE,
	},
	"elf": {
		"id": "race_passing_rhythm", "ancestry": "elf", "name": "Passing Rhythm",
		"summary": "Walking accelerates 15% faster, but casts begun while walking start 10% slower.",
		"condition": "grounded_walking", "effects": {"ground_acceleration_ratio": 1150, "spell_startup_ratio": 1100},
		"window": "Ordinary grounded walking, outside sprint and authored movement.",
		"counter": "Read the walking lane and contest the slower moving cast.", "reference": TITANFALL,
	},
	"orc": {
		"id": "race_iron_nerve", "ancestry": "orc", "name": "Iron Nerve",
		"summary": "During cast startup, take 7% less damage but walk 10% slower.",
		"condition": "pending_cast", "effects": {"incoming_damage_ratio": 930, "ground_speed_ratio": 900},
		"window": "An accepted paid cast is still in startup; not its recovery or released projectile.",
		"counter": "Reposition around the slower caster and punish the recovery.", "reference": APEX_GUIDE,
	},
	"troll": {
		"id": "race_resting_mend", "ancestry": "troll", "name": "Resting Mend",
		"summary": "Standing still on ground heals 20% faster but recovers Flux 10% slower.",
		"condition": "stationary_grounded", "effects": {"health_recovery_ratio": 1200, "flux_recovery_ratio": 900},
		"window": "Grounded at rest after normal recovery delays; no forced movement or jumpsquat.",
		"counter": "Maintain contact damage or force a reposition to stop the benefit.", "reference": APEX_GUIDE,
	},
	"minotaur": {
		"id": "race_committed_stride", "ancestry": "minotaur", "name": "Committed Stride",
		"summary": "Sprinting takes 15% less knockback, but brakes 15% more slowly.",
		"condition": "sprinting", "effects": {"knockback_ratio": 850, "ground_braking_ratio": 850},
		"window": "An actually paid sprint, not a held key with insufficient Stamina.",
		"counter": "Step across its committed route or place a hazard near its stopping point.", "reference": TITANFALL,
	},
	"seakin": {
		"id": "race_slipstream_cast", "ancestry": "seakin", "name": "Slipstream Cast",
		"summary": "During a slide, casts start 10% faster but incoming damage rises 5%.",
		"condition": "sliding", "effects": {"spell_startup_ratio": 900, "incoming_damage_ratio": 1050},
		"window": "Active paid slide only; ordinary crouch and wavedash do not count.",
		"counter": "Cover the predictable sliding lane with ground effects.", "reference": TITANFALL,
	},
	"wyrmborn": {
		"id": "race_descending_scales", "ancestry": "wyrmborn", "name": "Descending Scales",
		"summary": "While falling, take 5% less damage but steer in air 10% more slowly.",
		"condition": "airborne_descending", "effects": {"incoming_damage_ratio": 950, "air_steering_ratio": 900},
		"window": "Actually airborne and descending; excludes wallrun and held flight.",
		"counter": "Anticipate the less flexible landing route; height grants no new immunity.", "reference": HORIZON,
	},
	"stoneborn": {
		"id": "race_gathering_weight", "ancestry": "stoneborn", "name": "Gathering Weight",
		"summary": "Held jump preparation takes 5% less damage and 15% less knockback, but loses momentum 20% faster.",
		"condition": "jumpsquat", "effects": {"incoming_damage_ratio": 950, "knockback_ratio": 850, "ground_braking_ratio": 1200},
		"window": "Grounded held jump preparation only; a complete instant tap has no preparation tick.",
		"counter": "Use the slowing grounded target's exposure; release ends the defense.", "reference": APEX_GUIDE,
	},
	"treefolk": {
		"id": "race_deep_reserve", "ancestry": "treefolk", "name": "Deep Reserve",
		"summary": "At one-third Flux or less, recover Flux 20% faster but walk 10% slower.",
		"condition": "low_flux", "effects": {"flux_recovery_ratio": 1200, "ground_speed_ratio": 900},
		"window": "Flux at or below one-third; normal recovery delay and suppression still apply.",
		"counter": "Pressure the retreat before the reserve recovers.", "reference": APEX_GUIDE,
	},
	"sylph": {
		"id": "race_rising_current", "ancestry": "sylph", "name": "Rising Current",
		"summary": "While rising, air steering is 15% stronger; movement actions cost 10% more.",
		"condition": "airborne_rising", "effects": {"air_steering_ratio": 1150, "movement_cost_ratio": 1100},
		"window": "Positive airborne vertical velocity; not stationary flight or wallrun.",
		"counter": "Track the descent and pressure the more expensive follow-up.", "reference": HORIZON,
	},
	"undead": {
		"id": "race_stubborn_ember", "ancestry": "undead", "name": "Stubborn Ember",
		"summary": "At one-third Health or less, heal 20% faster but recover Flux 15% slower.",
		"condition": "low_health", "effects": {"health_recovery_ratio": 1200, "flux_recovery_ratio": 850},
		"window": "Health at or below one-third; damage still restarts the normal healing delay.",
		"counter": "Keep pressure on the wounded target before regeneration starts.", "reference": APEX_GUIDE,
	},
	"goblin": {
		"id": "race_exit_burst", "ancestry": "goblin", "name": "Exit Burst",
		"summary": "During cast recovery, ground acceleration is 20% stronger but braking is 15% weaker.",
		"condition": "cast_recovery", "effects": {"ground_acceleration_ratio": 1200, "ground_braking_ratio": 850},
		"window": "The existing cast-recovery timer; it neither shortens recovery nor adds speed above the usual target.",
		"counter": "Read the faster departure and bait an overshoot.", "reference": APEX_GUIDE,
	},
	"nymph": {
		"id": "race_unbroken_flow", "ancestry": "nymph", "name": "Unbroken Flow",
		"summary": "At least three-quarters Health: recover Flux 15% faster but take 5% more damage.",
		"condition": "high_health", "effects": {"flux_recovery_ratio": 1150, "incoming_damage_ratio": 1050},
		"window": "Health at or above three-quarters; Flux recovery still waits its normal delay.",
		"counter": "A clean hit both exploits the vulnerability and can break the recovery window.", "reference": APEX_GUIDE,
	},
	"spiderkin": {
		"id": "race_wall_weaver", "ancestry": "spiderkin", "name": "Wall Weaver",
		"summary": "Movement exits from wallrun cost 15% less, but wallrunning takes 10% more damage.",
		"condition": "wallrunning", "effects": {"movement_cost_ratio": 850, "incoming_damage_ratio": 1100},
		"window": "An active paid wallrun; initial attachment and wallrun sustain keep their normal costs.",
		"counter": "Cover the exposed wall lane before its discounted exit.", "reference": REVENANT,
	},
	"vampire": {
		"id": "race_held_vigor", "ancestry": "vampire", "name": "Held Vigor",
		"summary": "At least two-thirds Stamina: heal 15% faster but recover Stamina 15% slower.",
		"condition": "high_stamina", "effects": {"health_recovery_ratio": 1150, "stamina_recovery_ratio": 850},
		"window": "Stamina at or above two-thirds; normal healing delay remains.",
		"counter": "Force repeated movement spending to break its healing reserve.", "reference": APEX_GUIDE,
	},
	"demon": {
		"id": "race_last_air_gambit", "ancestry": "demon", "name": "Last Air Gambit",
		"summary": "After a completed air dodge, airborne casts start 10% faster; airborne release adds 15% to that spell's cooldown.",
		"condition": "airborne_spent_dodge", "effects": {"spell_startup_ratio": 900, "spell_cooldown_ratio": 1150},
		"window": "Dodge timer must have ended. Startup checks airborne spent dodge at admission; that spell's cooldown checks again at release. Landing clears it. Both timing changes require a real whole-tick difference; otherwise neither applies to that spell.",
		"counter": "Contest the longer wait for that spell when a second dodge is unavailable.", "reference": APEX_GUIDE,
	},
	"angel": {
		"id": "race_poised_wings", "ancestry": "angel", "name": "Poised Wings",
		"summary": "During paid held flight, take 5% less damage but steer 10% more slowly.",
		"condition": "flight_active", "effects": {"incoming_damage_ratio": 950, "air_steering_ratio": 900},
		"window": "Flight must actually be active and paid; release, exhaustion and expiry end it.",
		"counter": "Aim at the less responsive flight path and contest the finite landing.", "reference": HORIZON,
	},
	"werewolf": {
		"id": "race_wounded_stride", "ancestry": "werewolf", "name": "Wounded Stride",
		"summary": "At one-third Health or less, ground speed rises 8% but incoming damage rises 5%.",
		"condition": "low_health", "effects": {"ground_speed_ratio": 1080, "incoming_damage_ratio": 1050},
		"window": "Health at or below one-third; affects ordinary ground targets, never paid impulse speed.",
		"counter": "Anticipate the escape route; a caught retreat is more vulnerable.", "reference": APEX_GUIDE,
	},
}


static func definition(ancestry: String) -> Dictionary:
	return Dictionary(DEFINITIONS.get(ancestry, {})).duplicate(true)


static func raw_definition(ancestry: String) -> Dictionary:
	# Internal policy read only. Public consumers use definition()/all() copies.
	return DEFINITIONS.get(ancestry, {})


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ancestry: String in ORDER:
		result.append(definition(ancestry))
	return result


static func ancestry_for_wire(wire: int) -> String:
	return ANCESTRY_BY_WIRE[wire] if wire > 0 and wire < ANCESTRY_BY_WIRE.size() else ""
