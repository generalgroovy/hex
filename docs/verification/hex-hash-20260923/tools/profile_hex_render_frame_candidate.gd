extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")


# Test-only preparation comparison. This times no CanvasItem drawing and changes
# no presenter, authority, topology, geometry, selection, style, or draw path.
const Candidate = preload("res://tests/support/hex_render_frame_candidate.gd")
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const ACTIVE_WORKLOAD_TICKS := 40
const EXPECTED_TOPOLOGY_CELLS := 2_766
const EXPECTED_EQUIVALENCE_CASES := 21
const EXPECTED_PROFILE_CASES := 2
const CYCLES := 4
const BLOCKS_PER_CYCLE := 4
const SAMPLES_PER_BLOCK := 5
const EXPECTED_BLOCKS_PER_CASE := CYCLES * BLOCKS_PER_CYCLE
const EXPECTED_SAMPLES_PER_IMPLEMENTATION := CYCLES * 2 * SAMPLES_PER_BLOCK

var equivalence_cases_completed := 0
var profile_cases_completed := 0


class DerivedCourt:
	extends HexChemistryWorld


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-render-frame-candidate-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"render frame receipt path is fresh and scoped",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "normal campus supplies the exact 2,766-cell topology")
	_check(Presenter.MATERIALS == HexChemistryWorld.material_layers(), "presenter and exact base court share the same ordered 8+36 material domain")
	var language := VisualLanguage.new()
	_check(language.load_from_file(), "production visual language loads")
	if failures > 0:
		_finish({})
		return

	_equivalence_cases(language)
	_check(equivalence_cases_completed == EXPECTED_EQUIVALENCE_CASES, "all %d frame preparation equivalence cases complete" % EXPECTED_EQUIVALENCE_CASES)
	if failures > 0:
		_finish({})
		return

	var cases: Array[Dictionary] = []
	for case_name: String in ["sustained-distributed", "dense-crucible"]:
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		for unused: int in range(WARMUP_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, false, false)), case_name + " neutral warmup advances")
		for unused: int in range(ACTIVE_WORKLOAD_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, true, false)), case_name + " paid workload advances")
		var court: HexChemistryWorld = world.hex_court
		var presenter: HexCourtPresenter = _prepared_presenter(court, language, false)
		var occupancy: Dictionary = _occupancy(court, world.tick)
		var occupied_cells: int = court.occupied_cells().size()
		_check(world.players.size() == 8 and court.cells.size() == EXPECTED_TOPOLOGY_CELLS and court.conservation_valid(), case_name + " retains eight actors, full topology, and conservation")
		_check(occupied_cells > 0 and presenter._cells.size() == occupied_cells, case_name + " timed presenter uses actual occupied-only Wellspring membership")
		if case_name == "sustained-distributed":
			_check(int(court.metrics.admitted) == 7 and int(court.metrics.matter_paid) == 4_200 and int(occupancy.active_cells) == 57, "distributed frozen workload matches D5 legal authority")
		else:
			_check(int(court.metrics.admitted) == 8 and int(court.metrics.matter_paid) == 4_800 and int(occupancy.active_cells) == 29, "dense frozen workload matches D5 legal authority")
		cases.append(_profile_case(case_name, court, presenter, float(world.tick), {
			"world_tick": world.tick,
			"actors": world.players.size(),
			"metrics": court.metrics.duplicate(true),
			"occupancy": occupancy,
			"presenter_cells": occupied_cells,
		}))
	_check(profile_cases_completed == EXPECTED_PROFILE_CASES and cases.size() == EXPECTED_PROFILE_CASES, "both legal profile cases complete")
	for case_index: int in cases.size():
		_check(_profile_case_complete(cases[case_index]), "profile case %d contains every block and sample" % case_index)
	if failures > 0:
		_finish({})
		return

	var receipt: Dictionary = {
		"schema_version": 1,
		"profile_version": "hex-render-frame-candidate-abba-v1",
		"workload_version": "unified-wellspring-profile-v1/distributed+dense-first-40",
		"engine": Engine.get_version_info().get("string", ""),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"map_path": "res://content/maps/sanctum_campus_g2_v1.json",
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"topology_cells": EXPECTED_TOPOLOGY_CELLS,
		"material_count": Presenter.MATERIALS.size(),
		"warmup_ticks": WARMUP_TICKS,
		"active_workload_ticks": ACTIVE_WORKLOAD_TICKS,
		"cycles": CYCLES,
		"blocks_per_cycle": BLOCKS_PER_CYCLE,
		"samples_per_block": SAMPLES_PER_BLOCK,
		"samples_per_implementation_per_case": EXPECTED_SAMPLES_PER_IMPLEMENTATION,
		"equivalence_cases_completed": equivalence_cases_completed,
		"profile_cases_completed": profile_cases_completed,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"cases": cases,
		"source_sha256": _candidate_source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless isolated preparation of exact HexChemistryWorld per-cell views and presenter-prepared regions over actual occupied-only normal-Wellspring membership at frozen legal tick-160 distributed and dense authorities. production_current invokes the actual current court.view loop then HexCourtPresenter._collect_render_regions. candidate invokes one test-only function-local pass and the original render_regions/_prepare_region helpers. The full authority topology remains 2,766 cells and is not the timed view membership.",
		"timing_semantics": "VisualLanguage load, fixture setup, 120+40 simulation ticks, presenter _prepare_court topology setup, equivalence/Variant-byte checks, ownership checks, authority hashes, and receipt work are outside timers. Each sample times only one views+prepared-regions bundle; no CanvasItem draw or rendering completion is timed.",
		"claim_limit": "Preparation-only diagnostic. It does not establish full hex_ground, draw, frame, rendered, GPU, network, capacity, export, package, or release improvement. No cache crosses calls or frames.",
	}
	_finish(receipt)


func _equivalence_cases(language: VisualLanguage) -> void:
	var empty_fixture: Dictionary = _fixture("dense-crucible")
	var empty_court: HexChemistryWorld = empty_fixture.world.hex_court
	var occupied_presenter: HexCourtPresenter = _prepared_presenter(empty_court, language, false)
	_check(occupied_presenter._cells.is_empty(), "empty occupied-only court prepares no cells")
	_assert_equivalent(empty_court, occupied_presenter, 0.0, "empty occupied-only court avoids per-cell template work")
	var full_empty_presenter: HexCourtPresenter = _prepared_presenter(empty_court, language, true)
	_check(full_empty_presenter._cells.size() == EXPECTED_TOPOLOGY_CELLS, "empty full court retains the complete presentation topology")
	_assert_equivalent(empty_court, full_empty_presenter, 0.0, "empty full-topology court")
	var derived := DerivedCourt.new()
	var derived_cells: Array[Vector2i] = [Vector2i.ZERO]
	_check(derived.configure_geometry(Vector2i.ZERO, derived_cells), "derived structural guard fixture configures")
	var derived_presenter: HexCourtPresenter = _prepared_presenter(derived, language, true)
	_check(Candidate.candidate_bundle(derived, derived_presenter, 0.0).is_empty(), "candidate declines subclasses so generic presenter behavior remains the required fallback")

	var rich: HexChemistryWorld = _rich_court()
	var rich_presenter: HexCourtPresenter = _prepared_presenter(rich, language, true)
	for tick: float in [19.5, 20.0, 33.5, 34.0, 39.5, 40.0, 69.5, 70.0, 99.5, 100.0]:
		_assert_equivalent(rich, rich_presenter, tick, "phase boundary or fractional tick %.1f" % tick)
	_assert_equivalent(rich, rich_presenter, 50.25, "overlap owners, expiries, zero quantity presence, and missing/extra layers")

	var mutation_tick := 50.25
	var before: Dictionary = Candidate.candidate_bundle(rich, rich_presenter, mutation_tick)
	_assert_equivalent(rich, rich_presenter, mutation_tick, "direct mutation baseline")
	var original_intensity: int = rich.products[21].intensity
	rich.products[21].intensity = original_intensity + 777
	var mutated: Dictionary = Candidate.candidate_bundle(rich, rich_presenter, mutation_tick)
	_check(var_to_bytes(mutated) != var_to_bytes(before), "direct product mutation is visible on the next candidate call")
	_assert_equivalent(rich, rich_presenter, mutation_tick, "direct mutation visible")
	rich.products[21].intensity = original_intensity
	_assert_equivalent(rich, rich_presenter, mutation_tick, "direct mutation restoration")
	_check(var_to_bytes(Candidate.candidate_bundle(rich, rich_presenter, mutation_tick)) == var_to_bytes(before), "restoration recovers exact original bundle bytes")

	_assert_independent_outputs(rich, rich_presenter, mutation_tick)
	var missing_cell: HexChemistryWorld = _rich_court()
	var missing_presenter: HexCourtPresenter = _prepared_presenter(missing_cell, language, true)
	missing_cell.cells.erase(Vector2i.RIGHT)
	_assert_equivalent(missing_cell, missing_presenter, mutation_tick, "stale prepared membership with missing authority cell preserves two-field view")
	var iterable_layer: HexChemistryWorld = _rich_court()
	var iterable_presenter: HexCourtPresenter = _prepared_presenter(iterable_layer, language, true)
	iterable_layer.cells[Vector2i.ZERO].fire = [11, 12]
	_assert_equivalent(iterable_layer, iterable_presenter, mutation_tick, "renderable non-Dictionary material lane uses exact current fallback")
	var iterable_cell: HexChemistryWorld = _rich_court()
	var iterable_cell_presenter: HexCourtPresenter = _prepared_presenter(iterable_cell, language, true)
	iterable_cell.cells[Vector2i.RIGHT] = []
	_assert_equivalent(iterable_cell, iterable_cell_presenter, mutation_tick, "renderable non-Dictionary cell record uses exact current fallback")
	var rejected_region: HexChemistryWorld = _rich_court()
	var rejected_region_presenter: HexCourtPresenter = _prepared_presenter(rejected_region, language, true)
	rejected_region.products[21].flow_aim = "invalid"
	_assert_equivalent(rejected_region, rejected_region_presenter, mutation_tick, "prepare-region rejection preserves complete views and fails regions closed")


func _assert_equivalent(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float, label: String) -> void:
	var authority_bytes: PackedByteArray = _authority_bytes(court)
	var current: Dictionary = Candidate.current_bundle(court, presenter, tick)
	var candidate: Dictionary = Candidate.candidate_bundle(court, presenter, tick)
	_check(candidate == current, label + " candidate structure equals actual current loops")
	_check(var_to_bytes(candidate) == var_to_bytes(current), label + " candidate preserves exact Variant bytes and order")
	_check(_authority_bytes(court) == authority_bytes, label + " both paths leave authority unchanged")
	equivalence_cases_completed += 1


func _assert_independent_outputs(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float) -> void:
	var authority_bytes: PackedByteArray = _authority_bytes(court)
	var first: Dictionary = Candidate.candidate_bundle(court, presenter, tick)
	var second: Dictionary = Candidate.candidate_bundle(court, presenter, tick)
	var second_bytes: PackedByteArray = var_to_bytes(second)
	var views: Dictionary = first.views
	var cell_view: Dictionary = views[Vector2i.ZERO]
	cell_view.fire_quantity = int(cell_view.fire_quantity) + 999
	views[Vector2i.ZERO] = cell_view
	first.views = views
	var regions: Dictionary = first.regions
	var fire_by_cell: Dictionary = regions.fire
	var fire_regions: Array = fire_by_cell[Vector2i.ZERO]
	var first_region: Dictionary = fire_regions[0]
	first_region.quantity = int(first_region.quantity) + 888
	var source_ids: Array = first_region.source_ids
	source_ids.append(999_999)
	first_region.source_ids = source_ids
	fire_regions[0] = first_region
	fire_by_cell[Vector2i.ZERO] = fire_regions
	regions.fire = fire_by_cell
	first.regions = regions
	_check(var_to_bytes(first) != second_bytes, "selected output mutation changes the selected bundle")
	_check(var_to_bytes(second) == second_bytes, "separate candidate call owns independent views, regions, and source IDs")
	_check(_authority_bytes(court) == authority_bytes, "output mutation cannot alias mutable authority")
	equivalence_cases_completed += 1


func _profile_case(case_name: String, court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float, fixture: Dictionary) -> Dictionary:
	var authority_hash: String = court.state_hash()
	var authority_bytes: PackedByteArray = _authority_bytes(court)
	var expected: Dictionary = Candidate.current_bundle(court, presenter, tick)
	var expected_bytes: PackedByteArray = var_to_bytes(expected)
	_check(not expected.is_empty() and var_to_bytes(Candidate.candidate_bundle(court, presenter, tick)) == expected_bytes, case_name + " candidate matches current bundle before timing")
	for unused: int in 2:
		_check(var_to_bytes(Candidate.current_bundle(court, presenter, tick)) == expected_bytes, case_name + " current warmup remains exact")
		_check(var_to_bytes(Candidate.candidate_bundle(court, presenter, tick)) == expected_bytes, case_name + " candidate warmup remains exact")
	var all_samples: Dictionary = {"production_current": PackedInt64Array(), "candidate": PackedInt64Array()}
	var block_counts: Dictionary = {"production_current": 0, "candidate": 0}
	var blocks: Array[Dictionary] = []
	for cycle: int in CYCLES:
		var order: Array[String] = []
		if cycle % 2 == 0:
			order.assign(["production_current", "candidate", "candidate", "production_current"])
		else:
			order.assign(["candidate", "production_current", "production_current", "candidate"])
		for block_index: int in BLOCKS_PER_CYCLE:
			var implementation: String = order[block_index]
			var samples: PackedInt64Array = _measure_block(case_name, implementation, court, presenter, tick, expected_bytes)
			_check(samples.size() == SAMPLES_PER_BLOCK, "%s %s cycle %d block %d has every sample" % [case_name, implementation, cycle, block_index])
			var combined: PackedInt64Array = all_samples[implementation]
			combined.append_array(samples)
			all_samples[implementation] = combined
			block_counts[implementation] = int(block_counts[implementation]) + 1
			blocks.append({"cycle": cycle, "block": block_index, "implementation": implementation, "samples_us": Array(samples), "statistics_us": _statistics(samples)})
			_check(court.state_hash() == authority_hash and _authority_bytes(court) == authority_bytes, case_name + " block leaves authority exact")
	var current_samples: PackedInt64Array = all_samples.production_current
	var candidate_samples: PackedInt64Array = all_samples.candidate
	var blocks_per_implementation := EXPECTED_BLOCKS_PER_CASE / 2
	_check(blocks.size() == EXPECTED_BLOCKS_PER_CASE, case_name + " has every alternating block")
	_check(int(block_counts.production_current) == blocks_per_implementation and int(block_counts.candidate) == blocks_per_implementation, case_name + " has balanced implementation blocks")
	_check(current_samples.size() == EXPECTED_SAMPLES_PER_IMPLEMENTATION and candidate_samples.size() == EXPECTED_SAMPLES_PER_IMPLEMENTATION, case_name + " has all 40 samples per implementation")
	_check(var_to_bytes(Candidate.current_bundle(court, presenter, tick)) == expected_bytes and var_to_bytes(Candidate.candidate_bundle(court, presenter, tick)) == expected_bytes, case_name + " post-profile bundles remain byte exact")
	_check(court.state_hash() == authority_hash and _authority_bytes(court) == authority_bytes, case_name + " complete profile preserves authority")
	var current_stats: Dictionary = _statistics(current_samples)
	var candidate_stats: Dictionary = _statistics(candidate_samples)
	profile_cases_completed += 1
	return {
		"case": case_name,
		"tick": tick,
		"topology_cells": court.cells.size(),
		"fixture": fixture.duplicate(true),
		"authority_hash": authority_hash,
		"bundle_variant_bytes": expected_bytes.size(),
		"view_cells": (expected.views as Dictionary).size(),
		"prepared_regions": _prepared_region_count(expected.regions),
		"blocks": blocks,
		"implementations": {
			"production_current": {"statistics_us": current_stats, "samples_us": Array(current_samples)},
			"candidate": {"statistics_us": candidate_stats, "samples_us": Array(candidate_samples)},
		},
		"comparison": {
			"p50_delta_us": int(current_stats.p50) - int(candidate_stats.p50),
			"p95_delta_us": int(current_stats.p95) - int(candidate_stats.p95),
			"p50_candidate_over_current": float(candidate_stats.p50) / float(maxi(1, int(current_stats.p50))),
			"p95_candidate_over_current": float(candidate_stats.p95) / float(maxi(1, int(current_stats.p95))),
		},
	}


func _measure_block(case_name: String, implementation: String, court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float, expected_bytes: PackedByteArray) -> PackedInt64Array:
	var samples := PackedInt64Array()
	for sample_index: int in SAMPLES_PER_BLOCK:
		var started: int = Time.get_ticks_usec()
		var actual: Dictionary = Candidate.current_bundle(court, presenter, tick) if implementation == "production_current" else Candidate.candidate_bundle(court, presenter, tick)
		samples.append(Time.get_ticks_usec() - started)
		_check(var_to_bytes(actual) == expected_bytes, "%s %s sample %d preserves exact bundle bytes" % [case_name, implementation, sample_index])
	return samples


func _profile_case_complete(result: Dictionary) -> bool:
	if result.is_empty() or int(result.get("topology_cells", 0)) != EXPECTED_TOPOLOGY_CELLS:
		return false
	var fixture: Variant = result.get("fixture")
	if not fixture is Dictionary or int(result.get("view_cells", 0)) <= 0 or int(result.view_cells) != int(fixture.get("presenter_cells", -1)):
		return false
	var blocks: Variant = result.get("blocks")
	if not blocks is Array or blocks.size() != EXPECTED_BLOCKS_PER_CASE:
		return false
	for block: Variant in blocks:
		if not block is Dictionary or not block.get("samples_us") is Array or block.samples_us.size() != SAMPLES_PER_BLOCK:
			return false
	var implementations: Variant = result.get("implementations")
	if not implementations is Dictionary:
		return false
	for implementation: String in ["production_current", "candidate"]:
		var row: Variant = implementations.get(implementation)
		if not row is Dictionary or not row.get("samples_us") is Array or row.samples_us.size() != EXPECTED_SAMPLES_PER_IMPLEMENTATION:
			return false
	return true


func _prepared_presenter(court: HexChemistryWorld, language: VisualLanguage, include_empty: bool) -> HexCourtPresenter:
	var presenter := Presenter.new()
	_check(presenter.configure(language), "candidate presenter configures with production language")
	_check(presenter._prepare_court(court, include_empty), "candidate presenter prepares exact court topology outside timers")
	return presenter


func _rich_court() -> HexChemistryWorld:
	var court := HexChemistryWorld.new()
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	_check(court.configure_geometry(Vector2i(640_000, 480_000), cells), "rich presentation fixture configures")
	var fire_parts_a: Dictionary = {}
	fire_parts_a[301] = {"created": 10, "expiry_tick": 100, "coverage": {Vector2i.ZERO: 1}, "cells": {Vector2i.ZERO: 12}}
	fire_parts_a[299] = {"created": 0, "expiry_tick": 80, "coverage": {Vector2i.ZERO: 1}, "cells": {Vector2i.ZERO: 0}}
	court.casts[11] = {"owner": 2, "source": 101, "aim": Vector2i(900, -100), "ground_parts": fire_parts_a}
	court.casts[12] = {"owner": 3, "source": 102, "aim": Vector2i(-400, 600), "ground_parts": {
		305: {"created": 5, "expiry_tick": 120, "coverage": {Vector2i.ZERO: 1}, "cells": {Vector2i.ZERO: 7}},
	}}
	court.cells[Vector2i.ZERO].fire = {11: 12, 12: 7}
	court.products[21] = {"active_tick": 20, "decay_tick": 70, "expiry_tick": 100, "intensity": 1_400, "cells": {Vector2i.ZERO: 0}, "owner": 4, "source_ids": [101, 102], "recipe_wire_id": 310, "flow_aim": Vector2i(1000, 0)}
	court.products[22] = {"active_tick": 0, "decay_tick": 90, "expiry_tick": 130, "intensity": 900, "cells": {Vector2i.ZERO: 5}, "owner": 5, "source_ids": [103], "recipe_wire_id": 310, "flow_aim": Vector2i(0, -1000)}
	court.cells[Vector2i.ZERO].steam = {21: 0, 22: 5}
	court.cells[Vector2i.RIGHT].erase("dark")
	court.cells[Vector2i.RIGHT]["extra_layer"] = {999: 1}
	return court


func _authority_bytes(court: HexChemistryWorld) -> PackedByteArray:
	return var_to_bytes([court.cells, court.casts, court.products, court.origin, court.current_tick])


func _prepared_region_count(regions_value: Variant) -> int:
	if not regions_value is Dictionary:
		return -1
	var result := 0
	for material_value: Variant in (regions_value as Dictionary).values():
		if not material_value is Dictionary:
			return -1
		for rows_value: Variant in (material_value as Dictionary).values():
			if not rows_value is Array:
				return -1
			result += (rows_value as Array).size()
	return result


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


func _candidate_source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_hex_render_frame_candidate.gd",
		"tests/support/hex_render_frame_candidate.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/presentation/hex_court_presenter.gd",
		"src/presentation/visual_language.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/hex/hex_recipe_policy.gd",
		"content/visual/visual_language_v1.json",
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
		_check(output != null, "render frame receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-render-frame-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
