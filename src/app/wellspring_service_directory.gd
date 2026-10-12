class_name WellspringServiceDirectory
extends RefCounted
const GridNavigation = preload("res://src/app/ui_grid_navigation.gd")
const ReadableDirectory = preload("res://src/presentation/readable_service_directory.gd")
const MAX_DETAIL_LINES := 6
## A modal selection model only. The caller revalidates and dispatches one ID.

var is_open := false
var group_id := ""
var selected_index := 0
var readable_page := 0
var entries: Array[Dictionary] = []
var availability_by_station: Dictionary = {}
var card_overrides_by_station: Dictionary = {}
var _lines_by_station: Dictionary = {}
var status_text := ""
var details_visible := false
var input_source := "keyboard"
var _hover_index := -1
var _focus := WellspringServiceBuildings.new()
var _stick_x_latched := false
var _stick_y_latched := false
var _layout_viewport := Vector2.ZERO
var _layout_count := -1
var _geometry: Dictionary = {}


func open_group(group: String, stations: Array, preferred_station_id: String = "", availability: Dictionary = {}) -> bool:
	close()
	if not WellspringServiceBuildings.GROUPS.has(group):
		return false
	var candidates := WellspringServiceBuildings.commands_for_group(group, stations)
	if candidates.is_empty():
		return false
	var seen := {}
	var seen_commands := {}
	for entry: Dictionary in candidates:
		var station_id := String(entry.get("id", ""))
		var command := String(entry.get("command", ""))
		if station_id.is_empty() or seen.has(station_id) or seen_commands.has(command):
			return false
		seen[station_id] = true
		seen_commands[command] = true
	entries = candidates
	group_id = group
	availability_by_station = availability.duplicate(true)
	selected_index = 0
	for index: int in range(entries.size()):
		if String(entries[index]["id"]) == preferred_station_id:
			selected_index = index
	is_open = true
	input_source = "keyboard"
	details_visible = _focus.update_focus(selected_station_id(), 0.0, true)
	return true


func close() -> void:
	is_open = false
	group_id = ""
	entries.clear()
	availability_by_station.clear()
	card_overrides_by_station.clear()
	_lines_by_station.clear()
	status_text = ""
	selected_index = 0
	readable_page = 0
	_hover_index = -1
	details_visible = false
	_stick_x_latched = false
	_stick_y_latched = false
	_focus.clear_focus()
	_layout_count = -1
	_geometry.clear()


func selected_station_id() -> String:
	if not is_open or entries.is_empty():
		return ""
	return String(entries[selected_index]["id"])


func group_title() -> String:
	return String(WellspringServiceBuildings.group_definition(group_id).get("title", ""))


func group_hint() -> String:
	return String(WellspringServiceBuildings.group_definition(group_id).get("hint", ""))


func selected_available() -> bool:
	var value: Variant = availability_by_station.get(selected_station_id(), {})
	return bool(value.get("enabled", true)) if value is Dictionary else bool(value)


func selected_disabled_reason() -> String:
	if selected_available(): return ""
	var available: Variant = availability_by_station.get(selected_station_id(), {})
	return String(available.get("reason", "This service is not available right now.")) if available is Dictionary else "This service is not available right now."


## Live presentation only; replace each refresh so departed/stale state vanishes.
## Six-row callers reserve row zero for action/status and rows one-five for help.
## A disabled reason replaces that first row when full, retaining all five help
## rows; shorter content receives the reason as an additional first row.
func set_station_lines(lines_by_station: Dictionary) -> void:
	_lines_by_station = lines_by_station.duplicate(true)


func selected_detail_lines() -> Array[String]:
	var lines: Array[String] = []
	if not is_open or entries.is_empty():
		return lines
	var source: Variant = _lines_by_station.get(selected_station_id(), entries[selected_index].get("lines", []))
	if source is Array or source is PackedStringArray:
		for value: Variant in source:
			if value is String:
				lines.append(value)
			if lines.size() == MAX_DETAIL_LINES:
				break
	if not selected_available():
		var reason := selected_disabled_reason()
		if lines.is_empty() or lines[0] != reason:
			if lines.size() == MAX_DETAIL_LINES:
				lines[0] = reason
			else:
				lines.push_front(reason)
	return lines


func request_selected() -> String:
	if not is_open:
		return ""
	if not selected_available():
		status_text = selected_disabled_reason()
		# A click is deliberate focus, not a fresh hover. Keep the reason visible
		# across the next mouse update, even if root replaces the status subtitle.
		_hover_index = selected_index
		details_visible = _focus.update_focus(selected_station_id(), 0.0, true)
		return ""
	status_text = ""
	return selected_station_id()


func update(delta: float, pointer: Vector2, viewport_size: Vector2) -> void:
	if not is_open:
		return
	if input_source != "mouse":
		return
	var geometry := layout_for(viewport_size)
	if bool(geometry.get("compact",false)):
		details_visible = true
		return
	var index := WellspringServiceBuildings.hit_card(pointer, geometry["cards"])
	if index != _hover_index:
		status_text = ""
		_hover_index = index
		_focus.clear_focus()
	if index < 0:
		details_visible = false
		return
	selected_index = index
	details_visible = _focus.update_focus(selected_station_id(), delta)


func handle_event(event: InputEvent, pointer: Vector2, viewport_size: Vector2) -> String:
	if not is_open or event == null:
		return ""
	if InputMap.has_action(InputRouter.INTERACT_ACTION) and event.is_action_pressed(InputRouter.INTERACT_ACTION) and not event.is_echo() and not _reserved_navigation(event):
		input_source = "controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard"
		return request_selected()
	if bool(layout_for(viewport_size).get("compact",false)):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion: input_source = "controller"
		elif event is InputEventKey: input_source = "keyboard"
		elif event is InputEventMouseButton or event is InputEventMouseMotion: input_source = "mouse"
		details_visible = true
		return ReadableDirectory.handle_input(self,event,pointer,viewport_size)
	if event is InputEventMouseMotion:
		input_source = "mouse"
		update(0.0, pointer, viewport_size)
	elif event is InputEventMouseButton and event.pressed:
		input_source = "mouse"
		var geometry := layout_for(viewport_size)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if (geometry["close"] as Rect2).has_point(pointer):
				close()
				return ""
			var index := WellspringServiceBuildings.hit_card(pointer, geometry["cards"])
			if index >= 0:
				selected_index = index
				return request_selected()
	elif event is InputEventKey and event.pressed and not event.echo:
		input_source = "keyboard"
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_ESCAPE:
				close()
			KEY_LEFT, KEY_A:
				_move(-1, 0, viewport_size)
			KEY_RIGHT, KEY_D:
				_move(1, 0, viewport_size)
			KEY_TAB:
				selected_index = posmod(selected_index + (-1 if event.shift_pressed else 1), entries.size())
				_move(0, 0, viewport_size)
			KEY_UP, KEY_W:
				_move(0, -1, viewport_size)
			KEY_DOWN, KEY_S:
				_move(0, 1, viewport_size)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				return request_selected()
	elif event is InputEventJoypadButton and event.pressed:
		input_source = "controller"
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				close()
			JOY_BUTTON_DPAD_LEFT:
				_move(-1, 0, viewport_size)
			JOY_BUTTON_DPAD_RIGHT:
				_move(1, 0, viewport_size)
			JOY_BUTTON_DPAD_UP:
				_move(0, -1, viewport_size)
			JOY_BUTTON_DPAD_DOWN:
				_move(0, 1, viewport_size)
			JOY_BUTTON_A:
				return request_selected()
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			if absf(event.axis_value) < 0.35:
				_stick_x_latched = false
			elif absf(event.axis_value) > 0.65 and not _stick_x_latched:
				input_source = "controller"
				_stick_x_latched = true
				_move(1 if event.axis_value > 0 else -1, 0, viewport_size)
		elif event.axis == JOY_AXIS_LEFT_Y:
			if absf(event.axis_value) < 0.35:
				_stick_y_latched = false
			elif absf(event.axis_value) > 0.65 and not _stick_y_latched:
				input_source = "controller"
				_stick_y_latched = true
				_move(0, 1 if event.axis_value > 0 else -1, viewport_size)
	return ""


static func _reserved_navigation(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return key in [KEY_ESCAPE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if event is InputEventJoypadButton:
		return event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_A, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]
	if event is InputEventJoypadMotion:
		return event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT


func _move(horizontal: int, vertical: int, viewport_size: Vector2) -> void:
	var geometry := layout_for(viewport_size)
	var columns := int(geometry["columns"])
	selected_index = GridNavigation.neighbor(selected_index, entries.size(), columns, horizontal, vertical)
	status_text = ""
	_hover_index = -1
	details_visible = _focus.update_focus(selected_station_id(), 0.0, true)


func layout_for(viewport_size: Vector2) -> Dictionary:
	if viewport_size == _layout_viewport and entries.size() == _layout_count and not _geometry.is_empty():
		return _geometry
	_layout_viewport = viewport_size
	_layout_count = entries.size()
	if viewport_size.x < 700 or viewport_size.y < 500:
		_geometry = ReadableDirectory.geometry(viewport_size)
		return _geometry
	var width := minf(760.0, maxf(240.0, viewport_size.x - 32.0))
	var columns := WellspringServiceBuildings.card_columns(width - 32.0, entries.size())
	var rows := ceili(float(maxi(1, entries.size())) / float(columns))
	var desired_grid_height := float(rows * 76 - 8)
	var height := minf(202.0 + desired_grid_height, maxf(180.0, viewport_size.y - 32.0))
	var panel := Rect2(((viewport_size - Vector2(width, height)) * 0.5).round(), Vector2(width, height))
	var cards_area := Rect2(panel.position + Vector2(16, 58), Vector2(width - 32.0, height - 202.0))
	var cards := WellspringServiceBuildings.card_rectangles(cards_area, entries.size())
	_geometry = {
		"panel": panel,
		"cards": cards,
		"columns": columns,
		"close": Rect2(panel.end.x - 40.0, panel.position.y + 10.0, 28, 28),
		"details": Rect2(panel.position.x + 16.0, panel.end.y - 130.0, width - 32.0, 94),
	}
	return _geometry


func draw(canvas: CanvasItem, viewport_size: Vector2) -> void:
	if canvas == null or not is_open:
		return
	var geometry := layout_for(viewport_size)
	if bool(geometry.get("compact",false)):
		ReadableDirectory.draw(canvas,viewport_size,self)
		return
	var panel: Rect2 = geometry["panel"]
	var font := ThemeDB.fallback_font
	var group := WellspringServiceBuildings.group_definition(group_id)
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.05, 0.07, 0.60))
	canvas.draw_rect(panel, WellspringServiceBuildings.INK)
	canvas.draw_rect(panel.grow(-3), WellspringServiceBuildings.STONE, false, 2.0)
	canvas.draw_string(font, panel.position + Vector2(16, 27), String(group["title"]), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 17, WellspringServiceBuildings.PARCHMENT)
	canvas.draw_string(font, panel.position + Vector2(16, 45), String(group["hint"]) if status_text.is_empty() else status_text, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 11, WellspringServiceBuildings.STONE_LIGHT)
	var close_rect: Rect2 = geometry["close"]
	canvas.draw_rect(close_rect, WellspringServiceBuildings.STONE, false, 1.0)
	canvas.draw_string(font, close_rect.position + Vector2(0, 20), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 14, WellspringServiceBuildings.PARCHMENT)
	var cards: Array[Rect2] = geometry["cards"]
	for index: int in range(cards.size()):
		var overrides: Dictionary = card_overrides_by_station.get(String(entries[index]["id"]), {})
		WellspringServiceBuildings.draw_card(canvas, cards[index], entries[index], selected_index == index, "", String(overrides.get("title", "")), String(overrides.get("hint", "")))
		var available: Variant = availability_by_station.get(String(entries[index]["id"]), {})
		var enabled := bool(available.get("enabled", true)) if available is Dictionary else bool(available)
		if not enabled:
			canvas.draw_rect(cards[index].grow(-2), Color(0.12, 0.12, 0.14, 0.50))
	var detail: Rect2 = geometry["details"]
	canvas.draw_line(detail.position, Vector2(detail.end.x, detail.position.y), WellspringServiceBuildings.STONE, 1.0)
	if cards.is_empty():
		canvas.draw_string(font, detail.position + Vector2(0, 23), "Increase window size to show the service cards.", HORIZONTAL_ALIGNMENT_LEFT, detail.size.x, 12, WellspringServiceBuildings.PARCHMENT)
	elif details_visible and not entries.is_empty():
		var lines := selected_detail_lines()
		for index: int in range(lines.size()):
			canvas.draw_string(font, detail.position + Vector2(0, 17 + index * 14), String(lines[index]), HORIZONTAL_ALIGNMENT_LEFT, detail.size.x, 11, WellspringServiceBuildings.PARCHMENT)
	else:
		canvas.draw_string(font, detail.position + Vector2(0, 23), "Hover a card for details.", HORIZONTAL_ALIGNMENT_LEFT, detail.size.x, 11, WellspringServiceBuildings.STONE_LIGHT)
	canvas.draw_string(font, Vector2(panel.position.x + 16, panel.end.y - 13), "Arrows / WASD: select    Enter / A: open    Esc / B: back", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 10, WellspringServiceBuildings.STONE_LIGHT)
