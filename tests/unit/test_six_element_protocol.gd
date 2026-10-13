extends FluxTestSuite

const Elements = preload("res://src/content/element_rules.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ChemistrySnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")


func run() -> int:
	equal(Elements.IDS, ["water", "fire", "wind", "earth", "light", "dark"], "one six-element display order")
	equal(Elements.WIRE_IDS, [3, 2, 4, 1, 7, 8], "sparse identities do not reinterpret historical wires")
	equal(SimConfig.PROTOCOL_VERSION, 61, "mixed payload and status authority includes same-step defeated pending cleanup")
	equal(ChemistrySnapshot.SCHEMA_VERSION, 5, "mixed source funding requires schema5")
	for wire: int in range(-2, 12):
		equal(Elements.is_active_wire(wire), wire in [1, 2, 3, 4, 7, 8], "live element admission uses membership: %d" % wire)
	equal(Elements.fold_legacy_wire(5), 3, "local legacy Ice projects to Water")
	equal(Elements.fold_legacy_wire(6), 2, "local legacy Charge projects to Fire")
	equal(Elements.fold_legacy_wire(9), 0, "local migration does not invent future elements")
	var masks := {}
	for wire: int in Policy.active_wire_ids():
		var mask := Policy.mask_for_wire(wire)
		check(mask >= 1 and mask <= 63 and not masks.has(mask), "every combination has one unique six-bit identity")
		masks[mask] = wire
		equal(Policy.wire_for_mask(mask), wire, "mask and recipe wire round-trip")
		check(not Policy.runtime_definition(wire).is_empty(), "each advertised combination is executable")
		equal(ChemistrySnapshot._material_name(ChemistrySnapshot._material_code(Policy.product_layer(wire))), Policy.product_layer(wire), "sparse compound layer round-trips without aliasing")
	equal(masks.size(), 63, "all self/pair through six-element combinations exist")
	for mask: int in range(1, 64): check(masks.has(mask), "no ingredient subset is omitted: %d" % mask)
	for wire: int in [305, 306, 312, 313, 318, 319, 323, 324, 327, 328, 329, 330, 331, 332, 333, 400, 401, 402, 403, 464]:
		equal(ChemistrySnapshot._material_name(wire - 300), "", "retired/invalid reaction cannot decode through layer index: %d" % wire)
	_test_live_projectile_identity()
	_test_saved_preview_boundary()
	return finish("six-element-protocol")


func _test_live_projectile_identity() -> void:
	var definitions := CombatTuning.runtime_wire_ids()
	equal(definitions.size(), 504, "63 compositions times eight families are live")
	for wire: int in definitions:
		var definition := CombatTuning.projectile_definition(wire)
		if definition.is_empty(): continue
		var row := PackedInt32Array()
		row.resize(Snapshot.PROJECTILE_ROW_SIZE)
		row[0] = 1; row[1] = 1; row[2] = 1; row[3] = wire
		row[4] = int(definition.element_wire_id)
		row[13] = int(definition.radius); row[14] = int(definition.damage)
		row[15] = 120; row[16] = CombatTuning.NO_HIT_CONTROL_STATE
		row[21] = -1; row[22] = 1; row[26] = 1; row[28] = 1
		check(Snapshot._valid_projectile_row(row), "canonical projectile admits: %d" % wire)
		for forged: int in [5, 6, 0, 9]:
			var malformed := row.duplicate()
			malformed[4] = forged
			check(not Snapshot._valid_projectile_row(malformed), "network never aliases retired or unknown ingredients")
		var wrong_identity := row.duplicate()
		wrong_identity[4] = 1 if row[4] != 1 else 2
		check(not Snapshot._valid_projectile_row(wrong_identity), "valid ingredients cannot impersonate a different source spell")


func _test_saved_preview_boundary() -> void:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities):
		check(false, "migration boundary requires valid live catalogs")
		return
	var coordinator := CharacterWeaveCoordinator.new()
	var path := "user://six-protocol-preview-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(coordinator.configure(champions, abilities, false, path), "migration coordinator configures in memory")
	var actor := PlayerState.new()
	check(champions.apply_to_player(actor, "oh_tipi"), "real profile receives canonical starter")
	var initial := actor.canonical_values()
	var legacy := PackedInt32Array([170,140,101,145,189,181,190,171,187,188,167,174])
	check(coordinator.library.remember("oh_tipi", legacy, CharacterWeaveLibrary.MODE_CUSTOM, champions, abilities), "old exact identities remain inspectable")
	var proposal := coordinator.migration_for_actor(actor)
	check(bool(proposal.get("required", false)) and bool(proposal.get("valid", false)), "legacy weave produces explicit valid preview")
	check(coordinator.preferred_weave(actor, true).is_empty(), "old saved configuration never auto-applies aliases")
	check(coordinator.restore_actor(actor, true), "awaiting review leaves playable canonical starter")
	equal(actor.canonical_values(), initial, "preview and pending restore leave every authoritative field unchanged")
	equal(coordinator.library.saved_weave("oh_tipi").wire_ids, legacy, "preview leaves stored legacy positions unchanged")
	check(not FileAccess.file_exists(path), "read-only preview writes no user file")
	check(CharacterWeavePolicy.apply(actor, proposal.after_wire_ids), "explicit reviewed application passes real authority policy")
	check(coordinator.save_local(actor, CharacterWeaveLibrary.MODE_CUSTOM), "explicit confirmed application can replace local memory")
	check(not bool(coordinator.migration_for_actor(actor).get("required", false)), "confirmed migration is idempotent")
