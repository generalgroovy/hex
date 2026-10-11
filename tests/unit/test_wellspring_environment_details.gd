extends FluxTestSuite

const Details = preload("res://src/presentation/wellspring_environment_details.gd")


func run() -> int:
	_test_compilation_and_readability()
	_test_cache_and_invalidation()
	return finish("wellspring-environment-details")


func _layout() -> SanctumCampusLayout:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "floor craft uses the actual admitted campus")
	return layout


func _test_compilation_and_readability() -> void:
	var layout := _layout()
	var before := CanonicalContent.sha256(layout.data)
	var details := Details.new()
	check(details.configure(layout), "floor craft compiles: " + details.last_error)
	check(details.marks.size() > 100 and details.marks.size() <= Details.MAX_MARKS, "authored route shoulders and destinations receive finite detail")
	check(details.patches.size() > 4 and details.patches.size() <= Details.MAX_PATCHES, "floor geometry is partitioned into a bounded world cache")
	check(details.vertex_count > 0 and details.vertex_count <= Details.MAX_VERTICES, "complete map mesh stays within its explicit vertex budget")
	var environments := {}
	var landmark_marks := 0
	var landmark_environments := {}
	for mark: Dictionary in details.marks:
		environments[String(mark.environment)] = true
		if String(mark.kind) == "route":
			check(float(mark.clear_half_width) >= Details.LANE_CLEAR_HALF_WIDTH, "wide route retains an empty center for feet, aim and spells")
		else:
			landmark_marks += 1
			landmark_environments[String(mark.environment)] = true
		for building: Dictionary in layout.data.get("buildings", []):
			check(not (mark.bounds as Rect2).intersects(Rect2(SanctumCampusLayout._parse_bounds(building.bounds)).grow(12.0), true), "flush detail avoids authored solid facade and approach margin")
		for landmark: Dictionary in layout.data.get("landmarks", []):
			var center := Vector2(SanctumCampusLayout._parse_point(landmark.position))
			var nearest := center.clamp(mark.bounds.position, (mark.bounds as Rect2).end)
			check(center.distance_to(nearest) >= Details.LANDMARK_CLEAR_RADIUS - 0.01, "actual travel destination remains an unadorned arrival pocket")
		for route: Dictionary in layout.data.get("routes", []):
			if String(route.get("kind", "")) != "ordinary": continue
			var points: Array = route.points
			for index: int in range(points.size() - 1):
				var a := Vector2(SanctumCampusLayout._parse_point(points[index]))
				var b := Vector2(SanctumCampusLayout._parse_point(points[index + 1]))
				# Independent nearest-point geometry covers cross-route shoulders
				# and landmark fronds; own-lane clearance cannot protect them.
				var point := Geometry2D.get_closest_point_to_segment(mark.anchor, a, b)
				var nearest := point.clamp(mark.bounds.position, (mark.bounds as Rect2).end)
				check(point.distance_to(nearest) >= Details.LANE_CLEAR_HALF_WIDTH - 0.01, "every ordinary route keeps its center clear through crossings and landmarks")
	check(landmark_marks >= 16, "distinct floor compositions frame the four outlying travel destinations")
	for environment: String in ["coast", "grove", "foundry", "observatory"]:
		check(landmark_environments.has(environment), "authored travel destination retains its distinct floor composition: " + environment)
	for environment: String in ["garden", "nexus", "proving", "coast", "grove", "foundry", "observatory"]:
		check(environments.has(environment), "floor craft covers district identity: " + environment)
	var vertices := 0
	for patch: Dictionary in details.patches:
		var mesh: ArrayMesh = patch.mesh
		equal(mesh.get_surface_count(), 1, "one persistent surface per visible patch avoids per-mark draw calls")
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		vertices += points.size()
		equal(points.size() % 3, 0, "mesh has only complete pre-triangulated primitives")
		equal(colors.size(), points.size(), "every floor vertex has a retained authored color")
		for point: Vector2 in points:
			check(point.is_finite() and (patch.bounds as Rect2).grow(0.01).has_point(point), "culling bounds include every finite triangle vertex")
		for color: Color in colors:
			check(color.a > 0 and color.a <= 0.52, "quiet floor craft stays below the actor/threat contrast tier")
	equal(vertices, details.vertex_count, "diagnostic vertex budget matches compiled render resources")
	var native_view := Rect2(128, 2720, 1707, 960)
	check(details.visible_patch_count(native_view) > 0 and details.visible_patch_count(native_view) < details.patches.size(), "native camera culls distant districts without rebuilding geometry")
	equal(details.visible_patch_count(Rect2(-4096, -4096, 128, 128)), 0, "off-world view submits no meshes")
	equal(details.visible_patch_count(Rect2()), details.patches.size(), "uncropped tooling capture retains the complete map")
	equal(CanonicalContent.sha256(layout.data), before, "map craft never changes collision, paid routes, travel or interaction authority")


func _test_cache_and_invalidation() -> void:
	var layout := _layout()
	var details := Details.new()
	check(details.configure(layout), "cache fixture compiles")
	var first_hash := details.content_hash
	var first_build := details.build_count
	var first_mesh: ArrayMesh = details.patches[0].mesh
	check(details.configure(layout), "identical actual data reuses floor craft")
	equal(details.build_count, first_build, "repeat configure performs no mesh construction")
	equal(details.patches[0].mesh, first_mesh, "persistent mesh lifetime survives a repeated configure")
	var route: Dictionary = (layout.data.routes as Array)[1]
	var points: Array = route.points
	(points[0] as Array)[0] = int((points[0] as Array)[0]) + 32
	check(details.configure(layout), "edited actual route recompiles independently of caller content_hash")
	check(details.content_hash != first_hash and details.build_count == first_build + 1, "real relevant source edits invalidate geometry")
	check(details.patches[0].mesh != first_mesh, "edited map obtains a new retained mesh cohort")
	details.clear()
	check(details.patches.is_empty() and details.marks.is_empty() and details.content_hash.is_empty(), "owner teardown releases all retained render resources")
	equal(details.vertex_count, 0, "teardown resets the geometry accounting")
	check(not details.configure(null), "unadmitted map fails without creating any render resources")
	check(Details.segment_crosses_rect(Vector2(-10, 0), Vector2(10, 0), Rect2(-1, -1, 2, 2)), "a lane crossing the whole mark is detected even with endpoints outside")
	check(not Details.segment_crosses_rect(Vector2(-10, 4), Vector2(10, 4), Rect2(-1, -1, 2, 2)), "a disjoint lane cannot discard unrelated floor detail")
