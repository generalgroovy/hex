class_name MeleeBodyPresenter
extends RefCounted


const LIVE_ROOT := "res://assets/sprites/wireframe_melee_v1/"
const DEFAULT_PATH := LIVE_ROOT + "manifest.json"
const CELL := Vector2(96, 96)
const PIVOT := Vector2(48, 84)
const PAGE_DIMENSIONS := Vector2(768, 2880)
const STYLE_ID := "warm_adventurer_foundation_v1"
const MOTION_REVISION := "melee_v1"
const BODY_TYPES: Array[String] = ["small", "middle", "large"]
const DISPLAY_HEIGHTS := {"small": 58, "middle": 63, "large": 68}
const PRESENTATION_SCALES := {"small": 1.0, "middle": 63.0 / 68.0, "large": 68.0 / 76.0}
const DIRECTIONS: Array[String] = [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const GAITS: Array[String] = ["idle", "forward", "strafe_right", "backward", "strafe_left"]
const ATTACKS: Array[String] = ["punch", "kick"]
const PHASES: Array[String] = ["startup", "active", "recovery"]
const PAGE_LAYOUT := "eight aim columns; rows = ((gait_index * 2 + attack_index) * 3 + phase_index)"
const FRAME_COUNT := 720
const ATTACHMENT_AUTHORITY := "presentation-only points derived from validated melee rig; no simulation or collision values"
const ATTACHMENT_COORDINATE_SPACE := "baked_cell_pixels_subpixel"
const ATTACHMENT_RECORD_FIELDS: Array[String] = [
	"body_index", "gait_index", "physical_kind", "physical_phase", "aim_index",
	"point_x", "point_y", "pixel_x", "pixel_y",
]

var last_error := ""
var content_hash := ""
var page_textures: Dictionary[String, Texture2D] = {}
var frame_records: Dictionary[String, Dictionary] = {}
var attachment_records: Dictionary[String, Dictionary] = {}
var attachment_status := "missing_attachment_table"


func clear() -> void:
	page_textures.clear()
	frame_records.clear()
	attachment_records.clear()
	attachment_status = "missing_attachment_table"
	content_hash = ""


func configure(path: String = DEFAULT_PATH) -> bool:
	clear()
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("Melee body manifest is missing: " + path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Melee body manifest must be an object")
	var data: Dictionary = parsed
	if not _valid_manifest_contract(data):
		return _fail("Melee body manifest layout or shared-body contract changed")
	var pages_value: Variant = data.get("pages")
	if not pages_value is Dictionary:
		return _fail("Melee body manifest pages are missing")
	var pages: Dictionary = pages_value
	for body_type: String in BODY_TYPES:
		var page_value: Variant = pages.get(body_type)
		if not page_value is Dictionary:
			return _fail("Melee body page is missing: " + body_type)
		var page := _load_page(body_type, page_value)
		if page == null:
			return _fail(last_error)
		page_textures[body_type] = page
	if not _index_frames(data.get("frames", [])):
		return _fail(last_error)
	if not _index_attachment_table(path, data):
		return _fail(last_error)
	content_hash = source.sha256_text()
	return true


func ready() -> bool:
	return content_hash.length() == 64 and page_textures.size() == BODY_TYPES.size() and frame_records.size() == FRAME_COUNT


func page_texture(body_type: String) -> Texture2D:
	return page_textures.get(body_type) if ready() else null


func frame(
	body_type: String,
	physical_kind: int,
	physical_phase: int,
	latched_aim: Vector2i,
	travel: Vector2i,
	phase_ticks_remaining: int,
	phase_ticks_total: int,
) -> Dictionary:
	if not ready() or not page_textures.has(body_type) or latched_aim == Vector2i.ZERO:
		return {}
	var phase := phase_selector(physical_kind, physical_phase, phase_ticks_remaining, phase_ticks_total)
	if phase.is_empty():
		return {}
	var aim_index := EightDirectionResolver.classify_index(latched_aim.x, latched_aim.y)
	var gait_index := relative_gait_index(latched_aim, travel)
	if gait_index < 0:
		return {}
	var region := source_region(gait_index, physical_kind, physical_phase, aim_index)
	var key := _frame_key(body_type, gait_index, physical_kind, physical_phase, aim_index)
	if not region.has_area() or not frame_records.has(key):
		return {}
	var attachment: Dictionary = attachment_records.get(key, {})
	var attachment_available := not attachment.is_empty()
	var travel_index := EightDirectionResolver.classify_index(travel.x, travel.y, aim_index)
	return {
		"texture": page_textures[body_type],
		"source_region": region,
		"gait_frame": 0,
		"aim_index": aim_index,
		"travel_index": travel_index,
		"relative_gait_index": gait_index,
		"relative_gait": GAITS[gait_index],
		"gait_bank": "melee",
		"physical_kind": physical_kind,
		"physical_phase": physical_phase,
		"physical_phase_name": str(phase.get("phase_name", "")),
		"physical_phase_progress": float(phase.get("progress", 0.0)),
		"wireframe_body": true,
		"melee_body": true,
		"style_id": STYLE_ID,
		"motion_revision": MOTION_REVISION,
		"baked_presentation_scale": float(PRESENTATION_SCALES[body_type]),
		"display_height": int(DISPLAY_HEIGHTS[body_type]),
		"body_height": int(DISPLAY_HEIGHTS[body_type]),
		"pivot": PIVOT,
		"attachment_available": attachment_available,
		"attachment_name": str(attachment.get("name", "missing")),
		"attachment_point": attachment.get("point", Vector2.INF),
		"attachment_pixel": attachment.get("pixel", Vector2i(-1, -1)),
		"attachment_source": attachment_status,
	}


static func source_region(gait_index: int, physical_kind: int, physical_phase: int, aim_index: int) -> Rect2:
	if gait_index < 0 or gait_index >= GAITS.size() or physical_kind < 1 or physical_kind > ATTACKS.size() \
			or physical_phase < 1 or physical_phase > PHASES.size() or aim_index < 0 or aim_index >= DIRECTIONS.size():
		return Rect2()
	var attack_index := physical_kind - 1
	var phase_index := physical_phase - 1
	var row := ((gait_index * ATTACKS.size() + attack_index) * PHASES.size() + phase_index)
	return Rect2(Vector2(aim_index * int(CELL.x), row * int(CELL.y)), CELL)


static func phase_selector(physical_kind: int, physical_phase: int, ticks_remaining: int, ticks_total: int) -> Dictionary:
	if physical_kind < 1 or physical_kind > ATTACKS.size() or physical_phase < 1 or physical_phase > PHASES.size() \
			or ticks_total <= 0 or ticks_remaining < 0 or ticks_remaining > ticks_total:
		return {}
	return {
		"attack_index": physical_kind - 1,
		"attack_name": ATTACKS[physical_kind - 1],
		"phase_index": physical_phase - 1,
		"phase_name": PHASES[physical_phase - 1],
		"progress": 1.0 - float(ticks_remaining) / float(ticks_total),
	}


static func relative_gait_index(latched_aim: Vector2i, travel: Vector2i) -> int:
	if latched_aim == Vector2i.ZERO:
		return -1
	if travel == Vector2i.ZERO:
		return 0
	var dot := latched_aim.x * travel.x + latched_aim.y * travel.y
	var cross := latched_aim.x * travel.y - latched_aim.y * travel.x
	if absi(dot) >= absi(cross):
		return 1 if dot >= 0 else 3
	return 2 if cross > 0 else 4


func _valid_manifest_contract(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != 1 or str(data.get("style_id", "")) != STYLE_ID \
			or not _matches_dimensions(data.get("cell"), Vector2i(CELL)) or not _matches_dimensions(data.get("pivot"), Vector2i(PIVOT)) \
			or not _matches_dimensions(data.get("page_dimensions"), Vector2i(PAGE_DIMENSIONS)) or str(data.get("page_layout", "")) != PAGE_LAYOUT:
		return false
	var matrix_value: Variant = data.get("matrix")
	if not matrix_value is Dictionary:
		return false
	var matrix: Dictionary = matrix_value
	return matrix.get("bodies") == BODY_TYPES and matrix.get("display_heights") == DISPLAY_HEIGHTS \
		and matrix.get("directions") == DIRECTIONS and matrix.get("gaits") == GAITS and matrix.get("attacks") == ATTACKS \
		and matrix.get("phases") == PHASES and int(matrix.get("frame_count", -1)) == FRAME_COUNT


func _load_page(body_type: String, page: Dictionary) -> Texture2D:
	var expected_path := LIVE_ROOT + body_type + "-melee.png"
	var source_hash := str(page.get("sha256", ""))
	var rgba_hash := str(page.get("rgba_sha256", ""))
	if str(page.get("file", "")) != body_type + "-melee.png" or not _matches_dimensions(page.get("dimensions"), Vector2i(PAGE_DIMENSIONS)) \
			or int(page.get("display_height", -1)) != int(DISPLAY_HEIGHTS[body_type]) \
			or not is_equal_approx(float(page.get("presentation_scale", -1.0)), float(PRESENTATION_SCALES[body_type])) \
			or source_hash.length() != 64 or rgba_hash.length() != 64 or not ResourceLoader.exists(expected_path):
		last_error = "Melee body texture contract is invalid: " + body_type
		return null
	if OS.has_feature("editor") and FileAccess.file_exists(expected_path) and FileAccess.get_sha256(expected_path) != source_hash:
		last_error = "Melee body source texture hash changed: " + expected_path
		return null
	var texture := load(expected_path) as Texture2D
	if texture == null or texture.get_size() != PAGE_DIMENSIONS:
		last_error = "Melee body texture dimensions changed: " + expected_path
		return null
	var pixels := texture.get_image()
	if pixels == null or pixels.is_empty() or pixels.has_mipmaps():
		last_error = "Melee body texture must decode without mipmaps: " + expected_path
		return null
	pixels.convert(Image.FORMAT_RGBA8)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(pixels.get_data())
	if digest.finish().hex_encode() != rgba_hash:
		last_error = "Melee body decoded texture hash changed: " + expected_path
		return null
	return texture


func _index_frames(frames_value: Variant) -> bool:
	if not frames_value is Array or frames_value.size() != FRAME_COUNT:
		last_error = "Melee body manifest must contain exactly 720 frame records"
		return false
	for frame_value: Variant in frames_value:
		if not frame_value is Dictionary:
			last_error = "Melee body frame record must be an object"
			return false
		var record: Dictionary = frame_value
		var body_type := str(record.get("body", ""))
		var gait_index := int(record.get("gait_index", -1))
		var physical_kind := int(record.get("physical_kind", -1))
		var physical_phase := int(record.get("physical_phase", -1))
		var aim_index := int(record.get("aim", -1))
		var expected := source_region(gait_index, physical_kind, physical_phase, aim_index)
		var key := _frame_key(body_type, gait_index, physical_kind, physical_phase, aim_index)
		if body_type not in BODY_TYPES or not expected.has_area() or frame_records.has(key) \
				or str(record.get("gait", "")) != GAITS[gait_index] or str(record.get("attack", "")) != ATTACKS[physical_kind - 1] \
				or str(record.get("phase", "")) != PHASES[physical_phase - 1] or str(record.get("direction", "")) != DIRECTIONS[aim_index] \
				or not _matches_rect(record.get("region"), expected) or not _matches_dimensions(record.get("pivot"), Vector2i(PIVOT)) \
				or int(record.get("standing_display_target", -1)) != int(DISPLAY_HEIGHTS[body_type]) or str(record.get("rgba_sha256", "")).length() != 64:
			last_error = "Melee body frame record disagrees with the fixed row contract: " + key
			return false
		frame_records[key] = record
	if frame_records.size() != FRAME_COUNT:
		last_error = "Melee body frame matrix is incomplete"
		return false
	return true


func _index_attachment_table(manifest_path: String, manifest: Dictionary) -> bool:
	attachment_records.clear()
	attachment_status = "missing_attachment_table"
	if not manifest.has("attachment_table"):
		return true
	var reference_value: Variant = manifest.get("attachment_table")
	if not reference_value is Dictionary:
		last_error = "Melee attachment table reference must be an object"
		return false
	var reference: Dictionary = reference_value
	var expected_hash := str(reference.get("sha256", ""))
	var source_rig_hash := str(reference.get("source_rig_sha256", ""))
	var source_manifest_hash := str(reference.get("source_manifest_core_sha256", ""))
	var path := manifest_path.get_base_dir().path_join("attachments.json")
	if int(reference.get("schema_version", -1)) != 1 or str(reference.get("file", "")) != "attachments.json" \
			or str(reference.get("path", "")) != LIVE_ROOT + "attachments.json" or expected_hash.length() != 64 \
			or source_rig_hash.length() != 64 or source_manifest_hash.length() != 64 \
			or source_rig_hash != str(manifest.get("rig_data_sha256", "")) \
			or str(reference.get("coordinate_space", "")) != ATTACHMENT_COORDINATE_SPACE \
			or int(reference.get("frame_count", -1)) != FRAME_COUNT or not FileAccess.file_exists(path):
		last_error = "Melee attachment table reference is invalid"
		return false
	if FileAccess.get_sha256(path) != expected_hash:
		last_error = "Melee attachment table hash changed: " + path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		last_error = "Melee attachment table must be an object"
		return false
	var data: Dictionary = parsed
	var records_value: Variant = data.get("records")
	if int(data.get("schema_version", -1)) != 1 or str(data.get("authority", "")) != ATTACHMENT_AUTHORITY \
			or str(data.get("coordinate_space", "")) != ATTACHMENT_COORDINATE_SPACE \
			or int(data.get("frame_count", -1)) != FRAME_COUNT or not records_value is Array or records_value.size() != FRAME_COUNT \
			or not _matches_dimensions(data.get("cell"), Vector2i(CELL)) or not _matches_dimensions(data.get("pivot"), Vector2i(PIVOT)) \
			or data.get("bodies") != BODY_TYPES or data.get("gaits") != GAITS or data.get("attacks") != ATTACKS \
			or data.get("phases") != PHASES or data.get("directions") != DIRECTIONS \
			or data.get("display_heights") != DISPLAY_HEIGHTS or data.get("presentation_scales") != PRESENTATION_SCALES \
			or data.get("record_fields") != ATTACHMENT_RECORD_FIELDS \
			or str(data.get("source_rig_sha256", "")) != source_rig_hash \
			or str(data.get("source_manifest_core_sha256", "")) != source_manifest_hash:
		last_error = "Melee attachment table contract changed"
		return false
	var names_value: Variant = data.get("attachment_by_physical_kind")
	if not names_value is Dictionary or str((names_value as Dictionary).get("1", "")) != "hand_r" \
			or str((names_value as Dictionary).get("2", "")) != "toe_r":
		last_error = "Melee attachment names changed"
		return false
	for record_value: Variant in records_value:
		if not record_value is Array or record_value.size() != ATTACHMENT_RECORD_FIELDS.size():
			last_error = "Melee attachment record must contain nine values"
			return false
		var record: Array = record_value
		for value_index: int in record.size():
			if typeof(record[value_index]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record[value_index])):
				last_error = "Melee attachment record contains a nonnumeric value"
				return false
		for integer_index: int in 5:
			if float(record[integer_index]) != floorf(float(record[integer_index])):
				last_error = "Melee attachment key contains a fractional index"
				return false
		for integer_index: int in range(7, 9):
			if float(record[integer_index]) != floorf(float(record[integer_index])):
				last_error = "Melee attachment pixel contains a fractional coordinate"
				return false
		var body_index := int(record[0])
		var gait_index := int(record[1])
		var physical_kind := int(record[2])
		var physical_phase := int(record[3])
		var aim_index := int(record[4])
		if body_index < 0 or body_index >= BODY_TYPES.size():
			last_error = "Melee attachment body index is invalid"
			return false
		var body_type := BODY_TYPES[body_index]
		var key := _frame_key(body_type, gait_index, physical_kind, physical_phase, aim_index)
		if not frame_records.has(key) or attachment_records.has(key):
			last_error = "Melee attachment record does not match a rendered frame: " + key
			return false
		var point_name := "hand_r" if physical_kind == 1 else "toe_r"
		var displayed := Vector2(float(record[5]), float(record[6]))
		var pixel := Vector2i(int(record[7]), int(record[8]))
		if not displayed.is_finite() or displayed.x < 0.0 or displayed.x >= CELL.x or displayed.y < 0.0 or displayed.y >= CELL.y \
				or pixel.x < 0 or pixel.x >= int(CELL.x) or pixel.y < 0 or pixel.y >= int(CELL.y) \
				or Vector2i(displayed.round()) != pixel:
			last_error = "Melee striking attachment leaves its fixed cell: " + key
			return false
		attachment_records[key] = {"name": point_name, "point": displayed, "pixel": pixel}
	if attachment_records.size() != FRAME_COUNT:
		last_error = "Melee attachment table matrix is incomplete"
		return false
	attachment_status = "verified_compact_table"
	return true


func _fail(message: String) -> bool:
	clear()
	last_error = message
	return false


static func _frame_key(body_type: String, gait_index: int, physical_kind: int, physical_phase: int, aim_index: int) -> String:
	return "%s/%d/%d/%d/%d" % [body_type, gait_index, physical_kind, physical_phase, aim_index]


static func _matches_dimensions(value: Variant, expected: Vector2i) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for index: int in 2:
		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT] or float(value[index]) != float(expected[index]):
			return false
	return true


static func _matches_rect(value: Variant, expected: Rect2) -> bool:
	if not value is Array or value.size() != 4:
		return false
	for index: int in 4:
		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3])) == expected
