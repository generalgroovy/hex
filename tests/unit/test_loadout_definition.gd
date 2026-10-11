extends FluxTestSuite


const ABILITY_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const LOADOUT_PATH: String = "res://content/loadouts/foundation_practitioner_v1.json"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "ability catalog loads for loadout projection tests")
	_test_runtime_default(catalog)
	_test_known_disabled_slots_are_preserved(catalog)
	_test_unknown_and_disabled_active_fail_closed(catalog)
	return finish("loadout-definition")


func _test_runtime_default(catalog: AbilityCatalog) -> void:
	var loadout := LoadoutDefinition.new()
	check(loadout.load_from_file(LOADOUT_PATH, catalog), "foundation loadout validates: %s" % loadout.last_error)
	equal(loadout.active_points, 9, "three affinity-aligned actives fit within the standard thirteen-point budget")
	equal(loadout.spell_slot_ids, [
		"cinderbolt", "cinder-shell", "ember-stream", "ember-sweep",
		"dawn-needle", "dawn-shell", "glint-stream", "radiant-veil",
		"", "", "", "",
	], "authored loadout exposes all twelve positions without compaction")
	equal(loadout.spell_slot_wire_ids, PackedInt32Array([
		145, 179, 180, 154,
		173, 191, 192, 174,
		0, 0, 0, 0,
	]), "runtime projection preserves each exact authored position")
	check(loadout.disabled_spell_slots.is_empty(), "new foundation loadout authors only admitted spell IDs")
	equal(loadout.spell_slot_entry(1), {
		"position": 1, "ability_id": "cinderbolt", "wire_id": 145,
		"runtime_status": "playable", "enabled": true,
	}, "enabled slot entry is directly describable")
	equal(loadout.spell_slot_entry(9), {
		"position": 9, "ability_id": "", "wire_id": 0,
		"runtime_status": "empty", "enabled": false,
	}, "empty slot entry retains its position")
	check(loadout.spell_slot_entry(0).is_empty() and loadout.spell_slot_entry(13).is_empty(), "slot descriptions fail closed outside the twelve-position model")


func _test_known_disabled_slots_are_preserved(catalog: AbilityCatalog) -> void:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	authored["spell_slots"] = [
		"cinderbolt", "vector-lance", "cinder-shell", "cinder-fan",
		"", "", "", "",
		"", "", "", "phase-step",
	]
	var loadout := LoadoutDefinition.new()
	loadout.data = authored
	check(loadout.validate(catalog), "known retired authored IDs remain inspectable: %s" % loadout.last_error)
	equal(loadout.spell_slot_ids, authored["spell_slots"], "known disabled authored IDs remain in their original positions")
	equal(loadout.spell_slot_wire_ids, PackedInt32Array([
		145, 0, 179, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
	]), "disabled slots become in-place zeroes without substitution or compaction")
	equal(loadout.disabled_spell_slots, [
		{"position": 2, "ability_id": "vector-lance", "wire_id": 110, "runtime_status": "catalog_only"},
		{"position": 4, "ability_id": "cinder-fan", "wire_id": 146, "runtime_status": "catalog_only"},
		{"position": 12, "ability_id": "phase-step", "wire_id": 120, "runtime_status": "catalog_only"},
	], "disabled metadata identifies every preserved source position and stable wire")
	equal(loadout.spell_slot_entry(2), {
		"position": 2, "ability_id": "vector-lance", "wire_id": 0,
		"runtime_status": "catalog_only", "enabled": false,
	}, "known disabled slot is explicitly describable as unavailable")
	equal(loadout.spell_slot_entry(3).get("wire_id"), 179, "later admitted entries do not slide into a disabled position")


func _test_unknown_and_disabled_active_fail_closed(catalog: AbilityCatalog) -> void:
	var unknown := LoadoutDefinition.new()
	unknown.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	unknown.data["spell_slots"][5] = "missing-spell"
	check(not unknown.validate(catalog), "unknown spell-slot ID still fails closed")
	check(unknown.last_error.contains("unknown ability"), "unknown spell-slot rejection is diagnosable")

	var disabled_active := LoadoutDefinition.new()
	disabled_active.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	disabled_active.data["slots"]["actives"][0] = "vector-lance"
	check(not disabled_active.validate(catalog), "catalog-only ability cannot enter the playable active kit")
	check(disabled_active.last_error.contains("not runtime-enabled"), "disabled active rejection identifies runtime admission")
