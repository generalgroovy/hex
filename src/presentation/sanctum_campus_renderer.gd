class_name SanctumCampusRenderer
extends RefCounted


# Current campus drawing has one validated illustrated path. NaturalMapKit
# remains available to bootstrap for actor contacts and receiving shadows.
var BRASS := Color("b98336")
var PARCHMENT := Color("e4d8ae")
var CYAN := Color("51d5dc")
var PANEL := Color("11140ee8")
var language: VisualLanguage
var natural_kit: NaturalMapKit
var illustrated_kit: WellspringIllustratedKit
var last_error: String = ""
const FLOOR_GUIDE_PATH := "res://content/presentation/wellspring_floor_guides_v1.json"
const FLOOR_STAGE_ORDER := ["source-court", "movement-garden", "crucible", "duel-court"]
const FLOOR_LINE_VERTEX_LIMIT := 384
var floor_guide_data: Dictionary = {}
var floor_ink := PackedVector2Array()
var floor_trim := PackedVector2Array()
var floor_labels: Array[Dictionary] = []
var floor_mark_count := 0
var floor_guide_builds := 0
var floor_guide_hash := ""


func configure(visual_language: VisualLanguage) -> bool:
	language = null
	natural_kit = null
	illustrated_kit = null
	last_error = ""
	_clear_floor_guides()
	if visual_language == null or visual_language.ramps.is_empty():
		return _fail("Campus renderer requires a validated visual language")
	language = visual_language
	BRASS = language.ramp_color("aged_brass", 2)
	PARCHMENT = language.ui_color("text_primary")
	CYAN = language.ui_color("focus")
	PANEL = language.ui_color("panel_fill")
	natural_kit = NaturalMapKit.new()
	if not natural_kit.configure(language):
		return _fail(natural_kit.last_error)
	illustrated_kit = WellspringIllustratedKit.new()
	return true


func configure_campus(layout: SanctumCampusLayout) -> bool:
	last_error = ""
	_clear_floor_guides()
	if illustrated_kit == null:
		return _fail("Configure the campus visual language before binding its map")
	if not illustrated_kit.configure(layout):
		return _fail(illustrated_kit.last_error)
	if illustrated_kit.ground == null or illustrated_kit.content_hash.is_empty():
		return _fail("Illustrated campus must supply validated ground before drawing")
	var descriptor: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLOOR_GUIDE_PATH))
	if not descriptor is Dictionary or not prepare_floor_guides(layout, descriptor):
		return _fail(last_error if not last_error.is_empty() else "Campus floor guides require their presentation-only descriptor")
	return true


func draw(
	canvas: CanvasItem,
	layout: SanctumCampusLayout,
	presentation_tick: int,
	focus_world_position: Vector2 = Vector2(-1000000.0, -1000000.0),
	reduced_effects: bool = false,
) -> void:
	if illustrated_kit == null or illustrated_kit.ground == null or layout == null or illustrated_kit.campus != layout:
		return
	illustrated_kit.draw_ground(canvas)
	_draw_activity_areas(canvas, layout)
	_draw_arena(canvas, layout.arena_definition)
	for building_value: Variant in layout.data.get("buildings", []):
		illustrated_kit.draw_building(canvas, building_value as Dictionary, focus_world_position)
	for landmark_value: Variant in layout.data.get("landmarks", []):
		var landmark: Dictionary = landmark_value
		if bool(landmark.get("worldbone", false)):
			illustrated_kit.draw_landmark(canvas, landmark, focus_world_position, presentation_tick, reduced_effects)
	for station_value: Variant in layout.data.get("stations", []):
		illustrated_kit.draw_station(canvas, station_value as Dictionary, presentation_tick, reduced_effects, focus_world_position)
	for district_value: Variant in layout.data.get("districts", []):
		_draw_district_label(canvas, district_value as Dictionary)


func _draw_arena(canvas: CanvasItem, definition: Dictionary) -> void:
	if definition.is_empty():
		return
	var bounds := SanctumCampusLayout._parse_bounds(definition.get("bounds", []))
	canvas.draw_rect(Rect2(bounds), Color(BRASS, 0.22), false, 4.0)
	canvas.draw_rect(Rect2(bounds.grow(-8)), Color(PARCHMENT, 0.16), false, 2.0)
	var court_label := "PROVING COURT · FIRST %d" % int(definition.get("score_limit", 0))
	var label_rect := Rect2(
		Vector2(bounds.position.x + (bounds.size.x - 218) / 2, bounds.position.y + 24),
		Vector2(218, 25),
	)
	canvas.draw_rect(label_rect, Color(PANEL, 0.76), true)
	canvas.draw_rect(label_rect, Color(BRASS, 0.5), false, 1.0)
	canvas.draw_string(ThemeDB.fallback_font, label_rect.position + Vector2(10, 17), court_label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - 20.0, 12, PARCHMENT)
	for spawn_value: Variant in definition.get("spawns", []):
		var point_values: Array = spawn_value
		var point := Vector2(float(point_values[0]), float(point_values[1]))
		canvas.draw_circle(point, 14.0, Color(PANEL, 0.68))
		canvas.draw_arc(point, 14.0, 0.0, TAU, 16, Color(CYAN, 0.56), 2.0)
		canvas.draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), Color(PARCHMENT, 0.48), 1.0)
		canvas.draw_line(point + Vector2(0, -5), point + Vector2(0, 5), Color(PARCHMENT, 0.48), 1.0)


func _draw_district_label(canvas: CanvasItem, district: Dictionary) -> void:
	var values: Array = district.get("label_anchor", [])
	var anchor := Vector2(float(values[0]), float(values[1]))
	var label := String(district.get("label", ""))
	var width: float = minf(250.0, 18.0 + ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	canvas.draw_rect(Rect2(anchor.x - 4, anchor.y - 14, width, 20), PANEL, true)
	canvas.draw_rect(Rect2(anchor.x - 4, anchor.y - 14, width, 20), Color(BRASS, 0.65), false, 1.0)
	canvas.draw_string(ThemeDB.fallback_font, anchor, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, PARCHMENT)


# Geometry and collision stay in the layout; these quiet floor cues only teach purpose.
func _draw_activity_areas(canvas: CanvasItem, layout: SanctumCampusLayout) -> void:
	# Two setup-cached batches replace seven full rectangular borders and the
	# old radial movement target. These are neutral stone inlays, not geometry.
	if not floor_trim.is_empty():
		canvas.draw_multiline(floor_trim, Color(BRASS, 0.22), 2.0)
	if not floor_ink.is_empty():
		canvas.draw_multiline(floor_ink, Color(PARCHMENT, 0.38), 2.0)
	for label: Dictionary in floor_labels:
		canvas.draw_string(ThemeDB.fallback_font, label["anchor"], label["text"],
			HORIZONTAL_ALIGNMENT_LEFT, label["width"], label["size"], Color(PARCHMENT, label["opacity"]))
	# Authored references compile these endpoints once; no target-position copies.
	for lane: Dictionary in layout.practice_lanes:
		var start := Vector2(lane["start"])
		var end := Vector2(lane["end"])
		var direction := (end - start).normalized()
		canvas.draw_dashed_line(start + direction * 14.0, end - direction * 34.0, Color(PARCHMENT, 0.24), 1.0, 10.0)
		canvas.draw_arc(start, 12.0, 0, TAU, 12, Color(BRASS, 0.42), 1.0)
		var side := Vector2(-direction.y, direction.x) * float(lane["width"]) * 0.5
		canvas.draw_line(start - side, start + side, Color(BRASS, 0.32), 1.0)
	for group: Dictionary in layout.practice_groups_by_id.values():
		var anchor := Vector2(SanctumCampusLayout._parse_point(group["label_anchor"]))
		canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(0, 11), String(group["label"]), HORIZONTAL_ALIGNMENT_LEFT, 224, 11, Color(PARCHMENT, 0.78))
		canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(0, 26), String(group["purpose"]), HORIZONTAL_ALIGNMENT_LEFT, 224, 10, Color(PARCHMENT, 0.62))


func _fail(message: String) -> bool:
	last_error = message
	_clear_floor_guides()
	if illustrated_kit != null:
		illustrated_kit.ground = null
		illustrated_kit.content_hash = ""
	return false


func _clear_floor_guides() -> void:
	floor_guide_data.clear()
	floor_ink.clear()
	floor_trim.clear()
	floor_labels.clear()
	floor_mark_count = 0
	floor_guide_hash = ""


func prepare_floor_guides(layout: SanctumCampusLayout, descriptor: Dictionary) -> bool:
	_clear_floor_guides()
	if layout == null or int(descriptor.get("schema_version", 0)) != 1 or String(descriptor.get("authority", "")) != "presentation_only" or String(descriptor.get("map_id", "")) != String(layout.data.get("id", "")):
		return _fail("Floor guides cannot own or replace the campus map")
	if descriptor.get("stage_order", []) != FLOOR_STAGE_ORDER or not descriptor.get("stages") is Array or not descriptor.get("markers") is Array or descriptor.stages.size() != 4 or descriptor.markers.size() > 12:
		return _fail("Floor guides require four ordered stages and at most twelve sparse markers")
	var areas: Dictionary = {}
	for area: Dictionary in layout.data["activity_areas"]:
		areas[String(area.id)] = area
	var routes: Dictionary = {}
	for route: Dictionary in layout.data["routes"] + layout.data["connections"]:
		routes[String(route.id)] = route
	var collision := layout.build_collision_world()
	var stage_labels: Dictionary = {}
	var stage_label_anchors: Dictionary = {}
	for index: int in range(descriptor.stages.size()):
		if not descriptor.stages[index] is Dictionary:
			return _fail("Floor stage must be an object")
		var stage: Dictionary = descriptor.stages[index]
		var id := String(stage.get("activity", ""))
		var anchor := _floor_point(stage.get("anchor", []))
		var emblem := String(stage.get("emblem", ""))
		var label := String(stage.get("label", ""))
		if id != FLOOR_STAGE_ORDER[index] or not areas.has(id) or not anchor.is_finite() or not Rect2(SanctumCampusLayout._parse_bounds(areas[id].bounds)).grow(-40).has_point(anchor) or not collision.can_occupy(Vector2i(anchor * 1000), 40000):
			return _fail("Floor stage must remain inside its real activity and outside worldbone")
		if emblem != ["gather", "stride", "pair", "cross"][index] or label.is_empty() or label.length() > 28:
			return _fail("Floor stages require bounded, distinct neutral emblems and short labels")
		stage_labels[id] = label
		if stage.has("label_anchor"):
			var label_anchor := _floor_point(stage["label_anchor"])
			if not label_anchor.is_finite() or not Rect2(SanctumCampusLayout._parse_bounds(areas[id].bounds)).grow(-24).has_point(label_anchor) or not collision.can_occupy(Vector2i(label_anchor * 1000), 24000):
				return _fail("Floor title override must occupy clear ground inside its activity")
			stage_label_anchors[id] = label_anchor
		_append_floor_emblem(anchor, emblem)
		floor_mark_count += 1
	var south_label := String(descriptor.get("south_label", ""))
	if south_label.is_empty() or south_label.length() > 28:
		return _fail("Southern loop label must be brief")
	stage_labels["south-movement-loop"] = south_label
	for area: Dictionary in layout.data["activity_areas"]:
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(area.bounds)).grow(-16)
		for corner: Vector2 in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
			var toward := (bounds.get_center() - corner).sign()
			floor_trim.append_array(PackedVector2Array([corner + Vector2(40 * toward.x, 0), corner, corner, corner + Vector2(0, 40 * toward.y)]))
		floor_labels.append({"anchor": stage_label_anchors.get(String(area.id), bounds.position + Vector2(0, 12)), "text": String(stage_labels.get(String(area.id), area.label)), "width": bounds.size.x, "size": 16, "opacity": 0.68})
	var seen: Dictionary = {}
	for value: Variant in descriptor.markers:
		if not value is Dictionary:
			return _fail("Floor marker must be an object")
		var marker: Dictionary = value
		var id := String(marker.get("id", ""))
		var route_id := String(marker.get("route", ""))
		var anchor := _floor_point(marker.get("anchor", []))
		var direction := _floor_point(marker.get("direction", []))
		var hint := String(marker.get("hint", ""))
		if id.is_empty() or seen.has(id) or not routes.has(route_id) or not anchor.is_finite() or direction not in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN] or hint.length() > 16:
			return _fail("Floor markers require unique IDs, real routes and cardinal arrows")
		seen[id] = true
		var route: Dictionary = routes[route_id]
		var nearest := INF
		var alignment := 0.0
		for index: int in range(route.points.size() - 1):
			var a := _floor_point(route.points[index])
			var b := _floor_point(route.points[index + 1])
			var distance := anchor.distance_to(Geometry2D.get_closest_point_to_segment(anchor, a, b))
			var segment_alignment := absf(direction.dot((b - a).normalized()))
			if distance < nearest - 0.001:
				nearest = distance
				alignment = segment_alignment
			elif is_equal_approx(distance, nearest):
				alignment = maxf(alignment, segment_alignment)
		if nearest > float(route.width) * 0.5 - 24 or alignment < 0.85 or not collision.can_occupy(Vector2i(anchor * 1000), 24000):
			return _fail("Floor arrows must fit existing traversable routes, never promise a new shortcut")
		_append_floor_chevrons(anchor, direction)
		floor_mark_count += 1
		if not hint.is_empty():
			floor_labels.append({"anchor": anchor + Vector2(-48, 34), "text": hint, "width": 108.0, "size": 11, "opacity": 0.52})
	if floor_ink.size() + floor_trim.size() > FLOOR_LINE_VERTEX_LIMIT:
		return _fail("Floor guide vertex budget exceeded")
	floor_guide_data = descriptor.duplicate(true)
	floor_guide_hash = CanonicalContent.sha256(descriptor)
	floor_guide_builds += 1
	last_error = ""
	return true


static func _floor_point(value: Variant) -> Vector2:
	if not value is Array or value.size() != 2 or (not value[0] is int and not value[0] is float) or (not value[1] is int and not value[1] is float):
		return Vector2(INF, INF)
	return Vector2(float(value[0]), float(value[1]))


func _append_floor_chevrons(anchor: Vector2, direction: Vector2) -> void:
	var side := direction.orthogonal() * 10.0
	for offset: float in [-7.0, 7.0]:
		var tip := anchor + direction * (offset + 5.0)
		floor_ink.append_array(PackedVector2Array([tip - direction * 9 + side, tip, tip, tip - direction * 9 - side]))


func _append_floor_emblem(anchor: Vector2, kind: String) -> void:
	# The existing native line/stone grammar supplies four flat inlays. No props,
	# elemental colors, range circles, new textures or per-frame geometry builds.
	if kind == "stride":
		_append_floor_chevrons(anchor - Vector2(0, 6), Vector2.UP)
		floor_trim.append_array(PackedVector2Array([anchor + Vector2(-22, 22), anchor + Vector2(22, 22)]))
	elif kind == "cross":
		floor_ink.append_array(PackedVector2Array([anchor + Vector2(-20, -20), anchor + Vector2(20, 20), anchor + Vector2(-20, 20), anchor + Vector2(20, -20)]))
		for side: float in [-1.0, 1.0]:
			floor_trim.append_array(PackedVector2Array([anchor + Vector2(26 * side, -14), anchor + Vector2(26 * side, 14)]))
	else:
		var centers := [anchor + Vector2(-12, 0), anchor + Vector2(12, 0)] if kind == "pair" else [anchor]
		for center: Vector2 in centers:
			var radius := 15.0 if kind == "pair" else 24.0
			var points := [center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]
			for index: int in 4:
				floor_ink.append_array(PackedVector2Array([points[index], points[(index + 1) % 4]]))
		if kind == "gather":
			floor_trim.append_array(PackedVector2Array([anchor - Vector2(8, 0), anchor + Vector2(8, 0), anchor - Vector2(0, 8), anchor + Vector2(0, 8)]))
