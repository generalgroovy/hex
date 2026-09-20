class_name EightDirectionResolver
extends RefCounted


const SOUTH := 0
const SOUTH_EAST := 1
const EAST := 2
const NORTH_EAST := 3
const NORTH := 4
const NORTH_WEST := 5
const WEST := 6
const SOUTH_WEST := 7
const DIRECTION_ORDER: Array[String] = [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const FIXED_VECTORS: Array[Vector2i] = [
	Vector2i(0, 1000), Vector2i(707, 707), Vector2i(1000, 0), Vector2i(707, -707),
	Vector2i(0, -1000), Vector2i(-707, -707), Vector2i(-1000, 0), Vector2i(-707, 707),
]
const CARDINAL_IDS: Array[String] = ["south", "east", "north", "west"]
const SECTOR_SCALE := 1_000_000
const DIAGONAL_THRESHOLD := 414_214 # ceil(tan(22.5 degrees) * SECTOR_SCALE)
const HYSTERESIS_MARGIN_DEGREES := 8.0
const HYSTERESIS_HOLD_DOT := 0.8616291604415258 # cos(22.5 + 8 degrees)

var last_index := SOUTH
var has_direction := false


static func classify_index(x: int, y: int, fallback_index: int = SOUTH) -> int:
	var fallback := _safe_index(fallback_index)
	if x == 0 and y == 0:
		return fallback
	var absolute_x := absi(x)
	var absolute_y := absi(y)
	if absolute_x * SECTOR_SCALE <= absolute_y * DIAGONAL_THRESHOLD:
		return SOUTH if y >= 0 else NORTH
	if absolute_y * SECTOR_SCALE <= absolute_x * DIAGONAL_THRESHOLD:
		return EAST if x >= 0 else WEST
	if x >= 0:
		return SOUTH_EAST if y >= 0 else NORTH_EAST
	return SOUTH_WEST if y >= 0 else NORTH_WEST


static func direction_id_from_vector(x: int, y: int, fallback_id: String = "south") -> String:
	return DIRECTION_ORDER[classify_index(x, y, direction_index(fallback_id))]


static func direction_index(direction_id: String) -> int:
	var index := DIRECTION_ORDER.find(direction_id)
	return index if index >= 0 else SOUTH


static func fixed_vector(direction_id: String) -> Vector2i:
	return FIXED_VECTORS[direction_index(direction_id)]


static func is_fixed_vector(value: Vector2i) -> bool:
	return value in FIXED_VECTORS


static func nearest_cardinal_id(x: int, y: int, fallback_id: String = "south") -> String:
	if x == 0 and y == 0:
		return fallback_id if fallback_id in CARDINAL_IDS else "south"
	if absi(x) > absi(y):
		return "east" if x >= 0 else "west"
	return "south" if y >= 0 else "north"


static func relative_gait(facing_index: int, travel_index: int) -> String:
	if facing_index < SOUTH or facing_index > SOUTH_WEST or travel_index < SOUTH or travel_index > SOUTH_WEST:
		return "idle"
	var difference := posmod(travel_index - facing_index, DIRECTION_ORDER.size())
	if difference in [0, 1, 7]:
		return "forward"
	if difference in [3, 4, 5]:
		return "backward"
	return "strafe_left" if difference == 2 else "strafe_right"


static func relative_gait_from_vectors(facing: Vector2i, travel: Vector2i) -> String:
	if travel == Vector2i.ZERO:
		return "idle"
	return relative_gait(
		classify_index(facing.x, facing.y, SOUTH),
		classify_index(travel.x, travel.y, SOUTH),
	)


func resolve_index(x: int, y: int, fallback_index: int = SOUTH, use_hysteresis: bool = true) -> int:
	if x == 0 and y == 0:
		if not has_direction:
			last_index = _safe_index(fallback_index)
			has_direction = true
		return last_index
	var raw_index := classify_index(x, y, fallback_index)
	if has_direction and use_hysteresis and raw_index != last_index and _inside_hold_cone(x, y, last_index):
		return last_index
	last_index = raw_index
	has_direction = true
	return last_index


func resolve_id(x: int, y: int, fallback_id: String = "south", use_hysteresis: bool = true) -> String:
	return DIRECTION_ORDER[resolve_index(x, y, direction_index(fallback_id), use_hysteresis)]


func reset(direction_id: String = "south") -> void:
	last_index = direction_index(direction_id)
	has_direction = true


func clear() -> void:
	last_index = SOUTH
	has_direction = false


static func _inside_hold_cone(x: int, y: int, direction: int) -> bool:
	var sample := Vector2(float(x), float(y)).normalized()
	var center_value := FIXED_VECTORS[_safe_index(direction)]
	var center := Vector2(float(center_value.x), float(center_value.y)).normalized()
	return sample.dot(center) >= HYSTERESIS_HOLD_DOT


static func _safe_index(value: int) -> int:
	return value if value >= SOUTH and value <= SOUTH_WEST else SOUTH
