class_name WellspringWayfinding
extends RefCounted


const DEFAULT_PATH := "res://content/visual/wellspring_wayfinding_v1.json"
const EXPECTED_ID := "wellspring-wayfinding-v1"
const EXPECTED_AUTHORITY := "presentation only; authored map topology, collision, elevation, stations and routes remain canonical elsewhere"
const ALLOWED_KINDS := ["movement", "rest", "archive", "spell", "build", "farflow", "duel", "alchemy"]

var language: VisualLanguage
var data: Dictionary = {}
var points: Array[Dictionary] = []
var content_hash := ""
var last_error := ""


func configure(visual_language: VisualLanguage, layout: SanctumCampusLayout, path: String = DEFAULT_PATH) -> bool:
	language = visual_language
	data.clear()
	points.clear()
	content_hash = ""
	last_error = ""
	if language == null or layout == null or language.ramps.is_empty() or layout.districts_by_id.is_empty():
		return _fail("Wellspring wayfinding requires validated visual language and campus layout")
	if not FileAccess.file_exists(path):
		return _fail("Wellspring wayfinding does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Wellspring wayfinding cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Wellspring wayfinding root must be an object")
	data = parsed
	if not validate(layout):
		data.clear()
		return false
	content_hash = source.sha256_text()
	return true


func validate(layout: SanctumCampusLayout) -> bool:
	last_error = ""
	points.clear()
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Wellspring wayfinding identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Wellspring wayfinding must remain presentation-only")
	var budgets: Dictionary = data.get("budgets", {})
	if int(budgets.get("maximum_visible_labels", 0)) < 1 or int(budgets.get("maximum_visible_labels", 0)) > 6 \
		or int(budgets.get("label_distance", 0)) < 240 or int(budgets.get("label_distance", 0)) > 960 \
		or int(budgets.get("label_exclusion_radius", 0)) < 32 or int(budgets.get("label_exclusion_radius", 0)) > 96 \
		or int(budgets.get("marker_radius", 0)) < 8 or int(budgets.get("marker_radius", 0)) > 32:
		return _fail("Wellspring wayfinding budgets are unsafe")
	var values: Variant = data.get("points", [])
	if not values is Array or (values as Array).size() < 8 or (values as Array).size() > 12:
		return _fail("Wellspring wayfinding requires eight to twelve purpose points")
	var ids: Dictionary[String, bool] = {}
	for value: Variant in values:
		if not value is Dictionary:
			return _fail("Wellspring wayfinding point must be an object")
		var point: Dictionary = value
		var point_id := String(point.get("id", ""))
		var district_id := String(point.get("district", ""))
		var kind := String(point.get("kind", ""))
		var title := String(point.get("title", ""))
		var subtitle := String(point.get("subtitle", ""))
		var position_values: Array = point.get("position", [])
		if point_id.is_empty() or ids.has(point_id) or not layout.districts_by_id.has(district_id) or kind not in ALLOWED_KINDS:
			return _fail("Wellspring wayfinding point identity is invalid: %s" % point_id)
		if title.is_empty() or title.length() > 28 or subtitle.is_empty() or subtitle.length() > 30 or position_values.size() != 2:
			return _fail("Wellspring wayfinding point copy or position is invalid: %s" % point_id)
		var position := Vector2i(int(position_values[0]), int(position_values[1]))
		var district: Dictionary = layout.districts_by_id[district_id]
		if not SanctumCampusLayout._parse_bounds(district.get("bounds", [])).has_point(position):
			return _fail("Wellspring wayfinding point leaves its district: %s" % point_id)
		ids[point_id] = true
		points.append(point)
	return true


func draw(canvas: CanvasItem, focus_world_position: Vector2, tick: int, reduced_effects: bool) -> void:
	if canvas == null or language == null:
		return
	var budgets: Dictionary = data.get("budgets", {})
	var maximum := int(budgets.get("maximum_visible_labels", 4))
	var label_distance := float(budgets.get("label_distance", 720))
	var label_exclusion_radius := float(budgets.get("label_exclusion_radius", 64))
	var marker_radius := float(budgets.get("marker_radius", 18))
	var ordered: Array[Dictionary] = points.duplicate()
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _position(left).distance_squared_to(focus_world_position) < _position(right).distance_squared_to(focus_world_position)
	)
	var labels_drawn := 0
	for point: Dictionary in ordered:
		var position := _position(point)
		var accent := _accent_for_kind(String(point.get("kind", "")))
		_draw_marker(canvas, position, marker_radius, accent, tick, reduced_effects)
		var focus_distance := position.distance_to(focus_world_position)
		if labels_drawn >= maximum or focus_distance > label_distance or focus_distance < label_exclusion_radius:
			continue
		_draw_label(canvas, position, String(point.get("title", "")), String(point.get("subtitle", "")), accent)
		labels_drawn += 1


func _draw_marker(canvas: CanvasItem, position: Vector2, radius: float, accent: Color, tick: int, reduced_effects: bool) -> void:
	var pulse := 0.0 if reduced_effects else (sin(float(tick) * 0.055 + position.x * 0.01) + 1.0) * 0.5
	canvas.draw_circle(position + Vector2(3, 6), radius + 3.0, Color(language.ramp_color("worldbone", 0), 0.52))
	canvas.draw_arc(position, radius, 0.0, TAU, 16, Color(language.ramp_color("aged_brass", 3), 0.72), 2.0)
	canvas.draw_circle(position, radius - 6.0, Color(accent, 0.12 + pulse * 0.10))
	canvas.draw_circle(position, 4.0, accent)
	canvas.draw_line(position + Vector2(-radius * 0.42, 0), position + Vector2(radius * 0.42, 0), Color(language.ui_color("text_primary"), 0.55), 1.0)
	canvas.draw_line(position + Vector2(0, -radius * 0.42), position + Vector2(0, radius * 0.42), Color(language.ui_color("text_primary"), 0.55), 1.0)


func _draw_label(canvas: CanvasItem, position: Vector2, title: String, subtitle: String, accent: Color) -> void:
	var width := maxf(132.0, ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22.0)
	var rectangle := Rect2(position.x - width * 0.5, position.y + 27.0, width, 30.0)
	canvas.draw_rect(rectangle, Color(language.ui_color("panel_fill"), 0.82), true)
	canvas.draw_rect(rectangle, Color(accent, 0.72), false, 1.0)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(7, 11), title, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 14.0, 10, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(7, 24), subtitle, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 14.0, 8, language.ui_color("text_secondary"))


func _accent_for_kind(kind: String) -> Color:
	match kind:
		"movement":
			return language.element_color("wind", "bright")
		"rest":
			return language.element_color("light", "bright")
		"archive":
			return language.element_color("time", "bright")
		"spell":
			return language.element_color("spirit", "bright")
		"build":
			return language.ramp_color("aged_brass", 4)
		"farflow":
			return language.element_color("water", "bright")
		"duel":
			return language.element_color("fire", "bright")
		_:
			return language.element_color("chaos", "bright")


static func _position(point: Dictionary) -> Vector2:
	var values: Array = point.get("position", [])
	return Vector2(float(values[0]), float(values[1]))


func _fail(message: String) -> bool:
	last_error = message
	return false
