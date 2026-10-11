class_name SightOcclusion
extends RefCounted


const CAMERA_ELEVATION_DEGREES := 55.0
const GROUND_Y_SCALE := 0.8191520442889918 # sin(55 degrees), matching the art camera.
const REAR_AWARENESS_RADIUS := 72.0
const MASK_SEGMENTS := 96


static func project_ground(point: Vector2) -> Vector2:
	return Vector2(point.x, point.y * GROUND_Y_SCALE)


static func inverse_project_ground(point: Vector2) -> Vector2:
	return Vector2(point.x, point.y / GROUND_Y_SCALE)


static func ground_aim_angle(screen_aim: Vector2) -> float:
	return inverse_project_ground(screen_aim).angle() if screen_aim.length_squared() > 0.0 else 0.0


static func projected_viewport_cover_radius(origin: Vector2, viewport: Rect2) -> float:
	return viewport_cover_radius(inverse_project_ground(origin), Rect2(inverse_project_ground(viewport.position), inverse_project_ground(viewport.size)), MASK_SEGMENTS)


# A shared world-space range for actor visibility and the terrain mask. The
# camera may place the observer away from center (HUD, lead, world edges), so a
# half-diagonal alone cannot cover every visible corner. Opaque LOS is still
# evaluated separately by point_visible; a wider view never sees through walls.
static func viewport_sight_range(origin: Vector2, viewport: Rect2, minimum_range: float = 720.0) -> float:
	var minimum := maxf(0.0, minimum_range) if is_finite(minimum_range) else 0.0
	if not origin.is_finite() or not viewport.has_area() or not viewport.position.is_finite() or not viewport.end.is_finite():
		return minimum
	return maxf(minimum, projected_viewport_cover_radius(origin, viewport))


static func projected_arc(origin: Vector2, radius: float, start: float, end: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(1, segments)
	for index: int in range(count + 1):
		points.append(origin + project_ground(Vector2.from_angle(lerpf(start, end, float(index) / count)) * radius))
	return points


static func projected_mask_quad(origin: Vector2, inner_radius: float, outer_radius: float, angle_a: float, angle_b: float) -> PackedVector2Array:
	return PackedVector2Array([
		origin + project_ground(Vector2.from_angle(angle_a) * inner_radius),
		origin + project_ground(Vector2.from_angle(angle_a) * outer_radius),
		origin + project_ground(Vector2.from_angle(angle_b) * outer_radius),
		origin + project_ground(Vector2.from_angle(angle_b) * inner_radius),
	])


static func point_visible(origin: Vector2, target: Vector2, aim: Vector2, angle_degrees: float, sight_range: float, opaque_bounds: Array[Rect2], rear_radius: float = REAR_AWARENESS_RADIUS) -> bool:
	# World/collision positions are already screen-cardinal map coordinates.
	# Invert the SAME projection for aim and distance; never warp map geometry.
	if not origin.is_finite() or not target.is_finite() or not aim.is_finite() or not is_finite(angle_degrees) or not is_finite(sight_range) or sight_range <= 0.0:
		return false
	var delta := inverse_project_ground(target - origin)
	var distance_squared := delta.length_squared()
	if distance_squared > sight_range * sight_range:
		return false
	var near_radius := clampf(rear_radius, 0.0, sight_range) if is_finite(rear_radius) else 0.0
	if distance_squared > near_radius * near_radius and angle_degrees < 360.0:
		var half_angle := deg_to_rad(clampf(angle_degrees, 15.0, 360.0)) * 0.5
		if absf(wrapf(delta.angle() - ground_aim_angle(aim), -PI, PI)) > half_angle + 0.000001:
			return false
	return line_clear(origin, target, opaque_bounds)


static func line_clear(origin: Vector2, target: Vector2, opaque_bounds: Array[Rect2]) -> bool:
	for bounds: Rect2 in opaque_bounds:
		if not bounds.has_area():
			continue
		if bounds.has_point(origin) or bounds.has_point(target):
			return false
		var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
		for index: int in 4:
			if Geometry2D.segment_intersects_segment(origin, target, corners[index], corners[(index + 1) % 4]) != null:
				return false
	return true


static func viewport_cover_radius(origin: Vector2, viewport: Rect2, segment_count: int = 96) -> float:
	# The polygon's edges, not just its vertices, must cover the furthest corner.
	var farthest_squared: float = maxf(
		maxf(origin.distance_squared_to(viewport.position), origin.distance_squared_to(viewport.end)),
		maxf(origin.distance_squared_to(Vector2(viewport.end.x, viewport.position.y)), origin.distance_squared_to(Vector2(viewport.position.x, viewport.end.y))),
	)
	return (sqrt(farthest_squared) + 1.0) / cos(PI / float(maxi(3, segment_count)))


static func shadow_polygon(origin: Vector2, occluder: Rect2, outer_distance: float) -> PackedVector2Array:
	if outer_distance <= 0.0 or occluder.size.x <= 0.0 or occluder.size.y <= 0.0 or occluder.has_point(origin):
		return PackedVector2Array()
	return shadow_convex_polygon(origin, PackedVector2Array([
		occluder.position,
		Vector2(occluder.end.x, occluder.position.y),
		occluder.end,
		Vector2(occluder.position.x, occluder.end.y),
	]), outer_distance)


# Returns the two exact silhouette vertices and their bounded outward rays.
# Callers retain the real convex outline; replacing a Hex with its Rect2 would
# incorrectly hide the four traversable corners of its bounding box.
static func shadow_convex_polygon(origin: Vector2, occluder: PackedVector2Array, outer_distance: float) -> PackedVector2Array:
	if not origin.is_finite() or not is_finite(outer_distance) or outer_distance <= 0.0 or not _valid_convex_polygon(occluder) or _point_in_or_on_convex(origin, occluder):
		return PackedVector2Array()
	var center := Vector2.ZERO
	for point: Vector2 in occluder:
		center += point
	center /= float(occluder.size())
	var center_angle: float = (center - origin).angle()
	var minimum_delta := INF
	var maximum_delta := -INF
	var minimum_corner := Vector2.ZERO
	var maximum_corner := Vector2.ZERO
	for corner: Vector2 in occluder:
		var delta: float = wrapf((corner - origin).angle() - center_angle, -PI, PI)
		if delta < minimum_delta:
			minimum_delta = delta
			minimum_corner = corner
		if delta > maximum_delta:
			maximum_delta = delta
			maximum_corner = corner
	var minimum_ray := minimum_corner - origin
	var maximum_ray := maximum_corner - origin
	if minimum_ray.length_squared() <= 0.01 or maximum_ray.length_squared() <= 0.01:
		return PackedVector2Array()
	return PackedVector2Array([
		minimum_corner,
		origin + minimum_ray.normalized() * outer_distance,
		origin + maximum_ray.normalized() * outer_distance,
		maximum_corner,
	])


# Surface shading is separate from strict actor LOS. The tangent chord cuts
# through a blocker; subtract its actual shape so the first surface stays lit.
# Another blocker's shadow still covers that surface, independent of draw order.
static func shadow_outside_surface(origin: Vector2, occluder: PackedVector2Array, outer_distance: float) -> Array[PackedVector2Array]:
	var shadow := shadow_convex_polygon(origin, occluder, outer_distance)
	if shadow.is_empty():
		return []
	return Geometry2D.clip_polygons(shadow, occluder)


static func rectangle_polygon(bounds: Rect2) -> PackedVector2Array:
	return PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])


static func _valid_convex_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var winding := 0
	var area := 0.0
	for index: int in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		var c: Vector2 = points[(index + 2) % points.size()]
		if not a.is_finite() or not b.is_finite() or not c.is_finite() or a == b:
			return false
		area += a.cross(b)
		var turn := (b - a).cross(c - b)
		if absf(turn) <= 0.000001:
			continue
		var turn_sign: int = 1 if turn > 0.0 else -1
		if winding != 0 and turn_sign != winding:
			return false
		winding = turn_sign
	return winding != 0 and absf(area) > 0.000001


static func _point_in_or_on_convex(point: Vector2, polygon: PackedVector2Array) -> bool:
	var positive := false
	var negative := false
	for index: int in range(polygon.size()):
		var edge := polygon[(index + 1) % polygon.size()] - polygon[index]
		var cross := edge.cross(point - polygon[index])
		positive = positive or cross > 0.000001
		negative = negative or cross < -0.000001
		if positive and negative:
			return false
	return true
