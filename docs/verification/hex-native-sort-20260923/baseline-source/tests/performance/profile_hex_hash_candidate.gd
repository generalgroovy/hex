extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Test-only ABBA comparison of the frozen current state_hash implementation and
# a byte-identical empty-cell stable-value specialization. Runtime is untouched.
const Candidate = preload("res://tests/support/hex_stable_cells_candidate.gd")
const ACTIVE_WORKLOAD_TICKS := 40
const EXPECTED_TOPOLOGY_CELLS := 2_766
const EXPECTED_ACTIVE_CELLS := 29
const CYCLES := 4
const SAMPLES_PER_BLOCK := 7
const BLOCKS_PER_CYCLE := 4
const FRAME_BUDGET_US := 16_667
const EXPECTED_EQUIVALENCE_CASES := 38
const EXPECTED_PROFILE_CASES := 3
const EXPECTED_BLOCKS_PER_PROFILE_CASE := CYCLES * BLOCKS_PER_CYCLE
const EXPECTED_SAMPLES_PER_IMPLEMENTATION := CYCLES * 2 * SAMPLES_PER_BLOCK

var equivalence_cases_completed := 0
var profile_cases_completed := 0


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-hash-candidate-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"candidate receipt path is fresh and scoped",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "normal campus supplies the exact 2,766-cell topology")
	if failures > 0:
		_finish({})
		return

	_equivalence_cases()
	_check(equivalence_cases_completed == EXPECTED_EQUIVALENCE_CASES, "all %d equivalence cases complete" % EXPECTED_EQUIVALENCE_CASES)
	if failures > 0:
		_finish({})
		return

	var empty_fixture: Dictionary = _fixture("dense-crucible")
	var empty_world: SimWorld = empty_fixture.world
	var empty_occupancy: Dictionary = _occupancy(empty_world.hex_court, empty_world.tick)
	_check(int(empty_occupancy.active_cells) == 0 and _nonempty_material_cells(empty_world.hex_court) == 0, "empty profile case has no material cells")

	var active_fixture: Dictionary = _fixture("dense-crucible")
	var active_world: SimWorld = active_fixture.world
	var targets: Dictionary = active_fixture.targets
	for unused: int in range(WARMUP_TICKS):
		_check(active_world.step(_commands(active_world, targets, "dense-crucible", false, false)), "legal workload warmup advances")
	for unused: int in range(ACTIVE_WORKLOAD_TICKS):
		_check(active_world.step(_commands(active_world, targets, "dense-crucible", true, false)), "legal paid workload advances")
	var active_occupancy: Dictionary = _occupancy(active_world.hex_court, active_world.tick)
	_check(int(active_world.hex_court.metrics.admitted) == 8 and int(active_world.hex_court.metrics.matter_paid) == 4_800, "legal profile case retains eight paid admissions")
	_check(int(active_occupancy.active_cells) == EXPECTED_ACTIVE_CELLS and active_world.hex_court.conservation_valid(), "legal profile case retains 29 active cells and conservation")

	var dense_fixture: Dictionary = _fixture("dense-crucible")
	var dense_world: SimWorld = dense_fixture.world
	var dense_court: HexChemistryWorld = dense_world.hex_court
	var material: String = HexChemistryWorld.material_layers()[0]
	var dense_index := 0
	for cell: Vector2i in dense_court.cells:
		dense_court.cells[cell][material][900_000 + dense_index] = dense_index + 1
		dense_index += 1
	_check(_nonempty_material_cells(dense_court) == EXPECTED_TOPOLOGY_CELLS, "dense pressure case makes every topology record nonempty")

	var cases: Array[Dictionary] = [
		_profile_case("production-empty", empty_world.hex_court, empty_occupancy),
		_profile_case("legal-paid-29-active", active_world.hex_court, active_occupancy),
		_profile_case("synthetic-all-nonempty", dense_court, {"active_cells": 0, "source_quantity": 0, "product_quantity": 0}),
	]
	var expected_case_names: Array[String] = ["production-empty", "legal-paid-29-active", "synthetic-all-nonempty"]
	_check(profile_cases_completed == EXPECTED_PROFILE_CASES, "all %d profile cases complete" % EXPECTED_PROFILE_CASES)
	_check(cases.size() == EXPECTED_PROFILE_CASES, "receipt has all %d profile cases" % EXPECTED_PROFILE_CASES)
	for case_index: int in expected_case_names.size():
		_check(_profile_case_is_complete(cases[case_index], expected_case_names[case_index]), "%s profile result is populated with every block and sample" % expected_case_names[case_index])
	if failures > 0:
		_finish({})
		return
	var receipt := {
		"schema_version": 1,
		"profile_version": "hex-hash-candidate-abba-v2",
		"engine": Engine.get_version_info().get("string", ""),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"map_path": "res://content/maps/sanctum_campus_g2_v1.json",
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"topology_cells": EXPECTED_TOPOLOGY_CELLS,
		"warmup_ticks": WARMUP_TICKS,
		"active_workload_ticks": ACTIVE_WORKLOAD_TICKS,
		"cycles": CYCLES,
		"blocks_per_cycle": BLOCKS_PER_CYCLE,
		"samples_per_block": SAMPLES_PER_BLOCK,
		"samples_per_implementation_per_case": CYCLES * 2 * SAMPLES_PER_BLOCK,
		"equivalence_cases_completed": equivalence_cases_completed,
		"profile_cases_completed": profile_cases_completed,
		"expected_blocks_per_profile_case": EXPECTED_BLOCKS_PER_PROFILE_CASE,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"cases": cases,
		"source_sha256": _candidate_source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless read-only ABBA comparison of the actual current HexChemistryWorld.state_hash and a test-only byte-identical empty integral cell stable-value specialization. An independent frozen copy of the full current bytes/hash logic is an outside-timer oracle. Cases use the production empty topology, existing legal 29-active-cell paid workload, and synthetic all-nonempty fallback pressure. Fixtures, warmup, bytes/hash equivalence, malformed/reordered/mutation cases and source checks are outside timers.",
		"timing_limit": "Each implementation has 56 samples per case. p99 is the sample-limited nearest-rank maximum. The dense case is invalid chemistry authority used only to quantify fallback pressure. No allocation, frame, 120 Hz, networking, export or capacity claim is made.",
	}
	_finish(receipt)


func _equivalence_cases() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, -7), Vector2i(-12, 4), Vector2i.ZERO, Vector2i(-2, -11)]
	var world := HexChemistryWorld.new()
	_check(world.configure_geometry(Vector2i(-240_000, 360_000), cells), "equivalence fixture accepts negative and reordered cells")
	world.cells[Vector2i(3, -7)].terrain = -17
	world.cells[Vector2i(-12, 4)].elevation = 9
	world.cells[Vector2i.ZERO].structure = 4
	_assert_equivalent(world, "integral metadata and negative cells")
	var original_hash := world.state_hash()
	var reversed := {}
	for index: int in range(cells.size() - 1, -1, -1):
		reversed[cells[index]] = world.cells[cells[index]]
	world.cells = reversed
	_assert_equivalent(world, "reordered cell insertion")
	_check(world.state_hash() == original_hash, "reordered insertion preserves the published hash")

	world.cells[cells[0]]["extra_scalar"] = 17
	world.cells[cells[1]]["extra_empty"] = {}
	world.cells[cells[2]]["extra_mixed"] = {4: ["opaque", null, true], "4": {Vector2i(-1, 2): false}, Vector2i(4, -3): [1, {2: "nested"}]}
	world.cells[cells[3]][HexChemistryWorld.material_layers()[0]][77_001] = 23
	_assert_equivalent(world, "extras mixed nested values and nonempty layer fallback")

	world.cells[cells[0]].terrain = {}
	world.cells[cells[1]].elevation = [3, null, {2: false}]
	world.cells[cells[2]].erase("structure")
	_assert_equivalent(world, "malformed and missing metadata fallback")

	var before_cells: Dictionary = world.cells.duplicate(true)
	var before_hash := world.state_hash()
	var nested: Dictionary = world.cells[cells[2]].extra_mixed
	nested["mutation"] = [Vector2i(8, -5), {9: "visible"}]
	var mutated_hash := world.state_hash()
	_check(mutated_hash != before_hash, "nested public mutation is visible to the next hash call")
	_assert_equivalent(world, "between-call nested mutation")
	world.cells = before_cells
	_assert_equivalent(world, "restored nested authority")
	_check(world.state_hash() == before_hash, "deep restoration recovers the original published hash")

	var malformed_metadata_values: Array[Dictionary] = [
		{"type": "float", "value": 2.5},
		{"type": "boolean", "value": true},
		{"type": "null", "value": null},
		{"type": "string", "value": "direct-metadata"},
	]
	var metadata_keys: Array[String] = ["terrain", "elevation", "structure"]
	var malformed_metadata_cells: Array[Vector2i] = [Vector2i(-5, 8)]
	for metadata_key: String in metadata_keys:
		for value_case: Dictionary in malformed_metadata_values:
			var malformed_metadata_world := HexChemistryWorld.new()
			_check(malformed_metadata_world.configure_geometry(Vector2i(-24_000, 36_000), malformed_metadata_cells), "%s %s metadata fixture configures" % [metadata_key, value_case.type])
			malformed_metadata_world.cells[Vector2i(-5, 8)][metadata_key] = value_case.value
			_assert_equivalent(malformed_metadata_world, "%s metadata with %s value" % [metadata_key, value_case.type])

	var missing_metadata_world := HexChemistryWorld.new()
	var missing_metadata_cells: Array[Vector2i] = [Vector2i(9, -6)]
	_check(missing_metadata_world.configure_geometry(Vector2i(12_000, -18_000), missing_metadata_cells), "missing metadata fixture configures")
	for metadata_key: String in metadata_keys:
		var missing_record: Dictionary = missing_metadata_world.cells[Vector2i(9, -6)].duplicate(true)
		missing_record.erase(metadata_key)
		missing_metadata_world.cells[Vector2i(9, -6)] = missing_record
		_assert_equivalent(missing_metadata_world, "missing %s metadata" % metadata_key)
		missing_metadata_world.cells[Vector2i(9, -6)] = HexChemistryWorld._new_empty_cell()

	var material_layer: String = HexChemistryWorld.material_layers()[0]
	var missing_layer_world := HexChemistryWorld.new()
	var layer_shape_cells: Array[Vector2i] = [Vector2i(6, -9)]
	_check(missing_layer_world.configure_geometry(Vector2i(-30_000, 42_000), layer_shape_cells), "missing material layer fixture configures")
	missing_layer_world.cells[Vector2i(6, -9)].erase(material_layer)
	_assert_equivalent(missing_layer_world, "missing material layer")
	for value_case: Dictionary in malformed_metadata_values:
		var malformed_layer_world := HexChemistryWorld.new()
		_check(malformed_layer_world.configure_geometry(Vector2i(-30_000, 42_000), layer_shape_cells), "malformed material layer %s fixture configures" % value_case.type)
		malformed_layer_world.cells[Vector2i(6, -9)][material_layer] = value_case.value
		_assert_equivalent(malformed_layer_world, "material layer with %s value" % value_case.type)

	for int_key_first: bool in [true, false]:
		var tie_world := HexChemistryWorld.new()
		var tie_cells: Array[Vector2i] = [Vector2i(-4, 11)]
		_check(tie_world.configure_geometry(Vector2i(54_000, -66_000), tie_cells), "%s tie fixture configures" % ("integer-first" if int_key_first else "string-first"))
		var nested_tie := {}
		if int_key_first:
			nested_tie[4] = "integer-key"
			nested_tie["4"] = "string-key"
		else:
			nested_tie["4"] = "string-key"
			nested_tie[4] = "integer-key"
		tie_world.cells[Vector2i(-4, 11)]["equal_format_tie"] = nested_tie
		_assert_equivalent(tie_world, "%s nested integer/string equal-format tie" % ("integer-first" if int_key_first else "string-first"))

	var fast_path_world := HexChemistryWorld.new()
	var fast_path_cells: Array[Vector2i] = [Vector2i(7, -13)]
	_check(fast_path_world.configure_geometry(Vector2i(-72_000, 84_000), fast_path_cells), "empty fast-path mutation fixture configures")
	var fast_path_original_hash := fast_path_world.state_hash()
	for metadata_index: int in 3:
		var metadata_key: String = metadata_keys[metadata_index]
		fast_path_world.cells[Vector2i(7, -13)][metadata_key] = 101 + metadata_index
		_assert_equivalent(fast_path_world, "empty fast-path %s integer mutation" % metadata_key)
		_check(fast_path_world.state_hash() != fast_path_original_hash, "empty fast-path %s integer mutation changes the published hash" % metadata_key)
		fast_path_world.cells[Vector2i(7, -13)][metadata_key] = 0
		_assert_equivalent(fast_path_world, "empty fast-path %s integer restoration" % metadata_key)
		_check(fast_path_world.state_hash() == fast_path_original_hash, "empty fast-path %s integer restoration recovers the published hash" % metadata_key)

	var layer_transition_world := HexChemistryWorld.new()
	var layer_transition_cells: Array[Vector2i] = [Vector2i(-8, 14)]
	_check(layer_transition_world.configure_geometry(Vector2i(90_000, -102_000), layer_transition_cells), "material layer transition fixture configures")
	var layer_transition_original_hash := layer_transition_world.state_hash()
	_assert_equivalent(layer_transition_world, "empty material layer before transition")
	layer_transition_world.cells[Vector2i(-8, 14)][material_layer][880_001] = 37
	_assert_equivalent(layer_transition_world, "material layer empty to nonempty transition")
	_check(layer_transition_world.state_hash() != layer_transition_original_hash, "nonempty material layer changes the published hash")
	layer_transition_world.cells[Vector2i(-8, 14)][material_layer].erase(880_001)
	_assert_equivalent(layer_transition_world, "material layer nonempty to empty restoration")
	_check(layer_transition_world.state_hash() == layer_transition_original_hash, "empty material layer restoration recovers the published hash")

	var empty_cells_world := HexChemistryWorld.new()
	_check(empty_cells_world.cells.is_empty(), "empty cells dictionary fixture starts empty")
	_assert_equivalent(empty_cells_world, "empty cells dictionary")


func _assert_equivalent(court: HexChemistryWorld, label: String) -> void:
	var source_identity := court.get_instance_id()
	var source_cells: Dictionary = court.cells.duplicate(true)
	var production_hash := court.state_hash()
	var original_bytes := Candidate.frozen_original_bytes(court)
	var candidate_bytes := Candidate.candidate_bytes(court)
	_check(not original_bytes.is_empty() and candidate_bytes == original_bytes, label + " candidate preserves exact published bytes")
	_check(Candidate.frozen_original_hash(court) == production_hash, label + " frozen original oracle matches production hash")
	_check(Candidate.candidate_hash(court) == production_hash, label + " candidate matches production hash")
	_check(court.get_instance_id() == source_identity and court.cells == source_cells and court.state_hash() == production_hash, label + " hashing leaves source identity and records unchanged")
	equivalence_cases_completed += 1


func _profile_case(case_name: String, court: HexChemistryWorld, occupancy: Dictionary) -> Dictionary:
	var source_identity := court.get_instance_id()
	var source_cells: Dictionary = court.cells.duplicate(true)
	var production_hash := court.state_hash()
	var original_bytes := Candidate.frozen_original_bytes(court)
	var candidate_bytes := Candidate.candidate_bytes(court)
	_check(candidate_bytes == original_bytes, case_name + " candidate bytes equal the frozen original bytes")
	_check(Candidate.frozen_original_hash(court) == production_hash and Candidate.candidate_hash(court) == production_hash, case_name + " both implementations equal production state_hash")
	for unused: int in 3:
		_check(court.state_hash() == production_hash, case_name + " current production warmup remains exact")
		_check(Candidate.candidate_hash(court) == production_hash, case_name + " candidate warmup remains exact")

	var all_samples := {"production_current": PackedInt64Array(), "candidate": PackedInt64Array()}
	var block_counts := {"production_current": 0, "candidate": 0}
	var blocks: Array[Dictionary] = []
	for cycle: int in CYCLES:
		var order: Array[String] = []
		if cycle % 2 == 0:
			order.assign(["production_current", "candidate", "candidate", "production_current"])
		else:
			order.assign(["candidate", "production_current", "production_current", "candidate"])
		for block_index: int in BLOCKS_PER_CYCLE:
			var implementation: String = order[block_index]
			var samples := _measure_block(case_name, implementation, court, production_hash)
			_check(samples.size() == SAMPLES_PER_BLOCK, "%s %s cycle %d block %d has every sample" % [case_name, implementation, cycle, block_index])
			var combined: PackedInt64Array = all_samples[implementation]
			combined.append_array(samples)
			all_samples[implementation] = combined
			block_counts[implementation] = int(block_counts[implementation]) + 1
			blocks.append({"cycle": cycle, "block": block_index, "implementation": implementation, "samples_us": Array(samples), "statistics_us": _statistics(samples)})
			_check(court.get_instance_id() == source_identity and court.cells == source_cells and court.state_hash() == production_hash, "%s %s cycle %d block %d preserves source" % [case_name, implementation, cycle, block_index])

	var production_samples: PackedInt64Array = all_samples.production_current
	var candidate_samples: PackedInt64Array = all_samples.candidate
	var expected_blocks := CYCLES * BLOCKS_PER_CYCLE / 2
	var expected_samples := expected_blocks * SAMPLES_PER_BLOCK
	_check(blocks.size() == CYCLES * BLOCKS_PER_CYCLE, case_name + " has every ABBA/BAAB block")
	_check(int(block_counts.production_current) == expected_blocks and int(block_counts.candidate) == expected_blocks, case_name + " both implementations have every block")
	_check(production_samples.size() == expected_samples and candidate_samples.size() == expected_samples, case_name + " both implementations have all 56 samples")
	_check(Candidate.candidate_bytes(court) == Candidate.frozen_original_bytes(court), case_name + " post-profile bytes remain exact")
	_check(court.cells == source_cells and court.state_hash() == production_hash, case_name + " complete profile leaves source unchanged")
	var production_stats := _statistics(production_samples)
	var candidate_stats := _statistics(candidate_samples)
	profile_cases_completed += 1
	return {
		"case": case_name,
		"topology_cells": court.cells.size(),
		"world_tick": court.current_tick,
		"occupancy": occupancy.duplicate(true),
		"nonempty_material_cells": _nonempty_material_cells(court),
		"authority_hash": production_hash,
		"canonical_bytes": original_bytes.size(),
		"blocks": blocks,
		"implementations": {
			"production_current": {"statistics_us": production_stats, "samples_us": Array(production_samples)},
			"candidate": {"statistics_us": candidate_stats, "samples_us": Array(candidate_samples)},
		},
		"comparison": {
			"p50_delta_us": int(production_stats.p50) - int(candidate_stats.p50),
			"p95_delta_us": int(production_stats.p95) - int(candidate_stats.p95),
			"p99_delta_us": int(production_stats.p99) - int(candidate_stats.p99),
			"p50_candidate_over_production": float(candidate_stats.p50) / float(maxi(1, int(production_stats.p50))),
			"p95_candidate_over_production": float(candidate_stats.p95) / float(maxi(1, int(production_stats.p95))),
		},
	}


func _profile_case_is_complete(result: Dictionary, expected_name: String) -> bool:
	if result.is_empty() or String(result.get("case", "")) != expected_name:
		return false
	var blocks_value: Variant = result.get("blocks")
	if not blocks_value is Array or blocks_value.size() != EXPECTED_BLOCKS_PER_PROFILE_CASE:
		return false
	for block_value: Variant in blocks_value:
		if not block_value is Dictionary:
			return false
		var block_samples_value: Variant = block_value.get("samples_us")
		if not block_samples_value is Array or block_samples_value.size() != SAMPLES_PER_BLOCK:
			return false
	var implementations_value: Variant = result.get("implementations")
	if not implementations_value is Dictionary:
		return false
	for implementation_name: String in ["production_current", "candidate"]:
		var implementation_value: Variant = implementations_value.get(implementation_name)
		if not implementation_value is Dictionary:
			return false
		var samples_value: Variant = implementation_value.get("samples_us")
		if not samples_value is Array or samples_value.size() != EXPECTED_SAMPLES_PER_IMPLEMENTATION:
			return false
	return true


func _measure_block(case_name: String, implementation: String, court: HexChemistryWorld, expected_hash: String) -> PackedInt64Array:
	var samples := PackedInt64Array()
	for sample_index: int in SAMPLES_PER_BLOCK:
		var started := Time.get_ticks_usec()
		var actual := court.state_hash() if implementation == "production_current" else Candidate.candidate_hash(court)
		samples.append(Time.get_ticks_usec() - started)
		_check(actual == expected_hash, "%s %s sample %d returns the exact production hash" % [case_name, implementation, sample_index])
	return samples


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


func _statistics(values: PackedInt64Array) -> Dictionary:
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


func _candidate_source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_hex_hash_candidate.gd",
		"tests/support/hex_stable_cells_candidate.gd",
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
		_check(output != null, "candidate receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-hash-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
