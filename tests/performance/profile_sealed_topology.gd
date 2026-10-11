extends "res://tests/performance/profile_unified_wellspring.gd"

# Diagnostic only. The timed baseline is the current codec operating on an
# explicitly materialized legacy twin, NOT the slower historical full oracle.
# Only that legacy twin is passed to old helpers that read the .cells escape hatch.
const Legacy = preload("res://tests/support/hex_producer_topology_legacy_oracle.gd")
const FrozenHash = preload("res://tests/support/hex_stable_cells_candidate.gd")
const PAID_STEPS := 41
const SAMPLE_PAIRS := 3
const EXPECTED_TOPOLOGY_CELLS := 11_337
const ARMS: Array[String] = ["legacy", "sealed"]
const STATES: Array[String] = ["empty", "paid-40", "paid-41"]
const OPERATIONS: Array[String] = ["state_hash", "capture"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/sealed-topology-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "sealed topology receipt path is fresh and scoped")
	if failures > 0:
		quit(1)
		return
	var sources_before: Dictionary = _sealed_sources()
	_check(_hashes_valid(sources_before), "all source dependencies hash before setup")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "unchanged abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "unchanged champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus topology builds")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for case_index: int in CASES.size():
		for reverse_order: bool in [false, true]:
			var result: Dictionary = _paired_case(CASES[case_index], reverse_order, case_index)
			_check(_case_complete(result, CASES[case_index], reverse_order, case_index), "case receipt is complete")
			records.append(result)
	var complete: bool = _records_complete(records)
	_check(complete, "every workload, input order, state, operation and paired sample completed")
	_receipt_guard_checks(records)
	var sources_after: Dictionary = _sealed_sources()
	var sources_unchanged: bool = _hashes_valid(sources_after) and sources_before == sources_after
	_check(sources_unchanged, "source hashes unchanged throughout complete comparison")
	var receipt: Dictionary = {
		"schema_version": 1, "profile_version": "sealed-topology-v1",
		"engine": Engine.get_version_info().get("string", ""), "seed": SEED,
		"map_hash": definition.map_hash, "definition_hash": definition.definition_hash,
		"warmup_ticks": WARMUP_TICKS, "paid_steps": PAID_STEPS, "sample_pairs": SAMPLE_PAIRS,
		"records": records, "receipt_complete": complete, "sources_unchanged": sources_unchanged,
		"source_sha256_before": sources_before, "source_sha256_after": sources_after,
		"assertions": assertions, "failures": failures, "diagnostic_status": "PASS" if failures == 0 else "FAIL",
		"scope": "Paired current-production sealed topology versus its explicit legacy-storage branch. Two separately constructed actual-campus worlds with eight real champions replay identical ordinary paid inputs; distributed and dense cases, normal and reversed input order, empty/paid40/paid41 snapshots. No injected authority, resource refill, capacity or gameplay changes.",
		"baseline_semantics": "Legacy materializes .cells exactly once after normal fixture construction, before neutral warmup and paid replay. Both timed arms call the SAME current HexWorldSnapshot.capture and SimWorld.state_hash APIs. Frozen preceding full capture/prepare and frozen original canonical chemistry bytes run only on the legacy twin outside timers; they are compatibility oracles, not the timed baseline.",
		"timing_semantics": "Three complete capture and three complete state_hash samples per arm/state, paired in alternating order; starting arm is counterbalanced by case/input order. Paid step times cover actual SimWorld.step only, with commands built before each timer. Capture includes codec validation, detached reconstruction, canonical hashing, compression and its internal temporary disposal. Returned output destruction, equality/oracle checks, observer hashing, public prepare/refusal checks and memory reads are outside those timers. Nested timings are not additive.",
		"setup_semantics": "Per-arm fixture setup observations include normal topology admission, actor/catalogue setup, fixture assertions and legacy materialization where applicable. These are single interleaved observations, not isolated topology admission or cold-process benchmarks. The first capture follows untimed correctness/oracle work and is NOT labeled cold.",
		"percentile_limit": "Three warm samples per arm/state are diagnostic observations; p95/p99 are sample-limited maxima, not reliable tail/capacity estimates. Forty-one paid-step samples are a short changing workload, not sustained throughput.",
		"memory_semantics": "Static and process-global peak observations include both live twins, receipt/oracle allocations and caches. Unavailable readings are null. No per-arm allocation, retained-memory saving or peak attribution claim.",
		"performance_acceptance": "NOT_ESTABLISHED. No sockets, rendering, production lifecycle, 60Hz envelope schedule, 120Hz capacity or 16/32/64-player acceptance is established by this bounded probe.",
	}
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "sealed topology receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: sealed-topology; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _paired_case(case_name: String, reverse_order: bool, case_index: int) -> Dictionary:
	print("SEALED_TOPOLOGY fixture=%s reverse=%s" % [case_name, reverse_order])
	var offset: int = case_index + int(reverse_order)
	var worlds: Dictionary = {}
	var targets: Dictionary = {}
	var setup: Dictionary = {}
	var memory_before: Dictionary = _memory()
	for arm: String in _order(offset):
		var started: int = Time.get_ticks_usec()
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		if arm == "legacy":
			# This is the sole intentional getter on either measured source.
			var borrowed: Dictionary = world.hex_court.cells
			_check(borrowed.size() == EXPECTED_TOPOLOGY_CELLS, "legacy escape hatch materializes all topology cells")
		setup[arm] = Time.get_ticks_usec() - started
		worlds[arm] = world
		targets[arm] = fixture.targets
	_check(_storage_modes_valid(worlds), "setup preserves sealed candidate and explicit legacy baseline")
	_check(targets.legacy == targets.sealed, "both replay twins use identical authored targets")
	var legacy: SimWorld = worlds.legacy
	var sealed: SimWorld = worlds.sealed
	for unused: int in WARMUP_TICKS:
		for arm: String in _order(unused + offset):
			var world: SimWorld = worlds[arm]
			_check(world.step(_commands(world, targets[arm], case_name, false, reverse_order)), "neutral warmup advances")
	var stages: Array[Dictionary] = [_paired_stage(worlds, "empty", offset)]
	var step_samples: Dictionary = {"legacy": PackedInt64Array(), "sealed": PackedInt64Array()}
	var step_pairs: Array[Dictionary] = []
	var trace: Array[Dictionary] = []
	for index: int in PAID_STEPS:
		var order: Array[String] = _order(index + offset)
		var pair: Dictionary = {"pair": index, "order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var world: SimWorld = worlds[arm]
			var commands: Array[SimCommand] = _commands(world, targets[arm], case_name, true, reverse_order)
			var started: int = Time.get_ticks_usec()
			var advanced: bool = world.step(commands)
			var elapsed: int = Time.get_ticks_usec() - started
			_check(advanced, "ordinary paid step advances")
			_append_sample(step_samples, pair, arm, elapsed)
		step_pairs.append(pair)
		var expected_hash: String = legacy.state_hash()
		var events: Variant = FrozenHash._stable_original(legacy.combat_events)
		_check(sealed.state_hash() == expected_hash and sealed.combat_events == legacy.combat_events, "paid twins preserve exact per-tick world hash and events")
		_check(_storage_modes_valid(worlds), "paid simulation and observer hashes never detach sealed source")
		trace.append({"tick": legacy.tick, "state_hash": expected_hash, "events": events})
		if index == 39: stages.append(_paired_stage(worlds, "paid-40", offset + 1))
		if index == 40: stages.append(_paired_stage(worlds, "paid-41", offset + 2))
	_check(legacy.hex_court.metrics == sealed.hex_court.metrics, "paid metrics match exactly between representations")
	_check(int(legacy.hex_court.metrics.admitted) > 0 and int(legacy.hex_court.metrics.matter_paid) > 0, "ordinary command replay contains real paid admissions")
	_check(legacy.hex_court.conservation_valid() and sealed.hex_court.conservation_valid(), "both representations conserve all paid matter")
	_check(_alive_count(legacy) == 8 and _alive_count(sealed) == 8, "both replays retain eight living actual champions")
	return {
		"completed": true, "case": case_name, "reverse_command_order": reverse_order, "order_offset": offset,
		"setup_us": setup, "setup_order": _order(offset), "stages": stages, "trace": trace,
		"paid_step": _operation_result(step_samples, step_pairs), "paid_metrics": legacy.hex_court.metrics.duplicate(true),
		"final_state_hash": legacy.state_hash(), "storage_modes_preserved": _storage_modes_valid(worlds),
		"memory_before": memory_before, "memory_after": _memory(),
	}


func _paired_stage(worlds: Dictionary, label: String, offset: int) -> Dictionary:
	var legacy: SimWorld = worlds.legacy
	var sealed: SimWorld = worlds.sealed
	print("SEALED_TOPOLOGY state=%s tick=%d" % [label, legacy.tick])
	var before: String = legacy.state_hash()
	_check(sealed.state_hash() == before, label + " twins start with identical full authority")
	var frozen_bytes: PackedByteArray = FrozenHash.frozen_original_bytes(legacy.hex_court)
	_check(legacy.hex_court._state_hash_bytes() == frozen_bytes and sealed.hex_court._state_hash_bytes() == frozen_bytes, label + " complete chemistry canonical byte stream matches independent frozen original")
	var expected: Dictionary = Legacy.capture(legacy)
	_check(not expected.is_empty(), label + " frozen preceding full capture accepts legacy twin")
	if expected.is_empty(): return {}
	var expected_bytes: PackedByteArray = var_to_bytes(expected)
	var operations: Dictionary = {}
	for operation: String in OPERATIONS:
		var samples: Dictionary = {"legacy": PackedInt64Array(), "sealed": PackedInt64Array()}
		var pairs: Array[Dictionary] = []
		for index: int in SAMPLE_PAIRS:
			var order: Array[String] = _order(index + offset)
			var pair: Dictionary = {"pair": index, "order": order.duplicate(), "samples_us": {}}
			for arm: String in order:
				var world: SimWorld = worlds[arm]
				if operation == "state_hash":
					var started: int = Time.get_ticks_usec()
					var actual_hash: String = world.state_hash()
					var elapsed: int = Time.get_ticks_usec() - started
					_append_sample(samples, pair, arm, elapsed)
					_check(actual_hash == before, label + " timed " + arm + " full hash is exact")
				else:
					var started: int = Time.get_ticks_usec()
					var actual: Dictionary = HexWorldSnapshot.capture(world)
					var elapsed: int = Time.get_ticks_usec() - started
					_append_sample(samples, pair, arm, elapsed)
					_check(actual == expected and var_to_bytes(actual) == expected_bytes, label + " timed " + arm + " full snapshot and typed wire bytes are exact")
				_check(_storage_modes_valid(worlds), label + " timed calls preserve both storage modes")
			pairs.append(pair)
		operations[operation] = _operation_result(samples, pairs)
	var oracle_prepared: SimWorld = Legacy.prepare(expected, legacy)
	_check(oracle_prepared != null and oracle_prepared.state_hash() == before, label + " frozen public prepare reconstructs exact full authority")
	var prepare_checks: Dictionary = {}
	for arm: String in ARMS:
		var world: SimWorld = worlds[arm]
		var prepared: SimWorld = HexWorldSnapshot.prepare(expected, world)
		var valid: bool = prepared != null and prepared.state_hash() == before
		_check(valid, label + " current incoming prepare restores " + arm + " trusted topology")
		prepare_checks[arm] = valid
	var refusal_checks: Dictionary = _refusal_checks(expected, worlds) if label == "paid-40" else {}
	var unchanged: bool = legacy.state_hash() == before and sealed.state_hash() == before and _storage_modes_valid(worlds)
	_check(unchanged, label + " capture, restore and rejection observers leave both sources unchanged")
	return {
		"completed": true, "state": label, "tick": legacy.tick, "order_offset": offset,
		"source_state_hash": before, "chemistry_bytes_sha256": CanonicalBytes.sha256_hex(frozen_bytes),
		"snapshot_bytes_sha256": CanonicalBytes.sha256_hex(expected_bytes), "snapshot_bytes": expected_bytes.size(),
		"topology_cells": sealed.hex_court.cell_count(), "actors": sealed.players.size(),
		"casts": sealed.hex_court.casts.size(), "products": sealed.hex_court.products.size(),
		"operations": operations, "public_prepare_checks": prepare_checks, "refusal_checks": refusal_checks,
		"sources_unchanged": unchanged, "storage_modes_preserved": _storage_modes_valid(worlds), "memory": _memory(),
	}


func _refusal_checks(snapshot: Dictionary, worlds: Dictionary) -> Dictionary:
	var wrong_hash: Dictionary = snapshot.duplicate(true)
	wrong_hash.state_hash = "f".repeat(64)
	var wrong_topology: Dictionary = snapshot.duplicate(true)
	var topology_packed: Dictionary = HexWorldSnapshot._decompress_hex(wrong_topology.hex)
	topology_packed.topology_hash = "0".repeat(64)
	wrong_topology.hex = HexWorldSnapshot._compress_hex(topology_packed)
	_check(not wrong_topology.hex.is_empty() and HexWorldSnapshot._decompress_hex(wrong_topology.hex).get("topology_hash") == "0".repeat(64), "forged topology preserves valid compression and typed lane framing")
	var missing_metrics: Dictionary = snapshot.duplicate(true)
	var envelope: Dictionary = missing_metrics.hex.duplicate(true)
	var packed: Dictionary = HexWorldSnapshot._decompress_hex(envelope)
	packed.erase("metrics")
	var raw: PackedByteArray = var_to_bytes(packed)
	envelope["size"] = raw.size()
	envelope.bytes = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	missing_metrics.hex = envelope
	var result: Dictionary = {}
	var malformed_values: Dictionary = {"forged_authority_hash": wrong_hash, "forged_topology_hash": wrong_topology, "missing_chemistry_metrics": missing_metrics}
	for name: String in ["forged_authority_hash", "forged_topology_hash", "missing_chemistry_metrics"]:
		var malformed: Dictionary = malformed_values[name]
		var outcomes: Dictionary = {"frozen": Legacy.prepare(malformed, worlds.legacy) == null}
		for arm: String in ARMS:
			outcomes[arm] = HexWorldSnapshot.prepare(malformed, worlds[arm]) == null
		_check(outcomes.frozen and outcomes.legacy and outcomes.sealed, "strict refusal agrees across frozen, current legacy and sealed paths: " + name)
		result[name] = outcomes
	return result


func _storage_modes_valid(worlds: Dictionary) -> bool:
	var legacy: SimWorld = worlds.legacy
	var sealed: SimWorld = worlds.sealed
	return legacy.hex_court.immutable_topology() == null and sealed.hex_court.immutable_topology() != null


func _order(index: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(["legacy", "sealed"] if index % 2 == 0 else ["sealed", "legacy"])
	return result


func _append_sample(samples: Dictionary, pair: Dictionary, arm: String, elapsed: int) -> void:
	var values: PackedInt64Array = samples[arm]
	values.append(elapsed)
	samples[arm] = values
	pair.samples_us[arm] = elapsed


func _operation_result(samples: Dictionary, pairs: Array[Dictionary]) -> Dictionary:
	return {"pairs": pairs, "legacy": _stats(samples.legacy), "sealed": _stats(samples.sealed)}


func _stats(samples: PackedInt64Array) -> Dictionary:
	return {"samples_us": Array(samples), "statistics_us": _percentiles(samples)}


func _memory() -> Dictionary:
	var current: int = OS.get_static_memory_usage()
	var peak: int = OS.get_static_memory_peak_usage()
	return {"static_bytes": current if current > 0 else null, "process_global_peak_bytes": peak if peak > 0 else null}


func _records_complete(records: Array[Dictionary]) -> bool:
	if records.size() != CASES.size() * 2: return false
	for index: int in CASES.size():
		if not _case_complete(records[index * 2], CASES[index], false, index): return false
		if not _case_complete(records[index * 2 + 1], CASES[index], true, index): return false
		if records[index * 2].trace != records[index * 2 + 1].trace: return false
		if records[index * 2].paid_metrics != records[index * 2 + 1].paid_metrics: return false
	return true


func _case_complete(value: Dictionary, case_name: String, reverse_order: bool, case_index: int) -> bool:
	var offset: int = case_index + int(reverse_order)
	if value.get("completed") != true or value.get("case") != case_name or value.get("reverse_command_order") != reverse_order: return false
	if value.get("order_offset") != offset or value.get("setup_order") != _order(offset) or value.get("storage_modes_preserved") != true: return false
	var setup: Variant = value.get("setup_us")
	if not setup is Dictionary or setup.size() != 2: return false
	for arm: String in ARMS:
		if typeof(setup.get(arm)) != TYPE_INT or setup[arm] < 0: return false
	var stages: Variant = value.get("stages")
	if not stages is Array or stages.size() != STATES.size(): return false
	for index: int in STATES.size():
		if not _stage_complete(stages[index], STATES[index], offset + index): return false
	if not _operation_complete(value.get("paid_step"), PAID_STEPS, offset): return false
	var trace: Variant = value.get("trace")
	if not trace is Array or trace.size() != PAID_STEPS: return false
	for index: int in trace.size():
		if not trace[index] is Dictionary or trace[index].get("tick", -1) != WARMUP_TICKS + index + 1: return false
		if not _hash_valid(trace[index].get("state_hash")) or not trace[index].get("events") is Array: return false
	if value.get("final_state_hash") != trace[-1].state_hash: return false
	var metrics: Variant = value.get("paid_metrics")
	return metrics is Dictionary and metrics.get("admitted", 0) > 0 and metrics.get("matter_paid", 0) > 0


func _stage_complete(value: Variant, label: String, offset: int) -> bool:
	if not value is Dictionary or value.get("completed") != true or value.get("state") != label or value.get("order_offset") != offset: return false
	var expected_tick: int = WARMUP_TICKS + (0 if label == "empty" else 40 if label == "paid-40" else 41)
	if value.get("tick") != expected_tick or value.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS or value.get("actors") != 8: return false
	if value.get("sources_unchanged") != true or value.get("storage_modes_preserved") != true or value.get("snapshot_bytes", 0) <= 0: return false
	for key: String in ["source_state_hash", "chemistry_bytes_sha256", "snapshot_bytes_sha256"]:
		if not _hash_valid(value.get(key)): return false
	var operations: Variant = value.get("operations")
	if not operations is Dictionary or operations.size() != OPERATIONS.size(): return false
	for operation: String in OPERATIONS:
		if not _operation_complete(operations.get(operation), SAMPLE_PAIRS, offset): return false
	if value.get("public_prepare_checks") != {"legacy": true, "sealed": true}: return false
	var refusals: Variant = value.get("refusal_checks")
	if not refusals is Dictionary: return false
	if label != "paid-40": return refusals.is_empty()
	if refusals.size() != 3: return false
	for name: String in ["forged_authority_hash", "forged_topology_hash", "missing_chemistry_metrics"]:
		if refusals.get(name) != {"frozen": true, "legacy": true, "sealed": true}: return false
	return true


func _operation_complete(value: Variant, count: int, offset: int) -> bool:
	if not value is Dictionary: return false
	for arm: String in ARMS:
		var result: Variant = value.get(arm)
		if not result is Dictionary or not result.get("samples_us") is Array or result.samples_us.size() != count: return false
		for sample: Variant in result.samples_us:
			if typeof(sample) != TYPE_INT or sample < 0: return false
		if result.get("statistics_us") != _percentiles(PackedInt64Array(result.samples_us)): return false
	var pairs: Variant = value.get("pairs")
	if not pairs is Array or pairs.size() != count: return false
	for index: int in pairs.size():
		var pair: Variant = pairs[index]
		if not pair is Dictionary or pair.get("pair") != index or pair.get("order") != _order(index + offset): return false
		if not pair.get("samples_us") is Dictionary or pair.samples_us.size() != 2: return false
		for arm: String in ARMS:
			if pair.samples_us.get(arm, -1) != value[arm].samples_us[index]: return false
	return true


func _receipt_guard_checks(records: Array[Dictionary]) -> void:
	if not _records_complete(records): return
	var broken: Array[Dictionary] = records.duplicate(true)
	broken.pop_back()
	_check(not _records_complete(broken), "receipt guard rejects missing case")
	broken = records.duplicate(true)
	broken[0].stages.pop_back()
	_check(not _records_complete(broken), "receipt guard rejects missing state")
	broken = records.duplicate(true)
	broken[0].stages[0].operations.capture.sealed.samples_us.pop_back()
	_check(not _records_complete(broken), "receipt guard rejects missing paired sample")
	broken = records.duplicate(true)
	broken[0].stages[0].operations.capture.pairs[0].order.reverse()
	_check(not _records_complete(broken), "receipt guard rejects incorrect timing order")
	broken = records.duplicate(true)
	broken[0].storage_modes_preserved = false
	_check(not _records_complete(broken), "receipt guard rejects accidentally materialized candidate")
	broken = records.duplicate(true)
	broken[0].stages[1].refusal_checks.missing_chemistry_metrics.sealed = false
	_check(not _records_complete(broken), "receipt guard rejects missing strict refusal")
	broken = records.duplicate(true)
	broken[0].trace[0].state_hash = "0".repeat(64)
	_check(not _records_complete(broken), "receipt guard rejects divergent input-order traces")


func _hash_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for index: int in value.length():
		if value[index] not in "0123456789abcdef": return false
	return true


func _hashes_valid(values: Dictionary) -> bool:
	if values.is_empty(): return false
	for value: Variant in values.values():
		if not _hash_valid(value): return false
	return true


func _sealed_sources() -> Dictionary:
	var result: Dictionary = _source_hashes()
	# Cover newly introduced runtime helpers automatically, not just a stale
	# manually enumerated list of direct script preloads.
	_add_script_hashes("res://src", result)
	for path: String in ["project.godot", "tests/performance/profile_sealed_topology.gd", "tests/support/hex_producer_topology_legacy_oracle.gd", "tests/support/hex_stable_cells_candidate.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _add_script_hashes(directory: String, result: Dictionary) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(directory)
	files.sort()
	for name: String in files:
		if name.ends_with(".gd"):
			var path: String = directory.path_join(name)
			result[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	var directories: PackedStringArray = DirAccess.get_directories_at(directory)
	directories.sort()
	for name: String in directories:
		_add_script_hashes(directory.path_join(name), result)
