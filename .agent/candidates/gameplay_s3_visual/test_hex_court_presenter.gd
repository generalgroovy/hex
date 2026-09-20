extends FluxTestSuite


const Presenter = preload("res://src/presentation/hex_court_presenter.gd")


class MissingRegionCourt:
	extends RefCounted


class RegionCourt:
	extends RefCounted
	var regions: Array = []

	func render_regions(_cell: Vector2i, _material: String, _tick: float) -> Array:
		return regions


func run() -> int:
	_test_configuration_and_fail_closed_regions()
	_test_seam_identity_accepts_integer_and_boolean_fields()
	_test_inward_outline_geometry()
	_test_phase_style_metadata()
	_test_strength_scaled_projectile_size()
	_test_projectile_size_cache()
	_test_projectile_cache_reuse_and_bound()
	_test_projectile_helpers_do_not_mutate_state()
	return finish("hex-court-presenter")


func _configured_presenter() -> HexCourtPresenter:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "shared visual language loads for the hex presenter")
	var presenter := Presenter.new()
	check(presenter.configure(language), "hex presenter accepts the validated shared palette")
	return presenter


func _test_configuration_and_fail_closed_regions() -> void:
	var presenter := Presenter.new()
	check(not presenter.configure(null), "hex presenter refuses a missing shared palette")
	check(not presenter.configure(VisualLanguage.new()), "hex presenter refuses an unloaded shared palette")
	presenter = _configured_presenter()
	presenter._cells = [Vector2i.ZERO]
	var active_views := {Vector2i.ZERO: {"water_quantity": 1, "fire_quantity": 0, "steam_quantity": 0}}
	check(presenter._collect_render_regions(MissingRegionCourt.new(), active_views, 0.0).is_empty(), "quantity-positive material without the authority API fails closed")
	var court := RegionCourt.new()
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "quantity-positive material without an explicit region fails closed")
	court.regions = [{"footprint_id": 7, "polygon": PackedVector2Array(), "phase": "forming", "danger": false, "intensity": 1000}]
	var tangent := presenter._collect_render_regions(court, active_views, 0.0)
	check(not tangent.is_empty(), "explicit analytic tangent is valid presentation input")
	equal((tangent.water[Vector2i.ZERO] as Array).size(), 0, "zero-area display clip draws no invented whole-hex material")
	court.regions = [{"footprint_id": 7, "polygon": PackedVector2Array(), "phase": "forming", "intensity": 1000}]
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "empty clip still requires complete danger metadata")


func _test_seam_identity_accepts_integer_and_boolean_fields() -> void:
	var presenter := _configured_presenter()
	var identity := {"material": "steam", "footprint_id": 17, "phase": "active", "danger": true, "intensity": 900}
	var forward := presenter._region_edge_key(identity, Vector2(1000, 0), Vector2(1000, 1000))
	var reverse := presenter._region_edge_key(identity, Vector2(1000, 1000), Vector2(1000, 0))
	equal(forward, reverse, "seam identity is independent of polygon winding")
	equal(forward, "steam/17/active/true/900/1000,0:1000,1000", "integer footprint and Boolean danger use explicit stable text")
	var safe := identity.duplicate()
	safe.danger = false
	check(presenter._region_edge_key(safe, Vector2(1000, 0), Vector2(1000, 1000)) != forward, "danger boundary cannot merge into a safe neighbor")
	var left := presenter._prepare_region({"footprint_id": 17, "polygon": PackedVector2Array([Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 1000), Vector2(0, 1000)]), "phase": "active", "danger": true, "intensity": 900}, "steam")
	var right := presenter._prepare_region({"footprint_id": 17, "polygon": PackedVector2Array([Vector2(1000, 0), Vector2(2000, 0), Vector2(2000, 1000), Vector2(1000, 1000)]), "phase": "active", "danger": true, "intensity": 900}, "steam")
	var counts := presenter._region_edge_counts({Vector2i.ZERO: [left], Vector2i.RIGHT: [right]})
	equal(int(counts[forward]), 2, "matching footprint/phase/danger/intensity hides the internal shared segment")


func _test_inward_outline_geometry() -> void:
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var strip := Presenter._inward_edge_strip(polygon, 0, 2.0)
	equal(strip.size(), 4, "one semantic boundary is a finite four-point strip")
	equal(strip[0], polygon[0], "boundary strip begins at the exact authority edge")
	equal(strip[1], polygon[1], "boundary strip ends at the exact authority edge")
	for point: Vector2 in strip:
		check(point.x >= 0.0 and point.x <= 10.0 and point.y >= 0.0 and point.y <= 10.0, "outline strip never expands outside the clipped footprint")
	check(strip[2].y > 0.0 and strip[3].y > 0.0, "outline thickness extends inward from the authority edge")
	check(Presenter._inward_edge_strip(polygon, -1, 2.0).is_empty(), "invalid edge fails closed")
	check(Presenter._inward_edge_strip(polygon, 0, 0.0).is_empty(), "nonpositive boundary width fails closed")
	equal(Presenter._inward_edge_triangles(polygon, 0, 2.0).size(), 2, "convex strip draws as two primitives without polygon triangulation")
	var duplicate := PackedVector2Array([Vector2(1000, 700), Vector2(1000, 700), Vector2(1001, 701), Vector2(999, 701)])
	check(Presenter._inward_edge_triangles(duplicate, 0, 3.0).is_empty(), "zero-length clipped edge produces no degenerate draw primitive")
	var sliver := PackedVector2Array([Vector2(1000, 700), Vector2(1000.0001, 700.0001), Vector2(1001, 701), Vector2(999, 701)])
	for triangle: PackedVector2Array in Presenter._inward_edge_triangles(sliver, 0, 3.0):
		equal(triangle.size(), 3, "float32 sliver emits only explicitly triangulated primitives")
		check(absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.0001, "subpixel border omits collapsed triangles")


func _test_phase_style_metadata() -> void:
	var presenter := _configured_presenter()
	var water := {"phase": "active", "danger": false, "intensity": 1000}
	var water_normal := presenter._water_region_style(water, false)
	var water_reduced := presenter._water_region_style(water, true)
	equal(water_normal.base, presenter._language.element_color("water", "base"), "active court Water uses canonical saturated blue")
	equal(water_normal.phase, water_reduced.phase, "reduced Water preserves authoritative phase")
	equal(water_normal.mark_count, 1, "normal Water guarantees one fitting ripple")
	equal(water_reduced.mark_count, 1, "reduced Water keeps one fitting identity ripple")
	check(float(water_reduced.fill_opacity) < float(water_normal.fill_opacity), "reduced Water lowers fill without dropping identity")
	check(not bool(water_reduced.motion) and bool(water_normal.motion), "reduced Water removes motion only")
	var fire := {"phase": "active", "danger": true, "intensity": 1000}
	var fire_normal := presenter._fire_region_style(fire, false)
	var fire_reduced := presenter._fire_region_style(fire, true)
	equal(fire_normal.edge, fire_normal.danger_color, "active harmful Fire uses its shared vivid danger edge")
	equal(fire_normal.phase, fire_reduced.phase, "reduced Fire preserves active phase")
	equal(fire_reduced.mark_count, 1, "reduced Fire retains one fitting phase glyph")
	var steam := {"phase": "active", "danger": true, "intensity": 1000}
	var hot_normal := presenter._steam_region_style(steam, 1500, false)
	var hot_reduced := presenter._steam_region_style(steam, 1500, true)
	equal(hot_normal.palette_phase, "hot", "active high-heat Steam selects the shared hot palette")
	equal(hot_reduced.palette_phase, "hot", "reduced Steam preserves the heat cue")
	equal(hot_normal.mark_count, 2, "normal Steam guarantees two fitting curls")
	equal(hot_reduced.mark_count, 2, "reduced Steam keeps two fitting curls")
	check(bool(hot_reduced.danger) and float(hot_reduced.danger_opacity) > 0.0, "reduced Steam retains the warm scald boundary")
	check(float(hot_reduced.fill_opacity) < float(hot_normal.fill_opacity), "reduced Steam remains transparent without losing its phase")
	var decaying := steam.duplicate()
	decaying.phase = "decaying"
	equal(presenter._steam_region_style(decaying, 1500, false).palette_phase, "decaying", "formation/decay authority is not overwritten by heat")


func _test_strength_scaled_projectile_size() -> void:
	var authored := 32.0
	var strengths := [15, 10, 7, 2]
	var sizes: Array[float] = []
	for remaining: int in strengths:
		sizes.append(Presenter.strength_scaled_size(authored, remaining, 15))
	for index: int in range(1, sizes.size()):
		check(sizes[index] < sizes[index - 1], "15 -> 10 -> 7 -> 2 strength produces a strictly shrinking Heavy silhouette")
	check(is_equal_approx(sizes[0], authored), "full strength retains authored family size")
	check(is_equal_approx(sizes[1], authored * sqrt(10.0 / 15.0)), "strength target uses authored size times square-root ratio")
	check(is_equal_approx(Presenter.strength_scaled_size(authored, 1, 1000), 5.0), "positive extreme loss retains only the five-pixel readable floor")
	check(is_zero_approx(Presenter.strength_scaled_size(authored, 0, 15)), "exhausted strength has no projectile body")
	check(is_equal_approx(Presenter.collision_radius_px(84_000), 84.0), "collision outline radius uses exact fixed-to-world conversion")


func _test_projectile_size_cache() -> void:
	var cache := {}
	var identity := "owner/team/cast/wire/element/initial/radius"
	var full := Presenter.cache_projectile_size(cache, 71, identity, 20, 0.0, 32.0, false)
	check(is_equal_approx(full, 32.0), "new projectile begins at its current target without a presentation-only grow-in")
	var weakened_target := Presenter.strength_scaled_size(32.0, 10, 15)
	var change_tick := Presenter.cache_projectile_size(cache, 71, identity, 19, 1.0, weakened_target, false)
	check(is_equal_approx(change_tick, 32.0), "strength change begins from the currently displayed same-shot size")
	var start_tick := float((cache[71] as Dictionary).start_tick)
	var next_tick := Presenter.cache_projectile_size(cache, 71, identity, 18, 2.0, weakened_target, false)
	check(is_equal_approx(float((cache[71] as Dictionary).start_tick), start_tick), "same-shot repeated draw does not restart its transition")
	check(next_tick < full and next_tick > weakened_target, "same-shot shrink advances monotonically between endpoints")
	var settled := Presenter.cache_projectile_size(cache, 71, identity, 13, 7.0, weakened_target, false)
	check(is_equal_approx(settled, weakened_target), "normal presentation reaches its new target within six simulation ticks")
	var immediate := Presenter.cache_projectile_size(cache, 71, identity, 12, 8.0, 7.0, true)
	check(is_equal_approx(immediate, 7.0), "reduced mode applies the strength target immediately")


func _test_projectile_cache_reuse_and_bound() -> void:
	var cache := {}
	Presenter.cache_projectile_size(cache, 5, "first-identity", 5, 10.0, 20.0, false)
	var changed_identity := Presenter.cache_projectile_size(cache, 5, "second-identity", 4, 11.0, 12.0, false)
	check(is_equal_approx(changed_identity, 12.0), "reused entity ID with new immutable identity resets instead of inheriting an old shrink")
	var renewed_lifetime := Presenter.cache_projectile_size(cache, 5, "second-identity", 30, 12.0, 18.0, false)
	check(is_equal_approx(renewed_lifetime, 18.0), "same identity with a lifetime increase is treated as ID reuse")
	cache.clear()
	for entity_id: int in range(1, 131):
		Presenter.cache_projectile_size(cache, entity_id, "identity-%d" % entity_id, 1000, float(entity_id), 16.0, false)
	equal(cache.size(), 128, "per-shot presentation cache stays at its hard 128-entry bound")
	check(cache.has(130), "cache eviction retains the shot currently being drawn")
	Presenter.prune_projectile_cache(cache, 10_000.0)
	check(cache.is_empty(), "cache prunes entries after their observed projectile lifetime expires")


func _test_projectile_helpers_do_not_mutate_state() -> void:
	var shot := ProjectileState.new(81, 2, 3, 203, 3, Vector2i(10_000, 20_000), Vector2i(30_000, 0), 84_000, 9000, 40)
	shot.source_cast_id = 901
	shot.initial_strength = 15
	shot.remaining_strength = 7
	var canonical_before := shot.canonical_values()
	var initial_before := shot.initial_strength
	var remaining_before := shot.remaining_strength
	var pair := Presenter.projectile_strength_pair(shot)
	var identity := Presenter.projectile_cache_identity(shot)
	var cache := {}
	Presenter.cache_projectile_size(cache, shot.entity_id, identity, shot.lifetime_ticks, 12.0, Presenter.strength_scaled_size(32.0, pair.y, pair.x), false)
	equal(shot.canonical_values(), canonical_before, "presentation size/cache helpers do not mutate canonical projectile state")
	equal(shot.initial_strength, initial_before, "presentation helpers do not mutate initial hex strength")
	equal(shot.remaining_strength, remaining_before, "presentation helpers do not mutate remaining hex strength")
