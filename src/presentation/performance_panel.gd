extends RefCounted
## A local presentation preference surface. No simulation options live here.

const LIMITS := [60, 120, 0]
var is_open := false
var selected := 0
var message := ""
var _stick_latched := false

func open() -> void:
	is_open = true
	selected = 0
	message = ""
	_stick_latched = false

func close() -> void:
	is_open = false
	_stick_latched = false

static func panel_rect(viewport: Vector2) -> Rect2:
	var size := Vector2(424, 260)
	return Rect2((viewport - size) * 0.5, size)

static func row_rect(viewport: Vector2, index: int) -> Rect2:
	return Rect2(panel_rect(viewport).position + Vector2(16, 54 + 42 * index), Vector2(392, 36))

static func changed_value(index: int, direction: int, preferences: PlayerPreferences) -> Dictionary:
	if index == 0:
		return {"render_quality": "standard" if preferences.render_quality == "low" else "low"}
	if index == 1:
		return {"frame_limit": LIMITS[posmod(LIMITS.find(preferences.frame_limit) + direction, LIMITS.size())]}
	return {}

func handle_input(event: InputEvent, viewport: Vector2, preferences: PlayerPreferences) -> Dictionary:
	if not is_open: return {}
	var direction := 0
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_ESCAPE: return {"close": true}
			KEY_UP, KEY_DOWN: selected = 1 - selected
			KEY_TAB: selected = 1 - selected
			KEY_LEFT: direction = -1
			KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER: direction = 1
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK: return {"close": true}
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN: selected = 1 - selected
			JOY_BUTTON_DPAD_LEFT: direction = -1
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A: direction = 1
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if absf(event.axis_value) < 0.35: _stick_latched = false
		elif absf(event.axis_value) > 0.6 and not _stick_latched:
			if event.axis == JOY_AXIS_LEFT_Y: selected = 1 - selected
			else: direction = 1 if event.axis_value > 0 else -1
			_stick_latched = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for index: int in 2:
			var row := row_rect(viewport, index)
			if row.has_point(event.position):
				selected = index
				direction = -1 if event.position.x < row.get_center().x else 1
				break
	return changed_value(selected, direction, preferences) if direction != 0 else {}

func draw(canvas: CanvasItem, font: Font, viewport: Vector2, preferences: PlayerPreferences) -> void:
	var rect := panel_rect(viewport)
	var ink := Color("eee0b8")
	var muted := Color("acbebd")
	canvas.draw_rect(rect, Color("14242cf7"))
	canvas.draw_rect(rect, Color("6a9394"), false, 1)
	canvas.draw_string(font, rect.position + Vector2(16, 29), "PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	canvas.draw_string(font, rect.position + Vector2(296, 28), "Esc / B: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)
	var values := ["Low" if preferences.render_quality == "low" else "Standard", "Unlimited" if preferences.frame_limit == 0 else "%d FPS" % preferences.frame_limit]
	for index: int in 2:
		var row := row_rect(viewport, index)
		if selected == index: canvas.draw_rect(row, Color("305157"))
		canvas.draw_string(font, row.position + Vector2(10, 24), ["Visual detail", "Frame limit"][index], HORIZONTAL_ALIGNMENT_LEFT, 180, 15, ink)
		canvas.draw_string(font, row.position + Vector2(204, 24), "‹   %s   ›" % values[index], HORIZONTAL_ALIGNMENT_CENTER, 178, 15, ink)
	var lines := ["Low reduces decorative glow and Garden detail.", "Spell areas, warnings and movement stay complete.", "60 FPS is recommended for a 60 Hz display."]
	for index: int in lines.size():
		canvas.draw_string(font, rect.position + Vector2(16, 158 + index * 20), lines[index], HORIZONTAL_ALIGNMENT_LEFT, 392, 13, muted)
	canvas.draw_string(font, rect.position + Vector2(16, 240), message if not message.is_empty() else "↑ ↓ select · ← → / A change", HORIZONTAL_ALIGNMENT_LEFT, 392, 12, muted)
