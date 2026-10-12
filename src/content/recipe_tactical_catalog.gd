extends RefCounted
## Read-only decisions derived from the resolved runtime recipe and spell
## tables. Scenario prompts are evaluation instructions, not balance results.

const StatusText = preload("res://src/content/spell_status_catalog.gd")
const SINGLE_PAIR_TRIGGERS := {
	301:"contact", 302:"pulse", 303:"dwell", 304:"contact", 307:"contact",
	308:"pulse", 309:"pulse", 310:"heat_exposure", 311:"activation", 314:"activation",
	315:"fuse", 316:"contact", 317:"pulse", 320:"moving", 321:"exit",
	322:"pulse", 325:"contact", 326:"alternating", 334:"pulse", 335:"crossing", 336:"dwell",
}
const TRIGGER_LABELS := {
	"contact":"Contact creates one hit per actor", "pulse":"Pressure repeats on its paid pulse clock",
	"dwell":"Staying inside enables pressure", "heat_exposure":"Heat and exposure control scald pressure",
	"activation":"One burst after formation", "fuse":"One burst after the visible fuse",
	"moving":"Movement exposes the target to pulses", "exit":"A grounded exit triggers the hit",
	"alternating":"Danger alternates with clear intervals", "crossing":"One boundary-crossing hit per actor",
}
const TEST_ACTIONS := {
	"contact":"Enter once, leave, then re-enter with the same actor; compare damage events.",
	"pulse":"Cross the marked cells between pulses, then repeat while staying inside.",
	"dwell":"Leave before the stated exposure delay; compare with remaining inside beyond it.",
	"heat_exposure":"Compare the same paid Steam field before and after one fresh Water cooling shot.",
	"activation":"Leave during formation; compare with remaining on the marked footprint at activation.",
	"fuse":"Leave during the transparent final warning; compare with staying until detonation.",
	"moving":"Compare a stationary occupant with one moving inside the same active footprint.",
	"exit":"Compare a grounded exit with an ordinary paid jump out of the footprint.",
	"alternating":"Cross during a clear interval, then compare the same route during a concealing interval.",
	"crossing":"Compare the safe center with a boundary crossing; repeat with the same actor.",
}
const IDENTITY_FIELDS := ["wire_id", "id", "name", "elements", "ingredient_layers", "product_layer",
	"archive_recipe_wire", "visual_material", "element_mask", "arity", "purpose", "counter"]


static func definition(mask: int) -> Dictionary:
	if mask < 1 or mask > 63: return {}
	var mixture := MixtureCatalog.definition(mask)
	if mixture.is_empty(): return {}
	var recipe := HexRecipePolicy.definition(int(mixture.reaction_wire_id))
	if recipe.is_empty(): return {}
	var trigger := String(recipe.get("trigger", SINGLE_PAIR_TRIGGERS.get(int(recipe.wire_id), "")))
	if not TRIGGER_LABELS.has(trigger): return {}
	var deliveries: Array[Dictionary] = []
	for family: String in MixtureCatalog.FAMILIES:
		var wire := MixtureCatalog.wire_for(mask, family)
		var compiled := CombatTuning.cast_definition_view(wire)
		if compiled.is_empty(): return {}
		deliveries.append({"family":family, "wire_id":wire, "flux_cost":int(compiled.flux_cost),
			"direct_damage_quote":int(compiled.damage), "reaction_strength":int(compiled.reaction_strength),
			"startup_ticks":SimConfig.new().milliseconds_to_ticks(int(compiled.startup_ms)),
			"cooldown_ticks":SimConfig.new().milliseconds_to_ticks(int(compiled.cooldown_ms)),
			"status_ticks":SimConfig.new().milliseconds_to_ticks(int(compiled.status_duration_ms))})
	var mechanics := _mechanics(recipe)
	var environment := "Marked open ground"
	match String(recipe.selection_kind):
		"capsule", "sector": environment = "A readable lane or corridor with a lateral exit"
		"annulus": environment = "An open center with a visible dangerous boundary"
	if int(recipe.get("health", 0)) > 0:
		environment = "A firing lane with room to go around or break the temporary structure"
	return {"element_mask":mask, "name":String(mixture.display_name), "reaction_name":String(recipe.name),
		"recipe_wire_id":int(recipe.wire_id), "ingredient_count":mixture.elements.size(),
		"headline":String(recipe.purpose), "counter":String(recipe.counter),
		"trigger":trigger, "trigger_label":String(TRIGGER_LABELS[trigger]),
		"environment":environment, "footprint":String(recipe.selection_kind),
		"ground_only":bool(recipe.ground_only), "formation_ticks":int(recipe.formation_ticks),
		"active_ticks":int(recipe.active_ticks), "decay_ticks":int(recipe.decay_ticks),
		"direct_hit_statuses":StatusText.rows_for_mask(mask), "deliveries":deliveries,
		"mechanical_signature":CanonicalContent.sha256(mechanics), "mechanics":mechanics,
		"simpler_comparisons":_simpler_comparisons(mask, recipe),
		"counter_scenario":{"id":"recipe_%02d_%s" % [mask,trigger], "action":String(TEST_ACTIONS[trigger]),
			"observation":"Use ordinary paid casts; record real damage, movement, exposure, and remaining resources.",
			"status":"proposed_evaluation_not_executed_result"},
		"reference":String(mixture.reference),
		"reference_scope":"Magicka supports combining elements and experimentation, not these original numbers or a balance verdict.",
		"scope":"Resolved policy describes potential effects. Paid strength, target eligibility, coverage and counters determine actual outcomes."}


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mask: int in range(1,64):
		var row := definition(mask)
		if row.is_empty(): return []
		result.append(row)
	return result


static func _mechanics(recipe: Dictionary) -> Dictionary:
	var result := recipe.duplicate(true)
	for key: String in IDENTITY_FIELDS: result.erase(key)
	return result


static func _simpler_comparisons(mask: int, recipe: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bit: int in StatusText.BITS:
		if mask & bit == 0 or mask == bit: continue
		var simpler_mask := mask ^ bit
		var simpler := MixtureCatalog.definition(simpler_mask)
		var base_recipe := HexRecipePolicy.definition(int(simpler.reaction_wire_id))
		var delta: Array[Dictionary] = []
		for family: String in MixtureCatalog.FAMILIES:
			var added := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(mask, family))
			var base := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(simpler_mask, family))
			delta.append({"family":family, "extra_flux":int(added.flux_cost)-int(base.flux_cost),
				"direct_damage_change":int(added.damage)-int(base.damage),
				"status_duration_change_ms":int(added.status_duration_ms)-int(base.status_duration_ms)})
		var changed := changed_mechanical_fields(recipe,base_recipe)
		result.append({"without_bit":bit, "element_mask":simpler_mask, "name":String(simpler.display_name),
			"delivery_deltas":delta, "formation_tick_change":int(recipe.formation_ticks)-int(base_recipe.formation_ticks),
			"changed_mechanical_fields":changed})
	return result


static func changed_mechanical_fields(recipe: Dictionary, base_recipe: Dictionary) -> Array[String]:
	# Resolved policies combine literal StringName keys with authored String
	# keys. Normalize before sorting: Variant's mixed-key ordering is not a
	# strict weak order and can fail in Godot's sort implementation.
	var keys: Array[String] = []
	for source: Dictionary in [recipe,base_recipe]:
		for raw_key: Variant in source:
			var key := String(raw_key)
			if not keys.has(key): keys.append(key)
	keys.sort()
	var changed: Array[String] = []
	for key: String in keys:
		if key not in IDENTITY_FIELDS and recipe.get(key) != base_recipe.get(key): changed.append(key)
	return changed
