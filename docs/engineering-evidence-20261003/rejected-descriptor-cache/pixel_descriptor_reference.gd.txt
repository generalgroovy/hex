extends RefCounted
## Frozen pre-reuse selectors from the October3 scale-performance checkpoint.
## Deliberately no call to production frame/template/region helpers. Inputs
## borrow the same admitted immutable textures so full descriptors compare.

const DIRECTIONS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const ROWS := ["idle", "walk_contact_a", "walk_pass_a", "walk_contact_b", "walk_pass_b", "cast"]
const CAST_ROW_MAP := [0, 1, 0, 2, 0, 3]
const SUPPORTED_ACTIONS := ["idle", "walk", "sprint", "cast", "rooted"]
const CELL := Vector2(128, 128)
const PIVOT := Vector2(64, 104)
const ANATOMY_NOTE := "Both body halves keep the same aim-facing anatomy. Sidestep and backward-specific art are incomplete; two contacts with shared neutral beats are visually symmetric under reversal."
const HEIGHTS := {"small":58, "middle":63, "large":68}
const ACTION_ROWS := {"jumpsquat":0, "jump":1, "double_jump":1, "walljump":1,
	"slide_jump":1, "fall":2, "fast_fall":2, "land":3}


static func ground_frame(bank: RefCounted, id: String, action: String, aim: int, travel: int, phase: float,
		casting: bool, cast_weight: float, _reduced_motion: bool) -> Dictionary:
	if not bank.entries.has(id) or not bank.textures.has(id): return {}
	if aim < 0 or aim >= DIRECTIONS.size() or travel < 0 or travel >= DIRECTIONS.size(): return {}
	if not is_finite(phase) or not is_finite(cast_weight) or cast_weight < 0.0 or cast_weight > 1.0: return {}
	if bank.action_bank != null:
		var authored := action_frame(bank.action_bank, id, action, aim, travel, phase, casting)
		if not authored.is_empty(): return authored
	if action not in SUPPORTED_ACTIONS: return {}
	var walking := action in ["walk", "sprint"]
	var relative: int = (travel - aim + 8) % 8
	var gait_mode: String = "standing"
	if walking:
		gait_mode = "backpedal" if relative in [3, 4, 5] else ("sidestep" if relative in [2, 6] else "forward")
	var base_step := clampi(floori(fposmod(phase, 1.0) * 4.0), 0, 3) if walking else 0
	var step: int = posmod(-base_step, 4) if gait_mode == "backpedal" else base_step
	var lower_row := step + 1 if walking else 0
	var upper_row := lower_row
	var lower_facing := aim
	var cast_frame := action == "cast" or (casting and cast_weight > 0.0)
	if cast_frame: upper_row = ROWS.find("cast")
	if bank.full_cast:
		lower_row = CAST_ROW_MAP[lower_row]
		upper_row = CAST_ROW_MAP[upper_row]
	var entry: Dictionary = bank.entries[id]
	var components := make_regions(bank.textures[id], int(entry.waist_y), lower_facing, lower_row, aim, upper_row, 4 if bank.full_cast else 6)
	if components.is_empty(): return {}
	return {
		"texture": bank.textures[id], "components": components,
		"pixel_body_pilot": true, "fullbody_art": true, "wireframe_body": false,
		"visual_mode": "pixel_cast" if bank.full_cast else "pixel_body_pilot", "body_type": entry.body,
		"art_pose_quality": "registered fixed-pixel cast" if bank.full_cast else "registered fixed-pixel pilot",
		"cell_size": CELL, "pivot": PIVOT, "offset": Vector2.ZERO, "squat_depth": 0,
		"display_height": int(entry.display_height), "action": action,
		"aim_index": aim, "travel_index": travel, "motion_phase": phase,
		"gait_mode": gait_mode, "lower_facing": lower_facing,
		"anatomy_note": ANATOMY_NOTE, "strafe_art_complete": false, "backpedal_art_complete": false,
		"sample_phase": float(step) / 4.0 if walking else 0.0,
		"cast_frame": cast_frame, "independent_cast_pose": cast_frame,
		"frame_id": "%s/%s/%d/%d/%d/%d" % [id, action, aim, lower_facing, lower_row, upper_row],
	}


static func make_regions(texture: Texture2D, waist_y: int, lower_facing: int,
		lower_row: int, upper_facing: int, upper_row: int, atlas_rows: int = 6) -> Array[Dictionary]:
	if atlas_rows not in [4, 6] or texture == null or Vector2i(texture.get_size()) != Vector2i(1024, atlas_rows * 128) or waist_y <= 0 or waist_y >= 128: return []
	if lower_facing < 0 or lower_facing >= DIRECTIONS.size() or upper_facing < 0 or upper_facing >= DIRECTIONS.size(): return []
	if lower_row < 0 or lower_row >= atlas_rows or upper_row < 0 or upper_row >= atlas_rows: return []
	return [
		{"texture": texture,
			"source_region": Rect2(lower_facing * 128, lower_row * 128 + waist_y, 128, 128 - waist_y),
			"destination_region": Rect2(0, waist_y, 128, 128 - waist_y)},
		{"texture": texture,
			"source_region": Rect2(upper_facing * 128, upper_row * 128, 128, waist_y),
			"destination_region": Rect2(0, 0, 128, waist_y)},
	]


static func action_frame(bank: RefCounted, id: String, action: String, aim: int, travel: int, phase: float, casting: bool) -> Dictionary:
	if not bank.entries.has(id) or not ACTION_ROWS.has(action) or aim < 0 or aim > 7 or travel < 0 or travel > 7 or not is_finite(phase): return {}
	var texture: Texture2D = bank.textures[id]
	var row: int = ACTION_ROWS[action]
	return {"texture":texture, "pixel_body_pilot":true, "fullbody_art":true, "wireframe_body":false,
		"visual_mode":"pixel_cast", "body_type":bank.entries[id].body, "pixel_action_key":true,
		"display_height":HEIGHTS[bank.entries[id].body],
		"components":[{"texture":texture, "source_region":Rect2(aim*128,row*128,128,128), "destination_region":Rect2(0,0,128,128)}],
		"cell_size":Vector2(128,128), "pivot":Vector2(64,104), "offset":Vector2.ZERO, "squat_depth":0,
		"action":action, "aim_index":aim, "travel_index":travel, "motion_phase":phase,
		"art_pose_quality":"authored fixed-pixel jump key", "independent_cast_pose":false,
		"cast_overlay_requested":casting, "all_action_art_complete":false,
		"frame_id":"%s/action/%d/%d" % [id,aim,row]}


static func same_descriptor(actual: Variant, expected: Variant) -> bool:
	# Numeric types, dictionary key order and nested values are all observable.
	# Resource identity is compared, not decoded pixels or object serialization.
	if typeof(actual) != typeof(expected): return false
	if actual is Dictionary:
		if actual.keys() != expected.keys(): return false
		for key: Variant in actual:
			if not same_descriptor(actual[key], expected[key]): return false
		return true
	if actual is Array:
		if actual.size() != expected.size(): return false
		for index: int in actual.size():
			if not same_descriptor(actual[index], expected[index]): return false
		return true
	return actual == expected
