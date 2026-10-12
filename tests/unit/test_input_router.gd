extends FluxTestSuite


const BootstrapScript: Script = preload("res://src/app/bootstrap.gd")


func _test_prompt_device() -> void:
	var router := InputRouter.new()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	check(router.observe_prompt_device(pad), "deliberate pad press switches the teaching vocabulary")
	equal(router.prompt_device, ControlBindingEditor.DEVICE_CONTROLLER, "pad hints are selected independently of aiming")
	var drift := InputEventJoypadMotion.new()
	drift.axis_value = 0.2
	check(not router.observe_prompt_device(drift), "stick noise does not switch labels")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(1, 1)
	check(not router.observe_prompt_device(mouse), "tiny pointer drift cannot steal pad prompts")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	key.echo = true
	check(not router.observe_prompt_device(key), "held key echo does not steal pad prompts")
	key.echo = false
	check(router.observe_prompt_device(key), "fresh keyboard press restores keyboard and mouse prompts")
	drift.axis_value = -0.7
	check(router.observe_prompt_device(drift), "deliberate stick direction selects pad prompts")
	pad.pressed = false
	check(not router.observe_prompt_device(pad), "button release cannot manufacture another device change")
	mouse.relative = Vector2(5, 0)
	check(router.observe_prompt_device(mouse), "deliberate pointer travel restores mouse and keyboard prompts")


func run() -> int:
	for action: StringName in [&"jump", &"primary", &"active_1", &"sprint", &"slide", &"evade", &"technique", &"punch", &"kick", &"interact", &"emote", &"spell_1", &"spell_2", &"spell_3", &"spell_4", &"spell_layer_ctrl", &"spell_layer_alt", &"adjust_camera_zoom"]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	InputRouter.ensure_input_map()
	for action: StringName in [
		&"move_left", &"move_right", &"move_up", &"move_down",
		&"aim_left", &"aim_right", &"aim_up", &"aim_down",
		&"sprint", &"slide", &"jump", &"technique", &"punch", &"kick", &"interact", &"emote", &"spectate_next", &"primary", &"active_1",
		&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"spell_layer_ctrl", &"spell_layer_alt",
		&"reset_match", &"toggle_debug_overlay",
		&"toggle_movement_reference", &"toggle_pov_mode",
		&"adjust_pov_angle", &"adjust_pov_range", &"adjust_camera_zoom",
	]:
		check(InputMap.has_action(action), "input action exists: %s" % action)
		check(not InputMap.action_get_events(action).is_empty(), "input action has a default: %s" % action)
	equal(_keycodes(&"jump"), [KEY_SPACE], "jump defaults to Space exactly once")
	equal(_keycodes(&"sprint"), [KEY_SHIFT], "sprint defaults to Shift")
	equal(_keycodes(&"slide"), [KEY_C], "slide defaults to C")
	equal(_keycodes(&"evade"), [KEY_B], "B maps only to the default evade action")
	equal(_keycodes(&"technique"), [KEY_V], "V maps only to the default technique action")
	for action: StringName in PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS:
		check(not _keycodes(action).has(KEY_Q), "Q is unassigned in the S4 default keyboard map: %s" % action)
	check(_keycodes(&"punch").is_empty() and _has_mouse_button(&"punch", MOUSE_BUTTON_LEFT), "Punch is mouse-left with no keyboard alias")
	check(_keycodes(&"kick").is_empty() and _has_mouse_button(&"kick", MOUSE_BUTTON_RIGHT), "Kick is mouse-right with no keyboard alias")
	check(_has_mouse_button(&"jump", MOUSE_BUTTON_WHEEL_UP), "wheel up triggers semantic jump")
	check(_has_mouse_button(&"slide", MOUSE_BUTTON_WHEEL_DOWN), "wheel down triggers slide or airborne fast fall")
	equal(_keycodes(&"interact"), [KEY_F], "walk-up interaction defaults to F")
	check(_has_joy_button(&"interact", JOY_BUTTON_RIGHT_STICK), "walk-up interaction uses the dedicated controller stick click")
	equal(_keycodes(&"emote"), [KEY_T], "social speech defaults to T")
	for button_index: int in range(PlayerState.SPELL_BUTTON_COUNT):
		equal(_keycodes(InputRouter.SPELL_ACTIONS[button_index]), [KEY_1 + button_index], "spell button %d defaults to its number key" % (button_index + 1))
	equal(_keycodes(InputRouter.SPELL_CTRL_LAYER_ACTION), [KEY_CTRL], "Ctrl selects the middle spell layer")
	equal(_keycodes(InputRouter.SPELL_ALT_LAYER_ACTION), [KEY_ALT], "Alt selects the final spell layer")
	equal(_keycodes(&"adjust_camera_zoom"), [KEY_F11], "F11 retains the compatibility camera notice binding")
	equal(InputRouter.selected_spell_slot_index(0, false, false), 0, "plain button 1 selects position 1")
	equal(InputRouter.selected_spell_slot_index(3, true, false), 7, "Ctrl+4 selects position 8")
	equal(InputRouter.selected_spell_slot_index(3, false, true), 11, "Alt+4 selects position 12")
	equal(InputRouter.selected_spell_slot_index(1, true, true), 9, "Alt deterministically wins a dual-modifier chord")
	_test_press_edge_resilience()
	_test_prompt_device()
	_test_qv_physical_press_paths()
	_test_evade_neutral_threshold_and_rearm()
	_test_evade_device_events_and_unbound()
	_test_eight_direction_command_vectors()
	_test_absolute_keyboard_chords()
	_test_eight_direction_slide_chords()
	_test_wheel_gesture_safety()
	_test_modal_paid_action_quarantine()
	_test_bootstrap_movement_cancel_guard()
	_test_melee_modal_quarantine_without_wire_bits()
	_test_s4_mouse_reconfiguration_clears_old_spell_aliases()
	check(_has_joy_button(&"emote", JOY_BUTTON_START), "social speech moves off the four spell directions")
	check(not _keycodes(&"primary").has(KEY_SPACE), "primary has no Space keyboard alias")
	check(not _has_mouse_button(&"primary", MOUSE_BUTTON_LEFT), "Primary no longer owns the Punch mouse button")
	check(InputMap.action_get_events(&"primary").size() >= 1, "Primary preserves its controller trigger")
	check(not _has_mouse_button(&"active_1", MOUSE_BUTTON_RIGHT), "Active one no longer owns the Kick mouse button")
	check(InputMap.action_get_events(&"active_1").size() >= 2, "Active one preserves E and its controller button")
	check(InputMap.action_get_events(InputRouter.SPECTATE_NEXT_ACTION).size() >= 2, "spectator focus supports Tab and controller D-pad right")
	_test_capture_pointer_parser()
	_test_accessible_aim_and_deadzones()
	_test_aim_endpoint()
	_test_twelve_position_controller_events()
	return finish("input-router")


func _test_aim_endpoint() -> void:
	for action: StringName in [&"aim_left", &"aim_right", &"aim_up", &"aim_down"]:
		Input.action_release(action)
	var router := InputRouter.new()
	var mouse := router.sample(0, Vector2(100, 100), Vector2(123.25, 234.5))
	equal(Vector2i(mouse.aim_target_x, mouse.aim_target_y), Vector2i(123250, 234500), "mouse command preserves fixed-world impact endpoint")
	Input.action_press(&"aim_right", 1.0)
	var controller := router.sample(1, Vector2(100, 100), Vector2(123, 234))
	equal(Vector2i(controller.aim_target_x, controller.aim_target_y), Vector2i(-1, -1), "controller direction keeps maximum-range endpoint sentinel")
	Input.action_release(&"aim_right")
	var bounded := InputRouter.new().sample(2, Vector2.ZERO, Vector2(-10, 200000))
	equal(Vector2i(bounded.aim_target_x, bounded.aim_target_y), Vector2i(0, 100000000), "mouse endpoint stays inside command bounds")

	# Reproduce through Godot's event map and the production InputRouter entry.
	# Releasing the stick must not resurrect the pointer that was left behind
	# when the controller took ownership of aim.
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	_deliver_movement_event(router, stick)
	var controller_event_command := router.sample(3, Vector2(100, 100), Vector2(25, 50))
	equal(Vector2i(controller_event_command.aim_x, controller_event_command.aim_y), Vector2i(1000, 0), "real right-stick event reaches the sampled command")
	equal(Vector2i(controller_event_command.aim_target_x, controller_event_command.aim_target_y), Vector2i(-1, -1), "real right-stick event selects the maximum-range endpoint")
	stick.axis_value = 0.0
	_deliver_movement_event(router, stick)
	_deliver_movement_event(router, _physical_key_event(KEY_1, true))
	var neutral_cast := router.sample(4, Vector2(100, 100), Vector2(25, 50))
	check(neutral_cast.has_pressed(SimCommand.SPELL_PRESSED_BITS[0]), "real spell press reaches the neutral-stick cast command")
	equal(Vector2i(neutral_cast.aim_x, neutral_cast.aim_y), Vector2i(1000, 0), "neutral stick retains the last controller direction instead of stale mouse aim")
	equal(Vector2i(neutral_cast.aim_target_x, neutral_cast.aim_target_y), Vector2i(-1, -1), "neutral stick retains the controller endpoint until actual mouse motion")
	check(router.is_controller_aim_active(), "neutral stick keeps explicit controller ownership")
	_deliver_movement_event(router, _physical_key_event(KEY_1, false))
	var synthetic_mouse_motion := InputEventMouseMotion.new()
	synthetic_mouse_motion.position = Vector2(400, 300)
	synthetic_mouse_motion.relative = Vector2.ZERO
	_deliver_movement_event(router, synthetic_mouse_motion)
	var unchanged_pointer := router.sample(5, Vector2(100, 100), Vector2(25, 50))
	equal(Vector2i(unchanged_pointer.aim_x, unchanged_pointer.aim_y), Vector2i(1000, 0), "zero-relative mouse event cannot steal neutral controller aim")
	equal(Vector2i(unchanged_pointer.aim_target_x, unchanged_pointer.aim_target_y), Vector2i(-1, -1), "zero-relative mouse event cannot revive a stale endpoint")
	check(router.is_controller_aim_active(), "zero-relative mouse event preserves explicit controller ownership")

	# A real mouse movement hands aim back even when its legitimate world
	# endpoint is exactly the player position and therefore has zero aim delta.
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(400, 300)
	mouse_motion.relative = Vector2(2, -1)
	_deliver_movement_event(router, mouse_motion)
	var exact_player_endpoint := router.sample(6, Vector2(100, 100), Vector2(100, 100))
	equal(Vector2i(exact_player_endpoint.aim_x, exact_player_endpoint.aim_y), Vector2i(1000, 0), "zero-delta mouse handoff keeps the last valid direction")
	equal(Vector2i(exact_player_endpoint.aim_target_x, exact_player_endpoint.aim_target_y), Vector2i(100000, 100000), "mouse handoff preserves an exact-player world endpoint")
	check(not router.is_controller_aim_active(), "nonzero mouse motion hands explicit ownership back")
	var moved_endpoint := router.sample(7, Vector2(100, 100), Vector2(75, 100))
	equal(Vector2i(moved_endpoint.aim_x, moved_endpoint.aim_y), Vector2i(-1000, 0), "mouse handoff resumes pointer-derived aim")
	equal(Vector2i(moved_endpoint.aim_target_x, moved_endpoint.aim_target_y), Vector2i(75000, 100000), "mouse handoff resumes the legitimate pointer endpoint")
	stick.axis_value = InputRouter.AIM_DEADZONE - 0.01
	_deliver_movement_event(router, stick)
	var analog_noise := router.sample(8, Vector2(100, 100), Vector2(100, 75))
	equal(Vector2i(analog_noise.aim_x, analog_noise.aim_y), Vector2i(0, -1000), "below-deadzone analog noise cannot steal mouse aim")
	equal(Vector2i(analog_noise.aim_target_x, analog_noise.aim_target_y), Vector2i(100000, 75000), "below-deadzone analog noise keeps the mouse endpoint")
	check(not router.is_controller_aim_active(), "below-deadzone analog noise preserves mouse ownership")
	stick.axis_value = 0.0
	_deliver_movement_event(router, stick)


func _test_twelve_position_controller_events() -> void:
	var spell_buttons: Array[int] = [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_RIGHT,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
	]
	var layer_buttons: Array[int] = [-1, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
	for action: StringName in InputRouter.PAID_ACTIONS + [InputRouter.SPELL_CTRL_LAYER_ACTION, InputRouter.SPELL_ALT_LAYER_ACTION]:
		Input.action_release(action)
	var router := InputRouter.new(1)
	check(router.configure_controller_bindings(PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS), "controller spell fixture applies the complete defaults")
	router.sample(0, Vector2.ZERO, Vector2.RIGHT)
	for layer_index: int in range(layer_buttons.size()):
		for button_index: int in range(spell_buttons.size()):
			if layer_buttons[layer_index] >= 0:
				_deliver_movement_event(router, _joy_button_event(layer_buttons[layer_index], true))
			_deliver_movement_event(router, _joy_button_event(spell_buttons[button_index], true))
			var slot_index := layer_index * spell_buttons.size() + button_index
			var command := router.sample(slot_index + 1, Vector2.ZERO, Vector2.RIGHT)
			equal(command.pressed_actions, SimCommand.SPELL_PRESSED_BITS[slot_index], "physical controller chord reaches only spell position %d" % (slot_index + 1))
			equal(command.held_actions, SimCommand.SPELL_HELD_BITS[slot_index], "physical controller chord sustains only spell position %d" % (slot_index + 1))
			_deliver_movement_event(router, _joy_button_event(spell_buttons[button_index], false))
			if layer_buttons[layer_index] >= 0:
				_deliver_movement_event(router, _joy_button_event(layer_buttons[layer_index], false))
			router.sample(20 + slot_index, Vector2.ZERO, Vector2.RIGHT)


func _test_eight_direction_command_vectors() -> void:
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var direction_id := EightDirectionResolver.DIRECTION_ORDER[direction_index]
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		var sampled := InputRouter.quantize_movement_vector(Vector2(fixed) / 1000.0)
		equal(sampled, fixed, "digital/controller vector preserves normalized %s command" % direction_id)
		equal(
			InputRouter.transform_movement(fixed.x, fixed.y, 1000, 0, PlayerPreferences.MOVEMENT_WORLD_RELATIVE),
			fixed,
			"world-relative transform preserves %s" % direction_id,
		)
	var analog := InputRouter.quantize_movement_vector(Vector2(0.42, -0.31))
	equal(analog, Vector2i(420, -310), "sub-unit controller magnitude survives command quantization")
	var overdriven := InputRouter.quantize_movement_vector(Vector2(2.0, 0.0))
	equal(overdriven, Vector2i(1000, 0), "movement vector is bounded to the command envelope")
	var aim_relative := InputRouter.transform_movement(420, -310, 1000, 0, PlayerPreferences.MOVEMENT_AIM_RELATIVE)
	equal(aim_relative, Vector2i(310, 420), "aim-relative rotation preserves analog components around east-facing aim")


func _test_press_edge_resilience() -> void:
	check(InputRouter.pressed_edge(true, false, false), "held-state transition produces one semantic press")
	check(InputRouter.pressed_edge(false, false, true), "buffered engine transition preserves a short press between samples")
	check(not InputRouter.pressed_edge(true, true, false), "held action does not repeat without a new transition")
	check(not InputRouter.pressed_edge(false, false, false), "idle action produces no semantic press")


func _test_qv_physical_press_paths() -> void:
	var router := InputRouter.new()
	var preferences := PlayerPreferences.new()
	var profiles: Array[Dictionary] = [preferences.to_dictionary()]
	var legacy := preferences.to_dictionary().duplicate(true)
	legacy.erase("keyboard_defaults_revision")
	legacy["keyboard_bindings"] = PlayerPreferences.SCHEMA_V11_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	check(preferences.apply_dictionary(legacy), "actual input fixture migrates complete old v11 defaults")
	profiles.append(preferences.to_dictionary())
	var custom := legacy.duplicate(true)
	custom["keyboard_bindings"][&"jump"] = KEY_J
	check(preferences.apply_dictionary(custom), "actual input fixture retains a customized old Q/V layout")
	profiles.append(preferences.to_dictionary())
	for profile: Dictionary in profiles:
		check(preferences.apply_dictionary(profile), "press-path profile reloads persisted controls")
		# Start with every prior physical alias present, as on a reused InputMap.
		InputRouter._add_key(&"evade", KEY_V)
		InputRouter._add_key(&"technique", KEY_Q)
		InputRouter._add_key(&"evade", KEY_Q)
		check(router.configure_keyboard_bindings(preferences.keyboard_bindings), "applying a profile replaces old aliases before sampling")
		for action: StringName in [&"evade", &"technique"]:
			equal(_keycodes(action), [preferences.keyboard_bindings[action]], "only the configured physical key owns %s" % action)
		for action: StringName in [&"evade", &"technique"]:
			var keycode := int(preferences.keyboard_bindings[action])
			for paid_action: StringName in InputRouter.PAID_ACTIONS:
				Input.action_release(paid_action)
			router.discard_transient_movement_input()
			var expected := SimCommand.PRESSED_EVADE if action == &"evade" else SimCommand.PRESSED_TECHNIQUE
			var event := _physical_key_event(keycode, true)
			check(event.is_action_pressed(action), "configured physical event matches its semantic action")
			check(not event.is_action_pressed(&"technique" if action == &"evade" else &"evade"), "one physical key cannot match both semantic actions")
			_deliver_movement_event(router, event)
			var pressed := router.sample(0, Vector2.ZERO, Vector2.RIGHT)
			equal(pressed.pressed_actions, expected | SimCommand.PRESSED_CANCEL_MOVEMENT, "physical key reaches exactly one paid command bit plus the pending interruption cancellation")
			var held := router.sample(1, Vector2.ZERO, Vector2.RIGHT)
			equal(held.pressed_actions, 0, "held key does not repeat the semantic press during catch-up")
			_deliver_movement_event(router, _physical_key_event(keycode, false))
			var released := router.sample(2, Vector2.ZERO, Vector2.RIGHT)
			equal(released.pressed_actions, 0, "physical release does not create another action")
			equal(released.held_actions, 0, "physical release leaves no paid held intent")
	check(router.configure_keyboard_bindings(PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS), "press-path test restores current keyboard defaults")
	router.discard_transient_movement_input()


func _test_evade_neutral_threshold_and_rearm() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"evade"]:
		Input.action_release(action)
	var router := InputRouter.new(1)
	check(router.configure_keyboard_bindings(PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS), "evade intent fixture uses current remappable defaults")
	Input.action_press(&"move_left")
	Input.action_press(&"move_right")
	Input.action_press(&"evade")
	var cancelled := router.sample(0, Vector2.ZERO, Vector2.RIGHT)
	equal(Vector2i(cancelled.move_x, cancelled.move_y), Vector2i.ZERO, "opposing keyboard directions are exact neutral on Q admission")
	check(cancelled.has_pressed(SimCommand.PRESSED_EVADE), "cancelled movement retains the one semantic Evade edge")
	equal(router.sample(1, Vector2.ZERO, Vector2.RIGHT).pressed_actions & SimCommand.PRESSED_EVADE, 0, "holding Q never repeats its edge")
	for action: StringName in [&"move_left", &"move_right", &"evade"]:
		Input.action_release(action)
	router.sample(2, Vector2.ZERO, Vector2.RIGHT)
	Input.action_press(&"move_right", InputRouter.AIM_DEADZONE - 0.01)
	Input.action_press(&"evade")
	var below := router.sample(3, Vector2.ZERO, Vector2.RIGHT)
	equal(Vector2i(below.move_x, below.move_y), Vector2i.ZERO, "controller-strength movement below the shared deadzone is neutral for Q")
	Input.action_release(&"move_right")
	Input.action_release(&"evade")
	router.sample(4, Vector2.ZERO, Vector2.RIGHT)
	Input.action_press(&"move_right", InputRouter.AIM_DEADZONE + 0.01)
	Input.action_press(&"evade")
	var above := router.sample(5, Vector2.ZERO, Vector2.RIGHT)
	check(above.move_x > 0 and above.move_y == 0, "controller-strength movement above the shared deadzone is directional for Q")
	check(above.has_pressed(SimCommand.PRESSED_EVADE), "release and repress rearms exactly one Evade edge")
	Input.action_release(&"move_right")
	Input.action_release(&"evade")
	router.sample(6, Vector2.ZERO, Vector2.RIGHT)


func _test_evade_device_events_and_unbound() -> void:
	var router := InputRouter.new(1)
	for action: StringName in InputRouter.PAID_ACTIONS + [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	check(router.configure_controller_bindings(PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS), "Evade device fixture restores controller defaults")
	for strength: float in [0.24, 0.26]:
		var movement := InputEventJoypadMotion.new()
		movement.axis = JOY_AXIS_LEFT_X
		movement.axis_value = strength
		_deliver_movement_event(router, movement)
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_LEFT
		trigger.axis_value = 1.0
		_deliver_movement_event(router, trigger)
		var command := router.sample(0, Vector2.ZERO, Vector2.LEFT)
		check(command.has_pressed(SimCommand.PRESSED_EVADE), "injected configured trigger produces semantic Evade")
		if strength < InputRouter.AIM_DEADZONE:
			equal(Vector2i(command.move_x, command.move_y), Vector2i.ZERO, "injected stick below deadzone stays neutral despite independent aim")
		else:
			check(command.move_x > 0 and command.move_y == 0, "injected stick above deadzone preserves directional Q intent")
		trigger.axis_value = 0.0
		movement.axis_value = 0.0
		_deliver_movement_event(router, trigger)
		_deliver_movement_event(router, movement)
		router.sample(1, Vector2.ZERO, Vector2.LEFT)
	var bindings := PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS.duplicate()
	bindings[&"evade"] = KEY_K
	check(router.configure_keyboard_bindings(bindings), "Evade accepts a custom physical key")
	_deliver_movement_event(router, _physical_key_event(KEY_K, true))
	check(router.sample(2, Vector2.ZERO, Vector2.LEFT).has_pressed(SimCommand.PRESSED_EVADE), "custom key reaches neutral semantic Evade")
	_deliver_movement_event(router, _physical_key_event(KEY_K, false))
	router.sample(3, Vector2.ZERO, Vector2.LEFT)
	bindings[&"evade"] = 0
	check(router.configure_keyboard_bindings(bindings), "Evade keyboard binding can be explicitly unbound")
	for keycode: int in [KEY_B, KEY_K]:
		_deliver_movement_event(router, _physical_key_event(keycode, true))
		check(not router.sample(4, Vector2.ZERO, Vector2.LEFT).has_pressed(SimCommand.PRESSED_EVADE), "unbound Evade cannot use default or former custom key")
		_deliver_movement_event(router, _physical_key_event(keycode, false))
		router.sample(5, Vector2.ZERO, Vector2.LEFT)
	check(router.configure_keyboard_bindings(PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS), "Evade device fixture restores keyboard defaults")
	router.discard_transient_movement_input()


func _test_absolute_keyboard_chords() -> void:
	var movement_actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		for action: StringName in movement_actions:
			Input.action_release(action)
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		if fixed.x < 0:
			Input.action_press(&"move_left")
		elif fixed.x > 0:
			Input.action_press(&"move_right")
		if fixed.y < 0:
			Input.action_press(&"move_up")
		elif fixed.y > 0:
			Input.action_press(&"move_down")
		var router := InputRouter.new(1)
		check(router.configure_movement_reference(PlayerPreferences.MOVEMENT_WORLD_RELATIVE), "absolute keyboard mode configures")
		var command := router.sample(0, Vector2.ZERO, Vector2.RIGHT)
		equal(Vector2i(command.move_x, command.move_y), fixed, "absolute keyboard chord resolves exact %s lane" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
	for action: StringName in movement_actions:
		Input.action_release(action)


func _test_eight_direction_slide_chords() -> void:
	var movement_actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		for action: StringName in movement_actions:
			Input.action_release(action)
		Input.action_release(InputRouter.SLIDE_ACTION)
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		if fixed.x < 0:
			Input.action_press(&"move_left")
		elif fixed.x > 0:
			Input.action_press(&"move_right")
		if fixed.y < 0:
			Input.action_press(&"move_up")
		elif fixed.y > 0:
			Input.action_press(&"move_down")
		Input.action_press(InputRouter.SLIDE_ACTION)
		var router := InputRouter.new(1)
		var world := SimWorld.new(120)
		# Slide requires earned ground speed. The explicit100ms intent buffer
		# must not wait until126ms of acceleration to become a late action.
		for warmup: int in range(20):
			check(world.step([SimCommand.new(world.tick, 1, fixed.x, fixed.y, 0, 0, 1000, 0)]), "%s ordinary movement builds slide-entry speed" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		var first_command: SimCommand = router.sample(world.tick, Vector2.ZERO, Vector2.RIGHT)
		equal(Vector2i(first_command.move_x, first_command.move_y), fixed, "%s movement chord reaches the command unchanged" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		check(first_command.has_pressed(SimCommand.PRESSED_SLIDE), "%s movement + slide emits the slide edge" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		check(first_command.has_held(SimCommand.HELD_FAST_FALL), "%s movement + slide retains the shared held intent" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		check(world.step([first_command]), "%s chord enters deterministic simulation" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		while world.player().slide_ticks == 0 and world.player().slide_buffer_ticks > 0:
			var command: SimCommand = router.sample(world.tick, Vector2.ZERO, Vector2.RIGHT)
			check(not command.has_pressed(SimCommand.PRESSED_SLIDE), "%s held chord does not repeat its press edge during catch-up" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
			check(world.step([command]), "%s buffered chord advances" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		check(world.player().slide_ticks > 0, "%s movement + slide reaches the slide state" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		equal(Vector2i(world.player().slide_x, world.player().slide_y), fixed, "%s slide owns the requested direction" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
	for action: StringName in movement_actions:
		Input.action_release(action)
	Input.action_release(InputRouter.SLIDE_ACTION)


func _test_wheel_gesture_safety() -> void:
	var router := InputRouter.new(1)
	check(router.accept_wheel_pulse(&"jump", 0), "first wheel gesture is accepted immediately")
	check(not router.accept_wheel_pulse(&"jump", 30), "nearby wheel notch remains part of the same gesture")
	check(not router.accept_wheel_pulse(&"jump", 140), "each notch extends quiet time instead of scheduling auto-repeat")
	check(router.accept_wheel_pulse(&"jump", 260), "a deliberate gesture after120ms quiet is accepted")
	check(router.accept_wheel_pulse(&"slide", 260), "opposite wheel action is independent for deliberate chains")
	check(not router.accept_wheel_pulse(&"primary", 260), "wheel movement filtering cannot change spell cadence")
	router = InputRouter.new(1)
	for action: StringName in [&"jump", &"slide"]:
		Input.action_release(action)
	var wheel_down := _wheel_event(MOUSE_BUTTON_WHEEL_DOWN, true)
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	_deliver_movement_event(router, wheel_down)
	var command := router.sample(0, Vector2.ZERO, Vector2.RIGHT)
	check(command.has_pressed(SimCommand.PRESSED_SLIDE), "first live wheel-down emits one slide intent")
	check(not command.has_held(SimCommand.HELD_SLIDE), "wheel-down never fabricates a sustained slide or fast-fall hold")
	equal(Vector2i(command.move_x, command.move_y), Vector2i(707, 707), "wheel filtering preserves simultaneous down-right directional input")
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_DOWN, false))
	_deliver_movement_event(router, wheel_down)
	command = router.sample(1, Vector2.ZERO, Vector2.RIGHT)
	check(not command.has_pressed(SimCommand.PRESSED_SLIDE), "second notch cannot accidentally brake the first slide")
	check(not command.has_held(SimCommand.HELD_SLIDE), "suppressed notch cannot sustain an action")
	var key_slide := _physical_key_event(KEY_C, true)
	_deliver_movement_event(router, key_slide)
	command = router.sample(2, Vector2.ZERO, Vector2.RIGHT)
	check(command.has_pressed(SimCommand.PRESSED_SLIDE), "deliberate keyboard Slide bypasses wheel gesture filtering")
	check(command.has_held(SimCommand.HELD_SLIDE), "keyboard Slide still holds even with a wheel pulse in the same frame")
	Input.action_press(InputRouter.SPELL_CTRL_LAYER_ACTION)
	Input.action_press(&"spell_1")
	command = router.sample(2, Vector2.ZERO, Vector2.RIGHT)
	check(command.has_pressed(SimCommand.SPELL_PRESSED_BITS[4]), "wheel filtering leaves Ctrl+1 spell intent untouched")
	Input.action_release(&"spell_1")
	Input.action_release(InputRouter.SPELL_CTRL_LAYER_ACTION)
	_deliver_movement_event(router, _physical_key_event(KEY_C, false))
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_DOWN, false))
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, true))
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, false))
	command = router.sample(3, Vector2.ZERO, Vector2.RIGHT)
	check(command.has_pressed(SimCommand.PRESSED_JUMP), "wheel release does not lose the accepted short jump before sampling")
	check(not command.has_held(SimCommand.HELD_JUMP), "wheel jump is short rather than a simulated hold")
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, true))
	command = router.sample(4, Vector2.ZERO, Vector2.RIGHT)
	check(not command.has_pressed(SimCommand.PRESSED_JUMP), "same scrolling gesture cannot buy an accidental second jump")
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, false))
	for index: int in range(4):
		command = router.sample(5 + index, Vector2.ZERO, Vector2.RIGHT)
		check(not command.has_pressed(SimCommand.PRESSED_JUMP) and not command.has_pressed(SimCommand.PRESSED_SLIDE), "catch-up ticks never replay a wheel pulse")
	router.wheel_last_pulse_ms[&"jump"] = Time.get_ticks_msec() - InputRouter.WHEEL_GESTURE_QUIET_MS
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, true))
	router.discard_transient_movement_input()
	command = router.sample(9, Vector2.ZERO, Vector2.RIGHT)
	equal(command.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "opening a modal replaces an unconsumed wheel pulse with exactly movement cancellation")
	equal(command.held_actions, 0, "cancelled wheel pulse leaves no paid held intent")
	_deliver_movement_event(router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, false))
	# The production consumer uses elapsed time, not a render-frame identity.
	# Test it with explicit time instead of sleeping or faking an engine frame.
	router.pending_wheel_pulses[&"jump"] = 5000
	check(router.consume_wheel_pulse(&"jump", 5017), "pending short input remains available across a17ms sampling gap")
	check(not router.consume_wheel_pulse(&"jump", 5018), "accepted wheel intent is consumed exactly once")
	router.pending_wheel_pulses[&"jump"] = 6000
	check(not router.consume_wheel_pulse(&"jump", 6001 + InputRouter.WHEEL_GESTURE_QUIET_MS), "stale wheel pulse expires instead of becoming delayed movement")
	for action: StringName in [&"jump", &"slide"]:
		Input.action_release(action)


func _test_modal_paid_action_quarantine() -> void:
	var cases: Array[Dictionary] = [
		{"action": &"jump", "held": SimCommand.HELD_JUMP, "pressed": SimCommand.PRESSED_JUMP},
		{"action": &"slide", "held": SimCommand.HELD_SLIDE, "pressed": SimCommand.PRESSED_SLIDE},
		{"action": &"evade", "held": 0, "pressed": SimCommand.PRESSED_EVADE},
		{"action": &"technique", "held": 0, "pressed": SimCommand.PRESSED_TECHNIQUE},
		{"action": &"active_1", "held": 0, "pressed": SimCommand.PRESSED_ACTIVE_1},
		{"action": &"primary", "held": SimCommand.HELD_PRIMARY, "pressed": 0},
		{"action": &"sprint", "held": SimCommand.HELD_SPRINT, "pressed": 0},
	]
	for index: int in range(InputRouter.SPELL_ACTIONS.size()):
		cases.append({"action": InputRouter.SPELL_ACTIONS[index], "held": SimCommand.SPELL_HELD_BITS[index], "pressed": SimCommand.SPELL_PRESSED_BITS[index]})
	for case: Dictionary in cases:
		Input.action_release(case.action)
		var router := InputRouter.new()
		router.sample(0, Vector2.ZERO, Vector2.RIGHT)
		Input.action_press(case.action)
		router.discard_transient_movement_input()
		for tick: int in range(1, 4):
			var blocked := router.sample(tick, Vector2.ZERO, Vector2.RIGHT)
			equal(blocked.held_actions, 0, "%s held during a modal cannot retain any paid hold" % case.action)
			equal(blocked.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT if tick == 1 else 0, "%s quarantine emits cancellation once and no paid action during catch-up" % case.action)
		Input.action_release(case.action)
		var released := router.sample(4, Vector2.ZERO, Vector2.RIGHT)
		equal(released.held_actions, 0, "%s interrupted release leaves no paid hold" % case.action)
		equal(released.pressed_actions, 0, "%s interrupted release cannot create a new action or cancellation" % case.action)
		Input.action_press(case.action)
		var fresh := router.sample(5, Vector2.ZERO, Vector2.RIGHT)
		equal(fresh.held_actions, int(case.held), "%s fresh gameplay press restores exactly its paid hold" % case.action)
		equal(fresh.pressed_actions, int(case.pressed), "%s fresh gameplay press restores exactly its paid edge without stale cancellation" % case.action)
		Input.action_release(case.action)
		router.sample(6, Vector2.ZERO, Vector2.RIGHT)
	var direction_router := InputRouter.new()
	Input.action_press(&"move_right")
	direction_router.discard_transient_movement_input()
	var resumed_direction := direction_router.sample(7, Vector2.ZERO, Vector2.RIGHT)
	equal(resumed_direction.move_x, 1000, "ordinary directional movement may resume after a modal")
	equal(resumed_direction.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "resumed direction carries exactly the pending movement cancellation")
	equal(resumed_direction.held_actions, 0, "resumed direction cannot revive a paid hold")
	Input.action_release(&"move_right")
	# Quarantine follows the physical numbered action across Ctrl/Alt changes;
	# it cannot be bypassed by selecting a different Rapid slot while held.
	for layer: StringName in [InputRouter.SPELL_CTRL_LAYER_ACTION, InputRouter.SPELL_ALT_LAYER_ACTION]:
		for index: int in range(InputRouter.SPELL_ACTIONS.size()):
			var layer_router := InputRouter.new()
			layer_router.sample(0, Vector2.ZERO, Vector2.RIGHT)
			var action := InputRouter.SPELL_ACTIONS[index]
			Input.action_press(action)
			layer_router.discard_transient_movement_input()
			Input.action_press(layer)
			var blocked := layer_router.sample(0, Vector2.ZERO, Vector2.RIGHT)
			equal(blocked.held_actions, 0, "modifier changes cannot revive a quarantined Rapid hold")
			equal(blocked.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "modifier changes retain exactly cancellation and cannot revive a quarantined spell edge")
			Input.action_release(action)
			var released := layer_router.sample(1, Vector2.ZERO, Vector2.RIGHT)
			equal(released.pressed_actions, 0, "layered release cannot repeat interruption cancellation")
			equal(released.held_actions, 0, "layered release leaves no paid hold")
			Input.action_press(action)
			var fresh := layer_router.sample(2, Vector2.ZERO, Vector2.RIGHT)
			var slot := InputRouter.selected_spell_slot_index(index, layer == InputRouter.SPELL_CTRL_LAYER_ACTION, layer == InputRouter.SPELL_ALT_LAYER_ACTION)
			equal(fresh.pressed_actions, SimCommand.SPELL_PRESSED_BITS[slot], "fresh layered press restores exactly the selected slot without stale cancellation")
			equal(fresh.held_actions, SimCommand.SPELL_HELD_BITS[slot], "fresh layered press restores exactly the selected slot hold")
			Input.action_release(action)
			Input.action_release(layer)
	var wheel_router := InputRouter.new()
	_deliver_movement_event(wheel_router, _physical_key_event(KEY_SPACE, true))
	wheel_router.discard_transient_movement_input()
	_deliver_movement_event(wheel_router, _physical_key_event(KEY_SPACE, false))
	_deliver_movement_event(wheel_router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, true))
	var wheel := wheel_router.sample(8, Vector2.ZERO, Vector2.RIGHT)
	equal(wheel.pressed_actions, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_CANCEL_MOVEMENT, "direct router sampling retains the fresh wheel jump and undelivered cancellation exactly")
	equal(wheel.held_actions, 0, "released quarantine permits a fresh short wheel jump without fabricating a hold")
	_deliver_movement_event(wheel_router, _wheel_event(MOUSE_BUTTON_WHEEL_UP, false))


func _test_bootstrap_movement_cancel_guard() -> void:
	# A raw router may carry an undelivered cancellation beside a fresh press.
	# Bootstrap must deliver that cancellation during the modal/focus guard so
	# it cannot cancel the first legitimate action after gameplay resumes.
	var cases: Array[Dictionary] = [
		{"key": KEY_SPACE, "held": SimCommand.HELD_JUMP, "pressed": SimCommand.PRESSED_JUMP, "name": "jump"},
		{"key": KEY_C, "held": SimCommand.HELD_SLIDE, "pressed": SimCommand.PRESSED_SLIDE, "name": "slide"},
	]
	for focus_interruption: bool in [false, true]:
		for release_during_guard: bool in [false, true]:
			for case: Dictionary in cases:
				for action: StringName in InputRouter.PAID_ACTIONS + [&"move_left", &"move_right", &"move_up", &"move_down"]:
					Input.action_release(action)
				var node = BootstrapScript.new()
				node.input_router = InputRouter.new(7)
				var router: InputRouter = node.input_router
				var label := "%s %s release_%s_guard" % ["focus" if focus_interruption else "modal", case.name, "during" if release_during_guard else "after"]
				_deliver_movement_event(router, _physical_key_event(int(case.key), true))
				var initial: SimCommand = node._sample_gameplay_command(0, Vector2.ZERO, Vector2.RIGHT, false)
				equal(initial.pressed_actions, int(case.pressed), "%s starts with exactly the intended paid edge" % label)
				equal(initial.held_actions, int(case.held), "%s starts with exactly the intended paid hold" % label)
				Input.action_press(&"move_right")
				node.application_input_active = not focus_interruption
				for tick: int in range(1, 3):
					if tick == 2 and release_during_guard:
						_deliver_movement_event(router, _physical_key_event(int(case.key), false))
					var guarded: SimCommand = node._sample_gameplay_command(tick, Vector2.ZERO, Vector2.RIGHT, not focus_interruption)
					equal(guarded.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "%s blocked sample delivers exactly cancellation" % label)
					equal(guarded.held_actions, 0, "%s blocked sample clears interrupted held state" % label)
					equal(Vector2i(guarded.move_x, guarded.move_y), Vector2i.ZERO, "%s blocked sample suppresses directional movement" % label)
					check(not router.movement_cancel_pending, "%s delivered guard cancellation cannot leak into fresh gameplay" % label)
				node.application_input_active = true
				if not release_during_guard:
					var still_held: SimCommand = node._sample_gameplay_command(3, Vector2.ZERO, Vector2.RIGHT, false)
					equal(still_held.pressed_actions, 0, "%s interrupted hold stays quarantined after the guard" % label)
					equal(still_held.held_actions, 0, "%s interrupted hold cannot resume anticipation or flight" % label)
					_deliver_movement_event(router, _physical_key_event(int(case.key), false))
					var released: SimCommand = node._sample_gameplay_command(4, Vector2.ZERO, Vector2.RIGHT, false)
					equal(released.pressed_actions, 0, "%s interrupted release cannot become a paid action" % label)
					equal(released.held_actions, 0, "%s interrupted release leaves no held state" % label)
				_deliver_movement_event(router, _physical_key_event(int(case.key), true))
				var fresh: SimCommand = node._sample_gameplay_command(5, Vector2.ZERO, Vector2.RIGHT, false)
				equal(fresh.pressed_actions, int(case.pressed), "%s first fresh action has exactly its paid edge and no cancellation" % label)
				equal(fresh.held_actions, int(case.held), "%s first fresh action restores exactly its hold" % label)
				equal(Vector2i(fresh.move_x, fresh.move_y), Vector2i(1000, 0), "%s fresh action preserves resumed movement" % label)
				var catch_up: SimCommand = node._sample_gameplay_command(6, Vector2.ZERO, Vector2.RIGHT, false)
				equal(catch_up.pressed_actions, 0, "%s catch-up cannot replay the fresh edge or cancellation" % label)
				equal(catch_up.held_actions, int(case.held), "%s catch-up retains the legitimate fresh hold" % label)
				_deliver_movement_event(router, _physical_key_event(int(case.key), false))
				Input.action_release(&"move_right")
				router.sample(7, Vector2.ZERO, Vector2.RIGHT)
				node.free()


func _test_melee_modal_quarantine_without_wire_bits() -> void:
	for action: StringName in [InputRouter.PUNCH_ACTION, InputRouter.KICK_ACTION]:
		check(action in InputRouter.PAID_ACTIONS, "%s participates in modal paid-action quarantine" % action)
		Input.action_release(action)
		var router := InputRouter.new()
		Input.action_press(action)
		router.discard_transient_movement_input()
		check(router.quarantined_actions.has(action), "%s held through a modal is quarantined" % action)
		check(not router._paid_action_down(action), "%s cannot re-enter gameplay while its modal hold continues" % action)
		var no_wire_command := router.sample(0, Vector2.ZERO, Vector2.RIGHT)
		equal(no_wire_command.held_actions, 0, "%s has no premature SimCommand held bit in S4" % action)
		equal(no_wire_command.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "%s sends only interruption cancellation and no premature SimCommand melee bit in S4" % action)
		Input.action_release(action)
		var released := router.sample(1, Vector2.ZERO, Vector2.RIGHT)
		equal(released.pressed_actions, 0, "%s release cannot repeat interruption cancellation" % action)
		equal(released.held_actions, 0, "%s release leaves no paid hold" % action)
		check(not router.quarantined_actions.has(action), "%s release clears its modal quarantine" % action)
		Input.action_press(action)
		check(router._paid_action_down(action), "%s fresh press is available for the later S5 command authority" % action)
		Input.action_release(action)
		router.sample(2, Vector2.ZERO, Vector2.RIGHT)


func _test_s4_mouse_reconfiguration_clears_old_spell_aliases() -> void:
	var router := InputRouter.new()
	InputRouter._add_mouse_button(InputRouter.PRIMARY_ACTION, MOUSE_BUTTON_LEFT)
	InputRouter._add_mouse_button(InputRouter.ACTIVE_1_ACTION, MOUSE_BUTTON_RIGHT)
	check(_has_mouse_button(InputRouter.PRIMARY_ACTION, MOUSE_BUTTON_LEFT), "reused InputMap fixture begins with the old Primary mouse alias")
	check(_has_mouse_button(InputRouter.ACTIVE_1_ACTION, MOUSE_BUTTON_RIGHT), "reused InputMap fixture begins with the old Active mouse alias")
	check(router.configure_mouse_bindings(PlayerPreferences.DEFAULT_MOUSE_BINDINGS), "S4 mouse defaults replace all prior mouse events atomically after validation")
	check(not _has_mouse_button(InputRouter.PRIMARY_ACTION, MOUSE_BUTTON_LEFT), "S4 reconfiguration removes old Primary left mouse")
	check(not _has_mouse_button(InputRouter.ACTIVE_1_ACTION, MOUSE_BUTTON_RIGHT), "S4 reconfiguration removes old Active right mouse")
	check(_has_mouse_button(InputRouter.PUNCH_ACTION, MOUSE_BUTTON_LEFT), "S4 reconfiguration installs Punch left mouse")
	check(_has_mouse_button(InputRouter.KICK_ACTION, MOUSE_BUTTON_RIGHT), "S4 reconfiguration installs Kick right mouse")


func _deliver_movement_event(router: InputRouter, event: InputEvent) -> void:
	var fresh_event := event.duplicate() as InputEvent
	Input.parse_input_event(fresh_event)
	Input.flush_buffered_events()
	router.observe_input_event(fresh_event)


func _wheel_event(button: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _physical_key_event(key: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	return event


func _joy_button_event(button: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _keycodes(action: StringName) -> Array[int]:
	var result: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(event.physical_keycode)
	return result


func _has_mouse_button(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false


func _has_joy_button(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


func _test_capture_pointer_parser() -> void:
	var canvas := Vector2i(2560, 1440)
	equal(BootstrapScript.parse_capture_pointer("--capture-pointer=1280,720", canvas), Vector2i(1280, 720), "capture pointer accepts an in-campus world point")
	equal(BootstrapScript.parse_capture_pointer("--other=1280,720", canvas), Vector2i(-1, -1), "unrelated arguments do not enable capture pointer")
	equal(BootstrapScript.parse_capture_pointer("--capture-pointer=bad,720", canvas), Vector2i(-1, -1), "capture pointer rejects malformed coordinates")
	equal(BootstrapScript.parse_capture_pointer("--capture-pointer=-1,720", canvas), Vector2i(-1, -1), "capture pointer rejects negative coordinates")
	equal(BootstrapScript.parse_capture_pointer("--capture-pointer=2560,720", canvas), Vector2i(-1, -1), "capture pointer rejects the exclusive canvas boundary")
	equal(BootstrapScript.camera_origin_for(Vector2(1280, 720), Vector2i(1280, 720), canvas, 110, 100), Vector2(640, 305), "100 percent camera preserves the original focus geometry")
	equal(BootstrapScript.camera_origin_for(Vector2(1280, 720), Vector2i(1280, 720), canvas, 110, 50), Vector2(0, 0), "wide camera clamps safely against the campus edge")
	equal(BootstrapScript.parse_farflow_mode("--farflow=host"), "host", "diagnostic Farflow host mode parses")
	equal(BootstrapScript.parse_farflow_mode("--farflow=JOIN"), "join", "diagnostic Farflow join mode is case-insensitive")
	equal(BootstrapScript.parse_farflow_mode("--farflow=relay"), "", "unknown Farflow mode fails closed")
	check(BootstrapScript.has_emote_smoke_argument("--farflow-smoke-emote"), "diagnostic social smoke switch parses exactly")
	check(not BootstrapScript.has_emote_smoke_argument("--farflow-smoke-emote=true"), "diagnostic social smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_prediction_smoke_argument("--farflow-smoke-prediction"), "diagnostic prediction smoke switch parses exactly")
	check(not BootstrapScript.has_prediction_smoke_argument("--farflow-smoke-prediction=true"), "diagnostic prediction smoke switch fails closed on alternate syntax")
	equal(BootstrapScript.snapshot_tick_interval(120), 2, "120 Hz match publishes 60 snapshots per second")
	equal(BootstrapScript.snapshot_tick_interval(60), 0, "retired 60 Hz cadence fails closed")
	equal(BootstrapScript.snapshot_tick_interval(90), 0, "unsupported match cadence cannot derive a snapshot interval")
	check(BootstrapScript.has_reconnect_smoke_argument("--farflow-smoke-reconnect"), "diagnostic reconnect smoke switch parses exactly")
	check(not BootstrapScript.has_reconnect_smoke_argument("--farflow-smoke-reconnect=true"), "diagnostic reconnect smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_hearth_smoke_argument("--farflow-smoke-hearth"), "diagnostic Hearth smoke switch parses exactly")
	check(not BootstrapScript.has_hearth_smoke_argument("--farflow-smoke-hearth=true"), "diagnostic Hearth smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_round_smoke_argument("--farflow-smoke-round"), "diagnostic court smoke switch parses exactly")
	check(not BootstrapScript.has_round_smoke_argument("--farflow-smoke-round=true"), "diagnostic court smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_rematch_smoke_argument("--farflow-smoke-rematch"), "diagnostic rematch smoke switch parses exactly")
	check(not BootstrapScript.has_rematch_smoke_argument("--farflow-smoke-rematch=true"), "diagnostic rematch smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_steward_smoke_argument("--farflow-smoke-steward"), "diagnostic stewardship smoke switch parses exactly")
	check(not BootstrapScript.has_steward_smoke_argument("--farflow-smoke-steward=true"), "diagnostic stewardship smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_spectator_smoke_argument("--farflow-smoke-spectator"), "diagnostic spectator smoke switch parses exactly")
	check(not BootstrapScript.has_spectator_smoke_argument("--farflow-smoke-spectator=true"), "diagnostic spectator smoke switch fails closed on alternate syntax")
	check(BootstrapScript.has_safe_quit_smoke_argument("--safe-quit-smoke"), "diagnostic safe-quit smoke switch parses exactly")
	check(not BootstrapScript.has_safe_quit_smoke_argument("--safe-quit-smoke=true"), "diagnostic safe-quit smoke switch fails closed on alternate syntax")
	check(BootstrapScript.reconnect_smoke_prerequisites_met(false, false, false, false), "standalone reconnect smoke may begin after its first snapshot")
	check(not BootstrapScript.reconnect_smoke_prerequisites_met(true, false, true, true), "combined smoke waits until the reliable social request is sent")
	check(not BootstrapScript.reconnect_smoke_prerequisites_met(true, true, true, false), "combined smoke waits for authoritative movement confirmation")
	check(BootstrapScript.reconnect_smoke_prerequisites_met(true, true, true, true), "combined smoke leaves only after interaction is sent and movement passes")
	check(not BootstrapScript.reconnect_smoke_prerequisites_met(true, true, true, true, true, false), "combined smoke waits for shared Hearth start")
	check(BootstrapScript.reconnect_smoke_prerequisites_met(true, true, true, true, true, true), "combined smoke leaves after shared Hearth start is received")
	equal(BootstrapScript.parse_session_charter("--session-charter=SPARRING_CIRCLE"), "sparring_circle", "diagnostic charter override is case-insensitive")
	equal(BootstrapScript.parse_session_charter("--session-charter=unbounded"), "", "unknown diagnostic charter fails closed")
	equal(BootstrapScript.parse_session_charter("--other=duel_knot"), "", "unrelated argument cannot change the charter")
	equal(BootstrapScript.parse_capture_spawn("--capture-spawn=2380,800", canvas), Vector2i(2380, 800), "capture-only spawn accepts an in-campus station point")
	equal(BootstrapScript.parse_capture_spawn("--capture-spawn=2560,800", canvas), Vector2i(-1, -1), "capture-only spawn rejects the canvas boundary")
	equal(BootstrapScript.parse_capture_spawn("--other=2380,800", canvas), Vector2i(-1, -1), "unrelated argument cannot change capture spawn")
	equal(BootstrapScript.parse_capture_spell_slot("--capture-cast-slot=12"), 12, "diagnostic cast accepts Alt+4")
	equal(BootstrapScript.parse_capture_spell_slot("--capture-cast-slot=13"), 0, "diagnostic cast rejects positions beyond the weave")
	equal(BootstrapScript.parse_capture_spell_slot("--capture-cast-slot=bad"), 0, "diagnostic cast rejects malformed positions")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=SLIDE"), "slide", "diagnostic movement capture is case-insensitive")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=roll"), "roll", "grounded roll has an explicit production-command capture")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=air_chain"), "air_chain", "physical airborne chain has a production input capture")
	check(not BootstrapScript.capture_movement_command("air_chain", 23, 1).has_held(SimCommand.HELD_JUMP), "chain capture releases before the second jump")
	check(BootstrapScript.capture_movement_command("air_chain", 24, 1).has_pressed(SimCommand.PRESSED_JUMP), "chain capture issues a real fresh second jump")
	check(BootstrapScript.capture_movement_command("air_chain", 40, 1).has_pressed(SimCommand.PRESSED_EVADE), "chain capture issues an actual airborne evade")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=float_release"), "float_release", "held Float has a production-input capture")
	check(not BootstrapScript.capture_movement_command("float_release", 23, 1).has_held(SimCommand.HELD_JUMP), "Float capture releases the first jump")
	check(BootstrapScript.capture_movement_command("float_release", 24, 1).has_pressed(SimCommand.PRESSED_JUMP), "Float capture freshly activates the second airborne action")
	check(BootstrapScript.capture_movement_command("float_release", 63, 1).has_held(SimCommand.HELD_JUMP), "Float capture sustains through its last protected input")
	check(not BootstrapScript.capture_movement_command("float_release", 64, 1).has_held(SimCommand.HELD_JUMP), "Float capture releases into vulnerable descent")
	var float_turn: SimCommand = BootstrapScript.capture_movement_command("float_release", 40, 1)
	equal(Vector2i(float_turn.move_x, float_turn.move_y), Vector2i(0, 1000), "Float capture requests a real midair direction change")
	var roll_capture: SimCommand = BootstrapScript.capture_movement_command("roll", 6, 1, Vector2i(707, -707))
	check(roll_capture.has_pressed(SimCommand.PRESSED_EVADE), "roll capture presses the real Evade command")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=grounded"), "grounded", "diagnostic grounded pose capture is explicit")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=hit"), "hit", "diagnostic launched-hit capture is explicit")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=reverse"), "reverse", "diagnostic reversal capture is explicit")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=impact_recovery"), "impact_recovery", "diagnostic recovery capture is explicit")
	equal(BootstrapScript.parse_capture_movement("--capture-movement=teleport"), "", "unknown movement capture fails closed")
	equal(BootstrapScript.parse_capture_direction("--capture-direction=south"), Vector2i(0, 1000), "movement capture accepts fixed-point south")
	equal(BootstrapScript.parse_capture_direction("--capture-direction=WEST"), Vector2i(-1000, 0), "movement capture direction is case-insensitive")
	equal(BootstrapScript.parse_capture_direction("--capture-direction=north_east"), Vector2i(707, -707), "movement capture accepts normalized north-east")
	equal(BootstrapScript.parse_capture_direction("--capture-direction=south_west"), Vector2i(-707, 707), "movement capture accepts normalized south-west")
	equal(BootstrapScript.parse_capture_direction("--capture-direction=diagonal"), Vector2i.ZERO, "movement capture rejects unknown directions")
	equal(BootstrapScript.parse_capture_chain_spell_slot("--capture-chain-slot=12"), 12, "diagnostic occupied-channel capture accepts the final layered slot")
	equal(BootstrapScript.parse_capture_chain_spell_slot("--capture-chain-slot=13"), 0, "diagnostic occupied-channel capture rejects overflow")
	equal(Array(BootstrapScript.parse_capture_spell_sequence("--capture-spell-sequence=2, 3,1,1")), [2, 3, 1, 1], "density capture accepts an ordered sequence with deliberate repeated pressure casts")
	check(BootstrapScript.parse_capture_spell_sequence("--capture-spell-sequence=1,13").is_empty(), "density capture rejects a slot outside the twelve-position weave")
	check(BootstrapScript.parse_capture_spell_sequence("--capture-spell-sequence=1,spell").is_empty(), "density capture rejects malformed positions")
	check(BootstrapScript.parse_capture_spell_sequence("--other=1,2").is_empty(), "unrelated arguments cannot schedule diagnostic casts")
	var display_order_bolts := PackedInt32Array([140, 145, 163, 159, 173, 142])
	var retired_bursts := PackedInt32Array([147, 146, 148, 149, 150, 151, 152, 153])
	equal(BootstrapScript.parse_capture_spell_wires("--capture-spell-wires=140,145,163,159,173,142"), display_order_bolts, "capture-only weave accepts the six live Bolts in canonical display order")
	check(BootstrapScript.parse_capture_spell_wires("--capture-spell-wires=140,159,145,163,170,101,173,142").is_empty(), "capture-only weave rejects the old eight-Bolt set containing retired Ice and Charge")
	check(BootstrapScript.parse_capture_spell_wires("--capture-spell-wires=140,140").is_empty(), "capture-only weave rejects duplicate wires")
	check(BootstrapScript.parse_capture_spell_wires("--capture-spell-wires=140,110").is_empty(), "capture-only weave rejects a known non-playable wire")
	check(BootstrapScript.parse_capture_spell_wires("--capture-spell-wires=140,spell").is_empty(), "capture-only weave rejects malformed wire values")
	check(BootstrapScript.parse_capture_spell_wires("--capture-spell-wires=147,146,148,149,150,151,152,153").is_empty(), "capture-only weave rejects the retired Burst set")
	check(BootstrapScript.parse_capture_spell_wires("--other=140").is_empty(), "unrelated arguments cannot replace the capture weave")
	var capture_state := PlayerState.new(71)
	var before_retired_apply := capture_state.canonical_values()
	check(not BootstrapScript.apply_capture_spell_wires(capture_state, PackedInt32Array([140, 140])), "direct capture caller rejects duplicate live wires before placement")
	equal(capture_state.canonical_values(), before_retired_apply, "duplicate refusal preserves the complete player state")
	check(not BootstrapScript.apply_capture_spell_wires(capture_state, retired_bursts), "retired Burst wires cannot enter a capture-only player weave")
	equal(capture_state.canonical_values(), before_retired_apply, "rejected retired Burst capture leaves the player unchanged")
	for retired_wire: int in [101, 167, 170, 171, 187, 188, 189, 190]:
		check(not BootstrapScript.apply_capture_spell_wires(capture_state, PackedInt32Array([140, retired_wire])), "retired Ice/Charge wire%d rejects the entire mixed capture weave" % retired_wire)
		equal(capture_state.canonical_values(), before_retired_apply, "rejected retired element capture leaves every player value unchanged")
	check(BootstrapScript.apply_capture_spell_wires(capture_state, display_order_bolts), "capture-only weave applies retained Bolts through ordinary proven-spell placement")
	for bolt_index: int in range(display_order_bolts.size()):
		equal(capture_state.spell_wire_id(bolt_index + 1), display_order_bolts[bolt_index], "capture-only weave keeps requested Bolt display order at slot %d" % (bolt_index + 1))
	var slide_capture: SimCommand = BootstrapScript.capture_movement_command("slide", 6, 1)
	check(slide_capture.has_held(SimCommand.HELD_SPRINT) and slide_capture.has_held(SimCommand.HELD_SLIDE) and slide_capture.has_pressed(SimCommand.PRESSED_SLIDE), "slide capture uses the ordinary held semantic sprint-slide command")
	var slide_release: SimCommand = BootstrapScript.capture_movement_command("slide", 42, 1)
	check(not slide_release.has_held(SimCommand.HELD_SLIDE), "slide capture releases paid sustain after the authored maximum")
	var north_slide: SimCommand = BootstrapScript.capture_movement_command("slide", 6, 1, Vector2i.UP)
	equal(Vector2i(north_slide.move_x, north_slide.move_y), Vector2i(0, -1000), "movement capture applies the requested cardinal direction")
	equal(Vector2i(north_slide.aim_x, north_slide.aim_y), Vector2i(0, -1000), "movement capture keeps aim aligned to the cardinal review direction")
	var diagonal_slide: SimCommand = BootstrapScript.capture_movement_command("slide", 6, 1, Vector2i(707, -707))
	equal(Vector2i(diagonal_slide.move_x, diagonal_slide.move_y), Vector2i(707, -707), "movement capture preserves normalized diagonal travel")
	equal(Vector2i(diagonal_slide.aim_x, diagonal_slide.aim_y), Vector2i(707, -707), "movement capture keeps aim aligned to diagonal review travel")
	var grounded_start: SimCommand = BootstrapScript.capture_movement_command("grounded", 0, 1, Vector2i(707, 707))
	equal(Vector2i(grounded_start.move_x, grounded_start.move_y), Vector2i(707, 707), "grounded capture establishes its diagonal facing once")
	var grounded_hold: SimCommand = BootstrapScript.capture_movement_command("grounded", 1, 1, Vector2i(707, 707))
	equal(Vector2i(grounded_hold.move_x, grounded_hold.move_y), Vector2i.ZERO, "grounded capture releases movement after establishing facing")
	equal(Vector2i(grounded_hold.aim_x, grounded_hold.aim_y), Vector2i(707, 707), "grounded capture keeps diagonal review aim")
	var air_capture: SimCommand = BootstrapScript.capture_movement_command("air_dodge", 12, 1)
	check(air_capture.has_held(SimCommand.HELD_JUMP) and air_capture.has_pressed(SimCommand.PRESSED_EVADE), "air capture uses the explicit Evade command")
	var brake_capture: SimCommand = BootstrapScript.capture_movement_command("brake", 30, 1)
	equal(brake_capture.move_x, 0, "brake capture releases ordinary movement at its exact review tick")
	var reverse_capture: SimCommand = BootstrapScript.capture_movement_command("reverse", 30, 1)
	equal(reverse_capture.move_x, -1000, "reversal capture counter-strafes at its exact review tick")
	var recovery_capture: SimCommand = BootstrapScript.capture_movement_command("impact_recovery", 8, 1)
	equal(Vector2i(recovery_capture.move_x, recovery_capture.move_y), Vector2i(0, -1000), "recovery capture supplies bounded launch influence without a fake player action")
	var capture_stations := {"farflow-charter": {}}
	equal(BootstrapScript.parse_capture_expanded_station("--capture-expanded-station=farflow-charter", capture_stations), "farflow-charter", "capture-only station expansion accepts an authored station")
	equal(BootstrapScript.parse_capture_expanded_station("--capture-expanded-station=missing", capture_stations), "", "capture-only station expansion rejects unknown stations")
	equal(BootstrapScript.parse_capture_expanded_station("--other=farflow-charter", capture_stations), "", "unrelated argument cannot expand a station")
	equal(BootstrapScript.ui_scale_for(Vector2(1280, 720)), 1.0, "authored 720p uses the one-to-one UI design grid")
	equal(BootstrapScript.ui_scale_for(Vector2(1920, 1080)), 1.5, "1080p scales the UI design grid for equivalent readability")
	equal(BootstrapScript.ui_scale_for(Vector2(2560, 1080)), 1.5, "wide output derives UI scale from its limiting height")
	check(BootstrapScript.is_transient_preference_argument("--pov-mode=cone"), "capture POV override is explicitly transient")
	check(BootstrapScript.is_transient_preference_argument("--camera-zoom=50"), "capture camera override is explicitly transient")
	check(not BootstrapScript.is_transient_preference_argument("--session-port=24922"), "ordinary session arguments do not suppress preference persistence")


func _test_accessible_aim_and_deadzones() -> void:
	var router := InputRouter.new()
	var prefs := PlayerPreferences.new()
	prefs.movement_deadzone_percent=40
	prefs.aim_deadzone_percent=10
	prefs.keyboard_bindings[&"aim_up"]=KEY_I
	router.configure_keyboard_bindings(prefs.keyboard_bindings)
	router.configure_controller_bindings(prefs.controller_bindings)
	router.configure_accessibility(prefs)
	for action: StringName in [&"move_left",&"move_right",&"move_up",&"move_down"]+InputRouter.AIM_ACTIONS: Input.action_release(action)
	var left := InputEventJoypadMotion.new()
	left.axis=JOY_AXIS_LEFT_X
	left.axis_value=0.3
	_deliver_movement_event(router,left)
	var right := InputEventJoypadMotion.new()
	right.axis=JOY_AXIS_RIGHT_Y
	right.axis_value=0.2
	_deliver_movement_event(router,right)
	var command := router.sample(0,Vector2.ZERO,Vector2.LEFT)
	equal(command.move_x,0,"movement drift cannot borrow the lower aim deadzone")
	equal(Vector2i(command.aim_x,command.aim_y),Vector2i(0,1000),"aim accepts a deliberate tilt below movement threshold")
	left.axis_value=0.0
	right.axis_value=0.0
	_deliver_movement_event(router,left)
	_deliver_movement_event(router,right)
	_deliver_movement_event(router,_physical_key_event(KEY_I,true))
	command=router.sample(1,Vector2.ZERO,Vector2.RIGHT)
	equal(Vector2i(command.aim_x,command.aim_y),Vector2i(0,-1000),"real remappable keyboard aim reaches the command")
	equal(command.aim_target_x,-1,"digital aim uses the same directional endpoint as a stick")
	router.discard_transient_movement_input()
	command=router.sample(2,Vector2.ZERO,Vector2.RIGHT)
	check(router.quarantined_actions.has(&"aim_up"),"menu-held digital aim stays quarantined")
	_deliver_movement_event(router,_physical_key_event(KEY_I,false))
	router.sample(3,Vector2.ZERO,Vector2.RIGHT)
	check(not router.quarantined_actions.has(&"aim_up"),"neutral release rearms digital aim")
	prefs.aim_deadzone_percent=25
	router.configure_accessibility(prefs)
	for action: StringName in [&"aim_right",&"aim_down"]: Input.action_press(action,0.2)
	router.discard_transient_movement_input()
	check(router.quarantined_actions.has(&"aim_right") and router.quarantined_actions.has(&"aim_down"),"radial diagonal aim is quarantined even below each axis threshold")
	for action: StringName in InputRouter.AIM_ACTIONS: Input.action_release(action)
	router.sample(4,Vector2.ZERO,Vector2.RIGHT)
	check(router.quarantined_actions.is_empty(),"neutral diagonal releases every modal aim quarantine")
	prefs=PlayerPreferences.new()
	router.configure_keyboard_bindings(prefs.keyboard_bindings)
	router.configure_accessibility(prefs)
