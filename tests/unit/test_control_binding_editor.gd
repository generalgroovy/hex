extends FluxTestSuite


func run() -> int:
	_test_navigation_and_capture()
	_test_conflict_swap_unbind_and_reset()
	_test_device_filtering()
	_test_reserved_fixed_ui_binding()
	_test_s4_melee_rows_and_migration_notices()
	return finish("control-binding-editor")


func _test_navigation_and_capture() -> void:
	var editor := ControlBindingEditor.new()
	var preferences := PlayerPreferences.new()
	editor.open_editor()
	check(editor.is_open, "editor opens explicitly")
	equal(editor.selected_action(), &"move_left", "editor begins on first gameplay action")
	editor.move_selection(-1, -1)
	equal(editor.selected_action(), &"practice_retry", "row navigation wraps across all spell buttons and layers")
	equal(editor.selected_device, ControlBindingEditor.DEVICE_CONTROLLER, "device navigation wraps")
	equal(editor.visible_action_indices().front(), ControlBindingEditor.ACTIONS.size() - ControlBindingEditor.VISIBLE_ROWS, "wrapped spell selection scrolls the first visible row")
	equal(editor.visible_action_indices().back(), ControlBindingEditor.ACTIONS.size() - 1, "scrolled editor keeps the selected spell-layer row visible")
	check(editor.select_cell(Vector2(ControlBindingEditor.DEVICE_X + 4, ControlBindingEditor.FIRST_ROW_Y + 4)), "visible scrolled cell can be selected")
	equal(editor.selected_action_index, ControlBindingEditor.ACTIONS.size() - ControlBindingEditor.VISIBLE_ROWS, "mouse selection includes the scroll offset")
	editor.cancel_capture()
	editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
	editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	editor.begin_capture()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	check(editor.capture_event(key, preferences), "keyboard capture applies")
	equal(preferences.keyboard_bindings[&"jump"], KEY_J, "captured physical key is stored")
	equal(editor.binding_label(&"jump", ControlBindingEditor.DEVICE_KEYBOARD, preferences), "J", "keyboard binding has a readable label")
	editor.close_editor()
	check(not editor.is_open and not editor.capturing, "closing editor cancels capture state")


func _test_conflict_swap_unbind_and_reset() -> void:
	var editor := ControlBindingEditor.new()
	var preferences := PlayerPreferences.new()
	editor.open_editor()
	editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
	editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	editor.begin_capture()
	var c_key := InputEventKey.new()
	c_key.physical_keycode = KEY_C
	c_key.pressed = true
	check(editor.capture_event(c_key, preferences), "capturing an occupied key performs a safe swap")
	equal(preferences.keyboard_bindings[&"jump"], KEY_C, "selected action receives occupied key")
	equal(preferences.keyboard_bindings[&"slide"], KEY_SPACE, "conflicting action receives selected action's previous key")
	check("SWAPPED" in editor.status_message.to_upper(), "swap is disclosed to the player")
	check(editor.unbind_selected(preferences), "selected keyboard lane can be unbound")
	equal(preferences.keyboard_bindings[&"jump"], 0, "unbind stores the explicit empty binding")
	editor.reset_bindings(preferences)
	equal(preferences.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "reset restores keyboard defaults")
	equal(preferences.mouse_bindings, PlayerPreferences.DEFAULT_MOUSE_BINDINGS, "reset restores mouse defaults")
	equal(preferences.controller_bindings, PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS, "reset restores controller defaults")
	equal(editor.binding_label(&"evade", ControlBindingEditor.DEVICE_KEYBOARD, preferences), "B", "editor displays the conflict-free default evade key")
	equal(editor.binding_label(&"technique", ControlBindingEditor.DEVICE_KEYBOARD, preferences), "V", "editor displays Technique's requested V default")
	editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
	editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	editor.begin_capture()
	var f_key := InputEventKey.new()
	f_key.physical_keycode = KEY_F
	f_key.pressed = true
	check(editor.capture_event(f_key, preferences), "gameplay and interaction actions share one conflict-safe namespace")
	equal(preferences.keyboard_bindings[&"interact"], KEY_SPACE, "occupying interact swaps its prior key instead of double-triggering")


func _test_device_filtering() -> void:
	var editor := ControlBindingEditor.new()
	var preferences := PlayerPreferences.new()
	editor.open_editor()
	editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"sprint")
	editor.selected_device = ControlBindingEditor.DEVICE_MOUSE
	editor.begin_capture()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	check(not editor.capture_event(key, preferences), "mouse capture ignores keyboard input")
	check(editor.capturing, "ignored device input leaves capture armed")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	mouse.pressed = true
	check(editor.capture_event(mouse, preferences), "mouse capture accepts auxiliary buttons")
	equal(preferences.mouse_bindings[&"sprint"], MOUSE_BUTTON_XBUTTON1, "mouse binding is stored on the selected action")
	editor.selected_device = ControlBindingEditor.DEVICE_CONTROLLER
	editor.begin_capture()
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = -0.9
	check(editor.capture_event(axis, preferences), "controller capture accepts a deliberate axis direction")
	var descriptor: Dictionary = preferences.controller_bindings[&"sprint"]
	equal(String(descriptor.get("kind")), "axis", "controller axis kind is stored")
	equal(int(descriptor.get("direction")), -1, "controller axis direction is stored")


func _test_reserved_fixed_ui_binding() -> void:
	var editor := ControlBindingEditor.new()
	var preferences := PlayerPreferences.new()
	editor.open_editor()
	editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
	editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	editor.begin_capture()
	var before: Dictionary = preferences.to_dictionary().duplicate(true)
	var field_guide_key := InputEventKey.new()
	field_guide_key.physical_keycode = KEY_F4
	field_guide_key.keycode = KEY_F4
	field_guide_key.pressed = true
	check(not editor.capture_event(field_guide_key, preferences), "fixed Compendium shortcut cannot be accepted as a gameplay binding")
	check(editor.capturing, "rejected fixed UI shortcut leaves capture armed for a usable input")
	equal(preferences.to_dictionary(), before, "rejected fixed UI shortcut cannot mutate persisted controls")
	check("F4" in editor.status_message and "COMPENDIUM" in editor.status_message.to_upper(), "rejection identifies the fixed shortcut and its owner")
	var escape_key := InputEventKey.new()
	escape_key.physical_keycode = KEY_ESCAPE
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	check(not editor.capture_event(escape_key, preferences), "editor API cannot persist the keyboard capture-cancel key")
	check(editor.capturing and "ESC" in editor.status_message, "direct Escape rejection remains armed and identifies the cancel key")
	equal(preferences.to_dictionary(), before, "Escape rejection cannot mutate persisted controls")
	editor.selected_device = ControlBindingEditor.DEVICE_CONTROLLER
	editor.begin_capture()
	var back_button := InputEventJoypadButton.new()
	back_button.button_index = JOY_BUTTON_BACK
	back_button.pressed = true
	check(not editor.capture_event(back_button, preferences), "editor API cannot persist the controller capture-cancel button")
	check(editor.capturing and "BACK" in editor.status_message, "direct Back rejection remains armed and identifies the cancel button")
	equal(preferences.to_dictionary(), before, "Back rejection cannot mutate persisted controls")


func _test_s4_melee_rows_and_migration_notices() -> void:
	var editor := ControlBindingEditor.new()
	var preferences := PlayerPreferences.new()
	check(ControlBindingEditor.ACTIONS.has(&"punch") and ControlBindingEditor.ACTIONS.has(&"kick"), "binding editor exposes dedicated Punch and Kick rows")
	equal(ControlBindingEditor.ACTION_LABELS[&"punch"], "PUNCH (UNAVAILABLE)", "Punch row discloses that melee is unavailable")
	equal(ControlBindingEditor.ACTION_LABELS[&"kick"], "KICK (UNAVAILABLE)", "Kick row discloses that melee is unavailable")
	equal(editor.binding_label(&"punch", ControlBindingEditor.DEVICE_MOUSE, preferences), "LEFT BUTTON", "Punch row displays its left mouse default")
	equal(editor.binding_label(&"kick", ControlBindingEditor.DEVICE_MOUSE, preferences), "RIGHT BUTTON", "Kick row displays its right mouse default")
	equal(editor.binding_label(&"punch", ControlBindingEditor.DEVICE_KEYBOARD, preferences), "—", "Punch row discloses its unbound keyboard lane")
	equal(editor.binding_label(&"kick", ControlBindingEditor.DEVICE_CONTROLLER, preferences), "—", "Kick row discloses its unbound controller lane")
	var notices: Array = [
		{
			"code": "evade_moved_q_to_b",
			"severity": "info",
			"device": "keyboard",
			"action": &"evade",
			"requested_binding": KEY_B,
			"conflicting_action": StringName(),
			"message": "Evade moved from Q to B in the new default layout.",
		},
		{"code": "ignored", "message": ""},
		"malformed",
	]
	editor.set_migration_notices(notices)
	equal(editor.migration_notice_lines(), ["Evade moved from Q to B in the new default layout."], "editor projects only clear nonempty migration notice text")
	check(editor.status_message.contains("Q to B"), "first migration notice is immediately available to the controls UI")
	(notices[0] as Dictionary)["message"] = "caller changed"
	equal(editor.migration_notice_lines(), ["Evade moved from Q to B in the new default layout."], "editor owns a deep copy of transient notice data")
	editor.reset_bindings(preferences)
	equal(editor.migration_notices.size(), 0, "explicit default reset clears obsolete migration notices")
