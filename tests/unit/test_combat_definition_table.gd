extends FluxTestSuite


const CATALOG_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
# Local readability candidate: 20% slower and 20% larger projectiles.
# Independent production A/B traces in test_elemental_bursts constrain
# speed, actual collision radius, timing, preserved reach and expiry.
const CANDIDATE_DEFINITION_SIGNATURES: Dictionary = {
	101: "5f0485be6169c4621f9f2c4b9b7b57ba966e42814c1a1c1ad33c426d48546011",
	140: "32693d70069c7083b26c36666cb5ad48864691476da0188a1d7e8b6203b5476e",
	141: "d94cc312d3e1b5c5d2494dfdaa64920d7e15a6b06bcbb91a1e928c7c7afb4b0c",
	142: "6558f49079d8993f7472f1d02e11ccede7a7cdc84b67a34454f85e58536062d9",
	145: "339e9eed3be4962b07a29404a740aeecb09112ac27475c9d82f033527511aba8",
}
const DISABLED_DELIVERY_WIRE_IDS: Array[int] = [
	110,
	146, 147, 148, 149, 150, 151, 152, 153,
	155, 157, 161, 165, 168, 172, 143, 177,
	156, 158, 162, 166, 169, 144, 175, 178,
]
const EXPECTED_REACTION_STRENGTH_BY_FAMILY: Dictionary = {
	"rapid": 1,
	"spray": 3,
	"bolt": 5,
	"heavy": 15,
}


func run() -> int:
	_test_exact_legacy_parity()
	_test_authored_change_updates_definition_and_hash()
	_test_reaction_strength_compiles_independently()
	_test_invalid_simulation_fields_fail_closed()
	return finish("combat-definition-table")


func _catalog() -> AbilityCatalog:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(CATALOG_PATH), "combat source catalog validates: %s" % catalog.last_error)
	return catalog


func _test_exact_legacy_parity() -> void:
	var catalog := _catalog()
	var table := CombatDefinitionTable.new()
	check(table.compile(catalog), "validated catalog compiles once: %s" % table.last_error)
	equal(table.runtime_wire_ids(), catalog.spell_matrix_wire_ids, "compiled order is exactly the 32-cell four-family matrix")
	equal(table.runtime_wire_ids(), CombatTuning.runtime_wire_ids(), "default combat tuning follows the authored runtime order")
	equal(table.runtime_wire_ids().size(), 32, "combat table compiles exactly thirty-two playable definitions")
	equal(table.content_hash.length(), 64, "compiled table has a compatibility hash")
	for wire_id: int in CombatTuning.runtime_wire_ids():
		check(table.is_runtime_wire_id(wire_id), "compiled table contains live wire %d" % wire_id)
		equal(table.definition(wire_id), CombatTuning.cast_definition(wire_id), "wire %d compiles byte-for-byte equivalent simulation data" % wire_id)
		var ability := catalog.ability_from_wire(wire_id)
		var family := AbilityCatalog._spell_family(ability)
		var definition := table.definition(wire_id)
		equal(int(definition.get("reaction_strength", 0)), int(ability.get("reaction_strength", 0)), "wire %d compiles its independently authored reaction strength" % wire_id)
		equal(int(definition.get("reaction_strength", 0)), int(EXPECTED_REACTION_STRENGTH_BY_FAMILY[family]), "wire %d keeps the current %s strength" % [wire_id, family])
		check(int(definition.get("reaction_strength", 0)) != int(definition.get("damage", 0)), "wire %d reaction strength is not derived from damage" % wire_id)
		if CANDIDATE_DEFINITION_SIGNATURES.has(wire_id):
			equal(_definition_signature_without_reaction_strength(definition), CANDIDATE_DEFINITION_SIGNATURES[wire_id], "wire %d preserves its local readability candidate fixture independently of strength" % wire_id)
		else:
			check(wire_id >= 154 and wire_id <= 194, "new compiled wire stays inside the reserved matrix range")
			equal(_definition_signature(definition).length(), 64, "new matrix wire %d has a deterministic definition signature" % wire_id)
	check(table.definition(65_535).is_empty(), "unknown wire fails closed")
	for disabled_wire_id: int in DISABLED_DELIVERY_WIRE_IDS:
		check(not catalog.ability_from_wire(disabled_wire_id).is_empty(), "disabled wire %d retains catalog metadata" % disabled_wire_id)
		equal(String(catalog.ability_from_wire(disabled_wire_id).get("runtime_status", "")), "catalog_only", "disabled wire %d remains explicitly gated" % disabled_wire_id)
		check(table.definition(disabled_wire_id).is_empty(), "disabled wire %d has no compiled cast definition" % disabled_wire_id)
		check(CombatTuning.cast_definition(disabled_wire_id).is_empty(), "disabled wire %d fails closed through the global authority adapter" % disabled_wire_id)
	check(table.projectile_definition(CombatTuning.TIDELINE_WIRE_ID).is_empty(), "compiled spray cannot enter projectile simulation")
	var eclipse_definition := table.definition(142)
	equal(int(eclipse_definition["remaining_bounces"]), 0, "Eclipse deposits its material at the first terminal instead of intrinsically ricocheting")
	eclipse_definition["remaining_bounces"] = 1
	equal(_definition_signature_without_reaction_strength(eclipse_definition), "4d2c13d8121a220082f114fa3fa5dfa4f922c98e3fe0bc6f444864b55aa1a979", "readability candidate Eclipse definition changes only its intrinsic bounce count")


func _test_authored_change_updates_definition_and_hash() -> void:
	var source := _catalog()
	var baseline := CombatDefinitionTable.new()
	check(baseline.compile(source), "baseline table compiles")
	var changed_catalog := AbilityCatalog.new()
	changed_catalog.data = source.data.duplicate(true)
	for ability: Dictionary in changed_catalog.data["abilities"]:
		if String(ability.get("id", "")) == "arc-primary":
			ability["damage"] = int(ability["damage"]) + 1
	check(changed_catalog.validate(), "bounded authored tuning change validates: %s" % changed_catalog.last_error)
	var changed := CombatDefinitionTable.new()
	check(changed.compile(changed_catalog), "changed catalog compiles: %s" % changed.last_error)
	equal(int(changed.definition(CombatTuning.PRIMARY_WIRE_ID)["damage"]), int(CombatTuning.cast_definition(CombatTuning.PRIMARY_WIRE_ID)["damage"]) + 1, "compiled definition follows its only authored damage value")
	equal(int(changed.definition(CombatTuning.PRIMARY_WIRE_ID)["reaction_strength"]), 5, "damage tuning does not change independently authored reaction strength")
	check(changed.content_hash != baseline.content_hash, "authored simulation change updates compatibility hash")


func _test_reaction_strength_compiles_independently() -> void:
	var source := _catalog()
	var baseline := CombatDefinitionTable.new()
	check(baseline.compile(source), "reaction-strength baseline compiles")
	var changed_catalog := AbilityCatalog.new()
	changed_catalog.data = source.data.duplicate(true)
	for ability: Dictionary in changed_catalog.data["abilities"]:
		if String(ability.get("id", "")) == "arc-primary":
			ability["reaction_strength"] = 7
	check(changed_catalog.validate(), "future bounded custom reaction strength validates: %s" % changed_catalog.last_error)
	var changed := CombatDefinitionTable.new()
	check(changed.compile(changed_catalog), "future bounded custom reaction strength compiles: %s" % changed.last_error)
	var baseline_definition := baseline.definition(CombatTuning.PRIMARY_WIRE_ID)
	var changed_definition := changed.definition(CombatTuning.PRIMARY_WIRE_ID)
	equal(int(changed_definition["reaction_strength"]), 7, "compiler preserves another bounded authored integer without a family-name rule")
	equal(int(changed_definition["damage"]), int(baseline_definition["damage"]), "reaction strength tuning does not alter damage")
	equal(String(changed_catalog.ability("arc-primary")["material_operation"]), "charge", "reaction strength tuning does not alter authored material identity")
	check(changed.content_hash != baseline.content_hash, "reaction strength changes the compiled compatibility hash")


func _test_invalid_simulation_fields_fail_closed() -> void:
	var source := _catalog()
	var missing := AbilityCatalog.new()
	missing.data = source.data.duplicate(true)
	for ability: Dictionary in missing.data["abilities"]:
		if String(ability.get("id", "")) == "rillshot":
			ability.erase("speed")
	check(not missing.validate(), "missing runtime simulation field fails closed")
	check(missing.last_error.contains("rillshot/speed"), "missing field failure identifies ability and field")

	var fractional := AbilityCatalog.new()
	fractional.data = source.data.duplicate(true)
	for ability: Dictionary in fractional.data["abilities"]:
		if String(ability.get("id", "")) == "rillshot":
			ability["damage"] = 1.5
	check(not fractional.validate(), "fractional fixed-point damage fails closed")
	check(fractional.last_error.contains("rillshot/damage"), "fractional field failure is diagnosable")

	var incomplete_order := AbilityCatalog.new()
	incomplete_order.data = source.data.duplicate(true)
	incomplete_order.data["runtime_wire_ids"].pop_back()
	check(not incomplete_order.validate(), "runtime order cannot omit a playable wire")
	check(incomplete_order.last_error.contains("every playable spell"), "runtime order failure is diagnosable")

	var unsupported_rotation := AbilityCatalog.new()
	unsupported_rotation.data = source.data.duplicate(true)
	for ability: Dictionary in unsupported_rotation.data["abilities"]:
		# Mutate a playable projectile so matrix gating does not preempt the
		# deterministic fixed-angle diagnostic under test.
		if String(ability.get("id", "")) == "rillshot":
			ability["projectile_angles_degrees"] = [-30, 0, 30]
	check(not unsupported_rotation.validate(), "uncompiled symmetric projectile angle fails during content validation")
	check(unsupported_rotation.last_error.contains("deterministic rotation"), "unsupported angle failure is diagnosable before simulation")


func _definition_signature(definition: Dictionary) -> String:
	var normalized := definition.duplicate(true)
	if normalized.has("projectile_rotations"):
		var rotations: Array = []
		for rotation: Vector2i in normalized["projectile_rotations"]:
			rotations.append([rotation.x, rotation.y])
		normalized["projectile_rotations"] = rotations
	return CanonicalContent.sha256(normalized)


func _definition_signature_without_reaction_strength(definition: Dictionary) -> String:
	var previous_contract := definition.duplicate(true)
	previous_contract.erase("reaction_strength")
	return _definition_signature(previous_contract)
