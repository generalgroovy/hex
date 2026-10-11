extends RefCounted
## Opt-in registered-pixel banks. This module never receives authoritative state.
## It selects two immutable atlas regions; unsupported actions return {} so the
## caller can choose its explicit existing-renderer fallback.

const PATH := "res://assets/sprites/pixel_body_pilot_v1/"
const MANIFEST_ID := "hex-pixel-body-pilot-v1"
const CAST_PATH := "res://assets/sprites/pixel_cast_v1/"
const CAST_MANIFEST_ID := "hex-pixel-cast-v1"
const AerialPose = preload("res://src/presentation/pixel_aerial_pose.gd")
const WallPose = preload("res://src/presentation/pixel_wallrun_pose.gd")
const ActionBank = preload("res://src/presentation/pixel_action_bank.gd")
const CAST_ROWS := ["idle", "walk_contact_a", "walk_contact_b", "cast"]
const CAST_ROW_MAP := [0, 1, 0, 2, 0, 3] # Reuse neutral beats without duplicate texture rows.
const MAX_CAST_CHARACTERS := 64 # Bounded admission; catalog equality is also required.
const DIRECTIONS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const ROWS := ["idle", "walk_contact_a", "walk_pass_a", "walk_contact_b", "walk_pass_b", "cast"]
const CELL := Vector2(128, 128)
const PIVOT := Vector2(64, 104)
const ATLAS_SIZE := Vector2i(1024, 768)
const MAX_CHARACTERS := 3
const BODY_HEIGHTS := {"small": 58, "middle": 63, "large": 68}
const SUPPORTED_ACTIONS := ["idle", "walk", "sprint", "cast", "rooted"]
const RIGID_FALLBACK_POSES := {"crouch": "jumpsquat", "slide": "jumpsquat",
	"wavedash": "jumpsquat", "roll": "jumpsquat", "air_dodge": "jump",
	"wallrun": "jump", "fly": "jump", "hit": "jumpsquat",
	"stunned": "jumpsquat", "defeated": "land"}
const TRAVEL_FACING_ACTIONS := ["slide", "wavedash", "roll", "air_dodge", "wallrun"]
const ANATOMY_NOTE := "Both body halves keep the same aim-facing anatomy. Sidestep and backward-specific art are incomplete; two contacts with shared neutral beats are visually symmetric under reversal."

var aerial_profiles: Dictionary = {}
var entries: Dictionary = {}
var textures: Dictionary = {}
var last_error := ""
var full_cast := false
var action_bank: RefCounted
var action_bank_error := ""
var bounded_residency := false
var portrait_sources: Dictionary = {}
var page_load_count := 0


func configure(catalog_ids: Array, use_full_cast: bool = false, use_bounded_residency: bool = false) -> bool:
	_clear()
	bounded_residency = use_bounded_residency
	var bank_path: String = CAST_PATH if use_full_cast else PATH
	var manifest_path := bank_path + "manifest.json"
	if not FileAccess.file_exists(manifest_path):
		return _fail("Missing pixel-body pilot manifest")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or parsed.get("id") != (CAST_MANIFEST_ID if use_full_cast else MANIFEST_ID):
		return _fail("Pixel bank identity does not match the requested renderer")
	var error := manifest_error(parsed, catalog_ids)
	if not error.is_empty():
		return _fail(error)
	if bounded_residency:
		full_cast = use_full_cast
		for entry: Dictionary in parsed.characters:
			var page := _load_page(entry)
			if page == null: return _fail(last_error)
			entries[entry.id] = entry.duplicate(true)
			var pixels := page.get_image()
			if pixels.is_compressed(): pixels.decompress()
			portrait_sources[entry.id] = pixels.get_region(Rect2i(0,0,128,128))
		if use_full_cast: configure_actions(ActionBank.new())
		return true
	var pages: Dictionary = {}
	for entry: Dictionary in parsed.characters:
		var leaf: String = entry.atlas
		var page := load(bank_path + leaf) as Texture2D
		if page == null:
			return _fail("Missing pixel-body pilot atlas: " + leaf)
		pages[leaf] = page
	if not admit_manifest(parsed, catalog_ids, pages): return false
	if use_full_cast:
		configure_actions(ActionBank.new())
	return true


func configure_actions(candidate: RefCounted) -> bool:
	# An optional action extension cannot revoke the complete, admitted ground
	# bank. Reject the extension atomically and retain explicit legacy actions.
	action_bank = null
	aerial_profiles.clear()
	action_bank_error = ""
	if not full_cast or candidate == null: return false
	if bounded_residency and candidate.get_script() == ActionBank:
		candidate.bounded_residency = true
	if not candidate.configure(entries):
		action_bank_error = candidate.last_error
		return false
	action_bank = candidate
	aerial_profiles.clear()
	for id: String in action_bank.textures:
		var page: Texture2D = action_bank.textures[id]
		var pixels := page.get_image()
		if pixels.is_compressed(): pixels.decompress()
		aerial_profiles[id] = AerialPose.profile(entries[id], pixels, page)
	return true


func admit_manifest(value: Variant, catalog_ids: Array, pages: Dictionary) -> bool:
	# The same admission path supports synthetic textures in contract tests. No
	# partial bank becomes visible when one later entry or page is invalid.
	_clear()
	var error := manifest_error(value, catalog_ids)
	if not error.is_empty():
		return _fail(error)
	var admitted_entries: Dictionary = {}
	var admitted_textures: Dictionary = {}
	var is_cast: bool = value.id == CAST_MANIFEST_ID
	for entry: Dictionary in value.characters:
		var leaf: String = entry.atlas
		var texture := pages.get(leaf) as Texture2D
		var page_error := _page_error(texture, entry, is_cast)
		if not page_error.is_empty(): return _fail(page_error)
		admitted_entries[entry.id] = entry.duplicate(true)
		admitted_textures[entry.id] = texture
	entries = admitted_entries
	textures = admitted_textures
	full_cast = is_cast
	last_error = ""
	return true


static func _page_error(texture: Texture2D, entry: Dictionary, is_cast: bool) -> String:
	var leaf: String = entry.atlas
	var expected_size := Vector2i(1024, 512) if is_cast else ATLAS_SIZE
	if texture == null or Vector2i(texture.get_size()) != expected_size:
		return ("Pixel-body pilot atlas dimensions: " + leaf)
	var pixels := texture.get_image()
	if pixels == null:
		return ("Unreadable pixel-body pilot atlas: " + leaf)
	if pixels.is_compressed() and pixels.decompress() != OK:
		return ("Compressed pixel-body pilot atlas: " + leaf)
	pixels.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels.get_data())
	if hash.finish().hex_encode() != entry.rgba_sha256:
		return ("Pixel-body pilot decoded pixels changed: " + leaf)
	# A matching checksum certifies identity, not usable art. Reject an empty
	# required cell before activation so it cannot hide the working fallback.
	for row: int in (4 if is_cast else 6):
		for column: int in 8:
			if not pixels.get_region(Rect2i(column*128,row*128,128,128)).get_used_rect().has_area():
				return ("Empty required pixel cell: %s/%d/%d" % [leaf,row,column])
	return ""


func _load_page(entry: Dictionary) -> Texture2D:
	var bank_path: String = CAST_PATH if full_cast else PATH
	var page := ResourceLoader.load(bank_path+String(entry.atlas), "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	page_load_count += 1
	last_error = _page_error(page, entry, full_cast)
	return page if last_error.is_empty() else null


func prepare_character_pages(ids: Array[String]) -> bool:
	if not bounded_residency: return true
	if ids.size() > 15:
		last_error = "Pixel residency capacity exceeded"
		return false
	var staged := {}
	for id: String in ids:
		# The three-character pilot remains an explicit subset of the full roster.
		if not entries.has(id): continue
		var page: Texture2D = textures.get(id)
		if page == null: page = _load_page(entries[id])
		if page == null: return false
		staged[id] = page
	if action_bank != null and not action_bank.prepare_character_pages(ids):
		last_error = action_bank.last_error
		return false
	var profiles := {}
	if action_bank != null:
		for id: String in action_bank.textures:
			if aerial_profiles.has(id):
				profiles[id] = aerial_profiles[id]
			else:
				var page: Texture2D = action_bank.textures[id]
				var pixels := page.get_image()
				if pixels.is_compressed(): pixels.decompress()
				profiles[id] = AerialPose.profile(entries[id], pixels, page)
	textures = staged
	aerial_profiles = profiles
	last_error = ""
	return true


static func manifest_error(value: Variant, catalog_ids: Array) -> String:
	if not value is Dictionary:
		return "Invalid pixel-body pilot manifest"
	if value.get("id") not in [MANIFEST_ID, CAST_MANIFEST_ID] or not _whole_number(value.get("schema_version"), 1, 1):
		return "Invalid pixel-body pilot schema"
	var is_cast: bool = value.id == CAST_MANIFEST_ID
	var expected_rows: Array = CAST_ROWS if is_cast else ROWS
	if value.get("directions") != DIRECTIONS or value.get("rows") != expected_rows:
		return "Pixel-body pilot direction/row order changed"
	var cell: Variant = value.get("cell")
	if not _whole_number(cell, 128, 128) and not _pair_equals(cell, 128, 128):
		return "Pixel-body pilot requires a fixed 128px cell"
	if not _pair_equals(value.get("pivot"), 64, 104):
		return "Pixel-body pilot pivot changed"
	var characters: Variant = value.get("characters")
	if not characters is Array or characters.is_empty() or characters.size() > (MAX_CAST_CHARACTERS if is_cast else MAX_CHARACTERS):
		return "Pixel bank exceeds its bounded character capacity"
	if is_cast and characters.size() != catalog_ids.size():
		return "Full pixel cast must cover the exact live catalog"
	var seen_ids: Dictionary = {}
	var seen_pages: Dictionary = {}
	for raw: Variant in characters:
		if not raw is Dictionary:
			return "Invalid pixel-body pilot character"
		var id: Variant = raw.get("id")
		if not id is String or id.is_empty() or not catalog_ids.has(id) or seen_ids.has(id):
			return "Pixel-body pilot identity mismatch"
		var body: Variant = raw.get("body")
		if not body is String or not BODY_HEIGHTS.has(body):
			return "Invalid pixel-body pilot body: " + id
		if not _whole_number(raw.get("display_height"), BODY_HEIGHTS[body], BODY_HEIGHTS[body]):
			return "Pixel-body pilot body calibration changed: " + id
		if not _whole_number(raw.get("waist_y"), 1, 127):
			return "Invalid pixel-body pilot waist: " + id
		var leaf: Variant = raw.get("atlas")
		if not leaf is String or not _safe_atlas_leaf(leaf):
			return "Unsafe pixel-body pilot atlas: " + id
		if seen_pages.has(leaf.to_lower()):
			return "Duplicate pixel-body pilot atlas: " + leaf
		var digest: Variant = raw.get("rgba_sha256")
		if not digest is String or not _sha256_string(digest):
			return "Invalid pixel-body pilot pixel hash: " + id
		seen_ids[id] = true
		seen_pages[leaf.to_lower()] = true
	return ""


func visual_mode() -> String:
	return "pixel_cast" if full_cast else "pixel_body_pilot"


func has_character(id: String) -> bool:
	return entries.has(id) and textures.has(id)


func inspection_frame(id: String, direction: int) -> Dictionary:
	if not has_character(id) or direction < 0 or direction >= DIRECTIONS.size():
		return {}
	return {
		"texture": textures[id], "region": Rect2(direction * 128, 0, 128, 128),
		"pixel_body_pilot": true, "fullbody_art": true, "wireframe_body": false,
		"visual_mode": visual_mode(), "body_type": entries[id].body,
		"cell_size": CELL, "pivot": PIVOT,
	}


func frame(id: String, action: String, aim: int, travel: int, phase: float,
		casting: bool, cast_weight: float, _reduced_motion: bool) -> Dictionary:
	if not has_character(id):
		return {}
	if aim < 0 or aim >= DIRECTIONS.size() or travel < 0 or travel >= DIRECTIONS.size():
		return {}
	if not is_finite(phase) or not is_finite(cast_weight) or cast_weight < 0.0 or cast_weight > 1.0:
		return {}
	if action_bank != null:
		var authored: Dictionary = action_bank.frame(id,action,aim,travel,phase,casting)
		if not authored.is_empty(): return authored
	if action not in SUPPORTED_ACTIONS: return {}
	var walking := action in ["walk", "sprint"]
	var relative: int = (travel - aim + 8) % 8
	var gait_mode: String = "standing"
	if walking:
		gait_mode = "backpedal" if relative in [3, 4, 5] else ("sidestep" if relative in [2, 6] else "forward")
	var base_step := _gait_step(phase) if walking else 0
	# Preserve the phase-zero contact when reversing. A mixed-facing waist cut
	# broke tails/capes during native review: both halves must use the same
	# heading. Sidesteps currently reuse the forward cycle, not finished strafe art.
	var step: int = posmod(-base_step, 4) if gait_mode == "backpedal" else base_step
	var lower_row := step + 1 if walking else 0
	var upper_row := lower_row
	var lower_facing := aim
	# Cast weight is an admission envelope, never an opacity or body transform.
	# A control-owned standing cast also gets its authored upper row at weight0.
	var cast_frame := action == "cast" or (casting and cast_weight > 0.0)
	if cast_frame:
		upper_row = ROWS.find("cast")
	if full_cast:
		lower_row = CAST_ROW_MAP[lower_row]
		upper_row = CAST_ROW_MAP[upper_row]
	var entry: Dictionary = entries[id]
	var components := make_regions(textures[id], int(entry.waist_y), lower_facing, lower_row, aim, upper_row, 4 if full_cast else 6)
	if components.is_empty():
		return {}
	return {
		"texture": textures[id], "components": components,
		"pixel_body_pilot": true, "fullbody_art": true, "wireframe_body": false,
		"visual_mode": visual_mode(), "body_type": entry.body,
		"art_pose_quality": "registered fixed-pixel cast" if full_cast else "registered fixed-pixel pilot",
		"cell_size": CELL, "pivot": PIVOT, "offset": Vector2.ZERO, "squat_depth": 0,
		"display_height": int(entry.display_height), "action": action,
		"aim_index": aim, "travel_index": travel, "motion_phase": phase,
		"gait_mode": gait_mode, "lower_facing": lower_facing,
		"anatomy_note": ANATOMY_NOTE, "strafe_art_complete": false, "backpedal_art_complete": false,
		"sample_phase": float(step) / 4.0 if walking else 0.0,
		"cast_frame": cast_frame, "independent_cast_pose": cast_frame,
		"frame_id": "%s/%s/%d/%d/%d/%d" % [id, action, aim, lower_facing, lower_row, upper_row],
	}


func _gait_step(phase: float) -> int:
	var cycle := fposmod(phase, 1.0)
	if not full_cast:
		return clampi(floori(cycle * 4.0), 0, 3)
	# Center the two painted contacts on distance phases 0 and 1/2. Each holds
	# 5/16 of the cycle; the reused neutral passes each hold 3/16. At the live
	# 2.0/2.5Hz walk/sprint caps hold contacts for156/125ms and passes for
	# 94/75ms, retaining at least two samples per full key at steady30FPS.
	# This accents existing poses, not additional authored animation frames.
	if cycle < 5.0 / 32.0 or cycle >= 27.0 / 32.0: return 0
	if cycle < 11.0 / 32.0: return 1
	if cycle < 21.0 / 32.0: return 2
	return 3


func rigid_fallback_frame(id: String, action: String, aim: int, travel: int,
		phase: float, casting: bool) -> Dictionary:
	# A full pixel cast must not switch art style or grow deforming body parts
	# for an unpainted action. Reuse a registered whole-body key, explicitly
	# marked as a placeholder, until a real action cycle is authored. No waist
	# splice can safely aim the hands independently in these low/air silhouettes.
	if not full_cast or not has_character(id) or aim < 0 or aim > 7 or travel < 0 or travel > 7 or not is_finite(phase):
		return {}
	if not RIGID_FALLBACK_POSES.has(action) and not ActionBank.ACTION_ROWS.has(action):
		return {}
	var facing := travel if action in TRAVEL_FACING_ACTIONS else aim
	var source_pose: String = RIGID_FALLBACK_POSES.get(action, action)
	var result: Dictionary = {}
	if action_bank != null:
		result = action_bank.frame(id, source_pose, facing, travel, phase, casting)
	if result.is_empty():
		# Optional bank admission failure still keeps the admitted identity visible
		# in rigid pixels. Never silently fall back into the legacy mesh renderer.
		source_pose = "idle"
		var texture: Texture2D = textures[id]
		result = {"texture": texture, "pixel_body_pilot": true, "fullbody_art": true,
			"wireframe_body": false, "visual_mode": "pixel_cast", "body_type": entries[id].body,
			"display_height": int(entries[id].display_height), "cell_size": CELL,
			"pivot": PIVOT, "offset": Vector2.ZERO, "squat_depth": 0,
			"components": [{"texture": texture, "source_region": Rect2(facing * 128, 0, 128, 128),
				"destination_region": Rect2(0, 0, 128, 128)}]}
	result["action"] = action
	result["aim_index"] = aim
	result["travel_index"] = travel
	result["motion_phase"] = phase
	result["pose_facing_index"] = facing
	result["source_pose"] = source_pose
	result["rigid_pose_fallback"] = true
	result["pixel_action_key"] = false # The source key is not art for this action.
	result["art_pose_quality"] = "reused fixed-pixel pose; action-specific animation incomplete"
	result["all_action_art_complete"] = false
	result["independent_cast_pose"] = false
	result["cast_overlay_requested"] = casting
	result["frame_id"] = "%s/fallback/%s/%d/%s" % [id, action, facing, source_pose]
	return result


static func make_regions(texture: Texture2D, waist_y: int, lower_facing: int,
		lower_row: int, upper_facing: int, upper_row: int, atlas_rows: int = 6) -> Array[Dictionary]:
	# Each call owns its dictionaries. Both blits remain at native1x pixels and
	# meet on one integer seam; their sizes cannot stretch, rotate or overlap.
	if atlas_rows not in [4, 6] or texture == null or Vector2i(texture.get_size()) != Vector2i(1024, atlas_rows * 128) or waist_y <= 0 or waist_y >= 128:
		return []
	if lower_facing < 0 or lower_facing >= DIRECTIONS.size() or upper_facing < 0 or upper_facing >= DIRECTIONS.size():
		return []
	if lower_row < 0 or lower_row >= atlas_rows or upper_row < 0 or upper_row >= atlas_rows:
		return []
	return [
		{"texture": texture,
			"source_region": Rect2(lower_facing * 128, lower_row * 128 + waist_y, 128, 128 - waist_y),
			"destination_region": Rect2(0, waist_y, 128, 128 - waist_y)},
		{"texture": texture,
			"source_region": Rect2(upper_facing * 128, upper_row * 128, 128, waist_y),
			"destination_region": Rect2(0, 0, 128, waist_y)},
	]


func aerial_frame(id: String, action: String, aim: int, travel: int, tick: float, vertical_velocity: int, reduced: bool, second_jump: bool = false) -> Dictionary:
	return AerialPose.frame(id, aerial_profiles.get(id, {}), action, aim, travel, tick, vertical_velocity, reduced, second_jump)


func wallrun_frame(id: String, aim: int, travel: int, phase: float, normal: Vector2, moving: bool, reduced: bool) -> Dictionary:
	if not full_cast or not has_character(id) or not is_finite(phase): return {}
	return WallPose.frame(id, entries[id], textures[id], aim, travel, _gait_step(phase), normal, moving, reduced)


static func draw_frame(canvas: CanvasItem, value: Dictionary, anchor: Vector2, tint: Color = Color.WHITE) -> void:
	if canvas == null or not anchor.is_finite() or not bool(value.get("pixel_body_pilot", false)):
		return
	if bool(value.get("wallrun_pose", false)):
		WallPose.draw(canvas, value, anchor, tint)
		return
	if bool(value.get("procedural_pixel_pose", false)):
		AerialPose.draw(canvas, value, anchor, tint)
		return
	var at := anchor - PIVOT
	for component: Dictionary in value.get("components", []):
		var destination: Rect2 = component.destination_region
		canvas.draw_texture_rect_region(component.texture, Rect2(at + destination.position, destination.size), component.source_region, tint)


func _clear() -> void:
	portrait_sources.clear()
	aerial_profiles.clear()
	entries.clear()
	textures.clear()
	last_error = ""
	full_cast = false
	action_bank = null
	action_bank_error = ""


func _fail(message: String) -> bool:
	_clear()
	last_error = message
	return false


static func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum


static func _pair_equals(value: Variant, x: int, y: int) -> bool:
	return value is Array and value.size() == 2 and _whole_number(value[0], x, x) and _whole_number(value[1], y, y)


static func _safe_atlas_leaf(leaf: String) -> bool:
	return not leaf.is_empty() and leaf == leaf.get_file() and "/" not in leaf and "\\" not in leaf \
		and ":" not in leaf and ".." not in leaf and leaf.get_extension().to_lower() == "png"


static func _sha256_string(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in value.length():
		if value[index] not in "0123456789abcdef":
			return false
	return true
