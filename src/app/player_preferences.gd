class_name PlayerPreferences
extends RefCounted


const SCHEMA_VERSION: int = 11
const KEYBOARD_DEFAULTS_REVISION: int = 2
const MOUSE_DEFAULTS_REVISION: int = 1
const CONTROLLER_DEFAULTS_REVISION: int = 1
const DEFAULT_PATH: String = "user://player_preferences_v1.json"
const PRE_FOUR_DELIVERY_BACKUP_SUFFIX: String = ".pre_four_delivery_a.bak"
const PRE_S4_CONTROLS_BACKUP_SUFFIX: String = ".pre_s4_controls.bak"
const DEFAULT_FARFLOW_JOIN_ADDRESS: String = "127.0.0.1"
const MOVEMENT_WORLD_RELATIVE: String = "world_relative"
const MOVEMENT_AIM_RELATIVE: String = "aim_relative"
const POV_RELATIVE: String = "relative"
# Legacy input tokens only; neither grants an alternate effective view.
const POV_FULL: String = "full"
const POV_CONE: String = "cone"
const MIN_POV_ANGLE_DEGREES: int = 15
const MAX_POV_ANGLE_DEGREES: int = 360
const MIN_POV_RANGE: int = 160
const MAX_POV_RANGE: int = 4096
const RELATIVE_SIGHT_ANGLE_DEGREES: int = 360
const RELATIVE_SIGHT_RANGE: int = 720
const DEFAULT_POV_ANGLE_DEGREES: int = RELATIVE_SIGHT_ANGLE_DEGREES
const DEFAULT_POV_RANGE: int = RELATIVE_SIGHT_RANGE
const MIN_CAMERA_ZOOM_PERCENT: int = 50
const MAX_CAMERA_ZOOM_PERCENT: int = 100
const DEFAULT_CAMERA_ZOOM_PERCENT: int = 75
const LEGACY_DEFAULT_KEYBOARD_BINDINGS: Dictionary[StringName, int] = {
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"sprint": KEY_ALT,
	&"jump": KEY_C,
	&"technique": KEY_V,
	&"primary": KEY_SPACE,
	&"active_1": KEY_E,
	&"reset_match": KEY_R,
	&"toggle_debug_overlay": KEY_F1,
	&"toggle_tick_rate": KEY_F6,
	&"toggle_movement_reference": KEY_F7,
	&"toggle_pov_mode": KEY_F8,
	&"adjust_pov_angle": KEY_F9,
	&"adjust_pov_range": KEY_F10,
}
const SCHEMA_V2_DEFAULT_KEYBOARD_BINDINGS: Dictionary[StringName, int] = {
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"sprint": KEY_ALT,
	&"jump": KEY_SPACE,
	&"technique": KEY_V,
	&"primary": 0,
	&"active_1": KEY_E,
	&"reset_match": KEY_R,
	&"toggle_debug_overlay": KEY_F1,
	&"toggle_tick_rate": KEY_F6,
	&"toggle_movement_reference": KEY_F7,
	&"toggle_pov_mode": KEY_F8,
	&"adjust_pov_angle": KEY_F9,
	&"adjust_pov_range": KEY_F10,
}
const SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS: Dictionary[StringName, int] = {
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"sprint": KEY_SHIFT,
	&"slide": KEY_CTRL,
	&"jump": KEY_SPACE,
	&"technique": KEY_V,
	&"primary": 0,
	&"active_1": KEY_E,
	&"reset_match": KEY_R,
	&"toggle_debug_overlay": KEY_F1,
	&"toggle_tick_rate": KEY_F6,
	&"toggle_movement_reference": KEY_F7,
	&"toggle_pov_mode": KEY_F8,
	&"adjust_pov_angle": KEY_F9,
	&"adjust_pov_range": KEY_F10,
}
const SCHEMA_V11_DEFAULT_KEYBOARD_BINDINGS: Dictionary[StringName, int] = {
	&"practice_trace": KEY_F2,
	&"practice_retry": KEY_F3,
	&"evade": KEY_V,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"sprint": KEY_SHIFT,
	&"slide": KEY_C,
	&"jump": KEY_SPACE,
	&"technique": KEY_Q,
	&"primary": 0,
	&"active_1": KEY_E,
	&"interact": KEY_F,
	&"emote": KEY_T,
	&"spell_1": KEY_1,
	&"spell_2": KEY_2,
	&"spell_3": KEY_3,
	&"spell_4": KEY_4,
	&"spell_layer_ctrl": KEY_CTRL,
	&"spell_layer_alt": KEY_ALT,
	&"reset_match": KEY_R,
	&"toggle_debug_overlay": KEY_F1,
	&"toggle_movement_reference": KEY_F7,
	&"toggle_pov_mode": KEY_F8,
	&"adjust_pov_angle": KEY_F9,
	&"adjust_pov_range": KEY_F10,
	&"adjust_camera_zoom": KEY_F11,
}
const S4_PREVIOUS_DEFAULT_KEYBOARD_BINDINGS: Dictionary[StringName, int] = {
	&"practice_trace": KEY_F2,
	&"practice_retry": KEY_F3,
	&"evade": KEY_Q,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"sprint": KEY_SHIFT,
	&"slide": KEY_C,
	&"jump": KEY_SPACE,
	&"technique": KEY_V,
	&"primary": 0,
	&"active_1": KEY_E,
	&"interact": KEY_F,
	&"emote": KEY_T,
	&"spell_1": KEY_1,
	&"spell_2": KEY_2,
	&"spell_3": KEY_3,
	&"spell_4": KEY_4,
	&"spell_layer_ctrl": KEY_CTRL,
	&"spell_layer_alt": KEY_ALT,
	&"reset_match": KEY_R,
	&"toggle_debug_overlay": KEY_F1,
	&"toggle_movement_reference": KEY_F7,
	&"toggle_pov_mode": KEY_F8,
	&"adjust_pov_angle": KEY_F9,
	&"adjust_pov_range": KEY_F10,
	&"adjust_camera_zoom": KEY_F11,
}
const DEFAULT_KEYBOARD_BINDINGS: Dictionary[StringName, int] = {
	&"practice_trace": KEY_F2,
	&"practice_retry": KEY_F3,
	&"evade": KEY_B,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"sprint": KEY_SHIFT,
	&"slide": KEY_C,
	&"jump": KEY_SPACE,
	&"technique": KEY_V,
	&"punch": 0,
	&"kick": 0,
	&"primary": 0,
	&"active_1": KEY_E,
	&"interact": KEY_F,
	&"emote": KEY_T,
	&"spell_1": KEY_1,
	&"spell_2": KEY_2,
	&"spell_3": KEY_3,
	&"spell_4": KEY_4,
	&"spell_layer_ctrl": KEY_CTRL,
	&"spell_layer_alt": KEY_ALT,
	&"reset_match": KEY_R,
	&"toggle_debug_overlay": KEY_F1,
	&"toggle_movement_reference": KEY_F7,
	&"toggle_pov_mode": KEY_F8,
	&"adjust_pov_angle": KEY_F9,
	&"adjust_pov_range": KEY_F10,
	&"adjust_camera_zoom": KEY_F11,
	&"aim_left": 0,
	&"aim_right": 0,
	&"aim_up": 0,
	&"aim_down": 0,
}
const SCHEMA_V4_DEFAULT_MOUSE_BINDINGS: Dictionary[StringName, int] = {
	&"primary": MOUSE_BUTTON_LEFT,
	&"active_1": MOUSE_BUTTON_RIGHT,
	&"jump": MOUSE_BUTTON_WHEEL_UP,
	&"slide": MOUSE_BUTTON_WHEEL_DOWN,
}
const S4_PREVIOUS_DEFAULT_MOUSE_BINDINGS: Dictionary[StringName, int] = {
	&"practice_trace": 0,
	&"practice_retry": 0,
	&"evade": 0,
	&"move_left": 0,
	&"move_right": 0,
	&"move_up": 0,
	&"move_down": 0,
	&"sprint": 0,
	&"slide": MOUSE_BUTTON_WHEEL_DOWN,
	&"jump": MOUSE_BUTTON_WHEEL_UP,
	&"technique": 0,
	&"primary": MOUSE_BUTTON_LEFT,
	&"active_1": MOUSE_BUTTON_RIGHT,
	&"interact": 0,
	&"emote": 0,
	&"spell_1": 0,
	&"spell_2": 0,
	&"spell_3": 0,
	&"spell_4": 0,
	&"spell_layer_ctrl": 0,
	&"spell_layer_alt": 0,
}
const DEFAULT_MOUSE_BINDINGS: Dictionary[StringName, int] = {
	&"practice_trace": 0,
	&"practice_retry": 0,
	&"evade": 0,
	&"move_left": 0,
	&"move_right": 0,
	&"move_up": 0,
	&"move_down": 0,
	&"sprint": 0,
	&"slide": MOUSE_BUTTON_WHEEL_DOWN,
	&"jump": MOUSE_BUTTON_WHEEL_UP,
	&"technique": 0,
	&"punch": MOUSE_BUTTON_LEFT,
	&"kick": MOUSE_BUTTON_RIGHT,
	&"primary": 0,
	&"active_1": 0,
	&"interact": 0,
	&"emote": 0,
	&"spell_1": 0,
	&"spell_2": 0,
	&"spell_3": 0,
	&"spell_4": 0,
	&"spell_layer_ctrl": 0,
	&"spell_layer_alt": 0,
	&"aim_left": 0, &"aim_right": 0, &"aim_up": 0, &"aim_down": 0,
}
const SCHEMA_V11_DEFAULT_CONTROLLER_BINDINGS: Dictionary = {
	&"practice_trace": {"kind": "none", "index": -1, "direction": 0},
	&"practice_retry": {"kind": "none", "index": -1, "direction": 0},
	&"evade": {"kind": "axis", "index": JOY_AXIS_TRIGGER_LEFT, "direction": 1},
	&"move_left": {"kind": "axis", "index": JOY_AXIS_LEFT_X, "direction": -1},
	&"move_right": {"kind": "axis", "index": JOY_AXIS_LEFT_X, "direction": 1},
	&"move_up": {"kind": "axis", "index": JOY_AXIS_LEFT_Y, "direction": -1},
	&"move_down": {"kind": "axis", "index": JOY_AXIS_LEFT_Y, "direction": 1},
	&"sprint": {"kind": "button", "index": JOY_BUTTON_LEFT_SHOULDER, "direction": 0},
	&"slide": {"kind": "button", "index": JOY_BUTTON_A, "direction": 0},
	&"jump": {"kind": "button", "index": JOY_BUTTON_RIGHT_SHOULDER, "direction": 0},
	&"technique": {"kind": "button", "index": JOY_BUTTON_B, "direction": 0},
	&"primary": {"kind": "axis", "index": JOY_AXIS_TRIGGER_RIGHT, "direction": 1},
	&"active_1": {"kind": "button", "index": JOY_BUTTON_X, "direction": 0},
	&"interact": {"kind": "button", "index": JOY_BUTTON_Y, "direction": 0},
	&"emote": {"kind": "button", "index": JOY_BUTTON_DPAD_UP, "direction": 0},
	&"spell_1": {"kind": "none", "index": -1, "direction": 0},
	&"spell_2": {"kind": "none", "index": -1, "direction": 0},
	&"spell_3": {"kind": "none", "index": -1, "direction": 0},
	&"spell_4": {"kind": "none", "index": -1, "direction": 0},
	&"spell_layer_ctrl": {"kind": "none", "index": -1, "direction": 0},
	&"spell_layer_alt": {"kind": "none", "index": -1, "direction": 0},
}
const DEFAULT_CONTROLLER_BINDINGS: Dictionary = {
	&"practice_trace": {"kind": "none", "index": -1, "direction": 0},
	&"practice_retry": {"kind": "none", "index": -1, "direction": 0},
	&"punch": {"kind": "none", "index": -1, "direction": 0},
	&"kick": {"kind": "none", "index": -1, "direction": 0},
	&"evade": {"kind": "axis", "index": JOY_AXIS_TRIGGER_LEFT, "direction": 1},
	&"move_left": {"kind": "axis", "index": JOY_AXIS_LEFT_X, "direction": -1},
	&"move_right": {"kind": "axis", "index": JOY_AXIS_LEFT_X, "direction": 1},
	&"move_up": {"kind": "axis", "index": JOY_AXIS_LEFT_Y, "direction": -1},
	&"move_down": {"kind": "axis", "index": JOY_AXIS_LEFT_Y, "direction": 1},
	&"sprint": {"kind": "button", "index": JOY_BUTTON_LEFT_STICK, "direction": 0},
	&"slide": {"kind": "button", "index": JOY_BUTTON_B, "direction": 0},
	&"jump": {"kind": "button", "index": JOY_BUTTON_A, "direction": 0},
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
	&"aim_left": {"kind":"axis","index":JOY_AXIS_RIGHT_X,"direction":-1},
	&"aim_right": {"kind":"axis","index":JOY_AXIS_RIGHT_X,"direction":1},
	&"aim_up": {"kind":"axis","index":JOY_AXIS_RIGHT_Y,"direction":-1},
	&"aim_down": {"kind":"axis","index":JOY_AXIS_RIGHT_Y,"direction":1},
}

var movement_reference: String = MOVEMENT_WORLD_RELATIVE
# Effective sight is common to every profile. Guard direct property writes as
# well as migration/setter APIs so legacy captures cannot restore local modes.
var pov_mode: String = POV_RELATIVE:
	set(value):
		if is_valid_pov_mode(value):
			pov_mode = POV_RELATIVE
		else:
			last_error = "Invalid pov_mode: %s" % value
var pov_angle_degrees: int = DEFAULT_POV_ANGLE_DEGREES:
	set(value):
		if value >= MIN_POV_ANGLE_DEGREES and value <= MAX_POV_ANGLE_DEGREES:
			pov_angle_degrees = DEFAULT_POV_ANGLE_DEGREES
		else:
			last_error = "pov_angle_degrees must be between %d and %d" % [MIN_POV_ANGLE_DEGREES, MAX_POV_ANGLE_DEGREES]
var pov_range: int = DEFAULT_POV_RANGE:
	set(value):
		if value >= MIN_POV_RANGE and value <= MAX_POV_RANGE:
			pov_range = DEFAULT_POV_RANGE
		else:
			last_error = "pov_range must be between %d and %d" % [MIN_POV_RANGE, MAX_POV_RANGE]
var camera_zoom_percent: int = DEFAULT_CAMERA_ZOOM_PERCENT
var keyboard_bindings: Dictionary[StringName, int] = {}
var mouse_bindings: Dictionary[StringName, int] = {}
var controller_bindings: Dictionary = {}
var reduced_motion: bool = false
var camera_look_ahead: bool = true
var direction_indicator: bool = true
var high_contrast: bool = false
var sound_volume_percent: int = 30
var render_quality: String = "low"
var frame_limit: int = 60
var movement_deadzone_percent: int = 25
var aim_deadzone_percent: int = 25
var ui_text_percent: int = 100
# Session-only input vocabulary; never replaces or persists a user's bindings.
var prompt_device: int = ControlBindingEditor.DEVICE_KEYBOARD
var farflow_join_address: String = DEFAULT_FARFLOW_JOIN_ADDRESS
var migration_notices: Array[Dictionary] = []
var last_error: String = ""


func _init() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	movement_reference = MOVEMENT_WORLD_RELATIVE
	pov_mode = POV_RELATIVE
	pov_angle_degrees = DEFAULT_POV_ANGLE_DEGREES
	pov_range = DEFAULT_POV_RANGE
	camera_zoom_percent = DEFAULT_CAMERA_ZOOM_PERCENT
	keyboard_bindings = DEFAULT_KEYBOARD_BINDINGS.duplicate()
	mouse_bindings = DEFAULT_MOUSE_BINDINGS.duplicate()
	controller_bindings = DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	reduced_motion = false
	camera_look_ahead = true
	direction_indicator = true
	high_contrast = false
	sound_volume_percent = 30
	render_quality = "low"
	frame_limit = 60
	ui_text_percent = 100
	movement_deadzone_percent = 25
	aim_deadzone_percent = 25
	prompt_device = ControlBindingEditor.DEVICE_KEYBOARD
	farflow_join_address = DEFAULT_FARFLOW_JOIN_ADDRESS
	migration_notices.clear()
	last_error = ""


func apply_control_preset(preset_id: String) -> bool:
	if not is_valid_movement_reference(preset_id):
		last_error = "Unknown control preset: %s" % preset_id
		return false
	movement_reference = preset_id
	last_error = ""
	return true


func apply_dictionary(data: Dictionary) -> bool:
	var raw_schema: Variant = data.get("schema_version", -1)
	if not _is_whole_number(raw_schema):
		last_error = "Player preferences require schema_version 1 through 11"
		return false
	var requested_schema: int = int(raw_schema)
	if requested_schema < 1 or requested_schema > SCHEMA_VERSION:
		last_error = "Player preferences require schema_version 1 through 11"
		return false
	var raw_keyboard_revision: Variant = data.get("keyboard_defaults_revision", 0)
	if not _is_whole_number(raw_keyboard_revision) or float(raw_keyboard_revision) < 0.0 or float(raw_keyboard_revision) > KEYBOARD_DEFAULTS_REVISION:
		last_error = "keyboard_defaults_revision must be an integer from 0 to %d" % KEYBOARD_DEFAULTS_REVISION
		return false
	var requested_keyboard_revision := int(raw_keyboard_revision)
	var raw_mouse_revision: Variant = data.get("mouse_defaults_revision", 0)
	if not _is_whole_number(raw_mouse_revision) or float(raw_mouse_revision) < 0.0 or float(raw_mouse_revision) > MOUSE_DEFAULTS_REVISION:
		last_error = "mouse_defaults_revision must be an integer from 0 to %d" % MOUSE_DEFAULTS_REVISION
		return false
	var requested_mouse_revision := int(raw_mouse_revision)
	var raw_controller_revision: Variant = data.get("controller_defaults_revision", 0)
	if not _is_whole_number(raw_controller_revision) or float(raw_controller_revision) < 0.0 or float(raw_controller_revision) > CONTROLLER_DEFAULTS_REVISION:
		last_error = "controller_defaults_revision must be an integer from 0 to %d" % CONTROLLER_DEFAULTS_REVISION
		return false
	var requested_controller_revision := int(raw_controller_revision)
	var requested_movement: String = str(data.get("movement_reference", ""))
	# Optional additive setting: older v11 builds ignore it without rejecting the
	# user's entire control profile. No existing field changes meaning or default.
	var raw_sound: Variant = data.get("sound_volume_percent", 30)
	if not _is_whole_number(raw_sound) or float(raw_sound) < 0.0 or float(raw_sound) > 100.0:
		last_error = "sound_volume_percent must be an integer from 0 to 100"
		return false
	var requested_sound_volume := int(raw_sound)
	var requested_quality: Variant = data.get("render_quality", "low")
	if not requested_quality is String or requested_quality not in ["low", "standard"]:
		last_error = "render_quality must be low or standard"
		return false
	var requested_limit: Variant = data.get("frame_limit", 60)
	if not _is_whole_number(requested_limit) or float(requested_limit) not in [0.0, 60.0, 120.0]:
		last_error = "frame_limit must be 0, 60 or 120"
		return false
	var requested_move_deadzone: Variant = data.get("movement_deadzone_percent",25)
	var requested_aim_deadzone: Variant = data.get("aim_deadzone_percent",25)
	for value: Variant in [requested_move_deadzone,requested_aim_deadzone]:
		if not _is_whole_number(value) or float(value)<5 or float(value)>50:
			last_error = "Movement and aim deadzones must be whole percentages from 5 to 50"
			return false
	var requested_text: Variant = data.get("ui_text_percent", 100)
	if not _is_whole_number(requested_text) or float(requested_text) not in [100.0, 125.0, 150.0, 200.0]:
		last_error = "ui_text_percent must be 100, 125, 150 or 200"
		return false
	var requested_pov_mode: String = str(data.get("pov_mode", ""))
	var requested_direction_indicator: Variant = data.get("direction_indicator", true)
	if not requested_direction_indicator is bool:
		last_error = "direction_indicator must be a boolean"
		return false
	var requested_reduced_motion: bool = false
	if requested_schema >= 2:
		var raw_reduced_motion: Variant = data.get("reduced_motion", false)
		if not raw_reduced_motion is bool:
			last_error = "reduced_motion must be a boolean"
			return false
		requested_reduced_motion = raw_reduced_motion
	# Preserve historical framing when the independent camera preference is absent.
	# Explicit choices remain independent from reduced effects after migration.
	var requested_camera_look_ahead: Variant = data.get("camera_look_ahead", not requested_reduced_motion)
	if not requested_camera_look_ahead is bool:
		last_error = "camera_look_ahead must be a boolean"
		return false
	var requested_high_contrast: bool = false
	if requested_schema >= 8:
		var raw_high_contrast: Variant = data.get("high_contrast", false)
		if not raw_high_contrast is bool:
			last_error = "high_contrast must be a boolean"
			return false
		requested_high_contrast = raw_high_contrast
	var requested_farflow_join_address: String = DEFAULT_FARFLOW_JOIN_ADDRESS
	if requested_schema >= 9:
		var raw_farflow_join_address: Variant = data.get("farflow_join_address", "")
		if not raw_farflow_join_address is String or not is_valid_farflow_join_address(raw_farflow_join_address):
			last_error = "farflow_join_address must be a valid host or IP address"
			return false
		requested_farflow_join_address = String(raw_farflow_join_address)
	if not is_valid_movement_reference(requested_movement):
		last_error = "Invalid movement_reference: %s" % requested_movement
		return false
	if not is_valid_pov_mode(requested_pov_mode):
		last_error = "Invalid pov_mode: %s" % requested_pov_mode
		return false
	if not _is_whole_number(data.get("pov_angle_degrees")):
		last_error = "pov_angle_degrees must be an integer"
		return false
	if not _is_whole_number(data.get("pov_range")):
		last_error = "pov_range must be an integer"
		return false
	var requested_angle: int = int(data["pov_angle_degrees"])
	var requested_range: int = int(data["pov_range"])
	var requested_camera_zoom: int = DEFAULT_CAMERA_ZOOM_PERCENT
	var requested_migration_notices: Array[Dictionary] = []
	if requested_schema >= 7:
		if not _is_whole_number(data.get("camera_zoom_percent")):
			last_error = "camera_zoom_percent must be an integer"
			return false
		requested_camera_zoom = int(data["camera_zoom_percent"])
	if requested_angle < MIN_POV_ANGLE_DEGREES or requested_angle > MAX_POV_ANGLE_DEGREES:
		last_error = "pov_angle_degrees must be between %d and %d" % [MIN_POV_ANGLE_DEGREES, MAX_POV_ANGLE_DEGREES]
		return false
	if requested_range < MIN_POV_RANGE or requested_range > MAX_POV_RANGE:
		last_error = "pov_range must be between %d and %d" % [MIN_POV_RANGE, MAX_POV_RANGE]
		return false
	if requested_pov_mode != POV_RELATIVE or requested_angle != DEFAULT_POV_ANGLE_DEGREES or requested_range != DEFAULT_POV_RANGE:
		requested_migration_notices.append(_migration_notice(
			"relative_vision_unified", "info", "vision", StringName(), 0, StringName(),
			"Vision now uses 360-degree character-centered sight covering the full screen. Legacy full/cone and custom sight values were migrated; controls and camera settings were preserved.",
		))
	if requested_camera_zoom < MIN_CAMERA_ZOOM_PERCENT or requested_camera_zoom > MAX_CAMERA_ZOOM_PERCENT:
		last_error = "camera_zoom_percent must be between %d and %d" % [MIN_CAMERA_ZOOM_PERCENT, MAX_CAMERA_ZOOM_PERCENT]
		return false
	var requested_bindings: Dictionary[StringName, int]
	var schema_defaults := default_keyboard_bindings_for_schema(requested_schema)
	if requested_schema == SCHEMA_VERSION and requested_keyboard_revision == 1:
		schema_defaults = S4_PREVIOUS_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	if requested_schema == SCHEMA_VERSION and requested_keyboard_revision == KEYBOARD_DEFAULTS_REVISION:
		schema_defaults = DEFAULT_KEYBOARD_BINDINGS.duplicate()
	if requested_schema == 1:
		requested_bindings = LEGACY_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	elif requested_schema == 2:
		requested_bindings = SCHEMA_V2_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	elif requested_schema == 3:
		requested_bindings = SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	else:
		requested_bindings = schema_defaults.duplicate()
	var binding_data: Variant = data.get("keyboard_bindings", {})
	if not binding_data is Dictionary:
		last_error = "keyboard_bindings must be an object"
		return false
	for raw_action: Variant in binding_data:
		var action := StringName(str(raw_action))
		if action == &"toggle_tick_rate":
			# Schema 1-9 saves may retain the retired F6 cadence toggle. The
			# canonical 120 Hz runtime ignores it during lossless migration.
			continue
		if requested_schema <= 6 and action == &"spell_5":
			continue
		if not DEFAULT_KEYBOARD_BINDINGS.has(action):
			last_error = "Unknown keyboard action: %s" % action
			return false
		if not _is_whole_number(binding_data[raw_action]):
			last_error = "Keyboard binding for %s must be an integer keycode" % action
			return false
		var keycode: int = int(binding_data[raw_action])
		if keycode < 0 or keycode > 0x7fffffff:
			last_error = "Keyboard binding for %s is outside the supported keycode range" % action
			return false
		requested_bindings[action] = keycode
	for action: StringName in DEFAULT_KEYBOARD_BINDINGS:
		if not requested_bindings.has(action):
			requested_bindings[action] = int(schema_defaults.get(action, 0))
	# Add optional digital aim without taking keys from an older custom layout.
	if not binding_data.is_empty():
		for action: StringName in [&"aim_left",&"aim_right",&"aim_up",&"aim_down"]:
			if not binding_data.has(action): requested_bindings[action] = 0
	requested_bindings.erase(&"toggle_tick_rate")
	if requested_schema == 1:
		if requested_bindings[&"jump"] == LEGACY_DEFAULT_KEYBOARD_BINDINGS[&"jump"]:
			requested_bindings[&"jump"] = DEFAULT_KEYBOARD_BINDINGS[&"jump"]
		if requested_bindings[&"primary"] == LEGACY_DEFAULT_KEYBOARD_BINDINGS[&"primary"]:
			requested_bindings[&"primary"] = DEFAULT_KEYBOARD_BINDINGS[&"primary"]
	if requested_schema <= 2:
		if requested_bindings[&"sprint"] == KEY_ALT:
			requested_bindings[&"sprint"] = DEFAULT_KEYBOARD_BINDINGS[&"sprint"]
		requested_bindings[&"slide"] = DEFAULT_KEYBOARD_BINDINGS[&"slide"]
	elif requested_schema == 3 and requested_bindings[&"slide"] == SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS[&"slide"]:
		requested_bindings[&"slide"] = DEFAULT_KEYBOARD_BINDINGS[&"slide"]
	if requested_schema <= 6:
		_preserve_legacy_modifier_binding(requested_bindings, &"spell_layer_ctrl", KEY_CTRL)
		_preserve_legacy_modifier_binding(requested_bindings, &"spell_layer_alt", KEY_ALT)
	if requested_schema < 10:
		# Never steal a player's existing custom key when adding a new intent.
		for added_action: StringName in [&"evade", &"practice_trace", &"practice_retry"]:
			for action: StringName in requested_bindings:
				if action != added_action and requested_bindings[action] == requested_bindings[added_action]:
					requested_bindings[added_action] = 0
	var expected_old_keyboard: Dictionary[StringName, int] = default_keyboard_bindings_for_schema(requested_schema)
	if requested_schema == 1:
		expected_old_keyboard = LEGACY_DEFAULT_KEYBOARD_BINDINGS
	elif requested_schema == 2:
		expected_old_keyboard = SCHEMA_V2_DEFAULT_KEYBOARD_BINDINGS
	elif requested_schema == 3:
		expected_old_keyboard = SCHEMA_V3_DEFAULT_KEYBOARD_BINDINGS
	elif requested_schema == SCHEMA_VERSION and requested_keyboard_revision == 1:
		expected_old_keyboard = S4_PREVIOUS_DEFAULT_KEYBOARD_BINDINGS
	var migrate_old_keyboard_defaults := (
		requested_keyboard_revision < KEYBOARD_DEFAULTS_REVISION
		and (
			_is_complete_keyboard_layout(binding_data, expected_old_keyboard)
			or (requested_schema < SCHEMA_VERSION and not data.has("keyboard_bindings"))
		)
	)
	if migrate_old_keyboard_defaults:
		requested_bindings = DEFAULT_KEYBOARD_BINDINGS.duplicate()
		var previous_evade_key := int(expected_old_keyboard.get(&"evade", 0))
		var previous_evade_label := OS.get_keycode_string(previous_evade_key) if previous_evade_key != 0 else "Unbound"
		requested_migration_notices.append(_migration_notice(
			"evade_moved_q_to_b", "info", "keyboard", &"evade", KEY_B, StringName(),
			"Evade moved from %s to B in the new default layout." % previous_evade_label,
		))
	elif requested_keyboard_revision < KEYBOARD_DEFAULTS_REVISION and data.has("keyboard_bindings"):
		requested_migration_notices.append(_migration_notice(
			"custom_keyboard_preserved", "info", "keyboard", StringName(), 0, StringName(),
			"Custom keyboard bindings were preserved; Punch and Kick remain unbound.",
		))
		var b_owner := _numeric_binding_owner(requested_bindings, KEY_B)
		if not b_owner.is_empty() and b_owner != &"evade":
			requested_migration_notices.append(_migration_notice(
				"evade_b_conflict_preserved", "action", "keyboard", &"evade", KEY_B, b_owner,
				"Evade stayed on its custom key because B is assigned to %s." % String(b_owner),
			))
	var binding_error: String = validate_keyboard_bindings(requested_bindings)
	if not binding_error.is_empty():
		last_error = binding_error
		return false
	var requested_mouse_bindings: Dictionary[StringName, int] = (
		DEFAULT_MOUSE_BINDINGS.duplicate()
		if requested_mouse_revision == MOUSE_DEFAULTS_REVISION
		else S4_PREVIOUS_DEFAULT_MOUSE_BINDINGS.duplicate()
	)
	var mouse_binding_data: Variant = data.get("mouse_bindings", {})
	if not mouse_binding_data is Dictionary:
		last_error = "mouse_bindings must be an object"
		return false
	for raw_action: Variant in mouse_binding_data:
		var action := StringName(str(raw_action))
		if requested_schema <= 6 and action == &"spell_5":
			continue
		if not DEFAULT_MOUSE_BINDINGS.has(action):
			last_error = "Unknown mouse action: %s" % action
			return false
		if not _is_whole_number(mouse_binding_data[raw_action]):
			last_error = "Mouse binding for %s must be an integer button" % action
			return false
		requested_mouse_bindings[action] = int(mouse_binding_data[raw_action])
	for action: StringName in DEFAULT_MOUSE_BINDINGS:
		if not requested_mouse_bindings.has(action):
			requested_mouse_bindings[action] = 0
	var migrate_old_mouse_defaults := (
		requested_mouse_revision < MOUSE_DEFAULTS_REVISION
		and (
			_is_complete_keyboard_layout(mouse_binding_data, S4_PREVIOUS_DEFAULT_MOUSE_BINDINGS, false)
			or (requested_schema == 4 and _is_complete_keyboard_layout(mouse_binding_data, SCHEMA_V4_DEFAULT_MOUSE_BINDINGS, false))
			or not data.has("mouse_bindings")
		)
	)
	if migrate_old_mouse_defaults:
		requested_mouse_bindings = DEFAULT_MOUSE_BINDINGS.duplicate()
		requested_migration_notices.append(_migration_notice(
			"mouse_melee_defaults_applied", "info", "mouse", &"punch", MOUSE_BUTTON_LEFT, StringName(),
			"Mouse defaults now use Left Button for Punch and Right Button for Kick.",
		))
	elif requested_mouse_revision < MOUSE_DEFAULTS_REVISION and data.has("mouse_bindings"):
		requested_migration_notices.append(_migration_notice(
			"custom_mouse_preserved", "info", "mouse", StringName(), 0, StringName(),
			"Custom mouse bindings were preserved; Punch and Kick remain unbound.",
		))
		for requested_action: StringName in [&"punch", &"kick"]:
			var requested_button := MOUSE_BUTTON_LEFT if requested_action == &"punch" else MOUSE_BUTTON_RIGHT
			var button_owner := _numeric_binding_owner(requested_mouse_bindings, requested_button)
			if not button_owner.is_empty() and button_owner != requested_action:
				requested_migration_notices.append(_migration_notice(
					"mouse_binding_conflict_preserved", "action", "mouse", requested_action, requested_button, button_owner,
					"%s remains unbound because %s owns mouse button %d." % [String(requested_action).capitalize(), String(button_owner), requested_button],
				))
	var mouse_binding_error: String = validate_mouse_bindings(requested_mouse_bindings)
	if not mouse_binding_error.is_empty():
		last_error = mouse_binding_error
		return false
	var controller_binding_data: Variant = data.get("controller_bindings", {})
	if not controller_binding_data is Dictionary:
		last_error = "controller_bindings must be an object"
		return false
	var controller_schema_defaults: Dictionary = DEFAULT_CONTROLLER_BINDINGS if requested_controller_revision == CONTROLLER_DEFAULTS_REVISION else SCHEMA_V11_DEFAULT_CONTROLLER_BINDINGS
	var requested_controller_bindings: Dictionary = controller_schema_defaults.duplicate(true)
	for raw_action: Variant in controller_binding_data:
		var action := StringName(str(raw_action))
		if requested_schema <= 6 and action == &"spell_5":
			continue
		if not DEFAULT_CONTROLLER_BINDINGS.has(action):
			last_error = "Unknown controller action: %s" % action
			return false
		if not controller_binding_data[raw_action] is Dictionary:
			last_error = "Controller binding for %s must be an object" % action
			return false
		var raw_descriptor: Dictionary = controller_binding_data[raw_action]
		if not _is_whole_number(raw_descriptor.get("index", -1)) or not _is_whole_number(raw_descriptor.get("direction", 0)):
			last_error = "Controller binding for %s requires integer index and direction" % action
			return false
		requested_controller_bindings[action] = {
			"kind": String(raw_descriptor.get("kind", "")),
			"index": int(raw_descriptor.get("index", -1)),
			"direction": int(raw_descriptor.get("direction", 0)),
		}
	for action: StringName in DEFAULT_CONTROLLER_BINDINGS:
		if not requested_controller_bindings.has(action):
			requested_controller_bindings[action] = unbound_controller_binding()
	for action: StringName in [&"aim_left",&"aim_right",&"aim_up",&"aim_down"]:
		if not controller_binding_data.has(action):
			var aim_binding: Dictionary = DEFAULT_CONTROLLER_BINDINGS[action].duplicate()
			for other_action: StringName in requested_controller_bindings:
				if other_action != action and requested_controller_bindings[other_action] == aim_binding:
					aim_binding = unbound_controller_binding()
					break
			requested_controller_bindings[action] = aim_binding
	if requested_schema < 10:
		for action: StringName in requested_controller_bindings:
			if action != &"evade" and requested_controller_bindings[action] == requested_controller_bindings[&"evade"]:
				requested_controller_bindings[&"evade"] = {"kind": "none", "index": -1, "direction": 0}
	# An omitted controller object predates controller customization. A complete
	# historical default is likewise safe to migrate. Any partial/custom map or
	# explicit changed/unbound descriptor preserves the whole historical layout.
	if (
		requested_controller_revision == 0
		and (
			not data.has("controller_bindings")
			or _is_complete_controller_layout(controller_binding_data, SCHEMA_V11_DEFAULT_CONTROLLER_BINDINGS)
		)
	):
		requested_controller_bindings = DEFAULT_CONTROLLER_BINDINGS.duplicate(true)
	var controller_binding_error: String = validate_controller_bindings(requested_controller_bindings)
	if not controller_binding_error.is_empty():
		last_error = controller_binding_error
		return false
	movement_reference = requested_movement
	pov_mode = requested_pov_mode
	pov_angle_degrees = requested_angle
	pov_range = requested_range
	camera_zoom_percent = requested_camera_zoom
	keyboard_bindings = requested_bindings
	mouse_bindings = requested_mouse_bindings
	controller_bindings = requested_controller_bindings
	reduced_motion = requested_reduced_motion
	camera_look_ahead = requested_camera_look_ahead
	direction_indicator = requested_direction_indicator
	high_contrast = requested_high_contrast
	sound_volume_percent = requested_sound_volume
	render_quality = requested_quality
	frame_limit = int(requested_limit)
	ui_text_percent = int(requested_text)
	movement_deadzone_percent = int(requested_move_deadzone)
	aim_deadzone_percent = int(requested_aim_deadzone)
	farflow_join_address = requested_farflow_join_address
	migration_notices = requested_migration_notices.duplicate(true)
	last_error = ""
	return true


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		# Older schema-11 readers ignore these additive markers and retain the
		# explicit action maps. Exact historical layouts remain recognizable.
		"keyboard_defaults_revision": KEYBOARD_DEFAULTS_REVISION,
		"mouse_defaults_revision": MOUSE_DEFAULTS_REVISION,
		"controller_defaults_revision": CONTROLLER_DEFAULTS_REVISION,
		"movement_reference": movement_reference,
		"pov_mode": pov_mode,
		"pov_angle_degrees": pov_angle_degrees,
		"pov_range": pov_range,
		"camera_zoom_percent": camera_zoom_percent,
		"keyboard_bindings": keyboard_bindings,
		"mouse_bindings": mouse_bindings,
		"controller_bindings": controller_bindings,
		"reduced_motion": reduced_motion,
		"camera_look_ahead": camera_look_ahead,
		"direction_indicator": direction_indicator,
		"high_contrast": high_contrast,
		"sound_volume_percent": sound_volume_percent,
		"render_quality": render_quality,
		"frame_limit": frame_limit,
		"ui_text_percent": ui_text_percent,
		"movement_deadzone_percent":movement_deadzone_percent,
		"aim_deadzone_percent":aim_deadzone_percent,
		"farflow_join_address": farflow_join_address,
	}


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	reset_to_defaults()
	if not FileAccess.file_exists(path):
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Could not read player preferences: %s" % path
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		last_error = "Player preferences must contain one JSON object"
		return false
	return apply_dictionary(parser.data)


func save_to_file(path: String = DEFAULT_PATH) -> bool:
	# Validate a detached outgoing snapshot before touching either file. Runtime
	# settings/binding maps are mutable; a successful write must remain loadable.
	var outgoing := to_dictionary().duplicate(true)
	var validator := PlayerPreferences.new()
	if not validator.apply_dictionary(outgoing):
		last_error = "Preferences kept unchanged; current settings are invalid: %s" % validator.last_error
		return false
	# The original bytes survive the first normalization by this catalogue version.
	# Validate disk state on every save: a failed load followed by default settings
	# or shutdown must never overwrite a damaged or unsupported existing profile.
	if FileAccess.file_exists(path):
		var original := _read_valid_profile_bytes(path)
		if original.is_empty():
			return false
		var backup_path := path + PRE_S4_CONTROLS_BACKUP_SUFFIX
		if FileAccess.file_exists(backup_path):
			if _read_valid_profile_bytes(backup_path).is_empty():
				return false
		elif not _write_profile_bytes(backup_path, original):
			return false
	return _write_profile_bytes(path, (JSON.stringify(outgoing, "\t") + "\n").to_utf8_buffer())


func _read_valid_profile_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Preferences kept unchanged; could not read: %s" % path
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(bytes.get_string_from_utf8())
	var validator := PlayerPreferences.new()
	if parse_error != OK or not parser.data is Dictionary or not validator.apply_dictionary(parser.data):
		last_error = "Preferences kept unchanged; existing profile or recovery copy is invalid: %s" % path
		return PackedByteArray()
	return bytes


func _write_profile_bytes(path: String, bytes: PackedByteArray) -> bool:
	# Stage beside the target so a failed write never truncates the usable file.
	# Never remove the target to force a failed replacement through.
	var staged_path := "%s.writing-%d-%d" % [path, get_instance_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(staged_path, FileAccess.WRITE)
	if file == null:
		last_error = "Preferences kept unchanged; could not stage: %s" % path
		return false
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(staged_path) != bytes:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged_path))
		last_error = "Preferences kept unchanged; staged write did not verify: %s" % path
		return false
	if _replace_staged_profile(staged_path, path) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged_path))
		last_error = "Preferences kept unchanged; could not install staged file: %s" % path
		return false
	last_error = ""
	return true


func _replace_staged_profile(staged_path: String, path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(staged_path), ProjectSettings.globalize_path(path))


func set_pov_mode(requested_mode: String) -> bool:
	if not is_valid_pov_mode(requested_mode):
		last_error = "Invalid pov_mode: %s" % requested_mode
		return false
	pov_mode = requested_mode
	last_error = ""
	return true


func set_pov_angle_degrees(requested_angle: Variant) -> bool:
	if not _is_whole_number(requested_angle) or float(requested_angle) < MIN_POV_ANGLE_DEGREES or float(requested_angle) > MAX_POV_ANGLE_DEGREES:
		last_error = "pov_angle_degrees must be an integer between %d and %d" % [MIN_POV_ANGLE_DEGREES, MAX_POV_ANGLE_DEGREES]
		return false
	pov_angle_degrees = int(requested_angle)
	last_error = ""
	return true


func set_pov_range(requested_range: Variant) -> bool:
	if not _is_whole_number(requested_range) or float(requested_range) < MIN_POV_RANGE or float(requested_range) > MAX_POV_RANGE:
		last_error = "pov_range must be an integer between %d and %d" % [MIN_POV_RANGE, MAX_POV_RANGE]
		return false
	pov_range = int(requested_range)
	last_error = ""
	return true


func set_camera_zoom_percent(requested_zoom_percent: int) -> void:
	camera_zoom_percent = clampi(requested_zoom_percent, MIN_CAMERA_ZOOM_PERCENT, MAX_CAMERA_ZOOM_PERCENT)


static func is_valid_movement_reference(requested_reference: String) -> bool:
	return requested_reference == MOVEMENT_WORLD_RELATIVE or requested_reference == MOVEMENT_AIM_RELATIVE


static func is_valid_pov_mode(requested_mode: String) -> bool:
	return requested_mode in [POV_RELATIVE, POV_FULL, POV_CONE]


static func is_valid_farflow_join_address(address: String) -> bool:
	var safe_address := address.strip_edges()
	if safe_address.is_empty() or safe_address.length() > 255 or safe_address != address:
		return false
	for character: String in safe_address:
		if character.unicode_at(0) <= 32 or character in "/\\":
			return false
	return true


static func validate_keyboard_bindings(requested_bindings: Dictionary) -> String:
	var used_keycodes: Dictionary[int, StringName] = {}
	for raw_action: Variant in requested_bindings:
		var action := StringName(str(raw_action))
		if not DEFAULT_KEYBOARD_BINDINGS.has(action):
			return "Unknown keyboard action: %s" % action
		var keycode: int = int(requested_bindings[raw_action])
		if keycode == 0:
			continue
		if used_keycodes.has(keycode):
			return "Keyboard actions %s and %s conflict on keycode %d" % [used_keycodes[keycode], action, keycode]
		used_keycodes[keycode] = action
	return ""


static func validate_mouse_bindings(requested_bindings: Dictionary) -> String:
	var used_buttons: Dictionary[int, StringName] = {}
	for raw_action: Variant in requested_bindings:
		var action := StringName(str(raw_action))
		if not DEFAULT_MOUSE_BINDINGS.has(action):
			return "Unknown mouse action: %s" % action
		var button: int = int(requested_bindings[raw_action])
		if button < 0 or button > MOUSE_BUTTON_XBUTTON2:
			return "Mouse binding for %s is outside the supported button range" % action
		if button == 0:
			continue
		if used_buttons.has(button):
			return "Mouse actions %s and %s conflict on button %d" % [used_buttons[button], action, button]
		used_buttons[button] = action
	return ""


static func validate_controller_bindings(requested_bindings: Dictionary) -> String:
	var used_inputs: Dictionary[String, StringName] = {}
	for raw_action: Variant in requested_bindings:
		var action := StringName(str(raw_action))
		if not DEFAULT_CONTROLLER_BINDINGS.has(action):
			return "Unknown controller action: %s" % action
		var descriptor_value: Variant = requested_bindings[raw_action]
		if not descriptor_value is Dictionary:
			return "Controller binding for %s must be an object" % action
		var descriptor: Dictionary = descriptor_value
		var kind := String(descriptor.get("kind", ""))
		var index: int = int(descriptor.get("index", -1))
		var direction: int = int(descriptor.get("direction", 0))
		if kind == "none":
			if index != -1 or direction != 0:
				return "Unbound controller action %s has invalid fields" % action
			continue
		if kind == "button":
			if index < 0 or index > 31 or direction != 0:
				return "Controller button for %s is outside the supported range" % action
		elif kind == "axis":
			if index < 0 or index > 15 or direction not in [-1, 1]:
				return "Controller axis for %s is outside the supported range" % action
		else:
			return "Controller binding for %s has an unknown kind" % action
		var signature := "%s:%d:%d" % [kind, index, direction]
		if used_inputs.has(signature):
			return "Controller actions %s and %s conflict on %s" % [used_inputs[signature], action, signature]
		used_inputs[signature] = action
	return ""


static func unbound_controller_binding() -> Dictionary:
	return {"kind": "none", "index": -1, "direction": 0}


static func _migration_notice(
	code: String,
	severity: String,
	device: String,
	action: StringName,
	requested_binding: int,
	conflicting_action: StringName,
	message: String,
) -> Dictionary:
	return {
		"code": code,
		"severity": severity,
		"device": device,
		"action": action,
		"requested_binding": requested_binding,
		"conflicting_action": conflicting_action,
		"message": message,
	}


static func _numeric_binding_owner(bindings: Dictionary, binding: int) -> StringName:
	if binding == 0:
		return StringName()
	for raw_action: Variant in bindings:
		if int(bindings[raw_action]) == binding:
			return StringName(str(raw_action))
	return StringName()


static func _preserve_legacy_modifier_binding(bindings: Dictionary, modifier_action: StringName, keycode: int) -> void:
	for raw_action: Variant in bindings:
		var action := StringName(str(raw_action))
		if action != modifier_action and int(bindings[raw_action]) == keycode:
			bindings[modifier_action] = 0
			return


static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floorf(value)
	return false


static func default_keyboard_bindings_for_schema(schema: int) -> Dictionary[StringName, int]:
	# Historical schema defaults must not follow future current-layout edits.
	var result: Dictionary[StringName, int] = SCHEMA_V11_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	if schema < 11:
		result[&"evade"] = KEY_Q
		result[&"technique"] = KEY_V
	return result


static func _is_complete_keyboard_layout(bindings: Dictionary, expected: Dictionary[StringName, int], allow_additive_unbound_melee: bool = true) -> bool:
	# A marker-stripping older reader can retain additive unbound melee/aim
	# actions. They carry no custom key choice. Only these exact
	# additions may accompany a complete historical keyboard layout; mouse
	# layouts and any nonzero/custom/unknown additions remain strict.
	for raw_action: Variant in bindings:
		var action := StringName(str(raw_action))
		if expected.has(action):
			continue
		if not allow_additive_unbound_melee or action not in [&"punch", &"kick", &"aim_left", &"aim_right", &"aim_up", &"aim_down"] or bindings[raw_action] != 0:
			return false
	for action: StringName in expected:
		if not bindings.has(action) or bindings[action] != expected[action]:
			return false
	return true


static func _is_complete_controller_layout(bindings: Dictionary, expected: Dictionary) -> bool:
	if bindings.size() != expected.size():
		return false
	for action: StringName in expected:
		# JSON object keys decode as String while in-memory defaults use
		# StringName. Require an exact supported descriptor either way.
		var serialized_action: Variant = action if bindings.has(action) else String(action)
		if not bindings.has(serialized_action):
			return false
		var descriptor: Variant = bindings[serialized_action]
		var expected_descriptor: Dictionary = expected[action]
		if not descriptor is Dictionary or (descriptor as Dictionary).size() != expected_descriptor.size():
			return false
		for field: Variant in expected_descriptor:
			if not (descriptor as Dictionary).has(field) or (descriptor as Dictionary)[field] != expected_descriptor[field]:
				return false
	return true
