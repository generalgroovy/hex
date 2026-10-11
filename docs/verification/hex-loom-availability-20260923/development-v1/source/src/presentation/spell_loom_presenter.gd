class_name SpellLoomPresenter
extends RefCounted

const ElementGlyphRendererScript = preload("res://src/presentation/element_glyph_renderer.gd")

# One layout contract powers painting and hit testing; no gameplay mutation here.
static func draw_panel(canvas: CanvasItem, editor: SpellLoomEditor, state: PlayerState, catalog: AbilityCatalog, language: VisualLanguage, preferences: PlayerPreferences = null, availability: Dictionary = {}) -> void:
	if state == null:
		return
	var ink := language.ui_color("text_primary")
	var muted := language.ui_color("text_secondary")
	var focus := language.ui_color("focus")
	var assignment_enabled := assignment_is_enabled(availability)
	var assignment_reason := assignment_disabled_reason(availability)
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("050806c4"))
	canvas.draw_rect(SpellLoomEditor.PANEL_RECT, Color("111a19fc"))
	canvas.draw_rect(SpellLoomEditor.PANEL_RECT, Color("a58d5d"), false, 2)
	text(canvas, Vector2(48, 58), "SPELL LOOM", 24, ink)
	text(canvas, Vector2(48, 86), "Choose a slot, then a spell. All 32 spells remain available. Labels below use your keyboard settings.", 14, muted)
	text(canvas, Vector2(48, 126), "YOUR 12 SLOTS", 16, ink)
	text(canvas, Vector2(SpellLoomEditor.MATRIX_LABEL_X, 96), "SPELLS  /  %d OF %d" % [editor.visible_spell_indices().size(), editor.available_wire_ids.size()], 14, ink)
	canvas.draw_rect(SpellLoomEditor.CLOSE_RECT, Color("31433d"))
	text(canvas, SpellLoomEditor.CLOSE_RECT.position + Vector2(10, 23), "X", 17, ink)
	if not editor.starter_preview_active():
		canvas.draw_rect(SpellLoomEditor.STARTER_BUTTON_RECT, Color(focus, 0.10))
		canvas.draw_rect(SpellLoomEditor.STARTER_BUTTON_RECT, Color(focus, 0.72), false, 1)
		text(canvas, SpellLoomEditor.STARTER_BUTTON_RECT.position + Vector2(10, 23), "Use character starter kit", 12, ink)
	for filter_index: int in range(SpellLoomEditor.ELEMENT_FILTERS.size()):
		var filter_id := SpellLoomEditor.ELEMENT_FILTERS[filter_index]
		var filter_rect := SpellLoomEditor.element_filter_rect(filter_index)
		var filter_selected := filter_id == editor.selected_element_filter
		canvas.draw_rect(filter_rect, Color(focus, 0.20) if filter_selected else Color(muted, 0.06))
		canvas.draw_rect(filter_rect, focus if filter_selected else Color(muted, 0.30), false, 2 if filter_selected else 1)
		text(canvas, filter_rect.position + Vector2(7, 19), SpellLoomEditor.element_filter_label(filter_id).to_upper(), 10, ink if filter_selected else muted, filter_rect.size.x - 12)
	for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
		var rect := SpellLoomEditor.slot_rect(slot)
		var ability := catalog.ability_from_wire(state.spell_wire_id(slot + 1))
		var element := String(ability.get("element", ""))
		var color := language.element_color(element, "base") if not element.is_empty() else muted
		var selected := editor.selected_slot_index == slot
		var target := editor.dragging and SpellLoomEditor.slot_at(editor.pointer_position) == slot
		canvas.draw_rect(rect, Color(color, 0.18 if selected or target else 0.07))
		canvas.draw_rect(rect, focus if selected or target else Color(muted, 0.30), false, 2 if selected or target else 1)
		text(canvas, rect.position + Vector2(9, 22), "Slot %02d" % (slot + 1), 12, focus)
		var slot_lines := name_lines(slot_display_name(state.spell_wire_id(slot + 1), ability), rect.size.x - 18, 13)
		for line: int in range(slot_lines.size()):
			text(canvas, rect.position + Vector2(9, 41 + line * 14), slot_lines[line], 13, ink, rect.size.x - 18)
		text(canvas, rect.position + Vector2(9, 71), slot_binding_label(slot, preferences), 10, color, rect.size.x - 18)
		ElementGlyphRendererScript.draw(canvas, language, rect.position + Vector2(rect.size.x - 16, 18), element, 6.0, color)
	for column: int in range(AbilityCatalog.SPELL_MATRIX_FAMILIES.size()):
		text(canvas, Vector2(SpellLoomEditor.SPELL_PICKER_X + column * SpellLoomEditor.SPELL_PICKER_WIDTH + 5, 140), family_label(AbilityCatalog.SPELL_MATRIX_FAMILIES[column]).to_upper(), 12, muted)
	var displayed_elements: Array[String] = []
	if editor.selected_element_filter.is_empty():
		displayed_elements.assign(AbilityCatalog.FIRST_EIGHT_ELEMENTS)
	else:
		displayed_elements.append(editor.selected_element_filter)
	for row: int in range(displayed_elements.size()):
		var row_element := displayed_elements[row]
		var row_color := language.element_color(row_element, "base")
		ElementGlyphRendererScript.draw(canvas, language, Vector2(SpellLoomEditor.MATRIX_LABEL_X + 27, SpellLoomEditor.GRID_Y + row * SpellLoomEditor.SPELL_PICKER_HEIGHT + 8), row_element, 5.0, row_color)
		text(canvas, Vector2(SpellLoomEditor.MATRIX_LABEL_X, SpellLoomEditor.GRID_Y + row * SpellLoomEditor.SPELL_PICKER_HEIGHT + 24), AbilityCatalog.element_display_name(row_element).to_upper(), 11, row_color, 62)
	for index: int in editor.visible_spell_indices():
		var rect := editor.spell_rect(index)
		var ability := catalog.ability_from_wire(editor.available_wire_ids[index])
		var element := String(ability.get("element", ""))
		var color := language.element_color(element, "base")
		var selected := index == editor.selected_spell_index
		canvas.draw_rect(rect, Color(color, 0.22 if selected else 0.08))
		canvas.draw_rect(rect, focus if selected else Color(muted, 0.25), false, 2 if selected else 1)
		canvas.draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), color)
		var picker_lines := name_lines(String(ability.get("display_name", "Spell")), rect.size.x - 11, 11)
		for line: int in range(picker_lines.size()):
			text(canvas, rect.position + Vector2(8, 12 + line * 12), picker_lines[line], 11, ink, rect.size.x - 11)
		text(canvas, rect.position + Vector2(8, 36), "%dF" % int(ability.get("flux_cost", 0)), 10, color)
	text(canvas, Vector2(48, 548), "Slot %02d / %s / Keyboard: %s" % [editor.selected_slot_index + 1, slot_display_name(state.spell_wire_id(editor.selected_slot_index + 1), catalog.ability_from_wire(state.spell_wire_id(editor.selected_slot_index + 1))), slot_binding_label(editor.selected_slot_index, preferences)], 13, focus, 1170)
	var chosen := catalog.ability_from_wire(editor.selected_wire_id())
	canvas.draw_line(Vector2(48, SpellLoomEditor.DETAIL_DIVIDER_Y), Vector2(1228, SpellLoomEditor.DETAIL_DIVIDER_Y), Color(muted, 0.3))
	text(canvas, Vector2(48, 594), String(chosen.get("display_name", "Choose a spell")), 19, ink)
	text(canvas, Vector2(330, 594), "%s  /  %s  /  %d Flux  /  %.2fs cooldown" % [AbilityCatalog.element_display_name(String(chosen.get("element", ""))), family_label(AbilityCatalog._spell_family(chosen)), int(chosen.get("flux_cost", 0)), float(chosen.get("cooldown_ms", 0)) / 1000.0], 14, muted)
	text(canvas, Vector2(48, 620), family_detail(chosen), 13, ink, 930)
	text(canvas, Vector2(48, 651), editor.status_message, 13, muted, 940)
	var assign_color := focus if assignment_enabled else muted
	canvas.draw_rect(SpellLoomEditor.ASSIGN_RECT, Color(assign_color, 0.18 if assignment_enabled else 0.08))
	canvas.draw_rect(SpellLoomEditor.ASSIGN_RECT, Color(assign_color, 1.0 if assignment_enabled else 0.45), false, 1)
	text(canvas, SpellLoomEditor.ASSIGN_RECT.position + Vector2(10, 25), "Assign to slot %02d" % (editor.selected_slot_index + 1) if assignment_enabled else "Assign unavailable", 13, ink if assignment_enabled else muted)
	var footer := "Up / Down: slot     Left / Right: shown spell     Click: element filter     Enter / A: assign     Esc / B: close"
	if not assignment_enabled:
		footer = "ASSIGN UNAVAILABLE: %s  Esc / B: close." % assignment_reason
	text(canvas, Vector2(48, 682), footer, 12, muted)
	if editor.dragging and not editor.starter_preview_active():
		var ghost := Rect2(editor.pointer_position + Vector2(14, 14), Vector2(176, 38))
		var dragged := catalog.ability_from_wire(editor.available_wire_ids[editor.drag_spell_index])
		canvas.draw_rect(ghost, Color("152a25ed"))
		canvas.draw_rect(ghost, focus, false, 2)
		text(canvas, ghost.position + Vector2(9, 25), String(dragged.get("display_name", "Spell")), 14, ink)
	if editor.starter_preview_active():
		_draw_starter_preview(canvas, editor, language, preferences, availability)


static func _draw_starter_preview(canvas: CanvasItem, editor: SpellLoomEditor, language: VisualLanguage, preferences: PlayerPreferences = null, availability: Dictionary = {}) -> void:
	var ink := language.ui_color("text_primary")
	var muted := language.ui_color("text_secondary")
	var quiet := language.ui_color("text_muted")
	var focus := language.ui_color("focus")
	var pending := language.ui_color("pending")
	var assignment_enabled := assignment_is_enabled(availability)
	var assignment_reason := assignment_disabled_reason(availability)
	canvas.draw_rect(SpellLoomEditor.PANEL_RECT, Color("050806c8"))
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_RECT, language.ui_color("panel_fill_strong"))
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_RECT, Color(focus, 0.78), false, 2)
	text(canvas, Vector2(112, 88), "CHARACTER STARTER KIT PREVIEW", 22, ink)
	text(canvas, Vector2(112, 113), "Review every slot before the game sends one atomic apply request.", 13, muted)
	text(canvas, Vector2(112, 136), String(editor.starter_preview.get("notice", "")), 12, pending, 1018)
	var rows_value: Variant = editor.starter_preview.get("rows", [])
	if rows_value is Array:
		var rows: Array = rows_value
		for index: int in range(mini(PlayerState.SPELL_SLOT_COUNT, rows.size())):
			var row_value: Variant = rows[index]
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			var rect := SpellLoomEditor.starter_preview_slot_rect(index)
			var before_element := String(row.get("before_element", ""))
			var after_element := String(row.get("after_element", ""))
			var before_color := language.element_color(before_element, "base") if not before_element.is_empty() else quiet
			var after_color := language.element_color(after_element, "base") if not after_element.is_empty() else quiet
			var supported := bool(row.get("court_supported", false))
			var tag_color := after_color if supported else pending
			canvas.draw_rect(rect, Color(after_color, 0.075))
			canvas.draw_rect(rect, Color(muted, 0.28), false, 1)
			canvas.draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), after_color)
			text(canvas, rect.position + Vector2(10, 17), "Slot %02d / %s" % [index + 1, slot_binding_label(index, preferences)], 11, focus, 310)
			text(canvas, rect.position + Vector2(330, 17), String(row.get("court_tag", "HEX EFFECT UNAVAILABLE")), 10, tag_color, 176)
			ElementGlyphRendererScript.draw(canvas, language, rect.position + Vector2(18, 37), before_element, 5.0, before_color)
			text(canvas, rect.position + Vector2(31, 41), String(row.get("before_name", "Empty")), 12, ink, 190)
			text(canvas, rect.position + Vector2(229, 41), ">", 13, muted)
			ElementGlyphRendererScript.draw(canvas, language, rect.position + Vector2(258, 37), after_element, 5.0, after_color)
			text(canvas, rect.position + Vector2(271, 41), String(row.get("after_name", "Spell")), 12, ink, 231)
			text(canvas, rect.position + Vector2(31, 57), AbilityCatalog.element_display_name(before_element) if not before_element.is_empty() else "Empty", 10, before_color, 190)
			text(canvas, rect.position + Vector2(271, 57), AbilityCatalog.element_display_name(after_element), 10, after_color, 231)
	text(canvas, Vector2(112, 594), "Preview only: the library, world and current weave have not changed." if assignment_enabled else "APPLY UNAVAILABLE: %s" % assignment_reason, 12, muted if assignment_enabled else pending, 720)
	var apply_color := focus if assignment_enabled else muted
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT, Color(apply_color, 0.20 if assignment_enabled else 0.08))
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT, Color(apply_color, 1.0 if assignment_enabled else 0.45), false, 2)
	text(canvas, SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT.position + Vector2(38, 25), "APPLY", 13, ink if assignment_enabled else muted)
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT, Color(muted, 0.10))
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT, muted, false, 1)
	text(canvas, SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT.position + Vector2(36, 25), "CANCEL", 13, ink)


static func assignment_is_enabled(availability: Dictionary) -> bool:
	return availability.is_empty() or bool(availability.get("enabled", false))


static func assignment_disabled_reason(availability: Dictionary) -> String:
	return "" if assignment_is_enabled(availability) else String(availability.get("reason", "Spell assignment is unavailable."))


# Missing positive identity is not an empty slot. Only the actual catalog runtime
# gate is used; material_runtime_enabled does not gate an otherwise playable spell.
static func slot_display_name(wire_id: int, ability: Dictionary) -> String:
	if wire_id == 0:
		return "Empty"
	if ability.is_empty() or String(ability.get("display_name", "")).is_empty():
		return "Unavailable spell #%d" % wire_id
	var label := String(ability.display_name)
	if ability.has("runtime_status") and String(ability.runtime_status) != "playable":
		return "%s (unavailable #%d)" % [label, wire_id]
	return label


# Read-only labels: a missing settings object is unknown, a zero key is unbound.
# These are explicitly keyboard labels; mouse/controller input ownership is unchanged.
static func slot_binding_label(slot_index: int, preferences: PlayerPreferences) -> String:
	if slot_index < 0 or slot_index >= PlayerState.SPELL_SLOT_COUNT:
		return "Invalid slot"
	if preferences == null:
		return "Binding unavailable"
	var action := StringName("spell_%d" % (slot_index % PlayerState.SPELL_BUTTON_COUNT + 1))
	var keycode := int(preferences.keyboard_bindings.get(action, 0))
	if keycode == 0:
		return "Not bound"
	var key_label := OS.get_keycode_string(keycode)
	# Whole groups of four slots select the existing plain/modifier layer.
	@warning_ignore("integer_division")
	var layer := slot_index / PlayerState.SPELL_BUTTON_COUNT
	if layer == 0:
		return key_label
	var modifier_action: StringName = &"spell_layer_ctrl" if layer == 1 else &"spell_layer_alt"
	var modifier := int(preferences.keyboard_bindings.get(modifier_action, 0))
	return "Not bound" if modifier == 0 else OS.get_keycode_string(modifier) + "+" + key_label


static func text(canvas: CanvasItem, at: Vector2, value: String, size: int, color: Color, width: float = -1.0) -> void:
	canvas.draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


static func family_label(family: String) -> String:
	return family.capitalize()


static func family_detail(ability: Dictionary) -> String:
	if String(ability.get("runtime_status", "")) != "playable":
		return "This authored catalog entry is disabled for runtime selection."
	var cost := int(ability.get("flux_cost", 0))
	var definition := CombatTuning.cast_definition(int(ability.get("wire_id", 0)))
	var reaction_strength := int(definition.get("reaction_strength", 0))
	match AbilityCatalog._spell_family(ability):
		"bolt":
			return "Bolt: one focused projectile per cast. Initial strength %d. One element per spell; cover and evasion matter." % reaction_strength
		"heavy":
			return "Heavy: %d Flux / %spx splash radius. Initial strength %d. Slow shell; blast at impact or endpoint." % [cost, String.num(float(ability.get("blast_radius", 0)) / 1000.0).trim_suffix(".0"), reaction_strength]
		"rapid":
			var repeat_held := bool(ability.get("repeat_while_held", false))
			var trigger := "hold the spell key" if repeat_held else "press the spell key"
			return "Rapid: %s / %d Flux per shot. Initial strength %d; always trail-free. %s" % [trigger, cost, reaction_strength, "Release to stop repeating." if repeat_held else "One shot per press."]
		"spray":
			return "Spray: %spx range / %d Flux. Initial strength %d; one paid first-eight ingredient fan. Aim before release." % [String.num(float(ability.get("range", 0)) / 1000.0).trim_suffix(".0"), cost, reaction_strength]
	return "This authored catalog entry is disabled for runtime selection."


static func name_lines(value: String, width: float, size: int) -> PackedStringArray:
	var result := PackedStringArray()
	var current := ""
	for word: String in value.split(" ", false):
		var candidate := word if current.is_empty() else current + " " + word
		if not current.is_empty() and ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and result.is_empty():
			result.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		result.append(current)
	return result
