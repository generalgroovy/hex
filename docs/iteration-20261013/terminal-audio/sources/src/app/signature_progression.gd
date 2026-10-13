class_name SignatureProgression
extends RefCounted
## Earned local records are separate from preferences, loadouts and developer tools.

const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const LearningPath = preload("res://src/content/signature_learning_path.gd")
const DEFAULT_PATH := "user://signature_progression_v1.json"
const SCHEMA_VERSION := 1
const MAX_FILE_BYTES := 16384
const MAX_RECOVERY_BYTES := MAX_FILE_BYTES * 64
const BACKUP_SUFFIX := ".before-signature-save.bak"
const ROLLING_SUFFIX := ".last-good.bak"

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
var _persistence_requested := false
var _recovery_available := false
var recovery_copy_path := ""
var _recovery_path := ""
var _recovery_count := 0


func configure(champions: ChampionCatalog, abilities: AbilityCatalog, store_path: String = DEFAULT_PATH, allow_persistence: bool = true) -> bool:
	configured = false
	persistence_allowed = false
	_persistence_requested = allow_persistence
	_recovery_available = false
	_recovery_path = ""
	_recovery_count = 0
	recovery_copy_path = ""
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
		if not bool(parsed.get("ok", false)):
			_refresh_recovery()
			return _fail(String(parsed.error))
		for id: String in parsed.data.defeated: _learned[id] = true
	elif _refresh_recovery():
		return _fail("Progress file is missing; a verified backup is available for explicit recovery.")
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
	# This is read every presentation frame; availability is cached at actual
	# load/save boundaries rather than reading progress files from the HUD.
	return {"configured": configured, "learned_count": _learned.size(), "total": _rows.size(), "dirty": dirty, "error": last_error,
		"can_retry_save": configured and persistence_allowed and dirty,
		"can_recover_backup": _persistence_requested and _recovery_available,
		"recovery_notice": "Restore %d earned spell%s from the verified backup; preserve the current file." % [_recovery_count, "" if _recovery_count == 1 else "s"] if _recovery_available else "",
		"recovery_count": _recovery_count, "recovery_source": _recovery_path,
		"recovery_copy_path": recovery_copy_path,
		"learning_path": LearningPath.view(_rows,learned_ids()) if configured else {},
		"characters": "All 30 characters are already available in the sandbox."}


func retry_save() -> Dictionary:
	var saved := configured and persistence_allowed and (not dirty or save())
	return {"ok": saved, "saved": saved, "notice": "Progress saved." if saved else (last_error if not last_error.is_empty() else "Saving is unavailable in this session.")}


func recover_backup() -> Dictionary:
	# An explicit UI action is required. Recovery never invents empty progress,
	# rewrites a valid current save, or discards the player's damaged/future file.
	if not _persistence_requested or _by_id.size() != 30:
		return {"ok": false, "saved": false, "notice": "Progress recovery is unavailable in this session."}
	var current := _read(path)
	if bool(current.get("ok", false)):
		_recovery_available = false
		var notice := "The current progress file is valid; no backup was restored."
		if not configured: notice += " Restart H.E.X. to reload it."
		return {"ok": false, "saved": false, "notice": notice}
	_refresh_recovery()
	var backup := _read(_recovery_path) if _recovery_available else {}
	if not bool(backup.get("ok", false)):
		_recovery_available = false
		return {"ok": false, "saved": false, "notice": "No verified backup is available; original files were kept."}
	var preserved_path := "%s.recovery-%d-%d" % [path, get_instance_id(), Time.get_ticks_usec()]
	if FileAccess.file_exists(preserved_path):
		return {"ok": false, "saved": false, "notice": "A recovery copy already exists; retry to use a fresh path."}
	if FileAccess.file_exists(path):
		var source := FileAccess.open(path, FileAccess.READ)
		if source == null:
			return {"ok": false, "saved": false, "notice": "Could not read the current file; recovery left it unchanged."}
		if source.get_length() > MAX_RECOVERY_BYTES:
			source.close()
			_recovery_available = false
			_fail("Progress is too large for in-game recovery; the current file and backup were kept.")
			return {"ok": false, "saved": false, "notice": last_error}
		var length := source.get_length()
		var original := source.get_buffer(length)
		source.close()
		# An unreadable source must never be mistaken for a safely copied file.
		if original.size() != length or not _write_atomic(preserved_path, original):
			return {"ok": false, "saved": false, "notice": "Could not preserve the current file; recovery left it unchanged."}
		recovery_copy_path = preserved_path
	var merged := _learned.duplicate()
	for id: String in backup.data.defeated: merged[id] = true
	var ids: Array[String] = []
	for row: Dictionary in _rows:
		if merged.has(String(row.id)): ids.append(String(row.id))
	var bytes := (JSON.stringify({"schema_version": SCHEMA_VERSION, "defeated": ids}, "\t") + "\n").to_utf8_buffer()
	if not _write_atomic(path, bytes):
		return {"ok": false, "saved": false, "notice": last_error}
	_learned = merged
	configured = true
	persistence_allowed = true
	dirty = false
	_recovery_available = false
	last_error = ""
	return {"ok": true, "saved": true, "notice": "Backup restored." + (" The previous file was preserved." if not recovery_copy_path.is_empty() else ""), "recovery_copy_path": recovery_copy_path}


func to_dictionary() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "defeated": learned_ids()}


func save() -> bool:
	if not configured or not persistence_allowed: return _fail("Progress is session-only; saving is disabled.")
	var bytes := (JSON.stringify(to_dictionary(), "\t") + "\n").to_utf8_buffer()
	if bytes.size() > MAX_FILE_BYTES: return _fail("Progress exceeds its save limit; original files were kept.")
	if FileAccess.file_exists(path):
		var original := _read(path)
		if not bool(original.get("ok", false)):
			_refresh_recovery()
			return _fail(String(original.error))
		if original.bytes == bytes:
			dirty = false
			last_error = ""
			_recovery_available = false
			_recovery_path = ""
			_recovery_count = 0
			return true
		var backup := path + BACKUP_SUFFIX
		# Preserve the first backup even if externally damaged. A valid current
		# primary can still advance through the separate rolling generation.
		if not FileAccess.file_exists(backup) and not _write_atomic(backup, original.bytes): return false
		var rolling := path + ROLLING_SUFFIX
		if FileAccess.file_exists(rolling) and not bool(_read(rolling).get("ok", false)):
			if not _preserve_damaged(rolling): return false
		# Commit the previous validated primary first. A failed primary replace
		# leaves both the actual save and its rolling backup valid and identical.
		if not _write_atomic(rolling, original.bytes): return false
	elif _refresh_recovery():
		return _fail("Progress file disappeared; recover the verified backup before saving.")
	if not _write_atomic(path, bytes): return false
	dirty = false
	_recovery_available = false
	last_error = ""
	return true


func _refresh_recovery() -> bool:
	_recovery_available = false
	_recovery_path = ""
	_recovery_count = 0
	if not _persistence_requested: return false
	for suffix: String in [ROLLING_SUFFIX, BACKUP_SUFFIX]:
		var candidate := _read(path + suffix)
		if not bool(candidate.get("ok", false)): continue
		_recovery_path = path + suffix
		_recovery_count = candidate.data.defeated.size()
		_recovery_available = true
		break
	return _recovery_available


func _preserve_damaged(source_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null: return _fail("Could not preserve the damaged rolling backup; original files were kept.")
	var length := source.get_length()
	if length > MAX_RECOVERY_BYTES:
		source.close()
		return _fail("Damaged rolling backup is too large to preserve in-game; original files were kept.")
	var bytes := source.get_buffer(length)
	source.close()
	var preserved := "%s.recovery-%d-%d" % [source_path, get_instance_id(), Time.get_ticks_usec()]
	if bytes.size() != length or FileAccess.file_exists(preserved): return _fail("Could not preserve the damaged rolling backup; original files were kept.")
	return _write_atomic(preserved, bytes)


func _read(source_path: String) -> Dictionary:
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null: return {"ok": false, "error": "Progress file is unavailable; kept unchanged."}
	var length := file.get_length()
	if length <= 0 or length > MAX_FILE_BYTES:
		file.close()
		return {"ok": false, "error": "Progress file has invalid size; kept unchanged."}
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length: return {"ok": false, "error": "Progress file could not be read completely; kept unchanged."}
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
	return {"ok": true, "data": data, "bytes": bytes}


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
