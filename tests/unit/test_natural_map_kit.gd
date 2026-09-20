extends FluxTestSuite


func run() -> int:
	_test_repository_kit()
	_test_surface_resolution()
	_test_fail_closed_budget()
	return finish("natural-map-kit")


func _test_repository_kit() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for natural map kit")
	var kit := NaturalMapKit.new()
	check(kit.configure(language), "natural map kit validates: %s" % kit.last_error)
	check(kit.content_hash.length() == 64, "natural map kit has a stable content hash")
	equal(kit.profiles.size(), 3, "all live district styles own reusable natural recipes")
	check(float((kit.profiles["garden"] as Dictionary).get("edge_scale", 0.0)) > 1.0, "Conservatory scenic-edge props remain readable at overview zoom")
	for motion_id: String in ["walk", "sprint", "low", "air"]:
		check(kit.contact_profiles.has(motion_id), "%s has a surface-contact recipe" % motion_id)
	equal(kit.receiving_shadow_profiles.size(), 4, "water and all three ground families own receiving-shadow recipes")
	check(kit.elevation_shadow_opacity_step > 0.0, "receiving shadows expose a bounded elevation cue")
	var masonry_cell := kit.combat_floor.get("masonry_cell", []) as Array
	equal(Vector2i(int(masonry_cell[0]), int(masonry_cell[1])), Vector2i(40, 24), "combat floors use quiet staggered masonry rather than a debug grid")
	var pockets := NaturalMapKit.arena_safe_pockets(Rect2(0, 0, 600, 420), 54.0)
	equal(pockets.size(), 4, "proving floor exposes four readable response pockets")
	check(pockets[0].distance_to(pockets[2]) > 400.0, "response pockets preserve a broad central bullet lane")


func _test_surface_resolution() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for surface test")
	var kit := NaturalMapKit.new()
	check(kit.configure(language), "natural map kit loads for surface test")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus loads for surface test")
	equal(kit.surface_style_at(layout, Vector2(300, 720)), "garden", "conservatory resolves garden contact")
	equal(kit.surface_style_at(layout, Vector2(1280, 720)), "nexus", "commons resolves masonry contact")
	equal(kit.surface_style_at(layout, Vector2(2560, 720)), "proving", "wayfarer quarter resolves proving contact")
	equal(kit.surface_style_at(layout, Vector2(10, 10)), "nexus", "water/outside fails to conservative quiet contact")
	var water_shadow := kit.receiving_shadow_sample(layout, Vector2(10, 10))
	var garden_shadow := kit.receiving_shadow_sample(layout, Vector2(300, 720))
	var nexus_shadow := kit.receiving_shadow_sample(layout, Vector2(1280, 720))
	equal(String(water_shadow.get("surface_id", "")), "water", "deep water receives a distinct grounded shadow")
	equal(int(garden_shadow.get("elevation", -1)), 1, "garden receiving shadow reads authored elevation")
	equal(int(nexus_shadow.get("elevation", -1)), 2, "Nexus receiving shadow reads authored elevation")
	check(float(nexus_shadow.get("opacity_scale", 0.0)) > float(garden_shadow.get("opacity_scale", 0.0)), "higher masonry keeps a slightly firmer contact read")
	check((water_shadow.get("fill_color", Color.WHITE) as Color) != (nexus_shadow.get("fill_color", Color.WHITE) as Color), "water and masonry shadows use distinct material ramps")
	var open_path := PackedVector2Array([Vector2(0, 0), Vector2(20, 20), Vector2(40, 0)])
	var smoothed := NaturalMapKit.smoothed_path(open_path, 2)
	equal(smoothed[0], open_path[0], "smoothed route preserves its authored start")
	equal(smoothed[smoothed.size() - 1], open_path[open_path.size() - 1], "smoothed route preserves its authored finish")
	check(smoothed.size() > open_path.size(), "smoothed route adds bounded curve samples")


func _test_fail_closed_budget() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for invalid kit test")
	var source := NaturalMapKit.new()
	check(source.configure(language), "valid natural kit loads before mutation")
	var kit := NaturalMapKit.new()
	kit.language = language
	kit.data = source.data.duplicate(true)
	(kit.data["budgets"] as Dictionary)["maximum_details_per_district"] = 1000
	check(not kit.validate(), "unbounded map detail density fails closed")
	check(not kit.last_error.is_empty(), "natural map budget refusal is actionable")
	var shadow_kit := NaturalMapKit.new()
	shadow_kit.language = language
	shadow_kit.data = source.data.duplicate(true)
	(((shadow_kit.data["receiving_shadows"] as Dictionary)["profiles"] as Dictionary)["water"] as Dictionary)["rim_opacity"] = 0.9
	check(not shadow_kit.validate(), "overstated receiving-shadow rims fail closed")
	var arena_kit := NaturalMapKit.new()
	arena_kit.language = language
	arena_kit.data = source.data.duplicate(true)
	(((arena_kit.data["combat_floor"] as Dictionary)["arena"] as Dictionary)["marker_count"]) = 128
	check(not arena_kit.validate(), "unbounded arena marks fail closed")
