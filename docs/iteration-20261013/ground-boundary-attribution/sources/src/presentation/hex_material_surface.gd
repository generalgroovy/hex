extends RefCounted

# Native artwork sampled on one fixed world grid, not restarted at every hex.
# Only immutable asset pixels and exact geometry are retained. Phase, ownership,
# danger, intensity and palettes are always supplied by the current draw caller.
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const RecipePolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const EffectGeometry = preload("res://src/presentation/pixel_effect_geometry.gd")
const TILE_SIZE := 32
const GEOMETRY_LIMIT := 512
const MESH_LIMIT := 512
const MAX_PIECES := 9
const MAX_VERTICES := 90
const MAX_INDICES := 216
const MAX_FRAME_TEXTURES := 660 # 44 materials * 3 phases * (4 normal + 1 reduced).
const MAX_TEXTURE_BYTES := MAX_FRAME_TEXTURES * TILE_SIZE * TILE_SIZE * 4
const MAX_MESH_DATA_BYTES := MESH_LIMIT * (MAX_VERTICES * (12 + 8) + MAX_INDICES * 4)
const PHASES := ["formation", "active", "decay"]

# One bounded shared bank. Reconfiguration replaces it rather than accumulating
# content versions. Instances keep their own bank alive only while in use.
static var _bank_library: PixelMagicLibrary
static var _bank_hash := ""
static var _bank: Dictionary = {}
static var _bank_texture_count := 0

var _frames: Dictionary = {}
var _texture_count := 0
var _geometry: Dictionary = {}
var _order: Array[PackedVector2Array] = []
var _cursor := 0
var _builds := 0
var _hits := 0
var _translated_draws := 0
var _meshes: Dictionary = {}
var _mesh_uploads := 0
var _mesh_hits := 0
var _triangle_fallback_draws := 0


func configure(library: PixelMagicLibrary = null) -> bool:
	# Setup only: the owner configures before submitting a retained draw list.
	# Resident meshes are never evicted while draw commands may reference them.
	_meshes.clear()
	_mesh_uploads = 0
	_mesh_hits = 0
	_triangle_fallback_draws = 0
	_frames = {}
	_texture_count = 0
	_geometry.clear()
	_order.clear()
	_cursor = 0
	_builds = 0
	_hits = 0
	_translated_draws = 0
	if library == null:
		library = Library.default_library()
	if library.asset_count() == 0:
		return false
	if _bank_library == library and _bank_hash == library.content_hash and not _bank.is_empty():
		_frames = _bank
		_texture_count = _bank_texture_count
		return true
	var prepared := {}
	var pages := {}
	var count := 0
	for wire: int in _material_wires():
		for phase: String in PHASES:
			for reduced: bool in [false, true]:
				var asset_id := _asset_id(library, wire, phase, reduced)
				var asset: Dictionary = library.asset(asset_id)
				if asset.is_empty():
					return false
				var source_frames: Array = asset.get("sampled_frames", [])
				if source_frames.size() != 4:
					return false # Unexpected packs keep the established mark fallback.
				var textures: Array[Texture2D] = []
				for index: int in range(1 if reduced else 4):
					var source: Dictionary = source_frames[1 if reduced else index]
					var texture: Texture2D = source.texture
					var rect: Rect2 = source.region
					if texture == null or rect.size != Vector2(TILE_SIZE, TILE_SIZE):
						return false
					var page_key := texture.get_instance_id()
					if not pages.has(page_key):
						var page := texture.get_image()
						if page == null or (page.is_compressed() and page.decompress() != OK):
							return false
						page.convert(Image.FORMAT_RGBA8)
						pages[page_key] = page
					var cropped: Image = pages[page_key].get_region(Rect2i(rect))
					textures.append(ImageTexture.create_from_image(cropped))
					count += 1
					if count > MAX_FRAME_TEXTURES:
						return false
				textures.make_read_only()
				var entry := {"textures": textures, "asset_id": asset_id, "ends": asset.frame_ends, "total": int(asset.total_ticks)}
				entry.make_read_only()
				prepared[_frame_key(wire, phase, reduced)] = entry
	prepared.make_read_only()
	_bank_library = library
	_bank_hash = library.content_hash
	_bank = prepared
	_bank_texture_count = count
	_frames = prepared
	_texture_count = count
	return true


func draw_region(canvas: CanvasItem, wire: int, polygon: PackedVector2Array, phase: String, tick: float, reduced: bool, opacity: float, tint: Color = Color.WHITE) -> bool:
	if canvas == null or not is_finite(opacity) or opacity <= 0.0:
		return false
	var entry := _frame_entry(wire, phase, tick, reduced)
	if entry.is_empty():
		return false
	var placement := _local_placement(polygon)
	if placement.is_empty():
		return false
	var texture: Texture2D = entry.textures[_frame_index(entry, phase, tick, reduced)]
	var modulate := Color(tint, clampf(opacity, 0.0, 1.0))
	var mesh := _resident_mesh(placement.polygon)
	# UVs wrap by separate clipped pieces, not CanvasItem.texture_repeat: changing
	# that retained property around individual commands would affect other draws.
	if mesh != null:
		RenderingServer.canvas_item_add_mesh(canvas.get_canvas_item(), mesh.get_rid(),
			Transform2D(0.0, placement.origin), modulate, texture.get_rid())
	else:
		# Overflow remains exact and bounded. Do not evict a mesh that an earlier
		# command in this retained draw list may still need when rendering starts.
		var template := _local_geometry(placement.polygon)
		if template.is_empty(): return false
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), template.indices,
			_translated_points(template, placement.origin), PackedColorArray([modulate]), template.uvs,
			PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
		_triangle_fallback_draws += 1
	_translated_draws += 1
	return true


# Detached diagnostics: callers can never mutate packed arrays used by rendering.
func geometry_for_polygon(polygon: PackedVector2Array) -> Dictionary:
	var geometry := _geometry_for_draw(polygon)
	if geometry.is_empty():
		return {}
	return {"points": geometry.points.duplicate(), "uvs": geometry.uvs.duplicate(), "indices": geometry.indices.duplicate(), "pieces": int(geometry.pieces)}


func sample_info(wire: int, phase: String, tick: float, reduced: bool) -> Dictionary:
	var entry := _frame_entry(wire, phase, tick, reduced)
	if entry.is_empty():
		return {}
	return {"asset_id": String(entry.asset_id), "frame": 1 if reduced else _frame_index(entry, phase, tick, reduced), "size": Vector2i(TILE_SIZE, TILE_SIZE)}


func stats() -> Dictionary:
	return {"textures": _texture_count, "texture_bytes": _texture_count * TILE_SIZE * TILE_SIZE * 4,
		"sequences": _frames.size(), "geometry_entries": _geometry.size(), "geometry_builds": _builds, "geometry_hits": _hits,
		"template_builds": _builds, "template_hits": _hits, "translated_draws": _translated_draws,
		"mesh_entries": _meshes.size(), "mesh_uploads": _mesh_uploads, "mesh_hits": _mesh_hits, "triangle_fallback_draws": _triangle_fallback_draws}


func _frame_entry(wire: int, phase: String, tick: float, reduced: bool) -> Dictionary:
	if not is_finite(tick) or tick < 0.0:
		return {}
	var normalized := _phase(phase)
	# Recipe identity/art aliases are immutable; never rebuild a full compound
	# definition for each occupied hex submitted in the same frame.
	var definition := RecipePolicy.runtime_definition(wire) if wire >= 301 else {}
	var archive_wire := int(definition.get("archive_recipe_wire", wire))
	return _frames.get(_frame_key(archive_wire, normalized, reduced), {}) if not normalized.is_empty() else {}


static func _frame_index(entry: Dictionary, phase: String, tick: float, reduced: bool) -> int:
	# No phase age is invented: preparatory/terminal art holds a representative
	# pose until authority changes phase. Only active material animates in place.
	if reduced:
		return 0
	if _phase(phase) != "active":
		return 1
	var elapsed := fmod(tick, float(entry.total))
	for index: int in 4:
		if elapsed < float(entry.ends[index]):
			return index
	return 3


static func _phase(phase: String) -> String:
	if phase in ["forming", "ignition"]: return "formation"
	if phase == "active": return "active"
	if phase in ["decaying", "cooling"]: return "decay"
	return ""


static func _frame_key(wire: int, phase: String, reduced: bool) -> String:
	return "%d/%s/%d" % [wire, phase, int(reduced)]


static func _asset_id(library: PixelMagicLibrary, wire: int, phase: String, reduced: bool) -> String:
	if wire >= 1 and wire <= 8:
		return Library.element_asset_id(wire, "deposit_" + phase, reduced)
	return library.reaction_asset_id(wire, phase, reduced)


static func _material_wires() -> Array[int]:
	# Archive texture preparation, not live element admission: keep Ice/Charge
	# motifs and all36 original reaction frames for the explicit live63 adapter.
	var result: Array[int] = []
	for wire: int in range(1, 9): result.append(wire)
	for index: int in RecipePolicy.COMPILED_ROWS.size(): result.append(RecipePolicy.FIRST_RECIPE_WIRE + index)
	return result


func _geometry_for_draw(polygon: PackedVector2Array) -> Dictionary:
	var placement := _local_placement(polygon)
	if placement.is_empty(): return {}
	var template := _local_geometry(placement.polygon)
	if template.is_empty(): return {}
	return {"points": _translated_points(template, placement.origin), "uvs": template.uvs, "indices": template.indices, "pieces": int(template.pieces)}


static func _local_placement(polygon: PackedVector2Array) -> Dictionary:
	if polygon.size() != 6:
		return {}
	for point: Vector2 in polygon:
		if not point.is_finite() or absf(point.x) > 1_000_000.0 or absf(point.y) > 1_000_000.0:
			return {}
	# Subtract only an exact integer tile translation. The remaining six points
	# retain every fractional coordinate and the world UV phase; no shape or UV
	# quantization merges different geometry. Columns reuse a handful of shapes
	# even when a whole visible board contains more than 512 absolute polygons.
	var origin := Vector2(floori(polygon[0].x / TILE_SIZE) * TILE_SIZE, floori(polygon[0].y / TILE_SIZE) * TILE_SIZE)
	var normalized := PackedVector2Array()
	for point: Vector2 in polygon: normalized.append(point - origin)
	return {"origin": origin, "polygon": normalized}


static func _translated_points(template: Dictionary, origin: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = template.points.duplicate()
	for index: int in points.size(): points[index] += origin
	return points


func _resident_mesh(polygon: PackedVector2Array) -> ArrayMesh:
	if _meshes.has(polygon):
		_mesh_hits += 1
		return _meshes[polygon]
	if _meshes.size() >= MESH_LIMIT:
		return null
	var template := _local_geometry(polygon)
	if template.is_empty(): return null
	var vertices := PackedVector3Array()
	for point: Vector2 in template.points: vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = template.uvs
	arrays[Mesh.ARRAY_INDEX] = template.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Independent copied key: template FIFO eviction cannot discard or alter the
	# resident resource. No shader, packed-attribute compression or mesh mutation.
	_meshes[polygon.duplicate()] = mesh
	_mesh_uploads += 1
	return mesh


func _local_geometry(polygon: PackedVector2Array) -> Dictionary:
	if _geometry.has(polygon):
		_hits += 1
		return _geometry[polygon]
	if polygon.size() != 6:
		return {}
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		if not point.is_finite() or absf(point.x) > 1_000_000.0 or absf(point.y) > 1_000_000.0:
			return {}
		bounds = bounds.expand(point)
	# Live hexes are 24px wide; the cap also admits the previous 48px fixture and
	# small inner phase masks without allowing unbounded diagnostic clip loops.
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.x > 64.0 or bounds.size.y > 64.0:
		return {}
	var first := Vector2i(floori(bounds.position.x / TILE_SIZE), floori(bounds.position.y / TILE_SIZE))
	var last := Vector2i(ceili(bounds.end.x / TILE_SIZE) - 1, ceili(bounds.end.y / TILE_SIZE) - 1)
	if (last.x - first.x + 1) * (last.y - first.y + 1) > MAX_PIECES:
		return {}
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var pieces := 0
	# Work near zero for the native polygon clipper, including distant map cells.
	var local := PackedVector2Array()
	for point: Vector2 in polygon: local.append(point - bounds.position)
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var origin := Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var tile := Rect2(origin - bounds.position, Vector2(TILE_SIZE, TILE_SIZE))
			var square := PackedVector2Array([tile.position, Vector2(tile.end.x, tile.position.y), tile.end, Vector2(tile.position.x, tile.end.y)])
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(local, square):
				var triangles := EffectGeometry.local_triangle_indices(clipped)
				if triangles.is_empty(): continue
				var offset := points.size()
				for point: Vector2 in clipped:
					points.append(point + bounds.position)
					uvs.append((point - tile.position) / float(TILE_SIZE))
				for index: int in triangles: indices.append(offset + index)
				pieces += 1
				if pieces > MAX_PIECES or points.size() > MAX_VERTICES or indices.size() > MAX_INDICES:
					return {}
	if indices.is_empty(): return {}
	var result := {"points": points, "uvs": uvs, "indices": indices, "pieces": pieces}
	result.make_read_only()
	var key := polygon.duplicate()
	if _order.size() < GEOMETRY_LIMIT:
		_order.append(key)
	else:
		_geometry.erase(_order[_cursor])
		_order[_cursor] = key
		_cursor = (_cursor + 1) % GEOMETRY_LIMIT
	_geometry[key] = result
	_builds += 1
	return result
