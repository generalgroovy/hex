extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Isolated test-only ABBA/BAAB comparison of the exact current composed strict
# packed decode and a single-pass candidate. No world prepare or frame claim is
# made here; fixture construction and all equivalence checks are outside timers.
const Candidate = preload("res://tests/support/hex_wire_decode_candidate.gd")
const WirePacking = preload("res://src/net/hex_snapshot_wire_packing.gd")
const ChemistrySnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")
const ACTIVE_WORKLOAD_TICKS := 40
const EXPECTED_TOPOLOGY_CELLS := 2_766
const SYNTHETIC_TOPOLOGY_CELLS := 4_096
const EXPECTED_ACTIVE_CELLS := 29
const EXPECTED_STORED_CELLS := 49
const CYCLES := 4
const BLOCKS_PER_CYCLE := 4
const SAMPLES_PER_BLOCK := 7
const EXPECTED_EQUIVALENCE_CASES := 87 # 2+4+2+18+9+2+14+16+15+3+1+1
const EXPECTED_PROFILE_CASES := 3
const EXPECTED_BLOCKS_PER_CASE := CYCLES * BLOCKS_PER_CYCLE
const EXPECTED_SAMPLES_PER_IMPLEMENTATION := CYCLES * 2 * SAMPLES_PER_BLOCK

var equivalence_cases_completed := 0
var profile_cases_completed := 0


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-wire-decode-candidate-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"wire decode receipt path is fresh and scoped",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "normal campus supplies the exact 2,766-cell topology")
	if failures > 0:
		_finish({})
		return

	var synthetic_pressure: Dictionary = _maximum_bounded_packed_fixture()
	_equivalence_cases(synthetic_pressure)
	_check(equivalence_cases_completed == EXPECTED_EQUIVALENCE_CASES, "all %d strict decode equivalence cases complete" % EXPECTED_EQUIVALENCE_CASES)
	if failures > 0:
		_finish({})
		return

	var empty_fixture: Dictionary = _fixture("dense-crucible")
	var empty_world: SimWorld = empty_fixture.world
	var empty_packed: Dictionary = _pack_court(empty_world.hex_court)
	var empty_occupancy: Dictionary = _occupancy(empty_world.hex_court, empty_world.tick)
	_check(not empty_packed.is_empty() and int(empty_occupancy.active_cells) == 0, "empty campus packs with no active cells")

	var paid_fixture: Dictionary = _fixture("dense-crucible")
	var paid_world: SimWorld = paid_fixture.world
	var targets: Dictionary = paid_fixture.targets
	for unused: int in range(WARMUP_TICKS):
		_check(paid_world.step(_commands(paid_world, targets, "dense-crucible", false, false)), "legal workload warmup advances")
	for unused: int in range(ACTIVE_WORKLOAD_TICKS):
		_check(paid_world.step(_commands(paid_world, targets, "dense-crucible", true, false)), "legal paid workload advances")
	var paid_court: HexChemistryWorld = paid_world.hex_court
	var paid_occupancy: Dictionary = _occupancy(paid_court, paid_world.tick)
	var paid_stored_cells: int = _nonempty_material_cells(paid_court)
	_check(int(paid_court.metrics.admitted) == 8 and int(paid_court.metrics.matter_paid) == 4_800, "legal workload retains eight admissions and 4,800 paid matter")
	_check(int(paid_occupancy.active_cells) == EXPECTED_ACTIVE_CELLS and paid_stored_cells == EXPECTED_STORED_CELLS, "legal workload retains 29 active and 49 stored material cells")
	_check(paid_court.conservation_valid(), "legal paid authority conserves matter")
	var paid_packed: Dictionary = _pack_court(paid_court)
	_check(not paid_packed.is_empty(), "legal paid campus packs")
	if failures > 0:
		_finish({})
		return

	var cases: Array[Dictionary] = [
		_profile_case("legal-paid-dense-crucible", paid_packed, EXPECTED_TOPOLOGY_CELLS, {
			"world_tick": paid_world.tick,
			"actors": paid_world.players.size(),
			"metrics": paid_court.metrics.duplicate(true),
			"occupancy": paid_occupancy,
			"stored_material_cells": paid_stored_cells,
		}),
		_profile_case("production-empty-campus", empty_packed, EXPECTED_TOPOLOGY_CELLS, {
			"world_tick": empty_world.tick,
			"actors": empty_world.players.size(),
			"metrics": empty_world.hex_court.metrics.duplicate(true),
			"occupancy": empty_occupancy,
			"stored_material_cells": _nonempty_material_cells(empty_world.hex_court),
		}),
		_profile_case("synthetic-max-bounded-packed-lanes", synthetic_pressure, SYNTHETIC_TOPOLOGY_CELLS, {
			"non_gameplay": true,
			"cast_rows": WirePacking.MAX_CASTS,
			"product_rows": WirePacking.MAX_PRODUCTS,
			"cast_allocation_rows": WirePacking.MAX_CAST_ALLOCATION_ROWS,
			"product_allocation_rows": WirePacking.MAX_PRODUCT_ALLOCATION_ROWS,
			"variable_payload_policy": "zero-length payloads because the current grammar has no payload-count maximum",
		}),
	]
	var expected_names: Array[String] = ["legal-paid-dense-crucible", "production-empty-campus", "synthetic-max-bounded-packed-lanes"]
	_check(profile_cases_completed == EXPECTED_PROFILE_CASES and cases.size() == EXPECTED_PROFILE_CASES, "all three decode profile cases complete")
	for index: int in expected_names.size():
		_check(_profile_case_complete(cases[index], expected_names[index]), expected_names[index] + " contains every block and sample")
	if failures > 0:
		_finish({})
		return

	var receipt: Dictionary = {
		"schema_version": 1,
		"profile_version": "hex-wire-decode-candidate-abba-v1",
		"workload_version": "unified-wellspring-profile-v1/dense-crucible-first-40",
		"engine": Engine.get_version_info().get("string", ""),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"map_path": "res://content/maps/sanctum_campus_g2_v1.json",
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"known_topology_cells": EXPECTED_TOPOLOGY_CELLS,
		"warmup_ticks": WARMUP_TICKS,
		"active_workload_ticks": ACTIVE_WORKLOAD_TICKS,
		"cycles": CYCLES,
		"blocks_per_cycle": BLOCKS_PER_CYCLE,
		"samples_per_block": SAMPLES_PER_BLOCK,
		"batch_size": 1,
		"samples_per_implementation_per_case": EXPECTED_SAMPLES_PER_IMPLEMENTATION,
		"equivalence_cases_completed": equivalence_cases_completed,
		"profile_cases_completed": profile_cases_completed,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"cases": cases,
		"source_sha256": _candidate_source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless isolated strict packed-decode comparison. production_composed is the actual validate_structure(packed, cell_count) then unpack(packed, cell_count) pipeline; candidate is a test-only single traversal using the same production leaf helpers. Empty and paid cases use the genuine 2,766-cell campus. The maximum bounded packed-lane case is synthetic non-gameplay pressure.",
		"timing_semantics": "Fixture construction, 120 neutral plus 40 paid ticks, source hashing, byte/equality verification, malformed cases, and output ownership checks are outside timers. Each sample times one decode call; batch_size is one.",
		"claim_limit": "Decode-only diagnostic. It does not establish whole prepare, capture, frame, rendered, networking, allocation, export, or release gains, and it does not alter compression, topology, cadence, workload, or capacity.",
	}
	_finish(receipt)


func _equivalence_cases(synthetic_pressure: Dictionary) -> void:
	var base: Dictionary = _small_valid_packed_fixture()
	_assert_decode_case(base, 8, true, "minimal valid packed fixture")

	var loose_semantics: Dictionary = base.duplicate(true)
	loose_semantics.topology_hash = ""
	loose_semantics.authority_hash = "arbitrary"
	loose_semantics.pending = PackedInt32Array([9, -7, 0, 12])
	loose_semantics.sources = PackedInt32Array([31])
	loose_semantics.exposure = PackedInt32Array([1, 2, 3, 4, 5])
	loose_semantics.flow_carry = PackedInt32Array([-99, 88])
	loose_semantics.metrics = PackedInt64Array([7, -4, 0, 9001])
	_assert_decode_case(loose_semantics, 8, true, "accepted arbitrary hash contents, direct lanes, metrics, and zero-length variable payloads")

	_assert_decode_case(base, 0, false, "cell count zero rejects")
	_assert_decode_case(base, -1, false, "composed decode rejects validator-default minus one because unpack rejects it")
	_assert_decode_case(base, 4_096, true, "maximum topology cell count accepts")
	_assert_decode_case(base, 4_097, false, "cell count above maximum rejects")

	var missing_key: Dictionary = base.duplicate(true)
	missing_key.erase("metrics")
	_assert_decode_case(missing_key, 8, false, "missing required key rejects")
	var extra_key: Dictionary = base.duplicate(true)
	extra_key.extra = 1
	_assert_decode_case(extra_key, 8, false, "extra key rejects")

	var wrong_types: Dictionary = {
		"schema": "3", "topology_hash": 3, "authority_hash": 4,
		"header": [], "cast_ids": [], "casts": [], "cast_allocations": PackedInt32Array(),
		"product_ids": [], "products": [], "product_sources": [], "product_allocations": PackedInt32Array(),
		"cast_parts": [], "product_states": [], "pending": [], "sources": [], "exposure": [], "flow_carry": [],
		"metrics": PackedInt32Array(),
	}
	for key: String in WirePacking.KEYS:
		var wrong_type: Dictionary = base.duplicate(true)
		wrong_type[key] = wrong_types[key]
		_assert_decode_case(wrong_type, 8, false, "%s wrong lane type rejects" % key)

	var wrong_schema: Dictionary = base.duplicate(true)
	wrong_schema.schema = 2
	_assert_decode_case(wrong_schema, 8, false, "wrong schema value rejects")
	for header_size: int in [4, 6]:
		var wrong_header_size: Dictionary = base.duplicate(true)
		var resized_header: PackedInt32Array = wrong_header_size.header
		resized_header.resize(header_size)
		wrong_header_size.header = resized_header
		_assert_decode_case(wrong_header_size, 8, false, "header size %d rejects" % header_size)
	var header_mutations: Array[Dictionary] = [
		{"index": 0, "value": -1, "label": "negative tick"},
		{"index": 1, "value": -1, "label": "negative enabled flag"},
		{"index": 1, "value": 2, "label": "enabled flag above one"},
		{"index": 2, "value": 0, "label": "zero next cast id"},
		{"index": 3, "value": 0, "label": "zero next product id"},
		{"index": 4, "value": 0, "label": "zero next ground part id"},
	]
	for mutation: Dictionary in header_mutations:
		var wrong_header: Dictionary = base.duplicate(true)
		var header: PackedInt32Array = wrong_header.header
		header[int(mutation.index)] = int(mutation.value)
		wrong_header.header = header
		_assert_decode_case(wrong_header, 8, false, String(mutation.label) + " rejects")

	var too_many_casts: Dictionary = synthetic_pressure.duplicate(true)
	var cast_ids: PackedInt32Array = too_many_casts.cast_ids
	cast_ids.append(10_001)
	too_many_casts.cast_ids = cast_ids
	var casts: PackedInt32Array = too_many_casts.casts
	casts.append_array(_flat_row(WirePacking.CAST_ROW_SIZE, 10_001))
	too_many_casts.casts = casts
	var cast_parts: PackedInt32Array = too_many_casts.cast_parts
	cast_parts.append_array(PackedInt32Array([10_001, 0]))
	too_many_casts.cast_parts = cast_parts
	_assert_decode_case(too_many_casts, SYNTHETIC_TOPOLOGY_CELLS, false, "cast count above 64 rejects")
	var too_many_products: Dictionary = synthetic_pressure.duplicate(true)
	var product_ids: PackedInt32Array = too_many_products.product_ids
	product_ids.append(20_001)
	too_many_products.product_ids = product_ids
	var products: PackedInt32Array = too_many_products.products
	products.append_array(_flat_row(WirePacking.PRODUCT_ROW_SIZE, 20_001))
	too_many_products.products = products
	for lane: String in ["product_sources", "product_states"]:
		var values: PackedInt32Array = too_many_products[lane]
		values.append_array(PackedInt32Array([20_001, 0]))
		too_many_products[lane] = values
	_assert_decode_case(too_many_products, SYNTHETIC_TOPOLOGY_CELLS, false, "product count above 32 rejects")

	for prefix: String in ["cast", "product"]:
		_id_rejection_cases(base, prefix)
	for prefix: String in ["cast", "product"]:
		_sparse_rejection_cases(base, prefix, 8)
	for lane: String in ["product_sources", "cast_parts", "product_states"]:
		_variable_rejection_cases(base, lane)

	var directly_mutated: Dictionary = base.duplicate(true)
	_assert_decode_case(directly_mutated, 8, true, "direct mutation source starts valid")
	var original_header: PackedInt32Array = directly_mutated.header.duplicate()
	var mutated_header: PackedInt32Array = directly_mutated.header
	mutated_header[1] = 7
	directly_mutated.header = mutated_header
	_assert_decode_case(directly_mutated, 8, false, "direct between-call mutation is observed")
	directly_mutated.header = original_header
	_assert_decode_case(directly_mutated, 8, true, "direct restoration is observed")

	_assert_output_independence(base, 8)
	_assert_decode_case(synthetic_pressure, SYNTHETIC_TOPOLOGY_CELLS, true, "maximum bounded packed-lane synthetic pressure accepts")


func _id_rejection_cases(base: Dictionary, prefix: String) -> void:
	var ids_key := prefix + "_ids"
	var rows_key := "casts" if prefix == "cast" else "products"
	var width := WirePacking.CAST_ROW_SIZE if prefix == "cast" else WirePacking.PRODUCT_ROW_SIZE
	for kind: String in ["duplicate", "decreasing", "zero", "negative"]:
		var malformed: Dictionary = base.duplicate(true)
		var ids: PackedInt32Array = malformed[ids_key]
		var rows: PackedInt32Array = malformed[rows_key]
		if kind == "duplicate":
			ids[1] = ids[0]
			rows[width] = rows[0]
		elif kind == "decreasing":
			var first: int = ids[0]
			ids[0] = ids[1]
			ids[1] = first
			rows[0] = ids[0]
			rows[width] = ids[1]
		elif kind == "zero":
			ids[0] = 0
			rows[0] = 0
		else:
			ids[0] = -1
			rows[0] = -1
		malformed[ids_key] = ids
		malformed[rows_key] = rows
		_assert_decode_case(malformed, 8, false, "%s %s id ordering/value rejects" % [prefix, kind])
	var row_mismatch: Dictionary = base.duplicate(true)
	var mismatch_rows: PackedInt32Array = row_mismatch[rows_key]
	mismatch_rows[0] += 100
	row_mismatch[rows_key] = mismatch_rows
	_assert_decode_case(row_mismatch, 8, false, "%s row id mismatch rejects" % prefix)
	var short_rows: Dictionary = base.duplicate(true)
	var shortened: PackedInt32Array = short_rows[rows_key]
	shortened.resize(shortened.size() - 1)
	short_rows[rows_key] = shortened
	_assert_decode_case(short_rows, 8, false, "%s flattened row truncation rejects" % prefix)
	var long_rows: Dictionary = base.duplicate(true)
	var lengthened: PackedInt32Array = long_rows[rows_key]
	lengthened.append(0)
	long_rows[rows_key] = lengthened
	_assert_decode_case(long_rows, 8, false, "%s flattened row trailing value rejects" % prefix)


func _sparse_rejection_cases(base: Dictionary, prefix: String, cell_count: int) -> void:
	var lane := prefix + "_allocations"
	var maximum := WirePacking.MAX_CAST_ALLOCATION_ROWS if prefix == "cast" else WirePacking.MAX_PRODUCT_ALLOCATION_ROWS
	var truncated: Dictionary = base.duplicate(true)
	var truncated_plane: PackedByteArray = truncated[lane]
	truncated_plane.resize(truncated_plane.size() - 1)
	truncated[lane] = truncated_plane
	_assert_decode_case(truncated, cell_count, false, "%s sparse truncation rejects" % prefix)
	var trailing: Dictionary = base.duplicate(true)
	var trailing_plane: PackedByteArray = trailing[lane]
	trailing_plane.append(0)
	trailing[lane] = trailing_plane
	_assert_decode_case(trailing, cell_count, false, "%s sparse trailing byte rejects" % prefix)
	var row_bound: Dictionary = base.duplicate(true)
	var row_bound_plane: PackedByteArray = row_bound[lane]
	var ids: PackedInt32Array = row_bound[prefix + "_ids"]
	row_bound_plane.encode_u16(2, ids.size())
	row_bound[lane] = row_bound_plane
	_assert_decode_case(row_bound, cell_count, false, "%s sparse row bound rejects" % prefix)
	var cell_bound: Dictionary = base.duplicate(true)
	var cell_bound_plane: PackedByteArray = cell_bound[lane]
	cell_bound_plane.encode_u16(4, cell_count)
	cell_bound[lane] = cell_bound_plane
	_assert_decode_case(cell_bound, cell_count, false, "%s sparse cell bound rejects" % prefix)
	var zero_amount: Dictionary = base.duplicate(true)
	var zero_plane: PackedByteArray = zero_amount[lane]
	zero_plane.encode_u16(6, 0)
	zero_amount[lane] = zero_plane
	_assert_decode_case(zero_amount, cell_count, false, "%s sparse zero amount rejects" % prefix)
	var duplicate_order: Dictionary = base.duplicate(true)
	var duplicate_plane: PackedByteArray = duplicate_order[lane]
	duplicate_plane.encode_u16(8, duplicate_plane.decode_u16(2))
	duplicate_plane.encode_u16(10, duplicate_plane.decode_u16(4))
	duplicate_plane.encode_u16(12, 1)
	duplicate_order[lane] = duplicate_plane
	_assert_decode_case(duplicate_order, cell_count, false, "%s sparse duplicate order rejects" % prefix)
	var decreasing_order: Dictionary = base.duplicate(true)
	var decreasing_plane: PackedByteArray = decreasing_order[lane]
	decreasing_plane.encode_u16(2, 1)
	decreasing_plane.encode_u16(4, 1)
	decreasing_plane.encode_u16(8, 0)
	decreasing_plane.encode_u16(10, 0)
	decreasing_order[lane] = decreasing_plane
	_assert_decode_case(decreasing_order, cell_count, false, "%s sparse decreasing order rejects" % prefix)
	var excessive: Dictionary = base.duplicate(true)
	excessive[lane] = _counted_sparse_plane(maximum + 1)
	_assert_decode_case(excessive, cell_count, false, "%s sparse maximum row count rejects" % prefix)


func _variable_rejection_cases(base: Dictionary, lane: String) -> void:
	var ids_key := "cast_ids" if lane == "cast_parts" else "product_ids"
	var expected_ids: PackedInt32Array = base[ids_key]
	var wrong_id: Dictionary = base.duplicate(true)
	var wrong_id_values: PackedInt32Array = wrong_id[lane]
	wrong_id_values[0] = expected_ids[0] + 100
	wrong_id[lane] = wrong_id_values
	_assert_decode_case(wrong_id, 8, false, lane + " wrong id rejects")
	var negative_count: Dictionary = base.duplicate(true)
	var negative_values: PackedInt32Array = negative_count[lane]
	negative_values[1] = -1
	negative_count[lane] = negative_values
	_assert_decode_case(negative_count, 8, false, lane + " negative count rejects")
	var truncated_header: Dictionary = base.duplicate(true)
	var truncated_header_values: PackedInt32Array = truncated_header[lane]
	truncated_header_values.resize(truncated_header_values.size() - 1)
	truncated_header[lane] = truncated_header_values
	_assert_decode_case(truncated_header, 8, false, lane + " truncated row header rejects")
	var truncated_payload: Dictionary = base.duplicate(true)
	truncated_payload[lane] = PackedInt32Array([expected_ids[0], 1])
	_assert_decode_case(truncated_payload, 8, false, lane + " truncated payload rejects")
	var trailing: Dictionary = base.duplicate(true)
	var trailing_values: PackedInt32Array = trailing[lane]
	trailing_values.append(999)
	trailing[lane] = trailing_values
	_assert_decode_case(trailing, 8, false, lane + " trailing value rejects")


func _assert_decode_case(packed: Dictionary, cell_count: int, expected_success: bool, label: String) -> void:
	var source_bytes: PackedByteArray = var_to_bytes(packed)
	var current: Dictionary = Candidate.composed_current(packed, cell_count)
	var candidate: Dictionary = Candidate.strict_decode(packed, cell_count)
	_check((not current.is_empty()) == expected_success, label + " current composed result has expected acceptance")
	_check(candidate == current and var_to_bytes(candidate) == var_to_bytes(current), label + " candidate preserves exact value and bytes")
	_check(var_to_bytes(packed) == source_bytes, label + " both decoders leave packed source unchanged")
	equivalence_cases_completed += 1


func _assert_output_independence(packed: Dictionary, cell_count: int) -> void:
	var packed_bytes: PackedByteArray = var_to_bytes(packed)
	var first: Dictionary = Candidate.strict_decode(packed, cell_count)
	var second: Dictionary = Candidate.strict_decode(packed, cell_count)
	var untouched_second: PackedByteArray = var_to_bytes(second)
	var cast_rows: Array = first.casts
	var first_cast: PackedInt64Array = cast_rows[0]
	first_cast[1] += 777
	cast_rows[0] = first_cast
	first.casts = cast_rows
	var product_sources: Array = first.product_sources
	var first_source: PackedInt64Array = product_sources[0]
	first_source[0] += 444
	product_sources[0] = first_source
	first.product_sources = product_sources
	var cast_cells: PackedInt64Array = first.cast_cells
	cast_cells[2] += 222
	first.cast_cells = cast_cells
	var header: PackedInt64Array = first.header
	header[0] += 111
	first.header = header
	var metrics: PackedInt64Array = first.metrics
	metrics[0] += 333
	first.metrics = metrics
	_check(var_to_bytes(first) != untouched_second, "nested output mutation changes only the selected decode")
	_check(var_to_bytes(second) == untouched_second, "second decode owns fresh nested rows and metrics")
	_check(var_to_bytes(packed) == packed_bytes, "decoded nested output does not alias packed input")
	equivalence_cases_completed += 1


func _profile_case(case_name: String, packed: Dictionary, cell_count: int, fixture: Dictionary) -> Dictionary:
	var source_bytes: PackedByteArray = var_to_bytes(packed)
	var expected: Dictionary = Candidate.composed_current(packed, cell_count)
	var expected_bytes: PackedByteArray = var_to_bytes(expected)
	_check(not expected.is_empty() and Candidate.strict_decode(packed, cell_count) == expected, case_name + " candidate equals composed current before timing")
	for unused: int in 3:
		_check(var_to_bytes(Candidate.composed_current(packed, cell_count)) == expected_bytes, case_name + " current warmup remains exact")
		_check(var_to_bytes(Candidate.strict_decode(packed, cell_count)) == expected_bytes, case_name + " candidate warmup remains exact")

	var all_samples: Dictionary = {"production_composed": PackedInt64Array(), "candidate": PackedInt64Array()}
	var block_counts: Dictionary = {"production_composed": 0, "candidate": 0}
	var blocks: Array[Dictionary] = []
	for cycle: int in CYCLES:
		var order: Array[String] = []
		if cycle % 2 == 0:
			order.assign(["production_composed", "candidate", "candidate", "production_composed"])
		else:
			order.assign(["candidate", "production_composed", "production_composed", "candidate"])
		for block_index: int in BLOCKS_PER_CYCLE:
			var implementation: String = order[block_index]
			var samples: PackedInt64Array = _measure_block(case_name, implementation, packed, cell_count, expected_bytes)
			_check(samples.size() == SAMPLES_PER_BLOCK, "%s %s cycle %d block %d has every sample" % [case_name, implementation, cycle, block_index])
			var combined: PackedInt64Array = all_samples[implementation]
			combined.append_array(samples)
			all_samples[implementation] = combined
			block_counts[implementation] = int(block_counts[implementation]) + 1
			blocks.append({"cycle": cycle, "block": block_index, "implementation": implementation, "samples_us": Array(samples), "statistics_us": _statistics(samples)})
			_check(var_to_bytes(packed) == source_bytes, "%s %s cycle %d block %d preserves packed source" % [case_name, implementation, cycle, block_index])

	var production_samples: PackedInt64Array = all_samples.production_composed
	var candidate_samples: PackedInt64Array = all_samples.candidate
	var expected_blocks_per_implementation := CYCLES * BLOCKS_PER_CYCLE / 2
	_check(blocks.size() == EXPECTED_BLOCKS_PER_CASE, case_name + " has every ABBA/BAAB block")
	_check(int(block_counts.production_composed) == expected_blocks_per_implementation and int(block_counts.candidate) == expected_blocks_per_implementation, case_name + " both implementations have every block")
	_check(production_samples.size() == EXPECTED_SAMPLES_PER_IMPLEMENTATION and candidate_samples.size() == EXPECTED_SAMPLES_PER_IMPLEMENTATION, case_name + " both implementations have all 56 samples")
	_check(var_to_bytes(Candidate.composed_current(packed, cell_count)) == expected_bytes and var_to_bytes(Candidate.strict_decode(packed, cell_count)) == expected_bytes, case_name + " post-profile outputs remain exact")
	_check(var_to_bytes(packed) == source_bytes, case_name + " complete profile leaves packed source unchanged")
	var production_stats: Dictionary = _statistics(production_samples)
	var candidate_stats: Dictionary = _statistics(candidate_samples)
	profile_cases_completed += 1
	return {
		"case": case_name,
		"cell_count": cell_count,
		"packed_lane_bytes": WirePacking.byte_size(packed),
		"packed_variant_bytes": source_bytes.size(),
		"decoded_variant_bytes": expected_bytes.size(),
		"fixture": fixture.duplicate(true),
		"blocks": blocks,
		"implementations": {
			"production_composed": {"statistics_us": production_stats, "samples_us": Array(production_samples)},
			"candidate": {"statistics_us": candidate_stats, "samples_us": Array(candidate_samples)},
		},
		"comparison": {
			"p50_delta_us": int(production_stats.p50) - int(candidate_stats.p50),
			"p95_delta_us": int(production_stats.p95) - int(candidate_stats.p95),
			"p50_candidate_over_production": float(candidate_stats.p50) / float(maxi(1, int(production_stats.p50))),
			"p95_candidate_over_production": float(candidate_stats.p95) / float(maxi(1, int(production_stats.p95))),
		},
	}


func _measure_block(case_name: String, implementation: String, packed: Dictionary, cell_count: int, expected_bytes: PackedByteArray) -> PackedInt64Array:
	var samples := PackedInt64Array()
	for sample_index: int in SAMPLES_PER_BLOCK:
		var started: int = Time.get_ticks_usec()
		var actual: Dictionary = Candidate.composed_current(packed, cell_count) if implementation == "production_composed" else Candidate.strict_decode(packed, cell_count)
		samples.append(Time.get_ticks_usec() - started)
		_check(var_to_bytes(actual) == expected_bytes, "%s %s sample %d returns exact decoded bytes" % [case_name, implementation, sample_index])
	return samples


func _profile_case_complete(result: Dictionary, expected_name: String) -> bool:
	if result.is_empty() or String(result.get("case", "")) != expected_name or int(result.get("packed_lane_bytes", -1)) <= 0:
		return false
	var blocks_value: Variant = result.get("blocks")
	if not blocks_value is Array or blocks_value.size() != EXPECTED_BLOCKS_PER_CASE:
		return false
	for block_value: Variant in blocks_value:
		if not block_value is Dictionary:
			return false
		var block_samples: Variant = block_value.get("samples_us")
		if not block_samples is Array or block_samples.size() != SAMPLES_PER_BLOCK:
			return false
	var implementations: Variant = result.get("implementations")
	if not implementations is Dictionary:
		return false
	for implementation: String in ["production_composed", "candidate"]:
		var row: Variant = implementations.get(implementation)
		if not row is Dictionary:
			return false
		var samples: Variant = row.get("samples_us")
		if not samples is Array or samples.size() != EXPECTED_SAMPLES_PER_IMPLEMENTATION:
			return false
	return true


func _small_valid_packed_fixture() -> Dictionary:
	var detached: Dictionary = _base_detached()
	var casts: Array[PackedInt64Array] = []
	var cast_parts: Array[PackedInt64Array] = []
	for id: int in [11, 19]:
		casts.append(_wide_row(WirePacking.CAST_ROW_SIZE, id))
		cast_parts.append(PackedInt64Array([id]))
	var products: Array[PackedInt64Array] = []
	var product_sources: Array[PackedInt64Array] = []
	var product_states: Array[PackedInt64Array] = []
	for id: int in [31, 47]:
		products.append(_wide_row(WirePacking.PRODUCT_ROW_SIZE, id))
		product_sources.append(PackedInt64Array([id]))
		product_states.append(PackedInt64Array([id]))
	detached.casts = casts
	detached.cast_cells = PackedInt64Array([11, 0, 1, 19, 1, 2])
	detached.products = products
	detached.product_sources = product_sources
	detached.product_cells = PackedInt64Array([31, 2, 3, 47, 3, 4])
	detached.cast_parts = cast_parts
	detached.product_states = product_states
	return WirePacking.pack(detached, 8)


func _maximum_bounded_packed_fixture() -> Dictionary:
	var detached: Dictionary = _base_detached()
	var casts: Array[PackedInt64Array] = []
	var cast_parts: Array[PackedInt64Array] = []
	var cast_cells := PackedInt64Array()
	for index: int in WirePacking.MAX_CASTS:
		var id := 1_001 + index
		casts.append(_wide_row(WirePacking.CAST_ROW_SIZE, id))
		cast_parts.append(PackedInt64Array([id]))
		for cell_index: int in HexChemistryWorld.MATTER_PER_CAST:
			cast_cells.append_array(PackedInt64Array([id, cell_index, 1]))
	var products: Array[PackedInt64Array] = []
	var product_sources: Array[PackedInt64Array] = []
	var product_states: Array[PackedInt64Array] = []
	var product_cells := PackedInt64Array()
	for index: int in WirePacking.MAX_PRODUCTS:
		var id := 2_001 + index
		products.append(_wide_row(WirePacking.PRODUCT_ROW_SIZE, id))
		product_sources.append(PackedInt64Array([id]))
		product_states.append(PackedInt64Array([id]))
		for cell_index: int in WirePacking.MAX_SELECTED_CELLS:
			product_cells.append_array(PackedInt64Array([id, cell_index, 1]))
	detached.casts = casts
	detached.cast_cells = cast_cells
	detached.products = products
	detached.product_sources = product_sources
	detached.product_cells = product_cells
	detached.cast_parts = cast_parts
	detached.product_states = product_states
	return WirePacking.pack(detached, SYNTHETIC_TOPOLOGY_CELLS)


func _base_detached() -> Dictionary:
	return {
		"schema": 3,
		"topology_hash": "t".repeat(64),
		"authority_hash": "a".repeat(64),
		"header": PackedInt64Array([0, 1, 1, 1, 1]),
		"casts": [], "cast_cells": PackedInt64Array(),
		"products": [], "product_sources": [], "product_cells": PackedInt64Array(),
		"cast_parts": [], "product_states": [],
		"pending": PackedInt64Array([1, 2]), "sources": PackedInt64Array([3]),
		"exposure": PackedInt64Array([4]), "flow_carry": PackedInt64Array([5, 6]),
		"metrics": PackedInt64Array([0]),
	}


func _pack_court(court: HexChemistryWorld) -> Dictionary:
	var detached: Dictionary = ChemistrySnapshot._capture_for_outer_roundtrip(court)
	return WirePacking.pack(detached, court.cells.size()) if not detached.is_empty() else {}


func _wide_row(width: int, id: int) -> PackedInt64Array:
	var row := PackedInt64Array()
	row.resize(width)
	row[0] = id
	return row


func _flat_row(width: int, id: int) -> PackedInt32Array:
	var row := PackedInt32Array()
	row.resize(width)
	row[0] = id
	return row


func _counted_sparse_plane(count: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(2 + count * WirePacking.SPARSE_ALLOCATION_BYTES)
	result.encode_u16(0, count)
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
		"tests/performance/profile_hex_wire_decode_candidate.gd",
		"tests/support/hex_wire_decode_candidate.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/net/hex_snapshot_wire_packing.gd",
		"src/net/hex_chemistry_snapshot.gd",
		"src/sim/hex/hex_chemistry_world.gd",
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
		_check(output != null, "wire decode receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-wire-decode-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
