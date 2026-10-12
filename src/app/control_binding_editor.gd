class_name ControlBindingEditor
extends RefCounted


const DEVICE_KEYBOARD: int = 0
const DEVICE_MOUSE: int = 1
const DEVICE_CONTROLLER: int = 2
const DEVICE_COUNT: int = 3
const ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"sprint",
	&"slide",
	&"jump",
	&"technique",
	&"evade",
	&"punch",
	&"kick",
	&"primary",
	&"active_1",
	&"interact",
	&"emote",
	&"spell_1",
	&"spell_2",
	&"spell_3",
	&"spell_4",
	&"spell_layer_ctrl",
	&"spell_layer_alt",
	&"practice_trace",
	&"practice_retry",
	&"aim_left", &"aim_right", &"aim_up", &"aim_down",
]
const ACTION_LABELS: Dictionary[StringName, String] = {
	&"aim_left":"AIM LEFT", &"aim_right":"AIM RIGHT", &"aim_up":"AIM UP", &"aim_down":"AIM DOWN",
	&"move_left": "MOVE LEFT",
	&"move_right": "MOVE RIGHT",
	&"move_up": "MOVE UP",
	&"move_down": "MOVE DOWN",
	&"sprint": "SPRINT",
	&"slide": "SLIDE / FAST-FALL",
	&"jump": "JUMP",
	&"technique": "WALL / AIR TURN / TECH",
	&"evade": "EVADE (ROLL / AIR DODGE)",
	&"punch": "PUNCH (UNAVAILABLE)",
	&"kick": "KICK (UNAVAILABLE)",
	&"primary": "PRIMARY SPELL",
	&"active_1": "ACTIVE SPELL",
	&"interact": "INTERACT",
	&"emote": "TALK",
	&"spell_1": "SPELL BUTTON 1",
	&"spell_2": "SPELL BUTTON 2",
	&"spell_3": "SPELL BUTTON 3",
	&"spell_4": "SPELL BUTTON 4",
	&"spell_layer_ctrl": "SPELL CTRL LAYER",
	&"spell_layer_alt": "SPELL ALT LAYER",
	&"practice_trace": "PRACTICE TRACE ON / OFF",
	&"practice_retry": "RECORD NEXT PRACTICE RUN",
}
const DEVICE_LABELS: Array[String] = ["KEYBOARD", "MOUSE", "CONTROLLER"]
const RESERVED_KEYBOARD_BINDINGS: Dictionary[int, String] = {
	KEY_ESCAPE: "ESC cancels binding capture.",
	KEY_F4: "F4 opens the Compendium and cannot be a gameplay binding.",
}
const RESERVED_CONTROLLER_BUTTON_BINDINGS: Dictionary[int, String] = {
	JOY_BUTTON_BACK: "BACK cancels binding capture and opens the Compendium.",
}
const VISIBLE_ROWS: int = 12
const PANEL_RECT := Rect2(116, 126, 1048, 548)
const FIRST_ROW_Y: float = 222.0
const ROW_HEIGHT: float = 31.0
const ACTION_X: float = 154.0
const ACTION_WIDTH: float = 258.0
const DEVICE_X: float = 430.0
const DEVICE_WIDTH: float = 226.0

var is_open: bool = false
var capturing: bool = false
var selected_action_index: int = 0
var selected_device: int = DEVICE_KEYBOARD
var first_visible_row: int = 0
var status_message: String = "Choose a binding to change."
var migration_notices: Array[Dictionary] = []


func open_editor() -> void:
	is_open = true
	capturing = false
	status_message = (
		String(migration_notices.front().get("message", ""))
		if not migration_notices.is_empty()
		else "Choose a binding to change."
	)


func close_editor() -> void:
	is_open = false
	capturing = false
	status_message = ""


func selected_action() -> StringName:
	return ACTIONS[selected_action_index]


func move_selection(row_delta: int, device_delta: int) -> void:
	selected_action_index = posmod(selected_action_index + row_delta, ACTIONS.size())
	selected_device = posmod(selected_device + device_delta, DEVICE_COUNT)
	_ensure_selection_visible()
	capturing = false
	status_message = "Choose a binding to change."


func select_cell(position: Vector2) -> bool:
	if position.y < FIRST_ROW_Y or position.y >= FIRST_ROW_Y + ROW_HEIGHT * VISIBLE_ROWS:
		return false
	if position.x < DEVICE_X or position.x >= DEVICE_X + DEVICE_WIDTH * DEVICE_COUNT:
		return false
	selected_action_index = clampi(first_visible_row + int((position.y - FIRST_ROW_Y) / ROW_HEIGHT), 0, ACTIONS.size() - 1)
	selected_device = clampi(int((position.x - DEVICE_X) / DEVICE_WIDTH), 0, DEVICE_COUNT - 1)
	begin_capture()
	return true


func begin_capture() -> void:
	capturing = true
	status_message = "Press a %s input \u00b7 Esc cancels" % DEVICE_LABELS[selected_device].to_lower()


func visible_action_indices() -> Array[int]:
	var result: Array[int] = []
	for index: int in range(first_visible_row, mini(ACTIONS.size(), first_visible_row + VISIBLE_ROWS)):
		result.append(index)
	return result


func cancel_capture() -> void:
	capturing = false
	status_message = "Binding unchanged."


func unbind_selected(preferences: PlayerPreferences) -> bool:
	var replacement: Variant = 0
	if selected_device == DEVICE_CONTROLLER:
		replacement = PlayerPreferences.unbound_controller_binding()
	return _assign_with_swap(preferences, replacement)


func reset_bindings(preferences: PlayerPreferences) -> void:
	preferences.keyboard_bindings = PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS.duplicate()
	preferences.mouse_bindings = PlayerPreferences.DEFAULT_MOUSE_BINDINGS.duplicate()
	preferences.controller_bindings = PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	set_migration_notices([])
	capturing = false
	status_message = "Safe defaults restored."


func set_migration_notices(notices: Array) -> void:
	migration_notices.clear()
	for notice_value: Variant in notices:
		if not notice_value is Dictionary:
			continue
		var notice: Dictionary = notice_value
		var message := String(notice.get("message", "")).strip_edges()
		if message.is_empty():
			continue
		migration_notices.append(notice.duplicate(true))
	if not capturing and not migration_notices.is_empty():
		status_message = String(migration_notices.front().get("message", ""))


func migration_notice_lines() -> Array[String]:
	var result: Array[String] = []
	for notice: Dictionary in migration_notices:
		result.append(String(notice.get("message", "")))
	return result


func capture_event(event: InputEvent, preferences: PlayerPreferences) -> bool:
	if not capturing:
		return false
	var replacement: Variant
	if selected_device == DEVICE_KEYBOARD:
		if not event is InputEventKey:
			return false
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		replacement = int(key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode)
		if RESERVED_KEYBOARD_BINDINGS.has(replacement):
			status_message = RESERVED_KEYBOARD_BINDINGS[replacement]
			return false
	elif selected_device == DEVICE_MOUSE:
		if not event is InputEventMouseButton:
			return false
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return false
		replacement = int(mouse_event.button_index)
	else:
		if event is InputEventJoypadButton:
			var button_event := event as InputEventJoypadButton
			if not button_event.pressed:
				return false
			if RESERVED_CONTROLLER_BUTTON_BINDINGS.has(button_event.button_index):
				status_message = RESERVED_CONTROLLER_BUTTON_BINDINGS[button_event.button_index]
				return false
			replacement = {"kind": "button", "index": int(button_event.button_index), "direction": 0}
		elif event is InputEventJoypadMotion:
			var motion_event := event as InputEventJoypadMotion
			if absf(motion_event.axis_value) < 0.75:
				return false
			replacement = {"kind": "axis", "index": int(motion_event.axis), "direction": -1 if motion_event.axis_value < 0.0 else 1}
		else:
			return false
	return _assign_with_swap(preferences, replacement)


func binding_label(action: StringName, device: int, preferences: PlayerPreferences) -> String:
	if device == DEVICE_KEYBOARD:
		var keycode: int = int(preferences.keyboard_bindings.get(action, 0))
		return "\u2014" if keycode == 0 else OS.get_keycode_string(keycode)
	if device == DEVICE_MOUSE:
		return _mouse_label(int(preferences.mouse_bindings.get(action, 0)))
	var descriptor: Dictionary = preferences.controller_bindings.get(action, PlayerPreferences.unbound_controller_binding())
	return _controller_label(descriptor)


func _assign_with_swap(preferences: PlayerPreferences, replacement: Variant) -> bool:
	var action := selected_action()
	var bindings: Dictionary
	if selected_device == DEVICE_KEYBOARD:
		bindings = preferences.keyboard_bindings.duplicate()
	elif selected_device == DEVICE_MOUSE:
		bindings = preferences.mouse_bindings.duplicate()
	else:
		bindings = preferences.controller_bindings.duplicate(true)
	var previous: Variant = bindings.get(action, 0 if selected_device != DEVICE_CONTROLLER else PlayerPreferences.unbound_controller_binding())
	var conflict_action := StringName()
	var replacement_signature := _binding_signature(replacement, selected_device)
	if not replacement_signature.is_empty():
		for raw_action: Variant in bindings:
			var candidate_action := StringName(str(raw_action))
			if candidate_action != action and _binding_signature(bindings[raw_action], selected_device) == replacement_signature:
				conflict_action = candidate_action
				break
	bindings[action] = replacement
	if not conflict_action.is_empty():
		bindings[conflict_action] = previous
	var validation_error: String
	if selected_device == DEVICE_KEYBOARD:
		validation_error = PlayerPreferences.validate_keyboard_bindings(bindings)
	elif selected_device == DEVICE_MOUSE:
		validation_error = PlayerPreferences.validate_mouse_bindings(bindings)
	else:
		validation_error = PlayerPreferences.validate_controller_bindings(bindings)
	if not validation_error.is_empty():
		status_message = validation_error
		capturing = false
		return false
	if selected_device == DEVICE_KEYBOARD:
		preferences.keyboard_bindings = bindings
	elif selected_device == DEVICE_MOUSE:
		preferences.mouse_bindings = bindings
	else:
		preferences.controller_bindings = bindings
	capturing = false
	status_message = "Swapped with %s." % ACTION_LABELS.get(conflict_action, String(conflict_action)) if not conflict_action.is_empty() else "Binding saved."
	return true


static func _binding_signature(value: Variant, device: int) -> String:
	if device != DEVICE_CONTROLLER:
		var numeric := int(value)
		return "" if numeric == 0 else str(numeric)
	if not value is Dictionary:
		return ""
	var descriptor: Dictionary = value
	var kind := String(descriptor.get("kind", "none"))
	if kind == "none":
		return ""
	return "%s:%d:%d" % [kind, int(descriptor.get("index", -1)), int(descriptor.get("direction", 0))]


func _ensure_selection_visible() -> void:
	if selected_action_index < first_visible_row:
		first_visible_row = selected_action_index
	elif selected_action_index >= first_visible_row + VISIBLE_ROWS:
		first_visible_row = selected_action_index - VISIBLE_ROWS + 1
	first_visible_row = clampi(first_visible_row, 0, maxi(0, ACTIONS.size() - VISIBLE_ROWS))


static func _mouse_label(button: int) -> String:
	match button:
		0:
			return "\u2014"
		MOUSE_BUTTON_LEFT:
			return "LEFT BUTTON"
		MOUSE_BUTTON_RIGHT:
			return "RIGHT BUTTON"
		MOUSE_BUTTON_MIDDLE:
			return "MIDDLE BUTTON"
		MOUSE_BUTTON_WHEEL_UP:
			return "WHEEL UP"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "WHEEL DOWN"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "WHEEL LEFT"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "WHEEL RIGHT"
		_:
			return "BUTTON %d" % button


static func _controller_label(descriptor: Dictionary) -> String:
	var kind := String(descriptor.get("kind", "none"))
	var index := int(descriptor.get("index", -1))
	if kind == "none":
		return "\u2014"
	if kind == "axis":
		var axis_names := ["LEFT X", "LEFT Y", "RIGHT X", "RIGHT Y", "LEFT TRIGGER", "RIGHT TRIGGER"]
		var axis_name: String = axis_names[index] if index >= 0 and index < axis_names.size() else "AXIS %d" % index
		return "%s %s" % [axis_name, "\u2212" if int(descriptor.get("direction", 0)) < 0 else "+"]
	var button_names := ["SOUTH / A", "EAST / B", "WEST / X", "NORTH / Y", "BACK", "GUIDE", "START", "L STICK", "R STICK", "L SHOULDER", "R SHOULDER", "DPAD UP", "DPAD DOWN", "DPAD LEFT", "DPAD RIGHT"]
	return button_names[index] if index >= 0 and index < button_names.size() else "BUTTON %d" % index


func selected_migration_notice() -> String:
	var selected_action := ACTIONS[selected_action_index]
	for notice: Dictionary in migration_notices:
		if notice.get("severity", "") == "action" and (StringName(notice.get("action", "")) == selected_action or StringName(notice.get("conflicting_action", "")) == selected_action):
			return "Migration: " + String(notice.message)
	return ""
