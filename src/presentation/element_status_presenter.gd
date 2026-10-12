class_name ElementStatusPresenter
extends RefCounted
## Read-only actor badges. These are ailments, never protection or hit volumes.

const Glyph = preload("res://src/presentation/element_glyph_renderer.gd")
const ELEMENTS: Array[String] = ["earth", "fire", "water", "wind", "light", "dark"]
const LABELS: Array[String] = ["FOCUS", "BURN", "CHILL", "GUST", "SEEN", "WITHER"]
const STRIDE := 8
const MAX_BADGES := 6
const BADGE_ROW_Y := -88.0 # Stable clearance above the largest admitted protection crest.


static func model(actor: PlayerState, config: SimConfig, language: VisualLanguage) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if actor == null or actor.health <= 0 or config == null or config.tick_rate <= 0 or language == null or actor.spell_status_values.size() != 48:
		return result
	for channel: int in MAX_BADGES:
		var offset := channel * STRIDE
		var ticks := int(actor.spell_status_values[offset])
		if ticks <= 0: continue
		var element := ELEMENTS[channel]
		if not language.elements.has(element): continue
		var definition := CombatTuning.cast_definition_view(int(actor.spell_status_values[offset + 6]))
		if definition.is_empty() or int(definition.get("element_mask", 0)) & (1 << channel) == 0: continue
		# Attribution can survive a refresh by another spell. Show time on a
		# fixed one-second scale, never an invented fraction of the original hit.
		var duration := maxi(1, config.milliseconds_to_ticks(1000))
		var pool := maxi(0, int(actor.spell_status_values[offset + 2]))
		result.append({"channel": channel, "element": element, "label": LABELS[channel],
			"ticks": ticks, "remaining_ratio": clampf(float(ticks) / float(duration), 0.0, 1.0),
			"seconds_remaining": float(ticks) / float(config.tick_rate), "bar_window_seconds": 1.0,
			"potency": maxi(0, int(actor.spell_status_values[offset + 1])), "damage_remaining": pool,
			"damage_active": channel == 1 and pool > 0, "protection": false,
			"dark": language.element_color(element, "dark"), "base": language.element_color(element, "base"),
			"bright": language.element_color(element, "bright")})
	return result


static func draw(canvas: CanvasItem, actor: PlayerState, screen_pos: Vector2, config: SimConfig, language: VisualLanguage, _reduced: bool = false) -> void:
	if canvas == null or not screen_pos.is_finite(): return
	var badges := model(actor, config, language)
	for index: int in badges.size():
		var badge: Dictionary = badges[index]
		var center := screen_pos + Vector2((float(index) - float(badges.size() - 1) * 0.5) * 15.0, BADGE_ROW_Y)
		# Open corner plates cannot be confused with the closed spawn shield or
		# split body slashes used for actual combat intangibility.
		canvas.draw_rect(Rect2(center - Vector2(6, 7), Vector2(12, 14)), Color(0.025, 0.035, 0.035, 0.90))
		var bright: Color = badge.bright
		if int(badge.channel) == 1 and not bool(badge.damage_active): bright = Color(bright, 0.40)
		Glyph.draw(canvas, language, center - Vector2(0, 1), badge.element, 4.0, bright)
		canvas.draw_line(center + Vector2(-5, 6), center + Vector2(5, 6), Color(badge.dark, 0.95), 2.0)
		canvas.draw_line(center + Vector2(-5, 6), center + Vector2(-5 + 10.0 * float(badge.remaining_ratio), 6), bright, 2.0)
