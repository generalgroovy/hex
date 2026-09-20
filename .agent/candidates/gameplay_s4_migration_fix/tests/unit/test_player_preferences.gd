extends FluxTestSuite


class FailedReplacementPreferences:
	extends PlayerPreferences
	var fail_backup: bool = false
	var fail_primary: bool = false
	func _replace_staged_profile(staged_path: String, path: String) -> Error:
		if (fail_backup and path.ends_with(PRE_S4_CONTROLS_BACKUP_SUFFIX)) or (fail_primary and not path.ends_with(PRE_S4_CONTROLS_BACKUP_SUFFIX)):
			return ERR_CANT_CREATE
		return super._replace_staged_profile(staged_path, path)


func run() -> int:
	_test_defaults_and_presets()
	_test_validation()
	_test_schema_v1_migration_and_reduced_motion()
	_test_keyboard_bindings()
	_test_persistence_round_trip()
	_test_recoverable_profile_preservation()
	_test_movement_transforms()
	_test_evade_default_swap_migration()
	_test_keyboard_default_revision()
	_test_s4_control_default_migration()
	_test_s4_custom_control_preservation_and_notices()
	_test_optional_sound_volume()
	_test_controller_spell_default_candidate()
	_test_controller_default_revision()
	return finish("player-preferences")


func _test_recoverable_profile_preservation() -> void:
	var folder := "user://profile-preservation-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK, "owned preservation fixture directory created")
	var path := folder + "/preferences.json"
	var backup_path := path + PlayerPreferences.PRE_S4_CONTROLS_BACKUP_SUFFIX
	var legacy_backup_path := path + PlayerPreferences.PRE_FOUR_DELIVERY_BACKUP_SUFFIX
	var original_preferences := PlayerPreferences.new()
	original_preferences.keyboard_bindings[&"jump"] = KEY_J
	original_preferences.mouse_bindings[&"jump"] = 0
	original_preferences.controller_bindings[&"jump"] = {"kind": "none", "index": -1, "direction": 0}
	# Validate custom bindings before they become the preservation fixture.
	var source := original_preferences.to_dictionary()
	check(original_preferences.apply_dictionary(source), "custom three-device profile is valid")
	var original_bytes := ("  " + JSON.stringify(source, "  ") + "\n\n").to_utf8_buffer()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(original_bytes)
	file.close()
	var legacy_backup_bytes := original_bytes.duplicate()
	file = FileAccess.open(legacy_backup_path, FileAccess.WRITE)
	file.store_buffer(legacy_backup_bytes)
	file.close()
	var preferences := FailedReplacementPreferences.new()
	check(preferences.load_from_file(path), "custom existing profile loads")
	preferences.sound_volume_percent = 45
	preferences.fail_backup = true
	check(not preferences.save_to_file(path), "failed backup installation blocks primary rewrite")
	equal(FileAccess.get_file_as_bytes(path), original_bytes, "failed backup preserves the exact original bytes")
	check(not FileAccess.file_exists(backup_path), "failed backup does not claim a recovery copy")
	equal(preferences.keyboard_bindings, original_preferences.keyboard_bindings, "backup failure preserves live keyboard bindings")
	preferences.fail_backup = false
	preferences.fail_primary = true
	check(not preferences.save_to_file(path), "failed primary installation is reported")
	equal(FileAccess.get_file_as_bytes(path), original_bytes, "failed primary replacement never truncates original")
	equal(FileAccess.get_file_as_bytes(backup_path), original_bytes, "recovery bytes remain usable after failed primary installation")
	preferences.fail_primary = false
	check(preferences.save_to_file(path), "staged primary replacement succeeds")
	var reloaded := PlayerPreferences.new()
	check(reloaded.load_from_file(path), "rewritten primary loads")
	equal(reloaded.keyboard_bindings, original_preferences.keyboard_bindings, "keyboard bindings survive rewrite")
	equal(reloaded.mouse_bindings, original_preferences.mouse_bindings, "mouse bindings survive rewrite")
	equal(reloaded.controller_bindings, original_preferences.controller_bindings, "controller bindings survive rewrite")
	equal(reloaded.sound_volume_percent, 45, "requested setting persists")
	preferences.sound_volume_percent = 55
	check(preferences.save_to_file(path), "repeat save succeeds")
	equal(FileAccess.get_file_as_bytes(backup_path), original_bytes, "repeat save never overwrites pre-overhaul recovery copy")
	equal(FileAccess.get_file_as_bytes(legacy_backup_path), legacy_backup_bytes, "S4 persistence never overwrites the earlier delivery backup")
	var invalid_bytes := "{ damaged profile".to_utf8_buffer()
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(invalid_bytes)
	file.close()
	check(not reloaded.load_from_file(path), "damaged primary fails closed")
	reloaded.reset_to_defaults()
	check(not reloaded.save_to_file(path), "default reset cannot overwrite damaged existing profile")
	equal(FileAccess.get_file_as_bytes(path), invalid_bytes, "failed-load save leaves damaged file recoverable")
	equal(FileAccess.get_file_as_bytes(backup_path), original_bytes, "damaged primary cannot replace good backup")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "owned damaged fixture removed")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path)) == OK, "owned recovery fixture removed")
	check(reloaded.save_to_file(path), "missing profile can create defaults")
	check(not FileAccess.file_exists(backup_path), "new profile does not invent a pre-migration backup")
	var new_profile_bytes := FileAccess.get_file_as_bytes(path)
	file = FileAccess.open(backup_path, FileAccess.WRITE)
	file.store_buffer(invalid_bytes)
	file.close()
	check(not reloaded.save_to_file(path), "damaged recovery copy blocks rewriting an otherwise valid primary")
	equal(FileAccess.get_file_as_bytes(path), new_profile_bytes, "damaged recovery copy leaves valid primary intact")
	equal(FileAccess.get_file_as_bytes(backup_path), invalid_bytes, "damaged recovery copy is retained for inspection")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path)) == OK, "owned damaged recovery fixture removed")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "owned new profile removed")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_backup_path)) == OK, "owned legacy recovery fixture removed")
	var directory := DirAccess.open(folder)
	equal(directory.get_files().size(), 0, "failed replacements leave no staged scratch")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(folder)) == OK, "only owned preservation fixture directory removed")


func _test_defaults_and_presets() -> void:
	var preferences := PlayerPreferences.new()
	equal(preferences.movement_reference, PlayerPreferences.MOVEMENT_WORLD_RELATIVE, "world-relative movement is the safe default")
	equal(preferences.pov_mode, PlayerPreferences.POV_FULL, "full view is the safe default")
	equal(preferences.pov_angle_degrees, 120, "cone angle remains ready when cone view is selected")
	equal(preferences.pov_range, 720, "cone range remains ready when cone view is selected")
	equal(preferences.camera_zoom_percent, 75, "the default camera exposes more connected movement space")
	equal(PlayerPreferences.SCHEMA_VERSION, 11, "player preferences save schema v11")
	equal(preferences.keyboard_bindings[&"evade"], KEY_B, "B is the default evade key")
	equal(preferences.keyboard_bindings[&"technique"], KEY_V, "V keeps Technique distinct from evade")
	equal(preferences.to_dictionary().get("keyboard_defaults_revision"), 2, "fresh defaults record the additive keyboard revision")
	equal(preferences.to_dictionary().get("mouse_defaults_revision"), 1, "fresh defaults record the additive mouse revision")
	equal(preferences.farflow_join_address, "127.0.0.1", "local Farflow is the safe address default")
	equal(preferences.keyboard_bindings[&"sprint"], KEY_SHIFT, "Shift is the production-default sprint key")
	equal(preferences.keyboard_bindings[&"slide"], KEY_C, "C is the persisted slide key")
	equal(preferences.keyboard_bindings[&"jump"], KEY_SPACE, "Space is the production-default jump key")
	equal(preferences.keyboard_bindings[&"primary"], 0, "primary has no default keyboard alias")
	equal(preferences.keyboard_bindings[&"punch"], 0, "Punch has no default keyboard alias")
	equal(preferences.keyboard_bindings[&"kick"], 0, "Kick has no default keyboard alias")
	equal(preferences.keyboard_bindings[&"interact"], KEY_F, "interact participates in conflict-safe persistence")
	for button_index: int in range(PlayerState.SPELL_BUTTON_COUNT):
		equal(preferences.keyboard_bindings[StringName("spell_%d" % (button_index + 1))], KEY_1 + button_index, "spell button %d defaults to its number key" % (button_index + 1))
	equal(preferences.keyboard_bindings[&"spell_layer_ctrl"], KEY_CTRL, "Ctrl defaults to the middle four-position layer")
	equal(preferences.keyboard_bindings[&"spell_layer_alt"], KEY_ALT, "Alt defaults to the final four-position layer")
	equal(preferences.mouse_bindings[&"jump"], MOUSE_BUTTON_WHEEL_UP, "wheel up is the alternate jump input")
	equal(preferences.mouse_bindings[&"slide"], MOUSE_BUTTON_WHEEL_DOWN, "wheel down is the alternate slide and fast-fall input")
	equal(preferences.mouse_bindings[&"punch"], MOUSE_BUTTON_LEFT, "left mouse is dedicated to Punch")
	equal(preferences.mouse_bindings[&"kick"], MOUSE_BUTTON_RIGHT, "right mouse is dedicated to Kick")
	equal(preferences.mouse_bindings[&"primary"], 0, "Primary keeps no default mouse alias")
	equal(preferences.mouse_bindings[&"active_1"], 0, "Active one keeps E and no default mouse alias")
	equal(preferences.controller_bindings[&"punch"], PlayerPreferences.unbound_controller_binding(), "Punch is deliberately unbound on controller")
	equal(preferences.controller_bindings[&"kick"], PlayerPreferences.unbound_controller_binding(), "Kick is deliberately unbound on controller")
	equal(PlayerPreferences.validate_keyboard_bindings(preferences.keyboard_bindings), "", "S4 keyboard defaults are conflict-free")
	equal(PlayerPreferences.validate_mouse_bindings(preferences.mouse_bindings), "", "S4 mouse defaults are conflict-free")
	equal(String((preferences.controller_bindings[&"jump"] as Dictionary).get("kind")), "button", "controller jump defaults to a button")
	check(not preferences.reduced_motion, "reduced motion defaults off")
	check(not preferences.high_contrast, "high contrast defaults off")
	check(preferences.apply_control_preset(PlayerPreferences.MOVEMENT_AIM_RELATIVE), "aim-relative preset is accepted")
	equal(preferences.movement_reference, PlayerPreferences.MOVEMENT_AIM_RELATIVE, "aim-relative preset applies")
	check(preferences.apply_control_preset(PlayerPreferences.MOVEMENT_WORLD_RELATIVE), "world-relative preset is accepted")
	check(not preferences.apply_control_preset("camera_relative"), "unknown movement preset fails closed")


func _test_controller_spell_default_candidate() -> void:
	var preferences := PlayerPreferences.new()
	var expected: Dictionary = {
		&"punch": PlayerPreferences.unbound_controller_binding(),
		&"kick": PlayerPreferences.unbound_controller_binding(),
		&"evade": {"kind": "axis", "index": JOY_AXIS_TRIGGER_LEFT, "direction": 1},
		&"sprint": {"kind": "button", "index": JOY_BUTTON_LEFT_STICK, "direction": 0},
		&"jump": {"kind": "button", "index": JOY_BUTTON_A, "direction": 0},
		&"slide": {"kind": "button", "index": JOY_BUTTON_B, "direction": 0},
		&"technique": {"kind": "button", "index": JOY_BUTTON_X, "direction": 0},
		&"primary": {"kind": "axis", "index": JOY_AXIS_TRIGGER_RIGHT, "direction": 1},
		&"active_1": {"kind": "button", "index": JOY_BUTTON_Y, "direction": 0},
		&"interact": {"kind": "button", "index": JOY_BUTTON_RIGHT_STICK, "direction": 0},
		&"emote": {"kind": "button", "index": JOY_BUTTON_START, "direction": 0},
		&"spell_1": {"kind": "button", "index": JOY_BUTTON_DPAD_UP, "direction": 0},
		&"spell_2": {"kind": "button", "index": JOY_BUTTON_DPAD_RIGHT, "direction": 0},
		&"spell_3": {"kind": "button", "index": JOY_BUTTON_DPAD_DOWN, "direction": 0},
		&"spell_4": {"kind": "button", "index": JOY_BUTTON_DPAD_LEFT, "direction": 0},
		&"spell_layer_ctrl": {"kind": "button", "index": JOY_BUTTON_LEFT_SHOULDER, "direction": 0},
		&"spell_layer_alt": {"kind": "button", "index": JOY_BUTTON_RIGHT_SHOULDER, "direction": 0},
	}
	for action: StringName in expected:
		equal(preferences.controller_bindings[action], expected[action], "controller default maps %s to the authorized direct-access layout" % action)
	equal(preferences.to_dictionary().get("controller_defaults_revision"), 1, "fresh controller defaults record the additive layout revision")
	equal(PlayerPreferences.validate_controller_bindings(preferences.controller_bindings), "", "authorized controller defaults are conflict-free")


func _test_controller_default_revision() -> void:
	var historical: Dictionary = PlayerPreferences.SCHEMA_V11_DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	var untouched := _base_preferences(11, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)
	untouched["controller_bindings"] = historical.duplicate(true)
	var migrated := PlayerPreferences.new()
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(untouched))), "complete historical controller defaults migrate through their JSON shape")
	equal(migrated.controller_bindings, PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS, "untouched historical controller defaults gain all twelve spell positions")
	equal(migrated.to_dictionary().get("controller_defaults_revision"), 1, "migrated controller defaults persist the current additive revision")
	var no_controller := _base_preferences(3, PlayerPreferences.SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS)
	check(migrated.apply_dictionary(no_controller), "profile predating controller customization still loads")
	equal(migrated.controller_bindings, PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS, "profile without a controller object gains complete current defaults")

	var custom_unbind: Dictionary = historical.duplicate(true)
	custom_unbind[&"jump"] = PlayerPreferences.unbound_controller_binding()
	var custom_profile := _base_preferences(11, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)
	custom_profile["controller_bindings"] = custom_unbind
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(custom_profile))), "historical profile with an explicit unbind loads")
	equal(migrated.controller_bindings, _with_s4_unbound_controller(custom_unbind), "one explicit unbind preserves the complete historical controller layout and adds melee unbound")
	var custom_spell: Dictionary = historical.duplicate(true)
	custom_spell[&"spell_1"] = {"kind": "button", "index": JOY_BUTTON_DPAD_DOWN, "direction": 0}
	custom_profile["controller_bindings"] = custom_spell
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(custom_profile))), "historical profile with a custom spell input loads")
	equal(migrated.controller_bindings, _with_s4_unbound_controller(custom_spell), "one custom input prevents wholesale default migration and adds melee unbound")

	var partial_profile := _base_preferences(11, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)
	partial_profile["controller_bindings"] = {&"jump": historical[&"jump"]}
	check(migrated.apply_dictionary(partial_profile), "partial historical controller object loads")
	equal(migrated.controller_bindings, _with_s4_unbound_controller(historical), "partial historical object is seeded from historical defaults with new melee actions unbound")
	partial_profile["controller_bindings"] = {}
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(partial_profile))), "explicitly empty historical controller object loads")
	equal(migrated.controller_bindings, _with_s4_unbound_controller(historical), "explicitly empty map preserves historical meanings with new melee actions unbound")
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(migrated.to_dictionary()))), "normalized empty-map profile survives a JSON round trip")
	equal(migrated.controller_bindings, _with_s4_unbound_controller(historical), "empty-map preservation remains idempotent after revision is saved")
	var deliberate_old := _base_preferences(11, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)
	deliberate_old["controller_defaults_revision"] = 1
	deliberate_old["controller_bindings"] = historical.duplicate(true)
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(deliberate_old))), "current revision can deliberately retain the complete historical layout")
	equal(migrated.controller_bindings, _with_s4_unbound_controller(historical), "revision marker protects a deliberate historical layout and adds only unbound melee actions")
	var preserved_before := migrated.to_dictionary().duplicate(true)
	for invalid: Variant in [-1, 2, 0.5, NAN, INF, -INF, true, false, "1", null, [], {}]:
		var candidate := untouched.duplicate(true)
		candidate["controller_defaults_revision"] = invalid
		check(not migrated.apply_dictionary(candidate), "invalid controller revision fails closed: %s" % str(invalid))
		check(migrated.last_error.contains("controller_defaults_revision"), "invalid controller revision identifies its field")
		equal(migrated.to_dictionary(), preserved_before, "invalid controller revision cannot partially change preferences")


func _test_validation() -> void:
	var valid := {
		"schema_version": 9,
		"movement_reference": "aim_relative",
		"pov_mode": "cone",
		"pov_angle_degrees": 360,
		"pov_range": 2048,
		"camera_zoom_percent": 50,
		"reduced_motion": false,
		"high_contrast": false,
		"farflow_join_address": "friend.example.test",
	}
	var preferences := PlayerPreferences.new()
	check(preferences.apply_dictionary(valid), "valid exact settings load")
	equal(preferences.pov_angle_degrees, 360, "360-degree ranged view is legal")
	equal(preferences.pov_range, 2048, "custom view length is legal")
	equal(preferences.farflow_join_address, "friend.example.test", "valid Farflow address loads")
	for mutation: Dictionary in [
		{"schema_version": 12},
		{"movement_reference": "camera_relative"},
		{"pov_mode": "wallhack"},
		{"pov_angle_degrees": 14},
		{"pov_angle_degrees": 361},
		{"pov_angle_degrees": 90.5},
		{"pov_range": 159},
		{"pov_range": 4097},
		{"camera_zoom_percent": 49},
		{"camera_zoom_percent": 101},
		{"camera_zoom_percent": 75.5},
		{"reduced_motion": "false"},
		{"high_contrast": "false"},
		{"farflow_join_address": ""},
		{"farflow_join_address": "bad address"},
		{"farflow_join_address": "https://friend.example"},
	]:
		var candidate: Dictionary = valid.duplicate(true)
		for key: Variant in mutation:
			candidate[key] = mutation[key]
		var rejected := PlayerPreferences.new()
		check(not rejected.apply_dictionary(candidate), "invalid preference mutation fails closed: %s" % mutation)
	check(preferences.set_pov_mode(PlayerPreferences.POV_FULL), "full POV is accepted")
	check(preferences.set_pov_mode(PlayerPreferences.POV_CONE), "cone POV is accepted")
	check(not preferences.set_pov_mode("omniscient"), "unknown POV mode fails closed")
	preferences.set_pov_angle_degrees(-500)
	equal(preferences.pov_angle_degrees, PlayerPreferences.MIN_POV_ANGLE_DEGREES, "runtime angle clamps to minimum")
	preferences.set_pov_angle_degrees(500)
	equal(preferences.pov_angle_degrees, PlayerPreferences.MAX_POV_ANGLE_DEGREES, "runtime angle clamps to 360")
	preferences.set_pov_range(1)
	equal(preferences.pov_range, PlayerPreferences.MIN_POV_RANGE, "runtime range clamps to minimum")
	preferences.set_pov_range(99999)
	equal(preferences.pov_range, PlayerPreferences.MAX_POV_RANGE, "runtime range clamps to maximum")
	preferences.set_camera_zoom_percent(1)
	equal(preferences.camera_zoom_percent, PlayerPreferences.MIN_CAMERA_ZOOM_PERCENT, "runtime camera zoom clamps to its widest view")
	preferences.set_camera_zoom_percent(999)
	equal(preferences.camera_zoom_percent, PlayerPreferences.MAX_CAMERA_ZOOM_PERCENT, "runtime camera zoom clamps to its closest view")


func _base_preferences(schema_version: int, bindings: Dictionary) -> Dictionary:
	var result := {
		"schema_version": schema_version,
		"movement_reference": PlayerPreferences.MOVEMENT_WORLD_RELATIVE,
		"pov_mode": PlayerPreferences.POV_FULL,
		"pov_angle_degrees": PlayerPreferences.DEFAULT_POV_ANGLE_DEGREES,
		"pov_range": PlayerPreferences.DEFAULT_POV_RANGE,
		"keyboard_bindings": bindings,
	}
	if schema_version >= 7:
		result["camera_zoom_percent"] = PlayerPreferences.DEFAULT_CAMERA_ZOOM_PERCENT
	if schema_version >= 8:
		result["high_contrast"] = false
	if schema_version >= 9:
		result["farflow_join_address"] = PlayerPreferences.DEFAULT_FARFLOW_JOIN_ADDRESS
	return result


func _test_schema_v1_migration_and_reduced_motion() -> void:
	var legacy_defaults: Dictionary = PlayerPreferences.LEGACY_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	var migrated := PlayerPreferences.new()
	check(migrated.apply_dictionary(_base_preferences(1, legacy_defaults)), "schema-v1 defaults migrate")
	equal(migrated.keyboard_bindings[&"jump"], KEY_SPACE, "schema-v1 default C migrates to Space jump")
	equal(migrated.keyboard_bindings[&"primary"], 0, "schema-v1 default Space primary alias is removed")
	equal(migrated.keyboard_bindings[&"sprint"], KEY_SHIFT, "schema-v1 Alt sprint migrates to Shift")
	equal(migrated.keyboard_bindings[&"slide"], KEY_C, "schema-v1 gains the C slide action")
	equal(migrated.keyboard_bindings[&"interact"], KEY_F, "schema-v1 gains conflict-safe interact binding")
	check(not migrated.reduced_motion, "schema-v1 reduced_motion defaults false")
	var schema_two := PlayerPreferences.new()
	check(schema_two.apply_dictionary(_base_preferences(2, PlayerPreferences.SCHEMA_V2_DEFAULT_KEYBOARD_BINDINGS)), "schema-v2 defaults migrate")
	equal(schema_two.keyboard_bindings[&"sprint"], KEY_SHIFT, "schema-v2 Alt sprint migrates to Shift")
	equal(schema_two.keyboard_bindings[&"slide"], KEY_C, "schema-v2 gains the C slide action")
	var schema_three := PlayerPreferences.new()
	check(schema_three.apply_dictionary(_base_preferences(3, PlayerPreferences.SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS)), "schema-v3 defaults migrate")
	equal(schema_three.keyboard_bindings[&"slide"], KEY_C, "schema-v3 Ctrl slide migrates to C")
	equal(schema_three.mouse_bindings, PlayerPreferences.DEFAULT_MOUSE_BINDINGS, "schema-v3 gains safe mouse and wheel defaults")
	var schema_four_data := _base_preferences(4, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)
	schema_four_data["mouse_bindings"] = PlayerPreferences.SCHEMA_V4_DEFAULT_MOUSE_BINDINGS
	var schema_four := PlayerPreferences.new()
	check(schema_four.apply_dictionary(schema_four_data), "schema-v4 mouse defaults migrate")
	equal(schema_four.mouse_bindings[&"jump"], MOUSE_BUTTON_WHEEL_UP, "schema-v4 retains wheel-up jump")
	equal(schema_four.controller_bindings, PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS, "schema-v4 gains safe controller defaults")
	var schema_five_data := _base_preferences(5, {
		&"jump": KEY_SPACE,
		&"slide": KEY_C,
	})
	var schema_five := PlayerPreferences.new()
	check(schema_five.apply_dictionary(schema_five_data), "schema-v5 bindings migrate")
	equal(schema_five.keyboard_bindings[&"spell_1"], KEY_1, "schema-v5 gains spell button 1")
	equal(schema_five.keyboard_bindings[&"spell_layer_ctrl"], KEY_CTRL, "schema-v5 gains the Ctrl weave layer")
	equal(schema_five.camera_zoom_percent, PlayerPreferences.DEFAULT_CAMERA_ZOOM_PERCENT, "schema-v5 gains the wider camera default")
	var schema_six := PlayerPreferences.new()
	check(schema_six.apply_dictionary(_base_preferences(6, {&"spell_1": KEY_CTRL, &"spell_5": KEY_5})), "schema-v6 spell bindings migrate")
	equal(schema_six.keyboard_bindings[&"spell_1"], KEY_CTRL, "schema-v6 custom Ctrl binding is preserved")
	equal(schema_six.keyboard_bindings[&"spell_layer_ctrl"], 0, "new Ctrl layer stays unbound when a legacy action already owns Ctrl")
	check(not schema_six.keyboard_bindings.has(&"spell_5"), "retired fifth physical button is removed during migration")

	var explicit: Dictionary = legacy_defaults.duplicate()
	explicit[&"jump"] = KEY_J
	explicit[&"primary"] = KEY_P
	var preserved := PlayerPreferences.new()
	check(preserved.apply_dictionary(_base_preferences(1, explicit)), "schema-v1 explicit bindings migrate")
	equal(preserved.keyboard_bindings[&"jump"], KEY_J, "explicit jump override is preserved")
	equal(preserved.keyboard_bindings[&"primary"], KEY_P, "explicit primary override is preserved")

	var current: Dictionary = migrated.to_dictionary()
	current["reduced_motion"] = true
	var loaded := PlayerPreferences.new()
	check(loaded.apply_dictionary(current), "schema-v9 preferences load")
	check(loaded.reduced_motion, "schema-v9 reduced_motion loads")
	check(not loaded.high_contrast, "schema-v9 high contrast defaults off")
	current["high_contrast"] = true
	check(loaded.apply_dictionary(current), "schema-v9 high contrast loads")
	check(loaded.high_contrast, "schema-v9 high contrast is retained")
	var before: Dictionary = loaded.to_dictionary().duplicate(true)
	var malformed: Dictionary = current.duplicate(true)
	malformed["reduced_motion"] = "false"
	check(not loaded.apply_dictionary(malformed), "non-boolean reduced_motion fails closed")
	equal(loaded.to_dictionary(), before, "invalid reduced_motion never partially mutates preferences")
	malformed = current.duplicate(true)
	malformed["high_contrast"] = "true"
	check(not loaded.apply_dictionary(malformed), "non-boolean high_contrast fails closed")
	equal(loaded.to_dictionary(), before, "invalid high_contrast never partially mutates preferences")
	var schema_seven := PlayerPreferences.new()
	check(schema_seven.apply_dictionary(_base_preferences(7, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)), "schema-v7 preferences migrate")
	check(not schema_seven.high_contrast, "schema-v7 migration gains safe standard contrast")
	var schema_eight := PlayerPreferences.new()
	check(schema_eight.apply_dictionary(_base_preferences(8, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)), "schema-v8 preferences migrate")
	equal(schema_eight.farflow_join_address, PlayerPreferences.DEFAULT_FARFLOW_JOIN_ADDRESS, "schema-v8 gains the local Farflow address default")


func _test_persistence_round_trip() -> void:
	var path := "user://flux2_player_preferences_test.json"
	var saved := PlayerPreferences.new()
	check(saved.apply_control_preset(PlayerPreferences.MOVEMENT_AIM_RELATIVE), "round-trip control preset applies")
	check(saved.set_pov_mode(PlayerPreferences.POV_CONE), "round-trip POV mode applies")
	saved.set_pov_angle_degrees(225)
	saved.set_pov_range(1360)
	saved.set_camera_zoom_percent(50)
	saved.reduced_motion = true
	saved.high_contrast = true
	saved.sound_volume_percent = 70
	saved.farflow_join_address = "192.0.2.44"
	check(saved.save_to_file(path), "preferences save offline")
	var loaded := PlayerPreferences.new()
	check(loaded.load_from_file(path), "preferences load offline")
	equal(loaded.to_dictionary(), saved.to_dictionary(), "saved preferences round-trip exactly")
	var absolute_path: String = ProjectSettings.globalize_path(path)
	check(DirAccess.remove_absolute(absolute_path) == OK, "preference test file is cleaned")


func _test_optional_sound_volume() -> void:
	var defaults := PlayerPreferences.new()
	equal(defaults.sound_volume_percent, 30, "new preference profiles use conservative sound gain")
	equal(defaults.to_dictionary().get("sound_volume_percent"), 30, "sound volume is persisted as an optional scalar")
	equal(PlayerPreferences.SCHEMA_VERSION, 11, "additive audio does not strand older schema11 control profiles")
	defaults.sound_volume_percent = 0
	defaults.reset_to_defaults()
	equal(defaults.sound_volume_percent, 30, "reset restores safe gain instead of retaining mute or full gain")
	for schema: int in range(1, 12):
		var old_profile := _base_preferences(schema, {&"jump": KEY_J, &"primary": KEY_P})
		var migrated := PlayerPreferences.new()
		migrated.sound_volume_percent = 100
		check(migrated.apply_dictionary(old_profile), "schema%d without audio field still loads" % schema)
		equal(migrated.sound_volume_percent, 30, "schema%d missing field gets the safe default, not stale previous volume" % schema)
		equal(migrated.keyboard_bindings[&"jump"], KEY_J, "audio migration preserves custom jump for schema%d" % schema)
		equal(migrated.keyboard_bindings[&"primary"], KEY_P, "audio migration preserves custom primary for schema%d" % schema)
		var muted := old_profile.duplicate(true)
		muted["sound_volume_percent"] = 0
		check(migrated.apply_dictionary(muted), "schema%d accepts an explicit additive mute field" % schema)
		equal(migrated.sound_volume_percent, 0, "schema%d explicit zero is not mistaken for an absent setting" % schema)
	var custom := PlayerPreferences.new()
	custom.keyboard_bindings[&"jump"] = KEY_J
	custom.mouse_bindings[&"jump"] = MOUSE_BUTTON_MIDDLE
	custom.controller_bindings[&"jump"] = {"kind": "button", "index": JOY_BUTTON_GUIDE, "direction": 0}
	custom.reduced_motion = true
	custom.high_contrast = true
	custom.sound_volume_percent = 70
	custom.farflow_join_address = "192.0.2.55"
	var valid := custom.to_dictionary().duplicate(true)
	var loaded := PlayerPreferences.new()
	check(loaded.apply_dictionary(valid), "custom keyboard/mouse/controller profile accepts sound setting")
	for volume: Variant in [0, 1, 30, 99, 100, 0.0, 30.0, 100.0]:
		var candidate := valid.duplicate(true)
		candidate["sound_volume_percent"] = volume
		check(loaded.apply_dictionary(candidate), "whole numeric gain is accepted: %s" % volume)
		equal(loaded.sound_volume_percent, int(volume), "accepted numeric gain retains its exact value")
		equal(loaded.keyboard_bindings, custom.keyboard_bindings, "audio setting does not change custom keyboard controls")
		equal(loaded.mouse_bindings, custom.mouse_bindings, "audio setting does not change custom mouse controls")
		equal(loaded.controller_bindings, custom.controller_bindings, "audio setting does not change custom controller controls")
	check(loaded.apply_dictionary(valid), "atomic rejection fixture restores its complete original state")
	var before := loaded.to_dictionary().duplicate(true)
	for invalid: Variant in [-1, 101, 30.5, -0.5, NAN, INF, -INF, "30", "false", true, false, null, [], {}]:
		var candidate := valid.duplicate(true)
		candidate["movement_reference"] = PlayerPreferences.MOVEMENT_AIM_RELATIVE
		candidate["keyboard_bindings"][&"jump"] = KEY_K
		candidate["sound_volume_percent"] = invalid
		check(not loaded.apply_dictionary(candidate), "invalid sound scalar fails closed: %s" % str(invalid))
		equal(loaded.to_dictionary(), before, "invalid audio never partially mutates any existing preference")
		check(loaded.last_error.contains("sound_volume_percent"), "invalid audio reports its own field")
	var late_failure := valid.duplicate(true)
	late_failure["sound_volume_percent"] = 100
	late_failure["controller_bindings"][&"jump"] = {"kind": "axis", "index": 99, "direction": 1}
	check(not loaded.apply_dictionary(late_failure), "later binding validation can reject an otherwise valid sound value")
	equal(loaded.to_dictionary(), before, "later validation does not commit sound early")
	var old_reader_shape := valid.duplicate(true)
	old_reader_shape.erase("sound_volume_percent")
	var compatible := PlayerPreferences.new()
	check(compatible.apply_dictionary(old_reader_shape), "schema11 document remains valid when the additive audio field is ignored")
	equal(compatible.keyboard_bindings, custom.keyboard_bindings, "ignoring the new field retains keyboard customization")
	equal(compatible.mouse_bindings, custom.mouse_bindings, "ignoring the new field retains mouse customization")
	equal(compatible.controller_bindings, custom.controller_bindings, "ignoring the new field retains controller customization")
	# This checks the on-disk schema shape, not execution of an uninstalled older binary.
	var json_round_trip: Dictionary = JSON.parse_string(JSON.stringify(valid))
	check(compatible.apply_dictionary(json_round_trip), "JSON float decoding accepts whole-number persisted volume")
	equal(compatible.to_dictionary(), valid, "audio and all customized controls round-trip without loss")


func _test_evade_default_swap_migration() -> void:
	var old_defaults := PlayerPreferences.default_keyboard_bindings_for_schema(10)
	equal(old_defaults[&"evade"], KEY_Q, "migration remembers the old evade key exactly")
	equal(old_defaults[&"technique"], KEY_V, "migration remembers the old technique key exactly")
	var migrated := PlayerPreferences.new()
	check(migrated.apply_dictionary(_base_preferences(10, old_defaults)), "complete old keyboard default profile migrates")
	equal(migrated.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "default-profile migration moves Evade from Q to B and keeps Technique on V")
	for mutation: Dictionary in [{&"jump": KEY_J}, {&"evade": 0}, {&"technique": KEY_G}, {&"evade": KEY_G}]:
		var custom := old_defaults.duplicate()
		custom.merge(mutation, true)
		var preserved := PlayerPreferences.new()
		check(preserved.apply_dictionary(_base_preferences(10, custom)), "custom old keyboard profile remains valid")
		var expected_custom := _with_s4_unbound_keyboard(custom)
		equal(preserved.keyboard_bindings, expected_custom, "even one custom key or unbind preserves all previous meanings and leaves melee unbound")
		var reloaded := PlayerPreferences.new()
		check(reloaded.apply_dictionary(preserved.to_dictionary()), "custom migrated profile round-trips as schema11")
		equal(reloaded.keyboard_bindings, expected_custom, "later loads do not reapply the default migration to custom controls")
	var legacy_custom := _base_preferences(9, {&"technique": KEY_Q})
	var legacy := PlayerPreferences.new()
	check(legacy.apply_dictionary(legacy_custom), "older custom Q still migrates without a conflicting added evade")
	equal(legacy.keyboard_bindings[&"technique"], KEY_Q, "older custom Q belongs to its original action")
	equal(legacy.keyboard_bindings[&"evade"], 0, "migration never steals Q from an older custom action")
	equal(PlayerPreferences.validate_keyboard_bindings(migrated.keyboard_bindings), "", "new defaults have no duplicate key triggers")


func _test_keyboard_default_revision() -> void:
	var old_v11 := PlayerPreferences.SCHEMA_V11_DEFAULT_KEYBOARD_BINDINGS
	equal(PlayerPreferences.default_keyboard_bindings_for_schema(11), old_v11, "schema11 historical default is frozen independently of current defaults")
	equal(old_v11[&"technique"], KEY_Q, "historical schema11 Technique remains Q")
	equal(old_v11[&"evade"], KEY_V, "historical schema11 Evade remains V")
	for revision: Variant in [0, 0.0]:
		var old_json: Dictionary = JSON.parse_string(JSON.stringify(_base_preferences(11, old_v11)))
		old_json["keyboard_defaults_revision"] = revision
		var decoded := PlayerPreferences.new()
		check(decoded.apply_dictionary(old_json), "explicit revision zero accepts JSON-decoded complete old default keycodes")
		equal(decoded.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "whole-number JSON values retain exact default-layout migration eligibility")
	var custom_devices := _base_preferences(11, old_v11)
	custom_devices["mouse_bindings"] = PlayerPreferences.DEFAULT_MOUSE_BINDINGS.duplicate()
	custom_devices["mouse_bindings"][&"technique"] = MOUSE_BUTTON_MIDDLE
	custom_devices["controller_bindings"] = PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	custom_devices["controller_bindings"][&"technique"] = {"kind": "button", "index": JOY_BUTTON_GUIDE, "direction": 0}
	var migrated_devices := PlayerPreferences.new()
	check(migrated_devices.apply_dictionary(custom_devices), "untouched keyboard default migrates alongside custom device layouts")
	equal(migrated_devices.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "mouse/controller customization does not prevent the keyboard-only default swap")
	equal(migrated_devices.mouse_bindings, custom_devices["mouse_bindings"], "keyboard-only swap preserves every custom mouse binding")
	equal(migrated_devices.controller_bindings, custom_devices["controller_bindings"], "keyboard-only swap preserves every custom controller binding")
	for schema: int in range(1, 12):
		var historical: Dictionary = PlayerPreferences.default_keyboard_bindings_for_schema(schema)
		if schema == 1:
			historical = PlayerPreferences.LEGACY_DEFAULT_KEYBOARD_BINDINGS.duplicate()
		elif schema == 2:
			historical = PlayerPreferences.SCHEMA_V2_DEFAULT_KEYBOARD_BINDINGS.duplicate()
		elif schema == 3:
			historical = PlayerPreferences.SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS.duplicate()
		var loaded := PlayerPreferences.new()
		check(loaded.apply_dictionary(_base_preferences(schema, historical)), "schema%d full historical defaults load" % schema)
		equal(loaded.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "schema%d untouched defaults reach exact Technique V / Evade B" % schema)
		var current := loaded.to_dictionary().duplicate(true)
		equal(current.get("schema_version"), 11, "migration keeps older schema11 readers compatible")
		equal(current.get("keyboard_defaults_revision"), 2, "every accepted legacy profile persists current layout revision")
		for round_trip: int in range(3):
			check(loaded.apply_dictionary(JSON.parse_string(JSON.stringify(current))), "schema%d JSON reload %d succeeds" % [schema, round_trip])
			equal(loaded.to_dictionary(), current, "migration is idempotent through JSON numeric decoding")
		# Existing readers ignore unknown fields and write their known schema11
		# shape. This checks that shape, not execution of an older binary.
		var old_reader_shape := current.duplicate(true)
		old_reader_shape.erase("keyboard_defaults_revision")
		check(loaded.apply_dictionary(old_reader_shape), "old-reader re-save without additive marker still loads")
		equal(loaded.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "an old-reader re-save cannot oscillate the explicit current B/V default")
		var custom := historical.duplicate()
		custom[&"jump"] = KEY_J
		custom[&"primary"] = KEY_P
		custom[&"technique"] = KEY_G
		custom[&"evade"] = 0
		var customized := _base_preferences(schema, custom)
		var mouse := PlayerPreferences.DEFAULT_MOUSE_BINDINGS.duplicate()
		mouse[&"jump"] = MOUSE_BUTTON_MIDDLE
		var controller := PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
		controller[&"technique"] = {"kind": "button", "index": JOY_BUTTON_GUIDE, "direction": 0}
		customized["mouse_bindings"] = mouse
		customized["controller_bindings"] = controller
		check(loaded.apply_dictionary(customized), "schema%d custom controls on every device load" % schema)
		for action: StringName in [&"jump", &"primary", &"technique", &"evade"]:
			equal(loaded.keyboard_bindings[action], custom[action], "schema%d keeps explicit %s ownership or unbind" % [schema, action])
		equal(loaded.mouse_bindings, mouse, "keyboard revision leaves custom mouse layout unchanged")
		equal(loaded.controller_bindings, controller, "keyboard revision leaves custom controller layout unchanged")
		var custom_round_trip := loaded.to_dictionary().duplicate(true)
		check(loaded.apply_dictionary(JSON.parse_string(JSON.stringify(custom_round_trip))), "custom controls serialize and reload")
		equal(loaded.to_dictionary(), custom_round_trip, "all customized settings survive an exact JSON round-trip")
		var omitted := _base_preferences(schema, {})
		omitted.erase("keyboard_bindings")
		check(loaded.apply_dictionary(omitted), "schema%d still accepts an omitted optional keyboard object" % schema)
		equal(loaded.keyboard_bindings, _with_s4_unbound_keyboard(old_v11) if schema == 11 else PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "omitted keyboard data is not proof of a complete old v11 default profile")
	# Every unrelated customization or explicit unbind prevents the old-pair swap.
	for action: StringName in old_v11:
		for keycode: int in [KEY_G, 0]:
			if old_v11[action] == keycode:
				continue
			var custom := old_v11.duplicate()
			custom[action] = keycode
			var preserved := PlayerPreferences.new()
			check(preserved.apply_dictionary(_base_preferences(11, custom)), "old v11 single custom %s=%d loads" % [action, keycode])
			equal(preserved.keyboard_bindings, _with_s4_unbound_keyboard(custom), "one customization protects the entire prior keyboard layout and leaves melee unbound")
	for removed_action: StringName in old_v11:
		var partial := old_v11.duplicate()
		partial.erase(removed_action)
		var preserved := PlayerPreferences.new()
		check(preserved.apply_dictionary(_base_preferences(11, partial)), "partial v11 map loads with historical missing-key defaults")
		equal(preserved.keyboard_bindings, _with_s4_unbound_keyboard(old_v11), "a missing %s is not silently promoted to proof of untouched full defaults" % removed_action)
		check(preserved.apply_dictionary(preserved.to_dictionary()), "revision protects a normalized partial map on the next load")
		equal(preserved.keyboard_bindings, _with_s4_unbound_keyboard(old_v11), "normalized partial map never acquires a delayed migration")
	var explicit_old := _base_preferences(11, old_v11)
	explicit_old["keyboard_defaults_revision"] = 2
	var explicit := PlayerPreferences.new()
	check(explicit.apply_dictionary(explicit_old), "current-revision user may deliberately retain the exact old layout")
	equal(explicit.keyboard_bindings, _with_s4_unbound_keyboard(old_v11), "revisioned explicit old defaults are genuine user controls with melee unbound")
	check(explicit.apply_dictionary(JSON.parse_string(JSON.stringify(explicit.to_dictionary()))), "deliberate old layout round-trips")
	equal(explicit.keyboard_bindings, _with_s4_unbound_keyboard(old_v11), "current builds never reinterpret a deliberate old layout")
	# Downgrade limitation: an old reader discarding the marker also discards
	# evidence that this exact old-default map was deliberately selected.
	var downgraded_old := explicit.to_dictionary().duplicate(true)
	downgraded_old.erase("keyboard_defaults_revision")
	var upgraded_again := PlayerPreferences.new()
	check(upgraded_again.apply_dictionary(downgraded_old), "downgraded exact old-default profile is still loadable")
	equal(upgraded_again.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "marker stripping leaves exact historical defaults plus zeroed new actions recognizable and cannot oscillate the new layout")
	var normalized_custom := _with_s4_unbound_keyboard(old_v11)
	normalized_custom[&"evade"] = 0
	var preserved_unbind := PlayerPreferences.new()
	check(preserved_unbind.apply_dictionary(_base_preferences(11, normalized_custom)), "markerless normalized profile with an explicit historical unbind loads")
	equal(preserved_unbind.keyboard_bindings, normalized_custom, "one explicit historical unbind still prevents default migration")
	var normalized_punch_custom := _with_s4_unbound_keyboard(old_v11)
	normalized_punch_custom[&"punch"] = KEY_Z
	var preserved_punch := PlayerPreferences.new()
	check(preserved_punch.apply_dictionary(_base_preferences(11, normalized_punch_custom)), "markerless normalized profile with a deliberate Punch key loads")
	equal(preserved_punch.keyboard_bindings, normalized_punch_custom, "a nonzero new-action binding is custom and cannot be mistaken for normalized defaults")
	var late_failure := _base_preferences(11, old_v11)
	var before := explicit.to_dictionary().duplicate(true)
	for malformed: Dictionary in [
		{"mouse_bindings": {&"jump": MOUSE_BUTTON_LEFT}},
		{"controller_bindings": {&"jump": {"kind": "axis", "index": 99, "direction": 1}}},
	]:
		var candidate := late_failure.duplicate(true)
		candidate.merge(malformed, true)
		check(not explicit.apply_dictionary(candidate), "invalid later device validation rejects a pending keyboard migration")
		equal(explicit.to_dictionary(), before, "late validation never commits the swap or revision early")
	for invalid: Variant in [-1, 3, 0.5, NAN, INF, -INF, true, false, "1", null, [], {}]:
		var candidate := late_failure.duplicate(true)
		candidate["keyboard_defaults_revision"] = invalid
		check(not explicit.apply_dictionary(candidate), "invalid keyboard revision fails closed: %s" % str(invalid))
		check(explicit.last_error.contains("keyboard_defaults_revision"), "invalid revision identifies its field")
		equal(explicit.to_dictionary(), before, "revision validation leaves every existing setting unchanged")
	var current_partial := _base_preferences(11, {&"jump": KEY_J})
	current_partial["keyboard_defaults_revision"] = 1.0
	check(explicit.apply_dictionary(current_partial), "whole-number JSON prior revision accepts a partial profile")
	equal(explicit.keyboard_bindings[&"technique"], KEY_V, "prior revision seeds Technique V for missing fields")
	equal(explicit.keyboard_bindings[&"evade"], KEY_Q, "prior revision seeds Evade Q for missing fields")
	explicit.reset_to_defaults()
	equal(explicit.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "explicit reset uses the new default layout")
	equal(explicit.to_dictionary().get("keyboard_defaults_revision"), 2, "explicit reset persists the current layout revision")


func _test_keyboard_bindings() -> void:
	var remapped: Dictionary[StringName, int] = PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS.duplicate()
	remapped[&"jump"] = KEY_J
	equal(PlayerPreferences.validate_keyboard_bindings(remapped), "", "unique remapped keyboard bindings validate")
	var router := InputRouter.new()
	check(router.configure_keyboard_bindings(remapped), "router applies a valid keyboard remap")
	var jump_keycodes: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"jump"):
		if event is InputEventKey:
			jump_keycodes.append(event.physical_keycode)
	equal(jump_keycodes, [KEY_J], "jump keyboard default is replaced without removing controller input")
	check(_mouse_buttons(&"jump").has(MOUSE_BUTTON_WHEEL_UP), "keyboard remap retains wheel-up jump")
	var conflicting: Dictionary[StringName, int] = remapped.duplicate()
	conflicting[&"technique"] = KEY_J
	check(not PlayerPreferences.validate_keyboard_bindings(conflicting).is_empty(), "conflicting key bindings fail closed")
	var unknown: Dictionary = remapped.duplicate()
	unknown[&"developer_cheat"] = KEY_F12
	check(not PlayerPreferences.validate_keyboard_bindings(unknown).is_empty(), "unknown bindable action fails closed")
	remapped[&"jump"] = 0
	equal(PlayerPreferences.validate_keyboard_bindings(remapped), "", "zero explicitly unbinds one keyboard action")
	check(router.configure_keyboard_bindings(PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS), "test restores keyboard defaults")
	var remapped_mouse: Dictionary[StringName, int] = PlayerPreferences.DEFAULT_MOUSE_BINDINGS.duplicate()
	remapped_mouse[&"jump"] = MOUSE_BUTTON_MIDDLE
	check(router.configure_mouse_bindings(remapped_mouse), "router applies a valid mouse remap")
	equal(_mouse_buttons(&"jump"), [MOUSE_BUTTON_MIDDLE], "jump mouse binding is replaced without removing keyboard/controller input")
	var conflicting_mouse: Dictionary[StringName, int] = remapped_mouse.duplicate()
	conflicting_mouse[&"slide"] = MOUSE_BUTTON_MIDDLE
	check(not PlayerPreferences.validate_mouse_bindings(conflicting_mouse).is_empty(), "conflicting mouse bindings fail closed")
	var unknown_mouse: Dictionary = remapped_mouse.duplicate()
	unknown_mouse[&"developer_cheat"] = MOUSE_BUTTON_XBUTTON1
	check(not PlayerPreferences.validate_mouse_bindings(unknown_mouse).is_empty(), "unknown mouse action fails closed")
	remapped_mouse[&"jump"] = 0
	equal(PlayerPreferences.validate_mouse_bindings(remapped_mouse), "", "zero explicitly unbinds one mouse action")
	check(router.configure_mouse_bindings(PlayerPreferences.DEFAULT_MOUSE_BINDINGS), "test restores mouse defaults")
	var remapped_controller: Dictionary = PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	remapped_controller[&"jump"] = {"kind": "button", "index": JOY_BUTTON_GUIDE, "direction": 0}
	check(router.configure_controller_bindings(remapped_controller), "router applies a valid controller remap")
	check(_controller_buttons(&"jump").has(JOY_BUTTON_GUIDE), "jump controller binding is replaced without removing keyboard or mouse")
	var conflicting_controller: Dictionary = remapped_controller.duplicate(true)
	conflicting_controller[&"slide"] = remapped_controller[&"jump"]
	check(not PlayerPreferences.validate_controller_bindings(conflicting_controller).is_empty(), "conflicting controller bindings fail closed")
	var malformed_controller: Dictionary = remapped_controller.duplicate(true)
	malformed_controller[&"jump"] = {"kind": "axis", "index": 99, "direction": 1}
	check(not PlayerPreferences.validate_controller_bindings(malformed_controller).is_empty(), "out-of-range controller axis fails closed")
	remapped_controller[&"jump"] = PlayerPreferences.unbound_controller_binding()
	equal(PlayerPreferences.validate_controller_bindings(remapped_controller), "", "controller action can be explicitly unbound")
	check(router.configure_controller_bindings(PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS), "test restores controller defaults")


func _test_s4_control_default_migration() -> void:
	var previous_controller := PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	previous_controller.erase(&"punch")
	previous_controller.erase(&"kick")
	var old_profile := _base_preferences(11, PlayerPreferences.S4_PREVIOUS_DEFAULT_KEYBOARD_BINDINGS.duplicate())
	old_profile["keyboard_defaults_revision"] = 1
	old_profile["mouse_defaults_revision"] = 0
	old_profile["mouse_bindings"] = PlayerPreferences.S4_PREVIOUS_DEFAULT_MOUSE_BINDINGS.duplicate()
	old_profile["controller_defaults_revision"] = 1
	old_profile["controller_bindings"] = previous_controller
	var old_profile_before := old_profile.duplicate(true)
	var migrated := PlayerPreferences.new()
	check(migrated.apply_dictionary(JSON.parse_string(JSON.stringify(old_profile))), "complete pre-S4 device defaults migrate")
	equal(migrated.keyboard_bindings, PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS, "exact old keyboard defaults move Evade Q to B")
	equal(migrated.mouse_bindings, PlayerPreferences.DEFAULT_MOUSE_BINDINGS, "exact old mouse spell aliases become dedicated Punch and Kick defaults")
	for action: StringName in previous_controller:
		equal(migrated.controller_bindings[action], previous_controller[action], "S4 migration preserves controller meaning for %s" % action)
	equal(migrated.controller_bindings[&"punch"], PlayerPreferences.unbound_controller_binding(), "S4 migration adds controller Punch unbound")
	equal(migrated.controller_bindings[&"kick"], PlayerPreferences.unbound_controller_binding(), "S4 migration adds controller Kick unbound")
	var codes := _notice_codes(migrated.migration_notices)
	check(codes.has("evade_moved_q_to_b"), "exact keyboard migration reports the Evade move")
	check(codes.has("mouse_melee_defaults_applied"), "exact mouse migration reports the melee defaults")
	equal(old_profile, old_profile_before, "migration does not mutate its caller-owned profile")
	var serialized := migrated.to_dictionary()
	check(not serialized.has("migration_notices"), "migration notices are transient and never persisted")
	var reloaded := PlayerPreferences.new()
	check(reloaded.apply_dictionary(JSON.parse_string(JSON.stringify(serialized))), "migrated S4 profile reloads")
	equal(reloaded.to_dictionary(), serialized, "S4 migration is idempotent after revision markers persist")
	equal(reloaded.migration_notices.size(), 0, "current-revision reload emits no stale migration notice")


func _test_s4_custom_control_preservation_and_notices() -> void:
	var custom_keyboard := PlayerPreferences.S4_PREVIOUS_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	custom_keyboard[&"emote"] = KEY_B
	var custom_mouse := PlayerPreferences.S4_PREVIOUS_DEFAULT_MOUSE_BINDINGS.duplicate()
	custom_mouse[&"jump"] = MOUSE_BUTTON_MIDDLE
	var custom_profile := _base_preferences(11, custom_keyboard)
	custom_profile["keyboard_defaults_revision"] = 1
	custom_profile["mouse_defaults_revision"] = 0
	custom_profile["mouse_bindings"] = custom_mouse
	var preserved := PlayerPreferences.new()
	check(preserved.apply_dictionary(JSON.parse_string(JSON.stringify(custom_profile))), "custom pre-S4 keyboard and mouse maps load")
	equal(preserved.keyboard_bindings, _with_s4_unbound_keyboard(custom_keyboard), "custom keyboard meanings stay intact and new melee actions stay unbound")
	equal(preserved.mouse_bindings, _with_s4_unbound_mouse(custom_mouse), "custom mouse meanings stay intact and new melee actions stay unbound")
	equal(preserved.keyboard_bindings[&"evade"], KEY_Q, "custom Evade stays on Q")
	equal(preserved.keyboard_bindings[&"emote"], KEY_B, "custom B owner is preserved")
	equal(preserved.mouse_bindings[&"primary"], MOUSE_BUTTON_LEFT, "custom left mouse Primary is preserved")
	equal(preserved.mouse_bindings[&"active_1"], MOUSE_BUTTON_RIGHT, "custom right mouse Active remains preserved")
	var codes := _notice_codes(preserved.migration_notices)
	for expected_code: String in ["custom_keyboard_preserved", "evade_b_conflict_preserved", "custom_mouse_preserved", "mouse_binding_conflict_preserved"]:
		check(codes.has(expected_code), "custom migration reports %s" % expected_code)
	var found_b_conflict := false
	var mouse_conflicts: Dictionary[StringName, StringName] = {}
	for notice: Dictionary in preserved.migration_notices:
		if String(notice.get("code", "")) == "evade_b_conflict_preserved":
			found_b_conflict = (
				notice.get("action") == &"evade"
				and int(notice.get("requested_binding", 0)) == KEY_B
				and notice.get("conflicting_action") == &"emote"
			)
		elif String(notice.get("code", "")) == "mouse_binding_conflict_preserved":
			mouse_conflicts[StringName(str(notice.get("action", "")))] = StringName(str(notice.get("conflicting_action", "")))
	check(found_b_conflict, "keyboard conflict notice identifies Evade, B, and its preserved owner")
	equal(mouse_conflicts, {&"punch": &"primary", &"kick": &"active_1"}, "mouse notices identify both preserved spell-button conflicts")
	var preserved_before := preserved.to_dictionary().duplicate(true)
	var notices_before := preserved.migration_notices.duplicate(true)
	var invalid_late := custom_profile.duplicate(true)
	invalid_late["mouse_bindings"] = custom_mouse.duplicate()
	invalid_late["mouse_bindings"][&"punch"] = MOUSE_BUTTON_LEFT
	check(not preserved.apply_dictionary(invalid_late), "late mouse conflict rejects the whole migration")
	equal(preserved.to_dictionary(), preserved_before, "late migration failure preserves every accepted setting")
	equal(preserved.migration_notices, notices_before, "late migration failure preserves the prior transient notices")
	for invalid: Variant in [-1, 2, 0.5, true, "1", null, [], {}]:
		var invalid_revision := custom_profile.duplicate(true)
		invalid_revision["mouse_defaults_revision"] = invalid
		check(not preserved.apply_dictionary(invalid_revision), "invalid mouse revision fails closed: %s" % str(invalid))
		check(preserved.last_error.contains("mouse_defaults_revision"), "invalid mouse revision identifies its field")
		equal(preserved.to_dictionary(), preserved_before, "invalid mouse revision cannot mutate accepted settings")


func _mouse_buttons(action: StringName) -> Array[int]:
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			buttons.append(event.button_index)
	return buttons


func _controller_buttons(action: StringName) -> Array[int]:
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			buttons.append(event.button_index)
	return buttons


func _with_s4_unbound_keyboard(bindings: Dictionary) -> Dictionary:
	var result := bindings.duplicate()
	result[&"punch"] = 0
	result[&"kick"] = 0
	return result


func _with_s4_unbound_mouse(bindings: Dictionary) -> Dictionary:
	var result := bindings.duplicate()
	result[&"punch"] = 0
	result[&"kick"] = 0
	return result


func _with_s4_unbound_controller(bindings: Dictionary) -> Dictionary:
	var result := bindings.duplicate(true)
	result[&"punch"] = PlayerPreferences.unbound_controller_binding()
	result[&"kick"] = PlayerPreferences.unbound_controller_binding()
	return result


func _notice_codes(notices: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for notice: Dictionary in notices:
		result.append(String(notice.get("code", "")))
	return result


func _test_movement_transforms() -> void:
	equal(
		InputRouter.transform_movement(250, -700, 0, 1000, PlayerPreferences.MOVEMENT_WORLD_RELATIVE),
		Vector2i(250, -700),
		"world-relative movement ignores aim",
	)
	equal(
		InputRouter.transform_movement(0, -1000, 1000, 0, PlayerPreferences.MOVEMENT_AIM_RELATIVE),
		Vector2i(1000, 0),
		"aim-relative W follows a right-facing aim",
	)
	equal(
		InputRouter.transform_movement(0, -1000, 0, 1000, PlayerPreferences.MOVEMENT_AIM_RELATIVE),
		Vector2i(0, 1000),
		"aim-relative W follows a downward aim",
	)
	equal(
		InputRouter.transform_movement(1000, 0, 0, -1000, PlayerPreferences.MOVEMENT_AIM_RELATIVE),
		Vector2i(1000, 0),
		"aim-relative D strafes right from an upward aim",
	)
	equal(
		InputRouter.transform_movement(-1000, 0, 1000, 0, PlayerPreferences.MOVEMENT_AIM_RELATIVE),
		Vector2i(0, -1000),
		"aim-relative A strafes above a right-facing aim",
	)
	var router := InputRouter.new()
	check(router.configure_movement_reference(PlayerPreferences.MOVEMENT_AIM_RELATIVE), "router accepts aim-relative configuration")
	check(not router.configure_movement_reference("invalid"), "router rejects invalid movement reference")
