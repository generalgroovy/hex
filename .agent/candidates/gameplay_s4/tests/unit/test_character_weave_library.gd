extends FluxTestSuite


const Library = preload("res://src/app/character_weave_library.gd")
const StarterKit = preload("res://src/content/character_starter_kit.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"

class FailedReplacementLibrary:
	extends CharacterWeaveLibrary
	var fail_backup := false
	var fail_primary := false
	func _replace_staged_file(staged_path: String, path: String) -> Error:
		if (fail_backup and path.ends_with(BACKUP_SUFFIX)) or (fail_primary and not path.ends_with(BACKUP_SUFFIX)):
			return ERR_CANT_CREATE
		return super._replace_staged_file(staged_path, path)

var abilities: AbilityCatalog
var champions: ChampionCatalog
var folder := ""


func run() -> int:
	abilities = AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "weave test ability catalog validates: %s" % abilities.last_error)
	champions = ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "weave test champion catalog validates: %s" % champions.last_error)
	var ability_source_before: Dictionary = abilities.data.duplicate(true)
	var champion_source_before: Dictionary = champions.data.duplicate(true)
	folder = "user://character-weave-library-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK, "owned weave fixture directory created")
	if abilities.last_error.is_empty() and champions.last_error.is_empty():
		_test_all_thirty_starters()
		_test_custom_and_disabled_preservation()
		_test_round_trip_backup_and_failures()
		_test_atomic_rejections()
	equal(abilities.data, ability_source_before, "weave persistence never mutates the ability catalog")
	equal(champions.data, champion_source_before, "weave persistence never mutates the champion catalog")
	_cleanup_folder()
	return finish("character-weave-library")


func _test_all_thirty_starters() -> void:
	var path := folder + "/missing.json"
	var library := Library.new()
	check(library.load_from_file(path, champions, abilities), "missing library initializes bounded starter memory")
	check(not FileAccess.file_exists(path), "loading missing library does not write personal storage")
	equal(library.champion_order, champions.ordered_champion_ids(), "memory owns all thirty champions in canonical order")
	equal(library.weaves_by_champion.size(), Library.CHARACTER_COUNT, "memory is bounded to thirty character entries")
	for champion_id: String in champions.ordered_champion_ids():
		var expected: Dictionary = StarterKit.build(champions, abilities, champion_id)
		var saved: Dictionary = library.saved_weave(champion_id)
		equal(String(saved.get("mode", "")), Library.MODE_STARTER, "%s begins in starter mode" % champion_id)
		equal(saved.get("spell_ids", []), expected.get("spell_ids", []), "%s starter IDs match the pure generator" % champion_id)
		equal(saved.get("wire_ids", PackedInt32Array()), expected.get("wire_ids", PackedInt32Array()), "%s starter wires match the pure generator" % champion_id)
		equal((saved.get("wire_ids", PackedInt32Array()) as PackedInt32Array).size(), Library.SLOT_COUNT, "%s owns twelve saved positions" % champion_id)


func _test_custom_and_disabled_preservation() -> void:
	var library := Library.new()
	check(library.load_from_file(folder + "/new-custom.json", champions, abilities), "custom fixture initializes starters")
	var custom: PackedInt32Array = library.saved_weave("oh_tipi").wire_ids
	var disabled_wire := int(abilities.ability("cinder-fan").wire_id)
	check(String(abilities.ability("cinder-fan").runtime_status) == "catalog_only", "fixture uses a retained disabled ability identity")
	custom[custom.size() - 1] = disabled_wire
	check(library.remember("oh_tipi", custom, Library.MODE_CUSTOM, champions, abilities), "custom weave accepts a known retained disabled ID")
	var saved := library.saved_weave("oh_tipi")
	equal(saved.wire_ids, custom, "custom wires persist without a playable substitution")
	equal(String(saved.spell_ids[-1]), "cinder-fan", "retained disabled wire resolves to its exact known ability ID")
	for champion_id: String in champions.ordered_champion_ids():
		library.saved_weave(champion_id)
	equal(library.saved_weave("oh_tipi").wire_ids, custom, "previewing every character never overwrites the custom weave")
	var caller_wires: PackedInt32Array = saved.wire_ids
	caller_wires[0] = 999_999
	saved.wire_ids = caller_wires
	saved.spell_ids[0] = "tampered"
	equal(library.saved_weave("oh_tipi").wire_ids, custom, "saved_weave returns an owned deep copy")
	equal(String(library.saved_weave("oh_tipi").spell_ids[0]), abilities.ability_id_from_wire(custom[0]), "caller mutation cannot alter stored IDs")
	var before := library.to_dictionary()
	var duplicate := custom.duplicate()
	duplicate[1] = duplicate[0]
	check(not library.remember("oh_tipi", duplicate, Library.MODE_CUSTOM, champions, abilities), "remember rejects duplicate ability identities")
	equal(library.to_dictionary(), before, "failed remember leaves all prior memory unchanged")
	check(not library.remember("missing", custom, Library.MODE_CUSTOM, champions, abilities), "remember rejects an unknown champion")
	equal(library.to_dictionary(), before, "unknown champion rejection is atomic")


func _test_round_trip_backup_and_failures() -> void:
	var path := folder + "/persistent.json"
	var backup_path := path + Library.BACKUP_SUFFIX
	var initial := Library.new()
	check(initial.load_from_file(path, champions, abilities), "persistent fixture initializes")
	check(initial.save_to_file(path), "new library saves through a staged verified write")
	check(not FileAccess.file_exists(backup_path), "first save does not invent a preexisting-file backup")
	var original_bytes := FileAccess.get_file_as_bytes(path)
	var desired: PackedInt32Array = initial.saved_weave("oh_tipi").wire_ids
	var disabled_wire := int(abilities.ability("cinder-fan").wire_id)
	desired[desired.size() - 1] = disabled_wire
	var writer := FailedReplacementLibrary.new()
	check(writer.load_from_file(path, champions, abilities), "existing library reloads before replacement")
	check(writer.remember("oh_tipi", desired, Library.MODE_CUSTOM, champions, abilities), "replacement memory records an exact custom weave")
	writer.fail_backup = true
	check(not writer.save_to_file(path), "failed backup installation blocks the primary rewrite")
	equal(FileAccess.get_file_as_bytes(path), original_bytes, "backup failure preserves primary bytes")
	check(not FileAccess.file_exists(backup_path), "failed backup does not claim a recovery copy")
	equal(writer.saved_weave("oh_tipi").wire_ids, desired, "failed write preserves the requested in-memory weave")
	writer.fail_backup = false
	writer.fail_primary = true
	check(not writer.save_to_file(path), "failed primary installation is reported")
	equal(FileAccess.get_file_as_bytes(path), original_bytes, "primary failure preserves original bytes")
	equal(FileAccess.get_file_as_bytes(backup_path), original_bytes, "successful backup preserves exact pre-change bytes")
	writer.fail_primary = false
	check(writer.save_to_file(path), "verified replacement succeeds after failure clears")
	var changed_bytes := FileAccess.get_file_as_bytes(path)
	check(changed_bytes != original_bytes, "custom weave changes serialized primary bytes")
	var reloaded := Library.new()
	check(reloaded.load_from_file(path, champions, abilities), "custom library round-trips")
	equal(reloaded.saved_weave("oh_tipi").wire_ids, desired, "custom including disabled ID round-trips exactly")
	equal(String(reloaded.saved_weave("oh_tipi").mode), Library.MODE_CUSTOM, "custom mode round-trips")
	check(reloaded.save_to_file(path), "idempotent repeat save succeeds")
	equal(FileAccess.get_file_as_bytes(path), changed_bytes, "idempotent save emits identical primary bytes")
	equal(FileAccess.get_file_as_bytes(backup_path), original_bytes, "repeat save never overwrites the recovery copy")
	var damaged := "{ damaged weave".to_utf8_buffer()
	_write_bytes(path, damaged)
	check(not reloaded.save_to_file(path), "damaged existing primary blocks a memory save")
	equal(FileAccess.get_file_as_bytes(path), damaged, "damaged existing primary remains available for recovery")
	equal(FileAccess.get_file_as_bytes(backup_path), original_bytes, "damaged primary cannot replace the prior recovery copy")
	_write_bytes(path, changed_bytes)
	_write_bytes(backup_path, damaged)
	check(not reloaded.save_to_file(path), "damaged recovery copy blocks an otherwise valid primary rewrite")
	equal(FileAccess.get_file_as_bytes(path), changed_bytes, "damaged recovery copy leaves the valid primary intact")
	equal(FileAccess.get_file_as_bytes(backup_path), damaged, "damaged recovery copy is retained and never overwritten")
	_remove(path)
	_remove(backup_path)


func _test_atomic_rejections() -> void:
	var valid_path := folder + "/valid.json"
	var library := Library.new()
	check(library.load_from_file(valid_path, champions, abilities), "atomic fixture initializes")
	var before := library.to_dictionary()
	var cases: Array[Dictionary] = []
	var wrong_schema: Dictionary = before.duplicate(true)
	wrong_schema.schema_version = 2
	cases.append({"label": "schema", "data": wrong_schema})
	var missing: Dictionary = before.duplicate(true)
	missing.weaves.pop_back()
	cases.append({"label": "missing champion", "data": missing})
	var duplicate_champion: Dictionary = before.duplicate(true)
	duplicate_champion.weaves[1].champion_id = duplicate_champion.weaves[0].champion_id
	cases.append({"label": "duplicate champion", "data": duplicate_champion})
	var unknown_champion: Dictionary = before.duplicate(true)
	unknown_champion.weaves[0].champion_id = "unknown"
	cases.append({"label": "unknown champion", "data": unknown_champion})
	var duplicate_wire: Dictionary = before.duplicate(true)
	duplicate_wire.weaves[0].wire_ids[1] = duplicate_wire.weaves[0].wire_ids[0]
	duplicate_wire.weaves[0].spell_ids[1] = duplicate_wire.weaves[0].spell_ids[0]
	cases.append({"label": "duplicate ability", "data": duplicate_wire})
	var unknown_wire: Dictionary = before.duplicate(true)
	unknown_wire.weaves[0].wire_ids[0] = 999_999
	cases.append({"label": "unknown wire", "data": unknown_wire})
	var mismatched_id: Dictionary = before.duplicate(true)
	mismatched_id.weaves[0].spell_ids[0] = mismatched_id.weaves[0].spell_ids[1]
	cases.append({"label": "mismatched ID", "data": mismatched_id})
	var fractional_wire: Dictionary = before.duplicate(true)
	fractional_wire.weaves[0].wire_ids[0] = 140.5
	cases.append({"label": "fractional wire", "data": fractional_wire})
	var wrong_mode: Dictionary = before.duplicate(true)
	wrong_mode.weaves[0].mode = "automatic"
	cases.append({"label": "mode", "data": wrong_mode})
	var extra_root: Dictionary = before.duplicate(true)
	extra_root["unexpected"] = true
	cases.append({"label": "extra root field", "data": extra_root})
	for index: int in range(cases.size()):
		var path := folder + "/invalid-%d.json" % index
		_write_json(path, cases[index].data)
		check(not library.load_from_file(path, champions, abilities), "%s document fails closed" % String(cases[index].label))
		equal(library.to_dictionary(), before, "%s rejection leaves prior memory unchanged" % String(cases[index].label))
		_remove(path)
	var malformed_path := folder + "/malformed.json"
	_write_bytes(malformed_path, "[not an object".to_utf8_buffer())
	check(not library.load_from_file(malformed_path, champions, abilities), "malformed JSON fails closed")
	equal(library.to_dictionary(), before, "malformed JSON leaves prior memory unchanged")
	_remove(malformed_path)
	var oversized_path := folder + "/oversized.json"
	var oversized := PackedByteArray()
	oversized.resize(Library.MAX_FILE_BYTES + 1)
	oversized.fill(32)
	_write_bytes(oversized_path, oversized)
	check(not library.load_from_file(oversized_path, champions, abilities), "oversized document fails before parsing")
	equal(library.to_dictionary(), before, "oversized rejection leaves prior memory unchanged")
	_remove(oversized_path)
	check(not library.load_from_file(valid_path, ChampionCatalog.new(), abilities), "invalid champion catalog fails closed")
	equal(library.to_dictionary(), before, "catalog rejection leaves prior memory unchanged")


func _write_json(path: String, data: Dictionary) -> void:
	_write_bytes(path, (JSON.stringify(data, "\t") + "\n").to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "owned fixture opens for write: %s" % path.get_file())
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "owned fixture removed: %s" % path.get_file())


func _cleanup_folder() -> void:
	var directory := DirAccess.open(folder)
	if directory != null:
		for file_name: String in directory.get_files():
			_remove(folder + "/" + file_name)
		equal(directory.get_files().size(), 0, "owned weave fixture directory is empty after cleanup")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(folder)) == OK, "owned weave fixture directory removed")
