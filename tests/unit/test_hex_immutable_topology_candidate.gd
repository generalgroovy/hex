extends "res://tests/unit/test_hex_chemistry_snapshot.gd"

const Candidate = preload("res://tests/support/hex_immutable_topology_candidate.gd")
const FrozenOracle = preload("res://tests/support/hex_stable_cells_candidate.gd")
const MAP_IDENTITY := "candidate-test-map"
const DEFINITION_IDENTITY := "candidate-test-definition"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "candidate fixtures load unchanged production abilities")
	if not catalog.last_error.is_empty(): return finish("hex-immutable-topology-candidate")
	_test_topology_value()
	_test_sparse_ownership(catalog)
	_test_zero_coverage_candidate(catalog)
	_test_zero_product_history(catalog)
	_test_candidate_refusals(catalog)
	return finish("hex-immutable-topology-candidate")


func _test_topology_value() -> void:
	var world := HexChemistryWorld.new()
	var coordinates: Array[Vector2i] = [Vector2i(11, 0), Vector2i(-2, 1), Vector2i(2, 0), Vector2i.ZERO]
	check(world.configure_geometry(Vector2i(1000, -2000), coordinates), "candidate mixed-coordinate fixture configures")
	world.cells[Vector2i.ZERO].terrain = 2_147_483_649
	world.cells[Vector2i.ZERO].elevation = -2_147_483_649
	var topology := Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not topology.is_empty(), "integer64 metadata admits without narrowing")
	if topology.is_empty(): return
	_assert_frozen_tree(topology, "topology")
	var ordered := SnapshotCodec._trusted_cells(world)
	equal(topology.numeric_cells, ordered, "numeric order equals production snapshot order")
	equal(Candidate.topology_bytes(topology), SnapshotCodec._topology_bytes(world, ordered), "exact signed64 topology bytes")
	equal(topology.fingerprint, SnapshotCodec._topology_hash(world, ordered), "exact wire topology fingerprint")
	equal(topology.legacy_hash_cells, world._ordered_hash_cell_keys(), "separate formatted-string hash order")
	check(topology.numeric_cells != topology.legacy_hash_cells, "fixture distinguishes numeric and formatted-string ordering")
	for index: int in ordered.size(): equal(topology.indices[ordered[index]], index, "stable numeric index %d" % index)
	var bytes := Candidate.topology_bytes(topology)
	bytes[0] = (bytes[0] + 1) % 256
	check(bytes != Candidate.topology_bytes(topology), "mutating returned packed buffer cannot poison shared topology")
	var detached: Dictionary = topology.metadata.duplicate(true)
	detached[Vector2i.ZERO].terrain = -99
	equal(topology.metadata[Vector2i.ZERO].terrain, 2_147_483_649, "detached metadata edit leaves frozen nested value unchanged")
	var reordered := {}
	coordinates.reverse()
	for cell: Vector2i in coordinates: reordered[cell] = world.cells[cell].duplicate(true)
	world.cells = reordered
	equal(Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY), topology, "independent reordered admission equals immutable value")
	var other_map := Candidate.admit_topology(world, "different-map", DEFINITION_IDENTITY)
	equal(other_map.fingerprint, topology.fingerprint, "legacy fingerprint intentionally excludes map identity")
	check(other_map != topology, "admitted map identity still distinguishes shared values")
	world.cells[Vector2i.ZERO].terrain = 8
	equal(topology.metadata[Vector2i.ZERO].terrain, 2_147_483_649, "later caller metadata edits cannot mutate admitted value")
	check(Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "changed metadata refuses old topology reuse")
	world.cells[Vector2i.ZERO].terrain = 8.0
	check(Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "wrong metadata type refuses admission")


func _test_sparse_ownership(catalog: AbilityCatalog) -> void:
	var world := _rich_world(catalog)
	var topology := Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY)
	var state := Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not state.is_empty(), "rich conserved authority imports through strict producer roundtrip")
	if state.is_empty(): return
	var expected := FrozenOracle.frozen_original_bytes(world)
	equal(Candidate.legacy_bytes(state), expected, "sparse adapter reproduces independent frozen canonical bytes")
	check(state.materials.size() < topology.numeric_cells.size(), "sparse state owns no wholly unused cell records")
	var first := Candidate.clone_state(state)
	var second := Candidate.clone_state(state)
	check(is_same(first.topology, topology) and is_same(second.topology, topology), "clones share the exact frozen topology value")
	for field: String in Candidate.DYNAMIC:
		check(not is_same(first[field], second[field]) and not is_same(first[field], world.get(field)), field + " dictionaries have independent ownership")
		first[field].clear()
		check(second[field] == state[field] and world.get(field) == state[field], field + " mutation cannot affect sibling/source")
	first.materials.clear()
	equal(Candidate.legacy_bytes(second), expected, "all first-clone mutations leave complete sibling canonical state unchanged")
	equal(FrozenOracle.frozen_original_bytes(world), expected, "clone mutations leave original complete authority unchanged")
	var one := Candidate.prepare_snapshot(SnapshotCodec.capture(world), topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	var two := Candidate.prepare_snapshot(SnapshotCodec.capture(world), topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not one.is_empty() and not two.is_empty(), "two strict compatibility restores succeed")
	if one.is_empty() or two.is_empty(): return
	check(is_same(one.topology, two.topology), "independent restores share topology alone")
	var cast_id: int = one.casts.keys()[0]
	one.casts[cast_id].ledger["candidate_mutation"] = 3
	one.products[one.products.keys()[0]].source_ids.append(999_999)
	one.exposure[8] = 0
	one.flow_carry.clear()
	equal(Candidate.legacy_bytes(two), expected, "nested ledger/provenance/exposure/flow edits do not leak across restores")
	var projected := Candidate.legacy_world(two)
	projected.cells[projected.cells.keys()[0]].terrain = 555
	projected.casts.clear()
	equal(Candidate.legacy_bytes(two), expected, "legacy projection is detached including metadata and authority")


func _test_zero_coverage_candidate(catalog: AbilityCatalog) -> void:
	var world := _court()
	var wire := _wire(catalog, "water", "bolt")
	check(world.reserve_cast(1, wire), "zero candidate reserves ordinary cast")
	world.commit_payment(1)
	world.bind_release(1, 71_001, world.origin, Vector2i(1000, 0), 1)
	var record: Dictionary = world.casts[int(world.sources[71_001])]
	var selected: Array[Vector2i] = []
	var keys: Array = world.cells.keys()
	keys.sort()
	for index: int in 3: selected.append(keys[index])
	var shape := HexFootprint.disk(world.origin + HexGrid.center(selected[1]), 64_000)
	var part_id := world.next_ground_part_id
	var expiry := 4 + HexCourt.trail_lifetime(int(record.element))
	equal(HexCastParts.deposit_flight(record, 71_001, part_id, selected, shape, 4, expiry, true, 1), 1, "one paid flight unit retains three covered cells")
	world.next_ground_part_id += 1
	record.footprint = shape
	record.expires = expiry
	world._sync_cast_ledger(record)
	world._rebuild_cast_layers(record)
	var topology := Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY)
	var state := Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not state.is_empty(), "zero-allocation covered source imports")
	if state.is_empty(): return
	equal(state.materials.size(), 3, "zero-quantity owner entries still occupy sparse reverse cells")
	equal(state.casts[record.id].ground_parts[part_id].cells.values().count(0), 2, "both zero quantities preserved in part allocations")
	equal(Candidate.legacy_bytes(state), FrozenOracle.frozen_original_bytes(world), "zero coverage preserves complete legacy bytes")
	var restored := Candidate.prepare_snapshot(SnapshotCodec.capture(world), topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not restored.is_empty(), "zero coverage strict compatibility restore succeeds")
	if restored.is_empty(): return
	equal(restored.materials, state.materials, "restore retains zero reverse entries")
	var scratch := Candidate.clone_state(state)
	var cell: Vector2i = selected[-1]
	check(Candidate.set_amount(scratch, cell, "water", 999, 0), "zero-valued extra owner remains representable")
	Candidate.erase_amount(scratch, cell, "water", int(record.id))
	check(scratch.materials.has(cell) and scratch.materials[cell].water.has(999), "removing one owner preserves zero-valued sibling")
	Candidate.erase_amount(scratch, cell, "water", 999)
	check(not scratch.materials.has(cell), "removing last owner releases sparse cell even with immutable topology membership retained")
	check(topology.indices.has(cell), "empty eligible cell remains admitted geometry")
	check(not Candidate.set_amount(scratch, Vector2i(257, 0), "water", 999, 0), "out-of-topology sparse writes refuse")
	check(not Candidate.set_amount(scratch, cell, "water", 999, -1), "negative sparse writes refuse")
	equal(Candidate.legacy_bytes(state), FrozenOracle.frozen_original_bytes(world), "scratch ownership changes never affect admitted source")


func _test_zero_product_history(catalog: AbilityCatalog) -> void:
	# Explicit boundary fixture, not the ordinary paid workload/profile: retain
	# the legal paid provenance but retile one stored unit over three cells.
	var world := _rich_world(catalog)
	var product_id := _product_id(world, HexCourt.FROSTWAY_WIRE)
	var product: Dictionary = world.products[product_id]
	var selected: Array[Vector2i] = []
	var keys: Array = world.cells.keys()
	keys.sort()
	for index: int in 3: selected.append(keys[index])
	product.quantity = 1
	world._retile_product(product, selected)
	product.contacts[7] = {"inside": false, "entered": 0, "last_pulse": 0, "effect_used": false}
	world.exposure[7] = 0
	world.flow_carry["%d:7" % product_id] = Vector2i.ZERO
	check(world.conservation_valid(), "explicit zero-product fixture remains within conserved paid matter")
	var topology := Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY)
	var state := Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not state.is_empty(), "zero product and history rows pass strict production admission")
	if state.is_empty(): return
	equal(state.products[product_id].cells.values().count(0), 2, "two zero product allocation cells remain")
	for cell: Vector2i in selected:
		check(state.materials[cell][product.material].has(product_id), "product inverse membership includes zero quantities")
	var restored := Candidate.prepare_snapshot(SnapshotCodec.capture(world), topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	check(not restored.is_empty(), "zero product strict compatibility restore succeeds")
	if restored.is_empty(): return
	equal(restored.products[product_id].contacts[7], product.contacts[7], "false and zero-valued contact history is preserved")
	check(restored.exposure.has(7) and restored.exposure[7] == 0, "zero exposure row is not dropped")
	check(restored.flow_carry.has("%d:7" % product_id), "zero flow carry row is not dropped")
	equal(Candidate.legacy_bytes(restored), FrozenOracle.frozen_original_bytes(world), "zero product/history restore preserves exact complete bytes")


func _test_candidate_refusals(catalog: AbilityCatalog) -> void:
	var world := _rich_world(catalog)
	var topology := Candidate.admit_topology(world, MAP_IDENTITY, DEFINITION_IDENTITY)
	var accepted := Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY)
	if accepted.is_empty():
		check(false, "refusal fixture imports")
		return
	var before := Candidate.legacy_bytes(accepted)
	check(Candidate.import_world(world, topology, "wrong-map", DEFINITION_IDENTITY).is_empty(), "wrong map refuses reuse")
	check(Candidate.import_world(world, topology, MAP_IDENTITY, "wrong-definition").is_empty(), "wrong definition refuses reuse")
	world.origin.x += 1
	check(Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "changed origin refuses reuse")
	world.origin.x -= 1
	var cell: Vector2i = world.cells.keys()[0]
	var saved: Dictionary = world.cells[cell].duplicate(true)
	world.cells.erase(cell)
	world.cells[Vector2i(200, 200)] = saved.duplicate(true)
	check(Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "same-size topology replacement refuses reuse")
	world.cells.erase(Vector2i(200, 200))
	world.cells[cell] = saved.duplicate(true)
	for value: Variant in [3, {"bad-owner": 1}, {777: -1}, {777: 1.5}, {777: 1}]:
		world.cells[cell].water = value
		check(Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "malformed or orphan reverse material refuses " + str(value))
		world.cells[cell] = saved.duplicate(true)
	world.sources.erase(world.sources.keys()[0])
	check(Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "removed source refuses strict import without repairing authority")
	world.sources = accepted.sources.duplicate(true)
	world.metrics.matter_paid += 1
	check(Candidate.import_world(world, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "broken conservation refuses strict import")
	world.metrics = accepted.metrics.duplicate(true)
	var snapshot := SnapshotCodec.capture(world)
	check(not snapshot.is_empty(), "restored refusal source retains valid snapshot")
	if snapshot.is_empty(): return
	var bad_hash := snapshot.duplicate(true)
	bad_hash.authority_hash = "0".repeat(64)
	var bad_counts := snapshot.duplicate(true)
	bad_counts.header = PackedInt64Array([1])
	var duplicate_id := snapshot.duplicate(true)
	duplicate_id.casts.append(duplicate_id.casts[0].duplicate())
	var bad_topology := snapshot.duplicate(true)
	bad_topology.topology_hash = "0".repeat(64)
	for malformed: Dictionary in [bad_hash, bad_counts, duplicate_id, bad_topology]:
		check(Candidate.prepare_snapshot(malformed, topology, MAP_IDENTITY, DEFINITION_IDENTITY).is_empty(), "malformed snapshot refuses detached candidate publication")
		equal(Candidate.legacy_bytes(accepted), before, "failed prepare leaves previously accepted full state untouched")
	equal(FrozenOracle.frozen_original_bytes(world), before, "all restored refusal fixtures recover exact source semantics")


func _assert_frozen_tree(value: Variant, label: String) -> void:
	if value is Dictionary:
		check(value.is_read_only(), label + " dictionary refuses mutation")
		for key: Variant in value: _assert_frozen_tree(value[key], label + "/" + str(key))
	elif value is Array:
		check(value.is_read_only(), label + " array refuses mutation")
		for index: int in value.size(): _assert_frozen_tree(value[index], label + "/%d" % index)
	else:
		check(typeof(value) in [TYPE_INT, TYPE_STRING, TYPE_VECTOR2I], label + " contains only immutable value leaves")
