class_name ContinuousContact
extends RefCounted

# Analytic continuous contact. Fractions use scalar float64 (never Vector2's
# float32); authority positions are rounded once to the existing 0.001px grid.
# Broad-phase eligibility retains the exact integer closed-circle predicate.
static func circle_toi(start: Vector2i, finish: Vector2i, center: Vector2i, radius: int) -> float:
	if not SprayContactGeometry.segment_intersects_circle(start, finish, center, radius):
		return -1.0
	var x := float(start.x - center.x)
	var y := float(start.y - center.y)
	var dx := float(finish.x - start.x)
	var dy := float(finish.y - start.y)
	var c := x * x + y * y - float(radius) * float(radius)
	if c <= 0.0: return 0.0
	var a := dx * dx + dy * dy
	if a == 0.0: return -1.0
	var h := x * dx + y * dy
	var root := sqrt(maxf(0.0, h * h - a * c))
	# Stable smaller quadratic root avoids cancellation near the start.
	var denominator := -h + root
	if denominator <= 0.0: return -1.0
	return clampf(c / denominator, 0.0, 1.0)

static func point_at(start: Vector2i, finish: Vector2i, fraction: float) -> Vector2i:
	return Vector2i(roundi(float(start.x) + float(finish.x - start.x) * fraction), roundi(float(start.y) + float(finish.y - start.y) * fraction))

static func circle_surface(center_at_contact: Vector2i, target: Vector2i, target_radius: int) -> Vector2i:
	var dx := float(center_at_contact.x - target.x)
	var dy := float(center_at_contact.y - target.y)
	var length := sqrt(dx * dx + dy * dy)
	if length <= 0.0: return target
	return Vector2i(roundi(float(target.x) + dx * float(target_radius) / length), roundi(float(target.y) + dy * float(target_radius) / length))

static func circle_contact(start: Vector2i, finish: Vector2i, fraction: float, target: Vector2i, target_radius: int) -> Vector2i:
	# Compute the surface from the unrounded swept center. The flight center and
	# physical impact are each independently quantized once, never from each other.
	var dx := float(start.x - target.x) + float(finish.x - start.x) * fraction
	var dy := float(start.y - target.y) + float(finish.y - start.y) * fraction
	var length := sqrt(dx * dx + dy * dy)
	if length <= 0.0: return target
	return Vector2i(roundi(float(target.x) + dx * float(target_radius) / length), roundi(float(target.y) + dy * float(target_radius) / length))

static func box_toi(start: Vector2i, finish: Vector2i, low: Vector2i, high: Vector2i) -> Dictionary:
	var entering := 0.0
	var leaving := 1.0
	var normal := Vector2i.ZERO
	for axis: int in range(2):
		var delta := float(finish[axis] - start[axis])
		if delta == 0.0:
			if start[axis] < low[axis] or start[axis] > high[axis]: return {}
			continue
		var first := float(low[axis] - start[axis]) / delta
		var last := float(high[axis] - start[axis]) / delta
		var sign_normal := -1000
		if first > last:
			var swap := first
			first = last
			last = swap
			sign_normal = 1000
		if first > entering:
			entering = first
			normal = Vector2i.ZERO
			normal[axis] = sign_normal
		leaving = minf(leaving, last)
		if entering > leaving: return {}
	if leaving < 0.0 or entering > 1.0: return {}
	return {"fraction": maxf(0.0, entering), "normal": normal}

static func wall_contact(start: Vector2i, finish: Vector2i, radius: int, world: CollisionWorld) -> Dictionary:
	if world is HexCollisionWorld:
		return world.hex_wall_contact(start, finish, radius)
	var best := {}
	# Preserve the existing square wall-clearance envelope, but sweep it as one
	# continuous segment rather than separate X/Y moves. Actor movement is unchanged.
	# Reuse the world's mutation-aware spatial index. Every candidate still goes
	# through the exact continuous narrow phase and original stable tie-break.
	var minimum := Vector2i(mini(start.x,finish.x),mini(start.y,finish.y))-Vector2i.ONE*radius
	var maximum := Vector2i(maxi(start.x,finish.x),maxi(start.y,finish.y))+Vector2i.ONE*radius
	var candidates := world._candidate_obstacles(minimum,maximum) if radius >= 0 else world.obstacle_view()
	for obstacle: CollisionWorld.Obstacle in candidates:
		var low := Vector2i(obstacle.minimum_x, obstacle.minimum_y)
		var high := Vector2i(obstacle.maximum_x, obstacle.maximum_y)
		var hit := box_toi(start, finish, low - Vector2i.ONE * radius, high + Vector2i.ONE * radius)
		if hit.is_empty(): continue
		if float(hit.fraction) == 0.0:
			var separating := false
			for axis: int in range(2):
				if (start[axis] == low[axis] - radius and finish[axis] <= start[axis]) or (start[axis] == high[axis] + radius and finish[axis] >= start[axis]):
					separating = true
			if separating: continue # Touching while separating/sliding is not entry.
		if not best.is_empty() and (float(hit.fraction) > float(best.fraction) or (float(hit.fraction) == float(best.fraction) and obstacle.obstacle_id >= int(best.id))): continue
		var center := point_at(start, finish, float(hit.fraction))
		hit.center = center
		hit.point = Vector2i(clampi(center.x, low.x, high.x), clampi(center.y, low.y, high.y))
		hit.id = obstacle.obstacle_id
		best = hit
	for axis: int in range(2):
		var limit := world.width if axis == 0 else world.height
		var delta := finish[axis] - start[axis]
		var edge := radius if finish[axis] < radius else limit - radius
		if delta == 0 or (finish[axis] >= radius and finish[axis] <= limit - radius): continue
		var fraction := clampf(float(edge - start[axis]) / float(delta), 0.0, 1.0)
		if not best.is_empty() and fraction > float(best.fraction): continue
		var center := point_at(start, finish, fraction)
		var point := center
		point[axis] = 0 if delta < 0 else limit
		var normal := Vector2i.ZERO
		normal[axis] = -signi(delta) * 1000
		best = {"fraction": fraction, "center": center, "point": point, "normal": normal, "id": -1 - axis}
	return best
