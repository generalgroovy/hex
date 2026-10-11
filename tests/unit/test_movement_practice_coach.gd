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
	_test_wheel_only_wallrun_guidance()
	_test_air_dodge_hints()
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
	preferences.keyboard_bindings[&"jump"] = KEY_K
	preferences.keyboard_bindings[&"sprint"] = KEY_L
	var view := Coach.sample(state, preferences, bounds)
	equal(view.kind, "grounded", "ground hint teaches ordinary movement")
	check(_text(view).contains("L") and _text(view).contains("release K"), "ground hint follows sprint and release-jump bindings")
	check(not _text(view).contains("wallrun"), "ground hint cannot offer grounded wallrun")
	state.jumpsquat_active = true
	view = Coach.sample(state, preferences, bounds)
	equal(view.kind, "jumpsquat", "anticipation has a specific release hint")
	check(_text(view).contains("Still grounded"), "anticipation does not imply low-profile avoidance")
	state.jumpsquat_active = false
	state.wall_skim_ticks = 30
	view = Coach.sample(state, preferences, bounds)
	equal(view.kind, "wallrun", "actual wallrun wins over ordinary air")
	check(_text(view).contains("Release K") and _text(view).contains("no immunity"), "release walljump and wall vulnerability are explicit")
	state.wall_skim_ticks = 0
	state.air_height = 20000
	state.hop_ticks = 30
	view = Coach.sample(state, preferences, bounds)
	check(_text(view).contains("one paid double jump") and not _text(view).contains("flight"), "ordinary races get double jump, not Float")
	state.double_jump_used = true
	check(_text(Coach.sample(state, preferences, bounds)).contains("spent air budgets"), "used extra jump remains spent")
	state.flight_capable = true
	view = Coach.sample(state, preferences, bounds)
	check(_text(view).contains("Press again + hold K") and _text(view).contains("finite time"), "capable race sees held finite flight")
	state.air_floating = true
	state.float_ticks = 30
	view = Coach.sample(state, preferences, bounds)
	equal(view.kind, "flight", "paid flight is its own context")
	check(_text(view).contains("No immunity"), "flight never advertises universal protection")
	state.air_floating = false
	state.wall_memory_ticks = 4
	state.wall_contact_id = 115
	check(_text(Coach.sample(state, preferences, bounds)).contains("along wall") and _text(Coach.sample(state, preferences, bounds)).contains("Release: walljump"), "near wall teaches hold-along then release")
	state.wall_memory_ticks = 0
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_WHEEL_UP
	check(_text(Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_MOUSE)).contains("Press again + hold K"), "mouse input retains keyboard hold binding")
	preferences.keyboard_bindings[&"jump"] = 0
	check(_text(Coach.sample(state, preferences, bounds)).contains("Wheel is a pulse"), "wheel cannot promise sustained flight")
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_MIDDLE
	check(_text(Coach.sample(state, preferences, bounds)).contains("MIDDLE BUTTON"), "mouse fallback is a real hold input")
	preferences.mouse_bindings[&"jump"] = 0
	check(_text(Coach.sample(state, preferences, bounds)).contains("UNBOUND"), "missing Jump is explicit")
	check(_text(Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_CONTROLLER)).contains("SOUTH / A"), "controller follows its own binding")
	state.movement_commitment_ticks = 1
	equal(Coach.sample(state, preferences, bounds).kind, "commitment", "commitment does not promise another action")
	state.control_state = PlayerState.ControlState.STUNNED
	equal(Coach.sample(state, preferences, bounds).kind, "control", "forced control takes priority")


func _test_wheel_only_wallrun_guidance() -> void:
	var state := _state()
	state.air_height = 20_000
	state.hop_ticks = 30
	state.wall_memory_ticks = 4
	state.wall_contact_id = 115
	var world := SimWorld.new(120, 933)
	world.players[0] = state
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"jump"] = 0
	for wheel: int in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		preferences.mouse_bindings[&"jump"] = wheel
		for flight_capable: bool in [false, true]:
			state.flight_capable = flight_capable
			for device: int in [ControlBindingEditor.DEVICE_KEYBOARD, ControlBindingEditor.DEVICE_MOUSE]:
				var before := world.state_hash()
				var saved := preferences.to_dictionary().duplicate(true)
				var view := Coach.sample(state, preferences, bounds, device)
				equal(view.kind, "airborne", "wheel wallrun regression reaches the wall-contact airborne branch")
				equal(view.lines[1], "Wallrun needs held Jump; bind a button at Controls.", "wall contact cannot overwrite a wheel-only hold limitation")
				check(not _text(view).contains("Hold WHEEL") and not _text(view).contains("Release: walljump"), "pulse-only bindings do not promise held entry or held release")
				check(ThemeDB.fallback_font.get_string_size(view.lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 412, "wheel recovery guidance fits the unchanged compact card")
				equal(world.state_hash(), before, "wheel guidance changes no paid action, timing or air budget")
				equal(preferences.to_dictionary(), saved, "wheel guidance never silently binds a hold button")
	# A keyboard binding remains usable even when the latest event was a wheel.
	preferences.keyboard_bindings[&"jump"] = KEY_K
	for device: int in [ControlBindingEditor.DEVICE_KEYBOARD, ControlBindingEditor.DEVICE_MOUSE]:
		equal(Coach.sample(state, preferences, bounds, device).lines[1], "Hold K + along wall: wallrun. Release: walljump.", "keyboard plus wheel retains the real held keyboard instruction")
	preferences.keyboard_bindings[&"jump"] = 0
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_MIDDLE
	check(_text(Coach.sample(state, preferences, bounds)).contains("Hold MIDDLE BUTTON + along wall"), "holdable mouse fallback still offers wallrun")
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_WHEEL_UP
	check(_text(Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_CONTROLLER)).contains("Hold SOUTH / A + along wall"), "controller hold does not inherit another device's wheel limitation")
	preferences.controller_bindings[&"jump"] = PlayerPreferences.unbound_controller_binding()
	check(_text(Coach.sample(state, preferences, bounds, ControlBindingEditor.DEVICE_CONTROLLER)).contains("UNBOUND"), "unbound controller does not borrow mouse wheel or invent a hold")
	preferences.mouse_bindings[&"jump"] = 0
	check(_text(Coach.sample(state, preferences, bounds)).contains("UNBOUND"), "fully unbound Jump retains its existing recovery advice")
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_WHEEL_UP
	state.wall_memory_ticks = 0
	state.flight_capable = false
	check(_text(Coach.sample(state, preferences, bounds)).contains("Fresh WHEEL UP: one paid double jump"), "ordinary wheel tap remains a legal fresh double-jump hint away from walls")
	state.flight_capable = true
	check(_text(Coach.sample(state, preferences, bounds)).contains("Wheel is a pulse"), "flight wheel limitation remains intact away from walls")
	state.wall_memory_ticks = 4
	state.movement_commitment_ticks = 1
	equal(Coach.sample(state, preferences, bounds).kind, "commitment", "opening commitment still precedes wallrun instruction")
	state.control_state = PlayerState.ControlState.STUNNED
	equal(Coach.sample(state, preferences, bounds).kind, "control", "forced control still precedes wheel recovery guidance")


func _test_air_dodge_hints() -> void:
	var cases: Array[Dictionary] = [
		{"name": "ready", "used": false, "chain": 0, "reset": 0, "offset": 1, "status": "paid"},
		{"name": "base equality", "used": false, "chain": 0, "reset": 0, "offset": 0, "status": "paid"},
		{"name": "base underfunded", "used": false, "chain": 0, "reset": 0, "offset": -1, "status": "needs"},
		{"name": "empty Stamina", "used": false, "chain": 0, "reset": 0, "offset": -MovementTuning.AIR_DODGE_COST, "status": "needs"},
		{"name": "spent", "used": true, "chain": 0, "reset": 0, "offset": 1, "status": "spent"},
		{"name": "spent before affordability", "used": true, "chain": 0, "reset": 0, "offset": -1, "status": "spent"},
		{"name": "chain equality", "used": false, "chain": 2, "reset": 10, "offset": 0, "status": "paid"},
		{"name": "chain underfunded", "used": false, "chain": 2, "reset": 10, "offset": -1, "status": "needs"},
		{"name": "capped chain equality", "used": false, "chain": MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS + 3, "reset": 10, "offset": 0, "status": "paid"},
		{"name": "capped chain underfunded", "used": false, "chain": MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS + 3, "reset": 10, "offset": -1, "status": "needs"},
		{"name": "expired chain equality", "used": false, "chain": MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS, "reset": 0, "offset": 0, "status": "paid"},
	]
	var bindings: Array[Dictionary] = [
		{"name": "default keyboard", "device": ControlBindingEditor.DEVICE_KEYBOARD, "label": "B"},
		{"name": "custom keyboard", "device": ControlBindingEditor.DEVICE_KEYBOARD, "key": KEY_K, "label": "K"},
		{"name": "keyboard before mouse", "device": ControlBindingEditor.DEVICE_MOUSE, "key": KEY_K, "mouse": MOUSE_BUTTON_MIDDLE, "label": "K"},
		{"name": "mouse fallback", "device": ControlBindingEditor.DEVICE_KEYBOARD, "key": 0, "mouse": MOUSE_BUTTON_MIDDLE, "label": "MIDDLE BUTTON"},
		{"name": "wheel pulse", "device": ControlBindingEditor.DEVICE_MOUSE, "key": 0, "mouse": MOUSE_BUTTON_WHEEL_DOWN, "label": "WHEEL DOWN"},
		{"name": "default controller", "device": ControlBindingEditor.DEVICE_CONTROLLER, "label": "LEFT TRIGGER +"},
		{"name": "custom controller button", "device": ControlBindingEditor.DEVICE_CONTROLLER, "controller": {"kind": "button", "index": JOY_BUTTON_RIGHT_SHOULDER, "direction": 0}, "label": "R SHOULDER"},
		{"name": "custom controller axis", "device": ControlBindingEditor.DEVICE_CONTROLLER, "controller": {"kind": "axis", "index": JOY_AXIS_TRIGGER_RIGHT, "direction": 1}, "label": "RIGHT TRIGGER +"},
		{"name": "unbound keyboard and mouse", "device": ControlBindingEditor.DEVICE_KEYBOARD, "key": 0, "mouse": 0, "label": "UNBOUND"},
		{"name": "unbound controller", "device": ControlBindingEditor.DEVICE_CONTROLLER, "controller": PlayerPreferences.unbound_controller_binding(), "label": "UNBOUND"},
	]
	var world := SimWorld.new(120, 931)
	for binding: Dictionary in bindings:
		var preferences := PlayerPreferences.new()
		if binding.has("key"):
			preferences.keyboard_bindings[&"evade"] = int(binding.key)
		if binding.has("mouse"):
			preferences.mouse_bindings[&"evade"] = int(binding.mouse)
		if binding.has("controller"):
			preferences.controller_bindings[&"evade"] = binding.controller.duplicate(true)
		var saved := preferences.to_dictionary().duplicate(true)
		for scenario: Dictionary in cases:
			var state := _state()
			state.air_height = 20_000
			state.hop_ticks = 30
			state.double_jump_used = true
			state.air_dodge_used = bool(scenario.used)
			state.movement_chain_count = int(scenario.chain)
			state.movement_chain_reset_ticks = int(scenario.reset)
			var cost := MovementSystem._movement_action_cost(state, MovementTuning.AIR_DODGE_COST)
			state.stamina = cost + int(scenario.offset)
			world.players[0] = state
			var before := world.state_hash()
			var view := Coach.sample(state, preferences, bounds, int(binding.device))
			var context := "%s / %s" % [binding.name, scenario.name]
			equal(view.kind, "airborne", context + ": tests the ordinary airborne branch")
			equal(view.lines.size(), 2, context + ": retains the two-line card")
			var line := String(view.lines[0])
			if String(binding.label) == "UNBOUND":
				equal(line, "Evade UNBOUND; set it at Controls for fast fall/dodge.", context + ": unbound input never borrows another device or claims an action")
			else:
				check(line.begins_with(String(binding.label) + " neutral: free fast fall;"), context + ": actual bound neutral input remains zero-cost")
				match String(scenario.status):
					"paid":
						check(line.ends_with("+move: paid dodge."), context + ": unused affordable dodge retains directional instruction")
					"spent":
						check(line.ends_with("dodge spent until landing."), context + ": only landing restores the spent opportunity")
						check(not line.contains("paid dodge") and not line.contains("needs"), context + ": spent budget wins over resource amount")
					"needs":
						check(line.ends_with("dodge needs " + MovementGuideModel._units(cost) + " Stamina."), context + ": displays current authoritative chain-adjusted cost")
						check(not line.contains("paid dodge"), context + ": cannot advertise an unaffordable paid action")
			for visible_line: String in view.lines:
				check(ThemeDB.fallback_font.get_string_size(visible_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 412, context + ": real-font line fits existing 412px width: " + visible_line)
			equal(world.state_hash(), before, context + ": sampling leaves authority unchanged")
			equal(preferences.to_dictionary(), saved, context + ": sampling preserves customized bindings")
			state.movement_commitment_ticks = 1
			equal(Coach.sample(state, preferences, bounds, int(binding.device)).kind, "commitment", context + ": commitment takes precedence over availability")
			state.control_state = PlayerState.ControlState.STUNNED
			equal(Coach.sample(state, preferences, bounds, int(binding.device)).kind, "control", context + ": forced control takes precedence over availability")


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
			state.flight_capable = false
			state.double_jump_used = false
			state.jumpsquat_active = false
			state.hop_ticks = 0
			state.air_redirects_remaining = 0
			match context:
				1: state.wall_skim_ticks = 20
				2: state.air_height = 20_000
				3:
					state.air_height = 20_000
					state.flight_capable = true
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
	check(String(guide.execution).contains("along its face"), "wall guide requires along-face movement")
	check(String(guide.timing_note).contains("refills no air budget"), "wall guide explicitly preserves spent air budgets")
	guide = MovementGuideModel.entry_by_id("double_jump", preferences)
	check(String(guide.execution).contains("double jump") and String(guide.execution).contains("hold"), "compact extra-air instruction matches production guide")
