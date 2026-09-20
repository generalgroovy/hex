class_name HubDefinition
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const REQUIRED_LAYERS: Array[String] = ["terraces", "crown", "undercroft"]

var data: Dictionary = {}
var last_error: String = ""
var districts_by_id: Dictionary = {}
var travel_nodes_by_id: Dictionary = {}


func load_from_file(path: String) -> bool:
	last_error = ""
	data = {}
	districts_by_id = {}
	travel_nodes_by_id = {}
	if not FileAccess.file_exists(path):
		return _fail("hub definition does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("hub definition cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("hub definition root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	districts_by_id = {}
	travel_nodes_by_id = {}
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported hub schema version")
	if String(data.get("id", "")).is_empty():
		return _fail("hub id is required")
	var bounds: Array = data.get("world_bounds", [])
	if bounds.size() != 4 or int(bounds[2]) <= 0 or int(bounds[3]) <= 0:
		return _fail("world_bounds must be [x, y, width, height] with positive size")
	var layers: Array = data.get("layers", [])
	for required_layer: String in REQUIRED_LAYERS:
		if not layers.has(required_layer):
			return _fail("required layer is missing: %s" % required_layer)

	var districts: Array = data.get("districts", [])
	if districts.size() < 8:
		return _fail("a vast hub requires at least eight major districts")
	for value: Variant in districts:
		if not value is Dictionary:
			return _fail("every district must be an object")
		var district: Dictionary = value
		var district_id := String(district.get("id", ""))
		if district_id.is_empty() or districts_by_id.has(district_id):
			return _fail("district ids must be non-empty and unique: %s" % district_id)
		if not layers.has(String(district.get("layer", ""))):
			return _fail("district has an unknown layer: %s" % district_id)
		if (district.get("center", []) as Array).size() != 2:
			return _fail("district center must have two coordinates: %s" % district_id)
		if int(district.get("radius", 0)) <= 0:
			return _fail("district radius must be positive: %s" % district_id)
		if (district.get("functions", []) as Array).size() < 2:
			return _fail("district must combine at least two functions: %s" % district_id)
		if (district.get("entrances", []) as Array).size() < 2:
			return _fail("district must expose at least two entrances: %s" % district_id)
		if (district.get("movement_routes", []) as Array).is_empty():
			return _fail("district needs a movement route: %s" % district_id)
		var travel_node: Dictionary = district.get("travel_node", {})
		var node_id := String(travel_node.get("id", ""))
		if node_id.is_empty() or travel_nodes_by_id.has(node_id):
			return _fail("travel node ids must be non-empty and unique: %s" % node_id)
		districts_by_id[district_id] = district
		travel_nodes_by_id[node_id] = travel_node

	for district_id: String in districts_by_id:
		var district: Dictionary = districts_by_id[district_id]
		for connection: Variant in district.get("connections", []):
			var connected_id := String(connection)
			if not districts_by_id.has(connected_id):
				return _fail("district %s has unknown connection %s" % [district_id, connection])
			var connected: Dictionary = districts_by_id[connected_id]
			if not (connected.get("connections", []) as Array).has(district_id):
				return _fail("district connection must be reciprocal: %s -> %s" % [district_id, connected_id])

	var spawn_district_id := String(data.get("spawn_district_id", ""))
	if not districts_by_id.has(spawn_district_id):
		return _fail("spawn district is unknown")
	var fast_travel: Dictionary = data.get("fast_travel", {})
	var initial_node_id := String(fast_travel.get("initial_node_id", ""))
	if not travel_nodes_by_id.has(initial_node_id):
		return _fail("initial fast-travel node is unknown")
	if travel_nodes_by_id.size() < int(fast_travel.get("minimum_node_count", 0)):
		return _fail("fast-travel network has fewer nodes than its declared minimum")
	if String(fast_travel.get("authority", "")) != "session_host":
		return _fail("fast travel must remain session-host authoritative")
	if not bool(fast_travel.get("destination_clearance_required", false)):
		return _fail("fast travel requires destination clearance")
	return true


func can_fast_travel(
	origin_id: String,
	destination_id: String,
	unlocked_node_ids: Dictionary,
	blocked_state: String = "",
	destination_is_clear: bool = true,
) -> bool:
	if (
		not last_error.is_empty()
		or origin_id == destination_id
		or not travel_nodes_by_id.has(origin_id)
		or not travel_nodes_by_id.has(destination_id)
	):
		return false
	if (
		not bool(unlocked_node_ids.get(origin_id, false))
		or not bool(unlocked_node_ids.get(destination_id, false))
		or not bool((travel_nodes_by_id[origin_id] as Dictionary).get("enabled", false))
		or not bool((travel_nodes_by_id[destination_id] as Dictionary).get("enabled", false))
		or not destination_is_clear
	):
		return false
	var blocked_states: Array = (data.get("fast_travel", {}) as Dictionary).get("blocked_states", [])
	return blocked_state.is_empty() or not blocked_states.has(blocked_state)


func _fail(message: String) -> bool:
	last_error = message
	return false
