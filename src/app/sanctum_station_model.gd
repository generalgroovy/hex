class_name SanctumStationModel
extends RefCounted


static func nearest_station_id(stations_by_id: Dictionary, player_position_fixed: Vector2i) -> String:
	var station_ids: Array = stations_by_id.keys()
	station_ids.sort()
	var nearest_id: String = ""
	var nearest_distance_squared: int = 0
	for station_id_value: Variant in station_ids:
		var station_id := String(station_id_value)
		var station: Dictionary = stations_by_id.get(station_id, {})
		if not station_in_reach(stations_by_id, station_id, player_position_fixed):
			continue
		var position_value: Variant = station.get("position", [])
		if not position_value is Array or (position_value as Array).size() != 2:
			continue
		var position_values: Array = position_value
		var radius_fixed: int = int(station.get("interaction_radius", 0)) * SimConfig.FIXED_SCALE
		if radius_fixed <= 0:
			continue
		var station_position := Vector2i(
			int(position_values[0]) * SimConfig.FIXED_SCALE,
			int(position_values[1]) * SimConfig.FIXED_SCALE,
		)
		var offset := player_position_fixed - station_position
		var distance_squared: int = offset.x * offset.x + offset.y * offset.y
		if distance_squared > radius_fixed * radius_fixed:
			continue
		if nearest_id.is_empty() or distance_squared < nearest_distance_squared:
			nearest_id = station_id
			nearest_distance_squared = distance_squared
	return nearest_id


static func station_in_reach(stations: Dictionary, station_id: String, point: Vector2i) -> bool:
	# Authorize the requested action, not an alphabetical nearest-ID tie when
	# several actions share one real building door. Never trust client UI focus.
	var station: Dictionary = stations.get(station_id, {})
	var values: Variant = station.get("position", [])
	if not values is Array or values.size() != 2:
		return false
	var anchor := Vector2i(int(values[0]), int(values[1])) * SimConfig.FIXED_SCALE
	var radius := int(station.get("interaction_radius", 0)) * SimConfig.FIXED_SCALE
	if radius <= 0 or point.distance_squared_to(anchor) > radius * radius:
		return false
	return not station.has("building_id") or point.y >= anchor.y - 16 * SimConfig.FIXED_SCALE


static func impact_launch_direction(layout: SanctumCampusLayout, player_position_fixed: Vector2i) -> Vector2i:
	# Practice launches away from its real facade, never through its own wall.
	# This runs once per admitted request and reads canonical collision content;
	# it does not depend on art, camera or presentation-only geometry.
	var station: Dictionary = layout.stations_by_id.get("momentum-chime", {})
	var building_id := int(station.get("building_id", -1))
	for building: Dictionary in layout.buildings_by_id.values():
		if int(building.get("id", 0)) != building_id and String(building.get("service_station", "")) != "momentum-chime":
			continue
		var bounds := SanctumCampusLayout._parse_bounds(building["bounds"])
		var center := (bounds.position * 2 + bounds.size) * SimConfig.FIXED_SCALE
		var offset := player_position_fixed * 2 - center
		# Compare relative distance from each face with integer cross-products.
		# The larger normalized component points safely away, including corners.
		if absi(offset.x) * bounds.size.y > absi(offset.y) * bounds.size.x:
			return Vector2i.RIGHT if offset.x >= 0 else Vector2i.LEFT
		return Vector2i.DOWN if offset.y >= 0 else Vector2i.UP
	return Vector2i.UP # Pre-service maps retain their original open northern lane.
