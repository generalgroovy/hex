extends RefCounted


# One finite label at the authoritative cue anchor. No actor-following, history,
# trails, damage inference or changes to the owning cue's lifetime/visibility.
const FONT_SIZE := 11
const CONTACT_LIFT := 48.0
const OTHER_LIFT := 24.0
const MAX_DRIFT := 16.0
const SHADOW_OFFSET := Vector2.ONE


static func layout(cue: Dictionary, font: Font, reduced: bool) -> Dictionary:
	var label := String(cue.get("label", ""))
	var anchor_value: Variant = cue.get("position")
	if label.is_empty() or font == null or not anchor_value is Vector2:
		return {}
	var anchor: Vector2 = anchor_value
	var duration := float(cue.get("duration", 0.0))
	var remaining := float(cue.get("remaining", 0.0))
	if not anchor.is_finite() or not is_finite(duration) or not is_finite(remaining) or duration <= 0.0 or remaining <= 0.0:
		return {}
	var opacity := clampf(remaining / duration, 0.0, 1.0)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var contact := String(cue.get("event_type", "")) in ["projectile_hit", "spray_hit", "field_triggered"]
	var lift := CONTACT_LIFT if contact else OTHER_LIFT
	var drift := 0.0 if reduced else (1.0 - opacity) * MAX_DRIFT
	var color: Color = cue.get("color", Color.WHITE)
	return {
		"label": label,
		"baseline": (anchor + Vector2(-width * 0.5, -lift - drift)).round(),
		"opacity": opacity,
		"color": Color(color, color.a * opacity),
	}


static func draw(canvas: CanvasItem, cue: Dictionary, reduced: bool, ink: Color = Color("11181c")) -> void:
	if canvas == null:
		return
	var placement := layout(cue, ThemeDB.fallback_font, reduced)
	if placement.is_empty():
		return
	var baseline: Vector2 = placement.baseline
	# Match the HUD's one-pixel underprint, not an opaque panel over the actor.
	canvas.draw_string(ThemeDB.fallback_font, baseline + SHADOW_OFFSET, placement.label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(ink, ink.a * float(placement.color.a)))
	canvas.draw_string(ThemeDB.fallback_font, baseline, placement.label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, placement.color)
