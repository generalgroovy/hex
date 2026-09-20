class_name CharacterWeaveLibrary
extends RefCounted


const DEFAULT_PATH := "user://character_weaves_v1.json"
const BACKUP_SUFFIX := ".pre_character_weaves_v1.bak"
const SCHEMA_VERSION := 1
const CHARACTER_COUNT := 30
const SLOT_COUNT := 12
const MAX_FILE_BYTES := 65_536
const MODE_CUSTOM := "custom"
const MODE_STARTER := "starter"
const MODES: Array[String] = [MODE_CUSTOM, MODE_STARTER]
const StarterKit = preload("res://src/content/character_starter_kit.gd")

var last_error := ""
var weaves_by_champion: Dictionary[String, Dictionary] = {}
var champion_order: Array[String] = []
var _champions: ChampionCatalog = null
var _abilities: AbilityCatalog = null


func load_from_file(path: String, champions: ChampionCatalog, abilities: AbilityCatalog) -> bool:
	var catalog_error := _catalog_error(champions, abilities)
	if not catalog_error.is_empty():
		return _fail(catalog_error)
	var parsed_state: Dictionary
	if not FileAccess.file_exists(path):
		parsed_state = _starter_state(champions, abilities)
	else:
		var document := _read_document(path)
		if not bool(document.get("ok", false)):
			return _fail(String(document.get("error", "Character weave library could not be read.")))
		parsed_state = _parse_dictionary(document.data, champions, abilities)
	if not bool(parsed_state.get("ok", false)):
		return _fail(String(parsed_state.get("error", "Character weave library is invalid.")))
	_commit_state(parsed_state, champions, abilities)
	last_error = ""
	return true


func saved_weave(champion_id: String) -> Dictionary:
	return weaves_by_champion.get(champion_id, {}).duplicate(true)


func remember(
	champion_id: String,
	requested_wires: Variant,
	mode: String,
	champions: ChampionCatalog,
	abilities: AbilityCatalog,
) -> bool:
	var catalog_error := _catalog_error(champions, abilities)
	if not catalog_error.is_empty():
		return _fail(catalog_error)
	if not champions.champions_by_id.has(champion_id):
		return _fail("Character weave champion is unknown: %s" % champion_id)
	var entry := _entry_from_wires(champion_id, requested_wires, mode, abilities)
	if not bool(entry.get("ok", false)):
		return _fail(String(entry.get("error", "Character weave is invalid.")))

	var next_weaves: Dictionary[String, Dictionary]
	var next_order: Array[String]
	if _state_matches_catalog(champions, abilities):
		next_weaves = weaves_by_champion.duplicate(true)
		next_order = champion_order.duplicate()
	else:
		var starters := _starter_state(champions, abilities)
		if not bool(starters.get("ok", false)):
			return _fail(String(starters.get("error", "Character starter weaves are invalid.")))
		next_weaves = starters.weaves
		next_order = starters.order
	next_weaves[champion_id] = entry.weave
	weaves_by_champion = next_weaves
	champion_order = next_order
	_champions = champions
	_abilities = abilities
	last_error = ""
	return true


func save_to_file(path: String) -> bool:
	if _champions == null or _abilities == null:
		return _fail("Character weave library must load valid catalogs before saving.")
	var current := _parse_dictionary(to_dictionary(), _champions, _abilities)
	if not bool(current.get("ok", false)):
		return _fail("Character weave memory is invalid; file kept unchanged: %s" % String(current.get("error", "unknown error")))
	if FileAccess.file_exists(path):
		var original := _read_valid_bytes(path, _champions, _abilities)
		if original.is_empty():
			return false
		var backup_path := path + BACKUP_SUFFIX
		if FileAccess.file_exists(backup_path):
			if _read_valid_bytes(backup_path, _champions, _abilities).is_empty():
				return false
		elif not _write_bytes(backup_path, original):
			return false
	var encoded := (JSON.stringify(to_dictionary(), "\t") + "\n").to_utf8_buffer()
	if encoded.size() > MAX_FILE_BYTES:
		return _fail("Character weave library exceeds its bounded file size.")
	return _write_bytes(path, encoded)


func to_dictionary() -> Dictionary:
	var entries: Array[Dictionary] = []
	for champion_id: String in champion_order:
		var stored: Dictionary = weaves_by_champion.get(champion_id, {})
		entries.append({
			"champion_id": champion_id,
			"mode": String(stored.get("mode", "")),
			"spell_ids": (stored.get("spell_ids", []) as Array).duplicate(),
			"wire_ids": Array(stored.get("wire_ids", PackedInt32Array())),
		})
	return {"schema_version": SCHEMA_VERSION, "weaves": entries}


func _starter_state(champions: ChampionCatalog, abilities: AbilityCatalog) -> Dictionary:
	var order := champions.ordered_champion_ids()
	if order.size() != CHARACTER_COUNT:
		return _rejected("Character weave library requires exactly thirty canonical champions.")
	var weaves: Dictionary[String, Dictionary] = {}
	for champion_id: String in order:
		var generated: Dictionary = StarterKit.build(champions, abilities, champion_id)
		if not bool(generated.get("valid", false)):
			return _rejected(String(generated.get("error", "Starter weave generation failed.")))
		var entry := _entry_from_wires(champion_id, generated.get("wire_ids", PackedInt32Array()), MODE_STARTER, abilities)
		if not bool(entry.get("ok", false)):
			return entry
		if entry.weave.spell_ids != generated.get("spell_ids", []):
			return _rejected("Character starter wire and ID provenance disagree: %s" % champion_id)
		weaves[champion_id] = entry.weave
	return {"ok": true, "weaves": weaves, "order": order}


func _parse_dictionary(data: Variant, champions: ChampionCatalog, abilities: AbilityCatalog) -> Dictionary:
	if not data is Dictionary:
		return _rejected("Character weave library root must be one object.")
	var root: Dictionary = data
	if not _has_exact_keys(root, ["schema_version", "weaves"]):
		return _rejected("Character weave library requires only schema_version and weaves.")
	if not _whole_number(root.get("schema_version")) or int(root.schema_version) != SCHEMA_VERSION:
		return _rejected("Character weave library schema must be version one.")
	if not root.get("weaves") is Array:
		return _rejected("Character weave library weaves must be an array.")
	var values: Array = root.weaves
	if values.size() != CHARACTER_COUNT:
		return _rejected("Character weave library must contain exactly thirty entries.")
	var canonical_order := champions.ordered_champion_ids()
	if canonical_order.size() != CHARACTER_COUNT:
		return _rejected("Character weave library requires exactly thirty canonical champions.")
	var seen: Dictionary[String, bool] = {}
	var weaves: Dictionary[String, Dictionary] = {}
	for value: Variant in values:
		if not value is Dictionary:
			return _rejected("Every character weave entry must be one object.")
		var raw: Dictionary = value
		if not _has_exact_keys(raw, ["champion_id", "mode", "spell_ids", "wire_ids"]):
			return _rejected("Every character weave requires champion_id, mode, spell_ids and wire_ids.")
		if not raw.get("champion_id") is String or not raw.get("mode") is String:
			return _rejected("Character weave champion_id and mode must be strings.")
		var champion_id := String(raw.champion_id)
		if not champions.champions_by_id.has(champion_id) or seen.has(champion_id):
			return _rejected("Character weave champion is unknown or duplicated: %s" % champion_id)
		var entry := _entry_from_wires(champion_id, raw.wire_ids, String(raw.mode), abilities, raw.spell_ids)
		if not bool(entry.get("ok", false)):
			return entry
		seen[champion_id] = true
		weaves[champion_id] = entry.weave
	for champion_id: String in canonical_order:
		if not seen.has(champion_id):
			return _rejected("Character weave is missing canonical champion: %s" % champion_id)
	return {"ok": true, "weaves": weaves, "order": canonical_order}


func _entry_from_wires(
	champion_id: String,
	requested_wires: Variant,
	mode: String,
	abilities: AbilityCatalog,
	requested_ids: Variant = null,
) -> Dictionary:
	if mode not in MODES:
		return _rejected("Character weave mode must be custom or starter: %s" % champion_id)
	if not requested_wires is Array and not requested_wires is PackedInt32Array and not requested_wires is PackedInt64Array:
		return _rejected("Character weave wire_ids must be an array: %s" % champion_id)
	var wires: Array = Array(requested_wires)
	if wires.size() != SLOT_COUNT:
		return _rejected("Character weave must contain exactly twelve wire IDs: %s" % champion_id)
	if requested_ids != null and not requested_ids is Array:
		return _rejected("Character weave spell_ids must be an array: %s" % champion_id)
	var ids: Array = requested_ids if requested_ids is Array else []
	if requested_ids != null and ids.size() != SLOT_COUNT:
		return _rejected("Character weave must contain exactly twelve spell IDs: %s" % champion_id)
	var normalized_wires := PackedInt32Array()
	var normalized_ids: Array[String] = []
	var seen_wires: Dictionary[int, bool] = {}
	var seen_ids: Dictionary[String, bool] = {}
	for slot: int in range(SLOT_COUNT):
		var wire_value: Variant = wires[slot]
		if not _whole_number(wire_value):
			return _rejected("Character weave wire IDs must be whole numbers: %s" % champion_id)
		var wire_id := int(wire_value)
		var ability_id := abilities.ability_id_from_wire(wire_id)
		var ability: Dictionary = abilities.ability(ability_id)
		if wire_id <= 0 or ability_id.is_empty() or ability.is_empty() or int(ability.get("wire_id", 0)) != wire_id \
				or seen_wires.has(wire_id) or seen_ids.has(ability_id):
			return _rejected("Character weave ability is unknown or duplicated: %s/%d" % [champion_id, wire_id])
		if requested_ids != null:
			if not ids[slot] is String or String(ids[slot]) != ability_id:
				return _rejected("Character weave wire and spell ID disagree: %s/%d" % [champion_id, slot])
		seen_wires[wire_id] = true
		seen_ids[ability_id] = true
		normalized_wires.append(wire_id)
		normalized_ids.append(ability_id)
	return {"ok": true, "weave": {
		"champion_id": champion_id,
		"mode": mode,
		"spell_ids": normalized_ids,
		"wire_ids": normalized_wires,
	}}


func _state_matches_catalog(champions: ChampionCatalog, abilities: AbilityCatalog) -> bool:
	if champion_order != champions.ordered_champion_ids() or weaves_by_champion.size() != CHARACTER_COUNT:
		return false
	for champion_id: String in champion_order:
		if not weaves_by_champion.has(champion_id):
			return false
		var entry: Dictionary = weaves_by_champion[champion_id]
		var checked := _entry_from_wires(champion_id, entry.get("wire_ids", []), String(entry.get("mode", "")), abilities, entry.get("spell_ids", []))
		if not bool(checked.get("ok", false)):
			return false
	return true


func _catalog_error(champions: ChampionCatalog, abilities: AbilityCatalog) -> String:
	if champions == null or champions.content_hash.length() != 64 or not champions.last_error.is_empty():
		return "Character weave library requires a valid champion catalog."
	if abilities == null or abilities.content_hash.length() != 64 or not abilities.last_error.is_empty():
		return "Character weave library requires a valid ability catalog."
	if champions.ordered_champion_ids().size() != CHARACTER_COUNT:
		return "Character weave library requires exactly thirty canonical champions."
	return ""


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _rejected("Character weave library could not be opened: %s" % path)
	var length := file.get_length()
	if length <= 0 or length > MAX_FILE_BYTES:
		file.close()
		return _rejected("Character weave library file size is invalid: %s" % path)
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return _rejected("Character weave library could not be read: %s" % path)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _rejected("Character weave library must contain valid JSON: %s" % path)
	return {"ok": true, "data": parser.data}


func _read_valid_bytes(path: String, champions: ChampionCatalog, abilities: AbilityCatalog) -> PackedByteArray:
	var document := _read_document(path)
	if not bool(document.get("ok", false)):
		last_error = "Character weave file kept unchanged; %s" % String(document.get("error", "could not read existing file"))
		return PackedByteArray()
	var checked := _parse_dictionary(document.data, champions, abilities)
	if not bool(checked.get("ok", false)):
		last_error = "Character weave file kept unchanged; existing file or recovery copy is invalid: %s" % path
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var staged_path := "%s.writing-%d-%d" % [path, get_instance_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(staged_path, FileAccess.WRITE)
	if file == null:
		return _fail("Character weave file kept unchanged; could not stage: %s" % path)
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(staged_path) != bytes:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged_path))
		return _fail("Character weave file kept unchanged; staged write did not verify: %s" % path)
	if _replace_staged_file(staged_path, path) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged_path))
		return _fail("Character weave file kept unchanged; could not install staged file: %s" % path)
	last_error = ""
	return true


func _replace_staged_file(staged_path: String, path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(staged_path), ProjectSettings.globalize_path(path))


func _commit_state(state: Dictionary, champions: ChampionCatalog, abilities: AbilityCatalog) -> void:
	weaves_by_champion = state.weaves
	champion_order = state.order
	_champions = champions
	_abilities = abilities


static func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value))


static func _has_exact_keys(value: Dictionary, required: Array[String]) -> bool:
	if value.size() != required.size():
		return false
	for key: String in required:
		if not value.has(key):
			return false
	return true


static func _rejected(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _fail(message: String) -> bool:
	last_error = message
	return false
