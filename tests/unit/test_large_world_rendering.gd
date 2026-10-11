extends FluxTestSuite

const Terrain = preload("res://src/presentation/hex_environment_layout.gd")
const District = preload("res://src/presentation/wellspring_district_style.gd")
const Backdrop = preload("res://src/presentation/pov_terrain_backdrop.gd")

# Isolate cache replacement from artwork preparation. The region equivalence
# tests below independently exercise the real native pixel compositor.
class RegionProbe:
	extends RefCounted
	var calls: Array[Rect2i] = []
	var last_error := ""
	func compose_region(region: Rect2i, _classify: Callable, _style: RefCounted, _finish: Callable, _sources: Dictionary) -> Image:
		calls.append(region)
		var result := Image.create(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
		result.fill(Color(float(posmod(region.position.x / 512, 12)) / 12.0, 0.25, 0.5))
		return result


# Isolate capture revision semantics from asynchronous disk preparation.
class ReadyRenderer:
	extends SanctumCampusRenderer
	var prepared := true
	func terrain_ready_for(_visible: Rect2) -> bool:
		return prepared


# Exact pre-broadphase algorithms copied from the preserved before-source.
# Independent oracle: it reparses every original area/district and visits all
# original route segments in order; it never calls the optimized sampler.
class PreBroadphaseSampler:
	extends RefCounted
	const HexTerrain = preload("res://src/presentation/hex_environment_layout.gd")
	const COMMONS_FLOOR := Rect2(1148, 568, 776, 568)
	const FLOOR_INSET := 24.0
	const FLOOR_RIBBON_HALF_WIDTH := 24.0
	var data: Dictionary
	var campus: SanctumCampusLayout
	var paths: Array[Dictionary]
	func _init(kit: RefCounted) -> void:
		data = kit.data
		campus = kit.campus
		paths = kit.paths

	func surface_at(point: Vector2) -> int:
		# One material per canonical chemistry hex. Input routes remain authority;
		# presentation rounds only their visual edge, not their walkable clearance.
		var cell := HexTerrain.cell_at(point)
		point = HexTerrain.center_pixels(cell)
		var seed := absi(cell.x * 173 + cell.y * 389 + int(data["terrain"]["seed"]))
		# Retain the authored64/128px shore margins inside the current map envelope.
		# Resizing the campus must not paint playable annex routes as water. This
		# classification grants no water collision or material-assisted movement.
		var land := Rect2(64, 128, campus.canvas_size.x - 128, campus.canvas_size.y - 224)
		if not land.has_point(point):
			return 8
		var edge := minf(minf(point.x - land.position.x, land.end.x - point.x), minf(point.y - land.position.y, land.end.y - point.y))
		if edge < 28 + (seed % 3) * 8:
			return 14 if edge > 14 else 8
		if COMMONS_FLOOR.has_point(point):
			return 0
		# Reuse the existing autotiles for bounded practice rooms, not decorative
		# objects with fictitious collision. Grass insets keep the cover garden
		# distinct from the open experiment floor and compact chain courtyard.
		for area: Dictionary in campus.data.get("activity_areas", []):
			var room := Rect2(SanctumCampusLayout._parse_bounds(area["bounds"]))
			if not room.grow(-16).has_point(point):
				continue
			match String(area["id"]):
				"chain-courtyard":
					return 0
				"open-laboratory":
					return 1 if room.grow(-48).has_point(point) else 0
				"cover-garden":
					var inset := point - room.position
					if int(inset.x) % 224 < 64 and int(inset.y) % 192 < 64:
						return 4
					return 0
		for area: Dictionary in campus.data.get("activity_areas", []):
			if String(area["id"]) in ["pattern-range", "duel-court", "crucible"] and Rect2(SanctumCampusLayout._parse_bounds(area["bounds"])).grow(-16).has_point(point):
				return 2 if String(area["id"]) == "crucible" else 0
		for route: Dictionary in paths:
			var points: PackedVector2Array = route["points"]
			for index: int in range(points.size() - 1):
				var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1]))
				if distance <= float(route["width"]) * 0.5:
					return 13 if bool(route["advanced"]) else (2 if distance > float(route["width"]) * 0.5 - 18 else 1)
		for district: Dictionary in campus.data.get("districts", []):
			if not Rect2(SanctumCampusLayout._parse_bounds(district["bounds"])).has_point(point): continue
			match String(district.get("environment", "")):
				"coast", "observatory": return 0
				"foundry": return 6
		return 5 if seed % 5 == 0 else 4

	func floor_finish_at(point: Vector2, material: String) -> int:
		# Called only while composing the cached floor. Preserve surface_at's family
		# and the actual lattice: no geometry, obstacle or chemistry material changes.
		point = HexTerrain.center_pixels(HexTerrain.cell_at(point))
		if material not in ["paving", "earth"]:
			return HexTerrain.Finish.ORIGINAL
		# Only broad ordinary circulation gets a ribbon. Narrow wall/chain/cover
		# drills and the sparring zigzag retain their own existing floor language.
		# Crossings take precedence so the flat inset never closes a real entrance.
		for route: Dictionary in paths:
			if bool(route["advanced"]) or float(route["width"]) < 160.0:
				continue
			var points: PackedVector2Array = route["points"]
			for index: int in range(points.size() - 1):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])) <= FLOOR_RIBBON_HALF_WIDTH:
					return HexTerrain.Finish.ROUTE
		if material != "paving":
			return HexTerrain.Finish.ORIGINAL
		for area: Dictionary in campus.data.get("activity_areas", []):
			var finish: int = HexTerrain.Finish.ORIGINAL
			match String(area["id"]):
				"source-court": finish = HexTerrain.Finish.COMMONS
				"crucible": finish = HexTerrain.Finish.CHEMISTRY
				"duel-court": finish = HexTerrain.Finish.DUEL
				"chain-courtyard": finish = HexTerrain.Finish.CHAIN
				_: continue
			var room := Rect2(SanctumCampusLayout._parse_bounds(area["bounds"]))
			if finish == HexTerrain.Finish.COMMONS:
				room = room.intersection(COMMONS_FLOOR)
			if not room.grow(-FLOOR_INSET).has_point(point):
				continue
			return finish if room.grow(-2.0 * FLOOR_INSET).has_point(point) else HexTerrain.Finish.INSET
		for district: Dictionary in campus.data.get("districts", []):
			if not Rect2(SanctumCampusLayout._parse_bounds(district["bounds"])).has_point(point): continue
			if String(district.get("environment", "")) == "coast": return HexTerrain.Finish.DUEL
			if String(district.get("environment", "")) == "observatory": return HexTerrain.Finish.COMMONS
		return HexTerrain.Finish.ORIGINAL


func run() -> int:
	_test_region_pixels()
	_test_region_cache()
	_test_region_sampler_equivalence()
	_test_wayfinding_and_culling()
	_test_view_relative_backdrop()
	return finish("large-world-rendering")


func _test_region_pixels() -> void:
	var style := WellspringIllustratedKit.GroundStyle.new()
	check(style.configure_style(PixelMapLibrary.default_library()), "region test uses actual admitted authored palette")
	var atlas := (load("res://assets/environment/wellspring_v3/surfaces.png") as Texture2D).get_image()
	atlas.convert(Image.FORMAT_RGBA8)
	var kit := WellspringIllustratedKit.new()
	for index: int in 16:
		kit.tiles.append(atlas.get_region(Rect2i(index % 4 * 128, index / 4 * 128, 128, 128)))
	var classify := func(point: Vector2) -> String: return Terrain.FAMILIES[posmod(Terrain.cell_at(point).x, 5)]
	var finish := func(_point: Vector2, family: String) -> int: return Terrain.Finish.ROUTE if family in ["earth", "paving"] else Terrain.Finish.ORIGINAL
	for authored: Dictionary in [{}, kit.ground_surface_sources()]:
		var terrain := Terrain.new()
		var reference: Image = terrain.compose(Vector2i(320, 256), classify, style, finish, authored)
		check(reference != null, "small-map composition remains available for independent cropped reference")
		if reference == null: return
		for rect: Rect2i in [Rect2i(0, 0, 63, 61), Rect2i(63, 0, 129, 99), Rect2i(121, 117, 128, 128), Rect2i(249, 128, 71, 128)]:
			var region: Image = terrain.compose_region(rect, classify, style, finish, authored)
			check(region != null, "native arbitrary-origin region composes")
			if region == null: continue
			equal(region.get_size(), rect.size, "allocation follows requested region, never absolute world extent")
			equal(region.get_data(), reference.get_region(rect).get_data(), "global cell ownership, finish and authored UVs are byte exact across region edges")
		check(terrain.stamp_bytes + terrain.authored_tile_bytes <= Terrain.MAX_STAMP_BYTES, "reused source and stamp preparations share bounded residency")
		var negative := Rect2i(-141, -73, 240, 180)
		var negative_image: Image = terrain.compose_region(negative, classify, style, finish, authored)
		var sub := Rect2i(-30, -20, 97, 91)
		var negative_sub: Image = terrain.compose_region(sub, classify, style, finish, authored)
		check(negative_image != null and negative_sub != null, "negative world-space regions remain supported")
		if negative_image != null and negative_sub != null:
			equal(negative_sub.get_data(), negative_image.get_region(Rect2i(sub.position - negative.position, sub.size)).get_data(), "negative UV wrapping and hex row phases agree across independent boundaries")
		check(terrain.compose_region(Rect2i(8180, 0, 13, 8), classify, style) == null, "one-past supported absolute raster extent refuses")
		check(terrain.compose_region(Rect2i(6144, 5376, 16, 16), classify, style) != null, "far camera border needs only a small local allocation")
	# A changed source object must not reuse its prior prepared authored pixels.
	var sources := kit.ground_surface_sources()
	var cached := Terrain.new()
	var stone := func(_point: Vector2) -> String: return "paving"
	var rect := Rect2i(511, 511, 48, 48)
	var before: Image = cached.compose_region(rect, stone, style, Callable(), sources)
	var old_key: String = cached._prepared_key
	var source: Image = sources["paving:0"]
	source.set_pixel(1, 1, Color.BLACK if source.get_pixel(1, 1).r > 0.5 else Color.WHITE)
	var after: Image = cached.compose_region(rect, stone, style, Callable(), sources)
	var fresh: Image = Terrain.new().compose_region(rect, stone, style, Callable(), sources)
	check(before != null and after != null and fresh != null, "mutated-source cache test retains valid native source shape")
	check(cached._prepared_key != old_key, "source bytes invalidate prepared cache even when Image identity stays the same")
	if after != null and fresh != null: equal(after.get_data(), fresh.get_data(), "post-mutation cached region matches fresh actual pixel preparation")


func _test_region_cache() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "bounded cache uses real large world bounds")
	var original := CanonicalContent.sha256(layout.data)
	var kit := WellspringIllustratedKit.new()
	kit.campus = layout
	kit.ground_style = RefCounted.new()
	kit.content_hash = "test-only-region-cache"
	# Probe ignores source images but exercises the ordinary cache call boundary.
	for index: int in 16: kit.tiles.append(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var probe := RegionProbe.new()
	kit.hex_terrain = probe
	check(kit.ground_ready() and kit.ground == null and kit.ground_overview == null, "ready large-world allocation policy starts without a full texture")
	equal(kit.ground_chunk_ids(Rect2(512, 512, 512, 512)), [Vector2i(1, 1)], "exact upper boundaries do not overfetch neighboring regions")
	equal(kit.ground_chunk_ids(Rect2(-32, -32, 64, 64)), [Vector2i.ZERO], "outside camera margin clips to finite map bounds")
	check(kit.ground_chunk_ids(Rect2(6200, 5400, 10, 10)).is_empty(), "fully off-map view allocates no chunks")
	equal(kit.ground_chunk_rect(Vector2i(11, 10)), Rect2i(5632, 5120, 512, 256), "last partial row allocates only real map pixels")
	check(not kit.prepare_ground_view(Rect2(Vector2.ZERO, Vector2(layout.canvas_size))), "oversized view refuses native cache expansion before allocation")
	equal(probe.calls.size(), 0, "refused whole-world native preparation performs no region work")
	for index: int in 24: check(kit.ground_chunk(Vector2i(index % 12, index / 12)) != null, "first native cache entries allocate bounded regions")
	equal(kit.ground_chunks.size(), 24, "cache has exact finite texture count at capacity")
	equal(kit.ground_cache_bytes, 24 * 512 * 512 * 4, "full native cache residency is exactly24MiB")
	var first := kit.ground_chunk(Vector2i.ZERO)
	equal(probe.calls.size(), 24, "cache hit performs no pixel composition")
	check(kit.ground_chunk(Vector2i(0, 2)) != null, "new offscreen-to-visible region replaces an old entry")
	check(kit.ground_chunks.has(Vector2i.ZERO) and not kit.ground_chunks.has(Vector2i(1, 0)), "recently used region survives least-recently-used eviction")
	equal(kit.ground_chunk(Vector2i.ZERO), first, "retained texture identity is stable on repeated draws")
	equal(kit.ground_chunks.size(), 24, "replacement never grows texture count")
	check(kit.ground_cache_bytes <= kit.GROUND_CACHE_MAX_BYTES, "replacement remains below explicit byte ceiling")
	check(kit.ground_chunk(Vector2i(11, 10)) != null, "partial edge region also enters bounded cache")
	equal(kit.ground_cache_bytes, 23 * 512 * 512 * 4 + 512 * 256 * 4, "eviction subtracts actual texture dimensions and adds exact partial-region bytes")
	equal(CanonicalContent.sha256(layout.data), original, "cache work leaves authored map and collision metadata untouched")


func _test_wayfinding_and_culling() -> void:
	var signatures := {}
	for environment: String in ["coast", "grove", "foundry", "observatory"]:
		var lines := District.emblem(Vector2.ZERO, environment)
		check(not lines.is_empty() and lines.size() % 2 == 0 and lines.size() <= 48, "each district has a small finite open-line silhouette")
		signatures[str(lines)] = true
		for point: Vector2 in lines: check(point.length() <= 60, "waymark stays inside its culled visual envelope")
	equal(signatures.size(), 4, "all four districts remain distinguishable without depending on color or animation")
	var ornaments := District.ground_ornaments({"environment": "coast", "landmark_anchor": [3712, 640]})
	equal(ornaments.size(), 6, "authored landmark margins carry at most six independent finite ornament clusters")
	for ornament: Dictionary in ornaments:
		check(not (ornament.bounds as Rect2).has_point(Vector2(3712, 640)), "flat decoration leaves actual arrival and central feet clear")
		for point: Vector2 in ornament.lines: check((ornament.bounds as Rect2).has_point(point), "all decoration vertices remain inside the culling envelope")
	check(District.ground_ornaments({"environment": "grove"}).is_empty(), "missing authored anchor cannot invent decoration positions")
	var lines := PackedVector2Array([Vector2(-10, 5), Vector2(20, 5), Vector2(5000, 5000), Vector2(5010, 5000)])
	equal(SanctumCampusRenderer.visible_floor_segments(lines, Rect2(0, 0, 10, 10)), PackedVector2Array([Vector2(-10, 5), Vector2(20, 5)]), "crossing floor segment survives while offscreen work is culled")
	equal(SanctumCampusRenderer.visible_floor_segments(lines, Rect2()), lines, "explicit overview keeps all floor lines")
	check(not SanctumCampusRenderer.visible_in_world_rect(SanctumCampusRenderer.landmark_visual_bounds({"position": [5216, 4192]}), Rect2(0, 0, 960, 540)), "distant landmark performs no draw work in core view")


func _test_view_relative_backdrop() -> void:
	var backdrop := Backdrop.new()
	var renderer := ReadyRenderer.new()
	backdrop.configure(renderer, SanctumCampusLayout.new())
	equal(backdrop.size, Vector2i(2, 2), "POV terrain starts at Godot's minimal2x2 viewport without a world-sized allocation")
	var first := Rect2(1400, 800, 1280, 720)
	renderer.prepared = false
	check(not backdrop.prepare_view(first) and not backdrop.world_rect.has_area(), "incomplete terrain cannot capture a blank backdrop and mark it ready")
	renderer.prepared = true
	check(not backdrop.prepare_view(first), "new camera origin requires a fresh rendered revision")
	check(backdrop.world_rect.encloses(first), "allocated POV region includes current camera view")
	check(backdrop.size.x <= 2560 and backdrop.size.y <= 1536, "POV texture allocation is independently bounded")
	check(not backdrop.ready_for(first), "unrendered pixels cannot enter the POV compositor")
	# Explicitly simulate the completion token; native frame rendering remains a
	# separate root-owned capture gate, not an assertion made by this unit test.
	backdrop._complete_capture(backdrop._revision)
	check(backdrop.ready_for(first), "matching completed token admits the exact prepared view")
	var revision: int = backdrop._revision
	check(backdrop.prepare_view(first.grow(-10)), "contained camera movement reuses matching pixels")
	equal(backdrop._revision, revision, "contained movement schedules no terrain recapture")
	var destination := Rect2(4600, 4000, 1280, 720)
	check(not backdrop.prepare_view(destination) and not backdrop.ready_for(destination), "teleport refuses old terrain until its replacement revision renders")
	check(backdrop.ready_for(first), "old completed pixels remain available while a separate destination capture is pending")
	backdrop._complete_capture(revision)
	check(not backdrop.ready_for(destination), "late completion of old revision cannot authorize new origin")
	backdrop._complete_capture(backdrop._revision)
	check(backdrop.ready_for(destination) and not backdrop.ready_for(first), "completion atomically replaces coordinates and the captured texture")
	check(backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT), "court-label change schedules fresh static pixels")
	check(not backdrop.ready_for(destination), "court context invalidates otherwise matching camera texture")
	check(not backdrop.prepare_view(Rect2(0, 0, 0, 10)), "empty camera view refuses")
	backdrop.free()


func _test_region_sampler_equivalence() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "sampler equivalence uses complete live expanded geometry")
	var original_hash := CanonicalContent.sha256(layout.data)
	var kit := WellspringIllustratedKit.new()
	check(kit.configure(layout), "optimized sampler uses actual configured native art and route ordering: " + kit.last_error)
	if kit.content_hash.is_empty(): return
	var old := PreBroadphaseSampler.new(kit)
	var expected_by_cell := {}
	var regions := kit.ground_chunk_ids(Rect2(Vector2.ZERO,Vector2(layout.canvas_size)))
	equal(regions.size(), 132, "equivalence covers every full and partial cold region in the current world")
	var all_segments := 0
	for route: Dictionary in kit.paths: all_segments += (route.points as PackedVector2Array).size() - 1
	var candidate_segments := 0
	var callback_centers := 0
	for id: Vector2i in regions:
		var rect := kit.ground_chunk_rect(id)
		var sampler := kit.ground_region_sampler(rect)
		candidate_segments += sampler.segments.size()
		check(sampler.areas.size() <= layout.data.activity_areas.size() and sampler.districts.size() <= layout.data.districts.size(), "ephemeral broadphase cannot increase the source candidate inventory")
		# Independently reproduce the existing compositor's inclusive axial
		# visitation, including centers outside each image edge. Compare actual
		# scalar answers, not membership in the optimized candidate lists.
		var first_r := floori(float(rect.position.y * 1000 - HexGrid.HALF_HEIGHT) / HexGrid.ROW_PITCH)
		var last_r := ceili(float(rect.end.y * 1000 + HexGrid.HALF_HEIGHT) / HexGrid.ROW_PITCH)
		for r: int in range(first_r,last_r + 1):
			var first_q := floori(float(rect.position.x * 1000 - HexGrid.HALF_WIDTH * r - HexGrid.HALF_WIDTH) / HexGrid.COLUMN_PITCH)
			var last_q := ceili(float(rect.end.x * 1000 - HexGrid.HALF_WIDTH * r + HexGrid.HALF_WIDTH) / HexGrid.COLUMN_PITCH)
			for q: int in range(first_q,last_q + 1):
				var cell := Vector2i(q,r)
				var point := Terrain.center_pixels(cell)
				callback_centers += 1
				check(sampler.sample_bounds.has_point(point), "every actual compositor callback center fits the prepared fringe")
				if not expected_by_cell.has(cell):
					var surface: int = old.surface_at(point)
					var family := WellspringIllustratedKit.pixel_family(surface)
					expected_by_cell[cell] = [surface,family,old.floor_finish_at(point,family)]
				var expected: Array = expected_by_cell[cell]
				equal(sampler.surface_at(point), expected[0], "region material agrees exactly with independently retained original sampler")
				equal(sampler.finish_at(point,expected[1]), expected[2], "region finish preserves exact original room/route/district precedence")
	check(callback_centers > 65000 and expected_by_cell.size() > 60000, "equivalence reached actual whole-world callbacks instead of a small representative sample")
	check(candidate_segments * 4 < all_segments * regions.size(), "region broadphase removes at least three quarters of the possible ordered segment candidates on this actual map")
	# Probe off-center inputs and exact rectangular edges as well as callback
	# centers; floor/material sampling must retain the original cell snap.
	for area: Dictionary in layout.data.activity_areas:
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(area.bounds))
		for anchor: Vector2 in [bounds.position,bounds.end,bounds.get_center()]:
			var sampler := kit.ground_region_sampler(Rect2i(Vector2i(anchor) - Vector2i(1,1),Vector2i(2,2)))
			for offset: Vector2 in [Vector2.ZERO,Vector2(-0.001,0.001),Vector2(15.999,16.001),Vector2(-24.001,23.999),Vector2(48,48)]:
				var point := anchor + offset
				equal(sampler.surface_at(point), old.surface_at(point), "boundary and out-of-region fallback preserve original fixed-point hex ownership")
				for family: String in ["earth","paving","grass","water","worldbone"]:
					equal(sampler.finish_at(point,family), old.floor_finish_at(point,family), "all family finish gates agree at edges and fallback points")
	# Native pixel composition remains independently byte-equal around core
	# room/ribbon overlap, chunk seams, district boundaries and negative origins.
	var reference_compositor := Terrain.new()
	var optimized_compositor := Terrain.new()
	var classify_old := func(point: Vector2) -> String: return WellspringIllustratedKit.pixel_family(old.surface_at(point))
	for rect: Rect2i in [Rect2i(-19,-21,82,83),Rect2i(511,511,128,96),Rect2i(1117,563,192,128),Rect2i(1480,1360,160,128),Rect2i(2272,936,192,128),Rect2i(3104,2400,128,192),Rect2i(504,3264,192,128),Rect2i(2304,3264,192,128),Rect2i(4320,2688,160,128),Rect2i(6096,5328,48,48)]:
		var sampler := kit.ground_region_sampler(rect)
		var reference: Image = reference_compositor.compose_region(rect,classify_old,kit.ground_style,old.floor_finish_at,kit.ground_surface_sources())
		var optimized: Image = optimized_compositor.compose_region(rect,sampler.material_at,kit.ground_style,sampler.finish_at,kit.ground_surface_sources())
		check(reference != null and optimized != null, "both independent sampler routes compose actual native pixels")
		if reference != null and optimized != null:
			equal(optimized.get_data(), reference.get_data(), "optimized terrain pixels are byte exact at representative seams and precedence boundaries")
	equal(CanonicalContent.sha256(layout.data), original_hash, "terrain sampling preserves every authored gameplay/content value")
	equal(kit.ground_chunks.size(), 0, "ephemeral sampler preparation never populates or expands texture residency")
