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
	elif state.movement_commitment_ticks > 0:
		kind = "commitment"
		title = "SOUTH LOOP / FINISH THE OPENING"
		lines = ["Let the opening movement commitment finish.", "A new action still needs its own Stamina and gate."]
	elif state.air_floating and state.float_ticks > 0 and state.stamina > 0:
		kind = "float"
		title = "SOUTH LOOP / FLOAT"
		lines = ["Hold %s: paid height + protection; release to fall." % jump, "Neutral %s / fresh %s: fast fall, no protection." % [evade, slide]]
		if _wheel_jump(preferences, device):
			lines[0] = "A wheel pulse cannot sustain Float; use a button."
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
		lines = ["Steer away to detach into ordinary descent.", "Neutral %s: fast fall + detach; walls do not refill." % evade]
		if state.hop_stage < 2 and jump != "UNBOUND":
			lines[0] = "Fresh %s + away: try a paid wall kick." % jump
		elif technique != "UNBOUND":
			lines[0] = "%s again or steer away to detach." % technique
		if evade == "UNBOUND":
			lines[1] = "Evade UNBOUND; walls refill no spent air budgets."
	elif state.is_airborne():
		kind = "airborne"
		title = "SOUTH LOOP / STEER THE EXIT"
		lines = ["%s neutral: zero-cost fast fall; +move: paid dodge." % evade, "Steer freely; spent Float stays spent until landing."]
		if evade == "UNBOUND":
			lines[0] = "Evade UNBOUND; set it at Controls for fast fall/dodge."
		var can_turn := state.hop_ticks > 0 and state.air_redirects_remaining > 0 and technique != "UNBOUND" and state.stamina >= MovementSystem._movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST) and Vector2i(state.air_velocity_x, state.air_velocity_y) != Vector2i.ZERO
		if not state.float_used:
			lines[1] = "Fresh press + hold %s: paid Float." % jump
			if jump == "UNBOUND":
				lines[1] = "Jump is UNBOUND; set it at Controls for Float."
			elif _wheel_jump(preferences, device):
				lines[1] = "Wheel is a pulse; bind Jump to a hold button."
			elif can_turn:
				lines[1] = "%s + new direction: paid turn; press + hold %s: Float." % [technique, jump]
		elif can_turn:
			lines[1] = "%s + new direction: paid turn; Float stays spent." % technique
		# The actual Jump dispatch prefers a remembered first-stage wall kick
		# when steering outward; do not label that same input as Float here.
		if state.hop_ticks > 0 and state.hop_stage == 1 and state.wall_memory_ticks > 0 and state.wall_contact_id > 0 and jump != "UNBOUND":
			lines[1] = "Near wall: fresh %s + away tries a paid kick." % jump
	else:
		lines = ["Walk around walls; %s adds paid sprint." % sprint, "%s rolls by move/facing; wall + %s: wallrun." % [evade, technique]]
		if sprint == "UNBOUND":
			lines[0] = "Walk around walls; Sprint is UNBOUND."
		if technique == "UNBOUND":
			lines[1] = "%s rolls by move/facing; Technique is UNBOUND." % evade
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
