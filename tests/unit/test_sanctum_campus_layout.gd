extends FluxTestSuite


const CAMPUS_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"
const PRE_ANNEX_CONTENT_HASH := "1977f644057dd6a10c7bb3e08f2fd656456bc322a54d1281cf8179368aa45abf"
const WARM_TRAILS_AUTHORITY_HASH := "9e98cfe69c06deee0e6ed836f8cc6a8a55d9869915f19a6bb97f36edfbf6d726"


func run() -> int:
	_test_repository_layout()
	_test_collision_compilation()
	_test_invalid_layouts_fail_closed()
	_test_disconnected_graph_fails_closed()
	_test_custom_world_identity()
	_test_practice_groups()
	_test_practice_group_rejections()
	_test_south_annex_preserves_existing_campus()
	_test_floor_guide_authority_boundary()
	return finish("sanctum-campus-layout")


func _test_floor_guide_authority_boundary() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "practice wayfinding uses the current authoritative campus")
	equal(CanonicalContent.sha256(_historical_campus_with_original_loom_copy(layout.data)), WARM_TRAILS_AUTHORITY_HASH, "four-delivery A changes only the explicitly verified Loom copy; every other map field retains the exact warm-trails hash")
	check(not layout.data.has("floor_guides") and not layout.data.has("practice_wayfinding"), "floor-only guidance does not churn the network map fingerprint")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SanctumCampusRenderer.FLOOR_GUIDE_PATH))
	check(parsed is Dictionary, "guide data is a separately authored presentation descriptor")
	if parsed is Dictionary:
		equal(String(parsed.get("authority", "")), "presentation_only", "guide descriptor cannot add gameplay geometry")
		equal(String(parsed.get("map_id", "")), String(layout.data.id), "guide data binds the existing campus by identity")


func _historical_campus_with_original_loom_copy(current: Dictionary) -> Dictionary:
	var previous := current.duplicate(true)
	var found := 0
	for station: Dictionary in previous["stations"]:
		if station.get("id") != "spell-loom":
			continue
		found += 1
		equal(station["lines"], [
			"Choose Bolt, Heavy, Rapid or Spray",
			"Eight elements, including Air",
			"12 slots on 1-4, Ctrl and Alt",
			"Every character can use all 32 spells",
			"Bolt, Heavy and Rapid leave chemistry matter",
			"Spray does not; reaction areas still form from pairs",
		], "only the authorized four-delivery teaching replaces the old Loom copy")
		# Restore these six historical strings for the old full-map fingerprint;
		# no geometry, actor, route, station behavior or other copy is excluded.
		station["lines"] = [
			"Choose an element row and spell type",
			"12 slots on 1-4, Ctrl and Alt",
			"Drag a spell to a slot, or select and Assign",
			"Every character can use every listed spell",
			"Compare single and group hits at the Pattern Range",
			"Read pair effects in F4 - Chemistry",
		]
	equal(found, 1, "exactly one Loom station owns the changed copy")
	return previous


func _test_south_annex_preserves_existing_campus() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "southern annex validates through the production map loader")
	var previous := _historical_campus_with_original_loom_copy(layout.data)
	previous["canvas_size"] = [3072.0, 1728.0]
	for district: Dictionary in previous["districts"]:
		district["bounds"][3] = 1504.0
	previous["connections"] = previous["connections"].slice(0, 6)
	previous["routes"] = previous["routes"].slice(0, 9)
	previous["buildings"] = previous["buildings"].slice(0, 14)
	previous["activity_areas"] = previous["activity_areas"].slice(0, 6)
	equal(CanonicalContent.sha256(previous), PRE_ANNEX_CONTENT_HASH, "annex preserves every previous spawn, station, target, arena, wall, route, landmark and rule")
	check(layout.content_hash != PRE_ANNEX_CONTENT_HASH, "expanded content has a new host compatibility identity")
	equal(layout.data["connections"].size(), 7, "one new southern bridge joins existing quarters")
	equal(layout.data["routes"].size(), 12, "annex adds one wide loop, one optional wall line and one Bell return")
	equal(layout.data["activity_areas"].size(), 7, "one bounded southern movement activity is declared")
	var collision := layout.build_collision_world()
	for wall_id: int in [115, 116]:
		var found := false
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			if obstacle.obstacle_id == wall_id:
				found = true
				check(obstacle.wall_runnable and not obstacle.vaultable, "southern practice wall compiles to real wallrun geometry, never a vault")
		check(found, "southern worldbone has stable collision identity %d" % wall_id)
	var profiles := BodyTypeProfileCatalog.new()
	check(profiles.load_from_file(), "annex clearance checks all three current body profiles")
	for route: Dictionary in layout.data["routes"]:
		if String(route["id"]) not in ["conservatory-south-loop", "crucible-south-return"]:
			continue
		check(route["accessible"] and int(route["width"]) == 160, "southern bypass remains ordinary160px passage")
		var points: Array = route["points"]
		for index: int in range(points.size() - 1):
			var a := Vector2(SanctumCampusLayout._parse_point(points[index]))
			var b := Vector2(SanctumCampusLayout._parse_point(points[index + 1]))
			var samples := ceili(a.distance_to(b) / 8.0)
			for sample: int in range(samples + 1):
				var position := Vector2i(a.lerp(b, float(sample) / samples)) * SimConfig.FIXED_SCALE
				check(collision.can_occupy(position, 80_000), "every sampled bypass point preserves the full authored width")
				for body: String in BodyTypeProfileCatalog.BODY_TYPES:
					check(collision.can_occupy(position, MovementTuning.PLAYER_RADIUS), "shared18px movement clearance remains open for " + body)
					check(collision.can_occupy(position, profiles.hurt_radius(body)), "even the visible combat radius fits the broad bypass for " + body)


func _test_repository_layout() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "repository campus layout validates: %s" % layout.last_error)
	equal(String(layout.data.get("id")), "wellspring-campus-loop-v2", "campus layout id is stable")
	equal(layout.canvas_size, Vector2i(3072, 2304), "campus includes the bounded southern practice annex")
	equal(layout.viewport_size, Vector2i(1280, 720), "campus preserves the supported gameplay viewport")
	equal(layout.spawn, Vector2i(1536, 880), "campus spawn anchors the combined Nexus commons")
	check(layout.content_hash.length() == 64, "campus layout has a canonical content hash")
	equal(layout.districts_by_id.size(), 3, "related Sanctum functions are combined into three large quarters")
	for district_id: String in SanctumCampusLayout.REQUIRED_DISTRICTS:
		check(layout.districts_by_id.has(district_id), "required visible district exists: %s" % district_id)
	equal(layout.buildings_by_id.size(), 16, "original buildings plus two southern practice walls are registered")
	equal(layout.landmarks_by_id.size(), 6, "combined quarters retain multiple memorable landmarks")
	equal(layout.reset_zones_by_id.size(), 2, "movement and proving reset zones are explicit")
	equal(layout.stations_by_id.size(), 12, "play, movement practice, controls, spells, Farflow and host-stewardship stations are explicit")
	equal(layout.practice_targets_by_id.size(), 4, "comparison range and isolated Crucible target fit the current snapshot budget")
	equal(String(layout.arena_definition.get("id", "")), "proving-court-v1", "the first bounded arena has a stable authored identity")
	equal((layout.arena_definition.get("spawns", []) as Array).size(), 8, "arena reserves eight ordered spawn anchors")
	var hearth_station: Dictionary = layout.stations_by_id["session-hearth"]
	equal((hearth_station.get("gather_spawns", []) as Array).size(), 8, "Hearth reserves one rematch gather spawn per supported traveller")
	var effigy: Dictionary = layout.practice_targets_by_id["nexus-sparring-effigy"]
	equal(int(effigy.get("entity_id", 0)), 900, "sparring effigy has a stable simulation entity id")
	equal(int(effigy.get("health", 0)), 80_000, "sparring effigy has authored Health")
	equal(layout.elevation_at(Vector2i(1280, 720)), 2, "Nexus elevation is queryable without rendering")
	equal(layout.elevation_at(Vector2i(300, 720)), 1, "Conservatory elevation is queryable without rendering")
	equal(layout.elevation_at(Vector2i(10, 200)), 0, "water outside districts has no ground elevation")
	var represented_sources: Dictionary[String, bool] = {}
	for district_id: String in layout.districts_by_id:
		for source_value: Variant in (layout.districts_by_id[district_id] as Dictionary).get("combines", []):
			represented_sources[String(source_value)] = true
	for source_district_id: String in SanctumCampusLayout.REQUIRED_SOURCE_DISTRICTS:
		check(represented_sources.has(source_district_id), "combined campus retains source function area: %s" % source_district_id)
	for building_id: int in layout.buildings_by_id:
		var building: Dictionary = layout.buildings_by_id[building_id]
		check(not String(building.get("occlusion_policy", "")).is_empty(), "building %d declares foreground occlusion behavior" % building_id)


func _test_collision_compilation() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "campus loads for collision compilation")
	var collision: CollisionWorld = layout.build_collision_world()
	equal(collision.width, 3_072_000, "campus collision width uses fixed-point units")
	equal(collision.height, 2_304_000, "campus collision height uses fixed-point units")
	equal(collision.obstacles.size(), 16, "every authored building compiles to ordered collision")
	for index: int in range(collision.obstacles.size() - 1):
		check(collision.obstacles[index].obstacle_id < collision.obstacles[index + 1].obstacle_id, "campus obstacle ids are canonical")
	check(collision.can_occupy(layout.spawn * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "authored spawn has player clearance")
	for station_id: String in layout.stations_by_id:
		var station: Dictionary = layout.stations_by_id[station_id]
		check(collision.can_occupy(SanctumCampusLayout._parse_point(station["position"]) * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "station clearance: %s" % station_id)
	for target_id: String in layout.practice_targets_by_id:
		var target: Dictionary = layout.practice_targets_by_id[target_id]
		check(collision.can_occupy(SanctumCampusLayout._parse_point(target["position"]) * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "target clearance: %s" % target_id)
	for gather_value: Variant in (layout.stations_by_id["session-hearth"] as Dictionary).get("gather_spawns", []):
		var gather_values: Array = gather_value
		check(collision.can_occupy(Vector2i(int(gather_values[0]), int(gather_values[1])) * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "Hearth gather spawn has authored collision clearance")
	check(not collision.can_occupy(Vector2i(300_000, 240_000), MovementTuning.PLAYER_RADIUS), "lodge collision matches visible bounds")
	for obstacle: CollisionWorld.Obstacle in collision.obstacles:
		check(not obstacle.vaultable, "no campus obstacle offers vaulting")


func _test_invalid_layouts_fail_closed() -> void:
	var source := SanctumCampusLayout.new()
	check(source.load_from_file(CAMPUS_PATH), "campus loads as invalid-layout source")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["schema_version"] = 99,
		func(data: Dictionary) -> void: data["canvas_size"] = [1280, 720],
		func(data: Dictionary) -> void: data["required_districts"] = ["nexus-court"],
		func(data: Dictionary) -> void: (data["connections"][0] as Dictionary)["to"] = "missing-district",
		func(data: Dictionary) -> void: (data["routes"][0] as Dictionary)["points"] = [[-1, 200], [20, 200]],
		func(data: Dictionary) -> void: (data["routes"][0] as Dictionary)["kind"] = "teleport",
		func(data: Dictionary) -> void: (data["routes"][1] as Dictionary)["width"] = 400,
		func(data: Dictionary) -> void: (data["routes"][1] as Dictionary)["points"] = [[82, 720], [1500, 720]],
		func(data: Dictionary) -> void: (data["reset_zones"][0] as Dictionary)["bounds"] = [800, 1200, 300, 300],
		func(data: Dictionary) -> void: (data["arena"] as Dictionary)["score_limit"] = 99,
		func(data: Dictionary) -> void: (data["arena"] as Dictionary)["spawns"] = [[1900, 860]],
		func(data: Dictionary) -> void: (data["arena"] as Dictionary)["bounds"] = [0, 0, 100, 100],
		func(data: Dictionary) -> void: (data["stations"][0] as Dictionary)["command"] = "open_detached_menu",
		func(data: Dictionary) -> void: (data["stations"][0] as Dictionary)["interaction_radius"] = 900,
		func(data: Dictionary) -> void: (data["stations"][0] as Dictionary)["lines"] = "too vague",
		func(data: Dictionary) -> void: (data["stations"][0] as Dictionary)["position"] = [1400, 240],
		func(data: Dictionary) -> void: (data["stations"][8] as Dictionary)["gather_spawns"] = [[2080, 620]],
		func(data: Dictionary) -> void: ((data["stations"][8] as Dictionary)["gather_spawns"] as Array)[0] = [2300, 620],
		func(data: Dictionary) -> void: ((data["stations"][8] as Dictionary)["gather_spawns"] as Array)[1] = [2144, 620],
		func(data: Dictionary) -> void: (data["practice_targets"][0] as Dictionary)["health"] = 0,
		func(data: Dictionary) -> void: (data["practice_targets"][0] as Dictionary)["entity_id"] = 1,
		func(data: Dictionary) -> void: (data["practice_targets"][0] as Dictionary)["position"] = [2400, 240],
		func(data: Dictionary) -> void: (data["buildings"][0] as Dictionary)["occlusion_policy"] = "always_xray",
		func(data: Dictionary) -> void: (data["buildings"][0] as Dictionary)["worldbone"] = false,
		func(data: Dictionary) -> void: (data["buildings"][9] as Dictionary)["vaultable"] = true,
		func(data: Dictionary) -> void: (data["landmarks"][0] as Dictionary)["position"] = [2550, 1430],
		func(data: Dictionary) -> void: (data["buildings"][4] as Dictionary)["bounds"] = [1520, 864, 60, 60],
	]
	for mutation: Callable in mutations:
		var candidate := SanctumCampusLayout.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(), "invalid campus mutation fails closed")
		check(not candidate.last_error.is_empty(), "invalid campus mutation is diagnosable")


func _test_disconnected_graph_fails_closed() -> void:
	var source := SanctumCampusLayout.new()
	check(source.load_from_file(CAMPUS_PATH), "campus loads as disconnected-graph source")
	var candidate := SanctumCampusLayout.new()
	candidate.data = source.data.duplicate(true)
	for value: Variant in candidate.data["connections"]:
		var connection: Dictionary = value
		if connection["to"] == "wayfarer-proving-quarter":
			connection["to"] = "conservatory-gardens"
			connection["points"] = [[1104, 832], [848, 832]]
	check(not candidate.validate(), "duplicate bridge count cannot hide a disconnected district")
	check("connected district graph" in candidate.last_error, "disconnected district failure is actionable")


func _test_custom_world_identity() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "campus loads for world identity")
	var campus_world := SimWorld.new(120, 99, layout.build_collision_world(), String(layout.data.get("id")), layout.content_hash)
	var foundation_world := SimWorld.new(120, 99)
	equal(campus_world.map_id, "wellspring-campus-loop-v2", "world owns the authored map id")
	equal(campus_world.map_hash, layout.content_hash, "world owns the authored map hash")
	check(campus_world.state_hash() != foundation_world.state_hash(), "authored map identity changes canonical world state")


func _test_practice_groups() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "practice groups load: %s" % layout.last_error)
	equal(layout.practice_groups_by_id.size(), 2, "two complementary practice setups are explicit")
	equal(layout.practice_lanes.size(), 4, "every dummy owns a target-linked firing lane")
	check(layout.practice_targets_by_id.size() <= SessionSnapshot.MAX_TARGETS, "all authored targets can be replicated without silent omission")
	check(layout.practice_targets_by_id.size() + SessionSnapshot.MAX_PLAYERS <= ElementChemistrySystem.MAX_TRACKED_ACTORS, "full lobby plus targets fits bounded chemistry contact tracking")
	var range_group: Dictionary = layout.practice_groups_by_id["pattern-comparison"]
	equal(range_group["target_ids"].size(), 3, "comparison range retains three targets for pattern tests")
	var left := SanctumCampusLayout._parse_point(layout.practice_targets_by_id["nexus-sparring-effigy"]["position"])
	var center := SanctumCampusLayout._parse_point(layout.practice_targets_by_id["range-effigy-center"]["position"])
	var right := SanctumCampusLayout._parse_point(layout.practice_targets_by_id["range-effigy-east"]["position"])
	equal(center - left, Vector2i(120, 0), "first gap permits comparison of precise and between-target aim")
	equal(right - center, Vector2i(120, 0), "comparison gaps are symmetric")
	# Use the actual authored blast radius to preserve the range's single-hit
	# versus between-target group-hit teaching contract after gameplay retunes.
	var comparison_reach := int(CombatTuning.cast_definition(179)["blast_radius"]) / SimConfig.FIXED_SCALE + int(layout.practice_targets_by_id["nexus-sparring-effigy"]["radius"])
	check(left.distance_squared_to(center) > comparison_reach * comparison_reach, "directly centred heavy blast need not automatically hit its neighbor")
	check(left.distance_squared_to(right) > comparison_reach * comparison_reach, "centered heavy blast still excludes the far comparison target")
	check(left.distance_squared_to((left + center) / 2) < comparison_reach * comparison_reach, "between-target aim can cover both comparison targets")
	var collision := layout.build_collision_world()
	for lane: Dictionary in layout.practice_lanes:
		var target: Dictionary = layout.practice_targets_by_id[lane["target_id"]]
		equal(lane["end"], SanctumCampusLayout._parse_point(target["position"]), "rendered lane endpoint cannot drift from target content")
		var start := Vector2(lane["start"])
		var end := Vector2(lane["end"])
		var half_width := int(lane["width"]) / 2
		for index: int in range(33):
			var point := Vector2i(start.lerp(end, index / 32.0)) * SimConfig.FIXED_SCALE
			check(collision.can_occupy(point, half_width * SimConfig.FIXED_SCALE), "authored firing lane has continuous worldbone clearance")
		for station: Dictionary in layout.stations_by_id.values():
			var station_position := Vector2(SanctumCampusLayout._parse_point(station["position"]))
			var nearest := Geometry2D.get_closest_point_to_segment(station_position, start, end)
			var distance := float(int(station["interaction_radius"]) + half_width)
			check(station_position.distance_squared_to(nearest) >= distance * distance, "practice lane does not shoot through a station interaction area")
	for group: Dictionary in layout.practice_groups_by_id.values():
		var bounds := SanctumCampusLayout._parse_bounds(group["bounds"])
		for building: Dictionary in layout.buildings_by_id.values():
			check(not bounds.intersects(SanctumCampusLayout._parse_bounds(building["bounds"])), "practice pad remains an unobstructed experimentation space")
		check(ThemeDB.fallback_font.get_string_size(String(group["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 224, "practice heading fits its real rendered label width")
		check(ThemeDB.fallback_font.get_string_size(String(group["purpose"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 224, "practice instruction fits its real rendered label width")
	var bell := " ".join(layout.stations_by_id["training-reset"]["lines"])
	check(bell.contains("three seconds") and TrainingTargetSystem.RESPAWN_DELAY_MS == 3000, "practice bell accurately teaches existing automatic respawn")
	check(not " ".join(layout.stations_by_id["spell-loom"]["lines"]).contains("16 spells"), "Spell Loom instruction cannot pin a stale catalog count")
	var second := SanctumCampusLayout.new()
	check(second.load_from_file(CAMPUS_PATH), "second group validation loads")
	equal(second.practice_lanes, layout.practice_lanes, "compiled firing cues are deterministic")
	check(second.validate(), "revalidation of groups succeeds")
	equal(second.practice_lanes.size(), 4, "revalidation cannot accumulate duplicate lanes")
	# Existing source-driven spawn path supports every new target without a new
	# lifecycle implementation; prove all four return to their authored anchors.
	for target: Dictionary in layout.practice_targets_by_id.values():
		var actor := PlayerState.new(int(target["entity_id"]))
		actor.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		actor.health_maximum = int(target["health"])
		actor.health = 0
		actor.training_spawn_x = int(target["position"][0]) * SimConfig.FIXED_SCALE
		actor.training_spawn_y = int(target["position"][1]) * SimConfig.FIXED_SCALE
		actor.training_respawn_ticks = 1
		equal(TrainingTargetSystem.step_target(actor, SimConfig.new(120)), TrainingTargetSystem.RESPAWN_EVENT, "every authored practice target uses the existing safe respawn path")
		equal(Vector2i(actor.position_x, actor.position_y), SanctumCampusLayout._parse_point(target["position"]) * SimConfig.FIXED_SCALE, "practice actor returns to the same group anchor")


func _test_practice_group_rejections() -> void:
	var source := SanctumCampusLayout.new()
	check(source.load_from_file(CAMPUS_PATH), "practice rejection fixture loads")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["practice_groups"] = [],
		func(data: Dictionary) -> void: data["practice_groups"] = "unbounded",
		func(data: Dictionary) -> void: data["practice_targets"].append(data["practice_targets"][0].duplicate(true)),
		func(data: Dictionary) -> void: data["practice_groups"][0]["target_ids"][0] = "missing",
		func(data: Dictionary) -> void: data["practice_groups"][0]["target_ids"][1] = data["practice_groups"][0]["target_ids"][0],
		func(data: Dictionary) -> void: data["practice_groups"][0]["firing_anchors"] = [],
		func(data: Dictionary) -> void: data["practice_groups"][0]["firing_anchors"][0] = [2464, 352],
		func(data: Dictionary) -> void: data["practice_groups"][0]["lane_width"] = 200,
		func(data: Dictionary) -> void: data["practice_groups"][0]["bounds"] = [2304, 224, 448, 416],
		func(data: Dictionary) -> void: data["practice_groups"][0]["label_anchor"] = [2900, 620],
		func(data: Dictionary) -> void: data["practice_groups"][0]["purpose"] = "x".repeat(41),
		func(data: Dictionary) -> void: data["practice_targets"][1]["position"] = [2488, 352],
		func(data: Dictionary) -> void: data["stations"][1]["position"] = [1568, 1360],
	]
	for mutation: Callable in mutations:
		var candidate := SanctumCampusLayout.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(), "unsafe or misleading practice layout fails closed")
		check(not candidate.last_error.is_empty(), "practice rejection explains why the layout is unsafe")
