extends CompactCombatHud

# Exact 2026-10-10 pre-mesh panel draw; native raster oracle only.
func _draw_panel(canvas: CanvasItem, rectangle: Rect2, opacity: float) -> void:
	var step := float((data.get("layout", {}) as Dictionary).get("panel_corner_step", 6))
	var points := PackedVector2Array([
		rectangle.position + Vector2(step, 0), rectangle.end - Vector2(step, rectangle.size.y),
		rectangle.end - Vector2(0, rectangle.size.y - step), rectangle.end - Vector2(0, step),
		rectangle.end - Vector2(step, 0), rectangle.position + Vector2(step, rectangle.size.y),
		rectangle.position + Vector2(0, rectangle.size.y - step), rectangle.position + Vector2(0, step),
	])
	canvas.draw_colored_polygon(points, Color(language.ui_color("panel_fill"), opacity))
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(language.ramp_color("aged_brass", 2), 0.72 * opacity), 1.0, false)
