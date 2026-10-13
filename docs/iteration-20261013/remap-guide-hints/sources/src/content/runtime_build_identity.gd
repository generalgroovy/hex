class_name RuntimeBuildIdentity
extends RefCounted


const MANIFEST_PATH := "res://content/runtime/runtime_build_identity_v1.json"
const SCHEMA_VERSION := 1
const STATUS := "candidate_generated_not_promoted"
const SCOPE_ID := "production-runtime-source-v1"
const CANONICAL_ENCODING := "utf8-lf-tagged-length-v1"
const PINNED_ENGINE_IDENTITY := "4.7.1.stable.official.a13da4feb"
const AUTHORITY := "Generated from canonical production runtime source records; delivery, publication and acceptance remain separate."
const HASH_LENGTH := 64
const SHORT_HASH_LENGTH := 12
const MAX_EXACT_INTEGER := 2_147_483_647
const EXPECTED_FIELDS: Array[String] = [
	"schema_version",
	"status",
	"scope_id",
	"canonical_encoding",
	"protocol_version",
	"snapshot_schema",
	"engine_identity",
	"record_count",
	"runtime_source_sha256",
	"build_id",
	"authority",
]


static func validate_manifest(
	value: Variant,
	expected_protocol: int,
	expected_snapshot_schema: int,
	expected_engine_identity: String = PINNED_ENGINE_IDENTITY,
) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("Runtime build identity must be a JSON object.")
	if expected_protocol < 1 or expected_snapshot_schema < 1 or expected_engine_identity.is_empty():
		return _failure("Runtime build identity expectations are invalid.")
	var manifest := value as Dictionary
	if manifest.size() != EXPECTED_FIELDS.size():
		return _failure("Runtime build identity has missing or unexpected fields.")
	for key: Variant in manifest.keys():
		if typeof(key) != TYPE_STRING or not EXPECTED_FIELDS.has(String(key)):
			return _failure("Runtime build identity has missing or unexpected fields.")
	for field: String in EXPECTED_FIELDS:
		if not manifest.has(field):
			return _failure("Runtime build identity has missing or unexpected fields.")

	if not _exact_integer(manifest["schema_version"], 1) or int(manifest["schema_version"]) != SCHEMA_VERSION:
		return _failure("Runtime build identity schema is unsupported.")
	if typeof(manifest["status"]) != TYPE_STRING or String(manifest["status"]) != STATUS:
		return _failure("Runtime build identity status is invalid.")
	if typeof(manifest["scope_id"]) != TYPE_STRING or String(manifest["scope_id"]) != SCOPE_ID:
		return _failure("Runtime build identity scope is invalid.")
	if typeof(manifest["canonical_encoding"]) != TYPE_STRING or String(manifest["canonical_encoding"]) != CANONICAL_ENCODING:
		return _failure("Runtime build identity canonical encoding is invalid.")
	if not _exact_integer(manifest["protocol_version"], 1) or int(manifest["protocol_version"]) != expected_protocol:
		return _failure("Runtime build identity protocol differs from this runtime.")
	if not _exact_integer(manifest["snapshot_schema"], 1) or int(manifest["snapshot_schema"]) != expected_snapshot_schema:
		return _failure("Runtime build identity snapshot schema differs from this runtime.")
	if typeof(manifest["engine_identity"]) != TYPE_STRING or String(manifest["engine_identity"]) != expected_engine_identity:
		return _failure("Runtime build identity engine differs from this runtime.")
	if not _exact_integer(manifest["record_count"], 1):
		return _failure("Runtime build identity record count is invalid.")
	if typeof(manifest["runtime_source_sha256"]) != TYPE_STRING:
		return _failure("Runtime build identity source hash is invalid.")
	var full_hash := String(manifest["runtime_source_sha256"])
	if not _valid_lower_hash(full_hash):
		return _failure("Runtime build identity source hash is invalid.")
	var short_id := "p%d-%s" % [expected_protocol, full_hash.left(SHORT_HASH_LENGTH)]
	if typeof(manifest["build_id"]) != TYPE_STRING or String(manifest["build_id"]) != short_id:
		return _failure("Runtime build identity display ID is not derived from its protocol and source hash.")
	if typeof(manifest["authority"]) != TYPE_STRING or String(manifest["authority"]) != AUTHORITY:
		return _failure("Runtime build identity authority boundary is invalid.")

	var sanitized := {
		"schema_version": SCHEMA_VERSION,
		"status": STATUS,
		"scope_id": SCOPE_ID,
		"canonical_encoding": CANONICAL_ENCODING,
		"protocol_version": expected_protocol,
		"snapshot_schema": expected_snapshot_schema,
		"engine_identity": expected_engine_identity,
		"record_count": int(manifest["record_count"]),
		"runtime_source_sha256": full_hash,
		"build_id": short_id,
		"authority": AUTHORITY,
	}
	return {
		"ok": true,
		"error": "",
		"runtime_source_sha256": full_hash,
		"build_id": short_id,
		"manifest": sanitized,
	}


static func parse_manifest_text(
	source: String,
	expected_protocol: int,
	expected_snapshot_schema: int,
	expected_engine_identity: String = PINNED_ENGINE_IDENTITY,
) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return _failure("Runtime build identity JSON is invalid.")
	return validate_manifest(parser.data, expected_protocol, expected_snapshot_schema, expected_engine_identity)


static func load_current(
	expected_protocol: int,
	expected_snapshot_schema: int,
	expected_engine_identity: String = PINNED_ENGINE_IDENTITY,
	path: String = MANIFEST_PATH,
) -> Dictionary:
	if running_engine_identity() != expected_engine_identity:
		return _failure("Running engine differs from the required runtime build identity.")
	if path.is_empty() or not FileAccess.file_exists(path):
		return _failure("Runtime build identity manifest is missing.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Runtime build identity manifest cannot be read.")
	return parse_manifest_text(file.get_as_text(), expected_protocol, expected_snapshot_schema, expected_engine_identity)


static func running_engine_identity() -> String:
	# Engine's display string uses "4.x.y-stable (official)"; the pinned CLI
	# identity additionally names the nine-character build revision.
	var version := Engine.get_version_info()
	return "%d.%d.%d.%s.%s.%s" % [
		version["major"], version["minor"], version["patch"],
		version["status"], version["build"], String(version["hash"]).left(9),
	]


static func _exact_integer(value: Variant, minimum: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= MAX_EXACT_INTEGER
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric >= float(minimum) and numeric <= float(MAX_EXACT_INTEGER) and floor(numeric) == numeric


static func _valid_lower_hash(value: String) -> bool:
	if value.length() != HASH_LENGTH:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"runtime_source_sha256": "",
		"build_id": "",
		"manifest": {},
	}
