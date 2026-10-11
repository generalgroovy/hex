class_name PixelSpellEffects
extends RefCounted

# Rendering only. A material frame never determines attack admission or coverage.
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const Geometry = preload("res://src/presentation/pixel_effect_geometry.gd")
const FootprintPresenter = preload("res://src/presentation/element_chemistry_presenter.gd")
const Glyph = preload("res://src/presentation/element_glyph_renderer.gd")
const ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const MAX_FIELD_STAMPS := 64
const MAX_SPRAY_STAMPS := 24
const MAX_TAIL_SCALE := 1.5
const MAX_IMPACT_SCALE := 3.0
const IMPACT_READABILITY_SCALE := 1.50
const IMPACT_IMPRINT_TICKS := 18 # Retained as a historical capture checkpoint; no borrowed looped stamp.
const TERMINAL_CONTACT_TICKS := 36
const CORE_SEGMENTS := 32
const SECTOR_SEGMENTS := 12
const CORE_LIGHT_DIRECTION := Vector2(-0.70710678, -0.70710678)
# Six normalized templates cover all 63 mixtures. No position, paid state or
# changing strength is retained, and shrinking cannot change the tessellation.
static var _sector_templates: Dictionary = {}
var library: RefCounted
var geometry := Geometry.new()
var collision: CollisionWorld
var material_footprint := FootprintPresenter.new()


static func mixture_elements(mask: int) -> Array[String]:
	var result: Array[String] = []
	if mask <= 0 or mask > 63: return result
	for wire: int in ElementRules.WIRE_IDS:
		if mask & int(ElementRules.MASK_BY_WIRE[wire]): result.append(ElementRules.id_from_wire(wire))
	return result


static func mixture_sectors(mask: int, center: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var elements := mixture_elements(mask)
	if elements.is_empty() or not center.is_finite() or not is_finite(radius) or radius <= 0.0: return result
	var templates := _templates_for(elements.size())
	for index: int in elements.size():
		var template: Dictionary = templates[index]
		var points := PackedVector2Array()
		for point: Vector2 in template.points: points.append(center + point * radius)
		var surface_points := points.duplicate()
		if elements.size() == 1: surface_points.append(center)
		result.append({"element": elements[index], "points": points, "start": template.start, "end": template.end,
			"glyph_anchor": center + (template.glyph_unit as Vector2) * radius,
			"surface_points": surface_points, "indices": (template.indices as PackedInt32Array).duplicate(),
			"material_offsets": (template.material_offsets as PackedVector2Array).duplicate(),
			"lighting": (template.lighting as PackedFloat32Array).duplicate(),
			"material_colors": (template.material_colors as PackedColorArray).duplicate()})
	return result


static func mixture_layout(mask: int, center: Vector2, radius: float) -> Array[Dictionary]:
	# Hand arcs and Mantle glyphs do not submit a filled material body. Share the
	# identity/layout without allocating detached triangle, UV or color arrays.
	var result: Array[Dictionary] = []
	var elements := mixture_elements(mask)
	if elements.is_empty() or not center.is_finite() or not is_finite(radius) or radius <= 0.0: return result
	var templates := _templates_for(elements.size())
	for index: int in elements.size():
		var template: Dictionary = templates[index]
		result.append({"element": elements[index], "start": template.start, "end": template.end,
			"glyph_anchor": center + (template.glyph_unit as Vector2) * radius})
	return result


static func _templates_for(count: int) -> Array[Dictionary]:
	if count < 1 or count > 6: return []
	if _sector_templates.has(count): return _sector_templates[count]
	var templates: Array[Dictionary] = []
	for index: int in count:
		var start := -PI * 0.5 + TAU * float(index) / float(count)
		var end := -PI * 0.5 + TAU * float(index + 1) / float(count)
		var points := PackedVector2Array()
		if count == 1:
			for step: int in CORE_SEGMENTS: points.append(Vector2.from_angle(TAU * float(step) / float(CORE_SEGMENTS)))
		else:
			points.append(Vector2.ZERO)
			for step: int in SECTOR_SEGMENTS + 1: points.append(Vector2.from_angle(lerpf(start, end, float(step) / float(SECTOR_SEGMENTS))))
		var surface := points.duplicate()
		var indices := PackedInt32Array()
		if count == 1:
			surface.append(Vector2.ZERO)
			for step: int in CORE_SEGMENTS: indices.append_array(PackedInt32Array([CORE_SEGMENTS, step, (step + 1) % CORE_SEGMENTS]))
		else:
			for step: int in SECTOR_SEGMENTS: indices.append_array(PackedInt32Array([0, step + 1, step + 2]))
		var lighting := PackedFloat32Array()
		var material_offsets := PackedVector2Array()
		var material_colors := PackedColorArray()
		for point: Vector2 in surface:
			var light := clampf(0.96 - point.length_squared() * 0.54 + point.dot(CORE_LIGHT_DIRECTION) * 0.24, 0.0, 1.0)
			lighting.append(light)
			material_offsets.append(point * 8.0)
			var value := 0.64 + light * 0.36
			material_colors.append(Color(value, value, value, 0.72))
		var template := {"points": points, "indices": indices, "start": start, "end": end,
			"glyph_unit": Vector2.from_angle((start + end) * 0.5) * (0.58 if count > 1 else 0.0),
			"lighting": lighting, "material_offsets": material_offsets, "material_colors": material_colors}
		template.make_read_only()
		templates.append(template)
	templates.make_read_only()
	_sector_templates[count] = templates
	return templates


static func projectile_depth_model(model: Dictionary) -> Dictionary:
	if not model.get("center") is Vector2 or bool(model.get("mantle", false)): return {}
	var center: Vector2 = model.center
	var radius := float(model.get("core_radius", 0.0))
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0: return {}
	# Lift an inset painted body, never the projectile or its contact marks.
	# The body plus offset and every shadow vertex remain inside the old core.
	var lift := minf(3.0, radius * 0.18)
	var shadow := PackedVector2Array()
	var template: Dictionary = _templates_for(1)[0]
	for point: Vector2 in template.points:
		shadow.append(center + Vector2(point.x * 0.82, 0.45 + point.y * 0.25) * radius)
	shadow.append(center + Vector2(0, radius * 0.45))
	return {"center": center - Vector2(0, lift), "radius": radius - lift, "lift": lift, "shadow": shadow,
		"shadow_indices": (template.indices as PackedInt32Array).duplicate()}


static func material_geometry_stats() -> Dictionary:
	return {"template_sets": _sector_templates.size(), "maximum_template_sets": 6,
		"core_segments": CORE_SEGMENTS, "sector_segments": SECTOR_SEGMENTS}


static func expanded_projectile_model(shot: ProjectileState, definition: Dictionary, position: Vector2, config: SimConfig, owner: PlayerState = null, reduced: bool = false) -> Dictionary:
	if shot == null or config == null or not config.is_valid() or not position.is_finite() or shot.lifetime_ticks <= 0 or shot.radius <= 0: return {}
	if String(definition.get("shape", "")) != "projectile": return {}
	var mask := int(definition.get("element_mask", 0))
	var family := String(definition.get("family", ""))
	if mixture_elements(mask).is_empty() or family not in MixtureCatalog.FAMILIES: return {}
	if shot.initial_strength > 0 and shot.remaining_strength <= 0: return {}
	var radius := float(shot.radius) / SimConfig.FIXED_SCALE
	var center := position
	var armed := family == "fuse" and shot.delivery_phase == 1
	var mantle := family == "mantle"
	if armed:
		position = Vector2(shot.position_x, shot.position_y) / SimConfig.FIXED_SCALE
		center = position # A planted warning never interpolates back along its flight.
	if (mantle or armed) and shot.delivery_damage_remaining <= 0: return {}
	if mantle and owner != null:
		if owner.entity_id != shot.owner_id or owner.health <= 0: return {}
		center -= Vector2(0, float(JumpPresentation.sample(owner, config, 0.0, reduced).body_lift_pixels))
	var strength_ratio := clampf(float(shot.remaining_strength) / maxi(1, shot.initial_strength), 0.0, 1.0) if shot.initial_strength > 0 else 1.0
	var core_radius := radius if mantle else maxf(minf(3.0, radius), radius * sqrt(strength_ratio))
	var direction := ProjectilePresentationMotion.travel_direction(shot)
	var delay := config.milliseconds_to_ticks(600)
	var lifetime := config.milliseconds_to_ticks(int(definition.get("lifetime_ms", 0)))
	return {"family": family, "mask": mask, "elements": mixture_elements(mask), "center": center,
		"ground_center": position, "radius": radius, "core_radius": core_radius, "direction": direction,
		"armed": armed, "mantle": mantle, "split_parent": family == "split" and shot.delivery_phase == 0,
		"split_child": family == "split" and shot.delivery_phase == 2, "bounces": clampi(shot.remaining_bounces, 0, 2),
		"warning_radius": float(definition.get("blast_radius", 0)) / SimConfig.FIXED_SCALE if armed else 0.0,
		"countdown_ratio": clampf(float(shot.delivery_ticks) / maxi(1, delay), 0.0, 1.0) if armed else 0.0,
		"pool_ratio": clampf(float(shot.delivery_damage_remaining) / maxi(1, int(definition.get("damage", 0))), 0.0, 1.0) if mantle or armed else 0.0,
		"remaining_ratio": clampf(float(shot.lifetime_ticks) / maxi(1, lifetime), 0.0, 1.0),
		"age": maxi(0, lifetime - shot.lifetime_ticks), "protection": false, "reduced": reduced}


static func mixed_spray_model(cue: Dictionary, definition: Dictionary, reduced: bool) -> Dictionary:
	var elements := mixture_elements(int(definition.get("element_mask", 0)))
	var raw: Variant = cue.get("spray_geometry")
	if elements.is_empty() or String(definition.get("shape", "")) != "spray" or not raw is Dictionary: return {}
	var source: Dictionary = raw
	if not source.get("start") is Vector2 or not source.get("endpoints") is PackedVector2Array or not source.get("brace") is PackedVector2Array: return {}
	var start: Vector2 = source.start
	var endpoints: PackedVector2Array = source.endpoints
	var brace: PackedVector2Array = source.brace
	if not start.is_finite() or endpoints.size() != 5 or brace.size() != 2: return {}
	var duration := float(cue.get("duration", 0.0))
	var remaining := float(cue.get("remaining", 0.0))
	if not is_finite(duration) or not is_finite(remaining) or duration <= 0.0 or remaining <= 0.0: return {}
	var segments: Array[Dictionary] = []
	for ray: int in ([0, 2, 4] if reduced else [0, 1, 2, 3, 4]):
		var endpoint := endpoints[ray]
		if not endpoint.is_finite() or start.distance_to(endpoint) > float(definition.get("range", 0)) / 1000.0 + 0.001: return {}
		if endpoint == start: continue # Observer/cover sentinel remains invisible.
		for index: int in elements.size():
			segments.append({"start": start.lerp(endpoint, float(index) / float(elements.size())),
				"end": start.lerp(endpoint, float(index + 1) / float(elements.size())), "element": elements[index], "ray": ray})
	return {"segments": segments, "opacity": clampf(remaining / duration, 0.0, 1.0),
		"brace": brace.duplicate(), "start": start, "mask": int(definition.element_mask),
		"origin_visible": brace[0].is_finite() and brace[1].is_finite() and brace[0] != brace[1]}


static func fuse_countdown_model(model: Dictionary) -> Dictionary:
	if not bool(model.get("armed", false)) or not model.get("center") is Vector2: return {}
	var center: Vector2 = model.center
	var radius := float(model.get("radius", 0.0))
	var remaining := float(model.get("countdown_ratio", 0.0))
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0 or not is_finite(remaining): return {}
	var track := Rect2(center + Vector2(-16.0, radius + 7.0), Vector2(32.0, 6.0))
	return {"track": track, "fill": Rect2(track.position, Vector2(track.size.x * clampf(remaining, 0.0, 1.0), track.size.y))}


func draw_expanded_projectile(canvas: CanvasItem, model: Dictionary, language: VisualLanguage) -> bool:
	if canvas == null or model.is_empty() or language == null: return false
	var center: Vector2 = model.center
	var floor_center: Vector2 = model.ground_center
	var radius := float(model.radius)
	var core_radius := float(model.core_radius)
	var elements: Array = model.elements
	var bright := language.element_color(String(elements[0]), "bright")
	# The southeast inset shade and northwest light are shared with wall relief.
	# No camera motion, synthetic trajectory, extra projectile or collision shift.
	if bool(model.armed):
		var warning := geometry.disk_mask(floor_center, float(model.warning_radius), collision)
		for polygon: PackedVector2Array in warning.get("polygons", []): canvas.draw_colored_polygon(polygon, Color(bright, 0.055))
		for boundary: PackedVector2Array in warning.get("boundaries", []):
			canvas.draw_polyline(boundary, Color(0.025, 0.03, 0.03, 0.90), 3.0)
			canvas.draw_polyline(boundary, Color(bright, 0.80), 1.0)
	if bool(model.mantle):
		var covered := geometry.disk_mask(floor_center, radius, collision)
		var lift := center - floor_center
		if lift.length_squared() > 0.0:
			var shadow := PackedVector2Array()
			for index: int in 24: shadow.append(floor_center + Vector2.from_angle(TAU * float(index) / 24.0) * Vector2(radius * 0.68, radius * 0.20))
			canvas.draw_colored_polygon(shadow, Color(0.02, 0.03, 0.03, 0.20))
		for boundary: PackedVector2Array in covered.get("boundaries", []):
			var elevated := PackedVector2Array()
			for point: Vector2 in boundary: elevated.append(point + lift)
			canvas.draw_polyline(elevated, Color(0.035, 0.045, 0.045, 0.85), 3.0)
			canvas.draw_polyline(elevated, Color(bright, 0.62), 1.0)
		for sector: Dictionary in mixture_layout(int(model.mask), center, radius * 0.75):
			Glyph.draw(canvas, language, sector.glyph_anchor, sector.element, 4.0, language.element_color(sector.element, "bright"))
		for index: int in 4:
			var at := center + Vector2(float(index) * 5.0 - 9.0, radius * 0.60)
			canvas.draw_rect(Rect2(at, Vector2(4, 2)), Color(bright, 0.95 if float(index) < float(model.pool_ratio) * 4.0 else 0.16))
		return true
	var depth := projectile_depth_model(model)
	if depth.is_empty(): return false
	var body_center: Vector2 = depth.center
	var body_radius := float(depth.radius)
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), depth.shadow_indices, depth.shadow,
		PackedColorArray([Color(0.018, 0.025, 0.025, 0.38)]), PackedVector2Array(), PackedInt32Array(), PackedFloat32Array())
	for sector: Dictionary in mixture_sectors(int(model.mask), body_center, body_radius):
		var color := language.element_color(sector.element, "base")
		var shade := color.darkened(0.56)
		var light := color.lightened(0.18)
		var colors := PackedColorArray()
		for weight: float in sector.lighting: colors.append(Color(shade.lerp(light, weight), 0.92))
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), sector.indices, sector.surface_points,
			colors, PackedVector2Array(), PackedInt32Array(), PackedFloat32Array())
		_draw_mixture_material(canvas, sector, int(model.age), bool(model.reduced))
		if core_radius >= 9.0:
			Glyph.draw(canvas, language, sector.glyph_anchor, sector.element, minf(3.5, core_radius * 0.16), language.element_color(sector.element, "bright"))
	canvas.draw_arc(body_center, body_radius * 0.85, -2.75, -0.65, 14, Color(0.93, 0.94, 0.86, 0.78), 1.0)
	canvas.draw_arc(body_center, body_radius * 0.85, 0.20, 1.80, 12, Color(0.025, 0.03, 0.04, 0.68), minf(2.0, body_radius * 0.15))
	_draw_delivery_mark(canvas, model, bright, body_center, body_radius)
	if bool(model.armed):
		# A separate monochrome clock stays legible beneath mixed ingredient glyphs.
		# This small UI meter is not coverage: only the unchanged clipped outer
		# warning describes blast reach. Reduced effects retains the same deadline.
		var countdown := fuse_countdown_model(model)
		if not countdown.is_empty():
			var track: Rect2 = countdown.track
			var ink := Color("10181d")
			canvas.draw_rect(track.grow(2.0), ink)
			canvas.draw_rect(track.grow(1.0), Color("cbd1cb"))
			canvas.draw_rect(track, Color("38424a"))
			var fill: Rect2 = countdown.fill
			if fill.size.x > 0.0: canvas.draw_rect(fill, Color("fff0bd"))
			for division: int in [1, 2, 3]:
				canvas.draw_rect(Rect2(track.position + Vector2(float(division) * 8.0 - 0.5, 0.0), Vector2(1.0, track.size.y)), ink)
	# Physical contacts remain visible at their immutable radius even when the
	# material core shrinks with its remaining strength.
	for axis: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		canvas.draw_line(center + axis * (radius - 1.0), center + axis * radius, Color(bright, 0.90), 1.0)
	return true


func _draw_mixture_material(canvas: CanvasItem, sector: Dictionary, age: int, reduced: bool) -> void:
	if not ready(): return
	var frame: Dictionary = library.sample(asset_id(String(sector.element), "flight", reduced), age)
	var texture := frame.get("texture") as Texture2D
	if texture == null or not frame.get("region") is Rect2: return
	var source: Rect2 = frame.region
	var pivot: Vector2 = frame.get("pivot", frame.get("pivot_px", Vector2.ZERO))
	var uvs := PackedVector2Array()
	# Unit offsets are independent of world position and changing paid strength.
	# Avoid both distant-coordinate UV jitter and a triangulation for every draw.
	for offset: Vector2 in sector.material_offsets: uvs.append((source.position + pivot + offset) / texture.get_size())
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), sector.indices, sector.surface_points,
		sector.material_colors, uvs, PackedInt32Array(), PackedFloat32Array(), texture.get_rid())


static func _draw_delivery_mark(canvas: CanvasItem, model: Dictionary, bright: Color, center: Vector2, body_radius: float) -> void:
	var radius := body_radius * 0.60
	var direction: Vector2 = model.direction
	if direction.length_squared() <= 0.0: direction = Vector2.UP
	var side := direction.orthogonal()
	var ink := Color(0.025, 0.035, 0.035, 0.95)
	var strokes: Array[PackedVector2Array] = []
	match String(model.family):
		"split":
			if bool(model.split_parent):
				strokes.append(PackedVector2Array([center - direction * radius, center, center + (direction + side) * radius * 0.65]))
				strokes.append(PackedVector2Array([center, center + (direction - side) * radius * 0.65]))
			else: strokes.append(PackedVector2Array([center - side * radius, center + direction * radius, center + side * radius]))
		"fuse":
			strokes.append(PackedVector2Array([center + Vector2(-radius, -radius), center + Vector2(radius, -radius), center + Vector2(radius, radius), center + Vector2(-radius, radius), center + Vector2(-radius, -radius)]))
		"rebound":
			strokes.append(PackedVector2Array([center - direction * radius, center + side * radius * 0.6, center + direction * radius]))
			for index: int in int(model.bounces): canvas.draw_circle(center - side * radius * 0.60 + direction * float(index * 4 - 2), 1.2, bright)
		"heavy":
			strokes.append(PackedVector2Array([center - direction * radius, center + side * radius, center + direction * radius, center - side * radius, center - direction * radius]))
		"spray":
			for angle: float in [-0.40, 0.0, 0.40]: strokes.append(PackedVector2Array([center - direction * radius * 0.5, center + direction.rotated(angle) * radius]))
		_:
			strokes.append(PackedVector2Array([center - side * radius * 0.45, center + direction * radius, center + side * radius * 0.45]))
	for stroke: PackedVector2Array in strokes:
		canvas.draw_polyline(stroke, ink, 3.0)
		canvas.draw_polyline(stroke, bright, 1.0)


func _init(shared_library: RefCounted = null) -> void:
	library = shared_library if shared_library != null else Library.default_library()


func ready() -> bool:
	return library != null and library.asset_count() > 0


func begin_frame(_config: SimConfig, collision_world: CollisionWorld) -> void:
	collision = collision_world


static func asset_id(element: String, effect: String, reduced: bool) -> String:
	return Library.element_asset_id(ELEMENTS.find(element) + 1, effect, reduced)


static func lifetime_age(lifetime_ms: int, remaining_ticks: int) -> int:
	return maxi(0, ceili(float(lifetime_ms) * 0.12) - remaining_ticks)


static func accepted_release(event: Dictionary) -> Dictionary:
	var kind := String(event.get("type",""))
	if kind not in ["projectile_spawned","field_spawned","beam_fired","spray_fired"]:
		return {}
	if kind == "projectile_spawned" and int(event.get("lane_index",0)) != 0:
		return {} # One bare-hand release per real cast, not one per Burst lane.
	var owner_id := int(event.get("owner_id",0))
	var wire_id := int(event.get("source_wire_id",event.get("wire_id",0)))
	if owner_id <= 0 or wire_id <= 0:
		return {}
	# Optical continuations share this key; caller deduplicates within the same
	# accepted simulation tick and attaches to that owner's current hand anchor.
	return {"owner_id":owner_id,"wire_id":wire_id,"dedup_key":"%d:%d" % [owner_id,wire_id]}


func material_color(element: String, index: int = 3) -> Color:
	var entry: Dictionary = library.asset(asset_id(element,"field_tile",false))
	var palette: Array = entry.get("palette_rgba",[])
	return Color(String(palette[index])) if palette.size() > index else Color("cddbc9")


func flight(canvas: CanvasItem, element: String, position: Vector2, _direction: Vector2, radius: float, age: int, reduced: bool) -> bool:
	if not ready() or element not in ELEMENTS or radius <= 0.0 or age < 0:
		return false
	var scale := radius / 8.0 # Authored core envelope is 16 px, not its 32 px gutter cell.
	return library.draw_stamp(canvas, asset_id(element, "flight", reduced), position, age, 0.0, 1.0, scale)


static func flight_tail_profile(element: String, position: Vector2, direction: Vector2, radius: float, reduced: bool) -> Dictionary:
	if element not in ELEMENTS or not position.is_finite() or not direction.is_finite() or not is_finite(radius) or radius <= 0.0 or direction.length_squared() <= 0.0:
		return {}
	# Reduced mode keeps a short heading cue, not a second projectile. The
	# upright material core and real collision radius are never rotated/resized.
	return {"asset_id": asset_id(element, "flight_tail", reduced),
		"anchor": position - direction.normalized() * radius, "angle": direction.angle(),
		"opacity": 0.24 if reduced else 0.32, "scale": minf(radius / 8.0, MAX_TAIL_SCALE) * (0.60 if reduced else 1.0)}


func hand(canvas: CanvasItem, element: String, position: Vector2, age: int, reduced: bool, effect: String = "hand_prepare") -> bool:
	return ready() and library.draw_stamp(canvas, asset_id(element, effect, reduced), position, age)


func impact(canvas: CanvasItem, element: String, position: Vector2, age: int, reduced: bool, radius: float = 8.0) -> bool:
	if canvas == null or not ready() or not position.is_finite() or age < 0 or impact_profile(element, radius, reduced).is_empty():
		return false
	var model := impact_model(element, position, age, reduced, radius)
	if model.is_empty():
		# A valid expired contact is handled without drawing. Returning false here
		# would resurrect legacy fallback artwork in FoundationSpellPresenter.
		return true
	var profile: Dictionary = model.breakup
	var sample_age: int = model.sample_age_ticks
	# The authored contact now contains its own full material bloom. One guaranteed
	# finite stamp keeps that identity at zero optional budget without borrowing
	# a looping flight core or overdrawing a duplicate contact silhouette.
	library.draw_stamp(canvas, profile.asset_id, position, sample_age, 0.0, model.render_opacity, model.render_scale)
	return true


func impact_model(element: String, position: Vector2, age: int, reduced: bool, radius: float = 8.0) -> Dictionary:
	var profile := impact_profile(element, radius, reduced)
	if not ready() or profile.is_empty() or not position.is_finite() or age < 0:
		return {}
	# Only the nonlooping contact is sampled. No flight loop can revive expiry.
	var duration := impact_duration_ticks(int(library.asset(profile.asset_id).get("total_ticks", 0)))
	if age >= duration: return {}
	var sample_age := impact_sample_age(age)
	if library.sample(profile.asset_id, sample_age).is_empty():
		return {}
	var weight := 0 if radius <= 6.0 else (1 if radius <= 18.0 else 2)
	var envelope := impact_envelope(age, duration, weight, reduced)
	return {"breakup": profile, "imprint": {}, "anchor": position, "age_ticks": age, "sample_age_ticks": sample_age,
		"weight": weight, "render_scale": minf(MAX_IMPACT_SCALE, float(profile.scale) * envelope.x),
		"render_opacity": float(profile.opacity) * envelope.y}


static func impact_envelope(age: int, duration: int, weight: int, reduced: bool) -> Vector2:
	# One finite material stamp: brisk tap / firm burst / weighty bloom, then
	# settle. This only animates VFX, never bodies, collision or attack coverage.
	# Keep the existing authored sequence and expiry; no extra timer or particle.
	if age < 0 or duration <= 0 or age >= duration or weight < 0 or weight > 2:
		return Vector2.ZERO
	var phase := float(age) / float(duration)
	var opacity := 1.0 - 0.45 * phase * phase
	if reduced:
		return Vector2(1.0, opacity) # Same information/size, no scale pulse.
	var peak_age := minf(float(duration) * 0.25, float(2 + weight * 2))
	var attack := clampf(float(age) / maxf(1.0, peak_age), 0.0, 1.0)
	var settle := clampf((float(age) - peak_age) / maxf(1.0, float(duration) - peak_age), 0.0, 1.0)
	var scale := lerpf(0.84, 1.08, attack * (2.0 - attack))
	return Vector2(lerpf(scale, 0.94, settle * settle), opacity)


static func impact_sample_age(age: int) -> int:
	# Finite 1.5x playback, not a looping ghost or an extended damage window.
	return floori(float(age) * 2.0 / 3.0)


static func impact_duration_ticks(authored_ticks: int) -> int:
	return ceili(float(maxi(0, authored_ticks)) * 1.5)


static func impact_profile(element: String, radius: float, reduced: bool) -> Dictionary:
	if element not in ELEMENTS or not is_finite(radius) or radius <= 0.0:
		return {}
	# Expand only the short contact sprite, never a persistent area or damage mask.
	# The finite contact envelope remains cosmetic and does not resize matter.
	return {"asset_id": asset_id(element, "impact", reduced), "opacity": 0.95 if reduced else 1.0,
		"scale": clampf(radius / 8.0 * IMPACT_READABILITY_SCALE, 0.75, MAX_IMPACT_SCALE)}


static func spray_polygon(start: Vector2, endpoint: Vector2, cosine_squared: int) -> PackedVector2Array:
	var lane := endpoint - start
	var points := PackedVector2Array()
	if lane.length_squared() <= 0.0:
		return points
	var half_angle := acos(sqrt(clampf(float(cosine_squared) / 1000000.0, 0.0, 1.0)))
	points.append(start)
	for index: int in range(25):
		points.append(start + Vector2.from_angle(lane.angle() - half_angle + half_angle * 2.0 * float(index) / 24.0) * lane.length())
	return points


func beam(canvas: CanvasItem, element: String, start: Vector2, endpoint: Vector2, radius: float, age: int, reduced: bool, opacity: float) -> bool:
	if not ready() or element not in ELEMENTS:
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lane := endpoint - start
	if lane.length_squared() <= 0.0 or radius <= 0.0:
		return true
	var direction := lane.normalized()
	var side := direction.orthogonal() * radius
	var mask := PackedVector2Array([start-side, endpoint-side, endpoint+side, start+side])
	var frame: Dictionary = library.sample(asset_id(element, "beam_body", reduced), age)
	for index: int in range(ceili(lane.length() / 16.0)):
		Geometry.draw_clipped_frame(canvas, frame, start + direction * float(index * 16), [mask], opacity, lane.angle())
	for cap: String in ["beam_start", "beam_end"]:
		var cap_frame: Dictionary = library.sample(asset_id(element, cap, reduced), age)
		Geometry.draw_clipped_frame(canvas, cap_frame, start if cap == "beam_start" else endpoint, [mask], opacity)
	# These two one-pixel rails are information, not the magic material.
	canvas.draw_line(start-side, endpoint-side, Color(material_color(element), opacity * 0.85), 1.0, false)
	canvas.draw_line(start+side, endpoint+side, Color(material_color(element), opacity * 0.85), 1.0, false)
	return true


func spray(canvas: CanvasItem, element: String, start: Vector2, endpoint: Vector2, cosine_squared: int, age: int, reduced: bool, opacity: float, clearance_radius: float = 0.0) -> bool:
	if not ready() or element not in ELEMENTS:
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mask := spray_polygon(start, endpoint, cosine_squared)
	if mask.is_empty():
		return true
	var bounds := Rect2(start,Vector2.ZERO)
	for point: Vector2 in mask:
		bounds = bounds.expand(point)
	var clipped: Dictionary = geometry.clip_spell_mask([mask],start,bounds,collision,clearance_radius)
	var polygons: Array = clipped.get("polygons",[])
	if polygons.is_empty():
		return true
	var frame: Dictionary = library.sample(asset_id(element, "spray_grain", reduced), age)
	_draw_occupied_material(canvas, frame, clipped, opacity * 0.9)
	var lane := endpoint - start
	var half_angle := acos(sqrt(clampf(float(cosine_squared) / 1000000.0, 0.0, 1.0)))
	var count := 12 if reduced else MAX_SPRAY_STAMPS
	for index: int in range(count):
		if not library.take_decoration(asset_id(element,"spray_grain",reduced)):
			break
		# Stable sparse rays with continuous outward phase; no invented extra hits.
		var ray := -0.88 + float(index % 5) * 0.44
		var distance_ratio := fmod(float(index) * 0.381966 + float(age) / 36.0, 1.0)
		var anchor := start + lane.rotated(ray * half_angle) * distance_ratio
		Geometry.draw_clipped_frame(canvas, frame, anchor, polygons, opacity * 0.9)
	return true


func _draw_occupied_material(canvas: CanvasItem, frame: Dictionary, mask: Dictionary, opacity: float) -> int:
	var model := {"frame": frame, "mask": mask, "socket": false}
	var cells := material_footprint.footprint_cells(model)
	var offset: Vector2 = frame.region.position / frame.texture.get_size()
	for cell: Dictionary in cells:
		for part: Dictionary in cell.parts:
			var uvs: PackedVector2Array = part.uvs.duplicate()
			for index: int in range(uvs.size()):
				uvs[index] += offset
			canvas.draw_polygon(part.points, PackedColorArray([Color(1, 1, 1, opacity)]), uvs, frame.texture)
	return cells.size()


func field_model(element: String, center: Vector2, radius: float, age: int, reduced: bool) -> Dictionary:
	if not ready() or element not in ELEMENTS or not center.is_finite() or not is_finite(radius) or radius <= 0.0 or age < 0:
		return {}
	var mask := Geometry.circle_polygon(center, radius)
	var core_asset := asset_id(element, "flight", reduced)
	return {"frame": library.sample(asset_id(element, "field_tile", reduced), age),
		"core_asset_id": core_asset, "core_frame": library.sample(core_asset, age), "polygons": [mask],
		"core_anchor": center, "core_opacity": 0.55 if reduced else 0.72, "material_opacity": 0.10 if reduced else 0.20}


func field(canvas: CanvasItem, element: String, center: Vector2, radius: float, age: int, reduced: bool) -> bool:
	var model := field_model(element, center, radius, age, reduced)
	if canvas == null or model.is_empty():
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mask: PackedVector2Array = model.polygons[0]
	var frame: Dictionary = model.frame
	# The element remains identifiable even after optional density is exhausted.
	# Native flight identity is more legible than sparse tile grains. It is one
	# unscaled32px atlas cell clipped to the same real mask, not another projectile.
	Geometry.draw_clipped_frame(canvas, model.core_frame, center, model.polygons, model.core_opacity)
	_draw_occupied_material(canvas, frame, {"polygons": [mask], "bounds": Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)}, model.material_opacity)
	return true
