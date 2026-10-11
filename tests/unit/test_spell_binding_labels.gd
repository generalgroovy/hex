extends FluxTestSuite

const Labels = preload("res://src/presentation/spell_binding_labels.gd")


func run() -> int:
	_test_default_and_priority()
	_test_all_slots()
	_test_finite_compact_labels()
	_test_unknown_and_unbound()
	_test_hidden_cast()
	return finish("spell-binding-labels")


func _empty_preferences() -> PlayerPreferences:
	var preferences := PlayerPreferences.new()
	for action: StringName in preferences.keyboard_bindings: preferences.keyboard_bindings[action] = 0
	for action: StringName in preferences.mouse_bindings: preferences.mouse_bindings[action] = 0
	for action: StringName in preferences.controller_bindings: preferences.controller_bindings[action] = PlayerPreferences.unbound_controller_binding()
	return preferences


func _saved_bytes(preferences: PlayerPreferences) -> PackedByteArray:
	return var_to_bytes([preferences.keyboard_bindings, preferences.mouse_bindings, preferences.controller_bindings])


func _test_default_and_priority() -> void:
	var defaults := PlayerPreferences.new()
	var before := _saved_bytes(defaults)
	for slot: int in PlayerState.SPELL_SLOT_COUNT:
		var prefix := "" if slot < 4 else "Ctrl+" if slot < 8 else "Alt+"
		equal(SpellLoomPresenter.slot_binding_label(slot, defaults), prefix + str(slot % 4 + 1), "default keyboard labels remain exact across all twelve slots")
	equal(_saved_bytes(defaults), before, "reading defaults never writes saved preferences")
	var preferences := _empty_preferences()
	preferences.keyboard_bindings[&"spell_1"] = KEY_T
	preferences.mouse_bindings[&"spell_1"] = MOUSE_BUTTON_MIDDLE
	preferences.controller_bindings[&"spell_1"] = {"kind": "button", "index": JOY_BUTTON_A, "direction": 0}
	equal(Labels.action_label(&"spell_1", preferences), "T", "explicit saved keyboard mapping leads despite other devices")
	preferences.keyboard_bindings[&"spell_1"] = 0
	equal(Labels.action_label(&"spell_1", preferences), "MOUSE M", "saved mouse is used when keyboard is unbound")
	preferences.mouse_bindings[&"spell_1"] = 0
	equal(Labels.action_label(&"spell_1", preferences), "PAD A", "saved pad is used when keyboard and mouse are unbound")
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	equal(SpellLoomPresenter.slot_binding_label(4, preferences), "Shift+PAD A", "actual aggregate input permits mixed-device saved chords")
	preferences.controller_bindings[&"spell_1"] = {"kind": "axis", "index": JOY_AXIS_RIGHT_X, "direction": -1}
	equal(CompactCombatHud.button_binding_label(0, preferences), "PAD RX-", "HUD preserves saved axis identity and sign")
	preferences.controller_bindings[&"spell_1"].direction = 1
	equal(SpellLoomPresenter.slot_binding_label(0, preferences), "PAD RX+", "labels read changed saved descriptors without a stale device cache")
	equal(PlayerPreferences.validate_keyboard_bindings(preferences.keyboard_bindings), "", "priority fixture has valid saved keyboard assignments")
	equal(PlayerPreferences.validate_mouse_bindings(preferences.mouse_bindings), "", "priority fixture has valid saved mouse assignments")
	equal(PlayerPreferences.validate_controller_bindings(preferences.controller_bindings), "", "priority fixture has valid saved controller assignments")


func _test_all_slots() -> void:
	var preferences := _empty_preferences()
	var mouse_buttons := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1]
	var mouse_labels := ["MOUSE L", "MOUSE R", "MOUSE M", "MOUSE X1"]
	for index: int in PlayerState.SPELL_BUTTON_COUNT:
		preferences.mouse_bindings[StringName("spell_%d" % (index + 1))] = mouse_buttons[index]
	preferences.mouse_bindings[&"spell_layer_ctrl"] = MOUSE_BUTTON_XBUTTON2
	preferences.keyboard_bindings[&"spell_layer_alt"] = KEY_ALT
	_assert_slot_matrix(preferences, mouse_labels, "MOUSE X2", "Alt")
	preferences = _empty_preferences()
	var pad_buttons := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]
	var pad_labels := ["PAD UP", "PAD RGT", "PAD DN", "PAD LEFT"]
	for index: int in PlayerState.SPELL_BUTTON_COUNT:
		preferences.controller_bindings[StringName("spell_%d" % (index + 1))] = {"kind": "button", "index": pad_buttons[index], "direction": 0}
	preferences.controller_bindings[&"spell_layer_ctrl"] = {"kind": "button", "index": JOY_BUTTON_LEFT_SHOULDER, "direction": 0}
	preferences.controller_bindings[&"spell_layer_alt"] = {"kind": "button", "index": JOY_BUTTON_RIGHT_SHOULDER, "direction": 0}
	_assert_slot_matrix(preferences, pad_labels, "PAD LB", "PAD RB")


func _assert_slot_matrix(preferences: PlayerPreferences, buttons: Array, ctrl: String, alt: String) -> void:
	var before := _saved_bytes(preferences)
	for slot: int in PlayerState.SPELL_SLOT_COUNT:
		var prefix := "" if slot < 4 else ctrl + "+" if slot < 8 else alt + "+"
		var full := prefix + String(buttons[slot % 4])
		equal(SpellLoomPresenter.slot_binding_label(slot, preferences), full, "all twelve saved device chords retain their correct modifier and button")
		equal(CompactCombatHud.button_binding_label(slot % 4, preferences), buttons[slot % 4], "HUD button matches the shared Loom input label")
		var cap := SpellLoomPresenter.slot_keycap(slot, preferences)
		check(ThemeDB.fallback_font.get_string_size(cap.label, HORIZONTAL_ALIGNMENT_LEFT, -1, cap.font_size).x <= SpellLoomEditor.slot_rect(slot).size.x - 18, "fallback chord fits existing compact Loom card")
		check(cap.label == full or (String(cap.label).ends_with("...") and full.begins_with(String(cap.label).trim_suffix("..."))), "fitted keycap remains a truthful label or visible prefix")
	equal(CompactCombatHud.binding_layer_label(0, preferences), "PLAIN SPELLS", "plain layer remains unchanged")
	equal(CompactCombatHud.binding_layer_label(1, preferences), ctrl + " SPELLS", "HUD first modifier follows actual saved input")
	equal(CompactCombatHud.binding_layer_label(2, preferences), alt + " SPELLS", "HUD second modifier follows actual saved input")
	equal(_saved_bytes(preferences), before, "slot and fitting reads never mutate any saved device binding")


func _test_finite_compact_labels() -> void:
	var preferences := _empty_preferences()
	for button: int in range(MOUSE_BUTTON_LEFT, MOUSE_BUTTON_XBUTTON2 + 1):
		preferences.mouse_bindings[&"spell_1"] = button
		_assert_button_fit(preferences, "mouse")
	preferences.mouse_bindings[&"spell_1"] = 0
	for button: int in range(32):
		preferences.controller_bindings[&"spell_1"] = {"kind": "button", "index": button, "direction": 0}
		_assert_button_fit(preferences, "controller button")
	for axis: int in range(16):
		for direction: int in [-1, 1]:
			preferences.controller_bindings[&"spell_1"] = {"kind": "axis", "index": axis, "direction": direction}
			_assert_button_fit(preferences, "controller axis")
			check(Labels.action_label(&"spell_1", preferences).ends_with("-" if direction < 0 else "+"), "every supported axis sign remains explicit")


func _assert_button_fit(preferences: PlayerPreferences, kind: String) -> void:
	var before := _saved_bytes(preferences)
	var label := CompactCombatHud.button_binding_label(0, preferences)
	check(not label.is_empty() and label != "-" and label != "?", kind + " retains a real assigned label")
	check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 54.0, kind + " fits the existing 64px HUD key box without clipping")
	equal(_saved_bytes(preferences), before, kind + " formatting is read-only")


func _test_unknown_and_unbound() -> void:
	var preferences := _empty_preferences()
	for slot: int in PlayerState.SPELL_SLOT_COUNT:
		equal(SpellLoomPresenter.slot_binding_label(slot, preferences), "Not bound", "all-device unbound remains distinct from a fallback binding")
	equal(CompactCombatHud.button_binding_label(0, preferences), "-", "HUD retains compact truly-unbound marker")
	equal(CompactCombatHud.binding_layer_label(1, preferences), "LAYER UNBOUND", "modifier unbound on every device remains explicit")
	equal(CompactCombatHud.button_binding_label(0, null), "?", "unknown preferences never invent a default input")
	equal(SpellLoomPresenter.slot_binding_label(0, null), "Binding unavailable", "Loom unknown preferences remain distinct from unbound")
	for slot: int in [-1, PlayerState.SPELL_SLOT_COUNT]:
		equal(SpellLoomPresenter.slot_binding_label(slot, preferences), "Invalid slot", "invalid slots do not alias saved inputs")
	for invalid: Variant in [null, [], {}, {"kind": "button", "index": 32, "direction": 0}, {"kind": "button", "index": 0, "direction": 1}, {"kind": "axis", "index": 0, "direction": 0}, {"kind": "axis", "index": 16, "direction": 1}, {"kind": "button", "index": "0", "direction": 0}]:
		preferences.controller_bindings[&"spell_1"] = invalid
		equal(Labels.action_label(&"spell_1", preferences), "", "malformed controller descriptor cannot advertise a working input")
	preferences.controller_bindings.clear()
	preferences.mouse_bindings.clear()
	preferences.keyboard_bindings.clear()
	equal(Labels.action_label(&"spell_1", preferences), "", "missing saved lanes do not synthesize defaults")


func _test_hidden_cast() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "hidden-cast fixture loads actual abilities")
	var state := PlayerState.new()
	state.spell_wire_ids.fill(0)
	state.spell_wire_ids[4] = 101
	state.pending_cast_wire_id = 101
	state.pending_cast_ticks = 1
	var preferences := _empty_preferences()
	preferences.mouse_bindings[&"spell_1"] = MOUSE_BUTTON_MIDDLE
	preferences.controller_bindings[&"spell_layer_ctrl"] = {"kind": "button", "index": JOY_BUTTON_LEFT_SHOULDER, "direction": 0}
	var before := state.canonical_values()
	var saved := _saved_bytes(preferences)
	var cue := CompactCombatHud.hidden_cast_status(state, abilities, 0, preferences)
	check(String(cue.get("label", "")).ends_with("PAD LB+MOUSE M"), "already-paid hidden cast shows the real saved fallback chord")
	equal(state.canonical_values(), before, "binding presentation leaves simulation authority untouched")
	equal(_saved_bytes(preferences), saved, "hidden cast leaves all saved inputs untouched")
