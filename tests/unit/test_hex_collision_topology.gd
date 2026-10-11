extends "res://tests/unit/test_hex_collision_world.gd"

const PreE7 = preload("res://tests/support/hex_collision_pre_e7.gd")
const STATE_FIELDS: Array[String] = ["grid_origin", "_topology", "_indices", "_solid", "_cover", "_faces", "_components", "_actor_ignored", "_solid_ordered", "_cover_ordered", "_chemistry", "_sealed_topology"]

class SpoofedAuthority:
	extends HexChemistryWorld
	var alleged: HexCellTopology
	func immutable_topology() -> HexCellTopology:
		return alleged
	func cell_keys() -> Array:
		return alleged.numeric_cells()

class InheritedCollision:
	extends HexCollisionWorld


func run() -> int:
	_test_fresh_blank_and_ownership()
	_test_paid_rampart()
	_test_later_cover_and_component_order()
	_test_atomic_refusals()
	_test_public_configuration_and_subclasses()
	return finish("hex-collision-topology")


func _source() -> HexChemistryWorld:
	var result := HexChemistryWorld.new()
	check(result.configure_geometry(Vector2i(1_000_000, 1_000_000), HexGrid.disk(Vector2i.ZERO, 6)), "collision fixture owns admitted concrete topology")
	return result


func _destination() -> HexCollisionWorld:
	var base := CollisionWorld.new(2_000_000, 2_000_000)
	base.add_obstacle(CollisionWorld.Obstacle.new(1, 200_000, 200_000, 300_000, 300_000))
	return HexWorld.new(base)


func _state(world: HexCollisionWorld) -> Dictionary:
	var result := {}
	for field: String in STATE_FIELDS:
		var value: Variant = world.get(field)
		result[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


func _equal_configuration(actual: HexCollisionWorld, expected: HexCollisionWorld, label: String) -> void:
	for field: String in STATE_FIELDS: equal(actual.get(field), expected.get(field), label + " exact " + field)
	equal(actual._faces.keys(), expected._faces.keys(), label + " exact face insertion order")
	equal(actual._components.keys(), expected._components.keys(), label + " exact component traversal order")
	equal(actual.hex_occluders(), expected.hex_occluders(), label + " exact cover polygon order")
	for id: int in actual._faces:
		var face: Dictionary = actual._faces[id]
		equal(id, HexWorld.FACE_ID_BASE + int(actual._indices[face.cell]) * 8 + int(face.face), label + " face ID uses full topology index")


func _equal_queries(actual: HexCollisionWorld, expected: HexCollisionWorld, label: String) -> void:
	var center := actual.grid_origin
	var queries: Array = [
		[center - Vector2i(100_000, 0), center + Vector2i(100_000, 0)],
		[center - Vector2i(0, 100_000), center + Vector2i(0, 100_000)],
		[center - Vector2i(120_000, 80_000), center + Vector2i(120_000, 80_000)],
		[center, center + Vector2i(160_000, 0)],
		[Vector2i(100_000, 250_000), Vector2i(350_000, 250_000)],
	]
	for query: Array in queries:
		var start: Vector2i = query[0]
		var finish: Vector2i = query[1]
		equal(actual.hex_segment_clear(start, finish), expected.hex_segment_clear(start, finish), label + " combined LOS")
		equal(actual.hex_pillar_segment_clear(start, finish), expected.hex_pillar_segment_clear(start, finish), label + " pillar-only LOS")
		for radius: int in [0, 5_000, 18_000]:
			equal(actual.can_occupy(start, radius), expected.can_occupy(start, radius), label + " occupancy")
			equal(actual.hex_wall_contact(start, finish, radius), expected.hex_wall_contact(start, finish, radius), label + " exact swept projectile contact")
			actual.begin_actor(start, radius)
			expected.begin_actor(start, radius)
			equal(actual._actor_ignored, expected._actor_ignored, label + " exact connected escape exemptions")
			var moved := actual.move_box(start, finish - start, radius)
			var reference := expected.move_box(start, finish - start, radius)
			equal([moved.position, moved.wall_normal, moved.wall_id, moved.blocking_normals], [reference.position, reference.wall_normal, reference.wall_id, reference.blocking_normals], label + " exact actor movement/contact")
			equal(actual.nearby_hex_face(start, radius, 4), expected.nearby_hex_face(start, radius, 4), label + " nearest face")
	actual.begin_actor(Vector2i.ZERO, 18_000)
	expected.begin_actor(Vector2i.ZERO, 18_000)


func _test_fresh_blank_and_ownership() -> void:
	var authority := _source()
	var topology := authority.immutable_topology()
	var first := _destination()
	var sibling := _destination()
	var expected := _destination()
	check(first.set_hex_surfaces(authority, 0) and sibling.set_hex_surfaces(authority, 0), "fresh empty collisions admit actual immutable geometry")
	check(PreE7.set_hex_surfaces(expected, authority, 0), "frozen preceding empty setup accepts")
	_equal_configuration(first, expected, "empty")
	_equal_queries(first, expected, "empty")
	check(first._indices.is_read_only() and first._topology.is_read_only(), "fresh setup borrows read-only full order and indices")
	check(not expected._indices.is_read_only() and not expected._topology.is_read_only(), "frozen predecessor really builds its own mutable order/index")
	equal(first._topology, topology.numeric_cells(), "borrowed order equals admitted numeric order")
	equal(first._indices, topology.cell_indices(), "borrowed index map equals admitted full-cell indices")
	first._actor_ignored[Vector2i.ZERO] = true
	check(sibling._actor_ignored.is_empty(), "actor escape bookkeeping is never shared")
	first._faces[123] = {"cell": Vector2i.ZERO, "face": 0}
	first._components[Vector2i.ZERO] = Vector2i.ZERO
	check(sibling._faces.is_empty() and sibling._components.is_empty(), "dynamic faces and components are independently owned")
	var cell: Vector2i = authority.cell_keys()[0]
	authority.cells.erase(cell)
	check(authority.immutable_topology() == null, "compatibility mutation detaches source geometry")
	equal(sibling._topology.size(), topology.numeric_cells().size(), "source compatibility edits cannot mutate admitted sibling order")
	check(sibling._indices.has(cell), "source compatibility edits cannot mutate admitted sibling indices")
	check(not sibling.set_hex_surfaces(authority, 0), "same collision cannot silently adopt changed mutable topology")


func _test_paid_rampart() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid collision fixture loads production abilities")
	if not catalog.last_error.is_empty(): return
	var authority := _source()
	authority.chemistry_enabled = true
	var wire := int(catalog.ability(catalog.spell_id_at("earth", "bolt")).get("wire_id", 0))
	for owner: int in [1, 2]:
		var source_id := 90_000 + owner
		check(authority.reserve_cast(owner, wire), "paid Rampart reserves Earth source")
		authority.commit_payment(owner)
		authority.bind_release(owner, source_id, authority.origin)
		var definition := CombatTuning.cast_definition(wire)
		authority.deposit_terminal({"type": "projectile_terminal", "source_cast_id": source_id, "source_wire_id": wire,
			"owner_id": owner, "team_id": owner, "element_wire_id": int(definition.element_wire_id),
			"position": authority.origin, "direction": Vector2i(1000, 0), "strength": 1000,
			"reaction_strength": int(definition.reaction_strength)}, 5)
	check(authority.products.size() == 1 and authority.conservation_valid(), "two ordinary paid Earth deposits form conserved product authority")
	if authority.products.size() != 1: return
	var product: Dictionary = authority.products.values()[0]
	equal(int(product.recipe_wire_id), 301, "paid Earth mirror is Rampart")
	check(authority.immutable_topology() != null, "paid formation retains sealed topology")
	var actual := _destination()
	var expected := _destination()
	for tick: int in [int(product.active_tick) - 1, int(product.active_tick), int(product.decay_tick) - 1, int(product.decay_tick)]:
		check(actual.set_hex_surfaces(authority, tick) and PreE7.set_hex_surfaces(expected, authority, tick), "paid phase setup accepts in both implementations")
		_equal_configuration(actual, expected, "paid Rampart tick %d" % tick)
		_equal_queries(actual, expected, "paid Rampart tick %d" % tick)
		var fresh := _destination()
		var fresh_reference := _destination()
		check(fresh.set_hex_surfaces(authority, tick) and PreE7.set_hex_surfaces(fresh_reference, authority, tick), "fresh collision follows each paid phase")
		_equal_configuration(fresh, fresh_reference, "fresh paid phase")
		if tick == int(product.active_tick): check(not fresh._solid.is_empty() and not fresh._faces.is_empty(), "active paid Rampart really exercises solid faces")
	product.health = 0
	check(actual.set_hex_surfaces(authority, int(product.active_tick)) and PreE7.set_hex_surfaces(expected, authority, int(product.active_tick)), "destroyed paid Rampart refreshes")
	_equal_configuration(actual, expected, "destroyed Rampart")
	check(actual._solid.is_empty() and actual._cover.is_empty(), "zero health removes physical cover")


func _test_later_cover_and_component_order() -> void:
	var authority := _source()
	# Geometry-only fixtures deliberately exercise disconnected seed ordering and
	# mixed cover recipes without claiming these synthetic rows are paid state.
	for id: int in range(1, 5):
		var cell: Vector2i = [Vector2i(3, 0), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i.ZERO][id - 1]
		authority.products[id] = _cover_product(id, 301, cell)
	for wire: int in [305, 306, 307, 329]:
		authority.products[5] = _cover_product(5, wire, Vector2i(1, 0))
		authority.products[5].cells[Vector2i(1, 0)] = 0
		var actual := _destination()
		var expected := _destination()
		check(actual.set_hex_surfaces(authority, 10) and PreE7.set_hex_surfaces(expected, authority, 10), "mixed Rampart/later-cover fixture admits")
		_equal_configuration(actual, expected, "mixed cover %d" % wire)
		_equal_queries(actual, expected, "mixed cover %d" % wire)
		check(actual._cover.has(Vector2i(1, 0)) and not actual._solid.has(Vector2i(1, 0)), "zero-allocation later cover remains shot/LOS coverage only")
		equal(actual._components[Vector2i.ZERO], Vector2i(-2, 0), "connected component retains numeric minimum seed")
		equal(actual._components[Vector2i(3, 0)], Vector2i(3, 0), "disconnected component keeps independent seed")
		var sibling := _destination()
		check(sibling.set_hex_surfaces(authority, 10), "active sibling constructs independently")
		actual.begin_actor(authority.origin, 18_000)
		check(not actual._actor_ignored.is_empty() and sibling._actor_ignored.is_empty(), "escape exemption is local to active collision instance")
		actual._faces.clear()
		check(not sibling._faces.is_empty(), "active sibling faces are not shared")


func _test_atomic_refusals() -> void:
	for fresh: bool in [true, false]:
		var authority := _source()
		authority.products[1] = _cover_product(1, 301, Vector2i.ZERO)
		var actual := _destination()
		var expected := _destination()
		if not fresh:
			check(actual.set_hex_surfaces(authority, 10) and PreE7.set_hex_surfaces(expected, authority, 10), "atomic refresh fixture starts configured")
			actual.begin_actor(authority.origin, 18_000)
			expected.begin_actor(authority.origin, 18_000)
		var before := _state(actual)
		var reference_before := _state(expected)
		authority.products[2] = _cover_product(2, 301, Vector2i(30, 30))
		check(not actual.set_hex_surfaces(authority, 10) and not PreE7.set_hex_surfaces(expected, authority, 10), "unknown dynamic coverage refuses before publication")
		equal(_state(actual), before, "invalid coverage preserves every candidate collision field")
		equal(_state(expected), reference_before, "invalid coverage preserves frozen reference state")
		authority.products.erase(2)
		check(actual.set_hex_surfaces(authority, 10) and PreE7.set_hex_surfaces(expected, authority, 10), "normal refresh recovers after rejection")
		_equal_configuration(actual, expected, "post-refusal recovery")
	for mutation: String in ["origin", "same-count"]:
		var source := _source()
		var actual := _destination()
		var expected := _destination()
		check(actual.set_hex_surfaces(source, 0) and PreE7.set_hex_surfaces(expected, source, 0), "topology replacement fixture configures")
		var before := _state(actual)
		if mutation == "origin": source.origin += Vector2i(1, 0)
		else:
			var cell: Vector2i = source.cell_keys()[0]
			var cells: Dictionary = source.cells
			var row: Dictionary = cells[cell]
			cells.erase(cell)
			cells[Vector2i(10, 0)] = row
		check(not actual.set_hex_surfaces(source, 0) and not PreE7.set_hex_surfaces(expected, source, 0), mutation + " cannot remap installed face indices")
		equal(_state(actual), before, mutation + " rejection preserves installed collision state")


func _test_public_configuration_and_subclasses() -> void:
	var origin := Vector2i(1_000_000, 1_000_000)
	var topology := HexGrid.disk(Vector2i.ZERO, 2)
	var duplicate := topology.duplicate()
	duplicate.append(duplicate[0])
	var out_of_bounds: Array[Vector2i] = [Vector2i(385, -200)]
	check(HexGrid._query_point_valid(origin + HexGrid.center(out_of_bounds[0])), "one-past384 axial negative stays inside world-coordinate bounds")
	var cases: Array = [
		[origin, topology, [Vector2i.ZERO], [Vector2i.ZERO], true],
		[origin, duplicate, [], [], false],
		[origin, out_of_bounds, [], [], false],
		[Vector2i(HexGrid.MAX_ABS_QUERY_COORDINATE + 1, 0), topology, [], [], false],
		[Vector2i(HexGrid.MAX_ABS_QUERY_COORDINATE, 0), [Vector2i(1, 0)], [], [], false],
		[origin, topology, [Vector2i.ZERO, Vector2i.ZERO], [Vector2i.ZERO], false],
		[origin, topology, [Vector2i.ZERO], [Vector2i.ZERO, Vector2i.ZERO], false],
		[origin, topology, [Vector2i.ZERO], [], false],
	]
	for row: Array in cases:
		var cells: Array[Vector2i] = []
		var solid: Array[Vector2i] = []
		var cover: Array[Vector2i] = []
		cells.assign(row[1])
		solid.assign(row[2])
		cover.assign(row[3])
		var actual := _destination()
		var expected := _destination()
		equal(actual._configure_hex_sets(row[0], cells, solid, cover), row[4], "ordinary explicit configuration preserves acceptance/refusal")
		equal(PreE7.configure_hex_sets(expected, row[0], cells, solid, cover), row[4], "frozen configuration confirms expected refusal")
		_equal_configuration(actual, expected, "explicit configuration")
	# The frozen pre-E7 oracle deliberately retains its historical256 boundary.
	# Expanded-domain acceptance is asserted separately, never called equivalence.
	var expanded_cells: Array[Vector2i] = [Vector2i(257, 0)]
	var expanded_current := _destination()
	var old_domain := _destination()
	check(expanded_current.configure_hexes(origin, expanded_cells, []), "current public collision authority accepts explicitly expanded axial257")
	check(not PreE7.configure_hex_sets(old_domain, origin, expanded_cells, [], []), "unchanged independent oracle retains old-domain axial257 refusal")
	equal(expanded_current._topology, expanded_cells, "accepted expanded coordinate is retained exactly without clipping or remapping")
	var inherited := InheritedCollision.new(CollisionWorld.new(2_000_000, 2_000_000))
	check(inherited.configure_hexes(origin, topology, [Vector2i.ZERO]), "subclass inherits unchanged public configure_hexes contract")
	equal(inherited._cover, inherited._solid, "public configure_hexes still treats occupied cells as both solid and cover")
	check(not inherited.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 1), []), "public configuration cannot replace installed topology")
	var source := _source()
	var spoof := SpoofedAuthority.new()
	spoof.origin = source.origin
	spoof.alleged = source.immutable_topology()
	spoof.cells = {Vector2i(385, -200): {"terrain": 0, "elevation": 0, "structure": 0}}
	var actual := _destination()
	var expected := _destination()
	check(actual._owned_topology(spoof) == null, "subclass cannot assert admission with another world's handle")
	check(not actual.set_hex_surfaces(spoof, 0) and not PreE7.set_hex_surfaces(expected, spoof, 0), "subclass accessor spoof cannot hide out-of-bounds mutable membership")
	_equal_configuration(actual, expected, "subclass refusal")
	spoof.cells = source.immutable_topology().metadata().duplicate(true)
	check(actual.set_hex_surfaces(spoof, 0) and PreE7.set_hex_surfaces(expected, spoof, 0), "valid subclass uses complete legacy fallback")
	_equal_configuration(actual, expected, "valid subclass fallback")
	check(not actual._indices.is_read_only(), "subclass never acquires borrowed immutable index trust")
