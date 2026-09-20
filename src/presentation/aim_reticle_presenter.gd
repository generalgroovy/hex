class_name AimReticlePresenter
extends RefCounted

# Screen-space, not scaled with the arena camera. The empty centre preserves
# visibility of small targets; the short tail communicates outgoing direction.
const RADIUS: float = 8.0
const GAP: float = 4.0

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
		canvas.draw_polyline(points, ink, 4.0, false)
		canvas.draw_polyline(points, parchment, 2.0, false)
	return true
