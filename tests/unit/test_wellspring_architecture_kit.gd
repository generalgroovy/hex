extends FluxTestSuite


func run() -> int:
	_test_repository_kit()
	_test_live_coverage()
	_test_archive_geometry_helpers()
	_test_fail_closed_contract()
	return finish("wellspring-architecture-kit")


func _test_repository_kit() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for architecture kit")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus loads for architecture kit")
	var kit := WellspringArchitectureKit.new()
	check(kit.configure(language, layout), "architecture kit validates: %s" % kit.last_error)
	check(kit.content_hash.length() == 64, "architecture kit has a stable content hash")
	check(kit.runtime_kit != null and kit.runtime_kit.textures_by_id.size() == 8, "architecture reuses every approved pixel module through the validated runtime kit")
	check(kit.environment_kit != null and kit.environment_kit.textures_by_id.size() == 16, "architecture binds the complete reusable environment module sheet")
	equal(String((kit.data["court_profile"] as Dictionary).get("district_style")), "nexus", "source court is bound to the Nexus presentation profile")
	equal(kit.court_decorations.size(), 6, "source court has a bounded authored decoration set")
	equal(String(kit.court_decorations[0].get("kind", "")), "lantern", "source court starts with a readable light marker")
	equal(int(kit.surface_alignment.get("collision_marker_length", 0)), 12, "building collision corners use one editable marker contract")
	equal(int(kit.surface_alignment.get("door_threshold_width", 0)), 34, "building thresholds share one readable approach width")
	equal(kit.building_profiles.size(), WellspringArchitectureKit.BUILDING_STYLES.size(), "every architecture style has one reusable profile")
	equal(kit.station_profiles.size(), WellspringArchitectureKit.STATION_KINDS.size(), "every station kind has one furniture profile")
	equal(kit.landmark_profiles.size(), WellspringArchitectureKit.LANDMARK_KINDS.size(), "every landmark kind has one frame profile")


func _test_live_coverage() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for live architecture coverage")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus loads for live architecture coverage")
	var kit := WellspringArchitectureKit.new()
	check(kit.configure(language, layout), "architecture kit loads for live coverage")
	for building: Dictionary in layout.buildings_by_id.values():
		var style := String(building.get("style", ""))
		check(style == "practice_wall" or kit.building_profiles.has(style), "live building style %s has modular art" % style)
	for station: Dictionary in layout.stations_by_id.values():
		var kind := String(station.get("kind", ""))
		check(kit.station_profiles.has(kind), "live station kind %s has furniture" % kind)
	for landmark: Dictionary in layout.landmarks_by_id.values():
		var kind := String(landmark.get("kind", ""))
		check(kit.landmark_profiles.has(kind), "live landmark kind %s has a frame" % kind)


func _test_archive_geometry_helpers() -> void:
	# These retained standalone-kit helpers are not live campus startup inputs.
	var kit := WellspringArchitectureKit.new()
	var footprint := Rect2(100, 100, 80, 64)
	var markers := WellspringArchitectureKit.collision_corner_segments(footprint, 12.0, 2.0)
	equal(markers.size(), 8, "four collision corners expose two exact approach markers each")
	equal(markers[0], PackedVector2Array([Vector2(102, 100), Vector2(114, 100)]), "north-west marker follows the exact collision edge")
	equal(markers[7], PackedVector2Array([Vector2(180, 150), Vector2(180, 162)]), "south-east marker follows the exact collision edge")
	equal(WellspringArchitectureKit.door_threshold_rect(footprint, 34.0, 6.0), Rect2(123, 164, 34, 6), "door threshold begins outside the collision footprint")
	equal(kit.cutaway_amount(footprint, Vector2(20, 20)), 0.0, "archive cutaway preserves distant architecture")
	equal(kit.cutaway_amount(footprint, Vector2(140, 100)), 1.0, "archive cutaway exposes a near approach")
	check(kit.cutaway_amount(footprint, Vector2(140, 58)) > 0.0, "archive cutaway eases at its outer boundary")
	equal(kit.cutaway_amount(Rect2(), Vector2.ZERO), 0.0, "archive empty footprint cannot create a cutaway")


func _test_fail_closed_contract() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads before architecture mutation")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus loads before architecture mutation")
	var source := WellspringArchitectureKit.new()
	check(source.configure(language, layout), "valid architecture kit loads before mutation")
	var kit := WellspringArchitectureKit.new()
	kit.language = language
	kit.data = source.data.duplicate(true)
	(kit.data["budgets"] as Dictionary)["maximum_facade_ratio"] = 0.90
	check(not kit.validate(layout), "facades that can steal the play footprint fail closed")
	check(not kit.last_error.is_empty(), "architecture refusal is actionable")
	var decoration_kit := WellspringArchitectureKit.new()
	decoration_kit.language = language
	decoration_kit.data = source.data.duplicate(true)
	((decoration_kit.data["court_profile"] as Dictionary)["decorations"] as Array)[0]["offset"] = [999, 0]
	check(not decoration_kit.validate(layout), "court decorations outside the playable floor fail closed")
	var surface_kit := WellspringArchitectureKit.new()
	surface_kit.language = language
	surface_kit.data = source.data.duplicate(true)
	(surface_kit.data["surface_alignment"] as Dictionary)["cutaway_fade_distance"] = 99
	check(not surface_kit.validate(layout), "cutaway margins that cannot interpolate exactly fail closed")
