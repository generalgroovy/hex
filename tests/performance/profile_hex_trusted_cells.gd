extends SceneTree
@warning_ignore_start("integer_division")

# Matched microprofile for the isolated trusted-topology validator. Both paths
# receive the same unchanged production 2,766-cell Wellspring authority. The
# control is a frozen copy of the pre-optimization function, not a reconstruction
# of the candidate branch. Equality and source checks stay outside every timer.
const LegacyTrustedCells = preload("res://tests/support/hex_trusted_cells_legacy_oracle.gd")
const MAP_PATH := "res://content/maps/sanctum_campus_g2_v1.json"
const EXPECTED_TOPOLOGY_CELLS := 2_766
const CYCLES := 4
const SAMPLES_PER_BLOCK := 7
const BLOCKS_PER_CYCLE := 4
const TICK_BUDGET_US := 8_333
const FRAME_BUDGET_US := 16_667

var output_path := ""
var assertions := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-trusted-cells-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"profile receipt path is fresh and scoped",
	)
	var layout := SanctumCampusLayout.new()
	_check(layout.load_from_file(MAP_PATH), "production Wellspring campus loads")
	var definition := HexWorldDefinition.from_campus(layout)
	_check(definition != null, "production whole-map definition builds")
	if definition == null:
		_finish({})
		return
	_check(definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "profile uses the exact 2,766-cell production topology")
	var cases: Array[Dictionary] = []
	for case_name: String in ["empty-2766", "sparse-29", "dense-2766"]:
		var authority: HexChemistryWorld = definition.create_authority()
		_check(authority != null, case_name + " creates one trusted production topology")
		if authority == null:
			continue
		var ordered: Array[Vector2i] = LegacyTrustedCells.trusted_cells(authority)
		var nonempty_records := 0
		if case_name == "sparse-29":
			nonempty_records = 29
		elif case_name == "dense-2766":
			nonempty_records = ordered.size()
		var material := HexChemistryWorld.material_layers()[0]
		for index: int in nonempty_records:
			authority.cells[ordered[index]][material][900_000 + index] = index + 1
		cases.append(_profile_case(case_name, authority, nonempty_records))
	if failures > 0:
		_finish({})
		return

	var receipt := {
		"schema_version": 1,
		"profile_version": "hex-trusted-cells-abba-v1",
		"engine": Engine.get_version_info().get("string", ""),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"map_path": MAP_PATH,
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"topology_cells": EXPECTED_TOPOLOGY_CELLS,
		"cycles": CYCLES,
		"blocks_per_cycle": BLOCKS_PER_CYCLE,
		"samples_per_block": SAMPLES_PER_BLOCK,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"cases": cases,
		"source_sha256": _source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless isolated validation of the same production 2,766-cell topology with empty, representative 29-nonempty-record, and synthetic all-nonempty fallback pressure. Each timed sample includes only one validator call and its required returned-array allocation/sort. Fixture construction, warmup, equality, state hashing, topology hashing, assertions and receipt work are outside timers. Nonempty records contain one synthetic material entry only; they are validator pressure, not a legal paid simulation workload.",
		"allocations": "not available from the Godot runtime; no allocation count is claimed",
		"percentile_limit": "Each implementation has 56 samples per case. p99 is the sample-limited nearest-rank maximum and is reported for completeness, not as a tail-capacity estimate.",
		"acceptance": "Exact output/source equivalence is mandatory. The empty case should improve; sparse and dense cases quantify fallback overhead and may not. A local timing reduction is diagnostic only and does not establish end-to-end snapshot, simulation, frame, 120 Hz, multiplayer or release capacity.",
	}
	_finish(receipt)


func _profile_case(case_name: String, authority: HexChemistryWorld, nonempty_records: int) -> Dictionary:
	var source_identity := authority.get_instance_id()
	var source_hash := authority.state_hash()
	var source_cells: Dictionary = authority.cells.duplicate(true)
	var legacy_expected: Array[Vector2i] = LegacyTrustedCells.trusted_cells(authority)
	var candidate_expected: Array[Vector2i] = HexChemistrySnapshot._trusted_cells(authority)
	_check(legacy_expected.size() == EXPECTED_TOPOLOGY_CELLS, case_name + " frozen legacy validator accepts every production cell")
	_check(candidate_expected == legacy_expected, case_name + " candidate and legacy produce identical ordered cells")
	var topology_hash := HexChemistrySnapshot._topology_hash(authority, legacy_expected)
	_check(topology_hash.length() == 64, case_name + " ordered topology has a complete fingerprint")
	for unused: int in 3:
		_check(LegacyTrustedCells.trusted_cells(authority) == legacy_expected, case_name + " legacy warmup remains exact")
		_check(HexChemistrySnapshot._trusted_cells(authority) == legacy_expected, case_name + " candidate warmup remains exact")

	var all_samples := {"legacy": PackedInt64Array(), "candidate": PackedInt64Array()}
	var blocks: Array[Dictionary] = []
	var block_counts := {"legacy": 0, "candidate": 0}
	for cycle: int in CYCLES:
		var order: Array[String] = []
		if cycle % 2 == 0:
			order.assign(["legacy", "candidate", "candidate", "legacy"])
		else:
			order.assign(["candidate", "legacy", "legacy", "candidate"])
		for block_index: int in BLOCKS_PER_CYCLE:
			var implementation := order[block_index]
			var samples := _measure_block(case_name, implementation, authority, legacy_expected)
			_check(samples.size() == SAMPLES_PER_BLOCK, "%s %s cycle %d block %d has every sample" % [case_name, implementation, cycle, block_index])
			var combined: PackedInt64Array = all_samples[implementation]
			combined.append_array(samples)
			all_samples[implementation] = combined
			block_counts[implementation] = int(block_counts[implementation]) + 1
			blocks.append({"cycle": cycle, "block": block_index, "implementation": implementation, "samples_us": Array(samples), "statistics_us": _statistics(samples)})
			# These checks are deliberately outside the sample timers.
			_check(authority.get_instance_id() == source_identity, "%s %s cycle %d block %d retains source identity" % [case_name, implementation, cycle, block_index])
			_check(authority.state_hash() == source_hash, "%s %s cycle %d block %d retains authority hash" % [case_name, implementation, cycle, block_index])
			_check(HexChemistrySnapshot._topology_hash(authority, legacy_expected) == topology_hash, "%s %s cycle %d block %d retains topology hash" % [case_name, implementation, cycle, block_index])

	var legacy_samples: PackedInt64Array = all_samples.legacy
	var candidate_samples: PackedInt64Array = all_samples.candidate
	var expected_blocks_per_implementation := CYCLES * BLOCKS_PER_CYCLE / 2
	var expected_samples_per_implementation := expected_blocks_per_implementation * SAMPLES_PER_BLOCK
	_check(blocks.size() == CYCLES * BLOCKS_PER_CYCLE, case_name + " has every ABBA/BAAB block")
	_check(int(block_counts.legacy) == expected_blocks_per_implementation, case_name + " legacy has every expected block")
	_check(int(block_counts.candidate) == expected_blocks_per_implementation, case_name + " candidate has every expected block")
	var legacy_stats := _statistics(legacy_samples)
	var candidate_stats := _statistics(candidate_samples)
	_check(legacy_samples.size() == expected_samples_per_implementation, case_name + " legacy has the full sample count")
	_check(candidate_samples.size() == expected_samples_per_implementation, case_name + " candidate has the full sample count")
	_check(authority.cells == source_cells and authority.state_hash() == source_hash, case_name + " complete profile leaves source records unchanged")
	_check(HexChemistrySnapshot._trusted_cells(authority) == LegacyTrustedCells.trusted_cells(authority), case_name + " post-profile equivalence remains exact")
	return {
		"case": case_name,
		"topology_cells": authority.cells.size(),
		"nonempty_records": nonempty_records,
		"source_authority_hash": source_hash,
		"topology_hash": topology_hash,
		"blocks": blocks,
		"implementations": {
			"legacy": {"statistics_us": legacy_stats, "samples_us": Array(legacy_samples)},
			"candidate": {"statistics_us": candidate_stats, "samples_us": Array(candidate_samples)},
		},
		"comparison": {
			"p50_delta_us": int(legacy_stats.p50) - int(candidate_stats.p50),
			"p95_delta_us": int(legacy_stats.p95) - int(candidate_stats.p95),
			"p99_delta_us": int(legacy_stats.p99) - int(candidate_stats.p99),
			"p50_candidate_over_legacy": float(candidate_stats.p50) / float(maxi(1, int(legacy_stats.p50))),
			"p95_candidate_over_legacy": float(candidate_stats.p95) / float(maxi(1, int(legacy_stats.p95))),
		},
	}


func _measure_block(case_name: String, implementation: String, authority: HexChemistryWorld, expected: Array[Vector2i]) -> PackedInt64Array:
	var samples := PackedInt64Array()
	for sample_index: int in SAMPLES_PER_BLOCK:
		var started := Time.get_ticks_usec()
		var actual: Array[Vector2i] = LegacyTrustedCells.trusted_cells(authority) if implementation == "legacy" else HexChemistrySnapshot._trusted_cells(authority)
		samples.append(Time.get_ticks_usec() - started)
		# Output checks are intentionally after timing. Keep every sample rather
		# than accepting one representative call.
		_check(actual == expected, "%s %s sample %d returns the exact ordered topology" % [case_name, implementation, sample_index])
	return samples


func _statistics(values: PackedInt64Array) -> Dictionary:
	var ordered: Array = Array(values)
	ordered.sort()
	if ordered.is_empty():
		return {"samples": 0, "min": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0, "over_8333_us": 0, "over_16667_us": 0}
	var tick_misses := 0
	var frame_misses := 0
	for value: int in ordered:
		if value > TICK_BUDGET_US:
			tick_misses += 1
		if value > FRAME_BUDGET_US:
			frame_misses += 1
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


func _percentile_index(size: int, percentile: int) -> int:
	return clampi((size * percentile + 99) / 100 - 1, 0, size - 1)


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_hex_trusted_cells.gd",
		"tests/support/hex_trusted_cells_legacy_oracle.gd",
		"src/net/hex_chemistry_snapshot.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/hex/hex_grid.gd",
		"src/sim/hex/hex_world_definition.gd",
		MAP_PATH.trim_prefix("res://"),
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _finish(receipt: Dictionary) -> void:
	if not receipt.is_empty():
		receipt.assertions = assertions
		receipt.failures = failures
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "profile receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-trusted-cells-abba; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
