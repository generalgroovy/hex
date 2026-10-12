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
const EnvironmentDetails = preload("res://src/presentation/wellspring_environment_details.gd")
var environment_details := EnvironmentDetails.new()
var last_error: String = ""
const FLOOR_GUIDE_PATH := "res://content/presentation/wellspring_floor_guides_v1.json"
const FLOOR_STAGE_ORDER := ["source-court", "movement-garden", "crucible", "duel-court"]
const FLOOR_LINE_VERTEX_LIMIT := 768
const DistrictStyle = preload("res://src/presentation/wellspring_district_style.gd")
const PRACTICE_TEXT_NEAR := 220.0
const PRACTICE_TEXT_FAR := 360.0
const SOLO_DUEL_CONTEXT := "solo_duel_trial"
const SIGNATURE_CHALLENGE_CONTEXT := "signature_challenge"
const PRACTICE_TITLES := {
	"pattern-range": "TARGET PRACTICE",
	"chain-courtyard": "MOVEMENT CHAIN COURT",
	"cover-garden": "COVER PRACTICE",
	"open-laboratory": "FREE EXPERIMENT COURT",
}
const OPEN_LAB_LINK := [Vector2(1568, 1440), Vector2(1568, 1664), Vector2(1728, 1664), Vector2(1728, 1728)]
var floor_guide_data: Dictionary = {}
var floor_ink := PackedVector2Array()
var floor_trim := PackedVector2Array()
var floor_labels: Array[Dictionary] = []
var floor_mark_count := 0
var floor_guide_builds := 0
var floor_guide_hash := ""
var retained_generation := 0
const RETAINED_LAYER_COUNT := 6


func configure(visual_language: VisualLanguage) -> bool:
	if illustrated_kit != null and illustrated_kit.terrain_stream != null and not illustrated_kit.terrain_stream.pending.is_empty():
		last_error = "Drain or finish the current terrain stream before reconfiguration"
		return false
	language = null
	natural_kit = null
	illustrated_kit = null
	last_error = ""
	_clear_floor_guides()
	environment_details.clear()
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
	if illustrated_kit != null and illustrated_kit.terrain_stream != null and not illustrated_kit.terrain_stream.pending.is_empty():
		last_error = "Drain or finish the current terrain stream before rebinding its map"
		return false
	last_error = ""
	_clear_floor_guides()
	if illustrated_kit == null:
		return _fail("Configure the campus visual language before binding its map")
	if not illustrated_kit.configure(layout):
		return _fail(illustrated_kit.last_error)
	if not illustrated_kit.ground_ready() or illustrated_kit.content_hash.is_empty():
		return _fail("Illustrated campus must supply validated ground before drawing")
	if not environment_details.configure(layout):
		return _fail(environment_details.last_error)
	var descriptor: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLOOR_GUIDE_PATH))
	if not descriptor is Dictionary or not prepare_floor_guides(layout, descriptor):
		return _fail(last_error if not last_error.is_empty() else "Campus floor guides require their presentation-only descriptor")
	return true


func prepare_terrain_view(visible: Rect2, upload_budget: int = 2) -> bool:
	# The 160px envelope includes the POV's96px margin and64px alignment.
	# Stream adds one native tile of prefetch beyond this; no authority changes.
	if illustrated_kit == null or not visible.has_area() or not visible.position.is_finite() or not visible.end.is_finite(): return false
	return illustrated_kit.request_ground_view(terrain_preparation_rect(visible), upload_budget)


static func terrain_preparation_rect(visible: Rect2) -> Rect2:
	return visible.grow(160.0)


func prefetch_terrain_view(visible: Rect2) -> void:
	if illustrated_kit == null: return
	if not visible.has_area() or not visible.position.is_finite() or not visible.end.is_finite():
		clear_terrain_prefetch()
		return
	illustrated_kit.prefetch_ground_view(terrain_preparation_rect(visible))


func clear_terrain_prefetch() -> void:
	if illustrated_kit != null: illustrated_kit.clear_ground_prefetch()


func suspend_terrain() -> bool:
	return illustrated_kit == null or illustrated_kit.suspend_ground()


func finish_terrain_shutdown() -> void:
	# Final owner teardown only: may wait for at most two outstanding decodes.
	if illustrated_kit != null: illustrated_kit.finish_ground_shutdown()


func terrain_ready_for(visible: Rect2) -> bool:
	return illustrated_kit != null and illustrated_kit.ground_ready_for(visible)


func terrain_status() -> Dictionary:
	return illustrated_kit.ground_status() if illustrated_kit != null else {"ready": 0, "required": 0, "error": last_error}


func prepare_overview() -> bool:
	return illustrated_kit != null and illustrated_kit._prepare_ground_overview()


func draw(
	canvas: CanvasItem,
	layout: SanctumCampusLayout,
	presentation_tick: int,
	focus_world_position: Vector2 = Vector2(-1000000.0, -1000000.0),
	reduced_effects: bool = false,
	station_titles: bool = true,
	visible_world_rect: Rect2 = Rect2(),
	practice_details: bool = true,
	court_context: String = "",
) -> void:
	for layer: int in RETAINED_LAYER_COUNT:
		draw_retained_layer(canvas, layout, layer, presentation_tick, focus_world_position, reduced_effects, station_titles, visible_world_rect, practice_details, court_context)


func retained_source() -> SanctumCampusRenderer:
	return self


func can_draw_campus(layout: SanctumCampusLayout) -> bool:
	return illustrated_kit != null and illustrated_kit.ground_ready() and layout != null and illustrated_kit.campus == layout


func draw_retained_layer(canvas: CanvasItem, layout: SanctumCampusLayout, layer: int, presentation_tick: int, focus_world_position: Vector2, reduced_effects: bool, station_titles: bool, visible_world_rect: Rect2, practice_details: bool, court_context: String) -> void:
	# Exact original painter order, shared by the immediate reference path and
	# independently retained CanvasItems. No simulation or visibility admission.
	if illustrated_kit == null or not illustrated_kit.ground_ready() or layout == null or illustrated_kit.campus != layout:
		return
	match layer:
		0:
			illustrated_kit.draw_ground(canvas, visible_world_rect)
			environment_details.draw(canvas, visible_world_rect)
		1:
			_draw_activity_areas(canvas, layout, focus_world_position, visible_world_rect, practice_details)
			if visible_in_world_rect(Rect2(SanctumCampusLayout._parse_bounds(layout.arena_definition.get("bounds", []))).grow(8), visible_world_rect):
				_draw_arena(canvas, layout.arena_definition, court_context)
		2:
			for building_value: Variant in layout.data.get("buildings", []):
				var building: Dictionary = building_value
				if visible_in_world_rect(building_visual_bounds(building), visible_world_rect):
					illustrated_kit.draw_building(canvas, building, focus_world_position)
		3:
			for landmark_value: Variant in layout.data.get("landmarks", []):
				var landmark: Dictionary = landmark_value
				if not visible_in_world_rect(landmark_visual_bounds(landmark), visible_world_rect): continue
				if bool(landmark.get("worldbone", false)):
					illustrated_kit.draw_landmark(canvas, landmark, focus_world_position, presentation_tick, reduced_effects)
				elif bool(landmark.get("fast_travel", false)):
					_draw_waypoint_inlay(canvas, layout, landmark)
		4:
			var drawn_groups := {}
			for station_value: Variant in layout.data.get("stations", []):
				var station: Dictionary = station_value
				var group := String(station.get("service_group", station["id"]))
				if drawn_groups.has(group): continue
				drawn_groups[group] = true
				if visible_in_world_rect(station_visual_bounds(station), visible_world_rect):
					illustrated_kit.draw_station(canvas, station, presentation_tick, reduced_effects, focus_world_position, station_titles)
		5:
			for district_value: Variant in layout.data.get("districts", []):
				var district: Dictionary = district_value
				if visible_in_world_rect(district_label_bounds(district), visible_world_rect):
					_draw_district_label(canvas, district)


static func visible_in_world_rect(visual_bounds: Rect2, visible_world_rect: Rect2) -> bool:
	# Empty means uncropped capture/backdrop, not an invisible map. This is only
	# conservative render rejection; it never reads or changes sight/interaction.
	if not visible_world_rect.has_area() or not visible_world_rect.position.is_finite() or not visible_world_rect.size.is_finite():
		return true
	return visual_bounds.intersects(visible_world_rect, true)


static func building_visual_bounds(building: Dictionary) -> Rect2:
	# Includes roof outline, the southeast receiving shadow, doorway and side
	# planters on the narrowest existing structure. Never cull to collision alone.
	return Rect2(SanctumCampusLayout._parse_bounds(building["bounds"])).grow(48.0)


static func station_visual_bounds(station: Dictionary) -> Rect2:
	var values: Array = station["position"]
	var point := Vector2(float(values[0]), float(values[1]))
	# Flat door approach, its 1px outline and label only; roofs are separate.
	return Rect2(point + Vector2(-136, -21), Vector2(272, 70))


static func landmark_visual_bounds(landmark: Dictionary) -> Rect2:
	var point := Vector2(SanctumCampusLayout._parse_point(landmark.get("position", [])))
	return Rect2(point - Vector2(112, 128), Vector2(224, 256))


static func district_label_bounds(district: Dictionary) -> Rect2:
	var point := Vector2(SanctumCampusLayout._parse_point(district.get("label_anchor", [])))
	return Rect2(point - Vector2(4, 16), Vector2(272, 24))


static func visible_floor_segments(points: PackedVector2Array, visible: Rect2) -> PackedVector2Array:
	if not visible.has_area() or not visible.position.is_finite() or not visible.end.is_finite(): return points
	var selected := PackedVector2Array()
	for index: int in range(0, points.size() - 1, 2):
		var bounds := Rect2(points[index], Vector2.ZERO).expand(points[index + 1]).grow(2.0)
		if bounds.intersects(visible, true): selected.append_array(PackedVector2Array([points[index], points[index + 1]]))
	return selected


func _draw_waypoint_inlay(canvas: CanvasItem, layout: SanctumCampusLayout, landmark: Dictionary) -> void:
	# Navigation marks are flat engraved floor, never fictional solid props or
	# a spell tell. Destination authority and travel admission live elsewhere.
	var point := Vector2(SanctumCampusLayout._parse_point(landmark.position))
	var district: Dictionary = layout.districts_by_id.get(String(landmark.get("district", "")), {})
	var environment := DistrictStyle.environment_for(district)
	var style := DistrictStyle.style_for(environment)
	canvas.draw_multiline(DistrictStyle.emblem(point, environment), Color(style.accent, 0.28), 2.0)


static func arena_label(definition: Dictionary, court_context: String = "") -> String:
	# Context changes copy only: the ordinary court keeps its authored score rule.
	if court_context == SOLO_DUEL_CONTEXT:
		return "DUEL TRIAL · DEFEAT OH TIPI"
	if court_context == SIGNATURE_CHALLENGE_CONTEXT:
		return "SIGNATURE CHALLENGE"
	return "PROVING COURT · FIRST %d" % int(definition.get("score_limit", 0))


func _draw_arena(canvas: CanvasItem, definition: Dictionary, court_context: String = "") -> void:
	if definition.is_empty():
		return
	var bounds := SanctumCampusLayout._parse_bounds(definition.get("bounds", []))
	canvas.draw_rect(Rect2(bounds), Color(BRASS, 0.22), false, 4.0)
	canvas.draw_rect(Rect2(bounds.grow(-8)), Color(PARCHMENT, 0.16), false, 2.0)
	var court_label := arena_label(definition, court_context)
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
	var width: float = minf(264.0, 18.0 + ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	canvas.draw_rect(Rect2(anchor.x - 4, anchor.y - 14, width, 20), PANEL, true)
	var style := DistrictStyle.style_for(DistrictStyle.environment_for(district))
	canvas.draw_rect(Rect2(anchor.x - 4, anchor.y - 14, width, 20), Color(style.edge, 0.65), false, 1.0)
	canvas.draw_string(ThemeDB.fallback_font, anchor, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, PARCHMENT)


# Geometry and collision stay in the layout; these quiet floor cues only teach purpose.
func _draw_activity_areas(canvas: CanvasItem, layout: SanctumCampusLayout, focus: Vector2 = Vector2(-1000000.0, -1000000.0), visible_world_rect: Rect2 = Rect2(), practice_details: bool = true) -> void:
	# Two setup-cached batches replace seven full rectangular borders and the
	# old radial movement target. These are neutral stone inlays, not geometry.
	var visible_trim := visible_floor_segments(floor_trim, visible_world_rect)
	var visible_ink := visible_floor_segments(floor_ink, visible_world_rect)
	if not visible_trim.is_empty():
		canvas.draw_multiline(visible_trim, Color(BRASS, 0.22), 2.0)
	if not visible_ink.is_empty():
		canvas.draw_multiline(visible_ink, Color(PARCHMENT, 0.38), 2.0)
	for label: Dictionary in floor_labels:
		if not visible_in_world_rect(Rect2(label["anchor"] - Vector2(1, int(label["size"])), Vector2(float(label["width"]) + 2, int(label["size"]) + 4)), visible_world_rect): continue
		canvas.draw_string(ThemeDB.fallback_font, label["anchor"] + Vector2(1, 1), label["text"],
			HORIZONTAL_ALIGNMENT_LEFT, label["width"], label["size"], Color(PANEL, 0.88))
		canvas.draw_string(ThemeDB.fallback_font, label["anchor"], label["text"],
			HORIZONTAL_ALIGNMENT_LEFT, label["width"], label["size"], Color(PARCHMENT, label["opacity"]))
	# Authored references compile these endpoints once; no target-position copies.
	for lane: Dictionary in layout.practice_lanes:
		var start := Vector2(lane["start"])
		var end := Vector2(lane["end"])
		var direction := (end - start).normalized()
		if not visible_in_world_rect(Rect2(start, Vector2.ZERO).expand(end).grow(float(lane["width"]) * 0.5 + 14.0), visible_world_rect): continue
		canvas.draw_dashed_line(start + direction * 14.0, end - direction * 34.0, Color(PARCHMENT, 0.24), 1.0, 10.0)
		canvas.draw_arc(start, 12.0, 0, TAU, 12, Color(BRASS, 0.42), 1.0)
		var side := Vector2(-direction.y, direction.x) * float(lane["width"]) * 0.5
		canvas.draw_line(start - side, start + side, Color(BRASS, 0.32), 1.0)
	for group: Dictionary in layout.practice_groups_by_id.values():
		var anchor := Vector2(SanctumCampusLayout._parse_point(group["label_anchor"]))
		if not visible_in_world_rect(Rect2(anchor + Vector2(0, -4), Vector2(228, 36)), visible_world_rect):
			continue
		canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(1, 12), String(group["label"]), HORIZONTAL_ALIGNMENT_LEFT, 224, 12, PANEL)
		canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(0, 11), String(group["label"]), HORIZONTAL_ALIGNMENT_LEFT, 224, 12, Color(PARCHMENT, 0.90))
		var detail_opacity := practice_instruction_opacity(anchor, focus, Rect2(SanctumCampusLayout._parse_bounds(group["bounds"])), practice_details)
		if detail_opacity > 0.0:
			canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(1, 27), String(group["purpose"]), HORIZONTAL_ALIGNMENT_LEFT, 224, 11, Color(PANEL, PANEL.a * detail_opacity))
			canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(0, 26), String(group["purpose"]), HORIZONTAL_ALIGNMENT_LEFT, 224, 11, Color(PARCHMENT, 0.85 * detail_opacity))


static func practice_instruction_opacity(anchor: Vector2, focus: Vector2, practice_bounds: Rect2 = Rect2(), details_enabled: bool = true) -> float:
	# Static unseen-world backdrops must not bake contextual instructions into
	# fog; otherwise they reappear after the live world correctly hides them.
	if not details_enabled:
		return 0.0
	# Names and floor routes remain available at a distance; the instructional
	# second line matters only near its station. No timer, authority or allocation.
	# Unfocused overview captures retain all copy instead of inventing a player.
	if focus == Vector2(-1000000.0, -1000000.0) or not focus.is_finite() or not anchor.is_finite():
		return 1.0
	var distance_squared := anchor.distance_squared_to(focus)
	# The copy stays fully available throughout the practice area, even when
	# a wide target lane places its firing position far from the text anchor.
	if practice_bounds.has_area() and practice_bounds.position.is_finite() and practice_bounds.end.is_finite():
		var nearest := focus.clamp(practice_bounds.position, practice_bounds.end)
		distance_squared = minf(distance_squared, nearest.distance_squared_to(focus))
	var near_squared := PRACTICE_TEXT_NEAR * PRACTICE_TEXT_NEAR
	var far_squared := PRACTICE_TEXT_FAR * PRACTICE_TEXT_FAR
	var blend := clampf((distance_squared - near_squared) / (far_squared - near_squared), 0.0, 1.0)
	return 1.0 - blend * blend * (3.0 - 2.0 * blend)


func _fail(message: String) -> bool:
	last_error = message
	_clear_floor_guides()
	if illustrated_kit != null:
		illustrated_kit.ground = null
		illustrated_kit.content_hash = ""
	return false


func _clear_floor_guides() -> void:
	retained_generation += 1
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
		floor_labels.append({"anchor": stage_label_anchors.get(String(area.id), bounds.position + Vector2(0, 12)), "text": String(PRACTICE_TITLES.get(String(area.id), stage_labels.get(String(area.id), area.label))), "width": bounds.size.x, "size": 16, "opacity": 0.68})
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
	if not _append_open_lab_link(layout, collision):
		return _fail("Experiment shortcut must connect its real firing position to clear open laboratory ground")
	if floor_ink.size() + floor_trim.size() > FLOOR_LINE_VERTEX_LIMIT:
		return _fail("Floor guide vertex budget exceeded")
	floor_guide_data = descriptor.duplicate(true)
	floor_guide_hash = CanonicalContent.sha256(descriptor)
	floor_guide_builds += 1
	last_error = ""
	return true


func _append_open_lab_link(layout: SanctumCampusLayout, collision: CollisionWorld) -> bool:
	# Compile two neutral arrows once for the real newly opened passage. The
	# actor-size-plus-margin check refuses a visual shortcut through any wall.
	if not layout.practice_groups_by_id.has("crucible-experiment"):
		return false
	var firing := Vector2(SanctumCampusLayout._parse_point(layout.practice_groups_by_id["crucible-experiment"]["firing_anchors"][0]))
	if firing != OPEN_LAB_LINK[0]:
		return false
	var reaches_laboratory := false
	for area: Dictionary in layout.data["activity_areas"]:
		if String(area.id) == "open-laboratory":
			reaches_laboratory = Rect2(SanctumCampusLayout._parse_bounds(area.bounds)).grow(-32).has_point(OPEN_LAB_LINK.back())
	if not reaches_laboratory:
		return false
	for index: int in range(OPEN_LAB_LINK.size() - 1):
		var start: Vector2 = OPEN_LAB_LINK[index]
		var end: Vector2 = OPEN_LAB_LINK[index + 1]
		var steps := ceili(start.distance_to(end) / 4.0)
		for step_index: int in range(steps + 1):
			if not collision.can_occupy(Vector2i(start.lerp(end, float(step_index) / steps) * SimConfig.FIXED_SCALE), 32_000):
				return false
	_append_floor_chevrons(Vector2(1568, 1552), Vector2.DOWN)
	_append_floor_chevrons(Vector2(1632, 1664), Vector2.RIGHT)
	floor_mark_count += 2
	floor_labels.append({"anchor": Vector2(1592, 1632), "text": "OPEN PRACTICE", "width": 160.0, "size": 11, "opacity": 0.52})
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
