class_name WellspringDistrictView
extends Node2D


const CATALOG_PATH := "res://content/visual/wellspring_visual_catalog_v2.json"
const TILE_SIZE := Vector2i(16, 16)

@export var district_id: String = "source_court"
@export var build_collision: bool = true
@export var show_navigation_overlay: bool = false

var last_error: String = ""
var layout: Dictionary = {}
var tile_registry: Dictionary = {}
var tile_rows: Array = []
var navigation_rows: Array = []
var tileset_texture: Texture2D
var _collision_root: StaticBody2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not load_district(district_id):
		push_error(last_error)


func load_district(value: String) -> bool:
	last_error = ""
	district_id = value
	clear_runtime_content()
	var catalog := _load_json(CATALOG_PATH)
	if catalog.is_empty():
		return false
	var wellspring: Dictionary = catalog.get("wellspring", {})
	var districts: Dictionary = wellspring.get("districts", {})
	if not districts.has(district_id):
		return _fail("unknown Wellspring district: %s" % district_id)
	var district: Dictionary = districts[district_id]
	layout = _load_json(str(district.get("layout", "")))
	if layout.is_empty():
		return false
	tile_registry = _load_json(str(wellspring.get("tile_registry", ""))).get("tiles", {})
	if tile_registry.is_empty():
		return _fail("Wellspring tile registry is empty")
	var texture_resource: Resource = load(str(wellspring.get("tileset", "")))
	if not texture_resource is Texture2D:
		return _fail("Wellspring tileset could not be loaded")
	tileset_texture = texture_resource
	tile_rows = _decode_rows(layout.get("rows_rle", []), "visual")
	navigation_rows = _decode_rows(layout.get("navigation_rows", []), "navigation")
	if tile_rows.size() != 45:
		return _fail("district visual layout must contain 45 rows")
	if build_collision:
		_build_collision_rows(layout.get("collision_rows", []))
	queue_redraw()
	return true


func clear_runtime_content() -> void:
	if is_instance_valid(_collision_root):
		_collision_root.queue_free()
	_collision_root = null
	tile_rows.clear()
	navigation_rows.clear()
	layout.clear()
	tile_registry.clear()
	tileset_texture = null
	queue_redraw()


func _draw() -> void:
	if tileset_texture == null:
		return
	for y: int in tile_rows.size():
		var row: Array = tile_rows[y]
		for x: int in row.size():
			var tile_id := str(row[x])
			var tile: Dictionary = tile_registry.get(tile_id, {})
			var region: Array = tile.get("region", [])
			if region.size() != 4:
				continue
			var destination := Rect2(Vector2(x * TILE_SIZE.x, y * TILE_SIZE.y), Vector2(TILE_SIZE))
			var source := Rect2(Vector2(float(region[0]), float(region[1])), Vector2(float(region[2]), float(region[3])))
			draw_texture_rect_region(tileset_texture, destination, source)
	if show_navigation_overlay:
		for y: int in navigation_rows.size():
			var row: Array = navigation_rows[y]
			for x: int in row.size():
				if int(row[x]) == 1:
					draw_rect(Rect2(Vector2(x * 16, y * 16), Vector2(16, 16)), Color(0.2, 1.0, 0.5, 0.12), true)


func _build_collision_rows(encoded_rows: Variant) -> void:
	var collision_rows := _decode_rows(encoded_rows, "collision")
	if collision_rows.size() != 45:
		_fail("district collision layout must contain 45 rows")
		return
	_collision_root = StaticBody2D.new()
	_collision_root.name = "GeneratedWorldCollision"
	add_child(_collision_root)
	for y: int in collision_rows.size():
		var row: Array = collision_rows[y]
		var run_start := -1
		for x: int in row.size() + 1:
			var blocked := x < row.size() and int(row[x]) == 1
			if blocked and run_start < 0:
				run_start = x
			elif not blocked and run_start >= 0:
				_add_collision_run(run_start, x - 1, y)
				run_start = -1


func _add_collision_run(start_x: int, end_x: int, row_y: int) -> void:
	var width_tiles := end_x - start_x + 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * TILE_SIZE.x, TILE_SIZE.y)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2((start_x + width_tiles * 0.5) * TILE_SIZE.x, (row_y + 0.5) * TILE_SIZE.y)
	_collision_root.add_child(collision)


func _decode_rows(encoded_rows: Variant, label: String) -> Array:
	var result: Array = []
	if not encoded_rows is Array:
		_fail("%s rows must be an array" % label)
		return result
	for row_variant: Variant in encoded_rows:
		if not row_variant is Array:
			_fail("%s row must be an array" % label)
			return []
		var row: Array = []
		for pair_variant: Variant in row_variant:
			if not pair_variant is Array or (pair_variant as Array).size() != 2:
				_fail("%s RLE pair is malformed" % label)
				return []
			var pair: Array = pair_variant
			var count := int(pair[1])
			if count <= 0:
				_fail("%s RLE count must be positive" % label)
				return []
			for _index: int in count:
				row.append(pair[0])
		if row.size() != 80:
			_fail("%s row expands to %d cells; expected 80" % [label, row.size()])
			return []
		result.append(row)
	return result


func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		_fail("JSON file does not exist: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not open JSON file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("JSON root must be an object: %s" % path)
		return {}
	return parsed


func _fail(message: String) -> bool:
	last_error = message
	return false
