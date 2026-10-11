extends FluxTestSuite

const Frozen = preload("res://tests/support/hex_stable_cells_candidate.gd")
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")

class BorrowedTopologyWorld:
	extends HexChemistryWorld
	var borrowed: HexCellTopology
	func immutable_topology() -> HexCellTopology: return borrowed
	func cell_keys() -> Array: return borrowed.numeric_cells()
	func clone_cell_storage_to(target: HexChemistryWorld) -> void:
		target.cells = cells # Adversarial extension must never reach this callback.


func run() -> int:
	_test_ownership()
	_test_membership_and_readers()
	_test_escape_and_reconfigure()
	_test_canonical_rows()
	_test_subclass_boundaries()
	return finish("hex-cell-storage")


func _world() -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	var selected: Array[Vector2i] = [Vector2i(2, 0), Vector2i.ZERO, Vector2i(-2, 0), Vector2i(10, 0)]
	check(world.configure_geometry(Vector2i(640_000, 480_000), selected), "storage fixture configures")
	world.chemistry_enabled = true
	return world


func _same_bytes(world: HexChemistryWorld, label: String) -> void:
	var topology := world.immutable_topology()
	var legacy := HexChemistryWorld.new()
	world.clone_cell_storage_to(legacy)
	legacy.chemistry_enabled = world.chemistry_enabled
	var materialized: Dictionary = legacy.cells
	check(materialized.size() == world.cell_count(), label + " oracle projection complete")
	equal(world._state_hash_bytes(), Frozen.frozen_original_bytes(legacy), label + " exact frozen legacy bytes")
	check(world.immutable_topology() == topology, label + " hashing and cloning retain source topology")


func _test_ownership() -> void:
	var source := _world()
	var topology := source.immutable_topology()
	check(topology != null, "configured production world is sealed")
	if topology == null: return
	check(source.cell_record(Vector2i.ZERO).is_read_only(), "blank metadata is immutable")
	source.set_cell_amount(Vector2i.ZERO, "water", 1, 0)
	source.set_cell_amount(Vector2i.ZERO, "water", 2, 17)
	check(source.cell_record(Vector2i.ZERO).is_read_only(), "material row keeps metadata immutable")
	var alias: Dictionary = source.cell_record(Vector2i.ZERO).water
	var one := HexChemistryWorld.new()
	var two := HexChemistryWorld.new()
	source.clone_cell_storage_to(one)
	source.clone_cell_storage_to(two)
	check(one.immutable_topology() == topology and two.immutable_topology() == topology, "copies share exact static geometry")
	check(not is_same(one.cell_record(Vector2i.ZERO).water, alias), "clone owns detached nested material")
	check(not is_same(one.cell_record(Vector2i.ZERO).water, two.cell_record(Vector2i.ZERO).water), "sibling material dictionaries are independent")
	one.set_cell_amount(Vector2i.ZERO, "water", 2, 71)
	equal(alias[2], 17, "clone mutation cannot change original")
	equal(two.cell_record(Vector2i.ZERO).water[2], 17, "clone mutation cannot change sibling")
	var escaped: Dictionary = source.cells
	check(source.immutable_topology() == null, "writable compatibility read detaches once")
	check(is_same(escaped[Vector2i.ZERO].water, alias), "same-world preexisting nested alias remains authoritative after escape")
	alias[2] = 33
	equal(source.cells[Vector2i.ZERO].water[2], 33, "existing nested alias edit remains visible")
	escaped[Vector2i.ZERO].terrain = 8
	equal(two.cell_record(Vector2i.ZERO).terrain, 0, "legacy metadata edit does not affect shared sibling geometry")
	check(two.immutable_topology() == topology, "sibling remains sealed after other world escape")


func _test_membership_and_readers() -> void:
	var world := _world()
	var topology := world.immutable_topology()
	check(world.dynamic_cell_keys().is_empty(), "blank map allocates zero dynamic rows")
	for cell: Vector2i in world.cell_keys():
		var point := world.origin + HexGrid.center(cell)
		var selection := world.select_cells(HexFootprint.disk(point, 1))
		check(selection.has(cell), "dry geometry remains eligible for first deposit")
	world.set_cell_amount(Vector2i.ZERO, "water", 1, 0)
	world.set_cell_amount(Vector2i.ZERO, "water", 2, 0)
	world.erase_cell_amount(Vector2i.ZERO, "water", 1)
	check(world.cell_record(Vector2i.ZERO).water.has(2), "erasing one zero allocation keeps second owner")
	world.erase_cell_amount(Vector2i.ZERO, "water", 2)
	check(world.dynamic_cell_keys().is_empty() and world.has_cell(Vector2i.ZERO), "last erase removes material only")
	world.set_cell_amount(Vector2i.ZERO, "fire", 3, 1)
	world.erase_cell_amount(Vector2i.ZERO, "fire", 3)
	check(not world.cell_record(Vector2i.ZERO).has("fire"), "fresh lookup never retains stale layer presence")
	var collision := HexCollisionWorld.new(CollisionWorld.new())
	check(collision.set_hex_surfaces(world, 0), "collision admits full empty map")
	check(collision.set_hex_surfaces(world, 1), "collision refresh reuses actual immutable topology")
	var presenter := Presenter.new()
	check(presenter._prepare_court(world, true), "presentation geometry reads sealed terrain")
	presenter._prepare_frame_bundle(world, 0.0)
	check(world.immutable_topology() == topology, "normal collision/render readers do not materialize compatibility")
	var escaped: Dictionary = world.cells
	var row: Dictionary = escaped[Vector2i(10, 0)]
	escaped.erase(Vector2i(10, 0))
	escaped[Vector2i(11, 0)] = row
	check(not collision.set_hex_surfaces(world, 2), "same-object changed topology does not reuse stale collision indices")


func _test_escape_and_reconfigure() -> void:
	var world := _world()
	var old_origin := world.origin
	var prior := world.immutable_topology()
	world.origin += Vector2i(1, 0)
	check(world.immutable_topology() == null, "origin edit invalidates immutable identity")
	world.origin = old_origin
	check(world.immutable_topology() == null, "restoring origin cannot resurrect escaped admission")
	var held: Dictionary = world.cells
	var selected: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	check(world.configure_geometry(old_origin, selected), "explicit safe reconfigure constructs new owned geometry")
	check(world.immutable_topology() != null and world.immutable_topology() != prior, "reconfigure owns a new handle")
	held[Vector2i.ZERO].terrain = 999
	equal(world.cell_record(Vector2i.ZERO).terrain, 0, "old escaped alias cannot mutate new configuration")
	world.metrics.matter_paid = 600
	var before := world.immutable_topology()
	check(not world.configure_geometry(old_origin, selected), "paid state blocks geometry reconfiguration")
	check(world.immutable_topology() == before, "refused configuration preserves current topology")


func _test_canonical_rows() -> void:
	var world := _world()
	_same_bytes(world, "empty")
	for cell: Vector2i in world.cell_keys():
		world.set_cell_amount(cell, "water", 2, 0)
		world.set_cell_amount(cell, "fire", 11, 600)
	_same_bytes(world, "zero and populated rows")
	for cell: Vector2i in world.cell_keys(): world.cell_record(cell).water.clear()
	_same_bytes(world, "explicit empty dictionaries")
	world.set_cell_amount(Vector2i.ZERO, "unknown-empty", 99, 0)
	world.cell_record(Vector2i.ZERO)["unknown-empty"].clear()
	_same_bytes(world, "unknown empty dictionaries preserve hash projection")
	world.set_cell_amount(Vector2i.ZERO, "water", 1, 2_147_483_650)
	_same_bytes(world, "wide dynamic amount uses exact generic fallback")


func _test_subclass_boundaries() -> void:
	var source := _world()
	var derived := BorrowedTopologyWorld.new()
	derived.borrowed = source.immutable_topology()
	derived.origin = source.origin
	var selected: Array[Vector2i] = [Vector2i.ZERO, Vector2i(12, 0)]
	check(derived.configure_geometry(source.origin, selected), "extension owns a different topology")
	var collision := HexCollisionWorld.new(CollisionWorld.new())
	check(collision.set_hex_surfaces(source, 0), "concrete collision establishes trusted topology")
	check(not collision.set_hex_surfaces(derived, 1), "subclass cannot substitute another world's immutable handle or cell_keys")
	derived.set_cell_amount(Vector2i.ZERO, "water", 1, 5)
	var world := SimWorld.new()
	world.hex_court = derived
	var predictor := ClientPrediction.new()
	var prepared := predictor.prepare_hex_context(world)
	check(not prepared.is_empty(), "extension prediction retains legacy independent-copy path")
	if prepared.is_empty(): return
	var prediction: HexChemistryWorld = prepared.authority
	prediction.set_cell_amount(Vector2i.ZERO, "water", 1, 25)
	equal(derived.cells[Vector2i.ZERO].water[1], 5, "virtual clone cannot alias prediction to original authority")
