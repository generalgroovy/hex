extends FluxTestSuite


func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "illustrated campus uses the live gameplay layout")
	var original := CanonicalContent.sha256(layout.data)
	var kit := WellspringIllustratedKit.new()
	check(not kit.configure(null), "illustrated campus refuses missing geometry")
	check(kit.configure(layout), "illustrated campus validates: " + kit.last_error)
	check(kit.content_hash.length() == 64, "presentation has a bounded content identity")
	check(kit.ground_ready() and kit.ground == null, "large terrain is ready without a full-world texture")
	equal(kit.ground_chunks.size(), 0, "setup allocates no offscreen native chunks")
	check(kit.prepare_ground_view(Rect2(1024, 512, 1024, 1024)), "actual local floor prepares bounded visible chunks")
	equal(kit.cached_terrain_builds, 0, "large world never composes a full-world native raster")
	check(kit.hex_terrain != null and kit.hex_terrain.cell_count == 0, "live baked floor allocates no authoring lattice during setup or loading")
	var reference := kit.HexTerrain.new()
	var reference_rect := Rect2i(1024, 512, 512, 512)
	var reference_image: Image = reference.compose_region(reference_rect, func(point: Vector2) -> String: return kit.pixel_family(kit.surface_at(point)), kit.ground_style, kit.floor_finish_at, kit.ground_surface_sources())
	check(reference_image != null and reference.cell_count > 100, "independent original composer retains the actual symbol-sized chemistry lattice")
	if reference_image != null:
		equal(kit.ground_chunk(Vector2i(2, 1)).get_image().get_data(), reference_image.get_data(), "prepared floor is byte-identical to the original material/finish lattice")
	check(reference.stamp_count <= kit.HexTerrain.MAX_STAMPS and reference.stamp_bytes <= kit.HexTerrain.MAX_STAMP_BYTES, "authoring raster retains bounded material/finish stamps")
	check(kit.ground_cache_bytes <= kit.GROUND_CACHE_MAX_BYTES, "native ground residency stays inside its explicit byte budget")
	equal(reference.authored_tile_count, kit.HexTerrain.MAX_AUTHORED_TILES, "prepared campus still derives from all nine admitted native stone/soil finishes")
	equal(reference.authored_tile_bytes, kit.HexTerrain.MAX_AUTHORED_BYTES, "independent authoring finish variants retain exactly576KiB")
	equal(kit.hex_terrain.authored_tile_bytes, 0, "live prepared terrain needs no duplicate576KiB authoring variants")
	check(reference.stamp_bytes + reference.authored_tile_bytes <= kit.HexTerrain.MAX_STAMP_BYTES, "native authoring artwork and organic stamps share the existing16MiB transient budget")
	equal(kit.roof_skins.size() + kit.practice_skins.size(), layout.buildings_by_id.size(), "each existing structure receives a cached skin without collision changes")
	_test_practice_masonry(kit, layout)
	_test_masonry_relief(kit)
	_test_slate_roofs(kit, layout)
	_test_ground_style(kit)
	_test_floor_inlays(kit, layout)
	equal(kit.tiles.size(), 16, "sixteen reusable material tiles load")
	equal(kit.PROP_IDS.size(), 16, "sixteen reusable props load")
	equal(kit.decorations.size(), 0, "non-worldbone decoration is withheld from the live campus")
	equal(String(kit.data["camera"]["ground_axes"]), "screen_cardinal", "painted elevation never skews input or aim")
	equal(int(kit.data["camera"]["art_elevation_degrees"]), 55, "characters and environment share the elevated art camera")
	check(int(kit.data["camera"]["maximum_facade_pixels"]) <= 64, "ordinary facade default remains bounded; selected taller art stays inside its existing footprint")
	var building := Rect2(100, 100, 200, 120)
	equal(kit.cover_opacity(building, Vector2(200, 90)), kit.cover_opacity(building, Vector2(90, 160)), "roof clearance is equal on cardinal approaches")
	check(is_equal_approx(kit.cover_opacity(building, Vector2(200, 100)), 0.30), "near roof reveals the player without a schematic replacement panel")
	check(is_equal_approx(kit.cover_opacity(building, Vector2(200, 72)), 0.65), "roof fade changes continuously across the approach band")
	equal(kit.cover_opacity(building, Vector2(200, 0)), 1.0, "distant architecture remains fully visible")
	equal(kit.landmark_opacity(Vector2(400, 400), Vector2(400, 400)), 0.30, "decorative fountain stays quiet when the player crosses its footprint")
	equal(kit.landmark_opacity(Vector2(400, 400), Vector2(600, 600)), 1.0, "distant fountain retains its full artwork")
	equal(kit.ambient_phase(0, 180), 0.0, "ambient landmark motion starts from a quiet phase")
	equal(kit.ambient_phase(90, 180), 1.0, "ambient landmark motion reaches one bounded crest")
	equal(kit.ambient_phase(90, 180, true), 0.0, "Reduced Effects freezes nonessential landmark motion")
	for tick: int in range(-360, 361, 17):
		check(kit.ambient_phase(tick, 180) >= 0.0 and kit.ambient_phase(tick, 180) <= 1.0, "ambient landmark phase remains bounded")
	equal(kit.station_label_opacity(Vector2(400, 400), Vector2(400, 400)), 1.0, "nearby station title remains fully readable")
	equal(kit.station_label_opacity(Vector2(400, 400), Vector2(920, 400)), 0.0, "distant station title yields the overview lane to gameplay")
	var fading_label := kit.station_label_opacity(Vector2(400, 400), Vector2(800, 400))
	check(fading_label > 0.0 and fading_label < 1.0, "station title fades continuously across the relevance band")
	check(kit.surface_at(Vector2(1536, 900)) in [0, 1], "source court reads as stone")
	for sample: Vector2 in [Vector2(1536, 900), Vector2(224, 1380), Vector2(2100, 1900)]:
		var cell := WellspringIllustratedKit.HexTerrain.cell_at(sample)
		var center := WellspringIllustratedKit.HexTerrain.center_pixels(cell)
		for offset: Vector2 in [Vector2.ZERO, Vector2(5, 0), Vector2(0, 5), Vector2(-5, -5)]:
			equal(kit.surface_at(center + offset), kit.surface_at(center), "all samples inside one canonical hex share the same material")
	equal(kit.surface_at(Vector2(10, 10)), 8, "outer shore reads as water")
	for point: Vector2 in [Vector2(256, 2080), Vector2(848, 2080), Vector2(1120, 2080), Vector2(1888, 2080)]:
		check(kit.surface_at(point) != 8, "the live southern walk is land, not a hardcoded old shoreline")
	equal(kit.surface_at(Vector2(1536, layout.canvas_size.y - 32)), 8, "the new bottom boundary retains its quiet shoreline")
	check(layout.canvas_size.x <= kit.LARGE_WORLD_MAX.x and layout.canvas_size.y <= kit.LARGE_WORLD_MAX.y, "expanded world stays inside explicit region-rendering bounds")
	# Transparent borders prohibit paper/checkerboard backing in live cutouts.
	var props := kit.props.get_image()
	for index: int in range(16):
		var cell := props.get_region(Rect2i(index % 4 * 128, index / 4 * 128, 128, 128))
		check(cell.get_pixel(0, 0).a == 0 and cell.get_pixel(127, 127).a == 0, "prop %d has transparent cell corners" % index)
		check(cell.get_used_rect().get_area() > 100, "prop %d contains real artwork" % index)
		var occupied := 0
		for y: int in range(128):
			for x: int in range(128):
				if cell.get_pixel(x, y).a > 0.5:
					occupied += 1
		check(occupied < 128 * 128 * 0.78, "prop %d contains a cutout, not an opaque preview card" % index)
	equal(CanonicalContent.sha256(layout.data), original, "terrain preparation never mutates gameplay content")
	equal(kit.cached_terrain_builds, 0, "inspection cannot create a full-world raster")
	print("ILLUSTRATED_SETUP: %d ms; %d props; bounded native terrain regions; %d authored bytes; %d native copies" % [kit.ground_generation_ms, kit.decorations.size(), kit.hex_terrain.authored_tile_bytes, kit.hex_terrain.authored_copy_count])
	_test_renderer_binding(layout)
	_test_visible_world_culling(layout)
	return finish("wellspring-illustrated-kit")


func _test_floor_inlays(kit: WellspringIllustratedKit, layout: SanctumCampusLayout) -> void:
	var before := CanonicalContent.sha256(layout.data)
	var paths_before := kit.paths.duplicate(true)
	var texture := kit.ground
	var builds := kit.cached_terrain_builds
	var palettes := {}
	var source_bytes := {}
	for family: String in kit.HexTerrain.FAMILIES:
		var tile := kit.ground_style.tile_image("map.terrain.%s.fill_v1" % family) as Image
		palettes[family] = kit.HexTerrain._material_palette(tile)
		source_bytes[family] = tile.get_data()
	var tones: Array[Color] = kit.HexTerrain.finish_tones(palettes)
	var authored_sources := kit.ground_surface_sources()
	var authored_bytes := {}
	var authored_tiles := {}
	for key: String in authored_sources:
		var family := key.get_slice(":", 0)
		var kind := int(key.get_slice(":", 1))
		var base: Color = kit.HexTerrain.terrain_tone(palettes[family][0], family) if kind == kit.HexTerrain.Finish.ORIGINAL else tones[kind]
		authored_bytes[key] = (authored_sources[key] as Image).get_data()
		authored_tiles[key] = kit.HexTerrain.prepare_authored_tile(authored_sources[key], base)
	var examples := [
		[Vector2(1536, 960), 0, kit.HexTerrain.Finish.COMMONS],
		[Vector2(1472, 1328), 2, kit.HexTerrain.Finish.CHEMISTRY],
		[Vector2(2640, 1120), 0, kit.HexTerrain.Finish.DUEL],
		[Vector2(1360, 1888), 0, kit.HexTerrain.Finish.CHAIN],
		[Vector2(1184, 720), 0, kit.HexTerrain.Finish.INSET],
		[Vector2(1360, 1180), 2, kit.HexTerrain.Finish.INSET],
		[Vector2(2208, 1280), 0, kit.HexTerrain.Finish.INSET],
		[Vector2(1184, 1872), 0, kit.HexTerrain.Finish.INSET],
		[Vector2(1536, 832), 0, kit.HexTerrain.Finish.ROUTE],
		[Vector2(1536, 1408), 2, kit.HexTerrain.Finish.ROUTE],
		[Vector2(1008, 832), 1, kit.HexTerrain.Finish.ROUTE],
		# The actual sparring zigzag and chain drill are not circulation ribbons.
		[Vector2(2544, 1216), 0, kit.HexTerrain.Finish.DUEL],
		[Vector2(1360, 1792), 0, kit.HexTerrain.Finish.CHAIN],
	]
	for entry: Array in examples:
		var point: Vector2 = entry[0]
		var surface: int = kit.surface_at(point)
		equal(surface, int(entry[1]), "inlays preserve the existing authored surface classification at " + str(point))
		var family: String = kit.pixel_family(surface)
		var expected: int = int(entry[2])
		equal(kit.floor_finish_at(point, family), expected, "native court/ribbon/inset selection matches its real campus location " + str(point))
		var cell := kit.HexTerrain.cell_at(point)
		var center := kit.HexTerrain.center_pixels(cell)
		for offset: Vector2 in [Vector2.ZERO, Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
			equal(kit.floor_finish_at(center + offset, family), expected, "the entire canonical hex shares one finish at an inlay boundary")
		var authored: Image = authored_tiles[kit.HexTerrain.surface_key(family, expected)]
		var sample := Vector2i(center.floor())
		var source_point := Vector2i(1 + sample.x % 126, 1 + sample.y % 126) if family == "earth" else Vector2i(sample.x % 128, sample.y % 128)
		var chunk_id := Vector2i(sample.x / kit.GROUND_CHUNK_SIZE, sample.y / kit.GROUND_CHUNK_SIZE)
		var chunk: Texture2D = kit.ground_chunk(chunk_id)
		check(chunk != null, "inlay sample has an actual bounded native region")
		if chunk != null:
			equal(chunk.get_image().get_pixelv(sample - chunk_id * kit.GROUND_CHUNK_SIZE), authored.get_pixelv(source_point), "live chunk contains its classified native texture, excluding only proven soil sheet-divider ink")
	for point: Vector2 in [Vector2(1280, 832), Vector2(1808, 832), Vector2(1896, 832), Vector2(1280, 1408), Vector2(1808, 1408)]:
		equal(kit.floor_finish_at(point, kit.pixel_family(kit.surface_at(point))), kit.HexTerrain.Finish.ROUTE, "existing broad crossing stays continuous through court and inset boundaries")
	for family: String in ["grass", "water", "worldbone"]:
		equal(kit.floor_finish_at(Vector2(1536, 832), family), kit.HexTerrain.Finish.ORIGINAL, "floor inlays cannot override garden, shore or worldbone material families")
	var room := WellspringIllustratedKit.new()
	room.campus = layout
	# Isolate the court bounds from route precedence without editing the live kit.
	for entry: Array in [[Vector2(1536, 588), kit.HexTerrain.Finish.ORIGINAL], [Vector2(1536, 616), kit.HexTerrain.Finish.INSET], [Vector2(1536, 680), kit.HexTerrain.Finish.COMMONS], [Vector2(1536, 1104), kit.HexTerrain.Finish.ORIGINAL]]:
		equal(room.floor_finish_at(entry[0], "paving"), int(entry[1]), "source finish stays inside its existing court/floor intersection, with a flat24px inset")
	room.paths.append({"points": PackedVector2Array([Vector2(1400, 960), Vector2(1680, 960)]), "width": 160.0, "advanced": true})
	room.paths.append({"points": PackedVector2Array([Vector2(1400, 960), Vector2(1680, 960)]), "width": 64.0, "advanced": false})
	equal(room.floor_finish_at(Vector2(1536, 960), "paving"), kit.HexTerrain.Finish.COMMONS, "advanced and narrow training paths never acquire a misleading main-walk ribbon")
	check(kit.ground == null and kit.ground_overview == null, "native inlay inspection never allocates a whole-world image or overview")
	check(kit.ground_cache_bytes <= kit.GROUND_CACHE_MAX_BYTES and kit.ground_chunks.size() <= kit.GROUND_CACHE_LIMIT, "native inlays retain the explicit chunk byte and count bounds")
	equal(kit.hex_terrain.stamp_bytes, kit.hex_terrain.stamp_count * kit.HexTerrain.STAMP_SIZE.x * kit.HexTerrain.STAMP_SIZE.y * 4, "live setup reports its exact transient stamp allocation")
	equal(kit.ground, texture, "finish inspection keeps the same cached terrain texture")
	equal(kit.cached_terrain_builds, builds, "finish sampling does not rebuild terrain")
	equal(CanonicalContent.sha256(layout.data), before, "floor finishes cannot mutate routes, stations, colliders, LOS or any map content")
	equal(kit.paths, paths_before, "route ribbons do not rewrite even the presentation's prepared paths")
	for family: String in kit.HexTerrain.FAMILIES:
		equal((kit.ground_style.tile_image("map.terrain.%s.fill_v1" % family) as Image).get_data(), source_bytes[family], "court inspection preserves every admitted source image")
	for key: String in authored_sources:
		equal((authored_sources[key] as Image).get_data(), authored_bytes[key], "live floor inspection preserves every original v3 stone/soil source image")
	var source := FileAccess.get_file_as_string("res://src/presentation/wellspring_illustrated_kit.gd").replace("\r", "")
	var draw_source := source.get_slice("func draw_ground(", 1).get_slice("\n\nfunc ", 0)
	check(draw_source.contains("ground_chunk_ids(visible_world_rect)") and draw_source.contains("ground_chunks[id]") and not draw_source.contains("prepare_ground_view"), "large render path reads only prepared visible native regions without blocking")
	check(not draw_source.contains("floor_finish_at") and not draw_source.contains("compose_region") and not draw_source.contains("Image.create"), "ground draw itself performs no per-cell image work")


func _test_practice_masonry(kit: WellspringIllustratedKit, layout: SanctumCampusLayout) -> void:
	var original := CanonicalContent.sha256(layout.data)
	var count := 0
	var bytes := 0
	var families := {}
	for building: Dictionary in layout.buildings_by_id.values():
		if String(building.get("style", "")) != "practice_wall": continue
		count += 1
		var bounds := SanctumCampusLayout._parse_bounds(building["bounds"])
		var family := kit.WallSkin.family_for(bounds, layout.data.get("activity_areas", []), layout.data.get("districts", []))
		families[family] = true
		var expected := kit.WallSkin.compose(bounds, family)
		var skin: Texture2D = kit.practice_skins[int(building["id"])]
		var actual := skin.get_image()
		equal(actual.get_size(), bounds.size, "wall art fits exact collision rectangle, no decorative overhang")
		equal(actual.get_used_rect(), Rect2i(Vector2i.ZERO, bounds.size), "wall has continuous readable silhouette through corners")
		equal(actual.get_data(), expected.get_data(), "masonry recompilation produces identical pixels")
		check(skin == kit.practice_skins[int(building["id"])], "wall cache lookup returns the same admitted texture")
		var opaque := true
		var allowed := true
		var palette: Array[Color] = []
		for code: String in kit.WallSkin.PALETTES[family]: palette.append(Color(code))
		for y: int in bounds.size.y:
			for x: int in bounds.size.x:
				var pixel := actual.get_pixel(x, y)
				opaque = opaque and pixel.a == 1.0
				allowed = allowed and pixel in palette
		check(opaque, "solid collision cannot look like a traversable hole")
		check(allowed, "pixel wall uses only its eight opaque room colors; no antialiasing or chemistry glow")
		bytes += actual.get_data().size()
	equal(kit.practice_skins.size(), count, "one prepared texture per real practice obstacle")
	equal(kit.practice_skin_bytes, bytes, "wall allocation is reported exactly")
	check(bytes <= kit.PRACTICE_CACHE_MAX_BYTES, "all49-building campus masonry remains within explicit3MiB bound")
	equal(bytes, 2_248_960, "41 actual practice footprints account for exact decoded masonry allocation")
	equal(families.size(), 6, "original three rooms and coastal, foundry and observatory architecture retain separate real-cover identities")
	for invalid: Rect2i in [Rect2i(0, 0, 0, 28), Rect2i(0, 0, 15, 28), Rect2i(0, 0, 1025, 28)]:
		check(kit.WallSkin.compose(invalid, "slate") == null, "unbounded or too-small wall footprint refuses raster allocation")
	check(kit.WallSkin.compose(Rect2i(0, 0, 28, 28), "fire") == null, "masonry never invents an elemental wall")
	for family: String in kit.WallSkin.PALETTES:
		var smallest := kit.WallSkin.compose(Rect2i(0, 0, 16, 16), family)
		var ink := Color(kit.WallSkin.PALETTES[family][0])
		for index: int in 16:
			check(smallest.get_pixel(index, 0) == ink and smallest.get_pixel(index, 15) == ink and smallest.get_pixel(0, index) == ink and smallest.get_pixel(15, index) == ink, "smallest valid skin keeps complete collision rim without clipped decoration")
	equal(CanonicalContent.sha256(layout.data), original, "wall raster and room materials cannot mutate collision/gameplay")


func _test_masonry_relief(kit: WellspringIllustratedKit) -> void:
	# Read actual image planes independently of the composer's chosen dimensions.
	# A deeper facade may not move the silhouette, erase the cap, or add ground.
	var deep_heights := {}
	for family: String in kit.WallSkin.PALETTES:
		var palette: Array = kit.WallSkin.PALETTES[family]
		for size: Vector2i in [Vector2i(96, 128), Vector2i(320, 28), Vector2i(28, 192)]:
			var bounds := Rect2i(Vector2i(304, 512), size)
			var image: Image = kit.WallSkin.compose(bounds, family)
			check(image != null, "bounded depth fixture composes for " + family)
			if image == null: continue
			equal(image.get_size(), size, "relief keeps the complete original collision footprint")
			equal(image.get_data().size(), size.x * size.y * 4, "relief adds no texture area or layer")
			var face_y := -1
			for y: int in range(4, size.y - 2):
				if image.get_pixel(4, y) == Color(palette[0]):
					face_y = y
					break
			check(face_y >= 8 and face_y < size.y - 5, "actual cap and south face are both visible")
			var face_height := size.y - 2 - face_y
			check(face_height <= (size.y - 4) / 2, "visual height never consumes more than half the real footprint")
			if size == Vector2i(96, 128):
				deep_heights[family] = face_height
				check(face_height > 14 and face_height <= 42, "deep blocks gain bounded relief beyond the old14px facade")
			elif size.y == 28:
				check(face_height <= 12, "thin cover retains a low facade and readable opaque cap")
			var solid_rim := true
			for x: int in size.x:
				solid_rim = solid_rim and image.get_pixel(x, 0) == Color(palette[0]) and image.get_pixel(x, size.y - 1) == Color(palette[0])
			for y: int in size.y:
				solid_rim = solid_rim and image.get_pixel(0, y) == Color(palette[0]) and image.get_pixel(size.x - 1, y) == Color(palette[0])
			check(solid_rim, "parapet and material relief cannot imply a notch, doorway or traversable gap")
			var shaded_side := true
			for y: int in range(2, size.y - 2):
				shaded_side = shaded_side and image.get_pixel(size.x - 4, y) == Color(palette[1])
			check(shaded_side, "continuous dark east plane conveys volume without exterior shadow or overhang")
			equal(image.get_pixel(4, size.y - 3), Color(palette[5]), "continuous south foundation anchors the wall inside its collision edge")
	check(int(deep_heights.get("garden", 0)) < int(deep_heights.get("slate", 0)), "garden barriers and slate ramparts retain distinct vertical profiles")
	check(int(deep_heights.get("slate", 0)) < int(deep_heights.get("foundry", 0)), "industrial buttresses have deeper faces than slate ramparts")
	check(int(deep_heights.get("foundry", 0)) < int(deep_heights.get("observatory", 0)), "observatory plinths retain their own bounded profile")
	# Existing native terrain is an independent artifact. This relief belongs to
	# setup-only building textures, not the tile bake or its producer inventory.
	var terrain_manifest := load(kit.TerrainStream.MANIFEST) as Resource
	check(terrain_manifest != null, "depth comparison retains the existing terrain manifest")
	if terrain_manifest != null:
		equal(String(terrain_manifest.get("descriptor").get("signature", "")), kit.bake_signature, "wall relief leaves the baked-ground signature unchanged")
	check("res://src/presentation/practice_wall_skin.gd" not in kit.TerrainStream.BAKE_SOURCE_PATHS, "wall raster is not a ground-tile producer")


func _test_slate_roofs(kit: WellspringIllustratedKit, layout: SanctumCampusLayout) -> void:
	var original := CanonicalContent.sha256(layout.data)
	var slate := kit.tiles[10]
	var source_bytes := slate.get_data()
	var count := 0
	var bytes := 0
	for building: Dictionary in layout.buildings_by_id.values():
		var id := int(building["id"])
		if String(building.get("style", "")) == "practice_wall":
			check(not kit.roof_skins.has(id), "practice obstacles retain their existing masonry, not roof art")
			continue
		count += 1
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(building["bounds"]))
		if id in [105, 108]:
			_test_tall_architecture(kit, building)
			bytes += kit.roof_skins[id].get_image().get_data().size()
			continue
		var facade_height := minf(float(kit.data["camera"]["maximum_facade_pixels"]), bounds.size.y * 0.42)
		var size := Vector2i(Vector2(bounds.size.x, bounds.size.y - facade_height).ceil())
		var skin: Texture2D = kit.roof_skins[id]
		var actual := skin.get_image()
		var expected := kit.compose_roof_skin(size, slate)
		equal(actual.get_size(), size, "roof cache covers only the original roof rectangle, rounded up for edge cropping")
		equal(actual.get_used_rect(), Rect2i(Vector2i.ZERO, size), "roof silhouette stays continuous and opaque through every corner")
		equal(actual.get_data(), expected.get_data(), "roof composition is deterministic")
		var exact_copy := true
		for y: int in size.y:
			for x: int in size.x:
				exact_copy = exact_copy and actual.get_pixel(x, y) == slate.get_pixel(x % 128, y % 128)
		check(exact_copy, "all roof pixels are unscaled approved slate, including partial repeat edges")
		for _access: int in 3:
			check(skin == kit.roof_skins[id], "repeated presentation lookup reuses the admitted texture")
		bytes += actual.get_data().size()
	equal(count, 8, "only the eight existing service buildings share the roof/architecture cache")
	equal(kit.cached_roof_builds, count, "each roof is composed exactly once during configuration")
	equal(kit.roof_skin_bytes, bytes, "roof cache reports exact decoded allocation")
	equal(bytes, 861440, "two full-footprint facades replace old roofs without retaining duplicate textures")
	check(bytes < 1024 * 1024, "all current roofs and taller facades remain below one MiB decoded")
	equal(slate.get_data(), source_bytes, "roof tiling never edits the validated source atlas")
	for invalid: Vector2i in [Vector2i.ZERO, Vector2i(-1, 64), Vector2i(1025, 1), Vector2i(512, 512)]:
		check(kit.compose_roof_skin(invalid, slate) == null, "invalid or over-budget roof sizes refuse allocation")
	check(kit.compose_roof_skin(Vector2i(32, 32), null) == null, "missing slate is not replaced with invented art")
	var source: String = String(kit.get_script().source_code).replace("\r", "")
	var draw_source := source.get_slice("func draw_building(", 1).get_slice("\n\nstatic func ", 0)
	check(draw_source.contains("roof_skins.get("), "actual building draw reads the prepared roof cache")
	check(draw_source.contains("Rect2(Vector2.ZERO, roof.size)"), "fractional facade split crops the texture without changing the roof silhouette")
	for forbidden: String in ["compose_roof_skin", "Image.create", "ImageTexture.create", "cached_roof_builds +=", "architecture_inlays"]:
		check(not draw_source.contains(forbidden), "building redraw cannot regenerate roof art or restore hex outlines: " + forbidden)
	equal(kit.cached_roof_builds, count, "inspection and repeated lookups do not build extra roof textures")
	equal(CanonicalContent.sha256(layout.data), original, "roof preparation cannot change footprints, LOS, stations or route authority")


func _test_tall_architecture(kit: WellspringIllustratedKit, building: Dictionary) -> void:
	var id := int(building.id)
	var size := Vector2i(192, 160) if id == 105 else Vector2i(144, 144)
	var face_y := 60 if id == 105 else 52
	var family := "observatory" if id == 105 else "limestone"
	var before := CanonicalContent.sha256(building)
	var slate_before := kit.tiles[10].get_data()
	var facade_before := kit.tiles[11].get_data()
	var actual: Image = kit.roof_skins[id].get_image()
	equal(actual.get_size(), size, "taller facade fills only its existing exact footprint")
	equal(actual.get_format(), Image.FORMAT_RGBA8, "taller facade uses the existing decoded pixel format")
	var opaque := true
	var pixels := actual.get_data()
	for offset: int in range(3, pixels.size(), 4):
		opaque = opaque and pixels[offset] == 255
	check(opaque, "taller planes and decorative cap contain no false opening")
	for point: Vector2i in [Vector2i(0, 0), Vector2i(2, face_y), Vector2i(size.x - 1, size.y - 1)]:
		equal(actual.get_pixelv(point), Color("4b3025"), "solid original outer rim remains inside its footprint")
	equal(actual.get_pixel(5, 8), kit.tiles[10].get_pixel(2, 5), "narrow roof still samples approved slate at one-to-one scale")
	var face_color := Color(kit.WallSkin.PALETTES[family][2])
	var tile_color := kit.tiles[11].get_pixel(2, 12)
	var expected := tile_color.lerp(face_color, 0.12)
	expected.a = 1.0
	var quantized := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	quantized.set_pixel(0, 0, expected)
	equal(actual.get_pixel(5, face_y + 12), quantized.get_pixel(0, 0), "large front plane retains the approved facade tile's exact grain and phase")
	check(actual.get_pixel(size.x - 8, face_y + 12).get_luminance() < actual.get_pixel(size.x - 136, face_y + 12).get_luminance(), "east plane stays visibly darker than the broad front")
	check(kit.ArchitectureSkin.compose_building(building, null, kit.tiles[11]) == null, "selected architecture refuses missing approved slate")
	check(kit.ArchitectureSkin.compose_building(building, kit.tiles[10], null) == null, "selected architecture refuses missing approved masonry")
	var changed := building.duplicate(true)
	changed.bounds[2] += 1
	check(not kit.ArchitectureSkin.supports(changed), "different footprint uses ordinary architecture instead of stretching the admitted skin")
	changed = building.duplicate(true)
	changed.vaultable = true
	check(not kit.ArchitectureSkin.supports(changed), "a traversable structure cannot borrow the solid tower treatment")
	equal(kit.tiles[10].get_data(), slate_before, "architecture leaves the admitted slate source unchanged")
	equal(kit.tiles[11].get_data(), facade_before, "architecture leaves the admitted masonry source unchanged")
	equal(CanonicalContent.sha256(building), before, "architecture cannot change collision, LOS, doorway or movement flags")
	check("res://src/presentation/wellspring_architecture_skin.gd" not in kit.TerrainStream.BAKE_SOURCE_PATHS, "object facade raster is not a baked-ground producer")


func _test_visible_world_culling(layout: SanctumCampusLayout) -> void:
	var before := CanonicalContent.sha256(layout.data)
	var viewport := Rect2(1000, 500, 1280, 720)
	check(SanctumCampusRenderer.visible_in_world_rect(Rect2(-9000, -9000, 10, 10), Rect2()), "empty view preserves complete-map captures and backdrop drawing")
	check(SanctumCampusRenderer.visible_in_world_rect(Rect2(1100, 600, 40, 40), viewport), "visible object survives conservative world-view rejection")
	check(not SanctumCampusRenderer.visible_in_world_rect(Rect2(10, 10, 40, 40), viewport), "distant object is rejected before submitting its individual draw commands")
	check(SanctumCampusRenderer.visible_in_world_rect(Rect2(960, 600, 40, 40), viewport), "edge-touching artwork is retained to avoid one-pixel camera pops")
	var building := {"bounds": [1200, 400, 160, 60]}
	var building_bounds := SanctumCampusRenderer.building_visual_bounds(building)
	check(building_bounds.encloses(Rect2(1200, 400, 160, 60)), "render bounds always contain authority footprint")
	check(SanctumCampusRenderer.visible_in_world_rect(building_bounds, Rect2(1200, 485, 100, 60)), "building planter/shadow edge can appear even when collision rectangle is offscreen")
	var station := {"position": [1200, 700], "command": "configure_spells"}
	var station_bounds := SanctumCampusRenderer.station_visual_bounds(station)
	check(station_bounds.encloses(WellspringServiceBuildings.door_threshold(station).grow(1)), "flat approach and its thin outline are included without an invented hut footprint")
	check(station_bounds.has_point(Vector2(1280, 724)), "directory title width and bottom baseline are included")
	check(station_bounds.size.y<=70,"directory bounds contain two compact label lines and approach; existing roofs use separate building bounds")
	var station_label := WellspringServiceBuildings.service_label_rect(station)
	check(station_bounds.encloses(station_label.grow(1)), "both purpose and identity lines remain inside conservative directory culling bounds")
	equal(station_bounds.end.y, 749.0, "two-line directory keeps ten pixels of lower culling allowance beyond its label")
	check(SanctumCampusRenderer.visible_in_world_rect(station_bounds, Rect2(1190, station_label.end.y - 1.0, 20, 1)), "the final visible pixel of the identity label cannot be culled at the viewport edge")
	check(SanctumCampusRenderer.visible_in_world_rect(station_bounds, Rect2(1190, 679, 20, 1)), "the door-connected outline survives the first visible pixel at the viewport edge")
	check(SanctumCampusRenderer.visible_in_world_rect(station_bounds, Rect2(1160, 680, 80, 4)), "partially entering threshold/label survives edge culling")
	check(not SanctumCampusRenderer.visible_in_world_rect(station_bounds, Rect2(1160, 620, 80, 20)), "removed hut roof no longer keeps a distant directory marker drawable")
	var group_bounds := {}
	for entry: Dictionary in layout.data.get("stations", []):
		var actual_bounds := SanctumCampusRenderer.station_visual_bounds(entry)
		var point := Vector2(SanctumCampusLayout._parse_point(entry["position"]))
		check(actual_bounds.encloses(WellspringServiceBuildings.door_threshold(entry).grow(1)), "all grouped door approaches and their outlines survive render culling")
		var actual_label := WellspringServiceBuildings.service_label_rect(entry)
		check(actual_bounds.encloses(actual_label.grow(1)), "every grouped purpose and identity label fits its render extent")
		equal(actual_bounds.end.y, point.y + 49.0, "all grouped two-line labels retain the same conservative lower extent")
		check(SanctumCampusRenderer.visible_in_world_rect(actual_bounds, Rect2(point.x - 10.0, actual_label.end.y - 1.0, 20, 1)), "every grouped identity label survives bottom-edge viewport entry")
		var group := String(entry["service_group"])
		if group_bounds.has(group): equal(actual_bounds,group_bounds[group],"one directory uses one render extent regardless of action count")
		else: group_bounds[group]=actual_bounds
	equal(group_bounds.size(),4,"twelve commands produce only four shared directory marker bounds")
	for retired: int in range(201, 213):
		check(not layout.buildings_by_id.has(retired), "large-map rendering never restores a scrapped directory hut")
	for entry: Dictionary in layout.data.get("buildings", []):
		check(SanctumCampusRenderer.visible_in_world_rect(SanctumCampusRenderer.building_visual_bounds(entry), Rect2()), "full-map rendering includes every building without special-case IDs")
	equal(CanonicalContent.sha256(layout.data), before, "view calculations cannot change layout or interaction authority")


func _test_ground_style(kit: WellspringIllustratedKit) -> void:
	var style: RefCounted = kit.ground_style
	check(style != null and style.content_hash.length() == 64, "live ground binds the validated warm terrain derivative")
	equal(style.style_data.tiles.size(), 135, "warm ground retains all original terrain registrations")
	equal(Vector2i(int(style.style_data["size"][0]), int(style.style_data["size"][1])), Vector2i(1024, 180), "style adds one bounded720KiB decoded atlas, not per-character/map copies")
	var original := kit.pixel_map.tile_image("map.terrain.paving.fill_v1") as Image
	var current := style.tile_image("map.terrain.paving.fill_v1") as Image
	check(original.get_data() != current.get_data(), "live paving is genuinely restyled rather than only renamed")
	equal(current, style.tile_image("map.terrain.paving.fill_v1"), "repeated terrain access reuses the same prepared image")
	check(style.tile_image("map.prop.lectern") == null, "ground adapter cannot replace architectural props")
	for entry: Dictionary in style.style_data.tiles:
		var before := kit.pixel_map.tile_image(String(entry.id)) as Image
		var after := style.tile_image(String(entry.id)) as Image
		var same_alpha := true
		for y: int in 32:
			for x: int in 32:
				same_alpha = same_alpha and before.get_pixel(x, y).a == after.get_pixel(x, y).a
		check(same_alpha, "warm terrain preserves exact original alpha footprint for " + String(entry.id))
	for family: String in PixelMapLibrary.FAMILIES:
		for signature: int in 256:
			var valid := true
			for id: String in PixelMapLibrary.terrain_layers(family, signature & 15, signature >> 4):
				valid = valid and style.tile_image(id) != null
			check(valid, "warm terrain covers every original cardinal and diagonal neighborhood")
	var rejected: RefCounted = WellspringIllustratedKit.GroundStyle.new()
	check(not rejected.configure_style(null), "ground style rejects missing validated original pack")
	check(not rejected.configure_style(kit.pixel_map, "res://.godot/missing-ground-style.json"), "ground style rejects missing manifest")
	check(rejected.content_hash.is_empty() and rejected.tile_image("map.terrain.paving.fill_v1") == null, "failed style exposes no stale cached cells")
	check(rejected.configure_style(kit.pixel_map), "style can explicitly recover from valid source")
	check(not rejected.configure_style(PixelMapLibrary.new()), "invalid base clears a previously valid style")
	check(rejected.content_hash.is_empty() and rejected.tile_image("map.terrain.paving.fill_v1") == null, "failed reconfiguration cannot silently keep old styled pixels")


func _test_renderer_binding(layout: SanctumCampusLayout) -> void:
	var renderer := SanctumCampusRenderer.new()
	check(not renderer.configure_campus(layout), "campus cannot draw before visual-language setup")
	check(not renderer.last_error.is_empty(), "unconfigured campus failure is actionable")
	renderer.draw(null, layout, 120)
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for current campus binding")
	check(renderer.configure(language), "current campus initializes its actual presentation dependencies")
	check(renderer.configure_campus(layout), "current campus requires the illustrated map: " + renderer.last_error)
	check(renderer.illustrated_kit.content_hash.length() == 64, "current campus exposes its active map-art identity")
	check(renderer.illustrated_kit.ground_ready() and renderer.illustrated_kit.campus.canvas_size == layout.canvas_size, "region renderer binds the exact authoritative world envelope")
	check(renderer.natural_kit != null, "actor-contact and receiving-shadow support remains available")
	_test_floor_guides(renderer, layout, language)
	for property: Dictionary in renderer.get_property_list():
		check(String(property.name) not in ["architecture_kit", "wayfinding"], "current campus does not retain shadowed kit objects")
	var renderer_source: String = renderer.get_script().source_code
	for retired_dependency: String in ["WellspringArchitectureKit", "WellspringWayfinding", "_draw_district_identity", "configure_wayfinding"]:
		check(not renderer_source.contains(retired_dependency), "current campus has no dependency on retired startup seam " + retired_dependency)
	var content_before := CanonicalContent.sha256(layout.data)
	var previous_roof: WeakRef = weakref(renderer.illustrated_kit.roof_skins[104])
	var previous_tall: WeakRef = weakref(renderer.illustrated_kit.roof_skins[105])
	var previous_tower: WeakRef = weakref(renderer.illustrated_kit.roof_skins[108])
	check(not renderer.configure_campus(null), "missing map refuses even after a previous successful setup")
	check(renderer.illustrated_kit.ground == null and renderer.illustrated_kit.content_hash.is_empty(), "failed reconfiguration exposes no stale successful map")
	check(renderer.illustrated_kit.practice_skins.is_empty() and renderer.illustrated_kit.practice_skin_bytes == 0, "failed reconfiguration releases stale wall art")
	check(renderer.illustrated_kit.roof_skins.is_empty() and renderer.illustrated_kit.roof_skin_bytes == 0 and renderer.illustrated_kit.cached_roof_builds == 0, "failed reconfiguration releases stale roof textures and counters")
	check(previous_roof.get_ref() == null, "reload drops its ownership of the old roof texture instead of retaining a stale cache")
	check(previous_tall.get_ref() == null and previous_tower.get_ref() == null, "failed reconfiguration releases both full-footprint architecture textures")
	renderer.draw(null, layout, 120)
	# A genuinely failed active library load must not select historical map art.
	var saved_library := PixelMapLibrary.default_library()
	var missing_library := PixelMapLibrary.new()
	check(not missing_library.load_from_file("res://.godot/cleanup-20260908/missing-map-manifest.json"), "missing active map pack is rejected by its real loader")
	PixelMapLibrary._shared = missing_library
	var missing_accepted := renderer.configure_campus(layout)
	PixelMapLibrary._shared = saved_library
	check(not missing_accepted, "failed active pixel pack blocks the campus instead of enabling a legacy fallback")
	equal(renderer.last_error, missing_library.last_error, "active pack failure reaches the startup diagnostic unchanged")
	check(renderer.illustrated_kit.ground == null, "failed active pack leaves nothing drawable")
	check(renderer.configure_campus(layout), "restored validated pack permits explicit reconfiguration")
	equal(renderer.illustrated_kit.roof_skins.size(), 8, "recovery repopulates only the current eight roof textures")
	equal(renderer.illustrated_kit.cached_roof_builds, 8, "recovery counts only its current setup, not released roof builds")
	var recovered_tall: WeakRef = weakref(renderer.illustrated_kit.roof_skins[105])
	var recovered_tower: WeakRef = weakref(renderer.illustrated_kit.roof_skins[108])
	check(renderer.configure_campus(layout), "successful reconfiguration replaces the same current architecture cache")
	check(recovered_tall.get_ref() == null and recovered_tower.get_ref() == null, "successful reconfiguration does not retain replaced facade textures")
	equal(renderer.illustrated_kit.roof_skins.size(), 8, "reconfiguration retains only eight current roof/architecture textures")
	equal(renderer.illustrated_kit.roof_skin_bytes, 861440, "reconfiguration restores the exact bounded allocation")
	check(renderer.last_error.is_empty(), "successful recovery clears the previous diagnostic")
	equal(CanonicalContent.sha256(layout.data), content_before, "startup failures and recovery cannot alter gameplay content")
	check(not renderer.configure(null), "invalid language refuses a previously configured renderer")
	check(renderer.illustrated_kit == null and renderer.natural_kit == null, "invalid language clears previous drawing dependencies")
	equal(renderer.floor_mark_count, 0, "failed language binding clears all floor-guide state")


func _test_floor_guides(renderer: SanctumCampusRenderer, layout: SanctumCampusLayout, language: VisualLanguage) -> void:
	var before := CanonicalContent.sha256(layout.data)
	var descriptor := renderer.floor_guide_data.duplicate(true)
	equal(descriptor["stage_order"], ["source-court", "movement-garden", "crucible", "duel-court"], "practice loop teaches Commons, Movement, Crucible, then Sparring")
	var activity_labels: Dictionary[String, String] = {}
	for activity: Dictionary in layout.data.get("activity_areas", []):
		activity_labels[String(activity.get("id", ""))] = String(activity.get("label", ""))
	for index: int in range(descriptor["stages"].size()):
		var stage: Dictionary = descriptor["stages"][index]
		var activity_id := String(stage.get("activity", ""))
		var stage_label := String(stage.get("label", ""))
		equal(activity_id, String(descriptor["stage_order"][index]), "route stage %d keeps its ordered activity identity" % (index + 1))
		check(stage_label.begins_with("%d " % (index + 1)), "route stage %d displays its ordered ordinal" % (index + 1))
		check(activity_labels.has(activity_id), "route stage %d resolves an actual campus activity" % (index + 1))
		if activity_labels.has(activity_id):
			check(stage_label.contains(activity_labels[activity_id]), "route stage %d names its actual campus activity" % (index + 1))
	equal(renderer.floor_mark_count, 18, "four emblems, twelve route arrows and two validated experiment-link arrows remain bounded")
	equal(renderer.floor_labels.size(), 34, "twenty-four actual activity titles and ten existing short hints cover the expanded campus")
	equal(renderer.floor_guide_builds, 1, "floor vectors compile once when the campus binds")
	check(renderer.floor_guide_hash.length() == 64, "presentation descriptor has a separate content identity")
	check(renderer.floor_ink.size() > 0 and renderer.floor_trim.size() > 0, "both neutral-pigment batches contain actual geometry")
	check(renderer.floor_ink.size() + renderer.floor_trim.size() <= renderer.FLOOR_LINE_VERTEX_LIMIT, "complete floor guide stays below its fixed vertex budget")
	equal(renderer.floor_ink.size() % 2, 0, "ink contains complete line pairs")
	equal(renderer.floor_trim.size() % 2, 0, "trim contains complete line pairs")
	for point: Vector2 in renderer.floor_ink:
		check(point.is_finite() and Rect2(Vector2.ZERO, Vector2(layout.canvas_size)).has_point(point), "every visible emblem/arrow vertex stays inside the live map")
	for label: Dictionary in renderer.floor_labels:
		check(String(label.text).length() <= 28 and float(label.opacity) <= 0.68, "floor text remains bounded and visually subordinate")
		if String(label.text) == "2 MOVEMENT GARDEN":
			equal(label.anchor, Vector2(224, 448), "garden title clears the inherited Lodge facade instead of sitting beneath it")
	var practice_titles: Array[String] = []
	for label: Dictionary in renderer.floor_labels:
		practice_titles.append(String(label.text))
	for title: String in SanctumCampusRenderer.PRACTICE_TITLES.values():
		check(title in practice_titles, "real practice areas clearly display their distinct purpose: "+title)
	check("OPEN PRACTICE" in practice_titles,"the clear new passage visibly points toward experimentation")
	check("ELEMENT GARDEN" in practice_titles, "the new physical garden has an explicit floor title at its arrival forecourt")
	for title: String in ["SPRINT / SLIDE STRAIGHT", "OPTIONAL WALL CHAIN", "OPEN SPELL COURT"]:
		check(title in practice_titles, "larger southern playground visibly names each real training space: " + title)
	var old_workshop := SanctumCampusLayout.new()
	old_workshop.data = layout.data.duplicate(true)
	for building: Dictionary in old_workshop.data["buildings"]:
		if int(building["id"]) == 106: building["bounds"][2] = 384
	check(old_workshop.validate(),"old Workshop remains a valid map authority positive control")
	var blocked_link := SanctumCampusRenderer.new()
	check(blocked_link.configure(language),"blocked shortcut fixture has valid visual language")
	check(not blocked_link.prepare_floor_guides(old_workshop,descriptor),"a restored blocker cannot leave a false visual experiment shortcut")
	check(blocked_link.floor_ink.is_empty() and blocked_link.floor_labels.is_empty(),"blocked shortcut refuses incomplete floor guidance")
	var marker_ids: Array[String] = []
	for marker: Dictionary in descriptor.markers:
		marker_ids.append(String(marker.id))
	check("south-ordinary-bypass" in marker_ids and "wall-line-start" in marker_ids and "south-return" in marker_ids, "south loop distinguishes the ordinary bypass, optional wall line and return")
	var renderer_source: String = renderer.get_script().source_code
	var area_source := renderer_source.get_slice("func _draw_activity_areas(", 1).get_slice("\n\nstatic func ", 0)
	check(area_source.count("canvas.draw_multiline(") == 2, "two visible floor batches remain separate from flat landmark wayfinding")
	check(not renderer_source.contains("ImageTexture.create") and not renderer_source.contains("Image.create"), "floor guides generate no new raster textures")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["authority"] = "simulation",
		func(data: Dictionary) -> void: data["map_id"] = "another-map",
		func(data: Dictionary) -> void: data["stage_order"] = ["duel-court", "movement-garden", "crucible", "source-court"],
		func(data: Dictionary) -> void: data["stages"][0]["anchor"] = [1300, 240],
		func(data: Dictionary) -> void: data["stages"][0]["anchor"] = ["1472", 832],
		func(data: Dictionary) -> void: data["stages"][0]["emblem"] = "fire",
		func(data: Dictionary) -> void: data["stages"][1]["label_anchor"] = [300, 240],
		func(data: Dictionary) -> void: data["markers"][0]["route"] = "invented-shortcut",
		func(data: Dictionary) -> void: data["markers"][0]["anchor"] = [1300, 240],
		func(data: Dictionary) -> void: data["markers"][0]["direction"] = [1, 1],
		func(data: Dictionary) -> void: data["markers"][0]["direction"] = [0, 1],
		func(data: Dictionary) -> void: data["markers"][0]["hint"] = "A VERY LONG AND NOISY ROUTE LABEL",
		func(data: Dictionary) -> void: data["markers"][1]["id"] = data["markers"][0]["id"],
		func(data: Dictionary) -> void: data["markers"].append_array(data["markers"].duplicate(true)),
	]
	for mutate: Callable in mutations:
		var candidate := descriptor.duplicate(true)
		mutate.call(candidate)
		var rejected := SanctumCampusRenderer.new()
		check(rejected.configure(language), "invalid-guide fixture has the actual configured visual language")
		check(not rejected.prepare_floor_guides(layout, candidate), "unsafe, noisy or detached guide metadata fails closed")
		check(rejected.floor_ink.is_empty() and rejected.floor_trim.is_empty() and rejected.floor_labels.is_empty() and rejected.floor_guide_hash.is_empty(), "rejected guide leaves no partial or stale drawing state")
	equal(CanonicalContent.sha256(layout.data), before, "guide compilation and rejection never change any authority map field")
	equal(renderer.floor_guide_builds, 1, "guide inspection does not rebuild the production cache")
