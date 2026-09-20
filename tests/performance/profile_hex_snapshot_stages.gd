extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Isolated stage profiler for the production whole-campus snapshot path. This
# reuses the existing eight-champion dense-crucible fixture and its ordinary
# paid command schedule; it does not change capacity, cadence, or authority.
const STAGE_REPETITIONS := 5
const ACTIVE_WORKLOAD_TICKS := 40
const EXPECTED_TOPOLOGY_CELLS := 1_493


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-snapshot-stages-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"stage receipt path is fresh and scoped",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "normal campus produces one trusted whole-hex definition")
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "stage profile uses the genuine 1493-cell campus topology")
	if failures > 0:
		quit(1)
		return

	var fixture: Dictionary = _fixture("dense-crucible")
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	var court: HexChemistryWorld = world.hex_court
	for unused: int in range(WARMUP_TICKS):
		_check(world.step(_commands(world, targets, "dense-crucible", false, false)), "neutral warmup advances")
	for unused: int in range(ACTIVE_WORKLOAD_TICKS):
		_check(world.step(_commands(world, targets, "dense-crucible", true, false)), "authored paid workload advances")
	_check(world.players.size() == 8, "stage profile retains eight real champion actors")
	_check(int(court.metrics.admitted) > 0 and int(court.metrics.matter_paid) > 0, "stage profile contains paid chemistry authority")
	_check(court.cells.size() == EXPECTED_TOPOLOGY_CELLS, "bound authority retains the genuine campus topology")
	_check(court.conservation_valid(), "paid matter is conserved before profiling")

	var stable_world_hash: String = world.state_hash()
	var stable_hex_hash: String = court.state_hash()
	var ordered_cells: Array[Vector2i] = HexChemistrySnapshot._trusted_cells(court)
	var stable_topology_hash: String = HexChemistrySnapshot._topology_hash(court, ordered_cells)
	var chemistry_snapshot: Dictionary = HexChemistrySnapshot._capture_for_outer_roundtrip(court)
	var world_snapshot: Dictionary = HexWorldSnapshot.capture(world)
	_check(stable_world_hash.length() == 64 and stable_hex_hash.length() == 64 and stable_topology_hash.length() == 64, "baseline hashes are complete")
	_check(not chemistry_snapshot.is_empty() and not world_snapshot.is_empty(), "baseline snapshot captures succeed")
	_check(String(chemistry_snapshot.topology_hash) == stable_topology_hash, "captured topology fingerprint matches isolated baseline")
	_check(String(chemistry_snapshot.authority_hash) == stable_hex_hash and String(world_snapshot.state_hash) == stable_world_hash, "captured authority hashes match isolated baselines")

	var stages: Dictionary = {
		"world_hash": _measure_world_hash(world, stable_world_hash),
		"topology_hash": _measure_topology_hash(court, ordered_cells, stable_topology_hash),
		"chemistry_capture": _measure_chemistry_capture(world, stable_world_hash, chemistry_snapshot),
		"world_capture": _measure_world_capture(world, stable_world_hash, world_snapshot),
		"blank_world": _measure_blank_world(court, stable_topology_hash),
		"chemistry_restore": _measure_chemistry_restore(court, chemistry_snapshot, stable_hex_hash),
		"world_prepare": _measure_world_prepare(world, world_snapshot, stable_world_hash),
		"prediction_bind": _measure_prediction_bind(world, stable_hex_hash),
	}
	_malformed_rejection_checks(world, chemistry_snapshot, world_snapshot)
	_check(world.state_hash() == stable_world_hash, "all measured stages leave source authority unchanged")

	var receipt: Dictionary = {
		"schema_version": 1,
		"profile_version": "hex-snapshot-stages-v1",
		"workload_version": "unified-wellspring-profile-v1/dense-crucible-first-40",
		"engine": Engine.get_version_info()["string"],
		"seed": SEED,
		"warmup_ticks": WARMUP_TICKS,
		"active_workload_ticks": ACTIVE_WORKLOAD_TICKS,
		"stage_repetitions": STAGE_REPETITIONS,
		"topology_cells": court.cells.size(),
		"world_tick": world.tick,
		"authority_hash": stable_world_hash,
		"hex_authority_hash": stable_hex_hash,
		"topology_hash": stable_topology_hash,
		"workload": {
			"actors": world.players.size(),
			"metrics": court.metrics.duplicate(true),
			"occupancy": _occupancy(court, world.tick),
		},
		"stages": stages,
		"source_sha256": _stage_source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless isolated inclusive stage timings on the genuine 1493-cell campus after the existing eight-champion dense-crucible warmup and first 40 paid workload ticks. No sockets, rendering, capacity override, gameplay mutation, or performance acceptance.",
		"timing_semantics": "Validation, equality checks, malformed-input checks, fixture setup, warmup, command work, and destination allocation are outside timed regions unless the named production stage itself owns that allocation. Each stage runs five times against one unchanged authority state.",
	}
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "stage receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: hex-snapshot-stages; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _measure_world_hash(world: SimWorld, expected: String) -> Dictionary:
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var actual: String = world.state_hash()
		times[index] = Time.get_ticks_usec() - started
		_check(actual == expected, "world hash repetition is exact")
	return _stage_result("world_hash", times, {"hash": expected})


func _measure_topology_hash(world: HexChemistryWorld, ordered_cells: Array[Vector2i], expected: String) -> Dictionary:
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var actual: String = HexChemistrySnapshot._topology_hash(world, ordered_cells)
		times[index] = Time.get_ticks_usec() - started
		_check(actual == expected, "topology hash repetition is exact")
	return _stage_result("topology_hash", times, {"hash": expected, "ordered_cells": ordered_cells.size()})


func _measure_chemistry_capture(world: SimWorld, expected_world_hash: String, expected: Dictionary) -> Dictionary:
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	var court: HexChemistryWorld = world.hex_court
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var actual: Dictionary = HexChemistrySnapshot._capture_for_outer_roundtrip(court)
		times[index] = Time.get_ticks_usec() - started
		_check(actual == expected, "chemistry producer capture repetition is byte-equivalent")
	_check(world.state_hash() == expected_world_hash, "chemistry producer captures leave authority unchanged")
	return _stage_result("chemistry_capture", times, {"encoded_bytes": HexChemistrySnapshot.encoded_size(expected)})


func _measure_world_capture(world: SimWorld, expected_world_hash: String, expected: Dictionary) -> Dictionary:
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var actual: Dictionary = HexWorldSnapshot.capture(world)
		times[index] = Time.get_ticks_usec() - started
		_check(actual == expected, "world capture repetition is byte-equivalent")
	_check(world.state_hash() == expected_world_hash, "world captures leave authority unchanged")
	return _stage_result("world_capture", times, {"wire_bytes": HexWorldSnapshot.byte_size(expected)})


func _measure_blank_world(trusted: HexChemistryWorld, expected_topology_hash: String) -> Dictionary:
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var blank: HexChemistryWorld = HexWorldSnapshot._blank_trusted_hex(trusted)
		times[index] = Time.get_ticks_usec() - started
		_check(blank != null, "blank trusted world repetition succeeds")
		if blank != null:
			var cells: Array[Vector2i] = HexChemistrySnapshot._trusted_cells(blank)
			_check(cells.size() == EXPECTED_TOPOLOGY_CELLS and HexChemistrySnapshot._topology_hash(blank, cells) == expected_topology_hash, "blank world preserves exact trusted topology")
	return _stage_result("blank_world", times, {"topology_cells": EXPECTED_TOPOLOGY_CELLS})


func _measure_chemistry_restore(trusted: HexChemistryWorld, snapshot: Dictionary, expected_hash: String) -> Dictionary:
	var targets: Array[HexChemistryWorld] = []
	for unused: int in range(STAGE_REPETITIONS):
		targets.append(HexWorldSnapshot._blank_trusted_hex(trusted))
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var restored: bool = HexChemistrySnapshot.restore(snapshot, targets[index])
		times[index] = Time.get_ticks_usec() - started
		_check(restored and targets[index].state_hash() == expected_hash, "chemistry restore repetition reconstructs exact authority")
	return _stage_result("chemistry_restore", times, {})


func _measure_world_prepare(trusted: SimWorld, snapshot: Dictionary, expected_hash: String) -> Dictionary:
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var prepared: SimWorld = HexWorldSnapshot.prepare(snapshot, trusted)
		times[index] = Time.get_ticks_usec() - started
		_check(prepared != null and prepared.state_hash() == expected_hash, "world prepare repetition reconstructs exact authority")
	return _stage_result("world_prepare", times, {})


func _measure_prediction_bind(world: SimWorld, expected_hex_hash: String) -> Dictionary:
	var predictors: Array[ClientPrediction] = []
	for unused: int in range(STAGE_REPETITIONS):
		var predictor: ClientPrediction = ClientPrediction.new()
		_check(predictor.configure(world.config, world.collision, 2), "prediction stage configures outside timer")
		predictors.append(predictor)
	var times: PackedInt64Array = PackedInt64Array()
	times.resize(STAGE_REPETITIONS)
	for index: int in range(STAGE_REPETITIONS):
		var started: int = Time.get_ticks_usec()
		var bound: bool = predictors[index].bind_hex_world(world)
		times[index] = Time.get_ticks_usec() - started
		_check(bound and predictors[index].hex_authority != null and predictors[index].hex_authority.state_hash() == expected_hex_hash, "prediction bind repetition owns an exact independent authority copy")
	return _stage_result("prediction_bind", times, {})


func _malformed_rejection_checks(world: SimWorld, chemistry_snapshot: Dictionary, world_snapshot: Dictionary) -> void:
	var wrong_topology: Dictionary = chemistry_snapshot.duplicate(true)
	wrong_topology.topology_hash = "0".repeat(64)
	var court: HexChemistryWorld = world.hex_court
	var chemistry_target: HexChemistryWorld = HexWorldSnapshot._blank_trusted_hex(court)
	var before_hex_hash: String = chemistry_target.state_hash() if chemistry_target != null else ""
	_check(chemistry_target != null and not HexChemistrySnapshot.restore(wrong_topology, chemistry_target), "restore rejects a forged topology fingerprint")
	_check(chemistry_target != null and chemistry_target.state_hash() == before_hex_hash, "rejected chemistry restore leaves target unchanged")

	var wrong_authority: Dictionary = world_snapshot.duplicate(true)
	wrong_authority.state_hash = "f".repeat(64)
	_check(HexWorldSnapshot.prepare(wrong_authority, world) == null, "prepare rejects a forged authority hash")
	var corrupt_hex: Dictionary = world_snapshot.duplicate(true)
	var corrupt_envelope: Dictionary = (corrupt_hex.hex as Dictionary).duplicate(true)
	# Keep the compression framing valid so this rejection check stays quiet under
	# the wrapper's zero-stderr contract. The decoded value deliberately lacks a
	# required wire lane and must still be rejected before authority construction.
	var malformed_packed: Dictionary = HexWorldSnapshot._decompress_hex(corrupt_envelope)
	malformed_packed.erase("metrics")
	var malformed_raw: PackedByteArray = var_to_bytes(malformed_packed)
	corrupt_envelope["size"] = malformed_raw.size()
	corrupt_envelope.bytes = malformed_raw.compress(FileAccess.COMPRESSION_DEFLATE)
	corrupt_hex.hex = corrupt_envelope
	_check(HexWorldSnapshot.prepare(corrupt_hex, world) == null, "prepare rejects valid compression with malformed chemistry shape")


func _stage_result(stage: String, times: PackedInt64Array, extra: Dictionary) -> Dictionary:
	var result: Dictionary = {"stage": stage, "inclusive_us": _percentiles(times), "samples": Array(times)}
	for key: Variant in extra:
		result[key] = extra[key]
	print("HEX_SNAPSHOT_STAGE stage=%s p50_us=%d p95_us=%d max_us=%d" % [stage, int(result.inclusive_us.p50), int(result.inclusive_us.p95), int(result.inclusive_us.max)])
	return result


func _stage_source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [
		"tests/performance/profile_hex_snapshot_stages.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/net/hex_world_snapshot.gd",
		"src/net/hex_chemistry_snapshot.gd",
		"src/net/hex_snapshot_wire_packing.gd",
		"src/net/client_prediction.gd",
		"src/sim/core/sim_world.gd",
		"src/sim/hex/hex_chemistry_world.gd",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
