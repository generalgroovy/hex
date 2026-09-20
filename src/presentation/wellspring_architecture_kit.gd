class_name WellspringArchitectureKit
extends RefCounted


const DEFAULT_PATH := "res://content/visual/wellspring_architecture_kit_v1.json"
const EXPECTED_ID := "wellspring-architecture-kit-v1"
const EXPECTED_AUTHORITY := "presentation only; authored campus topology, collision, elevation, station commands and interaction radii remain canonical elsewhere"
const BUILDING_STYLES := ["timber_hall", "garden_gate", "archive_hall", "spire", "service_tower", "portal_rotunda", "foundry_hall"]
const STATION_KINDS := ["guide", "training", "champion", "spell", "farflow", "charter", "hearth", "ledger", "parting", "controls"]
const LANDMARK_KINDS := ["attunement_spire", "grand_fountain", "archive_orrey", "portal_ring", "attunement_crucible"]
const ROOF_SHAPES := ["gable", "hipped", "dome", "spire", "industrial"]
const FACADES := ["timber_frame", "garden_stone", "stone_timber", "foundry_brick"]
const MOTIFS := ["route", "garden", "archive", "attunement", "service", "farflow", "foundry"]
const FURNITURE := ["lectern", "bell", "loom", "gate", "desk", "hearth"]
const LANDMARK_FRAMES := ["spire", "basin", "orrery", "gate", "crucible"]
const COURT_DECORATION_KINDS := ["lantern", "planter", "rune"]

var language: VisualLanguage
var runtime_kit: SanctumRuntimeKit
var environment_kit: WellspringEnvironmentKit
var data: Dictionary = {}
var building_profiles: Dictionary[String, Dictionary] = {}
var station_profiles: Dictionary[String, Dictionary] = {}
var landmark_profiles: Dictionary[String, Dictionary] = {}
var court_decorations: Array[Dictionary] = []
var surface_alignment: Dictionary = {}
var content_hash := ""
var last_error := ""


func configure(visual_language: VisualLanguage, layout: SanctumCampusLayout, path: String = DEFAULT_PATH) -> bool:
	language = visual_language
	data.clear()
	building_profiles.clear()
	station_profiles.clear()
	landmark_profiles.clear()
	court_decorations.clear()
	surface_alignment.clear()
	content_hash = ""
	last_error = ""
	if language == null or layout == null or language.ramps.is_empty() or layout.buildings_by_id.is_empty():
		return _fail("Wellspring architecture requires validated visual language and campus layout")
	runtime_kit = SanctumRuntimeKit.new()
	if not runtime_kit.load_from_file():
		return _fail("Wellspring architecture cannot bind the approved pixel modules: %s" % runtime_kit.last_error)
	environment_kit = WellspringEnvironmentKit.new()
	if not environment_kit.load_from_file():
		return _fail("Wellspring architecture cannot bind the environment modules: %s" % environment_kit.last_error)
	if not FileAccess.file_exists(path):
		return _fail("Wellspring architecture kit does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Wellspring architecture kit cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Wellspring architecture kit root must be an object")
	data = parsed
	if not validate(layout):
		data.clear()
		return false
	content_hash = source.sha256_text()
	return true


func validate(layout: SanctumCampusLayout) -> bool:
	last_error = ""
	building_profiles.clear()
	station_profiles.clear()
	landmark_profiles.clear()
	court_decorations.clear()
	surface_alignment.clear()
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Wellspring architecture identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Wellspring architecture must remain presentation-only")
	var budgets: Dictionary = data.get("budgets", {})
	var maximum_facade_ratio := float(budgets.get("maximum_facade_ratio", 0.0))
	if maximum_facade_ratio < 0.30 or maximum_facade_ratio > 0.85 \
		or int(budgets.get("maximum_roof_overhang", 0)) < 2 or int(budgets.get("maximum_roof_overhang", 0)) > 12 \
		or int(budgets.get("maximum_modules_per_building", 0)) < 8 or int(budgets.get("maximum_modules_per_building", 0)) > 64 \
		or int(budgets.get("station_footprint", 0)) < 36 or int(budgets.get("station_footprint", 0)) > 56 \
		or int(budgets.get("landmark_footprint", 0)) < 72 or int(budgets.get("landmark_footprint", 0)) > 112:
		return _fail("Wellspring architecture budgets are unsafe")
	if not _validate_surface_alignment():
		return false
	var court: Dictionary = data.get("court_profile", {})
	if String(court.get("district_style", "")) != "nexus" \
		or int(court.get("width", 0)) < 480 or int(court.get("width", 0)) > 720 \
		or int(court.get("height", 0)) < 420 or int(court.get("height", 0)) > 620 \
		or absi(int(court.get("center_offset_y", 999))) > 140 \
		or int(court.get("corner_step", 0)) < 16 or int(court.get("corner_step", 0)) > 40 \
		or int(court.get("cell_size", 0)) < 24 or int(court.get("cell_size", 0)) > 40 \
		or not language.elements.has(String(court.get("accent", ""))):
		return _fail("Wellspring source-court profile is invalid")
	if not _index_court_decorations(court):
		return false
	if not _index_buildings(maximum_facade_ratio) or not _index_stations() or not _index_landmarks():
		return false
	for building: Dictionary in layout.buildings_by_id.values():
		var style := String(building.get("style", ""))
		if style != "practice_wall" and not building_profiles.has(style):
			return _fail("Live building style has no architecture profile: %s" % style)
	for station: Dictionary in layout.stations_by_id.values():
		var kind := String(station.get("kind", ""))
		if not station_profiles.has(kind):
			return _fail("Live station kind has no architecture profile: %s" % kind)
	for landmark: Dictionary in layout.landmarks_by_id.values():
		var kind := String(landmark.get("kind", ""))
		if not landmark_profiles.has(kind):
			return _fail("Live landmark kind has no architecture profile: %s" % kind)
	return true


func draw_district_court(canvas: CanvasItem, district: Dictionary, reduced_effects: bool) -> bool:
	if canvas == null:
		return false
	var profile: Dictionary = data.get("court_profile", {})
	if String(district.get("style", "")) != String(profile.get("district_style", "")):
		return false
	var district_bounds := SanctumCampusLayout._parse_bounds(district.get("bounds", []))
	var size := Vector2(int(profile.get("width", 640)), int(profile.get("height", 540)))
	var center := Vector2(district_bounds.get_center()) + Vector2(0, int(profile.get("center_offset_y", 92)))
	var court := Rect2(center - size * 0.5, size)
	var step := float(profile.get("corner_step", 28))
	var accent := language.element_color(String(profile.get("accent", "water")), "bright")
	var outer := _stepped_rect(court, step)
	var rim := _stepped_rect(court.grow(-9), step - 4.0)
	var floor := _stepped_rect(court.grow(-18), step - 8.0)
	canvas.draw_colored_polygon(_offset(outer, Vector2(6, 10)), Color(language.ramp_color("worldbone", 0), 0.70))
	canvas.draw_colored_polygon(outer, language.ramp_color("worldbone", 2))
	canvas.draw_polyline(_closed(outer), language.ramp_color("aged_brass", 1), 3.0, false)
	canvas.draw_colored_polygon(rim, language.ramp_color("warm_stone", 3))
	canvas.draw_colored_polygon(floor, language.ramp_color("warm_stone", 2))
	_draw_court_pavers(canvas, court.grow(-20), int(profile.get("cell_size", 32)))
	for corner: Vector2 in [
		court.position + Vector2(42, 42),
		Vector2(court.end.x - 42, court.position.y + 42),
		Vector2(court.position.x + 42, court.end.y - 42),
		court.end - Vector2(42, 42),
	]:
		canvas.draw_rect(Rect2(corner - Vector2(24, 13), Vector2(48, 26)), language.ramp_color("worldbone", 1), true)
		canvas.draw_rect(Rect2(corner - Vector2(21, 10), Vector2(42, 20)), language.ramp_color("garden", 2), true)
		for side: float in [-1.0, 0.0, 1.0]:
			canvas.draw_circle(corner + Vector2(side * 11.0, -4), 6.0, language.ramp_color("garden", 3 if side != 0.0 else 4))
	var channel_alpha := 0.30 if reduced_effects else 0.42
	for side: float in [-1.0, 1.0]:
		var channel := Rect2(center.x + side * (court.size.x * 0.5 - 32) - 6, center.y - 90, 12, 180)
		canvas.draw_rect(channel, language.ramp_color("deep_water", 1), true)
		canvas.draw_line(channel.position + Vector2(6, 4), channel.position + Vector2(6, channel.size.y - 4), Color(accent, channel_alpha), 2.0)
	for radius: float in [80.0, 52.0, 24.0]:
		canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(language.ramp_color("aged_brass", 3), 0.30), 2.0)
	for index: int in range(8):
		var direction := Vector2.from_angle(TAU * float(index) / 8.0)
		canvas.draw_line(center + direction * 28.0, center + direction * 76.0, Color(language.ramp_color("aged_brass", 2), 0.28), 2.0)
	if environment_kit != null:
		environment_kit.draw_anchored(canvas, "brass-inlay", center + Vector2(0, 22), Color(1.0, 1.0, 1.0, 0.70), 1.18)
	_draw_court_decorations(canvas, center, reduced_effects)
	return true


func _index_court_decorations(court: Dictionary) -> bool:
	var values: Variant = court.get("decorations", [])
	if not values is Array or (values as Array).size() < 4 or (values as Array).size() > 12:
		return _fail("Wellspring source-court decorations must stay within the small authored budget")
	var half_width := float(court.get("width", 0)) * 0.5 - 48.0
	var half_height := float(court.get("height", 0)) * 0.5 - 48.0
	for value: Variant in values:
		if not value is Dictionary:
			return _fail("Wellspring source-court decoration must be an object")
		var decoration: Dictionary = value
		var offset_value: Variant = decoration.get("offset", [])
		if String(decoration.get("kind", "")) not in COURT_DECORATION_KINDS \
			or not language.elements.has(String(decoration.get("accent", ""))) \
			or not offset_value is Array or (offset_value as Array).size() != 2 \
			or absf(float((offset_value as Array)[0])) > half_width \
			or absf(float((offset_value as Array)[1])) > half_height \
			or float(decoration.get("scale", 0.0)) < 0.75 or float(decoration.get("scale", 0.0)) > 1.25:
			return _fail("Wellspring source-court decoration is invalid")
		court_decorations.append(decoration)
	return true


func _validate_surface_alignment() -> bool:
	var candidate: Variant = data.get("surface_alignment", {})
	if not candidate is Dictionary:
		return _fail("Wellspring surface alignment must be an object")
	var profile: Dictionary = candidate
	var outer_margin := float(profile.get("cutaway_outer_margin", 0.0))
	var inner_margin := float(profile.get("cutaway_inner_margin", 0.0))
	var fade_distance := float(profile.get("cutaway_fade_distance", 0.0))
	if int(profile.get("collision_marker_length", 0)) < 8 or int(profile.get("collision_marker_length", 0)) > 20 \
		or int(profile.get("collision_marker_inset", -1)) < 0 or int(profile.get("collision_marker_inset", -1)) > 4 \
		or float(profile.get("collision_edge_alpha", 0.0)) < 0.25 or float(profile.get("collision_edge_alpha", 0.0)) > 0.75 \
		or int(profile.get("door_threshold_width", 0)) < 28 or int(profile.get("door_threshold_width", 0)) > 40 \
		or int(profile.get("door_threshold_depth", 0)) < 4 or int(profile.get("door_threshold_depth", 0)) > 8 \
		or outer_margin < 36.0 or outer_margin > 56.0 \
		or inner_margin < 12.0 or inner_margin > 24.0 \
		or outer_margin <= inner_margin \
		or not is_equal_approx(fade_distance, outer_margin - inner_margin):
		return _fail("Wellspring surface-alignment bounds are unsafe")
	surface_alignment = profile.duplicate(true)
	return true


func _draw_court_decorations(canvas: CanvasItem, center: Vector2, reduced_effects: bool) -> void:
	var glow_alpha := 0.10 if reduced_effects else 0.18
	for decoration: Dictionary in court_decorations:
		var offset_value: Array = decoration.get("offset", [])
		var position := center + Vector2(float(offset_value[0]), float(offset_value[1]))
		var size_scale := float(decoration.get("scale", 1.0))
		var accent := language.element_color(String(decoration.get("accent", "light")), "bright")
		canvas.draw_colored_polygon(_ellipse(position + Vector2(3, 6), Vector2(21, 9) * size_scale, 16), Color(language.ramp_color("worldbone", 0), 0.36))
		match String(decoration.get("kind", "")):
			"lantern":
				if environment_kit != null:
					environment_kit.draw_anchored(canvas, "brass-lantern", position + Vector2(0, 7) * size_scale, Color.WHITE, 0.82 * size_scale)
				canvas.draw_rect(Rect2(position + Vector2(-3, -18) * size_scale, Vector2(6, 20) * size_scale), language.ramp_color("timber", 3), true)
				canvas.draw_rect(Rect2(position + Vector2(-10, -23) * size_scale, Vector2(20, 8) * size_scale), language.ramp_color("aged_brass", 2), true)
				canvas.draw_rect(Rect2(position + Vector2(-6, -21) * size_scale, Vector2(12, 4) * size_scale), Color(accent, 0.78), true)
				canvas.draw_circle(position + Vector2(0, -19) * size_scale, 16.0 * size_scale, Color(accent, glow_alpha))
			"planter":
				if environment_kit != null:
					environment_kit.draw_anchored(canvas, "garden-planter", position + Vector2(0, 8) * size_scale, Color.WHITE, 0.72 * size_scale)
				canvas.draw_rect(Rect2(position + Vector2(-18, -7) * size_scale, Vector2(36, 15) * size_scale), language.ramp_color("worldbone", 2), true)
				canvas.draw_rect(Rect2(position + Vector2(-14, -8) * size_scale, Vector2(28, 8) * size_scale), language.ramp_color("garden", 2), true)
				for leaf_offset: Vector2 in [Vector2(-10, -12), Vector2(0, -17), Vector2(10, -12)]:
					canvas.draw_circle(position + leaf_offset * size_scale, 7.0 * size_scale, language.ramp_color("garden", 4))
			"rune":
				var diamond := PackedVector2Array([
					position + Vector2(0, -15) * size_scale,
					position + Vector2(15, 0) * size_scale,
					position + Vector2(0, 15) * size_scale,
					position + Vector2(-15, 0) * size_scale,
				])
				canvas.draw_colored_polygon(diamond, Color(accent, 0.12))
				canvas.draw_polyline(_closed(diamond), Color(accent, 0.60), 2.0, false)
				canvas.draw_line(position + Vector2(-7, 0) * size_scale, position + Vector2(7, 0) * size_scale, Color(accent, 0.52), 2.0)
				canvas.draw_line(position + Vector2(0, -7) * size_scale, position + Vector2(0, 7) * size_scale, Color(accent, 0.52), 2.0)


func _draw_court_pavers(canvas: CanvasItem, court: Rect2, cell_size: int) -> void:
	var line := Color(language.ramp_color("worldbone", 3), 0.28)
	for y: int in range(roundi(court.position.y), roundi(court.end.y), cell_size):
		canvas.draw_line(Vector2(court.position.x, y), Vector2(court.end.x, y), line, 1.0)
		var row := floori((float(y) - court.position.y) / float(cell_size))
		var offset := float(cell_size) * 0.5 if row % 2 != 0 else 0.0
		for x: int in range(roundi(court.position.x + offset), roundi(court.end.x), cell_size):
			canvas.draw_line(Vector2(x, y), Vector2(x, minf(court.end.y, y + cell_size)), line, 1.0)


func _index_buildings(maximum_facade_ratio: float) -> bool:
	var values: Variant = data.get("building_profiles", [])
	if not values is Array or (values as Array).size() != BUILDING_STYLES.size():
		return _fail("Wellspring architecture must define every building style exactly once")
	for value: Variant in values:
		if not value is Dictionary:
			return _fail("Wellspring building profile must be an object")
		var profile: Dictionary = value
		var style := String(profile.get("style", ""))
		var facade_ratio := float(profile.get("facade_ratio", 0.0))
		if style not in BUILDING_STYLES or building_profiles.has(style) \
			or String(profile.get("roof_shape", "")) not in ROOF_SHAPES \
			or not language.ramps.has(String(profile.get("roof_ramp", ""))) \
			or String(profile.get("facade", "")) not in FACADES \
			or String(profile.get("motif", "")) not in MOTIFS \
			or not language.elements.has(String(profile.get("accent", ""))) \
			or facade_ratio < 0.24 or facade_ratio > maximum_facade_ratio \
			or int(profile.get("bay_width", 0)) < 24 or int(profile.get("bay_width", 0)) > 48 \
			or int(profile.get("roof_rise", 0)) < 10 or int(profile.get("roof_rise", 0)) > 28:
			return _fail("Wellspring building profile is invalid: %s" % style)
		building_profiles[style] = profile
	return true


func _index_stations() -> bool:
	var values: Variant = data.get("station_profiles", [])
	if not values is Array or (values as Array).size() != STATION_KINDS.size():
		return _fail("Wellspring architecture must define every station kind exactly once")
	for value: Variant in values:
		if not value is Dictionary:
			return _fail("Wellspring station profile must be an object")
		var profile: Dictionary = value
		var kind := String(profile.get("kind", ""))
		if kind not in STATION_KINDS or station_profiles.has(kind) \
			or String(profile.get("furniture", "")) not in FURNITURE \
			or not language.elements.has(String(profile.get("accent", ""))):
			return _fail("Wellspring station profile is invalid: %s" % kind)
		station_profiles[kind] = profile
	return true


func _index_landmarks() -> bool:
	var values: Variant = data.get("landmark_profiles", [])
	if not values is Array or (values as Array).size() != LANDMARK_KINDS.size():
		return _fail("Wellspring architecture must define every landmark kind exactly once")
	for value: Variant in values:
		if not value is Dictionary:
			return _fail("Wellspring landmark profile must be an object")
		var profile: Dictionary = value
		var kind := String(profile.get("kind", ""))
		if kind not in LANDMARK_KINDS or landmark_profiles.has(kind) \
			or String(profile.get("frame", "")) not in LANDMARK_FRAMES \
			or not language.elements.has(String(profile.get("accent", ""))):
			return _fail("Wellspring landmark profile is invalid: %s" % kind)
		landmark_profiles[kind] = profile
	return true


func draw_building(canvas: CanvasItem, building: Dictionary) -> bool:
	if canvas == null:
		return false
	var style := String(building.get("style", ""))
	if not building_profiles.has(style):
		return false
	var profile: Dictionary = building_profiles[style]
	var bounds := SanctumCampusLayout._parse_bounds(building.get("bounds", []))
	var footprint := Rect2(bounds)
	var facade_height := clampi(roundi(float(bounds.size.y) * float(profile.get("facade_ratio", 0.3))), 32, 58)
	var facade := Rect2(bounds.position.x, bounds.end.y - facade_height, bounds.size.x, facade_height)
	_draw_foundation(canvas, footprint)
	_draw_facade(canvas, facade, profile)
	_draw_roof(canvas, bounds, facade, profile)
	_draw_door_and_windows(canvas, bounds, facade, profile)
	_draw_building_motif(canvas, bounds, facade, profile)
	_draw_collision_alignment(canvas, footprint)
	return true


func draw_station_frame(canvas: CanvasItem, station: Dictionary, tick: int, reduced_effects: bool) -> bool:
	if canvas == null:
		return false
	var kind := String(station.get("kind", ""))
	if not station_profiles.has(kind):
		return false
	var profile: Dictionary = station_profiles[kind]
	var position := _point(station.get("position", []))
	var footprint := float((data.get("budgets", {}) as Dictionary).get("station_footprint", 48))
	var accent := language.element_color(String(profile.get("accent", "light")), "bright")
	var furniture := String(profile.get("furniture", ""))
	var pulse := 0.0 if reduced_effects else (sin(float(tick) * 0.05 + position.x * 0.01) + 1.0) * 0.04
	var base := Rect2(position.x - footprint * 0.5, position.y - 12.0, footprint, 27.0)
	canvas.draw_rect(Rect2(base.position + Vector2(3, 6), base.size), Color(language.ramp_color("worldbone", 0), 0.62), true)
	canvas.draw_rect(base, language.ramp_color("warm_stone", 1), true)
	canvas.draw_rect(base, Color(language.ramp_color("aged_brass", 3), 0.70), false, 2.0)
	canvas.draw_rect(Rect2(position.x - 13, position.y + 13, 26, 4), language.ramp_color("warm_stone", 3), true)
	match furniture:
		"lectern", "desk":
			canvas.draw_rect(Rect2(position.x - 17, position.y - 23, 34, 7), language.ramp_color("timber", 3), true)
			canvas.draw_line(position + Vector2(-12, -16), position + Vector2(-9, -5), language.ramp_color("aged_brass", 3), 2.0)
			canvas.draw_line(position + Vector2(12, -16), position + Vector2(9, -5), language.ramp_color("aged_brass", 3), 2.0)
		"bell":
			canvas.draw_line(position + Vector2(-15, -8), position + Vector2(-15, -27), language.ramp_color("timber", 3), 3.0)
			canvas.draw_line(position + Vector2(15, -8), position + Vector2(15, -27), language.ramp_color("timber", 3), 3.0)
			canvas.draw_line(position + Vector2(-17, -27), position + Vector2(17, -27), language.ramp_color("aged_brass", 3), 3.0)
		"loom":
			for side: float in [-1.0, 1.0]:
				canvas.draw_line(position + Vector2(side * 15, -8), position + Vector2(side * 15, -27), language.ramp_color("aged_brass", 3), 2.0)
				canvas.draw_circle(position + Vector2(side * 15, -29), 3.0, accent)
		"gate":
			canvas.draw_arc(position + Vector2(0, -7), 20.0, PI, TAU, 16, language.ramp_color("aged_brass", 3), 4.0)
			canvas.draw_line(position + Vector2(-20, -7), position + Vector2(-20, 9), language.ramp_color("aged_brass", 2), 4.0)
			canvas.draw_line(position + Vector2(20, -7), position + Vector2(20, 9), language.ramp_color("aged_brass", 2), 4.0)
		"hearth":
			for offset: Vector2 in [Vector2(-14, 6), Vector2(-7, 12), Vector2(7, 12), Vector2(14, 6)]:
				canvas.draw_circle(position + offset, 5.0, language.ramp_color("worldbone", 3))
	canvas.draw_circle(position, 21.0, Color(accent, 0.05 + pulse))
	return true


func draw_landmark_frame(canvas: CanvasItem, landmark: Dictionary, tick: int, reduced_effects: bool) -> bool:
	if canvas == null:
		return false
	var kind := String(landmark.get("kind", ""))
	if not landmark_profiles.has(kind):
		return false
	var profile: Dictionary = landmark_profiles[kind]
	var position := _point(landmark.get("position", []))
	var accent := language.element_color(String(profile.get("accent", "light")), "bright")
	var frame := String(profile.get("frame", ""))
	var pulse := 0.0 if reduced_effects else (sin(float(tick) * 0.04 + position.y * 0.01) + 1.0) * 0.5
	canvas.draw_circle(position + Vector2(4, 8), 50.0, Color(language.ramp_color("worldbone", 0), 0.52))
	canvas.draw_circle(position, 46.0, language.ramp_color("warm_stone", 1))
	canvas.draw_arc(position, 43.0, 0.0, TAU, 24, language.ramp_color("aged_brass", 2), 3.0)
	for index: int in range(8):
		var direction := Vector2.from_angle(TAU * float(index) / 8.0)
		canvas.draw_line(position + direction * 35.0, position + direction * 44.0, Color(accent, 0.48), 2.0)
	match frame:
		"spire":
			canvas.draw_rect(Rect2(position.x - 7, position.y - 51, 14, 30), language.ramp_color("worldbone", 2), true)
			canvas.draw_colored_polygon(PackedVector2Array([position + Vector2(-11, -49), position + Vector2(0, -68), position + Vector2(11, -49)]), language.ramp_color("indigo_roof", 3))
		"basin":
			canvas.draw_arc(position, 35.0, PI, TAU, 20, Color(accent, 0.38), 3.0)
		"orrery":
			canvas.draw_arc(position, 32.0, -0.8, 2.35, 18, Color(accent, 0.62), 2.0)
			canvas.draw_arc(position, 25.0, 2.35, 5.5, 18, Color(language.ramp_color("aged_brass", 4), 0.62), 2.0)
		"gate":
			canvas.draw_arc(position, 34.0, PI, TAU, 20, Color(accent, 0.44 + pulse * 0.08), 5.0)
		"crucible":
			canvas.draw_line(position + Vector2(-34, 22), position + Vector2(-20, -20), language.ramp_color("aged_brass", 3), 4.0)
			canvas.draw_line(position + Vector2(34, 22), position + Vector2(20, -20), language.ramp_color("aged_brass", 3), 4.0)
	return true


func _draw_foundation(canvas: CanvasItem, footprint: Rect2) -> void:
	canvas.draw_rect(Rect2(footprint.position + Vector2(7, 10), footprint.size), Color(language.ramp_color("worldbone", 0), 0.78), true)
	canvas.draw_rect(footprint, language.ramp_color("worldbone", 2), true)
	canvas.draw_rect(footprint, Color(language.ramp_color("warm_stone", 3), 0.58), false, 2.0)
	for x: int in range(roundi(footprint.position.x) + 12, roundi(footprint.end.x) - 8, 28):
		canvas.draw_rect(Rect2(x, footprint.end.y - 8, 15, 5), language.ramp_color("worldbone", 3), true)


func _draw_facade(canvas: CanvasItem, facade: Rect2, profile: Dictionary) -> void:
	var facade_kind := String(profile.get("facade", "stone_timber"))
	var fill := language.ramp_color("warm_stone", 1)
	if facade_kind == "timber_frame":
		fill = language.ramp_color("timber", 2)
	elif facade_kind == "garden_stone":
		fill = language.ramp_color("garden", 1)
	elif facade_kind == "foundry_brick":
		fill = language.ramp_color("timber", 3)
	canvas.draw_rect(facade, fill, true)
	var wall_texture := runtime_kit.texture("academy-wall") if runtime_kit != null else null
	if wall_texture != null:
		canvas.draw_texture_rect(wall_texture, facade, true, Color(1.0, 1.0, 1.0, 0.42 if facade_kind != "foundry_brick" else 0.28))
	var authored_facade := environment_kit.texture("academy-facade") if environment_kit != null else null
	if authored_facade != null:
		var module_count := clampi(ceili(facade.size.x / 170.0), 1, 3)
		var gap := 12.0
		var module_width := minf(106.0, (facade.size.x - gap * float(module_count - 1)) / float(module_count))
		var group_width := module_width * float(module_count) + gap * float(module_count - 1)
		var start_x := facade.get_center().x - group_width * 0.5
		for module_index: int in range(module_count):
			canvas.draw_texture_rect(
				authored_facade,
				Rect2(start_x + float(module_index) * (module_width + gap), facade.position.y, module_width, facade.size.y),
				false,
				Color(1.0, 1.0, 1.0, 0.42 if facade_kind != "foundry_brick" else 0.26),
			)
	for y: int in range(roundi(facade.position.y) + 7, roundi(facade.end.y), 9):
		canvas.draw_line(Vector2(facade.position.x + 3, y), Vector2(facade.end.x - 3, y), Color(language.ramp_color("warm_stone", 3), 0.23), 1.0)
	var bay_width := int(profile.get("bay_width", 36))
	for x: int in range(roundi(facade.position.x) + bay_width, roundi(facade.end.x), bay_width):
		canvas.draw_line(Vector2(x, facade.position.y + 2), Vector2(x, facade.end.y - 2), language.ramp_color("timber", 3), 3.0)
		if facade_kind in ["timber_frame", "stone_timber"]:
			canvas.draw_line(Vector2(x - 10, facade.end.y - 4), Vector2(x, facade.position.y + 5), Color(language.ramp_color("timber", 4), 0.54), 2.0)
	canvas.draw_line(facade.position + Vector2(0, 3), Vector2(facade.end.x, facade.position.y + 3), language.ramp_color("aged_brass", 2), 2.0)


func _draw_roof(canvas: CanvasItem, bounds: Rect2i, facade: Rect2, profile: Dictionary) -> void:
	var shape := String(profile.get("roof_shape", "gable"))
	var ramp := String(profile.get("roof_ramp", "indigo_roof"))
	var roof_dark := language.ramp_color(ramp, 1)
	var roof_mid := language.ramp_color(ramp, 2)
	var roof_light := language.ramp_color(ramp, 3)
	var accent := language.element_color(String(profile.get("accent", "light")), "bright")
	var overhang := int((data.get("budgets", {}) as Dictionary).get("maximum_roof_overhang", 8))
	var rise := int(profile.get("roof_rise", 18))
	var roof_bottom := roundi(facade.position.y) + 4
	if shape in ["gable", "hipped", "spire"]:
		var inset := rise if shape == "hipped" else maxi(10, rise / 2)
		var ridge_y := bounds.position.y + rise
		var rear_plane := PackedVector2Array([
			Vector2(bounds.position.x - overhang, bounds.position.y + rise),
			Vector2(bounds.position.x + inset, bounds.position.y - 4),
			Vector2(bounds.end.x - inset, bounds.position.y - 4),
			Vector2(bounds.end.x + overhang, bounds.position.y + rise),
		])
		var front_plane := PackedVector2Array([
			Vector2(bounds.position.x - overhang, ridge_y),
			Vector2(bounds.end.x + overhang, ridge_y),
			Vector2(bounds.end.x + 2, roof_bottom),
			Vector2(bounds.position.x - 2, roof_bottom),
		])
		canvas.draw_colored_polygon(rear_plane, roof_light.darkened(0.16))
		canvas.draw_colored_polygon(front_plane, roof_mid)
		var roof_texture := runtime_kit.texture("blue-green-roof") if runtime_kit != null else null
		if roof_texture != null:
			canvas.draw_texture_rect(
				roof_texture,
				Rect2(bounds.position.x, ridge_y + 2, bounds.size.x, maxi(1, roof_bottom - ridge_y - 3)),
				true,
				Color(roof_light.lightened(0.28), 0.36),
			)
		canvas.draw_polyline(_closed(rear_plane), language.ramp_color("aged_brass", 1), 3.0, false)
		canvas.draw_polyline(_closed(front_plane), language.ramp_color("aged_brass", 1), 3.0, false)
		canvas.draw_line(Vector2(bounds.position.x - overhang + 2, ridge_y), Vector2(bounds.end.x + overhang - 2, ridge_y), language.ramp_color("aged_brass", 3), 3.0)
		for y: int in range(ridge_y + 8, roof_bottom, 10):
			canvas.draw_line(Vector2(bounds.position.x + 3, y), Vector2(bounds.end.x - 3, y), Color(roof_light, 0.30), 2.0)
		var authored_roof := environment_kit.texture("academy-roof") if environment_kit != null else null
		if authored_roof != null and roof_bottom > ridge_y + 8:
			canvas.draw_texture_rect(
				authored_roof,
				Rect2(bounds.position.x + 3, ridge_y + 2, bounds.size.x - 6, roof_bottom - ridge_y - 4),
				false,
				Color(roof_light.lightened(0.18), 0.38),
			)
		var module_step := maxi(58, int(profile.get("bay_width", 36)) * 2)
		var module_index := 0
		for x: int in range(bounds.position.x + module_step / 2, bounds.end.x - module_step / 3, module_step):
			canvas.draw_line(Vector2(x, ridge_y + 3), Vector2(x, roof_bottom - 3), Color(roof_dark, 0.34), 2.0)
			if roof_bottom - ridge_y >= 58 and module_index % 2 == 0:
				_draw_dormer(canvas, Vector2(x, ridge_y + mini(48, (roof_bottom - ridge_y) / 2)), roof_dark, roof_light, accent)
			module_index += 1
		if shape == "hipped":
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(bounds.position.x - overhang, ridge_y),
				Vector2(bounds.position.x + inset, bounds.position.y - 4),
				Vector2(bounds.position.x + inset, roof_bottom),
				Vector2(bounds.position.x - 2, roof_bottom),
			]), Color(roof_dark, 0.50))
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(bounds.end.x + overhang, ridge_y),
				Vector2(bounds.end.x - inset, bounds.position.y - 4),
				Vector2(bounds.end.x - inset, roof_bottom),
				Vector2(bounds.end.x + 2, roof_bottom),
			]), Color(roof_dark, 0.50))
		canvas.draw_line(Vector2(bounds.position.x + inset, bounds.position.y), Vector2(bounds.end.x - inset, bounds.position.y), language.ramp_color("aged_brass", 3), 2.0)
		if shape == "spire":
			var center_x := bounds.get_center().x
			var tower := Rect2(center_x - 27, ridge_y + 5, 54, minf(72.0, float(roof_bottom - ridge_y - 12)))
			canvas.draw_rect(Rect2(tower.position + Vector2(4, 6), tower.size), Color(language.ramp_color("worldbone", 0), 0.55), true)
			canvas.draw_rect(tower, roof_dark, true)
			canvas.draw_rect(tower, language.ramp_color("aged_brass", 2), false, 2.0)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(center_x - 32, tower.position.y), Vector2(center_x, tower.position.y - 32), Vector2(center_x + 32, tower.position.y)]), roof_light)
			canvas.draw_line(Vector2(center_x, tower.position.y - 31), Vector2(center_x, tower.position.y - 43), language.ramp_color("aged_brass", 4), 2.0)
			canvas.draw_circle(Vector2(center_x, tower.position.y - 45), 4.0, accent)
	elif shape == "dome":
		var roof_rect := Rect2(bounds.position.x - overhang, bounds.position.y - 4, bounds.size.x + overhang * 2, roof_bottom - bounds.position.y + 8)
		var dome := _octagon(roof_rect)
		canvas.draw_colored_polygon(dome, roof_mid)
		canvas.draw_polyline(_closed(dome), language.ramp_color("aged_brass", 2), 3.0, false)
		var inner_rect := roof_rect.grow(-16.0)
		canvas.draw_colored_polygon(_octagon(inner_rect), roof_dark.lightened(0.05))
		canvas.draw_polyline(_closed(_octagon(inner_rect)), Color(language.ramp_color("aged_brass", 3), 0.68), 2.0, false)
		var center := Vector2(bounds.get_center().x, bounds.position.y + roof_rect.size.y * 0.48)
		var ring_x := minf(roof_rect.size.x * 0.24, 76.0)
		var ring_y := minf(roof_rect.size.y * 0.28, 50.0)
		for scale_value: float in [1.0, 0.64]:
			canvas.draw_polyline(_closed(_ellipse(center, Vector2(ring_x, ring_y) * scale_value, 24)), Color(roof_light, 0.54), 3.0, false)
		for index: int in range(8):
			var direction := Vector2.from_angle(TAU * float(index) / 8.0)
			canvas.draw_line(center + direction * 14.0, center + Vector2(direction.x * ring_x, direction.y * ring_y), Color(language.ramp_color("aged_brass", 3), 0.48), 2.0)
		canvas.draw_circle(center + Vector2(3, 5), 14.0, Color(language.ramp_color("worldbone", 0), 0.42))
		canvas.draw_circle(center, 12.0, language.ramp_color("aged_brass", 2))
		canvas.draw_circle(center, 6.0, Color(accent, 0.72))
	else:
		var roof_rect := Rect2(bounds.position.x - overhang, bounds.position.y - 4, bounds.size.x + overhang * 2, roof_bottom - bounds.position.y + 8)
		canvas.draw_rect(roof_rect, roof_dark, true)
		canvas.draw_rect(roof_rect, language.ramp_color("aged_brass", 2), false, 3.0)
		var saw_step := 46
		var saw_index := 0
		for x: int in range(bounds.position.x, bounds.end.x, saw_step):
			var finish_x := mini(x + saw_step, bounds.end.x)
			var saw := PackedVector2Array([
				Vector2(x, bounds.position.y + 8 + (8 if saw_index % 2 == 0 else 0)),
				Vector2(finish_x, bounds.position.y + 2 + (8 if saw_index % 2 == 0 else 0)),
				Vector2(finish_x, roof_bottom - 3),
				Vector2(x, roof_bottom - 3),
			])
			canvas.draw_colored_polygon(saw, Color(roof_mid, 0.72 if saw_index % 2 == 0 else 0.42))
			canvas.draw_line(Vector2(finish_x, bounds.position.y + 4), Vector2(finish_x, roof_bottom - 3), Color(roof_light, 0.30), 2.0)
			if saw_index % 2 == 0:
				canvas.draw_rect(Rect2(x + 14, bounds.position.y - 17, 12, 24), language.ramp_color("worldbone", 2), true)
				canvas.draw_rect(Rect2(x + 12, bounds.position.y - 20, 16, 5), language.ramp_color("aged_brass", 2), true)
			saw_index += 1
		for y: int in range(bounds.position.y + 16, roof_bottom, 14):
			canvas.draw_line(Vector2(bounds.position.x + 4, y), Vector2(bounds.end.x - 4, y), Color(roof_light, 0.22), 2.0)


func _draw_dormer(canvas: CanvasItem, center: Vector2, roof_dark: Color, roof_light: Color, accent: Color) -> void:
	var wall := Rect2(center.x - 8, center.y - 4, 16, 16)
	canvas.draw_rect(Rect2(wall.position + Vector2(2, 3), wall.size), Color(language.ramp_color("worldbone", 0), 0.42), true)
	canvas.draw_rect(wall, language.ramp_color("warm_stone", 2), true)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-11, -3),
		center + Vector2(0, -13),
		center + Vector2(11, -3),
	]), roof_dark)
	canvas.draw_line(center + Vector2(-11, -3), center + Vector2(0, -13), roof_light, 2.0)
	canvas.draw_line(center + Vector2(0, -13), center + Vector2(11, -3), roof_light, 2.0)
	canvas.draw_rect(Rect2(center.x - 3, center.y + 1, 6, 7), Color(accent, 0.42), true)
	canvas.draw_rect(Rect2(center.x - 3, center.y + 1, 6, 7), language.ramp_color("aged_brass", 2), false, 1.0)


func _draw_door_and_windows(canvas: CanvasItem, bounds: Rect2i, facade: Rect2, profile: Dictionary) -> void:
	var accent := language.element_color(String(profile.get("accent", "light")), "bright")
	var door_width := mini(26, bounds.size.x / 3)
	var door := Rect2(bounds.position.x + (bounds.size.x - door_width) / 2, bounds.end.y - 31, door_width, 31)
	canvas.draw_rect(door, language.ramp_color("timber", 0), true)
	canvas.draw_rect(door, language.ramp_color("aged_brass", 3), false, 2.0)
	canvas.draw_circle(door.position + Vector2(door.size.x - 6, door.size.y * 0.55), 2.0, accent)
	var authored_door := environment_kit.texture("academy-door") if environment_kit != null else null
	if authored_door != null:
		var door_art := Rect2(door.get_center().x - 25, bounds.end.y - 40, 50, 40)
		canvas.draw_texture_rect(authored_door, door_art, false, Color(1.0, 1.0, 1.0, 0.86))
	var threshold := door_threshold_rect(
		Rect2(bounds),
		float(surface_alignment.get("door_threshold_width", 34)),
		float(surface_alignment.get("door_threshold_depth", 6)),
	)
	canvas.draw_rect(threshold, language.ramp_color("warm_stone", 3), true)
	canvas.draw_line(Vector2(threshold.position.x, threshold.end.y), threshold.end, language.ramp_color("worldbone", 0), 1.0)
	var threshold_center := threshold.get_center()
	for side: float in [-1.0, 1.0]:
		canvas.draw_line(
			threshold_center + Vector2(side * 7.0, -2.0),
			threshold_center + Vector2(side * 3.0, 2.0),
			Color(accent, 0.46),
			1.0,
		)
	for window_x: int in range(bounds.position.x + 16, bounds.end.x - 12, int(profile.get("bay_width", 36))):
		var window := Rect2(window_x, facade.position.y + 11, 11, 13)
		if window.intersects(door.grow(5)):
			continue
		canvas.draw_rect(window, Color(accent, 0.24), true)
		canvas.draw_rect(window, language.ramp_color("aged_brass", 1), false, 1.0)
		canvas.draw_line(window.position + Vector2(window.size.x * 0.5, 1), window.position + Vector2(window.size.x * 0.5, window.size.y - 1), Color(language.ui_color("text_primary"), 0.34), 1.0)
		var authored_window := environment_kit.texture("academy-window") if environment_kit != null else null
		if authored_window != null:
			canvas.draw_texture_rect(authored_window, Rect2(window.get_center() - Vector2(12, 10), Vector2(24, 20)), false, Color(1.0, 1.0, 1.0, 0.72))


func _draw_building_motif(canvas: CanvasItem, bounds: Rect2i, facade: Rect2, profile: Dictionary) -> void:
	var motif := String(profile.get("motif", "route"))
	var accent := language.element_color(String(profile.get("accent", "light")), "bright")
	var center := Vector2(bounds.get_center().x, bounds.position.y + 34)
	match motif:
		"garden":
			for side: float in [-1.0, 1.0]:
				canvas.draw_rect(Rect2(center.x + side * 42 - 12, facade.position.y - 7, 24, 9), language.ramp_color("garden", 2), true)
				canvas.draw_circle(Vector2(center.x + side * 42, facade.position.y - 10), 6.0, language.ramp_color("garden", 4))
		"archive":
			canvas.draw_arc(center, 18.0, -0.8, 2.35, 16, accent, 2.0)
			canvas.draw_arc(center, 11.0, 2.35, 5.5, 14, language.ramp_color("aged_brass", 4), 2.0)
		"attunement":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -12), center + Vector2(8, 0), center + Vector2(0, 12), center + Vector2(-8, 0)]), Color(accent, 0.72))
			canvas.draw_line(center + Vector2(0, -13), center + Vector2(0, -27), language.ramp_color("aged_brass", 3), 2.0)
		"service":
			canvas.draw_arc(center, 13.0, 0.0, TAU, 16, language.ramp_color("aged_brass", 4), 3.0)
			for index: int in range(4):
				var direction := Vector2.from_angle(float(index) * PI * 0.5)
				canvas.draw_line(center + direction * 13.0, center + direction * 19.0, accent, 3.0)
		"farflow":
			canvas.draw_arc(center, 20.0, PI, TAU, 18, Color(accent, 0.74), 4.0)
			canvas.draw_circle(center, 6.0, Color(language.element_color("spirit", "bright"), 0.55))
		"foundry":
			canvas.draw_circle(center, 14.0, Color(accent, 0.46))
			canvas.draw_arc(center, 16.0, 0.0, TAU, 16, language.ramp_color("aged_brass", 3), 3.0)
		_:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -9), center + Vector2(8, -4), center + Vector2(5, 11), center + Vector2(-8, 7)]), Color(accent, 0.52))


func _draw_collision_alignment(canvas: CanvasItem, footprint: Rect2) -> void:
	var marker_length := float(surface_alignment.get("collision_marker_length", 12))
	var marker_inset := float(surface_alignment.get("collision_marker_inset", 2))
	var marker_alpha := float(surface_alignment.get("collision_edge_alpha", 0.58))
	var marker_color := Color(language.ramp_color("warm_stone", 4), marker_alpha)
	for segment: PackedVector2Array in collision_corner_segments(footprint, marker_length, marker_inset):
		canvas.draw_line(segment[0], segment[1], marker_color, 2.0)


func cutaway_amount(footprint: Rect2, focus_world_position: Vector2) -> float:
	return cutaway_amount_for_profile(footprint, focus_world_position, surface_alignment)


static func cutaway_amount_for_profile(footprint: Rect2, focus_world_position: Vector2, profile: Dictionary) -> float:
	if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
		return 0.0
	var outer_margin := float(profile.get("cutaway_outer_margin", 44.0))
	var inner_margin := float(profile.get("cutaway_inner_margin", 18.0))
	var fade_distance := float(profile.get("cutaway_fade_distance", outer_margin - inner_margin))
	if outer_margin <= inner_margin or fade_distance <= 0.0:
		return 0.0
	var outer := footprint.grow(outer_margin)
	if not outer.has_point(focus_world_position):
		return 0.0
	var inner := footprint.grow(inner_margin)
	if inner.has_point(focus_world_position):
		return 1.0
	var nearest := Vector2(
		clampf(focus_world_position.x, inner.position.x, inner.end.x),
		clampf(focus_world_position.y, inner.position.y, inner.end.y),
	)
	return 1.0 - clampf(focus_world_position.distance_to(nearest) / fade_distance, 0.0, 1.0)


static func door_threshold_rect(footprint: Rect2, width: float, depth: float) -> Rect2:
	if footprint.size.x <= 0.0 or footprint.size.y <= 0.0 or width <= 0.0 or depth <= 0.0:
		return Rect2()
	var bounded_width := minf(width, footprint.size.x)
	return Rect2(footprint.get_center().x - bounded_width * 0.5, footprint.end.y, bounded_width, depth)


static func collision_corner_segments(footprint: Rect2, marker_length: float, inset: float) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if footprint.size.x <= 0.0 or footprint.size.y <= 0.0 or marker_length <= 0.0 or inset < 0.0:
		return segments
	var length_x := minf(marker_length, maxf(0.0, footprint.size.x * 0.5 - inset))
	var length_y := minf(marker_length, maxf(0.0, footprint.size.y * 0.5 - inset))
	var left := footprint.position.x
	var top := footprint.position.y
	var right := footprint.end.x
	var bottom := footprint.end.y
	segments.assign([
		PackedVector2Array([Vector2(left + inset, top), Vector2(left + inset + length_x, top)]),
		PackedVector2Array([Vector2(left, top + inset), Vector2(left, top + inset + length_y)]),
		PackedVector2Array([Vector2(right - inset - length_x, top), Vector2(right - inset, top)]),
		PackedVector2Array([Vector2(right, top + inset), Vector2(right, top + inset + length_y)]),
		PackedVector2Array([Vector2(left + inset, bottom), Vector2(left + inset + length_x, bottom)]),
		PackedVector2Array([Vector2(left, bottom - inset - length_y), Vector2(left, bottom - inset)]),
		PackedVector2Array([Vector2(right - inset - length_x, bottom), Vector2(right - inset, bottom)]),
		PackedVector2Array([Vector2(right, bottom - inset - length_y), Vector2(right, bottom - inset)]),
	])
	return segments


static func _point(values: Variant) -> Vector2:
	var point: Array = values
	return Vector2(float(point[0]), float(point[1]))


static func _stepped_rect(rectangle: Rect2, step: float) -> PackedVector2Array:
	return PackedVector2Array([
		rectangle.position + Vector2(step, 0),
		Vector2(rectangle.end.x - step, rectangle.position.y),
		Vector2(rectangle.end.x, rectangle.position.y + step),
		rectangle.end - Vector2(0, step),
		rectangle.end - Vector2(step, 0),
		Vector2(rectangle.position.x + step, rectangle.end.y),
		Vector2(rectangle.position.x, rectangle.end.y - step),
		rectangle.position + Vector2(0, step),
	])


static func _offset(points: PackedVector2Array, amount: Vector2) -> PackedVector2Array:
	var output := PackedVector2Array()
	for point: Vector2 in points:
		output.append(point + amount)
	return output


static func _octagon(rectangle: Rect2) -> PackedVector2Array:
	var step := minf(18.0, minf(rectangle.size.x, rectangle.size.y) * 0.25)
	return PackedVector2Array([
		rectangle.position + Vector2(step, 0), Vector2(rectangle.end.x - step, rectangle.position.y),
		Vector2(rectangle.end.x, rectangle.position.y + step), rectangle.end - Vector2(0, step),
		rectangle.end - Vector2(step, 0), Vector2(rectangle.position.x + step, rectangle.end.y),
		Vector2(rectangle.position.x, rectangle.end.y - step), rectangle.position + Vector2(0, step),
	])


static func _ellipse(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var output := PackedVector2Array()
	for index: int in range(segments):
		var angle := TAU * float(index) / float(segments)
		output.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return output


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var output := points.duplicate()
	if not output.is_empty():
		output.append(output[0])
	return output


func _fail(message: String) -> bool:
	last_error = message
	return false
