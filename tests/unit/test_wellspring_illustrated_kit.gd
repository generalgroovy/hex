extends FluxTestSuite


func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "illustrated campus uses the live gameplay layout")
	var original := CanonicalContent.sha256(layout.data)
	var kit := WellspringIllustratedKit.new()
	check(not kit.configure(null), "illustrated campus refuses missing geometry")
	check(kit.configure(layout), "illustrated campus validates: " + kit.last_error)
	check(kit.content_hash.length() == 64, "presentation has a bounded content identity")
	equal(kit.ground.get_size(), Vector2(layout.canvas_size), "terrain matches the authoritative map envelope")
	equal(kit.cached_terrain_builds, 1, "terrain is composed once at setup")
	_test_ground_style(kit)
	equal(kit.tiles.size(), 16, "sixteen reusable material tiles load")
	equal(kit.PROP_IDS.size(), 16, "sixteen reusable props load")
	equal(kit.decorations.size(), 0, "non-worldbone decoration is withheld from the live campus")
	equal(String(kit.data["camera"]["ground_axes"]), "screen_cardinal", "painted elevation never skews input or aim")
	equal(int(kit.data["camera"]["art_elevation_degrees"]), 55, "characters and environment share the elevated art camera")
	check(int(kit.data["camera"]["maximum_facade_pixels"]) <= 64, "facades cannot steal large sections of play space")
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
	equal(kit.surface_at(Vector2(10, 10)), 8, "outer shore reads as water")
	for point: Vector2 in [Vector2(256, 2080), Vector2(848, 2080), Vector2(1120, 2080), Vector2(1888, 2080)]:
		check(kit.surface_at(point) != 8, "the live southern walk is land, not a hardcoded old shoreline")
	equal(kit.surface_at(Vector2(1536, layout.canvas_size.y - 32)), 8, "the new bottom boundary retains its quiet shoreline")
	check(layout.canvas_size.x / 32 <= 128 and layout.canvas_size.y / 32 <= 128, "the complete enlarged terrain stays within the tile composer's128x128 cap")
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
	equal(kit.cached_terrain_builds, 1, "inspection does not rebuild the floor")
	print("ILLUSTRATED_SETUP: %d ms; %d props; one terrain texture" % [kit.ground_generation_ms, kit.decorations.size()])
	_test_renderer_binding(layout)
	return finish("wellspring-illustrated-kit")


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
	equal(renderer.illustrated_kit.ground.get_size(), Vector2(layout.canvas_size), "current campus ground covers the authoritative envelope")
	check(renderer.natural_kit != null, "actor-contact and receiving-shadow support remains available")
	_test_floor_guides(renderer, layout, language)
	for property: Dictionary in renderer.get_property_list():
		check(String(property.name) not in ["architecture_kit", "wayfinding"], "current campus does not retain shadowed kit objects")
	var renderer_source: String = renderer.get_script().source_code
	for retired_dependency: String in ["WellspringArchitectureKit", "WellspringWayfinding", "_draw_district_identity", "configure_wayfinding"]:
		check(not renderer_source.contains(retired_dependency), "current campus has no dependency on retired startup seam " + retired_dependency)
	var content_before := CanonicalContent.sha256(layout.data)
	check(not renderer.configure_campus(null), "missing map refuses even after a previous successful setup")
	check(renderer.illustrated_kit.ground == null and renderer.illustrated_kit.content_hash.is_empty(), "failed reconfiguration exposes no stale successful map")
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
	equal(renderer.floor_mark_count, 16, "four emblems and twelve bounded route arrows include chemistry and configuration wayfinding")
	equal(renderer.floor_labels.size(), 16, "seven activity titles and nine short hints include chemistry and configuration routes")
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
	var marker_ids: Array[String] = []
	for marker: Dictionary in descriptor.markers:
		marker_ids.append(String(marker.id))
	check("south-ordinary-bypass" in marker_ids and "wall-line-start" in marker_ids and "south-return" in marker_ids, "south loop distinguishes the ordinary bypass, optional wall line and return")
	var renderer_source: String = renderer.get_script().source_code
	check(renderer_source.count("canvas.draw_multiline(") == 2, "two batched native floor-line calls replace many individual border/radial calls")
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
