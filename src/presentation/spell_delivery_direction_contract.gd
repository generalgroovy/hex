class_name SpellDeliveryDirectionContract
extends RefCounted


const DEFAULT_PATH := "res://content/visual/spell_delivery_direction_v1.json"
const EXPECTED_ID := "spell-delivery-direction-v1"
const EXPECTED_AUTHORITY := "presentation-only"
const DIRECTION_ORDER: Array[String] = [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const ZERO_VECTOR_FALLBACK := "south"
const REQUIRED_CHANNELS := {
	"simulation_aim": "continuous-normalized-vector",
	"hand_origin": "continuous-aim-presentation-offset",
	"body_cast_and_recovery": "nearest-eight-direction",
	"hand_gather_and_release_art": "nearest-eight-direction",
	"projectile_orientation_and_trail_art": "nearest-eight-direction",
	"beam_and_spray_geometry": "continuous-simulation-owned",
	"field_and_impact_anchors": "simulation-owned",
}

var data: Dictionary = {}
var content_hash := ""
var last_error := ""


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	data.clear()
	content_hash = ""
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("Spell delivery direction contract does not exist: %s" % path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Spell delivery direction contract root must be an object")
	data = parsed
	if not validate():
		data.clear()
		return false
	content_hash = source.replace("\r\n", "\n").replace("\r", "\n").sha256_text()
	return true


func validate() -> bool:
	last_error = ""
	content_hash = ""
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Spell delivery direction contract identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Spell delivery direction contract must remain presentation-only")
	var raw_order: Variant = data.get("direction_order", [])
	if not raw_order is Array or (raw_order as Array).size() != DIRECTION_ORDER.size():
		return _fail("Spell delivery direction order must contain exactly eight sectors")
	for index: int in range(DIRECTION_ORDER.size()):
		if String((raw_order as Array)[index]) != DIRECTION_ORDER[index] \
				or DIRECTION_ORDER[index] != EightDirectionResolver.DIRECTION_ORDER[index]:
			return _fail("Spell delivery direction order is not canonical")
	if String(data.get("zero_vector_fallback", "")) != ZERO_VECTOR_FALLBACK:
		return _fail("Spell delivery zero-vector fallback must be south")
	var channels: Variant = data.get("channels", {})
	if not channels is Dictionary or (channels as Dictionary).size() != REQUIRED_CHANNELS.size():
		return _fail("Spell delivery direction channels are incomplete")
	for channel_id: String in REQUIRED_CHANNELS:
		if String((channels as Dictionary).get(channel_id, "")) != String(REQUIRED_CHANNELS[channel_id]):
			return _fail("Spell delivery direction channel is unsupported: %s" % channel_id)
	return true


func is_valid() -> bool:
	return not data.is_empty() and last_error.is_empty()


static func direction_id(vector: Vector2) -> String:
	if vector.length_squared() <= 0.0:
		return ZERO_VECTOR_FALLBACK
	var normalized := vector.normalized() * 1000.0
	return EightDirectionResolver.direction_id_from_vector(
		roundi(normalized.x), roundi(normalized.y), ZERO_VECTOR_FALLBACK,
	)


static func visual_vector(vector: Vector2) -> Vector2:
	var fixed := EightDirectionResolver.fixed_vector(direction_id(vector))
	return Vector2(float(fixed.x), float(fixed.y)).normalized()


func _fail(message: String) -> bool:
	last_error = message
	return false
