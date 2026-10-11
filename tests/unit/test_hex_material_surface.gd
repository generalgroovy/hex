extends FluxTestSuite

const Surface = preload("res://src/presentation/hex_material_surface.gd")
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const Library = preload("res://src/presentation/pixel_magic_library.gd")


func run() -> int:
	_test_assets_and_phases()
	_test_exact_world_geometry()
	_test_detached_bounded_cache()
	_test_shifted_template_reuse()
	_test_resident_meshes()
	_test_fresh_style_fallback()
	_test_immutable_recipe_alias_reads()
	return finish("hex-material-surface")


func _test_assets_and_phases() -> void:
	var surface := Surface.new()
	var library := Library.default_library()
	check(surface.configure(library), "all 44 native material sequences prepare without changing the source pack")
	if surface.stats().textures == 0: return
	equal(surface.stats().sequences, 264, "all 44 identities have three phases and both modes")
	equal(surface.stats().textures, 660, "four normal poses plus one fixed reduced pose are prepared per phase")
	equal(surface.stats().texture_bytes, Surface.MAX_TEXTURE_BYTES, "bounded unmipped native 32px RGBA surface bank is 2.58 MiB")
	var seen := {}
	for wire: int in Surface._material_wires():
		for phase: String in ["forming", "active", "decaying"]:
			for reduced: bool in [false, true]:
				var normalized := "formation" if phase == "forming" else "decay" if phase == "decaying" else "active"
				var live := Presenter.RecipePolicy.definition(wire) if wire >= 301 else {}
				var alias := int(live.get("archive_recipe_wire", wire))
				var expected := Library.element_asset_id(wire, "deposit_" + normalized, reduced) if wire <= 8 else library.reaction_asset_id(alias, normalized, reduced)
				var info := surface.sample_info(wire, phase, 0.0, reduced)
				equal(info.get("asset_id", ""), expected, "surface samples the actual element/reaction phase asset")
				equal(info.get("size"), Vector2i(32, 32), "art remains native 32px rather than stretching to the hex bounds")
				seen[expected] = true
				if reduced or phase != "active":
					equal(surface.sample_info(wire, phase, 999_999.0, reduced), info, "reduced/preparatory/terminal art is stationary until authority changes phase")
				else:
					var asset := library.asset(expected)
					for index: int in 4:
						var tick := 0 if index == 0 else int(asset.frame_ends[index - 1])
						equal(surface.sample_info(wire, phase, float(tick), false).frame, index, "active cosmetic material keeps the authored pose durations")
					equal(surface.sample_info(wire, phase, float(asset.total_ticks), false).frame, 0, "active material loops in place without moving occupied geometry")
	equal(surface._frames.size(), 264, "all original archive sequences remain resident despite live aliases")
	for wire: int in Presenter.RecipePolicy.active_wire_ids():
		var definition := Presenter.RecipePolicy.definition(wire)
		for phase: String in ["forming", "active", "decaying"]:
			for reduced: bool in [false, true]:
				var normalized := "formation" if phase == "forming" else "decay" if phase == "decaying" else "active"
				equal(surface.sample_info(wire, phase, 0.0, reduced).asset_id, library.reaction_asset_id(int(definition.archive_recipe_wire), normalized, reduced), "all 63 live recipes use their declared archived art")
	equal(surface.stats().textures, 660, "63 live recipe lookups allocate no new art textures")
	equal(surface.sample_info(2, "ignition", 0.0, false).asset_id, "magic.fire.deposit_formation.normal", "Fire ignition selects preparatory pixels")
	equal(surface.sample_info(2, "cooling", 0.0, false).asset_id, "magic.fire.deposit_decay.normal", "Fire cooling selects terminal pixels")
	for bad_phase: String in ["", "expired", "missing", "hot"]:
		check(surface.sample_info(2, bad_phase, 0.0, false).is_empty(), "unknown/dead phase cannot fabricate a live surface")
	for bad_wire: int in [0, 9, 300, 337]:
		check(surface.sample_info(bad_wire, "active", 0.0, false).is_empty(), "unknown identity uses caller's safe fallback")
	for tick: float in [-1.0, INF, NAN]:
		check(surface.sample_info(2, "active", tick, false).is_empty(), "invalid clock cannot select a surface")
	var second := Surface.new()
	check(second.configure(library), "second presenter reuses the bounded shared bank")
	check(surface._frames == second._frames, "setup reuses prepared texture resources")
	var canvas := Node2D.new()
	var polygon := _polygon(Vector2i.ZERO)
	var before := surface.stats()
	for index: int in 36:
		check(surface.draw_region(canvas, 6, polygon, "active", float(index), index % 2 == 0, 0.72), "warm surface submits native triangles")
	var after := surface.stats()
	equal(after.textures, before.textures, "warm draws allocate no additional ImageTextures")
	equal(after.geometry_builds, int(before.geometry_builds) + 1, "one exact hex geometry is reused across frames, materials and effect modes")
	equal(after.translated_draws, 36, "submission count is separate from shared template construction")
	equal(after.mesh_uploads, 1, "warm draws upload the exact normalized mesh only once")
	equal(after.mesh_hits, 35, "animation and Reduced frames reuse the same resident mesh")
	canvas.free()
	check(not second.configure(Library.new()), "missing native pack fails safely")
	check(second.sample_info(6, "active", 0.0, false).is_empty(), "failed setup cannot expose the preceding bank")
	equal(second.stats().geometry_entries, 0, "failed setup clears previous geometry")


func _test_exact_world_geometry() -> void:
	var surface := Surface.new()
	for shift: Vector2 in [Vector2.ZERO, Vector2(-47.0, 19.0), Vector2(7999.0, -7999.0)]:
		for cell: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-2, -3)]:
			var polygon := _polygon(cell, shift)
			for reverse: bool in [false, true]:
				if reverse: polygon.reverse()
				var original := polygon.duplicate()
				var geometry := surface.geometry_for_polygon(polygon)
				check(not geometry.is_empty(), "real hex in either winding has bounded exact material coverage")
				if geometry.is_empty(): continue
				equal(polygon, original, "preparation never changes caller-owned authority geometry")
				check(geometry.pieces >= 1 and geometry.pieces <= Surface.MAX_PIECES, "world grid intersection has bounded pieces")
				var points: PackedVector2Array = geometry.points
				var uvs: PackedVector2Array = geometry.uvs
				var indices: PackedInt32Array = geometry.indices
				equal(points.size(), uvs.size(), "one UV accompanies every native triangle point")
				check(points.size() <= Surface.MAX_VERTICES and indices.size() <= Surface.MAX_INDICES, "single command has fixed vertex/index bounds")
				var area := 0.0
				for offset: int in range(0, indices.size(), 3):
					var a: Vector2 = points[indices[offset]]
					var b: Vector2 = points[indices[offset + 1]]
					var c: Vector2 = points[indices[offset + 2]]
					area += absf((b - a).cross(c - a)) * 0.5
					check(_inside_or_edge((a + b + c) / 3.0, polygon), "every submitted triangle stays in its authoritative hex")
					for corner: int in range(offset, offset + 3):
						var point: Vector2 = points[indices[corner]]
						var uv: Vector2 = uvs[indices[corner]]
						check(_inside_or_edge(point, polygon), "no submitted vertex escapes exact selected membership")
						check(uv.x >= -0.0001 and uv.y >= -0.0001 and uv.x <= 1.0001 and uv.y <= 1.0001, "tile pieces never require CanvasItem texture-repeat state")
						var origin := point - uv * Surface.TILE_SIZE
						check(origin.distance_to((origin / Surface.TILE_SIZE).round() * Surface.TILE_SIZE) < 0.002, "UVs resolve a common world 32px grid across neighboring cells and negative coordinates")
				check(absf(area - _area(polygon)) < 0.03, "combined clipped triangles cover the whole hex once without gaps or double fill")
	# A new geometry, not an old cell center, controls the clip on each call.
	var full := _polygon(Vector2i.ZERO)
	var small := PackedVector2Array()
	for point: Vector2 in full: small.append(point * 0.4)
	check(_geometry_area(surface.geometry_for_polygon(small)) < _geometry_area(surface.geometry_for_polygon(full)) * 0.17, "pressure decay inner mask stays tiny and cannot reuse full active coverage")
	for invalid: PackedVector2Array in [PackedVector2Array(), PackedVector2Array([Vector2.ZERO, Vector2.ONE]), PackedVector2Array([Vector2(INF, 0), Vector2.ZERO, Vector2.ONE, Vector2.UP, Vector2.LEFT, Vector2.DOWN])]:
		check(surface.geometry_for_polygon(invalid).is_empty(), "invalid geometry fails closed")
	var huge := full.duplicate()
	for index: int in huge.size(): huge[index] *= 1000.0
	check(surface.geometry_for_polygon(huge).is_empty(), "diagnostic polygons cannot cause unbounded tiling work")


func _test_detached_bounded_cache() -> void:
	var surface := Surface.new()
	var original := _polygon(Vector2i.ZERO)
	var saved := surface.geometry_for_polygon(original)
	var expected: PackedVector2Array = saved.points.duplicate()
	saved.points[0] += Vector2(200, 200)
	saved.uvs[0] = Vector2(9, 9)
	saved.indices[0] = 999
	equal(surface.geometry_for_polygon(original).points, expected, "diagnostic returned points cannot poison later rendering")
	check(surface.geometry_for_polygon(original).uvs[0] != Vector2(9, 9), "diagnostic UVs are detached too")
	check(surface.geometry_for_polygon(original).indices[0] != 999, "diagnostic indices are detached too")
	original[0] += Vector2(0.25, 0.125)
	check(surface.geometry_for_polygon(original).points != expected, "public mutation uses exact fresh points, not an invalidation assumption")
	for index: int in Surface.GEOMETRY_LIMIT + 17:
		var distinct := _polygon(Vector2i.ZERO, Vector2(float(index) / 256.0, 4.125))
		check(not surface.geometry_for_polygon(distinct).is_empty(), "cache traversal admits exact fractional grid phases")
		check(surface.stats().geometry_entries <= Surface.GEOMETRY_LIMIT, "travel cannot grow persistent geometry storage")
	equal(surface.stats().geometry_entries, Surface.GEOMETRY_LIMIT, "more than 512 genuinely different local shapes exercise bounded eviction")
	equal(surface.geometry_for_polygon(_polygon(Vector2i.ZERO)).points, expected, "evicted first hex rebuilds the same exact sampling geometry")


func _test_shifted_template_reuse() -> void:
	var surface := Surface.new()
	var board: Array[PackedVector2Array] = []
	# The native stress fixture's actual 28-by-24 axial board has 672 absolute cells,
	# but columns repeat exact local shape/world-UV phases within each row.
	for row: int in 24:
		for column: int in 28:
			var polygon := _polygon(Vector2i(column, row))
			board.append(polygon)
			check(not surface.geometry_for_polygon(polygon).is_empty(), "cold 672-cell board has valid material geometry")
	var cold := surface.stats()
	check(cold.template_builds < Surface.GEOMETRY_LIMIT, "all exact stressboard templates fit the original 512-entry bound")
	for pass_index: int in 3:
		for polygon: PackedVector2Array in board:
			var geometry := surface.geometry_for_polygon(polygon)
			check(absf(_geometry_area(geometry) - _area(polygon)) < 0.03, "warm template still covers the exact requested world hex once")
	var warm := surface.stats()
	equal(warm.template_builds, cold.template_builds, "a board larger than 512 absolute cells performs zero further warm clipping builds")
	equal(warm.template_hits - cold.template_hits, 672 * 3, "all warm stressboard requests hit reusable local templates")
	equal(warm.translated_draws, 0, "geometry diagnostics do not claim actual rendering submissions")
	# More than 512 translated copies with fractional local geometry must reuse
	# one exact template, not cached whole-world points or rounded shape keys.
	var copies := Surface.new()
	var base := _polygon(Vector2i.ZERO, Vector2(0.125, 0.375))
	var reference := copies.geometry_for_polygon(base)
	for index: int in 673:
		var translation := Vector2((index - 336) * 32, 0)
		var moved := PackedVector2Array()
		for point: Vector2 in base: moved.append(point + translation)
		var actual := copies.geometry_for_polygon(moved)
		equal(actual.indices, reference.indices, "integer tile translation preserves the exact local triangulation")
		equal(actual.uvs, reference.uvs, "integer tile translation preserves exact native pixel sampling")
		equal(actual.points.size(), reference.points.size(), "translation neither grows nor omits geometry")
		for vertex: int in actual.points.size():
			check(actual.points[vertex].distance_to(reference.points[vertex] + translation) < 0.002, "negative/distant translated points equal their local template plus exact tile offset")
	equal(copies.stats().template_builds, 1, "673 translated fractional shapes never churn the cache")
	# Independently clip world-space source polygons rather than invoking the
	# candidate's template builder as an oracle; tolerate only subpixel rounding.
	for shift: Vector2 in [Vector2.ZERO, Vector2(-96.125, 63.375), Vector2(7999.125, -7999.375)]:
		var polygon := _polygon(Vector2i(3, -2), shift)
		var actual := surface.geometry_for_polygon(polygon)
		var expected := _uncached_world_geometry(polygon)
		check(absf(_geometry_area(actual) - _geometry_area(expected)) < 0.03, "local-template area agrees with independent world-space clipping")
		for vertex: int in actual.points.size():
			var point: Vector2 = actual.points[vertex]
			var uv: Vector2 = actual.uvs[vertex]
			check(_inside_or_edge(point, polygon), "translated triangles cannot escape negative/distant/fractional source boundaries")
			var matched := false
			for other: int in expected.points.size():
				if point.distance_to(expected.points[other]) < 0.002 and uv.distance_to(expected.uvs[other]) < 0.0001:
					matched = true
					break
			check(matched, "translated point and UV agree with independent direct world clipping")


func _test_resident_meshes() -> void:
	var surface := Surface.new()
	check(surface.configure(), "resident mesh fixture prepares the real native material bank")
	var canvas := Node2D.new()
	var base := _polygon(Vector2i.ZERO, Vector2(0.125, 0.375))
	var local: Dictionary = Surface._local_placement(base)
	var expected := surface.geometry_for_polygon(base)
	check(surface.draw_region(canvas, 6, base, "active", 0.0, false, 0.82), "first native draw admits a bounded resident mesh")
	check(surface._meshes.has(local.polygon), "mesh is retained under a detached exact local-shape key")
	if not surface._meshes.has(local.polygon):
		canvas.free()
		return
	var resident: WeakRef = weakref(surface._meshes[local.polygon])
	var resource_id: int = resident.get_ref().get_instance_id()
	var arrays: Array = (resident.get_ref() as ArrayMesh).surface_get_arrays(0)
	equal(arrays[Mesh.ARRAY_INDEX], expected.indices, "uploaded mesh retains the exact triangle index order")
	equal(arrays[Mesh.ARRAY_TEX_UV], expected.uvs, "uploaded mesh retains exact native UVs without attribute compression")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	equal(vertices.size(), expected.points.size(), "resident mesh contains every exact clipped vertex")
	for index: int in vertices.size():
		equal(vertices[index].z, 0.0, "2D material mesh introduces no depth")
		check((Vector2(vertices[index].x, vertices[index].y) + Vector2(local.origin)).distance_to(expected.points[index]) < 0.0001, "per-call translation reconstructs the original world geometry")
	var cold := surface.stats()
	for index: int in 24:
		var moved := PackedVector2Array()
		for point: Vector2 in base: moved.append(point + Vector2((index - 12) * 32, 0))
		check(surface.draw_region(canvas, 3 if index % 2 == 0 else 6, moved, "active", float(index), index % 2 == 0, 0.64), "material, frame, mode and world translation share one resident mesh")
	equal(surface.stats().mesh_uploads, cold.mesh_uploads, "warm translated draws never upload another mesh")
	equal(surface.stats().template_builds, cold.template_builds, "resident draws also bypass repeat clipping")
	equal(surface.stats().mesh_hits - cold.mesh_hits, 24, "resident hits count actual mesh reuse separately")
	equal(surface.stats().translated_draws, 25, "all mesh submissions are included in translated draw statistics")
	# Fill beyond capacity with genuinely different fractional local shapes.
	# Earlier submitted meshes must remain alive even if their CPU template is
	# evicted; uncached overflow uses the existing exact triangle-array fallback.
	for index: int in Surface.MESH_LIMIT + 17:
		var polygon := _polygon(Vector2i.ZERO, Vector2(float(index) / 256.0, 4.125))
		check(surface.draw_region(canvas, 6, polygon, "active", 12.0, false, 0.82), "overflow keeps drawing every selected polygon")
		check(surface.stats().mesh_entries <= Surface.MESH_LIMIT, "resident mesh storage never exceeds 512 resources")
	var full := surface.stats()
	equal(full.mesh_entries, Surface.MESH_LIMIT, "resident capacity is fixed and independent of template FIFO")
	equal(full.mesh_uploads, Surface.MESH_LIMIT, "overflow cannot upload and evict additional meshes")
	equal(full.triangle_fallback_draws, 18, "only the 18 shapes beyond available resident slots use triangle fallback")
	check(resident.get_ref() != null and surface._meshes.has(local.polygon), "first submitted resource survives cache pressure until rendering consumes it")
	equal(resident.get_ref().get_instance_id(), resource_id, "resident mesh is not silently rebuilt during template eviction")
	check(surface.draw_region(canvas, 6, base, "active", 24.0, true, 0.64), "original mesh remains available after overflow")
	equal(surface.stats().mesh_uploads, Surface.MESH_LIMIT, "returning to resident geometry performs no upload")
	equal(surface.stats().triangle_fallback_draws, full.triangle_fallback_draws, "returning resident uses its mesh even after template eviction")
	var detached := surface.geometry_for_polygon(base)
	detached.points[0] += Vector2(500, 500)
	detached.uvs[0] = Vector2(99, 99)
	detached.indices[0] = 999
	var intact: Array = (resident.get_ref() as ArrayMesh).surface_get_arrays(0)
	equal(intact[Mesh.ARRAY_INDEX], expected.indices, "diagnostic copy mutation cannot alter resident topology")
	equal(intact[Mesh.ARRAY_TEX_UV], expected.uvs, "diagnostic copy mutation cannot alter resident sampling")
	check(Surface.MAX_MESH_DATA_BYTES == 1_363_968, "mesh vertex/UV/index payload has an explicit 1.31 MiB ceiling excluding resource/driver overhead")
	canvas.free() # Clear the retained commands before setup resets mesh residency.
	check(not surface.configure(Library.new()), "failed reconfiguration clears the bounded resident bank too")
	equal(surface.stats().mesh_entries, 0, "mesh resources are released at explicit setup reset")
	equal(surface.stats().mesh_uploads, 0, "mesh counters reset with setup")
	check(resident.get_ref() == null, "no test-only reference or cache retains a reset resident mesh")


func _test_fresh_style_fallback() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "surface style fixture loads the actual shared language")
	var presenter := Presenter.new()
	check(presenter.configure(language), "material surface integrates without changing presentation configuration")
	var canvas := Node2D.new()
	for material: String in Presenter.MATERIALS:
		for phase: String in ["forming", "active", "decaying"]:
			var source := {"phase": phase, "danger": phase == "active", "intensity": 1000, "polygon": _polygon(Vector2i.ZERO)}
			var candidate: Dictionary
			if material == "water": candidate = presenter._water_region_style(source, false)
			elif material == "fire": candidate = presenter._fire_region_style(source, false)
			elif material == "steam": candidate = presenter._steam_region_style(source, 1000, false)
			elif material == "conflagration":
				candidate = {"phase": phase, "dark": language.reaction_color(material, "dark"), "base": language.reaction_color(material, "base"), "bright": language.reaction_color(material, "bright")}
			else: candidate = presenter._shared_material_style(material, source, false)
			for reduced: bool in [false, true]:
				var needs_centered_mark := String(candidate.get("visual_material", material)) in Presenter.COMBAT_PHASE_MATERIALS and phase != "active"
				var needs_material_silhouette := material in ["steam", "conflagration"]
				equal(presenter._draw_material_surface(canvas, material, source, candidate, 24.0, reduced), not (needs_centered_mark or needs_material_silhouette), "native surface selection preserves pressure phase marks and sole Steam/Conflagration vapor/flame silhouettes")
				if needs_centered_mark:
					check(candidate.mark_scale > 0.0 and candidate.mark_scale < 1.0, "pressure fallback retains the existing bounded visible phase mark in both modes")
	canvas.free()
	var region := {"phase": "active", "danger": false, "intensity": 1000, "polygon": _polygon(Vector2i.ZERO)}
	var style := presenter._shared_material_style("light", region, false)
	check(presenter._surface_palette_matches("light", style), "canonical native Light palette is admitted")
	region.intensity = 400
	region.danger = true
	var weaker := presenter._shared_material_style("light", region, false)
	check(float(weaker.fill_opacity) < float(style.fill_opacity) and weaker.edge != style.edge, "intensity and danger styles still read fresh authority")
	check(presenter._surface_palette_matches("light", weaker), "no intensity/danger authority is frozen in the static asset guard")
	language.elements.light.base = "#123456"
	check(not presenter._surface_palette_matches("light", presenter._shared_material_style("light", region, false)), "direct live palette edit immediately selects freshly colored fallback")
	var custom := Presenter.new()
	check(custom.configure(language), "custom palette still supports established presentation")
	check(not custom._surface_palette_matches("light", custom._shared_material_style("light", region, false)), "noncanonical palette supplied before configure cannot admit stale native RGB")
	for material: String in Presenter.PRODUCT_MATERIALS:
		if String(presenter._material_descriptor(material).visual_material) not in Presenter.COMBAT_PHASE_MATERIALS: continue
		var forming := presenter._shared_material_style(material, {"phase": "forming", "intensity": 1000, "danger": false}, false)
		var active := presenter._shared_material_style(material, {"phase": "active", "intensity": 1000, "danger": true}, false)
		var decay := presenter._shared_material_style(material, {"phase": "decaying", "intensity": 1000, "danger": false}, true)
		check(float(forming.mark_scale) < float(active.mark_scale) and float(decay.mark_scale) < float(forming.mark_scale), "existing pressure warning/active/decay size distinction is unchanged")
		check(float(decay.edge_opacity) < float(active.edge_opacity), "Reduced retains harmless terminal contrast")
	var steam := presenter._steam_region_style({"phase": "active", "intensity": 1000, "danger": true}, 1500, true)
	equal(steam.palette_phase, "hot", "fresh Steam heat keeps its authored palette phase")
	check(not Presenter.steam_vent_marks(region.polygon, true, "active").is_empty(), "essential scald shape is independent of surface decoration")
	check(not Presenter._earth_pillar_geometry(region.polygon, 5.0).is_empty(), "physical cover geometry remains separate from the material surface")
	check(not presenter.configure(null), "failed presenter reconfiguration refuses drawing")
	check(not presenter._surface_palette_matches("light", style), "failed reconfiguration cannot preserve old surface admission")


static func _polygon(cell: Vector2i, shift: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2i in Grid.vertices(cell): result.append(Vector2(point) / 1000.0 + shift)
	return result


static func _inside_or_edge(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon): return true
	for index: int in polygon.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])) < 0.002: return true
	return false


static func _area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index: int in range(1, polygon.size() - 1): area += absf((polygon[index] - polygon[0]).cross(polygon[index + 1] - polygon[0])) * 0.5
	return area


static func _geometry_area(geometry: Dictionary) -> float:
	var result := 0.0
	var points: PackedVector2Array = geometry.points
	var indices: PackedInt32Array = geometry.indices
	for index: int in range(0, indices.size(), 3): result += absf((points[indices[index + 1]] - points[indices[index]]).cross(points[indices[index + 2]] - points[indices[index]])) * 0.5
	return result


static func _uncached_world_geometry(polygon: PackedVector2Array) -> Dictionary:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon: bounds = bounds.expand(point)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y: int in range(floori(bounds.position.y / 32.0), ceili(bounds.end.y / 32.0)):
		for x: int in range(floori(bounds.position.x / 32.0), ceili(bounds.end.x / 32.0)):
			var origin := Vector2(x * 32, y * 32)
			var square := PackedVector2Array([origin, origin + Vector2(32, 0), origin + Vector2(32, 32), origin + Vector2(0, 32)])
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon, square):
				var local := PackedVector2Array()
				for point: Vector2 in clipped: local.append(point - clipped[0])
				var triangles := Geometry2D.triangulate_polygon(local)
				if triangles.is_empty(): continue
				var offset := points.size()
				for point: Vector2 in clipped:
					points.append(point)
					uvs.append((point - origin) / 32.0)
				for index: int in triangles: indices.append(offset + index)
	return {"points": points, "uvs": uvs, "indices": indices}


func _test_immutable_recipe_alias_reads() -> void:
	var surface := Surface.new()
	check(surface.configure(), "immutable lookup probe reuses the real native surface bank")
	for wire: int in Presenter.RecipePolicy.ACTIVE_RECIPE_WIRES:
		var runtime: Dictionary = Presenter.RecipePolicy.runtime_definition(wire)
		check(runtime.is_read_only(), "every live recipe lookup is an immutable shared contract")
		var authored: Dictionary = Presenter.RecipePolicy.definition(wire)
		var expected := surface.sample_info(wire,"active",12.5,false)
		check(not expected.is_empty(), "every live recipe keeps its declared actual art identity")
		authored.archive_recipe_wire = 999999
		authored.visual_material = "invalid"
		for unused: int in 4:
			equal(surface.sample_info(wire,"active",12.5,false),expected,"mutable public definition cannot poison shared surface selection")
		equal(Presenter.RecipePolicy.runtime_definition(wire).archive_recipe_wire,runtime.archive_recipe_wire,"art reads do not mutate shared recipe metadata")
		var detached := expected.duplicate(true)
		detached.asset_id = "invalid"
		equal(surface.sample_info(wire,"active",12.5,false),expected,"public surface diagnostics remain detached")
	equal(surface.stats().textures,660,"repeated63-recipe lookups keep the unchanged bounded art bank")
