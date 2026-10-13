extends RefCounted

## Exact retained surface geometry. Live phase admission, color and opacity
## remain with the caller. Oversized/invalid/churning input keeps the original
## draw path; no Mesh referenced by a retained CanvasItem command is evicted.
const Glow = preload("res://src/presentation/hex_magic_glow.gd")
const ENTRY_LIMIT := 256
const VERTICES_PER_MESH := 6
const INDICES_PER_MESH := 12

var _entries: Dictionary = {}
var _builds := 0
var _hits := 0
var _draws := 0
var _fallbacks := 0


func draw_surface(canvas: CanvasItem, polygon: PackedVector2Array, base: Color, bright: Color, opacity: float) -> int:
	if canvas == null or not is_finite(opacity) or opacity <= 0.0: return 0
	var entry := _geometry_entry(polygon)
	if entry.is_empty():
		_fallbacks += 1
		return Glow.draw_surface(canvas, polygon, base, bright, opacity)
	for layer: int in Glow.SURFACE_LAYERS:
		var mesh: ArrayMesh = entry.meshes[layer]
		RenderingServer.canvas_item_add_mesh(canvas.get_canvas_item(), mesh.get_rid(), Transform2D.IDENTITY,
			Glow.layer_color(base, bright, layer + 1, opacity, false))
		_draws += 1
	return Glow.SURFACE_LAYERS


func _geometry_entry(polygon: PackedVector2Array) -> Dictionary:
	if polygon.size() != VERTICES_PER_MESH: return {}
	if _entries.has(polygon):
		_hits += 1
		return _entries[polygon]
	if _entries.size() >= ENTRY_LIMIT: return {}
	var meshes: Array[ArrayMesh] = []
	var polygons: Array[PackedVector2Array] = []
	for layer: int in Glow.SURFACE_LAYERS:
		# The old helper remains the sole convexity/inset definition. Never
		# approximate its center arithmetic, winding checks or float positions.
		var inset: PackedVector2Array = Glow.surface_polygon(polygon, layer)
		if inset.size() != VERTICES_PER_MESH: return {}
		var indices := Geometry2D.triangulate_polygon(inset)
		if indices.size() != INDICES_PER_MESH: return {}
		var vertices := PackedVector3Array()
		for point: Vector2 in inset: vertices.append(Vector3(point.x, point.y, 0.0))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes.append(mesh)
		polygons.append(inset)
	meshes.make_read_only()
	polygons.make_read_only()
	var entry := {"meshes": meshes, "polygons": polygons}
	entry.make_read_only()
	_entries[polygon.duplicate()] = entry
	_builds += 1
	return entry


func stats() -> Dictionary:
	return {"entries": _entries.size(), "meshes": _entries.size() * Glow.SURFACE_LAYERS,
		"builds": _builds, "hits": _hits, "draws": _draws, "fallbacks": _fallbacks}


func geometry_for_polygon(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var entry := _geometry_entry(polygon)
	if entry.is_empty(): return result
	for inset: PackedVector2Array in entry.polygons: result.append(inset.duplicate())
	return result
