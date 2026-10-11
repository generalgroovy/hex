class_name NaturalMapKit
extends RefCounted


const DEFAULT_PATH := "res://content/visual/natural_map_kit_v1.json"
const EXPECTED_ID := "natural-map-kit-v2-bullet-room"
const EXPECTED_AUTHORITY := "presentation only; authored map topology, collision, elevation and routes remain canonical elsewhere"
const REQUIRED_STYLES := ["garden", "nexus", "proving"]
const ALLOWED_FEATURES := ["grass_tuft", "leaf_pair", "blossom", "small_stone", "moss_seam", "brass_leaf", "dry_tuft"]
const ALLOWED_EDGE_PROPS := ["tree", "bush", "dry_bush"]

var language: VisualLanguage
var data: Dictionary = {}
var profiles: Dictionary = {}
var contact_profiles: Dictionary = {}
var receiving_shadow_profiles: Dictionary = {}
var elevation_shadow_opacity_step := 0.0
var combat_floor: Dictionary = {}
var content_hash := ""
var last_error := ""


func configure(visual_language: VisualLanguage, path: String = DEFAULT_PATH) -> bool:
	language = visual_language
	data.clear()
	profiles.clear()
	contact_profiles.clear()
	receiving_shadow_profiles.clear()
	elevation_shadow_opacity_step = 0.0
	combat_floor.clear()
	content_hash = ""
	last_error = ""
	if language == null or language.ramps.is_empty():
		return _fail("Natural map kit requires the validated visual language")
	if not FileAccess.file_exists(path):
		return _fail("Natural map kit does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Natural map kit cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Natural map kit root must be an object")
	data = parsed
	if not validate():
		data.clear()
		return false
	content_hash = source.sha256_text()
	return true


func validate() -> bool:
	last_error = ""
	if int(data.get("schema_version", -1)) != 2 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Natural map kit identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Natural map kit must remain presentation-only")
	var budgets: Dictionary = data.get("budgets", {})
	if int(budgets.get("detail_step", 0)) < 32 or int(budgets.get("detail_step", 0)) > 96 \
		or int(budgets.get("maximum_details_per_district", 0)) > 240 \
		or int(budgets.get("maximum_contact_marks_per_actor", 0)) > 8 \
		or int(budgets.get("maximum_arena_marks", 0)) < 8 \
		or int(budgets.get("maximum_arena_marks", 0)) > 32:
		return _fail("Natural map detail budget is unsafe")
	combat_floor = data.get("combat_floor", {})
	if not _validate_combat_floor(combat_floor):
		return false
	profiles = data.get("district_profiles", {})
	for style: String in REQUIRED_STYLES:
		if not profiles.has(style) or not _validate_district_profile(style, profiles[style]):
			return false
	contact_profiles = data.get("contact_profiles", {})
	for motion_id: String in ["walk", "sprint", "low", "air"]:
		var profile: Dictionary = contact_profiles.get(motion_id, {})
		if int(profile.get("period", 0)) < 4 or int(profile.get("period", 0)) > 30 \
			or float(profile.get("opacity", 0.0)) <= 0.0 or float(profile.get("opacity", 0.0)) > 0.6 \
			or float(profile.get("length", 0.0)) < 2.0 or float(profile.get("length", 0.0)) > 18.0:
			return _fail("Natural map contact profile is invalid: %s" % motion_id)
	var receiving_shadows: Dictionary = data.get("receiving_shadows", {})
	elevation_shadow_opacity_step = float(receiving_shadows.get("elevation_opacity_step", -1.0))
	if elevation_shadow_opacity_step < 0.0 or elevation_shadow_opacity_step > 0.08:
		return _fail("Natural map elevation shadow step is invalid")
	receiving_shadow_profiles = receiving_shadows.get("profiles", {})
	for surface_id: String in ["water", "garden", "nexus", "proving"]:
		var shadow_profile: Dictionary = receiving_shadow_profiles.get(surface_id, {})
		var ramp_id := String(shadow_profile.get("ramp", ""))
		var fill_step := int(shadow_profile.get("fill_step", -1))
		var rim_step := int(shadow_profile.get("rim_step", -1))
		if not language.ramps.has(ramp_id) \
			or fill_step < 0 or fill_step > 4 \
			or rim_step < 0 or rim_step > 4 \
			or float(shadow_profile.get("opacity_scale", 0.0)) < 0.50 or float(shadow_profile.get("opacity_scale", 0.0)) > 1.0 \
			or float(shadow_profile.get("rim_opacity", 0.0)) < 0.10 or float(shadow_profile.get("rim_opacity", 0.0)) > 0.35:
			return _fail("Natural map receiving-shadow profile is invalid: %s" % surface_id)
	return true


func draw_district_details(canvas: CanvasItem, district: Dictionary, district_index: int, tick: int, reduced_effects: bool) -> void:
	var style := String(district.get("style", ""))
	if canvas == null or not profiles.has(style):
		return
	var bounds := SanctumCampusLayout._parse_bounds(district.get("bounds", [])).grow(-18)
	var profile: Dictionary = profiles[style]
	var step := int((data.get("budgets", {}) as Dictionary).get("detail_step", 48))
	var maximum := int((data.get("budgets", {}) as Dictionary).get("maximum_details_per_district", 180))
	var features: Array = profile.get("features", [])
	var count := 0
	for y: int in range(bounds.position.y + step / 2, bounds.end.y, step):
		for x: int in range(bounds.position.x + step / 2, bounds.end.x, step):
			if count >= maximum:
				return
			var cell_seed := _hash_cell(x / step, y / step, district_index + int(data.get("seed", 0)))
			var edge_distance := mini(mini(x - bounds.position.x, bounds.end.x - x), mini(y - bounds.position.y, bounds.end.y - y))
			var density := float(profile.get("edge_density", 0.5)) if edge_distance < step * 1.5 else float(profile.get("interior_density", 0.1))
			if float(cell_seed % 1000) / 1000.0 > density:
				continue
			var jitter := Vector2(float((cell_seed >> 8) % 19) - 9.0, float((cell_seed >> 16) % 15) - 7.0)
			if cell_seed % 4 == 0:
				_draw_ground_patch(canvas, Vector2(x, y) + jitter, style, cell_seed, edge_distance < step * 1.5)
			var edge_props: Array = profile.get("edge_props", [])
			var use_edge_prop := edge_distance < step * 1.5 and not edge_props.is_empty() and cell_seed % 3 != 0
			var feature := String(edge_props[cell_seed % edge_props.size()]) if use_edge_prop else String(features[cell_seed % features.size()])
			var feature_scale := float(profile.get("edge_scale", 1.0)) if use_edge_prop else 1.0
			_draw_feature(canvas, Vector2(x, y) + jitter, feature, style, tick, cell_seed, reduced_effects, feature_scale)
			count += 1


func draw_arena_floor(canvas: CanvasItem, bounds: Rect2i, tick: int, reduced_effects: bool) -> void:
	if canvas == null or combat_floor.is_empty() or not combat_floor.get("arena", {}) is Dictionary:
		return
	var profile: Dictionary = combat_floor["arena"]
	var outer := Rect2(bounds).grow(-float(profile.get("outer_inset", 14)))
	var inner := Rect2(bounds).grow(-float(profile.get("inner_inset", 30)))
	var lane_width := float(profile.get("lane_width", 76))
	var pocket_radius := float(profile.get("safe_pocket_radius", 54))
	var outline_alpha := float(profile.get("outline_alpha", 0.34))
	var shimmer := 0.0 if reduced_effects else sin(float(tick) * 0.025) * 0.025
	canvas.draw_rect(outer, Color(language.ramp_color("worldbone", 0), 0.18), true)
	canvas.draw_rect(inner, Color(language.ramp_color("warm_stone", 1), 0.94), true)
	canvas.draw_rect(outer, Color(language.ramp_color("aged_brass", 2), outline_alpha), false, 3.0)
	canvas.draw_rect(inner, Color(language.ramp_color("warm_stone", 4), 0.24), false, 2.0)
	var horizontal_lane := Rect2(inner.position.x, inner.get_center().y - lane_width * 0.5, inner.size.x, lane_width)
	var vertical_lane := Rect2(inner.get_center().x - lane_width * 0.5, inner.position.y, lane_width, inner.size.y)
	canvas.draw_rect(horizontal_lane, Color(language.ramp_color("warm_stone", 3), 0.075), true)
	canvas.draw_rect(vertical_lane, Color(language.ramp_color("warm_stone", 3), 0.075), true)
	canvas.draw_arc(inner.get_center(), lane_width * 0.58, 0.0, TAU, 32, Color(language.ramp_color("aged_brass", 3), 0.24 + shimmer), 2.0)
	canvas.draw_arc(inner.get_center(), lane_width * 0.24, 0.0, TAU, 20, Color(language.ui_color("focus"), 0.18 + shimmer), 2.0)
	for pocket: Vector2 in arena_safe_pockets(inner, pocket_radius):
		var facing := (inner.get_center() - pocket).angle()
		canvas.draw_arc(pocket, pocket_radius, facing - 1.05, facing + 1.05, 12, Color(language.ramp_color("aged_brass", 3), 0.30), 3.0)
		canvas.draw_arc(pocket, pocket_radius - 8.0, facing - 0.82, facing + 0.82, 10, Color(language.ui_color("text_primary"), 0.12), 1.0)
	var marker_count := int(profile.get("marker_count", 12))
	for marker_index: int in range(marker_count):
		var edge_progress := float(marker_index) / float(maxi(1, marker_count - 1))
		var x := lerpf(inner.position.x + 28.0, inner.end.x - 28.0, edge_progress)
		var marker_color := Color(language.ramp_color("aged_brass", 4), 0.24)
		canvas.draw_line(Vector2(x - 5.0, inner.position.y + 4.0), Vector2(x + 5.0, inner.position.y + 4.0), marker_color, 2.0)
		canvas.draw_line(Vector2(x - 5.0, inner.end.y - 4.0), Vector2(x + 5.0, inner.end.y - 4.0), marker_color, 2.0)


static func arena_safe_pockets(inner: Rect2, radius: float) -> Array[Vector2]:
	if not inner.has_area() or radius <= 0.0:
		return []
	var inset := radius + 18.0
	return [
		inner.position + Vector2(inset, inset),
		Vector2(inner.end.x - inset, inner.position.y + inset),
		inner.end - Vector2(inset, inset),
		Vector2(inner.position.x + inset, inner.end.y - inset),
	]


func draw_actor_contact(canvas: CanvasItem, layout: SanctumCampusLayout, state: PlayerState, ground_anchor: Vector2, tick: int, reduced_effects: bool) -> void:
	if canvas == null or layout == null or state == null:
		return
	var motion_id := MinimalChampionMotion.motion_id(state)
	if not contact_profiles.has(motion_id):
		return
	var velocity := Vector2(float(state.velocity_x), float(state.velocity_y))
	if velocity.length_squared() < 1.0:
		return
	var surface := surface_style_at(layout, ground_anchor)
	var profile: Dictionary = contact_profiles[motion_id]
	var period := int(profile.get("period", 10))
	var phase := tick % period
	var fade := 1.0 - float(phase) / float(period)
	var opacity := float(profile.get("opacity", 0.3)) * fade * (0.55 if reduced_effects else 1.0)
	var length := float(profile.get("length", 4.0)) * (0.65 if reduced_effects else 1.0)
	var direction := velocity.normalized()
	var side := Vector2(-direction.y, direction.x)
	var ramp_id := String((profiles.get(surface, profiles["nexus"]) as Dictionary).get("contact_ramp", "warm_stone"))
	var color := Color(language.ramp_color(ramp_id, 4), opacity)
	if motion_id in ["walk", "sprint"]:
		var foot_side := -1.0 if (tick / period) % 2 == 0 else 1.0
		var foot := ground_anchor - direction * 8.0 + side * 4.0 * foot_side
		canvas.draw_line(foot - direction * length * 0.5, foot + direction * length * 0.5, color, 2.0)
		canvas.draw_circle(foot + direction * length * 0.5, 1.5, color)
	elif motion_id == "low":
		for index: int in range(3):
			var trail_start := ground_anchor - direction * (8.0 + float(index) * 7.0) + side * float(index - 1) * 4.0
			canvas.draw_line(trail_start, trail_start - direction * length * fade, Color(color, opacity * (1.0 - float(index) * 0.22)), 2.0)
	else:
		for sign_value: float in [-1.0, 1.0]:
			var air_start := ground_anchor + side * 8.0 * sign_value - direction * 5.0
			canvas.draw_arc(air_start, length * 0.45, -0.8, 0.8, 5, color, 1.0)


func surface_style_at(layout: SanctumCampusLayout, point: Vector2) -> String:
	var ordered: Array[String] = layout.districts_by_id.keys()
	ordered.sort()
	for district_id: String in ordered:
		var district: Dictionary = layout.districts_by_id[district_id]
		if SanctumCampusLayout._parse_bounds(district.get("bounds", [])).has_point(Vector2i(point.round())):
			return String(district.get("style", "nexus"))
	return "nexus"


func receiving_surface_id_at(layout: SanctumCampusLayout, point: Vector2, ground_family: String = "") -> String:
	# The live floor owns material registration at the canonical hex center.
	# District rectangles overlap and include water, soil and paved routes, so
	# their names alone cannot choose a truthful receiving shadow. Reuse the
	# existing profiles; omitted or unknown families keep the legacy fallback.
	match ground_family:
		"water": return "water"
		"grass": return "garden"
		"earth": return "proving"
		"paving", "worldbone": return "nexus"
	if layout == null:
		return "water"
	var ordered: Array[String] = layout.districts_by_id.keys()
	ordered.sort()
	for district_id: String in ordered:
		var district: Dictionary = layout.districts_by_id[district_id]
		if SanctumCampusLayout._parse_bounds(district.get("bounds", [])).has_point(Vector2i(point.round())):
			return String(district.get("style", "nexus"))
	return "water"


func receiving_shadow_sample(layout: SanctumCampusLayout, point: Vector2, ground_family: String = "") -> Dictionary:
	if language == null or receiving_shadow_profiles.is_empty():
		return {}
	var surface_id := receiving_surface_id_at(layout, point, ground_family)
	var profile: Dictionary = receiving_shadow_profiles.get(surface_id, {})
	if profile.is_empty():
		return {}
	var ramp_id := String(profile.get("ramp", "worldbone"))
	var elevation := layout.elevation_at(Vector2i(point.round())) if layout != null else 0
	return {
		"surface_id": surface_id,
		"elevation": elevation,
		"fill_color": language.ramp_color(ramp_id, int(profile.get("fill_step", 0))),
		"rim_color": language.ramp_color(ramp_id, int(profile.get("rim_step", 3))),
		"opacity_scale": clampf(
			float(profile.get("opacity_scale", 0.82)) + float(elevation) * elevation_shadow_opacity_step,
			0.5,
			1.0,
		),
		"rim_opacity": float(profile.get("rim_opacity", 0.2)),
	}


func _draw_ground_patch(canvas: CanvasItem, position: Vector2, style: String, seed: int, edge: bool) -> void:
	var ramp_id := String((profiles[style] as Dictionary).get("ground_ramp", "warm_stone"))
	var radius := (18.0 if edge else 11.0) + float(seed % 9)
	var points := PackedVector2Array()
	for index: int in range(9):
		var angle := TAU * float(index) / 9.0
		var variation := radius * (0.78 + float((seed >> (index % 16)) & 3) * 0.08)
		points.append(position + Vector2.from_angle(angle) * Vector2(variation, variation * 0.65))
	canvas.draw_colored_polygon(points, Color(language.ramp_color(ramp_id, 1 if style != "garden" else 3), 0.055 if edge else 0.035))


static func smoothed_path(points: PackedVector2Array, passes: int = 1) -> PackedVector2Array:
	if points.size() < 3 or passes <= 0:
		return points.duplicate()
	var closed := points[0].is_equal_approx(points[points.size() - 1])
	var current := points.duplicate()
	for pass_index: int in range(clampi(passes, 0, 2)):
		var output := PackedVector2Array()
		if not closed:
			output.append(current[0])
		var segment_count := current.size() - 1
		for index: int in range(segment_count):
			var start := current[index]
			var finish := current[index + 1]
			output.append(start.lerp(finish, 0.25))
			output.append(start.lerp(finish, 0.75))
		if closed:
			output.append(output[0])
		else:
			output.append(current[current.size() - 1])
		current = output
	return current


func _draw_feature(canvas: CanvasItem, position: Vector2, feature: String, style: String, tick: int, seed: int, reduced: bool, feature_scale: float = 1.0) -> void:
	var breeze := 0.0 if reduced else sin(float(tick + seed % 61) * 0.035) * 1.25
	match feature:
		"grass_tuft":
			for dx: float in [-3.0, 0.0, 3.0]:
				canvas.draw_line(position + Vector2(dx, 3), position + Vector2(dx + breeze, -4.0 - absf(dx) * 0.25), language.ramp_color("garden", 4), 1.0)
		"leaf_pair":
			canvas.draw_line(position + Vector2(-4, 2), position + Vector2(4 + breeze, -3), language.ramp_color("garden", 3), 2.0)
			canvas.draw_circle(position + Vector2(-3, -1), 2.0, language.ramp_color("garden", 4))
			canvas.draw_circle(position + Vector2(4 + breeze, -3), 2.0, language.ramp_color("garden", 2))
		"blossom":
			var petal := language.element_color("light", "bright")
			canvas.draw_rect(Rect2(position + Vector2(-2, 0), Vector2(2, 2)), petal, true)
			canvas.draw_rect(Rect2(position + Vector2(1, -2), Vector2(2, 2)), Color(petal, 0.78), true)
		"small_stone":
			canvas.draw_colored_polygon(PackedVector2Array([position + Vector2(-4, 2), position + Vector2(-2, -2), position + Vector2(3, -3), position + Vector2(5, 1), position + Vector2(2, 3)]), language.ramp_color("worldbone", 3))
			canvas.draw_line(position + Vector2(-1, -2), position + Vector2(3, -2), Color(language.ramp_color("warm_stone", 4), 0.45), 1.0)
		"moss_seam":
			canvas.draw_polyline(PackedVector2Array([position + Vector2(-6, 2), position + Vector2(-2, -1), position + Vector2(2, 1), position + Vector2(6, -2)]), Color(language.ramp_color("garden", 3), 0.42), 2.0)
		"brass_leaf":
			canvas.draw_line(position + Vector2(-4, 2), position + Vector2(4, -2), Color(language.ramp_color("aged_brass", 3), 0.38), 1.0)
		"dry_tuft":
			for dx: float in [-2.0, 1.0, 3.0]:
				canvas.draw_line(position + Vector2(dx, 3), position + Vector2(dx + breeze * 0.4, -3), Color(language.ramp_color("timber", 4), 0.55), 1.0)
		"tree":
			var scale := (0.76 + float(seed % 21) / 100.0) * feature_scale
			canvas.draw_colored_polygon(_ellipse_points(position + Vector2(3, 8) * scale, Vector2(15, 7) * scale), Color(language.ramp_color("garden", 0), 0.48))
			canvas.draw_rect(Rect2(position + Vector2(-3, -1) * scale, Vector2(6, 17) * scale), language.ramp_color("timber", 2), true)
			canvas.draw_circle(position + Vector2(-7 + breeze, -6) * scale, 11.0 * scale, language.ramp_color("garden", 2))
			canvas.draw_circle(position + Vector2(7 + breeze, -7) * scale, 12.0 * scale, language.ramp_color("garden", 3))
			canvas.draw_circle(position + Vector2(breeze, -15) * scale, 12.0 * scale, language.ramp_color("garden", 4))
		"bush", "dry_bush":
			var ramp := "timber" if feature == "dry_bush" else "garden"
			var bush_scale := (0.74 + float(seed % 17) / 100.0) * feature_scale
			canvas.draw_circle(position + Vector2(3, 4) * bush_scale, 8.0 * bush_scale, Color(language.ramp_color("garden", 0), 0.42))
			canvas.draw_circle(position + Vector2(-5 + breeze * 0.4, 0) * bush_scale, 7.0 * bush_scale, language.ramp_color(ramp, 2))
			canvas.draw_circle(position + Vector2(5 + breeze * 0.4, -1) * bush_scale, 8.0 * bush_scale, language.ramp_color(ramp, 3))
			canvas.draw_circle(position + Vector2(breeze * 0.4, -6) * bush_scale, 6.0 * bush_scale, language.ramp_color(ramp, 4))


func _validate_district_profile(style: String, value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Natural district profile must be an object: %s" % style)
	var profile: Dictionary = value
	for ramp_key: String in ["ground_ramp", "contact_ramp"]:
		if not language.ramps.has(String(profile.get(ramp_key, ""))):
			return _fail("Natural district profile uses unknown ramp: %s/%s" % [style, ramp_key])
	for density_key: String in ["edge_density", "interior_density"]:
		var density := float(profile.get(density_key, -1.0))
		if density < 0.0 or density > 0.85:
			return _fail("Natural district density is invalid: %s/%s" % [style, density_key])
	var edge_scale := float(profile.get("edge_scale", 0.0))
	if edge_scale < 0.90 or edge_scale > 1.50:
		return _fail("Natural district edge scale is invalid: %s" % style)
	var features: Array = profile.get("features", [])
	if features.size() < 3 or features.size() > 6:
		return _fail("Natural district requires a bounded feature vocabulary: %s" % style)
	for feature: Variant in features:
		if String(feature) not in ALLOWED_FEATURES:
			return _fail("Natural district uses an unknown feature: %s/%s" % [style, feature])
	var edge_props: Array = profile.get("edge_props", [])
	if edge_props.size() < 2 or edge_props.size() > 4:
		return _fail("Natural district requires a bounded edge-prop vocabulary: %s" % style)
	for edge_prop: Variant in edge_props:
		if String(edge_prop) not in ALLOWED_EDGE_PROPS:
			return _fail("Natural district uses an unknown edge prop: %s/%s" % [style, edge_prop])
	return true


func _validate_combat_floor(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Natural map combat-floor language must be an object")
	var profile: Dictionary = value
	var masonry_cell := _vector2i(profile.get("masonry_cell", []))
	if masonry_cell.x < 24 or masonry_cell.x > 64 or masonry_cell.y < 16 or masonry_cell.y > 40 \
		or float(profile.get("masonry_alpha", 0.0)) < 0.03 or float(profile.get("masonry_alpha", 0.0)) > 0.14 \
		or float(profile.get("garden_alpha", 0.0)) < 0.02 or float(profile.get("garden_alpha", 0.0)) > 0.10:
		return _fail("Natural map floor-cell language is unsafe")
	if not profile.get("arena", {}) is Dictionary:
		return _fail("Natural map arena language must be an object")
	var arena: Dictionary = profile["arena"]
	if int(arena.get("outer_inset", 0)) < 8 or int(arena.get("outer_inset", 0)) > 24 \
		or int(arena.get("inner_inset", 0)) < 24 or int(arena.get("inner_inset", 0)) > 48 \
		or int(arena.get("lane_width", 0)) < 56 or int(arena.get("lane_width", 0)) > 104 \
		or int(arena.get("safe_pocket_radius", 0)) < 36 or int(arena.get("safe_pocket_radius", 0)) > 72 \
		or int(arena.get("marker_count", 0)) < 8 or int(arena.get("marker_count", 0)) > int((data.get("budgets", {}) as Dictionary).get("maximum_arena_marks", 0)) \
		or float(arena.get("outline_alpha", 0.0)) < 0.20 or float(arena.get("outline_alpha", 0.0)) > 0.50:
		return _fail("Natural map arena readability profile is unsafe")
	return true


static func _vector2i(values: Variant) -> Vector2i:
	if not values is Array or (values as Array).size() != 2:
		return Vector2i.ZERO
	return Vector2i(int((values as Array)[0]), int((values as Array)[1]))


static func _hash_cell(x: int, y: int, seed: int) -> int:
	var value := (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16))


static func _ellipse_points(center: Vector2, radii: Vector2, segments: int = 12) -> PackedVector2Array:
	var output := PackedVector2Array()
	for index: int in range(segments):
		var angle := TAU * float(index) / float(segments)
		output.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return output


func _fail(message: String) -> bool:
	last_error = message
	return false
