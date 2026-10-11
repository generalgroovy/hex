class_name SignatureProgression
extends RefCounted
## Earned local records are separate from preferences, loadouts and developer tools.

const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const DEFAULT_PATH := "user://signature_progression_v1.json"
const SCHEMA_VERSION := 1
const MAX_FILE_BYTES := 16384
const BACKUP_SUFFIX := ".before-signature-save.bak"

var last_error := ""
var configured := false
var persistence_allowed := false
var dirty := false
var path := DEFAULT_PATH
var _rows: Array[Dictionary] = []
var _by_wire := {}
var _by_id := {}
var _learned := {}
var _preserved := {} # Existing admitted saved/equipped spells, never dev loaners.
var _abilities: AbilityCatalog


func configure(champions: ChampionCatalog, abilities: AbilityCatalog, store_path: String = DEFAULT_PATH, allow_persistence: bool = true) -> bool:
	configured = false
	persistence_allowed = false
	last_error = ""
	dirty = false
	_learned.clear()
	_preserved.clear()
	_by_wire.clear()
	_by_id.clear()
	_abilities = abilities
	_rows = Challenges.rows(champions, abilities)
	path = store_path
	if _rows.size() != 30: return _fail("Signature catalog is incomplete; progress file kept unchanged.")
	for row: Dictionary in _rows:
		_by_id[String(row.id)] = row
		_by_wire[int(row.signature_wire)] = row
	if FileAccess.file_exists(path):
		var parsed := _read(path)
		if not bool(parsed.get("ok", false)): return _fail(String(parsed.error))
		for id: String in parsed.data.defeated: _learned[id] = true
	configured = true
	persistence_allowed = allow_persistence
	return true


func can_equip(wire: int, session_override: bool = false) -> bool:
	if not CombatTuning.is_runtime_wire_id(wire): return false
	if not _by_wire.has(wire): return true # Includes every original spell.
	return session_override or _preserved.has(wire) or _learned.has(String(_by_wire[wire].id))


func preserve_existing(wires: PackedInt32Array) -> void:
	# Call only during initial trusted saved/equipped-weave import. Developer and
	# Range code deliberately have no path to this method or persistent grants.
	for wire: int in wires:
		if _by_wire.has(wire) and CombatTuning.is_runtime_wire_id(wire): _preserved[wire] = true


func learned_ids() -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in _rows:
		if _learned.has(String(row.id)): result.append(String(row.id))
	return result


func record_victory(challenge_id: String) -> Dictionary:
	if not configured or not _by_id.has(challenge_id): return {"ok": false, "new": false, "saved": false, "notice": "Progress is unavailable; original file was kept."}
	var fresh := not _learned.has(challenge_id)
	_learned[challenge_id] = true
	dirty = dirty or fresh
	var saved := not dirty
	if dirty and persistence_allowed: saved = save()
	var row: Dictionary = _by_id[challenge_id]
	var notice := "%s learned." % String(row.spell_name) if fresh else "%s already learned." % String(row.spell_name)
	if not saved: notice += " Available this session; progress has not been saved."
	return {"ok": true, "new": fresh, "saved": saved, "wire": int(row.signature_wire), "notice": notice}


func view() -> Dictionary:
	return {"configured": configured, "learned_count": _learned.size(), "total": _rows.size(), "dirty": dirty, "error": last_error, "characters": "All 30 characters are already available in the sandbox."}


func to_dictionary() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "defeated": learned_ids()}


func save() -> bool:
	if not configured or not persistence_allowed: return _fail("Progress is session-only; saving is disabled.")
	if FileAccess.file_exists(path):
		var original := _read(path)
		if not bool(original.get("ok", false)): return _fail(String(original.error))
		var backup := path + BACKUP_SUFFIX
		if FileAccess.file_exists(backup):
			var recovery := _read(backup)
			if not bool(recovery.get("ok", false)): return _fail("Recovery copy is invalid; progress file kept unchanged.")
		elif not _write_atomic(backup, FileAccess.get_file_as_bytes(path)): return false
	var bytes := (JSON.stringify(to_dictionary(), "\t") + "\n").to_utf8_buffer()
	if bytes.size() > MAX_FILE_BYTES or not _write_atomic(path, bytes): return false
	dirty = false
	last_error = ""
	return true


func _read(source_path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty() or bytes.size() > MAX_FILE_BYTES: return {"ok": false, "error": "Progress file has invalid size; kept unchanged."}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return {"ok": false, "error": "Progress file has invalid JSON; kept unchanged."}
	var data: Variant = parser.data
	if not data is Dictionary or data.size() != 2 or not data.has("schema_version") or not data.has("defeated"):
		return {"ok": false, "error": "Progress schema is unknown; kept unchanged."}
	if typeof(data.schema_version) not in [TYPE_INT, TYPE_FLOAT] or float(data.schema_version) != SCHEMA_VERSION or not data.defeated is Array or data.defeated.size() > _rows.size():
		return {"ok": false, "error": "Progress version or records are unsupported; kept unchanged."}
	var seen := {}
	for id: Variant in data.defeated:
		if not id is String or not _by_id.has(id) or seen.has(id): return {"ok": false, "error": "Progress contains unknown or duplicate rivals; kept unchanged."}
		seen[id] = true
	return {"ok": true, "data": data}


func _write_atomic(target: String, bytes: PackedByteArray) -> bool:
	var staged := "%s.writing-%d-%d" % [target, get_instance_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null: return _fail("Progress is available this session; could not stage its save.")
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_bytes(staged) != bytes or _replace_staged(staged, target) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
		return _fail("Progress is available this session; save failed and original bytes were kept.")
	return true


func _replace_staged(staged: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(staged), ProjectSettings.globalize_path(target))


func _fail(message: String) -> bool:
	last_error = message
	return false
