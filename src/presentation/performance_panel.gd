extends RefCounted
## A local presentation preference surface. Deadzone and reading adaptations do not alter authority rules.

const LIMITS := [60, 120, 0]
const TEXT_SIZES := [100, 125, 150, 200]
const ROW_COUNT := 5
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
	var size := Vector2(minf(440,viewport.x-24), minf(346,viewport.y-24))
	return Rect2((viewport - size) * 0.5, size)

static func row_rect(viewport: Vector2, index: int) -> Rect2:
	var panel := panel_rect(viewport)
	var step := minf(42,(panel.size.y-98)/ROW_COUNT)
	return Rect2(panel.position + Vector2(16, 42 + step * index), Vector2(panel.size.x-32, step-3))

static func changed_value(index: int, direction: int, preferences: PlayerPreferences) -> Dictionary:
	if index == 0:
		return {"render_quality": "standard" if preferences.render_quality == "low" else "low"}
	if index == 1:
		return {"frame_limit": LIMITS[posmod(LIMITS.find(preferences.frame_limit) + direction, LIMITS.size())]}
	if index == 2:
		return {"ui_text_percent": TEXT_SIZES[posmod(TEXT_SIZES.find(preferences.ui_text_percent) + direction,TEXT_SIZES.size())]}
	if index == 3:
		return {"movement_deadzone_percent":clampi(preferences.movement_deadzone_percent+direction*5,5,50)}
	if index == 4:
		return {"aim_deadzone_percent":clampi(preferences.aim_deadzone_percent+direction*5,5,50)}
	return {}

func handle_input(event: InputEvent, viewport: Vector2, preferences: PlayerPreferences) -> Dictionary:
	if not is_open: return {}
	var direction := 0
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_ESCAPE: return {"close": true}
			KEY_UP: selected = posmod(selected-1,ROW_COUNT)
			KEY_DOWN: selected = posmod(selected+1,ROW_COUNT)
			KEY_TAB: selected = posmod(selected+(-1 if event.shift_pressed else 1),ROW_COUNT)
			KEY_LEFT: direction = -1
			KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER: direction = 1
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK: return {"close": true}
			JOY_BUTTON_DPAD_UP: selected = posmod(selected-1,ROW_COUNT)
			JOY_BUTTON_DPAD_DOWN: selected = posmod(selected+1,ROW_COUNT)
			JOY_BUTTON_DPAD_LEFT: direction = -1
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A: direction = 1
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if absf(event.axis_value) < 0.35: _stick_latched = false
		elif absf(event.axis_value) > 0.6 and not _stick_latched:
			if event.axis == JOY_AXIS_LEFT_Y: selected = posmod(selected+(1 if event.axis_value>0 else -1),ROW_COUNT)
			else: direction = 1 if event.axis_value > 0 else -1
			_stick_latched = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for index: int in ROW_COUNT:
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
	canvas.draw_string(font, rect.position + Vector2(16, 28), "DISPLAY & INPUT", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-140, 18, ink)
	canvas.draw_string(font, rect.position + Vector2(rect.size.x-116, 28), "Esc / B: close", HORIZONTAL_ALIGNMENT_LEFT, 104, 12, muted)
	var values := ["Low" if preferences.render_quality == "low" else "Standard", "Unlimited" if preferences.frame_limit == 0 else "%d FPS" % preferences.frame_limit,"%d%%" % preferences.ui_text_percent,"%d%%" % preferences.movement_deadzone_percent,"%d%%" % preferences.aim_deadzone_percent]
	for index: int in ROW_COUNT:
		var row := row_rect(viewport, index)
		var baseline := minf(24,row.size.y-5)
		if selected == index: canvas.draw_rect(row, Color("305157"))
		canvas.draw_string(font, row.position + Vector2(10, baseline), ["Visual detail", "Frame limit", "Text size", "Movement deadzone", "Aim deadzone"][index], HORIZONTAL_ALIGNMENT_LEFT, row.size.x*0.58-12, 14, ink)
		canvas.draw_string(font, row.position + Vector2(row.size.x*0.58, baseline), "<  %s  >" % values[index], HORIZONTAL_ALIGNMENT_CENTER, row.size.x*0.42-6, 14, ink)
	var hints := ["Low reduces decoration; danger stays complete.","A target cap, not measured frame speed.","Larger text reflows spell setup and controls.","Left stick: higher values ignore more drift.","Right stick: independent of movement drift."]
	canvas.draw_string(font,rect.position+Vector2(16,rect.size.y-36),hints[selected],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-32,12,muted)
	canvas.draw_string(font, rect.position + Vector2(16, rect.size.y-14), message if not message.is_empty() else "Up / Down select; Left / Right / A change", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-32, 12, muted)
