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
