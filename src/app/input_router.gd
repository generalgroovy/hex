class_name InputRouter
extends RefCounted


const KEY_ACTIONS: Dictionary[StringName, int] = PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS
const MOUSE_ACTIONS: Dictionary[StringName, int] = PlayerPreferences.DEFAULT_MOUSE_BINDINGS
const CONTROLLER_ACTIONS: Dictionary = PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS
const PRIMARY_ACTION: StringName = &"primary"
const ACTIVE_1_ACTION: StringName = &"active_1"
const PUNCH_ACTION: StringName = &"punch"
const KICK_ACTION: StringName = &"kick"
const SLIDE_ACTION: StringName = &"slide"
const INTERACT_ACTION: StringName = &"interact"
const EMOTE_ACTION: StringName = &"emote"
const SPECTATE_NEXT_ACTION: StringName = &"spectate_next"
const SPELL_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]
const SPELL_CTRL_LAYER_ACTION: StringName = &"spell_layer_ctrl"
const SPELL_ALT_LAYER_ACTION: StringName = &"spell_layer_alt"
const AIM_DEADZONE: float = 0.25
const WHEEL_GESTURE_QUIET_MS: int = 120
const WHEEL_MOVEMENT_ACTIONS: Array[StringName] = [&"jump", &"slide"]
const PAID_ACTIONS: Array[StringName] = [&"sprint", &"primary", &"evade", &"jump", &"technique", &"active_1", &"slide", &"punch", &"kick", &"spell_1", &"spell_2", &"spell_3", &"spell_4"]

var entity_id: int
var evade_was_down: bool = false
var jump_was_down: bool = false
var technique_was_down: bool = false
var active_1_was_down: bool = false
var slide_was_down: bool = false
var spell_was_down: Array[bool] = [false, false, false, false]
var movement_reference: String = PlayerPreferences.MOVEMENT_WORLD_RELATIVE
var last_quantized_aim := Vector2i(1000, 0)
var controller_aim_active: bool = false
var consumed_engine_edge_frames: Dictionary[StringName, int] = {}
var wheel_last_pulse_ms: Dictionary[StringName, int] = {}
var wheel_origin_actions: Dictionary[StringName, bool] = {}
var pending_wheel_pulses: Dictionary[StringName, int] = {}
var physical_press_frames: Dictionary[StringName, int] = {}
var consumed_physical_frames: Dictionary[StringName, int] = {}
var physical_hold_frames: Dictionary[StringName, int] = {}
var physical_holds: Dictionary[StringName, bool] = {}
var quarantined_actions: Dictionary[StringName, bool] = {}
var movement_cancel_pending: bool = false


func _init(requested_entity_id: int = 1) -> void:
	entity_id = requested_entity_id
	ensure_input_map()


static func ensure_input_map() -> void:
	for action: StringName in KEY_ACTIONS:
		_ensure_action(action)
		var physical_keycode: int = KEY_ACTIONS[action]
		if physical_keycode != 0:
			_add_key(action, physical_keycode)
	_ensure_action(SPECTATE_NEXT_ACTION)
	_add_key(SPECTATE_NEXT_ACTION, KEY_TAB)
	_ensure_action(PRIMARY_ACTION)
	_ensure_action(ACTIVE_1_ACTION)
	_add_key(ACTIVE_1_ACTION, KEY_E)
	for action: StringName in MOUSE_ACTIONS:
		_ensure_action(action)
		var mouse_button: int = MOUSE_ACTIONS[action]
		if mouse_button != 0:
			_add_mouse_button(action, mouse_button)

	for action: StringName in CONTROLLER_ACTIONS:
		_ensure_action(action)
		_add_controller_binding(action, CONTROLLER_ACTIONS[action])
	_ensure_action(&"aim_left")
	_ensure_action(&"aim_right")
	_ensure_action(&"aim_up")
	_ensure_action(&"aim_down")
	_add_joy_axis(&"aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis(&"aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis(&"aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis(&"aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_button(SPECTATE_NEXT_ACTION, JOY_BUTTON_DPAD_RIGHT)


static func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, AIM_DEADZONE)


static func _add_key(action: StringName, physical_keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	_add_event_once(action, event)


static func _add_mouse_button(action: StringName, button_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	_add_event_once(action, event)


static func _add_joy_axis(action: StringName, axis: int, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_event_once(action, event)


static func _add_joy_button(action: StringName, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	_add_event_once(action, event)


static func _add_controller_binding(action: StringName, descriptor: Dictionary) -> void:
	var kind := String(descriptor.get("kind", "none"))
	if kind == "button":
		_add_joy_button(action, int(descriptor.get("index", -1)))
	elif kind == "axis":
		_add_joy_axis(action, int(descriptor.get("index", -1)), float(descriptor.get("direction", 0)))


static func _add_event_once(action: StringName, event: InputEvent) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing.as_text() == event.as_text():
			return
	InputMap.action_add_event(action, event)


func observe_input_event(event: InputEvent) -> void:
	# Modal callers immediately discard the observed intent. Keeping its source
	# still distinguishes a UI wheel pulse from an intentionally held button.
	# Keep wheel origin until sampling: Godot's aggregate action state otherwise
	# makes a wheel notch indistinguishable from a deliberately held button.
	if event is InputEventMouseMotion:
		# A zero-relative event can be emitted without physical pointer travel. Only
		# deliberate mouse movement hands aim back from a neutral right stick.
		if (event as InputEventMouseMotion).relative.length_squared() > 0.0:
			controller_aim_active = false
		return
	if event is InputEventKey and event.echo:
		return
	if not event is InputEventKey and not event is InputEventMouseButton and not event is InputEventJoypadButton and not event is InputEventJoypadMotion:
		return
	var frame := Engine.get_process_frames()
	var wheel: bool = event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	for action: StringName in WHEEL_MOVEMENT_ACTIONS:
		if wheel and event.is_action(action):
			wheel_origin_actions[action] = true
			# Wheel releases finish the engine pulse; they neither rearm the
			# gesture nor erase a press that has not reached a simulation tick.
			if event.is_pressed() and accept_wheel_pulse(action, Time.get_ticks_msec()):
				pending_wheel_pulses[action] = Time.get_ticks_msec()
		elif event.is_action(action):
			physical_hold_frames[action] = frame
			physical_holds[action] = event.is_action_pressed(action)
			if event.is_action_pressed(action):
				physical_press_frames[action] = frame
	for action: StringName in quarantined_actions.keys():
		if event.is_action_released(action) and not _raw_paid_action_down(action):
			quarantined_actions.erase(action)
			_consume_engine_edge(action)


func accept_wheel_pulse(action: StringName, timestamp_ms: int) -> bool:
	if action not in WHEEL_MOVEMENT_ACTIONS:
		return false
	var previous := int(wheel_last_pulse_ms.get(action, -WHEEL_GESTURE_QUIET_MS))
	wheel_last_pulse_ms[action] = timestamp_ms
	# Every observed notch extends the same gesture, not a scheduled repeat.
	# The next gesture requires a quiet gap; other movement buttons bypass it.
	return timestamp_ms - previous >= WHEEL_GESTURE_QUIET_MS


func _movement_action_down(action: StringName) -> bool:
	if not wheel_origin_actions.has(action):
		return Input.is_action_pressed(action)
	if not Input.is_action_pressed(action) and not Input.is_action_just_pressed(action):
		wheel_origin_actions.erase(action)
		return false
	return _nonwheel_action_down(action)


func _nonwheel_action_down(action: StringName) -> bool:
	# This short scan runs only while the aggregate action still contains a
	# wheel-origin pulse. It also tolerates devices without an explicit wheel
	# release; a wheel can never become a hold on the following render frame.
	if int(physical_hold_frames.get(action, -1)) == Engine.get_process_frames() and bool(physical_holds.get(action, false)):
		return true
	for binding: InputEvent in InputMap.action_get_events(action):
		if binding is InputEventKey:
			if binding.physical_keycode != 0 and Input.is_physical_key_pressed(binding.physical_keycode):
				return true
			if binding.physical_keycode == 0 and Input.is_key_pressed(binding.keycode):
				return true
		elif binding is InputEventMouseButton and binding.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			if Input.is_mouse_button_pressed(binding.button_index):
				return true
		elif binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
			for device_id: int in Input.get_connected_joypads():
				if binding.device >= 0 and binding.device != device_id:
					continue
				if binding is InputEventJoypadButton and Input.is_joy_button_pressed(device_id, binding.button_index):
					return true
				if binding is InputEventJoypadMotion and Input.get_joy_axis(device_id, binding.axis) * signf(binding.axis_value) > InputMap.action_get_deadzone(action):
					return true
	return false


func _movement_pressed_edge(action: StringName, down: bool, was_down: bool) -> bool:
	var frame := Engine.get_process_frames()
	var wheel_pressed := consume_wheel_pulse(action, Time.get_ticks_msec())
	if not wheel_origin_actions.has(action):
		return _action_pressed_edge(action, down, was_down) or wheel_pressed
	# Consume the engine edge even when the wheel gesture was rejected, so a
	# later catch-up tick cannot turn that rejected pulse into a paid action.
	_consume_engine_edge(action)
	var physical_pressed := int(physical_press_frames.get(action, -1)) == frame and int(consumed_physical_frames.get(action, -1)) != frame
	if physical_pressed:
		consumed_physical_frames[action] = frame
	return pressed_edge(down, was_down, physical_pressed) or wheel_pressed


func consume_wheel_pulse(action: StringName, timestamp_ms: int) -> bool:
	if not pending_wheel_pulses.has(action):
		return false
	var age := timestamp_ms - int(pending_wheel_pulses[action])
	pending_wheel_pulses.erase(action)
	return age >= 0 and age <= WHEEL_GESTURE_QUIET_MS


func discard_transient_movement_input() -> void:
	movement_cancel_pending = true
	# Quarantine paid holds across modal/focus interruptions. Directional movement
	# may resume, but UI presses and drags cannot become fresh gameplay actions.
	pending_wheel_pulses.clear()
	for action: StringName in PAID_ACTIONS:
		if _raw_paid_action_down(action):
			quarantined_actions[action] = true
		else:
			quarantined_actions.erase(action)
		_consume_engine_edge(action)
		consumed_physical_frames[action] = Engine.get_process_frames()
	evade_was_down = false
	jump_was_down = false
	technique_was_down = false
	active_1_was_down = false
	slide_was_down = false
	spell_was_down.fill(false)


func _raw_paid_action_down(action: StringName) -> bool:
	return _movement_action_down(action) if action in WHEEL_MOVEMENT_ACTIONS else Input.is_action_pressed(action)


func _paid_action_down(action: StringName) -> bool:
	return not quarantined_actions.has(action) and _raw_paid_action_down(action)


func _consume_quarantined_input() -> void:
	for action: StringName in quarantined_actions.keys():
		_consume_engine_edge(action)
		pending_wheel_pulses.erase(action)
		consumed_physical_frames[action] = Engine.get_process_frames()
		if not _raw_paid_action_down(action):
			quarantined_actions.erase(action)


func sample(tick: int, player_position: Vector2, pointer_position: Vector2) -> SimCommand:
	_consume_quarantined_input()
	var movement_input := Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down", AIM_DEADZONE,
	)
	var quantized_movement := quantize_movement_vector(movement_input)
	var raw_move_x := quantized_movement.x
	var raw_move_y := quantized_movement.y
	var held: int = 0
	if _paid_action_down(&"sprint"):
		held |= SimCommand.HELD_SPRINT
	if _paid_action_down(PRIMARY_ACTION):
		held |= SimCommand.HELD_PRIMARY
	var evade_down: bool = _paid_action_down(&"evade")
	var evade_pressed: bool = _action_pressed_edge(&"evade", evade_down, evade_was_down)
	evade_was_down = evade_down
	var jump_down: bool = _paid_action_down(&"jump")
	var technique_down: bool = _paid_action_down(&"technique")
	var active_1_down: bool = _paid_action_down(ACTIVE_1_ACTION)
	var slide_down: bool = _paid_action_down(SLIDE_ACTION)
	var jump_pressed: bool = _movement_pressed_edge(&"jump", jump_down, jump_was_down)
	var technique_pressed: bool = _action_pressed_edge(&"technique", technique_down, technique_was_down)
	var active_1_pressed: bool = _action_pressed_edge(ACTIVE_1_ACTION, active_1_down, active_1_was_down)
	var slide_pressed: bool = _movement_pressed_edge(SLIDE_ACTION, slide_down, slide_was_down)
	if jump_down:
		held |= SimCommand.HELD_JUMP
	if slide_down:
		held |= SimCommand.HELD_SLIDE # Same wire bit becomes fast fall while airborne.
	var pressed: int = SimCommand.PRESSED_EVADE if evade_pressed else 0
	if movement_cancel_pending:
		pressed |= SimCommand.PRESSED_CANCEL_MOVEMENT
		movement_cancel_pending = false
	if jump_pressed:
		pressed |= SimCommand.PRESSED_JUMP
	if technique_pressed:
		pressed |= SimCommand.PRESSED_TECHNIQUE
	if active_1_pressed:
		pressed |= SimCommand.PRESSED_ACTIVE_1
	if slide_pressed:
		pressed |= SimCommand.PRESSED_SLIDE
	var ctrl_layer: bool = Input.is_action_pressed(SPELL_CTRL_LAYER_ACTION)
	var alt_layer: bool = Input.is_action_pressed(SPELL_ALT_LAYER_ACTION)
	for button_index: int in range(SPELL_ACTIONS.size()):
		var spell_down: bool = _paid_action_down(SPELL_ACTIONS[button_index])
		if spell_down:
			held |= SimCommand.SPELL_HELD_BITS[selected_spell_slot_index(button_index, ctrl_layer, alt_layer)]
		var spell_pressed: bool = pressed_edge(
			spell_down,
			spell_was_down[button_index],
			_consume_engine_edge(SPELL_ACTIONS[button_index]),
		)
		if spell_pressed:
			var spell_slot_index := selected_spell_slot_index(button_index, ctrl_layer, alt_layer)
			pressed |= SimCommand.SPELL_PRESSED_BITS[spell_slot_index]
		spell_was_down[button_index] = spell_down
	jump_was_down = jump_down
	technique_was_down = technique_down
	active_1_was_down = active_1_down
	slide_was_down = slide_down

	var joy_aim := Vector2(
		Input.get_action_strength(&"aim_right") - Input.get_action_strength(&"aim_left"),
		Input.get_action_strength(&"aim_down") - Input.get_action_strength(&"aim_up"),
	)
	var joy_stick_active: bool = joy_aim.length() >= AIM_DEADZONE
	if joy_stick_active:
		controller_aim_active = true
	var aim_delta: Vector2 = joy_aim if joy_stick_active else (pointer_position - player_position)
	var quantized_aim := last_quantized_aim
	if (joy_stick_active or not controller_aim_active) and aim_delta.length_squared() > 0.01:
		var normalized_aim: Vector2 = aim_delta.normalized() * 1000.0
		quantized_aim = Vector2i(roundi(normalized_aim.x), roundi(normalized_aim.y))
		last_quantized_aim = quantized_aim
	var transformed_move := transform_movement(
		raw_move_x,
		raw_move_y,
		quantized_aim.x,
		quantized_aim.y,
		movement_reference,
	)
	return SimCommand.new(
		tick,
		entity_id,
		transformed_move.x,
		transformed_move.y,
		held,
		pressed,
		quantized_aim.x,
		quantized_aim.y,
		clampi(roundi(pointer_position.x * SimConfig.FIXED_SCALE), 0, 100_000_000) if not controller_aim_active else -1,
		clampi(roundi(pointer_position.y * SimConfig.FIXED_SCALE), 0, 100_000_000) if not controller_aim_active else -1,
	)


func is_controller_aim_active() -> bool:
	return controller_aim_active


static func pressed_edge(down: bool, was_down: bool, engine_just_pressed: bool) -> bool:
	# Godot retains a just-pressed transition across the render/physics boundary.
	# Combine it with the explicit held-state edge so short wheel/key taps and
	# keyboard chords cannot disappear between input polling and simulation.
	return engine_just_pressed or (down and not was_down)


func _action_pressed_edge(action: StringName, down: bool, was_down: bool) -> bool:
	return pressed_edge(down, was_down, _consume_engine_edge(action))


func _consume_engine_edge(action: StringName) -> bool:
	if not Input.is_action_just_pressed(action):
		return false
	var process_frame: int = Engine.get_process_frames()
	if int(consumed_engine_edge_frames.get(action, -1)) == process_frame:
		return false
	consumed_engine_edge_frames[action] = process_frame
	return true


static func selected_spell_slot_index(button_index: int, ctrl_layer: bool, alt_layer: bool) -> int:
	var safe_button_index := clampi(button_index, 0, PlayerState.SPELL_BUTTON_COUNT - 1)
	# Alt takes deterministic precedence if both modifier actions are held.
	var layer_index: int = 2 if alt_layer else (1 if ctrl_layer else 0)
	return layer_index * PlayerState.SPELL_BUTTON_COUNT + safe_button_index


static func quantize_movement_vector(value: Vector2) -> Vector2i:
	var bounded := value.limit_length(1.0)
	return Vector2i(roundi(bounded.x * 1000.0), roundi(bounded.y * 1000.0))


func configure_movement_reference(requested_reference: String) -> bool:
	if not PlayerPreferences.is_valid_movement_reference(requested_reference):
		return false
	movement_reference = requested_reference
	return true


func configure_keyboard_bindings(requested_bindings: Dictionary) -> bool:
	if not PlayerPreferences.validate_keyboard_bindings(requested_bindings).is_empty():
		return false
	for action: StringName in PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS:
		var retained_events: Array[InputEvent] = []
		for existing: InputEvent in InputMap.action_get_events(action):
			if not existing is InputEventKey:
				retained_events.append(existing)
		InputMap.action_erase_events(action)
		for retained: InputEvent in retained_events:
			InputMap.action_add_event(action, retained)
		var physical_keycode: int = int(requested_bindings.get(action, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS[action]))
		if physical_keycode != 0:
			_add_key(action, physical_keycode)
	return true


func configure_mouse_bindings(requested_bindings: Dictionary) -> bool:
	if not PlayerPreferences.validate_mouse_bindings(requested_bindings).is_empty():
		return false
	for action: StringName in PlayerPreferences.DEFAULT_MOUSE_BINDINGS:
		var retained_events: Array[InputEvent] = []
		for existing: InputEvent in InputMap.action_get_events(action):
			if not existing is InputEventMouseButton:
				retained_events.append(existing)
		InputMap.action_erase_events(action)
		for retained: InputEvent in retained_events:
			InputMap.action_add_event(action, retained)
		var mouse_button: int = int(requested_bindings.get(action, PlayerPreferences.DEFAULT_MOUSE_BINDINGS[action]))
		if mouse_button != 0:
			_add_mouse_button(action, mouse_button)
	return true


func configure_controller_bindings(requested_bindings: Dictionary) -> bool:
	if not PlayerPreferences.validate_controller_bindings(requested_bindings).is_empty():
		return false
	for action: StringName in PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS:
		var retained_events: Array[InputEvent] = []
		for existing: InputEvent in InputMap.action_get_events(action):
			if not existing is InputEventJoypadButton and not existing is InputEventJoypadMotion:
				retained_events.append(existing)
		InputMap.action_erase_events(action)
		for retained: InputEvent in retained_events:
			InputMap.action_add_event(action, retained)
		var descriptor: Dictionary = requested_bindings.get(action, PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS[action])
		_add_controller_binding(action, descriptor)
	return true


static func transform_movement(
	raw_move_x: int,
	raw_move_y: int,
	aim_x: int,
	aim_y: int,
	reference: String,
) -> Vector2i:
	var clamped_x := clampi(raw_move_x, -1000, 1000)
	var clamped_y := clampi(raw_move_y, -1000, 1000)
	if reference != PlayerPreferences.MOVEMENT_AIM_RELATIVE:
		return Vector2i(clamped_x, clamped_y)
	var forward := SimCommand._normalized_direction(aim_x, aim_y)
	@warning_ignore("integer_division")
	var world_x: int = (forward.x * -clamped_y - forward.y * clamped_x) / 1000
	@warning_ignore("integer_division")
	var world_y: int = (forward.y * -clamped_y + forward.x * clamped_x) / 1000
	return Vector2i(clampi(world_x, -1000, 1000), clampi(world_y, -1000, 1000))
