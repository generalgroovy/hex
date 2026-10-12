extends FluxTestSuite

const Effects = preload("res://src/presentation/pixel_spell_effects.gd")


func run() -> int:
	_test_material_geometry()
	_test_delivery_depth()
	_test_detached_templates()
	_test_live_submission_geometry()
	return finish("projectile-surface-depth")


func _test_material_geometry() -> void:
	for mask: int in range(1, 64):
		var original := Effects.mixture_sectors(mask, Vector2.ZERO, 18.0)
		var layout := Effects.mixture_layout(mask, Vector2.ZERO, 18.0)
		equal(layout.size(), original.size(), "lightweight hand and Mantle layout preserves all ingredient identities")
		for index: int in layout.size():
			for key: String in ["element", "start", "end", "glyph_anchor"]:
				equal(layout[index][key], original[index][key], "lightweight layout preserves existing glyph and arc placement")
			check(not layout[index].has("surface_points") and not layout[index].has("material_colors"), "glyph-only paths retain no unused material buffers")
		for center: Vector2 in [Vector2.ZERO, Vector2(19200.25, 15360.75)]:
			for radius: float in [0.5, 3.0, 8.999, 9.001, 18.0, 36.0]:
				var sectors := Effects.mixture_sectors(mask, center, radius)
				var area := 0.0
				for index: int in sectors.size():
					var sector: Dictionary = sectors[index]
					var points: PackedVector2Array = sector.surface_points
					var indices: PackedInt32Array = sector.indices
					var geometry_valid := points.size() == (sector.material_offsets as PackedVector2Array).size() \
						and points.size() == (sector.lighting as PackedFloat32Array).size() \
						and points.size() == (sector.material_colors as PackedColorArray).size()
					for point: Vector2 in points:
						geometry_valid = geometry_valid and point.is_finite() and point.distance_to(center) <= radius + 0.003
					for vertex: int in indices: geometry_valid = geometry_valid and vertex >= 0 and vertex < points.size()
					check(geometry_valid, "cached material triangles and shading stay inside their requested core at local and distant coordinates")
					if not geometry_valid: continue
					for triangle: int in range(0, indices.size(), 3):
						var a := points[indices[triangle]] - center
						var b := points[indices[triangle + 1]] - center
						var c := points[indices[triangle + 2]] - center
						area += absf((b - a).cross(c - a)) * 0.5
					equal(indices, original[index].indices, "moving and weakening a projectile never rebuilds or flips material topology")
					equal(sector.material_offsets, original[index].material_offsets, "material UV offsets cannot swim with world translation or changing strength")
					equal(sector.lighting, original[index].lighting, "core illumination has no time or position clock")
				check(area > PI * radius * radius * 0.95 and area <= PI * radius * radius * 1.008, "indexed sectors cover one bounded disk with no duplicated full-strength fill")
	var stats := Effects.material_geometry_stats()
	equal(stats.template_sets, 6, "all 63 mixtures and changing strengths retain exactly six immutable template sets")
	var single: Dictionary = Effects.mixture_sectors(1, Vector2.ZERO, 18.0)[0]
	var light: PackedFloat32Array = single.lighting
	check(light[20] > light[4] and light[light.size() - 1] > light[20], "raised material center and northwest rim catch light above the southeast rim")


func _test_delivery_depth() -> void:
	var config := SimConfig.new(120)
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "depth matrix reads all current paid spells")
	for mask: int in range(1, 64):
		for family: String in MixtureCatalog.FAMILIES:
			if family == "spray": continue
			var wire := MixtureCatalog.wire_for(mask, family)
			var definition := CombatTuning.cast_definition_view(wire)
			var shot := ProjectileState.new(1, 1, 1, wire, int(definition.element_wire_id), Vector2i(100000, 200000), Vector2i(200000, -100000), int(definition.radius), int(definition.damage), config.milliseconds_to_ticks(int(definition.lifetime_ms)))
			shot.initial_strength = int(definition.reaction_strength)
			shot.delivery_damage_remaining = shot.damage
			for strength: int in [shot.initial_strength, maxi(1, floori(float(shot.initial_strength) * 0.5)), 1]:
				shot.remaining_strength = strength
				var before := shot.canonical_values()
				var normal := {}
				for reduced: bool in [false, true]:
					var model := Effects.expanded_projectile_model(shot, definition, Vector2(100, 200), config, null, reduced)
					var depth := Effects.projectile_depth_model(model)
					if family == "mantle":
						check(depth.is_empty(), "owner-height Mantle retains its exact existing world projection")
						continue
					check(not depth.is_empty(), "every traveling mixture retains bounded depth in both effect modes")
					if depth.is_empty(): continue
					check(float(depth.lift) > 0.0 and float(depth.lift) <= 3.0, "inset painted body has a small steady elevation without changing physics")
					check((depth.center as Vector2).distance_to(model.center) + float(depth.radius) <= float(model.core_radius) + 0.0001, "entire raised body remains inside its original strength core")
					var shadow_bounded := true
					for point: Vector2 in depth.shadow: shadow_bounded = shadow_bounded and point.distance_to(model.center) < float(model.core_radius)
					check(shadow_bounded, "flattened ground shadow never advertises contact beyond the core")
					equal(model.radius, float(shot.radius) / SimConfig.FIXED_SCALE, "unchanged contact marks still describe the real immutable radius")
					equal(shot.canonical_values(), before, "depth cannot alter paid strength, travel, timer, collision or provenance")
					if reduced: equal(depth, normal, "reduced effects retains identical body depth without a pulse or oscillation")
					else: normal = depth
	for invalid: Dictionary in [{}, {"center": Vector2(INF, 0), "core_radius": 18.0}, {"center": Vector2.ZERO, "core_radius": NAN}, {"center": Vector2.ZERO, "core_radius": -1.0}]:
		check(Effects.projectile_depth_model(invalid).is_empty(), "invalid depth geometry is refused")


func _test_detached_templates() -> void:
	var expected := Effects.mixture_sectors(63, Vector2(7, 11), 18.0)
	var escaped := Effects.mixture_sectors(63, Vector2(7, 11), 18.0)
	escaped[0].points[0] = Vector2(999, 999)
	escaped[0].surface_points[0] = Vector2(999, 999)
	escaped[0].indices[0] = 999
	escaped[0].material_offsets[0] = Vector2(999, 999)
	escaped[0].lighting[0] = -99.0
	escaped[0].material_colors[0] = Color.TRANSPARENT
	equal(Effects.mixture_sectors(63, Vector2(7, 11), 18.0), expected, "returned geometry cannot poison shared templates or another spell's shading")
	var model := {"center": Vector2(7, 11), "core_radius": 18.0}
	var original := Effects.projectile_depth_model(model)
	var modified := Effects.projectile_depth_model(model)
	modified.shadow_indices[0] = 999
	modified.shadow[0] = Vector2(999, 999)
	equal(Effects.projectile_depth_model(model), original, "ground-shadow diagnostics never expose cached triangle ownership")


func _test_live_submission_geometry() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "live material submission uses the current validated palette")
	var source := Rect2(48, 72, 24, 24)
	var pivot := Vector2(12, 12)
	var texture_size := Vector2(192, 144)
	for mask: int in range(1, 64):
		var elements := Effects.mixture_elements(mask)
		var templates := Effects._templates_for(elements.size())
		var unchanged := var_to_bytes(templates)
		for center: Vector2 in [Vector2(7.25, 11.75), Vector2(19200.25, 15360.75)]:
			for radius: float in [0.5, 3.0, 9.0, 18.0, 36.0]:
				var diagnostic := Effects.mixture_sectors(mask, center, radius)
				for index: int in elements.size():
					var template: Dictionary = templates[index]
					var points := Effects._surface_points(template, center, radius)
					equal(points, diagnostic[index].surface_points, "live world vertices exactly match detached reference geometry for all63 mixtures")
					equal(template.indices, diagnostic[index].indices, "live submission retains exact independently validated triangle connectivity")
					check(points.size() == (33 if elements.size() == 1 else 14), "live buffers retain fixed authored tessellation regardless of speed, position or strength")
					var color := language.element_color(elements[index], "base")
					var colors := Effects._surface_colors(template, color)
					var uvs := Effects._material_uvs(template, source, pivot, texture_size)
					equal(colors.size(), points.size(), "every live vertex retains illumination")
					equal(uvs.size(), points.size(), "every live vertex retains its material coordinates")
					for vertex: int in points.size():
						var weight := float(diagnostic[index].lighting[vertex])
						var expected_color := Color(color.darkened(0.56).lerp(color.lightened(0.18), weight), 0.92)
						equal(colors[vertex], expected_color, "live body shading retains the previous exact color calculation")
						equal(uvs[vertex], (source.position + pivot + diagnostic[index].material_offsets[vertex]) / texture_size, "live UVs retain exact atlas crop without position or strength drift")
					# Mutating transient output must not mutate shared normalized templates.
					points[0] = Vector2.INF
					colors[0] = Color.TRANSPARENT
					uvs[0] = Vector2.INF
				var expected_depth := Effects.projectile_depth_model({"center": center, "core_radius": radius})
				equal(Effects._projectile_shadow_points(center, radius), expected_depth.shadow, "live flattened shadow retains detached depth-model geometry")
			equal(var_to_bytes(templates), unchanged, "drawing submissions and detached diagnostics cannot retain or mutate live paid state")
	check(int(Effects.material_geometry_stats().template_sets) <= 6, "the live fast path has only six geometry template sets, never position-keyed caches")
