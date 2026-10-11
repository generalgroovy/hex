extends FluxTestSuite

const Before = preload("res://tests/support/hex_polygon_before_cache.gd")
const CourtPresenter = preload("res://src/presentation/hex_court_presenter.gd")
const BeforePresenter = preload("res://tests/support/hex_court_before_paid_mesh.gd")


func run() -> int:
	_test_exact_detached_geometry()
	_test_paid_records_and_fresh_phases()
	_test_owner_prefix_equivalence()
	return finish("hex-render-polygon-cache")


func _test_exact_detached_geometry() -> void:
	var world := HexChemistryWorld.new()
	var before := Before.new()
	check(world.configure_geometry(Vector2i(1234567, 2345678), HexGrid.disk(Vector2i.ZERO, 3)), "geometry-cache fixture admits real hex topology")
	before.origin = world.origin
	var hash_before := world.state_hash()
	for cell: Vector2i in world.cell_keys():
		var expected: PackedVector2Array = before.whole_cell_polygon(cell)
		equal(world.whole_cell_polygon(cell), expected, "cold fixed vertices equal the frozen pre-cache implementation")
		var escaped := world.whole_cell_polygon(cell)
		escaped[0] += Vector2(99999, -77777)
		equal(world.whole_cell_polygon(cell), expected, "a public writable polygon cannot alter cached geometry")
	equal(world.state_hash(), hash_before, "geometry reads and cache residency do not change authority hash")
	var stats := world.render_polygon_cache_stats()
	equal(stats.entries, world.cell_count(), "repeated overlapping records retain one polygon per actual coordinate")
	equal(stats.hits, world.cell_count() * 2, "repeat reads avoid rebuilding all six fixed vertices")
	var held_geometry := world.whole_cell_polygon(Vector2i.ZERO)
	# Whole-cell geometry has always supported diagnostic coordinates outside the
	# topology. Do not turn a cache into a second coverage-admission decision.
	for index: int in 550:
		var cell := Vector2i(100 + index, 17)
		equal(world.whole_cell_polygon(cell), before.whole_cell_polygon(cell), "out-of-topology and overflow diagnostics retain exact original geometry")
	equal(world.render_polygon_cache_stats().entries, HexChemistryWorld.RENDER_POLYGON_CACHE_LIMIT, "arbitrary coordinates cannot grow retained geometry above512 entries")
	check(int(world.render_polygon_cache_stats().evictions) > 0, "later districts replace old geometry after the fixed cache fills")
	equal(held_geometry, before.whole_cell_polygon(Vector2i.ZERO), "an escaped polygon remains intact after its cache entry is evicted")
	check(not world._render_polygons.has(Vector2i.ZERO), "travelling across more than the cache budget evicts the original district")
	var before_revisit := world.render_polygon_cache_stats()
	equal(world.whole_cell_polygon(Vector2i.ZERO), before.whole_cell_polygon(Vector2i.ZERO), "returning to a displaced cell recomputes exact original geometry")
	equal(world.whole_cell_polygon(Vector2i.ZERO), before.whole_cell_polygon(Vector2i.ZERO), "a revisited district becomes warm again")
	equal(world.render_polygon_cache_stats().builds, int(before_revisit.builds) + 1, "a displaced cell builds only once on revisit")
	equal(world.render_polygon_cache_stats().hits, int(before_revisit.hits) + 1, "overlapping records reuse revisited geometry")
	equal(world.render_polygon_cache_stats().entries, HexChemistryWorld.RENDER_POLYGON_CACHE_LIMIT, "revisiting old districts does not grow the cache")
	world.origin += Vector2i(12345, -6789)
	before.origin = world.origin
	equal(world.whole_cell_polygon(Vector2i.ZERO), before.whole_cell_polygon(Vector2i.ZERO), "direct origin changes without revision immediately rebase cached geometry")
	equal(world.render_polygon_cache_stats().entries, 1, "origin shift releases the prior polygon cohort")
	equal(world._render_polygon_order.size(), 1, "origin shift also releases stale eviction order")
	equal(world._render_polygon_cursor, 0, "origin shift restarts the eviction cursor")
	world.cells[Vector2i(9, 9)] = {"terrain": 2, "elevation": 1}
	equal(world.whole_cell_polygon(Vector2i(9, 9)), before.whole_cell_polygon(Vector2i(9, 9)), "direct topology additions do not return a different cell's geometry")
	world.render_revision += 1
	equal(world.whole_cell_polygon(Vector2i.ZERO), before.whole_cell_polygon(Vector2i.ZERO), "explicit topology revision retains exact geometry")
	equal(world.render_polygon_cache_stats().entries, 1, "revision replaces the resident cohort")
	equal(world._render_polygon_order.size(), 1, "topology revision releases the old eviction order")
	equal(world._render_polygon_cursor, 0, "topology revision restarts the eviction cursor")
	check(world.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "an empty world can reconfigure its actual topology")
	equal(world.render_polygon_cache_stats(), {"entries": 0, "builds": 0, "hits": 0, "evictions": 0}, "reconfiguration clears every geometry resource and diagnostic counter")


func _test_paid_records_and_fresh_phases() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid cache fixture uses live compiled spells")
	var world := HexCourt.new()
	world.chemistry_enabled = true
	var wire := MixtureCatalog.wire_for(ElementRules.MASK_BY_WIRE[2], "bolt")
	var definition := CombatTuning.cast_definition_view(wire)
	for owner: int in [1, 2]:
		check(world.reserve_cast(owner, wire), "each overlapping fixture reserves an independent paid cast")
		world.commit_payment(owner)
		world.bind_release(owner, 71000 + owner, world.origin)
		world.deposit_terminal({"type": "projectile_terminal", "source_cast_id": 71000 + owner,
			"source_wire_id": wire, "owner_id": owner, "team_id": owner,
			"element_wire_id": 2, "position": world.origin, "direction": Vector2i(1000, 0),
			"strength": 1000, "reaction_strength": int(definition.reaction_strength)}, 0)
	var hash_before := world.state_hash()
	var observed := 0
	for cell: Vector2i in world.occupied_cells():
		for material: String in HexChemistryWorld.material_layers():
			for tick: float in [0.0, 23.0, 24.0, 419.0, 420.0, 479.0, 480.0, 900.0]:
				var warm := world.render_regions(cell, material, tick)
				# Invalidating only presentation geometry supplies a cold control
				# while retaining current authoritative records, phase and quantities.
				world._render_polygon_revision = -1
				equal(world.render_regions(cell, material, tick), warm, "cached geometry cannot retain an old phase, owner, quantity, source or expiry")
				observed += warm.size()
	check(observed > 0, "phase comparison observes actual paid occupied regions")
	equal(world.state_hash(), hash_before, "overlapping paid render queries preserve source budgets and canonical state")
	check(world.conservation_valid(), "cache reads preserve paid-matter conservation")


func _test_owner_prefix_equivalence() -> void:
	var current := CourtPresenter.new()
	var before := BeforePresenter.new()
	var row := {"material": "compound_63", "phase": "active", "danger": true, "owner_key": 1,
		"footprint_id": 17, "intensity": 750, "expiry_tick": 800, "decay_tick": 750}
	for material: String in ["fire", "steam", "conflagration", "cinderveil", "compound_63"]:
		row.material = material
		for owner: Variant in [0, 1, -1, 9223372036854775807, 1.0, "1", true, null, [1, 2], {"owner": 1, "team": 2}, {"team": 2, "owner": 1}]:
			row.owner_key = owner
			for repeat_index: int in 2:
				equal(current._region_edge_prefix(row), before._region_edge_prefix(row), "integer-owner fast lookup preserves exact frozen boundary text and generic owner semantics")
	var mutable := {"owner": 1}
	row.owner_key = mutable
	current._region_edge_prefix(row)
	mutable.owner = 2
	equal(current._region_edge_prefix(row), before._region_edge_prefix(row), "mutated generic owner dictionaries are serialized freshly")
	check(current._edge_prefixes.size() <= CourtPresenter.REGION_LAYOUT_LIMIT, "owner optimization keeps the existing per-pass boundary cache budget")
