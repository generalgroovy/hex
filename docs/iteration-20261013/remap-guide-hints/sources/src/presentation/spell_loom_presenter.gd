class_name SpellLoomPresenter
extends RefCounted

const ElementGlyphRendererScript = preload("res://src/presentation/element_glyph_renderer.gd")
const BindingLabels = preload("res://src/presentation/spell_binding_labels.gd")
const IdentityPerkPolicy = preload("res://src/sim/entities/identity_perk_policy.gd")
const StatusCatalog = preload("res://src/content/spell_status_catalog.gd")
const Inspector = preload("res://src/presentation/spell_inspector_model.gd")
const SUBTITLE := "Choose a slot. Combine elements. Choose how the spell travels."
const SUBTITLE_POSITION := Vector2(48, 86)
const LIBRARY_HEADING_POSITION := Vector2(SpellLoomEditor.MATRIX_LABEL_X, 96)
const HEADER_FONT_SIZE := 14
const PICKER_NAME_FONT_SIZE := 14
const PICKER_INFO_FONT_SIZE := 12
const PICKER_NAME_BASELINE := 16.0
const PICKER_NAME_LINE_STEP := 20.0
const PICKER_INFO_BASELINE := 55.0
const SLOT_NAME_FONT_SIZE := 13
const SLOT_NAME_BASELINE := 37.0
const SLOT_NAME_LINE_STEP := 18.0
const SLOT_NAME_PADDING := 4.0
const ASSIGNMENT_PREVIEW_RECT := Rect2(48, 420, 432, 44)
const PAYLOAD_BASELINE := 479.0
const PAYLOAD_LINE_STEP := 18.0
const TARGET_BASELINE := 558.0
const METRICS_HINT := "Nominal reach: cursor/cover can shorten it. Burst, then rest for faster Flux recovery."
const METRICS_HINT_POSITION := Vector2(564, 558)
const METRICS_HINT_FONT_SIZE := 10
const METRICS_HINT_WIDTH := 624.0

# One layout contract powers painting and hit testing; no gameplay mutation here.
static func draw_panel(canvas: CanvasItem, editor: SpellLoomEditor, state: PlayerState, catalog: AbilityCatalog, language: VisualLanguage, preferences: PlayerPreferences = null, availability: Dictionary = {}) -> void:
	if state == null:
		return
	var ink := language.ui_color("text_primary")
	var muted := language.ui_color("text_secondary")
	var focus := language.ui_color("focus")
	var assignment_enabled := assignment_is_enabled(availability)
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("050806c4"))
	canvas.draw_rect(SpellLoomEditor.PANEL_RECT, Color("111a19fc"))
	canvas.draw_rect(SpellLoomEditor.PANEL_RECT, Color("a58d5d"), false, 2)
	text(canvas, Vector2(48, 58), "SPELL LOOM", 24, ink)
	text(canvas, SUBTITLE_POSITION, SUBTITLE, 12, muted, 880)
	text(canvas, Vector2(48, 126), "4 KEYS / 3 LAYERS" + ("  < FOCUS" if editor.focus_area == "slots" else ""), 16, focus if editor.focus_area == "slots" else ink)
	text(canvas, LIBRARY_HEADING_POSITION, "%d MATCHES / %d SPELLS" % [editor.filtered_spell_indices().size(), editor.available_wire_ids.size()], HEADER_FONT_SIZE, ink)
	canvas.draw_rect(SpellLoomEditor.CLOSE_RECT, Color("31433d"))
	text(canvas, SpellLoomEditor.CLOSE_RECT.position + Vector2(10, 23), "X", 17, ink)
	if not editor.starter_preview_active():
		canvas.draw_rect(SpellLoomEditor.COMPARE_RECT, Color(focus, 0.18 if editor.compare_equipped else 0.08))
		text(canvas, SpellLoomEditor.COMPARE_RECT.position + Vector2(8, 23), "Compare: ON" if editor.compare_equipped else "Compare equipped", 12, ink)
		canvas.draw_rect(SpellLoomEditor.STARTER_BUTTON_RECT, Color(focus, 0.10))
		canvas.draw_rect(SpellLoomEditor.STARTER_BUTTON_RECT, Color(focus, 0.72), false, 1)
		text(canvas, SpellLoomEditor.STARTER_BUTTON_RECT.position + Vector2(10, 23), "Use character starter kit", 12, ink)
	for filter_index: int in range(SpellLoomEditor.ELEMENT_FILTERS.size()):
		var filter_id := SpellLoomEditor.ELEMENT_FILTERS[filter_index]
		var filter_rect := SpellLoomEditor.element_filter_rect(filter_index)
		var filter_selected := editor.selected_element_mask == 0 if filter_id.is_empty() else (editor.selected_element_mask & int(SpellLoomEditor.Elements.MASK_BY_WIRE[SpellLoomEditor.Elements.BY_ID[filter_id]])) != 0
		canvas.draw_rect(filter_rect, Color(focus, 0.20) if filter_selected else Color(muted, 0.06))
		canvas.draw_rect(filter_rect, focus if filter_selected else Color(muted, 0.30), false, 2 if filter_selected else 1)
		text(canvas, filter_rect.position + Vector2(7, 19), SpellLoomEditor.element_filter_label(filter_id).to_upper(), 10, ink if filter_selected else muted, filter_rect.size.x - 12)
	canvas.draw_rect(SpellLoomEditor.MORE_FORMS_RECT, Color(focus, 0.16))
	text(canvas, SpellLoomEditor.MORE_FORMS_RECT.position + Vector2(7, 19), "MORE FORMS" if editor.basic_forms_only else "CORE FORMS", 11, ink, 104)
	for family_index: int in SpellLoomEditor.FAMILY_FILTERS.size():
		var family := SpellLoomEditor.FAMILY_FILTERS[family_index]
		var family_rect := SpellLoomEditor.family_filter_rect(family_index)
		var selected := editor.selected_family_filter == family
		canvas.draw_rect(family_rect, Color(focus, 0.20) if selected else Color(muted, 0.06))
		canvas.draw_rect(family_rect, focus if selected else Color(muted, 0.30), false, 1)
		text(canvas, family_rect.position + Vector2(5, 19), "ALL" if family.is_empty() else family.to_upper(), 10, ink if selected else muted, 57)
	for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
		var rect := SpellLoomEditor.slot_rect(slot)
		var ability := catalog.ability_from_wire(state.spell_wire_id(slot + 1))
		var element := String(ability.get("element", ""))
		var color := language.element_color(element, "base") if not element.is_empty() else muted
		var selected := editor.selected_slot_index == slot
		var target := editor.dragging and SpellLoomEditor.slot_at(editor.pointer_position) == slot
		canvas.draw_rect(rect, Color(color, 0.18 if selected or target else 0.07))
		canvas.draw_rect(rect, focus if selected or target else Color(muted, 0.30), false, 2 if selected or target else 1)
		var keycap := slot_keycap(slot, preferences)
		canvas.draw_rect(Rect2(rect.position + Vector2(7, 1), Vector2(rect.size.x - 14, 21)), Color(focus, 0.09))
		text(canvas, rect.position + Vector2(9, 16), keycap.label, keycap.font_size, focus, rect.size.x - 18)
		var slot_lines := name_lines(slot_display_name(state.spell_wire_id(slot + 1), ability), rect.size.x - SLOT_NAME_PADDING * 2, SLOT_NAME_FONT_SIZE)
		for line: int in range(slot_lines.size()):
			text(canvas, rect.position + Vector2(SLOT_NAME_PADDING, SLOT_NAME_BASELINE + line * SLOT_NAME_LINE_STEP), slot_lines[line], SLOT_NAME_FONT_SIZE, ink, rect.size.x - SLOT_NAME_PADDING * 2)
	for index: int in editor.visible_spell_indices():
		var rect := editor.spell_rect(index)
		var ability := catalog.ability_from_wire(editor.available_wire_ids[index])
		var element := String(ability.get("element", ""))
		var color := language.element_color(element, "base")
		var selected := index == editor.selected_spell_index
		var locked := not editor.unavailable_reason(int(editor.available_wire_ids[index])).is_empty()
		canvas.draw_rect(rect, Color(color, 0.22 if selected else 0.08))
		canvas.draw_rect(rect, focus if selected else Color(muted, 0.25), false, 2 if selected else 1)
		canvas.draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), color)
		var picker_lines := name_lines(String(ability.get("display_name", "Spell")), rect.size.x - 11, PICKER_NAME_FONT_SIZE)
		for line: int in range(picker_lines.size()):
			text(canvas, rect.position + Vector2(8, PICKER_NAME_BASELINE + line * PICKER_NAME_LINE_STEP), picker_lines[line], PICKER_NAME_FONT_SIZE, ink, rect.size.x - 11)
		text(canvas, rect.position + Vector2(8, PICKER_INFO_BASELINE), "LEARN" if locked else "%dF" % int(ability.get("flux_cost", 0)), PICKER_INFO_FONT_SIZE, muted if locked else color)
		var equipped_slot := state.spell_wire_ids.find(int(editor.available_wire_ids[index]))
		if equipped_slot >= 0:
			text(canvas, rect.position + Vector2(77, PICKER_INFO_BASELINE), "SLOT %02d" % (equipped_slot + 1), PICKER_INFO_FONT_SIZE, focus)
	for page_control: Rect2 in [SpellLoomEditor.PAGE_PREVIOUS_RECT, SpellLoomEditor.PAGE_NEXT_RECT]:
		canvas.draw_rect(page_control, Color(focus, 0.12))
	text(canvas, SpellLoomEditor.PAGE_PREVIOUS_RECT.position + Vector2(12, 20), "< PREV", 12, ink)
	text(canvas, SpellLoomEditor.PAGE_NEXT_RECT.position + Vector2(12, 20), "NEXT >", 12, ink)
	text(canvas, Vector2(742, 474), "PAGE %d / %d" % [editor.page_index + 1, editor.page_count()], 12, muted, 250)
	text(canvas, Vector2(48, TARGET_BASELINE), "TARGET %02d  /  Binding: %s" % [editor.selected_slot_index + 1, slot_binding_label(editor.selected_slot_index, preferences)], 13, focus, 432)
	var chosen := catalog.ability_from_wire(editor.selected_wire_id())
	_draw_assignment_preview(canvas, editor, state, catalog, language)
	var payload := MixtureCatalog.definition(int(chosen.get("element_mask", 0)))
	if not payload.is_empty():
		var mask := int(payload.element_mask)
		var effect_prefix := "Matching matter: " if (mask & (mask - 1)) == 0 else "Payload field: "
		var payload_lines := _wrap_payload(effect_prefix + String(payload.purpose), 432)
		payload_lines.append_array(_wrap_payload("Counter: " + String(payload.counter), 432))
		for line: int in mini(4, payload_lines.size()):
			text(canvas, Vector2(48, PAYLOAD_BASELINE + line * PAYLOAD_LINE_STEP), payload_lines[line], 12, muted, 432)
	var metrics := spell_metrics(chosen,state)
	for metric_index: int in range(metrics.size()):
		var at := Vector2(564 + (metric_index % 3) * 208, 513 + (metric_index / 3) * 26)
		text(canvas, at, String(metrics[metric_index].label), 10, muted, 94)
		text(canvas, at + Vector2(95, 0), String(metrics[metric_index].value), 12, ink, 108)
	text(canvas, METRICS_HINT_POSITION, timing_note(chosen,state), METRICS_HINT_FONT_SIZE, muted, METRICS_HINT_WIDTH)
	canvas.draw_line(Vector2(48, SpellLoomEditor.DETAIL_DIVIDER_Y), Vector2(1228, SpellLoomEditor.DETAIL_DIVIDER_Y), Color(muted, 0.3))
	text(canvas, Vector2(48, 589), String(chosen.get("display_name", "Choose a spell")), 19, ink, 700)
	text(canvas, Vector2(790, 589), "%s / %d Flux / %.2fs" % [family_label(AbilityCatalog._spell_family(chosen)), int(chosen.get("flux_cost", 0)), float(chosen.get("cooldown_ms", 0)) / 1000.0], 13, muted, 420)
	if editor.compare_equipped:
		var comparison := Inspector.comparison(editor.selected_wire_id(),state.spell_wire_id(editor.selected_slot_index+1),state)
		text(canvas,Vector2(48,610),comparison[0] + (" " + comparison[1] if comparison.size()>1 else ""),12,ink,940)
		if comparison.size()>3: text(canvas,Vector2(48,627),comparison[2]+" "+comparison[3],12,muted,940)
		text(canvas,Vector2(48,644),"Hit/pool are not sustained DPS. Fields are separate. Current timing can change before release.",11,muted,940)
	else:
		text(canvas, Vector2(48, 610), family_detail(chosen), 12, ink, 940)
		text(canvas, Vector2(48, 627), payload_detail(chosen), 12, muted, 940)
	_draw_feedback(canvas, editor, language, availability)
	var assign_color := focus if assignment_enabled else muted
	canvas.draw_rect(SpellLoomEditor.ASSIGN_RECT, Color(assign_color, 0.18 if assignment_enabled else 0.08))
	canvas.draw_rect(SpellLoomEditor.ASSIGN_RECT, Color(assign_color, 1.0 if assignment_enabled else 0.45), false, 1)
	var action := "Swap" if editor.assignment_preview(state).kind == "swap" else "Assign"
	text(canvas, SpellLoomEditor.ASSIGN_RECT.position + Vector2(10, 25), "%s to slot %02d" % [action, editor.selected_slot_index + 1] if assignment_enabled else "Assign unavailable", 13, ink if assignment_enabled else muted)
	var footer := "Arrows/D-pad: browse  Tab/Y: slots/library  PgUp/PgDn/LB/RB: mixture  Q/E: form  Enter/A: assign  Esc/B: close"
	text(canvas, Vector2(48, 682), footer, 12, muted)
	if editor.dragging and not editor.starter_preview_active():
		var ghost := Rect2((editor.pointer_position + Vector2(14, 14)).clamp(Vector2(24, 20), Vector2(1080, 662)), Vector2(176, 38))
		var dragged := catalog.ability_from_wire(editor.available_wire_ids[editor.drag_spell_index])
		canvas.draw_rect(ghost, Color("152a25ed"))
		canvas.draw_rect(ghost, focus, false, 2)
		text(canvas, ghost.position + Vector2(9, 25), String(dragged.get("display_name", "Spell")), 14, ink)
	if editor.starter_preview_active():
		_draw_starter_preview(canvas, editor, language, preferences, availability)


static func _draw_assignment_preview(canvas: CanvasItem, editor: SpellLoomEditor, state: PlayerState, catalog: AbilityCatalog, language: VisualLanguage) -> void:
	var preview := editor.assignment_preview(state)
	var box := ASSIGNMENT_PREVIEW_RECT
	var focus := language.ui_color("focus")
	var ink := language.ui_color("text_primary")
	canvas.draw_rect(box, Color(focus, 0.07))
	canvas.draw_rect(box, Color(focus, 0.30), false)
	var title := "REPLACE ONE SLOT"
	if preview.kind == "swap":
		title = "SWAP SLOTS %02d AND %02d" % [editor.selected_slot_index + 1, int(preview.other_slot) + 1]
	elif preview.kind == "unchanged":
		title = "ALREADY IN THIS SLOT"
	var current := catalog.ability_from_wire(state.spell_wire_id(editor.selected_slot_index + 1))
	var chosen := catalog.ability_from_wire(editor.selected_wire_id())
	text(canvas, box.position + Vector2(12, 16), title + (" / timers kept" if preview.kind == "swap" else ""), 12, focus, 408)
	text(canvas, box.position + Vector2(12, 36), slot_display_name(state.spell_wire_id(editor.selected_slot_index + 1), current) + " \u2192 " + String(chosen.get("display_name", "Choose a spell")), 12, ink, 408)


static func _wrap_payload(copy: String, width: float) -> Array[String]:
	var result: Array[String] = []
	var line := ""
	for word: String in copy.split(" "):
		var next := word if line.is_empty() else line + " " + word
		if not line.is_empty() and ThemeDB.fallback_font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > width:
			result.append(line)
			line = word
		else: line = next
	if not line.is_empty(): result.append(line)
	return result


static func spell_metrics(ability: Dictionary, state: PlayerState = null) -> Array[Dictionary]:
	return Inspector.metrics(int(ability.get("wire_id",0)),state)


static func timing_note(ability: Dictionary, state: PlayerState) -> String:
	return Inspector.timing_note(int(ability.get("wire_id",0)),state)


static func _draw_starter_preview(canvas: CanvasItem, editor: SpellLoomEditor, language: VisualLanguage, preferences: PlayerPreferences = null, availability: Dictionary = {}) -> void:
	var ink := language.ui_color("text_primary")
	var muted := language.ui_color("text_secondary")
	var quiet := language.ui_color("text_muted")
	var focus := language.ui_color("focus")
	var pending := language.ui_color("pending")
	var assignment_enabled := assignment_is_enabled(availability)
	canvas.draw_rect(SpellLoomEditor.PANEL_RECT, Color("050806c8"))
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_RECT, language.ui_color("panel_fill_strong"))
	canvas.draw_rect(SpellLoomEditor.STARTER_PREVIEW_RECT, Color(focus, 0.78), false, 2)
	text(canvas, Vector2(112, 88), "SAVED WEAVE / SIX-ELEMENT UPDATE" if String(editor.starter_preview.get("kind", "")) == "migration" else "CHARACTER STARTER KIT PREVIEW", 22, ink)
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
	_draw_feedback(canvas, editor, language, availability, true)
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


# The last transaction outcome and the next action's admission are independent.
# An accepted assignment immediately becomes a no-op; that must not hide its
# confirmation or a failed-save warning. Starter failures use the same projection.
static func feedback_lines(editor: SpellLoomEditor, availability: Dictionary = {}, starter: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin := Vector2(112, 591) if starter else Vector2(48, 642)
	var width := 1018.0 if starter else 940.0
	var status := editor.status_message if editor != null else ""
	var reason := assignment_disabled_reason(availability)
	if not status.is_empty():
		result.append({"text": status, "position": origin, "width": width, "font_size": 12, "kind": "status"})
	if not reason.is_empty() and reason != status:
		result.append({"text": reason, "position": origin + Vector2(0, 17), "width": width, "font_size": 12, "kind": "availability"})
	return result


static func _draw_feedback(canvas: CanvasItem, editor: SpellLoomEditor, language: VisualLanguage, availability: Dictionary, starter: bool = false) -> void:
	for line: Dictionary in feedback_lines(editor, availability, starter):
		text(canvas, line.position, line.text, line.font_size, language.ui_color("focus" if line.kind == "availability" else "text_primary"), line.width)


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


# Read-only saved-binding labels. A missing settings object is unknown; a slot
# is unbound only when its button or required modifier has no saved device input.
static func slot_binding_label(slot_index: int, preferences: PlayerPreferences) -> String:
	if slot_index < 0 or slot_index >= PlayerState.SPELL_SLOT_COUNT:
		return "Invalid slot"
	if preferences == null:
		return "Binding unavailable"
	var action := StringName("spell_%d" % (slot_index % PlayerState.SPELL_BUTTON_COUNT + 1))
	var key_label := BindingLabels.action_label(action, preferences)
	if key_label.is_empty():
		return "Not bound"
	# Whole groups of four slots select the existing plain/modifier layer.
	@warning_ignore("integer_division")
	var layer := slot_index / PlayerState.SPELL_BUTTON_COUNT
	if layer == 0:
		return key_label
	var modifier_action: StringName = &"spell_layer_ctrl" if layer == 1 else &"spell_layer_alt"
	var modifier := BindingLabels.action_label(modifier_action, preferences)
	return "Not bound" if modifier.is_empty() else modifier + "+" + key_label


static func text(canvas: CanvasItem, at: Vector2, value: String, size: int, color: Color, width: float = -1.0) -> void:
	canvas.draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


# The actual saved chord leads each card; full binding remains in the target
# footer. Rare long saved chords are visibly elided, never replaced by defaults.
static func slot_keycap(slot_index: int, preferences: PlayerPreferences) -> Dictionary:
	var label := slot_binding_label(slot_index, preferences)
	var size := 14
	var width := SpellLoomEditor.slot_rect(0).size.x - 18.0
	while size > 10 and ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	if ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		while not label.is_empty() and ThemeDB.fallback_font.get_string_size(label + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			label = label.left(-1)
		label += "..."
	return {"label": label, "font_size": size}


static func family_heading(family: String) -> String:
	var role := ""
	match family:
		"bolt": role = "FOCUS"
		"heavy": role = "SPLASH"
		"rapid": role = "PRESSURE"
		"spray": role = "FAN"
		"mantle": role = "CONTACT"
		"fuse": role = "DELAY"
		"split": role = "FORK"
		"rebound": role = "BANK"
	return family.to_upper() + (" / " + role if not role.is_empty() else "")


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
			var trigger := "Hold to repeat; release stops new casts." if bool(ability.get("repeat_while_held", false)) else "Press for one shot."
			return "Bolt: %s %d Flux per shot. Initial strength %d; focused aim and paid countercasting." % [trigger, cost, reaction_strength]
		"heavy":
			return "Heavy: %d Flux / %spx splash radius. Initial strength %d. Slow shell; blast at impact or endpoint." % [cost, String.num(float(ability.get("blast_radius", 0)) / 1000.0).trim_suffix(".0"), reaction_strength]
		"rapid":
			var repeat_held := bool(ability.get("repeat_while_held", false))
			var trigger := "hold the spell key" if repeat_held else "press the spell key"
			return "Rapid: %s / %d Flux per shot. Initial strength %d; always trail-free. %s" % [trigger, cost, reaction_strength, "Release to stop repeating." if repeat_held else "One shot per press."]
		"spray":
			var control := "Aim before release."
			if int(definition.get("hit_control_state", 0)) == PlayerState.ControlState.LAUNCHED and int(definition.get("hit_control_duration_ms", 0)) > 0 and int(definition.get("hit_control_speed", 0)) > 0:
				control = "Launch on hit: %dms at %spx/s." % [int(definition.hit_control_duration_ms), String.num(float(definition.hit_control_speed) / 1000.0, 1)]
			return "Spray: %spx range / %d Flux. Initial strength %d; paid ingredient fan. %s" % [String.num(float(ability.get("range", 0)) / 1000.0).trim_suffix(".0"), cost, reaction_strength, control]
		"mantle": return "Mantle: follows you; touch and trail share one paid pool. Initial strength %d." % reaction_strength
		"fuse": return "Fuse: grounded warning, then one cover-blocked explosion. Initial strength %d." % reaction_strength
		"split": return "Split: forks once; children share the parent's damage and matter. Initial strength %d." % reaction_strength
		"rebound": return "Rebound: limited wall banks; no extra damage is created. Initial strength %d." % reaction_strength
	return "Choose a spell to inspect its delivery."


static func payload_detail(ability: Dictionary) -> String:
	var mask := int(ability.get("element_mask", 0))
	var effects := PackedStringArray()
	for row: Dictionary in StatusCatalog.rows_for_mask(mask):
		effects.append(String(row.summary))
	if effects.size() > 3:
		var compact := PackedStringArray()
		for effect: String in effects: compact.append(effect.get_slice(":", 0))
		return "On a damaging hit: " + ", ".join(compact) + ". Status strengths are bounded; mixtures do not multiply damage."
	return "On a damaging hit: " + "; ".join(effects) + "."


static func name_lines(value: String, width: float, size: int) -> PackedStringArray:
	var result := PackedStringArray()
	var current := ""
	for word: String in value.split(" ", false):
		var candidate := word if current.is_empty() else current + " " + word
		if not current.is_empty() and ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			result.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		result.append(current)
	return result
