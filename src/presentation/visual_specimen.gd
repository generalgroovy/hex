class_name VisualSpecimen
extends RefCounted


const PANEL_MARGIN := 24.0


static func draw(canvas: CanvasItem, language: VisualLanguage, viewport_size: Vector2, tick: int) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), language.ui_color("scrim"), true)
	var panel := Rect2(Vector2(PANEL_MARGIN, PANEL_MARGIN), viewport_size - Vector2(PANEL_MARGIN * 2.0, PANEL_MARGIN * 2.0))
	PixelPrimitives.draw_panel(canvas, panel, language, true, false)
	var pad := float(language.ui_metric("panel_padding")) * 2.0
	var title_position := panel.position + Vector2(pad, 38)
	canvas.draw_string(ThemeDB.fallback_font, title_position, "HEX VISUAL LANGUAGE / CURRENT TOKENS", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - pad * 2.0, 22, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, title_position + Vector2(0, 24), "PRESENTATION ONLY / 2PX GRID / 50 75 100 CAMERA / ORIGINAL RUNTIME TOKENS", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - pad * 2.0, 11, language.ui_color("focus"))
	PixelPrimitives.draw_divider(canvas, Vector2(panel.position.x + pad, panel.position.y + 78), Vector2(panel.end.x - pad, panel.position.y + 78), language)

	var content_top := panel.position.y + 98.0
	var left_width := minf(520.0, panel.size.x * 0.44)
	_draw_materials(canvas, language, Rect2(panel.position.x + pad, content_top, left_width, 214.0))
	_draw_elements(canvas, language, Rect2(panel.position.x + pad, content_top + 232.0, left_width, 168.0), tick)
	var right := Rect2(panel.position.x + pad + left_width + 28.0, content_top, panel.size.x - pad * 2.0 - left_width - 28.0, 400.0)
	_draw_ui_language(canvas, language, right, tick)

	var footer_y := panel.end.y - 32.0
	PixelPrimitives.draw_divider(canvas, Vector2(panel.position.x + pad, footer_y - 20.0), Vector2(panel.end.x - pad, footer_y - 20.0), language)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + pad, footer_y), "DIAGNOSTIC SPECIMEN / NOT GAMEPLAY AUTHORITY / ESC CLOSES APPLICATION", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - pad * 2.0, 11, language.ui_color("text_muted"))


static func _draw_materials(canvas: CanvasItem, language: VisualLanguage, bounds: Rect2) -> void:
	canvas.draw_string(ThemeDB.fallback_font, bounds.position + Vector2(0, 16), "MATERIAL RAMPS", HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x, 14, language.ui_color("text_primary"))
	var ids := ["deep_water", "worldbone", "warm_stone", "timber", "aged_brass", "garden", "indigo_roof", "parchment"]
	var columns := 4
	var cell_width := (bounds.size.x - 18.0) / float(columns)
	for index: int in ids.size():
		var column := index % columns
		var row := index / columns
		var origin := bounds.position + Vector2(float(column) * (cell_width + 6.0), 30.0 + float(row) * 86.0)
		var tile := Rect2(origin, Vector2(cell_width, 56.0))
		PixelPrimitives.draw_material_tile(canvas, tile, language.ramp(ids[index]), index)
		canvas.draw_string(ThemeDB.fallback_font, origin + Vector2(4, 72), String(ids[index]).replace("_", " ").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, cell_width, 10, language.ui_color("text_secondary"))


static func _draw_elements(canvas: CanvasItem, language: VisualLanguage, bounds: Rect2, tick: int) -> void:
	canvas.draw_string(ThemeDB.fallback_font, bounds.position + Vector2(0, 16), "EIGHT ACTIVE ELEMENTS / SHAPE + VALUE", HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x, 14, language.ui_color("text_primary"))
	var element_ids := VisualLanguage.ACTIVE_ELEMENTS
	var gap := 5.0
	var size := minf(48.0, (bounds.size.x - gap * (element_ids.size() - 1)) / float(element_ids.size()))
	for index: int in element_ids.size():
		var element_id: String = element_ids[index]
		var rectangle := Rect2(bounds.position + Vector2(float(index) * (size + gap), 34), Vector2(size, size))
		canvas.draw_rect(rectangle, Color(language.element_color(element_id, "dark"), 0.92), true)
		canvas.draw_rect(rectangle, language.element_color(element_id, "base"), false, 1.0)
		PixelPrimitives.draw_element_glyph(canvas, language, rectangle.get_center(), size * 0.31, element_id, language.element_color(element_id, "bright"))
		var short_label: String = {"charge": "CHG", "chaos": "CHS", "spirit": "SPI", "gravity": "GRV"}.get(element_id, element_id.left(3).to_upper())
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(1, size + 14), short_label, HORIZONTAL_ALIGNMENT_CENTER, size, 9, language.ui_color("text_secondary"))
	# The first-eight motion samples execute the same bounded field/impact path.
	var live_elements := VisualLanguage.ACTIVE_ELEMENTS
	var motion_spacing := bounds.size.x / float(live_elements.size())
	for index: int in live_elements.size():
		var element_id: String = live_elements[index]
		var center := bounds.position + Vector2((float(index) + 0.5) * motion_spacing, 132.0)
		var phase := ElementGlyphRenderer.material_phase(language, element_id, tick)
		ElementGlyphRenderer.draw_material_motion(canvas, language, center, element_id, minf(25.0, motion_spacing * 0.45), phase, 0.8, false)
		canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-motion_spacing * 0.5, 29.0), element_id.left(3).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, motion_spacing, 9, language.ui_color("text_muted"))
	canvas.draw_string(ThemeDB.fallback_font, bounds.position + Vector2(0, 108), "SHARED FIELD / IMPACT MOTION", HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x, 10, language.ui_color("text_muted"))


static func _draw_ui_language(canvas: CanvasItem, language: VisualLanguage, bounds: Rect2, _tick: int) -> void:
	canvas.draw_string(ThemeDB.fallback_font, bounds.position + Vector2(0, 16), "COMBAT + INTERACTION COMPONENTS", HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x, 14, language.ui_color("text_primary"))
	var card := Rect2(bounds.position + Vector2(0, 30), Vector2(bounds.size.x, 92))
	PixelPrimitives.draw_panel(canvas, card, language, false, true)
	canvas.draw_string(ThemeDB.fallback_font, card.position + Vector2(16, 24), "OH TIPI / WELLSPRING", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 14, language.ui_color("text_primary"))
	PixelPrimitives.draw_resource_sample(canvas, Rect2(card.position + Vector2(16, 36), Vector2(card.size.x - 32, 12)), language.ramp("health"), 0.82)
	PixelPrimitives.draw_resource_sample(canvas, Rect2(card.position + Vector2(16, 54), Vector2(card.size.x - 32, 12)), language.ramp("flux"), 0.61)
	PixelPrimitives.draw_resource_sample(canvas, Rect2(card.position + Vector2(16, 72), Vector2(card.size.x - 32, 12)), language.ramp("stamina"), 0.93)

	var spell_top := card.end.y + 18.0
	var gap := float(language.ui_metric("cell_gap"))
	var spell_size := minf(76.0, (bounds.size.x - gap * 3.0) / 4.0)
	for index: int in 4:
		var spell_rect := Rect2(bounds.position + Vector2(float(index) * (spell_size + gap), spell_top - bounds.position.y), Vector2(spell_size, spell_size))
		PixelPrimitives.draw_panel(canvas, spell_rect, language, false, index == 0)
		var element_id: String = ["water", "dark", "ice", "light"][index]
		PixelPrimitives.draw_element_glyph(canvas, language, spell_rect.get_center(), 15.0, element_id, language.element_color(element_id, "bright"))
		canvas.draw_string(ThemeDB.fallback_font, spell_rect.position + Vector2(6, 14), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, spell_rect.size.x - 12, 10, language.ui_color("text_secondary"))

	var prompt := Rect2(bounds.position + Vector2(18, 248), Vector2(bounds.size.x - 36, 66))
	PixelPrimitives.draw_panel(canvas, prompt, language, false, false)
	canvas.draw_string(ThemeDB.fallback_font, prompt.position + Vector2(14, 23), "THE CURRENT LISTENS WHEN YOU DO.", HORIZONTAL_ALIGNMENT_LEFT, prompt.size.x - 28, 13, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, prompt.position + Vector2(14, 46), "F / INTERACT", HORIZONTAL_ALIGNMENT_LEFT, prompt.size.x - 28, 11, language.ui_color("focus"))
	var pointer := PackedVector2Array([
		prompt.position + Vector2(34, prompt.size.y),
		prompt.position + Vector2(48, prompt.size.y),
		prompt.position + Vector2(40, prompt.size.y + 10),
	])
	canvas.draw_colored_polygon(pointer, language.ui_color("panel_fill"))

	canvas.draw_string(ThemeDB.fallback_font, bounds.position + Vector2(0, 352), "PLAIN / CTRL / ALT   FOUR CELLS PER LAYER   TWELVE WEAVE POSITIONS", HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x, 10, language.ui_color("text_muted"))
