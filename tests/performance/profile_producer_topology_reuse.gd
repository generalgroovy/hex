extends "res://tests/performance/profile_unified_wellspring.gd"

const Legacy = preload("res://tests/support/hex_producer_topology_legacy_oracle.gd")
const PAID_STEPS := 40
const CAPTURE_PAIRS := 6
const STAGES: Array[String] = ["empty", "paid-40", "paid-41"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/producer-topology-reuse-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "producer bridge receipt path is fresh and scoped")
	if failures > 0:
		quit(1)
		return
	var sources_before := _bridge_sources()
	_check(_hashes_valid(sources_before), "all bridge dependencies hash before setup")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "unchanged abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "unchanged champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "unchanged campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "trusted production topology builds")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for case_name: String in CASES:
		var normal := _bridge_case(case_name, false)
		var reverse := _bridge_case(case_name, true)
		_check(_case_complete(normal, case_name, false), case_name + " normal receipt is complete")
		_check(_case_complete(reverse, case_name, true), case_name + " reversed receipt is complete")
		_check(normal.get("trace", []) == reverse.get("trace", []), case_name + " per-tick state/events match under reversed input order")
		records.append(normal)
		records.append(reverse)
	var complete := _records_complete(records)
	_check(complete, "every expected case/state/cold/warm sample completed")
	var sources_after := _bridge_sources()
	var sources_unchanged := _hashes_valid(sources_after) and sources_before == sources_after
	_check(sources_unchanged, "source hashes unchanged throughout complete comparison")
	var receipt := {
		"schema_version": 1, "profile_version": "producer-topology-reuse-v1",
		"engine": Engine.get_version_info().get("string", ""), "seed": SEED,
		"map_hash": definition.map_hash, "definition_hash": definition.definition_hash,
		"warmup_ticks": WARMUP_TICKS, "paid_steps": PAID_STEPS + 1, "warm_pairs": CAPTURE_PAIRS,
		"records": records, "receipt_complete": complete, "sources_unchanged": sources_unchanged,
		"source_sha256_before": sources_before, "source_sha256_after": sources_after,
		"assertions": assertions, "failures": failures, "diagnostic_status": "PASS" if failures == 0 else "FAIL",
		"scope": "Complete HexWorldSnapshot.capture, frozen pre-bridge producer versus call-local topology reuse, on identical unchanged eight-champion distributed/dense paid fixture states. Both input orders; neutral empty state, paid tick40, and next mutating tick41. No actor/chemistry/resource/capacity limit changes; no synthetic authority injection.",
		"timing_semantics": "One cold capture per arm after clearing both existing pure caches, then six warm complete-capture samples per arm in alternating AB/BA order. Timers include encoding, wire packing/compression, detached producer decode, all dynamic/relation/hash checks and local context disposal. Equality, public incoming restore, simulation, hashing for observer traces, and memory observations are outside timers. No sums of nested percentiles.",
		"percentile_limit": "Six warm samples per arm/state; p95/p99 are the sample-limited maximum, not capacity/tail estimates. Cold samples are individual observations.",
		"memory_semantics": "Process-global OS static/peak observations outside timers include both arms and observer overhead; unavailable readings are null. No allocation count or per-arm peak claim.",
		"performance_acceptance": "NOT_ESTABLISHED. This bridge retains full-cell geometry copies and canonical hashing. It does not prove 60Hz envelopes, 120Hz simulation, rendered/networked hosting, or 16/32/64-player capacity.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "producer bridge receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: producer-topology-reuse; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _bridge_case(case_name: String, reverse_order: bool) -> Dictionary:
	var fixture: Dictionary = _fixture(case_name)
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	_check(HexWorldSnapshot._producer_reuse_eligible(world), "actual fixture exercises concrete optimized producer")
	for unused: int in WARMUP_TICKS:
		_check(world.step(_commands(world, targets, case_name, false, reverse_order)), "neutral warmup advances")
	var stages: Array[Dictionary] = []
	stages.append(_capture_pair_stage(world, "empty"))
	var trace: Array[Dictionary] = []
	for index: int in PAID_STEPS + 1:
		_check(world.step(_commands(world, targets, case_name, true, reverse_order)), "ordinary paid command advances")
		trace.append({"tick": world.tick, "state_hash": world.state_hash(), "events": HexChemistryWorld._stable(world.combat_events)})
		if index == PAID_STEPS - 1: stages.append(_capture_pair_stage(world, "paid-40"))
		if index == PAID_STEPS: stages.append(_capture_pair_stage(world, "paid-41"))
	_check(world.hex_court.metrics.admitted > 0 and world.hex_court.metrics.matter_paid > 0, "case contains ordinary paid activity")
	return {"completed": true, "case": case_name, "reverse_command_order": reverse_order, "stages": stages, "trace": trace, "paid_metrics": world.hex_court.metrics.duplicate(true)}


func _capture_pair_stage(world: SimWorld, label: String) -> Dictionary:
	print("PRODUCER_TOPOLOGY stage=%s tick=%d" % [label, world.tick])
	var before := world.state_hash()
	var expected := Legacy.capture(world)
	_check(not expected.is_empty(), label + " frozen producer accepts source")
	if expected.is_empty(): return {}
	var expected_bytes := var_to_bytes(expected)
	var cold := {}
	for arm: String in ["legacy", "candidate"]:
		HexChemistryWorld._canonical_blank_rows.clear()
		HexChemistrySnapshot._blank_topology_bytes.clear()
		HexChemistrySnapshot._blank_topology_cells.clear()
		var started := Time.get_ticks_usec()
		var value := Legacy.capture(world) if arm == "legacy" else HexWorldSnapshot.capture(world)
		cold[arm] = Time.get_ticks_usec() - started
		_check(value == expected and var_to_bytes(value) == expected_bytes, label + " cold " + arm + " exact snapshot/wire bytes")
	var all_samples := {"legacy": PackedInt64Array(), "candidate": PackedInt64Array()}
	var pairs: Array[Dictionary] = []
	var memory_before := _memory()
	for pair: int in CAPTURE_PAIRS:
		var order: Array[String] = []
		order.assign(["legacy", "candidate"] if pair % 2 == 0 else ["candidate", "legacy"])
		var row := {"pair": pair, "order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started := Time.get_ticks_usec()
			var value := Legacy.capture(world) if arm == "legacy" else HexWorldSnapshot.capture(world)
			var elapsed := Time.get_ticks_usec() - started
			var samples: PackedInt64Array = all_samples[arm]
			samples.append(elapsed)
			all_samples[arm] = samples
			row.samples_us[arm] = elapsed
			_check(value == expected and var_to_bytes(value) == expected_bytes, label + " warm " + arm + " exact snapshot/wire bytes")
		pairs.append(row)
	var restored := HexWorldSnapshot.prepare(expected, world)
	_check(restored != null and restored.state_hash() == before, label + " public incoming path still independently restores complete authority")
	_check(world.state_hash() == before, label + " complete paired capture never mutates source")
	return {
		"completed": true, "state": label, "tick": world.tick,
		"source_state_hash": before, "topology_cells": world.hex_court.cells.size(),
		"actors": world.players.size(), "casts": world.hex_court.casts.size(), "products": world.hex_court.products.size(),
		"snapshot_bytes": expected_bytes.size(), "cold_capture_us": cold, "pairs": pairs,
		"legacy": _stats(all_samples.legacy), "candidate": _stats(all_samples.candidate),
		"memory_before": memory_before, "memory_after": _memory(),
	}


func _stats(samples: PackedInt64Array) -> Dictionary:
	return {"samples_us": Array(samples), "statistics_us": _percentiles(samples)}


func _memory() -> Dictionary:
	var current := OS.get_static_memory_usage()
	var peak := OS.get_static_memory_peak_usage()
	return {"static_bytes": current if current > 0 else null, "process_global_peak_bytes": peak if peak > 0 else null}


func _records_complete(values: Array[Dictionary]) -> bool:
	if values.size() != CASES.size() * 2: return false
	for index: int in CASES.size():
		if not _case_complete(values[index * 2], CASES[index], false): return false
		if not _case_complete(values[index * 2 + 1], CASES[index], true): return false
		if values[index * 2].trace != values[index * 2 + 1].trace: return false
	return true


func _case_complete(value: Dictionary, case_name: String, reverse_order: bool) -> bool:
	if value.get("completed") != true or value.get("case") != case_name or value.get("reverse_command_order") != reverse_order: return false
	var stages: Variant = value.get("stages")
	if not stages is Array or stages.size() != STAGES.size(): return false
	for index: int in STAGES.size():
		if not _stage_complete(stages[index], STAGES[index]): return false
	var trace: Variant = value.get("trace")
	if not trace is Array or trace.size() != PAID_STEPS + 1: return false
	for index: int in trace.size():
		if not trace[index] is Dictionary or trace[index].get("tick", -1) != WARMUP_TICKS + index + 1: return false
		if not _hash_valid_value(trace[index].get("state_hash")) or not trace[index].get("events") is Array: return false
	var metrics: Variant = value.get("paid_metrics")
	return metrics is Dictionary and metrics.get("admitted", 0) > 0 and metrics.get("matter_paid", 0) > 0


func _stage_complete(value: Variant, label: String) -> bool:
	if not value is Dictionary or value.get("completed") != true or value.get("state") != label: return false
	var expected_tick := WARMUP_TICKS + (0 if label == "empty" else 40 if label == "paid-40" else 41)
	if value.get("tick", -1) != expected_tick or value.get("actors", -1) != 8 or value.get("topology_cells", -1) != definition.eligible_cells.size(): return false
	if not _hash_valid_value(value.get("source_state_hash")) or value.get("snapshot_bytes", 0) <= 0: return false
	var cold: Variant = value.get("cold_capture_us")
	if not cold is Dictionary or cold.size() != 2: return false
	for arm: String in ["legacy", "candidate"]:
		if typeof(cold.get(arm)) != TYPE_INT or cold[arm] < 0: return false
		var stage: Variant = value.get(arm)
		if not stage is Dictionary or not stage.get("samples_us") is Array or stage.samples_us.size() != CAPTURE_PAIRS: return false
		for sample: Variant in stage.samples_us:
			if typeof(sample) != TYPE_INT or sample < 0: return false
		if stage.get("statistics_us") != _percentiles(PackedInt64Array(stage.samples_us)): return false
	var pairs: Variant = value.get("pairs")
	if not pairs is Array or pairs.size() != CAPTURE_PAIRS: return false
	for index: int in pairs.size():
		var row: Variant = pairs[index]
		if not row is Dictionary or row.get("pair", -1) != index: return false
		var expected_order: Array = ["legacy", "candidate"] if index % 2 == 0 else ["candidate", "legacy"]
		if row.get("order") != expected_order or not row.get("samples_us") is Dictionary: return false
		for arm: String in ["legacy", "candidate"]:
			if row.samples_us.get(arm, -1) != value[arm].samples_us[index]: return false
	return true


func _hash_valid_value(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for index: int in value.length():
		if value[index] not in "0123456789abcdef": return false
	return true


func _hashes_valid(values: Dictionary) -> bool:
	if values.is_empty(): return false
	for value: Variant in values.values():
		if not _hash_valid_value(value): return false
	return true


func _bridge_sources() -> Dictionary:
	var values := _source_hashes()
	for path: String in [
		"src/net/hex_chemistry_snapshot.gd", "src/net/hex_world_snapshot.gd", "src/net/hex_snapshot_wire_packing.gd",
		"tests/support/hex_producer_topology_legacy_oracle.gd", "tests/unit/test_hex_producer_topology_reuse.gd",
		"tests/performance/profile_producer_topology_reuse.gd",
	]: values[path] = FileAccess.get_sha256("res://" + path)
	return values
