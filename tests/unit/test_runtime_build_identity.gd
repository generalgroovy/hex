extends FluxTestSuite


const Identity = preload("res://src/content/runtime_build_identity.gd")
const PROTOCOL := 48
const SNAPSHOT_SCHEMA := 18
const ENGINE := "4.7.1.stable.official.a13da4feb"
const FULL_HASH := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


func run() -> int:
	_test_valid_identity()
	_test_json_round_trip()
	_test_exact_fields()
	_test_fixed_metadata()
	_test_integer_fields()
	_test_hash_and_derived_id()
	_test_runtime_expectations()
	equal(Identity.running_engine_identity(), ENGINE, "actual running build fields reproduce the pinned CLI engine identity")
	var wrong_engine := Identity.load_current(PROTOCOL, SNAPSHOT_SCHEMA, "4.7.2.stable.example")
	_reject(wrong_engine, "resource loader rejects an actual engine mismatch before reading metadata")
	check(String(wrong_engine.get("error", "")).contains("Running engine differs"), "actual engine identity has a specific failure reason")
	return finish("runtime-build-identity")


func _test_valid_identity() -> void:
	var fixture := _fixture()
	var result := Identity.validate_manifest(fixture, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE)
	check(bool(result.get("ok", false)), "exact candidate identity validates")
	equal(result.get("error", "failure"), "", "valid identity has no error")
	equal(result.get("runtime_source_sha256", ""), FULL_HASH, "loader returns the full source hash")
	equal(result.get("build_id", ""), "p48-aaaaaaaaaaaa", "loader returns the derived short display ID")
	var sanitized: Dictionary = result.get("manifest", {})
	equal(sanitized.size(), Identity.EXPECTED_FIELDS.size(), "loader returns only the strict manifest fields")
	sanitized["status"] = "modified"
	equal(fixture["status"], Identity.STATUS, "validated result does not alias the input fixture")


func _test_json_round_trip() -> void:
	var source := JSON.stringify(_fixture())
	var result := Identity.parse_manifest_text(source, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE)
	check(bool(result.get("ok", false)), "in-memory JSON fixture round-trips")
	_reject(Identity.parse_manifest_text("{", PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "malformed JSON fails closed")
	_reject(Identity.parse_manifest_text("null", PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "non-object JSON fails closed")


func _test_exact_fields() -> void:
	var missing := _fixture()
	missing.erase("scope_id")
	_reject(Identity.validate_manifest(missing, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "missing field fails closed")
	var extra := _fixture()
	extra["released"] = true
	_reject(Identity.validate_manifest(extra, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "unexpected field fails closed")
	_reject(Identity.validate_manifest([], PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "non-dictionary manifest fails closed")


func _test_fixed_metadata() -> void:
	for field: String in ["status", "scope_id", "canonical_encoding", "authority"]:
		var malformed := _fixture()
		malformed[field] = "drifted"
		_reject(Identity.validate_manifest(malformed, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "%s drift fails closed" % field)
		var wrong_type := _fixture()
		wrong_type[field] = StringName(String(wrong_type[field]))
		_reject(Identity.validate_manifest(wrong_type, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "%s rejects a non-JSON string type" % field)
	var schema := _fixture()
	schema["schema_version"] = 2
	_reject(Identity.validate_manifest(schema, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "unknown manifest schema fails closed")


func _test_integer_fields() -> void:
	for field: String in ["schema_version", "protocol_version", "snapshot_schema", "record_count"]:
		for invalid: Variant in [true, "1", 1.5, 0, -1, 3_000_000_000]:
			var malformed := _fixture()
			malformed[field] = invalid
			_reject(Identity.validate_manifest(malformed, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "%s rejects non-exact value %s" % [field, invalid])
	var json_numeric := _fixture()
	json_numeric["record_count"] = 3.0
	check(bool(Identity.validate_manifest(json_numeric, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE).get("ok", false)), "integral JSON number is accepted and sanitized")


func _test_hash_and_derived_id() -> void:
	for invalid_hash: String in ["a".repeat(63), "A".repeat(64), "g".repeat(64), "0x" + "a".repeat(62)]:
		var malformed := _fixture()
		malformed["runtime_source_sha256"] = invalid_hash
		_reject(Identity.validate_manifest(malformed, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "malformed lowercase SHA-256 fails closed")
	var friendly := _fixture()
	friendly["build_id"] = "overnight-best"
	_reject(Identity.validate_manifest(friendly, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "friendly drifting build ID fails closed")
	var wrong_prefix := _fixture()
	wrong_prefix["build_id"] = "p48-000000000000"
	_reject(Identity.validate_manifest(wrong_prefix, PROTOCOL, SNAPSHOT_SCHEMA, ENGINE), "short ID must derive from the full hash")


func _test_runtime_expectations() -> void:
	_reject(Identity.validate_manifest(_fixture(), 47, SNAPSHOT_SCHEMA, ENGINE), "protocol mismatch is actionable")
	_reject(Identity.validate_manifest(_fixture(), PROTOCOL, 19, ENGINE), "snapshot schema mismatch is actionable")
	_reject(Identity.validate_manifest(_fixture(), PROTOCOL, SNAPSHOT_SCHEMA, "4.7.2.stable.example"), "engine mismatch is actionable")
	_reject(Identity.validate_manifest(_fixture(), 0, SNAPSHOT_SCHEMA, ENGINE), "invalid expected protocol fails closed")


func _fixture() -> Dictionary:
	return {
		"schema_version": 1,
		"status": "candidate_generated_not_promoted",
		"scope_id": "production-runtime-source-v1",
		"canonical_encoding": "utf8-lf-tagged-length-v1",
		"protocol_version": PROTOCOL,
		"snapshot_schema": SNAPSHOT_SCHEMA,
		"engine_identity": ENGINE,
		"record_count": 3103,
		"runtime_source_sha256": FULL_HASH,
		"build_id": "p48-aaaaaaaaaaaa",
		"authority": "Generated from canonical production runtime source records; delivery, publication and acceptance remain separate.",
	}


func _reject(result: Dictionary, message: String) -> void:
	check(not bool(result.get("ok", true)), message)
	check(not String(result.get("error", "")).is_empty(), "%s exposes an actionable error" % message)
	equal(result.get("runtime_source_sha256", "leaked"), "", "%s does not expose an unvalidated full hash" % message)
	equal(result.get("build_id", "leaked"), "", "%s does not expose an unvalidated display ID" % message)
