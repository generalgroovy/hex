class_name WireframeBodyPresenter
extends RefCounted


const DEFAULT_PATH := "res://assets/sprites/wireframe_motion_v2/manifest.json"
const CELL := Vector2(96, 96)
const PIVOT := Vector2(48, 84)
const BODY_TYPES: Array[String] = ["small", "middle", "large"]
const BODY_HEIGHTS := {"small": 58, "middle": 68, "large": 76}
const DISPLAY_HEIGHTS := {"small": 53, "middle": 63, "large": 70}
const PRESENTATION_SCALE := 0.92
const STYLE_ID := "warm_adventurer_foundation_v1"
const MOTION_REVISION := "counter_swing_v3"
const BASE_ROWS: Array[String] = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const PHASE_COUNT := 8
const MATRIX_COLUMNS := 16
const MATRIX_DIMENSIONS := Vector2(1536, 3072)
const BASE_DIMENSIONS := Vector2(768, 960)

var last_error := ""
var content_hash := ""
var base_textures: Dictionary[String, Texture2D] = {}
var locomotion_textures: Dictionary[String, Texture2D] = {}
var sprint_textures: Dictionary[String, Texture2D] = {}


func clear() -> void:
	base_textures.clear()
	locomotion_textures.clear()
	sprint_textures.clear()
	content_hash = ""


func configure(path: String = DEFAULT_PATH) -> bool:
	clear()
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("Wireframe body manifest is missing: " + path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Wireframe body manifest must be an object")
	var data: Dictionary = parsed
	var baked_scale: Variant = data.get("presentation_scale")
	if String(data.get("style_id", "")) != STYLE_ID or typeof(baked_scale) not in [TYPE_INT, TYPE_FLOAT] \
		or not is_finite(float(baked_scale)) or not is_equal_approx(float(baked_scale), PRESENTATION_SCALE):
		return _fail("Adventurer style or baked presentation scale changed")
	if String(data.get("motion_revision", "")) != MOTION_REVISION:
		return _fail("Adventurer motion revision changed")
	var layout: Variant = data.get("locomotion")
	if int(data.get("schema_version", -1)) != 2 or not _matches_dimensions(data.get("cell"), Vector2i(96, 96)) \
		or not _matches_dimensions(data.get("pivot"), Vector2i(48, 84)) or data.get("directions") != EightDirectionResolver.DIRECTION_ORDER \
		or data.get("base_rows") != BASE_ROWS or not layout is Dictionary:
		return _fail("Wireframe body cell, pivot or direction contract changed")
	if layout.get("columns") != 16 or layout.get("rows") != 32 or layout.get("phases") != 8 \
		or layout.get("index_formula") != "((travel*8+aim)*8+phase)":
		return _fail("Wireframe locomotion matrix contract changed")
	var sizes: Variant = data.get("sizes")
	if not sizes is Dictionary or sizes.size() != BODY_TYPES.size():
		return _fail("Wireframe bodies require exactly three shared size templates")
	for body_type: String in BODY_TYPES:
		if not sizes.get(body_type) is Dictionary:
			return _fail("Wireframe body size is missing: " + body_type)
		var definition: Dictionary = sizes[body_type]
		if int(definition.get("reference_height", -1)) != int(BODY_HEIGHTS[body_type]):
			return _fail("Wireframe reference height changed: " + body_type)
		if int(definition.get("display_height", -1)) != int(DISPLAY_HEIGHTS[body_type]):
			return _fail("Adventurer baked display height changed: " + body_type)
		var base := _load_verified(definition, "base", BASE_DIMENSIONS, body_type)
		if base == null:
			return _fail(last_error)
		var locomotion := _load_verified(definition, "locomotion", MATRIX_DIMENSIONS, body_type)
		if locomotion == null:
			return _fail(last_error)
		var sprint := _load_verified(definition, "sprint", MATRIX_DIMENSIONS, body_type)
		if sprint == null:
			return _fail(last_error)
		base_textures[body_type] = base
		locomotion_textures[body_type] = locomotion
		sprint_textures[body_type] = sprint
	content_hash = source.sha256_text()
	return true


func ready() -> bool:
	return not content_hash.is_empty() and base_textures.size() == 3 and locomotion_textures.size() == 3 and sprint_textures.size() == 3


func base_texture(body_type: String) -> Texture2D:
	return base_textures.get(body_type) if ready() else null


static func base_region(animation_state: String, aim_index: int) -> Rect2:
	var row := BASE_ROWS.find(animation_state)
	if row < 0 or aim_index < 0 or aim_index >= 8:
		return Rect2()
	return Rect2(Vector2(aim_index * 96, row * 96), CELL)


static func locomotion_region(travel_index: int, aim_index: int, phase_index: int) -> Rect2:
	if travel_index < 0 or travel_index >= 8 or aim_index < 0 or aim_index >= 8 or phase_index < 0 or phase_index >= PHASE_COUNT:
		return Rect2()
	var index := ((travel_index * 8 + aim_index) * PHASE_COUNT + phase_index)
	return Rect2(Vector2((index % MATRIX_COLUMNS) * 96, floori(float(index) / MATRIX_COLUMNS) * 96), CELL)


func frame(body_type: String, animation_state: String, aim: Vector2i, travel: Vector2i, normalized_phase: float) -> Dictionary:
	if not ready() or not base_textures.has(body_type):
		return {}
	var aim_index := EightDirectionResolver.classify_index(aim.x, aim.y)
	var region := base_region(animation_state, aim_index)
	if not region.has_area():
		return {}
	var texture: Texture2D = base_textures[body_type]
	var travel_index := EightDirectionResolver.classify_index(travel.x, travel.y, aim_index)
	var phase_index := 0
	if animation_state.trim_suffix("_b") in ["walk", "sprint"] and travel != Vector2i.ZERO:
		if not is_finite(normalized_phase):
			return {}
		phase_index = mini(PHASE_COUNT - 1, floori(fposmod(normalized_phase, 1.0) * PHASE_COUNT))
		region = locomotion_region(travel_index, aim_index, phase_index)
		texture = locomotion_textures[body_type]
		if animation_state.trim_suffix("_b") == "sprint":
			texture = sprint_textures[body_type]
	return {"texture": texture, "source_region": region, "gait_frame": phase_index,
		"aim_index": aim_index, "travel_index": travel_index, "wireframe_body": true,
		"style_id": STYLE_ID, "motion_revision": MOTION_REVISION, "baked_presentation_scale": PRESENTATION_SCALE, "display_height": DISPLAY_HEIGHTS[body_type],
		"gait_bank": "sprint" if texture == sprint_textures[body_type] else ("walk" if texture == locomotion_textures[body_type] else "base")}


func _load_verified(definition: Dictionary, key: String, dimensions: Vector2, body_type: String) -> Texture2D:
	var path := String(definition.get(key, ""))
	var source_hash := String(definition.get(key + "_sha256", ""))
	var rgba_hash := String(definition.get(key + "_rgba_sha256", ""))
	if path != "res://assets/sprites/wireframe_motion_v2/%s-%s.png" % [body_type, key] \
		or not _matches_dimensions(definition.get(key + "_dimensions"), Vector2i(dimensions)) \
		or source_hash.length() != 64 or rgba_hash.length() != 64 or not ResourceLoader.exists(path):
		last_error = "Wireframe texture contract is invalid: " + key
		return null
	if OS.has_feature("editor") and FileAccess.file_exists(path) and FileAccess.get_sha256(path) != source_hash:
		last_error = "Wireframe source texture hash changed: " + path
		return null
	var texture := load(path) as Texture2D
	if texture == null or texture.get_size() != dimensions:
		last_error = "Wireframe texture dimensions changed: " + path
		return null
	var pixels := texture.get_image()
	if pixels == null or pixels.is_empty() or pixels.has_mipmaps():
		last_error = "Wireframe texture must decode without mipmaps: " + path
		return null
	pixels.convert(Image.FORMAT_RGBA8)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(pixels.get_data())
	if digest.finish().hex_encode() != rgba_hash:
		last_error = "Wireframe decoded texture hash changed: " + path
		return null
	return texture


func _fail(message: String) -> bool:
	clear()
	last_error = message
	return false


static func _matches_dimensions(value: Variant, expected: Vector2i) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for index: int in 2:
		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT] or float(value[index]) != float(expected[index]):
			return false
	return true
