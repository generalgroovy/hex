extends RefCounted
## Result-only surface. Inputs return intents; no encounter/save mutation here.

const Trial = preload("res://src/app/solo_duel_trial.gd")
const PAPER := Color("eadfc3")
const MUTED := Color("b8c1bf")
const ACCENT := Color("77dddc")
var selected := 0
var _selection_key := ""
var _stick_latched := false


func reset_selection() -> void:
	selected = 0
	_selection_key = ""
	_stick_latched = false


static func actions(view: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not bool(view.get("active", false)) or String(view.get("state", "")) not in ["result", "complete"]: return rows
	if bool(view.get("complete", false)):
		rows.append({"id": "circuit-try", "label": "Try learned spell"})
		rows.append({"id": "circuit-replay", "label": "Replay circuit"})
	elif bool(view.get("can_next", false)):
		rows.append({"id": "circuit-next-learned", "label": "Next with learned spell"})
		rows.append({"id": "circuit-next", "label": "Next"})
	else:
		rows.append({"id": "circuit-retry", "label": "Retry rival"})
	rows.append({"id": "circuit-leave", "label": "Leave circuit"})
	var progress: Dictionary = view.get("progress", {})
	if bool(progress.get("can_recover_backup", false)):
		rows.append({"id": "circuit-save", "label": "Recover progress backup"})
	elif bool(progress.get("can_retry_save", false)):
		rows.append({"id": "circuit-save", "label": "Retry progress save"})
	return rows


static func geometry(viewport: Vector2, view: Dictionary) -> Dictionary:
	var size := Vector2(minf(560, viewport.x - 24), minf(246, viewport.y - 24))
	var panel := Rect2(((viewport - size) * 0.5).floor(), size)
	var boxes: Array[Rect2] = []
	var rows := actions(view)
	var width := size.x - 28
	var has_save := not rows.is_empty() and String(rows.back().id) == "circuit-save"
	var ordinary_count := rows.size() - (1 if has_save else 0)
	for index: int in rows.size():
		var box := Rect2(panel.position + Vector2(14, 122), Vector2(width, 32))
		if index > 0:
			box.position.y += 38
			if ordinary_count == 3 and index < 3:
				box.size.x = (width - 8) * 0.5
				box.position.x += (box.size.x + 8) * (index - 1)
			if has_save and index == rows.size() - 1:
				box.position.y = panel.position.y + 198
				box.size.y = 26
		boxes.append(box)
	return {"panel": panel, "buttons": boxes, "text_width": width}


static func title(view: Dictionary) -> String:
	if bool(view.get("complete", false)): return "RIVAL CIRCUIT CLEARED"
	var result: Dictionary = view.get("result", {})
	if bool(result.get("qualified", false)): return "RIVAL DEFEATED"
	return {Trial.DEFEATED: "DEFEATED", Trial.TIMEOUT: "TIME EXPIRED", Trial.LEFT_COURT: "LEFT THE COURT", Trial.UNAVAILABLE: "ENCOUNTER INTERRUPTED"}.get(String(result.get("phase", "")), "RESULT NOT QUALIFIED")


static func lines(view: Dictionary) -> PackedStringArray:
	var result: Dictionary = view.get("result", {})
	var reward: Dictionary = result.get("reward", {})
	var earned := bool(result.get("qualified", false))
	var status := "saved" if bool(reward.get("saved", false)) else "not saved"
	var reward_line := "%s, %s: %s" % ["Learned" if bool(reward.get("new", false)) else "Already known", status, String(result.get("spell_name", "Signature"))] if earned else "No signature earned from this attempt."
	var elapsed := float(result.get("elapsed_ticks", 0)) / 120.0
	var health := CompactCombatHud.resource_amount_label(int(result.get("health", 0)), int(result.get("health_maximum", 0)))
	var stats := "%.2fs  |  Health %s  |  %d paid casts" % [elapsed, health, int(result.get("paid_casts", 0))]
	var hint := "Retry keeps earned spells; leaving ends this circuit."
	if bool(view.get("can_next", false)): hint = "Learned option: temporary slot 1; saved weave unchanged."
	elif bool(view.get("complete", false)):
		stats = "Encounter %.2fs total (incl. retries) | Health %s" % [float(view.get("total_elapsed_ticks", 0)) / 120.0, health]
		hint = "Try opens Spell Range; replay starts a fresh circuit."
	return PackedStringArray([
		"Rival %d / %d - %s" % [int(view.get("stage", 0)) + 1, int(view.get("total", 3)), String(result.get("name", ""))],
		stats,
		reward_line, "Each rival: fresh resources, 72s including ready time.", hint,
	])


func handle_input(event: InputEvent, viewport: Vector2, view: Dictionary) -> String:
	var rows := actions(view)
	if rows.is_empty(): return ""
	_sync_selection(view, rows.size())
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_ESCAPE: return "circuit-leave"
			KEY_UP, KEY_LEFT: selected = posmod(selected - 1, rows.size())
			KEY_DOWN, KEY_RIGHT: selected = posmod(selected + 1, rows.size())
			KEY_TAB: selected = posmod(selected + (-1 if event.shift_pressed else 1), rows.size())
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: return String(rows[selected].id)
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK: return "circuit-leave"
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT: selected = posmod(selected - 1, rows.size())
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT: selected = posmod(selected + 1, rows.size())
			JOY_BUTTON_A: return String(rows[selected].id)
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if absf(event.axis_value) < 0.35: _stick_latched = false
		elif absf(event.axis_value) > 0.6 and not _stick_latched:
			selected = posmod(selected + (1 if event.axis_value > 0 else -1), rows.size())
			_stick_latched = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var boxes: Array[Rect2] = geometry(viewport, view).buttons
		for index: int in boxes.size():
			if boxes[index].has_point(event.position):
				selected = index
				return String(rows[index].id)
	return ""


func draw(canvas: CanvasItem, font: Font, viewport: Vector2, view: Dictionary) -> void:
	var rows := actions(view)
	if canvas == null or font == null or rows.is_empty(): return
	_sync_selection(view, rows.size())
	var boxes := geometry(viewport, view)
	var panel: Rect2 = boxes.panel
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport), Color("060907c8"))
	canvas.draw_rect(panel, Color("12242bf7"))
	canvas.draw_rect(panel, ACCENT, false, 1)
	_text(canvas, font, panel.position + Vector2(14, 26), title(view), 18, PAPER, boxes.text_width)
	var body := lines(view)
	for index: int in body.size():
		_text(canvas, font, panel.position + Vector2(14, 46 + index * 17), body[index], 11 if index >= 3 else 12, ACCENT if index == 2 else MUTED, boxes.text_width)
	for index: int in rows.size():
		var box: Rect2 = boxes.buttons[index]
		canvas.draw_rect(box, Color("315e4f") if selected == index else Color("27352f"))
		canvas.draw_rect(box, ACCENT if selected == index else MUTED, false, 1)
		_text(canvas, font, box.position + Vector2(10, 21 if box.size.y >= 32 else 18), String(rows[index].label), 13, PAPER, box.size.x - 20)
	_text(canvas, font, panel.position + Vector2(14, panel.size.y - 10), "Arrows / D-pad select; Enter / A confirm; Esc / B leave", 10, MUTED, boxes.text_width)


func _sync_selection(view: Dictionary, count: int) -> void:
	var key := "%d:%d:%s" % [int(view.get("run", 0)), int(view.get("attempt", 0)), String(view.get("state", ""))]
	if key != _selection_key:
		selected = 0
		_stick_latched = false
		_selection_key = key
	selected = clampi(selected, 0, count - 1)


static func _text(canvas: CanvasItem, font: Font, point: Vector2, words: String, size: int, color: Color, width: float) -> void:
	canvas.draw_string(font, point, words, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)
