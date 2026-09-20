extends FluxTestSuite


const REACTION_PATH: String = "res://content/reactions/first_eight_element_reactions_v1.json"
const ABILITY_PATH: String = "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	_test_complete_symmetric_catalog()
	_test_bounded_definition_compiler()
	_test_content_change_updates_compatibility_hash()
	_test_invalid_content_fails_closed()
	return finish("reaction-catalog")


func _reactions() -> ReactionCatalog:
	var catalog := ReactionCatalog.new()
	check(catalog.load_from_file(REACTION_PATH), "first-eight reaction catalog validates: %s" % catalog.last_error)
	return catalog


func _abilities() -> AbilityCatalog:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "ability catalog validates for reaction compilation: %s" % catalog.last_error)
	return catalog


func _test_complete_symmetric_catalog() -> void:
	var catalog := _reactions()
	equal(catalog.content_hash.length(), 64, "reaction catalog has a compatibility hash")
	equal(catalog.reactions_by_id.size(), 36, "all unordered first-eight pairs exist exactly once")
	equal(catalog.ordered_wire_ids(), range(301, 337), "reaction wire range is stable and contiguous")
	equal(catalog.runtime_profiles.size(), ReactionCatalog.PRIMITIVES.size(), "one reusable profile owns every shared primitive")
	var observed_primitives: Array[String] = []
	for profile: Dictionary in catalog.runtime_profiles.values():
		observed_primitives.append(String(profile.get("primitive", "")))
	observed_primitives.sort()
	var expected_primitives := ReactionCatalog.PRIMITIVES.duplicate()
	expected_primitives.sort()
	equal(observed_primitives, expected_primitives, "surface/flow/cover/field/conduction/visibility/hazard/refraction/fracture are all represented")
	var pair_count := 0
	for left_index: int in range(ReactionCatalog.FIRST_EIGHT_ELEMENTS.size()):
		for right_index: int in range(left_index, ReactionCatalog.FIRST_EIGHT_ELEMENTS.size()):
			var left := ReactionCatalog.FIRST_EIGHT_ELEMENTS[left_index]
			var right := ReactionCatalog.FIRST_EIGHT_ELEMENTS[right_index]
			var forward := catalog.reaction(left, right)
			var reverse := catalog.reaction(right, left)
			check(not forward.is_empty(), "%s + %s resolves" % [left, right])
			equal(String(reverse.get("id", "")), String(forward.get("id", "")), "%s + %s lookup is symmetric" % [left, right])
			check(not (forward.get("counters", []) as Array).is_empty(), "%s exposes counterplay" % String(forward.get("id", "")))
			pair_count += 1
	equal(pair_count, 36, "upper-triangle pair enumeration is complete")
	check(catalog.reaction("spirit", "fire").is_empty(), "deferred element cannot enter first-eight lookup")


func _test_bounded_definition_compiler() -> void:
	var catalog := _reactions()
	var table := ReactionDefinitionTable.new()
	check(table.compile(catalog, _abilities()), "complete reaction catalog compiles: %s" % table.last_error)
	equal(table.ordered_wire_ids(), range(301, 337), "compiler preserves stable reaction wire order")
	equal(table.content_hash.length(), 64, "compiled reaction definitions have a compatibility hash")
	check(table.mutation_enabled(), "all first-grade executable recipes are promoted together")
	for left_index: int in range(ReactionCatalog.FIRST_EIGHT_ELEMENTS.size()):
		for right_index: int in range(left_index, ReactionCatalog.FIRST_EIGHT_ELEMENTS.size()):
			var left := ReactionCatalog.FIRST_EIGHT_ELEMENTS[left_index]
			var right := ReactionCatalog.FIRST_EIGHT_ELEMENTS[right_index]
			var definition := table.definition(left, right)
			check(not definition.is_empty(), "%s + %s compiles" % [left, right])
			equal(table.definition(right, left), definition, "%s + %s compiled lookup is order-independent" % [left, right])
			check(String(definition.get("primitive", "")) in ReactionCatalog.PRIMITIVES, "%s maps to a shared primitive" % String(definition.get("id", "")))
			equal((definition.get("channel_vector", {}) as Dictionary).size(), ReactionCatalog.CHANNELS.size(), "%s has the exact integer channel vector" % String(definition.get("id", "")))
			equal(String(definition.get("worldbone_policy", "")), "reject", "%s cannot mutate worldbone" % String(definition.get("id", "")))
			check(bool(definition.get("runtime_enabled", false)), "%s has a bounded first-grade execution signature" % String(definition.get("id", "")))
			equal(String(definition["level_one"]["id"]),String(definition["id"]),"runtime minimum signature preserves recipe identity")
			check(int(definition.get("maximum_area_cells", 0)) <= int(table.runtime_bounds["maximum_area_cells_per_reaction"]), "%s area is globally bounded" % String(definition.get("id", "")))
			check(int(definition.get("work_units_per_tick", 0)) <= int(table.runtime_bounds["maximum_work_units_per_tick"]), "%s work is globally bounded" % String(definition.get("id", "")))
	var magma := table.definition("fire", "earth")
	equal(String(magma.get("id", "")), "magma", "flagship pair resolves to Magma")
	equal(String(magma.get("primitive", "")), "flow", "Magma starts from the shared flow primitive")
	equal(magma.get("channel_vector", {}), {"structure": 700, "heat": 700, "saturation": 0, "pressure_momentum": 100, "charge": 0, "radiance_vitality": 0, "decay": 0}, "Magma compiles exact bounded physical channels")
	equal((table.definition("earth", "earth")["channel_vector"] as Dictionary)["structure"], SimConfig.FIXED_SCALE, "same-element channel sum clamps to fixed scale")
	equal((table.definition("light", "dark")["channel_vector"] as Dictionary)["radiance_vitality"], 500, "opposed Light/Dark channel remains a contested boundary")
	var mutable_copy := table.definition("ice", "dark")
	mutable_copy["primitive"] = "hazard"
	equal(String(table.definition("ice", "dark")["primitive"]), "surface", "definition lookup returns a defensive copy")


func _test_content_change_updates_compatibility_hash() -> void:
	var source := _reactions()
	var abilities := _abilities()
	var baseline := ReactionDefinitionTable.new()
	check(baseline.compile(source, abilities), "baseline reaction table compiles")
	var changed := ReactionCatalog.new()
	changed.data = source.data.duplicate(true)
	(changed.data["runtime_profiles"]["moving_flow"] as Dictionary)["active_ms"] = 4001
	check(changed.validate(), "bounded profile change validates: %s" % changed.last_error)
	var changed_table := ReactionDefinitionTable.new()
	check(changed_table.compile(changed, abilities), "changed reaction table compiles: %s" % changed_table.last_error)
	equal(int(changed_table.definition("earth", "fire")["authored_profile"]["active_ms"]), 4001, "future authored profile remains explicit design data")
	equal(int(changed_table.definition("earth", "fire")["active_ms"]), 2750, "first-grade lifecycle keeps the current explicit sustained duration, not an unrelated historical profile")
	check(changed_table.content_hash != baseline.content_hash, "authored reaction change updates compatibility hash")


func _test_invalid_content_fails_closed() -> void:
	var source := _reactions()

	var missing_pair := ReactionCatalog.new()
	missing_pair.data = source.data.duplicate(true)
	missing_pair.data["reactions"].pop_back()
	check(not missing_pair.validate(), "missing pair fails closed")
	check(missing_pair.last_error.contains("36"), "missing pair failure is diagnosable")

	var duplicate_pair := ReactionCatalog.new()
	duplicate_pair.data = source.data.duplicate(true)
	(duplicate_pair.data["reactions"][1] as Dictionary)["input_elements"] = ["earth", "earth"]
	check(not duplicate_pair.validate(), "duplicate unordered pair fails closed")
	check(duplicate_pair.last_error.contains("canonical and unique"), "duplicate pair failure is diagnosable")

	var reversed_pair := ReactionCatalog.new()
	reversed_pair.data = source.data.duplicate(true)
	(reversed_pair.data["reactions"][1] as Dictionary)["input_elements"] = ["fire", "earth"]
	check(not reversed_pair.validate(), "reversed authored pair fails closed while lookup remains symmetric")
	check(reversed_pair.last_error.contains("canonical"), "reversed pair failure identifies canonical order")

	var duplicate_wire := ReactionCatalog.new()
	duplicate_wire.data = source.data.duplicate(true)
	(duplicate_wire.data["reactions"][1] as Dictionary)["wire_id"] = 301
	check(not duplicate_wire.validate(), "duplicate reaction wire fails closed")
	check(duplicate_wire.last_error.contains("wire ids"), "wire collision failure is diagnosable")

	var no_counter := ReactionCatalog.new()
	no_counter.data = source.data.duplicate(true)
	(no_counter.data["reactions"][0] as Dictionary)["counters"] = []
	check(not no_counter.validate(), "reaction without counterplay fails closed")
	check(no_counter.last_error.contains("counterplay"), "counterplay failure is diagnosable")

	var over_capacity := ReactionCatalog.new()
	over_capacity.data = source.data.duplicate(true)
	(over_capacity.data["runtime_profiles"]["moving_flow"] as Dictionary)["maximum_area_cells"] = 33
	check(not over_capacity.validate(), "profile above global area capacity fails closed")
	check(over_capacity.last_error.contains("exceeds global capacity"), "capacity failure is diagnosable")

	var fractional_work := ReactionCatalog.new()
	fractional_work.data = source.data.duplicate(true)
	(fractional_work.data["runtime_profiles"]["moving_flow"] as Dictionary)["work_units_per_tick"] = 1.5
	check(not fractional_work.validate(), "fractional authoritative work fails closed")
	check(fractional_work.last_error.contains("work_units_per_tick"), "fractional work failure is diagnosable")

	var mutable_worldbone := ReactionCatalog.new()
	mutable_worldbone.data = source.data.duplicate(true)
	(mutable_worldbone.data["policy"] as Dictionary)["worldbone_policy"] = "allow"
	check(not mutable_worldbone.validate(), "mutable worldbone policy fails closed")
	check(mutable_worldbone.last_error.contains("safety policy"), "worldbone failure is diagnosable")

	var premature_runtime := ReactionCatalog.new()
	premature_runtime.data = source.data.duplicate(true)
	premature_runtime.data["status"] = "unbounded_recursive_runtime"
	check(not premature_runtime.validate(), "unsupported recursive mutation runtime fails closed")
	check(premature_runtime.last_error.contains("first-grade"), "runtime gate requires the bounded first-grade contract")
