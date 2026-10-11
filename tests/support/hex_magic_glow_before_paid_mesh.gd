extends RefCounted


# Small, steady luminous cores, not world lighting or a second threat shape.
# No history, timers, textures, particles, shaders or simulation writes.
const MAX_RADIUS := 48.0
const NORMAL_LAYERS := 3
const REDUCED_LAYERS := 1
const SURFACE_LAYERS := 2
const SURFACE_LIMIT := 48
const RING: Array[Vector2] = [
	Vector2(1, 0), Vector2(0.8660254, 0.5), Vector2(0.5, 0.8660254),
	Vector2(0, 1), Vector2(-0.5, 0.8660254), Vector2(-0.8660254, 0.5),
	Vector2(-1, 0), Vector2(-0.8660254, -0.5), Vector2(-0.5, -0.8660254),
	Vector2(0, -1), Vector2(0.5, -0.8660254), Vector2(0.8660254, -0.5),
]


static func projectile_radius(physical_radius: float, current_core_size: float) -> float:
	if not is_finite(physical_radius) or not is_finite(current_core_size) or physical_radius <= 1.0 or current_core_size <= 0.0:
		return 0.0
	# One pixel inside contact geometry; consumed strength shrinks it immediately.
	return minf(MAX_RADIUS, minf(physical_radius - 1.0, current_core_size * 0.70))


static func cue_opacity(cue: Dictionary, duration_ticks: int) -> float:
	var age_value: Variant = cue.get("age_ticks", 0)
	var remaining_value: Variant = cue.get("remaining", 1.0)
	var duration_value: Variant = cue.get("duration", 1.0)
	if typeof(age_value) != TYPE_INT or int(age_value) < 0 or duration_ticks <= 0 or int(age_value) >= duration_ticks \
		or typeof(remaining_value) not in [TYPE_INT, TYPE_FLOAT] or typeof(duration_value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0.0
	var remaining := float(remaining_value)
	var duration := float(duration_value)
	if not is_finite(remaining) or not is_finite(duration) or remaining <= 0.0 or duration <= 0.0:
		return 0.0
	var fade := minf(1.0 - float(age_value) / duration_ticks, clampf(remaining / duration, 0.0, 1.0))
	return fade * fade


static func radial_polygon(position: Vector2, radius: float, layer: int = 0) -> PackedVector2Array:
	if not position.is_finite() or not is_finite(radius) or radius < 1.0 or radius > MAX_RADIUS or layer < 0 or layer >= NORMAL_LAYERS:
		return PackedVector2Array()
	var scale := 1.0 if layer == 0 else (0.68 if layer == 1 else 0.36)
	var points := PackedVector2Array()
	for unit: Vector2 in RING:
		points.append(position + unit * radius * scale)
	return points


static func layer_color(base: Color, bright: Color, layer: int, opacity: float, reduced: bool) -> Color:
	if not is_finite(opacity) or layer < 0 or layer >= NORMAL_LAYERS:
		return Color.TRANSPARENT
	var color := base.lerp(bright, 0.30 if layer == 0 else (0.65 if layer == 1 else 0.90))
	color.a = clampf(opacity, 0.0, 1.0) * (0.055 if reduced else (0.09 if layer == 0 else (0.16 if layer == 1 else 0.24)))
	return color


static func draw_radial(canvas: CanvasItem, position: Vector2, radius: float, base: Color, bright: Color, reduced: bool, opacity: float = 1.0) -> int:
	if canvas == null or not is_finite(opacity) or opacity <= 0.0:
		return 0
	var draws := 0
	for layer: int in (REDUCED_LAYERS if reduced else NORMAL_LAYERS):
		var polygon := radial_polygon(position, radius, layer)
		if polygon.is_empty(): return draws
		canvas.draw_colored_polygon(polygon, layer_color(base, bright, layer, opacity, reduced))
		draws += 1
	return draws


static func surface_opacity(phase: String, intensity: int, reduced: bool) -> float:
	# Formation/decay retain their existing quiet warning/terminal art. Steady
	# active material light is decoration, never a new damage/phase assertion.
	if reduced or phase != "active" or intensity <= 0:
		return 0.0
	return clampf(float(intensity) / 1000.0, 0.0, 1.0) * 0.52


static func surface_polygon(polygon: PackedVector2Array, layer: int) -> PackedVector2Array:
	# Production supplies canonical convex hexes. Fail closed for malformed or
	# concave input instead of allowing an inset to span an unoccupied hole.
	if polygon.size() != 6 or layer < 0 or layer >= SURFACE_LAYERS:
		return PackedVector2Array()
	var center := Vector2.ZERO
	for point: Vector2 in polygon:
		if not point.is_finite() or point.length_squared() > 1.0e12: return PackedVector2Array()
		center += point / 6.0
	var winding := 0.0
	for index: int in 6:
		var edge := polygon[(index + 1) % 6] - polygon[index]
		# Equal consecutive turns alone admit star/crossing vertex orders. Every
		# other vertex must lie strictly on the same interior side of each edge.
		for other: int in 6:
			if other == index or other == (index + 1) % 6: continue
			var side := edge.cross(polygon[other] - polygon[index])
			if absf(side) < 0.001 or (winding != 0.0 and signf(side) != signf(winding)):
				return PackedVector2Array()
			winding = side
	var scale := 0.78 if layer == 0 else 0.46
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		result.append(center.lerp(point, scale))
	return result


static func draw_surface(canvas: CanvasItem, polygon: PackedVector2Array, base: Color, bright: Color, opacity: float) -> int:
	if canvas == null or not is_finite(opacity) or opacity <= 0.0:
		return 0
	var draws := 0
	for layer: int in SURFACE_LAYERS:
		var inset := surface_polygon(polygon, layer)
		if inset.is_empty(): return draws
		# Match HexMaterialSurface's retained RenderingServer submission path;
		# surface preparation also supports a detached canvas outside _draw().
		RenderingServer.canvas_item_add_polygon(canvas.get_canvas_item(), inset,
			PackedColorArray([layer_color(base, bright, layer + 1, opacity, false)]))
		draws += 1
	return draws
