extends "res://tests/unit/test_hex_chemistry_snapshot.gd"
@warning_ignore_start("integer_division")

const Before = preload("res://tests/support/expanded_chemistry_snapshot_reference.gd")
const DYNAMIC_FIELDS: Array[String] = ["casts", "products", "pending", "sources", "exposure", "flow_carry", "metrics"]
const SCALAR_FIELDS: Array[String] = ["current_tick", "chemistry_enabled", "next_cast_id", "next_product_id", "next_ground_part_id"]

class CountingWorld:
	extends HexChemistryWorld
	var layer_writes := 0
	func set_cell_amount(cell: Vector2i, layer: String, source: int, amount: int) -> void:
		layer_writes += 1
		super.set_cell_amount(cell, layer, source, amount)

class ChangingHashWorld:
	extends HexChemistryWorld
	var hash_calls := 0
	func state_hash() -> String:
		hash_calls += 1
		return super.state_hash() if hash_calls == 1 else "0".repeat(64)

class SpoofedWorld:
	extends HexChemistryWorld
	var alleged: HexCellTopology
	func immutable_topology() -> HexCellTopology:
		return alleged
	func dynamic_cell_keys() -> Array:
		return []


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "strict chemistry prepare fixtures load unchanged abilities")
	if not catalog.last_error.is_empty(): return finish("hex-chemistry-prepare")
	_test_cell_order()
	var rich := _rich_world(catalog)
	var sealed := _sealed_copy(rich)
	_assert_equivalent(rich, "legacy subclass paid authority")
	_assert_equivalent(sealed, "sealed paid authority")
	var zero := _zero_world(catalog)
	_assert_equivalent(zero, "explicit zero-allocation coverage")
	var product_zero := _product_zero_copy(sealed)
	_assert_equivalent(product_zero, "synthetic conserved zero product coverage")
	_test_write_count(sealed, "positive ingredients and products")
	_test_write_count(zero, "positive and zero ground coverage")
	_test_write_count(product_zero, "positive and zero product coverage")
	_test_mutations(sealed)
	_test_boundary_ownership(sealed)
	_test_subclass_fallback()
	return finish("hex-chemistry-prepare")


func _geometry_like(source: HexChemistryWorld, target: HexChemistryWorld) -> void:
	var cells: Array[Vector2i] = []
	cells.assign(source.cell_keys())
	check(target.configure_geometry(source.origin, cells), "comparison world configures exact local geometry")


func _sealed_copy(source: HexChemistryWorld) -> HexChemistryWorld:
	var target := HexChemistryWorld.new()
	_geometry_like(source, target)
	for key: String in DYNAMIC_FIELDS: target.set(key, (source.get(key) as Dictionary).duplicate(true))
	for key: String in SCALAR_FIELDS: target.set(key, source.get(key))
	var layers: Array[String] = HexChemistryWorld.material_layers()
	for cell: Vector2i in source.dynamic_cell_keys():
		var row: Dictionary = source.cell_record(cell)
		for layer: String in layers:
			for id: int in row.get(layer, {}): target.set_cell_amount(cell, layer, id, int(row[layer][id]))
	check(target.immutable_topology() != null and target.conservation_valid(), "comparison copy stays sealed and conserved")
	return target


func _assert_equivalent(source: HexChemistryWorld, label: String) -> void:
	var before := source._state_hash_bytes()
	var topology := source.immutable_topology()
	var expected := Before.capture(source)
	var actual := SnapshotCodec.capture(source)
	check(not actual.is_empty() and not expected.is_empty(), label + " both complete captures accept")
	if actual.is_empty() or expected.is_empty(): return
	equal(actual, expected, label + " exact snapshot fields")
	check(var_to_bytes(actual) == var_to_bytes(expected), label + " exact typed wire bytes")
	equal(SnapshotCodec.encoded_size(actual), Before.encoded_size(expected), label + " exact encoded size")
	equal(SnapshotCodec.snapshot_hash(actual), Before.snapshot_hash(expected), label + " exact snapshot digest")
	var candidate := SnapshotCodec._prepare(actual, source)
	var reference := Before._prepare(expected, source)
	check(candidate != null and reference != null, label + " complete strict preparations accept")
	if candidate == null or reference == null: return
	check(candidate._state_hash_bytes() == before and reference._state_hash_bytes() == before, label + " exact full canonical authority bytes")
	check(candidate.conservation_valid() and reference.conservation_valid(), label + " all layers and finite ledgers conserve")
	check(source._state_hash_bytes() == before and source.immutable_topology() == topology, label + " source ownership stays unchanged")
	var restored := HexChemistryWorld.new()
	_geometry_like(source, restored)
	check(SnapshotCodec.restore(expected, restored), label + " public restore accepts schema-adapted predecessor wire")
	check(restored._state_hash_bytes() == before, label + " public restore publishes exact authority")
	for tick: int in [100, 500, 1000]:
		candidate.sync_flights([], [])
		reference.sync_flights([], [])
		candidate.expire_at(tick)
		reference.expire_at(tick)
		check(candidate._state_hash_bytes() == reference._state_hash_bytes(), label + " exact continued retirement at tick %d" % tick)


func _zero_world(catalog: AbilityCatalog) -> HexChemistryWorld:
	var source := HexChemistryWorld.new()
	check(source.configure_geometry(Vector2i(640_000, 480_000), HexGrid.disk(Vector2i.ZERO, 3)), "zero fixture configures sealed geometry")
	source.chemistry_enabled = true
	check(source.reserve_cast(1, _wire(catalog, "water", "bolt")), "zero fixture reserves a real paid cast")
	source.commit_payment(1)
	source.bind_release(1, 71_001, source.origin, Vector2i(1000, 0), 1)
	var record: Dictionary = source.casts[int(source.sources[71_001])]
	var selected: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)]
	var shape := HexFootprint.disk(source.origin + HexGrid.center(selected[1]), 64_000)
	var expiry := 4 + HexChemistryWorld.trail_lifetime(int(record.element))
	equal(HexCastParts.deposit_flight(record, 71_001, source.next_ground_part_id, selected, shape, 4, expiry, true, 1), 1, "one paid unit covers three cells including two zero amounts")
	source.next_ground_part_id += 1
	record.footprint = shape
	record.expires = expiry
	source._sync_cast_ledger(record)
	source._rebuild_cast_layers(record)
	check(source.conservation_valid(), "zero fixture preserves paid conservation")
	return source


func _test_write_count(source: HexChemistryWorld, label: String) -> void:
	var snapshot := Before.capture(source)
	check(not snapshot.is_empty(), label + " write-count fixture captures")
	if snapshot.is_empty(): return
	var candidate := CountingWorld.new()
	var reference := CountingWorld.new()
	_geometry_like(source, candidate)
	_geometry_like(source, reference)
	var ordered: Array[Vector2i] = SnapshotCodec._trusted_cells(source)
	check(SnapshotCodec._decode_prepared_state(snapshot, candidate, ordered) == candidate, label + " candidate complete dynamic decoder accepts")
	check(Before._decode_prepared_state(snapshot, reference, ordered) == reference, label + " schema-adapted predecessor complete dynamic decoder accepts")
	var final_writes := 0
	for record: Dictionary in source.casts.values(): final_writes += record.cells.size()
	for product: Dictionary in source.products.values(): final_writes += product.cells.size()
	var duplicate_writes: int = (snapshot.cast_cells.size() + snapshot.product_cells.size()) / 3
	equal(candidate.layer_writes, final_writes, label + " writes every final cell ownership exactly once")
	equal(reference.layer_writes, final_writes + duplicate_writes, label + " frozen implementation independently demonstrates duplicate positive writes")
	check(candidate._state_hash_bytes() == reference._state_hash_bytes(), label + " fewer writes leave exact canonical bytes")
	# Helper defaults still materialize positive layers for their direct callers.
	var standalone := CountingWorld.new()
	_geometry_like(source, standalone)
	# Schema4 product ancestry validates against the enclosing snapshot tick.
	# Direct helper callers must provide that same already-validated header context.
	standalone.current_tick = source.current_tick
	check(SnapshotCodec._decode_casts(snapshot.casts, standalone), label + " standalone cast decoder accepts")
	check(SnapshotCodec._decode_cast_cells(snapshot.cast_cells, standalone, ordered), label + " standalone cast-cell default accepts")
	check(SnapshotCodec._decode_products(snapshot.products, snapshot.product_sources, standalone), label + " standalone product decoder accepts")
	check(SnapshotCodec._decode_product_cells(snapshot.product_cells, standalone, ordered), label + " standalone product-cell default accepts")
	equal(standalone.layer_writes, duplicate_writes, label + " standalone helper defaults preserve immediate layer writes")


func _product_zero_copy(source: HexChemistryWorld) -> HexChemistryWorld:
	var result := _sealed_copy(source)
	var product_id: int = result.products.keys()[0]
	var product: Dictionary = result.products[product_id]
	var cells: Array = product.cells.keys()
	check(cells.size() >= 2, "synthetic zero product fixture has two selected cells")
	if cells.size() < 2: return result
	var donor: Vector2i = cells[0]
	var receiver: Vector2i = cells[1]
	var amount: int = product.cells[donor]
	# Synthetic coverage edge case, not a claim that this retile is produced by
	# ordinary input. It preserves exact product quantity and paid source ledgers.
	product.cells[donor] = 0
	product.cells[receiver] = int(product.cells[receiver]) + amount
	result.set_cell_amount(donor, product.material, product_id, 0)
	result.set_cell_amount(receiver, product.material, product_id, int(product.cells[receiver]))
	check(result.conservation_valid(), "synthetic zero product coverage remains exactly conserved")
	return result


func _test_cell_order() -> void:
	var cells: Array = [Vector2i(10, -2), Vector2i(-10, 2), Vector2i(2, 10), Vector2i(2, -10), Vector2i.ZERO, Vector2i(-1, 0)]
	for unused: int in cells.size():
		equal(SnapshotCodec._sorted_cells(cells), Before._sorted_cells(cells), "native cell sort matches frozen callback numeric order")
		cells.push_back(cells.pop_front())
	cells.append("(0, 0)")
	equal(SnapshotCodec._sorted_cells(cells), Before._sorted_cells(cells), "mixed type cell input keeps rejection")


func _test_mutations(source: HexChemistryWorld) -> void:
	var snapshot := Before.capture(source)
	check(not snapshot.is_empty(), "rejection corpus begins with valid frozen snapshot")
	if snapshot.is_empty(): return
	var wrong_types := {
		"schema": "3", "topology_hash": 3, "authority_hash": 3, "header": [], "casts": {},
		"cast_cells": [], "products": {}, "product_sources": {}, "product_cells": [], "cast_parts": {},
		"product_states": {}, "pending": [], "sources": [], "exposure": [], "flow_carry": [], "metrics": [],
	}
	for key: String in SnapshotCodec.SNAPSHOT_KEYS:
		var wrong: Dictionary = snapshot.duplicate(true)
		wrong[key] = wrong_types[key]
		_assert_rejected(wrong, source, key + " wrong type")
	var missing: Dictionary = snapshot.duplicate(true)
	missing.erase("metrics")
	_assert_rejected(missing, source, "missing lane")
	var extra: Dictionary = snapshot.duplicate(true)
	extra.extra = 1
	_assert_rejected(extra, source, "extra lane")
	for lane: String in ["cast_cells", "product_cells"]:
		for kind: String in ["duplicate", "decreasing", "negative", "out-of-range", "zero", "negative-amount", "orphan", "truncated", "empty"]:
			var wrong: Dictionary = snapshot.duplicate(true)
			var values: PackedInt64Array = wrong[lane]
			check(values.size() >= 6, lane + " corpus has two positive rows")
			if values.size() < 6: continue
			if kind == "duplicate":
				for index: int in 3: values[index + 3] = values[index]
			elif kind == "decreasing":
				for index: int in 3:
					var saved: int = values[index]
					values[index] = values[index + 3]
					values[index + 3] = saved
			elif kind == "negative": values[1] = -1
			elif kind == "out-of-range": values[1] = source.cell_count()
			elif kind == "zero": values[2] = 0
			elif kind == "negative-amount": values[2] = -1
			elif kind == "orphan": values[0] = SnapshotCodec.MAX_ID
			elif kind == "truncated": values.resize(values.size() - 1)
			else: values.clear()
			wrong[lane] = values
			_assert_rejected(wrong, source, lane + " " + kind)
	for lane: String in ["casts", "products", "cast_parts", "product_states", "product_sources"]:
		var wrong: Dictionary = snapshot.duplicate(true)
		wrong[lane].insert(1, wrong[lane][0].duplicate())
		_assert_rejected(wrong, source, lane + " duplicate row")
		wrong = snapshot.duplicate(true)
		wrong[lane][0] = PackedInt64Array([1])
		_assert_rejected(wrong, source, lane + " truncated row")
	for key: String in ["authority_hash", "topology_hash"]:
		var wrong: Dictionary = snapshot.duplicate(true)
		wrong[key] = "0".repeat(64)
		_assert_rejected(wrong, source, key + " mismatch")
	var conservation: Dictionary = snapshot.duplicate(true)
	var metrics: PackedInt64Array = conservation.metrics
	metrics[6] += HexChemistryWorld.MATTER_PER_CAST
	conservation.metrics = metrics
	_assert_rejected(conservation, source, "paid conservation")
	for lane: String in ["sources", "pending"]:
		var wrong: Dictionary = snapshot.duplicate(true)
		var pairs: PackedInt64Array = wrong[lane]
		pairs[1] = SnapshotCodec.MAX_ID
		wrong[lane] = pairs
		_assert_rejected(wrong, source, lane + " orphan relationship")
	var oversized: Dictionary = snapshot.duplicate(true)
	oversized.authority_hash = "a".repeat(SnapshotCodec.MAX_ENCODED_BYTES)
	check(SnapshotCodec.encoded_size(oversized) > SnapshotCodec.MAX_ENCODED_BYTES, "oversized corpus exceeds unchanged exact JSON limit")
	_assert_rejected(oversized, source, "encoded size above one MiB")
	# Reusing the same caller-owned object must not establish reusable trust.
	check(SnapshotCodec.validate(snapshot, source), "mutable wire starts accepted")
	var original_header: PackedInt64Array = snapshot.header.duplicate()
	var header: PackedInt64Array = snapshot.header
	header[1] = 2
	snapshot.header = header
	_assert_rejected(snapshot, source, "same object direct mutation")
	snapshot.header = original_header
	check(SnapshotCodec.validate(snapshot, source) and Before.validate(snapshot, source), "same object repaired values are freshly revalidated")


func _assert_rejected(snapshot: Dictionary, source: HexChemistryWorld, label: String) -> void:
	var target := _sealed_copy(source)
	var before := target._state_hash_bytes()
	var topology := target.immutable_topology()
	var revision := target.value_revision
	var wire_before := var_to_bytes(snapshot)
	check(Before._prepare(snapshot, target) == null, label + " frozen strict decoder rejects")
	check(SnapshotCodec._prepare(snapshot, target) == null, label + " candidate strict decoder rejects")
	check(not SnapshotCodec.restore(snapshot, target), label + " public restore rejects")
	check(target._state_hash_bytes() == before, label + " rejection preserves exact live authority")
	check(target.immutable_topology() == topology and target.value_revision == revision, label + " rejection preserves topology and publication revision")
	check(var_to_bytes(snapshot) == wire_before, label + " caller wire remains untouched")


func _test_boundary_ownership(source: HexChemistryWorld) -> void:
	var snapshot := Before.capture(source)
	var first := SnapshotCodec._prepare(snapshot, source)
	var second := SnapshotCodec._prepare(snapshot, source)
	check(first != null and second != null, "two independent preparations accept")
	if first == null or second == null: return
	var before := source._state_hash_bytes()
	var cast_id: int = first.casts.keys()[0]
	first.casts[cast_id].owner = 9000
	first.metrics.refused += 1
	check(second._state_hash_bytes() == before and source._state_hash_bytes() == before, "prepared dynamic maps do not alias source or sibling")
	var mutable := _sealed_copy(source)
	var cell: Vector2i = mutable.cell_keys()[0]
	var exposed: Dictionary = mutable.cells
	exposed[cell].terrain = 1
	check(SnapshotCodec._prepare(snapshot, mutable) == null and Before._prepare(snapshot, mutable) == null, "direct local metadata mutation invalidates old topology")
	exposed[cell].terrain = 0
	exposed[cell].water = 7
	check(SnapshotCodec._prepare(snapshot, mutable) == null and Before._prepare(snapshot, mutable) == null, "direct malformed local layer remains visible to both fallbacks")


func _test_subclass_fallback() -> void:
	var source := HexChemistryWorld.new()
	check(source.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "subclass fixture admits concrete topology")
	var snapshot := Before.capture(source)
	var spoof := SpoofedWorld.new()
	spoof.origin = source.origin
	spoof.cells = source.immutable_topology().metadata().duplicate(true)
	spoof.alleged = source.immutable_topology()
	spoof.cells[Vector2i.ZERO].terrain = 0.5
	check(SnapshotCodec.capture(spoof).is_empty() and Before.capture(spoof).is_empty(), "subclass cannot spoof immutable admission to hide bad metadata")
	check(SnapshotCodec._prepare(snapshot, spoof) == null and Before._prepare(snapshot, spoof) == null, "subclass incoming fallback rejects forged local metadata")
	for codec: GDScript in [Before, SnapshotCodec]:
		var changing := ChangingHashWorld.new()
		_geometry_like(source, changing)
		check(codec.capture(changing).is_empty(), "public capture still rejects source whose virtual authority changes after prepare")
		equal(changing.hash_calls, 2, "public capture retains fresh source hash check after complete preparation")
