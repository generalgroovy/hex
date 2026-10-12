class_name WellspringMapModel
extends RefCounted
## Read-only navigation projection. Only the owner may validate and execute travel.

var is_open := false
var selected_index := 0
var destinations: Array[Dictionary] = []
var areas: Array[Dictionary] = []
var districts: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var courses: Array[Dictionary] = []
var _route_cache: Dictionary = {}
var world_bounds := Rect2()
var player_position := Vector2.ZERO
var location_visible := true
var availability: Dictionary = {"enabled": false, "reason": "Map unavailable."}
var message := ""
var last_error := ""


func configure(layout: SanctumCampusLayout) -> bool:
	close()
	destinations.clear()
	areas.clear()
	districts.clear()
	connections.clear()
	buildings.clear()
	courses.clear()
	_route_cache.clear()
	world_bounds = Rect2()
	last_error = ""
	if layout == null or layout.content_hash.is_empty() or layout.canvas_size.x <= 0 or layout.canvas_size.y <= 0:
		return _fail("Map content is unavailable.")
	var rows: Array[Dictionary] = layout.travel_destinations()
	if rows.is_empty(): return _fail("No travel destinations are available.")
	var bounds := Rect2(Vector2.ZERO, Vector2(layout.canvas_size))
	var seen := {}
	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		var point: Variant = row.get("position")
		if id.is_empty() or seen.has(id) or String(row.get("label", "")).is_empty() or String(row.get("detail", "")).is_empty() or not point is Array or point.size() != 2:
			return _fail("Map destination metadata is invalid.")
		for coordinate: Variant in point:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate) != floorf(float(coordinate)):
				return _fail("Map destination coordinates are invalid.")
		if not bounds.has_point(Vector2(float(point[0]), float(point[1]))): return _fail("Map destination is outside Wellspring.")
		seen[id] = true
	# Content validation owns walkability. Keep copies so focus cannot edit it.
	destinations = rows.duplicate(true)
	for value: Dictionary in layout.data.get("activity_areas", []): areas.append(value.duplicate(true))
	for value: Dictionary in layout.data.get("districts", []): districts.append(value.duplicate(true))
	for value: Dictionary in layout.data.get("connections", []): connections.append(value.duplicate(true))
	for value: Dictionary in layout.data.get("buildings", []): buildings.append(value.duplicate(true))
	for value: Dictionary in layout.data.get("movement_courses",[]): courses.append(value.duplicate(true))
	world_bounds = bounds
	return true


func open(position_fixed: Vector2i, travel_availability: Dictionary = {}) -> bool:
	if destinations.is_empty(): return false
	location_visible = true
	update_position(position_fixed)
	set_availability(travel_availability)
	selected_index = 0
	var nearest := INF
	for index: int in destinations.size():
		var distance := player_position.distance_squared_to(destination_position(index))
		if distance < nearest:
			nearest = distance
			selected_index = index
	is_open = true
	message = "" if bool(availability.enabled) else String(availability.reason)
	return true


func close() -> void:
	is_open = false
	message = ""
	selected_index = 0


func update_position(position_fixed: Vector2i) -> void:
	player_position = Vector2(position_fixed) / float(SimConfig.FIXED_SCALE)


func set_availability(value: Dictionary) -> void:
	var next := {"enabled": bool(value.get("enabled", true)), "reason": String(value.get("reason", "Travel is unavailable right now."))}
	if next == availability: return # A draw refresh must not erase a target-specific refusal.
	availability = next
	message = "" if bool(availability.enabled) else String(availability.reason)


func select(index: int) -> void:
	if not is_open or index < 0 or index >= destinations.size(): return
	selected_index = index
	message = "" if bool(availability.enabled) else String(availability.reason)


func move(delta: int) -> void:
	if destinations.is_empty(): return
	select(clampi(selected_index + delta, 0, destinations.size() - 1))


func selected_destination() -> Dictionary:
	return destinations[selected_index].duplicate(true) if is_open and selected_index >= 0 and selected_index < destinations.size() else {}


func destination_position(index: int) -> Vector2:
	if index < 0 or index >= destinations.size(): return Vector2.ZERO
	var point: Array = destinations[index].position
	return Vector2(float(point[0]), float(point[1]))


func current_location() -> String:
	if not location_visible: return "Away from Wellspring"
	if not world_bounds.has_point(player_position): return "Outside Wellspring"
	for rows: Array[Dictionary] in [areas, districts]:
		var label := ""
		var smallest := INF
		for row: Dictionary in rows:
			var bounds := Rect2(SanctumCampusLayout._parse_bounds(row.get("bounds", [])))
			if bounds.has_point(player_position) and bounds.get_area() < smallest:
				smallest = bounds.get_area()
				label = String(row.get("label", ""))
		if not label.is_empty(): return label
	return "Open paths"


func district_at(point: Vector2) -> String:
	var selected := ""
	var smallest := INF
	for district: Dictionary in districts:
		var rect := Rect2(SanctumCampusLayout._parse_bounds(district.get("bounds",[])))
		if rect.has_point(point) and rect.get_area()<smallest:
			selected=String(district.id)
			smallest=rect.get_area()
	return selected


func selected_route() -> Dictionary:
	# Runner's Vision supplies the optional destination guidance precedent.
	# These are authored district connections, never an invented collision-safe
	# polyline through buildings or a fastest-route claim.
	# https://www.ea.com/amp/news/runners-vision-in-mirrors-edge-catalyst
	if not is_open or not location_visible or not world_bounds.has_point(player_position): return {}
	var origin := district_at(player_position)
	var target := district_at(destination_position(selected_index))
	if origin.is_empty() or target.is_empty(): return {}
	var key := origin+"/"+target
	if _route_cache.has(key): return (_route_cache[key] as Dictionary).duplicate(true)
	var queue: Array[String]=[origin]
	var previous := {origin:{}}
	while not queue.is_empty() and not previous.has(target):
		var current := queue.pop_front() as String
		for connection: Dictionary in connections:
			var other := String(connection.to) if String(connection.from)==current else String(connection.from) if String(connection.to)==current else ""
			if other.is_empty() or previous.has(other): continue
			previous[other]={"district":current,"connection":String(connection.id)}
			queue.append(other)
	if not previous.has(target): return {}
	var path: Array[String]=[]
	var district_ids: Array[String]=[target]
	var cursor := target
	while cursor!=origin:
		path.push_front(String(previous[cursor].connection))
		cursor=String(previous[cursor].district)
		district_ids.push_front(cursor)
	var labels := PackedStringArray()
	for id: String in district_ids:
		for row: Dictionary in districts:
			if String(row.id)==id: labels.append(String(row.label).capitalize());break
	var result := {"connection_ids":path,"district_ids":district_ids,"description":"Already in the destination district." if path.is_empty() else "District connections: "+" > ".join(labels)+". Choose your local approach around real cover."}
	_route_cache[key]=result
	return result.duplicate(true)


func selected_context() -> Array[String]:
	if not message.is_empty(): return [message]
	var destination := selected_destination()
	if destination.is_empty(): return []
	var values: Array[String]=[String(destination.detail)]
	var id := district_at(destination_position(selected_index))
	for row: Dictionary in courses:
		if String(row.get("district",""))==id:
			values.append("Optional route: "+String(row.get("purpose","")))
			break
	var route := selected_route()
	if not route.is_empty(): values.append(String(route.description))
	return values


func request_travel() -> Dictionary:
	var selected := selected_destination()
	if selected.is_empty(): return {}
	if not bool(availability.enabled):
		message = String(availability.reason)
		return {}
	# Send identity, never a client-selected coordinate or a pre-authorized claim.
	return {"action": "travel", "destination_id": String(selected.id)}


func view() -> Dictionary:
	return {"open": is_open, "current_location": current_location(), "selected": selected_destination(), "selected_index": selected_index, "count": destinations.size(), "enabled": bool(availability.enabled), "message": message}


func _fail(error: String) -> bool:
	last_error = error
	return false
