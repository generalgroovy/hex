extends "res://tests/performance/profile_unified_wellspring.gd"

const Candidate = preload("res://tests/support/hex_immutable_topology_candidate.gd")
const FrozenOracle = preload("res://tests/support/hex_stable_cells_candidate.gd")
const PAID_STEPS := 40
const COLD_SAMPLES := 3
const WARM_PAIRS := 20
const HASH_PAIRS := 3


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/immutable-topology-candidate-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "candidate receipt path is fresh and scoped")
	if failures > 0:
		quit(1)
		return
	var source_before := _candidate_sources()
	_check(_source_hashes_valid(source_before), "every measured source has a nonempty SHA-256 before setup")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "trusted local definition builds")
	if failures > 0:
		quit(1)
		return
	var cases: Array[Dictionary] = []
	for case_name: String in CASES:
		var normal := _candidate_case(case_name, false)
		var reversed := _candidate_case(case_name, true)
		_check(_case_complete(normal, case_name, false), case_name + " normal case has every required stage and sample")
		_check(_case_complete(reversed, case_name, true), case_name + " reversed case has every required stage and sample")
		_check(normal.get("trace", []) == reversed.get("trace", []), case_name + " reversed commands preserve every tick hash/event trace")
		cases.append(normal)
		cases.append(reversed)
	var complete := _cases_complete(cases)
	_check(complete, "receipt contains exactly the expected four complete cases, eight paired states, and every measured sample")
	if complete: _check(_completeness_guards_reject_truncation(cases), "receipt guards reject empty helpers, missing samples, wrong identities, and inconsistent statistics")
	var source_after := _candidate_sources()
	var sources_unchanged := _source_hashes_valid(source_after) and source_after == source_before
	_check(sources_unchanged, "all measured source hashes are unchanged from before setup through final verification")
	var receipt := {
		"schema_version": 2, "profile_version": "immutable-topology-candidate-v2",
		"engine": Engine.get_version_info().get("string", ""),
		"map_hash": definition.map_hash, "definition_hash": definition.definition_hash,
		"paid_steps": PAID_STEPS, "warmup_ticks": WARMUP_TICKS,
		"cold_samples": COLD_SAMPLES, "warm_pairs": WARM_PAIRS, "hash_pairs": HASH_PAIRS,
		"cases": cases, "source_sha256": source_before,
		"source_sha256_before": source_before, "source_sha256_after": source_after,
		"sources_unchanged": sources_unchanged, "receipt_complete": complete,
		"diagnostic_status": "PASS" if failures == 0 else "FAIL",
		"assertions": assertions, "failures": failures,
		"scope": "NON-SHIPPING S1/S2 representation experiment. Same unchanged eight-champion paid fixture, distributed and dense, both input orders; no resource/capacity/state injection. Every paid tick imports through strict chemistry producer roundtrip and compares a detached sparse-state legacy projection with the independent frozen canonical oracle. This is not a separately advancing candidate simulation.",
		"timing_semantics": "Cold topology admission, strict source import, warm full-cell versus sparse-state clone, full legacy hash projection, and destruction are separate stages. Alternating AB/BA pairs compare identical states. Warm clone excludes topology admission/import and collision, rendering, actors, packets, sockets, and prediction integration. Candidate legacy projection/prepare still allocate full topology. No nested percentile totals are reported.",
		"memory_semantics": "OS static memory and process-global peak are sampled outside timers; unavailable nonpositive readings are null. These are observations, not allocation counts or candidate-attributable peaks. Sparse owner/cell counts are exact representation counts; occupied includes zero quantities. Frozen topology byte storage uses a read-only integer Array, not a proposed production compact layout.",
		"percentile_limit": "Three cold/hash samples and twenty warm samples per arm per state; p95/p99 are sample-limited, often the maximum, not tail-capacity estimates.",
		"performance_acceptance": "NOT_ESTABLISHED. This prototype does not change production storage/codec/hash, resolve dense 120Hz simulation cost, prove 60Hz snapshots, or enable 16/32/64 players.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "candidate receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: immutable-topology-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _candidate_case(case_name: String, reverse_order: bool) -> Dictionary:
	print("IMMUTABLE_TOPOLOGY stage=fixture case=%s reverse=%s" % [case_name, str(reverse_order)])
	var fixture: Dictionary = _fixture(case_name)
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	var topology_samples := PackedInt64Array()
	var topology := {}
	var admission_memory := _memory_observation()
	for unused: int in COLD_SAMPLES:
		var started := Time.get_ticks_usec()
		var admitted := Candidate.admit_topology(world.hex_court, definition.map_hash, definition.definition_hash)
		topology_samples.append(Time.get_ticks_usec() - started)
		_check(not admitted.is_empty(), "candidate cold topology admits")
		if not topology.is_empty(): _check(admitted == topology, "independent cold admissions agree")
		topology = admitted
	if topology.is_empty(): return {"case": case_name, "reverse": reverse_order, "trace": []}
	var empty_pair := _paired_state("empty", world.hex_court, topology)
	for unused: int in WARMUP_TICKS:
		_check(world.step(_commands(world, targets, case_name, false, reverse_order)), "candidate neutral warmup advances")
	var trace: Array[Dictionary] = []
	var per_tick_import := PackedInt64Array()
	for index: int in PAID_STEPS:
		_check(world.step(_commands(world, targets, case_name, true, reverse_order)), "unchanged paid tick advances")
		var started := Time.get_ticks_usec()
		var state := Candidate.import_world(world.hex_court, topology, definition.map_hash, definition.definition_hash)
		per_tick_import.append(Time.get_ticks_usec() - started)
		_check(not state.is_empty(), "mutating paid state imports strictly")
		if state.is_empty(): break
		_check(Candidate.legacy_bytes(state) == FrozenOracle.frozen_original_bytes(world.hex_court), "per-tick complete chemistry canonical bytes match independent oracle")
		trace.append({"tick": world.tick, "state_hash": world.state_hash(), "events": HexChemistryWorld._stable(world.combat_events)})
		if index % 10 == 9: print("IMMUTABLE_TOPOLOGY stage=paid_trace case=%s reverse=%s step=%d" % [case_name, str(reverse_order), index + 1])
	_check(trace.size() == PAID_STEPS, "candidate retains every paid tick trace")
	_check(world.hex_court.metrics.matter_paid > 0 and world.hex_court.metrics.admitted > 0, "candidate workload contains ordinary paid admission")
	var paid_pair := _paired_state("paid-final", world.hex_court, topology)
	return {
		"completed": true, "case": case_name, "reverse_command_order": reverse_order,
		"topology_cells": topology.numeric_cells.size(), "topology_bytes": topology.byte_values.size(),
		"topology_fingerprint": topology.fingerprint,
		"cold_topology_admission": _stage(topology_samples),
		"admission_memory_before": admission_memory, "memory_after": _memory_observation(),
		"empty": empty_pair, "paid_final": paid_pair,
		"mutating_per_tick_strict_import": _stage(per_tick_import),
		"paid_metrics": world.hex_court.metrics.duplicate(true), "trace": trace,
	}


func _paired_state(label: String, world: HexChemistryWorld, topology: Dictionary) -> Dictionary:
	var expected := FrozenOracle.frozen_original_bytes(world)
	var imports := PackedInt64Array()
	var state := {}
	for unused: int in COLD_SAMPLES:
		var started := Time.get_ticks_usec()
		var imported := Candidate.import_world(world, topology, definition.map_hash, definition.definition_hash)
		imports.append(Time.get_ticks_usec() - started)
		_check(not imported.is_empty(), label + " strict import succeeds")
		state = imported
	if state.is_empty(): return {}
	_check(Candidate.legacy_bytes(state) == expected, label + " cold import matches complete frozen oracle")
	var clone_times := {"legacy": PackedInt64Array(), "candidate": PackedInt64Array()}
	var disposal_times := {"legacy": PackedInt64Array(), "candidate": PackedInt64Array()}
	var live_memory: Array[Dictionary] = []
	for pair: int in WARM_PAIRS:
		var order: Array[String] = []
		order.assign(["legacy", "candidate"] if pair % 2 == 0 else ["candidate", "legacy"])
		for arm: String in order:
			var before_memory := _memory_observation()
			var started := Time.get_ticks_usec()
			var copy: Dictionary = _legacy_clone(world) if arm == "legacy" else Candidate.clone_state(state)
			var elapsed := Time.get_ticks_usec() - started
			var samples: PackedInt64Array = clone_times[arm]
			samples.append(elapsed)
			clone_times[arm] = samples
			live_memory.append({"pair": pair, "arm": arm, "before": before_memory, "with_clone": _memory_observation()})
			# Compare outside timers, and only once per arm: every later call clones
			# the same state; per-tick mutating import equality is a separate gate.
			if pair == 0:
				if arm == "candidate":
					_check(Candidate.legacy_bytes(copy) == expected and is_same(copy.topology, topology), label + " warm candidate clone is exact and shares immutable topology")
				else:
					_check(copy.cells == world.cells and copy.casts == world.casts, label + " full-cell clone is exact")
			started = Time.get_ticks_usec()
			copy.clear()
			elapsed = Time.get_ticks_usec() - started
			var disposal: PackedInt64Array = disposal_times[arm]
			disposal.append(elapsed)
			disposal_times[arm] = disposal
	var hash_times := {"legacy": PackedInt64Array(), "candidate": PackedInt64Array()}
	for pair: int in HASH_PAIRS:
		var order: Array[String] = []
		order.assign(["legacy", "candidate"] if pair % 2 == 0 else ["candidate", "legacy"])
		for arm: String in order:
			var started := Time.get_ticks_usec()
			var bytes: PackedByteArray = FrozenOracle.frozen_original_bytes(world) if arm == "legacy" else Candidate.legacy_bytes(state)
			var samples: PackedInt64Array = hash_times[arm]
			samples.append(Time.get_ticks_usec() - started)
			hash_times[arm] = samples
			_check(bytes == expected, label + " paired compatibility projection remains byte-identical")
	_check(FrozenOracle.frozen_original_bytes(world) == expected, label + " paired stages never mutate source")
	var owners := 0
	var zero_owners := 0
	for layers: Dictionary in state.materials.values():
		for entries: Dictionary in layers.values():
			owners += entries.size()
			for amount: int in entries.values():
				if amount == 0: zero_owners += 1
	return {
		"completed": true, "state": label, "topology_cells": topology.numeric_cells.size(), "sparse_cells_including_zero_coverage": state.materials.size(),
		"reverse_owner_entries": owners, "zero_quantity_owner_entries": zero_owners,
		"casts": state.casts.size(), "products": state.products.size(), "legacy_canonical_bytes": expected.size(),
		"strict_import": _stage(imports),
		"warm_clone": {"legacy_full_cells": _stage(clone_times.legacy), "candidate_shared_topology": _stage(clone_times.candidate)},
		"clone_disposal": {"legacy_full_cells": _stage(disposal_times.legacy), "candidate_shared_topology": _stage(disposal_times.candidate)},
		"compatibility_canonical_projection": {"frozen_legacy": _stage(hash_times.legacy), "candidate_full_legacy_projection": _stage(hash_times.candidate)},
		"live_memory_observations": live_memory,
	}


func _legacy_clone(world: HexChemistryWorld) -> Dictionary:
	var result := {"origin": world.origin, "cells": world.cells.duplicate(true)}
	for field: String in Candidate.DYNAMIC: result[field] = (world.get(field) as Dictionary).duplicate(true)
	for field: String in Candidate.SCALARS: result[field] = world.get(field)
	return result


func _stage(values: PackedInt64Array) -> Dictionary:
	return {"statistics_us": _percentiles(values), "samples_us": Array(values)}


func _memory_observation() -> Dictionary:
	var current := OS.get_static_memory_usage()
	var peak := OS.get_static_memory_peak_usage()
	return {"static_bytes": current if current > 0 else null, "process_global_peak_bytes": peak if peak > 0 else null}


# Independent fail-closed receipt checks. A GDScript helper runtime error may
# return an empty value without raising our assertion counter; therefore only a
# complete, exact-shape result can contribute to a successful diagnostic.
func _cases_complete(values: Array[Dictionary]) -> bool:
	if values.size() != CASES.size() * 2: return false
	for case_index: int in CASES.size():
		if not _case_complete(values[case_index * 2], CASES[case_index], false): return false
		if not _case_complete(values[case_index * 2 + 1], CASES[case_index], true): return false
		if values[case_index * 2].trace != values[case_index * 2 + 1].trace: return false
	return true


func _completeness_guards_reject_truncation(values: Array[Dictionary]) -> bool:
	var missing_case := values.duplicate(true)
	missing_case.pop_back()
	if _cases_complete(missing_case): return false
	var empty_helper := values.duplicate(true)
	empty_helper[0].empty = {}
	if _cases_complete(empty_helper): return false
	var missing_sample := values.duplicate(true)
	missing_sample[0].paid_final.warm_clone.legacy_full_cells.samples_us.pop_back()
	if _cases_complete(missing_sample): return false
	var wrong_identity := values.duplicate(true)
	wrong_identity[0]["case"] = "unexpected-case"
	if _cases_complete(wrong_identity): return false
	var wrong_order := values.duplicate(true)
	wrong_order[0].reverse_command_order = true
	if _cases_complete(wrong_order): return false
	var wrong_stats := values.duplicate(true)
	wrong_stats[0].empty.strict_import.statistics_us.samples += 1
	if _cases_complete(wrong_stats): return false
	var missing_trace := values.duplicate(true)
	missing_trace[0].trace.pop_back()
	if _cases_complete(missing_trace): return false
	return true


func _case_complete(value: Dictionary, case_name: String, reverse_order: bool) -> bool:
	if value.get("completed") != true or value.get("case") != case_name: return false
	if typeof(value.get("reverse_command_order")) != TYPE_BOOL or value.reverse_command_order != reverse_order: return false
	if value.get("topology_cells", -1) != definition.eligible_cells.size(): return false
	if value.get("topology_bytes", -1) != (3 + definition.eligible_cells.size() * 5) * 8: return false
	if not _sha256_valid(value.get("topology_fingerprint")): return false
	if not _stage_complete(value.get("cold_topology_admission"), COLD_SAMPLES): return false
	if not _stage_complete(value.get("mutating_per_tick_strict_import"), PAID_STEPS): return false
	if not _paired_complete(value.get("empty"), "empty"): return false
	if not _paired_complete(value.get("paid_final"), "paid-final"): return false
	if not _memory_complete(value.get("admission_memory_before")) or not _memory_complete(value.get("memory_after")): return false
	var metrics: Variant = value.get("paid_metrics")
	if not metrics is Dictionary or metrics.get("matter_paid", 0) <= 0 or metrics.get("admitted", 0) <= 0: return false
	var rows: Variant = value.get("trace")
	if not rows is Array or rows.size() != PAID_STEPS: return false
	for index: int in rows.size():
		var row: Variant = rows[index]
		if not row is Dictionary or row.size() != 3 or row.get("tick", -1) != WARMUP_TICKS + index + 1: return false
		if not _sha256_valid(row.get("state_hash")) or not row.get("events") is Array: return false
	return true


func _paired_complete(value: Variant, label: String) -> bool:
	if not value is Dictionary or value.get("completed") != true or value.get("state") != label: return false
	if value.get("topology_cells", -1) != definition.eligible_cells.size(): return false
	for key: String in ["sparse_cells_including_zero_coverage", "reverse_owner_entries", "zero_quantity_owner_entries", "casts", "products", "legacy_canonical_bytes"]:
		if typeof(value.get(key)) != TYPE_INT or value[key] < 0: return false
	if value.legacy_canonical_bytes <= 0 or value.sparse_cells_including_zero_coverage > value.topology_cells: return false
	if value.zero_quantity_owner_entries > value.reverse_owner_entries: return false
	if not _stage_complete(value.get("strict_import"), COLD_SAMPLES): return false
	for category: String in ["warm_clone", "clone_disposal"]:
		var stages: Variant = value.get(category)
		if not stages is Dictionary or stages.size() != 2: return false
		if not _stage_complete(stages.get("legacy_full_cells"), WARM_PAIRS): return false
		if not _stage_complete(stages.get("candidate_shared_topology"), WARM_PAIRS): return false
	var hashes: Variant = value.get("compatibility_canonical_projection")
	if not hashes is Dictionary or hashes.size() != 2: return false
	if not _stage_complete(hashes.get("frozen_legacy"), HASH_PAIRS): return false
	if not _stage_complete(hashes.get("candidate_full_legacy_projection"), HASH_PAIRS): return false
	var memory: Variant = value.get("live_memory_observations")
	if not memory is Array or memory.size() != WARM_PAIRS * 2: return false
	for index: int in memory.size():
		var row: Variant = memory[index]
		var pair: int = index >> 1
		var first_arm := "legacy" if pair % 2 == 0 else "candidate"
		var expected_arm := first_arm if index % 2 == 0 else ("candidate" if first_arm == "legacy" else "legacy")
		if not row is Dictionary or row.size() != 4 or row.get("pair", -1) != pair or row.get("arm") != expected_arm: return false
		if not _memory_complete(row.get("before")) or not _memory_complete(row.get("with_clone")): return false
	return true


func _stage_complete(value: Variant, expected_samples: int) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	var raw: Variant = value.get("samples_us")
	var stats: Variant = value.get("statistics_us")
	if not raw is Array or raw.size() != expected_samples or not stats is Dictionary: return false
	for sample: Variant in raw:
		if typeof(sample) != TYPE_INT or sample < 0: return false
	return stats == _percentiles(PackedInt64Array(raw))


func _memory_complete(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	for key: String in ["static_bytes", "process_global_peak_bytes"]:
		if not value.has(key): return false
		if value[key] != null and (typeof(value[key]) != TYPE_INT or value[key] <= 0): return false
	return true


func _source_hashes_valid(values: Dictionary) -> bool:
	if values.is_empty(): return false
	for hash_value: Variant in values.values():
		if not _sha256_valid(hash_value): return false
	return true


func _sha256_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for index: int in value.length():
		if value[index] not in "0123456789abcdef": return false
	return true


func _candidate_sources() -> Dictionary:
	var result := _source_hashes()
	for path: String in [
		"tests/support/hex_immutable_topology_candidate.gd",
		"tests/support/hex_stable_cells_candidate.gd",
		"tests/unit/test_hex_immutable_topology_candidate.gd",
		"tests/performance/profile_immutable_topology_candidate.gd",
		"src/net/hex_chemistry_snapshot.gd", "src/sim/hex/hex_world_definition.gd",
	]: result[path] = FileAccess.get_sha256("res://" + path)
	return result
