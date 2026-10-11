extends RefCounted
## One retained draw submission for opaque terrain replacement polygons.
## Visibility geometry and painter order remain owned by Bootstrap.

var active := false
var _canvas: CanvasItem
var _texture: Texture2D
var _uv_origin := Vector2.ZERO
var _uv_scale := Vector2.ONE
var _fallback := Color("25331f")
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()

func begin(canvas: CanvasItem, texture: Texture2D, world_rect: Rect2, translation: Vector2, zoom: float) -> void:
	_canvas = canvas
	_texture = texture
	active = true
	_points.clear()
	_colors.clear()
	_uvs.clear()
	_indices.clear()
	if texture != null and world_rect.has_area() and zoom > 0.0:
		_uv_scale = Vector2.ONE / (world_rect.size * zoom)
		_uv_origin = -translation * _uv_scale - world_rect.position / world_rect.size
	else:
		_texture = null
		_uv_scale = Vector2.ZERO
		_uv_origin = Vector2.ZERO

func append_polygon(points: PackedVector2Array, shade: Color, edge_shade: Color, feather: bool = false) -> void:
	if not active or points.size() < 3: return
	var triangles := Geometry2D.triangulate_polygon(points)
	if triangles.is_empty(): return
	var offset := _points.size()
	for index: int in points.size():
		_points.append(points[index])
		var color := edge_shade if feather and index in [1, 2] else shade
		_colors.append(color if _texture != null else color * _fallback)
		_uvs.append(points[index] * _uv_scale + _uv_origin)
	for index: int in triangles: _indices.append(index + offset)

func flush() -> void:
	if _canvas != null and not _indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), _indices, _points, _colors, _uvs, PackedInt32Array(), PackedFloat32Array(), _texture.get_rid() if _texture != null else RID())
	_points.clear()
	_colors.clear()
	_uvs.clear()
	_indices.clear()

func finish() -> void:
	flush()
	active = false
	_canvas = null
	_texture = null

# Detached diagnostics; buffers submitted to the renderer remain privately owned.
func geometry() -> Dictionary:
	return {"points": _points.duplicate(), "colors": _colors.duplicate(), "uvs": _uvs.duplicate(), "indices": _indices.duplicate()}
