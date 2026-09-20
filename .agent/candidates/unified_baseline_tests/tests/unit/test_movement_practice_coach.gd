extends FluxTestSuite

const Coach = preload("res://src/presentation/movement_practice_coach.gd")
var bounds := Rect2i()


func run() -> int:
	var campus := SanctumCampusLayout.new()
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "coach tests load the actual southern annex")
	for area: Dictionary in campus.data.activity_areas:
		if String(area.id) == "south-movement-loop":
			bounds = SanctumCampusLayout._parse_bounds(area.bounds)
	check(bounds.has_area(), "southern movement-loop bounds come from validated map content")
	_test_admission()
	_test_context_and_bindings()
	_test_source_and_fit()
	return finish("movement-practice-coach")


func _state() -> PlayerState:
	var state := PlayerState.new(1)
	var point := bounds.position * SimConfig.FIXED_SCALE + Vector2i(100_000, 100_000)
	state.position_x = point.x
	state.position_y = point.y
	return state


func _text(view: Dictionary) -> String:
	return " ".join(view.get("lines", PackedStringArray()))


func _test_admission() -> void:
	var state := _state()
	var preferences := PlayerPreferences.new()
	check(not Coach.sample(state, preferences, bounds).is_empty(), "alive local fixture inside actual area receives a hint")
	check(Coach.sample(state, preferences, bounds, 0, false).is_empty(), "caller owns menu/round/spectator/identity denial")
	check(Coach.sample(null, preferences, bounds).is_empty(), "absent actor fails closed")
	check(Coach.sample(state, null, bounds).is_empty(), "absent current bindings fail closed")
	check(Coach.sample(state, preferences, Rect2i()).is_empty(), "missing authored area cannot invent a practice region")
	for device: int in [-1, ControlBindingEditor.DEVICE_COUNT]:
		check(Coach.sample(state, preferences, bounds, device).is_empty(), "unknown device cannot fabricate default controls")
	for offset: Vector2i in [Vector2i.ZERO, bounds.size * SimConfig.FIXED_SCALE - Vector2i.ONE]:
		var point := bounds.position * SimConfig.FIXED_SCALE + offset
		state.position_x = point.x
		state.position_y = point.y
		check(Coach.inside_area(state, bounds), "inclusive start and last fixed unit stay in authored area")
	for point: Vector2i in [bounds.position * SimConfig.FIXED_SCALE - Vector2i.ONE, bounds.end * SimConfig.FIXED_SCALE]:
		state.position_x = point.x
		state.position_y = point.y
		check(not Coach.inside_area(state, bounds), "outside and exclusive end never enlarge the practice area")
	state = _state()
	state.health = 0
	check(Coach.sample(state, preferences, bounds).is_empty(), "dead actor is not coached")
	state = _state()
	state.entity_id = 0
	check(Coach.sample(state, preferences, bounds).is_empty(), "missing identity is not coached")
	state = _state()
	state.stamina = -1
	check(Coach.sample(state, preferences, bounds).is_empty(), "invalid resource state fails closed")
	state.stamina = state.stamina_maximum + 1
	check(Coach.sample(state, preferences, bounds).is_empty(), "overmaximum resource state fails closed")


func _test_context_and_bindings() -> void:
	var state := _state()
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"technique"] = KEY_J
	preferences.keyboard_bindings[&"jump"] = KEY_K
	preferences.keyboard_bindings[&"sprint"] = KEY_L
	var grounded := Coach.sample(state, preferences, bounds)
	equal(grounded.kind, "grounded", "ordinary ground state teaches the walking bypass first")
	check(_text(grounded).contains("Walk around walls") and _text(grounded).contains("L") and _text(grounded).contains("J"), "ground hint follows rebound Sprint/Technique")
	state.stamina = 0
	check(_text(Coach.sample(state, preferences, bounds)).contains("ordinary movement is free"), "empty Stamina preserves the ordinary bypass")
	state.stamina = state.stamina_maximum
	state.wall_skim_ticks = 30
	state.hop_stage = 1
	var wall := Coach.sample(state, preferences, bounds)
	equal(wall.kind, "wallrun", "live wallrun takes precedence over generic airborne state")
	check(_text(wall).contains("Fresh K + away") and _text(wall).contains("do not refill"), "wall hint teaches a deliberate kick without resetting air budgets")
	state.hop_stage = 2
	check(not _text(Coach.sample(state, preferences, bounds)).contains("wall kick"), "spent kick stage cannot promise another wall kick")
	check(_text(Coach.sample(state, preferences, bounds)).contains("J again"), "spent wall kick offers a real detachment instead")
	state.wall_skim_ticks = 0
	state.air_height = 20_000
	state.hop_ticks = 30
	state.air_redirects_remaining = 1
	state.air_velocity_x = 200_000
	var air := Coach.sample(state, preferences, bounds)
	equal(air.kind, "airborne", "real height drives the airborne hint")
	check(_text(air).contains("B neutral: zero-cost fast fall") and _text(air).contains("+move: paid dodge"), "air hint teaches neutral and directional Evade with the active binding")
	check(_text(air).contains("J + new direction") and _text(air).contains("hold K"), "air turn and fresh held Float use active bindings")
	state.hop_stage = 1
	state.wall_memory_ticks = 4
	state.wall_contact_id = 115
	check(_text(Coach.sample(state, preferences, bounds)).contains("fresh K + away") and not _text(Coach.sample(state, preferences, bounds)).contains("Float"), "remembered first-stage wall contact does not mislabel outward Jump as Float")
	state.wall_memory_ticks = 0
	state.hop_stage = 2
	state.air_redirects_remaining = 0
	state.float_used = true
	air = Coach.sample(state, preferences, bounds)
	check(_text(air).contains("B neutral: zero-cost fast fall") and _text(air).contains("Steer freely") and _text(air).contains("until landing"), "spent air budgets retain free steering and truthful neutral fast fall")
	state.air_redirects_remaining = 1
	state.movement_chain_count = 4
	state.movement_chain_reset_ticks = 10
	state.stamina = MovementSystem._movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST) - 1
	check(not _text(Coach.sample(state, preferences, bounds)).contains("paid turn"), "insufficient current chain-adjusted Stamina does not advertise a paid turn")
	state.stamina += 1
	check(_text(Coach.sample(state, preferences, bounds)).contains("paid turn"), "turn hint follows the real chain-adjusted cost boundary")
	state.air_floating = true
	state.float_ticks = 30
	var floating := Coach.sample(state, preferences, bounds)
	equal(floating.kind, "float", "actual active Float is distinct from ordinary airborne state")
	check(_text(floating).contains("Hold K") and _text(floating).contains("paid height + protection") and _text(floating).contains("Neutral B") and _text(floating).contains("no protection"), "Float and neutral fast fall state their actual protection boundary")
	var saved_evade_key := int(preferences.keyboard_bindings.get(&"evade", 0))
	var saved_evade_mouse := int(preferences.mouse_bindings.get(&"evade", 0))
	preferences.keyboard_bindings[&"evade"] = 0
	preferences.mouse_bindings[&"evade"] = 0
	var slide_only := _text(Coach.sample(state, preferences, bounds))
	check(slide_only.contains("Fresh C") and not slide_only.contains("Neutral UNBOUND"), "Float hint selects the bound Slide alias when Evade is unbound")
	preferences.keyboard_bindings[&"evade"] = saved_evade_key
	preferences.mouse_bindings[&"evade"] = saved_evade_mouse
	var saved_slide_key := int(preferences.keyboard_bindings.get(&"slide", 0))
	var saved_slide_mouse := int(preferences.mouse_bindings.get(&"slide", 0))
	preferences.keyboard_bindings[&"slide"] = 0
	preferences.mouse_bindings[&"slide"] = 0
	var evade_only := _text(Coach.sample(state, preferences, bounds))
	check(evade_only.contains("Neutral B") and not evade_only.contains("fresh UNBOUND"), "Float hint selects the bound neutral Evade alias when Slide is unbound")
	preferences.keyboard_bindings[&"slide"] = saved_slide_key
	preferences.mouse_bindings[&"slide"] = saved_slide_mouse
	state.movement_commitment_ticks = 1
	equal(Coach.sample(state, preferences, bounds).kind, "commitment", "opening commitment does not imply immediate transition readiness")
	state.control_state = PlayerState.ControlState.STUNNED
	equal(Coach.sample(state, preferences, bounds).kind, "control", "external control takes priority over action instructions")
	state = _state()
	state.air_height = 20_000
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_WHEEL_UP
	check(_text(Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_MOUSE)).contains("hold K"), "mouse activity retains the current held keyboard binding")
	preferences.keyboard_bindings[&"jump"] = 0
	check(_text(Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_MOUSE)).contains("Wheel is a pulse"), "wheel mapping is not falsely described as a sustained Float input")
	check(_text(Coach.sample(state, preferences, bounds)).contains("Wheel is a pulse"), "keyboard-unbound setup also sees the mouse wheel limitation")
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_MIDDLE
	check(_text(Coach.sample(state, preferences, bounds)).contains("hold MIDDLE BUTTON"), "an actual mouse hold binding is the keyboard-unbound fallback")
	preferences.mouse_bindings[&"jump"] = 0
	check(_text(Coach.sample(state, preferences, bounds)).contains("UNBOUND"), "missing Jump never falls back to an invented default")
	var controller := Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_CONTROLLER)
	check(_text(controller).contains("SOUTH / A") and not _text(controller).contains("UNBOUND"), "controller uses its own bindings rather than keyboard state")


func _test_source_and_fit() -> void:
	var preferences := PlayerPreferences.new()
	var world := SimWorld.new(120, 929)
	var state := _state()
	world.players[0] = state
	state.stamina = 123_400
	state.stamina_maximum = 456_000
	var before := world.state_hash()
	var saved := preferences.to_dictionary().duplicate(true)
	for device: int in range(ControlBindingEditor.DEVICE_COUNT):
		for context: int in range(7):
			state.control_state = PlayerState.ControlState.FREE
			state.movement_commitment_ticks = 0
			state.wall_skim_ticks = 0
			state.air_floating = false
			state.air_height = 0
			state.float_used = false
			state.hop_ticks = 0
			state.air_redirects_remaining = 0
			match context:
				1: state.wall_skim_ticks = 20
				2: state.air_height = 20_000
				3:
					state.air_height = 20_000
					state.air_floating = true
					state.float_ticks = 20
				4: state.control_state = PlayerState.ControlState.ROOTED
				5: state.movement_commitment_ticks = 1
				6:
					state.air_height = 20_000
					state.hop_ticks = 30
					state.air_redirects_remaining = 1
					state.air_velocity_x = 200_000
			before = world.state_hash()
			var view := Coach.sample(state, preferences, bounds, device)
			equal(view.phase, "STAMINA 123.4/456", "resource line uses current selected actor values")
			equal(view.lines.size(), 2, "every context stays within the two-line compact card")
			check(ThemeDB.fallback_font.get_string_size(view.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 412, "context title fits the existing compact card width")
			check(ThemeDB.fallback_font.get_string_size(view.phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 412, "actual resource line fits the existing compact card width")
			for line: String in view.lines:
				check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 412, "current device execution hint fits at 12px without wrapping: %s" % line)
				check(not line.contains("mastery") and not line.contains("invulnerable") and not line.contains("achievement"), "contextual instructions invent no achievement or immunity")
			equal(world.state_hash(), before, "sampling never mutates simulation or air budgets")
			equal(preferences.to_dictionary(), saved, "sampling never rewrites bindings or preferences")
	var guide := MovementGuideModel.entry_by_id("wall_run", preferences)
	check(String(guide.execution).contains("along its face") and String(guide.timing_note).contains("does not refill"), "compact wall instruction retains full guide's execution and finite budget caveat")
	guide = MovementGuideModel.entry_by_id("double_jump", preferences)
	check(String(guide.execution).contains("release and press") and String(guide.execution).contains("current height"), "compact Float instruction is grounded in the production guide")
