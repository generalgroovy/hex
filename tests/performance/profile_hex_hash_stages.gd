extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Read-only decomposition of the exact current HexChemistryWorld.state_hash.
# The reconstructed canonical bytes and SHA must equal the production method;
# all equality and source-preservation checks stay outside stage timers.
const Canonical = preload("res://src/sim/core/canonical_bytes.gd")
const ACTIVE_WORKLOAD_TICKS := 40
const EXPECTED_TOPOLOGY_CELLS := 2_766
const EXPECTED_ACTIVE_CELLS := 29
const CYCLES := 6
const SAMPLES_PER_BLOCK := 7
const STAGES: Array[String] = ["production_total", "compact_projection", "stable", "json", "canonical_sha"]
const FRAME_BUDGET_US := 16_667


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-hash-stages-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"hash-stage receipt path is fresh and scoped",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "normal campus supplies the exact 2,766-cell topology")
	if failures > 0:
		_finish({})
		return

	var empty_fixture: Dictionary = _fixture("dense-crucible")
	var empty_world: SimWorld = empty_fixture.world
	var empty_occupancy: Dictionary = _occupancy(empty_world.hex_court, empty_world.tick)
	_check(empty_world.hex_court.cells.size() == EXPECTED_TOPOLOGY_CELLS, "empty case retains the complete production topology")
	_check(empty_world.hex_court.casts.is_empty() and empty_world.hex_court.products.is_empty(), "empty case contains no paid chemistry records")
	_check(int(empty_occupancy.active_cells) == 0 and _nonempty_material_cells(empty_world.hex_court) == 0, "empty case has no active or stored material cells")

	var active_fixture: Dictionary = _fixture("dense-crucible")
	var active_world: SimWorld = active_fixture.world
	var targets: Dictionary = active_fixture.targets
	for unused: int in range(WARMUP_TICKS):
		_check(active_world.step(_commands(active_world, targets, "dense-crucible", false, false)), "legal workload warmup advances")
	for unused: int in range(ACTIVE_WORKLOAD_TICKS):
		_check(active_world.step(_commands(active_world, targets, "dense-crucible", true, false)), "legal paid workload advances")
	var active_occupancy: Dictionary = _occupancy(active_world.hex_court, active_world.tick)
	_check(active_world.hex_court.cells.size() == EXPECTED_TOPOLOGY_CELLS, "active case retains the complete production topology")
	_check(int(active_world.hex_court.metrics.admitted) == 8 and int(active_world.hex_court.metrics.matter_paid) == 4_800, "active case uses the existing eight-admission paid workload")
	_check(int(active_occupancy.active_cells) == EXPECTED_ACTIVE_CELLS, "active case has the measured 29 active cells")
	_check(active_world.hex_court.conservation_valid(), "active case conserves paid matter")

	var cases: Array[Dictionary] = [
		_profile_case("production-empty", empty_world.hex_court, empty_occupancy),
		_profile_case("legal-paid-29-active", active_world.hex_court, active_occupancy),
	]
	var receipt := {
		"schema_version": 1,
		"profile_version": "hex-hash-stages-v1",
		"engine": Engine.get_version_info().get("string", ""),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"map_path": "res://content/maps/sanctum_campus_g2_v1.json",
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"topology_cells": EXPECTED_TOPOLOGY_CELLS,
		"warmup_ticks": WARMUP_TICKS,
		"active_workload_ticks": ACTIVE_WORKLOAD_TICKS,
		"cycles": CYCLES,
		"samples_per_block": SAMPLES_PER_BLOCK,
		"samples_per_stage_per_case": CYCLES * SAMPLES_PER_BLOCK,
		"stage_order": "One block per stage per cycle; cyclic start rotates each cycle and traversal alternates forward/reverse.",
		"cases": cases,
		"source_sha256": _hash_stage_source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless read-only decomposition of the exact current HexChemistryWorld.state_hash on the production 2,766-cell empty authority and the existing legal dense-crucible authority after 120 warmup plus 40 paid ticks (29 active cells). Each timed sample contains only the named stage. Fixtures, references, equality, byte/hash checks, source hashes and mutation checks are outside timers.",
		"timing_limit": "Stages are isolated and intentionally non-additive: each downstream stage receives its prepared input outside the timer. p99 is the sample-limited nearest-rank maximum of 42 samples. No allocation, frame, 120 Hz, networking, export or capacity claim is made.",
	}
	_finish(receipt)


func _profile_case(case_name: String, court: HexChemistryWorld, occupancy: Dictionary) -> Dictionary:
	var source_identity := court.get_instance_id()
	var source_cells: Dictionary = court.cells.duplicate(true)
	var source_hash := court.state_hash()
	var reference_compact := _reference_compact_projection(court)
	var compact := _compact_projection(court)
	_check(compact == reference_compact, case_name + " compact projection equals the complete interpreted reference")
	var raw_value: Array = _state_value(court, compact)
	var stable_value: Variant = HexChemistryWorld._stable(raw_value)
	var json_value := JSON.stringify(stable_value)
	var canonical_bytes := _canonical_bytes(json_value)
	var reconstructed_hash := Canonical.sha256_hex(canonical_bytes)
	_check(not canonical_bytes.is_empty(), case_name + " reconstructed canonical byte stream is nonempty")
	_check(reconstructed_hash == source_hash, case_name + " reconstructed canonical bytes produce the exact production state hash")
	_check(Canonical.sha256_hex(_canonical_bytes(JSON.stringify(HexChemistryWorld._stable(_state_value(court, reference_compact))))) == source_hash, case_name + " independent full projection produces the exact production state hash")

	var all_samples := {}
	var blocks: Array[Dictionary] = []
	for stage: String in STAGES:
		all_samples[stage] = PackedInt64Array()
	for cycle: int in CYCLES:
		var order := _stage_order(cycle)
		_check(order.size() == STAGES.size(), case_name + " cycle %d schedules every stage" % cycle)
		for block_index: int in order.size():
			var stage: String = order[block_index]
			var samples := _measure_stage_block(case_name, stage, court, raw_value, stable_value, json_value, compact, canonical_bytes, source_hash)
			_check(samples.size() == SAMPLES_PER_BLOCK, "%s %s cycle %d has every sample" % [case_name, stage, cycle])
			var combined: PackedInt64Array = all_samples[stage]
			combined.append_array(samples)
			all_samples[stage] = combined
			blocks.append({"cycle": cycle, "block": block_index, "stage": stage, "samples_us": Array(samples), "statistics_us": _hash_statistics(samples)})
			_check(court.get_instance_id() == source_identity, "%s %s cycle %d retains source identity" % [case_name, stage, cycle])
			_check(court.cells == source_cells and court.state_hash() == source_hash, "%s %s cycle %d leaves source authority unchanged" % [case_name, stage, cycle])

	var stages := {}
	for stage: String in STAGES:
		var samples: PackedInt64Array = all_samples[stage]
		_check(samples.size() == CYCLES * SAMPLES_PER_BLOCK, case_name + " " + stage + " has all 42 samples")
		stages[stage] = {"statistics_us": _hash_statistics(samples), "samples_us": Array(samples)}
	_check(blocks.size() == CYCLES * STAGES.size(), case_name + " has every scheduled stage block")
	_check(court.cells == source_cells and court.state_hash() == source_hash, case_name + " complete profile preserves exact source state")
	return {
		"case": case_name,
		"topology_cells": court.cells.size(),
		"world_tick": court.current_tick,
		"occupancy": occupancy.duplicate(true),
		"nonempty_material_cells": _nonempty_material_cells(court),
		"authority_hash": source_hash,
		"canonical_bytes": canonical_bytes.size(),
		"blocks": blocks,
		"stages": stages,
	}


func _measure_stage_block(case_name: String, stage: String, court: HexChemistryWorld, raw_value: Array, stable_value: Variant, json_value: String, expected_compact: Dictionary, expected_bytes: PackedByteArray, expected_hash: String) -> PackedInt64Array:
	var samples := PackedInt64Array()
	for sample_index: int in SAMPLES_PER_BLOCK:
		var started := Time.get_ticks_usec()
		var actual: Variant
		match stage:
			"production_total": actual = court.state_hash()
			"compact_projection": actual = _compact_projection(court)
			"stable": actual = HexChemistryWorld._stable(raw_value)
			"json": actual = JSON.stringify(stable_value)
			"canonical_sha": actual = _hash_json(json_value)
			_: actual = null
		samples.append(Time.get_ticks_usec() - started)
		match stage:
			"production_total", "canonical_sha": _check(actual == expected_hash, "%s %s sample %d returns the exact production hash" % [case_name, stage, sample_index])
			"compact_projection": _check(actual == expected_compact, "%s compact sample %d returns the exact sparse projection" % [case_name, sample_index])
			"stable": _check(actual == stable_value, "%s stable sample %d returns the exact canonical value" % [case_name, sample_index])
			"json": _check(actual == json_value and _canonical_bytes(String(actual)) == expected_bytes, "%s JSON sample %d returns the exact canonical bytes" % [case_name, sample_index])
	return samples


func _compact_projection(court: HexChemistryWorld) -> Dictionary:
	var compact_cells := {}
	var empty_cell := HexChemistryWorld._new_empty_cell()
	for cell: Vector2i in court.cells:
		var record: Dictionary = court.cells[cell]
		var empty_compact := {}
		for metadata_key: String in ["terrain", "elevation", "structure"]:
			var metadata_value: Variant = record.get(metadata_key)
			empty_cell[metadata_key] = metadata_value
			if not metadata_value is Dictionary or not metadata_value.is_empty():
				empty_compact[metadata_key] = metadata_value
		if record == empty_cell:
			compact_cells[cell] = empty_compact
			continue
		var compact := {}
		for key: String in record:
			var value: Variant = record[key]
			if not value is Dictionary or not value.is_empty():
				compact[key] = value
		compact_cells[cell] = compact
	return compact_cells


func _reference_compact_projection(court: HexChemistryWorld) -> Dictionary:
	var compact_cells := {}
	for cell: Vector2i in court.cells:
		var compact := {}
		var record: Dictionary = court.cells[cell]
		for key: String in record:
			var value: Variant = record[key]
			if not value is Dictionary or not value.is_empty():
				compact[key] = value
		compact_cells[cell] = compact
	return compact_cells


func _state_value(court: HexChemistryWorld, compact_cells: Dictionary) -> Array:
	return [court.origin, court.current_tick, court.chemistry_enabled, court.next_cast_id, court.next_product_id, court.next_ground_part_id, compact_cells, court.casts, court.products, court.pending, court.sources, court.exposure, court.flow_carry, court.metrics]


func _canonical_bytes(json_value: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	Canonical.append_string(bytes, json_value)
	return bytes


func _hash_json(json_value: String) -> String:
	return Canonical.sha256_hex(_canonical_bytes(json_value))


func _stage_order(cycle: int) -> Array[String]:
	var result: Array[String] = []
	var direction := 1 if cycle % 2 == 0 else -1
	for offset: int in STAGES.size():
		result.append(STAGES[posmod(cycle + direction * offset, STAGES.size())])
	return result


func _nonempty_material_cells(court: HexChemistryWorld) -> int:
	var result := 0
	var layers: Array[String] = HexChemistryWorld.material_layers()
	for cell: Vector2i in court.cells:
		for layer: String in layers:
			var layer_value: Dictionary = court.cells[cell][layer]
			if not layer_value.is_empty():
				result += 1
				break
	return result


func _hash_statistics(values: PackedInt64Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {"samples": 0, "min": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0, "over_8333_us": 0, "over_16667_us": 0}
	var tick_misses := 0
	var frame_misses := 0
	for value: int in ordered:
		tick_misses += int(value > TICK_BUDGET_US)
		frame_misses += int(value > FRAME_BUDGET_US)
	return {
		"samples": ordered.size(),
		"min": ordered[0],
		"p50": ordered[_percentile_index(ordered.size(), 50)],
		"p95": ordered[_percentile_index(ordered.size(), 95)],
		"p99": ordered[_percentile_index(ordered.size(), 99)],
		"max": ordered[-1],
		"over_8333_us": tick_misses,
		"over_16667_us": frame_misses,
	}


func _hash_stage_source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_hex_hash_stages.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/core/canonical_bytes.gd",
		"src/sim/core/sim_world.gd",
		"src/sim/hex/hex_world_definition.gd",
		"content/abilities/foundation_abilities_v1.json",
		"content/champions/foundation_champions_v1.json",
		"content/maps/sanctum_campus_g2_v1.json",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _finish(receipt: Dictionary) -> void:
	if not receipt.is_empty() and not output_path.is_empty():
		receipt.assertions = assertions
		receipt.failures = failures
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "hash-stage receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-hash-stages; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
