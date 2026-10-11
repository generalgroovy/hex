class_name AimReticlePresenter
extends RefCounted

# Screen-space, not scaled with the arena camera. The empty centre preserves
# visibility of small targets; the short tail communicates outgoing direction.
const RADIUS: float = 8.0
const GAP: float = 4.0
const OUTLINE_WIDTH: float = 4.0
const VIEWPORT_INSET: float = RADIUS + OUTLINE_WIDTH * 0.5


# Shorten the original screen-space aim segment, never clamp its axes separately
# or feed the display position back into aim authority. An origin outside the
# inset remains valid when its forward segment crosses the visible rectangle.
# INF deliberately reaches the existing no-draw guard when no full cue fits.
static func controller_position(origin: Vector2, requested: Vector2, viewport: Rect2) -> Vector2:
	if not origin.is_finite() or not requested.is_finite() or not viewport.position.is_finite() \
		or not viewport.size.is_finite() or not viewport.end.is_finite() \
		or viewport.size.x < VIEWPORT_INSET * 2.0 or viewport.size.y < VIEWPORT_INSET * 2.0:
		return Vector2(INF, INF)
	var lower := viewport.position + Vector2.ONE * VIEWPORT_INSET
	var upper := viewport.end - Vector2.ONE * VIEWPORT_INSET
	var displacement := requested - origin
	if not displacement.is_finite():
		return Vector2(INF, INF)
	var first := 0.0
	var last := 1.0
	for axis: int in range(2):
		if displacement[axis] == 0.0:
			if origin[axis] < lower[axis] or origin[axis] > upper[axis]:
				return Vector2(INF, INF)
			continue
		var near := (lower[axis] - origin[axis]) / displacement[axis]
		var far := (upper[axis] - origin[axis]) / displacement[axis]
		first = maxf(first, minf(near, far))
		last = minf(last, maxf(near, far))
		if first > last:
			return Vector2(INF, INF)
	# Retain the exact previous endpoint in the ordinary, unclipped case.
	if last == 1.0:
		return requested
	# Scalar interpolation avoids an intermediate rounded Vector2 product at an
	# exact boundary. Refuse numerically unrepresentable intersections as well.
	var placed := Vector2(origin.x + displacement.x * last, origin.y + displacement.y * last)
	if not placed.is_finite() or placed.x < lower.x or placed.x > upper.x or placed.y < lower.y or placed.y > upper.y:
		return Vector2(INF, INF)
	return placed

static func segments(position: Vector2, aim_direction: Vector2 = Vector2.RIGHT) -> Array[PackedVector2Array]:
	var output: Array[PackedVector2Array] = []
	if not position.is_finite() or not aim_direction.is_finite():
		return output
	for direction: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		output.append(PackedVector2Array([position + direction * GAP, position + direction * RADIUS]))
	var aim := aim_direction.normalized() if aim_direction.length_squared() > 0.001 else Vector2.RIGHT
	output.append(PackedVector2Array([position - aim * 7.0 + aim.orthogonal(), position - aim * 7.0 - aim.orthogonal()]))
	return output

static func draw(canvas: CanvasItem, screen_position: Vector2, aim_direction: Vector2 = Vector2.RIGHT, blocked: bool = false) -> bool:
	if canvas == null:
		return false
	var lines := segments(screen_position, aim_direction)
	if lines.is_empty():
		return false
	var ink := Color("191d25")
	var parchment := Color("e6c283") if blocked else Color("f8edcb")
	for points: PackedVector2Array in lines:
		canvas.draw_polyline(points, ink, OUTLINE_WIDTH, false)
		canvas.draw_polyline(points, parchment, 2.0, false)
	return true
