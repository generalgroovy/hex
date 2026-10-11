extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Isolated test-only comparison of the actual public geometry constructor and a
# checked canonical-order specialization. Every sample constructs a fresh empty
# base world; fixture construction and exact output checks are outside timers.
const Candidate = preload("res://tests/support/hex_ordered_geometry_candidate.gd")
const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const EXPECTED_TOPOLOGY_CELLS := 2_766
const EXPECTED_MATERIAL_LANES := 44
const CYCLES := 4
const BLOCKS_PER_CYCLE := 4
const SAMPLES_PER_BLOCK := 5
const EXPECTED_BLOCKS := CYCLES * BLOCKS_PER_CYCLE
const EXPECTED_SAMPLES_PER_IMPLEMENTATION := CYCLES * 2 * SAMPLES_PER_BLOCK
const EXPECTED_EQUIVALENCE_CASES := 22
const EXPECTED_PROFILE_CASES := 1

var equivalence_cases_completed := 0
var profile_cases_completed := 0


class DerivedWorld extends HexChemistryWorld:
	var configure_calls := 0

	func configure_geometry(requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> bool:
		configure_calls += 1
		return super.configure_geometry(requested_origin, eligible_cells)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-ordered-geometry-candidate-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"ordered geometry receipt path is fresh and scoped",
	)
	if failures > 0:
		_finish({})
		return

	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "normal campus supplies the exact 2,766-cell topology")
	_check(World.material_layers().size() == EXPECTED_MATERIAL_LANES, "geometry shape retains the exact 44 material lanes")
	if failures > 0:
		_finish({})
		return

	var ordered_campus: Array[Vector2i] = definition.eligible_cells.duplicate()
	ordered_campus.sort_custom(Grid._cell_less)
	_check(_strictly_ordered(ordered_campus), "profile input is the canonical trusted-cell order")
	var source_before: Dictionary = _source_hashes()
	var runtime_identity_before: Dictionary = _runtime_identity()
	var runtime_identity_sha_before: String = FileAccess.get_sha256(RuntimeBuildIdentity.MANIFEST_PATH)
	_check(_hashes_complete(source_before), "all profiled source hashes are complete before equivalence and timing")
	_check(not runtime_identity_before.is_empty() and runtime_identity_sha_before.length() == 64, "runtime identity is readable before equivalence and timing")
	_equivalence_cases()
	_check(equivalence_cases_completed == EXPECTED_EQUIVALENCE_CASES, "all %d ordered geometry equivalence cases complete" % EXPECTED_EQUIVALENCE_CASES)
	if failures > 0:
		_finish({})
		return

	var profile_case: Dictionary = _profile_legal_campus(ordered_campus)
	_check(profile_cases_completed == EXPECTED_PROFILE_CASES, "the one bounded legal geometry profile completes")
	_check(_profile_case_complete(profile_case), "legal geometry profile contains every alternating block and sample")
	var source_after: Dictionary = _source_hashes()
	var runtime_identity_after: Dictionary = _runtime_identity()
	var runtime_identity_sha_after: String = FileAccess.get_sha256(RuntimeBuildIdentity.MANIFEST_PATH)
	_check(source_after == source_before, "profiled sources remain byte-identical through the complete diagnostic")
	_check(runtime_identity_after == runtime_identity_before and runtime_identity_sha_after == runtime_identity_sha_before, "runtime identity remains byte-identical through the complete diagnostic")
	if failures > 0:
		_finish({})
		return

	var receipt: Dictionary = {
		"schema_version": 1,
		"profile_version": "hex-ordered-geometry-candidate-abba-v1",
		"engine": Engine.get_version_info().get("string", ""),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"map_path": "res://content/maps/sanctum_campus_g2_v1.json",
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"known_topology_cells": EXPECTED_TOPOLOGY_CELLS,
		"material_lanes_per_cell": EXPECTED_MATERIAL_LANES,
		"cycles": CYCLES,
		"blocks_per_cycle": BLOCKS_PER_CYCLE,
		"samples_per_block": SAMPLES_PER_BLOCK,
		"samples_per_implementation": EXPECTED_SAMPLES_PER_IMPLEMENTATION,
		"batch_size": 1,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"equivalence_cases_completed": equivalence_cases_completed,
		"profile_cases_completed": profile_cases_completed,
		"cases": [profile_case],
		"source_sha256": source_before,
		"runtime_identity": runtime_identity_before,
		"runtime_identity_path": RuntimeBuildIdentity.MANIFEST_PATH,
		"runtime_identity_sha256": runtime_identity_sha_before,
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless isolated geometry-construction comparison on the genuine sorted 2,766-cell Wellspring topology. production_current calls the actual HexChemistryWorld.configure_geometry; candidate checks strict canonical order and skips only the duplicate sort while retaining validation and fresh nested allocation.",
		"timing_semantics": "Each sample includes fresh HexChemistryWorld construction, all geometry checks, 2,766 cell allocations, and 44 independently owned material dictionaries per cell. Map loading, sorting the trusted input, warmup, source hashes, exact Variant-byte comparisons, state hashes, malformed cases, and ownership checks are outside timers. batch_size is one.",
		"workload_limit": "Geometry-only fresh empty worlds. No snapshot prepare, hash, simulation tick, paid admission, renderer, network, cadence, capacity, export, or frame gain is measured or inferred.",
	}
	_finish(receipt)


func _equivalence_cases() -> void:
	var small: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(-1, -1), Vector2i.ZERO, Vector2i(1, -2), Vector2i(2, 0)]
	_assert_configure_case("ordinary canonical mixed coordinates", Vector2i(120_000, -80_000), small, true)
	var reversed := small.duplicate()
	reversed.reverse()
	_assert_configure_case("reversed input uses the original sorting path", Vector2i(120_000, -80_000), reversed, true)
	_assert_configure_case("duplicate cells reject through the original path", Vector2i.ZERO, [Vector2i.ZERO, Vector2i.ZERO], false)
	_assert_configure_case("empty topology rejects", Vector2i.ZERO, [], false)

	var boundary: Array[Vector2i] = Grid.disk(Vector2i.ZERO, 37)
	var maximum: Array[Vector2i] = []
	var above_maximum: Array[Vector2i] = []
	for index: int in range(World.MAX_CELLS + 1):
		above_maximum.append(boundary[index])
		if index < World.MAX_CELLS:
			maximum.append(boundary[index])
	_assert_configure_case("maximum 4096-cell topology accepts", Vector2i.ZERO, maximum, true)
	_assert_configure_case("4097-cell topology rejects", Vector2i.ZERO, above_maximum, false)
	_assert_configure_case("invalid origin rejects", Vector2i(Grid.MAX_ABS_QUERY_COORDINATE + 1, 0), [Vector2i.ZERO], false)
	_assert_configure_case("positive cell coordinate bound rejects", Vector2i.ZERO, [Vector2i(257, 0)], false)
	_assert_configure_case("negative cell coordinate bound rejects", Vector2i.ZERO, [Vector2i(-257, 0)], false)
	_assert_configure_case("translated cell center query bound rejects", Vector2i(7_900_000, 0), [Vector2i(3, 0)], false)

	_assert_configure_case("nonempty casts reject", Vector2i.ZERO, [Vector2i.ZERO], false, Callable(self, "_seed_cast"))
	_assert_configure_case("nonempty products reject", Vector2i.ZERO, [Vector2i.ZERO], false, Callable(self, "_seed_product"))
	_assert_configure_case("nonempty pending state rejects", Vector2i.ZERO, [Vector2i.ZERO], false, Callable(self, "_seed_pending"))
	_assert_configure_case("nonempty source mappings reject", Vector2i.ZERO, [Vector2i.ZERO], false, Callable(self, "_seed_source"))
	_assert_configure_case("paid matter rejects", Vector2i.ZERO, [Vector2i.ZERO], false, Callable(self, "_seed_paid_metric"))
	_assert_configure_case("valid negative origin accepts", Vector2i(-3_000_000, -2_000_000), [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i.ZERO], true)

	var replacement: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
	var accepted_reconfigure: Dictionary = _assert_configure_case("accepted reconfiguration replaces metadata and invalidates render polygons", Vector2i(30_000, 40_000), replacement, true, Callable(self, "_seed_configured_state"))
	var accepted_candidate: HexChemistryWorld = accepted_reconfigure.get("candidate")
	_check(accepted_candidate != null and accepted_candidate.render_revision == 17 and accepted_candidate._render_polygon_revision == -1 and accepted_candidate._render_polygons.is_empty(), "accepted reconfiguration preserves revision and invalidates cached polygons")
	_check(accepted_candidate != null and int(accepted_candidate.cells[Vector2i.ZERO].terrain) == 0, "accepted reconfiguration replaces directly mutated metadata")

	var rejected_reconfigure: Dictionary = _assert_configure_case("rejected reconfiguration leaves prior object byte-identical", Vector2i.ZERO, [Vector2i.ZERO, Vector2i.ZERO], false, Callable(self, "_seed_configured_state"))
	var rejected_candidate: HexChemistryWorld = rejected_reconfigure.get("candidate")
	_check(rejected_candidate != null and rejected_candidate._render_polygon_revision == 23 and rejected_candidate._render_polygons.size() == 1, "rejected reconfiguration retains prior render cache metadata")
	_assert_configure_case("sorted late-invalid coordinate rejects atomically after local allocation", Vector2i.ZERO, [Vector2i.ZERO, Vector2i(257, 0)], false, Callable(self, "_seed_configured_state"))

	_mutation_between_calls_case()
	_derived_fallback_case(small)
	_ownership_case()


func _assert_configure_case(label: String, requested_origin: Vector2i, eligible_cells: Array[Vector2i], expected: bool, setup: Callable = Callable()) -> Dictionary:
	var production: HexChemistryWorld = World.new()
	var candidate: HexChemistryWorld = World.new()
	if setup.is_valid():
		setup.call(production)
		setup.call(candidate)
	var production_before: PackedByteArray = _world_bytes(production)
	var candidate_before: PackedByteArray = _world_bytes(candidate)
	_check(production_before == candidate_before, label + " starts from identical old/candidate objects")
	var production_result: bool = production.configure_geometry(requested_origin, eligible_cells)
	var candidate_result: bool = Candidate.configure_geometry(candidate, requested_origin, eligible_cells)
	_check(production_result == expected and candidate_result == expected, label + " preserves actual acceptance")
	_check(_world_bytes(production) == _world_bytes(candidate), label + " preserves exact structural Variant bytes")
	if expected:
		_check(production.state_hash() == candidate.state_hash(), label + " preserves authority hash")
	else:
		_check(_world_bytes(production) == production_before and _world_bytes(candidate) == candidate_before, label + " leaves both prior objects unchanged on rejection")
	equivalence_cases_completed += 1
	return {"production": production, "candidate": candidate}


func _mutation_between_calls_case() -> void:
	var production: HexChemistryWorld = World.new()
	var candidate: HexChemistryWorld = World.new()
	var cells: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO]
	_check(production.configure_geometry(Vector2i.ZERO, cells) and Candidate.configure_geometry(candidate, Vector2i.ZERO, cells), "mutation-between-calls fixtures initially configure")
	production.cells[Vector2i.ZERO].terrain = 71
	candidate.cells[Vector2i.ZERO].terrain = 71
	cells.append(Vector2i(1, 0))
	var production_result: bool = production.configure_geometry(Vector2i(90_000, -60_000), cells)
	var candidate_result: bool = Candidate.configure_geometry(candidate, Vector2i(90_000, -60_000), cells)
	_check(production_result and candidate_result and production.cells.size() == 3 and candidate.cells.size() == 3, "consecutive calls observe the directly mutated input array")
	_check(_world_bytes(production) == _world_bytes(candidate) and int(candidate.cells[Vector2i.ZERO].terrain) == 0, "consecutive call output remains exact and replaces prior direct metadata mutation")
	equivalence_cases_completed += 1


func _derived_fallback_case(cells: Array[Vector2i]) -> void:
	var production := DerivedWorld.new()
	var candidate := DerivedWorld.new()
	var production_result: bool = production.configure_geometry(Vector2i.ZERO, cells)
	var candidate_result: bool = Candidate.configure_geometry(candidate, Vector2i.ZERO, cells)
	_check(production_result and candidate_result, "derived world ordered geometry accepts through public behavior")
	_check(production.configure_calls == 1 and candidate.configure_calls == 1, "candidate invokes the derived configure override exactly once")
	_check(_world_bytes(production) == _world_bytes(candidate), "derived fallback matches the actual overridden path bytes")
	equivalence_cases_completed += 1


func _ownership_case() -> void:
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	var production: HexChemistryWorld = _construct_production(Vector2i.ZERO, cells)
	var first: HexChemistryWorld = Candidate.construct(Vector2i.ZERO, cells)
	var second: HexChemistryWorld = Candidate.construct(Vector2i.ZERO, cells)
	_check(production != null and first != null and second != null and _world_bytes(production) == _world_bytes(first) and _world_bytes(first) == _world_bytes(second), "ownership fixtures start from exact independently constructed output")
	var layers: Array[String] = World.material_layers()
	var complete_shape := true
	for cell: Vector2i in cells:
		if first.cells[cell].size() != EXPECTED_MATERIAL_LANES + 3:
			complete_shape = false
		for layer: String in layers:
			if not first.cells[cell].has(layer) or not first.cells[cell][layer] is Dictionary or not first.cells[cell][layer].is_empty():
				complete_shape = false
	_check(complete_shape, "each cell owns all 44 empty material dictionaries plus three metadata fields")
	first.cells[Vector2i.ZERO][layers[0]][101] = 7
	_check(first.cells[Vector2i.ZERO][layers[1]].is_empty() and first.cells[Vector2i(1, 0)][layers[0]].is_empty(), "material lanes and sibling cells do not alias within one world")
	_check(second.cells[Vector2i.ZERO][layers[0]].is_empty(), "separately constructed worlds do not alias material lanes")
	second.cells[Vector2i.ZERO].terrain = 99
	_check(int(first.cells[Vector2i.ZERO].terrain) == 0, "separately constructed worlds do not alias metadata records")
	equivalence_cases_completed += 1


func _profile_legal_campus(ordered_cells: Array[Vector2i]) -> Dictionary:
	var expected: HexChemistryWorld = _construct_production(definition.origin, ordered_cells)
	_check(expected != null and expected.cells.size() == EXPECTED_TOPOLOGY_CELLS, "production oracle constructs the legal campus")
	var expected_bytes: PackedByteArray = _world_bytes(expected)
	var expected_hash: String = expected.state_hash() if expected != null else ""
	for implementation: String in ["production_current", "candidate"]:
		for warmup_index: int in range(3):
			var warmup: HexChemistryWorld = _construct(implementation, definition.origin, ordered_cells)
			_check(warmup != null and _world_bytes(warmup) == expected_bytes and warmup.state_hash() == expected_hash, "%s warmup %d is exact" % [implementation, warmup_index])

	var samples_by_implementation: Dictionary = {
		"production_current": PackedInt64Array(),
		"candidate": PackedInt64Array(),
	}
	var blocks: Array[Dictionary] = []
	for cycle: int in range(CYCLES):
		var order: Array[String] = _implementation_order(cycle)
		for block_index: int in range(order.size()):
			var implementation: String = order[block_index]
			var block_samples := PackedInt64Array()
			for sample_index: int in range(SAMPLES_PER_BLOCK):
				var started: int = Time.get_ticks_usec()
				var actual: HexChemistryWorld = _construct(implementation, definition.origin, ordered_cells)
				var elapsed: int = Time.get_ticks_usec() - started
				block_samples.append(elapsed)
				samples_by_implementation[implementation].append(elapsed)
				_check(actual != null and actual.cells.size() == EXPECTED_TOPOLOGY_CELLS, "%s cycle %d block %d sample %d constructs every cell" % [implementation, cycle, block_index, sample_index])
				_check(actual != null and _world_bytes(actual) == expected_bytes and actual.state_hash() == expected_hash, "%s cycle %d block %d sample %d remains byte/hash exact" % [implementation, cycle, block_index, sample_index])
				actual = null
			blocks.append({"cycle": cycle, "block": block_index, "implementation": implementation, "samples_us": Array(block_samples)})

	profile_cases_completed += 1
	return {
		"case": "legal-sorted-2766-cell-campus",
		"topology_cells": ordered_cells.size(),
		"origin": [definition.origin.x, definition.origin.y],
		"expected_variant_bytes": expected_bytes.size(),
		"expected_authority_hash": expected_hash,
		"blocks": blocks,
		"implementations": {
			"production_current": {"inclusive_us": _statistics(samples_by_implementation.production_current), "samples_us": Array(samples_by_implementation.production_current)},
			"candidate": {"inclusive_us": _statistics(samples_by_implementation.candidate), "samples_us": Array(samples_by_implementation.candidate)},
		},
	}


func _profile_case_complete(result: Dictionary) -> bool:
	if result.is_empty() or String(result.get("case", "")) != "legal-sorted-2766-cell-campus" or int(result.get("topology_cells", 0)) != EXPECTED_TOPOLOGY_CELLS:
		return false
	var blocks_value: Variant = result.get("blocks")
	if not blocks_value is Array or blocks_value.size() != EXPECTED_BLOCKS:
		return false
	var flattened_production: Array = []
	var flattened_candidate: Array = []
	for flat_index: int in range(blocks_value.size()):
		var block_value: Variant = blocks_value[flat_index]
		if not block_value is Dictionary:
			return false
		var expected_cycle: int = flat_index / BLOCKS_PER_CYCLE
		var expected_block: int = flat_index % BLOCKS_PER_CYCLE
		var expected_order: Array[String] = _implementation_order(expected_cycle)
		var expected_implementation: String = expected_order[expected_block]
		if int(block_value.get("cycle", -1)) != expected_cycle or int(block_value.get("block", -1)) != expected_block \
			or String(block_value.get("implementation", "")) != expected_implementation:
			return false
		var block_samples: Variant = block_value.get("samples_us")
		if not block_samples is Array or block_samples.size() != SAMPLES_PER_BLOCK:
			return false
		for sample: Variant in block_samples:
			if typeof(sample) != TYPE_INT or int(sample) <= 0:
				return false
		if expected_implementation == "production_current":
			flattened_production.append_array(block_samples)
		else:
			flattened_candidate.append_array(block_samples)
	var implementations: Variant = result.get("implementations")
	if not implementations is Dictionary:
		return false
	for implementation: String in ["production_current", "candidate"]:
		var row: Variant = implementations.get(implementation)
		if not row is Dictionary:
			return false
		var implementation_samples: Variant = row.get("samples_us")
		if not implementation_samples is Array or implementation_samples.size() != EXPECTED_SAMPLES_PER_IMPLEMENTATION:
			return false
		var expected_flattened: Array = flattened_candidate
		if implementation == "production_current":
			expected_flattened = flattened_production
		if implementation_samples != expected_flattened:
			return false
		var statistics: Variant = row.get("inclusive_us")
		if not statistics is Dictionary or int(statistics.get("samples", -1)) != EXPECTED_SAMPLES_PER_IMPLEMENTATION:
			return false
	return true


func _implementation_order(cycle: int) -> Array[String]:
	var order: Array[String] = []
	if cycle % 2 == 0:
		order.assign(["production_current", "candidate", "candidate", "production_current"])
	else:
		order.assign(["candidate", "production_current", "production_current", "candidate"])
	return order


func _construct(implementation: String, requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> HexChemistryWorld:
	return _construct_production(requested_origin, eligible_cells) if implementation == "production_current" else Candidate.construct(requested_origin, eligible_cells)


func _construct_production(requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> HexChemistryWorld:
	var world: HexChemistryWorld = World.new()
	return world if world.configure_geometry(requested_origin, eligible_cells) else null


func _world_bytes(world: HexChemistryWorld) -> PackedByteArray:
	if world == null:
		return PackedByteArray()
	return var_to_bytes({
		"origin": world.origin,
		"cells": world.cells,
		"casts": world.casts,
		"products": world.products,
		"pending": world.pending,
		"sources": world.sources,
		"exposure": world.exposure,
		"flow_carry": world.flow_carry,
		"next_cast_id": world.next_cast_id,
		"next_product_id": world.next_product_id,
		"current_tick": world.current_tick,
		"render_revision": world.render_revision,
		"value_revision": world.value_revision,
		"render_polygon_revision": world._render_polygon_revision,
		"render_polygons": world._render_polygons,
		"chemistry_enabled": world.chemistry_enabled,
		"next_ground_part_id": world.next_ground_part_id,
		"metrics": world.metrics,
	})


func _seed_cast(world: HexChemistryWorld) -> void:
	world.casts[1] = {}


func _seed_product(world: HexChemistryWorld) -> void:
	world.products[1] = {}


func _seed_pending(world: HexChemistryWorld) -> void:
	world.pending[1] = 1


func _seed_source(world: HexChemistryWorld) -> void:
	world.sources[1] = 1


func _seed_paid_metric(world: HexChemistryWorld) -> void:
	world.metrics.matter_paid = 1


func _seed_configured_state(world: HexChemistryWorld) -> void:
	world.configure_geometry(Vector2i(10_000, -20_000), [Vector2i.ZERO])
	world.cells[Vector2i.ZERO].terrain = 9
	world.cells[Vector2i.ZERO].elevation = -4
	world.cells[Vector2i.ZERO].structure = 7
	world.render_revision = 17
	world._render_polygon_revision = 23
	world._render_polygons[Vector2i.ZERO] = Grid.vertices(Vector2i.ZERO)


func _strictly_ordered(cells: Array[Vector2i]) -> bool:
	for index: int in range(1, cells.size()):
		if not Grid._cell_less(cells[index - 1], cells[index]):
			return false
	return true


func _statistics(values: PackedInt64Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {"samples": 0, "min": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}
	return {
		"samples": ordered.size(),
		"min": ordered[0],
		"p50": ordered[_percentile_index(ordered.size(), 50)],
		"p95": ordered[_percentile_index(ordered.size(), 95)],
		"p99": ordered[_percentile_index(ordered.size(), 99)],
		"max": ordered[-1],
	}


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_hex_ordered_geometry_candidate.gd",
		"tests/support/hex_ordered_geometry_candidate.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/hex/hex_grid.gd",
		"src/sim/hex/hex_world_definition.gd",
		"content/maps/sanctum_campus_g2_v1.json",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _hashes_complete(hashes: Dictionary) -> bool:
	if hashes.size() != 7:
		return false
	for value: Variant in hashes.values():
		if typeof(value) != TYPE_STRING or String(value).length() != 64:
			return false
	return true


func _runtime_identity() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH))
	return value.duplicate(true) if value is Dictionary else {}


func _finish(receipt: Dictionary) -> void:
	if not receipt.is_empty() and not output_path.is_empty():
		receipt.assertions = assertions
		receipt.failures = failures
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "ordered geometry receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-ordered-geometry-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
