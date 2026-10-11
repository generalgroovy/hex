extends RefCounted


# One connected, filled material cut replaces the generic two-triangle nose.
# Integer-authored corners retain the pixel language; only the existing travel
# direction and current strength-scaled core determine the transform.
const SHAPES := {
	1: [Vector2(3,-1),Vector2(2,3),Vector2(-2,3),Vector2(-3,0),Vector2(-2,-3),Vector2(1,-3)], # Earth chip.
	2: [Vector2(4,0),Vector2(1,3),Vector2(-3,2),Vector2(-1,0),Vector2(-3,-2),Vector2(0,-1),Vector2(1,-3)], # Flame.
	3: [Vector2(4,0),Vector2(0,3),Vector2(-2,3),Vector2(-4,1),Vector2(-4,-1),Vector2(-2,-3),Vector2(0,-3)], # Droplet.
	4: [Vector2(3,-3),Vector2(-1,-3),Vector2(-3,-1),Vector2(-3,1),Vector2(-1,3),Vector2(3,3),Vector2(3,1),Vector2(0,1),Vector2(-1,0),Vector2(0,-1),Vector2(3,-1)], # Air curl.
	5: [Vector2(4,0),Vector2(-2,2),Vector2(-4,0),Vector2(-2,-2)], # Ice shard.
	6: [Vector2(4,-1),Vector2(-1,4),Vector2(0,1),Vector2(-4,1),Vector2(1,-4),Vector2(0,-1)], # Lightning.
	7: [Vector2(4,0),Vector2(1,1),Vector2(0,4),Vector2(-1,1),Vector2(-4,0),Vector2(-1,-1),Vector2(0,-4),Vector2(1,-1)], # Star.
	8: [Vector2(2,-3),Vector2(0,-1),Vector2(0,1),Vector2(2,3),Vector2(-1,3),Vector2(-3,1),Vector2(-3,-1),Vector2(-1,-3)], # Crescent.
}
const COMPACT_SHAPES := {
	1: [Vector2(3,-2),Vector2(2,3),Vector2(-3,2),Vector2(-2,-3)],
	2: [Vector2(4,0),Vector2(-2,3),Vector2(-1,0),Vector2(-3,-2),Vector2(1,-2)],
	3: [Vector2(4,0),Vector2(-1,3),Vector2(-4,0),Vector2(-1,-3)],
	4: [Vector2(3,-2),Vector2(2,3),Vector2(-3,2),Vector2(-3,-2),Vector2(-1,0),Vector2(1,1)],
	5: [Vector2(4,0),Vector2(-3,2),Vector2(-2,-2)],
	6: [Vector2(3,-2),Vector2(0,3),Vector2(-1,0),Vector2(-3,2),Vector2(0,-3),Vector2(1,0)],
	7: [Vector2(4,0),Vector2(1,1),Vector2(0,4),Vector2(-1,1),Vector2(-4,0),Vector2(-1,-1),Vector2(0,-4),Vector2(1,-1)],
	8: [Vector2(2,-3),Vector2(0,0),Vector2(2,3),Vector2(-3,1),Vector2(-3,-1)],
}
const LIGHT_DIRECTION := Vector2(-0.70710678, -0.70710678)
static var _triangles: Dictionary = {}


static func polygon(element_wire: int, direction: Vector2, radius: float, core_size: float) -> PackedVector2Array:
	if not SHAPES.has(element_wire) or not direction.is_finite() or not is_finite(radius) \
		or not is_finite(core_size) or radius <= 0.0 or core_size <= 0.0:
		return PackedVector2Array()
	var squared := direction.length_squared()
	if not is_finite(squared) or squared <= 0.0:
		return PackedVector2Array()
	# The old core and physical disk remain the limits, including the five-pixel
	# readable floor. Subpixel cores disappear rather than gaining a larger icon.
	var extent := minf(radius, core_size * 0.35) - 0.5
	if extent < 0.5:
		return PackedVector2Array()
	var forward := direction / sqrt(squared)
	var side := Vector2(-forward.y, forward.x)
	var authored: Array = (COMPACT_SHAPES if extent < 2.25 else SHAPES)[element_wire]
	var result := PackedVector2Array()
	for point: Vector2 in authored:
		# Every authored corner is within a five-unit disk, including diagonals.
		var transformed := (forward * point.x + side * point.y) * (extent / 5.0)
		if not transformed.is_finite():
			return PackedVector2Array()
		result.append(transformed)
	return result


static func draw(canvas: CanvasItem, position: Vector2, direction: Vector2, radius: float, core_size: float, element_wire: int, color: Color) -> bool:
	if canvas == null or not position.is_finite() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return false
	var points := polygon(element_wire, direction, radius, core_size)
	if points.is_empty():
		return false
	var colors := surface_colors(points, color)
	var compact := minf(radius, core_size * 0.35) - 0.5 < 2.25
	var key := element_wire + (8 if compact else 0)
	if not _triangles.has(key):
		# Sixteen immutable authored silhouettes, never world-position keys.
		# Triangulating near zero also avoids distant-world cancellation.
		_triangles[key] = Geometry2D.triangulate_polygon(PackedVector2Array((COMPACT_SHAPES if compact else SHAPES)[element_wire]))
	for index: int in points.size():
		points[index] += position
		if not points[index].is_finite():
			return false
	# One existing material cut now catches the same northwest light as terrain.
	# Its colors do not depend on time, camera position or optional effect budget.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), _triangles[key], points,
		colors, PackedVector2Array(), PackedInt32Array(), PackedFloat32Array())
	return true


static func surface_colors(points: PackedVector2Array, color: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	if points.is_empty() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return colors
	var extent := 0.0
	for point: Vector2 in points:
		if not point.is_finite(): return PackedColorArray()
		extent = maxf(extent, point.length())
	if not is_finite(extent) or extent <= 0.0: return colors
	var shade := color.darkened(0.58)
	var light := color.lightened(0.10)
	for point: Vector2 in points:
		var incidence := clampf(0.5 + point.dot(LIGHT_DIRECTION) / (extent * 2.0), 0.0, 1.0)
		colors.append(Color(shade.lerp(light, incidence), color.a))
	return colors


static func spray_origin(geometry: Dictionary) -> Dictionary:
	if not geometry.get("start") is Vector2 or not geometry.get("brace") is PackedVector2Array:
		return {}
	var start: Vector2 = geometry.start
	var brace: PackedVector2Array = geometry.brace
	if not start.is_finite() or brace.size() != 2 or not brace[0].is_finite() or not brace[1].is_finite():
		return {}
	var midpoint := (brace[0] + brace[1]) * 0.5
	var lane := midpoint - start
	var distance := lane.length()
	var half_width := brace[0].distance_to(brace[1]) * 0.5
	if not is_finite(distance) or not is_finite(half_width) or distance <= 0.0 or half_width <= 0.0:
		return {}
	# Inscribe the mark in the existing near-origin triangle. A clipped/collapsed
	# brace cannot acquire an outgoing marker, and the five fan rays are untouched.
	var radius := minf(distance * 0.5, (distance * 0.5) * half_width / sqrt(distance * distance + half_width * half_width))
	if not is_finite(radius) or radius < 1.0:
		return {}
	return {"position": start + lane * 0.5, "direction": lane / distance, "radius": radius, "core_size": radius * 3.0}
