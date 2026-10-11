extends RefCounted


# Saved bindings, not a guess about the active device. Keep the explicit keyboard
# assignment first, then mouse, then pad. InputRouter combines these same actions
# across devices, so a modifier and spell button may legitimately use two devices.
# Empty means no saved binding; callers retain their own unknown/unbound wording.
static func action_label(action: StringName, preferences: PlayerPreferences) -> String:
	if preferences == null: return ""
	var key := int(preferences.keyboard_bindings.get(action, 0))
	if key != 0: return OS.get_keycode_string(key)
	var mouse := _mouse_label(int(preferences.mouse_bindings.get(action, 0)))
	if not mouse.is_empty(): return mouse
	return _controller_label(preferences.controller_bindings.get(action))


static func _mouse_label(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT: return "MOUSE L"
		MOUSE_BUTTON_RIGHT: return "MOUSE R"
		MOUSE_BUTTON_MIDDLE: return "MOUSE M"
		MOUSE_BUTTON_WHEEL_UP: return "WHEEL UP"
		MOUSE_BUTTON_WHEEL_DOWN: return "WHEEL DN"
		MOUSE_BUTTON_WHEEL_LEFT: return "WHEEL L"
		MOUSE_BUTTON_WHEEL_RIGHT: return "WHEEL R"
		MOUSE_BUTTON_XBUTTON1: return "MOUSE X1"
		MOUSE_BUTTON_XBUTTON2: return "MOUSE X2"
	return ""


static func _controller_label(value: Variant) -> String:
	if not value is Dictionary: return ""
	var kind: Variant = value.get("kind")
	var index: Variant = value.get("index")
	var direction: Variant = value.get("direction")
	if not kind is String or typeof(index) != TYPE_INT or typeof(direction) != TYPE_INT: return ""
	if kind == "button" and index >= 0 and index <= 31 and direction == 0:
		var names := ["A", "B", "X", "Y", "BK", "GD", "ST", "LS", "RS", "LB", "RB", "UP", "DN", "LEFT", "RGT"]
		return "PAD " + (String(names[index]) if index < names.size() else "B%d" % index)
	if kind == "axis" and index >= 0 and index <= 15 and direction in [-1, 1]:
		var names := ["LX", "LY", "RX", "RY", "L2", "R2"]
		var axis := String(names[index]) if index < names.size() else "A%d" % index
		return "PAD " + axis + ("-" if direction < 0 else "+")
	return ""
