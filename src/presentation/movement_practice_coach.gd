class_name MovementPracticeCoach
extends RefCounted


# Read-only execution hints distilled from MovementGuideModel and the live
# MovementSystem gates. The caller owns free-practice/local-player/UI admission
# and supplies the validated south-movement-loop rectangle and active device.
static func sample(state: PlayerState, preferences: PlayerPreferences, bounds_pixels: Rect2i, device: int = ControlBindingEditor.DEVICE_KEYBOARD, allowed: bool = true) -> Dictionary:
	if not allowed or preferences == null or not inside_area(state, bounds_pixels) or device < 0 or device >= ControlBindingEditor.DEVICE_COUNT:
		return {}
	var editor := ControlBindingEditor.new()
	var jump := _binding(editor, preferences, &"jump", device)
	var technique := _binding(editor, preferences, &"technique", device)
	var sprint := _binding(editor, preferences, &"sprint", device)
	var evade := _binding(editor, preferences, &"evade", device)
	var slide := _binding(editor, preferences, &"slide", device)
	var kind := "grounded"
	var title := "SOUTH LOOP / WALK OR WALL"
	var lines := PackedStringArray()
	if state.control_state not in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED] or state.impact_recovery_ticks > 0:
		kind = "control"
		title = "SOUTH LOOP / REGAIN CONTROL"
		lines = ["Wait for this control state or recovery to clear.", "The walking loop bypasses the optional walls."]
	elif state.jumpsquat_active:
		kind = "jumpsquat"
		title = "SOUTH LOOP / PREPARE THEN RELEASE"
		lines = ["Release %s to jump; hold charges a little higher." % jump, "Still grounded: projectiles and floor effects hit."]
	elif state.movement_commitment_ticks > 0:
		kind = "commitment"
		title = "SOUTH LOOP / FINISH THE OPENING"
		lines = ["Let the opening movement commitment finish.", "A new action still needs its own Stamina and gate."]
	elif state.flight_capable and state.air_floating and state.float_ticks > 0 and state.stamina > 0:
		kind = "flight"
		title = "SOUTH LOOP / FLIGHT"
		lines = ["Hold %s to fly; release to fall. No immunity." % jump, "Neutral %s / fresh %s: fast fall, no protection." % [evade, slide]]
		if _wheel_jump(preferences, device):
			lines[0] = "A wheel pulse cannot sustain flight; use a button."
		elif jump == "UNBOUND":
			lines[0] = "Jump is UNBOUND; set a hold input at Controls."
		if evade == "UNBOUND" and slide == "UNBOUND":
			lines[1] = "Evade and Slide UNBOUND; set a fast-fall input."
		elif evade == "UNBOUND":
			lines[1] = "Fresh %s: zero-cost fast fall, no protection." % slide
		elif slide == "UNBOUND":
			lines[1] = "Neutral %s: zero-cost fast fall, no protection." % evade
	elif state.wall_skim_ticks > 0:
		kind = "wallrun"
		title = "SOUTH LOOP / WALLRUN"
		lines = ["Release %s + move: outward walljump; no immunity." % jump, "Neutral %s: fast fall + detach; walls do not refill." % evade]
		if jump == "UNBOUND":
			lines[0] = "Jump UNBOUND; steer away to detach."
		if evade == "UNBOUND":
			lines[1] = "Evade UNBOUND; walls refill no spent air budgets."
	elif state.is_airborne():
		kind = "airborne"
		title = "SOUTH LOOP / STEER THE EXIT"
		lines = ["", "Steer freely; spent air budgets reset on landing."]
		if evade == "UNBOUND":
			lines[0] = "Evade UNBOUND; set it at Controls for fast fall/dodge."
		elif state.air_dodge_used:
			lines[0] = "%s neutral: free fast fall; dodge spent until landing." % evade
		else:
			# The earlier control/commitment branches already suppress blocked
			# actions. Match the remaining air-dodge budget and paid-cost gates;
			# neutral Evade still takes its independent, zero-cost fast-fall path.
			var dodge_cost := MovementSystem._movement_action_cost(state, MovementTuning.AIR_DODGE_COST)
			if state.stamina < dodge_cost:
				lines[0] = "%s neutral: free fast fall; dodge needs " % evade + MovementGuideModel._units(dodge_cost) + " Stamina."
			else:
				lines[0] = "%s neutral: free fast fall; +move: paid dodge." % evade
		var can_turn := state.hop_ticks > 0 and state.air_redirects_remaining > 0 and technique != "UNBOUND" and state.stamina >= MovementSystem._movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST) and Vector2i(state.air_velocity_x, state.air_velocity_y) != Vector2i.ZERO
		if (state.flight_capable and not state.float_used) or (not state.flight_capable and not state.double_jump_used):
			lines[1] = "Press again + hold %s: paid flight, finite time." % jump if state.flight_capable else "Fresh %s: one paid double jump; steer freely." % jump
			if jump == "UNBOUND":
				lines[1] = "Jump is UNBOUND; set it at Controls."
			elif state.flight_capable and _wheel_jump(preferences, device):
				lines[1] = "Wheel is a pulse; bind Jump to a hold button."
		elif can_turn:
			lines[1] = "%s + new direction: paid turn; air budget spent." % technique
		if state.wall_memory_ticks > 0 and state.wall_contact_id > 0 and jump != "UNBOUND":
			# A wheel pulse can jump, but InputRouter never turns it into the
			# held Jump required for wallrun. Do not overwrite that distinction.
			lines[1] = "Wallrun needs held Jump; bind a button at Controls." if _wheel_jump(preferences, device) else "Hold %s + along wall: wallrun. Release: walljump." % jump
	else:
		lines = ["Walk around walls; %s adds paid sprint." % sprint, "Press then release %s: jump. %s + move: roll." % [jump, evade]]
		if sprint == "UNBOUND":
			lines[0] = "Walk around walls; Sprint is UNBOUND."
		if jump == "UNBOUND":
			lines[1] = "%s rolls by move/facing; Jump is UNBOUND." % evade
		if evade == "UNBOUND":
			lines[1] = "Evade UNBOUND; set it at Controls for ground roll."
		if state.stamina == 0:
			lines = ["Walk the loop; ordinary movement is free.", "Wall routes are optional; keep the walking lane."]
	return {"kind": kind, "title": title, "phase": "STAMINA %s/%s" % [MovementGuideModel._units(state.stamina), MovementGuideModel._units(state.stamina_maximum)], "lines": lines}


static func inside_area(state: PlayerState, bounds_pixels: Rect2i) -> bool:
	if state == null or state.entity_id <= 0 or state.health <= 0 or state.stamina < 0 or state.stamina_maximum <= 0 or state.stamina > state.stamina_maximum or not bounds_pixels.has_area():
		return false
	var fixed := Rect2i(bounds_pixels.position * SimConfig.FIXED_SCALE, bounds_pixels.size * SimConfig.FIXED_SCALE)
	return fixed.has_point(Vector2i(state.position_x, state.position_y))


static func _binding(editor: ControlBindingEditor, preferences: PlayerPreferences, action: StringName, device: int) -> String:
	# Keyboard and mouse are one play setup. Prefer its held keyboard input;
	# a mouse binding is the fallback, not a reason to hide a valid keyboard key.
	var label := editor.binding_label(action, ControlBindingEditor.DEVICE_CONTROLLER if device == ControlBindingEditor.DEVICE_CONTROLLER else ControlBindingEditor.DEVICE_KEYBOARD, preferences)
	if label == "—" and device != ControlBindingEditor.DEVICE_CONTROLLER:
		label = editor.binding_label(action, ControlBindingEditor.DEVICE_MOUSE, preferences)
	return "UNBOUND" if label == "—" else label


static func _wheel_jump(preferences: PlayerPreferences, device: int) -> bool:
	return device != ControlBindingEditor.DEVICE_CONTROLLER and int(preferences.keyboard_bindings.get(&"jump", 0)) == 0 and int(preferences.mouse_bindings.get(&"jump", 0)) in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
