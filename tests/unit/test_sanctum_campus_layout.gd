extends FluxTestSuite


const CAMPUS_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"
const DIRECTORY_BASELINE_PATH := "res://tests/fixtures/campus_before_directories_20260928.json"
const DIRECTORY_BASELINE_SHA256 := "b0949fc129e353b0458e9514fbb4b15e2597024103b7b34a1d5fa1b3e0683f8c"
const PRE_ANNEX_CONTENT_HASH := "1977f644057dd6a10c7bb3e08f2fd656456bc322a54d1281cf8179368aa45abf"
const WARM_TRAILS_AUTHORITY_HASH := "9e98cfe69c06deee0e6ed836f8cc6a8a55d9869915f19a6bb97f36edfbf6d726"
const GARDEN_BASELINE_PATH := "res://tests/fixtures/campus_before_element_garden_20261009.json"
const GARDEN_BASELINE_SHA256 := "0d9b23bda9f925e4f172aa70f316b28567089138b8ed58211b79cfde9575800e"
const EXPEDITION_BASELINE_PATH := "res://tests/fixtures/campus_before_expeditions_20261009.json"
const EXPEDITION_BASELINE_SHA256 := "ec13a6ad81a57625584f217a3fe3c8e070b25ba5705ffcbbcf77f1229bea33ec"


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
	_test_contextual_practice_copy()
	_test_playground_routes()
	_test_service_door_geometry()
	_test_directory_map_delta()
	_test_open_experiment_passage()
	_test_south_training_extension()
	_test_expedition_preservation_and_routes()
	_test_travel_destinations()
	_test_expedition_rejections()
	_test_element_garden_geometry()
	_test_element_garden_rejections()
	return finish("sanctum-campus-layout")


func _test_contextual_practice_copy() -> void:
	var anchor := Vector2(720, 960)
	check(SanctumCampusRenderer.practice_instruction_opacity(anchor, anchor) == 1.0, "nearby practice instructions remain fully legible")
	check(SanctumCampusRenderer.practice_instruction_opacity(anchor, anchor + Vector2(220, 0)) == 1.0, "instruction near boundary is stable")
	check(SanctumCampusRenderer.practice_instruction_opacity(anchor, anchor + Vector2(360, 0)) == 0.0, "far instructions do not clutter combat view")
	check(SanctumCampusRenderer.practice_instruction_opacity(anchor, Vector2(-1000000, -1000000)) == 1.0, "unfocused overview keeps instructional content")
	check(SanctumCampusRenderer.practice_instruction_opacity(anchor, Vector2(NAN, 0)) == 1.0, "invalid focus cannot permanently suppress instructions")
	equal(SanctumCampusRenderer.practice_instruction_opacity(anchor, Vector2(-1000000, -1000000), Rect2(), false), 0.0, "static unseen terrain excludes contextual instructions even with overview focus")
	equal(SanctumCampusRenderer.practice_instruction_opacity(anchor, anchor, Rect2(), false), 0.0, "disabled context never bakes a nearby instruction into a backdrop")
	var backdrop_source := FileAccess.get_file_as_string("res://src/presentation/pov_terrain_backdrop.gd")
	# The final court context changes the objective plaque only; proximity details
	# and station titles remain disabled (also exercised by pov-terrain-context).
	check(backdrop_source.contains("true, false, world_rect, false, court_context)"), "static POV renderer explicitly disables contextual copy without removing navigation")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
		var previous := 1.0
		for distance: int in range(0, 481, 8):
			var opacity := SanctumCampusRenderer.practice_instruction_opacity(anchor, anchor + direction * float(distance))
			check(opacity >= 0.0 and opacity <= previous + 0.00001, "practice detail fades monotonically in every travel direction")
			previous = opacity
	check(not SanctumCampusRenderer.visible_in_world_rect(Rect2(anchor, Vector2(228, 36)), Rect2(0, 0, 640, 400)), "offscreen practice text is conservatively skipped")
	check(SanctumCampusRenderer.visible_in_world_rect(Rect2(anchor, Vector2(228, 36)), Rect2(800, 900, 640, 400)), "partly visible practice labels remain drawn")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "contextual copy uses real authored practice areas")
	for group: Dictionary in layout.practice_groups_by_id.values():
		var label := Vector2(SanctumCampusLayout._parse_point(group["label_anchor"]))
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(group["bounds"]))
		equal(SanctumCampusRenderer.practice_instruction_opacity(label, label, bounds), 1.0, "approaching a practice label reveals its instructions")
		equal(SanctumCampusRenderer.practice_instruction_opacity(label, bounds.get_center(), bounds), 1.0, "practice area center retains instructions")
		for firing: Array in group["firing_anchors"]:
			equal(SanctumCampusRenderer.practice_instruction_opacity(label, Vector2(SanctumCampusLayout._parse_point(firing)), bounds), 1.0, "every real firing lane retains complete instructions")
		equal(SanctumCampusRenderer.practice_instruction_opacity(label, bounds.end + Vector2(700, 700), bounds), 0.0, "distant practice areas do not retain instructional clutter")


func _test_playground_routes() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "new playground uses production collision and map validation")
	var collision := layout.build_collision_world()
	for route: Dictionary in layout.data["routes"]:
		if String(route.id) not in ["south-chain-line", "south-proving-loop", "cover-weave-line"]:
			continue
		for index: int in range(route.points.size() - 1):
			var a := Vector2(SanctumCampusLayout._parse_point(route.points[index]))
			var b := Vector2(SanctumCampusLayout._parse_point(route.points[index + 1]))
			var samples := ceili(a.distance_to(b) / 4.0)
			for sample: int in range(samples + 1):
				var point := Vector2i(a.lerp(b, float(sample) / samples) * SimConfig.FIXED_SCALE)
				check(collision.can_occupy(point, MovementTuning.PLAYER_RADIUS), "each new marked route has continuous shared wall clearance: " + String(route.id))
	for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
		if obstacle.obstacle_id >= 117 and obstacle.obstacle_id <= 123:
			check(obstacle.wall_runnable and not obstacle.vaultable, "each new visible wall offers real wallrun and projectile cover")
	var topology := HexWorldDefinition.from_campus(layout)
	check(topology != null, "expanded practice footprint stays within the existing whole-map hex cap")
	if topology != null:
		equal(topology.eligible_cells.size(), 59466, "expanded whole-map chemistry matches independent fixed-integer polygon/obstacle enumeration")
		check(topology.eligible_cells.size() <= HexChemistryWorld.MAX_CELLS, "larger playground preserves the existing finite cell cap")


func _test_service_door_geometry() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "service geometry validates all canonical full-width ordinary routes")
	var collision := layout.build_collision_world()
	var directories := {
		"training": [101, ["movement-guide", "controls-lectern"]],
		"academy": [104, ["champion-loom", "spell-loom"]],
		"farflow": [109, ["farflow-host", "farflow-join", "farflow-charter", "session-hearth", "company-ledger", "parting-bell"]],
		"practice": [103, ["training-reset", "momentum-chime"]],
	}
	var seen := {}
	for group: String in directories:
		var building_id := int(directories[group][0])
		check(layout.buildings_by_id.has(building_id), "directory reuses a canonical existing building")
		var building: Dictionary = layout.buildings_by_id[building_id]
		var rectangle := Rect2(SanctumCampusLayout._parse_bounds(building["bounds"]))
		check(building["worldbone"] and not building["vaultable"], "existing directory buildings retain solid non-vault worldbone")
		check(not collision.can_occupy(Vector2i(rectangle.get_center() * SimConfig.FIXED_SCALE), MovementTuning.PLAYER_RADIUS), "existing visible building cannot be walked through")
		var door := Vector2(rectangle.get_center().x,rectangle.end.y+24)
		for station_id: String in directories[group][1]:
			check(not seen.has(station_id), "each action has one directory membership")
			seen[station_id] = true
			var station: Dictionary = layout.stations_by_id[station_id]
			equal(String(station["service_group"]), group, "related actions share their intended directory")
			equal(int(station["building_id"]), building_id, "station points at its canonical existing building")
			equal(Vector2(SanctumCampusLayout._parse_point(station["position"])),door,"every grouped action shares exactly one front-door anchor")
			equal(station["district"],building["district"],"directory and building share district authority")
		# The existing Lodge faces a narrow lane behind its practice wall; enter
		# that lane from the west rather than pretending the wall is passable.
		var approach_limit := 21 if building_id == 101 else 65
		for approach: int in range(0, approach_limit, 4):
			check(collision.can_occupy(Vector2i((door + Vector2(0, approach)) * SimConfig.FIXED_SCALE), MovementTuning.PLAYER_RADIUS), "every door has an unobstructed approach from its front")
		if building_id == 101:
			for lane_x: int in range(240,329,4):
				check(collision.can_occupy(Vector2i(lane_x,336)*SimConfig.FIXED_SCALE,MovementTuning.PLAYER_RADIUS),"Lodge approach remains accessible through its west side lane")
	equal(seen.size(), 12, "all twelve existing services remain accessible through four real buildings")
	for removed_id: int in range(201,213):
		check(not layout.buildings_by_id.has(removed_id), "retired standalone menu hut is absent")
	for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
		check(obstacle.obstacle_id<201 or obstacle.obstacle_id>212, "retired huts cannot leave invisible collision behind")
	var gather: Array = layout.stations_by_id["session-hearth"]["gather_spawns"]
	var expected_gather := [[1924,368],[1964,368],[2004,368],[2044,368],[1924,408],[1964,408],[2004,408],[2044,408]]
	equal(gather.size(),expected_gather.size(),"Farflow gathering retains eight points")
	for index: int in gather.size():
		equal(SanctumCampusLayout._parse_point(gather[index]),SanctumCampusLayout._parse_point(expected_gather[index]),"Farflow gathering uses ordered nonoverlapping points in two front-door rows")
	for index: int in gather.size():
		var point := SanctumCampusLayout._parse_point(gather[index])
		check(collision.can_occupy(point*SimConfig.FIXED_SCALE,MovementTuning.PLAYER_RADIUS),"each new gathering point has shared player clearance")
		for prior: int in index:
			check(point.distance_squared_to(SanctumCampusLayout._parse_point(gather[prior]))>=40*40,"gathered bodies retain the shared clearance plus4px gap")
	check(not String(layout.stations_by_id["controls-lectern"]["title"]).contains("LECTERN"), "public controls copy names the new building")
	check(" ".join(layout.stations_by_id["movement-guide"]["lines"]).contains("Lodge directory"), "movement guide directs players to the combined directory")


func _directory_baseline() -> Dictionary:
	equal(FileAccess.get_sha256(DIRECTORY_BASELINE_PATH),DIRECTORY_BASELINE_SHA256,"historical directory baseline is pinned, not regenerated to fit a new map")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY_BASELINE_PATH))
	check(parsed is Dictionary,"pre-directory historical campus fixture parses")
	return parsed if parsed is Dictionary else {}


func _test_directory_map_delta() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH),"directory delta uses the validated live map")
	var baseline := _directory_baseline()
	var before := baseline.duplicate(true)
	# Explicit current range correction for the live Heavy radius. Keep all
	# other target/group fields under the pinned historical comparison.
	before["practice_targets"][0]["position"][0] = 2400.0
	before["practice_targets"][2]["position"][0] = 2720.0
	before["practice_groups"][0]["bounds"] = [2360.0,304.0,400.0,336.0]
	before["practice_groups"][0]["firing_anchors"][0][0] = 2400.0
	before["practice_groups"][0]["firing_anchors"][2][0] = 2720.0
	var current := _without_south_training_extension(layout.data)
	for key: String in ["buildings","stations"]:
		before.erase(key)
		current.erase(key)
	equal(CanonicalContent.sha256(current),CanonicalContent.sha256(before),"directories preserve map fields except the separately checked Heavy comparison range spacing")
	equal(baseline["buildings"].size(),35,"baseline contains the exact23original buildings and12retired huts")
	equal(_without_expeditions(layout.data)["buildings"].size(),25,"preserved core removes only the12retired huts and retains its two southern practice walls")
	for index: int in 23:
		var expected: Dictionary = baseline["buildings"][index].duplicate(true)
		if int(expected["id"])==109: expected["name"]="Farflow Hall"
		if int(expected["id"])==106: expected["bounds"]=[1264.0,1504.0,256.0,112.0]
		equal(CanonicalContent.sha256(layout.data["buildings"][index]),CanonicalContent.sha256(expected),"original building rules stay exact except109name and the bounded106experiment-passage footprint")
	for index: int in range(23,35):
		equal(int(baseline["buildings"][index]["id"]),201+index-23,"only sequential standalone hut ids201through212are removed")
	equal(layout.data["stations"].size(),baseline["stations"].size(),"all original station actions remain present")
	for index: int in baseline["stations"].size():
		var old_station: Dictionary = baseline["stations"][index].duplicate(true)
		var new_station: Dictionary = layout.data["stations"][index].duplicate(true)
		equal(new_station["id"],old_station["id"],"station identity and canonical ordering are unchanged")
		for field: String in ["position","district","title","lines","service_group","building_id"]:
			old_station.erase(field)
			new_station.erase(field)
		if String(old_station["id"])=="session-hearth":
			old_station.erase("gather_spawns")
			new_station.erase("gather_spawns")
		equal(CanonicalContent.sha256(new_station),CanonicalContent.sha256(old_station),"only directory metadata, access locations and approved copy/gathering change; commands, authority, radii and all other fields remain exact")


func _test_open_experiment_passage() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "experiment passage validates against every existing full-width route")
	var collision := layout.build_collision_world()
	var workshop: Dictionary = layout.buildings_by_id[106]
	equal(SanctumCampusLayout._parse_bounds(workshop["bounds"]), Rect2i(1264,1504,256,112), "only the decorative Workshop's eastern128px are opened")
	check(not WellspringServiceBuildings.GROUPS.values().any(func(group: Dictionary) -> bool: return int(group["building_id"]) == 106), "reshaped Workshop owns no live service doorway")
	check(not collision.can_occupy(Vector2i(1392,1560)*SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "remaining visible Workshop stays solid cover")
	var before := CollisionWorld.new(layout.canvas_size.x*SimConfig.FIXED_SCALE, layout.canvas_size.y*SimConfig.FIXED_SCALE)
	before.add_obstacle(CollisionWorld.Obstacle.new(106,1264000,1504000,1648000,1616000))
	check(not before.can_occupy(Vector2i(1568,1552)*SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "positive control proves the old Workshop really blocked this experiment exit")
	var profiles := BodyTypeProfileCatalog.new()
	check(profiles.load_from_file(), "experiment passage checks actual small/middle/large hurt radii")
	for index: int in range(SanctumCampusRenderer.OPEN_LAB_LINK.size()-1):
		var start: Vector2 = SanctumCampusRenderer.OPEN_LAB_LINK[index]
		var end: Vector2 = SanctumCampusRenderer.OPEN_LAB_LINK[index+1]
		var steps := ceili(start.distance_to(end)/4.0)
		for step_index: int in range(steps+1):
			var point := Vector2i(start.lerp(end,float(step_index)/steps)*SimConfig.FIXED_SCALE)
			check(collision.can_occupy(point,32_000), "new chemistry-to-open-lab passage has continuous64px clearance")
			for body: String in BodyTypeProfileCatalog.BODY_TYPES:
				check(collision.can_occupy(point,profiles.hurt_radius(body)), "experiment link fits actual "+body+" body")
		var origin := Vector2i(start*SimConfig.FIXED_SCALE)
		var destination := Vector2i(end*SimConfig.FIXED_SCALE)
		var result := collision.move_box(origin,destination-origin,MovementTuning.PLAYER_RADIUS)
		equal(result.position,destination,"authoritative swept movement traverses every visible passage segment without collision")
	equal(layout.canvas_size,Vector2i(6144,5376),"existing experiment link stays at its original coordinates inside the fourfold campus")
	equal(collision.obstacles.size(),49,"twenty-five unchanged core structures coexist with twenty-four expedition walls")
	equal(layout.stations_by_id.size(),12,"experiment link creates no fake service or interaction")
	equal(layout.practice_targets_by_id.size(),4,"experiment link creates no extra target actor")


func _without_south_training_extension(current: Dictionary) -> Dictionary:
	# Compare every pre-extension field against the pinned historical fixture;
	# the exact appended topology and dimensions are checked separately below.
	var previous := _without_expeditions(current)
	previous["canvas_size"] = [3072.0, 2304.0]
	for district: Dictionary in previous["districts"]:
		district["bounds"][3] = 2080.0
	previous["connections"] = previous["connections"].slice(0, 8)
	previous["routes"] = previous["routes"].slice(0, 15)
	previous["buildings"] = previous["buildings"].slice(0, 23)
	previous["activity_areas"] = previous["activity_areas"].slice(0, 10)
	return previous


func _test_south_training_extension() -> void:
	var layout := SanctumCampusLayout.new()
	var loaded := layout.load_from_file(CAMPUS_PATH)
	check(loaded, "larger playground validates through the authoritative loader: " + layout.last_error)
	if not loaded: return
	var preserved_canvas := SanctumCampusLayout._parse_point(_without_expeditions(layout.data)["canvas_size"])
	equal(preserved_canvas, Vector2i(3072, 2688), "the preceding southern playground remains the exact expansion core")
	equal(preserved_canvas.y * 6, 2304 * 7, "historical southern extension retains its exact one-sixth increase")
	for district: Dictionary in layout.data["districts"].slice(0, 3):
		equal(int(district["bounds"][3]), 2464, "all three existing quarters extend to the same southern shoreline")
	var collision := layout.build_collision_world()
	var old_bounds := CollisionWorld.new(3072000, 2304000)
	var southern_sample := Vector2i(2528000, 2480000)
	check(not old_bounds.can_occupy(southern_sample, MovementTuning.PLAYER_RADIUS), "positive control proves the spell court was outside the former world")
	check(collision.can_occupy(southern_sample, MovementTuning.PLAYER_RADIUS), "the new court is authoritative playable space, not cosmetic terrain")
	var expected_routes := {
		"south-extension-garden-straight": [128, [[256,2080],[256,2320],[864,2320]]],
		"south-extension-commons-straight": [128, [[1120,2080],[1120,2320],[1888,2320]]],
		"south-extension-proving-straight": [128, [[2256,2080],[2256,2320],[2896,2320]]],
		"south-extension-wall-chain": [64, [[1168,2384],[1536,2384],[1568,2448],[1568,2544],[1680,2544]]],
		"south-extension-wall-bypass": [96, [[1088,2320],[1088,2560],[1952,2560],[1952,2320]]],
		"south-extension-garden-link": [160, [[864,2320],[1120,2320]]],
		"south-extension-proving-link": [160, [[1888,2320],[2256,2320]]],
	}
	var profiles := BodyTypeProfileCatalog.new()
	check(profiles.load_from_file(), "extension uses all three actual body profile clearances")
	var seen := {}
	var paths: Array = layout.data["routes"].slice(15, 20) + layout.data["connections"].slice(8, 10)
	equal(paths.size(), expected_routes.size(), "exactly five routes and two district connections extend the existing campus")
	for route: Dictionary in paths:
		var route_id := String(route["id"])
		check(expected_routes.has(route_id) and not seen.has(route_id), "extension path identity is exact and unique: " + route_id)
		if not expected_routes.has(route_id): continue
		seen[route_id] = true
		equal(int(route["width"]), int(expected_routes[route_id][0]), "extension keeps its full promised path width")
		var expected_points: Array = expected_routes[route_id][1]
		equal(route["points"].size(), expected_points.size(), "extension keeps every authored connection and corner")
		for index: int in mini(route["points"].size(), expected_points.size()):
			equal(SanctumCampusLayout._parse_point(route["points"][index]), SanctumCampusLayout._parse_point(expected_points[index]), "extension path geometry remains exact")
		if route.has("accessible"):
			equal(bool(route["accessible"]), route_id != "south-extension-wall-chain", "only the optional chain is advanced; every bypass is ordinary walking")
		for index: int in range(route["points"].size() - 1):
			var a := Vector2(SanctumCampusLayout._parse_point(route["points"][index]))
			var b := Vector2(SanctumCampusLayout._parse_point(route["points"][index + 1]))
			var samples := ceili(a.distance_to(b) / 4.0)
			var half_width := int(route["width"]) * 500
			for sample: int in range(samples + 1):
				var point := Vector2i(a.lerp(b, float(sample) / samples) * SimConfig.FIXED_SCALE)
				check(collision.can_occupy(point, half_width), "every4px of the visible extension path retains its full authored width: " + route_id)
				for body: String in BodyTypeProfileCatalog.BODY_TYPES:
					check(collision.can_occupy(point, profiles.hurt_radius(body)), "extension path fits actual " + body + " body")
			var origin := Vector2i(a * SimConfig.FIXED_SCALE)
			var destination := Vector2i(b * SimConfig.FIXED_SCALE)
			equal(collision.move_box(origin, destination - origin, MovementTuning.PLAYER_RADIUS).position, destination, "swept authoritative movement reaches the next extension corner")
	for link_id: String in ["south-extension-garden-link", "south-extension-proving-link"]:
		var link_points: Array = expected_routes[link_id][1]
		# A valid crossing must join existing ordinary routes in both quarters.
		for endpoint: Array in link_points:
			var touches_ordinary := false
			for route: Dictionary in layout.data["routes"]:
				if String(route["kind"]) != "ordinary" or not bool(route.get("accessible", false)): continue
				for point: Array in route["points"]:
					touches_ordinary = touches_ordinary or SanctumCampusLayout._parse_point(point) == SanctumCampusLayout._parse_point(endpoint)
			check(touches_ordinary, "southern bridge ends on a usable ordinary route: " + link_id)
		var narrowed := SanctumCampusLayout.new()
		narrowed.data = layout.data.duplicate(true)
		for connection: Dictionary in narrowed.data["connections"]:
			if String(connection["id"]) == link_id: connection["width"] = 128
		check(not narrowed.validate(), "undersized southern district bridge remains invalid: " + link_id)
		check(narrowed.last_error.contains("connection width") and narrowed.last_error.contains(link_id), "width refusal identifies the specific invalid crossing")
	for x: int in range(256, 2897, 4):
		check(collision.can_occupy(Vector2i(x,2320) * SimConfig.FIXED_SCALE,64000), "all2640px of the connected128px sprint/slide straight are clear")
	for x: int in range(2208, 2865, 32):
		for y: int in range(2384, 2561, 32):
			check(collision.can_occupy(Vector2i(x,y) * SimConfig.FIXED_SCALE,32000), "open spell court has usable interior area, not only a thin route")
	for wall_id: int in [124,125]:
		var wall: Dictionary = layout.buildings_by_id[wall_id]
		equal(String(wall["style"]), "practice_wall", "extension adds training walls, not new service buildings")
		var bounds := SanctumCampusLayout._parse_bounds(wall["bounds"])
		var expected_bounds := Rect2i(1200,2416,256,24) if wall_id == 124 else Rect2i(1600,2416,24,96)
		equal(bounds, expected_bounds, "practice wall footprint is exact")
		check(not collision.can_occupy(bounds.get_center() * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "visible new wall has real collision")
		var matching := 0
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			if obstacle.obstacle_id == wall_id:
				matching += 1
				check(obstacle.wall_runnable and not obstacle.vaultable, "optional wall chain uses real nonvaultable wallrun authority")
		equal(matching, 1, "each practice wall compiles exactly once")
	var expected_areas := {
		"south-extension-stride": [Rect2i(128,2288,800,304), "SPRINT / SLIDE STRAIGHT"],
		"south-extension-chain": [Rect2i(1056,2288,960,304), "OPTIONAL WALL CHAIN"],
		"south-extension-spells": [Rect2i(2160,2288,736,304), "OPEN SPELL COURT"],
	}
	for area: Dictionary in layout.data["activity_areas"].slice(10, 13):
		var area_id := String(area["id"])
		check(expected_areas.has(area_id), "extension activity identity names a useful practice space")
		if not expected_areas.has(area_id): continue
		equal(SanctumCampusLayout._parse_bounds(area["bounds"]), expected_areas[area_id][0], "extension activity owns its real playable footprint")
		equal(String(area["label"]), String(expected_areas[area_id][1]), "extension title states what to do without adding a service")
	# Camera bounds remain data-driven even at the new southern edge.
	var view := Vector2(1280,720)
	var world := Rect2(Vector2.ZERO,Vector2(layout.canvas_size))
	check(PlayerCameraRig.clamped_origin(world.end - Vector2(24,24), view, world).is_equal_approx(world.end - view / PlayerCameraRig.ZOOM), "actual camera can frame the enlarged southeast boundary")


func _test_floor_guide_authority_boundary() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "practice wayfinding uses the current authoritative campus")
	equal(CanonicalContent.sha256(_historical_campus_with_original_loom_copy(_directory_baseline())), WARM_TRAILS_AUTHORITY_HASH, "pinned historical projection retains the original complete-map authority receipt")
	check(not layout.data.has("floor_guides") and not layout.data.has("practice_wayfinding"), "floor-only guidance does not churn the network map fingerprint")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SanctumCampusRenderer.FLOOR_GUIDE_PATH))
	check(parsed is Dictionary, "guide data is a separately authored presentation descriptor")
	if parsed is Dictionary:
		equal(String(parsed.get("authority", "")), "presentation_only", "guide descriptor cannot add gameplay geometry")
		equal(String(parsed.get("map_id", "")), String(layout.data.id), "guide data binds the existing campus by identity")


func _historical_campus_with_original_loom_copy(current: Dictionary) -> Dictionary:
	var previous := current.duplicate(true)
	# New southern playground is append-only. Remove just its registrations
	# before comparing the preserved pre-playground campus fingerprint.
	previous["connections"] = previous["connections"].slice(0, 7)
	previous["routes"] = previous["routes"].slice(0, 12)
	previous["buildings"] = previous["buildings"].slice(0, 16)
	previous["activity_areas"] = previous["activity_areas"].slice(0, 7)
	# Service doors relocate six access points to preserve every original route's
	# promised width. Restore only those coordinates and two copy changes for
	# the historical assertion; current geometry has a separate mandatory test.
	var original_service_positions := {
		"movement-guide": [1216.0, 640.0], "farflow-host": [1216.0, 1008.0],
		"training-reset": [1888.0, 1376.0], "momentum-chime": [832.0, 928.0],
		"company-ledger": [2016.0, 896.0], "parting-bell": [2016.0, 1056.0],
	}
	for station: Dictionary in previous["stations"]:
		var station_id := String(station["id"])
		if original_service_positions.has(station_id):
			station["position"] = original_service_positions[station_id].duplicate()
		if station_id == "movement-guide":
			station["lines"][4] = "Change any binding at the Controls Lectern"
		if station_id == "controls-lectern":
			station["title"] = "CONTROLS LECTERN"
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
	var previous := _historical_campus_with_original_loom_copy(_directory_baseline())
	previous["canvas_size"] = [3072.0, 1728.0]
	for district: Dictionary in previous["districts"]:
		district["bounds"][3] = 1504.0
	previous["connections"] = previous["connections"].slice(0, 6)
	previous["routes"] = previous["routes"].slice(0, 9)
	previous["buildings"] = previous["buildings"].slice(0, 14)
	previous["activity_areas"] = previous["activity_areas"].slice(0, 6)
	equal(CanonicalContent.sha256(previous), PRE_ANNEX_CONTENT_HASH, "annex preserves every previous spawn, station, target, arena, wall, route, landmark and rule")
	check(layout.content_hash != PRE_ANNEX_CONTENT_HASH, "expanded content has a new host compatibility identity")
	var core := _without_expeditions(layout.data)
	equal(core["connections"].size(), 10, "both preserved southern loops connect the original three quarters")
	equal(core["routes"].size(), 20, "all prior routes remain alongside the original five southern practice routes")
	equal(core["activity_areas"].size(), 13, "three southern activity pockets remain in the preserved core")
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
	equal(layout.canvas_size, Vector2i(6144, 5376), "campus doubles both dimensions while retaining the established core")
	equal(layout.viewport_size, Vector2i(1280, 720), "campus preserves the supported gameplay viewport")
	equal(layout.spawn, Vector2i(1536, 880), "campus spawn anchors the combined Nexus commons")
	check(layout.content_hash.length() == 64, "campus layout has a canonical content hash")
	equal(layout.districts_by_id.size(), 7, "three existing quarters and four distinct expeditions have explicit identities")
	for district_id: String in SanctumCampusLayout.REQUIRED_DISTRICTS:
		check(layout.districts_by_id.has(district_id), "required visible district exists: %s" % district_id)
	equal(layout.buildings_by_id.size(), 49, "twelve services keep existing buildings while twenty-four real walls shape the new expeditions")
	equal(layout.landmarks_by_id.size(), 10, "existing landmarks remain alongside one distinct landmark per expedition")
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
	equal(collision.width, 6_144_000, "campus collision width uses fixed-point units")
	equal(collision.height, 5_376_000, "enlarged campus collision height uses fixed-point units")
	equal(collision.obstacles.size(), 49, "preserved core plus twenty-four expedition walls compile to ordered collision")
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
		func(data: Dictionary) -> void: ((data["stations"][8] as Dictionary)["gather_spawns"] as Array)[1] = data["stations"][8]["gather_spawns"][0].duplicate(),
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
	candidate.data["connections"] = (candidate.data["connections"] as Array).filter(func(connection: Dictionary) -> bool: return String(connection["from"]) != "wayfarer-proving-quarter" and String(connection["to"]) != "wayfarer-proving-quarter")
	check(candidate.data["connections"].size() >= SanctumCampusLayout.REQUIRED_DISTRICTS.size() - 1, "negative control retains enough bridges but genuinely isolates a required district")
	check(not candidate.validate(), "a sufficient bridge count cannot hide a disconnected district")
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
	equal(left, Vector2i(2400,352), "left comparison target moves only40px within the existing practice pocket")
	equal(center, Vector2i(2560,352), "center comparison target keeps its existing anchor")
	equal(right, Vector2i(2720,352), "right comparison target moves symmetrically40px")
	equal(center - left, Vector2i(160, 0), "first gap permits comparison of precise and between-target aim")
	equal(right - center, Vector2i(160, 0), "comparison gaps are symmetric")
	equal(SanctumCampusLayout._parse_bounds(range_group["bounds"]), Rect2i(2360,304,400,336), "expanded comparison pocket preserves its vertical extent")
	for index: int in range(3):
		equal(SanctumCampusLayout._parse_point(range_group["firing_anchors"][index]), Vector2i(2400 + 160 * index,592), "each moved target retains its aligned240px firing lane")
	# Use the actual authored blast radius to preserve the range's single-hit
	# versus between-target group-hit teaching contract after gameplay retunes.
	var comparison_reach := int(CombatTuning.cast_definition(179)["blast_radius"]) / SimConfig.FIXED_SCALE + int(layout.practice_targets_by_id["nexus-sparring-effigy"]["radius"])
	check(left.distance_squared_to(center) > comparison_reach * comparison_reach, "directly centred heavy blast need not automatically hit its neighbor")
	var surface_separation := comparison_reach + int(layout.practice_targets_by_id["range-effigy-center"]["radius"])
	check(left.distance_squared_to(center) > surface_separation * surface_separation, "Heavy impact on the struck target's nearest surface still excludes its neighbor")
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
		func(data: Dictionary) -> void: data["practice_targets"][1]["position"] = [2448, 352],
		func(data: Dictionary) -> void: data["stations"][1]["position"] = [1568, 1360],
	]
	for mutation: Callable in mutations:
		var candidate := SanctumCampusLayout.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(), "unsafe or misleading practice layout fails closed")
		check(not candidate.last_error.is_empty(), "practice rejection explains why the layout is unsafe")


func _without_expeditions(current: Dictionary) -> Dictionary:
	var core := current.duplicate(true)
	core["schema_version"] = 6.0
	core["canvas_size"] = [3072.0, 2688.0]
	for key: String in {"required_districts": 3, "required_source_districts": 7, "districts": 3, "connections": 10, "routes": 20, "buildings": 25, "activity_areas": 13, "landmarks": 6}:
		var count := int({"required_districts": 3, "required_source_districts": 7, "districts": 3, "connections": 10, "routes": 20, "buildings": 25, "activity_areas": 13, "landmarks": 6}[key])
		core[key] = (core[key] as Array).slice(0, count)
	core.erase("travel_destinations")
	core.erase("movement_courses")
	core.erase("element_garden")
	return core


func _test_expedition_preservation_and_routes() -> void:
	equal(FileAccess.get_sha256(EXPEDITION_BASELINE_PATH), EXPEDITION_BASELINE_SHA256, "independent pre-expedition fixture keeps its exact original bytes")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPEDITION_BASELINE_PATH))
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "four expeditions load through production validation: " + layout.last_error)
	if layout.content_hash.is_empty(): return
	equal(CanonicalContent.sha256(_without_expeditions(layout.data)), CanonicalContent.sha256(original), "every pre-expansion field, station, target, spawn, arena and authored core path is preserved")
	equal(layout.canvas_size.x * layout.canvas_size.y, 4 * 3072 * 2688, "expedition campus has exactly four times the preceding canvas area")
	equal(layout.data.routes.size(), 32, "twelve purposeful district routes join all twenty core routes")
	equal(layout.data.connections.size(), 17, "seven real inter-district links join all ten core links")
	equal(layout.data.activity_areas.size(), 24, "eight expedition spaces, two core forecourts and one bounded Element Garden join thirteen core areas")
	var collision := layout.build_collision_world()
	var new_paths: Array = (layout.data.routes as Array).slice(20) + (layout.data.connections as Array).slice(10)
	for path: Dictionary in new_paths:
		var half_width := int(path.width) * SimConfig.FIXED_SCALE / 2
		for index: int in range(path.points.size() - 1):
			var a := Vector2(SanctumCampusLayout._parse_point(path.points[index]))
			var b := Vector2(SanctumCampusLayout._parse_point(path.points[index + 1]))
			var samples := maxi(1, ceili(a.distance_to(b) / 4.0))
			var resolved := Vector2i(a * SimConfig.FIXED_SCALE)
			for sample: int in range(samples + 1):
				var point := Vector2i(a.lerp(b, float(sample) / float(samples)) * SimConfig.FIXED_SCALE)
				check(collision.can_occupy(point, half_width), "new route has its entire promised width clear, including endpoints: " + String(path.id))
				var moved := collision.move_box(resolved, point - resolved, MovementTuning.PLAYER_RADIUS)
				resolved = moved.position
				equal(resolved, point, "ordinary small-step collision traversal reaches each marked segment point: " + String(path.id))
			equal(resolved, Vector2i(b * SimConfig.FIXED_SCALE), "continuous ordinary traversal reaches the route endpoint")
	var expected_environments := {"tideglass-quays": "coast", "verdant-reaches": "grove", "basalt-foundry": "foundry", "starward-terraces": "observatory"}
	for district_id: String in expected_environments:
		var district: Dictionary = layout.districts_by_id[district_id]
		equal(String(district.environment), expected_environments[district_id], "each expedition owns a distinct environment vocabulary")
		var ordinary_routes := 0
		var advanced_routes := 0
		for route: Dictionary in layout.data.routes:
			if String(route.district) != district_id: continue
			if int(route.width) >= 192: ordinary_routes += 1
			else: advanced_routes += 1
		equal(ordinary_routes, 2, "each advanced district retains two broad ordinary walking choices")
		equal(advanced_routes, 1, "each district adds one optional precision route")
	for wall_id: int in range(301, 325):
		var building: Dictionary = layout.buildings_by_id[wall_id]
		var bounds := SanctumCampusLayout._parse_bounds(building.bounds)
		check(bool(building.worldbone) and not bool(building.vaultable), "new landmarks use real solid wall cover")
		check(not collision.can_occupy(Vector2i(bounds.get_center()) * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS), "new wall interior cannot be walked through")
	for course: Dictionary in layout.data.movement_courses:
		var state := PlayerState.new(1)
		var contact := SanctumCampusLayout._parse_point(course.contact) * SimConfig.FIXED_SCALE
		state.position_x = contact.x
		state.position_y = contact.y
		state.air_height = 80_000
		state.hop_ticks = 40
		state.hop_stage = 1
		var before := state.stamina
		MovementSystem.step(state, SimCommand.new(0, 1, 1000, 0, 0, SimCommand.PRESSED_TECHNIQUE), SimConfig.new(120), collision)
		check(state.wall_skim_ticks > 0 and state.wall_skim_surface_id == int(course.wall_id), "actual movement admission finds each authored runnable contact without injected contact memory")
		equal(state.stamina, before - 18_000, "each real district wallrun pays the established finite entry cost")
		equal(state.jump_protection_ticks, 0, "district wall contact invents no protection")
		for tick: int in range(200):
			MovementSystem.step(state, SimCommand.new(tick + 1, 1, 1000, 0), SimConfig.new(120), collision)
		equal(state.wall_skim_ticks, 0, "each paid course attachment necessarily expires without renewed input")


func _test_travel_destinations() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "travel data loads from the same collision authority")
	if layout.content_hash.is_empty(): return
	var ids := ["wellspring", "academy", "training", "farflow", "pattern-range", "duel-court", "crucible", "recovery", "tideglass", "verdant", "foundry", "starward", "element-garden"]
	var positions := [Vector2i(1536,880), Vector2i(1536,424), Vector2i(208,432), Vector2i(1984,416), Vector2i(2560,608), Vector2i(2256,1008), Vector2i(1536,1424), Vector2i(672,1408), Vector2i(3328,832), Vector2i(256,2912), Vector2i(2304,2912), Vector2i(4352,2912), Vector2i(4880,720)]
	var collision := layout.build_collision_world()
	var rows := layout.travel_destinations()
	equal(rows.size(), 13, "map publishes a bounded thirteen-stop travel directory including the Element Garden")
	for index: int in ids.size():
		var row: Dictionary = rows[index]
		equal(String(row.id), ids[index], "travel order and stable identity are independently pinned")
		equal(SanctumCampusLayout._parse_point(row.position), positions[index], "map pins use authored, independently pinned walkable arrival coordinates")
		check(collision.can_occupy(positions[index] * SimConfig.FIXED_SCALE, 40_000), "each arrival clears the largest admitted body plus margin")
		equal(layout.travel_destination(ids[index]), row, "ID resolution and public directory agree")
		row.position[0] = -999999
		equal(SanctumCampusLayout._parse_point(layout.travel_destination(ids[index]).position), positions[index], "public directory copies cannot change authoritative travel positions")
		var looked_up := layout.travel_destination(ids[index])
		looked_up.position[1] = -999999
		equal(SanctumCampusLayout._parse_point(layout.travel_destination(ids[index]).position), positions[index], "single lookup is also a deep isolated copy")
	equal(layout.travel_destination("unlisted"), {}, "unknown destination never produces arbitrary coordinates")
	check(layout.validate(), "revalidation accepts the unchanged source data")
	equal(layout.travel_destinations().size(), 13, "revalidation never duplicates travel rows")
	for bad_path: String in ["res://tests/fixtures/nonexistent_campus_reload_control.json", "res://tests/unit/test_sanctum_campus_layout.gd"]:
		check(layout.load_from_file(CAMPUS_PATH), "reload control starts with an actual admitted published map")
		equal(layout.travel_destinations().size(), 13, "reload control really has previous destinations to invalidate")
		check(not layout.load_from_file(bad_path), "missing file and non-JSON source reject reload")
		check(not layout.last_error.is_empty(), "failed reload retains an actionable diagnostic")
		equal(layout.content_hash, "", "failed reload cannot retain prior content admission")
		equal(layout.travel_destinations().size(), 0, "failed reload cannot expose stale destinations")
		equal(layout.travel_destination("wellspring"), {}, "failed reload also invalidates direct ID lookup")
		equal(layout.element_garden_plots().size(), 0, "failed reload also invalidates published exhibition metadata")


func _test_expedition_rejections() -> void:
	var source := SanctumCampusLayout.new()
	check(source.load_from_file(CAMPUS_PATH), "negative expedition fixtures begin with admitted content")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data.travel_destinations.pop_back(),
		func(data: Dictionary) -> void: data.travel_destinations[1].id = data.travel_destinations[0].id,
		func(data: Dictionary) -> void: data.travel_destinations[0].area_id = "unlisted",
		func(data: Dictionary) -> void: data.travel_destinations[0].position = [3552, 1056],
		func(data: Dictionary) -> void: data.travel_destinations[0].detail = "x".repeat(121),
		func(data: Dictionary) -> void: data.movement_courses.pop_back(),
		func(data: Dictionary) -> void: data.movement_courses[0].wall_id = 101,
		func(data: Dictionary) -> void: data.movement_courses[0].normal = [0, -1],
		func(data: Dictionary) -> void: data.movement_courses[0].contact[1] += 1,
		func(data: Dictionary) -> void: data.districts[3].environment = "grove",
		func(data: Dictionary) -> void: data.districts[3].landmark_anchor = [3552, 1056],
	]
	for mutation: Callable in mutations:
		var candidate := SanctumCampusLayout.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(), "invalid expedition geometry or travel metadata fails closed")
		check(not candidate.last_error.is_empty(), "invalid expansion is diagnosable")
		equal(candidate.travel_destinations().size(), 0, "failed layout cannot publish partially admitted travel data")


func _test_element_garden_geometry() -> void:
	equal(FileAccess.get_sha256(GARDEN_BASELINE_PATH), GARDEN_BASELINE_SHA256, "pre-garden expansion keeps its exact independently pinned source bytes")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "authored Element Garden loads: " + layout.last_error)
	if layout.content_hash.is_empty(): return
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GARDEN_BASELINE_PATH))
	var projected := layout.data.duplicate(true)
	projected.schema_version = 7.0
	projected.erase("element_garden")
	projected.activity_areas = (projected.activity_areas as Array).slice(0,23)
	projected.travel_destinations = (projected.travel_destinations as Array).slice(0,12)
	equal(CanonicalContent.sha256(projected), CanonicalContent.sha256(before), "garden addition preserves every previous district, wall, route, station, target, landmark and destination")
	var plots := layout.element_garden_plots()
	equal(plots.size(), 63, "all six singleton and fifty-seven mixed ingredient sets have physical plots")
	var counts := [0,0,0,0,0,0,0]
	var seen := {}
	var collision := layout.build_collision_world()
	for index: int in plots.size():
		var row: Dictionary = plots[index]
		var mask := int(row.mask)
		check(mask >= 1 and mask <= 63 and not seen.has(mask), "plot identity is one unique nonempty six-bit set")
		seen[mask] = true
		var cardinality := 0
		for bit: int in 6:
			if (mask & (1 << bit)) != 0: cardinality += 1
		counts[cardinality] += 1
		check(row.center is Vector2, "public plot API returns typed pixel vectors for the presenter")
		var point: Vector2 = row.center
		check(collision.can_occupy(Vector2i(point) * 1000,160_000), "every plot clears preserved real walls beyond its108px pad and bounded field")
		equal(posmod(int(point.x) - 3296,288), 0, "plot columns retain the independently bounded288px visibility lattice")
		equal(posmod(int(point.y) - 288,288), 0, "plot rows retain the independently bounded288px visibility lattice")
		for previous: int in index:
			check(point.distance_to(plots[previous].center) >= 288.0, "neighboring108px pads leave at least72px clear aisles")
		row.center = Vector2(-1,-1)
		check((layout.element_garden_plots()[index].center as Vector2).x >= 0, "published plot metadata cannot mutate its authoritative source")
		plots[index] = layout.element_garden_plots()[index]
	equal(counts, [0,6,15,20,15,6,1], "physical plot groups match the exact six-element binomial cardinalities")
	for mask: int in range(1,64): check(seen.has(mask), "no possible ingredient set is missing")
	equal(plots[0], {"mask":1,"center":Vector2(3296,288)}, "first exhibit keeps the authored northwest anchor")
	equal(plots[-1], {"mask":63,"center":Vector2(5312,2304)}, "six-element exhibit has a stable real southern anchor")
	for size: Vector2 in [Vector2(1280,720),Vector2(960,540)]:
		var world_view := size / 0.75
		var maximum_columns := ceili((world_view.x + 360.0) / 288.0)
		var maximum_rows := ceili((world_view.y + 360.0) / 288.0)
		check(maximum_columns * maximum_rows <= 40, "every plot intersecting supported75percent camera plus180px visual fringe fits forty resident exhibits")
	var route: Dictionary = layout.data.element_garden.entry_path
	equal(route, {"width":96.0,"points":[[4880.0,832.0],[4880.0,720.0]]}, "dedicated entrance joins the existing broad Tideglass approach without moving it")
	for y: int in range(720,833,4):
		check(collision.can_occupy(Vector2i(4880,y) * 1000,48_000), "entry path has its entire96px ordinary width clear")
	equal(layout.travel_destination("element-garden").position, [4880.0,720.0], "garden map arrival lies in the real clear entry aisle")
	for area: Dictionary in layout.data.activity_areas:
		if String(area.id) == "element-garden":
			equal(SanctumCampusLayout._parse_bounds(area.bounds), Rect2i(4736,576,288,288), "garden location names the arrival forecourt while exhibit bounds retain all plots")
			check(SanctumCampusLayout._parse_bounds(area.bounds).has_point(Vector2i(4880,720)), "new forecourt contains the trusted arrival")


func _test_element_garden_rejections() -> void:
	var source := SanctumCampusLayout.new()
	check(source.load_from_file(CAMPUS_PATH), "negative garden controls start from admitted content")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data.erase("element_garden"),
		func(data: Dictionary) -> void: data.element_garden.plots.pop_back(),
		func(data: Dictionary) -> void: data.element_garden.plots[0].mask = 0,
		func(data: Dictionary) -> void: data.element_garden.plots[0].mask = 64,
		func(data: Dictionary) -> void: data.element_garden.plots[0].mask = 1.5,
		func(data: Dictionary) -> void: data.element_garden.plots[1].mask = 1,
		func(data: Dictionary) -> void: data.element_garden.plots.reverse(),
		func(data: Dictionary) -> void: data.element_garden.plots[0].center = [3584,1152],
		func(data: Dictionary) -> void: data.element_garden.plots[1].center = data.element_garden.plots[0].center.duplicate(),
		func(data: Dictionary) -> void: data.element_garden.plots[0].center[0] += 1,
		func(data: Dictionary) -> void: data.element_garden.plots[0].center[0] = NAN,
		func(data: Dictionary) -> void: data.element_garden.plot_radius = 160,
		func(data: Dictionary) -> void: data.element_garden.entry_path.width = 192,
		func(data: Dictionary) -> void: data.activity_areas[-1].bounds = data.element_garden.bounds.duplicate(),
		func(data: Dictionary) -> void: data.element_garden.entry_path.points[1] = [4900,720],
		func(data: Dictionary) -> void: data.travel_destinations[-1].position = [4880,832],
	]
	for mutation: Callable in mutations:
		var candidate := SanctumCampusLayout.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(), "unsafe, incomplete or misleading exhibition metadata fails closed")
		check(not candidate.last_error.is_empty(), "garden rejection is diagnosable")
		equal(candidate.element_garden_plots().size(), 0, "failed validation never publishes a partial or stale garden")
		equal(candidate.travel_destinations().size(), 0, "failed garden validation cannot publish its navigation directory")
