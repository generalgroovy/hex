# Historical p59-era benchmark with preserved pre-expansion snapshot oracles.
# Retained for history only: this script is not current-schema performance
# evidence for protocol60, schema5, or the expanded status/delivery lanes.
extends "res://tests/performance/profile_collision_topology.gd"

const BeforeE9 = preload("res://tests/support/hex_world_snapshot_pre_e9.gd")
const ChemistryBeforeE9 = preload("res://tests/support/hex_chemistry_snapshot_pre_e9.gd")
const CANONICAL_PAIRS := 7
const CANONICAL_GUARD_ASSERTIONS := 59
const CANONICAL_OPERATIONS: Array[String] = ["chemistry_hash", "chemistry_encode", "chemistry_prepare", "world_capture", "world_prepare"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/snapshot-canonical-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped receipt path")
	if failures > 0:
		quit(1)
		return
	var sources_before: Dictionary = _canonical_sources()
	_check(_hashes_valid(sources_before), "all production and diagnostic dependencies hash")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var cold_geometry: Dictionary = _cold_geometry_probe()
	_check(_canonical_cold_complete(cold_geometry), "all three complete cold-geometry sample sets")
	var records: Array[Dictionary] = []
	for index: int in CASE_LABELS.size():
		var record: Dictionary = _canonical_case(CASE_LABELS[index], index)
		_check(_canonical_case_complete(record, CASE_LABELS[index]), "complete case receipt " + CASE_LABELS[index])
		records.append(record)
	var complete: bool = _canonical_receipt_complete(records, cold_geometry)
	_check(complete, "all four complete states and cold-geometry samples")
	_check(_canonical_receipt_guards(records, cold_geometry), "all independent malformed receipt guards complete")
	var sources_after: Dictionary = _canonical_sources()
	var unchanged: bool = _hashes_valid(sources_after) and sources_before == sources_after
	_check(unchanged, "no source changes during profile")
	var receipt: Dictionary = {
		"profile_version": "snapshot-canonical-v2", "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": sources_before, "source_sha256_after": sources_after, "sources_unchanged": unchanged,
		"topology_cells": EXPECTED_TOPOLOGY_CELLS, "pairs": CANONICAL_PAIRS, "cold_geometry": cold_geometry, "records": records, "receipt_complete": complete,
		"baseline": "Frozen E8 complete world and chemistry codecs. Chemistry hash calls explicitly use the unchanged pre-E9 _state_hash_bytes plus SHA256; no candidate streaming hash is used by the baseline codec. Shared unchanged simulation, wire, compression and collision primitives are not independently reimplemented.",
		"scope": "Same sealed 11337-cell source with eight real champions; empty, ordinary distributed/dense paid40 and paid active Rampart fixtures. Seven alternating case-counterbalanced pairs. Full capture and public incoming preparation use fresh destination authority per call. Fixtures and equivalence checks outside timers; immutable topology caches are warm. Not a cold process benchmark.",
		"correctness": "Exact canonical bytes/hash, encoded chemistry dictionary bytes, complete world snapshot bytes, restored full authority hash/collision geometry, and 16 identical paid-state continuation steps per case. Existing independent legacy replay twin retains exact input traces.",
		"limits": "Inclusive operations overlap; never sum them. Seven pairs are diagnostic, not sustained p95/p99, FPS, throughput, physical network or capacity acceptance. Memory observations are global and include both arms; no arm-attributed memory saving.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: snapshot-canonical; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _cold_geometry_probe() -> Dictionary:
	var first_samples := PackedInt64Array()
	var warm_samples := PackedInt64Array()
	var old_samples := PackedInt64Array()
	var memory_before: Dictionary = _memory()
	for index: int in 3:
		var court := HexChemistryWorld.new()
		_check(court.configure_geometry(definition.origin, definition.eligible_cells), "new topology identity for cold hash")
		var started: int = Time.get_ticks_usec()
		var old_hash: String = CanonicalBytes.sha256_hex(court._state_hash_bytes())
		old_samples.append(Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
		var first_hash: String = court.state_hash()
		first_samples.append(Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
		var warm_hash: String = court.state_hash()
		warm_samples.append(Time.get_ticks_usec() - started)
		_check(old_hash == first_hash and first_hash == warm_hash, "cold/warm bytes equal legacy")
	return {"samples": 3, "old_hash": _stats(old_samples), "first_new_topology_hash": _stats(first_samples), "warm_same_topology_hash": _stats(warm_samples), "memory_before": memory_before, "memory_after": _memory(), "scope": "Three newly configured topology identities, not cold engine processes. Preceding whole-byte hash then first streaming hash then warm streaming hash; fixed order and not a tail estimate. Includes new cache construction; one bounded cached topology retained."}


func _canonical_case(label: String, offset: int) -> Dictionary:
	print("CANONICAL_FIXTURE " + label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var before_hash: String = world.state_hash()
	var before_bytes: PackedByteArray = world.hex_court._state_hash_bytes()
	var chemistry: Dictionary = ChemistryBeforeE9._capture_for_outer_roundtrip(world.hex_court)
	var snapshot: Dictionary = BeforeE9.capture(world)
	_check(not chemistry.is_empty() and not snapshot.is_empty(), "frozen E8 captures actual source")
	if chemistry.is_empty() or snapshot.is_empty(): return {}
	var expected_bytes: PackedByteArray = var_to_bytes(snapshot)
	var expected_chemistry: PackedByteArray = var_to_bytes(chemistry)
	var stages: Dictionary = {}
	var memory_before: Dictionary = _memory()
	for operation: String in CANONICAL_OPERATIONS:
		var old_samples := PackedInt64Array()
		var new_samples := PackedInt64Array()
		var pairs: Array[Dictionary] = []
		for pair_index: int in CANONICAL_PAIRS:
			var order: Array[String] = _collision_order(pair_index + offset)
			var pair: Dictionary = {"order": order.duplicate(), "samples_us": {}}
			var results: Dictionary = {}
			for arm: String in order:
				var started: int = Time.get_ticks_usec()
				var value: Variant = _canonical_operation(operation, arm, world, chemistry, snapshot)
				var elapsed: int = Time.get_ticks_usec() - started
				if arm == "frozen": old_samples.append(elapsed)
				else: new_samples.append(elapsed)
				pair.samples_us[arm] = elapsed
				results[arm] = value
			pairs.append(pair)
			for arm: String in order:
				_check(_canonical_result_valid(operation, results[arm], before_hash, before_bytes, expected_chemistry, expected_bytes), label + " " + operation + " " + arm + " exact result")
			if operation == "world_prepare" and results.frozen != null and results.candidate != null:
				_check(_collision_descriptor(results.frozen.collision) == _collision_descriptor(results.candidate.collision), "complete prepared collision structures match")
			_check(world.state_hash() == before_hash and world.hex_court.immutable_topology() != null, "timing observers preserve source and sealed ownership")
		stages[operation] = {"frozen": _stats(old_samples), "candidate": _stats(new_samples), "pairs": pairs}
		print("CANONICAL_STAGE %s %s old_p50_us=%d new_p50_us=%d" % [label, operation, stages[operation].frozen.statistics_us.p50, stages[operation].candidate.statistics_us.p50])
	var old_world: SimWorld = BeforeE9.prepare(snapshot, world)
	var new_world: SimWorld = HexWorldSnapshot.prepare(snapshot, world)
	var continuation: bool = old_world != null and new_world != null
	if continuation:
		for index: int in 16:
			var commands: Array[SimCommand] = _commands(old_world, fixture.targets, "dense-crucible", false, false)
			continuation = old_world.step(commands) and new_world.step(commands) and old_world.state_hash() == new_world.state_hash() and old_world.combat_events == new_world.combat_events and continuation
	_check(continuation, "16 exact paid-state continuation steps")
	var source_unchanged: bool = world.state_hash() == before_hash and world.hex_court._state_hash_bytes() == before_bytes and world.hex_court.immutable_topology() != null
	_check(source_unchanged, "original source unchanged after complete workload")
	return {"case": label, "stages": stages, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(), "paid_metrics": world.hex_court.metrics.duplicate(true), "active_ramparts": _active_ramparts(world.hex_court, world.tick), "source_unchanged": source_unchanged, "continuation_steps": 16 if continuation else 0, "state_hash": before_hash, "trace_sha256": fixture.trace_sha256, "snapshot_bytes": expected_bytes.size(), "snapshot_sha256": CanonicalBytes.sha256_hex(expected_bytes), "memory_before": memory_before, "memory_after": _memory()}


func _canonical_operation(operation: String, arm: String, world: SimWorld, chemistry: Dictionary, snapshot: Dictionary) -> Variant:
	var frozen: bool = arm == "frozen"
	match operation:
		"chemistry_hash": return CanonicalBytes.sha256_hex(world.hex_court._state_hash_bytes()) if frozen else world.hex_court.state_hash()
		"chemistry_encode": return ChemistryBeforeE9._capture_for_outer_roundtrip(world.hex_court) if frozen else HexChemistrySnapshot._capture_for_outer_roundtrip(world.hex_court)
		"chemistry_prepare": return ChemistryBeforeE9._prepare(chemistry, world.hex_court) if frozen else HexChemistrySnapshot._prepare(chemistry, world.hex_court)
		"world_capture": return BeforeE9.capture(world) if frozen else HexWorldSnapshot.capture(world)
		"world_prepare": return BeforeE9.prepare(snapshot, world) if frozen else HexWorldSnapshot.prepare(snapshot, world)
	return null


func _canonical_result_valid(operation: String, value: Variant, world_hash: String, chemistry_bytes: PackedByteArray, chemistry_wire: PackedByteArray, world_wire: PackedByteArray) -> bool:
	match operation:
		"chemistry_hash": return value is String and value == CanonicalBytes.sha256_hex(chemistry_bytes)
		"chemistry_encode": return value is Dictionary and var_to_bytes(value) == chemistry_wire
		"chemistry_prepare": return value is HexChemistryWorld and value._state_hash_bytes() == chemistry_bytes
		"world_capture": return value is Dictionary and var_to_bytes(value) == world_wire
		"world_prepare": return value is SimWorld and value.state_hash() == world_hash
	return false


func _canonical_receipt_complete(records: Variant, cold_geometry: Variant) -> bool:
	return _canonical_records_complete(records) and _canonical_cold_complete(cold_geometry)


func _canonical_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for index: int in CASE_LABELS.size():
		if not _canonical_case_complete(records[index], CASE_LABELS[index]): return false
	return true


func _canonical_case_complete(record: Variant, label: String) -> bool:
	if label not in CASE_LABELS or not _canonical_keys(record, ["case", "stages", "actors", "topology_cells", "paid_metrics", "active_ramparts", "source_unchanged", "continuation_steps", "state_hash", "trace_sha256", "snapshot_bytes", "snapshot_sha256", "memory_before", "memory_after"]): return false
	if typeof(record.case) != TYPE_STRING or record.case != label: return false
	for key: String in ["actors", "topology_cells", "active_ramparts", "continuation_steps", "snapshot_bytes"]:
		if typeof(record[key]) != TYPE_INT: return false
	if record.actors != 8 or record.topology_cells != EXPECTED_TOPOLOGY_CELLS or record.continuation_steps != 16: return false
	if typeof(record.source_unchanged) != TYPE_BOOL or not record.source_unchanged: return false
	if record.active_ramparts < 0 or (label == "active-rampart" and record.active_ramparts <= 0): return false
	if record.snapshot_bytes < 1 or record.snapshot_bytes > HexWorldSnapshot.MAX_RAW_BYTES: return false
	for key: String in ["state_hash", "trace_sha256", "snapshot_sha256"]:
		if not _hash_valid(record[key]): return false
	if not _canonical_keys(record.paid_metrics, ["requested", "admitted", "refused", "deposited", "reactions", "modifiers", "matter_paid", "matter_consumed", "matter_expired", "exposure_queries"]): return false
	for value: Variant in record.paid_metrics.values():
		if typeof(value) != TYPE_INT or value < 0: return false
	if label != "empty" and (record.paid_metrics.admitted <= 0 or record.paid_metrics.matter_paid <= 0): return false
	if label == "empty" and (record.paid_metrics.admitted != 0 or record.paid_metrics.matter_paid != 0 or record.active_ramparts != 0): return false
	if not _canonical_memory_complete(record.memory_before) or not _canonical_memory_complete(record.memory_after): return false
	var stages: Variant = record.stages
	if not _canonical_keys(stages, CANONICAL_OPERATIONS): return false
	var offset: int = CASE_LABELS.find(label)
	for operation: String in CANONICAL_OPERATIONS:
		var stage: Variant = stages[operation]
		if not _canonical_stage_complete(stage, offset): return false
	return true


func _canonical_stage_complete(stage: Variant, offset: int) -> bool:
	if not _canonical_keys(stage, ["frozen", "candidate", "pairs"]): return false
	if not stage.pairs is Array or stage.pairs.size() != CANONICAL_PAIRS: return false
	for arm: String in ["frozen", "candidate"]:
		if not _canonical_samples_complete(stage[arm], CANONICAL_PAIRS): return false
	for index: int in CANONICAL_PAIRS:
		var pair: Variant = stage.pairs[index]
		if not _canonical_keys(pair, ["order", "samples_us"]): return false
		if not pair.order is Array or pair.order.size() != 2: return false
		for arm: Variant in pair.order:
			if typeof(arm) != TYPE_STRING: return false
		if pair.order != _collision_order(index + offset): return false
		if not _canonical_keys(pair.samples_us, ["frozen", "candidate"]): return false
		for arm: String in ["frozen", "candidate"]:
			if typeof(pair.samples_us[arm]) != TYPE_INT or pair.samples_us[arm] <= 0: return false
			if pair.samples_us[arm] != stage[arm].samples_us[index]: return false
	return true


func _canonical_cold_complete(value: Variant) -> bool:
	if not _canonical_keys(value, ["samples", "old_hash", "first_new_topology_hash", "warm_same_topology_hash", "memory_before", "memory_after", "scope"]): return false
	if typeof(value.samples) != TYPE_INT or value.samples != 3: return false
	for stage: String in ["old_hash", "first_new_topology_hash", "warm_same_topology_hash"]:
		if not _canonical_samples_complete(value[stage], 3): return false
	if typeof(value.scope) != TYPE_STRING or value.scope.is_empty(): return false
	return _canonical_memory_complete(value.memory_before) and _canonical_memory_complete(value.memory_after)


func _canonical_samples_complete(value: Variant, expected_count: int) -> bool:
	if not _canonical_keys(value, ["samples_us", "statistics_us"]): return false
	if not value.samples_us is Array or value.samples_us.size() != expected_count: return false
	for sample: Variant in value.samples_us:
		if typeof(sample) != TYPE_INT or sample <= 0: return false
	if not _canonical_keys(value.statistics_us, ["samples", "p50", "p95", "p99", "max"]): return false
	for statistic: Variant in value.statistics_us.values():
		if typeof(statistic) != TYPE_INT or statistic <= 0: return false
	return value.statistics_us == _percentiles(PackedInt64Array(value.samples_us))


func _canonical_memory_complete(value: Variant) -> bool:
	if not _canonical_keys(value, ["static_bytes", "process_global_peak_bytes"]): return false
	for count: Variant in value.values():
		if count != null and (typeof(count) != TYPE_INT or count <= 0): return false
	return true


func _canonical_keys(value: Variant, keys: Array[String]) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true


func _canonical_receipt_guards(records: Array[Dictionary], cold_geometry: Dictionary) -> bool:
	if not _canonical_receipt_complete(records, cold_geometry): return false
	var assertions_before: int = assertions
	var failures_before: int = failures
	for invalid: Variant in [null, false, 7, "records", {}]:
		_check(not _canonical_receipt_complete(invalid, cold_geometry), "receipt refuses non-array records")
		_check(not _canonical_receipt_complete(records, invalid), "receipt refuses non-dictionary cold result")
		_check(not _canonical_case_complete(invalid, "empty"), "receipt refuses non-dictionary case")
	for mutation: String in ["missing-case", "duplicate-case", "wrong-count-type", "missing-stage", "extra-stage", "wrong-stage-type", "missing-pair", "wrong-pair-type", "missing-arm", "extra-arm", "wrong-order", "duplicate-order", "wrong-order-type", "short-samples", "zero-sample", "negative-sample", "string-sample", "float-sample", "pair-type", "pair-mismatch", "stats-count", "stats-value", "stats-type", "short-hash", "nonhex-hash", "hash-type", "snapshot-size", "rampart", "source", "source-type", "memory-shape", "unpaid-case"]:
		var broken: Array[Dictionary] = records.duplicate(true)
		var stage: Dictionary = broken[0].stages.chemistry_hash
		match mutation:
			"missing-case": broken.pop_back()
			"duplicate-case": broken[1] = broken[0].duplicate(true)
			"wrong-count-type": broken[0].actors = 8.0
			"missing-stage": broken[0].stages.erase("world_prepare")
			"extra-stage": broken[0].stages.unmeasured = {}
			"wrong-stage-type": broken[0].stages.world_prepare = []
			"missing-pair": stage.pairs.pop_back()
			"wrong-pair-type":
				var pairs: Array = []
				pairs.assign(stage.pairs)
				pairs[0] = null
				stage.pairs = pairs
			"missing-arm": stage.pairs[0].samples_us.erase("frozen")
			"extra-arm": stage.pairs[0].samples_us.extra = 1
			"wrong-order": stage.pairs[0].order = ["candidate", "frozen"]
			"duplicate-order": stage.pairs[0].order = ["frozen", "frozen"]
			"wrong-order-type": stage.pairs[0].order = [true, "candidate"]
			"short-samples": stage.candidate.samples_us.pop_back()
			"zero-sample", "negative-sample", "string-sample", "float-sample":
				var samples: Array = []
				samples.assign(stage.candidate.samples_us)
				samples[0] = {"zero-sample": 0, "negative-sample": -1, "string-sample": "1", "float-sample": 1.0}[mutation]
				stage.candidate.samples_us = samples
			"pair-type": stage.pairs[0].samples_us.candidate = str(stage.pairs[0].samples_us.candidate)
			"pair-mismatch": stage.pairs[0].samples_us.candidate += 1
			"stats-count": stage.frozen.statistics_us.samples -= 1
			"stats-value": stage.frozen.statistics_us.p50 += 1
			"stats-type": stage.frozen.statistics_us.max = float(stage.frozen.statistics_us.max)
			"short-hash": broken[0].state_hash = "a".repeat(63)
			"nonhex-hash": broken[0].trace_sha256 = "g".repeat(64)
			"hash-type": broken[0].snapshot_sha256 = 123
			"snapshot-size": broken[0].snapshot_bytes = HexWorldSnapshot.MAX_RAW_BYTES + 1
			"rampart": broken[3].active_ramparts = 0
			"source": broken[0].source_unchanged = false
			"source-type": broken[0].source_unchanged = 1
			"memory-shape": broken[0].memory_after = {}
			"unpaid-case": broken[1].paid_metrics.matter_paid = 0
		_check(not _canonical_receipt_complete(broken, cold_geometry), "receipt refuses " + mutation)
	for mutation: String in ["empty", "missing-stage", "extra-stage", "sample-count", "sample-type", "short-samples", "zero-sample", "pairless-stage", "stats-value", "stats-type", "memory-type"]:
		var broken: Dictionary = cold_geometry.duplicate(true)
		match mutation:
			"empty": broken = {}
			"missing-stage": broken.erase("warm_same_topology_hash")
			"extra-stage": broken.extra = {}
			"sample-count": broken.samples = 2
			"sample-type": broken.samples = "3"
			"short-samples": broken.first_new_topology_hash.samples_us.pop_back()
			"zero-sample": broken.old_hash.samples_us = [1, 0, 1]
			"pairless-stage": broken.old_hash = {}
			"stats-value": broken.warm_same_topology_hash.statistics_us.p99 += 1
			"stats-type": broken.old_hash.statistics_us.p50 = "1"
			"memory-type": broken.memory_before.static_bytes = false
		_check(not _canonical_receipt_complete(records, broken), "receipt refuses cold " + mutation)
	_check(_canonical_receipt_complete(records, cold_geometry), "negative fixtures leave original complete receipt untouched")
	return assertions - assertions_before == CANONICAL_GUARD_ASSERTIONS and failures == failures_before


func _canonical_sources() -> Dictionary:
	var result: Dictionary = _collision_sources()
	for path: String in ["tests/performance/profile_snapshot_canonical.gd", "tests/support/hex_world_snapshot_pre_e9.gd", "tests/support/hex_chemistry_snapshot_pre_e9.gd", "tests/support/hex_canonical_pre_e9.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
