extends "res://tests/performance/profile_hex_native_sort_candidate.gd"
@warning_ignore_start("integer_division")


const CellJsonCandidate = preload("res://tests/support/hex_cell_json_candidate.gd")
const CELL_JSON_IMPLEMENTATION := "candidate_cell_json"
const CELL_JSON_EXTRA_EQUIVALENCE_CASES := 5
const CELL_JSON_EQUIVALENCE_CASES := TOTAL_EQUIVALENCE_CASES + CELL_JSON_EXTRA_EQUIVALENCE_CASES


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	receipt_path_valid = (
		output_path.begins_with("res://.godot/hex-cell-json-candidate-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path)
	)
	_check(receipt_path_valid, "cell JSON receipt path is fresh and scoped")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "normal campus supplies the exact 2,766-cell topology")
	var source_before: Dictionary = _cell_json_source_hashes()
	var identity_before: Dictionary = _runtime_identity()
	var identity_sha_before: String = FileAccess.get_sha256(RuntimeBuildIdentity.MANIFEST_PATH)
	_check(_cell_json_hashes_complete(source_before), "all cell JSON sources have complete hashes before work")
	_check(not identity_before.is_empty() and identity_sha_before.length() == 64, "runtime identity is readable before work")
	if failures > 0:
		_finish(_cell_json_partial("preflight", [], source_before, identity_before, identity_sha_before))
		return

	_equivalence_cases()
	_check(equivalence_cases_completed == CELL_JSON_EQUIVALENCE_CASES, "all %d inherited and cell JSON equivalence cases complete" % CELL_JSON_EQUIVALENCE_CASES)
	_check(ownership_cases_completed == 1, "independent cell JSON ownership case completes")
	if failures > 0:
		_finish(_cell_json_partial("equivalence", [], source_before, identity_before, identity_sha_before))
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
	_check(_nonempty_material_cells(dense_court) == EXPECTED_TOPOLOGY_CELLS, "synthetic pressure case makes every topology record nonempty")

	var cases: Array[Dictionary] = [
		_profile_case("production-empty", empty_world.hex_court, empty_occupancy),
		_profile_case("legal-paid-29-active", active_world.hex_court, active_occupancy),
		_profile_case("synthetic-all-nonempty", dense_court, {"active_cells": 0, "source_quantity": 0, "product_quantity": 0}),
	]
	var expected_names: Array[String] = ["production-empty", "legal-paid-29-active", "synthetic-all-nonempty"]
	_check(profile_cases_completed == EXPECTED_PROFILE_CASES and cases.size() == EXPECTED_PROFILE_CASES, "all three cell JSON profile cases complete")
	for case_index: int in expected_names.size():
		_check(_profile_case_is_complete(cases[case_index], expected_names[case_index]), "%s has exact alternating blocks and samples" % expected_names[case_index])

	var source_after: Dictionary = _cell_json_source_hashes()
	var identity_after: Dictionary = _runtime_identity()
	var identity_sha_after: String = FileAccess.get_sha256(RuntimeBuildIdentity.MANIFEST_PATH)
	_check(source_after == source_before, "all measured sources remain byte-identical")
	_check(identity_after == identity_before and identity_sha_after == identity_sha_before, "runtime identity remains byte-identical")
	if failures > 0:
		_finish(_cell_json_partial("profile", cases, source_before, identity_before, identity_sha_before))
		return

	_finish({
		"schema_version": 1,
		"profile_version": "hex-cell-json-candidate-abba-v1",
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
		"samples_per_implementation_per_case": EXPECTED_SAMPLES_PER_IMPLEMENTATION,
		"batch_size": 1,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"equivalence_cases_completed": equivalence_cases_completed,
		"ownership_cases_completed": ownership_cases_completed,
		"profile_cases_completed": profile_cases_completed,
		"cases": cases,
		"source_sha256": source_before,
		"runtime_identity": identity_before,
		"runtime_identity_path": RuntimeBuildIdentity.MANIFEST_PATH,
		"runtime_identity_sha256": identity_sha_before,
		"assertions": assertions,
		"failures": failures,
		"scope": "Isolated whole-public-state_hash comparison. production_current is live HexChemistryWorld. candidate_cell_json is a detached test-only subclass that emits exact empty integral cell JSON fragments; shallow ordinary occupied records use the production projection, while unknown, malformed, deep, or out-of-range cells delegate the whole call to production. Fixture creation and every byte/hash/source check are outside timers.",
		"timing_limit": "Each arm has 56 unbatched samples per case in balanced ABBA/BAAB order. The synthetic all-nonempty case is not legal chemistry. No frame, allocation, networking, export, capacity, or integrated-runtime benefit is inferred.",
	})


func _equivalence_cases() -> void:
	super._equivalence_cases()
	var cell := Vector2i(-2_147_483_648, 2_147_483_647)
	var bounds := HexChemistryWorld.new()
	bounds.cells[cell] = HexChemistryWorld._new_empty_cell()
	bounds.cells[cell].terrain = -2_147_483_648
	bounds.cells[cell].elevation = 2_147_483_647
	bounds.cells[cell].structure = -1
	_assert_equivalent(bounds, "synthetic direct hash mutation with int32 coordinate and metadata extrema")

	var wide := HexChemistryWorld.new()
	var wide_cells: Array[Vector2i] = [Vector2i(-21, 34), Vector2i(55, -89)]
	_check(wide.configure_geometry(Vector2i(144_000, -233_000), wide_cells), "int64 fallback fixture configures")
	wide.cells[wide_cells[0]].terrain = 2_147_483_648
	wide.cells[wide_cells[0]].elevation = 9_223_372_036_854_775_807
	wide.cells[wide_cells[1]].structure = -9_223_372_036_854_775_807 - 1
	_assert_equivalent(wide, "out-of-range and int64 extrema fallback")

	var escaped := HexChemistryWorld.new()
	var escaped_cell := Vector2i(-144, 233)
	_check(escaped.configure_geometry(Vector2i(-987_000, 1_597_000), [escaped_cell]), "escaped generic fixture configures")
	escaped.cells[escaped_cell]["ascii"] = "quote\" slash\\ newline\n tab\t control" + String.chr(1)
	escaped.cells[escaped_cell]["unicode"] = "Zażółć 火 🜁"
	escaped.cells[escaped_cell]["nested"] = {4: "integer", "4": ["quoted\"", "backslash\\", Vector2i(-1, 2)]}
	_assert_equivalent(escaped, "ASCII Unicode control and mixed-key generic escaping")

	var outer := HexChemistryWorld.new()
	var outer_cell := Vector2i(89, -144)
	var outer_cells: Array[Vector2i] = [outer_cell]
	_check(outer.configure_geometry(Vector2i(258_000, -417_000), outer_cells), "outer-lane string fixture configures")
	outer.metrics["ascii"] = "quote\" slash\\ newline\n tab\t control" + String.chr(2)
	outer.metrics["unicode"] = "Pchnąć 🜄 水"
	_assert_equivalent(outer, "ordinary direct cell path with escaped and Unicode outer lanes")

	var deep := HexChemistryWorld.new()
	var deep_cell := Vector2i(-55, 34)
	var deep_cells: Array[Vector2i] = [deep_cell]
	_check(deep.configure_geometry(Vector2i(-159_000, 257_000), deep_cells), "deep fallback fixture configures")
	deep.cells[deep_cell]["deep"] = {"one": [{"two": [{"three": ["terminal"]}]}]}
	_assert_equivalent(deep, "deep cell value delegates the whole hash call")


func _ownership_case(cells_value: Array[Vector2i]) -> void:
	var source := HexChemistryWorld.new()
	_check(source.configure_geometry(Vector2i(21_000, -23_000), cells_value), "cell JSON ownership source configures")
	var layer: String = HexChemistryWorld.material_layers()[0]
	source.cells[cells_value[0]]["nested_extra"] = {"items": [Vector2i(-3, 5), {7: "source"}]}
	var source_cells: Dictionary = source.cells.duplicate(true)
	var source_hash: String = source.state_hash()
	var first: HexChemistryWorld = CellJsonCandidate.from_world(source)
	var second: HexChemistryWorld = CellJsonCandidate.from_world(source)
	_check(first != null and second != null and first.get_instance_id() != second.get_instance_id(), "cell JSON candidate copies are distinct worlds")
	_check(first._state_hash_bytes() == source._state_hash_bytes() and second.state_hash() == source_hash, "cell JSON copies begin with exact public bytes and hash")
	first.cells[cells_value[0]][layer][901] = 17
	(first.cells[cells_value[0]]["nested_extra"]["items"] as Array).append("candidate-only")
	first.metrics["requested"] = int(first.metrics.requested) + 1
	_check(source.cells == source_cells and source.state_hash() == source_hash, "cell JSON nested mutations do not alias source")
	_check(second.cells == source_cells and second.state_hash() == source_hash, "cell JSON copies do not alias each other")
	_check(first.state_hash() != source_hash, "direct candidate mutation is visible to the next public hash")
	var added := Vector2i(3, -4)
	second.cells[added] = HexChemistryWorld._new_empty_cell()
	_check(second.state_hash() != source_hash and second._state_hash_bytes() == FrozenOracle.frozen_original_bytes(second), "same candidate observes a directly added cell")
	second.cells.erase(added)
	_check(second.state_hash() == source_hash, "same candidate removal restores the source hash")
	var ordinary := HexChemistryWorld.new()
	var ordinary_cell := Vector2i(13, -21)
	var ordinary_cells: Array[Vector2i] = [ordinary_cell]
	_check(ordinary.configure_geometry(Vector2i.ZERO, ordinary_cells), "ordinary transition source configures")
	var transition: HexChemistryWorld = CellJsonCandidate.from_world(ordinary)
	var ordinary_bytes: PackedByteArray = ordinary._state_hash_bytes()
	_check(transition != null and transition._state_hash_bytes() == ordinary_bytes, "ordinary transition starts on exact direct bytes")
	transition.cells[ordinary_cell]["deep"] = {"one": [{"two": [{"three": ["fallback"]}]}]}
	_check(transition._state_hash_bytes() == FrozenOracle.frozen_original_bytes(transition), "same candidate observes ordinary to whole-call fallback mutation")
	transition.cells[ordinary_cell].erase("deep")
	_check(transition._state_hash_bytes() == ordinary_bytes, "same candidate fallback removal restores direct-path bytes")
	ownership_cases_completed += 1


func _assert_equivalent(court: HexChemistryWorld, label: String) -> void:
	var source_identity: int = court.get_instance_id()
	var source_cells: Dictionary = court.cells.duplicate(true)
	var production_bytes: PackedByteArray = court._state_hash_bytes()
	var production_hash: String = court.state_hash()
	var frozen_bytes: PackedByteArray = FrozenOracle.frozen_original_bytes(court)
	var candidate: HexChemistryWorld = CellJsonCandidate.from_world(court)
	_check(candidate != null and candidate.get_instance_id() != source_identity, label + " candidate is an independent world")
	_check(production_bytes == frozen_bytes, label + " current production bytes equal the frozen oracle")
	_check(candidate != null and candidate._state_hash_bytes() == production_bytes and candidate.state_hash() == production_hash, label + " cell JSON candidate preserves exact public bytes and hash")
	_check(court.get_instance_id() == source_identity and court.cells == source_cells and court.state_hash() == production_hash, label + " hashing preserves source identity and records")
	equivalence_cases_completed += 1


func _profile_case(case_name: String, court: HexChemistryWorld, occupancy: Dictionary) -> Dictionary:
	var production_identity: int = court.get_instance_id()
	var production_cells: Dictionary = court.cells.duplicate(true)
	var production_bytes: PackedByteArray = court._state_hash_bytes()
	var production_hash: String = court.state_hash()
	var frozen_bytes: PackedByteArray = FrozenOracle.frozen_original_bytes(court)
	var candidate: HexChemistryWorld = CellJsonCandidate.from_world(court)
	var candidate_identity: int = candidate.get_instance_id() if candidate != null else 0
	var candidate_cells: Dictionary = candidate.cells.duplicate(true) if candidate != null else {}
	_check(candidate != null and candidate_identity != production_identity, case_name + " candidate is independently prepared")
	_check(production_bytes == frozen_bytes and candidate != null and candidate._state_hash_bytes() == production_bytes, case_name + " both live arms equal independent frozen bytes")
	_check(FrozenOracle.frozen_original_hash(court) == production_hash and candidate != null and candidate.state_hash() == production_hash, case_name + " both live arms equal the current public hash")
	for unused: int in 3:
		_check(court.state_hash() == production_hash and candidate != null and candidate.state_hash() == production_hash, case_name + " warmup remains exact")

	var all_samples: Dictionary = {"production_current": PackedInt64Array(), CELL_JSON_IMPLEMENTATION: PackedInt64Array()}
	var block_counts: Dictionary = {"production_current": 0, CELL_JSON_IMPLEMENTATION: 0}
	var blocks: Array[Dictionary] = []
	for cycle: int in CYCLES:
		var order: Array[String] = _cell_json_order(cycle)
		for block_index: int in BLOCKS_PER_CYCLE:
			var implementation: String = order[block_index]
			var samples: PackedInt64Array = _measure_cell_json_block(case_name, implementation, court, candidate, production_hash)
			_check(samples.size() == SAMPLES_PER_BLOCK, "%s %s cycle %d block %d has every sample" % [case_name, implementation, cycle, block_index])
			var combined: PackedInt64Array = all_samples[implementation]
			combined.append_array(samples)
			all_samples[implementation] = combined
			block_counts[implementation] = int(block_counts[implementation]) + 1
			blocks.append({"cycle": cycle, "block": block_index, "implementation": implementation, "samples_us": Array(samples), "statistics_us": _statistics(samples)})
			_check(court.get_instance_id() == production_identity and court.cells == production_cells and court.state_hash() == production_hash, "%s %s block preserves production source" % [case_name, implementation])
			_check(candidate != null and candidate.get_instance_id() == candidate_identity and candidate.cells == candidate_cells and candidate.state_hash() == production_hash, "%s %s block preserves candidate source" % [case_name, implementation])

	var production_samples: PackedInt64Array = all_samples.production_current
	var candidate_samples: PackedInt64Array = all_samples[CELL_JSON_IMPLEMENTATION]
	var expected_blocks: int = CYCLES * BLOCKS_PER_CYCLE / 2
	var expected_samples: int = expected_blocks * SAMPLES_PER_BLOCK
	_check(blocks.size() == EXPECTED_BLOCKS_PER_PROFILE_CASE, case_name + " has every alternating block")
	_check(int(block_counts.production_current) == expected_blocks and int(block_counts[CELL_JSON_IMPLEMENTATION]) == expected_blocks, case_name + " both implementations have every block")
	_check(production_samples.size() == expected_samples and candidate_samples.size() == expected_samples, case_name + " both implementations have all samples")
	_check(candidate != null and candidate._state_hash_bytes() == frozen_bytes and court.cells == production_cells and court.state_hash() == production_hash, case_name + " post-profile bytes and source remain exact")
	var production_stats: Dictionary = _statistics(production_samples)
	var candidate_stats: Dictionary = _statistics(candidate_samples)
	profile_cases_completed += 1
	return {
		"case": case_name,
		"topology_cells": court.cells.size(),
		"world_tick": court.current_tick,
		"occupancy": occupancy.duplicate(true),
		"nonempty_material_cells": _nonempty_material_cells(court),
		"authority_hash": production_hash,
		"canonical_bytes": production_bytes.size(),
		"blocks": blocks,
		"implementations": {
			"production_current": {"statistics_us": production_stats, "samples_us": Array(production_samples)},
			CELL_JSON_IMPLEMENTATION: {"statistics_us": candidate_stats, "samples_us": Array(candidate_samples)},
		},
		"comparison": {
			"p50_delta_us": int(production_stats.p50) - int(candidate_stats.p50),
			"p95_delta_us": int(production_stats.p95) - int(candidate_stats.p95),
			"p99_delta_us": int(production_stats.p99) - int(candidate_stats.p99),
			"p50_candidate_over_production": float(candidate_stats.p50) / float(maxi(1, int(production_stats.p50))),
			"p95_candidate_over_production": float(candidate_stats.p95) / float(maxi(1, int(production_stats.p95))),
		},
	}


func _measure_cell_json_block(case_name: String, implementation: String, production: HexChemistryWorld, candidate: HexChemistryWorld, expected_hash: String) -> PackedInt64Array:
	var samples := PackedInt64Array()
	for sample_index: int in SAMPLES_PER_BLOCK:
		var started: int = Time.get_ticks_usec()
		var actual: String = production.state_hash() if implementation == "production_current" else candidate.state_hash()
		samples.append(Time.get_ticks_usec() - started)
		_check(actual == expected_hash, "%s %s sample %d returns exact production hash" % [case_name, implementation, sample_index])
	return samples


func _cell_json_order(cycle: int) -> Array[String]:
	var order: Array[String] = []
	if cycle % 2 == 0:
		order.assign(["production_current", CELL_JSON_IMPLEMENTATION, CELL_JSON_IMPLEMENTATION, "production_current"])
	else:
		order.assign([CELL_JSON_IMPLEMENTATION, "production_current", "production_current", CELL_JSON_IMPLEMENTATION])
	return order


func _profile_case_is_complete(result: Dictionary, expected_name: String) -> bool:
	if result.is_empty() or String(result.get("case", "")) != expected_name:
		return false
	var blocks_value: Variant = result.get("blocks")
	if not blocks_value is Array or blocks_value.size() != EXPECTED_BLOCKS_PER_PROFILE_CASE:
		return false
	var flattened: Dictionary = {"production_current": [], CELL_JSON_IMPLEMENTATION: []}
	for flat_index: int in blocks_value.size():
		var block: Variant = blocks_value[flat_index]
		if not block is Dictionary:
			return false
		var cycle: int = flat_index / BLOCKS_PER_CYCLE
		var block_index: int = flat_index % BLOCKS_PER_CYCLE
		var expected_implementation: String = _cell_json_order(cycle)[block_index]
		if int(block.get("cycle", -1)) != cycle or int(block.get("block", -1)) != block_index or String(block.get("implementation", "")) != expected_implementation:
			return false
		var samples: Variant = block.get("samples_us")
		if not samples is Array or samples.size() != SAMPLES_PER_BLOCK:
			return false
		for sample: Variant in samples:
			if typeof(sample) != TYPE_INT or int(sample) <= 0:
				return false
		(flattened[expected_implementation] as Array).append_array(samples)
	var implementations: Variant = result.get("implementations")
	if not implementations is Dictionary:
		return false
	for implementation: String in ["production_current", CELL_JSON_IMPLEMENTATION]:
		var row: Variant = implementations.get(implementation)
		if not row is Dictionary or row.get("samples_us") != flattened[implementation]:
			return false
		var stats: Variant = row.get("statistics_us")
		if not stats is Dictionary or int(stats.get("samples", -1)) != EXPECTED_SAMPLES_PER_IMPLEMENTATION:
			return false
	return true


func _cell_json_source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [
		"tests/performance/profile_hex_cell_json_candidate.gd",
		"tests/support/hex_cell_json_candidate.gd",
		"tests/performance/profile_hex_native_sort_candidate.gd",
		"tests/support/hex_native_sort_candidate.gd",
		"tests/performance/profile_hex_hash_candidate.gd",
		"tests/support/hex_stable_cells_candidate.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/core/canonical_bytes.gd",
		"src/sim/core/sim_world.gd",
		"src/sim/hex/hex_grid.gd",
		"src/sim/hex/hex_world_definition.gd",
		"content/abilities/foundation_abilities_v1.json",
		"content/champions/foundation_champions_v1.json",
		"content/maps/sanctum_campus_g2_v1.json",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _cell_json_hashes_complete(hashes: Dictionary) -> bool:
	if hashes.size() != 15:
		return false
	for value: Variant in hashes.values():
		if typeof(value) != TYPE_STRING or String(value).length() != 64:
			return false
	return true


func _cell_json_partial(stage: String, cases: Array, sources: Dictionary, identity: Dictionary, identity_sha: String) -> Dictionary:
	return {
		"schema_version": 1,
		"profile_version": "hex-cell-json-candidate-abba-v1-partial",
		"failed_stage": stage,
		"equivalence_cases_completed": equivalence_cases_completed,
		"ownership_cases_completed": ownership_cases_completed,
		"profile_cases_completed": profile_cases_completed,
		"cases": cases.duplicate(true),
		"source_sha256": sources.duplicate(true),
		"runtime_identity": identity.duplicate(true),
		"runtime_identity_path": RuntimeBuildIdentity.MANIFEST_PATH,
		"runtime_identity_sha256": identity_sha,
		"assertions": assertions,
		"failures": failures,
		"scope": "Partial diagnostic receipt retained after a fail-closed cell JSON candidate check.",
	}


func _finish(receipt: Dictionary) -> void:
	if receipt_path_valid and not receipt.is_empty() and not output_path.is_empty():
		receipt.assertions = assertions
		receipt.failures = failures
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "cell JSON receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-cell-json-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
