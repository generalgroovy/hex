class_name SkeletonAnimationLibrary
extends RefCounted

const SUPPORTED_SCHEMA_VERSION: int = 2
const DEFAULT_PATH: String = "res://content/animations/skeleton_animation_manifest_v1.json"
const REQUIRED_BODY_TYPES: Array[String] = ["small", "middle", "large"]
const REQUIRED_CARDINAL_DIRECTIONS: Array[String] = ["south", "east", "north", "west"]

var data: Dictionary = {}
var last_error: String = ""
var animations: Dictionary = {}
var body_types: Dictionary = {}
var aliases: Dictionary = {}
var action_contracts: Dictionary = {}
var directions: Array[String] = []
var cardinal_directions: Array[String] = []
var cell_size := Vector2i.ZERO
var pivot := Vector2i.ZERO
var atlas_size := Vector2i.ZERO
var block_size := Vector2i.ZERO


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("skeleton animation manifest does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("could not open skeleton animation manifest: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("skeleton animation manifest root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	if int(data.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported skeleton animation schema")
	cell_size = _vector2i(data.get("cell_size", []))
	pivot = _vector2i(data.get("pivot", []))
	if cell_size.x <= 0 or cell_size.y <= 0:
		return _fail("cell size must be positive")
	if pivot.x < 0 or pivot.y < 0 or pivot.x >= cell_size.x or pivot.y >= cell_size.y:
		return _fail("pivot must be inside the animation cell")
	var layout: Dictionary = data.get("atlas_layout", {})
	atlas_size = _vector2i(layout.get("atlas_size", []))
	block_size = _vector2i(layout.get("block_size", []))
	if atlas_size.x <= 0 or atlas_size.y <= 0 or block_size.x <= 0 or block_size.y <= 0:
		return _fail("atlas and block sizes must be positive")
	var raw_directions: Array = data.get("direction_order", [])
	if raw_directions.size() != 8:
		return _fail("exactly eight directions are required")
	directions.clear()
	for direction_value: Variant in raw_directions:
		var direction_id := str(direction_value)
		if direction_id.is_empty() or directions.has(direction_id):
			return _fail("direction ids must be unique and non-empty")
		directions.append(direction_id)
	var raw_cardinal_directions: Array = data.get("cardinal_direction_order", [])
	if raw_cardinal_directions != REQUIRED_CARDINAL_DIRECTIONS:
		return _fail("cardinal direction order must be south, east, north, west")
	cardinal_directions.clear()
	for direction_value: Variant in raw_cardinal_directions:
		var direction_id := str(direction_value)
		if not directions.has(direction_id) or cardinal_directions.has(direction_id):
			return _fail("cardinal directions must be unique members of direction_order")
		cardinal_directions.append(direction_id)
	var cardinal_coverage: Dictionary = data.get("cardinal_coverage", {})
	if not bool(cardinal_coverage.get("required_for_every_animation", false)):
		return _fail("every animation must declare cardinal coverage")
	if String(cardinal_coverage.get("diagonal_policy", "")) != "authored_or_derived":
		return _fail("diagonal direction policy is unsupported")
	if cardinal_coverage.get("diagonal_directions", []) != ["south_east", "north_east", "north_west", "south_west"]:
		return _fail("diagonal direction order is unsupported")
	animations = data.get("animations", {})
	body_types = data.get("body_types", {})
	aliases = data.get("aliases", {})
	action_contracts = data.get("action_contracts", {})
	if animations.is_empty():
		return _fail("at least one animation is required")
	if body_types.size() != REQUIRED_BODY_TYPES.size():
		return _fail("exactly three body types are required")
	for body_type_id: String in REQUIRED_BODY_TYPES:
		if not body_types.has(body_type_id):
			return _fail("required body type is missing: %s" % body_type_id)
	if String(data.get("casting_origin", "")) != "hands":
		return _fail("all skeleton magic must originate from hands")
	var occupied_blocks: Dictionary = {}
	for animation_id: String in animations:
		var animation: Dictionary = animations[animation_id]
		var frames := int(animation.get("frames", 0))
		var block := _vector2i(animation.get("block", []))
		if frames <= 0 or frames * cell_size.x > block_size.x:
			return _fail("%s has invalid frame count" % animation_id)
		if block.x < 0 or block.y < 0:
			return _fail("%s has invalid block coordinates" % animation_id)
		var key := "%d:%d" % [block.x, block.y]
		if occupied_blocks.has(key):
			return _fail("animation blocks overlap: %s" % key)
		occupied_blocks[key] = animation_id
		var final_region := frame_region_from_values(block, directions.size() - 1, frames - 1)
		if final_region.end.x > atlas_size.x or final_region.end.y > atlas_size.y:
			return _fail("%s exceeds atlas bounds" % animation_id)
		for cardinal_direction: String in cardinal_directions:
			var cardinal_index := directions.find(cardinal_direction)
			var cardinal_region := frame_region_from_values(block, cardinal_index, frames - 1)
			if cardinal_region.end.x > atlas_size.x or cardinal_region.end.y > atlas_size.y:
				return _fail("%s lacks cardinal direction coverage: %s" % [animation_id, cardinal_direction])
	for alias_id: String in ["jump", "roll", "impact_recovery"]:
		var target_id := String(aliases.get(alias_id, ""))
		if target_id.is_empty() or not animations.has(target_id) or animations.has(alias_id):
			return _fail("animation alias is invalid: %s" % alias_id)
	for action_id: String in ["jump", "roll", "air_dodge", "cast"]:
		var contract: Dictionary = action_contracts.get(action_id, {})
		if (
			String(contract.get("simulation_timer", "")).is_empty()
			or int(contract.get("invulnerability_ms", -1)) < 0
			or String(contract.get("world_collision", "")) != "solid"
			or String(contract.get("magic_origin", "")) != "hands"
		):
			return _fail("animation action contract is invalid: %s" % action_id)
	for body_type_id: String in body_types:
		var body_type: Dictionary = body_types[body_type_id]
		for path_key: String in ["atlas", "debug_atlas"]:
			var asset_path := str(body_type.get(path_key, ""))
			if asset_path.is_empty() or not FileAccess.file_exists(asset_path):
				return _fail("%s is missing %s" % [body_type_id, path_key])
			var image := ImageAssetInspector.load_image(asset_path)
			if image == null or image.get_size() != atlas_size:
				return _fail("%s %s dimensions do not match manifest" % [body_type_id, path_key])
	return true


func frame_region(body_type_id: String, animation_id: String, direction_id: String, frame_index: int) -> Rect2i:
	animation_id = resolved_animation_id(animation_id)
	if not body_types.has(body_type_id) or not animations.has(animation_id):
		return Rect2i()
	var direction_index := directions.find(direction_id)
	if direction_index < 0:
		return Rect2i()
	var animation: Dictionary = animations[animation_id]
	var frames := int(animation.get("frames", 0))
	if frame_index < 0 or frame_index >= frames:
		return Rect2i()
	return frame_region_from_values(_vector2i(animation.get("block", [])), direction_index, frame_index)


func resolved_animation_id(animation_id: String) -> String:
	return String(aliases.get(animation_id, animation_id))


func action_contract(action_id: String) -> Dictionary:
	return (action_contracts.get(action_id, {}) as Dictionary).duplicate(true)


func cardinal_direction_indices() -> Array[int]:
	var indices: Array[int] = []
	for direction_id: String in cardinal_directions:
		indices.append(directions.find(direction_id))
	return indices


func frame_region_from_values(block: Vector2i, direction_index: int, frame_index: int) -> Rect2i:
	return Rect2i(
		block.x * block_size.x + frame_index * cell_size.x,
		block.y * block_size.y + direction_index * cell_size.y,
		cell_size.x,
		cell_size.y
	)


func atlas_path(body_type_id: String, debug: bool = false) -> String:
	if not body_types.has(body_type_id):
		return ""
	var key := "debug_atlas" if debug else "atlas"
	return str((body_types[body_type_id] as Dictionary).get(key, ""))


func _vector2i(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int((value as Array)[0]), int((value as Array)[1]))


func _fail(message: String) -> bool:
	last_error = message
	return false
