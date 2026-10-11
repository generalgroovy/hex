class_name PixelEffectGeometry
extends RefCounted

# Render-only, world-pixel geometry. Convex, non-overlapping fill pieces prevent
# holes (safe centres and wall shadows) becoming opaque textured polygons.
const Archive = preload("res://src/presentation/archive_magic_contract.gd")
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Occlusion = preload("res://src/presentation/sight_occlusion.gd")
const CACHE_LIMIT: int = 128
const CHORD_ERROR: float = 0.20
const EPSILON: float = 0.0001
var _cache: Dictionary = {}
var _order: Array[String] = []
var _stats := {"cache_hits": 0, "builds": 0, "colliders_considered": 0, "relevant_colliders": 0, "peak_polygons": 0}


func stats() -> Dictionary:
	var result := _stats.duplicate()
	result["cache_entries"] = _cache.size()
	return result


func clear_cache() -> void:
	_cache.clear()
	_order.clear()


func disk_mask(origin: Vector2, radius: float, collision: CollisionWorld = null) -> Dictionary:
	# Raw deposits are not fabricated reaction states. They use the same cached
	# presentation geometry and real wall clearance, with no lifecycle authority.
	if not origin.is_finite() or not is_finite(radius) or radius <= 0.0:
		return {}
	var extent := Rect2(origin - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return _clip_geometry([circle_polygon(origin, radius)], origin, extent, collision, "disk")


func clip_spell_mask(polygons: Array, origin: Vector2, bounds: Rect2, collision: CollisionWorld = null, obstacle_padding: float = 0.0) -> Dictionary:
	if polygons.is_empty() or not origin.is_finite() or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x < 0.0 or bounds.size.y < 0.0 or not is_finite(obstacle_padding) or obstacle_padding < 0.0:
		return {}
	return _clip_geometry(polygons, origin, bounds, collision, "spell", obstacle_padding)


func _clip_geometry(polygons: Array, origin: Vector2, extent: Rect2, collision: CollisionWorld, shape: String, obstacle_padding: float = 0.0) -> Dictionary:
	var obstacles: Array[Rect2] = []
	var key_values: Array = [shape, origin, extent, polygons, obstacle_padding]
	if collision != null:
		key_values.append(Vector2i(collision.width, collision.height))
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			_stats.colliders_considered += 1
			var rect := Rect2(Vector2(obstacle.minimum_x, obstacle.minimum_y) / 1000.0, Vector2(obstacle.maximum_x - obstacle.minimum_x, obstacle.maximum_y - obstacle.minimum_y) / 1000.0).grow(obstacle_padding)
			if extent.intersects(rect, true):
				obstacles.append(rect)
				key_values.append(rect)
		_stats.relevant_colliders += obstacles.size()
	var key := str(key_values)
	if _cache.has(key):
		_stats.cache_hits += 1
		return _cache[key]
	var pieces := polygons.duplicate()
	if collision != null:
		var world_bounds := Rect2(Vector2.ZERO, Vector2(collision.width, collision.height) / 1000.0).grow(-obstacle_padding)
		pieces = _intersect_all(pieces, rectangle_polygon(world_bounds)) if world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0 else []
		for rect: Rect2 in obstacles:
			if rect.has_point(origin):
				pieces.clear()
				break
			pieces = _subtract_all(pieces, rectangle_polygon(rect))
			var shadow := Occlusion.shadow_polygon(origin, rect, origin.distance_to(extent.position) + extent.size.length() + 32.0)
			if shadow.size() >= 3:
				for cutter: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(shadow):
					pieces = _subtract_all(pieces, cutter)
	var result := {"polygons": pieces, "boundaries": boundary_loops(pieces), "bounds": extent, "shape": shape, "active": true, "clipped_by_worldbone": not obstacles.is_empty()}
	_stats.builds += 1
	_stats.peak_polygons = maxi(int(_stats.peak_polygons), pieces.size())
	if _order.size() >= CACHE_LIMIT:
		_cache.erase(_order.pop_front())
	_order.append(key)
	_cache[key] = result
	return result


func reaction_mask(state: RefCounted, definition: Dictionary, tick: int, config: SimConfig, collision: CollisionWorld = null) -> Dictionary:
	return _reaction_mask(state, definition, tick, config, collision, false)


# Archive-only visual regression tooling; live admission remains separate.
func archive_reaction_mask(state: RefCounted, definition: Dictionary, tick: int, config: SimConfig, collision: CollisionWorld = null) -> Dictionary:
	return _reaction_mask(state, definition, tick, config, collision, true)


func _reaction_mask(state: RefCounted, definition: Dictionary, tick: int, config: SimConfig, collision: CollisionWorld, archive: bool) -> Dictionary:
	if state == null or config == null or definition.is_empty() or int(definition.get("wire_id", 0)) != state.recipe_wire_id or tick < state.created_tick or tick >= state.expiry_tick:
		return {}
	var authoritative := Chemistry.recipe(state.recipe_wire_id)
	if archive:
		authoritative = {}
		for entry: Dictionary in Archive.REACTIONS:
			if int(entry.wire_id) == int(state.recipe_wire_id): authoritative = entry; break
	if authoritative.is_empty() or String(definition.get("shape", "")) != String(authoritative.shape):
		return {}
	var shape := String(authoritative.shape)
	var origin := Vector2(state.position_x, state.position_y) / 1000.0
	var radius := float(state.radius) / 1000.0
	if radius <= 0.0:
		return {}
	var extent := _extent(state, shape, origin, radius)
	var obstacles: Array[Rect2] = []
	var key_values: Array = [archive, shape, state.recipe_wire_id, state.position_x, state.position_y, state.direction_x, state.direction_y, state.radius, state.length, state.endpoint_x, state.endpoint_y, state.path_points, state.active(tick)]
	var hail := Vector2.ZERO
	if shape == "pulse_lane":
		var period := maxi(1, config.milliseconds_to_ticks(450))
		var age := maxi(0, tick - state.active_tick) % period
		@warning_ignore("integer_division")
		var amount: int = state.length * age / period
		hail = origin + Vector2(Chemistry.scaled(Vector2i(state.direction_x, state.direction_y), amount)) / 1000.0
		key_values.append(hail)
	if collision != null:
		key_values.append(Vector2i(collision.width, collision.height))
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			_stats.colliders_considered += 1
			var rect := Rect2(Vector2(obstacle.minimum_x, obstacle.minimum_y) / 1000.0, Vector2(obstacle.maximum_x - obstacle.minimum_x, obstacle.maximum_y - obstacle.minimum_y) / 1000.0)
			if extent.intersects(rect, true):
				obstacles.append(rect)
				key_values.append(rect)
		_stats.relevant_colliders += obstacles.size()
	var key := str(key_values)
	if _cache.has(key):
		_stats.cache_hits += 1
		return _cache[key]
	var pieces := _shape_pieces(state, shape, origin, radius, hail)
	var worldbone_clipped := false
	if collision != null:
		pieces = _intersect_all(pieces, rectangle_polygon(Rect2(Vector2.ZERO, Vector2(collision.width, collision.height) / 1000.0)))
		var reach := origin.distance_to(extent.position) + extent.size.length() + 32.0
		for rect: Rect2 in obstacles:
			if rect.has_point(origin):
				pieces.clear()
				worldbone_clipped = true
				break
			var cutters: Array = [rectangle_polygon(rect)]
			var shadow := Occlusion.shadow_polygon(origin, rect, reach)
			if shadow.size() >= 3:
				cutters.append_array(Geometry2D.decompose_polygon_in_convex(shadow))
			for cutter: PackedVector2Array in cutters:
				pieces = _subtract_all(pieces, cutter)
			worldbone_clipped = true
	var boundaries := boundary_loops(pieces)
	var result := {"polygons": pieces, "boundaries": boundaries, "bounds": extent, "shape": shape, "hail_position": hail, "active": state.active(tick), "clipped_by_worldbone": worldbone_clipped}
	_stats.builds += 1
	_stats.peak_polygons = maxi(int(_stats.peak_polygons), pieces.size())
	if _order.size() >= CACHE_LIMIT:
		_cache.erase(_order.pop_front())
	_order.append(key)
	_cache[key] = result
	return result


static func _extent(state: RefCounted, shape: String, origin: Vector2, radius: float) -> Rect2:
	if int(state.recipe_wire_id) == 301:
		var footprint := Chemistry.rampart_bounds(state)
		return Rect2(Vector2(footprint.position) / 1000.0, Vector2(footprint.size) / 1000.0)
	var bounds := Rect2(origin, Vector2.ZERO)
	if shape in ["cover", "plane", "lens"]:
		@warning_ignore("integer_division")
		var side := Vector2(Chemistry.scaled(Vector2i(-state.direction_y, state.direction_x), state.length / 2)) / 1000.0
		bounds = bounds.expand(origin - side).expand(origin + side)
	elif shape in ["water_path", "frost_path", "branch"]:
		for index: int in range(0, state.path_points.size() - 1, 2):
			bounds = bounds.expand(Vector2(state.path_points[index], state.path_points[index + 1]) / 1000.0)
	elif shape in ["corridor", "front", "growing_strip", "pulse_lane", "bands", "reveal_line"]:
		bounds = bounds.expand(Vector2(state.endpoint_x, state.endpoint_y) / 1000.0)
	return bounds.grow(radius)


static func _shape_pieces(state: RefCounted, shape: String, origin: Vector2, radius: float, hail: Vector2) -> Array:
	if int(state.recipe_wire_id) == 301:
		return [rectangle_polygon(_extent(state, shape, origin, radius))]
	if shape in ["annulus", "ring"]:
		var inner := float(state.length) / 1000.0
		if inner >= radius:
			return []
		if inner <= 0.0:
			return [circle_polygon(origin, radius)]
		var outer_loop := circle_polygon(origin, radius)
		var pieces: Array = []
		for index: int in range(outer_loop.size()):
			var a := outer_loop[index] - origin
			var b := outer_loop[(index + 1) % outer_loop.size()] - origin
			pieces.append(PackedVector2Array([origin + a, origin + b, origin + b * inner / radius, origin + a * inner / radius]))
		return pieces
	if shape in ["water_path", "frost_path", "branch"]:
		if state.path_points.size() < 4:
			return [circle_polygon(origin, radius)] if shape == "water_path" else []
		var pieces: Array = []
		for index: int in range(0, state.path_points.size() - 2, 2):
			var a := Vector2(state.path_points[index], state.path_points[index + 1]) / 1000.0
			var b := Vector2(state.path_points[index + 2], state.path_points[index + 3]) / 1000.0
			var additions: Array = [capsule_polygon(a, b, radius)]
			for occupied: PackedVector2Array in pieces:
				additions = _subtract_all(additions, occupied)
			pieces.append_array(additions)
		return pieces
	if shape in ["corridor", "front", "growing_strip", "pulse_lane", "bands", "reveal_line"]:
		var lane := capsule_polygon(origin, Vector2(state.endpoint_x, state.endpoint_y) / 1000.0, radius)
		return _intersect_all([lane], circle_polygon(hail, float(Chemistry.extent(25000)) / 1000.0)) if shape == "pulse_lane" else [lane]
	if shape in ["cover", "plane", "lens"]:
		@warning_ignore("integer_division")
		var side := Vector2(Chemistry.scaled(Vector2i(-state.direction_y, state.direction_x), state.length / 2)) / 1000.0
		return [capsule_polygon(origin - side, origin + side, radius)]
	return [circle_polygon(origin, radius)]


static func circle_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if radius <= 0.0:
		return points
	var count := maxi(16, ceili(PI / acos(clampf(1.0 - CHORD_ERROR / radius, -1.0, 1.0))))
	# Cardinal extrema stay exact; chord sagitta is strictly under one pixel.
	count = ceili(float(count) / 4.0) * 4
	for index: int in range(count):
		points.append(center + Vector2.from_angle(TAU * float(index) / float(count)) * radius)
	return points


static func capsule_polygon(start: Vector2, end: Vector2, radius: float) -> PackedVector2Array:
	if start.is_equal_approx(end):
		return circle_polygon(start, radius)
	var angle := (end - start).angle()
	var half_count := maxi(8, ceili(PI / (2.0 * acos(clampf(1.0 - CHORD_ERROR / radius, -1.0, 1.0)))))
	var points := PackedVector2Array()
	for index: int in range(half_count + 1):
		points.append(end + Vector2.from_angle(angle - PI * 0.5 + PI * float(index) / float(half_count)) * radius)
	for index: int in range(half_count + 1):
		points.append(start + Vector2.from_angle(angle + PI * 0.5 + PI * float(index) / float(half_count)) * radius)
	return points


static func rectangle_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _intersect_all(pieces: Array, clip: PackedVector2Array) -> Array:
	var result: Array = []
	for polygon: PackedVector2Array in pieces:
		result.append_array(Geometry2D.intersect_polygons(polygon, clip))
	return result


static func _subtract_all(pieces: Array, cutter: PackedVector2Array) -> Array:
	var result: Array = []
	for polygon: PackedVector2Array in pieces:
		result.append_array(_subtract_convex(polygon, cutter))
	return result


static func _subtract_convex(polygon: PackedVector2Array, cutter: PackedVector2Array) -> Array:
	# Partition by each cutter half-plane. Every retained piece is convex and
	# disjoint, even when a cutter lies wholly inside its subject (a real hole).
	var result: Array = []
	var inside := polygon
	var sign_value := -1.0 if Geometry2D.is_polygon_clockwise(cutter) else 1.0
	for index: int in range(cutter.size()):
		var a := cutter[index]
		var b := cutter[(index + 1) % cutter.size()]
		var outside := _half_plane(inside, a, b, -sign_value)
		if outside.size() >= 3 and absf(_area(outside)) > EPSILON:
			result.append(outside)
		inside = _half_plane(inside, a, b, sign_value)
		if inside.size() < 3:
			break
	return result


static func _half_plane(polygon: PackedVector2Array, a: Vector2, b: Vector2, sign_value: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty():
		return result
	var previous := polygon[polygon.size() - 1]
	var previous_distance := (b - a).cross(previous - a) * sign_value
	for current: Vector2 in polygon:
		var distance := (b - a).cross(current - a) * sign_value
		if (distance >= 0.0) != (previous_distance >= 0.0):
			result.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance >= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result


static func _area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for index: int in range(polygon.size()):
		result += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return result * 0.5


static func boundary_loops(pieces: Array) -> Array:
	# Remove shared internal edges, including partial overlaps from clipping.
	# This is setup/cache work only; texture stamps never recompute boundaries.
	var edges: Array = []
	for polygon: PackedVector2Array in pieces:
		for index: int in range(polygon.size()):
			var a := polygon[index]
			var b := polygon[(index + 1) % polygon.size()]
			if a.distance_squared_to(b) > EPSILON:
				edges.append([a, b])
	var exposed: Array = []
	for edge: Array in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var delta := b - a
		var length_squared := delta.length_squared()
		var spans: Array = [Vector2(0, 1)]
		for other: Array in edges:
			var c: Vector2 = other[0]
			var d: Vector2 = other[1]
			if delta.dot(d - c) >= 0.0 or absf(delta.cross(c - a)) > 0.002 * sqrt(length_squared) or absf(delta.cross(d - a)) > 0.002 * sqrt(length_squared):
				continue
			var lo := clampf(delta.dot(d - a) / length_squared, 0.0, 1.0)
			var hi := clampf(delta.dot(c - a) / length_squared, 0.0, 1.0)
			var next: Array = []
			for span: Vector2 in spans:
				if lo >= span.y or hi <= span.x:
					next.append(span)
				else:
					if lo > span.x: next.append(Vector2(span.x, lo))
					if hi < span.y: next.append(Vector2(hi, span.y))
			spans = next
			if spans.is_empty(): break
		for span: Vector2 in spans:
			if (span.y - span.x) * delta.length() > 0.005:
				exposed.append([a + delta * span.x, a + delta * span.y])
	var loops: Array = []
	while not exposed.is_empty():
		var edge: Array = exposed.pop_back()
		var loop := PackedVector2Array([edge[0], edge[1]])
		var extending := true
		while extending and loop[0].distance_to(loop[loop.size() - 1]) > 0.01:
			extending = false
			for index: int in range(exposed.size()):
				if loop[loop.size() - 1].distance_to(exposed[index][0]) <= 0.01:
					loop.append(exposed[index][1])
					exposed.remove_at(index)
					extending = true
					break
		if loop.size() >= 4 and loop[0].distance_to(loop[loop.size() - 1]) <= 0.01:
			loop[loop.size() - 1] = loop[0]
			loops.append(loop)
	return loops


static func contains_point(polygons: Array, point: Vector2) -> bool:
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


static func clipped_frame_parts(frame: Dictionary, anchor: Vector2, polygons: Array, rotation: float = 0.0) -> Array:
	var result: Array = []
	var texture := frame.get("texture") as Texture2D
	var source_value: Variant = frame.get("region", frame.get("rect"))
	if texture == null or not source_value is Rect2:
		return result
	var source: Rect2 = source_value
	var pivot: Vector2 = frame.get("pivot", frame.get("pivot_px", Vector2.ZERO))
	var destination := Rect2(anchor - pivot, source.size)
	var rectangle := rectangle_polygon(destination)
	if rotation != 0.0:
		for index: int in range(rectangle.size()):
			rectangle[index] = anchor + (rectangle[index] - anchor).rotated(rotation)
	for polygon: PackedVector2Array in polygons:
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon, rectangle):
			var indices := local_triangle_indices(clipped)
			if indices.is_empty():
				continue # Degenerate/nonfinite output never reaches a GPU polygon draw.
			var uv := PackedVector2Array()
			for point: Vector2 in clipped:
				uv.append((source.position + (point - anchor).rotated(-rotation) + pivot) / texture.get_size())
			result.append({"points": clipped, "uvs": uv, "indices": indices})
	return result


static func local_triangle_indices(points: PackedVector2Array) -> PackedInt32Array:
	if points.size() < 3:
		return PackedInt32Array()
	# Triangulate's winding area sums float cross products. At large world
	# coordinates a genuine subpixel sliver can lose its sign to cancellation.
	# Translate only the triangulation input; never move/round the drawn mask
	# vertices or UVs, and never fill a failed piece using a convex hull.
	var local := PackedVector2Array()
	for point: Vector2 in points:
		if not point.is_finite():
			return PackedInt32Array()
		local.append(point - points[0])
	return Geometry2D.triangulate_polygon(local)


static func draw_frame_part(canvas: CanvasItem, part: Dictionary, texture: Texture2D, opacity: float = 1.0, uv_offset: Vector2 = Vector2.ZERO) -> bool:
	if canvas == null or texture == null or opacity <= 0.0 or (part.get("indices", PackedInt32Array()) as PackedInt32Array).is_empty():
		return false
	var uvs: PackedVector2Array = part.uvs
	if uv_offset != Vector2.ZERO:
		uvs = uvs.duplicate()
		for index: int in range(uvs.size()):
			uvs[index] += uv_offset
	# Explicit indices avoid re-running unstable world-coordinate triangulation
	# inside CanvasItem.draw_polygon. One draw command per original clipped part.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), part.indices, part.points,
		PackedColorArray([Color(1, 1, 1, clampf(opacity, 0.0, 1.0))]), uvs,
		PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
	return true


static func draw_clipped_frame(canvas: CanvasItem, frame: Dictionary, anchor: Vector2, polygons: Array, opacity: float = 1.0, rotation: float = 0.0) -> int:
	if canvas == null or opacity <= 0.0:
		return 0
	var parts := clipped_frame_parts(frame, anchor, polygons, rotation)
	for part: Dictionary in parts:
		draw_frame_part(canvas, part, frame.texture, opacity)
	return parts.size()
