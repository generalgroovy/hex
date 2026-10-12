class_name SpellTestingPanel
extends RefCounted
## Local modal model + renderer. Intents never mutate a world or saved profile.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const Dev = preload("res://src/app/developer_testing_session.gd")
const StatusPolicy = preload("res://src/sim/combat/spell_status_policy.gd")
const Inspector = preload("res://src/presentation/spell_inspector_model.gd")
const StatusCatalog = preload("res://src/content/spell_status_catalog.gd")
const ScenarioPanel = preload("res://src/presentation/range_scenario_panel.gd")
const PAGE_SIZE := 7
const PAPER := Color("eadfc3")
const MUTED := Color("afbcbc")
const CYAN := Color("77dddc")
const BACK := Color("101c23f8")
const Readable = preload("res://src/presentation/readable_testing_panel.gd")
var readable := false
var detail_page := 0
var _detail_axis_latched := false
var inspection_state: PlayerState
var comparison_wire := 0
var compare_equipped := false
var range_setup_open := false
var range_setup_index := 0
var _range_scenario: Dictionary={}
var is_open := false
var mode := "range"
var selected_index := 0
var family_index := 0
var pane := 0
var tool_index := 2
var message := ""
var _rows: Array[Dictionary] = []
var _dev_view: Dictionary = {}
var _progress: SignatureProgression


func open_range(abilities: AbilityCatalog, mask: int = 1, family: String = "bolt") -> bool:
	if abilities == null: return false
	_rows = Mixtures.all()
	if _rows.size() != 63 or Mixtures.wire_for(mask, family) <= 0: return false
	# Teach the six ingredients before pairs and larger mixtures. This is only
	# presentation order; canonical catalog positions and wires remain stable.
	_rows.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_count: int = first.elements.size()
		var second_count: int = second.elements.size()
		return int(first.element_mask) < int(second.element_mask) if first_count == second_count else first_count < second_count
	)
	mode = "range"
	range_setup_open=false
	message = ""
	selected_index = 0
	for index: int in _rows.size():
		if int(_rows[index].element_mask) == mask: selected_index = index
	family_index = maxi(0, Mixtures.FAMILIES.find(family))
	pane = 0
	is_open = true
	return true


func open_challenges(champions: ChampionCatalog, abilities: AbilityCatalog, progression: SignatureProgression) -> bool:
	_rows = Challenges.rows(champions, abilities)
	if _rows.size() != 30: return false
	mode = "challenges"
	range_setup_open=false
	message = ""
	_progress = progression
	selected_index = 0
	pane = 0
	is_open = true
	return true


func open_developer(developer_view: Dictionary) -> void:
	mode = "developer"
	range_setup_open=false
	message = ""
	_dev_view = developer_view.duplicate(true)
	_rows.clear()
	for id: String in Dev.TOGGLES: _rows.append({"id": id, "name": "Pause rival commands" if id == "freeze_rival" else id.replace("_", " "), "toggle": true})
	for id: String in Dev.ACTIONS: _rows.append({"id": id, "name": id.replace("_", " "), "toggle": false})
	_rows.append({"id":"record_replay","name":"Record 60-second replay","toggle":false})
	_rows.append({"id":"export_replay","name":"Export recorded replay","toggle":false})
	selected_index = 0
	pane = 0
	is_open = true


func update_developer(developer_view: Dictionary) -> void:
	_dev_view = developer_view.duplicate(true)


func set_inspection_context(state: PlayerState, equipped_wire: int = 0) -> void:
	inspection_state = state
	comparison_wire = equipped_wire if equipped_wire > 0 else state.spell_wire_id(1) if state != null else 0


func set_range_scenario(value: Dictionary) -> void:
	_range_scenario=value.duplicate(true)


func challenge_paragraphs() -> Array[String]:
	if mode!="challenges" or _rows.is_empty(): return []
	var row: Dictionary=_rows[selected_index]
	var values: Array[String]=[String(row.spell_name),"Learned" if _progress!=null and _progress.can_equip(int(row.signature_wire)) else "Defeat this rival to learn it.",String(row.tell),String(row.counter)]
	if not String(row.get("district_label","")).is_empty(): values.insert(1,"Court: "+String(row.district_label))
	if _progress!=null:
		var path: Dictionary=_progress.view().get("learning_path",{})
		if not path.is_empty():
			var next: Dictionary=path.get("next",{})
			values.append("Optional learning path: "+String(path.title))
			values.append(String(path.lesson))
			if not next.is_empty(): values.append("Recommended next: "+String(next.name)+". "+String(next.reuse))
	return values


func inspection_paragraphs() -> Array[String]:
	if mode != "range" or _rows.is_empty(): return []
	var row: Dictionary = _rows[selected_index]
	var family := String(Mixtures.FAMILIES[family_index])
	var values := spell_paragraphs(row,family,inspection_state)
	if compare_equipped: values = Inspector.comparison(Mixtures.wire_for(int(row.element_mask),family),comparison_wire,inspection_state) + values
	return values


func close() -> void:
	is_open = false
	inspection_state = null


func set_message(text: String) -> void:
	message = text.replace("\n", " ").strip_edges()


func view() -> Dictionary:
	var selected: Dictionary = _rows[selected_index].duplicate(true) if not _rows.is_empty() else {}
	return {"open": is_open, "mode": mode, "selection": selected, "family": String(Mixtures.FAMILIES[family_index]),
		"page": floori(float(selected_index) / PAGE_SIZE), "pages": ceili(float(_rows.size()) / PAGE_SIZE), "count": _rows.size(), "pane": pane, "message": message}


static func geometry(viewport: Vector2) -> Dictionary:
	var size := Vector2(minf(900, viewport.x - 32), minf(520, viewport.y - 32))
	var panel := Rect2(((viewport - size) * 0.5).floor(), size)
	var left := Rect2(panel.position + Vector2(18, 86), Vector2(floorf((size.x - 54) * 0.55), 36))
	var right := Rect2(Vector2(left.end.x + 18, left.position.y), Vector2(size.x - left.size.x - 54, 28))
	var buttons: Array[Rect2] = []
	var utilities: Array[Rect2] = []
	var button_width := (size.x - 44) / 5.0
	for index: int in 5:
		buttons.append(Rect2(panel.position + Vector2(18 + index * (button_width + 2), size.y - 52), Vector2(button_width, 30)))
		utilities.append(Rect2(panel.position + Vector2(18 + index * (button_width + 2), size.y - 88), Vector2(button_width, 30)))
	return {"panel": panel, "left": left, "right": right, "buttons": buttons, "utilities": utilities,
		"compare":Rect2(panel.position+Vector2(panel.size.x-164,12),Vector2(146,26)),
		"setup":Rect2(panel.position+Vector2(panel.size.x-252,12),Vector2(82,26)),
		"details_previous":Rect2(Vector2(right.position.x,panel.end.y-124),Vector2(36,22)),
		"details_next":Rect2(Vector2(right.position.x+42,panel.end.y-124),Vector2(36,22)),
		"feedback": Rect2(panel.position + Vector2(18, 58), Vector2(panel.size.x - 36, 23))}


func handle_input(event: InputEvent, viewport: Vector2) -> Dictionary:
	if not is_open or _rows.is_empty(): return {}
	var compact: bool=readable and bool(Readable.geometry(viewport).tight)
	var event_key: int=(event.physical_keycode if event.physical_keycode!=0 else event.keycode) if event is InputEventKey else 0
	if mode=="range" and ((event is InputEventKey and event.pressed and not event.echo and event_key==KEY_T) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_X)):
		range_setup_open=not range_setup_open
		detail_page=0
		return {}
	if mode == "range" and event is InputEventKey and event.pressed and not event.echo and event_key == KEY_C:
		compare_equipped = not compare_equipped
		detail_page = 0
		return {}
	if mode == "range" and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		compare_equipped = not compare_equipped
		detail_page = 0
		return {}
	if event is InputEventKey and event.pressed and not event.echo and event_key in [KEY_COMMA,KEY_PERIOD]:
		detail_page += -1 if event_key==KEY_COMMA else 1
		return {}
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		if event.axis_value<0.3: _detail_axis_latched=false
		elif event.axis_value>0.7 and not _detail_axis_latched:
			detail_page += -1 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1
			_detail_axis_latched=true
		return {}
	if range_setup_open: return ScenarioPanel.input(event,viewport,self)
	if readable:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var result := Readable.pointer_action(event.position,viewport,self)
			if result.has("detail_page"):
				detail_page += int(result.detail_page)
				return {}
			return result
	var move := 0
	var page_move := 0
	var activate := false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_ESCAPE: return {"action": "close"}
			KEY_UP: move = -1
			KEY_DOWN: move = 1
			KEY_LEFT: _next_pane(-1)
			KEY_RIGHT, KEY_TAB: _next_pane(1)
			KEY_PAGEUP: page_move = -1
			KEY_PAGEDOWN: page_move = 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: activate = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK: return {"action": "close"}
			JOY_BUTTON_DPAD_UP: move = -1
			JOY_BUTTON_DPAD_DOWN: move = 1
			JOY_BUTTON_DPAD_LEFT: _next_pane(-1)
			JOY_BUTTON_DPAD_RIGHT: _next_pane(1)
			JOY_BUTTON_LEFT_SHOULDER: page_move = -1
			JOY_BUTTON_RIGHT_SHOULDER: page_move = 1
			JOY_BUTTON_A: activate = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var geo := geometry(viewport)
		if mode == "range":
			if (geo.setup as Rect2).has_point(event.position):
				range_setup_open=true
				detail_page=0
				return {}
			if (geo.compare as Rect2).has_point(event.position):
				compare_equipped = not compare_equipped
				detail_page = 0
				return {}
		for key: String in ["details_previous","details_next"]:
			if (geo[key] as Rect2).has_point(event.position):
				detail_page += -1 if key.ends_with("previous") else 1
				return {}
		var first := floori(float(selected_index) / PAGE_SIZE) * PAGE_SIZE
		for row_index: int in PAGE_SIZE:
			var rect: Rect2 = geo.left
			rect.position.y += row_index * 40
			if rect.has_point(event.position) and first + row_index < _rows.size():
				selected_index = first + row_index
				pane = 0
				return {}
		if mode == "range":
			for index: int in Mixtures.FAMILIES.size():
				var rect := family_rect(index, geo.right)
				if rect.has_point(event.position):
					family_index = index
					pane = 1
					return {}
		for index: int in geo.buttons.size():
			if (geo.buttons[index] as Rect2).has_point(event.position):
				if index == 0: page_move = -1
				elif index == 1: page_move = 1
				elif index == 2: activate = true
				elif index == 3: return {"action": "refill" if mode == "range" else "leave_developer" if mode == "developer" else "close"}
				else: return {"action": "close"}
		for index: int in geo.utilities.size():
			if (geo.utilities[index] as Rect2).has_point(event.position):
				if index < 3 and mode == "range": return {"action": ["reset_cooldowns", "reset_targets", "clear_shots"][index]}
				if index == 3: return {"action": "introduction"}
				if index == 4: return {"action": "skip_introduction"}
	if page_move != 0: selected_index = clampi(selected_index + page_move * PAGE_SIZE, 0, _rows.size() - 1)
	if compact and pane==2 and tool_index not in [2,3,4]: tool_index=2
	if move != 0:
		if pane == 2:
			if compact: tool_index=2+posmod(tool_index-2+move,3)
			else:
				tool_index = posmod(tool_index + move, 10)
				while mode != "range" and tool_index in [5, 6, 7]: tool_index = posmod(tool_index + move, 10)
		elif mode == "range" and pane == 1: family_index = posmod(family_index + move, Mixtures.FAMILIES.size())
		else: selected_index = posmod(selected_index + move, _rows.size())
	return _tool_action(compact) if activate and pane == 2 else _activate() if activate else {}


func _next_pane(direction: int) -> void:
	pane = posmod(pane + direction, 3)
	if mode != "range" and pane == 1: pane = posmod(pane + direction, 3)


func _tool_action(compact: bool = false) -> Dictionary:
	if compact:
		if tool_index not in [2,3,4]: return {}
		if mode=="range" and tool_index==3:
			range_setup_open=true
			detail_page=0
			return {}
	match tool_index:
		0, 1:
			selected_index = clampi(selected_index + (-PAGE_SIZE if tool_index == 0 else PAGE_SIZE), 0, _rows.size() - 1)
			return {}
		2: return _activate()
		3: return {"action": "refill" if mode == "range" else "leave_developer" if mode == "developer" else "close"}
		4: return {"action": "close"}
		5, 6, 7: return {"action": ["reset_cooldowns", "reset_targets", "clear_shots"][tool_index - 5]} if mode == "range" else {}
		8: return {"action": "introduction"}
		9: return {"action": "skip_introduction"}
	return {}


func _activate() -> Dictionary:
	var row: Dictionary = _rows[selected_index]
	if mode == "range": return {"action": "loaner", "mask": int(row.element_mask), "family": String(Mixtures.FAMILIES[family_index])}
	if mode == "challenges": return {"action": "challenge", "challenge_id": String(row.id)}
	var id := String(row.id)
	return {"action": "toggle", "id": id, "enabled": not bool((_dev_view.get("toggles", {}) as Dictionary).get(id, false))} if bool(row.toggle) else {"action": id}


func draw(canvas: CanvasItem, font: Font, viewport: Vector2) -> void:
	if not is_open or _rows.is_empty() or canvas == null or font == null: return
	if range_setup_open:
		ScenarioPanel.draw(canvas,font,viewport,self)
		return
	if readable:
		Readable.draw(canvas,font,viewport,self,detail_page)
		return
	var geo := geometry(viewport)
	var panel: Rect2 = geo.panel
	canvas.draw_rect(panel, BACK)
	canvas.draw_rect(panel, CYAN, false, 1)
	var title := "SPELL RANGE | 63 mixtures x 8 deliveries" if mode == "range" else "SIGNATURE CHALLENGES | learn by defeating the rival" if mode == "challenges" else "DEVELOPER SESSION | no earned progress"
	canvas.draw_string(font, panel.position + Vector2(18, 28), title, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - (276 if mode=="range" else 36), 17, PAPER)
	if mode=="range":
		canvas.draw_rect(geo.setup,Color("26414c"))
		canvas.draw_string(font,geo.setup.position+Vector2(6,18),"Setup T/X",HORIZONTAL_ALIGNMENT_LEFT,70,12,CYAN)
		canvas.draw_rect(geo.compare,Color("26414c"))
		canvas.draw_string(font,geo.compare.position+Vector2(8,18),"Compare ON" if compare_equipped else "Compare / C / Y",HORIZONTAL_ALIGNMENT_LEFT,138,12,CYAN)
	var hint := "Select mixture + delivery. Equip creates a temporary slot 1 loaner; it never casts automatically." if mode == "range" else "Every character is already playable. These victories teach 30 distinct signature spells." if mode == "challenges" else "Session-only overrides. Leave developer mode before online play; existing saves stay unchanged."
	canvas.draw_string(font, panel.position + Vector2(18, 51), hint, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 12, MUTED)
	if not message.is_empty():
		var feedback: Rect2 = geo.feedback
		canvas.draw_string(font, feedback.position + Vector2(0, 15), message, HORIZONTAL_ALIGNMENT_LEFT, feedback.size.x, 12, CYAN)
	var first := floori(float(selected_index) / PAGE_SIZE) * PAGE_SIZE
	for offset: int in PAGE_SIZE:
		var index := first + offset
		if index >= _rows.size(): break
		var rect: Rect2 = geo.left
		rect.position.y += offset * 40
		var row: Dictionary = _rows[index]
		canvas.draw_rect(rect, Color("26414c") if index == selected_index else Color("192c34"))
		if index == selected_index: canvas.draw_rect(rect, CYAN if pane == 0 else MUTED, false, 1)
		var label := String(row.get("display_name", row.get("name", "")))
		if mode == "developer" and bool(row.toggle): label += " : ON" if bool((_dev_view.get("toggles", {}) as Dictionary).get(String(row.id), false)) else " : OFF"
		canvas.draw_string(font, rect.position + Vector2(9, 23), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18, 14, PAPER)
	if mode == "range":
		for index: int in Mixtures.FAMILIES.size():
			var rect := family_rect(index, geo.right)
			canvas.draw_rect(rect, Color("26414c") if index == family_index else Color("192c34"))
			if index == family_index: canvas.draw_rect(rect, CYAN if pane == 1 else MUTED, false, 1)
			canvas.draw_string(font, rect.position + Vector2(9, 20), String(Mixtures.FAMILIES[index]).capitalize(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18, 14, PAPER)
		_draw_wide_details(canvas,font,geo,inspection_paragraphs(),74)
	else:
		var row: Dictionary = _rows[selected_index]
		var lines: Array[String] = []
		if mode == "challenges":
			lines = challenge_paragraphs()
		else: lines = ["All 30 characters are already available.", "Overrides do not grant earned spells.", "Any developer attempt gives no rewards.", "Pause rival commands stops new input; existing movement, casts and fields continue.", "Clear shots also retires active fields."]
		_draw_wide_details(canvas,font,geo,lines,18)
	var footer := "Up/Down: select | Left/Right/Tab: list, delivery, tools | PageUp/Down / LB/RB: page | Enter / A: apply"
	if mode == "range" and String(Mixtures.FAMILIES[family_index]) == "fuse": footer = "FUSE: delayed detonation. Leave the marked blast before it fires."
	canvas.draw_string(font, panel.position + Vector2(18, panel.size.y - 102), footer, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 36, 12, MUTED)
	var labels: Array[String] = ["Previous", "Next", "Equip" if mode == "range" else "Challenge" if mode == "challenges" else "Apply", "Refill" if mode == "range" else "Leave Developer" if mode == "developer" else "Back", "Close"]
	for index: int in geo.buttons.size():
		var rect: Rect2 = geo.buttons[index]
		canvas.draw_rect(rect, Color("284049"))
		if pane == 2 and tool_index == index: canvas.draw_rect(rect, CYAN, false, 2)
		canvas.draw_string(font, rect.position + Vector2(9, 21), labels[index], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18, 13, PAPER)
	var utility_labels: Array[String] = ["Reset cooldowns", "Reset targets", "Clear fields", "Introduction", "Skip guide"]
	for index: int in geo.utilities.size():
		if index < 3 and mode != "range": continue
		var rect: Rect2 = geo.utilities[index]
		canvas.draw_rect(rect, Color("24333c"))
		if pane == 2 and tool_index == index + 5: canvas.draw_rect(rect, CYAN, false, 2)
		canvas.draw_string(font, rect.position + Vector2(9, 21), utility_labels[index], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18, 12, PAPER)


func _draw_wide_details(canvas: CanvasItem,font: Font,geo: Dictionary,paragraphs: Array[String],top: float) -> void:
	var lines: Array[String]=[]
	for paragraph: String in paragraphs: lines.append_array(_wrap(paragraph,font,12,(geo.right as Rect2).size.x-8))
	var y := (geo.right as Rect2).position.y+top
	var count := maxi(1,floori(((geo.panel as Rect2).end.y-136-y)/18))
	var pages := maxi(1,ceili(float(lines.size())/count))
	var first := posmod(detail_page,pages)*count
	for index: int in mini(count,lines.size()-first):
		canvas.draw_string(font,Vector2((geo.right as Rect2).position.x,y+index*18),lines[first+index],HORIZONTAL_ALIGNMENT_LEFT,(geo.right as Rect2).size.x,12,PAPER)
	for key: String in ["details_previous","details_next"]:
		canvas.draw_rect(geo[key],Color("26414c"))
		canvas.draw_string(font,geo[key].position+Vector2(10,16),"<" if key.ends_with("previous") else ">",HORIZONTAL_ALIGNMENT_LEFT,28,12,PAPER)
	canvas.draw_string(font,geo.details_next.end+Vector2(7,-5),"%d/%d  , . / LT RT" % [posmod(detail_page,pages)+1,pages],HORIZONTAL_ALIGNMENT_LEFT,210,12,MUTED)


static func _wrap(text: String, font: Font, size: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word: String in text.split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines.append(line)
			line = word
		else: line = candidate
	if not line.is_empty(): lines.append(line)
	return lines


static func family_rect(index: int, bounds: Rect2) -> Rect2:
	var width := (bounds.size.x - 18) * 0.25
	return Rect2(bounds.position + Vector2((index % 4) * (width + 6), floorf(float(index) / 4.0) * 29), Vector2(width, bounds.size.y))


static func spell_paragraphs(mixture: Dictionary, family: String, state: PlayerState = null) -> Array[String]:
	var mask := int(mixture.get("element_mask",0))
	var wire := Mixtures.wire_for(mask,family)
	var values := Inspector.paragraphs(wire,state)
	if values.is_empty(): return values
	var ingredients := PackedStringArray()
	for element: String in mixture.get("elements",[]): ingredients.append(AbilityCatalog.element_display_name(element))
	values.append("Ingredients: "+" + ".join(ingredients))
	for row: Dictionary in StatusCatalog.rows_for_mask(mask):
		values.append("On damaging hit: "+String(row.summary)+". "+String(row.detail))
	return values


static func payload_paragraphs(mixture: Dictionary) -> Array[String]:
	var mask := int(mixture.get("element_mask", 0))
	var prefix := "TWO MATCHING PAID SOURCES: " if mask > 0 and (mask & (mask - 1)) == 0 else "PAYLOAD FIELD: "
	return [prefix + String(mixture.get("purpose", "")), "COUNTER: " + String(mixture.get("counter", ""))]
