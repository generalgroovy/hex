extends RefCounted
## A reflowed large-text view over the existing editor. It never applies a weave.
const Inspector = preload("res://src/presentation/spell_inspector_model.gd")
const Wrap = preload("res://src/presentation/spell_testing_panel.gd")
const PAPER := Color("eadfc3")
const MUTED := Color("b8c8ca")
const FOCUS := Color("77dddc")
var page := 0
var _detail_axis_latched := false

func handle_input(game, event: InputEvent) -> void:
	var editor: SpellLoomEditor = game.spell_loom_editor
	var action := ""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			action = pointer_action(event.position / game._loom_scale(),game.get_viewport_rect().size / game._loom_scale(),editor, game.pending_weave_request.is_empty())
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: action = "previous"
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: action = "next"
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		action = {KEY_O:"options",KEY_ESCAPE:"close",KEY_UP:"previous",KEY_DOWN:"next",KEY_TAB:"focus",KEY_LEFT:"form_previous",KEY_RIGHT:"form_next",KEY_Q:"form_previous",KEY_E:"form_next",KEY_ENTER:"assign",KEY_KP_ENTER:"assign",KEY_HOME:"starter",KEY_PAGEUP:"mixture_previous",KEY_PAGEDOWN:"mixture_next",KEY_C:"compare",KEY_COMMA:"detail_previous",KEY_PERIOD:"detail_next"}.get(key,"")
	elif event is InputEventJoypadButton and event.pressed:
		action = {JOY_BUTTON_LEFT_STICK:"options",JOY_BUTTON_B:"close",JOY_BUTTON_DPAD_UP:"previous",JOY_BUTTON_DPAD_DOWN:"next",JOY_BUTTON_DPAD_LEFT:"form_previous",JOY_BUTTON_DPAD_RIGHT:"form_next",JOY_BUTTON_Y:"focus",JOY_BUTTON_A:"assign",JOY_BUTTON_RIGHT_STICK:"compare",JOY_BUTTON_X:"starter",JOY_BUTTON_LEFT_SHOULDER:"mixture_previous",JOY_BUTTON_RIGHT_SHOULDER:"mixture_next"}.get(event.button_index,"")
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		if event.axis_value < 0.3: _detail_axis_latched = false
		elif event.axis_value > 0.7 and not _detail_axis_latched:
			action = "detail_previous" if event.axis == JOY_AXIS_TRIGGER_LEFT else "detail_next"
			_detail_axis_latched = true
	if action == "options":
		editor.reading_options_open=not editor.reading_options_open
	elif action == "close":
		if not game.pending_weave_request.is_empty(): editor.cancel_starter_preview(false)
		game._close_spell_loom_editor()
	elif action == "compare":
		editor.compare_equipped = not editor.compare_equipped
		page = 0
	elif action == "detail_previous": page -= 1
	elif action == "detail_next": page += 1
	elif game.pending_weave_request.is_empty():
		if editor.starter_preview_active():
			if action == "assign": game._submit_starter_weave()
		else:
			match action:
				"assign": game._submit_spell_loom_choice()
				"starter": editor.prepare_starter_preview(game._local_player_state(),game.champion_catalog,game.ability_catalog)
				"focus": editor.cycle_focus()
				"previous", "next":
					var direction := -1 if action == "previous" else 1
					editor.move_selection(direction if editor.focus_area == "slots" else 0,direction if editor.focus_area == "spells" else 0)
				"form_previous", "form_next":
					editor.basic_forms_only = false
					editor.cycle_family_filter(-1 if action == "form_previous" else 1)
				"mixture_previous", "mixture_next": editor.cycle_element_filter(-1 if action == "mixture_previous" else 1)
		if action not in ["", "focus"]: page = 0
	game.controls_input_guard_frames = 2
	game.get_viewport().set_input_as_handled()
	game.queue_redraw()

static func geometry(viewport: Vector2, options: bool = false) -> Dictionary:
	var panel := Rect2(Vector2(12, 12), viewport - Vector2(24, 24))
	var width := panel.size.x - 24
	var tight := panel.size.y < 300
	var filter_y := 36 if tight else 43
	var form_y := 64 if tight else 78
	var browse_y := 94 if tight else 117
	var body_y := 128 if tight else 154
	var filters: Array[Rect2] = []
	for index: int in 7:
		filters.append(Rect2(panel.position + Vector2(12 + index * width / 7, filter_y), Vector2(width / 7 - 3, 24 if tight else 28)))
	var buttons: Dictionary = {}
	for index: int in 3:
		buttons[["previous", "next", "focus"][index]] = Rect2(panel.position + Vector2(12 + index * width / 3, browse_y), Vector2(width / 3 - 4, 30))
	buttons["compare"] = Rect2(panel.position+Vector2(panel.size.x-154,6),Vector2(142,30))
	buttons["form_previous"] = Rect2(panel.position + Vector2(12, form_y), Vector2(48, 28))
	buttons["form_next"] = Rect2(panel.position + Vector2(width - 36, form_y), Vector2(48, 28))
	buttons["detail_previous"] = Rect2(panel.position + Vector2(12, panel.size.y - 80), Vector2(44, 28))
	buttons["detail_next"] = Rect2(panel.position + Vector2(62, panel.size.y - 80), Vector2(44, 28))
	for index: int in 3:
		buttons[["starter", "assign", "close"][index]] = Rect2(panel.position + Vector2(12 + index * width / 3, panel.size.y - 42), Vector2(width / 3 - 4, 30))
	buttons["options"]=Rect2(panel.position+Vector2(panel.size.x-238,6),Vector2(78,30))
	if tight and not options:
		buttons.previous=Rect2(panel.position+Vector2(12,37),Vector2(36,28))
		buttons.next=Rect2(panel.position+Vector2(panel.size.x-48,37),Vector2(36,28))
		body_y=82
	return {"panel":panel,"filters":filters,"buttons":buttons,"tight":tight,"options":options,
		"title":Rect2(panel.position+Vector2(12,0),Vector2(panel.size.x-178,40)),
		"body":Rect2(panel.position + Vector2(12, body_y),Vector2(width, maxf(19, panel.size.y - 88 - body_y)))}

static func selection_title_lines(editor: SpellLoomEditor, catalog: AbilityCatalog, width: float) -> Array[String]:
	var chosen := catalog.ability_from_wire(editor.selected_wire_id())
	return Wrap._wrap("Selected: " + String(chosen.get("display_name", "Choose a spell")), ThemeDB.fallback_font, 14, width)

static func comparison_identity(editor: SpellLoomEditor, state: PlayerState, catalog: AbilityCatalog) -> String:
	var chosen := catalog.ability_from_wire(editor.selected_wire_id())
	var current := catalog.ability_from_wire(state.spell_wire_id(editor.selected_slot_index+1))
	return "Equipped %s -> selected %s" % [String(current.get("display_name", "Empty")), String(chosen.get("display_name", "Choose a spell"))]

static func detail_lines(editor: SpellLoomEditor, state: PlayerState, catalog: AbilityCatalog, preferences: PlayerPreferences, width: float) -> Array[String]:
	var chosen := catalog.ability_from_wire(editor.selected_wire_id())
	var current := catalog.ability_from_wire(state.spell_wire_id(editor.selected_slot_index + 1))
	var preview := editor.assignment_preview(state)
	var paragraphs: Array[String] = [
		"Slot %02d [%s]: %s" % [editor.selected_slot_index + 1, SpellLoomPresenter.slot_binding_label(editor.selected_slot_index, preferences), String(current.get("display_name", "Empty"))],
		String(chosen.get("display_name", "Choose a spell")),
		SpellLoomPresenter.family_detail(chosen),
		SpellLoomPresenter.payload_detail(chosen),
	]
	paragraphs.append_array(Inspector.paragraphs(editor.selected_wire_id(),state))
	if editor.compare_equipped and not editor.starter_preview_active():
		var comparison := Inspector.comparison(editor.selected_wire_id(),state.spell_wire_id(editor.selected_slot_index+1),state)
		if comparison.size()>1: comparison.remove_at(0)
		comparison.insert(0,comparison_identity(editor,state,catalog))
		paragraphs = comparison + paragraphs
	if editor.starter_preview_active():
		paragraphs = [String(editor.starter_preview.get("notice", "Review the replacement before Apply."))]
		for row: Dictionary in editor.starter_preview.get("rows", []):
			paragraphs.append("%02d: %s -> %s" % [int(row.slot_index)+1,String(row.before_name),String(row.after_name)])
	if not editor.starter_preview_active(): paragraphs.append("Swap keeps both cooldowns." if preview.kind == "swap" else "Already equipped here." if preview.kind == "unchanged" else "Replaces only this slot.")
	if not editor.status_message.is_empty(): paragraphs.append(editor.status_message)
	var locked := editor.unavailable_reason(editor.selected_wire_id())
	if not locked.is_empty(): paragraphs.append(locked)
	var result: Array[String] = []
	for text: String in paragraphs: result.append_array(Wrap._wrap(text, ThemeDB.fallback_font, 14, width))
	return result

static func draw(canvas: CanvasItem, viewport: Vector2, editor: SpellLoomEditor, state: PlayerState, catalog: AbilityCatalog, preferences: PlayerPreferences, availability: Dictionary, page: int) -> void:
	if state == null: return
	var geo := geometry(viewport,editor.reading_options_open)
	var panel: Rect2 = geo.panel
	canvas.draw_rect(panel, Color("101c23fc"))
	canvas.draw_rect(panel, FOCUS, false, 1)
	if geo.tight:
		_text(canvas,panel.position+Vector2(12,28),"Loom",19,PAPER,panel.size.x-250)
	else:
		var titles := selection_title_lines(editor,catalog,geo.title.size.x)
		for index: int in mini(2,titles.size()):
			_text(canvas,geo.title.position+Vector2(0,16+index*18),titles[index],14,PAPER,geo.title.size.x)
	if geo.tight: _button(canvas,geo.buttons.options,"Done" if editor.reading_options_open else "Options",editor.reading_options_open)
	_button(canvas,geo.buttons.compare,"Compare ON" if editor.compare_equipped else "Compare",editor.compare_equipped)
	if geo.tight and not editor.reading_options_open and not editor.starter_preview_active():
		_button(canvas,geo.buttons.previous,"<",false)
		_button(canvas,geo.buttons.next,">",false)
		var chosen := catalog.ability_from_wire(editor.selected_wire_id())
		_text(canvas,panel.position+Vector2(56,57),String(chosen.get("display_name","Choose spell")),15,PAPER,panel.size.x-112)
		var row := Inspector.inspect(editor.selected_wire_id(),state)
		if not row.is_empty(): _text(canvas,panel.position+Vector2(12,77),"%.1f Flux | %.2fs prepare / %.2fs cooldown | Slot %02d" % [row.flux,row.startup,row.cooldown,editor.selected_slot_index+1],12,MUTED,panel.size.x-24)
	else:
		for index: int in 7:
			var element := SpellLoomEditor.ELEMENT_FILTERS[index]
			var selected := editor.selected_element_mask == 0 if element.is_empty() else (editor.selected_element_mask & int(ElementRules.MASK_BY_WIRE[ElementRules.BY_ID[element]])) != 0
			_button(canvas, geo.filters[index], SpellLoomEditor.element_filter_label(element), selected)
		_button(canvas, geo.buttons.form_previous, "<", false)
		_button(canvas, geo.buttons.form_next, ">", false)
		_text(canvas, panel.position + Vector2(70, geo.buttons.form_previous.position.y-panel.position.y+20), "Form: %s  (%d matches)" % ["All" if editor.selected_family_filter.is_empty() else editor.selected_family_filter.capitalize(), editor.filtered_spell_indices().size()], 14, PAPER, panel.size.x - 145)
		_button(canvas, geo.buttons.previous, "Previous", false)
		_button(canvas, geo.buttons.next, "Next", false)
		_button(canvas, geo.buttons.focus, "Browse " + editor.focus_area, true)
	var lines := detail_lines(editor,state,catalog,preferences,geo.body.size.x)
	if not bool(availability.get("enabled",true)):
		lines = Wrap._wrap(String(availability.get("reason","Unavailable now.")),ThemeDB.fallback_font,14,geo.body.size.x) + lines
	var count := maxi(1, floori(geo.body.size.y / 19))
	var pages := maxi(1, ceili(float(lines.size()) / count))
	var first := posmod(page,pages) * count
	for index: int in mini(count, lines.size()-first):
		_text(canvas, geo.body.position + Vector2(0, 15 + index * 19), lines[first+index], 14, PAPER, geo.body.size.x)
	_button(canvas, geo.buttons.detail_previous, "<", false)
	_button(canvas, geo.buttons.detail_next, ">", false)
	_text(canvas, geo.buttons.detail_next.end + Vector2(10,-8), "Details %d/%d" % [posmod(page,pages)+1,pages], 12, MUTED, panel.size.x - 150)
	var buttons: Dictionary = geo.buttons
	_button(canvas, buttons.starter, "Starter kit", false)
	_button(canvas, buttons.assign, "Swap" if editor.assignment_preview(state).kind == "swap" else "Assign", bool(availability.get("enabled",true)))
	_button(canvas, buttons.close, "Close", false)
	if editor.starter_preview_active():
		canvas.draw_rect(panel, Color("101c23fc"))
		_text(canvas,panel.position+Vector2(12,28),"REVIEW ALL TWELVE POSITIONS",17,PAPER,panel.size.x-24)
		var preview_count := maxi(1,floori((panel.size.y-132)/19))
		var preview_pages := maxi(1,ceili(float(lines.size())/preview_count))
		var preview_first := posmod(page,preview_pages)*preview_count
		for index: int in mini(preview_count,lines.size()-preview_first):
			_text(canvas,panel.position+Vector2(12,56+index*19),lines[preview_first+index],14,PAPER,panel.size.x-24)
		_button(canvas,buttons.detail_previous,"<",false)
		_button(canvas,buttons.detail_next,">",false)
		_text(canvas,buttons.detail_next.end+Vector2(10,-8),"Review %d/%d" % [posmod(page,preview_pages)+1,preview_pages],12,MUTED,panel.size.x-150)
		_button(canvas, buttons.assign, "Apply", true)
		_button(canvas, buttons.close, "Cancel", false)

static func pointer_action(position: Vector2, viewport: Vector2, editor: SpellLoomEditor, editable: bool = true) -> String:
	var geo := geometry(viewport,editor.reading_options_open)
	if editable and not editor.starter_preview_active() and (not geo.tight or editor.reading_options_open):
		for index: int in 7:
			if (geo.filters[index] as Rect2).has_point(position):
				editor.toggle_element_filter(SpellLoomEditor.ELEMENT_FILTERS[index])
				return "changed"
	for key: String in geo.buttons:
		if geo.tight and not editor.reading_options_open and key in ["focus","form_previous","form_next"]: continue
		if not geo.tight and key=="options": continue
		if (geo.buttons[key] as Rect2).has_point(position): return key
	return ""

static func _button(canvas: CanvasItem, rect: Rect2, text: String, selected: bool) -> void:
	canvas.draw_rect(rect, Color("305157") if selected else Color("20353e"))
	_text(canvas,rect.position+Vector2(6,20),text,13,PAPER,rect.size.x-12)

static func _text(canvas: CanvasItem, at: Vector2, value: String, size: int, color: Color, width: float) -> void:
	canvas.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)
