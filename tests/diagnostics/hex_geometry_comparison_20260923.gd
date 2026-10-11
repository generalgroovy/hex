extends SceneTree
@warning_ignore_start("integer_division")

# Historical diagnostic from 2026-09-23: its assertions describe the former
# 48 px, 2,766-cell campus. It does not qualify the current expanded world.
# Read-only same-map lattice oracle. The production HexGrid constants remain
# untouched. Candidate 32 px and 24 px lattices are enumerated against the same
# campus bounds, collision obstacles and 18 px clearance as the live 48 px map.
const MAP_PATH := "res://content/maps/sanctum_campus_g2_v1.json"
const SAMPLE_COUNT := 5
const GEOMETRIES: Array[Dictionary] = [
	{"face_px": 48, "half_width": 24_000, "half_height": 27_712},
	{"face_px": 32, "half_width": 16_000, "half_height": 18_476},
	{"face_px": 24, "half_width": 12_000, "half_height": 13_856},
]

var assertions := 0
var failures := 0
var output_path := "res://.godot/hex-geometry-comparison-20260923-v1.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-geometry-comparison-20260923-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"receipt path is fresh and scoped",
	)
	var layout := SanctumCampusLayout.new()
	_check(layout.load_from_file(MAP_PATH), "production Wellspring campus loads")
	var production := HexWorldDefinition.from_campus(layout)
	_check(production != null, "production 48 px definition builds")
	_check(production != null and production.eligible_cells.size() == 2_766, "production authority retains 2,766 eligible cells")
	_check(HexChemistryWorld.MAX_CELLS == HexChemistrySnapshot.MAX_TOPOLOGY_CELLS, "simulation and chemistry snapshot share the 4,096-cell cap")
	_check(HexChemistryWorld.MAX_CELLS == HexSnapshotWirePacking.MAX_TOPOLOGY_CELLS, "simulation and wire packing share the 4,096-cell cap")
	if failures > 0:
		quit(1)
		return

	var collision: CollisionWorld = layout.build_collision_world()
	var playable_top: int = layout.reserved_ui_top * SimConfig.FIXED_SCALE
	var bounds := Rect2i(Vector2i(0, playable_top), Vector2i(collision.width, collision.height - playable_top))
	_check(bounds == production.world_bounds, "oracle uses the exact production playable bounds")
	var expanded_obstacles: Array[Rect2i] = []
	for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
		expanded_obstacles.append(Rect2i(
			obstacle.minimum_x - HexWorldDefinition.CLEARANCE,
			obstacle.minimum_y - HexWorldDefinition.CLEARANCE,
			obstacle.maximum_x - obstacle.minimum_x + 2 * HexWorldDefinition.CLEARANCE,
			obstacle.maximum_y - obstacle.minimum_y + 2 * HexWorldDefinition.CLEARANCE,
		))

	var cases: Array[Dictionary] = []
	var previous_count := 0
	var production_cells_match := false
	var production_hash_match := false
	for geometry: Dictionary in GEOMETRIES:
		var samples := PackedInt64Array()
		var eligible: Array[Vector2i] = []
		for sample_index: int in SAMPLE_COUNT:
			var started := Time.get_ticks_usec()
			var candidate := _eligible_cells(bounds, expanded_obstacles, geometry)
			samples.append(Time.get_ticks_usec() - started)
			if sample_index == 0:
				eligible = candidate
			else:
				_check(candidate == eligible, "%d px enumeration is deterministic" % int(geometry.face_px))
		var coordinate_safe := _coordinate_bounds_safe(eligible, geometry, production.origin)
		var row_pitch: int = int(geometry.half_height) * 3 / 2
		var local_vertices := _local_vertices(geometry)
		var definition_hash := _definition_hash(layout.content_hash, bounds, local_vertices, production.origin, eligible)
		var face_px := int(geometry.face_px)
		if face_px == 48:
			_check(int(geometry.half_width) == HexGrid.HALF_WIDTH and int(geometry.half_height) == HexGrid.HALF_HEIGHT, "48 px oracle constants equal production")
			production_cells_match = eligible == production.eligible_cells
			production_hash_match = definition_hash == production.definition_hash
			_check(production_cells_match, "48 px oracle exactly matches production cells and ordering")
			_check(production_hash_match, "48 px oracle reproduces the production definition hash")
		else:
			_check(eligible.size() > previous_count, "%d px finer lattice increases same-map cell count" % face_px)
		previous_count = eligible.size()
		cases.append({
			"face_to_face_px": face_px,
			"half_width_fixed": int(geometry.half_width),
			"half_height_fixed": int(geometry.half_height),
			"row_pitch_fixed": row_pitch,
			"eligible_cells": eligible.size(),
			"live_cap": HexChemistryWorld.MAX_CELLS,
			"cap_margin": HexChemistryWorld.MAX_CELLS - eligible.size(),
			"within_live_cap": eligible.size() <= HexChemistryWorld.MAX_CELLS,
			"runtime_coordinate_bounds_safe": coordinate_safe,
			"definition_hash": definition_hash,
			"enumeration_us": _percentiles(samples),
			"samples_us": Array(samples),
		})

	var receipt := {
		"schema_version": 1,
		"probe_version": "hex-geometry-comparison-20260923-v1",
		"engine": Engine.get_version_info()["string"],
		"map_path": MAP_PATH,
		"map_content_hash": layout.content_hash,
		"map_sha256": FileAccess.get_sha256(MAP_PATH),
		"world_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"clearance_fixed": HexWorldDefinition.CLEARANCE,
		"live_topology_cap": HexChemistryWorld.MAX_CELLS,
		"cases": cases,
		"production_48_equivalence": {
			"eligible_cells": production.eligible_cells.size(),
			"definition_hash": production.definition_hash,
			"cells_and_order_match": production_cells_match,
			"definition_hash_match": production_hash_match,
		},
		"source_sha256": {
			"tests/diagnostics/hex_geometry_comparison_20260923.gd": FileAccess.get_sha256("res://tests/diagnostics/hex_geometry_comparison_20260923.gd"),
			"src/sim/hex/hex_grid.gd": FileAccess.get_sha256("res://src/sim/hex/hex_grid.gd"),
			"src/sim/hex/hex_world_definition.gd": FileAccess.get_sha256("res://src/sim/hex/hex_world_definition.gd"),
			"src/sim/hex/hex_chemistry_world.gd": FileAccess.get_sha256("res://src/sim/hex/hex_chemistry_world.gd"),
		},
		"assertions": assertions,
		"failures": failures,
		"scope": "Read-only same-map eligibility enumeration at 48, 32 and 24 px. It does not configure a candidate authority, mutate HexGrid, change the map, raise caps, select effects, truncate cells, or claim gameplay/performance equivalence.",
		"timing_semantics": "Five inclusive topology-enumeration samples per lattice. Map load, collision construction, equivalence checks, hashing and receipt writing are outside timers.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: hex-geometry-comparison-20260923; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _eligible_cells(bounds: Rect2i, expanded_obstacles: Array[Rect2i], geometry: Dictionary) -> Array[Vector2i]:
	var minimum := _world_to_cell(bounds.position, geometry)
	var maximum := minimum
	for point: Vector2i in [bounds.position, bounds.end, Vector2i(bounds.end.x, bounds.position.y), Vector2i(bounds.position.x, bounds.end.y)]:
		var cell := _world_to_cell(point, geometry)
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	var result: Array[Vector2i] = []
	for q: int in range(minimum.x - 2, maximum.x + 3):
		for r: int in range(minimum.y - 2, maximum.y + 3):
			var cell := Vector2i(q, r)
			var polygon := _vertices(cell, geometry)
			var allowed := true
			for point: Vector2i in polygon:
				if point.x < bounds.position.x or point.y < bounds.position.y or point.x > bounds.end.x or point.y > bounds.end.y:
					allowed = false
			if not allowed:
				continue
			for rectangle: Rect2i in expanded_obstacles:
				if _overlaps_rectangle(polygon, rectangle):
					allowed = false
					break
			if allowed:
				result.append(cell)
	result.sort_custom(_cell_less)
	return result


func _world_to_cell(point: Vector2i, geometry: Dictionary) -> Vector2i:
	var half_width := int(geometry.half_width)
	var row_pitch := int(geometry.half_height) * 3 / 2
	var column_pitch := half_width * 2
	var seed_r := _floor_div(point.y, row_pitch)
	var numerator := 2 * row_pitch * point.x - column_pitch * point.y
	var seed_q := _floor_div(numerator, 2 * column_pitch * row_pitch)
	var owners: Array[Vector2i] = []
	for q: int in range(seed_q - 2, seed_q + 3):
		for r: int in range(seed_r - 2, seed_r + 3):
			var candidate := Vector2i(q, r)
			if _point_in_cell(point, candidate, geometry):
				owners.append(candidate)
	owners.sort_custom(_cell_less)
	return owners[0] if not owners.is_empty() else Vector2i(seed_q, seed_r)


func _center(cell: Vector2i, geometry: Dictionary) -> Vector2i:
	var half_width := int(geometry.half_width)
	var row_pitch := int(geometry.half_height) * 3 / 2
	return Vector2i(half_width * 2 * cell.x + half_width * cell.y, row_pitch * cell.y)


func _local_vertices(geometry: Dictionary) -> Array[Vector2i]:
	var half_width := int(geometry.half_width)
	var half_height := int(geometry.half_height)
	return [
		Vector2i(0, -half_height),
		Vector2i(half_width, -half_height / 2),
		Vector2i(half_width, half_height / 2),
		Vector2i(0, half_height),
		Vector2i(-half_width, half_height / 2),
		Vector2i(-half_width, -half_height / 2),
	]


func _vertices(cell: Vector2i, geometry: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center := _center(cell, geometry)
	for local: Vector2i in _local_vertices(geometry):
		result.append(center + local)
	return result


func _point_in_cell(point: Vector2i, cell: Vector2i, geometry: Dictionary) -> bool:
	var polygon := _vertices(cell, geometry)
	for index: int in polygon.size():
		if _orientation(polygon[index], polygon[(index + 1) % polygon.size()], point) < 0:
			return false
	return true


func _overlaps_rectangle(polygon: Array[Vector2i], rectangle: Rect2i) -> bool:
	var corners: Array[Vector2i] = [rectangle.position, Vector2i(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2i(rectangle.position.x, rectangle.end.y)]
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for index: int in polygon.size():
		var edge := polygon[(index + 1) % polygon.size()] - polygon[index]
		axes.append(Vector2i(-edge.y, edge.x))
	for axis: Vector2i in axes:
		var low_a: int = 0x7fffffffffffffff
		var high_a: int = -0x7fffffffffffffff
		var low_b: int = low_a
		var high_b: int = high_a
		for point: Vector2i in polygon:
			var projection := point.x * axis.x + point.y * axis.y
			low_a = mini(low_a, projection)
			high_a = maxi(high_a, projection)
		for point: Vector2i in corners:
			var projection := point.x * axis.x + point.y * axis.y
			low_b = mini(low_b, projection)
			high_b = maxi(high_b, projection)
		if high_a <= low_b or high_b <= low_a:
			return false
	return true


func _coordinate_bounds_safe(cells: Array[Vector2i], geometry: Dictionary, origin: Vector2i) -> bool:
	for cell: Vector2i in cells:
		if absi(cell.x) > 256 or absi(cell.y) > 256:
			return false
		var center := _center(cell, geometry) + origin
		if absi(center.x) > HexGrid.MAX_ABS_QUERY_COORDINATE or absi(center.y) > HexGrid.MAX_ABS_QUERY_COORDINATE:
			return false
	return true


func _definition_hash(map_hash: String, bounds: Rect2i, local_vertices: Array[Vector2i], origin: Vector2i, cells: Array[Vector2i]) -> String:
	var rows: Array = [HexWorldDefinition.SCHEMA, map_hash, "whole_map", bounds.position, bounds.size, local_vertices, origin, cells]
	return CanonicalBytes.sha256_hex(JSON.stringify(HexChemistryWorld._stable(rows)).to_utf8_buffer())


func _percentiles(values: PackedInt64Array) -> Dictionary:
	var ordered := Array(values)
	ordered.sort()
	return {
		"samples": ordered.size(),
		"p50": int(ordered[(ordered.size() - 1) / 2]),
		"p95": int(ordered[ordered.size() - 1]),
		"max": int(ordered[ordered.size() - 1]),
	}


func _floor_div(numerator: int, denominator: int) -> int:
	var quotient := numerator / denominator
	if numerator < 0 and numerator % denominator != 0:
		quotient -= 1
	return quotient


func _orientation(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


func _cell_less(left: Vector2i, right: Vector2i) -> bool:
	return left.x < right.x or (left.x == right.x and left.y < right.y)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("HEX_GEOMETRY_COMPARISON: " + message)
