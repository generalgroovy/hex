extends RefCounted

# Character identity augments the separate race passive through existing state.
# These are bounded H.E.X. design adaptations, not imported balance claims.
# Runtime owns condition truth, positive payment, delay gates and combined caps.
const APEX := "https://help.ea.com/en/articles/apex-legends/abilities/"
const GUNGEON := "https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-"
const TITANFALL := "https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right"

# Stable current champion order. Every row uses a distinct condition/effect
# signature; changing a percentage alone is not a new perk identity.
const ROWS: Array[Dictionary] = [
	{"champion_id":"oh_tipi", "name":"Current Anchor", "condition":"grounded_walking&high_flux", "effects":{"ground_braking_ratio":1200,"ground_acceleration_ratio":900}, "window":"Walking with at least two-thirds Flux.", "counter":"Stops decisively but builds speed slowly; make the current keeper change lanes.", "reference":TITANFALL},
	{"champion_id":"s_wayne", "name":"Shadow Budget", "condition":"grounded_walking&low_flux", "effects":{"flux_recovery_ratio":1150,"ground_speed_ratio":950}, "window":"Walking with at most one-third Flux, after its normal recovery delay.", "counter":"A measured retreat restores spells but gives a pursuer time to close.", "reference":APEX},
	{"champion_id":"red_baron", "name":"Last Redoubt", "condition":"grounded_crouching", "effects":{"incoming_damage_ratio":900,"health_recovery_ratio":850}, "window":"Grounded crouch; not slide, air or jump preparation.", "counter":"Damage remains real and healing slows; persistent ground pressure forces the Baron out.", "reference":APEX},
	{"champion_id":"grace_reava", "name":"Falling Ribbon", "condition":"airborne_descending&high_flux", "effects":{"air_steering_ratio":1200,"spell_cooldown_ratio":1100}, "window":"Descending with at least two-thirds Flux; wallrun and held flight do not count. Spell cooldown samples release.", "counter":"Grace shapes a landing, but a spell released here waits longer before that same spell can repeat.", "reference":APEX},
	{"champion_id":"wa_bidi", "name":"Scrap Spark", "condition":"sprinting&low_flux", "effects":{"spell_startup_ratio":850,"spell_cooldown_ratio":1150}, "window":"A paid sprint with at most one-third Flux; startup samples admission, spell cooldown samples release.", "counter":"A quicker low-reserve opening delays that spell's next use if released in the same window; bait it.", "reference":GUNGEON},
	{"champion_id":"steezo", "name":"Slide Encore", "condition":"sliding&high_stamina", "effects":{"spell_cooldown_ratio":850,"incoming_damage_ratio":1100}, "window":"Active paid slide with at least two-thirds Stamina. Spell cooldown samples release.", "counter":"A sliding release lets that spell repeat sooner, but ground hits hurt more; cover the travel lane.", "reference":TITANFALL},
	{"champion_id":"treevor_mason", "name":"Mason's Stance", "condition":"stationary_grounded&high_flux", "effects":{"knockback_ratio":850,"spell_startup_ratio":1100}, "window":"At rest on the ground with at least two-thirds Flux.", "counter":"Rooted footing resists displacement, but slower startup invites a flank or interruption.", "reference":APEX},
	{"champion_id":"oll_i", "name":"Cornered Bound", "condition":"grounded_walking&low_health", "effects":{"ground_acceleration_ratio":1200,"ground_braking_ratio":850}, "window":"Ordinary walking with at most one-third Health.", "counter":"A wounded escape changes pace quickly but needs more room to stop.", "reference":TITANFALL},
	{"champion_id":"fluup", "name":"Patient Reserve", "condition":"grounded_walking&high_stamina", "effects":{"movement_cost_ratio":900,"spell_startup_ratio":1100}, "window":"Walking with at least two-thirds Stamina before an action.", "counter":"Careful footwork buys cheaper paid movement, while slower spells surrender initiative.", "reference":GUNGEON},
	{"champion_id":"nico_lai", "name":"Quiet Circuit", "condition":"stationary_grounded&low_flux", "effects":{"flux_recovery_ratio":1200,"stamina_recovery_ratio":900}, "window":"At rest with at most one-third Flux; normal recovery delays apply.", "counter":"Recharging Flux slows Stamina recovery; force Waka Aren Si to relocate.", "reference":APEX},
	{"champion_id":"spai_si", "name":"Rising Feint", "condition":"airborne_rising&high_flux", "effects":{"spell_startup_ratio":850,"air_steering_ratio":900}, "window":"Ascending with at least two-thirds Flux.", "counter":"The fast aerial release commits to a less adjustable ascent; read the lane.", "reference":APEX},
	{"champion_id":"leaf_hidden", "name":"Sheltered Sap", "condition":"stationary_grounded&low_health", "effects":{"health_recovery_ratio":1200,"spell_startup_ratio":1100}, "window":"At rest with at most one-third Health, after the normal healing delay.", "counter":"Shelter improves existing healing but slows a defensive cast; maintain pressure.", "reference":APEX},
	{"champion_id":"ha_rekt", "name":"Spent-Wing Rudder", "condition":"airborne_descending&low_stamina", "effects":{"air_steering_ratio":1150,"incoming_damage_ratio":1100}, "window":"Descending with at most one-third Stamina, outside held flight and wallrun.", "counter":"A tired descent can steer, but aerial hits punish it more strongly.", "reference":APEX},
	{"champion_id":"dr_apex", "name":"Counterweight", "condition":"jumpsquat&high_stamina", "effects":{"incoming_damage_ratio":900,"ground_braking_ratio":900}, "window":"Held grounded jump preparation with at least two-thirds Stamina.", "counter":"Preparation resists damage while retaining more drift; contest the predicted takeoff.", "reference":APEX},
	{"champion_id":"haara", "name":"Sunlit Pace", "condition":"grounded_walking&high_health", "effects":{"flux_recovery_ratio":1100,"ground_braking_ratio":900}, "window":"Ordinary walking with at least three-quarters Health; normal Flux delay remains.", "counter":"Healthy pacing sustains spells but stops less sharply; chip damage ends the benefit.", "reference":APEX},
	{"champion_id":"hesus_christo", "name":"Grounded Reprise", "condition":"landing&high_flux", "effects":{"ground_acceleration_ratio":1200,"movement_cost_ratio":1100}, "window":"The existing grounded landing window with at least two-thirds Flux.", "counter":"A brisk landing exit costs more for paid follow-ups; read the landing and force another evasion.", "reference":APEX},
	{"champion_id":"grimm_bow", "name":"Second Breath", "condition":"grounded_walking&low_stamina", "effects":{"stamina_recovery_ratio":1200,"flux_recovery_ratio":900}, "window":"Walking with at most one-third Stamina, after ordinary recovery waits.", "counter":"Grimm regains movement before spells; pressure while the spell reserve lags.", "reference":APEX},
	{"champion_id":"biggy_bob", "name":"Low Bellows", "condition":"grounded_crouching&low_flux", "effects":{"spell_startup_ratio":850,"spell_cooldown_ratio":1150}, "window":"Grounded crouch with at most one-third Flux; startup samples admission, spell cooldown samples release.", "counter":"A quick low cast delays that spell's next use if released crouched and low; contest the ground.", "reference":GUNGEON},
	{"champion_id":"jan_wicked", "name":"Measured Exit", "condition":"cast_recovery&grounded", "effects":{"incoming_damage_ratio":900,"stamina_recovery_ratio":850}, "window":"Grounded during the existing cast recovery window.", "counter":"Jan softens a return hit but rebuilds movement reserve slowly; sustain the pursuit.", "reference":GUNGEON},
	{"champion_id":"ba_djoh", "name":"Open-Lane Charge", "condition":"sprinting&high_stamina", "effects":{"ground_speed_ratio":1100,"ground_braking_ratio":850}, "window":"A successfully paid sprint with at least two-thirds Stamina.", "counter":"The first stretch is fast but committed; sidestep or place ground denial at the stopping point.", "reference":TITANFALL},
	{"champion_id":"urzh", "name":"Weighted Resolve", "condition":"grounded&slowed", "effects":{"incoming_damage_ratio":900,"spell_startup_ratio":1150}, "window":"Grounded under an actual timed slow; terrain colour alone does not qualify.", "counter":"A slowed Urzh is tougher but casts more deliberately; take another angle.", "reference":APEX},
	{"champion_id":"donnok", "name":"Set the Anvil", "condition":"stationary_grounded&high_stamina", "effects":{"spell_cooldown_ratio":850,"spell_startup_ratio":1100}, "window":"At rest with at least two-thirds Stamina; startup samples admission, spell cooldown samples release.", "counter":"A prepared spell starts later but can repeat sooner after a settled release; pressure the initial tell.", "reference":GUNGEON},
	{"champion_id":"djonah_thaan", "name":"Retreating Hunger", "condition":"retreating_grounded", "effects":{"flux_recovery_ratio":1150,"ground_acceleration_ratio":850}, "window":"Ordinary grounded movement away from the aim direction, after the normal Flux delay.", "counter":"Djonah can watch a pursuer while recovering spells, but changes escape speed slowly.", "reference":TITANFALL},
	{"champion_id":"luuh_i_zeh", "name":"Wall Thread", "condition":"wallrunning&low_flux", "effects":{"flux_recovery_ratio":1150,"incoming_damage_ratio":1100}, "window":"An attached paid wallrun with at most one-third Flux; normal recovery delay remains.", "counter":"The wall route can rebuild spell reserve but exposes a more vulnerable silhouette.", "reference":TITANFALL},
	{"champion_id":"juul_i_yaina", "name":"Last Ember Step", "condition":"airborne_spent_dodge&low_stamina", "effects":{"movement_cost_ratio":850,"knockback_ratio":1150}, "window":"Airborne after your air dodge has finished, with at most one-third Stamina.", "counter":"Legal remaining movements cost less but pushes carry farther; no dodge or flight budget resets.", "reference":APEX},
	{"champion_id":"faab_i_yaina", "name":"Steady Descent", "condition":"airborne_descending&high_health", "effects":{"incoming_damage_ratio":900,"air_steering_ratio":900}, "window":"Descending with at least three-quarters Health, outside held flight and wallrun.", "counter":"The healthy descent is resilient but predictable; contest the landing or chip away the window.", "reference":APEX},
	{"champion_id":"joh_haynes", "name":"Unbroken Bearing", "condition":"impact_recovery", "effects":{"knockback_ratio":850,"flux_recovery_ratio":850}, "window":"During existing forced impact recovery; the first impact is unchanged.", "counter":"Repeated pushes move Joh less, but Flux recovery slows; damage and control duration remain real.", "reference":APEX},
	{"champion_id":"h_le_ne", "name":"Quiet Facet", "condition":"grounded_crouching&high_flux", "effects":{"spell_cooldown_ratio":850,"stamina_recovery_ratio":900}, "window":"Grounded crouch with at least two-thirds Flux; spell cooldown samples release.", "counter":"A low, stocked release lets that spell repeat sooner but rebuilds evasions slowly.", "reference":GUNGEON},
	{"champion_id":"fimu_yashiha", "name":"Landing Dew", "condition":"landing&low_flux", "effects":{"flux_recovery_ratio":1200,"ground_acceleration_ratio":900}, "window":"The existing grounded landing window with at most one-third Flux, after normal delay.", "counter":"A settled landing briefly speeds Flux recovery but has a slower ground exit.", "reference":APEX},
	{"champion_id":"sai_laas", "name":"Bright Rush", "condition":"sprinting&high_flux", "effects":{"spell_startup_ratio":900,"incoming_damage_ratio":1100}, "window":"A paid sprint with at least two-thirds Flux when starting a spell.", "counter":"A stocked rush releases promptly but takes stronger return hits; make Sai commit across cover.", "reference":GUNGEON},
]

const EFFECT_LABELS := {
	"ground_speed_ratio":"ground speed", "ground_acceleration_ratio":"accel",
	"ground_braking_ratio":"braking", "air_steering_ratio":"air steer",
	"incoming_damage_ratio":"damage taken", "knockback_ratio":"push taken",
	"health_recovery_ratio":"Health regen", "flux_recovery_ratio":"Flux regen",
	"stamina_recovery_ratio":"Stamina regen", "movement_cost_ratio":"move cost",
	"spell_startup_ratio":"cast startup", "spell_cooldown_ratio":"spell cooldown",
}
const CONDITION_LABELS := {
	"grounded_walking":"Walking", "grounded_crouching":"Crouched", "stationary_grounded":"At rest",
	"airborne_descending":"Falling", "airborne_rising":"Rising", "wallrunning":"Wallrun",
	"landing":"Landing", "jumpsquat":"Jump prep", "sprinting":"Sprinting", "sliding":"Sliding",
	"grounded":"Grounded", "retreating_grounded":"Walking away from aim",
	"low_health":"Health<=1/3", "high_health":"Health>=3/4", "low_flux":"Flux<=1/3", "high_flux":"Flux>=2/3",
	"low_stamina":"Stamina<=1/3", "high_stamina":"Stamina>=2/3", "cast_recovery":"Post-cast",
	"impact_recovery":"Impact recovery", "slowed":"Slowed", "airborne_spent_dodge":"Airborne, dodge finished",
}


static func raw_definition(wire: int) -> Dictionary:
	return ROWS[wire - 1] if wire >= 1 and wire <= ROWS.size() else {}


static func definition(wire: int) -> Dictionary:
	if wire < 1 or wire > ROWS.size(): return {}
	var result: Dictionary = ROWS[wire - 1].duplicate(true)
	result.wire_id = wire
	result.id = "character_" + String(result.champion_id)
	var paired_timing: bool = result.effects.has("spell_startup_ratio") and result.effects.has("spell_cooldown_ratio")
	var changes: Array[String] = []
	for effect: String in result.effects:
		var amount := (int(result.effects[effect]) - 1000) / 10.0
		var label := String(EFFECT_LABELS[effect])
		if paired_timing: label = "startup" if effect=="spell_startup_ratio" else "cooldown"
		changes.append("%s %s%.0f%%" % [label, "+" if amount > 0 else "", amount])
	var windows: Array[String] = []
	for token: String in String(result.condition).split("&"):
		windows.append(String(CONDITION_LABELS.get(token, token)))
	result.summary = ", ".join(windows) + ": " + "; ".join(changes) + "."
	if paired_timing:
		result.summary += " Both clocks must change."
		result.window += " Both changes require a real whole-tick difference; otherwise neither applies to that spell."
	return result


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wire: int in range(1, ROWS.size() + 1): result.append(definition(wire))
	return result


static func mechanical_signature(row: Dictionary) -> String:
	# Ignore authored numbers: two identically triggered mechanisms with only
	# a different percentage are duplicates, even if their names differ.
	var effects: Array[String] = []
	for key: String in row.get("effects", {}): effects.append(key)
	effects.sort()
	var conditions := String(row.get("condition", "")).split("&")
	conditions.sort()
	return "&".join(conditions) + ":" + ",".join(effects)
