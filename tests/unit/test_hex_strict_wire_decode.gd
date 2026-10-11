extends "res://tests/unit/test_hex_world_snapshot.gd"

# E8 owns only the fusion of the preceding validate_structure + unpack
# contract. Keep both preceding public functions as the independent oracle.
# Corpus adapted from profile_hex_wire_decode_candidate; fixture limits follow
# production constants, and no observer crosses a sealed world's .cells getter.
const WirePacking = preload("res://src/net/hex_snapshot_wire_packing.gd")
const LegacySnapshot = preload("res://tests/support/hex_producer_topology_legacy_oracle.gd")
const SYNTHETIC_TOPOLOGY_CELLS := WirePacking.MAX_TOPOLOGY_CELLS
const EXPECTED_EQUIVALENCE_CASES := 87

var equivalence_cases_completed := 0


func run() -> int:
	var pressure := _maximum_bounded_packed_fixture()
	check(not pressure.is_empty(), "maximum packed-lane fixture fits unchanged production limits")
	_equivalence_cases(pressure)
	equal(equivalence_cases_completed, EXPECTED_EQUIVALENCE_CASES, "all 87 exact structural acceptance and ownership cases run")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "strict wire integration loads production abilities")
	if catalog.last_error.is_empty(): _test_full_envelopes(catalog)
	return finish("hex-strict-wire-decode")


func _composed(packed: Dictionary, cell_count: int) -> Dictionary:
	if not WirePacking.validate_structure(packed, cell_count): return {}
	return WirePacking.unpack(packed, cell_count)


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
	_assert_decode_case(base, WirePacking.MAX_TOPOLOGY_CELLS, true, "maximum topology cell count accepts")
	_assert_decode_case(base, WirePacking.MAX_TOPOLOGY_CELLS + 1, false, "cell count above maximum rejects")

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
	var preceding_schema: Dictionary = base.duplicate(true)
	preceding_schema.schema = 4
	check(not WirePacking.validate_structure(preceding_schema, 8), "preceding chemistry schema4 cannot admit the current mixed cast row")
	check(WirePacking.strict_decode(preceding_schema, 8).is_empty(), "strict decoder refuses the retired schema4 even with current lane shapes")
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
	var current: Dictionary = _composed(packed, cell_count)
	var candidate: Dictionary = WirePacking.strict_decode(packed, cell_count)
	check((not current.is_empty()) == expected_success, label + " current composed result has expected acceptance")
	check(candidate == current and var_to_bytes(candidate) == var_to_bytes(current), label + " candidate preserves exact value and bytes")
	check(var_to_bytes(packed) == source_bytes, label + " both decoders leave packed source unchanged")
	equivalence_cases_completed += 1


func _assert_output_independence(packed: Dictionary, cell_count: int) -> void:
	var packed_bytes: PackedByteArray = var_to_bytes(packed)
	var first: Dictionary = WirePacking.strict_decode(packed, cell_count)
	var second: Dictionary = WirePacking.strict_decode(packed, cell_count)
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
	check(var_to_bytes(first) != untouched_second, "nested output mutation changes only the selected decode")
	check(var_to_bytes(second) == untouched_second, "second decode owns fresh nested rows and metrics")
	check(var_to_bytes(packed) == packed_bytes, "decoded nested output does not alias packed input")
	equivalence_cases_completed += 1


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
		"schema": WirePacking.CHEMISTRY_SCHEMA_VERSION,
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



func _test_full_envelopes(catalog: AbilityCatalog) -> void:
	var source := SimWorld.new()
	check(HexCourtPractice.configure(source, catalog, false), "strict wire fixture uses ordinary paid practice inputs")
	var concrete := HexChemistryWorld.new()
	var selected: Array[Vector2i] = []
	selected.assign(source.hex_court.cell_keys())
	check(concrete.configure_geometry(source.hex_court.origin, selected), "integration owns concrete sealed geometry")
	concrete.chemistry_enabled = true
	source.hex_court = concrete
	var topology := concrete.immutable_topology()
	check(topology != null, "integration starts sealed")
	var empty := Snapshot.capture(source)
	check(not empty.is_empty(), "empty sealed source captures")
	if empty.is_empty(): return
	_assert_decode_case(Snapshot._decompress_hex(empty.hex), concrete.cell_count(), true, "actual empty world strict decode")
	var valid := _advance_to_rich_capture(source)
	check(not valid.is_empty(), "ordinary paid commands reach flight, product and pending authority")
	if valid.is_empty(): return
	check(concrete.immutable_topology() == topology, "paid simulation and capture do not materialize source")
	var packed := Snapshot._decompress_hex(valid.hex, concrete.cell_count())
	_assert_decode_case(packed, concrete.cell_count(), true, "actual paid world strict decode")
	var target := Snapshot.prepare(valid, source)
	check(target != null, "strict incoming route accepts complete paid snapshot")
	if target == null: return
	check(target.state_hash() == source.state_hash(), "complete strict preparation preserves exact world hash")
	check(target.hex_court.immutable_topology() == topology, "strict preparation retains sealed shared geometry")
	check(var_to_bytes(Snapshot.capture(target)) == var_to_bytes(valid), "prepared complete wire bytes reproduce producer exactly")
	var legacy := Snapshot.prepare(valid, source)
	check(legacy != null, "independent legacy oracle arm prepares")
	if legacy == null: return
	var legacy_cells: Dictionary = legacy.hex_court.cells # Deliberate oracle-arm escape only.
	check(legacy_cells.size() == concrete.cell_count(), "oracle materializes all cells only on its own arm")
	check(var_to_bytes(LegacySnapshot.capture(legacy)) == var_to_bytes(valid), "frozen preceding full capture matches strict producer bytes")
	var before := _witness(target)
	var wrong_types := {
		"schema": "3", "topology_hash": 3, "authority_hash": 4,
		"header": [], "cast_ids": [], "casts": [], "cast_allocations": PackedInt32Array(),
		"product_ids": [], "products": [], "product_sources": [], "product_allocations": PackedInt32Array(),
		"cast_parts": [], "product_states": [], "pending": [], "sources": [], "exposure": [], "flow_carry": [],
		"metrics": PackedInt32Array(),
	}
	for key: String in WirePacking.KEYS:
		var malformed: Dictionary = packed.duplicate(true)
		malformed[key] = wrong_types[key]
		_assert_packed_rejected(malformed, valid, target, before, "compressed wrong type: " + key)
	for kind: String in ["missing-key", "extra-key", "schema", "header-width", "flag", "row-width", "sparse-truncated", "variable-trailing"]:
		var malformed: Dictionary = packed.duplicate(true)
		match kind:
			"missing-key": malformed.erase("metrics")
			"extra-key": malformed.extra = 1
			"schema": malformed.schema = 2
			"header-width":
				var values: PackedInt32Array = malformed.header
				values.resize(4)
				malformed.header = values
			"flag":
				var values: PackedInt32Array = malformed.header
				values[1] = 2
				malformed.header = values
			"row-width":
				var values: PackedInt32Array = malformed.casts
				values.append(0)
				malformed.casts = values
			"sparse-truncated":
				var values: PackedByteArray = malformed.cast_allocations
				values.resize(values.size() - 1)
				malformed.cast_allocations = values
			"variable-trailing":
				var values: PackedInt32Array = malformed.cast_parts
				values.append(0)
				malformed.cast_parts = values
		_assert_packed_rejected(malformed, valid, target, before, "compressed malformed " + kind)
	# These still pass packed framing; chemistry/topology semantics must reject.
	for kind: String in ["topology_hash", "authority_hash", "metrics"]:
		var malformed: Dictionary = packed.duplicate(true)
		if kind == "metrics":
			var values: PackedInt64Array = malformed.metrics
			values[0] = -1
			malformed.metrics = values
		else: malformed[kind] = "0".repeat(64)
		_assert_packed_rejected(malformed, valid, target, before, "semantic " + kind, true)
		var legacy_before := _witness(legacy)
		_assert_packed_rejected(malformed, valid, legacy, legacy_before, "legacy semantic " + kind, true)
	var envelope_cases: Dictionary = {}
	var envelope: Dictionary = valid.hex.duplicate(true)
	envelope["size"] = int(envelope["size"]) + 1
	envelope_cases["false exact uncompressed size"] = envelope
	envelope = valid.hex.duplicate(true)
	envelope.schema = Snapshot.SCHEMA_VERSION + 1
	envelope_cases["wrong envelope schema"] = envelope
	envelope = valid.hex.duplicate(true)
	envelope["size"] = Snapshot.MAX_HEX_UNCOMPRESSED_BYTES + 1
	envelope_cases["advertised uncompressed limit"] = envelope
	envelope = valid.hex.duplicate(true)
	envelope.bytes = PackedByteArray()
	envelope_cases["empty compressed bytes"] = envelope
	envelope = valid.hex.duplicate(true)
	envelope.bytes = PackedInt32Array([1])
	envelope_cases["wrong compressed lane type"] = envelope
	envelope = valid.hex.duplicate(true)
	envelope.extra = 1
	envelope_cases["extra envelope key"] = envelope
	envelope_cases["compressed non-Dictionary"] = _raw_envelope(PackedInt32Array([1, 2, 3]))
	envelope_cases["compressed empty Dictionary"] = _raw_envelope({})
	# A real oversized, compressible payload proves the advertised bound is
	# unchanged without intentionally causing a native decompressor error log.
	var oversized := PackedByteArray()
	oversized.resize(Snapshot.MAX_HEX_UNCOMPRESSED_BYTES + 1)
	envelope_cases["actual oversized payload"] = _raw_envelope(oversized)
	for label: String in envelope_cases:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.hex = envelope_cases[label]
		check(Snapshot._decompress_hex(malformed.hex).is_empty(), label + " strict envelope helper refuses")
		_assert_outer_rejected(malformed, target, before, label, false)
	var wrong_world_hash: Dictionary = valid.duplicate(true)
	wrong_world_hash.state_hash = "0".repeat(64)
	_assert_outer_rejected(wrong_world_hash, target, before, "forged outer authority hash", true)
	check(concrete.immutable_topology() == topology, "all full-path observers preserve sealed producer")
	check(Snapshot.restore(valid, target), "valid complete snapshot still restores after every refusal")
	check(target.state_hash() == source.state_hash(), "valid recovery restores exact source authority")
	var command := SimCommand.new(source.tick, 1, 0, 0, 0, 0, 0, -1000, 640_000, 480_000)
	check(source.step([command]) and target.step([command]) and legacy.step([command]), "sealed and legacy restorations accept identical continuation")
	check(source.state_hash() == target.state_hash() and source.state_hash() == legacy.state_hash(), "next-tick authority remains exact across fused, original and legacy arms")


func _raw_envelope(value: Variant) -> Dictionary:
	# Do not call _compress_hex: that would reject malformed packed lanes before
	# the incoming path under test ever sees them.
	var raw := var_to_bytes(value)
	return {"schema": Snapshot.SCHEMA_VERSION, "size": raw.size(), "bytes": raw.compress(FileAccess.COMPRESSION_DEFLATE)}


func _witness(world: SimWorld) -> Dictionary:
	return {"hash": world.state_hash(), "wire": var_to_bytes(Snapshot.capture(world)),
		"court": world.hex_court, "collision": world.collision, "players": world.players,
		"projectiles": world.projectiles, "topology": world.hex_court.immutable_topology()}


func _assert_packed_rejected(packed: Dictionary, valid: Dictionary, target: SimWorld, before: Dictionary, label: String, wire_valid: bool = false) -> void:
	var snapshot := valid.duplicate(true)
	snapshot.hex = _raw_envelope(packed)
	check(not snapshot.hex.bytes.is_empty(), label + " actually reaches compressed transport")
	check((not Snapshot._decompress_hex(snapshot.hex).is_empty()) == wire_valid, label + " strict envelope helper keeps preceding structural acceptance")
	_assert_outer_rejected(snapshot, target, before, label, wire_valid)


func _assert_outer_rejected(snapshot: Dictionary, target: SimWorld, before: Dictionary, label: String, wire_valid: bool) -> void:
	var input_bytes := var_to_bytes(snapshot)
	check(Snapshot.validate_wire_structure(snapshot) == wire_valid, label + " transport structure result remains exact")
	check(Snapshot.prepare(snapshot, target) == null, label + " complete preparation refuses")
	check(not Snapshot.restore(snapshot, target), label + " restoration refuses")
	check(target.state_hash() == before.hash and var_to_bytes(Snapshot.capture(target)) == before.wire, label + " target authority and wire remain exact")
	check(target.hex_court == before.court and target.collision == before.collision
		and is_same(target.players, before.players) and is_same(target.projectiles, before.projectiles), label + " no target-owned objects publish on failure")
	check(target.hex_court.immutable_topology() == before.topology, label + " topology ownership remains unchanged")
	check(var_to_bytes(snapshot) == input_bytes, label + " incoming payload remains unchanged")
