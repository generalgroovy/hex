extends "res://tests/unit/test_hex_world_snapshot.gd"

const Legacy = preload("res://tests/support/hex_producer_topology_legacy_oracle.gd")
const OriginalBytes = preload("res://tests/support/hex_stable_cells_candidate.gd")
const DYNAMIC_FIELDS: Array[String] = ["casts", "products", "pending", "sources", "exposure", "flow_carry", "metrics"]
const SCALAR_FIELDS: Array[String] = ["current_tick", "chemistry_enabled", "next_cast_id", "next_product_id", "next_ground_part_id"]

class SpoofedWorld:
	extends HexChemistryWorld
	var alleged: HexCellTopology
	func immutable_topology() -> HexCellTopology:
		return alleged
	func cell_count() -> int:
		return alleged.numeric_cells().size()
	func dynamic_cell_keys() -> Array:
		return []


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "sealed snapshot uses unchanged production abilities")
	if not catalog.last_error.is_empty(): return finish("hex-sealed-snapshot")
	_test_small_geometry_and_oracle()
	_test_compatibility_detachment()
	_test_subclass_cannot_assert_trust()
	_test_zero_coverage(catalog)
	_test_paid_outer_roundtrip(catalog)
	return finish("hex-sealed-snapshot")


func _small_world() -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	# Deliberately mix positive/negative and multi-digit coordinates: numeric
	# wire order differs from the formatted-vector legacy canonical hash order.
	var selected: Array[Vector2i] = [Vector2i(10, 0), Vector2i(-2, 1), Vector2i.ZERO, Vector2i(2, 0), Vector2i(-10, 0)]
	check(world.configure_geometry(Vector2i(640_000, 480_000), selected), "small fixture admits concrete immutable geometry")
	world.chemistry_enabled = true
	return world


func _legacy_copy(source: HexChemistryWorld) -> HexChemistryWorld:
	var result := HexChemistryWorld.new()
	source.clone_cell_storage_to(result)
	# Only the independent oracle arm crosses compatibility; source must retain
	# its sealed handle throughout the comparison.
	var materialized: Dictionary = result.cells
	check(not materialized.is_empty(), "oracle arm explicitly materializes legacy mutable cells")
	for field: String in DYNAMIC_FIELDS: result.set(field, (source.get(field) as Dictionary).duplicate(true))
	for field: String in SCALAR_FIELDS: result.set(field, source.get(field))
	return result


func _assert_chemistry_oracle(source: HexChemistryWorld, label: String) -> void:
	var topology := source.immutable_topology()
	check(topology != null, label + " begins sealed")
	var legacy := _legacy_copy(source)
	equal(source._state_hash_bytes(), OriginalBytes.frozen_original_bytes(legacy), label + " exact original full-cell canonical bytes")
	var expected := Legacy.chemistry_capture(legacy)
	var actual := ChemistrySnapshot.capture(source)
	check(not actual.is_empty(), label + " complete strict chemistry capture accepts")
	equal(actual, expected, label + " exact frozen chemistry snapshot")
	equal(var_to_bytes(actual), var_to_bytes(expected), label + " exact serialized snapshot bytes")
	check(source.immutable_topology() == topology, label + " oracle/capture never materialize source")


func _test_small_geometry_and_oracle() -> void:
	var source := _small_world()
	var topology := source.immutable_topology()
	check(topology != null, "concrete configure owns an admitted handle")
	if topology == null: return
	check(topology.numeric_cells().is_read_only() and topology.cell_indices().is_read_only() and topology.metadata().is_read_only(), "borrowed topology collections are read-only")
	for record: Dictionary in topology.metadata().values(): check(record.is_read_only(), "every shared static row is read-only")
	var original_bytes := topology.topology_bytes()
	var exposed := topology.topology_bytes()
	exposed[0] = int(exposed[0]) ^ 1
	equal(topology.topology_bytes(), original_bytes, "packed topology bytes are detached, never a mutable geometry alias")
	_assert_chemistry_oracle(source, "empty sealed topology")
	var snapshot := ChemistrySnapshot.capture(source)
	var first := ChemistrySnapshot._prepare(snapshot, source)
	var second := ChemistrySnapshot._prepare(snapshot, source)
	check(first != null and second != null, "strict incoming chemistry preparation succeeds twice")
	if first == null or second == null: return
	check(first.immutable_topology() == topology and second.immutable_topology() == topology, "incoming preparation shares only admitted static geometry")
	check(first.dynamic_cell_keys().is_empty() and second.dynamic_cell_keys().is_empty(), "blank preparation allocates no mutable blank-cell rows")
	var cell: Vector2i = topology.numeric_cells()[0]
	first.set_cell_amount(cell, "water", 900_001, 0)
	check(first.cell_record(cell).water.has(900_001), "zero quantity remains explicit owner coverage")
	check(not second.cell_record(cell).has("water") and not source.cell_record(cell).has("water"), "prepared sparse layers do not alias source or sibling")
	check(ChemistrySnapshot.capture(first).is_empty(), "orphan zero-quantity reverse layer cannot disappear in sparse capture")
	first.erase_cell_amount(cell, "water", 900_001)
	check(first.dynamic_cell_keys().is_empty(), "erasing final owner removes sparse row without removing topology")
	equal(first.cell_count(), source.cell_count(), "sparse removal preserves complete topology count")
	check(ChemistrySnapshot.restore(snapshot, first), "chemistry restore accepts after local sparse mutation")
	check(first.immutable_topology() == topology, "chemistry restore preserves sealed storage without compatibility access")
	var reversed := topology.numeric_cells().duplicate()
	reversed.reverse()
	var legacy := _legacy_copy(source)
	equal(ChemistrySnapshot._topology_bytes(source, reversed), Legacy.topology_bytes(legacy, reversed), "noncanonical explicit topology order keeps legacy helper semantics")
	check(source.immutable_topology() == topology, "diagnostic byte helper does not detach sealed source")


func _test_compatibility_detachment() -> void:
	for mutation: String in ["metadata", "known-layer-type", "same-count-key", "origin"]:
		var source := _small_world()
		var snapshot := ChemistrySnapshot.capture(source)
		var sibling := ChemistrySnapshot._prepare(snapshot, source)
		check(sibling != null, mutation + " independent sibling prepares")
		if sibling == null: continue
		var sibling_hash := sibling.state_hash()
		var before := source.immutable_topology()
		var operation := ChemistrySnapshot.ProducerRoundtrip.new(source)
		var cell: Vector2i = source.cell_keys()[0]
		if mutation == "origin":
			source.origin += Vector2i(1, 0)
		else:
			var cells: Dictionary = source.cells
			if mutation == "metadata": cells[cell].terrain = 2_147_483_649
			elif mutation == "known-layer-type": cells[cell].water = 7
			else:
				var row: Dictionary = cells[cell]
				cells.erase(cell)
				cells[Vector2i(11, 0)] = row
		check(source.immutable_topology() == null, mutation + " permanently detaches writable compatibility state")
		check(operation.consume(operation.snapshot(), source) == null, mutation + " invalidates a previously captured producer operation")
		check(ChemistrySnapshot._prepare(snapshot, source) == null, mutation + " strict incoming refuses stale topology or malformed layer")
		check(sibling.immutable_topology() == before, mutation + " cannot replace sibling topology")
		equal(sibling.state_hash(), sibling_hash, mutation + " cannot mutate sibling state")
		var expected := Legacy.chemistry_capture(source)
		var actual := ChemistrySnapshot.capture(source)
		if mutation == "known-layer-type":
			check(expected.is_empty() and actual.is_empty(), "malformed known layer refuses in both producers")
		else:
			check(not actual.is_empty(), mutation + " remains valid legacy mutable state")
			equal(actual, expected, mutation + " new mutable topology remains byte-compatible")
			equal(source._state_hash_bytes(), OriginalBytes.frozen_original_bytes(source), mutation + " signed metadata/origin/key keeps original canonical bytes")


func _test_subclass_cannot_assert_trust() -> void:
	var source := _small_world()
	var spoof := SpoofedWorld.new()
	spoof.origin = source.origin
	spoof.cells = source.immutable_topology().metadata().duplicate(true)
	spoof.alleged = source.immutable_topology()
	var cell: Vector2i = spoof.cells.keys()[0]
	spoof.cells[cell].terrain = 0.5
	check(ChemistrySnapshot._owned_immutable_topology(spoof) == null, "subclass cannot assert trust with a borrowed concrete handle")
	check(ChemistrySnapshot._trusted_cells(spoof).is_empty(), "subclass accessor overrides cannot hide malformed mutable metadata")
	check(ChemistrySnapshot.capture(spoof).is_empty(), "subclass fallback retains strict producer refusal")
	var snapshot := ChemistrySnapshot.capture(source)
	check(ChemistrySnapshot._prepare(snapshot, spoof) == null, "subclass fallback retains strict incoming refusal")


func _test_zero_coverage(catalog: AbilityCatalog) -> void:
	var source := HexChemistryWorld.new()
	check(source.configure_geometry(Vector2i(640_000, 480_000), HexGrid.disk(Vector2i.ZERO, 3)), "zero coverage configures concrete topology")
	source.chemistry_enabled = true
	var wire := int(catalog.ability(catalog.spell_id_at("water", "bolt")).get("wire_id", 0))
	check(source.reserve_cast(1, wire), "zero coverage reserves real paid Water source")
	source.commit_payment(1)
	source.bind_release(1, 71_001, source.origin, Vector2i(1000, 0), 1)
	var record: Dictionary = source.casts[int(source.sources[71_001])]
	var selected: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)]
	var shape := HexFootprint.disk(source.origin + HexGrid.center(selected[1]), 64_000)
	var part_id := source.next_ground_part_id
	var expiry := 4 + HexChemistryWorld.trail_lifetime(int(record.element))
	equal(HexCastParts.deposit_flight(record, 71_001, part_id, selected, shape, 4, expiry, true, 1), 1, "one paid unit tiles across three members")
	source.next_ground_part_id += 1
	record.footprint = shape
	record.expires = expiry
	source._sync_cast_ledger(record)
	source._rebuild_cast_layers(record)
	_assert_chemistry_oracle(source, "paid zero-allocation coverage")
	var prepared := ChemistrySnapshot._prepare(ChemistrySnapshot.capture(source), source)
	check(prepared != null, "zero-coverage sealed snapshot prepares")
	if prepared == null: return
	var restored: Dictionary = prepared.casts[int(prepared.sources[71_001])].ground_parts[part_id]
	equal(restored.cells.values().count(0), 2, "two zero allocations survive complete dynamic decode")
	equal(prepared.dynamic_cell_keys().size(), 3, "all selected owners remain in sparse storage including zeros")
	check(prepared.conservation_valid(), "zero coverage retains exact paid conservation")
	var clone := HexChemistryWorld.new()
	prepared.clone_cell_storage_to(clone)
	var cell: Vector2i = selected[0]
	var layer := HexRecipePolicy.ingredient_layer(int(record.element))
	var id: int = int(prepared.sources[71_001])
	var amount: int = prepared.cell_record(cell)[layer][id]
	clone.cell_record(cell)[layer][id] = amount + 1
	equal(prepared.cell_record(cell)[layer][id], amount, "cloned sparse layer dictionaries remain independently mutable")
	prepared.cell_record(cell)[layer][id] = amount + 1
	check(ChemistrySnapshot.capture(prepared).is_empty(), "post-admission mutable layer corruption remains visible to exact-hash refusal")


func _test_paid_outer_roundtrip(catalog: AbilityCatalog) -> void:
	var source := SimWorld.new()
	check(HexCourtPractice.configure(source, catalog, false), "paid outer fixture configures normal inputs")
	var concrete := HexChemistryWorld.new()
	var cells: Array[Vector2i] = []
	cells.assign(source.hex_court.cell_keys())
	check(concrete.configure_geometry(source.hex_court.origin, cells), "practice fixture replaces only subclass storage with concrete geometry")
	concrete.chemistry_enabled = true
	source.hex_court = concrete
	var snapshot := _advance_to_rich_capture(source)
	check(not snapshot.is_empty(), "sealed paid authority reaches live flight, product, and pending cast together")
	if snapshot.is_empty(): return
	var topology: HexCellTopology = source.hex_court.immutable_topology()
	check(topology != null, "real paid simulation and outer capture retain sealed topology")
	if topology == null: return
	_assert_chemistry_oracle(source.hex_court, "paid full authority")
	var first := Snapshot.prepare(snapshot, source)
	var second := Snapshot.prepare(snapshot, source)
	check(first != null and second != null, "complete outer snapshots prepare independently")
	if first == null or second == null: return
	check(first.hex_court.immutable_topology() == topology and second.hex_court.immutable_topology() == topology, "outer incoming path shares immutable geometry without blank-map copies")
	var legacy_court := _legacy_copy(second.hex_court)
	second.hex_court = legacy_court
	var expected := Legacy.capture(second)
	equal(snapshot, expected, "complete outer snapshot matches frozen legacy producer")
	equal(var_to_bytes(snapshot), var_to_bytes(expected), "complete packed/compressed wire remains exact")
	for offset: int in range(4):
		var command := SimCommand.new(source.tick, 1, 0, 0, 0, 0, 0, -1000, 640_000, 480_000)
		check(source.step([command]) and first.step([command]) and second.step([command]), "sealed and legacy paid continuation step %d" % offset)
		equal(source.state_hash(), first.state_hash(), "two sealed authorities continue identically")
		equal(source.state_hash(), second.state_hash(), "legacy materialized authority continues identically")
		check(source.hex_court.immutable_topology() == topology and first.hex_court.immutable_topology() == topology, "continuation cannot accidentally materialize sealed authority")
	var bad := Snapshot.capture(source)
	bad.state_hash = "0".repeat(64)
	var before := first.state_hash()
	check(not Snapshot.restore(bad, first), "malformed outer hash refuses before publication")
	equal(first.state_hash(), before, "outer rejection leaves complete authority unchanged")
	check(first.hex_court.immutable_topology() == topology, "outer rejection leaves topology ownership unchanged")
