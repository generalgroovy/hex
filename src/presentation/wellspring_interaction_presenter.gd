class_name WellspringInteractionPresenter
extends RefCounted


const DEFAULT_PATH := "res://content/visual/wellspring_interaction_language_v1.json"
const EXPECTED_ID := "wellspring-interaction-language-v1"
const EXPECTED_AUTHORITY := "presentation only; station proximity, commands, authority, social events and outcomes remain owned elsewhere"
const REQUIRED_KINDS := ["guide", "training", "champion", "spell", "farflow", "charter", "hearth", "ledger", "parting", "controls"]
const GLYPHS := ["route", "bell", "mask", "weave", "gate", "scroll", "hearth", "ledger", "keys"]
const COMPACT_PROMPT_HEIGHT := 40.0

var language: VisualLanguage
var data: Dictionary = {}
var styles_by_kind: Dictionary[String, Dictionary] = {}
var content_hash := ""
var last_error := ""
var _notice_message := ""
var _notice_viewport := Vector2.ZERO
var _notice_font: Font
var _notice_cache: Dictionary = {}


func configure(visual_language: VisualLanguage, campus: SanctumCampusLayout, path: String = DEFAULT_PATH) -> bool:
	language = visual_language
	data.clear()
	styles_by_kind.clear()
	content_hash = ""
	last_error = ""
	_notice_cache = {}
	if language == null or campus == null or language.ramps.is_empty() or campus.stations_by_id.is_empty():
		return _fail("Wellspring interaction presentation requires validated visual and campus data")
	if not FileAccess.file_exists(path):
		return _fail("Wellspring interaction presentation does not exist: %s" % path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Wellspring interaction presentation root must be an object")
	data = parsed
	if not validate(campus):
		data.clear()
		return false
	content_hash = source.sha256_text()
	return true


func validate(campus: SanctumCampusLayout) -> bool:
	last_error = ""
	styles_by_kind.clear()
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Wellspring interaction presentation identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Wellspring interaction presentation must remain presentation-only")
	var budgets: Dictionary = data.get("budgets", {})
	if int(budgets.get("station_style_count", 0)) != REQUIRED_KINDS.size() \
		or int(budgets.get("maximum_prompt_width", 0)) < 180 or int(budgets.get("maximum_prompt_width", 0)) > language.ui_metric("prompt_maximum_width") \
		or int(budgets.get("maximum_expanded_width", 0)) < 240 or int(budgets.get("maximum_expanded_width", 0)) > language.ui_metric("prompt_maximum_width") \
		or int(budgets.get("maximum_station_lines", 0)) != int(language.budgets.get("maximum_world_prompt_lines", 3)) * 2 \
		or int(budgets.get("maximum_social_width", 0)) < 96 or int(budgets.get("maximum_social_width", 0)) > 160 \
		or int(budgets.get("maximum_notice_width", 0)) < 300 or int(budgets.get("maximum_notice_width", 0)) > 480 \
		or int(budgets.get("screen_margin", 0)) < 12 or int(budgets.get("screen_margin", 0)) > 32 \
		or int(budgets.get("corner_step", 0)) != language.ui_metric("corner_step") \
		or int(budgets.get("line_height", 0)) < 16 or int(budgets.get("line_height", 0)) > 22:
		return _fail("Wellspring interaction visual budgets are unsafe")
	var layout: Dictionary = data.get("layout", {})
	if int(layout.get("prompt_width", 0)) > int(budgets.get("maximum_prompt_width", 0)) \
		or int(layout.get("expanded_width", 0)) > int(budgets.get("maximum_expanded_width", 0)) \
		or int(layout.get("social_height", 0)) < 28 or int(layout.get("social_height", 0)) > 48 \
		or int(layout.get("notice_height", 0)) < 34 or int(layout.get("notice_height", 0)) > 54 \
		or int(layout.get("station_anchor_lift", 0)) < 40 or int(layout.get("traveller_anchor_lift", 0)) < 52 \
		or int(layout.get("tail_height", 0)) < 6 or int(layout.get("tail_height", 0)) > 14:
		return _fail("Wellspring interaction layout is invalid")
	var style_values: Variant = data.get("station_styles", [])
	if not style_values is Array or (style_values as Array).size() != REQUIRED_KINDS.size():
		return _fail("Wellspring interaction presentation must define every station kind exactly once")
	for value: Variant in style_values:
		if not value is Dictionary:
			return _fail("Wellspring station visual style must be an object")
		var style: Dictionary = value
		var kind := String(style.get("kind", ""))
		var ramp := String(style.get("ramp", ""))
		var ramp_index := int(style.get("ramp_index", -1))
		if kind not in REQUIRED_KINDS or styles_by_kind.has(kind) or String(style.get("glyph", "")) not in GLYPHS \
			or not language.ramps.has(ramp) or ramp_index < 0 or ramp_index > 4:
			return _fail("Wellspring station visual style is invalid: %s" % kind)
		styles_by_kind[kind] = style
	for kind: String in REQUIRED_KINDS:
		if not styles_by_kind.has(kind):
			return _fail("Wellspring interaction presentation is missing station kind: %s" % kind)
	for station: Dictionary in campus.stations_by_id.values():
		if not styles_by_kind.has(String(station.get("kind", ""))):
			return _fail("Live station has no interaction visual: %s" % String(station.get("id", "")))
		if (station.get("lines", []) as Array).size() > int(budgets.get("maximum_station_lines", 0)):
			return _fail("Live station exceeds the interaction line budget: %s" % String(station.get("id", "")))
	return true


func draw_station(
	canvas: CanvasItem,
	viewport_size: Vector2,
	source_anchor: Vector2,
	station: Dictionary,
	lines: Array,
	expanded: bool,
	interact_label: String,
	protected_actor: Rect2 = Rect2(),
) -> void:
	if canvas == null or not styles_by_kind.has(String(station.get("kind", ""))):
		return
	var budgets: Dictionary = data.get("budgets", {})
	var style: Dictionary = styles_by_kind[String(station.get("kind", ""))]
	var accent := language.ramp_color(String(style.get("ramp", "aged_brass")), int(style.get("ramp_index", 3)))
	var line_height := float(budgets.get("line_height", 18))
	var rectangle := station_rect(viewport_size, source_anchor, expanded, lines.size(), protected_actor)
	_draw_tether(canvas, source_anchor, rectangle, accent)
	_draw_parchment_panel(canvas, rectangle, accent, 0.90 if expanded else 0.86)
	var glyph_center := rectangle.position + Vector2(22, 24 if expanded else 20)
	_draw_glyph(canvas, glyph_center, String(style.get("glyph", "route")), accent)
	var key_label := resolved_interact_label(interact_label)
	var key_width := clampf(ThemeDB.fallback_font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14.0, 28.0, 104.0)
	var key_rect := Rect2(rectangle.end.x - key_width - 10.0, rectangle.position.y + (10.0 if expanded else 8.0), key_width, 24.0)
	canvas.draw_rect(key_rect, Color(language.ramp_color("worldbone", 0), 0.86), true)
	canvas.draw_rect(key_rect, Color(accent, 0.90), false, 2.0)
	canvas.draw_string(ThemeDB.fallback_font, key_rect.position + Vector2(0, 16), key_label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, key_rect.size.x, 10, language.ramp_color("parchment", 4))
	var title_width := key_rect.position.x - (rectangle.position.x + 46.0) - 6.0
	var service := WellspringServiceBuildings.definition_for(station)
	var title := String(station.get("title", "STATION")) if expanded else String(service.get("title", station.get("title", "SERVICE")))
	title = String(station.get("directory_title", title))
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(42, 20 if expanded else 24), title, HORIZONTAL_ALIGNMENT_LEFT, title_width + 4.0, 12, language.ramp_color("worldbone", 0))
	if expanded:
		canvas.draw_line(rectangle.position + Vector2(46, 29), Vector2(key_rect.position.x - 6.0, rectangle.position.y + 29), Color(accent, 0.62), 1.0)
		for index: int in range(mini(lines.size(), int(budgets.get("maximum_station_lines", 6)))):
			canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(14, 50 + float(index) * line_height), localized_interaction_line(String(lines[index]), key_label), HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 28.0, 10, language.ramp_color("worldbone", 0))


func station_rect(viewport_size: Vector2, source_anchor: Vector2, expanded: bool, line_count: int = 0, protected_actor: Rect2 = Rect2()) -> Rect2:
	# Shared by draw and hover/focus hit testing: no mismatched invisible cards.
	var layout: Dictionary = data.get("layout", {})
	var budgets: Dictionary = data.get("budgets", {})
	var width := float(layout.get("expanded_width" if expanded else "prompt_width", 296 if expanded else 232))
	var height := COMPACT_PROMPT_HEIGHT
	if expanded:
		height = float(layout.get("expanded_header_height", 46)) + float(budgets.get("line_height", 18)) * float(clampi(line_count, 0, int(budgets.get("maximum_station_lines", 6))))
	var desired := Rect2(source_anchor.x - width * 0.5, source_anchor.y - float(layout.get("station_anchor_lift", 58)) - height, width, height)
	var rectangle := clamped_panel_rect(desired, viewport_size, float(budgets.get("screen_margin", 16)), 126.0)
	if not expanded:
		rectangle = avoid_actor_rect(rectangle, protected_actor, viewport_size, float(budgets.get("screen_margin", 16)))
	return rectangle


static func resolved_interact_label(value: String) -> String:
	var label := value.strip_edges()
	return "Not bound" if label.is_empty() or label == "\u2014" else label


static func practice_station_lines(station: Dictionary, preferences: PlayerPreferences, device: int = ControlBindingEditor.DEVICE_KEYBOARD) -> Array[String]:
	# Practice help follows the controls actually used to enter the directory.
	# Static map copy must not teach an old binding or an obsolete motion rule.
	var command := String(station.get("command", ""))
	if command not in ["movement_guide", "impact_practice"] or preferences == null:
		return []
	var editor := ControlBindingEditor.new()
	if command == "impact_practice":
		var technique := resolved_interact_label(editor.binding_label(&"technique", device, preferences))
		return [
			"Hold direction to bend the launch for free.",
			"Tech %s near landing or during the brace." % technique,
			"Tech: %.1f base Stamina; perks / chain apply." % (float(MovementTuning.IMPACT_RECOVERY_TECH_COST) / SimConfig.FIXED_SCALE),
			"No new protection; keep the exit lane clear.",
			"Without a legal Tech: full %d ms brace." % MovementTuning.IMPACT_RECOVERY_DURATION_MS,
		]
	var jump := resolved_interact_label(editor.binding_label(&"jump", device, preferences))
	var slide := resolved_interact_label(editor.binding_label(&"slide", device, preferences))
	var evade := resolved_interact_label(editor.binding_label(&"evade", device, preferences))
	var wheel_jump := device == ControlBindingEditor.DEVICE_MOUSE and int(preferences.mouse_bindings.get(&"jump", 0)) in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	return [
		"Jump %s: press, then release to launch." % jump,
		"Wheel cannot hold charge, flight or wallrun." if wheel_jump else "Hold Jump to brake for charge; tap keeps speed.",
		"Slide %s at speed; steer to carve or brake." % slide,
		"Brake a slide: release and press %s again." % slide,
		"Air %s: direction dodges; neutral fast-falls." % evade,
		"Wall: hold Jump along it; release to walljump." if wheel_jump else "Wall: hold %s along it; release to walljump." % jump,
	]


static func avoid_actor_rect(panel: Rect2, actor: Rect2, viewport_size: Vector2, margin: float = 16.0) -> Rect2:
	if not actor.has_area() or not panel.intersects(actor):
		return panel
	var positions := [
		Vector2(panel.position.x, actor.position.y - panel.size.y - 10.0),
		Vector2(actor.end.x + 10.0, panel.position.y),
		Vector2(actor.position.x - panel.size.x - 10.0, panel.position.y),
		Vector2(panel.position.x, actor.end.y + 10.0),
	]
	for position: Vector2 in positions:
		var candidate := clamped_panel_rect(Rect2(position, panel.size), viewport_size, margin, 126.0)
		if not candidate.intersects(actor):
			return candidate
	return panel


func notice_layout(viewport_size: Vector2, message: String) -> Dictionary:
	if not viewport_size.is_finite() or viewport_size.x < 180.0 or viewport_size.y < 180.0 or message.strip_edges().is_empty():
		return {}
	var font := ThemeDB.fallback_font
	if not _notice_cache.is_empty() and message == _notice_message and viewport_size == _notice_viewport and font == _notice_font:
		return _notice_cache
	var layout: Dictionary = data.get("layout", {})
	var budgets: Dictionary = data.get("budgets", {})
	var margin := float(budgets.get("screen_margin", 16))
	var width := minf(float(budgets.get("maximum_notice_width", 420)), viewport_size.x - margin * 2.0)
	# Only reshape when content or viewport changes; bound work for network copy.
	var lines := PlayerCompendium.wrap_text(message.left(512), font, width - 54.0, 11)
	if lines.size() > 3 or message.length() > 512:
		lines.resize(mini(lines.size(), 3))
		var tail := lines[-1]
		while not tail.is_empty() and font.get_string_size(tail + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width - 54.0:
			tail = tail.left(-1)
		lines[-1] = tail + "..."
	var height := float(layout.get("notice_height", 42)) + 14.0 * float(lines.size() - 1)
	# At narrow resolutions sit below the left/right top HUD rather than on it.
	var top := margin if viewport_size.x - width >= 672.0 else 60.0
	var rectangle := Rect2(roundf((viewport_size.x - width) * 0.5), top, width, height)
	lines.make_read_only()
	_notice_cache = {"rect": rectangle, "lines": lines}
	_notice_cache.make_read_only()
	_notice_message = message
	_notice_viewport = viewport_size
	_notice_font = font
	return _notice_cache


func draw_notice(canvas: CanvasItem, viewport_size: Vector2, title: String, message: String) -> void:
	if canvas == null:
		return
	var model := notice_layout(viewport_size, message)
	if model.is_empty():
		return
	var rectangle: Rect2 = model.rect
	var accent := language.ramp_color("aged_brass", 4)
	_draw_parchment_panel(canvas, rectangle, accent, 0.88)
	_draw_glyph(canvas, rectangle.position + Vector2(22, rectangle.size.y * 0.5), "bell", accent)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(42, 15), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 54.0, 10, language.ramp_color("parchment", 0))
	for index: int in model.lines.size():
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(42, 30 + index * 14), model.lines[index], HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 54.0, 11, language.ramp_color("worldbone", 0))


func draw_social(canvas: CanvasItem, viewport_size: Vector2, source_anchor: Vector2, speaker: String, message: String, life_ratio: float) -> void:
	if canvas == null:
		return
	var layout: Dictionary = data.get("layout", {})
	var budgets: Dictionary = data.get("budgets", {})
	var safe_message := message.strip_edges()
	if safe_message.is_empty():
		safe_message = String((data.get("copy", {}) as Dictionary).get("social_fallback", "HELLO!"))
	var text_width := ThemeDB.fallback_font.get_string_size(safe_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var speaker_width := ThemeDB.fallback_font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var width := clampf(maxf(text_width + 30.0, speaker_width + 30.0), 92.0, float(budgets.get("maximum_social_width", 132)))
	var height := float(layout.get("social_height", 36))
	var lift := float(layout.get("traveller_anchor_lift", 72))
	var desired := Rect2(source_anchor.x - width * 0.5, source_anchor.y - lift - height, width, height)
	var rectangle := clamped_panel_rect(desired, viewport_size, float(budgets.get("screen_margin", 16)), 122.0)
	var opacity := clampf(life_ratio * 1.8, 0.0, 1.0)
	var accent := language.ramp_color("stamina", 4)
	_draw_tether(canvas, source_anchor, rectangle, Color(accent, opacity))
	_draw_parchment_panel(canvas, rectangle, Color(accent, opacity), 0.78 * opacity)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 12), speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 20.0, 8, Color(language.ramp_color("parchment", 0), opacity))
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 28), safe_message, HORIZONTAL_ALIGNMENT_CENTER, rectangle.size.x - 20.0, 11, Color(language.ramp_color("worldbone", 0), opacity))


static func station_action_text(station: Dictionary) -> String:
	return _without_legacy_interact_prefix(String(station.get("prompt", "INTERACT"))).capitalize()


static func localized_interaction_line(line: String, interact_label: String) -> String:
	var stripped := line.strip_edges()
	var localized := _without_legacy_interact_prefix(stripped)
	if localized != stripped:
		return "%s %s" % [interact_label.to_upper(), localized]
	return stripped


static func _without_legacy_interact_prefix(value: String) -> String:
	var text := value.strip_edges()
	for legacy_key: String in ["F", "E"]:
		if text.begins_with(legacy_key + " "):
			return text.trim_prefix(legacy_key).strip_edges()
	return text


static func clamped_panel_rect(desired: Rect2, viewport_size: Vector2, margin: float, bottom_reserve: float, top_reserve: float = 58.0) -> Rect2:
	var maximum := Vector2(
		maxf(margin, viewport_size.x - margin - desired.size.x),
		maxf(margin, viewport_size.y - bottom_reserve - desired.size.y),
	)
	return Rect2(Vector2(clampf(desired.position.x, margin, maximum.x), clampf(desired.position.y, top_reserve, maximum.y)).round(), desired.size.round())


func _draw_parchment_panel(canvas: CanvasItem, rectangle: Rect2, accent: Color, opacity: float) -> void:
	var step := float((data.get("budgets", {}) as Dictionary).get("corner_step", 6))
	var points := PackedVector2Array([
		rectangle.position + Vector2(step, 0), rectangle.end - Vector2(step, rectangle.size.y),
		rectangle.end - Vector2(0, rectangle.size.y - step), rectangle.end - Vector2(0, step),
		rectangle.end - Vector2(step, 0), rectangle.position + Vector2(step, rectangle.size.y),
		rectangle.position + Vector2(0, rectangle.size.y - step), rectangle.position + Vector2(0, step),
	])
	canvas.draw_colored_polygon(points, Color(language.ramp_color("parchment", 4), opacity))
	canvas.draw_polyline(_closed(points), Color(language.ramp_color("worldbone", 0), minf(0.94, opacity + 0.08)), 2.0, false)
	canvas.draw_polyline(PackedVector2Array([rectangle.position + Vector2(step + 2, 3), rectangle.end - Vector2(step + 2, rectangle.size.y - 3)]), Color(accent, minf(0.82, opacity)), 2.0, false)


func _draw_tether(canvas: CanvasItem, source_anchor: Vector2, rectangle: Rect2, accent: Color) -> void:
	var target := Vector2(clampf(source_anchor.x, rectangle.position.x + 14.0, rectangle.end.x - 14.0), rectangle.end.y)
	var tail_height := float((data.get("layout", {}) as Dictionary).get("tail_height", 10))
	var tail := PackedVector2Array([target + Vector2(-7, 0), target + Vector2(7, 0), target + Vector2(0, tail_height)])
	canvas.draw_colored_polygon(tail, Color(language.ramp_color("parchment", 4), 0.84))
	if target.distance_to(source_anchor) > tail_height + 6.0:
		canvas.draw_line(target + Vector2(0, tail_height), source_anchor, Color(accent, 0.54), 1.0)
		canvas.draw_circle(source_anchor, 3.0, Color(accent, 0.78))


func _draw_glyph(canvas: CanvasItem, center: Vector2, glyph: String, accent: Color) -> void:
	canvas.draw_circle(center, 13.0, Color(language.ramp_color("worldbone", 0), 0.88))
	canvas.draw_circle(center, 11.0, Color(accent, 0.20))
	match glyph:
		"route":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-7, 6), center + Vector2(-2, -5), center + Vector2(3, 3), center + Vector2(8, -6)]), accent, 2.0, false)
		"bell":
			canvas.draw_arc(center + Vector2(0, 1), 7.0, PI, TAU, 12, accent, 2.0)
			canvas.draw_line(center + Vector2(-7, 1), center + Vector2(7, 1), accent, 2.0)
			canvas.draw_circle(center + Vector2(0, 5), 2.0, accent)
		"mask":
			canvas.draw_arc(center, 8.0, 0.0, PI, 12, accent, 2.0)
			canvas.draw_circle(center + Vector2(-4, 1), 2.0, accent)
			canvas.draw_circle(center + Vector2(4, 1), 2.0, accent)
		"weave":
			for angle: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
				canvas.draw_arc(center + Vector2.from_angle(angle) * 4.0, 6.0, angle, angle + PI * 1.3, 10, accent, 2.0)
		"gate":
			canvas.draw_arc(center + Vector2(0, 5), 8.0, PI, TAU, 12, accent, 2.0)
			canvas.draw_line(center + Vector2(-8, 5), center + Vector2(-8, -1), accent, 2.0)
			canvas.draw_line(center + Vector2(8, 5), center + Vector2(8, -1), accent, 2.0)
		"scroll":
			canvas.draw_rect(Rect2(center - Vector2(6, 8), Vector2(12, 16)), accent, false, 2.0)
			canvas.draw_line(center + Vector2(-3, -3), center + Vector2(4, -3), accent, 1.0)
			canvas.draw_line(center + Vector2(-3, 2), center + Vector2(3, 2), accent, 1.0)
		"hearth":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(7, 3), center + Vector2(3, 8), center + Vector2(-4, 7), center + Vector2(-7, 1)]), accent)
		"ledger":
			canvas.draw_rect(Rect2(center - Vector2(7, 8), Vector2(14, 16)), accent, false, 2.0)
			canvas.draw_line(center, center + Vector2(0, 8), accent, 1.0)
		"keys":
			for offset: Vector2 in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]:
				canvas.draw_rect(Rect2(center + offset - Vector2(3, 3), Vector2(6, 6)), accent, false, 1.0)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var output := points.duplicate()
	if not output.is_empty():
		output.append(output[0])
	return output


func _fail(message: String) -> bool:
	last_error = message
	return false
