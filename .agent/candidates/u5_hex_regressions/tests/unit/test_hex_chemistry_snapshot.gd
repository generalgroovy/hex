extends FluxTestSuite


const SnapshotCodec = preload("res://src/net/hex_chemistry_snapshot.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "hex snapshot fixtures load the production ability catalog: %s" % catalog.last_error)
	if not catalog.last_error.is_empty():
		return finish("hex-chemistry-snapshot")
	_test_real_input_continuation(catalog)
	_test_round_trip_and_subsequent_state(catalog)
	_test_pending_products_and_auxiliary_ledgers(catalog)
	_test_corruptions_reject_atomically(catalog)
	_test_trusted_topology_and_size_boundaries(catalog)
	_test_extended_footprint_lanes()
	_test_zero_allocation_ground_coverage(catalog)
	_test_full_layer_registry()
	return finish("hex-chemistry-snapshot")


func _test_round_trip_and_subsequent_state(catalog: AbilityCatalog) -> void:
	var original := _rich_world(catalog)
	var snapshot := SnapshotCodec.capture(original)
	check(not snapshot.is_empty(), "valid paid unified authority captures as schema 2")
	equal(int(snapshot.schema), SnapshotCodec.SCHEMA_VERSION, "capture identifies the local schema explicitly")
	check(SnapshotCodec.encoded_size(snapshot) > 0 and SnapshotCodec.encoded_size(snapshot) <= SnapshotCodec.MAX_ENCODED_BYTES, "encoded capture stays within its explicit one MiB boundary")
	var first_hash := SnapshotCodec.snapshot_hash(snapshot)
	check(first_hash.length() == 64, "typed schema has a deterministic SHA-256 snapshot hash")

	var restored := _court()
	check(SnapshotCodec.restore(snapshot, restored), "valid schema restores into matching trusted topology")
	equal(restored.state_hash(), original.state_hash(), "restore reproduces the complete chemistry authority hash")
	equal(restored.next_ground_part_id, original.next_ground_part_id, "independent ground-part allocator resumes exactly")
	var recaptured := SnapshotCodec.capture(restored)
	equal(SnapshotCodec.snapshot_hash(recaptured), first_hash, "capture, restore, and recapture preserve canonical snapshot bytes")

	original.sync_flights([], [])
	restored.sync_flights([], [])
	original.expire_at(500)
	restored.expire_at(500)
	equal(restored.state_hash(), original.state_hash(), "restored authority makes the identical subsequent retirement and expiry transition")
	check(restored.conservation_valid(), "subsequent restored state retains finite paid-matter conservation")


func _test_pending_products_and_auxiliary_ledgers(catalog: AbilityCatalog) -> void:
	var original := _rich_world(catalog)
	var snapshot := SnapshotCodec.capture(original)
	var restored := _court()
	check(SnapshotCodec.restore(snapshot, restored), "mixed pending and product authority restores")
	equal(restored.products.size(), 2, "both production Steam and Flood products survive restore")
	equal(restored.pending.size(), 2, "unpaid and paid pre-release reservations both survive restore")
	check(not bool(restored.casts[int(restored.pending[5])].paid), "unpaid pending reservation remains unpaid")
	check(bool(restored.casts[int(restored.pending[6])].paid), "paid pending reservation remains paid without inventing a source ledger")
	equal(restored.casts[int(restored.pending[6])].ledger, {}, "pre-release payment remains distinct from a bound source ledger")
	var flood_id := _product_id(restored, HexCourt.FLOOD_WIRE)
	var steam_id := _product_id(restored, HexCourt.STEAM_WIRE)
	check(flood_id > 0, "production Water mirror retains its Flood identity")
	check(steam_id > 0 and bool(restored.products[steam_id].heated), "production modifier channel preserves the Steam heated flag")
	equal(restored.products[steam_id].source_ids.size(), 3, "modified Steam preserves both parents and its paid modifier provenance")
	equal(int(restored.products[steam_id].intensity), int(original.products[steam_id].intensity), "modified product intensity restores exactly")
	equal(int(restored.products[steam_id].expiry_tick), int(original.products[steam_id].expiry_tick), "modified product expiry restores exactly")
	equal(restored.flow_carry.get("%d:8" % flood_id, Vector2i.ZERO), Vector2i(17, -23), "Flood numerator remainder survives as typed product/actor state")
	equal(int(restored.exposure.get(8, -1)), 19, "per-actor exposure survives within its bounded range")
	equal(restored.products[flood_id].source_ids, original.products[flood_id].source_ids, "ordered historical product provenance survives after ledger transfer")
	equal(restored.metrics, original.metrics, "all ten authority metrics restore exactly")
	check(restored.conservation_valid(), "pending payment and both products remain cross-ledger conserved")


func _test_corruptions_reject_atomically(catalog: AbilityCatalog) -> void:
	var snapshot := SnapshotCodec.capture(_rich_world(catalog))

	var wrong_type := snapshot.duplicate(true)
	wrong_type.header = Array(wrong_type.header)
	_rejects_without_mutation(wrong_type, "untyped header array")

	var duplicate_cast := snapshot.duplicate(true)
	duplicate_cast.casts.insert(1, duplicate_cast.casts[0].duplicate())
	_rejects_without_mutation(duplicate_cast, "duplicate cast id")

	var orphan_cell := snapshot.duplicate(true)
	var orphan_values: PackedInt64Array = orphan_cell.cast_cells.duplicate()
	orphan_values[0] = SnapshotCodec.MAX_ID
	orphan_cell.cast_cells = orphan_values
	_rejects_without_mutation(orphan_cell, "orphan cast allocation")

	var ledger_mismatch := snapshot.duplicate(true)
	var deposited_row_index := _cast_row_index(ledger_mismatch, 10_006)
	check(deposited_row_index >= 0, "corruption fixture locates the live deposited source row")
	if deposited_row_index < 0:
		return
	var cast_row: PackedInt64Array = ledger_mismatch.casts[deposited_row_index].duplicate()
	cast_row[7] -= 1
	cast_row[6] += 1
	ledger_mismatch.casts[deposited_row_index] = cast_row
	_rejects_without_mutation(ledger_mismatch, "cast scalar and immutable ledger mismatch")

	var duplicate_parent := snapshot.duplicate(true)
	var parent_row: PackedInt64Array = duplicate_parent.product_sources[0].duplicate()
	parent_row.append(parent_row[1])
	duplicate_parent.product_sources[0] = parent_row
	_rejects_without_mutation(duplicate_parent, "duplicate historical product source")

	var orphan_pending := snapshot.duplicate(true)
	var pending_values: PackedInt64Array = orphan_pending.pending.duplicate()
	pending_values[1] = SnapshotCodec.MAX_ID
	orphan_pending.pending = pending_values
	_rejects_without_mutation(orphan_pending, "orphan pending owner mapping")

	var orphan_flow := snapshot.duplicate(true)
	var flow_values: PackedInt64Array = orphan_flow.flow_carry.duplicate()
	flow_values[0] = SnapshotCodec.MAX_ID
	orphan_flow.flow_carry = flow_values
	_rejects_without_mutation(orphan_flow, "orphan Flood carry")

	var broken_conservation := snapshot.duplicate(true)
	var metric_values: PackedInt64Array = broken_conservation.metrics.duplicate()
	metric_values[6] -= HexCourt.MATTER_PER_CAST
	broken_conservation.metrics = metric_values
	_rejects_without_mutation(broken_conservation, "paid-matter conservation violation")

	var forged_hash := snapshot.duplicate(true)
	forged_hash.authority_hash = "0".repeat(64)
	_rejects_without_mutation(forged_hash, "authority hash mismatch")

	var forged_part := snapshot.duplicate(true)
	var part_row: PackedInt64Array = forged_part.cast_parts[0].duplicate()
	part_row[1] = SnapshotCodec.MAX_OWNER_ID
	forged_part.cast_parts[0] = part_row
	_rejects_without_mutation(forged_part, "typed cast-part team disagrees with authority hash")


func _test_trusted_topology_and_size_boundaries(catalog: AbilityCatalog) -> void:
	var snapshot := SnapshotCodec.capture(_rich_world(catalog))
	var different_topology := _court()
	different_topology.cells[Vector2i.ZERO].terrain = 1
	var topology_before := different_topology.state_hash()
	check(not SnapshotCodec.restore(snapshot, different_topology), "caller-owned terrain fingerprint rejects a remote topology substitution")
	equal(different_topology.state_hash(), topology_before, "topology mismatch cannot mutate the target map or authority")

	var too_many_allocations := snapshot.duplicate(true)
	var rows := PackedInt64Array()
	rows.resize((SnapshotCodec.MAX_CAST_CELL_ROWS + 1) * 3)
	too_many_allocations.cast_cells = rows
	_rejects_without_mutation(too_many_allocations, "cast allocation row cap")

	equal(SnapshotCodec.MAX_CAST_CELL_ROWS, HexCourt.MAX_CASTS * SnapshotCodec.MAX_ELIGIBLE_CELLS, "cast allocation boundary covers every legal cast/cell pair")
	equal(SnapshotCodec.MAX_PRODUCT_CELL_ROWS, HexCourt.MAX_PRODUCTS * SnapshotCodec.MAX_ELIGIBLE_CELLS, "product allocation boundary covers every legal product/cell pair")
	equal(SnapshotCodec.MAX_FLOW_ROWS, HexCourt.MAX_PRODUCTS * SnapshotCodec.MAX_TRACKED_ACTORS, "Flood carry boundary is product and actor bounded")
	equal(SnapshotCodec.MAX_ENCODED_BYTES, 1_048_576, "schema rejects captures beyond its documented encoded-byte ceiling")


func _test_extended_footprint_lanes() -> void:
	var capsule := HexFootprint.capsule(Vector2i(-30_000, 4_000), Vector2i(70_000, 4_000), 12_000)
	var annulus := HexFootprint.annulus(Vector2i(11_000, -9_000), 8_000, 45_000)
	for fixture: Dictionary in [capsule, annulus]:
		var encoded := SnapshotCodec._encode_footprint(fixture)
		check(encoded[0] in [3, 4], "selection-only capsule/annulus has a dedicated seven-lane tag")
		equal(SnapshotCodec._decode_footprint(encoded), fixture, "extended footprint lane round trips exactly")


func _test_zero_allocation_ground_coverage(catalog: AbilityCatalog) -> void:
	var court := _court()
	var wire := _wire(catalog, "water", "bolt")
	check(court.reserve_cast(1, wire), "zero-allocation fixture reserves source")
	court.commit_payment(1)
	court.bind_release(1, 71_001, court.origin, Vector2i(1000, 0), 1)
	var record: Dictionary = court.casts[int(court.sources[71_001])]
	var selected: Array[Vector2i] = []
	var ordered: Array = court.cells.keys()
	ordered.sort_custom(HexGrid._cell_less)
	for index: int in 3:
		selected.append(ordered[index])
	var shape := HexFootprint.disk(court.origin + HexGrid.center(selected[1]), 64_000)
	var part_id := court.next_ground_part_id
	var expiry := 4 + HexCourt.trail_lifetime(int(record.element))
	equal(HexCastParts.deposit_flight(record, 71_001, part_id, selected, shape, 4, expiry, true, 1), 1, "one trail unit is tiled across three selected cells")
	court.next_ground_part_id += 1
	var later_part_id := court.next_ground_part_id
	var later_expiry := 9 + HexCourt.trail_lifetime(int(record.element))
	equal(HexCastParts.deposit_flight(record, 71_001, later_part_id, selected.slice(0, 2), shape, 9, later_expiry, true, 1), 1, "a second ground part keeps its own creation and expiry")
	court.next_ground_part_id += 1
	record.footprint = shape
	record.expires = later_expiry
	court._sync_cast_ledger(record)
	court._rebuild_cast_layers(record)
	var snapshot := SnapshotCodec.capture(court)
	check(not snapshot.is_empty(), "zero-allocation coverage captures without synthesizing quantity")
	if snapshot.is_empty():
		return
	var restored := _court()
	var restored_ok := SnapshotCodec.restore(snapshot, restored)
	check(restored_ok, "zero-allocation coverage restores")
	if not restored_ok:
		return
	var restored_part: Dictionary = restored.casts[int(restored.sources[71_001])].ground_parts[part_id]
	var restored_later: Dictionary = restored.casts[int(restored.sources[71_001])].ground_parts[later_part_id]
	equal(restored_part.coverage.size(), 3, "all selected cells remain members after restore")
	equal(restored_part.cells.values().count(0), 2, "integer retile preserves two zero-allocation selected cells")
	equal(int(restored_later.expiry_tick) - int(restored_part.expiry_tick), 5, "independent ground-part lifetimes survive without collapse")


func _test_full_layer_registry() -> void:
	var court := _court()
	var sample: Dictionary = court.cells[court.cells.keys()[0]]
	for element: int in range(1, 9):
		var layer := HexRecipePolicy.ingredient_layer(element)
		check(not layer.is_empty() and sample.has(layer), "ingredient layer %d is present in trusted topology" % element)
	for wire: int in range(301, 337):
		var layer := HexRecipePolicy.product_layer(wire)
		check(not layer.is_empty() and sample.has(layer), "product wire %d owns one local topology layer" % wire)
		equal(SnapshotCodec._material_name(SnapshotCodec._material_code(layer)), layer, "product wire %d material lane round trips" % wire)


func _rich_world(catalog: AbilityCatalog) -> HexCourt:
	var court := _court()
	var water_bolt := _wire(catalog, "water", "bolt")
	var fire_bolt := _wire(catalog, "fire", "bolt")
	_deposit(court, 1, water_bolt, 10_001, Vector2i(-2, 0), 5)
	_deposit(court, 2, fire_bolt, 10_002, Vector2i(-2, 0), 5)
	_deposit(court, 3, water_bolt, 10_003, Vector2i(3, 0), 5)
	_deposit(court, 4, water_bolt, 10_004, Vector2i(3, 0), 5)
	equal(court.products.size(), 2, "production paid terminals form one Steam and one Flood snapshot fixture")
	_deposit(court, 7, fire_bolt, 10_005, Vector2i(-2, 0), 6)
	_deposit(court, 8, fire_bolt, 10_006, Vector2i(0, 4), 7)
	var flood_id := _product_id(court, HexCourt.FLOOD_WIRE)
	check(flood_id > 0, "snapshot fixture forms its Flood product through production contact")
	court.flow_carry["%d:8" % flood_id] = Vector2i(17, -23)
	court.exposure[8] = 19
	check(court.reserve_cast(5, water_bolt), "snapshot fixture reserves an unpaid pending cast")
	check(court.reserve_cast(6, fire_bolt), "snapshot fixture reserves a paid pending cast")
	court.commit_payment(6)
	court.expire_at(10)
	check(court.conservation_valid(), "production fixture and explicit auxiliary counters preserve matter before capture")
	return court


func _court() -> HexCourt:
	var court := HexCourt.new()
	court.chemistry_enabled = true
	return court


func _wire(catalog: AbilityCatalog, element: String, family: String) -> int:
	var ability_id := catalog.spell_id_at(element, family)
	return int(catalog.ability(ability_id).get("wire_id", 0))


func _deposit(court: HexCourt, owner: int, wire: int, source: int, cell: Vector2i, tick: int) -> void:
	check(court.reserve_cast(owner, wire), "production fixture reserves chemistry cast %d" % source)
	court.commit_payment(owner)
	court.bind_release(owner, source, court.origin)
	var definition := CombatTuning.cast_definition(wire)
	court.deposit_terminal({
		"type": "projectile_terminal", "source_cast_id": source, "source_wire_id": wire,
		"owner_id": owner, "team_id": owner, "element_wire_id": int(definition.element_wire_id),
		"position": court.origin + HexGrid.center(cell), "direction": Vector2i(1000, 0),
		"strength": 1000, "reaction_strength": int(definition.reaction_strength),
	}, tick)


func _product_id(court: HexCourt, recipe_wire_id: int) -> int:
	for id: int in court.products:
		if int(court.products[id].recipe_wire_id) == recipe_wire_id:
			return id
	return 0


func _cast_row_index(snapshot: Dictionary, source_id: int) -> int:
	for index: int in snapshot.casts.size():
		if int(snapshot.casts[index][11]) == source_id:
			return index
	return -1


func _rejects_without_mutation(snapshot: Dictionary, label: String) -> void:
	var target := _court()
	var before := target.state_hash()
	check(not SnapshotCodec.restore(snapshot, target), "%s corruption rejects" % label)
	equal(target.state_hash(), before, "%s rejection is atomic" % label)


func _test_real_input_continuation(catalog: AbilityCatalog) -> void:
	var original := SimWorld.new()
	var restored := SimWorld.new()
	check(HexCourtPractice.configure(original, catalog, false), "real paid input original court configured")
	check(HexCourtPractice.configure(restored, catalog, false), "real paid input restore court configured")
	var saw_product := false
	var saw_same_owner_pending := false
	for step: int in range(560):
		var slot := 0 if step == 0 or step == 160 or step == 260 else 1 if step == 100 else -1
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot]) if slot >= 0 else 0
		var command := SimCommand.new(step, 1, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000)
		check(original.step([command]) and restored.step([command]), "paid command advances both authorities")
		if step % 8 == 0 or slot >= 0:
			var payload := SnapshotCodec.capture(original.hex_court)
			check(not payload.is_empty(), "actual admitted runtime state is serializable")
			if payload.is_empty(): break
			check(SnapshotCodec.restore(payload, restored.hex_court), "real input snapshot restores atomically")
			equal(restored.state_hash(), original.state_hash(), "restored real input state preserves full simulation hash")
		for cast_id: int in original.hex_court.casts:
			var record: Dictionary = original.hex_court.casts[cast_id]
			if int(record.source) > 0 and original.hex_court.pending.has(int(record.owner)):
				saw_same_owner_pending = true
		saw_product = saw_product or not original.hex_court.products.is_empty()
		equal(restored.state_hash(), original.state_hash(), "subsequent SimWorld step remains identical after restore")
	check(saw_product, "paid input sequence forms actual product during roundtrip")
	check(saw_same_owner_pending, "codec supports prior live source while same owner starts next paid cast")
	check(original.hex_court.conservation_valid(), "real input continuation conserves all paid matter")
