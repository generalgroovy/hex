extends FluxTestSuite

const Library = preload("res://src/presentation/pixel_map_library.gd")
const Kit = preload("res://src/presentation/wellspring_illustrated_kit.gd")


func run() -> int:
	var library := Library.new()
	check(library.load_from_file(), "supplied map pack validates and decodes: " + library.last_error)
	check(library.content_hash.length() == 64, "map manifest has a stable presentation identity")
	equal(library.textures.size(), 4, "exactly four category atlas textures are cached")
	equal(library.data.assets.size(), 250, "all supplied map modules remain independently addressable")
	check(library.palette_status.contains("provisional"), "palette caveat remains truthful until visual acceptance")
	var frames := 0
	for asset: Dictionary in library.data.assets:
		var tick := 0
		for definition: Dictionary in asset.atlas_frames:
			var frame := library.sample(String(asset.id), tick)
			var rect: Array = definition.rect
			equal(frame.region, Rect2(rect[0], rect[1], rect[2], rect[3]), "frame sampling honors supplied atlas rectangles")
			equal(frame.pivot, Vector2(asset.pivot_px[0], asset.pivot_px[1]), "frame sampling preserves authored ground anchor")
			check(frame.is_read_only(), "cached frame records cannot be mutated by presenters")
			frames += 1
			tick += int(definition.duration_ticks)
		if bool(asset.loop):
			equal(library.sample(String(asset.id), tick), library.sample(String(asset.id), 0), "ambient loop wraps at exact120Hz duration")
			equal(library.sample(String(asset.id), tick / 2, true), library.sample(String(asset.id), 0), "Reduced Effects freezes cosmetic ambient motion")
	equal(frames, 274, "all274 supplied frames are usable at declared timings")
	check(library.sample("map.missing").is_empty(), "unknown map module fails closed")
	check(not library.draw(null, "map.prop.lectern", Vector2.ZERO), "missing canvas is safe")
	_test_manifest_rejection(library)
	_test_terrain(library)
	_test_live_ground()
	return finish("pixel-map-library")


func _test_manifest_rejection(library: PixelMapLibrary) -> void:
	var changed := library.data.duplicate(true)
	changed.usage_authority.collision_authority = true
	check(not library.validate_manifest(changed), "map art cannot claim gameplay collision authority")
	changed = library.data.duplicate(true)
	changed.atlases[0].path = "../outside.png"
	check(not library.validate_manifest(changed), "atlas path traversal is rejected")
	changed = library.data.duplicate(true)
	changed.assets[0].atlas_frames[0].rect = [0, 0, 9999, 9999]
	check(not library.validate_manifest(changed), "out-of-atlas frame bounds are rejected")
	changed = library.data.duplicate(true)
	changed.assets[0].atlas_frames[0].duration_ticks = 0
	check(not library.validate_manifest(changed), "zero frame duration is rejected")
	changed = library.data.duplicate(true)
	changed.assets[0].id = changed.assets[1].id
	check(not library.validate_manifest(changed), "duplicate asset identity is rejected")
	check(library.validate_manifest(library.data), "unmodified supplied metadata remains valid")


func _test_terrain(library: PixelMapLibrary) -> void:
	for family: String in Library.FAMILIES:
		for signature: int in range(256):
			var layers := Library.terrain_layers(family, signature & 15, signature >> 4)
			check(not layers.is_empty(), "every terrain neighborhood has a base")
			for id: String in layers:
				var image := library.tile_image(id)
				check(image != null and image.get_size() == Vector2i(32, 32), "every neighborhood layer uses supplied32px raster")
		for mask: int in range(16):
			var image := library.tile_image("map.terrain.%s.mask_%02d" % [family, mask])
			for coordinate: int in range(32):
				check(image.get_pixel(coordinate, 0).a == 1.0 and image.get_pixel(0, coordinate).a == 1.0, "terrain bases have no transparent edge gaps")
	var grid: Array[String] = ["grass", "grass", "grass", "grass", "paving", "grass", "grass", "grass", "grass"]
	var image := library.compose_ground(grid, 3, 3)
	equal(image.get_size(), Vector2i(96, 96), "terrain assembly preserves exact existing32px cell size")
	var centre := library.tile_image("map.terrain.paving.mask_00")
	equal(image.get_pixel(48, 48), centre.get_pixel(16, 16), "mixed terrain retains source material pixels without resampling")
	check(library.compose_ground(grid, 4, 4) == null, "incomplete material grid is rejected")
	check(library.compose_ground([], 129, 129) == null, "terrain composition budget is bounded")
	equal(Kit.pixel_family(8), "water", "existing shoreline classification maps to supplied water")
	equal(Kit.pixel_family(4), "grass", "existing gardens map to supplied grass")
	equal(Kit.pixel_family(13), "worldbone", "existing advanced-route material stays distinct")


func _test_live_ground() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "live map layout loads")
	var original := CanonicalContent.sha256(layout.data)
	var kit := Kit.new()
	check(kit.configure(layout), "live map renderer integrates supplied ground and prop atlas: " + kit.last_error)
	equal(kit.ground.get_size(), Vector2(layout.canvas_size), "new raster ground preserves full live map envelope")
	equal(kit.cached_terrain_builds, 1, "new terrain is composed only once during setup")
	check(kit.pixel_map != null and not kit.pixel_map.content_hash.is_empty(), "live map kit actually references new asset library")
	equal(kit.decorations.size(), 0, "integration invents no new decorative obstacles")
	equal(CanonicalContent.sha256(layout.data), original, "terrain and prop preparation cannot change gameplay layout")
	check(kit.ground_style != null and not kit.ground_style.content_hash.is_empty(), "live ground uses the isolated validated warm terrain derivative")
	print("PIXEL_MAP_SETUP: %dms;4 retained atlas textures;one warm ground texture;one setup-only terrain derivative" % kit.ground_generation_ms)
