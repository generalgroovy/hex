extends FluxTestSuite


const Facets = preload("res://src/presentation/hex_projectile_facets.gd")
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
var catalog := AbilityCatalog.new()


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "facet matrix uses live delivery definitions")
	if catalog.runtime_wire_ids.is_empty(): return finish("hex-projectile-facets")
	_test_matrix_bounds_and_identity()
	_test_direction_modes_and_authority()
	_test_invalid_and_detached()
	_test_spray_origin_bounds()
	_test_directional_surface()
	_test_production_seam()
	return finish("hex-projectile-facets")


func _definition(element: String, family: String) -> Dictionary:
	var ability := catalog.ability(catalog.spell_id_at(element, family))
	return CombatTuning.cast_definition(int(ability.get("wire_id", 0)))


func _test_matrix_bounds_and_identity() -> void:
	var cases := 0
	for family: String in ["rapid", "bolt", "heavy", "spray"]:
		for strength: Vector2i in [Vector2i(15,15), Vector2i(15,7), Vector2i(1000,1), Vector2i(15,0)]:
			var size := Presenter.strength_scaled_size(float(Presenter.FAMILY_SIZE[family]), strength.y, strength.x)
			for octant: int in 8:
				var direction := Vector2.from_angle(float(octant) * PI / 4.0)
				var identities := {}
				for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
					var definition := _definition(element, family)
					var before := var_to_bytes(definition)
					var wire := int(definition.element_wire_id)
					var radius := Presenter.collision_radius_px(int(definition.radius))
					var points := Facets.polygon(wire, direction, radius, size)
					cases += 1
					if strength.y == 0:
						check(points.is_empty(), "exhausted cores cannot retain a material icon")
						continue
					check(points.size() >= 3 and points.size() <= 11, "every active core has one connected simple silhouette, even at weakest Rapid")
					if points.is_empty(): continue
					identities[var_to_bytes(points).hex_encode()] = true
					var triangles := Geometry2D.triangulate_polygon(points)
					equal(triangles.size(), (points.size() - 2) * 3, "pixel-cut silhouette is a simple filled polygon without holes or crossed edges")
					var bounded := true
					for point: Vector2 in points:
						bounded = bounded and point.is_finite() and point.length() < radius and point.length() < size * 0.5
					check(bounded, "all elements and directions remain strictly inside physical disk and current strength core")
					equal(var_to_bytes(definition), before, "shape sampling never rewrites a compiled cast")
				if strength.y > 0: equal(identities.size(), 6, "all six live elements differ by geometry, not just RGB")
	equal(cases, 768, "six live elements by four families by eight directions by four strengths")


func _test_direction_modes_and_authority() -> void:
	for family: String in ["rapid", "bolt", "heavy", "spray"]:
		for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
			var definition := _definition(element, family)
			var ability := catalog.ability(catalog.spell_id_at(element, family))
			var shot := ProjectileState.new(91, 1, 1, int(ability.wire_id), int(definition.element_wire_id), Vector2i(400_000,400_000), Vector2i(200_000,-100_000), int(definition.radius), int(definition.damage), 40)
			shot.initial_strength = 15
			shot.remaining_strength = 1
			var before := shot.canonical_values()
			var pair := Presenter.projectile_strength_pair(shot)
			var full := float(Presenter.FAMILY_SIZE[family])
			var target := Presenter.strength_scaled_size(full, pair.y, pair.x)
			var cache := {}
			var identity := Presenter.projectile_cache_identity(shot)
			Presenter.cache_projectile_size(cache, shot.entity_id, identity, 41, 10.0, full, false)
			var normal_size := Presenter.cache_projectile_size(cache, shot.entity_id, identity, 40, 11.0, target, false)
			var reduced_size := Presenter.cache_projectile_size({}, shot.entity_id, identity, 40, 11.0, target, true)
			var direction := Presenter.ProjectileMotion.travel_direction(shot)
			var radius := Presenter.collision_radius_px(shot.radius)
			var normal := Facets.polygon(shot.element_wire_id, direction, radius, minf(normal_size, target))
			var reduced := Facets.polygon(shot.element_wire_id, direction, radius, minf(reduced_size, target))
			equal(normal, reduced, "normal/reduced retain identical elemental information while the old core shrinks")
			var unit := Facets.polygon(shot.element_wire_id, Vector2.RIGHT, radius, target)
			for index: int in unit.size():
				check(normal[index].is_equal_approx(unit[index].rotated(direction.angle())), "material silhouette follows true travel rather than adding a second snapped heading")
			equal(shot.canonical_values(), before, "facet reads leave canonical projectile authority untouched")
			equal(Vector2i(shot.initial_strength,shot.remaining_strength), pair, "facet cannot restore consumed matter strength")
	# Archived Ice primitive remains an isolated heading/geometry control; no live cast admission.
	for degrees: float in [22.4,22.6,67.4,67.6]:
		var direction := Vector2.from_angle(deg_to_rad(degrees))
		var shard := Facets.polygon(5,direction,12.0,24.0)
		check(shard[0].normalized().is_equal_approx(direction), "direction remains truthful either side of atlas octant boundaries")


func _test_invalid_and_detached() -> void:
	for element: int in [-1,0,9,999]:
		check(Facets.polygon(element,Vector2.RIGHT,12.0,24.0).is_empty(), "unknown elements do not borrow a material shape")
	for direction: Vector2 in [Vector2.ZERO,Vector2(INF,0),Vector2(0,NAN),Vector2(1.0e30,1.0e30)]:
		check(Facets.polygon(3,direction,12.0,24.0).is_empty(), "zero and nonfinite heading fail closed")
	for value: float in [-1.0,0.0,NAN,INF,-INF]:
		check(Facets.polygon(3,Vector2.RIGHT,value,24.0).is_empty(), "invalid physical radius fails closed")
		check(Facets.polygon(3,Vector2.RIGHT,12.0,value).is_empty(), "invalid current core size fails closed")
	check(Facets.polygon(3,Vector2.RIGHT,0.25,24.0).is_empty(), "subpixel physical disk never acquires an oversized readable icon")
	check(Facets.polygon(3,Vector2.RIGHT,12.0,0.25).is_empty(), "subpixel core never acquires an oversized readable icon")
	check(Facets.polygon(3,Vector2.RIGHT,1.0e300,1.0e300).is_empty(), "finite but unrepresentable geometry fails closed before drawing")
	check(not Facets.draw(null,Vector2.ZERO,Vector2.RIGHT,12.0,24.0,3,Color.WHITE), "missing canvas is unsupported")
	# All eight raw art primitives remain testable, including archived Ice and Charge.
	for element: int in range(1,9):
		var expected := Facets.polygon(element,Vector2.RIGHT,12.0,24.0)
		equal(Facets.polygon(element,Vector2(576_000,0),12.0,24.0), expected, "speed magnitude cannot enlarge the material")
		var escaped := Facets.polygon(element,Vector2.RIGHT,12.0,24.0)
		escaped[0] = Vector2(999,999)
		equal(Facets.polygon(element,Vector2.RIGHT,12.0,24.0), expected, "returned points never alias authored corners or future draws")


func _test_spray_origin_bounds() -> void:
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var definition := _definition(element,"spray")
		for octant: int in 8:
			var direction := Vector2.from_angle(float(octant) * PI / 4.0)
			for length: float in [8.0,40.0,280.0]:
				var start := Vector2(400.25,400.125)
				var cue := {"start":start,"end":start + direction * length,"range":int(length * 1000.0)}
				var geometry := Presenter._spray_cue_geometry(cue,definition)
				var before := var_to_bytes(geometry)
				var origin := Facets.spray_origin(geometry)
				if origin.is_empty():
					check(length == 8.0, "only tiny clipped origin envelopes omit the material mark")
					continue
				var points := Facets.polygon(int(definition.element_wire_id),origin.direction,origin.radius,origin.core_size)
				check(not points.is_empty(), "usable Spray origin keeps one material silhouette")
				var triangle := PackedVector2Array([start,geometry.brace[0],geometry.brace[1]])
				for point: Vector2 in points:
					check(Geometry2D.is_point_in_polygon(origin.position + point,triangle), "Spray material stays inside the old near-origin fan triangle, never adding reach")
				equal(var_to_bytes(geometry),before,"origin sampling preserves admitted endpoints, brace, range and cover clipping")
	for invalid: Dictionary in [{},{"start":Vector2.ZERO,"brace":PackedVector2Array([Vector2.ZERO,Vector2.ZERO])},{"start":Vector2(INF,0),"brace":PackedVector2Array([Vector2(4,1),Vector2(4,-1)])},{"start":Vector2.ZERO,"brace":[]},{"start":Vector2.ZERO,"brace":PackedVector2Array([Vector2(4,1)])}]:
		check(Facets.spray_origin(invalid).is_empty(),"invalid or fully blocked Spray cannot manufacture origin geometry")


func _test_directional_surface() -> void:
	var points := PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
	var source := Color(0.8, 0.6, 0.3, 0.42)
	var colors := Facets.surface_colors(points, source)
	equal(colors.size(), points.size(), "one shade per existing vertex adds depth without additional geometry")
	check(colors[0].get_luminance() > colors[2].get_luminance(), "northwest light and southeast shade agree with terrain relief")
	for color: Color in colors: equal(color.a, source.a, "directional shading never invents a pulse or increases cue opacity")
	var smaller := PackedVector2Array()
	for point: Vector2 in points: smaller.append(point * 0.25)
	var reduced := Facets.surface_colors(smaller, source)
	for index: int in colors.size(): check(colors[index].is_equal_approx(reduced[index]), "strength shrink preserves illumination without brightness popping")
	for invalid: PackedVector2Array in [PackedVector2Array(), PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2(INF, 0)])]:
		check(Facets.surface_colors(invalid, source).is_empty(), "invalid normals cannot reach per-vertex rendering")
	check(Facets.surface_colors(points, Color(NAN, 0, 0)).is_empty(), "nonfinite light fails closed")


func _test_production_seam() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/hex_projectile_facets.gd")
	equal(source.count("RenderingServer.canvas_item_add_triangle_array("),1,"one indexed silhouette supplies light and shade without extra draw layers")
	for forbidden: String in ["draw_arc(","draw_circle(","draw_line(","Image.create","ImageTexture.create","lifetime_ticks =","remaining_strength =","load_from_file("]:
		check(not source.contains(forbidden),"facets add no halo, outline, asset loading or gameplay mutation: " + forbidden)
	var presenter := FileAccess.get_file_as_string("res://src/presentation/hex_court_presenter.gd")
	check(presenter.contains("ProjectileFacets.draw(canvas, position, travel, collision_radius_px(radius_fixed), core_size"),"production projectile nose uses the bounded facet helper")
	check(presenter.contains("ProjectileFacets.spray_origin(geometry)"),"production Spray reuses its already admitted cover-aware origin envelope")
	check(presenter.contains("minf(size, target_size)"),"strength loss limits the facet immediately in both effects modes")
