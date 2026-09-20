class_name HexConvexGeometry
extends RefCounted
@warning_ignore_start("integer_division")

# Six authoritative faces. Collision queries use raw integer edge normals;
# movement receives this one normalized table on host and prediction alike.
const TIME_EPSILON := 1.0e-12
const NORMALS: Array[Vector2i] = [Vector2i(500, -866), Vector2i(1000, 0), Vector2i(500, 866), Vector2i(-500, 866), Vector2i(-1000, 0), Vector2i(-500, -866)]
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1)]

static func polygon(cell: Vector2i, origin: Vector2i) -> Array[Vector2i]:
	var points := HexGrid.vertices(cell)
	for index: int in points.size(): points[index] += origin
	return points

static func box_overlaps(center: Vector2i, radius: int, cell: Vector2i, origin: Vector2i) -> bool:
	if not _valid_query(center, center, radius, cell, origin): return false
	for plane: Dictionary in _box_planes(cell, origin, radius):
		var n: Vector2i = plane.n
		if center.x * n.x + center.y * n.y >= int(plane.limit): return false
	return true

static func sweep_box(start: Vector2i, finish: Vector2i, radius: int, cell: Vector2i, origin: Vector2i) -> Dictionary:
	if not _valid_query(start, finish, radius, cell, origin): return {}
	# SAT axes of hex + AABB. The additional Y planes are essential: offsetting
	# only six hex faces would overfill the Minkowski sum at its top/bottom tips.
	var enter := 0.0
	var leave := 1.0
	var face := -1
	var hit_normal := Vector2i.ZERO
	for plane: Dictionary in _box_planes(cell, origin, radius):
		var n: Vector2i = plane.n
		var distance: int = start.x * n.x + start.y * n.y - int(plane.limit)
		var travel: int = (finish.x - start.x) * n.x + (finish.y - start.y) * n.y
		if distance >= 0 and travel >= 0: return {}
		if travel == 0: continue
		var time := -float(distance) / float(travel)
		if travel < 0:
			if time > enter + TIME_EPSILON or (absf(time - enter) <= TIME_EPSILON and (face < 0 or (int(plane.face) >= 0 and int(plane.face) < face))):
				enter = maxf(enter, time)
				face = int(plane.face)
				hit_normal = plane.normal
		else: leave = minf(leave, time)
		if enter >= leave: return {}
	if enter >= 1.0 or leave <= 0.0: return {}
	var center := ContinuousContact.point_at(start, finish, maxf(0.0, enter))
	var point := center - Vector2i(signi(hit_normal.x) * radius, signi(hit_normal.y) * radius)
	return {"fraction": maxf(0.0, enter), "center": center, "point": point, "normal": hit_normal, "face": face, "runnable": face >= 0}

static func sweep_circle(start: Vector2i, finish: Vector2i, radius: int, cell: Vector2i, origin: Vector2i) -> Dictionary:
	if not _valid_query(start, finish, radius, cell, origin): return {}
	var points := polygon(cell, origin)
	var best := {}
	if HexGrid._point_strictly_in_cell(start - origin, cell):
		return {"fraction": 0.0, "center": start, "point": start, "normal": Vector2i.ZERO, "face": -1, "runnable": false}
	for index: int in 6:
		var a: Vector2i = points[index]
		var b: Vector2i = points[(index + 1) % 6]
		var edge := b - a
		var n := Vector2i(edge.y, -edge.x)
		var length := sqrt(float(n.x) * float(n.x) + float(n.y) * float(n.y))
		var distance := float(start.x - a.x) * n.x + float(start.y - a.y) * n.y
		var travel := float(finish.x - start.x) * n.x + float(finish.y - start.y) * n.y
		var initial_projection: int = (start.x - a.x) * edge.x + (start.y - a.y) * edge.y
		if distance >= 0.0 and distance < float(radius) * length and initial_projection >= 0 and initial_projection <= edge.x * edge.x + edge.y * edge.y:
			var point := Vector2i(roundi(float(start.x) - float(n.x) * distance / (length * length)), roundi(float(start.y) - float(n.y) * distance / (length * length)))
			best = _earlier(best, {"fraction": 0.0, "center": start, "point": point, "normal": NORMALS[index], "face": index, "runnable": true})
		if travel < 0.0:
			var time := (float(radius) * length - distance) / travel
			if time >= 0.0 and time <= 1.0:
				var x := float(start.x) + float(finish.x - start.x) * time - float(n.x) * radius / length
				var y := float(start.y) + float(finish.y - start.y) * time - float(n.y) * radius / length
				var projection := (x - a.x) * edge.x + (y - a.y) * edge.y
				var edge_squared: int = edge.x * edge.x + edge.y * edge.y
				if projection >= 0.0 and projection <= float(edge_squared):
					var candidate := {"fraction": time, "center": ContinuousContact.point_at(start, finish, time), "point": Vector2i(roundi(x), roundi(y)), "normal": NORMALS[index], "face": index, "runnable": true}
					best = _earlier(best, candidate)
		var vertex_time := ContinuousContact.circle_toi(start, finish, a, radius)
		if vertex_time < 0.0: continue
		var offset := start - a
		var delta := finish - start
		if vertex_time == 0.0 and offset.x * offset.x + offset.y * offset.y == radius * radius and offset.x * delta.x + offset.y * delta.y >= 0: continue
		var center := ContinuousContact.point_at(start, finish, vertex_time)
		var normal := SimCommand._normalized_direction(center.x - a.x, center.y - a.y)
		best = _earlier(best, {"fraction": vertex_time, "center": center, "point": a, "normal": normal, "face": index, "runnable": false})
	return best

static func nearby_face(center: Vector2i, radius: int, tolerance: int, cell: Vector2i, origin: Vector2i, requested_face: int = -1) -> Dictionary:
	if not _valid_query(center, center, radius, cell, origin) or tolerance < 0 or tolerance > 10_000 or requested_face < -1 or requested_face >= 6: return {}
	var points := polygon(cell, origin)
	var best := {}
	for index: int in 6:
		if requested_face >= 0 and index != requested_face: continue
		var a: Vector2i = points[index]
		var edge := points[(index + 1) % 6] - a
		var n := Vector2i(edge.y, -edge.x)
		var distance: int = (center.x - a.x) * n.x + (center.y - a.y) * n.y - radius * (absi(n.x) + absi(n.y))
		if distance < 0 and requested_face < 0: continue
		var length := sqrt(float(n.x) * float(n.x) + float(n.y) * float(n.y))
		var gap := float(distance) / length
		if absf(gap) > tolerance: continue
		var touching := center - Vector2i(signi(n.x) * radius, signi(n.y) * radius)
		var projection: int = (touching.x - a.x) * edge.x + (touching.y - a.y) * edge.y
		if projection < 0 or projection > edge.x * edge.x + edge.y * edge.y: continue
		if best.is_empty() or gap < float(best.gap): best = {"face": index, "normal": NORMALS[index], "gap": gap}
	return best

static func tangent(vector: Vector2i, normal: Vector2i) -> Vector2i:
	var denominator: int = normal.x * normal.x + normal.y * normal.y
	if denominator == 0: return vector
	var dot: int = vector.x * normal.x + vector.y * normal.y
	return vector - Vector2i(dot * normal.x / denominator, dot * normal.y / denominator)

static func _box_planes(cell: Vector2i, origin: Vector2i, radius: int) -> Array[Dictionary]:
	var points := polygon(cell, origin)
	var result: Array[Dictionary] = []
	for index: int in 6:
		var point: Vector2i = points[index]
		var edge := points[(index + 1) % 6] - point
		var n := Vector2i(edge.y, -edge.x)
		result.append({"n": n, "limit": point.x * n.x + point.y * n.y + radius * (absi(n.x) + absi(n.y)), "face": index, "normal": NORMALS[index]})
	var center := HexGrid.center(cell) + origin
	result.append({"n": Vector2i(0, -1), "limit": -center.y + HexGrid.HALF_HEIGHT + radius, "face": -1, "normal": Vector2i(0, -1000)})
	result.append({"n": Vector2i(0, 1), "limit": center.y + HexGrid.HALF_HEIGHT + radius, "face": -1, "normal": Vector2i(0, 1000)})
	return result

static func _earlier(first: Dictionary, second: Dictionary) -> Dictionary:
	if first.is_empty() or float(second.fraction) < float(first.fraction) - TIME_EPSILON: return second
	if absf(float(second.fraction) - float(first.fraction)) <= TIME_EPSILON:
		if bool(second.runnable) and not bool(first.runnable): return second
		if bool(second.runnable) == bool(first.runnable) and int(second.face) < int(first.face): return second
	return first


static func _valid_query(start: Vector2i, finish: Vector2i, radius: int, cell: Vector2i, origin: Vector2i) -> bool:
	return radius >= 0 and radius <= HexGrid.MAX_SWEEP_RADIUS and absi(cell.x) <= 256 and absi(cell.y) <= 256 and HexGrid._query_point_valid(start) and HexGrid._query_point_valid(finish) and HexGrid._query_point_valid(origin) and HexGrid._query_point_valid(HexGrid.center(cell) + origin)
