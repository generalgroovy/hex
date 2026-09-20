class_name ElementGlyphRenderer
extends RefCounted


const TOPOLOGY_BY_SHAPE := {
	"block_fracture": "square_crack",
	"forked_flame": "pointed_fork",
	"curling_wave": "curl_drop",
	"open_spiral": "open_coil",
	"six_point_crystal": "six_spokes",
	"broken_bolt": "offset_zigzag",
	"radiant_diamond": "diamond_cross",
	"inward_crescent": "paired_crescent",
	"double_echo": "twin_rings",
	"broken_orbit": "split_orbit",
	"concentric_weight": "weighted_rings",
	"offset_hour": "offset_hands",
}

# Cadence tokens come from the same validated language as HUD/flight glyphs.
# Periods use the presentation's existing 60-sample clock, never simulation time.
const MATERIAL_BY_CADENCE := {
	"accelerating": {"motif": "ember", "period": 54, "count": 5},
	"flowing": {"motif": "ripple", "period": 108, "count": 3},
	"weighty": {"motif": "block", "period": 144, "count": 4},
	"staccato": {"motif": "stream", "period": 78, "count": 3},
	"snapping": {"motif": "arc", "period": 66, "count": 4},
	"crystalline": {"motif": "facet", "period": 132, "count": 6},
	"measured_pulse": {"motif": "ray", "period": 120, "count": 4},
	"lingering": {"motif": "wisp", "period": 156, "count": 3},
}


static func contract(language: VisualLanguage, element_id: String) -> Dictionary:
	if language == null or not language.elements.has(element_id):
		return {}
	var shape := language.element_shape(element_id)
	if not TOPOLOGY_BY_SHAPE.has(shape):
		return {}
	return {
		"element": element_id,
		"shape": shape,
		"topology": String(TOPOLOGY_BY_SHAPE[shape]),
		"cadence": language.element_cadence(element_id),
	}


static func material_contract(language: VisualLanguage, element_id: String) -> Dictionary:
	var glyph := contract(language, element_id)
	if glyph.is_empty() or not MATERIAL_BY_CADENCE.has(String(glyph["cadence"])):
		return {}
	var result: Dictionary = MATERIAL_BY_CADENCE[String(glyph["cadence"])].duplicate()
	result["element"] = element_id
	result["shape"] = glyph["shape"]
	result["cadence"] = glyph["cadence"]
	return result


static func material_phase(language: VisualLanguage, element_id: String, tick: int, seed: int = 0) -> float:
	var profile := material_contract(language, element_id)
	if profile.is_empty():
		return 0.0
	var period := int(profile["period"])
	return float(posmod(tick + seed * 7, period)) / float(period)


# Relative coordinates are deliberately bounded inside the real field radius.
# This list is shared by persistent fields and finite impact cues; it owns no
# collision, lifetime, persistent objects or random state.
static func material_motifs(language: VisualLanguage, element_id: String, phase: float, remaining: float, reduced_effects: bool) -> Array[Dictionary]:
	var profile := material_contract(language, element_id)
	var result: Array[Dictionary] = []
	if profile.is_empty():
		return result
	var motion := 0.5 if reduced_effects else clampf(phase, 0.0, 1.0)
	var life := clampf(remaining, 0.0, 1.0)
	var count := mini(int(profile["count"]), 3) if reduced_effects else int(profile["count"])
	var motif := String(profile["motif"])
	for index: int in range(count):
		var angle := TAU * float(index) / float(count) - PI * 0.5
		var local_phase := fposmod(motion + float(index) * 0.23, 1.0)
		var offset := Vector2.from_angle(angle) * 0.50
		var size := 0.075
		var alpha := 0.62
		match motif:
			"ember":
				offset += Vector2.UP * local_phase * local_phase * 0.16
				size = 0.055 + (1.0 - local_phase) * 0.025
				alpha = 0.40 + (1.0 - local_phase) * 0.28
			"ripple":
				offset = Vector2.ZERO
				size = 0.27 + float(index) * 0.16 + motion * 0.10
				angle = 0.18 + float(index) * 0.7
				alpha = 0.48 - motion * 0.14
			"block":
				# Settle once at formation, not a repeating bob of solid stone.
				offset += Vector2.UP * maxf(0.0, 1.0 - (1.0 - life) * 8.0) * 0.10
				angle = 0.0
				size = 0.08
			"stream":
				offset = Vector2.ZERO
				size = 0.34 + float(index) * 0.16
				angle += motion * TAU
			"arc":
				alpha = 0.72 if local_phase < 0.25 else 0.30
				size = 0.09
				angle += (0.16 if local_phase < 0.25 else -0.16)
			"facet":
				size = 0.065 + minf((1.0 - life) * 4.0, 1.0) * 0.04
				alpha = 0.42 + sin(motion * PI) * 0.16
			"ray":
				size = 0.075 + (0.5 - 0.5 * cos(motion * TAU)) * 0.045
				alpha = 0.46 + sin(motion * PI) * 0.18
			"wisp":
				offset = Vector2.from_angle(angle - motion * 0.7) * (0.61 - motion * 0.16)
				size = 0.09
				angle -= motion * 0.7
		result.append({"motif": motif, "offset": offset, "size": size, "angle": angle, "alpha": alpha * (0.45 + life * 0.55)})
	return result


static func draw_material_motion(canvas: CanvasItem, language: VisualLanguage, center: Vector2, element_id: String, radius: float, phase: float, remaining: float, reduced_effects: bool, opacity: float = 1.0) -> bool:
	if canvas == null or radius <= 0.0:
		return false
	var motifs := material_motifs(language, element_id, phase, remaining, reduced_effects)
	if motifs.is_empty():
		return false
	for mark: Dictionary in motifs:
		var origin := center + (mark["offset"] as Vector2) * radius
		var size := float(mark["size"]) * radius
		var angle := float(mark["angle"])
		var direction := Vector2.from_angle(angle)
		var side := direction.orthogonal()
		var color := Color(language.element_color(element_id, "bright"), float(mark["alpha"]) * clampf(opacity, 0.0, 1.0))
		match String(mark["motif"]):
			"ember":
				draw(canvas, language, origin, element_id, size, color, Vector2.UP)
			"ripple":
				canvas.draw_arc(origin, size, angle, angle + TAU - 0.62, 24, color, 1.5)
			"block":
				draw(canvas, language, origin, element_id, size, color, Vector2.UP)
			"stream":
				canvas.draw_arc(origin, size, angle, angle + 1.7, 10, color, 2.0)
				canvas.draw_arc(origin, size * 0.90, angle + 0.18, angle + 1.20, 7, Color(color, color.a * 0.6), 1.0)
			"arc":
				canvas.draw_polyline(PackedVector2Array([origin - side * size, origin - direction * size * 0.45, origin + side * size * 0.12, origin + direction * size * 0.45, origin + side * size]), color, 2.0, false)
				canvas.draw_circle(origin - side * size, 1.5, color)
			"facet":
				var facet := PackedVector2Array([origin + direction * size, origin + side * size * 0.55, origin - direction * size, origin - side * size * 0.55])
				canvas.draw_polyline(_closed(facet), color, 1.5, false)
				canvas.draw_line(origin - direction * size, origin + direction * size, Color(color, color.a * 0.7), 1.0)
			"ray":
				canvas.draw_line(origin - direction * size, origin + direction * size, color, 2.0)
				canvas.draw_line(origin - side * size * 0.35, origin + side * size * 0.35, color, 1.5)
			"wisp":
				canvas.draw_arc(origin, size, angle + 0.45, angle + 3.1, 10, color, 2.0)
				canvas.draw_arc(origin - direction * size * 0.25, size * 0.60, angle + 0.65, angle + 2.9, 8, Color(color, color.a * 0.65), 1.0)
	return true


static func draw(canvas: CanvasItem, language: VisualLanguage, center: Vector2, element_id: String, radius: float, color: Color, direction: Vector2 = Vector2.UP) -> bool:
	var glyph := contract(language, element_id)
	if canvas == null or glyph.is_empty() or radius <= 0.0:
		return false
	var forward := direction.normalized() if direction.length_squared() > 0.0 else Vector2.UP
	var side := forward.orthogonal()
	match String(glyph["shape"]):
		"block_fracture":
			var square := PackedVector2Array([center - forward * radius - side * radius, center - forward * radius + side * radius, center + forward * radius + side * radius, center + forward * radius - side * radius])
			canvas.draw_polyline(_closed(square), color, 1.5, false)
			canvas.draw_polyline(PackedVector2Array([center - side * radius * 0.8, center + forward * radius * 0.15, center - forward * radius * 0.2 + side * radius * 0.8]), color, 1.5, false)
		"forked_flame":
			canvas.draw_polyline(PackedVector2Array([center + forward * radius, center - side * radius * 0.55, center - forward * radius * 0.25, center + side * radius * 0.55, center + forward * radius]), color, 1.5, false)
			canvas.draw_line(center - forward * radius * 0.15, center - forward * radius, color, 1.5)
		"curling_wave":
			canvas.draw_arc(center, radius, forward.angle() - 2.55, forward.angle() + 0.55, 10, color, 1.5)
			canvas.draw_circle(center + side * radius * 0.42, radius * 0.22, color)
		"open_spiral":
			canvas.draw_arc(center, radius, forward.angle() - 2.65, forward.angle() + 1.60, 12, color, 1.5)
			canvas.draw_line(center + forward * radius * 0.1, center + forward * radius, color, 1.5)
		"six_point_crystal":
			for index: int in range(6):
				var ray := Vector2.from_angle(forward.angle() + TAU * float(index) / 6.0)
				canvas.draw_line(center, center + ray * radius, color, 1.5)
		"broken_bolt":
			canvas.draw_polyline(PackedVector2Array([center - forward * radius, center - side * radius * 0.72, center + forward * radius * 0.12, center + side * radius * 0.72, center + forward * radius]), color, 1.5, false)
		"radiant_diamond":
			var diamond := PackedVector2Array([center + forward * radius, center + side * radius, center - forward * radius, center - side * radius])
			canvas.draw_polyline(_closed(diamond), color, 1.5, false)
			canvas.draw_line(center - forward * radius * 0.42, center + forward * radius * 0.42, color, 1.5)
			canvas.draw_line(center - side * radius * 0.42, center + side * radius * 0.42, color, 1.5)
		"inward_crescent":
			canvas.draw_arc(center - side * radius * 0.18, radius, forward.angle() - 2.30, forward.angle() + 0.85, 10, color, 1.5)
			canvas.draw_arc(center + side * radius * 0.34, radius * 0.72, forward.angle() - 2.30, forward.angle() + 0.85, 9, color, 1.0)
		"double_echo":
			canvas.draw_arc(center - side * radius * 0.35, radius * 0.65, 0.0, TAU, 10, color, 1.0)
			canvas.draw_arc(center + side * radius * 0.35, radius * 0.65, 0.0, TAU, 10, color, 1.5)
		"broken_orbit":
			canvas.draw_arc(center, radius, -2.6, -0.2, 8, color, 1.5)
			canvas.draw_arc(center, radius, 0.55, 2.3, 7, color, 1.5)
			canvas.draw_circle(center + forward * radius, radius * 0.18, color)
		"concentric_weight":
			canvas.draw_arc(center, radius, 0.0, TAU, 12, color, 1.5)
			canvas.draw_arc(center, radius * 0.48, 0.0, TAU, 10, color, 1.5)
			canvas.draw_line(center + side * radius, center + side * radius * 1.35, color, 2.0)
		"offset_hour":
			canvas.draw_arc(center, radius, 0.0, TAU, 12, color, 1.5)
			canvas.draw_line(center, center + forward * radius * 0.78, color, 1.5)
			canvas.draw_line(center, center + side * radius * 0.55, color, 1.5)
		_:
			return false
	return true


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
