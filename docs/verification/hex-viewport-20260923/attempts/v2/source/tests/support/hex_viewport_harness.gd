extends "res://tests/support/hex_viewport_candidate.gd"

# Test-only bridge for the unchanged Bootstrap call signature. It recomputes the
# same call-local camera values from the drawing Bootstrap and immediately passes
# the exact rectangle into draw_ground_visible; no rectangle or region is stored.
const Candidate = preload("res://tests/support/hex_viewport_candidate.gd")

var candidate_enabled := false
var diagnostics_enabled := false
var draw_ground_us := 0
var last_result := false
var last_diagnostics: Dictionary = {}
var cover_repaint_calls := 0


class GroundCanvas extends Node2D:
	var presenter: Variant
	var court: RefCounted
	var tick := 0.0
	var reduced := false
	var draw_district_base := false
	var candidate_enabled := false
	var diagnostics_enabled := false
	var repaint_cover := false
	var camera_origin := Vector2.ZERO
	var zoom_percent := 100
	var viewport_size := Vector2(1280, 720)
	var draw_invocations := 0
	var draw_ground_us := 0
	var last_result := false
	var last_diagnostics: Dictionary = {}
	var cover_region_count := 0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("121820"), true)
		var zoom: float = Candidate.PixelPresentationScript.zoom_scale(zoom_percent)
		var translation: Vector2 = Candidate.PixelPresentationScript.snapped_canvas_origin(camera_origin, zoom_percent)
		draw_set_transform(translation, 0.0, Vector2(zoom, zoom))
		var began: int = Time.get_ticks_usec()
		var diagnostics: Dictionary = {}
		if candidate_enabled:
			var visible_world: Rect2 = Candidate.visible_world_rect(camera_origin, viewport_size, zoom_percent)
			last_result = presenter.draw_ground_visible(self, court, tick, reduced, draw_district_base, visible_world, zoom, diagnostics, diagnostics_enabled)
		else:
			last_result = presenter.draw_ground(self, court, tick, reduced, draw_district_base)
		draw_ground_us = Time.get_ticks_usec() - began
		last_diagnostics = diagnostics.duplicate(true)
		cover_region_count = 0
		if repaint_cover:
			var polygons: Array[PackedVector2Array] = []
			for material_value: Variant in presenter._cover_surface_regions.values():
				if not material_value is Dictionary:
					continue
				for rows_value: Variant in (material_value as Dictionary).values():
					if not rows_value is Array:
						continue
					for region_value: Variant in rows_value:
						if region_value is Dictionary and typeof(region_value.get("polygon")) == TYPE_PACKED_VECTOR2_ARRAY:
							polygons.append(region_value.polygon)
			cover_region_count = polygons.size()
			if not polygons.is_empty():
				presenter.draw_cover_surfaces(self, polygons, tick, reduced)
		draw_set_transform(Vector2.ZERO)
		draw_invocations += 1


static func new_ground_canvas() -> Node2D:
	return GroundCanvas.new()


func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
	var began: int = Time.get_ticks_usec()
	var result := false
	var diagnostics: Dictionary = {}
	if candidate_enabled and _bootstrap_surface_valid(canvas):
		var bootstrap: Variant = canvas
		var alpha: float = clampf(float(bootstrap.accumulator_seconds) * float(bootstrap.tick_rate), 0.0, 1.0)
		var rendered_position: Vector2 = bootstrap.previous_position.lerp(bootstrap.current_position, alpha)
		var camera_focus_position: Vector2 = bootstrap._camera_focus_position(rendered_position)
		var camera_origin: Vector2 = bootstrap._camera_origin(camera_focus_position)
		var zoom_percent: int = int(bootstrap.player_preferences.camera_zoom_percent)
		var zoom: float = Candidate.PixelPresentationScript.zoom_scale(zoom_percent)
		var visible_world: Rect2 = Candidate.visible_world_rect(camera_origin, bootstrap.get_viewport_rect().size, zoom_percent)
		result = draw_ground_visible(canvas, court, tick, reduced, draw_district_base, visible_world, zoom, diagnostics, diagnostics_enabled)
	else:
		result = super.draw_ground(canvas, court, tick, reduced, draw_district_base)
	draw_ground_us = Time.get_ticks_usec() - began
	last_result = result
	last_diagnostics = diagnostics.duplicate(true)
	return result


func draw_cover_surfaces(canvas: CanvasItem, polygons: Array[PackedVector2Array], tick: float, reduced: bool) -> void:
	cover_repaint_calls += 1
	super.draw_cover_surfaces(canvas, polygons, tick, reduced)


func _bootstrap_surface_valid(canvas: CanvasItem) -> bool:
	if canvas == null or not canvas.has_method("_camera_focus_position") or not canvas.has_method("_camera_origin"):
		return false
	var bootstrap: Variant = canvas
	return bootstrap.player_preferences != null
