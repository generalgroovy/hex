class_name SanctumCampusLayout
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 6
const REQUIRED_CANVAS := Vector2i(3072, 2304)
const REQUIRED_VIEWPORT := Vector2i(1280, 720)
const REQUIRED_DISTRICTS: Array[String] = [
	"conservatory-gardens",
	"nexus-commons",
	"wayfarer-proving-quarter",
]
const REQUIRED_SOURCE_DISTRICTS: Array[String] = [
	"nexus-court",
	"movement-conservatory",
	"living-archive",
	"wayfarer-concourse",
	"alchemical-proving-grounds",
	"verdant-recovery",
	"crown-observatory",
]
const ALLOWED_STYLES: Array[String] = ["garden", "nexus", "archive", "wayfarer", "proving"]
const ALLOWED_OCCLUSION: Array[String] = ["los_cutaway", "low_never_occludes"]
const ALLOWED_ROUTE_KINDS: Array[String] = ["ordinary", "advanced", "garden"]
const ALLOWED_RESET_KINDS: Array[String] = ["movement", "practice"]
const ALLOWED_STATION_KINDS: Array[String] = ["guide", "controls", "training", "champion", "spell", "farflow", "charter", "hearth", "ledger", "parting"]
const ALLOWED_STATION_COMMANDS: Array[String] = ["movement_guide", "configure_controls", "training_reset", "impact_practice", "champion_switch", "configure_spells", "host_session", "join_session", "session_charter", "session_hearth", "session_ledger", "session_parting"]
const ALLOWED_STATION_AUTHORITIES: Array[String] = ["local", "host"]

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var districts_by_id: Dictionary[String, Dictionary] = {}
var buildings_by_id: Dictionary[int, Dictionary] = {}
var landmarks_by_id: Dictionary[String, Dictionary] = {}
var reset_zones_by_id: Dictionary[String, Dictionary] = {}
var stations_by_id: Dictionary[String, Dictionary] = {}
var practice_targets_by_id: Dictionary[String, Dictionary] = {}
var practice_groups_by_id: Dictionary[String, Dictionary] = {}
# Prepared once at content validation; presentation reads these same target-linked lanes.
var practice_lanes: Array[Dictionary] = []
var arena_definition: Dictionary = {}
var canvas_size := Vector2i.ZERO
var viewport_size := Vector2i.ZERO
var reserved_ui_top: int = 0
var spawn := Vector2i.ZERO


func load_from_file(path: String) -> bool:
	last_error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("Sanctum campus layout does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Sanctum campus layout cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Sanctum campus layout root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	content_hash = ""
	districts_by_id = {}
	buildings_by_id = {}
	landmarks_by_id = {}
	reset_zones_by_id = {}
	stations_by_id = {}
	practice_targets_by_id = {}
	practice_groups_by_id = {}
	practice_lanes = []
	arena_definition = {}
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("Unsupported Sanctum campus schema")
	if String(data.get("id", "")).is_empty():
		return _fail("Sanctum campus id is required")
	var canvas: Array = data.get("canvas_size", [])
	if canvas.size() != 2:
		return _fail("Sanctum campus canvas_size must contain width and height")
	canvas_size = Vector2i(int(canvas[0]), int(canvas[1]))
	if canvas_size != REQUIRED_CANVAS:
		return _fail("Sanctum campus must provide the authored %d x %d world" % [REQUIRED_CANVAS.x, REQUIRED_CANVAS.y])
	var viewport: Array = data.get("viewport_size", [])
	if viewport.size() != 2:
		return _fail("Sanctum campus viewport_size must contain width and height")
	viewport_size = Vector2i(int(viewport[0]), int(viewport[1]))
	if viewport_size != REQUIRED_VIEWPORT:
		return _fail("Sanctum campus must target the current 1280 x 720 viewport")
	reserved_ui_top = int(data.get("reserved_ui_top", 0))
	if reserved_ui_top < 96 or reserved_ui_top > 160:
		return _fail("Sanctum campus reserved UI band is outside supported bounds")
	var spawn_data: Array = data.get("spawn", [])
	if spawn_data.size() != 2:
		return _fail("Sanctum campus spawn must have two coordinates")
	spawn = Vector2i(int(spawn_data[0]), int(spawn_data[1]))
	if not _point_inside_canvas(spawn, MovementTuning.PLAYER_RADIUS / SimConfig.FIXED_SCALE):
		return _fail("Sanctum campus spawn is outside safe canvas bounds")

	var declared_required: Array = data.get("required_districts", [])
	var declared_source_districts: Array = data.get("required_source_districts", [])
	for source_district_id: String in REQUIRED_SOURCE_DISTRICTS:
		if not declared_source_districts.has(source_district_id):
			return _fail("Sanctum campus omits required source function area: %s" % source_district_id)
	var combined_source_districts: Dictionary[String, bool] = {}
	for value: Variant in data.get("districts", []):
		if not value is Dictionary:
			return _fail("Every Sanctum district presentation must be an object")
		var district: Dictionary = value
		var district_id := String(district.get("id", ""))
		if district_id.is_empty() or districts_by_id.has(district_id):
			return _fail("Sanctum presentation district ids must be non-empty and unique")
		if String(district.get("label", "")).is_empty():
			return _fail("Sanctum district requires a label: %s" % district_id)
		if not ALLOWED_STYLES.has(String(district.get("style", ""))):
			return _fail("Sanctum district has unsupported style: %s" % district_id)
		var bounds := _parse_bounds(district.get("bounds", []))
		if bounds.size == Vector2i.ZERO or not _rect_inside_canvas(bounds):
			return _fail("Sanctum district bounds are invalid: %s" % district_id)
		var label_anchor := _parse_point(district.get("label_anchor", []))
		if not bounds.has_point(label_anchor):
			return _fail("Sanctum district label anchor is outside district: %s" % district_id)
		if int(district.get("elevation", 0)) < 1 or int(district.get("elevation", 0)) > 4:
			return _fail("Sanctum district elevation is outside supported bands: %s" % district_id)
		var combined_areas: Array = district.get("combines", [])
		if combined_areas.size() < 2:
			return _fail("Sanctum district must combine related functional areas: %s" % district_id)
		for source_value: Variant in combined_areas:
			var source_id := String(source_value)
			if not REQUIRED_SOURCE_DISTRICTS.has(source_id) or combined_source_districts.has(source_id):
				return _fail("Sanctum source area must be known and combined exactly once: %s" % source_id)
			combined_source_districts[source_id] = true
		districts_by_id[district_id] = district
	for district_id: String in REQUIRED_DISTRICTS:
		if not declared_required.has(district_id) or not districts_by_id.has(district_id):
			return _fail("Sanctum campus is missing required district: %s" % district_id)
	for source_district_id: String in REQUIRED_SOURCE_DISTRICTS:
		if not combined_source_districts.has(source_district_id):
			return _fail("Sanctum source area is not represented in a combined district: %s" % source_district_id)

	var activity_ids: Dictionary[String, bool] = {}
	for value: Variant in data.get("activity_areas", []):
		if not value is Dictionary:
			return _fail("Every campus activity must be an object")
		var activity: Dictionary = value
		var activity_id := String(activity.get("id", ""))
		var district_id := String(activity.get("district", ""))
		if activity_id.is_empty() or activity_ids.has(activity_id) or not districts_by_id.has(district_id):
			return _fail("Campus activity identity or district is invalid")
		var bounds := _parse_bounds(activity.get("bounds", []))
		if bounds.size.x < 288 or bounds.size.y < 288 or not _parse_bounds(districts_by_id[district_id]["bounds"]).encloses(bounds):
			return _fail("Campus activity needs a bounded, readable practice pocket")
		if String(activity.get("label", "")).is_empty() or String(activity.get("purpose", "")).is_empty():
			return _fail("Campus activities must explain their purpose")
		activity_ids[activity_id] = true
	for required_id: String in ["source-court", "movement-garden", "pattern-range", "duel-court", "crucible", "recovery-grove"]:
		if not activity_ids.has(required_id):
			return _fail("Campus activity missing: %s" % required_id)

	var connection_ids: Dictionary[String, bool] = {}
	var connection_graph: Dictionary[String, Array] = {}
	for district_id: String in districts_by_id:
		connection_graph[district_id] = []
	for value: Variant in data.get("connections", []):
		if not value is Dictionary:
			return _fail("Every Sanctum connection must be an object")
		var connection: Dictionary = value
		var connection_id := String(connection.get("id", ""))
		if connection_id.is_empty() or connection_ids.has(connection_id):
			return _fail("Sanctum connection ids must be non-empty and unique")
		var from_id := String(connection.get("from", ""))
		var to_id := String(connection.get("to", ""))
		if not districts_by_id.has(from_id) or not districts_by_id.has(to_id):
			return _fail("Sanctum connection references an unknown district: %s" % connection_id)
		if from_id == to_id:
			return _fail("Sanctum connection cannot link a district to itself: %s" % connection_id)
		if int(connection.get("width", 0)) < 144 or int(connection.get("width", 0)) > 288:
			return _fail("Sanctum connection width is outside bounds: %s" % connection_id)
		var connection_points: Array = connection.get("points", [])
		if not _validate_points(connection_points, 2):
			return _fail("Sanctum connection points are invalid: %s" % connection_id)
		var from_bounds := _parse_bounds((districts_by_id[from_id] as Dictionary).get("bounds", []))
		var to_bounds := _parse_bounds((districts_by_id[to_id] as Dictionary).get("bounds", []))
		if not from_bounds.has_point(_parse_point(connection_points.front())) or not to_bounds.has_point(_parse_point(connection_points.back())):
			return _fail("Sanctum connection endpoints must belong to their declared districts: %s" % connection_id)
		(connection_graph[from_id] as Array).append(to_id)
		(connection_graph[to_id] as Array).append(from_id)
		connection_ids[connection_id] = true
	if connection_ids.size() < REQUIRED_DISTRICTS.size() - 1:
		return _fail("Sanctum campus needs enough bridges/stairs to connect visible districts")
	var visited: Dictionary[String, bool] = {}
	var pending: Array[String] = [REQUIRED_DISTRICTS[0]]
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor_value: Variant in connection_graph[current]:
			var neighbor := String(neighbor_value)
			if not visited.has(neighbor):
				pending.append(neighbor)
	if visited.size() != districts_by_id.size():
		return _fail("Sanctum connections must form one connected district graph")

	var route_ids: Dictionary[String, bool] = {}
	var ordinary_districts: Dictionary[String, bool] = {}
	var advanced_districts: Dictionary[String, bool] = {}
	var accessible_districts: Dictionary[String, bool] = {}
	for value: Variant in data.get("routes", []):
		if not value is Dictionary:
			return _fail("Every Sanctum route must be an object")
		var route: Dictionary = value
		var route_id := String(route.get("id", ""))
		if route_id.is_empty() or route_ids.has(route_id):
			return _fail("Sanctum route ids must be non-empty and unique")
		var route_district_id := String(route.get("district", ""))
		if not districts_by_id.has(route_district_id):
			return _fail("Sanctum route references an unknown district: %s" % route_id)
		var route_kind := String(route.get("kind", ""))
		if not ALLOWED_ROUTE_KINDS.has(route_kind):
			return _fail("Sanctum route has unsupported kind: %s" % route_id)
		if int(route.get("width", 0)) < 48 or int(route.get("width", 0)) > 288:
			return _fail("Sanctum route width is outside bounds: %s" % route_id)
		var route_points: Array = route.get("points", [])
		if not _validate_points(route_points, 2):
			return _fail("Sanctum route points are invalid: %s" % route_id)
		var route_district_bounds := _parse_bounds((districts_by_id[route_district_id] as Dictionary).get("bounds", []))
		for route_point_value: Variant in route_points:
			if not route_district_bounds.has_point(_parse_point(route_point_value)):
				return _fail("Sanctum route leaves its declared district: %s" % route_id)
		if route_kind == "ordinary":
			ordinary_districts[route_district_id] = true
			if bool(route.get("accessible", false)):
				accessible_districts[route_district_id] = true
		elif route_kind == "advanced":
			advanced_districts[route_district_id] = true
		route_ids[route_id] = true
	for district_id: String in REQUIRED_DISTRICTS:
		if not ordinary_districts.has(district_id) or not advanced_districts.has(district_id):
			return _fail("Every Sanctum district requires ordinary and advanced routes: %s" % district_id)
		if not accessible_districts.has(district_id):
			return _fail("Every Sanctum district requires an accessible ordinary route: %s" % district_id)

	for value: Variant in data.get("reset_zones", []):
		if not value is Dictionary:
			return _fail("Every Sanctum reset zone must be an object")
		var reset_zone: Dictionary = value
		var reset_zone_id := String(reset_zone.get("id", ""))
		var reset_district_id := String(reset_zone.get("district", ""))
		if reset_zone_id.is_empty() or reset_zones_by_id.has(reset_zone_id):
			return _fail("Sanctum reset zone ids must be non-empty and unique")
		if not districts_by_id.has(reset_district_id):
			return _fail("Sanctum reset zone references an unknown district: %s" % reset_zone_id)
		if not ALLOWED_RESET_KINDS.has(String(reset_zone.get("kind", ""))) or String(reset_zone.get("reset_group", "")).is_empty():
			return _fail("Sanctum reset zone contract is incomplete: %s" % reset_zone_id)
		var reset_bounds := _parse_bounds(reset_zone.get("bounds", []))
		var reset_district_bounds := _parse_bounds((districts_by_id[reset_district_id] as Dictionary).get("bounds", []))
		if reset_bounds.size == Vector2i.ZERO or not reset_district_bounds.encloses(reset_bounds):
			return _fail("Sanctum reset zone must be bounded by its district: %s" % reset_zone_id)
		reset_zones_by_id[reset_zone_id] = reset_zone
	for required_reset_zone_id: String in ["conservatory-route-reset", "proving-basin-reset"]:
		if not reset_zones_by_id.has(required_reset_zone_id):
			return _fail("Sanctum campus is missing required reset zone: %s" % required_reset_zone_id)

	var arena_value: Variant = data.get("arena", {})
	if not arena_value is Dictionary:
		return _fail("Sanctum arena definition must be an object")
	arena_definition = arena_value
	if String(arena_definition.get("id", "")) != "proving-court-v1":
		return _fail("Sanctum arena requires the stable proving court id")
	var arena_district_id := String(arena_definition.get("district", ""))
	if arena_district_id != "wayfarer-proving-quarter" or not districts_by_id.has(arena_district_id):
		return _fail("Sanctum arena must belong to the proving quarter")
	var arena_bounds := _parse_bounds(arena_definition.get("bounds", []))
	var arena_district_bounds := _parse_bounds((districts_by_id[arena_district_id] as Dictionary).get("bounds", []))
	if arena_bounds.size.x < 320 or arena_bounds.size.y < 240 or not arena_district_bounds.encloses(arena_bounds):
		return _fail("Sanctum arena bounds are invalid")
	if int(arena_definition.get("score_limit", 0)) < SessionRound.MIN_SCORE_LIMIT or int(arena_definition.get("score_limit", 0)) > SessionRound.MAX_SCORE_LIMIT:
		return _fail("Sanctum arena score limit is invalid")
	if int(arena_definition.get("round_seconds", 0)) < SessionRound.MIN_ROUND_SECONDS or int(arena_definition.get("round_seconds", 0)) > SessionRound.MAX_ROUND_SECONDS:
		return _fail("Sanctum arena duration is invalid")
	if int(arena_definition.get("result_seconds", 0)) < SessionRound.MIN_RESULT_SECONDS or int(arena_definition.get("result_seconds", 0)) > SessionRound.MAX_RESULT_SECONDS:
		return _fail("Sanctum arena result duration is invalid")
	if int(arena_definition.get("respawn_ms", 0)) < SessionRound.MIN_RESPAWN_MS or int(arena_definition.get("respawn_ms", 0)) > SessionRound.MAX_RESPAWN_MS:
		return _fail("Sanctum arena respawn delay is invalid")
	if int(arena_definition.get("spawn_protection_ms", 0)) < SessionRound.MIN_PROTECTION_MS or int(arena_definition.get("spawn_protection_ms", 0)) > SessionRound.MAX_PROTECTION_MS:
		return _fail("Sanctum arena spawn protection is invalid")
	var arena_spawns: Array = arena_definition.get("spawns", [])
	if arena_spawns.size() != SessionRound.MAX_PLAYERS:
		return _fail("Sanctum arena requires eight ordered spawn anchors")
	for spawn_value: Variant in arena_spawns:
		var arena_spawn := _parse_point(spawn_value)
		if not arena_bounds.has_point(arena_spawn):
			return _fail("Sanctum arena spawn leaves its bounds")

	for value: Variant in data.get("stations", []):
		if not value is Dictionary:
			return _fail("Every Sanctum station must be an object")
		var station: Dictionary = value
		var station_id := String(station.get("id", ""))
		var station_district_id := String(station.get("district", ""))
		if station_id.is_empty() or stations_by_id.has(station_id):
			return _fail("Sanctum station ids must be non-empty and unique")
		if not districts_by_id.has(station_district_id):
			return _fail("Sanctum station references an unknown district: %s" % station_id)
		if not ALLOWED_STATION_KINDS.has(String(station.get("kind", ""))):
			return _fail("Sanctum station kind is unsupported: %s" % station_id)
		if not ALLOWED_STATION_COMMANDS.has(String(station.get("command", ""))):
			return _fail("Sanctum station command is unsupported: %s" % station_id)
		if not ALLOWED_STATION_AUTHORITIES.has(String(station.get("authority", ""))):
			return _fail("Sanctum station authority is unsupported: %s" % station_id)
		if String(station.get("title", "")).is_empty() or String(station.get("prompt", "")).is_empty():
			return _fail("Sanctum station text is incomplete: %s" % station_id)
		var station_lines_value: Variant = station.get("lines", [])
		if not station_lines_value is Array:
			return _fail("Sanctum station lines must be an array: %s" % station_id)
		var station_lines: Array = station_lines_value
		if station_lines.is_empty() or station_lines.size() > 6:
			return _fail("Sanctum station requires one to six concise lines: %s" % station_id)
		for line_value: Variant in station_lines:
			if String(line_value).is_empty() or String(line_value).length() > 52:
				return _fail("Sanctum station line is invalid: %s" % station_id)
		var station_position := _parse_point(station.get("position", []))
		var station_district_bounds := _parse_bounds((districts_by_id[station_district_id] as Dictionary).get("bounds", []))
		if not station_district_bounds.has_point(station_position):
			return _fail("Sanctum station is outside its district: %s" % station_id)
		var interaction_radius := int(station.get("interaction_radius", 0))
		if interaction_radius < 48 or interaction_radius > 160:
			return _fail("Sanctum station interaction radius is outside bounds: %s" % station_id)
		if station_id == "session-hearth":
			var gather_spawns: Array = station.get("gather_spawns", [])
			if gather_spawns.size() != SessionHearth.MAX_PLAYERS:
				return _fail("Session Hearth requires eight gather spawns")
			var gathered_points: Array[Vector2i] = []
			for gather_value: Variant in gather_spawns:
				var gather_point := _parse_point(gather_value)
				if (
					not station_district_bounds.has_point(gather_point)
					or gather_point.distance_squared_to(station_position) > interaction_radius * interaction_radius
				):
					return _fail("Session Hearth gather spawn leaves its interaction circle")
				for prior_point: Vector2i in gathered_points:
					var minimum_separation := MovementTuning.PLAYER_RADIUS * 2 / SimConfig.FIXED_SCALE + 4
					if gather_point.distance_squared_to(prior_point) < minimum_separation * minimum_separation:
						return _fail("Session Hearth gather spawns overlap")
				gathered_points.append(gather_point)
		stations_by_id[station_id] = station
	for required_station_id: String in ["movement-guide", "controls-lectern", "training-reset", "momentum-chime", "champion-loom", "spell-loom", "farflow-host", "farflow-join", "farflow-charter", "session-hearth", "company-ledger", "parting-bell"]:
		if not stations_by_id.has(required_station_id):
			return _fail("Sanctum campus is missing required station: %s" % required_station_id)

	var target_entity_ids: Dictionary[int, bool] = {}
	var target_values: Variant = data.get("practice_targets", [])
	if not target_values is Array or target_values.size() < 1 or target_values.size() > SessionSnapshot.MAX_TARGETS:
		return _fail("Practice targets must fit the %d-target multiplayer snapshot budget" % SessionSnapshot.MAX_TARGETS)
	for value: Variant in data.get("practice_targets", []):
		if not value is Dictionary:
			return _fail("Every Sanctum practice target must be an object")
		var target: Dictionary = value
		var target_id := String(target.get("id", ""))
		var entity_id := int(target.get("entity_id", 0))
		var target_district_id := String(target.get("district", ""))
		if target_id.is_empty() or practice_targets_by_id.has(target_id):
			return _fail("Sanctum practice target ids must be non-empty and unique")
		if entity_id < 100 or target_entity_ids.has(entity_id):
			return _fail("Sanctum practice target entity ids must be stable and unique: %s" % target_id)
		if not districts_by_id.has(target_district_id):
			return _fail("Sanctum practice target references an unknown district: %s" % target_id)
		var target_position := _parse_point(target.get("position", []))
		var target_district_bounds := _parse_bounds((districts_by_id[target_district_id] as Dictionary).get("bounds", []))
		if not target_district_bounds.has_point(target_position):
			return _fail("Sanctum practice target is outside its district: %s" % target_id)
		var target_radius := int(target.get("radius", 0))
		if target_radius < 12 or target_radius > 32:
			return _fail("Sanctum practice target radius is outside bounds: %s" % target_id)
		var target_health := int(target.get("health", 0))
		if target_health < 20_000 or target_health > 200_000:
			return _fail("Sanctum practice target Health is outside bounds: %s" % target_id)
		if String(target.get("label", "")).is_empty() or String(target.get("reset_policy", "")) != "practice_bell":
			return _fail("Sanctum practice target reset contract is incomplete: %s" % target_id)
		practice_targets_by_id[target_id] = target
		target_entity_ids[entity_id] = true
	if not practice_targets_by_id.has("nexus-sparring-effigy"):
		return _fail("Sanctum campus is missing its sparring effigy")

	for value: Variant in data.get("buildings", []):
		if not value is Dictionary:
			return _fail("Every Sanctum building must be an object")
		var building: Dictionary = value
		var building_id: int = int(building.get("id", 0))
		var district_id := String(building.get("district", ""))
		if building_id <= 0 or buildings_by_id.has(building_id):
			return _fail("Sanctum building ids must be positive and unique")
		if not districts_by_id.has(district_id):
			return _fail("Sanctum building references an unknown district: %d" % building_id)
		if String(building.get("name", "")).is_empty() or String(building.get("style", "")).is_empty():
			return _fail("Sanctum building requires name and style: %d" % building_id)
		var bounds := _parse_bounds(building.get("bounds", []))
		if bounds.size == Vector2i.ZERO or not _rect_inside_canvas(bounds):
			return _fail("Sanctum building bounds are invalid: %d" % building_id)
		var district_bounds := _parse_bounds((districts_by_id[district_id] as Dictionary).get("bounds", []))
		if not district_bounds.encloses(bounds):
			return _fail("Sanctum building is outside its district: %d" % building_id)
		if not ALLOWED_OCCLUSION.has(String(building.get("occlusion_policy", ""))):
			return _fail("Sanctum building needs an explicit occlusion policy: %d" % building_id)
		if not bool(building.get("worldbone", false)):
			return _fail("Sanctum topology building must be immutable worldbone: %d" % building_id)
		if bool(building.get("vaultable", false)):
			return _fail("Vault surfaces are retired; use solid practice walls")
		buildings_by_id[building_id] = building

	var fast_travel_count: int = 0
	for value: Variant in data.get("landmarks", []):
		if not value is Dictionary:
			return _fail("Every Sanctum landmark must be an object")
		var landmark: Dictionary = value
		var landmark_id := String(landmark.get("id", ""))
		var district_id := String(landmark.get("district", ""))
		if landmark_id.is_empty() or landmarks_by_id.has(landmark_id):
			return _fail("Sanctum landmark ids must be non-empty and unique")
		if not districts_by_id.has(district_id) or String(landmark.get("kind", "")).is_empty():
			return _fail("Sanctum landmark is incomplete: %s" % landmark_id)
		var position := _parse_point(landmark.get("position", []))
		var district_bounds := _parse_bounds((districts_by_id[district_id] as Dictionary).get("bounds", []))
		if not district_bounds.has_point(position):
			return _fail("Sanctum landmark is outside its district: %s" % landmark_id)
		if bool(landmark.get("fast_travel", false)):
			fast_travel_count += 1
		landmarks_by_id[landmark_id] = landmark
	if fast_travel_count < REQUIRED_DISTRICTS.size():
		return _fail("Every visible district requires a fast-travel context marker")

	var collision := build_collision_world()
	if not _validate_practice_groups(collision):
		return false
	# Ordinary routes and bridges promise full-width, obstacle-free passage.
	for value: Variant in (data.get("routes", []) as Array) + (data.get("connections", []) as Array):
		var route: Dictionary = value
		if String(route.get("kind", "")) in ["advanced", "garden"]:
			continue
		var points: Array = route["points"]
		var clearance: int = int(route["width"]) / 2 * SimConfig.FIXED_SCALE
		for index: int in range(points.size() - 1):
			var start := _parse_point(points[index]) * SimConfig.FIXED_SCALE
			var end := _parse_point(points[index + 1]) * SimConfig.FIXED_SCALE
			var steps := maxi(1, ceili(Vector2(end - start).length() / (16 * SimConfig.FIXED_SCALE)))
			for sample: int in range(steps + 1):
				var point := Vector2i(Vector2(start).lerp(Vector2(end), float(sample) / steps))
				if not collision.can_occupy(point, clearance):
					return _fail("Ordinary route lacks promised clearance: %s" % route["id"])
	var spawn_fixed := spawn * SimConfig.FIXED_SCALE
	if not collision.can_occupy(spawn_fixed, MovementTuning.PLAYER_RADIUS):
		return _fail("Sanctum campus spawn overlaps authored collision")
	for station_id: String in stations_by_id:
		var station_position := _parse_point((stations_by_id[station_id] as Dictionary).get("position", [])) * SimConfig.FIXED_SCALE
		if not collision.can_occupy(station_position, MovementTuning.PLAYER_RADIUS):
			return _fail("Sanctum station overlaps authored collision: %s" % station_id)
	var hearth_station: Dictionary = stations_by_id.get("session-hearth", {})
	for gather_value: Variant in hearth_station.get("gather_spawns", []):
		var gather_position := _parse_point(gather_value) * SimConfig.FIXED_SCALE
		if not collision.can_occupy(gather_position, MovementTuning.PLAYER_RADIUS):
			return _fail("Session Hearth gather spawn overlaps authored collision")
	for target_id: String in practice_targets_by_id:
		var target: Dictionary = practice_targets_by_id[target_id]
		var target_position := _parse_point(target.get("position", [])) * SimConfig.FIXED_SCALE
		var target_radius := int(target.get("radius", 0)) * SimConfig.FIXED_SCALE
		if not collision.can_occupy(target_position, target_radius):
			return _fail("Sanctum practice target overlaps authored collision: %s" % target_id)
	for spawn_value: Variant in arena_definition.get("spawns", []):
		var arena_spawn := _parse_point(spawn_value) * SimConfig.FIXED_SCALE
		if not collision.can_occupy(arena_spawn, MovementTuning.PLAYER_RADIUS):
			return _fail("Sanctum arena spawn overlaps authored collision")
	content_hash = CanonicalContent.sha256(data)
	return content_hash.length() == 64 or _fail("Sanctum campus hash failed")


func _validate_practice_groups(collision: CollisionWorld) -> bool:
	var values: Variant = data.get("practice_groups", [])
	if not values is Array or values.size() < 1 or values.size() > SessionSnapshot.MAX_TARGETS:
		return _fail("Campus requires a bounded list of practice groups")
	var activities: Dictionary = {}
	for activity: Dictionary in data["activity_areas"]:
		activities[String(activity["id"])] = activity
	var grouped_targets: Dictionary = {}
	for value: Variant in values:
		if not value is Dictionary:
			return _fail("Practice group must be an object")
		var group: Dictionary = value
		var group_id := String(group.get("id", ""))
		var activity_id := String(group.get("activity", ""))
		if group_id.is_empty() or practice_groups_by_id.has(group_id) or not activities.has(activity_id):
			return _fail("Practice group identity or activity is invalid")
		var activity: Dictionary = activities[activity_id]
		var activity_bounds := _parse_bounds(activity["bounds"])
		var bounds := _parse_bounds(group.get("bounds", []))
		if bounds.size.x < 192 or bounds.size.y < 192 or not activity_bounds.encloses(bounds):
			return _fail("Practice group needs an open area inside its activity: %s" % group_id)
		for building: Dictionary in buildings_by_id.values():
			if bounds.intersects(_parse_bounds(building["bounds"])):
				return _fail("Practice group open area overlaps worldbone: %s" % group_id)
		var label := String(group.get("label", ""))
		var purpose := String(group.get("purpose", ""))
		var label_anchor := _parse_point(group.get("label_anchor", []))
		if label.is_empty() or label.length() > 32 or purpose.is_empty() or purpose.length() > 40 or not activity_bounds.encloses(Rect2i(label_anchor, Vector2i(224, 32))):
			return _fail("Practice group needs a concise label inside its activity: %s" % group_id)
		var target_ids: Variant = group.get("target_ids", [])
		var anchors: Variant = group.get("firing_anchors", [])
		var lane_width := int(group.get("lane_width", 0))
		if not target_ids is Array or not anchors is Array or target_ids.is_empty() or target_ids.size() != anchors.size() or lane_width < 40 or lane_width > 96:
			return _fail("Practice group requires one safe firing lane per target: %s" % group_id)
		for index: int in range(target_ids.size()):
			var target_id := String(target_ids[index])
			if not practice_targets_by_id.has(target_id) or grouped_targets.has(target_id):
				return _fail("Practice target must belong to exactly one known group: %s" % target_id)
			var target: Dictionary = practice_targets_by_id[target_id]
			var target_position := _parse_point(target["position"])
			var anchor := _parse_point(anchors[index])
			var clearance := lane_width / 2
			if String(target["district"]) != String(activity["district"]) or not bounds.grow(-clearance).has_point(anchor) or not bounds.grow(-clearance).has_point(target_position):
				return _fail("Practice lane leaves its declared open area: %s" % target_id)
			if anchor.distance_squared_to(target_position) < 128 * 128:
				return _fail("Practice lane is too short for a readable cast: %s" % target_id)
			for station: Dictionary in stations_by_id.values():
				var station_position := Vector2(_parse_point(station["position"]))
				var nearest := Geometry2D.get_closest_point_to_segment(station_position, Vector2(anchor), Vector2(target_position))
				var station_clearance := float(int(station["interaction_radius"]) + clearance)
				if station_position.distance_squared_to(nearest) < station_clearance * station_clearance:
					return _fail("Practice firing lane crosses a station interaction area: %s" % target_id)
			var steps := maxi(1, ceili(Vector2(target_position - anchor).length() / 16.0))
			for step: int in range(steps + 1):
				var point := Vector2i(Vector2(anchor).lerp(Vector2(target_position), float(step) / steps)) * SimConfig.FIXED_SCALE
				if not collision.can_occupy(point, clearance * SimConfig.FIXED_SCALE):
					return _fail("Practice firing lane is blocked by worldbone: %s" % target_id)
			practice_lanes.append({"group_id":group_id, "target_id":target_id, "start":anchor, "end":target_position, "width":lane_width})
			grouped_targets[target_id] = true
		practice_groups_by_id[group_id] = group
	if grouped_targets.size() != practice_targets_by_id.size():
		return _fail("Every practice target needs a purposeful firing group")
	var targets: Array = practice_targets_by_id.values()
	for left: int in range(targets.size()):
		for right: int in range(left + 1, targets.size()):
			var separation := int(targets[left]["radius"]) + int(targets[right]["radius"]) + MovementTuning.PLAYER_RADIUS * 2 / SimConfig.FIXED_SCALE + 8
			if _parse_point(targets[left]["position"]).distance_squared_to(_parse_point(targets[right]["position"])) < separation * separation:
				return _fail("Practice targets leave insufficient walking and silhouette space")
	return true


func build_collision_world() -> CollisionWorld:
	var collision := CollisionWorld.new(canvas_size.x * SimConfig.FIXED_SCALE, canvas_size.y * SimConfig.FIXED_SCALE)
	var building_ids: Array[int] = buildings_by_id.keys()
	building_ids.sort()
	for building_id: int in building_ids:
		var building: Dictionary = buildings_by_id[building_id]
		var bounds := _parse_bounds(building.get("bounds", []))
		collision.add_obstacle(CollisionWorld.Obstacle.new(
			building_id,
			bounds.position.x * SimConfig.FIXED_SCALE,
			bounds.position.y * SimConfig.FIXED_SCALE,
			bounds.end.x * SimConfig.FIXED_SCALE,
			bounds.end.y * SimConfig.FIXED_SCALE,
			false,
			String(building.get("style", "")) == "practice_wall",
		))
	return collision


func elevation_at(point: Vector2i) -> int:
	var elevation: int = 0
	var district_ids: Array[String] = districts_by_id.keys()
	district_ids.sort()
	for district_id: String in district_ids:
		var district: Dictionary = districts_by_id[district_id]
		if _parse_bounds(district.get("bounds", [])).has_point(point):
			elevation = maxi(elevation, int(district.get("elevation", 0)))
	return elevation


static func _parse_bounds(value: Variant) -> Rect2i:
	if not value is Array or (value as Array).size() != 4:
		return Rect2i()
	var values: Array = value
	var rectangle := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
	return rectangle if rectangle.size.x > 0 and rectangle.size.y > 0 else Rect2i()


static func _parse_point(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(-1, -1)
	var values: Array = value
	return Vector2i(int(values[0]), int(values[1]))


func _validate_points(value: Variant, minimum_count: int) -> bool:
	if not value is Array or (value as Array).size() < minimum_count:
		return false
	for point_value: Variant in value:
		var point := _parse_point(point_value)
		if not _point_inside_canvas(point):
			return false
	return true


func _rect_inside_canvas(rectangle: Rect2i) -> bool:
	return rectangle.position.x >= 0 and rectangle.position.y >= reserved_ui_top and rectangle.end.x <= canvas_size.x and rectangle.end.y <= canvas_size.y


func _point_inside_canvas(point: Vector2i, margin: int = 0) -> bool:
	return point.x >= margin and point.y >= reserved_ui_top and point.x <= canvas_size.x - margin and point.y <= canvas_size.y - margin


func _fail(message: String) -> bool:
	last_error = message
	return false
